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
        Write-Host "  [OK] TimeProviders key not found" -ForegroundColor Green
    } else {
        $subkeys = @(Get-ChildItem -Path $regPath -ErrorAction Stop)
        foreach ($subkey in $subkeys) {
            $providerName = $subkey.PSChildName
            if ($allowedProviders -contains $providerName) {
                Write-Host "  [OK] '$providerName' whitelisted" -ForegroundColor Green
            } else {
                $findings += "Unknown Time Provider: '$providerName'"
                Write-Host "  [FIND] Unknown Time Provider: '$providerName'" -ForegroundColor Red
                try {
                    Remove-Item -Path $subkey.PSPath -Recurse -Force -ErrorAction Stop
                    $actions += "Time Provider '$providerName' removed"
                    Write-Host "  [OK] '$providerName' removed" -ForegroundColor Green
                } catch {
                    $actions += "Failed to remove '$providerName': $_"
                    Write-Host "  [WARN] Error removing '$providerName': $_" -ForegroundColor Yellow
                    $success = $false
                }
            }
        }
    }
} catch {
    Write-Host "  [WARN] Error checking Time Providers: $_" -ForegroundColor Yellow
    $success = $false
}

Write-Host ""

[PSCustomObject]@{
    Module   = "time-providers"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
