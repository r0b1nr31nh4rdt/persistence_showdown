# winlogon

Enforces the default values for `Userinit` and `Shell` under `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon`.

## Default values

| Value | Expected |
|---|---|
| `Userinit` | `C:\Windows\system32\userinit.exe,` |
| `Shell` | `explorer.exe` |

## Approach

If either value deviates, it is immediately reset to the default (enforce, not just report).

## Return value

`[PSCustomObject]` with `Module`, `Findings`, `Actions`, `Success`.
