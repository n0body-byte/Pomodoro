import { AiPlan, AiPlanSnapshot, AiPlanStep } from './AiAgentModels';

export class AiPlanVersionHelper {
  private static copyStep(step: AiPlanStep): AiPlanStep {
    return {
      title: step.title,
      project: step.project,
      tag: step.tag,
      note: step.note,
      estimatedPomodoros: step.estimatedPomodoros,
      reason: step.reason,
      completed: step.completed
    };
  }

  static copyPlan(plan: AiPlan): AiPlan {
    const steps: AiPlanStep[] = [];
    for (const step of plan.steps) {
      steps.push(AiPlanVersionHelper.copyStep(step));
    }
    return { summary: plan.summary, steps: steps };
  }

  static areEquivalent(first: AiPlan, second: AiPlan): boolean {
    if (first.summary !== second.summary || first.steps.length !== second.steps.length) {
      return false;
    }
    for (let index = 0; index < first.steps.length; index++) {
      const left = first.steps[index];
      const right = second.steps[index];
      if (left === undefined || right === undefined || left.title !== right.title ||
        left.project !== right.project || left.tag !== right.tag || left.note !== right.note ||
        left.estimatedPomodoros !== right.estimatedPomodoros || left.reason !== right.reason ||
        left.completed !== right.completed) {
        return false;
      }
    }
    return true;
  }

  static capture(currentPlan: AiPlan, nextPlan: AiPlan, currentSource: string,
    savedAt: number): AiPlanSnapshot | undefined {
    if (currentPlan.steps.length === 0 || AiPlanVersionHelper.areEquivalent(currentPlan, nextPlan)) {
      return undefined;
    }
    return {
      plan: AiPlanVersionHelper.copyPlan(currentPlan),
      source: currentSource.length > 0 ? currentSource : 'none',
      savedAt: savedAt
    };
  }
}
