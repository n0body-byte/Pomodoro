import { media } from '@kit.MediaKit';

let player: media.AVPlayer | null = null;

export class SoundHelper {
  static async play(context: Context, soundName: string): Promise<void> {
    try {
      if (player !== null) {
        await player.reset();
        await player.release();
        player = null;
      }

      const rawFd = await context.resourceManager.getRawFd(`${soundName}.wav`);

      player = await media.createAVPlayer();

      await new Promise<void>((resolve) => {
        player!.on('stateChange', (state: string) => {
          if (state === 'initialized') {
            player!.prepare();
          } else if (state === 'prepared') {
            player!.play();
          } else if (state === 'completed') {
            player!.stop();
          } else if (state === 'stopped') {
            resolve();
          }
        });

        player!.on('error', () => {
          resolve();
        });

        player!.fdSrc = {
          fd: rawFd.fd,
          offset: rawFd.offset,
          length: rawFd.length
        };
      });
    } catch {
      // 播放失败静默处理
    }
  }

  static async release(): Promise<void> {
    try {
      if (player !== null) {
        await player.reset();
        await player.release();
        player = null;
      }
    } catch {
      // 释放失败静默处理
    }
  }
}
