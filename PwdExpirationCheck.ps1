#Variables
$NotifyThreshold = 15
$CheckGroup = "dept-it-shanghai-all"
#$CheckGroup = "GDS-TechOps"
$SendFrom = "noreply@greendotcorp.com"
$ReportTo = @("jun.zhang@greendotcorp.com","josie.huang@greendotcorp.com")
$MailServer = "mailhost.nextestate.com"
$scriptname = (($MyInvocation.MyCommand.Name).Split("."))[0]
$scriptPath = Split-Path -parent $MyInvocation.MyCommand.Definition
$datetime = Get-Date
$htmlbody = '<html>
Dear User,
<br>
<br>
Your password will be <strong>expired</strong> recently. Please change your password as soon as possible.
<br>
<br>
<u><I>For Windows user</u></I><br>Please make sure you connect with <strong>corp network</strong> and press <strong><font color="#ff0000"> Ctrl + Alt + Delete</font></strong> to change your password.
<br>
<br>
<u><I>For Mac user</u></I><br>Please make sure your Mac is under <strong>corp network</strong> and click <strong><font color="#ff0000">"JAMF Connect" icon on the top menu bar</font></strong> to change your password.
<br>
<br>
<u><I>For Remote user</u></I><br><strong><font color="#ff0000">Please follow the method below:</font></strong><br>
1. Log into your computer as usual and make sure you are connected to the internet.<br>
2. Use this link to change your password <a href="https://account.activedirectory.windowsazure.com/ChangePassword.aspx">https://account.activedirectory.windowsazure.com/ChangePassword.aspx</a>.<br>
3. Connect and log in to VPN using your new password.<br>
4. Once connected to VPN, lock your computer and unlock with your new password.<br>
<br>
The new password must meet the minimum requirements set forth in our corporate policies including:
<br>
1. It must be at least 12 characters long.
<br>
2. It must contain at least one character from at least 3 of the 4 following groups of characters:
<br>
&nbsp;&nbsp;&nbsp;&nbsp;a. Uppercase letters (A-Z)
<br>
&nbsp;&nbsp;&nbsp;&nbsp;b. Lowercase letters (a-z)
<br>
&nbsp;&nbsp;&nbsp;&nbsp;c. Numbers (0-9)
<br>
&nbsp;&nbsp;&nbsp;&nbsp;d. Symbols (!@#$%^&*...)
<br>
3. It cannot match any of your past 12 passwords.
<br>
4. It cannot contain 3 or more consecutive characters which match your account name or display name.
<br>
5. You cannot change your password more often than once in a 24 hour period.
<br>
<br>
If you need support for password changing, Please contact <a href="mailto:ithelp@greendotcorp.com"><strong>Shanghai Service Desk.</strong></a>
<br>
<br>
Thanks for your cooperation
<br>
<br>
<strong>Shanghai Service Desk team</strong>
<br>
<font size=2>Mail: <a href="mailto:ithelp@greendotcorp.com">ithelp@greendotcorp.com</a></font>
<br>
<font size=2>Tel: +86 (21) 60963310 option 1</font>
</html>'
#Cleanup csv files older than 30 days
Get-ChildItem "$scriptPath\$scriptname*.csv" | Where-Object {($datetime - $_.lastwritetime).Totaldays -gt 30 } | Remove-Item -Force
$strdatetime = $datetime.ToString("yyyyMMdd-hhmmss")
#csv files for email reports are created under the same folder as the script, with date time appeneded to the file name
$CsvFilePath = Join-Path -Path $scriptPath -ChildPath "$scriptname-$strdatetime.csv"

Import-Module ActiveDirectory
#Get all users in the given group recursively
$users = (Get-ADGroupMember $CheckGroup -Recursive | Where-Object {$_.objectclass -eq "user"}).distinguishedName
$objColl = @()
#Get list of users to be notified
foreach ($user in $users) 
{
    $aduser = get-aduser $user -Properties mail,PasswordLastSet
    $pwdlastset = $aduser.PasswordLastSet
    $pwdexpiredate = Get-ADUser $user -Properties msDS-UserPasswordExpiryTimeComputed | select @{l="date"; e={[datetime]::FromFileTime($_."msDS-UserPasswordExpiryTimeComputed")}}
    $pwdexpday = ($pwdexpiredate.date - $datetime).Days
    if ($pwdexpday -lt $NotifyThreshold) 
    {
        $notifiedObj = New-Object -TypeName PSObject
        $notifiedObj | Add-Member -MemberType NoteProperty -Name User -Value $aduser.Name
        $notifiedObj | Add-Member -MemberType NoteProperty -Name DaysToExpire -Value $pwdexpday
        $notifiedObj | Add-Member -MemberType NoteProperty -Name Email -Value $aduser.mail
        $objColl += $notifiedObj
    }
}

if ($objColl) {
    #Split to 10 users a batch and wait for 5 seconds after each batch to reduce email server load
    $objGroups = @()
    for ($i = 0; $i -lt $objColl.count; $i += 10) {
        $objGroups += ,@($objColl[$i..($i+9)]);
    }
    foreach ($ObjGroup in $ObjGroups) {
        #Send Email notifications to users
        $ObjGroup | ForEach-Object {Send-MailMessage -to $($_.Email) -from $SendFrom -Subject "Your Password Will Be Expired in $($_.DaysToExpire) Days" -BodyAsHtml $htmlbody  -SmtpServer $MailServer -Priority High} 
        Start-Sleep -Seconds 5
    }
    $objColl | Export-Csv $CsvFilePath -NoTypeInformation
    #Send Email report
    Send-MailMessage -to $ReportTo -from $SendFrom -Subject "Password Expiration Notification Report" -Attachments $CsvFilePath -SmtpServer $MailServer
}
else {
    Send-MailMessage -to $ReportTo -from $SendFrom -Subject "Password Expiration Notification Report" -Body "No users to notify" -SmtpServer $MailServer
}