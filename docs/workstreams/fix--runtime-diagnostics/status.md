# 任务台账

## 基本信息

- 任务：建立隐私安全的运行时诊断边界并消除异常吞没
- 关联发布或里程碑：DeepSeek 代码分析报告问题 #5 修复，不绑定发布版本
- 分支：`fix/runtime-diagnostics`
- Worktree：`C:\Users\Fantasy\Desktop\Spark-worktrees\agent-6`
- 基线提交：`4474bcffd8a1e9c49baba0be9bfe1b7398d35c5c`
- 负责人：Fantasy（编排者）
- 状态：审查回修复测通过，待重新审查
- 最近更新：2026-08-13 18:45

## 目标

为 Flutter 客户端与 Paper API 服务端建立可测试、隐私安全的运行时诊断边界；在保留离线优先、取消、缓存 best-effort 和用户友好错误提示的前提下，让所有被最终消费的意外异常携带固定操作标识、异常类型和 stack trace 进入诊断通道，消除生产故障无根因证据的问题。

## 非目标

- 不记录 DeepSeek API Key、Authorization header、提示词、论文正文、聊天内容、原始请求/响应、完整查询参数或数据文件内容。
- 不把预期的格式探测失败、用户取消、已持久化的坏记录拒绝和已转换后继续上抛的异常重复记录为故障。
- 不改变论文 Feed、搜索、PDF、ChatPaper、本地存储和同步管线的用户可见降级语义。
- 不引入远程日志 SaaS、遥测上传、用户标识或新的服务端部署能力。
- 不处理 DeepSeek 报告中的其他问题；后续批次继续基于本任务最终审查提交串联创建 worktree。
- 不合入 `main`，不启动 Windows App，也不进行人工验收。

## 验收标准

- [x] 客户端提供跨 feature 复用、可替换测试 sink 的诊断接口；默认输出只包含固定 operation、severity、异常运行时类型和 stack trace，不调用异常 `toString()`，不接受任意上下文 payload。
- [x] Flutter framework、platform/async 顶层未处理错误进入同一诊断边界，并保持 Flutter 默认错误呈现与进程级错误传播契约。
- [x] `lib/` 内现有 25 处匿名 `catch (_)` 与 16 处无绑定变量的 `on Object` 完成逐项分类；另修复报告漏检的 5 处无绑定变量 `on Exception`：最终消费的意外异常被报告，取消等预期控制流不记录，转换后继续上抛路径保留原 stack 且不重复记录。审查回修后 PDF 下载/worker 仅转换并保留 stack，由全文入口统一记录一次。
- [x] Feed、搜索、离线仓储、缓存、本地 JSON、PDF、聊天持久化与展示操作的既有 fallback/错误提示不变，并由定向回归覆盖诊断事件和业务结果。
- [x] 服务端使用 Python 标准 logging 在 HTTP/CLI/同步边界记录安全的操作事件与 stack trace；已写入同步报告或拒绝计数的预期数据问题不重复记录原始记录。
- [x] Paper API 未预期分发及响应序列化异常返回固定 `internal_error` 响应，不再向客户端暴露底层异常文本；400 参数错误契约保持不变。审查回修后只有专用请求校验异常返回 400，内部 `ValueError` 进入固定 500。
- [x] 客户端与服务端隐私回归证明密钥、提示词、论文/聊天内容、请求查询、CLI 参数和原始数据不会进入捕获的诊断文本；内部 `ValueError` 文本也不会进入响应或日志。
- [x] 静态门禁禁止新增匿名 broad catch；Dart 格式检查、`flutter analyze`、Flutter 全量测试、服务端全量测试、Python 编译和 `git diff --check` 通过；审查回修后的第二次 `/test` 全量门禁亦通过。

## 写入范围

### 独占路径

- `lib/src/core/diagnostics/`
- `test/runtime_diagnostics_test.dart`
- `server/spark_papers/diagnostics.py`
- `server/tests/test_diagnostics.py`
- `docs/workstreams/fix--runtime-diagnostics/status.md`

### 共享路径

- `lib/main.dart`、`lib/src/app/`：仅接入客户端顶层诊断边界。
- `lib/src/core/storage/local_json_store.dart`：仅补原子写恢复失败的诊断，不改变恢复顺序。
- `lib/src/features/{papers,search,chat,local_data}/`：仅改造最终消费异常的 catch 与对应测试，不重构业务职责。
- `test/architecture_boundaries_test.dart`：增加匿名 broad catch 与生产代码禁止旁路诊断入口的静态门禁。
- `server/spark_papers/{api,cli,pipeline,dataset,storage,sources}.py`：仅补进程/请求/同步边界诊断和响应脱敏，不改变数据契约与同步算法。
- `server/tests/`：仅增加诊断、脱敏及既有错误契约回归。

## 依赖关系

- 上游任务：`refactor/follow-state-single-source@4474bcffd8a1e9c49baba0be9bfe1b7398d35c5c`，以及此前串联完成的报告问题修复批次。
- 外部接口或数据源：无；所有诊断与错误路径使用 fake、临时目录和本地测试服务验证。

## 实施计划

1. 第一轮：在 `lib/src/core/diagnostics/` 建立固定 operation、最小事件模型、默认 sink、Zone 测试 sink 与 Flutter 顶层绑定；修改 `lib/main.dart`，以 `test/runtime_diagnostics_test.dart` 覆盖隐私和原错误处理器传播。
2. 第二轮：扩展 `runtime_diagnostics.dart` 固定 operation；改造 `paper_feed_controller.dart`、`paper_search_controller.dart`、`offline_first_paper_catalog_repository.dart`、`paper_api_catalog_repository.dart` 和 `local_json_store.dart`，并在四个既有测试文件中同时断言诊断事件与原 fallback。
3. 第三轮：扩展 PDF/Chat/外链固定 operation；改造 PDF provider/service、Chat conversation/session controller、DeepSeek SSE request、Reader、Sources panel 与 Chat app bar，并在对应定向测试中区分用户取消和取消清理失败。
4. 第四轮：扩展本地数据、评论、频道偏好、交互、关键词、阅读和翻译固定 operation；改造 7 个状态控制器的读取、保存、清理和生成失败边界，在对应 7 个测试文件中同时断言诊断事件与原 fallback；在 `architecture_boundaries_test.dart` 增加匿名 broad catch 静态门禁。
5. 第五轮：新增 `server/spark_papers/diagnostics.py`，以固定 operation、异常类型和不含异常文本/局部变量的文件名-行号-函数 stack 使用 Python 标准 logging；HTTP 防御边界固定 500 响应，CLI 按固定子命令记录未预期失败；`SourceError`、逐记录拒绝和导入失败状态保持原报告/计数及继续传播语义，不重复日志；在 API、CLI、pipeline 与独立诊断测试中覆盖事件、stack、400/500 和隐私。
6. 第六轮：在客户端诊断总测试中校验全部固定 operation 的唯一性、安全字符集和异常零字符串化；在架构测试中禁止生产 Dart 代码绕过统一入口直接输出日志；在服务端诊断总测试中加入同等 operation/旁路日志门禁，并补强 HTTP/CLI 单次故障仅产生一个安全事件。定向验证通过后，另行执行 `/test` 全量门禁并进入 `/review` 只读审查。
7. 审查回修：在 `server/spark_papers/api.py` 用专用请求校验异常隔离 400 与内部 500，并在 `server/tests/test_api.py` 锁定内部 `ValueError` 的固定响应、单事件和隐私；在 `paper_pdf_extraction_service.dart` 让下载/worker 转换仅保留原 stack 并继续传播，由全文入口作为唯一报告边界，移除失去生产调用方的 PDF 中间层 operation，在 `paper_pdf_test.dart` 与 `paper_ai_chat_app_bar_test.dart` 覆盖中间层零事件和真实串联单事件。

## 当前进度

- 已完成：读取强制文档、原分析报告及 Paper API、真实数据导入、历史稳健性修复台账。
- 已完成：基于 agent-5 最终审查提交创建 `fix/runtime-diagnostics` 与 `agent-6`，确认 `main` 保持 `5578a77d12dd3779940d2352d216e1f766ab47fa`。
- 已完成：扫描确认客户端存在 25 处匿名 catch、16 处无绑定 broad catch，服务端业务包存在 35 处 exception handler；现有客户端无顶层诊断接线，服务端无标准 logging 调用。
- 已完成：第一轮 `/develop` 建立固定 operation 与最小事件模型，默认 sink 不接收异常文本或任意 payload；测试可通过 Zone 注入捕获 sink。
- 已完成：`main.dart` 在同一受保护 Zone 内初始化 Flutter binding 与 `runApp`；framework、platform 和 Dart 未处理错误统一报告，且原 handler 返回值与父 Zone 传播保持不变。
- 已完成：第二轮 `/develop` 迁移 Feed、搜索、Paper API/arXiv/cache 多级回退中最终消费异常的 catch；缓存与远程降级记录 warning，仓储继续抛至控制器的最终故障记录 error。
- 已完成：本地 JSON Windows 原子替换恢复路径改为显式保存原 error/stack 后继续抛出，不在中间层重复记录；本轮五个生产文件均无匿名 broad catch。
- 已完成：第三轮 `/develop` 覆盖 PDF 缓存/下载/worker 解析、ChatPaper 会话设置与消息持久化、会话列表、AI 请求、SSE 取消清理、关键词/分享/外链/全文加载；原 fallback 与用户提示保持不变。
- 已完成：用户主动取消仍是无诊断事件的预期控制流；取消订阅自身失败记录 warning，且不会覆盖向调用者返回的取消结果。
- 已完成：PDF worker 将未预期解析失败的固定异常类型和原 stack trace 跨 isolate 送回诊断边界，不调用异常 `toString()`；已知 `PaperPdfException` 不重复记录。
- 已完成：第四轮为本地数据、评论、频道偏好、交互、关键词、ChatPaper 上下文、阅读和翻译增加固定 operation；15 处无绑定 `on Object` 与报告漏检的 5 处无绑定 `on Exception` 已全部归零。
- 已完成：DeepSeek 普通/联网服务的异常转换路径使用原 stack 继续上抛，由最终会话控制器统一记录；关键词与翻译取消保持零诊断事件。
- 已完成：架构测试新增生产 Dart 代码 broad-catch 门禁，同时禁止匿名 catch 变量及无绑定 `on Object`/`on Exception`。
- 已完成：第五轮新增仅接受固定枚举 operation 的服务端诊断模块；日志只含 operation、异常运行时类型及最多 20 帧的文件名/行号/函数 stack，不持有异常对象且不调用异常字符串化。
- 已完成：Paper API 分发和 JSON 序列化异常统一记录一次并返回固定 500；400 仍保留原 `invalid_request` 契约，默认 HTTP access log 继续关闭以免泄露查询。
- 已完成：CLI 按五个固定子命令记录最终未预期异常并固定退出 1；显式 `SystemExit`、`KeyboardInterrupt`、`SourceError` 报告、分页拒绝和数据集坏行计数不重复记录。
- 已完成：第六轮遍历客户端与服务端全部固定 operation，锁定唯一性、安全字符集和异常零字符串化；生产 Dart/Python 模块禁止绕过统一诊断入口直接接入日志实现。
- 已完成：HTTP 与 CLI 未预期失败的隐私回归明确断言单次故障恰好产生一条事件；ChatPaper 分层失败回归保持最终控制器单次记录。
- 已完成：独立 `/test` 全量门禁通过；Flutter 523 项、服务端 62 项、格式、静态分析、Python 编译与空白检查均成功。
- 已完成：`/review` 从任务基线 `4474bcf` 逐项核对 59 个改动文件、结构阻断条件、验收标准与全量测试证据。
- 已完成：审查回修引入专用 `_InvalidRequestError`；显式 cursor/sort/year/following/seed/limit/date/请求目标校验保持 400，内部 `ValueError` 记录一次并返回固定 500。
- 已完成：PDF 下载与 worker 只映射友好异常并保留原 stack，不在中间层记录；全文入口成为唯一报告边界，四个失去生产调用方的 PDF 中间层 operation 已删除。
- 已完成：新增真实 PDF 下载/worker 到全文入口的串联回归，分别证明中间层零事件、最终边界恰好一条事件；服务端新增内部 `ValueError` 隐私回归。
- 已完成：补强 PDF worker 栈契约；服务级回归锁定 isolate 内 `_extractSynchronously` 根因，最终消费级回归锁定 `_runExtractionWorker` 异步完成边界，避免只断言非空栈而放过证据退化。
- 已完成：审查回修后的第二次 `/test` 全量门禁通过；Flutter 524 项、服务端 63 项、格式、静态分析、Python 编译与空白检查均成功。
- 下一步：重新进入 `/review`，只读复核两个原阻断项、完整 diff 与最新测试证据。
- 阻塞项：无。

## 决策记录

| 日期 | 决策 | 原因 | 影响 |
| --- | --- | --- | --- |
| 2026-08-13 | 基于 `agent-5@4474bcf` 串联创建 agent-6，不以 `main` 为基线 | 编排者要求每批修复继承上一批最终结果且不合入 main | 本批包含前五批全部修复；main 保持不变 |
| 2026-08-13 | 只在异常被最终消费的边界记录，转换后上抛不重复记录 | 避免同一故障多层重复日志，同时保留根因 stack trace | 每个 catch 必须明确属于最终消费、预期控制流或继续传播之一 |
| 2026-08-13 | 诊断事件拒绝任意 payload 和异常文本，只接受固定 operation、异常类型与 stack trace | 根因可追踪不能以泄露 BYOK、请求内容或论文/聊天数据为代价 | 测试 sink 与默认 sink 使用相同的最小事件模型 |
| 2026-08-13 | HTTP 500 使用固定客户端消息，详细根因只进入服务端诊断 | 当前实现把 `str(error)` 返回给客户端，可能暴露数据库或本机信息 | 500 契约更安全；400 仍返回可操作的参数错误 |
| 2026-08-13 | Zone handler 记录后以原 error/stack 继续向父 Zone 传播；platform handler 沿用原 handler 返回值 | 把错误标记为已处理会改变崩溃、stderr fallback 与宿主监控语义 | 新诊断只增加证据，不吞掉原有顶层错误 |

## 验证记录

| 命令或人工检查 | 结果 | 日期 |
| --- | --- | --- |
| 强制文档、原报告与重叠台账读取 | 通过；确认报告问题 #5 仍成立，且不得记录 BYOK/内容型数据 | 2026-08-13 |
| `rg` 客户端异常扫描 | 25 处匿名 catch、16 处无绑定 `on Object`；需在实现阶段逐项分类 | 2026-08-13 |
| `rg` 服务端异常与日志扫描 | 业务包 35 处 handler；同步失败已有结构化报告/计数，但 HTTP 防御边界会暴露异常文本且全包无标准 logging | 2026-08-13 |
| Git/worktree 预检 | 控制工作树与 agent-5 干净；目标分支和 `agent-6` 未占用；基线为 `4474bcf` | 2026-08-13 |
| `flutter test test/runtime_diagnostics_test.dart` | 通过；6 项覆盖最小事件、异常不字符串化、同步/异步父 Zone 传播、framework 原 handler 与 platform handled 结果 | 2026-08-13 |
| `.\tool\verify_changed_dart_format.ps1` | 通过；跨串联基线识别的 56 个 Dart 文件均无需格式化 | 2026-08-13 |
| `flutter analyze` | 通过；No issues found | 2026-08-13 |
| 论文目录第二轮定向测试 | 通过；`paper_controller`、`paper_search_controller`、offline-first、Paper API 与 versioned local JSON 共 92 项，覆盖每层 operation、事件次数与原 fallback | 2026-08-13 |
| 第二轮匿名 broad catch 扫描 | 通过；Feed、Search、offline-first、Paper API、LocalJsonStore 五个生产文件均为 0 | 2026-08-13 |
| 第二轮 `.\tool\verify_changed_dart_format.ps1` | 通过；跨串联基线识别的 62 个 Dart 文件均无需格式化 | 2026-08-13 |
| 第二轮 `flutter analyze` | 通过；No issues found | 2026-08-13 |
| 第三轮 PDF/Chat/展示层定向测试 | 通过；9 个测试文件共 71 项，覆盖缓存、下载、worker、会话持久化、AI 请求、SSE 取消、Reader、AppBar 与来源面板 | 2026-08-13 |
| `flutter test test/paper_pdf_test.dart` | 最终审查补强后通过；22 项，确认 worker 固定异常类型与 stack 跨 isolate 传递不影响错误映射 | 2026-08-13 |
| 全量 `lib` broad catch 扫描 | 匿名 `catch (_)` 已为 0；无绑定变量 `on Object` 余 15 处，均定位到下一轮本地状态控制器 | 2026-08-13 |
| 第三轮 `flutter analyze` | 通过；No issues found | 2026-08-13 |
| 第三轮 `.\tool\verify_changed_dart_format.ps1` | 通过；跨串联基线识别的 75 个 Dart 文件均无需格式化 | 2026-08-13 |
| 第三轮 `git diff --check` | 通过；实现与测试提交无空白错误 | 2026-08-13 |
| 第四轮本地状态与架构定向测试 | 通过；9 个测试文件共 58 项，覆盖读取/保存/清理/补偿、状态回滚、启动 mutation 重放、生成、取消及 broad-catch 门禁 | 2026-08-13 |
| DeepSeek 普通/联网服务回归 | 通过；2 个测试文件共 13 项，确认异常映射保留原业务契约与请求取消隔离 | 2026-08-13 |
| 全量 `lib` broad catch 扫描 | 通过；匿名 catch、无绑定 `on Object`、无绑定 `on Exception` 均为 0 | 2026-08-13 |
| 第四轮 `flutter analyze` | 通过；No issues found | 2026-08-13 |
| 第四轮 `.\tool\verify_changed_dart_format.ps1` | 通过；跨串联基线识别的 92 个 Dart 文件均无需格式化 | 2026-08-13 |
| 第四轮 `git diff --check` | 通过；实现与测试提交无空白错误 | 2026-08-13 |
| 第五轮服务端定向测试 | 通过；diagnostics、API、CLI、pipeline、dataset 共 35 项，覆盖固定 operation、脱敏 stack、400/500、CLI 退出和预期同步零日志 | 2026-08-13 |
| `python -m unittest discover -s server/tests` | 通过；服务端全量 60 项 | 2026-08-13 |
| `python -m compileall -q server/spark_papers server/tests` | 通过；生产包与测试均可编译 | 2026-08-13 |
| 第五轮 `flutter analyze` | 通过；No issues found | 2026-08-13 |
| 第五轮 `.\tool\verify_changed_dart_format.ps1` | 通过；跨串联基线识别的 92 个 Dart 文件均无需格式化 | 2026-08-13 |
| 第五轮 `git diff --check` | 通过；实现与测试提交无空白错误 | 2026-08-13 |
| 第六轮客户端诊断、架构与 ChatPaper 定向测试 | 通过；35 项，覆盖全部 operation 安全性、禁止旁路日志和分层故障单事件 | 2026-08-13 |
| 第六轮服务端诊断、API 与 CLI 定向测试 | 通过；使用 `PYTHONPATH=server` 运行 19 项，覆盖全部 operation 安全性、禁止旁路 logging 与 HTTP/CLI 单事件；首次从仓库根未设置导入路径的调用失败后已按项目布局纠正 | 2026-08-13 |
| 第六轮 `python -m compileall -q server/spark_papers server/tests` | 通过；生产包与测试均可编译 | 2026-08-13 |
| 第六轮 `flutter analyze` | 通过；No issues found | 2026-08-13 |
| 第六轮 `.\tool\verify_changed_dart_format.ps1` | 通过；跨串联基线识别的 92 个 Dart 文件均无需格式化 | 2026-08-13 |
| 第六轮 `git diff --check` | 通过；测试门禁提交无空白错误 | 2026-08-13 |
| `/test` 预检 | 通过；`fix/runtime-diagnostics@d075ae1d2abb` 工作区干净，控制工作树 `main` 仍为 `5578a77d12dd` | 2026-08-13 |
| `/test` `.\tool\verify_changed_dart_format.ps1` | 通过；跨串联基线识别的 92 个 Dart 文件均无需格式化 | 2026-08-13 |
| `/test` `flutter analyze` | 通过；No issues found | 2026-08-13 |
| `/test` `flutter test` | 通过；Flutter 全量 523 项 | 2026-08-13 |
| `/test` `python -m unittest discover -s tests`（`server` 工作目录） | 通过；服务端全量 62 项；此前从仓库根未设置模块路径的调用在测试加载前失败，已按服务端目录布局纠正 | 2026-08-13 |
| `/test` `python -m compileall -q spark_papers tests`（`server` 工作目录） | 通过；生产包与测试均可编译 | 2026-08-13 |
| `/test` `git diff --check` | 通过；测试前工作区干净，无空白错误 | 2026-08-13 |
| `/test` 目标构建与人工验收 | 未运行；APK/Windows release 构建属于 `/finish`，本任务明确不合入 `main`；编排者明确无需人工验收 | 2026-08-13 |
| `/review` 完整改动读取与结构核对 | 完成；任务基线 `4474bcf` 至 `18e34b7` 共 59 文件、3087 行新增、183 行删除；10 条结构阻断条件均未触发 | 2026-08-13 |
| `/review` 内部 `ValueError` HTTP 复现 | 未通过；令 `PaperStore.count()` 抛出 `ValueError('token=private-db-secret')`，实际得到 `(400, {'error': 'invalid_request', 'message': 'token=private-db-secret'})` 且绕过诊断 | 2026-08-13 |
| `/review` PDF 分层事件流核对 | 未通过；下载/worker 边界先报告并转换为 `PaperPdfException`，`PaperAiChatAppBar._toggleFullText` 的 broad catch 对同一异常再次报告，现有测试仅分别验证各层而未覆盖端到端去重 | 2026-08-13 |
| 审查回修 Flutter 定向测试 | 通过；PDF service、全文入口、诊断总测试与架构门禁共 44 项，真实下载与 worker 串联均只有 `chatLoadFullText` 一条事件且保留原 stack | 2026-08-13 |
| 审查回修服务端 API/诊断定向测试 | 通过；10 项，内部 `ValueError` 固定 500、单事件且不泄露，显式日期与 seed 校验保持无日志 400 | 2026-08-13 |
| 审查回修 `python -m unittest discover -s tests` | 通过；服务端全量 63 项 | 2026-08-13 |
| 审查回修 Python 编译、`flutter analyze` 与 Dart 格式 | 通过；Python 包与测试可编译，Flutter 无静态问题，92 个 Dart 文件格式通过 | 2026-08-13 |
| 审查回修 `git diff --check` 与失效 operation 扫描 | 通过；无空白错误，四个 PDF 中间层 operation 在生产与测试中均无残留引用 | 2026-08-13 |
| 审查回修 PDF 根因栈定向测试 | 通过；`paper_pdf_test.dart` 与 `paper_ai_chat_app_bar_test.dart` 共 24 项，分别锁定 isolate 根因栈与最终消费异步边界栈；随后 92 文件格式、`flutter analyze` 与 `git diff --check` 通过 | 2026-08-13 |
| 回修后 `/test` 预检 | 通过；`fix/runtime-diagnostics@7e826fd89c00` 工作区干净，控制工作树 `main` 仍为 `5578a77d12dd` | 2026-08-13 |
| 回修后 `/test` `.\tool\verify_changed_dart_format.ps1` | 通过；跨串联基线识别的 92 个 Dart 文件均无需格式化 | 2026-08-13 |
| 回修后 `/test` `flutter analyze` | 通过；No issues found | 2026-08-13 |
| 回修后 `/test` `flutter test --reporter compact` | 通过；Flutter 全量 524 项 | 2026-08-13 |
| 回修后 `/test` `python -m unittest discover -s tests`（`server` 工作目录） | 通过；服务端全量 63 项 | 2026-08-13 |
| 回修后 `/test` `python -m compileall -q spark_papers tests`（`server` 工作目录） | 通过；生产包与测试均可编译 | 2026-08-13 |
| 回修后 `/test` `git diff --check` | 通过；测试前工作区干净，无空白错误 | 2026-08-13 |
| 回修后 `/test` 目标构建与人工验收 | 未运行；APK/Windows release 构建属于 `/finish`，本任务明确不合入 `main`；编排者明确无需人工验收 | 2026-08-13 |

## 审查结论

> 由 `/review` 填写摘要（阻断项、缺陷、结论）。

- 审查日期：2026-08-13
- 阻断项：2 项。① `server/spark_papers/api.py:167-168` 把内部 `ValueError` 当作请求错误并回传异常文本，违反固定 500 与隐私边界；② `paper_pdf_extraction_service.dart:99-105,218-288` 与 `paper_ai_chat_app_bar.dart:213-219` 对同一 PDF 故障分层重复记录。
- 缺陷：现有回归分别覆盖 PDF 服务与全文入口，但缺少串联两层的单事件测试；修复阻断项时必须补充。
- 建议：为当前仅由枚举总测试覆盖的 `chatConversationSessionLoad`、`chatSessionPin` 等分支逐步增加操作级回归，但不单独阻断本任务；PDF worker 中间层 operation 已在回修中删除并改由真实串联测试覆盖。
- 结论：需修复；返回 `/develop`，修复后重新执行 `/test` 与 `/review`。
- 回修状态：两个阻断项已在 `795937d` 修复，并通过定向验证与第二次 `/test` 全量门禁；原审查结论保留为历史，待重新 `/review` 复审。

## 检查点与提交

| SHA | 提交信息 | 对应阶段 | 验证摘要 |
| --- | --- | --- | --- |
| `7657d68` | `新增（诊断）：接入客户端运行时错误边界` | 第一轮 `/develop` 实现 | 诊断最小事件、Zone/default sink、Flutter 顶层绑定与 main 接线；5 项初始定向测试、格式和 analyze 通过 |
| `0dea59d` | `测试（诊断）：覆盖异步错误继续传播` | 第一轮 `/develop` 补强 | 证明异步未处理错误只记录一次并以原对象继续进入父 Zone；定向测试增至 6 项 |
| `e60bf30` | `修复（论文目录）：记录降级链路异常` | 第二轮 `/develop` | Feed/Search/Paper API/arXiv/cache 分层事件与 LocalJsonStack 保真；92 项定向测试、62 文件格式与 analyze 通过 |
| `5cb07d9` | `修复（诊断）：覆盖 PDF 与聊天异常边界` | 第三轮 `/develop` | PDF/Chat/展示层最终消费异常可诊断；71 项定向测试、75 文件格式、analyze 与 diff check 通过 |
| `5889fa7` | `修复（诊断）：覆盖本地状态异常边界` | 第四轮 `/develop` | 客户端 broad catch 归零并加入静态门禁；58 项状态/架构测试、13 项 DeepSeek 回归、92 文件格式与 analyze 通过 |
| `d3f52ca` | `修复（服务端诊断）：脱敏异常日志与固定 500 响应` | 第五轮 `/develop` | HTTP/CLI 安全诊断、固定 500 与预期同步零日志；35 项定向、60 项服务端全量、Python 编译、Flutter analyze 与格式通过 |
| `11f2f44` | `测试（诊断）：锁定隐私与单事件门禁` | 第六轮 `/develop` | 客户端/服务端 operation、旁路日志和单事件总回归；35 项 Flutter 定向、19 项服务端定向、Python 编译、92 文件格式与 analyze 通过 |
| `795937d` | `修复（诊断）：收紧错误分类与单事件边界` | 审查回修 `/develop` | 专用 HTTP 请求校验异常、内部 ValueError 固定 500、PDF 最终边界单事件；44 项 Flutter 定向、10 项服务端定向、63 项服务端全量、Python 编译、格式与 analyze 通过 |
| `8451f05` | `测试（诊断）：锁定 PDF 根因栈` | 审查回修 `/develop` 补强 | 服务级与最终消费级分别锁定 worker 根因栈位置；24 项 PDF/ChatPaper 定向、92 文件格式、analyze 与 diff check 通过 |

## 交付准备（合并前收集）

### 交付摘要

客户端与 Paper API 服务端现已具备统一、可测试且不接收动态 payload 的运行时诊断边界；所有已分类的最终消费异常使用固定 operation 记录异常类型和 stack trace，预期取消/数据拒绝不记录，HTTP 500 不再暴露底层错误文本。首次 `/review` 的两个阻断项已回修，第二次 `/test` 全量门禁通过，待重新 `/review`。

### 实际变更

- 领域与业务逻辑：不改变领域模型；保留现有离线降级、取消、重试和用户提示语义。
- 数据与基础设施：新增客户端与服务端安全诊断适配器；Paper API 未预期错误固定返回 `internal_error`，CLI 未预期错误固定退出 1。
- 界面与交互：仅在展示层最终消费异常处接入诊断，不新增界面或改变交互。
- 测试与工具：新增诊断单元、跨 feature fallback、隐私、operation、单事件、顶层传播和旁路日志静态门禁。
- 文档：持续维护本任务台账；不影响 `docs/development.md` 产品能力状态。

### 兼容性与迁移

- 本地数据迁移：无。
- API 或领域契约变化：Paper API 500 错误消息已固定化；其他 API/领域契约不变。
- 旧版本兼容性：不改变持久化 schema。

### 已知风险与回滚

- 已知风险：诊断不足会遗漏根因，诊断过度会产生重复事件或泄露动态数据；以事件模型和隐私回归共同约束。
- 回滚方式：按实现与台账提交逆序 `git revert`；不涉及数据迁移或远程状态。

### 文档更新建议

- 本任务属于结构性技术债修复，不改变产品路线图能力；不计划修改 `docs/development.md`。

### 未完成与后续工作

- DeepSeek 报告的后续未修复项由新的串联 worktree 继续处理。

## 合并归档（合并后在 main 补齐）

> 编排者明确要求本任务不合入 `main`；本节保持未填写，不执行 `/finish`。

- 最终状态：未合并
- 合入分支：不适用
- 最终集成提交：不适用
- Pull Request：无
- 合并时间：不适用
- main 集成验证：不适用
- 开发计划更新：不适用；本任务仅修复结构性技术债
- 最终后续项：完成重新 `/review` 后，以最终审查提交为下一批 worktree 基线
