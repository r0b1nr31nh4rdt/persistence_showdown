# lsa-packages

Prueft LSA Security Packages und OSConfig Security Packages gegen die Baseline und setzt unbekannte Eintraege zurueck.

## Geprueft

| Schluessel | Wert | Erlaubt |
|---|---|---|
| `HKLM:\...\Control\Lsa` | `Security Packages` | (leer) |
| `HKLM:\...\Control\Lsa\OSConfig` | `Security Packages` | (leer) |

## Vorgehen

Enthaelt der REG_MULTI_SZ-Wert unbekannte Paketnamen, wird er vollstaendig auf `@("")` (leer) zurueckgesetzt. Einzelne Eintraege koennen bei diesem Werttyp nicht selektiv entfernt werden.

## Rueckgabe

`[PSCustomObject]` mit `Module`, `Findings`, `Actions`, `Success`.
