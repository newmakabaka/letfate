/**
 * 历史记录列表（展示用）：接收已格式化的记录行，支持清空。
 * 记录格式由父组件组装："结果 · 时间"。
 */
@Component
export struct HistoryList {
  @Prop sectionTitle: ResourceStr = '';
  @Prop emptyText: ResourceStr = '';
  @Prop records: string[] = [];
  onClear: () => void = () => {};

  build() {
    Column({ space: 12 }) {
      Row() {
        Text(this.sectionTitle)
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.text_primary'))
        Blank()
        if (this.records.length > 0) {
          Text($r('app.string.btn_clear'))
            .fontSize(14)
            .fontColor($r('app.color.text_secondary'))
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .onClick(() => {
              this.onClear();
            })
        }
      }
      .width('100%')

      if (this.records.length === 0) {
        Text(this.emptyText)
          .fontSize(14)
          .fontColor($r('app.color.text_secondary'))
          .width('100%')
          .textAlign(TextAlign.Center)
          .padding({ top: 18, bottom: 18 })
      } else {
        List({ space: 8 }) {
          ForEach(this.records, (rec: string, idx: number) => {
            ListItem() {
              Text(rec)
                .fontSize(14)
                .fontColor($r('app.color.text_primary'))
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
                .padding({ left: 12, right: 12, top: 10, bottom: 10 })
                .borderRadius(10)
                .backgroundColor($r('app.color.input_bg'))
            }
          }, (rec: string, idx: number) => `${idx}_${rec}`)
        }
        .width('100%')
        .height(220)
        .scrollBar(BarState.Off)
      }
    }
    .padding(16)
    .borderRadius(16)
    .backgroundColor($r('app.color.card_bg'))
    .width('100%')
  }
}
