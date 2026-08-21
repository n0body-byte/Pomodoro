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
  PREF_KEY_AI_SERVICE_ENDPOINT,
  PREF_KEY_AI_AGENT_STATE,
  PREF_KEY_AI_CONVERSATION_INDEX,
  PREF_KEY_AI_CONVERSATION_PREFIX,
  PREF_KEY_AI_AUTO_REVIEW,
  DEFAULT_WORK_SECONDS,
  DEFAULT_BREAK_SECONDS,
  DEFAULT_DAILY_TARGET,
  DEFAULT_LONG_BREAK_SECONDS,
  DEFAULT_LONG_BREAK_INTERVAL,
  DEFAULT_SOUND_VOLUME,
  DEFAULT_AMBIENT_VOLUME
} from '../common/Constants';
import {
  AiAgentMemory,
  AiAgentState,
  AiChatMessage,
  AiConversationSummary,
  AiGoalDriftInsight,
  AiPlan,
  AiPlanStep
} from './AiAgentModels';

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

  static async saveAiServiceEndpoint(context: Context, endpoint: string): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    await prefs.put(PREF_KEY_AI_SERVICE_ENDPOINT, endpoint.trim());
    await prefs.flush();
  }

  static async loadAiServiceEndpoint(context: Context): Promise<string> {
    try {
      const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
      return await prefs.get(PREF_KEY_AI_SERVICE_ENDPOINT, '') as string;
    } catch {
      return '';
    }
  }

  static async saveAiAutoReview(context: Context, enabled: boolean): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    await prefs.put(PREF_KEY_AI_AUTO_REVIEW, enabled);
    await prefs.flush();
  }

  static async loadAiAutoReview(context: Context): Promise<boolean> {
    try {
      const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
      return await prefs.get(PREF_KEY_AI_AUTO_REVIEW, false) as boolean;
    } catch {
      return false;
    }
  }

  static async saveAiAgentState(context: Context, state: AiAgentState): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    await prefs.put(PREF_KEY_AI_AGENT_STATE, JSON.stringify(state));
    await prefs.flush();
  }

  static async loadAiAgentState(context: Context): Promise<AiAgentState> {
    const emptyMessages: AiChatMessage[] = [];
    const emptySteps: AiPlanStep[] = [];
    const emptyPlan: AiPlan = { summary: '', steps: emptySteps };
    const emptyState: AiAgentState = {
      id: '',
      title: '',
      createdAt: 0,
      messages: emptyMessages,
      plan: emptyPlan,
      updatedAt: 0,
      needsReview: false,
      lastCompletedStepTitle: ''
    };
    try {
      const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
      const raw = await prefs.get(PREF_KEY_AI_AGENT_STATE, '');
      if (typeof raw !== 'string' || raw.length === 0) {
        return emptyState;
      }
      const state = JSON.parse(raw) as AiAgentState;
      if (!Array.isArray(state.messages) || state.plan === undefined || !Array.isArray(state.plan.steps)) {
        return emptyState;
      }
      let title = typeof state.title === 'string' ? state.title.trim() : '';
      if (title.length === 0) {
        for (const message of state.messages) {
          if (message.role === 'user' && message.content.trim().length > 0) {
            title = message.content.trim().substring(0, 24);
            break;
          }
        }
      }
      let memory: AiAgentMemory | undefined = undefined;
      if (state.memory !== undefined) {
        memory = {
          primaryGoal: typeof state.memory.primaryGoal === 'string' ? state.memory.primaryGoal : '',
          longTermSummary: typeof state.memory.longTermSummary === 'string' ?
            state.memory.longTermSummary : '暂无长期专注数据。',
          shortTermSummary: typeof state.memory.shortTermSummary === 'string' ?
            state.memory.shortTermSummary : '暂无正在执行的计划。',
          updatedAt: typeof state.memory.updatedAt === 'number' ? state.memory.updatedAt : 0
        };
      }
      let goalDrift: AiGoalDriftInsight | undefined = undefined;
      if (state.goalDrift !== undefined) {
        goalDrift = {
          status: typeof state.goalDrift.status === 'string' ? state.goalDrift.status : 'none',
          title: typeof state.goalDrift.title === 'string' ? state.goalDrift.title : '目标保持一致',
          description: typeof state.goalDrift.description === 'string' ?
            state.goalDrift.description : '暂无需要处理的目标偏航。',
          similarityPercent: typeof state.goalDrift.similarityPercent === 'number' ?
            state.goalDrift.similarityPercent : 100
        };
      }
      return {
        id: typeof state.id === 'string' && state.id.length > 0 ? state.id : `ai-${Date.now()}`,
        title: title.length > 0 ? title : '未命名对话',
        createdAt: typeof state.createdAt === 'number' && state.createdAt > 0 ?
          state.createdAt : (state.updatedAt > 0 ? state.updatedAt : Date.now()),
        messages: state.messages,
        plan: state.plan,
        updatedAt: state.updatedAt,
        needsReview: state.needsReview === true,
        lastCompletedStepTitle: typeof state.lastCompletedStepTitle === 'string' ?
          state.lastCompletedStepTitle : '',
        availableMinutes: typeof state.availableMinutes === 'number' && state.availableMinutes > 0 ?
          Math.round(state.availableMinutes) : 120,
        deadline: typeof state.deadline === 'string' ? state.deadline : '',
        primaryGoal: typeof state.primaryGoal === 'string' ? state.primaryGoal : '',
        memory: memory,
        goalDrift: goalDrift,
        lastAutoReviewAttemptTitle: typeof state.lastAutoReviewAttemptTitle === 'string' ?
          state.lastAutoReviewAttemptTitle : '',
        lastExecutionReplanKey: typeof state.lastExecutionReplanKey === 'string' ?
          state.lastExecutionReplanKey : '',
        planSource: typeof state.planSource === 'string' ? state.planSource : 'none'
      };
    } catch {
      return emptyState;
    }
  }

  static async loadAiConversationHistory(context: Context): Promise<AiConversationSummary[]> {
    const emptyHistory: AiConversationSummary[] = [];
    try {
      const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
      const raw = await prefs.get(PREF_KEY_AI_CONVERSATION_INDEX, '');
      if (typeof raw !== 'string' || raw.length === 0) {
        return emptyHistory;
      }
      const history = JSON.parse(raw) as AiConversationSummary[];
      if (!Array.isArray(history)) {
        return emptyHistory;
      }
      return history;
    } catch {
      return emptyHistory;
    }
  }

  static async archiveAiConversation(context: Context, state: AiAgentState): Promise<void> {
    if (state.id.length === 0 || (state.messages.length === 0 && state.plan.steps.length === 0)) {
      return;
    }
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    const rawIndex = await prefs.get(PREF_KEY_AI_CONVERSATION_INDEX, '');
    let oldHistory: AiConversationSummary[] = [];
    if (typeof rawIndex === 'string' && rawIndex.length > 0) {
      try {
        const parsed = JSON.parse(rawIndex) as AiConversationSummary[];
        if (Array.isArray(parsed)) {
          oldHistory = parsed;
        }
      } catch {
        oldHistory = [];
      }
    }
    let completedStepCount = 0;
    for (const step of state.plan.steps) {
      if (step.completed) {
        completedStepCount += 1;
      }
    }
    const history: AiConversationSummary[] = [{
      id: state.id,
      title: state.title.length > 0 ? state.title : '未命名对话',
      createdAt: state.createdAt,
      updatedAt: state.updatedAt,
      messageCount: state.messages.length,
      stepCount: state.plan.steps.length,
      completedStepCount: completedStepCount
    }];
    for (const item of oldHistory) {
      if (item.id !== state.id && history.length < 20) {
        history.push(item);
      }
    }
    await prefs.put(`${PREF_KEY_AI_CONVERSATION_PREFIX}${state.id}`, JSON.stringify(state));
    await prefs.put(PREF_KEY_AI_CONVERSATION_INDEX, JSON.stringify(history));
    await prefs.flush();
  }

  static async loadArchivedAiConversation(context: Context, id: string): Promise<AiAgentState | undefined> {
    try {
      const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
      const raw = await prefs.get(`${PREF_KEY_AI_CONVERSATION_PREFIX}${id}`, '');
      if (typeof raw !== 'string' || raw.length === 0) {
        return undefined;
      }
      const state = JSON.parse(raw) as AiAgentState;
      if (!Array.isArray(state.messages) || state.plan === undefined || !Array.isArray(state.plan.steps)) {
        return undefined;
      }
      return state;
    } catch {
      return undefined;
    }
  }

  static async removeArchivedAiConversation(context: Context, id: string): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    const oldHistory = await PreferencesHelper.loadAiConversationHistory(context);
    const history: AiConversationSummary[] = [];
    for (const item of oldHistory) {
      if (item.id !== id) {
        history.push(item);
      }
    }
    await prefs.delete(`${PREF_KEY_AI_CONVERSATION_PREFIX}${id}`);
    await prefs.put(PREF_KEY_AI_CONVERSATION_INDEX, JSON.stringify(history));
    await prefs.flush();
  }

  static async clearAiAgentState(context: Context): Promise<void> {
    const prefs = await preferences.getPreferences(context, PREFERENCES_STORE_NAME);
    await prefs.delete(PREF_KEY_AI_AGENT_STATE);
    await prefs.flush();
  }

  static async markAiPlanStepCompleted(context: Context, task: string, project: string): Promise<void> {
    if (task.length === 0) {
      return;
    }
    const state = await PreferencesHelper.loadAiAgentState(context);
    let matched = false;
    const updatedSteps: AiPlanStep[] = [];
    for (const step of state.plan.steps) {
      if (!matched && !step.completed && step.title === task && step.project === project) {
        updatedSteps.push({
          title: step.title,
          project: step.project,
          tag: step.tag,
          note: step.note,
          estimatedPomodoros: step.estimatedPomodoros,
          reason: step.reason,
          completed: true
        });
        matched = true;
      } else {
        updatedSteps.push(step);
      }
    }
    if (!matched) {
      return;
    }
    const updatedPlan: AiPlan = { summary: state.plan.summary, steps: updatedSteps };
    await PreferencesHelper.saveAiAgentState(context, {
      id: state.id,
      title: state.title,
      createdAt: state.createdAt,
      messages: state.messages,
      plan: updatedPlan,
      updatedAt: Date.now(),
      needsReview: true,
      lastCompletedStepTitle: task,
      availableMinutes: state.availableMinutes,
      deadline: state.deadline,
      primaryGoal: state.primaryGoal,
      memory: state.memory,
      goalDrift: state.goalDrift,
      lastAutoReviewAttemptTitle: state.lastAutoReviewAttemptTitle,
      lastExecutionReplanKey: state.lastExecutionReplanKey,
      planSource: state.planSource
    });
  }
}
