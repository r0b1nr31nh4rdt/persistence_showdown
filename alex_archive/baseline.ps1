#Requires -RunAsAdministrator
# baseline.ps1 - run only on your own fresh/clean VM, not on the challenge VM.
# Creates whitelist.json as a strict name-only whitelist for defender.ps1.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$outputPath = Join-Path $scriptDir 'whitelist.json'

$wl = [ordered]@{}
$step = 0
$totalSteps = 29

function Write-Step {
    param([string]$Text)
    $script:step++
    Write-Host ("[*] {0}/{1} {2}" -f $script:step, $script:totalSteps, $Text) -ForegroundColor Cyan
}
function Write-OK { param([string]$Text) Write-Host "    [OK] $Text" -ForegroundColor Green }
function Write-Warn { param([string]$Text) Write-Host "    [WARN] $Text" -ForegroundColor Yellow }

function Get-PropertyValue {
    param($InputObject, [string]$Name, $Default = $null)
    if ($null -eq $InputObject) { return $Default }
    $prop = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $Default }
    return $prop.Value
}

function Add-WhitelistSection {
    param([string]$Name, $Items)
    $wl[$Name] = @($Items | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | ForEach-Object { [string]$_ } | Sort-Object -Unique)
    Write-OK "$($wl[$Name].Count) names"
}

function Join-PathIfRoot {
    param([string]$Root, [string]$Child)
    if ([string]::IsNullOrWhiteSpace($Root)) { return $null }
    return Join-Path $Root $Child
}

function Get-RegValueNames {
    param([string]$Path)
    try {
        if (-not (Test-Path $Path)) { return @() }
        $props = Get-ItemProperty -Path $Path -ErrorAction Stop
        return @($props.PSObject.Properties |
            Where-Object { $_.Name -notmatch '^PS(Path|ParentPath|ChildName|Drive|Provider)$' } |
            Select-Object -ExpandProperty Name)
    } catch {
        Write-Warn "Get-RegValueNames '$Path': $_"
        return @()
    }
}

function Get-RegSubKeyNames {
    param([string[]]$Paths)
    $names = @()
    foreach ($path in $Paths) {
        try {
            if (Test-Path $path) {
                $names += @(Get-ChildItem -Path $path -ErrorAction SilentlyContinue | Select-Object -ExpandProperty PSChildName)
            }
        } catch { Write-Warn "Get-RegSubKeyNames '$path': $_" }
    }
    return @($names)
}

function Get-FileNames {
    param([string[]]$Paths, [string]$Filter = '*', [switch]$Recurse)
    $names = @()
    foreach ($path in $Paths) {
        try {
            if (Test-Path -LiteralPath $path) {
                $params = @{
                    LiteralPath = $path
                    File = $true
                    Filter = $Filter
                    ErrorAction = 'SilentlyContinue'
                }
                if ($Recurse) { $params['Recurse'] = $true }
                $names += @(Get-ChildItem @params | Select-Object -ExpandProperty Name)
            }
        } catch { Write-Warn "Get-FileNames '$path': $_" }
    }
    return @($names)
}

function Get-ProfilePathsPresent {
    param([string[]]$Paths)
    return @($Paths | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) })
}

function Get-ScheduledTaskNames {
    try {
        return @(Get-ScheduledTask -ErrorAction SilentlyContinue |
            ForEach-Object {
                $taskPath = [string]$_.TaskPath
                if (-not $taskPath.EndsWith('\')) { $taskPath += '\' }
                "$taskPath$($_.TaskName)"
            })
    } catch {
        Write-Warn "Get-ScheduledTaskNames: $_"
        return @()
    }
}

function Get-ServiceNames {
    try {
        return @(Get-WmiObject Win32_Service -ErrorAction Stop |
            Where-Object { $_.StartMode -in @('Auto', 'Manual') } |
            Select-Object -ExpandProperty Name)
    } catch {
        Write-Warn "Get-ServiceNames: $_"
        return @()
    }
}

function Get-RegValueMarker {
    param([string]$Path, [string]$ValueName)
    try {
        $key = Get-ItemProperty -Path $Path -Name $ValueName -ErrorAction SilentlyContinue
        if ($null -eq $key) { return @() }
        $prop = $key.PSObject.Properties[$ValueName]
        if ($null -eq $prop -or $null -eq $prop.Value) { return @() }
        if ([string]::IsNullOrWhiteSpace(([string]$prop.Value))) { return @() }
        return @($ValueName)
    } catch { return @() }
}

$startupUser = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
$startupPublic = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup'
$desktopPaths = @(
    [Environment]::GetFolderPath('Desktop'),
    'C:\Users\Public\Desktop'
) | Where-Object { $_ }
$startMenuPaths = @(
    (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu'),
    'C:\ProgramData\Microsoft\Windows\Start Menu'
) | Where-Object { $_ }
$officeStartupPaths = @(
    (Join-PathIfRoot $env:APPDATA 'Microsoft\Word\STARTUP'),
    (Join-PathIfRoot $env:APPDATA 'Microsoft\Excel\XLSTART'),
    (Join-PathIfRoot $env:ProgramFiles 'Microsoft Office\root\Office16\STARTUP'),
    (Join-PathIfRoot ${env:ProgramFiles(x86)} 'Microsoft Office\root\Office16\STARTUP')
) | Where-Object { $_ }
$powerShellProfilePaths = @(
    "$PSHOME\profile.ps1",
    "$PSHOME\Microsoft.PowerShell_profile.ps1",
    (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\profile.ps1'),
    (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),
    (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\profile.ps1'),
    (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Microsoft.PowerShell_profile.ps1'),
    (Join-PathIfRoot $env:ProgramFiles 'PowerShell\7\profile.ps1'),
    (Join-PathIfRoot ${env:ProgramFiles(x86)} 'PowerShell\7\profile.ps1')
) | Where-Object { $_ }
$officeVersions = @('12.0', '14.0', '15.0', '16.0')
$officeApps = @('Word', 'Excel', 'PowerPoint', 'Outlook')
$officeAddinPaths = @()
foreach ($root in @('HKLM:\Software', 'HKCU:\Software', 'HKLM:\Software\WOW6432Node', 'HKCU:\Software\WOW6432Node')) {
    foreach ($version in $officeVersions) {
        foreach ($app in $officeApps) {
            $officeAddinPaths += "$root\Microsoft\Office\$version\$app\Addins"
            $officeAddinPaths += "$root\Microsoft\Office\$app\Addins"
        }
    }
}

Write-Step "Run keys HKLM"
Add-WhitelistSection 'RunHKLM' (Get-RegValueNames 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run')

Write-Step "Run keys HKCU"
Add-WhitelistSection 'RunHKCU' (Get-RegValueNames 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run')

Write-Step "RunOnce keys HKLM"
Add-WhitelistSection 'RunOnceHKLM' (Get-RegValueNames 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce')

Write-Step "RunOnce keys HKCU"
Add-WhitelistSection 'RunOnceHKCU' (Get-RegValueNames 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce')

Write-Step "WOW6432Node Run/RunOnce keys"
Add-WhitelistSection 'RunWow6432NodeHKLM' (Get-RegValueNames 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run')
Add-WhitelistSection 'RunOnceWow6432NodeHKLM' (Get-RegValueNames 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce')
Add-WhitelistSection 'RunWow6432NodeHKCU' (Get-RegValueNames 'HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run')
Add-WhitelistSection 'RunOnceWow6432NodeHKCU' (Get-RegValueNames 'HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce')

Write-Step "Scheduled Tasks"
Add-WhitelistSection 'ScheduledTasks' (Get-ScheduledTaskNames)

Write-Step "Services (Automatic/Manual)"
Add-WhitelistSection 'Services' (Get-ServiceNames)

Write-Step "Startup folder user"
Add-WhitelistSection 'StartupUser' (Get-FileNames @($startupUser))

Write-Step "Startup folder public"
Add-WhitelistSection 'StartupPublic' (Get-FileNames @($startupPublic))

Write-Step "WMI Subscriptions"
try {
    Add-WhitelistSection 'WMIFilters' @(Get-WmiObject -Namespace root\subscription -Class __EventFilter -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
    Add-WhitelistSection 'WMIConsumers' @(Get-WmiObject -Namespace root\subscription -Class __EventConsumer -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
    Add-WhitelistSection 'WMIBindings' @(Get-WmiObject -Namespace root\subscription -Class __FilterToConsumerBinding -ErrorAction SilentlyContinue | ForEach-Object { "$($_.Filter) -> $($_.Consumer)" })
} catch {
    Write-Warn $_
    Add-WhitelistSection 'WMIFilters' @()
    Add-WhitelistSection 'WMIConsumers' @()
    Add-WhitelistSection 'WMIBindings' @()
}

Write-Step "AppCertDlls"
Add-WhitelistSection 'AppCertDlls' (Get-RegValueNames 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCertDlls')

Write-Step "AppInit_DLLs"
Add-WhitelistSection 'AppInitDLLs' (Get-RegValueMarker 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows' 'AppInit_DLLs')

Write-Step "AppInit_DLLs WOW64"
Add-WhitelistSection 'AppInitDLLsWow64' (Get-RegValueMarker 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\Windows' 'AppInit_DLLs')

Write-Step "LSA Security Packages"
try {
    $key = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'Security Packages' -ErrorAction SilentlyContinue
    $v = Get-PropertyValue $key 'Security Packages' @()
    Add-WhitelistSection 'LSASecurityPackages' @($v)
} catch { Write-Warn $_; Add-WhitelistSection 'LSASecurityPackages' @() }

Write-Step "LSA OSConfig Security Packages"
try {
    $key = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\OSConfig' -Name 'Security Packages' -ErrorAction SilentlyContinue
    $v = Get-PropertyValue $key 'Security Packages' @()
    Add-WhitelistSection 'LSAOSConfigSecurityPackages' @($v)
} catch { Write-Warn $_; Add-WhitelistSection 'LSAOSConfigSecurityPackages' @() }

Write-Step "NetSh Helper DLLs"
Add-WhitelistSection 'NetShHelperDLLs' (Get-RegValueNames 'HKLM:\SOFTWARE\Microsoft\NetSh')

Write-Step "Print Monitors"
Add-WhitelistSection 'PrintMonitors' (Get-RegSubKeyNames @('HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors'))

Write-Step "BootExecute"
try {
    $v = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name BootExecute -ErrorAction SilentlyContinue).BootExecute
    Add-WhitelistSection 'BootExecute' @($v)
} catch { Write-Warn $_; Add-WhitelistSection 'BootExecute' @() }

Write-Step "IFEO Debugger values"
try {
    $names = @(Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options' -ErrorAction SilentlyContinue |
        Where-Object { $null -ne (Get-ItemProperty $_.PSPath -Name Debugger -ErrorAction SilentlyContinue).Debugger } |
        Select-Object -ExpandProperty PSChildName)
    Add-WhitelistSection 'IFEO' $names
} catch { Write-Warn $_; Add-WhitelistSection 'IFEO' @() }

Write-Step "Winlogon"
try {
    $key = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction SilentlyContinue
    Add-WhitelistSection 'Winlogon' @(
        "Userinit=$(Get-PropertyValue $key 'Userinit' '')",
        "Shell=$(Get-PropertyValue $key 'Shell' '')"
    )
} catch { Write-Warn $_; Add-WhitelistSection 'Winlogon' @() }

Write-Step "Time Providers"
Add-WhitelistSection 'TimeProviders' (Get-RegSubKeyNames @('HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders'))

Write-Step "Microsoft Edge forced extension policy"
Add-WhitelistSection 'EdgeExtensionInstallForcelistHKLM' (Get-RegValueNames 'HKLM:\Software\Policies\Microsoft\Edge\ExtensionInstallForcelist')
Add-WhitelistSection 'EdgeExtensionInstallForcelistHKCU' (Get-RegValueNames 'HKCU:\Software\Policies\Microsoft\Edge\ExtensionInstallForcelist')
Add-WhitelistSection 'EdgeExtensionSettingsHKLM' (Get-RegValueNames 'HKLM:\Software\Policies\Microsoft\Edge\ExtensionSettings')
Add-WhitelistSection 'EdgeExtensionSettingsHKCU' (Get-RegValueNames 'HKCU:\Software\Policies\Microsoft\Edge\ExtensionSettings')

Write-Step "Office Startup folders"
Add-WhitelistSection 'OfficeStartupFiles' (Get-FileNames $officeStartupPaths)

Write-Step "Office add-in registry keys"
Add-WhitelistSection 'OfficeAddins' (Get-RegSubKeyNames $officeAddinPaths)

Write-Step "COM add-ins"
Add-WhitelistSection 'COMAddins' (Get-RegSubKeyNames @(
    'HKLM:\Software\Microsoft\Office\Addins',
    'HKCU:\Software\Microsoft\Office\Addins',
    'HKLM:\Software\WOW6432Node\Microsoft\Office\Addins',
    'HKCU:\Software\WOW6432Node\Microsoft\Office\Addins'
))

Write-Step "PowerShell profiles"
Add-WhitelistSection 'PowerShellProfiles' (Get-ProfilePathsPresent $powerShellProfilePaths)

Write-Step "Shortcut .lnk targets"
Add-WhitelistSection 'Shortcuts' (Get-FileNames (@($startupUser, $startupPublic) + $desktopPaths + $startMenuPaths) -Filter '*.lnk' -Recurse)

Write-Step "Active Setup Installed Components"
Add-WhitelistSection 'ActiveSetup' (Get-RegSubKeyNames @(
    'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components',
    'HKCU:\SOFTWARE\Microsoft\Active Setup\Installed Components',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Active Setup\Installed Components',
    'HKCU:\SOFTWARE\WOW6432Node\Microsoft\Active Setup\Installed Components'
))

Write-Host ""
Write-Step "Export whitelist.json"
try {
    $wl | ConvertTo-Json -Depth 5 | Set-Content -Path $outputPath -Encoding UTF8
    Write-Host "[DONE] whitelist.json saved: $outputPath" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Could not write whitelist.json: $_" -ForegroundColor Red
    exit 1
}
