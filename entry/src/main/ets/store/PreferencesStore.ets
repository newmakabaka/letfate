import { preferences } from '@kit.ArkData';
import { common } from '@kit.AbilityKit';

const STORE_NAME = 'letfate_store';

/**
 * Preferences 持久化封装：同步读写 + 异步落盘，存储异常不阻塞 UI。
 */
export class PreferencesStore {
  private static instance: preferences.Preferences | undefined = undefined;

  private static getStore(context: common.UIAbilityContext): preferences.Preferences {
    if (!PreferencesStore.instance) {
      PreferencesStore.instance = preferences.getPreferencesSync(context, { name: STORE_NAME });
    }
    return PreferencesStore.instance;
  }

  static getString(context: common.UIAbilityContext, key: string, defaultValue: string): string {
    try {
      return PreferencesStore.getStore(context).getSync(key, defaultValue) as string;
    } catch (err) {
      // 读取失败回退默认值
      return defaultValue;
    }
  }

  static putString(context: common.UIAbilityContext, key: string, value: string): void {
    try {
      const store = PreferencesStore.getStore(context);
      store.putSync(key, value);
      store.flush().catch(() => {});
    } catch (err) {
      // 写入失败不阻塞 UI
    }
  }

  static getNumber(context: common.UIAbilityContext, key: string, defaultValue: number): number {
    try {
      return PreferencesStore.getStore(context).getSync(key, defaultValue) as number;
    } catch (err) {
      return defaultValue;
    }
  }

  static putNumber(context: common.UIAbilityContext, key: string, value: number): void {
    try {
      const store = PreferencesStore.getStore(context);
      store.putSync(key, value);
      store.flush().catch(() => {});
    } catch (err) {
      // 写入失败不阻塞 UI
    }
  }
}
