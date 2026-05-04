# bootexecute

Ensures that `BootExecute` under `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager` contains only the default value `autocheck autochk *`.

## Approach

- If the REG_MULTI_SZ value contains additional or deviating entries, it is fully reset to the default value.
- Every entry other than `autocheck autochk *` is treated as a deviation.

## Return value

`[PSCustomObject]` with `Module`, `Findings`, `Actions`, `Success`.
