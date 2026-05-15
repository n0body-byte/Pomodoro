@Component
export struct CircularProgress {
  @Prop progress: number = 100;
  @Prop remainingSeconds: number = 0;
  @Prop totalSeconds: number = 1;
  @Prop isWorkMode: boolean = true;

  formatTime(totalSeconds: number): string {
    const minutes = Math.floor(totalSeconds / 60).toString().padStart(2, '0');
    const seconds = (totalSeconds % 60).toString().padStart(2, '0');
    return `${minutes}:${seconds}`;
  }

  build() {
    Stack({ alignContent: Alignment.Center }) {
      Progress({
        value: 100,
        total: 100,
        type: ProgressType.Ring
      })
        .width(280)
        .height(280)
        .color($r('app.color.ring_track'))
        .style({ strokeWidth: $r('app.float.ring_stroke_width'), scaleCount: 1, scaleWidth: 0 })

      Progress({
        value: this.progress,
        total: 100,
        type: ProgressType.Ring
      })
        .width(280)
        .height(280)
        .color(this.isWorkMode ? $r('app.color.primary_red') : $r('app.color.primary_green'))
        .style({ strokeWidth: $r('app.float.ring_stroke_width'), scaleCount: 1, scaleWidth: 0 })
        .animation({ duration: 1000, curve: Curve.EaseInOut })

      Column({ space: 2 }) {
        Text('剩余时间')
          .fontSize($r('app.float.caption_font_size'))
          .fontColor($r('app.color.text_tertiary'))
          .letterSpacing(2)
          .margin({ bottom: 4 })

        Text(this.formatTime(this.remainingSeconds))
          .fontSize($r('app.float.timer_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
          .fontFamily('monospace')

        Text(this.isWorkMode ? '工作中' : '休息中')
          .fontSize($r('app.float.label_font_size'))
          .fontColor(this.isWorkMode ? $r('app.color.primary_red') : $r('app.color.primary_green'))
          .fontWeight(FontWeight.Medium)
          .margin({ top: 6 })
          .padding({ left: 16, right: 16, top: 4, bottom: 4 })
          .borderRadius(10)
          .backgroundColor(this.isWorkMode ? '#FFF0F0' : '#F0FFF4')
      }
    }
    .padding(8)
  }
}
