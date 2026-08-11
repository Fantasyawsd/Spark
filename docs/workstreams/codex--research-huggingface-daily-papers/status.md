# 论文数据与推荐规划任务台账

## 基本信息

- 任务：Hugging Face Daily Papers、论文数据底座与推荐系统规划
- 关联发布或里程碑：当前论文数据服务主线，不绑定发布版本
- 分支：`codex/research-huggingface-daily-papers`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\codex--research-huggingface-daily-papers`
- 基线提交：`009e36527885af637d65b58db0a69721526e6e03`
- 负责人：Fantasy（编排者）
- 状态：已合并
- 最近更新：2026-08-11 19:36

## 目标

把 Hugging Face Daily Papers、arXiv、OpenAlex、Semantic Scholar 与 GitHub 的论文数据服务和推荐系统规划收敛到唯一开发计划，并保留统一领域词汇表。

## 非目标

- 不实现服务端、数据库、抓取任务、推荐算法或 Client 接口。
- 不连接 A100，不下载论文数据或模型。
- 不修改 Flutter 生产代码、测试或依赖。

## 验收标准

- [x] 开发计划只保留当前生产能力、真实缺口、进行中/待办任务和 Phase 1–5 主线。
- [x] OpenAlex 与 Semantic Scholar 均进入 Phase 1，跨源引用数保持独立，不直接相加。
- [x] HF API、时间语义、限流、缓存、许可与 Blogs 社区边界已进入开发计划。
- [x] PDF/六问线标记为暂缓，side chat 的 fork、临时提示和不持久化规格得到保留。
- [x] 有效研究结论完成整合，`docs/research/` 及其索引和引用已删除。
- [x] `CONTEXT.md` 记录论文身份、信号、候选池与频道的统一领域语言。
- [x] Markdown 本地/外部链接、尾随空格和 `git diff --check` 通过。

## 写入范围

### 独占路径

- `CONTEXT.md`
- `docs/workstreams/codex--research-huggingface-daily-papers/status.md`
- `docs/research/`（内容整合后删除）

### 共享路径

- `docs/README.md`
- `docs/development.md`
- 合并前发现 `main` 的 `docs/development.md` 存在未提交重叠改动；经编排者确认，将 OpenAlex/Semantic Scholar 规划与其中 PDF 暂缓、side chat 规格一并整合，随后恢复控制工作树到干净基线。

## 依赖关系

- 上游任务：无
- 外部接口或数据源：arXiv、Hugging Face Hub、OpenAlex、Semantic Scholar、GitHub；本任务仅记录契约和规划，不执行线上写入。

## 实施计划

1. 核对当前代码、开发计划和外部一手接口契约。
2. 建立领域词汇并将数据源、字段、频道和推荐规则写入开发计划。
3. 删除旧优先级、完成事项和重复研究文档，更新当前状态与任务。
4. 处理 `main` 重叠文档语义，验证后提交并合并。

## 当前进度

- 已完成：任务提交已合入 `main`；规划、术语、索引和研究内容已收敛；合并前文档门禁与合并后完整集成验证均通过；双目标构建产物已记录。
- 正在进行：无，任务已完成归档。
- 下一步：按开发计划启动 Phase 1 论文数据底座实现任务。
- 阻塞项：无

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-11 | 保留根 `CONTEXT.md` | 编排者确认继续使用领域词汇表 | 后续论文与推荐术语需同步维护 |
| 2026-08-11 | 研究结论并入唯一开发计划并删除 `docs/research/` | 避免计划、研究文档形成重复事实源 | 开发计划直接保存长期接口和运维约束 |
| 2026-08-11 | OpenAlex 与 Semantic Scholar 都接入 Phase 1 | 编排者明确要求保留两类学术影响来源 | 两来源独立采集、归一化和展示，不直接相加 |
| 2026-08-11 | PDF/六问线暂缓，保留 side chat 规格 | 合并时发现 `main` 有重叠未提交规划，编排者确认需保留 | 客户端任务状态与 §4.3 交互规格已同步 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| Markdown 本地链接检查 | 0 个失败 | 2026-08-11 |
| Markdown 外部链接检查 | 14 个链接，0 个失败 | 2026-08-11 |
| 尾随空格检查 | 0 个问题 | 2026-08-11 |
| `git diff --check` | 通过 | 2026-08-11 |
| 研究目录与引用检查 | `docs/research/` 不存在，无残留引用 | 2026-08-11 |
| `tool/verify_changed_dart_format.ps1` | 通过；本任务无 Dart 文件变更 | 2026-08-11 |
| `flutter analyze` | 通过；No issues found | 2026-08-11 |
| `flutter test` | 通过；407 项测试全部成功 | 2026-08-11 |
| `flutter build apk --debug --flavor development --dart-define=SPARK_ENV=development` | 通过 | 2026-08-11 |
| `flutter build windows --debug --dart-define=SPARK_ENV=development` | 通过 | 2026-08-11 |

## 审查结论

- 审查日期：2026-08-11
- 阻断项：无
- 缺陷：无已知文档阻断缺陷
- 结论：编排者直接确认“可以合并”；本纯文档任务未执行独立 `/review`，按此次明确批准进入 `/finish`

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `a83b248` | `文档（论文）：规划数据服务与推荐系统` | 规划收敛 | Markdown 链接、尾随空格与 `git diff --check` 通过 |
| `7fbb2b4` | `文档（台账）：补齐论文规划合并准入` | 合并准入 | 任务与控制工作树干净，`main...HEAD` diff 检查通过 |

## 交付准备（合并前收集）

### 交付摘要

Spark 的论文发现规划已收敛为单一开发主线：Phase 1 建立 AI 论文底座并接入 HF、OpenAlex、Semantic Scholar 与 GitHub；Phase 2 提供基础 Feed；Phase 3–5 演进实时热点、个性化和高级推荐。开发计划同步反映当前 Client 能力、服务端未实现边界、PDF 暂缓和 side chat 规格。

### 实际变更

- 领域与业务逻辑：只更新领域词汇与产品规则，不改变运行时逻辑。
- 数据与基础设施：记录 Paper Database、离线同步、跨源身份、字段来源、可空值、限流和推荐信号契约。
- 界面与交互：记录推荐/关注/最新频道语义与 side chat 交互；无界面代码改动。
- 测试与工具：执行纯文档链接、空格和 diff 门禁；未运行 Flutter 代码测试。
- 文档：新增 `CONTEXT.md`，重写 `docs/development.md`，更新 `docs/README.md`，删除已整合的 `docs/research/`。

### 兼容性与迁移

- 本地数据迁移：无
- API 或领域契约变化：仅规划未来 `/api/v1` 和字段协议，当前生产 API 无变化
- 旧版本兼容性：无运行时影响

### 已知风险与回滚

- 已知风险：第三方接口、计费、限流和许可会变化，实施前必须重新核对官方契约；当前文档不代表能力已上线。
- 回滚方式：对任务文档提交执行 `git revert`；没有数据库、用户数据或运行时迁移影响。

### 文档更新建议

- 开发计划已经完成本任务所需更新；合并后只需在本台账记录真实集成 SHA、构建证据和最终后续项。

### 未完成与后续工作

- Phase 1–5、PDF/六问恢复、side chat、相关论文和个人数据任务均按开发计划后续实施。

## 合并归档（合并后在 main 补齐）

- 最终状态：已合并并完成归档
- 集成提交：`d98d13cb51f131b04a6fa95aa31c88456b98b390`
- Pull Request：无；经编排者明确批准后执行本地非快进合并
- 合并时间：2026-08-11 19:32（Asia/Shanghai）
- 集成验证：格式门禁、`flutter analyze`、407 项 `flutter test`、development APK 与 Windows debug 构建全部通过
- APK：`C:\Users\Fantasy\Desktop\Spark-worktrees\Spark\build\app\outputs\flutter-apk\app-development-debug.apk`；193,305,007 bytes（184.35 MiB）；SHA-256 `FD3CF5838347BF7A5CF191778F72356966C4B85FD4C548143A90F0FB135EFF83`
- Windows EXE：`C:\Users\Fantasy\Desktop\Spark-worktrees\Spark\build\windows\x64\runner\Debug\spark.exe`；1,278,976 bytes（1.22 MiB）；SHA-256 `7C27356B6774A41377FC9E5232F8CEBE9A80F074415ABABF2B39B6F5574F3214`
- 开发计划：已在 `docs/development.md` 记录 OpenAlex、Semantic Scholar、HF Daily Papers、GitHub、频道与推荐系统 Phase 1–5 主线，并保留 PDF 暂缓和 side chat 规格
- 后续项：另立任务实施 Phase 1；本台账转为只读归档，除勘误外不再更新
