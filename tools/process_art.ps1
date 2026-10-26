# process_art.ps1 - 通用图片后处理工具（M3）
# 用途：把人工/商业 AI 工具生成的大图（放 art_src/）裁剪缩放为游戏内规格。
# 用法示例：
#   powershell -File tools\process_art.ps1 -Src "F:\PuzzleGame\art_src\bg3.jpg" `
#       -Dst "F:\PuzzleGame\game\assets\art\backgrounds\bg_forest_03.png" `
#       -Width 720 -Height 1280 -Darken 70
#   .\tools\process_art.ps1 -Src art_src\bud.png -Dst game\assets\art\buds\bud_06.png -Width 128 -Height 128
param(
    [Parameter(Mandatory = $true)][string]$Src,
    [Parameter(Mandatory = $true)][string]$Dst,
    [int]$Width = 720,
    [int]$Height = 1280,
    [int]$Darken = 0,          # 0-255 全局压暗强度（背景建议 70）
    [switch]$Vignette          # 背景建议加晕影
)
Add-Type -AssemblyName System.Drawing

if (-not (Test-Path $Src)) { Write-Error "源文件不存在: $Src"; exit 1 }

$img = [System.Drawing.Image]::FromFile($Src)
$sw = $img.Width; $sh = $img.Height

# 中心裁剪到目标宽高比
$targetRatio = $Width / $Height
$srcRatio = $sw / $sh
if ($srcRatio -gt $targetRatio) {
    $cw = [int]($sh * $targetRatio); $ch = $sh; $cx = [int](($sw - $cw) / 2); $cy = 0
} else {
    $cw = $sw; $ch = [int]($sw / $targetRatio); $cx = 0; $cy = [int](($sh - $ch) / 2)
}
$srcRect = [System.Drawing.Rectangle]::new($cx, $cy, $cw, $ch)

$bmp = New-Object System.Drawing.Bitmap($Width, $Height)
$g = [System.Drawing.Graphics]::FromImage($bmp)
$g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
$g.DrawImage($img, [System.Drawing.Rectangle]::new(0, 0, $Width, $Height), $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
$img.Dispose()

if ($Darken -gt 0) {
    $brush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb($Darken, 12, 20, 14))
    $g.FillRectangle($brush, 0, 0, $Width, $Height)
    $brush.Dispose()
}
if ($Vignette) {
    $gp = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $gp.AddEllipse([int](-$Width * 0.22), [int](-$Height * 0.13), [int]($Width * 1.44), [int]($Height * 1.25))
    $pgrad = [System.Drawing.Drawing2D.PathGradientBrush]::new($gp)
    $pgrad.CenterColor = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
    $pgrad.SurroundColors = @([System.Drawing.Color]::FromArgb(150, 8, 14, 10))
    $g.FillPath($pgrad, $gp)
    $pgrad.Dispose(); $gp.Dispose()
}
$g.Dispose()

$dstDir = Split-Path $Dst -Parent
if ($dstDir) { New-Item -ItemType Directory -Force -Path $dstDir | Out-Null }
$bmp.Save($Dst, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "OK $Dst (${Width}x${Height}, darken=$Darken, vignette=$Vignette)"
