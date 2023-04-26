#FAILBACK Unegister EUS2 Region Workspace

$ResourceGroupNameEUS2 = "RG-AVD-Pool-1-EUS2"
$WorkspaceNameEUS2 = "WS-Pooled-Desktops-EUS2"
$SubscriptionIdEUS2 = "e446e661-f7b9-4343-b93a-1e719e986bd0"
$ApplicationGroupName = "HP-Pooled-Desktops-EUS2-DAG"
$ApplicationGroupPath = "/subscriptions/$SubscriptionIdEUS2/resourceGroups/$ResourceGroupNameEUS2/providers/Microsoft.DesktopVirtualization/applicationGroups/$ApplicationGroupName"

Select-AzSubscription -SubscriptionId $subscriptionIdEUS2

Unregister-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupNameEUS2 `
                                    -WorkspaceName $WorkspaceNameEUS2 `
                                    -ApplicationGroupPath $ApplicationGroupPath

#FAILOVER Register EUS2 Region Workspace

$ResourceGroupNameEUS = "rg-avd-pool-1"
$WorkspaceNameEUS = "WS-Pooled-Desktops"
$SubscriptionIdEUS = "e446e661-f7b9-4343-b93a-1e719e986bd0"
$ApplicationGroupName = "AG-Pooled-Desktops"
$ApplicationGroupPath = "/subscriptions/$SubscriptionIdEUS/resourceGroups/$ResourceGroupNameEUS/providers/Microsoft.DesktopVirtualization/applicationGroups/$ApplicationGroupName"

Select-AzSubscription -SubscriptionId $subscriptionIdEUS

Register-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupNameEUS `
                                    -WorkspaceName $WorkspaceNameEUS `
                                    -ApplicationGroupPath $ApplicationGroupPath
