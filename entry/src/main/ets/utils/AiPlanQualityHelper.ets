import { AiPlanInsight, AiPlanQualityInsight, AiPlanStep } from './AiAgentModels';

export class AiPlanQualityHelper {
  private static hasDeliverableSignal(step: AiPlanStep): boolean {
    const text = `${step.title}${step.note}`;
    const signals: string[] = ['检查', '提交', '交付', '验收', '发布', '完成', '复盘'];
    for (const signal of signals) {
      if (text.indexOf(signal) >= 0) {
        return true;
      }
    }
    return false;
  }

  static evaluate(steps: AiPlanStep[], planInsight: AiPlanInsight): AiPlanQualityInsight {
    if (steps.length === 0) {
      return {
        score: 0,
        status: 'empty',
        title: '等待计划质检',
        description: '生成计划后会在本地检查容量、步骤重复和完成标准。',
        improvementPrompt: ''
      };
    }

    let score = 100;
    const issues: string[] = [];
    if (planInsight.status === 'over_capacity') {
      score -= 35;
      issues.push(`剩余计划超出可用时间 ${Math.abs(planInsight.bufferMinutes)} 分钟`);
    }

    let missingNotes = 0;
    let missingReasons = 0;
    let duplicateSteps = 0;
    for (let index = 0; index < steps.length; index++) {
      const step = steps[index];
      if (step !== undefined) {
        if (step.note.trim().length < 4) {
          missingNotes += 1;
        }
        if (step.reason.trim().length < 4) {
          missingReasons += 1;
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
      issues.push(`${missingNotes} 个步骤缺少可检查的完成标准`);
    }
    if (missingReasons > 0) {
      score -= Math.min(10, missingReasons * 3);
      issues.push(`${missingReasons} 个步骤缺少安排原因`);
    }
    if (duplicateSteps > 0) {
      score -= Math.min(20, duplicateSteps * 10);
      issues.push(`存在 ${duplicateSteps} 个重复步骤`);
    }

    const lastStep = steps[steps.length - 1];
    if (lastStep !== undefined && !AiPlanQualityHelper.hasDeliverableSignal(lastStep)) {
      score -= 10;
      issues.push('最后一步缺少检查、提交或交付动作');
    }

    score = Math.max(0, Math.min(100, score));
    if (score >= 85) {
      return {
        score: score,
        status: 'strong',
        title: '计划质量良好',
        description: '容量、完成标准和交付闭环均通过本地检查。',
        improvementPrompt: ''
      };
    }

    const issueText = issues.join('；');
    return {
      score: score,
      status: score >= 65 ? 'review' : 'weak',
      title: score >= 65 ? '计划建议再校准' : '计划存在明显风险',
      description: `${issueText}。`,
      improvementPrompt: `本地计划质检发现：${issueText}。请修正这些问题，` +
        `保留已经完成的步骤，返回完整计划，并确保未完成番茄总量不超出当前可用时间。`
    };
  }
}
