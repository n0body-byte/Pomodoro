import { ConfigurationConstant, common } from '@kit.AbilityKit';
import { CircularProgress } from '../components/CircularProgress';
import { TimerControls } from '../components/TimerControls';
import { CelebrationOverlay } from '../components/CelebrationOverlay';
import { PreferencesHelper, TaskContext } from '../utils/PreferencesHelper';
import { SoundHelper } from '../utils/SoundHelper';
import { AmbientHelper } from '../utils/AmbientHelper';
import { NotificationHelper } from '../utils/NotificationHelper';
import { TimerHelper } from '../utils/TimerHelper';
import { TimerPlanHelper } from '../utils/TimerPlanHelper';
import { Settings } from '../views/Settings';
import { Insights } from '../views/Insights';
import { AiPlanner } from '../views/AiPlanner';
import { AiPlanStep } from '../utils/AiAgentModels';
import {
  DEFAULT_WORK_SECONDS,
  DEFAULT_BREAK_SECONDS,
  DEFAULT_DAILY_TARGET,
  NOTIFICATION_UPDATE_INTERVAL
} from '../common/Constants';

const MAX_RECOVERED_PHASES = 32;

@Entry
@Component
struct Index {
  @State remainingSeconds: number = DEFAULT_WORK_SECONDS;
  @State totalSeconds: number = DEFAULT_WORK_SECONDS;
  @State isRunning: boolean = false;
  @State isWorkMode: boolean = true;
  @State completedSessions: number = 0;
  @State progressValue: number = 100;
  @State todayCount: number = 0;
  @State todayWorkSeconds: number = 0;
  @State todayBreakSeconds: number = 0;
  @State dailyTarget: number = DEFAULT_DAILY_TARGET;
  @State currentTabIndex: number = 0;
  @State isDarkMode: boolean = false;
  @State soundName: string = 'bell';
  @State ambientName: string = '';
  @State showCelebration: boolean = false;
  @State autoStartWork: boolean = false;
  @State autoStartBreak: boolean = false;
  @State isLongBreak: boolean = false;
  @State soundEnabled: boolean = true;
  @State soundVolume: number = 0.8;
  @State ambientVolume: number = 0.5;
  @State currentTask: string = '';
  @State currentProject: string = '';
  @State currentTag: string = '';
  @State currentNote: string = '';
  @State estimatedPomodoros: number = 1;
  @State currentTaskCompleted: number = 0;
  @State currentTaskSource: string = 'manual';
  @State currentTaskConversationId: string = '';
  @State showTaskEditor: boolean = false;
  @State showEndEarlyDialog: boolean = false;
  @State taskDraft: string = '';
  @State projectDraft: string = '';
  @State tagDraft: string = '';
  @State noteDraft: string = '';
  @State estimateDraft: number = 1;

  private timerId: number | null = null;
  private workDuration: number = DEFAULT_WORK_SECONDS;
  private breakDuration: number = DEFAULT_BREAK_SECONDS;
  private longBreakDuration: number = 15 * 60;
  private longBreakInterval: number = 4;
  private tickCount: number = 0;
  private deadlineAt: number = 0;
  private autoStartTimerId: number | null = null;
  private ambientPreviewTimerId: number | null = null;
  private isCompleting: boolean = false;
  private taskTrackingStartedAt: number = 0;
  private tabsController: TabsController = new TabsController();

  async aboutToAppear(): Promise<void> {
    const ctx = this.getContext();
    await NotificationHelper.requestPermission(ctx as common.UIAbilityContext);
    this.isDarkMode = await PreferencesHelper.loadTheme(ctx);
    this.soundName = await PreferencesHelper.loadSound(ctx);
    this.ambientName = await PreferencesHelper.loadAmbient(ctx);
    this.autoStartWork = await PreferencesHelper.loadAutoStartWork(ctx);
    this.autoStartBreak = await PreferencesHelper.loadAutoStartBreak(ctx);
    this.soundEnabled = await PreferencesHelper.loadSoundEnabled(ctx);
    this.soundVolume = await PreferencesHelper.loadSoundVolume(ctx);
    this.ambientVolume = await PreferencesHelper.loadAmbientVolume(ctx);
    const taskContext = await PreferencesHelper.loadTaskContext(ctx);
    this.applyTaskContext(taskContext);
    this.applyColorMode();
    await this.loadSettings();
    this.completedSessions = 0;
    this.todayCount = 0;
    this.remainingSeconds = this.workDuration;
    this.totalSeconds = this.workDuration;
    this.updateProgress();
  }

  aboutToDisappear(): void {
    this.saveCurrentState();
    this.clearTimerInterval();
    this.cancelScheduledAutoStart();
    NotificationHelper.cancelOngoing();
    AmbientHelper.stop();
    SoundHelper.release();
  }

  async onPageShow(): Promise<void> {
    await this.loadTodayStats();
    await this.recoverFromBackground();
  }

  async onPageHide(): Promise<void> {
    await this.saveCurrentState();
  }

  private applyColorMode(): void {
    const ctx = this.getUIContext().getHostContext();
    if (ctx) {
      const appCtx = ctx.getApplicationContext();
      appCtx.setColorMode(this.isDarkMode
        ? ConfigurationConstant.ColorMode.COLOR_MODE_DARK
        : ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT
      );
    }
  }

  private applyTaskContext(taskContext: TaskContext): void {
    this.currentTask = taskContext.task;
    this.currentProject = taskContext.project;
    this.currentTag = taskContext.tag;
    this.currentNote = taskContext.note;
    this.estimatedPomodoros = Math.max(1, taskContext.estimatedPomodoros || 1);
    this.taskTrackingStartedAt = typeof taskContext.trackingStartedAt === 'number' ?
      Math.max(0, taskContext.trackingStartedAt) : 0;
    this.currentTaskSource = taskContext.source === 'ai' ? 'ai' : 'manual';
    this.currentTaskConversationId = typeof taskContext.agentConversationId === 'string' ?
      taskContext.agentConversationId : '';
  }

  private async saveTaskContext(): Promise<void> {
    const nextTask = this.taskDraft.trim();
    const nextProject = this.projectDraft.trim();
    if (nextTask !== this.currentTask || nextProject !== this.currentProject) {
      this.taskTrackingStartedAt = Date.now();
      this.currentTaskSource = 'manual';
      this.currentTaskConversationId = '';
    }
    this.currentTask = nextTask;
    this.currentProject = nextProject;
    this.currentTag = this.tagDraft.trim();
    this.currentNote = this.noteDraft.trim();
    this.estimatedPomodoros = this.estimateDraft;
    await PreferencesHelper.saveTaskContext(this.getContext(), {
      task: this.currentTask.trim(),
      project: this.currentProject.trim(),
      tag: this.currentTag.trim(),
      note: this.currentNote.trim(),
      estimatedPomodoros: this.estimatedPomodoros,
      trackingStartedAt: this.taskTrackingStartedAt,
      source: this.currentTaskSource === 'ai' ? 'ai' : 'manual',
      agentConversationId: this.currentTaskConversationId
    });
    this.currentTask = this.currentTask.trim();
    this.currentProject = this.currentProject.trim();
    this.currentTag = this.currentTag.trim();
    this.currentNote = this.currentNote.trim();
    this.showTaskEditor = false;
    await this.loadTodayStats();
  }

  private hasTaskContent(): boolean {
    return this.currentTask.length > 0 || this.currentProject.length > 0 ||
      this.currentTag.length > 0 || this.currentNote.length > 0 ||
      this.taskDraft.length > 0 || this.projectDraft.length > 0 ||
      this.tagDraft.length > 0 || this.noteDraft.length > 0;
  }

  private async clearTaskContext(): Promise<void> {
    this.currentTask = '';
    this.currentProject = '';
    this.currentTag = '';
    this.currentNote = '';
    this.estimatedPomodoros = 1;
    this.currentTaskCompleted = 0;
    this.currentTaskSource = 'manual';
    this.currentTaskConversationId = '';
    this.taskTrackingStartedAt = 0;
    this.taskDraft = '';
    this.projectDraft = '';
    this.tagDraft = '';
    this.noteDraft = '';
    this.estimateDraft = 1;
    await PreferencesHelper.saveTaskContext(this.getContext(), {
      task: '',
      project: '',
      tag: '',
      note: '',
      estimatedPomodoros: 1,
      trackingStartedAt: 0,
      source: 'manual',
      agentConversationId: ''
    });
    this.showTaskEditor = false;
  }

  private async applyAiPlanStep(step: AiPlanStep, conversationId: string): Promise<void> {
    if (this.isRunning || this.remainingSeconds !== this.totalSeconds) {
      return;
    }
    this.currentTask = step.title;
    this.currentProject = step.project;
    this.currentTag = step.tag;
    this.currentNote = step.note;
    this.estimatedPomodoros = step.estimatedPomodoros;
    this.taskTrackingStartedAt = Date.now();
    this.currentTaskSource = 'ai';
    this.currentTaskConversationId = conversationId;
    await PreferencesHelper.saveTaskContext(this.getContext(), {
      task: this.currentTask,
      project: this.currentProject,
      tag: this.currentTag,
      note: this.currentNote,
      estimatedPomodoros: this.estimatedPomodoros,
      trackingStartedAt: this.taskTrackingStartedAt,
      source: 'ai',
      agentConversationId: conversationId
    });
    this.currentTaskCompleted = 0;
    this.currentTabIndex = 0;
    this.tabsController.changeIndex(0);
  }

  private openTaskEditor(): void {
    this.taskDraft = this.currentTask;
    this.projectDraft = this.currentProject;
    this.tagDraft = this.currentTag;
    this.noteDraft = this.currentNote;
    this.estimateDraft = this.estimatedPomodoros;
    this.showTaskEditor = true;
  }

  private playSelectedSound(sound: string = this.soundName): void {
    if (this.soundEnabled && this.soundVolume > 0) {
      SoundHelper.play(this.getContext(), sound, this.soundVolume);
    }
  }

  private previewAmbient(name: string): void {
    if (this.isRunning || name === '') {
      return;
    }
    if (this.ambientPreviewTimerId !== null) {
      clearTimeout(this.ambientPreviewTimerId);
    }
    AmbientHelper.start(this.getContext(), name, this.ambientVolume);
    this.ambientPreviewTimerId = setTimeout(() => {
      this.ambientPreviewTimerId = null;
      AmbientHelper.stop();
    }, 3000);
  }

  private onThemeChange(isDark: boolean): void {
    this.isDarkMode = isDark;
    this.applyColorMode();
    PreferencesHelper.saveTheme(this.getContext(), isDark);
  }

  private getContext(): Context {
    return this.getUIContext().getHostContext()!;
  }

  async loadSettings(): Promise<void> {
    try {
      this.workDuration = await PreferencesHelper.loadWorkDuration(this.getContext());
      this.breakDuration = await PreferencesHelper.loadBreakDuration(this.getContext());
      this.dailyTarget = await PreferencesHelper.loadDailyTarget(this.getContext());
      this.longBreakDuration = await PreferencesHelper.loadLongBreakDuration(this.getContext());
      this.longBreakInterval = await PreferencesHelper.loadLongBreakInterval(this.getContext());
    } catch {
      this.workDuration = DEFAULT_WORK_SECONDS;
      this.breakDuration = DEFAULT_BREAK_SECONDS;
      this.dailyTarget = DEFAULT_DAILY_TARGET;
      this.longBreakDuration = 15 * 60;
      this.longBreakInterval = 4;
    }
  }

  async loadTodayStats(): Promise<void> {
    try {
      this.todayCount = await PreferencesHelper.getTodaySessions(this.getContext());
      this.todayWorkSeconds = await PreferencesHelper.getTodayWorkSeconds(this.getContext());
      this.todayBreakSeconds = await PreferencesHelper.getTodayBreakSeconds(this.getContext());
      this.currentTaskCompleted = await PreferencesHelper.getTaskCompletedSessions(
        this.getContext(), this.currentTask, this.currentProject, this.taskTrackingStartedAt);
    } catch {
      this.todayCount = 0;
      this.todayWorkSeconds = 0;
      this.todayBreakSeconds = 0;
      this.currentTaskCompleted = 0;
    }
  }

  updateProgress(): void {
    if (this.totalSeconds > 0) {
      this.progressValue = (this.remainingSeconds / this.totalSeconds) * 100;
    } else {
      this.progressValue = 0;
    }
  }

  private clearTimerInterval(): void {
    if (this.timerId !== null) {
      clearInterval(this.timerId);
      this.timerId = null;
    }
  }

  private cancelScheduledAutoStart(): void {
    if (this.autoStartTimerId !== null) {
      clearTimeout(this.autoStartTimerId);
      this.autoStartTimerId = null;
    }
  }

  private refreshRemainingFromDeadline(): void {
    if (this.deadlineAt <= 0) {
      return;
    }
    this.remainingSeconds = TimerHelper.calculateRemainingSeconds(this.deadlineAt, Date.now());
    this.updateProgress();
  }

  private beginTimerWithDeadline(deadlineAt: number): void {
    this.clearTimerInterval();
    this.deadlineAt = deadlineAt;
    this.isRunning = true;
    this.tickCount = 0;
    this.refreshRemainingFromDeadline();
    NotificationHelper.publishOngoing(this.remainingSeconds, this.isWorkMode);
    if (this.isWorkMode && this.ambientName !== '') {
      AmbientHelper.start(this.getContext(), this.ambientName, this.ambientVolume);
    }
    this.timerId = setInterval(() => {
      this.tick();
    }, 1000);
  }

  startTimer(): void {
    if (this.timerId !== null || this.remainingSeconds <= 0) {
      return;
    }
    this.cancelScheduledAutoStart();
    this.beginTimerWithDeadline(Date.now() + this.remainingSeconds * 1000);
    this.saveCurrentState();
  }

  stopTimer(): void {
    this.refreshRemainingFromDeadline();
    this.clearTimerInterval();
    this.cancelScheduledAutoStart();
    this.deadlineAt = 0;
    this.isRunning = false;
    NotificationHelper.cancelOngoing();
    AmbientHelper.stop();
  }

  tick(): void {
    if (!this.isRunning || this.deadlineAt <= 0) {
      return;
    }
    this.refreshRemainingFromDeadline();
    this.tickCount += 1;

    if (this.remainingSeconds <= 0) {
      this.handleTimerComplete();
      return;
    }

    if (this.tickCount % NOTIFICATION_UPDATE_INTERVAL === 0) {
      NotificationHelper.publishOngoing(this.remainingSeconds, this.isWorkMode);
    }
  }

  private scheduleAutoStart(): void {
    this.cancelScheduledAutoStart();
    this.autoStartTimerId = setTimeout(() => {
      this.autoStartTimerId = null;
      this.startTimer();
    }, 2000);
  }

  async handleTimerComplete(): Promise<void> {
    if (this.isCompleting) {
      return;
    }
    this.isCompleting = true;
    const completedWorkMode = this.isWorkMode;
    const completedDuration = this.totalSeconds;
    const completedAt = this.deadlineAt > 0 ? this.deadlineAt : Date.now();
    const previousTodayCount = this.todayCount;

    this.remainingSeconds = 0;
    this.updateProgress();
    this.clearTimerInterval();
    this.deadlineAt = 0;
    this.isRunning = false;
    NotificationHelper.cancelOngoing();
    AmbientHelper.stop();

    this.playSelectedSound();

    if (completedWorkMode) {
      this.completedSessions += 1;
      NotificationHelper.sendEndNotification(true);
      this.switchToBreak();
    } else {
      NotificationHelper.sendEndNotification(false);
      this.switchToWork();
    }

    if (TimerPlanHelper.shouldAutoStart(completedWorkMode, this.autoStartBreak, this.autoStartWork)) {
      this.scheduleAutoStart();
    }

    try {
      const saved = await this.persistPhaseRecord(completedWorkMode, completedDuration, completedDuration,
        completedAt, 'completed');
      await this.loadTodayStats();
      if (saved && completedWorkMode && this.currentTaskCompleted >= this.estimatedPomodoros) {
        await PreferencesHelper.markAiPlanStepCompleted(
          this.getContext(), this.currentTask, this.currentProject);
      }
      if (completedWorkMode && previousTodayCount < this.dailyTarget && this.todayCount >= this.dailyTarget) {
        this.triggerCelebration();
      }
      await this.saveCurrentState();
    } finally {
      this.isCompleting = false;
    }
  }

  private getDateStr(timestamp: number): string {
    const date = new Date(timestamp);
    return `${date.getFullYear()}-${(date.getMonth() + 1).toString().padStart(2, '0')}-${date.getDate().toString().padStart(2, '0')}`;
  }

  private async persistPhaseRecord(isWorkMode: boolean, actualSeconds: number, plannedSeconds: number,
    completedAt: number, status: 'completed' | 'abandoned' | 'skipped'): Promise<boolean> {
    if (actualSeconds <= 0) {
      return false;
    }
    try {
      await PreferencesHelper.saveSessionRecord(this.getContext(), {
        date: this.getDateStr(completedAt),
        workSeconds: Math.min(actualSeconds, plannedSeconds),
        startedAt: completedAt - Math.min(actualSeconds, plannedSeconds) * 1000,
        completedAt: completedAt,
        type: isWorkMode ? 'work' : 'break',
        status: status,
        plannedSeconds: plannedSeconds,
        task: this.currentTask,
        project: this.currentProject,
        tag: this.currentTag,
        note: this.currentNote,
        source: 'timer'
      });
      return true;
    } catch {
      // 单次记录失败不阻塞计时状态切换。
      return false;
    }
  }

  triggerCelebration(): void {
    this.showCelebration = true;
    this.playSelectedSound('celebration');
    setTimeout(() => {
      this.showCelebration = false;
    }, 4000);
  }

  clearTodayData(): void {
    PreferencesHelper.clearTodaySessions(this.getContext()).then(() => {
      this.todayCount = 0;
      this.todayWorkSeconds = 0;
      this.todayBreakSeconds = 0;
      this.completedSessions = 0;
    });
  }

  switchToWork(): void {
    this.isWorkMode = true;
    this.isLongBreak = false;
    this.totalSeconds = this.workDuration;
    this.remainingSeconds = this.workDuration;
    this.updateProgress();
  }

  switchToBreak(): void {
    this.isWorkMode = false;
    this.isLongBreak = TimerPlanHelper.isLongBreak(this.completedSessions, this.longBreakInterval);
    this.totalSeconds = TimerPlanHelper.getBreakDuration(this.completedSessions, this.longBreakInterval,
      this.breakDuration, this.longBreakDuration);
    this.remainingSeconds = this.totalSeconds;
    this.updateProgress();
  }

  onStartPause(): void {
    if (this.isRunning) {
      this.stopTimer();
      this.saveCurrentState();
    } else {
      this.startTimer();
    }
  }

  onReset(): void {
    this.stopTimer();
    this.remainingSeconds = this.totalSeconds;
    this.updateProgress();
    this.saveCurrentState();
  }

  async onSkipBreak(): Promise<void> {
    const plannedSeconds = this.totalSeconds;
    this.stopTimer();
    const actualSeconds = Math.max(0, plannedSeconds - this.remainingSeconds);
    this.playSelectedSound();
    this.switchToWork();
    if (this.autoStartWork) {
      this.scheduleAutoStart();
    }
    const saved = await this.persistPhaseRecord(false, actualSeconds, plannedSeconds, Date.now(), 'skipped');
    if (saved) {
      this.todayBreakSeconds += actualSeconds;
    }
    await this.saveCurrentState();
  }

  onSkipPhase(): void {
    if (!this.isRunning) {
      return;
    }
    if (this.isWorkMode) {
      this.stopTimer();
      this.showEndEarlyDialog = true;
    } else {
      this.onSkipBreak();
    }
  }

  private cancelEndEarly(): void {
    this.showEndEarlyDialog = false;
    this.startTimer();
  }

  async finishEarly(action: string): Promise<void> {
    if (this.isCompleting) {
      return;
    }
    this.isCompleting = true;
    const plannedSeconds = this.totalSeconds;
    const actualSeconds = Math.max(0, plannedSeconds - this.remainingSeconds);
    const previousTodayCount = this.todayCount;
    this.showEndEarlyDialog = false;
    try {
      if (action === 'completed') {
        this.completedSessions += 1;
        // “按完成计算”代表将本轮视为完整番茄，统计时计入全部计划时长。
        const saved = await this.persistPhaseRecord(
          true, plannedSeconds, plannedSeconds, Date.now(), 'completed');
        if (saved) {
          this.todayWorkSeconds += plannedSeconds;
          this.todayCount += 1;
          if (this.currentTask.length > 0) {
            this.currentTaskCompleted += 1;
          }
          if (this.currentTaskCompleted >= this.estimatedPomodoros) {
            await PreferencesHelper.markAiPlanStepCompleted(
              this.getContext(), this.currentTask, this.currentProject);
          }
        }
      } else if (action === 'partial') {
        const saved = await this.persistPhaseRecord(
          true, actualSeconds, plannedSeconds, Date.now(), 'abandoned');
        if (saved) {
          this.todayWorkSeconds += actualSeconds;
        }
      }
      if (action !== 'discard') {
        this.playSelectedSound();
      }
      this.switchToBreak();
      if (this.autoStartBreak) {
        this.scheduleAutoStart();
      }
      if (action === 'completed' && previousTodayCount < this.dailyTarget && this.todayCount >= this.dailyTarget) {
        this.triggerCelebration();
      }
      await this.saveCurrentState();
    } finally {
      this.isCompleting = false;
    }
  }

  async saveCurrentState(): Promise<void> {
    try {
      await PreferencesHelper.saveTimerState(this.getContext(), {
        remainingSeconds: this.remainingSeconds,
        totalSeconds: this.totalSeconds,
        isWorkMode: this.isWorkMode,
        isRunning: this.isRunning,
        completedSessions: this.completedSessions,
        savedAt: Date.now(),
        deadlineAt: this.isRunning ? this.deadlineAt : 0,
        isLongBreak: this.isLongBreak
      });
    } catch {
      // 保存失败静默处理
    }
  }

  async recoverFromBackground(): Promise<void> {
    this.clearTimerInterval();
    this.cancelScheduledAutoStart();
    NotificationHelper.cancelOngoing();
    AmbientHelper.stop();
    this.isCompleting = false;

    try {
      const state = await PreferencesHelper.loadTimerState(this.getContext());
      if (state !== null) {
        this.totalSeconds = state.totalSeconds;
        this.isWorkMode = state.isWorkMode;
        this.isLongBreak = state.isLongBreak || false;
        this.completedSessions = state.completedSessions;

        if (!state.isRunning) {
          this.isRunning = false;
          this.deadlineAt = 0;
          this.remainingSeconds = Math.max(0, Math.min(state.remainingSeconds, state.totalSeconds));
          this.updateProgress();
          return;
        }

        const now = Date.now();
        let phaseWorkMode = state.isWorkMode;
        let phaseDuration = state.totalSeconds;
        let phaseEndAt = state.deadlineAt !== undefined && state.deadlineAt > 0
          ? state.deadlineAt
          : state.savedAt + state.remainingSeconds * 1000;
        let recoveredPhases = 0;

        while (phaseEndAt <= now && recoveredPhases < MAX_RECOVERED_PHASES) {
          await this.persistPhaseRecord(phaseWorkMode, phaseDuration, phaseDuration,
            phaseEndAt, 'completed');
          if (phaseWorkMode) {
            this.completedSessions += 1;
          }

          const shouldContinue = TimerPlanHelper.shouldAutoStart(
            phaseWorkMode, this.autoStartBreak, this.autoStartWork);
          phaseWorkMode = !phaseWorkMode;
          if (phaseWorkMode) {
            phaseDuration = this.workDuration;
          } else {
            phaseDuration = TimerPlanHelper.getBreakDuration(this.completedSessions, this.longBreakInterval,
              this.breakDuration, this.longBreakDuration);
          }
          recoveredPhases += 1;

          if (!shouldContinue) {
            this.isWorkMode = phaseWorkMode;
            this.isLongBreak = !phaseWorkMode &&
              TimerPlanHelper.isLongBreak(this.completedSessions, this.longBreakInterval);
            this.totalSeconds = phaseDuration;
            this.remainingSeconds = phaseDuration;
            this.isRunning = false;
            this.deadlineAt = 0;
            this.updateProgress();
            await this.loadTodayStats();
            await this.saveCurrentState();
            return;
          }
          phaseEndAt += phaseDuration * 1000;
        }

        this.isWorkMode = phaseWorkMode;
        this.isLongBreak = !phaseWorkMode &&
          TimerPlanHelper.isLongBreak(this.completedSessions, this.longBreakInterval);
        this.totalSeconds = phaseDuration;

        if (phaseEndAt <= now) {
          // 长时间未返回时停止自动追赶，避免生成大量无人值守的虚假记录。
          this.remainingSeconds = phaseDuration;
          this.isRunning = false;
          this.deadlineAt = 0;
          this.updateProgress();
        } else {
          this.remainingSeconds = TimerHelper.calculateRemainingSeconds(phaseEndAt, now);
          this.updateProgress();
          this.beginTimerWithDeadline(phaseEndAt);
        }

        await this.loadTodayStats();
        await this.saveCurrentState();
        return;
      }
    } catch {
      // 恢复失败静默处理
    }
    await this.loadSettings();
    this.isRunning = false;
    this.deadlineAt = 0;
    this.totalSeconds = this.isWorkMode ? this.workDuration : this.breakDuration;
    this.remainingSeconds = this.totalSeconds;
    this.updateProgress();
  }

  private getCapsuleIndices(): number[] {
    const arr: number[] = [];
    for (let i = 0; i < this.dailyTarget; i++) {
      arr.push(i);
    }
    return arr;
  }

  private async onNavigateToTimer(): Promise<void> {
    await this.loadSettings();
    this.autoStartWork = await PreferencesHelper.loadAutoStartWork(this.getContext());
    this.autoStartBreak = await PreferencesHelper.loadAutoStartBreak(this.getContext());
    // 仅在初始状态（未曾开始或刚完成复位）时应用新设置，暂停中的计时不受影响
    if (!this.isRunning && this.remainingSeconds === this.totalSeconds) {
      this.totalSeconds = this.isWorkMode ? this.workDuration : this.breakDuration;
      this.remainingSeconds = this.totalSeconds;
      this.updateProgress();
    }
  }

  @Builder
  tabBarTimer() {
    Column({ space: 1 }) {
      Image($r('app.media.pomodoro'))
        .width(18)
        .height(18)
        .fillColor(this.currentTabIndex === 0 ? $r('app.color.tab_selected') : $r('app.color.tab_unselected'))
      Text('计时')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.currentTabIndex === 0 ? $r('app.color.tab_selected') : $r('app.color.tab_unselected'))
    }
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }

  @Builder
  tabBarAiPlanner() {
    Column({ space: 1 }) {
      Image($r('app.media.ai_plan'))
        .width(18)
        .height(18)
        .fillColor(this.currentTabIndex === 1 ? $r('app.color.tab_selected') : $r('app.color.tab_unselected'))
      Text('AI 计划')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.currentTabIndex === 1 ? $r('app.color.tab_selected') : $r('app.color.tab_unselected'))
    }
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }

  @Builder
  tabBarSettings() {
    Column({ space: 1 }) {
      Image($r('app.media.settings'))
        .width(18)
        .height(18)
        .fillColor(this.currentTabIndex === 3 ? $r('app.color.tab_selected') : $r('app.color.tab_unselected'))
      Text('设置')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.currentTabIndex === 3 ? $r('app.color.tab_selected') : $r('app.color.tab_unselected'))
    }
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }

  @Builder
  tabBarInsights() {
    Column({ space: 1 }) {
      Image($r('app.media.statistics'))
        .width(18)
        .height(18)
        .fillColor(this.currentTabIndex === 2 ? $r('app.color.tab_selected') : $r('app.color.tab_unselected'))
      Text('数据')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.currentTabIndex === 2 ? $r('app.color.tab_selected') : $r('app.color.tab_unselected'))
    }
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }

  @Builder
  taskEditorOverlay() {
    if (this.showTaskEditor) {
      Column() {
        Column({ space: 12 }) {
          Row({ space: 10 }) {
            Text('设置本轮任务')
              .fontSize(20).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).layoutWeight(1)
            Button('清空任务').height(30).fontSize(10).borderRadius(15)
              .enabled(this.hasTaskContent())
              .backgroundColor('#24FA2E69').fontColor($r('app.color.primary_red'))
              .onClick(() => this.clearTaskContext())
          }.width('100%')
          TextInput({ text: this.taskDraft, placeholder: '这轮要完成什么？' })
            .height(44).backgroundColor($r('app.color.ring_track'))
            .onChange((value: string) => this.taskDraft = value)
          Row({ space: 8 }) {
            TextInput({ text: this.projectDraft, placeholder: '项目' })
              .layoutWeight(1).height(42).backgroundColor($r('app.color.ring_track'))
              .onChange((value: string) => this.projectDraft = value)
            TextInput({ text: this.tagDraft, placeholder: '标签' })
              .layoutWeight(1).height(42).backgroundColor($r('app.color.ring_track'))
              .onChange((value: string) => this.tagDraft = value)
          }
          TextInput({ text: this.noteDraft, placeholder: '本轮备注（可选）' })
            .height(42).backgroundColor($r('app.color.ring_track'))
            .onChange((value: string) => this.noteDraft = value)
          Row() {
            Text('预计番茄数').fontSize(13).fontColor($r('app.color.text_secondary'))
            Blank()
            Button() {
              Image($r('app.media.minus')).width(13).height(13)
                .fillColor($r('app.color.text_secondary'))
            }
              .width(32).height(32).borderRadius(16).padding(0)
              .backgroundColor($r('app.color.ring_track'))
              .onClick(() => this.estimateDraft = Math.max(1, this.estimateDraft - 1))
            Text(`${this.estimateDraft}`).width(46).textAlign(TextAlign.Center)
              .fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.primary_red'))
            Button() {
              Image($r('app.media.plus')).width(13).height(13).fillColor(Color.White)
            }
              .width(32).height(32).borderRadius(16).padding(0)
              .backgroundColor($r('app.color.primary_red'))
              .onClick(() => this.estimateDraft = Math.min(20, this.estimateDraft + 1))
          }
          Row({ space: 10 }) {
            Button('取消').layoutWeight(1).height(42)
              .backgroundColor($r('app.color.ring_track')).fontColor($r('app.color.text_secondary'))
              .onClick(() => this.showTaskEditor = false)
            Button('保存').layoutWeight(1).height(42)
              .backgroundColor($r('app.color.primary_red')).fontColor(Color.White)
              .onClick(() => this.saveTaskContext())
          }
        }
        .width('88%').padding(18)
        .backgroundColor($r('app.color.surface')).borderRadius(20)
      }
      .width('100%').height('100%')
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .backgroundColor('#88000000').zIndex(20)
    }
  }

  @Builder
  endEarlyOverlay() {
    if (this.showEndEarlyDialog) {
      Column() {
        Column({ space: 12 }) {
          Text('提前结束本轮？')
            .fontSize(20).fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))
          Text('选择如何处理已经专注的时间')
            .fontSize(12).fontColor($r('app.color.text_tertiary'))
          Button('按完成计算')
            .width('100%').height(42).backgroundColor($r('app.color.primary_red')).fontColor(Color.White)
            .onClick(() => this.finishEarly('completed'))
          Button('保存部分专注')
            .width('100%').height(42).backgroundColor($r('app.color.primary_green')).fontColor(Color.White)
            .onClick(() => this.finishEarly('partial'))
          Button('放弃，不记录')
            .width('100%').height(42).backgroundColor($r('app.color.ring_track'))
            .fontColor($r('app.color.text_secondary'))
            .onClick(() => this.finishEarly('discard'))
          Button('继续计时')
            .width('100%').height(36).backgroundColor(Color.Transparent)
            .fontColor($r('app.color.text_tertiary'))
            .onClick(() => this.cancelEndEarly())
        }
        .width('82%').padding(18)
        .backgroundColor($r('app.color.surface')).borderRadius(20)
      }
      .width('100%').height('100%')
      .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
      .backgroundColor('#88000000').zIndex(21)
    }
  }

  @Builder
  timerTab() {
    Stack() {
    Column() {
      // Bento 风格今日进度卡片
      Column({ space: 10 }) {
        Row({ space: 6 }) {
          Image($r('app.media.tomato'))
            .width(14)
            .height(14)
          Text('TODAY')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.today_label'))
            .letterSpacing(3)
        }
        .width('100%')

        Row({ space: 3 }) {
          ForEach(this.getCapsuleIndices(), (i: number) => {
            Column()
              .layoutWeight(1)
              .height(18)
              .borderRadius(2.5)
              .backgroundColor(i < this.todayCount ? $r('app.color.capsule_filled') : $r('app.color.capsule_empty'))
          }, (i: number) => i.toString())
        }
        .width('100%')

        Row({ space: 8 }) {
          Text(`${this.todayCount}/${this.dailyTarget}`)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          if (this.todayCount > 0) {
            Button() {
              Text('清空')
                .fontSize(10)
                .fontColor($r('app.color.text_tertiary'))
            }
              .height(24)
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: $r('app.color.divider'), radius: 6 })
              .padding({ left: 8, right: 8 })
              .onClick(() => this.clearTodayData())
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 14, bottom: 14 })
      .backgroundColor($r('app.color.surface'))
      .borderRadius(18)
      .border({ width: 1, color: $r('app.color.card_border') })

      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Text(this.currentTask.length > 0 ? this.currentTask : '设置本轮任务')
            .fontSize(14).fontWeight(FontWeight.Bold)
            .fontColor(this.currentTask.length > 0 ? $r('app.color.text_primary') : $r('app.color.primary_red'))
            .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          if (this.currentTask.length > 0) {
            Text(`${this.currentProject.length > 0 ? this.currentProject : '无项目'}${this.currentTag.length > 0 ? ` · #${this.currentTag}` : ''} · ${this.currentTaskCompleted}/${this.estimatedPomodoros}${this.currentTaskSource === 'ai' ? ' · AI 计划' : ''}`)
              .fontSize(10).fontColor($r('app.color.text_tertiary'))
              .maxLines(1).textOverflow({ overflow: TextOverflow.Ellipsis })
          }
        }.layoutWeight(1).alignItems(HorizontalAlign.Start)
        Button(this.currentTask.length > 0 ? '修改' : '+ 添加')
          .height(30).fontSize(11).borderRadius(15)
          .backgroundColor($r('app.color.ring_track'))
          .fontColor($r('app.color.text_secondary'))
          .onClick(() => this.openTaskEditor())
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 10, bottom: 10 })
      .margin({ top: 8 })
      .backgroundColor($r('app.color.surface'))
      .borderRadius(14)
      .border({ width: 1, color: $r('app.color.card_border') })

      // 环形计时区
      Column({ space: 0 }) {
        CircularProgress({
          progress: this.progressValue,
          remainingSeconds: this.remainingSeconds,
          totalSeconds: this.totalSeconds,
          isWorkMode: this.isWorkMode,
          isLongBreak: this.isLongBreak
        })

        TimerControls({
          isRunning: this.isRunning,
          isWorkMode: this.isWorkMode,
          onStartPause: () => this.onStartPause(),
          onReset: () => this.onReset(),
          onSkip: () => this.onSkipPhase()
        })
          .margin({ top: 28 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)

    // 今日专注 / 休息时长卡片
    Row({ space: 8 }) {
      Column({ space: 6 }) {
        Row({ space: 4 }) {
          Image($r('app.media.focus'))
            .width(12)
            .height(12)
            .fillColor($r('app.color.focus_color'))
          Text('专注')
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.focus_color'))
        }
        DurationDisplay({
          totalSeconds: this.todayWorkSeconds +
            (this.isWorkMode ? Math.max(0, this.totalSeconds - this.remainingSeconds) : 0)
        })
      }
      .layoutWeight(1)
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
      .backgroundColor($r('app.color.surface'))
      .borderRadius(14)
      .border({ width: 1, color: $r('app.color.card_border') })
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Row({ space: 4 }) {
          Image($r('app.media.rest'))
            .width(12)
            .height(12)
            .fillColor($r('app.color.rest_color'))
          Text('休息')
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.rest_color'))
        }
        DurationDisplay({
          totalSeconds: this.todayBreakSeconds +
            (!this.isWorkMode ? Math.max(0, this.totalSeconds - this.remainingSeconds) : 0)
        })
      }
      .layoutWeight(1)
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
      .backgroundColor($r('app.color.surface'))
      .borderRadius(14)
      .border({ width: 1, color: $r('app.color.card_border') })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .margin({ bottom: 8 })
    }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 48 })

    CelebrationOverlay({
      show: this.showCelebration,
      onDismiss: () => { this.showCelebration = false; }
    })
    this.taskEditorOverlay()
    this.endEarlyOverlay()
    }
  }

  build() {
    Tabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
      TabContent() {
        this.timerTab()
      }
      .tabBar(this.tabBarTimer)

      TabContent() {
        AiPlanner({
          active: this.currentTabIndex === 1,
          workMinutes: Math.max(1, Math.round(this.workDuration / 60)),
          breakMinutes: Math.max(1, Math.round(this.breakDuration / 60)),
          canApplyStep: !this.isRunning && this.remainingSeconds === this.totalSeconds,
          todayWorkSeconds: this.todayWorkSeconds,
          todayBreakSeconds: this.todayBreakSeconds,
          todayCompletedSessions: this.todayCount,
          dailyTarget: this.dailyTarget,
          currentTask: this.currentTask,
          currentProject: this.currentProject,
          currentTaskCompleted: this.currentTaskCompleted,
          currentTaskSource: this.currentTaskSource,
          currentTaskConversationId: this.currentTaskConversationId,
          onApplyStep: (step: AiPlanStep, conversationId: string) =>
            this.applyAiPlanStep(step, conversationId)
        })
      }
      .tabBar(this.tabBarAiPlanner)

      TabContent() {
        Insights({
          active: this.currentTabIndex === 2,
          onHistoryChanged: () => this.loadTodayStats()
        })
      }
      .tabBar(this.tabBarInsights)

      TabContent() {
        Settings({
          isDarkMode: this.isDarkMode,
          soundName: this.soundName,
          ambientName: this.ambientName,
          soundEnabled: this.soundEnabled,
          soundVolume: this.soundVolume,
          ambientVolume: this.ambientVolume,
          onThemeChange: (isDark: boolean) => this.onThemeChange(isDark),
          onSoundChange: (sound: string) => {
            this.soundName = sound;
            PreferencesHelper.saveSound(this.getContext(), sound);
          },
          onAmbientChange: (ambient: string) => {
            this.ambientName = ambient;
            PreferencesHelper.saveAmbient(this.getContext(), ambient);
            if (this.isRunning && this.isWorkMode) {
              AmbientHelper.stop().then(() => {
                if (ambient !== '') AmbientHelper.start(this.getContext(), ambient, this.ambientVolume);
              });
            }
          },
          onSoundEnabledChange: (enabled: boolean) => {
            this.soundEnabled = enabled;
            PreferencesHelper.saveSoundEnabled(this.getContext(), enabled);
          },
          onSoundVolumeChange: (volume: number) => {
            this.soundVolume = volume;
            PreferencesHelper.saveSoundVolume(this.getContext(), volume);
          },
          onAmbientVolumeChange: (volume: number) => {
            this.ambientVolume = volume;
            AmbientHelper.setVolume(volume);
            PreferencesHelper.saveAmbientVolume(this.getContext(), volume);
          },
          onSoundPreview: (sound: string) => this.playSelectedSound(sound),
          onAmbientPreview: (ambient: string) => this.previewAmbient(ambient),
          onSaved: async () => {
            await this.onNavigateToTimer();
            this.currentTabIndex = 0;
            this.tabsController.changeIndex(0);
          }
        })
      }
      .tabBar(this.tabBarSettings)
    }
    .barHeight(56)
    .barBackgroundColor($r('app.color.tab_bar_bg'))
    .barMode(BarMode.Fixed)
    .onChange((index: number) => {
      this.currentTabIndex = index;
      if (index === 0) {
        this.onNavigateToTimer();
      }
    })
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }
}

@Component
struct DurationDisplay {
  @Prop totalSeconds: number = 0;

  build() {
    Row({ space: 2 }) {
      if (Math.floor(this.totalSeconds / 3600) > 0) {
        Text(`${Math.floor(this.totalSeconds / 3600)}`)
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Text('h')
          .fontSize(18)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_tertiary'))
      }
      Text(`${Math.floor((this.totalSeconds % 3600) / 60)}`)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text('m')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_tertiary'))
      Text(`${this.totalSeconds % 60}`)
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
      Text('s')
        .fontSize(18)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_tertiary'))
    }
  }
}
