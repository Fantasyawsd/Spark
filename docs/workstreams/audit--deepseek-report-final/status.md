# DeepSeek 报告最终审计台账

> 状态：待合并
> 最近更新：2026-08-14

## 目标

基于前序修复批次的最终台账，逐项复核 DeepSeek Spark 代码分析报告中的高危、中危、服务端和测试缺口条目；修复最后仍成立的公共 API 暴露问题，并为已处理或已不成立条目保留证据。

## 非目标

- 不合入 `main`，不进行客户端人工验收，不构建 APK/EXE。
- 不重复修改前序批次已完成且审查通过的代码。
- 不把文件规模本身当作必须继续拆分的行为缺陷；只处理有明确边界收益的问题。

## 分支与基线

- 分支：`audit/deepseek-report-final`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-51`
- 基线：`78dabf8`

## 本批修复

- 从 `lib/spark.dart` 移除未接入组合根的 `paper_sync_service.dart` 和 `paper_sync_ports.dart` 导出。
- 将同步和来源测试改为从论文模块内部契约导入。
- 扩展公共 API 门禁，防止这两个同步入口重新暴露。

## 报告条目结论

### 已修复并有代码/测试证据

- 架构门禁盲区：第 2 批增加同 feature 层依赖、循环依赖、domain 外部包、core 复用和公共入口门禁。
- `paper_ai_message_view.dart` 外链与 URI 校验：第 3 批提取平台链接服务和共享 URI 边界。
- `paper_ai_chat_screen.dart` 平台通道与多流程：第 4 批拆分屏幕边界和键盘平台适配。
- 关注状态双源：第 5 批统一互动状态来源。
- 异常吞掉与零日志：第 6 批建立 `SparkDiagnostics`，生产 broad catch 均保留 error/stackTrace 或显式诊断边界。
- `spark_app.dart` 上帝壳：第 7 批拆分启动、导航壳和应用会话。
- ThemeController 单例：第 8 批改为组合根注入。
- Markdown、Feed、Chat、Reader、Composer、PDF：第 16、18、21、22、24、25、26、29、40、41、42、46 批完成边界拆分。
- 领域 Record/Mapper 混用：第 10、27、32、33、34、38、39 批完成分层。
- 缓存键时间窗口、arXiv 分类、FNV 重复、JSONL null、死 messages 模块、demo 夹具：第 11、17、23、15、14 批修复。
- provenance N+1、服务端空摘要/伪造时间/OpenAlex topic/冲突统计/身份决策/Schema/数据集/索引/同步存储：第 19、1、43、45、47、48、49 批修复。
- Mapper 基础重复：第 31、50 批收敛 `PaperJsonValueReader`。
- 文件仓储样板：第 35 批以窄 `PaperFilePersistence` 收敛同构论文仓储；剩余仓储具有不同流通知、TTL/LRU、List 载荷或迁移语义，不再建立通用基类。
- 测试缺口：第 12、13、36、37、44 批补充关键词、凭据、导航、展示屏拆分测试。

### 本批修复

- 根 barrel 仍暴露未接线同步 application/domain：本批移除两个导出并补静态门禁；同步实现仍可由模块内部测试直接覆盖。

### 已复核不成立或属于有意保留边界

- `TopicChip` 实际位于 papers 模块并由三个论文组件使用；`ProfileAvatar` 位于 community 模块，不属于 core 复用违规。
- `CherryButton` 已不存在；现有 `CherryIconButton` 在 papers header 有四处生产调用。
- `paper_reader_view.dart` 不再直连 keyword repository，架构测试固定该约束。
- `PaperEnhancement.applyEnhancement` 已由第 10 批改为完整字段复制并有测试。
- arXiv OAI/OpenAlex data client 仍保留为论文模块内部同步能力；本批收紧稳定根 API，未删除内部能力。
- `storage.py` 已由第 27、43、45、47、48、49 批拆分合并、身份、Schema、数据集、索引和同步生命周期；剩余查询方法属于在线论文查询边界，不再机械拆分。

## 验收标准

- [x] 未接线同步实现不再由 `lib/spark.dart` 稳定公开。
- [x] 既有同步和来源测试继续覆盖内部实现。
- [x] 报告条目逐项给出已修复或不成立结论。
- [x] 完整 Flutter 门禁和只读审查通过。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| 定向公共 API、同步和来源测试 | 8 项通过 | 2026-08-14 |
| `./tool/verify_changed_dart_format.ps1 -BaseRevision 78dabf8` | 4 个文件通过 | 2026-08-14 |
| `flutter analyze` | No issues found | 2026-08-14 |
| `flutter test` | 582 项通过 | 2026-08-14 |
| `git diff --check` | 通过 | 2026-08-14 |
| 只读报告复核 | 未发现仍需修复的报告条目；剩余规模差异均已有边界拆分或属于有意保留的模块内部能力 | 2026-08-14 |

## 审查结论

通过。第 51 批修复了最后一个仍成立的报告问题；前序批次均有独立代码/测试/台账证据。未合入 `main`，工作树保持为可继续交接的任务分支。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `a07ba6e` | `修复（公共 API）：隐藏未接线同步入口` | 实现 | Flutter 582 项、分析、格式通过 |
| `9eff65c` | `文档（审计）：记录 DeepSeek 报告最终结论` | `/test` + `/review` | 逐项记录报告结论 |
