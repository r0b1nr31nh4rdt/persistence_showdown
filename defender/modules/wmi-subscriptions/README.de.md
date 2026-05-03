# wmi-subscriptions

Bereinigt WMI-Persistence im Namespace `root\subscription` (EventFilter, EventConsumer, FilterToConsumerBinding).

## Vorgehen

1. **Bindings zuerst** – damit keine verwaisten Referenzen entstehen.
2. **EventFilter** – unbekannte Filter werden geloescht.
3. **EventConsumer** – alle gaengigen Consumer-Klassen werden geprueft (`CommandLineEventConsumer`, `ActiveScriptEventConsumer` etc.).

Whitelistet sind ausschliesslich die Windows-Standard-Eintraege:
- Filter: `SCM Event Log Filter`
- Consumer: `SCM Event Log Consumer`

## Rueckgabe

`[PSCustomObject]` mit `Module`, `Findings`, `Actions`, `Success`.
