import { common } from '@kit.AbilityKit';
import { mediaquery } from '@kit.ArkUI';
import { HdsNavigation, HdsNavigationTitleMode } from '@kit.UIDesignKit';
import { HistoryList } from '../components/HistoryList';
import { HDS_TITLE_MATERIAL } from '../components/HdsTitleStyle';
import { SHARE_ANCHOR_ID, buildSignShareText, showTextShare } from '../logic/ShareUtil';
import { SignEngine } from '../logic/SignEngine';
import { HistoryItem, HistoryManager } from '../logic/HistoryManager';
import { DRAW_HISTORY_MODULE, SIGN_LEVELS } from '../model/SignModels';

const HISTORY_DISPLAY_MAX: number = 50;
/** 签筒摇动摆角序列（度），逐段平滑过渡 */
const SHAKE_ANGLES: number[] = [-7, 6, -4, 0];
/** 摇动单步时长（毫秒），四步总时长约 760ms */
const SHAKE_STEP_MS: number = 190;
/** 签枝高度序列（竖屏基准，横屏按比例缩放） */
const STICK_HEIGHTS: number[] = [96, 86, 104, 88, 94];
/** 签枝倾斜角序列（度） */
const STICK_TILTS: number[] = [-10, -4, 0, 5, 12];
/** 签筒舞台纵向跨度系数：升签槽 92 + 签枝 104−6 + 筒身 168−6（均随缩放系数变化） */
const TUBE_SPAN: number = 352;
/** 横屏舞台固定占用：顶部对齐 6 + 提示行 24 + 按钮 54 + 底部预留 28 */
const STAGE_FIXED_H: number = 112;
/** 横屏签筒缩放上下限 */
const TUBE_SCALE_MAX: number = 0.6;
const TUBE_SCALE_MIN: number = 0.35;
/** 卡片直达求签页时的上级页面：主页 */
const HOME_URL: string = 'pages/Index';

@Entry
@Component
struct DrawPage {
  /** 签筒当前摆角（度） */
  @State tubeAngle: number = 0;
  /** 是否正在摇签（动画进行中） */
  @State drawing: boolean = false;
  /** 抽中的签的透明度 / 上移偏移（升起动画） */
  @State stickOpacity: number = 0;
  @State stickOffsetY: number = 70;
  /** 签文详情卡是否展开 */
  @State resultShown: boolean = false;
  @State signLevelIndex: number = 0;
  @State signTitle: string = '';
  @State signPoem: string[] = [];
  @State signInterpret: string = '';
  @State historyLines: string[] = [];
  /** 横竖屏自适应：横屏为左舞台（签筒+摇签）/右信息（签文+历史）双栏 */
  @State isLandscape: boolean = false;
  /** 横屏左栏实测高度，用于计算签筒缩放，保证舞台整体不超出可用高度 */
  @State stageH: number = 0;
  private landscapeListener?: mediaquery.MediaQueryListener;

  aboutToAppear(): void {
    const listener = mediaquery.matchMediaSync('(orientation: landscape)');
    this.landscapeListener = listener;
    this.isLandscape = listener.matches;
    listener.on('change', (result: mediaquery.MediaQueryResult) => {
      this.isLandscape = result.matches;
    });
    this.historyLines = HistoryManager
      .load(this.appContext(), DRAW_HISTORY_MODULE)
      .slice(0, HISTORY_DISPLAY_MAX)
      .map((it: HistoryItem): string => `${it.title} · ${HistoryManager.formatTime(it.time)}`);
  }

  aboutToDisappear(): void {
    this.landscapeListener?.off('change');
  }

  private appContext(): common.UIAbilityContext {
    return this.getUIContext().getHostContext() as common.UIAbilityContext;
  }

  /**
   * 签筒舞台缩放：竖屏固定 1（原始布局）；
   * 横屏按左栏实测高度自适应：(栏高 − 固定占用) ÷ 纵向跨度系数，
   * 签筒随设备实际可用高度缩小，保证提示与摇签按钮始终完整落在栏内、不压底部。
   */
  private ts(): number {
    if (!this.isLandscape) {
      return 1;
    }
    if (this.stageH <= STAGE_FIXED_H + 120) {
      return TUBE_SCALE_MIN;
    }
    return Math.max(TUBE_SCALE_MIN, Math.min(TUBE_SCALE_MAX, (this.stageH - STAGE_FIXED_H) / TUBE_SPAN));
  }

  /** 签级展示色：上上红 / 上金 / 中紫 / 中平青 / 下灰紫（详情卡徽章用） */
  private levelColor(index: number): Resource {
    if (index === 0) {
      return $r('app.color.accent_red');
    }
    if (index === 1) {
      return $r('app.color.brand_gold');
    }
    if (index === 2) {
      return $r('app.color.accent_purple');
    }
    if (index === 3) {
      return $r('app.color.accent_teal');
    }
    return $r('app.color.text_secondary');
  }

  /** 抽出签枝的颜色：随签级变化，上上红 / 上金 / 中紫 / 中平青 / 下黑 */
  private stickColor(index: number): Resource {
    if (index === 0) {
      return $r('app.color.accent_red');
    }
    if (index === 1) {
      return $r('app.color.brand_gold');
    }
    if (index === 2) {
      return $r('app.color.accent_purple');
    }
    if (index === 3) {
      return $r('app.color.accent_teal');
    }
    return $r('app.color.sign_stick_down');
  }

  /** 摇签：先定结果，再依次播放 签筒摇动 → 签升起 → 展开签文。 */
  private startDraw(): void {
    if (this.drawing) {
      return;
    }
    const sign = SignEngine.drawSign();
    this.signLevelIndex = sign.levelIndex;
    this.signTitle = sign.title;
    this.signPoem = sign.poem;
    this.signInterpret = sign.interpret;
    this.drawing = true;
    this.resultShown = false;
    this.stickOpacity = 0;
    this.stickOffsetY = 70;
    this.shakeStep(0);
  }

  /** 签筒左右摆动：链式 animateTo 逐段过渡摆角，最后一段归零。 */
  private shakeStep(step: number): void {
    if (step >= SHAKE_ANGLES.length) {
      this.revealStick();
      return;
    }
    this.getUIContext().animateTo({
      duration: SHAKE_STEP_MS,
      curve: Curve.EaseInOut,
      onFinish: () => {
        this.shakeStep(step + 1);
      }
    }, () => {
      this.tubeAngle = SHAKE_ANGLES[step];
    });
  }

  /** 抽中的签从筒口升起。 */
  private revealStick(): void {
    this.getUIContext().animateTo({
      duration: 420,
      curve: Curve.EaseOut,
      onFinish: () => {
        this.showResult();
      }
    }, () => {
      this.stickOpacity = 1;
      this.stickOffsetY = 0;
    });
  }

  /** 展开签文详情并写入历史。 */
  private showResult(): void {
    const levelName = SIGN_LEVELS[this.signLevelIndex];
    const item = HistoryManager.add(this.appContext(), DRAW_HISTORY_MODULE, `${levelName}·${this.signTitle}`);
    this.historyLines =
      [`${item.title} · ${HistoryManager.formatTime(item.time)}`, ...this.historyLines].slice(0, HISTORY_DISPLAY_MAX);
    this.getUIContext().animateTo({ duration: 280, curve: Curve.EaseOut }, () => {
      this.resultShown = true;
      this.drawing = false;
    });
  }

  private clearHistory(): void {
    HistoryManager.clear(this.appContext(), DRAW_HISTORY_MODULE);
    this.historyLines = [];
  }

  private toast(message: string | Resource): void {
    this.getUIContext().getPromptAction().showToast({ message: message, duration: 2000 });
  }

  /** 分享当前签文（F7）：签级 + 签题 + 签诗全文，经系统分享面板发出。 */
  private shareSign(): void {
    if (!this.resultShown) {
      return;
    }
    const text = buildSignShareText(SIGN_LEVELS[this.signLevelIndex], this.signTitle, this.signPoem);
    showTextShare(this.appContext(), text).catch(() => {
      this.toast($r('app.string.share_failed'));
    });
  }

  /** 返回导航：卡片直达时本页是根页面，返回改为回主页，避免直接退出到桌面。 */
  private goBack(): void {
    if (this.getUIContext().getRouter().getStackSize() <= 1) {
      this.getUIContext().getRouter().replaceUrl({ url: HOME_URL }).catch(() => {});
    } else {
      this.getUIContext().getRouter().back();
    }
  }

  /** 系统返回（导航键/侧滑手势）统一走 goBack。 */
  onBackPress(): boolean {
    this.goBack();
    return true;
  }

  /** 签筒舞台：升签槽位 + 签枝 + 筒身，整体尺寸随 ts() 缩放。 */
  @Builder
  TubeBlock() {
    Column() {
      // 升起的签：固定高度槽位，布局不随透明度变化跳动；签色随抽中的签级变化
      Column() {
        Column()
          .width(10 * this.ts())
          .height(92 * this.ts())
          .borderRadius(5 * this.ts())
          .backgroundColor(this.stickColor(this.signLevelIndex))
          .opacity(this.stickOpacity)
          .translate({ y: this.stickOffsetY * this.ts() })
      }
      .height(92 * this.ts())
      .justifyContent(FlexAlign.End)

      // 签枝
      Row({ space: 5 * this.ts() }) {
        ForEach(STICK_HEIGHTS, (h: number, i: number) => {
          Column()
            .width(9 * this.ts())
            .height(h * this.ts())
            .borderRadius(4 * this.ts())
            .backgroundColor($r('app.color.sign_stick'))
            .rotate({ angle: STICK_TILTS[i] })
        }, (h: number, i: number) => `stick_${i}`)
      }
      .alignItems(VerticalAlign.Bottom)
      .margin({ bottom: -6 * this.ts() })

      // 筒身
      Column() {
        // 束口金带
        Row()
          .width('100%')
          .height(16 * this.ts())
          .borderRadius({ topLeft: 20 * this.ts(), topRight: 20 * this.ts() })
          .backgroundColor($r('app.color.brand_gold'))
        Column({ space: 6 * this.ts() }) {
          Text('签')
            .fontSize(52 * this.ts())
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.brand_gold'))
          Text($r('app.string.index_title'))
            .fontSize(this.isLandscape ? 10 : 12)
            .fontColor($r('app.color.text_secondary'))
        }
        .width('100%')
        .layoutWeight(1)
        .justifyContent(FlexAlign.Center)
      }
      .width(140 * this.ts())
      .height(168 * this.ts())
      .borderRadius({
        topLeft: 20 * this.ts(),
        topRight: 20 * this.ts(),
        bottomLeft: 28 * this.ts(),
        bottomRight: 28 * this.ts()
      })
      .linearGradient({
        angle: 180,
        colors: [[$r('app.color.sign_tube_top'), 0], [$r('app.color.night_deep'), 1]]
      })
      .margin({ top: -6 * this.ts() })
    }
    .alignItems(HorizontalAlign.Center)
    .rotate({ x: 0, y: 0, z: 1, angle: this.tubeAngle, centerX: '50%', centerY: '100%' })
    .margin({ top: this.isLandscape ? 0 : 10 })
  }

  /** 舞台：签筒 + 提示 + 摇签按钮（横竖屏共用，尺寸随方向切换）。 */
  @Builder
  StagePane() {
    Column() {
      this.TubeBlock()

      Text($r('app.string.draw_hint'))
        .fontSize(13)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: this.isLandscape ? 6 : 18 })

      Button(this.drawing ? $r('app.string.draw_drawing') : $r('app.string.draw_start'))
        .fontSize(this.isLandscape ? 18 : 20)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.night_deep'))
        .backgroundColor($r('app.color.brand_gold'))
        .borderRadius(this.isLandscape ? 23 : 26)
        .width(this.isLandscape ? 170 : 200)
        .height(this.isLandscape ? 46 : 52)
        .margin({ top: this.isLandscape ? 8 : 16, bottom: this.isLandscape ? 0 : 24 })
        .enabled(!this.drawing)
        .opacity(this.drawing ? 0.6 : 1)
        .onClick(() => {
          this.startDraw();
        })
    }
    .width('100%')
    .alignItems(HorizontalAlign.Center)
  }

  /** 信息：签文详情 + 历史（竖屏在舞台下方，横屏在右栏滚动）。 */
  @Builder
  InfoPane() {
    Column() {
      // ===== 签文详情 =====
      if (this.resultShown) {
        Column({ space: 14 }) {
          Text(SIGN_LEVELS[this.signLevelIndex])
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.levelColor(this.signLevelIndex))
            .padding({ left: 18, right: 18, top: 6, bottom: 6 })
            .borderRadius(20)
            .border({ width: 1.5, color: this.levelColor(this.signLevelIndex) })

          Text(this.signTitle)
            .fontSize(26)
            .fontWeight(FontWeight.Bold)
            .fontColor($r('app.color.text_primary'))

          Column({ space: 6 }) {
            ForEach(this.signPoem, (line: string) => {
              Text(line)
                .fontSize(17)
                .fontColor($r('app.color.text_primary'))
                .letterSpacing(2)
            }, (line: string, idx: number) => `${idx}_${line}`)
          }
          .alignItems(HorizontalAlign.Center)
          .margin({ top: 4 })

          Divider()
            .strokeWidth(1)
            .color($r('app.color.text_secondary'))
            .opacity(0.35)
            .width('72%')

          Text($r('app.string.draw_interpret_label'))
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor($r('app.color.brand_gold'))

          Text(this.signInterpret)
            .fontSize(15)
            .fontColor($r('app.color.text_secondary'))
            .lineHeight(24)
            .textAlign(TextAlign.Center)

          Row({ space: 12 }) {
            Button($r('app.string.draw_again'))
              .fontSize(17)
              .fontWeight(FontWeight.Bold)
              .fontColor($r('app.color.night_deep'))
              .backgroundColor($r('app.color.brand_gold'))
              .borderRadius(22)
              .width(160)
              .height(44)
              .onClick(() => {
                this.startDraw();
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
              .onClick(() => {
                this.shareSign();
              })
          }
          .justifyContent(FlexAlign.Center)
          .margin({ top: 8 })
        }
        .width('100%')
        .padding(24)
        .borderRadius(20)
        .backgroundColor($r('app.color.card_bg'))
        .transition(TransitionEffect.OPACITY
          .combine(TransitionEffect.scale({ x: 0.92, y: 0.92 }))
          .animation({ duration: 280, curve: Curve.EaseOut }))
      }

      // ===== 历史记录 =====
      Column() {
        HistoryList({
          sectionTitle: $r('app.string.draw_history_title'),
          emptyText: $r('app.string.draw_history_empty'),
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
            // 舞台整体靠上排布，避免横屏时摇签按钮压到屏幕底部留白
            .justifyContent(FlexAlign.Start)
            .padding({ top: 6 })
            .onAreaChange((oldValue: Area, newValue: Area) => {
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
      .backgroundColor($r('app.color.page_bg'))
    }
    .titleMode(HdsNavigationTitleMode.MINI)
    .mode(NavigationMode.Stack)
    .titleBar({
      content: {
        title: { mainTitle: $r('app.string.draw_title') },
        backIcon: { action: (): void => this.goBack() }
      },
      style: HDS_TITLE_MATERIAL,
      // HDS 标题栏默认悬浮在内容之上；设为组件级安全区后内容区自动下移避让，不再与标题重叠
      enableComponentSafeArea: true
    })
  }
}
