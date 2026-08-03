# PaperFlow

PaperFlow 是面向个人研究者的 Flutter 论文发现、阅读和 AI 研究助手。产品希望把论文信息流的快速发现、结构化阅读、中文理解和围绕论文的持续对话整合到一个移动端应用中。

当前为未发布开发版本 `0.0.1+1`，第一验收平台是 Android 手机。

## 当前功能

### 论文

- arXiv 远程论文流、分页、搜索和离线缓存。
- 单页刷论文与双栏浏览选择。
- Markdown、LaTeX、英文 Abstract、中文摘要和相关论文。
- 点赞、评论、分享、已读、稍后阅读和收藏分组。
- 从搜索、收藏、历史和相关论文进入独立全屏阅读页。

### ChatPaper

- 置顶主聊天和按论文创建的聊天。
- DeepSeek 流式回答、深度思考、联网搜索、停止和重试。
- Markdown、公式、代码块和会话本地保存。
- 左滑置顶或删除论文会话。

### 我的

- 默认收藏与自定义收藏分组。
- 阅读历史、稍后阅读、主题设置和本地数据管理。
- DeepSeek API Key 验证、保存、替换和删除。
- 应用版本、隐私说明和开源许可。

社区、私信、通知、账号、云同步和内容发布不属于当前生产范围。后续论文发现与阅读改进见 [开发计划](docs/development.md)。

## 数据与隐私

- 论文目录使用 arXiv Atom API；失败时依次回退到设备缓存和内置种子论文。
- 阅读状态、互动、评论、搜索历史、中文摘要和聊天会话保存在当前设备。
- AI 采用 BYOK，用户 Key 存入设备安全存储；正式 APK 不包含共享 Key。
- ChatPaper 和中文摘要请求会把必要的论文内容发送到 DeepSeek 官方接口。
- 正式发布前按应用商店要求提供隐私政策。

## 项目结构

```text
|-- AGENTS.md                  AI Agent 开发、协作和交付规范
|-- CHANGELOG.md               用户可见版本变更记录
|-- README.md                  项目背景、功能、结构和运行方式
|-- .github/workflows/         Pull Request 与 main 持续集成
|-- assets/                    Logo、启动图和应用静态资源
|-- android/                   Android 工程、清单和签名配置入口
|-- windows/                   Windows 桌面宿主工程
|-- docs/
|   |-- README.md              开发文档总入口
|   |-- development.md         开发计划（产品边界、优先级、领域方向）
|   |-- standards/             架构、协作和版本管理规范
|   |-- templates/             Workstream 状态和开发报告模板
|   |-- workstreams/           各开发分支的状态与报告
|   `-- releases/<version>/    仅保存版本发布资料
|-- lib/
|   |-- main.dart              应用入口和生产依赖装配
|   `-- src/
|       |-- app/               应用壳、导航和组合根
|       |-- core/              真正跨业务复用的主题、动画、存储和组件
|       `-- features/
|           |-- papers/        论文目录、阅读、互动和评论
|           |-- chat/          ChatPaper 会话与界面
|           |-- ai_settings/   DeepSeek 凭据配置
|           |-- search/        论文搜索和历史
|           |-- profile/       我的页面与个人研究数据入口
|           |-- local_data/    本地数据统计和清理
|           |-- community/     延期模块，不进入生产导航
|           `-- messages/      旧模块，不进入生产导航
|-- test/                      单元测试和 Widget 测试
|-- tool/                      开发、构建和密钥安全辅助脚本
|-- pubspec.yaml               Flutter 包、资源和版本配置
`-- analysis_options.yaml      Dart/Flutter 静态分析规则
```

代码采用 feature-first + 分层架构：

```text
presentation -> application -> domain <- data
```

完整架构约束见 [代码结构原则](docs/standards/code-structure.md)，发布、环境和兼容规则见 [发布与兼容性管理](docs/standards/release-management.md)。

## 开发文档

- [文档总入口](docs/README.md)
- [开发计划](docs/development.md)
- [发布与兼容性管理](docs/standards/release-management.md)
- [AI Agent 协作规范](AGENTS.md)

## 开发环境

- Flutter 3.44.8 / Dart 3.12.2
- Android SDK：`D:\App\Android\Sdk`
- Windows 构建需要 Visual Studio Build Tools 的 Desktop C++ 组件

```powershell
flutter pub get
flutter run -d windows --dart-define=PAPERFLOW_ENV=development
```

本地调试 DeepSeek 可以使用拒绝 release 的辅助脚本：

```powershell
.\tool\flutter_with_deepseek.ps1 -FlutterCommand run -FlutterArguments @('-d', 'windows', '--dart-define=PAPERFLOW_ENV=development')
```

正式 Android 构建只读取用户在设备安全存储中配置的 Key。

## 验证

```powershell
.\tool\verify_changed_dart_format.ps1
flutter analyze
flutter test
flutter build apk --debug --flavor development --dart-define=PAPERFLOW_ENV=development
```

项目不使用 Android 模拟器作为日常验收方式。Android 正式签名、真机验收和发布门见 [发布与兼容性管理](docs/standards/release-management.md)。
