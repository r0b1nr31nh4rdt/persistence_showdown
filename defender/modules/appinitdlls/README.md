# appinitdlls

Clears `AppInit_DLLs` in both registry paths (x64 and Wow64) and deletes the referenced DLL files.

## Checked

- `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows` → AppInit_DLLs
- `HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Windows` → AppInit_DLLs

## Approach

- If the value is not empty, it is set to `""` (the key is kept).
- `LoadAppInit_DLLs` is set to `0`.
- All referenced DLL paths (comma/space-separated) are deleted as files.

## Return value

`[PSCustomObject]` with `Module`, `Findings`, `Actions`, `Success`.
