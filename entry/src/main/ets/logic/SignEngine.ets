import { RandomUtil } from './RandomUtil';
import { Sign, SIGN_LEVEL_WEIGHTS } from '../model/SignModels';
import { SIGN_LIBRARY } from '../model/SignLibrary';

/**
 * 抽签引擎：先按签级经验概率定级，再在同级签池中等概率抽一支（结果先行）。
 * 签级概率：上上 10% / 上 25% / 中 35% / 中平 20% / 下 10%。
 */
export class SignEngine {
  static drawSign(): Sign {
    const levelIndex = RandomUtil.weightedPickIndex(SIGN_LEVEL_WEIGHTS);
    const pool: Sign[] = [];
    for (let i = 0; i < SIGN_LIBRARY.length; i++) {
      if (SIGN_LIBRARY[i].levelIndex === levelIndex) {
        pool.push(SIGN_LIBRARY[i]);
      }
    }
    return RandomUtil.pick(pool);
  }
}
