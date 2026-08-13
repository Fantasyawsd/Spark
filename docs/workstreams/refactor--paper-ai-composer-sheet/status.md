# 拆分论文 AI Composer 设置面板任务台账

> 状态：待审查
> 最近更新：2026-08-13

## 目标

将 `PaperAiComposer` 的模型/思考强度底部面板与滑块绘制逻辑提取到独立模块，缩短 Composer 主 build 和 State 职责范围，保持现有交互契约。

## 非目标

- 不改变输入框、工具栏按钮、推理选项值和回调语义。
- 不处理 ChatScreen 其他职责拆分。
- 不进行客户端人工验收，不合入 `main`。

## 分支与基线

- 分支：`refactor/paper-ai-composer-sheet`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-25`
- 基线：`2f332e4`

## 验收标准

- [x] Composer 不再内联模型和思考强度 sheet。
- [x] 现有 key、推理强度更新和模型展示行为保持不变。
- [x] Composer 定向测试、完整格式、分析和全量测试通过。
- [x] 只读审查无阻断项。

## 实施计划

1. 提取 `paper_ai_composer_sheets.dart`，集中管理两个 sheet 和 slider track。
2. Composer 委托 sheet 展示，运行完整门禁。
3. 完成台账审查记录并提交。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `dart format` | 通过 | 2026-08-13 |
| `flutter test test/paper_ai_composer_test.dart` | 通过（6 项） | 2026-08-13 |
| `flutter analyze` | 通过 | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1` | 通过（138 个文件） | 2026-08-13 |
| `flutter test` | 通过（554 项） | 2026-08-13 |
| `git diff --check` | 通过 | 2026-08-13 |

## 审查结论

只读审查结论：阻断项 0，缺陷 0，建议 0。设置面板、滑块绘制和选项标签仅移动到独立模块；Composer 保留按钮 key、回调和输入布局。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
