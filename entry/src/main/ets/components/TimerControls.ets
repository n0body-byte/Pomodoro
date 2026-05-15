@Component
export struct TimerControls {
  @Prop isRunning: boolean = false;
  @Prop isWorkMode: boolean = true;
  onStartPause: () => void = () => {};
  onReset: () => void = () => {};

  build() {
    Row({ space: 16 }) {
      Button() {
        Row({ space: 8 }) {
          Text(this.isRunning ? '⏸' : '▶')
            .fontSize(16)
          Text(this.isRunning ? $r('app.string.btn_pause') : $r('app.string.btn_start'))
            .fontSize($r('app.float.button_font_size'))
            .fontWeight(FontWeight.Medium)
        }
      }
        .width(160)
        .height(52)
        .fontColor(Color.White)
        .backgroundColor(this.isWorkMode ? $r('app.color.primary_red') : $r('app.color.primary_green'))
        .borderRadius(26)
        .shadow({
          radius: 12,
          color: this.isWorkMode ? '#40E74C3C' : '#4027AE60',
          offsetY: 4
        })
        .onClick(() => this.onStartPause())

      Button() {
        Text('↺')
          .fontSize(20)
          .fontColor($r('app.color.text_secondary'))
      }
        .width(48)
        .height(48)
        .backgroundColor($r('app.color.ring_track'))
        .borderRadius(24)
        .onClick(() => this.onReset())
    }
    .justifyContent(FlexAlign.Center)
  }
}
