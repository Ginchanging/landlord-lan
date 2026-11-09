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

## iOS

需要 Mac、受 Flutter 3.41.9 支持的 Xcode、iOS SDK、CocoaPods。Linux 无法编译或签名 iOS 应用。

```sh
flutter pub get
flutter precache --ios
flutter build ios --release --no-codesign
open ios/Runner.xcworkspace
```

在 Xcode 中：

1. 选择 **Runner → Signing & Capabilities**，选择 Apple Team，启用自动签名。
2. 若 Bundle Identifier 被占用，将 `io.github.ginchanging.lanDoudizhu` 改为自己唯一的标识。
3. 接上已信任的 iPhone / iPad，选中设备运行。个人免费 Apple ID 的设备数、有效期与开发者模式限制遵循 Apple 当前规则。
4. 首次运行允许 **本地网络**，后续可在系统设置中修改。

TestFlight / App Store 需要 Apple Developer 会员、分发签名和 App Store Connect 配置，本次不包含这些账号操作。CI 的 `--no-codesign` 仅验证编译，不生成可直接安装的签名 IPA。

## 截图与测试

```sh
flutter test --reporter expanded
flutter test test/ui_test.dart --dart-define=CAPTURE_SCREENSHOTS=true
```

第二条命令更新 `docs/screenshots/` 中的组件渲染截图。测试中的自动出牌只用于验证规则，不是产品里的电脑玩家。
