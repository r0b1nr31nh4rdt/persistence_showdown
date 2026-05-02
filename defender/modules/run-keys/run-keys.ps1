#Requires -RunAsAdministrator

$allowedRunHKLM = @(
    "SecurityHealth"
)
$allowedRunHKCU = @(
    "OneDrive"
)
$allowedRunOnceHKLM = @(
    "msedge_cleanup_{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}"
)
$allowedRunOnceHKCU = @(
    "Delete Cached Update Binary",
    "Delete Cached Standalone Update Binary",
    "Uninstall 26.040.0301.0001"
)

$findings = @()
$actions  = @()
$success  = $true

$locations = @(
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run";     Allowed = $allowedRunHKLM;     Label = "HKLM Run" },
    @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run";     Allowed = $allowedRunHKCU;     Label = "HKCU Run" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"; Allowed = $allowedRunOnceHKLM; Label = "HKLM RunOnce" },
    @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce"; Allowed = $allowedRunOnceHKCU; Label = "HKCU RunOnce" }
)

Write-Host ""
Write-Host "=== run-keys ===" -ForegroundColor Cyan

foreach ($loc in $locations) {
    try {
        if (-not (Test-Path $loc.Path)) {
            Write-Host "  [OK] $($loc.Label): key not found" -ForegroundColor Green
            continue
        }
        $props = Get-ItemProperty -Path $loc.Path -ErrorAction Stop
        $values = @($props.PSObject.Properties | Where-Object {
            $_.Name -notmatch '^PS(Path|ParentPath|ChildName|Drive|Provider)$'
        })
        if ($values.Count -eq 0) {
            Write-Host "  [OK] $($loc.Label): empty" -ForegroundColor Green
            continue
        }
        foreach ($v in $values) {
            if ($loc.Allowed -contains $v.Name) {
                Write-Host "  [OK] $($loc.Label): '$($v.Name)' whitelisted" -ForegroundColor Green
            } else {
                $findings += "$($loc.Label): unknown entry '$($v.Name)' = '$($v.Value)'"
                Write-Host "  [FIND] $($loc.Label): '$($v.Name)' not in whitelist" -ForegroundColor Red
                try {
                    Remove-ItemProperty -Path $loc.Path -Name $v.Name -Force -ErrorAction Stop
                    $actions += "$($loc.Label): '$($v.Name)' removed"
                    Write-Host "  [OK] '$($v.Name)' removed" -ForegroundColor Green
                } catch {
                    $actions += "$($loc.Label): failed to remove '$($v.Name)': $_"
                    Write-Host "  [WARN] Error removing '$($v.Name)': $_" -ForegroundColor Yellow
                    $success = $false
                }
            }
        }
    } catch {
        Write-Host "  [WARN] Error reading $($loc.Label): $_" -ForegroundColor Yellow
        $success = $false
    }
}

Write-Host ""

[PSCustomObject]@{
    Module   = "run-keys"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
