export interface AiDeadlineInsight {
  status: string;
  deadlineAt: number;
  remainingMinutes: number;
  effectiveAvailableMinutes: number;
  normalizedDeadline: string;
  title: string;
  description: string;
}

export class AiDeadlineHelper {
  private static pad(value: number): string {
    return value < 10 ? `0${value}` : `${value}`;
  }

  private static format(timestamp: number): string {
    const value = new Date(timestamp);
    return `${value.getFullYear()}-${AiDeadlineHelper.pad(value.getMonth() + 1)}-` +
      `${AiDeadlineHelper.pad(value.getDate())} ${AiDeadlineHelper.pad(value.getHours())}:` +
      `${AiDeadlineHelper.pad(value.getMinutes())}`;
  }

  private static compactParts(value: string): string[] {
    const raw = value.replace('　', ' ').split(' ');
    const result: string[] = [];
    for (const part of raw) {
      if (part.trim().length > 0) {
        result.push(part.trim());
      }
    }
    return result;
  }

  private static parseClock(value: string, defaultHour: number,
    defaultMinute: number): number {
    const normalized = value.trim().split('：').join(':');
    if (normalized.length === 0) {
      return defaultHour * 60 + defaultMinute;
    }
    const parts = normalized.split(':');
    if (parts.length !== 2) {
      return -1;
    }
    const hour = Number(parts[0]);
    const minute = Number(parts[1]);
    if (!Number.isInteger(hour) || !Number.isInteger(minute) ||
      hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      return -1;
    }
    return hour * 60 + minute;
  }

  private static atLocalClock(base: Date, dayOffset: number, clockMinutes: number): number {
    return new Date(base.getFullYear(), base.getMonth(), base.getDate() + dayOffset,
      Math.floor(clockMinutes / 60), clockMinutes % 60, 0, 0).getTime();
  }

  private static parseAbsolute(value: string): number {
    const parts = AiDeadlineHelper.compactParts(value.split('/').join('-'));
    if (parts.length !== 2) {
      return 0;
    }
    const dateParts = parts[0].split('-');
    const clockMinutes = AiDeadlineHelper.parseClock(parts[1], 23, 59);
    if (dateParts.length !== 3 || clockMinutes < 0) {
      return 0;
    }
    const year = Number(dateParts[0]);
    const month = Number(dateParts[1]);
    const day = Number(dateParts[2]);
    if (!Number.isInteger(year) || !Number.isInteger(month) || !Number.isInteger(day) ||
      year < 2020 || year > 2100 || month < 1 || month > 12 || day < 1 || day > 31) {
      return 0;
    }
    const parsed = new Date(year, month - 1, day, Math.floor(clockMinutes / 60),
      clockMinutes % 60, 0, 0);
    if (parsed.getFullYear() !== year || parsed.getMonth() !== month - 1 ||
      parsed.getDate() !== day) {
      return 0;
    }
    return parsed.getTime();
  }

  private static parseRelative(value: string, now: number): number {
    const base = new Date(now);
    const relativeDays: string[] = ['今天', '今晚', '明天', '后天'];
    const dayOffsets: number[] = [0, 0, 1, 2];
    const defaultHours: number[] = [23, 22, 18, 18];
    for (let index = 0; index < relativeDays.length; index++) {
      const prefix = relativeDays[index];
      if (value.indexOf(prefix) === 0) {
        const clock = AiDeadlineHelper.parseClock(
          value.substring(prefix.length).trim(), defaultHours[index], 0);
        return clock < 0 ? 0 : AiDeadlineHelper.atLocalClock(base, dayOffsets[index], clock);
      }
    }

    if (value.endsWith('小时后')) {
      const hours = Number(value.substring(0, value.length - 3).trim());
      return Number.isFinite(hours) && hours > 0 && hours <= 24 * 14 ?
        now + Math.round(hours * 60 * 60 * 1000) : 0;
    }
    if (value.endsWith('分钟后')) {
      const minutes = Number(value.substring(0, value.length - 3).trim());
      return Number.isFinite(minutes) && minutes > 0 && minutes <= 24 * 14 * 60 ?
        now + Math.round(minutes * 60 * 1000) : 0;
    }

    if (value.indexOf('周') === 0 && value.length >= 2) {
      const weekday = '日一二三四五六'.indexOf(value.substring(1, 2));
      if (weekday < 0) {
        return 0;
      }
      const clock = AiDeadlineHelper.parseClock(value.substring(2).trim(), 18, 0);
      if (clock < 0) {
        return 0;
      }
      let dayOffset = weekday - base.getDay();
      const todayTarget = AiDeadlineHelper.atLocalClock(base, 0, clock);
      if (dayOffset < 0 || (dayOffset === 0 && todayTarget <= now)) {
        dayOffset += 7;
      }
      return AiDeadlineHelper.atLocalClock(base, dayOffset, clock);
    }
    return 0;
  }

  static evaluate(deadline: string, availableMinutes: number,
    now: number = Date.now()): AiDeadlineInsight {
    const normalizedAvailable = Math.max(0, Math.min(1440, Math.round(availableMinutes)));
    const text = deadline.trim();
    if (text.length === 0) {
      return {
        status: 'none', deadlineAt: 0, remainingMinutes: normalizedAvailable,
        effectiveAvailableMinutes: normalizedAvailable, normalizedDeadline: '',
        title: '未设置截止时间', description: '计划仅按手动设置的可用时间计算。'
      };
    }
    let deadlineAt = AiDeadlineHelper.parseAbsolute(text);
    if (deadlineAt <= 0) {
      deadlineAt = AiDeadlineHelper.parseRelative(text, now);
    }
    if (deadlineAt <= 0) {
      return {
        status: 'unsupported', deadlineAt: 0, remainingMinutes: normalizedAvailable,
        effectiveAvailableMinutes: normalizedAvailable, normalizedDeadline: text,
        title: '无法识别截止时间',
        description: '请使用“今晚 22:00”“明天 18:00”“周五 18:00”或“2026-08-25 18:00”。'
      };
    }
    const remainingMinutes = Math.floor((deadlineAt - now) / (60 * 1000));
    if (remainingMinutes <= 0) {
      return {
        status: 'expired', deadlineAt: deadlineAt, remainingMinutes: 0,
        effectiveAvailableMinutes: 0, normalizedDeadline: AiDeadlineHelper.format(deadlineAt),
        title: '截止时间已过', description: '请更新或清除截止时间后再生成计划。'
      };
    }
    const effective = Math.min(normalizedAvailable, remainingMinutes);
    return {
      status: 'valid', deadlineAt: deadlineAt, remainingMinutes: remainingMinutes,
      effectiveAvailableMinutes: effective, normalizedDeadline: AiDeadlineHelper.format(deadlineAt),
      title: effective < normalizedAvailable ? '截止时间已收紧容量' : '截止时间可行',
      description: effective < normalizedAvailable ?
        `距截止还有 ${remainingMinutes} 分钟，计划容量已从 ${normalizedAvailable} 分钟收紧为 ${effective} 分钟。` :
        `距截止还有 ${remainingMinutes} 分钟，本轮仍按 ${normalizedAvailable} 分钟可用时间规划。`
    };
  }
}
