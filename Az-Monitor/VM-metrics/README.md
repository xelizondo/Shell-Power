# Azure Linux VM Performance Monitoring - Bicep

This package deploys a generic troubleshooting baseline for existing Linux Azure VMs:

- A Log Analytics workspace
- A Linux Data Collection Rule (DCR)
- Azure Monitor Agent (AMA) on each listed VM
- DCR associations for each VM
- Linux performance counters sent to the `Perf` table
- Warning-and-higher Syslog sent to the `Syslog` table
- Optional read-only RBAC for an Azure SRE Agent managed identity

Native Azure platform metrics such as Percentage CPU, disk latency, disk IOPS, throughput, queue depth, and network totals already exist in Azure Monitor Metrics and are not duplicated into Log Analytics by this template.

## Files

- `main.bicep`: subscription-scope orchestration
- `modules/monitoring.bicep`: workspace, DCR, and optional workspace RBAC
- `modules/vm-onboarding.bicep`: AMA and DCR association for each existing Linux VM
- `main.parameters.example.json`: example parameter file
- `queries.kql`: validation and starter troubleshooting queries

## Prerequisites

- Azure CLI with Bicep support
- Permission to create a resource group, workspace, DCR, VM extensions, DCR associations, and optionally role assignments
- Existing supported Linux Azure VMs with the Azure VM agent operating normally
- Outbound connectivity required by Azure Monitor Agent, or an appropriate private-link design if public ingestion/query access is disabled

## Configure

1. Copy `main.parameters.example.json` to `main.parameters.json`.
2. Replace each placeholder subscription ID, resource group, VM name, VM location, and monitoring resource name.
3. To configure SRE Agent access, set `sreAgentPrincipalId` to its managed identity object/principal ID and set `deploySreAgentRbac` to `true`.
4. Keep the default 60-second sampling initially. Lower intervals increase Log Analytics ingestion.

## Validate and preview

```bash
az login
az account set --subscription <deployment-subscription-id>
az bicep build --file main.bicep

az deployment sub what-if \
  --name linux-monitoring-preview \
  --location <deployment-region> \
  --template-file main.bicep \
  --parameters @main.parameters.json
```

The deployment subscription should normally be the subscription that will contain the monitoring resource group. The VM entries may point to VMs in other subscriptions to which the deploying identity has access.

## Deploy

```bash
az deployment sub create \
  --name linux-monitoring-deployment \
  --location <deployment-region> \
  --template-file main.bicep \
  --parameters @main.parameters.json
```

## Verify

```bash
az vm extension show \
  --resource-group <vm-resource-group> \
  --vm-name <vm-name> \
  --name AzureMonitorLinuxAgent \
  --query "{state:provisioningState,version:typeHandlerVersion}" \
  --output table
```

In the Azure portal:

1. Open **Monitor > Data Collection Rules**, select the DCR, and verify the three VM resources are associated.
2. Open the Log Analytics workspace and run the queries in `queries.kql`.
3. Open each VM's **Metrics** blade for native platform metrics.
4. Allow for normal ingestion delay before concluding that collection failed.

## Deliberate limits

- This package does not instrument the application or collect Oracle AWR/ASH/wait events.
- Process-level top CPU and memory consumers and TCP retransmissions are not guaranteed by the included standard AMA performance counters. Add application/APM, process telemetry, or custom logs if those are required.
- No automatic remediation is enabled.
- Public ingestion and query access are enabled for fastest generic deployment. Review Private Link, AMPLS, DCE, firewall, proxy, and network security requirements before production use.
- Platform metrics remain in Azure Monitor Metrics. Sending them to Log Analytics is not required for basic SRE Agent analysis and would add ingestion cost.

## Rollback

Delete the subscription deployment resources individually, or remove the monitoring resource group after first removing the AMA extensions and DCR associations from VMs if they are no longer needed.
