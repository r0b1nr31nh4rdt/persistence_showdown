#Requires -RunAsAdministrator

# Baseline: Security Packages is empty on a clean system (empty string only)
$allowedSecurityPackages  = @("")
# OSConfig Security Packages: empty on baseline
$allowedOSConfigPackages  = @()

$lsaPath      = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa"
$osconfigPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\OSConfig"

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== lsa-packages ===" -ForegroundColor Cyan

# Security Packages
try {
    if (-not (Test-Path -Path $lsaPath)) {
        Write-Host "  [WARN] LSA key not found" -ForegroundColor Yellow
    } else {
        $props = Get-ItemProperty -Path $lsaPath -ErrorAction Stop
        $currentPackages = @()
        try { $currentPackages = @($props."Security Packages") } catch {}

        $unknownPackages = @($currentPackages | Where-Object {
            $pkg = [string]$_
            $pkg -ne "" -and ($allowedSecurityPackages -notcontains $pkg)
        })

        if ($unknownPackages.Count -eq 0) {
            Write-Host "  [OK] Security Packages: no unknown entries" -ForegroundColor Green
        } else {
            foreach ($pkg in $unknownPackages) {
                $findings += "Unknown LSA Security Package: '$pkg'"
                Write-Host "  [FIND] Unknown Security Package: '$pkg'" -ForegroundColor Red
            }
            try {
                Set-ItemProperty -Path $lsaPath -Name "Security Packages" -Value @("") -Type MultiString -Force -ErrorAction Stop
                $actions += "Security Packages reset to empty"
                Write-Host "  [OK] Security Packages reset" -ForegroundColor Green
            } catch {
                $actions += "Failed to reset Security Packages: $_"
                Write-Host "  [WARN] Error resetting Security Packages: $_" -ForegroundColor Yellow
                $success = $false
            }
        }
    }
} catch {
    Write-Host "  [WARN] Error checking Security Packages: $_" -ForegroundColor Yellow
    $success = $false
}

# OSConfig Security Packages
try {
    if (-not (Test-Path -Path $osconfigPath)) {
        Write-Host "  [OK] OSConfig key not found" -ForegroundColor Green
    } else {
        $props = Get-ItemProperty -Path $osconfigPath -ErrorAction Stop
        $currentOSPackages = @()
        try { $currentOSPackages = @($props."Security Packages") } catch {}

        $unknownOSPackages = @($currentOSPackages | Where-Object {
            $pkg = [string]$_
            $pkg -ne "" -and ($allowedOSConfigPackages -notcontains $pkg)
        })

        if ($unknownOSPackages.Count -eq 0) {
            Write-Host "  [OK] OSConfig Security Packages: no unknown entries" -ForegroundColor Green
        } else {
            foreach ($pkg in $unknownOSPackages) {
                $findings += "Unknown OSConfig Security Package: '$pkg'"
                Write-Host "  [FIND] Unknown OSConfig Package: '$pkg'" -ForegroundColor Red
            }
            try {
                Set-ItemProperty -Path $osconfigPath -Name "Security Packages" -Value @("") -Type MultiString -Force -ErrorAction Stop
                $actions += "OSConfig Security Packages reset"
                Write-Host "  [OK] OSConfig Security Packages reset" -ForegroundColor Green
            } catch {
                $actions += "Failed to reset OSConfig Security Packages: $_"
                Write-Host "  [WARN] Error resetting OSConfig Security Packages: $_" -ForegroundColor Yellow
                $success = $false
            }
        }
    }
} catch {
    Write-Host "  [WARN] Error checking OSConfig Security Packages: $_" -ForegroundColor Yellow
    $success = $false
}

Write-Host ""

[PSCustomObject]@{
    Module   = "lsa-packages"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
