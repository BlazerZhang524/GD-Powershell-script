Write-Host "Input your admin account" -ForegroundColor Yellow
$cred = Get-Credential juz9
Import-Module ActiveDirectory
$DC="G2CPAD01"

#Get bitlocker recovery key
function get-bitlockerkey
{
Write-Host "Input computer name" -ForegroundColor Yellow
$name = Read-Host
$cn=Get-ADComputer $name
Get-ADObject -Filter {objectclass -eq 'msFVE-RecoveryInformation'} -SearchBase $cn.distinguishedname -Properties 'cn','msFVE-RecoveryPassword' -server $DC -Credential $cred | select @{n="Computername";e={$cn.Name}},CN,msFVE-RecoveryPassword #search Key information in AD
}

#Move OU and add group membership for new imaged computer
function new-computer
{
$groups=@("shanghai_patching P2_1","shanghai_patching P2_2","shanghai_patching P2_3","shanghai_patching P2_4")
$patchinggroup = Get-Random $groups
Write-Host "Input computer name" -ForegroundColor Yellow
$cn = Read-Host
if($cn -like "sha-*-l*")
{
get-adcomputer $cn -Server $DC | Move-ADObject -TargetPath "OU=CorpNetLaptops,OU=CORP_NET-205,OU=Workstations,DC=nextestate,DC=com" -Credential $cred -server $DC; #move OU
Add-ADGroupMember -Identity acs-vlan-gd-corp -Members (get-adcomputer $cn -Server $DC).SamAccountName -Credential $cred -Server $DC; #Add group
Add-ADGroupMember -Identity $patchinggroup -Members (get-adcomputer $cn -Server $DC).SamAccountName -Credential $cred -Server $DC
$OUstatus = (Get-ADComputer $cn -Server $DC| select distinguishedname).distinguishedname | Out-String
$Groupmemberstatus = (Get-ADComputer $cn -Properties memberof -Server $DC | select memberof).memberof | Out-String
if($OUstatus.Contains("OU=CorpNetLaptops,OU=CORP_NET-205,OU=Workstations,DC=nextestate,DC=com") -and $Groupmemberstatus.Contains("ACS-VLAN-GD-CORP") -and $Groupmemberstatus.Contains("Shanghai_Patching P2"))
{
Write-Host "operation done with success" -ForegroundColor Green
}
else
{
Write-Host "Error occured, Please check group membership and OU" -ForegroundColor Red
}
}
elseif($cn -like "sha-*-d*")
{
get-adcomputer $cn -Server $DC | Move-ADObject -TargetPath "OU=CorpNetDesktops,OU=CORP_NET-205,OU=Workstations,DC=nextestate,DC=com" -Credential $cred -server $DC; #move OU
Add-ADGroupMember -Identity acs-vlan-gd-corp -Members (get-adcomputer $cn -Server $DC).SamAccountName -Credential $cred -Server $DC; #Add group
Add-ADGroupMember -Identity $patchinggroup -Members (get-adcomputer $cn -Server $DC).SamAccountName -Credential $cred -Server $DC
$OUstatus = (Get-ADComputer $cn -Server $DC| select distinguishedname).distinguishedname | Out-String
$Groupmemberstatus = (Get-ADComputer $cn -Properties memberof -Server $DC| select memberof).memberof | Out-String
if($OUstatus.Contains("OU=CorpNetDesktops,OU=CORP_NET-205,OU=Workstations,DC=nextestate,DC=com") -and $Groupmemberstatus.Contains("ACS-VLAN-GD-CORP") -and $Groupmemberstatus.Contains("Shanghai_Patching P2"))
{
Write-Host "operation done with success" -ForegroundColor Green
}
else
{
Write-Host "Error occured, Please check group membership and OU" -ForegroundColor Red
}
}
else
{
Write-Host "Computer name $cn is not a validate name" -ForegroundColor Red
}
}
#Move OU and add group membership for new imaged Admin computer
function new-admincomputer
{
Write-Host "Input Admin computer name" -ForegroundColor Yellow
$cn = Read-Host
if($cn -like "sha-*-l*")
{
get-adcomputer $cn -Server $DC | Move-ADObject -TargetPath "OU=AdminNetLaptops,OU=ADMIN_NET-240,OU=Workstations,DC=nextestate,DC=com" -Credential $cred -server $DC; #move OU
Add-ADGroupMember -Identity ACS-VLAN-ADMIN -Members (get-adcomputer $cn -Server $DC).SamAccountName -Credential $cred -Server $DC; #Add group
Add-ADGroupMember -Identity "Shanghai_Patching P0" -Members (get-adcomputer $cn -Server $DC).SamAccountName -Credential $cred -Server $DC
$OUstatus = (Get-ADComputer $cn -Server $DC| select distinguishedname).distinguishedname | Out-String
$Groupmemberstatus = (Get-ADComputer $cn -Properties memberof -Server $DC | select memberof).memberof | Out-String
if($OUstatus.Contains("OU=AdminNetLaptops,OU=ADMIN_NET-240,OU=Workstations,DC=nextestate,DC=com") -and $Groupmemberstatus.Contains("ACS-VLAN-ADMIN") -and $Groupmemberstatus.Contains("Shanghai_Patching P0"))
{
Write-Host "operation done with success" -ForegroundColor Green
}
else
{
Write-Host "Error occured, Please check group membership and OU" -ForegroundColor Red
}
}
elseif($cn -like "sha-*-d*")
{
get-adcomputer $cn -Server $DC | Move-ADObject -TargetPath "OU=AdminNetDesktops,OU=ADMIN_NET-240,OU=Workstations,DC=nextestate,DC=com" -Credential $cred -server $DC; #move OU
Add-ADGroupMember -Identity ACS-VLAN-ADMIN -Members (get-adcomputer $cn -Server $DC).SamAccountName -Credential $cred -Server $DC; #Add group
Add-ADGroupMember -Identity "Shanghai_Patching P0" -Members (get-adcomputer $cn -Server $DC).SamAccountName -Credential $cred -Server $DC
$OUstatus = (Get-ADComputer $cn -Server $DC | select distinguishedname).distinguishedname | Out-String
$Groupmemberstatus = (Get-ADComputer $cn -Properties memberof -Server $DC| select memberof).memberof | Out-String
if($OUstatus.Contains("OU=AdminNetDesktops,OU=ADMIN_NET-240,OU=Workstations,DC=nextestate,DC=com") -and $Groupmemberstatus.Contains("ACS-VLAN-ADMIN") -and $Groupmemberstatus.Contains("Shanghai_Patching P0"))
{
Write-Host "operation done with success" -ForegroundColor Green
}
else
{
Write-Host "Error occured, Please check group membership and OU" -ForegroundColor Red
}
}
else
{
Write-Host "Computer name $cn is not a validate name" -ForegroundColor Red
}
}


#Unlock AD account
function unlock-account
{
Write-Host "Input AD account" -ForegroundColor Yellow
$account = Read-Host
$locked=(get-aduser $account -Server $DC -Properties lockedout).Lockedout
if($locked -eq $false)
{
Write-Host "Account $account is not lockedout" -ForegroundColor Red
}
elseif($locked -eq $true)
{
Unlock-ADAccount $account -Credential $cred -Server $DC
Write-Host "Account $account has been unlocked" -ForegroundColor Green
}
}

#Reset AD account password
function reset-password
{
Write-Host "Input AD account" -ForegroundColor Yellow
$account = Read-Host
Set-ADAccountPassword -Identity $account -Server $DC -Reset -Credential $cred
Write-Host "Password of $account has been reset" -ForegroundColor Green
}

#New Hire 
function newhire
{
#Create Random Password
function Get-RandomCharacters($length, $characters) 
{
    $random = 1..$length | ForEach-Object { Get-Random -Maximum $characters.length }
    $private:ofs=""
    return [String]$characters[$random]
}
 
function Scramble-String([string]$inputString)
{     
    $characterArray = $inputString.ToCharArray()   
    $scrambledStringArray = $characterArray | Get-Random -Count $characterArray.Length     
    $outputString = -join $scrambledStringArray
    return $outputString 
}
 
$password = Get-RandomCharacters -length 3 -characters 'abcdefghiklmnoprstuvwxyz'
$password += Get-RandomCharacters -length 3 -characters 'ABCDEFGHKLMNOPRSTUVWXYZ'
$password += Get-RandomCharacters -length 4 -characters '1234567890'
$password += Get-RandomCharacters -length 2 -characters '!"$%&/()=?}{@#*+'

Write-Host $password

#Setup user account
Write-Host "Input your admin account" -ForegroundColor Yellow
$cred1 = Get-Credential nextestate.com\juz9
$pwd=ConvertTo-SecureString -AsPlainText $password -force
Write-Host "Input new user's AD account" -ForegroundColor Yellow
$account = Read-Host


#Upload Photo for new hire 
#Write-Host "Input O365 admin account" -ForegroundColor Yellow
#$cred2 = Get-Credential jun.zhang@greendotcorp.com
#Import-Module ExchangeOnlineManagement
#Connect-ExchangeOnline https://outlook.office365.com/powershell -Credential $cred2
#Set-UserPhoto -Identity "$account" -PictureData ([System.IO.File]::ReadAllBytes("\\10.80.123.51\All Staff Picture2016\$account.JPG")) -Preview -confirm: $false; Set-UserPhoto "$account" -Save -Confirm: $false
#Get-PSSession | Remove-PSSession

#set adaccount password
Set-ADAccountPassword -Identity $account -Credential $cred1 -reset -NewPassword $pwd -Server $DC
Set-ADUser -Identity $account -ChangePasswordAtLogon $true -Server $DC -Credential $cred1 

#Create word file and print
$word = New-object -comobject word.application 
$word.Visible=$true
$document=$word.documents.add()
$selection=$word.selection
$selection.font.Size=18
$selection.Font.Bold=1
$selection.Font.Italic=1
$selection.TypeParagraph() 
$selection.TypeText("Welcome to Green Dot!")
$selection.TypeParagraph()  
$selection.font.Bold=0
$selection.TypeParagraph()  
$selection.TypeText("This is a basic introduction of your computer use.")
$selection.TypeParagraph()  
$selection.TypeParagraph()
$selection.Font.Bold=1
$selection.TypeText("Username:")
$selection.Font.Bold=0
$selection.Font.Italic=0
$selection.font.Underline=1
$selection.TypeText("First Name.Last Name")
$selection.font.Underline=0
$selection.TypeParagraph()
$selection.TypeText("($account)")
$selection.Font.Bold=1
$selection.Font.Italic=1
$selection.TypeParagraph()
$selection.TypeText("Password for first logon:")
$selection.Font.Bold=0
$selection.Font.Italic=0
$selection.TypeParagraph()
$selection.font.Underline=1
$selection.TypeText($password)
$selection.font.Underline=0
$selection.TypeParagraph()  
$selection.TypeParagraph()
$selection.TypeText("Password change is ")
$selection.Font.Bold=1
$selection.Font.Italic=1
$selection.TypeText("Required ")
$selection.Font.Bold=0
$selection.Font.Italic=0
$selection.TypeText("during your first logon.")
$selection.TypeParagraph()  
$selection.TypeText("Due to our security policy, you must change your ")
$selection.TypeParagraph()
$selection.TypeText("password")
$selection.Font.Bold=1
$selection.Font.Italic=1
$selection.font.Underline=1
$selection.TypeText(" every 90 days.")
$selection.font.Underline=0
$selection.TypeParagraph()
$selection.TypeParagraph()
$selection.TypeText("Please follow the process on second page to finish DUO enrollment. You MUST take your laptop home after work if you are laptop user.")
$selection.TypeParagraph()
$selection.TypeParagraph()
$selection.Font.Bold=0
$selection.Font.Italic=0
$selection.TypeText("From Service Desk Team ")
$Report = "C:\Temp\newhiredoc\newhire$(get-date -f yyyy-MM-dd)$account.doc"
$Document.SaveAs([ref]$Report,[ref]$SaveFormat::wdFormatDocument)
$word.Quit()
start-process -filepath $Report -verb print
Start-Process "\\gscpfs01\Software\Enrolling in Duo_2022.docx" -Verb print
}

#Delete computer in AD, AAD and Intune
function delete-computer
{
[CmdletBinding(DefaultParameterSetName='All')]
Param
(
    [Parameter(ParameterSetName='All',Mandatory=$true,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
    [Parameter(ParameterSetName='Individual',Mandatory=$true,ValueFromPipelineByPropertyName=$true,ValueFromPipeline=$true)]
    $ComputerName,
    [Parameter(ParameterSetName='All')]
    [switch]$All = $True,
    [Parameter(ParameterSetName='Individual')]
    [switch]$AD,
    [Parameter(ParameterSetName='Individual')]
    [switch]$AAD,
    [Parameter(ParameterSetName='Individual')]
    [switch]$Intune,
    [Parameter(ParameterSetName='Individual')]
    [switch]$Autopilot,
    [Parameter(ParameterSetName='Individual')]
    [switch]$ConfigMgr
)

Set-Location $env:SystemDrive

# Load required modules
If ($PSBoundParameters.ContainsKey("AAD") -or $PSBoundParameters.ContainsKey("Intune") -or $PSBoundParameters.ContainsKey("Autopilot") -or $PSBoundParameters.ContainsKey("ConfigMgr") -or $PSBoundParameters.ContainsKey("All"))
{
    Try
    {
        Write-host "Importing modules..." -NoNewline
        If ($PSBoundParameters.ContainsKey("AAD") -or $PSBoundParameters.ContainsKey("Intune") -or $PSBoundParameters.ContainsKey("Autopilot") -or $PSBoundParameters.ContainsKey("All"))
        {
            Import-Module Microsoft.Graph.Intune -ErrorAction Stop
            Update-MSGraphEnvironment -AppId 9a6e3dee-a1e4-4d6a-9e51-74b178f29d12
        }
        If ($PSBoundParameters.ContainsKey("AAD") -or $PSBoundParameters.ContainsKey("All"))
        {
            Import-Module AzureAD -ErrorAction Stop
        }
        If ($PSBoundParameters.ContainsKey("ConfigMgr") -or $PSBoundParameters.ContainsKey("All"))
        {
            Import-Module $env:SMS_ADMIN_UI_PATH.Replace('i386','ConfigurationManager.psd1') -ErrorAction Stop
        }
        Write-host "Success" -ForegroundColor Green 
    }
    Catch
    {
        Write-host "$($_.Exception.Message)" -ForegroundColor Red
        Return
    }
}

# Authenticate with Azure
If ($PSBoundParameters.ContainsKey("AAD") -or $PSBoundParameters.ContainsKey("Intune") -or $PSBoundParameters.ContainsKey("Autopilot") -or $PSBoundParameters.ContainsKey("All"))
{
    Try
    {
        Write-Host "Authenticating with MS Graph and Azure AD..." -NoNewline
        $intuneId = Connect-MSGraph -ErrorAction Stop
        $aadId = Connect-AzureAD -AccountId $intuneId.UPN -ErrorAction Stop
        Write-host "Success" -ForegroundColor Green
    }
    Catch
    {
        Write-host "Error!" -ForegroundColor Red
        Write-host "$($_.Exception.Message)" -ForegroundColor Red
        Return
    }
}

Write-host "$($ComputerName.ToUpper())" -ForegroundColor Yellow
Write-Host "===============" -ForegroundColor Yellow

# Delete from AD
If ($PSBoundParameters.ContainsKey("AD") -or $PSBoundParameters.ContainsKey("All"))
{
    Try
    {
        Write-host "Retrieving " -NoNewline
        Write-host "Active Directory " -ForegroundColor Yellow -NoNewline
        Write-host "computer account..." -NoNewline   
        $Searcher = [ADSISearcher]::new()
        $Searcher.Filter = "(sAMAccountName=$ComputerName`$)"
        [void]$Searcher.PropertiesToLoad.Add("distinguishedName")
        $ComputerAccount = $Searcher.FindOne()
        If ($ComputerAccount)
        {
            Write-host "Success" -ForegroundColor Green
            Write-Host "   Deleting computer account..." -NoNewline
            $DirectoryEntry = $ComputerAccount.GetDirectoryEntry()
            $Result = $DirectoryEntry.DeleteTree()
            Write-Host "Success" -ForegroundColor Green
        }
        Else
        {
            Write-host "Not found!" -ForegroundColor Red
        }
    }
    Catch
    {
        Write-host "Error!" -ForegroundColor Red
        $_
    }
}

# Delete from Azure AD
If ($PSBoundParameters.ContainsKey("AAD") -or $PSBoundParameters.ContainsKey("All"))
{
    Try
    {
        Write-host "Retrieving " -NoNewline
        Write-host "Azure AD " -ForegroundColor Yellow -NoNewline
        Write-host "device record/s..." -NoNewline 
        [array]$AzureADDevices = Get-AzureADDevice -Filter "DisplayName eq '$ComputerName'" -All:$true -ErrorAction Stop
        If ($AzureADDevices.Count -ge 1)
        {
            Write-Host "Success" -ForegroundColor Green
            Foreach ($AzureADDevice in $AzureADDevices)
            {
                Write-host "   Deleting DisplayName: $($AzureADDevice.DisplayName)  |  ObjectId: $($AzureADDevice.ObjectId)  |  DeviceId: $($AzureADDevice.DeviceId) ..." -NoNewline
                Remove-AzureADDevice -ObjectId $AzureADDevice.ObjectId -ErrorAction Stop
                Write-host "Success" -ForegroundColor Green
            }      
        }
        Else
        {
            Write-host "Not found!" -ForegroundColor Red
        }
    }
    Catch
    {
        Write-host "Error!" -ForegroundColor Red
        $_
    }
}

# Delete from Intune
If ($PSBoundParameters.ContainsKey("Intune") -or $PSBoundParameters.ContainsKey("Autopilot") -or $PSBoundParameters.ContainsKey("All"))
{
    Try
    {
        Write-host "Retrieving " -NoNewline
        Write-host "Intune " -ForegroundColor Yellow -NoNewline
        Write-host "managed device record/s..." -NoNewline
        [array]$IntuneDevices = Get-IntuneManagedDevice -Filter "deviceName eq '$ComputerName'" -ErrorAction Stop
        If ($IntuneDevices.Count -ge 1)
        {
            Write-Host "Success" -ForegroundColor Green
            If ($PSBoundParameters.ContainsKey("Intune") -or $PSBoundParameters.ContainsKey("All"))
            {
                foreach ($IntuneDevice in $IntuneDevices)
                {
                    Write-host "   Deleting DeviceName: $($IntuneDevice.deviceName)  |  Id: $($IntuneDevice.Id)  |  AzureADDeviceId: $($IntuneDevice.azureADDeviceId)  |  SerialNumber: $($IntuneDevice.serialNumber) ..." -NoNewline
                    Remove-IntuneManagedDevice -managedDeviceId $IntuneDevice.Id -Verbose -ErrorAction Stop
                    Write-host "Success" -ForegroundColor Green
                }
            }
        }
        Else
        {
            Write-host "Not found!" -ForegroundColor Red
        }
    }
    Catch
    {
        Write-host "Error!" -ForegroundColor Red
        $_
    }
}

# Delete Autopilot device
If ($PSBoundParameters.ContainsKey("Autopilot") -or $PSBoundParameters.ContainsKey("All"))
{
    If ($IntuneDevices.Count -ge 1)
    {
        Try
        {
            Write-host "Retrieving " -NoNewline
            Write-host "Autopilot " -ForegroundColor Yellow -NoNewline
            Write-host "device registration..." -NoNewline
            $AutopilotDevices = New-Object System.Collections.ArrayList
            foreach ($IntuneDevice in $IntuneDevices)
            {
                $URI = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities?`$filter=contains(serialNumber,'$($IntuneDevice.serialNumber)')"
                $AutopilotDevice = Invoke-MSGraphRequest -Url $uri -HttpMethod GET -ErrorAction Stop
                [void]$AutopilotDevices.Add($AutopilotDevice)
            }
            Write-Host "Success" -ForegroundColor Green

            foreach ($device in $AutopilotDevices)
            {
                Write-host "   Deleting SerialNumber: $($Device.value.serialNumber)  |  Model: $($Device.value.model)  |  Id: $($Device.value.id)  |  GroupTag: $($Device.value.groupTag)  |  ManagedDeviceId: $($device.value.managedDeviceId) ..." -NoNewline
                $URI = "https://graph.microsoft.com/beta/deviceManagement/windowsAutopilotDeviceIdentities/$($device.value.Id)"
                $AutopilotDevice = Invoke-MSGraphRequest -Url $uri -HttpMethod DELETE -ErrorAction Stop
                Write-Host "Success" -ForegroundColor Green
            }
        }
        Catch
        {
            Write-host "Error!" -ForegroundColor Red
            $_
        }
    }
}

# Delete from ConfigMgr
If ($PSBoundParameters.ContainsKey("ConfigMgr") -or $PSBoundParameters.ContainsKey("All"))
{
    Try
    {
        Write-host "Retrieving " -NoNewline
        Write-host "ConfigMgr " -ForegroundColor Yellow -NoNewline
        Write-host "device record/s..." -NoNewline
        $SiteCode = (Get-PSDrive -PSProvider CMSITE -ErrorAction Stop).Name
        Set-Location ("$SiteCode" + ":") -ErrorAction Stop
        [array]$ConfigMgrDevices = Get-CMDevice -Name $ComputerName -Fast -ErrorAction Stop
        Write-Host "Success" -ForegroundColor Green
        foreach ($ConfigMgrDevice in $ConfigMgrDevices)
        {
            Write-host "   Deleting Name: $($ConfigMgrDevice.Name)  |  ResourceID: $($ConfigMgrDevice.ResourceID)  |  SMSID: $($ConfigMgrDevice.SMSID)  |  UserDomainName: $($ConfigMgrDevice.UserDomainName) ..." -NoNewline
            Remove-CMDevice -InputObject $ConfigMgrDevice -Force -ErrorAction Stop
            Write-Host "Success" -ForegroundColor Green
        }
    }
    Catch
    {
        Write-host "Error!" -ForegroundColor Red
        $_
    }
}

Set-Location $env:SystemDrive
}