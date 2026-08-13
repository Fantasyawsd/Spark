# 任务台账

## 基本信息

- 任务：建立隐私安全的运行时诊断边界并消除异常吞没
- 关联发布或里程碑：DeepSeek 代码分析报告问题 #5 修复，不绑定发布版本
- 分支：`fix/runtime-diagnostics`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-6`
- 基线提交：`4474bcffd8a1e9c49baba0be9bfe1b7398d35c5c`
- 负责人：Fantasy（编排者）
- 状态：规划中
- 最近更新：2026-08-13 17:17

## 目标

为 Flutter 客户端与 Paper API 服务端建立可测试、隐私安全的运行时诊断边界；在保留离线优先、取消、缓存 best-effort 和用户友好错误提示的前提下，让所有被最终消费的意外异常携带固定操作标识、异常类型和 stack trace 进入诊断通道，消除生产故障无根因证据的问题。

## 非目标

- 不记录 DeepSeek API Key、Authorization header、提示词、论文正文、聊天内容、原始请求/响应、完整查询参数或数据文件内容。
- 不把预期的格式探测失败、用户取消、已持久化的坏记录拒绝和已转换后继续上抛的异常重复记录为故障。
- 不改变论文 Feed、搜索、PDF、ChatPaper、本地存储和同步管线的用户可见降级语义。
- 不引入远程日志 SaaS、遥测上传、用户标识或新的服务端部署能力。
- 不处理 DeepSeek 报告中的其他问题；后续批次继续基于本任务最终审查提交串联创建 worktree。
- 不合入 `main`，不启动 Windows App，也不进行人工验收。

## 验收标准

- [ ] 客户端提供跨 feature 复用、可替换测试 sink 的诊断接口；默认输出只包含固定 operation、severity、异常运行时类型和 stack trace，不调用异常 `toString()`，不接受任意上下文 payload。
- [ ] Flutter framework、platform/async 顶层未处理错误进入同一诊断边界，并保持 Flutter 默认错误呈现与进程级错误传播契约。
- [ ] `lib/` 内现有 25 处匿名 `catch (_)` 与 16 处无绑定变量的 `on Object` 完成逐项分类：最终消费的意外异常被报告；预期控制流或已继续上抛路径有明确代码语义且不产生重复日志。
- [ ] Feed、搜索、离线仓储、缓存、本地 JSON、PDF、聊天持久化与展示操作的既有 fallback/错误提示不变，并由定向回归覆盖诊断事件和业务结果。
- [ ] 服务端使用 Python 标准 logging 在 HTTP/CLI/同步边界记录安全的操作事件与 stack trace；已写入同步报告或拒绝计数的预期数据问题不泄露原始记录。
- [ ] Paper API 未预期异常返回固定 `internal_error` 响应，不再向客户端暴露底层异常文本；400 参数错误契约保持不变。
- [ ] 客户端与服务端隐私回归证明密钥、提示词、论文/聊天内容、请求查询和原始数据不会进入捕获的诊断文本。
- [ ] 静态门禁禁止新增匿名 broad catch；Dart 格式检查、`flutter analyze`、Flutter 全量测试、服务端全量测试、Python 编译和 `git diff --check` 通过。

## 写入范围

### 独占路径

- `lib/src/core/diagnostics/`
- `test/runtime_diagnostics_test.dart`
- `server/spark_papers/diagnostics.py`
- `server/tests/test_diagnostics.py`
- `docs/workstreams/fix--runtime-diagnostics/status.md`

### 共享路径

- `lib/main.dart`、`lib/src/app/`：仅接入客户端顶层诊断边界。
- `lib/src/core/storage/local_json_store.dart`：仅补原子写恢复失败的诊断，不改变恢复顺序。
- `lib/src/features/{papers,search,chat,local_data}/`：仅改造最终消费异常的 catch 与对应测试，不重构业务职责。
- `test/architecture_boundaries_test.dart`：仅增加匿名 broad catch 静态门禁。
- `server/spark_papers/{api,cli,pipeline,dataset,storage,sources}.py`：仅补进程/请求/同步边界诊断和响应脱敏，不改变数据契约与同步算法。
- `server/tests/`：仅增加诊断、脱敏及既有错误契约回归。

## 依赖关系

- 上游任务：`refactor/follow-state-single-source@4474bcffd8a1e9c49baba0be9bfe1b7398d35c5c`，以及此前串联完成的报告问题修复批次。
- 外部接口或数据源：无；所有诊断与错误路径使用 fake、临时目录和本地测试服务验证。

## 实施计划

1. 增加客户端隐私安全诊断模型、默认 sink、测试捕获能力和顶层未处理错误接线。
2. 按“最终消费 / 预期控制流 / 转换后上抛”分类改造客户端 broad catch，先覆盖 Feed、搜索、离线仓储和本地存储，再覆盖 PDF、ChatPaper 与展示操作。
3. 增加服务端标准 logging 配置与 HTTP/CLI/同步边界事件，固定 500 响应并避免记录数据型动态值。
4. 补齐业务结果、事件字段、stack trace、去重和隐私脱敏回归，并增加匿名 broad catch 静态门禁。
5. 执行定向验证，更新台账并形成原子实现提交；随后按 `/test` 与 `/review` 阶段完成全量门禁和只读审查。

## 当前进度

- 已完成：读取强制文档、原分析报告及 Paper API、真实数据导入、历史稳健性修复台账。
- 已完成：基于 agent-5 最终审查提交创建 `fix/runtime-diagnostics` 与 `agent-6`，确认 `main` 保持 `5578a77d12dd3779940d2352d216e1f766ab47fa`。
- 已完成：扫描确认客户端存在 25 处匿名 catch、16 处无绑定 broad catch，服务端业务包存在 35 处 exception handler；现有客户端无顶层诊断接线，服务端无标准 logging 调用。
- 正在进行：固化问题分类、验收条件与独占/共享写入边界。
- 下一步：等待编排者触发 `/develop`，从客户端诊断核心与隐私测试开始实现。
- 阻塞项：无。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-13 | 基于 `agent-5@4474bcf` 串联创建 agent-6，不以 `main` 为基线 | 编排者要求每批修复继承上一批最终结果且不合入 main | 本批包含前五批全部修复；main 保持不变 |
| 2026-08-13 | 只在异常被最终消费的边界记录，转换后上抛不重复记录 | 避免同一故障多层重复日志，同时保留根因 stack trace | 每个 catch 必须明确属于最终消费、预期控制流或继续传播之一 |
| 2026-08-13 | 诊断事件拒绝任意 payload 和异常文本，只接受固定 operation、异常类型与 stack trace | 根因可追踪不能以泄露 BYOK、请求内容或论文/聊天数据为代价 | 测试 sink 与默认 sink 使用相同的最小事件模型 |
| 2026-08-13 | HTTP 500 使用固定客户端消息，详细根因只进入服务端诊断 | 当前实现把 `str(error)` 返回给客户端，可能暴露数据库或本机信息 | 500 契约更安全；400 仍返回可操作的参数错误 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| 强制文档、原报告与重叠台账读取 | 通过；确认报告问题 #5 仍成立，且不得记录 BYOK/内容型数据 | 2026-08-13 |
| `rg` 客户端异常扫描 | 25 处匿名 catch、16 处无绑定 `on Object`；需在实现阶段逐项分类 | 2026-08-13 |
| `rg` 服务端异常与日志扫描 | 业务包 35 处 handler；同步失败已有结构化报告/计数，但 HTTP 防御边界会暴露异常文本且全包无标准 logging | 2026-08-13 |
| Git/worktree 预检 | 控制工作树与 agent-5 干净；目标分支和 `agent-6` 未占用；基线为 `4474bcf` | 2026-08-13 |

## 审查结论

> 由 `/review` 填写摘要（阻断项、缺陷、结论）。

- 审查日期：
- 阻断项：
- 缺陷：
- 结论：可合并 / 需修复 / 需重新审查

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |

## 交付准备（合并前收集）

### 交付摘要

待实现与验证后填写。

### 实际变更

- 领域与业务逻辑：待填写。
- 数据与基础设施：待填写。
- 界面与交互：待填写。
- 测试与工具：待填写。
- 文档：待填写。

### 兼容性与迁移

- 本地数据迁移：无。
- API 或领域契约变化：Paper API 500 错误消息计划固定化；其他 API/领域契约不变。
- 旧版本兼容性：不改变持久化 schema。

### 已知风险与回滚

- 已知风险：诊断不足会遗漏根因，诊断过度会产生重复事件或泄露动态数据；以事件模型和隐私回归共同约束。
- 回滚方式：按实现与台账提交逆序 `git revert`；不涉及数据迁移或远程状态。

### 文档更新建议

- 本任务属于结构性技术债修复，不改变产品路线图能力；不计划修改 `docs/development.md`。

### 未完成与后续工作

- DeepSeek 报告的后续未修复项由新的串联 worktree 继续处理。

## 合并归档（合并后在 main 补齐）

> 编排者明确要求本任务不合入 `main`；本节保持未填写，不执行 `/finish`。

- 最终状态：未合并
- 合入分支：不适用
- 最终集成提交：不适用
- Pull Request：无
- 合并时间：不适用
- main 集成验证：不适用
- 开发计划更新：不适用；本任务仅修复结构性技术债
- 最终后续项：完成 `/test` 与 `/review` 后，以最终审查提交为下一批 worktree 基线
