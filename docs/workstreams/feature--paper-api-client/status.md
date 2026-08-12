# 任务台账

## 基本信息

- 任务：在 Flutter development 环境接入本地 Paper API
- 关联发布或里程碑：论文数据服务客户端接入验证，不绑定发布版本
- 分支：`feature/paper-api-client`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\feature--paper-api-client`
- 基线提交：`f33c2ccd274f4f269a412244c7e2cc08b1cd0e4f`
- 负责人：Fantasy（编排者）
- 状态：已验收，待合入
- 最近更新：2026-08-11 22:42

## 目标

让 development 环境的 Flutter App 通过本地 `Paper API /api/v1` 获取推荐、最新、主题、会议和关注频道数据，并在服务不可用时保留现有 arXiv、本地缓存和种子回退能力，以便编排者在 Windows App 内验证 Phase 1/2 服务端闭环。

## 非目标

- 不切换 staging 或 production 的论文数据源。
- 不实现 Phase 3 热点、Phase 4 个性化或账号/云同步。
- 不修改 Paper API 协议，不导入真实外部数据。
- 不删除现有 arXiv 直连、缓存或种子回退实现。

## 验收标准

- [x] development 环境默认连接可配置的本地 Paper API，production 行为保持不变。
- [x] 推荐、最新、主题、会议和关注频道使用对应 `/api/v1` 接口，并正确处理游标分页与筛选参数。
- [x] API DTO 与领域 `Paper` 分层转换；未知字段保持未知，不伪造会议、引用数、stars 或单位。
- [x] 本地 API 不可用或响应异常时，App 能回退到现有 arXiv/缓存/种子链路并给出准确状态；服务端有效空列表保持为空，不混入不匹配的备用数据。
- [x] 数据层、组合根和控制器的定向测试覆盖远程成功、分页、映射和回退路径。
- [x] `flutter analyze`、相关测试和 Dart 格式检查通过。
- [x] Windows development App 能展示本地 fixture 论文 `Fixture AI Paper`，由编排者实际操作验收。

## 写入范围

### 独占路径

- `lib/src/features/papers/data/providers/paper_api/`
- `test/paper_api_*`
- `docs/workstreams/feature--paper-api-client/status.md`

### 共享路径

- `lib/src/app/spark_dependencies.dart`：仅修改论文目录依赖装配。
- `lib/src/core/config/`：仅增加 Paper API development 配置。
- `lib/src/features/papers/data/offline_first_paper_catalog_repository.dart`：仅在复用现有回退链路确有必要时修改。
- `docs/development.md`：仅在任务合入后更新真实状态。

## 依赖关系

- 上游任务：Phase 1/2 服务端实现 `main@7af6861`，归档基线 `main@f33c2cc`。
- 外部接口或数据源：本地 `http://127.0.0.1:8000/api/v1`、现有 arXiv Atom API、本地缓存和内置种子。

## 实施计划

1. 梳理 `PaperCatalogRepository` 查询契约、频道语义和组合根配置。
2. 实现 Paper API DTO、mapper、HTTP source 与游标状态。
3. 将 development 环境装配为 Paper API 优先、现有目录仓储回退，production 保持不变。
4. 补齐远程成功、筛选、分页、可空字段和回退测试。
5. 运行格式、定向测试与 `flutter analyze`，更新台账并提交检查点。

## 当前进度

- 已完成：创建独立分支和 worktree；确认本地 Paper API 健康检查返回 `status=ok`、`paper_count=1`。
- 已完成：补齐频道查询契约、opaque cursor、Paper API DTO/mapper/client、API 优先仓储、development-only 组合根和备用目录回退。
- 已完成：新增 API、仓储、控制器和配置测试；全量 Flutter 测试与 development Windows 构建通过。
- 已完成：编排者在 Windows App 内确认论文页和“最新”频道显示 `Fixture AI Paper`，并确认“我的”页数据源为 `Spark Paper API`。
- 下一步：将已验收提交合入 `main`，再完成合并后台账和开发计划归档。
- 阻塞项：无。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-11 | 仅 development 环境启用本地 Paper API | 当前目标是本地 App 验证，不能提前改变 production 数据契约 | production 继续使用现有 arXiv/缓存/种子链路 |
| 2026-08-11 | 保留现有目录仓储作为回退 | 本地服务可能未启动，App 不应因此失去论文浏览能力 | 需要为远程失败和空数据建立明确回退测试 |
| 2026-08-11 | 有效空列表不触发回退 | 空列表可能是正确的频道查询结果，回退会混入不匹配论文 | 只对连接、超时、HTTP 和协议错误启用备用目录 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `GET http://127.0.0.1:8000/api/v1/health` | 通过；`status=ok`、`schema_version=api.v1`、`paper_count=1` | 2026-08-11 |
| `flutter test` | 通过；420 项测试全部通过 | 2026-08-11 |
| `flutter analyze` | 通过；No issues found | 2026-08-11 |
| `flutter build windows --debug --dart-define=SPARK_ENV=development` | 通过；`build/windows/x64/runner/Debug/spark.exe`；1,279,488 bytes；SHA-256 `90036DCF90420B0CF2091756DB44CB3CA8B96A26E545D6A67EAE20C36CEE3C16` | 2026-08-11 |
| `flutter run -d windows --dart-define=SPARK_ENV=development` | 已启动；Windows App PID `17168`；待人工确认 `Fixture AI Paper` 和 `Spark Paper API` 状态 | 2026-08-11 |
| Windows App 人工验收 | 通过；论文页显示 `Fixture AI Paper`；“最新”频道显示该论文；“我的”页数据源显示 `Spark Paper API` | 2026-08-11 |

## 审查结论

- 审查日期：
- 阻断项：
- 缺陷：
- 结论：待审查

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |

## 交付准备（合并前收集）

### 交付摘要

development 环境的 Flutter App 已接入本地 Paper API，保留原有离线优先回退链路，并完成 Windows App 人工验收。

### 实际变更

- 领域与业务逻辑：扩展论文频道查询、关注作者和已读筛选、opaque cursor 分页。
- 数据与基础设施：新增 Paper API DTO、映射器、HTTP 客户端及 API 优先目录仓储；API 异常时回退 arXiv、缓存和种子。
- 界面与交互：development 组合根接入 Paper API，Profile 数据源显示 `Spark Paper API`。
- 测试与工具：新增客户端、仓储、控制器查询契约和配置测试；完成 Flutter 分析、测试和 Windows debug 构建。
- 文档：补充本任务台账和人工验收记录。

### 兼容性与迁移

- 本地数据迁移：无。
- API 或领域契约变化：Flutter 侧新增 Paper API 查询契约，服务端协议保持不变。
- 旧版本兼容性：production 数据源保持不变。

### 已知风险与回滚

- 已知风险：本地服务必须先于 App 启动；Android 设备访问宿主机时不能使用 `127.0.0.1`，本任务仅验收 Windows development App。
- 回滚方式：revert 本任务提交即可恢复 development 环境原有目录装配；不涉及本地数据迁移。

### 文档更新建议

- 合入后更新 `docs/development.md` 的 Flutter Client 数据源边界。

### 未完成与后续工作

- Android 真机访问地址、staging/production 服务地址和真实数据部署另行排期。

## 合并归档（合并后在 main 补齐）

- 最终状态：待合并
- 合入分支：`main`
- 最终集成提交：待填写
- Pull Request：无
- 合并时间：待填写
- main 集成验证：待填写
- 开发计划更新：待填写
- 最终后续项：待填写
