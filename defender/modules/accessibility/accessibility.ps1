#Requires -RunAsAdministrator

$locations = @(
    @{ Path = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Accessibility"; Name = "Configuration"; Label = "HKCU Accessibility\Configuration" },
    @{ Path = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Accessibility"; Name = "Startup";       Label = "HKLM Accessibility\Startup" }
)

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== accessibility ===" -ForegroundColor Cyan

foreach ($loc in $locations) {
    try {
        if (-not (Test-Path -Path $loc.Path)) {
            Write-Host "  [OK] $($loc.Label): key not found" -ForegroundColor Green
            continue
        }
        $val = $null
        try { $val = (Get-ItemProperty -Path $loc.Path -Name $loc.Name -ErrorAction Stop).($loc.Name) } catch {}
        if ($null -eq $val -or [string]::IsNullOrWhiteSpace([string]$val)) {
            Write-Host "  [OK] $($loc.Label): empty" -ForegroundColor Green
        } else {
            $findings += "$($loc.Label): '$val'"
            Write-Host "  [FIND] $($loc.Label): '$val'" -ForegroundColor Red
            try {
                Remove-ItemProperty -Path $loc.Path -Name $loc.Name -Force -ErrorAction Stop
                $actions += "$($loc.Label) removed"
                Write-Host "  [OK] $($loc.Label) removed" -ForegroundColor Green
            } catch {
                $actions += "$($loc.Label): removal failed: $_"
                Write-Host "  [WARN] Error removing $($loc.Label): $_" -ForegroundColor Yellow
                $success = $false
            }
        }
    } catch {
        Write-Host "  [WARN] Error checking $($loc.Label): $_" -ForegroundColor Yellow
        $success = $false
    }
}

Write-Host ""

[PSCustomObject]@{
    Module   = "accessibility"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
