---
name: test
description: 运行验证门禁（格式、analyze、全量测试、development APK 构建）并记录证据到台账。
disable-model-invocation: true
---

# /test 验证门禁

由人类编排者在实现完成后、审查前触发；也可用于合并后的完整回归。纯文档任务跳过 Flutter 构建。

## 步骤

1. **确认验证范围**
   - 确认当前分支与工作区；判断是否为纯文档任务（见 `AGENTS.md`「验证与界面约束」）。
   - 完成标准：明确本次要跑的验证与不跑的项及原因。

2. **运行门禁**
   - 按顺序运行格式检查、`flutter analyze`、`flutter test`、development APK 构建；命令清单见 `docs/standards/version-control.md`「验证门禁」。
   - 完成标准：每个命令有明确成功/失败输出；失败时区分本次引入 / 基线已有 / 环境缺失 / 外部服务不可用。

3. **记录证据**
   - 把每个命令结果写入 status.md「验证记录」。
   - 完成标准：台账验证表完整；不存在未运行却声称通过的情况。

4. **汇报**
   - 汇总通过项与失败项给编排者。
   - 完成标准：汇报含每个门禁结果与失败归属。
