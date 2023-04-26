Param(
[Parameter(Mandatory=$true,HelpMessage="Select True for Workshop users or False for Demo Users")][bool]$bolUserType = $true,
[Parameter(Mandatory=$true,HelpMessage="Select True for Enabled or False for Disabled")][bool]$bolUserStatus = $True
)

If ($bolUserType -eq $true){
	$UserType ="Workshop"
}
else {
	$UserType ="Demo"
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

if ($bolUserStatus -eq $false){
	Get-AzureADUser -All $true | Where-Object {$_.Department -eq $UserType} | Set-AzureADUser -AccountEnabled $false
}
elseif ($bolUserStatus -eq $true){
	Get-AzureADUser -All $true | Where-Object {$_.Department -eq $UserType} | Set-AzureADUser -AccountEnabled $true
}
else {
	exit
}
