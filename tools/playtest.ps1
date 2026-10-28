# Roda o playtest scriptado em janela (GPU real), com entrada simulada, e grava
# capturas e métricas em docs\playtest\marco-1 (ou na pasta indicada em -Out).
param([string]$Out = 'docs/playtest/marco-1')

. "$PSScriptRoot\godot.ps1"
$root = Split-Path -Parent $PSScriptRoot
$godot = Find-Godot -Console $true

if (-not (Test-Path (Join-Path $root '.godot'))) {
    & $godot --headless --path $root --import | Out-Null
}

& $godot --path $root --rendering-driver vulkan --windowed --resolution 1920x1080 --disable-vsync -- --playtest "--out=$Out"
exit $LASTEXITCODE
