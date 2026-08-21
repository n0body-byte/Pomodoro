import { AiExecutionCheckIn, AiPlan, AiPlanStep } from './AiAgentModels';

export interface AiExecutionCheckInValidation {
  ready: boolean;
  message: string;
}

export class AiExecutionCheckInHelper {
  private static isSupportedOutcome(outcome: string): boolean {
    return outcome === 'achieved' || outcome === 'partial' || outcome === 'blocked';
  }

  private static isVagueDetail(detail: string): boolean {
    const normalized = detail.replace(/\s/g, '');
    const vagueValues: string[] = ['完成了', '做完了', '差不多', '有问题', '没做完', '卡住了', '不知道'];
    for (const value of vagueValues) {
      if (normalized === value) {
        return true;
      }
    }
    return false;
  }

  static validate(outcome: string, detail: string): AiExecutionCheckInValidation {
    if (!AiExecutionCheckInHelper.isSupportedOutcome(outcome)) {
      return { ready: false, message: '请选择已交付、部分完成或遇到阻塞' };
    }
    const normalized = detail.trim();
    if (normalized.length < 4 || AiExecutionCheckInHelper.isVagueDetail(normalized)) {
      return {
        ready: false,
        message: outcome === 'achieved' ?
          '请写下可核验结果，例如文件名、完成数量或提交状态' :
          '请具体说明已完成到哪里，以及剩余问题或阻塞原因'
      };
    }
    return { ready: true, message: '执行结果可以用于复盘' };
  }

  static create(stepTitle: string, project: string, outcome: string,
    detail: string, recordedAt: number): AiExecutionCheckIn | undefined {
    const validation = AiExecutionCheckInHelper.validate(outcome, detail);
    if (!validation.ready) {
      return undefined;
    }
    const normalizedOutcome: 'achieved' | 'partial' | 'blocked' = outcome === 'partial' ?
      'partial' : (outcome === 'blocked' ? 'blocked' : 'achieved');
    return {
      stepTitle: stepTitle,
      project: project,
      outcome: normalizedOutcome,
      detail: detail.trim().substring(0, 500),
      recordedAt: recordedAt
    };
  }

  static matchesStep(checkIn: AiExecutionCheckIn | undefined,
    stepTitle: string, project: string = ''): boolean {
    return checkIn !== undefined && checkIn.stepTitle === stepTitle &&
      (project.length === 0 || checkIn.project === project) &&
      typeof checkIn.detail === 'string' && checkIn.detail.length > 0;
  }

  static applyOutcome(plan: AiPlan, checkIn: AiExecutionCheckIn): AiPlan {
    const steps: AiPlanStep[] = [];
    let matched = false;
    for (const step of plan.steps) {
      if (!matched && step.title === checkIn.stepTitle && step.project === checkIn.project) {
        steps.push({
          title: step.title,
          project: step.project,
          tag: step.tag,
          note: step.note,
          estimatedPomodoros: step.estimatedPomodoros,
          reason: step.reason,
          completed: checkIn.outcome === 'achieved'
        });
        matched = true;
      } else {
        steps.push(step);
      }
    }
    return { summary: plan.summary, steps: steps };
  }

  static outcomeLabel(outcome: string): string {
    if (outcome === 'achieved') {
      return '已形成交付';
    }
    if (outcome === 'partial') {
      return '部分完成';
    }
    return '遇到阻塞';
  }

  static buildReviewMessage(checkIn: AiExecutionCheckIn): string {
    const outcome = AiExecutionCheckInHelper.outcomeLabel(checkIn.outcome);
    const guidance = checkIn.outcome === 'achieved' ?
      '核对交付物是否满足完成标准，再给出下一步。' :
      '不要把该步骤视为已完成；请依据现状拆小、调整估时或提供解除阻塞的具体动作。';
    return `步骤“${checkIn.stepTitle}”的执行核验结果：${outcome}。` +
      `用户记录：${checkIn.detail}。${guidance}`;
  }
}
