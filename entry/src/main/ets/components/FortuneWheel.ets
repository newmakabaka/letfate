import {
  WHEEL_LABEL_COLOR,
  WHEEL_LABEL_FONT_SCALE,
  WHEEL_RING_COLOR,
  WHEEL_SECTOR_PALETTE,
  WHEEL_SEPARATOR_COLOR
} from '../model/WheelModels';

/**
 * Canvas 幸运转盘：静态盘面（扇区 + 径向文字 + 金色外环）由 Canvas 绘制，
 * 旋转通过外层 rotate 属性动画驱动；指针与中心按钮为静态覆盖层，不参与旋转。
 */
@Component
export struct FortuneWheel {
  /** 当前选项列表（已清洗，≥2 项），变化时重绘盘面。 */
  @Prop @Watch('onDataChange') options: string[] = [];
  /** 盘面累计旋转角度（度），由父组件通过属性动画驱动。 */
  @Prop rotation: number = 0;
  /** 中奖扇区高亮下标，-1 表示无高亮。 */
  @Prop @Watch('onDataChange') highlightIndex: number = -1;
  /** 点击中心按钮（等效于页面上的开始按钮）。 */
  onHubClick: () => void = () => {};

  private settings: RenderingContextSettings = new RenderingContextSettings(true);
  private context: CanvasRenderingContext2D = new CanvasRenderingContext2D(this.settings);
  private canvasReady: boolean = false;

  // 盘面配色：Canvas 无法直接消费 $r 资源，取自模型层常量（与 color.json 同源）
  private palette: string[] = WHEEL_SECTOR_PALETTE;
  private separatorColor: string = WHEEL_SEPARATOR_COLOR;
  private labelColor: string = WHEEL_LABEL_COLOR;
  private ringColor: string = WHEEL_RING_COLOR;

  // @Watch 回调（参数为触发变化的属性名）
  onDataChange(propName: string): void {
    this.drawWheel();
  }

  private rad(deg: number): number {
    return deg * Math.PI / 180;
  }

  private drawWheel(): void {
    if (!this.canvasReady) {
      return;
    }
    const ctx = this.context;
    const side = Math.min(ctx.width, ctx.height);
    if (side <= 0) {
      return;
    }
    const cx = side / 2;
    const cy = side / 2;
    const radius = side / 2 - 8;
    const count = this.options.length;
    ctx.clearRect(0, 0, ctx.width, ctx.height);
    if (count < 2) {
      this.drawRing(ctx, cx, cy, radius);
      return;
    }
    const seg = 360 / count;
    for (let i = 0; i < count; i++) {
      const startDeg = -90 + i * seg;
      ctx.beginPath();
      ctx.moveTo(cx, cy);
      ctx.arc(cx, cy, radius, this.rad(startDeg), this.rad(startDeg + seg));
      ctx.closePath();
      ctx.fillStyle = this.palette[i % this.palette.length];
      ctx.fill();
      ctx.lineWidth = 2;
      ctx.strokeStyle = this.separatorColor;
      ctx.stroke();
      if (i === this.highlightIndex) {
        ctx.fillStyle = 'rgba(255, 255, 255, 0.45)';
        ctx.fill();
      }
    }
    this.drawRing(ctx, cx, cy, radius);
    for (let i = 0; i < count; i++) {
      this.drawLabel(ctx, i, count, seg, cx, cy, radius);
    }
  }

  private drawRing(ctx: CanvasRenderingContext2D, cx: number, cy: number, radius: number): void {
    ctx.beginPath();
    ctx.arc(cx, cy, radius + 4, 0, Math.PI * 2);
    ctx.lineWidth = 6;
    ctx.strokeStyle = this.ringColor;
    ctx.stroke();
  }

  /**
   * 沿扇区中心角绘制径向文字。
   * 翻转规则：左半盘（90°~270°）额外旋转 180° 后以 -dist 绘制，
   * 只翻转阅读方向、不改变落点（此前误用 +dist 导致左半盘文字画到对侧，造成"只显示半边/重叠"）。
   * 字号：基准值随选项数减半盘增；再按标签长度自适应收缩，优先完整显示；
   * 仍超长时才截断，保证文字不越出扇区、不与相邻文字或中心按钮重叠。
   */
  private drawLabel(ctx: CanvasRenderingContext2D, index: number, count: number, seg: number,
    cx: number, cy: number, radius: number): void {
    let label = this.options[index];
    if (label.length === 0) {
      return;
    }
    const baseFs = count <= 4 ? radius * 0.34 :
      (count <= 6 ? radius * 0.29 : (count <= 9 ? radius * 0.24 : radius * 0.20));
    const dist = radius * 0.62;
    const fitFs = (radius * 0.90) / label.length;
    // WHEEL_LABEL_FONT_SCALE：用户可调的字号倍率，见 model/WheelModels.ets
    const fontSize = Math.max(12, Math.min(baseFs, fitFs) * WHEEL_LABEL_FONT_SCALE);
    const maxChars = Math.max(1.3, Math.floor((radius * 1.10) / fontSize));
    if (label.length > maxChars) {
      label = label.substring(0, Math.max(1, maxChars - 1)) + '…';
    }
    const centerDeg = -90 + index * seg + seg / 2;
    const normalized = ((centerDeg % 360) + 360) % 360;
    ctx.save();
    ctx.translate(cx, cy);
    ctx.rotate(this.rad(centerDeg));
    let drawX = dist;
    if (normalized > 90 && normalized < 270) {
      ctx.rotate(Math.PI);
      drawX = -dist;
    }
    ctx.font = `bold ${Math.round(fontSize)}px sans-serif`;
    ctx.textBaseline = 'middle';
    ctx.textAlign = 'center';
    ctx.fillStyle = this.labelColor;
    ctx.fillText(label, drawX, 0);
    ctx.restore();
  }

  build() {
    Stack() {
      // 旋转盘面
      Column() {
        Canvas(this.context)
          .width('100%')
          .height('100%')
          .onReady(() => {
            this.canvasReady = true;
            this.drawWheel();
          })
          // 横竖屏切换导致组件尺寸变化时重绘盘面（绘制半径按当前尺寸实时计算）
          .onAreaChange((oldValue: Area, newValue: Area) => {
            this.drawWheel();
          })
          .rotate({
            x: 0,
            y: 0,
            z: 1,
            angle: this.rotation,
            centerX: '50%',
            centerY: '50%'
          })
      }
      .width('100%')
      .height('100%')

      // 顶部指针（静态覆盖层；形状组件的 shadow 会按矩形边界渲染出方框，故不使用）
      Column() {
        Polygon({ width: 38, height: 32 })
          .points([[9, 2], [29, 2], [19, 28]])
          .fill(this.ringColor)
          .stroke(this.separatorColor)
          .strokeWidth(2)
          .margin({ top: 2 })
      }
      .width('100%')
      .height('100%')

      // 中心按钮（整体尺寸为 0.75 倍：58 / 45 / 18）
      Column() {
        Stack() {
          Circle({ width: 58, height: 58 })
            .fill(this.ringColor)
          Column() {
            Text('GO')
              .fontSize(18)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.ringColor)
          }
          .width(45)
          .height(45)
          .borderRadius(22.5)
          .backgroundColor(this.separatorColor)
          .justifyContent(FlexAlign.Center)
          .alignItems(HorizontalAlign.Center)
        }
        .onClick(() => {
          this.onHubClick();
        })
      }
      .width('100%')
      .height('100%')
      .justifyContent(FlexAlign.Center)
    }
    .width('100%')
    .height('100%')
  }
}
