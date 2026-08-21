import { http } from '@kit.NetworkKit';
import {
  AiAgentResult,
  AiAgentMemory,
  AiChatMessage,
  AiExecutionInsight,
  AiFocusContext,
  AiGoalDriftInsight,
  AiPlan,
  AiPlanStep,
  AiUsage
} from './AiAgentModels';
import { AiGoalReadinessHelper } from './AiGoalReadinessHelper';

export interface AiPlanResult {
  success: boolean;
  plan: AiPlan;
  errorMessage: string;
}

export interface AiServiceCheckResult {
  success: boolean;
  message: string;
}

interface AiPlanRequest {
  goal: string;
  availableMinutes: number;
  deadline: string;
  workMinutes: number;
  breakMinutes: number;
}

interface AiPlanStepResponse {
  title?: string;
  project?: string;
  tag?: string;
  note?: string;
  estimatedPomodoros?: number | string;
  reason?: string;
  completed?: boolean;
}

interface AiPlanResponse {
  summary?: string;
  steps?: AiPlanStepResponse[];
}

interface AiAgentResponse {
  reply?: string;
  summary?: string;
  steps?: AiPlanStepResponse[];
  plan?: AiPlanResponse;
}

interface DeepSeekMessage {
  role: string;
  content: string;
}

interface DeepSeekResponseFormat {
  type: string;
}

interface DeepSeekThinking {
  type: string;
}

interface DeepSeekRequest {
  model: string;
  messages: DeepSeekMessage[];
  response_format: DeepSeekResponseFormat;
  thinking: DeepSeekThinking;
  max_tokens: number;
  stream: boolean;
}

interface DeepSeekResponseMessage {
  content: string;
}

interface DeepSeekChoice {
  message: DeepSeekResponseMessage;
  finish_reason?: string;
}

interface DeepSeekResponse {
  choices: DeepSeekChoice[];
  usage?: DeepSeekUsage;
}

interface DeepSeekUsage {
  prompt_tokens: number;
  completion_tokens: number;
  total_tokens: number;
}

interface DeepSeekBalanceResponse {
  is_available?: boolean;
}

interface DeepSeekModelInfo {
  id?: string;
}

interface DeepSeekModelsResponse {
  data?: DeepSeekModelInfo[];
}

export class AiPlannerService {
  private static emptyPlan(): AiPlan {
    return { summary: '', steps: [] };
  }

  private static emptyUsage(): AiUsage {
    return { promptTokens: 0, completionTokens: 0, totalTokens: 0 };
  }

  private static agentFailure(message: string): AiAgentResult {
    return {
      success: false,
      reply: '',
      plan: AiPlannerService.emptyPlan(),
      usage: AiPlannerService.emptyUsage(),
      errorMessage: message
    };
  }

  private static failure(message: string): AiPlanResult {
    return { success: false, plan: AiPlannerService.emptyPlan(), errorMessage: message };
  }

  static evaluateDeepSeekService(balanceAvailable: boolean, modelIds: string[],
    selectedModel: string): AiServiceCheckResult {
    if (!balanceAvailable) {
      return { success: false, message: '密钥有效，但账户余额当前不可用于 API 调用' };
    }
    if (modelIds.indexOf(selectedModel) < 0) {
      return { success: false, message: `连接成功，但当前账号未返回所选模型 ${selectedModel}` };
    }
    const modelLabel = selectedModel === 'deepseek-v4-pro' ? 'V4 Pro' : 'V4 Flash';
    return {
      success: true,
      message: `连接成功：密钥有效、余额可用，${modelLabel} 可访问；本次诊断未生成内容`
    };
  }

  static async checkDeepSeekService(apiKey: string, selectedModel: string): Promise<AiServiceCheckResult> {
    const normalizedKey = apiKey.trim();
    if (normalizedKey.length < 10) {
      return { success: false, message: '请先填写有效的 DeepSeek API Key' };
    }
    const client = http.createHttp();
    const headers: Record<string, string> = {
      'Accept': 'application/json',
      'Authorization': `Bearer ${normalizedKey}`
    };
    try {
      const balanceResponse = await client.request('https://api.deepseek.com/user/balance', {
        method: http.RequestMethod.GET,
        header: headers,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 20000
      });
      if (balanceResponse.responseCode === 401 || balanceResponse.responseCode === 403) {
        return { success: false, message: 'DeepSeek API Key 无效或没有访问权限' };
      }
      if (balanceResponse.responseCode === 429) {
        return { success: false, message: 'DeepSeek 当前请求过于频繁，请稍后再试' };
      }
      if (balanceResponse.responseCode < 200 || balanceResponse.responseCode >= 300 ||
        typeof balanceResponse.result !== 'string') {
        return { success: false, message: `DeepSeek 余额检查失败（${balanceResponse.responseCode}）` };
      }
      const balance = JSON.parse(balanceResponse.result) as DeepSeekBalanceResponse;

      const modelsResponse = await client.request('https://api.deepseek.com/models', {
        method: http.RequestMethod.GET,
        header: headers,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 10000,
        readTimeout: 20000
      });
      if (modelsResponse.responseCode === 429) {
        return { success: false, message: 'DeepSeek 当前请求过于频繁，请稍后再试' };
      }
      if (modelsResponse.responseCode < 200 || modelsResponse.responseCode >= 300 ||
        typeof modelsResponse.result !== 'string') {
        return { success: false, message: `DeepSeek 模型检查失败（${modelsResponse.responseCode}）` };
      }
      const models = JSON.parse(modelsResponse.result) as DeepSeekModelsResponse;
      const modelIds: string[] = [];
      if (Array.isArray(models.data)) {
        for (const item of models.data) {
          if (item !== undefined && typeof item.id === 'string') {
            modelIds.push(item.id);
          }
        }
      }
      return AiPlannerService.evaluateDeepSeekService(
        balance.is_available === true, modelIds, selectedModel);
    } catch {
      return { success: false, message: '无法完成 DeepSeek 诊断，请检查网络后重试' };
    } finally {
      client.destroy();
    }
  }

  private static isAllowedEndpoint(endpoint: string): boolean {
    return endpoint.startsWith('https://') ||
      endpoint.startsWith('http://localhost') ||
      endpoint.startsWith('http://127.0.0.1');
  }

  private static extractJsonObject(content: string): string {
    let normalized = content.trim();
    if (normalized.length > 0 && normalized.charCodeAt(0) === 0xFEFF) {
      normalized = normalized.substring(1).trim();
    }
    const firstBrace = normalized.indexOf('{');
    const lastBrace = normalized.lastIndexOf('}');
    if (firstBrace < 0 || lastBrace <= firstBrace) {
      throw new Error('No JSON object found');
    }
    return normalized.substring(firstBrace, lastBrace + 1);
  }

  private static parseEstimate(value: number | string | undefined): number {
    if (typeof value === 'number' && Number.isFinite(value)) {
      return value;
    }
    if (typeof value === 'string') {
      const parsed = Number(value);
      if (Number.isFinite(parsed)) {
        return parsed;
      }
    }
    return 1;
  }

  private static buildPlanningPrompt(goal: string, availableMinutes: number, deadline: string,
    workMinutes: number, breakMinutes: number): string {
    return `请为下面的目标制定番茄工作计划，并且只输出 JSON。\n` +
      `用户目标：${goal}\n` +
      `可用时间：${availableMinutes} 分钟\n` +
      `截止时间：${deadline.length > 0 ? deadline : '未指定'}\n` +
      `番茄节奏：专注 ${workMinutes} 分钟，休息 ${breakMinutes} 分钟\n` +
      `请输出以下 JSON 结构，不要使用 Markdown：\n` +
      `{"summary":"计划思路和必要取舍","steps":[` +
      `{"title":"具体且可验证的动作","project":"项目名称","tag":"标签",` +
      `"note":"可检查的完成标准","estimatedPomodoros":1,"reason":"安排原因"}]}\n` +
      `要求：步骤按执行顺序排列，最多 12 步；每步预计 1 到 4 个番茄；` +
      `标题必须包含具体动作和对象，note 必须说明完成后能检查到什么；` +
      `禁止使用“研究一下、了解一下、完善内容、继续学习、推进任务”等空泛步骤；` +
      `最后一步必须包含检查、提交、导出、保存或交付动作；` +
      `不要把休息列为任务。若时间不足，优先给出最小可交付成果并在 summary 中说明。`;
  }

  private static normalizePlan(response: AiPlanResponse): AiPlanResult {
    if (typeof response.summary !== 'string' || !Array.isArray(response.steps) || response.steps.length === 0) {
      return AiPlannerService.failure('AI 服务返回的数据格式不正确');
    }

    const summary = response.summary;
    const responseSteps = response.steps;
    const normalizedSteps: AiPlanStep[] = [];
    const maxSteps = Math.min(responseSteps.length, 12);
    for (let index = 0; index < maxSteps; index++) {
      const step = responseSteps[index];
      if (step === undefined || typeof step.title !== 'string' || step.title.trim().length === 0) {
        continue;
      }
      const estimate = AiPlannerService.parseEstimate(step.estimatedPomodoros);
      normalizedSteps.push({
        title: step.title.trim(),
        project: typeof step.project === 'string' ? step.project.trim() : '',
        tag: typeof step.tag === 'string' ? step.tag.trim() : '',
        note: typeof step.note === 'string' ? step.note.trim() : '',
        estimatedPomodoros: Math.max(1, Math.min(12, Math.round(estimate))),
        reason: typeof step.reason === 'string' ? step.reason.trim() : '',
        completed: false
      });
    }

    if (normalizedSteps.length === 0) {
      return AiPlannerService.failure('AI 没有返回可执行的计划步骤');
    }
    return {
      success: true,
      plan: { summary: summary.trim(), steps: normalizedSteps },
      errorMessage: ''
    };
  }

  private static normalizeAgentPlan(response: AiAgentResponse, previousPlan: AiPlan): AiPlanResult {
    const responsePlan: AiPlanResponse = response.plan === undefined ?
      { summary: response.summary, steps: response.steps } : response.plan;
    const normalized = AiPlannerService.normalizePlan(responsePlan);
    if (!normalized.success) {
      return normalized;
    }
    const steps: AiPlanStep[] = [];
    for (const step of normalized.plan.steps) {
      let completed = false;
      for (const previous of previousPlan.steps) {
        if (previous.completed && previous.title === step.title && previous.project === step.project) {
          completed = true;
          break;
        }
      }
      steps.push({
        title: step.title,
        project: step.project,
        tag: step.tag,
        note: step.note,
        estimatedPomodoros: step.estimatedPomodoros,
        reason: step.reason,
        completed: completed
      });
    }
    return {
      success: true,
      plan: { summary: normalized.plan.summary, steps: steps },
      errorMessage: ''
    };
  }

  private static buildAgentSystemPrompt(context: AiFocusContext, currentPlan: AiPlan,
    memory: AiAgentMemory, goalDrift: AiGoalDriftInsight,
    execution: AiExecutionInsight): string {
    return `你是番茄钟 App 内的个人执行智能体。你必须结合用户真实专注数据持续调整计划。\n` +
      `你每次只能输出 JSON，不要输出 Markdown。JSON 格式为：\n` +
      `{"reply":"给用户的简短中文回复","summary":"当前计划思路",` +
      `"steps":[{"title":"具体动作","project":"项目","tag":"标签",` +
      `"note":"完成标准","estimatedPomodoros":1,"reason":"安排原因","completed":false}]}\n` +
      `必须返回完整的当前计划，而不是只返回变更部分。最多 12 步，每步 1 到 4 个番茄。` +
      `标题必须包含具体动作和对象，note 必须是可检查的完成标准。` +
      `禁止“研究一下、完善内容、继续学习、推进任务”等空泛步骤，最后一步必须形成明确交付。` +
      `保留已经完成且仍相关的步骤；用户要求调整时应重新估算。不要把休息列为任务。\n` +
      `长期与短期记忆：${JSON.stringify(memory)}\n` +
      `目标偏移判断：${JSON.stringify(goalDrift)}\n` +
      `执行偏差判断：${JSON.stringify(execution)}\n` +
      `记忆中的 primaryGoal 是当前主目标。若目标偏移状态为 possible 或 changed，` +
      `不要静默替换主目标；优先保留主目标，只吸收与其一致的调整，并在 reply 中提醒用户。` +
      `若执行偏差要求重排，必须根据真实耗时校准未完成步骤的估时、顺序和缓冲，已完成步骤不得改回未完成。\n` +
      `真实专注上下文：${JSON.stringify(context)}\n` +
      `当前计划：${JSON.stringify(currentPlan)}`;
  }

  static async createPlan(endpoint: string, goal: string, availableMinutes: number,
    deadline: string, workMinutes: number, breakMinutes: number): Promise<AiPlanResult> {
    const normalizedEndpoint = endpoint.trim();
    const normalizedGoal = goal.trim();
    const readiness = AiGoalReadinessHelper.evaluate(normalizedGoal);
    if (!readiness.ready) {
      return AiPlannerService.failure(readiness.question);
    }
    if (!AiPlannerService.isAllowedEndpoint(normalizedEndpoint)) {
      return AiPlannerService.failure('请填写 HTTPS 服务地址；本机调试可使用 localhost 或 127.0.0.1');
    }

    const requestBody: AiPlanRequest = {
      goal: normalizedGoal,
      availableMinutes: Math.max(workMinutes, Math.min(1440, Math.round(availableMinutes))),
      deadline: deadline.trim(),
      workMinutes: Math.max(5, Math.min(120, Math.round(workMinutes))),
      breakMinutes: Math.max(1, Math.min(60, Math.round(breakMinutes)))
    };
    const client = http.createHttp();
    try {
      const response = await client.request(normalizedEndpoint, {
        method: http.RequestMethod.POST,
        header: { 'Content-Type': 'application/json' },
        extraData: JSON.stringify(requestBody),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 60000
      });
      if (response.responseCode < 200 || response.responseCode >= 300) {
        return AiPlannerService.failure(`AI 服务暂时不可用（${response.responseCode}）`);
      }
      if (typeof response.result !== 'string' || response.result.length === 0) {
        return AiPlannerService.failure('AI 服务没有返回内容');
      }
      try {
        return AiPlannerService.normalizePlan(JSON.parse(response.result) as AiPlanResponse);
      } catch {
        return AiPlannerService.failure('AI 服务返回的数据无法解析');
      }
    } catch {
      return AiPlannerService.failure('无法连接 AI 服务，请检查地址和网络');
    } finally {
      client.destroy();
    }
  }

  static async createDeepSeekPlan(apiKey: string, model: string, goal: string, availableMinutes: number,
    deadline: string, workMinutes: number, breakMinutes: number): Promise<AiPlanResult> {
    const normalizedKey = apiKey.trim();
    const normalizedGoal = goal.trim();
    if (normalizedKey.length < 10) {
      return AiPlannerService.failure('请填写有效的 DeepSeek API Key');
    }
    const readiness = AiGoalReadinessHelper.evaluate(normalizedGoal);
    if (!readiness.ready) {
      return AiPlannerService.failure(readiness.question);
    }
    const selectedModel = model === 'deepseek-v4-pro' ? 'deepseek-v4-pro' : 'deepseek-v4-flash';
    const normalizedAvailableMinutes = Math.max(workMinutes, Math.min(1440, Math.round(availableMinutes)));
    const normalizedWorkMinutes = Math.max(5, Math.min(120, Math.round(workMinutes)));
    const normalizedBreakMinutes = Math.max(1, Math.min(60, Math.round(breakMinutes)));
    const requestBody: DeepSeekRequest = {
      model: selectedModel,
      messages: [
        {
          role: 'system',
          content: '你是严谨、务实的中文计划助手，擅长把模糊目标拆成可以立即执行的番茄任务。'
        },
        {
          role: 'user',
          content: AiPlannerService.buildPlanningPrompt(normalizedGoal, normalizedAvailableMinutes,
            deadline.trim(), normalizedWorkMinutes, normalizedBreakMinutes)
        }
      ],
      response_format: { type: 'json_object' },
      thinking: { type: selectedModel === 'deepseek-v4-pro' ? 'enabled' : 'disabled' },
      max_tokens: selectedModel === 'deepseek-v4-pro' ? 8192 : 4096,
      stream: false
    };

    const client = http.createHttp();
    try {
      const response = await client.request('https://api.deepseek.com/chat/completions', {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${normalizedKey}`
        },
        extraData: JSON.stringify(requestBody),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 90000
      });
      if (response.responseCode === 401 || response.responseCode === 403) {
        return AiPlannerService.failure('DeepSeek API Key 无效或没有访问权限');
      }
      if (response.responseCode === 402) {
        return AiPlannerService.failure('DeepSeek 账户余额不足，请先充值');
      }
      if (response.responseCode === 429) {
        return AiPlannerService.failure('DeepSeek 请求过于频繁，请稍后再试');
      }
      if (response.responseCode < 200 || response.responseCode >= 300) {
        return AiPlannerService.failure(`DeepSeek 服务暂时不可用（${response.responseCode}）`);
      }
      if (typeof response.result !== 'string' || response.result.length === 0) {
        return AiPlannerService.failure('DeepSeek 没有返回内容');
      }
      try {
        const deepSeekResponse = JSON.parse(response.result) as DeepSeekResponse;
        if (!Array.isArray(deepSeekResponse.choices) || deepSeekResponse.choices.length === 0 ||
          deepSeekResponse.choices[0] === undefined || deepSeekResponse.choices[0].message === undefined ||
          typeof deepSeekResponse.choices[0].message.content !== 'string' ||
          deepSeekResponse.choices[0].message.content.length === 0) {
          return AiPlannerService.failure('DeepSeek 返回了空计划，请重新生成');
        }
        if (deepSeekResponse.choices[0].finish_reason === 'length') {
          return AiPlannerService.failure('DeepSeek 输出过长而被截断，请缩小目标或改用 V4 Flash');
        }
        const jsonContent = AiPlannerService.extractJsonObject(deepSeekResponse.choices[0].message.content);
        const plan = JSON.parse(jsonContent) as AiPlanResponse;
        return AiPlannerService.normalizePlan(plan);
      } catch {
        return AiPlannerService.failure('DeepSeek 返回的计划格式不正确，请重新生成');
      }
    } catch {
      return AiPlannerService.failure('无法连接 DeepSeek，请检查网络后重试');
    } finally {
      client.destroy();
    }
  }

  static async continueDeepSeekAgent(apiKey: string, model: string, userMessage: string,
    history: AiChatMessage[], currentPlan: AiPlan, context: AiFocusContext,
    memory: AiAgentMemory, goalDrift: AiGoalDriftInsight,
    execution: AiExecutionInsight): Promise<AiAgentResult> {
    const normalizedKey = apiKey.trim();
    const normalizedMessage = userMessage.trim();
    if (normalizedKey.length < 10) {
      return AiPlannerService.agentFailure('请填写有效的 DeepSeek API Key');
    }
    if (normalizedMessage.length < 2) {
      return AiPlannerService.agentFailure('请告诉 AI 你想规划或调整什么');
    }
    const selectedModel = model === 'deepseek-v4-pro' ? 'deepseek-v4-pro' : 'deepseek-v4-flash';
    const messages: DeepSeekMessage[] = [{
      role: 'system',
      content: AiPlannerService.buildAgentSystemPrompt(context, currentPlan, memory, goalDrift, execution)
    }];
    const startIndex = Math.max(0, history.length - 16);
    for (let index = startIndex; index < history.length; index++) {
      const item = history[index];
      if (item !== undefined && (item.role === 'user' || item.role === 'assistant') && item.content.length > 0) {
        messages.push({ role: item.role, content: item.content });
      }
    }
    messages.push({ role: 'user', content: normalizedMessage });
    const requestBody: DeepSeekRequest = {
      model: selectedModel,
      messages: messages,
      response_format: { type: 'json_object' },
      thinking: { type: selectedModel === 'deepseek-v4-pro' ? 'enabled' : 'disabled' },
      max_tokens: selectedModel === 'deepseek-v4-pro' ? 8192 : 4096,
      stream: false
    };

    const client = http.createHttp();
    try {
      const response = await client.request('https://api.deepseek.com/chat/completions', {
        method: http.RequestMethod.POST,
        header: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${normalizedKey}`
        },
        extraData: JSON.stringify(requestBody),
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: 15000,
        readTimeout: 90000
      });
      if (response.responseCode === 401 || response.responseCode === 403) {
        return AiPlannerService.agentFailure('DeepSeek API Key 无效或没有访问权限');
      }
      if (response.responseCode === 402) {
        return AiPlannerService.agentFailure('DeepSeek 账户余额不足，请先充值');
      }
      if (response.responseCode === 429) {
        return AiPlannerService.agentFailure('DeepSeek 请求过于频繁，请稍后再试');
      }
      if (response.responseCode < 200 || response.responseCode >= 300) {
        return AiPlannerService.agentFailure(`DeepSeek 服务暂时不可用（${response.responseCode}）`);
      }
      if (typeof response.result !== 'string' || response.result.length === 0) {
        return AiPlannerService.agentFailure('DeepSeek 没有返回内容');
      }
      try {
        const deepSeekResponse = JSON.parse(response.result) as DeepSeekResponse;
        if (!Array.isArray(deepSeekResponse.choices) || deepSeekResponse.choices.length === 0 ||
          deepSeekResponse.choices[0] === undefined || deepSeekResponse.choices[0].message === undefined ||
          typeof deepSeekResponse.choices[0].message.content !== 'string' ||
          deepSeekResponse.choices[0].message.content.length === 0) {
          return AiPlannerService.agentFailure('DeepSeek 返回了空内容，请重新发送');
        }
        if (deepSeekResponse.choices[0].finish_reason === 'length') {
          return AiPlannerService.agentFailure('DeepSeek 输出过长而被截断，请缩小目标或改用 V4 Flash');
        }
        const jsonContent = AiPlannerService.extractJsonObject(deepSeekResponse.choices[0].message.content);
        const parsed = JSON.parse(jsonContent) as AiAgentResponse;
        const fallbackSummary = parsed.plan === undefined ? parsed.summary : parsed.plan.summary;
        const reply = typeof parsed.reply === 'string' && parsed.reply.trim().length > 0 ?
          parsed.reply.trim() : (typeof fallbackSummary === 'string' ? fallbackSummary.trim() : '');
        if (reply.length === 0) {
          return AiPlannerService.agentFailure('DeepSeek 回复格式不正确，请重新发送');
        }
        const normalizedPlan = AiPlannerService.normalizeAgentPlan(parsed, currentPlan);
        if (!normalizedPlan.success) {
          return AiPlannerService.agentFailure(normalizedPlan.errorMessage);
        }
        const usage: AiUsage = deepSeekResponse.usage === undefined ? AiPlannerService.emptyUsage() : {
          promptTokens: deepSeekResponse.usage.prompt_tokens,
          completionTokens: deepSeekResponse.usage.completion_tokens,
          totalTokens: deepSeekResponse.usage.total_tokens
        };
        return {
          success: true,
          reply: reply,
          plan: normalizedPlan.plan,
          usage: usage,
          errorMessage: ''
        };
      } catch {
        return AiPlannerService.agentFailure('DeepSeek 返回的数据格式不正确，请重新发送');
      }
    } catch {
      return AiPlannerService.agentFailure('无法连接 DeepSeek，请检查网络后重试');
    } finally {
      client.destroy();
    }
  }
}
