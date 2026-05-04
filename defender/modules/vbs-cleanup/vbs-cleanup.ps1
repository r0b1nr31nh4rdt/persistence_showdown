#Requires -RunAsAdministrator

$targetFiles = @(
    "$env:APPDATA\Microsoft\Installer\msihelper.vbs",
    "$env:APPDATA\Microsoft\Windows\Caches\cache.vbs",
    "$env:APPDATA\Microsoft\Internet Explorer\UserData\iehelper.vbs",
    "$env:ProgramData\Microsoft\Installer\msihelper.vbs",
    "$env:ProgramData\Microsoft\Windows\Caches\cache.vbs",
    "$env:ProgramData\Microsoft\Internet Explorer\UserData\iehelper.vbs"
)

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== vbs-cleanup ===" -ForegroundColor Cyan

foreach ($file in $targetFiles) {
    try {
        if (-not (Test-Path -LiteralPath $file -PathType Leaf -ErrorAction SilentlyContinue)) {
            Write-Host "  [OK] Not found: $file" -ForegroundColor Green
            continue
        }
        $findings += "Attacker VBS found: '$file'"
        Write-Host "  [FIND] VBS file: $file" -ForegroundColor Red
        try {
            $item = Get-Item -LiteralPath $file -Force -ErrorAction Stop
            $item.Attributes = [System.IO.FileAttributes]::Normal
            Remove-Item -LiteralPath $file -Force -ErrorAction Stop
            $actions += "Removed: '$file'"
            Write-Host "  [OK] Removed: $file" -ForegroundColor Green
        } catch {
            $actions += "Failed to remove '$file': $_"
            Write-Host "  [WARN] Error removing '$file': $_" -ForegroundColor Yellow
            $success = $false
        }
    } catch {
        Write-Host "  [WARN] Error checking '$file': $_" -ForegroundColor Yellow
        $success = $false
    }
}

Write-Host ""

[PSCustomObject]@{
    Module   = "vbs-cleanup"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
