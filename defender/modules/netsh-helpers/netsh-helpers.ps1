#Requires -RunAsAdministrator

# Allowed NetSh Helper DLLs: value name -> DLL filename
$allowedHelpers = @{
    "2"           = "ifmon.dll"
    "4"           = "rasmontr.dll"
    "authfwcfg"   = "authfwcfg.dll"
    "dhcpclient"  = "dhcpcmonitor.dll"
    "dnsclient"   = "nshdnsclient.dll"
    "dot3cfg"     = "dot3cfg.dll"
    "fwcfg"       = "fwcfg.dll"
    "hnetmon"     = "hnetmon.dll"
    "netiohlp"    = "netiohlp.dll"
    "netprofm"    = "netprofm.dll"
    "nettrace"    = "nettrace.dll"
    "nshhttp"     = "nshhttp.dll"
    "nshipsec"    = "nshipsec.dll"
    "nshwfp"      = "nshwfp.dll"
    "rpc"         = "rpcnsh.dll"
    "WcnNetsh"    = "WcnNetsh.dll"
    "whhelper"    = "whhelper.dll"
    "wlancfg"     = "wlancfg.dll"
    "wshelper"    = "wshelper.dll"
    "wwancfg"     = "wwancfg.dll"
    "peerdistsh"  = "peerdistsh.dll"
}

$regPath = "HKLM:\SOFTWARE\Microsoft\NetSh"

$findings = @()
$actions  = @()
$success  = $true

Write-Host ""
Write-Host "=== netsh-helpers ===" -ForegroundColor Cyan

try {
    if (-not (Test-Path -Path $regPath)) {
        Write-Host "  [OK] NetSh key not found" -ForegroundColor Green
    } else {
        $props = Get-ItemProperty -Path $regPath -ErrorAction Stop
        $values = @($props.PSObject.Properties | Where-Object {
            $_.Name -notmatch '^PS(Path|ParentPath|ChildName|Drive|Provider)$'
        })

        foreach ($v in $values) {
            $name = $v.Name
            $dll  = [string]$v.Value

            if ($allowedHelpers.ContainsKey($name)) {
                $expectedDll = $allowedHelpers[$name]
                if ($dll -eq $expectedDll) {
                    Write-Host "  [OK] '$name' = '$dll' whitelisted" -ForegroundColor Green
                } else {
                    $findings += "NetSh Helper '$name': expected '$expectedDll', found '$dll'"
                    Write-Host "  [FIND] '$name' has wrong DLL value: '$dll' (expected: '$expectedDll')" -ForegroundColor Red
                    try {
                        Set-ItemProperty -Path $regPath -Name $name -Value $expectedDll -Force -ErrorAction Stop
                        $actions += "NetSh Helper '$name' corrected to '$expectedDll'"
                        Write-Host "  [OK] '$name' corrected to '$expectedDll'" -ForegroundColor Green
                    } catch {
                        $actions += "Failed to correct '$name': $_"
                        Write-Host "  [WARN] Error correcting '$name': $_" -ForegroundColor Yellow
                        $success = $false
                    }
                }
            } else {
                $findings += "Unknown NetSh Helper: '$name' = '$dll'"
                Write-Host "  [FIND] Unknown NetSh Helper: '$name' = '$dll'" -ForegroundColor Red
                try {
                    Remove-ItemProperty -Path $regPath -Name $name -Force -ErrorAction Stop
                    $actions += "NetSh Helper '$name' removed"
                    Write-Host "  [OK] '$name' removed" -ForegroundColor Green
                } catch {
                    $actions += "Failed to remove '$name': $_"
                    Write-Host "  [WARN] Error removing '$name': $_" -ForegroundColor Yellow
                    $success = $false
                }
            }
        }
    }
} catch {
    Write-Host "  [WARN] Error checking NetSh helpers: $_" -ForegroundColor Yellow
    $success = $false
}

Write-Host ""

[PSCustomObject]@{
    Module   = "netsh-helpers"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
