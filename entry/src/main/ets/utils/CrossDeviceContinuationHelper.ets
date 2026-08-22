import { AiAgentState, AiChatMessage } from './AiAgentModels';
import { PreferencesHelper, SessionRecord, TaskContext, TimerState } from './PreferencesHelper';

const CONTINUATION_SCHEMA_VERSION = 1;
const MAX_CONTINUATION_CHARACTERS = 60000;
const MAX_TRANSFERRED_MESSAGES = 8;
const MAX_TRANSFERRED_SESSIONS = 50;
export const CONTINUATION_REVISION_KEY = 'pomodoroContinuationRevision';

export interface PomodoroContinuationSnapshot {
  schemaVersion: number;
  transferId: string;
  transferredAt: number;
  timerState: TimerState | null;
  taskContext: TaskContext;
  agentState: AiAgentState;
  recentSessions: SessionRecord[];
}

export interface ContinuationParseResult {
  success: boolean;
  message: string;
  snapshot: PomodoroContinuationSnapshot | undefined;
}

export interface ContinuationRestoreResult {
  success: boolean;
  duplicate: boolean;
  stale: boolean;
  message: string;
}

export type ContinuationTransferDecision = 'accept' | 'duplicate' | 'stale';

export class CrossDeviceContinuationHelper {
  private static copyRecentMessages(messages: AiChatMessage[]): AiChatMessage[] {
    const result: AiChatMessage[] = [];
    const startIndex = Math.max(0, messages.length - MAX_TRANSFERRED_MESSAGES);
    for (let index = startIndex; index < messages.length; index++) {
      const message = messages[index];
      if (message !== undefined) {
        result.push({
          role: message.role,
          content: message.content.substring(0, 2000),
          createdAt: message.createdAt
        });
      }
    }
    return result;
  }

  private static compactAgentState(state: AiAgentState): AiAgentState {
    return {
      id: state.id,
      title: state.title,
      createdAt: state.createdAt,
      messages: CrossDeviceContinuationHelper.copyRecentMessages(state.messages),
      plan: state.plan,
      updatedAt: state.updatedAt,
      needsReview: state.needsReview,
      lastCompletedStepTitle: state.lastCompletedStepTitle,
      lastCompletedStepProject: state.lastCompletedStepProject,
      availableMinutes: state.availableMinutes,
      deadline: state.deadline,
      primaryGoal: state.primaryGoal,
      memory: state.memory,
      goalDrift: state.goalDrift,
      lastAutoReviewAttemptTitle: state.lastAutoReviewAttemptTitle,
      lastExecutionReplanKey: state.lastExecutionReplanKey,
      planSource: state.planSource,
      previousPlan: state.previousPlan,
      lastExecutionCheckIn: state.lastExecutionCheckIn,
      requestTraces: state.requestTraces,
      tokenBudget: state.tokenBudget,
      consumedTokens: state.consumedTokens,
      pendingPlan: state.pendingPlan,
      pendingPlanReply: state.pendingPlanReply,
      pendingPlanRequest: state.pendingPlanRequest,
      pendingPlanSource: state.pendingPlanSource,
      pendingPlanCreatedAt: state.pendingPlanCreatedAt,
      pendingPrimaryGoal: state.pendingPrimaryGoal,
      pendingPlanSelections: state.pendingPlanSelections
    };
  }

  private static copySessionRecord(record: SessionRecord): SessionRecord {
    return {
      id: record.id,
      date: record.date,
      workSeconds: record.workSeconds,
      startedAt: record.startedAt,
      completedAt: record.completedAt,
      type: record.type,
      status: record.status,
      plannedSeconds: record.plannedSeconds,
      task: record.task === undefined ? undefined : record.task.substring(0, 120),
      project: record.project === undefined ? undefined : record.project.substring(0, 80),
      tag: record.tag === undefined ? undefined : record.tag.substring(0, 40),
      note: record.note === undefined ? undefined : record.note.substring(0, 300),
      source: record.source,
      focusRating: record.focusRating,
      energyRating: record.energyRating,
      interruptionReason: record.interruptionReason,
      outcomeNote: record.outcomeNote === undefined ? undefined : record.outcomeNote.substring(0, 300),
      reflectedAt: record.reflectedAt
    };
  }

  private static copyRecentSessions(records: SessionRecord[]): SessionRecord[] {
    const result: SessionRecord[] = [];
    const startIndex = Math.max(0, records.length - MAX_TRANSFERRED_SESSIONS);
    for (let index = startIndex; index < records.length; index++) {
      const record = records[index];
      if (record !== undefined) {
        result.push(CrossDeviceContinuationHelper.copySessionRecord(record));
      }
    }
    return result;
  }

  static createSnapshot(timerState: TimerState | null, taskContext: TaskContext,
    agentState: AiAgentState, records: SessionRecord[], now: number): PomodoroContinuationSnapshot {
    const timerMarker = timerState === null || timerState.deadlineAt === undefined ? 0 : timerState.deadlineAt;
    const conversationMarker = agentState.id.length > 0 ? agentState.id : 'no-agent';
    return {
      schemaVersion: CONTINUATION_SCHEMA_VERSION,
      transferId: `${now}-${timerMarker}-${conversationMarker}`,
      transferredAt: now,
      timerState: timerState,
      taskContext: {
        task: taskContext.task.substring(0, 120),
        project: taskContext.project.substring(0, 80),
        tag: taskContext.tag.substring(0, 40),
        note: taskContext.note.substring(0, 300),
        estimatedPomodoros: Math.max(1, Math.min(20, Math.round(taskContext.estimatedPomodoros))),
        trackingStartedAt: taskContext.trackingStartedAt,
        source: taskContext.source,
        agentConversationId: taskContext.agentConversationId
      },
      agentState: CrossDeviceContinuationHelper.compactAgentState(agentState),
      recentSessions: CrossDeviceContinuationHelper.copyRecentSessions(records)
    };
  }

  private static validTimerState(state: TimerState | null): boolean {
    if (state === null) {
      return true;
    }
    return Number.isFinite(state.remainingSeconds) && Number.isFinite(state.totalSeconds) &&
      state.remainingSeconds >= 0 && state.totalSeconds > 0 && state.totalSeconds <= 24 * 60 * 60 &&
      typeof state.isWorkMode === 'boolean' && typeof state.isRunning === 'boolean' &&
      Number.isFinite(state.completedSessions) && state.completedSessions >= 0 &&
      Number.isFinite(state.savedAt) && state.savedAt > 0;
  }

  private static validTaskContext(task: TaskContext): boolean {
    return typeof task.task === 'string' && typeof task.project === 'string' &&
      typeof task.tag === 'string' && typeof task.note === 'string' &&
      Number.isFinite(task.estimatedPomodoros) && task.estimatedPomodoros >= 1 &&
      task.estimatedPomodoros <= 20;
  }

  private static validAgentState(state: AiAgentState): boolean {
    return typeof state.id === 'string' && typeof state.title === 'string' &&
      Array.isArray(state.messages) && state.plan !== undefined &&
      typeof state.plan.summary === 'string' && Array.isArray(state.plan.steps) &&
      Number.isFinite(state.updatedAt);
  }

  private static validSessionRecord(record: SessionRecord): boolean {
    return typeof record.date === 'string' && record.date.length === 10 &&
      Number.isFinite(record.workSeconds) && record.workSeconds >= 0 &&
      Number.isFinite(record.completedAt) && record.completedAt > 0;
  }

  static serialize(snapshot: PomodoroContinuationSnapshot): string {
    const serialized = JSON.stringify(snapshot);
    if (serialized.length > MAX_CONTINUATION_CHARACTERS) {
      throw new Error('Continuation payload is too large');
    }
    return serialized;
  }

  static parse(serialized: string): ContinuationParseResult {
    if (serialized.length === 0 || serialized.length > MAX_CONTINUATION_CHARACTERS) {
      return { success: false, message: '接续数据为空或过大', snapshot: undefined };
    }
    try {
      const snapshot = JSON.parse(serialized) as PomodoroContinuationSnapshot;
      if (snapshot.schemaVersion !== CONTINUATION_SCHEMA_VERSION ||
        typeof snapshot.transferId !== 'string' || snapshot.transferId.length === 0 ||
        !Number.isFinite(snapshot.transferredAt) || snapshot.transferredAt <= 0 ||
        !CrossDeviceContinuationHelper.validTimerState(snapshot.timerState) ||
        !CrossDeviceContinuationHelper.validTaskContext(snapshot.taskContext) ||
        !CrossDeviceContinuationHelper.validAgentState(snapshot.agentState) ||
        !Array.isArray(snapshot.recentSessions)) {
        return { success: false, message: '接续数据格式或版本不受支持', snapshot: undefined };
      }
      const validRecords: SessionRecord[] = [];
      for (const record of snapshot.recentSessions) {
        if (CrossDeviceContinuationHelper.validSessionRecord(record)) {
          validRecords.push(record);
        }
      }
      snapshot.recentSessions = validRecords;
      return { success: true, message: '接续数据有效', snapshot: snapshot };
    } catch {
      return { success: false, message: '接续数据无法解析', snapshot: undefined };
    }
  }

  static decideTransfer(previousTransferId: string, previousTransferredAt: number,
    snapshot: PomodoroContinuationSnapshot): ContinuationTransferDecision {
    if (previousTransferId === snapshot.transferId) {
      return 'duplicate';
    }
    if (previousTransferredAt > 0 && snapshot.transferredAt <= previousTransferredAt) {
      return 'stale';
    }
    return 'accept';
  }

  static async capture(context: Context, now: number = Date.now()): Promise<string> {
    const timerState = await PreferencesHelper.loadTimerState(context);
    const taskContext = await PreferencesHelper.loadTaskContext(context);
    const agentState = await PreferencesHelper.loadAiAgentState(context);
    const sessionHistory = await PreferencesHelper.loadSessionHistory(context);
    return CrossDeviceContinuationHelper.serialize(CrossDeviceContinuationHelper.createSnapshot(
      timerState, taskContext, agentState, sessionHistory, now));
  }

  static async restore(context: Context, serialized: string): Promise<ContinuationRestoreResult> {
    const parsed = CrossDeviceContinuationHelper.parse(serialized);
    if (!parsed.success || parsed.snapshot === undefined) {
      return { success: false, duplicate: false, stale: false, message: parsed.message };
    }
    const snapshot = parsed.snapshot;
    const previousTransferId = await PreferencesHelper.loadContinuationTransferId(context);
    const previousTransferredAt = await PreferencesHelper.loadContinuationTransferredAt(context);
    const decision = CrossDeviceContinuationHelper.decideTransfer(
      previousTransferId, previousTransferredAt, snapshot);
    if (decision === 'duplicate') {
      return { success: true, duplicate: true, stale: false, message: '该接续状态已应用，无需重复恢复' };
    }
    if (decision === 'stale') {
      return { success: false, duplicate: false, stale: true,
        message: '接续状态早于本机已恢复版本，已拒绝覆盖' };
    }
    try {
      if (snapshot.timerState !== null) {
        await PreferencesHelper.saveTimerState(context, snapshot.timerState);
      } else {
        await PreferencesHelper.clearTimerState(context);
      }
      await PreferencesHelper.saveTaskContext(context, snapshot.taskContext);
      await PreferencesHelper.saveAiAgentState(context, snapshot.agentState);
      await PreferencesHelper.mergeSessionHistory(context, snapshot.recentSessions);
      await PreferencesHelper.saveContinuationMarker(
        context, snapshot.transferId, snapshot.transferredAt);
      return { success: true, duplicate: false, stale: false,
        message: '已恢复计时、任务和智能体计划' };
    } catch {
      return { success: false, duplicate: false, stale: false, message: '接续状态写入失败' };
    }
  }
}
