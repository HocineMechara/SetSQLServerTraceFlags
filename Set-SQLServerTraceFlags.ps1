function Set_SQLServerTraceFlags{

    param(
        [Parameter(Mandatory=$true)]
        [string]$RestartInstance,
        
        [Parameter(Mandatory=$true)]
        [string[]]$Traceflags,

        [Parameter(Mandatory=$true)]
        [string[]]$Servers,

        [Parameter(Mandatory=$true)]
        [System.Management.Automation.PSCredential]$cred

        )

    foreach ($Server in $Servers)

    {

    $SQLInstances = Invoke-Command -ComputerName $Server -ScriptBlock {
    Get-Service | Where-Object { $_.Name -like 'MSSQL$*' -or $_.Name -eq 'MSSQLSERVER' }
    } -Credential $cred

        foreach ($SQLInstance in $SQLInstances)
        {

            if($SQLInstance.Name -eq "MSSQLSERVER")
            {
                $InstanceName = "MSSQLSERVER"
            }
            else
                {
                $InstanceName = $SQLInstance.Name -replace '.*\$', ''
                }

            $Dynamicdirectory = Invoke-Command -ComputerName $Server -ScriptBlock {
            (Get-ChildItem -Path 'HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server' | where-object {$_.Name -like "*.$($using:InstanceName)"}).Name -replace '.+\\', ''
            } -Credential $cred

            $RegPath = "HKLM:\SOFTWARE\Microsoft\Microsoft SQL Server\"+$Dynamicdirectory+"\MSSQLServer\Parameters"

            $RestartPending = 0 ##
    
            Foreach($Traceflag in $Traceflags)
            {
                Start-Sleep -Milliseconds 1
                $TraceflagName = '-T'+$Traceflag
                $Timestamp = (Get-Date -Format 'yyyyMMddHHmmssfff').ToString()
                $registryName = 'SQLArg' + $Timestamp

                $RegistryValue = Invoke-Command -ComputerName $Server -ScriptBlock {
                Get-ItemProperty -Path $using:RegPath | where-object { $_.PSObject.Properties.Value -eq "$($using:TraceflagName)"}
                } -Credential $cred

                ##
                if($RegistryValue -eq $null)
                {
                    Invoke-Command -ComputerName $Server -ScriptBlock {
                    Set-ItemProperty -Path $using:RegPath -Value $using:TraceflagName -Name $using:registryName
                    } -Credential $cred

                    Write-Host "The Traceflag $($TraceflagName) has been set for $($InstanceName) on $($Server)." -ForegroundColor Green
                    $RestartPending = 1

                }
                else
                    {
                    Write-Host "The Traceflag: $($TraceflagName) is already in place for $($InstanceName)." -ForegroundColor Magenta
                    }
            }

            if($RestartPending -eq 1 -and $RestartInstance -eq 'Y')
            {
                Write-Host "Restarting the instance $($SQLInstance.Name) on $($Server)..." -ForegroundColor Yellow
                Invoke-Command -ComputerName $Server -ScriptBlock {
                Restart-Service -Name $using:SQLInstance.Name -Force
                } -Credential $cred
                $ServiceAfterRestart = Get-Service | Where-Object { $_.Name -eq $SQLInstance.Name}
                Write-Host "The instance $($ServiceAfterRestart.Name) has been restarted." -ForegroundColor Yellow
            }

        }

    }
}
