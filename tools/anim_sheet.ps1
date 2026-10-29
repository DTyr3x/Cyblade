# Gera folhas de contato da locomoção do humanoide (janela real, entrada simulada).
param([string]$Out = 'docs/h1/capturas')
. "$PSScriptRoot\godot.ps1"
$root = Split-Path -Parent $PSScriptRoot
$godot = Find-Godot -Console $true
if (-not (Test-Path (Join-Path $root '.godot'))) { & $godot --headless --path $root --import | Out-Null }
& $godot --path $root --rendering-driver vulkan --windowed --resolution 1280x720 -s res://tools/anim_sheet.gd -- "--out=$Out"
exit $LASTEXITCODE
