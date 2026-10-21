/** 抽签模块的数据模型与常量定义。 */

export const DRAW_HISTORY_MODULE: string = 'draw';

/** 签级名称（下标即 SIGN_LIBRARY 中的 levelIndex）。 */
export const SIGN_LEVELS: string[] = ['上上签', '上签', '中签', '中平签', '下签'];

/** 签级抽取经验权重（百分比），与 SIGN_LEVELS 下标对应。 */
export const SIGN_LEVEL_WEIGHTS: number[] = [10, 25, 35, 20, 10];

/** 一支签的数据结构（文案均为原创，避免版权风险）。 */
export interface Sign {
  /** 所属签级下标（0~4） */
  levelIndex: number;
  /** 签名（四字吉语/意象） */
  title: string;
  /** 签诗四句 */
  poem: string[];
  /** 解签 */
  interpret: string;
}
