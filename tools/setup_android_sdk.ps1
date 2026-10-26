# setup_android_sdk.ps1 - M4: JDK 就绪后一键安装 SDK 组件 + 生成 debug 密钥库
# 用法: powershell -File F:\PuzzleGame\tools\setup_android_sdk.ps1
$ErrorActionPreference = "Stop"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$javaHome = "F:\PuzzleGame\tools\jdk17"
$sdkRoot = "F:\PuzzleGame\tools\android-sdk"
$sdkmanager = "$sdkRoot\cmdline-tools\latest\bin\sdkmanager.bat"
$keystoreDir = "F:\PuzzleGame\tools\keystore"
$keystore = "$keystoreDir\debug.keystore"

if (-not (Test-Path "$javaHome\bin\java.exe")) { Write-Error "JDK17 未就绪: $javaHome"; exit 1 }
$env:JAVA_HOME = $javaHome
$env:Path = "$javaHome\bin;" + $env:Path

# ---- 1. 安装 SDK 组件（走默认 dl.google.com，若被墙则失败——已验证 cmdline-tools 镜像可通，
#         组件包较小，先试官方源；失败需改用腾讯镜像手动下载 platform-tools/build-tools）----
Write-Output "[1/3] sdkmanager 安装 platform-tools / platforms;android-34 / build-tools;34.0.0 ..."
$yes = "y`r`n" * 20
$yes | & $sdkmanager --sdk_root="$sdkRoot" "platform-tools" "platforms;android-34" "build-tools;34.0.0" 2>&1 | Select-Object -Last 8
foreach ($p in @("$sdkRoot\platform-tools\adb.exe", "$sdkRoot\platforms\android-34", "$sdkRoot\build-tools\34.0.0\apksigner.bat")) {
    if (-not (Test-Path $p)) { Write-Error "SDK 组件缺失: $p"; exit 1 }
}
Write-Output "[1/3] SDK 组件安装完成"

# ---- 2. 接受许可 ----
Write-Output "[2/3] 接受 SDK 许可 ..."
$yes | & $sdkmanager --sdk_root="$sdkRoot" --licenses 2>&1 | Select-Object -Last 2
Write-Output "[2/3] 许可已处理"

# ---- 3. 生成 debug 密钥库 ----
New-Item -ItemType Directory -Force -Path $keystoreDir | Out-Null
if (Test-Path $keystore) { Remove-Item $keystore -Force }
& "$javaHome\bin\keytool.exe" -genkeypair -v -keystore $keystore -storepass android -alias androiddebugkey -keypass android -keyalg RSA -keysize 2048 -validity 10000 -dname "CN=Android Debug,O=Android,C=US" 2>&1 | Select-Object -Last 2
if (-not (Test-Path $keystore)) { Write-Error "密钥库生成失败"; exit 1 }
Write-Output "[3/3] debug.keystore 生成完成"
Write-Output "SETUP OK"
