import { AiPlan, AiPlanStep } from './AiAgentModels';

export interface AiPlanCompletionResult {
  matched: boolean;
  plan: AiPlan;
  nextStep?: AiPlanStep;
}

export class AiPlanProgressHelper {
  static isTrackedConversation(source: string, taskConversationId: string,
    planConversationId: string): boolean {
    return source === 'ai' && taskConversationId.length > 0 &&
      taskConversationId === planConversationId;
  }

  static completeStep(plan: AiPlan, task: string, project: string): AiPlanCompletionResult {
    let matched = false;
    const updatedSteps: AiPlanStep[] = [];
    for (const step of plan.steps) {
      if (!matched && !step.completed && step.title === task && step.project === project) {
        updatedSteps.push({
          title: step.title,
          project: step.project,
          tag: step.tag,
          note: step.note,
          estimatedPomodoros: step.estimatedPomodoros,
          reason: step.reason,
          completed: true
        });
        matched = true;
      } else {
        updatedSteps.push(step);
      }
    }

    const updatedPlan: AiPlan = { summary: plan.summary, steps: updatedSteps };
    if (!matched) {
      return { matched: false, plan: updatedPlan };
    }

    for (const step of updatedSteps) {
      if (!step.completed) {
        return { matched: true, plan: updatedPlan, nextStep: step };
      }
    }
    return { matched: true, plan: updatedPlan };
  }
}
