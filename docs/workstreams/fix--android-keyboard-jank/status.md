# 任务台账

## 基本信息

- 任务：消除 Android 调起软键盘时的明显卡顿和掉帧
- 关联发布或里程碑：不关联发布；P0 单机可用与发布质量
- 分支：`fix/android-keyboard-jank`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\fix--android-keyboard-jank`
- 基线提交：`a768f0a4003c7f84a99fb7674c48202961f9d584`
- 负责人：Fantasy（编排者）；执行：Codex
- 状态：开发中
- 最近更新：2026-08-11 00:29

## 目标

让 Spark Android 客户端在输入框获取焦点、软键盘弹出或收起时保持流畅，避免昂贵的富文本对话树随每个 IME inset 帧重复变换或布局；键盘出现时固定对话页顶栏和消息视口，输入栏单独跟随键盘，长对话内容按 IME 高度差值增量滚动以保持底部锚定。

## 非目标

- 不改变聊天消息、搜索或评论的业务契约和持久化结构。
- 不重新设计输入区、页面导航或主题视觉。
- 不启动 Android 模拟器；最终真机体感验收仍由编排者执行。

## 验收标准

- [x] 建立可重复的 IME inset 变化反馈环，能在修复前捕获面板追赶键盘与布局放大。
- [x] Android Activity 不做原生 resize/pan；对话页仅用输入栏的独立合成层消费 IME inset。
- [x] 键盘过渡时顶栏与消息视口坐标不变，输入栏逐帧贴合键盘；长对话的滚动范围和偏移按 inset 差值同步更新。
- [x] 评论与 AI 输入、发送、键盘收起以及半屏/全屏交互不回归。
- [x] 相关 Widget 回归测试、格式检查与 `flutter analyze` 通过。
- [x] development debug APK 构建成功；Android 真机性能结论如实记录。

## 写入范围

### 独占路径

- `lib/src/features/papers/presentation/widgets/paper_comments_sheet.dart`
- `lib/src/app/spark_app.dart`
- `lib/src/features/chat/presentation/paper_ai_chat_screen.dart`
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
5. 根据第二、三次真机反馈，以真实对话页“顶栏固定、消息列表与输入框等距上移”为红灯信号，改用对话页 body 统一平移并重新构建 APK。
6. 根据第四次真机反馈参考 RikkaHub 的顶栏、LazyList 与输入栏分层方案，以“消息视口不变换、输入栏独立位移、消息增量滚动”替代整个 chat body 平移。

## 当前进度

- 已完成：必读文档、历史 ChatPaper 台账、基线与设备状态核对；前三轮依据真机反馈已消除二次动画、原生窗口避让和顶栏误位移。第四轮针对仍有轻微掉帧，对照 RikkaHub 源码改为固定顶栏与消息视口、输入栏独立合成层跟随 IME、长对话按 inset 差值增量滚动。8 帧布局事件为 328，不超过 360 上限；25 项定向测试、格式、静态分析、402 项全量测试和 development APK 构建通过。
- 正在进行：本轮 `/develop` 实现与静态验证已完成，等待 Android 真机验收或编排者触发 `/test`。
- 下一步：由编排者安装新 APK，确认顶栏固定，输入栏跟手贴合键盘，长对话内容同步上滚且体感流畅；之后按需触发 `/test`。
- 阻塞项：无；本机没有 Android 真机，因此设备级帧时间尚未采集，自动证据不能替代最终真机验收。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-10 | 以本地 `main@a768f0a` 为任务基线 | 本地 `main` 干净且包含 `origin/main` 尚未同步的最新规范归档提交 | 保持任务遵循当前仓库规范；不引入其他并行 worktree 改动 |
| 2026-08-10 | 使用实际评论/AI 面板注入 8 个 IME inset 帧作为反馈环 | 本机无 Android 真机；该路径可确定性复现键盘边界滞后和布局次数，并直接覆盖真实 Widget 树 | 最终仍需编排者在 Android 真机确认 UI/Raster 帧时间 |
| 2026-08-10 | 移除跟随 IME 的 180ms `AnimatedPadding` | Flutter 已逐帧更新 `viewInsets`；隐式补间会在每个新值到达时重新追赶，最小复现中最终位置比目标滞后约 259 logical px | 面板不再叠加第二段键盘动画 |
| 2026-08-10 | 半屏使用 `Transform.translate` + `RepaintBoundary`，全屏保留同步 `Padding` | 半屏是主要输入场景，平移可保持内容布局稳定；全屏若整体平移会把顶部栏推出屏幕 | 半屏 8 帧布局事件由 504 降至 336（约 33%）；全屏顶部边缘保持固定 |
| 2026-08-10 | 根据真机反馈改为 Android 窗口级 `adjustPan` | 第一轮已解决卡顿，但只移动面板；产品预期是页面、遮罩和面板作为同一静态画面统一上移 | Android 跳过面板级 inset follower，并在应用根部阻止 Flutter 组件消费 Android IME bottom inset，避免二次位移；其他平台保留原有避让 |
| 2026-08-10 | 放弃原生 `adjustPan`，改由 Flutter 对话页 body 统一平移 | 真机证明 Android 仅弹出键盘，没有平移 Flutter 画面；编排者进一步明确顶栏必须固定，仅移动对话区域 | Activity 使用 `adjustNothing`；chat body 根据 IME inset 更新单一变换，body 子树看到 0 inset，避免布局抖动和局部二次位移 |
| 2026-08-11 | 参考 RikkaHub 的 Scaffold 分层与 IME 增量滚动，取消整个 chat body 变换 | 第三轮真机体感仍有轻微掉帧；整个富文本消息区参与逐帧合成是最高优先级可证伪根因 | 顶栏与消息视口固定；只平移输入栏的 `RepaintBoundary`；消息列表增加 IME spacer，并在同一布局帧按 inset 差值校正滚动偏移 |

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
| `flutter test test\android_keyboard_window_config_test.dart --reporter expanded`（第三轮修复前） | 失败（预期红灯）；最终配置仍为 `adjustPan`，真实主聊天页面在 320 logical px IME 下顶栏固定，但消息区仍停在 `y=56`，输入区也完全不动 | 2026-08-10 |
| `flutter test test\android_keyboard_window_config_test.dart test\paper_comments_keyboard_test.dart --reporter expanded`（第三轮修复后） | 通过；6 项。主聊天顶栏在 8 个 IME 帧中坐标不变，消息区与输入区逐帧等距上移，输入区子树 inset 为 0 且上移后仍可命中；评论半屏/全屏避让不回归 | 2026-08-10 |
| `flutter test test\android_keyboard_window_config_test.dart test\paper_comments_keyboard_test.dart test\ui_preview_test.dart test\paper_ai_mobile_chat_ui_test.dart test\paper_ai_composer_test.dart test\paper_message_composer_test.dart test\deepseek_settings_widget_test.dart test\tiktok_app_shell_test.dart test\widget_test.dart --reporter expanded` | 通过；56 项应用壳、评论、ChatPaper、输入和设置定向回归 | 2026-08-10 |
| `.\tool\verify_changed_dart_format.ps1`（第三轮） | 通过；5 个变更 Dart 文件格式正确 | 2026-08-10 |
| `flutter analyze`（第三轮） | 通过；No issues found | 2026-08-10 |
| `flutter test`（第三轮） | 通过；401 项全量测试 | 2026-08-10 |
| `flutter build apk --debug --flavor development --dart-define=SPARK_ENV=development`（第三轮） | 通过；`build/app/outputs/flutter-apk/app-development-debug.apk`，193,262,519 字节（184.31 MiB），SHA-256 `CF989F88FE881CE252D578CD393B0F4D911CF602D7AE4C798B260B5CE8CCD3BA` | 2026-08-10 |
| 检查 Gradle merged/packaged manifest（第三轮） | 通过；developmentDebug 最终清单均包含 `android:windowSoftInputMode="adjustNothing"` | 2026-08-10 |
| `git diff --check`（第三轮） | 通过 | 2026-08-10 |
| 读取 RikkaHub `2c980642` 的 `ChatPage.kt`、`ChatInput.kt` 与 `ImeAutoScroller.kt` | 确认其用 Scaffold 分离 topBar/bottomBar，输入栏单独消费 IME padding，LazyList 按键盘高度差值 `scrollBy` | 2026-08-11 |
| `flutter test test\android_keyboard_window_config_test.dart --reporter expanded`（第四轮修复前） | 失败（预期红灯）；第一个 40 logical px IME 帧就将消息视口从 `y=56` 平移到 `y=16`，长对话也没有独立滚动锚定 | 2026-08-11 |
| `flutter test test\android_keyboard_window_config_test.dart --reporter expanded`（第四轮修复后） | 通过；4 项。顶栏与消息视口在弹出/收起各 8 帧中坐标不变，输入栏贴合 IME，长对话滚动范围与偏移按 inset 差值同步；弹出 8 帧共 328 次布局事件，低于 360 上限 | 2026-08-11 |
| `flutter test test\android_keyboard_window_config_test.dart test\paper_comments_keyboard_test.dart test\paper_ai_mobile_chat_ui_test.dart test\paper_ai_composer_test.dart test\paper_message_composer_test.dart --reporter expanded` | 通过；25 项键盘、评论、ChatPaper 与输入交互定向回归 | 2026-08-11 |
| `.\tool\verify_changed_dart_format.ps1`（第四轮） | 通过；5 个变更 Dart 文件格式正确 | 2026-08-11 |
| `flutter analyze`（第四轮） | 通过；No issues found | 2026-08-11 |
| `flutter test`（第四轮） | 通过；402 项全量测试 | 2026-08-11 |
| `flutter build apk --debug --flavor development --dart-define=SPARK_ENV=development`（第四轮） | 通过；`build/app/outputs/flutter-apk/app-development-debug.apk`，193,264,913 字节（184.31 MiB），SHA-256 `994F93120066C0852FD3C4A55859C90C1245B0F4A2C9CE87E870D08850CD3597` | 2026-08-11 |
| 检查 Gradle merged/packaged manifest（第四轮） | 通过；developmentDebug 最终清单均包含 `android:windowSoftInputMode="adjustNothing"` | 2026-08-11 |
| `git diff --check`（第四轮） | 通过 | 2026-08-11 |

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
| `ee12142` | `修复（ChatPaper）：固定顶栏并上移对话区域` | 二次真机反馈纠偏、对话 body 图层平移与回归测试 | 真实主聊天红/绿反馈环、56 项定向测试、401 项全量测试、analyze、格式门禁、最终清单核对与 development APK 构建通过 |
| `c0c5826` | `修复（ChatPaper）：按输入栏与消息滚动跟随键盘` | RikkaHub 分层方案迭代、输入栏独立合成与滚动锚定 | 新红/绿反馈环、25 项定向测试、402 项全量测试、analyze、格式门禁、最终清单核对与 development APK 构建通过 |

## 交付准备（合并前收集）

### 交付摘要

Android 的评论/AI 面板不再为系统键盘的每个 inset 帧重启一段内部动画。根据真机反馈与 RikkaHub 的实际源码分层，Android 系统不 resize/pan 窗口；ChatPaper 顶栏和消息视口固定，仅将输入栏放入独立缓存合成层随 IME 上移，长对话内容通过滚动偏移的布局期校正保持底部锚定。评论半屏继续平移缓存图层，全屏继续固定顶部并同步缩短内容区。

### 实际变更

- 领域与业务逻辑：无计划变更。
- 数据与基础设施：无计划变更。
- 界面与交互：Android Activity 使用 `adjustNothing`；应用根部恢复 IME inset，仅把常驻主壳设为不 resize；`PaperAiChatScreen` 在 Android 固定 AppBar 与消息视口，通过 `_AndroidChatBottomBarFollower` 仅平移输入栏独立合成层，用 `_ImeAnchoringScrollController` 按 IME 差值锚定长对话；评论面板保留已验证的半屏图层平移与全屏同步 padding；其他平台保留 Scaffold/inset 默认行为。
- 测试与工具：最终 Android 清单配置测试覆盖 `adjustNothing`；真实主聊天路径覆盖弹出 8 帧顶栏/消息视口固定、输入区逐帧位移、inset 隔离、布局上限和变换后命中；长对话覆盖弹出/收起各 8 帧的滚动范围与偏移锚定；评论面板继续覆盖半屏/全屏几何、焦点和布局上限。
- 文档：本任务台账。

### 兼容性与迁移

- 本地数据迁移：无。
- API 或领域契约变化：无。
- 旧版本兼容性：仅展示层性能修复，无持久化影响。

### 已知风险与回滚

- 已知风险：当前无 Android 真机；自动测试能够锁定 Flutter 不再变换整个消息视口、仅平移输入栏并同帧校正滚动偏移，且最终 APK 清单为 `adjustNothing`，但不能直接证明具体设备的 UI/Raster 帧均低于刷新预算。
- 回滚方式：在合入后 revert 本任务修复提交；不涉及数据迁移或 API 兼容。

### 文档更新建议

- 性能缺陷修复不改变 `docs/development.md` 的能力状态；合并归档时记录为不适用。

### 未完成与后续工作

- Android 真机安装后先确认顶栏与消息视口不变，输入栏跟手上移，长对话内容与输入栏同步上滚且输入框不被遮挡，再使用系统 Profile GPU Rendering 或 Flutter DevTools Performance 复核键盘弹出与收起帧时间。

## 合并归档（合并后在 main 补齐）

- 最终状态：待合并
- 合入分支：`main`
- 最终集成提交：待合并后填写
- Pull Request：无
- 合并时间：待合并后填写
- main 集成验证：待合并后填写
- 开发计划更新：待合并后填写
- 最终后续项：待合并后填写
