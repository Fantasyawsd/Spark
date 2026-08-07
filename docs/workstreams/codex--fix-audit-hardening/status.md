# 审查问题稳健性修复台账

## 基本信息

- 任务：修复全仓审查中除旧版本迁移外的稳健性、正确性、性能与架构问题
- 关联发布或里程碑：首次公开发布前质量加固
- 分支：`codex/fix-audit-hardening`
- Worktree：`%USERPROFILE%\Desktop\Spark-worktrees\codex--fix-audit-hardening`
- 基线提交：`e8adb382fff91d1834d9e349e0a080c70bfced62`
- 负责人：Codex（用户编排）
- 状态：待合并
- 最近更新：`2026-08-07 16:56`

## 目标

修复审查确认的本地数据、缓存、PDF、AI 流式请求、聊天状态、论文列表与搜索控制器、功能开关、模块边界和开发工具问题，使首次发布基线具备可重复验证的正确性与故障恢复能力。

## 非目标

- 不迁移 PaperFlow 旧目录、旧 JSON format、旧安全存储 namespace 或旧 Android application ID；产品尚未发布，不存在需要兼容的旧版本。
- 不新增账号、云同步、服务端代理或在线 Feature Flag。
- 不启动 Windows 应用、Android 模拟器或浏览器自动化；本轮使用测试、静态分析和构建验证。

## 验收标准

- [x] 本地数据统计和清理覆盖 PDF 提取缓存、损坏隔离文件和残留临时文件。
- [x] 翻译、PDF 与论文目录缓存具备内容版本校验、损坏恢复和有界淘汰策略。
- [x] PDF 下载、解析与分块有资源上限，异常或取消不会留下永久 loading。
- [x] DeepSeek 流式请求具有响应头、流空闲和总时长边界；并发请求与客户端所有权互不干扰。
- [x] 聊天取消、删除、异步持久化、阅读初始化、论文分页和搜索分页不存在已识别的竞态或陈旧状态。
- [x] Feature Flag 实际门控实验能力，非开发构建不读取编译期 DeepSeek Key，短 Key 脱敏安全。
- [x] 分享文本和缓存预加载等小型健壮性问题有回归覆盖。
- [x] 关键跨层/跨 feature 反向依赖消除，组合根、Profile 和论文 Feed 的独立业务职责合理下沉或拆分。
- [x] 文档 worktree 路径与实际 Spark 仓库一致，Windows 格式门禁可处理大量 Dart 文件。
- [x] 格式门禁、`flutter analyze`、`flutter test`、development debug APK 构建和 `git diff --check` 通过。

## 写入范围

### 独占路径

- `lib/src/features/local_data/`、相关测试：数据与缓存 agent
- `lib/src/features/papers/data/`、相关 PDF/缓存测试：数据与缓存 agent
- `lib/src/features/chat/`、`lib/src/features/ai_settings/`、相关测试：AI 与聊天 agent
- `lib/src/features/papers/application/`、`lib/src/features/papers/presentation/`、`lib/src/features/search/`、`lib/src/features/profile/`、相关测试：论文状态与界面 agent
- `docs/workstreams/codex--fix-audit-hardening/status.md`、规范文档、工具脚本和最终组合根整合：主 agent

### 共享路径

- `lib/src/app/spark_app.dart`、`lib/src/app/spark_dependencies.dart` 仅由主 agent 串行修改。
- `lib/src/core/` 仅由主 agent 在各业务边界明确后串行修改。

## 依赖关系

- 上游任务：无；基于本地 `main@e8adb38`。
- 外部接口或数据源：arXiv、DeepSeek（测试均使用本地 fake/client，不依赖实时服务）。

## 实施计划

1. 建立问题到生产文件、故障模式和回归测试的映射。
2. 并行修复数据/PDF、AI/聊天、论文/搜索状态三组互斥路径。
3. 串行完成组合根、跨模块边界、大文件职责拆分和工具文档修复。
4. 运行定向及全量验证，按标准/需求双轴审查并修正阻断项。
5. 形成原子提交并补齐交付、兼容性、风险和验证记录。

## 当前进度

- 已完成：读取仓库规范与实施/验证技能；恢复工作区；创建独立分支和 worktree；三路只读核对确认除旧版本迁移外的问题均仍成立；冻结互斥写入范围；移除编译期 DeepSeek Key 辅助脚本；修正规范路径与格式门禁分批执行。
- 已完成：数据/PDF、AI/聊天、论文/搜索/Profile 三路修复；组合根、Feature Flag、模块公开入口、DTO/mapper、core 边界和 Windows 格式门禁已串行接入。
- 已完成：定向竞态与故障回归；首轮固定基线双轴复审新增的 PDF/缓存资源边界、控制器竞态和公共入口阻断项均已修复。
- 已完成：提交后双轴复审发现 Chat 设置迟到加载和 Papers 跨 feature 深导入两项遗漏；分别以 settings revision、Papers 领域公共入口及递归架构门禁修复。
- 已完成：最终格式、静态分析、394 项全量测试和 development debug APK 已从最新文件状态通过；代码、规范及复审修复形成四个可解释检查点。
- 下一步：独立 `check-work` 验证通过后交由用户决定合并时机。
- 阻塞项：无。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-07 | 排除全部旧 PaperFlow 数据与标识迁移 | 用户确认尚无旧版本 | 可直接修订当前 schema，不增加无效兼容分支 |
| 2026-08-07 | 使用本地 `main@e8adb38` 为基线 | 控制工作树干净，且最新功能提交均在本地 main | 不以落后 14 个提交的 `origin/main` 为实现基线 |
| 2026-08-07 | 不启动应用或浏览器自动化 | 用户未授权 Windows 启动，项目规则要求前端只做静态验证 | 以 Widget 测试、analyzer 和 APK 构建作为证据 |
| 2026-08-07 | 保留恢复后的首轮生产代码与对应测试为单一检查点 | 关机恢复时跨模块契约迁移与全部回归已共存于未提交工作区；不在缺少原始中间状态的情况下伪造事后历史 | 首个检查点范围较大；规范工具及两项复审修复均另行原子提交 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `git status --short`（基线） | 通过，控制工作树干净 | 2026-08-07 |
| `flutter pub get` | 通过；依赖解析成功 | 2026-08-07 |
| `flutter test test/paper_controller_test.dart test/paper_feed_preference_coordinator_test.dart test/paper_search_controller_test.dart` | 51 项通过 | 2026-08-07 |
| `flutter test test/paper_pdf_test.dart test/file_paper_storage_schema_test.dart` | 29/29 通过；覆盖 PDF 资源边界、超时终止、TTL、容量和跨实例原子写 | 2026-08-07 |
| `flutter test test/cached_paper_pdf_content_provider_test.dart` | 4/4 通过 | 2026-08-07 |
| `flutter test test/chat_conversation_controller_test.dart test/paper_feed_preference_coordinator_test.dart test/paper_reading_controller_test.dart test/paper_search_controller_test.dart` | 39/39 通过；覆盖初始化、mutation 重放和分页游标竞态 | 2026-08-07 |
| `flutter test test/paper_controller_test.dart` | 30/30 通过 | 2026-08-07 |
| `flutter test test/architecture_boundaries_test.dart` | 7/7 通过；含递归 barrel export 边界检查 | 2026-08-07 |
| `.\tool\verify_changed_dart_format.ps1` | 160 个变更 Dart 文件通过；脚本支持分批、删除路径过滤和本地 main 基线 | 2026-08-07 |
| `flutter analyze` | No issues found | 2026-08-07 |
| `flutter test` | 394/394 通过 | 2026-08-07 |
| `flutter build apk --debug --flavor development --dart-define=SPARK_ENV=development` | 最新代码 APK 构建成功：`build/app/outputs/flutter-apk/app-development-debug.apk`，164,790,693 bytes，SHA-256 `C4A2EE91165332E82B2971381AE831719800FDCDBE61EFB0809A79FE3FF46C4A` | 2026-08-07 |
| `git diff --check`、冲突标记、敏感信息、异常大文件与边界扫描 | 通过；仅有 Git CRLF 转换提示；无旧 shim、无 `data -> application`、无 presentation 直接 Clipboard | 2026-08-07 |

## 审查结论

- 审查日期：2026-08-07（固定基线首轮与提交后双轴复审均已完成）
- 首轮阻断项：PDF 输入/页数/字符/分块和可终止 deadline；PDF/翻译缓存 TTL、容量与跨实例原子写；Chat/Reading/Feed/Search 初始化和分页竞态；feature 公共入口与递归 barrel export 边界。
- 修复状态：上述首轮阻断项均已修复并通过定向及全量回归。
- 提交后阻断项：Chat 设置加载期间的用户更新可能被迟到结果覆盖；Profile/Search 直接深导入 Papers 领域实现，架构门禁存在 domain 假阴性。
- 提交后修复：`37babea` 以设置 revision 保留新 mutation；`4259b1f` 新增 Papers 领域公共入口并收紧跨 feature 门禁；定向 48 项及全量 394 项回归通过。
- 结论：标准轴与需求轴已无未修复阻断项，当前分支可进入独立 verifier 与合并决策。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `6db94c7` | `fix: harden runtime state and persistence` | 首轮生产代码与对应回归 | 格式、analyze、393 项全量测试及 development debug APK 通过 |
| `93924cf` | `chore: align validation and repository guidance` | 规范与工具 | 格式脚本、文档路径、BYOK 规则和 `git diff --check` 通过 |
| `37babea` | `fix(chat): preserve settings changed during load` | 需求轴复审修复 | Chat/设置定向 19 项、analyze 与全量回归通过 |
| `4259b1f` | `refactor(papers): expose cross-feature domain contracts` | 标准轴复审修复 | 架构/Profile/Search 定向回归、跨 feature 扫描与全量回归通过 |

## 交付准备（合并前收集）

### 交付摘要

本任务修复首次公开发布前审查确认的稳健性、正确性、性能和架构问题；按用户决定不处理旧 PaperFlow 版本迁移。

### 实际变更

- 领域与业务逻辑：修复论文 Feed/Search 分页与历史竞态，拆分 Feed 偏好协调和投影，统一 Chat 会话契约。
- 数据与基础设施：为本地 JSON、翻译/PDF/目录缓存增加版本、指纹、TTL、容量和损坏隔离；限制 PDF 下载/解析；强化 DeepSeek SSE 超时、取消和客户端所有权；缓存与分享失败采用 best-effort/统一异常。
- 界面与交互：Feature Flag 实际门控社区、会议和 PDF AI；Reader/Profile/Chat 职责拆分；全文加载失败复位并反馈；剪贴板经公共平台端口。
- 测试与工具：新增架构边界、Feature Flag、PDF provider/context loader 和并发回归；修复窄导入；格式门禁改为分批并过滤已删除路径。
- 文档：修正 Spark worktree 路径、开发计划会话存储命名和任务台账证据。

### 兼容性与迁移

- 本地数据迁移：不兼容旧 PaperFlow 版本；当前 Spark 尚未发布。
- API 或领域契约变化：Chat 会话仓储统一使用 `contextId`；论文翻译 data 层改为注入 Chat 领域流式接口；旧 PaperAI 兼容 shim 已删除。
- 旧版本兼容性：按用户决策不提供。

### 已知风险与回滚

- 已知风险：未进行真实设备/Windows 应用人工验收；第三方 arXiv/DeepSeek 运行时行为仍依赖网络和用户 BYOK。当前构建与测试均使用本地 fake 或静态门禁。
- 回滚方式：按依赖逆序 `git revert 4259b1f 37babea 93924cf 6db94c7`；涉及当前开发数据 schema 时以损坏隔离和重建缓存恢复。

### 文档更新建议

- 修正规范中的旧 worktree 根路径；功能状态不变，预计无需修改产品路线图。

### 未完成与后续工作

- 待后续：真实 Android 设备验收、发布签名/商店门禁和任何未来旧版本迁移策略另行立项。

## 合并归档（合并后在 main 补齐）

- 最终状态：待合并
- 合入分支：`main`
- 最终集成提交：待合并后填写
- Pull Request：无
- 合并时间：待填写
- main 集成验证：待填写
- 开发计划更新：待确定
- 最终后续项：真实 Android 设备验收与发布门另行安排；本任务不处理不存在的旧版本迁移
