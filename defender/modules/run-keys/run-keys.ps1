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
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run";                                    Allowed = $allowedRunHKLM;     Label = "HKLM Run" },
    @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run";                                    Allowed = $allowedRunHKCU;     Label = "HKCU Run" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce";                                Allowed = $allowedRunOnceHKLM; Label = "HKLM RunOnce" },
    @{ Path = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce";                                Allowed = $allowedRunOnceHKCU; Label = "HKCU RunOnce" },
    @{ Path = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run";                  Allowed = @();                 Label = "HKCU Policies\Explorer\Run" },
    @{ Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run";                  Allowed = @();                 Label = "HKLM Policies\Explorer\Run" },
    @{ Path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run";      Allowed = @();                 Label = "HKLM WOW64 Policies\Explorer\Run" },
    @{ Path = "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunServices";                            Allowed = @();                 Label = "HKLM RunServices" }
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

# --- HKCU Windows\Load (should be empty on a clean system) ---
$windowsLoadPath = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows"
try {
    if (Test-Path $windowsLoadPath) {
        $loadVal = ""
        try { $loadVal = [string](Get-ItemProperty -Path $windowsLoadPath -Name "Load" -ErrorAction Stop).Load } catch {}
        if ([string]::IsNullOrWhiteSpace($loadVal)) {
            Write-Host "  [OK] HKCU Windows\Load: empty" -ForegroundColor Green
        } else {
            $findings += "HKCU Windows\Load: '$loadVal'"
            Write-Host "  [FIND] HKCU Windows\Load: '$loadVal'" -ForegroundColor Red
            try {
                Remove-ItemProperty -Path $windowsLoadPath -Name "Load" -Force -ErrorAction Stop
                $actions += "HKCU Windows\Load removed"
                Write-Host "  [OK] HKCU Windows\Load removed" -ForegroundColor Green
            } catch {
                $actions += "HKCU Windows\Load removal failed: $_"
                Write-Host "  [WARN] Error removing HKCU Windows\Load: $_" -ForegroundColor Yellow
                $success = $false
            }
        }
    } else {
        Write-Host "  [OK] HKCU Windows\Load: key not found" -ForegroundColor Green
    }
} catch {
    Write-Host "  [WARN] Error checking HKCU Windows\Load: $_" -ForegroundColor Yellow
    $success = $false
}

Write-Host ""

[PSCustomObject]@{
    Module   = "run-keys"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
