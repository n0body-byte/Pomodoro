import { preferences } from '@kit.ArkData';
import {
  PREFERENCES_STORE_NAME,
  PREF_KEY_WORK_DURATION,
  PREF_KEY_BREAK_DURATION,
  PREF_KEY_AUTO_START,
  PREF_KEY_DAILY_TARGET,
  PREF_KEY_SESSION_HISTORY,
  PREF_KEY_TIMER_STATE,
  PREF_KEY_THEME,
  PREF_KEY_SOUND,
  PREF_KEY_AMBIENT,
  PREF_KEY_LONG_BREAK_DURATION,
  PREF_KEY_LONG_BREAK_INTERVAL,
  PREF_KEY_AUTO_START_WORK,
  PREF_KEY_AUTO_START_BREAK,
  PREF_KEY_TIMER_PRESET,
  PREF_KEY_SOUND_ENABLED,
  PREF_KEY_SOUND_VOLUME,
  PREF_KEY_AMBIENT_VOLUME,
  PREF_KEY_TASK_CONTEXT,
  DEFAULT_WORK_SECONDS,
  DEFAULT_BREAK_SECONDS,
  DEFAULT_DAILY_TARGET,
  DEFAULT_LONG_BREAK_SECONDS,
  DEFAULT_LONG_BREAK_INTERVAL,
  DEFAULT_SOUND_VOLUME,
  DEFAULT_AMBIENT_VOLUME
} from '../common/Constants';

export interface SessionRecord {
  id?: string;
  date: string;
  workSeconds: number;
  startedAt?: number;
  completedAt: number;
  type?: 'work' | 'break';
  status?: 'completed' | 'abandoned' | 'skipped';
  plannedSeconds?: number;
  task?: string;
  project?: string;
  tag?: string;
  note?: string;
  source?: 'timer' | 'manual';
}

export interface TaskContext {
  task: string;
  project: string;
  tag: string;
  note: string;
  estimatedPomodoros: number;
}

export interface TimerState {
  remainingSeconds: number;
  totalSeconds: number;
  isWorkMode: boolean;
  isRunning: boolean;
  completedSessions: number;
  savedAt: number;
  deadlineAt?: number;
  isLongBreak?: boolean;
}

export interface DailyStats {
  date: string;
  totalSeconds: number;
}

export class PreferencesHelper {
  private static getRecordKey(record: SessionRecord): string {
    if (record.id !== undefined && record.id.length > 0) {
      return record.id;
    }
    return `${record.completedAt}-${record.type === 'break' ? 'break' : 'work'}`;
  }

  static async saveWorkDuration(context: Context, seconds: number): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    await prefs.put(PREF_KEY_WORK_DURATION, seconds);
    await prefs.flush();
  }

  static async saveBreakDuration(context: Context, seconds: number): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    await prefs.put(PREF_KEY_BREAK_DURATION, seconds);
    await prefs.flush();
  }

  static async loadWorkDuration(context: Context): Promise<number> {
    try {
      const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
      const value = await prefs.get(PREF_KEY_WORK_DURATION, DEFAULT_WORK_SECONDS);
      return value as number;
    } catch {
      return DEFAULT_WORK_SECONDS;
    }
  }

  static async loadBreakDuration(context: Context): Promise<number> {
    try {
      const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
      const value = await prefs.get(PREF_KEY_BREAK_DURATION, DEFAULT_BREAK_SECONDS);
      return value as number;
    } catch {
      return DEFAULT_BREAK_SECONDS;
    }
  }

  static async saveAutoStart(context: Context, enabled: boolean): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    await prefs.put(PREF_KEY_AUTO_START, enabled);
    await prefs.flush();
  }

  static async loadAutoStart(context: Context): Promise<boolean> {
    try {
      const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
      const value = await prefs.get(PREF_KEY_AUTO_START, false);
      return value as boolean;
    } catch {
      return false;
    }
  }

  static async saveDailyTarget(context: Context, target: number): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    await prefs.put(PREF_KEY_DAILY_TARGET, target);
    await prefs.flush();
  }

  static async loadDailyTarget(context: Context): Promise<number> {
    try {
      const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
      const value = await prefs.get(PREF_KEY_DAILY_TARGET, DEFAULT_DAILY_TARGET);
      return value as number;
    } catch {
      return DEFAULT_DAILY_TARGET;
    }
  }

  static async saveSessionRecord(context: Context, record: SessionRecord): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    const raw = await prefs.get(PREF_KEY_SESSION_HISTORY, '[]');
    let history: SessionRecord[] = [];
    if (typeof raw === 'string' && raw.length > 0) {
      history = JSON.parse(raw) as SessionRecord[];
    }
    const recordType = record.type === 'break' ? 'break' : 'work';
    for (const item of history) {
      const itemType = item.type === 'break' ? 'break' : 'work';
      if (item.completedAt === record.completedAt && itemType === recordType) {
        return;
      }
    }
    history.push(record);
    await prefs.put(PREF_KEY_SESSION_HISTORY, JSON.stringify(history));
    await prefs.flush();
  }

  static async loadSessionHistory(context: Context): Promise<SessionRecord[]> {
    try {
      const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
      const raw = await prefs.get(PREF_KEY_SESSION_HISTORY, '[]');
      if (typeof raw === 'string' && raw.length > 0) {
        return JSON.parse(raw) as SessionRecord[];
      }
      return [];
    } catch {
      return [];
    }
  }

  static async updateSessionRecord(context: Context, record: SessionRecord): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    const raw = await prefs.get(PREF_KEY_SESSION_HISTORY, '[]');
    const history = typeof raw === 'string' && raw.length > 0
      ? JSON.parse(raw) as SessionRecord[] : [];
    const recordKey = PreferencesHelper.getRecordKey(record);
    let replaced = false;
    const updated: SessionRecord[] = [];
    for (const item of history) {
      if (PreferencesHelper.getRecordKey(item) === recordKey) {
        updated.push(record);
        replaced = true;
      } else {
        updated.push(item);
      }
    }
    if (!replaced) {
      updated.push(record);
    }
    await prefs.put(PREF_KEY_SESSION_HISTORY, JSON.stringify(updated));
    await prefs.flush();
  }

  static async deleteSessionRecord(context: Context, record: SessionRecord): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    const raw = await prefs.get(PREF_KEY_SESSION_HISTORY, '[]');
    const history = typeof raw === 'string' && raw.length > 0
      ? JSON.parse(raw) as SessionRecord[] : [];
    const recordKey = PreferencesHelper.getRecordKey(record);
    const updated = history.filter((item: SessionRecord) =>
      PreferencesHelper.getRecordKey(item) !== recordKey);
    await prefs.put(PREF_KEY_SESSION_HISTORY, JSON.stringify(updated));
    await prefs.flush();
  }

  static async getTaskCompletedSessions(context: Context, task: string, project: string): Promise<number> {
    if (task.length === 0) {
      return 0;
    }
    const history = await PreferencesHelper.loadSessionHistory(context);
    return history.filter((record: SessionRecord) =>
      PreferencesHelper.isCompletedWorkRecord(record) &&
      (record.task || '') === task && (record.project || '') === project).length;
  }

  static async clearTodaySessions(context: Context): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    const raw = await prefs.get(PREF_KEY_SESSION_HISTORY, '[]');
    let history: SessionRecord[] = [];
    if (typeof raw === 'string' && raw.length > 0) {
      history = JSON.parse(raw) as SessionRecord[];
    }
    const today = new Date();
    const todayStr = `${today.getFullYear()}-${(today.getMonth() + 1).toString().padStart(2, '0')}-${today.getDate().toString().padStart(2, '0')}`;
    const filtered = history.filter((r: SessionRecord) => r.date !== todayStr);
    await prefs.put(PREF_KEY_SESSION_HISTORY, JSON.stringify(filtered));
    await prefs.flush();
  }

  static async getTodaySessions(context: Context): Promise<number> {
    const history = await PreferencesHelper.loadSessionHistory(context);
    const today = new Date();
    const todayStr = `${today.getFullYear()}-${(today.getMonth() + 1).toString().padStart(2, '0')}-${today.getDate().toString().padStart(2, '0')}`;
    return history.filter((r: SessionRecord) =>
      r.date === todayStr && PreferencesHelper.isCompletedWorkRecord(r)
    ).length;
  }

  static async getTodayWorkSeconds(context: Context): Promise<number> {
    const history = await PreferencesHelper.loadSessionHistory(context);
    const today = new Date();
    const todayStr = `${today.getFullYear()}-${(today.getMonth() + 1).toString().padStart(2, '0')}-${today.getDate().toString().padStart(2, '0')}`;
    let total = 0;
    for (const r of history) {
      if (r.date === todayStr && r.type !== 'break') {
        total += r.workSeconds;
      }
    }
    return total;
  }

  static async getTodayBreakSeconds(context: Context): Promise<number> {
    const history = await PreferencesHelper.loadSessionHistory(context);
    const today = new Date();
    const todayStr = `${today.getFullYear()}-${(today.getMonth() + 1).toString().padStart(2, '0')}-${today.getDate().toString().padStart(2, '0')}`;
    let total = 0;
    for (const r of history) {
      if (r.date === todayStr && r.type === 'break') {
        total += r.workSeconds;
      }
    }
    return total;
  }

  static async getStats(context: Context, days: number): Promise<DailyStats[]> {
    const history = await PreferencesHelper.loadSessionHistory(context);
    const statsMap: Record<string, number> = {};
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth(); // 0-indexed
    const today = now.getDate();

    // 用与 record.date 相同的 "YYYY-MM-DD" 格式生成 key
    for (let i = 0; i < days; i++) {
      const d = new Date(year, month, today - i);
      const key = `${d.getFullYear()}-${(d.getMonth() + 1).toString().padStart(2, '0')}-${d.getDate().toString().padStart(2, '0')}`;
      statsMap[key] = 0;
    }

    // record.date 本身就是 "YYYY-MM-DD"，直接用作 key 查找
    for (const record of history) {
      if (record.type !== 'break' && statsMap[record.date] !== undefined) {
        statsMap[record.date] += record.workSeconds;
      }
    }

    // 按时间顺序输出，展示用 "M/D" 格式
    const result: DailyStats[] = [];
    for (let i = days - 1; i >= 0; i--) {
      const d = new Date(year, month, today - i);
      const key = `${d.getFullYear()}-${(d.getMonth() + 1).toString().padStart(2, '0')}-${d.getDate().toString().padStart(2, '0')}`;
      result.push({
        date: `${d.getMonth() + 1}/${d.getDate()}`,
        totalSeconds: statsMap[key]
      });
    }
    return result;
  }

  static async getWeeklyStats(context: Context, weeks: number): Promise<DailyStats[]> {
    const history = await PreferencesHelper.loadSessionHistory(context);
    const now = new Date();

    // 定位到本周一
    const today = new Date(now.getFullYear(), now.getMonth(), now.getDate());
    const todayDow = today.getDay(); // 0=Sun
    const mondayOffset = todayDow === 0 ? -6 : (1 - todayDow);
    const thisMonday = new Date(today);
    thisMonday.setDate(today.getDate() + mondayOffset);

    // 倒推 weeks 周前的周一
    const startMonday = new Date(thisMonday);
    startMonday.setDate(startMonday.getDate() - (weeks - 1) * 7);

    const result: DailyStats[] = [];
    for (let w = 0; w < weeks; w++) {
      const mon = new Date(startMonday);
      mon.setDate(mon.getDate() + w * 7);
      const sun = new Date(mon);
      sun.setDate(mon.getDate() + 6);

      const label = `${mon.getMonth() + 1}/${mon.getDate()}-${sun.getMonth() + 1}/${sun.getDate()}`;

      let total = 0;
      const dayCursor = new Date(mon);
      for (let d = 0; d < 7; d++) {
        const key = `${dayCursor.getFullYear()}-${(dayCursor.getMonth() + 1).toString().padStart(2, '0')}-${dayCursor.getDate().toString().padStart(2, '0')}`;
        for (const record of history) {
          if (record.type !== 'break' && record.date === key) {
            total += record.workSeconds;
          }
        }
        dayCursor.setDate(dayCursor.getDate() + 1);
      }
      result.push({ date: label, totalSeconds: total });
    }
    return result;
  }

  static async getMonthlyStats(context: Context, months: number): Promise<DailyStats[]> {
    const history = await PreferencesHelper.loadSessionHistory(context);
    const now = new Date();
    const year = now.getFullYear();
    const month = now.getMonth(); // 0-indexed

    const result: DailyStats[] = [];
    for (let i = months - 1; i >= 0; i--) {
      let m = month - i;
      let y = year;
      while (m < 0) {
        m += 12;
        y -= 1;
      }
      const label = `${m + 1}月`;
      const prefix = `${y}-${(m + 1).toString().padStart(2, '0')}-`;
      let total = 0;
      for (const record of history) {
        if (record.type !== 'break' && record.date.startsWith(prefix)) {
          total += record.workSeconds;
        }
      }
      result.push({ date: label, totalSeconds: total });
    }
    return result;
  }

  static async saveTimerState(context: Context, state: TimerState): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    await prefs.put(PREF_KEY_TIMER_STATE, JSON.stringify(state));
    await prefs.flush();
  }

  static isCompletedWorkRecord(record: SessionRecord): boolean {
    return record.type !== 'break' && (record.status === undefined || record.status === 'completed');
  }

  static async saveTheme(context: Context, isDark: boolean): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    await prefs.put(PREF_KEY_THEME, isDark);
    await prefs.flush();
  }

  static async saveSound(context: Context, sound: string): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    await prefs.put(PREF_KEY_SOUND, sound);
    await prefs.flush();
  }

  static async saveAmbient(context: Context, ambient: string): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    await prefs.put(PREF_KEY_AMBIENT, ambient);
    await prefs.flush();
  }

  static async loadAmbient(context: Context): Promise<string> {
    try {
      const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
      const value = await prefs.get(PREF_KEY_AMBIENT, '');
      return value as string;
    } catch {
      return '';
    }
  }

  static async loadSound(context: Context): Promise<string> {
    try {
      const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
      const value = await prefs.get(PREF_KEY_SOUND, 'bell');
      return value as string;
    } catch {
      return 'bell';
    }
  }

  static async loadTheme(context: Context): Promise<boolean> {
    try {
      const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
      const value = await prefs.get(PREF_KEY_THEME, false);
      return value as boolean;
    } catch {
      return false;
    }
  }

  static async loadTimerState(context: Context): Promise<TimerState | null> {
    try {
      const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
      const value = await prefs.get(PREF_KEY_TIMER_STATE, '');
      if (typeof value === 'string' && value.length > 0) {
        return JSON.parse(value) as TimerState;
      }
      return null;
    } catch {
      return null;
    }
  }

  static async saveLongBreakDuration(context: Context, seconds: number): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    await prefs.put(PREF_KEY_LONG_BREAK_DURATION, seconds);
    await prefs.flush();
  }

  static async loadLongBreakDuration(context: Context): Promise<number> {
    try {
      const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
      return await prefs.get(PREF_KEY_LONG_BREAK_DURATION, DEFAULT_LONG_BREAK_SECONDS) as number;
    } catch {
      return DEFAULT_LONG_BREAK_SECONDS;
    }
  }

  static async saveLongBreakInterval(context: Context, count: number): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    await prefs.put(PREF_KEY_LONG_BREAK_INTERVAL, count);
    await prefs.flush();
  }

  static async loadLongBreakInterval(context: Context): Promise<number> {
    try {
      const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
      return await prefs.get(PREF_KEY_LONG_BREAK_INTERVAL, DEFAULT_LONG_BREAK_INTERVAL) as number;
    } catch {
      return DEFAULT_LONG_BREAK_INTERVAL;
    }
  }

  static async saveAutoStartWork(context: Context, enabled: boolean): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    await prefs.put(PREF_KEY_AUTO_START_WORK, enabled);
    await prefs.flush();
  }

  static async loadAutoStartWork(context: Context): Promise<boolean> {
    try {
      const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
      const legacy = await prefs.get(PREF_KEY_AUTO_START, false) as boolean;
      return await prefs.get(PREF_KEY_AUTO_START_WORK, legacy) as boolean;
    } catch {
      return false;
    }
  }

  static async saveAutoStartBreak(context: Context, enabled: boolean): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    await prefs.put(PREF_KEY_AUTO_START_BREAK, enabled);
    await prefs.flush();
  }

  static async loadAutoStartBreak(context: Context): Promise<boolean> {
    try {
      const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
      const legacy = await prefs.get(PREF_KEY_AUTO_START, false) as boolean;
      return await prefs.get(PREF_KEY_AUTO_START_BREAK, legacy) as boolean;
    } catch {
      return false;
    }
  }

  static async saveTimerPreset(context: Context, preset: string): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    await prefs.put(PREF_KEY_TIMER_PRESET, preset);
    await prefs.flush();
  }

  static async loadTimerPreset(context: Context): Promise<string> {
    try {
      const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
      return await prefs.get(PREF_KEY_TIMER_PRESET, 'classic') as string;
    } catch {
      return 'classic';
    }
  }

  static async saveSoundEnabled(context: Context, enabled: boolean): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    await prefs.put(PREF_KEY_SOUND_ENABLED, enabled);
    await prefs.flush();
  }

  static async loadSoundEnabled(context: Context): Promise<boolean> {
    try {
      const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
      return await prefs.get(PREF_KEY_SOUND_ENABLED, true) as boolean;
    } catch {
      return true;
    }
  }

  static async saveSoundVolume(context: Context, volume: number): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    await prefs.put(PREF_KEY_SOUND_VOLUME, volume);
    await prefs.flush();
  }

  static async loadSoundVolume(context: Context): Promise<number> {
    try {
      const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
      return await prefs.get(PREF_KEY_SOUND_VOLUME, DEFAULT_SOUND_VOLUME) as number;
    } catch {
      return DEFAULT_SOUND_VOLUME;
    }
  }

  static async saveAmbientVolume(context: Context, volume: number): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    await prefs.put(PREF_KEY_AMBIENT_VOLUME, volume);
    await prefs.flush();
  }

  static async loadAmbientVolume(context: Context): Promise<number> {
    try {
      const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
      return await prefs.get(PREF_KEY_AMBIENT_VOLUME, DEFAULT_AMBIENT_VOLUME) as number;
    } catch {
      return DEFAULT_AMBIENT_VOLUME;
    }
  }

  static async saveTaskContext(context: Context, taskContext: TaskContext): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    await prefs.put(PREF_KEY_TASK_CONTEXT, JSON.stringify(taskContext));
    await prefs.flush();
  }

  static async loadTaskContext(context: Context): Promise<TaskContext> {
    const defaultValue: TaskContext = { task: '', project: '', tag: '', note: '', estimatedPomodoros: 1 };
    try {
      const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
      const raw = await prefs.get(PREF_KEY_TASK_CONTEXT, '');
      if (typeof raw === 'string' && raw.length > 0) {
        return JSON.parse(raw) as TaskContext;
      }
      return defaultValue;
    } catch {
      return defaultValue;
    }
  }
}
