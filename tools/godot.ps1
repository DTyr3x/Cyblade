# Localiza o executável do Godot 4.7.x. Uso: . "$PSScriptRoot\godot.ps1"; Find-Godot -Console $false
# Ordem: variável CYBLADE_GODOT, PATH, Área de Trabalho, Downloads, C:\Godot, Program Files.

function Find-Godot {
    param([bool]$Console = $false)

    if ($env:CYBLADE_GODOT -and (Test-Path $env:CYBLADE_GODOT -PathType Leaf)) {
        $exe = $env:CYBLADE_GODOT
        if ($Console) {
            $sibling = $exe -replace '\.exe$', '_console.exe'
            if (Test-Path $sibling -PathType Leaf) { return $sibling }
        }
        return $exe
    }

    $pattern = if ($Console) { 'Godot_v4*_win64_console.exe' } else { 'Godot_v4*_win64.exe' }
    $roots = @(
        (Join-Path $env:USERPROFILE 'Desktop'),
        (Join-Path $env:USERPROFILE 'Downloads'),
        'C:\Godot',
        (Join-Path $env:ProgramFiles 'Godot')
    )
    foreach ($r in $roots) {
        if (-not (Test-Path $r)) { continue }
        $hit = Get-ChildItem $r -Recurse -Depth 2 -File -Filter $pattern -ErrorAction SilentlyContinue |
            Sort-Object Name -Descending | Select-Object -First 1
        if ($hit) { return $hit.FullName }
    }

    $onPath = Get-Command ($(if ($Console) { 'godot_console' } else { 'godot' })) -ErrorAction SilentlyContinue
    if ($onPath) { return $onPath.Source }

    Write-Error "Godot 4.7 não encontrado. Instale em https://godotengine.org/download/windows/ ou defina CYBLADE_GODOT com o caminho do .exe."
    exit 1
}
