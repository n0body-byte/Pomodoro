import { AiPlanInsight, AiPlanStep } from './AiAgentModels';

export class AiPlanInsightHelper {
  private static normalizePositive(value: number, fallback: number): number {
    if (!Number.isFinite(value) || value <= 0) {
      return fallback;
    }
    return Math.round(value);
  }

  static calculate(steps: AiPlanStep[], availableMinutes: number,
    workMinutes: number, breakMinutes: number): AiPlanInsight {
    const normalizedAvailable = Math.max(0, Math.round(availableMinutes));
    const normalizedWork = AiPlanInsightHelper.normalizePositive(workMinutes, 25);
    const normalizedBreak = AiPlanInsightHelper.normalizePositive(breakMinutes, 5);
    let totalPomodoros = 0;
    let completedPomodoros = 0;
    let nextStepIndex = -1;

    for (let index = 0; index < steps.length; index++) {
      const step = steps[index];
      if (step !== undefined) {
        const estimate = Math.max(1, Math.min(20, Math.round(step.estimatedPomodoros)));
        totalPomodoros += estimate;
        if (step.completed) {
          completedPomodoros += estimate;
        } else if (nextStepIndex < 0) {
          nextStepIndex = index;
        }
      }
    }

    const remainingPomodoros = Math.max(0, totalPomodoros - completedPomodoros);
    const progressPercent = totalPomodoros === 0 ? 0 :
      Math.min(100, Math.round(completedPomodoros * 100 / totalPomodoros));
    const breakCount = Math.max(0, remainingPomodoros - 1);
    const requiredMinutes = remainingPomodoros * normalizedWork + breakCount * normalizedBreak;
    const bufferMinutes = normalizedAvailable - requiredMinutes;
    const feasibilityPercent = requiredMinutes === 0 ? 100 :
      Math.min(100, Math.max(0, Math.round(normalizedAvailable * 100 / requiredMinutes)));

    if (steps.length === 0) {
      return {
        totalPomodoros: 0,
        completedPomodoros: 0,
        remainingPomodoros: 0,
        progressPercent: 0,
        requiredMinutes: 0,
        bufferMinutes: normalizedAvailable,
        feasibilityPercent: 0,
        status: 'empty',
        title: '等待生成计划',
        description: '生成计划后会自动评估工作量、时间缓冲和完成风险。',
        nextStepIndex: -1
      };
    }

    if (remainingPomodoros === 0) {
      return {
        totalPomodoros: totalPomodoros,
        completedPomodoros: completedPomodoros,
        remainingPomodoros: 0,
        progressPercent: 100,
        requiredMinutes: 0,
        bufferMinutes: normalizedAvailable,
        feasibilityPercent: 100,
        status: 'completed',
        title: '计划已完成',
        description: '所有步骤均已完成，可以让智能体复盘成果并规划下一阶段。',
        nextStepIndex: -1
      };
    }

    if (bufferMinutes < 0) {
      return {
        totalPomodoros: totalPomodoros,
        completedPomodoros: completedPomodoros,
        remainingPomodoros: remainingPomodoros,
        progressPercent: progressPercent,
        requiredMinutes: requiredMinutes,
        bufferMinutes: bufferMinutes,
        feasibilityPercent: feasibilityPercent,
        status: 'over_capacity',
        title: '计划超出时间容量',
        description: `预计还需 ${requiredMinutes} 分钟，当前时间缺口 ${Math.abs(bufferMinutes)} 分钟。`,
        nextStepIndex: nextStepIndex
      };
    }

    if (bufferMinutes < normalizedWork + normalizedBreak) {
      return {
        totalPomodoros: totalPomodoros,
        completedPomodoros: completedPomodoros,
        remainingPomodoros: remainingPomodoros,
        progressPercent: progressPercent,
        requiredMinutes: requiredMinutes,
        bufferMinutes: bufferMinutes,
        feasibilityPercent: feasibilityPercent,
        status: 'tight',
        title: '计划可行但缓冲较少',
        description: `预计还需 ${requiredMinutes} 分钟，仅剩 ${bufferMinutes} 分钟机动时间。`,
        nextStepIndex: nextStepIndex
      };
    }

    return {
      totalPomodoros: totalPomodoros,
      completedPomodoros: completedPomodoros,
      remainingPomodoros: remainingPomodoros,
      progressPercent: progressPercent,
      requiredMinutes: requiredMinutes,
      bufferMinutes: bufferMinutes,
      feasibilityPercent: feasibilityPercent,
      status: 'on_track',
      title: '计划节奏健康',
      description: `预计还需 ${requiredMinutes} 分钟，并保留 ${bufferMinutes} 分钟机动时间。`,
      nextStepIndex: nextStepIndex
    };
  }
}
