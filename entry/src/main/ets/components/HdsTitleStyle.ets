import { hdsMaterial, TitleBarStyleOptions } from '@kit.UIDesignKit';

/**
 * 三功能页共用的标题栏材质：沉浸光感，全部交给系统自适应
 * （materialType ADAPTIVE 跟随系统材质策略；materialLevel ADAPTIVE 按设备算力自动降级）。
 * 见 docs/letfate/LetFate_V1.1_Plan.md 第 11 节（F6）。
 */
export const HDS_TITLE_MATERIAL: TitleBarStyleOptions = {
  systemMaterialEffect: {
    materialType: hdsMaterial.MaterialType.ADAPTIVE,
    materialLevel: hdsMaterial.MaterialLevel.ADAPTIVE
  }
};
