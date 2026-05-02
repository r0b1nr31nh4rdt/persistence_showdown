#Requires -RunAsAdministrator

$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCertDlls"

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== appcertdlls ===" -ForegroundColor Cyan

try {
    if (-not (Test-Path -Path $regPath)) {
        Write-Host "  [OK] AppCertDlls key not found" -ForegroundColor Green
    } else {
        $props = Get-ItemProperty -Path $regPath -ErrorAction Stop
        $values = @($props.PSObject.Properties | Where-Object {
            $_.Name -notmatch '^PS(Path|ParentPath|ChildName|Drive|Provider)$'
        })

        if ($values.Count -eq 0) {
            Write-Host "  [OK] AppCertDlls empty" -ForegroundColor Green
        } else {
            foreach ($v in $values) {
                $dllPath = [string]$v.Value
                $findings += "AppCertDlls entry found: '$($v.Name)' = '$dllPath'"
                Write-Host "  [FIND] AppCertDlls: '$($v.Name)' = '$dllPath'" -ForegroundColor Red

                # Remove registry entry
                try {
                    Remove-ItemProperty -Path $regPath -Name $v.Name -Force -ErrorAction Stop
                    $actions += "Registry value '$($v.Name)' removed"
                    Write-Host "  [OK] Registry value '$($v.Name)' removed" -ForegroundColor Green
                } catch {
                    $actions += "Failed to remove registry value '$($v.Name)': $_"
                    Write-Host "  [WARN] Error removing '$($v.Name)': $_" -ForegroundColor Yellow
                    $success = $false
                }

                # Delete referenced DLL file
                if (-not [string]::IsNullOrWhiteSpace($dllPath)) {
                    $expandedPath = [Environment]::ExpandEnvironmentVariables($dllPath.Trim('"'))
                    try {
                        if (Test-Path -LiteralPath $expandedPath -PathType Leaf) {
                            Remove-Item -LiteralPath $expandedPath -Force -ErrorAction Stop
                            $actions += "DLL file deleted: '$expandedPath'"
                            Write-Host "  [OK] DLL deleted: '$expandedPath'" -ForegroundColor Green
                        }
                    } catch {
                        $actions += "Failed to delete DLL '$expandedPath': $_"
                        Write-Host "  [WARN] Error deleting '$expandedPath': $_" -ForegroundColor Yellow
                        $success = $false
                    }
                }
            }
        }
    }
} catch {
    Write-Host "  [WARN] Error checking AppCertDlls: $_" -ForegroundColor Yellow
    $success = $false
}

Write-Host ""

[PSCustomObject]@{
    Module   = "appcertdlls"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
