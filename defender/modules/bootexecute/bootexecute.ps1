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
        Write-Host "  [WARN] Session Manager-Key nicht gefunden" -ForegroundColor Yellow
        $success = $false
    } else {
        $props = Get-ItemProperty -Path $regPath -ErrorAction Stop
        $current = @()
        try { $current = @($props.$valueName) } catch {}

        # Pruefen ob der aktuelle Wert exakt dem Soll entspricht
        $currentStr = ($current | ForEach-Object { [string]$_ }) -join "|"
        $allowedStr = ($allowedBootExecute | ForEach-Object { [string]$_ }) -join "|"

        if ($currentStr -eq $allowedStr) {
            Write-Host "  [OK] BootExecute: Standardwert vorhanden" -ForegroundColor Green
        } else {
            $unknownEntries = @($current | Where-Object {
                $entry = [string]$_
                $allowedBootExecute -notcontains $entry
            })

            foreach ($entry in $unknownEntries) {
                $findings += "BootExecute: unbekannter Eintrag '$entry'"
                Write-Host "  [FUND] BootExecute: '$entry' nicht erlaubt" -ForegroundColor Red
            }

            try {
                Set-ItemProperty -Path $regPath -Name $valueName -Value $allowedBootExecute -Type MultiString -Force -ErrorAction Stop
                $actions += "BootExecute auf Standardwert zurueckgesetzt"
                Write-Host "  [OK] BootExecute auf '@(autocheck autochk *)' zurueckgesetzt" -ForegroundColor Green
            } catch {
                $actions += "BootExecute konnte nicht zurueckgesetzt werden: $_"
                Write-Host "  [WARN] Fehler beim Zuruecksetzen von BootExecute: $_" -ForegroundColor Yellow
                $success = $false
            }
        }
    }
} catch {
    Write-Host "  [WARN] Fehler beim Pruefen von BootExecute: $_" -ForegroundColor Yellow
    $success = $false
}

Write-Host ""

[PSCustomObject]@{
    Module   = "bootexecute"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
