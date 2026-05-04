#Requires -RunAsAdministrator

# Value names specifically planted by the attacker as encrypted payload storage.
$blobTargets = @(
    @{ Path = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"; Name = "CacheData";  Label = "HKCU AppCompatFlags\Layers CacheData" },
    @{ Path = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Custom"; Name = "CompatData"; Label = "HKCU AppCompatFlags\Custom CompatData" },
    @{ Path = "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Custom"; Name = "CompatData"; Label = "HKLM AppCompatFlags\Custom CompatData" }
)

# DriverData: attacker overwrites with encrypted blob; expected value is a Windows path.
$driverDataPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
$driverDataName = "DriverData"

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== appcompatflags ===" -ForegroundColor Cyan

foreach ($t in $blobTargets) {
    try {
        $val = $null
        try {
            $props = Get-ItemProperty -Path $t.Path -Name $t.Name -ErrorAction Stop
            $prop = $props.PSObject.Properties[$t.Name]
            if ($null -ne $prop) { $val = $prop.Value }
        } catch {}

        if ($null -eq $val) {
            Write-Host "  [OK] $($t.Label): not found" -ForegroundColor Green
        } else {
            $findings += "$($t.Label): encrypted blob present"
            Write-Host "  [FIND] $($t.Label): encrypted blob present" -ForegroundColor Red
            try {
                Remove-ItemProperty -Path $t.Path -Name $t.Name -Force -ErrorAction Stop
                $actions += "$($t.Label) removed"
                Write-Host "  [OK] $($t.Label) removed" -ForegroundColor Green
            } catch {
                $actions += "$($t.Label): removal failed: $_"
                Write-Host "  [WARN] Error removing $($t.Label): $_" -ForegroundColor Yellow
                $success = $false
            }
        }
    } catch {
        Write-Host "  [WARN] Error checking $($t.Label): $_" -ForegroundColor Yellow
        $success = $false
    }
}

# DriverData: remove if it looks like a payload blob (no backslash = not a path).
try {
    $ddVal = $null
    try {
        $props = Get-ItemProperty -Path $driverDataPath -Name $driverDataName -ErrorAction Stop
        $prop = $props.PSObject.Properties[$driverDataName]
        if ($null -ne $prop) { $ddVal = [string]$prop.Value }
    } catch {}

    if ($null -eq $ddVal -or $ddVal -eq "") {
        Write-Host "  [OK] DriverData: not set" -ForegroundColor Green
    } elseif ($ddVal -like "*\*") {
        Write-Host "  [OK] DriverData: '$ddVal'" -ForegroundColor Green
    } else {
        $findings += "DriverData: unexpected value (looks like payload blob)"
        Write-Host "  [FIND] DriverData: does not look like a path - possible payload blob" -ForegroundColor Red
        try {
            Remove-ItemProperty -Path $driverDataPath -Name $driverDataName -Force -ErrorAction Stop
            $actions += "DriverData removed"
            Write-Host "  [OK] DriverData removed" -ForegroundColor Green
        } catch {
            $actions += "DriverData: removal failed: $_"
            Write-Host "  [WARN] Error removing DriverData: $_" -ForegroundColor Yellow
            $success = $false
        }
    }
} catch {
    Write-Host "  [WARN] Error checking DriverData: $_" -ForegroundColor Yellow
    $success = $false
}

Write-Host ""

[PSCustomObject]@{
    Module   = "appcompatflags"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
