#Requires -RunAsAdministrator
# Lab-only scheduled task persistence generator for testing defender.ps1.
# Default: installs several harmless tasks that write C:\Users\Public\Documents\pwned.txt after reboot/logon.
# Cleanup: powershell.exe -ExecutionPolicy Bypass -File .\scheduled_tasks.ps1 -Cleanup -RemoveProof

param(
    [switch]$Cleanup,
    [switch]$RemoveProof
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$taskPath = '\PersistenceShowdownLab\'
$workDir = Join-Path $env:ProgramData 'PersistenceShowdownLab\ScheduledTasks'
$payloadPath = 'C:\Users\Public\Documents\pwned.txt'
$payloadText = 'Pwn3d'
$psExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$cmdExe = Join-Path $env:WINDIR 'System32\cmd.exe'
$wscriptExe = Join-Path $env:WINDIR 'System32\wscript.exe'

function Write-Step { param([string]$Text) Write-Host "[*] $Text" -ForegroundColor Cyan }
function Write-OK { param([string]$Text) Write-Host "    [OK] $Text" -ForegroundColor Green }
function Write-Warn { param([string]$Text) Write-Host "    [WARN] $Text" -ForegroundColor Yellow }

function Remove-LabTasks {
    Write-Step "Removing Persistence Showdown scheduled tasks"
    try {
        Get-ScheduledTask -TaskPath $taskPath -ErrorAction SilentlyContinue |
            Unregister-ScheduledTask -Confirm:$false -ErrorAction SilentlyContinue
        Write-OK "Removed tasks under $taskPath"
    } catch {
        Write-Warn "Task cleanup via ScheduledTasks module failed: $_"
    }

    foreach ($name in @(
        'PSUnit-Startup-ProfileCache',
        'PSUnit-Logon-CloudSync',
        'PSUnit-Startup-EventBroker',
        'PSUnit-Startup-WinUpdateCache',
        'PSUnit-Startup-UserInitBridge'
    )) {
        & schtasks.exe /Delete /TN "$taskPath$name" /F 2>$null | Out-Null
    }
}

function Remove-LabFiles {
    Write-Step "Removing helper files"
    if (Test-Path -LiteralPath $workDir) {
        Remove-Item -LiteralPath $workDir -Recurse -Force -ErrorAction SilentlyContinue
        Write-OK "Removed $workDir"
    }
    if ($RemoveProof -and (Test-Path -LiteralPath $payloadPath)) {
        Remove-Item -LiteralPath $payloadPath -Force -ErrorAction SilentlyContinue
        Write-OK "Removed $payloadPath"
    }
}

function New-PayloadScript {
    param([string]$Path, [int]$DelaySeconds = 0)

    $content = @"
`$ErrorActionPreference = 'SilentlyContinue'
if ($DelaySeconds -gt 0) { Start-Sleep -Seconds $DelaySeconds }
New-Item -ItemType Directory -Path 'C:\Users\Public\Documents' -Force | Out-Null
Set-Content -LiteralPath 'C:\Users\Public\Documents\pwned.txt' -Value 'Pwn3d' -NoNewline -Encoding ASCII
"@
    Set-Content -LiteralPath $Path -Value $content -Encoding ASCII
}

function New-PayloadVbs {
    param([string]$Path)

    $content = @'
On Error Resume Next
Set fso = CreateObject("Scripting.FileSystemObject")
If Not fso.FolderExists("C:\Users\Public\Documents") Then
    fso.CreateFolder("C:\Users\Public\Documents")
End If
Set f = fso.CreateTextFile("C:\Users\Public\Documents\pwned.txt", True)
f.Write "Pwn3d"
f.Close
'@
    Set-Content -LiteralPath $Path -Value $content -Encoding ASCII
}

function New-EncodedPayload {
    $command = "New-Item -ItemType Directory -Path 'C:\Users\Public\Documents' -Force | Out-Null; Set-Content -LiteralPath 'C:\Users\Public\Documents\pwned.txt' -Value 'Pwn3d' -NoNewline -Encoding ASCII"
    return [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
}

function Register-LabTask {
    param(
        [string]$Name,
        [string]$Description,
        $Action,
        $Trigger,
        [switch]$Hidden
    )

    $principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $settingsArgs = @{
        AllowStartIfOnBatteries = $true
        DontStopIfGoingOnBatteries = $true
        StartWhenAvailable = $true
        MultipleInstances = 'IgnoreNew'
        ExecutionTimeLimit = (New-TimeSpan -Minutes 5)
    }
    if ($Hidden) { $settingsArgs['Hidden'] = $true }
    $settings = New-ScheduledTaskSettingsSet @settingsArgs

    Register-ScheduledTask -TaskName $Name -TaskPath $taskPath -Action $Action -Trigger $Trigger -Principal $principal -Settings $settings -Description $Description -Force | Out-Null
    Write-OK "Registered $taskPath$Name"
}

if ($Cleanup) {
    Remove-LabTasks
    Remove-LabFiles
    Write-Host "[DONE] scheduled task unit-test cleanup complete" -ForegroundColor Green
    exit 0
}

Write-Step "Preparing scheduled task helper files"
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
$profileCacheScript = Join-Path $workDir 'profile-cache.ps1'
$delayedScript = Join-Path $workDir 'userinit-bridge.ps1'
$vbsScript = Join-Path $workDir 'event-cache.vbs'
New-PayloadScript -Path $profileCacheScript
New-PayloadScript -Path $delayedScript -DelaySeconds 20
New-PayloadVbs -Path $vbsScript
Write-OK "Helper files written to $workDir"

Remove-LabTasks

Write-Step "Installing scheduled task persistence variants"
$encoded = New-EncodedPayload

Register-LabTask `
    -Name 'PSUnit-Startup-ProfileCache' `
    -Description 'Lab test: hidden SYSTEM startup task that launches a ProgramData PowerShell helper.' `
    -Action (New-ScheduledTaskAction -Execute $psExe -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$profileCacheScript`"" -WorkingDirectory $workDir) `
    -Trigger (New-ScheduledTaskTrigger -AtStartup) `
    -Hidden

Register-LabTask `
    -Name 'PSUnit-Logon-CloudSync' `
    -Description 'Lab test: logon task using cmd.exe to write the project proof file.' `
    -Action (New-ScheduledTaskAction -Execute $cmdExe -Argument "/c echo $payloadText>$payloadPath") `
    -Trigger (New-ScheduledTaskTrigger -AtLogOn)

Register-LabTask `
    -Name 'PSUnit-Startup-EventBroker' `
    -Description 'Lab test: startup task using Windows Script Host and a VBS helper.' `
    -Action (New-ScheduledTaskAction -Execute $wscriptExe -Argument "//B `"$vbsScript`"" -WorkingDirectory $workDir) `
    -Trigger (New-ScheduledTaskTrigger -AtStartup)

Register-LabTask `
    -Name 'PSUnit-Startup-WinUpdateCache' `
    -Description 'Lab test: hidden startup task using an encoded PowerShell command.' `
    -Action (New-ScheduledTaskAction -Execute $psExe -Argument "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded") `
    -Trigger (New-ScheduledTaskTrigger -AtStartup) `
    -Hidden

Register-LabTask `
    -Name 'PSUnit-Startup-UserInitBridge' `
    -Description 'Lab test: delayed startup task using a helper script.' `
    -Action (New-ScheduledTaskAction -Execute $psExe -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$delayedScript`"" -WorkingDirectory $workDir) `
    -Trigger (New-ScheduledTaskTrigger -AtStartup)

Write-Host ""
Write-Host "[DONE] Installed scheduled task unit-test persistences." -ForegroundColor Green
Write-Host "Reboot or log on again to let any remaining tasks create $payloadPath." -ForegroundColor Yellow
