# services

Prueft alle Windows-Dienste mit StartType `Automatic` oder `Manual` gegen eine Whitelist und deaktiviert unbekannte Dienste.

## Vorgehen

- Nur Dienste mit `StartMode = Auto` oder `Manual` werden betrachtet; `Disabled` wird ignoriert.
- Per-User-Dienste haben einen Session-ID-Suffix (`_52352`, `_12345` etc.). Der Vergleich erfolgt auf Basis des **Basisnamens** (Suffix wird abgeschnitten), sodass das Modul auf jeder VM korrekt funktioniert.
- Unbekannte Dienste werden zuerst mit `Stop-Service -Force` gestoppt, dann mit `Set-Service -StartupType Disabled` dauerhaft deaktiviert.

## Rueckgabe

`[PSCustomObject]` mit `Module`, `Findings`, `Actions`, `Success`.
