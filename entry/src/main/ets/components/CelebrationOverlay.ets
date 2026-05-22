@Component
export struct CelebrationOverlay {
  @Prop show: boolean = false;
  onDismiss?: () => void;

  build() {
    if (this.show) {
      Column() {
        Image($r('app.media.tomato'))
          .width(64)
          .height(64)
          .fillColor($r('app.color.primary_red'))
          .scale({ x: 1, y: 1 })
          .animation({ duration: 500, curve: Curve.EaseOut })

        Text('今日目标达成！')
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.primary_red'))
          .margin({ top: 12 })

        Text('太棒了，继续加油！')
          .fontSize(15)
          .fontColor($r('app.color.text_secondary'))
          .margin({ top: 6 })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)
      .backgroundColor($r('app.color.background'))
      .opacity(0.95)
      .onClick(() => {
        if (this.onDismiss) {
          this.onDismiss();
        }
      })
    }
  }
}
