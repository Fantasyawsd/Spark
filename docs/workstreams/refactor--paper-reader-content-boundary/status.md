# 论文阅读卡片内容边界任务台账

> 状态：已合并
> 合并归档：实现提交已随审计串行批次合入 main（2026-08-13 至 2026-08-14）；合并后 flutter analyze 无问题、flutter test 582 项通过、Windows 开发版人工验收通过，批次集成记录见 audit--deepseek-report-final 台账。
> 最近更新：2026-08-14

## 目标

从 `PaperReaderCard` 提取无状态标签内容、空态、AI 入口和跨平台标题文本组件，使卡片文件聚焦页面编排、标签状态、Controller 生命周期与导航动作。

## 非目标

- 不再次修改已由前序任务收口的 Controller 生命周期规则。
- 不改变标签顺序、文案、布局尺寸、ValueKey 或用户交互。
- 不调整翻译、关键词生成或 ChatPaper 业务行为。
- 不进行客户端人工验收，不合入 `main`。

## 分支与基线

- 分支：`refactor/paper-reader-content-boundary`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-42`
- 基线：`a0efaa9`

## 验收标准

- [x] `paper_reader_card.dart` 不再定义无状态标签内容和通用空态组件。
- [x] 标签内容、AI 入口和标题选择行为保持不变。
- [x] 阅读卡片生命周期和页面交互回归测试通过。
- [x] 完整 `/test` 与只读 `/review` 通过。

## 写入范围

- `lib/src/features/papers/presentation/widgets/paper_reader_card.dart`
- `lib/src/features/papers/presentation/widgets/paper_reader_content.dart`
- `test/paper_reader_content_test.dart`
- `docs/workstreams/refactor--paper-reader-content-boundary/status.md`

## 实施计划

1. 提取无状态内容与跨平台标题组件。
2. 让阅读卡片只保留组合和行为编排。
3. 补充组件级测试并运行阅读卡片定向回归。
4. 完成完整门禁、只读审查和原子提交。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter pub get` | 通过 | 2026-08-14 |
| `flutter test test/paper_reader_content_test.dart test/paper_reader_view_test.dart test/ui_preview_test.dart` | 通过，共 30 项 | 2026-08-14 |
| `.\tool\verify_changed_dart_format.ps1 -BaseRevision a0efaa9` | 通过，检查 3 个 Dart 文件 | 2026-08-14 |
| `flutter analyze` | 通过，无问题 | 2026-08-14 |
| `flutter test` | 通过，共 577 项 | 2026-08-14 |
| `git diff --check` | 通过 | 2026-08-14 |

## 审查结论

只读审查通过：阻断项 0、缺陷 0、建议 0。移动前后 ValueKey、文案、尺寸、颜色与回调分支一致；`PaperReaderCard` 从 621 行降至 389 行，已验证的 Controller 生命周期逻辑未修改。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `7558ed6` | `重构（论文阅读）：拆分卡片内容组件` | `/develop`、`/test`、`/review` | 定向测试 30 项、格式检查、静态分析和全量测试 577 项均通过；只读审查无发现 |
