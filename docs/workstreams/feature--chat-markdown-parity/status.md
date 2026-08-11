# 任务台账

## 基本信息

- 任务：对齐 RikkaHub 的 ChatPaper Markdown 与代码展示
- 关联发布或里程碑：不关联发布（日常功能改进）
- 分支：`feature/chat-markdown-parity`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\feature--chat-markdown-parity`
- 基线提交：`c01a6d252135cdfe82261a9c60be9fb0a137a62a`（本地 `main`；创建时比 `origin/main` 领先 13 个已集成提交）
- 负责人：Fantasy（编排者）；执行：Codex
- 状态：测试与人工验收通过，待审查
- 最近更新：2026-08-12

## 目标

让 ChatPaper 的 AI 与用户消息保持 RikkaHub 同类的 GFM + LaTeX 语法能力，并让代码块按应用亮暗模式使用 Atom One Light / Atom One Dark 语法高亮和 JetBrains Mono 字体；沿用 Spark 现有系统、亮色、暗色三档，不增加 AMOLED 纯黑模式。

## 非目标

- 不复制 RikkaHub 的 Kotlin/Compose 实现、主题预设、消息树、MCP、Workspace 或其他业务架构。
- 不增加 AMOLED 纯黑模式，也不重做 Spark 全局调色板和主题设置页。
- 不引入 Markdown 内嵌 HTML、WebView、Mermaid 或可执行代码预览。
- 不改变 DeepSeek 请求、会话持久化、论文缓存和领域契约。
- 不启动浏览器自动化或 Android 模拟器；Windows 应用只在编排者后续明确要求验收时启动。

## 验收标准

- [x] ChatPaper 继续使用 GFM 解析，并以测试覆盖标题、强调、删除线、引用、链接、列表、任务列表、表格、分隔线和围栏代码；现有行内/块级 LaTeX 行为不回归。
- [x] 亮色模式代码块使用 Atom One Light 调色板，暗色模式使用 Atom One Dark 调色板；容器、工具栏、边框和正文在两种模式下均有可读对比度，暗色背景不使用纯黑。
- [x] 围栏代码按语言进行语法高亮；未知语言和高亮失败时完整显示原始代码，不丢字、不崩溃，并保留复制能力。
- [x] 代码正文和行内代码使用随应用打包的 JetBrains Mono；字体授权文件随资源保留，不依赖运行时联网下载。
- [x] AI 流式内容、用户气泡、思考面板、论文正文共用 Markdown 和现有选择语义没有回归。
- [x] 定向 Widget 测试、格式检查、`flutter analyze`、全量 `flutter test` 与后续阶段要求的 release/profile 构建通过，结果如实写入本台账。

## 写入范围

### 独占路径

- `lib/src/core/widgets/spark_markdown.dart`
- `lib/src/core/theme/` 下新增的代码高亮主题文件（如需要）
- `assets/fonts/` 下新增的 JetBrains Mono 字体与授权文件
- `test/spark_markdown_test.dart`
- `test/paper_ai_message_view_test.dart`
- `docs/workstreams/feature--chat-markdown-parity/status.md`

### 共享路径

- `pubspec.yaml`、`pubspec.lock`：仅用于登记字体资源及经过评估后确有必要的语法高亮依赖；修改前复核其他活跃 worktree。
- `docs/development.md`：只在 `/finish` 按合并后的真实能力同步；任务分支不预写“已完成”。

## 依赖关系

- 上游任务：暗色模式、RikkaHub 风格 ChatPaper UI、共用 Markdown/LaTeX 与行内公式修复均已合入 `main`。
- 外部参考：本地只读 RikkaHub 源码 `references/源仓库/rikkahub`（AGPL-3.0）；只对照 GFM、Material 3 主题和 Atom One 配色，不复制其实现代码。
- 外部资源：JetBrains Mono（OFL-1.1）；如需新增高亮包，必须先核对许可证、维护状态、包体影响和 Flutter/Dart 兼容性。

## 实施计划

1. 固化基线事实：确认 Spark 与 RikkaHub 都使用 GFM，枚举 Spark 当前渲染与测试缺口；以新增 Widget 测试建立亮/暗配色、字体、语言高亮和 GFM 结构的失败基线。
2. 比较高亮实现路径：现有依赖能力、轻量 Dart 高亮依赖、有限手写 tokenizer；优先选择成熟、可降级且不破坏流式性能的方案，并记录许可证与依赖决策。
3. 将代码高亮调色板和渲染职责从 Markdown 解析中保持清晰边界，接入 Atom One Light/Dark、JetBrains Mono、复制与未知语言回退；保留现有 LaTeX、选择和流式稳定逻辑。
4. 运行定向测试和静态检查，检查亮/暗 Theme 下可观测颜色与字体；更新台账并形成职责单一的功能提交。
5. 等待编排者后续依次触发 `/test`、`/review`、`/finish`，不在本阶段跨越门禁。

## 当前进度

- 已完成：任务边界与基线确认；完成高亮依赖选型；新增本地 JetBrains Mono、Atom One Light/Dark 主题、有限语言 tokenizer、GFM AST 代码块 builder 与明暗/回退/GFM/LaTeX/消息视图测试；定向测试和静态门禁通过。
- 正在进行：无；自动门禁与 Windows release 人工验收均已通过。
- 下一步：等待编排者触发 `/review`。
- 阻塞项：无。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-11 | 使用本地 `main` 的 `c01a6d2` 作为基线 | `origin/main` 落后 13 个已集成提交，其中包含最近的主题和 ChatPaper 键盘工作 | 新任务完整继承当前可验收能力，不从过时远端基线开发 |
| 2026-08-11 | 保留 Spark 现有 GFM + LaTeX 解析路径 | Spark 与 RikkaHub 当前都使用 GFM；用户需要的是行为与展示对齐，不需要替换为 Kotlin 解析器 | 以补齐结构测试和渲染差异为主，降低公式与流式回归风险 |
| 2026-08-11 | 代码高亮对齐 Atom One Light/Dark，字体使用本地 JetBrains Mono | 这是 RikkaHub 代码展示的明确实现；本地打包避免运行时网络和字体漂移 | 新增字体资源与授权记录；两套 Theme 下分别验证 |
| 2026-08-11 | 不实现纯黑、HTML、Mermaid 和代码预览 | 用户明确不需要纯黑；其余属于更大安全和交互范围 | 本任务保持在 Markdown/代码展示边界内 |
| 2026-08-12 | 不引入 `syntax_highlight 0.5.0`，改用展示层内有限语言 tokenizer | 该包会传递引入 `super_clipboard` 原生插件，并造成 Windows 依赖降级和注册文件变化；与本次只读代码展示的范围不相称 | 保持依赖树和平台注册文件稳定；未知语言与高亮异常统一完整回退原文 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `/start` 基线检查：`git status --short`、diff stat、最近提交、worktree 列表、`origin/main...main` | 控制工作树干净；本地 `main` 比 `origin/main` 领先 13；采用 `c01a6d2` | 2026-08-11 |
| RikkaHub 源码只读核对 | 确认 GFM 解析、Material 3 Expressive 亮暗主题、Atom One Light/Dark 和 JetBrains Mono | 2026-08-11 |
| `flutter test test\\spark_markdown_test.dart --reporter expanded`（新增测试红测） | tokenizer、未知语言、主题和 GFM 波浪线围栏测试暴露捕获组编号漂移；原有非代码 Markdown/LaTeX 用例未见新增失败 | 2026-08-12 |
| `flutter pub get` | 资源与依赖解析通过；未新增、降级或修改锁定依赖 | 2026-08-12 |
| `flutter test test\\spark_markdown_test.dart test\\paper_ai_message_view_test.dart --reporter expanded` | 34 项通过；覆盖 GFM、LaTeX、所有声明语言原文完整性、未知语言回退、复制、亮暗 Atom 背景及消息选择语义 | 2026-08-12 |
| `flutter analyze` | 通过，0 issues | 2026-08-12 |
| `.\\tool\\verify_changed_dart_format.ps1` | 通过，3 个变更 Dart 文件格式正确 | 2026-08-12 |
| `git diff --check` | 通过 | 2026-08-12 |
| `/test`：`.\\tool\\verify_changed_dart_format.ps1` | 通过，3 个变更 Dart 文件格式正确 | 2026-08-12 |
| `/test`：`flutter analyze` | 通过，0 issues | 2026-08-12 |
| `/test`：`flutter test --reporter expanded` | 全量 417 项通过 | 2026-08-12 |
| `/test`：`flutter build apk --profile --flavor development --dart-define=SPARK_ENV=development` | 通过；因缺少 `android/key.properties` 按规则使用 profile；`build/app/outputs/flutter-apk/app-development-profile.apk`，90,808,169 bytes，SHA-256 `7CDFB11BB06488D61BAFE9D9AB977AB2EB016F54A8962BBCCBC9DAFE863299FC` | 2026-08-12 |
| `/test`：`flutter build windows --release --dart-define=SPARK_ENV=development` | 通过；`build/windows/x64/runner/Release/spark.exe`，101,888 bytes，SHA-256 `6216D4E75402B5C95B6E2F2E7783AFF156E5C36FAB15EF3389115C3E1C2DD680` | 2026-08-12 |
| `/test` 验收运行：`flutter pub get` + `flutter run -d windows --release --dart-define=SPARK_ENV=development` | 依赖解析通过；本任务 worktree 的 Spark release 窗口成功启动（PID `46060`）；人工验收结果待编排者反馈 | 2026-08-12 |
| `/test` 人工验收 | 编排者确认 GFM、LaTeX、亮暗模式、代码高亮、JetBrains Mono、复制及模型头像均正常；首次运行的头像缺失由验收期间重复构建造成，停止重复构建并从稳定 release 产物重启后恢复，未修改产品代码 | 2026-08-12 |

## 审查结论

> 由 `/review` 填写摘要（阻断项、缺陷、结论）。

- 审查日期：尚未进入 `/review` 阶段。
- 阻断项：尚未审查。
- 缺陷：尚未审查。
- 结论：尚未审查。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `20c5d21e792b5cb355463500d93465c3252c2565` | `新增（ChatPaper）：支持明暗代码高亮` | `/develop` | `flutter pub get`；34 项 Markdown/ChatPaper 定向测试；`flutter analyze`；变更 Dart 格式检查；`git diff --check` 均通过 |

## 交付准备（合并前收集）

### 交付摘要

尚未进入合并前交付整理阶段；当前仅完成任务初始化。

### 实际变更

- 领域与业务逻辑：无改动。
- 数据与基础设施：无改动；未新增第三方运行时依赖。
- 界面与交互：代码块由 GFM AST builder 统一渲染，支持 Atom One Light/Dark、语言标签、高亮、横向滚动、选择与复制；行内代码和代码块使用 JetBrains Mono；链接、引用和分隔线跟随应用主题。
- 测试与工具：新增 GFM 结构、代码围栏、明暗背景、token 分类、全部声明语言原文完整性、未知语言回退与复制测试，并回归 ChatPaper 消息视图。
- 文档：更新本任务台账；新增 JetBrains Mono OFL-1.1 授权文件。

### 兼容性与迁移

- 本地数据迁移：无。
- API 或领域契约变化：无。
- 旧版本兼容性：仅展示层变化，待实现后复核。

### 已知风险与回滚

- 已知风险：有限 tokenizer 只覆盖当前声明的常用语言和基础 token 类型，不承诺完整编译器级语法；不支持的语言完整回退纯文本。字体资源增加约 300 KiB 源文件体积。
- 回滚方式：整体 revert 本任务功能提交；不涉及本地数据迁移。

### 文档更新建议

- `/finish` 时评估是否在 `docs/development.md` 的 ChatPaper 当前能力与验收原则中记录代码高亮和主题适配。

### 未完成与后续工作

- HTML、Mermaid、代码执行/预览不在本任务范围，如确有产品需求应另开任务并评估安全边界。

## 合并归档（合并后在 main 补齐）

> 只有任务提交已真实进入 `main` 后才能填写。本节与 `docs/development.md` 的真实状态更新一并提交；完成后台账转为只读归档。

- 最终状态：不适用（任务尚未开发或合并）
- 合入分支：`main`
- 最终集成提交：不适用（任务尚未合并）
- Pull Request：无
- 合并时间：不适用（任务尚未合并）
- main 集成验证：不适用（任务尚未合并）
- 开发计划更新：不适用（任务尚未合并）
- 最终后续项：等待编排者触发 `/develop`。
