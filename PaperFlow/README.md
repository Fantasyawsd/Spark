# PaperFlow

PaperFlow 是面向个人研究者的 Flutter 论文阅读器。0.1.0 聚焦三个页面：

- **论文**：arXiv 论文流、领域筛选、搜索、Markdown/公式阅读、中文解读、相关论文和本地互动。
- **ChatPaper**：主聊天与论文聊天、流式回答、深度思考、联网搜索和本地会话管理。
- **我的**：收藏分组、阅读记录、主题、DeepSeek API Key 和本地数据管理。

社区、私信、账号、云同步和内容发布不属于 0.1.0 范围。

## 数据与隐私

- 论文目录使用 arXiv Atom API；联网失败时回退到设备缓存或内置种子论文。
- 阅读记录、互动、评论、搜索历史、中文解读和聊天会话只保存在当前设备，可从“我的 > 本地数据”清理。
- AI 功能采用 BYOK：用户在“我的 > AI 设置”保存自己的 DeepSeek API Key。正式 release 不包含共享 Key，也不接受 `--dart-define` 注入 Key。
- 使用 ChatPaper 或中文解读时，问题、论文标题/摘要和必要上下文会发送到 DeepSeek 官方接口。应用内“隐私”入口有简要说明；公开发布前必须按 [隐私政策草案](docs/versions/0.1.0/privacy-policy-draft.md) 提供可访问的正式 URL。

## 目录

```text
lib/src/
|-- app/        应用组合根、导航和依赖装配
|-- core/       跨业务模块复用的主题、动画、存储和基础组件
`-- features/   按论文、聊天、AI 设置、搜索、我的等业务划分
```

开发文档从 [文档总入口](docs/README.md) 进入。详细架构约束见 [代码结构原则](docs/code-structure-principles.md)，0.1.0 范围与发布状态见 [发布计划](docs/versions/0.1.0/release-plan.md)。

## 开发环境

- Flutter 3.44.8 / Dart 3.12.2
- Android SDK：`D:\app\Android\Sdk`
- Windows 构建需要 Visual Studio Build Tools 的 Desktop C++ 组件

```powershell
flutter pub get
flutter run -d windows
```

本地开发若需通过环境变量临时注入 DeepSeek Key，可使用：

```powershell
.\tool\flutter_with_deepseek.ps1 -FlutterCommand run -FlutterArguments @('-d', 'windows')
```

该脚本会拒绝 `--release`，防止把 Key 编译进正式安装包。正式 Android 构建只使用用户在设备安全存储中配置的 Key。

## 验证

```powershell
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build windows --release
```

Android 上线步骤、签名配置、真机验收与 Play Console 发布门见 [0.1.0 发布检查清单](docs/versions/0.1.0/release-checklist.md)。
