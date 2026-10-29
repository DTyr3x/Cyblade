# Compara as poses de transição Kesa -> Kiriage (frente e lado).
param([string]$Out = 'docs/h2-2/estudo')
. "$PSScriptRoot\godot.ps1"
$root = Split-Path -Parent $PSScriptRoot
$godot = Find-Godot -Console $true
& $godot --path $root --rendering-driver vulkan --windowed --resolution 1280x720 -s res://tools/pose_compare.gd -- "--out=$Out"
exit $LASTEXITCODE
