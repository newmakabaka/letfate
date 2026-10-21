import { common } from '@kit.AbilityKit';
import { curves, mediaquery } from '@kit.ArkUI';
import { image } from '@kit.ImageKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { generateBarcode, scanBarcode, scanCore } from '@kit.ScanKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { FortuneWheel } from '../components/FortuneWheel';
import { ResultDialog } from '../components/ResultDialog';
import { QrDialog } from '../components/QrDialog';
import { HistoryList } from '../components/HistoryList';
import { HDS_TITLE_MATERIAL } from '../components/HdsTitleStyle';
import {
  SHARE_ANCHOR_ID,
  buildWheelShareText,
  savePixelMapToCache,
  showImageShare
} from '../logic/ShareUtil';
import { decodeOptions, encodeOptions } from '../logic/WheelQr';
import { RandomUtil } from '../logic/RandomUtil';
import { WheelEngine } from '../logic/WheelEngine';
import { HistoryItem, HistoryManager } from '../logic/HistoryManager';
import { PreferencesStore } from '../store/PreferencesStore';
import {
  DEFAULT_WHEEL_OPTIONS,
  WHEEL_MAX_OPTIONS,
  WHEEL_MIN_OPTIONS,
  WHEEL_OPTIONS_KEY,
  WHEEL_HISTORY_MODULE
} from '../model/WheelModels';

/** 转盘旋转状态机 */
enum SpinPhase {
  Idle,
  Spinning,
  Result
}

const HISTORY_DISPLAY_MAX: number = 50;
/** 横屏左栏内：转盘直径 = min(栏宽×0.92, 栏高−按钮区高度, 360) */
const STAGE_BUTTON_AREA: number = 76;
const WHEEL_MAX_SIDE: number = 360;

@Entry
@Component
struct WheelPage {
  @State options: string[] = DEFAULT_WHEEL_OPTIONS;
  @State rotation: number = 0;
  @State phase: SpinPhase = SpinPhase.Idle;
  @State resultIndex: number = -1;
  @State resultTitle: string = '';
  @State highlightIndex: number = -1;
  @State resultVisible: boolean = false;
  @State historyLines: string[] = [];
  /**
   * 选项列表版本号：仅在增删选项时递增，用作 ForEach key 前缀。
   * 删除中间项后强制重建所有行，避免行内事件捕获旧 index 导致"删错行"、编号不刷新。
   */
  @State listVersion: number = 0;
  /** 横竖屏自适应：横屏为左舞台（转盘+开始）/右信息（编辑+历史）双栏 */
  @State isLandscape: boolean = false;
  /** 横屏左栏实测尺寸，用于计算转盘直径 */
  @State stageW: number = 0;
  @State stageH: number = 0;
  /** 选项二维码弹层可见性（F8） */
  @State qrVisible: boolean = false;
  /** 选项二维码图（Scan Kit 生成） */
  @State qrPixelMap: image.PixelMap | undefined = undefined;
  /**
   * 旋转期间挂起弹窗挂载：旋转动画会干扰弹窗子树的转场（真机 RS 连报
   * Failed to attach property，弹窗视觉上消失，见 V1.2 文档 3.6.2），
   * 方向切换后先卸载、动画结束再整体重建，避开转场干扰窗口。
   */
  @State dialogRebuild: boolean = false;
  private rebuildTimer: number = -1;
  private landscapeListener?: mediaquery.MediaQueryListener;

  aboutToAppear(): void {
    const listener = mediaquery.matchMediaSync('(orientation: landscape)');
    this.landscapeListener = listener;
    this.isLandscape = listener.matches;
    hilog.info(0x0000, 'WheelRotate', 'page aboutToAppear, landscape=%{public}s', String(listener.matches));
    listener.on('change', (result: mediaquery.MediaQueryResult) => {
      hilog.info(0x0000, 'WheelRotate', 'mediaquery change, matches=%{public}s', String(result.matches));
      this.isLandscape = result.matches;
      this.dialogRebuild = true;
      if (this.rebuildTimer !== -1) {
        clearTimeout(this.rebuildTimer);
      }
      this.rebuildTimer = setTimeout(() => {
        this.dialogRebuild = false;
        this.rebuildTimer = -1;
      }, 600);
    });
    this.loadPersistedState();
  }

  aboutToDisappear(): void {
    this.landscapeListener?.off('change');
    if (this.rebuildTimer !== -1) {
      clearTimeout(this.rebuildTimer);
      this.rebuildTimer = -1;
    }
  }

  private appContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  private toast(message: string | Resource): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  /** 启动时读取已存选项与历史；首次启动写入默认选项。 */
  private loadPersistedState(): void {
    try {
      const raw = PreferencesStore.getString(this.appContext(), WHEEL_OPTIONS_KEY, '');
      if (raw.length === 0) {
        this.persistOptions();
      } else {
        const parsed = JSON.parse(raw) as string[];
        if (Array.isArray(parsed) && parsed.length >= WHEEL_MIN_OPTIONS) {
          this.options = parsed.slice(0, WHEEL_MAX_OPTIONS);
        }
      }
    } catch (err) {
      // 解析失败保留默认选项
    }
    this.historyLines = HistoryManager
      .load(this.appContext(), WHEEL_HISTORY_MODULE)
      .slice(0, HISTORY_DISPLAY_MAX)
      .map((it: HistoryItem): string => `${it.title} · ${HistoryManager.formatTime(it.time)}`);
  }

  private persistOptions(): void {
    PreferencesStore.putString(this.appContext(), WHEEL_OPTIONS_KEY, JSON.stringify(this.options));
  }

  private sanitizedCount(): number {
    return WheelEngine.sanitizeOptions(this.options).length;
  }

  /** 是否存在重复选项（非空白且与其它行相同）。 */
  private hasDuplicateOptions(): boolean {
    const seen = new Set<string>();
    for (let i = 0; i < this.options.length; i++) {
      const value = this.options[i].trim();
      if (value.length === 0) {
        continue;
      }
      if (seen.has(value)) {
        return true;
      }
      seen.add(value);
    }
    return false;
  }

  /** 指定行是否与其它行内容重复（用于标红提示）。 */
  private isDuplicate(index: number): boolean {
    if (index < 0 || index >= this.options.length) {
      return false;
    }
    const value = this.options[index].trim();
    if (value.length === 0) {
      return false;
    }
    for (let j = 0; j < this.options.length; j++) {
      if (j !== index && this.options[j].trim() === value) {
        return true;
      }
    }
    return false;
  }

  private canStart(): boolean {
    return this.phase !== SpinPhase.Spinning
      && WheelEngine.canSpin(this.sanitizedCount())
      && !this.hasDuplicateOptions();
  }

  /** 横屏转盘边长：取左栏宽高的较小值（高度需扣除开始按钮区域）。 */
  private wheelSide(): number {
    if (this.stageW <= 0 || this.stageH <= 0) {
      return 0;
    }
    return Math.max(160, Math.min(this.stageW * 0.92, this.stageH - STAGE_BUTTON_AREA, WHEEL_MAX_SIDE));
  }

  /** 编辑选项后使旧结果失效。 */
  private resetResult(): void {
    this.phase = SpinPhase.Idle;
    this.highlightIndex = -1;
    this.resultVisible = false;
  }

  private updateOption(index: number, value: string): void {
    if (this.phase === SpinPhase.Spinning) {
      return;
    }
    if (index < 0 || index >= this.options.length) {
      return;
    }
    const wasDuplicate = this.isDuplicate(index);
    this.options[index] = value;
    // 仅在"由不重复变为重复"的瞬间提示一次，避免连续输入时 Toast 刷屏
    if (!wasDuplicate && this.isDuplicate(index)) {
      this.toast($r('app.string.wheel_duplicate'));
    }
    this.resetResult();
    this.persistOptions();
  }

  private addOption(): void {
    if (this.phase === SpinPhase.Spinning) {
      return;
    }
    if (this.options.length >= WHEEL_MAX_OPTIONS) {
      this.toast($r('app.string.wheel_max_reach'));
      return;
    }
    this.options.push(`选项${this.options.length + 1}`);
    this.resetResult();
    this.persistOptions();
    this.listVersion++;
  }

  private removeOption(index: number): void {
    if (this.phase === SpinPhase.Spinning) {
      return;
    }
    if (this.options.length <= WHEEL_MIN_OPTIONS) {
      this.toast($r('app.string.wheel_min_keep'));
      return;
    }
    this.options.splice(index, 1);
    this.resetResult();
    this.persistOptions();
    this.listVersion++;
  }

  /** 开转：先随机结果，再反推目标角度驱动动画。 */
  private startSpin(): void {
    if (this.phase === SpinPhase.Spinning) {
      return;
    }
    const clean = WheelEngine.sanitizeOptions(this.options);
    if (clean.length < WheelEngine.MIN_OPTIONS) {
      this.toast($r('app.string.wheel_need_two'));
      return;
    }
    if (this.hasDuplicateOptions()) {
      this.toast($r('app.string.wheel_duplicate'));
      return;
    }
    const resultIdx = WheelEngine.pickResultIndex(clean.length);
    const target = WheelEngine.computeTargetRotation(this.rotation, resultIdx, clean.length);
    const duration = WheelEngine.spinDuration();
    this.resultIndex = resultIdx;
    this.resultTitle = clean[resultIdx];
    this.highlightIndex = -1;
    this.resultVisible = false;
    this.phase = SpinPhase.Spinning;
    this.getUIContext().animateTo({
      duration: duration,
      curve: curves.cubicBezier(0.12, 0.72, 0.08, 1.0),
      onFinish: () => {
        this.onSpinFinished();
      }
    }, () => {
      this.rotation = target;
    });
  }

  private onSpinFinished(): void {
    this.phase = SpinPhase.Result;
    this.highlightIndex = this.resultIndex;
    this.resultVisible = true;
    const item = HistoryManager.add(this.appContext(), WHEEL_HISTORY_MODULE, this.resultTitle);
    this.historyLines =
      [`${item.title} · ${HistoryManager.formatTime(item.time)}`, ...this.historyLines].slice(0, HISTORY_DISPLAY_MAX);
  }

  private clearHistory(): void {
    HistoryManager.clear(this.appContext(), WHEEL_HISTORY_MODULE);
    this.historyLines = [];
  }

  /** 生成并展示选项二维码（F8）：内容为清洗后的当前选项。 */
  private showQr(): void {
    if (this.phase === SpinPhase.Spinning) {
      return;
    }
    const clean = WheelEngine.sanitizeOptions(this.options);
    if (clean.length < WheelEngine.MIN_OPTIONS) {
      this.toast($r('app.string.wheel_need_two'));
      return;
    }
    const options: generateBarcode.CreateOptions = {
      scanType: scanCore.ScanType.QR_CODE,
      height: 400,
      width: 400,
      level: generateBarcode.ErrorCorrectionLevel.LEVEL_H
    };
    generateBarcode.createBarcode(encodeOptions(clean), options).then((pixelMap: image.PixelMap) => {
      this.qrPixelMap = pixelMap;
      this.qrVisible = true;
    }).catch(() => {
      this.toast($r('app.string.qr_generate_failed'));
    });
  }

  /** 分享二维码图（F8）：先落沙箱 cache，再经系统分享面板发出。 */
  private shareQr(): void {
    if (this.qrPixelMap === undefined) {
      return;
    }
    savePixelMapToCache(this.appContext(), this.qrPixelMap, 'wheel_qr.png')
      .then((path: string) => showImageShare(this.appContext(), path))
      .catch((err: BusinessError) => {
        // 失败码必须留痕：F8 真机问题即凭此日志（13900015 File exists）定位
        hilog.error(0x0000, 'WheelShare', 'share qr failed, code=%{public}d, msg=%{public}s', err.code, err.message);
        this.toast($r('app.string.share_failed'));
      });
  }

  /** 扫码导入选项（F8）：系统默认扫码界面（免相机权限），取消静默。 */
  private importByScan(): void {
    if (this.phase === SpinPhase.Spinning) {
      return;
    }
    if (!scanCore.isDefaultScanSupported()) {
      this.toast($r('app.string.qr_scan_unsupported'));
      return;
    }
    const options: scanBarcode.ScanOptions = {
      scanTypes: [scanCore.ScanType.QR_CODE],
      enableAlbum: true
    };
    scanBarcode.startScanForResult(this.appContext(), options).then((result: scanBarcode.ScanResult) => {
      this.applyImportedOptions(result.originalValue);
    }).catch((err: BusinessError) => {
      // 1000500002 为用户主动取消，静默处理
      if (err.code !== 1000500002) {
        this.toast($r('app.string.qr_scan_failed'));
      }
    });
  }

  /** 应用导入结果：合法则整体替换当前选项并持久化，否则提示。 */
  private applyImportedOptions(raw: string): void {
    const imported = decodeOptions(raw);
    if (imported === null) {
      this.toast($r('app.string.qr_invalid_code'));
      return;
    }
    this.options = imported;
    this.resetResult();
    this.persistOptions();
    this.listVersion++;
    this.toast($r('app.string.qr_import_done', imported.length));
  }

  /** 返回导航：默认出栈；栈深=1（根页面）时回主页，与 DrawPage 行为一致。 */
  private goBack(): void {
    if (this.getUIContext().getRouter().getStackSize() <= 1) {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' }).catch(() => {});
    } else {
      this.getUIContext().getRouter().back();
    }
  }

  @Builder
  WheelBlock() {
    Stack() {
      FortuneWheel({
        options: WheelEngine.sanitizeOptions(this.options),
        rotation: this.rotation,
        highlightIndex: this.highlightIndex,
        onHubClick: (): void => {
          this.startSpin();
        }
      })
      if (this.sanitizedCount() < WHEEL_MIN_OPTIONS) {
        Text($r('app.string.wheel_hint_add'))
          .fontSize(15)
          .fontColor($r('app.color.text_primary'))
          .padding({ left: 16, right: 16, top: 8, bottom: 8 })
          .borderRadius(12)
          .backgroundColor($r('app.color.card_bg'))
      }
    }
    .width('100%')
    .height('100%')
  }

  /** 舞台：转盘 + 开始按钮（横竖屏共用，尺寸随方向切换）。 */
  @Builder
  StagePane() {
    Column() {
      if (this.isLandscape && this.wheelSide() > 0) {
        // 横屏：直径按左栏实测尺寸计算，避免溢出
        Column() {
          this.WheelBlock()
        }
        .width(this.wheelSide())
        .height(this.wheelSide())
      } else {
        Column() {
          this.WheelBlock()
        }
        .width('86%')
        .constraintSize({ maxWidth: 360 })
        .aspectRatio(1)
        .margin({ top: 8 })
      }

      Button(this.phase === SpinPhase.Spinning
        ? $r('app.string.wheel_spinning')
        : $r('app.string.wheel_start'))
        .fontSize(20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.night_deep'))
        .backgroundColor($r('app.color.brand_gold'))
        .borderRadius(26)
        .width(200)
        .height(52)
        .margin({ top: this.isLandscape ? 14 : 22, bottom: this.isLandscape ? 0 : 24 })
        .enabled(this.canStart())
        .opacity(this.canStart() ? 1 : 0.5)
        .onClick(() => {
          this.startSpin();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  /** 信息：选项编辑 + 历史（竖屏在舞台下方，横屏在右栏滚动）。 */
  @Builder
  InfoPane() {
    Column() {
      // 选项编辑
      Column({ space: 12 }) {
        Row() {
          Text($r('app.string.wheel_editor_title'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Text(`${this.options.length}/${WHEEL_MAX_OPTIONS}`)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
          // 选项二维码入口（F8）
          Text($r('app.string.qr_entry'))
            .fontSize(13)
            .fontColor($r('app.color.brand_gold'))
            .padding({ left: 10, right: 10, top: 4, bottom: 4 })
            .borderRadius(12)
            .border({ width: 1, color: $r('app.color.brand_gold') })
            .margin({ left: 10 })
            .opacity(this.phase === SpinPhase.Spinning ? 0.5 : 1)
            .onClick(() => {
              this.showQr();
            })
        }
        .width('100%')

        // 重复选项提示（随输入实时刷新；避免在 TextInput 上加 border，会导致无法输入）
        if (this.hasDuplicateOptions()) {
          Text($r('app.string.wheel_duplicate_tip'))
            .fontSize(13)
            .fontColor($r('app.color.accent_red'))
            .width('100%')
        }

        ForEach(this.options, (item: string, index: number) => {
          Row({ space: 10 }) {
            Text(`${index + 1}.`)
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .width(24)
              .textAlign(TextAlign.End)
            TextInput({ text: item, placeholder: `选项${index + 1}` })
              .layoutWeight(1)
              .height(44)
              .fontSize(16)
              .fontColor($r('app.color.text_primary'))
              .placeholderColor($r('app.color.text_secondary'))
              .backgroundColor($r('app.color.input_bg'))
              .borderRadius(10)
              .padding({ left: 12, right: 12 })
              .onChange((value: string) => {
                this.updateOption(index, value);
              })
            Text('✕')
              .fontSize(16)
              .fontColor($r('app.color.text_secondary'))
              .width(32)
              .height(32)
              .textAlign(TextAlign.Center)
              .onClick(() => {
                this.removeOption(index);
              })
          }
          .width('100%')
        }, (item: string, index: number) => `${this.listVersion}_${index}`)

        Row() {
          Text($r('app.string.wheel_add_option'))
            .fontSize(15)
            .fontColor($r('app.color.brand_gold'))
            .width('100%')
            .height(44)
            .textAlign(TextAlign.Center)
            .borderRadius(10)
            .border({ width: 1, color: $r('app.color.brand_gold') })
            .opacity(this.phase === SpinPhase.Spinning ? 0.5 : 1)
            .onClick(() => {
              this.addOption();
            })
        }
        .width('100%')

        // 扫码导入（F8）：整体替换当前选项
        Row() {
          Text($r('app.string.qr_import_entry'))
            .fontSize(15)
            .fontColor($r('app.color.brand_gold'))
            .width('100%')
            .height(44)
            .textAlign(TextAlign.Center)
            .borderRadius(10)
            .border({ width: 1, color: $r('app.color.brand_gold') })
            .opacity(this.phase === SpinPhase.Spinning ? 0.5 : 1)
            .onClick(() => {
              this.importByScan();
            })
        }
        .width('100%')

        Text($r('app.string.qr_import_hint'))
          .fontSize(12)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
      }
      .padding(16)
      .borderRadius(16)
      .backgroundColor($r('app.color.card_bg'))
      .width('100%')
      .opacity(this.phase === SpinPhase.Spinning ? 0.6 : 1)

      // 历史记录
      Column() {
        HistoryList({
          sectionTitle: $r('app.string.wheel_history_title'),
          emptyText: $r('app.string.wheel_history_empty'),
          records: this.historyLines,
          onClear: (): void => {
            this.clearHistory();
          }
        })
      }
      .width('100%')
      .margin({ top: 14 })
    }
    .width('100%')
  }

  build() {
    // HDS 导航替换自绘 NavBar：标题栏启用沉浸光感材质（F6）
    HdsNavigation() {
      Stack() {
        Column() {
          if (this.isLandscape) {
            // 横屏：左舞台 / 右信息
            Row({ space: 12 }) {
              Column() {
                this.StagePane()
              }
              .layoutWeight(45)
              .height('100%')
              .justifyContent(FlexAlign.Center)
              .onAreaChange((oldValue: Area, newValue: Area) => {
                this.stageW = Number(newValue.width);
                this.stageH = Number(newValue.height);
              })

              Scroll() {
                Column() {
                  this.InfoPane()
                }
                .width('100%')
                .padding({ left: 4, right: 4, bottom: 20 })
              }
              .layoutWeight(55)
              .height('100%')
              .scrollBar(BarState.Off)
            }
            .width('100%')
            .layoutWeight(1)
            .padding({ left: 16, right: 16 })
            .alignItems(VerticalAlign.Top)
          } else {
            Scroll() {
              Column() {
                this.StagePane()
                this.InfoPane()
              }
              .width('100%')
              .padding({ left: 16, right: 16, bottom: 30 })
            }
            .layoutWeight(1)
            .scrollBar(BarState.Off)
            .width('100%')
          }
        }
        .width('100%')
        .height('100%')

        // 结果弹窗：条件实例化（与 QrDialog 同模式）；dialogRebuild 在旋转期间
        // 暂卸弹窗、动画结束后重建，避开系统旋转动画对转场的干扰
        if (this.resultVisible && !this.dialogRebuild) {
          ResultDialog({
            visible: true,
            title: $r('app.string.result_title'),
            message: this.resultTitle,
            shareText: buildWheelShareText(this.resultTitle),
            isLandscape: this.isLandscape,
            onConfirm: (): void => {
              this.resultVisible = false;
            },
            onAgain: (): void => {
              this.resultVisible = false;
              this.startSpin();
            }
          })
        }

        // 选项二维码弹层（F8）：条件实例化——pixelMap 是普通成员、仅组件创建时初始化一次，
        // 常驻实例不会同步页面后续生成的码值，导致弹层首开无图
        if (this.qrVisible && !this.dialogRebuild) {
          QrDialog({
            visible: true,
            title: $r('app.string.qr_dialog_title'),
            isLandscape: this.isLandscape,
            pixelMap: this.qrPixelMap,
            onShare: (): void => {
              this.shareQr();
            },
            onClose: (): void => {
              this.qrVisible = false;
            }
          })
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.page_bg'))
    }
    .titleMode(HdsNavigationTitleMode.MINI)
    .mode(NavigationMode.Stack)
    .titleBar({
      content: {
        title: { mainTitle: $r('app.string.wheel_title') },
        backIcon: { action: (): void => this.goBack() }
      },
      style: HDS_TITLE_MATERIAL,
      // HDS 标题栏默认悬浮在内容之上；设为组件级安全区后内容区自动下移避让，不再与标题重叠
      enableComponentSafeArea: true
    })
  }
}
