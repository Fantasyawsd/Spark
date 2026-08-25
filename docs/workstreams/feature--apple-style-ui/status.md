# 任务台账

## 基本信息

- 任务：UI 苹果风（iOS）主题层重塑
- 关联发布或里程碑：无（日常迭代）
- 分支：`feature/apple-style-ui`
- Worktree：`../agent-1`
- 基线提交：`ca0fd28`
- 负责人：Fantasy（编排者）
- 状态：开发中
- 最近更新：2026-08-25

## 目标

把 Spark 全局观感从 Cherry Studio 风格转向 iOS 视觉语言：保留 Material 组件骨架，通过 core 主题层（palette / design tokens / ThemeData）+ 自建组件层 + 页面级硬编码清理完成重塑。深浅色 × 五强调色全矩阵生效。

## 非目标

- 不替换 Material Icons 为 SF Symbols。
- 不引入 Cupertino 组件替换、不建独立设计系统组件库。
- 不改路由、业务逻辑、Markdown 渲染管线。
- 不引入字体文件或 google_fonts；维持系统字体栈。
- 不重排任何页面布局结构。

## 验收标准

- [ ] `flutter analyze` 无告警；`flutter test` 全绿（含新增 iOS 基准快照测试与调整后的对比度门限）。
- [ ] light/dark 双模式色板对齐 iOS 语义色（canvas #F2F2F7 / dark 纯黑系）；五强调色为 iOS 系统色系变体。
- [ ] 卡片无边框靠底色分层；阴影收敛；标题字重降档至 w700/w600。
- [ ] AppBar 居中标题 17/w600；Switch 选中态系统绿。
- [ ] 用户 Windows 实机验收通过。

## 写入范围

### 独占路径

- `lib/src/core/theme/`
- `lib/src/core/widgets/`
- `lib/src/features/papers/presentation/`（字重清理、paper_accent 色值）
- `lib/src/features/chat/presentation/`（字重清理）
- `lib/src/features/profile/presentation/`（grouped 化、大标题试点）
- `test/`（spark_theme_test 等）
- `docs/workstreams/feature--apple-style-ui/`

### 共享路径

- 无

## 依赖关系

- 上游任务：无
- 外部接口或数据源：无

## 实施计划

1. Phase A 基座：`core/theme` 四文件（palette 色值表、强调色 iOS 化、圆角/阴影 token、ThemeData 组件级主题）。
2. Phase B 组件层：CherrySurface 去默认边框、bottom_nav/sheet/segmented/tab_bar 参数对齐。
3. Phase C 页面推广：全局 w800 降档（19 文件 24 处）、paper_accent 色值、profile grouped 化与大标题试点。
4. 验证：测试适配（门限 4.5→3.0 注明依据）+ 新增 iOS 快照断言；analyze + test 全绿。
5. Windows 实机验收（用户执行）。

## 当前进度

- 已完成：Phase A（c295b5d）、Phase B（11daa5a）、Phase C（67184bb）；格式检查 + analyze + 全量测试通过。
- 正在进行：等待编排者 Windows 实机验收。
- 下一步：实机验收 → /test → /review → /finish。
- 阻塞项：无

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-25 | 强调色机制保留，色值向 iOS 系统色对齐；green/orange 用 Apple 加深变体 | 纯 #34C759/#FF9500 配白字对比度不可读 | spark_theme_test 对白门限放宽 ≥3.0 |
| 2026-08-25 | 维持系统字体栈，不引 SF Pro/google_fonts | 版权限制 + 混排基线问题 | 仅靠字重与负字距塑形 |
| 2026-08-25 | dark 模式转中性黑灰系（#000000/#1C1C1E） | iOS 暗色语义 | spark_theme L74-78 蓝黑字面量需一并替换 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `.\tool\verify_changed_dart_format.ps1` | 通过（36 文件） | 2026-08-25 |
| `flutter analyze` | No issues found | 2026-08-25 |
| `flutter test` | 625 项全绿（含新增 iOS 基准快照与门限 3.0 调整） | 2026-08-25 |
| Windows 实机验收（flutter run -d windows，用户执行） | 待执行 | — |

### 备注

- `spark_theme_test` 对白对比度门限由 4.5 放宽至 3.0：iOS 系统色作按钮底色配白字时 Apple 自身即 ~4.0（systemBlue #007AFF = 4.02），已在测试注释中写明依据；暗色对卡片 ≥4.5 门限保留且全部通过。
- 工作区遗留 `windows/flutter/generated_*` 为 Flutter 构建自动再生文件，与本任务无关，不纳入提交，收尾时按仓库惯例处理。

## 审查结论

- 审查日期：
- 阻断项：
- 缺陷：
- 结论：

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| c295b5d | 重构（主题）：色板、圆角阴影与组件级主题对齐 iOS 风格 | Phase A | analyze 无问题；spark_theme_test 9 项全绿 |

## 交付准备（合并前收集）

### 交付摘要

（待合并前填写）

### 实际变更

- 领域与业务逻辑：无
- 数据与基础设施：无
- 界面与交互：iOS 风格主题层重塑（待完成后填写明细）
- 测试与工具：spark_theme_test 门限与快照更新
- 文档：本台账

### 兼容性与迁移

- 本地数据迁移：无
- API 或领域契约变化：无
- 旧版本兼容性：无影响（纯视觉）

### 已知风险与回滚

- 已知风险：纯黑 canvas 下 PaperAccent/阴影观感待实机复核；去边框后个别底色未跟 token 处会失去层次（Phase C 逐页核查）。
- 回滚方式：revert 本分支提交即可，无数据影响。

### 未完成与后续工作

- 无（后续可选：SF Symbols 映射、Cupertino 化深化不在本任务范围）
