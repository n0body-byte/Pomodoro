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
          .fontColor('#8E8E93')
      }
        .width(44)
        .height(44)
        .backgroundColor('#2C2C2E')
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
        Text(this.isRunning ? '⏸' : '▶')
          .fontSize(32)
          .fontColor(this.isWorkMode ? '#FA2E69' : '#65FE08')
      }
        .width(80)
        .height(80)
        .backgroundColor('#1C1C1E')
        .borderRadius(40)
        .border({ width: 3, color: this.isWorkMode ? '#FA2E69' : '#65FE08' })
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
          .fontColor('#8E8E93')
      }
        .width(44)
        .height(44)
        .backgroundColor('#2C2C2E')
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
