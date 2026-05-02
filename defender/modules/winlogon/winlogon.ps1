#Requires -RunAsAdministrator

$expectedUserinit = "C:\Windows\system32\userinit.exe,"
$expectedShell    = "explorer.exe"

$regPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon"

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== winlogon ===" -ForegroundColor Cyan

try {
    if (-not (Test-Path -Path $regPath)) {
        Write-Host "  [WARN] Winlogon-Key nicht gefunden" -ForegroundColor Yellow
        $success = $false
    } else {
        $props = Get-ItemProperty -Path $regPath -ErrorAction Stop

        # Userinit pruefen und erzwingen
        $currentUserinit = ""
        try { $currentUserinit = [string]$props.Userinit } catch {}

        if ($currentUserinit -eq $expectedUserinit) {
            Write-Host "  [OK] Userinit: '$currentUserinit'" -ForegroundColor Green
        } else {
            $findings += "Winlogon Userinit abweichend: '$currentUserinit'"
            Write-Host "  [FUND] Userinit: '$currentUserinit' (erwartet: '$expectedUserinit')" -ForegroundColor Red
            try {
                Set-ItemProperty -Path $regPath -Name "Userinit" -Value $expectedUserinit -Force -ErrorAction Stop
                $actions += "Userinit auf '$expectedUserinit' zurueckgesetzt"
                Write-Host "  [OK] Userinit zurueckgesetzt" -ForegroundColor Green
            } catch {
                $actions += "Userinit konnte nicht zurueckgesetzt werden: $_"
                Write-Host "  [WARN] Fehler beim Zuruecksetzen von Userinit: $_" -ForegroundColor Yellow
                $success = $false
            }
        }

        # Shell pruefen und erzwingen
        $currentShell = ""
        try { $currentShell = [string]$props.Shell } catch {}

        if ($currentShell -eq $expectedShell) {
            Write-Host "  [OK] Shell: '$currentShell'" -ForegroundColor Green
        } else {
            $findings += "Winlogon Shell abweichend: '$currentShell'"
            Write-Host "  [FUND] Shell: '$currentShell' (erwartet: '$expectedShell')" -ForegroundColor Red
            try {
                Set-ItemProperty -Path $regPath -Name "Shell" -Value $expectedShell -Force -ErrorAction Stop
                $actions += "Shell auf '$expectedShell' zurueckgesetzt"
                Write-Host "  [OK] Shell zurueckgesetzt" -ForegroundColor Green
            } catch {
                $actions += "Shell konnte nicht zurueckgesetzt werden: $_"
                Write-Host "  [WARN] Fehler beim Zuruecksetzen von Shell: $_" -ForegroundColor Yellow
                $success = $false
            }
        }
    }
} catch {
    Write-Host "  [WARN] Fehler beim Pruefen von Winlogon: $_" -ForegroundColor Yellow
    $success = $false
}

Write-Host ""

[PSCustomObject]@{
    Module   = "winlogon"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
