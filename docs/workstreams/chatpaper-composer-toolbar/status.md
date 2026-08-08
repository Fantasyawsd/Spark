# 任务台账

## 基本信息

- 任务：将 ChatPaper 与 AI 解读的 Composer 功能区移至输入框上方
- 关联发布或里程碑：不关联发布
- 分支：`fix/chatpaper-composer-toolbar`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\chatpaper-composer-toolbar`
- 基线提交：`13d7119`
- 负责人：Fantasy（编排者）；执行：Codex
- 状态：已合并
- 最近更新：2026-08-09

## 目标

让 ChatPaper 主聊天、论文聊天与 AI 解读共用的 Composer 将模型、联网搜索、思考深度和清除上下文功能区显示在输入框上方，并保持功能区背景透明、无明显容器。

## 非目标

- 不改变按钮功能、会话状态、发送行为或 AI 请求契约。
- 不调整 ChatPaper 顶部栏、消息区和非 AI 评论输入框。

## 验收标准

- [x] 功能区位于输入框上方且不在输入框装饰容器内。
- [x] 功能区无背景、边框和阴影，按钮呈悬浮视觉。
- [x] 发送/停止按钮保留在输入框内，单行和多行输入均不溢出。
- [x] ChatPaper 主聊天、论文聊天和 AI 解读共用新布局。
- [x] 模型面板移除标题和副标题，模型名保持几何居中。
- [x] 思考强度面板精简为关闭/自动/高/极致四档，并使用粗胶囊滑块样式。
- [x] 定向格式检查、静态分析和 Widget 测试通过。

## 写入范围

### 独占路径

- `lib/src/features/chat/presentation/widgets/paper_ai_composer.dart`
- `test/paper_ai_composer_test.dart`
- `docs/workstreams/chatpaper-composer-toolbar/status.md`

### 共享路径

- 无。

## 依赖关系

- 上游任务：无
- 外部接口或数据源：无

## 实施计划

1. 重排共用 Composer，将透明功能区置于独立输入框上方，并把发送按钮留在输入框内。
2. 更新 Widget 测试，覆盖功能区层级、相对位置、多行自适应和窄屏边界。
3. 运行定向格式、分析和测试，记录验证证据。

## 当前进度

- 已完成：必读文档、基线与共用组件调用范围确认；Composer、模型面板和思考强度面板调整；结构、多行、窄屏和聊天流程测试；格式与静态分析门禁；Windows 实机视觉验收；合入 `main`；合并后全量回归与双目标构建。
- 正在进行：无。
- 下一步：无；本次归档提交后清理任务 worktree 与分支。
- 阻塞项：无。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-08 | 功能按钮与输入框拆为兄弟层级，发送按钮保留在输入框内 | 匹配用户标注的目标位置，并让功能区无装饰容器 | 所有使用 `PaperAiComposer` 的界面同步生效 |
| 2026-08-08 | 模型面板移除标题和副标题，模型名在对称图标区之间居中 | 对齐验收截图，减少面板层级和冗余说明 | 模型选择面板高度更紧凑，选中态保持不变 |
| 2026-08-08 | 思考强度面板使用关闭/自动/高/极致四档，“自动”映射现有 `medium` API 档 | 满足四档产品语义，同时避免向 DeepSeek 发送未经支持的新参数 | `low` 不再进入界面选项；底层兼容能力保留 |
| 2026-08-08 | 思考强度滑块改为粗胶囊轨道、白色圆形滑块和两端状态点 | 对齐编排者提供的图 2 视觉参考 | 仍使用离散四档和原有回调契约 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter pub get` | 通过；依赖按项目约束解析 | 2026-08-08 |
| `.\tool\verify_changed_dart_format.ps1` | 通过；2 个变更 Dart 文件格式正确 | 2026-08-08 |
| `flutter analyze` | 通过；No issues found | 2026-08-08 |
| `flutter test test/paper_ai_composer_test.dart test/paper_ai_mobile_chat_ui_test.dart` | 通过；16 项定向测试 | 2026-08-08 |
| `flutter test` | 通过；394 项全量测试 | 2026-08-08 |
| `flutter run -d windows --no-resident --dart-define=SPARK_ENV=development` | 通过；更新后的 Windows debug 构建完成，Spark 窗口已启动并保持响应 | 2026-08-08 |
| `git diff --check` | 通过 | 2026-08-08 |
| Windows 人工视觉验收 | 通过；编排者逐轮确认工具栏、模型面板与思考强度面板，并明确批准 `/finish` | 2026-08-09 |
| `git merge-base --is-ancestor 1feb87b main` | 通过；任务提交已真实进入 `main` | 2026-08-09 |
| `dart format --output=none --set-exit-if-changed ...`（main） | 通过；2 个变更 Dart 文件无格式差异 | 2026-08-09 |
| `flutter analyze`（main） | 通过；No issues found | 2026-08-09 |
| `flutter test`（main） | 通过；394 项全量测试 | 2026-08-09 |
| `flutter build apk --debug --flavor development --dart-define=SPARK_ENV=development` | 通过；`build/app/outputs/flutter-apk/app-development-debug.apk`，193,258,407 字节（184.31 MiB），SHA-256 `9DB06E4BC1C07B5DB48C1BBA5ECAA003F8EDBD7F9096E3E77A47466E87660DC7` | 2026-08-09 |
| `flutter build windows --debug --dart-define=SPARK_ENV=development` | 通过；`build/windows/x64/runner/Debug/spark.exe`，1,278,976 字节（1.22 MiB），SHA-256 `AE6FF77E8BB96BBB6BAC49BCB8EB8DAD34DA05CD8957CBF37AB6D168DB9772E8` | 2026-08-09 |
| 合并后归档文档检查 | 通过；台账无 Markdown 链接目标，`git diff --check` 无错误 | 2026-08-09 |

## 审查结论

- 审查日期：2026-08-09
- 阻断项：无
- 缺陷：无；验收期间提出的模型面板和思考强度面板反馈均已修复并重新验证
- 结论：可合并；编排者完成 Windows 实机视觉验收并明确批准 `/finish`，豁免独立 `/review` 阶段

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `1feb87b` | `fix(chat): refine composer controls and panels` | 实现、测试与合并前台账 | 定向 16 项、全量 394 项、analyze、格式与 Windows 人工验收通过 |
| `93e8a5c` | `merge: refine chat composer controls` | 合并到 `main` | ancestry、main 全量回归、development APK 与 Windows debug EXE 构建通过 |

## 交付准备（合并前收集）

### 交付摘要

ChatPaper 主聊天、论文聊天和 AI 解读的功能按钮已统一移至输入框上方，以透明、无边框和无阴影的独立工具栏呈现；发送/停止按钮保留在输入框右下侧。

### 实际变更

- 领域与业务逻辑：无。
- 数据与基础设施：无。
- 界面与交互：共用 Composer 拆为透明功能区和独立输入框两个兄弟层级；发送/停止按钮并入输入框；模型选择面板移除标题、副标题并将模型名居中；思考强度面板精简标题和说明、压缩高度并改为关闭/自动/高/极致四档，滑块采用 18px 胶囊轨道、22px 白色圆形滑块和两端状态点。
- 测试与工具：更新 Composer Widget 测试，断言工具栏层级、上下位置、多行自适应、发送按钮归属、模型文案删除与居中，以及思考面板高度、四档选项和滑块主题；定向 16 项和全量 394 项测试通过。
- 文档：本任务台账。

### 兼容性与迁移

- 本地数据迁移：无。
- API 或领域契约变化：无。
- 旧版本兼容性：仅展示层布局调整。

### 已知风险与回滚

- 已知风险：无；Windows 桌面视觉已由编排者逐轮验收，自动化覆盖窄屏、多行和面板布局。
- 回滚方式：在 `main` revert 合并提交 `93e8a5c`；无数据迁移或持久化影响。

### 文档更新建议

- 纯展示调整，不影响 `docs/development.md` 能力状态。

### 未完成与后续工作

- 无。

## 合并归档（合并后在 main 补齐）

- 最终状态：已合并
- 合入分支：`main`
- 最终集成提交：`93e8a5c9bac5a27c833815631cb60a5229b514d9`
- Pull Request：无；日常开发由编排者批准本地直接合并
- 合并时间：2026-08-09 00:02:39（+08:00）
- main 集成验证：`git merge-base --is-ancestor 1feb87b main`、显式 Dart 格式检查、`flutter analyze`、394 项 `flutter test`、development debug APK 和 Windows debug EXE 均通过；两个构建产物的路径、大小与 SHA-256 已记录在验证表
- 开发计划更新：不适用；本任务只调整既有 ChatPaper Composer 与底部面板的展示和交互形态，不新增或改变 `docs/development.md` 中的产品能力状态
- 最终后续项：无
