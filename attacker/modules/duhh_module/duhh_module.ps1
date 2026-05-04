$path = 'C:\Users\Public\Documents'
$file = Join-Path $path 'pwned.txt'

# Ensure directory exists
if (-not (Test-Path -Path $path)) {
    New-Item -ItemType Directory -Path $path -Force | Out-Null
}

# Write text to file (overwrites if exists)
"Pwn3d. duhhhh" | Set-Content -Path $file -Encoding UTF8

# Optional: confirm
Write-Output "Wrote file: $file"