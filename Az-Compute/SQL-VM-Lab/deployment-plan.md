# SQL VM lab deployment plan

Deployment history and validation evidence for the [SQL VM lab](README.md).

Status: Deployed

## Scope

Create a standalone Bicep lab under `Az-Compute/SQL-VM-Lab`.
Subscription is parameterized. For the live test the user selected
`MS-XE-CSA-AIA-Shared-Services` (`2b73f762-264b-40ac-9ade-a1f95c5b2195`)
in tenant `132736d4-bb30-4536-a172-f2ed120852ec`.
Location is Canada Central and the resource group is `RG-SQL`.

## Approved architecture

- SQL2025: SQL Server 2025 Enterprise on Windows Server 2025, x64 Gen2.
- SQL2022: SQL Server 2022 Standard on Windows Server 2022, x64 Gen2.
- SQL2017: SQL Server 2017 Developer on Windows Server 2019, x64 Gen2.
- All VMs: Standard_D2alds_v6, az-admin, Windows Hybrid Benefit.
- SQL Hybrid Benefit for Enterprise/Standard; free Developer licensing.
- Standard SSD LRS OS disk at image minimum size.
- Two Standard SSD LRS 64-GiB disks per VM for SQL data and logs.
- Shared VNet/subnet and NSG; public IP per VM; RDP only from 162.207.71.133/32.
- SQL IaaS registration, Windows SQL authentication, no public SQL listener.
- Key Vault stores independently generated VM administrator passwords.
- Empty GRS Recovery Services vault for later backup demonstrations.
- Daily 19:00 shutdown in Eastern Standard Time (Windows zone; observes DST).

## Preparation and validation

1. Research exact Marketplace image identifiers, SQL storage configuration,
   licensing, secret handling, and schedule resource schemas.
2. Generate subscription-scope entry point, resource-group modules, parameters,
   deployment/preflight script, and documentation.
3. Compile and lint Bicep and parse PowerShell locally.
4. Leave regional SKU availability, quota, image availability, ARM validation,
   and What-If as subscription-authenticated deployment-time gates.

On 2026-10-16 the user authorized billable deployment after successful live
validation, registration of missing required resource providers, and vault-scoped
Key Vault Secrets User for `admin@xavierelizondo.com`
(`0d665a9d-3090-4aec-8c2a-1d5b4ee09b68`). Leave the VMs running after checks.
Do not delete existing resources or change the approved region, size, or images
without explicit approval.

## Preparation results

- Generated the Bicep entry point, resource-group and VM modules, shared image
  manifest, secure deployment/preflight script, README, and offline regression checks.
- Bicep compilation passes without template/linter diagnostics.
- Offline checks cover compiled requirements and mocked execution scenarios for
  validation, deployment verification, credential reuse, missing secrets, denied
  vault access, insufficient quota, restricted SKU, wrong image generation,
  unsuccessful What-If, and cleanup on failure.
- The 4-GiB VM memory constraint is documented; SQL memory is capped at 2 GiB.
- TempDB shares the managed data disk instead of relying on raw NVMe temporary storage.
- Developer registration uses PAYG with Developer edition (no SQL license charge);
  SQL Enterprise and Standard use AHUB.
- Live Marketplace/SKU capacity, subscription quotas/policy, ARM validation,
  What-If, RDP, guest SQL health, and actual shutdown are pending a user-selected
  subscription and explicit execution.

## All validation checks pass

- [x] Local Bicep compilation and linting.
- [x] Offline template contract checks and mocked PowerShell execution checks.
- [x] Static RBAC: Key Vault Secrets User is scoped to this vault; its principal
  ID and type are supplied by the caller. No broad subscription role is granted.
- [x] Core authenticated validation: CLI authentication, ARM validate, What-If.
- [x] Azure Policy validation for the selected subscription.

Live checks, the validation workflow, deployment, and post-deployment checks passed
for the user-confirmed subscription. VMs are left running as requested.

### Initial deployment and corrective retry

- Initial resource creation succeeded for all three running VMs, nine disks,
  networking, shutdown schedules, Key Vault, saved passwords, and vault reader role.
- SQL registration failed with InvalidLUNsSpecifiedForSameDrive. TempDB shares F:
  with SQL data and must explicitly specify the same LUN 0.
- Recovery Services creation failed with InvalidRestApiParameter for incomplete
  redundancy settings. Set crossRegionRestore explicitly to Disabled alongside
  GeoRedundant; this does not enable an unrequested restore feature.
- Retry must reuse all saved administrator passwords and existing VM image
  references; no resources will be deleted or recreated.
- Corrected templates compile and all 12 local regression checks pass.
- Corrective ARM validation and What-If succeeded against the existing lab:
  4 Create, 14 Modify, 9 Ignore, 7 NoChange, and no Delete changes.
- Saved passwords and pinned image references were successfully reused.
- Live RDP TCP connectivity succeeds to all three VM public IPs. TCP 1433
  times out on all three. NSG rules match the approved /32 RDP allow and
  catch-all inbound deny.
- Key Vault Secrets User assignment and all three enabled password secret names
  were verified live without printing secret values.

## Final deployment verification

ARM subscription deployment `sql-vm-lab` succeeded with timestamp
`2026-10-17T01:57:03.620017+00:00` (2026-10-16 Eastern).
All three SQL resources and SQL IaaS Agent extensions report Succeeded.
The script initially observed a transient extension state after ARM success;
post-deployment verification now retries transient states for at most 12 checks
at ten-second intervals, and fails immediately on an explicit Failed state.
The corrected scripts compile/parse and all 14 offline regression checks pass.

| VM | Public IP | Guest SQL version | Guest edition | Guest Windows |
| --- | --- | --- | --- | --- |
| SQL2025 | 20.63.32.44 | 17.0.5005.3 | Enterprise | Server 2025 Datacenter |
| SQL2022 | 20.151.223.188 | 16.0.4255.1 | Standard | Server 2022 Datacenter |
| SQL2017 | 20.151.105.70 | 14.0.3485.1 | Developer | Server 2019 Datacenter |

- All VMs: Standard_D2alds_v6, az-admin, Windows_Server Hybrid Benefit,
  provisioning Succeeded and VM running.
- SQL licensing: AHUB for Enterprise/Standard, PAYG with free Developer edition.
- Guest SQL services Running; Windows-only authentication is 1; max SQL memory
  is 2048 MiB on every VM.
- Guest SQL default data path F:\SQLData and default log path G:\SQLLog;
  master and TempDB file paths on F: verified using database-scoped metadata.
- Six data/log managed disks are exactly 64 GiB, StandardSSD_LRS. Three OS disks
  are 127 GiB, StandardSSD_LRS. Guest NTFS volumes are approximately 62 GiB after
  Storage Spaces overhead, not a disk-sizing error.
- Recovery Services vault rsv-sql-lab: Succeeded, GeoRedundant, cross-region
  restore Disabled, zero protected items.
- Key Vault kv-sql-ynpgh73ek6d5a: all three administrator password secrets
  enabled; confirmed administrator has vault-scoped Key Vault Secrets User.
- Each shutdown schedule: Enabled, 1900, Eastern Standard Time.
- RDP TCP reachability succeeds from this client; SQL TCP 1433 is blocked.
  Interactive RDP login and denial from a separate external source were not tested.
- No passwords were printed or committed. Temporary deployment parameter files
  were removed by the script. No resources were deleted during correction.

Portal: https://portal.azure.com/#@xavierelizondo.com/resource/subscriptions/2b73f762-264b-40ac-9ade-a1f95c5b2195/resourceGroups/RG-SQL/overview

## 7. Validation proof

- `az bicep build --file Az-Compute\SQL-VM-Lab\main.bicep --stdout`:
  passes with no Bicep template/linter diagnostics.
- PowerShell AST parsing of both lab scripts: passes.
- `Az-Compute\SQL-VM-Lab\Test-SqlVmLab.ps1`: 11 checks passed
  (compiled template requirements and 10 mocked execution scenarios).
  Uses mocked Azure CLI commands, never live Azure requests.
- `git diff --check`: passes for tracked changes; new templates are additionally
  covered by compilation and parsing.
- Before the live test, compatibility, capacity, policy, and guest health were
  untested. The completed live checks are recorded below.

### Live test preflight, 2026-10-16

- Azure CLI authentication verified as `admin@xavierelizondo.com` in the selected tenant.
- `az group exists --name RG-SQL`: false; no existing resource group conflict.
- `az role assignment list --include-inherited`: deployment principal has Owner
  and User Access Administrator permissions; vault role assignment is permitted.
- `az policy assignment list --disable-scope-strict-match`: returned two assignments
  scoped to RG-Images-WIP and RG-SIG, not RG-SQL. No applicable blocking assignment
  found in this result. ARM validation remains the policy enforcement gate.
- Microsoft.SqlVirtualMachine was unregistered; registration is authorized and
  was requested before running the deployment script in Validate mode.
- Microsoft.SqlVirtualMachine registration completed successfully.
- Resolved Windows x64 Gen2 images in Canada Central, all advertising SCSI/NVMe:
  SQL2025 `17.0.261006`, SQL2022 `16.0.260610`, SQL2017 `14.1.250114`.
- Regional total vCPU quota: 0/65 used. Daldv6-family quota: 0/65 used.
  Six new vCPUs fit both quotas, and no location SKU restriction was reported.
- `Deploy-SqlVmLab.ps1 -SubscriptionId 2b73f762-264b-40ac-9ade-a1f95c5b2195
  -VaultReaderObjectId 0d665a9d-3090-4aec-8c2a-1d5b4ee09b68` in default Validate
  mode: ARM validation succeeded; What-If Succeeded with 25 Create changes and
  no Modify/Delete changes. No Azure lab resources created by validation.
- Fixed strict-mode handling of an omitted optional Marketplace purchase-plan
  property. Local regression runner now passes 12 checks, including missing-plan
  metadata and rejection of images that require explicit purchase-plan handling.
- Static role verification: the only new assignment is Key Vault Secrets User
  (`4633458b-17de-408a-b874-0445c86b69e6`) scoped to the lab vault, assigned to
  the confirmed administrator object ID. No VM-to-service data-plane identity
  relationship is required for this lab.
