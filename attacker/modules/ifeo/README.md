# Image File Execution Options (IFEO)

## What is it?
IFEO is a Windows feature originally designed for developers and debuggers — it was created for legitimate purposes. The name gives it away: it's about options that apply when an image file (i.e. an .exe) is executed.

The core idea is simple: a developer wants to attach a debugger to a program the moment it starts — regardless of who starts it or from what context. Windows automatically launches the debugger and attaches the target program to it. This is useful because manually attaching a debugger to a running process doesn't work for certain problems (e.g. race conditions at startup).

## Where does it come from?
IFEO has existed since the early NT versions — at least since Windows NT 3.1 (early 1990s). Microsoft introduced it as an official debugging tool and it remains part of Windows to this day. It is documented in the Sysinternals ecosystem and Microsoft itself writes openly about it.

The registry path everything revolves around:
```
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\
```

## How does the core mechanism work?
When Windows launches an .exe, the Windows Loader checks this registry key for a subkey matching the exact filename of the executable — e.g. `notepad.exe`. If a `Debugger` value exists there, the following happens:

Windows does not start `notepad.exe` directly. Instead, it starts the process specified in the `Debugger` value and passes the original path to `notepad.exe` as a command-line argument.

Concretely: if you set
```
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe
    Debugger = "C:\dbg\windbg.exe"
```
and someone then launches Notepad, Windows internally runs:
```
C:\dbg\windbg.exe "C:\Windows\System32\notepad.exe"
```
The debugger receives Notepad as an argument and can start it in a controlled way.

## Why is this interesting from a security perspective?
Here is the key point: Windows does not verify whether the `Debugger` value actually points to a debugger. It is just a path to an executable. That means you can put any program there.

Furthermore, the mechanism applies system-wide and for all users — because the key lives under HKLM (the hive that requires administrator rights to write to, but is readable by everyone).

This makes IFEO a classic persistence mechanism for attackers:

- No new process showing up in an autostart list
- No scheduled task
- No service
- Instead: the malware launches exactly when a legitimate program is started — reliably and inconspicuously

A classic real-world example (and a penetration testing staple): the accessibility tools on the Windows lock screen. Programs like `sethc.exe` (Sticky Keys) or `utilman.exe` run without a logged-in user because they are reachable from the lock screen. Registering `cmd.exe` via IFEO there gives you a SYSTEM-level shell without any login. This was a well-known technique for years (ATT&CK T1546.012).

## What is SilentProcessExit?
SilentProcessExit works differently from the classic `Debugger` value and lives in a place many defender scripts do not monitor.

With the `Debugger` value, you actively intervene before the process runs and can disrupt the program's startup — potentially disturbing system operation.

With SilentProcessExit, the target process always runs cleanly. If there is a bug in the attacker's code, only the attacker's payload fails to execute — everything else continues normally.

## Where to hide it?
The Windows boot sequence (simplified):
```
BIOS/UEFI
    ↓
Bootloader (bootmgr)
    ↓
Windows Kernel + HAL
    ↓
smss.exe  ← Session Manager, first user-mode process
    ↓
csrss.exe + wininit.exe
    ↓
services.exe  ← starts all auto-start services
    ↓
winlogon.exe
    ↓
LogonUI / userinit.exe  ← login happens here
```

**userinit.exe**
- Runs at every login
- Initialises the user shell (starts `explorer.exe`), processes Group Policy scripts
- Then exits — making it a reliable SilentProcessExit trigger on every user logon

## How it works

### The two keys

**Step 1 — under IFEO:**
```
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\userinit.exe
    GlobalFlag = 0x200  (REG_DWORD)
```
The `GlobalFlag` value `0x200` means: "Monitor this process for its exit." It is what activates the mechanism in the first place.

**Step 2 — in a new location:**
```
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\userinit.exe
    MonitorProcess = "C:\Windows\System32\cmd.exe /c echo Pwn3d > C:\Users\Public\Documents\pwned.txt"
    ReportingMode  = 0x1  (REG_DWORD)
```
`MonitorProcess` is the payload. `ReportingMode = 1` tells Windows: "Launch this process instead of just writing a dump."

### How they interact
```
userinit.exe exits (every user logon)
      ↓
Windows Kernel checks: GlobalFlag 0x200 set?
      ↓ yes
Windows reads SilentProcessExit\userinit.exe
      ↓
Launches MonitorProcess
```

### Script contents
The payload runs inline — no dropped file required:
```
cmd.exe /c echo Pwn3d > C:\Users\Public\Documents\pwned.txt
```

### Hiding the payload

**Option A: Drop a file**

Windows has folders that:
- Already contain hundreds of `.ps1` or system files
- Are typically treated as trusted by defender scripts
- Are deeply nested

For example:
```
C:\Windows\System32\
C:\Windows\SysWOW64\
C:\ProgramData\Microsoft\
```

Disguise the file itself:
```
myScript.ps1          ← obvious
vs.
WerFaultSecure.ps1    ← sounds like Windows
```

Obscure the file extension — you can rename the script and PowerShell will still execute it:
```
WerFaultSecure.log
WerFaultSecure.dat
```
```
powershell.exe -ExecutionPolicy Bypass -File "C:\Windows\Temp\WerFaultSecure.dat"
```
PowerShell ignores the extension and executes the contents.

**Option B: Inline command in the registry value**
```
MonitorProcess = "cmd.exe /c echo Pwn3d > C:\Users\Public\Documents\pwned.txt"
```

### Protection against deletion

**Registry ACLs** — this is the real protection:
```
Defender finds your SilentProcessExit entry
    ↓
Tries to delete it
    ↓
Access denied
```
If the defender cannot delete your registry key, it does not matter whether it finds it.

#### Layer 1: Deny ACE for Everyone

Both keys (`IFEO\userinit.exe` and `SilentProcessExit\userinit.exe`) get a Deny ACE for `Everyone` covering:

| Right | Blocks |
|---|---|
| `Delete` | Deleting the key itself |
| `SetValue` | Removing or modifying values within the key |
| `ChangePermissions` | Modifying the DACL to remove the Deny rules |
| `TakeOwnership` | Taking ownership via the DACL path |

Denying `ChangePermissions` is the critical addition. Without it, a defender that opens the key with `ChangePermissions` access can simply strip the Deny rules before proceeding — which is exactly what advanced defender scripts do.

#### Layer 2: TrustedInstaller as owner

After setting the Deny ACE, ownership of both keys is transferred to `NT SERVICE\TrustedInstaller`.

Why this matters: in Windows, the owner of an object always retains `WRITE_DAC` (the right to modify the DACL), regardless of what the DACL says. If Administrators owned the key, any elevated process could use that implicit `WRITE_DAC` to rewrite the ACL. With TrustedInstaller as owner, that path is closed.

#### Why this requires SeRestorePrivilege

Setting the owner to an account you are not a member of requires `SeRestorePrivilege` to be explicitly enabled in the process token. This privilege is present but disabled by default in elevated admin tokens — it must be activated via `AdjustTokenPrivileges` before calling `SetAccessControl`. The script does this via a small P/Invoke helper.

The order is:
```
1. Create keys + set values
2. Enable SeRestorePrivilege + SeTakeOwnershipPrivilege (P/Invoke)
3. Set owner → TrustedInstaller        ← must happen before the Deny
4. Set Deny ACE (Delete|SetValue|ChangePermissions|TakeOwnership)
```
Step 3 must come before step 4: once `TakeOwnership` is denied, opening the key with that access right fails.

#### Remaining attack surface for the defender

The only reliable bypass at this point is:
1. Enable `SeTakeOwnershipPrivilege` explicitly in the token
2. Take ownership back (e.g. to Administrators)
3. Rewrite the DACL
4. Delete the key

A standard defender script that only calls `Remove-Item -Force` or tries `OpenSubKey` with `ChangePermissions` will fail at every step.

Even if the defender finds everything, the ACL buys the decisive moment:
```
Defender finds entry + cannot delete it (ACL)
    ↓
Reboot / next logon
    ↓
SilentProcessExit triggers anyway
    ↓
pwned.txt is created
    ↓
Attacker wins
```
