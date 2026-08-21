export const DEFAULT_AI_TOKEN_BUDGET = 30000;

export interface AiTokenBudgetInsight {
  budget: number;
  consumed: number;
  remaining: number;
  percent: number;
  status: string;
  canRequest: boolean;
  title: string;
  description: string;
}

export class AiTokenBudgetHelper {
  static normalizeBudget(value: number): number {
    if (!Number.isFinite(value)) {
      return DEFAULT_AI_TOKEN_BUDGET;
    }
    return Math.max(10000, Math.min(100000, Math.round(value)));
  }

  static addUsage(consumed: number, used: number): number {
    const safeConsumed = Number.isFinite(consumed) ? Math.max(0, Math.round(consumed)) : 0;
    const safeUsed = Number.isFinite(used) ? Math.max(0, Math.round(used)) : 0;
    return safeConsumed + safeUsed;
  }

  static evaluate(tokenBudget: number, consumedTokens: number): AiTokenBudgetInsight {
    const budget = AiTokenBudgetHelper.normalizeBudget(tokenBudget);
    const consumed = Number.isFinite(consumedTokens) ? Math.max(0, Math.round(consumedTokens)) : 0;
    const remaining = Math.max(0, budget - consumed);
    const percent = Math.min(100, Math.round(consumed * 100 / budget));
    if (consumed >= budget) {
      return {
        budget: budget, consumed: consumed, remaining: 0, percent: 100,
        status: 'exhausted', canRequest: false, title: '本对话 Token 预算已用完',
        description: '已停止新的 DeepSeek 调用；可提高预算或新建对话。'
      };
    }
    if (percent >= 80) {
      return {
        budget: budget, consumed: consumed, remaining: remaining, percent: percent,
        status: 'warning', canRequest: true, title: 'Token 预算即将用完',
        description: `本对话还可使用约 ${remaining} tokens，下一次调用可能超过剩余额度。`
      };
    }
    return {
      budget: budget, consumed: consumed, remaining: remaining, percent: percent,
      status: 'healthy', canRequest: true, title: 'Token 预算正常',
      description: `本对话还可使用约 ${remaining} tokens。`
    };
  }
}
