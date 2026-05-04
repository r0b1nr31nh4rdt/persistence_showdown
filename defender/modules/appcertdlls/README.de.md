# appcertdlls

Prueft `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCertDlls` auf Eintraege und entfernt diese inkl. der referenzierten DLL-Dateien.

## Vorgehen

- Auf einer sauberen Windows-VM existiert der Key nicht oder ist leer – jeder Eintrag ist verdaechtig.
- Fuer jeden gefundenen Wert: Registry-Eintrag entfernen, dann die referenzierte DLL-Datei loeschen.
- Existiert der Key gar nicht, wird kein Fehler geworfen.

## Rueckgabe

`[PSCustomObject]` mit `Module`, `Findings`, `Actions`, `Success`.
