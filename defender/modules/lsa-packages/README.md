# lsa-packages

Checks LSA Security Packages and OSConfig Security Packages against the baseline and resets unknown entries.

## Checked

| Key | Value | Allowed |
|---|---|---|
| `HKLM:\...\Control\Lsa` | `Security Packages` | (empty) |
| `HKLM:\...\Control\Lsa\OSConfig` | `Security Packages` | (empty) |

## Approach

If the REG_MULTI_SZ value contains unknown package names, it is fully reset to `@("")` (empty). Individual entries cannot be selectively removed for this value type.

## Return value

`[PSCustomObject]` with `Module`, `Findings`, `Actions`, `Success`.
