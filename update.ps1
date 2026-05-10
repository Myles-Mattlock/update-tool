# --- 1. ENVIRONMENT ENFORCEMENT (WT & ADMIN) ---
# Check for Windows Terminal and Admin rights simultaneously
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isWT = $null -ne $env:WT_SESSION

if (-not $isAdmin -or -not $isWT) {
    # Get the path of the current running process (the .exe)
    $currentFilePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    
    # Use -Command for better compatibility with .exe wrappers
    $argList = "-NoProfile -ExecutionPolicy Bypass -Command `"& '$currentFilePath'`""
    
    if (Get-Command "wt.exe" -ErrorAction SilentlyContinue) {
        # Launch Windows Terminal, which then launches the EXE
        Start-Process "wt.exe" -ArgumentList "powershell.exe $argList" -Verb RunAs
    } else {
        # If no WT, just relaunch the EXE as Admin in standard console
        Start-Process "$currentFilePath" -Verb RunAs
    }
    exit
}

# --- 2. DEPENDENCY CHECK ---
Write-Host "--- Checking Dependencies ---" -ForegroundColor Cyan

# Ensure NuGet provider is installed (required for module installation)
if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Write-Host "Installing NuGet provider..." -ForegroundColor Yellow
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force | Out-Null
}

# Ensure the PSWindowsUpdate module is installed/loaded
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Warning "PSWindowsUpdate module not found. Attempting to install..."
    Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -Scope CurrentUser
}

# --- 3. EXECUTION LOGIC ---
Write-Host "`n--- System Update & Cleanup ---" -ForegroundColor Cyan

try {
    # Windows Updates
    Write-Host "[1/2] Checking for Windows Updates..." -ForegroundColor Yellow
    Import-Module PSWindowsUpdate
    # -AcceptAll and -Install handle the process automatically
    Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false -ErrorAction Stop

    # Winget Updates
    Write-Host "`n[2/2] Updating Winget packages..." -ForegroundColor Yellow
    winget update --all --accept-source-agreements --accept-package-agreements

    Write-Host "`nAll updates completed successfully!" -ForegroundColor Green
}
catch {
    Write-Error "An update error occurred: $($_.Exception.Message)"
}

# --- 4. EXIT HANDLING ---
Write-Host "`nExecution finished." -ForegroundColor Cyan
Write-Host "Press any key to exit..."
$null = [Console]::ReadKey($true)
exit