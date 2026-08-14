# Phase 4.3 匿名画像推荐请求契约任务台账

> 状态：已合并
> 最近更新：2026-08-14

## 目标

建立「匿名偏好画像随推荐请求上送」的端到端契约（不含任何原始行为事件）：

1. 服务端 `anonymous_profile.py`：AnonymousProfile（profile.v1 + 主题/关键词/会议权重）、base64url 编解码、校验（版本已知、每类键数 ≤ 64、权重为有限数且在 [-10,10]）。
2. `api.py` recommended：解析 `profile` 参数，非法输入 400；解析结果传入推荐引擎（4.4 前仅记入 batch 特征快照，不参与评分）。
3. 客户端 `PaperFeedQuery` 增补画像字段；`PaperApiClient` 编码上送；`PaperFeedController` 推荐查询从本地画像填充。
4. 契约测试：服务端解析/校验/边界；客户端编码与请求参数；端到端往返一致。

## 非目标

- 画像不参与评分（4.4/4.5）。
- 不上送原始行为事件（隐私边界不变）。

## 分支与基线

- 分支：`feature/phase4-anon-profile-contract`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-1`
- 基线：`1f2a5c6`
- 负责人：Fantasy（编排者，目标迭代授权）；执行：DeepSeek Agent

## 验收标准

- [x] 服务端解析校验单测（合法/超限/非法版本/非法权重）
- [x] API 非法 profile 返回 400、合法返回 200
- [x] 客户端编码与服务端解码往返一致
- [x] 控制器推荐查询携带画像
- [x] `pytest` 与 `flutter analyze/test` 全量通过

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| `python -m pytest tests/test_anonymous_profile.py` | 8 项通过 | 2026-08-14 |
| `python -m pytest tests/test_api.py::ApiTest::test_recommended_accepts_anonymous_profile` | 通过（合法 200/非法 400） | 2026-08-14 |
| `python -m pytest -q`（全量） | 149 项通过 | 2026-08-14 |
| `flutter test test/anonymous_profile_contract_test.dart` | 2 项通过（含无原始行为断言） | 2026-08-14 |
| `flutter analyze` / `flutter test`（全量） | 无问题 / 601 项通过 | 2026-08-14 |
| preview 画像仓库改内存实现 | 修复 widget 测试 FakeAsync 下文件 IO 挂起 | 2026-08-14 |

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| 待提交 | `新增（推荐）：匿名画像推荐请求契约` | 实现 | pytest 149、flutter 601 全过 |

## 合并归档

- 合并方式：本地快进合并（`main` `1f2a5c6..7463d74`）
- 最终集成提交：`7463d74`
- 合并时间：2026-08-14
- 集成验证（/finish 双目标构建，Windows 已清理重建并核验时间戳）：
  - Windows release：`build/windows/x64/runner/Release/spark.exe`，101,888 bytes，SHA-256 `688D2F426838FD14FBD2DF1A8845F86A7995DA137E4D6955DC574A268696F56C`
  - Android development profile：`build/app/outputs/flutter-apk/app-development-profile.apk`，119,671,692 bytes，SHA-256 `1C43FEC29EE4488D01E3F28576FDC2EA9165B63A43FAA2163144EE57207A8BFA`
  - Gradle daemon：`--stop` 后无运行中残留
- 真实后续项：4.4 Personalized Pool 候选召回（下一迭代基线，复杂任务走 workflow + openai/gpt-5.6-sol）。

## 审查结论

只读审查：服务端校验（版本/键数上限/权重有限与边界）非法输入 400；客户端 base64url 编码不含任何原始行为事件；控制器从本地画像快照填充推荐查询；preview 使用内存画像仓库避免测试环境文件 IO 挂起，生产仍走 FileProfileStore。generate 接受画像参数但 4.4 前不参与评分（契约预留）。无阻断项。
