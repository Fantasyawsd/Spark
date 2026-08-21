# 任务台账

## 基本信息

- 任务：`side-chat-boundaries`（修复 side chat 功能的架构边界违规）
- 分支：`fix/side-chat-boundaries`
- Worktree：`../agent-1`
- 基线提交：`c1644f2`（main）
- 负责人：编排者（人类）+ Claude Code Agent
- 状态：开发中
- 最近更新：2026-08-21 20:05

## 目标

清偿界面焕新集成验证时溯源出的 side chat 功能基线问题（提交 ba76034/8407fa5 引入）：

1. `main_ai_chat_screen.dart:67/179` 两处裸 `on Object` 捕获（违反
   architecture_boundaries_test 的 no anonymous broad catch）。
2. presentation 直接依赖本 feature data 层
   （main_ai_chat_screen → side_chat_dismiss_preference_store，违反 layers only depend inward）。
3. `side_chat_test.dart:175` 空 catch 块（analyze empty_catches info）。

## 非目标

- 不改 side chat 功能行为；不重构其他模块。

## 验收标准

- [x] 架构边界测试全部通过；analyze 无任何问题（含原 info）。
- [x] 全量测试 624 项通过。

## 实施方案

按仓库分层惯例走「domain 抽象 + application 服务 + 组合根注入」：

1. domain 新增 `SideChatDismissPreference` 接口；data store implements 之。
2. application 新增 `SideChatDismissPreferenceController`：注入抽象，
   读写失败经 SparkDiagnostics 上报（新增 chatSideChatPreferenceLoad/Save
   操作枚举，warning 级）并降级（load 失败返回 false / save 静默），
   不再向上抛异常。
3. presentation 改依赖 controller（参数必选，去除自建默认与 try/catch）。
4. 组合根 spark_dependencies 装配 store+controller，spark_shell 注入。
5. 测试：空 catch 加注释与变量；三处注入点改 mock controller；
   另两个测试文件补 `_NoopSideChatPreference` 注入。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-21 | 异常在 application 层消化并上报 diagnostics，而非改用具体异常类型 | LocalJsonStore 失败类型开放（IO/JSON 等），逐类型列举脆弱；仓库已有 SparkDiagnostics 门禁要求运行时异常走该通道 | screen 无需 try/catch |
| 2026-08-21 | MainAiChatScreen 参数改必选并经组合根注入 | 自建默认会重新引入 presentation→data 违规；生产/测试调用点各一处可控 | spark_shell 与三个测试文件同步更新 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| flutter analyze | 无任何问题（含原 empty_catches info 清零） | 2026-08-21 |
| flutter test | 624 项全部通过（含 architecture_boundaries_test 两项恢复绿色） | 2026-08-21 |
| tool/verify_changed_dart_format.ps1 | 通过 | 2026-08-21 |

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |

## 合并归档（合并后在 main 补齐）

- 最终状态：
- 合入分支：
- 最终集成提交：
- 合并时间：
- main 集成验证：
- 开发计划更新：
- 最终后续项：
