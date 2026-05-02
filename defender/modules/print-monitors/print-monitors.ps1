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
        Write-Host "  [OK] Print Monitors-Key nicht vorhanden" -ForegroundColor Green
    } else {
        $subkeys = @(Get-ChildItem -Path $regPath -ErrorAction Stop)
        foreach ($subkey in $subkeys) {
            $monitorName = $subkey.PSChildName
            if ($allowedMonitors -contains $monitorName) {
                Write-Host "  [OK] '$monitorName' bekannt" -ForegroundColor Green
            } else {
                $findings += "Unbekannter Print Monitor: '$monitorName'"
                Write-Host "  [FUND] Unbekannter Print Monitor: '$monitorName'" -ForegroundColor Red
                try {
                    Remove-Item -Path $subkey.PSPath -Recurse -Force -ErrorAction Stop
                    $actions += "Print Monitor '$monitorName' entfernt"
                    Write-Host "  [OK] '$monitorName' entfernt" -ForegroundColor Green
                } catch {
                    $actions += "Entfernung von '$monitorName' fehlgeschlagen: $_"
                    Write-Host "  [WARN] Fehler beim Entfernen von '$monitorName': $_" -ForegroundColor Yellow
                    $success = $false
                }
            }
        }
    }
} catch {
    Write-Host "  [WARN] Fehler beim Pruefen der Print Monitors: $_" -ForegroundColor Yellow
    $success = $false
}

Write-Host ""

[PSCustomObject]@{
    Module   = "print-monitors"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
