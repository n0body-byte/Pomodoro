import { AiPlan, AiPlanChange, AiPlanStep } from './AiAgentModels';

export interface AiPlanProposalStats {
  added: number;
  removed: number;
  modified: number;
  selected: number;
  currentPomodoros: number;
  candidatePomodoros: number;
}

export class AiPlanProposalHelper {
  static copyStep(step: AiPlanStep): AiPlanStep {
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

  static areStepsEquivalent(first: AiPlanStep, second: AiPlanStep): boolean {
    return first.title === second.title && first.project === second.project &&
      first.tag === second.tag && first.note === second.note &&
      first.estimatedPomodoros === second.estimatedPomodoros &&
      first.reason === second.reason && first.completed === second.completed;
  }

  static buildChanges(current: AiPlanStep[], candidate: AiPlanStep[], selections: boolean[]): AiPlanChange[] {
    const changes: AiPlanChange[] = [];
    const count = Math.max(current.length, candidate.length);
    for (let index = 0; index < count; index++) {
      const currentStep = current[index];
      const candidateStep = candidate[index];
      let type: 'added' | 'removed' | 'modified' | 'unchanged' = 'unchanged';
      if (currentStep === undefined && candidateStep !== undefined) {
        type = 'added';
      } else if (currentStep !== undefined && candidateStep === undefined) {
        type = 'removed';
      } else if (currentStep !== undefined && candidateStep !== undefined &&
        !AiPlanProposalHelper.areStepsEquivalent(currentStep, candidateStep)) {
        type = 'modified';
      }
      changes.push({
        index: index,
        type: type,
        currentStep: currentStep,
        candidateStep: candidateStep,
        selected: type === 'unchanged' ? false : selections[index] !== false
      });
    }
    return changes;
  }

  static merge(current: AiPlan, candidate: AiPlan, selections: boolean[]): AiPlan {
    const changes = AiPlanProposalHelper.buildChanges(current.steps, candidate.steps, selections);
    const steps: AiPlanStep[] = [];
    let appliedChange = false;
    for (const change of changes) {
      if (change.type === 'unchanged') {
        if (change.currentStep !== undefined) {
          steps.push(AiPlanProposalHelper.copyStep(change.currentStep));
        }
      } else if (change.selected) {
        appliedChange = true;
        if (change.type !== 'removed' && change.candidateStep !== undefined) {
          steps.push(AiPlanProposalHelper.copyStep(change.candidateStep));
        }
      } else if (change.currentStep !== undefined) {
        steps.push(AiPlanProposalHelper.copyStep(change.currentStep));
      }
    }
    return {
      summary: appliedChange ? candidate.summary : current.summary,
      steps: steps
    };
  }

  static getStats(current: AiPlanStep[], candidate: AiPlanStep[], selections: boolean[]): AiPlanProposalStats {
    const changes = AiPlanProposalHelper.buildChanges(current, candidate, selections);
    let added = 0;
    let removed = 0;
    let modified = 0;
    let selected = 0;
    for (const change of changes) {
      if (change.type === 'added') {
        added += 1;
      } else if (change.type === 'removed') {
        removed += 1;
      } else if (change.type === 'modified') {
        modified += 1;
      }
      if (change.selected) {
        selected += 1;
      }
    }
    return {
      added: added,
      removed: removed,
      modified: modified,
      selected: selected,
      currentPomodoros: AiPlanProposalHelper.totalPomodoros(current),
      candidatePomodoros: AiPlanProposalHelper.totalPomodoros(candidate)
    };
  }

  static totalPomodoros(steps: AiPlanStep[]): number {
    let total = 0;
    for (const step of steps) {
      if (!step.completed) {
        total += Math.max(1, Math.round(step.estimatedPomodoros));
      }
    }
    return total;
  }
}
