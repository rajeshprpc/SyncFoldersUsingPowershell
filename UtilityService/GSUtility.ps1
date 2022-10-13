$moduleName = 'GSUtilityModule'
$moduleFiles = "$moduleName.psm1,$moduleName.psd1,$($moduleName).xml"
$PSModulePath = ($Env:PSModulePath.split(';') -like '*program*')[0]

Set-Location -Path $PSScriptRoot

$logModulePath = Join-Path -Path $PSModulePath -ChildPath "\$moduleName"

if((Test-Path -Path ($logModulePath)) -eq $true){
    Remove-Item -Path $logModulePath -Force -Recurse
}

New-Item -Path $logModulePath -ItemType 'directory'

$moduleFiles.split(',') | ForEach-Object{
    if((Test-Path -Path "$_") -eq $true){
        Copy-Item -Path (Join-Path -Path (Get-Location) -ChildPath "$_") -Destination $logModulePath
    }
}