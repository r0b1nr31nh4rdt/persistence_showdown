#Requires -RunAsAdministrator

$allowedTasks = @(
    "\MicrosoftEdgeUpdateTaskMachineCore{07CA4E31-97AB-4FFA-82FE-C37E834071AB}",
    "\MicrosoftEdgeUpdateTaskMachineUA{079B8D14-0FAE-4573-9ECE-2EF35CD50814}",
    "\Microsoft\Windows\.NET Framework\.NET Framework NGEN v4.0.30319",
    "\Microsoft\Windows\.NET Framework\.NET Framework NGEN v4.0.30319 64",
    "\Microsoft\Windows\.NET Framework\.NET Framework NGEN v4.0.30319 64 Critical",
    "\Microsoft\Windows\.NET Framework\.NET Framework NGEN v4.0.30319 Critical",
    "\Microsoft\Windows\AccountHealth\RecoverabilityToastTask",
    "\Microsoft\Windows\Active Directory Rights Management Services Client\AD RMS Rights Policy Template Management (Automated)",
    "\Microsoft\Windows\Active Directory Rights Management Services Client\AD RMS Rights Policy Template Management (Manual)",
    "\Microsoft\Windows\AppID\EDP Policy Manager",
    "\Microsoft\Windows\AppID\PolicyConverter",
    "\Microsoft\Windows\AppID\VerifiedPublisherCertStoreCheck",
    "\Microsoft\Windows\Application Experience\MareBackup",
    "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser Exp",
    "\Microsoft\Windows\Application Experience\PcaPatchDbTask",
    "\Microsoft\Windows\Application Experience\SdbinstMergeDbTask",
    "\Microsoft\Windows\Application Experience\StartupAppTask",
    "\Microsoft\Windows\ApplicationData\appuriverifierdaily",
    "\Microsoft\Windows\ApplicationData\appuriverifierinstall",
    "\Microsoft\Windows\ApplicationData\CleanupTemporaryState",
    "\Microsoft\Windows\ApplicationData\DsSvcCleanup",
    "\Microsoft\Windows\AppListBackup\Backup",
    "\Microsoft\Windows\AppListBackup\BackupNonMaintenance",
    "\Microsoft\Windows\AppxDeploymentClient\Pre-staged app cleanup",
    "\Microsoft\Windows\AppxDeploymentClient\UCPD velocity",
    "\Microsoft\Windows\Autochk\Proxy",
    "\Microsoft\Windows\BitLocker\BitLocker Encrypt All Drives",
    "\Microsoft\Windows\BitLocker\BitLocker MDM policy Refresh",
    "\Microsoft\Windows\Bluetooth\UninstallDeviceTask",
    "\Microsoft\Windows\BrokerInfrastructure\BgTaskRegistrationMaintenanceTask",
    "\Microsoft\Windows\capabilityaccessmanager\maintenancetasks",
    "\Microsoft\Windows\CertificateServicesClient\AikCertEnrollTask",
    "\Microsoft\Windows\CertificateServicesClient\CryptoPolicyTask",
    "\Microsoft\Windows\CertificateServicesClient\KeyPreGenTask",
    "\Microsoft\Windows\CertificateServicesClient\SystemTask",
    "\Microsoft\Windows\CertificateServicesClient\UserTask",
    "\Microsoft\Windows\CertificateServicesClient\UserTask-Roam",
    "\Microsoft\Windows\Chkdsk\ProactiveScan",
    "\Microsoft\Windows\Chkdsk\SyspartRepair",
    "\Microsoft\Windows\Clip\License Validation",
    "\Microsoft\Windows\Clip\LicenseImdsIntegration",
    "\Microsoft\Windows\CloudExperienceHost\CreateObjectTask",
    "\Microsoft\Windows\CloudRestore\Backup",
    "\Microsoft\Windows\CloudRestore\Restore",
    "\Microsoft\Windows\ConsentUX\UnifiedConsent\UnifiedConsentSyncTask",
    "\Microsoft\Windows\Containers\CmCleanup",
    "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
    "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
    "\Microsoft\Windows\Data Integrity Scan\Data Integrity Check And Scan",
    "\Microsoft\Windows\Data Integrity Scan\Data Integrity Scan",
    "\Microsoft\Windows\Data Integrity Scan\Data Integrity Scan for Crash Recovery",
    "\Microsoft\Windows\Defrag\ScheduledDefrag",
    "\Microsoft\Windows\Device Information\Device",
    "\Microsoft\Windows\Device Information\Device User",
    "\Microsoft\Windows\Device Setup\Driver Recovery on Reboot",
    "\Microsoft\Windows\Device Setup\Metadata Refresh",
    "\Microsoft\Windows\DeviceDirectoryClient\HandleCommand",
    "\Microsoft\Windows\DeviceDirectoryClient\HandleWnsCommand",
    "\Microsoft\Windows\DeviceDirectoryClient\IntegrityCheck",
    "\Microsoft\Windows\DeviceDirectoryClient\LocateCommandUserSession",
    "\Microsoft\Windows\DeviceDirectoryClient\RegisterDeviceAccountChange",
    "\Microsoft\Windows\DeviceDirectoryClient\RegisterDeviceLocationRightsChange",
    "\Microsoft\Windows\DeviceDirectoryClient\RegisterDevicePeriodic24",
    "\Microsoft\Windows\DeviceDirectoryClient\RegisterDevicePolicyChange",
    "\Microsoft\Windows\DeviceDirectoryClient\RegisterDeviceProtectionStateChanged",
    "\Microsoft\Windows\DeviceDirectoryClient\RegisterDeviceSettingChange",
    "\Microsoft\Windows\DeviceDirectoryClient\RegisterUserDevice",
    "\Microsoft\Windows\Diagnosis\RecommendedTroubleshootingScanner",
    "\Microsoft\Windows\Diagnosis\Scheduled",
    "\Microsoft\Windows\Diagnosis\UnexpectedCodepath",
    "\Microsoft\Windows\DirectX\DirectXDatabaseUpdater",
    "\Microsoft\Windows\DirectX\DXGIAdapterCache",
    "\Microsoft\Windows\DiskCleanup\SilentCleanup",
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
    "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticResolver",
    "\Microsoft\Windows\DiskFootprint\Diagnostics",
    "\Microsoft\Windows\DiskFootprint\StorageSense",
    "\Microsoft\Windows\DUSM\dusmtask",
    "\Microsoft\Windows\EDP\EDP App Launch Task",
    "\Microsoft\Windows\EDP\EDP Auth Task",
    "\Microsoft\Windows\EDP\EDP Inaccessible Credentials Task",
    "\Microsoft\Windows\EDP\StorageCardEncryption Task",
    "\Microsoft\Windows\ExploitGuard\ExploitGuard MDM policy Refresh",
    "\Microsoft\Windows\Feedback\Siuf\DmClient",
    "\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload",
    "\Microsoft\Windows\File Classification Infrastructure\Property Definition Sync",
    "\Microsoft\Windows\FileHistory\File History (maintenance mode)",
    "\Microsoft\Windows\Flighting\FeatureConfig\BootstrapUsageDataReporting",
    "\Microsoft\Windows\Flighting\FeatureConfig\GovernedFeatureUsageProcessing",
    "\Microsoft\Windows\Flighting\FeatureConfig\ReconcileConfigs",
    "\Microsoft\Windows\Flighting\FeatureConfig\ReconcileFeatures",
    "\Microsoft\Windows\Flighting\FeatureConfig\UsageDataFlushing",
    "\Microsoft\Windows\Flighting\FeatureConfig\UsageDataReceiver",
    "\Microsoft\Windows\Flighting\FeatureConfig\UsageDataReporting",
    "\Microsoft\Windows\Flighting\OneSettings\RefreshCache",
    "\Microsoft\Windows\Hotpatch\Monitoring",
    "\Microsoft\Windows\input\InputSettingsRestoreDataAvailable",
    "\Microsoft\Windows\input\LocalUserSyncDataAvailable",
    "\Microsoft\Windows\input\MouseSyncDataAvailable",
    "\Microsoft\Windows\input\PenSyncDataAvailable",
    "\Microsoft\Windows\input\RemoteMouseSyncDataAvailable",
    "\Microsoft\Windows\input\RemotePenSyncDataAvailable",
    "\Microsoft\Windows\input\RemoteTouchpadSyncDataAvailable",
    "\Microsoft\Windows\input\syncpensettings",
    "\Microsoft\Windows\input\TouchpadSyncDataAvailable",
    "\Microsoft\Windows\InstallService\RestoreDevice",
    "\Microsoft\Windows\InstallService\ScanForUpdates",
    "\Microsoft\Windows\InstallService\ScanForUpdatesAsUser",
    "\Microsoft\Windows\InstallService\SmartRetry",
    "\Microsoft\Windows\InstallService\WakeUpAndContinueUpdates",
    "\Microsoft\Windows\InstallService\WakeUpAndScanForUpdates",
    "\Microsoft\Windows\International\Synchronize Language Settings",
    "\Microsoft\Windows\Kernel\La57Cleanup",
    "\Microsoft\Windows\LanguageComponentsInstaller\Installation",
    "\Microsoft\Windows\LanguageComponentsInstaller\ReconcileLanguageResources",
    "\Microsoft\Windows\LanguageComponentsInstaller\Uninstallation",
    "\Microsoft\Windows\License Manager\TempSignedLicenseExchange",
    "\Microsoft\Windows\Location\WindowsActionDialog",
    "\Microsoft\Windows\Maintenance\WinSAT",
    "\Microsoft\Windows\Management\Autopilot\DetectHardwareChange",
    "\Microsoft\Windows\Management\Autopilot\RemediateHardwareChange",
    "\Microsoft\Windows\Management\Provisioning\Cellular",
    "\Microsoft\Windows\Management\Provisioning\Logon",
    "\Microsoft\Windows\Management\Provisioning\MdmDiagnosticsCleanup",
    "\Microsoft\Windows\Management\Provisioning\Retry",
    "\Microsoft\Windows\Management\Provisioning\RunOnReboot",
    "\Microsoft\Windows\Maps\MapsToastTask",
    "\Microsoft\Windows\Maps\MapsUpdateTask",
    "\Microsoft\Windows\MemoryDiagnostic\AutomaticOfflineMemoryDiagnostic",
    "\Microsoft\Windows\MemoryDiagnostic\ProcessMemoryDiagnosticEvents",
    "\Microsoft\Windows\MemoryDiagnostic\RunFullMemoryDiagnostic",
    "\Microsoft\Windows\MUI\LPRemove",
    "\Microsoft\Windows\Multimedia\SystemSoundsService",
    "\Microsoft\Windows\Network Connectivity Status Indicator\NcsiIdentifyUserProxies",
    "\Microsoft\Windows\NlaSvc\WiFiTask",
    "\Microsoft\Windows\Offline Files\Background Synchronization",
    "\Microsoft\Windows\Offline Files\Logon Synchronization",
    "\Microsoft\Windows\PCRPF\PCR Prediction Framework Firmware Update Task",
    "\Microsoft\Windows\PerformanceTrace\RequestTrace",
    "\Microsoft\Windows\PerformanceTrace\WhesvcToast",
    "\Microsoft\Windows\PI\Secure-Boot-Update",
    "\Microsoft\Windows\PI\Sqm-Tasks",
    "\Microsoft\Windows\Plug and Play\Device Install Group Policy",
    "\Microsoft\Windows\Plug and Play\Device Install Reboot Required",
    "\Microsoft\Windows\Plug and Play\Sysprep Generalize Drivers",
    "\Microsoft\Windows\Pluton\Pluton-Ksp-Provisioning",
    "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem",
    "\Microsoft\Windows\Printing\EduPrintProv",
    "\Microsoft\Windows\Printing\PrinterCleanupTask",
    "\Microsoft\Windows\Printing\PrintJobCleanupTask",
    "\Microsoft\Windows\PushToInstall\LoginCheck",
    "\Microsoft\Windows\PushToInstall\Registration",
    "\Microsoft\Windows\Ras\MobilityManager",
    "\Microsoft\Windows\RecoveryEnvironment\VerifyWinRE",
    "\Microsoft\Windows\ReFsDedupSvc\Initialization",
    "\Microsoft\Windows\Registry\RegIdleBackup",
    "\Microsoft\Windows\RemoteAssistance\RemoteAssistanceTask",
    "\Microsoft\Windows\Servicing\OOBEFodSetup",
    "\Microsoft\Windows\Servicing\StartComponentCleanup",
    "\Microsoft\Windows\Setup\PITRTask",
    "\Microsoft\Windows\Setup\SetupRecoveryDataTask",
    "\Microsoft\Windows\SharedPC\Account Cleanup",
    "\Microsoft\Windows\Shell\CreateObjectTask",
    "\Microsoft\Windows\Shell\FamilySafetyMonitor",
    "\Microsoft\Windows\Shell\FamilySafetyRefreshTask",
    "\Microsoft\Windows\Shell\IndexerAutomaticMaintenance",
    "\Microsoft\Windows\Shell\ThemeAssetTask_SyncFODState",
    "\Microsoft\Windows\Shell\ThemesSyncedImageDownload",
    "\Microsoft\Windows\Shell\UpdateUserPictureTask",
    "\Microsoft\Windows\Shell\UpdateUserPictureTaskContained",
    "\Microsoft\Windows\SoftwareProtectionPlatform\SvcRestartTask",
    "\Microsoft\Windows\SoftwareProtectionPlatform\SvcRestartTaskLogon",
    "\Microsoft\Windows\SoftwareProtectionPlatform\SvcRestartTaskNetwork",
    "\Microsoft\Windows\SpacePort\SpaceAgentTask",
    "\Microsoft\Windows\SpacePort\SpaceManagerTask",
    "\Microsoft\Windows\Speech\SpeechModelDownloadTask",
    "\Microsoft\Windows\StateRepository\MaintenanceTasks",
    "\Microsoft\Windows\Storage Tiers Management\Storage Tiers Management Initialization",
    "\Microsoft\Windows\Storage Tiers Management\Storage Tiers Optimization",
    "\Microsoft\Windows\Subscription\EnableLicenseAcquisition",
    "\Microsoft\Windows\Subscription\LicenseAcquisition",
    "\Microsoft\Windows\Sustainability\PowerGridForecastTask",
    "\Microsoft\Windows\Sustainability\SustainabilityTelemetry",
    "\Microsoft\Windows\Sysmain\HybridDriveCachePrepopulate",
    "\Microsoft\Windows\Sysmain\HybridDriveCacheRebalance",
    "\Microsoft\Windows\Sysmain\ResPriStaticDbSync",
    "\Microsoft\Windows\Sysmain\WsSwapAssessmentTask",
    "\Microsoft\Windows\SystemRestore\SR",
    "\Microsoft\Windows\Task Manager\Interactive",
    "\Microsoft\Windows\TextServicesFramework\MsCtfMonitor",
    "\Microsoft\Windows\Time Synchronization\ForceSynchronizeTime",
    "\Microsoft\Windows\Time Synchronization\SynchronizeTime",
    "\Microsoft\Windows\Time Zone\SynchronizeTimeZone",
    "\Microsoft\Windows\TPM\Tpm-HASCertRetr",
    "\Microsoft\Windows\TPM\Tpm-Maintenance",
    "\Microsoft\Windows\TPM\Tpm-PreAttestationHealthCheck",
    "\Microsoft\Windows\UpdateOrchestrator\Report policies",
    "\Microsoft\Windows\UpdateOrchestrator\Schedule Maintenance Work",
    "\Microsoft\Windows\UpdateOrchestrator\Schedule Scan",
    "\Microsoft\Windows\UpdateOrchestrator\Schedule Scan Static Task",
    "\Microsoft\Windows\UpdateOrchestrator\Schedule Wake To Work",
    "\Microsoft\Windows\UpdateOrchestrator\Schedule Work",
    "\Microsoft\Windows\UpdateOrchestrator\Start Oobe Expedite Work",
    "\Microsoft\Windows\UpdateOrchestrator\StartOobeAppsScanAfterUpdate",
    "\Microsoft\Windows\UpdateOrchestrator\StartOobeAppsScan_LicenseAccepted",
    "\Microsoft\Windows\UpdateOrchestrator\UIEOrchestrator",
    "\Microsoft\Windows\UpdateOrchestrator\USO_UxBroker",
    "\Microsoft\Windows\UpdateOrchestrator\UUS Failover Task",
    "\Microsoft\Windows\UPnP\UPnPHostConfig",
    "\Microsoft\Windows\UsageAndQualityInsights\UsageAndQualityInsights-MaintenanceTask",
    "\Microsoft\Windows\USB\Usb-Notifications",
    "\Microsoft\Windows\User Profile Service\HiveUploadTask",
    "\Microsoft\Windows\WaaSMedic\PerformRemediation",
    "\Microsoft\Windows\WCM\WiFiTask",
    "\Microsoft\Windows\WDI\ResolutionHost",
    "\Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance",
    "\Microsoft\Windows\Windows Defender\Windows Defender Cleanup",
    "\Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan",
    "\Microsoft\Windows\Windows Defender\Windows Defender Verification",
    "\Microsoft\Windows\Windows Error Reporting\QueueReporting",
    "\Microsoft\Windows\Windows Filtering Platform\BfeOnServiceStartTypeChange",
    "\Microsoft\Windows\Windows Media Sharing\UpdateLibrary",
    "\Microsoft\Windows\WindowsAI\Recall\InitialConfiguration",
    "\Microsoft\Windows\WindowsAI\Recall\PolicyConfiguration",
    "\Microsoft\Windows\WindowsAI\Settings\InitialConfiguration",
    "\Microsoft\Windows\WindowsColorSystem\Calibration Loader",
    "\Microsoft\Windows\WindowsUpdate\Refresh Group Policy Cache",
    "\Microsoft\Windows\WindowsUpdate\Scheduled Start",
    "\Microsoft\Windows\Wininet\CacheTask",
    "\Microsoft\Windows\WlanSvc\CDSSync",
    "\Microsoft\Windows\WlanSvc\MoProfileManagement",
    "\Microsoft\Windows\WOF\WIM-Hash-Management",
    "\Microsoft\Windows\WOF\WIM-Hash-Validation",
    "\Microsoft\Windows\Work Folders\Work Folders Logon Synchronization",
    "\Microsoft\Windows\Work Folders\Work Folders Maintenance Work",
    "\Microsoft\Windows\Workplace Join\Automatic-Device-Join",
    "\Microsoft\Windows\Workplace Join\Device-Sync",
    "\Microsoft\Windows\Workplace Join\Recovery-Check",
    "\Microsoft\Windows\WwanSvc\NotificationTask",
    "\Microsoft\Windows\WwanSvc\OobeDiscovery",
    "\Microsoft\XblGameSave\XblGameSaveTask"
)

# Tasks with SID suffix: prefix match instead of exact comparison
$allowedTaskPrefixes = @(
    "\OneDrive Reporting Task-S-",
    "\OneDrive Standalone Update Task-S-",
    "\OneDrive Startup Task-S-",
    "\PostponeDeviceSetupToast_S-"
)

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== scheduled-tasks ===" -ForegroundColor Cyan

try {
    $tasks = @(Get-ScheduledTask -ErrorAction Stop)
    foreach ($task in $tasks) {
        $fullPath = $task.TaskPath + $task.TaskName

        $isAllowed = $allowedTasks -contains $fullPath
        if (-not $isAllowed) {
            foreach ($prefix in $allowedTaskPrefixes) {
                if ($fullPath.StartsWith($prefix)) {
                    $isAllowed = $true
                    break
                }
            }
        }

        if ($isAllowed) {
            Write-Host "  [OK] '$fullPath' whitelisted" -ForegroundColor Green
        } else {
            $findings += "Unknown task: '$fullPath'"
            Write-Host "  [FIND] '$fullPath' not in whitelist" -ForegroundColor Red
            try {
                Unregister-ScheduledTask -TaskName $task.TaskName -TaskPath $task.TaskPath -Confirm:$false -ErrorAction Stop
                $actions += "Task '$fullPath' removed"
                Write-Host "  [OK] Task removed: '$fullPath'" -ForegroundColor Green
            } catch {
                $actions += "Failed to remove task '$fullPath': $_"
                Write-Host "  [WARN] Error removing '$fullPath': $_" -ForegroundColor Yellow
                $success = $false
            }
        }
    }
} catch {
    Write-Host "  [WARN] Error retrieving scheduled tasks: $_" -ForegroundColor Yellow
    $success = $false
}

Write-Host ""

[PSCustomObject]@{
    Module   = "scheduled-tasks"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
