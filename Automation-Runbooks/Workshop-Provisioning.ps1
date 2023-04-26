Param(
[Parameter(Mandatory=$true,HelpMessage="Enter the # of Resource Groups to be created. For example: 3")][int32]$NumberOfRGs = "40",
[Parameter(Mandatory=$false,HelpMessage="Enter a short string to describe the workhop or demo (NO spaces), like: CosmosDB")][String]$CustomName = "CosmosDB",
[Parameter(Mandatory=$true,HelpMessage="Enter the US Region to have the Resource Groups Created. for example: East US")][String]$RGLocation = "East US",
[Parameter(Mandatory=$true,HelpMessage="Enter the Owner(s) comma separated to set a tag for the Resource Group. for example: Srini Alavala")][String]$TagOwner = "Srini Alavala",
[Parameter(Mandatory=$true,HelpMessage="Enter the Service(s) comma separated to set a tag for the Resource Group. for example: Cosmos DB")][String]$Service = "CosmosDB",
[Parameter(Mandatory=$true,HelpMessage="Enter the Project or Engagement ID to set a tag for the Resource Group. For example: TBD")][String]$ProjectOrEngagementId = "TBD"
)

$CreationTime = Get-Date -Format "ddd-MM-dd-yyyy-HH-mm_K"
$bolUserEnable = $True #True to enable users
$Purpose ="Workshop"
$UserRoleAsignmentName = "Contributor"
$ADGroup = "Workshop-Proctors"
$UserNamePrefix = $Purpose + "-User-"
$EmailDomain = "@joyjeetmhotmail.onmicrosoft.com"

if ($CustomName)
{
	$RGNamePrefix = $Purpose + "-" + $CustomName + "-" + "User" + "-"
}
else{
    $RGNamePrefix = $Purpose + "-" + "User" + "-"
}

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
$token = (Get-AzAccessToken -ResourceTypeName AadGraph).token
Connect-AzureAD -AadAccessToken $token -AccountId $AzureContext.Account -TenantId $AzureContext.Tenant

#Find Workshop Users and enable their sign in status
Get-AzureADUser -All $true | Where-Object {$_.Department -eq $Purpose} | Set-AzureADUser -AccountEnabled $true

#Find AD group and store in variable for later user
$AzGroupForRBAC = Get-AzADGroup -SearchString $ADGroup

foreach($i in 1..$NumberOfRGs)
{
	Try {
		$RGname = $RGNamePrefix + $i  + "-" + "RG"
		$UserPrincipalName = $UserNamePrefix + $i + $EmailDomain
		New-AzResourceGroup -Name $RGname -Location $RGLocation -Tag @{Owner=$TagOwner; Creation=$CreationTime; Type=$Purpose; ProjectOrEngagementId=$ProjectOrEngagementId; Provisioning="Automation"; Service=$Service}
		Write-Host "$RGname : Created successfully!"
		New-AzRoleAssignment -SignInName $UserPrincipalName -RoleDefinitionName $UserRoleAsignmentName -ResourceGroupName $RGname
		New-AzRoleAssignment -ObjectId $AzGroupForRBAC.id -RoleDefinitionName $UserRoleAsignmentName -ResourceGroupName $RGname
	}
	Catch {
		Write-Error "Error occurred. $_"
	}
}

