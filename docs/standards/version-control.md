# Spark Git 与任务集成管理

> 状态：强制执行
> 最近更新：2026-08-07
> 适用范围：代码、测试、文档、配置和发布产物
> Agent 总规范：[`../../AGENTS.md`](../../AGENTS.md)

## 1. 目标

Git 与集成管理需要同时保证：

- 每个需求有明确目标、验收标准和责任分支；
- 每个任务的代码、状态和记录可以独立追踪；
- 共享文档和公共模块不会因并行修改持续冲突；
- 每个提交可审查、可验证、可回滚；
- main 始终可以说明当前包含哪些任务；
- 开发计划不预先绑定版本，只有进入发布准备后才归入发布版本。

## 2. 分支模型

### 2.1 长期分支

- `main`：只保留完整验证、可发布或明确标记的稳定基线。
- 发布分支：仅在进入发布准备后按需创建，例如 `release/0.2.0`，由编排者（人类）维护。
- 不为普通开发任务预先创建发布分支，也不使用范围持续扩大的长期功能分支代替集成基线。

### 2.2 任务分支

一个分支只交付一个主要业务结果：

```text
<type>/<slug>
feature/paper-channels
fix/pdf-cache
```

分支必须从编排者批准的提交创建。分支名发生失真时应结束当前分支，不继续叠加无关功能。

## 3. Worktree 隔离

每个独立任务使用独立 worktree；即使当前只有一个 Agent，也不直接把新任务叠加到控制工作树。

**唯一合法位置**：所有任务 worktree 必须与控制工作树同级，即 `<控制工作树根>\..\<branch-slug>`（本仓库即 `%USERPROFILE%\Desktop\Spark-worktrees\<branch-slug>`）。

**执行前提**：`git worktree` 命令必须在控制工作树（仓库根目录）内执行；执行前先确认当前目录：

```powershell
git rev-parse --show-toplevel
```

确保输出为控制工作树根路径（本仓库为 `%USERPROFILE%\Desktop\Spark-worktrees\Spark`），再执行创建：

```powershell
git worktree add ..\feature--paper-channels `
  -b feature/paper-channels <approved-base>
```

创建前检查：

```powershell
git branch --show-current
git status --short
git diff --stat
git diff --cached --stat
git log -5 --oneline
git worktree list
```

约束：

- 一个 worktree 只允许一个任务写入。
- 不在开发 worktree 中切换到其他任务分支。
- 不通过复制未提交文件、共享暂存区或压缩工作目录协作。
- 不从脏工作区创建无法追溯的任务基线。
- worktree 路径不得位于仓库内部。
- worktree 目录名固定为 `<branch-slug>`（分支名中 `/` 替换为 `--`），不得使用 `Spark-worktree`（单数）、`Spark-worktrees\Spark-worktrees`（嵌套）等变体。
- 禁止在以下位置创建 worktree：仓库内部（含 `.slim/worktrees/`、`.claude/`、`~/.claude/` 等任何隐藏目录）、仓库的上级目录以外的其他位置。

## 4. 任务台账

每个任务建立单文件台账：

```text
docs/workstreams/<branch-slug>/
`-- status.md
```

使用：

- [`../templates/workstream-status.md`](../templates/workstream-status.md)

`status.md` 由 `/start` 在开始编码前创建，由 `/develop`、`/test` 持续更新。`/finish` 在任务分支上收集合并前交付信息，但不得预写“已合并”或最终集成 SHA；任务真实合入 `main` 后，必须在 `main` 将台账更新为最终状态并提交归档记录。归档提交完成后保留，不删除，除勘误外不再更新。

聊天记录、终端历史和口头说明不能替代台账。

## 5. 写入范围

- 开发时在 status.md 登记独占与共享写入路径，避免与编排者的手动改动冲突。
- 同一时间一个文件只有一个写入任务。
- 必须共同修改的文件改为串行任务，不能依靠最后统一解决冲突。

## 6. 提交原则

提交信息必须使用中文，采用以下格式：

```text
<类型>（<范围>）：<中文主题>

<可选正文>
```

- 类型使用固定中文词：`新增`、`修复`、`重构`、`测试`、`文档`、`构建`、`杂项`。
- 范围填写受影响的业务模块、领域或基础设施名称，例如 `论文`、`ChatPaper`、`版本`；纯文档、全局配置或跨模块变更可以省略范围。
- 主题使用明确的中文动宾短语，说明本次提交带来的结果；不要使用“更新代码”“修改问题”“一些调整”等无法审查的表述。
- 正文用于补充主题无法表达的重要信息。涉及复杂逻辑、数据契约、兼容性或迁移时，至少说明变更背景、主要实现、验证结果和兼容性影响。
- 提交脚注用于记录关联 Issue、Pull Request 或破坏性变更；没有关联信息时不要添加空脚注。

示例：

```text
新增（论文）：支持按频道筛选论文
```

```text
修复（ChatPaper）：恢复流式回答中断后的会话状态

问题：回答请求中断后，输入框仍被错误地锁定。

变更：
- 在请求结束和异常路径统一恢复输入状态。
- 保留已生成的部分回答，允许用户重试。

验证：
- `flutter test`
- `flutter analyze`
```

```text
文档：补充中文提交信息规范
```

一个提交只有一个主要意图，并满足：

- 可以独立解释和审查；
- 代码、测试和契约保持一致；
- 不混入编排者或其他来源的无关改动；
- 不包含大范围无关格式化；
- 可以通过 `git revert` 安全回退。

默认按明确路径暂存：

```powershell
git add -- path/to/file1 path/to/file2
git diff --cached --stat
git diff --cached
git diff --cached --check
```

只有任务独占干净 worktree，并审查全部文件后，才允许整体暂存。

## 7. 检查点

以下节点需要形成提交：

1. 最小纵向闭环完成。
2. 修改领域接口、持久化 schema 或远程契约前后。
3. 用户确认一轮 UI 方案后。
4. 引入新依赖或大范围重构前后。
5. 准备提供公共接口时。
6. 申请人工验收、构建 APK 或合并前。

每个检查点同步更新 `status.md`，记录提交 SHA 和验证结果。

## 8. 审查与合并

申请合并必须提供：

- 完整的合并前任务台账（status.md，最终合并字段允许待填）；
- 干净工作区；
- 可解释的提交列表；
- 定向与完整验证结果；
- 数据迁移和兼容性说明；
- 已知风险和回滚方式。

编排者通过 `/review` 与 `/finish` 按以下顺序处理：

1. 阅读台账和任务规格。
2. 审查提交范围和依赖方向。
3. 检查与已合并任务的路径和契约冲突。
4. 在任务分支补齐交付摘要、验证、兼容性、风险和回滚等合并前信息；此时状态最多为“待合并”。
5. 将任务分支合入 `main`（版本迭代通过 Pull Request）；解决冲突、记录语义决策并形成真实集成提交。
6. 在已包含任务提交的 `main` 上执行要求的格式、分析、全量测试和目标平台构建。日常 `/finish` 至少完成 development APK 与 Windows debug EXE 两个目标构建。
7. 在 `main` 更新对应 `status.md`：标记 `已合并`，记录最终集成 SHA（fast-forward 时记录合入后的 `main` HEAD/任务 tip）或 PR、合并时间、集成验证和真实后续项。
8. 依据合并后的真实能力更新 `docs/development.md`；关联发布时再更新发布进度与清单。不影响开发计划的任务必须在台账归档中明确说明。
9. 将第 7、8 步形成独立的合并后文档归档提交；只有该提交已进入 `main`，才可清理 worktree 和分支。若 `main` 受保护，使用以已合并 `main` 为基线的仅文档 PR 完成该提交，在其合入前不得宣布 `/finish` 完成。

禁止在任务分支中把尚未合并的功能写成开发计划“已完成”，也禁止用“合并后不再更新台账”作为保留旧状态的理由。合并前记录用于证明“可合并”，合并后归档用于证明“已合并”，两者不可混用。

日常开发由编排者直接合并到 `main`（本地 merge 或 push；CI 只在 Pull Request 与发布 tag 时运行，日常 push 不触发）。版本迭代通过 Pull Request 合并到 `main`，并要求 `Flutter CI / verify` 状态检查通过；不得以本地管理员权限绕过门禁。

功能分支不得以“本地测试通过”替代集成分支回归。

## 9. 冲突处理

- 不使用 `ours` 或 `theirs` 整体覆盖业务文件。
- 先确认冲突双方的业务意图和数据契约。
- 优先保持领域接口兼容，再整合数据和展示实现。
- 需要改变已批准需求时交由人类决定。
- 冲突解决后运行双方相关测试，并在台账中说明。
- 无法判断来源的改动不得删除、恢复或覆盖。

## 10. 验证门禁

每个任务分支至少执行定向验证；合并前后默认执行完整验证：

```powershell
.\tool\verify_changed_dart_format.ps1
flutter analyze
flutter test
flutter build apk --debug --flavor development --dart-define=SPARK_ENV=development
flutter build windows --debug --dart-define=SPARK_ENV=development
git diff --check
```

`/finish` 合并后必须记录 APK 与 Windows debug EXE 的产物路径、大小和 SHA-256；任一目标构建失败不得完成归档或清理。Windows release、正式 Android release 和真机测试根据对应发布清单执行。项目日常开发不启动 Android 模拟器。

测试失败时必须区分：

- 本次改动引入；
- 上游基线已经存在；
- 环境缺失；
- 外部服务不可用。

没有证据时不能把失败归因于其他分支。

## 11. 敏感信息与生成文件

- 不提交 API Key、Token、签名密钥、`.env.local` 或工具私有配置。
- 不提交 `build/`、缓存、日志、临时截图和用户数据。
- 不从其他工具配置文件中复制凭据。
- 依赖或生成文件只有在任务确实需要且经过审查时才提交。
- 提交前检查敏感关键词和异常大文件。

## 12. 回滚

- 已共享提交使用 `git revert`。
- 未共享分支是否 rebase 或 reset 由编排者确认。
- 未经明确许可不得使用 `git reset --hard`、`git clean` 或强制 checkout。
- 涉及持久化 schema 时，回滚计划必须说明旧数据是否仍可读取。
- 发布版本回滚必须记录目标提交、影响范围和用户数据风险。

## 13. Worktree 清理

只有满足以下条件才移除 worktree：

- 分支已合并或明确取消；
- 任务台账已在合并后更新为最终状态；
- 没有未提交或未推送的重要内容；
- 编排者确认不再需要补丁；
- 合并后的台账与开发计划归档提交已进入 `main`；关联发布时，发布资料也已同步。

清理命令由控制工作树执行：

```powershell
git worktree remove <worktree-path>
git worktree prune
```

是否删除已合并分支由编排者决定。

## 14. 完成定义

一个任务只有在以下条件全部满足时才算完成：

- 需求和验收标准满足；
- 代码结构和数据分层符合项目原则；
- 测试和构建结果准确记录；
- `/finish` 合并后的 development APK 与 Windows debug EXE 均已构建成功，并在台账中记录产物证据；
- 提交职责单一且工作区干净；
- 任务台账 status.md 完整，并在合并后记录最终集成 SHA 或 PR 与状态；
- 风险、迁移和后续工作已经记录；
- 已完成集成回归，并在任务合入后更新相关产品文档；关联发布时已同步发布资料；
- 合并后文档归档提交已进入 `main`，台账不再停留在“待合并”或“进行中”；
- 分支可以安全回滚和交接。
