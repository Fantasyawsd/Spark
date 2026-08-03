# 任务台账

> 单文件任务台账，由 `/start` 创建、`/develop` 与 `/test` 持续更新，合并前由 `/finish` 补齐交付记录。所有占位内容替换为真实信息。任务合并后归档保留，不删除、不更新。

## 基本信息

- 任务：参考 cherry-studio 落地规范文档改进（项目结构 / 设计规范 / 提交规范）
- 关联发布或里程碑：无（纯文档任务，不绑定版本）
- 分支：`docs/standards-revamp`
- Worktree：`C:\Users\Fantasy\Desktop\PaperFlow-worktrees\docs--standards-revamp`
- 基线提交：`447f1a8`
- 负责人：Fantasy（编排者）+ Claude Code Agent
- 状态：待审查
- 最近更新：2026-08-03 20:00

## 目标

把 cherry-studio 的三类参考点落地为 PaperFlow 的规范文档改进：① 项目结构增强（`docs/standards/code-structure.md` 补顶层目录 charter、闭合顶层规则、公共入口与 anti-patterns）；② 简版设计规范（新建 `docs/standards/design.md`）；③ 提交规范 scope 化 + 「无测试视为不存在」理念（`AGENTS.md` 与 `docs/standards/version-control.md`）。只改规范文档，不改代码。

## 非目标

- 不照搬 cherry-studio 的文档数量与目录结构（PaperFlow 保持 solo 小文档集）。
- 不修改 `lib/` 代码结构本身（本次只定规则，不迁移代码）。
- 不引入未选择机制：`CLAUDE.local.md`、testplan 内测通道、draft PR、GPG 签名、rebase 强制线性历史。
- 不改 CI、版本管理、发布流程。

## 验收标准

- [ ] `code-structure.md` 包含：顶层目录（app / core / features）charter 表（各目录的职责与边界）、闭合顶层规则（新能力按性质路由、禁止新建顶层目录）、公共入口规则（模块唯一公共入口、禁止深导入）、anti-patterns 清单。
- [ ] `docs/standards/design.md` 新建，含：设计哲学（中性界面 + 语义色反馈）、颜色只用主题 token 不硬编码、语义色四色（危险/成功/警告/信息）使用边界。
- [ ] `AGENTS.md` §8 提交类型示例带模块 scope（如 `feat(chat):`、`fix(papers):`）；「无测试视为不存在」写入验证章节。
- [ ] `version-control.md` §6 提交原则同步 scope 化。
- [ ] `docs/README.md` 索引与 `AGENTS.md` §9.1 文档分类表同步登记 `design.md`。
- [ ] SKILL.md 只引用规范路径、不复制规范内容（抽查无大段复制）。
- [ ] `git diff --check` 通过；Markdown 链接检查通过（无失效引用）。

## 写入范围

### 独占路径

- `docs/standards/code-structure.md`
- `docs/standards/design.md`（新建）
- `docs/standards/version-control.md`（§6 提交原则）
- `AGENTS.md`（§8 提交约定、§10 验证、§9.1 分类表）
- `docs/README.md`（索引）
- 本台账 `docs/workstreams/docs--standards-revamp/`

### 共享路径

- 无（文档任务，无代码写入）。

## 依赖关系

- 上游任务：无
- 外部接口或数据源：无（参考 cherry-studio 源码在 `C:\Users\Fantasy\Desktop\PaperFlow-worktrees\references\cherry-studio`，只读）

## 实施计划

1. 读 `docs/standards/code-structure.md` 现状与 `lib/src/` 实际目录 → 起草顶层 charter 表（app / core / features 各自的职责、边界、charter）。→ 验证：charter 表与 `lib/src/` 实际目录一一对应。
2. 修改 `code-structure.md`：新增「顶层目录与边界」（charter 表）、「闭合顶层规则」、「公共入口规则」、「anti-patterns 清单」。→ 验证：四节存在且规则不与现有分层约束冲突。
3. 新建 `docs/standards/design.md`：设计哲学（中性界面、内容出彩、语义色只用于反馈）、颜色 token 化规则（只用主题 token、不硬编码）、语义色四色使用边界。→ 验证：文档存在、与 Flutter ThemeData 现状吻合（不虚构现有不存在的 token）。
4. 修改 `AGENTS.md`：§8 提交类型示例加模块 scope（`feat(chat):`、`fix(papers):` 等）；§10 验证章节加「无测试视为不存在」理念。→ 验证：示例与 `lib/` 模块名对应。
5. 修改 `version-control.md` §6 提交原则：类型后带 scope 的格式与约束。→ 验证：与 AGENTS.md §8 措辞一致。
6. 同步索引：`docs/README.md` 总文档表加 `design.md`；`AGENTS.md` §9.1 分类表加「设计规范」行。→ 验证：索引与新增/修改文档对应。
7. 验证：`git diff --check`、Markdown 链接检查、SKILL.md 引用抽查；更新本台账「验证记录」。→ 验证：全部通过。
8. 原子提交（`docs:` 类型，按职责拆 2-3 个提交）。→ 验证：提交职责单一、台账记录 SHA。

## 当前进度

- 已完成：worktree 与台账创建；code-structure.md 追加 2.13-2.16；design.md 新建；AGENTS.md / version-control.md 提交规范 scope 化；索引与 SKILL 同步；全部验证通过（2026-08-03）
- 正在进行：待 `/review` 审查
- 下一步：审查通过后 `/finish` 合并
- 阻塞项：无

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-03 | 三项落地全选：项目结构增强、简版设计规范、提交 scope 化 | 编排者确认 | 本次任务范围定为三项，其他 cherry 参考点（CLAUDE.local.md 等）不落地 |
| 2026-08-03 | 设计规范放 `docs/standards/design.md` 与三份规范并列 | 属于强制规范、符合「一个文档一个事实源」分类 | docs/README.md 索引与 AGENTS.md §9.1 需同步 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `git diff --check` | 通过 | 2026-08-03 |
| Markdown 链接检查（design.md 引用、SKILL standards 路径） | 通过，无失效引用 | 2026-08-03 |
| SKILL.md 引用抽查（develop/finish/release/review 引用的 standards 路径存在） | 通过，无复制规范内容 | 2026-08-03 |
| charter 表与 `lib/src/` 实际目录核对（app/core/features） | 一致 | 2026-08-03 |
| design.md 与实际主题代码核对（PaperFlowColors / PaperThemeColor / ThemeData） | 一致，未虚构 token | 2026-08-03 |

## 审查结论

> 由 `/review` 填写摘要（阻断项、缺陷、结论）。

- 审查日期：2026-08-03
- 阻断项：无
- 缺陷：
  1. 台账「检查点与提交」表未记录 4 个提交 SHA；「状态」仍为「规划中」（应改为「待审查」）——违反 version-control.md §7 检查点规则。
  2. design.md「禁止硬编码 Color(0x...)」未说明历史遗留过渡：lib/ 现有 68 处硬编码（core/widgets 与多个 features），应补「历史硬编码逐步迁移到主题 token，不作为新代码例外」。
- 建议：
  3. code-structure.md §2.9「core 或 shared」与 2.13 顶层三目录不一致（实际无 shared 目录），统一为「core」。
  4. AGENTS.md §8 与 version-control.md §6 的 scope 豁免措辞可统一。
- 结论：需修复 → 已复核：缺陷 1、2 与建议 3、4 在 `2d76fbe` 修复，复核无新问题，结论更新为**可合并**

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 7828c8f | docs(standards): add top-level charter, closed-set and placement rules | 结构规则 | diff --check 通过 |
| e0e96fe | docs(standards): add design spec | 设计规范 | 链接检查通过 |
| 78926f1 | docs: scope conventional commits and add testing philosophy | 提交规范 | 引用检查通过 |
| 830b141 | docs: add standards revamp workstream ledger | 台账 | — |
| 2d76fbe | docs: fix review findings on standards revamp | review 修复 | diff --check 通过 |

## 交付记录

### 交付摘要

三项 cherry-studio 参考点已落地为 PaperFlow 规范文档改进，与原计划一致：
① `code-structure.md` 新增顶层目录 charter、闭合顶层规则、模块公共入口与放置反模式（2.13–2.16）；
② `docs/standards/design.md` 新建（设计哲学、颜色 token、语义色边界、检查清单）；
③ 提交规范改为 `<type>(<scope>):`（`AGENTS.md` §8 与 `version-control.md` §6），并写入「无测试视为不存在」。
review 缺陷 1、2 与建议 3、4 全部修复。

### 实际变更

- 领域与业务逻辑：无
- 数据与基础设施：无
- 界面与交互：无
- 测试与工具：无
- 文档：`code-structure.md` +46 行（2.13–2.16）；`design.md` 新建 44 行；`AGENTS.md` 3 处；`version-control.md` §6；`docs/README.md` 索引；`develop/SKILL.md` 示例同步

### 兼容性与迁移

- 本地数据迁移：无
- API 或领域契约变化：无
- 旧版本兼容性：无影响（纯文档改动，不触碰代码）

### 已知风险与回滚

- 已知风险：① `design.md` 与新代码的一致性待定——编排者在 main 上新增了 `accent/popover/foregroundTertiary` 等主题 token，合并后 `design.md` §2.1 中性层级列表需补充（本次任务不处理 main 上的改动）；② 历史硬编码 `Color(0x...)`（约 68 处）逐步迁移，迁移须为独立提交。
- 回滚方式：revert 提交 `7828c8f` 至 `2d76fbe`（按依赖逆序），均为纯文档改动，无数据影响。

### 文档更新建议

- 需要编排者更新的开发计划：无（不涉及产品方向）。
- `design.md` 与 `cherry-studio-ui.md`（编排者 main 上新建）的关系待后续理清（可合并或互引）。

### 未完成与后续工作

- 编排者 main 上的 Cherry UI/UX 代码落地（`paperflow_design_tokens` / `cherry_motion` / `cherry_primitives` 等）与 `cherry-studio-ui.md` 不在本任务范围，由其自行提交处理。
- `design.md` 中性层级列表需随 main 新 token 补充。
