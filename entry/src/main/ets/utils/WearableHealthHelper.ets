export type HeartRateScenario = 'steady' | 'stress' | 'movement' | 'disconnected';

export type HeartRateQuality = 'good' | 'poor' | 'none';

export type WearableRecommendationLevel = 'normal' | 'observe' | 'recover' | 'unavailable';

export type WearableRecoveryAction = 'resume' | 'shorten' | 'end';

export interface HeartRateSample {
  bpm: number;
  quality: HeartRateQuality;
  hasMotion: boolean;
  isWorn: boolean;
  sampledAt: number;
}

export interface WearableHealthSnapshot {
  bpm: number;
  medianBpm: number;
  baselineBpm: number;
  trendBpm: number;
  highLoadSeconds: number;
  sampleCount: number;
  confidencePercent: number;
  quality: HeartRateQuality;
  hasMotion: boolean;
  isWorn: boolean;
  sampledAt: number;
}

export interface WearableRecommendation {
  level: WearableRecommendationLevel;
  title: string;
  description: string;
  actionLabel: string;
  canAdjustPlan: boolean;
}

export interface WearableCalibrationResult {
  success: boolean;
  baselineBpm: number;
  message: string;
}

export interface WearableAdjustmentRequest {
  id: string;
  createdAt: number;
  currentTask: string;
  recommendationTitle: string;
  summary: string;
  allowedActions: string[];
  protectedRules: string[];
}

export interface WearableRecoveryResolution {
  remainingSeconds: number;
  totalSeconds: number;
  shouldResume: boolean;
  shouldFinish: boolean;
}

export interface HeartRateProvider {
  setScenario(scenario: HeartRateScenario): void;
  nextSample(tick: number, sampledAt: number): HeartRateSample;
}

/**
 * 无真机阶段使用的确定性逐样本数据源。真实设备接入时只需实现 HeartRateProvider，
 * 滑动窗口、规则引擎和界面不需要知道数据来自模拟器还是真实传感器。
 */
export class MockHeartRateProvider implements HeartRateProvider {
  private scenario: HeartRateScenario = 'steady';

  setScenario(scenario: HeartRateScenario): void {
    this.scenario = scenario;
  }

  nextSample(tick: number, sampledAt: number): HeartRateSample {
    const safeTick = Math.max(0, tick);
    if (this.scenario === 'stress') {
      return {
        bpm: 98 + safeTick % 8,
        quality: 'good',
        hasMotion: false,
        isWorn: true,
        sampledAt: sampledAt
      };
    }
    if (this.scenario === 'movement') {
      return {
        bpm: 108 + safeTick % 12,
        quality: 'good',
        hasMotion: true,
        isWorn: true,
        sampledAt: sampledAt
      };
    }
    if (this.scenario === 'disconnected') {
      return {
        bpm: 0,
        quality: 'none',
        hasMotion: false,
        isWorn: false,
        sampledAt: sampledAt
      };
    }
    return {
      bpm: 73 + safeTick % 5,
      quality: 'good',
      hasMotion: false,
      isWorn: true,
      sampledAt: sampledAt
    };
  }
}

export class WearableHealthHelper {
  static emptySnapshot(baselineBpm: number = 75): WearableHealthSnapshot {
    return {
      bpm: 0,
      medianBpm: 0,
      baselineBpm: WearableHealthHelper.normalizeBaseline(baselineBpm),
      trendBpm: 0,
      highLoadSeconds: 0,
      sampleCount: 0,
      confidencePercent: 0,
      quality: 'none',
      hasMotion: false,
      isWorn: false,
      sampledAt: 0
    };
  }

  static emptyAdjustmentRequest(): WearableAdjustmentRequest {
    return {
      id: '',
      createdAt: 0,
      currentTask: '',
      recommendationTitle: '',
      summary: '',
      allowedActions: [],
      protectedRules: []
    };
  }

  static normalizeBaseline(value: number): number {
    if (!Number.isFinite(value)) {
      return 75;
    }
    return Math.max(45, Math.min(120, Math.round(value)));
  }

  static appendSample(samples: HeartRateSample[], sample: HeartRateSample,
    maxSamples: number = 12): HeartRateSample[] {
    const limit = Math.max(3, Math.min(60, Math.round(maxSamples)));
    const next: HeartRateSample[] = [];
    const start = Math.max(0, samples.length - limit + 1);
    for (let index = start; index < samples.length; index++) {
      next.push(samples[index]);
    }
    next.push(sample);
    return next;
  }

  static summarize(samples: HeartRateSample[], baselineBpm: number,
    previousHighLoadSeconds: number, sampleSpanSeconds: number = 1): WearableHealthSnapshot {
    const baseline = WearableHealthHelper.normalizeBaseline(baselineBpm);
    const valid: HeartRateSample[] = [];
    for (const sample of samples) {
      if (sample.isWorn && sample.quality !== 'none' && sample.bpm >= 35 && sample.bpm <= 220) {
        valid.push(sample);
      }
    }
    if (valid.length === 0) {
      return WearableHealthHelper.emptySnapshot(baseline);
    }

    const values: number[] = [];
    let hasMotion = false;
    for (const sample of valid) {
      values.push(sample.bpm);
      if (sample.hasMotion) {
        hasMotion = true;
      }
    }
    values.sort((left: number, right: number) => left - right);
    const middle = Math.floor(values.length / 2);
    const median = values.length % 2 === 0 ?
      Math.round((values[middle - 1] + values[middle]) / 2) : values[middle];
    const latest = valid[valid.length - 1];
    const trend = latest.bpm - valid[0].bpm;
    const confidence = Math.min(100, Math.round(valid.length / 8 * 100));
    const quality: HeartRateQuality = valid.length >= 5 ? 'good' : 'poor';
    const delta = median - baseline;
    const span = Math.max(1, Math.round(sampleSpanSeconds));
    const highLoad = delta >= 20 && !hasMotion && quality === 'good' ?
      Math.max(0, previousHighLoadSeconds) + span : 0;
    return {
      bpm: latest.bpm,
      medianBpm: median,
      baselineBpm: baseline,
      trendBpm: trend,
      highLoadSeconds: highLoad,
      sampleCount: valid.length,
      confidencePercent: confidence,
      quality: quality,
      hasMotion: hasMotion,
      isWorn: latest.isWorn,
      sampledAt: latest.sampledAt
    };
  }

  static calibrateBaseline(snapshot: WearableHealthSnapshot,
    currentBaselineBpm: number): WearableCalibrationResult {
    const current = WearableHealthHelper.normalizeBaseline(currentBaselineBpm);
    if (!snapshot.isWorn || snapshot.quality !== 'good' || snapshot.sampleCount < 5) {
      return { success: false, baselineBpm: current, message: '请保持佩戴并等待至少 5 个可靠样本' };
    }
    if (snapshot.hasMotion) {
      return { success: false, baselineBpm: current, message: '检测到活动，请静坐后再校准' };
    }
    if (snapshot.medianBpm < 45 || snapshot.medianBpm > 110) {
      return { success: false, baselineBpm: current, message: '当前窗口不适合建立静息基线' };
    }
    if (snapshot.medianBpm - current >= 20) {
      return { success: false, baselineBpm: current, message: '当前负荷偏高，请在平稳状态下校准' };
    }
    const calibrated = WearableHealthHelper.normalizeBaseline(
      Math.round(current * 0.3 + snapshot.medianBpm * 0.7));
    return { success: true, baselineBpm: calibrated, message: `个人基线已更新为 ${calibrated} BPM` };
  }

  static evaluate(snapshot: WearableHealthSnapshot): WearableRecommendation {
    if (!snapshot.isWorn || snapshot.quality === 'none' || snapshot.sampleCount < 3) {
      return {
        level: 'unavailable',
        title: '等待可靠数据',
        description: '设备未佩戴、已断连或样本不足，当前不会调整计划。',
        actionLabel: '',
        canAdjustPlan: false
      };
    }
    if (snapshot.quality === 'poor' || snapshot.confidencePercent < 60) {
      return {
        level: 'observe',
        title: '样本仍在积累',
        description: '当前置信度不足，只展示趋势，不触发恢复或计划调整。',
        actionLabel: '',
        canAdjustPlan: false
      };
    }

    const baselineDelta = snapshot.medianBpm - snapshot.baselineBpm;
    if (snapshot.hasMotion && baselineDelta >= 20) {
      return {
        level: 'observe',
        title: '检测到运动干扰',
        description: '心率升高可能来自活动，保持观察，不自动改变专注计划。',
        actionLabel: '查看受控调整',
        canAdjustPlan: true
      };
    }

    if (baselineDelta >= 20 && snapshot.highLoadSeconds >= 120) {
      return {
        level: 'recover',
        title: '建议暂停并短暂恢复',
        description: '聚合心率持续高于个人基线，建议进入两分钟恢复，再决定是否调整计划。',
        actionLabel: '查看受控调整',
        canAdjustPlan: true
      };
    }

    if (baselineDelta >= 15 && snapshot.trendBpm >= 5) {
      return {
        level: 'observe',
        title: '专注负荷正在上升',
        description: '先保持观察；只有趋势持续存在时才建议调整，避免单次读数误判。',
        actionLabel: '查看受控调整',
        canAdjustPlan: true
      };
    }

    return {
      level: 'normal',
      title: '当前状态平稳',
      description: '心率与个人基线接近，继续当前节奏，不需要修改计划。',
      actionLabel: '',
      canAdjustPlan: false
    };
  }

  static createAdjustmentRequest(snapshot: WearableHealthSnapshot,
    recommendation: WearableRecommendation, currentTask: string, createdAt: number): WearableAdjustmentRequest {
    const task = currentTask.trim().length > 0 ? currentTask.trim() : '当前专注任务';
    const motion = snapshot.hasMotion ? '检测到活动干扰' : '未检测到明显活动干扰';
    return {
      id: `wearable-${createdAt}`,
      createdAt: createdAt,
      currentTask: task,
      recommendationTitle: recommendation.title,
      summary: `窗口中位数 ${snapshot.medianBpm} BPM，个人基线 ${snapshot.baselineBpm} BPM，` +
        `持续高负荷 ${snapshot.highLoadSeconds} 秒，置信度 ${snapshot.confidencePercent}%，${motion}`,
      allowedActions: ['缩短下一轮专注', '增加短休息', '拆小当前步骤', '延后非关键步骤', '保持计划不变'],
      protectedRules: ['不得自动完成或删除任务', '不得改变用户总目标', '不得进行医学判断']
    };
  }

  static resolveRecoveryAction(action: WearableRecoveryAction,
    remainingSeconds: number, totalSeconds: number): WearableRecoveryResolution {
    const safeTotal = Math.max(1, Math.round(totalSeconds));
    const safeRemaining = Math.max(0, Math.min(safeTotal, Math.round(remainingSeconds)));
    if (action === 'end') {
      return {
        remainingSeconds: safeRemaining,
        totalSeconds: safeTotal,
        shouldResume: false,
        shouldFinish: true
      };
    }
    if (action === 'shorten') {
      const elapsedSeconds = safeTotal - safeRemaining;
      const shortenedRemaining = Math.min(safeRemaining, Math.max(60, safeRemaining - 5 * 60));
      return {
        remainingSeconds: shortenedRemaining,
        totalSeconds: elapsedSeconds + shortenedRemaining,
        shouldResume: shortenedRemaining > 0,
        shouldFinish: shortenedRemaining <= 0
      };
    }
    return {
      remainingSeconds: safeRemaining,
      totalSeconds: safeTotal,
      shouldResume: safeRemaining > 0,
      shouldFinish: safeRemaining <= 0
    };
  }

  static buildAgentPrompt(request: WearableAdjustmentRequest): string {
    return `穿戴端对“${request.currentTask}”给出状态建议：${request.recommendationTitle}。` +
      `仅提供聚合数据：${request.summary}。` +
      `只允许从以下动作中选择：${request.allowedActions.join('、')}。` +
      `必须遵守：${request.protectedRules.join('；')}。` +
      '请结合剩余时间和既有计划，给出幅度最小、可以立即执行的调整，并解释为何选择该动作。';
  }

  static scenarioLabel(scenario: HeartRateScenario): string {
    if (scenario === 'stress') {
      return '压力升高';
    }
    if (scenario === 'movement') {
      return '运动干扰';
    }
    if (scenario === 'disconnected') {
      return '设备断连';
    }
    return '平稳专注';
  }
}
