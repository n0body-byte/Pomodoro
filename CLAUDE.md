# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## 项目概述

番茄钟 (Pomodoro Timer) — HarmonyOS ArkTS 应用，API 22 (6.0.2)，Stage 模型。

## 构建与运行

本项目必须通过 **DevEco Studio IDE** 构建和运行，没有 CLI 构建命令。代码编辑后可借助 IDE 的 Previewer 或真机/模拟器运行。

- 入口 Ability: `entry/src/main/ets/entryability/EntryAbility.ets`
- 页面路由: `module.json5` → `"pages": "$profile:main_pages"` → 主页面 `pages/Index`
- 代码检查: `code-linter.json5` 配置了 ArkTS ESLint 规则（安全 + TypeScript 推荐）
- 测试框架: `@ohos/hypium` (1.0.25)，测试文件在 `entry/src/test/` 和 `entry/src/ohosTest/`

## 项目结构

```
entry/src/main/ets/
  pages/Index.ets          # 唯一 @Entry 页面，三 Tab 容器 + 全部计时逻辑
  components/
    CircularProgress.ets    # 环形进度组件（ProgressType.Ring）
    TimerControls.ets       # 开始/暂停/重置/跳过按钮组
    SessionCounter.ets      # 番茄计数（已弃用，暂停中的紧凑设计）
  views/
    Settings.ets            # 设置页（时长、目标、主题、提示音）+ SoundOption 子组件
    Statistics.ets          # 统计页（日/周/月柱状图）
  common/Constants.ets      # 全部常量：默认值、Preferences key、通知 ID
  utils/
    PreferencesHelper.ets   # 数据持久化封装（Preferences API）
    SoundHelper.ets         # 提示音播放（AVPlayer 状态机）
  entryability/EntryAbility.ets  # 应用入口 Ability
resources/
  base/element/  color.json, float.json, string.json
  dark/element/  color.json     # 深色主题颜色（默认 #000000 背景）
  light/element/ color.json     # 浅色主题颜色（#F2F2F7 背景）
  rawfile/       bell.wav, chime.wav, beep.wav, double_beep.wav, ding.wav
```

## 核心架构模式

### 导航与数据流

单页面 Tabs 架构。`Index.ets` 是唯一 `@Entry`，持有所有 `@State`，通过 `@Prop` 向下传递，通过回调向上通知：

```
Index (@State: isRunning, remainingSeconds, isWorkMode, isDarkMode, soundName, ...)
  ├── CircularProgress (@Prop: progress, remainingSeconds, totalSeconds, isWorkMode)
  ├── TimerControls (@Prop: isRunning, isWorkMode; 回调: onStartPause, onReset, onSkip)
  ├── Settings (@Prop: isDarkMode, soundName; 回调: onThemeChange, onSoundChange, onSaved)
  └── Statistics (独立加载数据，不接收 props)
```

### 主题切换

利用 HarmonyOS **资源限定符系统** + `applicationContext.setColorMode()`：
- `base/color.json` 定义所有颜色 key（深色值）
- `dark/color.json` 深色覆盖，`light/color.json` 浅色覆盖
- 所有 `.ets` 文件使用 `$r('app.color.xxx')` 引用，切换 colorMode 后自动解析
- 入口 `EntryAbility.onCreate` 设为 `COLOR_MODE_NOT_SET`（跟随系统），`Index.aboutToAppear` 加载用户偏好并调用 `setColorMode` 覆盖
- `PreferencesHelper.saveTheme/loadTheme` 持久化 boolean

### 计时器

`setInterval` 每秒 tick，`remainingSeconds -= 1`。结束后 `handleTimerComplete()`：播放声音 → 记录 session → 发通知 → 切换模式 → 2s 后自动开始。

后台恢复（`recoverFromBackground`）：从 Preferences 读取保存的时间戳，计算 elapsed 时间并调整倒计时。

### 数据持久化

`PreferencesHelper` 封装 `@kit.ArkData` 的 `preferences` API。所有方法均为 static async，传入 `context: Context`：
- 设置项：workDuration, breakDuration, dailyTarget, theme, sound（单个 key-value）
- Session 历史：JSON 数组，按 date 过滤统计
- 计时器状态：JSON 对象，用于后台恢复

### 音频播放

`SoundHelper.play(context, soundName)` 使用 AVPlayer 播放 `rawfile/` 下的 WAV 文件。**HarmonyOS AVPlayer 是状态机**，必须通过 `stateChange` 事件驱动，不能顺序调用：

```
fdSrc 赋值 → 'initialized' → prepare() → 'prepared' → play() → 'completed' → stop() → 'stopped'
```

资源加载使用 `context.resourceManager.getRawFd()` 获取文件描述符，通过 `player.fdSrc` 赋值（不能用 `player.url`）。

## ArkTS 关键约束

- **静态方法中不能使用 `this`**（`arkts-no-standalone-this`）→ 模块级变量代替静态属性
- 不能使用 `any`/`unknown` 类型
- 不能使用 `Function` 类型 → 用箭头函数类型 `() => void`
- 所有 catch 块不能省略参数 → `catch { }`（无括号）
- `$r()` 资源引用不能拼接字符串 → 不能用 `` `app.color.${name}` ``
- 文件路径不能用相对路径 import → 使用 `../utils/xxx` 形式

## Git

- 仓库：`github.com:n0body-byte/Pomodoro`，SSH 推送
- 主分支：`master`
- 提交风格：中文描述，简明扼要（如"新增计时结束提示音功能"）
