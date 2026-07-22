import http from 'node:http';

const host = process.env.HOST ?? '127.0.0.1';
const port = Number(process.env.PORT ?? 8787);
const apiKey = process.env.OPENAI_API_KEY ?? '';
const model = process.env.OPENAI_MODEL ?? 'gpt-5.6-terra';
const maxBodyBytes = 32 * 1024;

function sendJson(response, statusCode, body) {
  response.writeHead(statusCode, {
    'Content-Type': 'application/json; charset=utf-8',
    'Cache-Control': 'no-store'
  });
  response.end(JSON.stringify(body));
}

async function readJson(request) {
  let body = '';
  for await (const chunk of request) {
    body += chunk;
    if (Buffer.byteLength(body) > maxBodyBytes) {
      throw new Error('BODY_TOO_LARGE');
    }
  }
  return JSON.parse(body);
}

function getOutputText(responseBody) {
  for (const item of responseBody.output ?? []) {
    if (item.type !== 'message') continue;
    for (const content of item.content ?? []) {
      if (content.type === 'output_text' && typeof content.text === 'string') {
        return content.text;
      }
    }
  }
  return '';
}

function normalizeRequest(body) {
  const goal = typeof body.goal === 'string' ? body.goal.trim() : '';
  if (goal.length < 4 || goal.length > 2000) {
    throw new Error('INVALID_GOAL');
  }
  return {
    goal,
    availableMinutes: Math.max(5, Math.min(1440, Number(body.availableMinutes) || 120)),
    deadline: typeof body.deadline === 'string' ? body.deadline.slice(0, 120) : '',
    workMinutes: Math.max(5, Math.min(120, Number(body.workMinutes) || 25)),
    breakMinutes: Math.max(1, Math.min(60, Number(body.breakMinutes) || 5))
  };
}

async function createPlan(input) {
  const prompt = [
    `用户目标：${input.goal}`,
    `可用时间：${input.availableMinutes} 分钟`,
    `截止时间：${input.deadline || '未指定'}`,
    `当前番茄节奏：专注 ${input.workMinutes} 分钟，休息 ${input.breakMinutes} 分钟`,
    '请根据时间约束给出从现在就能开始的计划。任务标题必须具体、可验证；不要把休息列为任务。',
    'estimatedPomodoros 表示完成该步骤预计需要的专注轮数。若目标超出可用时间，优先给出最小可交付成果并在 summary 中说明取舍。'
  ].join('\n');

  const openAiResponse = await fetch('https://api.openai.com/v1/responses', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${apiKey}`,
      'Content-Type': 'application/json'
    },
    body: JSON.stringify({
      model,
      reasoning: { effort: 'low' },
      instructions: '你是严谨、务实的中文计划助手，擅长把目标拆成适合番茄工作法的连续行动。只提供与用户目标直接相关的步骤。',
      input: prompt,
      text: {
        format: {
          type: 'json_schema',
          name: 'pomodoro_plan',
          strict: true,
          schema: {
            type: 'object',
            additionalProperties: false,
            properties: {
              summary: { type: 'string' },
              steps: {
                type: 'array',
                minItems: 1,
                maxItems: 12,
                items: {
                  type: 'object',
                  additionalProperties: false,
                  properties: {
                    title: { type: 'string' },
                    project: { type: 'string' },
                    tag: { type: 'string' },
                    note: { type: 'string' },
                    estimatedPomodoros: { type: 'integer', minimum: 1, maximum: 20 },
                    reason: { type: 'string' }
                  },
                  required: ['title', 'project', 'tag', 'note', 'estimatedPomodoros', 'reason']
                }
              }
            },
            required: ['summary', 'steps']
          }
        }
      }
    })
  });

  if (!openAiResponse.ok) {
    const errorBody = await openAiResponse.text();
    console.error(`OpenAI request failed: ${openAiResponse.status} ${errorBody.slice(0, 500)}`);
    throw new Error('OPENAI_REQUEST_FAILED');
  }
  const responseBody = await openAiResponse.json();
  const outputText = getOutputText(responseBody);
  if (!outputText) throw new Error('EMPTY_MODEL_OUTPUT');
  return JSON.parse(outputText);
}

const server = http.createServer(async (request, response) => {
  if (request.method === 'GET' && request.url === '/health') {
    sendJson(response, 200, { ok: true, model });
    return;
  }
  if (request.method !== 'POST' || request.url !== '/plan') {
    sendJson(response, 404, { error: 'Not found' });
    return;
  }
  if (!apiKey) {
    sendJson(response, 503, { error: 'OPENAI_API_KEY is not configured' });
    return;
  }

  try {
    const body = await readJson(request);
    const input = normalizeRequest(body);
    const plan = await createPlan(input);
    sendJson(response, 200, plan);
  } catch (error) {
    const message = error instanceof Error ? error.message : 'UNKNOWN_ERROR';
    if (message === 'INVALID_GOAL' || message === 'BODY_TOO_LARGE' || error instanceof SyntaxError) {
      sendJson(response, 400, { error: '请求内容无效' });
      return;
    }
    console.error(error);
    sendJson(response, 502, { error: 'AI 计划生成失败' });
  }
});

server.listen(port, host, () => {
  console.log(`AI planner proxy listening on http://${host}:${port}`);
});
