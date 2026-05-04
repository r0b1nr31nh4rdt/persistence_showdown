# services

Checks all Windows services with StartType `Automatic` or `Manual` against a whitelist and disables unknown services.

## Approach

- Only services with `StartMode = Auto` or `Manual` are considered; `Disabled` is ignored.
- Per-user services have a session ID suffix (`_52352`, `_12345`, etc.). Comparison is based on the **base name** (suffix is stripped), so the module works correctly on every VM.
- Unknown services are first stopped with `Stop-Service -Force`, then permanently disabled with `Set-Service -StartupType Disabled`.

## Return value

`[PSCustomObject]` with `Module`, `Findings`, `Actions`, `Success`.
