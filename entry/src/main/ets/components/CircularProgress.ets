@Component
export struct CircularProgress {
  @Prop progress: number = 100;
  @Prop remainingSeconds: number = 0;
  @Prop totalSeconds: number = 1;
  @Prop isWorkMode: boolean = true;

  private formatMinutes(): string {
    return Math.floor(this.remainingSeconds / 60).toString().padStart(2, '0');
  }

  private formatSeconds(): string {
    return (this.remainingSeconds % 60).toString().padStart(2, '0');
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      // 轨道环 — 同色系 15% 透明度
      Progress({
        value: 100,
        total: 100,
        type: ProgressType.Ring
      })
        .width(280)
        .height(280)
        .color(this.isWorkMode ? '#FA2E69' : '#65FE08')
        .opacity(0.15)
        .style({ strokeWidth: $r('app.float.ring_stroke_width'), scaleCount: 1, scaleWidth: 0 })

      // 前景进度环 — 弹簧动画
      Progress({
        value: this.progress,
        total: 100,
        type: ProgressType.Ring
      })
        .width(280)
        .height(280)
        .color(this.isWorkMode ? '#FA2E69' : '#65FE08')
        .style({ strokeWidth: $r('app.float.ring_stroke_width'), scaleCount: 1, scaleWidth: 0 })
        .animation({ duration: 1200, curve: Curve.EaseOut })

      // 居中时间 — 等宽数字 + 冒号 30% 透明度
      Column({ space: 0 }) {
        Row({ space: 0 }) {
          Text(this.formatMinutes())
            .fontSize(68)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .fontFamily('monospace')
            .letterSpacing(-2)

          Text(':')
            .fontSize(68)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .fontFamily('monospace')
            .opacity(0.3)
            .letterSpacing(-2)

          Text(this.formatSeconds())
            .fontSize(68)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
            .fontFamily('monospace')
            .letterSpacing(-2)
        }

        Text(this.isWorkMode ? '专注' : '休息')
          .fontSize(11)
          .fontColor(this.isWorkMode ? '#FA2E69' : '#65FE08')
          .fontWeight(FontWeight.Bold)
          .letterSpacing(4)
          .margin({ top: 2 })
      }
    }
    .padding(8)
  }
}
