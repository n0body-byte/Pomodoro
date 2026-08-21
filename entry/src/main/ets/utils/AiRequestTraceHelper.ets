import { AiAgentResult, AiRequestTrace } from './AiAgentModels';

const MAX_REQUEST_TRACES = 20;

export class AiRequestTraceHelper {
  static create(action: string, model: string, startedAt: number, finishedAt: number,
    result: AiAgentResult, status: string, statusDetail: string): AiRequestTrace {
    const safeFinishedAt = Math.max(startedAt, finishedAt);
    return {
      id: `request-${startedAt}-${safeFinishedAt}-${status}-${action}`,
      action: action.substring(0, 24),
      provider: 'DeepSeek',
      model: model.substring(0, 40),
      startedAt: startedAt,
      durationMs: safeFinishedAt - startedAt,
      status: status,
      statusDetail: statusDetail.substring(0, 80),
      promptTokens: Math.max(0, Math.round(result.usage.promptTokens)),
      completionTokens: Math.max(0, Math.round(result.usage.completionTokens)),
      totalTokens: Math.max(0, Math.round(result.usage.totalTokens))
    };
  }

  static append(existing: AiRequestTrace[], trace: AiRequestTrace): AiRequestTrace[] {
    const result: AiRequestTrace[] = [trace];
    for (const item of existing) {
      if (item.id !== trace.id && result.length < MAX_REQUEST_TRACES) {
        result.push(item);
      }
    }
    return result;
  }

  static statusLabel(status: string): string {
    if (status === 'accepted') {
      return '已采用';
    }
    if (status === 'quality_rejected') {
      return '质检拦截';
    }
    if (status === 'repaired') {
      return '修复后采用';
    }
    return '调用失败';
  }

  static provesRemoteResponse(trace: AiRequestTrace): boolean {
    return trace.totalTokens > 0 || trace.status === 'accepted' ||
      trace.status === 'quality_rejected' || trace.status === 'repaired' ||
      (trace.status === 'failed' && trace.statusDetail.indexOf('无法连接 DeepSeek') < 0);
  }
}
