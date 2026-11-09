Landlord LAN v0.2.0：新增 Windows 电脑端，可与 iPhone、Android 通过同一 Wi-Fi / 局域网或热点联机。

- Windows x64 免安装包，完整解压后双击 `LandlordLAN.exe`，运行库、DLL 和 data 目录已随包提供。
- 支持鼠标选牌、创建 / 加入牌桌、窗口缩放和高 DPI；初始窗口适应桌面工作区域。
- 自动发现附近房间，也可手动输入 IP:端口。Windows 防火墙请允许本程序访问专用网络。
- 通信协议保持 v1，与已安装的 v0.1.0 手机端兼容，不强制重新安装手机 App。
- 手机端保留经典绿色横屏界面、三人真人对局、合法出牌提示与积分结算。
- 断线暂停、座位保留 60 秒和重连流程适用于所有平台。
- iOS 最低版本统一为 15，已修复 Xcode 27 对 Runner / Flutter / Pods 部署目标版本的要求。
- 静态检查、43 项自动化测试、Android 构建、iOS 无签名编译、Windows 构建和免安装包启动检查通过后才发布。
- Windows 启动检查验证实际 EXE 的窗口、原生 DLL、缩放与正常退出；跨设备 Wi-Fi / 热点联机尚未实测。

下载：

- Windows：`landlord-lan-v0.2.0-windows-x64.zip`，解压全部文件后启动 `LandlordLAN.exe`。
- Android：`landlord-lan-v0.2.0-android.apk`，Release 构建、调试签名，供侧载试玩。
- iOS：提供源码和 Mac / Xcode 签名步骤，不提供签名 IPA。

SHA-256 校验值、完整源码与构建记录一并提供。不同构建机器的 Android 调试签名不同；覆盖旧测试版失败时需先卸载旧版。
