# make_sfx.ps1 - M3: 程序化合成 WAV 音效（44100Hz 16bit 单声道）
# snip 剪枝 / error 误剪 / win 通关 / lose 失败 / click 按钮 / bgm_wind 环境风声循环
param(
    [string]$OutDir = "F:\PuzzleGame\game\assets\audio"
)
$sr = 44100
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$rng = New-Object System.Random(7)

function Write-Wav([string]$path, [double[]]$samples) {
    $n = $samples.Count
    $dataLen = $n * 2
    $ms = New-Object System.IO.MemoryStream
    $bw = New-Object System.IO.BinaryWriter($ms)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("RIFF"))
    $bw.Write([uint32](36 + $dataLen))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("WAVE"))
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("fmt "))
    $bw.Write([uint32]16); $bw.Write([uint16]1); $bw.Write([uint16]1)
    $bw.Write([uint32]$sr); $bw.Write([uint32]($sr * 2))
    $bw.Write([uint16]2); $bw.Write([uint16]16)
    $bw.Write([System.Text.Encoding]::ASCII.GetBytes("data"))
    $bw.Write([uint32]$dataLen)
    for ($i = 0; $i -lt $n; $i++) {
        $v = [math]::Max(-1.0, [math]::Min(1.0, $samples[$i]))
        $bw.Write([int16]($v * 32000.0))
    }
    $bw.Flush()
    [System.IO.File]::WriteAllBytes($path, $ms.ToArray())
    $bw.Close(); $ms.Dispose()
    Write-Output "OK $path ($([math]::Round($n / $sr, 2))s)"
}

$PI = [math]::PI

# ---- snip: 咔嚓（白噪爆发 + 高频瞬态）----
$len = [int]($sr * 0.075)
$a = New-Object double[] $len
for ($i = 0; $i - $len; $i++) {
    $t = $i / $sr
    $a[$i] = ($rng.NextDouble() * 2.0 - 1.0) * [math]::Exp(-$t * 55.0) * 0.85
    $a[$i] += [math]::Sin(2.0 * $PI * 3300.0 * $t) * [math]::Exp(-$t * 240.0) * 0.45
}
Write-Wav (Join-Path $OutDir "snip.wav") $a

# ---- error: 误剪（低频下滑闷响）----
$len = [int]($sr * 0.20)
$a = New-Object double[] $len
for ($i = 0; $i -lt $len; $i++) {
    $t = $i / $sr
    $f = 170.0 * [math]::Pow(0.32, $t / 0.2)
    $env = [math]::Exp(-$t * 9.0)
    $a[$i] = ([math]::Sin(2.0 * $PI * $f * $t) * 0.75 + [math]::Sin(4.0 * $PI * $f * $t) * 0.2) * $env * 0.8
}
Write-Wav (Join-Path $OutDir "error.wav") $a

# ---- win: 通关（上行琶音 C-E-G-C）----
$len = [int]($sr * 0.75)
$a = New-Object double[] $len
$notes = @(523.25, 659.25, 783.99, 1046.5)
$seg = [int]($sr * 0.14)
for ($k = 0; $k -lt $notes.Count; $k++) {
    $start = $k * $seg
    $end = [math]::Min($start + [int]($sr * 0.3), $len)
    for ($i = $start; $i -lt $end; $i++) {
        $t = ($i - $start) / $sr
        $env = [math]::Exp(-$t * 6.5) * [math]::Min(1.0, $t * 200.0)
        $a[$i] += ([math]::Sin(2.0 * $PI * $notes[$k] * $t) * 0.6 + [math]::Sin(2.0 * $PI * $notes[$k] * 2.0 * $t) * 0.15) * $env * 0.55
    }
}
Write-Wav (Join-Path $OutDir "win.wav") $a

# ---- lose: 失败（下行小调滑音）----
$len = [int]($sr * 0.55)
$a = New-Object double[] $len
for ($i = 0; $i -lt $len; $i++) {
    $t = $i / $sr
    $f = 300.0 - 140.0 * ($t / 0.55)
    $env = [math]::Exp(-$t * 3.2) * [math]::Min(1.0, $t * 120.0)
    $a[$i] = ([math]::Sin(2.0 * $PI * $f * $t) * 0.7 + [math]::Sin(2.0 * $PI * $f * 1.5 * $t) * 0.25) * $env * 0.65
}
Write-Wav (Join-Path $OutDir "lose.wav") $a

# ---- click: 按钮（短促滴答）----
$len = [int]($sr * 0.035)
$a = New-Object double[] $len
for ($i = 0; $i -lt $len; $i++) {
    $t = $i / $sr
    $a[$i] = [math]::Sin(2.0 * $PI * 1800.0 * $t) * [math]::Exp(-$t * 130.0) * 0.5
}
Write-Wav (Join-Path $OutDir "click.wav") $a

# ---- bgm_wind: 环境风声循环（8s，低通噪声 + 缓慢起伏）----
$len = [int]($sr * 8.0)
$a = New-Object double[] $len
$lp = 0.0
$k = 42.0
for ($i = 0; $i -lt $len; $i++) {
    $t = $i / $sr
    $x = $rng.NextDouble() * 2.0 - 1.0
    $lp += ($x - $lp) / $k
    $lfo = 0.55 + 0.45 * [math]::Sin(2.0 * $PI * 0.11 * $t)
    $a[$i] = $lp * $lfo * 0.32
}
# 首尾交叉淡化，保证循环无缝
$fade = [int]($sr * 0.5)
for ($i = 0; $i -lt $fade; $i++) {
    $w = $i / $fade
    $head = $a[$i]
    $tail = $a[$len - $fade + $i]
    $a[$i] = $head * $w + $tail * (1.0 - $w)
}
for ($i = 0; $i -lt $fade; $i++) {
    $a[$len - $fade + $i] = 0.0
}
Write-Wav (Join-Path $OutDir "bgm_wind.wav") $a

Write-Output "SFX DONE"
