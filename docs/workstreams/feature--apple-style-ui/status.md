# 任务台账

## 基本信息

- 任务：UI 苹果风（iOS）主题层重塑
- 关联发布或里程碑：无（日常迭代）
- 分支：`feature/apple-style-ui`
- Worktree：`../agent-1`
- 基线提交：`ca0fd28`
- 负责人：Fantasy（编排者）
- 状态：待合并
- 最近更新：2026-09-05

## 目标

把 Spark 全局观感从 Cherry Studio 风格转向 iOS 视觉语言：保留 Material 组件骨架，通过 core 主题层（palette / design tokens / ThemeData）+ 自建组件层 + 页面级硬编码清理完成重塑。深浅色 × 五强调色全矩阵生效。

## 非目标

- 不替换 Material Icons 为 SF Symbols。
- 不引入 Cupertino 组件替换、不建独立设计系统组件库。
- 不改路由、业务逻辑、Markdown 渲染管线。
- 不引入字体文件或 google_fonts；维持系统字体栈。
- 不重排任何页面布局结构。

## 验收标准

- [x] `flutter analyze` 无告警；`flutter test` 全绿（含新增 iOS 基准快照测试与调整后的对比度门限）。
- [x] light/dark 双模式色板对齐 iOS 语义色（canvas #F2F2F7 / dark 纯黑系）；五强调色为 iOS 系统色系变体。
- [x] 卡片无边框靠底色分层；阴影收敛；标题字重降档至 w700/w600。
- [x] AppBar 居中标题 17/w600；Switch 选中态系统绿。
- [x] 用户 Windows 实机验收通过（2026-09-05，编排者反馈「可以」）。

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
6. 本轮补齐开关禁用态：修改 `lib/src/core/theme/spark_theme.dart`，在 `test/spark_theme_test.dart` 覆盖深浅色 × 五强调色 × 开关状态的色彩区分与禁用点击行为；运行定向测试、analyze 与格式检查。

## 当前进度

- 已完成：Phase A（c295b5d）、Phase B（11daa5a）、Phase C（67184bb），2026-08-25 已通过格式检查、analyze 和全量测试；2026-09-05 补齐开关禁用态，26 项定向测试、analyze 和格式检查通过。
- 正在进行：完整门禁与只读审查已通过，编排者已授权推送并合入 main。
- 下一步：推送任务分支 → 合入 main → development APK 与 Windows release 双目标构建 → main 最终归档与推送。
- 阻塞项：无

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-25 | 强调色机制保留，色值向 iOS 系统色对齐；green/orange 用 Apple 加深变体 | 纯 #34C759/#FF9500 配白字对比度不可读 | spark_theme_test 对白门限放宽 ≥3.0 |
| 2026-08-25 | 维持系统字体栈，不引 SF Pro/google_fonts | 版权限制 + 混排基线问题 | 仅靠字重与负字距塑形；Windows 雅黑仅 Regular/Bold 两档，字重降档在 Windows 桌面无视觉差异 |
| 2026-08-25 | dark 模式转中性黑灰系（#000000/#1C1C1E） | iOS 暗色语义 | spark_theme L74-78 蓝黑字面量需一并替换 |
| 2026-08-25 | AppConfig.resolve 环境兜底按 kReleaseMode 裁决（a4ac989） | 漏传 SPARK_ENV 时实验功能静默消失，反复被误判为 UI 改动缺陷；编排者指示"不要让传参决定" | release 构建仍强制 production；显式 flavor/dart-define 可覆盖；AGENTS.md 验收条目无需 dart-define 即正确 |
| 2026-09-05 | 开关禁用态以卡片底色混合减淡，仍区分选中与未选中 | 主题原先忽略 disabled，个性化状态加载期间与可操作开关观感相同 | 保持可用态系统绿，覆盖深浅色 × 五强调色的禁用与点击行为 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `.\tool\verify_changed_dart_format.ps1` | 通过（36 文件） | 2026-08-25 |
| `flutter analyze` | No issues found | 2026-08-25 |
| `flutter test` | 625 项全绿（含新增 iOS 基准快照与门限 3.0 调整） | 2026-08-25 |
| `flutter --version` / `flutter pub get` | Flutter 3.44.8 / Dart 3.12.2；依赖恢复成功 | 2026-09-05 |
| `.\tool\verify_changed_dart_format.ps1` / `git diff --check` | 通过（35 个 Dart 文件）；无空白错误 | 2026-09-05 |
| `flutter analyze` | No issues found | 2026-09-05 |
| `flutter test test/spark_theme_test.dart test/personalization_privacy_controller_test.dart` | 22 项通过（含 10 项开关主题矩阵回归） | 2026-09-05 |
| `flutter test --no-pub test/profile_personalization_section_test.dart` | 4 项通过 | 2026-09-05 |
| `flutter run --no-pub -d windows --release --dart-define=SPARK_ENV=development`（此前已执行 `flutter pub get`） | Windows release 构建成功并已启动；Spark 窗口与 agent-1 产物进程已确认；编排者反馈「可以」，人工验收通过 | 2026-09-05 |

| 合并前格式检查 / `flutter analyze --no-pub` / `flutter test --no-pub` / `git diff --check` | 35 个 Dart 文件格式通过；No issues found；636 项全量测试通过；无空白错误 | 2026-09-05 |

### 备注

- `spark_theme_test` 对白对比度门限由 4.5 放宽至 3.0：iOS 系统色作按钮底色配白字时 Apple 自身即 ~4.0（systemBlue #007AFF = 4.02），已在测试注释中写明依据；暗色对卡片 ≥4.5 门限保留且全部通过。
- 工作区遗留 `windows/flutter/generated_*` 为 Flutter 构建自动再生文件，与本任务无关，不纳入提交，收尾时按仓库惯例处理。
- 2026-09-05 仓库迁移后，从 `D:/Spark-worktrees/Spark` 执行 `git worktree repair D:/Spark-worktrees/agent-1`，修复双方仍指向旧桌面目录的关联；未移动源码或改动分支历史。
- 本轮继续 `/develop`，未重新执行全量测试。编排者随后要求「验收」，已启动 development 配置的 Windows release 应用；未执行 Android 构建，未进入 /test、/review 或 /finish。
- 首次启动因迁移前 `.plugin_symlinks` 残留发生 `PathExistsException`；同时确认 CMake 缓存仍指向旧桌面目录。将 `windows/flutter/ephemeral` 与 `build/windows/x64` 隔离到本任务 `build/relocation-backup-20260905-230913/` 后重新生成，Windows release 在 97.7 秒内构建成功。产物：`build/windows/x64/runner/Release/spark.exe`。

## 审查结论

- 审查日期：2026-09-05
- 审查范围：远端 merge-base 为 `062718611adede28fe7f9558dc918246d0ce3047`；本地 main 已含其后 85 个提交，因此本任务逐文件审查范围为任务基线 `ca0fd28..a238283`（36 文件，582 行新增、268 行删除），未将 main 既有历史当成本任务新改动。
- 阻断项：无。逐项核对架构阻断条件，未新增 Widget I/O、具体仓储耦合、领域平台依赖、DTO 混层、反向或循环依赖、业务 utils、继承链或不可独立测试的业务行为。
- 缺陷：未发现新的阻断性功能回归；AppConfig 非 release 默认 development 属于此前编排者明确要求的修复，未改变显式 flavor/环境校验与 production 功能屏蔽。
- 规格核对：主题色板、卡片与字重、AppBar 默认标题、系统绿与禁用态均有代码或测试依据；636 项测试与 analyze/格式通过；Windows 人工验收通过。社区文件仅两处字重调整，不新增生产入口。
- 建议与限制：保留此前已确认的 3.0 对比度门限，但它不能证明所有小字号文字的可读性；Android 真机视觉效果尚未验收。系统字体在 Windows 的字重显示仍受本机字体影响。
- 结论：可合并。已核对 agent-2 当前修改位于独立 worktree，未纳入本次提交；其后续集成需基于更新后的 main 另行验证。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| c295b5d | 重构（主题）：色板、圆角阴影与组件级主题对齐 iOS 风格 | Phase A | analyze 无问题；spark_theme_test 9 项全绿 |
| 11daa5a | 重构（组件）：自建组件层对齐 iOS 形态 | Phase B | analyze 无问题；全量 625 项全绿 |
| 67184bb | 重构（界面）：页面层字重、论文强调色与 profile 分区对齐 iOS 风格 | Phase C | 格式/analyze/test 三门禁全绿 |
| fa5cbc3 | 文档（台账）：记录苹果风改造三阶段进度与验证结果 | 台账 | — |
| a4ac989 | 修复（配置）：非 release 运行默认 development 环境 | 环境修复 | analyze 无问题；全量 626 项全绿 |
| 470cb66 | 修复（主题）：区分 iOS 开关的禁用状态 | 本轮补齐 | 26 项定向测试通过；analyze 无问题；35 文件格式检查通过 |

## 交付准备（合并前收集）

### 交付摘要

全局色板、圆角、阴影、Material 组件默认主题、自建组件和页面字重对齐 iOS 风格；保留五强调色和深浅色切换，补齐开关禁用态。修复非 release 运行遗漏环境参数时实验功能消失的问题；不改变持久化数据、论文接口或导航结构。

### 实际变更

- 领域与业务逻辑：无
- 数据与基础设施：AppConfig 无显式环境时按构建模式选择默认值（release 为 production，非 release 为 development）；无持久化或网络契约变化。
- 界面与交互：深浅色 × 五强调色、纯黑暗色背景、卡片默认无边框、圆角与阴影收敛、页面标题字重调整、我的分组列表密度，以及系统绿开关的可用/禁用态。
- 测试与工具：主题基准断言、开关状态矩阵及点击测试、AppConfig 默认环境断言；迁移后构建缓存修复仅涉及忽略目录。
- 文档：本台账

### 兼容性与迁移

- 本地数据迁移：无
- API 或领域契约变化：无
- 旧版本兼容性：设备数据与既有 API 保持兼容；非 release 无参数启动现在默认 development。

### 已知风险与回滚

- 已知风险：Windows 实机验收已通过；Android 真机观感尚未验收。部分亮色强调色对白门限保持此前确认的 3.0，未声称完整文字无障碍达标。APK 缺少 release 签名时按规范交付 profile（AOT、debug 签名）。
- 回滚方式：对本次合并提交执行 `git revert -m 1 <merge-sha>`，必要时同步回退开发计划状态；无数据迁移。

### 未完成与后续工作

- Windows 实机验收、/test 与 /review 已通过；待 main 集成、双目标构建及归档。SF Symbols 映射、Cupertino 化深化不在本任务范围。
