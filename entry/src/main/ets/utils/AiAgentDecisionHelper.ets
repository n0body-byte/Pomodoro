import { AiAgentDecision, AiPlanInsight } from './AiAgentModels';

export class AiAgentDecisionHelper {
  private static decision(stage: string, stageLabel: string, title: string, description: string,
    action: string, actionLabel: string, usesAi: boolean): AiAgentDecision {
    return {
      stage: stage,
      stageLabel: stageLabel,
      title: title,
      description: description,
      action: action,
      actionLabel: actionLabel,
      usesAi: usesAi
    };
  }

  static decide(insight: AiPlanInsight, hasPlan: boolean, needsReview: boolean, hasError: boolean,
    canRetry: boolean, serviceReady: boolean, canApplyStep: boolean, isLoading: boolean): AiAgentDecision {
    if (isLoading) {
      return AiAgentDecisionHelper.decision(
        'thinking', '分析中', '智能体正在分析', '正在结合目标、计划和真实专注记录计算下一步。',
        'none', '', true);
    }
    if (hasError) {
      if (canRetry) {
        return AiAgentDecisionHelper.decision(
          'blocked', '待恢复', '上次行动没有完成', '请求内容已经保留，可以修复网络或服务问题后原样重试。',
          'retry', '重试上次行动', true);
      }
      if (!serviceReady) {
        return AiAgentDecisionHelper.decision(
          'blocked', '待配置', '智能体需要有效的服务配置', '完成 API Key 或代理地址配置后即可继续。',
          'configure', '检查 AI 配置', false);
      }
      return AiAgentDecisionHelper.decision(
        'blocked', '待处理', '请先修正当前问题', '根据页面中的错误提示修改输入，然后重新执行。',
        'none', '', false);
    }
    if (!hasPlan) {
      if (!serviceReady) {
        return AiAgentDecisionHelper.decision(
          'blocked', '待配置', '先连接 AI 服务', '配置 DeepSeek API Key 或安全代理地址后，智能体才能生成计划。',
          'configure', '配置 AI 服务', false);
      }
      return AiAgentDecisionHelper.decision(
        'planning', '规划', '先明确目标并生成执行计划', '填写目标、可用时间和截止条件，智能体会生成可执行步骤。',
        'generate', '生成执行计划', true);
    }
    if (needsReview) {
      if (!serviceReady) {
        return AiAgentDecisionHelper.decision(
          'blocked', '待配置', '连接 AI 后复盘最新结果', '当前计划仍可离线查看；复盘和重排需要先配置 AI 服务。',
          'configure', '配置 AI 服务', false);
      }
      return AiAgentDecisionHelper.decision(
        'reviewing', '复盘', '用最新结果校准后续计划', '检测到步骤已经完成，建议先读取最新专注数据再继续。',
        'review', '复盘并调整计划', true);
    }
    if (insight.status === 'completed') {
      if (!serviceReady) {
        return AiAgentDecisionHelper.decision(
          'completed', '已完成', '计划已全部完成', '连接 AI 服务后可以总结成果并规划下一阶段。',
          'configure', '配置 AI 并复盘', false);
      }
      return AiAgentDecisionHelper.decision(
        'completed', '已完成', '计划已全部完成', '让智能体总结成果、偏差和下一阶段建议。',
        'review', '复盘本次成果', true);
    }
    if (insight.status === 'over_capacity') {
      if (!serviceReady) {
        return AiAgentDecisionHelper.decision(
          'replanning', '需重排', '计划超出时间容量', '当前计划可离线执行；连接 AI 后可以自动压缩和重排。',
          'configure', '配置 AI 并重排', false);
      }
      return AiAgentDecisionHelper.decision(
        'replanning', '需重排', '当前计划超过可用时间', insight.description,
        'compress', '压缩并重排计划', true);
    }
    if (!canApplyStep) {
      return AiAgentDecisionHelper.decision(
        'executing', '执行中', '先完成当前计时阶段', '计时结束或重置后，智能体会继续推荐下一项任务。',
        'wait', '等待当前计时结束', false);
    }
    return AiAgentDecisionHelper.decision(
      'ready', '可执行', '下一步已经准备好', insight.description,
      'apply_next', '执行推荐的下一步', false);
  }
}
