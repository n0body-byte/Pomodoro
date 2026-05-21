import { AchievementHelper, AchievementDef } from '../utils/AchievementHelper';

@Component
export struct Achievements {
  @Prop @Watch('onActiveChange') active: boolean = false;
  @State unlockedCount: number = 0;
  @State totalCount: number = 0;
  @State allBadges: AchievementDef[] = [];
  @State refreshKey: number = 0;

  async aboutToAppear(): Promise<void> {
    await this.refresh();
  }

  async onActiveChange(): Promise<void> {
    if (this.active) {
      await this.refresh();
    }
  }

  private async refresh(): Promise<void> {
    const ctx = this.getUIContext().getHostContext();
    if (ctx === undefined || ctx === null) {
      setTimeout(() => this.refresh(), 200);
      return;
    }
    const result = await AchievementHelper.compute(ctx);
    this.allBadges = result;
    this.totalCount = result.length;
    let count = 0;
    for (const b of result) {
      if (b.unlocked) {
        count += 1;
      }
    }
    this.unlockedCount = count;
    this.refreshKey++;
  }

  private catLabel(cat: string): string {
    if (cat === 'milestone') return '里程';
    if (cat === 'streak') return '毅力';
    if (cat === 'champion') return '冠军';
    return '时间';
  }

  private catColor(cat: string): Resource {
    if (cat === 'milestone') return $r('app.color.primary_red');
    if (cat === 'streak') return $r('app.color.daily_target');
    if (cat === 'champion') return $r('app.color.primary_green');
    return $r('app.color.accent_yellow');
  }

  private catIcon(cat: string): Resource {
    if (cat === 'milestone') return $r('app.media.tomato');
    if (cat === 'streak') return $r('app.media.focus');
    if (cat === 'champion') return $r('app.media.pomodoro');
    return $r('app.media.rest');
  }

  build() {
    Column() {
      Text('成就')
        .fontSize($r('app.float.title_font_size'))
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.text_primary'))
        .width('100%')
        .padding({ top: 8, bottom: 4, left: 8 })

      // 进度概览
      Column({ space: 6 }) {
        Row({ space: 12 }) {
          Column({ space: 2 }) {
            Text(`${this.unlockedCount}`)
              .fontSize(36)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.primary_red'))
            Text('已解锁')
              .fontSize(11)
              .fontColor($r('app.color.text_tertiary'))
          }
          .alignItems(HorizontalAlign.Center)

          Divider()
            .vertical(true)
            .height(40)
            .color($r('app.color.divider'))

          Column({ space: 2 }) {
            Text(`${this.totalCount - this.unlockedCount}`)
              .fontSize(36)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_tertiary'))
            Text('待解锁')
              .fontSize(11)
              .fontColor($r('app.color.text_tertiary'))
          }
          .alignItems(HorizontalAlign.Center)

          Blank()

          Row() {
            Column()
              .width(this.totalCount > 0 ? `${(this.unlockedCount / this.totalCount) * 100}%` : '0%')
              .height(6)
              .borderRadius(3)
              .backgroundColor($r('app.color.primary_red'))
              .animation({ duration: 800, curve: Curve.EaseOut })
            Column()
              .layoutWeight(1)
              .height(6)
              .backgroundColor($r('app.color.ring_track'))
              .borderRadius(3)
          }
          .width(80)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      }
      .width('100%')
      .padding({ left: 16, right: 16, top: 14, bottom: 14 })
      .backgroundColor($r('app.color.surface'))
      .borderRadius(14)
      .shadow({ radius: 6, color: $r('app.color.shadow_surface'), offsetY: 2 })

      Blank().height(12)

      // 徽章网格（按类别分组，直接内联渲染）
      Scroll() {
        Column({ space: 18 }) {
          ForEach(['milestone', 'streak', 'champion', 'time'], (cat: string) => {
            Column({ space: 10 }) {
              Row({ space: 6 }) {
                Column()
                  .width(8)
                  .height(8)
                  .borderRadius(4)
                  .backgroundColor(this.catColor(cat))
                Text(this.catLabel(cat))
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.text_secondary'))
                  .letterSpacing(2)
              }
              .width('100%')

              Grid() {
                ForEach(this.allBadges.filter((b: AchievementDef) => b.category === cat),
                  (badge: AchievementDef) => {
                    GridItem() {
                      Column({ space: 6 }) {
                        Stack() {
                          Column()
                            .width(56)
                            .height(56)
                            .borderRadius(28)
                            .backgroundColor(badge.unlocked ? this.catColor(cat) : $r('app.color.ring_track'))
                            .opacity(badge.unlocked ? 1 : 0.45)
                          Image(this.catIcon(cat))
                            .width(26)
                            .height(26)
                            .fillColor(badge.unlocked ? Color.White : $r('app.color.text_tertiary'))
                            .opacity(badge.unlocked ? 1 : 0.35)
                        }
                        .alignContent(Alignment.Center)

                        Text(badge.name)
                          .fontSize(11)
                          .fontWeight(badge.unlocked ? FontWeight.Bold : FontWeight.Normal)
                          .fontColor(badge.unlocked ? $r('app.color.text_primary') : $r('app.color.text_tertiary'))
                          .maxLines(1)
                          .textAlign(TextAlign.Center)

                        Text(badge.desc)
                          .fontSize(9)
                          .fontColor($r('app.color.text_tertiary'))
                          .maxLines(1)
                          .textAlign(TextAlign.Center)
                      }
                      .alignItems(HorizontalAlign.Center)
                      .padding({ top: 6, bottom: 6 })
                    }
                  }, (badge: AchievementDef) => `${this.refreshKey}_${badge.id}`
                )
              }
              .columnsTemplate('1fr 1fr 1fr')
              .rowsGap(12)
              .columnsGap(8)
              .width('100%')
            }
          }, (cat: string) => `${this.refreshKey}_${cat}`)
        }
        .width('100%')
        .padding({ left: 4, right: 4 })
      }
      .scrollBar(BarState.Off)
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .backgroundColor($r('app.color.background'))
    .padding({ left: 8, right: 8, top: 8 })
  }
}
