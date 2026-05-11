# Azure Monitor AIOps — Centralized Alerting Governance

This folder contains Azure Policy definitions and custom RBAC role definitions to implement a **centralized, governed alerting model** where all teams can create metric alerts but must route them through centrally-managed Action Groups controlled by a Monitoring Engineering (ME) team.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────┐
│              Management Group (Shared Services)          │
│  ┌─────────────────────────────────────────────────┐    │
│  │  Policy 1: Alert Rule Naming Enforcement         │    │
│  │  Policy 2: Deny Duplicate AG Webhook URLs        │    │
│  └─────────────────────────────────────────────────┘    │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  ME Shared-Services Subscription                  │   │
│  │  ┌────────────────────────────────────────────┐  │   │
│  │  │  Action Group: aiops-prod                  │  │   │
│  │  │    webhook → https://aiops.domain/prod     │  │   │
│  │  │  Action Group: aiops-nonprod               │  │   │
│  │  │    webhook → https://aiops.domain/nonprod  │  │   │
│  │  └────────────────────────────────────────────┘  │   │
│  │  Role: AIOps Monitoring Engineer (ME team)        │   │
│  └──────────────────────────────────────────────────┘   │
│                                                          │
│  ┌──────────────────────────────────────────────────┐   │
│  │  Consumer Subscriptions (Landing Zones)           │   │
│  │  ┌────────────────────────────────────────────┐  │   │
│  │  │  Metric Alert Rules (owned by teams)       │  │   │
│  │  │    → reference ME Action Groups cross-sub  │  │   │
│  │  │    → name must match: alrt-{service}-...    │  │   │
│  │  └────────────────────────────────────────────┘  │   │
│  │  Role: AIOps Alert Rule Contributor (teams)       │   │
│  └──────────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────────┘
```

**Flow:**
1. ME team creates and owns Action Groups with AIOps webhook URLs in the shared-services subscription.
2. Consumer teams create metric alert rules in their own subscriptions, referencing ME-managed Action Groups cross-subscription.
3. Azure Policy enforces the naming convention on all new alert rules.
4. Azure Policy blocks any team from creating Action Groups that reuse the ME team's reserved webhook URLs.
5. RBAC prevents consumer teams from creating or modifying Action Groups entirely.

---

## Files

### `AIOps-AlertRule-NamingEnforcement.json`
**Type:** Azure Policy Definition  
**Resource target:** `Microsoft.Insights/metricAlerts`

Enforces the following naming standard on all metric alert rules:

```
{prefix}-{service}-{metric}-{severity}-{environment}-{region}
```

| Segment | Purpose | Allowed Values |
|---|---|---|
| `{prefix}` | Alert object type identifier | `alrt`, `ma`, `metricalrt` |
| `{service}` | Azure resource type abbreviation | `vm`, `sql`, `storage`, `appservice`, etc. |
| `{metric}` | Azure metric name (align to Azure naming) | `cpu`, `availability`, etc. |
| `{severity}` | Alert severity level | `high`, `low`, `med` |
| `{environment}` | Deployment stage / environment | `test`, `dev`, `prod` |
| `{region}` | Azure region abbreviation | `eastus`, `eastus2`, `westus`, `westus2`, `centralus`, `canadacentral`, `canadaeast` |

**Example valid name:** `alrt-vm-cpu-high-prod-eastus`

The policy applies **4 layered checks**:
1. Name starts with an approved prefix: `alrt-*`, `ma-*`, or `metricalrt-*`
2. Name contains a valid severity segment: `-high-`, `-low-`, or `-med-`
3. Name contains a valid environment segment: `-test-`, `-dev-`, or `-prod-`
4. Name ends with an approved Azure region abbreviation

**Parameters:**
| Parameter | Default | Description |
|---|---|---|
| `effect` | `Audit` | Policy effect — start with `Audit`, move to `Deny` after validation |

> **Note:** Log Analytics-based alerts (`scheduledQueryRules`) are explicitly out of scope and not targeted by this policy.

---

### `AIOps-Deny-ActionGroup-Webhook.json`
**Type:** Azure Policy Definition  
**Resource target:** `Microsoft.Insights/actionGroups`

Prevents any team from creating an Action Group that references a webhook URL reserved for ME team's centralized AIOps integration. This is the primary guard against teams bypassing the centralized routing model.

The policy uses the Azure Policy **array count expression** to inspect every `webhookReceivers[*].serviceUri` in a given Action Group. If any receiver URL matches the denied list, the request is blocked.

**Parameters:**
| Parameter | Default | Description |
|---|---|---|
| `deniedWebhookUrls` | `["https://aiops.domain.com/something/prod", "https://aiops.domain.com/something/nonprod"]` | Reserved webhook URLs — replace with real values before deployment |
| `effect` | `Audit` | Policy effect — start with `Audit`, move to `Deny` after validation |

> **Important:** Update `deniedWebhookUrls` to the actual AIOps endpoint URLs before assigning this policy. The defaults are placeholder values.

---

### `AIOps-ME-MonitoringEngineer-Role.json`
**Type:** Azure Custom RBAC Role  
**Intended assignees:** ME team members  
**Assignable scopes:** ME shared-services management group + ME shared-services subscription

Grants the ME team the permissions needed to own and operate the centralized AIOps infrastructure without granting broad Contributor or Owner rights:

| Permission Group | Actions |
|---|---|
| **Action Groups** | Full CRUD (`read`, `write`, `delete`) |
| **Metric Alert Rules** | Full CRUD + `status/read` |
| **Azure Policy** | Full management of definitions, assignments, exemptions at management group scope |
| **Policy Insights** | Read states/events, manage remediations |
| **Resources & Management Groups** | Read-only access to subscriptions, resource groups, management group hierarchy |
| **Metrics & Diagnostics** | Read-only visibility (`metrics`, `metricDefinitions`, `diagnosticSettings`, `alertRules`) |

> **Note:** For policy definition/assignment permissions to function at management group scope, the role must be **assigned at the management group**, not just the subscription.

---

### `AIOps-Consumer-AlertRuleContributor-Role.json`
**Type:** Azure Custom RBAC Role  
**Intended assignees:** Consumer team members (application/platform teams)  
**Assignable scopes:** Landing Zone management group (covers all consumer subscriptions)

Allows teams to create and manage metric alert rules in their own subscriptions while enforcing that they must use ME-managed Action Groups:

| Permission Group | Actions |
|---|---|
| **Action Groups** | `read` only (cross-subscription reference to ME-managed AGs) |
| **Metric Alert Rules** | Full CRUD + `status/read` |
| **Metrics & Definitions** | `read` (needed to configure alert conditions) |
| **Resources** | `read` on subscriptions, resource groups, resources |
| **Policy** | `read` only (compliance visibility) |
| **notActions** | `actionGroups/write` and `actionGroups/delete` are **explicitly denied** |

> **Cross-subscription note:** Azure ARM requires the identity creating an alert rule to have `actionGroups/read` on the Action Group's subscription. This role must be assigned in **two places**: (1) at the landing zone management group for consumer subscriptions, and (2) at the ME shared-services subscription (or its resource group) for the read access to ME-managed Action Groups. Without the second assignment, alert rule creation will fail even with a valid Action Group ARM ID.

---

## Deployment Guide

### Prerequisites

- Azure CLI installed and authenticated: `az login`
- Permissions:
  - `Owner` or `User Access Administrator` on the target management group (for RBAC role creation)
  - `Resource Policy Contributor` or higher on the management group (for policy deployment)
- The management group and subscription IDs for your environment

---

### Step 1 — Substitute Placeholder Values

Before deploying, replace the following placeholders across the role files:

| Placeholder | File | Replace With |
|---|---|---|
| `<ME-MANAGEMENT-GROUP-ID>` | `AIOps-ME-MonitoringEngineer-Role.json` | Your ME/shared-services management group ID |
| `<ME-SHARED-SERVICES-SUBSCRIPTION-ID>` | `AIOps-ME-MonitoringEngineer-Role.json` | Your ME shared-services subscription ID |
| `<LANDING-ZONE-MANAGEMENT-GROUP-ID>` | `AIOps-Consumer-AlertRuleContributor-Role.json` | Your landing zone management group ID |
| `https://aiops.domain.com/something/prod` | `AIOps-Deny-ActionGroup-Webhook.json` | Real AIOps prod webhook URL |
| `https://aiops.domain.com/something/nonprod` | `AIOps-Deny-ActionGroup-Webhook.json` | Real AIOps non-prod webhook URL |

---

### Step 2 — Deploy Custom RBAC Roles

```bash
# ME Team role (run once per tenant — roles are tenant-scoped)
az role definition create \
  --role-definition @AIOps-ME-MonitoringEngineer-Role.json

# Consumer Team role
az role definition create \
  --role-definition @AIOps-Consumer-AlertRuleContributor-Role.json
```

Verify:
```bash
az role definition list --custom-role-only true --query "[].{Name:roleName, ID:name}" -o table
```

---

### Step 3 — Deploy Policy Definitions

Deploy to the management group where ME team manages governance (e.g., shared-services MG):

```bash
MG_ID="<ME-MANAGEMENT-GROUP-ID>"

# Naming enforcement policy
az policy definition create \
  --name "aiops-alert-naming-enforcement" \
  --display-name "[AIOps] Enforce Alert Rule Naming Convention" \
  --rules AIOps-AlertRule-NamingEnforcement.json \
  --management-group $MG_ID \
  --mode All

# Webhook deny policy
az policy definition create \
  --name "aiops-deny-duplicate-actiongroup-webhook" \
  --display-name "[AIOps] Deny Action Groups Using Reserved ME Team Webhook URLs" \
  --rules AIOps-Deny-ActionGroup-Webhook.json \
  --management-group $MG_ID \
  --mode All
```

> **Tip:** You can also import the full JSON files (which include parameters) via the Azure Portal under **Management Groups → Policies → Definitions → + Policy definition**.

---

### Step 4 — Assign Policies (Start in Audit Mode)

Assign both policies at the management group scope. Use `Audit` effect first to identify non-compliant resources before enforcing `Deny`.

```bash
MG_ID="<ME-MANAGEMENT-GROUP-ID>"
MG_SCOPE="/providers/Microsoft.Management/managementGroups/$MG_ID"

# Assign naming enforcement (Audit mode)
az policy assignment create \
  --name "aiops-alert-naming-audit" \
  --display-name "[AIOps] Alert Rule Naming - Audit" \
  --policy "aiops-alert-naming-enforcement" \
  --scope $MG_SCOPE \
  --params '{"effect": {"value": "Audit"}}'

# Assign webhook deny (Audit mode)
az policy assignment create \
  --name "aiops-webhook-deny-audit" \
  --display-name "[AIOps] Deny Reserved Webhook URLs - Audit" \
  --policy "aiops-deny-duplicate-actiongroup-webhook" \
  --scope $MG_SCOPE \
  --params '{
    "effect": {"value": "Audit"},
    "deniedWebhookUrls": {"value": ["https://your-real-prod-url", "https://your-real-nonprod-url"]}
  }'
```

---

### Step 5 — Assign RBAC Roles

```bash
ME_SUB_ID="<ME-SHARED-SERVICES-SUBSCRIPTION-ID>"
ME_MG_ID="<ME-MANAGEMENT-GROUP-ID>"
LZ_MG_ID="<LANDING-ZONE-MANAGEMENT-GROUP-ID>"

# Assign ME team role at the management group (enables policy management)
az role assignment create \
  --role "AIOps Monitoring Engineer" \
  --assignee "<ME-TEAM-GROUP-OBJECT-ID>" \
  --scope "/providers/Microsoft.Management/managementGroups/$ME_MG_ID"

# Assign Consumer role at the LZ management group (covers all consumer subs)
az role assignment create \
  --role "AIOps Alert Rule Contributor" \
  --assignee "<CONSUMER-TEAM-GROUP-OBJECT-ID>" \
  --scope "/providers/Microsoft.Management/managementGroups/$LZ_MG_ID"

# IMPORTANT: Also assign the consumer role at the ME subscription
# so consumer teams can READ ME-managed Action Groups cross-subscription
az role assignment create \
  --role "AIOps Alert Rule Contributor" \
  --assignee "<CONSUMER-TEAM-GROUP-OBJECT-ID>" \
  --scope "/subscriptions/$ME_SUB_ID"
```

---

### Step 6 — Validate in Audit Mode

After assignment, trigger a compliance scan and review:

```bash
# Trigger evaluation
az policy state trigger-scan --management-group $MG_ID

# List non-compliant resources
az policy state list \
  --management-group $MG_ID \
  --filter "complianceState eq 'NonCompliant'" \
  --query "[].{Resource:resourceId, Policy:policyDefinitionName}" \
  -o table
```

Review all non-compliant alert rule names and remediate (rename) them before switching the policy effect to `Deny`.

---

### Step 7 — Switch to Deny Mode

Once all non-compliant resources are resolved:

```bash
# Update naming enforcement to Deny
az policy assignment update \
  --name "aiops-alert-naming-audit" \
  --scope $MG_SCOPE \
  --params '{"effect": {"value": "Deny"}}'

# Update webhook deny to Deny
az policy assignment update \
  --name "aiops-webhook-deny-audit" \
  --scope $MG_SCOPE \
  --params '{"effect": {"value": "Deny"}}'
```

---

## Recommended Rollout Order

```
1. Deploy RBAC roles (tenant-wide, non-disruptive)
2. Deploy policy definitions (no effect until assigned)
3. Assign policies in Audit mode
4. Run compliance scan — review non-compliant resources
5. Remediate existing non-compliant alert rule names
6. Switch policy assignments to Deny mode
7. Assign RBAC roles to ME team and consumer teams
```

---

## Out of Scope

The following are intentionally excluded from this implementation:

- Log Analytics / ingestion-based metrics
- Azure Monitor Agent (AMA) / custom metrics
- Dashboards and visualization
- Scheduled Query Rules (`Microsoft.Insights/scheduledQueryRules`)
- End-to-end monitoring strategy

---

## Notes

- All policies default to `Audit` effect — always validate in audit mode before enabling `Deny` in production.
- The webhook deny policy uses **exact URL matching**. Ensure the `deniedWebhookUrls` parameter values exactly match what the ME team's Action Groups use (including trailing slashes, casing, etc.).
- Custom RBAC role names must be unique per tenant. If a role with the same name already exists, update the existing definition instead of creating a new one.
- Policy definitions created at management group scope are only visible within that management group hierarchy and are not available tenant-wide unless created at the root management group.
