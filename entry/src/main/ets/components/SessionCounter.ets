@Component
export struct SessionCounter {
  @Prop count: number = 0;

  build() {
    Row({ space: 4 }) {
      Text('🍅')
        .fontSize(18)
      Text(`已完成: ${this.count} 个番茄`)
        .fontSize($r('app.float.session_count_font_size'))
        .fontColor($r('app.color.text_secondary'))
    }
    .justifyContent(FlexAlign.Center)
    .padding({ top: 16, bottom: 8 })
  }
}
