Landlord LAN 首个测试版本：三位真人通过同一 Wi-Fi 或手机热点联机斗地主，游戏不依赖互联网。

- iOS / Android 共用 Flutter 源码，中文横屏、经典绿色牌桌。
- 自动发现房间和手动 IP:端口加入，叫分、常见完整牌型、提示、积分结算。
- 断线暂停并保留座位 60 秒，自动重连；超时或主动离开则中止本局，不计分。
- Android APK：最低 Android 7 / API 24，包含 ARM32 / ARM64 / x86_64，Release 构建，调试密钥签名，供侧载试玩。
- 静态检查无问题，40 项自动化测试通过，包含 100 局规则测试和三个真实 WebSocket 客户端完成对局。
- Android APK 构建、macOS 上 iOS 无签名 Release 编译均通过，随后才执行本发布任务。
- iOS 提供源码和 Mac / Xcode 签名步骤，不提供签名 IPA。
- 尚未完成混合真机联测及实体设备 Bonjour / NSD、无外网热点验收，见 `docs/TESTING.md`。

下载 `landlord-lan-v0.1.0-android.apk` 安装试玩。源码、构建记录和 SHA-256 校验值一并提供。三部手机需安装相同版本。

不同构建机器使用的调试签名不同。若安装过之前下载的本地测试 APK，覆盖安装失败时需先卸载旧版，再安装本 Release 的 APK。
