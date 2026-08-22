import {
  HeartRateScenario,
  MockHeartRateProvider,
  WearableHealthHelper,
  WearableHealthSnapshot,
  WearableRecommendation
} from '../utils/WearableHealthHelper';

@Component
export struct WearableLab {
  @Prop remainingSeconds: number = 0;
  @Prop totalSeconds: number = 0;
  @Prop isRunning: boolean = false;
  @Prop isWorkMode: boolean = true;
  @Prop currentTask: string = '';
  @State scenario: HeartRateScenario = 'steady';
  @State snapshot: WearableHealthSnapshot = WearableHealthHelper.emptySnapshot();
  @State recommendation: WearableRecommendation = WearableHealthHelper.evaluate(
    WearableHealthHelper.emptySnapshot());
  onClose?: () => void;
  onStartPause?: () => void;
  onSkip?: () => void;
  onPauseForRecovery?: () => void;
  onSendToAgent?: (prompt: string) => void;

  private provider: MockHeartRateProvider = new MockHeartRateProvider();
  private simulationTimerId: number | null = null;
  private tick: number = 0;

  aboutToAppear(): void {
    this.provider.setScenario(this.scenario);
    this.refreshSnapshot();
    this.simulationTimerId = setInterval(() => {
      this.tick += 1;
      this.refreshSnapshot();
    }, 1000);
  }

  aboutToDisappear(): void {
    if (this.simulationTimerId !== null) {
      clearInterval(this.simulationTimerId);
      this.simulationTimerId = null;
    }
  }

  private refreshSnapshot(): void {
    this.snapshot = this.provider.nextSnapshot(this.tick, Date.now());
    this.recommendation = WearableHealthHelper.evaluate(this.snapshot);
  }

  private selectScenario(scenario: HeartRateScenario): void {
    this.scenario = scenario;
    this.tick = 0;
    this.provider.setScenario(scenario);
    this.refreshSnapshot();
  }

  private formatSeconds(seconds: number): string {
    const safeSeconds = Math.max(0, seconds);
    const minutes = Math.floor(safeSeconds / 60).toString().padStart(2, '0');
    const remainder = (safeSeconds % 60).toString().padStart(2, '0');
    return `${minutes}:${remainder}`;
  }

  private sendToAgent(): void {
    if (!this.recommendation.canAdjustPlan || !this.onSendToAgent) {
      return;
    }
    this.onSendToAgent(WearableHealthHelper.buildAgentPrompt(
      this.snapshot, this.recommendation, this.currentTask));
  }

  @Builder
  private scenarioButton(label: string, value: HeartRateScenario) {
    Button(label)
      .layoutWeight(1)
      .height(34)
      .fontSize(10)
      .borderRadius(17)
      .backgroundColor(this.scenario === value ?
        $r('app.color.primary_green') : $r('app.color.ring_track'))
      .fontColor(this.scenario === value ? Color.Black : $r('app.color.text_secondary'))
      .onClick(() => this.selectScenario(value))
  }

  @Builder
  private watchPreview() {
    Stack({ alignContent: Alignment.Center }) {
      Column({ space: 5 }) {
        Text(this.isWorkMode ? '专注中' : '休息中')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(this.isWorkMode ? '#FF789F' : '#75E58D')
        Text(this.formatSeconds(this.remainingSeconds))
          .fontSize(34)
          .fontWeight(FontWeight.Bold)
          .fontColor(Color.White)
        Text(this.currentTask.length > 0 ? this.currentTask : '尚未设置任务')
          .width(150)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .textAlign(TextAlign.Center)
          .fontSize(10)
          .fontColor('#A8A8AD')
        Row({ space: 5 }) {
          Text('♥').fontSize(16).fontColor('#FF4D73')
          Text(this.snapshot.bpm > 0 ? `${this.snapshot.bpm} BPM` : '-- BPM')
            .fontSize(13).fontWeight(FontWeight.Bold).fontColor(Color.White)
        }
      }
      .alignItems(HorizontalAlign.Center)
    }
    .width(210)
    .height(210)
    .backgroundColor('#111113')
    .borderRadius(105)
    .border({ width: 5, color: '#424247' })
    .shadow({ radius: 18, color: '#55000000', offsetY: 6 })
  }

  build() {
    Column() {
      Column({ space: 12 }) {
        Row({ space: 10 }) {
          Column({ space: 2 }) {
            Text('穿戴协同实验室')
              .fontSize(20).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary')).width('100%')
            Text('无真机开发模式 · 聚合数据不会自动调用 AI')
              .fontSize(10).fontColor($r('app.color.text_tertiary')).width('100%')
          }.layoutWeight(1)
          Button('关闭')
            .height(30).fontSize(10).borderRadius(15)
            .backgroundColor($r('app.color.ring_track'))
            .fontColor($r('app.color.text_secondary'))
            .onClick(() => {
              if (this.onClose) {
                this.onClose();
              }
            })
        }.width('100%')

        Scroll() {
          Column({ space: 14 }) {
            this.watchPreview()

            Row({ space: 8 }) {
              Button(this.isRunning ? '暂停' : '开始')
                .layoutWeight(1).height(38).fontSize(12).borderRadius(19)
                .backgroundColor($r('app.color.primary_red')).fontColor(Color.White)
                .onClick(() => {
                  if (this.onStartPause) {
                    this.onStartPause();
                  }
                })
              Button('跳过阶段')
                .layoutWeight(1).height(38).fontSize(12).borderRadius(19)
                .enabled(this.isRunning)
                .backgroundColor($r('app.color.ring_track'))
                .fontColor($r('app.color.text_secondary'))
                .onClick(() => {
                  if (this.onSkip) {
                    this.onSkip();
                  }
                })
            }.width('100%')

            Column({ space: 8 }) {
              Row() {
                Text('模拟数据源').fontSize(14).fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
                Blank()
                Text(WearableHealthHelper.scenarioLabel(this.scenario))
                  .fontSize(10).fontColor($r('app.color.primary_green'))
              }.width('100%')
              Row({ space: 6 }) {
                this.scenarioButton('平稳专注', 'steady')
                this.scenarioButton('压力升高', 'stress')
              }.width('100%')
              Row({ space: 6 }) {
                this.scenarioButton('运动干扰', 'movement')
                this.scenarioButton('设备断连', 'disconnected')
              }.width('100%')
              Text('场景数据为演示数据，但规则判断、隐私过滤和 Agent 入口均复用正式链路。')
                .fontSize(9).lineHeight(14).fontColor($r('app.color.text_tertiary')).width('100%')
            }
            .width('100%').padding(13).backgroundColor($r('app.color.ring_track')).borderRadius(14)

            Column({ space: 7 }) {
              Row({ space: 7 }) {
                Text(this.recommendation.level === 'recover' ? '需要恢复' :
                  (this.recommendation.level === 'observe' ? '保持观察' :
                    (this.recommendation.level === 'normal' ? '状态平稳' : '数据不可用')))
                  .fontSize(10).fontWeight(FontWeight.Bold)
                  .fontColor(this.recommendation.level === 'recover' ?
                    $r('app.color.primary_red') : $r('app.color.primary_green'))
                Text(this.recommendation.title).fontSize(13).fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_primary'))
              }.width('100%')
              Text(this.recommendation.description)
                .fontSize(10).lineHeight(15).fontColor($r('app.color.text_secondary')).width('100%')
              Text(`窗口中位数 ${this.snapshot.medianBpm || '--'} BPM · 基线 ${this.snapshot.baselineBpm} BPM · 高负荷 ${this.snapshot.highLoadSeconds} 秒`)
                .fontSize(9).fontColor($r('app.color.text_tertiary')).width('100%')

              if (this.recommendation.level === 'recover' && this.isRunning && this.isWorkMode) {
                Button('先暂停当前计时')
                  .width('100%').height(36).fontSize(11).borderRadius(18)
                  .backgroundColor($r('app.color.primary_red')).fontColor(Color.White)
                  .onClick(() => {
                    if (this.onPauseForRecovery) {
                      this.onPauseForRecovery();
                    }
                  })
              }
              if (this.recommendation.canAdjustPlan) {
                Button(this.recommendation.actionLabel)
                  .width('100%').height(38).fontSize(11).fontWeight(FontWeight.Bold).borderRadius(19)
                  .backgroundColor($r('app.color.primary_green')).fontColor(Color.Black)
                  .onClick(() => this.sendToAgent())
              }
            }
            .width('100%').padding(13).backgroundColor($r('app.color.surface'))
            .border({ width: 1, color: this.recommendation.level === 'recover' ?
              $r('app.color.primary_red') : $r('app.color.card_border') }).borderRadius(14)

            Text('隐私保护：正式接入后仅向手机和 Agent 提供窗口中位数、趋势、持续时间等摘要，不上传逐秒心率。此功能不用于医学诊断。')
              .fontSize(9).lineHeight(14).fontColor($r('app.color.text_tertiary')).width('100%')
          }
          .width('100%')
        }
        .layoutWeight(1).width('100%').scrollBar(BarState.Off)
      }
      .width('92%').height('90%').padding(16)
      .backgroundColor($r('app.color.background')).borderRadius(24)
      .border({ width: 1, color: $r('app.color.card_border') })
    }
    .width('100%').height('100%')
    .justifyContent(FlexAlign.Center).alignItems(HorizontalAlign.Center)
    .backgroundColor('#99000000').zIndex(50)
  }
}
