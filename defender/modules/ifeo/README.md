# ifeo

Scans all subkeys under `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options` for `Debugger` and `GlobalFlag` values and removes them. Also checks the `SilentProcessExit` key for any entries.

## Attack mechanism

The classic IFEO attack sets a `Debugger` value that executes an arbitrary command whenever a target process is launched.

The SilentProcessExit attack combines two registry paths:

1. `HKLM:\...\Image File Execution Options\<process.exe>` → `GlobalFlag = 0x200`
   Enables exit monitoring for the target process.
2. `HKLM:\...\SilentProcessExit\<process.exe>` → `MonitorProcess` + `ReportingMode`
   Defines the command to run when the monitored process exits.

## Approach

### Image File Execution Options

- All subkeys are iterated (one subkey per executable name).
- If a `Debugger` value is present, it is removed with `Remove-ItemProperty`.
- If a `GlobalFlag` value is present (prerequisite for SilentProcessExit), it is also removed.
- Subkeys themselves are kept intact — only the malicious values are deleted.
- No whitelist needed: a clean baseline has no Debugger or GlobalFlag entries at all.

### SilentProcessExit

- All subkeys under `HKLM:\...\SilentProcessExit` are enumerated.
- A clean system has no entries there.
- Every subkey found (including its values such as `MonitorProcess` and `ReportingMode`) is removed with `Remove-Item -Recurse`.

## Return value

`[PSCustomObject]` with `Module`, `Findings`, `Actions`, `Success`.
