# 随缘选 隐私说明

更新日期：2026-10-19
适用版本：1.1.0

「随缘选」（LetFate）是一款运行在 HarmonyOS 上的本地随机决策小工具，包含幸运转盘、求签、抛硬币三个功能。本说明如实描述应用对用户信息的处理方式。

## 一、我们不收集任何信息

- 「随缘选」不需要注册或登录任何账号，不连接网络，也不收集、上传或共享任何个人信息。
- 应用无任何用户画像、行为分析或崩溃上报。

## 二、权限

应用不声明任何权限（工程 `entry/src/main/module.json5` 中无 `requestPermissions` 声明）：

- 不使用网络权限，无任何联网行为；
- 不使用相机、麦克风、位置、通讯录、日历等敏感权限；
- 不读取设备媒体文件与共享存储。

## 三、本地数据存储

以下内容由你主动产生，仅通过系统 Preferences（应用沙箱内的 `letfate_store` 文件）写入当前设备，不会离开设备：

- 转盘选项（你自定义的选项内容）；
- 币面自定义文案（正面/反面文字）；
- 转动历史、求签历史、抛币历史（各保留最近 100 条）；
- 抛币累计统计（总次数、正面次数、反面次数）；
- 「每日一签」桌面卡片（V1.1 新增）：卡片展示的当日一签由本地随机生成，仅在应用沙箱内单独的 `daily_sign_store` 文件中记录日期、签级与签题，用于保证同一天卡面不变。卡片抽签不写入求签历史，与主应用数据相互隔离。

应用不读取、不监听系统剪贴板（当前版本也没有复制结果功能），不读取任何应用之外的数据。

## 四、系统备份

应用启用了系统备份扩展（HarmonyOS 工程默认模板行为，`allowToBackupRestore: true`）：当你在系统设置中主动发起"备份与恢复"或换机迁移时，上述本地数据可能随系统备份被保存或迁移到新设备。该过程由系统完成，应用自身不做任何网络传输。

## 五、数据的清除

- 幸运转盘、求签、抛硬币三个页面均可分别一键清空对应的历史记录；
- 抛币统计支持一键清零；
- 转盘选项与币面文案可随时编辑修改；
- 卸载应用会删除应用沙箱中的全部本地数据。

## 六、第三方组件

- 运行时零第三方依赖：不包含广告 SDK、统计 SDK、WebView 或跨端运行时；
- 开发阶段使用的 `@ohos/hypium`、`@ohos/hamock` 仅为本地单元测试框架（devDependencies），不随应用发布。

---

### 核实方式

以上声明可对照工程源码核实：权限声明见 `entry/src/main/module.json5`；依赖见 `oh-package.json5` / `entry/oh-package.json5`；全部本地存储读写集中在 `entry/src/main/ets/store/PreferencesStore.ets`（Preferences 名称 `letfate_store`）、`entry/src/main/ets/formability/DailySignFormAbility.ets`（卡片 Preferences 名称 `daily_sign_store`）与 `entry/src/main/ets/logic/HistoryManager.ets`。
