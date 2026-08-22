export interface FocusInsightRecord {
  workSeconds: number;
  completedAt: number;
  type?: 'work' | 'break';
  plannedSeconds?: number;
  focusRating?: number;
  energyRating?: number;
  interruptionReason?: string;
}

export interface FocusActionInsight {
  hasData: boolean;
  workSessions: number;
  bestPeriod: string;
  estimateAccuracyPercent: number;
  estimatedSessions: number;
  averageFocusRating: number;
  averageEnergyRating: number;
  reflectedSessions: number;
  reflectionCoveragePercent: number;
  recentWorkSeconds: number;
  previousWorkSeconds: number;
  trendStatus: string;
  trendPercent: number;
  topInterruption: string;
  actionTitle: string;
  actionDescription: string;
}

interface InterruptionCount {
  label: string;
  count: number;
}

interface FocusAction {
  title: string;
  description: string;
}

interface FocusTrend {
  status: string;
  percent: number;
}

export class FocusInsightHelper {
  static empty(): FocusActionInsight {
    return {
      hasData: false,
      workSessions: 0,
      bestPeriod: '待积累',
      estimateAccuracyPercent: 0,
      estimatedSessions: 0,
      averageFocusRating: 0,
      averageEnergyRating: 0,
      reflectedSessions: 0,
      reflectionCoveragePercent: 0,
      recentWorkSeconds: 0,
      previousWorkSeconds: 0,
      trendStatus: 'none',
      trendPercent: 0,
      topInterruption: '暂无',
      actionTitle: '完成第一轮专注',
      actionDescription: '完成计时并填写轻量复盘后，这里会给出基于真实记录的行动建议。'
    };
  }

  static analyze(records: FocusInsightRecord[], now: number = Date.now()): FocusActionInsight {
    const periods: number[] = [0, 0, 0, 0];
    const interruptions: InterruptionCount[] = [];
    let workCount = 0;
    let accuracyTotal = 0;
    let estimatedSessions = 0;
    let focusTotal = 0;
    let energyTotal = 0;
    let reflectedSessions = 0;
    let recentWorkSeconds = 0;
    let previousWorkSeconds = 0;
    const weekMilliseconds = 7 * 24 * 60 * 60 * 1000;

    for (const record of records) {
      if (record.type === 'break' || record.workSeconds <= 0) {
        continue;
      }
      workCount += 1;
      const age = now - record.completedAt;
      if (age >= 0 && age < weekMilliseconds) {
        recentWorkSeconds += record.workSeconds;
      } else if (age >= weekMilliseconds && age < weekMilliseconds * 2) {
        previousWorkSeconds += record.workSeconds;
      }
      const hour = new Date(record.completedAt).getHours();
      periods[FocusInsightHelper.periodIndex(hour)] += record.workSeconds;

      if (record.plannedSeconds !== undefined && record.plannedSeconds > 0) {
        const difference = Math.abs(record.workSeconds - record.plannedSeconds);
        accuracyTotal += Math.max(0, 1 - difference / record.plannedSeconds);
        estimatedSessions += 1;
      }

      if (record.focusRating !== undefined && record.energyRating !== undefined) {
        focusTotal += Math.max(1, Math.min(5, record.focusRating));
        energyTotal += Math.max(1, Math.min(5, record.energyRating));
        reflectedSessions += 1;
        const reason = record.interruptionReason !== undefined ? record.interruptionReason.trim() : '';
        if (reason.length > 0 && reason !== '无') {
          FocusInsightHelper.addInterruption(interruptions, reason);
        }
      }
    }

    if (workCount === 0) {
      return FocusInsightHelper.empty();
    }

    const bestPeriod = FocusInsightHelper.findBestPeriod(periods);
    const accuracy = estimatedSessions > 0 ? Math.round(accuracyTotal / estimatedSessions * 100) : 0;
    const averageFocus = reflectedSessions > 0 ?
      Math.round(focusTotal / reflectedSessions * 10) / 10 : 0;
    const averageEnergy = reflectedSessions > 0 ?
      Math.round(energyTotal / reflectedSessions * 10) / 10 : 0;
    const topInterruption = FocusInsightHelper.findTopInterruption(interruptions);
    const reflectionCoverage = Math.round(reflectedSessions / workCount * 100);
    const trend = FocusInsightHelper.calculateTrend(recentWorkSeconds, previousWorkSeconds);
    const action = FocusInsightHelper.buildAction(
      bestPeriod, accuracy, estimatedSessions, averageFocus, reflectedSessions,
      workCount, reflectionCoverage, topInterruption);

    return {
      hasData: true,
      workSessions: workCount,
      bestPeriod: bestPeriod,
      estimateAccuracyPercent: accuracy,
      estimatedSessions: estimatedSessions,
      averageFocusRating: averageFocus,
      averageEnergyRating: averageEnergy,
      reflectedSessions: reflectedSessions,
      reflectionCoveragePercent: reflectionCoverage,
      recentWorkSeconds: recentWorkSeconds,
      previousWorkSeconds: previousWorkSeconds,
      trendStatus: trend.status,
      trendPercent: trend.percent,
      topInterruption: topInterruption,
      actionTitle: action.title,
      actionDescription: action.description
    };
  }

  private static periodIndex(hour: number): number {
    if (hour >= 5 && hour < 12) return 0;
    if (hour >= 12 && hour < 18) return 1;
    if (hour >= 18 && hour < 23) return 2;
    return 3;
  }

  private static findBestPeriod(periods: number[]): string {
    const labels: string[] = ['上午', '下午', '晚上', '深夜'];
    let bestIndex = 0;
    for (let index = 1; index < periods.length; index++) {
      if (periods[index] > periods[bestIndex]) {
        bestIndex = index;
      }
    }
    return labels[bestIndex];
  }

  private static addInterruption(items: InterruptionCount[], label: string): void {
    for (const item of items) {
      if (item.label === label) {
        item.count += 1;
        return;
      }
    }
    items.push({ label: label, count: 1 });
  }

  private static findTopInterruption(items: InterruptionCount[]): string {
    if (items.length === 0) return '暂无';
    let best = items[0];
    for (let index = 1; index < items.length; index++) {
      if (items[index].count > best.count) {
        best = items[index];
      }
    }
    return best.label;
  }

  private static calculateTrend(recentSeconds: number, previousSeconds: number): FocusTrend {
    if (previousSeconds <= 0) {
      return recentSeconds > 0 ? { status: 'new', percent: 100 } : { status: 'none', percent: 0 };
    }
    const percent = Math.round((recentSeconds - previousSeconds) / previousSeconds * 100);
    if (Math.abs(percent) < 5) {
      return { status: 'steady', percent: percent };
    }
    return { status: percent > 0 ? 'up' : 'down', percent: percent };
  }

  private static buildAction(bestPeriod: string, accuracy: number, estimatedSessions: number,
    averageFocus: number, reflectedSessions: number, workSessions: number,
    reflectionCoverage: number, topInterruption: string): FocusAction {
    if (reflectedSessions === 0) {
      return {
        title: '补充一次轻量复盘',
        description: '下一轮结束后记录专注度、精力和打断原因，建议才会更贴合你的状态。'
      };
    }
    if (averageFocus <= 2.5) {
      return {
        title: '缩短下一轮并明确交付',
        description: '先安排 1 个番茄钟，只保留一个可核验产出，完成后再决定是否继续。'
      };
    }
    if (estimatedSessions >= 2 && accuracy < 70) {
      return {
        title: '重新校准任务估时',
        description: '最近计划时长与实际偏差较大，把任务拆小并参考相似历史记录重新估算。'
      };
    }
    if (workSessions >= 3 && reflectionCoverage < 50) {
      return {
        title: '连续完成 3 次轻量复盘',
        description: '当前反馈覆盖偏低，补充更多专注与精力评分后再依据洞察调整长期节奏。'
      };
    }
    if (topInterruption !== '暂无') {
      return {
        title: `优先处理“${topInterruption}”`,
        description: '开始前用一分钟移除主要打断源，再进入下一轮专注。'
      };
    }
    return {
      title: `把高价值任务放在${bestPeriod}`,
      description: `你的有效专注主要集中在${bestPeriod}，可优先安排最重要且最难的步骤。`
    };
  }
}
