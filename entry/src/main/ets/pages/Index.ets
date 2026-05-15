import { router } from '@kit.ArkUI';
import { vibrator } from '@kit.SensorServiceKit';
import { notificationManager } from '@kit.NotificationKit';
import { CircularProgress } from '../components/CircularProgress';
import { TimerControls } from '../components/TimerControls';
import { SessionCounter } from '../components/SessionCounter';
import { PreferencesHelper } from '../utils/PreferencesHelper';
import {
  DEFAULT_WORK_SECONDS,
  DEFAULT_BREAK_SECONDS,
  DEFAULT_DAILY_TARGET,
  EXTEND_SECONDS,
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
  @State dailyTarget: number = DEFAULT_DAILY_TARGET;

  private timerId: number | null = null;
  private workDuration: number = DEFAULT_WORK_SECONDS;
  private breakDuration: number = DEFAULT_BREAK_SECONDS;
  private autoStart: boolean = false;
  private tickCount: number = 0;
  private navigatingAway: boolean = false;

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
    if (this.navigatingAway) {
      this.navigatingAway = false;
      return;
    }
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
      this.autoStart = await PreferencesHelper.loadAutoStart(this.getContext());
      this.dailyTarget = await PreferencesHelper.loadDailyTarget(this.getContext());
    } catch {
      this.workDuration = DEFAULT_WORK_SECONDS;
      this.breakDuration = DEFAULT_BREAK_SECONDS;
      this.autoStart = false;
      this.dailyTarget = DEFAULT_DAILY_TARGET;
    }
  }

  async loadTodayStats(): Promise<void> {
    try {
      this.todayCount = await PreferencesHelper.getTodaySessions(this.getContext());
    } catch {
      this.todayCount = 0;
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
      this.sendNotification(false);
      this.switchToWork();
    }

    if (this.autoStart) {
      setTimeout(() => {
        this.startTimer();
      }, 2000);
    }
  }

  recordSession(): void {
    const today = new Date();
    const dateStr = `${today.getFullYear()}-${(today.getMonth() + 1).toString().padStart(2, '0')}-${today.getDate().toString().padStart(2, '0')}`;
    PreferencesHelper.saveSessionRecord(this.getContext(), {
      date: dateStr,
      workSeconds: this.totalSeconds - this.remainingSeconds,
      completedAt: Date.now()
    }).then(() => this.loadTodayStats());
  }

  clearTodayData(): void {
    PreferencesHelper.clearTodaySessions(this.getContext()).then(() => {
      this.todayCount = 0;
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
    this.stopTimer();
    this.switchToWork();
  }

  onExtend(): void {
    this.totalSeconds += EXTEND_SECONDS;
    this.remainingSeconds += EXTEND_SECONDS;
    this.updateProgress();
  }

  onEndEarly(): void {
    this.stopTimer();
    this.completedSessions += 1;
    this.recordSession();
    this.sendNotification(true);
    this.switchToBreak();
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

  build() {
    Column() {
      Column({ space: 0 }) {
        CircularProgress({
          progress: this.progressValue,
          remainingSeconds: this.remainingSeconds,
          totalSeconds: this.totalSeconds,
          isWorkMode: this.isWorkMode
        })

        Row({ space: 8 }) {
          Row({ space: 8 }) {
            Text('🍅')
              .fontSize(16)
            Text(`${this.todayCount}/${this.dailyTarget}`)
              .fontSize($r('app.float.session_count_font_size'))
              .fontColor($r('app.color.text_secondary'))
              .fontWeight(FontWeight.Medium)
          }
          .padding({ left: 16, right: 16, top: 6, bottom: 6 })
          .backgroundColor($r('app.color.surface'))
          .borderRadius(12)

          if (this.todayCount > 0) {
            Button() {
              Text('清空')
                .fontSize(11)
                .fontColor($r('app.color.text_tertiary'))
            }
              .height(28)
              .backgroundColor(Color.Transparent)
              .border({ width: 1, color: $r('app.color.divider'), radius: 8 })
              .padding({ left: 10, right: 10 })
              .onClick(() => this.clearTodayData())
          }
        }
        .margin({ top: 20 })
        .shadow({ radius: 4, color: '#10000000', offsetY: 2 })

        if (this.isRunning) {
          Row({ space: 8 }) {
            if (!this.isWorkMode) {
              Button() {
                Text($r('app.string.btn_skip_break'))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.primary_red'))
              }
                .height(32)
                .backgroundColor('#FFF0F0')
                .borderRadius(16)
                .onClick(() => this.onSkipBreak())
            }

            Button() {
              Text($r('app.string.btn_extend'))
                .fontSize($r('app.float.caption_font_size'))
                .fontColor($r('app.color.primary_green'))
            }
              .height(32)
              .backgroundColor('#F0FFF4')
              .borderRadius(16)
              .onClick(() => this.onExtend())

            if (this.isWorkMode) {
              Button() {
                Text($r('app.string.btn_end_early'))
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_secondary'))
              }
                .height(32)
                .backgroundColor($r('app.color.ring_track'))
                .borderRadius(16)
                .onClick(() => this.onEndEarly())
            }
          }
          .justifyContent(FlexAlign.Center)
          .margin({ top: 16 })
          .animation({ duration: 200, curve: Curve.EaseInOut })
        }

        TimerControls({
          isRunning: this.isRunning,
          isWorkMode: this.isWorkMode,
          onStartPause: () => this.onStartPause(),
          onReset: () => this.onReset()
        })
          .margin({ top: 24 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)

      Row() {
        Button() {
          Row({ space: 4 }) {
            Text('⚙')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
            Text($r('app.string.btn_settings'))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
        }
          .backgroundColor(Color.Transparent)
          .borderRadius(20)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .onClick(() => {
            this.navigatingAway = true;
            this.saveCurrentState().then(() => {
              router.pushUrl({ url: 'pages/Settings' });
            });
          })

        Button() {
          Row({ space: 4 }) {
            Text('📊')
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
            Text($r('app.string.btn_statistics'))
              .fontSize($r('app.float.caption_font_size'))
              .fontColor($r('app.color.text_secondary'))
          }
        }
          .backgroundColor(Color.Transparent)
          .borderRadius(20)
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .onClick(() => {
            this.navigatingAway = true;
            this.saveCurrentState().then(() => {
              router.pushUrl({ url: 'pages/Statistics' });
            });
          })
      }
      .justifyContent(FlexAlign.SpaceEvenly)
      .width('100%')
      .padding({ top: 12, bottom: 28 })
      .backgroundColor($r('app.color.surface'))
      .shadow({ radius: 8, color: '#08000000', offsetY: -2 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }
}
