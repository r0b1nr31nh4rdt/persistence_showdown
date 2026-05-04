#Requires -RunAsAdministrator

$suspiciousPattern = 'cmd|powershell|shell|exec|download|iex|invoke|rundll'

$profiles = @(
    $PROFILE,
    $PROFILE.AllUsersCurrentHost,
    $PROFILE.CurrentUserAllHosts,
    $PROFILE.AllUsersAllHosts,
    "$PSHOME\profile.ps1"
)

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== profile-injection ===" -ForegroundColor Cyan

foreach ($prof in $profiles) {
    try {
        if (-not (Test-Path -LiteralPath $prof -ErrorAction SilentlyContinue)) {
            Write-Host "  [OK] Not found: $prof" -ForegroundColor Green
            continue
        }
        $lines = Get-Content -LiteralPath $prof -ErrorAction Stop
        $hits  = @($lines | Where-Object { $_ -match $suspiciousPattern })
        if ($hits.Count -eq 0) {
            Write-Host "  [OK] Clean: $prof" -ForegroundColor Green
        } else {
            $findings += "Suspicious profile: '$prof' ($($hits.Count) matching lines)"
            Write-Host "  [FIND] Suspicious content in: $prof" -ForegroundColor Red
            foreach ($h in $hits) { Write-Host "    > $h" -ForegroundColor Red }
            try {
                Remove-Item -LiteralPath $prof -Force -ErrorAction Stop
                $actions += "Profile removed: '$prof'"
                Write-Host "  [OK] Profile removed: $prof" -ForegroundColor Green
            } catch {
                $actions += "Failed to remove profile '$prof': $_"
                Write-Host "  [WARN] Error removing '$prof': $_" -ForegroundColor Yellow
                $success = $false
            }
        }
    } catch {
        Write-Host "  [WARN] Error checking '$prof': $_" -ForegroundColor Yellow
        $success = $false
    }
}

Write-Host ""

[PSCustomObject]@{
    Module   = "profile-injection"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
