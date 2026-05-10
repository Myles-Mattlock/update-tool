# --- 1. ENVIRONMENT ENFORCEMENT (WT & ADMIN) ---
# Check for Windows Terminal and Admin rights simultaneously
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isWT = $null -ne $env:WT_SESSION

if (-not $isAdmin -or -not $isWT) {
    $argList = "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    
    # If WT is available, wrap the call; otherwise, just elevate PowerShell
    if (Get-Command "wt.exe" -ErrorAction SilentlyContinue) {
        Start-Process "wt.exe" -ArgumentList "powershell.exe $argList" -Verb RunAs
    } else {
        Start-Process "powershell.exe" -ArgumentList $argList -Verb RunAs
    }
    exit
}

# --- 2. DEPENDENCY CHECK ---
# Ensure the PSWindowsUpdate module is installed/loaded
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Warning "PSWindowsUpdate module not found. Attempting to install..."
    Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -Scope CurrentUser
}

# --- 3. EXECUTION LOGIC ---
Write-Host "--- System Update & Cleanup ---" -ForegroundColor Cyan

try {
    # Windows Updates
    Write-Host "[1/2] Checking for Windows Updates..." -ForegroundColor Yellow
    # Using Import-Module to ensure commands are available in the session
    Import-Module PSWindowsUpdate
    Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false -ErrorAction Stop

    # Winget Updates
    Write-Host "[2/2] Updating Winget packages..." -ForegroundColor Yellow
    winget update --all --accept-source-agreements --accept-package-agreements

    Write-Host "`nAll updates completed successfully!" -ForegroundColor Green
}
catch {
    Write-Error "An update error occurred: $($_.Exception.Message)"
}
finally {
    Write-Host "Closing in 5 seconds..."
    Start-Sleep -Seconds 5
}