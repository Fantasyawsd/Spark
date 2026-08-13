# PDF 下载边界任务台账

> 状态：待审查
> 最近更新：2026-08-13

## 目标

将 PDF HTTP 下载与 `PaperPdfExtractionService` 的文本提取/isolate 编排拆为独立数据源组件，降低单个服务的基础设施职责密度。

## 非目标

- 不改变下载超时、大小上限、PDF 文件头校验或异常消息。
- 不改变 isolate 提取、分块、缓存版本和调用方接口。
- 不进行客户端人工验收，不合入 `main`。

## 分支与基线

- 分支：`refactor/paper-pdf-download-boundary`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-30`
- 基线：`244118f`

## 验收标准

- [x] HTTP 下载逻辑位于独立 `PaperPdfDownloader`，提取服务只负责解析编排。
- [x] 下载大小、超时、状态码、PDF 头校验和异常映射行为保持一致。
- [x] PDF 提取与缓存现有测试保持通过，并新增下载器纯边界测试。
- [x] 完整 `/test` 与只读 `/review` 通过。

## 实施计划

1. 提取 `PaperPdfDownloader` 及 PDF 头校验。
2. 让提取服务委托下载器，移除 HTTP body 读取细节。
3. 运行定向和完整验证，完成只读审查。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter pub get` | 通过 | 2026-08-13 |
| `flutter test test/paper_pdf_downloader_test.dart test/paper_pdf_test.dart test/cached_paper_pdf_content_provider_test.dart test/paper_ai_chat_app_bar_test.dart` | 通过（31 项） | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1 -BaseRevision 244118f` | 通过（3 个文件） | 2026-08-13 |
| `flutter analyze` | 通过，无问题 | 2026-08-13 |
| `flutter test` | 通过（559 项） | 2026-08-13 |
| `git diff --check` | 通过 | 2026-08-13 |

## 审查结论

审查结论：阻断项 0；缺陷 0；建议 0。下载器独立承担 HTTP client、响应流取消、大小限制、总超时和 PDF 头校验；提取服务保留兼容下载入口并专注 isolate/解析编排，未改变现有调用契约。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 4066757 | 重构（PDF）：拆分下载与提取边界 | /develop | 下载器测试、格式、analyze、Flutter 559 项通过 |
