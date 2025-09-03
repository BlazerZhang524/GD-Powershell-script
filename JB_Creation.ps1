###################################################################################################################
# Author:Jun Zhang, Email:jun.zhang@greendotcorp.com                                                              #
#                                                                                                                 #    
# Before use this script, please install VMware PowerCLI on your machine. Make sure you have access to login DC1  #
# VMware platform. For the access related issue, please contact System Engineering team.                          #
#                                                                                                                 # 
# Do not change any parameter of this script without permission.                                                  #    
###################################################################################################################

Connect-VIServer dc1vmwvcsa01.dc1.greendotcorp.com -alllinked
while($true){
#check machine name occupation
$vmName=""
do{
Write-Host "Type VM name"
$vmName=Read-Host
$existingVM=Get-VM -Name $vmName -ErrorAction SilentlyContinue
if($existingVM)
{
Write-Host "A Jumpbox $vmName already exist in the platform. Please use another name!" -ForegroundColor Red
}
}
while($existingVM)
$userchoice=""
do{
Write-Host "Select a datacenter, default option is DC1."
Write-Host "1.DC1"
Write-Host "2.DC2"
$userchoice=Read-Host
if([string]::IsNullOrWhiteSpace($userchoice))
{Write-Host "Do not detect input, use default option: 1.DC1" -ForegroundColor Red
$userchoice='1'}
if($userchoice -ne "1" -and $userchoice -ne "2")
{Write-Host "Please varify your input, it only accepts 1 or 2." -ForegroundColor Red}
}
while($userchoice -ne "1" -and $userchoice -ne "2")
#set parameters for dc1 jumpbox
if($userchoice -eq "1")
{
$ESXIhostpool=@("dc1vsiprod08-16.dc1.greendotcorp.com","dc1vsiprod08-17.dc1.greendotcorp.com","dc1vsiprod08-18.dc1.greendotcorp.com","dc1vsiprod08-19.dc1.greendotcorp.com","dc1vsiprod08-20.dc1.greendotcorp.com")
$datacenter="DC1-Los_Angeles"
$folder="Jumpboxes"
$template="DC1_Jumpbox_Win11_23H2_Template"
$vmhost=Get-Random $ESXIhostpool
$datastore="dc1purearray01_dc1vsiprod03_lun10"
$storageformat="Thin"
$networkname="ADMIN_NET_196"
$server="dc1vmwvcsa01.dc1.greendotcorp.com"
}
#set parameters for dc2 jumpbox
elseif($userchoice -eq "2")
{
$ESXIhostpool=@("dc2vsiprod08-16.dc1.greendotcorp.com","dc2vsiprod08-17.dc1.greendotcorp.com","dc2vsiprod08-18.dc1.greendotcorp.com","dc2vsiprod08-19.dc1.greendotcorp.com","dc2vsiprod08-20.dc1.greendotcorp.com")
$datacenter="DC2-Las_Vegas"
$folder="Jumpboxes"
$template=Get-Template -Name "DC1_Jumpbox_Win11_23H2_Template" -Server "dc1vmwvcsa01.dc1.greendotcorp.com"
$vmhost=Get-Random $ESXIhostpool
$datastore="dc2purearray01_dc2vsiprod03_lun13"
$storageformat="Thin"
$networkname="ADMIN_NET_196"
$server="dc2vmwvcsa01.dc1.greendotcorp.com"
}
#create jumpbox with configured parameters
New-VM -Template $template -VMHost $vmhost -Datastore $datastore -StorageFormat $storageformat -Name $vmName -Location $folder -Server $server
#add network adapter for new jumpbox
New-NetworkAdapter -VM $vmName -NetworkName $networkname -StartConnected -WakeOnLan -Server $server
#add vtpm
New-VTpm -VM $vmName

#check VM
$checkVMName=Get-VM -Name $vmName -ErrorAction SilentlyContinue
$checkNetowrk=Get-NetworkAdapter -VM $vmName -ErrorAction SilentlyContinue | Select-Object NetworkName
$checkVTPM=Get-VTpm -VM $vmName -ErrorAction SilentlyContinue
$errors=@()
if(-not $checkVMName)
{$errors +="VM $vmName was not created."}
if($checkNetowrk.NetworkName -ne "ADMIN_NET_196")
{$errors +="network adapter isn't correct, please check."}
if(-not $checkVTPM)
{$errors+="VTPM is not configured, please check."}
if($errors.Count -eq 0)
{Write-Host "Jumpbox $vmName has been created successfully!" -ForegroundColor Green}
else
{Write-Host "Process failed with below issue:" -ForegroundColor Red
$errors | ForEach-Object {Write-Host $_ -ForegroundColor Red}
}
$checkVMName,$checkNetowrk,$checkVTPM=$null,$null,$null
}