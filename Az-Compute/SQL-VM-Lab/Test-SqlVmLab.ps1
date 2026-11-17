#Requires -Version 7.2
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Lab {
    param([bool] $Condition, [string] $Message)
    if (-not $Condition) { throw "FAILED: $Message" }
}

$compiled = & az bicep build --file (Join-Path $PSScriptRoot 'main.bicep') --stdout
if ($LASTEXITCODE -ne 0) { throw 'Bicep compilation failed.' }
$template = ($compiled -join "`n") | ConvertFrom-Json -AsHashtable
Assert-Lab ($template.parameters.adminPasswords.type -eq 'secureObject') 'Passwords must be secure at subscription scope.'
$labTemplate = $template.resources[1].properties.template
Assert-Lab ($labTemplate.parameters.adminPasswords.type -eq 'secureObject') 'Passwords must remain secure at resource-group scope.'
$labResources = @($labTemplate.resources)
$storageAccounts = @($labResources | Where-Object type -EQ 'Microsoft.Storage/storageAccounts')
Assert-Lab ($storageAccounts.Count -eq 1) 'Exactly one SQL backup storage account is required.'
$storage = $storageAccounts[0]
Assert-Lab ($storage.name -eq "[format('sqlbackup{0}', uniqueString(resourceGroup().id))]") 'Storage name must use sqlbackup plus a stable unique suffix.'
Assert-Lab ($storage.location -eq '[parameters(''location'')]' -and $storage.kind -eq 'StorageV2') 'Storage must use the lab region and StorageV2 kind.'
Assert-Lab ($storage.sku.name -eq 'Standard_RAGRS') 'Storage must use Standard RA-GRS.'
Assert-Lab ($storage.properties.accessTier -eq 'Hot' -and $storage.properties.isHnsEnabled -eq $false) 'Storage must use Hot tier without hierarchical namespace.'
Assert-Lab ($storage.properties.allowBlobPublicAccess -eq $false -and $storage.properties.allowSharedKeyAccess -eq $true) 'Anonymous access must be disabled while Shared Key SAS remains available.'
Assert-Lab ($storage.properties.supportsHttpsTrafficOnly -eq $true -and $storage.properties.minimumTlsVersion -eq 'TLS1_2') 'Storage must require HTTPS and TLS 1.2.'
Assert-Lab ($storage.properties.publicNetworkAccess -eq 'Enabled' -and
    $storage.properties.networkAcls.defaultAction -eq 'Allow' -and
    $storage.properties.networkAcls.ipRules.Count -eq 0 -and
    $storage.properties.networkAcls.virtualNetworkRules.Count -eq 0) 'Storage must allow authenticated access from all networks.'
Assert-Lab ($storage.properties.routingPreference.routingChoice -eq 'MicrosoftRouting' -and
    $storage.properties.routingPreference.publishMicrosoftEndpoints -eq $true -and
    $storage.properties.routingPreference.publishInternetEndpoints -eq $false) 'Storage must use Microsoft network routing.'
$blobService = @($labResources | Where-Object type -EQ 'Microsoft.Storage/storageAccounts/blobServices')[0]
Assert-Lab ($blobService.properties.containerDeleteRetentionPolicy.enabled -eq $false -and
    $blobService.properties.deleteRetentionPolicy.enabled -eq $false -and
    $blobService.properties.isVersioningEnabled -eq $false) 'Container soft delete, blob soft delete, and versioning must be disabled.'
$container = @($labResources | Where-Object type -EQ 'Microsoft.Storage/storageAccounts/blobServices/containers')[0]
Assert-Lab ($container.name -like '*sqlbackups*' -and $container.properties.publicAccess -eq 'None') 'The sqlbackups container must be private.'
foreach ($outputName in @('backupStorageAccountName', 'backupContainerName', 'backupContainerUrl')) {
    Assert-Lab ($labTemplate.outputs.ContainsKey($outputName) -and $template.outputs.ContainsKey($outputName)) "Storage output $outputName must be exposed by both templates."
}
$vault = @($labResources | Where-Object type -EQ 'Microsoft.RecoveryServices/vaults')[0]
Assert-Lab ($vault.properties.redundancySettings.standardTierStorageRedundancy -eq 'GeoRedundant') 'Recovery vault must use GRS.'
Assert-Lab ($vault.properties.redundancySettings.crossRegionRestore -eq 'Disabled') 'The redundancy settings must explicitly leave cross-region restore disabled.'
$nsg = @($labResources | Where-Object type -EQ 'Microsoft.Network/networkSecurityGroups')[0]
Assert-Lab ($nsg.properties.securityRules.Count -eq 2) 'Only the RDP allow and catch-all deny rules are expected.'
Assert-Lab ($nsg.properties.securityRules[0].properties.destinationPortRange -eq '3389') 'Only RDP is allowed.'
Assert-Lab ($nsg.properties.securityRules[1].properties.access -eq 'Deny') 'Default VNet inbound must not bypass the restriction.'
$vmTemplate = @($labResources | Where-Object type -EQ 'Microsoft.Resources/deployments')[0].properties.template
Assert-Lab ($vmTemplate.parameters.adminPassword.type -eq 'secureString') 'VM module password must be secure.'
$vmResources = @($vmTemplate.resources)
$sqlVm = @($vmResources | Where-Object type -EQ 'Microsoft.SqlVirtualMachine/sqlVirtualMachines')[0]
Assert-Lab ($sqlVm.properties.storageConfigurationSettings.sqlTempDbSettings.luns[0] -eq
    $sqlVm.properties.storageConfigurationSettings.sqlDataSettings.luns[0]) 'TempDB and data on the same drive must use identical LUNs.'
$vm = @($vmResources | Where-Object type -EQ 'Microsoft.Compute/virtualMachines')[0]
Assert-Lab ($vm.properties.hardwareProfile.vmSize -eq 'Standard_D2alds_v6') 'VM size must match the request.'
Assert-Lab ($vm.properties.licenseType -eq 'Windows_Server') 'Windows Hybrid Benefit is required.'
Assert-Lab ($vm.properties.storageProfile.osDisk.managedDisk.storageAccountType -eq 'StandardSSD_LRS') 'OS disk must be Standard SSD LRS.'
Assert-Lab ($vm.properties.storageProfile.dataDisks.Count -eq 2) 'Each VM needs separate data and log disks.'
foreach ($disk in $vm.properties.storageProfile.dataDisks) {
    Assert-Lab ($disk.diskSizeGB -eq 64 -and $disk.managedDisk.storageAccountType -eq 'StandardSSD_LRS') 'SQL disks must be 64-GiB Standard SSD LRS.'
}
$schedule = @($vmResources | Where-Object type -EQ 'Microsoft.DevTestLab/schedules')[0]
Assert-Lab ($schedule.properties.dailyRecurrence.time -eq '1900') 'Shutdown must be at 19:00.'
Assert-Lab ($schedule.properties.timeZoneId -eq 'Eastern Standard Time') 'Shutdown must follow Toronto DST.'
$definitions = @(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'vm-images.json') -Raw | ConvertFrom-Json)
Assert-Lab ($definitions.Count -eq 3) 'Exactly three VMs are required.'
Assert-Lab ($definitions[1].offer -eq 'sql2022-ws2022') 'SQL2022 must use the corrected SQL Server 2022 image.'
Assert-Lab ($definitions[2].edition -eq 'Developer' -and $definitions[2].licenseType -eq 'PAYG') 'SQL2017 must retain free Developer edition registration.'
Write-Host 'PASS: compiled template requirements'

if (Get-Variable SqlVmLabTestState -Scope Global -ErrorAction SilentlyContinue) {
    throw 'SqlVmLabTestState already exists; run the checks in a fresh PowerShell process.'
}
$global:SqlVmLabTestState = @{}
function az {
    $arguments = @($args)
    $global:LASTEXITCODE = 0
    $command = ($arguments[0..1] -join ' ')
    $result = switch ($command) {
        'provider show' { @{ registrationState = 'Registered' }; break }
        'vm list-skus' {
            @{
                name = 'Standard_D2alds_v6'
                family = 'standardDaldsv6Family'
                restrictions = @(if ($global:SqlVmLabTestState.Restricted) { @{ type = 'Location' } })
                capabilities = @(
                    @{ name = 'HyperVGenerations'; value = 'V2' }
                    @{ name = 'CpuArchitectureType'; value = 'x64' }
                )
            }; break
        }
        'group exists' { $global:SqlVmLabTestState.Existing; break }
        'vm list' {
            if ($global:SqlVmLabTestState.Existing) {
                @{
                    name = 'SQL2025'
                    location = 'canadacentral'
                    hardwareProfile = @{ vmSize = 'Standard_D2alds_v6' }
                    storageProfile = @{
                        imageReference = @{
                            publisher = 'MicrosoftSQLServer'
                            offer = 'sql2025-ws2025'
                            sku = 'enterprise-gen2'
                            version = '1.0.0'
                        }
                    }
                }
            }; break
        }
        'vm list-usage' {
            foreach ($name in @('cores', 'standardDaldsv6Family')) {
                @{ name = @{ value = $name }; currentValue = 0; limit = $global:SqlVmLabTestState.Quota }
            }; break
        }
        'vm image' {
            Assert-Lab ($arguments[2] -eq 'show') 'Only image metadata reads are expected.'
            $image = @{ name = '1.0.0'; architecture = 'x64'; hyperVGeneration = $global:SqlVmLabTestState.Generation; osDiskImage = @{ operatingSystem = 'Windows' } }
            if ($global:SqlVmLabTestState.PurchasePlan) {
                $image.plan = @{ name = 'requires-terms' }
            }
            $image
            break
        }
        'keyvault list' { @{ name = 'kv-sql-test' }; break }
        'keyvault secret' {
            if ($global:SqlVmLabTestState.DenySecrets) {
                $global:LASTEXITCODE = 1
                break
            }
            if ($arguments[2] -eq 'list') {
                if (-not $global:SqlVmLabTestState.MissingSecret) { @{ name = 'SQL2025-admin-password' } }
            } elseif ($arguments[2] -eq 'show') {
                @{ value = 'PreviouslySaved1!Password' }
            } else {
                throw 'Unexpected secret operation.'
            }
            break
        }
        'deployment sub' {
            $path = $arguments[[array]::IndexOf($arguments, '--parameters') + 1].Substring(1)
            $global:SqlVmLabTestState.ParameterPath = $path
            $parameters = Get-Content -LiteralPath $path -Raw | ConvertFrom-Json
            $rules = (Get-Acl -LiteralPath (Split-Path $path)).Access
            Assert-Lab (@($rules).Count -eq 1 -and -not $rules[0].IsInherited) 'Only the current owner may access the temporary parameter directory.'
            Assert-Lab (@($parameters.parameters.adminPasswords.value.PSObject.Properties).Count -eq 3) 'All three VM passwords must be supplied.'
            if ($global:SqlVmLabTestState.Existing) {
                Assert-Lab ($parameters.parameters.adminPasswords.value.SQL2025 -eq 'PreviouslySaved1!Password') 'Existing passwords must be reused.'
                Assert-Lab ($parameters.parameters.imageVersions.value.SQL2025 -eq '1.0.0') 'Existing VM image reference must be retained.'
            } else {
                $values = @($parameters.parameters.adminPasswords.value.PSObject.Properties.Value)
                Assert-Lab (@($values | Select-Object -Unique).Count -eq 3) 'Generated passwords must be distinct.'
                foreach ($value in $values) {
                    Assert-Lab ($value.Length -eq 32 -and $value -cmatch '[A-Z]' -and
                        $value -cmatch '[a-z]' -and $value -match '[0-9]' -and
                        $value -match '[!@#%+_-]') 'Generated passwords must meet complexity requirements.'
                }
            }
            switch ($arguments[2]) {
                'validate' { @{ properties = @{ provisioningState = 'Succeeded' } } }
                'what-if' {
                    if ($global:SqlVmLabTestState.FailPreview) { throw 'Simulated What-If failure.' }
                    @{ status = $global:SqlVmLabTestState.PreviewStatus; changes = @() }
                }
                'create' {
                    $global:SqlVmLabTestState.Creates++
                    @{ properties = @{ provisioningState = 'Succeeded'; outputs = @{ keyVaultName = @{ value = 'kv-sql-test' } } } }
                }
                default { throw 'Unexpected deployment operation.' }
            }
            break
        }
        'sql vm' { @{ provisioningState = 'Succeeded' }; break }
        'vm extension' {
            $global:SqlVmLabTestState.ExtensionChecks++
            $provisioningState = if ($global:SqlVmLabTestState.FailExtension) { 'Failed' }
                elseif ($global:SqlVmLabTestState.ExtensionChecks -le $global:SqlVmLabTestState.ExtensionDelay) { 'Updating' }
                else { 'Succeeded' }
            @{ publisher = 'Microsoft.SqlServer.Management'; provisioningState = $provisioningState }
            break
        }
        default { throw "Unexpected mocked CLI command: $command" }
    }
    # Azure CLI list commands always return arrays, including empty/single-item results.
    if ($command -in @('vm list-skus', 'vm list', 'vm list-usage', 'keyvault list', 'vm extension') -or
        ($command -eq 'keyvault secret' -and $arguments[2] -eq 'list')) {
        ConvertTo-Json -InputObject @($result) -Depth 20 -Compress
    } elseif ($null -ne $result) {
        ConvertTo-Json -InputObject $result -Depth 20 -Compress
    }
}

function Start-Sleep {
    param([int] $Seconds)
    Assert-Lab ($Seconds -eq 10) 'Extension verification must use a bounded polling interval.'
}

function Invoke-Scenario {
    param(
        [string] $Name,
        [hashtable] $Overrides = @{},
        [string] $Mode = 'Validate',
        [string] $ExpectedError = ''
    )
    $global:SqlVmLabTestState = @{
        Existing = $false; MissingSecret = $false; DenySecrets = $false
        FailPreview = $false; Quota = 100; Creates = 0; ParameterPath = $null
        Restricted = $false; Generation = 'V2'; PreviewStatus = 'Succeeded'
        PurchasePlan = $false
        ExtensionChecks = 0; ExtensionDelay = 0; FailExtension = $false
    }
    foreach ($key in $Overrides.Keys) { $global:SqlVmLabTestState[$key] = $Overrides[$key] }
    $failure = $null
    try {
        & (Join-Path $PSScriptRoot 'Deploy-SqlVmLab.ps1') `
            -SubscriptionId '11111111-1111-1111-1111-111111111111' `
            -VaultReaderObjectId '22222222-2222-2222-2222-222222222222' `
            -Mode $Mode -Confirm:$false 6>$null | Out-Null
    } catch {
        $failure = $_
    }
    if ($ExpectedError) {
        Assert-Lab ($null -ne $failure -and $failure.Exception.Message -like "*$ExpectedError*") "$Name must fail with '$ExpectedError'; actual: $failure"
    } elseif ($failure) {
        throw $failure
    }
    $expectedCreates = [int]($Mode -eq 'Deploy' -and (-not $ExpectedError -or $global:SqlVmLabTestState.FailExtension))
    Assert-Lab ($global:SqlVmLabTestState.Creates -eq $expectedCreates) "$Name must not create resources unexpectedly."
    if ($global:SqlVmLabTestState.ParameterPath) {
        Assert-Lab (-not (Test-Path -LiteralPath (Split-Path $global:SqlVmLabTestState.ParameterPath))) "$Name must remove its temporary credentials."
    }
    Write-Host "PASS: $Name"
}

try {
    Invoke-Scenario 'Fresh validation is read-only and passwords are strong'
    Invoke-Scenario 'Explicit deployment verifies SQL extensions' -Mode Deploy
    Invoke-Scenario 'Transient SQL extension states are retried' -Mode Deploy -Overrides @{ ExtensionDelay = 2 }
    Invoke-Scenario 'Failed SQL extensions fail explicitly' -Mode Deploy -Overrides @{ FailExtension = $true } -ExpectedError 'SQL IaaS Agent extension failed'
    Invoke-Scenario 'Redeployment preserves saved credentials' -Overrides @{ Existing = $true }
    Invoke-Scenario 'Missing saved credentials fail closed' -Overrides @{ Existing = $true; MissingSecret = $true } -ExpectedError 'no saved password'
    Invoke-Scenario 'Vault access errors do not reset passwords' -Overrides @{ Existing = $true; DenySecrets = $true } -ExpectedError 'Azure CLI failed'
    Invoke-Scenario 'Insufficient quota stops preflight' -Overrides @{ Quota = 4 } -ExpectedError 'quota'
    Invoke-Scenario 'Restricted VM SKU stops preflight' -Overrides @{ Restricted = $true } -ExpectedError 'subscription/location restriction'
    Invoke-Scenario 'Gen1 images are rejected' -Overrides @{ Generation = 'V1' } -ExpectedError 'not Windows x64 Gen2'
    Invoke-Scenario 'Purchase plans require explicit handling' -Overrides @{ PurchasePlan = $true } -ExpectedError 'requires a Marketplace purchase plan'
    Invoke-Scenario 'Unsuccessful What-If prevents deployment' -Overrides @{ PreviewStatus = 'Failed' } -ExpectedError 'What-If did not succeed'
    Invoke-Scenario 'What-If failure removes temporary secrets' -Overrides @{ FailPreview = $true } -ExpectedError 'Simulated What-If failure'
} finally {
    Remove-Item Function:\az
    Remove-Item Function:\Start-Sleep
    Remove-Variable SqlVmLabTestState -Scope Global
}
