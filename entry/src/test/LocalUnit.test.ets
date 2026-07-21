import { describe, beforeAll, beforeEach, afterEach, afterAll, it, expect } from '@ohos/hypium';
import { PreferencesHelper, SessionRecord } from '../main/ets/utils/PreferencesHelper';
import { TimerHelper } from '../main/ets/utils/TimerHelper';
import { TimerPlanHelper } from '../main/ets/utils/TimerPlanHelper';

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

    it('longBreakCadence', 0, () => {
      expect(TimerPlanHelper.isLongBreak(0, 4)).assertFalse();
      expect(TimerPlanHelper.isLongBreak(3, 4)).assertFalse();
      expect(TimerPlanHelper.isLongBreak(4, 4)).assertTrue();
      expect(TimerPlanHelper.getBreakDuration(4, 4, 300, 900)).assertEqual(900);
      expect(TimerPlanHelper.getBreakDuration(5, 4, 300, 900)).assertEqual(300);
    });

    it('separateAutoStartRules', 0, () => {
      expect(TimerPlanHelper.shouldAutoStart(true, true, false)).assertTrue();
      expect(TimerPlanHelper.shouldAutoStart(true, false, true)).assertFalse();
      expect(TimerPlanHelper.shouldAutoStart(false, false, true)).assertTrue();
      expect(TimerPlanHelper.shouldAutoStart(false, true, false)).assertFalse();
    });
  });
}
