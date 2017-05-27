#Requires -Version 4.0
<#
    RITSec-Scripts.psm1 - Scripts to help in the automation of user account
    creation as well as general automation of the RITSec Cluster.
#>

#TODO: Add user account to AD, create a vApp on the cluster, and give user permission for the vApp and Project Net.

function Add-RITSecUser {
    Param (
        
    )
}

<#
.SYNOPSIS
Short description

.DESCRIPTION
Long description

.PARAMETER FirstName
First name of user to be added.

.PARAMETER LastName
Last name of user to be added.

.PARAMETER Email
RIT email of user to be added.  Must be in abc1234@g.rit.edu format.

.EXAMPLE
Add-RITSecADUser -FirstName Joe -LastName Graham jxg5678@g.rit.edu

.NOTES
General notes
#>
function Add-RITSecADUser {
    Param (
        [Parameter(Mandatory=$true)][string]$FirstName,
        [Parameter(Mandatory=$true)][string]$LastName,
        [Parameter(Mandatory=$true)][string]$Email
    )
    $Name = $FirstName + " " + $LastName
    $UserName = $FirstName[0] + $LastName
    New-ADUser -Name $Name -GivenName $FirstName -Surname $LastName -AccountPassword <#TODO: Generate Temporary Password#> `
            -EmailAddress $Email -SamAccountName $UserName -Enabled -Path "OU=Datacenter,DC=galaxy,DC=ritsec"
}

<#
.SYNOPSIS
Creates a vApp when a name is specified.

.DESCRIPTION
Creates a vApp for a new user being added to the RITSec Cluster.

.PARAMETER Name
Name of the vApp to be created.

.EXAMPLE
Add-RITSecVApp -Name "jgraham"

.NOTES
General notes
#>
function Add-RITSecVApp {
    Param (
        [Parameter(Mandatory=$true)][string]$Name
    )
    New-VApp -Name $Name -Location (Get-Cluster[0]) -Confirm:$false -RunAsync
}
