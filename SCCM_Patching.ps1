param (
    [Parameter(Position=1,ValueFromPipeLine=$True)]
	[string[]]$ComputerName,
	[ValidateSet("Evaluate","Get","Install")]
	[string]$Action = "Get",
	[ValidateSet("Application","Update","All")]
	[string]$Type = "Update",
	[string]$Name = "All",
	[switch]$Summary,
	[switch]$Reboot,
	[switch]$Confirm = $True,
	[switch]$AsJob
)

$KnownTrustedSuffix = ".nextestate.com",".dc1.greendotcorp.com"
[regex]$KnownUntrustedPattern = "dmz|rush|an.local|gdd|sbbtral"

$HostList = @($Input)
if ($ComputerName) {
    if ($ComputerName -match " ") {
        $HostsArr = @($ComputerName.split(" "))
        $HostList += $HostsArr
    }
    elseif ($ComputerName -match ",") {
        $HostsArr = @($ComputerName.split(","))
        $HostList += $HostsArr
    }
    else {
        $HostList += $ComputerName
    }
    $HostList = $HostList -ne " "
}

$Servers = $HostList | Select-Object -Unique

$ErrorActionPreference = "SilentlyContinue"

$ScriptName = (($MyInvocation.MyCommand.Name).Split("."))[0..((($MyInvocation.MyCommand.Name).Split(".") | Measure-Object).Count -2)] -join "."
#$scriptPath = Split-Path -parent $MyInvocation.MyCommand.Definition
$OutputPath = "c:\temp"
$DateTime = Get-Date
#No need for export to csv for a single host
if (($Servers | Measure-Object).count -gt 1) {
	$StrDateTime = $DateTime.ToString("yyyyMMdd-hhmmss")
	#csv files are created under the $OutputPath, with date time appeneded to the file name
	$OutputCsv = Join-Path -Path $OutputPath -ChildPath "$ScriptName-$Action-$Type-$Name-$StrDateTime.csv"
}
#rotate logs older than 60 days
Get-ChildItem "$OutputPath\$ScriptName*.csv" | Where-Object {($DateTime - $_.LastWriteTime).Totaldays -gt 60 } | Remove-Item -Force

$EvaluateSb = {
	param ($Type)
	#$Obj = "" | Select-Object -Property MachinePolicyRetr,MachinePolicyEval,SUAssignEval,SUScan,SUDeployEval,AppDeployEval
	$Obj = "" | Select-Object -Property Type,Succeeded
	$Obj.Type = $Type
	$Obj.Succeeded = $True
	#Machine Policy Retrieval Cycle
	$Obj.Succeeded = $Obj.Succeeded -and (Invoke-WMIMethod -Namespace "root\CCM" -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000021}")
	#Machine Policy Evaluation Cycle
	$Obj.Succeeded = $Obj.Succeeded -and (Invoke-WMIMethod -Namespace "root\CCM" -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000022}")
	if ($Type -ne "Application") {
		#Software Updates Assignments Evaluation Cycle
		$Obj.Succeeded = $Obj.Succeeded -and (Invoke-WMIMethod -Namespace "root\CCM" -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000108}")
		#Software Update Scan Cycle
		$Obj.Succeeded = $Obj.Succeeded -and (Invoke-WMIMethod -Namespace "root\CCM" -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000113}")
		#Software Update Deployment Evaluation Cycle
		$Obj.Succeeded = $Obj.Succeeded -and (Invoke-WMIMethod -Namespace "root\CCM" -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000114}")
	}
	if ($Type -ne "Update") {
		#Application Deployment Evaluation Cycle
		$Obj.Succeeded = $Obj.Succeeded -and (Invoke-WMIMethod -Namespace "root\CCM" -Class SMS_CLIENT -Name TriggerSchedule "{00000000-0000-0000-0000-000000000121}")
	}
	$Obj
}

$GetUpdateSb = {
	param ($Article)
	#$OS = (Get-WmiObject -Class WWin32_OperatingSystem -Property Caption,LastBootupTime)
	#$LastBootupTime = $OS.ConvertToDateTime($OS.LastBootupTime)
	#$LastBootupTimeFormat = $LastBootupTime.ToString("yyyy/MM/dd hh:mm:ss")
	#$Uptime = ((Get-Date) - $LastBootupTime).ToString()
	$Updates = Get-WmiObject -Namespace "root\CCM\ClientSDK" -Class CCM_SoftwareUpdate
	if ($Article -ne "All") {
		$Updates = $Updates | Where-Object {$_.ArticleId -like $Article}
	}
	If (($Updates | Measure-Object).Count -lt 1) {
		"" | Select-Object ArticleId,Name,@{l="InstallState";e={"NoUpdates"}},EvaluationState,ComplianceState,ErrorCode,@{l="Type";e={"Update"}}
	}
	Else {
		$hashUpdateEvlCodes = [ordered]@{
			"0" = "None"
			"1" = "Available"
			"2" = "Submitted"
			"3" = "Detecting"
			"4" = "PreDownload"
			"5" = "Downloading"
			"6" = "WaitInstall"
			"7" = "Installing"
			"8" = "PendingSoftReboot"
			"9" = "PendingHardReboot"
			"10" = "WaitReboot"
			"11" = "Verifying"
			"12" = "InstallComplete"
			"13" = "Error"
			"14" = "WaitServiceWindow"
			"15" = "WaitUserLogon"
			"16" = "WaitUserLogoff"
			"17" = "WaitJobUserLogon"
			"18" = "WaitUserReconnect"
			"19" = "PendingUserLogoff"
			"20" = "PendingUpdate"
			"21" = "WaitingRetry"
			"22" = "WaitPresModeOff"
			"23" = "WaitForOrchestration"
		}
		$Updates | Select-Object ArticleId,Name,@{l="InstallState";e={$hashUpdateEvlCodes["$($_.EvaluationState)"]}},EvaluationState,ComplianceState,ErrorCode,@{l="Type";e={"Update"}}
	}
}

$GetApplicationSb = {
	param ($Name)
	$Applications = Get-WmiObject -Namespace "root\CCM\ClientSDK" -Class CCM_Application
	if ($Name -ne "All") {
		$Applications = $Applications | Where-Object {$_.Name -like $Name -and $_.EvaluationState -ne 2}
	}
	If (($Applications | Measure-Object).Count -lt 1) {
		"" | Select-Object ArticleId,Name,@{l="InstallState";e={"NoApplications"}},EvaluationState,ComplianceState,ErrorCode,@{l="Type";e={"Application"}}
	}
	Else {
		$Applications | Select-Object ArticleId,Name,InstallState,EvaluationState,ComplianceState,ErrorCode,@{l="Type";e={"Application"}}
	}
}

$InstallUpdateSb = {
	param ($Article)
	$GetUpdates = {
		param ($Article)
		$Updates = Get-WmiObject -Namespace "root\CCM\ClientSDK" -Class CCM_SoftwareUpdate
		if ($Article -ne "All") {
			$Updates = $Updates | Where-Object {$_.ArticleId -like $Article}
		}
		$Updates
	}
	$PendingUpdates = . $GetUpdates -Article $Article
	$TotalCount = ($PendingUpdates | Measure-Object).Count
	if ($TotalCount -gt 0) {
        if ($PendingUpdates | Where-Object {$_.EvaluationState -le 7}) { 
		    ([wmiclass]"root\CCM\ClientSDK:CCM_SoftwareUpdatesManager").InstallUpdates([System.Management.ManagementObject[]]$PendingUpdates)
        }
		Do {
			$FinishedUpdates = . $GetUpdates -Article $Article | Where-Object {$_.EvaluationState -gt 7}
			$FinishedCount = ($FinishedUpdates | Measure-Object).Count
			$CurrentIndex = $FinishedCount
			#if ($FinishedCount -eq $TotalCount) {
			#	Write-Progress -Activity "Completed" -Status "Update $CurrentIndex of $TotalCount" -CurrentOperation "" -PercentComplete ((($FinishedCount + $($CurrentArticle.PercentComplete) / 100) / $TotalCount) * 100)
			#}
			#else {
			$CurrentArticle = . $GetUpdates -Article $Article | Where-Object {$_.EvaluationState -eq 7}
			if ($CurrentArticle) {
				$CurrentIndex++
				$CurrentArticleId = "KB" + $CurrentArticle.ArticleId
				#$CurrentArticleName = $CurrentArticle.Name.Replace("`($CurrentArticleId`)","").Replace("for x64-based systems","").TrimEnd()
				$CurrentArticleName = (($CurrentArticle.Name.Replace("`($CurrentArticleId`)","")) -ireplace [regex]::Escape("for x64-based systems"),"").TrimEnd()
				#if ($CurrentArticle.PercentComplete) {
				$CurrentArticlePercentComplete = $($CurrentArticle.PercentComplete).ToString() + "%"
				#}
				#else {
				#	$CurrentArticlePercentComplete = "0%"
				#}
				Write-Progress -Activity "Installing..." -Status "Update $CurrentIndex of $TotalCount" -CurrentOperation "$CurrentArticlePercentComplete of $CurrentArticleId $CurrentArticleName" -PercentComplete ((($FinishedCount + $($CurrentArticle.PercentComplete) / 100) / $TotalCount) * 100)
			}
			else {
				if ($FinishedCount -eq $TotalCount) {$Activity = "Completed"} 
				else {$Activity = "Waiting..."}
				Write-Progress -Activity $Activity -Status "Update $FinishedCount of $TotalCount" -CurrentOperation "" -PercentComplete (($FinishedCount / $TotalCount) * 100)
			}
			Start-Sleep -Seconds 2
			#}
		}
		while ((. $GetUpdates -Article $Article | Where-Object {$_.EvaluationState -le 7} | Measure-Object).Count -gt 0)
		#Skip output, leave to $GetUpdateSb for more properties
		#. $GetUpdates -Article $Article | Select-Object ArticleId,Name,InstallState,EvaluationState,ComplianceState,ErrorCode
		#Invoke-Expression -ScriptBlock $Using:getUpdates_sb -ArgumentList $Article
	}
}

$InstallApplicationSb = {
	param ($Name)
	$GetApplications = {
		param ($Name)
		$Applications = Get-WmiObject -Namespace "root\CCM\ClientSDK" -Class CCM_Application
		if ($Name -ne "All") {
			$Applications = $Applications | Where-Object {$_.Name -like $Name -and $_.EvaluationState -ne 2}
		}
		$Applications
	}
	$PendingApplications = . $GetApplications -Name $Name | Where-Object {$_.InstallState -ne "Installed"}
	$TotalCount = ($PendingApplications | Measure-Object).Count
	if ($TotalCount -gt 0) {
		foreach ($Application in $PendingApplications) {
			$InstallArgs = @{
				EnforcePreference = [UINT32] 0
				Id = "$($Application.id)"
				IsMachineTarget = $Application.IsMachineTarget
				IsRebootIfNeeded = $False
				Priority = 'High'
				Revision = "$($Application.Revision)"
			}
			#if InstallState is Error, the install method doesn't work, need to use repair instead
			if ($PendingApplications.InstallState -eq "Error") {$AppInstallMethod = "Repair"}
			else {$AppInstallMethod = "Install" }
			Invoke-CimMethod -Namespace "root\CCM\ClientSDK" -ClassName CCM_Application -Arguments $InstallArgs -MethodName $AppInstallMethod | Out-Null
		}
	}
	#Wait for 10 seconds to ensure the installstate is properly updated
	Start-Sleep -Seconds 10
	Do {
		$FinishedApplications = $PendingApplications | ForEach-Object {. $GetApplications -Name $_.Name} | Where-Object {$_.EvaluationState -le 4}
		$FinishedCount = ($FinishedApplications | Measure-Object).Count
		$CurrentIndex = $FinishedCount
		$CurrentApplication = . $GetApplications -Name $Name | Where-Object {$_.EvaluationState -eq 12}
		if ($CurrentApplication) {
			$CurrentIndex++
			$CurrentApplicationPercentComplete = $($CurrentApplication.PercentComplete).ToString() + "%"
			Write-Progress -Activity "Installing..." -Status "Application $CurrentIndex of $TotalCount" -CurrentOperation "$CurrentApplicationPercentComplete of $($CurrentApplication.Name)" -PercentComplete ((($FinishedCount + $($CurrentApplication.PercentComplete) / 100) / $TotalCount) * 100)
		}
		else {
			if ($FinishedCount -eq $TotalCount) {$Activity = "Completed"}
			else {$Activity = "Waiting..."}
			Write-Progress -Activity $Activity -Status "Application $FinishedCount of $TotalCount" -CurrentOperation "" -PercentComplete (($FinishedCount / $TotalCount) * 100)
		}
		Start-Sleep -Seconds 5
	}
	while ((. $GetApplications -Name $Name | Where-Object {$_.EvaluationState -gt 4} | Measure-Object).Count -gt 0)
	#. $GetApplications -Article $Article | Select-Object ArticleId,Name,InstallState,EvaluationState,ComplianceState,ErrorCode
}

#Cleanup all jobs
Get-Job | Remove-Job -Force
$Types = @()
switch ($Type) {
	"All" {$Types = "Update","Application"}
	Default {$Types = $Type}
}
$Servers | ForEach-Object {
	$Suffix = (Resolve-DnsName $_).Name.Replace($_,"")
	if ($_ -notmatch "\." -and $Suffix -notin $KnownTrustedSuffix -or $Suffix -match $KnownUntrustedPattern) {$AuthMethod = "Negotiate"}
	else {$AuthMethod = "Default"}
	if ($Action -eq "Evaluate") {
		Invoke-Command -ComputerName $_ -ArgumentList $Type -ScriptBlock $EvaluateSb -AsJob -JobName $_ -Authentication $AuthMethod | Out-Null
	}
	else {
		ForEach ($Type in $Types) {
			Invoke-Command -ComputerName $_ -ArgumentList $Name -ScriptBlock ("`$$($Action)$($Type)Sb" | Invoke-Expression) -asJob -JobName "$($_)-$Type" -Authentication $AuthMethod | Out-Null
		}
	}
}
if ($Action -ne "Install" -or !($AsJob)) {
	if (Get-Job) {
		do {
			if ($Action -eq "Install") {
				Clear-Host
				$ProgressCol = @()
				Get-Job | ForEach-Object {$ProgressCol +=  New-Object -TypeName PSObject -property @{"Name" = $_.Name;"Activity" = ($_.ChildJobs[0].Progress[-1]).Activity;"Status" = ($_.ChildJobs[0].Progress[-1]).StatusDescription;"Operation" = ($_.ChildJobs[0].Progress[-1]).CurrentOperation;"Percent" = ($_.ChildJobs[0].Progress[-1]).PercentComplete} }
				#Use '| Out-String | Write-Host' to display the output to the host instead of return as object
				$ProgressCol | Select-Object Name,Activity,Status,Operation,Percent | Format-Table -AutoSize | Out-String | Write-Host
				Start-Sleep -Seconds 5
			}
			else {
				$Jobs = Get-Job
				$NotRunningJobsCount = ($Jobs | Where-Object {$_.State -ne "Running"} | Measure-Object).Count
				$AllJobsCount = ($Jobs | Measure-Object).Count 
				$Percent = $NotRunningJobsCount / $AllJobsCount * 100
				Write-Progress -Activity "Waiting for Jobs Completion..." -Status "$NotRunningJobsCount of $AllJobsCount Completed" -PercentComplete $Percent
				Start-Sleep -Seconds 1
			}
		}
		while ((Get-Job | Where-Object {$_.State -eq "Running"} | Measure-Object).count -gt 0)
		#prompt warning for failed jobs
		$FailedJobs = Get-Job | Where-Object {$_.State -eq "Failed"}
		if ($FailedJobs) {
			$FailedJobs | ForEach-Object {Write-Warning "Job ""$($_.Name)"" failed, please check manually!"}
		}
		if ($Action -eq "Install") {
            #write progress again after all jobs are completed, sometimes it's not correctly displayed
            Clear-Host
            $ProgressCol = @()
            Get-Job | ForEach-Object {$ProgressCol +=  New-Object -TypeName PSObject -property @{"Name" = $_.Name;"Activity" = ($_.ChildJobs[0].Progress[-1]).Activity;"Status" = ($_.ChildJobs[0].Progress[-1]).StatusDescription;"Operation" = ($_.ChildJobs[0].Progress[-1]).CurrentOperation;"Percent" = ($_.ChildJobs[0].Progress[-1]).PercentComplete} }
            $ProgressCol | Select-Object Name,Activity,Status,Operation,Percent | Format-Table -AutoSize | Out-String | Write-Host
			Write-Host "All Installation Jobs Completed, Checking Installation Status..." -ForegroundColor Green
			Get-Job | Remove-Job -Force
			$Servers | ForEach-Object {
				$Suffix = (Resolve-DnsName $_).Name.Replace($_,"")
				if ($_ -notmatch "\." -and $Suffix -notin $KnownTrustedSuffix -or $Suffix -match $KnownUntrustedPattern) {$AuthMethod = "Negotiate"}
				else {$AuthMethod = "Default"}
				ForEach ($Type in $Types) {
					Invoke-Command -ComputerName $_ -ArgumentList $Name -ScriptBlock ("`$Get$($Type)Sb" | Invoke-Expression) -asJob -JobName "$($_)-$Type" -Authentication $AuthMethod | Out-Null
				}
			}
			do {
				$Jobs = Get-Job
				$NotRunningJobsCount = ($Jobs | Where-Object {$_.State -ne "Running"} | Measure-Object).Count
				$AllJobsCount = ($Jobs | Measure-Object).Count
				$Percent = $NotRunningJobsCount / $AllJobsCount * 100
				Write-Progress -Activity "Waiting for Jobs Completion..." -Status "$NotRunningJobsCount of $AllJobsCount Completed" -PercentComplete $Percent
				Start-Sleep -Seconds 5
			}
			while ((Get-Job | Where-Object {$_.State -eq "Running"} | Measure-Object).count -gt 0)
		}
		$Results = Get-Job | Receive-Job
		if ($Action -ne "Evaluate") {
			$Results = $Results | Select-Object PSComputerName,ArticleId,@{l="Name";e={(($_.Name.Replace("`(KB$($_.ArticleId)`)","")) -ireplace [regex]::Escape("for x64-based systems"),"").TrimEnd()}},InstallState,EvaluationState,ComplianceState,ErrorCode,Type
		}
		else {
			$Results = $Results | Select-Object PSComputerName,Type,Succeeded
		}
		if (!($Summary)) {$Results}
		else {
			$GroupByComputer = $Results | Group-Object -Property PSComputerName
			Foreach ($Computer in $GroupByComputer) {
				#TODO: need better logic to show the summary view, additional properties can be added if necessary
				$Obj = "" | Select-Object -Property PSComputerName,TotalUpdates,PendingRebootUpdates,TotalApps,InstalledApps,Status
				$Obj.PSComputerName = $Computer.Name
				$Obj.TotalUpdates = ($Computer.Group | Where-Object {$_.Type -eq "Update" -and $_.InstallState -ne "NoUpdates"} | Measure-Object).Count
				$Obj.PendingRebootUpdates = ($Computer.Group | Where-Object {$_.Type -eq "Update" -and $_.InstallState -eq "PendingSoftReboot"} | Measure-Object).Count
				$Obj.ErrorUpdates = ($Computer.Group | Where-Object {$_.Type -eq "Update" -and $_.InstallState -eq "Error"} | Measure-Object).Count
				$Obj.TotalApps = ($Computer.Group | Where-Object {$_.Type -eq "Application" -and $_.InstallState -ne "NoApplications"} | Measure-Object).Count
				$Obj.InstalledApps = ($Computer.Group | Where-Object {$_.Type -eq "Applicatoin" -and $_.InstallState -eq "Installed"} | Measure-Object).Count
				$Obj.ErrorApps = ($Computer.Group | Where-Object {$_.Type -eq "Application" -and $_.InstallState -eq "Error"} | Measure-Object).Count
				$Obj.Status = $(
					if ($Obj.TotalUpdates -eq 0 -and ($Obj.InstalledApps -eq $Obj.TotalApps)) {"OK"}
					elseif ($Obj.TotalUpdates -gt 0 -and ($Obj.TotalUpdates -eq $Obj.PendingRebootUpdates)) {"PendingReboot"}
					elseif ($Obj.ErrorUpdates -gt 0) {"UpdateError"}
					elseif ($Obj.ErrorApps -gt 0) {"ApplicationError"}
					elseif ($Computer.Group | Where-Object {$_.Type -eq "Update" -and $_.EvaluationState -le 1}) {"UpdateNotStarted"}
					#TODO: need better logic for the overall status property
					else {"InProgress"}
				)
				$Obj
			}
			Write-Host
		}
		#$Results | Sort-Object -Property PSComputerName,ArticleId,InstallState
		#No need for export to csv for a single host
		if (($Servers | Measure-Object).count -gt 1 -and $Results) {
			$Results | Export-Csv $OutputCsv -NoTypeInformation
			Write-Host "Results have been saved to $OutputCsv" -ForegroundColor Green
		}
		Write-Host
		#Safety check to ensure all $srvs have a result object
		$ResultsSrvList = $Results | Select-Object -ExpandProperty PSComputerName | Select-Object -Unique
		if (($ResultsSrvList | Measure-Object).count -ne ($Srv | Measure-Object).count) {
			$MissingSrvList = $Servers | Where-Object {$_ -notin $ResultsSrvList}
			$MissingSrvList | ForEach-Object {Write-Warning "Server ""$_"" doesn't have any returned data, please check manually!"}
		}
		#reboot Only support all software update case
		if ($Type -eq "Update" -and $Name -eq "All") {
			$PendingRebootHosts = $Results | Group-Object -Property PSComputerName | Where-Object {($_.Group | Where-Object {$_.EvaluationState -eq 8}) -and ($_.Group.Count -eq (($_.Group | Where-Object {$_.EvaluationState -eq 8}) | Measure-Object).count)} | Select-Object -ExpandProperty Group | Select-Object -ExpandProperty PSComputerName | Sort-Object
			#$Results | Group-Object -Property PSComputerName | Foreach-Object {if (($_.Group | Where-Object {$_.ArticleId -ne "" -and $_.EvaluationState -eq 8} | Measure-Object).Count -ne 0 -and ($_.Group | Where-Object {$_.ArticleId -ne "" -and $_.EvaluationState -eq 8} | Measure-Object).Count -eq ($_.Group | Where-Object {$_.ArticleId -match "\d+"}).Count) {$PendingRebootHosts += $_.Name}}
			if ($PendingRebootHosts) {
				Write-Host "Pending Reboot Servers:" -ForegroundColor Yellow
				$PendingRebootHosts | ForEach-Object {Write-Host $_}
				Write-Host
			}
			if ($Reboot -and $PendingRebootHosts) {
				if ($Confirm) {$ConfirmInput = Read-Host -Prompt "Reboot Servers?"}
				else {$ConfirmInput = "Yes"}
				if ($ConfirmInput -in @("y","Y","yes","Yes","YES")) {
					$PendingRebootHosts | ForEach-Object {
						Write-Host "Rebooting $_"
						Restart-Computer $_ -Force
					}
				}
				else {Write-Host "Server will be rebooted manually"}
			}
		}
		elseif ($Reboot) {Write-Warning '-Reboot switch only supports -Type "Update" -Name "All"!'}
		Get-Job | Remove-Job -Force
	}
}
else {
	Start-Sleep -Seconds 5
	$FailedJobs = Get-Job | Where-Object {$_.State -eq "Failed"}
	if ($FailedJobs) {
		$FailedJobs | ForEach-Object {Write-Warning "Job ""$($_.Name)"" failed, please check manually!"}
	}
}