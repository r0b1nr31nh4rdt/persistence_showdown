#Requires -RunAsAdministrator

$ifeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"
$spePath  = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit"

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== ifeo ===" -ForegroundColor Cyan

# --- IFEO: Debugger and GlobalFlag values ---
try {
    if (-not (Test-Path -Path $ifeoPath)) {
        Write-Host "  [OK] IFEO key not found" -ForegroundColor Green
    } else {
        $subkeys = @(Get-ChildItem -Path $ifeoPath -ErrorAction Stop)
        foreach ($subkey in $subkeys) {
            try {
                $props = Get-ItemProperty -Path $subkey.PSPath -ErrorAction Stop

                # Remove Debugger value (hijacks process launch)
                $debuggerProp = $props.PSObject.Properties | Where-Object { $_.Name -eq "Debugger" }
                if ($debuggerProp) {
                    $debuggerValue = [string]$debuggerProp.Value
                    $findings += "IFEO Debugger value: '$($subkey.PSChildName)' -> '$debuggerValue'"
                    Write-Host "  [FIND] IFEO '$($subkey.PSChildName)': Debugger = '$debuggerValue'" -ForegroundColor Red
                    try {
                        Remove-ItemProperty -Path $subkey.PSPath -Name "Debugger" -Force -ErrorAction Stop
                        $actions += "IFEO '$($subkey.PSChildName)': Debugger value removed"
                        Write-Host "  [OK] Debugger value removed from '$($subkey.PSChildName)'" -ForegroundColor Green
                    } catch {
                        $actions += "IFEO '$($subkey.PSChildName)': Debugger removal failed: $_"
                        Write-Host "  [WARN] Error removing Debugger value from '$($subkey.PSChildName)': $_" -ForegroundColor Yellow
                        $success = $false
                    }
                } else {
                    Write-Host "  [OK] '$($subkey.PSChildName)': no Debugger value" -ForegroundColor Green
                }

                # Remove GlobalFlag value (0x200 enables SilentProcessExit monitoring)
                $globalFlagProp = $props.PSObject.Properties | Where-Object { $_.Name -eq "GlobalFlag" }
                if ($globalFlagProp) {
                    $globalFlagValue = $globalFlagProp.Value
                    $findings += "IFEO GlobalFlag value: '$($subkey.PSChildName)' -> '$globalFlagValue'"
                    Write-Host "  [FIND] IFEO '$($subkey.PSChildName)': GlobalFlag = '$globalFlagValue'" -ForegroundColor Red
                    try {
                        Remove-ItemProperty -Path $subkey.PSPath -Name "GlobalFlag" -Force -ErrorAction Stop
                        $actions += "IFEO '$($subkey.PSChildName)': GlobalFlag value removed"
                        Write-Host "  [OK] GlobalFlag value removed from '$($subkey.PSChildName)'" -ForegroundColor Green
                    } catch {
                        $actions += "IFEO '$($subkey.PSChildName)': GlobalFlag removal failed: $_"
                        Write-Host "  [WARN] Error removing GlobalFlag value from '$($subkey.PSChildName)': $_" -ForegroundColor Yellow
                        $success = $false
                    }
                }
            } catch {
                Write-Host "  [WARN] Error reading '$($subkey.PSChildName)': $_" -ForegroundColor Yellow
                $success = $false
            }
        }
    }
} catch {
    Write-Host "  [WARN] Error checking IFEO: $_" -ForegroundColor Yellow
    $success = $false
}

# --- SilentProcessExit: remove all subkeys (none expected on clean system) ---
try {
    if (-not (Test-Path -Path $spePath)) {
        Write-Host "  [OK] SilentProcessExit key not found" -ForegroundColor Green
    } else {
        $speSubkeys = @(Get-ChildItem -Path $spePath -ErrorAction Stop)
        if ($speSubkeys.Count -eq 0) {
            Write-Host "  [OK] SilentProcessExit: no entries" -ForegroundColor Green
        } else {
            foreach ($subkey in $speSubkeys) {
                $processName = $subkey.PSChildName
                try {
                    $props = Get-ItemProperty -Path $subkey.PSPath -ErrorAction SilentlyContinue
                    $monitorProcess = ""
                    try { $monitorProcess = [string]$props.MonitorProcess } catch {}
                    $findings += "SilentProcessExit entry: '$processName' -> MonitorProcess = '$monitorProcess'"
                    Write-Host "  [FIND] SilentProcessExit '$processName': MonitorProcess = '$monitorProcess'" -ForegroundColor Red
                } catch {
                    $findings += "SilentProcessExit entry: '$processName'"
                    Write-Host "  [FIND] SilentProcessExit '$processName'" -ForegroundColor Red
                }
                try {
                    Remove-Item -Path $subkey.PSPath -Recurse -Force -ErrorAction Stop
                    $actions += "SilentProcessExit '$processName' removed"
                    Write-Host "  [OK] SilentProcessExit '$processName' removed" -ForegroundColor Green
                } catch {
                    $actions += "SilentProcessExit '$processName' removal failed: $_"
                    Write-Host "  [WARN] Error removing SilentProcessExit '$processName': $_" -ForegroundColor Yellow
                    $success = $false
                }
            }
        }
    }
} catch {
    Write-Host "  [WARN] Error checking SilentProcessExit: $_" -ForegroundColor Yellow
    $success = $false
}

Write-Host ""

[PSCustomObject]@{
    Module   = "ifeo"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
