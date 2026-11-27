# Removes the task, firewall rule and program. Keeps keys and pairings unless -Purge.
param([switch]$Purge)
$ErrorActionPreference = 'Continue'
$Task = 'Krouton Server'
Stop-ScheduledTask -TaskName $Task
Unregister-ScheduledTask -TaskName $Task -Confirm:$false
Get-Process krouton-server -ErrorAction SilentlyContinue | Stop-Process -Force
Remove-NetFirewallRule -DisplayName $Task
Remove-Item -Recurse -Force (Join-Path $env:ProgramFiles 'Krouton Server')
if ($Purge) { Remove-Item -Recurse -Force (Join-Path $env:ProgramData 'Krouton Server') }
Write-Host 'Krouton Server removed.'
