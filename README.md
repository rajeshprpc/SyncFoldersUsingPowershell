# SyncFoldersUsingPowershell
In case of files uploaded through FTP Load Balancer, the uploaded files will be available only in 1 server whereas it should be available in all load balanced servers for reading it. This script helps to sync between 2 servers using RoboCopy windows command.

### Why PowerShell instead of Batch Command
- Since the Copy operation can be failed due to various reasons, this should be monitored.
- Registering scripts as modules can be reused in case the same functionality is required for multiple operations
- Creating Task Schedulers and sending email about any failure in copy operation can be automated

### What this scripts does
- By running setup.ps1, it registers 4 modules. 
- UtilityModule - For registering other modules and has other utility functions -- Get-GSModulePath, Get-GSConfig, Get-GSConfigXml, Get-GSConfigPath, Set-GSConfig, Set-GSConfigXML, Copy-GSConfigFiles
- LogModule - Logging functions --Write-GSLog
- EmailModule - Email related functions --Send-GSEmail
- SyncFoldersModule - Task Scheduler and Copy operations -- Initialize-GSFoldersSync, Copy-GSFoldersAndFiles, Initialize-GSFoldersSyncScheduler, Confirm-GSFolderSync, Stop-GSFoldersSync, Confirm-GSFolderSyncConfig
- Registered modules can be found under the program files

    ![image](https://user-images.githubusercontent.com/9925030/195577898-781d1520-b017-4ed1-b74a-4c7ac1245444.png)
- Creates new folder "[AppName]" in program files (x86)
- Copies all module's configuration files ".xml" to the new folder
- Creates 3 Task schedulers under "Microsoft -> Windows -> PowerShell -> ScheduledJobs"
- "[SchedulerNamePath1]" - For copying files from path1 to path2. Scheduler will start after 1 min on installation and restarts every day 12:00 AM 
- "[SchedulerNamePath2]" - For copying files from path2 to path1. Scheduler will start after 1 min on installation and restarts every day 12:00 AM
- "[ValidateSchedulerName]" - For sending notifications about the copy operations. Scheduler will run for every 15mins

### Configurations
#### GSSyncFoldersModule.xml
-	AppName *^ – Schedulers and log uses this name 
-	Path1 * – From folder path to copy files
-	Path2 * – To Folder path to save files (Path if not exists system will create)
-	InstallationPath *^ – Path for storing the configurations and logs. New folder is created with the App name.
-	ValidateSchedulerInterval * – Checks the status of the copy operation job on specified interval and triggers email
-	RetryCount * – No of retries to perform when there is any error during copy operation
-	WaitBtwnRetrySec * – Wait in seconds before next retry
-	MonitorNoOfChanges * – Monitors no of new file or folder changes and if reaches the specified count, copy operation initiated
-	MonitorWaitMin * – Wait for specified minutes before checking for any new files or folders and initiates copy operation
-	SchedulerNamePath1 *^ – Task scheduler is created as “AppName. SchedulerNamePath1“ for copying files from Path1 to Path2
-	SchedulerNamePath2 *^ – Task scheduler is created as “AppName. SchedulerNamePath2“ for copying files from Path2 to Path1
-	ValidateSchedulerName *^ – Task Scheduler is created with this “AppName. ValidateSchedulerName“ to validate copy operation and sends status
#### GSEmailModule.xml – (Email triggered with the status of the copy operation)
-	Mode * – SMTP / GMAIL
-	Smtp -> Smtpserver (* in case of Mode is SMTP) – smtp Server name
-	Smtp -> Port (* in case of Mode is SMTP)– smtp port number
-	GMAIL -> Smtp (* in case of Mode is GMAIL) – smtp Server name
-	GMAIL -> Port (* in case of Mode is GMAIL) – smtp port number
-	GMAIL -> UserName (* in case of Mode is GMAIL) – Gmail email id
-	GMAIL -> Password (* in case of Mode is GMAIL) – Gmail app specific password will be captured during installation step, should be blank
-	FromEmailId * – From email id (When Mode is Gmail User Id will be always Gmail UserName)
-	ToEmailId * - Multiple email address can separate by semicolon
-	CCEmailId (Optional) – Multiple email address can separate by semicolon
-	Subject * – Email subject for the status email. #STATUS# - Success / Fail, #EXECUTION_DATE# - Verified date time
#### GSLogModule.xml – (Logging the installation and job running status)
-	LogMode * – FILE
-	LogPath * – Log file path (Default: C:\Program Files (x86)\SynchronizeFolders)
### Note: 
- *- Mandatory configurations and cannot be blank
- ^- Modifications will not reflect immediately re-running setup.ps1 or specific module .ps1 is required

### Commands executed
- Robocopy $path1 $path2 /TEE /E /S /XC /MT:8 /MON:[MonitorNoOfChanges] /MOT:[MonitorWaitMin] /R:[RetryCount] /W:[WaitBtwnRetrySec] /LOG+:[LogFilePath]
- Robocopy $path2 $path1 /TEE /E /S /XC /MT:8 /MON:[MonitorNoOfChanges] /MOT:[MonitorWaitMin] /R:[RetryCount] /W:[WaitBtwnRetrySec] /LOG+:[LogFilePath]
- Robocopy $path1 $path2 /S /E /L /NJS /NJH /NDL /NC /NS
