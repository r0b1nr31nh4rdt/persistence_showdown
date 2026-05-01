#Requires -RunAsAdministrator
# defender.ps1 - non-interactive persistence cleanup for the Persistence Showdown VM.
# Default behavior removes suspicious persistence automatically and logs what happened.

param(
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$ConfirmPreference = 'None'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$baselinePath = Join-Path $scriptDir 'whitelist.json'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logPath = Join-Path $scriptDir "defender-log-$stamp.json"
$quarantineRoot = Join-Path $scriptDir "quarantine-$stamp"
$payloadPath = 'C:\Users\Public\Documents\pwned.txt'
$payloadContent = 'Pwn3d'

# Paste the contents of whitelist.json between the markers before submitting this
# as a single-file defender. If left empty, the script falls back to whitelist.json
# next to defender.ps1, which is useful while developing.
$EmbeddedBaselineJson = @'

'@

$script:Findings = @()
$script:QueuedFiles = @{}
$script:Baseline = $null
$script:BaselineAvailable = $false

function Write-Step { param([string]$Text) Write-Host "[*] $Text" -ForegroundColor Cyan }
function Write-OK { param([string]$Text) Write-Host "    [OK] $Text" -ForegroundColor Green }
function Write-Warn { param([string]$Text) Write-Host "    [WARN] $Text" -ForegroundColor Yellow }
function Write-Removed { param([string]$Text) Write-Host "    [REMOVED] $Text" -ForegroundColor Magenta }

function ConvertTo-BaselineValue {
    param($Value)
    if ($null -eq $Value) { return '' }
    if ($Value -is [byte[]]) {
        return (($Value | ForEach-Object { $_.ToString('X2') }) -join '')
    }
    if ($Value -is [array]) {
        return (@($Value | ForEach-Object { ConvertTo-BaselineValue $_ }) -join '|')
    }
    return [string]$Value
}

function Get-PropValue {
    param($InputObject, [string]$Name, $Default = '')
    if ($null -eq $InputObject) { return $Default }
    $prop = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $Default }
    return $prop.Value
}

function ConvertTo-ComparableString {
    param($Value)
    if ($null -eq $Value) { return '' }
    try { return ($Value | ConvertTo-Json -Depth 20 -Compress) } catch { return [string]$Value }
}

function Add-Finding {
    param(
        [string]$Kind,
        [string]$Location,
        [string]$Name,
        [string]$CommandLine,
        [int]$Score,
        [string[]]$Reasons,
        [string]$Action,
        [string]$Status
    )

    $script:Findings += [ordered]@{
        TimeUtc = (Get-Date).ToUniversalTime().ToString('o')
        Kind = $Kind
        Location = $Location
        Name = $Name
        CommandLine = $CommandLine
        Score = $Score
        Reasons = @($Reasons)
        Action = $Action
        Status = $Status
    }
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
    } catch { Write-Warn "Could not read registry values from '$Path': $_" }
    return $out
}

function Get-RegSubKeys {
    param([string[]]$Paths)
    $items = @()
    foreach ($path in $Paths) {
        try {
            if (Test-Path $path) {
                $items += @(Get-ChildItem -Path $path -ErrorAction SilentlyContinue |
                    Sort-Object PSChildName |
                    ForEach-Object {
                        [ordered]@{
                            Path = "$path\$($_.PSChildName)"
                            PSPath = $_.PSPath
                            Name = $_.PSChildName
                            Values = Get-RegValues $_.PSPath
                        }
                    })
            }
        } catch { Write-Warn "Could not read registry subkeys from '$path': $_" }
    }
    return @($items)
}

function Get-FileHashSafe {
    param([string]$Path)
    try {
        if (Test-Path -LiteralPath $Path) {
            return (Get-FileHash -LiteralPath $Path -Algorithm SHA256 -ErrorAction Stop).Hash
        }
    } catch {}
    return ''
}

function Get-TextPreview {
    param([string]$Path)
    try {
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
        if ($item.Length -gt 1048576) { return '' }
        if ($item.Extension -notmatch '^\.(ps1|bat|cmd|vbs|js|jse|wsf|hta|txt)$') { return '' }
        return (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop)
    } catch { return '' }
}

function Get-BaselineSection {
    param([string]$Name)
    if (-not $script:BaselineAvailable) { return $null }
    $prop = $script:Baseline.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $null }
    return $prop.Value
}

function Get-BaselineRegStatus {
    param([string]$Section, [string]$Name, [string]$CurrentValue)
    if (-not $script:BaselineAvailable) { return 'NoBaseline' }
    $base = Get-BaselineSection $Section
    if ($null -eq $base) { return 'New' }
    $prop = $base.PSObject.Properties[$Name]
    if ($null -eq $prop) { return 'New' }
    if ([string]$prop.Value -eq [string]$CurrentValue) { return 'Known' }
    return 'Changed'
}

function Get-BaselineFileStatus {
    param([string]$Section, [string]$FullName, [string]$Hash)
    if (-not $script:BaselineAvailable) { return 'NoBaseline' }
    $base = Get-BaselineSection $Section
    if ($null -eq $base) { return 'New' }
    foreach ($item in @($base)) {
        if ([string](Get-PropValue $item 'FullName') -eq $FullName) {
            if ([string](Get-PropValue $item 'SHA256') -eq $Hash) { return 'Known' }
            return 'Changed'
        }
    }
    return 'New'
}

function Get-BaselineShortcutStatus {
    param($Shortcut)
    if (-not $script:BaselineAvailable) { return 'NoBaseline' }
    $base = Get-BaselineSection 'Shortcuts'
    if ($null -eq $base) { return 'New' }
    foreach ($item in @($base)) {
        if ([string](Get-PropValue $item 'FullName') -eq [string]$Shortcut.FullName) {
            if ([string](Get-PropValue $item 'TargetPath') -eq [string]$Shortcut.TargetPath -and
                [string](Get-PropValue $item 'Arguments') -eq [string]$Shortcut.Arguments) {
                return 'Known'
            }
            return 'Changed'
        }
    }
    return 'New'
}

function Get-BaselineTaskStatus {
    param($Task, [string]$ActionText)
    if (-not $script:BaselineAvailable) { return 'NoBaseline' }
    $base = Get-BaselineSection 'ScheduledTasks'
    if ($null -eq $base) { return 'New' }
    foreach ($item in @($base)) {
        if ([string](Get-PropValue $item 'TaskPath') -eq [string]$Task.TaskPath -and
            [string](Get-PropValue $item 'TaskName') -eq [string]$Task.TaskName) {
            $baseActionText = (@(Get-PropValue $item 'Actions' @()) | ForEach-Object {
                '{0} {1} {2}' -f (Get-PropValue $_ 'Execute'), (Get-PropValue $_ 'Arguments'), (Get-PropValue $_ 'WorkingDirectory')
            }) -join ' ; '
            if ($baseActionText -eq $ActionText) { return 'Known' }
            return 'Changed'
        }
    }
    return 'New'
}

function Get-BaselineServiceStatus {
    param($Service)
    if (-not $script:BaselineAvailable) { return 'NoBaseline' }
    $base = Get-BaselineSection 'Services'
    if ($null -eq $base) { return 'New' }
    foreach ($item in @($base)) {
        if ([string](Get-PropValue $item 'Name') -eq [string]$Service.Name) {
            if ([string](Get-PropValue $item 'PathName') -eq [string]$Service.PathName -and
                [string](Get-PropValue $item 'StartName') -eq [string]$Service.StartName) {
                return 'Known'
            }
            return 'Changed'
        }
    }
    return 'New'
}

function Get-BaselineSubKeyStatus {
    param([string]$Section, [string]$Path, $Values)
    if (-not $script:BaselineAvailable) { return 'NoBaseline' }
    $base = Get-BaselineSection $Section
    if ($null -eq $base) { return 'New' }
    $prop = $base.PSObject.Properties[$Path]
    if ($null -eq $prop) { return 'New' }
    if ((ConvertTo-ComparableString $prop.Value) -eq (ConvertTo-ComparableString $Values)) { return 'Known' }
    return 'Changed'
}

function Expand-PathText {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    return [Environment]::ExpandEnvironmentVariables($Text.Trim('"', "'"))
}

function Get-ReferencedPaths {
    param([string]$Text)
    $expanded = [Environment]::ExpandEnvironmentVariables([string]$Text)
    $results = @()
    $patterns = @(
        '"(?<p>[A-Za-z]:\\[^"]+\.(?:ps1|bat|cmd|vbs|js|jse|wsf|hta|exe|dll|scr))"',
        '''(?<p>[A-Za-z]:\\[^'']+\.(?:ps1|bat|cmd|vbs|js|jse|wsf|hta|exe|dll|scr))''',
        '(?<p>[A-Za-z]:\\[^\s"''<>|]+\.(?:ps1|bat|cmd|vbs|js|jse|wsf|hta|exe|dll|scr))'
    )
    foreach ($pattern in $patterns) {
        foreach ($match in [regex]::Matches($expanded, $pattern, [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)) {
            $results += (Expand-PathText $match.Groups['p'].Value)
        }
    }
    return @($results | Where-Object { $_ } | Sort-Object -Unique)
}

function Test-UserWritablePath {
    param([string]$Path)
    $p = (Expand-PathText $Path).ToLowerInvariant()
    return (
        $p -match '\\appdata\\' -or
        $p -match '\\downloads\\' -or
        $p -match '\\desktop\\' -or
        $p -match '\\documents\\' -or
        $p -match '\\users\\public\\' -or
        $p -match '\\temp\\'
    )
}

function Test-ProgramDataPath {
    param([string]$Path)
    return ((Expand-PathText $Path).ToLowerInvariant().StartsWith('c:\programdata\'))
}

function Test-ProtectedPath {
    param([string]$Path)
    $p = (Expand-PathText $Path).ToLowerInvariant()
    $windows = [Environment]::ExpandEnvironmentVariables('%WINDIR%').ToLowerInvariant()
    $programFiles = [Environment]::GetEnvironmentVariable('ProgramFiles')
    if ($programFiles) { $programFiles = $programFiles.ToLowerInvariant() } else { $programFiles = '' }
    $programFilesX86 = ''
    $programFilesX86Value = [Environment]::GetEnvironmentVariable('ProgramFiles(x86)')
    if ($programFilesX86Value) { $programFilesX86 = $programFilesX86Value.ToLowerInvariant() }
    return ($p.StartsWith($windows) -or ($programFiles -and $p.StartsWith($programFiles)) -or ($programFilesX86 -and $p.StartsWith($programFilesX86)))
}

function Test-InterpreterPath {
    param([string]$Path)
    $leaf = Split-Path -Leaf (Expand-PathText $Path)
    return ($leaf -match '^(powershell|pwsh|cmd|wscript|cscript|mshta|rundll32|regsvr32)\.exe$')
}

function New-SuspicionAssessment {
    param(
        [string]$Name,
        [string]$CommandLine,
        [string]$Context,
        [string]$BaselineStatus,
        [int]$ExtraScore = 0,
        [string[]]$ExtraReasons = @()
    )

    $score = 0
    $reasons = @()
    $text = "$Name $CommandLine"

    if ($BaselineStatus -in @('New', 'Changed')) {
        $score += 45
        $reasons += "new or changed compared with clean baseline ($BaselineStatus)"
    } elseif ($BaselineStatus -eq 'NoBaseline') {
        $reasons += 'no clean baseline available, using heuristics only'
    }

    if ($text -match '(?i)pwn3d|pwned\.txt|\\users\\public\\documents\\pwned') {
        $score += 100
        $reasons += 'direct reference to the project payload'
    }

    if ($text -match '(?i)\b(powershell|pwsh|cmd|wscript|cscript|mshta|rundll32|regsvr32)\.exe\b') {
        $score += 25
        $reasons += 'launches through a common script/interpreter host'
    }

    if ($text -match '(?i)\.(ps1|bat|cmd|vbs|js|jse|wsf|hta)(\s|$|"|'')') {
        $score += 20
        $reasons += 'launches a script file'
    }

    $paths = @(Get-ReferencedPaths $text)
    $hasUserWritablePath = $false
    $hasProgramDataPath = $false
    foreach ($path in $paths) {
        if (Test-UserWritablePath $path) { $hasUserWritablePath = $true }
        if (Test-ProgramDataPath $path) { $hasProgramDataPath = $true }
    }
    if ($hasUserWritablePath) {
        $score += 30
        $reasons += 'references a user-writable path'
    }
    if ($hasProgramDataPath) {
        $score += 15
        $reasons += 'references ProgramData'
    }

    if ($Name -match '(?i)(pwn|payload|backdoor|persist|updater|updatecheck|winupdate|securityhealth|onedriveupdate)') {
        $score += 10
        $reasons += 'name looks vague, misleading, or persistence-related'
    }

    if ($Context -match '(?i)Startup|OfficeStartup|PowerShellProfile' -and $text -match '(?i)\.(ps1|bat|cmd|vbs|js|hta)') {
        $score += 15
        $reasons += 'script located in an autostart location'
    }

    if ($ExtraScore -gt 0) {
        $score += $ExtraScore
        $reasons += $ExtraReasons
    }

    return [pscustomobject]@{
        Score = $score
        Reasons = @($reasons | Where-Object { $_ } | Select-Object -Unique)
        ReferencedPaths = $paths
        BaselineStatus = $BaselineStatus
    }
}

function Test-ShouldClean {
    param($Assessment)
    $hasPayloadIndicator = $false
    foreach ($reason in @($Assessment.Reasons)) {
        if ($reason -eq 'direct reference to the project payload') { $hasPayloadIndicator = $true }
    }
    if ((Get-PropValue $Assessment 'BaselineStatus') -eq 'Known' -and -not $hasPayloadIndicator) { return $false }
    if ($hasPayloadIndicator) { return $true }
    if ($Assessment.Score -ge 80) { return $true }
    return $false
}

function Add-ReferencedFilesForQuarantine {
    param([string]$CommandLine, [string]$Reason)
    foreach ($path in @(Get-ReferencedPaths $CommandLine)) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        if (Test-InterpreterPath $path) { continue }
        if (-not (Test-UserWritablePath $path) -and -not (Test-ProgramDataPath $path)) { continue }
        if (-not $script:QueuedFiles.ContainsKey($path)) {
            $script:QueuedFiles[$path] = $Reason
        }
    }
}

function Move-ToQuarantine {
    param([string]$Path, [string]$Reason, [switch]$AllowProtected)
    try {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return }
        $resolved = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).Path
        if ((Test-ProtectedPath $resolved) -and -not $AllowProtected) {
            Add-Finding 'File' $resolved (Split-Path -Leaf $resolved) '' 0 @($Reason, 'protected path skipped') 'Skip quarantine' 'Skipped'
            return
        }
        $safeName = (($resolved -replace '[:\\\/\s]+', '_') -replace '[^A-Za-z0-9._-]', '_').Trim('_')
        if (-not $safeName) { $safeName = [guid]::NewGuid().ToString() }
        if (-not $DryRun) {
            New-Item -ItemType Directory -Path $quarantineRoot -Force | Out-Null
            $dest = Join-Path $quarantineRoot $safeName
            if (Test-Path -LiteralPath $dest) {
                $dest = Join-Path $quarantineRoot ("{0}-{1}" -f ([guid]::NewGuid().ToString('N')), $safeName)
            }
            Move-Item -LiteralPath $resolved -Destination $dest -Force -ErrorAction Stop
        }
        $status = if ($DryRun) { 'DryRun' } else { 'Quarantined' }
        Add-Finding 'File' $resolved (Split-Path -Leaf $resolved) '' 100 @($Reason) 'Move file to quarantine' $status
        Write-Removed "$status file: $resolved"
    } catch {
        Add-Finding 'File' $Path (Split-Path -Leaf $Path) '' 0 @($Reason, "$_") 'Move file to quarantine' 'Failed'
        Write-Warn "Could not quarantine '$Path': $_"
    }
}

function Get-ShortcutInfo {
    param([string]$Path)
    $info = [ordered]@{
        FullName = $Path
        TargetPath = ''
        Arguments = ''
        WorkingDirectory = ''
        IconLocation = ''
        WindowStyle = ''
    }
    try {
        $shell = New-Object -ComObject WScript.Shell
        $lnk = $shell.CreateShortcut($Path)
        $info.TargetPath = [string]$lnk.TargetPath
        $info.Arguments = [string]$lnk.Arguments
        $info.WorkingDirectory = [string]$lnk.WorkingDirectory
        $info.IconLocation = [string]$lnk.IconLocation
        $info.WindowStyle = [string]$lnk.WindowStyle
    } catch { Write-Warn "Could not read shortcut '$Path': $_" }
    return $info
}

function Restore-ShortcutFromBaseline {
    param([string]$FullName)
    $base = Get-BaselineSection 'Shortcuts'
    if ($null -eq $base) { return $false }
    foreach ($item in @($base)) {
        if ([string](Get-PropValue $item 'FullName') -eq $FullName) {
            if (-not $DryRun) {
                $shell = New-Object -ComObject WScript.Shell
                $lnk = $shell.CreateShortcut($FullName)
                $lnk.TargetPath = [string](Get-PropValue $item 'TargetPath')
                $lnk.Arguments = [string](Get-PropValue $item 'Arguments')
                $lnk.WorkingDirectory = [string](Get-PropValue $item 'WorkingDirectory')
                $lnk.IconLocation = [string](Get-PropValue $item 'IconLocation')
                $windowStyle = [int]([string](Get-PropValue $item 'WindowStyle' '1'))
                if ($windowStyle -gt 0) { $lnk.WindowStyle = $windowStyle }
                $lnk.Save()
            }
            return $true
        }
    }
    return $false
}

function Invoke-RegistryValueCleanup {
    param(
        [string]$Kind,
        [string]$Section,
        [string]$Path,
        [int]$ExtraScore = 0,
        [string[]]$ExtraReasons = @()
    )

    $values = Get-RegValues $Path
    foreach ($name in @($values.Keys)) {
        $value = [string]$values[$name]
        $baselineStatus = Get-BaselineRegStatus $Section $name $value
        $effectiveExtraScore = if ($baselineStatus -eq 'Known') { 0 } else { $ExtraScore }
        $effectiveExtraReasons = if ($baselineStatus -eq 'Known') { @() } else { $ExtraReasons }
        $assessment = New-SuspicionAssessment $name $value $Section $baselineStatus $effectiveExtraScore $effectiveExtraReasons
        if (-not (Test-ShouldClean $assessment)) { continue }

        $status = 'Removed'
        try {
            if (-not $DryRun) {
                Remove-ItemProperty -Path $Path -Name $name -Force -ErrorAction Stop
            } else {
                $status = 'DryRun'
            }
            Add-Finding $Kind $Path $name $value $assessment.Score $assessment.Reasons 'Remove registry value' $status
            Add-ReferencedFilesForQuarantine $value "$Kind '$name' referenced a suspicious file"
            Write-Removed "$status registry value: $Path -> $name"
        } catch {
            Add-Finding $Kind $Path $name $value $assessment.Score $assessment.Reasons 'Remove registry value' 'Failed'
            Write-Warn "Could not remove registry value '$Path\$name': $_"
        }
    }
}

function Invoke-RegistrySubKeyCleanup {
    param(
        [string]$Kind,
        [string]$Section,
        [string[]]$Paths,
        [int]$ExtraScore = 0,
        [string[]]$ExtraReasons = @()
    )

    foreach ($item in @(Get-RegSubKeys $Paths)) {
        $commandText = (@($item.Values.Keys) | ForEach-Object { "$_=$($item.Values[$_])" }) -join ' '
        $baselineStatus = Get-BaselineSubKeyStatus $Section $item.Path $item.Values
        $effectiveExtraScore = if ($baselineStatus -eq 'Known') { 0 } else { $ExtraScore }
        $effectiveExtraReasons = if ($baselineStatus -eq 'Known') { @() } else { $ExtraReasons }
        $assessment = New-SuspicionAssessment $item.Name $commandText $Section $baselineStatus $effectiveExtraScore $effectiveExtraReasons
        if (-not (Test-ShouldClean $assessment)) { continue }

        $status = 'Removed'
        try {
            if (-not $DryRun) {
                Remove-Item -Path $item.PSPath -Recurse -Force -ErrorAction Stop
            } else {
                $status = 'DryRun'
            }
            Add-Finding $Kind $item.Path $item.Name $commandText $assessment.Score $assessment.Reasons 'Remove registry key' $status
            Add-ReferencedFilesForQuarantine $commandText "$Kind '$($item.Name)' referenced a suspicious file"
            Write-Removed "$status registry key: $($item.Path)"
        } catch {
            Add-Finding $Kind $item.Path $item.Name $commandText $assessment.Score $assessment.Reasons 'Remove registry key' 'Failed'
            Write-Warn "Could not remove registry key '$($item.Path)': $_"
        }
    }
}

function Invoke-StartupFolderCleanup {
    param([string]$Section, [string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { return }
    Get-ChildItem -LiteralPath $Path -File -ErrorAction SilentlyContinue | Sort-Object FullName | ForEach-Object {
        $hash = Get-FileHashSafe $_.FullName
        $baselineStatus = Get-BaselineFileStatus $Section $_.FullName $hash
        $commandText = $_.FullName
        if ($_.Extension -ieq '.lnk') {
            $shortcut = Get-ShortcutInfo $_.FullName
            $commandText = "$($shortcut.TargetPath) $($shortcut.Arguments)"
        } else {
            $commandText = "$($_.FullName) $(Get-TextPreview $_.FullName)"
        }
        $assessment = New-SuspicionAssessment $_.Name $commandText 'Startup' $baselineStatus 10 @('file is in a Startup folder')
        if (-not (Test-ShouldClean $assessment)) { return }

        Move-ToQuarantine $_.FullName "suspicious Startup folder item: $($_.Name)"
        Add-ReferencedFilesForQuarantine $commandText "Startup item '$($_.Name)' referenced a suspicious file"
    }
}

function Invoke-ScheduledTaskCleanup {
    try {
        Get-ScheduledTask -ErrorAction SilentlyContinue | Sort-Object TaskPath, TaskName | ForEach-Object {
            $task = $_
            $actionText = (@($task.Actions) | ForEach-Object {
                '{0} {1} {2}' -f (Get-PropValue $_ 'Execute'), (Get-PropValue $_ 'Arguments'), (Get-PropValue $_ 'WorkingDirectory')
            }) -join ' ; '
            $hidden = [bool](Get-PropValue (Get-PropValue $task 'Settings' $null) 'Hidden' $false)
            $baselineStatus = Get-BaselineTaskStatus $task $actionText
            $extraScore = 0
            $extraReasons = @()
            if ($hidden -and $baselineStatus -ne 'Known') {
                $extraScore += 15
                $extraReasons += 'task is hidden'
            }
            $assessment = New-SuspicionAssessment $task.TaskName $actionText 'ScheduledTask' $baselineStatus $extraScore $extraReasons
            if (-not (Test-ShouldClean $assessment)) { return }

            $status = 'Removed'
            try {
                if (-not $DryRun) {
                    Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false -ErrorAction Stop
                } else {
                    $status = 'DryRun'
                }
                Add-Finding 'ScheduledTask' $task.TaskPath $task.TaskName $actionText $assessment.Score $assessment.Reasons 'Unregister scheduled task' $status
                Add-ReferencedFilesForQuarantine $actionText "scheduled task '$($task.TaskName)' referenced a suspicious file"
                Write-Removed "$status scheduled task: $($task.TaskPath)$($task.TaskName)"
            } catch {
                Add-Finding 'ScheduledTask' $task.TaskPath $task.TaskName $actionText $assessment.Score $assessment.Reasons 'Unregister scheduled task' 'Failed'
                Write-Warn "Could not remove scheduled task '$($task.TaskPath)$($task.TaskName)': $_"
            }
        }
    } catch { Write-Warn "Could not enumerate scheduled tasks: $_" }
}

function Invoke-ServiceCleanup {
    try {
        Get-WmiObject Win32_Service -ErrorAction Stop |
            Where-Object { $_.StartMode -in @('Auto', 'Manual') } |
            Sort-Object Name |
            ForEach-Object {
                $svc = $_
                $baselineStatus = Get-BaselineServiceStatus $svc
                $assessment = New-SuspicionAssessment $svc.Name $svc.PathName 'Service' $baselineStatus 0 @()
                if (-not (Test-ShouldClean $assessment)) { return }

                $action = if ($baselineStatus -eq 'Changed') { 'Disable suspicious service' } else { 'Delete suspicious service' }
                $status = if ($DryRun) { 'DryRun' } else { 'Removed' }
                try {
                    if (-not $DryRun) {
                        Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
                        if ($baselineStatus -eq 'Changed') {
                            Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction Stop
                        } else {
                            & sc.exe delete $svc.Name | Out-Null
                        }
                    }
                    Add-Finding 'Service' 'Win32_Service' $svc.Name $svc.PathName $assessment.Score $assessment.Reasons $action $status
                    Add-ReferencedFilesForQuarantine $svc.PathName "service '$($svc.Name)' referenced a suspicious file"
                    Write-Removed "$status service: $($svc.Name)"
                } catch {
                    Add-Finding 'Service' 'Win32_Service' $svc.Name $svc.PathName $assessment.Score $assessment.Reasons $action 'Failed'
                    Write-Warn "Could not clean service '$($svc.Name)': $_"
                }
            }
    } catch { Write-Warn "Could not enumerate services: $_" }
}

function Invoke-OfficeStartupCleanup {
    $paths = @(
        (Join-Path $env:APPDATA 'Microsoft\Word\STARTUP'),
        (Join-Path $env:APPDATA 'Microsoft\Excel\XLSTART'),
        (Join-Path $env:ProgramFiles 'Microsoft Office\root\Office16\STARTUP'),
        (Join-Path ${env:ProgramFiles(x86)} 'Microsoft Office\root\Office16\STARTUP')
    ) | Where-Object { $_ }

    foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path)) { continue }
        Get-ChildItem -LiteralPath $path -File -ErrorAction SilentlyContinue | Sort-Object FullName | ForEach-Object {
            $hash = Get-FileHashSafe $_.FullName
            $baselineStatus = Get-BaselineFileStatus 'OfficeStartupFiles' $_.FullName $hash
            $commandText = "$($_.FullName) $(Get-TextPreview $_.FullName)"
            $assessment = New-SuspicionAssessment $_.Name $commandText 'OfficeStartup' $baselineStatus 15 @('file is in an Office Startup folder')
            if (Test-ShouldClean $assessment) {
                Move-ToQuarantine $_.FullName "suspicious Office Startup file: $($_.Name)"
            }
        }
    }
}

function Invoke-PowerShellProfileCleanup {
    $paths = @(
        "$PSHOME\profile.ps1",
        "$PSHOME\Microsoft.PowerShell_profile.ps1",
        (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\profile.ps1'),
        (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),
        (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\profile.ps1'),
        (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Microsoft.PowerShell_profile.ps1'),
        "$env:ProgramFiles\PowerShell\7\profile.ps1",
        "${env:ProgramFiles(x86)}\PowerShell\7\profile.ps1"
    ) | Where-Object { $_ } | Sort-Object -Unique

    foreach ($path in $paths) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { continue }
        $hash = Get-FileHashSafe $path
        $baselineStatus = Get-BaselineFileStatus 'PowerShellProfiles' $path $hash
        $content = Get-TextPreview $path
        $assessment = New-SuspicionAssessment (Split-Path -Leaf $path) "$path $content" 'PowerShellProfile' $baselineStatus 0 @()
        if (Test-ShouldClean $assessment) {
            $allowProtected = ($content -match '(?i)pwn3d|pwned\.txt|\\users\\public\\documents\\pwned')
            Move-ToQuarantine $path 'suspicious PowerShell profile' -AllowProtected:$allowProtected
        }
    }
}

function Invoke-ShortcutCleanup {
    $desktopPaths = @(
        [Environment]::GetFolderPath('Desktop'),
        'C:\Users\Public\Desktop'
    ) | Where-Object { $_ }
    $startMenuPaths = @(
        (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu'),
        'C:\ProgramData\Microsoft\Windows\Start Menu'
    )

    foreach ($root in @($desktopPaths + $startMenuPaths)) {
        if (-not (Test-Path -LiteralPath $root)) { continue }
        Get-ChildItem -LiteralPath $root -Filter '*.lnk' -File -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName | ForEach-Object {
            $shortcut = Get-ShortcutInfo $_.FullName
            $baselineStatus = Get-BaselineShortcutStatus $shortcut
            $commandText = "$($shortcut.TargetPath) $($shortcut.Arguments)"
            $assessment = New-SuspicionAssessment $_.Name $commandText 'Shortcut' $baselineStatus 0 @()
            if (-not (Test-ShouldClean $assessment)) { return }

            if ($baselineStatus -eq 'Changed' -and (Restore-ShortcutFromBaseline $_.FullName)) {
                Add-Finding 'Shortcut' $_.FullName $_.Name $commandText $assessment.Score $assessment.Reasons 'Restore shortcut from baseline' $(if ($DryRun) { 'DryRun' } else { 'Restored' })
                Write-Removed "Restored shortcut from baseline: $($_.FullName)"
            } else {
                Move-ToQuarantine $_.FullName "suspicious shortcut: $($_.Name)"
            }
            Add-ReferencedFilesForQuarantine $commandText "shortcut '$($_.Name)' referenced a suspicious file"
        }
    }
}

Write-Step "Loading clean baseline"
if (-not [string]::IsNullOrWhiteSpace($EmbeddedBaselineJson)) {
    try {
        $script:Baseline = $EmbeddedBaselineJson | ConvertFrom-Json -ErrorAction Stop
        $script:BaselineAvailable = $true
        Write-OK 'Loaded embedded baseline'
    } catch {
        Write-Warn "Could not load embedded baseline. Continuing with heuristics only: $_"
    }
} elseif (Test-Path -LiteralPath $baselinePath) {
    try {
        $script:Baseline = Get-Content -LiteralPath $baselinePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        $script:BaselineAvailable = $true
        Write-OK "Loaded $baselinePath"
    } catch {
        Write-Warn "Could not load whitelist.json. Continuing with heuristics only: $_"
    }
} else {
    Write-Warn "No whitelist.json found. Continuing with heuristics only."
}

Write-Step "Checking registry Run and RunOnce keys"
$runLocations = @(
    [ordered]@{ Kind = 'RegistryRun'; Section = 'RunHKLM'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' },
    [ordered]@{ Kind = 'RegistryRun'; Section = 'RunHKCU'; Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' },
    [ordered]@{ Kind = 'RegistryRunOnce'; Section = 'RunOnceHKLM'; Path = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' },
    [ordered]@{ Kind = 'RegistryRunOnce'; Section = 'RunOnceHKCU'; Path = 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce' },
    [ordered]@{ Kind = 'RegistryRunWow6432Node'; Section = 'RunWow6432NodeHKLM'; Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' },
    [ordered]@{ Kind = 'RegistryRunOnceWow6432Node'; Section = 'RunOnceWow6432NodeHKLM'; Path = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce' },
    [ordered]@{ Kind = 'RegistryRunWow6432Node'; Section = 'RunWow6432NodeHKCU'; Path = 'HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run' },
    [ordered]@{ Kind = 'RegistryRunOnceWow6432Node'; Section = 'RunOnceWow6432NodeHKCU'; Path = 'HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce' }
)
foreach ($loc in $runLocations) {
    Invoke-RegistryValueCleanup $loc.Kind $loc.Section $loc.Path
}

Write-Step "Checking Startup folders"
$startupUser = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
$startupPublic = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup'
Invoke-StartupFolderCleanup 'StartupUser' $startupUser
Invoke-StartupFolderCleanup 'StartupPublic' $startupPublic

Write-Step "Checking scheduled tasks"
Invoke-ScheduledTaskCleanup

Write-Step "Checking Windows services"
Invoke-ServiceCleanup

Write-Step "Checking Microsoft Edge forced extension policy"
Invoke-RegistryValueCleanup 'EdgePolicy' 'EdgeExtensionInstallForcelistHKLM' 'HKLM:\Software\Policies\Microsoft\Edge\ExtensionInstallForcelist' 80 @('forced Edge extension policy not in clean baseline')
Invoke-RegistryValueCleanup 'EdgePolicy' 'EdgeExtensionInstallForcelistHKCU' 'HKCU:\Software\Policies\Microsoft\Edge\ExtensionInstallForcelist' 80 @('forced Edge extension policy not in clean baseline')
Invoke-RegistryValueCleanup 'EdgePolicy' 'EdgeExtensionSettingsHKLM' 'HKLM:\Software\Policies\Microsoft\Edge\ExtensionSettings'
Invoke-RegistryValueCleanup 'EdgePolicy' 'EdgeExtensionSettingsHKCU' 'HKCU:\Software\Policies\Microsoft\Edge\ExtensionSettings'

Write-Step "Checking Office Startup folders and add-ins"
Invoke-OfficeStartupCleanup
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
Invoke-RegistrySubKeyCleanup 'OfficeAddin' 'OfficeAddins' $officeAddinPaths 15 @('Office add-in autoload location')
Invoke-RegistrySubKeyCleanup 'COMAddin' 'COMAddins' @(
    'HKLM:\Software\Microsoft\Office\Addins',
    'HKCU:\Software\Microsoft\Office\Addins',
    'HKLM:\Software\WOW6432Node\Microsoft\Office\Addins',
    'HKCU:\Software\WOW6432Node\Microsoft\Office\Addins'
) 15 @('COM add-in autoload location')

Write-Step "Checking PowerShell profiles"
Invoke-PowerShellProfileCleanup

Write-Step "Checking shortcuts"
Invoke-ShortcutCleanup

Write-Step "Checking Active Setup"
Invoke-RegistrySubKeyCleanup 'ActiveSetup' 'ActiveSetup' @(
    'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components',
    'HKCU:\SOFTWARE\Microsoft\Active Setup\Installed Components',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Active Setup\Installed Components',
    'HKCU:\SOFTWARE\WOW6432Node\Microsoft\Active Setup\Installed Components'
) 20 @('Active Setup StubPath autostart location')

Write-Step "Quarantining referenced helper files"
foreach ($path in @($script:QueuedFiles.Keys)) {
    Move-ToQuarantine $path $script:QueuedFiles[$path]
}

Write-Step "Removing project proof file if present"
try {
    if (Test-Path -LiteralPath $payloadPath -PathType Leaf) {
        $content = Get-Content -LiteralPath $payloadPath -Raw -ErrorAction SilentlyContinue
        if (($content.Trim()) -eq $payloadContent) {
            if (-not $DryRun) {
                Remove-Item -LiteralPath $payloadPath -Force -ErrorAction Stop
            }
            $status = if ($DryRun) { 'DryRun' } else { 'Removed' }
            Add-Finding 'PayloadFile' $payloadPath 'pwned.txt' '' 100 @('project proof file contained Pwn3d') 'Remove project proof file' $status
            Write-Removed "$status payload proof file: $payloadPath"
        } else {
            Write-Warn "$payloadPath exists but does not contain the expected project payload text; left untouched."
        }
    } else {
        Write-OK 'Project proof file not present.'
    }
} catch {
    Add-Finding 'PayloadFile' $payloadPath 'pwned.txt' '' 100 @('project proof file cleanup failed', "$_") 'Remove project proof file' 'Failed'
    Write-Warn "Could not remove project proof file: $_"
}

Write-Step "Writing log"
try {
    $summary = [ordered]@{
        TimeUtc = (Get-Date).ToUniversalTime().ToString('o')
        DryRun = [bool]$DryRun
        BaselinePath = $baselinePath
        BaselineLoaded = [bool]$script:BaselineAvailable
        QuarantinePath = if (Test-Path -LiteralPath $quarantineRoot) { $quarantineRoot } else { '' }
        FindingCount = @($script:Findings).Count
        Findings = @($script:Findings)
    }
    $summary | ConvertTo-Json -Depth 20 | Set-Content -LiteralPath $logPath -Encoding UTF8
    Write-OK "Log saved: $logPath"
} catch {
    Write-Warn "Could not write defender log: $_"
}

Write-Host ""
Write-Host ("[DONE] Defender completed. Findings handled: {0}" -f @($script:Findings).Count) -ForegroundColor Green
