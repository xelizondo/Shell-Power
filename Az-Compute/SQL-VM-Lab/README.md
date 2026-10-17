# Three-version SQL Server VM lab

Bicep templates for **RG-SQL**, **Canada Central** (`canadacentral`).
Nothing is deployed by creating or compiling these files.

See the [deployment plan](deployment-plan.md) for deployment history and validation results.

| VM | Marketplace publisher / offer / SKU | SQL licensing |
| --- | --- | --- |
| SQL2025 | MicrosoftSQLServer / sql2025-ws2025 / enterprise-gen2 | Azure Hybrid Benefit |
| SQL2022 | MicrosoftSQLServer / sql2022-ws2022 / standard-gen2 | Azure Hybrid Benefit |
| SQL2017 | MicrosoftSQLServer / sql2017-ws2019 / sqldev-gen2 | Free Developer edition, dev/test only |

SQL2022 uses **SQL Server 2022**, not SQL Server 2012.
These offers use Windows Server 2025, 2022, and 2019, respectively.
The deployment script checks that each exact image is available in the target
region and is Windows x64 Gen2. It does not silently substitute another image,
edition, region, or VM size. Catalog availability is not verified until that
authenticated preflight runs.
The Daldsv6 series also requires NVMe-compatible OS images. ARM validation must
accept each exact image/VM-size combination; if it does not, stop and choose an
explicitly approved different image or size rather than bypassing that check.

## Resources and behavior

- Three `Standard_D2alds_v6` VMs, each with **2 vCPUs and 4 GiB RAM**.
  This is a small functional lab, not a SQL performance or production baseline.
  SQL maximum server memory is capped at 2,048 MiB per VM to leave room for Windows.
- Local administrator: `az-admin`. Each VM has its own random 32-character
  password, saved as `<VM-name>-admin-password` in a shared Standard Key Vault.
- Windows Server Hybrid Benefit on all VMs. SQL Hybrid Benefit on Enterprise
  and Standard. You must have eligible licenses and version rights; setting
  these properties does not provide licenses.
- Developer SQL registration uses `sqlImageSku: Developer` and license type
  `PAYG` (the API has no `FREE` license type). **Developer SQL licensing is free**;
  the VM, Windows licensing eligibility, disks, and networking still matter.
- OS disks: `StandardSSD_LRS`, retaining each Marketplace image's minimum size.
  They are not forced down to 64 GiB.
- Each VM has two **64-GiB Standard SSD LRS (E6)** managed disks:
  LUN 0 / F: for data and system databases, LUN 1 / G: for logs.
  Data caching is ReadOnly; log caching is None.
  SQL storage configuration uses Storage Spaces, so formatted volumes are
  slightly smaller than the underlying 64-GiB managed disks.
- TempDB is placed at `F:\SQLTempDB`, sharing the 64-GiB data disk.
  The requested v6 size has raw local NVMe storage, so the lab does not depend
  on its initialization or persistence. The local temporary disk is not configured.
- One shared VNet (`10.52.0.0/16`), subnet (`10.52.1.0/24`), and NSG.
  Check for address overlap before peering this lab with other networks.
- Three static Standard IPv4 public IPs. They also provide explicit outbound
  Internet access for the VMs; implicit/default subnet outbound access is disabled.
- Only TCP 3389 from `162.207.71.133/32` is allowed inbound.
  An explicit deny overrides the NSG's default VNet and load-balancer inbound
  allows: **VM-to-VM inbound traffic is also blocked**. SQL port 1433 is not
  exposed. Outbound traffic and established connection responses remain allowed.
- SQL uses Windows authentication and LOCAL connectivity. RDP to a VM and
  connect to its local default SQL instance using Windows authentication.
  No SQL-authentication user or password is created.
- `Microsoft.SqlVirtualMachine/sqlVirtualMachines` registration installs/manages
  the SQL IaaS Agent extension and configures the disks.
- Each VM shuts down/deallocates daily at **19:00 Toronto/Eastern time**.
  Windows time zone `Eastern Standard Time` observes daylight saving time
  (UTC-4 in summer, UTC-5 in winter). No automatic startup is configured.
- One Standard Recovery Services vault, `rsv-sql-lab`, with
  `standardTierStorageRedundancy: GeoRedundant`. No VM/SQL backup policy,
  backup enrollment, restore points, or cross-region restore enablement is created.
  The vault is ready for a later backup demo, not already protecting the VMs.

## Prerequisites

1. PowerShell **7.2+ on Windows**, Azure CLI, and its Bicep CLI.
2. `az login` to the correct tenant. Supply the subscription ID explicitly;
   the script does not change your default Azure subscription.
3. Permission to create the resource group and its resources, create subscription
   deployments, and assign **Key Vault Secrets User** on the lab vault. Owner,
   or Contributor plus an appropriate RBAC assignment role, are typical options.
   Contributor alone cannot create the role assignment.
4. The **object ID**, not application/client ID, of the password reader.
   For your own signed-in user: `az ad signed-in-user show --query id -o tsv`.
   Service principals and groups require the corresponding principal-type option.
5. Registered resource providers: Microsoft.Compute, Microsoft.Network,
   Microsoft.KeyVault, Microsoft.RecoveryServices, Microsoft.SqlVirtualMachine,
   and Microsoft.DevTestLab. Preflight reports missing registrations and stops;
   it does not modify subscription registrations.
6. Available regional total and Daldsv6-family quota: **6 vCPUs** for a fresh
   deployment. Three public IPs and three NICs must also fit subscription limits.
   Preflight checks VM-family and total vCPU quota; ARM validation checks the
   full deployment. Neither validation nor What-If reserves regional capacity.
7. Eligible Windows and SQL Hybrid Benefit licenses. SQL Server 2017 Developer
   must be used only for development/test.
8. Use a **dedicated** RG-SQL, not a resource group with unrelated SQL VMs.

The Key Vault data-plane firewall permits `162.207.71.133/32` and trusted Azure
services only. Run password reads/redeployments from that address with the
appropriate RBAC role. An authentication, firewall, or permission failure stops
the script rather than generating replacement passwords. RBAC propagation can
take a few minutes after first deployment.

## Validate first

From this directory:

```powershell
az bicep build --file .\main.bicep --stdout | Out-Null

.\Deploy-SqlVmLab.ps1 `
  -SubscriptionId '<subscription-guid>' `
  -VaultReaderObjectId '<your-user-object-guid>'
```

The default mode is **Validate**. It performs read-only provider, SKU, quota, and
image checks, ARM validation, and What-If. It creates no Azure resources.
New passwords used for a validation-only run are discarded afterwards.

For a service principal password reader, add:

```powershell
-VaultReaderPrincipalType ServicePrincipal
```

## Deploy explicitly

Only when you are ready to incur Azure charges:

```powershell
.\Deploy-SqlVmLab.ps1 `
  -SubscriptionId '<subscription-guid>' `
  -VaultReaderObjectId '<your-user-object-guid>' `
  -Mode Deploy
```

The script runs preflight/validation/What-If again, then asks for confirmation.
It returns public IPs, Key Vault name, secret names, and Recovery Services vault
name. It checks SQL resource and SQL IaaS extension provisioning after deployment,
allowing up to 12 checks at ten-second intervals for transient extension states.
Guest SQL service health and actual RDP access must be checked separately.

The subscription-scope entry point creates the resource group. All lab resources
are deployed into it. The image manifest is shared by the Bicep module and the
script; new VMs are pinned to the exact versions resolved during preflight.
Existing VM image references and saved passwords are reused on redeployment;
this script is not an image-upgrade or password-rotation workflow.

Passwords are never printed, output by the templates, or passed as command-line
values. An owner-only Windows ACL protects the temporary parameter directory
**before** credentials are written. The temporary file is removed in `finally`.
A forced process termination or power failure can bypass cleanup; treat any
remaining `%TEMP%\sql-vm-lab-<GUID>\parameters.json` as sensitive and delete only
that specific file/directory. Do not enable CLI debug tracing, dump variables,
or commit a populated parameter file.

The Bicep entry point can also be deployed directly, but callers must supply
the secure `adminPasswords` object safely and preserve/reuse credentials.

## Verify the deployed lab

Use the deployment outputs for the Key Vault name and each VM's IP.

1. From `162.207.71.133`, RDP to each public IP as `.\az-admin`.
   Retrieve its password in the Azure portal's Key Vault secret viewer.
   Keep passwords out of terminal output, screenshots, and chat.
2. Connect using SSMS, if installed, or `sqlcmd` on each VM with Windows
   authentication. No extra SSMS installation is included. Run:

   ```sql
   SELECT @@VERSION AS Version,
          SERVERPROPERTY('Edition') AS Edition,
          SERVERPROPERTY('IsIntegratedSecurityOnly') AS WindowsAuthenticationOnly;
   SELECT name, physical_name FROM sys.master_files ORDER BY database_id, file_id;
   EXEC sp_configure 'max server memory (MB)';
   ```

   Confirm the requested versions/editions, Windows-only authentication (`1`),
   F: data/system databases/TempDB, G: user database logs, and the memory cap.
   System database log files may share F: with the system databases.
3. In Disk Management, confirm F: and G: each use a separate 64-GiB managed disk.
   Check the Azure disk resources are Standard SSD LRS.
4. In **SQL virtual machines**, confirm successful registration and
   **SQL IaaS Agent** extension provisioning for all three VMs.
5. Inspect the shared NSG and VM effective rules. RDP should work from the
   allowed address and fail from another address; SQL TCP 1433 should not be
   accessible externally. A test from only the allowed IP does not prove the
   deny rule works.
6. Inspect each VM's Auto-shutdown page: **19:00**, **Eastern Time**. After that
   time, check that its power state becomes **Stopped (deallocated)**.
7. In the Recovery Services vault's backup configuration, confirm
   **Geo-redundant**, and that no protected items are enrolled.

The deny-all inbound rule and LOCAL SQL connectivity are intentional.
Review network rules and SQL permissions before demonstrating SQL workload
backup, remote SQL connections, or cross-VM scenarios; those features are not
configured by this lab.

## Cost and cleanup

Shutdown stops VM compute billing after deallocation, but managed disks,
Standard public IPv4 addresses, and any subsequent backup storage remain billable.
This lab does not assert a price estimate. Delete only the dedicated lab resource
group when finished, after checking that it contains nothing you need.
The Key Vault uses seven-day soft delete. Recreating a deleted RG with the same
vault name can require recovering or purging the soft-deleted vault; this script
does not purge vaults or remove backup data automatically.

## Local regression checks

```powershell
.\Test-SqlVmLab.ps1
```

These checks compile the templates and exercise the deployment script with a
mock Azure CLI. They do **not** authenticate, deploy, or verify live SKU capacity.

## References

- [Official SQL VM Bicep example](https://learn.microsoft.com/azure/azure-sql/virtual-machines/windows/create-sql-vm-bicep)
- [SQL VM resource schema](https://learn.microsoft.com/azure/templates/microsoft.sqlvirtualmachine/2023-10-01/sqlvirtualmachines)
- [SQL VM pricing and free Developer licensing](https://learn.microsoft.com/azure/azure-sql/virtual-machines/windows/pricing-guidance)
- [SQL IaaS Agent extension](https://learn.microsoft.com/azure/azure-sql/virtual-machines/windows/sql-server-iaas-agent-extension-automate-management)
- [Daldsv6 size and raw NVMe storage](https://learn.microsoft.com/azure/virtual-machines/sizes/general-purpose/daldsv6-series)
- [Recovery Services vault schema](https://learn.microsoft.com/azure/templates/microsoft.recoveryservices/2024-04-01/vaults)
