import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';
import {
  CONTINUATION_REVISION_KEY,
  CrossDeviceContinuationHelper
} from '../utils/CrossDeviceContinuationHelper';

const DOMAIN = 0x0000;

export default class EntryAbility extends UIAbility {
  private continuationRestore: Promise<boolean> = Promise.resolve(false);

  private extractContinuationSnapshot(want: Want): string {
    if (want.parameters === undefined) {
      return '';
    }
    const serialized = want.parameters.pomodoroContinuationSnapshot;
    return typeof serialized === 'string' ? serialized : '';
  }

  private async restoreContinuation(want: Want): Promise<boolean> {
    const serialized = this.extractContinuationSnapshot(want);
    if (serialized.length === 0) {
      return false;
    }
    const result = await CrossDeviceContinuationHelper.restore(this.context, serialized);
    if (result.success && !result.duplicate) {
      AppStorage.setOrCreate<number>(CONTINUATION_REVISION_KEY, Date.now());
      hilog.info(DOMAIN, 'continuation', '%{public}s', result.message);
    } else if (result.success) {
      hilog.info(DOMAIN, 'continuation', '%{public}s', result.message);
    } else {
      hilog.error(DOMAIN, 'continuation', '%{public}s', result.message);
    }
    return result.success;
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    AppStorage.setOrCreate<number>(CONTINUATION_REVISION_KEY, 0);
    this.continuationRestore = this.restoreContinuation(want);
    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onCreate');
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    this.continuationRestore.finally(() => {
      windowStage.loadContent('pages/Index', (err) => {
        if (err.code) {
          hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
          return;
        }
        hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
      });
    });
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.continuationRestore = this.restoreContinuation(want);
  }

  async onContinue(wantParam: Record<string, Object>): Promise<AbilityConstant.OnContinueResult> {
    try {
      const serialized = await CrossDeviceContinuationHelper.capture(this.context);
      wantParam.pomodoroContinuationSnapshot = serialized;
      hilog.info(DOMAIN, 'continuation', '%{public}s', 'Continuation snapshot prepared');
      return AbilityConstant.OnContinueResult.AGREE;
    } catch {
      hilog.error(DOMAIN, 'continuation', '%{public}s', 'Failed to prepare continuation snapshot');
      return AbilityConstant.OnContinueResult.REJECT;
    }
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
