#check admin	
param([switch]$Elevated)
function Check-Admin 
{
$currentUser = New-Object Security.Principal.WindowsPrincipal $([Security.Principal.WindowsIdentity]::GetCurrent())
$currentUser.IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)
}
if ((Check-Admin) -eq $false)  
{
if ($elevated)
{
# could not elevate, quit
}
 
else 
{ 
Start-Process powershell.exe -Verb RunAs -ArgumentList ('-noprofile -noexit -file "{0}" -elevated' -f ($myinvocation.MyCommand.Definition))
}
exit
}
#windows activation
slmgr.vbs /ipk NPPR9-FWDCX-D2C8J-H872K-2YT43 /ato /S

$Filesource="\\gdcfs01.nextestate.com\GeneralSoftware\Jumpbox_image"

#software 1 DUO
copy-item "$Filesource\DUO\*" -Destination "C:\Workstation_Applications"
$install2=([WMICLASS]"\root\cimv2:win32_Process").Create("C:\Workstation_applications\Duo Silent Install-Admin.cmd")
Start-Sleep -Seconds 30
If ($install2.ReturnValue -eq 0) 
{ 
"DUO Install completed! ProcessID:" +$install2.ProcessId+  (Get-Date) | out-file 'C:\Workstation_Applications\log.txt' -Append
}
else
{ 
'DUO Process create failed with' +$install2.ReturnValue+  (Get-Date) | Out-File 'C:\Workstation_Applications\log.txt' -Append
}


#software 2 SCCM

New-Item -Path "C:\windows\" -Name "ccmsetup" -ItemType "Directory"
copy-item  "$Filesource\ccmsetup\*" -Destination "C:\windows\ccmsetup"
$install5=([WMICLASS]"\root\cimv2:win32_Process").Create("C:\windows\CCMSETUP\CCMSETUP.EXE /S SMSSITECODE=PRI SMSMP=http://dc1sccmpri02.dc1.greendotcorp.com DNSSUFFIX=dc1.greendotcorp.com /mp:dc1sccmpri02.dc1.greendotcorp.com")
If ($install5.ReturnValue -eq 0) 
{ 
 "CCM CLIENT completed! ProcessID:" +$install5.ProcessId+  (Get-Date) | out-file 'C:\Workstation_Applications\log.txt' -Append
}
else 
{ 
'CCMCLIENT Process create failed with' +$install5.ReturnValue+  (Get-Date) | Out-File 'C:\Workstation_Applications\log.txt' -Append
}

#Install dtex
Copy-Item \\gdcfs01.nextestate.com\GeneralSoftware\Jumpbox_image\DTEX\* -Destination C:\Workstation_applications
Start-Process C:\Workstation_applications\DTEXForwarder_6.2.3.12_x64.msi -ArgumentList "/qn ADDRESS=receiver.greendot.dtexservices.com:443"
Start-Sleep -Seconds 45
Start-Process C:\Workstation_applications\DTEXForwarder_KeystrokeCapture_1.2.4.msi -ArgumentList "/qn"
Start-Sleep -Seconds 30
Start-Process C:\Workstation_applications\DTEXForwarderModule_Windows_ScreenRecording_2.2.3_x64.msi -ArgumentList "/qn"

#Computer setup
Disable-TlsCipherSuite -Name 'TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA'
Disable-TlsCipherSuite -Name 'TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA'
Disable-TlsCipherSuite -Name 'TLS_RSA_WITH_AES_128_CBC_SHA'
Disable-TlsCipherSuite -Name 'TLS_RSA_WITH_AES_256_CBC_SHA'
Disable-TlsCipherSuite -Name 'TLS_ECDHE_RSA_WITH_AES_128_CBC_SHA256'
Disable-TlsCipherSuite -Name 'TLS_ECDHE_RSA_WITH_AES_256_CBC_SHA384'
Disable-TlsCipherSuite -Name 'TLS_RSA_WITH_AES_128_CBC_SHA256'
Disable-TlsCipherSuite -Name 'TLS_RSA_WITH_AES_256_CBC_SHA256'

Add-ADGroupMember -Identity "ClientPatch_PROD_Win10_JB_Auto_0800" -Members(Get-ADComputer -Identity $env:COMPUTERNAME).SamAccountName
Set-Service -Name WinRM -StartupType Automatic

#echo log file for ccm
Get-Content C:\Windows\ccmsetup\Logs\ccmsetup.log -Wait