# ==============================================================================
# ATTACKER SCRIPT — HKLM Run Key Persistence (Showdown Version)
# Educational purposes only.
#
# TECHNIQUE OVERVIEW:
#   HKLM persistence affects ALL users on the machine (vs HKCU which only
#   affects the current user). Requires Administrator privileges to write.
#   Like the HKCU script, this uses two lesser-known autorun locations instead
#   of the obvious standard HKLM Run key that every defender script checks.
#
# LAYERS APPLIED:
#   Layer 1 : Believable registry value names and file names
#   Layer 2a: wscript.exe //B wrapper — zero visible window (no flash)
#   Layer 2b: -EncodedCommand (Base64) — no plaintext keywords in trigger
#   Layer 3b: Payload stored in obscure HKLM registry paths (rarely audited)
#   Layer 4 : AES-256 encryption of payload at rest
#   Layer 5b: Timestamp backdating on all dropped files and parent folders
#
# CHAINS:
#   PRIMARY  — Trigger: HKLM\...\Policies\Explorer\Run
#              Storage: HKLM\SYSTEM\...\Session Manager\Environment\DriverData
#              File:    %SystemRoot%\System32\drivers\etc\svcmon.vbs
#
#   BACKUP   — Trigger: HKLM\SOFTWARE\...\Windows NT\...\Windows "Load" value
#              Storage: HKLM\SOFTWARE\...\AppCompatFlags\Custom\CompatData
#              File:    %SystemRoot%\System32\drivers\etc\netmon.vbs
#
# RESULT: C:\Users\Public\Documents\pwned.txt containing "Pwn3d"
# ==============================================================================
#
# ADDITIONAL STEALTH:
#   -Remove all "Write-Host..." lines.
#   -Rename variable names to single letters or random strings. These appear in memory dumps and logs.