import { PreferencesHelper } from '../utils/PreferencesHelper';
import { DEFAULT_WORK_SECONDS, DEFAULT_BREAK_SECONDS, DEFAULT_DAILY_TARGET } from '../common/Constants';

@Component
export struct Settings {
  @State workMinutes: number = 25;
  @State breakMinutes: number = 5;
  @State longBreakMinutes: number = 15;
  @State longBreakInterval: number = 4;
  @State dailyTarget: number = DEFAULT_DAILY_TARGET;
  @State autoStartWork: boolean = false;
  @State autoStartBreak: boolean = false;
  @State presetName: string = 'classic';
  @Prop isDarkMode: boolean = true;
  @Prop soundName: string = 'bell';
  @Prop ambientName: string = '';
  @Prop soundEnabled: boolean = true;
  @Prop soundVolume: number = 0.8;
  @Prop ambientVolume: number = 0.5;
  onSaved?: () => void;
  onThemeChange?: (isDark: boolean) => void;
  onSoundChange?: (sound: string) => void;
  onAmbientChange?: (ambient: string) => void;
  onSoundEnabledChange?: (enabled: boolean) => void;
  onSoundVolumeChange?: (volume: number) => void;
  onAmbientVolumeChange?: (volume: number) => void;
  onSoundPreview?: (sound: string) => void;
  onAmbientPreview?: (ambient: string) => void;

  async aboutToAppear(): Promise<void> {
    try {
      const ctx = this.getUIContext().getHostContext()!;
      const workSeconds = await PreferencesHelper.loadWorkDuration(ctx);
      const breakSeconds = await PreferencesHelper.loadBreakDuration(ctx);
      const longBreakSeconds = await PreferencesHelper.loadLongBreakDuration(ctx);
      this.workMinutes = Math.floor(workSeconds / 60);
      this.breakMinutes = Math.floor(breakSeconds / 60);
      this.longBreakMinutes = Math.floor(longBreakSeconds / 60);
      this.longBreakInterval = await PreferencesHelper.loadLongBreakInterval(ctx);
      this.dailyTarget = await PreferencesHelper.loadDailyTarget(ctx);
      this.autoStartWork = await PreferencesHelper.loadAutoStartWork(ctx);
      this.autoStartBreak = await PreferencesHelper.loadAutoStartBreak(ctx);
      this.presetName = await PreferencesHelper.loadTimerPreset(ctx);
    } catch {
      this.workMinutes = Math.floor(DEFAULT_WORK_SECONDS / 60);
      this.breakMinutes = Math.floor(DEFAULT_BREAK_SECONDS / 60);
      this.longBreakMinutes = 15;
      this.longBreakInterval = 4;
      this.dailyTarget = DEFAULT_DAILY_TARGET;
      this.autoStartWork = false;
      this.autoStartBreak = false;
      this.presetName = 'classic';
    }
  }

  private increaseWork(): void {
    if (this.workMinutes < 60) {
      this.workMinutes += 1;
      this.presetName = 'custom';
    }
  }

  private decreaseWork(): void {
    if (this.workMinutes > 1) {
      this.workMinutes -= 1;
      this.presetName = 'custom';
    }
  }

  private increaseBreak(): void {
    if (this.breakMinutes < 30) {
      this.breakMinutes += 1;
      this.presetName = 'custom';
    }
  }

  private decreaseBreak(): void {
    if (this.breakMinutes > 1) {
      this.breakMinutes -= 1;
      this.presetName = 'custom';
    }
  }

  private increaseTarget(): void {
    if (this.dailyTarget < 20) {
      this.dailyTarget += 1;
    }
  }

  private decreaseTarget(): void {
    if (this.dailyTarget > 1) {
      this.dailyTarget -= 1;
    }
  }

  private selectPreset(name: string): void {
    this.presetName = name;
    if (name === 'classic') {
      this.workMinutes = 25;
      this.breakMinutes = 5;
      this.longBreakMinutes = 15;
    } else if (name === 'deep') {
      this.workMinutes = 50;
      this.breakMinutes = 10;
      this.longBreakMinutes = 20;
    } else if (name === 'quick') {
      this.workMinutes = 15;
      this.breakMinutes = 3;
      this.longBreakMinutes = 10;
    }
  }

  private changeLongBreak(delta: number): void {
    this.longBreakMinutes = Math.max(5, Math.min(45, this.longBreakMinutes + delta));
    this.presetName = 'custom';
  }

  private changeLongBreakInterval(delta: number): void {
    this.longBreakInterval = Math.max(2, Math.min(8, this.longBreakInterval + delta));
  }

  private changeAutoStartBreak(enabled: boolean): void {
    this.autoStartBreak = enabled;
    const ctx = this.getUIContext().getHostContext()!;
    PreferencesHelper.saveAutoStartBreak(ctx, enabled);
  }

  private changeAutoStartWork(enabled: boolean): void {
    this.autoStartWork = enabled;
    const ctx = this.getUIContext().getHostContext()!;
    PreferencesHelper.saveAutoStartWork(ctx, enabled);
  }

  private selectSound(sound: string): void {
    if (this.onSoundChange) {
      this.onSoundChange(sound);
    }
    if (this.onSoundPreview) {
      this.onSoundPreview(sound);
    }
  }

  private selectAmbient(ambient: string): void {
    if (this.onAmbientChange) {
      this.onAmbientChange(ambient);
    }
  }

  private onSave(): void {
    const ctx = this.getUIContext().getHostContext()!;
    PreferencesHelper.saveWorkDuration(ctx, this.workMinutes * 60)
      .then(() => PreferencesHelper.saveBreakDuration(ctx, this.breakMinutes * 60))
      .then(() => PreferencesHelper.saveLongBreakDuration(ctx, this.longBreakMinutes * 60))
      .then(() => PreferencesHelper.saveLongBreakInterval(ctx, this.longBreakInterval))
      .then(() => PreferencesHelper.saveDailyTarget(ctx, this.dailyTarget))
      .then(() => PreferencesHelper.saveTimerPreset(ctx, this.presetName))
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

  @Builder
  private sectionTitle(title: string, description: string) {
    Column({ space: 3 }) {
      Text(title)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
      Text(description)
        .fontSize($r('app.float.caption_font_size'))
        .fontColor($r('app.color.text_tertiary'))
        .width('100%')
    }
    .width('100%')
  }

  build() {
    Column() {
      Column({ space: 3 }) {
        Text($r('app.string.settings_title'))
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        Text('打造适合你的专注节奏')
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
      }
      .width('100%')
      .padding({ left: 20, right: 20, top: 8, bottom: 12 })

      Scroll() {
        Column({ space: 14 }) {
          Column({ space: 14 }) {
            Row() {
              this.sectionTitle('计时方案', '一键切换常用的专注与休息组合')
              if (this.presetName === 'custom') {
                Text('已自定义')
                  .fontSize(10)
                  .fontColor($r('app.color.primary_red'))
                  .backgroundColor($r('app.color.ring_track'))
                  .borderRadius(10)
                  .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              }
            }
            .width('100%')

            Row({ space: 8 }) {
              OptionChip({
                label: '经典 25/5', value: 'classic', current: this.presetName,
                onSelect: (value: string) => this.selectPreset(value)
              }).layoutWeight(1)
              OptionChip({
                label: '深度 50/10', value: 'deep', current: this.presetName,
                onSelect: (value: string) => this.selectPreset(value)
              }).layoutWeight(1)
              OptionChip({
                label: '轻量 15/3', value: 'quick', current: this.presetName,
                onSelect: (value: string) => this.selectPreset(value)
              }).layoutWeight(1)
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.card_border') })
          .borderRadius(18)
          .shadow({ radius: 6, color: $r('app.color.shadow_surface'), offsetY: 2 })

          Column() {
            Column() {
              this.sectionTitle('时间与目标', '调整一次完整番茄循环的节奏')
            }
            .padding({ left: 16, right: 16, top: 16, bottom: 8 })

            SettingStepperRow({
              label: '专注时长', description: '单次保持专注的时间',
              value: this.workMinutes, unit: '分钟',
              onDecrease: () => this.decreaseWork(), onIncrease: () => this.increaseWork()
            })
            Divider().color($r('app.color.card_border')).margin({ left: 16, right: 16 })
            SettingStepperRow({
              label: '短休息', description: '每次专注后的恢复时间',
              value: this.breakMinutes, unit: '分钟', activeGreen: true,
              onDecrease: () => this.decreaseBreak(), onIncrease: () => this.increaseBreak()
            })
            Divider().color($r('app.color.card_border')).margin({ left: 16, right: 16 })
            SettingStepperRow({
              label: '长休息', description: '完成若干番茄后的休息',
              value: this.longBreakMinutes, unit: '分钟', activeGreen: true,
              onDecrease: () => this.changeLongBreak(-5), onIncrease: () => this.changeLongBreak(5)
            })
            Divider().color($r('app.color.card_border')).margin({ left: 16, right: 16 })
            SettingStepperRow({
              label: '长休息间隔', description: '连续完成多少个番茄后触发',
              value: this.longBreakInterval, unit: '个',
              onDecrease: () => this.changeLongBreakInterval(-1),
              onIncrease: () => this.changeLongBreakInterval(1)
            })
            Divider().color($r('app.color.card_border')).margin({ left: 16, right: 16 })
            SettingStepperRow({
              label: '每日目标', description: '每天计划完成的番茄数',
              value: this.dailyTarget, unit: '个',
              onDecrease: () => this.decreaseTarget(), onIncrease: () => this.increaseTarget()
            })
          }
          .width('100%')
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.card_border') })
          .borderRadius(18)
          .shadow({ radius: 6, color: $r('app.color.shadow_surface'), offsetY: 2 })

          Column() {
            Column() {
              this.sectionTitle('自动衔接', '减少手动操作，保持工作节奏')
            }
            .padding({ left: 16, right: 16, top: 16, bottom: 6 })

            SettingToggleRow({
              label: '专注结束后自动休息', description: '计时完成后直接进入休息',
              isOn: this.autoStartBreak,
              onChange: (enabled: boolean) => this.changeAutoStartBreak(enabled)
            })
            Divider().color($r('app.color.card_border')).margin({ left: 16, right: 16 })
            SettingToggleRow({
              label: '休息结束后自动专注', description: '休息完成后开始下一轮',
              isOn: this.autoStartWork, activeGreen: true,
              onChange: (enabled: boolean) => this.changeAutoStartWork(enabled)
            })
          }
          .width('100%')
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.card_border') })
          .borderRadius(18)
          .shadow({ radius: 6, color: $r('app.color.shadow_surface'), offsetY: 2 })

          Column({ space: 14 }) {
            this.sectionTitle('外观', '选择更适合当前环境的显示模式')
            Row({ space: 8 }) {
              OptionChip({
                label: '浅色模式', value: 'light', current: this.isDarkMode ? 'dark' : 'light',
                onSelect: () => {
                  if (this.onThemeChange) {
                    this.onThemeChange(false);
                  }
                }
              }).layoutWeight(1)
              OptionChip({
                label: '深色模式', value: 'dark', current: this.isDarkMode ? 'dark' : 'light',
                onSelect: () => {
                  if (this.onThemeChange) {
                    this.onThemeChange(true);
                  }
                }
              }).layoutWeight(1)
            }
            .width('100%')
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.card_border') })
          .borderRadius(18)
          .shadow({ radius: 6, color: $r('app.color.shadow_surface'), offsetY: 2 })

          Column({ space: 14 }) {
            Row() {
              Column({ space: 3 }) {
                Text('提示音')
                  .fontSize(17)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                Text('完成计时时播放，点击选项可试听')
                  .fontSize($r('app.float.caption_font_size'))
                  .fontColor($r('app.color.text_tertiary'))
              }
              .layoutWeight(1)
              Toggle({ type: ToggleType.Switch, isOn: this.soundEnabled })
                .selectedColor($r('app.color.primary_red'))
                .onChange((enabled: boolean) => {
                  if (this.onSoundEnabledChange) {
                    this.onSoundEnabledChange(enabled);
                  }
                })
            }
            .width('100%')

            Column({ space: 8 }) {
              Row({ space: 8 }) {
                OptionChip({ label: '钟铃', value: 'bell', current: this.soundName,
                  onSelect: (value: string) => this.selectSound(value) }).layoutWeight(1)
                OptionChip({ label: '风铃', value: 'chime', current: this.soundName,
                  onSelect: (value: string) => this.selectSound(value) }).layoutWeight(1)
                OptionChip({ label: '短音', value: 'beep', current: this.soundName,
                  onSelect: (value: string) => this.selectSound(value) }).layoutWeight(1)
              }
              .width('100%')
              Row({ space: 8 }) {
                OptionChip({ label: '双响', value: 'double_beep', current: this.soundName,
                  onSelect: (value: string) => this.selectSound(value) }).layoutWeight(1)
                OptionChip({ label: '叮咚', value: 'ding', current: this.soundName,
                  onSelect: (value: string) => this.selectSound(value) }).layoutWeight(1)
                Blank().layoutWeight(1)
              }
              .width('100%')
            }

            Row() {
              Text('提示音量')
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
              Blank()
              Text(`${Math.round(this.soundVolume * 100)}%`)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.primary_red'))
            }
            .width('100%')
            Slider({ value: this.soundVolume * 100, min: 0, max: 100, step: 5 })
              .selectedColor($r('app.color.primary_red'))
              .onChange((value: number) => {
                if (this.onSoundVolumeChange) {
                  this.onSoundVolumeChange(value / 100);
                }
              })
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.card_border') })
          .borderRadius(18)
          .shadow({ radius: 6, color: $r('app.color.shadow_surface'), offsetY: 2 })

          Column({ space: 14 }) {
            this.sectionTitle('白噪音', '用持续环境声减少分心')
            Row({ space: 8 }) {
              OptionChip({ label: '关闭', value: '', current: this.ambientName, activeGreen: true,
                onSelect: (value: string) => this.selectAmbient(value) }).layoutWeight(1)
              OptionChip({ label: '雨声', value: 'rain', current: this.ambientName, activeGreen: true,
                onSelect: (value: string) => this.selectAmbient(value) }).layoutWeight(1)
              OptionChip({ label: '咖啡馆', value: 'cafe', current: this.ambientName, activeGreen: true,
                onSelect: (value: string) => this.selectAmbient(value) }).layoutWeight(1)
              OptionChip({ label: '森林', value: 'forest', current: this.ambientName, activeGreen: true,
                onSelect: (value: string) => this.selectAmbient(value) }).layoutWeight(1)
            }
            .width('100%')

            Row() {
              Text('环境音量')
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
              Blank()
              Text(`${Math.round(this.ambientVolume * 100)}%`)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.primary_green'))
            }
            .width('100%')
            Slider({ value: this.ambientVolume * 100, min: 0, max: 100, step: 5 })
              .selectedColor($r('app.color.primary_green'))
              .onChange((value: number) => {
                if (this.onAmbientVolumeChange) {
                  this.onAmbientVolumeChange(value / 100);
                }
              })

            if (this.ambientName !== '') {
              Button('试听 3 秒')
                .width('100%')
                .height(38)
                .fontSize(13)
                .fontWeight(FontWeight.Medium)
                .backgroundColor($r('app.color.ring_track'))
                .fontColor($r('app.color.text_secondary'))
                .borderRadius(19)
                .onClick(() => {
                  if (this.onAmbientPreview) {
                    this.onAmbientPreview(this.ambientName);
                  }
                })
            }
          }
          .width('100%')
          .padding(16)
          .backgroundColor($r('app.color.surface'))
          .border({ width: 1, color: $r('app.color.card_border') })
          .borderRadius(18)
          .shadow({ radius: 6, color: $r('app.color.shadow_surface'), offsetY: 2 })
        }
        .width('100%')
        .padding({ left: 12, right: 12, top: 4, bottom: 20 })
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
      .width('92%')
      .height(50)
      .backgroundColor($r('app.color.primary_red'))
      .borderRadius(25)
      .shadow({ radius: 16, color: $r('app.color.shadow_button'), offsetY: 6 })
      .margin({ top: 4, bottom: 12 })
      .onClick(() => this.onSave())
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
  }
}

@Component
struct SettingStepperRow {
  @Prop label: string = '';
  @Prop description: string = '';
  @Prop value: number = 0;
  @Prop unit: string = '';
  @Prop activeGreen: boolean = false;
  onDecrease?: () => void;
  onIncrease?: () => void;

  build() {
    Row({ space: 8 }) {
      Column({ space: 3 }) {
        Text(this.label)
          .fontSize($r('app.float.label_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        Text(this.description)
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .layoutWeight(1)

      Row({ space: 4 }) {
        Button() {
          Image($r('app.media.minus'))
            .width(15)
            .height(15)
            .fillColor($r('app.color.text_secondary'))
        }
          .width(32)
          .height(32)
          .backgroundColor($r('app.color.ring_track'))
          .borderRadius(16)
          .onClick(() => {
            if (this.onDecrease) {
              this.onDecrease();
            }
          })
        Column({ space: 0 }) {
          Text(`${this.value}`)
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.activeGreen ? $r('app.color.primary_green') : $r('app.color.primary_red'))
          Text(this.unit)
            .fontSize(10)
            .fontColor($r('app.color.text_tertiary'))
        }
        .width(48)
        Button() {
          Image($r('app.media.plus'))
            .width(15)
            .height(15)
            .fillColor(Color.White)
        }
          .width(32)
          .height(32)
          .backgroundColor(this.activeGreen ? $r('app.color.primary_green') : $r('app.color.primary_red'))
          .borderRadius(16)
          .onClick(() => {
            if (this.onIncrease) {
              this.onIncrease();
            }
          })
      }
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }
}

@Component
struct SettingToggleRow {
  @Prop label: string = '';
  @Prop description: string = '';
  @Prop isOn: boolean = false;
  @Prop activeGreen: boolean = false;
  onChange?: (enabled: boolean) => void;

  build() {
    Row({ space: 12 }) {
      Column({ space: 3 }) {
        Text(this.label)
          .fontSize($r('app.float.label_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
          .width('100%')
        Text(this.description)
          .fontSize(11)
          .fontColor($r('app.color.text_tertiary'))
          .width('100%')
      }
      .layoutWeight(1)
      Toggle({ type: ToggleType.Switch, isOn: this.isOn })
        .selectedColor(this.activeGreen ? $r('app.color.primary_green') : $r('app.color.primary_red'))
        .onChange((enabled: boolean) => {
          if (this.onChange) {
            this.onChange(enabled);
          }
        })
    }
    .width('100%')
    .padding({ left: 16, right: 16, top: 12, bottom: 12 })
  }
}

@Component
struct OptionChip {
  @Prop label: string = '';
  @Prop value: string = '';
  @Prop current: string = '';
  @Prop activeGreen: boolean = false;
  onSelect?: (value: string) => void;

  build() {
    Text(this.label)
      .fontSize(12)
      .fontWeight(FontWeight.Medium)
      .fontColor(this.current === this.value ? Color.White : $r('app.color.text_secondary'))
      .textAlign(TextAlign.Center)
      .width('100%')
      .height(36)
      .backgroundColor(this.current === this.value ?
        (this.activeGreen ? $r('app.color.primary_green') : $r('app.color.primary_red')) :
        $r('app.color.ring_track'))
      .borderRadius(18)
      .onClick(() => {
        if (this.onSelect) {
          this.onSelect(this.value);
        }
      })
  }
}
