<#
!!!!!!!!!!CAUTION: Read before you run it.
This Script will:
1. Disable sign-in for all Workshop-Users
2. Remove all Resource Groups that match a prefix specified and all resources inside them without confirmation.

EXAMPLE
        To delete the Resource Groups like below use this prefix: "Workshop-Purpose-User-"" where the match will be more specific than "Workshop-"
			"Workshop-Purpose-User-1"
			.
			.
            .
			"Workshop-Purpose-User-n" 
#>		

Param(
[Parameter(Mandatory=$true,HelpMessage="Enter the Resource Group name prefix for Resource Groups to be deleted. For example: Workshop-[Purpose]-User-")][String]$RGNamePrefix = "Workshop-Purpose-User-",
[Parameter(Mandatory=$true,HelpMessage="If True, it will use -WhatIf instead of -Force")][bool]$bolWhatIf = $true
)

$bolUserStatus = $False #True to enable users
$Purpose = "Workshop"

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

#Find Workshop Users and disable their sign in status
Get-AzureADUser -All $true | Where-Object {$_.Department -eq $Purpose} | Set-AzureADUser -AccountEnabled $bolUserStatus

#Find Resource Groups by Filter
Write-Output $RGNamePrefix
Get-AzResourceGroup | ? ResourceGroupName -match $RGNamePrefix | Select-Object ResourceGroupName
#Get-AzResourceGroup -Name $RGname | ForEach-Object { Start-Job -InputObject $_ -ScriptBlock { $Input | Remove-AzResourceGroup -Force } }

if ($bolWhatIf) {
	Write-Output "Running in -WhatIf mode"
	Get-AzResourceGroup -Name $RGname | ForEach-Object { Start-Job -InputObject $_ -ScriptBlock { $Input | Remove-AzResourceGroup -WhatIf } }
	Get-AzResourceGroup | ? ResourceGroupName -match $RGNamePrefix | Remove-AzResourceGroup -AsJob -WhatIf
}
else {
	Write-Output "Running in -Force mode" 
	#Async Delete ResourceGroups by Filter
	Get-AzResourceGroup | ? ResourceGroupName -match $RGNamePrefix | Remove-AzResourceGroup -AsJob -Force
}
Get-Job | Wait-Job	