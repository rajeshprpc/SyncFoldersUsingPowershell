function Initialize-GSFoldersSync{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$path1,
        [Parameter(Mandatory=$true)]
        [string]$path2
    )
    begin{
        Write-Host "Initialize Folders Synchronization function started"

        $SyncFoldersConfig = Get-GSConfig -Module GSSyncFoldersModule -XPath 'root'

        $path1SchedulerName = "$($SyncFoldersConfig.AppName).$($SyncFoldersConfig.SchedulerNamePath1)"
        $path2SchedulerName = "$($SyncFoldersConfig.AppName).$($SyncFoldersConfig.SchedulerNamePath2)"
    }
    process{
        
        Stop-GSFoldersSync

        $nextRunDateImmediate = (Get-Date).AddMinutes(1).ToString('yyyy-MM-dd HH:mm:ss')
        $trgImmediate = New-JobTrigger -At $nextRunDateImmediate -Once

        $option = New-ScheduledJobOption -RunElevated -MultipleInstancePolicy StopExisting

        Write-Host "Creating $path1SchedulerName scheduler for copying files from $path1 to $path2 runs at $nextRunDateImmediate"

        Register-ScheduledJob -Name $path1SchedulerName -InitializationScript {
            Import-Module GSSyncFoldersModule,GSLogModule -Force
        } -ScriptBlock {            
            Set-Location -Path ($args[1])

            $ExistingTrigger = Get-JobTrigger -Name $args[2]
            if($ExistingTrigger.Frequency -ne 'Daily'){
                $newNextRunDate = (Get-Date).AddDays(1).ToString("yyyy-MM-dd")
                Get-JobTrigger -Name $args[2] | Set-JobTrigger -At $newNextRunDate -Once

                Write-GSLog "Job trigger is changed to daily for the scheduler $($args[2]) and the next run date is $newNextRunDate"
            }

            $SyncFolderConfig = Get-GSConfig GSSyncFoldersModule -XPath 'root'

            Copy-GSFoldersAndFiles $SyncFolderConfig.Path1 $SyncFolderConfig.Path2 $args[0] 
        } -ArgumentList 'Path1', $SyncFoldersConfig.InstallationPath, $path1SchedulerName -Trigger $trgImmediate -ScheduledJobOption $option

        Write-Host "Creating $path2SchedulerName scheduler for copying files from $path2 to $path1 runs at $nextRunDate"

        Register-ScheduledJob -Name $path2SchedulerName -InitializationScript {
            Import-Module GSSyncFoldersModule,GSLogModule -Force
        } -ScriptBlock {
            Set-Location -Path($args[1])

            $ExistingTrigger = Get-JobTrigger -Name $args[2]
            if($ExistingTrigger.Frequency -ne 'Daily'){
                $newNextRunDate = (Get-Date).AddDays(1).ToString("yyyy-MM-dd")
                Get-JobTrigger -Name $args[2] | Set-JobTrigger -At $newNextRunDate -Once

                Write-GSLog "Job trigger is changed to daily for the scheduler $($args[2]) and the next run date is $newNextRunDate"
            }

            $SyncFolderConfig = Get-GSConfig GSSyncFoldersModule -XPath 'root'

            Copy-GSFoldersAndFiles $SyncFolderConfig.Path2 $SyncFolderConfig.Path1 $args[0]
        } -ArgumentList 'Path2', $SyncFoldersConfig.InstallationPath, $path2SchedulerName -Trigger $trgImmediate -ScheduledJobOption $option

        Initialize-GSFoldersSyncScheduler $path1 $path2
    }
    end{
        Write-Host "Initialize Folders Synchronization function ended"
    }
}

function Copy-GSFoldersAndFiles{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$path1,
        [Parameter(Mandatory=$true)]
        [string]$path2,
        [Parameter(Mandatory=$true)]
        [string]$name
    )
    begin{
        Write-GSLog "Copy folders and files $($name) started"
    }
    process{
        $LogFileName = Get-Date -Format 'yyyyMMdd'
        $filePath = "$(Join-Path -Path (Get-Location) -ChildPath "Log\$($LogFileName)_$($name).log")"
        $SyncFolderConfig = Get-GSConfig GSSyncFoldersModule -XPath 'root'

        Write-GSLog "Command executing: Robocopy $path1 $path2 /TEE /E /S /XC /MT:8 /MON:$($SyncFolderConfig.MonitorNoOfChanges) /MOT:$($SyncFolderConfig.MonitorWaitMin) /R:$($SyncFolderConfig.RetryCount) /W:$($SyncFolderConfig.WaitBtwnRetrySec) /LOG+:"$filePath""

        #$exitCode =  
        Robocopy $path1 $path2 /TEE /E /S /XC /MT:8 /MON:$($SyncFolderConfig.MonitorNoOfChanges) /MOT:$($SyncFolderConfig.MonitorWaitMin) /R:$($SyncFolderConfig.RetryCount) /W:$($SyncFolderConfig.WaitBtwnRetrySec) /LOG+:""$filePath""

        #Write-GSLog "Robocopy $($name) status - $exitCode"
    }
    end{
        Write-GSLog "Copy folders and files $($name) ended"
    }
}

function Initialize-GSFoldersSyncScheduler{
    [CmdletBinding()]
    param(
        [parameter(Mandatory=$true)]
        [string]$path1,
        [Parameter(Mandatory=$true)]
        [string]$path2
    )
    begin{
        Write-Host "Initializing validating folder synchronization scheduler function started"
    }
    process{
        $config = Get-GSConfig -Module GSSyncFoldersModule -XPath 'root'
        $nextRunDate = (Get-Date).AddMinutes($config.ValidateSchedulerInterval)
        $trigger = New-JobTrigger -Once -At $nextRunDate -RepetitionInterval (New-TimeSpan -Minutes ($config.ValidateSchedulerInterval)) -RepetitionDuration ([Timespan]::MaxValue)
        $options = New-ScheduledJobOption -RunElevated -MultipleInstancePolicy StopExisting
        
        $validateSchedulerName = "$($SyncFoldersConfig.AppName).$($config.ValidateSchedulerName)"
        
        Write-Host "Creating $validateSchedulerName scheduler for validating lone files and extra files in $path1 runs at $nextRunDate"

        Register-ScheduledJob -Name $validateSchedulerName -InitializationScript{
            Import-Module GSSyncFoldersModule,GSLogModule,GSEmailModule -Force
        } -ScriptBlock{
            Set-Location -Path($args[0])

            $SyncFolderConfig = Get-GSConfig GSSyncFoldersModule -XPath 'root'

            $ExistingTrigger = Get-JobTrigger -Name $args[1]
            if($ExistingTrigger.RepetitionInterval.Minutes -ne $SyncFolderConfig.ValidateSchedulerInterval){
                $newNextRunDate = (Get-Date).AddMinutes($SyncFolderConfig.ValidateSchedulerInterval).ToString("yyyy-MM-dd HH:mm")
                Get-JobTrigger -Name $args[1] | Set-JobTrigger -Once -At $newNextRunDate -RepetitionInterval (New-TimeSpan -Minutes ($SyncFolderConfig.ValidateSchedulerInterval)) -RepetitionDuration ([Timespan]::MaxValue)

                Write-GSLog "Job trigger is changed to $($SyncFolderConfig.ValidateSchedulerInterval) minutes for the scheduler $($args[1]) and the next run date is $newNextRunDate"
            }

            Confirm-GSFolderSync $SyncFolderConfig.Path1 $SyncFolderConfig.Path2
        } -ArgumentList $config.InstallationPath, $validateSchedulerName -Trigger $trigger -ScheduledJobOption $options -RunNow

    }
    end{
        Write-Host "Initializing validating folder synchronization scheduler function ended"
    }
}

function Confirm-GSFolderSync{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$path1,
        [Parameter(Mandatory=$true)]
        [string]$path2
    )
    begin{
        Write-GSLog "Confirm folders sync function started"
    }
    process{
        $files = Robocopy $path1 $path2 /S /E /L /NJS /NJH /NDL /NC /NS

        $status = 'Success'
        $priority = 'Normal'
        $color = 'green'

        if($files.length -gt 0){
            $status = 'Failed'
            $priority = 'High'
            $color = 'Red'
        }

        Write-GSLog "Command Executed: Robocopy $path1 $path2 /S /E /L /NJS /NJH /NDL /NC /NS; Status: $status"

        $configXml = Get-GSConfig GSEmailModule
        $subject = $configXml.Subject.replace('#STATUS#',$status).replace('#EXECUTION_DATE#',(Get-Date -Format 'dd-MM-yyyy HH:mm:ss'))
        
        $body = "Dears, <br><br>
                    Synchronizing files between $path1 and $path2 is <span style='color:$color;font-weight:bold'>$status</span>.<br>
                    $(
                        if($files.length -gt 0){
                            "Files pending to process <span style='color:$color;font-weight:bold'>$($files.length)</span><br><br>"
                    })
                Thanks & Regards,<br><br>
                <b>Scheduled Job</b>"

        Send-GSEmail $configXml.FromEmailId $configXml.ToEmailId $subject $body -Priority $priority
    }
    end{
        Write-GSLog "Confirm folders sync function ended"
    }
}

function Stop-GSFoldersSync{
    #Stop-Job SyncFromPath1ToPath2
    #Remove-Job SyncFromPath1ToPath2
    
    #Stop-Job SyncFromPath2ToPath1
    #Remove-Job SyncFromPath2ToPath1

    $SyncFoldersConfig = Get-GSConfig -Module GSSyncFoldersModule -XPath 'root'

    $path1SchedulerName = "$($SyncFoldersConfig.AppName).$($SyncFoldersConfig.SchedulerNamePath1)"
    $path2SchedulerName = "$($SyncFoldersConfig.AppName).$($SyncFoldersConfig.SchedulerNamePath2)"
    $validateSchedulerName = "$($SyncFoldersConfig.AppName).$($SyncFoldersConfig.ValidateSchedulerName)"

    if(Get-ScheduledTask | Where-Object {$_.TaskName -eq $path1SchedulerName}){
        Write-GSLog "Stopping $($path1SchedulerName) scheduler"
        Get-ScheduledTask | Where-Object {$_.TaskName -eq $path1SchedulerName} | Stop-ScheduledTask

        Start-Sleep -Seconds 2
        
        Write-GSLog "Removing $($path1SchedulerName) scheduler"
        Unregister-ScheduledJob $path1SchedulerName
    }

    if(Get-ScheduledTask | Where-Object {$_.TaskName -eq $path2SchedulerName}){
        Write-GSLog "Stopping $($path2SchedulerName) scheduler"
        Get-ScheduledTask | Where-Object {$_.TaskName -eq $path2SchedulerName} | Stop-ScheduledTask

        Start-Sleep -Seconds 2
        
        Write-GSLog "Removing $($path2SchedulerName) scheduler"
        Unregister-ScheduledJob $path2SchedulerName
    }

    if(Get-ScheduledTask | Where-Object {$_.TaskName -eq $validateSchedulerName}){
        Write-GSLog "Stopping $($validateSchedulerName) scheduler"
        Get-ScheduledTask | Where-Object {$_.TaskName -eq $validateSchedulerName} | Stop-ScheduledTask

        Start-Sleep -Seconds 2

        Write-GSLog "Removing $($validateSchedulerName) scheduler"
        Unregister-ScheduledJob $validateSchedulerName
    }
}

function Confirm-GSFolderSyncConfig{

    $SyncFoldersConfig = Get-GSConfig -Module GSSyncFoldersModule -XPath 'root'
    
    if([string]::IsNullOrWhiteSpace($SyncFoldersConfig.AppName)){
        do{
            $AppName = Read-Host "Enter App Name"        
        }while([string]::IsNullOrWhiteSpace($AppName))

        Set-GSConfig -Module GSSyncFoldersModule -XPath 'root/AppName' -Value $AppName
    }
    
    if([string]::IsNullOrWhiteSpace($SyncFoldersConfig.Path1) -or (-not (Test-Path -Path $SyncFoldersConfig.Path1))){
        Write-GSLog "Invalid Path 1 $($SyncFoldersConfig.Path1)"
    
        do{
            $Path1 = Read-Host "Enter valid Path 1"  
            
        }while([string]::IsNullOrWhiteSpace($Path1) -or (-not (Test-Path -Path $Path1)))
    
        Set-GSConfig -Module GSSyncFoldersModule -XPath 'root/Path1' -Value $Path1

        Write-GSLog "Path1 is set to $Path1"
    }
    
    if(-not (Test-Path -Path $SyncFoldersConfig.Path2)){
        Write-GSLog "Invalid Path 2 $($SyncFoldersConfig.Path2)"
    
        do{
            $Path2 = Read-Host "Enter valid Path 2"
            #New-Item -Path $Path2 -ItemType 'directory'
        }while(-not (Test-Path -Path $Path2))
        
        Set-GSConfig -Module GSSyncFoldersModule -XPath 'root/Path2' -Value $Path2

        Write-GSLog "Path2 is set to $Path2"    
    }
    
    if(-not ([bool]($SyncFoldersConfig.ValidateSchedulerInterval -as [int])) -or $SyncFoldersConfig.ValidateSchedulerInterval -le 0){        
        do{
            $ValidateSchedulerInterval = Read-Host "Enter Validate Scheduler Interval"        
        }while(-not ([bool]($ValidateSchedulerInterval -as [int])))

        Set-GSConfig -Module GSSyncFoldersModule -XPath 'root/ValidateSchedulerInterval' -Value $ValidateSchedulerInterval
    }
    
    if(-not ([bool]($SyncFoldersConfig.RetryCount -as [int])) -or $SyncFoldersConfig.RetryCount -le 0){        
        do{
            $RetryCount = Read-Host "Enter retry count"        
        }while(-not ([bool]($RetryCount -as [int])) -or $RetryCount -le 0)
        
        Set-GSConfig -Module GSSyncFoldersModule -XPath 'root/RetryCount' -Value $RetryCount
    }
    
    if(-not ([bool]($SyncFoldersConfig.WaitBtwnRetrySec -as [int])) -or $SyncFoldersConfig.WaitBtwnRetrySec -le 0){        
        do{
            $WaitBtwnRetrySec = Read-Host "Enter wait in seconds between retry"        
        }while(-not ([bool]($WaitBtwnRetrySec -as [int])) -or $WaitBtwnRetrySec -le 0)
        
        Set-GSConfig -Module GSSyncFoldersModule -XPath 'root/WaitBtwnRetrySec' -Value $WaitBtwnRetrySec
    }
    
    if(-not ([bool]($SyncFoldersConfig.MonitorNoOfChanges -as [int])) -or $SyncFoldersConfig.MonitorNoOfChanges -le 0){        
        do{
            $MonitorNoOfChanges = Read-Host "Enter no of changes to monitor"        
        }while(-not ([bool]($MonitorNoOfChanges -as [int])) -or $MonitorNoOfChanges -le 0)
        
        Set-GSConfig -Module GSSyncFoldersModule -XPath 'root/MonitorNoOfChanges' -Value $MonitorNoOfChanges
    }
    
    if(-not ([bool]($SyncFoldersConfig.MonitorNoOfChanges -as [int])) -or $SyncFoldersConfig.MonitorNoOfChanges -le 0){        
        do{
            $MonitorWaitMin = Read-Host "Enter minutes to monitor"        
        }while(-not ([bool]($MonitorNoOfChanges -as [int])) -or $MonitorNoOfChanges -le 0)
        
        Set-GSConfig -Module GSSyncFoldersModule -XPath 'root/MonitorWaitMin' -Value $MonitorWaitMin
    }
    
    if([string]::IsNullOrWhiteSpace($SyncFoldersConfig.SchedulerNamePath1) -or $SyncFoldersConfig.SchedulerNamePath1.InnerText){
        do{
            $SchedulerNamePath1 = Read-Host "Enter Scheduler Name for Path1"   
        }while([string]::IsNullOrWhiteSpace($SchedulerNamePath1))     

        Set-GSConfig -Module GSSyncFoldersModule -XPath 'root/SchedulerNamePath1' -Value $SchedulerNamePath1
    }
    
    if([string]::IsNullOrWhiteSpace($SyncFoldersConfig.SchedulerNamePath2) -or $SyncFoldersConfig.SchedulerNamePath2.InnerText){
        do{
            $SchedulerNamePath2 = Read-Host "Enter Scheduler Name for Path2"        
        }while([string]::IsNullOrWhiteSpace($SchedulerNamePath2))

        Set-GSConfig -Module GSSyncFoldersModule -XPath 'root/SchedulerNamePath2' -Value $SchedulerNamePath2
    }
    
    if([string]::IsNullOrWhiteSpace($SyncFoldersConfig.ValidateSchedulerName) -or $SyncFoldersConfig.ValidateSchedulerName.InnerText){
        do{
            $ValidateSchedulerName = Read-Host "Enter Validate Scheduler Name"        
        }while([string]::IsNullOrWhiteSpace($ValidateSchedulerName))

        Set-GSConfig -Module GSSyncFoldersModule -XPath 'root/ValidateSchedulerName' -Value $ValidateSchedulerName
    }
    
    $EmailConfig = Get-GSConfig -Module GSEmailModule -XPath 'root'
   
    if([string]::IsNullOrWhiteSpace($EmailConfig.Mode) -or $EmailConfig.Mode -notin ('GMAIL','SMTP') -or $EmailConfig.Mode.InnerText){
        do{
            $Mode = Read-Host "Enter valid Log Mode [GMAIL/SMTP]"        
        }while([string]::IsNullOrWhiteSpace($Mode) -or $Mode -notin ('GMAIL','SMTP'))

        Set-GSConfig -Module GSEmailModule -XPath 'root/Mode' -Value $Mode
    }
    
    if([string]::IsNullOrWhiteSpace($Mode)){
        $Mode = $EmailConfig.Mode
    }

    if($Mode -eq 'SMTP'){
        if([string]::IsNullOrWhiteSpace($EmailConfig.Smtpserver) -or $EmailConfig.Smtpserver.InnerText){
            do{
                $Smtpserver = Read-Host "Enter valid smtp server"        
            }While([string]::IsNullOrWhiteSpace($Smtpserver))

            Set-GSConfig -Module GSEmailModule -XPath 'root/smtp/Smtpserver' -Value $Smtpserver
        }

        if(-not ([bool]($EmailConfig.Port -as [int]))){
            do{
                $Port = Read-Host "Enter valid smtp server port"        
            }While(-not ([bool]($Port -as [int])))
            
            Set-GSConfig -Module GSEmailModule -XPath 'root/smtp/Port' -Value $Port
        }
    }

    if($Mode -eq 'GMAIL'){
        if([string]::IsNullOrWhiteSpace($EmailConfig.gmail.smtp) -or $EmailConfig.gmail.smtp.InnerText){
            do{
                $smtp = Read-Host "Enter valid smtp server"        
            }While([string]::IsNullOrWhiteSpace($smtp))

            Set-GSConfig -Module GSEmailModule -XPath 'root/gmail/smtp' -Value $smtp
        }

        if(-not ([bool]($EmailConfig.gmail.port -as [int]))){
            do{
                $Port = Read-Host "Enter valid smtp server port"        
            }While(-not ([bool]($Port -as [int])))
            
            Set-GSConfig -Module GSEmailModule -XPath 'root/gmail/port' -Value $Port
        }
        if([string]::IsNullOrWhiteSpace($EmailConfig.gmail.username) -or $EmailConfig.gmail.username.InnerText){
            do{
                $username = Read-Host "Enter valid gmail user name"        
            }While([string]::IsNullOrWhiteSpace($username))

            Set-GSConfig -Module GSEmailModule -XPath 'root/gmail/username' -Value $username
        }
        if([string]::IsNullOrWhiteSpace($EmailConfig.gmail.password) -or $EmailConfig.gmail.password.InnerText){
            do{
                $password = Read-Host "Enter valid gmail app password" -AsSecureString
            }While([string]::IsNullOrWhiteSpace($password))

            Set-GSConfig -Module GSEmailModule -XPath 'root/gmail/password' -Value (ConvertFrom-SecureString -SecureString $password)
        }
    }
    
    if([string]::IsNullOrWhiteSpace($EmailConfig.FromEmailId) -or $EmailConfig.FromEmailId.InnerText){
        do{
            $FromEmail = Read-Host "Enter from email address"        
        }while([string]::IsNullOrWhiteSpace($FromEmail))

        Set-GSConfig -Module GSEmailModule -XPath 'root/FromEmailId' -Value $FromEmail
    }
    
    if([string]::IsNullOrWhiteSpace($EmailConfig.ToEmailId) -or $EmailConfig.ToEmailId.InnerText){
        do{
            $ToEmail = Read-Host "Enter to email address"        
        }while([string]::IsNullOrWhiteSpace($ToEmail))

        Set-GSConfig -Module GSEmailModule -XPath 'root/ToEmailId' -Value $ToEmail
    }
    
    if([string]::IsNullOrWhiteSpace($EmailConfig.Subject) -or $EmailConfig.Subject.InnerText){
        do{
            $Subject = Read-Host "Enter to subject for notification email"        
        }while([string]::IsNullOrWhiteSpace($Subject))

        Set-GSConfig -Module GSEmailModule -XPath 'root/Subject' -Value $Subject
    }

    $LogConfig = Get-GSConfig GSLogModule
    
    if([string]::IsNullOrWhiteSpace($LogConfig.LogMode) -or $LogConfig.LogMode -notin ('FILE','EMAIL')){
        do{
            $LogMode = Read-Host "Enter to valid Log Mode [FILE / EMAIL]"        
        }while([string]::IsNullOrWhiteSpace($LogMode) -or $LogMode -notin ('FILE','EMAIL'))

        Set-GSConfig -Module GSLogModule -XPath 'root/LogMode' -Value $LogMode
    }
    
    Set-GSConfig -Module GSLogModule -XPath 'root/LogPath' -Value (Join-Path $SyncFoldersConfig.InstallationPath 'Log')
}