$ErrorActionPreference = 'Stop'

Add-Type @'
using System;
using System.Runtime.InteropServices;
public static class WindowProbe {
    [StructLayout(LayoutKind.Sequential)]
    public struct Rect { public int Left, Top, Right, Bottom; }
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr handle, out Rect rect);
    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr handle, int x, int y, int w, int h, bool repaint);
    [DllImport("user32.dll")]
    public static extern IntPtr SendMessageTimeout(IntPtr handle, uint message, IntPtr w, IntPtr l, uint flags, uint timeout, out IntPtr result);
    [DllImport("user32.dll")]
    public static extern bool PrintWindow(IntPtr handle, IntPtr target, uint flags);
}
'@

$zip = Get-ChildItem dist/*-windows-x64.zip | Select-Object -First 1
if (-not $zip) { throw 'Packaged Windows ZIP not found' }
$folder = Join-Path $env:RUNNER_TEMP 'landlord-lan-smoke'
Expand-Archive -Path $zip.FullName -DestinationPath $folder -Force
New-Item smoke -ItemType Directory -Force | Out-Null
$process = Start-Process "$folder/LandlordLAN.exe" -WorkingDirectory $folder -PassThru `
    -RedirectStandardOutput "$PWD/smoke/stdout.log" -RedirectStandardError "$PWD/smoke/stderr.log"
try {
    $ready = $false
    for ($attempt = 0; $attempt -lt 40; $attempt++) {
        Start-Sleep -Milliseconds 500
        $process.Refresh()
        if ($process.HasExited) { throw "App exited during startup: $($process.ExitCode)" }
        if ($process.MainWindowHandle -ne [IntPtr]::Zero) { $ready = $true; break }
    }
    if (-not $ready) { throw 'Flutter did not produce a visible application window' }
    if ($process.MainWindowTitle -ne 'Landlord LAN') { throw 'Unexpected window title' }
    $result = [IntPtr]::Zero
    $responsive = [WindowProbe]::SendMessageTimeout($process.MainWindowHandle, 0, [IntPtr]::Zero, [IntPtr]::Zero, 2, 5000, [ref]$result)
    if ($responsive -eq [IntPtr]::Zero) { throw 'Window is unresponsive' }
    $modules = @($process.Modules | ForEach-Object { $_.ModuleName })
    foreach ($module in @('flutter_windows.dll', 'nsd_windows_plugin.dll')) {
        if ($module -notin $modules) { throw "Native module not loaded: $module" }
    }
    [WindowProbe]::MoveWindow($process.MainWindowHandle, 40, 40, 1000, 650, $true) | Out-Null
    Start-Sleep -Seconds 3
    $process.Refresh()
    if ($process.HasExited) { throw 'App exited after resizing' }

    # Capture the real runner window when the CI desktop supports PrintWindow.
    try {
        Add-Type -AssemblyName System.Drawing
        $rect = [WindowProbe+Rect]::new()
        [WindowProbe]::GetWindowRect($process.MainWindowHandle, [ref]$rect) | Out-Null
        $bitmap = [System.Drawing.Bitmap]::new($rect.Right - $rect.Left, $rect.Bottom - $rect.Top)
        $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
        $dc = $graphics.GetHdc()
        try { $captured = [WindowProbe]::PrintWindow($process.MainWindowHandle, $dc, 2) }
        finally { $graphics.ReleaseHdc($dc) }
        if ($captured) { $bitmap.Save("$PWD/smoke/windows.png", [System.Drawing.Imaging.ImageFormat]::Png) }
        $graphics.Dispose()
        $bitmap.Dispose()
    } catch { Write-Warning "Screenshot unavailable: $_" }

    if (-not $process.CloseMainWindow()) { throw 'Could not request normal app exit' }
    if (-not $process.WaitForExit(10000)) { throw 'App did not exit after closing the window' }
    if ($process.ExitCode -ne 0) { throw "App exited with error: $($process.ExitCode)" }
    'Windows portable ZIP launched, rendered a window, loaded Flutter and NSD, resized, and exited normally.' |
        Set-Content smoke/RESULT.txt
    Get-Content smoke/RESULT.txt
} finally {
    if (-not $process.HasExited) { Stop-Process -Id $process.Id -Force }
}
