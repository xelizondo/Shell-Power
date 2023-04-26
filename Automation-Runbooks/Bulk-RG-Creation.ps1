Param(
[Parameter(Mandatory=$true,HelpMessage="Enter the # of Resource Groups to be created. For example: 3")][int32] $NumberOfRGs = "2",
[Parameter(Mandatory=$true,HelpMessage="Select True if these RGs are for a Workshop, false for a Demo")][bool] $bolRGpurpose = $true,
[Parameter(Mandatory=$false,HelpMessage="Enter a short string to describe the workhop or demo (NO spaces), like: CosmosDB")][String] $CustomName = "CosmosDB",
[Parameter(Mandatory=$true,HelpMessage="Enter the US Region to have the Resource Groups Created. for example: East US")][String] $RGLocation = "East US",
[Parameter(Mandatory=$true,HelpMessage="Enter the Owner(s) comma separated to set a tag for the Resource Group. for example: Srini Alavala")][String] $TagOwner = "Srini Alavala",
[Parameter(Mandatory=$true,HelpMessage="Enter the Service(s) comma separated to set a tag for the Resource Group. for example: Cosmos DB")][String] $Service = "CosmosDB",
[Parameter(Mandatory=$true,HelpMessage="Enter the Project or Engagement ID to set a tag for the Resource Group. For example: TBD")][String] $ProjectOrEngagementId = "TBD",
[Parameter(Mandatory=$true,HelpMessage="Enter the RBAC Role name to assign the user access to the RG, like: Contributor")][String] $UserRoleAsignmentName = "Contributor",
#[Parameter(Mandatory=$true,HelpMessage="Enter the MSFT  DisplayName to grant access to the Resource Groups. For example: Srini Alavala")][String] $MSFTowner = "Srini Alavala",
[Parameter(Mandatory=$true,HelpMessage="Enter the AAD Security Group to grant access to the Resource Groups. Default: Workshop-Proctors")][String] $ADGroup = "Workshop-Proctors",
[Parameter(Mandatory=$true,HelpMessage="Enter the RBAC Role to assign the MSFT Oner access to the RG, like: Contributor")][String] $OwnerRoleAsignmentName = "Contributor"
)

If ($bolRGpurpose -eq $true){
	$RGpurpose ="Workshop"
}
else {
	$RGpurpose ="Demo"
}

if ($CustomName)
{
	$RGNamePrefix = $RGpurpose + "-" + $CustomName + "-" + "User" + "-"
}
else{
    $RGNamePrefix = $RGpurpose + "-" + "User" + "-"
}

$UserNamePrefix = $RGpurpose + "-User-"
$EmailDomain = "@joyjeetmhotmail.onmicrosoft.com"

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

$AzGroupForRBAC = Get-AzADGroup -SearchString $ADGroup

foreach($i in 1..$NumberOfRGs)
{
	Try {
		$RGname = $RGNamePrefix + $i  + "-" + "RG"
		$UserPrincipalName = $UserNamePrefix + $i + $EmailDomain
		New-AzResourceGroup -Name $RGname -Location $RGLocation -Tag @{Owner=$TagOwner; Type=$RGpurpose; ProjectOrEngagementId=$ProjectOrEngagementId; Provisioning="Automation"; Service=$Service}
		Write-Host "$RGname : Created successfully!"
		New-AzRoleAssignment -SignInName $UserPrincipalName -RoleDefinitionName $UserRoleAsignmentName -ResourceGroupName $RGname
		New-AzRoleAssignment -ObjectId $AzGroupForRBAC.id -RoleDefinitionName $UserRoleAsignmentName -ResourceGroupName $RGname
	}
	Catch {
		Write-Error "Error occurred. $_"
	}
}

#$RGname = $RGNamePrefix + "*"
#$OwnerUser1 = Get-AzADUser -DisplayName $MSFTowner
#Get-AzResourceGroup -Name $RGname | New-AzRoleAssignment -ObjectId $OwnerUser1.id -RoleDefinitionName $OwnerRoleAsignmentName