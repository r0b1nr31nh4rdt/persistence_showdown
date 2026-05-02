#Requires -RunAsAdministrator

# Baseline: Security Packages ist auf sauberem System leer (nur Leerstring)
$allowedSecurityPackages  = @("")
# OSConfig Security Packages: auf Baseline leer
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
        Write-Host "  [WARN] LSA-Key nicht gefunden" -ForegroundColor Yellow
    } else {
        $props = Get-ItemProperty -Path $lsaPath -ErrorAction Stop
        $currentPackages = @()
        try { $currentPackages = @($props."Security Packages") } catch {}

        $unknownPackages = @($currentPackages | Where-Object {
            $pkg = [string]$_
            $pkg -ne "" -and ($allowedSecurityPackages -notcontains $pkg)
        })

        if ($unknownPackages.Count -eq 0) {
            Write-Host "  [OK] Security Packages: keine unbekannten Eintraege" -ForegroundColor Green
        } else {
            foreach ($pkg in $unknownPackages) {
                $findings += "Unbekanntes LSA Security Package: '$pkg'"
                Write-Host "  [FUND] Unbekanntes Security Package: '$pkg'" -ForegroundColor Red
            }
            try {
                Set-ItemProperty -Path $lsaPath -Name "Security Packages" -Value @("") -Type MultiString -Force -ErrorAction Stop
                $actions += "Security Packages zurueckgesetzt auf leer"
                Write-Host "  [OK] Security Packages zurueckgesetzt" -ForegroundColor Green
            } catch {
                $actions += "Security Packages konnten nicht zurueckgesetzt werden: $_"
                Write-Host "  [WARN] Fehler beim Zuruecksetzen von Security Packages: $_" -ForegroundColor Yellow
                $success = $false
            }
        }
    }
} catch {
    Write-Host "  [WARN] Fehler beim Pruefen von Security Packages: $_" -ForegroundColor Yellow
    $success = $false
}

# OSConfig Security Packages
try {
    if (-not (Test-Path -Path $osconfigPath)) {
        Write-Host "  [OK] OSConfig-Key nicht vorhanden" -ForegroundColor Green
    } else {
        $props = Get-ItemProperty -Path $osconfigPath -ErrorAction Stop
        $currentOSPackages = @()
        try { $currentOSPackages = @($props."Security Packages") } catch {}

        $unknownOSPackages = @($currentOSPackages | Where-Object {
            $pkg = [string]$_
            $pkg -ne "" -and ($allowedOSConfigPackages -notcontains $pkg)
        })

        if ($unknownOSPackages.Count -eq 0) {
            Write-Host "  [OK] OSConfig Security Packages: keine unbekannten Eintraege" -ForegroundColor Green
        } else {
            foreach ($pkg in $unknownOSPackages) {
                $findings += "Unbekanntes OSConfig Security Package: '$pkg'"
                Write-Host "  [FUND] Unbekanntes OSConfig Package: '$pkg'" -ForegroundColor Red
            }
            try {
                Set-ItemProperty -Path $osconfigPath -Name "Security Packages" -Value @("") -Type MultiString -Force -ErrorAction Stop
                $actions += "OSConfig Security Packages zurueckgesetzt"
                Write-Host "  [OK] OSConfig Security Packages zurueckgesetzt" -ForegroundColor Green
            } catch {
                $actions += "OSConfig Security Packages konnten nicht zurueckgesetzt werden: $_"
                Write-Host "  [WARN] Fehler beim Zuruecksetzen von OSConfig Packages: $_" -ForegroundColor Yellow
                $success = $false
            }
        }
    }
} catch {
    Write-Host "  [WARN] Fehler beim Pruefen von OSConfig Security Packages: $_" -ForegroundColor Yellow
    $success = $false
}

Write-Host ""

[PSCustomObject]@{
    Module   = "lsa-packages"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
