import { describe, it, expect } from '@ohos/hypium';
import { RandomUtil } from '../main/ets/logic/RandomUtil';
import { WheelEngine } from '../main/ets/logic/WheelEngine';
import { SignEngine } from '../main/ets/logic/SignEngine';
import { CoinEngine } from '../main/ets/logic/CoinEngine';
import { buildCoinShareText, buildSignShareText, buildWheelShareText } from '../main/ets/logic/ShareUtil';
import { decodeOptions, encodeOptions } from '../main/ets/logic/WheelQr';
import { SIGN_LEVELS, SIGN_LEVEL_WEIGHTS } from '../main/ets/model/SignModels';
import { SIGN_LIBRARY } from '../main/ets/model/SignLibrary';

export default function localUnitTest() {
  describe('randomUtilTest', () => {
    it('randomInt_withinBoundsInclusive', 0, () => {
      let sawMin = false;
      let sawMax = false;
      for (let i = 0; i < 2000; i++) {
        const v = RandomUtil.randomInt(2, 5);
        if (v === 2) {
          sawMin = true;
        }
        if (v === 5) {
          sawMax = true;
        }
      }
      expect(sawMin).assertTrue();
      expect(sawMax).assertTrue();
    });

    it('randomInt_singlePoint', 0, () => {
      expect(RandomUtil.randomInt(0, 0)).assertEqual(0);
      expect(RandomUtil.randomInt(7, 7)).assertEqual(7);
    });

    it('randomFloat_withinBounds', 0, () => {
      for (let i = 0; i < 1000; i++) {
        const v = RandomUtil.randomFloat(-0.5, 0.5);
        expect(v >= -0.5 && v < 0.5).assertTrue();
      }
    });

    it('pick_emptyArrayThrows', 0, () => {
      let threw = false;
      try {
        RandomUtil.pick<number>([]);
      } catch (err) {
        threw = true;
      }
      expect(threw).assertTrue();
    });
  });

  describe('wheelEngineTest', () => {
    it('segmentAngle', 0, () => {
      expect(WheelEngine.segmentAngle(6)).assertEqual(60);
      expect(WheelEngine.segmentAngle(12)).assertEqual(30);
      expect(WheelEngine.segmentAngle(2)).assertEqual(180);
    });

    it('rotationResultRoundTrip', 0, () => {
      // 任意扇区数与起始角度下，先算结果再反推的旋转角必须停在结果扇区
      for (let n = 2; n <= 12; n++) {
        for (let i = 0; i < n; i++) {
          const current = 1000 + i * 37;
          const target = WheelEngine.computeTargetRotation(current, i, n);
          expect(target).assertLarger(current);
          expect(WheelEngine.deriveIndexFromRotation(target, n)).assertEqual(i);
        }
      }
    });

    it('pickResultIndex_inRange', 0, () => {
      for (let k = 0; k < 500; k++) {
        const idx = WheelEngine.pickResultIndex(7);
        expect(idx).assertLargerOrEqual(0);
        expect(idx).assertLess(7);
      }
    });

    it('sanitizeOptions_trimsDedupesCaps', 0, () => {
      const out = WheelEngine.sanitizeOptions([' 火锅 ', '', '烧烤', '烧烤', '  ']);
      expect(out.length).assertEqual(2);
      expect(out[0]).assertEqual('火锅');
      expect(out[1]).assertEqual('烧烤');

      const many: string[] = [];
      for (let i = 0; i < 20; i++) {
        many.push(`选项${i}`);
      }
      expect(WheelEngine.sanitizeOptions(many).length).assertEqual(WheelEngine.MAX_OPTIONS);
    });
  });

  describe('signEngineTest', () => {
    it('weightedPickIndex_inRangeAndDeterministicEdges', 0, () => {
      // 正常权重：下标始终落在 [0, 4]
      for (let k = 0; k < 500; k++) {
        const idx = RandomUtil.weightedPickIndex(SIGN_LEVEL_WEIGHTS);
        expect(idx).assertLargerOrEqual(0);
        expect(idx).assertLess(SIGN_LEVEL_WEIGHTS.length);
      }
      // 单一非零权重：必中该下标
      expect(RandomUtil.weightedPickIndex([0, 0, 5, 0])).assertEqual(2);
      // 全零与空数组必须抛异常
      let threwZero = false;
      try {
        RandomUtil.weightedPickIndex([0, 0]);
      } catch (err) {
        threwZero = true;
      }
      expect(threwZero).assertTrue();
      let threwEmpty = false;
      try {
        RandomUtil.weightedPickIndex([]);
      } catch (err) {
        threwEmpty = true;
      }
      expect(threwEmpty).assertTrue();
    });

    it('signLibrary_structureValid', 0, () => {
      // 5 级 × 每级 4~6 支，总数 25 左右
      expect(SIGN_LEVELS.length).assertEqual(5);
      expect(SIGN_LEVEL_WEIGHTS.length).assertEqual(5);
      expect(SIGN_LIBRARY.length).assertEqual(25);
      for (let level = 0; level < 5; level++) {
        let count = 0;
        for (let i = 0; i < SIGN_LIBRARY.length; i++) {
          const sign = SIGN_LIBRARY[i];
          expect(sign.levelIndex).assertLargerOrEqual(0);
          expect(sign.levelIndex).assertLess(5);
          expect(sign.poem.length).assertEqual(4);
          expect(sign.title.length > 0).assertTrue();
          expect(sign.interpret.length > 0).assertTrue();
          if (sign.levelIndex === level) {
            count++;
          }
        }
        expect(count >= 4 && count <= 6).assertTrue();
      }
    });

    it('signEngine_drawAlwaysValidAndAllLevelsReachable', 0, () => {
      const seen = new Set<number>();
      for (let k = 0; k < 800; k++) {
        const sign = SignEngine.drawSign();
        expect(sign.levelIndex).assertLargerOrEqual(0);
        expect(sign.levelIndex).assertLess(5);
        expect(sign.poem.length).assertEqual(4);
        seen.add(sign.levelIndex);
      }
      // 800 次抽取下 5 个签级全部出现（最小权重 10%，期望出现 80 次）
      expect(seen.size).assertEqual(5);
    });
  });

  describe('coinEngineTest', () => {
    it('flip_inRangeAndBothFacesAppear', 0, () => {
      let heads = false;
      let tails = false;
      for (let i = 0; i < 500; i++) {
        const f = CoinEngine.flip();
        expect(f === CoinEngine.FACE_HEAD || f === CoinEngine.FACE_TAIL).assertTrue();
        if (f === CoinEngine.FACE_HEAD) {
          heads = true;
        } else {
          tails = true;
        }
      }
      expect(heads).assertTrue();
      expect(tails).assertTrue();
    });

    it('flipMany_count', 0, () => {
      expect(CoinEngine.flipMany(1).length).assertEqual(1);
      expect(CoinEngine.flipMany(3).length).assertEqual(3);
      expect(CoinEngine.flipMany(5).length).assertEqual(5);
      expect(CoinEngine.flipMany(0).length).assertEqual(0);
    });

    it('computeTargetRotation_landsOnRequestedFace', 0, () => {
      // 任意 90° 整数倍起始角下：结果先行反推的目标角必停在请求面，且为整段 90°
      for (let start = 0; start <= 720; start += 90) {
        for (let result = 0; result <= 1; result++) {
          const target = CoinEngine.computeTargetRotation(start, result);
          expect(target).assertLarger(start);
          const mod = ((target % 360) + 360) % 360;
          if (result === CoinEngine.FACE_HEAD) {
            expect(mod).assertEqual(0);
          } else {
            expect(mod).assertEqual(180);
          }
          expect((target - start) % 90).assertEqual(0);
        }
      }
    });

    it('faceStateAt_matchesQuadrantTable', 0, () => {
      // 静止定格：0° 正面正立；180° 反面需预镜像抵消容器的上下翻转
      expect(CoinEngine.faceStateAt(0).face).assertEqual(CoinEngine.FACE_HEAD);
      expect(CoinEngine.faceStateAt(0).mirrored).assertFalse();
      expect(CoinEngine.faceStateAt(180).face).assertEqual(CoinEngine.FACE_TAIL);
      expect(CoinEngine.faceStateAt(180).mirrored).assertTrue();
      expect(CoinEngine.faceStateAt(360).face).assertEqual(CoinEngine.FACE_HEAD);
      expect(CoinEngine.faceStateAt(540).face).assertEqual(CoinEngine.FACE_TAIL);
      // 运动段：任意 90° 段起始角的币面/镜像与象限表一致
      const expectFace = [CoinEngine.FACE_HEAD, CoinEngine.FACE_TAIL, CoinEngine.FACE_TAIL, CoinEngine.FACE_HEAD];
      const expectMirror = [false, true, true, false];
      for (let k = 0; k < 16; k++) {
        const idx = k % 4;
        expect(CoinEngine.faceStateAt(k * 90).face).assertEqual(expectFace[idx]);
        expect(CoinEngine.faceStateAt(k * 90).mirrored).assertEqual(expectMirror[idx]);
      }
    });
  });

  describe('shareUtilTest', () => {
    it('buildSignShareText_containsLevelTitlePoem', 0, () => {
      const text = buildSignShareText('上签', '心想事成', ['春色满园', '万事亨通']);
      expect(text.includes('上签')).assertTrue();
      expect(text.includes('心想事成')).assertTrue();
      expect(text.includes('春色满园\n万事亨通')).assertTrue();
      expect(text.includes('随缘选')).assertTrue();
    });

    it('buildWheelShareText_containsResult', 0, () => {
      const text = buildWheelShareText('火锅');
      expect(text.includes('火锅')).assertTrue();
      expect(text.includes('随缘选')).assertTrue();
    });

    it('buildCoinShareText_singleAndMulti', 0, () => {
      expect(buildCoinShareText(['正面'])).assertEqual('「随缘选」硬币：正面');
      expect(buildCoinShareText(['正面', '反面', '正面']))
        .assertEqual('「随缘选」硬币连抛 3 次：正面 · 反面 · 正面');
    });
  });

  describe('wheelQrTest', () => {
    it('encodeDecodeRoundTrip', 0, () => {
      const out = decodeOptions(encodeOptions(['火锅', '烧烤', '面条']));
      expect(out === null).assertFalse();
      if (out !== null) {
        expect(out.join('|')).assertEqual('火锅|烧烤|面条');
      }
    });

    it('decode_rejectsInvalidPayloads', 0, () => {
      expect(decodeOptions('not json')).assertNull();
      expect(decodeOptions('{"v":2,"o":["a","b"]}')).assertNull();
      expect(decodeOptions('{"v":1,"o":"abc"}')).assertNull();
      expect(decodeOptions('{"v":1,"o":["a"]}')).assertNull();
      expect(decodeOptions('{"v":1,"o":["a","b",12]}')).assertNull();
    });

    it('decode_trimsAndDropsEmpty_keepsDuplicates', 0, () => {
      const out = decodeOptions('{"v":1,"o":[" 火锅 ","","烧烤","火锅"]}');
      expect(out === null).assertFalse();
      if (out !== null) {
        expect(out.join('|')).assertEqual('火锅|烧烤|火锅');
      }
    });

    it('decode_rejectsOverMax', 0, () => {
      const many: string[] = [];
      for (let i = 0; i < 13; i++) {
        many.push(`选项${i}`);
      }
      expect(decodeOptions(encodeOptions(many))).assertNull();
    });
  });
}
