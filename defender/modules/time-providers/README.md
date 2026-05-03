# time-providers

Checks all W32Time TimeProvider subkeys under `HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders` against a whitelist.

## Allowed providers

`NtpClient`, `NtpServer`, `VMICTimeProvider`

## Approach

Unknown subkeys are deleted with `Remove-Item -Recurse -Force`.

## Return value

`[PSCustomObject]` with `Module`, `Findings`, `Actions`, `Success`.
