<#
!!!!!!!!!!CAUTION: Read before you run it.
This Script will: Remove all Resource Groups that match a prefix specified and all resources inside them without confirmation.

EXAMPLE
        To delete the Resource Groups like below use this prefix: "Workshop-Purpose-User-"" where the match will be more specific than "Workshop-"
			"Workshop-Purpose-User-1"
			.
			.
			"Workshop-Purpose-User-n" 
#>	

Param(
[Parameter(Mandatory=$true,HelpMessage="Enter the Resource Group name prefix for Resource Groups to be deleted. For example: Workshop-[Purpose]-User-")][String]$RGNamePrefix = "Workshop-Purpose-User-",
[Parameter(Mandatory=$false,HelpMessage="Enter the value for WhatIf. Values can be either true or false")][bool]$WhatIf = $true
)

# Ensures you do not inherit an AzContext in your runbook
Disable-AzContextAutosave -Scope Process

# Connect using a Managed Service Identity
try {
        $AzureContext = (Connect-AzAccount -Identity).context
    }
catch{
        Write-Output "There is no system-assigned identity. Aborting."; 
        exit
    }

# set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext

#Retrieve Resource Groups and foce delete them 
$RGname = $RGNamePrefix + "*"
Get-AzResourceGroup -Name $RGname | Remove-AzResourceGroup -Force