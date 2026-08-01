# PaperFlow Git 与多 Agent 集成管理

> 状态：强制执行
> 最近更新：2026-08-02
> 适用范围：代码、测试、文档、配置和发布产物
> Agent 总规范：[`../../AGENTS.md`](../../AGENTS.md)

## 1. 目标

Git 与集成管理需要同时保证：

- 每个需求有明确目标、验收标准和责任分支；
- 多个 Agent 的代码、状态和报告可以独立追踪；
- 共享文档和公共模块不会因并行修改持续冲突；
- 每个提交可审查、可验证、可回滚；
- 集成基线始终可以说明当前包含哪些 workstream；
- 开发计划不预先绑定版本，只有进入发布准备后才归入发布版本。

## 2. 分支模型

### 2.1 长期分支

- `main`：只保留完整验证、可发布或明确标记的稳定基线。
- 发布分支：仅在进入发布准备后按需创建，例如 `release/0.2.0`，由集成负责人维护。
- 不为普通开发任务预先创建发布分支，也不使用范围持续扩大的长期功能分支代替集成基线。

### 2.2 Workstream 分支

一个分支只交付一个主要业务结果：

```text
<agent>/<workstream>
codex/paper-channels
claude/pdf-ai
```

分支必须从人类或集成负责人批准的提交创建。分支名发生失真时应结束当前分支，不继续叠加无关功能。

## 3. Worktree 隔离

每个独立 workstream 使用独立 worktree；即使当前只有一个 Agent，也不直接把新任务叠加到控制工作树：

```powershell
git worktree add ..\PaperFlow-worktrees\codex-paper-channels `
  -b codex/paper-channels <approved-base>
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

- 不允许多个写入 Agent 共用一个 worktree。
- 不在开发 worktree 中切换到其他 workstream 分支。
- 不通过复制未提交文件、共享暂存区或压缩工作目录协作。
- 不从脏工作区创建无法追溯的任务基线。
- worktree 路径不得位于仓库内部。

## 4. 分支状态目录

每个 workstream 建立：

```text
docs/workstreams/<branch-slug>/
|-- status.md
`-- report.md
```

使用：

- [`../templates/workstream-status.md`](../templates/workstream-status.md)
- [`../templates/development-report.md`](../templates/development-report.md)

`status.md` 在开始编码前创建，并持续记录范围、所有权、计划、进度、决策和验证。`report.md` 在申请合并前完成，记录实际交付、提交、风险、迁移和共享文档建议。

聊天记录、终端历史和口头说明不能替代这两个文件。

## 5. 文件所有权

并行开始前必须分配：

- 独占代码和测试路径；
- 需要协调的共享接口；
- 功能契约文档负责人；
- 共享总文档负责人；
- 合并顺序和上游依赖。

默认规则：

- Workstream Agent 独占自己的状态目录。
- 同一时间一个文件只有一个写入 workstream。
- 开发总路线、产品领域文档和发布资料由集成负责人单点维护。
- 功能分支在报告中提出共享文档更新建议。
- 必须共同修改的文件改为串行任务，不能依靠最后统一解决冲突。

## 6. 提交原则

提交信息使用：

- `feat:` 新功能
- `fix:` 缺陷修复
- `refactor:` 不改变行为的结构调整
- `test:` 测试变更
- `docs:` 文档变更
- `chore:` 工具、依赖和构建配置

一个提交只有一个主要意图，并满足：

- 可以独立解释和审查；
- 代码、测试和契约保持一致；
- 不混入其他 Agent 或人类的无关改动；
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
5. 准备跨分支提供公共接口时。
6. 申请人工验收、构建 APK 或合并前。

每个检查点同步更新 `status.md`，记录提交 SHA 和验证结果。

## 8. 跨分支依赖

Workstream 需要其他分支能力时：

1. 读取对方 `status.md` 或 `report.md`。
2. 确认所需接口已经形成提交。
3. 由集成负责人决定先合并上游、merge、rebase 或 cherry-pick。
4. 在本分支状态中记录引入的提交和原因。
5. 重新运行受影响测试。

禁止复制对方未提交文件或在对方 worktree 中直接修改。

## 9. 审查与集成

申请合并必须提供：

- 完整开发报告；
- 干净工作区；
- 可解释的提交列表；
- 定向与完整验证结果；
- 数据迁移和兼容性说明；
- 已知风险和回滚方式。

集成负责人按以下顺序处理：

1. 阅读状态、报告和功能契约。
2. 审查提交范围和依赖方向。
3. 检查与已合并 workstream 的路径和契约冲突。
4. 合并到批准的集成基线；进入发布准备时再合并到发布分支。
5. 解决冲突并记录语义决策。
6. 执行格式、分析、全量测试和目标平台构建。
7. 更新开发路线和产品领域文档；关联发布时再更新发布进度与清单。
8. 形成集成提交或明确的合并提交。

功能分支不得以“本地测试通过”替代集成分支回归。

## 10. 冲突处理

- 不使用 `ours` 或 `theirs` 整体覆盖业务文件。
- 先确认冲突双方的业务意图和数据契约。
- 优先保持领域接口兼容，再整合数据和展示实现。
- 需要改变已批准需求时交由人类决定。
- 冲突解决后运行双方相关测试，并在报告或集成记录中说明。
- 无法判断来源的改动不得删除、恢复或覆盖。

## 11. 验证门禁

工作分支至少执行定向验证；集成分支默认执行：

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build apk --debug
git diff --check
```

Windows release、正式 Android release 和真机测试根据对应发布清单执行。项目日常开发不启动 Android 模拟器。

测试失败时必须区分：

- 本次改动引入；
- 上游基线已经存在；
- 环境缺失；
- 外部服务不可用。

没有证据时不能把失败归因于其他分支。

## 12. 敏感信息与生成文件

- 不提交 API Key、Token、签名密钥、`.env.local` 或工具私有配置。
- 不提交 `build/`、缓存、日志、临时截图和用户数据。
- 不从其他 Agent 配置文件中复制凭据。
- 依赖或生成文件只有在任务确实需要且经过审查时才提交。
- 提交前检查敏感关键词和异常大文件。

## 13. 回滚

- 已共享提交使用 `git revert`。
- 未共享分支是否 rebase 或 reset 由分支负责人和集成负责人共同确认。
- 未经明确许可不得使用 `git reset --hard`、`git clean` 或强制 checkout。
- 涉及持久化 schema 时，回滚计划必须说明旧数据是否仍可读取。
- 发布版本回滚必须记录目标提交、影响范围和用户数据风险。

## 14. Worktree 清理

只有满足以下条件才移除 worktree：

- 分支已合并或明确取消；
- 状态和报告已完成；
- 没有未提交或未推送的重要内容；
- 集成负责人确认不再需要补丁；
- 开发报告已记录最终结果；关联发布时，发布资料也已同步。

清理命令由控制工作树执行：

```powershell
git worktree remove <worktree-path>
git worktree prune
```

是否删除已合并分支由集成负责人决定。

## 15. 完成定义

一个 workstream 只有在以下条件全部满足时才算完成：

- 需求和验收标准满足；
- 代码结构和数据分层符合项目原则；
- 测试和构建结果准确记录；
- 提交职责单一且工作区干净；
- `status.md` 和 `report.md` 完整；
- 风险、迁移和后续工作已经记录；
- 已完成集成回归并更新相关产品文档；关联发布时已同步发布资料；
- 分支可以安全回滚和交接。
