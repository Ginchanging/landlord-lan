$ErrorActionPreference = 'Stop'

$versionMatch = Select-String -Path pubspec.yaml -Pattern '^version:\s*([^+\s]+)'
$version = 'v' + $versionMatch.Matches[0].Groups[1].Value
if ($env:GITHUB_REF_TYPE -eq 'tag' -and $env:GITHUB_REF_NAME -ne $version) {
    throw "Tag $env:GITHUB_REF_NAME does not match pubspec version $version"
}

$build = Join-Path $PWD 'build/windows/x64/runner/Release'
if (-not (Test-Path "$build/LandlordLAN.exe")) { throw 'Windows executable missing' }
$stage = Join-Path $env:RUNNER_TEMP 'landlord-lan-portable'
New-Item $stage -ItemType Directory -Force | Out-Null
Copy-Item "$build/*" $stage -Recurse -Force

# App-local MSVC runtimes let the portable app run without a separate installer.
$vswhere = "${env:ProgramFiles(x86)}/Microsoft Visual Studio/Installer/vswhere.exe"
$visualStudio = & $vswhere -latest -products '*' -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
if (-not $visualStudio) { throw 'Visual Studio C++ installation not found' }
$runtime = Get-ChildItem "$visualStudio/VC/Redist/MSVC" -Directory |
    Where-Object { $_.Name -match '^\d+(\.\d+)+$' } |
    Sort-Object { [version]$_.Name } -Descending |
    ForEach-Object { Join-Path $_.FullName 'x64/Microsoft.VC143.CRT' } |
    Where-Object { Test-Path $_ } |
    Select-Object -First 1
if (-not $runtime) { throw 'Redistributable x64 VC143 runtime not found' }
Copy-Item "$runtime/*.dll" $stage -Force

@'
Landlord LAN / 同桌斗地主

系统：Windows 10 1903 或更高 / Windows 11，x64。

完整解压后双击 LandlordLAN.exe。请保留同目录的 DLL 和 data 文件夹。
三台设备接入同一 Wi-Fi 或热点，可与 iPhone、Android 手机混合联机。
一人创建牌桌，其他人搜索加入；也可点击「连接」查看房主 IP 和端口手动加入。
三位真人全部准备后开局。游戏不需要互联网，也不需要账号。

Windows 防火墙询问时，允许本程序访问「专用网络」。
若自动搜索失败，可手动输入房主显示的 IP:端口，并检查防火墙或路由器客户端隔离。
电脑睡眠、关闭程序会中断连接；使用手机作为房主时请保持 App 在前台。

源码与构建说明：https://github.com/Ginchanging/landlord-lan
本程序使用 Flutter、nsd、Noto Sans SC，第三方声明见下方随附文件。
随包提供的 Microsoft Visual C++ 运行库遵循 Microsoft 的再分发条款：
https://learn.microsoft.com/cpp/windows/redistributing-visual-cpp-files
'@ | Set-Content "$stage/使用说明.txt" -Encoding utf8
Copy-Item THIRD_PARTY_NOTICES.md "$stage/THIRD_PARTY_NOTICES.md"
Copy-Item assets/fonts/OFL.txt "$stage/NotoSansSC-OFL.txt"

foreach ($file in @('LandlordLAN.exe', 'flutter_windows.dll', 'nsd_windows_plugin.dll', 'msvcp140.dll', 'vcruntime140.dll', 'vcruntime140_1.dll', 'data/app.so', 'data/icudtl.dat', 'data/flutter_assets/FontManifest.json')) {
    if (-not (Test-Path (Join-Path $stage $file))) { throw "Incomplete Windows bundle: $file" }
}
New-Item dist -ItemType Directory -Force | Out-Null
$zip = Join-Path $PWD "dist/landlord-lan-$version-windows-x64.zip"
Compress-Archive -Path "$stage/*" -DestinationPath $zip -Force
Write-Host "Packaged $zip"
