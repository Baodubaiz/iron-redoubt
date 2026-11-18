# Builds the signed playtest APK (Phase 6).
# Usage (PowerShell, from the project folder):  powershell -ExecutionPolicy Bypass -File tools\build_android.ps1
# Toolchain layout (all under C:\code):
#   C:\code\godot\Godot_v4.7.2-stable_win64.exe\   Godot editor (console exe used here)
#   C:\code\godot\export_templates\4.7.2.stable\   Android export templates (junctioned into %APPDATA%\Godot)
#   C:\code\android-sdk\                           cmdline-tools, platform-tools, build-tools;36.1.0
#   C:\code\java\                                  JDK
#   C:\code\android-keystores\                     playtest signing key + credentials (never commit)
$ErrorActionPreference = "Stop"
$godot = "C:\code\godot\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64_console.exe"
$cred = "C:\code\android-keystores\hexavanguard-playtest.credentials.txt"
if (-not (Test-Path $cred)) { throw "Missing $cred (playtest keystore credentials)." }
$kv = @{}
Get-Content $cred | ForEach-Object { $p = $_ -split "=", 2; if ($p.Count -eq 2) { $kv[$p[0]] = $p[1] } }
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $kv["keystore"]
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = $kv["alias"]
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $kv["password"]
$env:JAVA_HOME = "C:\code\java"
New-Item -ItemType Directory -Force build | Out-Null
$out = "build/IronRedoubt-0.10.0-playtest.apk"
& $godot --headless --path . --export-release "Android Playtest" $out *> build/export.log
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $out)) { Get-Content build/export.log -Tail 30; throw "Export failed" }
& "C:\code\android-sdk\build-tools\36.1.0\apksigner.bat" verify $out
Write-Host "APK ready: $out ($([math]::Round((Get-Item $out).Length / 1MB, 1)) MB)"
