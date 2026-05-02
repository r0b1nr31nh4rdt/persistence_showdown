# netsh-helpers

Prueft alle NetSh Helper DLL-Registrierungen unter `HKLM:\SOFTWARE\Microsoft\NetSh` gegen eine Whitelist von 21 bekannten Eintraegen.

## Vorgehen

- Wertname UND DLL-Dateiname muessen uebereinstimmen.
- Bekannter Name, aber falsche DLL: Wert wird auf den korrekten Baseline-Wert zurueckgesetzt.
- Unbekannter Name: Eintrag wird geloescht.

## Rueckgabe

`[PSCustomObject]` mit `Module`, `Findings`, `Actions`, `Success`.
