
$SubscriptionID = "MS-XE-CSA-AIA-LZ"
$location = "eastus"
$rg = "RG-Network-Preview"
$vnetname = "vnet-preview"
$vnetprefix = "172.19.0.0/22"
$subnetname1 = "172.19.1.0/24"
$subnetname2 = "172.19.2.0/24"
$saname = "savnetpreviewxelizondo"
$netwatcher = "NetworkWatcher_eastus"
$InsightsWorkspace = "MyWorkspace"

set-AzContext -Subscription $SubscriptionID

New-AzResourceGroup -Name $rg -Location $location
New-AzOperationalInsightsWorkspace -Name $InsightsWorkspace -ResourceGroupName $rg -Location $location -RetentionInDays 30
New-AzStorageAccount -Name $saname -ResourceGroupName $rg -Location $location -SkuName Standard_LRS -Kind StorageV2 -EnableHttpsTrafficOnly $true 
$frontendSubnet = New-AzVirtualNetworkSubnetConfig -Name frontendSubnet -AddressPrefix $subnetname1
$backendSubnet  = New-AzVirtualNetworkSubnetConfig -Name backendSubnet  -AddressPrefix $subnetname2
New-AzVirtualNetwork -ResourceGroupName $rg -Location $location -Name $vnetname -AddressPrefix $vnetprefix -Subnet $frontendSubnet,$backendSubnet

$vnet = Get-AzVirtualNetwork -Name $vnetname -ResourceGroupName $rg
$storageAccount = Get-AzStorageAccount -Name $saname -ResourceGroupName $rg
$nw = Get-AzNetworkWatcher -ResourceGroupName "NetworkWatcherRG" -Name $netwatcher
$workspace = Get-AzOperationalInsightsWorkspace -Name $InsightsWorkspace -ResourceGroupName $rg


Set-AzNetworkWatcherFlowLog -Enabled $true -Name 'testflowlog' -NetworkWatcherName $nw.Name `
    -ResourceGroupName NetworkWatcherRg -StorageId $storageAccount.Id -TargetResourceId $vnet.Id

Set-AzNetworkWatcherFlowLog -Enabled $true -Name 'testflowlog' -NetworkWatcherName $nw.Name `
    -ResourceGroupName NetworkWatcherRg -StorageId $storageAccount.Id -TargetResourceId $vnet.Id `
    -EnableTrafficAnalytics -TrafficAnalyticsWorkspaceId $workspace.ResourceId -TrafficAnalyticsInterval 10


Get-AzNetworkWatcherFlowLog -ResourceId /subscriptions/e446e661-f7b9-4343-b93a-1e719e986bd0/resourceGroups/NetworkWatcherRG/providers/Microsoft.Network/networkWatchers/NetworkWatcher_eastus/flowLogs/testflowlog