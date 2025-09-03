If (-Not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator"))
{
    $newProcess = Start-Process powershell -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}
Write-Host "Type your dc1 admin account credential and New computername"
$newcn = Read-Host
Rename-Computer -NewName $newcn -Force
Add-Computer -DomainName "dc1.greendotcorp.com" -Credential $cred -OUPath "OU=Admin Jumpboxes,DC=dc1,DC=greendotcorp,DC=com" -Options JoinWithNewName,AccountCreate
Write-Host "Machine will restart in 30s."
Start-Sleep -Seconds 30
Restart-Computer
