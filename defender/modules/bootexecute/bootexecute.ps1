#Requires -RunAsAdministrator

$allowedBootExecute = @("autocheck autochk *")

$regPath   = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager"
$valueName = "BootExecute"

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== bootexecute ===" -ForegroundColor Cyan

try {
    if (-not (Test-Path -Path $regPath)) {
        Write-Host "  [WARN] Session Manager key not found" -ForegroundColor Yellow
        $success = $false
    } else {
        $props = Get-ItemProperty -Path $regPath -ErrorAction Stop
        $current = @()
        try { $current = @($props.$valueName) } catch {}

        # Check whether the current value exactly matches the expected value
        $currentStr = ($current | ForEach-Object { [string]$_ }) -join "|"
        $allowedStr = ($allowedBootExecute | ForEach-Object { [string]$_ }) -join "|"

        if ($currentStr -eq $allowedStr) {
            Write-Host "  [OK] BootExecute: default value present" -ForegroundColor Green
        } else {
            $unknownEntries = @($current | Where-Object {
                $entry = [string]$_
                $allowedBootExecute -notcontains $entry
            })

            foreach ($entry in $unknownEntries) {
                $findings += "BootExecute: unknown entry '$entry'"
                Write-Host "  [FIND] BootExecute: '$entry' not allowed" -ForegroundColor Red
            }

            try {
                Set-ItemProperty -Path $regPath -Name $valueName -Value $allowedBootExecute -Type MultiString -Force -ErrorAction Stop
                $actions += "BootExecute reset to default"
                Write-Host "  [OK] BootExecute reset to 'autocheck autochk *'" -ForegroundColor Green
            } catch {
                $actions += "Failed to reset BootExecute: $_"
                Write-Host "  [WARN] Error resetting BootExecute: $_" -ForegroundColor Yellow
                $success = $false
            }
        }
    }
} catch {
    Write-Host "  [WARN] Error checking BootExecute: $_" -ForegroundColor Yellow
    $success = $false
}

Write-Host ""

[PSCustomObject]@{
    Module   = "bootexecute"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
