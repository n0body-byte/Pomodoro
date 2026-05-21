import { PreferencesHelper, SessionRecord } from './PreferencesHelper';

export interface AchievementDef {
  id: string;
  name: string;
  desc: string;
  category: 'milestone' | 'streak' | 'champion' | 'time';
  unlocked: boolean;
}

export class AchievementHelper {
  static async compute(context: Context): Promise<AchievementDef[]> {
    const history = await PreferencesHelper.loadSessionHistory(context);
    const workRecords = history.filter((r: SessionRecord) => r.type !== 'break');

    // 1. 总工作 session 数量
    const totalCount = workRecords.length;

    // 2. 每日最高番茄数
    const dayMap: Record<string, number> = {};
    for (const r of workRecords) {
      dayMap[r.date] = (dayMap[r.date] || 0) + 1;
    }
    const dates = Object.keys(dayMap).sort();
    let maxDaily = 0;
    for (const d of dates) {
      if (dayMap[d] > maxDaily) {
        maxDaily = dayMap[d];
      }
    }

    // 3. 连续天数 & 全勤周
    let streak = 0;
    let maxStreak = 0;
    const today = new Date();
    const todayStr = `${today.getFullYear()}-${(today.getMonth() + 1).toString().padStart(2, '0')}-${today.getDate().toString().padStart(2, '0')}`;
    const yesterdayStr = (() => {
      const y = new Date(today);
      y.setDate(y.getDate() - 1);
      return `${y.getFullYear()}-${(y.getMonth() + 1).toString().padStart(2, '0')}-${y.getDate().toString().padStart(2, '0')}`;
    })();
    let fullWeekBonus = false;
    let currentStreak = 0;
    for (let i = dates.length - 1; i >= 0; i--) {
      if (i === dates.length - 1) {
        currentStreak = 1;
        continue;
      }
      const prev = new Date(dates[i]);
      const next = new Date(dates[i + 1]);
      const diff = Math.floor((next.getTime() - prev.getTime()) / 86400000);
      if (diff === 1) {
        currentStreak += 1;
      } else {
        if (currentStreak > maxStreak) {
          maxStreak = currentStreak;
        }
        currentStreak = 1;
      }
    }
    if (currentStreak > maxStreak) {
      maxStreak = currentStreak;
    }
    // 当前连续天数：从今天（或昨天）往前数
    const refDate = dayMap[todayStr] ? todayStr : (dayMap[yesterdayStr] ? yesterdayStr : '');
    if (refDate !== '') {
      streak = 1;
      const ref = new Date(refDate);
      for (let d = 1; d < 366; d++) {
        const check = new Date(ref);
        check.setDate(check.getDate() - d);
        const checkStr = `${check.getFullYear()}-${(check.getMonth() + 1).toString().padStart(2, '0')}-${check.getDate().toString().padStart(2, '0')}`;
        if (dayMap[checkStr]) {
          streak += 1;
        } else {
          break;
        }
      }
    }
    // 全勤周：检查是否存在任意连续7天
    if (maxStreak >= 7) {
      fullWeekBonus = true;
    }

    // 4. 时段检查（从 SessionRecord.completedAt 获取小时）
    let hasEarlyBird = false;
    let hasNightOwl = false;
    for (const r of history) {
      if (r.type === 'break') {
        continue;
      }
      const hour = new Date(r.completedAt).getHours();
      if (hour >= 6 && hour < 8) {
        hasEarlyBird = true;
      }
      if (hour >= 22 && hour < 24) {
        hasNightOwl = true;
      }
    }

    // 5. 周/月总时长
    let weeklyMaxSeconds = 0;
    let monthlyMaxSeconds = 0;
    const weekMap: Record<string, number> = {};
    const monthMap: Record<string, number> = {};
    for (const r of workRecords) {
      const d = new Date(r.date);
      // 周 key: 年份 + 周数（以周一为准）
      const dayOfWeek = d.getDay();
      const mondayOffset = dayOfWeek === 0 ? -6 : (1 - dayOfWeek);
      const mon = new Date(d);
      mon.setDate(d.getDate() + mondayOffset);
      const weekKey = `${mon.getFullYear()}-W${Math.ceil((mon.getMonth() * 30 + mon.getDate()) / 7)}`;
      weekMap[weekKey] = (weekMap[weekKey] || 0) + r.workSeconds;
      // 月 key
      const monthKey = `${d.getFullYear()}-${d.getMonth() + 1}`;
      monthMap[monthKey] = (monthMap[monthKey] || 0) + r.workSeconds;
    }
    for (const k of Object.keys(weekMap)) {
      if (weekMap[k] > weeklyMaxSeconds) {
        weeklyMaxSeconds = weekMap[k];
      }
    }
    for (const k of Object.keys(monthMap)) {
      if (monthMap[k] > monthlyMaxSeconds) {
        monthlyMaxSeconds = monthMap[k];
      }
    }

    const checks: AchievementDef[] = [
      { id: 'first_tomato',   name: '初次番茄',   desc: '完成第1个番茄',            category: 'milestone', unlocked: totalCount >= 1 },
      { id: 'ten_tomatoes',   name: '番茄新秀',   desc: '累计完成10个番茄',          category: 'milestone', unlocked: totalCount >= 10 },
      { id: 'fifty_tomatoes', name: '番茄达人',   desc: '累计完成50个番茄',          category: 'milestone', unlocked: totalCount >= 50 },
      { id: 'hundred_tomatoes', name: '番茄大师', desc: '累计完成100个番茄',         category: 'milestone', unlocked: totalCount >= 100 },
      { id: 'streak_3',       name: '初显毅力',   desc: '连续3天专注',              category: 'streak',    unlocked: streak >= 3 },
      { id: 'streak_7',       name: '坚持一周',   desc: '连续7天专注',              category: 'streak',    unlocked: streak >= 7 },
      { id: 'daily_8',        name: '单日王者',   desc: '单日完成8个番茄',           category: 'champion',  unlocked: maxDaily >= 8 },
      { id: 'weekly_10h',     name: '周冠军',     desc: '一周专注超10小时',          category: 'champion',  unlocked: weeklyMaxSeconds >= 36000 },
      { id: 'monthly_40h',    name: '月冠军',     desc: '一月专注超40小时',          category: 'champion',  unlocked: monthlyMaxSeconds >= 144000 },
      { id: 'early_bird',     name: '早起鸟儿',   desc: '早上6-8点完成过番茄',       category: 'time',      unlocked: hasEarlyBird },
      { id: 'night_owl',      name: '夜猫子',     desc: '晚上22-24点完成过番茄',     category: 'time',      unlocked: hasNightOwl },
      { id: 'full_week',      name: '全勤周',     desc: '任意一周7天全勤',           category: 'streak',    unlocked: fullWeekBonus },
    ];
    return checks;
  }
}
