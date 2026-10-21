import { AbilityConstant, ConfigurationConstant, UIAbility, Want } from '@kit.AbilityKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { window } from '@kit.ArkUI';

const DOMAIN = 0x0000;
/** 服务卡片 router 事件参数：postCardAction params 以 JSON 字符串形式落在 want.parameters.params */
const PAGE_DRAW = 'pages/DrawPage';
const PAGE_INDEX = 'pages/Index';

export default class EntryAbility extends UIAbility {
  /** 卡片跳转目标（'draw' → 求签页）；每次解析前复位，避免残留参数劫持后续正常启动 */
  private cardTargetPage: string = '';
  private currentWindowStage: window.WindowStage | null = null;

  private parseCardParams(want: Want): void {
    this.cardTargetPage = '';
    try {
      const raw = want?.parameters?.params;
      if (raw) {
        const parsed = JSON.parse(raw as string) as Record<string, Object>;
        const target = parsed['targetPage'];
        if (typeof target === 'string') {
          this.cardTargetPage = target;
        }
      }
    } catch (err) {
      this.cardTargetPage = '';
    }
  }

  /** 卡片直达目标页直接作为根页面加载；返回逻辑由页面侧 onBackPress 处理（见 DrawPage.goBack） */
  private loadTargetPage(stage: window.WindowStage): void {
    stage.loadContent(this.targetPageUrl(), (err) => {
      if (err.code) {
        hilog.error(DOMAIN, 'testTag', 'Failed to load the content. Cause: %{public}s', JSON.stringify(err));
        return;
      }
      hilog.info(DOMAIN, 'testTag', 'Succeeded in loading the content.');
    });
  }

  private targetPageUrl(): string {
    return this.cardTargetPage === 'draw' ? PAGE_DRAW : PAGE_INDEX;
  }

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.parseCardParams(want);
    hilog.info(DOMAIN, 'testTag', '%{public}s', `Ability onCreate target=${this.cardTargetPage}`);
  }

  onDestroy(): void {
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onDestroy');
  }

  /** 应用已在后台时点卡片走这里：在现有 windowStage 上切换到目标页 */
  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.parseCardParams(want);
    hilog.info(DOMAIN, 'testTag', '%{public}s', `Ability onNewWant target=${this.cardTargetPage}`);
    if (this.currentWindowStage !== null) {
      this.loadTargetPage(this.currentWindowStage);
    }
  }

  onWindowStageCreate(windowStage: window.WindowStage): void {
    // Main window is created, set main page for this ability
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageCreate');

    this.currentWindowStage = windowStage;
    this.loadTargetPage(windowStage);

    try {
      this.context.getApplicationContext().setColorMode(ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);
    } catch (err) {
      hilog.error(DOMAIN, 'testTag', 'Failed to set colorMode. Cause: %{public}s', JSON.stringify(err));
    }
  }

  onWindowStageDestroy(): void {
    // Main window is destroyed, release UI related resources
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onWindowStageDestroy');
    this.currentWindowStage = null;
  }

  onForeground(): void {
    // Ability has brought to foreground
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onForeground');
  }

  onBackground(): void {
    // Ability has back to background
    hilog.info(DOMAIN, 'testTag', '%{public}s', 'Ability onBackground');
  }
}
