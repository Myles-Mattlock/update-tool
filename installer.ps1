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

    # Check/Set TLS 1.2 Protocol (Mandatory for most external connections)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
    Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.208 -Force -Scope CurrentUser
    Install-Module PSWindowsUpdate -Force  -Scope CurrentUser
    Add-WUServiceManager -MicrosoftUpdate  -Confirm:$false


    if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
        Write-Host "PSWindowsUpdate module is not installed. Installing and configuring now..."
        Install-Module PSWindowsUpdate -Force -Scope CurrentUser
        Add-WUServiceManager -MicrosoftUpdate -Confirm:$false
        Write-Host "PSWindowsUpdate module and configuration complete."
    } else {
        Write-Host "PSWindowsUpdate module is already installed. Ensuring service is present..."
        # Always ensure the service is added, just in case
        Add-WUServiceManager -MicrosoftUpdate -Confirm:$false
    }

} catch {
    Write-Output "An error occurred while running the installer"
    Write-Output $_.Exception.Message
}

Write-Output "Successfully installer Myles updater, closing..."
Start-Sleep -Seconds 5