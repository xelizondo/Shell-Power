<#
.SYNOPSIS
    Compares hotpatch state between the marketplace control VM and the gallery-image test VM.

.DESCRIPTION
    Two layers are checked, because they can disagree:

      1. CONTROL PLANE - does Azure treat the VM as hotpatch-capable?
         This is the layer the docs say custom images fail. Checked via ARM
         patchSettings and the VM instance view patch status.

      2. GUEST OS      - did the sysprep/capture cycle preserve the OS-side
         hotpatch artifacts (VBS running, HotPatchTableSize, Hotpatch.amd64
         enrollment package, Azure Edition SKU)?

    A "PASS" on layer 2 with a "FAIL" on layer 1 is the expected outcome for the
    gallery image, and is exactly why the scenario is unsupported: the bits are
    there but nothing orchestrates them.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string] $ResourceGroupName,
    [string[]] $VmNames = @('hplab-control', 'hplab-test')
)

$ErrorActionPreference = 'Stop'

$guestProbe = @'
$vbs = Get-CimInstance -Namespace root\Microsoft\Windows\DeviceGuard -ClassName Win32_DeviceGuard -ErrorAction SilentlyContinue
$tbl = Get-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' -Name HotPatchTableSize -ErrorAction SilentlyContinue
$enr = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Update\TargetingInfo\DynamicInstalled\Hotpatch.amd64' -ErrorAction SilentlyContinue

[pscustomobject]@{
    OsName                 = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').ProductName
    OsBuild                = "$([Environment]::OSVersion.Version.Build).$((Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').UBR)"
    EditionId              = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion').EditionID
    VbsStatus              = $vbs.VirtualizationBasedSecurityStatus   # 2 = running
    SecurityServicesRunning= ($vbs.SecurityServicesRunning -join ',')
    HotPatchTableSize      = $tbl.HotPatchTableSize
    HotpatchEnrollment     = $enr.Name
    HotpatchEnrollVersion  = $enr.Version
    LastBaselineOrHotfix   = (Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 1 -ExpandProperty HotFixID)
} | ConvertTo-Json -Compress
'@

foreach ($vm in $VmNames) {
    Write-Host ("=" * 78) -ForegroundColor DarkGray
    Write-Host "VM: $vm" -ForegroundColor Cyan
    Write-Host ("=" * 78) -ForegroundColor DarkGray

    $arm = az vm show -g $ResourceGroupName -n $vm -o json 2>$null | ConvertFrom-Json
    if (-not $arm) { Write-Warning "VM '$vm' not found - skipping."; continue }

    $img = $arm.storageProfile.imageReference
    $ps = $arm.osProfile.windowsConfiguration.patchSettings

    Write-Host '--- Control plane ---' -ForegroundColor Yellow
    [pscustomobject]@{
        ImageSource       = if ($img.id) { 'Gallery/custom' } else { 'Marketplace' }
        Publisher         = $img.publisher
        Offer             = $img.offer
        Sku               = $img.sku
        ImageId           = $img.id
        PatchMode         = $ps.patchMode
        AssessmentMode    = $ps.assessmentMode
        EnableHotpatching = $ps.enableHotpatching
    } | Format-List

    Write-Host '--- Instance view patch status ---' -ForegroundColor Yellow
    az vm get-instance-view -g $ResourceGroupName -n $vm --query 'instanceView.patchStatus' -o jsonc

    Write-Host '--- Guest OS probe ---' -ForegroundColor Yellow
    $raw = az vm run-command invoke -g $ResourceGroupName -n $vm `
        --command-id RunPowerShellScript --scripts $guestProbe `
        --query 'value[0].message' -o tsv 2>$null

    if ($raw -match '(?s)\{.*\}') {
        ($Matches[0] | ConvertFrom-Json) | Format-List
    }
    else {
        Write-Warning 'Guest probe returned no parsable output.'
        Write-Host $raw
    }

    Write-Host '--- On-demand patch assessment (authoritative hotpatch signal) ---' -ForegroundColor Yellow
    az vm assess-patches -g $ResourceGroupName -n $vm `
        --query '{status:status, rebootPending:rebootPending, critical:criticalAndSecurityPatchCount, other:otherPatchCount, error:error}' -o jsonc
    Write-Host ''
}

Write-Host 'Interpretation:' -ForegroundColor Green
Write-Host '  control VM  -> enableHotpatching:true AND Azure Update Manager shows Hotpatch enabled.'
Write-Host '  test VM     -> guest artifacts may survive, but the control plane will not treat it'
Write-Host '                 as hotpatch-capable because imageReference has no publisher/offer/sku.'
