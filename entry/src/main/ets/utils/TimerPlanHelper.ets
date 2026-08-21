export class TimerPlanHelper {
  static isLongBreak(completedSessions: number, interval: number): boolean {
    return completedSessions > 0 && interval > 0 && completedSessions % interval === 0;
  }

  static getBreakDuration(completedSessions: number, interval: number,
    shortBreakSeconds: number, longBreakSeconds: number): number {
    return TimerPlanHelper.isLongBreak(completedSessions, interval)
      ? longBreakSeconds : shortBreakSeconds;
  }

  static shouldAutoStart(completedWorkMode: boolean,
    autoStartBreak: boolean, autoStartWork: boolean): boolean {
    return completedWorkMode ? autoStartBreak : autoStartWork;
  }

  static canHandoffAiStep(isRunning: boolean, remainingSeconds: number,
    totalSeconds: number): boolean {
    return !isRunning && totalSeconds > 0 && remainingSeconds === totalSeconds;
  }
}
