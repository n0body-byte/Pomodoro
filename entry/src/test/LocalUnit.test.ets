import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { PreferencesHelper, SessionRecord } from '../main/ets/utils/PreferencesHelper';
import { TimerHelper } from '../main/ets/utils/TimerHelper';
import { TimerPlanHelper } from '../main/ets/utils/TimerPlanHelper';
import { AiPlanInsightHelper } from '../main/ets/utils/AiPlanInsightHelper';
import { AiAgentDecisionHelper } from '../main/ets/utils/AiAgentDecisionHelper';
import { AiAgentP1Helper, AiExecutionRecord } from '../main/ets/utils/AiAgentP1Helper';
import { LocalFallbackPlanHelper } from '../main/ets/utils/LocalFallbackPlanHelper';
import {
  AiExecutionInsight,
  AiFocusContext,
  AiGoalDriftInsight,
  AiPlan,
  AiPlanInsight,
  AiPlanStep
} from '../main/ets/utils/AiAgentModels';

export default function localUnitTest() {
  describe('localUnitTest', () => {
    // Defines a test suite. Two parameters are supported: test suite name and test suite function.
    beforeAll(() => {
      // Presets an action, which is performed only once before all test cases of the test suite start.
      // This API supports only one parameter: preset action function.
    });
    beforeEach(() => {
      // Presets an action, which is performed before each unit test case starts.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: preset action function.
    });
    afterEach(() => {
      // Presets a clear action, which is performed after each unit test case ends.
      // The number of execution times is the same as the number of test cases defined by **it**.
      // This API supports only one parameter: clear action function.
    });
    afterAll(() => {
      // Presets a clear action, which is performed after all test cases of the test suite end.
      // This API supports only one parameter: clear action function.
    });
    it('calculateRemainingSeconds', 0, () => {
      expect(TimerHelper.calculateRemainingSeconds(5000, 4000)).assertEqual(1);
      expect(TimerHelper.calculateRemainingSeconds(5000, 4001)).assertEqual(1);
      expect(TimerHelper.calculateRemainingSeconds(5000, 5000)).assertEqual(0);
      expect(TimerHelper.calculateRemainingSeconds(5000, 6000)).assertEqual(0);
    });

    it('calculateRemainingSecondsRoundsUp', 0, () => {
      expect(TimerHelper.calculateRemainingSeconds(5001, 5000)).assertEqual(1);
      expect(TimerHelper.calculateRemainingSeconds(5999, 5000)).assertEqual(1);
      expect(TimerHelper.calculateRemainingSeconds(6001, 5000)).assertEqual(2);
    });

    it('completedWorkRecordCompatibility', 0, () => {
      const legacyRecord: SessionRecord = {
        date: '2026-07-21', workSeconds: 1500, completedAt: 1, type: 'work'
      };
      const abandonedRecord: SessionRecord = {
        date: '2026-07-21', workSeconds: 300, completedAt: 2, type: 'work', status: 'abandoned'
      };
      const breakRecord: SessionRecord = {
        date: '2026-07-21', workSeconds: 300, completedAt: 3, type: 'break', status: 'completed'
      };
      expect(PreferencesHelper.isCompletedWorkRecord(legacyRecord)).assertTrue();
      expect(PreferencesHelper.isCompletedWorkRecord(abandonedRecord)).assertFalse();
      expect(PreferencesHelper.isCompletedWorkRecord(breakRecord)).assertFalse();
    });

    it('workRecordStatusMatrix', 0, () => {
      const completedRecord: SessionRecord = {
        date: '2026-07-22', workSeconds: 1500, completedAt: 4, type: 'work', status: 'completed'
      };
      const skippedRecord: SessionRecord = {
        date: '2026-07-22', workSeconds: 0, completedAt: 5, type: 'work', status: 'skipped'
      };
      expect(PreferencesHelper.isCompletedWorkRecord(completedRecord)).assertTrue();
      expect(PreferencesHelper.isCompletedWorkRecord(skippedRecord)).assertFalse();
    });

    it('taskProgressStartsWhenPlanStepIsApplied', 0, () => {
      const history: SessionRecord[] = [
        { date: '2026-08-21', workSeconds: 1500, completedAt: 100, type: 'work',
          status: 'completed', task: '完成报告', project: '课程' },
        { date: '2026-08-21', workSeconds: 1500, completedAt: 300, type: 'work',
          status: 'completed', task: '完成报告', project: '课程' },
        { date: '2026-08-21', workSeconds: 600, completedAt: 400, type: 'work',
          status: 'abandoned', task: '完成报告', project: '课程' }
      ];
      expect(PreferencesHelper.countCompletedTaskSessions(
        history, '完成报告', '课程', 200)).assertEqual(1);
      expect(PreferencesHelper.countCompletedTaskSessions(
        history, '完成报告', '课程')).assertEqual(2);
    });

    it('longBreakCadence', 0, () => {
      expect(TimerPlanHelper.isLongBreak(0, 4)).assertFalse();
      expect(TimerPlanHelper.isLongBreak(3, 4)).assertFalse();
      expect(TimerPlanHelper.isLongBreak(4, 4)).assertTrue();
      expect(TimerPlanHelper.getBreakDuration(4, 4, 300, 900)).assertEqual(900);
      expect(TimerPlanHelper.getBreakDuration(5, 4, 300, 900)).assertEqual(300);
    });

    it('longBreakDisabledForInvalidInterval', 0, () => {
      expect(TimerPlanHelper.isLongBreak(4, 0)).assertFalse();
      expect(TimerPlanHelper.isLongBreak(4, -1)).assertFalse();
      expect(TimerPlanHelper.getBreakDuration(4, 0, 300, 900)).assertEqual(300);
    });

    it('separateAutoStartRules', 0, () => {
      expect(TimerPlanHelper.shouldAutoStart(true, true, false)).assertTrue();
      expect(TimerPlanHelper.shouldAutoStart(true, false, true)).assertFalse();
      expect(TimerPlanHelper.shouldAutoStart(false, false, true)).assertTrue();
      expect(TimerPlanHelper.shouldAutoStart(false, true, false)).assertFalse();
    });

    it('planInsightOnTrack', 0, () => {
      const steps: AiPlanStep[] = [
        { title: '完成主体', project: '报告', tag: '写作', note: '', estimatedPomodoros: 2,
          reason: '', completed: false },
        { title: '检查提交', project: '报告', tag: '检查', note: '', estimatedPomodoros: 1,
          reason: '', completed: false }
      ];
      const insight = AiPlanInsightHelper.calculate(steps, 120, 25, 5);
      expect(insight.requiredMinutes).assertEqual(85);
      expect(insight.bufferMinutes).assertEqual(35);
      expect(insight.status).assertEqual('on_track');
      expect(insight.nextStepIndex).assertEqual(0);
    });

    it('planInsightOverCapacity', 0, () => {
      const steps: AiPlanStep[] = [
        { title: '完成主体', project: '报告', tag: '写作', note: '', estimatedPomodoros: 3,
          reason: '', completed: false }
      ];
      const insight = AiPlanInsightHelper.calculate(steps, 60, 25, 5);
      expect(insight.requiredMinutes).assertEqual(85);
      expect(insight.bufferMinutes).assertEqual(-25);
      expect(insight.feasibilityPercent).assertEqual(71);
      expect(insight.status).assertEqual('over_capacity');
    });

    it('planInsightWeightedProgress', 0, () => {
      const steps: AiPlanStep[] = [
        { title: '资料整理', project: '报告', tag: '准备', note: '', estimatedPomodoros: 2,
          reason: '', completed: true },
        { title: '最终检查', project: '报告', tag: '检查', note: '', estimatedPomodoros: 1,
          reason: '', completed: false }
      ];
      const insight = AiPlanInsightHelper.calculate(steps, 30, 25, 5);
      expect(insight.progressPercent).assertEqual(67);
      expect(insight.remainingPomodoros).assertEqual(1);
      expect(insight.requiredMinutes).assertEqual(25);
      expect(insight.nextStepIndex).assertEqual(1);
    });

    it('agentDecisionRecoversFailedActionFirst', 0, () => {
      const insight: AiPlanInsight = AiPlanInsightHelper.calculate([], 120, 25, 5);
      const decision = AiAgentDecisionHelper.decide(insight, false, false, true, true, true, true, false);
      expect(decision.stage).assertEqual('blocked');
      expect(decision.action).assertEqual('retry');
      expect(decision.usesAi).assertTrue();
    });

    it('agentDecisionReviewsCompletedStepBeforeExecution', 0, () => {
      const steps: AiPlanStep[] = [
        { title: '整理资料', project: '报告', tag: '准备', note: '', estimatedPomodoros: 1,
          reason: '', completed: true },
        { title: '写出初稿', project: '报告', tag: '写作', note: '', estimatedPomodoros: 2,
          reason: '', completed: false }
      ];
      const insight = AiPlanInsightHelper.calculate(steps, 90, 25, 5);
      const decision = AiAgentDecisionHelper.decide(insight, true, true, false, false, true, true, false);
      expect(decision.stage).assertEqual('reviewing');
      expect(decision.action).assertEqual('review');
    });

    it('agentDecisionReplansOverCapacity', 0, () => {
      const steps: AiPlanStep[] = [
        { title: '完成报告', project: '报告', tag: '写作', note: '', estimatedPomodoros: 4,
          reason: '', completed: false }
      ];
      const insight = AiPlanInsightHelper.calculate(steps, 60, 25, 5);
      const decision = AiAgentDecisionHelper.decide(insight, true, false, false, false, true, true, false);
      expect(decision.stage).assertEqual('replanning');
      expect(decision.action).assertEqual('compress');
    });

    it('agentDecisionAppliesNextStepWithoutAiCost', 0, () => {
      const steps: AiPlanStep[] = [
        { title: '开始执行', project: '计划', tag: '行动', note: '', estimatedPomodoros: 1,
          reason: '', completed: false }
      ];
      const insight = AiPlanInsightHelper.calculate(steps, 60, 25, 5);
      const decision = AiAgentDecisionHelper.decide(insight, true, false, false, false, true, true, false);
      expect(decision.stage).assertEqual('ready');
      expect(decision.action).assertEqual('apply_next');
      expect(decision.usesAi).assertFalse();
    });

    it('agentDecisionRequestsServiceConfiguration', 0, () => {
      const insight: AiPlanInsight = AiPlanInsightHelper.calculate([], 120, 25, 5);
      const decision = AiAgentDecisionHelper.decide(insight, false, false, false, false, false, true, false);
      expect(decision.stage).assertEqual('blocked');
      expect(decision.action).assertEqual('configure');
      expect(decision.usesAi).assertFalse();
    });

    it('agentDecisionKeepsExistingPlanExecutableOffline', 0, () => {
      const steps: AiPlanStep[] = [
        { title: '离线执行', project: '计划', tag: '行动', note: '', estimatedPomodoros: 1,
          reason: '', completed: false }
      ];
      const insight = AiPlanInsightHelper.calculate(steps, 60, 25, 5);
      const decision = AiAgentDecisionHelper.decide(insight, true, false, false, false, false, true, false);
      expect(decision.stage).assertEqual('ready');
      expect(decision.action).assertEqual('apply_next');
    });

    it('agentMemoryCombinesLongAndShortTermContext', 0, () => {
      const plan: AiPlan = { summary: '报告计划', steps: [
        { title: '整理资料', project: '报告', tag: '准备', note: '', estimatedPomodoros: 1,
          reason: '', completed: true },
        { title: '完成初稿', project: '报告', tag: '写作', note: '', estimatedPomodoros: 2,
          reason: '', completed: false }
      ] };
      const context: AiFocusContext = {
        todayWorkSeconds: 1500, todayBreakSeconds: 300, todayCompletedSessions: 1, dailyTarget: 4,
        sevenDayWorkSeconds: 7200, sevenDayCompletedSessions: 5, sevenDayAbandonedSessions: 1,
        currentTask: '', currentProject: '', currentTaskCompleted: 0, workMinutes: 25, breakMinutes: 5,
        recentSessionsSummary: '', availableMinutes: 120, deadline: '今晚', planRequiredMinutes: 55,
        planBufferMinutes: 65, planProgressPercent: 33, planRiskStatus: 'on_track'
      };
      const memory = AiAgentP1Helper.buildMemory('完成课程报告', plan, context, '整理资料', []);
      expect(memory.primaryGoal).assertEqual('完成课程报告');
      expect(memory.longTermSummary.indexOf('120 分钟') >= 0).assertTrue();
      expect(memory.shortTermSummary.indexOf('完成初稿') >= 0).assertTrue();
    });

    it('goalDriftKeepsWorkflowAdjustmentAligned', 0, () => {
      const plan: AiPlan = { summary: '', steps: [
        { title: '完成报告初稿', project: '课程报告', tag: '', note: '', estimatedPomodoros: 2,
          reason: '', completed: false }
      ] };
      const drift = AiAgentP1Helper.detectGoalDrift('完成课程报告', '请把第三步拆细一点', plan);
      expect(drift.status).assertEqual('aligned');
    });

    it('goalDriftDetectsUnrelatedInstruction', 0, () => {
      const plan: AiPlan = { summary: '', steps: [
        { title: '完成报告初稿', project: '课程报告', tag: '', note: '', estimatedPomodoros: 2,
          reason: '', completed: false }
      ] };
      const drift = AiAgentP1Helper.detectGoalDrift('完成课程报告', '帮我安排周末跑步和买菜', plan);
      expect(drift.status).assertEqual('possible');
    });

    it('executionInsightDetectsOverrun', 0, () => {
      const plan: AiPlan = { summary: '', steps: [
        { title: '整理资料', project: '报告', tag: '', note: '', estimatedPomodoros: 1,
          reason: '', completed: true }
      ] };
      const records: AiExecutionRecord[] = [
        { completedAt: 200, workSeconds: 2400, type: 'work', status: 'completed',
          task: '整理资料', project: '报告' }
      ];
      const execution = AiAgentP1Helper.analyzeExecution(plan, records, 100, 25);
      expect(execution.status).assertEqual('overrun');
      expect(execution.variancePercent).assertEqual(60);
      expect(execution.shouldReplan).assertTrue();
    });

    it('executionInsightAcceptsSmallVariance', 0, () => {
      const plan: AiPlan = { summary: '', steps: [
        { title: '整理资料', project: '报告', tag: '', note: '', estimatedPomodoros: 1,
          reason: '', completed: true }
      ] };
      const records: AiExecutionRecord[] = [
        { completedAt: 200, workSeconds: 1620, type: 'work', status: 'completed',
          task: '整理资料', project: '报告' }
      ];
      const execution = AiAgentP1Helper.analyzeExecution(plan, records, 100, 25);
      expect(execution.status).assertEqual('on_track');
      expect(execution.shouldReplan).assertFalse();
    });

    it('agentDecisionPrioritizesGoalAlignment', 0, () => {
      const steps: AiPlanStep[] = [
        { title: '完成报告', project: '报告', tag: '', note: '', estimatedPomodoros: 1,
          reason: '', completed: false }
      ];
      const insight = AiPlanInsightHelper.calculate(steps, 60, 25, 5);
      const drift: AiGoalDriftInsight = {
        status: 'possible', title: '可能偏移', description: '需要校准', similarityPercent: 0
      };
      const decision = AiAgentDecisionHelper.decide(
        insight, true, false, false, false, true, true, false, drift);
      expect(decision.action).assertEqual('align_goal');
    });

    it('agentDecisionReplansFromExecutionVariance', 0, () => {
      const steps: AiPlanStep[] = [
        { title: '完成报告', project: '报告', tag: '', note: '', estimatedPomodoros: 1,
          reason: '', completed: false }
      ];
      const insight = AiPlanInsightHelper.calculate(steps, 60, 25, 5);
      const drift: AiGoalDriftInsight = AiAgentP1Helper.emptyDrift();
      const execution: AiExecutionInsight = {
        status: 'overrun', title: '执行超时', description: '需要重排', expectedMinutes: 25,
        actualMinutes: 40, varianceMinutes: 15, variancePercent: 60, matchedSessions: 1,
        shouldReplan: true
      };
      const decision = AiAgentDecisionHelper.decide(
        insight, true, false, false, false, true, true, false, drift, execution);
      expect(decision.action).assertEqual('replan_variance');
    });

    it('localFallbackFitsAvailableTime', 0, () => {
      expect(LocalFallbackPlanHelper.calculateFittingPomodoros(120, 25, 5)).assertEqual(4);
      expect(LocalFallbackPlanHelper.calculateFittingPomodoros(60, 25, 5)).assertEqual(2);
      expect(LocalFallbackPlanHelper.calculateFittingPomodoros(24, 25, 5)).assertEqual(0);
    });

    it('localFallbackCreatesMinimalDeliverable', 0, () => {
      const plan = LocalFallbackPlanHelper.create('完成课程报告', 25, '今晚', 25, 5);
      expect(plan.steps.length).assertEqual(1);
      expect(plan.steps[0].estimatedPomodoros).assertEqual(1);
      expect(plan.summary.indexOf('未调用 AI') >= 0).assertTrue();
    });

    it('localFallbackReservesClosingStep', 0, () => {
      const plan = LocalFallbackPlanHelper.create('完成课程报告', 120, '周五 18:00', 25, 5);
      expect(plan.steps.length).assertEqual(3);
      expect(plan.steps[0].estimatedPomodoros + plan.steps[1].estimatedPomodoros +
        plan.steps[2].estimatedPomodoros).assertEqual(4);
      expect(plan.steps[2].title.indexOf('交付') >= 0).assertTrue();
    });
  });
}
