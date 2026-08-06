# 任务台账

> 单文件任务台账，由 `/start` 创建、`/develop` 与 `/test` 持续更新。`/finish` 在任务分支收集合并前交付信息；任务真实合入 `main` 后，再在 `main` 补齐最终合并归档。所有占位内容替换为真实信息。

## 基本信息

- 任务：替换 Spark 启动 logo，并修复改名误伤的 worktree 文档路径
- 关联发布或里程碑：无
- 分支：`feature/spark-logo`
- Worktree：`C:\Users\Fantasy\Desktop\PaperFlow-worktrees\feature--spark-logo`
- 基线提交：`2dd2b4d`
- 负责人：Fantasy
- 状态：开发中
- 最近更新：2026-08-07 00:50

## 目标

1. 用用户提供的新 logo（`Downloads\ChatGPT Image 2026年8月7日 00_38_55.png`）替换 `assets/images/spark_logo.png`，路径不变，启动闪屏显示新 logo。
2. 修复改名任务误伤的 worktree 真实目录路径：`AGENTS.md`、`docs/standards/version-control.md` 中被误改为 `Spark-worktrees` 的路径恢复为真实目录 `PaperFlow-worktrees`。

## 非目标

- 不改变 logo 尺寸、样式或启动闪屏动画。
- 不重命名 `PaperFlow-worktrees` 目录本身。
- 不涉及其他品牌改名遗留问题。

## 验收标准

- [ ] `assets/images/spark_logo.png` 内容为新 logo，路径与引用不变。
- [ ] `AGENTS.md`、`docs/standards/version-control.md` 中所有 worktree 路径均指向真实目录 `PaperFlow-worktrees`，无 `Spark-worktrees` 残留。
- [ ] `flutter analyze` 通过。
- [ ] Windows 桌面启动显示新 logo。

## 写入范围

### 独占路径

- `assets/images/spark_logo.png`
- `AGENTS.md`
- `docs/standards/version-control.md`
- `docs/workstreams/feature--spark-logo/status.md`

### 共享路径

- 无

## 依赖关系

- 上游任务：无
- 外部接口或数据源：无

## 实施计划

1. 替换 logo 文件 → 验证文件内容与路径引用。
2. 修复 AGENTS.md、version-control.md 的 worktree 路径 → 验证无 `Spark-worktrees` 残留。
3. 运行 `flutter analyze` → 验证通过。
4. 用户 Windows 桌面验收 → 验证新 logo 显示。
5. 合并 main、归档台账。

## 当前进度

- 已完成：worktree 分支创建、台账初始化、logo 替换、worktree 路径修复、flutter analyze 通过
- 正在进行：测试验证与提交
- 下一步：Windows 桌面验收
- 阻塞项：无

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-07 | 替换 logo 采用覆盖 `assets/images/spark_logo.png`（路径不变） | 引用点（spark_app.dart、widget_test.dart、pubspec.yaml）无需改动，改动最小 | 无 |
| 2026-08-07 | worktree 路径修复纳入本任务 | 改名任务的收尾修正，避免遗留破坏 worktree 创建流程的缺陷 | 无 |
| 2026-08-07 | 同时替换 Android 原生开屏 `launch_image.png`（drawable-nodpi） | 冷启动先显示原生开屏再进 Flutter 闪屏，只换 spark_logo 会导致开屏仍显示旧图 | 新增资源 |
| 2026-08-07 | 开屏 logo 尺寸 112→240，launch_image 放大至 768 | 用户要求开屏 logo 放大 2-3 号 | 视觉效果 |
| 2026-08-07 | Windows ICO 与 Android 图标白底 + 主体放大 1.25 | 用户要求 LOGO 白底、图标放大 2-3 号 | 视觉效果 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |

## 审查结论

> 由 `/review` 填写摘要（阻断项、缺陷、结论）。

- 审查日期：
- 阻断项：
- 缺陷：
- 结论：可合并 / 需修复 / 需重新审查

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `ea4ade9` | feat(core): replace startup logo and fix worktree path regressions | 最小纵向闭环 | flutter analyze 通过；widget_test 4 项通过（含 logo 断言） |

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
