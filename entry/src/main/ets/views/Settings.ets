import { PreferencesHelper } from '../utils/PreferencesHelper';
import { DEFAULT_WORK_SECONDS, DEFAULT_BREAK_SECONDS, DEFAULT_DAILY_TARGET } from '../common/Constants';

@Component
export struct Settings {
  @State workMinutes: number = 25;
  @State breakMinutes: number = 5;
  @State dailyTarget: number = DEFAULT_DAILY_TARGET;
  @State autoStart: boolean = false;
  @Prop isDarkMode: boolean = true;
  @Prop soundName: string = 'bell';
  @Prop ambientName: string = '';
  onSaved?: () => void;
  onThemeChange?: (isDark: boolean) => void;
  onSoundChange?: (sound: string) => void;
  onAmbientChange?: (ambient: string) => void;

  async aboutToAppear(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext()!;
      const workSeconds = await PreferencesHelper.loadWorkDuration(ctx);
      const breakSeconds = await PreferencesHelper.loadBreakDuration(ctx);
      const targetVal = await PreferencesHelper.loadDailyTarget(ctx);
      const autoStartVal = await PreferencesHelper.loadAutoStart(ctx);
      this.workMinutes = Math.floor(workSeconds / 60);
      this.breakMinutes = Math.floor(breakSeconds / 60);
      this.dailyTarget = targetVal;
      this.autoStart = autoStartVal;
    } catch {
      this.workMinutes = Math.floor(DEFAULT_WORK_SECONDS / 60);
      this.breakMinutes = Math.floor(DEFAULT_BREAK_SECONDS / 60);
      this.dailyTarget = DEFAULT_DAILY_TARGET;
      this.autoStart = false;
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
    const targetVal = this.dailyTarget;
    PreferencesHelper.saveWorkDuration(ctx, workSeconds)
      .then(() => PreferencesHelper.saveBreakDuration(ctx, breakSeconds))
      .then(() => PreferencesHelper.saveDailyTarget(ctx, targetVal))
      .then(() => {
        if (this.onSaved) {
          this.onSaved();
        }
      })
      .catch(() => {
        if (this.onSaved) {
          this.onSaved();
        }
      });
  }

  build() {
    Column({ space: 0 }) {
      Text($r('app.string.settings_title'))
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ top: 8, bottom: 12, left: 8 })

      Scroll() {
      Column({ space: 10 }) {
        // 工作时长卡片
        Column() {
          Row() {
            Text($r('app.string.work_duration_label'))
              .fontSize($r('app.float.button_font_size'))
              .fontColor($r('app.color.text_primary'))
              .width(74)
            Blank()
            Row({ space: 10 }) {
              Button() {
                Image($r('app.media.minus'))
                  .width(16)
                  .height(16)
                  .fillColor($r('app.color.text_secondary'))
              }
                .width(32)
                .height(32)
                .backgroundColor($r('app.color.ring_track'))
                .borderRadius(16)
                .onClick(() => this.decreaseWork())
              Text(`${this.workMinutes}`)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.primary_red'))
                .width(36)
                .textAlign(TextAlign.Center)
              Button() {
                Image($r('app.media.plus'))
                  .width(16)
                  .height(16)
                  .fillColor(Color.White)
              }
                .width(32)
                .height(32)
                .backgroundColor($r('app.color.primary_red'))
                .borderRadius(16)
                .onClick(() => this.increaseWork())
              Text($r('app.string.minutes_unit'))
                .fontSize($r('app.float.label_font_size'))
                .fontColor($r('app.color.text_tertiary'))
                .width(28)
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        }
        .backgroundColor($r('app.color.surface'))
        .borderRadius(14)
        .shadow({ radius: 6, color: $r('app.color.shadow_surface'), offsetY: 2 })

        // 休息时长卡片
        Column() {
          Row() {
            Text($r('app.string.break_duration_label'))
              .fontSize($r('app.float.button_font_size'))
              .fontColor($r('app.color.text_primary'))
              .width(74)
            Blank()
            Row({ space: 10 }) {
              Button() {
                Image($r('app.media.minus'))
                  .width(16)
                  .height(16)
                  .fillColor($r('app.color.text_secondary'))
              }
                .width(32)
                .height(32)
                .backgroundColor($r('app.color.ring_track'))
                .borderRadius(16)
                .onClick(() => this.decreaseBreak())
              Text(`${this.breakMinutes}`)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.primary_green'))
                .width(36)
                .textAlign(TextAlign.Center)
              Button() {
                Image($r('app.media.plus'))
                  .width(16)
                  .height(16)
                  .fillColor(Color.White)
              }
                .width(32)
                .height(32)
                .backgroundColor($r('app.color.primary_green'))
                .borderRadius(16)
                .onClick(() => this.increaseBreak())
              Text($r('app.string.minutes_unit'))
                .fontSize($r('app.float.label_font_size'))
                .fontColor($r('app.color.text_tertiary'))
                .width(28)
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        }
        .backgroundColor($r('app.color.surface'))
        .borderRadius(14)
        .shadow({ radius: 6, color: $r('app.color.shadow_surface'), offsetY: 2 })

        // 每日目标卡片
        Column() {
          Row() {
            Text($r('app.string.daily_target_label'))
              .fontSize($r('app.float.button_font_size'))
              .fontColor($r('app.color.text_primary'))
              .width(74)
            Blank()
            Row({ space: 10 }) {
              Button() {
                Image($r('app.media.minus'))
                  .width(16)
                  .height(16)
                  .fillColor($r('app.color.text_secondary'))
              }
                .width(32)
                .height(32)
                .backgroundColor($r('app.color.ring_track'))
                .borderRadius(16)
                .onClick(() => this.decreaseTarget())
              Text(`${this.dailyTarget}`)
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.primary_red'))
                .width(36)
                .textAlign(TextAlign.Center)
              Button() {
                Image($r('app.media.plus'))
                  .width(16)
                  .height(16)
                  .fillColor(Color.White)
              }
                .width(32)
                .height(32)
                .backgroundColor($r('app.color.primary_red'))
                .borderRadius(16)
                .onClick(() => this.increaseTarget())
              Text($r('app.string.daily_target_unit'))
                .fontSize($r('app.float.label_font_size'))
                .fontColor($r('app.color.text_tertiary'))
                .width(28)
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        }
        .backgroundColor($r('app.color.surface'))
        .borderRadius(14)
        .shadow({ radius: 6, color: $r('app.color.shadow_surface'), offsetY: 2 })

        // 自动开始开关卡片
        Column() {
          Row() {
            Text($r('app.string.auto_start_label'))
              .fontSize($r('app.float.button_font_size'))
              .fontColor($r('app.color.text_primary'))
            Blank()
            Toggle({ type: ToggleType.Switch, isOn: this.autoStart })
              .selectedColor($r('app.color.primary_red'))
              .onChange((isOn: boolean) => {
                this.autoStart = isOn;
                const ctx = this.getUIContext().getHostContext()!;
                PreferencesHelper.saveAutoStart(ctx, isOn);
              })
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        }
        .backgroundColor($r('app.color.surface'))
        .borderRadius(14)
        .shadow({ radius: 6, color: $r('app.color.shadow_surface'), offsetY: 2 })

        // 主题切换卡片
        Column() {
          Row() {
            Text('主题')
              .fontSize($r('app.float.button_font_size'))
              .fontColor($r('app.color.text_primary'))
            Blank()
            Row({ space: 8 }) {
              Button('浅色')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.isDarkMode ? $r('app.color.text_secondary') : Color.White)
                .backgroundColor(this.isDarkMode ? $r('app.color.ring_track') : $r('app.color.primary_red'))
                .height(32)
                .borderRadius(16)
                .padding({ left: 14, right: 14 })
                .onClick(() => {
                  if (this.onThemeChange) {
                    this.onThemeChange(false);
                  }
                })
              Button('深色')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(this.isDarkMode ? Color.White : $r('app.color.text_secondary'))
                .backgroundColor(this.isDarkMode ? $r('app.color.primary_red') : $r('app.color.ring_track'))
                .height(32)
                .borderRadius(16)
                .padding({ left: 14, right: 14 })
                .onClick(() => {
                  if (this.onThemeChange) {
                    this.onThemeChange(true);
                  }
                })
            }
          }
          .width('100%')
          .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        }
        .backgroundColor($r('app.color.surface'))
        .borderRadius(14)
        .shadow({ radius: 6, color: $r('app.color.shadow_surface'), offsetY: 2 })

        // 提示音选择卡片
        Column({ space: 8 }) {
          Text('提示音')
            .fontSize($r('app.float.button_font_size'))
            .fontColor($r('app.color.text_primary'))
            .width('100%')
          Row({ space: 6 }) {
            SoundOption({ label: '钟铃', value: 'bell', current: this.soundName, onSelect: (v: string) => { if (this.onSoundChange) this.onSoundChange(v); } })
            SoundOption({ label: '风铃', value: 'chime', current: this.soundName, onSelect: (v: string) => { if (this.onSoundChange) this.onSoundChange(v); } })
            SoundOption({ label: '短促', value: 'beep', current: this.soundName, onSelect: (v: string) => { if (this.onSoundChange) this.onSoundChange(v); } })
            SoundOption({ label: '双响', value: 'double_beep', current: this.soundName, onSelect: (v: string) => { if (this.onSoundChange) this.onSoundChange(v); } })
            SoundOption({ label: '叮咚', value: 'ding', current: this.soundName, onSelect: (v: string) => { if (this.onSoundChange) this.onSoundChange(v); } })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        .backgroundColor($r('app.color.surface'))
        .borderRadius(14)
        .shadow({ radius: 6, color: $r('app.color.shadow_surface'), offsetY: 2 })

        // 白噪音卡片
        Column({ space: 8 }) {
          Text('白噪音')
            .fontSize($r('app.float.button_font_size'))
            .fontColor($r('app.color.text_primary'))
            .width('100%')
          Row({ space: 6 }) {
            AmbientOption({ label: '关闭', value: '', current: this.ambientName, onSelect: (v: string) => { if (this.onAmbientChange) this.onAmbientChange(v); } })
            AmbientOption({ label: '雨声', value: 'rain', current: this.ambientName, onSelect: (v: string) => { if (this.onAmbientChange) this.onAmbientChange(v); } })
            AmbientOption({ label: '咖啡馆', value: 'cafe', current: this.ambientName, onSelect: (v: string) => { if (this.onAmbientChange) this.onAmbientChange(v); } })
            AmbientOption({ label: '森林', value: 'forest', current: this.ambientName, onSelect: (v: string) => { if (this.onAmbientChange) this.onAmbientChange(v); } })
          }
        }
        .width('100%')
        .padding({ left: 16, right: 16, top: 14, bottom: 14 })
        .backgroundColor($r('app.color.surface'))
        .borderRadius(14)
        .shadow({ radius: 6, color: $r('app.color.shadow_surface'), offsetY: 2 })
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 16 })
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .width('100%')

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
        .shadow({ radius: 16, color: $r('app.color.shadow_button'), offsetY: 6 })
        .margin({ bottom: 12 })
        .onClick(() => this.onSave())
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }
}

@Component
struct SoundOption {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop current: string = '';
  onSelect?: (value: string) => void;

  build() {
    Text(this.label)
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.current === this.value ? Color.White : $r('app.color.text_secondary'))
      .backgroundColor(this.current === this.value ? $r('app.color.primary_red') : $r('app.color.ring_track'))
      .borderRadius(12)
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .onClick(() => {
        if (this.onSelect) {
          this.onSelect(this.value);
        }
      })
  }
}

@Component
struct AmbientOption {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop current: string = '';
  onSelect?: (value: string) => void;

  build() {
    Text(this.label)
      .fontSize(11)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.current === this.value ? Color.White : $r('app.color.text_secondary'))
      .backgroundColor(this.current === this.value ? $r('app.color.primary_red') : $r('app.color.ring_track'))
      .borderRadius(12)
      .padding({ left: 10, right: 10, top: 6, bottom: 6 })
      .onClick(() => {
        if (this.onSelect) {
          this.onSelect(this.value);
        }
      })
  }
}
