import {
  AiAgentMemory,
  AiChatMessage,
  AiExecutionInsight,
  AiFocusContext,
  AiGoalDriftInsight,
  AiPlan,
  AiPlanStep
} from './AiAgentModels';

export interface AiExecutionRecord {
  completedAt: number;
  workSeconds: number;
  type?: string;
  status?: string;
  task?: string;
  project?: string;
}

export class AiAgentP1Helper {
  static emptyDrift(): AiGoalDriftInsight {
    return {
      status: 'none',
      title: '目标保持一致',
      description: '暂无需要处理的目标偏航。',
      similarityPercent: 100
    };
  }

  static emptyExecution(): AiExecutionInsight {
    return {
      status: 'no_data',
      title: '等待执行数据',
      description: '完成计划步骤后，智能体会用真实专注记录校准后续安排。',
      expectedMinutes: 0,
      actualMinutes: 0,
      varianceMinutes: 0,
      variancePercent: 0,
      matchedSessions: 0,
      shouldReplan: false
    };
  }

  static emptyMemory(): AiAgentMemory {
    return {
      primaryGoal: '',
      longTermSummary: '暂无长期专注数据。',
      shortTermSummary: '暂无正在执行的计划。',
      updatedAt: 0
    };
  }

  private static normalizeText(value: string): string {
    const ignored = ' \n\r\t，。！？、；：,.!?;:（）()【】[]“”\"\'的了和是我你请把将再一下这个当前需要';
    let result = '';
    const lower = value.toLowerCase();
    for (let index = 0; index < lower.length; index++) {
      const char = lower.charAt(index);
      if (ignored.indexOf(char) < 0 && result.indexOf(char) < 0) {
        result += char;
      }
    }
    return result;
  }

  private static overlapPercent(base: string, candidate: string): number {
    const normalizedBase = AiAgentP1Helper.normalizeText(base);
    const normalizedCandidate = AiAgentP1Helper.normalizeText(candidate);
    if (normalizedBase.length === 0 || normalizedCandidate.length === 0) {
      return 0;
    }
    let matched = 0;
    for (let index = 0; index < normalizedCandidate.length; index++) {
      if (normalizedBase.indexOf(normalizedCandidate.charAt(index)) >= 0) {
        matched += 1;
      }
    }
    return Math.round(matched * 100 / normalizedCandidate.length);
  }

  private static isWorkflowInstruction(message: string): boolean {
    const keywords: string[] = [
      '复盘', '调整', '拆细', '压缩', '时间', '完成', '继续', '下一步', '计划', '重排', '执行', '进度', '延期'
    ];
    for (const keyword of keywords) {
      if (message.indexOf(keyword) >= 0) {
        return true;
      }
    }
    return false;
  }

  private static planOverlapPercent(plan: AiPlan, message: string): number {
    let best = 0;
    for (const step of plan.steps) {
      best = Math.max(best, AiAgentP1Helper.overlapPercent(step.title, message));
      if (step.project.length > 0) {
        best = Math.max(best, AiAgentP1Helper.overlapPercent(step.project, message));
      }
    }
    return best;
  }

  static detectGoalDrift(primaryGoal: string, message: string, plan: AiPlan): AiGoalDriftInsight {
    const normalizedGoal = primaryGoal.trim();
    const normalizedMessage = message.trim();
    if (normalizedGoal.length < 4 || normalizedMessage.length < 4) {
      return AiAgentP1Helper.emptyDrift();
    }
    const explicitChange = normalizedMessage.indexOf('新目标') >= 0 ||
      normalizedMessage.indexOf('改成') >= 0 || normalizedMessage.indexOf('换成') >= 0 ||
      normalizedMessage.indexOf('不做了') >= 0;
    const goalSimilarity = AiAgentP1Helper.overlapPercent(normalizedGoal, normalizedMessage);
    const planSimilarity = AiAgentP1Helper.planOverlapPercent(plan, normalizedMessage);
    const similarity = Math.max(goalSimilarity, planSimilarity);
    if (!explicitChange && (similarity >= 25 || AiAgentP1Helper.isWorkflowInstruction(normalizedMessage))) {
      return {
        status: 'aligned',
        title: '指令与主目标一致',
        description: '这次调整仍围绕当前目标，智能体可以直接继续。',
        similarityPercent: similarity
      };
    }
    return {
      status: explicitChange ? 'changed' : 'possible',
      title: explicitChange ? '检测到目标切换' : '这条指令可能偏离主目标',
      description: `当前主目标是“${normalizedGoal.substring(0, 36)}”。` +
        '智能体会先保留原目标；如果确实要换目标，请在目标输入区重新生成计划。',
      similarityPercent: similarity
    };
  }

  static buildMemory(primaryGoal: string, plan: AiPlan, context: AiFocusContext,
    lastCompletedStepTitle: string, messages: AiChatMessage[]): AiAgentMemory {
    let completed = 0;
    let nextTitle = '';
    for (const step of plan.steps) {
      if (step.completed) {
        completed += 1;
      } else if (nextTitle.length === 0) {
        nextTitle = step.title;
      }
    }
    const sevenDayMinutes = Math.round(context.sevenDayWorkSeconds / 60);
    const todayMinutes = Math.round(context.todayWorkSeconds / 60);
    const completionTotal = context.sevenDayCompletedSessions + context.sevenDayAbandonedSessions;
    const completionRate = completionTotal > 0 ?
      Math.round(context.sevenDayCompletedSessions * 100 / completionTotal) : 0;
    const longTerm = `近 7 天专注 ${sevenDayMinutes} 分钟，完成 ${context.sevenDayCompletedSessions} 轮，` +
      `部分完成 ${context.sevenDayAbandonedSessions} 轮，执行完成率 ${completionRate}%；` +
      `常用节奏为专注 ${context.workMinutes} 分钟、休息 ${context.breakMinutes} 分钟。`;
    let shortTerm = primaryGoal.trim().length > 0 ? `主目标：${primaryGoal.trim()}；` : '主目标尚未明确；';
    shortTerm += `今日已专注 ${todayMinutes} 分钟；计划完成 ${completed}/${plan.steps.length} 步。`;
    if (lastCompletedStepTitle.length > 0) {
      shortTerm += ` 最近完成“${lastCompletedStepTitle}”。`;
    }
    if (nextTitle.length > 0) {
      shortTerm += ` 下一步是“${nextTitle}”。`;
    }
    if (messages.length > 0) {
      shortTerm += ` 当前对话保留最近 ${Math.min(messages.length, 30)} 条消息。`;
    }
    return {
      primaryGoal: primaryGoal.trim(),
      longTermSummary: longTerm,
      shortTermSummary: shortTerm,
      updatedAt: Date.now()
    };
  }

  private static matchesCompletedStep(record: AiExecutionRecord, steps: AiPlanStep[]): boolean {
    const task = record.task === undefined ? '' : record.task;
    const project = record.project === undefined ? '' : record.project;
    for (const step of steps) {
      if (step.completed && step.title === task && step.project === project) {
        return true;
      }
    }
    return false;
  }

  static analyzeExecution(plan: AiPlan, records: AiExecutionRecord[], conversationCreatedAt: number,
    workMinutes: number): AiExecutionInsight {
    let expectedMinutes = 0;
    for (const step of plan.steps) {
      if (step.completed) {
        expectedMinutes += step.estimatedPomodoros * workMinutes;
      }
    }
    if (expectedMinutes <= 0) {
      return AiAgentP1Helper.emptyExecution();
    }
    let actualSeconds = 0;
    let matchedSessions = 0;
    for (const record of records) {
      const afterConversationStart = conversationCreatedAt <= 0 || record.completedAt >= conversationCreatedAt;
      if (afterConversationStart && record.type !== 'break' && record.status !== 'skipped' &&
        AiAgentP1Helper.matchesCompletedStep(record, plan.steps)) {
        actualSeconds += record.workSeconds;
        matchedSessions += 1;
      }
    }
    if (matchedSessions === 0) {
      const empty = AiAgentP1Helper.emptyExecution();
      empty.description = '步骤已标记完成，但还没有匹配到对应的真实计时记录，暂不自动重排。';
      empty.expectedMinutes = expectedMinutes;
      return empty;
    }
    const actualMinutes = Math.round(actualSeconds / 60);
    const varianceMinutes = actualMinutes - expectedMinutes;
    const variancePercent = Math.round(varianceMinutes * 100 / expectedMinutes);
    if (variancePercent >= 25) {
      return {
        status: 'overrun',
        title: '实际执行比计划更慢',
        description: `已完成步骤预计 ${expectedMinutes} 分钟，实际用了 ${actualMinutes} 分钟，` +
          `超出 ${varianceMinutes} 分钟。建议按真实速度重排剩余计划。`,
        expectedMinutes: expectedMinutes,
        actualMinutes: actualMinutes,
        varianceMinutes: varianceMinutes,
        variancePercent: variancePercent,
        matchedSessions: matchedSessions,
        shouldReplan: true
      };
    }
    if (variancePercent <= -25) {
      return {
        status: 'ahead',
        title: '实际执行快于计划',
        description: `已完成步骤预计 ${expectedMinutes} 分钟，实际用了 ${actualMinutes} 分钟，` +
          `节省 ${Math.abs(varianceMinutes)} 分钟。可以提前后续任务或增加检查缓冲。`,
        expectedMinutes: expectedMinutes,
        actualMinutes: actualMinutes,
        varianceMinutes: varianceMinutes,
        variancePercent: variancePercent,
        matchedSessions: matchedSessions,
        shouldReplan: true
      };
    }
    return {
      status: 'on_track',
      title: '实际进度符合计划',
      description: `已完成步骤预计 ${expectedMinutes} 分钟，实际用了 ${actualMinutes} 分钟，偏差在可接受范围内。`,
      expectedMinutes: expectedMinutes,
      actualMinutes: actualMinutes,
      varianceMinutes: varianceMinutes,
      variancePercent: variancePercent,
      matchedSessions: matchedSessions,
      shouldReplan: false
    };
  }
}
