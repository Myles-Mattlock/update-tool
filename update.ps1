Get-WindowsUpdate
Install-WindowsUpdate -ForceDownload -ForceInstall -Confirm:$false -IgnoreReboot
winget update --all