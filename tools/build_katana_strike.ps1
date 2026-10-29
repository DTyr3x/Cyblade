# Gera o golpe autoral da katana: Blender (poses + IK) -> JSON -> Animation do Godot.
#   tools\build_katana_strike.ps1
. "$PSScriptRoot\godot.ps1"
$root = Split-Path -Parent $PSScriptRoot
$godot = Find-Godot -Console $true
$blender = 'C:\Program Files\Blender Foundation\Blender 4.5\blender.exe'
$json = Join-Path $env:TEMP 'cyblade_katana_kesa.json'
& $blender -b --python (Join-Path $root 'tools\blender\author_katana_strike.py') -- (Join-Path $root 'assets\characters\ual\UAL1_Standard.glb') $json | Select-String 'POLES|SAIDA|Error'
& $godot --headless --path $root -s res://tools/blender_pose_to_godot.gd -- $json res://assets/animations/katana/katana_kesa.res | Select-String 'pose->godot|ERROR'
