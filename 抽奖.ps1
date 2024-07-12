$user = Import-Csv C:\temp\user.csv
$lukcyone=Get-Random $user
Write-Host $lukcyone -ForegroundColor Green
$user = [System.Collections.ArrayList]$user
$user.Remove($lukcyone) 
$user | Export-Csv C:\temp\user.csv -NoTypeInformation