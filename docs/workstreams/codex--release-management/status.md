# Workstream 状态

## 基本信息

- Workstream：`release-management`
- 目标发布或里程碑：版本管理基础设施
- 分支：`codex/release-management`
- Worktree：`C:\Users\Fantasy\Desktop\PaperFlow-worktrees\codex-release-management`
- 基线提交：`4660302`
- 负责人：Codex
- 状态：已集成
- 最近更新：`2026-08-02`

## 目标

建立适合 PaperFlow 当前阶段的代码版本、发布版本、构建环境、数据/API 兼容和功能开关基础设施，使版本信息可校验、Android 渠道可隔离、主分支可由 CI 持续验证。

## 非目标

- 不创建尚不存在的服务端数据库、Migration 或 PaperFlow API。
- 不生成正式发布 Tag，不把代码候选标记为已上线。
- 不配置真实签名密钥、Play Console 或远程 Feature Flag 服务。

## 验收标准

- [x] `pubspec.yaml`、应用内版本和 CHANGELOG 可由工具校验。
- [x] Android 支持 development、staging、production 三个 flavor。
- [x] 实验功能具有生产默认关闭的编译期 Feature Flag 基础层。
- [x] GitHub Actions 执行基线版本/Tag 检查、变更文件格式、分析、测试、development/production APK 构建和无签名 release 阻断。
- [x] 版本、数据迁移、API 兼容与发布流程有唯一规范入口。
- [x] Flutter 分析、测试和 Android flavor 构建通过。

## 写入范围

### 独占路径

- `lib/src/core/config/`
- `test/app_config_test.dart`
- `tool/set_version.ps1`
- `tool/verify_version.ps1`
- `.github/workflows/ci.yml`
- `CHANGELOG.md`
- `android/app/build.gradle.kts`
- `android/app/src/main/AndroidManifest.xml`
- `lib/main.dart`
- `lib/src/app/paperflow_app.dart`
- `lib/src/features/profile/presentation/profile_screen.dart`

### 共享路径

- `AGENTS.md`、`README.md`、`docs/README.md`、`docs/standards/`：由本 workstream 作为当前集成负责人维护。

## 依赖关系

- 上游 workstream：无
- 下游 workstream：后续发布自动化、服务端数据/API
- 外部接口或数据源：GitHub Actions、Flutter Android flavor

## 实施计划

1. 建立应用版本、环境和 Feature Flag 类型及测试。
2. 增加 Android flavor、版本同步/校验工具和 CI。
3. 整理五层版本管理规范、CHANGELOG 与发布命令。
4. 完成全量验证、开发报告和原子提交。

## 当前进度

- 已完成：配置层、版本工具、三套 Android flavor、CI、五层版本规范、两轮只读审查、审查修复、完整验证，以及向 `main` 的快进集成。
- 集成结果：实现提交 `c35c173`、集成报告提交 `924c041` 和旧 `.ignore` 清理提交 `a51130a` 均已于 2026-08-02 推送并可从远程 `origin/main` 到达。
- 下一步：重新认证 GitHub 应用，核对首次 `main` GitHub Actions，并为 `main` 启用禁止强推、必须 Pull Request 和 `Flutter CI / verify` 必须通过的分支保护。
- 外部阻塞：GitHub 应用连接要求重新认证，当前无法读取 Actions 结果或修改仓库保护规则。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-02 | `pubspec.yaml` 作为发布版本唯一事实源 | Flutter 和 Android 已原生读取该字段，避免重复版本文件漂移 | 工具与 CI 必须同步校验应用内展示常量 |
| 2026-08-02 | 服务端数据/API 仅定义兼容规则 | 当前没有自有后端，提前创建空实现会产生虚假架构 | 后端 workstream 按规范落地 Migration 和 `/api/v1` |
| 2026-08-02 | CI 只强制格式化本次变更的 Dart 文件 | Dart 3.12 会重排大量历史文件，全仓迁移不应混入版本管理提交 | 后续单独建立基线格式迁移 workstream |
| 2026-08-02 | Android versionName 不追加渠道后缀 | `pubspec.yaml` 是唯一版本事实源，固定 `-beta` 会与 SemVer prerelease 重复 | 渠道通过 applicationId 与应用名称区分 |
| 2026-08-02 | 发布校验采用基线、实际 flavor 与实际 release 任务 | 防止版本倒退、环境错配和 Gradle 缩写/聚合任务绕过 | CI 与本地工具均 fail-closed |
| 2026-08-02 | 正式 Tag 必须位于当前远程 main 且高于历史正式 Tag | 防止给旧提交补 Tag 或用自身作为版本比较基线 | Tag CI 独立验证集成位置与发布单调性 |
| 2026-08-02 | 版本管理基础设施以快进方式集成到 `main` | GitHub 应用重新认证阻止创建 PR；本地四项门禁已通过且用户要求继续完成集成 | 这是分支保护启用前的 bootstrap 例外；后续普通开发恢复 Pull Request 流程 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `.\tool\verify_version.ps1` | `0.1.0+1` 一致性通过；临时提升到 build 2 后同步与校验闭环通过并已恢复 | 2026-08-02 |
| `.\tool\verify_changed_dart_format.ps1` | 无参数自动找到 `origin/main` merge-base，10 个变更 Dart 文件通过 | 2026-08-02 |
| Markdown 本地链接检查 / `git diff --check` | 通过 | 2026-08-02 |
| `flutter analyze` | 通过，无问题 | 2026-08-02 |
| `flutter test` | 195 项全部通过 | 2026-08-02 |
| development / staging / production debug APK | 三个 flavor 均构建成功，`aapt` 元数据符合约定 | 2026-08-02 |
| `:app:assembleProductionRelease`（无签名） | 按预期拒绝，错误信息明确 | 2026-08-02 |
| `:app:assembleProductionRel`（Gradle 缩写、无签名） | 仍由实际 release 任务门阻断 | 2026-08-02 |
| PowerShell 5 / 7 | 三个脚本使用 UTF-8 BOM；版本递增与基线校验均通过 | 2026-08-02 |
| 临时轻量 / annotated `v0.1.0` | 轻量 Tag 被拒绝；候选 CHANGELOG 被正式 Tag 门禁拒绝；临时 Tag 已删除 | 2026-08-02 |
| 开发分支临时 annotated `v0.1.0` | 因未指向当前 `origin/main` 被拒绝；临时 Tag 已删除 | 2026-08-02 |
| `main` 集成后版本、格式、分析和测试 | `0.1.0+1`、10 个 Dart 文件、`flutter analyze`、195 项测试全部通过 | 2026-08-02 |
| 远程 `main` SHA | `origin/main` 已核对为 `c35c173` | 2026-08-02 |

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `1efbebd` | `feat: add release environment configuration` | 配置层与 Android flavor | analyze、194 tests、三个 debug flavor 构建通过 |
| `5c4eeff` | `chore: add version checks and Flutter CI` | 工具与 CI | 版本升号/恢复闭环、格式与语法检查通过 |
| `f250c05` | `fix: enforce flavor and signing boundaries` | 审查修复 | 实际 flavor 校验、Gradle 缩写签名门、195 tests |
| `9156f0e` | `chore: harden version and release CI gates` | 审查修复 | 基线版本、Tag、PowerShell 5/7 和增量格式负向验证 |
