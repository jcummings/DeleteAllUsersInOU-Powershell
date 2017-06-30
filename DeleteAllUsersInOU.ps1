################################################################################################################################################################ 
# DeleteAllUsersinOU.ps1
# 
# To run the script 
# 
# .\DeleteAllUsersinOU.ps1 -ou "OU=TestUsers,DC=example,DC=com"
# 
# Author:                 John Cummings john@jcummings.net john.cummings@uncc.edu
# Version:                 1.0
# Last Modified Date:     6/28/2017
# Last Modified By:     John Cummings john@jcummings.net john.cummings@uncc.edu 
################################################################################################################################################################ 
#Accept input parameter of the OU to delete users from as string 
param([string]$ou)
Import-Module ActiveDirectory 

#Checking that an OU was supplied as a command line arg
if($ou -eq $false -OR $ou -eq $null -OR $ou -eq ''){
    Write-Host "An OU is requried to run this script.  .\RemoveAllUsersinOU.ps1 -ou 'OU=TestUsers,DC=example,DC=com'"
    Break
}

#Define the BaseDN for the domain and make sure the user doesn't accidentally delete all users
$checkBaseDN = $ou.StartsWith("CN=Users")
if ($checkBaseDN -eq $True){
    Write-Host "Sorry, but CN=Users indicates that you're trying to use your primary User OU.  This script will not allow deletions from the base User OU."
    Break
}

#Loop through the specified OU and delete any users from it 
$users = Get-ADUser -SearchBase $ou -Filter *
ForEach($user in $users){  
    Try
        {    
            Remove-ADUser -Identity $user -Confirm:$false -ErrorAction Stop
            Write-Host $user "removed successfully" | fl
    
        }
    Catch
        {
            Write-Host "An error occurred when attempting to get users from the specified OU. Double check the OU and try again"
            Break
        }
    }