---
name: develop
description: 在当前任务 worktree 内迭代开发：读上下文、纵向实现、定向验证、原子提交并更新台账。
disable-model-invocation: true
---

# /develop 迭代开发

由人类编排者在 `/start` 之后触发，可反复执行直到实现完成。每轮只完成一个最小闭环。

## 步骤

1. **确认当前环境**
   - 确认 `git branch --show-current` 匹配任务分支；`docs/workstreams/<branch-slug>/status.md` 存在。
   - 完成标准：处于任务 worktree；台账可读；若缺少则提示编排者先运行 `/start`。

2. **读取上下文**
   - 读 status.md、任务相关代码与测试、`docs/development.md` 相关领域章节；面向发布时读 `docs/releases/<version>/` 版本说明。
   - 完成标准：本次要改的文件路径与依赖接口清楚。

3. **制定迭代计划**
   - 拆出本次最小可独立验证的步骤，写入 status.md「实施计划」。
   - 完成标准：有明确改动文件清单与验证方式；不越出任务范围。

4. **纵向实现**
   - 按领域 → 数据 → 应用 → 展示 → 测试边界实现最小闭环；遵守 `docs/standards/code-structure.md` 的分层与依赖方向。
   - 完成标准：改动满足模块边界与数据分层；小段业务逻辑可脱离完整页面做单元测试。

5. **定向验证**
   - 运行本次改动相关测试、`flutter analyze` 与格式检查；命令清单见 `docs/standards/version-control.md`「验证门禁」，本 skill 不复制。
   - 完成标准：定向测试通过；无新增 analyze 问题；格式通过。

6. **原子提交**
   - 按明确路径暂存（`git add -- <paths>`），使用中文 `<类型>（<范围>）：<主题>` 提交信息；正文、验证和脚注规则见 `docs/standards/version-control.md`「提交原则」。
   - 更新 status.md「检查点与提交」记录 SHA 与验证摘要。
   - 完成标准：提交职责单一；`git diff --cached --check` 通过；台账已记录。

7. **汇报并等待**
   - 向编排者报告完成项、验证结果与下一步；是否继续由编排者决定。
   - 完成标准：本轮结果已汇报，阻塞项明确。
