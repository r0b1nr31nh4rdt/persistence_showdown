# ifeo

Durchsucht alle Subkeys unter `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options` nach einem `Debugger`-Wert und entfernt ihn.

## Vorgehen

- Alle Subkeys werden iteriert (ein Subkey pro ausfuehrbarer Datei).
- Existiert ein `Debugger`-Wert, wird er mit `Remove-ItemProperty` entfernt.
- Der Subkey selbst bleibt erhalten – nur der `Debugger`-Wert wird geloescht.
- Keine Whitelist erforderlich: auf der Baseline existiert kein einziger Debugger-Eintrag.

## Rueckgabe

`[PSCustomObject]` mit `Module`, `Findings`, `Actions`, `Success`.
