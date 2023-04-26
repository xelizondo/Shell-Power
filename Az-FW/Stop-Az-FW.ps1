# // Start Azure Automation Login Using Service Principal
$connectionName = "AzureRunAsConnection"
try
{
    # Get the connection "AzureRunAsConnection "
    $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName
    "Logging in to Azure..."
    Add-AzAccount `
        -ServicePrincipal `
        -TenantId $servicePrincipalConnection.TenantId `
        -ApplicationId $servicePrincipalConnection.ApplicationId `
        -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint
}
catch {
    if (!$servicePrincipalConnection)
    {
        $ErrorMessage = "Connection $connectionName not found."
        throw $ErrorMessage
    } else{
        Write-Error -Message $_.Exception
        throw $_.Exception
    }
}
# // Set script variables
$firewallRG = "RG-Hub-Core"
$firewallName = "Core-FW"
$subID = "1b233659-609f-49c0-bf59-f06289eb96e1"
Set-AzContext -subscriptionId $subID
$firewall=Get-AzFirewall -ResourceGroupName $firewallRG -Name $firewallName
$firewall.Deallocate()
$firewall | Set-AzFirewall