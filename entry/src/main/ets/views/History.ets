import { PreferencesHelper, SessionRecord } from '../utils/PreferencesHelper';

@Component
export struct History {
  @Prop @Watch('onActiveChange') active: boolean = false;
  @State records: SessionRecord[] = [];
  @State showEditor: boolean = false;
  @State editTask: string = '';
  @State editProject: string = '';
  @State editTag: string = '';
  @State editNote: string = '';
  @State editDate: string = '';
  @State editTime: string = '12:00';
  @State editMinutes: number = 25;
  @State editIsBreak: boolean = false;
  @State pendingDeleteKey: string = '';
  @State errorText: string = '';
  onChanged?: () => void;
  private editOriginal: SessionRecord | null = null;

  async aboutToAppear(): Promise<void> {
    await this.refresh();
  }

  async onActiveChange(): Promise<void> {
    if (this.active) {
      await this.refresh();
    }
  }

  private getContext(): Context {
    return this.getUIContext().getHostContext()!;
  }

  private async refresh(): Promise<void> {
    const history = await PreferencesHelper.loadSessionHistory(this.getContext());
    this.records = history.slice().sort((a: SessionRecord, b: SessionRecord) =>
      b.completedAt - a.completedAt);
  }

  private todayString(): string {
    const now = new Date();
    return `${now.getFullYear()}-${(now.getMonth() + 1).toString().padStart(2, '0')}-${now.getDate().toString().padStart(2, '0')}`;
  }

  private recordKey(record: SessionRecord): string {
    return record.id || `${record.completedAt}-${record.type === 'break' ? 'break' : 'work'}`;
  }

  private startAdd(): void {
    this.editOriginal = null;
    this.editTask = '';
    this.editProject = '';
    this.editTag = '';
    this.editNote = '';
    this.editDate = this.todayString();
    const now = new Date();
    this.editTime = `${now.getHours().toString().padStart(2, '0')}:${now.getMinutes().toString().padStart(2, '0')}`;
    this.editMinutes = 25;
    this.editIsBreak = false;
    this.errorText = '';
    this.showEditor = true;
  }

  private startEdit(record: SessionRecord): void {
    this.editOriginal = record;
    this.editTask = record.task || '';
    this.editProject = record.project || '';
    this.editTag = record.tag || '';
    this.editNote = record.note || '';
    this.editDate = record.date;
    this.editTime = this.formatTime(record.completedAt);
    this.editMinutes = Math.max(1, Math.round(record.workSeconds / 60));
    this.editIsBreak = record.type === 'break';
    this.errorText = '';
    this.showEditor = true;
  }

  private parseDateTime(value: string, timeValue: string): number {
    const parts = value.split('-');
    const timeParts = timeValue.split(':');
    if (parts.length !== 3 || timeParts.length !== 2) {
      return 0;
    }
    const year = Number(parts[0]);
    const month = Number(parts[1]);
    const day = Number(parts[2]);
    const hour = Number(timeParts[0]);
    const minute = Number(timeParts[1]);
    if (year < 2000 || month < 1 || month > 12 || day < 1 || day > 31 ||
      hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return 0;
    }
    const parsed = new Date(year, month - 1, day, hour, minute, 0);
    if (parsed.getFullYear() !== year || parsed.getMonth() !== month - 1 || parsed.getDate() !== day) {
      return 0;
    }
    return parsed.getTime();
  }

  private async saveEditor(): Promise<void> {
    const timestamp = this.parseDateTime(this.editDate, this.editTime);
    if (timestamp <= 0) {
      this.errorText = '日期时间格式应为 YYYY-MM-DD 和 HH:MM';
      return;
    }
    const original = this.editOriginal;
    const record: SessionRecord = {
      id: original !== null ? (original.id || this.recordKey(original)) : `manual-${Date.now()}`,
      date: this.editDate,
      workSeconds: this.editMinutes * 60,
      startedAt: timestamp - this.editMinutes * 60 * 1000,
      completedAt: timestamp,
      type: this.editIsBreak ? 'break' : 'work',
      status: original !== null ? original.status || 'completed' : 'completed',
      plannedSeconds: original !== null ? original.plannedSeconds || this.editMinutes * 60 : this.editMinutes * 60,
      task: this.editTask.trim(),
      project: this.editProject.trim(),
      tag: this.editTag.trim(),
      note: this.editNote.trim(),
      source: original !== null ? original.source || 'timer' : 'manual'
    };
    await PreferencesHelper.updateSessionRecord(this.getContext(), record);
    this.showEditor = false;
    this.editOriginal = null;
    await this.refresh();
    if (this.onChanged) this.onChanged();
  }

  private async deleteRecord(record: SessionRecord): Promise<void> {
    const key = this.recordKey(record);
    if (this.pendingDeleteKey !== key) {
      this.pendingDeleteKey = key;
      return;
    }
    await PreferencesHelper.deleteSessionRecord(this.getContext(), record);
    this.pendingDeleteKey = '';
    await this.refresh();
    if (this.onChanged) this.onChanged();
  }

  private statusLabel(record: SessionRecord): string {
    if (record.status === 'abandoned') return '部分专注';
    if (record.status === 'skipped') return '已跳过';
    if (record.source === 'manual') return '手动补记';
    return '已完成';
  }

  private formatTime(timestamp: number): string {
    const date = new Date(timestamp);
    return `${date.getHours().toString().padStart(2, '0')}:${date.getMinutes().toString().padStart(2, '0')}`;
  }

  build() {
    Column() {
      Row() {
        Text('历史记录')
          .fontSize($r('app.float.title_font_size'))
          .fontWeight(FontWeight.Bold)
          .fontColor($r('app.color.text_primary'))
        Blank()
        Button('+ 补记')
          .height(34).fontSize(12)
          .fontColor(Color.White)
          .backgroundColor($r('app.color.primary_red'))
          .borderRadius(17)
          .onClick(() => this.startAdd())
      }
      .width('100%')
      .padding({ left: 12, right: 12, top: 8, bottom: 12 })

      if (this.showEditor) {
        Column({ space: 10 }) {
          Row() {
            Text(this.editOriginal === null ? '补记专注' : '编辑记录')
              .fontSize(16).fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.text_primary'))
            Blank()
            Button(this.editIsBreak ? '休息' : '专注')
              .height(30).fontSize(12).borderRadius(15)
              .fontColor(Color.White)
              .backgroundColor(this.editIsBreak ? $r('app.color.primary_green') : $r('app.color.primary_red'))
              .onClick(() => this.editIsBreak = !this.editIsBreak)
          }
          TextInput({ text: this.editTask, placeholder: '任务名称' })
            .height(40).backgroundColor($r('app.color.ring_track'))
            .onChange((value: string) => this.editTask = value)
          Row({ space: 8 }) {
            TextInput({ text: this.editProject, placeholder: '项目' })
              .layoutWeight(1).height(40).backgroundColor($r('app.color.ring_track'))
              .onChange((value: string) => this.editProject = value)
            TextInput({ text: this.editTag, placeholder: '标签' })
              .layoutWeight(1).height(40).backgroundColor($r('app.color.ring_track'))
              .onChange((value: string) => this.editTag = value)
          }
          TextInput({ text: this.editNote, placeholder: '备注' })
            .height(40).backgroundColor($r('app.color.ring_track'))
            .onChange((value: string) => this.editNote = value)
          TextInput({ text: this.editDate, placeholder: 'YYYY-MM-DD' })
            .height(40).backgroundColor($r('app.color.ring_track'))
            .onChange((value: string) => this.editDate = value)
          TextInput({ text: this.editTime, placeholder: 'HH:MM（结束时间）' })
            .height(40).backgroundColor($r('app.color.ring_track'))
            .onChange((value: string) => this.editTime = value)
          Row() {
            Text('时长')
              .fontSize(13).fontColor($r('app.color.text_secondary'))
            Blank()
            Button('-5').height(30).backgroundColor($r('app.color.ring_track'))
              .fontColor($r('app.color.text_secondary'))
              .onClick(() => this.editMinutes = Math.max(1, this.editMinutes - 5))
            Text(`${this.editMinutes} 分钟`)
              .width(82).textAlign(TextAlign.Center)
              .fontWeight(FontWeight.Bold).fontColor($r('app.color.text_primary'))
            Button('+5').height(30).backgroundColor($r('app.color.ring_track'))
              .fontColor($r('app.color.text_secondary'))
              .onClick(() => this.editMinutes = Math.min(240, this.editMinutes + 5))
          }
          if (this.errorText !== '') {
            Text(this.errorText).fontSize(11).fontColor($r('app.color.primary_red'))
          }
          Row({ space: 10 }) {
            Button('取消').layoutWeight(1).height(38)
              .backgroundColor($r('app.color.ring_track'))
              .fontColor($r('app.color.text_secondary'))
              .onClick(() => this.showEditor = false)
            Button('保存').layoutWeight(1).height(38)
              .backgroundColor($r('app.color.primary_red'))
              .fontColor(Color.White)
              .onClick(() => this.saveEditor())
          }
        }
        .padding(14)
        .margin({ left: 10, right: 10, bottom: 10 })
        .backgroundColor($r('app.color.surface'))
        .borderRadius(16)
      }

      if (this.records.length === 0 && !this.showEditor) {
        Column({ space: 8 }) {
          Text('还没有专注记录').fontSize(16).fontColor($r('app.color.text_secondary'))
          Text('完成一次计时，或点击右上角手动补记')
            .fontSize(12).fontColor($r('app.color.text_tertiary'))
        }
        .layoutWeight(1).justifyContent(FlexAlign.Center)
      } else {
        List({ space: 8 }) {
          ForEach(this.records, (record: SessionRecord) => {
            ListItem() {
              Column({ space: 8 }) {
                Row() {
                  Column({ space: 3 }) {
                    Text(record.type === 'break' ? '休息' :
                      (record.task && record.task.length > 0 ? record.task : '未命名专注'))
                      .fontSize(15).fontWeight(FontWeight.Bold)
                      .fontColor($r('app.color.text_primary'))
                    Text(`${record.date} ${this.formatTime(record.startedAt || record.completedAt - record.workSeconds * 1000)}-${this.formatTime(record.completedAt)} · ${Math.round(record.workSeconds / 60)} 分钟`)
                      .fontSize(11).fontColor($r('app.color.text_tertiary'))
                  }.alignItems(HorizontalAlign.Start)
                  Blank()
                  Text(this.statusLabel(record))
                    .fontSize(10)
                    .fontColor(record.type === 'break' ? $r('app.color.primary_green') : $r('app.color.primary_red'))
                }.width('100%')
                if ((record.project && record.project.length > 0) || (record.tag && record.tag.length > 0)) {
                  Text(`${record.project || '无项目'}${record.tag && record.tag.length > 0 ? ` · #${record.tag}` : ''}`)
                    .fontSize(11).fontColor($r('app.color.text_secondary'))
                    .width('100%')
                }
                if (record.note && record.note.length > 0) {
                  Text(record.note).fontSize(11).fontColor($r('app.color.text_tertiary')).width('100%')
                }
                Row({ space: 8 }) {
                  Blank()
                  Button('编辑').height(28).fontSize(11)
                    .backgroundColor($r('app.color.ring_track'))
                    .fontColor($r('app.color.text_secondary'))
                    .onClick(() => this.startEdit(record))
                  Button(this.pendingDeleteKey === this.recordKey(record) ? '确认删除' : '删除')
                    .height(28).fontSize(11)
                    .backgroundColor(Color.Transparent)
                    .fontColor($r('app.color.primary_red'))
                    .onClick(() => this.deleteRecord(record))
                }.width('100%')
              }
              .padding(14)
              .backgroundColor($r('app.color.surface'))
              .borderRadius(14)
            }
          }, (record: SessionRecord) => this.recordKey(record))
        }
        .layoutWeight(1)
        .scrollBar(BarState.Off)
        .width('100%')
        .padding({ left: 10, right: 10, bottom: 10 })
      }
    }
    .width('100%').height('100%')
    .backgroundColor($r('app.color.background'))
  }
}
