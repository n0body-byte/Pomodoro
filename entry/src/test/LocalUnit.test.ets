import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { PreferencesHelper, SessionRecord } from '../main/ets/utils/PreferencesHelper';
import { TimerHelper } from '../main/ets/utils/TimerHelper';
import { TimerPlanHelper } from '../main/ets/utils/TimerPlanHelper';
import { AiPlanInsightHelper } from '../main/ets/utils/AiPlanInsightHelper';
import { AiAgentDecisionHelper } from '../main/ets/utils/AiAgentDecisionHelper';
import { AiAgentP1Helper, AiExecutionRecord } from '../main/ets/utils/AiAgentP1Helper';
import { LocalFallbackPlanHelper } from '../main/ets/utils/LocalFallbackPlanHelper';
import { AiPlanQualityHelper } from '../main/ets/utils/AiPlanQualityHelper';
import { AiGoalReadinessHelper } from '../main/ets/utils/AiGoalReadinessHelper';
import { AiPlanProgressHelper } from '../main/ets/utils/AiPlanProgressHelper';
import { AiPlanVersionHelper } from '../main/ets/utils/AiPlanVersionHelper';
import { AiPlannerService } from '../main/ets/utils/AiPlannerService';
import { CrossDeviceContinuationHelper } from '../main/ets/utils/CrossDeviceContinuationHelper';
import { AiExecutionCheckInHelper } from '../main/ets/utils/AiExecutionCheckInHelper';
import { AiRequestTraceHelper } from '../main/ets/utils/AiRequestTraceHelper';
import {
  AiAgentResult,
  AiAgentState,
  AiChatMessage,
  AiExecutionInsight,
  AiFocusContext,
  AiGoalDriftInsight,
  AiPlan,
  AiPlanInsight,
  AiPlanStep,
  AiRequestTrace
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

    it('planInsightIncludesActiveStepPartialProgress', 0, () => {
      const steps: AiPlanStep[] = [
        { title: '完成初稿', project: '报告', tag: '', note: '', estimatedPomodoros: 3,
          reason: '', completed: false },
        { title: '检查交付', project: '报告', tag: '', note: '', estimatedPomodoros: 1,
          reason: '', completed: false }
      ];
      const insight = AiPlanInsightHelper.calculate(
        steps, 60, 25, 5, '完成初稿', '报告', 2);
      expect(insight.completedPomodoros).assertEqual(2);
      expect(insight.remainingPomodoros).assertEqual(2);
      expect(insight.progressPercent).assertEqual(50);
      expect(insight.requiredMinutes).assertEqual(55);
      expect(insight.nextStepIndex).assertEqual(0);
    });

    it('planQualityAcceptsExecutableDeliverablePlan', 0, () => {
      const steps: AiPlanStep[] = [
        { title: '完成报告主体', project: '报告', tag: '', note: '写完三个核心章节', estimatedPomodoros: 2,
          reason: '优先形成主体成果', completed: false },
        { title: '检查并提交', project: '报告', tag: '', note: '检查格式并完成提交', estimatedPomodoros: 1,
          reason: '确保形成可验证交付', completed: false }
      ];
      const insight = AiPlanInsightHelper.calculate(steps, 120, 25, 5);
      const quality = AiPlanQualityHelper.evaluate(steps, insight);
      expect(quality.score).assertEqual(100);
      expect(quality.status).assertEqual('strong');
    });

    it('planQualityFindsCapacityAndStructureRisks', 0, () => {
      const steps: AiPlanStep[] = [
        { title: '处理事情', project: '项目', tag: '', note: '', estimatedPomodoros: 3,
          reason: '', completed: false },
        { title: '处理事情', project: '项目', tag: '', note: '', estimatedPomodoros: 3,
          reason: '', completed: false }
      ];
      const insight = AiPlanInsightHelper.calculate(steps, 60, 25, 5);
      const quality = AiPlanQualityHelper.evaluate(steps, insight);
      expect(quality.score < 65).assertTrue();
      expect(quality.status).assertEqual('blocked');
      expect(quality.canApply).assertFalse();
      expect(quality.improvementPrompt.indexOf('超出可用时间') >= 0).assertTrue();
      expect(quality.improvementPrompt.indexOf('重复步骤') >= 0).assertTrue();
    });

    it('goalReadinessRejectsVagueDirection', 0, () => {
      const learning = AiGoalReadinessHelper.evaluate('学习英语');
      const improving = AiGoalReadinessHelper.evaluate('完善项目');
      expect(learning.ready).assertFalse();
      expect(learning.question.indexOf('结果') >= 0).assertTrue();
      expect(improving.ready).assertFalse();
    });

    it('goalReadinessAcceptsVerifiableOutcome', 0, () => {
      const result = AiGoalReadinessHelper.evaluate('今晚完成两套四级听力并整理错题');
      expect(result.ready).assertTrue();
      expect(result.status).assertEqual('ready');
    });

    it('planQualityBlocksVagueStep', 0, () => {
      const steps: AiPlanStep[] = [
        { title: '研究一下', project: '比赛', tag: '', note: '看看相关内容', estimatedPomodoros: 1,
          reason: '先了解情况', completed: false },
        { title: '检查并提交', project: '比赛', tag: '', note: '检查结果并完成提交', estimatedPomodoros: 1,
          reason: '形成最终交付', completed: false }
      ];
      const quality = AiPlanQualityHelper.evaluate(
        steps, AiPlanInsightHelper.calculate(steps, 90, 25, 5));
      expect(quality.canApply).assertFalse();
      expect(quality.description.indexOf('空泛动作') >= 0).assertTrue();
    });

    it('planQualityBlocksOversizedStep', 0, () => {
      const steps: AiPlanStep[] = [
        { title: '完成报告主体', project: '报告', tag: '', note: '写完三个核心章节', estimatedPomodoros: 5,
          reason: '形成主体成果', completed: false },
        { title: '检查并提交', project: '报告', tag: '', note: '检查格式并完成提交', estimatedPomodoros: 1,
          reason: '形成最终交付', completed: false }
      ];
      const quality = AiPlanQualityHelper.evaluate(
        steps, AiPlanInsightHelper.calculate(steps, 240, 25, 5));
      expect(quality.canApply).assertFalse();
      expect(quality.improvementPrompt.indexOf('超过 4 个番茄') >= 0).assertTrue();
    });

    it('deepSeekDiagnosticAcceptsAvailableModel', 0, () => {
      const result = AiPlannerService.evaluateDeepSeekService(
        true, ['deepseek-v4-flash', 'deepseek-v4-pro'], 'deepseek-v4-flash');
      expect(result.success).assertTrue();
      expect(result.message.indexOf('余额可用') >= 0).assertTrue();
      expect(result.message.indexOf('V4 Flash') >= 0).assertTrue();
    });

    it('deepSeekDiagnosticSeparatesBalanceAndModelIssues', 0, () => {
      const balanceResult = AiPlannerService.evaluateDeepSeekService(
        false, ['deepseek-v4-flash'], 'deepseek-v4-flash');
      const modelResult = AiPlannerService.evaluateDeepSeekService(
        true, ['deepseek-v4-flash'], 'deepseek-v4-pro');
      expect(balanceResult.success).assertFalse();
      expect(balanceResult.message.indexOf('余额') >= 0).assertTrue();
      expect(modelResult.success).assertFalse();
      expect(modelResult.message.indexOf('所选模型') >= 0).assertTrue();
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

    it('localFallbackKeepsEveryStepSmall', 0, () => {
      const plan = LocalFallbackPlanHelper.create('完成复赛演示文档', 360, '周五 18:00', 25, 5);
      let largest = 0;
      for (const step of plan.steps) {
        largest = Math.max(largest, step.estimatedPomodoros);
      }
      expect(largest <= 4).assertTrue();
      const quality = AiPlanQualityHelper.evaluate(
        plan.steps, AiPlanInsightHelper.calculate(plan.steps, 360, 25, 5));
      expect(quality.canApply).assertTrue();
    });

    it('aiPlanCompletionReturnsNextStep', 0, () => {
      const plan: AiPlan = { summary: '完成报告', steps: [
        { title: '整理资料', project: '报告', tag: '准备', note: '', estimatedPomodoros: 1,
          reason: '先收集输入', completed: false },
        { title: '撰写初稿', project: '报告', tag: '产出', note: '', estimatedPomodoros: 2,
          reason: '形成可评审版本', completed: false }
      ] };
      const completion = AiPlanProgressHelper.completeStep(plan, '整理资料', '报告');
      expect(completion.matched).assertTrue();
      expect(completion.plan.steps[0].completed).assertTrue();
      expect(completion.nextStep !== undefined).assertTrue();
      if (completion.nextStep !== undefined) {
        expect(completion.nextStep.title).assertEqual('撰写初稿');
      }
      expect(plan.steps[0].completed).assertFalse();
    });

    it('aiPlanCompletionRequiresExactConversation', 0, () => {
      expect(AiPlanProgressHelper.isTrackedConversation('ai', 'conversation-1', 'conversation-1')).assertTrue();
      expect(AiPlanProgressHelper.isTrackedConversation('manual', 'conversation-1', 'conversation-1')).assertFalse();
      expect(AiPlanProgressHelper.isTrackedConversation('ai', 'conversation-1', 'conversation-2')).assertFalse();
      expect(AiPlanProgressHelper.isTrackedConversation('ai', '', '')).assertFalse();
    });

    it('executionCheckInAcceptsVerifiableEvidence', 0, () => {
      const result = AiExecutionCheckInHelper.validate('achieved', '已导出 demo.mp4 并完成播放检查');
      expect(result.ready).assertTrue();
    });

    it('executionCheckInRejectsVagueClaim', 0, () => {
      expect(AiExecutionCheckInHelper.validate('achieved', '完成了').ready).assertFalse();
      expect(AiExecutionCheckInHelper.validate('blocked', '有问题').ready).assertFalse();
    });

    it('partialCheckInReopensProvisionalStep', 0, () => {
      const plan: AiPlan = { summary: '交付演示', steps: [
        { title: '录制演示视频', project: '复赛', tag: '演示', note: '导出五分钟视频',
          estimatedPomodoros: 2, reason: '形成提交材料', completed: true }
      ] };
      const checkIn = AiExecutionCheckInHelper.create(
        '录制演示视频', '复赛', 'partial', '已录制前三分钟，剩余 Agent 演示', 1000);
      expect(checkIn !== undefined).assertTrue();
      if (checkIn !== undefined) {
        const updated = AiExecutionCheckInHelper.applyOutcome(plan, checkIn);
        expect(updated.steps[0].completed).assertFalse();
        expect(plan.steps[0].completed).assertTrue();
      }
    });

    it('executionCheckInBuildsGroundedReviewMessage', 0, () => {
      const checkIn = AiExecutionCheckInHelper.create(
        '联调登录接口', '复赛', 'blocked', '接口返回 401，等待服务端确认权限', 1000);
      expect(checkIn !== undefined).assertTrue();
      if (checkIn !== undefined) {
        const message = AiExecutionCheckInHelper.buildReviewMessage(checkIn);
        expect(message.indexOf('接口返回 401') >= 0).assertTrue();
        expect(message.indexOf('不要把该步骤视为已完成') >= 0).assertTrue();
      }
    });

    it('requestTraceCapturesReturnedUsage', 0, () => {
      const result: AiAgentResult = {
        success: true, reply: '计划完成', plan: { summary: '', steps: [] },
        usage: { promptTokens: 120, completionTokens: 80, totalTokens: 200 }, errorMessage: ''
      };
      const trace = AiRequestTraceHelper.create(
        '生成计划', 'deepseek-v4-flash', 1000, 2600, result, 'accepted', '已采用');
      expect(trace.totalTokens).assertEqual(200);
      expect(trace.durationMs).assertEqual(1600);
      expect(trace.provider).assertEqual('DeepSeek');
      expect(AiRequestTraceHelper.provesRemoteResponse(trace)).assertTrue();
    });

    it('requestTraceKeepsNewestTwentyEntries', 0, () => {
      let traces: AiRequestTrace[] = [];
      const result: AiAgentResult = {
        success: false, reply: '', plan: { summary: '', steps: [] },
        usage: { promptTokens: 0, completionTokens: 0, totalTokens: 0 }, errorMessage: '网络失败'
      };
      for (let index = 0; index < 25; index++) {
        const trace = AiRequestTraceHelper.create(
          `调用${index}`, 'deepseek-v4-flash', index, index + 1, result, 'failed', '网络失败');
        traces = AiRequestTraceHelper.append(traces, trace);
      }
      expect(traces.length).assertEqual(20);
      expect(traces[0].action).assertEqual('调用24');
    });

    it('requestTraceDoesNotClaimUnconfirmedFailureAsResponse', 0, () => {
      const result: AiAgentResult = {
        success: false, reply: '', plan: { summary: '', steps: [] },
        usage: { promptTokens: 0, completionTokens: 0, totalTokens: 0 },
        errorMessage: '无法连接 DeepSeek，请检查网络后重试'
      };
      const trace = AiRequestTraceHelper.create(
        '生成计划', 'deepseek-v4-flash', 1000, 2000, result, 'failed', result.errorMessage);
      expect(AiRequestTraceHelper.provesRemoteResponse(trace)).assertFalse();
      const authTrace = AiRequestTraceHelper.create(
        '生成计划', 'deepseek-v4-flash', 2000, 2200, result,
        'failed', 'DeepSeek API Key 无效或没有访问权限');
      expect(AiRequestTraceHelper.provesRemoteResponse(authTrace)).assertTrue();
    });

    it('aiPlanVersionCapturesChangedExecutablePlan', 0, () => {
      const current: AiPlan = { summary: '原计划', steps: [
        { title: '完成初稿', project: '报告', tag: '', note: '', estimatedPomodoros: 2,
          reason: '先形成内容', completed: false }
      ] };
      const next: AiPlan = { summary: '压缩计划', steps: [
        { title: '完成最小初稿', project: '报告', tag: '', note: '', estimatedPomodoros: 1,
          reason: '先保证交付', completed: false }
      ] };
      const snapshot = AiPlanVersionHelper.capture(current, next, 'ai', 123);
      expect(snapshot !== undefined).assertTrue();
      if (snapshot !== undefined) {
        expect(snapshot.plan.summary).assertEqual('原计划');
        expect(snapshot.plan.steps[0].title).assertEqual('完成初稿');
        expect(snapshot.source).assertEqual('ai');
        expect(snapshot.savedAt).assertEqual(123);
        current.steps[0].title = '已被外部修改';
        expect(snapshot.plan.steps[0].title).assertEqual('完成初稿');
      }
    });

    it('aiPlanVersionSkipsEmptyOrUnchangedPlan', 0, () => {
      const empty: AiPlan = { summary: '', steps: [] };
      const plan: AiPlan = { summary: '原计划', steps: [
        { title: '完成初稿', project: '报告', tag: '', note: '', estimatedPomodoros: 1,
          reason: '形成交付', completed: false }
      ] };
      expect(AiPlanVersionHelper.capture(empty, plan, 'none', 1) === undefined).assertTrue();
      expect(AiPlanVersionHelper.capture(plan, AiPlanVersionHelper.copyPlan(plan), 'ai', 2) ===
        undefined).assertTrue();
    });

    it('continuationKeepsAbsoluteTimerAndRecentAgentContext', 0, () => {
      const messages: AiChatMessage[] = [];
      for (let index = 0; index < 10; index++) {
        messages.push({ role: index % 2 === 0 ? 'user' : 'assistant',
          content: `消息${index}`, createdAt: 100 + index });
      }
      const agentState: AiAgentState = {
        id: 'conversation-1', title: '复赛计划', createdAt: 100, messages: messages,
        plan: { summary: '先完成演示', steps: [
          { title: '完成演示脚本', project: '复赛', tag: '演示', note: '写完五分钟演示脚本',
            estimatedPomodoros: 2, reason: '先形成可检查成果', completed: false }
        ] },
        updatedAt: 200, needsReview: false, lastCompletedStepTitle: ''
      };
      const snapshot = CrossDeviceContinuationHelper.createSnapshot({
        remainingSeconds: 1200, totalSeconds: 1500, isWorkMode: true, isRunning: true,
        completedSessions: 2, savedAt: 1000, deadlineAt: 130000, isLongBreak: false
      }, {
        task: '完成演示脚本', project: '复赛', tag: '演示', note: '写完初稿',
        estimatedPomodoros: 2, trackingStartedAt: 900, source: 'ai',
        agentConversationId: 'conversation-1'
      }, agentState, [], 2000);
      const parsed = CrossDeviceContinuationHelper.parse(
        CrossDeviceContinuationHelper.serialize(snapshot));
      expect(parsed.success).assertTrue();
      expect(parsed.snapshot !== undefined).assertTrue();
      if (parsed.snapshot !== undefined && parsed.snapshot.timerState !== null) {
        expect(parsed.snapshot.timerState.deadlineAt).assertEqual(130000);
        expect(parsed.snapshot.agentState.messages.length).assertEqual(8);
        expect(parsed.snapshot.agentState.messages[0].content).assertEqual('消息2');
      }
    });

    it('continuationRejectsUnsupportedOrBrokenPayload', 0, () => {
      expect(CrossDeviceContinuationHelper.parse('{broken').success).assertFalse();
      const agentState: AiAgentState = {
        id: '', title: '', createdAt: 0, messages: [], plan: { summary: '', steps: [] },
        updatedAt: 0, needsReview: false, lastCompletedStepTitle: ''
      };
      const snapshot = CrossDeviceContinuationHelper.createSnapshot(null, {
        task: '', project: '', tag: '', note: '', estimatedPomodoros: 1
      }, agentState, [], 1000);
      const unsupported = CrossDeviceContinuationHelper.serialize(snapshot)
        .replace('"schemaVersion":1', '"schemaVersion":2');
      expect(CrossDeviceContinuationHelper.parse(unsupported).success).assertFalse();
    });

    it('continuationHistoryMergeIsIdempotent', 0, () => {
      const existing: SessionRecord[] = [
        { id: 'record-1', date: '2026-08-21', workSeconds: 1500, completedAt: 100,
          type: 'work', status: 'completed' }
      ];
      const incoming: SessionRecord[] = [
        { id: 'record-1', date: '2026-08-21', workSeconds: 1500, completedAt: 100,
          type: 'work', status: 'completed' },
        { id: 'record-2', date: '2026-08-21', workSeconds: 300, completedAt: 200,
          type: 'break', status: 'completed' }
      ];
      const merged = PreferencesHelper.mergeSessionRecords(existing, incoming);
      expect(merged.length).assertEqual(2);
      expect(merged[0].id).assertEqual('record-1');
      expect(merged[1].id).assertEqual('record-2');
    });
  });
}
