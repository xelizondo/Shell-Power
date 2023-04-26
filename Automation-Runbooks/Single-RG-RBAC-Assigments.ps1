Param(
#[Parameter(Mandatory=$true,HelpMessage="Enter the comma separated MSFT User(s) in DisplayName format to grant access to the Resource Groups. For example: Srini Alavala,Xavier Elizondo")][String]$MSFTowner,
#[Parameter(Mandatory=$true,HelpMessage="Enter the Resource Group name prefix for Resource Groups for RBAC to be granted. For example: Workshop-[Purpose]-User-")][String]$RGNamePrefix = "Workshop-Purpose-User-",
#[Parameter(Mandatory=$true,HelpMessage="Enter the AAD Security Group to grant access to the Resource Groups. Default: Innovation-Maintenance-Operators")][String]$ADGroup = "Innovation-Maintenance-Operators"
#[Parameter(Mandatory=$true,HelpMessage="Enter the RBAC Role name to assign the user access to the RG, Default: Contributor")][String]$UserRoleAsignmentName = "Contributor",
#[Parameter(Mandatory=$false,HelpMessage="Enter the value for WhatIf. Values can be either true or false")][bool]$WhatIf = $false
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

$AzGroupForRBAC = Get-AzADGroup -SearchString "Innovation-Maintenance-Operators"
$RBnames = "Innovation-Bulk-User-Status-Action,Innovation-Bulk-User-Passwords-Reset,Innovation-Bulk-RG-RBAC-assigments,Innovation-Bulk-RG-Deletion,Innovation-Bulk-RG-Creation,Innovation-RG-Creation" # Name of the runbook
$RGName = "rg-internal-utility" # Resource Group name for the Automation account
$automationAccountName ="aa-internal-tasks" # Name of the Automation account
#$userId = "<User ObjectId>" # Azure Active Directory (AAD) user's ObjectId from the directory

# Gets the Automation account resource
$aa = Get-AzResource -ResourceGroupName $RGName -ResourceType "Microsoft.Automation/automationAccounts" -ResourceName $automationAccountName

# The Automation Job Operator role only needs to be run once per user.
New-AzRoleAssignment -ObjectId $AzGroupForRBAC.id -RoleDefinitionName "Automation Job Operator" -Scope $aa.ResourceId
#New-AzRoleAssignment -ObjectId $userId -RoleDefinitionName "Automation Job Operator" -Scope $aa.ResourceId

$CharArray =$RBnames.Split(",")
foreach ($objRBname in $CharArray) {
	write-host $objRBname
	# Get the Runbook resource
	$rb = Get-AzResource -ResourceGroupName $RGName -ResourceType "Microsoft.Automation/automationAccounts/runbooks" -ResourceName "$objRBname"

	# Adds the user to the Automation Runbook Operator role to the Runbook scope
	New-AzRoleAssignment -ObjectId $AzGroupForRBAC.id -RoleDefinitionName "Automation Runbook Operator" -Scope $rb.ResourceId
	#New-AzRoleAssignment -ObjectId $userId -RoleDefinitionName "Automation Runbook Operator" -Scope $rb.ResourceId
}