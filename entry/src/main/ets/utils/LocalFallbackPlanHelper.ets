import { AiPlan, AiPlanStep } from './AiAgentModels';

export class LocalFallbackPlanHelper {
  private static normalizePositive(value: number, fallback: number): number {
    if (!Number.isFinite(value) || value <= 0) {
      return fallback;
    }
    return Math.round(value);
  }

  private static createStep(title: string, project: string, note: string,
    estimatedPomodoros: number, reason: string): AiPlanStep {
    return {
      title: title,
      project: project,
      tag: '应急计划',
      note: note,
      estimatedPomodoros: Math.max(1, estimatedPomodoros),
      reason: reason,
      completed: false
    };
  }

  static calculateFittingPomodoros(availableMinutes: number,
    workMinutes: number, breakMinutes: number): number {
    const available = Math.max(0, Math.round(availableMinutes));
    const work = LocalFallbackPlanHelper.normalizePositive(workMinutes, 25);
    const rest = LocalFallbackPlanHelper.normalizePositive(breakMinutes, 5);
    if (available < work) {
      return 0;
    }
    return Math.max(1, Math.min(12, Math.floor((available + rest) / (work + rest))));
  }

  static create(goal: string, availableMinutes: number, deadline: string,
    workMinutes: number, breakMinutes: number): AiPlan {
    const normalizedGoal = goal.trim().length > 0 ? goal.trim() : '完成当前最重要的任务';
    const project = normalizedGoal.substring(0, 16);
    const pomodoros = Math.max(1, LocalFallbackPlanHelper.calculateFittingPomodoros(
      availableMinutes, workMinutes, breakMinutes));
    const steps: AiPlanStep[] = [];

    if (pomodoros === 1) {
      steps.push(LocalFallbackPlanHelper.createStep(
        '完成最小可交付成果', project,
        `围绕“${normalizedGoal}”直接完成一个可以检查或提交的最小版本。`, 1,
        '时间有限，优先确保本轮产生明确成果。'));
    } else if (pomodoros === 2) {
      steps.push(LocalFallbackPlanHelper.createStep(
        '明确完成标准并开始核心内容', project,
        `先确认“${normalizedGoal}”的完成标准，再立即进入最重要的内容。`, 1,
        '减少准备时间，尽快形成主体成果。'));
      steps.push(LocalFallbackPlanHelper.createStep(
        '完成检查并交付', project,
        '补齐关键缺口，检查结果并保存或提交。', 1,
        '用最后一轮形成可验证的完成结果。'));
    } else {
      steps.push(LocalFallbackPlanHelper.createStep(
        '明确完成标准与所需材料', project,
        `写下“${normalizedGoal}”的完成标准，只准备本轮必需的材料。`, 1,
        '先消除启动阻力，避免在准备阶段消耗过多时间。'));
      let remainingCorePomodoros = Math.max(1, pomodoros - 2);
      let coreIndex = 1;
      while (remainingCorePomodoros > 0) {
        const chunk = Math.min(4, remainingCorePomodoros);
        steps.push(LocalFallbackPlanHelper.createStep(
          `完成核心成果第 ${coreIndex} 部分`, project,
          `集中完成“${normalizedGoal}”的第 ${coreIndex} 部分，并保存本轮可检查的阶段结果。`,
          chunk, '把主要时间投入最有价值的交付内容，同时控制单步粒度。'));
        remainingCorePomodoros -= chunk;
        coreIndex += 1;
      }
      steps.push(LocalFallbackPlanHelper.createStep(
        '检查、修正并交付', project,
        '按照完成标准检查结果，修正关键问题并保存或提交。', 1,
        '预留一轮用于收尾，避免只有过程而没有最终成果。'));
    }

    const deadlineText = deadline.trim().length > 0 ? `，截止时间为${deadline.trim()}` : '';
    return {
      summary: `本地应急计划：在 ${Math.max(0, Math.round(availableMinutes))} 分钟内安排 ` +
        `${pomodoros} 个番茄${deadlineText}。该计划未调用 AI，可在联网后继续让智能体优化。`,
      steps: steps
    };
  }
}
