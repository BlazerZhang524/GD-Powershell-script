#check admin
If (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    $newProcess = Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Write-Host "Please type jumpbox data center,dc1 or dc2."
$dc=Read-Host
if($dc -eq "dc1")

{
#ipv4 network configuration
Write-Host "Please type IP address for this machine. IP range should be 10.111.96.0/24"
$newIPaddress = Read-Host
$newSubnetMask = "255.255.255.0"
$newGateway = "10.111.96.1"
$DNS1 = "10.111.51.31"
$DNS2 = "10.121.51.30"
}
elseif($dc -eq "dc2")
{
Write-Host "Please type IP address for this machine. IP range should be 10.121.96.0/24"
$newIPaddress = Read-Host
$newSubnetMask = "255.255.255.0"
$newGateway = "10.121.96.1"
$DNS1 = "10.111.51.31"
$DNS2 = "10.121.51.30"
}
#Get current network adapter
$networkadapter = Get-NetAdapter | Where-Object {$_.status -eq "Up"}

#SetIPaddress,subnetmask and dns
New-NetIPAddress -InterfaceIndex $networkadapter.InterfaceIndex -IPAddress $newIPaddress -PrefixLength 24 -DefaultGateway $newGateway
Set-DnsClientServerAddress -InterfaceIndex $networkadapter.InterfaceIndex -ServerAddresses ($DNS1,$DNS2)

Start-Sleep -Seconds 20

Test-NetConnection 10.111.51.31
Test-NetConnection 10.121.51.30

Start-Sleep -Seconds 10


