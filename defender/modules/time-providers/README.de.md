# time-providers

Prueft alle W32Time TimeProvider-Subkeys unter `HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders` gegen eine Whitelist.

## Erlaubte Provider

`NtpClient`, `NtpServer`, `VMICTimeProvider`

## Vorgehen

Unbekannte Subkeys werden mit `Remove-Item -Recurse -Force` geloescht.

## Rueckgabe

`[PSCustomObject]` mit `Module`, `Findings`, `Actions`, `Success`.
