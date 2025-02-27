<#

****************************************************************************************************************************
This Azure Automation runbook automates Azure Firewall backups. It takes snap shots at different instances or schedule and 
saves it to a Blob storage container. It also deletes old backups from blob storage.
 ***************************************************************************************************************************

.DESCRIPTION
	You should use this Runbook if you want to manage Azure Firewall backups in Blob storage or just want to export the current configuration. It
    works as a power runbook. 
	
#>

#param(
#    [parameter(Mandatory=$true)]
#    [String] $SubscriptionName,
#    [parameter(Mandatory=$true)]
#	[String] $ResourceGroupName,
#    [parameter(Mandatory=$true)]
#	[String] $AzureFirewallName,
#    [parameter(Mandatory=$true)]
#	[String] $AzureFirewallPolicy,
#    [parameter(Mandatory=$true)]
#    [String]$StorageAccountName,
#    [parameter(Mandatory=$true)]
#    [String]$StorageKey,
#	[parameter(Mandatory=$true)]
#    [string]$BlobContainerName,
#	[parameter(Mandatory=$true)]
#    [Int32]$RetentionDays
#)
#
#$ErrorActionPreference = 'stop'
<#/*******************************************************************
* Copyright         : 2024 
* File Name         : adp-firewall-backup.ps1
* Description       : backup Azure firewall to Blob storage
*                    
* Revision History  : 3.1
* Date		Author 			Comments
* ------------------------------------------------------------------

/******************************************************************/
#>
Import-Module Az.Network
Import-Module Az.Resources

function Login() {

    #Connect to Azure
    try
    {
        "Logging in to Azure..."
        "Please enable appropriate RBAC permissions to the system identity of this automation account. Otherwise, the runbook may fail..."
        #Connect-AzAccount -Identity -AccountID 8a8bd9e5-7fbb-4d33-981c-44d44e9c1e22
        Connect-AzAccount -Identity
    }
    catch {
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
    Write-Output "Logged in."

#    $subscriptionId=  (Get-AzSubscription -SubscriptionName $SubscriptionName).SubscriptionId 
#    Set-AzContext -SubscriptionId $subscriptionId
}

function Create-newContainer([string]$blobContainerName, $storageContext) {
	Write-Verbose "Creating '$blobContainerName' blob container space for storage..." -Verbose
	if (Get-AzStorageContainer -ErrorAction "Stop" -Context $storageContext | Where-Object { $_.Name -eq $blobContainerName }) {
		Write-Verbose "Container '$blobContainerName' already exists" -Verbose
	} else {
		New-AzStorageContainer -ErrorAction "Stop" -Name $blobContainerName -Permission Off -Context $storageContext
		Write-Verbose "Container '$blobContainerName' created" -Verbose
	}
}

function Export-To-Storageaccount([string]$azFirewallId, [string]$azFirewallRG, [string]$azFirewallName, [string]$azFirewallPolRG, [string]$azFirewallPolicy,[string]$storageKey, [string]$blobContainerName,$storageContext) {
	Write-Verbose "Starting Azure Firewall current configuration export in json..." -Verbose
    try
    {
        $BackupFilename = $azFirewallName + '-' + (Get-Date).ToString("yyyyMMddHHmm") + ".json"
        $BackupFilePath = (".\" + $BackupFilename)

        if ($azFirewallName -eq 'AzureFirewall_vhub-01-weu') {
            $FirewallPolicyID = (Get-AzFirewallPolicy -Name $azFirewallPolicy -ResourceGroupName $azFirewallPolRG).id
            Export-AzResourceGroup -ResourceGroupName $azFirewallPolRG -SkipAllParameterization -Resource @($FirewallPolicyID) -Path $BackupFilePath
        }
        else {
            $AzureFirewallId = (Get-AzFirewall -Name $azFirewallName -ResourceGroupName $azFirewallRG).id
            $FirewallPolicyID = (Get-AzFirewallPolicy -Name $azFirewallPolicy -ResourceGroupName $azFirewallPolRG).id
            Export-AzResourceGroup -ResourceGroupName $azFirewallPolRG -SkipAllParameterization -Resource @($AzureFirewallId, $FirewallPolicyID) -Path $BackupFilePath    
        }
        
	#Export value and store with name created
        Write-Output "Submitting request to dump Azure Firewall configuration"
        $blobname = $BackupFilename
        $output = Set-AzStorageBlobContent -File $BackupFilePath -Blob $blobname -Container $blobContainerName -Context $storageContext -Force -ErrorAction stop


    }
	#send out message if backup fails
    catch {
		   $ErrorMessage = "BackUp not created. Please check the input values."
#           throw $ErrorMessage
        }
    
}

function Remove-Older-Backups([int]$retentionDays, [string]$blobContainerName, $storageContext) {
	Write-Output "Removing backups older than '$retentionDays' days from blob: '$blobContainerName'"
	$isOldDate = [DateTime]::UtcNow.AddDays(-$retentionDays)
	$blobs = Get-AzStorageBlob -Container $blobContainerName -Context $storageContext
	foreach ($blob in ($blobs | Where-Object { $_.LastModified.UtcDateTime -lt $isOldDate -and $_.BlobType -eq "BlockBlob" })) {
		Write-Verbose ("Removing blob: " + $blob.Name) -Verbose
		Remove-AzStorageBlob -Blob $blob.Name -Container $blobContainerName -Context $storageContext
	}
}

try
{
    "Logging in to Azure..."
    "Please enable appropriate RBAC permissions to the system identity of this automation account. Otherwise, the runbook may fail..."
    #Connect-AzAccount -Identity -AccountID 8a8bd9e5-7fbb-4d33-981c-44d44e9c1e22
    Connect-AzAccount -Identity
}
catch {
    Write-Error -Message $_.Exception
    throw $_.Exception
}
Write-Output "Logged in."

$list = $null
$list = @()

$subs = Get-AzSubscription

foreach ($sub in $subs) {
    Set-AzContext -SubscriptionId $sub.Id
    $firewalls = Get-AzFirewall

    foreach ($firewall in $firewalls) {
        $firewall_name = $firewall.Name
        $firewall_id = $firewall.Id
        $firewall_sub = $firewall.Id.split('/')[2]
        $firewall_rg = $firewall.ResourceGroupName
        $firewall_location      = $firewall.Location
        $az_region = Get-AzLocation | Where-Object {$_.Location -eq $firewall.Location}
        $firewall_pol_name      = if($firewall.firewallPolicy.Id -eq $Null) {""} else{$firewall.firewallPolicy.Id.split('/')[8]}
        $firewall_pol_id = if($firewall.firewallPolicy.Id -eq $Null) {""} else{$firewall.firewallPolicy.Id}
        $firewall_pol_sub      = if($firewall.firewallPolicy.Id -eq $Null) {""} else{$firewall.firewallPolicy.Id.split('/')[2]}
        $firewall_pol_rg        = if($firewall.firewallPolicy.Id -eq $Null) {""} else{$firewall.firewallPolicy.Id.split('/')[4]}

        $list += [PSCustomObject]@{
            SubscriptionName        = $sub.Name
            ResourceGroupName       = $firewall_rg
            Location                = $az_region.DisplayName
            FirewallName                = $firewall_name
            FirewallPolicyName    = $firewall_pol_name
            FirewallPolicySub = $firewall_pol_sub
            FirewallPolicyRG = $firewall_pol_rg
        }
        
#        $firewall_pol_name

        if ($firewall_pol_name) {
            Set-AzContext -SubscriptionId $firewall_pol_sub
            $azFwPol = Get-AzFirewallPolicy -ResourceId $firewall_pol_Id
            $SubscriptionName = $sub.Name
            $AzureFirewallSub = $firewall_sub
            $AzureFirewallRG = $firewall_rg
            $AzureFirewallName = $firewall_name
            $AzureFirewallPolicySub = $firewall_pol_sub
            $AzureFirewallPolRG = $firewall_pol_rg
            $AzureFirewallPolicy = $firewall_pol_name
            
            $StorageAccountName = "saglobalfirewallbackup"
            $StorageKey = "5ASYNVtqVtDU/Sx8vprUmhA1piQgzmkbfgwo3VCqY1opd2WGX+hIhFX4923KAaIX4BF5f61MlY6j+AStTHttKQ="
            $BlobContainerName = $AzureFirewallPolicy.ToLower().replace('_','-') + "-backup"
            $RetentionDays = 30

            Write-Verbose "Starting database backup..." -Verbose

            $StorageContext = New-AzStorageContext -StorageAccountName $storageAccountName -StorageAccountKey $storageKey

            Create-newContainer `
            -blobContainerName $BlobContainerName `
            -storageContext $StorageContext
        
            Set-AzContext -SubscriptionId $firewall_pol_sub
#            $firewall_pol_sub

            Export-To-Storageaccount `
            -azFirewallId $firewall_id `
            -azFirewallRG $AzureFirewallRG `
            -azFirewallName $AzureFirewallName `
            -azFirewallPolRG $AzureFirewallPolRG `
            -azFirewallPolicy $AzureFirewallPolicy `
            -storageKey $StorageKey `
            -blobContainerName $BlobContainerName `
            -storageContext $StorageContext
        #	
            Remove-Older-Backups `
            -retentionDays $RetentionDays `
            -storageContext $StorageContext `
            -blobContainerName $BlobContainerName
            
            Write-Verbose "Azure Firewall current configuration back up completed." -Verbose
        
        }
    }
}

#$list