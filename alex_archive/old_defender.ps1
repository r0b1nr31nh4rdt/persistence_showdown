#Requires -RunAsAdministrator
# defender.ps1 - strict name-whitelist cleanup for the Persistence Showdown VM.
# Loads whitelist.json, removes persistence names that are not present, and logs every action.

param(
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'
$ConfirmPreference = 'None'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Definition
$baselinePath = Join-Path $scriptDir 'whitelist.json'
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$logPath = Join-Path $scriptDir "defender-log-$stamp.json"
$quarantineRoot = Join-Path $scriptDir "quarantine-$stamp"
$payloadPath = 'C:\Users\Public\Documents\pwned.txt'
$payloadContent = 'Pwn3d'
$recentCutoff = (Get-Date).AddMinutes(-30)

# Paste whitelist.json between these markers before submitting as a single-file defender.
# If this is empty, the script loads whitelist.json from the same directory.
$EmbeddedBaselineJson = @'
{
    "RunHKLM":  [
                    "SecurityHealth",
                    "VMware User Process"
                ],
    "RunHKCU":  [
                    "MicrosoftEdgeAutoLaunch_59E7256403361B9ABAF7E8A5219C8F91",
                    "OneDrive"
                ],
    "RunOnceHKLM":  [

                    ],
    "RunOnceHKCU":  [

                    ],
    "RunWow6432NodeHKLM":  [

                           ],
    "RunOnceWow6432NodeHKLM":  [

                               ],
    "RunWow6432NodeHKCU":  [

                           ],
    "RunOnceWow6432NodeHKCU":  [

                               ],
    "ScheduledTasks":  [
                           "\\Microsoft\\Windows\\.NET Framework\\.NET Framework NGEN v4.0.30319",
                           "\\Microsoft\\Windows\\.NET Framework\\.NET Framework NGEN v4.0.30319 64",
                           "\\Microsoft\\Windows\\.NET Framework\\.NET Framework NGEN v4.0.30319 64 Critical",
                           "\\Microsoft\\Windows\\.NET Framework\\.NET Framework NGEN v4.0.30319 Critical",
                           "\\Microsoft\\Windows\\AccountHealth\\RecoverabilityToastTask",
                           "\\Microsoft\\Windows\\Active Directory Rights Management Services Client\\AD RMS Rights Policy Template Management (Automated)",
                           "\\Microsoft\\Windows\\Active Directory Rights Management Services Client\\AD RMS Rights Policy Template Management (Manual)",
                           "\\Microsoft\\Windows\\AppID\\EDP Policy Manager",
                           "\\Microsoft\\Windows\\AppID\\PolicyConverter",
                           "\\Microsoft\\Windows\\AppID\\VerifiedPublisherCertStoreCheck",
                           "\\Microsoft\\Windows\\Application Experience\\MareBackup",
                           "\\Microsoft\\Windows\\Application Experience\\Microsoft Compatibility Appraiser Exp",
                           "\\Microsoft\\Windows\\Application Experience\\PcaPatchDbTask",
                           "\\Microsoft\\Windows\\Application Experience\\SdbinstMergeDbTask",
                           "\\Microsoft\\Windows\\Application Experience\\StartupAppTask",
                           "\\Microsoft\\Windows\\ApplicationData\\appuriverifierdaily",
                           "\\Microsoft\\Windows\\ApplicationData\\appuriverifierinstall",
                           "\\Microsoft\\Windows\\ApplicationData\\CleanupTemporaryState",
                           "\\Microsoft\\Windows\\ApplicationData\\DsSvcCleanup",
                           "\\Microsoft\\Windows\\AppListBackup\\Backup",
                           "\\Microsoft\\Windows\\AppListBackup\\BackupNonMaintenance",
                           "\\Microsoft\\Windows\\AppxDeploymentClient\\Pre-staged app cleanup",
                           "\\Microsoft\\Windows\\AppxDeploymentClient\\UCPD velocity",
                           "\\Microsoft\\Windows\\Autochk\\Proxy",
                           "\\Microsoft\\Windows\\BitLocker\\BitLocker Encrypt All Drives",
                           "\\Microsoft\\Windows\\BitLocker\\BitLocker MDM policy Refresh",
                           "\\Microsoft\\Windows\\Bluetooth\\UninstallDeviceTask",
                           "\\Microsoft\\Windows\\BrokerInfrastructure\\BgTaskRegistrationMaintenanceTask",
                           "\\Microsoft\\Windows\\capabilityaccessmanager\\maintenancetasks",
                           "\\Microsoft\\Windows\\CertificateServicesClient\\AikCertEnrollTask",
                           "\\Microsoft\\Windows\\CertificateServicesClient\\CryptoPolicyTask",
                           "\\Microsoft\\Windows\\CertificateServicesClient\\KeyPreGenTask",
                           "\\Microsoft\\Windows\\CertificateServicesClient\\SystemTask",
                           "\\Microsoft\\Windows\\CertificateServicesClient\\UserTask",
                           "\\Microsoft\\Windows\\CertificateServicesClient\\UserTask-Roam",
                           "\\Microsoft\\Windows\\Chkdsk\\ProactiveScan",
                           "\\Microsoft\\Windows\\Chkdsk\\SyspartRepair",
                           "\\Microsoft\\Windows\\Clip\\License Validation",
                           "\\Microsoft\\Windows\\Clip\\LicenseImdsIntegration",
                           "\\Microsoft\\Windows\\CloudExperienceHost\\CreateObjectTask",
                           "\\Microsoft\\Windows\\CloudRestore\\Backup",
                           "\\Microsoft\\Windows\\CloudRestore\\Restore",
                           "\\Microsoft\\Windows\\ConsentUX\\UnifiedConsent\\UnifiedConsentSyncTask",
                           "\\Microsoft\\Windows\\Containers\\CmCleanup",
                           "\\Microsoft\\Windows\\Customer Experience Improvement Program\\Consolidator",
                           "\\Microsoft\\Windows\\Customer Experience Improvement Program\\UsbCeip",
                           "\\Microsoft\\Windows\\Data Integrity Scan\\Data Integrity Check And Scan",
                           "\\Microsoft\\Windows\\Data Integrity Scan\\Data Integrity Scan",
                           "\\Microsoft\\Windows\\Data Integrity Scan\\Data Integrity Scan for Crash Recovery",
                           "\\Microsoft\\Windows\\Defrag\\ScheduledDefrag",
                           "\\Microsoft\\Windows\\Device Information\\Device",
                           "\\Microsoft\\Windows\\Device Information\\Device User",
                           "\\Microsoft\\Windows\\Device Setup\\Driver Recovery on Reboot",
                           "\\Microsoft\\Windows\\Device Setup\\Metadata Refresh",
                           "\\Microsoft\\Windows\\DeviceDirectoryClient\\HandleCommand",
                           "\\Microsoft\\Windows\\DeviceDirectoryClient\\HandleWnsCommand",
                           "\\Microsoft\\Windows\\DeviceDirectoryClient\\IntegrityCheck",
                           "\\Microsoft\\Windows\\DeviceDirectoryClient\\LocateCommandUserSession",
                           "\\Microsoft\\Windows\\DeviceDirectoryClient\\RegisterDeviceAccountChange",
                           "\\Microsoft\\Windows\\DeviceDirectoryClient\\RegisterDeviceLocationRightsChange",
                           "\\Microsoft\\Windows\\DeviceDirectoryClient\\RegisterDevicePeriodic24",
                           "\\Microsoft\\Windows\\DeviceDirectoryClient\\RegisterDevicePolicyChange",
                           "\\Microsoft\\Windows\\DeviceDirectoryClient\\RegisterDeviceProtectionStateChanged",
                           "\\Microsoft\\Windows\\DeviceDirectoryClient\\RegisterDeviceSettingChange",
                           "\\Microsoft\\Windows\\DeviceDirectoryClient\\RegisterDeviceWnsFallback",
                           "\\Microsoft\\Windows\\DeviceDirectoryClient\\RegisterUserDevice",
                           "\\Microsoft\\Windows\\Diagnosis\\RecommendedTroubleshootingScanner",
                           "\\Microsoft\\Windows\\Diagnosis\\Scheduled",
                           "\\Microsoft\\Windows\\Diagnosis\\UnexpectedCodepath",
                           "\\Microsoft\\Windows\\DirectX\\DirectXDatabaseUpdater",
                           "\\Microsoft\\Windows\\DirectX\\DXGIAdapterCache",
                           "\\Microsoft\\Windows\\DiskCleanup\\SilentCleanup",
                           "\\Microsoft\\Windows\\DiskDiagnostic\\Microsoft-Windows-DiskDiagnosticDataCollector",
                           "\\Microsoft\\Windows\\DiskDiagnostic\\Microsoft-Windows-DiskDiagnosticResolver",
                           "\\Microsoft\\Windows\\DiskFootprint\\Diagnostics",
                           "\\Microsoft\\Windows\\DiskFootprint\\StorageSense",
                           "\\Microsoft\\Windows\\DUSM\\dusmtask",
                           "\\Microsoft\\Windows\\EDP\\EDP App Launch Task",
                           "\\Microsoft\\Windows\\EDP\\EDP Auth Task",
                           "\\Microsoft\\Windows\\EDP\\EDP Inaccessible Credentials Task",
                           "\\Microsoft\\Windows\\EDP\\StorageCardEncryption Task",
                           "\\Microsoft\\Windows\\ExploitGuard\\ExploitGuard MDM policy Refresh",
                           "\\Microsoft\\Windows\\Feedback\\Siuf\\DmClient",
                           "\\Microsoft\\Windows\\Feedback\\Siuf\\DmClientOnScenarioDownload",
                           "\\Microsoft\\Windows\\File Classification Infrastructure\\Property Definition Sync",
                           "\\Microsoft\\Windows\\FileHistory\\File History (maintenance mode)",
                           "\\Microsoft\\Windows\\Flighting\\FeatureConfig\\BootstrapUsageDataReporting",
                           "\\Microsoft\\Windows\\Flighting\\FeatureConfig\\GovernedFeatureUsageProcessing",
                           "\\Microsoft\\Windows\\Flighting\\FeatureConfig\\ReconcileConfigs",
                           "\\Microsoft\\Windows\\Flighting\\FeatureConfig\\ReconcileFeatures",
                           "\\Microsoft\\Windows\\Flighting\\FeatureConfig\\UsageDataFlushing",
                           "\\Microsoft\\Windows\\Flighting\\FeatureConfig\\UsageDataReceiver",
                           "\\Microsoft\\Windows\\Flighting\\FeatureConfig\\UsageDataReporting",
                           "\\Microsoft\\Windows\\Flighting\\OneSettings\\RefreshCache",
                           "\\Microsoft\\Windows\\Hotpatch\\Monitoring",
                           "\\Microsoft\\Windows\\input\\InputSettingsRestoreDataAvailable",
                           "\\Microsoft\\Windows\\input\\LocalUserSyncDataAvailable",
                           "\\Microsoft\\Windows\\input\\MouseSyncDataAvailable",
                           "\\Microsoft\\Windows\\input\\PenSyncDataAvailable",
                           "\\Microsoft\\Windows\\input\\RemoteMouseSyncDataAvailable",
                           "\\Microsoft\\Windows\\input\\RemotePenSyncDataAvailable",
                           "\\Microsoft\\Windows\\input\\RemoteTouchpadSyncDataAvailable",
                           "\\Microsoft\\Windows\\input\\syncpensettings",
                           "\\Microsoft\\Windows\\input\\TouchpadSyncDataAvailable",
                           "\\Microsoft\\Windows\\InstallService\\RestoreDevice",
                           "\\Microsoft\\Windows\\InstallService\\ScanForUpdates",
                           "\\Microsoft\\Windows\\InstallService\\ScanForUpdatesAsUser",
                           "\\Microsoft\\Windows\\InstallService\\SmartRetry",
                           "\\Microsoft\\Windows\\InstallService\\WakeUpAndContinueUpdates",
                           "\\Microsoft\\Windows\\InstallService\\WakeUpAndScanForUpdates",
                           "\\Microsoft\\Windows\\International\\Synchronize Language Settings",
                           "\\Microsoft\\Windows\\Kernel\\La57Cleanup",
                           "\\Microsoft\\Windows\\LanguageComponentsInstaller\\Installation",
                           "\\Microsoft\\Windows\\LanguageComponentsInstaller\\ReconcileLanguageResources",
                           "\\Microsoft\\Windows\\LanguageComponentsInstaller\\Uninstallation",
                           "\\Microsoft\\Windows\\License Manager\\TempSignedLicenseExchange",
                           "\\Microsoft\\Windows\\Location\\WindowsActionDialog",
                           "\\Microsoft\\Windows\\Maintenance\\WinSAT",
                           "\\Microsoft\\Windows\\Management\\Autopilot\\DetectHardwareChange",
                           "\\Microsoft\\Windows\\Management\\Autopilot\\RemediateHardwareChange",
                           "\\Microsoft\\Windows\\Management\\Provisioning\\Cellular",
                           "\\Microsoft\\Windows\\Management\\Provisioning\\Logon",
                           "\\Microsoft\\Windows\\Management\\Provisioning\\MdmDiagnosticsCleanup",
                           "\\Microsoft\\Windows\\Management\\Provisioning\\Retry",
                           "\\Microsoft\\Windows\\Management\\Provisioning\\RunOnReboot",
                           "\\Microsoft\\Windows\\Maps\\MapsToastTask",
                           "\\Microsoft\\Windows\\Maps\\MapsUpdateTask",
                           "\\Microsoft\\Windows\\MemoryDiagnostic\\AutomaticOfflineMemoryDiagnostic",
                           "\\Microsoft\\Windows\\MemoryDiagnostic\\ProcessMemoryDiagnosticEvents",
                           "\\Microsoft\\Windows\\MemoryDiagnostic\\RunFullMemoryDiagnostic",
                           "\\Microsoft\\Windows\\MUI\\LPRemove",
                           "\\Microsoft\\Windows\\Multimedia\\SystemSoundsService",
                           "\\Microsoft\\Windows\\Network Connectivity Status Indicator\\NcsiIdentifyUserProxies",
                           "\\Microsoft\\Windows\\NlaSvc\\WiFiTask",
                           "\\Microsoft\\Windows\\Offline Files\\Background Synchronization",
                           "\\Microsoft\\Windows\\Offline Files\\Logon Synchronization",
                           "\\Microsoft\\Windows\\PCRPF\\PCR Prediction Framework Firmware Update Task",
                           "\\Microsoft\\Windows\\PerformanceTrace\\RequestTrace",
                           "\\Microsoft\\Windows\\PerformanceTrace\\WhesvcToast",
                           "\\Microsoft\\Windows\\PI\\Secure-Boot-Update",
                           "\\Microsoft\\Windows\\PI\\Sqm-Tasks",
                           "\\Microsoft\\Windows\\Plug and Play\\Device Install Group Policy",
                           "\\Microsoft\\Windows\\Plug and Play\\Device Install Reboot Required",
                           "\\Microsoft\\Windows\\Plug and Play\\Sysprep Generalize Drivers",
                           "\\Microsoft\\Windows\\Pluton\\Pluton-Ksp-Provisioning",
                           "\\Microsoft\\Windows\\Power Efficiency Diagnostics\\AnalyzeSystem",
                           "\\Microsoft\\Windows\\Printing\\EduPrintProv",
                           "\\Microsoft\\Windows\\Printing\\PrinterCleanupTask",
                           "\\Microsoft\\Windows\\Printing\\PrintJobCleanupTask",
                           "\\Microsoft\\Windows\\PushToInstall\\LoginCheck",
                           "\\Microsoft\\Windows\\PushToInstall\\Registration",
                           "\\Microsoft\\Windows\\Ras\\MobilityManager",
                           "\\Microsoft\\Windows\\RecoveryEnvironment\\VerifyWinRE",
                           "\\Microsoft\\Windows\\ReFsDedupSvc\\Initialization",
                           "\\Microsoft\\Windows\\Registry\\RegIdleBackup",
                           "\\Microsoft\\Windows\\RemoteAssistance\\RemoteAssistanceTask",
                           "\\Microsoft\\Windows\\RetailDemo\\CleanupOfflineContent",
                           "\\Microsoft\\Windows\\Servicing\\OOBEFodSetup",
                           "\\Microsoft\\Windows\\Servicing\\StartComponentCleanup",
                           "\\Microsoft\\Windows\\Setup\\PITRTask",
                           "\\Microsoft\\Windows\\Setup\\SetupCleanupTask",
                           "\\Microsoft\\Windows\\Setup\\SetupRecoveryDataTask",
                           "\\Microsoft\\Windows\\SharedPC\\Account Cleanup",
                           "\\Microsoft\\Windows\\Shell\\CreateObjectTask",
                           "\\Microsoft\\Windows\\Shell\\FamilySafetyMonitor",
                           "\\Microsoft\\Windows\\Shell\\FamilySafetyRefreshTask",
                           "\\Microsoft\\Windows\\Shell\\IndexerAutomaticMaintenance",
                           "\\Microsoft\\Windows\\Shell\\ThemeAssetTask_SyncFODState",
                           "\\Microsoft\\Windows\\Shell\\ThemesSyncedImageDownload",
                           "\\Microsoft\\Windows\\Shell\\UpdateUserPictureTask",
                           "\\Microsoft\\Windows\\Shell\\UpdateUserPictureTaskContained",
                           "\\Microsoft\\Windows\\SoftwareProtectionPlatform\\SvcRestartTask",
                           "\\Microsoft\\Windows\\SoftwareProtectionPlatform\\SvcRestartTaskLogon",
                           "\\Microsoft\\Windows\\SoftwareProtectionPlatform\\SvcRestartTaskNetwork",
                           "\\Microsoft\\Windows\\SpacePort\\SpaceAgentTask",
                           "\\Microsoft\\Windows\\SpacePort\\SpaceManagerTask",
                           "\\Microsoft\\Windows\\Speech\\SpeechModelDownloadTask",
                           "\\Microsoft\\Windows\\StateRepository\\MaintenanceTasks",
                           "\\Microsoft\\Windows\\Storage Tiers Management\\Storage Tiers Management Initialization",
                           "\\Microsoft\\Windows\\Storage Tiers Management\\Storage Tiers Optimization",
                           "\\Microsoft\\Windows\\Subscription\\EnableLicenseAcquisition",
                           "\\Microsoft\\Windows\\Subscription\\LicenseAcquisition",
                           "\\Microsoft\\Windows\\Sustainability\\PowerGridForecastTask",
                           "\\Microsoft\\Windows\\Sustainability\\SustainabilityTelemetry",
                           "\\Microsoft\\Windows\\Sysmain\\HybridDriveCachePrepopulate",
                           "\\Microsoft\\Windows\\Sysmain\\HybridDriveCacheRebalance",
                           "\\Microsoft\\Windows\\Sysmain\\ResPriStaticDbSync",
                           "\\Microsoft\\Windows\\Sysmain\\WsSwapAssessmentTask",
                           "\\Microsoft\\Windows\\SystemRestore\\SR",
                           "\\Microsoft\\Windows\\Task Manager\\Interactive",
                           "\\Microsoft\\Windows\\TextServicesFramework\\MsCtfMonitor",
                           "\\Microsoft\\Windows\\Time Synchronization\\ForceSynchronizeTime",
                           "\\Microsoft\\Windows\\Time Synchronization\\SynchronizeTime",
                           "\\Microsoft\\Windows\\Time Zone\\SynchronizeTimeZone",
                           "\\Microsoft\\Windows\\TPM\\Tpm-HASCertRetr",
                           "\\Microsoft\\Windows\\TPM\\Tpm-Maintenance",
                           "\\Microsoft\\Windows\\TPM\\Tpm-PreAttestationHealthCheck",
                           "\\Microsoft\\Windows\\UpdateOrchestrator\\Report policies",
                           "\\Microsoft\\Windows\\UpdateOrchestrator\\Schedule Maintenance Work",
                           "\\Microsoft\\Windows\\UpdateOrchestrator\\Schedule Scan",
                           "\\Microsoft\\Windows\\UpdateOrchestrator\\Schedule Scan Static Task",
                           "\\Microsoft\\Windows\\UpdateOrchestrator\\Schedule Wake To Work",
                           "\\Microsoft\\Windows\\UpdateOrchestrator\\Schedule Work",
                           "\\Microsoft\\Windows\\UpdateOrchestrator\\Start Oobe Expedite Work",
                           "\\Microsoft\\Windows\\UpdateOrchestrator\\StartOobeAppsScan_LicenseAccepted",
                           "\\Microsoft\\Windows\\UpdateOrchestrator\\StartOobeAppsScanAfterUpdate",
                           "\\Microsoft\\Windows\\UpdateOrchestrator\\UIEOrchestrator",
                           "\\Microsoft\\Windows\\UpdateOrchestrator\\USO_UxBroker",
                           "\\Microsoft\\Windows\\UpdateOrchestrator\\UUS Failover Task",
                           "\\Microsoft\\Windows\\UPnP\\UPnPHostConfig",
                           "\\Microsoft\\Windows\\UsageAndQualityInsights\\UsageAndQualityInsights-MaintenanceTask",
                           "\\Microsoft\\Windows\\USB\\Usb-Notifications",
                           "\\Microsoft\\Windows\\User Profile Service\\HiveUploadTask",
                           "\\Microsoft\\Windows\\WaaSMedic\\PerformRemediation",
                           "\\Microsoft\\Windows\\WCM\\WiFiTask",
                           "\\Microsoft\\Windows\\WDI\\ResolutionHost",
                           "\\Microsoft\\Windows\\Windows Defender\\Windows Defender Cache Maintenance",
                           "\\Microsoft\\Windows\\Windows Defender\\Windows Defender Cleanup",
                           "\\Microsoft\\Windows\\Windows Defender\\Windows Defender Scheduled Scan",
                           "\\Microsoft\\Windows\\Windows Defender\\Windows Defender Verification",
                           "\\Microsoft\\Windows\\Windows Error Reporting\\QueueReporting",
                           "\\Microsoft\\Windows\\Windows Filtering Platform\\BfeOnServiceStartTypeChange",
                           "\\Microsoft\\Windows\\Windows Media Sharing\\UpdateLibrary",
                           "\\Microsoft\\Windows\\WindowsAI\\Recall\\InitialConfiguration",
                           "\\Microsoft\\Windows\\WindowsAI\\Recall\\PolicyConfiguration",
                           "\\Microsoft\\Windows\\WindowsAI\\Settings\\InitialConfiguration",
                           "\\Microsoft\\Windows\\WindowsColorSystem\\Calibration Loader",
                           "\\Microsoft\\Windows\\WindowsUpdate\\Refresh Group Policy Cache",
                           "\\Microsoft\\Windows\\WindowsUpdate\\Scheduled Start",
                           "\\Microsoft\\Windows\\Wininet\\CacheTask",
                           "\\Microsoft\\Windows\\WlanSvc\\CDSSync",
                           "\\Microsoft\\Windows\\WlanSvc\\MoProfileManagement",
                           "\\Microsoft\\Windows\\WOF\\WIM-Hash-Management",
                           "\\Microsoft\\Windows\\WOF\\WIM-Hash-Validation",
                           "\\Microsoft\\Windows\\Work Folders\\Work Folders Logon Synchronization",
                           "\\Microsoft\\Windows\\Work Folders\\Work Folders Maintenance Work",
                           "\\Microsoft\\Windows\\Workplace Join\\Automatic-Device-Join",
                           "\\Microsoft\\Windows\\Workplace Join\\Device-Sync",
                           "\\Microsoft\\Windows\\Workplace Join\\Recovery-Check",
                           "\\Microsoft\\Windows\\WwanSvc\\NotificationTask",
                           "\\Microsoft\\Windows\\WwanSvc\\OobeDiscovery",
                           "\\Microsoft\\XblGameSave\\XblGameSaveTask",
                           "\\MicrosoftEdgeUpdateTaskMachineCore{1459F4CF-81D4-4638-85D1-AABEF19FC3F0}",
                           "\\MicrosoftEdgeUpdateTaskMachineUA{5CE3BB42-79A2-4BD3-936D-F7ECDBC947FC}",
                           "\\OneDrive Reporting Task-S-1-5-21-4244925100-1860728575-961805360-1001",
                           "\\OneDrive Standalone Update Task-S-1-5-21-4244925100-1860728575-961805360-1001",
                           "\\OneDrive Startup Task-S-1-5-21-4244925100-1860728575-961805360-1001",
                           "\\SoftLanding\\S-1-5-21-4244925100-1860728575-961805360-1001\\SoftLandingCreativeManagementTask"
                       ],
    "Services":  [
                     "AarSvc_631c6",
                     "ADPSvc",
                     "ALG",
                     "AppIDSvc",
                     "Appinfo",
                     "AppMgmt",
                     "AppReadiness",
                     "AppXSvc",
                     "ApxSvc",
                     "AssignedAccessManagerSvc",
                     "AudioEndpointBuilder",
                     "Audiosrv",
                     "autotimesvc",
                     "AxInstSV",
                     "BcastDVRUserService_631c6",
                     "BDESVC",
                     "BFE",
                     "BITS",
                     "BluetoothUserService_631c6",
                     "BrokerInfrastructure",
                     "BTAGService",
                     "BthAvctpSvc",
                     "bthserv",
                     "camsvc",
                     "CaptureService_631c6",
                     "cbdhsvc_631c6",
                     "CDPSvc",
                     "CDPUserSvc_631c6",
                     "CertPropSvc",
                     "ClipSVC",
                     "CloudBackupRestoreSvc_631c6",
                     "cloudidsvc",
                     "COMSysApp",
                     "ConsentUxUserSvc_631c6",
                     "CoreMessagingRegistrar",
                     "CredentialEnrollmentManagerUserSvc_631c6",
                     "CryptSvc",
                     "CscService",
                     "DcomLaunch",
                     "dcsvc",
                     "defragsvc",
                     "DeviceAssociationBrokerSvc_631c6",
                     "DeviceAssociationService",
                     "DeviceInstall",
                     "DevicePickerUserSvc_631c6",
                     "DevicesFlowUserSvc_631c6",
                     "DevQueryBroker",
                     "Dhcp",
                     "diagsvc",
                     "DiagTrack",
                     "DispBrokerDesktopSvc",
                     "DisplayEnhancementService",
                     "DmEnrollmentSvc",
                     "dmwappushservice",
                     "Dnscache",
                     "DoSvc",
                     "dot3svc",
                     "DPS",
                     "DsmSvc",
                     "DsSvc",
                     "DusmSvc",
                     "EapHost",
                     "edgeupdate",
                     "edgeupdatem",
                     "EFS",
                     "embeddedmode",
                     "EntAppSvc",
                     "EventLog",
                     "EventSystem",
                     "fdPHost",
                     "FDResPub",
                     "fhsvc",
                     "FontCache",
                     "FrameServer",
                     "FrameServerMonitor",
                     "GameInputSvc",
                     "gpsvc",
                     "GraphicsPerfSvc",
                     "hidserv",
                     "hpatchmon",
                     "HvHost",
                     "icssvc",
                     "IKEEXT",
                     "InstallService",
                     "InventorySvc",
                     "iphlpsvc",
                     "IpxlatCfgSvc",
                     "KeyIso",
                     "KtmRm",
                     "LanmanServer",
                     "LanmanWorkstation",
                     "lfsvc",
                     "LicenseManager",
                     "lltdsvc",
                     "lmhosts",
                     "LocalKdc",
                     "LSM",
                     "LxpSvc",
                     "MapsBroker",
                     "McmSvc",
                     "McpManagementService",
                     "MessagingService_631c6",
                     "MicrosoftEdgeElevationService",
                     "midisrv",
                     "mpssvc",
                     "MSDTC",
                     "MSiSCSI",
                     "msiserver",
                     "NaturalAuthentication",
                     "NcaSvc",
                     "NcbService",
                     "NcdAutoSetup",
                     "Netlogon",
                     "Netman",
                     "netprofm",
                     "NetSetupSvc",
                     "NgcCtnrSvc",
                     "NgcSvc",
                     "NlaSvc",
                     "NPSMSvc_631c6",
                     "nsi",
                     "OneSyncSvc_631c6",
                     "P9RdrService_631c6",
                     "PcaSvc",
                     "PeerDistSvc",
                     "PenService_631c6",
                     "perceptionsimulation",
                     "PerfHost",
                     "PhoneSvc",
                     "PimIndexMaintenanceSvc_631c6",
                     "pla",
                     "PlugPlay",
                     "PolicyAgent",
                     "Power",
                     "PrintDeviceConfigurationService",
                     "PrintNotify",
                     "PrintScanBrokerService",
                     "PrintWorkflowUserSvc_631c6",
                     "ProfSvc",
                     "PushToInstall",
                     "QWAVE",
                     "RasAuto",
                     "RasMan",
                     "refsdedupsvc",
                     "RetailDemo",
                     "RmSvc",
                     "RpcEptMapper",
                     "RpcLocator",
                     "RpcSs",
                     "SamSs",
                     "SCardSvr",
                     "ScDeviceEnum",
                     "Schedule",
                     "SCPolicySvc",
                     "SDRSVC",
                     "seclogon",
                     "SecurityHealthService",
                     "SEMgrSvc",
                     "SENS",
                     "Sense",
                     "SensorDataService",
                     "SensorService",
                     "SensrSvc",
                     "SessionEnv",
                     "SharedAccess",
                     "ShellHWDetection",
                     "smphost",
                     "SmsRouter",
                     "SNMPTrap",
                     "Spooler",
                     "sppsvc",
                     "SSDPSRV",
                     "SstpSvc",
                     "StateRepository",
                     "StiSvc",
                     "StorSvc",
                     "svsvc",
                     "swprv",
                     "SysMain",
                     "SystemEventsBroker",
                     "TapiSrv",
                     "TermService",
                     "TextInputManagementService",
                     "Themes",
                     "TieringEngineService",
                     "TimeBrokerSvc",
                     "TokenBroker",
                     "TrkWks",
                     "TroubleshootingSvc",
                     "TrustedInstaller",
                     "UdkUserSvc_631c6",
                     "UmRdpService",
                     "UnistoreSvc_631c6",
                     "upnphost",
                     "UserDataSvc_631c6",
                     "UserManager",
                     "UsoSvc",
                     "VaultSvc",
                     "vds",
                     "VGAuthService",
                     "VM3DService",
                     "vmicguestinterface",
                     "vmicheartbeat",
                     "vmickvpexchange",
                     "vmicrdv",
                     "vmicshutdown",
                     "vmictimesync",
                     "vmicvmsession",
                     "vmicvss",
                     "VMTools",
                     "vmvss",
                     "VSS",
                     "W32Time",
                     "WaaSMedicSvc",
                     "WalletService",
                     "WarpJITSvc",
                     "wbengine",
                     "WbioSrvc",
                     "Wcmsvc",
                     "wcncsvc",
                     "WdiServiceHost",
                     "WdiSystemHost",
                     "WdNisSvc",
                     "WebClient",
                     "webthreatdefsvc",
                     "webthreatdefusersvc_631c6",
                     "Wecsvc",
                     "WEPHOSTSVC",
                     "wercplsupport",
                     "WerSvc",
                     "WFDSConMgrSvc",
                     "whesvc",
                     "WiaRpc",
                     "WinDefend",
                     "WinHttpAutoProxySvc",
                     "Winmgmt",
                     "WinRM",
                     "wisvc",
                     "WlanSvc",
                     "wlidsvc",
                     "wlpasvc",
                     "WManSvc",
                     "wmiApSrv",
                     "WMPNetworkSvc",
                     "workfolderssvc",
                     "WpcMonSvc",
                     "WPDBusEnum",
                     "WpnService",
                     "WpnUserService_631c6",
                     "WSAIFabricSvc",
                     "wscsvc",
                     "WSearch",
                     "wuauserv",
                     "wuqisvc",
                     "WwanSvc",
                     "XblAuthManager",
                     "XblGameSave",
                     "XboxGipSvc",
                     "XboxNetApiSvc",
                     "ZTHELPER"
                 ],
    "StartupUser":  [

                    ],
    "StartupPublic":  [

                      ],
    "WMIFilters":  [
                       "SCM Event Log Filter"
                   ],
    "WMIConsumers":  [
                         "SCM Event Log Consumer"
                     ],
    "WMIBindings":  [
                        "__EventFilter.Name=\"SCM Event Log Filter\" -\u003e NTEventLogEventConsumer.Name=\"SCM Event Log Consumer\""
                    ],
    "AppCertDlls":  [

                    ],
    "AppInitDLLs":  [

                    ],
    "AppInitDLLsWow64":  [

                         ],
    "LSASecurityPackages":  [
                                "\"\""
                            ],
    "LSAOSConfigSecurityPackages":  [

                                    ],
    "NetShHelperDLLs":  [
                            "2",
                            "4",
                            "authfwcfg",
                            "dhcpclient",
                            "dnsclient",
                            "dot3cfg",
                            "fwcfg",
                            "hnetmon",
                            "netiohlp",
                            "netprofm",
                            "nettrace",
                            "nshhttp",
                            "nshipsec",
                            "nshwfp",
                            "peerdistsh",
                            "rpc",
                            "WcnNetsh",
                            "whhelper",
                            "wlancfg",
                            "wshelper",
                            "wwancfg"
                        ],
    "PrintMonitors":  [
                          "Appmon",
                          "Local Port",
                          "Standard TCP/IP Port",
                          "USB Monitor",
                          "Virtual Port Monitor",
                          "WSD Port"
                      ],
    "BootExecute":  [
                        "autocheck autochk *"
                    ],
    "IFEO":  [

             ],
    "Winlogon":  [
                     "Shell=explorer.exe",
                     "Userinit=C:\\WINDOWS\\system32\\userinit.exe,"
                 ],
    "TimeProviders":  [
                          "NtpClient",
                          "NtpServer",
                          "VMICTimeProvider"
                      ],
    "EdgeExtensionInstallForcelistHKLM":  [

                                          ],
    "EdgeExtensionInstallForcelistHKCU":  [

                                          ],
    "EdgeExtensionSettingsHKLM":  [

                                  ],
    "EdgeExtensionSettingsHKCU":  [

                                  ],
    "OfficeStartupFiles":  [

                           ],
    "OfficeAddins":  [

                     ],
    "COMAddins":  [

                  ],
    "PowerShellProfiles":  [

                           ],
    "Shortcuts":  [
                      "Administrative Tools.lnk",
                      "Character Map.lnk",
                      "Command Prompt.lnk",
                      "Component Services.lnk",
                      "Computer Management.lnk",
                      "Control Panel.lnk",
                      "dfrgui.lnk",
                      "Disk Cleanup.lnk",
                      "Event Viewer.lnk",
                      "File Explorer.lnk",
                      "iSCSI Initiator.lnk",
                      "LiveCaptions.lnk",
                      "Magnify.lnk",
                      "Memory Diagnostics Tool.lnk",
                      "Microsoft Edge.lnk",
                      "Narrator.lnk",
                      "ODBC Data Sources (32-bit).lnk",
                      "ODBC Data Sources (64-bit).lnk",
                      "OneDrive.lnk",
                      "On-Screen Keyboard.lnk",
                      "Performance Monitor.lnk",
                      "Print Management.lnk",
                      "RecoveryDrive.lnk",
                      "Registry Editor.lnk",
                      "Remote Desktop Connection.lnk",
                      "Resource Monitor.lnk",
                      "Run.lnk",
                      "Security Configuration Management.lnk",
                      "services.lnk",
                      "Steps Recorder.lnk",
                      "System Configuration.lnk",
                      "System Information.lnk",
                      "Task Manager.lnk",
                      "Task Scheduler.lnk",
                      "VoiceAccess.lnk",
                      "Windows Defender Firewall with Advanced Security.lnk",
                      "Windows Media Player Legacy.lnk",
                      "Windows PowerShell (x86).lnk",
                      "Windows PowerShell ISE (x86).lnk",
                      "Windows PowerShell ISE.lnk",
                      "Windows PowerShell.lnk"
                  ],
    "ActiveSetup":  [
                        "{22d6f312-b0f6-11d0-94ab-0080c74c7e95}",
                        "{23FC6305-ED84-30AC-ADF1-B038624370DA}",
                        "{2C7339CF-2B09-4501-B3F3-F3508C9228ED}",
                        "{3af36230-a269-11d1-b5bf-0000f8051515}",
                        "{44BBA855-CC51-11CF-AAFA-00AA00B6015F}",
                        "{45ea75a0-a269-11d1-b5bf-0000f8051515}",
                        "{4f645220-306d-11d2-995d-00c04f98bbc9}",
                        "{5fd399c0-a70a-11d1-9948-00c04f98bbc9}",
                        "{630b1da0-b465-11d1-9948-00c04f98bbc9}",
                        "{63C63144-7C7F-31A2-B40F-8EF8149444B0}",
                        "{6BF52A52-394A-11d3-B153-00C04F79FAA6}",
                        "{6fab99d0-bab8-11d1-994a-00c04f98bbc9}",
                        "{7790769C-0471-11d2-AF11-00C04FA35D02}",
                        "{89820200-ECBD-11cf-8B85-00AA005B4340}",
                        "{89820200-ECBD-11cf-8B85-00AA005B4383}",
                        "{89B4C1CD-B018-4511-B0A1-5476DBF70820}",
                        "{9381D8F2-0288-11D0-9501-00AA00B911A5}",
                        "{9459C573-B17A-45AE-9F64-1857B5D58CEE}",
                        "{C9E9A340-D1F1-11D0-821E-444553540600}",
                        "{de5aed00-a4bf-11d1-9948-00c04f98bbc9}",
                        "{E92B03AB-B707-11d2-9CBD-0000F87A369E}",
                        "\u003e{22d6f312-b0f6-11d0-94ab-0080c74c7e95}"
                    ]
}
'@

$script:Whitelist = $null
$script:Findings = @()

function Write-Step { param([string]$Text) Write-Host "[*] $Text" -ForegroundColor Cyan }
function Write-OK { param([string]$Text) Write-Host "    [OK] $Text" -ForegroundColor Green }
function Write-Warn { param([string]$Text) Write-Host "    [WARN] $Text" -ForegroundColor Yellow }
function Write-Removed { param([string]$Text) Write-Host "    [REMOVED] $Text" -ForegroundColor Magenta }

function Add-Finding {
    param(
        [string]$Kind,
        [string]$Identity,
        [string]$Location,
        [string]$Action,
        [string]$Reason,
        [string]$Status
    )

    $script:Findings += [ordered]@{
        TimeUtc = (Get-Date).ToUniversalTime().ToString('o')
        Kind = $Kind
        Identity = $Identity
        Location = $Location
        Action = $Action
        Reason = $Reason
        Status = $Status
    }
}

function Get-WhitelistEntries {
    param([string]$Section)
    if ($null -eq $script:Whitelist) { return @() }
    $prop = $script:Whitelist.PSObject.Properties[$Section]
    if ($null -eq $prop -or $null -eq $prop.Value) { return @() }
    return @($prop.Value | ForEach-Object { [string]$_ })
}

function Test-Whitelisted {
    param([string]$Section, [string]$Identity)
    return ((Get-WhitelistEntries $Section) -contains $Identity)
}

function Join-PathIfRoot {
    param([string]$Root, [string]$Child)
    if ([string]::IsNullOrWhiteSpace($Root)) { return $null }
    return Join-Path $Root $Child
}

function Get-RegValueNames {
    param([string]$Path)
    try {
        if (-not (Test-Path $Path)) { return @() }
        $props = Get-ItemProperty -Path $Path -ErrorAction Stop
        return @($props.PSObject.Properties |
            Where-Object { $_.Name -notmatch '^PS(Path|ParentPath|ChildName|Drive|Provider)$' } |
            Select-Object -ExpandProperty Name)
    } catch {
        Write-Warn "Could not read registry values from '$Path': $_"
        return @()
    }
}

function Get-RegSubKeyItems {
    param([string[]]$Paths)
    $items = @()
    foreach ($path in $Paths) {
        try {
            if (Test-Path $path) {
                $items += @(Get-ChildItem -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
                    [ordered]@{
                        Name = $_.PSChildName
                        Path = "$path\$($_.PSChildName)"
                        PSPath = $_.PSPath
                    }
                })
            }
        } catch { Write-Warn "Could not read registry subkeys from '$path': $_" }
    }
    return @($items)
}

function Get-FileItems {
    param([string[]]$Paths, [string]$Filter = '*', [switch]$Recurse)
    $items = @()
    foreach ($path in $Paths) {
        try {
            if (Test-Path -LiteralPath $path) {
                $params = @{
                    LiteralPath = $path
                    File = $true
                    Filter = $Filter
                    ErrorAction = 'SilentlyContinue'
                }
                if ($Recurse) { $params['Recurse'] = $true }
                $items += @(Get-ChildItem @params)
            }
        } catch { Write-Warn "Could not read files from '$path': $_" }
    }
    return @($items)
}

function Get-TaskIdentity {
    param($Task)
    $taskPath = [string]$Task.TaskPath
    if (-not $taskPath.EndsWith('\')) { $taskPath += '\' }
    return "$taskPath$($Task.TaskName)"
}

function Get-TaskFilePath {
    param($Task)
    $taskPath = [string]$Task.TaskPath
    $relative = (($taskPath.TrimStart('\').TrimEnd('\') + '\' + $Task.TaskName).TrimStart('\'))
    return Join-Path (Join-Path $env:WINDIR 'System32\Tasks') $relative
}

function Get-RecentReason {
    param([string]$Path)
    try {
        if ($Path -and (Test-Path -LiteralPath $Path)) {
            $item = Get-Item -LiteralPath $Path -ErrorAction Stop
            if ($item.LastWriteTime -ge $recentCutoff) {
                return "not in whitelist; timestamp is within the last 30 minutes ($($item.LastWriteTime.ToString('s')))"
            }
        }
    } catch {}
    return 'not in whitelist'
}

function Get-ServiceExecutablePath {
    param([string]$PathName)
    if ([string]::IsNullOrWhiteSpace($PathName)) { return '' }
    $expanded = [Environment]::ExpandEnvironmentVariables($PathName.Trim())
    if ($expanded.StartsWith('"')) {
        $endQuote = $expanded.IndexOf('"', 1)
        if ($endQuote -gt 1) { return $expanded.Substring(1, $endQuote - 1) }
    }
    $match = [regex]::Match($expanded, '^[A-Za-z]:\\.*?\.exe', [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    if ($match.Success) { return $match.Value }
    return ''
}

function Get-PropertyValue {
    param($InputObject, [string]$Name, $Default = '')
    if ($null -eq $InputObject) { return $Default }
    $prop = $InputObject.PSObject.Properties[$Name]
    if ($null -eq $prop) { return $Default }
    return $prop.Value
}

function ConvertTo-TextValue {
    param($Value)
    if ($null -eq $Value) { return '' }
    if ($Value -is [array]) {
        return (@($Value | ForEach-Object { ConvertTo-TextValue $_ }) -join ' ')
    }
    return [string]$Value
}

function Get-RegValueText {
    param([string]$Path, [string]$Name)
    try {
        $key = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        return ConvertTo-TextValue (Get-PropertyValue $key $Name '')
    } catch { return '' }
}

function Get-RegSubKeyText {
    param([string]$PSPath)
    try {
        $props = Get-ItemProperty -Path $PSPath -ErrorAction SilentlyContinue
        return (@($props.PSObject.Properties |
            Where-Object { $_.Name -notmatch '^PS(Path|ParentPath|ChildName|Drive|Provider)$' } |
            ForEach-Object { "$($_.Name)=$(ConvertTo-TextValue $_.Value)" }) -join ' ')
    } catch { return '' }
}

function Get-TextPreview {
    param([string]$Path)
    try {
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return '' }
        $item = Get-Item -LiteralPath $Path -ErrorAction Stop
        if ($item.Length -gt 1048576) { return '' }
        if ($item.Extension -notmatch '^\.(ps1|bat|cmd|vbs|js|jse|wsf|hta|txt|xml)$') { return '' }
        return (Get-Content -LiteralPath $Path -Raw -ErrorAction Stop)
    } catch { return '' }
}

function Get-ShortcutText {
    param([string]$Path)
    try {
        $shell = New-Object -ComObject WScript.Shell
        $shortcut = $shell.CreateShortcut($Path)
        return "$($shortcut.TargetPath) $($shortcut.Arguments) $($shortcut.WorkingDirectory)"
    } catch { return '' }
}

function Get-TaskCommandText {
    param($Task)
    try {
        return (@($Task.Actions | ForEach-Object {
            '{0} {1} {2}' -f (Get-PropertyValue $_ 'Execute'), (Get-PropertyValue $_ 'Arguments'), (Get-PropertyValue $_ 'WorkingDirectory')
        }) -join ' ; ')
    } catch { return '' }
}

function Get-WmiObjectText {
    param($InputObject)
    try {
        return (@($InputObject.PSObject.Properties | ForEach-Object {
            "$($_.Name)=$(ConvertTo-TextValue $_.Value)"
        }) -join ' ')
    } catch { return '' }
}

function Get-ReferencedPaths {
    param([string]$Text)

    $paths = @()
    if ([string]::IsNullOrWhiteSpace($Text)) { return @($paths) }

    $expanded = [Environment]::ExpandEnvironmentVariables($Text)
    $quoted = [regex]::Matches($expanded, '["''](?<path>[A-Za-z]:\\[^"'']+)["'']')
    foreach ($match in $quoted) {
        $paths += $match.Groups['path'].Value
    }

    $fileLike = [regex]::Matches($expanded, '(?<path>[A-Za-z]:\\[^\s"''<>|?*]+?\.(?:exe|dll|ps1|bat|cmd|vbs|js|jse|wsf|hta|txt|lnk|xml))', 'IgnoreCase')
    foreach ($match in $fileLike) {
        $paths += $match.Groups['path'].Value
    }

    return @($paths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
}

function Get-RecentTimestampReason {
    param(
        [string[]]$Paths = @(),
        [string]$Text = ''
    )

    $candidates = @()
    $candidates += @($Paths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $candidates += @(Get-ReferencedPaths $Text)

    foreach ($path in @($candidates | Select-Object -Unique)) {
        try {
            $expanded = [Environment]::ExpandEnvironmentVariables($path.Trim('"', "'", ' ', "`t", "`r", "`n"))
            if (-not (Test-Path -LiteralPath $expanded)) { continue }
            $item = Get-Item -LiteralPath $expanded -ErrorAction Stop
            if ($item.LastWriteTime -ge $recentCutoff) {
                return "timestamp is within the last 30 minutes ($($item.LastWriteTime.ToString('s')))"
            }
        } catch {}
    }

    return ''
}

function Get-SuspicionAssessment {
    param([string]$Identity, [string]$Text = '', [string]$Path = '')

    $score = 0
    $reasons = @()
    $haystack = "$Identity $Text $Path"

    if ($haystack -match '(?i)pwn3d|pwned\.txt|\\users\\public\\documents\\pwned') {
        $score += 100
        $reasons += 'direct project proof-file reference'
    }
    if ($haystack -match '(?i)(-encodedcommand|\s-enc\s|frombase64string|executionpolicy\s+bypass|windowstyle\s+hidden|invoke-expression|\biex\b)') {
        $score += 45
        $reasons += 'obfuscated or bypass-style PowerShell behavior'
    }
    if ($haystack -match '(?i)\b(powershell|pwsh|cmd|wscript|cscript|mshta|rundll32|regsvr32)\.exe\b') {
        $score += 25
        $reasons += 'launches through a script/interpreter host'
    }
    if ($haystack -match '(?i)\.(ps1|bat|cmd|vbs|js|jse|wsf|hta)(\s|$|"|'')') {
        $score += 20
        $reasons += 'references a script file'
    }
    if ($haystack -match '(?i)\\(appdata|temp|downloads|desktop)\\|\\users\\public\\|\\documents\\') {
        $score += 20
        $reasons += 'references a user-writable path'
    }
    if ($haystack -match '(?i)\\programdata\\') {
        $score += 10
        $reasons += 'references ProgramData'
    }

    return [pscustomobject]@{
        Score = $score
        Reasons = @($reasons | Select-Object -Unique)
    }
}

function Get-CleanupReason {
    param(
        [string]$Section,
        [string]$Identity,
        [string]$Text = '',
        [string[]]$TimestampPath = @()
    )

    $whitelisted = Test-Whitelisted $Section $Identity
    $recentReason = Get-RecentTimestampReason -Paths $TimestampPath -Text "$Identity $Text"
    $assessment = Get-SuspicionAssessment -Identity $Identity -Text $Text -Path ($TimestampPath -join ' ')
    $suspicious = ($assessment.Score -ge 40)
    $parts = @()

    if (-not $whitelisted) {
        $parts += 'not in whitelist'
        if ($recentReason) { $parts += $recentReason }
        if ($assessment.Reasons.Count -gt 0) { $parts += "suspicious: $($assessment.Reasons -join '; ')" }
        return ($parts -join '; ')
    }

    if ($suspicious -and $recentReason) {
        $parts += "whitelisted and $recentReason"
        $parts += "whitelisted but suspicious: $($assessment.Reasons -join '; ')"
        return ($parts -join '; ')
    }

    return ''
}

function Move-ToQuarantine {
    param([System.IO.FileInfo]$File, [string]$Kind, [string]$Section, [string]$Reason = '')

    $reason = if ($Reason) { $Reason } else { Get-RecentReason $File.FullName }
    $status = if ($DryRun) { 'DryRun' } else { 'Quarantined' }
    try {
        if (-not $DryRun) {
            New-Item -ItemType Directory -Path $quarantineRoot -Force | Out-Null
            $safeName = (($File.FullName -replace '[:\\\/\s]+', '_') -replace '[^A-Za-z0-9._-]', '_').Trim('_')
            if (-not $safeName) { $safeName = [guid]::NewGuid().ToString('N') }
            $dest = Join-Path $quarantineRoot $safeName
            if (Test-Path -LiteralPath $dest) {
                $dest = Join-Path $quarantineRoot ("{0}-{1}" -f ([guid]::NewGuid().ToString('N')), $safeName)
            }
            Move-Item -LiteralPath $File.FullName -Destination $dest -Force -ErrorAction Stop
        }
        Add-Finding $Kind $File.Name $File.FullName 'Move file out of persistence location' $reason $status
        Write-Removed "$status ${Kind}: $($File.FullName)"
    } catch {
        Add-Finding $Kind $File.Name $File.FullName 'Move file out of persistence location' "$reason; error: $_" 'Failed'
        Write-Warn "Could not quarantine '$($File.FullName)': $_"
    }
}

function Invoke-RegValueCleanup {
    param([string]$Kind, [string]$Section, [string]$Path)

    foreach ($name in @(Get-RegValueNames $Path)) {
        $valueText = Get-RegValueText $Path $name
        $reason = Get-CleanupReason -Section $Section -Identity $name -Text $valueText
        if (-not $reason) { continue }
        $status = if ($DryRun) { 'DryRun' } else { 'Removed' }
        try {
            if (-not $DryRun) {
                Remove-ItemProperty -Path $Path -Name $name -Force -ErrorAction Stop
            }
            Add-Finding $Kind $name $Path 'Remove registry value' $reason $status
            Write-Removed "$status registry value: $Path -> $name"
        } catch {
            Add-Finding $Kind $name $Path 'Remove registry value' "$reason; error: $_" 'Failed'
            Write-Warn "Could not remove registry value '$Path -> $name': $_"
        }
    }
}

function Invoke-RegSubKeyCleanup {
    param([string]$Kind, [string]$Section, [string[]]$Paths)

    foreach ($item in @(Get-RegSubKeyItems $Paths)) {
        $keyText = Get-RegSubKeyText $item.PSPath
        $reason = Get-CleanupReason -Section $Section -Identity $item.Name -Text $keyText
        if (-not $reason) { continue }
        $status = if ($DryRun) { 'DryRun' } else { 'Removed' }
        try {
            if (-not $DryRun) {
                Remove-Item -Path $item.PSPath -Recurse -Force -ErrorAction Stop
            }
            Add-Finding $Kind $item.Name $item.Path 'Remove registry key' $reason $status
            Write-Removed "$status registry key: $($item.Path)"
        } catch {
            Add-Finding $Kind $item.Name $item.Path 'Remove registry key' "$reason; error: $_" 'Failed'
            Write-Warn "Could not remove registry key '$($item.Path)': $_"
        }
    }
}

function Invoke-FileCleanup {
    param([string]$Kind, [string]$Section, [string[]]$Paths, [string]$Filter = '*', [switch]$Recurse)

    foreach ($file in @(Get-FileItems -Paths $Paths -Filter $Filter -Recurse:$Recurse)) {
        $text = $file.FullName
        if ($file.Extension -ieq '.lnk') {
            $text = "$text $(Get-ShortcutText $file.FullName)"
        } else {
            $text = "$text $(Get-TextPreview $file.FullName)"
        }
        $reason = Get-CleanupReason -Section $Section -Identity $file.Name -Text $text -TimestampPath $file.FullName
        if (-not $reason) { continue }
        Move-ToQuarantine -File $file -Kind $Kind -Section $Section -Reason $reason
    }
}

function Invoke-ProfileCleanup {
    param([string[]]$Paths)

    foreach ($path in @($Paths | Where-Object { $_ -and (Test-Path -LiteralPath $_ -PathType Leaf) })) {
        $text = "$path $(Get-TextPreview $path)"
        $reason = Get-CleanupReason -Section 'PowerShellProfiles' -Identity $path -Text $text -TimestampPath $path
        if (-not $reason) { continue }
        try {
            $file = Get-Item -LiteralPath $path -ErrorAction Stop
            Move-ToQuarantine -File $file -Kind 'PowerShellProfile' -Section 'PowerShellProfiles' -Reason $reason
        } catch {
            Add-Finding 'PowerShellProfile' $path $path 'Move file out of persistence location' "$reason; error: $_" 'Failed'
        }
    }
}

function Invoke-ScheduledTaskCleanup {
    try {
        Get-ScheduledTask -ErrorAction SilentlyContinue | Sort-Object TaskPath, TaskName | ForEach-Object {
            $identity = Get-TaskIdentity $_
            $taskFile = Get-TaskFilePath $_
            $taskText = "$(Get-TaskCommandText $_) $(Get-TextPreview $taskFile)"
            $reason = Get-CleanupReason -Section 'ScheduledTasks' -Identity $identity -Text $taskText -TimestampPath $taskFile
            if (-not $reason) { return }
            $status = if ($DryRun) { 'DryRun' } else { 'Removed' }
            try {
                if (-not $DryRun) {
                    Unregister-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -Confirm:$false -ErrorAction Stop
                }
                Add-Finding 'ScheduledTask' $identity $_.TaskPath 'Unregister scheduled task' $reason $status
                Write-Removed "$status scheduled task: $identity"
            } catch {
                Add-Finding 'ScheduledTask' $identity $_.TaskPath 'Unregister scheduled task' "$reason; error: $_" 'Failed'
                Write-Warn "Could not remove scheduled task '$identity': $_"
            }
        }
    } catch { Write-Warn "Could not enumerate scheduled tasks: $_" }
}

function Invoke-ServiceCleanup {
    try {
        Get-WmiObject Win32_Service -ErrorAction Stop |
            Where-Object { $_.StartMode -in @('Auto', 'Manual') } |
            Sort-Object Name |
            ForEach-Object {
                $exePath = Get-ServiceExecutablePath $_.PathName
                $reason = Get-CleanupReason -Section 'Services' -Identity $_.Name -Text $_.PathName -TimestampPath $exePath
                if (-not $reason) { return }
                $status = if ($DryRun) { 'DryRun' } else { 'Removed' }
                try {
                    if (-not $DryRun) {
                        Stop-Service -Name $_.Name -Force -ErrorAction SilentlyContinue
                        & sc.exe delete $_.Name | Out-Null
                    }
                    Add-Finding 'Service' $_.Name $_.PathName 'Stop and delete service' $reason $status
                    Write-Removed "$status service: $($_.Name)"
                } catch {
                    Add-Finding 'Service' $_.Name $_.PathName 'Stop and delete service' "$reason; error: $_" 'Failed'
                    Write-Warn "Could not remove service '$($_.Name)': $_"
                }
            }
    } catch { Write-Warn "Could not enumerate services: $_" }
}

function Invoke-WmiBindingCleanup {
    try {
        Get-WmiObject -Namespace root\subscription -Class __FilterToConsumerBinding -ErrorAction SilentlyContinue | ForEach-Object {
            $identity = "$($_.Filter) -> $($_.Consumer)"
            $text = Get-WmiObjectText $_
            $reason = Get-CleanupReason -Section 'WMIBindings' -Identity $identity -Text $text
            if (-not $reason) { return }
            $status = if ($DryRun) { 'DryRun' } else { 'Removed' }
            try {
                if (-not $DryRun) { $_ | Remove-WmiObject -ErrorAction Stop }
                Add-Finding 'WMIBinding' $identity 'root\subscription' 'Remove WMI binding' $reason $status
                Write-Removed "$status WMI binding: $identity"
            } catch {
                Add-Finding 'WMIBinding' $identity 'root\subscription' 'Remove WMI binding' "$reason; error: $_" 'Failed'
            }
        }
    } catch { Write-Warn "Could not enumerate WMI bindings: $_" }
}

function Invoke-WmiNamedCleanup {
    param([string]$Kind, [string]$Section, [string]$ClassName)

    try {
        Get-WmiObject -Namespace root\subscription -Class $ClassName -ErrorAction SilentlyContinue | ForEach-Object {
            $text = Get-WmiObjectText $_
            $reason = Get-CleanupReason -Section $Section -Identity $_.Name -Text $text
            if (-not $reason) { return }
            $status = if ($DryRun) { 'DryRun' } else { 'Removed' }
            try {
                if (-not $DryRun) { $_ | Remove-WmiObject -ErrorAction Stop }
                Add-Finding $Kind $_.Name 'root\subscription' "Remove $Kind" $reason $status
                Write-Removed "$status ${Kind}: $($_.Name)"
            } catch {
                Add-Finding $Kind $_.Name 'root\subscription' "Remove $Kind" "$reason; error: $_" 'Failed'
            }
        }
    } catch { Write-Warn "Could not enumerate ${Kind}: $_" }
}

function Invoke-SingleRegValueMarkerCleanup {
    param([string]$Kind, [string]$Section, [string]$Path, [string]$ValueName)

    try {
        $key = Get-ItemProperty -Path $Path -Name $ValueName -ErrorAction SilentlyContinue
        if ($null -eq $key) { return }
        $prop = $key.PSObject.Properties[$ValueName]
        if ($null -eq $prop -or $null -eq $prop.Value -or [string]::IsNullOrWhiteSpace([string]$prop.Value)) { return }
        $reason = Get-CleanupReason -Section $Section -Identity $ValueName -Text (ConvertTo-TextValue $prop.Value)
        if (-not $reason) { return }

        $status = if ($DryRun) { 'DryRun' } else { 'Removed' }
        if (-not $DryRun) {
            Remove-ItemProperty -Path $Path -Name $ValueName -Force -ErrorAction Stop
        }
        Add-Finding $Kind $ValueName $Path 'Remove registry value' $reason $status
        Write-Removed "$status registry value: $Path -> $ValueName"
    } catch {
        Add-Finding $Kind $ValueName $Path 'Remove registry value' "error: $_" 'Failed'
    }
}

function Invoke-MultiStringCleanup {
    param([string]$Kind, [string]$Section, [string]$Path, [string]$ValueName)

    try {
        $key = Get-ItemProperty -Path $Path -Name $ValueName -ErrorAction SilentlyContinue
        if ($null -eq $key) { return }
        $prop = $key.PSObject.Properties[$ValueName]
        if ($null -eq $prop -or $null -eq $prop.Value) { return }
        $current = @($prop.Value | ForEach-Object { [string]$_ })
        $allowed = Get-WhitelistEntries $Section
        $extra = @($current | Where-Object { $allowed -notcontains $_ })
        if ($extra.Count -eq 0) { return }

        $status = if ($DryRun) { 'DryRun' } else { 'Removed' }
        if (-not $DryRun) {
            Set-ItemProperty -Path $Path -Name $ValueName -Value ([string[]]@($current | Where-Object { $allowed -contains $_ })) -ErrorAction Stop
        }
        Add-Finding $Kind ($extra -join ', ') $Path "Remove unlisted entries from $ValueName" 'not in whitelist' $status
        Write-Removed "$status ${Kind}: $($extra -join ', ')"
    } catch {
        Add-Finding $Kind $ValueName $Path "Remove unlisted entries from $ValueName" "not in whitelist; error: $_" 'Failed'
    }
}

function Invoke-ScalarValueCleanup {
    param([string]$Kind, [string]$Section, [string]$Path, [string]$ValueName, [string[]]$DefaultValue = @())

    try {
        $key = Get-ItemProperty -Path $Path -Name $ValueName -ErrorAction SilentlyContinue
        if ($null -eq $key) { return }
        $prop = $key.PSObject.Properties[$ValueName]
        if ($null -eq $prop -or $null -eq $prop.Value) { return }
        $current = @($prop.Value | ForEach-Object { [string]$_ })
        $allowed = Get-WhitelistEntries $Section
        $extra = @($current | Where-Object { $allowed -notcontains $_ })
        if ($extra.Count -eq 0) { return }

        $replacement = if ($allowed.Count -gt 0) { $allowed } else { $DefaultValue }
        $status = if ($DryRun) { 'DryRun' } else { 'Reverted' }
        if (-not $DryRun) {
            Set-ItemProperty -Path $Path -Name $ValueName -Value ([string[]]$replacement) -ErrorAction Stop
        }
        Add-Finding $Kind ($extra -join ', ') $Path "Revert $ValueName to whitelist" 'not in whitelist' $status
        Write-Removed "$status ${Kind}: $ValueName"
    } catch {
        Add-Finding $Kind $ValueName $Path "Revert $ValueName to whitelist" "not in whitelist; error: $_" 'Failed'
    }
}

function Invoke-WinlogonCleanup {
    try {
        $path = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon'
        $key = Get-ItemProperty $path -ErrorAction SilentlyContinue
        foreach ($name in @('Userinit', 'Shell')) {
            $prop = $key.PSObject.Properties[$name]
            if ($null -eq $prop) { continue }
            $identity = "$name=$($prop.Value)"
            if (Test-Whitelisted 'Winlogon' $identity) { continue }
            $allowed = @(Get-WhitelistEntries 'Winlogon' | Where-Object { $_ -like "$name=*" })
            if ($allowed.Count -eq 0) { continue }
            $replacement = $allowed[0].Substring(("$name=").Length)
            $status = if ($DryRun) { 'DryRun' } else { 'Reverted' }
            if (-not $DryRun) {
                Set-ItemProperty -Path $path -Name $name -Value $replacement -ErrorAction Stop
            }
            Add-Finding 'Winlogon' $identity $path "Revert $name to whitelist" 'not in whitelist' $status
            Write-Removed "$status Winlogon value: $name"
        }
    } catch {
        Add-Finding 'Winlogon' 'Winlogon' 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Winlogon' 'Revert Winlogon values' "error: $_" 'Failed'
    }
}

Write-Step "Loading whitelist"
try {
    if (-not [string]::IsNullOrWhiteSpace($EmbeddedBaselineJson)) {
        $script:Whitelist = $EmbeddedBaselineJson | ConvertFrom-Json -ErrorAction Stop
        Write-OK 'Loaded embedded whitelist'
    } elseif (Test-Path -LiteralPath $baselinePath) {
        $script:Whitelist = Get-Content -LiteralPath $baselinePath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
        Write-OK "Loaded $baselinePath"
    } else {
        throw "No embedded baseline and no whitelist.json at $baselinePath"
    }
} catch {
    Write-Host "[ERROR] Could not load whitelist. Refusing to run strict cleanup: $_" -ForegroundColor Red
    exit 2
}

$startupUser = Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu\Programs\Startup'
$startupPublic = 'C:\ProgramData\Microsoft\Windows\Start Menu\Programs\Startup'
$desktopPaths = @(
    [Environment]::GetFolderPath('Desktop'),
    'C:\Users\Public\Desktop'
) | Where-Object { $_ }
$startMenuPaths = @(
    (Join-Path $env:APPDATA 'Microsoft\Windows\Start Menu'),
    'C:\ProgramData\Microsoft\Windows\Start Menu'
) | Where-Object { $_ }
$officeStartupPaths = @(
    (Join-PathIfRoot $env:APPDATA 'Microsoft\Word\STARTUP'),
    (Join-PathIfRoot $env:APPDATA 'Microsoft\Excel\XLSTART'),
    (Join-PathIfRoot $env:ProgramFiles 'Microsoft Office\root\Office16\STARTUP'),
    (Join-PathIfRoot ${env:ProgramFiles(x86)} 'Microsoft Office\root\Office16\STARTUP')
) | Where-Object { $_ }
$powerShellProfilePaths = @(
    "$PSHOME\profile.ps1",
    "$PSHOME\Microsoft.PowerShell_profile.ps1",
    (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\profile.ps1'),
    (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'WindowsPowerShell\Microsoft.PowerShell_profile.ps1'),
    (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\profile.ps1'),
    (Join-Path ([Environment]::GetFolderPath('MyDocuments')) 'PowerShell\Microsoft.PowerShell_profile.ps1'),
    (Join-PathIfRoot $env:ProgramFiles 'PowerShell\7\profile.ps1'),
    (Join-PathIfRoot ${env:ProgramFiles(x86)} 'PowerShell\7\profile.ps1')
) | Where-Object { $_ }
$officeVersions = @('12.0', '14.0', '15.0', '16.0')
$officeApps = @('Word', 'Excel', 'PowerPoint', 'Outlook')
$officeAddinPaths = @()
foreach ($root in @('HKLM:\Software', 'HKCU:\Software', 'HKLM:\Software\WOW6432Node', 'HKCU:\Software\WOW6432Node')) {
    foreach ($version in $officeVersions) {
        foreach ($app in $officeApps) {
            $officeAddinPaths += "$root\Microsoft\Office\$version\$app\Addins"
            $officeAddinPaths += "$root\Microsoft\Office\$app\Addins"
        }
    }
}

Write-Step "Cleaning registry Run and RunOnce values"
Invoke-RegValueCleanup 'RegistryRun' 'RunHKLM' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
Invoke-RegValueCleanup 'RegistryRun' 'RunHKCU' 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run'
Invoke-RegValueCleanup 'RegistryRunOnce' 'RunOnceHKLM' 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
Invoke-RegValueCleanup 'RegistryRunOnce' 'RunOnceHKCU' 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\RunOnce'
Invoke-RegValueCleanup 'RegistryRunWow6432Node' 'RunWow6432NodeHKLM' 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
Invoke-RegValueCleanup 'RegistryRunOnceWow6432Node' 'RunOnceWow6432NodeHKLM' 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce'
Invoke-RegValueCleanup 'RegistryRunWow6432Node' 'RunWow6432NodeHKCU' 'HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'
Invoke-RegValueCleanup 'RegistryRunOnceWow6432Node' 'RunOnceWow6432NodeHKCU' 'HKCU:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\RunOnce'

Write-Step "Cleaning Startup folders"
Invoke-FileCleanup 'StartupUser' 'StartupUser' @($startupUser)
Invoke-FileCleanup 'StartupPublic' 'StartupPublic' @($startupPublic)

Write-Step "Cleaning scheduled tasks"
Invoke-ScheduledTaskCleanup

Write-Step "Cleaning Windows services"
Invoke-ServiceCleanup

Write-Step "Cleaning WMI subscriptions"
Invoke-WmiBindingCleanup
Invoke-WmiNamedCleanup 'WMIFilter' 'WMIFilters' '__EventFilter'
Invoke-WmiNamedCleanup 'WMIConsumer' 'WMIConsumers' '__EventConsumer'

Write-Step "Cleaning DLL/policy registry values"
Invoke-RegValueCleanup 'AppCertDlls' 'AppCertDlls' 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\AppCertDlls'
Invoke-SingleRegValueMarkerCleanup 'AppInitDLLs' 'AppInitDLLs' 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows' 'AppInit_DLLs'
Invoke-SingleRegValueMarkerCleanup 'AppInitDLLsWow64' 'AppInitDLLsWow64' 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows NT\CurrentVersion\Windows' 'AppInit_DLLs'
Invoke-RegValueCleanup 'NetShHelperDLLs' 'NetShHelperDLLs' 'HKLM:\SOFTWARE\Microsoft\NetSh'
Invoke-RegValueCleanup 'EdgePolicy' 'EdgeExtensionInstallForcelistHKLM' 'HKLM:\Software\Policies\Microsoft\Edge\ExtensionInstallForcelist'
Invoke-RegValueCleanup 'EdgePolicy' 'EdgeExtensionInstallForcelistHKCU' 'HKCU:\Software\Policies\Microsoft\Edge\ExtensionInstallForcelist'
Invoke-RegValueCleanup 'EdgePolicy' 'EdgeExtensionSettingsHKLM' 'HKLM:\Software\Policies\Microsoft\Edge\ExtensionSettings'
Invoke-RegValueCleanup 'EdgePolicy' 'EdgeExtensionSettingsHKCU' 'HKCU:\Software\Policies\Microsoft\Edge\ExtensionSettings'

Write-Step "Cleaning registry subkeys"
Invoke-RegSubKeyCleanup 'PrintMonitor' 'PrintMonitors' @('HKLM:\SYSTEM\CurrentControlSet\Control\Print\Monitors')
Invoke-RegSubKeyCleanup 'TimeProvider' 'TimeProviders' @('HKLM:\SYSTEM\CurrentControlSet\Services\W32Time\TimeProviders')
Invoke-RegSubKeyCleanup 'OfficeAddin' 'OfficeAddins' $officeAddinPaths
Invoke-RegSubKeyCleanup 'COMAddin' 'COMAddins' @(
    'HKLM:\Software\Microsoft\Office\Addins',
    'HKCU:\Software\Microsoft\Office\Addins',
    'HKLM:\Software\WOW6432Node\Microsoft\Office\Addins',
    'HKCU:\Software\WOW6432Node\Microsoft\Office\Addins'
)
Invoke-RegSubKeyCleanup 'ActiveSetup' 'ActiveSetup' @(
    'HKLM:\SOFTWARE\Microsoft\Active Setup\Installed Components',
    'HKCU:\SOFTWARE\Microsoft\Active Setup\Installed Components',
    'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Active Setup\Installed Components',
    'HKCU:\SOFTWARE\WOW6432Node\Microsoft\Active Setup\Installed Components'
)

Write-Step "Cleaning IFEO Debugger values"
try {
    Get-ChildItem 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options' -ErrorAction SilentlyContinue | ForEach-Object {
        $key = Get-ItemProperty $_.PSPath -Name Debugger -ErrorAction SilentlyContinue
        $debugger = Get-PropertyValue $key 'Debugger' $null
        if ($null -eq $debugger) { return }
        $reason = Get-CleanupReason -Section 'IFEO' -Identity $_.PSChildName -Text (ConvertTo-TextValue $debugger)
        if (-not $reason) { return }
        $status = if ($DryRun) { 'DryRun' } else { 'Removed' }
        if (-not $DryRun) {
            Remove-ItemProperty -Path $_.PSPath -Name Debugger -Force -ErrorAction Stop
        }
        Add-Finding 'IFEO' $_.PSChildName $_.PSPath 'Remove Debugger registry value' $reason $status
        Write-Removed "$status IFEO Debugger: $($_.PSChildName)"
    }
} catch {
    Add-Finding 'IFEO' 'IFEO' 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options' 'Remove Debugger registry value' "error: $_" 'Failed'
}

Write-Step "Cleaning scalar persistence values"
Invoke-MultiStringCleanup 'LSASecurityPackages' 'LSASecurityPackages' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa' 'Security Packages'
Invoke-MultiStringCleanup 'LSAOSConfigSecurityPackages' 'LSAOSConfigSecurityPackages' 'HKLM:\SYSTEM\CurrentControlSet\Control\Lsa\OSConfig' 'Security Packages'
Invoke-ScalarValueCleanup 'BootExecute' 'BootExecute' 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' 'BootExecute' @('autocheck autochk *')
Invoke-WinlogonCleanup

Write-Step "Cleaning Office Startup folders"
Invoke-FileCleanup 'OfficeStartupFile' 'OfficeStartupFiles' $officeStartupPaths

Write-Step "Cleaning PowerShell profiles"
Invoke-ProfileCleanup $powerShellProfilePaths

Write-Step "Cleaning shortcuts"
Invoke-FileCleanup 'Shortcut' 'Shortcuts' (@($startupUser, $startupPublic) + $desktopPaths + $startMenuPaths) -Filter '*.lnk' -Recurse

Write-Step "Removing project proof file if present"
try {
    if (Test-Path -LiteralPath $payloadPath -PathType Leaf) {
        $content = Get-Content -LiteralPath $payloadPath -Raw -ErrorAction SilentlyContinue
        $reason = Get-RecentReason $payloadPath
        if (($content.Trim()) -eq $payloadContent) {
            $reason = "$reason; contained expected project payload text"
        } else {
            $reason = "$reason; proof path existed with different content"
        }
        $status = if ($DryRun) { 'DryRun' } else { 'Removed' }
        if (-not $DryRun) {
            Remove-Item -LiteralPath $payloadPath -Force -ErrorAction Stop
        }
        Add-Finding 'PayloadFile' 'pwned.txt' $payloadPath 'Remove project proof file' $reason $status
        Write-Removed "$status payload proof file: $payloadPath"
    } else {
        Write-OK 'Project proof file not present.'
    }
} catch {
    Add-Finding 'PayloadFile' 'pwned.txt' $payloadPath 'Remove project proof file' "error: $_" 'Failed'
}

Write-Step "Writing log"
try {
    $summary = [ordered]@{
        TimeUtc = (Get-Date).ToUniversalTime().ToString('o')
        DryRun = [bool]$DryRun
        BaselinePath = $baselinePath
        QuarantinePath = if (Test-Path -LiteralPath $quarantineRoot) { $quarantineRoot } else { '' }
        FindingCount = @($script:Findings).Count
        Findings = @($script:Findings)
    }
    $summary | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $logPath -Encoding UTF8
    Write-OK "Log saved: $logPath"
} catch {
    Write-Warn "Could not write defender log: $_"
}

Write-Host ""
Write-Host ("[DONE] Defender completed. Findings handled: {0}" -f @($script:Findings).Count) -ForegroundColor Green
