import { media } from '@kit.MediaKit';

let ambientPlayer: media.AVPlayer | null = null;
let activeAmbient: string = '';

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
  static async start(context: Context, name: string): Promise<void> {
    if (name === '' || name === activeAmbient) {
      return;
    }

    await AmbientHelper.stop();

    try {
      ambientPlayer = await media.createAVPlayer();
      activeAmbient = name;

      ambientPlayer.on('stateChange', (state: string) => {
        if (state === 'initialized') {
          ambientPlayer!.prepare();
        } else if (state === 'prepared') {
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
