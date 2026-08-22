import { PreferencesHelper, SessionRecord } from '../utils/PreferencesHelper';
import { AiPlanResult, AiPlannerService } from '../utils/AiPlannerService';
import { AiPlanInsightHelper } from '../utils/AiPlanInsightHelper';
import { AiAgentDecisionHelper } from '../utils/AiAgentDecisionHelper';
import { AiAgentP1Helper, AiExecutionRecord } from '../utils/AiAgentP1Helper';
import { LocalFallbackPlanHelper } from '../utils/LocalFallbackPlanHelper';
import { AiGoalReadinessHelper } from '../utils/AiGoalReadinessHelper';
import { AiPlanQualityHelper } from '../utils/AiPlanQualityHelper';
import { AiPlanVersionHelper } from '../utils/AiPlanVersionHelper';
import { AiPlanProposalHelper, AiPlanProposalStats } from '../utils/AiPlanProposalHelper';
import { AiExecutionCheckInHelper } from '../utils/AiExecutionCheckInHelper';
import { AiRequestTraceHelper } from '../utils/AiRequestTraceHelper';
import { WearableAdjustmentRequest, WearableHealthHelper } from '../utils/WearableHealthHelper';
import { AiDeadlineHelper, AiDeadlineInsight } from '../utils/AiDeadlineHelper';
import {
  AiTokenBudgetHelper,
  AiTokenBudgetInsight,
  DEFAULT_AI_TOKEN_BUDGET
} from '../utils/AiTokenBudgetHelper';
import {
  AiAgentDecision,
  AiAgentMemory,
  AiAgentResult,
  AiAgentState,
  AiChatMessage,
  AiConversationSummary,
  AiExecutionCheckIn,
  AiExecutionInsight,
  AiFocusContext,
  AiGoalDriftInsight,
  AiGoalReadinessInsight,
  AiPlan,
  AiPlanChange,
  AiPlanInsight,
  AiPlanQualityInsight,
  AiPlanSnapshot,
  AiPlanStep,
  AiRequestTrace
} from '../utils/AiAgentModels';

@Component
export struct AiPlanner {
  @StorageLink('pomodoroContinuationRevision') @Watch('onContinuationRevision')
  continuationRevision: number = 0;
  @Prop @Watch('onActiveChange') active: boolean = false;
  @Prop workMinutes: number = 25;
  @Prop breakMinutes: number = 5;
  @Prop canApplyStep: boolean = true;
  @Prop todayWorkSeconds: number = 0;
  @Prop todayBreakSeconds: number = 0;
  @Prop todayCompletedSessions: number = 0;
  @Prop dailyTarget: number = 8;
  @Prop currentTask: string = '';
  @Prop currentProject: string = '';
  @Prop currentTaskCompleted: number = 0;
  @Prop currentTaskSource: string = 'manual';
  @Prop currentTaskConversationId: string = '';
  @Prop @Watch('onWearableAdjustmentChange') wearableAdjustment: WearableAdjustmentRequest =
    WearableHealthHelper.emptyAdjustmentRequest();
  @State serviceMode: string = 'deepseek';
  @State apiKey: string = '';
  @State deepSeekModel: string = 'deepseek-v4-flash';
  @State endpoint: string = '';
  @State goal: string = '';
  @State deadline: string = '';
  @State availableMinutes: number = 120;
  @State isLoading: boolean = false;
  @State isCheckingService: boolean = false;
  @State serviceCheckMessage: string = '';
  @State serviceCheckSuccess: boolean = false;
  @State showServiceSettings: boolean = false;
  @State summary: string = '';
  @State planSteps: AiPlanStep[] = [];
  @State chatMessages: AiChatMessage[] = [];
  @State followUp: string = '';
  @State errorMessage: string = '';
  @State successMessage: string = '';
  @State needsReview: boolean = false;
  @State lastCompletedStepTitle: string = '';
  @State lastCompletedStepProject: string = '';
  @State lastTotalTokens: number = 0;
  @State conversationId: string = '';
  @State conversationTitle: string = '';
  @State conversationCreatedAt: number = 0;
  @State conversationHistory: AiConversationSummary[] = [];
  @State showConversationHistory: boolean = false;
  @State pendingDeleteConversationId: string = '';
  @State pendingDeleteConversationTitle: string = '';
  @State lastFailedMessage: string = '';
  @State primaryGoal: string = '';
  @State agentMemory: AiAgentMemory = AiAgentP1Helper.emptyMemory();
  @State goalDriftInsight: AiGoalDriftInsight = AiAgentP1Helper.emptyDrift();
  @State executionInsight: AiExecutionInsight = AiAgentP1Helper.emptyExecution();
  @State autoReviewEnabled: boolean = false;
  @State lastAutoReviewAttemptTitle: string = '';
  @State showAgentMemory: boolean = false;
  @State lastExecutionReplanKey: string = '';
  @State planSource: string = 'none';
  @State previousPlanSummary: string = '';
  @State previousPlanSteps: AiPlanStep[] = [];
  @State previousPlanSource: string = 'none';
  @State previousPlanSavedAt: number = 0;
  @State lastExecutionCheckIn: AiExecutionCheckIn | undefined = undefined;
  @State executionCheckInDraft: string = '';
  @State requestTraces: AiRequestTrace[] = [];
  @State showRequestTraces: boolean = false;
  @State tokenBudget: number = DEFAULT_AI_TOKEN_BUDGET;
  @State consumedTokens: number = 0;
  @State pendingPlanSummary: string = '';
  @State pendingPlanSteps: AiPlanStep[] = [];
  @State pendingPlanReply: string = '';
  @State pendingPlanRequest: string = '';
  @State pendingPlanSource: string = 'ai';
  @State pendingPlanCreatedAt: number = 0;
  @State pendingPrimaryGoal: string = '';
  @State pendingPlanSelections: boolean[] = [];
  @State pendingWearableAdjustment: WearableAdjustmentRequest =
    WearableHealthHelper.emptyAdjustmentRequest();
  onApplyStep?: (step: AiPlanStep, conversationId: string) => void;
  onStartStep?: (step: AiPlanStep, conversationId: string) => void;
  onWearableAdjustmentConsumed?: () => void;

  private examples: string[] = [
    '今晚复习两章高数并完成课后题',
    '三天内完成产品需求文档初稿',
    '用两个小时整理本周工作并规划下周'
  ];
  private isRestoringContinuation: boolean = false;
  private proposalPrimaryGoalDraft: string = '';

  private onWearableAdjustmentChange(): void {
    if (this.wearableAdjustment.id.length === 0) {
      return;
    }
    this.pendingWearableAdjustment = {
      id: this.wearableAdjustment.id,
      createdAt: this.wearableAdjustment.createdAt,
      currentTask: this.wearableAdjustment.currentTask,
      recommendationTitle: this.wearableAdjustment.recommendationTitle,
      summary: this.wearableAdjustment.summary,
      allowedActions: this.wearableAdjustment.allowedActions,
      protectedRules: this.wearableAdjustment.protectedRules
    };
    this.successMessage = '已接收穿戴端调整请求，请先检查允许动作与保护规则';
  }

  private clearWearableAdjustment(): void {
    this.pendingWearableAdjustment = WearableHealthHelper.emptyAdjustmentRequest();
    if (this.onWearableAdjustmentConsumed) {
      this.onWearableAdjustmentConsumed();
    }
  }

  private confirmWearableAdjustment(): void {
    if (this.pendingWearableAdjustment.id.length === 0) {
      return;
    }
    const prompt = WearableHealthHelper.buildAgentPrompt(this.pendingWearableAdjustment);
    if (this.planSteps.length > 0) {
      this.followUp = prompt;
      this.successMessage = '约束已预填到“继续调整”，确认内容后点击发送';
    } else {
      this.goal = prompt;
      this.successMessage = '约束已预填到目标输入框，确认内容后点击生成计划';
    }
    this.clearWearableAdjustment();
  }

  async aboutToAppear(): Promise<void> {
    this.endpoint = await PreferencesHelper.loadAiServiceEndpoint(this.getContext());
    this.autoReviewEnabled = await PreferencesHelper.loadAiAutoReview(this.getContext());
    await this.loadAgentState();
    await this.loadConversationHistory();
    await this.refreshAgentAnalysis();
    await this.tryAutoReview();
    this.onWearableAdjustmentChange();
    this.showServiceSettings = this.apiKey.length === 0;
  }

  async onActiveChange(): Promise<void> {
    if (this.active) {
      await this.loadAgentState();
      await this.loadConversationHistory();
      await this.refreshAgentAnalysis();
      await this.tryAutoReview();
      this.onWearableAdjustmentChange();
    }
  }

  private async onContinuationRevision(): Promise<void> {
    if (this.continuationRevision <= 0 || this.isRestoringContinuation) {
      return;
    }
    this.isRestoringContinuation = true;
    try {
      await this.loadAgentState();
      await this.loadConversationHistory();
      await this.refreshAgentAnalysis();
    } finally {
      this.isRestoringContinuation = false;
    }
  }

  private getContext(): Context {
    return this.getUIContext().getHostContext()!;
  }

  private emptyPlan(): AiPlan {
    return { summary: '', steps: [] };
  }

  private copyStep(step: AiPlanStep, completed: boolean = step.completed): AiPlanStep {
    return {
      title: step.title,
      project: step.project,
      tag: step.tag,
      note: step.note,
      estimatedPomodoros: step.estimatedPomodoros,
      reason: step.reason,
      completed: completed
    };
  }

  private async loadAgentState(): Promise<void> {
    const state = await PreferencesHelper.loadAiAgentState(this.getContext());
    this.applyAgentState(state);
  }

  private applyAgentState(state: AiAgentState): void {
    const steps: AiPlanStep[] = [];
    for (const step of state.plan.steps) {
      steps.push(this.copyStep(step, step.completed === true));
    }
    this.chatMessages = state.messages;
    this.summary = state.plan.summary;
    this.planSteps = steps;
    this.needsReview = state.needsReview;
    this.lastCompletedStepTitle = state.lastCompletedStepTitle;
    this.lastCompletedStepProject = typeof state.lastCompletedStepProject === 'string' ?
      state.lastCompletedStepProject : '';
    this.conversationId = state.id;
    this.conversationTitle = state.title;
    this.conversationCreatedAt = state.createdAt;
    if (typeof state.availableMinutes === 'number' && state.availableMinutes > 0) {
      this.availableMinutes = Math.round(state.availableMinutes);
    }
    this.deadline = typeof state.deadline === 'string' ? state.deadline : '';
    this.primaryGoal = typeof state.primaryGoal === 'string' ? state.primaryGoal : '';
    this.agentMemory = state.memory !== undefined ? state.memory : AiAgentP1Helper.emptyMemory();
    if (this.primaryGoal.length === 0 && this.agentMemory.primaryGoal.length > 0) {
      this.primaryGoal = this.agentMemory.primaryGoal;
    }
    this.goalDriftInsight = state.goalDrift !== undefined ?
      state.goalDrift : AiAgentP1Helper.emptyDrift();
    this.lastAutoReviewAttemptTitle = typeof state.lastAutoReviewAttemptTitle === 'string' ?
      state.lastAutoReviewAttemptTitle : '';
    this.lastExecutionReplanKey = typeof state.lastExecutionReplanKey === 'string' ?
      state.lastExecutionReplanKey : '';
    this.lastExecutionCheckIn = state.lastExecutionCheckIn;
    this.requestTraces = Array.isArray(state.requestTraces) ? state.requestTraces : [];
    this.tokenBudget = AiTokenBudgetHelper.normalizeBudget(
      typeof state.tokenBudget === 'number' ? state.tokenBudget : DEFAULT_AI_TOKEN_BUDGET);
    this.consumedTokens = typeof state.consumedTokens === 'number' ?
      Math.max(0, Math.round(state.consumedTokens)) : 0;
    if (state.pendingPlan !== undefined && Array.isArray(state.pendingPlan.steps) &&
      state.pendingPlan.steps.length > 0) {
      this.pendingPlanSummary = state.pendingPlan.summary;
      this.pendingPlanSteps = state.pendingPlan.steps;
      this.pendingPlanReply = typeof state.pendingPlanReply === 'string' ? state.pendingPlanReply : '';
      this.pendingPlanRequest = typeof state.pendingPlanRequest === 'string' ? state.pendingPlanRequest : '';
      this.pendingPlanSource = typeof state.pendingPlanSource === 'string' ? state.pendingPlanSource : 'ai';
      this.pendingPlanCreatedAt = typeof state.pendingPlanCreatedAt === 'number' ?
        state.pendingPlanCreatedAt : 0;
      this.pendingPrimaryGoal = typeof state.pendingPrimaryGoal === 'string' ?
        state.pendingPrimaryGoal : '';
      const savedSelections = Array.isArray(state.pendingPlanSelections) ?
        state.pendingPlanSelections : [];
      const selections: boolean[] = [];
      const count = Math.max(this.planSteps.length, state.pendingPlan.steps.length);
      for (let index = 0; index < count; index++) {
        selections.push(savedSelections[index] !== false);
      }
      this.pendingPlanSelections = selections;
    } else {
      this.clearPendingPlan();
    }
    this.executionCheckInDraft = state.needsReview && state.lastExecutionCheckIn !== undefined &&
      state.lastExecutionCheckIn.stepTitle === state.lastCompletedStepTitle &&
      (this.lastCompletedStepProject.length === 0 ||
        state.lastExecutionCheckIn.project === this.lastCompletedStepProject) ?
      state.lastExecutionCheckIn.detail : '';
    this.planSource = typeof state.planSource === 'string' ? state.planSource :
      (state.plan.summary.indexOf('本地应急计划：') === 0 ? 'local' :
        (state.plan.steps.length > 0 ? 'ai' : 'none'));
    if (state.previousPlan !== undefined && state.previousPlan.plan !== undefined &&
      Array.isArray(state.previousPlan.plan.steps) && state.previousPlan.plan.steps.length > 0) {
      const previousPlan = AiPlanVersionHelper.copyPlan(state.previousPlan.plan);
      this.previousPlanSummary = previousPlan.summary;
      this.previousPlanSteps = previousPlan.steps;
      this.previousPlanSource = state.previousPlan.source;
      this.previousPlanSavedAt = state.previousPlan.savedAt;
    } else {
      this.clearPreviousPlan();
    }
  }

  private async loadConversationHistory(): Promise<void> {
    this.conversationHistory = await PreferencesHelper.loadAiConversationHistory(this.getContext());
  }

  private resolveConversationTitle(): string {
    for (const message of this.chatMessages) {
      if (message.role === 'user' && message.content.trim().length > 0) {
        return message.content.trim().substring(0, 24);
      }
    }
    if (this.goal.trim().length > 0) {
      return this.goal.trim().substring(0, 24);
    }
    return '未命名对话';
  }

  private createCurrentState(): AiAgentState {
    const now = Date.now();
    if (this.conversationId.length === 0) {
      this.conversationId = `ai-${now}`;
      this.conversationCreatedAt = now;
    }
    if (this.conversationTitle.length === 0 || this.conversationTitle === '未命名对话') {
      this.conversationTitle = this.resolveConversationTitle();
    }
    return {
      id: this.conversationId,
      title: this.conversationTitle,
      createdAt: this.conversationCreatedAt,
      messages: this.chatMessages,
      plan: { summary: this.summary, steps: this.planSteps },
      updatedAt: now,
      needsReview: this.needsReview,
      lastCompletedStepTitle: this.lastCompletedStepTitle,
      lastCompletedStepProject: this.lastCompletedStepProject,
      availableMinutes: this.availableMinutes,
      deadline: this.deadline,
      primaryGoal: this.primaryGoal,
      memory: this.agentMemory,
      goalDrift: this.goalDriftInsight,
      lastAutoReviewAttemptTitle: this.lastAutoReviewAttemptTitle,
      lastExecutionReplanKey: this.lastExecutionReplanKey,
      planSource: this.planSource,
      previousPlan: this.createPreviousPlanSnapshot(),
      lastExecutionCheckIn: this.lastExecutionCheckIn,
      requestTraces: this.requestTraces,
      tokenBudget: this.tokenBudget,
      consumedTokens: this.consumedTokens,
      pendingPlan: this.pendingPlanSteps.length > 0 ? {
        summary: this.pendingPlanSummary,
        steps: this.pendingPlanSteps
      } : undefined,
      pendingPlanReply: this.pendingPlanReply,
      pendingPlanRequest: this.pendingPlanRequest,
      pendingPlanSource: this.pendingPlanSource,
      pendingPlanCreatedAt: this.pendingPlanCreatedAt,
      pendingPrimaryGoal: this.pendingPrimaryGoal,
      pendingPlanSelections: this.pendingPlanSelections
    };
  }

  private createDefaultSelections(count: number): boolean[] {
    const selections: boolean[] = [];
    for (let index = 0; index < count; index++) {
      selections.push(true);
    }
    return selections;
  }

  private clearPendingPlan(): void {
    this.pendingPlanSummary = '';
    this.pendingPlanSteps = [];
    this.pendingPlanReply = '';
    this.pendingPlanRequest = '';
    this.pendingPlanSource = 'ai';
    this.pendingPlanCreatedAt = 0;
    this.pendingPrimaryGoal = '';
    this.pendingPlanSelections = [];
  }

  private stagePlanProposal(request: string, reply: string, plan: AiPlan, source: string): void {
    this.pendingPlanSummary = plan.summary;
    this.pendingPlanSteps = plan.steps;
    this.pendingPlanReply = reply;
    this.pendingPlanRequest = request;
    this.pendingPlanSource = source;
    this.pendingPlanCreatedAt = Date.now();
    this.pendingPrimaryGoal = this.proposalPrimaryGoalDraft;
    this.proposalPrimaryGoalDraft = '';
    this.pendingPlanSelections = this.createDefaultSelections(
      Math.max(this.planSteps.length, plan.steps.length));
  }

  private async togglePendingPlanSelection(index: number): Promise<void> {
    const selections: boolean[] = [];
    const count = Math.max(this.planSteps.length, this.pendingPlanSteps.length);
    for (let itemIndex = 0; itemIndex < count; itemIndex++) {
      const current = this.pendingPlanSelections[itemIndex] !== false;
      selections.push(itemIndex === index ? !current : current);
    }
    this.pendingPlanSelections = selections;
    await this.saveAgentState(this.needsReview);
  }

  private async selectAllPendingChanges(selected: boolean): Promise<void> {
    const selections: boolean[] = [];
    const count = Math.max(this.planSteps.length, this.pendingPlanSteps.length);
    for (let index = 0; index < count; index++) {
      selections.push(selected);
    }
    this.pendingPlanSelections = selections;
    await this.saveAgentState(this.needsReview);
  }

  private async rejectPendingPlan(): Promise<void> {
    if (this.pendingPlanSteps.length === 0) {
      return;
    }
    const request = this.pendingPlanRequest;
    this.clearPendingPlan();
    await this.saveAgentState(this.needsReview);
    this.successMessage = request.length > 0 ? '已拒绝本次调整，原计划保持不变' : '已关闭计划提案';
  }

  private async applyPendingPlan(applyAll: boolean): Promise<void> {
    if (this.pendingPlanSteps.length === 0) {
      return;
    }
    const candidate: AiPlan = {
      summary: this.pendingPlanSummary,
      steps: this.pendingPlanSteps
    };
    const hadExistingPlan = this.planSteps.length > 0;
    const nextPlan = applyAll ? AiPlanVersionHelper.copyPlan(candidate) :
      AiPlanProposalHelper.merge(
        { summary: this.summary, steps: this.planSteps }, candidate, this.pendingPlanSelections);
    if (nextPlan.steps.length === 0) {
      this.errorMessage = '至少保留一个可执行步骤';
      return;
    }
    const quality = this.evaluateCandidatePlan(nextPlan);
    if (!quality.canApply) {
      this.errorMessage = `所选修改无法应用：${quality.description}`;
      return;
    }
    this.capturePreviousPlan(nextPlan);
    this.summary = nextPlan.summary;
    this.planSteps = nextPlan.steps;
    this.planSource = this.pendingPlanSource;
    const changesPrimaryGoal = this.pendingPrimaryGoal.length > 0;
    if (changesPrimaryGoal) {
      this.primaryGoal = this.pendingPrimaryGoal;
      this.lastExecutionReplanKey = '';
    }
    this.clearPendingPlan();
    this.lastFailedMessage = '';
    this.needsReview = false;
    this.goalDriftInsight = AiAgentP1Helper.emptyDrift();
    if (this.executionInsight.shouldReplan && !changesPrimaryGoal) {
      this.lastExecutionReplanKey = this.getExecutionReplanKey(this.executionInsight);
    }
    this.errorMessage = '';
    await this.refreshAgentAnalysis();
    await this.saveAgentState(false);
    this.successMessage = applyAll ? (hadExistingPlan ?
      '已应用完整提案，原计划已保留为可恢复版本' : '已应用计划提案，可以开始第一步') :
      '已应用所选修改，未勾选部分保持原计划';
  }

  private createPreviousPlanSnapshot(): AiPlanSnapshot | undefined {
    if (this.previousPlanSteps.length === 0) {
      return undefined;
    }
    return {
      plan: AiPlanVersionHelper.copyPlan({
        summary: this.previousPlanSummary,
        steps: this.previousPlanSteps
      }),
      source: this.previousPlanSource,
      savedAt: this.previousPlanSavedAt
    };
  }

  private clearPreviousPlan(): void {
    this.previousPlanSummary = '';
    this.previousPlanSteps = [];
    this.previousPlanSource = 'none';
    this.previousPlanSavedAt = 0;
  }

  private capturePreviousPlan(nextPlan: AiPlan): void {
    const snapshot = AiPlanVersionHelper.capture(
      { summary: this.summary, steps: this.planSteps }, nextPlan, this.planSource, Date.now());
    if (snapshot === undefined) {
      return;
    }
    this.previousPlanSummary = snapshot.plan.summary;
    this.previousPlanSteps = snapshot.plan.steps;
    this.previousPlanSource = snapshot.source;
    this.previousPlanSavedAt = snapshot.savedAt;
  }

  private async restorePreviousPlan(): Promise<void> {
    if (this.previousPlanSteps.length === 0 || this.isLoading) {
      return;
    }
    const restored = AiPlanVersionHelper.copyPlan({
      summary: this.previousPlanSummary,
      steps: this.previousPlanSteps
    });
    const restoredSource = this.previousPlanSource;
    this.summary = restored.summary;
    this.planSteps = restored.steps;
    this.planSource = restoredSource;
    this.clearPreviousPlan();
    this.needsReview = false;
    this.lastFailedMessage = '';
    this.errorMessage = '';
    this.appendMessages('恢复 AI 调整前的计划版本',
      '已恢复上一个执行计划；这是本地版本操作，没有调用 AI。');
    await this.refreshAgentAnalysis();
    await this.saveAgentState(false);
    this.successMessage = '已恢复 AI 调整前的计划版本，未调用 AI';
  }

  private async saveAgentState(needsReview: boolean = this.needsReview): Promise<void> {
    this.needsReview = needsReview;
    const state = this.createCurrentState();
    await PreferencesHelper.saveAiAgentState(this.getContext(), state);
  }

  private async startNewConversation(): Promise<void> {
    if (this.chatMessages.length > 0 || this.planSteps.length > 0) {
      const state = this.createCurrentState();
      await PreferencesHelper.archiveAiConversation(this.getContext(), state);
    }
    await PreferencesHelper.clearAiAgentState(this.getContext());
    this.conversationId = '';
    this.conversationTitle = '';
    this.conversationCreatedAt = 0;
    this.chatMessages = [];
    this.summary = '';
    this.planSteps = [];
    this.goal = '';
    this.followUp = '';
    this.needsReview = false;
    this.lastCompletedStepTitle = '';
    this.lastCompletedStepProject = '';
    this.lastTotalTokens = 0;
    this.errorMessage = '';
    this.lastFailedMessage = '';
    this.primaryGoal = '';
    this.agentMemory = AiAgentP1Helper.emptyMemory();
    this.goalDriftInsight = AiAgentP1Helper.emptyDrift();
    this.executionInsight = AiAgentP1Helper.emptyExecution();
    this.lastAutoReviewAttemptTitle = '';
    this.lastExecutionReplanKey = '';
    this.lastExecutionCheckIn = undefined;
    this.executionCheckInDraft = '';
    this.requestTraces = [];
    this.showRequestTraces = false;
    this.consumedTokens = 0;
    this.planSource = 'none';
    this.clearPreviousPlan();
    this.clearPendingPlan();
    this.successMessage = '已开始新对话';
    await this.loadConversationHistory();
  }

  private async openArchivedConversation(id: string): Promise<void> {
    const archived = await PreferencesHelper.loadArchivedAiConversation(this.getContext(), id);
    if (archived === undefined) {
      this.errorMessage = '历史对话已不存在或无法读取';
      await this.loadConversationHistory();
      return;
    }
    if (this.chatMessages.length > 0 || this.planSteps.length > 0) {
      await PreferencesHelper.archiveAiConversation(this.getContext(), this.createCurrentState());
    }
    await PreferencesHelper.saveAiAgentState(this.getContext(), archived);
    await PreferencesHelper.removeArchivedAiConversation(this.getContext(), id);
    this.applyAgentState(archived);
    this.goal = '';
    this.followUp = '';
    this.lastTotalTokens = 0;
    this.errorMessage = '';
    this.lastFailedMessage = '';
    this.successMessage = '已恢复历史对话，可以继续调整计划';
    this.closeConversationHistory();
    await this.loadConversationHistory();
  }

  private closeConversationHistory(): void {
    this.showConversationHistory = false;
    this.pendingDeleteConversationId = '';
    this.pendingDeleteConversationTitle = '';
  }

  private requestDeleteConversation(item: AiConversationSummary): void {
    this.pendingDeleteConversationId = item.id;
    this.pendingDeleteConversationTitle = item.title;
  }

  private cancelDeleteConversation(): void {
    this.pendingDeleteConversationId = '';
    this.pendingDeleteConversationTitle = '';
  }

  private async confirmDeleteConversation(): Promise<void> {
    const id = this.pendingDeleteConversationId;
    if (id.length === 0) {
      return;
    }
    try {
      await PreferencesHelper.removeArchivedAiConversation(this.getContext(), id);
      await this.loadConversationHistory();
      this.cancelDeleteConversation();
      this.errorMessage = '';
      this.successMessage = '历史对话已删除';
    } catch {
      this.errorMessage = '删除历史对话失败，请稍后重试';
    }
  }

  private changeAvailableMinutes(delta: number): void {
    this.availableMinutes = Math.max(this.workMinutes, Math.min(1440, this.availableMinutes + delta));
  }

  private getDeadlineInsight(): AiDeadlineInsight {
    return AiDeadlineHelper.evaluate(this.deadline, this.availableMinutes);
  }

  private getEffectiveAvailableMinutes(): number {
    return this.getDeadlineInsight().effectiveAvailableMinutes;
  }

  private prepareDeadline(): boolean {
    const insight = this.getDeadlineInsight();
    if (insight.status === 'unsupported' || insight.status === 'expired') {
      this.errorMessage = insight.description;
      return false;
    }
    if (insight.status === 'valid') {
      this.deadline = insight.normalizedDeadline;
    }
    return true;
  }

  private setDeadlineShortcut(value: string): void {
    const insight = AiDeadlineHelper.evaluate(value, this.availableMinutes);
    this.deadline = insight.status === 'valid' ? insight.normalizedDeadline : value;
    this.errorMessage = '';
  }

  private formatMinutes(minutes: number): string {
    if (minutes < 60) {
      return `${minutes} 分钟`;
    }
    const hours = Math.floor(minutes / 60);
    const rest = minutes % 60;
    return rest > 0 ? `${hours} 小时 ${rest} 分钟` : `${hours} 小时`;
  }

  private formatSeconds(seconds: number): string {
    return this.formatMinutes(Math.round(seconds / 60));
  }

  private formatConversationTime(timestamp: number): string {
    if (timestamp <= 0) {
      return '时间未知';
    }
    const date = new Date(timestamp);
    const month = date.getMonth() + 1;
    const day = date.getDate();
    const hours = date.getHours();
    const minutes = date.getMinutes();
    const minuteText = minutes < 10 ? `0${minutes}` : `${minutes}`;
    return `${month}月${day}日 ${hours}:${minuteText}`;
  }

  private formatRequestDuration(durationMs: number): string {
    if (durationMs < 1000) {
      return `${Math.max(0, Math.round(durationMs))} ms`;
    }
    return `${Math.round(durationMs / 100) / 10} 秒`;
  }

  private async saveEndpoint(): Promise<void> {
    const normalized = this.endpoint.trim();
    if (normalized.length === 0) {
      this.errorMessage = '请填写 AI 服务地址';
      return;
    }
    await PreferencesHelper.saveAiServiceEndpoint(this.getContext(), normalized);
    this.endpoint = normalized;
    this.errorMessage = '';
    this.successMessage = '代理地址已保存';
    this.showServiceSettings = false;
  }

  private async checkDeepSeekService(): Promise<void> {
    if (this.isCheckingService) {
      return;
    }
    this.isCheckingService = true;
    this.serviceCheckMessage = '';
    try {
      const result = await AiPlannerService.checkDeepSeekService(this.apiKey, this.deepSeekModel);
      this.serviceCheckSuccess = result.success;
      this.serviceCheckMessage = result.message;
    } finally {
      this.isCheckingService = false;
    }
  }

  private async buildFocusContext(): Promise<AiFocusContext> {
    const history = await PreferencesHelper.loadSessionHistory(this.getContext());
    const sevenDaysAgo = Date.now() - 7 * 24 * 60 * 60 * 1000;
    let sevenDayWorkSeconds = 0;
    let sevenDayCompletedSessions = 0;
    let sevenDayAbandonedSessions = 0;
    for (const record of history) {
      if (record.completedAt >= sevenDaysAgo && record.type !== 'break') {
        sevenDayWorkSeconds += record.workSeconds;
        if (record.status === 'completed') {
          sevenDayCompletedSessions += 1;
        } else if (record.status === 'abandoned') {
          sevenDayAbandonedSessions += 1;
        }
      }
    }
    let recentSummary = '';
    const startIndex = Math.max(0, history.length - 8);
    for (let index = history.length - 1; index >= startIndex; index--) {
      const record: SessionRecord | undefined = history[index];
      if (record !== undefined) {
        const type = record.type === 'break' ? '休息' : '专注';
        const status = record.status === 'completed' ? '完成' :
          (record.status === 'abandoned' ? '部分完成' : '跳过');
        recentSummary += `${record.date} ${type}${Math.round(record.workSeconds / 60)}分钟 ${status}`;
        if (record.task !== undefined && record.task.length > 0) {
          recentSummary += ` 任务:${record.task}`;
        }
        if (record.focusRating !== undefined && record.energyRating !== undefined) {
          recentSummary += ` 专注:${record.focusRating}/5 精力:${record.energyRating}/5`;
        }
        if (record.interruptionReason !== undefined && record.interruptionReason.length > 0 &&
          record.interruptionReason !== '无') {
          recentSummary += ` 打断:${record.interruptionReason}`;
        }
        if (record.outcomeNote !== undefined && record.outcomeNote.length > 0) {
          recentSummary += ` 产出:${record.outcomeNote}`;
        }
        recentSummary += '\n';
      }
    }
    const insight = this.getPlanInsight();
    const deadlineInsight = this.getDeadlineInsight();
    return {
      todayWorkSeconds: this.todayWorkSeconds,
      todayBreakSeconds: this.todayBreakSeconds,
      todayCompletedSessions: this.todayCompletedSessions,
      dailyTarget: this.dailyTarget,
      sevenDayWorkSeconds: sevenDayWorkSeconds,
      sevenDayCompletedSessions: sevenDayCompletedSessions,
      sevenDayAbandonedSessions: sevenDayAbandonedSessions,
      currentTask: this.currentTask,
      currentProject: this.currentProject,
      currentTaskCompleted: this.currentTaskCompleted,
      workMinutes: this.workMinutes,
      breakMinutes: this.breakMinutes,
      recentSessionsSummary: recentSummary.length > 0 ? recentSummary : '暂无历史记录',
      availableMinutes: deadlineInsight.effectiveAvailableMinutes,
      deadline: deadlineInsight.normalizedDeadline.length > 0 ?
        deadlineInsight.normalizedDeadline : '未指定',
      planRequiredMinutes: insight.requiredMinutes,
      planBufferMinutes: insight.bufferMinutes,
      planProgressPercent: insight.progressPercent,
      planRiskStatus: insight.status
    };
  }

  private getExecutionReplanKey(insight: AiExecutionInsight): string {
    return `${insight.expectedMinutes}-${insight.actualMinutes}-${insight.matchedSessions}`;
  }

  private async updateAgentAnalysis(context: AiFocusContext): Promise<void> {
    const history = await PreferencesHelper.loadSessionHistory(this.getContext());
    const records: AiExecutionRecord[] = [];
    for (const record of history) {
      records.push({
        completedAt: record.completedAt,
        workSeconds: record.workSeconds,
        type: record.type,
        status: record.status,
        task: record.task,
        project: record.project
      });
    }
    this.agentMemory = AiAgentP1Helper.buildMemory(
      this.primaryGoal, { summary: this.summary, steps: this.planSteps }, context,
      this.lastCompletedStepTitle, this.chatMessages);
    const execution = AiAgentP1Helper.analyzeExecution(
      { summary: this.summary, steps: this.planSteps }, records,
      this.conversationCreatedAt, this.workMinutes);
    if (execution.shouldReplan && this.getExecutionReplanKey(execution) === this.lastExecutionReplanKey) {
      execution.shouldReplan = false;
      execution.title = '执行偏差已校准';
      execution.description = '智能体已经按这批真实计时数据重排过计划，将等待新的执行记录。';
    }
    this.executionInsight = execution;
  }

  private async refreshAgentAnalysis(): Promise<void> {
    const context = await this.buildFocusContext();
    await this.updateAgentAnalysis(context);
  }

  private async toggleAutoReview(enabled: boolean): Promise<void> {
    this.autoReviewEnabled = enabled;
    await PreferencesHelper.saveAiAutoReview(this.getContext(), enabled);
    if (enabled) {
      this.successMessage = '已开启自动复盘；记录执行结果后会调用 DeepSeek';
      await this.tryAutoReview();
    } else {
      this.successMessage = '已关闭自动复盘';
    }
  }

  private async tryAutoReview(): Promise<void> {
    if (!this.autoReviewEnabled || this.serviceMode !== 'deepseek' || !this.isServiceReady() ||
      !this.needsReview || this.lastCompletedStepTitle.length === 0 || this.isLoading ||
      !AiExecutionCheckInHelper.matchesStep(this.lastExecutionCheckIn,
        this.lastCompletedStepTitle, this.lastCompletedStepProject) ||
      this.lastAutoReviewAttemptTitle === this.lastCompletedStepTitle) {
      return;
    }
    this.lastAutoReviewAttemptTitle = this.lastCompletedStepTitle;
    await this.saveAgentState(true);
    await this.reviewCompletedStep();
  }

  private getPlanInsight(): AiPlanInsight {
    const tracksCurrentPlan = this.currentTaskSource === 'ai' &&
      this.currentTaskConversationId === this.conversationId;
    return AiPlanInsightHelper.calculate(
      this.planSteps, this.getEffectiveAvailableMinutes(), this.workMinutes, this.breakMinutes,
      tracksCurrentPlan ? this.currentTask : '', tracksCurrentPlan ? this.currentProject : '',
      tracksCurrentPlan ? this.currentTaskCompleted : 0);
  }

  private getPlanQuality(insight: AiPlanInsight): AiPlanQualityInsight {
    return AiPlanQualityHelper.evaluate(this.planSteps, insight);
  }

  private getGoalReadiness(): AiGoalReadinessInsight {
    return AiGoalReadinessHelper.evaluate(this.goal);
  }

  private evaluateCandidatePlan(plan: AiPlan): AiPlanQualityInsight {
    const insight = AiPlanInsightHelper.calculate(
      plan.steps, this.getEffectiveAvailableMinutes(), this.workMinutes, this.breakMinutes);
    return AiPlanQualityHelper.evaluate(plan.steps, insight);
  }

  private buildRepairHistory(userMessage: string, assistantReply: string): AiChatMessage[] {
    const history: AiChatMessage[] = [];
    const startIndex = Math.max(0, this.chatMessages.length - 14);
    for (let index = startIndex; index < this.chatMessages.length; index++) {
      const item = this.chatMessages[index];
      if (item !== undefined) {
        history.push(item);
      }
    }
    history.push({ role: 'user', content: userMessage, createdAt: Date.now() });
    history.push({ role: 'assistant', content: assistantReply, createdAt: Date.now() });
    return history;
  }

  private getTrackedStepPomodoros(step: AiPlanStep): number {
    if (step.completed) {
      return Math.max(1, step.estimatedPomodoros);
    }
    if (this.currentTaskSource !== 'ai' || this.currentTaskConversationId !== this.conversationId ||
      step.title !== this.currentTask || step.project !== this.currentProject) {
      return 0;
    }
    return Math.max(0, Math.min(Math.max(1, step.estimatedPomodoros), this.currentTaskCompleted));
  }

  private formatStepProgress(step: AiPlanStep): string {
    const trackedPomodoros = this.getTrackedStepPomodoros(step);
    const estimatedPomodoros = Math.max(1, step.estimatedPomodoros);
    const progressText = trackedPomodoros > 0 ? `${trackedPomodoros}/${estimatedPomodoros}` :
      `${estimatedPomodoros}`;
    const runningText = trackedPomodoros > 0 && !step.completed ? ' · 执行中' : '';
    const projectText = step.project.length > 0 ? ` · ${step.project}` : '';
    return `${progressText} 个番茄${runningText}${projectText}`;
  }

  private getAgentDecision(): AiAgentDecision {
    return AiAgentDecisionHelper.decide(
      this.getPlanInsight(), this.planSteps.length > 0, this.needsReview,
      this.errorMessage.length > 0, this.lastFailedMessage.length > 0,
      this.isServiceReady(), this.canApplyStep, this.isLoading,
      this.goalDriftInsight, this.executionInsight);
  }

  private shouldShowAgentSuggestion(decision: AiAgentDecision): boolean {
    return decision.action === 'retry' || decision.action === 'review' || decision.action === 'compress' ||
      decision.action === 'replan_variance' || decision.action === 'align_goal';
  }

  private isServiceReady(): boolean {
    if (this.serviceMode === 'deepseek') {
      return this.apiKey.trim().length >= 10;
    }
    return this.endpoint.trim().length > 0;
  }

  private applyNextStep(): void {
    const insight = this.getPlanInsight();
    if (insight.nextStepIndex < 0) {
      this.successMessage = '当前计划已经全部完成';
      return;
    }
    const step = this.planSteps[insight.nextStepIndex];
    if (step !== undefined) {
      this.applyStep(step);
    }
  }

  private startNextStep(): void {
    const insight = this.getPlanInsight();
    if (insight.nextStepIndex < 0) {
      this.successMessage = '当前计划已经全部完成';
      return;
    }
    const step = this.planSteps[insight.nextStepIndex];
    if (step !== undefined) {
      this.startStep(step);
    }
  }

  private async requestPlanCompression(): Promise<void> {
    const insight = this.getPlanInsight();
    const effectiveMinutes = this.getEffectiveAvailableMinutes();
    const message = `当前计划剩余 ${insight.remainingPomodoros} 个番茄，预计需要 ` +
      `${insight.requiredMinutes} 分钟，但我在截止约束内只有 ${effectiveMinutes} 分钟。` +
      `请保留最有价值的可交付成果，压缩或合并后续步骤，并保留合理缓冲。`;
    await this.askAgent(message);
  }

  private async requestPlanQualityImprovement(quality: AiPlanQualityInsight): Promise<void> {
    if (quality.improvementPrompt.length === 0) {
      return;
    }
    if (this.serviceMode !== 'deepseek') {
      this.followUp = quality.improvementPrompt;
      this.successMessage = '质检建议已填入调整框；多轮修正请切换到 DeepSeek 直连';
      return;
    }
    await this.askAgent(quality.improvementPrompt);
  }

  private async alignWithPrimaryGoal(): Promise<void> {
    if (this.primaryGoal.length === 0) {
      this.errorMessage = '当前没有可用于校准的主目标';
      return;
    }
    const message = `请以主目标“${this.primaryGoal}”为唯一方向，重新检查当前计划。` +
      `只吸收最近指令中与主目标一致的调整，删除无关内容，并给出下一步。`;
    await this.askAgent(message);
  }

  private async requestExecutionReplan(): Promise<void> {
    const message = `真实执行数据表明：${this.executionInsight.description}` +
      `请按实际速度重排剩余计划，保留已完成步骤，并重新设置估时和缓冲。`;
    await this.askAgent(message);
  }

  private async retryLastRequest(): Promise<void> {
    if (this.lastFailedMessage.length === 0) {
      this.errorMessage = '没有可以重试的智能体行动';
      return;
    }
    await this.askAgent(this.lastFailedMessage);
  }

  private resolveFallbackGoal(): string {
    if (this.primaryGoal.trim().length > 0) {
      return this.primaryGoal.trim();
    }
    if (this.goal.trim().length > 0) {
      return this.goal.trim();
    }
    return '完成当前最重要的任务';
  }

  private async createLocalFallbackPlan(): Promise<void> {
    if (this.planSteps.length > 0) {
      this.successMessage = '现有计划仍可离线执行，无需覆盖';
      return;
    }
    if (!this.prepareDeadline()) {
      return;
    }
    const fallbackGoal = this.resolveFallbackGoal();
    const requestText = this.lastFailedMessage.length > 0 ? this.lastFailedMessage :
      `请为“${fallbackGoal}”制定计划。`;
    const plan = LocalFallbackPlanHelper.create(
      fallbackGoal, this.getEffectiveAvailableMinutes(), this.deadline, this.workMinutes, this.breakMinutes);
    this.primaryGoal = fallbackGoal;
    this.summary = plan.summary;
    this.planSteps = plan.steps;
    this.planSource = 'local';
    this.appendMessages(requestText, 'AI 服务暂时不可用，已生成明确标注的本地应急计划。' +
      '该计划依据可用时间和番茄参数计算，不包含模型推理结果。');
    this.errorMessage = '';
    this.lastFailedMessage = '';
    this.lastTotalTokens = 0;
    this.needsReview = false;
    await this.refreshAgentAnalysis();
    await this.saveAgentState(false);
    this.successMessage = '已生成本地应急计划，未调用 AI；联网后可继续优化';
  }

  private async runRecommendedAction(): Promise<void> {
    const decision = this.getAgentDecision();
    if (decision.action === 'retry') {
      await this.retryLastRequest();
    } else if (decision.action === 'configure') {
      this.showServiceSettings = true;
    } else if (decision.action === 'generate') {
      await this.generatePlan();
    } else if (decision.action === 'review') {
      await this.reviewCompletedStep();
    } else if (decision.action === 'compress') {
      await this.requestPlanCompression();
    } else if (decision.action === 'align_goal') {
      await this.alignWithPrimaryGoal();
    } else if (decision.action === 'replan_variance') {
      await this.requestExecutionReplan();
    } else if (decision.action === 'apply_next') {
      this.applyNextStep();
    }
  }

  private appendMessages(userText: string, assistantText: string): void {
    const messages: AiChatMessage[] = [];
    const startIndex = Math.max(0, this.chatMessages.length - 28);
    for (let index = startIndex; index < this.chatMessages.length; index++) {
      const item = this.chatMessages[index];
      if (item !== undefined) {
        messages.push(item);
      }
    }
    messages.push({ role: 'user', content: userText, createdAt: Date.now() });
    messages.push({ role: 'assistant', content: assistantText, createdAt: Date.now() });
    this.chatMessages = messages;
  }

  private resolveRequestAction(): string {
    if (this.needsReview && this.lastCompletedStepTitle.length > 0) {
      return '执行复盘';
    }
    return this.planSteps.length === 0 ? '生成计划' : '调整计划';
  }

  private recordRequestTrace(action: string, startedAt: number, result: AiAgentResult,
    status: string, statusDetail: string): void {
    const trace = AiRequestTraceHelper.create(
      action, this.deepSeekModel, startedAt, Date.now(), result, status, statusDetail);
    this.requestTraces = AiRequestTraceHelper.append(this.requestTraces, trace);
    this.consumedTokens = AiTokenBudgetHelper.addUsage(
      this.consumedTokens, result.usage.totalTokens);
  }

  private getTokenBudgetInsight(): AiTokenBudgetInsight {
    return AiTokenBudgetHelper.evaluate(this.tokenBudget, this.consumedTokens);
  }

  private async updateTokenBudget(value: number): Promise<void> {
    this.tokenBudget = AiTokenBudgetHelper.normalizeBudget(value);
    this.errorMessage = '';
    if (this.hasCurrentConversation()) {
      await this.saveAgentState(this.needsReview);
    }
  }

  private async askAgent(message: string): Promise<boolean> {
    if (this.isLoading) {
      return false;
    }
    const normalized = message.trim();
    if (normalized.length < 2) {
      this.errorMessage = '请告诉 AI 你想规划或调整什么';
      return false;
    }
    if (this.pendingPlanSteps.length > 0) {
      this.errorMessage = '请先应用或拒绝当前计划提案，再继续调用 AI';
      return false;
    }
    if (!this.prepareDeadline()) {
      return false;
    }
    if (this.serviceMode === 'deepseek' && !this.getTokenBudgetInsight().canRequest) {
      this.errorMessage = '本对话 Token 预算已用完，请提高预算或新建对话后再调用 DeepSeek';
      return false;
    }
    if (this.serviceMode === 'deepseek' && this.apiKey.trim().length < 10) {
      this.errorMessage = '请先填写 DeepSeek API Key';
      this.showServiceSettings = true;
      return false;
    }
    if (this.serviceMode === 'proxy' && this.endpoint.trim().length === 0) {
      this.errorMessage = '请先配置代理服务地址';
      this.showServiceSettings = true;
      return false;
    }
    this.isLoading = true;
    this.errorMessage = '';
    this.successMessage = '';
    try {
      if (this.serviceMode === 'deepseek') {
        const requestAction = this.resolveRequestAction();
        const focusContext = await this.buildFocusContext();
        this.goalDriftInsight = this.planSteps.length > 0 ?
          AiAgentP1Helper.detectGoalDrift(
            this.primaryGoal, normalized, { summary: this.summary, steps: this.planSteps }) :
          AiAgentP1Helper.emptyDrift();
        await this.updateAgentAnalysis(focusContext);
        const requestStartedAt = Date.now();
        const result: AiAgentResult = await AiPlannerService.continueDeepSeekAgent(
          this.apiKey, this.deepSeekModel, normalized, this.chatMessages,
          { summary: this.summary, steps: this.planSteps }, focusContext,
          this.agentMemory, this.goalDriftInsight, this.executionInsight);
        if (!result.success) {
          this.recordRequestTrace(requestAction, requestStartedAt, result,
            'failed', result.errorMessage);
          this.lastTotalTokens = result.usage.totalTokens;
          this.errorMessage = result.errorMessage;
          this.lastFailedMessage = normalized;
          await this.saveAgentState(this.needsReview);
          return false;
        }
        let acceptedResult: AiAgentResult = result;
        let quality = this.evaluateCandidatePlan(result.plan);
        let repaired = false;
        this.lastTotalTokens = result.usage.totalTokens;
        if (!quality.canApply) {
          this.recordRequestTrace(requestAction, requestStartedAt, result,
            'quality_rejected', '返回计划未通过本地质量门，已进入一次自动修复');
          if (!this.getTokenBudgetInsight().canRequest) {
            this.errorMessage = `AI 首版计划未通过质量门：${quality.description}` +
              '本对话 Token 预算已用完，已停止自动修复。';
            this.lastFailedMessage = normalized;
            await this.saveAgentState(this.needsReview);
            return false;
          }
          const repairStartedAt = Date.now();
          const repairResult: AiAgentResult = await AiPlannerService.continueDeepSeekAgent(
            this.apiKey, this.deepSeekModel, quality.improvementPrompt,
            this.buildRepairHistory(normalized, result.reply), result.plan, focusContext,
            this.agentMemory, this.goalDriftInsight, this.executionInsight);
          this.lastTotalTokens += repairResult.usage.totalTokens;
          if (!repairResult.success) {
            this.recordRequestTrace('质量门自动修复', repairStartedAt, repairResult,
              'failed', repairResult.errorMessage);
            this.errorMessage = `AI 计划未通过质量门：${quality.description}` +
              `自动修复失败：${repairResult.errorMessage}`;
            this.lastFailedMessage = normalized;
            await this.saveAgentState(this.needsReview);
            return false;
          }
          quality = this.evaluateCandidatePlan(repairResult.plan);
          if (!quality.canApply) {
            this.recordRequestTrace('质量门自动修复', repairStartedAt, repairResult,
              'quality_rejected', '修复结果仍未通过本地质量门，已停止自动重试');
            this.errorMessage = `AI 计划未通过质量门，已停止自动重试：${quality.description}`;
            this.lastFailedMessage = normalized;
            await this.saveAgentState(this.needsReview);
            return false;
          }
          this.recordRequestTrace('质量门自动修复', repairStartedAt, repairResult,
            'repaired', '修复结果已通过本地质量门，等待用户确认');
          acceptedResult = repairResult;
          repaired = true;
        } else {
          this.recordRequestTrace(requestAction, requestStartedAt, result,
            'accepted', '响应已通过本地质量门，等待用户确认');
        }
        this.appendMessages(normalized, acceptedResult.reply);
        this.stagePlanProposal(normalized, acceptedResult.reply, acceptedResult.plan, 'ai');
        this.lastFailedMessage = '';
        await this.saveAgentState(this.needsReview);
        if (repaired) {
          this.successMessage = '首版未通过质检，智能体已修正并生成待确认提案';
        } else {
          this.successMessage = 'AI 已生成计划提案，请核对变更后再应用';
        }
        return true;
      }

      if (this.chatMessages.length > 0) {
        this.errorMessage = '安全代理模式暂未升级多轮协议，请使用 DeepSeek 直连';
        this.lastFailedMessage = '';
        return false;
      }
      const result: AiPlanResult = await AiPlannerService.createPlan(
        this.endpoint, normalized, this.getEffectiveAvailableMinutes(), this.deadline,
        this.workMinutes, this.breakMinutes);
      if (!result.success) {
        this.errorMessage = result.errorMessage;
        this.lastFailedMessage = normalized;
        return false;
      }
      const quality = this.evaluateCandidatePlan(result.plan);
      if (!quality.canApply) {
        this.errorMessage = `代理返回的计划未通过质量门：${quality.description}` +
          '请按质检建议修改目标后重新生成。';
        this.lastFailedMessage = normalized;
        return false;
      }
      this.appendMessages(normalized, result.plan.summary);
      this.stagePlanProposal(normalized, result.plan.summary, result.plan, 'ai');
      this.lastFailedMessage = '';
      await this.saveAgentState(this.needsReview);
      this.successMessage = '代理已生成计划提案，请核对变更后再应用';
      return true;
    } catch {
      this.errorMessage = '智能体执行中断，请重试上次行动';
      this.lastFailedMessage = normalized;
      return false;
    } finally {
      this.isLoading = false;
    }
  }

  private async generatePlan(): Promise<void> {
    const readiness = this.getGoalReadiness();
    if (!readiness.ready) {
      this.errorMessage = readiness.question;
      return;
    }
    if (!this.prepareDeadline()) {
      return;
    }
    const deadlineText = this.deadline.trim().length > 0 ? this.deadline.trim() : '未指定';
    const effectiveMinutes = this.getEffectiveAvailableMinutes();
    this.proposalPrimaryGoalDraft = this.goal.trim();
    const message = `请制定或重新规划这个目标：${this.goal.trim()}。` +
      `我在截止约束内可用 ${effectiveMinutes} 分钟，截止时间：${deadlineText}。`;
    if (!await this.askAgent(message)) {
      this.proposalPrimaryGoalDraft = '';
      await this.refreshAgentAnalysis();
    }
  }

  private async sendFollowUp(): Promise<void> {
    const message = this.followUp.trim();
    if (await this.askAgent(message)) {
      this.followUp = '';
    }
  }

  private getPendingPlanChanges(): AiPlanChange[] {
    return AiPlanProposalHelper.buildChanges(
      this.planSteps, this.pendingPlanSteps, this.pendingPlanSelections);
  }

  private getPendingPlanStats(): AiPlanProposalStats {
    return AiPlanProposalHelper.getStats(
      this.planSteps, this.pendingPlanSteps, this.pendingPlanSelections);
  }

  private getChangeLabel(change: AiPlanChange): string {
    if (change.type === 'added') {
      return '新增';
    }
    if (change.type === 'removed') {
      return '删除';
    }
    if (change.type === 'modified') {
      return '修改';
    }
    return '不变';
  }

  private getChangeTitle(change: AiPlanChange): string {
    if (change.candidateStep !== undefined) {
      return change.candidateStep.title;
    }
    if (change.currentStep !== undefined) {
      return change.currentStep.title;
    }
    return '未命名步骤';
  }

  private getChangeDetail(change: AiPlanChange): string {
    if (change.type === 'modified' && change.currentStep !== undefined &&
      change.candidateStep !== undefined) {
      return `原：${change.currentStep.title} · ${change.currentStep.estimatedPomodoros} 个番茄\n` +
        `新：${change.candidateStep.title} · ${change.candidateStep.estimatedPomodoros} 个番茄`;
    }
    if (change.type === 'added' && change.candidateStep !== undefined) {
      return `${change.candidateStep.project} · ${change.candidateStep.estimatedPomodoros} 个番茄`;
    }
    if (change.type === 'removed' && change.currentStep !== undefined) {
      return `${change.currentStep.project} · ${change.currentStep.estimatedPomodoros} 个番茄`;
    }
    const step = change.candidateStep !== undefined ? change.candidateStep : change.currentStep;
    return step !== undefined ? `${step.project} · ${step.estimatedPomodoros} 个番茄` : '';
  }

  private async reviewCompletedStep(): Promise<void> {
    const title = this.lastCompletedStepTitle.length > 0 ? this.lastCompletedStepTitle : '刚才的任务';
    if (!AiExecutionCheckInHelper.matchesStep(this.lastExecutionCheckIn,
      title, this.lastCompletedStepProject) ||
      this.lastExecutionCheckIn === undefined) {
      this.errorMessage = '请先核验这一步的实际产出，再让 Agent 复盘';
      return;
    }
    const message = AiExecutionCheckInHelper.buildReviewMessage(this.lastExecutionCheckIn) +
      '请结合最新专注数据复盘，判断后续计划是否需要调整，并告诉我下一轮最应该做什么。';
    await this.askAgent(message);
  }

  private applyStep(step: AiPlanStep): void {
    const quality = this.getPlanQuality(this.getPlanInsight());
    if (!quality.canApply) {
      this.errorMessage = `当前计划未通过质量门：${quality.description}`;
      return;
    }
    if (!this.canApplyStep) {
      this.errorMessage = '请先完成或重置当前一轮计时，再切换任务';
      return;
    }
    if (this.onApplyStep) {
      this.onApplyStep(step, this.conversationId);
    }
    this.successMessage = `已将“${step.title}”设为当前任务`;
  }

  private startStep(step: AiPlanStep): void {
    const quality = this.getPlanQuality(this.getPlanInsight());
    if (!quality.canApply) {
      this.errorMessage = `当前计划未通过质量门：${quality.description}`;
      return;
    }
    if (!this.canApplyStep) {
      this.errorMessage = '当前阶段已开始，不能切换并启动新的计划步骤';
      return;
    }
    if (this.onStartStep) {
      this.onStartStep(step, this.conversationId);
      this.successMessage = `已将“${step.title}”设为任务并开始专注`;
    } else {
      this.applyStep(step);
    }
  }

  private async toggleStepCompleted(stepIndex: number): Promise<void> {
    const steps: AiPlanStep[] = [];
    for (let index = 0; index < this.planSteps.length; index++) {
      const step = this.planSteps[index];
      if (step !== undefined) {
        steps.push(this.copyStep(step, index === stepIndex ? !step.completed : step.completed));
      }
    }
    this.planSteps = steps;
    const changed = this.planSteps[stepIndex];
    this.lastExecutionCheckIn = undefined;
    this.executionCheckInDraft = '';
    if (changed !== undefined && changed.completed) {
      this.lastCompletedStepTitle = changed.title;
      this.lastCompletedStepProject = changed.project;
      this.lastAutoReviewAttemptTitle = '';
      this.needsReview = true;
    } else {
      this.needsReview = false;
    }
    await this.refreshAgentAnalysis();
    await this.saveAgentState(this.needsReview);
    await this.tryAutoReview();
  }

  private async submitExecutionCheckIn(outcome: string): Promise<void> {
    const validation = AiExecutionCheckInHelper.validate(outcome, this.executionCheckInDraft);
    if (!validation.ready) {
      this.errorMessage = validation.message;
      return;
    }
    const checkIn = AiExecutionCheckInHelper.create(
      this.lastCompletedStepTitle, this.lastCompletedStepProject, outcome,
      this.executionCheckInDraft, Date.now());
    if (checkIn === undefined) {
      this.errorMessage = validation.message;
      return;
    }
    this.lastExecutionCheckIn = checkIn;
    const updatedPlan = AiExecutionCheckInHelper.applyOutcome(
      { summary: this.summary, steps: this.planSteps }, checkIn);
    this.planSteps = updatedPlan.steps;
    this.lastAutoReviewAttemptTitle = '';
    this.needsReview = true;
    this.errorMessage = '';
    this.successMessage = checkIn.outcome === 'achieved' ?
      '已记录可核验交付，Agent 将据此复盘' :
      '已保留该步骤为未完成，Agent 将据此调整计划';
    await this.refreshAgentAnalysis();
    await this.saveAgentState(true);
    await this.tryAutoReview();
  }

  private getCompletedStepCount(): number {
    let count = 0;
    for (const step of this.planSteps) {
      if (step.completed) {
        count += 1;
      }
    }
    return count;
  }

  private getWorkflowStage(): number {
    if (this.needsReview || (this.planSteps.length > 0 &&
      this.getCompletedStepCount() === this.planSteps.length)) {
      return 3;
    }
    if (this.isLoading || this.pendingPlanSteps.length > 0) {
      return 1;
    }
    if (this.planSteps.length > 0) {
      return 2;
    }
    return 0;
  }

  private getWorkflowDescription(): string {
    const stage = this.getWorkflowStage();
    if (stage === 1) return '正在生成或确认可执行计划';
    if (stage === 2) return '按步骤专注，完成后提交可核验产出';
    if (stage === 3) return '用实际结果校准下一轮计划';
    return '先写清目标、截止时间与可用时长';
  }

  private hasCurrentConversation(): boolean {
    return this.chatMessages.length > 0 || this.planSteps.length > 0 || this.requestTraces.length > 0;
  }

  private hasCurrentExecutionCheckIn(): boolean {
    return AiExecutionCheckInHelper.matchesStep(
      this.lastExecutionCheckIn, this.lastCompletedStepTitle, this.lastCompletedStepProject);
  }

  @Builder
  private tokenBudgetCard(insight: AiTokenBudgetInsight) {
    if (this.serviceMode === 'deepseek') {
      Column({ space: 9 }) {
        Row({ space: 8 }) {
          Column({ space: 2 }) {
            Text('本对话 Token 预算').fontSize(13).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).width('100%')
            Text(`${insight.consumed} / ${insight.budget} tokens · ${insight.percent}%`)
              .fontSize(9).fontColor($r('app.color.text_tertiary')).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Text(insight.status === 'exhausted' ? '已停止调用' :
            (insight.status === 'warning' ? '接近上限' : '预算正常'))
            .fontSize(9).fontWeight(FontWeight.Bold)
            .fontColor(insight.status === 'healthy' ?
              $r('app.color.primary_green') : $r('app.color.primary_red'))
            .padding({ left: 8, right: 8, top: 5, bottom: 5 })
            .backgroundColor($r('app.color.ring_track')).borderRadius(11)
        }.width('100%')
        Text(insight.description).fontSize(10).lineHeight(15)
          .fontColor($r('app.color.text_secondary')).width('100%')
        Row({ space: 8 }) {
          Button('1 万').layoutWeight(1).height(30).fontSize(9).borderRadius(15)
            .backgroundColor(this.tokenBudget === 10000 ?
              $r('app.color.primary_green') : $r('app.color.ring_track'))
            .fontColor(this.tokenBudget === 10000 ? Color.Black : $r('app.color.text_secondary'))
            .onClick(() => this.updateTokenBudget(10000))
          Button('3 万').layoutWeight(1).height(30).fontSize(9).borderRadius(15)
            .backgroundColor(this.tokenBudget === 30000 ?
              $r('app.color.primary_green') : $r('app.color.ring_track'))
            .fontColor(this.tokenBudget === 30000 ? Color.Black : $r('app.color.text_secondary'))
            .onClick(() => this.updateTokenBudget(30000))
          Button('6 万').layoutWeight(1).height(30).fontSize(9).borderRadius(15)
            .backgroundColor(this.tokenBudget === 60000 ?
              $r('app.color.primary_green') : $r('app.color.ring_track'))
            .fontColor(this.tokenBudget === 60000 ? Color.Black : $r('app.color.text_secondary'))
            .onClick(() => this.updateTokenBudget(60000))
        }.width('100%')
        Text('预算按服务端 usage 累计；单次请求可能略微越过剩余额度。')
          .fontSize(9).fontColor($r('app.color.text_tertiary')).width('100%')
      }
      .width('100%').padding(13).backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: insight.status === 'healthy' ?
        $r('app.color.card_border') : $r('app.color.primary_red') }).borderRadius(15)
    }
  }

  @Builder
  private requestTraceCard() {
    if (this.requestTraces.length > 0) {
      Column({ space: 9 }) {
        Row({ space: 8 }) {
          Column({ space: 2 }) {
            Text('DeepSeek 调用记录').fontSize(13).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).width('100%')
            Text('只记录模型、耗时、Token 和结果，不保存提示词或 API Key')
              .fontSize(9).fontColor($r('app.color.text_tertiary')).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Button(this.showRequestTraces ? '收起' : '详情')
            .height(30).fontSize(9).borderRadius(15)
            .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.text_secondary'))
            .onClick(() => this.showRequestTraces = !this.showRequestTraces)
        }.width('100%')

        if (this.requestTraces[0] !== undefined) {
          Text(AiRequestTraceHelper.provesRemoteResponse(this.requestTraces[0]) ?
            (this.requestTraces[0].totalTokens > 0 ?
              '已收到 DeepSeek 响应；下方 Token 来自服务端 usage 字段' :
              '已收到 DeepSeek 错误响应，但服务端未返回 Token usage') :
            '尚未收到 DeepSeek 响应，请结合错误信息检查网络')
            .fontSize(10).fontWeight(FontWeight.Medium)
            .fontColor(AiRequestTraceHelper.provesRemoteResponse(this.requestTraces[0]) ?
              $r('app.color.primary_green') : $r('app.color.accent_yellow')).width('100%')
        }

        if (this.showRequestTraces) {
          ForEach(this.requestTraces, (trace: AiRequestTrace, index: number) => {
            if (index < 5) {
              Column({ space: 4 }) {
                Row({ space: 6 }) {
                  Text(`${trace.action} · ${AiRequestTraceHelper.statusLabel(trace.status)}`)
                    .fontSize(11).fontWeight(FontWeight.Bold)
                    .fontColor(trace.status === 'accepted' || trace.status === 'repaired' ?
                      $r('app.color.primary_green') :
                      (trace.status === 'failed' ? $r('app.color.primary_red') :
                        $r('app.color.accent_yellow'))).layoutWeight(1)
                  Text(this.formatConversationTime(trace.startedAt))
                    .fontSize(9).fontColor($r('app.color.text_tertiary'))
                }.width('100%')
                Text(`${trace.provider} · ${trace.model} · ${this.formatRequestDuration(trace.durationMs)}`)
                  .fontSize(9).fontColor($r('app.color.text_secondary')).width('100%')
                Text(trace.totalTokens > 0 ?
                  `${trace.totalTokens} tokens（输入 ${trace.promptTokens} / 输出 ${trace.completionTokens}）` :
                  '服务端未返回 Token usage')
                  .fontSize(9).fontColor($r('app.color.text_secondary')).width('100%')
                Text(trace.statusDetail).fontSize(9).fontColor($r('app.color.text_tertiary')).width('100%')
              }
              .width('100%').padding(10).backgroundColor($r('app.color.ring_track')).borderRadius(12)
            }
          }, (trace: AiRequestTrace) => trace.id)
        }
      }
      .width('100%').padding(14).backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.card_border') }).borderRadius(16)
    }
  }

  @Builder
  private executionCheckInCard() {
    Column({ space: 10 }) {
      Row({ space: 8 }) {
        Text(this.hasCurrentExecutionCheckIn() ? '执行结果已记录' : '时间达标，请核验实际产出')
          .fontSize(13).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).layoutWeight(1)
        Text('本地核验')
          .fontSize(9).fontWeight(FontWeight.Bold).fontColor($r('app.color.accent_yellow'))
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor($r('app.color.ring_track')).borderRadius(10)
      }.width('100%')
      Text(`步骤：${this.lastCompletedStepTitle}`)
        .fontSize(11).fontColor($r('app.color.text_secondary')).width('100%')
        .maxLines(2).textOverflow({ overflow: TextOverflow.Ellipsis })
      Text('番茄计时只代表投入时间。请写下可检查的交付物，或具体说明做到哪里、被什么阻塞。')
        .fontSize(10).lineHeight(16).fontColor($r('app.color.text_tertiary')).width('100%')
      TextArea({
        text: this.executionCheckInDraft,
        placeholder: '例如：已导出 demo.mp4；完成 12/20 道题，剩余 8 道；接口 401，待确认权限'
      })
        .width('100%').height(76).fontSize(11)
        .backgroundColor($r('app.color.background')).borderRadius(12)
        .onChange((value: string) => this.executionCheckInDraft = value.substring(0, 500))
      Row({ space: 6 }) {
        Button('已形成交付').layoutWeight(1).height(34).fontSize(9).borderRadius(17)
          .backgroundColor($r('app.color.primary_green')).fontColor(Color.Black)
          .onClick(() => this.submitExecutionCheckIn('achieved'))
        Button('部分完成').layoutWeight(1).height(34).fontSize(9).borderRadius(17)
          .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.accent_yellow'))
          .onClick(() => this.submitExecutionCheckIn('partial'))
        Button('遇到阻塞').layoutWeight(1).height(34).fontSize(9).borderRadius(17)
          .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.primary_red'))
          .onClick(() => this.submitExecutionCheckIn('blocked'))
      }.width('100%')
      Text(this.autoReviewEnabled ?
        '保存后会按你的设置调用 DeepSeek 自动复盘并产生 Token 消耗' :
        '保存仅写入本地；需要时再点击“让 Agent 复盘”')
        .fontSize(9).fontColor($r('app.color.text_tertiary')).width('100%')
    }
    .width('100%').padding(14).backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.accent_yellow') }).borderRadius(16)
  }

  @Builder
  private pageHeader() {
    Row({ space: 10 }) {
      Column() {
        Image($r('app.media.ai_plan')).width(24).height(24).fillColor(Color.Black)
      }
      .width(42).height(42)
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .backgroundColor($r('app.color.primary_green')).borderRadius(14)

      Column({ space: 3 }) {
        Text('AI 执行智能体').fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).width('100%')
        Text('结合你的专注历史持续规划、执行与复盘')
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_tertiary')).width('100%')
      }.layoutWeight(1)

      Button('历史')
        .height(34).fontSize(10).borderRadius(17)
        .backgroundColor(this.showConversationHistory ? $r('app.color.primary_green') :
          $r('app.color.ring_track'))
        .fontColor(this.showConversationHistory ? Color.Black : $r('app.color.text_secondary'))
        .onClick(() => {
          if (this.showConversationHistory) {
            this.closeConversationHistory();
          } else {
            this.showConversationHistory = true;
          }
        })
      Button() {
        Image($r('app.media.settings')).width(17).height(17)
          .fillColor($r('app.color.text_secondary'))
      }
      .width(36).height(36).backgroundColor($r('app.color.ring_track')).borderRadius(18)
      .onClick(() => this.showServiceSettings = !this.showServiceSettings)
    }.width('100%')
  }

  @Builder
  private workflowStageBar() {
    Column({ space: 7 }) {
      Row() {
        ForEach(['目标', '计划', '执行', '复盘'], (label: string, index: number) => {
          Column({ space: 4 }) {
            Text(`${index + 1}`)
              .width(24).height(24).textAlign(TextAlign.Center).fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor(index <= this.getWorkflowStage() ? Color.Black :
                $r('app.color.text_tertiary'))
              .backgroundColor(index <= this.getWorkflowStage() ?
                $r('app.color.primary_green') : $r('app.color.ring_track'))
              .borderRadius(12)
            Text(label).fontSize(9)
              .fontWeight(index === this.getWorkflowStage() ? FontWeight.Bold : FontWeight.Medium)
              .fontColor(index === this.getWorkflowStage() ? $r('app.color.text_primary') :
                $r('app.color.text_tertiary'))
          }.layoutWeight(1).alignItems(HorizontalAlign.Center)
        }, (label: string) => label)
      }.width('100%')
      Text(this.getWorkflowDescription()).fontSize(9)
        .fontColor($r('app.color.text_secondary')).width('100%').textAlign(TextAlign.Center)
    }
    .width('100%').padding({ left: 10, right: 10, top: 8, bottom: 8 })
    .backgroundColor($r('app.color.surface')).borderRadius(14)
  }

  @Builder
  private conversationListOverlay() {
    if (this.showConversationHistory) {
      Stack({ alignContent: Alignment.Top }) {
        Column()
          .width('100%').height('100%')
          .backgroundColor('#88000000')
          .onClick(() => this.closeConversationHistory())

        Column({ space: 12 }) {
          Row() {
            Column({ space: 2 }) {
              Text('对话列表').fontSize(17).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary')).width('100%')
              Text('当前对话与历史对话统一保存在这里')
                .fontSize(10).fontColor($r('app.color.text_tertiary')).width('100%')
            }.layoutWeight(1)
            Button('关闭').height(30).fontSize(10).borderRadius(15)
              .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.text_secondary'))
              .onClick(() => this.closeConversationHistory())
          }.width('100%')

          Button('新建对话')
            .width('100%').height(38).fontSize(11).borderRadius(19)
            .backgroundColor($r('app.color.primary_green')).fontColor(Color.Black)
            .onClick(() => {
              this.closeConversationHistory();
              this.startNewConversation();
            })

          List({ space: 10 }) {
          if (this.hasCurrentConversation()) {
            ListItem() {
              Row({ space: 10 }) {
                Column({ space: 4 }) {
                  Row({ space: 6 }) {
                    Text('当前').fontSize(9).fontWeight(FontWeight.Bold).fontColor(Color.Black)
                      .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                      .backgroundColor($r('app.color.primary_green')).borderRadius(9)
                    Text(this.conversationTitle.length > 0 ? this.conversationTitle :
                      this.resolveConversationTitle())
                      .fontSize(13).fontWeight(FontWeight.Medium)
                      .fontColor($r('app.color.text_primary')).maxLines(1)
                      .textOverflow({ overflow: TextOverflow.Ellipsis }).layoutWeight(1)
                  }.width('100%')
                  Text(`${this.chatMessages.length} 条消息 · ${this.getCompletedStepCount()}/${this.planSteps.length} 步`)
                    .fontSize(9).fontColor($r('app.color.text_tertiary')).width('100%')
                }.layoutWeight(1)
                Text('正在使用').fontSize(10).fontColor($r('app.color.primary_green'))
              }
              .width('100%').padding(12).backgroundColor($r('app.color.ring_track'))
              .border({ width: 1, color: $r('app.color.primary_green') }).borderRadius(13)
            }
          }

          ForEach(this.conversationHistory, (item: AiConversationSummary) => {
            ListItem() {
              Row({ space: 10 }) {
                Column({ space: 4 }) {
                  Text(item.title).fontSize(13).fontWeight(FontWeight.Medium)
                    .fontColor($r('app.color.text_primary')).maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
                  Text(`${this.formatConversationTime(item.updatedAt)} · ${item.messageCount} 条消息 · ` +
                    `${item.completedStepCount === undefined ? 0 : item.completedStepCount}/${item.stepCount} 步`)
                    .fontSize(9).fontColor($r('app.color.text_tertiary')).width('100%')
                }.layoutWeight(1)
                Row({ space: 6 }) {
                  Button('打开').width(54).height(32).fontSize(10).borderRadius(16).padding(0)
                    .backgroundColor($r('app.color.primary_green')).fontColor(Color.Black)
                    .onClick(() => this.openArchivedConversation(item.id))
                  Button('删除').width(54).height(32).fontSize(10).borderRadius(16).padding(0)
                    .backgroundColor('#24FA2E69').fontColor($r('app.color.primary_red'))
                    .onClick(() => this.requestDeleteConversation(item))
                }
              }
              .width('100%').padding(11).backgroundColor($r('app.color.ring_track')).borderRadius(13)
            }
          }, (item: AiConversationSummary) => item.id)

          if (!this.hasCurrentConversation() && this.conversationHistory.length === 0) {
            ListItem() {
              Column({ space: 7 }) {
                Text('还没有对话').fontSize(14).fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                Text('创建计划或向智能体提问后，对话会自动保存在此列表中')
                  .fontSize(10).fontColor($r('app.color.text_tertiary')).textAlign(TextAlign.Center)
              }
              .width('100%').padding({ top: 28, bottom: 28, left: 18, right: 18 })
              .backgroundColor($r('app.color.ring_track')).borderRadius(13)
            }
          }
          }
          .layoutWeight(1).width('100%').scrollBar(BarState.Auto)
        }
        .width('94%').height('78%').margin({ top: 54 }).padding(16)
        .backgroundColor($r('app.color.surface'))
        .border({ width: 1, color: $r('app.color.card_border') }).borderRadius(22)

        if (this.pendingDeleteConversationId.length > 0) {
          Stack({ alignContent: Alignment.Center }) {
            Column()
              .width('100%').height('100%')
              .backgroundColor('#99000000')
              .onClick(() => this.cancelDeleteConversation())

            Column({ space: 14 }) {
              Text('删除历史对话？').fontSize(18).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary')).width('100%')
              Text(`“${this.pendingDeleteConversationTitle}”删除后将无法恢复。`)
                .fontSize(12).lineHeight(19).fontColor($r('app.color.text_secondary')).width('100%')
              Row({ space: 10 }) {
                Button('取消').layoutWeight(1).height(38).fontSize(11).borderRadius(19)
                  .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.text_secondary'))
                  .onClick(() => this.cancelDeleteConversation())
                Button('确认删除').layoutWeight(1).height(38).fontSize(11).borderRadius(19)
                  .backgroundColor($r('app.color.primary_red')).fontColor(Color.White)
                  .onClick(() => this.confirmDeleteConversation())
              }.width('100%')
            }
            .width('82%').padding(18).backgroundColor($r('app.color.surface')).borderRadius(20)
          }
          .width('100%').height('100%').zIndex(31)
        }
      }
      .width('100%').height('100%').zIndex(30)
    }
  }

  @Builder
  private serviceModeChip(label: string, mode: string, green: boolean) {
    Text(label)
      .layoutWeight(1).height(36).fontSize(12).fontWeight(FontWeight.Medium)
      .fontColor(this.serviceMode === mode ? (green ? Color.Black : Color.White) :
        $r('app.color.text_secondary'))
      .textAlign(TextAlign.Center)
      .backgroundColor(this.serviceMode === mode ?
        (green ? $r('app.color.primary_green') : $r('app.color.primary_red')) :
        $r('app.color.ring_track'))
      .borderRadius(18)
      .onClick(() => {
        this.serviceMode = mode;
        this.errorMessage = '';
      })
  }

  @Builder
  private serviceCard() {
    if (this.showServiceSettings) {
      Column({ space: 10 }) {
        Column({ space: 3 }) {
          Text('AI 服务').fontSize(16).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary')).width('100%')
          Text(this.serviceMode === 'deepseek' ?
            '多轮智能体模式；密钥仅在本次运行中保留' :
            '代理模式只支持首次计划生成')
            .fontSize(11).fontColor($r('app.color.text_tertiary')).width('100%')
        }.width('100%')

        Row({ space: 8 }) {
          this.serviceModeChip('DeepSeek 智能体', 'deepseek', true)
          this.serviceModeChip('安全代理', 'proxy', false)
        }.width('100%')

        Row({ space: 10 }) {
          Column({ space: 3 }) {
            Text('记录结果后自动复盘').fontSize(12).fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary')).width('100%')
            Text('默认关闭；开启后会自动调用 DeepSeek，并产生 Token 消耗')
              .fontSize(10).fontColor($r('app.color.text_tertiary')).width('100%')
          }.layoutWeight(1)
          Toggle({ type: ToggleType.Switch, isOn: this.autoReviewEnabled })
            .selectedColor($r('app.color.primary_green'))
            .enabled(this.serviceMode === 'deepseek')
            .onChange((enabled: boolean) => this.toggleAutoReview(enabled))
        }
        .width('100%').padding(11).backgroundColor($r('app.color.ring_track')).borderRadius(12)

        if (this.serviceMode === 'deepseek') {
          TextInput({ text: this.apiKey, placeholder: '输入 DeepSeek API Key' })
            .type(InputType.Password).width('100%').height(42).fontSize(13)
            .fontColor($r('app.color.text_primary')).placeholderColor($r('app.color.text_tertiary'))
            .backgroundColor($r('app.color.ring_track')).borderRadius(12)
            .onChange((value: string) => {
              this.apiKey = value;
              this.serviceCheckMessage = '';
            })
          Row({ space: 8 }) {
            Text('V4 Flash · 日常').layoutWeight(1).height(34).fontSize(11)
              .fontColor(this.deepSeekModel === 'deepseek-v4-flash' ? Color.Black :
                $r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
              .backgroundColor(this.deepSeekModel === 'deepseek-v4-flash' ?
                $r('app.color.primary_green') : $r('app.color.ring_track'))
              .borderRadius(17).onClick(() => {
                this.deepSeekModel = 'deepseek-v4-flash';
                this.serviceCheckMessage = '';
              })
            Text('V4 Pro · 复杂规划').layoutWeight(1).height(34).fontSize(11)
              .fontColor(this.deepSeekModel === 'deepseek-v4-pro' ? Color.Black :
                $r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
              .backgroundColor(this.deepSeekModel === 'deepseek-v4-pro' ?
                $r('app.color.primary_green') : $r('app.color.ring_track'))
              .borderRadius(17).onClick(() => {
                this.deepSeekModel = 'deepseek-v4-pro';
                this.serviceCheckMessage = '';
              })
          }.width('100%')
          Button(this.isCheckingService ? '正在诊断…' : '检查密钥、余额与模型')
            .width('100%').height(38).fontSize(11).enabled(!this.isCheckingService)
            .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.primary_green'))
            .borderRadius(19).onClick(() => this.checkDeepSeekService())
          if (this.serviceCheckMessage.length > 0) {
            Text(this.serviceCheckMessage).width('100%').fontSize(10).lineHeight(16)
              .fontColor(this.serviceCheckSuccess ?
                $r('app.color.primary_green') : $r('app.color.primary_red'))
          }
          Text('诊断仅查询账户余额可用状态与模型列表，不发送目标或对话内容。')
            .width('100%').fontSize(9).fontColor($r('app.color.text_tertiary'))
          Text('直连密钥可能被调试或逆向获取；退出 App 后需重新输入。')
            .width('100%').fontSize(10).fontColor($r('app.color.primary_red'))
        } else {
          TextInput({ text: this.endpoint, placeholder: 'https://你的域名/plan' })
            .width('100%').height(42).fontSize(13)
            .fontColor($r('app.color.text_primary')).placeholderColor($r('app.color.text_tertiary'))
            .backgroundColor($r('app.color.ring_track')).borderRadius(12)
            .onChange((value: string) => this.endpoint = value)
          Button('保存代理地址').width('100%').height(38).fontSize(12)
            .backgroundColor($r('app.color.primary_red')).fontColor(Color.White).borderRadius(19)
            .onClick(() => this.saveEndpoint())
        }
        Button('完成配置').width('100%').height(36).fontSize(12)
          .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.text_secondary'))
          .borderRadius(18).onClick(() => {
            if (this.serviceMode === 'deepseek' && this.apiKey.trim().length < 10) {
              this.errorMessage = '请先填写 DeepSeek API Key';
              return;
            }
            this.showServiceSettings = false;
            this.errorMessage = '';
          })
      }
      .width('100%').padding(16).backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.card_border') }).borderRadius(18)
    }
  }

  @Builder
  private contextCard() {
    Row({ space: 8 }) {
      Column({ space: 3 }) {
        Text('今日专注').fontSize(10).fontColor($r('app.color.text_tertiary'))
        Text(this.formatSeconds(this.todayWorkSeconds)).fontSize(15).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.primary_red'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Column({ space: 3 }) {
        Text('完成番茄').fontSize(10).fontColor($r('app.color.text_tertiary'))
        Text(`${this.todayCompletedSessions}/${this.dailyTarget}`).fontSize(15).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.primary_green'))
      }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      Column({ space: 3 }) {
        Text('当前任务').fontSize(10).fontColor($r('app.color.text_tertiary'))
        Text(this.currentTask.length > 0 ? this.currentTask : '未设置').fontSize(12)
          .fontWeight(FontWeight.Medium).fontColor($r('app.color.text_primary'))
          .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
      }.layoutWeight(2).alignItems(HorizontalAlign.Start)
    }
    .width('100%').padding(12).backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.card_border') }).borderRadius(14)
  }

  @Builder
  private agentActionCard(decision: AiAgentDecision) {
    Column({ space: 9 }) {
      Row() {
        Text('下一步建议').fontSize(15).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Text(decision.stageLabel).fontSize(10).fontWeight(FontWeight.Bold)
          .fontColor(decision.stage === 'blocked' || decision.stage === 'replanning' ?
            $r('app.color.primary_red') : $r('app.color.primary_green'))
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor($r('app.color.ring_track')).borderRadius(12)
      }.width('100%')
      Text(decision.title).fontSize(13).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary')).width('100%')
      Text(decision.description).fontSize(11).lineHeight(17)
        .fontColor($r('app.color.text_secondary')).width('100%')
      Column({ space: 4 }) {
        Text(`为什么建议：${decision.reason}`).fontSize(10).lineHeight(16)
          .fontColor($r('app.color.text_secondary')).width('100%')
        Text(`执行后：${decision.expectedOutcome}`).fontSize(10).lineHeight(16)
          .fontColor($r('app.color.text_tertiary')).width('100%')
      }
      .width('100%').padding(10).backgroundColor($r('app.color.ring_track')).borderRadius(10)
      if (decision.action !== 'none') {
        Button(decision.actionLabel)
          .width('100%').height(38).fontSize(12)
          .enabled(decision.action !== 'wait' && !this.isLoading)
          .backgroundColor(decision.action === 'wait' ? $r('app.color.ring_track') :
            $r('app.color.primary_green'))
          .fontColor(decision.action === 'wait' ? $r('app.color.text_tertiary') : Color.Black)
          .borderRadius(19).onClick(() => this.runRecommendedAction())
        if (decision.usesAi) {
          Text('此操作会调用当前 AI 服务并产生 Token 消耗')
            .fontSize(9).fontColor($r('app.color.text_tertiary')).width('100%')
            .textAlign(TextAlign.Center)
        }
        if (decision.action === 'retry' && this.planSteps.length === 0) {
          Button('使用本地应急计划')
            .width('100%').height(36).fontSize(11).enabled(!this.isLoading)
            .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.text_secondary'))
            .borderRadius(18).onClick(() => this.createLocalFallbackPlan())
          Text('不调用 AI；仅依据目标、可用时间和当前番茄参数生成基础执行步骤')
            .fontSize(9).fontColor($r('app.color.text_tertiary')).width('100%')
            .textAlign(TextAlign.Center)
        }
      }
    }
    .width('100%').padding(14).backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: decision.stage === 'blocked' || decision.stage === 'replanning' ?
      $r('app.color.primary_red') : $r('app.color.card_border') }).borderRadius(16)
  }

  @Builder
  private agentMemoryCard() {
    if (this.planSteps.length > 0 || this.primaryGoal.length > 0) {
      Column({ space: 9 }) {
        Row() {
          Column({ space: 3 }) {
            Text('智能体记忆').fontSize(14).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).width('100%')
            Text(this.primaryGoal.length > 0 ? `主目标：${this.primaryGoal}` : '主目标尚未明确')
              .fontSize(10).fontColor($r('app.color.text_secondary')).maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis }).width('100%')
          }.layoutWeight(1)
          Button(this.showAgentMemory ? '收起' : '查看')
            .height(30).fontSize(10).borderRadius(15)
            .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.text_secondary'))
            .onClick(() => this.showAgentMemory = !this.showAgentMemory)
        }.width('100%')
        if (this.showAgentMemory) {
          Column({ space: 8 }) {
            Text('长期节奏').fontSize(10).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_green')).width('100%')
            Text(this.agentMemory.longTermSummary).fontSize(10).lineHeight(16)
              .fontColor($r('app.color.text_secondary')).width('100%')
            Text('本轮记忆').fontSize(10).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_green')).width('100%')
            Text(this.agentMemory.shortTermSummary).fontSize(10).lineHeight(16)
              .fontColor($r('app.color.text_secondary')).width('100%')
            if (this.executionInsight.status !== 'no_data') {
              Text(this.executionInsight.title).fontSize(10).fontWeight(FontWeight.Bold)
                .fontColor(this.executionInsight.shouldReplan ?
                  $r('app.color.primary_red') : $r('app.color.primary_green')).width('100%')
              Text(this.executionInsight.description).fontSize(10).lineHeight(16)
                .fontColor($r('app.color.text_secondary')).width('100%')
            }
          }.width('100%')
        }
      }
      .width('100%').padding(13).backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.card_border') }).borderRadius(15)
    }
  }

  @Builder
  private planInsightCard(insight: AiPlanInsight, quality: AiPlanQualityInsight) {
    Column({ space: 11 }) {
      Row() {
        Column({ space: 3 }) {
          Text('本地计划健康度').fontSize(15).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary')).width('100%')
          Text(insight.title).fontSize(11)
            .fontColor(insight.status === 'over_capacity' ?
              $r('app.color.primary_red') : $r('app.color.primary_green')).width('100%')
        }.layoutWeight(1)
        Text(`${insight.feasibilityPercent}% 可行度`).fontSize(10).fontWeight(FontWeight.Bold)
          .fontColor(insight.status === 'over_capacity' ?
            $r('app.color.primary_red') : $r('app.color.primary_green'))
          .padding({ left: 10, right: 10, top: 6, bottom: 6 })
          .backgroundColor($r('app.color.ring_track')).borderRadius(13)
      }.width('100%')
      Row({ space: 8 }) {
        Column({ space: 3 }) {
          Text('计划进度').fontSize(9).fontColor($r('app.color.text_tertiary'))
          Text(`${insight.progressPercent}%`).fontSize(16).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Column({ space: 3 }) {
          Text('剩余番茄').fontSize(9).fontColor($r('app.color.text_tertiary'))
          Text(`${insight.remainingPomodoros}`).fontSize(16).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Column({ space: 3 }) {
          Text('预计耗时').fontSize(9).fontColor($r('app.color.text_tertiary'))
          Text(this.formatMinutes(insight.requiredMinutes)).fontSize(13).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
      }.width('100%')
      Text(insight.description).fontSize(11).lineHeight(17)
        .fontColor($r('app.color.text_secondary')).width('100%')
      Column({ space: 6 }) {
        Row() {
          Text('本地计划质检').fontSize(11).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary')).layoutWeight(1)
          Text(`${quality.score} 分`).fontSize(10).fontWeight(FontWeight.Bold)
            .fontColor(quality.status === 'strong' ?
              $r('app.color.primary_green') : $r('app.color.primary_red'))
        }.width('100%')
        Text(quality.description).fontSize(10).lineHeight(16)
          .fontColor($r('app.color.text_secondary')).width('100%')
        if (quality.status !== 'strong' && quality.status !== 'empty' && insight.status !== 'completed') {
          Button(this.serviceMode === 'deepseek' ? '让 AI 按质检结果修正' : '使用质检修正建议')
            .width('100%').height(34).fontSize(10).enabled(!this.isLoading)
            .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.primary_red'))
            .borderRadius(17).onClick(() => this.requestPlanQualityImprovement(quality))
        }
      }
      .width('100%').padding(10).backgroundColor($r('app.color.ring_track')).borderRadius(12)
      if (insight.status !== 'completed') {
        Row({ space: 8 }) {
          Button(!quality.canApply ? '先修正计划' :
            (this.canApplyStep ? '设为下一任务' : '计时结束后设置'))
            .layoutWeight(1).height(36).fontSize(11).enabled(this.canApplyStep && quality.canApply)
            .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.primary_green'))
            .borderRadius(18)
            .onClick(() => this.applyNextStep())
          Button(this.canApplyStep ? '立即开始专注' : '当前阶段进行中')
            .layoutWeight(1).height(36).fontSize(11).enabled(this.canApplyStep && quality.canApply)
            .backgroundColor($r('app.color.primary_green')).fontColor(Color.Black).borderRadius(18)
            .onClick(() => this.startNextStep())
        }.width('100%')
        if (insight.status === 'over_capacity' || insight.status === 'tight') {
          Button(this.isLoading ? '正在重排…' : 'AI 压缩计划')
            .width('100%').height(36).fontSize(11).enabled(!this.isLoading)
            .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.primary_red'))
            .borderRadius(18).onClick(() => this.requestPlanCompression())
        }
      }
    }
    .width('100%').padding(14).backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: insight.status === 'over_capacity' ?
      $r('app.color.primary_red') : $r('app.color.card_border') }).borderRadius(16)
  }

  @Builder
  private goalReadinessCard(readiness: AiGoalReadinessInsight) {
    Column({ space: 4 }) {
      Row({ space: 6 }) {
        Text(readiness.ready ? '✓' : '!').fontSize(11).fontWeight(FontWeight.Bold)
          .fontColor(readiness.ready ? $r('app.color.primary_green') : $r('app.color.primary_red'))
        Text(readiness.title).fontSize(11).fontWeight(FontWeight.Bold)
          .fontColor(readiness.ready ? $r('app.color.primary_green') : $r('app.color.primary_red'))
      }.width('100%')
      Text(readiness.ready ? readiness.description : readiness.question)
        .fontSize(10).lineHeight(15).fontColor($r('app.color.text_secondary')).width('100%')
    }
    .width('100%').padding(10).backgroundColor($r('app.color.ring_track')).borderRadius(12)
  }

  @Builder
  private deadlineInsightCard(insight: AiDeadlineInsight) {
    if (insight.status !== 'none') {
      Column({ space: 4 }) {
        Row({ space: 6 }) {
          Text(insight.status === 'valid' ? '✓' : '!').fontSize(11).fontWeight(FontWeight.Bold)
            .fontColor(insight.status === 'valid' ?
              $r('app.color.primary_green') : $r('app.color.primary_red'))
          Text(insight.title).fontSize(11).fontWeight(FontWeight.Bold)
            .fontColor(insight.status === 'valid' ?
              $r('app.color.primary_green') : $r('app.color.primary_red'))
        }.width('100%')
        Text(insight.description).fontSize(10).lineHeight(15)
          .fontColor($r('app.color.text_secondary')).width('100%')
        if (insight.status === 'valid') {
          Text(`已标准化：${insight.normalizedDeadline}`)
            .fontSize(9).fontColor($r('app.color.text_tertiary')).width('100%')
        }
      }
      .width('100%').padding(10).backgroundColor($r('app.color.ring_track')).borderRadius(12)
    }
  }

  @Builder
  private wearableAdjustmentCard() {
    if (this.pendingWearableAdjustment.id.length > 0) {
      Column({ space: 9 }) {
        Row({ space: 7 }) {
          Text('穿戴端请求调整').fontSize(14).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Text('待确认').fontSize(9).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.accent_yellow'))
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor($r('app.color.ring_track')).borderRadius(10)
        }.width('100%')
        Text(this.pendingWearableAdjustment.recommendationTitle)
          .fontSize(12).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.primary_green')).width('100%')
        Text(this.pendingWearableAdjustment.summary)
          .fontSize(10).lineHeight(15).fontColor($r('app.color.text_secondary')).width('100%')
        Column({ space: 4 }) {
          Text('允许动作').fontSize(10).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary')).width('100%')
          Text(this.pendingWearableAdjustment.allowedActions.join(' · '))
            .fontSize(9).lineHeight(14).fontColor($r('app.color.text_secondary')).width('100%')
          Text('保护规则').fontSize(10).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary')).width('100%')
          Text(this.pendingWearableAdjustment.protectedRules.join(' · '))
            .fontSize(9).lineHeight(14).fontColor($r('app.color.primary_red')).width('100%')
        }
        .width('100%').padding(10).backgroundColor($r('app.color.ring_track')).borderRadius(12)
        Row({ space: 8 }) {
          Button('忽略').layoutWeight(1).height(36).fontSize(10).borderRadius(18)
            .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.text_secondary'))
            .onClick(() => {
              this.successMessage = '已忽略本次穿戴端调整请求';
              this.clearWearableAdjustment();
            })
          Button('确认并预填').layoutWeight(1).height(36).fontSize(10).fontWeight(FontWeight.Bold)
            .borderRadius(18).backgroundColor($r('app.color.primary_green')).fontColor(Color.Black)
            .onClick(() => this.confirmWearableAdjustment())
        }.width('100%')
        Text('确认只会预填请求，不会自动调用 AI，也不会直接修改当前计划。')
          .fontSize(9).lineHeight(14).fontColor($r('app.color.text_tertiary')).width('100%')
      }
      .width('100%').padding(14).backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.accent_yellow') }).borderRadius(16)
    }
  }

  @Builder
  private inputCard() {
    Column({ space: 12 }) {
      Column({ space: 3 }) {
        Text(this.planSteps.length > 0 ? '提出新目标或整体重排' : '你想完成什么？')
          .fontSize(17).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary')).width('100%')
        Text('智能体会参考你的真实专注历史，而不是只看这一句话')
          .fontSize(11).fontColor($r('app.color.text_tertiary')).width('100%')
      }.width('100%')
      TextArea({ text: this.goal, placeholder: '例如：今晚完成课程报告大纲并找到 3 篇参考资料' })
        .width('100%').height(92).fontSize(14).fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_tertiary')).backgroundColor($r('app.color.ring_track'))
        .borderRadius(14).padding(12).onChange((value: string) => this.goal = value)
      if (this.goal.trim().length > 0) {
        this.goalReadinessCard(this.getGoalReadiness())
      }
      Scroll() {
        Row({ space: 8 }) {
          ForEach(this.examples, (example: string) => {
            Text(example).fontSize(11).fontColor($r('app.color.text_secondary')).maxLines(1)
              .padding({ left: 11, right: 11, top: 7, bottom: 7 })
              .backgroundColor($r('app.color.ring_track')).borderRadius(14)
              .onClick(() => this.goal = example)
          }, (example: string) => example)
        }
      }.scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off).width('100%')
      Row({ space: 8 }) {
        Text(`可用 ${this.formatMinutes(this.availableMinutes)}`)
          .fontSize(12).fontColor($r('app.color.text_secondary')).layoutWeight(1)
        Button() { Image($r('app.media.minus')).width(13).height(13)
          .fillColor($r('app.color.text_secondary')) }
          .width(32).height(32).borderRadius(16).backgroundColor($r('app.color.ring_track'))
          .onClick(() => this.changeAvailableMinutes(-this.workMinutes))
        Button() { Image($r('app.media.plus')).width(13).height(13).fillColor(Color.Black) }
          .width(32).height(32).borderRadius(16).backgroundColor($r('app.color.primary_green'))
          .onClick(() => this.changeAvailableMinutes(this.workMinutes))
      }.width('100%')
      TextInput({ text: this.deadline, placeholder: '截止时间（可选，如：周五 18:00）' })
        .width('100%').height(40).fontSize(12).fontColor($r('app.color.text_primary'))
        .placeholderColor($r('app.color.text_tertiary')).backgroundColor($r('app.color.ring_track'))
        .borderRadius(12).onChange((value: string) => {
          this.deadline = value;
          this.errorMessage = '';
        })
      Row({ space: 8 }) {
        Button('今晚 22:00').layoutWeight(1).height(32).fontSize(9).borderRadius(16)
          .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.text_secondary'))
          .onClick(() => this.setDeadlineShortcut('今晚 22:00'))
        Button('明天 18:00').layoutWeight(1).height(32).fontSize(9).borderRadius(16)
          .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.text_secondary'))
          .onClick(() => this.setDeadlineShortcut('明天 18:00'))
        Button('清除截止').layoutWeight(1).height(32).fontSize(9).borderRadius(16)
          .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.text_tertiary'))
          .onClick(() => this.setDeadlineShortcut(''))
      }.width('100%')
      this.deadlineInsightCard(this.getDeadlineInsight())
      Button(this.isLoading ? '智能体正在分析…' : '生成或重排计划')
        .width('100%').height(46).fontSize(14).fontWeight(FontWeight.Bold)
        .enabled(!this.isLoading && this.pendingPlanSteps.length === 0 && this.getGoalReadiness().ready &&
          this.getDeadlineInsight().status !== 'unsupported' &&
          this.getDeadlineInsight().status !== 'expired')
        .backgroundColor($r('app.color.primary_green')).fontColor(Color.Black).borderRadius(23)
        .onClick(() => this.generatePlan())
    }
    .width('100%').padding(16).backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: $r('app.color.card_border') }).borderRadius(18)
  }

  @Builder
  private conversationCard() {
    if (this.chatMessages.length > 0) {
      Column({ space: 8 }) {
        Row() {
          Text('对话').fontSize(15).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
          Blank()
          if (this.lastTotalTokens > 0) {
            Text(`本次 ${this.lastTotalTokens} tokens`).fontSize(9)
              .fontColor($r('app.color.text_tertiary'))
          }
        }.width('100%')
        ForEach(this.chatMessages, (message: AiChatMessage, index: number) => {
          Row() {
            if (message.role === 'user') { Blank().layoutWeight(1) }
            Text(message.content).fontSize(12).lineHeight(18)
              .fontColor(message.role === 'user' ? Color.Black : $r('app.color.text_primary'))
              .padding({ left: 12, right: 12, top: 9, bottom: 9 })
              .backgroundColor(message.role === 'user' ?
                $r('app.color.primary_green') : $r('app.color.ring_track'))
              .borderRadius(14).constraintSize({ maxWidth: '86%' })
            if (message.role !== 'user') { Blank().layoutWeight(1) }
          }.width('100%')
        }, (message: AiChatMessage, index: number) => `${message.createdAt}-${index}`)
      }
      .width('100%').padding(14).backgroundColor($r('app.color.surface')).borderRadius(16)
    }
  }

  @Builder
  private followUpCard() {
    if (this.planSteps.length > 0 && this.pendingPlanSteps.length === 0) {
      Column({ space: 8 }) {
        Text('继续调整').fontSize(14).fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary')).width('100%')
        TextInput({ text: this.followUp, placeholder: '例如：第三步太难了，再拆细一点' })
          .width('100%').height(42).fontSize(12).fontColor($r('app.color.text_primary'))
          .placeholderColor($r('app.color.text_tertiary')).backgroundColor($r('app.color.ring_track'))
          .borderRadius(12).onChange((value: string) => this.followUp = value)
        if (this.planSource === 'local') {
          Button('联网后让 AI 优化这份应急计划')
            .width('100%').height(38).fontSize(11).enabled(!this.isLoading)
            .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.primary_green'))
            .borderRadius(19).onClick(async () => {
              this.followUp = '请检查当前本地应急计划，在不增加总番茄数的前提下优化步骤、交付物和风险预案。';
              await this.sendFollowUp();
            })
        }
        Row({ space: 8 }) {
          Button('时间减半').layoutWeight(1).height(34).fontSize(10)
            .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.text_secondary'))
            .borderRadius(17).onClick(() => this.followUp = '我的可用时间减半，请保留最重要的成果并重新安排。')
          Button('拆得更细').layoutWeight(1).height(34).fontSize(10)
            .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.text_secondary'))
            .borderRadius(17).onClick(() => this.followUp = '当前步骤太笼统，请拆成更小、更容易开始的动作。')
          Button('发送').layoutWeight(1).height(34).fontSize(11).enabled(!this.isLoading)
            .backgroundColor($r('app.color.primary_green')).fontColor(Color.Black)
            .borderRadius(17).onClick(() => this.sendFollowUp())
        }.width('100%')
      }
      .width('100%').padding(14).backgroundColor($r('app.color.surface')).borderRadius(16)
    }
  }

  @Builder
  private planProposalCard(stats: AiPlanProposalStats) {
    if (this.pendingPlanSteps.length > 0) {
      Column({ space: 12 }) {
        Row({ space: 8 }) {
          Column({ space: 3 }) {
            Text('AI 计划修改提案').fontSize(16).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).width('100%')
            Text('提案尚未生效，你可以逐项决定是否采用')
              .fontSize(10).fontColor($r('app.color.text_tertiary')).width('100%')
          }.layoutWeight(1).alignItems(HorizontalAlign.Start)
          Text('待确认').fontSize(9).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.accent_yellow'))
            .padding({ left: 9, right: 9, top: 5, bottom: 5 })
            .backgroundColor($r('app.color.ring_track')).borderRadius(12)
        }.width('100%')

        Text(this.pendingPlanSummary).fontSize(11).lineHeight(17)
          .fontColor($r('app.color.text_secondary')).width('100%')

        Row({ space: 7 }) {
          Text(`+${stats.added} 新增`).fontSize(9).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary_green')).padding({ left: 8, right: 8, top: 5, bottom: 5 })
            .backgroundColor($r('app.color.ring_track')).borderRadius(10)
          Text(`~${stats.modified} 修改`).fontSize(9).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.accent_yellow')).padding({ left: 8, right: 8, top: 5, bottom: 5 })
            .backgroundColor($r('app.color.ring_track')).borderRadius(10)
          Text(`-${stats.removed} 删除`).fontSize(9).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.primary_red')).padding({ left: 8, right: 8, top: 5, bottom: 5 })
            .backgroundColor($r('app.color.ring_track')).borderRadius(10)
          Blank()
          Text(`${stats.currentPomodoros} → ${stats.candidatePomodoros} 番茄`)
            .fontSize(9).fontColor($r('app.color.text_secondary'))
        }.width('100%')

        Column({ space: 8 }) {
          ForEach(this.getPendingPlanChanges(), (change: AiPlanChange) => {
            Row({ space: 10 }) {
              Button(change.type === 'unchanged' ? '—' : (change.selected ? '✓' : ''))
                .width(30).height(30).fontSize(12).fontWeight(FontWeight.Bold).padding(0)
                .enabled(change.type !== 'unchanged')
                .fontColor(change.selected ? Color.Black : $r('app.color.text_tertiary'))
                .backgroundColor(change.selected ?
                  $r('app.color.primary_green') : $r('app.color.ring_track'))
                .borderRadius(15).onClick(() => this.togglePendingPlanSelection(change.index))
              Column({ space: 3 }) {
                Row({ space: 6 }) {
                  Text(this.getChangeLabel(change)).fontSize(9).fontWeight(FontWeight.Bold)
                    .fontColor(change.type === 'added' ? $r('app.color.primary_green') :
                      (change.type === 'removed' ? $r('app.color.primary_red') :
                        $r('app.color.accent_yellow')))
                  Text(this.getChangeTitle(change)).fontSize(12).fontWeight(FontWeight.Bold)
                    .fontColor($r('app.color.text_primary')).layoutWeight(1).maxLines(1)
                    .textOverflow({ overflow: TextOverflow.Ellipsis })
                }.width('100%')
                Text(this.getChangeDetail(change)).fontSize(9).lineHeight(14)
                  .fontColor($r('app.color.text_tertiary')).width('100%')
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
            }
            .width('100%').padding(10).backgroundColor($r('app.color.ring_track')).borderRadius(12)
          }, (change: AiPlanChange) => `${change.index}-${change.type}`)
        }.width('100%')

        Row({ space: 8 }) {
          Button('全选').layoutWeight(1).height(32).fontSize(9).borderRadius(16)
            .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.text_secondary'))
            .onClick(() => this.selectAllPendingChanges(true))
          Button('清除选择').layoutWeight(1).height(32).fontSize(9).borderRadius(16)
            .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.text_secondary'))
            .onClick(() => this.selectAllPendingChanges(false))
        }.width('100%')
        Row({ space: 8 }) {
          Button('拒绝').layoutWeight(1).height(38).fontSize(10).borderRadius(19)
            .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.primary_red'))
            .onClick(() => this.rejectPendingPlan())
          Button(`应用所选（${stats.selected}）`).layoutWeight(1).height(38).fontSize(10).borderRadius(19)
            .enabled(stats.selected > 0).backgroundColor($r('app.color.ring_track'))
            .fontColor($r('app.color.primary_green')).onClick(() => this.applyPendingPlan(false))
          Button('全部应用').layoutWeight(1).height(38).fontSize(10).fontWeight(FontWeight.Bold)
            .borderRadius(19).backgroundColor($r('app.color.primary_green')).fontColor(Color.Black)
            .onClick(() => this.applyPendingPlan(true))
        }.width('100%')
      }
      .width('100%').padding(15).backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.accent_yellow') }).borderRadius(18)
    }
  }

  @Builder
  private planVersionCard() {
    if (this.previousPlanSteps.length > 0) {
      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Text('已保留上个计划版本')
            .fontSize(11).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.accent_yellow')).width('100%')
          Text(`AI 调整前 · ${this.previousPlanSteps.length} 步 · ${
            this.previousPlanSource === 'local' ? '本地应急' : '联网计划'}`)
            .fontSize(9).fontColor($r('app.color.text_tertiary')).width('100%')
          Text('恢复不会调用 AI；恢复后当前新版本将不再保留')
            .fontSize(9).fontColor($r('app.color.text_secondary')).width('100%')
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Button(this.canApplyStep ? '恢复上版' : '本轮结束后恢复')
          .height(32).fontSize(10).borderRadius(16).enabled(!this.isLoading && this.canApplyStep)
          .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.accent_yellow'))
          .onClick(() => this.restorePreviousPlan())
      }
      .width('100%').padding(12).backgroundColor($r('app.color.surface'))
      .border({ width: 1, color: $r('app.color.accent_yellow') }).borderRadius(14)
    }
  }

  @Builder
  private planCard(step: AiPlanStep, index: number) {
    Column({ space: 9 }) {
      Row({ space: 10 }) {
        Button(step.completed ? '✓' : `${index + 1}`)
          .width(30).height(30).fontSize(12).fontWeight(FontWeight.Bold)
          .fontColor(step.completed ? Color.Black : $r('app.color.text_primary'))
          .backgroundColor(step.completed ? $r('app.color.primary_green') : $r('app.color.ring_track'))
          .borderRadius(15).onClick(() => this.toggleStepCompleted(index))
        Column({ space: 3 }) {
          Text(step.title).fontSize(15).fontWeight(FontWeight.Bold)
            .fontColor(step.completed ? $r('app.color.text_tertiary') : $r('app.color.text_primary'))
            .decoration({ type: step.completed ? TextDecorationType.LineThrough : TextDecorationType.None })
            .width('100%')
          Text(this.formatStepProgress(step))
            .fontSize(10).fontColor($r('app.color.primary_green')).width('100%')
        }.layoutWeight(1)
      }.width('100%')
      if (step.note.length > 0) {
        Text(step.note).fontSize(12).lineHeight(18).fontColor($r('app.color.text_secondary')).width('100%')
      }
      if (!step.completed) {
        Row({ space: 8 }) {
          Button(!this.getPlanQuality(this.getPlanInsight()).canApply ? '先修正计划' : '设为任务')
            .layoutWeight(1).height(36).fontSize(10)
            .enabled(this.canApplyStep && this.getPlanQuality(this.getPlanInsight()).canApply)
            .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.primary_green'))
            .borderRadius(18).onClick(() => this.applyStep(step))
          Button(this.canApplyStep ? '立即开始' : '阶段进行中')
            .layoutWeight(1).height(36).fontSize(10)
            .enabled(this.canApplyStep && this.getPlanQuality(this.getPlanInsight()).canApply)
            .backgroundColor($r('app.color.primary_green')).fontColor(Color.Black)
            .borderRadius(18).onClick(() => this.startStep(step))
        }.width('100%')
      }
    }
    .width('100%').padding(14).backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: step.completed ? $r('app.color.primary_green') : $r('app.color.card_border') })
    .borderRadius(16)
  }

  @Builder
  private plannerControlPane() {
    Column({ space: 12 }) {
      this.serviceCard()
      this.tokenBudgetCard(this.getTokenBudgetInsight())
      this.requestTraceCard()
      this.contextCard()
      this.agentMemoryCard()
      if (this.needsReview && this.lastCompletedStepTitle.length > 0) {
        this.executionCheckInCard()
      }
      if (this.shouldShowAgentSuggestion(this.getAgentDecision()) &&
        (!this.needsReview || this.hasCurrentExecutionCheckIn())) {
        this.agentActionCard(this.getAgentDecision())
      }
      this.wearableAdjustmentCard()
      this.inputCard()
    }.width('100%')
  }

  @Builder
  private plannerResultPane() {
    Column({ space: 12 }) {
      if (this.errorMessage.length > 0) {
        Text(this.errorMessage).width('100%').fontSize(12).fontColor($r('app.color.primary_red'))
          .padding(12).backgroundColor('#24FA2E69').borderRadius(12)
      }
      if (this.successMessage.length > 0) {
        Text(this.successMessage).width('100%').fontSize(12).fontColor($r('app.color.primary_green'))
          .padding(12).backgroundColor('#2065FE08').borderRadius(12)
      }
      this.conversationCard()
      this.planProposalCard(this.getPendingPlanStats())
      if (this.planSteps.length > 0) {
        Row() {
          Text('执行计划').fontSize(16).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Blank()
          if (this.planSource !== 'none') {
            Text(this.planSource === 'local' ? '本地应急' : '联网智能体')
              .fontSize(9).fontWeight(FontWeight.Bold)
              .fontColor(this.planSource === 'local' ?
                $r('app.color.primary_red') : $r('app.color.primary_green'))
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .backgroundColor($r('app.color.ring_track')).borderRadius(10)
              .margin({ right: 8 })
          }
          Text(`${this.getCompletedStepCount()}/${this.planSteps.length}`)
            .fontSize(12).fontColor($r('app.color.primary_green'))
        }.width('100%').padding({ left: 4, right: 4 })
        if (this.summary.length > 0) {
          Text(this.summary).width('100%').fontSize(12).lineHeight(19)
            .fontColor($r('app.color.text_secondary')).padding(14)
            .backgroundColor($r('app.color.surface')).borderRadius(16)
        }
        this.planVersionCard()
        this.planInsightCard(this.getPlanInsight(), this.getPlanQuality(this.getPlanInsight()))
        ForEach(this.planSteps, (step: AiPlanStep, index: number) => {
          this.planCard(step, index)
        }, (step: AiPlanStep, index: number) => `${index}-${step.title}`)
      }
      this.followUpCard()
    }.width('100%')
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column({ space: 12 }) {
        this.pageHeader()
        this.workflowStageBar()
        Scroll() {
          GridRow({
            columns: { xs: 4, sm: 12 },
            gutter: { x: 12, y: 12 },
            breakpoints: { value: ['720vp'], reference: BreakpointsReference.WindowSize }
          }) {
            GridCol({ span: { xs: 4, sm: 5 } }) {
              this.plannerControlPane()
            }
            GridCol({ span: { xs: 4, sm: 7 } }) {
              this.plannerResultPane()
            }
          }.width('100%').padding({ bottom: 20 })
        }.scrollBar(BarState.Off).layoutWeight(1).width('100%')
      }
      .width('100%').height('100%').padding({ left: 12, right: 12, top: 10 })

      this.conversationListOverlay()
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.background'))
  }
}
