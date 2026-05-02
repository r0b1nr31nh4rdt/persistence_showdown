# startup-folders

Leert beide Windows-Startup-Ordner vollstaendig – kein Whitelist-Vergleich, da auf der Challenge-VM kein legitimer Inhalt erwartet wird.

## Geprueft

- `%APPDATA%\Microsoft\Windows\Start Menu\Programs\Startup` (User)
- `C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup` (Public)

## Vorgehen

Alle Dateien in beiden Ordnern werden mit `Remove-Item -Force` geloescht. Unterordner werden nicht rekursiv bereinigt (nur Dateien direkt im Startup-Ordner).

## Rueckgabe

`[PSCustomObject]` mit `Module`, `Findings`, `Actions`, `Success`.
