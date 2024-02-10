#based on https://learn.microsoft.com/azure/firewall-manager/secure-cloud-network-powershell#upgrade-an-existing-hub-with-availability-zones
#To create an Azure Firewall in a vWAN Hub with Availability Zones, you must first create a Firewall Policy with Availability Zones.

$RGvwan = "lab-vwan-eastus" #"Resource Group where the vWAN is located"
$VwanName = "vwan-intra" #"vWAN Name"
$RGvhub = "lab-vwan-westus2" #"Resource Group where the vWAN Hub is located, Az Firewall will be created in the same RG where the vWAN Hub is"
$HubName =  "vhub2-westus2" #"vWAN Hub Name"
$Location = "westus2" #"Location where the vWAN Hub is located"
$FirewallName = "vhub2-westus2-azfw" #"Name of the Az Firewall"
$FirewallTier = "Premium"  #"Standard or Premium"
$RGfwpolicy = "lab-vwan-security-westus2"  #"Resource Group where the Firewall Policy is located"
$FirewallPolicyName = "vhub2-westus2-fwpolicy" #"Name of the Firewall Policy"
$FWsub = "" #"sub id where the firewall will be created"
$FWPolsub = "" #"sub id where the firewall policy is located"


set-AzContext -Subscription $FWPolsub

# uncomment if a new Firewall Policy is needed #
#$FWPolicy = New-AzFirewallPolicy -Name $FirewallPolicyName -ResourceGroupName $RGfwpolicy -Location $Location

#Reuse a firewall policy
set-AzContext -Subscription $FWPolsub
$FWPolicy = Get-AzFirewallPolicy -Name $FirewallPolicyName -ResourceGroupName $RGfwpolicy


# Get references to vWAN and vWAN Hub to convert #
set-AzContext -Subscription $FWsub
$Vwan = Get-AzVirtualWan -ResourceGroupName $RGvwan -Name $VwanName
$Hub = Get-AzVirtualHub -ResourceGroupName $RGvhub -Name $HubName

# Create a new Firewall Public IP #
$AzFWPIPs = New-AzFirewallHubPublicIpAddress -Count 1
$AzFWHubIPs = New-AzFirewallHubIpAddress -PublicIP $AzFWPIPs

# Create Firewall instance #
$AzFW = New-AzFirewall -Name $FirewallName -ResourceGroupName $RGvhub -Location $Location `
            -VirtualHubId $Hub.Id -FirewallPolicyId $FWPolicy.Id `
            -SkuName "AZFW_Hub" -HubIPAddress $AzFWHubIPs `
            -SkuTier $FirewallTier `
            -Zone 1,2,3