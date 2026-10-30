# Gera os golpes autorais da katana: Blender (poses + IK) -> JSON -> Animation do Godot.
#   tools\build_katana_strike.ps1             (todos)
#   tools\build_katana_strike.ps1 -Clip kesa  (só um: kesa | kiriage)
param([string]$Clip = 'all')
. "$PSScriptRoot\godot.ps1"
$root = Split-Path -Parent $PSScriptRoot
$godot = Find-Godot -Console $true
$blender = 'C:\Program Files\Blender Foundation\Blender 4.5\blender.exe'
$names = @{ kesa = 'katana_kesa'; kiriage = 'katana_kiriage'; tsuki = 'katana_tsuki'; guarda = 'katana_guarda'; deflexao = 'katana_deflexao'; contra = 'katana_contra' }
foreach ($c in @('kesa', 'kiriage', 'tsuki', 'guarda', 'deflexao', 'contra')) {
    if ($Clip -ne 'all' -and $Clip -ne $c) { continue }
    $json = Join-Path $env:TEMP "cyblade_$($names[$c]).json"
    & $blender -b --python (Join-Path $root 'tools\blender\author_katana_strike.py') -- (Join-Path $root 'assets\characters\ual\UAL1_Standard.glb') $json $c | Select-String 'POLES|SAIDA|Error'
    & $godot --headless --path $root -s res://tools/blender_pose_to_godot.gd -- $json "res://assets/animations/katana/$($names[$c]).res" | Select-String 'pose->godot|ERROR'
}
