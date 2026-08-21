import { AiPlanInsight, AiPlanQualityInsight, AiPlanStep } from './AiAgentModels';

export class AiPlanQualityHelper {
  private static containsAny(text: string, signals: string[]): boolean {
    for (const signal of signals) {
      if (text.indexOf(signal) >= 0) {
        return true;
      }
    }
    return false;
  }

  private static hasDeliverableSignal(step: AiPlanStep): boolean {
    const text = `${step.title}${step.note}`;
    const signals: string[] = [
      '检查', '提交', '交付', '验收', '发布', '完成', '复盘', '保存', '导出',
      '生成', '形成', '写完', '整理出', '列出', '通过', '记录'
    ];
    return AiPlanQualityHelper.containsAny(text, signals);
  }

  private static hasCompletionStandard(step: AiPlanStep): boolean {
    if (step.note.trim().length < 6) {
      return false;
    }
    const evidenceSignals: string[] = [
      '完成', '写完', '形成', '保存', '提交', '导出', '检查', '修复', '整理',
      '列出', '标记', '通过', '达到', '生成', '交付', '记录', '确认', '找到'
    ];
    return /[0-9一二三四五六七八九十两]/.test(step.note) ||
      AiPlanQualityHelper.containsAny(step.note, evidenceSignals);
  }

  private static isVagueStep(step: AiPlanStep): boolean {
    const title = step.title.trim().replace(/\s+/g, '');
    const vagueTitles: string[] = [
      '处理事情', '继续学习', '研究一下', '了解一下', '思考一下', '完善内容',
      '推进任务', '开始执行', '做一下', '其他任务', '相关内容', '完成任务',
      '处理工作', '学习知识', '复习知识'
    ];
    return title.length < 4 || vagueTitles.indexOf(title) >= 0;
  }

  static evaluate(steps: AiPlanStep[], planInsight: AiPlanInsight): AiPlanQualityInsight {
    if (steps.length === 0) {
      return {
        score: 0,
        status: 'empty',
        title: '等待计划质检',
        description: '生成计划后会在本地检查容量、步骤重复和完成标准。',
        improvementPrompt: '',
        canApply: false,
        blockingIssues: []
      };
    }

    let score = 100;
    const issues: string[] = [];
    const blockingIssues: string[] = [];
    if (planInsight.status === 'over_capacity') {
      score -= 35;
      const issue = `剩余计划超出可用时间 ${Math.abs(planInsight.bufferMinutes)} 分钟`;
      issues.push(issue);
      blockingIssues.push(issue);
    }

    let missingNotes = 0;
    let missingReasons = 0;
    let duplicateSteps = 0;
    let vagueSteps = 0;
    let oversizedSteps = 0;
    for (let index = 0; index < steps.length; index++) {
      const step = steps[index];
      if (step !== undefined) {
        if (!step.completed && !AiPlanQualityHelper.hasCompletionStandard(step)) {
          missingNotes += 1;
        }
        if (step.reason.trim().length < 4) {
          missingReasons += 1;
        }
        if (!step.completed && AiPlanQualityHelper.isVagueStep(step)) {
          vagueSteps += 1;
        }
        if (!step.completed && step.estimatedPomodoros > 4) {
          oversizedSteps += 1;
        }
        for (let previousIndex = 0; previousIndex < index; previousIndex++) {
          const previous = steps[previousIndex];
          if (previous !== undefined && previous.title === step.title && previous.project === step.project) {
            duplicateSteps += 1;
            break;
          }
        }
      }
    }

    if (missingNotes > 0) {
      score -= Math.min(20, missingNotes * 5);
      const issue = `${missingNotes} 个步骤缺少可检查的完成标准`;
      issues.push(issue);
      blockingIssues.push(issue);
    }
    if (missingReasons > 0) {
      score -= Math.min(10, missingReasons * 3);
      issues.push(`${missingReasons} 个步骤缺少安排原因`);
    }
    if (duplicateSteps > 0) {
      score -= Math.min(20, duplicateSteps * 10);
      const issue = `存在 ${duplicateSteps} 个重复步骤`;
      issues.push(issue);
      blockingIssues.push(issue);
    }
    if (vagueSteps > 0) {
      score -= Math.min(30, vagueSteps * 12);
      const issue = `${vagueSteps} 个步骤仍是“研究一下、完善内容”等空泛动作`;
      issues.push(issue);
      blockingIssues.push(issue);
    }
    if (oversizedSteps > 0) {
      score -= Math.min(25, oversizedSteps * 10);
      const issue = `${oversizedSteps} 个步骤超过 4 个番茄，需要继续拆分`;
      issues.push(issue);
      blockingIssues.push(issue);
    }

    let lastStep: AiPlanStep | undefined = undefined;
    for (let index = steps.length - 1; index >= 0; index--) {
      const candidate = steps[index];
      if (candidate !== undefined && !candidate.completed) {
        lastStep = candidate;
        break;
      }
    }
    if (lastStep !== undefined && !AiPlanQualityHelper.hasDeliverableSignal(lastStep)) {
      score -= 10;
      const issue = '最后一步缺少检查、提交或交付动作';
      issues.push(issue);
      blockingIssues.push(issue);
    }

    score = Math.max(0, Math.min(100, score));
    const canApply = score >= 80 && blockingIssues.length === 0;
    if (canApply && issues.length === 0) {
      return {
        score: score,
        status: 'strong',
        title: '计划质量良好',
        description: '容量、完成标准和交付闭环均通过本地检查。',
        improvementPrompt: '',
        canApply: true,
        blockingIssues: []
      };
    }

    const issueText = issues.join('；');
    return {
      score: score,
      status: canApply ? 'review' : 'blocked',
      title: canApply ? '计划建议再校准' : '计划未通过质量门',
      description: `${issueText}。`,
      improvementPrompt: `本地计划质检发现：${issueText}。请修正这些问题，` +
        `保留已经完成的步骤，返回完整计划；每个未完成步骤为 1 到 4 个番茄，` +
        `标题必须包含具体动作和对象，note 必须写明可检查的完成标准，` +
        `并确保未完成番茄总量不超出当前可用时间。`,
      canApply: canApply,
      blockingIssues: blockingIssues
    };
  }
}
