Write-Host Copy Intune Enroll ID from Task scheduler\windows\EnterpriseMgmt
$IntuneEnrollID=Read-Host
Get-Item HKLM:\SOFTWARE\Microsoft\Enrollments\$IntuneEnrollID|Remove-Item -Force -Verbose
Get-Item HKLM:\SOFTWARE\Microsoft\Enrollments\Status\$IntuneEnrollID|Remove-Item -Force -Verbose
Get-Item HKLM:\SOFTWARE\Microsoft\EnterpriseResourceManager\Tracked\$IntuneEnrollID|Remove-Item -Force -Verbose
Get-Item HKLM:\SOFTWARE\Microsoft\PolicyManager\AdmxInstalled\$IntuneEnrollID|Remove-Item -Force -Verbose
Get-Item HKLM:\SOFTWARE\Microsoft\PolicyManager\Providers\$IntuneEnrollID|Remove-Item -Force -Verbose
Get-Item HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Accounts\$IntuneEnrollID|Remove-Item -Force -Verbose
Get-Item HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Logger\$IntuneEnrollID|Remove-Item -Force -Verbose
Get-Item HKLM:\SOFTWARE\Microsoft\Provisioning\OMADM\Sessions\$IntuneEnrollID|Remove-Item -Force -Verbose