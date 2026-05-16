@Component
export struct TimerControls {
  @Prop isRunning: boolean = false;
  @Prop isWorkMode: boolean = true;
  onStartPause: () => void = () => {};
  onReset: () => void = () => {};
  onSkip: () => void = () => {};
  @State private mainPressed: boolean = false;
  @State private resetPressed: boolean = false;
  @State private skipPressed: boolean = false;

  build() {
    Row({ space: 16 }) {
      // 重置
      Button() {
        Text('↺')
          .fontSize(18)
          .fontColor($r('app.color.text_secondary'))
      }
        .width(44)
        .height(44)
        .backgroundColor($r('app.color.ring_track'))
        .borderRadius(22)
        .scale({ x: this.resetPressed ? 0.9 : 1, y: this.resetPressed ? 0.9 : 1 })
        .animation({ duration: 150, curve: Curve.EaseOut })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.resetPressed = true;
          } else if (event.type === TouchType.Up) {
            this.resetPressed = false;
            this.onReset();
          }
        })

      // 开始/暂停
      Button() {
        Image($r(this.isRunning ? 'app.media.pause' : 'app.media.start'))
          .width(32)
          .height(32)
          .fillColor(this.isWorkMode ? $r('app.color.primary_red') : $r('app.color.primary_green'))
      }
        .width(80)
        .height(80)
        .backgroundColor($r('app.color.main_button_bg'))
        .borderRadius(40)
        .border({ width: 3, color: this.isWorkMode ? $r('app.color.primary_red') : $r('app.color.primary_green') })
        .scale({ x: this.mainPressed ? 0.92 : 1, y: this.mainPressed ? 0.92 : 1 })
        .animation({ duration: 150, curve: Curve.EaseOut })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.mainPressed = true;
          } else if (event.type === TouchType.Up) {
            this.mainPressed = false;
            this.onStartPause();
          }
        })

      // 跳过/提前结束
      Button() {
        Text('→')
          .fontSize(18)
          .fontColor($r('app.color.text_secondary'))
      }
        .width(44)
        .height(44)
        .backgroundColor($r('app.color.ring_track'))
        .borderRadius(22)
        .scale({ x: this.skipPressed ? 0.9 : 1, y: this.skipPressed ? 0.9 : 1 })
        .animation({ duration: 150, curve: Curve.EaseOut })
        .onTouch((event: TouchEvent) => {
          if (event.type === TouchType.Down) {
            this.skipPressed = true;
          } else if (event.type === TouchType.Up) {
            this.skipPressed = false;
            this.onSkip();
          }
        })
    }
    .justifyContent(FlexAlign.Center)
  }
}
