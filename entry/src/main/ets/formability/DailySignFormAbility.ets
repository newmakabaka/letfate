import { formBindingData, FormExtensionAbility, formProvider } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { preferences } from '@kit.ArkData';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { SignEngine } from '../logic/SignEngine';
import { SIGN_LEVELS } from '../model/SignModels';

const DOMAIN = 0x0000;
const TAG = 'DailySignFormAbility';
/** 卡片进程独立 Preferences（与主进程 letfate_store 隔离，互不读写） */
const STORE_NAME = 'daily_sign_store';
const KEY_DATE = 'sign_date';
const KEY_LEVEL = 'sign_level';
const KEY_TITLE = 'sign_title';

/** 当天日期键（仅用于同日判定） */
function todayKey(): string {
  const d = new Date();
  return `${d.getFullYear()}-${d.getMonth() + 1}-${d.getDate()}`;
}

/**
 * 「每日一签」2×2 卡片提供方。
 * 复用 logic 层 SignEngine（纯函数）抽签；卡片数据按日期键持久化：
 * 同一自然日内所有刷新返回同一支签，跨天首个刷新时点换签。
 * 卡片抽签不写入求签历史（不调用 HistoryManager）。
 */
export default class DailySignFormAbility extends FormExtensionAbility {
  onAddForm(want: Want): formBindingData.FormBindingData {
    hilog.info(DOMAIN, TAG, 'onAddForm');
    return formBindingData.createFormBindingData(this.resolveDailySign());
  }

  onUpdateForm(formId: string): void {
    hilog.info(DOMAIN, TAG, `onUpdateForm formId=${formId}`);
    const data = formBindingData.createFormBindingData(this.resolveDailySign());
    formProvider.updateForm(formId, data).catch((err: BusinessError) => {
      hilog.error(DOMAIN, TAG, `updateForm failed code=${err.code} msg=${err.message}`);
    });
  }

  onRemoveForm(formId: string): void {
    // 卡片数据为全局日期键（同日所有卡片实例共用一支签），无按 formId 持久化的数据
    hilog.info(DOMAIN, TAG, `onRemoveForm formId=${formId}`);
  }

  /** 日期键判定：今天已抽则复用，否则抽新签并持久化；存储异常退化为不持久化的随机签。 */
  private resolveDailySign(): Record<string, string> {
    const today = todayKey();
    try {
      const store = preferences.getPreferencesSync(this.context, { name: STORE_NAME });
      const savedDate = store.getSync(KEY_DATE, '') as string;
      const savedTitle = store.getSync(KEY_TITLE, '') as string;
      if (savedDate === today && savedTitle.length > 0) {
        const savedLevel = store.getSync(KEY_LEVEL, 2) as number;
        return this.toCardData(savedLevel, savedTitle);
      }
      const sign = SignEngine.drawSign();
      store.putSync(KEY_DATE, today);
      store.putSync(KEY_LEVEL, sign.levelIndex);
      store.putSync(KEY_TITLE, sign.title);
      store.flush().catch(() => {});
      return this.toCardData(sign.levelIndex, sign.title);
    } catch (err) {
      hilog.error(DOMAIN, TAG, 'daily sign store error, fallback to random');
      const sign = SignEngine.drawSign();
      return this.toCardData(sign.levelIndex, sign.title);
    }
  }

  private toCardData(levelIndex: number, title: string): Record<string, string> {
    const safeIndex = levelIndex >= 0 && levelIndex < SIGN_LEVELS.length ? levelIndex : 2;
    const data: Record<string, string> = {
      'levelName': SIGN_LEVELS[safeIndex],
      'signTitle': title
    };
    return data;
  }
}
