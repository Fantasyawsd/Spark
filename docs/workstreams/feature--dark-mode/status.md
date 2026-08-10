# 任务台账

> 单文件任务台账，由 `/start` 创建、`/develop` 与 `/test` 持续更新。`/finish` 在任务分支收集合并前交付信息；任务真实合入 `main` 后，再在 `main` 补齐最终合并归档。所有占位内容替换为真实信息。

## 基本信息

- 任务：`暗色模式（WS2）`
- 关联发布或里程碑：无（上游 WS1 `refactor/ui-design-tokens` 已完成；下游 WS3 桌面自适应 `feature/desktop-adaptive` 以本任务为基线）
- 分支：`feature/dark-mode`
- Worktree：`../feature--dark-mode`
- 基线提交：`e1459d2`（WS1 分支头）
- 负责人：编排者 Fantasy；执行 Claude Code Agent
- 状态：开发中（待用户实机验收）
- 最近更新：`2026-08-10 22:20`

## 目标

建立主题感知的调色板体系：新增 `SparkPalette`（ThemeExtension，light/dark 工厂），将现有静态 `SparkColors` 常量收敛为 `SparkColors.of(context)` 门面并迁移全部调用点；新增 `SparkTheme.dark()` 与 `AppThemeMode{system,light,dark}` 持久化；MaterialApp 接线 theme/darkTheme/themeMode；主题设置 sheet 增加「外观」三档；splash 与论文卡封面渐变等白底假设改为主题感知。

## 非目标

- 不实现桌面自适应布局（WS3）。
- 不重新设计暗色视觉细节（暗色初值按计划文件，用户验收后再微调）。
- 不改动 `community`、`messages` 模块的视觉；但若其引用 `SparkColors.` 导致编译断裂，必须一并做机械迁移。
- 不改本地数据结构（theme 偏好 JSON 仅追加 `mode` 键，旧数据缺省视为 system）。
- 不动 `docs/development.md`（/finish 职责）。

## 验收标准

- [x] 新增 `lib/src/core/theme/spark_palette.dart`：字段覆盖原 SparkColors 全部成员，`light()/dark()` 工厂，primarySoft/primaryPale 暗色由 alphaBlend 派生。
- [x] 原静态 `SparkColors` 删除，lib 内全部调用点迁移为 `SparkColors.of(context)`（含 community/messages，若引用）。
- [x] `SparkTheme.dark()` 与 `SparkTheme.light()` 并存，palette 经 `ThemeData.extensions` 注入。
- [x] `AppThemeMode` 持久化于 ThemePreferenceRepository（file/in-memory/测试替身同步），重启后保持。
- [x] `ThemeController` 暴露 mode/setMode，写队列模式与 setColor 一致。
- [x] `spark_app.dart` MaterialApp 接线 theme/darkTheme/themeMode。
- [x] 主题设置 sheet 强调色上方有「外观」三档（跟随系统/浅色/深色）。
- [x] splash 白底与 `paper_grid_card.dart` 封面渐变基色改为主题感知。
- [x] `verify_changed_dart_format.ps1`、`flutter analyze`、`flutter test` 全部通过，含新增 mode 持久化单测、sheet widget 测试、暗色冒烟测试。
- [ ] 用户 Windows 实机验收亮/暗切换。

## 写入范围

### 独占路径

- `lib/src/core/theme/`（新增 spark_palette.dart，改 spark_theme.dart）
- `lib/src/app/`（spark_app.dart）
- `lib/src/features/` 各模块 presentation（SparkColors 调用点迁移）
- 主题设置相关：theme controller / preference repository / spark_theme_sheet
- `test/`（迁移受影响的用例 + 新增暗色测试）
- `docs/workstreams/feature--dark-mode/`

### 共享路径

- `lib/spark.dart`（新增导出，追加式修改）

## 依赖关系

- 上游任务：WS1 `refactor/ui-design-tokens`（头 e1459d2，本任务基线）
- 外部接口或数据源：无
- 并行风险排查（2026-08-10）：main 在 WS1 期间推进至 a768f0a（4 个纯文档提交，含中文提交信息约定 dbc6b08），与本分支无代码重叠；是否 rebase 由编排者决定。

## 实施计划

1. C1 新增 `SparkPalette`，SparkColors 改 `of(context)` 门面，脚本迁移全部调用点（纯重构无行为变化）。
2. C2 `AppThemeMode` 枚举 + 偏好持久化 + ThemeController.mode/setMode + SparkTheme.dark() + MaterialApp 接线。
3. C3 主题设置 sheet 增加「外观」三档。
4. C4 splash 主题感知、paper_grid_card 封面渐变基色、其余白底假设杂项。
5. C5 测试：mode 持久化单测、sheet widget 测试、暗色冒烟测试。
6. 运行完整验证门禁并记录；请用户实机验收亮/暗切换。

## 当前进度

- 已完成：C1 SparkPalette 与全量迁移（1745e84）、C2 mode 持久化 + controller + dark() + MaterialApp 接线（ad4201c）、C3 主题 sheet 外观三档（d33ec18）、C4 splash/渐变/杂项主题感知（b6d466b）、C5 测试（698855e）、完整验证门禁（format 63 文件、analyze、test 400 全绿）。
- 正在进行：等待用户 Windows 实机验收亮/暗切换（`flutter run -d windows`）。
- 下一步：用户验收后由编排者触发 /test → /review → /finish；WS3 桌面自适应以本分支头为基线另行建流。
- 阻塞项：无

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-10 | 三个工作流链式基线（WS2 基于 WS1 头） | 合并由编排者 /finish 触发，链式避免中途合入 main | 合并顺序固定为 WS1→WS2→WS3 |
| 2026-08-10 | 暗色 primarySoft/primaryPale 用 `Color.alphaBlend(primary.withValues(alpha:.28/.14), darkCard)` 派生 | 跟随强调色变化，避免每强调色手写一对暗色 | 暗色下强调色容器色随 BYOK 强调色联动 |
| 2026-08-10 | 本工作流起提交信息使用中文格式 `<类型>（<范围>）：<主题>` | main dbc6b08 完善中文提交信息约定 | 本分支全部提交遵循新约定 |
| 2026-08-10 | 迁移文件随 dart format 3.12（tall style）重排，非迁移文件一律恢复不提交 | dart 3.12 formatter 只剩 tall style，WS1 已开先例；门禁要求变更文件格式合规 | C1 diff 含迁移文件的格式重排（无行为变化）；其余 ~106 个 short-style 文件留待编排者统一重排 |
| 2026-08-10 | 无 context 场景改显式传参而非兜底亮色：CustomPainter 加 ink 字段、markdown 样式函数加 context 参数、构造器默认色改可空 build 解析 | 兜底亮色在暗色下是错误数据，传参让主题解析发生在有 context 处 | sparkMarkdownStyle/paperReaderMarkdownStyle 签名变更（内部 API）；测试调用点包 Builder |
| 2026-08-10 | FileThemePreferenceRepository 读-改-写单键；schema 校验 color/mode 双键可选 | 两键共存同一 JSON，旧数据无 mode 键视为 system | 存量数据零迁移 |
| 2026-08-10 | SparkTheme 抽 _themeData(palette, brightness) 共享构建体，dark()/light() 委托 | 防止亮暗两套主题定义漂移 | 暗色差异点（secondary 派生、onError、shadow/scrim、surfaceContainer、SnackBar、弹窗阴影）集中 isDark 三元 |
| 2026-08-10 | ThemeController 新增 debugResetForTesting() 处理 testWidgets 跨用例挂起 | 用例在 FakeAsync 中 setColor/setMode 后，写队列 Future 的完成 microtask 可能随 FakeAsync 丢弃而永不派送，下一用例真实事件循环 await flushPendingWrites 即挂起（两个 sheet 用例连跑时必现） | widget 测试 setUp 先重置单例；paper_ai_mobile_chat_ui_test 等直接 setColor 的既有用例目前未踩坑，保持不动，未来可用同一辅助方法 |

## 验证记录

> `/finish` 合并后必须记录 development APK 与 Windows debug EXE 两个目标的构建结果、产物路径、大小和 SHA-256；任一目标失败时不得填写"已合并"或清理 worktree。

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `tool\verify_changed_dart_format.ps1` | 通过（63 个文件） | 2026-08-10 |
| `flutter analyze` | 通过，No issues found | 2026-08-10 |
| `flutter test`（全量） | 通过，400 个用例全绿（395 既有 + 5 新增） | 2026-08-10 |
| 用户 Windows 实机验收亮/暗切换 | 待用户验收 | - |

## 审查结论

> 由 `/review` 填写摘要（阻断项、缺陷、结论）。

- 审查日期：
- 阻断项：
- 缺陷：
- 结论：可合并 / 需修复 / 需重新审查

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| c050898 | 文档：新增 dark-mode 任务台账 | 台账初始化 | - |
| 1745e84 | 重构（core）：SparkColors 静态常量迁移为 SparkPalette 主题扩展 | C1 | format 58 文件、analyze、flutter test 395 全绿 |
| ad4201c | 新增（core）：外观模式持久化与暗色主题接线 | C2 | analyze 通过、flutter test 395 全绿 |
| d33ec18 | 新增（core）：主题设置增加外观模式三档 | C3 | analyze 通过、sheet 既有 widget 测试通过 |
| b6d466b | 修复（core）：表面白底假设改为主题感知 | C4 | analyze 通过、flutter test 395 全绿 |
| 698855e | 测试（core）：外观模式持久化、主题切换与暗色冒烟用例 | C5 | format 63 文件、analyze、flutter test 400 全绿 |

## 交付准备（合并前收集）

### 交付摘要

说明用户可以观察到的结果，以及与原计划是否一致。

### 实际变更

- 领域与业务逻辑：
- 数据与基础设施：
- 界面与交互：
- 测试与工具：
- 文档：

### 兼容性与迁移

- 本地数据迁移：theme 偏好 JSON 追加 `mode` 键，旧数据缺省视为 system
- API 或领域契约变化：无
- 旧版本兼容性：无影响

### 已知风险与回滚

- 已知风险：无
- 回滚方式：说明需要 revert 的提交及数据影响。

### 文档更新建议

- 需要编排者更新的开发计划；若关联发布，再列出发布资料更新建议。

### 未完成与后续工作

- 无；如有，写明后续方向和依赖。

## 合并归档（合并后在 main 补齐）

> 只有任务提交已真实进入 `main` 后才能填写。本节与 `docs/development.md` 的真实状态更新一并提交；完成后台账转为只读归档。

- 最终状态：已合并
- 合入分支：`main`
- 最终集成提交：`<merge-sha-or-fast-forward-tip>`
- Pull Request：无 / `<url-or-number>`
- 合并时间：`YYYY-MM-DD HH:mm`
- main 集成验证：`<commands-and-results>`
- 开发计划更新：`<updated-sections-or-not-applicable-with-reason>`
- 最终后续项：无 / `<remaining-work>`
