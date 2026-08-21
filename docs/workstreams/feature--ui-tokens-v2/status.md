# 任务台账

## 基本信息

- 任务：`ui-tokens-v2`（界面焕新 P1 · Token 升级）
- 关联发布或里程碑：无（界面焕新系列第二阶段）
- 分支：`feature/ui-tokens-v2`
- Worktree：`../agent-1`
- 基线提交：`b95c259`（main，含 P0）
- 负责人：编排者（人类）+ Claude Code Agent
- 状态：开发中
- 最近更新：2026-08-21 16:10

## 目标

按《界面焕新提案》升级设计 token 体系，为组件现代化（P2）提供地基：

1. 圆角三级制：新增 `radiusField=12`（控件）/`radiusCard=18`（卡片）/`radiusOverlay=22`（浮层），chip 胶囊化，按钮与输入框升级到控件级圆角。
2. 三层微阴影（亮暗双套）：`interactiveShadowFor/floatingShadowFor/shadowColorOf` 替换单层 const 阴影，统一三处散落阴影定义。
3. 字号刻度扩展（displaySmall=26/displayLarge=28）+ TextTheme 补全 titleSmall/bodySmall/labelLarge/labelMedium/labelSmall 五个缺失样式，headlineLarge 落到刻度（30→28+负字距）。
4. MotionTokens 增补 microDuration/springCurve/emphasizedCurve；ThemeData 配置 pageTransitionsTheme（Android FadeForwards / iOS Cupertino / Windows FadeUpwards）。
5. paper_accent 六色增加暗色提亮变体（colorFor(Brightness)），暗色下对比度 ≥ 4.5:1。

## 非目标

- 不做组件级改造（C1-C12 属 P2/P3）。
- 不改亮色取值语义（仅新增档位与暗色变体）。
- 不引入第三方依赖。

## 验收标准

- [x] 新 token 可用且 ThemeData 全量装配（chip 胶囊、按钮 12px、浮层 22px、页面转场定制）。
- [x] 阴影亮暗两套均可见，全库无游离阴影色值（popupMenu/网格卡/社区卡统一走 token）。
- [x] TextTheme 十一档齐全，Material 组件默认字号落在 Spark 刻度。
- [x] paper_accent 暗色对比度达标。
- [x] `flutter analyze`、`flutter test`（612 项）、格式检查通过。

## 写入范围

### 独占路径

- `lib/src/core/theme/spark_design_tokens.dart`、`spark_font_sizes.dart`、`spark_theme.dart`
- `lib/src/core/motion/motion_tokens.dart`
- `lib/src/core/widgets/cherry_primitives.dart`
- `lib/src/app/spark_bottom_nav.dart`
- `lib/src/features/community/presentation/community_screen.dart`（阴影调用点）
- `lib/src/features/papers/presentation/paper_accent.dart`、`widgets/paper_grid_card.dart`

### 共享路径

- 无

## 依赖关系

- 上游任务：`fix/ui-correctness`（P0，已合并）
- 外部接口或数据源：无

## 实施计划

1. token 三文件升级 + SparkTheme 装配 → verify: analyze
2. 三处阴影调用点迁移 → verify: analyze（旧 const 已删除，编译器兜底）
3. paper_accent 暗色变体 + 调用点 → verify: analyze
4. 全量 analyze + test + format → verify: 全绿

## 当前进度

- 已完成：全部实施与验证（analyze 无问题、test 612 全绿、format 通过）
- 正在进行：提交
- 下一步：等待编排者验收后合并
- 阻塞项：无

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-21 | paper_accent 用 colorFor(Brightness) 而非入 SparkPalette | ThemeExtension 加 List 字段需改构造/copyWith/lerp 全套，侵入大；colorFor 达成同一目标 | 调用点仅 1 处，已迁移 |
| 2026-08-21 | 保留 radius2Xl/radius3Xl 与新语义名 radiusCard/radiusOverlay 并存（同值） | 平滑迁移：现有 30+ 处调用不强制改名，新代码用语义名 | 后续 P2 逐步收敛 |
| 2026-08-21 | headlineLarge 30→28（displayLarge）+ letterSpacing -0.5 | 该样式全库零使用点，改动无回归风险；对齐大标题趋势 | 无 |
| 2026-08-21 | 删除旧 interactiveShadow/floatingShadow const，全部调用点迁移 | 避免「亮色 const + 新函数」双事实源 | 3 处调用点已迁移 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| flutter analyze | 无问题 | 2026-08-21 |
| flutter test | 612 项全部通过 | 2026-08-21 |
| tool/verify_changed_dart_format.ps1 | 通过 | 2026-08-21 |
| 双端发布版构建 | 统一在界面焕新系列全部合入后于 main 执行一次 | - |

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

- 界面与交互：圆角/阴影/字号/动效 token 全面升级，页面转场定制
- 测试与工具：无新增测试（token 值由现有 612 项测试回归覆盖）

### 兼容性与迁移

- 本地数据迁移：无
- API 或领域契约变化：SparkDesignTokens 删除 interactiveShadow/floatingShadow const（库内调用点已全部迁移）；SparkFontSizes/SparkDesignTokens/MotionTokens 新增字段
- 旧版本兼容性：无影响

### 已知风险与回滚

- 已知风险：TextTheme 补全改变未显式覆盖样式的 Material 组件默认字号（Chip/Dropdown/TabBar 等）——这正是目标，但观感需人工验收
- 回滚方式：revert 本分支合并提交

### 文档更新建议

- 开发计划不受影响（基础设施升级）

### 未完成与后续工作

- P2 组件现代化将消费新 token；radius2Xl/radius3Xl 与语义名并存的收敛在 P2 顺带进行

## 合并归档（合并后在 main 补齐）

- 最终状态：
- 合入分支：
- 最终集成提交：
- 合并时间：
- main 集成验证：
- 开发计划更新：
- 最终后续项：
