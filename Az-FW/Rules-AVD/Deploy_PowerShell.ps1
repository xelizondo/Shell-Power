Connect-AzAccount
Select-AzSubscription -Subscription "af3717f4-48d1-42d5-8b79-453a28496737" #"<<<Your Subscription ID >>>"

# Variable definition
$ResourceGroupName = "RG-Connectivity-Core" #"<<<Your Resource Group Name>>>"
$Location = "eastus" #"<<<Your Azure Region>>>"

# Run the deployment
New-AzResourceGroupDeployment -ResourceGroupName $ResourceGroupName -Location $Location -TemplateFile ".\FirewallPolicyForAVD-template.json" -TemplateParameterFile ".\FirewallPolicyForAVD-parameters.json"

# Once completed, review all the Policy settings and rules, then associate to an existing Firewall: #

$fwpolicyname = "AVD-Policy" #"<<<Your AVD Firewall Policy Name>>>"
$fwpolicyresourcegroup = "RG-Connectivity-Core" #"<<<Resource Group where the Policy has been created>>>"
$fwname =  "AzFW-Hub-EastUS" #"<<<Your Firewall Name>>>"
$fwresourcegroup = "RG-Connectivity-Core" #"<<<Resource Group where the Azure Firewall is located>>>"

$azFw = Get-AzFirewall -Name $fwname -ResourceGroupName $fwresourcegroup
$azPolicy = Get-AzFirewallPolicy -Name $fwpolicyname -ResourceGroupName $fwpolicyresourcegroup

$azFw.FirewallPolicy = $azPolicy.Id
$azFw | Set-AzFirewall


