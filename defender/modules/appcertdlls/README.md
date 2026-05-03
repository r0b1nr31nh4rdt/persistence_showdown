# appcertdlls

Checks `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCertDlls` for entries and removes them along with the referenced DLL files.

## Approach

- On a clean Windows VM the key does not exist or is empty — every entry is suspicious.
- For each value found: remove the registry entry, then delete the referenced DLL file.
- If the key does not exist at all, no error is thrown.

## Return value

`[PSCustomObject]` with `Module`, `Findings`, `Actions`, `Success`.
