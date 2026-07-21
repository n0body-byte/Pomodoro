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
  DEFAULT_WORK_SECONDS,
  DEFAULT_BREAK_SECONDS,
  DEFAULT_DAILY_TARGET
} from '../common/Constants';

export interface SessionRecord {
  date: string;
  workSeconds: number;
  completedAt: number;
  type?: 'work' | 'break';
  status?: 'completed' | 'abandoned' | 'skipped';
  plannedSeconds?: number;
}

export interface TimerState {
  remainingSeconds: number;
  totalSeconds: number;
  isWorkMode: boolean;
  isRunning: boolean;
  completedSessions: number;
  savedAt: number;
  deadlineAt?: number;
}

export interface DailyStats {
  date: string;
  totalSeconds: number;
}

export class PreferencesHelper {
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
}
