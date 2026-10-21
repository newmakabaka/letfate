import { mediaquery, router } from '@kit.ArkUI';

/** 首页功能卡片数据 */
interface HomeCard {
  icon: string;
  name: ResourceStr;
  desc: ResourceStr;
  route: string;
}

@Entry
@Component
struct Index {
  /** 横屏时压缩顶部留白与间距（轻量适配，不做分栏） */
  @State isLandscape: boolean = false;
  private landscapeListener?: mediaquery.MediaQueryListener;
  private cards: HomeCard[] = [
    {
      icon: '🎯',
      name: $r('app.string.card_wheel_name'),
      desc: $r('app.string.card_wheel_desc'),
      route: 'pages/WheelPage'
    },
    {
      icon: '🎋',
      name: $r('app.string.card_draw_name'),
      desc: $r('app.string.card_draw_desc'),
      route: 'pages/DrawPage'
    },
    {
      icon: '🪙',
      name: $r('app.string.card_coin_name'),
      desc: $r('app.string.card_coin_desc'),
      route: 'pages/CoinPage'
    }
  ];

  aboutToAppear(): void {
    const listener = mediaquery.matchMediaSync('(orientation: landscape)');
    this.landscapeListener = listener;
    this.isLandscape = listener.matches;
    listener.on('change', (result: mediaquery.MediaQueryResult) => {
      this.isLandscape = result.matches;
    });
  }

  aboutToDisappear(): void {
    this.landscapeListener?.off('change');
  }

  private onCardClick(card: HomeCard): void {
    if (card.route.length > 0) {
      router.pushUrl({ url: card.route }).catch(() => {});
    } else {
      this.getUIContext().getPromptAction().showToast({ message: $r('app.string.toast_developing') });
    }
  }

  build() {
    Column() {
      Text($r('app.string.index_title'))
        .fontSize(this.isLandscape ? 28 : 34)
        .fontWeight(FontWeight.Bold)
        .fontColor($r('app.color.brand_gold'))
      Text($r('app.string.index_slogan'))
        .fontSize(14)
        .fontColor($r('app.color.text_secondary'))
        .margin({ top: this.isLandscape ? 4 : 8 })

      Scroll() {
        Column({ space: 14 }) {
          ForEach(this.cards, (card: HomeCard) => {
            Row({ space: 16 }) {
              Text(card.icon)
                .fontSize(28)
                .width(56)
                .height(56)
                .textAlign(TextAlign.Center)
                .borderRadius(16)
                .backgroundColor($r('app.color.chip_bg'))
              Column({ space: 4 }) {
                Text(card.name)
                  .fontSize(18)
                  .fontWeight(FontWeight.Medium)
                  .fontColor($r('app.color.text_primary'))
                Text(card.desc)
                  .fontSize(13)
                  .fontColor($r('app.color.text_secondary'))
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)
              Text('›')
                .fontSize(22)
                .fontColor($r('app.color.text_secondary'))
            }
            .width('100%')
            .padding(18)
            .borderRadius(20)
            .backgroundColor($r('app.color.card_bg'))
            .onClick(() => {
              this.onCardClick(card);
            })
          }, (card: HomeCard) => card.icon)
        }
        .width('88%')
        .constraintSize({ maxWidth: 420 })
        .margin({ top: this.isLandscape ? 20 : 48 })
      }
      .layoutWeight(1)
      .scrollBar(BarState.Off)
      .width('100%')
      .align(this.isLandscape ? Alignment.Center : Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .alignItems(HorizontalAlign.Center)
    .padding({ top: this.isLandscape ? 24 : 88, bottom: 16 })
    .backgroundColor($r('app.color.page_bg'))
  }
}
