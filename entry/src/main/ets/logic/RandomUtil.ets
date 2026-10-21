/**
 * 随机数工具：全应用统一随机入口，便于 mock 与统计校验。
 * 后续可平滑替换为加密安全随机源，调用方无感知。
 */
export class RandomUtil {
  /** 返回 [min, max] 闭区间内的随机整数。 */
  static randomInt(min: number, max: number): number {
    const lo = Math.min(min, max);
    const hi = Math.max(min, max);
    return Math.floor(Math.random() * (hi - lo + 1)) + lo;
  }

  /** 返回 [min, max) 区间内的随机浮点数。 */
  static randomFloat(min: number, max: number): number {
    const lo = Math.min(min, max);
    const hi = Math.max(min, max);
    return lo + Math.random() * (hi - lo);
  }

  /** 从数组中等概率取一个元素，空数组抛出异常。 */
  static pick<T>(items: T[]): T {
    if (items.length === 0) {
      throw new Error('RandomUtil.pick: empty array');
    }
    return items[RandomUtil.randomInt(0, items.length - 1)];
  }

  /**
   * 按权重抽取下标：权重为任意非负数（如百分比），负数按 0 处理。
   * 全部权重非正或数组为空时抛出异常。
   */
  static weightedPickIndex(weights: number[]): number {
    if (weights.length === 0) {
      throw new Error('RandomUtil.weightedPickIndex: empty weights');
    }
    let total = 0;
    for (let i = 0; i < weights.length; i++) {
      total += Math.max(0, weights[i]);
    }
    if (total <= 0) {
      throw new Error('RandomUtil.weightedPickIndex: total weight must be positive');
    }
    let roll = Math.random() * total;
    for (let i = 0; i < weights.length; i++) {
      roll -= Math.max(0, weights[i]);
      if (roll < 0) {
        return i;
      }
    }
    return weights.length - 1;
  }
}
