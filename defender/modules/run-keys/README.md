# run-keys

Checks the four auto-start registry keys for non-whitelisted entries and removes them.

## Checked

| Key | Whitelist |
|---|---|
| `HKLM:\...\Run` | SecurityHealth |
| `HKCU:\...\Run` | OneDrive |
| `HKLM:\...\RunOnce` | msedge_cleanup_* |
| `HKCU:\...\RunOnce` | OneDrive cleanup entries |

## Approach

Only the **name** of the registry value is compared (not the path), since HKCU paths contain user-specific components.
Every entry not on the whitelist is deleted with `Remove-ItemProperty`.

## Return value

`[PSCustomObject]` with `Module`, `Findings`, `Actions`, `Success`.
