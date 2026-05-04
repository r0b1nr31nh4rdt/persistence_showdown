$filters = Get-WmiObject -Namespace "root\subscription" -Class "__EventFilter"
$consumers = Get-WmiObject -Namespace "root\subscription" -Class "__EventConsumer"
$bindings = Get-WmiObject -Namespace "root\subscription" -Class "__FilterToConsumerBinding"

$suspiciousKeywords = @('cmd', 'powershell', 'shell', 'exec', 'download', 'iex', 'invoke', 'rundll')
$suspiciousConsumers = @()

foreach ($consumer in $consumers) {
    $consumerString = $consumer | Out-String
    
    foreach ($keyword in $suspiciousKeywords) {
        if ($consumerString -match $keyword) {
            $suspiciousConsumers += [PSCustomObject]@{
                Name = $consumer.Name
                Consumer = $consumer
            }
            break
        }
    }
}
Write-Host ""
Write-Host "=== WMI Persistence Detection ===" -ForegroundColor Cyan
Write-Host ""
Write-Host "Bindings: $($bindings.Count)" -ForegroundColor Yellow
Write-Host "Event Filters: $($filters.Count)" -ForegroundColor Yellow
Write-Host "Event Consumers: $($consumers.Count)" -ForegroundColor Yellow

if ($consumers) {
    $consumers | Format-Table Name -AutoSize
}

if ($suspiciousConsumers) {
    Write-Host "`[!] SUSPICIOUS CONSUMERS DETECTED" -ForegroundColor Red
    Write-Host ""
    foreach ($consumer in $suspiciousConsumers) {
        Write-Host "Name:" -ForegroundColor Yellow
	Write-Host ""
        Write-Host "  $($consumer.Name)" -ForegroundColor White
        Write-Host ""
        
        Write-Host "Payload:" -ForegroundColor Yellow
	Write-Host ""
        Write-Host "  $($consumer.Consumer.CommandLineTemplate)" -ForegroundColor White
        Write-Host ""
        
        Write-Host "Trigger:" -ForegroundColor Yellow
	Write-Host ""
        Write-Host "  $($filters.Query)" -ForegroundColor White
        Write-Host ""
        
        Write-Host "Hidden Execution:" -ForegroundColor Yellow
	Write-Host ""
        Write-Host "  $($consumer.Consumer.RunInteractively -eq $false)" -ForegroundColor White
        Write-Host ""
        Write-Host ""
        
        Write-Host "[+] REMOVAL COMMANDS:" -ForegroundColor Green
	Write-Host ""
        Write-Host "Remove Binding: " -ForegroundColor Green -NoNewline
        Write-Host "Get-WmiObject -Namespace `"root\subscription`" -Class `"__FilterToConsumerBinding`" | Where-Object {`$_.Consumer -match `"$($consumer.Name)`"} | Remove-WmiObject -Confirm:`$false"
        
        Write-Host "Remove Event: " -ForegroundColor Green -NoNewline
        Write-Host "Get-WmiObject -Namespace `"root\subscription`" -Class `"__EventFilter`" -Filter `"Name='$($consumer.Name)'`" | Remove-WmiObject -Confirm:`$false"
        
        Write-Host "Remove Consumer: " -ForegroundColor Green -NoNewline
        Write-Host "Get-WmiObject -Namespace `"root\subscription`" -Class `"CommandLineEventConsumer`" -Filter `"Name='$($consumer.Name)'`" | Remove-WmiObject -Confirm:`$false"
        
        Write-Host ""
        Write-Host ""
    }
}
