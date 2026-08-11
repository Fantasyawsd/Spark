---
name: test
description: 运行验证门禁并记录证据到台账；用户要求验收时启动 Windows 桌面应用，合并收尾时由 `/finish` 确认 APK 与 Windows EXE 双目标产物。
disable-model-invocation: true
---

# /test 验证门禁

由人类编排者在实现完成后、审查前触发；也可用于合并后的完整回归。纯文档任务跳过 Flutter 构建。

## 步骤

1. **确认验证范围**
   - 确认当前分支与工作区；判断是否为纯文档任务（见 `AGENTS.md`「验证与界面约束」）。
   - 完成标准：明确本次要跑的验证与不跑的项及原因。

2. **运行门禁**
   - 按顺序运行格式检查、`flutter analyze`、`flutter test`；命令清单见 `docs/standards/version-control.md`「验证门禁」。两个目标（development APK、Windows EXE）的发布版构建不在此阶段重复执行，由 `/finish` 合入 `main` 后统一构建并记录证据。
   - 完成标准：每个命令有明确成功/失败输出；失败时区分本次引入 / 基线已有 / 环境缺失 / 外部服务不可用。

3. **验收运行（用户要求检验时）**
   - 执行 `flutter pub get` + `flutter run -d windows` 启动 Windows 桌面应用，等待编排者实际运行检验；不自行替代为 APK、模拟器或其他平台，运行前先与编排者确认。
   - 完成标准：应用窗口成功启动，无构建失败。

4. **记录证据**
   - 把每个命令结果写入 status.md「验证记录」。
   - 完成标准：台账验证表完整；不存在未运行却声称通过的情况。

5. **汇报**
   - 汇总通过项与失败项给编排者。
   - 完成标准：汇报含每个门禁结果与失败归属。
