export type HeartRateScenario = 'steady' | 'stress' | 'movement' | 'disconnected';

export type HeartRateQuality = 'good' | 'poor' | 'none';

export type WearableRecommendationLevel = 'normal' | 'observe' | 'recover' | 'unavailable';

export interface WearableHealthSnapshot {
  bpm: number;
  medianBpm: number;
  baselineBpm: number;
  trendBpm: number;
  highLoadSeconds: number;
  sampleCount: number;
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

export interface HeartRateProvider {
  setScenario(scenario: HeartRateScenario): void;
  nextSnapshot(tick: number, sampledAt: number): WearableHealthSnapshot;
}

/**
 * 无真机阶段使用的确定性数据源。真实设备接入时只需实现 HeartRateProvider，
 * 规则引擎和界面不需要知道数据来自模拟器还是真实传感器。
 */
export class MockHeartRateProvider implements HeartRateProvider {
  private scenario: HeartRateScenario = 'steady';

  setScenario(scenario: HeartRateScenario): void {
    this.scenario = scenario;
  }

  nextSnapshot(tick: number, sampledAt: number): WearableHealthSnapshot {
    const safeTick = Math.max(0, tick);
    if (this.scenario === 'stress') {
      return {
        bpm: 101 + safeTick % 8,
        medianBpm: 103,
        baselineBpm: 75,
        trendBpm: 11,
        highLoadSeconds: 150 + safeTick,
        sampleCount: 30,
        quality: 'good',
        hasMotion: false,
        isWorn: true,
        sampledAt: sampledAt
      };
    }
    if (this.scenario === 'movement') {
      return {
        bpm: 108 + safeTick % 12,
        medianBpm: 112,
        baselineBpm: 75,
        trendBpm: 9,
        highLoadSeconds: 180 + safeTick,
        sampleCount: 30,
        quality: 'good',
        hasMotion: true,
        isWorn: true,
        sampledAt: sampledAt
      };
    }
    if (this.scenario === 'disconnected') {
      return {
        bpm: 0,
        medianBpm: 0,
        baselineBpm: 75,
        trendBpm: 0,
        highLoadSeconds: 0,
        sampleCount: 0,
        quality: 'none',
        hasMotion: false,
        isWorn: false,
        sampledAt: sampledAt
      };
    }
    return {
      bpm: 74 + safeTick % 5,
      medianBpm: 76,
      baselineBpm: 75,
      trendBpm: 1,
      highLoadSeconds: 0,
      sampleCount: 30,
      quality: 'good',
      hasMotion: false,
      isWorn: true,
      sampledAt: sampledAt
    };
  }
}

export class WearableHealthHelper {
  static emptySnapshot(): WearableHealthSnapshot {
    return {
      bpm: 0,
      medianBpm: 0,
      baselineBpm: 75,
      trendBpm: 0,
      highLoadSeconds: 0,
      sampleCount: 0,
      quality: 'none',
      hasMotion: false,
      isWorn: false,
      sampledAt: 0
    };
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

    const baselineDelta = snapshot.medianBpm - snapshot.baselineBpm;
    if (snapshot.hasMotion && baselineDelta >= 20) {
      return {
        level: 'observe',
        title: '检测到运动干扰',
        description: '心率升高可能来自活动，保持观察，不自动改变专注计划。',
        actionLabel: '交给 Agent 判断',
        canAdjustPlan: true
      };
    }

    if (baselineDelta >= 20 && snapshot.highLoadSeconds >= 120) {
      return {
        level: 'recover',
        title: '建议暂停并短暂恢复',
        description: '聚合心率持续高于个人基线，建议先暂停本轮，再由你决定是否调整计划。',
        actionLabel: '让 Agent 调整计划',
        canAdjustPlan: true
      };
    }

    if (baselineDelta >= 15 && snapshot.trendBpm >= 5) {
      return {
        level: 'observe',
        title: '专注负荷正在上升',
        description: '先保持观察；只有趋势持续存在时才建议调整，避免单次读数误判。',
        actionLabel: '交给 Agent 判断',
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

  static buildAgentPrompt(snapshot: WearableHealthSnapshot,
    recommendation: WearableRecommendation, currentTask: string): string {
    const task = currentTask.trim().length > 0 ? currentTask.trim() : '当前专注任务';
    const motion = snapshot.hasMotion ? '检测到活动干扰' : '未检测到明显活动干扰';
    return `穿戴端对“${task}”给出状态建议：${recommendation.title}。` +
      `仅提供聚合数据：窗口心率中位数 ${snapshot.medianBpm} BPM，` +
      `个人基线 ${snapshot.baselineBpm} BPM，持续高负荷 ${snapshot.highLoadSeconds} 秒，${motion}。` +
      '请结合剩余时间和既有计划，给出幅度最小、可以立即执行的调整；' +
      '不要作医学判断，不要因单次心率直接完成、删除或大幅改写任务。';
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
