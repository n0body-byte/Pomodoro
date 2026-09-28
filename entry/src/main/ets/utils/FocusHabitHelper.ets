import { SessionRecord } from './PreferencesHelper';

export interface RecentTaskItem {
  task: string;
  project: string;
  tag: string;
  note: string;
  estimatedPomodoros: number;
}

export interface ProjectProgressItem {
  project: string;
  workSeconds: number;
  sessions: number;
}

export interface HabitSnapshot {
  streakDays: number;
  todayCompleted: number;
  dailyTarget: number;
  remainingToTarget: number;
  restTip: string;
}

export class FocusHabitHelper {
  static buildRecentTasks(history: SessionRecord[], limit: number = 3): RecentTaskItem[] {
    const items: RecentTaskItem[] = [];
    const seen: string[] = [];
    for (let index = 0; index < history.length; index++) {
      const record = history[index];
      if (record.type === 'break') {
        continue;
      }
      const task = typeof record.task === 'string' ? record.task.trim() : '';
      if (task.length === 0) {
        continue;
      }
      const project = typeof record.project === 'string' ? record.project.trim() : '';
      const key = `${task}::${project}`;
      if (seen.indexOf(key) >= 0) {
        continue;
      }
      seen.push(key);
      items.push({
        task: task,
        project: project,
        tag: typeof record.tag === 'string' ? record.tag.trim() : '',
        note: typeof record.note === 'string' ? record.note.trim() : '',
        estimatedPomodoros: 1
      });
      if (items.length >= limit) {
        break;
      }
    }
    return items;
  }

  static computeCurrentStreak(history: SessionRecord[], now: number = Date.now()): number {
    const dayMap: Record<string, boolean> = {};
    for (const record of history) {
      if (record.type === 'break' || record.workSeconds <= 0) {
        continue;
      }
      if (record.status === 'skipped') {
        continue;
      }
      const date = typeof record.date === 'string' && record.date.length > 0 ?
        record.date : FocusHabitHelper.formatLocalDate(new Date(record.completedAt));
      dayMap[date] = true;
    }
    const today = FocusHabitHelper.formatLocalDate(new Date(now));
    const yesterdayDate = new Date(now);
    yesterdayDate.setDate(yesterdayDate.getDate() - 1);
    const yesterday = FocusHabitHelper.formatLocalDate(yesterdayDate);
    const start = dayMap[today] ? today : (dayMap[yesterday] ? yesterday : '');
    if (start.length === 0) {
      return 0;
    }
    let streak = 0;
    const cursor = FocusHabitHelper.parseLocalDate(start);
    for (let day = 0; day < 366; day++) {
      const key = FocusHabitHelper.formatLocalDate(cursor);
      if (!dayMap[key]) {
        break;
      }
      streak += 1;
      cursor.setDate(cursor.getDate() - 1);
    }
    return streak;
  }

  static remainingToTarget(todayCompleted: number, dailyTarget: number): number {
    return Math.max(0, dailyTarget - Math.max(0, todayCompleted));
  }

  static restTip(completedSessions: number): string {
    const tips: string[] = [
      '站起来活动一下肩颈，看向远处 20 秒。',
      '喝一口水，放松眼睛，不必刷手机。',
      '做几次深呼吸，下轮只带一个明确交付。',
      '走动一圈或伸展手腕，再回来继续。'
    ];
    const index = Math.abs(completedSessions) % tips.length;
    return tips[index];
  }

  static buildProjectProgress(history: SessionRecord[], limit: number = 4,
    now: number = Date.now()): ProjectProgressItem[] {
    const weekMs = 7 * 24 * 60 * 60 * 1000;
    const map: ProjectProgressItem[] = [];
    for (const record of history) {
      if (record.type === 'break' || record.workSeconds <= 0) {
        continue;
      }
      if (now - record.completedAt > weekMs) {
        continue;
      }
      const project = typeof record.project === 'string' && record.project.trim().length > 0 ?
        record.project.trim() : '未分类';
      let found = false;
      for (const item of map) {
        if (item.project === project) {
          item.workSeconds += record.workSeconds;
          item.sessions += 1;
          found = true;
          break;
        }
      }
      if (!found) {
        map.push({ project: project, workSeconds: record.workSeconds, sessions: 1 });
      }
    }
    map.sort((left: ProjectProgressItem, right: ProjectProgressItem) =>
      right.workSeconds - left.workSeconds);
    return map.slice(0, limit);
  }

  static exportToJson(history: SessionRecord[]): string {
    return JSON.stringify(history, null, 2);
  }

  static exportToCsv(history: SessionRecord[]): string {
    const header = 'id,date,type,status,workSeconds,plannedSeconds,task,project,tag,note,focusRating,energyRating,interruptionReason,outcomeNote,completedAt';
    const lines: string[] = [header];
    for (const record of history) {
      const cells: string[] = [
        FocusHabitHelper.csvCell(record.id),
        FocusHabitHelper.csvCell(record.date),
        FocusHabitHelper.csvCell(record.type === 'break' ? 'break' : 'work'),
        FocusHabitHelper.csvCell(record.status),
        `${record.workSeconds}`,
        record.plannedSeconds !== undefined ? `${record.plannedSeconds}` : '',
        FocusHabitHelper.csvCell(record.task),
        FocusHabitHelper.csvCell(record.project),
        FocusHabitHelper.csvCell(record.tag),
        FocusHabitHelper.csvCell(record.note),
        record.focusRating !== undefined ? `${record.focusRating}` : '',
        record.energyRating !== undefined ? `${record.energyRating}` : '',
        FocusHabitHelper.csvCell(record.interruptionReason),
        FocusHabitHelper.csvCell(record.outcomeNote),
        `${record.completedAt}`
      ];
      lines.push(cells.join(','));
    }
    return lines.join('\n');
  }

  static habitSnapshot(history: SessionRecord[], todayCompleted: number, dailyTarget: number,
    completedSessions: number, now: number = Date.now()): HabitSnapshot {
    const streak = FocusHabitHelper.computeCurrentStreak(history, now);
    return {
      streakDays: streak,
      todayCompleted: todayCompleted,
      dailyTarget: dailyTarget,
      remainingToTarget: FocusHabitHelper.remainingToTarget(todayCompleted, dailyTarget),
      restTip: FocusHabitHelper.restTip(completedSessions)
    };
  }

  private static csvCell(value: string | undefined): string {
    const text = value !== undefined ? value : '';
    const escaped = text.replace(/"/g, '""');
    return `"${escaped}"`;
  }

  private static formatLocalDate(value: Date): string {
    return `${value.getFullYear()}-${(value.getMonth() + 1).toString().padStart(2, '0')}-${value.getDate().toString().padStart(2, '0')}`;
  }

  private static parseLocalDate(value: string): Date {
    const parts = value.split('-');
    return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
  }
}
