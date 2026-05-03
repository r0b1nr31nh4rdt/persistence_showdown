# netsh-helpers

Checks all NetSh Helper DLL registrations under `HKLM:\SOFTWARE\Microsoft\NetSh` against a whitelist of 21 known entries.

## Approach

- Both the value name AND the DLL filename must match.
- Known name but wrong DLL: the value is reset to the correct baseline value.
- Unknown name: the entry is deleted.

## Return value

`[PSCustomObject]` with `Module`, `Findings`, `Actions`, `Success`.
