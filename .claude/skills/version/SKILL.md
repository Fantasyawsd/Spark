---
name: version
description: 变更版本号与构建号：set_version、更新 CHANGELOG、verify_version 校验。
disable-model-invocation: true
---

# /version 版本管理

由人类编排者在需要新版本号或构建号时触发（内部构建、候选、发布前置）。只变更版本，不执行发布流程。

## 步骤

1. **确认新版本**
   - 与编排者确认新的 versionName 与 buildNumber；SemVer 与构建号规则见 `docs/standards/release-management.md`「发布版本与构建号」。
   - 完成标准：新版本高于当前且构建号递增；编排者已确认。

2. **运行版本工具**
   - 执行 `.\tool\set_version.ps1 -VersionName <name> -BuildNumber <n>`。
   - 完成标准：命令成功；`pubspec.yaml` 与应用内展示常量已同步。

3. **更新 CHANGELOG**
   - 添加 `## [<version>]` 条目与链接；候选版本不写发布日期（正式 Tag 规则见 `docs/standards/release-management.md`）。
   - 完成标准：CHANGELOG 有该版本条目。

4. **校验**
   - 执行 `.\tool\verify_version.ps1`。
   - 完成标准：校验通过；如需指定基线再带对应参数。

5. **提交**
   - 单独 `chore:` 或 `docs:` 提交版本变更与 CHANGELOG；提交规则见 `docs/standards/version-control.md`「提交原则」。
   - 完成标准：提交职责单一，含工具变更与 CHANGELOG。
