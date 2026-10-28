# Executa o protótipo do CYBLADE.
#   .\tools\run.ps1            joga
#   .\tools\run.ps1 -Editor    abre no editor do Godot
param([switch]$Editor)

. "$PSScriptRoot\godot.ps1"
$root = Split-Path -Parent $PSScriptRoot
$godot = Find-Godot -Console $false

# Primeira execução em um clone novo: gera o cache de classes e importa recursos.
if (-not (Test-Path (Join-Path $root '.godot'))) {
    Write-Host 'Primeira execução: importando o projeto...'
    $console = Find-Godot -Console $true
    & $console --headless --path $root --import | Out-Null
}

if ($Editor) {
    & $godot --path $root --editor
} else {
    & $godot --path $root
}
