# Azure Deployment Plan

> **Status:** Deployed

Generated: 2026-09-10

## 1. Project Overview

**Goal:** Deploy a private networking comparison lab with one Azure API Management Standard v2 unit and one Premium v2 unit.

**Path:** Add Components to the existing Shell-Power repository.

## 2. Requirements

| Attribute | Value |
|---|---|
| Classification | POC / lab |
| Scale | Small: one unit per APIM tier |
| Budget | Feature comparison; remove immediately after testing |
| Subscription | `ME-MngEnvMCAP065801-xaelizon-1` (`d6373f95-7403-4349-adf8-78cb62a4a60a`), confirmed by user |
| Location | Canada Central (`canadacentral`), confirmed by user |
| Resource group | `rg-apim-v2-network-lab` |

Retail Pricing returned no Canada Central records for the exact `StandardV2` and `PremiumV2` ARM SKU names. No cost estimate is asserted. The user was warned that both services are billable and explicitly approved live deployment after reviewing What-If.

## 3. Components Detected

| Component | Type | Technology | Path |
|---|---|---|---|
| Subscription deployment | Infrastructure | Bicep | `Az-Network/API-GW/main.bicep` |
| APIM/network lab module | Infrastructure | Bicep and Azure Verified Modules | `Az-Network/API-GW/modules/lab.bicep` |
| Deployment parameters | Configuration | Bicep parameters | `Az-Network/API-GW/main.bicepparam` |
| Deployment automation | Operations | PowerShell and Azure CLI | `Az-Network/API-GW/Deploy-ApimV2Lab.ps1` |
| Connectivity test | Verification | PowerShell | `Az-Network/API-GW/Test-ApimPrivateConnectivity.ps1` |
| Runbook | Documentation | Markdown | `Az-Network/API-GW/README.md` |

## 4. Recipe Selection

**Selected:** Bicep deployed through Azure CLI subscription deployment.

**Rationale:** The request explicitly requires Bicep and creates the resource group at subscription scope. Azure Verified Modules are used for APIM, VNet, NSG, and private DNS resources.

## 5. Architecture

| Component | Azure Service | SKU / configuration |
|---|---|---|
| Standard gateway | API Management | Standard v2, capacity 1, outbound VNet integration, gateway private endpoint |
| Premium gateway | API Management | Premium v2, capacity 1, internal VNet injection, gateway private endpoint |
| Network | Virtual Network | `10.42.0.0/16`, four dedicated `/24` subnets |
| Inbound private access | Private Link | Two private endpoints in a shared private-endpoint subnet |
| Name resolution | Private DNS | `privatelink.azure-api.net` linked to the lab VNet |
| Security | Network Security Groups | Separate NSGs for both delegated APIM subnets |
| Identity | Managed Identity | System-assigned identity on both APIM services |

Public network access starts enabled to avoid initial lockout and is changed only after connected-client testing. Standard v2 does not support full VNet injection. Premium v2 injection is a creation-time topology choice.

## 6. Provisioning Limit Checklist

ARM validation and What-If are the authoritative preflight checks for this APIM lab because the Microsoft.Quota API does not expose allocatable Standard v2 or Premium v2 unit capacity. Regional APIM capacity remains subject to availability at creation time.

| Resource Type | Number to Deploy | Total in Lab RG After Deployment | Limit / Capacity Check | Result |
|---|---:|---:|---|---|
| `Microsoft.ApiManagement/service` Standard v2 | 1 | 1 | No quota API entry; Canada Central support researched; ARM validation passed | Pass with regional capacity caveat |
| `Microsoft.ApiManagement/service` Premium v2 | 1 | 1 | No quota API entry; Canada Central selected because Central US creation was unavailable; ARM validation passed | Pass with regional capacity caveat |
| `Microsoft.Network/virtualNetworks` | 1 | 1 | Standard Azure networking subscription limit; ARM validation passed | Pass |
| `Microsoft.Network/virtualNetworks/subnets` | 4 | 4 | Address spaces are non-overlapping and accepted by ARM validation | Pass |
| `Microsoft.Network/networkSecurityGroups` | 2 | 2 | Standard Azure networking subscription limit; ARM validation passed | Pass |
| `Microsoft.Network/privateEndpoints` | 2 | 2 | Standard Private Link subscription/VNet limits; ARM validation passed | Pass |
| `Microsoft.Network/privateDnsZones` | 1 | 1 | Standard private DNS subscription limit; ARM validation passed | Pass |
| `Microsoft.Network/privateDnsZones/virtualNetworkLinks` | 1 | 1 | One link for one zone; ARM validation passed | Pass |

**Status:** All planned resources passed ARM validation and What-If. APIM regional capacity cannot be reserved or guaranteed by preflight.

## 7. Execution Checklist

### Phase 1: Planning

- [x] Analyze workspace
- [x] Gather requirements
- [x] Confirm subscription and location with user
- [x] Prepare 16-resource inventory
- [x] Check service limits and regional availability
- [x] Select Bicep recipe
- [x] Plan private networking architecture
- [x] User approved architecture, What-If, and live deployment

### Phase 2: Execution

- [x] Research APIM v2 networking constraints
- [x] Generate Bicep infrastructure and parameter files
- [x] Generate guarded deployment, validation, and cleanup scripts
- [x] Document security decisions and test procedure
- [x] Update plan status to Ready for Validation

### Phase 3: Validation

- [x] Local Bicep restore and build
- [x] PowerShell parser validation
- [x] ARM subscription deployment validation
- [x] ARM What-If
- [x] All validation checks pass
	- [x] Core validation: Azure CLI, authentication, Bicep build, ARM validation, and What-If
	- [x] Azure Policy validation
	- [x] Bicep linting (optional)
	- [x] Static RBAC review
- [x] Complete azure-validate workflow through validation proof
- [x] Set status to Validated through azure-validate

### Phase 4: Deployment

- [x] Complete pre-deployment checklist
- [x] Execute approved deployment
- [x] Verify APIM, private endpoints, VNet, and private DNS
- [x] Set status to Deployed

## 8. Validation Proof

This section will be finalized by the azure-validate workflow before deployment.

| Check | Command Run | Result | Timestamp |
|---|---|---|---|
| Bicep build | `az bicep build --file main.bicep` | Pass | 2026-09-10 |
| PowerShell parsing | PowerShell AST parser for all three scripts | Pass | 2026-09-10 |
| ARM validation | `az deployment sub validate` against the confirmed subscription | Succeeded, no error | 2026-09-10 |
| ARM What-If | `az deployment sub what-if --result-format ResourceIdOnly` | Succeeded: 16 create, 0 modify, 0 delete, no policy denial | 2026-09-10 |
| Prescribed core validation | `validate-deployment.ps1` with subscription scope and project paths | Overall Pass: CLI, auth, build, ARM validation, and What-If | 2026-09-10 |
| Bicep lint | `az bicep lint --file main.bicep` | Pass, no diagnostics | 2026-09-10 |
| Azure Policy | Policy assignment list plus deny rule inspection | Pass: legacy Classic-resource deny does not match; ARM validation and What-If had no denial | 2026-09-10 |
| Static RBAC | Search and review of all Bicep modules | Pass: no role assignments required; APIM identities have no configured data-plane dependencies | 2026-09-10 |

**Validated by:** azure-validate workflow

**Validation timestamp:** 2026-09-10

## Static Role Assignment Verification

- Status: Verified
- Identities checked: system-assigned identities on Standard v2 and Premium v2 API Management
- Roles confirmed: none required for the deployed network and private endpoint topology
- Rationale: the lab does not configure APIM access to Key Vault, Storage, Service Bus, Azure OpenAI, or another protected data-plane service
- Future work: add least-privilege data-plane roles when a private backend or secret store is added

## 9. Files

| File | Purpose | Status |
|---|---|---|
| [deployment-plan.md](./deployment-plan.md) | Deployment workflow evidence | Complete |
| `Az-Network/API-GW/main.bicep` | Subscription entry point | Complete |
| `Az-Network/API-GW/modules/lab.bicep` | APIM and network resources | Complete |
| `Az-Network/API-GW/main.bicepparam` | Confirmed deployment values | Complete |
| `Az-Network/API-GW/Deploy-ApimV2Lab.ps1` | Guarded deployment workflow | Complete |
| `Az-Network/API-GW/Test-ApimPrivateConnectivity.ps1` | Connected-client validation | Complete |
| `Az-Network/API-GW/Remove-ApimV2Lab.ps1` | Guarded cleanup | Complete |
| `Az-Network/API-GW/README.md` | Shareable runbook | Complete |

## 10. Next Steps

1. Run data-plane connectivity tests from a client connected to the lab VNet.
2. Compare private backend access through Standard v2 integration and Premium v2 injection.
3. Remove the resource group immediately after the comparison to stop APIM charges.

## 11. Deployment Result

| Item | Result |
|---|---|
| Deployment | `apim-v2-network-lab-20260910` succeeded in 15 minutes 42 seconds |
| Resource group | `rg-apim-v2-network-lab`, Canada Central, Succeeded |
| Standard v2 | `apimv2cmp-stdv2-talhc65l4tydu`, capacity 1, `External`, Succeeded |
| Premium v2 | `apimv2cmp-premv2-talhc65l4tydu`, capacity 1, `Internal`, Succeeded |
| Standard private endpoint | Approved, `Gateway`, `10.42.2.4` |
| Premium private endpoint | Approved, `Gateway`, `10.42.2.5` |
| Private DNS | Both APIM names have matching A records; VNet link Completed |
| Network | Four subnets and both required delegations verified |
| Failed operations | None |
| Deployment-created RBAC | None |
| Public workstation test | Standard status endpoint HTTP 200; Premium internal gateway did not resolve publicly |
| Private client test | Pending; no VM or other connected client was deployed by design |