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

`status.md` 从 [`../templates/workstream-status.md`](../templates/workstream-status.md) 创建，由 `/start` 初始化、`/develop` 与 `/test` 持续维护，`/review` 写入审查结论。`/finish` 先在任务分支收集合并前交付信息；任务真实合入 `main` 后，再在 `main` 标记 `已合并` 并记录最终集成 SHA 或 PR、合并时间和集成验证。

台账不能永久停留在“待合并”“进行中”等合并前状态。合并后的最终归档更新与 `docs/development.md` 同步形成独立文档提交；该提交进入 `main` 后，台账归档保留、不删除，除勘误外不再更新，供后续任务参考。
