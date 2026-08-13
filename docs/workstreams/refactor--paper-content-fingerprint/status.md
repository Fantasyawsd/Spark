# 论文内容指纹边界重构任务台账

> 状态：开发中
> 最近更新：2026-08-13 20:53

## 1. 任务信息

| 项目 | 内容 |
| --- | --- |
| 目标 | 集中翻译与关键词缓存共用的论文内容 FNV-1a 指纹算法，同时保持现有指纹值和缓存 freshness 语义不变。 |
| 非目标 | 不改变 prompt、prompt version、缓存 schema、输入字段或哈希算法；不处理其他报告问题；不合入 `main`，不进行人工桌面验收。 |
| 分支 | `refactor/paper-content-fingerprint` |
| worktree | `C:\Users\Fantasy\Desktop\Spark-worktrees\agent-11` |
| 基线 | `406433282ee5c65205dd78283cf49372bc1cdf9a`（上一批 `refactor/paper-copy-boundary` 最终审查提交） |
| 负责人 | Fantasy（编排）；Codex（执行） |
| 当前阶段 | `/develop` |

## 2. 问题与边界

`paper_translation_service.dart` 与 `paper_keyword_service.dart` 各自逐字实现相同的 UTF-8 + FNV-1a 64 位哈希循环，仅命名空间分隔符不同。算法修复或演进需要同步修改两处，容易导致缓存语义漂移。本批把机制集中到论文 application 层，调用方只提供用途命名空间。

## 3. 验收标准

1. FNV-1a 循环只在一个 application 文件中实现。
2. 翻译与关键词指纹继续使用标题、对应命名空间和原始 Abstract，trim 语义不变。
3. 迁移前后的固定输入指纹值完全一致，不使现有缓存失效。
4. 两类 freshness 判断和控制器缓存行为保持通过。
5. 定向测试、`flutter analyze`、格式门禁和 `/test` 全量门禁全部通过。

## 4. 写入范围

### 独占路径

- `lib/src/features/papers/application/paper_content_fingerprint.dart`
- `lib/src/features/papers/application/paper_translation_service.dart`
- `lib/src/features/papers/application/paper_keyword_service.dart`
- `test/paper_content_fingerprint_test.dart`
- 现有翻译与关键词测试
- 本台账

### 共享路径

- 无；本批串行基于上一批最终审查提交创建。

## 5. 实施计划

1. 用固定兼容向量锁定两类现有指纹值与命名空间隔离。
2. 提取共用论文内容指纹函数，迁移翻译与关键词调用点。
3. 运行定向测试、analyze 和格式检查，形成原子实现提交。
4. 执行 `/test` 全量门禁和 `/review` 只读审查，记录最终串行基线。

## 6. 当前进度

- 已完成：确认两处 FNV-1a 实现逐字重复，且业务差异仅为命名空间。
- 已完成：FNV-1a 循环已集中到 `paper_content_fingerprint.dart`，翻译与关键词包装函数只传入原命名空间。
- 已完成：英文与中文固定向量锁定旧 Dart 有符号十六进制输出；21 项 freshness 与控制器测试通过。
- 正在进行：形成 `/develop` 原子实现提交。
- 下一步：执行完整 `/test`，再进入只读 `/review`。
- 阻塞项：无。

## 7. 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-13 | 公共函数接收完整命名空间分隔符，而不自行拼接业务名称。 | 兼容值必须逐字保持，调用点显式表达缓存用途。 | 现有 `|spark-translation|` 与 `|spark-keywords|` 输入不变。 |
| 2026-08-13 | 固定向量保留 Dart 64 位有符号十六进制输出，包括最高位为 1 时的负号。 | 旧实现即按该形式写入缓存；改成无符号十六进制会造成部分缓存无故失效。 | 公共实现只消除重复，不修订历史指纹格式。 |

## 8. 验证记录

| 时间 | 阶段 | 命令或检查 | 结果 |
| --- | --- | --- | --- |
| 2026-08-13 20:53 | `/develop` | `flutter test test\paper_content_fingerprint_test.dart test\paper_translation_test.dart test\paper_keyword_test.dart test\paper_chat_context_loader_test.dart` | 通过，共 21 项；英文/中文固定向量、命名空间隔离、freshness、持久化和 ChatPaper 上下文行为保持通过。 |
| 2026-08-13 20:53 | `/develop` | `flutter analyze` | 通过，无问题。 |
| 2026-08-13 20:53 | `/develop` | `.\tool\verify_changed_dart_format.ps1` | 通过，共检查 117 个变更相关 Dart 文件。 |
| 2026-08-13 20:53 | `/develop` | `git diff --check` 与 FNV 常量搜索 | 通过；FNV offset/prime 循环只保留一份。 |

## 9. 审查与交付

- 审查范围：待实现提交后填写。
- 阻断项：待审查。
- 缺陷：待审查。
- 审查结论：待审查。
- 兼容性：固定指纹值、缓存 schema 和 prompt version 保持不变。
- 风险：命名空间或 trim 顺序变化导致全量缓存失效；由固定兼容向量锁定。
- 回滚：按原子提交回滚，不触碰 `main`。

## 10. 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
