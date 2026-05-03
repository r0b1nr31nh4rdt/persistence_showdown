# winlogon

Erzwingt die Standardwerte fuer `Userinit` und `Shell` unter `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon`.

## Standardwerte

| Wert | Soll |
|---|---|
| `Userinit` | `C:\Windows\system32\userinit.exe,` |
| `Shell` | `explorer.exe` |

## Vorgehen

Weicht einer der Werte ab, wird er sofort auf den Standardwert zurueckgesetzt (Erzwingen, nicht nur melden).

## Rueckgabe

`[PSCustomObject]` mit `Module`, `Findings`, `Actions`, `Success`.
