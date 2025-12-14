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


    ## --- STEP 1: Ensure Necessary Prerequisites (Fixing the NuGet Issue) ---

    # Check/Set TLS 1.2 Protocol (Mandatory for most external connections)
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Check if the NuGet provider is already installed successfully
    if (-not (Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue)) {
        Write-Host "Attempting to install NuGet Package Provider..."
        
        # 1. Try the standard installation method first
        try {
            Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -ErrorAction Stop
        }
        catch {
            Write-Warning "Standard NuGet installation failed. Falling back to manual method."
            
            # 2. Fallback: Manually download and install the required components
            $ProviderPath = Join-Path $env:ProgramFiles\PackageManagement\ProviderAssemblies
            if (-not (Test-Path $ProviderPath)) {
                $null = New-Item -Path $ProviderPath -ItemType Directory -Force
            }
            
            $TempZip = Join-Path $env:TEMP\OneGet.zip
            Invoke-WebRequest -Uri https://onegetcdn.azureedge.net/providers/Microsoft.PowerShell.OneGet-1.0.0.1.zip -OutFile $TempZip -UseBasicParsing
            Expand-Archive -Path $TempZip -DestinationPath $ProviderPath -Force
            Remove-Item $TempZip -Force
            
            Write-Host "NuGet provider installed manually. Restarting PowerShell session may be needed for full function."
        }
    } else {
        Write-Host "NuGet Package Provider is already available."
    }


    ## --- STEP 2: Conditional Module Installation and Configuration ---

    # Check if PSWindowsUpdate module is installed (Your existing check)
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