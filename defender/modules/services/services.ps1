#Requires -RunAsAdministrator

$allowedServices = @(
    "AarSvc_52352", "ADPSvc", "ALG", "AppIDSvc", "Appinfo", "AppMgmt",
    "AppReadiness", "AppXSvc", "ApxSvc", "AssignedAccessManagerSvc",
    "AudioEndpointBuilder", "Audiosrv", "autotimesvc", "AxInstSV",
    "BcastDVRUserService_52352", "BDESVC", "BFE", "BITS",
    "BluetoothUserService_52352", "BrokerInfrastructure", "BTAGService",
    "BthAvctpSvc", "bthserv", "camsvc", "CaptureService_52352",
    "cbdhsvc_52352", "CDPSvc", "CDPUserSvc_52352", "CertPropSvc", "ClipSVC",
    "CloudBackupRestoreSvc_52352", "cloudidsvc", "COMSysApp",
    "ConsentUxUserSvc_52352", "CoreMessagingRegistrar",
    "CredentialEnrollmentManagerUserSvc_52352", "CryptSvc", "CscService",
    "DcomLaunch", "dcsvc", "defragsvc", "DeviceAssociationBrokerSvc_52352",
    "DeviceAssociationService", "DeviceInstall", "DevicePickerUserSvc_52352",
    "DevicesFlowUserSvc_52352", "DevQueryBroker", "Dhcp", "diagsvc",
    "DiagTrack", "DispBrokerDesktopSvc", "DisplayEnhancementService",
    "DmEnrollmentSvc", "dmwappushservice", "Dnscache", "DoSvc", "dot3svc",
    "DPS", "DsmSvc", "DsSvc", "DusmSvc", "EapHost", "edgeupdate",
    "edgeupdatem", "EFS", "embeddedmode", "EntAppSvc", "EventLog",
    "EventSystem", "fdPHost", "FDResPub", "fhsvc", "FontCache",
    "FrameServer", "FrameServerMonitor", "GameInputSvc", "gpsvc",
    "GraphicsPerfSvc", "hidserv", "hpatchmon", "HvHost", "icssvc", "IKEEXT",
    "InstallService", "InventorySvc", "iphlpsvc", "IpxlatCfgSvc", "KeyIso",
    "KtmRm", "LanmanServer", "LanmanWorkstation", "lfsvc", "LicenseManager",
    "lltdsvc", "lmhosts", "LocalKdc", "LSM", "LxpSvc", "MapsBroker",
    "McmSvc", "McpManagementService", "MDCoreSvc", "MessagingService_52352",
    "MicrosoftEdgeElevationService", "midisrv", "mpssvc", "MSDTC",
    "MSiSCSI", "msiserver", "NaturalAuthentication", "NcaSvc", "NcbService",
    "NcdAutoSetup", "Netlogon", "Netman", "netprofm", "NetSetupSvc",
    "NgcCtnrSvc", "NgcSvc", "NlaSvc", "NPSMSvc_52352", "nsi",
    "OneSyncSvc_52352", "P9RdrService_52352", "PcaSvc", "PeerDistSvc",
    "PenService_52352", "perceptionsimulation", "PerfHost", "PhoneSvc",
    "PimIndexMaintenanceSvc_52352", "pla", "PlugPlay", "PolicyAgent",
    "Power", "PrintDeviceConfigurationService", "PrintNotify",
    "PrintScanBrokerService", "PrintWorkflowUserSvc_52352", "ProfSvc",
    "PushToInstall", "QWAVE", "RasAuto", "RasMan", "refsdedupsvc",
    "RetailDemo", "RmSvc", "RpcEptMapper", "RpcLocator", "RpcSs", "SamSs",
    "SCardSvr", "ScDeviceEnum", "Schedule", "SCPolicySvc", "SDRSVC",
    "seclogon", "SecurityHealthService", "SEMgrSvc", "SENS", "Sense",
    "SensorDataService", "SensorService", "SensrSvc", "SessionEnv",
    "SharedAccess", "ShellHWDetection", "smphost", "SmsRouter", "SNMPTrap",
    "Spooler", "sppsvc", "SSDPSRV", "SstpSvc", "StateRepository", "StiSvc",
    "StorSvc", "svsvc", "swprv", "SysMain", "SystemEventsBroker", "TapiSrv",
    "TermService", "TextInputManagementService", "Themes",
    "TieringEngineService", "TimeBrokerSvc", "TokenBroker", "TrkWks",
    "TroubleshootingSvc", "TrustedInstaller", "UdkUserSvc_52352",
    "UmRdpService", "UnistoreSvc_52352", "upnphost", "UserDataSvc_52352",
    "UserManager", "UsoSvc", "VaultSvc", "vds", "vmicguestinterface",
    "vmicheartbeat", "vmickvpexchange", "vmicrdv", "vmicshutdown",
    "vmictimesync", "vmicvmsession", "vmicvss", "VSS", "W32Time",
    "WaaSMedicSvc", "WalletService", "WarpJITSvc", "wbengine", "WbioSrvc",
    "Wcmsvc", "wcncsvc", "WdiServiceHost", "WdiSystemHost", "WdNisSvc",
    "WebClient", "webthreatdefsvc", "webthreatdefusersvc_52352", "Wecsvc",
    "WEPHOSTSVC", "wercplsupport", "WerSvc", "WFDSConMgrSvc", "whesvc",
    "WiaRpc", "WinDefend", "WinHttpAutoProxySvc", "Winmgmt", "WinRM",
    "wisvc", "WlanSvc", "wlidsvc", "wlpasvc", "WManSvc", "wmiApSrv",
    "WMPNetworkSvc", "workfolderssvc", "WpcMonSvc", "WPDBusEnum",
    "WpnService", "WpnUserService_52352", "WSAIFabricSvc", "wscsvc",
    "WSearch", "wuauserv", "wuqisvc", "WwanSvc", "XblAuthManager",
    "XblGameSave", "XboxGipSvc", "XboxNetApiSvc", "ZTHELPER"
)

# Base names without session ID suffix (_12345) for per-user services
$allowedBaseNames = $allowedServices | ForEach-Object { $_ -replace '_\d+$', '' }

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== services ===" -ForegroundColor Cyan

try {
    $services = @(Get-WmiObject Win32_Service -ErrorAction Stop |
        Where-Object { $_.StartMode -in @('Auto', 'Manual') })

    foreach ($svc in $services) {
        $baseName = $svc.Name -replace '_\d+$', ''
        if ($allowedBaseNames -contains $baseName) {
            Write-Host "  [OK] '$($svc.Name)' whitelisted" -ForegroundColor Green
        } else {
            $findings += "Unknown service: '$($svc.Name)' (StartMode: $($svc.StartMode), Path: $($svc.PathName))"
            Write-Host "  [FIND] '$($svc.Name)' not in whitelist ($($svc.StartMode))" -ForegroundColor Red
            try {
                Stop-Service -Name $svc.Name -Force -ErrorAction SilentlyContinue
                Set-Service -Name $svc.Name -StartupType Disabled -ErrorAction Stop
                $actions += "Service '$($svc.Name)' stopped and disabled"
                Write-Host "  [OK] '$($svc.Name)' stopped and disabled" -ForegroundColor Green
            } catch {
                $actions += "Failed to disable service '$($svc.Name)': $_"
                Write-Host "  [WARN] Error processing '$($svc.Name)': $_" -ForegroundColor Yellow
                $success = $false
            }
        }
    }
} catch {
    Write-Host "  [WARN] Error retrieving services: $_" -ForegroundColor Yellow
    $success = $false
}

Write-Host ""

[PSCustomObject]@{
    Module   = "services"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
