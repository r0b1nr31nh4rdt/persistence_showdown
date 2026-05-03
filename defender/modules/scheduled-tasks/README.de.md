# scheduled-tasks

Prueft alle registrierten Scheduled Tasks gegen eine Whitelist von 245 bekannten System-Tasks und loescht alle unbekannten Tasks.

## Vorgehen

- Alle Tasks werden mit `Get-ScheduledTask` abgerufen.
- Verglichen wird der vollstaendige Pfad (`TaskPath + TaskName`).
- Tasks mit SID-Suffix (OneDrive, PostponeDeviceSetupToast) werden per Prefix-Match whitelistet, da der SID auf jeder VM unterschiedlich ist.
- Unbekannte Tasks werden mit `Unregister-ScheduledTask -Confirm:$false` entfernt.

## Rueckgabe

`[PSCustomObject]` mit `Module`, `Findings`, `Actions`, `Success`.
