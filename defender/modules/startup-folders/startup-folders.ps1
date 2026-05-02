#Requires -RunAsAdministrator

$folders = @(
    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup",
    "C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup"
)

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== startup-folders ===" -ForegroundColor Cyan

foreach ($folder in $folders) {
    try {
        if (-not (Test-Path -LiteralPath $folder)) {
            Write-Host "  [OK] Ordner nicht gefunden: $folder" -ForegroundColor Green
            continue
        }
        $files = @(Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue)
        if ($files.Count -eq 0) {
            Write-Host "  [OK] Startup-Ordner leer: $folder" -ForegroundColor Green
            continue
        }
        foreach ($file in $files) {
            $findings += "Startup-Datei gefunden: $($file.FullName)"
            Write-Host "  [FUND] Startup-Datei: $($file.Name)" -ForegroundColor Red
            try {
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                $actions += "Datei geloescht: $($file.FullName)"
                Write-Host "  [OK] Geloescht: $($file.Name)" -ForegroundColor Green
            } catch {
                $actions += "Loeschen fehlgeschlagen: $($file.FullName): $_"
                Write-Host "  [WARN] Fehler beim Loeschen von '$($file.Name)': $_" -ForegroundColor Yellow
                $success = $false
            }
        }
    } catch {
        Write-Host "  [WARN] Fehler beim Pruefen von '$folder': $_" -ForegroundColor Yellow
        $success = $false
    }
}

Write-Host ""

[PSCustomObject]@{
    Module   = "startup-folders"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
