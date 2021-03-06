#
# Module manifest for module 'RITSec-Scripts'
#
# Generated by: Brandon Adler
#
# Generated on: 5/29/2017
#

@{

# Script module or binary module file associated with this manifest.
RootModule = '.\UserCreation.psm1'

# Version number of this module.
ModuleVersion = '1.0'

# Supported PSEditions
# CompatiblePSEditions = @()

# ID used to uniquely identify this module
GUID = '097346af-55ce-40a4-b11e-5f4408c25fa7'

# Author of this module
Author = 'Brandon Adler'

# Company or vendor of this module
CompanyName = 'OrganizationName'

# Copyright statement for this module
Copyright = '(c) 2017 Brandon Adler. All rights reserved.'

# Description of the functionality provided by this module
# Description = ''

# Minimum version of the Windows PowerShell engine required by this module
PowerShellVersion = '3.0'

# Modules that must be imported into the global environment prior to importing this module
RequiredModules = @('VMware.VimAutomation.Core', 
               'ActiveDirectory')

# Functions to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no functions to export.
FunctionsToExport = 'Add-User', 'Add-VApp', 'Remove-User'

# Cmdlets to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no cmdlets to export.
CmdletsToExport = '*'

# Variables to export from this module
VariablesToExport = '*'

# Aliases to export from this module, for best performance, do not use wildcards and do not delete the entry, use an empty array if there are no aliases to export.
AliasesToExport = '*'

# HelpInfo URI of this module
# HelpInfoURI = ''

# Default prefix for commands exported from this module. Override the default prefix using Import-Module -Prefix.
DefaultCommandPrefix = 'Auto'

}

