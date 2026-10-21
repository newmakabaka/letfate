import { WHEEL_MAX_OPTIONS, WHEEL_MIN_OPTIONS } from '../model/WheelModels';

/**
 * 转盘选项二维码编解码（F8，见 docs/letfate/LetFate_V1.2_Plan.md 第 3 节）。
 * 码值格式：{"v":1,"o":["火锅","烧烤"]}；纯函数、可单测。
 * 码内容来自外部（他人二维码），解析按不可信输入处理：逐项校验 + 数量限量。
 */

/** 码值格式版本：格式演进时拒绝旧码 */
const FORMAT_VERSION: number = 1;

/** 码值载荷结构 */
interface WheelQrPayload {
  v: number;
  o: string[];
}

/** 选项列表序列化为码值。入参应为已清洗（trim/去空）的选项。 */
export function encodeOptions(options: string[]): string {
  return JSON.stringify({ v: FORMAT_VERSION, o: options });
}

/**
 * 解析码值为选项列表。
 * 非法（JSON 解析失败 / 版本不符 / 非数组 / 含非字符串项 / 清洗后数量越界）返回 null。
 * 逐项 trim 并剔除空项；不去重（与手输行为一致，重复提示由页面既有逻辑接管）。
 */
export function decodeOptions(raw: string): string[] | null {
  let payload: WheelQrPayload;
  try {
    payload = JSON.parse(raw) as WheelQrPayload;
  } catch (err) {
    return null;
  }
  if (payload.v !== FORMAT_VERSION || !Array.isArray(payload.o)) {
    return null;
  }
  const list: string[] = [];
  for (const item of payload.o) {
    if (typeof item !== 'string') {
      return null;
    }
    const trimmed = item.trim();
    if (trimmed.length > 0) {
      list.push(trimmed);
    }
  }
  if (list.length < WHEEL_MIN_OPTIONS || list.length > WHEEL_MAX_OPTIONS) {
    return null;
  }
  return list;
}
