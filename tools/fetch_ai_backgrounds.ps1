# fetch_ai_backgrounds.ps1 - M3: 用 Pollinations.ai 免费生图 API 生成游戏背景
# 720x1280 竖屏，后处理（暗化+晕影），失败时用程序化森林兜底。
param(
    [string]$OutDir = "F:\PuzzleGame\game\assets\art\backgrounds"
)
$ProgressPreference = 'SilentlyContinue'
Add-Type -AssemblyName System.Drawing
$ErrorActionPreference = 'Continue'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

$jobs = @(
    @{
        name  = "bg_forest_01"
        seed  = 101
        prompt = "painterly 2D mobile game background, misty green forest grove, soft morning light rays through canopy, layered foliage depth, muted desaturated green and teal tones, vertical portrait composition, empty center area, no characters, no text, subtle dark vignette"
    },
    @{
        name  = "bg_forest_02"
        seed  = 102
        prompt = "painterly 2D mobile game background, dense autumn forest with warm amber sunlight filtering through trees, soft bokeh, muted olive and warm brown tones, vertical portrait composition, no characters, no text, dark vignette edges"
    }
)

function Invoke-PostProcess($img, $path) {
    # 裁掉底部 6%（去除生成水印）→ 缩放到 720x1280 + 全局压暗 + 晕影
    $srcW = $img.Width
    $srcH = $img.Height
    $cropH = [int]($srcH * 0.94)
    $srcRect = [System.Drawing.Rectangle]::new(0, 0, $srcW, $cropH)
    $bmp = New-Object System.Drawing.Bitmap(720, 1280)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.DrawImage($img, [System.Drawing.Rectangle]::new(0, 0, 720, 1280), $srcRect, [System.Drawing.GraphicsUnit]::Pixel)
    $img.Dispose()
    # 全局压暗
    $dark = [System.Drawing.Color]::FromArgb(70, 12, 20, 14)
    $brush = New-Object System.Drawing.SolidBrush($dark)
    $g.FillRectangle($brush, 0, 0, 720, 1280)
    $brush.Dispose()
    # 晕影（边缘更深）
    $path_ = New-Object System.Drawing.Drawing2D.GraphicsPath
    $path_.AddEllipse(-160, -160, 1040, 1600)
    $pgrad = New-Object System.Drawing.Drawing2D.PathGradientBrush($path_)
    $pgrad.CenterColor = [System.Drawing.Color]::FromArgb(0, 0, 0, 0)
    $pgrad.SurroundColors = @([System.Drawing.Color]::FromArgb(150, 8, 14, 10))
    $g.FillPath($pgrad, $path_)
    $pgrad.Dispose(); $path_.Dispose()
    $g.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

function New-ProceduralForest($path, $tone) {
    # 兜底：程序化雾林背景（渐变 + 四层树影 + 晕影）
    $bmp = New-Object System.Drawing.Bitmap(720, 1280)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
    $rect = New-Object System.Drawing.Rectangle(0, 0, 720, 1280)
    $top = [System.Drawing.Color]::FromArgb(255, $tone[0], $tone[1], $tone[2])
    $bot = [System.Drawing.Color]::FromArgb(255, [int]($tone[0] * 0.28), [int]($tone[1] * 0.35), [int]($tone[2] * 0.28))
    $lg = New-Object System.Drawing.Drawing2D.LinearGradientBrush($rect, $top, $bot, 90)
    $g.FillRectangle($lg, $rect)
    $lg.Dispose()
    $rng = New-Object System.Random(99)
    # 四层树影（越近越深）
    for ($layer = 0; $layer -lt 4; $layer++) {
        $alpha = 50 + $layer * 35
        $lum = 1.0 - $layer * 0.18
        $c = [System.Drawing.Color]::FromArgb($alpha, [int]($tone[0] * $lum * 0.6), [int]($tone[1] * $lum * 0.8), [int]($tone[2] * $lum * 0.55))
        $brush = New-Object System.Drawing.SolidBrush($c)
        $pen = New-Object System.Drawing.Pen($c, 10)
        $baseY = 420 + $layer * 240
        for ($t = 0; $t -lt 10 + $layer * 3; $t++) {
            $x = $rng.Next(-40, 720)
            $w = $rng.Next(60, 150)
            $h = $rng.Next(260, 520)
            $y = $baseY + $rng.Next(-90, 90)
            # 树冠 = 三角形簇 + 树干
            $pts = @(
                (New-Object System.Drawing.Point(([int]($x + $w / 2)), ([int]($y - $h)))),
                (New-Object System.Drawing.Point($x, $y)),
                (New-Object System.Drawing.Point(([int]($x + $w)), $y))
            )
            $g.FillPolygon($brush, $pts)
            $g.DrawLine($pen, [int]($x + $w / 2), $y, [int]($x + $w / 2), [int]($y + 120))
        }
        $brush.Dispose(); $pen.Dispose()
    }
    $dark = [System.Drawing.Color]::FromArgb(70, 12, 20, 14)
    $brush2 = New-Object System.Drawing.SolidBrush($dark)
    $g.FillRectangle($brush2, 0, 0, 720, 1280)
    $brush2.Dispose()
    $g.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
}

foreach ($j in $jobs) {
    $outPath = Join-Path $OutDir "$($j.name).png"
    $tmp = Join-Path $env:TEMP "$($j.name).jpg"
    $ok = $false
    try {
        $u = "https://image.pollinations.ai/prompt/$([uri]::EscapeDataString($j.prompt))?width=720&height=1280&nologo=true&seed=$($j.seed)"
        Invoke-WebRequest -Uri $u -OutFile $tmp -TimeoutSec 300
        $bytes = [System.IO.File]::ReadAllBytes($tmp)
        if ($bytes.Length -gt 30KB -and (($bytes[0] -eq 0x89 -and $bytes[1] -eq 0x50) -or ($bytes[0] -eq 0xFF -and $bytes[1] -eq 0xD8))) {
            $img = [System.Drawing.Image]::FromFile($tmp)
            if ($img.Width -ge 256) {
                Invoke-PostProcess $img $outPath
                Write-Output "OK $($j.name): AI generated ($($img.Width)x$($img.Height)) + post-processed"
                $ok = $true
            }
            $img.Dispose()
        }
    } catch {
        Write-Output "WARN $($j.name): pollinations failed - $($_.Exception.Message)"
    }
    if (-not $ok) {
        $tone = if ($j.name -eq "bg_forest_01") { @(170, 200, 180) } else { @(190, 170, 130) }
        New-ProceduralForest $outPath $tone
        Write-Output "OK $($j.name): procedural fallback"
    }
}
Write-Output "DONE: $((Get-ChildItem $OutDir -Filter *.png | Measure-Object).Count) backgrounds in $OutDir"
