[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$SubscriptionId,

    [ValidateSet('Validate', 'WhatIf', 'Deploy')]
    [string]$Mode = 'Validate',

    [string]$Location = 'canadacentral',

    [string]$DeploymentName = "apim-v2-network-lab-$(Get-Date -Format 'yyyyMMdd-HHmmss')",

    [switch]$ConfirmDeployment
)

$ErrorActionPreference = 'Stop'
$templateFile = Join-Path $PSScriptRoot 'main.bicep'
$parameterFile = Join-Path $PSScriptRoot 'main.bicepparam'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI is required. Install it, run az login, and retry.'
}

if ($Mode -eq 'Deploy' -and -not $ConfirmDeployment) {
    throw 'Live deployment creates billable Standard v2 and Premium v2 instances. Rerun with -ConfirmDeployment after reviewing What-If.'
}

$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) {
    throw 'No Azure CLI session was found. Run az login and retry.'
}

az account set --subscription $SubscriptionId
if ($LASTEXITCODE -ne 0) {
    throw "Unable to select subscription $SubscriptionId."
}

$providers = @('Microsoft.ApiManagement', 'Microsoft.Network', 'Microsoft.Web')
foreach ($provider in $providers) {
    $state = az provider show --namespace $provider --query registrationState --output tsv
    if ($state -ne 'Registered') {
        Write-Host "Registering $provider..."
        az provider register --namespace $provider --wait
        if ($LASTEXITCODE -ne 0) {
            throw "Provider registration failed for $provider."
        }
    }
}

$commonArguments = @(
    '--name', $DeploymentName,
    '--location', $Location,
    '--template-file', $templateFile,
    '--parameters', $parameterFile
)

switch ($Mode) {
    'Validate' {
        az deployment sub validate @commonArguments --output table
    }
    'WhatIf' {
        az deployment sub what-if @commonArguments --result-format FullResourcePayloads
    }
    'Deploy' {
        az deployment sub create @commonArguments --output json
    }
}

if ($LASTEXITCODE -ne 0) {
    throw "Azure deployment $Mode failed."
}

if ($Mode -eq 'Deploy') {
    Write-Host 'Deployment outputs:'
    az deployment sub show --name $DeploymentName --query properties.outputs --output jsonc
}