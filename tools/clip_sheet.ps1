# Folha de contato de um clipe. Uso: tools\clip_sheet.ps1 -Clip Sword_Attack [-Out docs/h2/pesquisa] [-Tiles 12]
param([string]$Clip = "Sword_Attack", [string]$Out = "docs/h2/pesquisa", [int]$Tiles = 12, [int]$Mirror = 0, [double]$From = -1, [double]$To = -1, [string]$Res = "", [switch]$Katana, [string]$Cam = "6,1.1,0")
. "$PSScriptRoot\godot.ps1"
$root = Split-Path -Parent $PSScriptRoot
$godot = Find-Godot -Console $true
& $godot --path $root --rendering-driver vulkan --windowed --resolution 1280x720 -s res://tools/clip_sheet.gd -- "--clip=$Clip" "--out=$Out" "--tiles=$Tiles" "--mirror=$Mirror" "--from=$From" "--to=$To" "--res=$Res" $(if ($Katana) { "--katana" }) "--cam=$Cam"
exit $LASTEXITCODE
