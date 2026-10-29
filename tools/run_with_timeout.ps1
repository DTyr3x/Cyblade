# Executa o Godot em janela com limite de tempo; no estouro encerra SÓ o processo iniciado aqui (por PID).
#   tools\run_with_timeout.ps1 -TimeoutSec 200 -GodotArgs '--rendering-driver','vulkan',...
param([int]$TimeoutSec = 200, [Parameter(ValueFromRemainingArguments = $true)][string[]]$GodotArgs)
. "$PSScriptRoot\godot.ps1"
$root = Split-Path -Parent $PSScriptRoot
$godot = Find-Godot -Console $true
$log = Join-Path $env:TEMP 'cyblade_timeout_run.log'
$p = Start-Process -FilePath $godot -ArgumentList (@('--path', $root) + $GodotArgs) -PassThru -RedirectStandardOutput $log -RedirectStandardError "$log.err" -WindowStyle Minimized
if (-not $p.WaitForExit($TimeoutSec * 1000)) { Stop-Process -Id $p.Id -Force; Write-Output "TIMEOUT: processo $($p.Id) encerrado após $TimeoutSec s" }
Get-Content $log | Select-String 'dbg|SCRIPT|ERROR|combat_sheet|playtest' | ForEach-Object { $_.Line }
