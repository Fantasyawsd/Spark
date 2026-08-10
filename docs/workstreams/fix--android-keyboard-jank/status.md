# 任务台账

## 基本信息

- 任务：消除 Android 调起软键盘时的明显卡顿和掉帧
- 关联发布或里程碑：不关联发布；P0 单机可用与发布质量
- 分支：`fix/android-keyboard-jank`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\fix--android-keyboard-jank`
- 基线提交：`a768f0a4003c7f84a99fb7674c48202961f9d584`
- 负责人：Fantasy（编排者）；执行：Codex
- 状态：开发中
- 最近更新：2026-08-10 22:52

## 目标

让 Spark Android 客户端在输入框获取焦点、软键盘弹出或收起时保持流畅，避免昂贵内容区随每个 IME inset 帧重复构建，同时保持现有输入、发送和键盘贴合行为不变。

## 非目标

- 不改变聊天消息、搜索或评论的业务契约和持久化结构。
- 不重新设计输入区、页面导航或主题视觉。
- 不启动 Android 模拟器；最终真机体感验收仍由编排者执行。

## 验收标准

- [x] 建立可重复的 IME inset 变化反馈环，能在修复前捕获面板追赶键盘与布局放大。
- [x] 半屏键盘过渡只平移缓存后的面板图层，不再逐帧重排 Markdown/评论内容；全屏态同步 resize 并保持顶部栏可见。
- [x] 评论与 AI 输入、发送、键盘收起以及半屏/全屏交互不回归。
- [x] 相关 Widget 回归测试、格式检查与 `flutter analyze` 通过。
- [x] development debug APK 构建成功；Android 真机性能结论如实记录。

## 写入范围

### 独占路径

- `lib/src/features/papers/presentation/widgets/paper_comments_sheet.dart`
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

- 已完成：必读文档、历史 ChatPaper 台账、基线与设备状态核对；建立实际评论面板的 IME 逐帧复现；确认二次 `AnimatedPadding` 是几何滞后根因；实现半屏图层平移与全屏同步 resize；新增回归测试；格式、定向测试、静态分析、全量测试和 Android development APK 构建通过。
- 正在进行：本轮 `/develop` 最小闭环已提交，等待 Android 真机验收或编排者触发 `/test`。
- 下一步：由编排者在 Android 真机安装 APK，复核键盘弹出/收起的 UI/Raster 帧时间与体感；之后按需触发 `/test`。
- 阻塞项：无；本机没有 Android 真机，因此设备级帧时间尚未采集，自动证据不能替代最终真机验收。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-10 | 以本地 `main@a768f0a` 为任务基线 | 本地 `main` 干净且包含 `origin/main` 尚未同步的最新规范归档提交 | 保持任务遵循当前仓库规范；不引入其他并行 worktree 改动 |
| 2026-08-10 | 使用实际评论/AI 面板注入 8 个 IME inset 帧作为反馈环 | 本机无 Android 真机；该路径可确定性复现键盘边界滞后和布局次数，并直接覆盖真实 Widget 树 | 最终仍需编排者在 Android 真机确认 UI/Raster 帧时间 |
| 2026-08-10 | 移除跟随 IME 的 180ms `AnimatedPadding` | Flutter 已逐帧更新 `viewInsets`；隐式补间会在每个新值到达时重新追赶，最小复现中最终位置比目标滞后约 259 logical px | 面板不再叠加第二段键盘动画 |
| 2026-08-10 | 半屏使用 `Transform.translate` + `RepaintBoundary`，全屏保留同步 `Padding` | 半屏是主要输入场景，平移可保持内容布局稳定；全屏若整体平移会把顶部栏推出屏幕 | 半屏 8 帧布局事件由 504 降至 336（约 33%）；全屏顶部边缘保持固定 |

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

## 审查结论

- 审查日期：待 `/review`
- 阻断项：待审查
- 缺陷：待审查
- 结论：需重新审查

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `e1b091f` | `修复（论文）：消除键盘弹出时的面板卡顿` | 根因修复、回归测试与合并前台账 | IME 红/绿反馈环、44 项定向测试、397 项全量测试、analyze、格式门禁与 development APK 构建通过 |

## 交付准备（合并前收集）

### 交付摘要

Android 的评论/AI 半屏面板不再为系统键盘的每个 inset 帧重启一段 180ms 内部动画。面板现在与键盘逐帧同步，并把半屏过渡限制为缓存图层平移；全屏态保持顶部栏固定并同步缩小可用高度。

### 实际变更

- 领域与业务逻辑：无计划变更。
- 数据与基础设施：无计划变更。
- 界面与交互：新增 `_KeyboardInsetFollower`；半屏使用可命中测试的图层平移，全屏使用同步底部 padding，移除二次隐式补间。
- 测试与工具：新增真实评论面板的半屏/全屏 IME 逐帧测试，覆盖焦点、几何贴合、布局上限和顶部栏稳定性。
- 文档：本任务台账。

### 兼容性与迁移

- 本地数据迁移：无。
- API 或领域契约变化：无。
- 旧版本兼容性：仅展示层性能修复，无持久化影响。

### 已知风险与回滚

- 已知风险：当前无 Android 真机，自动测试能够锁定 inset 几何和布局放大器，但不能直接证明具体设备的 UI/Raster 帧均低于刷新预算。
- 回滚方式：在合入后 revert 本任务修复提交；不涉及数据迁移或 API 兼容。

### 文档更新建议

- 性能缺陷修复不改变 `docs/development.md` 的能力状态；合并归档时记录为不适用。

### 未完成与后续工作

- Android 真机安装后使用系统 Profile GPU Rendering 或 Flutter DevTools Performance 复核键盘弹出与收起帧时间。

## 合并归档（合并后在 main 补齐）

- 最终状态：待合并
- 合入分支：`main`
- 最终集成提交：待合并后填写
- Pull Request：无
- 合并时间：待合并后填写
- main 集成验证：待合并后填写
- 开发计划更新：待合并后填写
- 最终后续项：待合并后填写
