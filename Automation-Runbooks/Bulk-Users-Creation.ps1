Param(
[Parameter(Mandatory=$true,HelpMessage="Enter the # of user accounts to be created. For example: 3")][int32]$TotalNumberOfUsers = "2",
[Parameter(Mandatory=$true,HelpMessage="Enter the # of user accounts to be created. For example: 1")][int32]$NumberOfUserToStartWith = "1",
[Parameter(Mandatory=$true,HelpMessage="Select True for Workshop users or False for Demo Users")][bool]$bolUserType = $true
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

If ($bolUserType -eq $true){
	$UserType ="Workshop"
	$varPassword = Get-AzKeyVaultSecret -VaultName "sdp-innovation-kv" -Name "Workshop-Users-Password" -AsPlainText
}
else {
	$UserType ="Demo"
	$varPassword = Get-AzKeyVaultSecret -VaultName "sdp-innovation-kv" -Name "Demo-Users-Password" -AsPlainText
}

$UserNamePrefix = $UserType + "-User-"
$EmailDomain = "@joyjeetmhotmail.onmicrosoft.com"

Write-Output "Password for all users is: " $varPassword

# set and store context
$AzureContext = Set-AzContext -SubscriptionName $AzureContext.Subscription -DefaultProfile $AzureContext
$token = (Get-AzAccessToken -ResourceTypeName AadGraph).token
Connect-AzureAD -AadAccessToken $token -AccountId $AzureContext.Account -TenantId $AzureContext.Tenant


$PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
$PasswordProfile.Password = $varPassword
$PasswordProfile.EnforceChangePasswordPolicy = 0
$PasswordProfile.ForceChangePasswordNextLogin = 0

foreach($i in $NumberOfUserToStartWith..$TotalNumberOfUsers){
	$DisplayName = $UserNamePrefix + $i
	$MailNickName = $UserNamePrefix + $i
	$UserPrincipalName = $UserNamePrefix + $i + $EmailDomain
	Try {
		New-AzureADUser -DisplayName $DisplayName `
			-AccountEnabled $true `
			-MailNickName $MailNickName `
			-UserPrincipalName $UserPrincipalName `
			-Department $UserType `
			-PasswordProfile $PasswordProfile
		Write-Output "$DisplayName : Azure AD user created successfully!"
	}
	Catch {
		Write-Error "$DisplayName : Error occurred while creating Azure AD Account. $_"
	}
}