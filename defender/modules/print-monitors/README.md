# print-monitors

Checks all Print Monitor subkeys under `HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors` against a whitelist of 6 known monitors.

## Allowed monitors

`Appmon`, `Local Port`, `Standard TCP/IP Port`, `USB Monitor`, `Virtual Port Monitor`, `WSD Port`

## Approach

Unknown subkeys are deleted with `Remove-Item -Recurse -Force`.

## Return value

`[PSCustomObject]` with `Module`, `Findings`, `Actions`, `Success`.
