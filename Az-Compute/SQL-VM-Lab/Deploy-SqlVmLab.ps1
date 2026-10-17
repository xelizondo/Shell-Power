#Requires -Version 7.2
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [Parameter(Mandatory)]
    [guid] $SubscriptionId,

    [Parameter(Mandatory)]
    [guid] $VaultReaderObjectId,

    [ValidateSet('User', 'ServicePrincipal', 'Group')]
    [string] $VaultReaderPrincipalType = 'User',

    [ValidateSet('Validate', 'Deploy')]
    [string] $Mode = 'Validate',

    [ValidatePattern('^[a-zA-Z0-9._()-]{1,90}$')]
    [string] $ResourceGroupName = 'RG-SQL'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
if (-not $IsWindows) {
    throw 'Run this script in PowerShell 7.2+ on Windows; temporary secret files are protected with Windows ACLs.'
}
Get-Command az -ErrorAction Stop | Out-Null
if ($SubscriptionId -eq [guid]::Empty -or $VaultReaderObjectId -eq [guid]::Empty) {
    throw 'SubscriptionId and VaultReaderObjectId must not be empty GUIDs.'
}
$location = 'canadacentral'
$vmSize = 'Standard_D2alds_v6'
$definitions = @(Get-Content -LiteralPath (Join-Path $PSScriptRoot 'vm-images.json') -Raw | ConvertFrom-Json)

function Invoke-LabAz {
    param([Parameter(Mandatory)][string[]] $Arguments)

    $result = & az @Arguments --subscription $SubscriptionId.ToString() --only-show-errors --output json
    if ($LASTEXITCODE -ne 0) {
        throw "Azure CLI failed (exit $LASTEXITCODE) during '$($Arguments[0]) $($Arguments[1])'. See the CLI error above."
    }
    if ($result) {
        ($result -join "`n") | ConvertFrom-Json
    }
}

function New-LabPassword {
    $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789!@#%+-_'
    do {
        $characters = for ($i = 0; $i -lt 32; $i++) {
            $alphabet[[System.Security.Cryptography.RandomNumberGenerator]::GetInt32($alphabet.Length)]
        }
        $password = -join $characters
    } until ($password -cmatch '[A-Z]' -and $password -cmatch '[a-z]' -and
        $password -match '[0-9]' -and $password -match '[!@#%+_-]')
    $password
}

Write-Host 'Checking provider registrations, regional VM SKU, quotas, and exact Gen2 images. No resources are created.'
foreach ($namespace in @('Microsoft.Compute', 'Microsoft.Network', 'Microsoft.KeyVault', 'Microsoft.RecoveryServices', 'Microsoft.SqlVirtualMachine', 'Microsoft.DevTestLab')) {
    $provider = Invoke-LabAz @('provider', 'show', '--namespace', $namespace)
    if ($provider.registrationState -ne 'Registered') {
        throw "Register $namespace in subscription $SubscriptionId before continuing. No automatic registration is performed."
    }
}

$skus = @(Invoke-LabAz @('vm', 'list-skus', '--location', $location, '--resource-type', 'virtualMachines', '--size', $vmSize, '--all'))
$sku = @($skus | Where-Object name -EQ $vmSize)
if ($sku.Count -ne 1) {
    throw "$vmSize was not found in $location. No alternative size will be selected."
}
$sku = $sku[0]
if (@($sku.restrictions | Where-Object type -EQ 'Location').Count -gt 0) {
    throw "$vmSize has a subscription/location restriction in $location."
}
foreach ($requirement in @{ HyperVGenerations = 'V2'; CpuArchitectureType = 'x64' }.GetEnumerator()) {
    $capability = @($sku.capabilities | Where-Object name -EQ $requirement.Key)
    if ($capability.Count -ne 1 -or $capability[0].value -notmatch $requirement.Value) {
        throw "$vmSize does not advertise the required $($requirement.Key)=$($requirement.Value)."
    }
}

$rgExists = Invoke-LabAz @('group', 'exists', '--name', $ResourceGroupName)
$existingVms = @()
$vaults = @()
if ($rgExists) {
    $existingVms = @(Invoke-LabAz @('vm', 'list', '--resource-group', $ResourceGroupName))
    $vaults = @(Invoke-LabAz @('keyvault', 'list', '--resource-group', $ResourceGroupName) |
        Where-Object name -Like 'kv-sql-*')
}
if ($vaults.Count -gt 1) {
    throw "Multiple kv-sql-* vaults exist in $ResourceGroupName. Resolve the ambiguity before continuing."
}
$existingLabNames = @($existingVms | Where-Object { $_.name -in $definitions.name } | ForEach-Object name)
foreach ($existingVm in $existingVms | Where-Object { $_.name -in $existingLabNames }) {
    if ($existingVm.hardwareProfile.vmSize -ne $vmSize -or $existingVm.location -ne $location) {
        throw "Existing VM $($existingVm.name) does not match the lab size/location. Use a dedicated lab resource group."
    }
}
$newVmCount = @($definitions | Where-Object { $_.name -notin $existingLabNames }).Count
$usages = @(Invoke-LabAz @('vm', 'list-usage', '--location', $location))
foreach ($quotaName in @('cores', $sku.family)) {
    $quota = @($usages | Where-Object { $_.name.value -eq $quotaName })
    if ($quota.Count -ne 1 -or ($quota[0].limit - $quota[0].currentValue) -lt (2 * $newVmCount)) {
        throw "Insufficient or unreported $quotaName quota for $newVmCount new VMs in $location."
    }
}

$versions = @{}
foreach ($definition in $definitions) {
    $version = 'latest'
    $existingVm = @($existingVms | Where-Object name -EQ $definition.name)
    if ($existingVm.Count -eq 1) {
        $reference = $existingVm[0].storageProfile.imageReference
        if ($reference.publisher -ne 'MicrosoftSQLServer' -or
            $reference.offer -ne $definition.offer -or $reference.sku -ne $definition.sku) {
            throw "Existing VM $($definition.name) uses a different image. Use a dedicated lab resource group."
        }
        $version = $reference.version
    }
    $urn = "MicrosoftSQLServer:$($definition.offer):$($definition.sku):$version"
    $image = Invoke-LabAz @('vm', 'image', 'show', '--location', $location, '--urn', $urn)
    if ($image.hyperVGeneration -ne 'V2' -or $image.architecture -ne 'x64' -or $image.osDiskImage.operatingSystem -ne 'Windows') {
        throw "Image $urn is not Windows x64 Gen2."
    }
    if ($image.PSObject.Properties['plan'] -and $image.plan) {
        throw "Image $urn requires a Marketplace purchase plan. Review its terms and add the plan explicitly before deploying."
    }
    $versions[$definition.name] = if ($existingVm.Count -eq 1) { $version } else { $image.name }
    Write-Host "$($definition.name): $urn -> $($image.name)"
}

$passwords = @{}
$availableSecrets = @()
if ($vaults.Count -eq 1) {
    # A failed/forbidden read must stop, not silently replace credentials.
    $availableSecrets = @(Invoke-LabAz @('keyvault', 'secret', 'list', '--vault-name', $vaults[0].name))
}
foreach ($definition in $definitions) {
    $secretName = "$($definition.name)-admin-password"
    if ($secretName -in @($availableSecrets | ForEach-Object name)) {
        $secret = Invoke-LabAz @('keyvault', 'secret', 'show', '--vault-name', $vaults[0].name, '--name', $secretName)
        if ([string]::IsNullOrWhiteSpace($secret.value)) {
            throw "Secret $secretName is empty. Restore the correct password before continuing."
        }
        $passwords[$definition.name] = $secret.value
    } elseif ($definition.name -in $existingLabNames) {
        throw "Existing VM $($definition.name) has no saved password. Restore its Key Vault secret; automatic password reset is not permitted."
    } else {
        $passwords[$definition.name] = New-LabPassword
    }
}

$temporaryDirectory = Join-Path ([System.IO.Path]::GetTempPath()) "sql-vm-lab-$([guid]::NewGuid())"
$parameterFile = Join-Path $temporaryDirectory 'parameters.json'
try {
    [System.IO.Directory]::CreateDirectory($temporaryDirectory) | Out-Null
    $acl = [System.Security.AccessControl.DirectorySecurity]::new()
    $acl.SetAccessRuleProtection($true, $false)
    $sid = [System.Security.Principal.WindowsIdentity]::GetCurrent().User
    $rule = [System.Security.AccessControl.FileSystemAccessRule]::new(
        $sid, 'FullControl', 'ContainerInherit, ObjectInherit', 'None', 'Allow')
    $acl.AddAccessRule($rule)
    [System.IO.FileSystemAclExtensions]::SetAccessControl(
        [System.IO.DirectoryInfo]::new($temporaryDirectory), $acl)

    $parameters = @{
        '$schema' = 'https://schema.management.azure.com/schemas/2019-04-01/deploymentParameters.json#'
        contentVersion = '1.0.0.0'
        parameters = @{
            resourceGroupName = @{ value = $ResourceGroupName }
            location = @{ value = $location }
            vaultReaderObjectId = @{ value = $VaultReaderObjectId.ToString() }
            vaultReaderPrincipalType = @{ value = $VaultReaderPrincipalType }
            adminPasswords = @{ value = $passwords }
            imageVersions = @{ value = $versions }
        }
    }
    $parameters | ConvertTo-Json -Depth 10 | Set-Content -LiteralPath $parameterFile -Encoding utf8
    $deploymentArguments = @(
        '--name', 'sql-vm-lab', '--location', $location,
        '--template-file', (Join-Path $PSScriptRoot 'main.bicep'),
        '--parameters', "@$parameterFile"
    )
    Invoke-LabAz (@('deployment', 'sub', 'validate') + $deploymentArguments) | Out-Null
    Write-Host 'ARM validation succeeded. Review the following What-If before deployment:'
    $preview = Invoke-LabAz (@('deployment', 'sub', 'what-if', '--no-pretty-print') + $deploymentArguments)
    if ($preview.status -ne 'Succeeded') {
        throw "What-If did not succeed: $($preview.status). No deployment will be attempted."
    }
    $preview | ConvertTo-Json -Depth 100 | Write-Host

    if ($Mode -eq 'Deploy' -and $PSCmdlet.ShouldProcess("$SubscriptionId / $ResourceGroupName", 'Create/update the three-VM SQL lab')) {
        $deployment = Invoke-LabAz (@('deployment', 'sub', 'create') + $deploymentArguments)
        if ($deployment.properties.provisioningState -ne 'Succeeded') {
            throw "Deployment did not succeed: $($deployment.properties.provisioningState)."
        }
        foreach ($definition in $definitions) {
            $sqlVm = Invoke-LabAz @('sql', 'vm', 'show', '--resource-group', $ResourceGroupName, '--name', $definition.name)
            if ($sqlVm.provisioningState -ne 'Succeeded') {
                throw "SQL IaaS provisioning did not succeed for $($definition.name)."
            }
            for ($attempt = 1; $attempt -le 12; $attempt++) {
                $extensions = @(Invoke-LabAz @('vm', 'extension', 'list', '--resource-group', $ResourceGroupName, '--vm-name', $definition.name))
                $sqlExtension = @($extensions | Where-Object publisher -EQ 'Microsoft.SqlServer.Management')
                if ($sqlExtension.Count -eq 1 -and $sqlExtension[0].provisioningState -eq 'Succeeded') {
                    break
                }
                if ($sqlExtension.Count -eq 1 -and $sqlExtension[0].provisioningState -eq 'Failed') {
                    throw "SQL IaaS Agent extension failed on $($definition.name)."
                }
                if ($attempt -eq 12) {
                    throw "SQL IaaS Agent extension is missing or not successful on $($definition.name) after 12 checks."
                }
                Write-Host "Waiting for SQL IaaS Agent extension state on $($definition.name) (attempt $attempt/12)."
                Start-Sleep -Seconds 10
            }
        }
        $deployment.properties.outputs | ConvertTo-Json -Depth 10
        Write-Host 'Deployment and SQL IaaS extension provisioning verified. Run the guest and connectivity checks in README.md.'
    } else {
        Write-Host 'No resources deployed. Validate is the default mode; Deploy requires explicit confirmation.'
    }
} finally {
    if (Test-Path -LiteralPath $parameterFile) {
        Remove-Item -LiteralPath $parameterFile -Force
    }
    if (Test-Path -LiteralPath $temporaryDirectory) {
        Remove-Item -LiteralPath $temporaryDirectory
    }
    $passwords.Clear()
    $parameters = $null
    $secret = $null
}
