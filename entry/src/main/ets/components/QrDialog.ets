import { image } from '@kit.ImageKit';
import { SHARE_ANCHOR_ID } from '../logic/ShareUtil';

/**
 * 二维码展示弹层（F8）：遮罩 + 卡片（码图 + 提示 + 分享/关闭），样式对齐 ResultDialog。
 * pixelMap 由页面异步生成后传入（不用装饰器，避免对 native 对象做深拷贝），
 * visible 变化驱动重渲染。
 * 横竖屏（F4）：isLandscape 由页面传入（页面已有 mediaquery 监听），
 * 横屏改为码图在左、文案按钮在右的横向卡片，避免纵向内容超高被截断。
 */
@Component
export struct QrDialog {
  @Prop visible: boolean = false;
  @Prop title: ResourceStr = '';
  @Prop isLandscape: boolean = false;
  pixelMap?: image.PixelMap;
  onShare: () => void = () => {};
  onClose: () => void = () => {};

  /** 分享/确定按钮组：横竖屏共用（锚点 ID 必须始终挂在分享键上） */
  @Builder
  actionButtons() {
    Row({ space: 14 }) {
      Button($r('app.string.share_result'))
        .fontSize(16)
        .fontColor($r('app.color.brand_gold'))
        .backgroundColor(Color.Transparent)
        .borderRadius(24)
        .border({ width: 1.5, color: $r('app.color.brand_gold') })
        .height(42)
        .layoutWeight(1)
        .id(SHARE_ANCHOR_ID)
        .onClick(() => {
          this.onShare();
        })
      Button($r('app.string.btn_ok'))
        .fontSize(16)
        .fontColor($r('app.color.night_deep'))
        .backgroundColor($r('app.color.brand_gold'))
        .borderRadius(24)
        .height(42)
        .layoutWeight(1)
        .onClick(() => {
          this.onClose();
        })
    }
    .width('100%')
  }

  /** 二维码码图：横屏收窄为 190，竖屏 240 */
  @Builder
  qrImage() {
    if (this.pixelMap) {
      Image(this.pixelMap)
        .width(this.isLandscape ? 190 : 240)
        .height(this.isLandscape ? 190 : 240)
        .borderRadius(12)
        .objectFit(ImageFit.Contain)
    }
  }

  build() {
    if (this.visible) {
      Stack() {
        if (this.isLandscape) {
          Row({ space: 20 }) {
            this.qrImage()
            Column({ space: 12 }) {
              Text(this.title)
                .fontSize(16)
                .fontWeight(FontWeight.Medium)
                .fontColor($r('app.color.text_primary'))
              Text($r('app.string.qr_hint'))
                .fontSize(13)
                .fontColor($r('app.color.text_secondary'))
                .textAlign(TextAlign.Center)
              this.actionButtons()
            }
            .layoutWeight(1)
            .alignItems(HorizontalAlign.Center)
          }
          .padding(24)
          .alignItems(VerticalAlign.Center)
          .borderRadius(24)
          .backgroundColor($r('app.color.card_bg'))
          .width('86%')
          .constraintSize({ maxWidth: 520 })
          .shadow({ radius: 24, color: 'rgba(0, 0, 0, 0.45)', offsetY: 8 })
          .transition(TransitionEffect.OPACITY
            .animation({ duration: 260, curve: Curve.EaseOut })
            .combine(TransitionEffect.scale({ x: 0.82, y: 0.82 })
              .animation({ duration: 260, curve: Curve.EaseOut })))
        } else {
          Column({ space: 14 }) {
            Text(this.title)
              .fontSize(16)
              .fontWeight(FontWeight.Medium)
              .fontColor($r('app.color.text_primary'))
            this.qrImage()
            Text($r('app.string.qr_hint'))
              .fontSize(13)
              .fontColor($r('app.color.text_secondary'))
              .textAlign(TextAlign.Center)
            // @Builder 调用不可链属性，竖屏的额外间距由外层容器承担
            Column() {
              this.actionButtons()
            }
            .width('100%')
            .margin({ top: 8 })
          }
          .padding(24)
          .width('78%')
          .constraintSize({ maxWidth: 340 })
          .borderRadius(24)
          .backgroundColor($r('app.color.card_bg'))
          .alignItems(HorizontalAlign.Center)
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
