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
            Write-Host "  [OK] Folder not found: $folder" -ForegroundColor Green
            continue
        }
        $files = @(Get-ChildItem -LiteralPath $folder -File -ErrorAction SilentlyContinue)
        if ($files.Count -eq 0) {
            Write-Host "  [OK] Startup folder empty: $folder" -ForegroundColor Green
            continue
        }
        foreach ($file in $files) {
            $findings += "Startup file found: $($file.FullName)"
            Write-Host "  [FIND] Startup file: $($file.Name)" -ForegroundColor Red
            try {
                Remove-Item -LiteralPath $file.FullName -Force -ErrorAction Stop
                $actions += "File deleted: $($file.FullName)"
                Write-Host "  [OK] Deleted: $($file.Name)" -ForegroundColor Green
            } catch {
                $actions += "Failed to delete: $($file.FullName): $_"
                Write-Host "  [WARN] Error deleting '$($file.Name)': $_" -ForegroundColor Yellow
                $success = $false
            }
        }
    } catch {
        Write-Host "  [WARN] Error checking '$folder': $_" -ForegroundColor Yellow
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
