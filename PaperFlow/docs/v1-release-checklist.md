# PaperFlow V1.0 发布检查清单

> 当前状态：**代码候选，不能标记为已上线**。
>
> 本清单区分可在仓库中验证的项目与必须由持有上传密钥、Android 真机和 Play Console 完成的发布门。

## 1. 已完成的仓库准备

- [x] V1 主导航只包含论文、ChatPaper、我的。
- [x] 包名固定为 `app.paperflow.reader`，版本为 `1.0.0+1`。
- [x] 正式 release 缺少 `android/key.properties` 时 Gradle 明确失败。
- [x] `android/key.properties`、`.jks` 和 `.keystore` 已被 Git 忽略。
- [x] Android 仅声明网络权限，禁用自动备份和明文流量。
- [x] 正式构建不读取 `DEEPSEEK_API_KEY` 的编译常量；开发辅助脚本拒绝 release。
- [x] 应用内隐私入口说明本地存储与 DeepSeek 数据传输。
- [x] 论文远程目录、缓存、离线种子回退、ChatPaper、本地互动和本地数据清理均有自动化测试。
- [x] `flutter analyze` 通过，完整 Flutter 测试 183 项通过，`git diff --check` 通过。
- [x] Android debug APK 已构建：`build/app/outputs/flutter-apk/app-debug.apk`。
- [x] 未配置签名时 `gradlew bundleRelease` 按预期失败，防止误把未签名产物当成发布包。

### 当前内部验证产物

- 构建时间：2026-08-01 21:00:18（本机时间）。
- 文件：`build/app/outputs/flutter-apk/app-debug.apk`，大小 159,610,812 字节。
- SHA-256：`28828F5456D36F3D4FC7DBE3F72A986A5802139F83A506B17A4C8B6EB89DD424`。
- `apksigner verify --verbose --print-certs` 已通过，使用 APK Signature Scheme v2，证书为 Android Debug。
- 该文件只用于开发和真机验收，不是可提交商店的正式签名包；目录中的任何旧 `app-release.apk` 均不得作为当前发布产物。

## 2. Android 构建环境

- [x] 已安装 Android SDK Command-line Tools 22.0，`flutter doctor -v` 的 Android toolchain 无警告。
- [x] 已执行 `flutter doctor --android-licenses`，全部 SDK licenses 已接受。
- [x] 当前构建基线：Flutter 3.44.8、Dart 3.12.2、Gradle 9.1.0、AGP 9.0.1、Kotlin 2.3.20、minSdk 24、compileSdk 36、targetSdk 36。

## 3. 正式签名

1. 在离线安全位置生成 upload keystore，密码不得写入仓库、聊天记录或文档。
2. 将 keystore 放在 `android/` 下，并从 `android/key.properties.example` 创建本机被忽略的 `android/key.properties`。
3. 确认 `git status --ignored` 中只有本地凭据被忽略，执行 `git diff --cached` 确认没有密钥内容。
4. 构建：

```powershell
flutter build appbundle --release
flutter build apk --release
```

5. 使用 Android Build Tools 的 `apksigner verify --verbose --print-certs <apk>` 验证 APK 签名；AAB 上传到 Play 内部测试轨道验证。

## 4. Android 真机验收

- [ ] 冷启动：断网时显示缓存或内置论文，不能出现空白页。
- [ ] arXiv：正常网络、弱网、断网、刷新、领域切换与分页的状态和错误提示正确。
- [ ] 阅读：垂直翻页、原文/中文解读/相关论文、文本选择、标题复制和系统分享正常。
- [ ] ChatPaper：保存/删除 Key、真实流式输出、停止、重试、深度思考和联网搜索正常。
- [ ] Keystore：验证重启、覆盖升级、卸载重装、Android 12+ 数据迁移及密钥失效后的提示。
- [ ] 本地数据：分类清理和重置后不残留旧评论、聊天、翻译或缓存。
- [ ] 系统：键盘、后台恢复、深浅主题、Android 12+ 启动图标与启动页正确。

Windows release 回归当前受本机 Visual Studio Build Tools 缺少 ATL 头文件 `atlstr.h` 阻塞；这不影响 Android V1，但若需要 Windows 分发，应安装 `Microsoft.VisualStudio.Component.VC.ATL` 后重试。

## 5. Play Console 发布门

- [ ] 创建 Play App Signing 配置并保存 upload key 备份。
- [ ] 发布可访问的 HTTPS 隐私政策 URL，补全 `docs/privacy-policy-draft.md` 的运营者和联系方式。
- [ ] 根据真实数据流填写 Data Safety：设备本地研究数据、用户提供 API Key、发送给 DeepSeek 的聊天/论文上下文，以及 arXiv 请求。
- [ ] 上传签名 AAB 至内部测试，完成预发布报告、安装、升级和崩溃检查。
- [ ] 准备商店名称、简介、截图、512x512 图标、功能图和内容分级问卷。

## 6. 最终发布判定

只有第 2 至第 5 节全部完成，并保留构建命令、产物 SHA-256、测试设备和 Play 内部测试记录后，才可将版本状态改为“发布候选”或“已上线”。
