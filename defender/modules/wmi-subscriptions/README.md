# wmi-subscriptions

Cleans up WMI persistence in the `root\subscription` namespace (EventFilter, EventConsumer, FilterToConsumerBinding).

## Approach

1. **Bindings first** — to avoid leaving orphaned references.
2. **EventFilter** — unknown filters are deleted.
3. **EventConsumer** — all common consumer classes are checked (`CommandLineEventConsumer`, `ActiveScriptEventConsumer`, etc.).

Whitelisted are exclusively the Windows default entries:
- Filter: `SCM Event Log Filter`
- Consumer: `SCM Event Log Consumer`

## Return value

`[PSCustomObject]` with `Module`, `Findings`, `Actions`, `Success`.
