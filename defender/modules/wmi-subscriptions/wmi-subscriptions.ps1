#Requires -RunAsAdministrator

$allowedFilters   = @("SCM Event Log Filter")
$allowedConsumers = @("SCM Event Log Consumer")

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== wmi-subscriptions ===" -ForegroundColor Cyan

# Remove bindings first (they reference filters and consumers)
try {
    $bindings = @(Get-WmiObject -Namespace "root\subscription" -Class "__FilterToConsumerBinding" -ErrorAction Stop)
    foreach ($binding in $bindings) {
        $filterName   = ""
        $consumerName = ""
        if ($binding.Filter   -match 'Name="([^"]+)"') { $filterName   = $Matches[1] }
        if ($binding.Consumer -match 'Name="([^"]+)"') { $consumerName = $Matches[1] }

        $bindingAllowed = ($allowedFilters -contains $filterName) -and ($allowedConsumers -contains $consumerName)

        if ($bindingAllowed) {
            Write-Host "  [OK] Binding '$filterName' -> '$consumerName' whitelisted" -ForegroundColor Green
        } else {
            $findings += "WMI Binding: '$filterName' -> '$consumerName'"
            Write-Host "  [FIND] WMI Binding: '$filterName' -> '$consumerName'" -ForegroundColor Red
            try {
                $binding | Remove-WmiObject -ErrorAction Stop
                $actions += "Binding '$filterName' -> '$consumerName' removed"
                Write-Host "  [OK] Binding removed" -ForegroundColor Green
            } catch {
                $actions += "Failed to remove binding: $_"
                Write-Host "  [WARN] Error removing binding: $_" -ForegroundColor Yellow
                $success = $false
            }
        }
    }
} catch {
    Write-Host "  [WARN] Error retrieving WMI bindings: $_" -ForegroundColor Yellow
    $success = $false
}

# Check EventFilters
try {
    $filters = @(Get-WmiObject -Namespace "root\subscription" -Class "__EventFilter" -ErrorAction Stop)
    foreach ($filter in $filters) {
        if ($allowedFilters -contains $filter.Name) {
            Write-Host "  [OK] EventFilter '$($filter.Name)' whitelisted" -ForegroundColor Green
        } else {
            $findings += "Unknown WMI EventFilter: '$($filter.Name)'"
            Write-Host "  [FIND] EventFilter '$($filter.Name)' not in whitelist" -ForegroundColor Red
            try {
                $filter | Remove-WmiObject -ErrorAction Stop
                $actions += "EventFilter '$($filter.Name)' removed"
                Write-Host "  [OK] EventFilter '$($filter.Name)' removed" -ForegroundColor Green
            } catch {
                $actions += "Failed to remove EventFilter '$($filter.Name)': $_"
                Write-Host "  [WARN] Error removing EventFilter '$($filter.Name)': $_" -ForegroundColor Yellow
                $success = $false
            }
        }
    }
} catch {
    Write-Host "  [WARN] Error retrieving WMI EventFilters: $_" -ForegroundColor Yellow
    $success = $false
}

# Check EventConsumers (all subclasses)
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
                Write-Host "  [OK] EventConsumer '$($consumer.Name)' whitelisted" -ForegroundColor Green
            } else {
                $findings += "Unknown WMI EventConsumer ($className): '$($consumer.Name)'"
                Write-Host "  [FIND] EventConsumer '$($consumer.Name)' ($className) not in whitelist" -ForegroundColor Red
                try {
                    $consumer | Remove-WmiObject -ErrorAction Stop
                    $actions += "EventConsumer '$($consumer.Name)' removed"
                    Write-Host "  [OK] EventConsumer '$($consumer.Name)' removed" -ForegroundColor Green
                } catch {
                    $actions += "Failed to remove EventConsumer '$($consumer.Name)': $_"
                    Write-Host "  [WARN] Error removing Consumer '$($consumer.Name)': $_" -ForegroundColor Yellow
                    $success = $false
                }
            }
        }
    } catch {
        # Class not present - no error
    }
}

Write-Host ""

[PSCustomObject]@{
    Module   = "wmi-subscriptions"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
