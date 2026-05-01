#Requires -RunAsAdministrator
# baseline.ps1 - run only on your own fresh/clean VM, not on the challenge VM.
# Creates whitelist.json with a baseline of common Windows persistence locations.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$outputPath = Join-Path $scriptDir 'whitelist.json'

$wl = [ordered]@{}
$step = 0
$totalSteps = 29

function Write-Step {
    param([string]$Text)
    $script:step++
    Write-Host ("[*] {0}/{1} {2}" -f $script:step, $script:totalSteps, $Text) -ForegroundColor Cyan
}
function Write-OK   { param([string]$Text) Write-Host "    [OK] $Text" -ForegroundColor Green }
function Write-Warn { param([string]$Text) Write-Host "    [WARN] $Text" -ForegroundColor Yellow }

function ConvertTo-BaselineValue {
    param($Value)
    if ($null -eq $Value) { return $null }
    if ($Value -is [byte[]]) {
        return (($Value | ForEach-Object { $_.ToString('X2') }) -join '')
    }
    if ($Value -is [array]) {
        return @($Value | ForEach-Object { ConvertTo-BaselineValue $_ })
    }
    return [string]$Value
}

function Get-ObjectProperty {
    param($InputObject, [string]$Name)
    if ($null -eq $InputObject) { return '' }
    $prop = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $prop) { return '' }
    return ConvertTo-BaselineValue $prop.Value
}

function Get-RegValues {
    param([string]$Path)
    $out = [ordered]@{}
    try {
        if (Test-Path $Path) {
            $props = Get-ItemProperty -Path $Path -ErrorAction Stop
            $props.PSObject.Properties |
                Where-Object { $_.Name -notmatch '^PS(Path|ParentPath|ChildName|Drive|Provider)$' } |
                Sort-Object Name |
                ForEach-Object { $out[$_.Name] = ConvertTo-BaselineValue $_.Value }
        }
    } catch { Write-Warn "Get-RegValues '$Path': $_" }
    return $out
}

function Get-RegSubKeyValues {
    param([string[]]$Paths)
    $out = [ordered]@{}
    foreach ($path in $Paths) {
        try {
            if (Test-Path $path) {
                Get-ChildItem -Path $path -ErrorAction SilentlyContinue |
                    Sort-Object PSChildName |
                    ForEach-Object {
                        $out["$path\$($_.PSChildName)"] = Get-RegValues $_.PSPath
                    }
            }
        } catch { Write-Warn "Get-RegSubKeyValues '$path': $_" }
    }
    return $out
}

function Get-FileBaseline {
    param([string[]]$Paths, [switch]$Recurse, [string]$Filter = '*')
    $items = @()
    foreach ($path in $Paths) {
        try {
            if (Test-Path $path) {
                $params = @{
                    LiteralPath = $path
                    File = $true
                    Filter = $Filter
                    ErrorAction = 'SilentlyContinue'
                }
                if ($Recurse) { $params['Recurse'] = $true }
                $items += @(Get-ChildItem @params | Sort-Object FullName | ForEach-Object {
                    $hash = ''
                    try { $hash = (Get-FileHash -LiteralPath $_.FullName -Algorithm SHA256 -ErrorAction Stop).Hash } catch {}
                    [ordered]@{
                        Name = $_.Name
                        FullName = $_.FullName
                        Length = $_.Length
                        LastWriteTimeUtc = $_.LastWriteTimeUtc.ToString('o')
                        SHA256 = $hash
                    }
                })
            }
        } catch { Write-Warn "Get-FileBaseline '$path': $_" }
    }
    return @($items)
}

function Get-ShortcutBaseline {
    param([string[]]$Paths)
    $items = @()
    $shell = $null
    try { $shell = New-Object -ComObject WScript.Shell } catch { Write-Warn "WScript.Shell unavailable: $_" }

    foreach ($path in $Paths) {
        try {
            if (Test-Path $path) {
                $items += @(Get-ChildItem -LiteralPath $path -Filter '*.lnk' -File -Recurse -ErrorAction SilentlyContinue |
                    Sort-Object FullName |
                    ForEach-Object {
                        $targetPath = ''
                        $arguments = ''
                        $workingDirectory = ''
                        $iconLocation = ''
                        $windowStyle = ''
                        if ($null -ne $shell) {
                            try {
                                $lnk = $shell.CreateShortcut($_.FullName)
                                $targetPath = $lnk.TargetPath
                                $arguments = $lnk.Arguments
                                $workingDirectory = $lnk.WorkingDirectory
                                $iconLocation = $lnk.IconLocation
                                $windowStyle = [string]$lnk.WindowStyle
                            } catch { Write-Warn "Shortcut parse '$($_.FullName)': $_" }
                        }
                        [ordered]@{
                            Name = $_.Name
                            FullName = $_.FullName
                            TargetPath = $targetPath
                            Arguments = $arguments
                            WorkingDirectory = $workingDirectory
                            IconLocation = $iconLocation
                            WindowStyle = $windowStyle
                            LastWriteTimeUtc = $_.LastWriteTimeUtc.ToString('o')
                        }
                    })
            }
        } catch { Write-Warn "Get-ShortcutBaseline '$path': $_" }
    }
    return @($items)
}

function Get-ScheduledTaskBaseline {
    $tasks = @()
    try {
        $tasks = @(Get-ScheduledTask -ErrorAction SilentlyContinue |
            Sort-Object TaskPath, TaskName |
            ForEach-Object {
                [ordered]@{
                    TaskPath = $_.TaskPath
                    TaskName = $_.TaskName
                    State = [string]$_.State
                    Author = $_.Author
                    Description = $_.Description
                    URI = $_.URI
                    Hidden = if ($null -ne $_.Settings) { [bool]$_.Settings.Hidden } else { $false }
                    Actions = @($_.Actions | ForEach-Object {
                        [ordered]@{
                            Type = $_.CimClass.CimClassName
                            Execute = Get-ObjectProperty $_ 'Execute'
                            Arguments = Get-ObjectProperty $_ 'Arguments'
                            WorkingDirectory = Get-ObjectProperty $_ 'WorkingDirectory'
                            ClassId = Get-ObjectProperty $_ 'ClassId'
                            Data = Get-ObjectProperty $_ 'Data'
                        }
                    })
                    Triggers = @($_.Triggers | ForEach-Object {
                        [ordered]@{
                            Type = $_.CimClass.CimClassName
                            Enabled = Get-ObjectProperty $_ 'Enabled'
                            StartBoundary = Get-ObjectProperty $_ 'StartBoundary'
                            EndBoundary = Get-ObjectProperty $_ 'EndBoundary'
                            UserId = Get-ObjectProperty $_ 'UserId'
                            Subscription = Get-ObjectProperty $_ 'Subscription'
                            Delay = Get-ObjectProperty $_ 'Delay'
                            Repetition = Get-ObjectProperty $_ 'Repetition'
                        }
                    })
                }
            })
    } catch { Write-Warn "Get-ScheduledTaskBaseline: $_" }
    return @($tasks)
}

function Get-ServiceBaseline {
    $services = @()
    try {
        $services = @(Get-WmiObject Win32_Service -ErrorAction Stop |
            Where-Object { $_.StartMode -in @('Auto', 'Manual') } |
            Sort-Object Name |
            ForEach-Object {
                [ordered]@{
                    Name = $_.Name
                    DisplayName = $_.DisplayName
                    StartMode = $_.StartMode
                    State = $_.State
                    PathName = $_.PathName
                    StartName = $_.StartName
                }
            })
    } catch { Write-Warn "Get-ServiceBaseline: $_" }
    return @($services)
}

$startupUser = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
$startupPublic = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup'
$desktopPaths = @(
    [Environment]::GetFolderPath('Desktop'),
    'C:\Users\Public\Desktop'
) | Where-Object { $_ }
$startMenuPaths = @(
    Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu',
    'C:\ProgramData\Microsoft\Windows\Start Menu'
)
$officeVersions = @('12.0', '14.0', '15.0', '16.0')
$officeApps = @('Word', 'Excel', 'PowerPoint', 'Outlook')

Write-Step "Run keys HKLM"
$wl['RunHKLM'] = Get-RegValues 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
Write-OK "$($wl['RunHKLM'].Count) entries"

Write-Step "Run keys HKCU"
$wl['RunHKCU'] = Get-RegValues 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
Write-OK "$($wl['RunHKCU'].Count) entries"

Write-Step "RunOnce keys HKLM"
$wl['RunOnceHKLM'] = Get-RegValues 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
Write-OK "$($wl['RunOnceHKLM'].Count) entries"

Write-Step "RunOnce keys HKCU"
$wl['RunOnceHKCU'] = Get-RegValues 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
Write-OK "$($wl['RunOnceHKCU'].Count) entries"

Write-Step "WOW6432Node Run/RunOnce keys"
$wl['RunWow6432NodeHKLM'] = Get-RegValues 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
$wl['RunOnceWow6432NodeHKLM'] = Get-RegValues 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce'
$wl['RunWow6432NodeHKCU'] = Get-RegValues 'HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
$wl['RunOnceWow6432NodeHKCU'] = Get-RegValues 'HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce'
Write-OK "HKLM/HKCU 32-bit view captured"

Write-Step "Scheduled Tasks"
$wl['ScheduledTasks'] = Get-ScheduledTaskBaseline
Write-OK "$($wl['ScheduledTasks'].Count) tasks"

Write-Step "Services (Automatic/Manual)"
$wl['Services'] = Get-ServiceBaseline
Write-OK "$($wl['Services'].Count) services"

Write-Step "Startup folder user"
$wl['StartupUser'] = Get-FileBaseline @($startupUser)
Write-OK "$($wl['StartupUser'].Count) files"

Write-Step "Startup folder public"
$wl['StartupPublic'] = Get-FileBaseline @($startupPublic)
Write-OK "$($wl['StartupPublic'].Count) files"

Write-Step "WMI Subscriptions"
try {
    $filters = @(Get-WmiObject -Namespace root\subscription -Class __EventFilter -ErrorAction SilentlyContinue |
        Sort-Object Name | Select-Object Name, Query, QueryLanguage, EventNamespace)
    $consumers = @(Get-WmiObject -Namespace root\subscription -Class __EventConsumer -ErrorAction SilentlyContinue |
        Sort-Object Name | Select-Object Name, CreatorSID, CommandLineTemplate, ExecutablePath, ScriptingEngine, ScriptText)
    $bindings = @(Get-WmiObject -Namespace root\subscription -Class __FilterToConsumerBinding -ErrorAction SilentlyContinue |
        Sort-Object Filter, Consumer | ForEach-Object { "$($_.Filter) -> $($_.Consumer)" })
    $wl['WMIFilters'] = $filters
    $wl['WMIConsumers'] = $consumers
    $wl['WMIBindings'] = $bindings
    Write-OK "filters: $($filters.Count) consumers: $($consumers.Count) bindings: $($bindings.Count)"
} catch {
    Write-Warn $_
    $wl['WMIFilters'] = @(); $wl['WMIConsumers'] = @(); $wl['WMIBindings'] = @()
}

Write-Step "AppCertDlls"
$wl['AppCertDlls'] = Get-RegValues 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCertDlls'
Write-OK "$($wl['AppCertDlls'].Count) entries"

Write-Step "AppInit_DLLs"
try {
    $v = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows' -Name AppInit_DLLs -ErrorAction SilentlyContinue).AppInit_DLLs
    $wl['AppInitDLLs'] = if ($null -eq $v) { '' } else { $v }
    Write-OK "captured"
} catch { Write-Warn $_; $wl['AppInitDLLs'] = '' }

Write-Step "AppInit_DLLs WOW64"
try {
    $v = (Get-ItemProperty 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\Windows' -Name AppInit_DLLs -ErrorAction SilentlyContinue).AppInit_DLLs
    $wl['AppInitDLLsWow64'] = if ($null -eq $v) { '' } else { $v }
    Write-OK "captured"
} catch { Write-Warn $_; $wl['AppInitDLLsWow64'] = '' }

Write-Step "LSA Security Packages"
try {
    $v = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'Security Packages' -ErrorAction SilentlyContinue).'Security Packages'
    $wl['LSASecurityPackages'] = @(if ($null -eq $v) { @() } else { $v })
    Write-OK "$($wl['LSASecurityPackages'].Count) packages"
} catch { Write-Warn $_; $wl['LSASecurityPackages'] = @() }

Write-Step "LSA OSConfig Security Packages"
try {
    $v = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\OSConfig' -Name 'Security Packages' -ErrorAction SilentlyContinue).'Security Packages'
    $wl['LSAOSConfigSecurityPackages'] = @(if ($null -eq $v) { @() } else { $v })
    Write-OK "$($wl['LSAOSConfigSecurityPackages'].Count) packages"
} catch { Write-Warn $_; $wl['LSAOSConfigSecurityPackages'] = @() }

Write-Step "NetSh Helper DLLs"
$wl['NetShHelperDLLs'] = Get-RegValues 'HKLM:\SOFTWARE\Microsoft\NetSh'
Write-OK "$($wl['NetShHelperDLLs'].Count) entries"

Write-Step "Print Monitors"
try {
    $wl['PrintMonitors'] = Get-RegSubKeyValues @('HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors')
    Write-OK "$($wl['PrintMonitors'].Count) monitors"
} catch { Write-Warn $_; $wl['PrintMonitors'] = [ordered]@{} }

Write-Step "BootExecute"
try {
    $v = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name BootExecute -ErrorAction Stop).BootExecute
    $wl['BootExecute'] = @($v)
    Write-OK "$($wl['BootExecute'] -join ' | ')"
} catch { Write-Warn $_; $wl['BootExecute'] = @('autocheck autochk *') }

Write-Step "IFEO Debugger values"
try {
    $ifeo = [ordered]@{}
    $ifeoPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
    Get-ChildItem $ifeoPath -ErrorAction SilentlyContinue | Sort-Object PSChildName | ForEach-Object {
        try {
            $dbg = (Get-ItemProperty $_.PSPath -Name Debugger -ErrorAction SilentlyContinue).Debugger
            if ($null -ne $dbg) { $ifeo[$_.PSChildName] = $dbg }
        } catch {}
    }
    $wl['IFEO'] = $ifeo
    Write-OK "$($ifeo.Count) entries with Debugger value"
} catch { Write-Warn $_; $wl['IFEO'] = [ordered]@{} }

Write-Step "Winlogon"
try {
    $key = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction Stop
    $wl['WinlogonUserinit'] = if ($null -ne $key.Userinit) { $key.Userinit } else { '' }
    $wl['WinlogonShell'] = if ($null -ne $key.Shell) { $key.Shell } else { '' }
    Write-OK "captured"
} catch { Write-Warn $_; $wl['WinlogonUserinit'] = ''; $wl['WinlogonShell'] = '' }

Write-Step "Time Providers"
try {
    $wl['TimeProviders'] = Get-RegSubKeyValues @('HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders')
    Write-OK "$($wl['TimeProviders'].Count) providers"
} catch { Write-Warn $_; $wl['TimeProviders'] = [ordered]@{} }

Write-Step "Microsoft Edge forced extension policy"
$wl['EdgeExtensionInstallForcelistHKLM'] = Get-RegValues 'HKLM:\Software\Policies\Microsoft\Edge\ExtensionInstallForcelist'
$wl['EdgeExtensionInstallForcelistHKCU'] = Get-RegValues 'HKCU:\Software\Policies\Microsoft\Edge\ExtensionInstallForcelist'
$wl['EdgeExtensionSettingsHKLM'] = Get-RegValues 'HKLM:\Software\Policies\Microsoft\Edge\ExtensionSettings'
$wl['EdgeExtensionSettingsHKCU'] = Get-RegValues 'HKCU:\Software\Policies\Microsoft\Edge\ExtensionSettings'
Write-OK "Edge extension policy captured"

Write-Step "Office Startup folders"
$officeStartupPaths = @(
    (Join-Path $env:APPDATA 'Microsoft\Word\STARTUP'),
    (Join-Path $env:APPDATA 'Microsoft\Excel\XLSTART'),
    (Join-Path $env:ProgramFiles 'Microsoft Office\root\Office16\STARTUP'),
    (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Office\root\Office16\STARTUP')
) | Where-Object { $_ }
$wl['OfficeStartupFiles'] = Get-FileBaseline $officeStartupPaths
Write-OK "$($wl['OfficeStartupFiles'].Count) files"

Write-Step "Office add-in registry keys"
$officeAddinPaths = @()
foreach ($root in @('HKLM:\Software', 'HKCU:\Software', 'HKLM:\Software\WOW6432Node', 'HKCU:\Software\WOW6432Node')) {
    foreach ($version in $officeVersions) {
        foreach ($app in $officeApps) {
            $officeAddinPaths += "$root\Microsoft\Office\$version\$app\Addins"
            $officeAddinPaths += "$root\Microsoft\Office\$app\Addins"
        }
    }
}
$wl['OfficeAddins'] = Get-RegSubKeyValues $officeAddinPaths
Write-OK "$($wl['OfficeAddins'].Count) add-in keys"

Write-Step "COM add-ins"
$wl['COMAddins'] = Get-RegSubKeyValues @(
    'HKLM:\Software\Microsoft\Office\Addins',
    'HKCU:\Software\Microsoft\Office\Addins',
    'HKLM:\Software\WOW6432Node\Microsoft\Office\Addins',
    'HKCU:\Software\WOW6432Node\Microsoft\Office\Addins'
)
Write-OK "$($wl['COMAddins'].Count) COM add-in keys"

Write-Step "PowerShell profiles"
$psProfilePaths = @(
    "$PSHOME\profile.ps1",
    "$PSHOME\Microsoft.PowerShell_profile.ps1",
    (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\profile.ps1'),
    (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),
    (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\profile.ps1'),
    (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Microsoft.PowerShell_profile.ps1'),
    "$env:ProgramFiles\PowerShell\7\profile.ps1",
    "${env:ProgramFiles(x86)}\PowerShell\7\profile.ps1"
) | Where-Object { $_ } | Sort-Object -Unique
$wl['PowerShellProfiles'] = Get-FileBaseline $psProfilePaths
Write-OK "$($wl['PowerShellProfiles'].Count) profile files present"

Write-Step "Shortcut .lnk targets"
$wl['Shortcuts'] = Get-ShortcutBaseline (@($startupUser, $startupPublic) + $desktopPaths + $startMenuPaths)
Write-OK "$($wl['Shortcuts'].Count) shortcuts"

Write-Step "Active Setup Installed Components"
$wl['ActiveSetup'] = Get-RegSubKeyValues @(
    'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components',
    'HKCU:\SOFTWARE\Microsoft\Active Setup\Installed Components',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Active Setup\Installed Components',
    'HKCU:\SOFTWARE\WOW6432Node\Microsoft\Active Setup\Installed Components'
)
Write-OK "$($wl['ActiveSetup'].Count) components"

Write-Host ""
Write-Step "Export whitelist.json"
try {
    $wl | ConvertTo-Json -Depth 20 | Set-Content -Path $outputPath -Encoding UTF8
    Write-Host "[DONE] whitelist.json saved: $outputPath" -ForegroundColor Green
} catch {
    Write-Host "[ERROR] Could not write whitelist.json: $_" -ForegroundColor Red
    exit 1
}
