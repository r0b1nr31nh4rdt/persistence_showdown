#Requires -RunAsAdministrator

$targetPath = "C:\Users\Public\Documents\pwned.txt"

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== pwned-cleanup ===" -ForegroundColor Cyan

try {
    if (-not (Test-Path -LiteralPath $targetPath -PathType Leaf)) {
        Write-Host "  [OK] pwned.txt nicht vorhanden" -ForegroundColor Green
    } else {
        $findings += "pwned.txt gefunden: '$targetPath'"
        Write-Host "  [FUND] pwned.txt gefunden: '$targetPath'" -ForegroundColor Red
        try {
            Remove-Item -LiteralPath $targetPath -Force -ErrorAction Stop
            $actions += "pwned.txt geloescht: '$targetPath'"
            Write-Host "  [OK] pwned.txt geloescht" -ForegroundColor Green
        } catch {
            $actions += "Loeschen fehlgeschlagen: $_"
            Write-Host "  [WARN] Fehler beim Loeschen von pwned.txt: $_" -ForegroundColor Yellow
            $success = $false
        }
    }
} catch {
    Write-Host "  [WARN] Fehler beim Pruefen von pwned.txt: $_" -ForegroundColor Yellow
    $success = $false
}

Write-Host ""

[PSCustomObject]@{
    Module   = "pwned-cleanup"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
