# Composer 构建边界任务台账

> 状态：待审查
> 最近更新：2026-08-13

## 目标

将 `PaperAiComposer` 的工具栏和输入表面拆为独立展示组件，使状态容器只负责 controller 生命周期和组合参数。

## 非目标

- 不改变 Composer 的交互、键值、视觉样式或回调契约。
- 不进行客户端人工验收，不合入 `main`。

## 分支与基线

- 分支：`refactor/paper-ai-composer-build-boundary`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-29`
- 基线：`8914b79`

## 验收标准

- [x] 工具栏与输入表面位于独立组件，主 Composer build 只负责组合。
- [x] 现有 key、回调、禁用/发送状态和视觉行为保持一致。
- [x] Composer 与会话控制器定向测试保持通过。
- [x] 完整 `/test` 与只读 `/review` 通过。

## 实施计划

1. 提取 `PaperAiComposerToolbar` 与 `PaperAiComposerInputSurface`。
2. 用组合组件替换原内联构建树。
3. 运行定向和完整验证，完成只读审查。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter pub get` | 通过 | 2026-08-13 |
| `flutter test test/paper_ai_composer_test.dart test/paper_ai_conversation_controller_test.dart` | 通过（21 项） | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1 -BaseRevision 8914b79` | 通过（2 个文件） | 2026-08-13 |
| `flutter analyze` | 通过，无问题 | 2026-08-13 |
| `flutter test` | 通过（556 项） | 2026-08-13 |
| `git diff --check` | 通过 | 2026-08-13 |

## 审查结论

审查结论：阻断项 0；缺陷 0；建议 0。拆分只移动展示树和私有按钮组件，未改变公开参数、ValueKey、回调条件或布局参数。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 2405434 | 重构（聊天）：拆分 Composer 构建边界 | /develop | 格式、analyze、Flutter 556 项通过 |
