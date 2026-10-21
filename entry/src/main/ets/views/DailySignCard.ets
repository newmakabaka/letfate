/**
 * 2×2「每日一签」桌面卡片。
 * 卡面固定深色底（与签筒视觉同源），不随系统深浅色切换，
 * 故直接使用色值常量（与 color.json 浅色值同源）而非 $r 颜色资源。
 */

let cardStorage = new LocalStorage();

@Entry(cardStorage)
@Component
struct DailySignCard {
  // 由 DailySignFormAbility 通过 formBindingData 注入
  @LocalStorageProp('levelName') levelName: string = '中签';
  @LocalStorageProp('signTitle') signTitle: string = '守常待时';

  /** 签级展示色：与页面 levelColor 同映射（上上红 / 上金 / 中紫 / 中平青 / 下灰紫） */
  private levelColor(name: string): string {
    if (name === '上上签') {
      return '#E86A5E';
    }
    if (name === '上签') {
      return '#F5C866';
    }
    if (name === '中签') {
      return '#A08CF0';
    }
    if (name === '中平签') {
      return '#7FC8A9';
    }
    return '#8B87A3';
  }

  build() {
    Column() {
      Text($r('app.string.card_daily_title'))
        .fontSize(11)
        .fontColor('#F5C866')
        .opacity(0.85)

      Column() {
        Text(this.levelName)
          .fontSize(26)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.levelColor(this.levelName))
        Text(this.signTitle)
          .fontSize(15)
          .fontColor('#F5EFE0')
          .maxLines(1)
          .margin({ top: 6 })
      }
      .layoutWeight(1)
      .justifyContent(FlexAlign.Center)
      .alignItems(HorizontalAlign.Center)

      Text($r('app.string.card_daily_tap'))
        .fontSize(10)
        .fontColor('#F5EFE0')
        .opacity(0.5)
    }
    .width('100%')
    .height('100%')
    .padding({ left: 14, right: 14, top: 12, bottom: 10 })
    .linearGradient({
      angle: 180,
      colors: [['#454158', 0], ['#302D41', 1]]
    })
    .borderRadius(16)
    .onClick(() => {
      postCardAction(this, {
        action: 'router',
        abilityName: 'EntryAbility',
        params: { targetPage: 'draw' }
      });
    })
  }
}
