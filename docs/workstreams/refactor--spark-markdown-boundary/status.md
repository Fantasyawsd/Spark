# 推荐信号归一化边界任务台账

> 状态：已合并
> 合并归档：实现提交已随审计串行批次合入 main（2026-08-13 至 2026-08-14）；合并后 flutter analyze 无问题、flutter test 582 项通过、Windows 开发版人工验收通过，批次集成记录见 audit--deepseek-report-final 台账。
> 最近更新：2026-08-14

## 目标

让推荐质量与趋势信号在同一年龄桶内按论文 subject 分组归一化，避免不同领域的信号分布互相污染。

## 非目标

- 不修改外部数据源的速度信号计算方式；当前仓库没有生成速度分母的逻辑。
- 不处理报告中已经修复的摘要、时间和 OpenAlex topic 数据契约问题。
- 不进行客户端人工验收，不合入 `main`。

## 分支与基线

- 分支：`refactor/spark-markdown-boundary`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-16`
- 基线：`3f6bb8f49f2ffc893376932619c9f8a05690ee10`

## 验收标准

- [x] 同年龄桶内不同 subject 的论文不参与彼此的信号分布计算。
- [x] 多 subject 论文可与任一共同 subject 的候选比较；无 subject 论文保持独立 unknown 组。
- [x] 现有推荐行为与确定性测试保持通过，并新增跨 subject 回归测试。
- [x] 完整 `/test` 与只读 `/review` 通过。

## 写入范围

### 独占路径

- `server/spark_papers/recommendation.py`
- `server/tests/test_recommendation.py`
- `docs/workstreams/refactor--spark-markdown-boundary/status.md`

### 共享路径

- 无。

## 实施计划

1. 抽取 subject 分组键并接入单篇及批量归一化路径。
2. 增加跨 subject、无 subject 和多 subject 回归测试。
3. 运行服务端测试、格式检查与完整 Flutter 门禁，完成只读审查记录。

## 当前进度

- 已完成：复核报告条目，确认摘要/时间/topic 问题已修复；确认推荐归一化仍只按年龄桶。
- 正在进行：执行完整验证门禁。
- 下一步：记录审查结论并提交。
- 阻塞项：无。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `$env:PYTHONPATH='server'; python -m unittest discover -s server/tests` | 通过（65 项） | 2026-08-13 |
| `flutter pub get` | 通过 | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1` | 通过（126 个文件） | 2026-08-13 |
| `flutter analyze` | 通过 | 2026-08-13 |
| `flutter test` | 通过（553 项） | 2026-08-13 |
| `git diff --check` | 通过 | 2026-08-13 |

## 审查结论

只读审查结论：阻断项 0，缺陷 0，建议 0。变更限定于推荐信号归一化及其回归测试；年龄桶与 freshness 逻辑保持不变，服务端 65 项、Flutter 553 项测试和静态门禁均通过。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `1960692` | 修复（推荐）：按主题分组归一化信号 | 开发与定向验证 | 服务端 65 项、Flutter 553 项、格式与 analyze 通过 |
