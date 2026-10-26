# make_sprites.ps1 - M3: 程序化合成游戏 sprite（芽苞/树皮/粒子）
# 修复版：所有 Pen 用 ::new + [single] 宽度（PS5.1 重载解析）；
#          树皮纹用 PointF[] + DrawLines（不再手工维护 lastX/lastY）。
param(
    [string]$OutDir = "F:\PuzzleGame\game\assets\art"
)
Add-Type -AssemblyName System.Drawing
$rng = New-Object System.Random(20261026)
$AA = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias

function New-Canvas([int]$w, [int]$h) {
    $bmp = New-Object System.Drawing.Bitmap($w, $h)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = $AA
    return @($bmp, $g)
}

function New-Pen([System.Drawing.Color]$col, [int]$w) {
    return [System.Drawing.Pen]::new($col, [single]$w)
}

function New-GrainPoints([single]$y0, [single]$amp, [double]$phase) {
    # 沿 x 方向的周期性波纹点列（sin 周期 128 → 平铺无缝）
    $list = [System.Collections.Generic.List[System.Drawing.PointF]]::new()
    for ($k = 0; $k -lt 20; $k++) {
        $x = -16 + $k * 8
        $y = $y0 + [math]::Sin($x * [math]::PI / 64.0 + $phase) * $amp
        $list.Add([System.Drawing.PointF]::new([single]$x, [single]$y))
    }
    return $list.ToArray()
}

# ---------- 叶簇 sprite（统一绿色，M3 改版：所有节点同一图案） ----------
# 设计：径向叶簇（18 片叶，后深前浅），底部带小枝梗，贴近真实树丛的树冠质感。
$budDir = Join-Path $OutDir "buds"
New-Item -ItemType Directory -Force -Path $budDir | Out-Null
$res = New-Canvas 128 128
$bmp, $g = $res

$colLeafDark  = [System.Drawing.Color]::FromArgb(255, 46, 92, 38)
$colLeafMid   = [System.Drawing.Color]::FromArgb(255, 82, 148, 60)
$colLeafLight = [System.Drawing.Color]::FromArgb(255, 146, 205, 100)
$colRim       = [System.Drawing.Color]::FromArgb(140, 30, 62, 26)
$colVein      = [System.Drawing.Color]::FromArgb(110, 34, 70, 28)
$colStem      = [System.Drawing.Color]::FromArgb(255, 116, 86, 56)
$colStemRim   = [System.Drawing.Color]::FromArgb(180, 70, 48, 30)

function Get-LerpColor($a, $b, [double]$t) {
    return [System.Drawing.Color]::FromArgb(255,
        [int]($a.R + ($b.R - $a.R) * $t),
        [int]($a.G + ($b.G - $a.G) * $t),
        [int]($a.B + ($b.B - $a.B) * $t))
}

# 径向叶簇：后层深色大叶 → 前层浅色小叶（无枝梗——纯叶簇图标，枝干由 BranchView 表达）
$leafCount = 18
for ($i = 0; $i -lt $leafCount; $i++) {
    $t = [double]$i / [double]($leafCount - 1)
    $ang = $t * 2.0 * [math]::PI + ($rng.NextDouble() - 0.5) * 0.5
    $dist = 6.0 + $rng.NextDouble() * 26.0
    $cx = 64.0 + [math]::Cos($ang) * $dist
    $cy = 64.0 + [math]::Sin($ang) * $dist
    $len = 30.0 + $rng.NextDouble() * 14.0 - $t * 6.0
    $wid = $len * (0.52 + $rng.NextDouble() * 0.1)
    $rot = [single]($ang * 180.0 / [math]::PI + 90.0 + ($rng.NextDouble() - 0.5) * 40.0)
    $col = Get-LerpColor $colLeafDark $(if ($t -lt 0.5) { $colLeafMid } else { $colLeafLight }) ([math]::Pow($t, 0.85))
    $g.TranslateTransform([single]$cx, [single]$cy)
    $g.RotateTransform($rot)
    $leafRect = [System.Drawing.RectangleF]::new([single](-$len / 2), [single](-$wid / 2), [single]$len, [single]$wid)
    $brush = [System.Drawing.SolidBrush]::new($col)
    $g.FillEllipse($brush, $leafRect)
    $brush.Dispose()
    $rimPen = New-Pen $colRim 1
    $g.DrawEllipse($rimPen, $leafRect)
    $rimPen.Dispose()
    $veinPen = New-Pen $colVein 1
    $g.DrawLine($veinPen, [single](-$len / 2 + 3), [single]0, [single]($len / 2 - 3), [single]0)
    $veinPen.Dispose()
    $g.ResetTransform()
}
# 顶部高光小叶簇
$hlBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(105, 208, 240, 165))
foreach ($h in @(@(48, 26, 24, 16), @(70, 30, 20, 13), @(58, 40, 26, 16))) {
    $g.FillEllipse($hlBrush, $h[0], $h[1], $h[2], $h[3])
}
$hlBrush.Dispose()
$g.Dispose()
$budPath = Join-Path $budDir "foliage_green.png"
$bmp.Save($budPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "OK $budPath"

# ---------- 树皮平铺纹理（128x64，x 轴 = 枝条方向，周期无缝） ----------
$barkDir = Join-Path $OutDir "bark"
New-Item -ItemType Directory -Force -Path $barkDir | Out-Null
$res = New-Canvas 128 64
$bmp, $g = $res
# 先整体清除为不透明底色（Canvas 初始为全透明，半透明线条会残留 alpha → 引擎内与背景混合发灰）
$g.Clear([System.Drawing.Color]::FromArgb(255, 70, 50, 36))
$baseRect = [System.Drawing.Rectangle]::new(0, 0, 128, 64)
$base = [System.Drawing.Drawing2D.LinearGradientBrush]::new($baseRect, [System.Drawing.Color]::FromArgb(255, 92, 68, 48), [System.Drawing.Color]::FromArgb(255, 70, 50, 36), [single]90)
$g.FillRectangle($base, $baseRect)
$base.Dispose()
# 暗色纵向纹（沿 x 方向波动）
for ($i = 0; $i -lt 18; $i++) {
    $y0 = [single]$rng.Next(0, 64)
    $amp = [single](2 + $rng.Next(0, 3))
    $phase = $rng.NextDouble() * 6.28
    $col = [System.Drawing.Color]::FromArgb(70 + $rng.Next(0, 100), 66, 48, 34)
    $pen = New-Pen $col (1 + $rng.Next(0, 3))
    try { $g.DrawLines($pen, (New-GrainPoints $y0 $amp $phase)) } catch { Write-Output "WARN grain dark $i : $($_.Exception.Message)" }
    $pen.Dispose()
}
# 亮色高光纹
for ($i = 0; $i -lt 10; $i++) {
    $y0 = [single]$rng.Next(0, 64)
    $amp = [single](1 + $rng.Next(0, 3))
    $phase = $rng.NextDouble() * 6.28
    $col = [System.Drawing.Color]::FromArgb(45 + $rng.Next(0, 70), 152, 122, 88)
    $pen = New-Pen $col (1 + $rng.Next(0, 2))
    try { $g.DrawLines($pen, (New-GrainPoints $y0 $amp $phase)) } catch { Write-Output "WARN grain light $i : $($_.Exception.Message)" }
    $pen.Dispose()
}
# 细噪点
$noiseDark = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(40, 60, 44, 30))
$noiseLight = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(40, 150, 125, 92))
for ($i = 0; $i -lt 500; $i++) {
    $x = $rng.Next(0, 128); $y = $rng.Next(0, 64)
    if ($rng.Next(0, 2) -eq 0) { $g.FillRectangle($noiseDark, $x, $y, 1, 1) }
    else { $g.FillRectangle($noiseLight, $x, $y, 1, 1) }
}
$noiseDark.Dispose(); $noiseLight.Dispose()
$g.Dispose()
$barkPath = Join-Path $barkDir "bark_tile.png"
$bmp.Save($barkPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "OK $barkPath"

# ---------- 粒子：落叶 / 木屑 ----------
$partDir = Join-Path $OutDir "particles"
New-Item -ItemType Directory -Force -Path $partDir | Out-Null

# 落叶 32x32
$res = New-Canvas 32 32
$bmp, $g = $res
$g.TranslateTransform(16, 16)
$g.RotateTransform(35)
$leafRect = [System.Drawing.Rectangle]::new(-14, -7, 28, 14)
$leafBrush = [System.Drawing.Drawing2D.LinearGradientBrush]::new($leafRect, [System.Drawing.Color]::FromArgb(255, 120, 176, 88), [System.Drawing.Color]::FromArgb(255, 62, 122, 54), [single]0)
$g.FillEllipse($leafBrush, $leafRect)
$leafBrush.Dispose()
$veinPen = New-Pen ([System.Drawing.Color]::FromArgb(170, 44, 92, 40)) 1
$g.DrawLine($veinPen, -14, 0, 14, 0)
$veinPen.Dispose()
$g.ResetTransform()
$g.Dispose()
$leafPath = Join-Path $partDir "leaf_01.png"
$bmp.Save($leafPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "OK $leafPath"

# 木屑 16x16
$res = New-Canvas 16 16
$bmp, $g = $res
$chipPts = @(
    (New-Object System.Drawing.Point(2, 9)), (New-Object System.Drawing.Point(7, 2)),
    (New-Object System.Drawing.Point(14, 8)), (New-Object System.Drawing.Point(8, 14))
)
$chipBrush = [System.Drawing.SolidBrush]::new([System.Drawing.Color]::FromArgb(255, 152, 112, 70))
$g.FillPolygon($chipBrush, $chipPts)
$chipBrush.Dispose()
$chipPen = New-Pen ([System.Drawing.Color]::FromArgb(180, 190, 148, 98)) 1
$g.DrawPolygon($chipPen, $chipPts)
$chipPen.Dispose()
$g.Dispose()
$chipPath = Join-Path $partDir "chip_01.png"
$bmp.Save($chipPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "OK $chipPath"

Write-Output "SPRITES DONE"

# ---------- 亮色统一背景（720x1280，M3 改版：固定亮调，与绿节点/棕枝条强对比） ----------
# 设计：暖纸色 → 浅薄荷绿纵向渐变 + 柔和光斑（林间光感），整体保持高亮度。
$bgDir = Join-Path $OutDir "backgrounds"
New-Item -ItemType Directory -Force -Path $bgDir | Out-Null
$res = New-Canvas 720 1280
$bmp, $g = $res
$g.Clear([System.Drawing.Color]::FromArgb(255, 247, 242, 226))  # 不透明底，防 alpha 残留
$bgRect = [System.Drawing.Rectangle]::new(0, 0, 720, 1280)
$bgGrad = [System.Drawing.Drawing2D.LinearGradientBrush]::new($bgRect,
    [System.Drawing.Color]::FromArgb(255, 247, 242, 226),
    [System.Drawing.Color]::FromArgb(255, 216, 233, 201), [single]90)
$g.FillRectangle($bgGrad, $bgRect)
$bgGrad.Dispose()
# 柔光斑（PathGradient 软边圆，模拟叶隙光）
for ($i = 0; $i -lt 42; $i++) {
    $r = 26 + $rng.Next(0, 70)
    $x = $rng.Next(-20, 720)
    $y = $rng.Next(-20, 1280)
    $gp = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $gp.AddEllipse($x - $r, $y - $r, $r * 2, $r * 2)
    $pg = [System.Drawing.Drawing2D.PathGradientBrush]::new($gp)
    $alpha = 14 + $rng.Next(0, 24)
    $warm = $rng.Next(0, 2) -eq 0
    if ($warm) { $pg.CenterColor = [System.Drawing.Color]::FromArgb($alpha, 255, 252, 235) }
    else { $pg.CenterColor = [System.Drawing.Color]::FromArgb($alpha, 255, 255, 255) }
    $pg.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 255, 255, 255))
    $g.FillPath($pg, $gp)
    $pg.Dispose(); $gp.Dispose()
}
# 四角极浅的青绿氛围（alpha<=10，保持整体亮）
foreach ($c in @(@(-160, -160), @(560, -200), @(-180, 1060), @(540, 1080))) {
    $gp = [System.Drawing.Drawing2D.GraphicsPath]::new()
    $gp.AddEllipse($c[0], $c[1], 340, 340)
    $pg = [System.Drawing.Drawing2D.PathGradientBrush]::new($gp)
    $pg.CenterColor = [System.Drawing.Color]::FromArgb(26, 168, 205, 150)
    $pg.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 168, 205, 150))
    $g.FillPath($pg, $gp)
    $pg.Dispose(); $gp.Dispose()
}
$g.Dispose()
$bgPath = Join-Path $bgDir "bg_bright.png"
$bmp.Save($bgPath, [System.Drawing.Imaging.ImageFormat]::Png)
$bmp.Dispose()
Write-Output "OK $bgPath"
