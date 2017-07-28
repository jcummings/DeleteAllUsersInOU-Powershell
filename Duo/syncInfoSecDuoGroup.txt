<############################################################################################################################################################### 
# syncInfoSecDuoGroup.ps1
# 
# To run the script: 
# On demand you can run the script by calling it directly from an uplifted PS window
# .\syncInfoSecDuoGroup.ps1
#
# The script is designed to be run daily as a scheduled task
#
# Purpose:  The script makes use of the Duo Powershell API https://github.com/mbegan/Duo-PSModule
#
# Using this API as an imported module, the script pulls in a current user list from 
# the UNCC Duo tenant.  It also gets the current list of members in the InfoSec-Duo-Sync
# AD group. Both user lists are exported to CSV and compared.  If any user is found
# in the Duo user list that is NOT in the AD group, the script writes those user
# differences to a third 'differences.csv' file and uses that file to import
# the missing members to the AD group.
#
# The script does extensive logging each step of the process, and performs disk 
# cleanup after each run. 
# 
# Author:                 John Cummings john@jcummings.net john.cummings@uncc.edu
#
# Version:                 1.1
# Last Modified Date:     7/24/2017
# Last Modified By:     John Cummings john@jcummings.net john.cummings@uncc.edu 
#
# Version history
# _______________
#
# 1.0 - 7.24.17 - John Cummings - john.cummings@uncc.edu
# - Initial version
#
# 1.1 - 7.26.17 - John Cummings - john.cummings@uncc.edu
# - Added Send-UNCCMail() function to allow emailing of errors to Duo admins
# - Added extended error handling and logging in each catch block
#
#
################################################################################################################################################################>

#Creating an internal function to perform log writes using @JeffHicks Write-Log function
<# 
.Synopsis 
   Write-Log writes a message to a specified log file with the current time stamp. 
.DESCRIPTION 
   The Write-Log function is designed to add logging capability to other scripts. 
   In addition to writing output and/or verbose you can write to a log file for 
   later debugging. 
.NOTES 
   Created by: Jason Wasser @wasserja 
   Modified: 11/24/2015 09:30:19 AM   
 
   Changelog: 
    * Code simplification and clarification - thanks to @juneb_get_help 
    * Added documentation. 
    * Renamed LogPath parameter to Path to keep it standard - thanks to @JeffHicks 
    * Revised the Force switch to work as it should - thanks to @JeffHicks 
 
   To Do: 
    * Add error handling if trying to create a log file in a inaccessible location. 
    * Add ability to write $Message to $Verbose or $Error pipelines to eliminate 
      duplicates. 
.PARAMETER Message 
   Message is the content that you wish to add to the log file.  
.PARAMETER Path 
   The path to the log file to which you would like to write. By default the function will  
   create the path and file if it does not exist.  
.PARAMETER Level 
   Specify the criticality of the log information being written to the log (i.e. Error, Warning, Informational) 
.PARAMETER NoClobber 
   Use NoClobber if you do not wish to overwrite an existing file. 
.EXAMPLE 
   Write-Log -Message 'Log message'  
   Writes the message to c:\Logs\PowerShellLog.log. 
.EXAMPLE 
   Write-Log -Message 'Restarting Server.' -Path c:\Logs\Scriptoutput.log 
   Writes the content to the specified log file and creates the path and file specified.  
.EXAMPLE 
   Write-Log -Message 'Folder does not exist.' -Path c:\Logs\Script.log -Level Error 
   Writes the message to the specified log file as an error message, and writes the message to the error pipeline. 
.LINK 
   https://gallery.technet.microsoft.com/scriptcenter/Write-Log-PowerShell-999c32d0 
#> 
function Write-Log 
{ 
    [CmdletBinding()] 
    Param 
    ( 
        [Parameter(Mandatory=$true, 
                   ValueFromPipelineByPropertyName=$true)] 
        [ValidateNotNullOrEmpty()] 
        [Alias("LogContent")] 
        [string]$Message, 
 
        [Parameter(Mandatory=$false)] 
        [Alias('LogPath')] 
        [string]$Path='E:\DuoScripts\DuoSyncLog.log', 
         
        [Parameter(Mandatory=$false)] 
        [ValidateSet("Error","Warn","Info")] 
        [string]$Level="Info", 
         
        [Parameter(Mandatory=$false)] 
        [switch]$NoClobber 
    ) 
 
    Begin 
    { 
        # Set VerbosePreference to Continue so that verbose messages are displayed. 
        $VerbosePreference = 'Continue' 
    } 
    Process 
    { 
         
        # If the file already exists and NoClobber was specified, do not write to the log. 
        if ((Test-Path $Path) -AND $NoClobber) { 
            Write-Error "Log file $Path already exists, and you specified NoClobber. Either delete the file or specify a different name." 
            Return 
            } 
 
        # If attempting to write to a log file in a folder/path that doesn't exist create the file including the path. 
        elseif (!(Test-Path $Path)) { 
            Write-Verbose "Creating $Path." 
            $NewLogFile = New-Item $Path -Force -ItemType File 
            } 
 
        else { 
            # Nothing to see here yet. 
            } 
 
        # Format Date for our Log File 
        $FormattedDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss" 
 
        # Write message to error, warning, or verbose pipeline and specify $LevelText 
        switch ($Level) { 
            'Error' { 
                Write-Error $Message 
                $LevelText = 'ERROR:' 
                } 
            'Warn' { 
                Write-Warning $Message 
                $LevelText = 'WARNING:' 
                } 
            'Info' { 
                Write-Verbose $Message 
                $LevelText = 'INFO:' 
                } 
            } 
         
        # Write log entry to $Path 
        "$FormattedDate $LevelText $Message" | Out-File -FilePath $Path -Append 
    } 
    End 
    { 
    } 
}

#Create a function to mail someone if something goes wrong
function Send-UNCCMail ([string]$toUser="john.cummings@uncc.edu", [string]$smtpServer="ironhost.uncc.edu", [string]$from="donnotreply@uncc.edu", [string]$subject="Duo Sync Script Failure", [string]$mybody="An error occurred attempting to sync Duo Users with AD"){
Send-MailMessage -To $toUser  -From $from -Subject $subject -body $mybody -smtpserver $smtpServer -BodyAsHtml
}


#Import the Duo API ps modules to get the list of duo users from duo.com
try{
    Write-Log -Message "################### Script Started #########################"
    Write-Log -Message "Importing the Duo API PowerShell module........"
    #Importing Duo API module
    Import-Module Duo -ErrorAction Stop
}
catch{
    Write-Log -Message "An error occurred trying to import the Duo API module `n $_.Exception.Message"
    Send-UNCCMail -subject "Import of Duo Module failed" -mybody $_.Exception.Message
    Write-Log -Message "############ SCRIPT FAILURE PLEASE REVIEW ###################"
    BREAK
}

#If the duo API import was a success, run the duoGetUser function to get all users in a PS object
try{
    Write-Log -Message "Getting a list of Duo users from Duo.com and importing in to PS Object...."
    $users=duoGetUser 
    Write-Log -Message "Importing the ActiveDirectory module for use in object compare....."
    Import-Module ActiveDirectory -ErrorAction Stop
}
catch{
    Write-Log -Message "An error occurred trying to import the ActiveDirectory and duo module...... `n $_.Exception.Message"
    Send-UNCCMail -subject "Import of AD module failed" -mybody $_.Exception.Message
    Write-Log -Message "############ SCRIPT FAILURE PLEASE REVIEW ###################"
    BREAK
}

#Export the users variable to a CSV so you can do a simple CSV->CSV compare
try{
    Write-Log -Message "Getting the duoUsers PS object and exporting to CSV...."
    $users | Select-Object | Export-Csv -Path duoimport.csv -ErrorAction Stop
    Write-Log -Message "Succeeded in exporting duoUsers PS object to CSV duoimport.csv"
}
catch{
    Write-Log -Message "An error occurred trying to export the duoUsers object to CSV `n $_.Exception.Message"
    Send-UNCCMail -subject "An error occurred trying to export the duoUsers object to CSV" -mybody $_.Exception.Message
    Write-Log -Message "############ SCRIPT FAILURE PLEASE REVIEW ###################"
    BREAK
}

#Get the current members of InfoSec-Duo-Sync and export to CSV for comparison
try{
    Write-Log -Message "Getting the membership in InfoSec-Duo-Sync and writing to infosecduosync.csv....."
    Get-ADGroupMember -Identity "InfoSec-Duo-Sync" | 
    Select sAMAccountName | 
    Export-CSV -Path infosecduosync.csv -NoTypeInformation -ErrorAction Stop
    Write-Log -Message "Succeeded in exporting membership of InfoSec-Duo-Sync to CSV"
}
catch{
    Write-Log -Message "Something went wrong when attempting to retrieve the InfoSec-Duo-Sync group and write its contents to CSV `n $_.Exception.Message"
    Send-UNCCMail -subject "Error writing AD group to CSV for comparison" -mybody $_.Exception.Message
    Write-Log -Message "############ SCRIPT FAILURE PLEASE REVIEW ###################"
    BREAK
}

#clean up the initial CSVs so that they both have sAMAccountName headers for comparison
try{
    Write-Log -Message "Attempting to rewrite duoimport.csv to a new file with sAMAccountName headers...."
    Import-CSV -Path duoimport.csv | 
    Select @{Name="sAMAccountName";Expression={$_."username"}} |
    Export-CSV -Path duousersclean.csv -NoTypeInformation -ErrorAction Stop
    Write-Log -Message "Rewrite of duoimport.csv with correct headers was successful"
}
catch{
    Write-Log -Message "There was an error trying to rewrite the duoimport.csv headers `n $_.Exception.Message"
    Send-UNCCMail -subject "There was an error trying to rewrite the duoimport.csv headers" -mybody $_.Exception.Message
    Write-Log -Message "############ SCRIPT FAILURE PLEASE REVIEW ###################"
    BREAK
}

#Compare the two csv files and write the differences to a third differences.csv file
try{
    Write-Log -Message "Comparing infosecdusync.csv and duousersclean.csv and getting differences......."
    Compare-Object -ReferenceObject $(Get-Content infosecduosync.csv) -DifferenceObject $(Get-Content duousersclean.csv) `
    |  Where-Object{$_.SideIndicator -eq '=>'} | `
    Select-Object InputObject | export-csv differences.csv -NoTypeInfo 
    (gc differences.csv) | % {$_ -replace '"', ""} | out-file differences.csv -Fo -En ascii -ErrorAction Stop
    Write-Log -Message "Successfully wrote membership differences to differences.csv"
}
catch{
    Write-Log -Message "There was an error comparing PS objects for Duo and AD `n $_.Exception.Message"
    Send-UNCCMail -subject "There was an error comparing PS objects for Duo and AD" -mybody $_.Exception.Message
    Write-Log -Message "############ SCRIPT FAILURE PLEASE REVIEW ###################"
    BREAK
}

#Read the differences.csv file as an input and add missing user objects that were in Duo to AD writing each individual user add to log
try{
    Write-Log -Message "Reading the differences.csv and adding missing users to InfoSec-Duo-Sync AD group...."
    Import-CSV -Path differences.csv | 
    ForEach-Object{
        if($_.InputObject -ne "pmp-its-idm"){
        Add-ADGroupMember InfoSec-Duo-Sync $_.InputObject
        Write-Log -Message "Added user $_.InputObject to the InfoSec-Duo-Sync AD group"
        }
    } -ErrorAction Stop
}
catch{
    Write-Log -Message "Failed to add missing Duo users to the AD group: `n $_.Exception.Message"
    Send-UNCCMail -subject "Failed to add missing Duo users to the AD group" -mybody $_.Exception.Message
    Write-Log -Message "############ SCRIPT FAILURE PLEASE REVIEW ###################"
    BREAK
}

#Clean up all the CSV files from disk
try{
    Write-Log -Message "Attempting to remove the temporary CSV files from disk......"
    Remove-Item infosecduosync.csv
    Remove-Item differences.csv
    Remove-Item duousersclean.csv
    Remove-Item duoimport.csv
    Write-Log -Message "Successfully cleaned up the temporary CSV files....."
    Write-Log -Message "Script completed successfully."
    Write-Log -Message "################### Script finished ######################"
}
catch{
    Write-Log -Message "Cleanup of temporary CSV files failed. Check e:\duoscripts to manually clean up. `n $_.Exception.Message"
    Send-UNCCMail -subject "Cleanup of temporary CSV files failed" -mybody $_.Exception.Message
    Write-Log -Message "############ SCRIPT FAILURE PLEASE REVIEW ###################"
    BREAK
}