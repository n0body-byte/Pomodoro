import { vibrator } from '@kit.SensorServiceKit';
import { notificationManager } from '@kit.NotificationKit';
import { CircularProgress } from '../components/CircularProgress';
import { TimerControls } from '../components/TimerControls';
import { PreferencesHelper } from '../utils/PreferencesHelper';
import { Settings } from '../views/Settings';
import { Statistics } from '../views/Statistics';
import {
  DEFAULT_WORK_SECONDS,
  DEFAULT_BREAK_SECONDS,
  DEFAULT_DAILY_TARGET,
  VIBRATION_DURATION_MS,
  NOTIFICATION_WORK_END_ID,
  NOTIFICATION_BREAK_END_ID,
  NOTIFICATION_ONGOING_ID,
  NOTIFICATION_UPDATE_INTERVAL
} from '../common/Constants';

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

  private timerId: number | null = null;
  private workDuration: number = DEFAULT_WORK_SECONDS;
  private breakDuration: number = DEFAULT_BREAK_SECONDS;
  private tickCount: number = 0;
  private tabsController: TabsController = new TabsController();

  async aboutToAppear(): Promise<void> {
    await this.loadSettings();
    this.completedSessions = 0;
    this.todayCount = 0;
    this.remainingSeconds = this.workDuration;
    this.totalSeconds = this.workDuration;
    this.updateProgress();
  }

  aboutToDisappear(): void {
    this.cancelOngoingNotification();
    this.stopTimer();
  }

  async onPageShow(): Promise<void> {
    await this.loadTodayStats();
    await this.recoverFromBackground();
  }

  async onPageHide(): Promise<void> {
    await this.saveCurrentState();
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

  startTimer(): void {
    if (this.timerId !== null) {
      return;
    }
    this.isRunning = true;
    this.tickCount = 0;
    this.publishOngoingNotification();
    this.timerId = setInterval(() => {
      this.tick();
    }, 1000);
  }

  stopTimer(): void {
    if (this.timerId !== null) {
      clearInterval(this.timerId);
      this.timerId = null;
    }
    this.isRunning = false;
    this.cancelOngoingNotification();
  }

  tick(): void {
    this.remainingSeconds -= 1;
    this.updateProgress();
    this.tickCount += 1;

    if (this.tickCount % NOTIFICATION_UPDATE_INTERVAL === 0) {
      this.publishOngoingNotification();
    }

    if (this.remainingSeconds <= 0) {
      this.handleTimerComplete();
    }
  }

  handleTimerComplete(): void {
    this.stopTimer();

    if (this.isWorkMode) {
      this.completedSessions += 1;
      this.recordSession();
      this.sendNotification(true);
      this.switchToBreak();
    } else {
      this.recordBreakSession();
      this.sendNotification(false);
      this.switchToWork();
    }

    setTimeout(() => {
      this.startTimer();
    }, 2000);
  }

  private getTodayStr(): string {
    const today = new Date();
    return `${today.getFullYear()}-${(today.getMonth() + 1).toString().padStart(2, '0')}-${today.getDate().toString().padStart(2, '0')}`;
  }

  recordSession(): void {
    PreferencesHelper.saveSessionRecord(this.getContext(), {
      date: this.getTodayStr(),
      workSeconds: this.totalSeconds - this.remainingSeconds,
      completedAt: Date.now(),
      type: 'work'
    }).then(() => this.loadTodayStats());
  }

  recordBreakSession(): void {
    const breakSeconds = this.totalSeconds - this.remainingSeconds;
    if (breakSeconds > 0) {
      PreferencesHelper.saveSessionRecord(this.getContext(), {
        date: this.getTodayStr(),
        workSeconds: breakSeconds,
        completedAt: Date.now(),
        type: 'break'
      }).then(() => this.loadTodayStats());
    }
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
    } else {
      this.startTimer();
    }
  }

  onReset(): void {
    this.stopTimer();
    this.remainingSeconds = this.totalSeconds;
    this.updateProgress();
  }

  onSkipBreak(): void {
    this.recordBreakSession();
    this.stopTimer();
    this.switchToWork();
    setTimeout(() => {
      this.startTimer();
    }, 2000);
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

  onEndEarly(): void {
    this.stopTimer();
    this.completedSessions += 1;
    this.recordSession();
    this.sendNotification(true);
    this.switchToBreak();
    setTimeout(() => {
      this.startTimer();
    }, 2000);
  }

  sendNotification(isWorkEnd: boolean): void {
    try {
      const request: notificationManager.NotificationRequest = {
        id: isWorkEnd ? NOTIFICATION_WORK_END_ID : NOTIFICATION_BREAK_END_ID,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: '番茄钟',
            text: isWorkEnd ? '工作时间结束，休息一下吧！' : '休息时间结束，开始工作吧！'
          }
        }
      };
      notificationManager.publish(request);

      vibrator.startVibration({
        type: 'time',
        duration: VIBRATION_DURATION_MS
      }, {
        usage: 'alarm'
      });
    } catch {
      // 通知或振动失败时静默处理
    }
  }

  publishOngoingNotification(): void {
    try {
      const minutes = Math.floor(this.remainingSeconds / 60).toString().padStart(2, '0');
      const seconds = (this.remainingSeconds % 60).toString().padStart(2, '0');
      const request: notificationManager.NotificationRequest = {
        id: NOTIFICATION_ONGOING_ID,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: '番茄钟计时中',
            text: `${this.isWorkMode ? '工作中' : '休息中'} ${minutes}:${seconds}`
          }
        }
      };
      notificationManager.publish(request);
    } catch {
      // 发布失败静默处理
    }
  }

  cancelOngoingNotification(): void {
    try {
      notificationManager.cancel(NOTIFICATION_ONGOING_ID);
    } catch {
      // 取消失败静默处理
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
        savedAt: Date.now()
      });
    } catch {
      // 保存失败静默处理
    }
  }

  async recoverFromBackground(): Promise<void> {
    try {
      const state = await PreferencesHelper.loadTimerState(this.getContext());
      if (state !== null && state.isRunning) {
        const elapsed = Math.floor((Date.now() - state.savedAt) / 1000);
        const adjusted = state.remainingSeconds - elapsed;
        this.totalSeconds = state.totalSeconds;
        this.isWorkMode = state.isWorkMode;
        this.completedSessions = state.completedSessions;
        if (adjusted <= 0) {
          this.remainingSeconds = 0;
          this.handleTimerComplete();
        } else {
          this.remainingSeconds = adjusted;
          this.isRunning = false;
          this.updateProgress();
        }
        return;
      }
    } catch {
      // 恢复失败静默处理
    }
    await this.loadSettings();
    this.totalSeconds = this.isWorkMode ? this.workDuration : this.breakDuration;
    this.remainingSeconds = this.totalSeconds;
    this.updateProgress();
  }

  @Builder
  durationDisplay(totalSeconds: number) {
    if (totalSeconds <= 0) {
      Row({ space: 2 }) {
        Text('0')
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
        Text('m')
          .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#636366')
      }
    } else {
      Row({ space: 2 }) {
        if (Math.floor(totalSeconds / 3600) > 0) {
          Text(`${Math.floor(totalSeconds / 3600)}`)
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          Text('h')
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#636366')
        }
        if (Math.floor((totalSeconds % 3600) / 60) > 0 || Math.floor(totalSeconds / 3600) === 0) {
          Text(`${Math.floor((totalSeconds % 3600) / 60)}`)
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#FFFFFF')
          Text('m')
            .fontSize(18).fontWeight(FontWeight.Bold).fontColor('#636366')
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
        .fillColor(this.currentTabIndex === 0 ? '#39FF14' : '#FFFFFF')
      Text('计时')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.currentTabIndex === 0 ? '#39FF14' : '#FFFFFF')
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
        .fillColor(this.currentTabIndex === 1 ? '#39FF14' : '#FFFFFF')
      Text('设置')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.currentTabIndex === 1 ? '#39FF14' : '#FFFFFF')
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
        .fillColor(this.currentTabIndex === 2 ? '#39FF14' : '#FFFFFF')
      Text('统计')
        .fontSize(10)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.currentTabIndex === 2 ? '#39FF14' : '#FFFFFF')
    }
    .alignItems(HorizontalAlign.Center)
    .justifyContent(FlexAlign.Center)
    .width('100%')
    .height('100%')
  }

  @Builder
  timerTab() {
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
            .fontColor('#8E8E93')
            .letterSpacing(3)
        }
        .width('100%')

        Row({ space: 3 }) {
          ForEach(this.getCapsuleIndices(), (i: number) => {
            Column()
              .layoutWeight(1)
              .height(18)
              .borderRadius(2.5)
              .backgroundColor(i < this.todayCount ? '#FA2E69' : '#2C2C2E')
          }, (i: number) => i.toString())
        }
        .width('100%')

        Row({ space: 8 }) {
          Text(`${this.todayCount}/${this.dailyTarget}`)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')

          if (this.todayCount > 0) {
            Button() {
              Text('清空')
                .fontSize(10)
                .fontColor('#636366')
            }
              .height(24)
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: '#38383A', radius: 6 })
              .padding({ left: 8, right: 8 })
              .onClick(() => this.clearTodayData())
          }
        }
        .width('100%')
        .justifyContent(FlexAlign.SpaceBetween)
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 14, bottom: 14 })
      .backgroundColor('#1C1C1E')
      .borderRadius(18)
      .border({ width: 1, color: '#1FFFFFFF' })

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
            .fillColor('#FA2E69')
          Text('专注')
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor('#FA2E69')
        }
        this.durationDisplay(this.todayWorkSeconds)
      }
      .layoutWeight(1)
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
      .backgroundColor('#1C1C1E')
      .borderRadius(14)
      .border({ width: 1, color: '#1FFFFFFF' })
      .alignItems(HorizontalAlign.Start)

      Column({ space: 6 }) {
        Row({ space: 4 }) {
          Image($r('app.media.rest'))
            .width(12)
            .height(12)
            .fillColor('#65FE08')
          Text('休息')
            .fontSize(10)
            .fontWeight(FontWeight.Medium)
            .fontColor('#65FE08')
        }
        this.durationDisplay(this.todayBreakSeconds)
      }
      .layoutWeight(1)
      .padding({ left: 14, right: 14, top: 12, bottom: 12 })
      .backgroundColor('#1C1C1E')
      .borderRadius(14)
      .border({ width: 1, color: '#1FFFFFFF' })
      .alignItems(HorizontalAlign.Start)
    }
    .width('100%')
    .margin({ bottom: 8 })
  }
    .width('100%')
    .height('100%')
    .padding({ left: 20, right: 20, top: 48 })
  }

  build() {
    Tabs({ barPosition: BarPosition.End, controller: this.tabsController }) {
      TabContent() {
        this.timerTab()
      }
      .tabBar(this.tabBarTimer)

      TabContent() {
        Settings({ onSaved: async () => {
          await this.onNavigateToTimer();
          this.currentTabIndex = 0;
          this.tabsController.changeIndex(0);
        } })
      }
      .tabBar(this.tabBarSettings)

      TabContent() {
        Statistics()
      }
      .tabBar(this.tabBarStatistics)
    }
    .barHeight(56)
    .barBackgroundColor('#1C1C1E')
    .barMode(BarMode.Fixed)
    .onChange((index: number) => {
      this.currentTabIndex = index;
      if (index === 0) {
        this.onNavigateToTimer();
      }
    })
    .width('100%')
    .height('100%')
    .backgroundColor('#000000')
  }
}
