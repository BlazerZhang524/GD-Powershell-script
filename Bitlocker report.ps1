$cred = Get-Credential juz9 #get admin account 
$computer=get-adcomputer -filter * -searchbase 'OU=CORP_NET-205,OU=Workstations,DC=nextestate,DC=com' | select distinguishedname,name #define search base and select output data
$report=@() #set $report as array
foreach ($cn in $computer)
{
$a=Get-ADObject -Filter {objectclass -eq 'msFVE-RecoveryInformation'} -SearchBase $cn.distinguishedname -Properties 'cn','msFVE-RecoveryPassword' -server gdcad01 -Credential $cred | select @{n="Computername";e={$cn.Name}},CN,msFVE-RecoveryPassword #search Key information in AD
$machine = New-Object -TypeName psobject #create a new object
$machine | Add-Member -MemberType NoteProperty -Name 'Computer Name' -Value $cn.Name
$machine | Add-Member -MemberType NoteProperty -Name 'Key ID' -Value $a.cn
$machine | Add-Member -MemberType NoteProperty -Name 'Key' -Value $a.'msFVE-RecoveryPassword'
$report += $machine #add element to array
}
$report | export-csv c:\vm\bitlockerreport.csv -NoTypeInformation #export report
