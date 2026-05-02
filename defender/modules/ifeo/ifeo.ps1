#Requires -RunAsAdministrator

$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== ifeo ===" -ForegroundColor Cyan

try {
    if (-not (Test-Path -Path $regPath)) {
        Write-Host "  [OK] IFEO-Key nicht vorhanden" -ForegroundColor Green
    } else {
        $subkeys = @(Get-ChildItem -Path $regPath -ErrorAction Stop)
        foreach ($subkey in $subkeys) {
            try {
                $props = Get-ItemProperty -Path $subkey.PSPath -ErrorAction Stop
                $debuggerProp = $props.PSObject.Properties | Where-Object { $_.Name -eq "Debugger" }
                if ($debuggerProp) {
                    $debuggerValue = [string]$debuggerProp.Value
                    $findings += "IFEO Debugger-Wert: '$($subkey.PSChildName)' -> '$debuggerValue'"
                    Write-Host "  [FUND] IFEO '$($subkey.PSChildName)': Debugger = '$debuggerValue'" -ForegroundColor Red
                    try {
                        Remove-ItemProperty -Path $subkey.PSPath -Name "Debugger" -Force -ErrorAction Stop
                        $actions += "IFEO '$($subkey.PSChildName)': Debugger-Wert entfernt"
                        Write-Host "  [OK] Debugger-Wert bei '$($subkey.PSChildName)' entfernt" -ForegroundColor Green
                    } catch {
                        $actions += "IFEO '$($subkey.PSChildName)': Entfernung fehlgeschlagen: $_"
                        Write-Host "  [WARN] Fehler beim Entfernen des Debugger-Wertes bei '$($subkey.PSChildName)': $_" -ForegroundColor Yellow
                        $success = $false
                    }
                } else {
                    Write-Host "  [OK] '$($subkey.PSChildName)': kein Debugger-Wert" -ForegroundColor Green
                }
            } catch {
                Write-Host "  [WARN] Fehler beim Lesen von '$($subkey.PSChildName)': $_" -ForegroundColor Yellow
                $success = $false
            }
        }
    }
} catch {
    Write-Host "  [WARN] Fehler beim Pruefen von IFEO: $_" -ForegroundColor Yellow
    $success = $false
}

Write-Host ""

[PSCustomObject]@{
    Module   = "ifeo"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
