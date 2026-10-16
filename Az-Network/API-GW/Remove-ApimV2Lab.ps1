[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [string]$SubscriptionId,

    [string]$ResourceGroupName = 'rg-apim-v2-network-lab'
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI is required.'
}

az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) {
    throw "Unable to select subscription $SubscriptionId."
}

if ($PSCmdlet.ShouldProcess($ResourceGroupName, 'Delete the resource group and every lab resource')) {
    az group delete --name $ResourceGroupName --yes --no-wait
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to start deletion of $ResourceGroupName."
    }

    Write-Host "Deletion started for $ResourceGroupName."
}