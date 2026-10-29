# Gera folhas de contato do combate (janela real, entrada simulada).
param([string]$Out = 'docs/h2/capturas')
. "$PSScriptRoot\godot.ps1"
$root = Split-Path -Parent $PSScriptRoot
$godot = Find-Godot -Console $true
if (-not (Test-Path (Join-Path $root '.godot'))) { & $godot --headless --path $root --import | Out-Null }
& $godot --path $root --rendering-driver vulkan --windowed --resolution 1280x720 -s res://tools/combat_sheet.gd -- "--out=$Out"
exit $LASTEXITCODE
