#Requires -RunAsAdministrator
# baseline.ps1 – NUR auf eigener frischer VM ausführen, NICHT auf der Challenge-VM!
# Liest alle 20 Persistence-Punkte aus und exportiert whitelist.json.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$scriptDir  = Split-Path -Parent $MyInvocation.MyCommand.Definition
$outputPath = Join-Path $scriptDir 'whitelist.json'

$wl = [ordered]@{}

function Write-Step { param([string]$t) Write-Host "[*] $t" -ForegroundColor Cyan }
function Write-OK   { param([string]$t) Write-Host "    [OK] $t" -ForegroundColor Green }
function Write-Warn { param([string]$t) Write-Host "    [WARN] $t" -ForegroundColor Yellow }

function Get-RegValues {
    param([string]$Path)
    $out = [ordered]@{}
    try {
        if (Test-Path $Path) {
            $props = Get-ItemProperty -Path $Path -ErrorAction Stop
            $props.PSObject.Properties |
                Where-Object { $_.Name -notmatch '^PS(Path|ParentPath|ChildName|Drive|Provider)$' } |
                ForEach-Object { $out[$_.Name] = $_.Value }
        }
    } catch { Write-Warn "Get-RegValues '$Path': $_" }
    return $out
}

# ── 1: Run HKLM ──────────────────────────────────────────────────────────────
Write-Step "1/20  Run Keys HKLM"
try {
    $wl['RunHKLM'] = Get-RegValues 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
    Write-OK "$($wl['RunHKLM'].Count) Eintraege"
} catch { Write-Warn $_; $wl['RunHKLM'] = [ordered]@{} }

# ── 2: Run HKCU ──────────────────────────────────────────────────────────────
Write-Step "2/20  Run Keys HKCU"
try {
    $wl['RunHKCU'] = Get-RegValues 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
    Write-OK "$($wl['RunHKCU'].Count) Eintraege"
} catch { Write-Warn $_; $wl['RunHKCU'] = [ordered]@{} }

# ── 3: RunOnce HKLM ──────────────────────────────────────────────────────────
Write-Step "3/20  RunOnce HKLM"
try {
    $wl['RunOnceHKLM'] = Get-RegValues 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    Write-OK "$($wl['RunOnceHKLM'].Count) Eintraege"
} catch { Write-Warn $_; $wl['RunOnceHKLM'] = [ordered]@{} }

# ── 4: RunOnce HKCU ──────────────────────────────────────────────────────────
Write-Step "4/20  RunOnce HKCU"
try {
    $wl['RunOnceHKCU'] = Get-RegValues 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
    Write-OK "$($wl['RunOnceHKCU'].Count) Eintraege"
} catch { Write-Warn $_; $wl['RunOnceHKCU'] = [ordered]@{} }

# ── 5: Scheduled Tasks ───────────────────────────────────────────────────────
Write-Step "5/20  Scheduled Tasks"
try {
    $taskList = @(
        Get-ScheduledTask -ErrorAction SilentlyContinue | ForEach-Object {
            ($_.TaskPath.TrimEnd('\') + '\' + $_.TaskName)
        }
    )
    $wl['ScheduledTasks'] = $taskList
    Write-OK "$($taskList.Count) Tasks"
} catch { Write-Warn $_; $wl['ScheduledTasks'] = @() }

# ── 6: Services (Automatic / Manual) ─────────────────────────────────────────
Write-Step "6/20  Services (Automatic/Manual)"
try {
    $svcList = @(
        Get-WmiObject Win32_Service -ErrorAction Stop |
            Where-Object { $_.StartMode -in @('Auto', 'Manual') } |
            Select-Object -ExpandProperty Name |
            Sort-Object
    )
    $wl['Services'] = $svcList
    Write-OK "$($svcList.Count) Dienste"
} catch { Write-Warn $_; $wl['Services'] = @() }

# ── 7: Startup-Ordner User ───────────────────────────────────────────────────
Write-Step "7/20  Startup-Ordner User"
try {
    $p = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup"
    $files = @(if (Test-Path $p) { Get-ChildItem $p -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name })
    $wl['StartupUser'] = $files
    Write-OK "$($files.Count) Dateien"
} catch { Write-Warn $_; $wl['StartupUser'] = @() }

# ── 8: Startup-Ordner Public ─────────────────────────────────────────────────
Write-Step "8/20  Startup-Ordner Public"
try {
    $p = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup'
    $files = @(if (Test-Path $p) { Get-ChildItem $p -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name })
    $wl['StartupPublic'] = $files
    Write-OK "$($files.Count) Dateien"
} catch { Write-Warn $_; $wl['StartupPublic'] = @() }

# ── 9: WMI Subscriptions ─────────────────────────────────────────────────────
Write-Step "9/20  WMI Subscriptions"
try {
    $filters   = @(Get-WmiObject -Namespace root\subscription -Class __EventFilter            -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
    $consumers = @(Get-WmiObject -Namespace root\subscription -Class __EventConsumer           -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name)
    $bindings  = @(Get-WmiObject -Namespace root\subscription -Class __FilterToConsumerBinding -ErrorAction SilentlyContinue |
                   ForEach-Object { "$($_.Filter) -> $($_.Consumer)" })
    $wl['WMIFilters']   = $filters
    $wl['WMIConsumers'] = $consumers
    $wl['WMIBindings']  = $bindings
    Write-OK "Filter: $($filters.Count)  Consumer: $($consumers.Count)  Bindings: $($bindings.Count)"
} catch {
    Write-Warn $_
    $wl['WMIFilters'] = @(); $wl['WMIConsumers'] = @(); $wl['WMIBindings'] = @()
}

# ── 10: AppCertDlls ──────────────────────────────────────────────────────────
Write-Step "10/20 AppCertDlls"
try {
    $p = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCertDlls'
    $wl['AppCertDlls'] = if (Test-Path $p) { Get-RegValues $p } else { [ordered]@{} }
    Write-OK "$($wl['AppCertDlls'].Count) Eintraege (normal: 0)"
} catch { Write-Warn $_; $wl['AppCertDlls'] = [ordered]@{} }

# ── 11: AppInit_DLLs ─────────────────────────────────────────────────────────
Write-Step "11/20 AppInit_DLLs"
try {
    $v = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows' -Name AppInit_DLLs -ErrorAction SilentlyContinue).AppInit_DLLs
    $wl['AppInitDLLs'] = if ($null -eq $v) { '' } else { $v }
    Write-OK "Wert: '$($wl['AppInitDLLs'])'"
} catch { Write-Warn $_; $wl['AppInitDLLs'] = '' }

# ── 12: AppInit_DLLs Wow64 ───────────────────────────────────────────────────
Write-Step "12/20 AppInit_DLLs Wow64"
try {
    $v = (Get-ItemProperty 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\Windows' -Name AppInit_DLLs -ErrorAction SilentlyContinue).AppInit_DLLs
    $wl['AppInitDLLsWow64'] = if ($null -eq $v) { '' } else { $v }
    Write-OK "Wert: '$($wl['AppInitDLLsWow64'])'"
} catch { Write-Warn $_; $wl['AppInitDLLsWow64'] = '' }

# ── 13: LSA Security Packages ────────────────────────────────────────────────
Write-Step "13/20 LSA Security Packages"
try {
    $v = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' -Name 'Security Packages' -ErrorAction SilentlyContinue).'Security Packages'
    $wl['LSASecurityPackages'] = @(if ($null -eq $v) { @() } else { $v })
    Write-OK "$($wl['LSASecurityPackages'].Count) Pakete"
} catch { Write-Warn $_; $wl['LSASecurityPackages'] = @() }

# ── 14: LSA OSConfig Security Packages ──────────────────────────────────────
Write-Step "14/20 LSA OSConfig Security Packages"
try {
    $v = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\OSConfig' -Name 'Security Packages' -ErrorAction SilentlyContinue).'Security Packages'
    $wl['LSAOSConfigSecurityPackages'] = @(if ($null -eq $v) { @() } else { $v })
    Write-OK "$($wl['LSAOSConfigSecurityPackages'].Count) Pakete"
} catch { Write-Warn $_; $wl['LSAOSConfigSecurityPackages'] = @() }

# ── 15: NetSh Helper DLLs ────────────────────────────────────────────────────
Write-Step "15/20 NetSh Helper DLLs"
try {
    $wl['NetShHelperDLLs'] = Get-RegValues 'HKLM:\SOFTWARE\Microsoft\NetSh'
    Write-OK "$($wl['NetShHelperDLLs'].Count) Eintraege"
} catch { Write-Warn $_; $wl['NetShHelperDLLs'] = [ordered]@{} }

# ── 16: Print Monitors ───────────────────────────────────────────────────────
Write-Step "16/20 Print Monitors"
try {
    $monitors = @(Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors' -ErrorAction SilentlyContinue |
                  Select-Object -ExpandProperty PSChildName)
    $wl['PrintMonitors'] = $monitors
    Write-OK "$($monitors.Count) Monitore"
} catch { Write-Warn $_; $wl['PrintMonitors'] = @() }

# ── 17: BootExecute ──────────────────────────────────────────────────────────
Write-Step "17/20 BootExecute"
try {
    $v = (Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' -Name BootExecute -ErrorAction Stop).BootExecute
    $wl['BootExecute'] = @($v)
    Write-OK "$($wl['BootExecute'] -join ' | ')"
} catch { Write-Warn $_; $wl['BootExecute'] = @('autocheck autochk *') }

# ── 18: IFEO – Debugger-Werte ────────────────────────────────────────────────
Write-Step "18/20 IFEO (Image File Execution Options)"
try {
    $ifeo = [ordered]@{}
    $ifeoPfad = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options'
    Get-ChildItem $ifeoPfad -ErrorAction SilentlyContinue | ForEach-Object {
        try {
            $dbg = (Get-ItemProperty $_.PSPath -Name Debugger -ErrorAction SilentlyContinue).Debugger
            if ($null -ne $dbg) { $ifeo[$_.PSChildName] = $dbg }
        } catch {}
    }
    $wl['IFEO'] = $ifeo
    Write-OK "$($ifeo.Count) Eintraege mit Debugger-Wert (normal: 0)"
} catch { Write-Warn $_; $wl['IFEO'] = [ordered]@{} }

# ── 19: Winlogon ─────────────────────────────────────────────────────────────
Write-Step "19/20 Winlogon"
try {
    $key = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' -ErrorAction Stop
    $wl['WinlogonUserinit'] = if ($null -ne $key.Userinit) { $key.Userinit } else { '' }
    $wl['WinlogonShell']    = if ($null -ne $key.Shell)    { $key.Shell }    else { '' }
    Write-OK "Userinit='$($wl['WinlogonUserinit'])'  Shell='$($wl['WinlogonShell'])'"
} catch { Write-Warn $_; $wl['WinlogonUserinit'] = ''; $wl['WinlogonShell'] = '' }

# ── 20: Time Providers ───────────────────────────────────────────────────────
Write-Step "20/20 Time Providers"
try {
    $providers = @(Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders' -ErrorAction SilentlyContinue |
                   Select-Object -ExpandProperty PSChildName)
    $wl['TimeProviders'] = $providers
    Write-OK "$($providers.Count) Provider"
} catch { Write-Warn $_; $wl['TimeProviders'] = @() }

# ── Export ───────────────────────────────────────────────────────────────────
Write-Host ""
Write-Step "Exportiere whitelist.json..."
try {
    $wl | ConvertTo-Json -Depth 10 | Set-Content -Path $outputPath -Encoding UTF8
    Write-Host "[DONE] whitelist.json gespeichert: $outputPath" -ForegroundColor Green
} catch {
    Write-Host "[FEHLER] Konnte whitelist.json nicht schreiben: $_" -ForegroundColor Red
    exit 1
}
