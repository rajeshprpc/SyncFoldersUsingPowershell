Import-Module GSUtilityModule,GSLogModule,GSEmailModule -Force

Write-Host "Registering Folders Synchronization Module"

Register-GSModules -Module GSSyncFoldersModule -FilePath ($PSScriptRoot)

Write-Host "Importing Folders Synchronization Module"

Import-Module GSSyncFoldersModule -Force

$SyncFoldersConfig = Get-GSConfig -Module GSSyncFoldersModule -XPath 'root'

Write-Host "Checking for installation path in Program Files (x86)"

$InstallationPath = (Join-Path ${Env:ProgramFiles(x86)} "$($SyncFoldersConfig.AppName)")

if(-not (Test-Path -Path $InstallationPath)){
    Write-Host "Installation Path not found. Creating $SyncFoldersConfig.InstallationPath ..."
    New-Item -Path $InstallationPath -ItemType 'directory'
}

Set-Location $InstallationPath

Write-Host "Copying configuration files to installation path"

Copy-GSConfigFiles

Set-GSConfig -Module GSSyncFoldersModule -XPath 'root/InstallationPath' -Value ($InstallationPath)

Confirm-GSFolderSyncConfig

Write-Host "Synchronizing Folders started"

Initialize-GSFoldersSync $SyncFoldersConfig.Path1 $SyncFoldersConfig.Path2

Write-Host "Synchronizing Folders ended"

Exit