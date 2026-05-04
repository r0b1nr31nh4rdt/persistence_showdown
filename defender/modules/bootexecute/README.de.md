# bootexecute

Stellt sicher, dass `BootExecute` unter `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager` ausschliesslich den Standardwert `autocheck autochk *` enthaelt.

## Vorgehen

- Enthaelt der REG_MULTI_SZ-Wert zusaetzliche oder abweichende Eintraege, wird er vollstaendig auf den Standardwert zurueckgesetzt.
- Jeder Eintrag ausser `autocheck autochk *` gilt als Abweichung.

## Rueckgabe

`[PSCustomObject]` mit `Module`, `Findings`, `Actions`, `Success`.
