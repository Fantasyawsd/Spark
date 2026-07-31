# PaperFlow 项目约定

## 项目简介

- Flutter 论文发现与社区应用（`paperflow`），采用 feature-first + 分层架构（`presentation → application → domain ← data`）。
- 入口：`lib/main.dart`（唯一依赖装配点）→ `lib/src/app/paperflow_app.dart`（应用壳）。

## 强制约束（开发与重构必须遵守）

- `docs/code-structure-principles.md`
  代码组织、模块边界和依赖方向的强制规则。开发/重构前自查第 5 节「提交前结构检查清单」；触及第 6 节「代码审查阻断条件」时不得合并。
- `docs/papers-development-roadmap.md`
  开发路线、阶段目标、已完成能力与验收标准。开发前先确认当前阶段与目标，避免偏离。

## 文档维护约定（每次开发/重构完成后）

1. 若改动涉及代码结构、模块归属或依赖方向 → 更新 `docs/code-structure-principles.md`，并更新头部「最近更新」日期。
2. 若改动涉及功能进度、能力边界或完成项 → 同步勾选/修订 `docs/papers-development-roadmap.md` 对应章节。
3. 文档变更与代码变更在同一提交内一起提交，避免文档滞后于代码。

## 验收命令

```text
flutter analyze
flutter test
flutter build apk --release
flutter build windows --release
```
