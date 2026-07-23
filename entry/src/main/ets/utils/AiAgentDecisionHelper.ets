import {
  AiAgentDecision,
  AiExecutionInsight,
  AiGoalDriftInsight,
  AiPlanInsight
} from './AiAgentModels';

export class AiAgentDecisionHelper {
  private static decision(stage: string, stageLabel: string, title: string, description: string,
    action: string, actionLabel: string, usesAi: boolean, reason: string,
    expectedOutcome: string): AiAgentDecision {
    return {
      stage: stage,
      stageLabel: stageLabel,
      title: title,
      description: description,
      action: action,
      actionLabel: actionLabel,
      usesAi: usesAi,
      reason: reason,
      expectedOutcome: expectedOutcome
    };
  }

  static decide(insight: AiPlanInsight, hasPlan: boolean, needsReview: boolean, hasError: boolean,
    canRetry: boolean, serviceReady: boolean, canApplyStep: boolean, isLoading: boolean,
    goalDrift?: AiGoalDriftInsight, execution?: AiExecutionInsight): AiAgentDecision {
    if (isLoading) {
      return AiAgentDecisionHelper.decision(
        'thinking', '分析中', '智能体正在分析', '正在结合目标、记忆、计划和真实专注记录计算下一步。',
        'none', '', true, '已有一项 AI 行动正在执行。', '完成后会自动刷新计划与建议。');
    }
    if (hasError) {
      if (canRetry) {
        return AiAgentDecisionHelper.decision(
          'blocked', '待恢复', '上次行动没有完成', '请求内容已经保留，可以修复网络或服务问题后原样重试。',
          'retry', '重试上次行动', true, '上次请求失败，但输入与上下文仍然完整。',
          '继续执行原请求，不需要重新输入。');
      }
      if (!serviceReady) {
        return AiAgentDecisionHelper.decision(
          'blocked', '待配置', '智能体需要有效的服务配置', '完成 API Key 或代理地址配置后即可继续。',
          'configure', '检查 AI 配置', false, '当前没有可用的 AI 服务连接。',
          '配置完成后即可生成、复盘和重排计划。');
      }
      return AiAgentDecisionHelper.decision(
        'blocked', '待处理', '请先修正当前问题', '根据页面中的错误提示修改输入，然后重新执行。',
        'none', '', false, '当前输入或返回内容未通过校验。', '修正后智能体可以继续工作。');
    }
    if (!hasPlan) {
      if (!serviceReady) {
        return AiAgentDecisionHelper.decision(
          'blocked', '待配置', '先连接 AI 服务', '配置 DeepSeek API Key 或安全代理地址后，智能体才能生成计划。',
          'configure', '配置 AI 服务', false, '尚未配置可用的模型服务。', '完成配置后可根据目标生成计划。');
      }
      return AiAgentDecisionHelper.decision(
        'planning', '规划', '先明确目标并生成执行计划', '填写目标、可用时间和截止条件，智能体会生成可执行步骤。',
        'generate', '生成执行计划', true, '当前还没有可执行计划。', '获得按优先级排列的番茄钟步骤。');
    }
    if (goalDrift !== undefined && (goalDrift.status === 'possible' || goalDrift.status === 'changed')) {
      if (!serviceReady) {
        return AiAgentDecisionHelper.decision(
          'blocked', '目标待确认', goalDrift.title, goalDrift.description,
          'configure', '配置 AI 后校准', false, '新指令与当前主目标的关联较弱。',
          '连接 AI 后可在保留主目标的前提下重新校准计划。');
      }
      return AiAgentDecisionHelper.decision(
        'replanning', '目标校准', goalDrift.title, goalDrift.description,
        'align_goal', '按主目标校准', true, '新指令可能改变正在执行的主目标。',
        '保留主目标，只吸收与目标一致的调整。');
    }
    if (execution !== undefined && execution.shouldReplan) {
      if (!serviceReady) {
        return AiAgentDecisionHelper.decision(
          'blocked', '偏差待处理', execution.title, execution.description,
          'configure', '配置 AI 后重排', false, '真实计时与步骤估时偏差超过 25%。',
          '连接 AI 后可按真实执行速度重新分配剩余时间。');
      }
      return AiAgentDecisionHelper.decision(
        'replanning', '执行校准', execution.title, execution.description,
        'replan_variance', '按实际速度重排', true, '真实计时与步骤估时偏差超过 25%。',
        '更新剩余步骤的估时、顺序和缓冲，不改动已完成内容。');
    }
    if (needsReview) {
      if (!serviceReady) {
        return AiAgentDecisionHelper.decision(
          'blocked', '待配置', '连接 AI 后复盘最新结果', '当前计划仍可离线查看；复盘和重排需要先配置 AI 服务。',
          'configure', '配置 AI 服务', false, '刚完成了一个计划步骤，需要结合最新结果校准。',
          '连接 AI 后可获得复盘结论和后续调整。');
      }
      return AiAgentDecisionHelper.decision(
        'reviewing', '复盘', '用最新结果校准后续计划', '检测到步骤已经完成，建议先读取最新专注数据再继续。',
        'review', '复盘并调整计划', true, '刚完成了一个计划步骤，已有新的执行数据。',
        '总结本步结果，并在必要时调整未完成步骤。');
    }
    if (insight.status === 'completed') {
      if (!serviceReady) {
        return AiAgentDecisionHelper.decision(
          'completed', '已完成', '计划已全部完成', '连接 AI 服务后可以总结成果并规划下一阶段。',
          'configure', '配置 AI 并复盘', false, '所有计划步骤均已完成。', '生成本轮总结与下一阶段建议。');
      }
      return AiAgentDecisionHelper.decision(
        'completed', '已完成', '计划已全部完成', '让智能体总结成果、偏差和下一阶段建议。',
        'review', '复盘本次成果', true, '所有计划步骤均已完成。', '形成可复用经验并决定是否开启新计划。');
    }
    if (insight.status === 'over_capacity') {
      if (!serviceReady) {
        return AiAgentDecisionHelper.decision(
          'replanning', '需重排', '计划超出时间容量', '当前计划可离线执行；连接 AI 后可以自动压缩和重排。',
          'configure', '配置 AI 并重排', false, '剩余步骤所需时间超过可用时间。', '连接 AI 后压缩低优先级内容。');
      }
      return AiAgentDecisionHelper.decision(
        'replanning', '需重排', '当前计划超过可用时间', insight.description,
        'compress', '压缩并重排计划', true, '剩余步骤所需时间超过可用时间。',
        '保留关键产出，并将计划压缩到可用时间内。');
    }
    if (!canApplyStep) {
      return AiAgentDecisionHelper.decision(
        'executing', '执行中', '先完成当前计时阶段', '计时结束或重置后，智能体会继续推荐下一项任务。',
        'wait', '等待当前计时结束', false, '当前已有任务正在计时。', '计时结束后开放下一步执行入口。');
    }
    return AiAgentDecisionHelper.decision(
      'ready', '可执行', '下一步已经准备好', insight.description,
      'apply_next', '执行推荐的下一步', false, '计划中仍有未完成步骤。', '把下一步任务带入计时器开始执行。');
  }
}
