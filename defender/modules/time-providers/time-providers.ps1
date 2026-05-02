#Requires -RunAsAdministrator

$allowedProviders = @(
    "NtpClient",
    "NtpServer",
    "VMICTimeProvider"
)

$regPath = "HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders"

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== time-providers ===" -ForegroundColor Cyan

try {
    if (-not (Test-Path -Path $regPath)) {
        Write-Host "  [OK] TimeProviders-Key nicht vorhanden" -ForegroundColor Green
    } else {
        $subkeys = @(Get-ChildItem -Path $regPath -ErrorAction Stop)
        foreach ($subkey in $subkeys) {
            $providerName = $subkey.PSChildName
            if ($allowedProviders -contains $providerName) {
                Write-Host "  [OK] '$providerName' bekannt" -ForegroundColor Green
            } else {
                $findings += "Unbekannter Time Provider: '$providerName'"
                Write-Host "  [FUND] Unbekannter Time Provider: '$providerName'" -ForegroundColor Red
                try {
                    Remove-Item -Path $subkey.PSPath -Recurse -Force -ErrorAction Stop
                    $actions += "Time Provider '$providerName' entfernt"
                    Write-Host "  [OK] '$providerName' entfernt" -ForegroundColor Green
                } catch {
                    $actions += "Entfernung von '$providerName' fehlgeschlagen: $_"
                    Write-Host "  [WARN] Fehler beim Entfernen von '$providerName': $_" -ForegroundColor Yellow
                    $success = $false
                }
            }
        }
    }
} catch {
    Write-Host "  [WARN] Fehler beim Pruefen der Time Providers: $_" -ForegroundColor Yellow
    $success = $false
}

Write-Host ""

[PSCustomObject]@{
    Module   = "time-providers"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
