$profiles = @(
    $PROFILE,
    $PROFILE.AllUsersCurrentHost,
    $PROFILE.CurrentUserAllHosts,
    $PROFILE.AllUsersAllHosts,
    "$PSHOME\profile.ps1"
)

$suspicious = 'cmd|powershell|shell|exec|download|iex|invoke|rundll'

foreach ($prof in $profiles) {
    if (Test-Path $prof) {
        Write-Host "[+] Scanning: $prof" -ForegroundColor Cyan
        Get-Content $prof | Where-Object { $_ -match $suspicious } | ForEach-Object { Write-Host "[!] $_" -ForegroundColor Red }
    }
}
