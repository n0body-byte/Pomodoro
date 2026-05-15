import { router } from '@kit.ArkUI';
import { PreferencesHelper } from '../utils/PreferencesHelper';
import { DEFAULT_WORK_SECONDS, DEFAULT_BREAK_SECONDS, DEFAULT_DAILY_TARGET } from '../common/Constants';

@Entry
@Component
struct Settings {
  @State workMinutes: number = 25;
  @State breakMinutes: number = 5;
  @State autoStart: boolean = false;
  @State dailyTarget: number = DEFAULT_DAILY_TARGET;

  async aboutToAppear(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext()!;
      const workSeconds = await PreferencesHelper.loadWorkDuration(ctx);
      const breakSeconds = await PreferencesHelper.loadBreakDuration(ctx);
      const autoStartVal = await PreferencesHelper.loadAutoStart(ctx);
      const targetVal = await PreferencesHelper.loadDailyTarget(ctx);
      this.workMinutes = Math.floor(workSeconds / 60);
      this.breakMinutes = Math.floor(breakSeconds / 60);
      this.autoStart = autoStartVal;
      this.dailyTarget = targetVal;
    } catch {
      this.workMinutes = Math.floor(DEFAULT_WORK_SECONDS / 60);
      this.breakMinutes = Math.floor(DEFAULT_BREAK_SECONDS / 60);
      this.autoStart = false;
      this.dailyTarget = DEFAULT_DAILY_TARGET;
    }
  }

  increaseWork(): void {
    if (this.workMinutes < 60) {
      this.workMinutes += 1;
    }
  }

  decreaseWork(): void {
    if (this.workMinutes > 1) {
      this.workMinutes -= 1;
    }
  }

  increaseBreak(): void {
    if (this.breakMinutes < 30) {
      this.breakMinutes += 1;
    }
  }

  decreaseBreak(): void {
    if (this.breakMinutes > 1) {
      this.breakMinutes -= 1;
    }
  }

  increaseTarget(): void {
    if (this.dailyTarget < 20) {
      this.dailyTarget += 1;
    }
  }

  decreaseTarget(): void {
    if (this.dailyTarget > 1) {
      this.dailyTarget -= 1;
    }
  }

  onSave(): void {
    const ctx = this.getUIContext().getHostContext()!;
    const workSeconds = this.workMinutes * 60;
    const breakSeconds = this.breakMinutes * 60;
    const autoStartVal = this.autoStart;
    const targetVal = this.dailyTarget;
    PreferencesHelper.saveWorkDuration(ctx, workSeconds)
      .then(() => PreferencesHelper.saveBreakDuration(ctx, breakSeconds))
      .then(() => PreferencesHelper.saveAutoStart(ctx, autoStartVal))
      .then(() => PreferencesHelper.saveDailyTarget(ctx, targetVal))
      .then(() => router.back())
      .catch(() => router.back());
  }

  build() {
    Column() {
      Row() {
        Button() {
          Text('←')
            .fontSize(20)
            .fontColor($r('app.color.text_primary'))
        }
          .backgroundColor(Color.Transparent)
          .width(40)
          .height(40)
          .borderRadius(20)
          .onClick(() => router.back())

        Text($r('app.string.settings_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
      }
      .width('100%')
      .justifyContent(FlexAlign.Start)
      .padding({ top: 48, bottom: 8, left: 8 })

      Column({ space: 0 }) {
        Row() {
          Text($r('app.string.work_duration_label'))
            .fontSize($r('app.float.button_font_size'))
            .fontColor($r('app.color.text_primary'))
          Blank()
          Row({ space: 10 }) {
            Button('-')
              .width(32)
              .height(32)
              .fontSize(16)
              .fontColor($r('app.color.text_secondary'))
              .backgroundColor($r('app.color.ring_track'))
              .borderRadius(16)
              .onClick(() => this.decreaseWork())
            Text(`${this.workMinutes}`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_red'))
              .constraintSize({ minWidth: 32 })
              .textAlign(TextAlign.Center)
            Button('+')
              .width(32)
              .height(32)
              .fontSize(16)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.primary_red'))
              .borderRadius(16)
              .onClick(() => this.increaseWork())
            Text($r('app.string.minutes_unit'))
              .fontSize($r('app.float.label_font_size'))
              .fontColor($r('app.color.text_tertiary'))
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })

        Divider()
          .color($r('app.color.divider'))
          .margin({ left: 16, right: 16 })

        Row() {
          Text($r('app.string.break_duration_label'))
            .fontSize($r('app.float.button_font_size'))
            .fontColor($r('app.color.text_primary'))
          Blank()
          Row({ space: 10 }) {
            Button('-')
              .width(32)
              .height(32)
              .fontSize(16)
              .fontColor($r('app.color.text_secondary'))
              .backgroundColor($r('app.color.ring_track'))
              .borderRadius(16)
              .onClick(() => this.decreaseBreak())
            Text(`${this.breakMinutes}`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_green'))
              .constraintSize({ minWidth: 32 })
              .textAlign(TextAlign.Center)
            Button('+')
              .width(32)
              .height(32)
              .fontSize(16)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.primary_green'))
              .borderRadius(16)
              .onClick(() => this.increaseBreak())
            Text($r('app.string.minutes_unit'))
              .fontSize($r('app.float.label_font_size'))
              .fontColor($r('app.color.text_tertiary'))
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })

        Divider()
          .color($r('app.color.divider'))
          .margin({ left: 16, right: 16 })

        Row() {
          Text($r('app.string.auto_start_label'))
            .fontSize($r('app.float.button_font_size'))
            .fontColor($r('app.color.text_primary'))
          Blank()
          Toggle({ type: ToggleType.Switch, isOn: this.autoStart })
            .selectedColor($r('app.color.primary_red'))
            .onChange((value: boolean) => {
              this.autoStart = value;
            })
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })

        Divider()
          .color($r('app.color.divider'))
          .margin({ left: 16, right: 16 })

        Row() {
          Text($r('app.string.daily_target_label'))
            .fontSize($r('app.float.button_font_size'))
            .fontColor($r('app.color.text_primary'))
          Blank()
          Row({ space: 10 }) {
            Button('-')
              .width(32)
              .height(32)
              .fontSize(16)
              .fontColor($r('app.color.text_secondary'))
              .backgroundColor($r('app.color.ring_track'))
              .borderRadius(16)
              .onClick(() => this.decreaseTarget())
            Text(`${this.dailyTarget}`)
              .fontSize(20)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_red'))
              .constraintSize({ minWidth: 32 })
              .textAlign(TextAlign.Center)
            Button('+')
              .width(32)
              .height(32)
              .fontSize(16)
              .fontColor(Color.White)
              .backgroundColor($r('app.color.primary_red'))
              .borderRadius(16)
              .onClick(() => this.increaseTarget())
            Text($r('app.string.daily_target_unit'))
              .fontSize($r('app.float.label_font_size'))
              .fontColor($r('app.color.text_tertiary'))
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      }
      .backgroundColor($r('app.color.surface'))
      .borderRadius(14)
      .margin({ left: 12, right: 12, top: 16 })
      .shadow({ radius: 6, color: '#10000000', offsetY: 2 })

      Blank()

      Button() {
        Text($r('app.string.btn_save'))
          .fontSize($r('app.float.button_font_size'))
          .fontColor(Color.White)
          .fontWeight(FontWeight.Medium)
      }
        .width('86%')
        .height(50)
        .backgroundColor($r('app.color.primary_red'))
        .borderRadius(25)
        .shadow({ radius: 12, color: '#40E74C3C', offsetY: 4 })
        .margin({ bottom: 32 })
        .onClick(() => this.onSave())
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }
}
