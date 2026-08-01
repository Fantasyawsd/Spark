# PaperFlow Workstreams

每个并行开发分支在本目录建立独占状态目录，不按版本划分：

```text
<branch-slug>/
|-- status.md
`-- report.md
```

分支名中的 `/` 替换为 `--`。例如：

```text
codex/feature-paper-channels
-> codex--feature-paper-channels/
```

`status.md` 从 [`../templates/workstream-status.md`](../templates/workstream-status.md) 创建，开发中持续维护。`report.md` 从 [`../templates/development-report.md`](../templates/development-report.md) 创建，合并前完成。

并行期间，每个目录只有对应分支可以写入；产品文档、开发总路线和发布资料由集成负责人依据开发报告统一更新。
