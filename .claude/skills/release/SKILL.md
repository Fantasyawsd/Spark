---
name: release
description: 执行正式发布：核对发布清单、production 签名构建、真机与 Play 门、创建并推送 annotated Tag。
disable-model-invocation: true
---

# /release 正式发布

由人类编排者在进入正式发布时触发。不单独触发 `/version`（本流程内含版本动作，避免重复升号）。发布门依赖签名密钥、真机与 Play Console 权限，由编排者执行人工部分。

## 步骤

1. **确认发布就绪**
   - 读取 `docs/releases/<version>/release-checklist.md` 与 `docs/standards/release-management.md`「发布门」；确认关联版本与当前 main 为发布基线。
   - 完成标准：发布版本明确；当前 main 为基线。

2. **版本与清单**
   - 若版本号未升则先按 `/version` 流程升号；逐项核对仓库内可验证的清单项（签名配置、包名、隐私、测试）。
   - 完成标准：仓库内检查项全部通过；未通过项有明确阻塞记录。

3. **构建与签名**
   - 构建 production AAB/APK；验证签名、包名、版本号与 SHA-256；命令见 release-checklist。
   - 完成标准：产物签名校验通过；未签名构建按预期失败。

4. **真机与 Play 门**
   - 由编排者完成真机验收与 Play Console 内部测试门（见 release-checklist）。
   - 完成标准：清单中人工/Play 项已确认或明确记录待办。

5. **创建并推送 Tag**
   - `git tag -a v<version> -m "Release v<version>"` + `git push origin v<version>`，随后 `.\tool\verify_version.ps1 -RequireReleaseTag`；Tag 规则见 `docs/standards/release-management.md`。
   - 完成标准：Tag 为 annotated、指向 origin/main、SemVer 与 build 高于历史 Tag；校验通过。

6. **归档**
   - 归档产物 SHA、迁移版本、已知问题与回滚方案；更新发布资料状态。
   - 完成标准：归档完整；版本状态改为发布候选或已上线。
