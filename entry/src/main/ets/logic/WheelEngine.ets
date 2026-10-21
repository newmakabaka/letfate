import { RandomUtil } from './RandomUtil';
import { WHEEL_MAX_OPTIONS, WHEEL_MIN_OPTIONS } from '../model/WheelModels';

/**
 * 幸运转盘引擎：负责结果抽取与"结果先行"的旋转角度计算。
 *
 * 坐标约定：指针固定在转盘正上方（12 点方向）；
 * 扇区 i 从 -90° + i*seg 开始顺时针绘制（Canvas 坐标系 0° 为 3 点方向，角度顺时针为正）。
 */
export class WheelEngine {
  static readonly MIN_OPTIONS: number = WHEEL_MIN_OPTIONS;
  static readonly MAX_OPTIONS: number = WHEEL_MAX_OPTIONS;
  private static readonly FULL_LAPS_MIN: number = 5;
  private static readonly FULL_LAPS_MAX: number = 8;
  private static readonly JITTER_RATIO: number = 0.35;
  private static readonly DURATION_MIN: number = 4200;
  private static readonly DURATION_MAX: number = 5800;

  /** 每个扇区的圆心角度数。 */
  static segmentAngle(count: number): number {
    if (count <= 0) {
      return 360;
    }
    return 360 / count;
  }

  /** 当前选项数是否允许开转。 */
  static canSpin(count: number): boolean {
    return count >= WheelEngine.MIN_OPTIONS && count <= WheelEngine.MAX_OPTIONS;
  }

  /** 等概率抽取结果扇区下标。 */
  static pickResultIndex(count: number): number {
    if (count <= 0) {
      return 0;
    }
    return RandomUtil.randomInt(0, count - 1);
  }

  /**
   * 先随机出结果，再反推目标旋转角，保证指针停在结果扇区内（留 ±35% 抖动避免每次都停在正中）。
   */
  static computeTargetRotation(current: number, resultIndex: number, count: number): number {
    const seg = WheelEngine.segmentAngle(count);
    const jitter = RandomUtil.randomFloat(-WheelEngine.JITTER_RATIO, WheelEngine.JITTER_RATIO) * seg;
    const needed = WheelEngine.normalize(-resultIndex * seg - seg / 2 + jitter);
    const laps = RandomUtil.randomInt(WheelEngine.FULL_LAPS_MIN, WheelEngine.FULL_LAPS_MAX) * 360;
    const delta = laps + WheelEngine.normalize(needed - WheelEngine.normalize(current));
    return current + delta;
  }

  /** 校验函数：根据最终旋转角反推指针所指扇区，用于单元测试一致性验证。 */
  static deriveIndexFromRotation(rotation: number, count: number): number {
    if (count <= 0) {
      return 0;
    }
    const seg = WheelEngine.segmentAngle(count);
    const pointerPhase = WheelEngine.normalize(-rotation);
    return Math.floor(pointerPhase / seg) % count;
  }

  /** 单次旋转动画时长（毫秒）。 */
  static spinDuration(): number {
    return RandomUtil.randomInt(WheelEngine.DURATION_MIN, WheelEngine.DURATION_MAX);
  }

  /** 选项清洗：去空白、去空项、去重，并截断到上限数量。 */
  static sanitizeOptions(raw: string[]): string[] {
    const cleaned: string[] = [];
    for (let i = 0; i < raw.length && cleaned.length < WheelEngine.MAX_OPTIONS; i++) {
      const item = raw[i].trim();
      if (item.length === 0) {
        continue;
      }
      let duplicated = false;
      for (let j = 0; j < cleaned.length; j++) {
        if (cleaned[j] === item) {
          duplicated = true;
          break;
        }
      }
      if (!duplicated) {
        cleaned.push(item);
      }
    }
    return cleaned;
  }

  /** 将任意角度归一化到 [0, 360)。 */
  private static normalize(deg: number): number {
    return ((deg % 360) + 360) % 360;
  }
}
