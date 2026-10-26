# export_android.ps1 - M4: 一键导出 Android APK 并校验
# 用法: powershell -File F:\PuzzleGame\tools\export_android.ps1            （调试包）
#       powershell -File F:\PuzzleGame\tools\export_android.ps1 -Release  （正式发布包，release 签名）
param(
    [switch]$Release,
    [string]$OutApk = ""
)
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$godot = "F:\PuzzleGame\tools\godot\Godot_v4.7.2-stable_win64_console.exe"
$javaHome = "F:\PuzzleGame\tools\jdk17"
$sdkRoot = "F:\PuzzleGame\tools\android-sdk"
$project = "F:\PuzzleGame\game"
if ($Release) {
    if ($OutApk -eq "") { $OutApk = "F:\PuzzleGame\builds\PruneMaster_release.apk" }
    $keystore = "F:\PuzzleGame\tools\keystore\release.keystore"
    $template = "F:\PuzzleGame\tools\export_templates\templates\android_release.apk"
    $exportFlag = "--export-release"
} else {
    if ($OutApk -eq "") { $OutApk = "F:\PuzzleGame\builds\PruneMaster_debug.apk" }
    $keystore = "F:\PuzzleGame\tools\keystore\debug.keystore"
    $template = "F:\PuzzleGame\tools\export_templates\templates\android_debug.apk"
    $exportFlag = "--export-debug"
}

# ---- 1. 环境检查 ----
$missing = @()
foreach ($p in @($godot, "$javaHome\bin\java.exe", "$sdkRoot\cmdline-tools\latest\bin\sdkmanager.bat", $keystore, $template)) {
    if (-not (Test-Path $p)) { $missing += $p }
}
if ($missing.Count -gt 0) {
    Write-Error ("环境未就绪，缺少：`n" + ($missing -join "`n"))
    exit 1
}
$env:JAVA_HOME = $javaHome
$env:ANDROID_HOME = $sdkRoot
Write-Output "[1/4] 环境检查 OK (JDK17 / Android SDK / keystore / 导出模板)"

# ---- 2. 资源导入（保证 .godot 缓存最新）----
& $godot --headless --path $project --import | Out-Null
if ($LASTEXITCODE -ne 0) { Write-Error "资源导入失败"; exit 1 }
Write-Output "[2/4] 资源导入完成"

# ---- 3. 导出 ----
if (Test-Path $OutApk) { Remove-Item $OutApk -Force }
& $godot --headless --path $project $exportFlag "Android" $OutApk
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $OutApk)) { Write-Error "APK 导出失败 (exit $LASTEXITCODE)"; exit 1 }
$sizeMB = [math]::Round((Get-Item $OutApk).Length / 1MB, 1)
Write-Output "[3/4] 导出完成: $OutApk (${sizeMB}MB)"

# ---- 4. 签名校验 ----
$apksigner = Get-ChildItem "$sdkRoot\build-tools\*\apksigner.bat" | Select-Object -First 1
if ($apksigner) {
    $verifyOut = & $apksigner.FullName verify --print-certs $OutApk 2>&1
    $verifyCode = $LASTEXITCODE
    $verifyOut | Select-Object -First 3
    if ($verifyCode -eq 0) { Write-Output "[4/4] 签名校验通过" } else { Write-Error "签名校验失败"; exit 1 }
} else {
    Write-Output "[4/4] apksigner 未找到，跳过校验"
}
Write-Output "EXPORT OK: $OutApk"
