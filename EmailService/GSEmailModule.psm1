function Send-GSEmail{
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0)]
        [ValidateNotNullOrEmpty()]
        [string]$FromEmail,
        [Parameter(Mandatory, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$ToEmail,
        [Parameter(Mandatory, Position = 2)]
        [ValidateNotNullOrEmpty()]
        [string]$Subject,
        [Parameter(Mandatory, Position = 3)]
        [ValidateNotNullOrEmpty()]
        [string]$Body,
        [Parameter(Mandatory=$false, Position = 4)]
        [AllowEmptyString()]
        [string]$Priority,
        [Parameter(Mandatory=$false, Position = 5)]
        [AllowEmptyString()]
        [string]$CCEmail,
        [Parameter(Mandatory=$false, Position = 6)]
        [AllowEmptyString()]
        $BCCEmail
    )    

    begin{
     $ConfigXml = Get-GSConfig GSEmailModule
    }
    process{
        try{
            $MailArguments = @{
                From = $FromEmail
                Subject = $Subject
                Body = $Body
                UseSsl = $true
            }

            [string[]]$ToEmails = @()

            $ToEmail.Split(';') | ForEach-Object -Process{
                $ToEmails += $_
            }

            $MailArguments.Add("To",$ToEmails)
    
            if(-not ([string]::IsNullOrWhiteSpace($CCEmail))){

                [string[]]$CCEmails = @()
        
                $CCEmail.Split(';') | ForEach-Object -Process{
                    $CCEmails += $_
                }

                $MailArguments.Add("Cc",$CCEmails)
            }
    
            if(-not ([string]::IsNullOrWhiteSpace($BCCEmail))){

                [string[]]$BCCEmails = @()
        
                $BCCEmail.Split(';') | ForEach-Object -Process{
                    $BCCEmails += $_
                }

                $MailArguments.Add("BCC",$BCCEmails)
            }
    
            if(-not ([string]::IsNullOrWhiteSpace($Priority))){
                $MailArguments.Add("Priority",$Priority)
            }

            switch($ConfigXml.mode){
                "GMAIL"{
                    $Password = ConvertTo-SecureString -String $ConfigXml.gmail.password
                    $Credential = New-Object -TypeName PSCredential -ArgumentList $ConfigXml.gmail.username, $Password

                    $MailArguments.Add("SmtpServer",$ConfigXml.gmail.smtp)
                    $MailArguments.Add("port",$ConfigXml.gmail.port)
                    $MailArguments.Add("Credential",$Credential)
                }
                "SMTP"{
                    $MailArguments.Add("SmtpServer",$ConfigXml.smtp.smtpserver)
                    $MailArguments.Add("port",$ConfigXml.smtp.port)
                }
            }

            Write-Host $MailArguments

            Send-MailMessage @MailArguments
        }
        catch {
            Write-GSLog $_
        }
    }
    end{

    }
}