import { common } from '@kit.AbilityKit';
import { PreferencesStore } from '../store/PreferencesStore';
import { RandomUtil } from './RandomUtil';
import { HISTORY_LIMIT } from '../model/WheelModels';

/** 通用历史记录条目（转盘/抽签/硬币共用）。 */
export interface HistoryItem {
  id: string;
  module: string;
  title: string;
  time: number;
}

/**
 * 历史记录管理：按模块分 key 存储，超出上限淘汰最旧记录。
 */
export class HistoryManager {
  static load(context: common.UIAbilityContext, moduleName: string): HistoryItem[] {
    try {
      const raw = PreferencesStore.getString(context, HistoryManager.key(moduleName), '[]');
      const parsed = JSON.parse(raw) as HistoryItem[];
      if (Array.isArray(parsed)) {
        return parsed;
      }
    } catch (err) {
      // 解析失败回退空列表
    }
    return [];
  }

  /** 新增一条记录并持久化，返回新条目。 */
  static add(context: common.UIAbilityContext, moduleName: string, title: string): HistoryItem {
    const item: HistoryItem = {
      id: `${Date.now()}_${RandomUtil.randomInt(0, 999999)}`,
      module: moduleName,
      title: title,
      time: Date.now()
    };
    const list = HistoryManager.load(context, moduleName);
    list.unshift(item);
    PreferencesStore.putString(context, HistoryManager.key(moduleName), JSON.stringify(list.slice(0, HISTORY_LIMIT)));
    return item;
  }

  static clear(context: common.UIAbilityContext, moduleName: string): void {
    PreferencesStore.putString(context, HistoryManager.key(moduleName), '[]');
  }

  /** 时间戳格式化为 "M-D HH:mm"。 */
  static formatTime(time: number): string {
    const d = new Date(time);
    const pad = (n: number): string => n < 10 ? `0${n}` : `${n}`;
    return `${d.getMonth() + 1}-${d.getDate()} ${pad(d.getHours())}:${pad(d.getMinutes())}`;
  }

  private static key(moduleName: string): string {
    return `${moduleName}_history`;
  }
}
