#Requires -RunAsAdministrator

# Erlaubte NetSh Helper DLLs: Wertname -> DLL-Dateiname
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
        Write-Host "  [OK] NetSh-Key nicht vorhanden" -ForegroundColor Green
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
                    Write-Host "  [OK] '$name' = '$dll' bekannt" -ForegroundColor Green
                } else {
                    $findings += "NetSh Helper '$name': erwartet '$expectedDll', gefunden '$dll'"
                    Write-Host "  [FUND] '$name' hat falschen DLL-Wert: '$dll' (erwartet: '$expectedDll')" -ForegroundColor Red
                    try {
                        Set-ItemProperty -Path $regPath -Name $name -Value $expectedDll -Force -ErrorAction Stop
                        $actions += "NetSh Helper '$name' auf '$expectedDll' korrigiert"
                        Write-Host "  [OK] '$name' korrigiert auf '$expectedDll'" -ForegroundColor Green
                    } catch {
                        $actions += "Korrektur von '$name' fehlgeschlagen: $_"
                        Write-Host "  [WARN] Fehler beim Korrigieren von '$name': $_" -ForegroundColor Yellow
                        $success = $false
                    }
                }
            } else {
                $findings += "Unbekannter NetSh Helper: '$name' = '$dll'"
                Write-Host "  [FUND] Unbekannter NetSh Helper: '$name' = '$dll'" -ForegroundColor Red
                try {
                    Remove-ItemProperty -Path $regPath -Name $name -Force -ErrorAction Stop
                    $actions += "NetSh Helper '$name' entfernt"
                    Write-Host "  [OK] '$name' entfernt" -ForegroundColor Green
                } catch {
                    $actions += "Entfernung von '$name' fehlgeschlagen: $_"
                    Write-Host "  [WARN] Fehler beim Entfernen von '$name': $_" -ForegroundColor Yellow
                    $success = $false
                }
            }
        }
    }
} catch {
    Write-Host "  [WARN] Fehler beim Pruefen der NetSh Helper: $_" -ForegroundColor Yellow
    $success = $false
}

Write-Host ""

[PSCustomObject]@{
    Module   = "netsh-helpers"
    Findings = $findings
    Actions  = $actions
    Success  = $success
}
