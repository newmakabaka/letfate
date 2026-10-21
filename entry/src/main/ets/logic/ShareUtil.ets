import { common } from '@kit.AbilityKit';
import { systemShare } from '@kit.ShareKit';
import { uniformTypeDescriptor } from '@kit.ArkData';
import { image } from '@kit.ImageKit';
import { fileIo as fs, fileUri } from '@kit.CoreFileKit';

/**
 * 结果分享工具（F7）：统一拼装三页分享文案 + 拉起系统分享面板。
 * 见 docs/letfate/LetFate_V1.1_Plan.md 第 13 节。
 * 纯文本经 systemShare（@since 4.1.0(11)）交给系统面板，应用不感知分享目标；零权限。
 */

/** 分享文案中的应用露出 */
const APP_NAME: string = '随缘选';
/** 三页分享按钮共用的锚点控件 ID：系统面板按它定位弹出位置（2in1 设备必需） */
export const SHARE_ANCHOR_ID: string = 'share_result_btn';

/** 求签结果文案：签级 + 签题 + 签诗全文 */
export function buildSignShareText(levelName: string, title: string, poem: string[]): string {
  return `我在「${APP_NAME}」求得一签：${levelName} · ${title}\n${poem.join('\n')}\n（来自${APP_NAME}）`;
}

/** 转盘结果文案 */
export function buildWheelShareText(result: string): string {
  return `「${APP_NAME}」转盘帮我选出了：${result}`;
}

/** 硬币结果文案：单抛一枚，连抛时标签用「 · 」串联 */
export function buildCoinShareText(labels: string[]): string {
  if (labels.length === 1) {
    return `「${APP_NAME}」硬币：${labels[0]}`;
  }
  return `「${APP_NAME}」硬币连抛 ${labels.length} 次：${labels.join(' · ')}`;
}

/**
 * 拉起系统分享面板分享纯文本。
 * 单条文本远小于 200KB IPC 上限，不做截断；失败（401/10037xxxx）由调用方 toast 提示。
 */
export function showTextShare(context: common.UIAbilityContext, text: string): Promise<void> {
  const data: systemShare.SharedData = new systemShare.SharedData({
    utd: uniformTypeDescriptor.UniformDataType.PLAIN_TEXT,
    content: text
  });
  return new systemShare.ShareController(data).show(context, { anchor: SHARE_ANCHOR_ID });
}

/**
 * PixelMap 编码为 PNG 覆盖写入沙箱 cache/share 目录，返回文件路径。
 * mkdir 前先 accessSync 判存：SDK d.ts 明确 recursive mkdirSync 在目录已存在时
 * 抛 13900015（File exists），F8 真机实测复现。目录系统可回收，应用不做清理；零权限。
 */
export async function savePixelMapToCache(context: common.UIAbilityContext, pixelMap: image.PixelMap,
  fileName: string): Promise<string> {
  const dir = `${context.cacheDir}/share`;
  if (!fs.accessSync(dir)) {
    fs.mkdirSync(dir, true);
  }
  const path = `${dir}/${fileName}`;
  const file = fs.openSync(path, fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
  try {
    const packer = image.createImagePacker();
    await packer.packToFile(pixelMap, file.fd, { format: 'image/png', quality: 100 });
  } finally {
    fs.closeSync(file);
  }
  return path;
}

/** 拉起系统分享面板分享沙箱内的 PNG 图片文件（F8 二维码 / F9 海报共用）。 */
export function showImageShare(context: common.UIAbilityContext, path: string): Promise<void> {
  const data: systemShare.SharedData = new systemShare.SharedData({
    utd: uniformTypeDescriptor.UniformDataType.PNG,
    uri: fileUri.getUriFromPath(path)
  });
  return new systemShare.ShareController(data).show(context, { anchor: SHARE_ANCHOR_ID });
}
