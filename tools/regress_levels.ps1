# M6 回归：20 关逐个以真实游戏场景 headless 加载运行 90 帧，
# 捕获 SCRIPT ERROR / Parse Error / ERROR（排除 Godot 已知的退出期良性提示）。
# 用法: powershell -NoProfile -ExecutionPolicy Bypass -File tools/regress_levels.ps1
$ErrorActionPreference = "Continue"
$Godot = "F:\PuzzleGame\tools\godot\Godot_v4.7.2-stable_win64_console.exe"
$GameDir = "F:\PuzzleGame\game"

$failed = @()
for ($lvl = 1; $lvl -le 20; $lvl++) {
    $out = & $Godot --headless --path $GameDir --quit-after 90 res://scenes/game/game.tscn -- "--level=$lvl" 2>&1
    $txt = ($out | Out-String)
    $bad = $txt -split "`n" | Where-Object {
        $_ -match "SCRIPT ERROR|Parse Error|ERROR:" -and $_ -notmatch "still in use at exit|ObjectDB instances"
    }
    if ($bad) {
        $failed += $lvl
        Write-Host ("L{0:d2}: ERRORS" -f $lvl)
        $bad | Select-Object -First 4 | ForEach-Object { Write-Host "   $_" }
    } else {
        Write-Host ("L{0:d2}: CLEAN" -f $lvl)
    }
}
if ($failed.Count -eq 0) {
    Write-Host "`nREGRESSION PASS: 20/20 levels clean"
    exit 0
} else {
    Write-Host ("`nREGRESSION FAIL: {0} level(s) with errors: {1}" -f $failed.Count, ($failed -join ","))
    exit 1
}
