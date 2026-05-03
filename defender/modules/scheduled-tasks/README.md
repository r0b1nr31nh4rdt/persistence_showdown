# scheduled-tasks

Checks all registered Scheduled Tasks against a whitelist of 245 known system tasks and deletes all unknown tasks.

## Approach

- All tasks are retrieved with `Get-ScheduledTask`.
- The full path (`TaskPath + TaskName`) is compared.
- Tasks with a SID suffix (OneDrive, PostponeDeviceSetupToast) are whitelisted by prefix match, since the SID differs on each VM.
- Unknown tasks are removed with `Unregister-ScheduledTask -Confirm:$false`.

## Return value

`[PSCustomObject]` with `Module`, `Findings`, `Actions`, `Success`.
