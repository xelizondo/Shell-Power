#This script will loop through each subscription and resource group that the user running the script is entitled to and export the RBAC assignments to a CSV file.


Get-AzSubscription | foreach-object {

    Write-Verbose -Message "Changing to Subscription $($_.Name)" -Verbose

    Set-AzContext -TenantId $_.TenantId -SubscriptionId $_.Id -Force
    $RGName     = "NA"
    $Name     = $_.Name
    $TenantId = $_.TenantId
    $SubId    = $_.SubscriptionId  

    Get-AzRoleAssignment -IncludeClassicAdministrators | Select-Object RoleDefinitionName,DisplayName,SignInName,ObjectType,Scope,
    @{name="TenantId";expression = {$TenantId}},@{name="SubscriptionName";expression = {$Name}},@{name="SubscriptionId";expression = {$SubId}},@{name="ResourceGroupName";expression = {$RGName}} -OutVariable ra

    # Also export the individual subscriptions to excel documents on your Desktop.
    # One file per subscription
    $ra | Export-Csv -Path .\RoleAssignments.csv -NoTypeInformation -Append


    Get-AzResourceGroup | foreach-object {

    Write-Verbose -Message "Changing to Resource Group $($_.ResourceGroupName)" -Verbose
    $RGName     = $_.ResourceGroupName

    Get-AzRoleAssignment -IncludeClassicAdministrators | Select-Object RoleDefinitionName,DisplayName,SignInName,ObjectType,Scope,
    @{name="TenantId";expression = {$TenantId}},@{name="SubscriptionName";expression = {$Name}},@{name="SubscriptionId";expression = {$SubId}},@{name="ResourceGroupName";expression = {$RGName}} -OutVariable ra

    # Also export the individual subscriptions to excel documents on your Desktop.
    # One file per subscription
    $ra | Export-Csv -Path .\RoleAssignments.csv -NoTypeInformation -Append

  }
}