import { vibrator } from '@kit.SensorServiceKit';
import { notificationManager } from '@kit.NotificationKit';
import {
  VIBRATION_DURATION_MS,
  NOTIFICATION_WORK_END_ID,
  NOTIFICATION_BREAK_END_ID,
  NOTIFICATION_ONGOING_ID
} from '../common/Constants';

export class NotificationHelper {
  static async requestPermission(): Promise<void> {
    try {
      const enabled = await notificationManager.isNotificationEnabled();
      if (!enabled) {
        await new Promise<void>((resolve) => {
          notificationManager.requestEnableNotification(() => { resolve(); });
        });
      }
    } catch { }
  }

  static publishOngoing(remainingSeconds: number, isWorkMode: boolean): void {
    try {
      const minutes = Math.floor(remainingSeconds / 60).toString().padStart(2, '0');
      const seconds = (remainingSeconds % 60).toString().padStart(2, '0');
      const request: notificationManager.NotificationRequest = {
        id: NOTIFICATION_ONGOING_ID,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: '番茄钟计时中',
            text: `${isWorkMode ? '工作中' : '休息中'} ${minutes}:${seconds}`
          }
        }
      };
      notificationManager.publish(request);
    } catch { }
  }

  static sendEndNotification(isWorkEnd: boolean): void {
    try {
      const request: notificationManager.NotificationRequest = {
        id: isWorkEnd ? NOTIFICATION_WORK_END_ID : NOTIFICATION_BREAK_END_ID,
        notificationSlotType: notificationManager.SlotType.SOCIAL_COMMUNICATION,
        content: {
          notificationContentType: notificationManager.ContentType.NOTIFICATION_CONTENT_BASIC_TEXT,
          normal: {
            title: '番茄钟',
            text: isWorkEnd ? '工作时间结束，休息一下吧！' : '休息时间结束，开始工作吧！'
          }
        }
      };
      notificationManager.publish(request);
      vibrator.startVibration({
        type: 'time',
        duration: VIBRATION_DURATION_MS
      }, {
        usage: 'alarm'
      });
    } catch { }
  }

  static cancelOngoing(): void {
    try {
      notificationManager.cancel(NOTIFICATION_ONGOING_ID);
    } catch { }
  }
}
