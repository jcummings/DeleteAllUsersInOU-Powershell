Import-Module Duo
$users=duoGetUser
Import-Module ActiveDirectory

$users | Select-Object | Export-Csv -Path duoimport.csv

Get-ADGroupMember -Identity "InfoSec-Duo-Sync" | 
Select sAMAccountName | 
Export-CSV -Path infosecduosync.csv -NoTypeInformation

Import-CSV -Path duoimport.csv | 
Select @{Name="sAMAccountName";Expression={$_."username"}} |
Export-CSV -Path duousersclean.csv -NoTypeInformation

Compare-Object -ReferenceObject $(Get-Content infosecduosync.csv) -DifferenceObject $(Get-Content duousersclean.csv) `
|  Where-Object{$_.SideIndicator -eq '=>'} | `
Select-Object InputObject | export-csv differences.csv -NoTypeInfo 
(gc differences.csv) | % {$_ -replace '"', ""} | out-file differences.csv -Fo -En ascii

Import-CSV -Path differences.csv | 
ForEach-Object{
    if($_.InputObject -ne "pmp-its-idm"){
    Add-ADGroupMember InfoSec-Duo-Sync $_.InputObject
    }
}
Remove-Item infosecduosync.csv
Remove-Item differences.csv
Remove-Item duousersclean.csv
Remove-Item duoimport.csv