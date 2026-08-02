# Release Management Workstream 开发报告

## 基本信息

- Workstream：`release-management`
- 目标发布或里程碑：版本管理基础设施 / 0.1.0 发布准备
- 分支：`codex/release-management`
- 基线提交：`4660302`
- 最终提交：`c35c173`
- 负责人：Codex
- 报告日期：2026-08-02

## 交付摘要

PaperFlow 已建立代码、发布、数据、接口和功能五层版本管理的统一规则与当前阶段可执行的基础设施。Android 现在区分 development、staging、production 三个渠道；应用版本由 `pubspec.yaml` 管理，工具同步应用内展示并由 CI 相对基线校验；GitHub Actions 对 Pull Request、`main` 和发布 Tag 执行版本、格式、分析、测试、渠道构建和签名门禁。

本 workstream 没有创建不存在的服务端、数据库或虚假 API，也没有创建 `v0.1.0` Tag 或声称已经正式上线。

2026-08-02，开发分支在本地版本、增量格式、静态分析和 195 项测试全部通过后，以快进方式集成并推送至 `main`。由于 GitHub 应用连接要求重新认证，本次无法通过连接器创建 Pull Request 或读取首次远程 Actions 结果；这是分支保护启用前的一次 bootstrap 例外，不改变后续普通开发必须通过 Pull Request 和 CI 的规则。

## 实际变更

- 应用配置：新增环境、版本和 Feature Flag 类型，生产配置强制关闭实验 Flag。
- Android：新增三个 product flavor，以不同 applicationId 和应用标签隔离安装渠道，versionName 统一来自 `pubspec.yaml`。
- 版本工具：新增递增版本、校验版本和检查变更 Dart 文件格式的 PowerShell 脚本。
- CI：新增 GitHub Actions，执行依赖、基线版本与 Tag、格式、分析、测试、development/production APK、无签名 release 阻断和 artifact 上传。
- 界面：应用标题与环境联动；“我的”、许可页和隐私说明统一读取应用版本常量。
- 文档：新增 CHANGELOG 和五层版本管理规范，统一 GitHub Flow、分支命名、flavor 命令与发布检查清单。

## 架构和数据决策

- `pubspec.yaml` 是发布版本唯一事实源；`AppVersion.current` 只用于无需平台插件的应用内展示，由工具同步和 CI 防漂移。
- 当前 Feature Flag 是渠道隔离用的编译期配置，生产环境会强制清零；它不等同于远程止损或百分比灰度。
- 现有本地数据继续使用各存储自己的 schema version 和 Migration，本 workstream 不改变任何持久化 schema。
- PaperFlow 尚无自有后端，因此只定义未来 `/api/v1` 与数据库 expand/migrate/contract 规则，不创建占位服务。
- Dart 3.12 会重排大量历史文件；CI 先对本次变更的 Dart 文件执行格式门禁，全仓格式迁移留给独立机械 workstream。
- Android 使用 Flutter 的真实 `appFlavor` 校验请求环境；所有实际 release 任务都在缺少签名时失败，不能由 Gradle 缩写或聚合任务绕过。
- 正式 Tag 必须为 annotated Tag、指向远程当前 `main`、高于所有可达的历史正式 Tag，且 CHANGELOG 必须从候选状态更新为发布日期并包含正确链接。

## 主要文件

| 路径 | 变更原因 |
| --- | --- |
| `lib/src/core/config/` | 环境、版本与 Feature Flag 基础类型 |
| `android/app/build.gradle.kts` | development、staging、production flavor |
| `tool/set_version.ps1` | 安全递增展示版本与构建号 |
| `tool/verify_version.ps1` | 校验 pubspec、应用展示版本、CHANGELOG 与可选 Tag |
| `tool/verify_changed_dart_format.ps1` | 本地和 CI 的增量格式门禁 |
| `.github/workflows/ci.yml` | Pull Request 与 main 持续集成 |
| `docs/standards/release-management.md` | 五层版本与兼容性唯一规范入口 |
| `docs/releases/0.1.0/release-checklist.md` | flavor 发布命令和本次 APK 验证证据 |

## 提交列表

| SHA | 提交信息 | 可独立回退 |
| --- | --- | --- |
| `1efbebd` | `feat: add release environment configuration` | 是；移除配置层和 Android flavor |
| `5c4eeff` | `chore: add version checks and Flutter CI` | 是；移除工具与 CI，不改变应用数据 |
| `f250c05` | `fix: enforce flavor and signing boundaries` | 是；恢复到仅依赖规范命令的环境和签名检查 |
| `9156f0e` | `chore: harden version and release CI gates` | 是；恢复到无基线/Tag 持续门禁 |
| `43fc44c` | `docs: define five-layer release management` | 是；只回退规范、证据与协作说明 |
| `c35c173` | `fix: require release tags on current main` | 是；恢复到未校验远程 main 指向的 Tag 门禁 |

## 验证证据

| 命令或人工检查 | 结果 |
| --- | --- |
| `.\tool\verify_version.ps1` | `0.1.0+1` 通过 |
| 临时 `set_version` 至 `0.1.0+2` 后再校验 | 同步闭环通过；CRLF 与版本行后空行保持；已恢复为 `0.1.0+1` |
| `.\tool\verify_changed_dart_format.ps1` | 自动找到 `origin/main` merge-base，10 个变更 Dart 文件通过 |
| PowerShell 5 / 7 | UTF-8 BOM、版本递增和基线校验均通过 |
| Markdown 本地链接检查 | 通过 |
| `flutter analyze` | 通过，无问题 |
| `flutter test` | 195 项全部通过 |
| development debug APK | 成功；`app.paperflow.reader.dev` / `0.1.0` / PaperFlow Dev |
| staging debug APK | 成功；`app.paperflow.reader.staging` / `0.1.0` / PaperFlow Beta |
| production debug APK | 成功；`app.paperflow.reader` / `0.1.0` / PaperFlow |
| 无签名 production release | Gradle 按预期拒绝并给出签名配置错误 |
| Gradle 缩写 `assembleProductionRel` | 仍由实际 release 任务签名门阻断 |
| SemVer / Tag 负向测试 | 降级、轻量 Tag、候选 CHANGELOG 正式 Tag 均被拒绝；临时状态已清理 |
| 非 main annotated Tag | 因未指向当前 `origin/main` 被拒绝；临时 Tag 已清理 |
| `git diff --check` | 通过 |

## 兼容性与迁移

- 本地数据迁移：无。
- API 或领域契约变化：无；新增配置类型不进入论文或聊天领域层。
- 安装兼容性：production 保持 `app.paperflow.reader`；development 与 staging 使用独立包名，可与正式包并存。
- 构建兼容性：后续 Android 命令必须明确 flavor 与匹配的 `PAPERFLOW_ENV`；错配会在应用启动前失败。

## 已知风险与回滚

- GitHub Actions 已由 `main` 推送触发，但连接器重新认证阻止读取结果；本地已覆盖其核心命令，远程 runner 和 artifact 上传仍需认证后核对。
- Feature Flag 目前没有远程配置、百分比灰度或在线止损能力，且具体实验功能仍需在所属业务模块接入。
- production release 未生成，因为仓库不包含上传签名；正式签名、AAB、真机和 Play Console 仍是人工发布门。
- 回滚可按提交逆序执行 `git revert`；本 workstream 没有数据迁移，不需要恢复设备数据。

## 共享文档更新

- 已更新 `README.md`、`AGENTS.md`、`docs/README.md`、Git 规范、workstream 模板和 0.1.0 发布清单。
- `docs/standards/release-management.md` 已作为发布与兼容性唯一规范入口。

## 未完成与后续工作

- 在 GitHub 为 `main` 启用禁止强推、必须 PR、必须通过 `Flutter CI / verify` 的分支保护。
- 重新认证 GitHub 应用后，核对首次 `main` GitHub Actions 并确认 APK artifact 上传路径。
- 在 GitHub 为 `main` 启用分支保护后，后续普通开发必须通过 Pull Request 集成；本次直接快进是保护规则建立前的 bootstrap 例外。
- 单独建立历史 Dart 格式基线迁移，不混入功能提交。
- 接入自有后端时再落地 development/staging/production 独立服务、数据库 Migration、API v1 和远程 Feature Flag。
- 由持有签名和 Play Console 权限的人完成 0.1.0 正式发布门，之后再创建 annotated Tag。
