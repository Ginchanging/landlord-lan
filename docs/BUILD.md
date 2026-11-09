# 构建与安装

## 开发环境

固定 Flutter `3.41.9` / Dart `3.11.5`。可以通过版本管理工具切换，或获取 SDK 标签：

```sh
git clone --depth 1 --branch 3.41.9 https://github.com/flutter/flutter.git flutter-sdk
export PATH="$PWD/flutter-sdk/bin:$PATH"
flutter --version
```

在本项目根目录运行 `flutter pub get`。首次需下载 Flutter artifacts、pub.dev、Android Maven/Gradle 依赖。公司代理环境还需为 Java/Gradle 配置代理与 CA 信任，不把机器的配置、路径和凭据写入仓库。

## Android

安装完整 **JDK 17（包含 javac）**、Android SDK Platform 36、Build Tools 35.0.0（AGP 默认）、NDK 28.2.13676358，并接受 SDK 许可证。

```sh
flutter doctor -v
flutter analyze
flutter test
flutter build apk --release
```

安装 `build/app/outputs/flutter-apk/app-release.apk`，系统询问时允许从当前来源安装应用。也可连接调试设备：

```sh
adb install -r build/app/outputs/flutter-apk/app-release.apk
flutter run --release
```

首版使用本机构建工具生成的调试签名供侧载测试，正式分发需要配置私有签名。跨机器构建的 APK 可能不能覆盖安装，卸载旧测试版后重装即可。密钥、`key.properties` 和本机 SDK 路径已忽略。

## Windows

使用 Windows 10 1903（build 18362）或更高 / Windows 11，x64 架构。普通玩家下载 Release 中的 `landlord-lan-v0.2.0-windows-x64.zip`，完整解压后运行 `LandlordLAN.exe`，不需要安装 Flutter 或 Visual Studio。

在自己可信的家庭网络中，将 Windows 网络配置文件设为“专用”，首次防火墙询问时允许 Landlord LAN 使用专用网络。电脑与手机接入同一局域网，创建 / 搜索牌桌，或输入房主显示的 IP:端口。不要只复制 EXE，旁边的 DLL 和 `data` 都是运行所需的文件。

开发者需安装 Visual Studio 2022 的 **使用 C++ 的桌面开发**工作负载，包括 MSVC、Windows SDK 和 CMake。然后执行：

```sh
flutter config --enable-windows-desktop
flutter pub get
flutter test --reporter expanded
flutter run -d windows
flutter build windows --release
```

输出目录为 `build/windows/x64/runner/Release/`。CI 打包时加入可应用本地部署的 Microsoft Visual C++ x64 运行库，压缩完整 Release 目录，并启动解压后的 ZIP 检查窗口显示、原生模块加载、缩放与正常退出。截图和启动日志保存在 `windows-smoke` Actions artifact。

Windows 与 v0.1.0 手机端使用相同的 v1 联机协议。窗口失焦 / 最小化不会主动断线；电脑睡眠、关闭进程会中断连接。混合设备的实际 Wi-Fi / 热点行为仍需在自己的网络中验证。

## iOS

需要 Mac、受 Flutter 3.41.9 支持的 Xcode、iOS SDK、CocoaPods。当前最低 iOS 版本为 15.0，Runner、App framework 与所有 Pods 的最低版本已统一，兼容 Xcode 27 的部署目标要求。Linux 无法编译或签名 iOS 应用。

```sh
flutter pub get
flutter precache --ios
flutter build ios --release --no-codesign
open ios/Runner.xcworkspace
```

在 Xcode 中：

1. 在 **Xcode → Settings → Accounts** 登录自己的 Apple ID。
2. 点左侧蓝色 **Runner** 工程，在 **TARGETS** 中选择 **Runner → Signing & Capabilities**，勾选 **Automatically manage signing**，**Team** 选择自己的账号（个人测试可选 Personal Team）。团队和证书属于本机签名设置，仓库不提供预设团队。
3. 若 Bundle Identifier 被占用，将 `io.github.ginchanging.lanDoudizhu` 改为自己唯一的英文标识，例如 `com.yourname.landlordlan`。
4. 接上已信任并解锁的 iPhone / iPad，在顶部 **Runner** 右侧选择真实设备。iOS 16 及以上按提示启用开发者模式；如果出现开发者磁盘映像错误，先更新兼容手机系统的 Xcode 并完成设备支持组件安装。
5. 选择 **Product → Scheme → Edit Scheme → Run → Info → Build Configuration → Release**，按 **⌘R** 签名安装。Release 模式支持断开电脑后独立启动。
6. 首次运行允许 **本地网络**，后续可在系统设置中修改。个人免费 Apple ID 的设备数、有效期与开发者模式限制遵循 Apple 当前规则。

### Xcode 27 提示最低版本过低

如果看到 Runner / nsd_ios / Pods-Runner / Flutter 的 `IPHONEOS_DEPLOYMENT_TARGET` 为 13.0 或 14.0，而 Xcode 要求 15.0，请先关闭 Xcode，在项目根目录更新并重新生成 Pods：

```sh
git pull --ff-only
flutter clean
flutter pub get
flutter precache --ios
cd ios
pod install
cd ..
open ios/Runner.xcworkspace
```

`v0.1.0` 源码归档保留了旧配置，修复位于最新 `main`。若 `git pull` 提示本地修改冲突，请保留自己的 Team / Bundle Identifier 设置并解决冲突，不要强制重置工程文件。

若仍提示 **Signing for Runner requires a development team**，按上述第 1～2 步选择本人的 Team；无签名编译检查通过，并不代表已经具备手机安装签名。

TestFlight / App Store 需要 Apple Developer 会员、分发签名和 App Store Connect 配置，本次不包含这些账号操作。CI 的 `--no-codesign` 仅验证编译，不生成可直接安装的签名 IPA。

## 截图与测试

```sh
flutter test --reporter expanded
flutter test test/ui_test.dart --dart-define=CAPTURE_SCREENSHOTS=true
```

第二条命令更新 `docs/screenshots/` 中的组件渲染截图。测试中的自动出牌只用于验证规则，不是产品里的电脑玩家。

## GitHub Release

推送 `v*` 标签会运行 Android 测试与 APK 构建、macOS 上的 iOS 无签名编译，以及 Windows 测试、x64 构建和免安装包启动检查。全部通过后，发布任务使用本仓库的临时 `GITHUB_TOKEN` 上传 APK、Windows ZIP、源码、校验值和构建记录，发布为测试版本。发布说明来自 `docs/RELEASE_NOTES.md`。

该流程不需要把个人访问令牌或签名密钥存入仓库；日常推送 `main` 只执行构建检查。
