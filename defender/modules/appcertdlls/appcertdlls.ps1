#Requires -RunAsAdministrator

$regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCertDlls"

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== appcertdlls ===" -ForegroundColor Cyan

try {
    if (-not (Test-Path -Path $regPath)) {
        Write-Host "  [OK] AppCertDlls-Key nicht vorhanden" -ForegroundColor Green
    } else {
        $props = Get-ItemProperty -Path $regPath -ErrorAction Stop
        $values = @($props.PSObject.Properties | Where-Object {
            $_.Name -notmatch '^PS(Path|ParentPath|ChildName|Drive|Provider)$'
        })

        if ($values.Count -eq 0) {
            Write-Host "  [OK] AppCertDlls leer" -ForegroundColor Green
        } else {
            foreach ($v in $values) {
                $dllPath = [string]$v.Value
                $findings += "AppCertDlls Eintrag gefunden: '$($v.Name)' = '$dllPath'"
                Write-Host "  [FUND] AppCertDlls: '$($v.Name)' = '$dllPath'" -ForegroundColor Red

                # Registry-Eintrag loeschen
                try {
                    Remove-ItemProperty -Path $regPath -Name $v.Name -Force -ErrorAction Stop
                    $actions += "Registry-Wert '$($v.Name)' entfernt"
                    Write-Host "  [OK] Registry-Wert '$($v.Name)' entfernt" -ForegroundColor Green
                } catch {
                    $actions += "Registry-Wert '$($v.Name)' konnte nicht entfernt werden: $_"
                    Write-Host "  [WARN] Fehler beim Entfernen von '$($v.Name)': $_" -ForegroundColor Yellow
                    $success = $false
                }

                # Referenzierte DLL-Datei loeschen
                if (-not [string]::IsNullOrWhiteSpace($dllPath)) {
                    $expandedPath = [Environment]::ExpandEnvironmentVariables($dllPath.Trim('"'))
                    try {
                        if (Test-Path -LiteralPath $expandedPath -PathType Leaf) {
                            Remove-Item -LiteralPath $expandedPath -Force -ErrorAction Stop
                            $actions += "DLL-Datei geloescht: '$expandedPath'"
                            Write-Host "  [OK] DLL geloescht: '$expandedPath'" -ForegroundColor Green
                        }
                    } catch {
                        $actions += "DLL '$expandedPath' konnte nicht geloescht werden: $_"
                        Write-Host "  [WARN] Fehler beim Loeschen von '$expandedPath': $_" -ForegroundColor Yellow
                        $success = $false
                    }
                }
            }
        }
    }
} catch {
    Write-Host "  [WARN] Fehler beim Pruefen von AppCertDlls: $_" -ForegroundColor Yellow
    $success = $false
}

Write-Host ""

[PSCustomObject]@{
    Module   = "appcertdlls"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
