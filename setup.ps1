# --- Configuration ---
$FolderName      = "SystemUpdate"
$CurrentDir      = $PSScriptRoot
if ([string]::IsNullOrEmpty($CurrentDir)) { $CurrentDir = Get-Location }

$SourcePath      = Join-Path -Path $CurrentDir -ChildPath $FolderName
$TargetPath      = Join-Path -Path $env:ProgramFiles -ChildPath $FolderName

# Shortcut Settings
$shortcutName    = "System Update"
$exeName         = "System Update.exe" 
$executablePath  = Join-Path -Path $TargetPath -ChildPath $exeName
$ProcessName     = "System Update"

# --- Admin Elevation Check ---
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "CRITICAL: This program requires administrative privileges." -ForegroundColor Red
    Write-Host "Please right-click and 'Run as Administrator'." -ForegroundColor Yellow
    Pause
    Exit
}

# --- Execution ---
Write-Host "Starting installation: $shortcutName" -ForegroundColor Cyan

# 0. Kill process if running
if (Get-Process -Name $ProcessName -ErrorAction SilentlyContinue) {
    Write-Host "Closing running instance of $ProcessName..." -ForegroundColor Yellow
    Stop-Process -Name $ProcessName -Force -ErrorAction SilentlyContinue
    Start-Sleep -Seconds 2
}

# 1. Check if Source Folder exists
if (-not (Test-Path -Path $SourcePath)) {
    Write-Error "Source folder '$FolderName' not found at $SourcePath"
    Pause
    exit
}

# 2. Clear old files / Prepare Directory
if (Test-Path -Path $TargetPath) {
    Write-Host "Removing old version..." -ForegroundColor Yellow
    try {
        Remove-Item -Path "$TargetPath\*" -Recurse -Force -ErrorAction Stop
    }
    catch {
        Write-Error "Failed to clear directory. Is the app still open? Error: $($_.Exception.Message)"
        Pause
        exit
    }
} else {
    New-Item -ItemType Directory -Path $TargetPath -Force | Out-Null
}

# 3. Copy files and Unblock
try {
    Write-Host "Installing to $TargetPath..." -ForegroundColor White
    Copy-Item -Path "$SourcePath\*" -Destination $TargetPath -Recurse -Force -ErrorAction Stop
    
    # Unblock files to prevent "Unknown Publisher" security blocks
    Get-ChildItem -Path $TargetPath -Recurse | Unblock-File
}
catch {
    Write-Error "Copy failed: $($_.Exception.Message)"
    Pause
    exit
}

# 4. Configure PowerShell Modules (PSWindowsUpdate)
try {
    Write-Host "Configuring Windows Update modules..." -ForegroundColor Cyan
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force

    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Host "Installing PSWindowsUpdate module..." -ForegroundColor Gray
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208 -Force -Scope CurrentUser
        Install-Module PSWindowsUpdate -Force -Scope CurrentUser
    }
    
    Write-Host "Registering Microsoft Update Service..." -ForegroundColor Gray
    Add-WUServiceManager -MicrosoftUpdate -Confirm:$false
}
catch {
    Write-Warning "Module configuration encountered an issue: $($_.Exception.Message)"
}

# 5. Create Desktop Shortcut
try {
    $desktopPath = [System.Environment]::GetFolderPath([System.Environment+SpecialFolder]::Desktop)
    $shortcutPath = Join-Path $desktopPath "$shortcutName.lnk"
    $WshShell = New-Object -ComObject WScript.Shell
    $shortcut = $WshShell.CreateShortcut($shortcutPath)
    $shortcut.TargetPath = $executablePath
    $shortcut.WorkingDirectory = $TargetPath
    $shortcut.Description = "Update Windows using Myles' Tool"
    $shortcut.Save()
    Write-Host "Shortcut created on Desktop." -ForegroundColor Green
}
catch {
    Write-Warning "Shortcut could not be created."
}

Write-Host "Installation of Myles' Updater successful!" -ForegroundColor Green
Start-Sleep -Seconds 5