# 番茄钟 - HarmonyOS 智能专注助手

一款使用 ArkTS 与 ArkUI 开发的 HarmonyOS 番茄钟应用。项目将计时、任务、历史、统计、成就与 AI 规划组合成完整的专注执行闭环。

## 功能概览

- 专注、短休息和长休息计时，支持分别设置自动衔接规则
- 经典、深度和轻量三套计时方案
- 当前任务、项目、标签、备注与预计番茄数
- 提前结束时可选择按实际时间或按完整阶段计入统计
- 历史记录查看、补记、编辑和二次确认删除
- 日、周、月专注统计与成就系统
- 通知栏倒计时、结束通知、振动、提示音和三种白噪音
- 深色与浅色主题、音量控制和设置持久化
- DeepSeek 多轮执行智能体：结合真实专注数据生成计划、应用任务、跟踪完成状态并复盘
- AI 对话历史归档与恢复；API Key 仅保留在运行内存中

## 应用界面

<p align="center">
  <img src="docs/images/timer.jpeg" width="30%" alt="计时页">
  <img src="docs/images/ai.jpeg" width="30%" alt="AI 执行智能体">
  <img src="docs/images/settings.jpeg" width="30%" alt="设置页">
</p>

<p align="center">
  <img src="docs/images/statistics.jpeg" width="30%" alt="统计页">
  <img src="docs/images/history.jpeg" width="30%" alt="历史记录页">
  <img src="docs/images/achievements.jpeg" width="30%" alt="成就页">
</p>

## 技术栈

| 层级 | 技术 |
|---|---|
| UI | ArkUI 声明式 UI、ArkTS、V1 状态管理 |
| 数据 | ArkData Preferences |
| 网络 | Network Kit HTTP Client |
| 系统能力 | Notification Kit、Sensor Service Kit、Media Kit、Ability Kit |
| AI | DeepSeek Chat Completions JSON Output；可选 OpenAI 服务端代理 |
| 架构 | `pages / views / components / utils / common` 分层 |

## 开发环境

- DevEco Studio 6.0.2
- HarmonyOS SDK API 22
- Node.js 18 或更高版本（仅 AI 代理需要）

## 快速运行

1. 使用 DevEco Studio 打开项目根目录。
2. 等待 Hvigor 与依赖同步完成。
3. 选择 HarmonyOS 模拟器或真机。
4. 运行 `entry` 模块。

命令行构建示例：

```powershell
hvigorw --mode module -p product=default assembleHap --no-daemon
```

构建产物默认位于：

```text
entry/build/default/outputs/default/entry-default-unsigned.hap
```

项目未提交个人签名配置，因此命令行构建默认输出未签名 HAP。安装到真机前需在 DevEco Studio 中配置签名。

## 使用 DeepSeek 智能体

1. 进入“AI 计划”。
2. 打开右上角服务设置。
3. 选择 V4 Flash 或 V4 Pro，输入 DeepSeek API Key。
4. 描述目标、可用时间与截止时间，生成执行计划。
5. 将计划步骤设为当前专注任务，完成后返回 AI 页面复盘。

安全说明：DeepSeek API Key 不写入 Preferences，也不会进入 AI 对话历史；退出应用后需要重新输入。客户端直连适合个人演示和开发，正式发布建议使用带鉴权、限流与日志脱敏的服务端代理。

## 可选 AI 代理

`ai-proxy/` 提供一个最小 OpenAI Responses API 代理，密钥只保存在服务端环境变量中：

```powershell
$env:OPENAI_API_KEY = "你的 API Key"
node .\ai-proxy\server.mjs
```

健康检查：`GET http://127.0.0.1:8787/health`。详细配置见 [ai-proxy/README.md](ai-proxy/README.md)。

## 测试与验证

本地单元测试覆盖：

- 后台截止时间换算与向上取整
- 完成、放弃、跳过和休息记录的统计兼容性
- 长休息触发周期与异常间隔
- 专注/休息的独立自动开始规则

```powershell
hvigorw test -p module=entry
```

完整手动验证矩阵、架构说明、评分点映射与产品前景分析见 [项目说明文档](说明文档.md)，排版版 PDF 见 [项目说明文档 PDF](output/pdf/番茄钟项目说明文档.pdf)。

## 项目结构

```text
entry/src/main/ets/
├── common/       # 常量与 Preferences Key
├── components/   # 环形进度、计时控制、庆祝动画等组件
├── pages/        # 应用入口和全局计时状态机
├── utils/        # 持久化、通知、音频、AI、成就与计时辅助逻辑
└── views/        # AI、设置、统计、历史和成就页面
```

## 文档

- [完整项目说明](说明文档.md)
- [PDF 版项目说明](output/pdf/番茄钟项目说明文档.pdf)
- [AI 代理说明](ai-proxy/README.md)
