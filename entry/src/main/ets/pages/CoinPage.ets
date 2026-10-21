import { common } from '@kit.AbilityKit';
import { mediaquery } from '@kit.ArkUI';
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { HistoryList } from '../components/HistoryList';
import { HDS_TITLE_MATERIAL } from '../components/HdsTitleStyle';
import { CoinEngine } from '../logic/CoinEngine';
import { HistoryItem, HistoryManager } from '../logic/HistoryManager';
import { SHARE_ANCHOR_ID, buildCoinShareText, showTextShare } from '../logic/ShareUtil';
import { PreferencesStore } from '../store/PreferencesStore';
import {
  COIN_FACE_HEADS_KEY,
  COIN_FACE_MAX_LEN,
  COIN_FACE_TAILS_KEY,
  COIN_FLIP_COUNTS,
  COIN_HISTORY_MODULE,
  COIN_STAT_HEADS_KEY,
  COIN_STAT_TAILS_KEY,
  COIN_STAT_TOTAL_KEY,
  FACE_HEADS,
  FACE_TAILS
} from '../model/CoinModels';

const HISTORY_DISPLAY_MAX: number = 50;

@Entry
@Component
struct CoinPage {
  /** 硬币累计翻转角（度），始终为 90 的整数倍；mod 360 = 0 正面 / 180 反面 */
  @State coinAngle: number = 0;
  /** 当前币面文字与是否预镜像（抵消容器转到背面时的上下翻转） */
  @State faceText: string = FACE_HEADS;
  @State faceMirrored: boolean = false;
  @State flipping: boolean = false;
  /** 连抛模式下标（0/1/2 → 1/3/5 次） */
  @State modeIndex: number = 0;
  /** 本轮已落定的结果（逐个追加，结果列表实时生长） */
  @State runResults: number[] = [];
  /** 结果行 ForEach key 前缀：每轮递增，保证新轮次行重建 */
  @State runVersion: number = 0;
  @State totalCount: number = 0;
  @State headsCount: number = 0;
  @State tailsCount: number = 0;
  @State historyLines: string[] = [];
  /** 用户自定义币面文案（空白输入回退默认"正面/反面"） */
  @State headsText: string = FACE_HEADS;
  @State tailsText: string = FACE_TAILS;
  /** 横竖屏自适应：横屏为左舞台（硬币+抛掷）/右信息（设置+统计+历史）双栏 */
  @State isLandscape: boolean = false;
  /** 待抛出的结果队列（结果先行，动画只是演出） */
  private queue: number[] = [];
  private modeLabels: ResourceStr[] = [
    $r('app.string.coin_mode_single'),
    $r('app.string.coin_mode_3'),
    $r('app.string.coin_mode_5')
  ];
  private landscapeListener?: mediaquery.MediaQueryListener;

  aboutToAppear(): void {
    const listener = mediaquery.matchMediaSync('(orientation: landscape)');
    this.landscapeListener = listener;
    this.isLandscape = listener.matches;
    listener.on('change', (result: mediaquery.MediaQueryResult) => {
      this.isLandscape = result.matches;
    });
    const ctx = this.appContext();
    this.totalCount = PreferencesStore.getNumber(ctx, COIN_STAT_TOTAL_KEY, 0);
    this.headsCount = PreferencesStore.getNumber(ctx, COIN_STAT_HEADS_KEY, 0);
    this.tailsCount = PreferencesStore.getNumber(ctx, COIN_STAT_TAILS_KEY, 0);
    if (!Number.isFinite(this.totalCount) || this.totalCount < 0) {
      this.totalCount = 0;
    }
    if (!Number.isFinite(this.headsCount) || this.headsCount < 0) {
      this.headsCount = 0;
    }
    if (!Number.isFinite(this.tailsCount) || this.tailsCount < 0) {
      this.tailsCount = 0;
    }
    this.headsText = PreferencesStore.getString(ctx, COIN_FACE_HEADS_KEY, FACE_HEADS);
    this.tailsText = PreferencesStore.getString(ctx, COIN_FACE_TAILS_KEY, FACE_TAILS);
    this.faceText = this.headsLabel();
    this.historyLines = HistoryManager
      .load(ctx, COIN_HISTORY_MODULE)
      .slice(0, HISTORY_DISPLAY_MAX)
      .map((it: HistoryItem): string => `${it.title} · ${HistoryManager.formatTime(it.time)}`);
  }

  aboutToDisappear(): void {
    this.landscapeListener?.off('change');
  }

  private appContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  /** 硬币舞台缩放：横屏压缩硬币整体尺寸（竖屏 1，横屏 0.72） */
  private cs(): number {
    return this.isLandscape ? 0.72 : 1;
  }

  /** 币面结果色：正面青 / 反面橙 */
  private faceColor(face: number): Resource {
    return face === 0 ? $r('app.color.accent_teal') : $r('app.color.accent_orange');
  }

  /** 币面文字自适应字号：保证单行落在硬币内圈内（可用宽约 150×缩放，留 15% 余量） */
  private faceFontSize(): number {
    const len = Math.max(1, this.faceText.length);
    const fit = Math.floor(150 * this.cs() / len * 0.85);
    return Math.max(18, Math.min(64 * this.cs(), fit));
  }

  private headsPct(): number {
    if (this.totalCount <= 0) {
      return 0;
    }
    return Math.round(this.headsCount * 100 / this.totalCount);
  }

  /** 空白输入回退默认文案 */
  private effectiveLabel(raw: string, fallback: string): string {
    const t = raw.trim();
    return t.length > 0 ? t : fallback;
  }

  private headsLabel(): string {
    return this.effectiveLabel(this.headsText, FACE_HEADS);
  }

  private tailsLabel(): string {
    return this.effectiveLabel(this.tailsText, FACE_TAILS);
  }

  /** 币面下标 → 展示文案（用户自定义优先） */
  private faceLabelOf(face: number): string {
    return face === CoinEngine.FACE_HEAD ? this.headsLabel() : this.tailsLabel();
  }

  private persistFaces(): void {
    const ctx = this.appContext();
    PreferencesStore.putString(ctx, COIN_FACE_HEADS_KEY, this.headsLabel());
    PreferencesStore.putString(ctx, COIN_FACE_TAILS_KEY, this.tailsLabel());
  }

  /** 静止状态下让币面文字跟随最新自定义文案 */
  private refreshIdleFace(): void {
    if (this.flipping) {
      return;
    }
    const fs = CoinEngine.faceStateAt(this.coinAngle);
    this.faceText = this.faceLabelOf(fs.face);
    this.faceMirrored = fs.mirrored;
  }

  private updateHeadsText(value: string): void {
    this.headsText = value;
    this.persistFaces();
    this.refreshIdleFace();
  }

  private updateTailsText(value: string): void {
    this.tailsText = value;
    this.persistFaces();
    this.refreshIdleFace();
  }

  /** 开始一轮抛掷：先生成全部结果，再逐个演出。 */
  private startRun(): void {
    if (this.flipping) {
      return;
    }
    const count = COIN_FLIP_COUNTS[this.modeIndex];
    this.queue = CoinEngine.flipMany(count);
    this.runResults = [];
    this.runVersion++;
    this.flipping = true;
    this.nextFlip();
  }

  private nextFlip(): void {
    if (this.queue.length === 0) {
      this.flipping = false;
      return;
    }
    const result = this.queue[0];
    this.queue = this.queue.slice(1);
    const target = CoinEngine.computeTargetRotation(this.coinAngle, result);
    this.animateLegs(target, result);
  }

  /** 逐段 90° 翻转：在段边界（硬币侧立、内容不可见）瞬间切换币面，文字永不倒置。 */
  private animateLegs(target: number, result: number): void {
    if (this.coinAngle >= target) {
      this.landFlip(result);
      return;
    }
    const state = CoinEngine.faceStateAt(this.coinAngle);
    this.faceText = this.faceLabelOf(state.face);
    this.faceMirrored = state.mirrored;
    this.getUIContext().animateTo({
      duration: CoinEngine.segmentMs(),
      curve: Curve.Linear,
      onFinish: () => {
        this.animateLegs(target, result);
      }
    }, () => {
      this.coinAngle = this.coinAngle + 90;
    });
  }

  /** 一次抛掷落定：按最终角度定格正立币面，写入统计与历史，继续下一抛。 */
  private landFlip(result: number): void {
    this.coinAngle = this.coinAngle % 360;
    const final = CoinEngine.faceStateAt(this.coinAngle);
    this.faceText = this.faceLabelOf(final.face);
    this.faceMirrored = final.mirrored;
    this.runResults = this.runResults.concat([result]);
    this.runVersion++;
    this.recordResult(result);
    this.nextFlip();
  }

  private recordResult(result: number): void {
    const ctx = this.appContext();
    this.totalCount++;
    if (result === CoinEngine.FACE_HEAD) {
      this.headsCount++;
    } else {
      this.tailsCount++;
    }
    PreferencesStore.putNumber(ctx, COIN_STAT_TOTAL_KEY, this.totalCount);
    PreferencesStore.putNumber(ctx, COIN_STAT_HEADS_KEY, this.headsCount);
    PreferencesStore.putNumber(ctx, COIN_STAT_TAILS_KEY, this.tailsCount);
    const item = HistoryManager.add(ctx, COIN_HISTORY_MODULE, this.faceLabelOf(result));
    this.historyLines =
      [`${item.title} · ${HistoryManager.formatTime(item.time)}`, ...this.historyLines].slice(0, HISTORY_DISPLAY_MAX);
  }

  private resetStats(): void {
    const ctx = this.appContext();
    this.totalCount = 0;
    this.headsCount = 0;
    this.tailsCount = 0;
    PreferencesStore.putNumber(ctx, COIN_STAT_TOTAL_KEY, 0);
    PreferencesStore.putNumber(ctx, COIN_STAT_HEADS_KEY, 0);
    PreferencesStore.putNumber(ctx, COIN_STAT_TAILS_KEY, 0);
  }

  private clearHistory(): void {
    HistoryManager.clear(this.appContext(), COIN_HISTORY_MODULE);
    this.historyLines = [];
  }

  private toast(message: string | Resource): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  /** 分享本轮结果（F7）：连抛时各次币面标签用「 · 」串联，经系统分享面板发出。 */
  private shareRun(): void {
    if (this.runResults.length === 0) {
      return;
    }
    const labels: string[] = this.runResults.map((face: number): string => this.faceLabelOf(face));
    showTextShare(this.appContext(), buildCoinShareText(labels)).catch(() => {
      this.toast($r('app.string.share_failed'));
    });
  }

  /** 返回导航：默认出栈；栈深=1（根页面）时回主页，与 DrawPage 行为一致。 */
  private goBack(): void {
    if (this.getUIContext().getRouter().getStackSize() <= 1) {
      this.getUIContext().getRouter().replaceUrl({ url: 'pages/Index' }).catch(() => {});
    } else {
      this.getUIContext().getRouter().back();
    }
  }

  /** 硬币：绕 X 轴翻转；币面文字层按 90° 段切换并预镜像，保证任意角度正立。 */
  @Builder
  CoinBlock() {
    Stack() {
      // 内圈刻线
      Column()
        .width(160 * this.cs())
        .height(160 * this.cs())
        .borderRadius(80 * this.cs())
        .border({ width: 2, color: $r('app.color.accent_orange') })
      // 币面内容：外层偏移包装（不镜像）负责整体下移，保证正反面下移方向一致
      Column() {
        // 预镜像层：背面段翻转 scaleY 抵消容器上下翻转
        Column({ space: 4 * this.cs() }) {
          Text(this.faceText)
            .fontSize(this.faceFontSize())
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.night_deep'))
            .maxLines(1)
          Text($r('app.string.index_title'))
            .fontSize(this.isLandscape ? 11 : 12)
            .fontColor($r('app.color.night_deep'))
            .opacity(0.55)
        }
        .justifyContent(FlexAlign.Center)
        .scale({ y: this.faceMirrored ? -1 : 1 })
      }
      .width('100%')
      .height('100%')
      .padding({ top: 18 * this.cs() })
      .justifyContent(FlexAlign.Center)
    }
    .width(190 * this.cs())
    .height(190 * this.cs())
    .borderRadius(95 * this.cs())
    .linearGradient({
      angle: 135,
      colors: [[$r('app.color.brand_gold'), 0], [$r('app.color.accent_orange'), 1]]
    })
    .border({ width: 5 * this.cs(), color: $r('app.color.accent_orange') })
    .rotate({ x: 1, y: 0, z: 0, angle: this.coinAngle, centerX: '50%', centerY: '50%' })
    .margin({ top: this.isLandscape ? 8 : 24 })
  }

  /** 舞台：硬币 + 连抛模式 + 抛掷按钮（横竖屏共用，尺寸随方向切换）。 */
  @Builder
  StagePane() {
    Column() {
      this.CoinBlock()

      // ===== 连抛模式选择 =====
      Row({ space: 10 }) {
        ForEach(COIN_FLIP_COUNTS, (count: number, idx: number) => {
          Text(this.modeLabels[idx])
            .fontSize(14)
            .fontColor(idx === this.modeIndex ? $r('app.color.night_deep') : $r('app.color.text_primary'))
            .fontWeight(idx === this.modeIndex ? FontWeight.Bold : FontWeight.Normal)
            .padding({
              left: this.isLandscape ? 12 : 14,
              right: this.isLandscape ? 12 : 14,
              top: this.isLandscape ? 6 : 8,
              bottom: this.isLandscape ? 6 : 8
            })
            .borderRadius(18)
            .backgroundColor(idx === this.modeIndex ? $r('app.color.brand_gold') : $r('app.color.input_bg'))
            .opacity(this.flipping && idx !== this.modeIndex ? 0.5 : 1)
            .onClick(() => {
              if (!this.flipping) {
                this.modeIndex = idx;
              }
            })
        }, (count: number, idx: number) => `mode_${idx}`)
      }
      .margin({ top: this.isLandscape ? 16 : 26 })

      // ===== 抛掷按钮 =====
      Button(this.flipping ? $r('app.string.coin_flipping') : $r('app.string.coin_start'))
        .fontSize(this.isLandscape ? 18 : 20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.night_deep'))
        .backgroundColor($r('app.color.brand_gold'))
        .borderRadius(this.isLandscape ? 23 : 26)
        .width(this.isLandscape ? 170 : 200)
        .height(this.isLandscape ? 46 : 52)
        .margin({ top: this.isLandscape ? 12 : 18, bottom: this.isLandscape ? 0 : 24 })
        .enabled(!this.flipping)
        .opacity(this.flipping ? 0.6 : 1)
        .onClick(() => {
          this.startRun();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  /** 信息：本轮结果 + 币面设置 + 统计 + 历史（竖屏在舞台下方，横屏在右栏滚动）。 */
  @Builder
  InfoPane() {
    Column() {
      // ===== 本轮结果 =====
      if (this.runResults.length > 0) {
        Column({ space: 12 }) {
          if (COIN_FLIP_COUNTS[this.modeIndex] === 1) {
            Text(this.faceLabelOf(this.runResults[0]))
              .fontSize(38)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.faceColor(this.runResults[0]))
          } else {
            ForEach(this.runResults, (face: number, index: number) => {
              Row() {
                Text(`第 ${index + 1} 次`)
                  .fontSize(15)
                  .fontColor($r('app.color.text_secondary'))
                Blank()
                Text(this.faceLabelOf(face))
                  .fontSize(16)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(this.faceColor(face))
              }
              .width('100%')
            }, (face: number, index: number) => `${this.runVersion}_${index}`)
          }
          Row({ space: 12 }) {
            Button($r('app.string.btn_again'))
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.night_deep'))
              .backgroundColor($r('app.color.brand_gold'))
              .borderRadius(22)
              .width(160)
              .height(44)
              .enabled(!this.flipping)
              .opacity(this.flipping ? 0.5 : 1)
              .onClick(() => {
                this.startRun();
              })
            Button($r('app.string.share_result'))
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.brand_gold'))
              .backgroundColor(Color.Transparent)
              .borderRadius(22)
              .border({ width: 1.5, color: $r('app.color.brand_gold') })
              .width(96)
              .height(44)
              .id(SHARE_ANCHOR_ID)
              .enabled(!this.flipping)
              .onClick(() => {
                this.shareRun();
              })
          }
          .justifyContent(FlexAlign.Center)
          .margin({ top: 4 })
        }
        .width('100%')
        .padding(24)
        .borderRadius(20)
        .backgroundColor($r('app.color.card_bg'))
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.scale({ x: 0.94, y: 0.94 }))
          .animation({ duration: 260, curve: Curve.EaseOut }))
      }

      // ===== 币面设置 =====
      Column({ space: 12 }) {
        Row() {
          Text($r('app.string.coin_face_editor_title'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Blank()
          Text($r('app.string.coin_face_editor_hint'))
            .fontSize(12)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')

        // 不给 TextInput 加 border（会导致真机无法输入）
        Row({ space: 10 }) {
          Text(FACE_HEADS)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width(36)
            .textAlign(TextAlign.End)
          TextInput({ text: this.headsText, placeholder: FACE_HEADS })
            .layoutWeight(1)
            .height(44)
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_secondary'))
            .backgroundColor($r('app.color.input_bg'))
            .borderRadius(10)
            .padding({ left: 12, right: 12 })
            .maxLength(COIN_FACE_MAX_LEN)
            .onChange((value: string) => {
              this.updateHeadsText(value);
            })
        }
        .width('100%')

        Row({ space: 10 }) {
          Text(FACE_TAILS)
            .fontSize(13)
            .fontColor($r('app.color.text_secondary'))
            .width(36)
            .textAlign(TextAlign.End)
          TextInput({ text: this.tailsText, placeholder: FACE_TAILS })
            .layoutWeight(1)
            .height(44)
            .fontSize(16)
            .fontColor($r('app.color.text_primary'))
            .placeholderColor($r('app.color.text_secondary'))
            .backgroundColor($r('app.color.input_bg'))
            .borderRadius(10)
            .padding({ left: 12, right: 12 })
            .maxLength(COIN_FACE_MAX_LEN)
            .onChange((value: string) => {
              this.updateTailsText(value);
            })
        }
        .width('100%')
      }
      .padding(16)
      .borderRadius(16)
      .backgroundColor($r('app.color.card_bg'))
      .width('100%')
      .margin({ top: 14 })

      // ===== 统计面板 =====
      Column({ space: 12 }) {
        Row() {
          Text($r('app.string.coin_stats_title'))
            .fontSize(16)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.text_primary'))
          Blank()
          if (this.totalCount > 0) {
            Text($r('app.string.coin_stats_reset'))
              .fontSize(14)
              .fontColor($r('app.color.text_secondary'))
              .padding({ left: 8, right: 8, top: 4, bottom: 4 })
              .onClick(() => {
                this.resetStats();
              })
          }
        }
        .width('100%')

        if (this.totalCount > 0) {
          // 正反占比条：正面青色，剩余为反面
          Stack({ alignContent: Alignment.Start }) {
            Row()
              .width('100%')
              .height(12)
              .borderRadius(6)
              .backgroundColor($r('app.color.input_bg'))
            Row()
              .height(12)
              .borderRadius(6)
              .backgroundColor($r('app.color.accent_teal'))
              .width(`${this.headsPct()}%`)
          }
          .width('100%')

          Row() {
            Text(`${this.faceLabelOf(0)} ${this.headsCount} 次 · ${this.headsPct()}%`)
              .fontSize(13)
              .fontColor($r('app.color.accent_teal'))
            Blank()
            Text(`${this.faceLabelOf(1)} ${this.tailsCount} 次 · ${100 - this.headsPct()}%`)
              .fontSize(13)
              .fontColor($r('app.color.accent_orange'))
          }
          .width('100%')
        } else {
          Text($r('app.string.coin_stats_empty'))
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .width('100%')
            .textAlign(TextAlign.Center)
            .padding({ top: 8, bottom: 8 })
        }
      }
      .padding(16)
      .borderRadius(16)
      .backgroundColor($r('app.color.card_bg'))
      .width('100%')
      .margin({ top: 14 })

      // ===== 历史记录 =====
      Column() {
        HistoryList({
          sectionTitle: $r('app.string.coin_history_title'),
          emptyText: $r('app.string.coin_history_empty'),
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
      .backgroundColor($r('app.color.page_bg'))
    }
    .titleMode(HdsNavigationTitleMode.MINI)
    .mode(NavigationMode.Stack)
    .titleBar({
      content: {
        title: { mainTitle: $r('app.string.coin_title') },
        backIcon: { action: (): void => this.goBack() }
      },
      style: HDS_TITLE_MATERIAL,
      // HDS 标题栏默认悬浮在内容之上；设为组件级安全区后内容区自动下移避让，不再与标题重叠
      enableComponentSafeArea: true
    })
  }
}
