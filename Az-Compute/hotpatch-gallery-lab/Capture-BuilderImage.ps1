<#
.SYNOPSIS
    Sysprep-generalizes the builder VM and captures it into the lab's Azure Compute Gallery.

.DESCRIPTION
    Mirrors what a Packer azure-arm builder does at the end of a run
    (sysprep /generalize /oobe /shutdown -> deallocate -> generalize -> capture),
    so the resulting image version is representative of a Packer output.

.NOTES
    Run after main.bicep has deployed. Requires Az CLI logged in to the right subscription.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ResourceGroupName,
    [Parameter(Mandatory)] [string] $GalleryName,
    [string] $BuilderVmName = 'hplab-builder',
    [string] $ImageDefinitionName = 'ws2025-azureedition-custom',
    [string] $ImageVersion = '1.0.0'
)

$ErrorActionPreference = 'Stop'

$sysprepCommand = @'
Start-Process -FilePath "$env:SystemRoot\System32\Sysprep\Sysprep.exe" `
    -ArgumentList '/generalize','/oobe','/shutdown','/quiet','/mode:vm' -NoNewWindow
'@

Write-Host "Running sysprep on $BuilderVmName (VM will shut down; the run-command may report a failure - that is expected)..." -ForegroundColor Cyan
az vm run-command invoke `
    --resource-group $ResourceGroupName `
    --name $BuilderVmName `
    --command-id RunPowerShellScript `
    --scripts $sysprepCommand | Out-Null

Write-Host 'Waiting for the VM to power off...' -ForegroundColor Cyan
do {
    Start-Sleep -Seconds 20
    $power = az vm get-instance-view -g $ResourceGroupName -n $BuilderVmName `
        --query "instanceView.statuses[?starts_with(code,'PowerState')].code | [0]" -o tsv
    Write-Host "  power state: $power"
} while ($power -ne 'PowerState/stopped')

Write-Host 'Deallocating and generalizing...' -ForegroundColor Cyan
az vm deallocate -g $ResourceGroupName -n $BuilderVmName | Out-Null
az vm generalize  -g $ResourceGroupName -n $BuilderVmName | Out-Null

$vmId = az vm show -g $ResourceGroupName -n $BuilderVmName --query id -o tsv

Write-Host "Capturing image version $ImageVersion into $GalleryName/$ImageDefinitionName..." -ForegroundColor Cyan
az sig image-version create `
    --resource-group $ResourceGroupName `
    --gallery-name $GalleryName `
    --gallery-image-definition $ImageDefinitionName `
    --gallery-image-version $ImageVersion `
    --virtual-machine $vmId `
    --replica-count 1 | Out-Null

$versionId = az sig image-version show `
    --resource-group $ResourceGroupName `
    --gallery-name $GalleryName `
    --gallery-image-definition $ImageDefinitionName `
    --gallery-image-version $ImageVersion `
    --query id -o tsv

Write-Host ''
Write-Host 'Captured image version resource ID:' -ForegroundColor Green
Write-Host $versionId
Write-Host ''
Write-Host 'Next: deploy stage 2 with this ID' -ForegroundColor Yellow
Write-Host "  az deployment group create -g $ResourceGroupName -f vm-from-gallery.bicep -p galleryImageVersionId='$versionId' adminUsername=<user> adminPassword=<pwd>"
