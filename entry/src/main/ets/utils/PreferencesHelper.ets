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
  DEFAULT_WORK_SECONDS,
  DEFAULT_BREAK_SECONDS,
  DEFAULT_DAILY_TARGET
} from '../common/Constants';

export interface SessionRecord {
  date: string;
  workSeconds: number;
  completedAt: number;
  type?: 'work' | 'break';
}

export interface TimerState {
  remainingSeconds: number;
  totalSeconds: number;
  isWorkMode: boolean;
  isRunning: boolean;
  completedSessions: number;
  savedAt: number;
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
    return history.filter((r: SessionRecord) => r.date === todayStr && r.type !== 'break').length;
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
      if (statsMap[record.date] !== undefined) {
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

  static async saveTimerState(context: Context, state: TimerState): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    await prefs.put(PREF_KEY_TIMER_STATE, JSON.stringify(state));
    await prefs.flush();
  }

  static async saveTheme(context: Context, isDark: boolean): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    await prefs.put(PREF_KEY_THEME, isDark);
    await prefs.flush();
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
