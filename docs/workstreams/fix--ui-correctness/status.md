# 任务台账

## 基本信息

- 任务：`ui-correctness`（界面焕新 P0 · 缺陷修复）
- 关联发布或里程碑：无（界面焕新系列第一阶段）
- 分支：`fix/ui-correctness`
- Worktree：`../agent-1`
- 基线提交：`506a854`
- 负责人：编排者（人类）+ Claude Code Agent
- 状态：开发中
- 最近更新：2026-08-21 14:40

## 目标

修复 UI 审计（105 项发现）中的高危正确性缺陷，使暗色模式、无障碍与语义色达到可接受基线：

1. 暗色 primary 提亮：五套强调色在暗色卡片上文本对比度 ≥ 4.5:1，并配套反向对比度测试。
2. 社区实验页暗色适配：清除 `Colors.white`、硬编码浅色渐变、裸字号与游离阴影。
3. 思考面板 shimmer 接入 `disableAnimations` 无障碍开关。
4. 搜索历史错误态改用 danger 语义色。
5. 删除 API Key 按钮补 danger 破坏性视觉。

## 非目标

- 不做 token 体系升级（P1）、组件现代化（P2）、品牌个性（P3）。
- 不调整亮色模式任何取值。
- 不改 community 页信息架构（该页不在生产导航）。

## 验收标准

- [ ] `SparkPalette.dark(color).primary` 对 `card` 对比度 ≥ 4.5:1（五色全部），有测试断言。
- [ ] community 模块无 `Colors.white` 硬编码底色、无裸字号（全部走 SparkFontSizes）。
- [ ] `disableAnimations` 开启时 shimmer 静态显示。
- [ ] 搜索错误文案与删除 Key 按钮使用 danger/dangerBorder。
- [ ] `flutter analyze`、`flutter test` 通过。

## 写入范围

### 独占路径

- `lib/src/core/theme/spark_theme_color.dart`、`spark_palette.dart`
- `lib/src/features/chat/presentation/widgets/paper_ai_reasoning_panel.dart`
- `lib/src/features/search/presentation/paper_search_screen.dart`
- `lib/src/features/ai_settings/presentation/deepseek_settings_section.dart`
- `lib/src/features/community/presentation/`（screen + widgets）
- `test/spark_theme_test.dart`、`test/community_screen_test.dart`（如存在）

### 共享路径

- 无

## 依赖关系

- 上游任务：无（基于 main @ 506a854）
- 外部接口或数据源：无

## 实施计划

1. SparkThemeColor 增加 darkValue 字段，SparkPalette.dark 接线 → verify: 新增对比度测试通过
2. _ShimmerText 接入 disableAnimations → verify: analyze + 现有 chat 测试
3. 搜索错误态 danger、删除 Key 按钮 danger 视觉 → verify: analyze
4. community 暗色适配（底色/渐变/字号/阴影/头像/示意图）→ verify: analyze + 定向测试
5. 全量 `flutter analyze` + `flutter test` → verify: 全绿

## 当前进度

- 已完成：worktree 创建、台账初始化
- 正在进行：步骤 1
- 下一步：步骤 2-5
- 阻塞项：无

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-21 | 暗色提亮值取 L≈0.45+ 的手调值（pink #E8708C 等） | 审测计算对比度 5.8-6.7:1，留有余量 | 仅暗色模式取值变化 |
| 2026-08-21 | 四阶段（P0-P3）的最终双端发布版构建统一在 P3 完成后执行一次 | 四支串行合入同一 main，逐支重复构建无增量信息 | 各支台账验证记录注明构建统一执行时点 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| （待执行） | | |

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

（待补）

### 实际变更

- 界面与交互：暗色强调色提亮、community 暗色适配、错误态语义色、shimmer 无障碍
- 测试与工具：暗色对比度测试

### 兼容性与迁移

- 本地数据迁移：无
- API 或领域契约变化：SparkThemeColor 枚举新增字段（非破坏）
- 旧版本兼容性：无影响

### 已知风险与回滚

- 已知风险：暗色 primary 变亮后，个别假设深色强调色的亮色元素观感变化（仅暗色模式）
- 回滚方式：revert 本分支合并提交

### 文档更新建议

- 开发计划不受影响（缺陷修复）

### 未完成与后续工作

- P1 token 升级、P2 组件现代化、P3 品牌个性按计划进行

## 合并归档（合并后在 main 补齐）

- 最终状态：
- 合入分支：
- 最终集成提交：
- 合并时间：
- main 集成验证：
- 开发计划更新：
- 最终后续项：
