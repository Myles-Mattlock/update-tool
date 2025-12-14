# Check if the script is running as Administrator
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Output "This program requires administrative privileges. Please run it as Administrator."
    # Pause so the user can see the message before the program exits
    Write-Host "Press Enter to exit..."
    Read-Host
    Exit
}

# Script logic below this point will run with elevated privileges
Write-Output "Running as Administrator! Proceeding with the System Cleanup commands..."

# Run the Installer
try {

    Get-WindowsUpdate
    Install-WindowsUpdate -ForceDownload -ForceInstall -Confirm:$false -IgnoreReboot
    winget update --all

} catch {
    Write-Output "An error occurred while running the Updater app"
    Write-Output $_.Exception.Message
}

Write-Output "Successfully Updated, closing App..."
Start-Sleep -Seconds 5