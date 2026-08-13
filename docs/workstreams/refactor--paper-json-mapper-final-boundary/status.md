# 论文 JSON Mapper 剩余边界任务台账

> 状态：待合并
> 最近更新：2026-08-14

## 目标

收敛论文缓存与评论 Mapper 中剩余的基础 JSON 类型读取重复，使基础值校验统一通过 `PaperJsonValueReader`，并保持各实体 schema 和业务校验不变。

## 非目标

- 不合并不同实体的 Mapper、Record 或业务校验。
- 不改变字段默认值、必填性、非空约束、日期解析或缓存迁移。
- 不建立跨业务模块的通用 Repository 基类。
- 不进行客户端人工验收，不构建 APK/EXE，不合入 `main`。

## 分支与基线

- 分支：`refactor/file-repository-persistence-final-boundary`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-50`
- 基线：`3674699`

## 验收标准

- [x] 评论 Mapper 不再自带基础字符串、整数、布尔和 Map 读取器。
- [x] 缓存 Mapper 的基础列表、字符串、整数和 Map 读取复用统一组件。
- [x] 缓存必填、非空、可空和默认值语义保持不变。
- [x] 定向测试、完整 `/test` 与只读 `/review` 通过。

## 写入范围

- `lib/src/features/papers/data/paper_json_value_reader.dart`
- `lib/src/features/papers/data/paper_comment_json_mapper.dart`
- `lib/src/features/papers/data/cache/paper_cache_mapper.dart`
- `test/paper_json_value_reader_test.dart`
- `docs/workstreams/refactor--paper-json-mapper-final-boundary/status.md`

## 实施计划

1. 扩展无业务语义的基础 JSON 值读取器。
2. 迁移评论和缓存 Mapper 的重复 helper。
3. 验证缓存 schema、评论异常和读取默认值保持不变。
4. 完成完整门禁、只读审查和原子提交。

## 候选复核记录

- 文件仓储重复：第 35 批已用 `PaperFilePersistence` 收敛同构论文仓储；剩余聊天、PDF/翻译、搜索和频道仓储生命周期不同，不继续通用化。
- OAI/OpenAlex 公共入口：第 20 批已确认根 barrel 不导出 data 实现和同步实现，并有架构门禁防回归；当前 data client 只在内部测试直接引用。
- core 归属：`TopicChip` 位于 papers 模块并由三个论文组件复用，`ProfileAvatar` 位于 community 模块；原报告指向已不成立。

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `flutter test test/paper_json_value_reader_test.dart test/paper_cache_store_test.dart test/file_paper_comment_repository_test.dart test/file_paper_storage_schema_test.dart` | 22 项通过 | 2026-08-14 |
| `./tool/verify_changed_dart_format.ps1 -BaseRevision 3674699` | 4 个文件通过 | 2026-08-14 |
| `flutter analyze` | No issues found | 2026-08-14 |
| `flutter test` | 582 项通过 | 2026-08-14 |
| `git diff --check` | 通过 | 2026-08-14 |
| 只读审查 | 共享读取器只承载基础类型校验；缓存必填字符串/列表、可空字段、默认值、日期、页键和实体关系校验均保持；评论领域字段和错误文案契约保持 | 2026-08-14 |

## 审查结论

通过。Mapper 基础读取重复已收敛，未发现 schema 放宽或业务边界越界。第 35、31、20 批已解决的文件仓储、Mapper 基础校验和公共 API 候选不重复修改。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 待提交 | `重构（论文数据）：收敛剩余 JSON 读取边界` | 实现 | Flutter 582 项、格式和分析通过 |
| 待提交 | `文档（台账）：记录剩余 JSON 边界审查` | `/test` + `/review` | 记录候选复核与验证结论 |
