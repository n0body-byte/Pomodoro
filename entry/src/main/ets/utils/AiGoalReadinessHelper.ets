import { AiGoalReadinessInsight } from './AiAgentModels';

export class AiGoalReadinessHelper {
  private static containsAny(text: string, signals: string[]): boolean {
    for (const signal of signals) {
      if (text.indexOf(signal) >= 0) {
        return true;
      }
    }
    return false;
  }

  private static incomplete(description: string, question: string): AiGoalReadinessInsight {
    return {
      ready: false,
      status: 'needs_clarification',
      title: '先补充一个关键信息',
      description: description,
      question: question
    };
  }

  static evaluate(goal: string): AiGoalReadinessInsight {
    const normalized = goal.trim().replace(/\s+/g, '');
    if (normalized.length < 4) {
      return AiGoalReadinessHelper.incomplete(
        '当前目标太短，智能体无法判断具体要完成什么。',
        '请补充任务对象和本轮产出，例如“完成课程报告大纲”。');
    }

    const vagueGoals: string[] = [
      '学习', '学习一下', '复习', '复习一下', '做作业', '做事情', '完成任务',
      '完善项目', '完善作品', '提升自己', '准备考试', '处理工作', '继续学习',
      '整理一下', '规划一下'
    ];
    const outputSignals: string[] = [
      '完成', '写完', '写出', '整理出', '列出', '提交', '导出', '生成', '制作',
      '实现', '修复', '检查', '通过', '背完', '读完', '做完', '记录', '整理',
      '规划', '制定', '拆分', '初稿',
      '大纲', '清单', '报告', '文档', '页面', '代码', '题目', '错题', '演示'
    ];
    const scopeSignals: string[] = [
      '个', '篇', '章', '节', '页', '套', '题', '项', '份', '轮', '分钟', '小时',
      '今晚', '今天', '明天', '本周', '截止', '第一', '第二', '第三', '核心', '最小'
    ];
    const isKnownVagueGoal = vagueGoals.indexOf(normalized) >= 0;
    const hasOutput = AiGoalReadinessHelper.containsAny(normalized, outputSignals);
    const hasScope = /[0-9一二三四五六七八九十两]/.test(normalized) ||
      AiGoalReadinessHelper.containsAny(normalized, scopeSignals);

    if (isKnownVagueGoal || (!hasOutput && !hasScope)) {
      return AiGoalReadinessHelper.incomplete(
        '目标只有方向，没有可检查的本轮结果，直接生成容易得到空泛计划。',
        '这轮结束时你希望留下什么结果？请补充数量、范围或交付物。');
    }

    if (!hasOutput) {
      return AiGoalReadinessHelper.incomplete(
        '目标已有范围，但还缺少可以验收的产出。',
        '请说明最终要完成、整理、提交或记录什么。');
    }

    return {
      ready: true,
      status: hasScope ? 'ready' : 'ready_with_defaults',
      title: hasScope ? '目标信息充足' : '目标可规划',
      description: hasScope ? '已包含明确产出和范围，可以生成执行计划。' :
        '已识别到明确产出，将按上方可用时间控制计划范围。',
      question: ''
    };
  }
}
