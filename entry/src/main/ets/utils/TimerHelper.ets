export class TimerHelper {
  static calculateRemainingSeconds(deadlineAt: number, now: number): number {
    if (deadlineAt <= now) {
      return 0;
    }
    return Math.ceil((deadlineAt - now) / 1000);
  }
}
