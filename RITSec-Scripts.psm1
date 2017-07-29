#Requires -Version 4.0
<#
    RITSec-Scripts.psm1 - Scripts to help in the automation of user account
    creation as well as general automation of the RITSec Cluster.

    Author: Brandon Adler
#>

<#
    .SYNOPSIS
    Automates adding of new users to the RITSec Infrastructure.

    .DESCRIPTION
    Automates adding of new users to the RITSec Infrastructure as well as creating
    a vApp for that user and giving them the correct permissions to be able to access
    their own vApp as well as networks that general users are allowed to use.

    .PARAMETER FirstName
    First name of user to be added.

    .PARAMETER LastName
    Last name of user to be added.

    .PARAMETER Email
    RIT email of user to be added.  Must be in abc1234@g.rit.edu format.

    .EXAMPLE
    Add-RITSecUser -FirstName Joe -LastName Graham jxg5678@g.rit.edu
#>
function Add-User {
    Param (
        [Parameter(Mandatory=$true)][string]$FirstName,
        [Parameter(Mandatory=$true)][string]$LastName,
        [Parameter(Mandatory=$true)][string]$Email,
        [switch]$OverrideRITEmail
    )
    # Parse input for vApp Name
    $UserName = $FirstName[0] + $LastName

    # Create user account in AD
    Add-ADUser -FirstName $FirstName -LastName $LastName -Email $Email -OverrideRITEmail:$OverrideRITEmail -ErrorAction Stop

    # Creates a vApp for the user.
    Add-VApp -UserName $UserName -ErrorAction Stop
}

function Add-ProjectMember {
    Param (
        [Parameter(Mandatory=$true)][string]$Project,
        [Parameter(Mandatory=$true)][string]$Username
    )
}

<#
    .SYNOPSIS
    Adds user to RITSec AD and adds new user to necessary groups.

    .DESCRIPTION
    Adds user to RITSec Active Directory and adds the new user to necessary groups.  
    Details of current configuration in Notes section below.

    .PARAMETER FirstName
    First name of user to be added.

    .PARAMETER LastName
    Last name of user to be added.

    .PARAMETER Email
    RIT email of user to be added.  Must be in abc1234@g.rit.edu format.

    .PARAMETER AdditionalGroups
    A list of additional groups the user should be added to. Default groups in notes.

    .PARAMETER OverrideRITEmail
    Used to add a user without an RIT email.

    .EXAMPLE
    Add-RITSecADUser -FirstName Joe -LastName Graham jxg5678@g.rit.edu

    .NOTES
    Current Configuration:
    Primary Domain Controller: quill.galaxy.ritsec
    General User OU: OU=Users,OU=Datacenter,DC=galaxy,DC=ritsec
    Default Groups Users Are Added To: vCenter Users, VPN Users
#>
function Add-ADUser {
    Param (
        [Parameter(Mandatory=$true)][string]$FirstName,
        [Parameter(Mandatory=$true)][string]$LastName,
        [Parameter(Mandatory=$true)][string]$Email,
        [string[]]$AdditionalGroups,
        [switch]$OverrideRITEmail
    )
    # Validate user input for Email is an RIT email
    # Added an option to override (just in case)
    try {
        New-Object -TypeName System.Net.Mail.MailAddress -ArgumentList $Email | Out-Null
    }
    catch {
        Write-Error "The email address entered is not in the form required for an e-mail address."
        return
    }

    # Temp var for string after the "@" in the address
    $EmailSuffix = $Email.Split("@")[1]

    # If the email address doesn't equal "g.rit.edu", then
    #   If the email address equals "rit.edu", convert to "g.rit.edu"
    #   Else check if $OverrideRITEmail is set to true
    if($EmailSuffix -ne "g.rit.edu") {
        if($EmailSuffix -eq "rit.edu") {
            Write-Host "Converting e-mail address to g.rit.edu" -ForegroundColor Yellow
            $Email = $Email.Split("@")[0] + "@g.rit.edu"
        }
        else {
            if($OverrideRITEmail) {
                Write-Warning -Message "You have overridden the RIT email check! Adding non-RIT account."
            }
            else {
                Write-Error "Non-RIT e-mail address entered.  Either enter an RIT e-mail address or override if necessary."
                return
            }
        }
    }

    # Get user's full name
    $FullName = $FirstName + " " + $LastName

    # Make username for the user
    $UserName = $FirstName[0] + $LastName

    # Add new user with specified parameters to AD.
    $TempPassword = New-SWRandomPassword -PasswordLength 20
    try {
        New-ADUser -Name $FullName -GivenName $FirstName -Surname $LastName -AccountPassword (ConvertTo-SecureString -String $TempPassword -AsPlainText -Force) `
            -EmailAddress $Email -SamAccountName $UserName -Enabled $true -Path "OU=Users,OU=Datacenter,DC=galaxy,DC=ritsec" `
            -ChangePasswordAtLogon $false -DisplayName $FullName -UserPrincipalName "$UserName@galaxy.ritsec"
    }
    catch [Microsoft.ActiveDirectory.Management.ADIdentityAlreadyExistsException] {
        Write-Warning -Message "The specified account ($UserName) already exists.  Continuing..."
        return
    }
    catch {
        Write-Error $_ 
        return
    }

    # Combining Default groups with AdditionalGroups
    $DefaultGroups = "vCenter Users","VPN Users"
    $DefaultGroups += $AdditionalGroups

    # Add new user to necessary groups
    foreach($Group in $DefaultGroups) {
        Add-ADGroupMember -Identity $Group -Members $UserName
    }

    # Output overview of the actions above with relevant information
    Write-Host "`nAccount Creation Output:" -ForegroundColor Green
    Write-Host "New Account: $Username"
    Write-Host "Email: $Email"
    Write-Host "Groups added to: vCenter Users, VPN Users"
    Write-Host "Temporary Password: $TempPassword`n"
}

<#
 .SYNOPSIS
 Creates a vApp when a name is specified.
 
 .DESCRIPTION
 Creates a vApp for a new user being added to the RITSec Cluster.  User is given
 permission to access their vApp and any general networks for them to use VMs on.
 
 .PARAMETER UserName
 Name of the vApp to be created.  Corresponds to the name of the user who the
 vApp belongs to.
 
 .EXAMPLE
 Add-RITSecVApp -Name "jgraham"
#>
function Add-ResourcePool {
    Param (
        [Parameter(Mandatory=$true)][string]$UserName
    )
    # Configuration settings for current vCenter
    $RoleName = "RITSec User"
    $DomainAlias = "ritsec"
    $UserFolder = Get-Folder -Name "User Folders"

    # Get VI Role
    $Role = Get-VIRole -Name $RoleName

    # Create folder for the user
    $NewFolder = New-Folder -Name "$UserName's Folder" -Location $UserFolder

    # Assign new user permissions to access folder
    New-VIPermission -Entity $NewFolder -Role $Role -Principal "$DomainAlias\$UserName"

    # Create vApp
    $ResourcePool = New-ResourcePool -Name $UserName -Location (Get-Cluster)[0]

    # Move vApp into folder created above
    Move-ResourcePool -ResourcePool $ResourcePool -Destination $NewFolder

    # Assign new user permissions to access vApp
    New-VIPermission -Entity $ResourcePool -Role $role -Principal "$DomainAlias\$UserName"

    # Output overview of the actions above with relevant information
    Write-Host "`nvApp Creation Output:" -ForegroundColor Green
    Write-Host "vApp Name: $($ResourcePool.Name)"
    Write-Host "Folder Name: $UserName's Folder"
    Write-Host "User allowed access: $DomainAlias\$UserName"
    Write-Host "Role Given to user: $RoleName"
}

<#
    .SYNOPSIS
    Short description

    .DESCRIPTION
    Long description

    .PARAMETER Identity
    Parameter description

    .EXAMPLE
    An example

    .NOTES
    General notes
#>
function Remove-User {
    Param (
        [Parameter(Mandatory=$true)][string]$Identity,
        [switch]$PreserveVApp = $false
    )

    # Remove User from AD
    Remove-ADUser -Identity $Identity -Confirm:$false

    if(!$PreserveVApp) {
        $VApp = Get-VApp -Name $Identity
        Remove-VApp -VApp $VApp -DeletePermanently -Confirm:$false
    }    
}

<#
    .Synopsis
        Generates one or more complex passwords designed to fulfill the requirements for Active Directory
    .DESCRIPTION
        Generates one or more complex passwords designed to fulfill the requirements for Active Directory
    .EXAMPLE
        New-SWRandomPassword
        C&3SX6Kn

        Will generate one password with a length between 8  and 12 chars.
    .EXAMPLE
        New-SWRandomPassword -MinPasswordLength 8 -MaxPasswordLength 12 -Count 4
        7d&5cnaB
        !Bh776T"Fw
        9"C"RxKcY
        %mtM7#9LQ9h

        Will generate four passwords, each with a length of between 8 and 12 chars.
    .EXAMPLE
        New-SWRandomPassword -InputStrings abc, ABC, 123 -PasswordLength 4
        3ABa

        Generates a password with a length of 4 containing atleast one char from each InputString
    .EXAMPLE
        New-SWRandomPassword -InputStrings abc, ABC, 123 -PasswordLength 4 -FirstChar abcdefghijkmnpqrstuvwxyzABCEFGHJKLMNPQRSTUVWXYZ
        3ABa

        Generates a password with a length of 4 containing atleast one char from each InputString that will start with a letter from 
        the string specified with the parameter FirstChar
    .OUTPUTS
        [String]
    .NOTES
        Written by Simon Wåhlin, blog.simonw.se
        I take no responsibility for any issues caused by this script.
    .FUNCTIONALITY
        Generates random passwords
    .LINK
        http://blog.simonw.se/powershell-generating-random-password-for-active-directory/
#>
function New-SWRandomPassword {
    
    [CmdletBinding(DefaultParameterSetName='FixedLength',ConfirmImpact='None')]
    [OutputType([String])]
    Param
    (
        # Specifies minimum password length
        [Parameter(Mandatory=$false,
                   ParameterSetName='RandomLength')]
        [ValidateScript({$_ -gt 0})]
        [Alias('Min')] 
        [int]$MinPasswordLength = 8,
        
        # Specifies maximum password length
        [Parameter(Mandatory=$false,
                   ParameterSetName='RandomLength')]
        [ValidateScript({
                if($_ -ge $MinPasswordLength){$true}
                else{Throw 'Max value cannot be lesser than min value.'}})]
        [Alias('Max')]
        [int]$MaxPasswordLength = 12,

        # Specifies a fixed password length
        [Parameter(Mandatory=$false,
                   ParameterSetName='FixedLength')]
        [ValidateRange(1,2147483647)]
        [int]$PasswordLength = 8,
        
        # Specifies an array of strings containing charactergroups from which the password will be generated.
        # At least one char from each group (string) will be used.
        [String[]]$InputStrings = @('abcdefghijkmnpqrstuvwxyz', 'ABCEFGHJKLMNPQRSTUVWXYZ', '23456789', '!"#%&'),

        # Specifies a string containing a character group from which the first character in the password will be generated.
        # Useful for systems which requires first char in password to be alphabetic.
        [String] $FirstChar,
        
        # Specifies number of passwords to generate.
        [ValidateRange(1,2147483647)]
        [int]$Count = 1
    )
    Begin {
        Function Get-Seed{
            # Generate a seed for randomization
            $RandomBytes = New-Object -TypeName 'System.Byte[]' 4
            $Random = New-Object -TypeName 'System.Security.Cryptography.RNGCryptoServiceProvider'
            $Random.GetBytes($RandomBytes)
            [BitConverter]::ToUInt32($RandomBytes, 0)
        }
    }
    Process {
        For($iteration = 1;$iteration -le $Count; $iteration++){
            $Password = @{}
            # Create char arrays containing groups of possible chars
            [char[][]]$CharGroups = $InputStrings

            # Create char array containing all chars
            $AllChars = $CharGroups | ForEach-Object {[Char[]]$_}

            # Set password length
            if($PSCmdlet.ParameterSetName -eq 'RandomLength')
            {
                if($MinPasswordLength -eq $MaxPasswordLength) {
                    # If password length is set, use set length
                    $PasswordLength = $MinPasswordLength
                }
                else {
                    # Otherwise randomize password length
                    $PasswordLength = ((Get-Seed) % ($MaxPasswordLength + 1 - $MinPasswordLength)) + $MinPasswordLength
                }
            }

            # If FirstChar is defined, randomize first char in password from that string.
            if($PSBoundParameters.ContainsKey('FirstChar')){
                $Password.Add(0,$FirstChar[((Get-Seed) % $FirstChar.Length)])
            }
            # Randomize one char from each group
            Foreach($Group in $CharGroups) {
                if($Password.Count -lt $PasswordLength) {
                    $Index = Get-Seed
                    While ($Password.ContainsKey($Index)){
                        $Index = Get-Seed                        
                    }
                    $Password.Add($Index,$Group[((Get-Seed) % $Group.Count)])
                }
            }

            # Fill out with chars from $AllChars
            for($i=$Password.Count;$i -lt $PasswordLength;$i++) {
                $Index = Get-Seed
                While ($Password.ContainsKey($Index)){
                    $Index = Get-Seed                        
                }
                $Password.Add($Index,$AllChars[((Get-Seed) % $AllChars.Count)])
            }
            Write-Output -InputObject $(-join ($Password.GetEnumerator() | Sort-Object -Property Name | Select-Object -ExpandProperty Value))
        }
    }
}
