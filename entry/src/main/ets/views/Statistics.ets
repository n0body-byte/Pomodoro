import { PreferencesHelper, DailyStats, SessionRecord } from '../utils/PreferencesHelper';
import {
  FocusActionInsight,
  FocusInsightHelper,
  FocusInsightRecord
} from '../utils/FocusInsightHelper';

@Component
export struct Statistics {
  @Prop @Watch('onActiveChange') active: boolean = false;
  @State selectedTab: number = 0;
  @State dailyData: DailyStats[] = [];
  @State weeklyData: DailyStats[] = [];
  @State monthlyData: DailyStats[] = [];
  @State totalSeconds: number = 0;
  @State avgSeconds: number = 0;
  @State maxSeconds: number = 0;
  @State sessionCount: number = 0;
  @State focusInsight: FocusActionInsight = FocusInsightHelper.empty();
  private hostCtx: Context | null = null;

  async aboutToAppear(): Promise<void> {
    await this.loadAllStats();
  }

  async onPageShow(): Promise<void> {
    await this.loadAllStats();
  }

  async onActiveChange(): Promise<void> {
    if (this.active) {
      await this.loadAllStats();
    }
  }

  private getContext(): Context | null {
    const ctx = this.getUIContext().getHostContext();
    return ctx !== undefined ? ctx : null;
  }

  private async loadAllStats(): Promise<void> {
    const ctx = this.getContext();
    if (ctx === null) {
      setTimeout(() => this.loadAllStats(), 200);
      return;
    }
    try {
      const daily = await PreferencesHelper.getStats(ctx, 7);
      const weekly = await PreferencesHelper.getWeeklyStats(ctx, 4);
      const monthly = await PreferencesHelper.getMonthlyStats(ctx, 6);
      const history = await PreferencesHelper.loadSessionHistory(ctx);
      this.dailyData = daily;
      this.weeklyData = weekly;
      this.monthlyData = monthly;
      const insightRecords: FocusInsightRecord[] = [];
      for (const record of history) {
        insightRecords.push(this.toInsightRecord(record));
      }
      this.focusInsight = FocusInsightHelper.analyze(insightRecords);

      const active = this.getActiveData();
      let total = 0;
      let max = 0;
      let count = 0;
      for (const s of active) {
        total += s.totalSeconds;
        if (s.totalSeconds > max) {
          max = s.totalSeconds;
        }
        if (s.totalSeconds > 0) {
          count += 1;
        }
      }
      this.totalSeconds = total;
      this.maxSeconds = max;
      this.avgSeconds = count > 0 ? Math.floor(total / count) : 0;
      this.sessionCount = count;
    } catch {
      // 加载失败静默处理
    }
  }

  private toInsightRecord(record: SessionRecord): FocusInsightRecord {
    return {
      workSeconds: record.workSeconds,
      completedAt: record.completedAt,
      type: record.type,
      plannedSeconds: record.plannedSeconds,
      focusRating: record.focusRating,
      energyRating: record.energyRating,
      interruptionReason: record.interruptionReason
    };
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
      return 0;
    }
    const height = (totalSeconds / maxSeconds) * 160;
    return Math.max(0, height);
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
      return '0 分钟';
    }
    if (totalSeconds < 60) {
      return `${totalSeconds} 秒`;
    }
    const minutes = Math.floor(totalSeconds / 60);
    if (minutes < 60) {
      return `${minutes} 分钟`;
    }
    const hours = Math.floor(minutes / 60);
    const remain = minutes % 60;
    return remain === 0 ? `${hours} 小时` : `${hours} 小时 ${remain} 分钟`;
  }

  private getTodayStr(): string {
    const today = new Date();
    return `${today.getMonth() + 1}/${today.getDate()}`;
  }

  private isToday(date: string): boolean {
    return date === this.getTodayStr();
  }

  private getAccuracyLabel(): string {
    return this.focusInsight.estimatedSessions > 0 ?
      `${this.focusInsight.estimateAccuracyPercent}%` : '待积累';
  }

  private getFocusLabel(): string {
    return this.focusInsight.reflectedSessions > 0 ?
      `${this.focusInsight.averageFocusRating}/5` : '待复盘';
  }

  private getTrendLabel(): string {
    if (this.focusInsight.trendStatus === 'new') return '开始积累';
    if (this.focusInsight.trendStatus === 'steady') return '基本持平';
    if (this.focusInsight.trendStatus === 'up') return `↑ ${this.focusInsight.trendPercent}%`;
    if (this.focusInsight.trendStatus === 'down') return `↓ ${Math.abs(this.focusInsight.trendPercent)}%`;
    return '暂无';
  }

  private getTrendColor(): ResourceColor {
    if (this.focusInsight.trendStatus === 'up' || this.focusInsight.trendStatus === 'new') {
      return $r('app.color.primary_green');
    }
    if (this.focusInsight.trendStatus === 'down') {
      return $r('app.color.primary_red');
    }
    return $r('app.color.accent_yellow');
  }

  private getCoverageColor(): ResourceColor {
    return this.focusInsight.reflectionCoveragePercent >= 60 ?
      $r('app.color.primary_green') : $r('app.color.accent_yellow');
  }

  @Builder
  private insightMetric(label: string, value: string, color: ResourceColor) {
    Column({ space: 3 }) {
      Text(label).fontSize(9).fontColor($r('app.color.text_tertiary'))
      Text(value).fontSize(15).fontWeight(FontWeight.Bold).fontColor(color)
    }
    .layoutWeight(1).alignItems(HorizontalAlign.Start)
  }

  @Builder
  private insightQualityMetric(label: string, value: string, description: string, color: ResourceColor) {
    Column({ space: 3 }) {
      Text(label).fontSize(9).fontColor($r('app.color.text_tertiary')).width('100%')
      Text(value).fontSize(13).fontWeight(FontWeight.Bold).fontColor(color).width('100%')
      Text(description).fontSize(8).fontColor($r('app.color.text_tertiary')).width('100%')
    }
    .layoutWeight(1).alignItems(HorizontalAlign.Start)
    .padding(9).backgroundColor($r('app.color.ring_track')).borderRadius(9)
  }

  build() {
    Column() {
      Text($r('app.string.statistics_title'))
        .fontSize($r('app.float.title_font_size')).fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary')).width('100%')
        .padding({ top: 8, bottom: 4, left: 8 })

      Row({ space: 8 }) {
        Button($r('app.string.tab_daily')).layoutWeight(1).height(36).borderRadius(18)
          .fontSize($r('app.float.label_font_size')).fontWeight(FontWeight.Medium)
          .fontColor(this.selectedTab === 0 ? Color.White : $r('app.color.text_secondary'))
          .backgroundColor(this.selectedTab === 0 ? $r('app.color.primary_red') : Color.Transparent)
          .onClick(() => { this.selectedTab = 0; this.loadAllStats(); })
        Button($r('app.string.tab_weekly')).layoutWeight(1).height(36).borderRadius(18)
          .fontSize($r('app.float.label_font_size')).fontWeight(FontWeight.Medium)
          .fontColor(this.selectedTab === 1 ? Color.White : $r('app.color.text_secondary'))
          .backgroundColor(this.selectedTab === 1 ? $r('app.color.primary_red') : Color.Transparent)
          .onClick(() => { this.selectedTab = 1; this.loadAllStats(); })
        Button($r('app.string.tab_monthly')).layoutWeight(1).height(36).borderRadius(18)
          .fontSize($r('app.float.label_font_size')).fontWeight(FontWeight.Medium)
          .fontColor(this.selectedTab === 2 ? Color.White : $r('app.color.text_secondary'))
          .backgroundColor(this.selectedTab === 2 ? $r('app.color.primary_red') : Color.Transparent)
          .onClick(() => { this.selectedTab = 2; this.loadAllStats(); })
      }
      .backgroundColor($r('app.color.ring_track')).borderRadius(20).padding(3)
      .width('90%').margin({ top: 12, bottom: 12 })

      Scroll() {
        Column({ space: 12 }) {
          Column({ space: 8 }) {
            Row() {
              Column({ space: 2 }) {
                Text('总专注').fontSize(10).fontColor($r('app.color.text_tertiary'))
                Text(this.getTotalLabel(this.totalSeconds)).fontSize(20).fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.primary_red'))
              }.layoutWeight(1).alignItems(HorizontalAlign.Start)
              Column({ space: 2 }) {
                Text('日均').fontSize(10).fontColor($r('app.color.text_tertiary'))
                Text(this.getTotalLabel(this.avgSeconds)).fontSize(20).fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.daily_target'))
              }.layoutWeight(1).alignItems(HorizontalAlign.Center)
              Column({ space: 2 }) {
                Text('活跃天数').fontSize(10).fontColor($r('app.color.text_tertiary'))
                Text(`${this.sessionCount}`).fontSize(20).fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.primary_green'))
              }.layoutWeight(1).alignItems(HorizontalAlign.End)
            }.width('100%')
            Divider().width('100%').height(1).color($r('app.color.divider'))
            Row() {
              Text('单日最佳：').fontSize(11).fontColor($r('app.color.text_tertiary'))
              Text(this.getTotalLabel(this.maxSeconds)).fontSize(11).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
            }.width('100%')
          }
          .width('100%').padding(14).backgroundColor($r('app.color.surface')).borderRadius(14)
          .shadow({ radius: 6, color: $r('app.color.shadow_surface'), offsetY: 2 })

          Column({ space: 10 }) {
            Row() {
              Text('行动洞察').fontSize(15).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary'))
              Blank()
              Text(this.focusInsight.reflectedSessions > 0 ?
                `全部记录 · ${this.focusInsight.reflectedSessions} 次复盘` : '基于全部记录')
                .fontSize(9).fontColor($r('app.color.text_tertiary'))
            }.width('100%')
            Row() {
              this.insightMetric('高效时段', this.focusInsight.bestPeriod, $r('app.color.primary_green'))
              this.insightMetric('估时准确', this.getAccuracyLabel(), $r('app.color.accent_yellow'))
              this.insightMetric('平均专注', this.getFocusLabel(), $r('app.color.primary_red'))
            }.width('100%')
            Row({ space: 8 }) {
              this.insightQualityMetric('近 7 天趋势', this.getTrendLabel(),
                `${this.getTotalLabel(this.focusInsight.recentWorkSeconds)} · 前期 ${this.getTotalLabel(this.focusInsight.previousWorkSeconds)}`,
                this.getTrendColor())
              this.insightQualityMetric('复盘覆盖', `${this.focusInsight.reflectionCoveragePercent}%`,
                `${this.focusInsight.reflectedSessions}/${this.focusInsight.workSessions} 条专注记录`,
                this.getCoverageColor())
            }.width('100%')
            if (this.focusInsight.topInterruption !== '暂无') {
              Text(`主要打断：${this.focusInsight.topInterruption}`)
                .fontSize(10).fontColor($r('app.color.text_secondary')).width('100%')
            }
            Column({ space: 4 }) {
              Text(this.focusInsight.actionTitle).fontSize(12).fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.text_primary')).width('100%')
              Text(this.focusInsight.actionDescription).fontSize(10).lineHeight(15)
                .fontColor($r('app.color.text_secondary')).width('100%')
            }
            .width('100%').padding(10).backgroundColor($r('app.color.ring_track')).borderRadius(10)
          }
          .width('100%').padding(14).backgroundColor($r('app.color.surface')).borderRadius(14)
          .border({ width: 1, color: $r('app.color.primary_green') })

          Column() {
            if (this.sessionCount === 0) {
              Column({ space: 8 }) {
                Text('📊').fontSize(40)
                Text('暂无数据').fontSize(15).fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_secondary'))
                Text('开始计时后，专注数据将在这里展示')
                  .fontSize(12).fontColor($r('app.color.text_tertiary'))
              }
              .width('100%').height(220).justifyContent(FlexAlign.Center)
              .alignItems(HorizontalAlign.Center)
            } else {
              Scroll() {
                Row({ space: 9 }) {
                  ForEach(this.getActiveData(), (item: DailyStats) => {
                    Column({ space: 6 }) {
                      Text(this.getBarLabel(item.totalSeconds)).fontSize(11).height(18)
                        .fontWeight(item.totalSeconds > 0 ? FontWeight.Bold : FontWeight.Normal)
                        .fontColor(item.totalSeconds > 0 ? $r('app.color.primary_red') :
                          $r('app.color.text_tertiary'))
                      Column().width(40).height(this.getBarHeight(item.totalSeconds, this.maxSeconds))
                        .borderRadius(8).linearGradient({
                          direction: GradientDirection.Bottom,
                          colors: item.totalSeconds > 0 ?
                            [[$r('app.color.primary_red'), 0], [$r('app.color.primary_red'), 0.7], ['#FFCDD2', 1]] :
                            [[$r('app.color.ring_track'), 0], [$r('app.color.ring_track'), 1]]
                        }).opacity(item.totalSeconds > 0 ? 1 : 0.4)
                        .animation({ duration: 500, curve: Curve.EaseOut })
                      Text(this.isToday(item.date) ? '今天' : item.date).fontSize(11)
                        .fontColor(this.isToday(item.date) ? $r('app.color.primary_red') :
                          $r('app.color.text_tertiary'))
                        .fontWeight(this.isToday(item.date) ? FontWeight.Bold : FontWeight.Normal)
                        .constraintSize({ maxWidth: 52 }).textAlign(TextAlign.Center)
                    }.alignItems(HorizontalAlign.Center)
                  }, (item: DailyStats) => item.date)
                }
                .alignItems(VerticalAlign.Bottom).padding({ left: 12, right: 12, top: 8, bottom: 4 })
              }
              .scrollable(ScrollDirection.Horizontal).scrollBar(BarState.Off)
              .height(240).width('100%')
            }
          }
          .width('100%').padding({ top: 12, bottom: 16, left: 4, right: 4 })
          .backgroundColor($r('app.color.surface')).borderRadius(14)
          .shadow({ radius: 4, color: $r('app.color.shadow_surface'), offsetY: 2 })
        }.width('100%').padding({ bottom: 14 })
      }.layoutWeight(1).width('100%').scrollBar(BarState.Off)
    }
    .width('100%').height('100%').backgroundColor($r('app.color.background'))
    .padding({ left: 8, right: 8 })
  }
}
