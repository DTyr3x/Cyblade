# Compara o alcance real dos golpes com render a 30, 60, 120 e 144 FPS (física em 120 Hz).
. "$PSScriptRoot\godot.ps1"
$root = Split-Path -Parent $PSScriptRoot
$godot = Find-Godot -Console $true
$base = $null
$fail = 0
foreach ($fps in 30, 60, 120, 144) {
    $lines = (& $godot --headless --path $root --fixed-fps $fps -s res://tests/hit_reach_check.gd | Select-String '\[alcance\]' | ForEach-Object { $_.Line }) -join "`n"
    Write-Output "-- $fps FPS`n$lines"
    if ($null -eq $base) { $base = $lines } elseif ($lines -ne $base) { $fail += 1 }
}
if ($fail -eq 0) { Write-Output '== alcance igual em todos os FPS ==' } else { Write-Output "== alcance difere em $fail taxa(s) ==" }
exit $fail
