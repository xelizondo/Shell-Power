# Hotpatch Retention Lab — Azure Compute Gallery vs. Marketplace

Validates whether a Windows Server 2025 Datacenter: Azure Edition image captured into an
Azure Compute Gallery (after Packer + sysprep) retains hotpatching capability.

## Answer up front

**No — it is not supported.**

- [Hotpatch for Windows Server — Supported platforms](https://learn.microsoft.com/windows-server/get-started/hotpatch#supported-platforms):
  > The following table lists the **exact combinations of publisher, OS offer, and SKU** that support Hotpatching…
  > **Note:** Windows Server container base images, **custom images**, or any other combination of publisher, offer, and SKU **aren't supported**.
- [Automatic VM Guest Patching — Supported OS images](https://learn.microsoft.com/azure/virtual-machines/automatic-vm-guest-patching#supported-os-images):
  > …supported **only on VMs created from images with the exact combination of publisher, offer and sku**… **Custom images** or any other publisher, offer, sku combinations **aren't supported**.

**Why it breaks mechanically:** platform hotpatch/AutoPatch orchestration keys off
`properties.storageProfile.imageReference.{publisher,offer,sku}`. A gallery image sets
`imageReference.id` instead, so those fields are absent and the VM never matches the
supported-image list — `enableHotpatching` is not honored even when the OS-side artifacts
(VBS, `HotPatchTableSize`, `Hotpatch.amd64` enrollment) survived sysprep.

**Supported alternatives**

- Deploy from the marketplace SKU and customize post-deploy (DSC / Custom Script Extension / Ansible / AUM configuration).
- Use [Hotpatch enabled by Azure Arc](https://learn.microsoft.com/windows-server/get-started/enable-hotpatch-azure-arc-enabled-servers) for WS2025 Standard/Datacenter — that path is OS-edition-based rather than image-SKU-based, but it targets Arc-connected machines, not Azure VMs.

This lab exists to prove the behavior empirically in your own subscription.

## Contents

| File | Purpose |
| --- | --- |
| `main.bicep` | Stage 1 — VNet/NSG, Compute Gallery + Gen2 / `TrustedLaunchSupported` image definition, **control VM** (marketplace SKU) and **builder VM** to be sysprepped |
| `Capture-BuilderImage.ps1` | Sysprep → deallocate → generalize → capture image version (mirrors the tail end of a Packer `azure-arm` build) |
| `vm-from-gallery.bicep` | Stage 2 — **test VM** from the captured image version, requesting `enableHotpatching: true`; outputs what ARM actually persisted |
| `Test-HotpatchState.ps1` | Side-by-side comparison of control-plane state vs. guest OS state across both VMs |

## Prerequisites

- Azure CLI logged in to the target subscription (`az login`, `az account set -s <sub>`).
- Bicep CLI (`az bicep install`).
- Contributor on the target subscription or resource group.
- A VM size that supports Trusted Launch (default `Standard_D2s_v5`) with available quota.
- Your egress public IP, for the RDP NSG rule.

## Run it

### 0. Resource group

```powershell
$rg = 'rg-hotpatch-lab'
az group create -n $rg -l centralus
```

### 1. Deploy the baseline (control + builder VMs, gallery, image definition)

```powershell
$myIp = (Invoke-RestMethod 'https://api.ipify.org')

az deployment group create `
  -g $rg `
  -f main.bicep `
  -p allowedRdpSourcePrefix="$myIp/32" `
     adminUsername='azureuser' `
     adminPassword='<StrongPassword>'
```

Capture the outputs:

```powershell
$galleryName = az deployment group show -g $rg -n main --query properties.outputs.galleryName.value -o tsv
$galleryName
```

Let the control VM sit for a few minutes so the VM agent reports in.

### 2. Confirm the control VM is genuinely hotpatch-enabled

Establish the baseline *before* touching the custom image, so you know a "fail" later is
meaningful and not an environment problem.

```powershell
.\Test-HotpatchState.ps1 -ResourceGroupName $rg -VmNames 'hplab-control'
```

Expected on the control VM:

- `EnableHotpatching : True`
- Portal → VM → **Updates** shows hotpatch as enabled / applicable.
- Guest probe shows `VbsStatus = 2` (running) and a populated `HotPatchTableSize` / `HotpatchEnrollment`.

### 3. Sysprep and capture the builder VM

```powershell
.\Capture-BuilderImage.ps1 `
  -ResourceGroupName $rg `
  -GalleryName $galleryName `
  -BuilderVmName 'hplab-builder' `
  -ImageVersion '1.0.0'
```

The script prints the captured image version resource ID. Note the run-command that triggers
sysprep may report a failure — that is expected, since the VM shuts itself down mid-call.

```powershell
$imgVersionId = '<paste the printed resource ID>'
```

### 4. Deploy the test VM from the gallery image

```powershell
az deployment group create `
  -g $rg `
  -f vm-from-gallery.bicep `
  -p galleryImageVersionId="$imgVersionId" `
     adminUsername='azureuser' `
     adminPassword='<StrongPassword>'
```

Check what the platform actually persisted versus what you requested:

```powershell
az deployment group show -g $rg -n vm-from-gallery `
  --query properties.outputs.persistedEnableHotpatching.value
```

If the deployment is rejected outright, that is itself a conclusive result — record the
error code and stop.

### 5. Compare control vs. test

```powershell
.\Test-HotpatchState.ps1 -ResourceGroupName $rg
```

## How to read the results

Two layers are checked, and they can legitimately disagree:

| Layer | What it tells you |
| --- | --- |
| **Control plane** — ARM `patchSettings`, instance-view `patchStatus`, `az vm assess-patches` | Whether Azure treats the VM as hotpatch-capable and will orchestrate hotpatch delivery |
| **Guest OS** — `Win32_DeviceGuard`, `HotPatchTableSize`, `Hotpatch.amd64` enrollment key, `EditionID` | Whether the sysprep/capture cycle preserved the OS-side hotpatch machinery |

| Outcome | Meaning |
| --- | --- |
| Control plane PASS + guest PASS | Hotpatching works (expected only on the marketplace control VM) |
| Control plane FAIL + guest PASS | **The expected result for the gallery image.** The bits are present but nothing orchestrates them — this is the trap |
| Deployment rejected | Even stronger confirmation; the platform refuses `enableHotpatching` on a custom image |

### The trap, restated

A smoke test on day 1 will not reveal the problem. The test VM boots, looks like Azure
Edition, and reports VBS running. The divergence only becomes visible in the next hotpatch
month, when the VM receives a full cumulative update requiring a reboot instead of a
reboot-free hotpatch. If you are relying on this for a maintenance-window SLA, that
discovery arrives at the worst possible time.

### Optional: isolate whether the request itself is rejected

Redeploy stage 2 with `requestHotpatching=false` to confirm the VM deploys fine without the
hotpatch request, which distinguishes "hotpatch request rejected" from "gallery image broken
for unrelated reasons".

```powershell
az deployment group create -g $rg -f vm-from-gallery.bicep `
  -p galleryImageVersionId="$imgVersionId" requestHotpatching=false `
     adminUsername='azureuser' adminPassword='<StrongPassword>'
```

### Longitudinal check (the only fully conclusive test)

Leave both VMs running across a hotpatch month per the
[Windows Server hotpatch calendar](https://learn.microsoft.com/windows/release-health/windows-server-release-info#windows-server-hotpatch-calendar),
then compare update history:

```powershell
az vm run-command invoke -g $rg -n hplab-control --command-id RunPowerShellScript `
  --scripts "Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 5 | Format-Table"
az vm run-command invoke -g $rg -n hplab-test --command-id RunPowerShellScript `
  --scripts "Get-HotFix | Sort-Object InstalledOn -Descending | Select-Object -First 5 | Format-Table"
```

The control VM should show a hotpatch KB with no reboot; the test VM should show a full
cumulative update.

## Notes and caveats

- **Trusted Launch is mandatory.** Hotpatch depends on VBS, which needs Secure Boot + vTPM. The image definition uses `hyperVGeneration: V2` and the `SecurityType = TrustedLaunchSupported` feature for this reason.
- **Licensing.** Windows Server Datacenter: Azure Edition is licensed through specific channels. Capturing and redeploying a marketplace Windows image changes how the Windows license is metered — validate the commercial implications separately from the technical ones.
- **Scale sets.** Uniform-orchestration scale sets cannot use Azure Edition images with hotpatch at all; use Flexible orchestration.
- **RDP exposure.** `main.bicep` opens 3389 only to `allowedRdpSourcePrefix`. Never widen this to `*` or `Internet`. For anything beyond a short-lived lab, replace the public IPs with Azure Bastion.

## Clean up

```powershell
az group delete -n $rg --yes --no-wait
```
