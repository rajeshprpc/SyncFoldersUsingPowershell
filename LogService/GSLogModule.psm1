$module = 'GSLogModule'

function Write-GSLog{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]    
        [string]$message,
        [ValidateNotNullOrEmpty()]
        [string]$params = '',
        [ValidateNotNullOrEmpty()]
        [string]$logFileName = ''
    )

    $configXml = Get-GSConfig $module

    switch ($configXml.LogMode){
        "FILE"{ 
            $fileName = Get-Date -Format 'yyyyMMdd'
            if([string]::IsNullOrWhiteSpace($logFileName) -eq $false){
                $fileName += "_$logFileName"
            }
            $fileName += '.log'
            $file = Join-Path -Path ($configXml.LogPath) -ChildPath $fileName

            if((Test-Path $configXml.LogPath) -eq $false){
                New-Item $configXml.LogPath -ItemType 'Directory'
            }

            $logMessage = Get-Date -Format 'yyyy-MM-dd HH:mm:ss';

            $logMessage += ":   $message"

            if([string]::IsNullOrWhiteSpace($params) -eq $false){
                $logMessage += ", Params: $params"
            }
            
            $logMessage | Out-File -FilePath $file -Append -Force
        }
    }
}