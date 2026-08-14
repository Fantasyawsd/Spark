# 任务台账

> 单文件任务台账，由 `/start` 创建、`/develop` 与 `/test` 持续更新。`/finish` 在任务分支收集合并前交付信息；任务真实合入 `main` 后，再在 `main` 补齐最终合并归档。所有占位内容替换为真实信息。

## 基本信息

- 任务：替换 Spark 启动 logo，并修复改名误伤的 worktree 文档路径
- 关联发布或里程碑：无
- 分支：`feature/spark-logo`
- Worktree：`C:\Users\Fantasy\Desktop\PaperFlow-worktrees\feature--spark-logo`
- 基线提交：`2dd2b4d`
- 负责人：Fantasy
- 状态：已合并
- 合并归档：分支 feature/spark-logo 已于 2026-08-07 合并（集成提交 3a3f92a）；台账此前停留在开发中，本次勘误归档。
- 最近更新：2026-08-14

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
| `flutter analyze` | 通过（No issues） | 2026-08-07 |
| `flutter test test/widget_test.dart` | 4 项通过（含启动闪屏 logo 断言） | 2026-08-07 |
| `flutter build apk --debug --flavor development --dart-define=SPARK_ENV=development` | 成功，产出 app-development-debug.apk | 2026-08-07 |
| APK 内部资源校验（launch_image / ic_launcher / spark_logo 哈希） | 新资源均已打包 | 2026-08-07 |

## 审查结论

> 由 `/review` 填写摘要（阻断项、缺陷、结论）。

- 审查日期：2026-08-07
- 阻断项：无
- 缺陷：无
- 结论：可合并（由编排者直接指示 `/finish`，未单独执行 `/review`）

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `ea4ade9` | feat(core): replace startup logo and fix worktree path regressions | 最小纵向闭环 | flutter analyze 通过；widget_test 4 项通过（含 logo 断言） |
| `3bef37b` | docs(workflow): record spark-logo task checkpoint | 检查点归档 | 台账检查点同步 |
| `0e466de` | feat(core): enlarge splash logo, white-background icons and native launch image | 用户验收迭代 | analyze 通过；APK 重新构建并校验资源 |

## 交付准备（合并前收集）

### 交付摘要

按用户提供的新 logo 替换 Spark 品牌视觉：Android 原生冷启动开屏、Flutter 启动闪屏、Windows 窗口图标与 Android 桌面图标统一为新 logo（白底、主体放大）；同时修复改名任务误伤的 worktree 文档路径。

### 实际变更

- 领域与业务逻辑：无
- 数据与基础设施：无
- 界面与交互：Flutter 闪屏 logo 尺寸 112→240；Android 原生开屏 `launch_image.png` 替换为新 logo 并放大至 768；Windows `app_icon.ico` 与 Android `mipmap-*` 桌面图标替换为新 logo（白底、主体放大 1.25）
- 测试与工具：无新增测试（纯资源/文档替换）；既有闪屏测试通过
- 文档：修复 `AGENTS.md`、`docs/standards/version-control.md` 中被改名误伤的 worktree 路径（`Spark-worktrees` → 真实目录 `PaperFlow-worktrees`）

### 兼容性与迁移

- 本地数据迁移：无
- API 或领域契约变化：无
- 旧版本兼容性：无影响（`applicationId` 未变，仍为 `app.spark.reader.dev`）

### 已知风险与回滚

- 已知风险：无
### 已知风险与回滚

- 已知风险：无
- 回滚方式：revert `ea4ade9` 或 `0e466de` 可恢复旧 logo 与 worktree 路径；纯资源/文档改动，无数据影响。

### 文档更新建议

- 本任务为品牌资源替换与路径修复，不影响 `docs/development.md` 开发计划（N/A）。

### 未完成与后续工作

- 手机实机开屏/图标效果由编排者确认（已指示 finish，视为接受当前状态）。

## 合并归档（合并后在 main 补齐）

> 只有任务提交已真实进入 `main` 后才能填写。本节与 `docs/development.md` 的真实状态更新一并提交；完成后台账转为只读归档。

- 最终状态：已合并
- 合入分支：`main`
- 最终集成提交：`3a3f92a`（Merge branch 'feature/spark-logo'）
- Pull Request：无（日常开发直接合入 main）
- 合并时间：2026-08-07 01:40
- main 集成验证：`flutter analyze` 通过；`flutter test test/widget_test.dart` 4 项通过；APK 构建成功（分支上验证）
- 开发计划更新：不适用——本任务为品牌资源替换与 worktree 路径修复，不改变产品能力，`docs/development.md` 无需更新
- 最终后续项：无
