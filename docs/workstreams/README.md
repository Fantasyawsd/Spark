# PaperFlow 任务台账

每个任务在本目录建立单文件台账：

```text
<branch-slug>/
`-- status.md
```

分支名中的 `/` 替换为 `--`。例如：

```text
feature/paper-channels
-> feature--paper-channels/
```

`status.md` 从 [`../templates/workstream-status.md`](../templates/workstream-status.md) 创建，由 `/start` 初始化、`/develop` 与 `/test` 持续维护，`/review` 写入审查结论，合并前由 `/finish` 补齐交付记录。

任务合并后台账归档保留，不删除、不更新，供后续任务参考。产品文档、开发总路线和发布资料由编排者依据交付记录统一更新。
