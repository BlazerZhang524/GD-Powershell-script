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
slmgr.vbs /ipk NPPR9-FWDCX-D2C8J-H872K-2YT43 /skms g2cplic01.nextestate.com /ato /S

#create folder
New-Item -Path "C:\" -Name "Workstation_Applications" -ItemType "Directory"

#software1
copy-item "\\gdsfs01\generalsoftware\7z1900-x64.exe" -Destination "C:\Workstation_Applications"
$install1=([WMICLASS]"\root\cimv2:win32_Process").Create("C:\Workstation_Applications\7z1900-x64.exe /S")

#software2
copy-item  "\\gdsfs01\Software\CiscoVPN\anyconnect.msi" -Destination "C:\Workstation_Applications"
$install2=([WMICLASS]"\root\cimv2:win32_Process").Create("msiexec /I C:\Workstation_Applications\anyconnect.msi /qn")
If ($install2.ReturnValue -eq 0) 
{ 
"CiscoVPN Install completed! ProcessID:" +$install2.ProcessId+  (Get-Date) | out-file 'C:\Workstation_Applications\log.txt' -Append
}
else
{ 
'CiscoVPN Process create failed with' +$install2.ReturnValue+  (Get-Date) | Out-File 'C:\Workstation_Applications\log.txt' -Append
}

#software3
copy-item  "\\gdsfs01\Software\CrowdStrike\windowssensor.exe" -Destination "C:\Workstation_Applications"
$install3=([WMICLASS]"\root\cimv2:win32_Process").Create("C:\Workstation_Applications\windowssensor.exe /install /quiet /norestart CID=95847DF668444BABAE8A108E51D3B7B8-69")
If ($install3.ReturnValue -eq 0) 
{ 
"windowssensor.exe Install completed! ProcessID:" +$install3.ProcessId+  (Get-Date) | out-file 'C:\Workstation_Applications\log.txt' -Append
}
else
 { 
 'windowssensor.exe Process create failed with' +$install3.ReturnValue+  (Get-Date) | Out-File 'C:\Workstation_Applications\log.txt' -Append
 }

#software4
copy-item  "\\gdsfs01\Software\Forcepoint\FORCEPOINT-ONE-ENDPOINT-x64-v20.12-Direct.exe" -Destination "C:\Workstation_Applications"
$install4=([WMICLASS]"\root\cimv2:win32_Process").Create('C:\Workstation_Applications\FORCEPOINT-ONE-ENDPOINT-x64-v20.12-Direct.exe /v"/qn /norestart"')
If ($install4.ReturnValue -eq 0)
 { 
  "ForcePoint Install completed! ProcessID:" +$install4.ProcessId+  (Get-Date) | out-file 'C:\Workstation_Applications\log.txt' -Append
 }
else 
 { 
 'ForcePoint create failed with' +$install4.ReturnValue+  (Get-Date) | Out-File 'C:\Workstation_Applications\log.txt' -Append
 }

#software5
copy-item "\\gdsfs01\Software\CiscoVPN\anyconnect-win-4.9.06037-gina-predeploy-k9.msi" -Destination "C:\Workstation_Applications"
$install5=([WMICLASS]"\root\cimv2:win32_Process").Create("msiexec /I C:\Workstation_Applications\anyconnect-win-4.9.06037-gina-predeploy-k9.msi /quiet /norestart")
If ($install5.ReturnValue -eq 0)
 { 
  "Anyconnect SBL Install completed! ProcessID:" +$install5.ProcessId+  (Get-Date) | out-file 'C:\Workstation_Applications\log.txt' -Append
 }
else 
 { 
 'Anyconnect SBL installation failed with' +$install4.ReturnValue+  (Get-Date) | Out-File 'C:\Workstation_Applications\log.txt' -Append
 }

#software6
New-Item -Path "C:\windows\" -Name "ccmsetup" -ItemType "Directory"
copy-item  "\\gdsfs01\Software\ccmsetup\*" -Destination "C:\windows\ccmsetup"
$install6=([WMICLASS]"\root\cimv2:win32_Process").Create("C:\windows\CCMSETUP\CCMSETUP.EXE /S /mp:GDCSCCMpri02 SMSSITECODE=pri")
If ($install6.ReturnValue -eq 0) 
{ 
 "CCM CLIENT completed! ProcessID:" +$install6.ProcessId+  (Get-Date) | out-file 'C:\Workstation_Applications\log.txt' -Append
}
else 
{ 
'CCMCLIENT Process create failed with' +$install6.ReturnValue+  (Get-Date) | Out-File 'C:\Workstation_Applications\log.txt' -Append
}

  #bitlocker
  Enable-Bitlocker -MountPoint c: -UsedSpaceOnly -SkipHardwareTest -RecoveryPasswordProtector
 
  #remove scripts 
  Remove-Item (Get-Item $myinvocation.MyCommand.Path).DirectoryName -Force -Recurse
  Set-ExecutionPolicy Restricted -Force LocalMachine

  #echo log file for ccm
  Get-Content C:\Windows\ccmsetup\Logs\ccmsetup.log -Wait