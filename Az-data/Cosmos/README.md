# Cosmos DB API inventory for CMDB

Azure Resource Graph does expose enough information to classify Cosmos DB APIs, but there is no single `apiType` property. For `Microsoft.DocumentDB/databaseAccounts`, classification requires both the top-level `kind` field and `properties.capabilities`. PostgreSQL and MongoDB-compatible vCore resources use separate ARM resource types.

| CMDB API label | ARM evidence |
| --- | --- |
| NoSQL API | `databaseAccounts`, `kind=GlobalDocumentDB`, no API capability |
| MongoDB API (RU-based) | `databaseAccounts`, `kind=MongoDB` and usually `EnableMongo` |
| Cassandra API | `databaseAccounts`, capability `EnableCassandra` |
| Gremlin API | `databaseAccounts`, capability `EnableGremlin` |
| Table API | `databaseAccounts`, capability `EnableTable` |
| PostgreSQL (retired Cosmos DB service) | `Microsoft.DBforPostgreSQL/serverGroupsv2` |
| Azure DocumentDB / MongoDB-compatible vCore | `Microsoft.DocumentDB/mongoClusters` |

Use [cosmosdb-api-inventory.kql](cosmosdb-api-inventory.kql) as the CMDB query. It preserves the raw classification fields so an unknown future value is visible instead of being incorrectly labeled as NoSQL.

## Deploy the validation accounts

The template creates one account for each RU-based API. It creates no databases or containers, so there is no provisioned throughput in those five accounts. Names are made globally unique from the subscription and resource group.

```powershell
$resourceGroup = 'rg-cosmos-cmdb-validation'
$location = 'eastus'

az group create --name $resourceGroup --location $location
az deployment group create `
  --resource-group $resourceGroup `
  --template-file .\cosmosdb-api-validation.bicep
```

PostgreSQL is disabled by default because Azure Cosmos DB for PostgreSQL is on a retirement path and its cluster creates billable compute. To test detection of an existing cluster, run the inventory query against a scope containing one. If the service is still available in the subscription and a temporary cluster is required, deploy with:

```powershell
$password = Read-Host 'Temporary PostgreSQL administrator password' -AsSecureString
New-AzResourceGroupDeployment `
  -ResourceGroupName $resourceGroup `
  -TemplateFile .\cosmosdb-api-validation.bicep `
  -deployPostgreSql $true `
  -postgresAdministratorPassword $password
```

## Run and validate the ARG query

```powershell
$query = (Get-Content .\cosmosdb-api-inventory.kql | Where-Object { $_ -notmatch '^\s*//' }) -join ' '
az graph query `
  --graph-query $query `
  --first 1000 `
  --query "data[].{Name:name, ApiType:apiType, Kind:rawKind, Capabilities:rawCapabilities, Location:location, ResourceGroup:resourceGroup, SubscriptionId:subscriptionId, ResourceType:type}" `
  --output table
```

Without `--subscriptions` or `--management-groups`, the query searches all subscriptions accessible to the signed-in account. The `--query "data[]..."` expression selects the resource rows from the Azure CLI response envelope; without it, table output can show only `Count` and `Total_records`.

Expected output contains five rows labeled NoSQL, MongoDB (RU-based), Cassandra, Gremlin, and Table. ARG is eventually consistent; wait a few minutes and rerun if a new deployment is not visible immediately. The `expectedApiType` tag provides an independent value for checking the query result.

See [ARG-Results-cosmosdb-api-inventory.kql.csv](ARG-Results-cosmosdb-api-inventory.kql.csv) for sample output captured from the validation environment.

To inspect the source fields without classification:

```kusto
Resources
| where type =~ 'microsoft.documentdb/databaseaccounts'
| project name, kind, capabilities=properties.capabilities, tags
```

## Cleanup

```powershell
az group delete --name $resourceGroup --yes --no-wait
```

## References

- [Azure Resource Graph samples for Azure Cosmos DB](https://learn.microsoft.com/azure/cosmos-db/resource-graph-samples)
- [Microsoft.DocumentDB/databaseAccounts Bicep reference](https://learn.microsoft.com/azure/templates/microsoft.documentdb/2024-11-15/databaseaccounts)
- [Azure Cosmos DB for PostgreSQL Bicep quickstart and retirement notice](https://learn.microsoft.com/azure/cosmos-db/postgresql/quickstart-create-bicep)