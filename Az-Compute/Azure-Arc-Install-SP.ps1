try {
    $ServicePrincipalId="";
    $ServicePrincipalClientSecret="";

    $env:SUBSCRIPTION_ID = "";
    $env:RESOURCE_GROUP = "";
    $env:TENANT_ID = "";
    $env:LOCATION = "eastus";
    $env:AUTH_TYPE = "principal";
    $env:CORRELATION_ID = "d98b5763-428f-4d0a-8554-b83950974a94";
    $env:CLOUD = "AzureCloud";
    

    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072;
    Invoke-WebRequest -UseBasicParsing -Uri "https://aka.ms/azcmagent-windows" -TimeoutSec 30 -OutFile "$env:TEMP\install_windows_azcmagent.ps1";
    & "$env:TEMP\install_windows_azcmagent.ps1";
    if ($LASTEXITCODE -ne 0) { exit 1; }
    & "$env:ProgramW6432\AzureConnectedMachineAgent\azcmagent.exe" connect --service-principal-id "$ServicePrincipalId" --service-principal-secret "$ServicePrincipalClientSecret" --resource-group "$env:RESOURCE_GROUP" --tenant-id "$env:TENANT_ID" --location "$env:LOCATION" --subscription-id "$env:SUBSCRIPTION_ID" --cloud "$env:CLOUD" --private-link-scope "/subscriptions/af3717f4-48d1-42d5-8b79-453a28496737/resourceGroups/rg-arc-pls/providers/Microsoft.HybridCompute/privateLinkScopes/arc-pls-eastus" --tags "Datacenter=Home,City=Rockford,StateOrDistrict=MI,CountryOrRegion=US,Environment=Development,'Business criticality'=low,CreatedBy=XER" --correlation-id "$env:CORRELATION_ID";
}
catch {
    $logBody = @{subscriptionId="$env:SUBSCRIPTION_ID";resourceGroup="$env:RESOURCE_GROUP";tenantId="$env:TENANT_ID";location="$env:LOCATION";correlationId="$env:CORRELATION_ID";authType="$env:AUTH_TYPE";operation="onboarding";messageType=$_.FullyQualifiedErrorId;message="$_";};
    Invoke-WebRequest -UseBasicParsing -Uri "https://gbl.his.arc.azure.com/log" -Method "PUT" -Body ($logBody | ConvertTo-Json) | out-null;
    Write-Host  -ForegroundColor red $_.Exception;
}
