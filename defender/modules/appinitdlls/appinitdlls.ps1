#Requires -RunAsAdministrator

$regLocations = @(
    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Windows"
)

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== appinitdlls ===" -ForegroundColor Cyan

foreach ($regPath in $regLocations) {
    $label = if ($regPath -match "WOW6432Node") { "AppInit_DLLs (Wow64)" } else { "AppInit_DLLs (x64)" }

    try {
        if (-not (Test-Path -Path $regPath)) {
            Write-Host "  [OK] $label: Schluessel nicht vorhanden" -ForegroundColor Green
            continue
        }

        $props    = Get-ItemProperty -Path $regPath -ErrorAction Stop
        $dllValue = ""
        try { $dllValue = [string]$props.AppInit_DLLs } catch {}

        if ([string]::IsNullOrWhiteSpace($dllValue)) {
            Write-Host "  [OK] $label: leer" -ForegroundColor Green
        } else {
            $findings += "$label enthält: '$dllValue'"
            Write-Host "  [FUND] $label: '$dllValue'" -ForegroundColor Red

            # DLL-Dateien vor dem Leeren des Wertes sichern
            $dllPaths = $dllValue -split '[\s,;]+' | Where-Object { $_ -ne "" }

            # Wert auf leer setzen (Key nicht loeschen)
            try {
                Set-ItemProperty -Path $regPath -Name "AppInit_DLLs" -Value "" -Force -ErrorAction Stop
                $actions += "$label: Wert auf leer gesetzt"
                Write-Host "  [OK] $label: Wert geleert" -ForegroundColor Green
            } catch {
                $actions += "$label: Leeren fehlgeschlagen: $_"
                Write-Host "  [WARN] Fehler beim Leeren von $label: $_" -ForegroundColor Yellow
                $success = $false
            }

            # Auch LoadAppInit_DLLs deaktivieren
            try {
                Set-ItemProperty -Path $regPath -Name "LoadAppInit_DLLs" -Value 0 -Force -ErrorAction SilentlyContinue
                $actions += "$label: LoadAppInit_DLLs auf 0 gesetzt"
            } catch {}

            # Referenzierte DLL-Dateien loeschen
            foreach ($dll in $dllPaths) {
                $expandedPath = [Environment]::ExpandEnvironmentVariables($dll.Trim('"'))
                try {
                    if (Test-Path -LiteralPath $expandedPath -PathType Leaf) {
                        Remove-Item -LiteralPath $expandedPath -Force -ErrorAction Stop
                        $actions += "DLL geloescht: '$expandedPath'"
                        Write-Host "  [OK] DLL geloescht: '$expandedPath'" -ForegroundColor Green
                    }
                } catch {
                    $actions += "DLL '$expandedPath' konnte nicht geloescht werden: $_"
                    Write-Host "  [WARN] Fehler beim Loeschen von '$expandedPath': $_" -ForegroundColor Yellow
                    $success = $false
                }
            }
        }
    } catch {
        Write-Host "  [WARN] Fehler beim Pruefen von $label: $_" -ForegroundColor Yellow
        $success = $false
    }
}

Write-Host ""

[PSCustomObject]@{
    Module   = "appinitdlls"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
