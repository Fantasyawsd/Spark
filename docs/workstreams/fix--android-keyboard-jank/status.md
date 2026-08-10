# 任务台账

## 基本信息

- 任务：消除 Android 调起软键盘时的明显卡顿和掉帧
- 关联发布或里程碑：不关联发布；P0 单机可用与发布质量
- 分支：`fix/android-keyboard-jank`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\fix--android-keyboard-jank`
- 基线提交：`a768f0a4003c7f84a99fb7674c48202961f9d584`
- 负责人：Fantasy（编排者）；执行：Codex
- 状态：开发中
- 最近更新：2026-08-10 23:19

## 目标

让 Spark Android 客户端在输入框获取焦点、软键盘弹出或收起时保持流畅，避免昂贵内容区随每个 IME inset 帧重复构建；键盘出现时由 Android 将整个 Flutter 窗口作为静态画面统一上移，不再只移动或缩放局部面板。

## 非目标

- 不改变聊天消息、搜索或评论的业务契约和持久化结构。
- 不重新设计输入区、页面导航或主题视觉。
- 不启动 Android 模拟器；最终真机体感验收仍由编排者执行。

## 验收标准

- [x] 建立可重复的 IME inset 变化反馈环，能在修复前捕获面板追赶键盘与布局放大。
- [x] Android Activity 使用窗口级平移；Flutter 组件树不再消费 IME bottom inset 做局部移动或缩放。
- [x] 键盘过渡时评论面板与其背后的页面保持相对位置不变，由系统统一移动整个窗口画面。
- [x] 评论与 AI 输入、发送、键盘收起以及半屏/全屏交互不回归。
- [x] 相关 Widget 回归测试、格式检查与 `flutter analyze` 通过。
- [x] development debug APK 构建成功；Android 真机性能结论如实记录。

## 写入范围

### 独占路径

- `lib/src/features/papers/presentation/widgets/paper_comments_sheet.dart`
- `lib/src/app/spark_app.dart`
- `android/app/src/main/AndroidManifest.xml`
- `test/android_keyboard_window_config_test.dart`
- `test/paper_comments_keyboard_test.dart`
- `docs/workstreams/fix--android-keyboard-jank/status.md`

### 共享路径

- 无；如定位到跨模块根因，先在本台账收窄新增路径后再修改。

## 依赖关系

- 上游任务：ChatPaper 移动端 UI、Composer 工具栏与发送后收起键盘能力均已合入 `main`。
- 外部接口或数据源：Android IME / Flutter `MediaQuery.viewInsets`；当前无 Android 真机连接。

## 实施计划

1. 构造可重复的键盘 inset 变化 Widget 性能回归测试，记录修复前失败信号并最小化触发场景。
2. 对候选根因逐一做可证伪探针，确认重建或布局热点后实施最小展示层修复。
3. 回归输入、发送、键盘收起与窄屏/多行布局，运行格式、静态分析、定向测试和 development APK 构建。
4. 清理诊断代码，记录真实证据、剩余真机不确定性与回滚方式。

## 当前进度

- 已完成：必读文档、历史 ChatPaper 台账、基线与设备状态核对；建立实际评论面板的 IME 逐帧复现；第一轮移除二次动画后由编排者真机确认卡顿改善；第二轮根据反馈改为 Android 窗口级 `adjustPan`，Flutter Android 组件树不再消费 IME bottom inset；定向测试、格式、静态分析、401 项全量测试和 development APK 构建通过。
- 正在进行：本轮 `/develop` 实现与静态验证已完成，等待 Android 真机验收或编排者触发 `/test`。
- 下一步：由编排者安装新 APK，确认键盘出现时页面、遮罩和面板作为一个静态画面整体上移；之后按需触发 `/test`。
- 阻塞项：无；本机没有 Android 真机，因此设备级帧时间尚未采集，自动证据不能替代最终真机验收。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-10 | 以本地 `main@a768f0a` 为任务基线 | 本地 `main` 干净且包含 `origin/main` 尚未同步的最新规范归档提交 | 保持任务遵循当前仓库规范；不引入其他并行 worktree 改动 |
| 2026-08-10 | 使用实际评论/AI 面板注入 8 个 IME inset 帧作为反馈环 | 本机无 Android 真机；该路径可确定性复现键盘边界滞后和布局次数，并直接覆盖真实 Widget 树 | 最终仍需编排者在 Android 真机确认 UI/Raster 帧时间 |
| 2026-08-10 | 移除跟随 IME 的 180ms `AnimatedPadding` | Flutter 已逐帧更新 `viewInsets`；隐式补间会在每个新值到达时重新追赶，最小复现中最终位置比目标滞后约 259 logical px | 面板不再叠加第二段键盘动画 |
| 2026-08-10 | 半屏使用 `Transform.translate` + `RepaintBoundary`，全屏保留同步 `Padding` | 半屏是主要输入场景，平移可保持内容布局稳定；全屏若整体平移会把顶部栏推出屏幕 | 半屏 8 帧布局事件由 504 降至 336（约 33%）；全屏顶部边缘保持固定 |
| 2026-08-10 | 根据真机反馈改为 Android 窗口级 `adjustPan` | 第一轮已解决卡顿，但只移动面板；产品预期是页面、遮罩和面板作为同一静态画面统一上移 | Android 跳过面板级 inset follower，并在应用根部阻止 Flutter 组件消费 Android IME bottom inset，避免二次位移；其他平台保留原有避让 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `D:\App\flutter\bin\flutter.bat --version` | Flutter 3.44.8 / Dart 3.12.2 | 2026-08-10 |
| `D:\App\flutter\bin\flutter.bat devices`、`adb devices -l` | 仅 Windows/Web；无 Android 真机或模拟器连接 | 2026-08-10 |
| `flutter test test\_keyboard_jank_probe_test.dart --reporter expanded`（临时最小复现，修复前） | 失败（预期红灯）；320 logical px 键盘过渡后半屏面板顶部仅到 `y=344.08`，目标为 `y=85`；8 帧产生 504 次布局 | 2026-08-10 |
| `flutter test test\paper_comments_keyboard_test.dart --reporter expanded` | 通过；半屏逐帧贴合且保持高度，布局事件不超过 400；全屏保持顶部边缘 | 2026-08-10 |
| `flutter test test\paper_comments_keyboard_test.dart test\ui_preview_test.dart test\paper_ai_mobile_chat_ui_test.dart test\paper_ai_composer_test.dart` | 通过；44 项评论、AI 输入与 ChatPaper 定向回归 | 2026-08-10 |
| `flutter analyze` | 通过；No issues found | 2026-08-10 |
| `.\tool\verify_changed_dart_format.ps1` | 通过；2 个变更 Dart 文件格式正确 | 2026-08-10 |
| `flutter test` | 通过；397 项全量测试 | 2026-08-10 |
| `flutter build apk --debug --flavor development --dart-define=SPARK_ENV=development` | 通过；`build/app/outputs/flutter-apk/app-development-debug.apk`，164,784,217 字节（157.15 MiB），SHA-256 `8F61BFE538FAA91F2C0AF96FBC7CC6D300B87BF841C987C245433C7D622F508E` | 2026-08-10 |
| `git diff --check` | 通过 | 2026-08-10 |
| `flutter test test\android_keyboard_window_config_test.dart test\paper_comments_keyboard_test.dart --reporter expanded`（第二轮修复前） | 失败（预期红灯）；清单仍为 `adjustResize`，Android 根组件仍收到 320 logical px inset，半屏面板单独上移 320 px、全屏面板单独缩短 320 px | 2026-08-10 |
| 同上（第二轮修复后） | 通过；Activity 配置为 `adjustPan`，Android 根组件收到的 IME bottom inset 为 0，半屏/全屏评论面板在 Flutter 坐标中保持静态；iOS 分支仍保留 inset 避让 | 2026-08-10 |
| `flutter test test\android_keyboard_window_config_test.dart test\paper_comments_keyboard_test.dart test\ui_preview_test.dart test\paper_ai_mobile_chat_ui_test.dart test\paper_ai_composer_test.dart test\deepseek_settings_widget_test.dart test\tiktok_app_shell_test.dart test\widget_test.dart --reporter expanded` | 通过；55 项应用壳、评论、ChatPaper、输入和设置定向回归 | 2026-08-10 |
| `.\tool\verify_changed_dart_format.ps1`（第二轮） | 通过；4 个变更 Dart 文件格式正确 | 2026-08-10 |
| `flutter analyze`（第二轮） | 通过；No issues found | 2026-08-10 |
| `flutter test`（第二轮） | 通过；401 项全量测试 | 2026-08-10 |
| `flutter build apk --debug --flavor development --dart-define=SPARK_ENV=development`（第二轮） | 通过；`build/app/outputs/flutter-apk/app-development-debug.apk`，193,261,916 字节（184.31 MiB），SHA-256 `7AFE8C85ECBFD65A713529953BA9594A12AAE18A8BA9A729896CE0BADAEECC9F` | 2026-08-10 |
| 检查 Gradle merged/packaged manifest | 通过；developmentDebug 最终清单均包含 `android:windowSoftInputMode="adjustPan"` | 2026-08-10 |
| `git diff --check`（第二轮） | 通过 | 2026-08-10 |

## 审查结论

- 审查日期：待 `/review`
- 阻断项：待审查
- 缺陷：待审查
- 结论：需重新审查

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `e1b091f` | `修复（论文）：消除键盘弹出时的面板卡顿` | 根因修复、回归测试与合并前台账 | IME 红/绿反馈环、44 项定向测试、397 项全量测试、analyze、格式门禁与 development APK 构建通过 |
| `cd702b1` | `修复（键盘）：改为 Android 整屏静态上移` | 真机反馈迭代、窗口级平移与回归测试 | 窗口配置与静态布局红/绿反馈环、55 项定向测试、401 项全量测试、analyze、格式门禁、最终清单核对与 development APK 构建通过 |

## 交付准备（合并前收集）

### 交付摘要

Android 的评论/AI 面板不再为系统键盘的每个 inset 帧重启一段内部动画。根据真机反馈，最终交互改为窗口级平移：键盘出现时页面、遮罩和面板保持同一静态布局，由系统统一移动整个 Flutter 窗口；Flutter 内不再进行 Android IME 的局部 resize 或二次位移。

### 实际变更

- 领域与业务逻辑：无计划变更。
- 数据与基础设施：无计划变更。
- 界面与交互：Android Activity 从 `adjustResize` 改为 `adjustPan`；应用根部仅在 Android 移除传向组件树的 IME bottom inset；评论面板在 Android 跳过局部 follower，其他平台保留原有避让。
- 测试与工具：新增最终 Android 清单配置、应用根部静态布局、半屏/全屏评论面板静态几何和非 Android 兼容回归；保留输入焦点与布局次数约束。
- 文档：本任务台账。

### 兼容性与迁移

- 本地数据迁移：无。
- API 或领域契约变化：无。
- 旧版本兼容性：仅展示层性能修复，无持久化影响。

### 已知风险与回滚

- 已知风险：当前无 Android 真机，自动测试能够锁定 Flutter 内部不再二次位移，且最终 APK 清单为 `adjustPan`，但不能模拟 Android 系统实际选取的窗口平移距离，也不能直接证明具体设备的 UI/Raster 帧均低于刷新预算。
- 回滚方式：在合入后 revert 本任务修复提交；不涉及数据迁移或 API 兼容。

### 文档更新建议

- 性能缺陷修复不改变 `docs/development.md` 的能力状态；合并归档时记录为不适用。

### 未完成与后续工作

- Android 真机安装后先确认页面、遮罩和面板统一上移且输入框不被遮挡，再使用系统 Profile GPU Rendering 或 Flutter DevTools Performance 复核键盘弹出与收起帧时间。

## 合并归档（合并后在 main 补齐）

- 最终状态：待合并
- 合入分支：`main`
- 最终集成提交：待合并后填写
- Pull Request：无
- 合并时间：待合并后填写
- main 集成验证：待合并后填写
- 开发计划更新：待合并后填写
- 最终后续项：待合并后填写
