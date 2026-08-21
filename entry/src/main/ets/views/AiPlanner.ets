import { PreferencesHelper, SessionRecord } from '../utils/PreferencesHelper';
import { AiPlanResult, AiPlannerService } from '../utils/AiPlannerService';
import { AiPlanInsightHelper } from '../utils/AiPlanInsightHelper';
import { AiAgentDecisionHelper } from '../utils/AiAgentDecisionHelper';
import { AiAgentP1Helper, AiExecutionRecord } from '../utils/AiAgentP1Helper';
import { LocalFallbackPlanHelper } from '../utils/LocalFallbackPlanHelper';
import {
  AiAgentDecision,
  AiAgentMemory,
  AiAgentResult,
  AiAgentState,
  AiChatMessage,
  AiConversationSummary,
  AiExecutionInsight,
  AiFocusContext,
  AiGoalDriftInsight,
  AiPlan,
  AiPlanInsight,
  AiPlanStep
} from '../utils/AiAgentModels';

@Component
export struct AiPlanner {
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
  @State serviceMode: string = 'deepseek';
  @State apiKey: string = '';
  @State deepSeekModel: string = 'deepseek-v4-flash';
  @State endpoint: string = '';
  @State goal: string = '';
  @State deadline: string = '';
  @State availableMinutes: number = 120;
  @State isLoading: boolean = false;
  @State showServiceSettings: boolean = false;
  @State summary: string = '';
  @State planSteps: AiPlanStep[] = [];
  @State chatMessages: AiChatMessage[] = [];
  @State followUp: string = '';
  @State errorMessage: string = '';
  @State successMessage: string = '';
  @State needsReview: boolean = false;
  @State lastCompletedStepTitle: string = '';
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
  onApplyStep?: (step: AiPlanStep, conversationId: string) => void;

  private examples: string[] = [
    '今晚复习两章高数并完成课后题',
    '三天内完成产品需求文档初稿',
    '用两个小时整理本周工作并规划下周'
  ];

  async aboutToAppear(): Promise<void> {
    this.endpoint = await PreferencesHelper.loadAiServiceEndpoint(this.getContext());
    this.autoReviewEnabled = await PreferencesHelper.loadAiAutoReview(this.getContext());
    await this.loadAgentState();
    await this.loadConversationHistory();
    await this.refreshAgentAnalysis();
    await this.tryAutoReview();
    this.showServiceSettings = this.apiKey.length === 0;
  }

  async onActiveChange(): Promise<void> {
    if (this.active) {
      await this.loadAgentState();
      await this.loadConversationHistory();
      await this.refreshAgentAnalysis();
      await this.tryAutoReview();
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
    this.planSource = typeof state.planSource === 'string' ? state.planSource :
      (state.plan.summary.indexOf('本地应急计划：') === 0 ? 'local' :
        (state.plan.steps.length > 0 ? 'ai' : 'none'));
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
      availableMinutes: this.availableMinutes,
      deadline: this.deadline,
      primaryGoal: this.primaryGoal,
      memory: this.agentMemory,
      goalDrift: this.goalDriftInsight,
      lastAutoReviewAttemptTitle: this.lastAutoReviewAttemptTitle,
      lastExecutionReplanKey: this.lastExecutionReplanKey,
      planSource: this.planSource
    };
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
    this.lastTotalTokens = 0;
    this.errorMessage = '';
    this.lastFailedMessage = '';
    this.primaryGoal = '';
    this.agentMemory = AiAgentP1Helper.emptyMemory();
    this.goalDriftInsight = AiAgentP1Helper.emptyDrift();
    this.executionInsight = AiAgentP1Helper.emptyExecution();
    this.lastAutoReviewAttemptTitle = '';
    this.lastExecutionReplanKey = '';
    this.planSource = 'none';
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
        recentSummary += '\n';
      }
    }
    const insight = this.getPlanInsight();
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
      availableMinutes: this.availableMinutes,
      deadline: this.deadline.trim().length > 0 ? this.deadline.trim() : '未指定',
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
      this.successMessage = '已开启自动复盘；完成计划步骤后会调用 DeepSeek';
      await this.tryAutoReview();
    } else {
      this.successMessage = '已关闭自动复盘';
    }
  }

  private async tryAutoReview(): Promise<void> {
    if (!this.autoReviewEnabled || this.serviceMode !== 'deepseek' || !this.isServiceReady() ||
      !this.needsReview || this.lastCompletedStepTitle.length === 0 || this.isLoading ||
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
      this.planSteps, this.availableMinutes, this.workMinutes, this.breakMinutes,
      tracksCurrentPlan ? this.currentTask : '', tracksCurrentPlan ? this.currentProject : '',
      tracksCurrentPlan ? this.currentTaskCompleted : 0);
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

  private async requestPlanCompression(): Promise<void> {
    const insight = this.getPlanInsight();
    const message = `当前计划剩余 ${insight.remainingPomodoros} 个番茄，预计需要 ` +
      `${insight.requiredMinutes} 分钟，但我现在只有 ${this.availableMinutes} 分钟。` +
      `请保留最有价值的可交付成果，压缩或合并后续步骤，并保留合理缓冲。`;
    await this.askAgent(message);
  }

  private async alignWithPrimaryGoal(): Promise<void> {
    if (this.primaryGoal.length === 0) {
      this.errorMessage = '当前没有可用于校准的主目标';
      return;
    }
    const message = `请以主目标“${this.primaryGoal}”为唯一方向，重新检查当前计划。` +
      `只吸收最近指令中与主目标一致的调整，删除无关内容，并给出下一步。`;
    if (await this.askAgent(message)) {
      this.goalDriftInsight = AiAgentP1Helper.emptyDrift();
      await this.saveAgentState(false);
    }
  }

  private async requestExecutionReplan(): Promise<void> {
    const key = this.getExecutionReplanKey(this.executionInsight);
    const message = `真实执行数据表明：${this.executionInsight.description}` +
      `请按实际速度重排剩余计划，保留已完成步骤，并重新设置估时和缓冲。`;
    if (await this.askAgent(message)) {
      this.lastExecutionReplanKey = key;
      await this.refreshAgentAnalysis();
      await this.saveAgentState(false);
    }
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
    const fallbackGoal = this.resolveFallbackGoal();
    const requestText = this.lastFailedMessage.length > 0 ? this.lastFailedMessage :
      `请为“${fallbackGoal}”制定计划。`;
    const plan = LocalFallbackPlanHelper.create(
      fallbackGoal, this.availableMinutes, this.deadline, this.workMinutes, this.breakMinutes);
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

  private async askAgent(message: string): Promise<boolean> {
    if (this.isLoading) {
      return false;
    }
    const normalized = message.trim();
    if (normalized.length < 2) {
      this.errorMessage = '请告诉 AI 你想规划或调整什么';
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
        const focusContext = await this.buildFocusContext();
        this.goalDriftInsight = this.planSteps.length > 0 ?
          AiAgentP1Helper.detectGoalDrift(
            this.primaryGoal, normalized, { summary: this.summary, steps: this.planSteps }) :
          AiAgentP1Helper.emptyDrift();
        await this.updateAgentAnalysis(focusContext);
        const result: AiAgentResult = await AiPlannerService.continueDeepSeekAgent(
          this.apiKey, this.deepSeekModel, normalized, this.chatMessages,
          { summary: this.summary, steps: this.planSteps }, focusContext,
          this.agentMemory, this.goalDriftInsight, this.executionInsight);
        if (!result.success) {
          this.errorMessage = result.errorMessage;
          this.lastFailedMessage = normalized;
          return false;
        }
        this.appendMessages(normalized, result.reply);
        this.summary = result.plan.summary;
        this.planSteps = result.plan.steps;
        this.planSource = 'ai';
        this.lastTotalTokens = result.usage.totalTokens;
        this.lastFailedMessage = '';
        this.needsReview = false;
        await this.refreshAgentAnalysis();
        await this.saveAgentState(false);
        return true;
      }

      if (this.chatMessages.length > 0) {
        this.errorMessage = '安全代理模式暂未升级多轮协议，请使用 DeepSeek 直连';
        this.lastFailedMessage = '';
        return false;
      }
      const result: AiPlanResult = await AiPlannerService.createPlan(
        this.endpoint, normalized, this.availableMinutes, this.deadline, this.workMinutes, this.breakMinutes);
      if (!result.success) {
        this.errorMessage = result.errorMessage;
        this.lastFailedMessage = normalized;
        return false;
      }
      this.summary = result.plan.summary;
      this.planSteps = result.plan.steps;
      this.planSource = 'ai';
      this.appendMessages(normalized, result.plan.summary);
      this.lastFailedMessage = '';
      await this.refreshAgentAnalysis();
      await this.saveAgentState(false);
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
    if (this.goal.trim().length < 4) {
      this.errorMessage = '请更具体地描述你想完成的目标';
      return;
    }
    const deadlineText = this.deadline.trim().length > 0 ? this.deadline.trim() : '未指定';
    this.primaryGoal = this.goal.trim();
    this.goalDriftInsight = AiAgentP1Helper.emptyDrift();
    this.lastExecutionReplanKey = '';
    const message = `请制定或重新规划这个目标：${this.goal.trim()}。` +
      `我可用 ${this.availableMinutes} 分钟，截止时间：${deadlineText}。`;
    await this.askAgent(message);
  }

  private async sendFollowUp(): Promise<void> {
    const message = this.followUp.trim();
    if (await this.askAgent(message)) {
      this.followUp = '';
    }
  }

  private async reviewCompletedStep(): Promise<void> {
    const title = this.lastCompletedStepTitle.length > 0 ? this.lastCompletedStepTitle : '刚才的任务';
    const executionKey = this.executionInsight.shouldReplan ?
      this.getExecutionReplanKey(this.executionInsight) : '';
    const message = `我刚完成了“${title}”。请根据最新专注数据复盘完成情况，` +
      `判断后续计划是否需要调整，并告诉我下一轮最应该做什么。`;
    if (await this.askAgent(message) && executionKey.length > 0) {
      this.lastExecutionReplanKey = executionKey;
      await this.refreshAgentAnalysis();
      await this.saveAgentState(false);
    }
  }

  private applyStep(step: AiPlanStep): void {
    if (!this.canApplyStep) {
      this.errorMessage = '请先完成或重置当前一轮计时，再切换任务';
      return;
    }
    if (this.onApplyStep) {
      this.onApplyStep(step, this.conversationId);
    }
    this.successMessage = `已将“${step.title}”设为当前任务`;
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
    if (changed !== undefined && changed.completed) {
      this.lastCompletedStepTitle = changed.title;
      this.lastAutoReviewAttemptTitle = '';
      this.needsReview = true;
    } else {
      this.needsReview = false;
    }
    await this.refreshAgentAnalysis();
    await this.saveAgentState(this.needsReview);
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

  private hasCurrentConversation(): boolean {
    return this.chatMessages.length > 0 || this.planSteps.length > 0;
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
            Text('完成步骤后自动复盘').fontSize(12).fontWeight(FontWeight.Medium)
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
            .onChange((value: string) => this.apiKey = value)
          Row({ space: 8 }) {
            Text('V4 Flash · 日常').layoutWeight(1).height(34).fontSize(11)
              .fontColor(this.deepSeekModel === 'deepseek-v4-flash' ? Color.Black :
                $r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
              .backgroundColor(this.deepSeekModel === 'deepseek-v4-flash' ?
                $r('app.color.primary_green') : $r('app.color.ring_track'))
              .borderRadius(17).onClick(() => this.deepSeekModel = 'deepseek-v4-flash')
            Text('V4 Pro · 复杂规划').layoutWeight(1).height(34).fontSize(11)
              .fontColor(this.deepSeekModel === 'deepseek-v4-pro' ? Color.Black :
                $r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
              .backgroundColor(this.deepSeekModel === 'deepseek-v4-pro' ?
                $r('app.color.primary_green') : $r('app.color.ring_track'))
              .borderRadius(17).onClick(() => this.deepSeekModel = 'deepseek-v4-pro')
          }.width('100%')
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
  private planInsightCard(insight: AiPlanInsight) {
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
      if (insight.status !== 'completed') {
        Row({ space: 8 }) {
          Button(this.canApplyStep ? '执行下一步' : '计时结束后执行')
            .layoutWeight(1).height(36).fontSize(11).enabled(this.canApplyStep)
            .backgroundColor($r('app.color.primary_green')).fontColor(Color.Black).borderRadius(18)
            .onClick(() => this.applyNextStep())
          if (insight.status === 'over_capacity' || insight.status === 'tight') {
            Button(this.isLoading ? '正在重排…' : 'AI 压缩计划')
              .layoutWeight(1).height(36).fontSize(11).enabled(!this.isLoading)
              .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.primary_red'))
              .borderRadius(18).onClick(() => this.requestPlanCompression())
          }
        }.width('100%')
      }
    }
    .width('100%').padding(14).backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: insight.status === 'over_capacity' ?
      $r('app.color.primary_red') : $r('app.color.card_border') }).borderRadius(16)
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
        .borderRadius(12).onChange((value: string) => this.deadline = value)
      Button(this.isLoading ? '智能体正在分析…' : '生成或重排计划')
        .width('100%').height(46).fontSize(14).fontWeight(FontWeight.Bold).enabled(!this.isLoading)
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
    if (this.planSteps.length > 0) {
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
        Button(this.canApplyStep ? '设为当前专注任务' : '当前轮结束后可使用')
          .width('100%').height(36).fontSize(11).enabled(this.canApplyStep)
          .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.primary_green'))
          .borderRadius(18).onClick(() => this.applyStep(step))
      }
    }
    .width('100%').padding(14).backgroundColor($r('app.color.surface'))
    .border({ width: 1, color: step.completed ? $r('app.color.primary_green') : $r('app.color.card_border') })
    .borderRadius(16)
  }

  build() {
    Stack({ alignContent: Alignment.Top }) {
      Column({ space: 12 }) {
        this.pageHeader()
        Scroll() {
          Column({ space: 12 }) {
            this.serviceCard()
            this.contextCard()
            this.agentMemoryCard()
            if (this.shouldShowAgentSuggestion(this.getAgentDecision())) {
              this.agentActionCard(this.getAgentDecision())
            }
            this.inputCard()
            if (this.errorMessage.length > 0) {
              Text(this.errorMessage).width('100%').fontSize(12).fontColor($r('app.color.primary_red'))
                .padding(12).backgroundColor('#24FA2E69').borderRadius(12)
            }
            if (this.successMessage.length > 0) {
              Text(this.successMessage).width('100%').fontSize(12).fontColor($r('app.color.primary_green'))
                .padding(12).backgroundColor('#2065FE08').borderRadius(12)
            }
            this.conversationCard()
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
              this.planInsightCard(this.getPlanInsight())
              ForEach(this.planSteps, (step: AiPlanStep, index: number) => {
                this.planCard(step, index)
              }, (step: AiPlanStep, index: number) => `${index}-${step.title}`)
            }
            this.followUpCard()
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
