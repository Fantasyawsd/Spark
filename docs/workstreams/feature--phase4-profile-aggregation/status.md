# Phase 4.2 用户画像本地聚合任务台账

> 状态：已合并
> 最近更新：2026-08-14

## 目标

把 4.1 采集的设备本地行为事件聚合为版本化用户画像（仍不离开设备）：

1. `behavior/domain/user_profile.dart`：版本化画像（profile.v1）——主题/关键词/会议偏好权重 Map 与更新时间；JSON 往返。
2. `application/profile_aggregator.dart`：纯函数聚合——打开（隐式，+0.5）、点赞（显式，+2.0）、收藏（显式，+1.5），时间衰减（30 天半衰指数）；paper 元数据经解析回调获取主题/内容关键词/会议。
3. `data/file_profile_store.dart`：画像本地持久化（LocalJsonStore）。
4. 组合根接线：应用会话初始化时后台刷新画像。
5. 测试：权重规则、衰减、空事件、JSON 往返、存储。

## 非目标

- 不上送画像到服务端（4.3 契约才定义上送）。
- 不做向量/Embedding（4.4 服务端）。
- 不做隐私设置 UI（4.7）。

## 分支与基线

- 分支：`feature/phase4-profile-aggregation`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-1`
- 基线：`9aed509`
- 负责人：Fantasy（编排者，目标迭代授权）；执行：DeepSeek Agent

## 验收标准

- [x] 聚合权重与时间衰减计算正确（单测）
- [x] 画像 schema 版本化且 JSON 往返一致
- [x] 存储读写与损坏隔离沿用既有机制
- [x] 会话初始化触发后台聚合刷新
- [x] `flutter analyze` 无问题、`flutter test` 全量通过（599 项）

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter test test/profile_aggregator_test.dart` | 5 项通过 | 2026-08-14 |
| `flutter analyze` | No issues found | 2026-08-14 |
| `flutter test`（全量） | 599 项通过（含架构门禁） | 2026-08-14 |

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 待提交 | `新增（行为）：本地聚合版本化用户画像` | 实现 | analyze 无问题、599 项通过 |

## 合并归档

- 合并方式：本地快进合并（`main` `9aed509..707bf3f`）
- 最终集成提交：`707bf3f`
- 合并时间：2026-08-14
- 集成验证（/finish 双目标构建，Windows 已清理 build/windows 重建并核验时间戳）：
  - Windows release：`build/windows/x64/runner/Release/spark.exe`，101,888 bytes，SHA-256 `5CF675333CEE144B80CDCEE4B3581D67207A7C30C364E6A7016D75DAEE52219A`
  - Android development profile：`build/app/outputs/flutter-apk/app-development-profile.apk`，119,671,692 bytes，SHA-256 `099DB050FDF8F9DE4114C2504BA46BE402272498AB56BCC81E504BC6E993F864`
  - Gradle daemon：`--stop` 后无运行中残留
- 真实后续项：4.3 匿名画像推荐请求契约（下一迭代基线）。

## 审查结论

只读审查：ProfileAggregator 纯函数（显式点赞 2.0 / 收藏 1.5 / 隐式打开 0.5，30 天半衰指数衰减）；画像 profile.v1 版本化并 JSON 往返；会话初始化后台刷新；元数据解析当前基于 paperRepository 种子集合（动态论文覆盖随 4.3 契约演进，已在目标外注明）。无阻断项。
