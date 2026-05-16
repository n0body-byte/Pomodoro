import { PreferencesHelper, DailyStats } from '../utils/PreferencesHelper';

@Component
export struct Statistics {
  @State selectedTab: number = 0;
  @State dailyData: DailyStats[] = [];
  @State weeklyData: DailyStats[] = [];
  @State monthlyData: DailyStats[] = [];
  @State totalSeconds: number = 0;
  private retryCount: number = 0;

  async aboutToAppear(): Promise<void> {
    await this.loadAllStats();
  }

  async onPageShow(): Promise<void> {
    await this.loadAllStats();
  }

  private async loadAllStats(): Promise<void> {
    const ctx = this.getUIContext().getHostContext();
    if (ctx === undefined) {
      if (this.retryCount < 5) {
        this.retryCount += 1;
        setTimeout(() => this.loadAllStats(), 300);
      }
      return;
    }
    this.retryCount = 0;
    try {
      const daily = await PreferencesHelper.getStats(ctx, 7);
      const weekly = await PreferencesHelper.getStats(ctx, 28);
      const monthly = await PreferencesHelper.getStats(ctx, 180);
      this.dailyData = daily;
      this.weeklyData = weekly;
      this.monthlyData = monthly;
      let totalSeconds = 0;
      for (const s of monthly) {
        totalSeconds += s.totalSeconds;
      }
      this.totalSeconds = totalSeconds;
    } catch {
      // 加载失败静默处理
    }
  }

  private getActiveData(): DailyStats[] {
    if (this.selectedTab === 0) {
      return this.dailyData;
    } else if (this.selectedTab === 1) {
      return this.weeklyData;
    } else {
      return this.monthlyData;
    }
  }

  private getBarHeight(totalSeconds: number, maxSeconds: number): number {
    if (totalSeconds <= 0 || maxSeconds <= 0) {
      return 4;
    }
    const height = (totalSeconds / maxSeconds) * 180;
    return Math.max(4, height);
  }

  private getBarLabel(totalSeconds: number): string {
    if (totalSeconds <= 0) {
      return '';
    }
    if (totalSeconds < 60) {
      return `${totalSeconds}s`;
    }
    const minutes = Math.floor(totalSeconds / 60);
    if (minutes < 60) {
      return `${minutes}m`;
    }
    const hours = Math.floor(minutes / 60);
    const remain = minutes % 60;
    return remain === 0 ? `${hours}h` : `${hours}h${remain}m`;
  }

  private getTotalLabel(totalSeconds: number): string {
    if (totalSeconds === 0) {
      return '暂无数据';
    }
    if (totalSeconds < 60) {
      return `总计: ${totalSeconds} 秒`;
    }
    const minutes = Math.floor(totalSeconds / 60);
    if (minutes < 60) {
      return `总计: ${minutes} 分钟`;
    }
    const hours = Math.floor(minutes / 60);
    const remain = minutes % 60;
    return remain === 0 ? `总计: ${hours} 小时` : `总计: ${hours}小时${remain}分钟`;
  }

  private getMaxSeconds(data: DailyStats[]): number {
    let max = 1;
    for (const s of data) {
      if (s.totalSeconds > max) {
        max = s.totalSeconds;
      }
    }
    return max;
  }

  build() {
    Column() {
      Text($r('app.string.statistics_title'))
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ top: 8, bottom: 4, left: 8 })

      Row({ space: 8 }) {
        Button($r('app.string.tab_daily'))
          .fontSize($r('app.float.label_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.selectedTab === 0 ? Color.White : $r('app.color.text_secondary'))
          .backgroundColor(this.selectedTab === 0 ? $r('app.color.primary_red') : Color.Transparent)
          .borderRadius(18)
          .height(36)
          .layoutWeight(1)
          .onClick(() => { this.selectedTab = 0; })

        Button($r('app.string.tab_weekly'))
          .fontSize($r('app.float.label_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.selectedTab === 1 ? Color.White : $r('app.color.text_secondary'))
          .backgroundColor(this.selectedTab === 1 ? $r('app.color.primary_red') : Color.Transparent)
          .borderRadius(18)
          .height(36)
          .layoutWeight(1)
          .onClick(() => { this.selectedTab = 1; })

        Button($r('app.string.tab_monthly'))
          .fontSize($r('app.float.label_font_size'))
          .fontWeight(FontWeight.Medium)
          .fontColor(this.selectedTab === 2 ? Color.White : $r('app.color.text_secondary'))
          .backgroundColor(this.selectedTab === 2 ? $r('app.color.primary_red') : Color.Transparent)
          .borderRadius(18)
          .height(36)
          .layoutWeight(1)
          .onClick(() => { this.selectedTab = 2; })
      }
      .backgroundColor($r('app.color.ring_track'))
      .borderRadius(20)
      .padding(3)
      .width('90%')
      .margin({ top: 12, bottom: 16 })

      Column() {
        Row() {
          Text(this.getTotalLabel(this.totalSeconds))
            .fontSize($r('app.float.label_font_size'))
            .fontColor($r('app.color.text_secondary'))
            .fontWeight(FontWeight.Medium)
            .margin({ top: 8, bottom: 16 })
        }

        Scroll() {
          Row({ space: 6 }) {
            ForEach(this.getActiveData(), (item: DailyStats, index: number) => {
              Column({ space: 4 }) {
                Text(this.getBarLabel(item.totalSeconds))
                  .fontSize(10)
                  .fontColor($r('app.color.text_tertiary'))
                  .height(16)

                Column()
                  .width(32)
                  .height(this.getBarHeight(item.totalSeconds, this.getMaxSeconds(this.getActiveData())))
                  .backgroundColor(item.totalSeconds > 0 ? $r('app.color.primary_red') : $r('app.color.ring_track'))
                  .borderRadius(4)
                  .opacity(item.totalSeconds > 0 ? 1 : 0.5)
                  .animation({ duration: 600, curve: Curve.EaseOut })

                Text(item.date)
                  .fontSize(10)
                  .fontColor($r('app.color.text_tertiary'))
                  .constraintSize({ maxWidth: 52 })
                  .textAlign(TextAlign.Center)
              }
              .alignItems(HorizontalAlign.Center)
            }, (item: DailyStats) => item.date)
          }
          .alignItems(VerticalAlign.Bottom)
          .padding({ left: 12, right: 12 })
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .height(220)
        .width('100%')
      }
      .width('100%')
      .backgroundColor($r('app.color.surface'))
      .borderRadius(12)
      .padding({ top: 4, bottom: 12, left: 8, right: 8 })
      .shadow({ radius: 4, color: '#08000000', offsetY: 2 })
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
    .padding({ left: 8, right: 8 })
  }
}
