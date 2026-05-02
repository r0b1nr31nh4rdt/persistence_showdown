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
        Write-Host "  [WARN] Winlogon key not found" -ForegroundColor Yellow
        $success = $false
    } else {
        $props = Get-ItemProperty -Path $regPath -ErrorAction Stop

        # Check and enforce Userinit
        $currentUserinit = ""
        try { $currentUserinit = [string]$props.Userinit } catch {}

        if ($currentUserinit -eq $expectedUserinit) {
            Write-Host "  [OK] Userinit: '$currentUserinit'" -ForegroundColor Green
        } else {
            $findings += "Winlogon Userinit deviates: '$currentUserinit'"
            Write-Host "  [FIND] Userinit: '$currentUserinit' (expected: '$expectedUserinit')" -ForegroundColor Red
            try {
                Set-ItemProperty -Path $regPath -Name "Userinit" -Value $expectedUserinit -Force -ErrorAction Stop
                $actions += "Userinit reset to '$expectedUserinit'"
                Write-Host "  [OK] Userinit reset" -ForegroundColor Green
            } catch {
                $actions += "Failed to reset Userinit: $_"
                Write-Host "  [WARN] Error resetting Userinit: $_" -ForegroundColor Yellow
                $success = $false
            }
        }

        # Check and enforce Shell
        $currentShell = ""
        try { $currentShell = [string]$props.Shell } catch {}

        if ($currentShell -eq $expectedShell) {
            Write-Host "  [OK] Shell: '$currentShell'" -ForegroundColor Green
        } else {
            $findings += "Winlogon Shell deviates: '$currentShell'"
            Write-Host "  [FIND] Shell: '$currentShell' (expected: '$expectedShell')" -ForegroundColor Red
            try {
                Set-ItemProperty -Path $regPath -Name "Shell" -Value $expectedShell -Force -ErrorAction Stop
                $actions += "Shell reset to '$expectedShell'"
                Write-Host "  [OK] Shell reset" -ForegroundColor Green
            } catch {
                $actions += "Failed to reset Shell: $_"
                Write-Host "  [WARN] Error resetting Shell: $_" -ForegroundColor Yellow
                $success = $false
            }
        }
    }
} catch {
    Write-Host "  [WARN] Error checking Winlogon: $_" -ForegroundColor Yellow
    $success = $false
}

Write-Host ""

[PSCustomObject]@{
    Module   = "winlogon"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
