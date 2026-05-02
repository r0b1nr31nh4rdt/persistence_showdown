#Requires -RunAsAdministrator

$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== ifeo ===" -ForegroundColor Cyan

try {
    if (-not (Test-Path -Path $regPath)) {
        Write-Host "  [OK] IFEO key not found" -ForegroundColor Green
    } else {
        $subkeys = @(Get-ChildItem -Path $regPath -ErrorAction Stop)
        foreach ($subkey in $subkeys) {
            try {
                $props = Get-ItemProperty -Path $subkey.PSPath -ErrorAction Stop
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
                        $actions += "IFEO '$($subkey.PSChildName)': removal failed: $_"
                        Write-Host "  [WARN] Error removing Debugger value from '$($subkey.PSChildName)': $_" -ForegroundColor Yellow
                        $success = $false
                    }
                } else {
                    Write-Host "  [OK] '$($subkey.PSChildName)': no Debugger value" -ForegroundColor Green
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

Write-Host ""

[PSCustomObject]@{
    Module   = "ifeo"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
