$PSModulePath = ($Env:PSModulePath.split(';') -like '*program*')[0]

function Register-GSModules{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Module,
        [Parameter(Mandatory)]
        [string]$FilePath
    )

    $moduleFiles = "$Module.psm1,$Module.psd1,$($Module).xml"

    Set-Location -Path $FilePath

    $modulePath = Join-Path -Path $PSModulePath -ChildPath "\$Module"

    if((Test-Path -Path ($modulePath)) -eq $true){
        Remove-Item -Path $modulePath -Force -Recurse
    }

    New-Item -Path $modulePath -ItemType 'directory'

    $moduleFiles.split(',') | ForEach-Object{
        if((Test-Path -Path "$_") -eq $true){
            Copy-Item -Path (Join-Path -Path (Get-Location) -ChildPath "$_") -Destination $modulePath
        }
    }
}

function Get-GSModulePath{
    [CmdletBinding()]
    param(
        [ValidateNotNullOrEmpty()]
        [string]$Module = ''
    )

    process{
        if($Module.Length -eq 0){
            return $PSModulePath
        }
        else{
            return Join-Path -Path ($PSModulePath) -ChildPath ($Module)
        }
    }
}

function Get-GSConfig{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Module,
        [ValidateNotNullOrEmpty()]
        [string]$XPath = '/root',
        [ValidateNotNullOrEmpty()]
        [string]$ConfigDir = ''
    )

    if([string]::IsNullOrWhiteSpace(($ConfigDir)) -eq $false){
        $configFile = Join-Path -Path ($ConfigDir) -ChildPath "$Module.xml"
    }
    else{
        $configFile = Get-GSConfigPath $Module
    }

    return Select-Xml -Path ($configFile) -XPath $XPath | Select-Object -ExpandProperty Node
}

function Get-GSConfigXml{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Module
    )

    $configFile = Get-GSConfigPath $Module

    $configXml = New-Object xml
    $configXml.Load(($configFile))    

    return $configXml.root
}

function Get-GSConfigPath{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Module
    )

    $configFileName = "$($Module).xml"

    $configPath = Join-Path -Path (Get-Location) -ChildPath $configFileName

    return $configPath
}

function Set-GSConfig{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Module,
        [Parameter(Mandatory)]
        [string]$XPath,
        [Parameter(Mandatory)]
        [string]$Value
    )

    Set-GSConfigXML $Module $XPath $Value

    return

    $selectedNode = Select-Xml -Path (Get-GSConfigPath $Module) -XPath $XPath

    $selectedNode.Node.'#text' = $Value

    $selectedNode.Node.OwnerDocument.Save($selectedNode.Path)
}

function Set-GSConfigXML{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Module,
        [Parameter(Mandatory)]
        [string]$XPath,
        [Parameter(Mandatory)]
        [string]$Value
    )
    $configPath = Get-GSConfigPath $Module

    $config = New-Object XML
    $config.Load($configPath)

    $config.SelectSingleNode($XPath).InnerText = $Value

    $config.Save($configPath)
}

function Copy-GSConfigFiles{
    [CmdletBinding()]
    param(        
    )

    Get-Module -ListAvailable -Name GS* | ForEach-Object{
        $ModulePath = Split-Path($_.Path)
        $ConfigFile = Join-Path -Path ($ModulePath) -ChildPath "$($_.Name).xml"

        if((Test-Path -Path ($ConfigFile)) -eq $true){
            Copy-Item -Path ($ConfigFile) -Destination (Get-Location)
        }
    }
}