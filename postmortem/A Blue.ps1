# ==============================================================================
# BLUE TEAM DEFENDER - Integrated Security Scanner v5.0 (COMPLETE)
# ==============================================================================
# Full working script - Copy all parts sequentially
# Save as: BlueTeam_Defender_v5.0.ps1
# Run as Administrator for full functionality
# ==============================================================================

#Requires -Version 5.0

$ErrorActionPreference = 'SilentlyContinue'

# ==============================================================================
# CONFIGURATION
# ==============================================================================
$Config = @{
    # Core IOCs
    RegRunPath      = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    RegRunName      = "WinUpdateSvc"
    TaskName        = "MicrosoftUpdateHelper"
    PwnedFile       = "C:\Users\Public\Documents\pwned.txt"
    
    # Ghost persistence detection
    GhostRegPath    = "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce"
    GhostRegName    = "BlueTeamDefenderGuard"
    
    # GUID drop folder IOCs
    GuidFolderName  = '{B6341000-21CD-4C19-82CF-60C4C444FDC7}'
    GuidDropFolder  = "$env:TEMP\{B6341000-21CD-4C19-82CF-60C4C444FDC7}"
    EncodedFileName = 'powershell script to base64 UTF16-LE string.ps1'
    
    # Hunt strings
    HuntStrings     = @("pwned.txt", "pwned", "Pwn3d", "WinUpdateSvc",
                        "MicrosoftUpdateHelper", "B6341000-21CD-4C19-82CF-60C4C444FDC7",
                        "powershell script to base64 UTF16-LE string", "SystemUIHost", "SystemUIHostTask")
    
    # Suspect script filenames
    SuspectScripts  = @(
        "svchost_helper.ps1", "svchost_helper_bak.ps1", "WinDefSvc.ps1",
        "WindowsUpdateService.ps1", "WindowsUpdateService_integrated.ps1",
        "powershell script to base64 UTF16-LE string.ps1", "final_attack.ps1"
    )
    
    # PS1 extensions to hunt
    SuspiciousExtensions = @('.ps1','.vbs','.js','.wsf','.hta','.bat','.cmd','.py','.rb','.jar','.jse','.wsh')
    
    # Suspicious paths
    SuspiciousPaths = @(
        '\AppData\', '\Temp\', '\tmp\', '\Public\', '\ProgramData\',
        '\Downloads\', '\Desktop\', '\Users\', '\Documents\', '\Music\',
        '\Pictures\', '\Videos\', '\Recycle', 'C:\Windows\Temp'
    )
    
    # Argument red flags
    ArgumentRedFlags = @(
        '-bypass', '-encodedcommand', '-enc ', '-windowstyle hidden',
        '-w hidden', '-nop ', '-noprofile', 'frombase64', 'iex ',
        'invoke-expression', 'downloadstring', 'webclient',
        'hidden.*bypass', 'executionpolicy bypass', '-Win Hidden'
    )
    
    # Interpreter patterns
    InterpreterPatterns = @(
        'powershell', 'pwsh', 'wscript', 'cscript', 'mshta', 'wmic',
        'msiexec', 'regsvr32', 'rundll32', 'certutil', 'bitsadmin', 'cmd\.exe\s.*/[cCkK]'
    )
    
    # Filesystem roots to scan
    SearchRoots = @(
        $env:TEMP, $env:APPDATA, $env:LOCALAPPDATA,
        "C:\Users\Public", "C:\Windows\Temp", "C:\ProgramData",
        "C:\Windows\System32\Tasks", "$env:USERPROFILE\Downloads",
        "$env:USERPROFILE\Desktop", "$env:USERPROFILE\Documents"
    )
    
    # Registry hives to deep-scan
    RegHivesToScan = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnceEx",
        "HKCU:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnceEx",
        "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon",
        "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon",
        "HKLM:\System\CurrentControlSet\Control\Lsa",
        "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Windows",
        "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Image File Execution Options",
        "HKLM:\System\CurrentControlSet\Services",
        "HKCU:\Environment"
    )
    
    # Startup folders
    StartupFolders = @(
        [Environment]::GetFolderPath('Startup'),
        [Environment]::GetFolderPath('CommonStartup'),
        "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup",
        'C:\Windows\Start Menu\Programs\Startup'
    ) | Sort-Object -Unique
    
    # Watchdog timing
    WatchdogIntervalSeconds = 30
    
    # Output paths
    ReportPath          = "$env:USERPROFILE\Desktop\BlueTeam_Defender_Report_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    WatchdogResultsPath = "$env:USERPROFILE\Desktop\BlueTeam_Watchdog_Results_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    WatchdogLogPath     = "$env:USERPROFILE\Desktop\BlueTeam_Defender_Watchdog.txt"
    DesktopShortcutPath = "$env:USERPROFILE\Desktop\BlueTeam_Defender_Watchdog.lnk"
}

# ==============================================================================
# GLOBAL STATE
# ==============================================================================
$script:Findings      = [System.Collections.Generic.List[PSCustomObject]]::new()
$script:WatchdogFindings = [System.Collections.Generic.List[PSCustomObject]]::new()
$script:Removed       = 0
$script:Skipped       = 0
$script:CycleCount    = 0
$script:TotalRemoved  = 0
$script:WatchdogRunning = $true
$script:StartTime     = Get-Date

# ==============================================================================
# UTILITY FUNCTIONS
# ==============================================================================

function Write-Banner {
    param([string]$Text, [string]$Color = "Cyan")
    $line = "=" * 70
    Write-Host "`n$line" -ForegroundColor $Color
    Write-Host "  $Text" -ForegroundColor $Color
    Write-Host "$line" -ForegroundColor $Color
}

function Write-Section {
    param([string]$T)
    Write-Host "`n$("=" * 70)`n  $T`n$("=" * 70)" -ForegroundColor Cyan
}

function Write-Sub { 
    param([string]$T) 
    Write-Host "`n  -- $T" -ForegroundColor DarkCyan 
}

function Write-OK { 
    param([string]$m) 
    Write-Host "    [OK]   $m" -ForegroundColor Green 
}

function Write-Info { 
    param([string]$m) 
    Write-Host "    [INFO] $m" -ForegroundColor Gray  
}

function Write-Finding {
    param(
        [string]$Category,
        [string]$Name,
        [string]$Detail,
        [string]$Reason,
        [string]$Action = 'Removed',
        [switch]$WatchdogMode
    )
    
    $finding = [PSCustomObject]@{
        Category = $Category
        Name     = $Name
        Detail   = $Detail
        Reason   = $Reason
        Action   = $Action
        Time     = Get-Date
        Cycle    = if ($WatchdogMode) { $script:CycleCount } else { 0 }
        Type     = if ($WatchdogMode) { "WATCHDOG" } else { "INITIAL_SCAN" }
    }
    
    if ($WatchdogMode) {
        $script:WatchdogFindings.Add($finding)
    } else {
        $script:Findings.Add($finding)
    }
    
    # Console output
    $prefix = if ($WatchdogMode) { "  [WATCH][FOUND]" } else { "  [FOUND]" }
    Write-Host "$prefix $Category : $Name" -ForegroundColor Red
    Write-Host "               $Detail" -ForegroundColor DarkYellow
    Write-Host "               Reason : $Reason" -ForegroundColor DarkYellow
    
    # Immediately save to appropriate report file
    $reportLine = @"
[$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))] [$($finding.Type)] CATEGORY: $Category
  Name: $Name
  Detail: $Detail
  Reason: $Reason
  Action: $Action
  $(if ($WatchdogMode) { "  Cycle: $($script:CycleCount)`n" } else { "`n" })
"@
    
    if ($WatchdogMode) {
        $reportLine | Out-File -FilePath $Config.WatchdogResultsPath -Append -Encoding UTF8 -ErrorAction SilentlyContinue
        $reportLine | Out-File -FilePath $Config.ReportPath -Append -Encoding UTF8 -ErrorAction SilentlyContinue
    } else {
        $reportLine | Out-File -FilePath $Config.ReportPath -Append -Encoding UTF8 -ErrorAction SilentlyContinue
    }
}

function Write-Removed {
    param([string]$m, [switch]$WatchdogMode)
    $prefix = if ($WatchdogMode) { "  [W-REMOVED]" } else { "    [REMOVED]" }
    Write-Host "$prefix $m" -ForegroundColor Green
    $script:Removed++
    $script:TotalRemoved++
    
    $removalLine = "[$([DateTime]::Now.ToString('yyyy-MM-dd HH:mm:ss'))] REMOVED: $m`n"
    $removalLine | Out-File -FilePath $Config.ReportPath -Append -Encoding UTF8 -ErrorAction SilentlyContinue
    if ($WatchdogMode) {
        $removalLine | Out-File -FilePath $Config.WatchdogResultsPath -Append -Encoding UTF8 -ErrorAction SilentlyContinue
    }
}

function Write-WatchStatus {
    param([string]$Label, [string]$Status, [string]$Color = "Green")
    Write-Host ("  {0,-50} {1}" -f $Label, $Status) -ForegroundColor $Color
}

function Confirm-Auto {
    param([string]$Prompt)
    Write-Host "    [AUTO-YES] $Prompt" -ForegroundColor DarkGray
    return $true
}

function Test-IsSuspicious {
    param(
        [string]$CommandLine = '',
        [string]$Name        = '',
        [string]$ExtraContext = ''
    )

    $haystack = ($CommandLine + ' ' + $Name + ' ' + $ExtraContext).ToLower()

    foreach ($kw in $Config.HuntStrings) {
        if ($haystack -like "*$($kw.ToLower())*") { 
            return $true, "Contains hunt keyword '$kw'" 
        }
    }

    foreach ($path in $Config.SuspiciousPaths) {
        if ($haystack -like "*$($path.ToLower())*") {
            return $true, "Binary/script located in user-writable path: $path"
        }
    }

    foreach ($flag in $Config.ArgumentRedFlags) {
        if ($haystack -match [regex]::Escape($flag.ToLower()) -or $haystack -match $flag.ToLower()) {
            return $true, "Suspicious argument flag: $flag"
        }
    }

    foreach ($ext in $Config.SuspiciousExtensions) {
        if ($haystack -like "*$ext*") {
            return $true, "Persistence entry invokes script file (*$ext)"
        }
    }

    foreach ($pat in $Config.InterpreterPatterns) {
        if ($haystack -match $pat) {
            $isSystemBinary = ($CommandLine -match '(?i)C:\\Windows\\System32\\' -or
                               $CommandLine -match '(?i)C:\\Windows\\SysWOW64\\') -and
                              ($CommandLine -notmatch '(?i)(appdata|temp|public|programdata|downloads|users)')
            if (-not $isSystemBinary) {
                return $true, "Interpreter-based launcher outside System32: $pat"
            }
        }
    }

    return $false, ''
}

function Test-FileIsDropper {
    param([string]$FilePath)
    if (-not (Test-Path $FilePath -PathType Leaf)) { return $false }
    try {
        $ext = [System.IO.Path]::GetExtension($FilePath).ToLower()
        if ($ext -notin @('.ps1','.vbs','.bat','.cmd','.js','.wsf','.hta','.txt','.py','.rb','.sh','.ini','.cfg','.xml')) {
            return $false
        }
        $content = Get-Content -Path $FilePath -Raw -ErrorAction Stop
        foreach ($kw in $Config.HuntStrings) {
            if ($content -match [regex]::Escape($kw)) { return $true }
        }
    } catch {}
    return $false
}

function Remove-PersistenceEntry {
    param(
        [scriptblock]$RemoveBlock,
        [string]$Label,
        [switch]$WatchdogMode
    )
    try {
        & $RemoveBlock
        Write-Removed "$Label" -WatchdogMode:$WatchdogMode
        return $true
    } catch {
        $script:Skipped++
        Write-Host "               [FAILED]  $Label - $_" -ForegroundColor Magenta
        return $false
    }
}

function Get-DecodedPayload {
    param([string]$FilePath)
    try {
        $raw   = Get-Content $FilePath -Raw -Encoding UTF8 -EA Stop
        $match = [regex]::Match($raw, '[A-Za-z0-9+/]{100,}={0,2}')
        if (-not $match.Success) { return $null }
        $bytes  = [Convert]::FromBase64String($match.Value)
        $decoded = [System.Text.Encoding]::Unicode.GetString($bytes)
        return $decoded
    } catch { return $null }
}

# ==============================================================================
# DEFENSIVE REGISTRY ENTRY
# ==============================================================================
function Install-DefensiveRegistryGuard {
    Write-Banner "DEFENSIVE MEASURE - Ghost Registry Guard"
    
    $defenderScript = @"
# BlueTeam Defender Guard - Auto-cleans ghost persistence
`$ErrorActionPreference = 'SilentlyContinue'
Start-Sleep -Seconds 3
Get-Process -Name "powershell","pwsh" -EA SilentlyContinue | ForEach-Object {
    try {
        `$cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=`$(`$_.Id)" -EA Stop).CommandLine
        if (`$cmd -match "pwned|Pwn3d|Set-Content.*pwned") {
            Stop-Process -Id `$_.Id -Force -EA SilentlyContinue
        }
    } catch {}
}
if (Test-Path "C:\Users\Public\Documents\pwned.txt") {
    Remove-Item "C:\Users\Public\Documents\pwned.txt" -Force -EA SilentlyContinue
}
`$runPaths = @(
    'HKCU:\\Software\\Microsoft\\Windows\\CurrentVersion\\Run',
    'HKLM:\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Run'
)
foreach (`$rp in `$runPaths) {
    if (Test-Path `$rp) {
        Get-ItemProperty -Path `$rp -EA SilentlyContinue | ForEach-Object {
            `$_.PSObject.Properties | Where-Object {
                `$_.Name -notmatch '^PS' -and `$_.Value -match 'powershell.*pwned'
            } | ForEach-Object {
                Remove-ItemProperty -Path `$rp -Name `$_.Name -Force -EA SilentlyContinue
            }
        }
    }
}
"@

    $guardScriptPath = "$env:TEMP\BlueTeamGuard.ps1"
    $defenderScript | Out-File -FilePath $guardScriptPath -Encoding ASCII -Force
    
    $guardCommand = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$guardScriptPath`""
    
    try {
        Set-ItemProperty -Path $Config.GhostRegPath -Name $Config.GhostRegName -Value $guardCommand -Force
        Write-OK "Defensive registry guard installed at: $($Config.GhostRegPath)\$($Config.GhostRegName)"
    } catch {
        Write-Info "Could not install defensive guard: $_"
    }
}

# ==============================================================================
# MODULE 1 - Registry Run/RunOnce Keys
# ==============================================================================
function Invoke-ScanRegistryRunKeys {
    Write-Banner "MODULE 1 - Registry Run / RunOnce Keys (PS1 Hunter)"
    
    $runPaths = @(
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnceEx',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnceEx',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce',
        'HKCU:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run',
        'HKCU:\Environment'
    )

    foreach ($regPath in $runPaths) {
        if (-not (Test-Path $regPath)) { continue }

        $item = Get-Item -Path $regPath -ErrorAction SilentlyContinue
        if (-not $item) { continue }

        $values = if ($regPath -like '*\Environment') {
            $item.GetValueNames() | Where-Object { $_ -eq 'UserInitMprLogonScript' }
        } else {
            $item.GetValueNames() | Where-Object { $_ -ne '' }
        }

        foreach ($valueName in $values) {
            $valueData = $item.GetValue($valueName)
            
            $hasPS1 = $valueData -match '\.ps1'
            $hasPowerShell = $valueData -match 'powershell|pwsh'
            $hasPwned = $valueData -match 'pwned|Pwn3d'
            $hasHidden = $valueData -match '-Win Hidden|-windowstyle hidden|-w hidden'
            
            $suspicious, $reason = Test-IsSuspicious -CommandLine $valueData -Name $valueName
            
            if ($hasPS1 -or ($hasPowerShell -and ($hasPwned -or $hasHidden))) {
                $suspicious = $true
                if ($hasPS1) { $reason = "Registry entry executes .ps1 script file" }
                if ($hasPowerShell -and $hasPwned) { $reason = "PowerShell command with pwned keyword in Run key" }
                if ($hasPowerShell -and $hasHidden) { $reason = "PowerShell with hidden window in Run key" }
            }
            
            if ($suspicious) {
                Write-Finding -Category 'Registry Run Key' `
                              -Name "$regPath\$valueName" `
                              -Detail "Value: $valueData" `
                              -Reason $reason
                
                Remove-PersistenceEntry -Label "$regPath\$valueName" -RemoveBlock {
                    Remove-ItemProperty -Path $regPath -Name $valueName -Force -ErrorAction Stop
                }
            } else {
                Write-OK "$regPath\$valueName"
            }
        }
    }
    
    # Winlogon overrides
    $winlogonPath = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
    if (Test-Path $winlogonPath) {
        foreach ($keyName in @('Userinit','Shell','UserInitMprLogonScript')) {
            $val = (Get-ItemProperty -Path $winlogonPath -Name $keyName -ErrorAction SilentlyContinue).$keyName
            if (-not $val) { continue }
            
            $suspicious, $reason = Test-IsSuspicious -CommandLine $val -Name $keyName
            if ($suspicious) {
                Write-Finding -Category 'Winlogon Override' `
                              -Name "$winlogonPath\$keyName" `
                              -Detail "Value: $val" `
                              -Reason "Winlogon $keyName has suspicious entry"
                
                $safeValue = if ($keyName -eq 'Shell') { 'explorer.exe' } else { 'C:\Windows\system32\userinit.exe,' }
                Remove-PersistenceEntry -Label "Restore $keyName to default" -RemoveBlock {
                    Set-ItemProperty -Path $winlogonPath -Name $keyName -Value $safeValue -Force -ErrorAction Stop
                }
            } else {
                Write-OK "Winlogon $keyName = $val"
            }
        }
    }
}

# ==============================================================================
# MODULE 2 - Startup Folders
# ==============================================================================
function Invoke-ScanStartupFolders {
    Write-Banner "MODULE 2 - Startup Folders"

    foreach ($folder in $Config.StartupFolders) {
        if (-not (Test-Path $folder)) { continue }

        Write-Sub $folder
        
        $items = Get-ChildItem -Path $folder -Force -ErrorAction SilentlyContinue
        if (-not $items) {
            Write-OK "Startup folder empty"
            continue
        }

        foreach ($entry in $items) {
            $suspicious = $false
            $reason = ''
            $targetPath = $entry.FullName

            $ext = $entry.Extension.ToLower()
            if ($ext -in $Config.SuspiciousExtensions) {
                $suspicious = $true
                $reason = "Script file ($ext) in Startup folder"
            }

            if ($ext -eq '.lnk') {
                try {
                    $shell = New-Object -ComObject WScript.Shell
                    $lnk = $shell.CreateShortcut($entry.FullName)
                    $target = $lnk.TargetPath + ' ' + $lnk.Arguments
                    $suspicious, $reason = Test-IsSuspicious -CommandLine $target -Name $entry.Name
                    $targetPath = $target
                } catch {}
            }

            if (-not $suspicious -and $ext -eq '.exe') {
                $suspicious, $reason = Test-IsSuspicious -CommandLine $entry.FullName -Name $entry.Name
            }

            if (-not $suspicious -and (Test-FileIsDropper -FilePath $entry.FullName)) {
                $suspicious = $true
                $reason = 'File content contains payload keyword'
            }

            if ($suspicious) {
                Write-Finding -Category 'Startup Folder' `
                              -Name $entry.Name `
                              -Detail "Path: $($entry.FullName) -> $targetPath" `
                              -Reason $reason
                
                $entryPath = $entry.FullName
                Remove-PersistenceEntry -Label $entry.FullName -RemoveBlock {
                    Remove-Item -Path $entryPath -Force -Recurse -ErrorAction Stop
                }
            } else {
                Write-OK "Startup: $($entry.Name)"
            }
        }
    }
}

# ==============================================================================
# MODULE 3 - Scheduled Tasks
# ==============================================================================
function Invoke-ScanScheduledTasks {
    Write-Banner "MODULE 3 - Scheduled Tasks"

    $safeMicrosoftPaths = @(
        '\Microsoft\Windows\AppID\', '\Microsoft\Windows\Application Experience\',
        '\Microsoft\Windows\Autochk\', '\Microsoft\Windows\Bluetooth\',
        '\Microsoft\Windows\Diagnosis\', '\Microsoft\Windows\DiskCleanup\',
        '\Microsoft\Windows\Windows Defender\', '\Microsoft\Windows\WindowsUpdate\'
    )

    try {
        $allTasks = Get-ScheduledTask -ErrorAction SilentlyContinue
    } catch {
        Write-Host '  [!] Cannot enumerate scheduled tasks - try running as Administrator' -ForegroundColor Magenta
        return
    }

    foreach ($task in $allTasks) {
        $fullPath = '\' + $task.TaskPath.TrimStart('\') + $task.TaskName
        $actionContext = ''
        
        if ($task.Actions) {
            foreach ($action in $task.Actions) {
                if ($action.CimClass.CimClassName -eq 'MSFT_TaskExecAction') {
                    $actionContext += ' ' + $action.Execute + ' ' + $action.Arguments
                }
                if ($action.CimClass.CimClassName -eq 'MSFT_TaskComHandlerAction') {
                    $actionContext += ' ' + $action.ClassId + ' ' + $action.Data
                }
            }
        }

        $suspicious, $reason = Test-IsSuspicious -CommandLine $actionContext -Name $task.TaskName -ExtraContext $task.TaskPath

        $isMicrosoftPath = $false
        foreach ($safePath in $safeMicrosoftPaths) {
            if ($task.TaskPath -like "*$safePath*" -or $task.TaskPath -eq $safePath.TrimEnd('\')) {
                $isMicrosoftPath = $true; break
            }
        }

        if ($isMicrosoftPath -and -not $suspicious) {
            foreach ($pat in @('powershell','pwsh','wscript','cscript','mshta','cmd\.exe')) {
                if ($actionContext -match $pat) {
                    $suspicious = $true
                    $reason = "Microsoft-namespaced task path runs interpreter ($pat) - likely masquerade"
                    break
                }
            }
        }

        if ($suspicious) {
            Write-Finding -Category 'Scheduled Task' `
                          -Name $fullPath `
                          -Detail "Action: $($actionContext.Trim())" `
                          -Reason $reason
            
            $tPath = $task.TaskPath
            $tName = $task.TaskName
            Remove-PersistenceEntry -Label "Task: $fullPath" -RemoveBlock {
                Unregister-ScheduledTask -TaskPath $tPath -TaskName $tName -Confirm:$false -ErrorAction Stop
            }
        } else {
            Write-OK "Task: $fullPath"
        }
    }
}

# ==============================================================================
# MODULE 4 - Windows Services
# ==============================================================================
function Invoke-ScanServices {
    Write-Banner "MODULE 4 - Windows Services"

    $services = Get-WmiObject Win32_Service -ErrorAction SilentlyContinue
    if (-not $services) {
        Write-Host '  [!] WMI service query failed' -ForegroundColor Magenta
        return
    }

    foreach ($svc in $services) {
        $binPath = $svc.PathName -replace '"',''
        if (-not $binPath) { continue }

        $suspicious, $reason = Test-IsSuspicious -CommandLine $binPath -Name $svc.Name

        if ($suspicious) {
            Write-Finding -Category 'Windows Service' `
                          -Name $svc.Name `
                          -Detail "Binary: $binPath | Start: $($svc.StartMode) | State: $($svc.State)" `
                          -Reason $reason
            
            $svcName = $svc.Name
            Remove-PersistenceEntry -Label "Service disabled+stopped: $svcName" -RemoveBlock {
                Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
                Set-Service -Name $svcName -StartupType Disabled -ErrorAction Stop
            }
        } else {
            Write-OK "Service: $($svc.Name) [$($svc.StartMode)]"
        }
    }
}

# ==============================================================================
# MODULE 5 - WMI Permanent Event Subscriptions
# ==============================================================================
function Invoke-ScanWMISubscriptions {
    Write-Banner "MODULE 5 - WMI Permanent Event Subscriptions"

    try {
        $filters   = Get-WMIObject -Namespace 'root\subscription' -Class '__EventFilter'   -ErrorAction Stop
        $consumers = Get-WMIObject -Namespace 'root\subscription' -Class '__EventConsumer'  -ErrorAction Stop
        $bindings  = Get-WMIObject -Namespace 'root\subscription' -Class '__FilterToConsumerBinding' -ErrorAction Stop
    } catch {
        Write-Host '  [!] WMI namespace query failed (admin required)' -ForegroundColor Magenta
        return
    }

    $wmiClean = $true

    foreach ($filter in $filters) {
        $wmiClean = $false
        Write-Finding -Category 'WMI EventFilter' `
                      -Name $filter.Name `
                      -Detail "Query: $($filter.Query)" `
                      -Reason 'WMI EventFilter found - root\subscription should be empty on clean systems'
        
        Remove-PersistenceEntry -Label "WMI Filter: $($filter.Name)" -RemoveBlock {
            $filter | Remove-WMIObject -ErrorAction Stop
        }
    }

    foreach ($consumer in $consumers) {
        $wmiClean = $false
        $detail = if ($consumer.CommandLineTemplate) { "CMD: $($consumer.CommandLineTemplate)" }
                  elseif ($consumer.ScriptText)      { "Script: $($consumer.ScriptText.Substring(0,[math]::Min(80,$consumer.ScriptText.Length)))..." }
                  else                               { "ClassID: $($consumer.__CLASS)" }
        Write-Finding -Category 'WMI EventConsumer' `
                      -Name $consumer.Name `
                      -Detail $detail `
                      -Reason 'WMI EventConsumer found - root\subscription should be empty on clean systems'
        
        Remove-PersistenceEntry -Label "WMI Consumer: $($consumer.Name)" -RemoveBlock {
            $consumer | Remove-WMIObject -ErrorAction Stop
        }
    }

    foreach ($binding in $bindings) {
        $wmiClean = $false
        Write-Finding -Category 'WMI FilterToConsumerBinding' `
                      -Name "$($binding.Filter) -> $($binding.Consumer)" `
                      -Detail "Binding in root\subscription" `
                      -Reason 'WMI Binding found - root\subscription should be empty on clean systems'
        
        Remove-PersistenceEntry -Label 'WMI Binding removed' -RemoveBlock {
            $binding | Remove-WMIObject -ErrorAction Stop
        }
    }

    if ($wmiClean) { Write-OK 'WMI root\subscription is clean' }
}

# ==============================================================================
# MODULE 6 - BITS Jobs
# ==============================================================================
function Invoke-ScanBITSJobs {
    Write-Banner "MODULE 6 - BITS Transfer Jobs"

    try {
        $jobs = Get-BitsTransfer -AllUsers -ErrorAction Stop
    } catch {
        Write-Host '  [!] BITS enumeration failed (admin required for -AllUsers)' -ForegroundColor Magenta
        try { $jobs = Get-BitsTransfer -ErrorAction SilentlyContinue } catch { return }
    }

    if (-not $jobs) { Write-OK 'No BITS jobs found'; return }

    foreach ($job in $jobs) {
        $context  = "$($job.DisplayName) $($job.JobState) $(($job.FileList | ForEach-Object { $_.RemoteName }) -join ' ')"
        $suspicious, $reason = Test-IsSuspicious -CommandLine $context -Name $job.DisplayName
        
        if ($suspicious -or $job.JobState -eq 'Suspended') {
            $finalReason = if ($reason) { $reason } else { 'Suspended BITS job with suspicious context' }

            Write-Finding -Category 'BITS Job' `
                          -Name $job.DisplayName `
                          -Detail "State: $($job.JobState) | ID: $($job.JobId)" `
                          -Reason $finalReason
            
            $jobId = $job.JobId
            Remove-PersistenceEntry -Label "BITS job $($job.JobId) cancelled" -RemoveBlock {
                Get-BitsTransfer -JobId $jobId -ErrorAction Stop | Remove-BitsTransfer -ErrorAction Stop
            }
        } else {
            Write-OK "BITS: $($job.DisplayName) [$($job.JobState)]"
        }
    }
}

# ==============================================================================
# MODULE 7 - Active Setup
# ==============================================================================
function Invoke-ScanActiveSetup {
    Write-Banner "MODULE 7 - Active Setup"

    $asPaths = @(
        'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Active Setup\Installed Components'
    )

    foreach ($asBase in $asPaths) {
        if (-not (Test-Path $asBase)) { continue }
        Get-ChildItem -Path $asBase | ForEach-Object {
            $stubPath = (Get-ItemProperty -Path $_.PSPath -Name 'StubPath' -ErrorAction SilentlyContinue).StubPath
            if ($stubPath) {
                $suspicious, $reason = Test-IsSuspicious -CommandLine $stubPath -Name $_.PSChildName
                if ($suspicious) {
                    Write-Finding -Category 'Active Setup' `
                                  -Name $_.PSChildName `
                                  -Detail "StubPath: $stubPath" `
                                  -Reason $reason
                    
                    $keyPath = $_.PSPath
                    Remove-PersistenceEntry -Label "Active Setup key: $($_.PSChildName)" -RemoveBlock {
                        Remove-Item -Path $keyPath -Recurse -Force -ErrorAction Stop
                    }
                }
            }
        }
    }
    Write-OK 'Active Setup scan complete'
}

# ==============================================================================
# MODULE 8 - Disk Dropper Hunt
# ==============================================================================
function Invoke-ScanDropperScripts {
    Write-Banner "MODULE 8 - Disk Dropper Script Hunt"

    $huntPaths = @(
        $env:TEMP, $env:TMP, "$env:APPDATA", "$env:LOCALAPPDATA\Temp",
        "$env:LOCALAPPDATA\Microsoft", "$env:ProgramData", "$env:ProgramData\Microsoft",
        'C:\Users\Public', 'C:\Users\Public\Documents', 'C:\Windows\Temp',
        "$env:USERPROFILE\Downloads", "$env:USERPROFILE\Desktop"
    ) | Sort-Object -Unique

    $scriptExtensions = @('*.ps1','*.vbs','*.bat','*.cmd','*.js','*.wsf','*.hta','*.py')
    $found = 0

    foreach ($huntDir in $huntPaths) {
        if (-not (Test-Path $huntDir)) { continue }

        foreach ($pattern in $scriptExtensions) {
            $candidates = Get-ChildItem -Path $huntDir -Filter $pattern -Force -ErrorAction SilentlyContinue
            foreach ($file in $candidates) {
                if (Test-FileIsDropper -FilePath $file.FullName) {
                    $found++
                    Write-Finding -Category 'Dropper Script (disk)' `
                                  -Name $file.Name `
                                  -Detail "Path: $($file.FullName)" `
                                  -Reason 'File content references payload IOC keyword'
                    
                    $filePath = $file.FullName
                    Remove-PersistenceEntry -Label "Dropper deleted: $filePath" -RemoveBlock {
                        Remove-Item -Path $filePath -Force -ErrorAction Stop
                    }
                }
            }
        }
    }

    if ($found -eq 0) { Write-OK 'No dropper scripts found in monitored directories' }
}

# ==============================================================================
# MODULE 9 - Kill Suspicious PowerShell Processes
# ==============================================================================
function Invoke-KillSuspiciousPowerShell {
    Write-Banner "MODULE 9 - Kill Suspicious PowerShell Processes"
    
    $killed = 0
    $psProcs = Get-Process -Name "powershell","pwsh" -ErrorAction SilentlyContinue
    
    foreach ($proc in $psProcs) {
        try {
            $wmi = Get-CimInstance Win32_Process -Filter "ProcessId=$($proc.Id)" -EA Stop
            $cmd = $wmi.CommandLine
            
            if ($cmd -match "pwned|Pwn3d|Set-Content.*pwned|Start-Sleep.*Set-Content" -or
                $cmd -match "-Win Hidden.*Set-Content" -or
                $cmd -match "pw.*ned\.txt") {
                
                Write-Finding -Category 'Suspicious Process' `
                              -Name "PID $($proc.Id)" `
                              -Detail "Command: $($cmd.Substring(0,[Math]::Min(200,$cmd.Length)))" `
                              -Reason "Process attempting to create pwned.txt or contains payload keyword"
                
                Remove-PersistenceEntry -Label "Kill PowerShell PID $($proc.Id)" -RemoveBlock {
                    Stop-Process -Id $proc.Id -Force -ErrorAction Stop
                }
                $killed++
            }
        } catch {}
    }
    
    if ($killed -eq 0) { Write-OK "No suspicious PowerShell processes found" }
}

# ==============================================================================
# MODULE 10 - Payload File Removal
# ==============================================================================
function Invoke-RemovePayload {
    Write-Banner "MODULE 10 - Payload File Removal"

    if (Test-Path $Config.PwnedFile) {
        $content = Get-Content $Config.PwnedFile -Raw -ErrorAction SilentlyContinue
        Write-Finding -Category 'Payload File' `
                      -Name $Config.PwnedFile `
                      -Detail "Content: $($content -replace "`n"," ")" `
                      -Reason 'Payload file exists - attacker persistence already fired'
        
        $pFile = $Config.PwnedFile
        Remove-PersistenceEntry -Label "Payload deleted: $Config.PwnedFile" -RemoveBlock {
            Remove-Item -Path $pFile -Force -ErrorAction Stop
        }
    } else {
        Write-OK "Payload file not present: $Config.PwnedFile"
    }

    Get-ChildItem -Path 'C:\Users\Public' -Recurse -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -match 'pwned|Pwn3d' -or (Test-FileIsDropper -FilePath $_.FullName) } |
        ForEach-Object {
            Write-Finding -Category 'Payload Artifact' `
                          -Name $_.Name `
                          -Detail $_.FullName `
                          -Reason 'File name or content matches payload IOC'
            
            $iPath = $_.FullName
            Remove-PersistenceEntry -Label "Artifact removed: $iPath" -RemoveBlock {
                Remove-Item -Path $iPath -Force -ErrorAction Stop
            }
        }
}

# ==============================================================================
# MODULE 11 - GUID Pattern Folder Scanner
# ==============================================================================
function Invoke-ScanGuidFolders {
    Write-Banner "MODULE 11 - GUID-Pattern Folder Scanner"
    
    $guidPattern = '^\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}$'
    $guidRoots = @($env:TEMP, $env:LOCALAPPDATA, "C:\Windows\Temp", "C:\Users\Public")
    $found = 0
    
    foreach ($root in $guidRoots) {
        if (-not (Test-Path $root)) { continue }
        
        Get-ChildItem -Path $root -Directory -Force -EA SilentlyContinue |
        Where-Object { $_.Name -match $guidPattern } |
        ForEach-Object {
            $folderPath = $_.FullName
            $ps1Files = Get-ChildItem $folderPath -Filter '*.ps1' -Force -Recurse -EA SilentlyContinue
            $hasBase64 = $false
            
            foreach ($f in $ps1Files) {
                $raw = Get-Content $f.FullName -Raw -EA SilentlyContinue
                if ($raw -match '[A-Za-z0-9+/]{100,}={0,2}') { $hasBase64 = $true }
            }
            
            $isKnownBad = ($_.Name -eq $Config.GuidFolderName)
            if ($isKnownBad -or $hasBase64 -or ($ps1Files.Count -gt 0)) {
                $found++
                Write-Finding -Category 'GUID Folder' `
                              -Name $_.Name `
                              -Detail "Path: $folderPath | PS1: $($ps1Files.Count) | Base64: $hasBase64" `
                              -Reason "GUID-pattern folder with suspicious content"
                
                Remove-PersistenceEntry -Label "GUID folder: $folderPath" -RemoveBlock {
                    Get-ChildItem $folderPath -Force -Recurse -EA SilentlyContinue |
                        ForEach-Object { try { $_.Attributes = 'Normal' } catch {} }
                    Remove-Item $folderPath -Recurse -Force -ErrorAction Stop
                }
            }
        }
    }
    
    if ($found -eq 0) { Write-OK "No suspicious GUID-pattern folders found" }
}

# ==============================================================================
# MODULE 12 - Base64 Encoded PS1 Detector
# ==============================================================================
function Invoke-ScanBase64Encoded {
    Write-Banner "MODULE 12 - Base64 Encoded PowerShell Detector"
    
    $scanRoots = @($env:TEMP, $env:APPDATA, $env:LOCALAPPDATA, "C:\Users\Public", "C:\Windows\Temp", "C:\ProgramData")
    $found = 0
    
    foreach ($root in $scanRoots) {
        if (-not (Test-Path $root)) { continue }
        
        Get-ChildItem $root -Filter '*.ps1' -Recurse -Force -EA SilentlyContinue |
        ForEach-Object {
            try {
                $raw = Get-Content $_.FullName -Raw -Encoding UTF8 -EA Stop
                if ($raw -match '[A-Za-z0-9+/]{100,}={0,2}') {
                    $found++
                    $decoded = Get-DecodedPayload -FilePath $_.FullName
                    $preview = if ($decoded) {
                        $decoded.Substring(0, [Math]::Min(100, $decoded.Length)) -replace "`r`n|`n"," | "
                    } else { "(decode failed)" }
                    
                    Write-Finding -Category 'Base64 Encoded PS1' `
                                  -Name $_.Name `
                                  -Detail "Path: $($_.FullName) | Decoded preview: $preview" `
                                  -Reason "Base64-encoded PowerShell script detected"
                    
                    Remove-PersistenceEntry -Label "Encoded PS1: $($_.FullName)" -RemoveBlock {
                        $_.Attributes = 'Normal'
                        Remove-Item $_.FullName -Force -ErrorAction Stop
                    }
                }
            } catch {}
        }
    }
    
    if ($found -eq 0) { Write-OK "No Base64-encoded PS1 files detected" }
}

# ==============================================================================
# TRAY ICON NOTIFICATION FUNCTION
# ==============================================================================
function Show-TrayNotification {
    param([string]$Title, [string]$Message, [string]$Icon = "Info")
    $wshell = New-Object -ComObject Wscript.Shell
    $popup = $wshell.Popup($Message, 3, $Title, 64 + 4096)
}

function Start-TrayIcon {
    param([string]$WatchdogScriptPath)
    
    $trayScript = @"
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

`$watchdogProcess = Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -File `"$WatchdogScriptPath`"" -WindowStyle Hidden -PassThru

`$notifyIcon = New-Object System.Windows.Forms.NotifyIcon
`$notifyIcon.Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe")
`$notifyIcon.Text = "BlueTeam Defender Watchdog`nActive and Monitoring"
`$notifyIcon.Visible = `$true

`$contextMenu = New-Object System.Windows.Forms.ContextMenuStrip
`$statusItem = New-Object System.Windows.Forms.ToolStripMenuItem
`$statusItem.Text = "Status: ACTIVE - Monitoring for persistence"
`$statusItem.Enabled = `$false
`$contextMenu.Items.Add(`$statusItem) | Out-Null

`$contextMenu.Items.Add("-") | Out-Null

`$showItem = New-Object System.Windows.Forms.ToolStripMenuItem
`$showItem.Text = "Show Watchdog Results"
`$showItem.Add_Click({
    Start-Process "notepad.exe" "$($Config.WatchdogResultsPath)"
})
`$contextMenu.Items.Add(`$showItem) | Out-Null

`$stopItem = New-Object System.Windows.Forms.ToolStripMenuItem
`$stopItem.Text = "Stop Watchdog"
`$stopItem.Add_Click({
    Stop-Process -Id `$watchdogProcess.Id -Force -EA SilentlyContinue
    `$notifyIcon.Visible = `$false
    [System.Windows.Forms.Application]::Exit()
})
`$contextMenu.Items.Add(`$stopItem) | Out-Null

`$contextMenu.Items.Add("-") | Out-Null

`$exitItem = New-Object System.Windows.Forms.ToolStripMenuItem
`$exitItem.Text = "Exit (Keep Watchdog Running)"
`$exitItem.Add_Click({
    `$notifyIcon.Visible = `$false
    [System.Windows.Forms.Application]::Exit()
})
`$contextMenu.Items.Add(`$exitItem) | Out-Null

`$notifyIcon.ContextMenuStrip = `$contextMenu
`$notifyIcon.ShowBalloonTip(5000, "BlueTeam Defender", "Watchdog is active and protecting your system`nClick to view status", [System.Windows.Forms.ToolTipIcon]::Info)

[System.Windows.Forms.Application]::Run()
"@
    
    $trayScriptPath = "$env:TEMP\BlueTeamTrayIcon.ps1"
    $trayScript | Out-File -FilePath $trayScriptPath -Encoding UTF8 -Force
    
    Start-Process -FilePath "powershell.exe" -ArgumentList "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$trayScriptPath`"" -WindowStyle Hidden
}

# ==============================================================================
# INSTALL WATCHDOG AS SCHEDULED TASK (Option 2)
# ==============================================================================
function Install-WatchdogScheduledTask {
    Write-Banner "INSTALLING WATCHDOG - Scheduled Task Method"
    
    $watchdogScript = @'
# BlueTeam Defender Watchdog - Background Protection Service
$ErrorActionPreference = 'SilentlyContinue'

$Config = @{
    RegRunPath = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run"
    RegRunName = "WinUpdateSvc"
    TaskName = "MicrosoftUpdateHelper"
    PwnedFile = "C:\Users\Public\Documents\pwned.txt"
    WatchdogIntervalSeconds = 30
    WatchdogResultsPath = "$env:USERPROFILE\Desktop\BlueTeam_Watchdog_Results.txt"
}

function Write-WatchdogLog {
    param([string]$Line)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    "[$timestamp] $Line" | Out-File -FilePath $Config.WatchdogResultsPath -Append -Encoding UTF8 -ErrorAction SilentlyContinue
}

Write-WatchdogLog "=== WATCHDOG SERVICE STARTED ==="

while ($true) {
    $cycleStart = Get-Date
    $removed = 0
    
    try {
        $v = Get-ItemProperty -Path $Config.RegRunPath -Name $Config.RegRunName -EA Stop
        Remove-ItemProperty -Path $Config.RegRunPath -Name $Config.RegRunName -Force -EA SilentlyContinue
        Write-WatchdogLog "REMOVED: Run key $($Config.RegRunName)"
        $removed++
    } catch {}
    
    $runKeys = @('HKCU:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run')
    foreach ($runKey in $runKeys) {
        if (Test-Path $runKey) {
            $props = Get-ItemProperty -Path $runKey -EA SilentlyContinue
            $props.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
                $vData = [string]$_.Value
                if ($vData -match '\.ps1|powershell.*-Win Hidden|pwned') {
                    Remove-ItemProperty -Path $runKey -Name $_.Name -Force -EA SilentlyContinue
                    Write-WatchdogLog "REMOVED: Run entry $($_.Name) (suspicious)"
                    $removed++
                }
            }
        }
    }
    
    if (Test-Path $Config.PwnedFile) {
        Remove-Item $Config.PwnedFile -Force -EA SilentlyContinue
        Write-WatchdogLog "REMOVED: pwned.txt payload file"
        $removed++
    }
    
    Get-Process "powershell","pwsh" -EA SilentlyContinue | ForEach-Object {
        try {
            $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -EA Stop).CommandLine
            if ($cmd -match "pwned|Pwn3d|Set-Content.*pwned") {
                Stop-Process -Id $_.Id -Force -EA SilentlyContinue
                Write-WatchdogLog "KILLED: Suspicious PowerShell PID $($_.Id)"
                $removed++
            }
        } catch {}
    }
    
    if ($removed -gt 0) {
        Write-WatchdogLog "CYCLE COMPLETE: $removed items removed"
    }
    
    Start-Sleep -Seconds $Config.WatchdogIntervalSeconds
}
'@
    
    $watchdogScriptPath = "$env:ProgramData\BlueTeamDefender\Watchdog.ps1"
    $watchdogDir = "$env:ProgramData\BlueTeamDefender"
    
    if (-not (Test-Path $watchdogDir)) {
        New-Item -Path $watchdogDir -ItemType Directory -Force | Out-Null
    }
    
    $watchdogScript | Out-File -FilePath $watchdogScriptPath -Encoding UTF8 -Force
    
    $taskName = "BlueTeamDefenderWatchdog"
    $taskPath = "\BlueTeam"
    
    try {
        Unregister-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Confirm:$false -ErrorAction SilentlyContinue
    } catch {}
    
    $action = New-ScheduledTaskAction -Execute "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" `
                                      -Argument "-ExecutionPolicy Bypass -WindowStyle Hidden -File `"$watchdogScriptPath`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -Hidden
    
    Register-ScheduledTask -TaskName $taskName -TaskPath $taskPath -Action $action -Trigger $trigger -Principal $principal -Settings $settings -Force | Out-Null
    
    Write-OK "Scheduled Task installed: $taskPath\$taskName"
    Write-OK "Watchdog script location: $watchdogScriptPath"
    
    $WScriptShell = New-Object -ComObject WScript.Shell
    $shortcut = $WScriptShell.CreateShortcut($Config.DesktopShortcutPath)
    $shortcut.TargetPath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
    $shortcut.Arguments = "-ExecutionPolicy Bypass -Command Write-Host 'BlueTeam Defender Watchdog is running as scheduled task.' -ForegroundColor Green; Write-Host ''; Write-Host 'Watchdog results: $($Config.WatchdogResultsPath)' -ForegroundColor Gray; Read-Host 'Press Enter to close'"
    $shortcut.IconLocation = "C:\Windows\System32\powershell.exe,0"
    $shortcut.Description = "BlueTeam Defender Watchdog - Protection Active"
    $shortcut.Save()
    
    Write-OK "Desktop shortcut created: $($Config.DesktopShortcutPath)"
    Write-Info "Starting watchdog in current session..."
    
    return $watchdogScriptPath
}

# ==============================================================================
# WATCHDOG LOOP (Foreground Mode)
# ==============================================================================
function Start-WatchdogLoop {
    Write-Banner "WATCHDOG LOOP - Continuous Protection (Foreground Mode)"
    Write-Host "  Watchdog interval: $($Config.WatchdogIntervalSeconds) seconds" -ForegroundColor Gray
    Write-Host "  Results are being saved to: $($Config.WatchdogResultsPath)" -ForegroundColor DarkGray
    Write-Host "  Press Ctrl+C to stop the watchdog and exit" -ForegroundColor Yellow
    Write-Host "  NOTE: Scheduled Task (if installed) will continue after exit" -ForegroundColor Cyan
    Write-Host ""
    
    $watchdogHeader = @"
========================================
BLUE TEAM WATCHDOG RESULTS
Started: $(Get-Date)
Host: $env:COMPUTERNAME
Watchdog Interval: $($Config.WatchdogIntervalSeconds) seconds
========================================

"@
    $watchdogHeader | Out-File -FilePath $Config.WatchdogResultsPath -Encoding UTF8
    
    try {
        [Console]::TreatControlCAsInput = $false
        $cancelHandler = {
            param($sender, $e)
            $e.Cancel = $true
            $script:WatchdogRunning = $false
        }
        [Console]::add_CancelKeyPress($cancelHandler)
    } catch {}
    
    while ($script:WatchdogRunning) {
        $script:CycleCount++
        $cycleStart = Get-Date
        $cycleRemoved = 0
        
        Write-Host ""
        Write-Host ("  +-- WATCHDOG CYCLE #{0,3}  [{1}]  ----" -f $script:CycleCount, $cycleStart.ToString("HH:mm:ss")) -ForegroundColor DarkCyan
        
        try {
            $v = Get-ItemProperty -Path $Config.RegRunPath -Name $Config.RegRunName -EA Stop
            Write-WatchStatus "W1 RUN key '$($Config.RegRunName)'" "[FOUND] auto-removing" "Red"
            Write-Finding -Category 'Watchdog - Registry' -Name $Config.RegRunName -Detail "Value: $($v.$($Config.RegRunName))" -Reason "IOC re-appeared" -Action 'Removed' -WatchdogMode
            Remove-ItemProperty -Path $Config.RegRunPath -Name $Config.RegRunName -Force -EA SilentlyContinue
            $cycleRemoved++
        } catch {
            Write-WatchStatus "W1 RUN key '$($Config.RegRunName)'" "absent OK" "Green"
        }
        
        $runKeys = @(
            'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run',
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
        )
        foreach ($runKey in $runKeys) {
            if (Test-Path $runKey) {
                $props = Get-ItemProperty -Path $runKey -EA SilentlyContinue
                $props.PSObject.Properties | Where-Object { $_.Name -notmatch '^PS' } | ForEach-Object {
                    $vData = [string]$_.Value
                    if ($vData -match '\.ps1|powershell.*-Win Hidden|pwned') {
                        Write-WatchStatus "W2 RUN '$($_.Name)'" "[FOUND] PS1/hidden - removing" "Red"
                        Write-Finding -Category 'Watchdog - Registry PS1' -Name $_.Name -Detail "Value: $vData" -Reason "Suspicious PS1 or hidden PowerShell in Run key" -Action 'Removed' -WatchdogMode
                        Remove-ItemProperty -Path $runKey -Name $_.Name -Force -EA SilentlyContinue
                        $cycleRemoved++
                    }
                }
            }
        }
        Write-WatchStatus "W2 RUN keys PS1 hunt" "complete" "Green"
        
        try {
            $task = Get-ScheduledTask -TaskName $Config.TaskName -EA SilentlyContinue
            if ($task) {
                Write-WatchStatus "W3 Task '$($Config.TaskName)'" "[FOUND] auto-removing" "Red"
                Write-Finding -Category 'Watchdog - Scheduled Task' -Name $Config.TaskName -Detail "Task re-appeared" -Reason "IOC scheduled task detected" -Action 'Removed' -WatchdogMode
                Unregister-ScheduledTask -TaskName $Config.TaskName -Confirm:$false -EA SilentlyContinue
                $cycleRemoved++
            } else {
                Write-WatchStatus "W3 Task '$($Config.TaskName)'" "absent OK" "Green"
            }
        } catch { Write-WatchStatus "W3 Task check" "error" "Yellow" }
        
        if (Test-Path $Config.PwnedFile) {
            $content = Get-Content $Config.PwnedFile -Raw -EA SilentlyContinue
            Write-WatchStatus "W4 pwned.txt" "[FOUND] auto-removing" "Red"
            Write-Finding -Category 'Watchdog - Payload' -Name $Config.PwnedFile -Detail "Content: $content" -Reason "Payload file re-created" -Action 'Removed' -WatchdogMode
            Remove-Item $Config.PwnedFile -Force -EA SilentlyContinue
            $cycleRemoved++
        } else {
            Write-WatchStatus "W4 pwned.txt" "absent OK" "Green"
        }
        
        $killed = 0
        Get-Process "powershell","pwsh" -EA SilentlyContinue | ForEach-Object {
            try {
                $cmd = (Get-CimInstance Win32_Process -Filter "ProcessId=$($_.Id)" -EA Stop).CommandLine
                if ($cmd -match "pwned|Pwn3d|Set-Content.*pwned") {
                    Write-WatchStatus "W5 PID $($_.Id)" "[FOUND] killing" "Red"
                    Write-Finding -Category 'Watchdog - Process' -Name "PID $($_.Id)" -Detail "Command: $($cmd.Substring(0,[Math]::Min(200,$cmd.Length)))" -Reason "Suspicious PowerShell process with payload keyword" -Action 'Killed' -WatchdogMode
                    Stop-Process -Id $_.Id -Force -EA SilentlyContinue
                    $killed++
                }
            } catch {}
        }
        if ($killed -eq 0) { Write-WatchStatus "W5 Suspect processes" "none OK" "Green" }
        $cycleRemoved += $killed
        
        $guidPattern = '^\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}$'
        $guidFound = 0
        foreach ($root in @($env:TEMP, $env:LOCALAPPDATA, "C:\Windows\Temp")) {
            if (-not (Test-Path $root)) { continue }
            Get-ChildItem -Path $root -Directory -Force -EA SilentlyContinue |
            Where-Object { $_.Name -match $guidPattern } |
            ForEach-Object {
                $folderPath = $_.FullName
                $ps1Files = Get-ChildItem $folderPath -Filter '*.ps1' -Force -Recurse -EA SilentlyContinue
                if ($ps1Files.Count -gt 0) {
                    $guidFound++
                    Write-WatchStatus "W6 GUID '$($_.Name)'" "[FOUND] removing" "Red"
                    Write-Finding -Category 'Watchdog - GUID Folder' -Name $_.Name -Detail "Path: $folderPath | PS1 files: $($ps1Files.Count)" -Reason "GUID-pattern folder with PS1 files re-appeared" -Action 'Removed' -WatchdogMode
                    Get-ChildItem $folderPath -Force -Recurse -EA SilentlyContinue |
                        ForEach-Object { try { $_.Attributes = 'Normal' } catch {} }
                    Remove-Item $folderPath -Recurse -Force -EA SilentlyContinue
                    $cycleRemoved++
                }
            }
        }
        if ($guidFound -eq 0) { Write-WatchStatus "W6 GUID folders" "none OK" "Green" }
        
        $startFound = 0
        foreach ($folder in $Config.StartupFolders) {
            if (-not (Test-Path $folder)) { continue }
            Get-ChildItem $folder -Force -EA SilentlyContinue |
            Where-Object { $_.Extension -in @('.ps1','.bat','.vbs','.cmd') -or (Test-FileIsDropper -FilePath $_.FullName) } |
            ForEach-Object {
                $startFound++
                Write-WatchStatus "W7 Startup '$($_.Name)'" "[FOUND] removing" "Red"
                Write-Finding -Category 'Watchdog - Startup' -Name $_.Name -Detail "Path: $($_.FullName)" -Reason "Suspicious script in startup folder" -Action 'Removed' -WatchdogMode
                $_.Attributes = 'Normal'
                Remove-Item $_.FullName -Force -EA SilentlyContinue
                $cycleRemoved++
            }
        }
        if ($startFound -eq 0) { Write-WatchStatus "W7 Startup folders" "clean OK" "Green" }
        
        $b64Found = 0
        foreach ($root in @($env:TEMP, $env:LOCALAPPDATA, "C:\Users\Public", "C:\Windows\Temp")) {
            if (-not (Test-Path $root)) { continue }
            Get-ChildItem $root -Filter '*.ps1' -Recurse -Force -EA SilentlyContinue |
            ForEach-Object {
                try {
                    $raw = Get-Content $_.FullName -Raw -Encoding UTF8 -EA Stop
                    if ($raw -match '[A-Za-z0-9+/]{100,}={0,2}') {
                        $b64Found++
                        Write-WatchStatus "W8 Base64 PS1 '$($_.Name)'" "[FOUND] removing" "Red"
                        Write-Finding -Category 'Watchdog - Base64 PS1' -Name $_.Name -Detail "Path: $($_.FullName)" -Reason "Base64-encoded PowerShell script detected" -Action 'Removed' -WatchdogMode
                        $_.Attributes = 'Normal'
                        Remove-Item $_.FullName -Force -EA SilentlyContinue
                        $cycleRemoved++
                    }
                } catch {}
            }
        }
        if ($b64Found -eq 0) { Write-WatchStatus "W8 Base64 PS1 files" "none OK" "Green" }
        
        $duration = [int]((Get-Date) - $cycleStart).TotalSeconds
        $cycleLogLine = "CYCLE $($script:CycleCount): removed=$cycleRemoved total=$($script:TotalRemoved) duration=${duration}s"
        $cycleLogLine | Out-File -FilePath $Config.WatchdogLogPath -Append -Encoding UTF8
        
        if ($cycleRemoved -gt 0) {
            Write-Host ("  +-- Cycle #{0} done ({1}s) | Removed: {2} | Total: {3}" -f `
                $script:CycleCount, $duration, $cycleRemoved, $script:TotalRemoved) -ForegroundColor Yellow
        } else {
            Write-Host ("  +-- Cycle #{0} done ({1}s) | ALL CLEAR" -f $script:CycleCount, $duration) -ForegroundColor DarkGreen
        }
        
        if ($script:WatchdogRunning) {
            $waited = 0
            while ($waited -lt $Config.WatchdogIntervalSeconds -and $script:WatchdogRunning) {
                Start-Sleep -Seconds 1
                $waited++
            }
        }
    }
    
    Write-Host "`n  Watchdog stopped. Results saved to: $($Config.WatchdogResultsPath)" -ForegroundColor Cyan
}

# ==============================================================================
# FINAL REPORT
# ==============================================================================
function Write-FinalReport {
    $line = "=" * 70
    Write-Host ""
    Write-Host "  $line" -ForegroundColor Cyan
    Write-Host "  BLUE TEAM DEFENDER - COMPLETE REPORT" -ForegroundColor Cyan
    Write-Host "  $line" -ForegroundColor Cyan
    Write-Host ""

    if ($script:Findings.Count -eq 0) {
        Write-Host "  INITIAL SCAN: No suspicious persistence entries found." -ForegroundColor Green
    } else {
        Write-Host "  INITIAL SCAN FINDINGS: $($script:Findings.Count)" -ForegroundColor Yellow
        Write-Host "  INITIAL SCAN REMOVED: $($script:Findings.Count - $script:Skipped)" -ForegroundColor Green
    }
    
    if ($script:WatchdogFindings.Count -gt 0) {
        Write-Host ""
        Write-Host "  WATCHDOG FINDINGS: $($script:WatchdogFindings.Count)" -ForegroundColor Yellow
        Write-Host "  WATCHDOG REMOVED: $($script:TotalRemoved)" -ForegroundColor Green
    }
    
    Write-Host ""
    Write-Host "  $line" -ForegroundColor Cyan
    Write-Host "  Reports saved:" -ForegroundColor Cyan
    Write-Host "    Main Report: $($Config.ReportPath)" -ForegroundColor Gray
    if ($script:WatchdogFindings.Count -gt 0 -or $script:CycleCount -gt 0) {
        Write-Host "    Watchdog Results: $($Config.WatchdogResultsPath)" -ForegroundColor Gray
    }
    Write-Host "    Watchdog Log: $($Config.WatchdogLogPath)" -ForegroundColor Gray
    Write-Host "  $line" -ForegroundColor Cyan
    Write-Host ""
}

# ==============================================================================
# MAIN ENTRY POINT
# ==============================================================================
Clear-Host

Write-Banner "BLUE TEAM DEFENDER - Integrated Security Scanner v5.0" "Cyan"
Write-Host "  Host     : $env:COMPUTERNAME" -ForegroundColor Gray
Write-Host "  User     : $env:USERNAME" -ForegroundColor Gray

$currentPrincipal = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
$IsAdmin = $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $IsAdmin) {
    Write-Host "  [!] WARNING: Not running as Administrator." -ForegroundColor Yellow
    Write-Host "      Some modules require elevation." -ForegroundColor Yellow
    Write-Host ""
} else {
    Write-Host "  Admin    : Yes" -ForegroundColor Green
}

Write-Host "  Auto-approval : ENABLED" -ForegroundColor DarkGray
Write-Host "  Main Report    : $($Config.ReportPath)" -ForegroundColor DarkGray
Write-Host ""

$reportHeader = @"
======================================================================
BLUE TEAM DEFENDER - SECURITY REPORT
Generated: $(Get-Date)
Host: $env:COMPUTERNAME
User: $env:USERNAME
Admin: $IsAdmin
======================================================================

--- INITIAL SCAN RESULTS ---

"@
$reportHeader | Out-File -FilePath $Config.ReportPath -Encoding UTF8

Install-DefensiveRegistryGuard

Write-Banner "INITIAL FULL SYSTEM SCAN" "Green"
Invoke-ScanRegistryRunKeys
Invoke-ScanStartupFolders
Invoke-ScanScheduledTasks
Invoke-ScanServices
Invoke-ScanWMISubscriptions
Invoke-ScanBITSJobs
Invoke-ScanActiveSetup
Invoke-ScanDropperScripts
Invoke-KillSuspiciousPowerShell
Invoke-RemovePayload
Invoke-ScanGuidFolders
Invoke-ScanBase64Encoded

Write-Banner "WATCHDOG PERSISTENCE OPTION" "Yellow"
Write-Host ""
Write-Host "  The watchdog will continuously monitor for persistence"
Write-Host "  re-infection every $($Config.WatchdogIntervalSeconds) seconds."
Write-Host ""
Write-Host "  Options:"
Write-Host "    [1] Run watchdog now (current session only)"
Write-Host "    [2] Run watchdog now AND install as scheduled task (auto-start on boot + tray icon + desktop shortcut)"
Write-Host "    [3] Skip watchdog (exit after report)"
Write-Host ""

$choice = Read-Host "  Enter choice (1-3)"

if ($choice -eq "1") {
    Write-Host "`n  Starting watchdog loop... Press Ctrl+C to stop.`n" -ForegroundColor Cyan
    Start-WatchdogLoop
}
elseif ($choice -eq "2") {
    Write-Host "`n  Installing scheduled task watchdog...`n" -ForegroundColor Cyan
    $watchdogPath = Install-WatchdogScheduledTask
    Start-TrayIcon -WatchdogScriptPath $watchdogPath
    Write-Host "`n  Starting watchdog in foreground mode... Press Ctrl+C to stop foreground instance." -ForegroundColor Cyan
    Write-Host "  (Scheduled task will continue after you close this window)`n" -ForegroundColor DarkGray
    Start-WatchdogLoop
}
else {
    Write-Host "`n  Skipping watchdog. Exiting..." -ForegroundColor Yellow
}

Write-FinalReport

Write-Banner "BLUE TEAM DEFENDER - COMPLETE" "Green"
