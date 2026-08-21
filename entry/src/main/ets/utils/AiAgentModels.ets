export interface AiPlanStep {
  title: string;
  project: string;
  tag: string;
  note: string;
  estimatedPomodoros: number;
  reason: string;
  completed: boolean;
}

export interface AiPlan {
  summary: string;
  steps: AiPlanStep[];
}

export interface AiChatMessage {
  role: string;
  content: string;
  createdAt: number;
}

export interface AiAgentState {
  id: string;
  title: string;
  createdAt: number;
  messages: AiChatMessage[];
  plan: AiPlan;
  updatedAt: number;
  needsReview: boolean;
  lastCompletedStepTitle: string;
  availableMinutes?: number;
  deadline?: string;
  primaryGoal?: string;
  memory?: AiAgentMemory;
  goalDrift?: AiGoalDriftInsight;
  lastAutoReviewAttemptTitle?: string;
  lastExecutionReplanKey?: string;
  planSource?: string;
}

export interface AiConversationSummary {
  id: string;
  title: string;
  createdAt: number;
  updatedAt: number;
  messageCount: number;
  stepCount: number;
  completedStepCount?: number;
}

export interface AiFocusContext {
  todayWorkSeconds: number;
  todayBreakSeconds: number;
  todayCompletedSessions: number;
  dailyTarget: number;
  sevenDayWorkSeconds: number;
  sevenDayCompletedSessions: number;
  sevenDayAbandonedSessions: number;
  currentTask: string;
  currentProject: string;
  currentTaskCompleted: number;
  workMinutes: number;
  breakMinutes: number;
  recentSessionsSummary: string;
  availableMinutes: number;
  deadline: string;
  planRequiredMinutes: number;
  planBufferMinutes: number;
  planProgressPercent: number;
  planRiskStatus: string;
}

export interface AiPlanInsight {
  totalPomodoros: number;
  completedPomodoros: number;
  remainingPomodoros: number;
  progressPercent: number;
  requiredMinutes: number;
  bufferMinutes: number;
  feasibilityPercent: number;
  status: string;
  title: string;
  description: string;
  nextStepIndex: number;
}

export interface AiAgentMemory {
  primaryGoal: string;
  longTermSummary: string;
  shortTermSummary: string;
  updatedAt: number;
}

export interface AiGoalDriftInsight {
  status: string;
  title: string;
  description: string;
  similarityPercent: number;
}

export interface AiExecutionInsight {
  status: string;
  title: string;
  description: string;
  expectedMinutes: number;
  actualMinutes: number;
  varianceMinutes: number;
  variancePercent: number;
  matchedSessions: number;
  shouldReplan: boolean;
}

export interface AiUsage {
  promptTokens: number;
  completionTokens: number;
  totalTokens: number;
}

export interface AiAgentResult {
  success: boolean;
  reply: string;
  plan: AiPlan;
  usage: AiUsage;
  errorMessage: string;
}

export interface AiAgentDecision {
  stage: string;
  stageLabel: string;
  title: string;
  description: string;
  action: string;
  actionLabel: string;
  usesAi: boolean;
  reason: string;
  expectedOutcome: string;
}
