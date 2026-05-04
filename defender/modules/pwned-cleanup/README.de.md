# pwned-cleanup

Loescht `C:\Users\Public\Documents\pwned.txt`, falls die Datei vorhanden ist.

## Vorgehen

- Existiert die Datei nicht, wird kein Fehler geworfen.
- Existiert sie, wird sie mit `Remove-Item -Force` geloescht.

## Rueckgabe

`[PSCustomObject]` mit `Module`, `Findings`, `Actions`, `Success`.
