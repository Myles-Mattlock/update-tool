# --- 1. ENVIRONMENT ENFORCEMENT (WT & ADMIN) ---
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
$isWT = $null -ne $env:WT_SESSION

if (-not $isAdmin -or -not $isWT) {
    $currentFilePath = [System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName
    $argList = "-NoProfile -ExecutionPolicy Bypass -Command `"& '$currentFilePath'`""
    
    if (Get-Command "wt.exe" -ErrorAction SilentlyContinue) {
        Start-Process "wt.exe" -ArgumentList "powershell.exe $argList" -Verb RunAs
    } else {
        Start-Process "$currentFilePath" -Verb RunAs
    }
    exit
}

# --- 2. GUI & PATH PREPARATION ---
Add-Type -AssemblyName System.Windows.Forms

if ([System.IO.Path]::GetExtension($PSCommandPath) -eq '.exe') {
    $CurrentDir = Split-Path -Parent ([System.Diagnostics.Process]::GetCurrentProcess().MainModule.FileName)
} else {
    $CurrentDir = $PSScriptRoot
}
if ([string]::IsNullOrEmpty($CurrentDir)) { $CurrentDir = Get-Location }

# --- 3. CONFIGURATION & UPDATE LOGIC ---
$CurrentVersion = "2.0.0" 
# Updated to point to the Update Tool repository
$RepoName = "Myles-Mattlock/update-tool"

function Check-ForUpdates {
    Write-Host "Checking for tool updates..." -ForegroundColor Gray
    try {
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $UserAgent = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) PowerShell-App"
        $Url = "https://api.github.com/repos/$RepoName/releases"

        $Releases = Invoke-RestMethod -Uri $Url -Method Get -UserAgent $UserAgent -ErrorAction Stop
        $StableReleases = $Releases | Where-Object { $_.prerelease -eq $false }

        $LocalVersion = [version]($CurrentVersion.ToLower().TrimStart('v').Split("-")[0])
        $UpdateFound = $null

        foreach ($Rel in $StableReleases) {
            $RemoteVersion = [version]($Rel.tag_name.ToLower().TrimStart('v').Split("-")[0])
            if ($RemoteVersion -gt $LocalVersion) {
                $UpdateFound = $Rel
                break 
            }
        }

        if ($UpdateFound) {
            Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
            Write-Host " [!] NEW TOOL UPDATE AVAILABLE: $($UpdateFound.tag_name)" -ForegroundColor White -BackgroundColor Blue
            Write-Host " You are currently running: v$CurrentVersion" -ForegroundColor Gray
            Write-Host "----------------------------------------------------------" -ForegroundColor Cyan
            
            $UpdateChoice = [System.Windows.Forms.MessageBox]::Show("A new version of this tool ($($UpdateFound.tag_name)) is available.`n`nWould you like to download it now?", "Tool Update Available", "YesNo", "Information", [System.Windows.Forms.MessageBoxDefaultButton]::Button1, [System.Windows.Forms.MessageBoxOptions]::ServiceNotification)
            
            if ($UpdateChoice -eq "Yes") { 
                Start-Process $UpdateFound.html_url
                Write-Host "Redirecting to download page. Closing app..." -ForegroundColor Yellow
                Start-Sleep -Seconds 2
                Exit 
            }
        } else {
            Write-Host " Tool is up to date (v$CurrentVersion)." -ForegroundColor DarkGreen
        }
    } catch {
        Write-Host " Note: Tool update check skipped (Connection issue)." -ForegroundColor DarkGray
    }
}

# --- 4. STARTUP & CONFIRMATION ---
Write-Host "--- Initializing System Update Tool ---" -ForegroundColor Cyan
Check-ForUpdates

# Execution Confirmation Popup
$PopTitle = "System Update Confirmation"
$PopText  = "Would you like to begin the System Update process?`n`nThis will check for Windows Updates and update all Winget packages."
$Result = [System.Windows.Forms.MessageBox]::Show($PopText, $PopTitle, "YesNo", "Question", [System.Windows.Forms.MessageBoxDefaultButton]::Button1, [System.Windows.Forms.MessageBoxOptions]::ServiceNotification)

if ($Result -eq "No") {
    Write-Host "`nOperation cancelled by user." -ForegroundColor Red
    Start-Sleep -Seconds 2
    Exit
}

# --- 5. DEPENDENCY CHECK ---
Write-Host "`n--- Checking Dependencies ---" -ForegroundColor Cyan

if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
    Write-Host "Installing NuGet provider..." -ForegroundColor Yellow
    Install-PackageProvider -Name NuGet -MinimumVersion 3.0.0.2 -Force | Out-Null
}

if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Warning "PSWindowsUpdate module not found. Attempting to install..."
    Install-Module -Name PSWindowsUpdate -Force -SkipPublisherCheck -Scope CurrentUser
}

# --- 6. EXECUTION LOGIC ---
Write-Host "`n--- Starting System Update ---" -ForegroundColor Cyan

try {
    Write-Host "[1/2] Checking for Windows Updates..." -ForegroundColor Yellow
    Import-Module PSWindowsUpdate
    Get-WindowsUpdate -AcceptAll -Install -AutoReboot:$false -ErrorAction Stop

    Write-Host "`n[2/2] Updating Winget packages..." -ForegroundColor Yellow
    winget update --all --accept-source-agreements --accept-package-agreements

    Write-Host "`nAll updates completed successfully!" -ForegroundColor Green
}
catch {
    Write-Host "`nAn update error occurred: $($_.Exception.Message)" -ForegroundColor Red
}

# --- 7. EXIT HANDLING ---
Write-Host "`nExecution finished." -ForegroundColor Cyan
Write-Host "Press any key to exit..."
$null = [Console]::ReadKey($true)
exit