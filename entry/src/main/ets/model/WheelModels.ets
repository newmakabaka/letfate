/** 幸运转盘模块的数据模型与常量定义。 */
export const WHEEL_MIN_OPTIONS: number = 2;
export const WHEEL_MAX_OPTIONS: number = 12;
export const HISTORY_LIMIT: number = 100;
export const WHEEL_OPTIONS_KEY: string = 'wheel_options';
export const WHEEL_HISTORY_MODULE: string = 'wheel';

/** 首次启动的默认转盘选项（吃什么示例盘）。 */
export const DEFAULT_WHEEL_OPTIONS: string[] = ['火锅', '烧烤', '面条', '汉堡', '麻辣烫', '沙县小吃'];

/**
 * Canvas 盘面配色（与应用图标同源的暖色点缀，深浅色模式下保持不变，
 * 与 resources 中 color.json 的同名色值保持一致，作为单一色源）。
 */
export const WHEEL_SECTOR_PALETTE: string[] = ['#F5C866', '#F58A57', '#F0F06A', '#E86A5E', '#7FC8A9'];
export const WHEEL_SEPARATOR_COLOR: string = '#302D41';
export const WHEEL_LABEL_COLOR: string = '#302D41';
export const WHEEL_RING_COLOR: string = '#F5C866';

/**
 * 转盘标签字体大小倍率（自己调试用）：
 * 以当前基准字号为 1 倍，改大即整体放大，例如：
 *   2   → 字号为原来的 2 倍
 *   1.5 → 字号为原来的 1.5 倍
 *   0.8 → 缩小为原来的 0.8 倍
 * 字号放大后，超长选项会自动截断（加"…"）以避免文字重叠。
 */
export const WHEEL_LABEL_FONT_SCALE: number = 1.2;
