import { common } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SHARE_ANCHOR_ID, showTextShare } from '../logic/ShareUtil';

/**
 * 通用结果弹窗：半透明遮罩 + 结果卡片，支持"再来一次 / 确定"。
 * 通过 if(visible) + transition 实现淡入缩放动效。
 * shareText 非空时右上角显示分享入口（F7），经系统分享面板发出。
 * 横竖屏：isLandscape 由页面传入（页面已有 mediaquery 监听），不自建监听；
 * 横屏改为主结果居左、标题/按钮居右的横向卡片，避免纵向内容超高。
 */
@Component
export struct ResultDialog {
  @Prop visible: boolean = false;
  @Prop title: ResourceStr = '';
  @Prop message: ResourceStr = '';
  /** 结果分享文本：非空时显示分享按钮（F7） */
  @Prop shareText: string = '';
  /** 横竖屏自适应：横屏为左右布局卡片 */
  @Prop isLandscape: boolean = false;
  onConfirm: () => void = () => {};
  onAgain: () => void = () => {};

  // 临时日志：旋转弹窗消失定位（机制确认后移除）
  aboutToAppear(): void {
    hilog.info(0x0000, 'WheelRotate', 'ResultDialog aboutToAppear');
  }

  aboutToDisappear(): void {
    hilog.info(0x0000, 'WheelRotate', 'ResultDialog aboutToDisappear');
  }

  /** 拉起系统分享面板；失败仅提示，不打断弹窗 */
  private share(): void {
    if (this.shareText.length === 0) {
      return;
    }
    const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
    showTextShare(context, this.shareText).catch(() => {
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.share_failed'), duration: 2000 });
    });
  }

  build() {
    if (this.visible) {
      Stack() {
        if (this.isLandscape) {
          // 横屏：主结果居左、标题/按钮居右；分享锚点仍挂右上角胶囊
          Stack({ alignContent: Alignment.TopEnd }) {
            Row({ space: 24 }) {
              Column({ space: 8 }) {
                Text('🎉')
                  .fontSize(40)
                Text(this.message)
                  .fontSize(26)
                  .fontWeight(FontWeight.Bold)
                  .fontColor($r('app.color.brand_gold'))
                  .textAlign(TextAlign.Center)
                  .constraintSize({ maxWidth: 180 })
              }
              .alignItems(HorizontalAlign.Center)

              Column({ space: 12 }) {
                Text(this.title)
                  .fontSize(16)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                Button($r('app.string.btn_again'))
                  .fontSize(16)
                  .fontColor($r('app.color.brand_gold'))
                  .backgroundColor(Color.Transparent)
                  .borderRadius(24)
                  .border({ width: 1.5, color: $r('app.color.brand_gold') })
                  .height(42)
                  .width('100%')
                  .onClick(() => {
                    this.onAgain();
                  })
                Button($r('app.string.btn_ok'))
                  .fontSize(16)
                  .fontColor($r('app.color.night_deep'))
                  .backgroundColor($r('app.color.brand_gold'))
                  .borderRadius(24)
                  .height(42)
                  .width('100%')
                  .onClick(() => {
                    this.onConfirm();
                  })
              }
              .layoutWeight(1)
            }
            .padding(24)
            .alignItems(VerticalAlign.Center)
            .width('100%')

            // 分享入口（shareText 非空才显示）
            if (this.shareText.length > 0) {
              Text($r('app.string.share_result'))
                .fontSize(13)
                .fontColor($r('app.color.brand_gold'))
                .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                .borderRadius(14)
                .border({ width: 1, color: $r('app.color.brand_gold') })
                .margin(12)
                .id(SHARE_ANCHOR_ID)
                .onClick(() => this.share())
            }
          }
          .borderRadius(24)
          .backgroundColor($r('app.color.card_bg'))
          .width('86%')
          .constraintSize({ maxWidth: 480 })
          .shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.45)', offsetY: 8 })
          .transition(TransitionEffect.OPACITY
            .animation({ duration: 260, curve: Curve.EaseOut })
            .combine(TransitionEffect.scale({ x: 0.82, y: 0.82 })
              .animation({ duration: 260, curve: Curve.EaseOut })))
        } else {
          // 竖屏：纵向卡片（已验证布局，保持原样）
          Stack({ alignContent: Alignment.TopEnd }) {
            Column({ space: 14 }) {
              Text('🎉')
                .fontSize(44)
              Text(this.title)
                .fontSize(16)
                .fontColor($r('app.color.text_secondary'))
              Text(this.message)
                .fontSize(30)
                .fontWeight(FontWeight.Bold)
                .fontColor($r('app.color.brand_gold'))
                .textAlign(TextAlign.Center)
              Row({ space: 14 }) {
                Button($r('app.string.btn_again'))
                  .fontSize(16)
                  .fontColor($r('app.color.brand_gold'))
                  .backgroundColor(Color.Transparent)
                  .borderRadius(24)
                  .border({ width: 1.5, color: $r('app.color.brand_gold') })
                  .height(42)
                  .layoutWeight(1)
                  .onClick(() => {
                    this.onAgain();
                  })
                Button($r('app.string.btn_ok'))
                  .fontSize(16)
                  .fontColor($r('app.color.night_deep'))
                  .backgroundColor($r('app.color.brand_gold'))
                  .borderRadius(24)
                  .height(42)
                  .layoutWeight(1)
                  .onClick(() => {
                    this.onConfirm();
                  })
              }
              .width('100%')
              .margin({ top: 8 })
            }
            .padding(28)
            .width('100%')
            .alignItems(HorizontalAlign.Center)

            // 分享入口（shareText 非空才显示）
            if (this.shareText.length > 0) {
              Text($r('app.string.share_result'))
                .fontSize(13)
                .fontColor($r('app.color.brand_gold'))
                .padding({ left: 12, right: 12, top: 5, bottom: 5 })
                .borderRadius(14)
                .border({ width: 1, color: $r('app.color.brand_gold') })
                .margin(12)
                .id(SHARE_ANCHOR_ID)
                .onClick(() => this.share())
            }
          }
          .borderRadius(24)
          .backgroundColor($r('app.color.card_bg'))
          .width('78%')
          .constraintSize({ maxWidth: 340 })
          .shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.45)', offsetY: 8 })
          .transition(TransitionEffect.OPACITY
            .animation({ duration: 260, curve: Curve.EaseOut })
            .combine(TransitionEffect.scale({ x: 0.82, y: 0.82 })
              .animation({ duration: 260, curve: Curve.EaseOut })))
        }
      }
      .width('100%')
      .height('100%')
      .backgroundColor($r('app.color.overlay_mask'))
      .transition(TransitionEffect.OPACITY.animation({ duration: 220 }))
    }
  }
}
