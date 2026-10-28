# Roda os testes automatizados (sem janela). Sai com código 0 se todos passarem.
. "$PSScriptRoot\godot.ps1"
$root = Split-Path -Parent $PSScriptRoot
$godot = Find-Godot -Console $true

if (-not (Test-Path (Join-Path $root '.godot'))) {
    & $godot --headless --path $root --import | Out-Null
}

& $godot --headless --path $root --fixed-fps 120 -s res://tests/run_tests.gd
exit $LASTEXITCODE
