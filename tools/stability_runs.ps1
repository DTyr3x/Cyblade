# Repete o playtest scriptado em janela N vezes com limite de tempo, para caçar travamentos.
# Cada execução grava o log; no estouro do limite registra o último trecho alcançado e se o
# processo estava parado (CPU ~0) ou girando, e encerra SÓ o processo que este script iniciou.
param([int]$Runs = 5, [int]$TimeoutSec = 150, [string]$Out = 'docs/h1-1/estabilidade')
. "$PSScriptRoot\godot.ps1"
$root = Split-Path -Parent $PSScriptRoot
$godot = Find-Godot -Console $true
New-Item -ItemType Directory -Force (Join-Path $root $Out) | Out-Null
$summary = @()
for ($i = 1; $i -le $Runs; $i++) {
    $log = Join-Path $root "$Out\run$i.log"
    $err = Join-Path $root "$Out\run$i.err.log"
    $argList = @('--path', $root, '--rendering-driver', 'vulkan', '--windowed', '--resolution', '1920x1080', '--disable-vsync', '--', '--playtest', "--out=$Out\run$i")
    $p = Start-Process -FilePath $godot -ArgumentList $argList -PassThru -RedirectStandardOutput $log -RedirectStandardError $err -WindowStyle Minimized
    $ok = $p.WaitForExit($TimeoutSec * 1000)
    $lastSeg = (Select-String -Path $log -Pattern "trecho '(.*)' conclu" | Select-Object -Last 1)
    $seg = if ($lastSeg) { $lastSeg.Matches[0].Groups[1].Value } else { '(nenhum)' }
    if ($ok) {
        $res = "ok (saída $($p.ExitCode))"
        $cpu = ''
    } else {
        $t0 = $p.TotalProcessorTime.TotalSeconds; Start-Sleep 3; $p.Refresh()
        $cpu = "CPU em 3 s: {0:N2} s" -f ($p.TotalProcessorTime.TotalSeconds - $t0)
        $res = 'TRAVOU'
        Stop-Process -Id $p.Id -Force
    }
    $line = "execução $i : $res | último trecho concluído: $seg | $cpu"
    Write-Output $line
    $summary += $line
}
$summary | Set-Content (Join-Path $root "$Out\resumo.txt") -Encoding utf8
