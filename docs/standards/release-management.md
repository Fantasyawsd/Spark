# PaperFlow 发布与兼容性管理

> 状态：强制执行
> 最近更新：2026-08-02
> 适用范围：客户端发布、构建渠道、本地数据、自有 API 和功能开放

PaperFlow 分开管理代码版本、发布版本、数据版本、接口版本和功能版本。五者具有不同生命周期，不能用 Git 分支或单一版本号替代。

## 1. 事实源

| 层级 | 唯一事实源 | 当前实现 |
| --- | --- | --- |
| 代码版本 | Git commit、Pull Request、`main` | GitHub Flow 与 CI |
| 发布版本 | `pubspec.yaml` 的 `version` | `versionName+versionCode` |
| 数据版本 | 每个存储的 schema ID、schema version、Migration | `VersionedLocalJsonStore` |
| 接口版本 | 服务端路由与契约文档 | 暂无自有 API；未来从 `/api/v1` 开始 |
| 功能版本 | Feature Flag 定义与发布配置 | 编译期 Flag；生产默认关闭实验功能 |

`VERSION` 文件不作为额外事实源。Flutter 和 Android 已原生读取 `pubspec.yaml`，重复文件只会增加漂移风险。所有 flavor 的 `versionName` 都保持为该版本值；渠道只通过应用 ID 和应用名称区分。应用内展示常量由 `tool/set_version.ps1` 同步，并由 `tool/verify_version.ps1` 和 CI 校验。

## 2. 代码版本

- `main` 始终保持可构建、测试通过和可作为发布候选基线。
- 每个任务使用短生命周期 workstream 分支和独立 worktree。
- Agent 分支格式为 `<agent>/<type>-<slug>`，例如 `codex/feature-paper-channel`、`claude/fix-feed-cache`。
- 人类直接开发可使用 `feature/*`、`fix/*`、`hotfix/*`、`refactor/*`。
- 普通功能通过 Pull Request 合并到 `main`；紧急修复也必须保留审查和 CI 记录。
- CI 对本次变更涉及的 Dart 文件执行格式门禁；历史代码的全仓格式迁移必须单独提交，不混入功能分支。
- 分支合并后及时删除，不长期维护 `develop` 或通用 release 分支。
- GitHub 的 `main` 应启用分支保护：禁止强推、要求 Pull Request、要求 `Flutter CI / verify` 通过。

## 3. 发布版本与构建号

格式：

```text
<major>.<minor>.<patch>[-prerelease]+<build-number>
0.2.0-beta.3+27
```

- `major`：公开稳定版本出现不兼容的产品或数据变化。
- `minor`：增加用户可感知功能，`0.x` 阶段允许较大结构调整。
- `patch`：兼容性缺陷修复。
- `prerelease`：`alpha.n`、`beta.n` 或 `rc.n`。
- `build-number`：Android `versionCode`，每次上传或分发构建必须严格递增，即使展示版本不变。

更新命令：

```powershell
.\tool\set_version.ps1 -VersionName 0.1.1 -BuildNumber 2
.\tool\verify_version.ps1
```

版本更新后必须同步 `CHANGELOG.md`。正式发布满足检查清单后才创建 annotated Tag：

```powershell
git tag -a v0.1.1 -m "Release v0.1.1"
.\tool\verify_version.ps1 -RequireReleaseTag
git push origin v0.1.1
```

CI 会将版本与目标分支基线比较：SemVer 不得倒退，版本元数据变化时 build number 必须严格递增。Tag 不用于标记未完成开发或普通内部构建。正式 Tag 必须是 annotated Tag、必须指向远程当前 `main`，SemVer 与 build number 必须高于所有可达的历史正式 Tag，CHANGELOG 标题必须使用发布日期而不是候选状态；已推送 Tag 不移动、不覆盖，发布错误使用新 patch 与新构建号修复。

## 4. 环境与渠道

Android 使用三个 flavor：

| Flavor | 应用 ID | 名称 | 用途 |
| --- | --- | --- | --- |
| `development` | `app.paperflow.reader.dev` | PaperFlow Dev | 开发与 CI |
| `staging` | `app.paperflow.reader.staging` | PaperFlow Beta | 内测与候选验收 |
| `production` | `app.paperflow.reader` | PaperFlow | 正式发布 |

构建命令：

```powershell
flutter build apk --debug --flavor development --dart-define=PAPERFLOW_ENV=development
flutter build apk --debug --flavor staging --dart-define=PAPERFLOW_ENV=staging
flutter build appbundle --release --flavor production --dart-define=PAPERFLOW_ENV=production
```

Android 会读取 Flutter 提供的真实 `appFlavor` 并与 `PAPERFLOW_ENV` 校验，错配时拒绝启动；Windows 等无 flavor 平台使用 `PAPERFLOW_ENV`。非敏感开关可使用 `dart-define`；API Key、签名密码和 Token 不属于环境常量，必须使用安全存储或 CI Secret。

当前没有自有服务器和数据库，因此三个环境暂时共享公开的 arXiv/OpenAlex 端点，但应用身份和运行配置已经隔离。接入后端时必须为三个环境配置独立域名、凭据和数据库，测试包不得访问生产数据库。

## 5. 数据版本

当前设备数据使用独立 `schemaId`、`schemaVersion` 和逐版本 Migration。修改持久化结构时必须：

1. 先增加向后兼容字段或读取逻辑。
2. 增加单步 Migration，例如 `2 -> 3`，不得跨版本跳迁。
3. 覆盖旧数据升级、未来版本拒绝读取、损坏隔离和重启恢复测试。
4. 在开发报告和发布资料中记录数据影响及回滚方式。
5. 旧客户端仍可能运行时，不立即删除旧字段或改变字段语义。

未来服务端数据库只允许通过 `database/migrations/` 中的不可变迁移文件修改。采用 expand/migrate/contract：先扩展结构、再切换读写、确认旧客户端退出支持窗口后才删除旧字段。

## 6. 接口版本

当前客户端直接调用第三方公开接口，不伪造 PaperFlow API 版本。自有后端建立后：

- 首个稳定路径为 `/api/v1/...`。
- 新增可选字段、可选参数和新端点保持在 v1。
- 删除字段、改变字段含义、改变认证或核心数据结构时才创建 v2。
- 服务端至少兼容仍在支持窗口内的生产客户端。
- 每次发布记录客户端版本、最低 API 版本、最高已验证 API 版本和数据库 Migration 版本。
- DTO、缓存 Record、领域实体和展示模型继续分层，服务端响应不直接进入 Widget。

## 7. 功能版本与 Feature Flag

实验 Flag 定义在 `lib/src/core/config/feature_flags.dart`：

```text
PAPERFLOW_FEATURE_COMMUNITY
PAPERFLOW_FEATURE_CONFERENCE_CHANNELS
PAPERFLOW_FEATURE_PDF_AI
```

开发或 staging 构建可显式启用，例如 `--dart-define=PAPERFLOW_FEATURE_PDF_AI=true`。当前生产配置会强制清除实验 Flag，避免误发布。

编译期 Flag 只解决渠道隔离，不能实现在线止损或百分比灰度；接入账号和后端后，再增加签名远程配置、缓存、过期回退和按用户稳定分桶。远程配置不可绕过客户端最低安全限制。

## 8. 发布门

1. `main` 工作区干净，CI 通过。
2. 使用版本工具递增发布号或构建号，更新 CHANGELOG。
3. 编写版本说明 `docs/releases/<version>/README.md`。
4. 构建 production AAB/APK，验证签名、包名、版本号和 SHA-256。
5. 完成真机升级、数据 Migration、弱网、凭据和回滚验证。
6. 创建并推送 annotated Tag；Tag CI 再校验当前 `main`、历史发布单调性、CHANGELOG 日期和链接。
7. 将构建产物上传到对应 GitHub Release 附件；归档提交 SHA、迁移版本、已知问题和回滚方案；更新版本说明状态。如经应用商店发布，再完成商店测试与审核门。

当前仍是代码候选（版本号 `0.0.1+1`，未正式发布）；在签名、真机和商店发布门完成前不得创建正式发布 Tag。
