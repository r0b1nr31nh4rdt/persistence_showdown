#Requires -RunAsAdministrator

$allowedFilters   = @("SCM Event Log Filter")
$allowedConsumers = @("SCM Event Log Consumer")

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== wmi-subscriptions ===" -ForegroundColor Cyan

# Bindings zuerst entfernen (referenzieren Filter und Consumer)
try {
    $bindings = @(Get-WmiObject -Namespace "root\subscription" -Class "__FilterToConsumerBinding" -ErrorAction Stop)
    foreach ($binding in $bindings) {
        $filterName   = ""
        $consumerName = ""
        if ($binding.Filter   -match 'Name="([^"]+)"') { $filterName   = $Matches[1] }
        if ($binding.Consumer -match 'Name="([^"]+)"') { $consumerName = $Matches[1] }

        $bindingAllowed = ($allowedFilters -contains $filterName) -and ($allowedConsumers -contains $consumerName)

        if ($bindingAllowed) {
            Write-Host "  [OK] Binding '$filterName' -> '$consumerName' bekannt" -ForegroundColor Green
        } else {
            $findings += "WMI Binding: '$filterName' -> '$consumerName'"
            Write-Host "  [FUND] WMI Binding: '$filterName' -> '$consumerName'" -ForegroundColor Red
            try {
                $binding | Remove-WmiObject -ErrorAction Stop
                $actions += "Binding '$filterName' -> '$consumerName' entfernt"
                Write-Host "  [OK] Binding entfernt" -ForegroundColor Green
            } catch {
                $actions += "Binding-Entfernung fehlgeschlagen: $_"
                Write-Host "  [WARN] Fehler beim Entfernen des Bindings: $_" -ForegroundColor Yellow
                $success = $false
            }
        }
    }
} catch {
    Write-Host "  [WARN] Fehler beim Abrufen der WMI Bindings: $_" -ForegroundColor Yellow
    $success = $false
}

# EventFilter pruefen
try {
    $filters = @(Get-WmiObject -Namespace "root\subscription" -Class "__EventFilter" -ErrorAction Stop)
    foreach ($filter in $filters) {
        if ($allowedFilters -contains $filter.Name) {
            Write-Host "  [OK] EventFilter '$($filter.Name)' bekannt" -ForegroundColor Green
        } else {
            $findings += "Unbekannter WMI EventFilter: '$($filter.Name)'"
            Write-Host "  [FUND] EventFilter '$($filter.Name)' nicht in Whitelist" -ForegroundColor Red
            try {
                $filter | Remove-WmiObject -ErrorAction Stop
                $actions += "EventFilter '$($filter.Name)' entfernt"
                Write-Host "  [OK] EventFilter '$($filter.Name)' entfernt" -ForegroundColor Green
            } catch {
                $actions += "EventFilter '$($filter.Name)' konnte nicht entfernt werden: $_"
                Write-Host "  [WARN] Fehler beim Entfernen von EventFilter '$($filter.Name)': $_" -ForegroundColor Yellow
                $success = $false
            }
        }
    }
} catch {
    Write-Host "  [WARN] Fehler beim Abrufen der WMI EventFilter: $_" -ForegroundColor Yellow
    $success = $false
}

# EventConsumer pruefen (alle Subklassen)
$consumerClasses = @(
    "__EventConsumer",
    "ActiveScriptEventConsumer",
    "CommandLineEventConsumer",
    "LogFileEventConsumer",
    "NTEventLogEventConsumer",
    "SMTPEventConsumer"
)

foreach ($className in $consumerClasses) {
    try {
        $consumers = @(Get-WmiObject -Namespace "root\subscription" -Class $className -ErrorAction SilentlyContinue)
        foreach ($consumer in $consumers) {
            if ($allowedConsumers -contains $consumer.Name) {
                Write-Host "  [OK] EventConsumer '$($consumer.Name)' bekannt" -ForegroundColor Green
            } else {
                $findings += "Unbekannter WMI EventConsumer ($className): '$($consumer.Name)'"
                Write-Host "  [FUND] EventConsumer '$($consumer.Name)' ($className) nicht in Whitelist" -ForegroundColor Red
                try {
                    $consumer | Remove-WmiObject -ErrorAction Stop
                    $actions += "EventConsumer '$($consumer.Name)' entfernt"
                    Write-Host "  [OK] EventConsumer '$($consumer.Name)' entfernt" -ForegroundColor Green
                } catch {
                    $actions += "EventConsumer '$($consumer.Name)' konnte nicht entfernt werden: $_"
                    Write-Host "  [WARN] Fehler beim Entfernen von Consumer '$($consumer.Name)': $_" -ForegroundColor Yellow
                    $success = $false
                }
            }
        }
    } catch {
        # Klasse nicht vorhanden – kein Fehler
    }
}

Write-Host ""

[PSCustomObject]@{
    Module   = "wmi-subscriptions"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
