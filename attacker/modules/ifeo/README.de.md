# Image File Execution Options (IFEO)

## Was ist das überhaupt?
IFEO ist ein Feature von Windows, das ursprünglich für Entwickler und Debugger gedacht war – also für legitime Zwecke entstanden ist. Der Name verrät schon viel: Es geht um Optionen, die beim Ausführen einer Image-Datei (also einer .exe) greifen.

Die Grundidee ist simpel: Ein Entwickler möchte ein Programm debuggen, sobald es startet – egal, wer es startet, egal aus welchem Kontext. Windows soll also automatisch den Debugger starten und das eigentliche Programm daran "anhängen". Das ist praktisch, weil man sonst den Debugger immer manuell an einen laufenden Prozess hängen müsste, was bei bestimmten Problemen (Race Conditions beim Start z.B.) gar nicht funktioniert.

## Woher kommt es?
IFEO existiert seit den frühen NT-Versionen – also mindestens seit Windows NT 3.1 (Anfang der 90er). Es wurde von Microsoft als offizielles Debugging-Werkzeug eingeführt und ist bis heute Teil von Windows. Du findest es im Sysinternals-Umfeld dokumentiert, und Microsoft selbst schreibt offen darüber.

Der Registry-Pfad, um den sich alles dreht:
```
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\
```

## Wie funktioniert der Kern-Mechanismus?
Wenn Windows eine .exe startet, schaut der Windows Loader in diesem Registry-Schlüssel nach, ob es einen Unterordner mit dem exakten Dateinamen der Executable gibt – also z.B. `notepad.exe`. Existiert dort ein `Debugger`-Wert, passiert folgendes:

Windows startet nicht `notepad.exe` direkt, sondern startet stattdessen den im `Debugger`-Wert angegebenen Prozess – und übergibt den originalen Pfad zu `notepad.exe` als Kommandozeilenargument.

Konkret: Wenn du
```
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe
    Debugger = "C:\dbg\windbg.exe"
```
setzt und dann jemand Notepad startet, passiert intern:
```
C:\dbg\windbg.exe "C:\Windows\System32\notepad.exe"
```
Der Debugger bekommt Notepad als Argument und kann es kontrolliert starten.

## Warum ist das aus Sicherheitsperspektive interessant?
Jetzt kommt der entscheidende Punkt: Windows prüft nicht, ob der `Debugger`-Wert wirklich ein Debugger ist. Es ist nur ein Pfad zu einer Executable. Das heißt: Du kannst dort beliebige Programme eintragen.

Außerdem greift der Mechanismus systemweit und für alle Benutzer – weil der Schlüssel unter HKLM liegt (also in der Hive, die Administratorrechte zum Schreiben braucht, aber beim Lesen für alle gilt).

Das macht IFEO zu einem klassischen Persistence-Mechanismus für Angreifer:

- Kein neuer Prozess, der im Autostart auffällt
- Kein Scheduled Task
- Kein Service
- Stattdessen: Das Malware-Programm startet genau dann, wenn ein legitimes Programm gestartet wird – also zuverlässig und unauffällig

Ein klassisches Beispiel aus der Praxis (und aus Penetration Tests): Die Accessibility-Tools auf dem Windows-Sperrbildschirm. Programme wie `sethc.exe` (Sticky Keys) oder `utilman.exe` laufen ohne angemeldeten Benutzer, weil sie vom Sperrbildschirm aus erreichbar sind. Wenn man dort per IFEO eine `cmd.exe` einträgt, bekommt man eine Shell mit SYSTEM-Rechten – ohne Login. Das war jahrelang eine bekannte Technik (ATT&CK T1546.012).

## Was ist SilentProcessExit?
SilentProcessExit funktioniert anders als der klassische `Debugger`-Wert und liegt an einer Stelle, die viele Defender-Scripts nicht auf dem Radar haben.

Mit dem `Debugger`-Wert greife ich vor der Prozess-Ausführung aktiv ein und kann den Start des Programms beeinträchtigen und das System bei seiner Arbeit stören.

Mit SilentProcessExit wird der Zielprozess auf jeden Fall sauber ausgeführt. Wenn ein Fehler in meinem Code ist, wird mein Teil nicht ausgeführt – Pech für mich – aber sonst läuft alles weiter.

## Wo verstecken?
Die Boot-Reihenfolge in Windows (vereinfacht):
```
BIOS/UEFI
    ↓
Bootloader (bootmgr)
    ↓
Windows Kernel + HAL
    ↓
smss.exe  ← Session Manager, erster User-Mode Prozess
    ↓
csrss.exe + wininit.exe
    ↓
services.exe  ← startet alle Auto-Start Dienste
    ↓
winlogon.exe
    ↓
LogonUI / userinit.exe  ← erst hier kommt Login
```

**userinit.exe**
- Läuft bei jedem Login
- Initialisiert die User-Shell (startet `explorer.exe`), verarbeitet Group-Policy-Scripts
- Beendet sich danach – und triggert damit SilentProcessExit bei jeder Benutzeranmeldung

## Wie es funktioniert

### Die zwei Schlüssel

**Schritt 1 – unter IFEO:**
```
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\userinit.exe
    GlobalFlag = 0x200  (REG_DWORD)
```
Dieser `GlobalFlag`-Wert mit `0x200` bedeutet: "Überwache diesen Prozess auf sein Ende." Er aktiviert den Mechanismus überhaupt erst.

**Schritt 2 – an einer neuen Stelle:**
```
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\userinit.exe
    MonitorProcess = "C:\Windows\System32\cmd.exe /c echo Pwn3d > C:\Users\Public\Documents\pwned.txt"
    ReportingMode  = 0x1  (REG_DWORD)
```
`MonitorProcess` ist der Payload. `ReportingMode = 1` sagt Windows: "Starte diesen Prozess, statt nur einen Dump zu schreiben."

### Das Zusammenspiel
```
userinit.exe beendet sich (bei jeder Benutzeranmeldung)
      ↓
Windows Kernel prüft: GlobalFlag 0x200 gesetzt?
      ↓ ja
Windows schaut in SilentProcessExit\userinit.exe
      ↓
startet MonitorProcess
```

### Inhalt vom Payload
Der Payload läuft inline – keine externe Datei nötig:
```
cmd.exe /c echo Pwn3d > C:\Users\Public\Documents\pwned.txt
```

### Das Versteck

**Option A: Datei erstellen**

Windows hat Ordner die:
- Bereits hunderte von `.ps1` oder Systemdateien enthalten
- Von Defender-Scripts typischerweise als "vertrauenswürdig" behandelt werden
- Tief verschachtelt sind

Zum Beispiel:
```
C:\Windows\System32\
C:\Windows\SysWOW64\
C:\ProgramData\Microsoft\
```

Die Datei selbst tarnen:
```
meinScript.ps1          ← offensichtlich
versus
WerFaultSecure.ps1      ← klingt nach Windows
```

Dateiendung verschleiern – PowerShell interessiert die Endung nicht:
```
WerFaultSecure.log
WerFaultSecure.dat
```
```
powershell.exe -ExecutionPolicy Bypass -File "C:\Windows\Temp\WerFaultSecure.dat"
```

**Option B: Wert direkt im Registry-Schlüssel**
```
MonitorProcess = "cmd.exe /c echo Pwn3d > C:\Users\Public\Documents\pwned.txt"
```

### Der Schutz gegen Löschen

**Registry-ACLs** – das ist der eigentliche Schutz:
```
Defender findet deinen SilentProcessExit-Eintrag
    ↓
Versucht ihn zu löschen
    ↓
Zugriff verweigert
```
Wenn der Defender deinen Registry-Schlüssel nicht löschen kann, ist es egal ob er ihn findet.

#### Schicht 1: Deny-ACE für Everyone

Beide Schlüssel (`IFEO\userinit.exe` und `SilentProcessExit\userinit.exe`) bekommen eine Deny-ACE für `Everyone` mit folgenden Rechten:

| Recht | Blockiert |
|---|---|
| `Delete` | Den Schlüssel selbst löschen |
| `SetValue` | Werte im Schlüssel ändern oder löschen |
| `ChangePermissions` | Die DACL anpassen um die Deny-Regeln zu entfernen |
| `TakeOwnership` | Ownership über den DACL-Pfad übernehmen |

`ChangePermissions` zu denyen ist die entscheidende Ergänzung. Ohne diese Einschränkung kann ein Defender-Script den Schlüssel mit `ChangePermissions`-Recht öffnen, die Deny-Regeln einfach wegräumen und danach normal löschen – genau das machen fortgeschrittene Defender-Scripts.

#### Schicht 2: TrustedInstaller als Owner

Nach dem Setzen der Deny-ACE wird der Owner beider Schlüssel auf `NT SERVICE\TrustedInstaller` umgestellt.

Warum das wichtig ist: In Windows hat der Owner eines Objekts immer implizit `WRITE_DAC` – also das Recht, die DACL zu ändern – egal was die DACL selbst sagt. Wenn Administrators Owner wären, könnte jeder elevated Prozess dieses implizite Recht nutzen um die ACL neu zu schreiben. Mit TrustedInstaller als Owner ist dieser Weg geschlossen.

#### Warum SeRestorePrivilege nötig ist

Den Owner auf ein Konto zu setzen, dem man selbst nicht angehört, erfordert dass `SeRestorePrivilege` explizit im Prozess-Token aktiviert ist. Dieses Privilege ist in elevated Admin-Tokens vorhanden, aber standardmäßig deaktiviert – es muss vor dem `SetAccessControl`-Aufruf über `AdjustTokenPrivileges` aktiviert werden. Das Script erledigt das über einen kleinen P/Invoke-Helper.

Die Reihenfolge ist dabei zwingend:
```
1. Schlüssel erstellen + Werte setzen
2. SeRestorePrivilege + SeTakeOwnershipPrivilege aktivieren (P/Invoke)
3. Owner → TrustedInstaller setzen        ← muss vor dem Deny passieren
4. Deny-ACE setzen (Delete|SetValue|ChangePermissions|TakeOwnership)
```
Schritt 3 muss vor Schritt 4 kommen: Sobald `TakeOwnership` in der Deny-ACE steht, schlägt das Öffnen des Schlüssels mit diesem Zugriffsrecht fehl.

#### Verbleibende Angriffsfläche für den Defender

Der einzig zuverlässige Bypass ist jetzt:
1. `SeTakeOwnershipPrivilege` explizit im Token aktivieren
2. Ownership zurückholen (z.B. auf Administrators)
3. DACL neu schreiben
4. Schlüssel löschen

Ein Standard-Defender-Script, das nur `Remove-Item -Force` aufruft oder versucht den Schlüssel mit `ChangePermissions` zu öffnen, scheitert an jedem dieser Schritte.

Selbst im schlechtesten Fall – Defender findet alles – schützt die ACL den entscheidenden Moment:
```
Defender findet Eintrag + kann nicht löschen (ACL)
    ↓
Reboot / nächste Anmeldung
    ↓
SilentProcessExit triggert trotzdem
    ↓
pwned.txt wird erstellt
    ↓
Attacker gewinnt
```
