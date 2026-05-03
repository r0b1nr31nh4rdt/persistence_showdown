# ifeo

Durchsucht alle Subkeys unter `HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options` nach `Debugger`- und `GlobalFlag`-Werten und entfernt sie. Prueft zusaetzlich den `SilentProcessExit`-Schluessel auf unbekannte Eintraege.

## Angriffsmechanismus

Der klassische IFEO-Angriff setzt einen `Debugger`-Wert, der beim Start eines Prozesses einen beliebigen Befehl ausfuehrt.

Der SilentProcessExit-Angriff kombiniert zwei Schluesselpfade:

1. `HKLM:\...\Image File Execution Options\<prozess.exe>` → `GlobalFlag = 0x200`
   Aktiviert die Exit-Ueberwachung fuer den Prozess.
2. `HKLM:\...\SilentProcessExit\<prozess.exe>` → `MonitorProcess` + `ReportingMode`
   Legt fest, welcher Befehl beim Beenden des ueberwachten Prozesses ausgefuehrt wird.

## Vorgehen

### Image File Execution Options

- Alle Subkeys werden iteriert (ein Subkey pro ausfuehrbarer Datei).
- Existiert ein `Debugger`-Wert, wird er mit `Remove-ItemProperty` entfernt.
- Existiert ein `GlobalFlag`-Wert (Voraussetzung fuer SilentProcessExit), wird er ebenfalls entfernt.
- Die Subkeys selbst bleiben erhalten – nur die schaedlichen Werte werden geloescht.
- Keine Whitelist erforderlich: auf der Baseline existiert kein einziger Debugger- oder GlobalFlag-Eintrag.

### SilentProcessExit

- Alle Subkeys unter `HKLM:\...\SilentProcessExit` werden aufgelistet.
- Auf einem sauberen System existieren dort keine Eintraege.
- Jeder gefundene Subkey wird inklusive aller Werte (`MonitorProcess`, `ReportingMode`) mit `Remove-Item -Recurse` entfernt.

## Rueckgabe

`[PSCustomObject]` mit `Module`, `Findings`, `Actions`, `Success`.
