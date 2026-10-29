# Roda a verificação do parry com render a 30, 60 e 144 FPS (física em 120 Hz).
. "$PSScriptRoot\godot.ps1"
$root = Split-Path -Parent $PSScriptRoot
$godot = Find-Godot -Console $true
$fail = 0
foreach ($fps in 30, 60, 144) {
    Write-Output "-- render a $fps FPS"
    & $godot --headless --path $root --fixed-fps $fps -s res://tests/parry_fps_check.gd | Select-String 'PASS|FAIL|==|SCRIPT'
    if ($LASTEXITCODE -ne 0) { $fail += 1 }
}
exit $fail
