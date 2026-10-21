import { RandomUtil } from './RandomUtil';
import {
  COIN_MAX_LAPS,
  COIN_MIN_LAPS,
  COIN_SEGMENT_MS_MAX,
  COIN_SEGMENT_MS_MIN,
  FaceState
} from '../model/CoinModels';

/**
 * 抛硬币引擎：正/反各 50%；结果先行，动画角度由结果反推。
 * 翻转角约定：累计角度始终是 90° 的整数倍；角度 mod 360 为 0 停在正面，为 180 停在反面。
 */
export class CoinEngine {
  static readonly FACE_HEAD: number = 0;
  static readonly FACE_TAIL: number = 1;

  /** 单次抛掷：正面 / 反面各 50%。 */
  static flip(): number {
    return RandomUtil.randomInt(0, 1);
  }

  /** 连抛 count 次。 */
  static flipMany(count: number): number[] {
    const out: number[] = [];
    for (let i = 0; i < count; i++) {
      out.push(CoinEngine.flip());
    }
    return out;
  }

  /** 结果先行：在现有角度上叠加 4~6 个整圈，再补足到目标面（正面 0 / 反面 180）。 */
  static computeTargetRotation(current: number, result: number): number {
    const laps = RandomUtil.randomInt(COIN_MIN_LAPS, COIN_MAX_LAPS) * 360;
    const mod = ((current % 360) + 360) % 360;
    const want = result === CoinEngine.FACE_HEAD ? 0 : 180;
    const delta = (((want - mod) % 360) + 360) % 360;
    return current + laps + delta;
  }

  /** 单个 90° 翻转段的时长（毫秒），随机化总时长。 */
  static segmentMs(): number {
    return RandomUtil.randomInt(COIN_SEGMENT_MS_MIN, COIN_SEGMENT_MS_MAX);
  }

  /**
   * 给定一段的起始角（90° 整数倍），返回该段应展示的币面与是否预镜像。
   * 象限表：[正面, 反面·镜像, 反面·镜像, 正面]——镜像段配合容器的 scaleY<0，
   * 使文字净变换始终正立；币面切换发生在段边界（硬币侧立、不可见瞬间）。
   * 币面对应的展示文案由页面层按用户自定义映射，引擎只负责"哪一面"。
   */
  static faceStateAt(angle: number): FaceState {
    const idx = Math.round(angle / 90) % 4;
    const face = (idx === 0 || idx === 3) ? CoinEngine.FACE_HEAD : CoinEngine.FACE_TAIL;
    const mirrored = idx === 1 || idx === 2;
    return { face: face, mirrored: mirrored };
  }
}
