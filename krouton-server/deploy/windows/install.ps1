# Installs Krouton Server on Windows 10 or 11 (x64, x86 or ARM64).
# Run from an elevated PowerShell:  .\install.ps1 [-Binary .\krouton-server.exe]
param([string]$Binary = (Join-Path $PSScriptRoot '..\..\krouton-server.exe'))
$ErrorActionPreference = 'Stop'

$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  throw 'Run this from an elevated PowerShell (Run as administrator).'
}
if (-not (Test-Path $Binary)) { throw "Cannot find krouton-server.exe at $Binary" }

$InstallDir = Join-Path $env:ProgramFiles 'Krouton Server'
$HomeDir = Join-Path $env:ProgramData 'Krouton Server'
$Exe = Join-Path $InstallDir 'krouton-server.exe'
$Log = Join-Path $HomeDir 'krouton-server.log'
$Task = 'Krouton Server'

Write-Host '==> Installing' $Exe
New-Item -ItemType Directory -Force -Path $InstallDir, $HomeDir | Out-Null
Stop-ScheduledTask -TaskName $Task -ErrorAction SilentlyContinue
Copy-Item -Force $Binary $Exe
Unblock-File $Exe

# Keys and pairings: readable only by SYSTEM and Administrators.
icacls $HomeDir /inheritance:r /grant:r 'SYSTEM:(OI)(CI)F' 'Administrators:(OI)(CI)F' | Out-Null

& $Exe --home $HomeDir init
if ($LASTEXITCODE -ne 0) { throw 'krouton-server init failed' }

Write-Host '==> Allowing port 7420 on private networks'
Remove-NetFirewallRule -DisplayName $Task -ErrorAction SilentlyContinue
New-NetFirewallRule -DisplayName $Task -Direction Inbound -Program $Exe -Protocol TCP -LocalPort 7420 -Profile Private,Domain -Action Allow | Out-Null

Write-Host '==> Registering the startup task (runs as SYSTEM)'
$cmd = "`"$Exe`" --home `"$HomeDir`" run >> `"$Log`" 2>&1"
$action = New-ScheduledTaskAction -Execute 'cmd.exe' -Argument "/d /c `"$cmd`""
$trigger = New-ScheduledTaskTrigger -AtStartup
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 999 -RestartInterval (New-TimeSpan -Minutes 1)
Register-ScheduledTask -TaskName $Task -Action $action -Trigger $trigger -Settings $settings -User 'SYSTEM' -RunLevel Highest -Force | Out-Null
Start-ScheduledTask -TaskName $Task
Start-Sleep -Seconds 2
& $Exe --home $HomeDir check

Write-Host ''
Write-Host 'Krouton Server is running. Next, pair your Mac from this elevated PowerShell:'
Write-Host "    & '$Exe' --home '$HomeDir' pair"
Write-Host ''
Write-Host "Logs:    $Log"
Write-Host "Config:  $HomeDir\server.conf   (then: Stop-ScheduledTask '$Task'; Start-ScheduledTask '$Task')"
Write-Host 'Make sure this network is set to Private in Windows Settings, or the Mac cannot connect.'
