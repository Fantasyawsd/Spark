# DeepSeek 报告数据正确性修复台账

> 本台账记录 DeepSeek 报告逐步修复链的第一批任务。后续批次使用新的 `agent-<n>` worktree，并以前一批修复分支的最新提交为基线；按编排者要求不合入 `main`。

## 基本信息

- 任务：修复审查报告中经当前源码确认的数据正确性与输入健壮性问题
- 关联发布或里程碑：代码质量加固，不绑定发布版本
- 分支：`fix/report-data-correctness`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-1`
- 基线提交：`5578a77d12dd3779940d2352d216e1f766ab47fa`
- 负责人：Codex（Fantasy 编排）
- 状态：已合并
- 合并归档：实现提交已随审计串行批次合入 main（2026-08-13 至 2026-08-14）；合并后 flutter analyze 无问题、flutter test 582 项通过、Windows 开发版人工验收通过，批次集成记录见 audit--deepseek-report-final 台账。
- 最近更新：2026-08-14

## 目标

使论文离线缓存与服务端数据管道在相对时间、可空字段、必填时间、OpenAlex Topic 身份、冲突统计和非法 JSON 根节点六类边界上保持真实、可恢复且可回归验证的语义。

## 非目标

- 本批不处理报告中的大文件拆分、日志体系、重复代码、死代码、主题单例、关注状态双源、N+1 查询和推荐模型增强；这些问题在后续串联 worktree 中逐批核实和修复。
- 不修改报告中已经不成立的结论；例如当前推荐 freshness 已显式传递 `as_of`，不会重复修复。
- 不启动 Windows App、不做人工验收、不执行浏览器自动化。
- 不合入 `main`，不清理本 worktree；下一批从本分支最终提交继续创建。

## 验收标准

- [x] 相对时间 Feed 缓存键包含具体时间窗口锚点，跨日期离线回退不会命中过期窗口页面。
- [x] 空白或纯空白 Abstract 规范化为 `null`，未知字段不以空字符串占位。
- [x] 数据库必填时间损坏时显式失败并保留可诊断字段信息，不用当前时间伪造发布时间或抓取时间。
- [x] OpenAlex Topic URL 与裸 Topic ID 使用统一规范形式比较，AI 准入规则对两种表示一致生效。
- [x] 精确身份冲突进入待核验队列且不计入成功落库数量；同步结果可区分成功、拒绝与挂起冲突。
- [x] JSON 文件根节点为 `null`、标量或其他非法结构时转为受控 `SourceError`，CLI/同步入口不会因 `AttributeError` 逃逸。
- [x] 每项新行为均有独立回归测试；相关 Flutter 与 Python 定向测试、静态检查和 `git diff --check` 通过。

## 写入范围

### 独占路径

- `lib/src/features/papers/data/offline_first_paper_catalog_repository.dart`
- `test/offline_first_paper_catalog_repository_test.dart`
- `server/spark_papers/db_mapper.py`
- `server/spark_papers/normalization.py`
- `server/spark_papers/policy.py`
- `server/spark_papers/ports.py`
- `server/spark_papers/storage.py`
- `server/spark_papers/pipeline.py`
- `server/spark_papers/sources.py`
- `server/tests/`
- `docs/workstreams/fix--report-data-correctness/status.md`

### 共享路径

- 无；当前已注册 worktree 中只有控制工作树与本任务 worktree，重叠历史任务均已合并归档。

## 依赖关系

- 上游任务：本地 `main@5578a77`；此前审查加固、Paper Data Platform 与 Phase 2.5 台账均已归档。
- 外部接口或数据源：无；验证使用本地 fixture、临时文件和临时 SQLite。

## 实施计划

1. 为六类边界分别补充能在旧实现上失败的回归测试，固定期望契约。
2. 修复相对时间缓存键和服务端规范化、映射、准入、冲突结果与来源解析逻辑。
3. 运行 Flutter/Python 定向测试并处理回归，形成职责清晰的代码检查点提交。
4. 更新本台账，执行本批 `/test` 与 `/review`；按用户要求保留分支，不进入合并 `main` 的 `/finish`。
5. 创建下一修复 worktree 时，以本分支最终提交为基线继续报告中的剩余问题。

## 当前进度

- 已完成：读取 `/start` skill、项目必读文档、报告原文和三个重叠历史台账；确认控制工作树干净。
- 已完成：逐项核对第一批候选；确认六项在当前源码仍成立，确认 freshness 的 `as_of` 问题在当前源码已不存在。
- 已完成：从本地最新 `main@5578a77` 创建 `fix/report-data-correctness` 与 `agent-1`。
- 已完成：六类边界均先增加失败回归，再完成实现；代码与测试已形成 `5ea6778` 原子提交。
- 已完成：服务端全量 55 项、Flutter 定向与架构 20 项、格式、静态分析、Python 编译和 diff 检查通过。
- 已完成：`/test` 完整门禁通过；Dart 格式、静态分析、448 项 Flutter 全量测试、55 项服务端测试和 Python 编译均成功。
- 已完成：`/review` 对固定基线 `5578a77...714aea2` 的 15 个文件逐项审查通过，无阻断项或缺陷。
- 正在进行：第一批已验证并保留在修复链分支，不执行常规 `/finish` 或合并。
- 下一步：从本分支最终提交创建新的 `agent-<n>` worktree，开始下一批结构与架构门禁修复。
- 阻塞项：无。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-13 | 第一批优先处理六项数据正确性问题 | 这些问题会导致过期内容、伪造时间、准入失效、统计失真或 CLI 异常逃逸 | 先建立可验证的数据契约，再处理结构性技术债 |
| 2026-08-13 | 基线使用本地 `main@5578a77` | 本地 `main` 干净且比 `origin/main` 多 76 个提交，代表当前真实仓库状态 | 不从落后远端基线丢失已完成工作 |
| 2026-08-13 | 不把 recommendation freshness 纳入修复 | 当前 `_signal`、`_normalized_signal` 和调用方均已传递 `as_of` | 报告该项已过时，只保留核验结论 |
| 2026-08-13 | 修复链不合入 `main`，后续 worktree 以前一批提交为基线 | 编排者明确要求连续修复并保留在 worktree 中 | 各批次形成串联分支；最终合并策略另行决定 |
| 2026-08-13 | 不进行人工验收 | 编排者明确免除人工验收，本批也不含 UI 交互改动 | 以自动化回归和静态门禁作为证据 |
| 2026-08-13 | `/review` 使用批准基线 `5578a77` 而非 `origin/main` merge-base | `origin/main@948f3af` 比本地任务基线落后 76 个提交，使用它会混入与本任务无关的已合并历史 | 审查范围精确限定为本任务 3 个提交、15 个文件、`+492/-29` |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `/start` Git 预检 | 控制工作树 `main` 干净；无未暂存或已暂存改动；仅控制 worktree 已注册 | 2026-08-13 |
| `git rev-list --left-right --count origin/main...main` | `0 76`，确认本地 `main` 为更新基线 | 2026-08-13 |
| 报告问题源码定向检索 | 六项第一批缺陷仍成立；freshness `as_of` 已修复，不再列入 | 2026-08-13 |
| 首次服务端基线命令（未设置 `PYTHONPATH`） | 仅在收集阶段因找不到本地包失败，0 项测试执行；随后按仓库要求修正环境 | 2026-08-13 |
| `$env:PYTHONPATH=(Resolve-Path server).Path; python -m unittest discover -s server/tests -v`（基线） | 48 项全部通过 | 2026-08-13 |
| 六项新增回归测试（修复前） | 准确暴露旧窗口缓存命中、空摘要、伪造时间、Topic 比较失配、冲突误计数和 `AttributeError` 逃逸 | 2026-08-13 |
| `$env:PYTHONPATH=(Resolve-Path server).Path; python -m unittest discover -s server/tests -v`（修复后） | 55 项全部通过 | 2026-08-13 |
| `flutter test test/offline_first_paper_catalog_repository_test.dart test/architecture_boundaries_test.dart` | 20 项全部通过 | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1` | 通过；2 个改动 Dart 文件均符合格式 | 2026-08-13 |
| `flutter analyze` | `No issues found` | 2026-08-13 |
| `python -m compileall -q server` | 通过 | 2026-08-13 |
| `git diff --cached --check` 与敏感词检查 | 通过；无空白错误、密钥或异常生成文件进入提交 | 2026-08-13 |
| `/test` `.\tool\verify_changed_dart_format.ps1` | 通过；2 个任务 Dart 文件，0 个需格式化 | 2026-08-13 |
| `/test` `flutter analyze` | `No issues found` | 2026-08-13 |
| `/test` `flutter test` | 448 项全部通过 | 2026-08-13 |
| `/test` `$env:PYTHONPATH=(Resolve-Path server).Path; python -m unittest discover -s server/tests -v` | 55 项全部通过 | 2026-08-13 |
| `/test` `python -m compileall -q server` | 通过 | 2026-08-13 |
| `/test` `git diff --check` | 通过 | 2026-08-13 |
| `/test` 目标构建 | 按阶段规范不运行；APK 与 Windows release 构建仅属于常规 `/finish` 合并后门禁，本修复链不合入 `main` | 2026-08-13 |
| `/test` 人工验收 | 按编排者明确指示不运行；本批无 UI 交互变更 | 2026-08-13 |

## 审查结论

- 审查日期：2026-08-13
- 审查范围：`5578a77d12dd3779940d2352d216e1f766ab47fa...714aea28ead6cce2b0c7b9daba9ccef161f4d0a3`；15 个文件，新增 492 行、删除 29 行。
- 规格核对：六项验收标准均满足；每项均有直接回归测试或共享实现路径证据，未发现越出非目标的生产改动。
- 结构核对：未触发 Widget/Controller 基础设施直连、领域层外部依赖、跨模块深导入、循环依赖、多职数据类型、core 反向依赖、业务 utils、深继承或不可独立测试等阻断条件。
- 阻断项：无。
- 缺陷：无。
- 建议：无本批必须处理项；报告中的 mapper 助手重复和更广泛结构债保留给后续串联 worktree 统一处理，不在本批顺手扩张。
- `/test` 证据：格式、`flutter analyze`、448 项 Flutter 测试、55 项服务端测试、Python 编译和 diff 检查全部通过。
- 未验证项：按阶段未执行目标构建；按编排者要求未进行人工验收；两项均不构成本批审查阻断。
- 结论：审查通过，可作为下一串联修复 worktree 的基线；按编排者要求不合入 `main`。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `5ea6778` | `修复（论文数据）：校正缓存与同步边界语义` | `/develop` | 服务端 55 项、Flutter 定向与架构 20 项、格式、analyze、compileall 和 diff 检查通过 |
| `e72a91e` | `文档（台账）：记录数据正确性修复` | `/develop` | 记录实现、定向验证、兼容性和串联 worktree 约束 |
| `714aea2` | `文档（台账）：记录数据正确性门禁` | `/test` | 记录 Flutter 448 项、服务端 55 项及其余完整门禁证据 |

## 交付准备（合并前收集）

### 交付摘要

已实现六项数据正确性与非法输入边界修复，完整 `/test` 与只读 `/review` 均已通过；本分支按编排者要求不合入 `main`，作为下一批修复的直接基线。

### 实际变更

- 领域与业务逻辑：OpenAlex Topic ID 统一为裸大写 ID；落库结果以 `IngestOutcome` 明确区分成功、未匹配和精确身份冲突。
- 数据与基础设施：相对时间缓存键加入起止日期；空摘要读写统一为 `null`；损坏必填时间显式失败；同步报告新增 `conflicts`；JSON/HTTP JSON 根节点统一受控校验。
- 界面与交互：无计划改动。
- 测试与工具：新增 DB mapper、normalization、policy 独立测试，并扩展缓存、pipeline 和 source 回归。
- 文档：本台账已记录实现、验证、兼容性和检查点。

### 兼容性与迁移

- 本地数据迁移：无需 schema 迁移；带时间范围的旧缓存页不会再命中，新请求会按具体窗口生成新键；不限时间缓存键保持不变。
- API 或领域契约变化：内部 `PipelineRepository.ingest` 从 `str | None` 改为 `IngestOutcome`，两个调用点已同步；同步报告向后兼容地新增 `conflicts` 整数字段。
- 旧版本兼容性：无持久化 schema 破坏；旧空 Abstract 在读取时也恢复为 `null`。

### 已知风险与回滚

- 已知风险：本批自动化门禁无已知失败；按编排者要求不做人工验收，且本修复链不执行合入 `main` 后的双目标构建。
- 回滚方式：在修复链分支上对 `5ea6778` 执行 `git revert`；无数据 schema 回滚步骤。

### 文档更新建议

- 本批是既有能力正确性加固，不预期改变 `docs/development.md` 的功能状态；最终以实现证据为准。

### 未完成与后续工作

- 报告其余结构、复杂度、日志、建模、重复代码、死代码、测试缺口、推荐规格和性能问题按串联 worktree 逐批处理。

## 合并归档

> 编排者明确要求本修复链不合入 `main`，因此本节当前不适用；不预填集成提交、合并时间或 main 验证。

- 最终状态：未合并，保留在修复链分支
- 合入分支：不适用
- 最终集成提交：不适用
- Pull Request：不适用
- 合并时间：不适用
- main 集成验证：不适用
- 开发计划更新：本批不改变功能路线图状态
- 最终后续项：后续 worktree 以前一批修复分支最终提交为基线继续
