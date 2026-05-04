#Requires -RunAsAdministrator

$targetPaths = @(
    "C:\Users\Public\Documents\pwned.txt",
    "C:\Users\Public\Public Documents\pwned.txt"
)

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== pwned-cleanup ===" -ForegroundColor Cyan

$found = $false
foreach ($targetPath in $targetPaths) {
    try {
        if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
            $found = $true
            $findings += "pwned.txt found: '$targetPath'"
            Write-Host "  [FIND] pwned.txt found: '$targetPath'" -ForegroundColor Red
            try {
                Remove-Item -LiteralPath $targetPath -Force -ErrorAction Stop
                $actions += "pwned.txt deleted: '$targetPath'"
                Write-Host "  [OK] pwned.txt deleted" -ForegroundColor Green
            } catch {
                $actions += "Failed to delete '$targetPath': $_"
                Write-Host "  [WARN] Error deleting pwned.txt: $_" -ForegroundColor Yellow
                $success = $false
            }
        }
    } catch {
        Write-Host "  [WARN] Error checking '$targetPath': $_" -ForegroundColor Yellow
        $success = $false
    }
}

if (-not $found) {
    Write-Host "  [OK] pwned.txt not found" -ForegroundColor Green
}

Write-Host ""

[PSCustomObject]@{
    Module   = "pwned-cleanup"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
