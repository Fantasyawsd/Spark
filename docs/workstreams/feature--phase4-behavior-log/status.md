# Phase 4.1 行为事件日志契约与本地采集任务台账

> 状态：待合并
> 最近更新：2026-08-14

## 目标

建立无账号阶段的设备本地行为日志基础设施（隐私边界：日志不离开设备，后续 4.3 仅上送聚合画像）：

1. 新建 `lib/src/features/behavior/` 模块：事件模型（类型/论文 ID/时间/上下文）与校验。
2. 本地存储：`VersionedLocalJsonStore` 持久化，保留期滚动清理（默认 90 天）与条目上限（默认 10000）；损坏隔离沿用现有机制。
3. 同意门控：`BehaviorLogger` 读取同意开关（默认开启），关闭即停止采集；提供清除接口（隐私删除边界）。
4. 埋点接入：论文打开、点赞、收藏三类事件接入现有控制器；组合根注入。
5. 纯 Dart 单测：事件校验、存储读写、保留期清理、上限裁剪、同意门控、清除。

## 非目标

- 不上送任何原始行为到服务端（4.3 只上送聚合画像）。
- 不实现画像聚合（4.2）。
- 不做隐私设置 UI（4.7）。

## 分支与基线

- 分支：`feature/phase4-behavior-log`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-1`
- 基线：`51be307`
- 负责人：Fantasy（编排者，目标迭代授权）；执行：DeepSeek Agent

## 验收标准

- [x] 事件模型与存储单测通过（含保留期/上限/门控/清除）
- [x] 三类埋点在真实代码路径调用 logger
- [x] 组合根注入无循环依赖（papers 经 behavior 公开入口依赖 domain 端口）
- [x] `flutter analyze` 无问题、`flutter test` 全量通过（594 项）

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter test test/behavior_logger_test.dart` | 6 项通过 | 2026-08-14 |
| `flutter analyze` | No issues found | 2026-08-14 |
| `flutter test`（全量） | 594 项通过（含架构门禁） | 2026-08-14 |

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 待提交 | `新增（行为）：设备本地行为事件日志与同意门控` | 实现 | analyze 无问题、594 项通过 |

## 审查结论

只读审查：behavior 模块分层正确（application 仅依赖 domain 端口，data 实现经组合根注入）；papers 经 public entry 依赖 behavior domain 端口，架构门禁通过；同意关闭停采、清除删除边界、保留期滚动清理与条目上限均有单测。开发期间曾因测试用混合路径分隔符触发既有 LocalJsonStore.clear 不匹配，确认为测试构造问题而非存储缺陷（已在审查时修正）。无阻断项。
