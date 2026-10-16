[CmdletBinding()]
param(
    [string]$ResourceGroupName = 'rg-apim-v2-network-lab'
)

$ErrorActionPreference = 'Stop'

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    throw 'Azure CLI is required to discover the API Management instance names.'
}

$instances = @(az apim list --resource-group $ResourceGroupName --query "[].{name:name,sku:sku.name,publicNetworkAccess:publicNetworkAccess,virtualNetworkType:virtualNetworkType}" --output json | ConvertFrom-Json)
if ($LASTEXITCODE -ne 0 -or $instances.Count -eq 0) {
    throw "No API Management instances were found in $ResourceGroupName."
}

$results = foreach ($instance in $instances) {
    $hostName = "$($instance.name).azure-api.net"
    $addresses = @()
    $dnsError = $null
    $httpStatus = $null
    $httpError = $null

    try {
        $addresses = @([System.Net.Dns]::GetHostAddresses($hostName) | ForEach-Object IPAddressToString)
    }
    catch {
        $dnsError = $_.Exception.Message
    }

    $tcpSucceeded = if ($addresses.Count -gt 0) {
        Test-NetConnection -ComputerName $hostName -Port 443 -InformationLevel Quiet
    }
    else {
        $false
    }

    if ($tcpSucceeded) {
        try {
            $response = Invoke-WebRequest -Uri "https://$hostName/status-0123456789abcdef" -UseBasicParsing -TimeoutSec 30
            $httpStatus = [int]$response.StatusCode
        }
        catch {
            if ($_.Exception.Response) {
                $httpStatus = [int]$_.Exception.Response.StatusCode
            }
            else {
                $httpError = $_.Exception.Message
            }
        }
    }

    [pscustomobject]@{
        Name                = $instance.name
        Sku                 = $instance.sku
        VirtualNetworkType  = $instance.virtualNetworkType
        PublicNetworkAccess = $instance.publicNetworkAccess
        HostName            = $hostName
        ResolvedAddresses   = $addresses -join ', '
        ResolvesPrivately   = ($addresses | Where-Object { $_ -match '^(10\.|172\.(1[6-9]|2[0-9]|3[01])\.|192\.168\.)' }).Count -gt 0
        Tcp443              = $tcpSucceeded
        HttpStatus          = $httpStatus
        Error               = @($dnsError, $httpError | Where-Object { $_ }) -join '; '
    }
}

$results | Format-Table -AutoSize

if ($results.ResolvesPrivately -contains $false -or $results.Tcp443 -contains $false) {
    Write-Warning 'At least one gateway did not resolve to a private address or accept TCP/443. Run this test from a client connected to the lab VNet and check the private DNS link.'
}