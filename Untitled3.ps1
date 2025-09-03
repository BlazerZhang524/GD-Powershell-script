#For Lgy/FW tier2DB patching  
#prepare all  nodes in txt/excel sheet,   except standalone SQL nodes which will be patching indenpendently.
#import  Cluster nodes and verify
#$allnodes=Get-CMCollectionMember -CollectionName "ServerPatch_Combined_SDLC_Tier2_SQL_Monthly" | Select-Object -ExpandProperty name
$allnodes=get-clipboard     
$allnodes
$allnodes.count
#optional, verify nodes amount in DC1 and DC2
#$dc2nodes=$allnodes -match  "\bDC?2.*\b"
#$dc2nodes
#$dc2nodes.count
#$dc1nodes=$allnodes -match "\bDC?1.*\b"
#$dc1nodes
#$dc1nodes.count
#get cluster names and verify amount
$allclusters = $allnodes | % {icm ($_ + ".dc1.greendotcorp.com") -ScriptBlock {get-cluster}} | select -ExpandProperty name -Unique
$allclusters
$allclusters.count
#review cluster group
$allclusters | % {icm ($_ + ".dc1.greendotcorp.com") -ScriptBlock {get-clustergroup}} |ft cluster,name,ownernode -autosize
$allclustergroups = $allclusters | % {icm ($_ + ".dc1.greendotcorp.com") -ScriptBlock {get-clustergroup}} 
$allclustergroups |ft cluster,name,ownernode -autosize
#get active node without RO/CNO owner for each FCI
$allclusters | % {get-clustergroup -cluster $_ | ? {($_.iscoregroup -ne $True) -and ($_.name -notmatch "RO$")}} | select -ExpandProperty ownernode | select -ExpandProperty name -unique
$activenodes  = $allclusters | % {get-clustergroup -cluster $_ | ? {($_.iscoregroup -ne $True) -and ($_.name -notmatch "RO$")}} | select -ExpandProperty ownernode | select -ExpandProperty name -unique
$activenodes
$activenodes.count
#get passive nodes
$passivenodes = $allnodes| ? {$_ -notin $activenodes}
$passivenodes
$passivenodes.count
#fitler dc2fci nodes only
$dc2fci="DC2ADHOCSQL03","DC2ADHOCSQL04","D2PDDIST201","D2PDDIST202","DC2FWDIST201","DC2FWDIST202"
$dc2fciActive=$activenodes | ? {$_ -in $dc2fci}
$dc2fcipassive=$dc2fci | ? {$_ -notin $dc2fciActive}
$dc2fciActive.Count
#divide node into 5 batches for patching, first DC2, then DC1
$batch0=$passivenodes -match  "\bDC?2.*02\b"
$batch1=$passivenodes -match  "\bDC?2.*\b" | where { $_ -notin $batch0 }
$batch2=$activenodes -match  "\bDC?2.*\b"  | ? {$_ -notin $dc2fciActive}     # ADHOCSQL02   #activenodes -in|notin $%batch2
$batch3=$passivenodes -notmatch "\bDC?2.*\b"
$batch4=($activenodes  -notmatch  "\bDC?2.*\b") + $dc2fciActive      #verfiy node amount is correct
#verfiy node amount is correct
$batch0.count
$batch1.count
$batch2.count
$batch3.count
$batch4.count
$batch0.count+$batch1.count+$batch2.count+$batch3.count+$batch4.count
#repeat patch nodes and reboot nodes by batch 0 - 4
#install patch
#please  ensure these nodes DO NOT host any cluster groups before actions, the output should be empty, if there any output need stop and review
$batch | % {icm {$_ + ".dc1.greendotcorp.com"} -ScriptBlock {get-clustergroup | ? {$_.ownernode -eq $env:computername -and $_.iscoregroup -eq $false }}} | ft pscomputername,cluster,name,ownernode
$batch=$batch0 #($batch0,1,2,3,4)
$batch | % {$_ + ".dc1.greendotcorp.com"} | .\SCCM_Patching.ps1 -Action Evaluate
$batch | % {$_ + ".dc1.greendotcorp.com"} | .\SCCM_Patching.ps1 -Type Update
$batch | % {$_ + ".dc1.greendotcorp.com"} | .\SCCM_Patching.ps1 -Type Update -Action Install 
#pause drain and reboot nodes
$batch | % {icm $_ -scriptblock {suspend-clusternode $env:computername -drain}}
#verify role is online , verify target node in pause status
$batch |% {get-clustergroup -cluster $_ | ? {($_.iscoregroup -ne $True) -and ($_.name -notmatch "RO$")}} |ft -autosize
$batch |% {get-clusternode -cluster $_}
#reboot by batchpatch/Powershell
restart-computer $batch1 -wait -force
#resume nodes after reboot
$batch | % {icm $_ -scriptblock {resume-clusternode $env:computername}}
#verify cluster node resume, cluster group online
$batch |% {get-clustergroup -cluster $_ | ? {($_.iscoregroup -ne $True) -and ($_.name -notmatch "RO$")}} |ft -autosize
$batch |% {get-clusternode -cluster $_}
#repeat for batch 0 - batch 4
#for batch 4 ensure DBA failover and confirmed
#verify all nodes and role up after patching