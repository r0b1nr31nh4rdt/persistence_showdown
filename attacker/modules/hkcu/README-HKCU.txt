# ==============================================================================
# ATTACKER SCRIPT — HKCU Run Key Persistence 
#
# TECHNIQUE OVERVIEW:
#   Instead of using the well-known standard Run key location, this script uses
#   two lesser-known autorun locations that basic defender scripts often miss.
#   Each chain is fully independent (separate encryption keys, separate storage
#   paths, separate trigger locations, separate dropped files).
#   The defender must find and remove ALL chains to prevent execution.
#
# LAYERS APPLIED:
#   Layer 1 : Believable registry value names and file names
#   Layer 2a: wscript.exe //B wrapper — zero visible window (no flash)
#   Layer 2b: -EncodedCommand (Base64) — no plaintext keywords in Run key
#   Layer 3b: Payload stored in AppCompatFlags registry keys (rarely audited)
#   Layer 4 : AES-256 encryption of payload at rest
#   Layer 5b: Timestamp backdating on all dropped files and parent folders
#
# LAYER ORDER:
#   Layer 4 before Layer 3b - Payload encryption before storing in registry.
#   Layer 2b before trigger - Base64-encode the loader before writing it to the Run key. Encoded string is what goes #			      into Registry value.
#   Layer 2a before trigger - The VBS file must exist on disk before the Run key points to it, otherwise the trigger #			      finds nothing.
#   Layer 5b last           - Otherwise the timestamp gets updated to the current time.
#
# CHAINS:
#   PRIMARY  — Trigger: HKCU\...\Policies\Explorer\Run
#              Storage: AppCompatFlags\Layers\CacheData
#              File:    %LOCALAPPDATA%\Microsoft\Windows\WebCache\mshelper.vbs
#
#   BACKUP   — Trigger: HKCU\...\Windows NT\...\Windows "Load" value
#              Storage: AppCompatFlags\Custom\CompatData
#              File:    %APPDATA%\Microsoft\Internet Explorer\UserData\iehelper.vbs
#
# RESULT: C:\Users\Public\Documents\pwned.txt containing "Pwn3d"
# ==============================================================================
#
# ADDITIONAL STEALTH:
#   -Remove all "Write-Host..." lines.
#   -Rename variable names to single letters or random strings. These appear in memory dumps and logs.