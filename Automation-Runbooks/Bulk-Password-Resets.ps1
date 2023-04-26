Param(
#[Parameter(Mandatory=$true,HelpMessage="Enter the comma separated MSFT User(s) in DisplayName format to grant access to the Resource Groups. For example: Srini Alavala,Xavier Elizondo")][String]$MSFTowner,
[Parameter(Mandatory=$true,HelpMessage="Enter the Resource Group name prefix for Resource Groups for RBAC to be granted. For example: Workshop-[Purpose]-User-")][String]$RGNamePrefix = "Workshop-Purpose-User-",
[Parameter(Mandatory=$true,HelpMessage="Enter the AAD Security Group to grant access to the Resource Groups. Default: Workshop-Proctors")][String]$ADGroup = "Workshop-Proctors",
[Parameter(Mandatory=$true,HelpMessage="Enter the RBAC Role name to assign the user access to the RG, Default: Contributor")][String]$UserRoleAsignmentName = "Contributor",
[Parameter(Mandatory=$false,HelpMessage="Enter the value for WhatIf. Values can be either true or false")][bool]$WhatIf = $false
)

# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process

# Connect using a Managed Service Identity
try {
        $AzureContext = (Connect-AzAccount -Identity).context
    }
catch{
        Write-Output "There is no system-assigned user identity. Aborting."; 
        exit
    }

# set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext

$RGname = $RGNamePrefix + "*"

$AzGroupForRBAC = Get-AzADGroup -SearchString $ADGroup
Get-AzResourceGroup -Name $RGname | New-AzRoleAssignment -ObjectId $AzGroupForRBAC.id -RoleDefinitionName $UserRoleAsignmentName

<#
$CharArray =$MSFTowner.Split(",")
foreach ($objarray in $CharArray) {
	write-host $objarray
	$OwnerUser = Get-AzADUser -DisplayName $objarray
	write-host $OwnerUser.id
	Get-AzResourceGroup -Name $RGname | New-AzRoleAssignment -ObjectId $OwnerUser.id -RoleDefinitionName $UserRoleAsignmentName
}
#>