import { media } from '@kit.MediaKit';

let ambientPlayer: media.AVPlayer | null = null;
let activeAmbient: string = '';
let activeVolume: number = 0.5;

function loopPlay(context: Context, name: string): void {
  if (ambientPlayer === null || activeAmbient !== name) {
    return;
  }
  context.resourceManager.getRawFd(`ambient_${name}.wav`).then((rawFd) => {
    if (ambientPlayer === null || activeAmbient !== name) {
      return;
    }
    ambientPlayer.fdSrc = {
      fd: rawFd.fd,
      offset: rawFd.offset,
      length: rawFd.length
    };
  }).catch(() => {});
}

export class AmbientHelper {
  static async start(context: Context, name: string, volume: number = 0.5): Promise<void> {
    if (name === '') {
      return;
    }

    if (name === activeAmbient && ambientPlayer !== null) {
      AmbientHelper.setVolume(volume);
      return;
    }

    await AmbientHelper.stop();

    try {
      ambientPlayer = await media.createAVPlayer();
      activeAmbient = name;
      activeVolume = Math.max(0, Math.min(volume, 1));

      ambientPlayer.on('stateChange', (state: string) => {
        if (state === 'initialized') {
          ambientPlayer!.prepare();
        } else if (state === 'prepared') {
          ambientPlayer!.setVolume(activeVolume);
          ambientPlayer!.play();
        } else if (state === 'completed') {
          ambientPlayer!.stop();
        } else if (state === 'stopped') {
          if (ambientPlayer !== null) {
            ambientPlayer.reset().then(() => {
              loopPlay(context, activeAmbient);
            }).catch(() => {});
          }
        }
      });

      ambientPlayer.on('error', () => {
        // 出错时尝试重新开始循环
        if (ambientPlayer !== null) {
          ambientPlayer.reset().then(() => {
            loopPlay(context, activeAmbient);
          }).catch(() => {});
        }
      });

      const rawFd = await context.resourceManager.getRawFd(`ambient_${name}.wav`);
      ambientPlayer.fdSrc = {
        fd: rawFd.fd,
        offset: rawFd.offset,
        length: rawFd.length
      };
    } catch {
      // 播放失败静默处理
    }
  }

  static setVolume(volume: number): void {
    activeVolume = Math.max(0, Math.min(volume, 1));
    if (ambientPlayer !== null) {
      ambientPlayer.setVolume(activeVolume);
    }
  }

  static async stop(): Promise<void> {
    try {
      if (ambientPlayer !== null) {
        await ambientPlayer.reset();
        await ambientPlayer.release();
        ambientPlayer = null;
      }
    } catch {
      // 停止失败静默处理
    }
    activeAmbient = '';
  }
}
