import { Statistics } from './Statistics';
import { History } from './History';
import { Achievements } from './Achievements';
import { SessionRecord } from '../utils/PreferencesHelper';

@Component
export struct Insights {
  @Prop active: boolean = false;
  @State selectedSection: number = 0;
  @Prop canRepeatTask: boolean = true;
  onHistoryChanged?: () => void;
  onRepeatTask?: (record: SessionRecord) => void;

  @Builder
  sectionButton(label: string, index: number) {
    Text(label)
      .layoutWeight(1)
      .height(36)
      .textAlign(TextAlign.Center)
      .fontSize(12)
      .fontWeight(this.selectedSection === index ? FontWeight.Bold : FontWeight.Medium)
      .fontColor(this.selectedSection === index ? Color.White : $r('app.color.text_secondary'))
      .backgroundColor(this.selectedSection === index ? $r('app.color.primary_red') : Color.Transparent)
      .borderRadius(14)
      .onClick(() => {
        this.selectedSection = index;
      })
  }

  build() {
    Column({ space: 8 }) {
      Row({ space: 4 }) {
        this.sectionButton('统计', 0)
        this.sectionButton('历史', 1)
        this.sectionButton('成就', 2)
      }
      .width('100%')
      .height(44)
      .padding(4)
      .backgroundColor($r('app.color.ring_track'))
      .borderRadius(18)

      Column() {
        if (this.selectedSection === 0) {
          Statistics({ active: this.active })
        } else if (this.selectedSection === 1) {
          History({
            active: this.active,
            canRepeatTask: this.canRepeatTask,
            onChanged: () => {
              if (this.onHistoryChanged !== undefined) {
                this.onHistoryChanged();
              }
            },
            onRepeatTask: (record: SessionRecord) => {
              if (this.onRepeatTask !== undefined) {
                this.onRepeatTask(record);
              }
            }
          })
        } else {
          Achievements({ active: this.active })
        }
      }
      .layoutWeight(1)
      .width('100%')
    }
    .width('100%')
    .height('100%')
    .padding({ left: 8, right: 8, top: 8 })
    .backgroundColor($r('app.color.background'))
  }
}
