# run-keys

Prueft die vier Auto-Start-Registry-Schluessel auf nicht whitelistete Eintraege und entfernt diese.

## Geprueft

| Schluessel | Whitelist |
|---|---|
| `HKLM:\...\Run` | SecurityHealth |
| `HKCU:\...\Run` | OneDrive |
| `HKLM:\...\RunOnce` | msedge_cleanup_* |
| `HKCU:\...\RunOnce` | OneDrive-Cleanup-Eintraege |

## Vorgehen

Verglichen wird ausschliesslich der **Name** des Registry-Wertes (nicht der Pfad), da HKCU-Pfade benutzerspezifische Komponenten enthalten.
Jeder Eintrag, der nicht in der Whitelist steht, wird mit `Remove-ItemProperty` geloescht.

## Rueckgabe

`[PSCustomObject]` mit `Module`, `Findings`, `Actions`, `Success`.
