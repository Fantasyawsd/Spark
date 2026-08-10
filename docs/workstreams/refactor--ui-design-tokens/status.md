# 任务台账

> 单文件任务台账，由 `/start` 创建、`/develop` 与 `/test` 持续更新。`/finish` 在任务分支收集合并前交付信息；任务真实合入 `main` 后，再在 `main` 补齐最终合并归档。所有占位内容替换为真实信息。

## 基本信息

- 任务：`UI 设计系统收敛与结构调整（WS1）`
- 关联发布或里程碑：无（后续 WS2 暗色模式 `feature/dark-mode`、WS3 桌面自适应 `feature/desktop-adaptive` 以本任务为链式基线）
- 分支：`refactor/ui-design-tokens`
- Worktree：`../refactor--ui-design-tokens`
- 基线提交：`4e44858`
- 负责人：编排者 Fantasy；执行 Claude Code Agent
- 状态：开发中
- 最近更新：`2026-08-10 19:46`

## 目标

将 papers / chat / profile / search / ai_settings / local_data 模块的颜色、字号、圆角收敛到统一设计令牌体系（SparkColors / SparkTextStyles / SparkDesignTokens），消除重复硬编码；把阅读/网格模式切换入口从底部导航迁回论文页顶栏；为 WS2 暗色模式扫清硬编码障碍。

## 非目标

- 不实现暗色模式（WS2）与桌面自适应布局（WS3）。
- 不改动 `community`、`messages` 模块（非生产导航）。
- 不重新设计组件视觉（字号/圆角单项渲染差 ≤1px，sheet 顶角除外）。
- 不改本地数据结构与 API 契约。

## 验收标准

- [ ] lib 内（community/messages 除外）无 `Color(0x...)` 危险色/遮罩/警告色重复硬编码，语义表面色统一走 SparkColors。
- [ ] 字号字面量收敛为 `SparkTextStyles` 语义阶梯（tiny10~display24）。
- [ ] 圆角按语义映射到 `SparkDesignTokens` 档位（pill 99 除外）。
- [ ] 阅读/网格模式切换通过论文页顶栏按钮完成，底部导航论文 tab 标签固定为「论文」。
- [ ] profile 横向论文小卡为单一公共组件。
- [ ] chat 会话主页无网络图依赖，空列表有轻量空态。
- [ ] `verify_changed_dart_format.ps1`、`flutter analyze`、`flutter test` 全部通过。

## 写入范围

### 独占路径

- `lib/src/core/theme/`、`lib/src/core/widgets/`、`lib/src/app/`（spark_app、spark_bottom_nav）
- `lib/src/features/{papers,chat,profile,search,ai_settings,local_data}/presentation/`
- `test/`（受行为变更影响的用例）
- `docs/workstreams/refactor--ui-design-tokens/`

### 共享路径

- `lib/spark.dart`（新增导出，追加式修改）

## 依赖关系

- 上游任务：无
- 外部接口或数据源：无
- 并行风险排查（2026-08-10）：`fix/chat-keyboard-jank` worktree 注册已失效被自动清理，仓库内无该分支 ref；`feature/refine-chat-composer` 无 main 之外的提交与 diff。结论：无并行写入重叠。

## 实施计划

1. WS1-A 颜色收敛：SparkColors 增补 warning/dangerBorder/barrier，替换硬编码色。
2. WS1-B 字号收敛：新建 `spark_text_styles.dart`，迁移 fontSize 字面量。
3. WS1-C 圆角收敛：按语义映射表对齐 SparkDesignTokens。
4. WS1-D 抽取 profile 横向论文小卡公共组件。
5. WS1-E 网格切换入口迁至论文页顶栏，底部导航标签固定，更新 ui_preview 测试。
6. WS1-F chat 头像去网络依赖 + 会话主页空态。
7. WS1-G papers 模块间距字面量接入 token（仅精确匹配刻度）。
8. 运行验证门禁并记录。

## 当前进度

- 已完成：全部 7 个实施项（A-G）+ 验证门禁（format 47 文件通过、analyze 通过、flutter test 395 全绿）。
- 正在进行：无（WS1 收尾，台账归档提交）。
- 下一步：编排者触发 /test → /review → /finish；WS2 暗色模式以本分支头（8532ade 起的最终提交）为基线另行建流。
- 阻塞项：无

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-10 | 三个工作流链式基线（WS2 基于 WS1 头、WS3 基于 WS2 头） | 合并由编排者 /finish 触发，链式避免中途合入 main | 合并顺序固定为 WS1→WS2→WS3 |
| 2026-08-10 | 字号收敛为整数语义阶梯，单项 Δ≤1px | 消除碎片化同时控制视觉回归 | 约 140 处调用点迁移 |
| 2026-08-10 | 实施中将计划的完整 TextStyle 类（SparkTextStyles）简化为纯字号 token 类 `SparkFontSizes` | 约 120 处迁移需脚本机械完成；完整 TextStyle 重写会破坏现有样式结构、风险高；纯字号 token 保持调用点结构不变且严格满足 Δ≤1px | 新建 `lib/src/core/theme/spark_font_sizes.dart`；样式级语义层留待后续按需引入 |
| 2026-08-10 | sheet 顶角统一 radius3Xl(22) | 与 dialogTheme 对齐，一个覆盖层语义一种圆角 | Δ≤6px，需用户验收背书 |
| 2026-08-10 | 排除 community/messages 模块 | AGENTS.md §2：非生产导航 | 其中字面量不在本次收敛范围 |

## 验证记录

> `/finish` 合并后必须记录 development APK 与 Windows debug EXE 两个目标的构建结果、产物路径、大小和 SHA-256；任一目标失败时不得填写"已合并"或清理 worktree。

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `tool\verify_changed_dart_format.ps1` | 通过（47 个文件） | 2026-08-10 |
| `flutter analyze` | 通过，No issues found | 2026-08-10 |
| `flutter test`（全量） | 通过，395 个用例全绿 | 2026-08-10 |
| 用户 Windows 实机验收 | 待编排者在 /test 或合并前安排 | - |

## 审查结论

> 由 `/review` 填写摘要（阻断项、缺陷、结论）。

- 审查日期：
- 阻断项：
- 缺陷：
- 结论：可合并 / 需修复 / 需重新审查

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 402ffa8 | docs: add workstream ledger for ui-design-tokens | 台账初始化 | - |
| f289daa | refactor(core): 收敛语义色并消除硬编码颜色 | WS1-A | flutter analyze 通过 |
| 6e07488 | refactor(core): 建立 SparkFontSizes 语义字号阶梯并统一字号 | WS1-B | dart format + analyze 通过 |
| 298e2ca | refactor(core): 圆角对齐 SparkDesignTokens 语义档位 | WS1-C | dart format + analyze 通过 |
| ed4cd35 | refactor(profile): 抽取横向论文小卡公共组件 PaperMiniCard | WS1-D | analyze 通过 |
| 6082a38 | refactor(papers): 阅读/网格模式切换入口移至论文页顶栏 | WS1-E | analyze + ui_preview 定向测试通过 |
| f9042c3 | fix(chat): 会话主页空态提示与模型头像去网络依赖 | WS1-F | dart format + analyze 通过 |
| 145fcc1 | refactor(papers): 整表达式等刻度的间距接入 SparkDesignTokens | WS1-G | dart format + analyze 通过 |

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

- 本地数据迁移：无
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
