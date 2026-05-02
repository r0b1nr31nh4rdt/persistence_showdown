#Requires -RunAsAdministrator

$regLocations = @(
    "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Windows",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Windows"
)

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== appinitdlls ===" -ForegroundColor Cyan

foreach ($regPath in $regLocations) {
    $label = if ($regPath -match "WOW6432Node") { "AppInit_DLLs (Wow64)" } else { "AppInit_DLLs (x64)" }

    try {
        if (-not (Test-Path -Path $regPath)) {
            Write-Host "  [OK] $label: key not found" -ForegroundColor Green
            continue
        }

        $props    = Get-ItemProperty -Path $regPath -ErrorAction Stop
        $dllValue = ""
        try { $dllValue = [string]$props.AppInit_DLLs } catch {}

        if ([string]::IsNullOrWhiteSpace($dllValue)) {
            Write-Host "  [OK] $label: empty" -ForegroundColor Green
        } else {
            $findings += "$label contains: '$dllValue'"
            Write-Host "  [FIND] $label: '$dllValue'" -ForegroundColor Red

            # Save DLL paths before clearing the value
            $dllPaths = $dllValue -split '[\s,;]+' | Where-Object { $_ -ne "" }

            # Clear the value (do not delete the key)
            try {
                Set-ItemProperty -Path $regPath -Name "AppInit_DLLs" -Value "" -Force -ErrorAction Stop
                $actions += "$label: value cleared"
                Write-Host "  [OK] $label: value cleared" -ForegroundColor Green
            } catch {
                $actions += "$label: failed to clear value: $_"
                Write-Host "  [WARN] Error clearing $label: $_" -ForegroundColor Yellow
                $success = $false
            }

            # Also disable LoadAppInit_DLLs
            try {
                Set-ItemProperty -Path $regPath -Name "LoadAppInit_DLLs" -Value 0 -Force -ErrorAction SilentlyContinue
                $actions += "$label: LoadAppInit_DLLs set to 0"
            } catch {}

            # Delete referenced DLL files
            foreach ($dll in $dllPaths) {
                $expandedPath = [Environment]::ExpandEnvironmentVariables($dll.Trim('"'))
                try {
                    if (Test-Path -LiteralPath $expandedPath -PathType Leaf) {
                        Remove-Item -LiteralPath $expandedPath -Force -ErrorAction Stop
                        $actions += "DLL deleted: '$expandedPath'"
                        Write-Host "  [OK] DLL deleted: '$expandedPath'" -ForegroundColor Green
                    }
                } catch {
                    $actions += "Failed to delete DLL '$expandedPath': $_"
                    Write-Host "  [WARN] Error deleting '$expandedPath': $_" -ForegroundColor Yellow
                    $success = $false
                }
            }
        }
    } catch {
        Write-Host "  [WARN] Error checking $label: $_" -ForegroundColor Yellow
        $success = $false
    }
}

Write-Host ""

[PSCustomObject]@{
    Module   = "appinitdlls"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
