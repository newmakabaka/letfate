/** 抛硬币模块的常量定义。 */

export const COIN_HISTORY_MODULE: string = 'coin';

/** 累计统计的持久化 key（反面次数 = 总数 - 正面，仍单独落盘便于直接读取） */
export const COIN_STAT_TOTAL_KEY: string = 'coin_total';
export const COIN_STAT_HEADS_KEY: string = 'coin_heads';
export const COIN_STAT_TAILS_KEY: string = 'coin_tails';

/** 币面文案（用于展示与历史记录） */
export const FACE_HEADS: string = '正面';
export const FACE_TAILS: string = '反面';

/** 连抛模式可选次数 */
export const COIN_FLIP_COUNTS: number[] = [1, 3, 5];

/** 自定义币面文案的持久化 key 与长度上限 */
export const COIN_FACE_HEADS_KEY: string = 'coin_heads_text';
export const COIN_FACE_TAILS_KEY: string = 'coin_tails_text';
export const COIN_FACE_MAX_LEN: number = 4;

/** 单次抛掷的翻转圈数范围（随机化避免套路感） */
export const COIN_MIN_LAPS: number = 4;
export const COIN_MAX_LAPS: number = 6;

/** 单个 90° 翻转段的时长范围（毫秒） */
export const COIN_SEGMENT_MS_MIN: number = 80;
export const COIN_SEGMENT_MS_MAX: number = 105;

/** 币面渲染状态：显示哪一面（0 正 / 1 反）+ 是否预镜像（scaleY -1，抵消背面段的上下翻转） */
export interface FaceState {
  face: number;
  mirrored: boolean;
}
