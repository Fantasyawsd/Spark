# 任务台账

> 单文件任务台账，由 `/start` 创建、`/develop` 与后续工作流持续更新。

## 基本信息

- 任务：调整中文摘要重新翻译操作的位置
- 关联发布或里程碑：不绑定发布版本；论文阅读体验修复
- 分支：`fix/summary-translation-action-layout`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\fix--summary-translation-action-layout`
- 基线提交：`75dc0aa4c89048401ad3a8f98ae68f95c6ec54a1`
- 负责人：Codex
- 状态：待审查
- 最近更新：`2026-08-12 00:22`

## 目标

中文摘要已生成后，将“重新翻译”操作放到摘要内容区左下角，并与右侧“展开全文”处于同一水平操作栏。

## 非目标

- 不改变中文摘要生成、取消、缓存或重新翻译的业务逻辑。
- 不调整 Abstract、关键词、作者、AI 解读或相关论文页面布局。
- 不改变全文阅读页与底部论文互动操作栏。

## 验收标准

- [x] 中文摘要溢出时，“重新翻译”显示在左侧，“展开全文”显示在右侧，两个操作垂直居中对齐。
- [x] 中文摘要未溢出时，“重新翻译”仍位于内容区底部操作栏，且不显示“展开全文”。
- [x] 翻译进行中时，同一位置显示“停止”，原有取消行为保持不变。
- [x] 378 像素宽视口无布局溢出，相关 Widget 测试通过。

## 写入范围

### 独占路径

- `lib/src/features/papers/presentation/widgets/paper_translation_content.dart`
- `lib/src/features/papers/presentation/widgets/paper_tab_body.dart`
- `test/ui_preview_test.dart`
- `docs/workstreams/fix--summary-translation-action-layout/status.md`

### 共享路径

- 无。

## 依赖关系

- 上游任务：已合并的论文阅读 MVP。
- 外部接口或数据源：无。

## 实施计划

1. 在现有论文阅读 Widget 测试中增加摘要底部操作栏位置断言，先验证旧布局失败。
2. 让 `PaperTabBody` 支持左侧底部操作，并由中文摘要组件传入重新翻译/停止按钮。
3. 运行定向 Widget 测试、格式检查、静态分析和完整测试套件，记录结果并提交原子改动。

## 当前进度

- 已完成：完成两轮 TDD 红绿循环、双轴审查修复、短摘要与刷新等待态覆盖；编排者已在 Windows 应用中人工验收通过。
- 正在进行：无。
- 下一步：等待编排者触发后续 `/test` 验证门禁。
- 阻塞项：无。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-11 | 复用 `PaperTabBody` 的底部操作区域承载重新翻译 | 展开操作的显示条件和底部高度由该组件掌握，可保证两个操作共用同一行 | 仅新增可选左侧操作，不改变其他论文页签的默认布局 |
| 2026-08-11 | 空正文生成态也保留左下角停止操作 | 重新翻译会在首个流式片段到达前暂时清空正文，若复用居中空状态会造成操作位置跳动 | 初次生成及重新翻译等待态统一在底部显示停止，取消逻辑不变 |
| 2026-08-11 | 发布版 APK 与 Windows 构建留给后续验证门禁 | 当前仅执行用户触发的 `/develop`，项目工作流不允许自行跨入 `/test` 或 `/finish` | 台账不声称合并门禁完成；进入后续阶段时按 AGENTS.md §10 构建并记录产物证据 |
| 2026-08-12 | Windows 验收使用临时短路径目录联接 | 原 worktree 的 MSBuild 中间产物路径恰好达到 260 字符，直接构建无法写入 `.tlog`；`subst` 又被 Flutter/CMake 错误解析 | 使用 `accept-link` 指向同一 worktree 完成启动；验收后关闭进程并删除联接，未复制或修改任务源文件 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `D:\App\flutter\bin\flutter.bat --version` | Flutter 3.44.8、Dart 3.12.2，与项目环境一致 | 2026-08-11 |
| `flutter test test/ui_preview_test.dart --plain-name "long Chinese interpretation can open the full reader"`（实现前） | 按预期失败：重新翻译与展开全文中心线相差 326 像素 | 2026-08-11 |
| 同一定向 Widget 测试（实现后） | 通过，重新翻译位于左侧且与展开全文中心线对齐 | 2026-08-11 |
| `flutter test test/paper_reader_view_test.dart` | 2 项通过 | 2026-08-11 |
| `flutter test test/ui_preview_test.dart` | 25 项通过 | 2026-08-11 |
| `.\tool\verify_changed_dart_format.ps1` | 3 个变更 Dart 文件格式检查通过 | 2026-08-11 |
| `flutter analyze` | 通过，No issues found | 2026-08-11 |
| `flutter test` | 407 项完整测试通过 | 2026-08-11 |
| `git diff --check` | 通过 | 2026-08-11 |
| `flutter test test/ui_preview_test.dart --plain-name "translation action stays bottom-left while refreshing"`（审查修复前） | 按预期失败：重新翻译等待态找不到底部操作 | 2026-08-11 |
| 同一定向 Widget 测试（审查修复后） | 通过，覆盖短摘要、刷新等待态底部停止及取消 | 2026-08-11 |
| `flutter test test/ui_preview_test.dart`（审查修复后） | 26 项通过 | 2026-08-11 |
| `.\tool\verify_changed_dart_format.ps1`（审查修复后） | 3 个变更 Dart 文件格式检查通过 | 2026-08-11 |
| `flutter analyze`（审查修复后） | 通过，No issues found | 2026-08-11 |
| `flutter test`（审查修复后） | 408 项完整测试通过 | 2026-08-11 |
| 合并前发布版 APK 与 Windows 构建 | 当前 `/develop` 阶段未运行；由后续 `/test`、`/finish` 按 AGENTS.md §10 执行 | 2026-08-11 |
| `flutter pub get` + `flutter run -d windows --dart-define=SPARK_ENV=development` | 依赖获取通过；经临时短路径目录联接成功构建并启动 `Spark` Windows 应用，编排者人工检查重新翻译/停止位置及展开全文后确认通过 | 2026-08-12 |
| 验收环境清理 | 已关闭本次 `spark.exe` 进程并删除 `accept-link` 目录联接；真实任务 worktree 存在且 Git 状态干净 | 2026-08-12 |

## 审查结论

> 由 `/review` 填写摘要（阻断项、缺陷、结论）。

- 审查日期：
- 阻断项：
- 缺陷：
- 结论：待审查

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `f8072bd` | `修复（论文）：对齐摘要底部操作` | 首轮实现 | 格式、analyze、定向 UI 与 407 项完整测试通过；双轴审查发现刷新等待态位置跳动和覆盖不足 |
| `fff086c` | `修复（论文）：保持翻译操作位置稳定` | 审查修复 | 覆盖短摘要、刷新等待态底部停止与取消；格式、analyze、26 项 UI 预览和 408 项完整测试通过 |

## 交付准备（合并前收集）

### 交付摘要

中文摘要已生成后，“重新翻译”从正文右上方移动到内容区左下角，并与右侧“展开全文”共用同一水平操作栏。

### 实际变更

- 领域与业务逻辑：无。
- 数据与基础设施：无。
- 界面与交互：`PaperTabBody` 支持可选左侧底部操作；摘要页将重新翻译/停止按钮传入该区域，生成进度仍保留在正文上方。
- 测试与工具：增加 378 像素宽长摘要同排断言，以及短摘要、刷新等待态底部停止和取消覆盖；定向与 408 项完整测试通过。
- 文档：维护本任务台账。

### 兼容性与迁移

- 本地数据迁移：无。
- API 或领域契约变化：无。
- 旧版本兼容性：无影响。

### 已知风险与回滚

- 已知风险：窄屏操作栏宽度及短摘要无展开按钮时的底部占位。
- 回滚方式：回退本任务提交即可，无数据影响。

### 文档更新建议

- 本任务为既有论文阅读界面的局部布局修复，不改变 `docs/development.md` 中的能力状态。

### 未完成与后续工作

- 无。

## 合并归档（合并后在 main 补齐）

> 任务尚未合入 `main`；最终集成提交、时间和集成验证由 `/finish` 在合并后填写。

- 最终状态：待合并后填写
- 合入分支：`main`
- 最终集成提交：待合并后填写
- Pull Request：无
- 合并时间：待合并后填写
- main 集成验证：待合并后填写
- 开发计划更新：本任务不改变开发计划中的能力状态
- 最终后续项：无
