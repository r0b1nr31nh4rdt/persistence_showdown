#Requires -RunAsAdministrator

$allowedMonitors = @(
    "Appmon",
    "Local Port",
    "Standard TCP/IP Port",
    "USB Monitor",
    "Virtual Port Monitor",
    "WSD Port"
)

$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors"

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== print-monitors ===" -ForegroundColor Cyan

try {
    if (-not (Test-Path -Path $regPath)) {
        Write-Host "  [OK] Print Monitors key not found" -ForegroundColor Green
    } else {
        $subkeys = @(Get-ChildItem -Path $regPath -ErrorAction Stop)
        foreach ($subkey in $subkeys) {
            $monitorName = $subkey.PSChildName
            if ($allowedMonitors -contains $monitorName) {
                Write-Host "  [OK] '$monitorName' whitelisted" -ForegroundColor Green
            } else {
                $findings += "Unknown Print Monitor: '$monitorName'"
                Write-Host "  [FIND] Unknown Print Monitor: '$monitorName'" -ForegroundColor Red
                try {
                    Remove-Item -Path $subkey.PSPath -Recurse -Force -ErrorAction Stop
                    $actions += "Print Monitor '$monitorName' removed"
                    Write-Host "  [OK] '$monitorName' removed" -ForegroundColor Green
                } catch {
                    $actions += "Failed to remove '$monitorName': $_"
                    Write-Host "  [WARN] Error removing '$monitorName': $_" -ForegroundColor Yellow
                    $success = $false
                }
            }
        }
    }
} catch {
    Write-Host "  [WARN] Error checking Print Monitors: $_" -ForegroundColor Yellow
    $success = $false
}

Write-Host ""

[PSCustomObject]@{
    Module   = "print-monitors"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
