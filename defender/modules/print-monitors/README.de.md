# print-monitors

Prueft alle Print Monitor-Subkeys unter `HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors` gegen eine Whitelist von 6 bekannten Monitoren.

## Erlaubte Monitore

`Appmon`, `Local Port`, `Standard TCP/IP Port`, `USB Monitor`, `Virtual Port Monitor`, `WSD Port`

## Vorgehen

Unbekannte Subkeys werden mit `Remove-Item -Recurse -Force` geloescht.

## Rueckgabe

`[PSCustomObject]` mit `Module`, `Findings`, `Actions`, `Success`.
