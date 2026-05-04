# appinitdlls

Leert `AppInit_DLLs` in beiden Registry-Pfaden (x64 und Wow64) und loescht referenzierte DLL-Dateien.

## Geprueft

- `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows` → AppInit_DLLs
- `HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Windows` → AppInit_DLLs

## Vorgehen

- Ist der Wert nicht leer, wird er auf `""` gesetzt (Key bleibt erhalten).
- `LoadAppInit_DLLs` wird auf `0` gesetzt.
- Alle referenzierten DLL-Pfade (komma-/leerzeichen-separiert) werden als Dateien geloescht.

## Rueckgabe

`[PSCustomObject]` mit `Module`, `Findings`, `Actions`, `Success`.
