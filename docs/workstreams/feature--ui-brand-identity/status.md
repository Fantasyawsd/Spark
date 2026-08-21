# 任务台账

## 基本信息

- 任务：`ui-brand-identity`（界面焕新 P3 · 品牌个性）
- 关联发布或里程碑：无（界面焕新系列第四阶段）
- 分支：`feature/ui-brand-identity`（基于 `feature/ui-components-2026` 的叠加分支）
- Worktree：`../agent-3`
- 基线提交：`4e9f902`（feature/ui-components-2026 tip）
- 负责人：编排者（人类）+ Claude Code Agent
- 状态：开发中
- 最近更新：2026-08-21 18:20

## 目标

完成界面焕新的品牌个性层（路线图 P3）与 C12：

1. 主题/强调色切换动画接入动效刻度（themeAnimationDuration=pageDuration、
   themeAnimationCurve=emphasizedCurve）。
2. 启动屏品牌化：canvas→强调色 5% 染色渐变底、logo 尺寸随窗口响应（160–240 clamp）。
3. 代码高亮暗色主题与应用色温对齐（背景/工具栏/边框改用应用暗色表面系，
   语法色保留 Atom One）。
4. C12：点赞红心语义（danger）+ 弹跳动效（1.25 spring 回落）+ 计数上滑滚动 +
   评论头像按 id 稳定轮换四语义色。

## 非目标

- 衬线展示字体接入：需要引入字体资产（打包体积与授权决策），留待编排者决策，
  本阶段不实施。
- 不改业务逻辑与数据契约。

## 验收标准

- [x] 切换强调色/亮暗模式时使用 emphasized 曲线 300ms 动画。
- [x] 启动屏渐变底 + 响应式 logo，亮暗两套成立。
- [x] 暗色下代码块背景与卡片色温一致（#1B222E 族）。
- [x] 点赞激活呈红心 + 弹跳，计数变化上滑滚动，评论头像四色轮换。
- [x] `flutter analyze` 无问题、`flutter test` 612 项全绿、格式门禁通过。

## 写入范围

### 独占路径

- `lib/src/app/spark_app.dart`、`spark_bootstrap.dart`
- `lib/src/core/widgets/spark_code_highlight.dart`
- `lib/src/features/papers/presentation/widgets/paper_action_bar.dart`、
  `paper_comments_sheet.dart`

### 共享路径

- 无

## 依赖关系

- 上游任务：fix/ui-correctness（P0，已合 main）、feature/ui-tokens-v2（P1）、
  feature/ui-components-2026（P2）——本分支叠加在 P2 之上
- 外部接口或数据源：无

## 实施计划

1. 主题切换动画 → verify: analyze
2. 启动屏品牌化 → verify: analyze + 现有启动屏测试
3. 代码高亮色温适配 → verify: analyze
4. C12 三项 → verify: analyze + 全量测试

## 当前进度

- 已完成：全部实施与验证（analyze 无问题、test 612 全绿、format 通过）
- 正在进行：提交
- 下一步：等待编排者验收；合并顺序 P1→P2→本分支
- 阻塞项：无

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-21 | 衬线展示字体不实施 | 需引入字体资产（Noto Serif SC 子集约数 MB），涉及包体积与授权决策，属编排者职权 | 记录为待决策项 |
| 2026-08-21 | 点赞激活色用 danger 而非新增 like 色 | danger 红已是语义色且暗色有变体，避免 palette 加冗余字段 | 收藏等其他 active 按钮不受影响（activeColor 参数化） |
| 2026-08-21 | 评论头像色轮换用 id.hashCode.abs()%4 | 稳定可复现（同一评论永远同色），无需额外状态 | 测试如锁定 primary 需更新（当前无此类断言） |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| flutter analyze | 无问题 | 2026-08-21 |
| flutter test | 612 项全部通过 | 2026-08-21 |
| tool/verify_changed_dart_format.ps1 | 通过 | 2026-08-21 |
| 双端发布版构建 | 待四阶段全部合入 main 后统一执行 | - |

## 审查结论

- 审查日期：
- 阻断项：
- 缺陷：
- 结论：

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |

## 交付准备（合并前收集）

### 交付摘要

（待合并前补齐）

### 实际变更

- 界面与交互：主题切换动画、启动屏品牌化、代码块色温、点赞/计数/头像微交互
- 测试与工具：无新增测试（现有 612 项回归覆盖）

### 兼容性与迁移

- 本地数据迁移：无
- API 或领域契约变化：_PaperActionButton 新增 activeColor/bounceOnTap 私有参数（模块内）
- 旧版本兼容性：无影响

### 已知风险与回滚

- 已知风险：无
- 回滚方式：revert 本分支合并提交（须连同 P1/P2 或保持其已合入）

### 文档更新建议

- 开发计划不受影响（视觉升级）
- 衬线字体决策待编排者：若采纳需评估字体资产引入（体积/授权/子集化）

### 未完成与后续工作

- 衬线展示字体（待编排者决策）
- 操作栏内容穿透、SliverAppBar.large、流式光标（P2 遗留记录）

## 合并归档（合并后在 main 补齐）

- 最终状态：
- 合入分支：
- 最终集成提交：
- 合并时间：
- main 集成验证：
- 开发计划更新：
- 最终后续项：
