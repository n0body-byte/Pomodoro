export interface ProductGuideStep {
  id: string;
  title: string;
  description: string;
  primaryLabel: string;
  primaryAction: string;
  secondaryLabel: string;
}

export interface TimerPresetDurations {
  name: string;
  label: string;
  workMinutes: number;
  breakMinutes: number;
  longBreakMinutes: number;
}

export class ProductGuideHelper {
  static guideSteps(): ProductGuideStep[] {
    return [
      {
        id: 'scene',
        title: '智能专注，从真实场景出发',
        description: '本应用解决三件事：目标太大不会开始、计划超出可用时间、做完番茄却不知道任务是否真正完成。',
        primaryLabel: '下一步',
        primaryAction: 'next',
        secondaryLabel: '跳过引导'
      },
      {
        id: 'plan',
        title: '规划不过载，一步就能开干',
        description: '在「AI 计划」描述目标与截止时间，本地会审计容量与质量；现场可用设置中的「演示 1/1」快速走通完整闭环。',
        primaryLabel: '去 AI 计划',
        primaryAction: 'ai',
        secondaryLabel: '下一步'
      },
      {
        id: 'harmony',
        title: '鸿蒙连续与穿戴协同',
        description: '设置页可打开虚拟手表验证压力恢复；跨设备接续可在签名双机后迁移当前计时与计划。模拟数据会明确标注。',
        primaryLabel: '打开虚拟手表',
        primaryAction: 'wearable',
        secondaryLabel: '开始使用'
      }
    ];
  }

  static resolvePreset(name: string): TimerPresetDurations | null {
    if (name === 'classic') {
      return {
        name: 'classic',
        label: '经典 25/5',
        workMinutes: 25,
        breakMinutes: 5,
        longBreakMinutes: 15
      };
    }
    if (name === 'deep') {
      return {
        name: 'deep',
        label: '深度 50/10',
        workMinutes: 50,
        breakMinutes: 10,
        longBreakMinutes: 20
      };
    }
    if (name === 'quick') {
      return {
        name: 'quick',
        label: '轻量 15/3',
        workMinutes: 15,
        breakMinutes: 3,
        longBreakMinutes: 10
      };
    }
    if (name === 'demo') {
      return {
        name: 'demo',
        label: '演示 1/1',
        workMinutes: 1,
        breakMinutes: 1,
        longBreakMinutes: 2
      };
    }
    return null;
  }

  static shouldShowStartPath(taskEmpty: boolean, hasAiHandoff: boolean): boolean {
    return taskEmpty && !hasAiHandoff;
  }

  static startPathTitle(): string {
    return '还没有本轮任务';
  }

  static startPathDescription(): string {
    return '用 AI 把目标拆成可执行步骤，或手动填写后直接开始专注。';
  }

  static clampGuideIndex(index: number, stepCount: number): number {
    if (stepCount <= 0) {
      return 0;
    }
    if (index < 0) {
      return 0;
    }
    if (index >= stepCount) {
      return stepCount - 1;
    }
    return index;
  }
}
