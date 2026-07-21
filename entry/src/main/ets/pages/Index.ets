import { ConfigurationConstant } from '@kit.AbilityKit';
import { CircularProgress } from '../components/CircularProgress';
import { TimerControls } from '../components/TimerControls';
import { CelebrationOverlay } from '../components/CelebrationOverlay';
import { PreferencesHelper } from '../utils/PreferencesHelper';
import { SoundHelper } from '../utils/SoundHelper';
import { AmbientHelper } from '../utils/AmbientHelper';
import { NotificationHelper } from '../utils/NotificationHelper';
import { TimerHelper } from '../utils/TimerHelper';
import { Settings } from '../views/Settings';
import { Statistics } from '../views/Statistics';
import { Achievements } from '../views/Achievements';
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
  @State autoStartNext: boolean = false;
  @State ambientName: string = '';
  @State showCelebration: boolean = false;

  private timerId: number | null = null;
  private workDuration: number = DEFAULT_WORK_SECONDS;
  private breakDuration: number = DEFAULT_BREAK_SECONDS;
  private tickCount: number = 0;
  private deadlineAt: number = 0;
  private autoStartTimerId: number | null = null;
  private isCompleting: boolean = false;
  private tabsController: TabsController = new TabsController();

  async aboutToAppear(): Promise<void> {
    const ctx = this.getContext();
    await NotificationHelper.requestPermission();
    this.isDarkMode = await PreferencesHelper.loadTheme(ctx);
    this.soundName = await PreferencesHelper.loadSound(ctx);
    this.autoStartNext = await PreferencesHelper.loadAutoStart(ctx);
    this.ambientName = await PreferencesHelper.loadAmbient(ctx);
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
    } catch {
      this.workDuration = DEFAULT_WORK_SECONDS;
      this.breakDuration = DEFAULT_BREAK_SECONDS;
      this.dailyTarget = DEFAULT_DAILY_TARGET;
    }
  }

  async loadTodayStats(): Promise<void> {
    try {
      this.todayCount = await PreferencesHelper.getTodaySessions(this.getContext());
      this.todayWorkSeconds = await PreferencesHelper.getTodayWorkSeconds(this.getContext());
      this.todayBreakSeconds = await PreferencesHelper.getTodayBreakSeconds(this.getContext());
    } catch {
      this.todayCount = 0;
      this.todayWorkSeconds = 0;
      this.todayBreakSeconds = 0;
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
      AmbientHelper.start(this.getContext(), this.ambientName);
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

    SoundHelper.play(this.getContext(), this.soundName);

    if (completedWorkMode) {
      this.completedSessions += 1;
      NotificationHelper.sendEndNotification(true);
      this.switchToBreak();
    } else {
      NotificationHelper.sendEndNotification(false);
      this.switchToWork();
    }

    if (this.autoStartNext) {
      this.scheduleAutoStart();
    }

    try {
      await this.persistPhaseRecord(completedWorkMode, completedDuration, completedDuration,
        completedAt, 'completed');
      await this.loadTodayStats();
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
    completedAt: number, status: 'completed' | 'abandoned' | 'skipped'): Promise<void> {
    if (actualSeconds <= 0) {
      return;
    }
    try {
      await PreferencesHelper.saveSessionRecord(this.getContext(), {
        date: this.getDateStr(completedAt),
        workSeconds: Math.min(actualSeconds, plannedSeconds),
        completedAt: completedAt,
        type: isWorkMode ? 'work' : 'break',
        status: status,
        plannedSeconds: plannedSeconds
      });
    } catch {
      // 单次记录失败不阻塞计时状态切换。
    }
  }

  triggerCelebration(): void {
    this.showCelebration = true;
    SoundHelper.play(this.getContext(), 'celebration');
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
    this.totalSeconds = this.workDuration;
    this.remainingSeconds = this.workDuration;
    this.updateProgress();
  }

  switchToBreak(): void {
    this.isWorkMode = false;
    this.totalSeconds = this.breakDuration;
    this.remainingSeconds = this.breakDuration;
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
    SoundHelper.play(this.getContext(), this.soundName);
    this.switchToWork();
    if (this.autoStartNext) {
      this.scheduleAutoStart();
    }
    await this.persistPhaseRecord(false, actualSeconds, plannedSeconds, Date.now(), 'skipped');
    await this.loadTodayStats();
    await this.saveCurrentState();
  }

  onSkipPhase(): void {
    if (!this.isRunning) {
      return;
    }
    if (this.isWorkMode) {
      this.onEndEarly();
    } else {
      this.onSkipBreak();
    }
  }

  async onEndEarly(): Promise<void> {
    const plannedSeconds = this.totalSeconds;
    this.stopTimer();
    const actualSeconds = Math.max(0, plannedSeconds - this.remainingSeconds);
    SoundHelper.play(this.getContext(), this.soundName);
    this.switchToBreak();
    if (this.autoStartNext) {
      this.scheduleAutoStart();
    }
    await this.persistPhaseRecord(true, actualSeconds, plannedSeconds, Date.now(), 'abandoned');
    await this.loadTodayStats();
    await this.saveCurrentState();
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
        deadlineAt: this.isRunning ? this.deadlineAt : 0
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

          phaseWorkMode = !phaseWorkMode;
          phaseDuration = phaseWorkMode ? this.workDuration : this.breakDuration;
          recoveredPhases += 1;

          if (!this.autoStartNext) {
            this.isWorkMode = phaseWorkMode;
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

  @Builder
  durationDisplay(totalSeconds: number) {
    if (totalSeconds <= 0) {
      Row({ space: 2 }) {
        Text('0')
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
        Text('m')
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_tertiary'))
      }
    } else {
      Row({ space: 2 }) {
        if (Math.floor(totalSeconds / 3600) > 0) {
          Text(`${Math.floor(totalSeconds / 3600)}`)
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
          Text('h')
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_tertiary'))
        }
        if (Math.floor((totalSeconds % 3600) / 60) > 0 || Math.floor(totalSeconds / 3600) === 0) {
          Text(`${Math.floor((totalSeconds % 3600) / 60)}`)
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
          Text('m')
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor($r('app.color.text_tertiary'))
        }
      }
    }
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
    this.autoStartNext = await PreferencesHelper.loadAutoStart(this.getContext());
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
  tabBarSettings() {
    Column({ space: 1 }) {
      Image($r('app.media.settings'))
        .width(18)
        .height(18)
        .fillColor(this.currentTabIndex === 1 ? $r('app.color.tab_selected') : $r('app.color.tab_unselected'))
      Text('设置')
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
  tabBarStatistics() {
    Column({ space: 1 }) {
      Image($r('app.media.statistics'))
        .width(18)
        .height(18)
        .fillColor(this.currentTabIndex === 2 ? $r('app.color.tab_selected') : $r('app.color.tab_unselected'))
      Text('统计')
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
  tabBarAchievements() {
    Column({ space: 1 }) {
      Image($r('app.media.achievement'))
        .width(18)
        .height(18)
        .fillColor(this.currentTabIndex === 3 ? $r('app.color.tab_selected') : $r('app.color.tab_unselected'))
      Text('成就')
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

      // 环形计时区
      Column({ space: 0 }) {
        CircularProgress({
          progress: this.progressValue,
          remainingSeconds: this.remainingSeconds,
          totalSeconds: this.totalSeconds,
          isWorkMode: this.isWorkMode
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
        this.durationDisplay(this.todayWorkSeconds)
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
        this.durationDisplay(this.todayBreakSeconds)
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
    }
  }

  build() {
    Tabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
      TabContent() {
        this.timerTab()
      }
      .tabBar(this.tabBarTimer)

      TabContent() {
        Settings({
          isDarkMode: this.isDarkMode,
          soundName: this.soundName,
          ambientName: this.ambientName,
          onThemeChange: (isDark: boolean) => this.onThemeChange(isDark),
          onSoundChange: (sound: string) => {
            this.soundName = sound;
            PreferencesHelper.saveSound(this.getContext(), sound);
          },
          onAmbientChange: (ambient: string) => {
            this.ambientName = ambient;
            PreferencesHelper.saveAmbient(this.getContext(), ambient);
          },
          onSaved: async () => {
            await this.onNavigateToTimer();
            this.currentTabIndex = 0;
            this.tabsController.changeIndex(0);
          }
        })
      }
      .tabBar(this.tabBarSettings)

      TabContent() {
        Statistics()
      }
      .tabBar(this.tabBarStatistics)

      TabContent() {
        Achievements({ active: this.currentTabIndex === 3 })
      }
      .tabBar(this.tabBarAchievements)
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
