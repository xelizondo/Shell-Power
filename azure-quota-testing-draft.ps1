
$QuotaPercentageThreshold = "80"
$NewLimitIncrement = "25"
$Location = 'EastUS'
$VMSize = 'Standard_B2ms'

$SKU = Get-AzComputeResourceSku -Location $Location | Where-Object ResourceType -eq "virtualMachines" | Select-Object Name,Family
$VMFamily = ($SKU | Where-Object Name -eq $VMSize | Select-Object -Property Family).Family
$Usage = Get-AzVMUsage -Location $Location | Where-Object { $_.Name.Value -eq $VMFamily } | Select-Object @{label="Name";expression={$_.name.LocalizedValue}},currentvalue,limit, @{label="PercentageUsed";expression={[math]::Round(($_.currentvalue/$_.limit)*100,1)}}
$NewLimit = $Usage.Limit + $NewLimitIncrement

#Ticket Details
$TicketName =  "Quota Request"
$TicketTitle = "Quota Request"
$TicketDescription = "Quota request for $VMSize"
$Severity = "Critical" #Minimal, Moderate, Critical, HighestCriticalImpact
$ContactFirstName = "Mike"
$ContactLastName = "Tyson"
$TimeZone = "pacific standard time"
$Language = "en-us"
$Country = "USA"
$PrimaryEmail = "mtyson@boxing.com"
$AdditionalEmail = "mjordan@nba.com"
$ServiceNameGUID = "06bfd9d3-516b-d5c6-5802-169c800dec89" 
$ProblemClassificationGUID = "599a339a-a959-d783-24fc-81a42d3fd5fb"

Write-Output "$($Usage.Name.LocalizedValue): You have consumed Percentage: $($USage.PercentageUsed)% | $($Usage.CurrentValue) /$($Usage.Limit) of available quota"

if ($($USage.PercentageUsed) -gt $QuotaPercentageThreshold) {
    Write-Output "Creating support case"
    New-AzSupportTicket `
        -Name "$TicketName" `
        -Title "$TicketTitle" `
        -Description "$TicketDescription" `
        -Severity "$Severity" `
        -ProblemClassificationId "/providers/Microsoft.Support/services/$ServiceNameGUID/problemClassifications/$ProblemClassificationGUID" `
        -QuotaTicketDetail @{QuotaChangeRequestVersion = "1.0" ; QuotaChangeRequests = (@{Region = "$Location"; Payload = "{`"VMFamily`":`"$VMSize`",`"NewLimit`":$NewLimit}"})} -CustomerContactDetail @{FirstName = "$ContactFirstName" ; LastName = "$ContactLastName" ; PreferredTimeZone = "$TimeZone" ; PreferredSupportLanguage = "$Language" ; Country = "$Country" ; PreferredContactMethod = "Email" ; PrimaryEmailAddress = "$PrimaryEmail" ; AdditionalEmailAddress = "$AdditionalEmail"}
}
else {
    Write-Output "Nothing to do here, exiting"
    Exit
}

<#

> Get-AzSupportService                                                                     
Name                                 DisplayName
----                                 -----------
484e2236-bc6d-b1bb-76d2-7d09278cf9ea Activity Logs
26d8424b-0a41-4443-cbc6-0309ea8708d0 Advisor
1232100c-42c0-f626-2b4f-8c8a4877acad AKS Edge Essentials
c1840ac9-309f-f235-c0ae-4782f283b698 Alerts and Action Groups
e8fe7c6f-d883-c57f-6576-cf801ca30653 Analysis Services
07651e65-958a-0877-36f3-61bbba85d783 API for FHIR
b4d0e877-0166-0474-9a76-b5be30ba40e4 API Management Service
862f5cc8-0f41-97a5-d2d8-940d7aba6de4 App Compliance Automation Tool for M365 - Preview
e14f616b-42c5-4515-3d7c-67935eece51a App Configuration
445c0905-55e2-4f42-d853-ec9e17a5180e App Service Certificates
b7d2f8b7-7d20-cf2f-ddd5-5543ada54bd2 App Service Domains
0420c0b3-5e23-1475-d8ad-c883ef940b46 App Service on Azure Stack Hub
101732bb-31af-ee61-7c16-d4ad77c86a50 Application Gateway
63df7848-ce1c-06d4-517f-2a62983372c6 Application Insights
2fd37acf-7616-eae7-546b-1a78a16d11b5 ASE
b661f9c2-28ee-800a-b621-118a6787a8e6 Automanage for Virtual Machines
81437870-7683-745e-1c1f-7d9e7e2401ef Automanage Machine Configuration
82881226-e06c-2b57-3365-38437e84059e Autoscale
c2514c34-3bf2-9e82-0119-17da8f366a19 Avere Legacy
500d88b2-c24c-0d5d-3b76-acfde7d6ee20 Avere vFXT
7505036e-a364-8354-e894-56d394dd4a61 Azure Active Directory App Integration and Development
b16f3aa1-e798-0090-9159-5dc3bae17c5b Azure Active Directory Business To Consumer (B2C)
3a36c1ba-f910-91c3-9f17-075d63c9488a Azure Active Directory Directories, Domains, and Objects
a69d6bc1-d1db-61e6-2668-451ae3784f86 Azure Active Directory Domain Services (Microsoft Managed - DCaaS)
b98631b1-d53a-3ac4-3181-aef136ec703d Azure Active Directory Governance, Compliance and Reporting
516fe906-3a1a-2878-02fd-8dd37ea207de Azure Active Directory Sign-In and Multi-Factor Authentication
38a234dd-6baf-d93b-2c48-5a735a3550ed Azure Active Directory User Provisioning and Synchronization
ab3e222e-3538-2b59-d3e8-963047a08f8b Azure Arc enabled Data Services
11689be9-43d7-ba72-5806-03ab87626a4a Azure Arc enabled Kubernetes
9ef6b6ba-0bb2-e927-2ea7-32f90a97414d Azure Arc enabled PostgreSQL - Preview
bdb8e8ae-3bba-4c43-e8ad-36e132e481ef Azure Arc enabled SCVMM
17318db1-cfda-52da-b65f-68e53ba89e64 Azure Arc enabled servers
f6575f88-34bc-79d3-8693-05ee9b7ca72b Azure Arc enabled SQL Managed Instance
8dfc5d56-9245-222f-19fc-dfafc3fba973 Azure Arc enabled SQL Server
2d45b14d-73cf-eb4b-0dc3-6ee86904c64b Azure Arc enabled VMware vSphere - Preview
216cb580-99ad-5c86-d60e-72aca32dc2a2 Azure Arc Resource Bridge - Preview
90426252-f966-63ea-cbda-cab5ceaa865d Azure Automation
17d72dfc-8f48-94cb-05e6-5f88efdf72d7 Azure Backup
58cf91d7-3a04-37d3-9818-9bd5c979d9a9 Azure CDN
6d25bd66-1b18-21ea-1c39-50d27ccbc816 Azure Compute Gallery
aec6da31-9ef4-f890-e34c-ec1fbac8e6b1 Azure Cosmos DB for PostgreSQL
3f14906b-a48e-b51a-d700-b3eb7784bce8 Azure Database for MariaDB
7ef8ab5c-3c21-c342-8eed-2b5a8fc7fba3 Azure Database for MySQL flexible server
32b3cec2-0abd-1d18-68cc-9183b15b7da1 Azure Database for MySQL single server
191ddd48-d790-61f4-315b-f621cdd66a91 Azure Database for PostgreSQL flexible server
12a55468-fa60-8943-45e2-338011722931 Azure Database for PostgreSQL single server
b9c52334-7da1-7360-b396-0406b0c9d3b7 Azure Dedicated Host
cd1e630f-be69-dde7-f0ee-899b33e765d6 Azure Deployment Environments - Preview
cd9d74ec-8333-b326-f42f-303e223e04eb Azure DevOps Services
985987a3-2363-99eb-321b-c753677e0008 Azure Digital Twins
f0269138-eb6e-a81a-10e9-17965b5683d4 Azure DNS
5b807b4a-60ff-3256-faf1-5934bd59b4b9 Azure Edge Hardware Center
3b799b70-420a-6397-e69c-853341d0eab5 Azure Firewall
f1e803c0-d4aa-156d-8507-3f9e5e4e1504 Azure Firewall Manager
025f80a1-8242-b74c-6a4a-f01341b8669b Azure Fluid Relay
3d598a6c-5432-adab-e87a-1dfdbb562302 Azure FXT Edge Filer
be63f24b-d7d7-fac8-d753-388658582f99 Azure Health Data Services
8ab9233e-aa65-ab0a-cf6f-7e4ec528556a Azure Healthcare Bot
036bd7f8-ead3-3a43-e7f9-cda1e3ad0120 Azure Import-Export Service
8168c456-2014-a581-dde8-d25e47d964c8 Azure Information Protection
e29406fa-af70-5215-e29b-9c9b7f5204d3 Azure Kinect Dev Kit
70d82de6-3222-8f21-71f8-1912ba5ad0ae Azure Kubernetes Fleet Manager - Preview
32545be3-202c-9cd6-2031-98e763d29b5e Azure Kubernetes Service on Azure Stack HCI (AKS-HCI)
88a4d9f6-1d66-7b9a-32fe-e5a965e0c099 Azure Load Testing - Preview
07112d69-b92c-27dd-4864-ff0d63e503fd Azure Managed Grafana
ef44dd7b-4344-edcf-2eb1-f6f094fd46a3 Azure Migrate
06d6dec8-469a-b652-f8e8-61e47c34efef Azure mobile app (for Android & iOS)
86490df1-3db5-08c6-1f6b-4138be52adb9 Azure Monitor for SAP Solutions - Preview
824615f0-1b01-931d-1e1c-36516330ec6d Azure Native Qumulo Scalable File Service - Preview
00743e6b-ddfd-e1cb-b90e-2a9f8d1c2a52 Azure NetApp Files
25aa2af2-9b6e-96b5-ce85-d784a0fea138 Azure Object Anchors - Preview
88f7fa12-ffd2-e080-ab1f-16aa954adbfb Azure Operator Distributed Services - Preview
c8be3b31-c407-ee77-e40d-ffa6a39201bd Azure Orbital
ce34cf91-b52e-afe9-57d6-1baf3ff5a59b Azure Payment HSM Service
03dc29df-b9ef-75cc-9bce-d87f55dd0f73 Azure Percept
10b4ca52-06e3-3064-3788-5b396ae8ff45 Azure Policy
2b3d28b4-4691-86b5-8a82-22f8e26b2e5e Azure Private 5G Core
50cb0c81-4dee-0e4e-d7bd-caa5560e76af Azure Private Link
0dbbd8bb-01d0-3b18-97d8-091ab1b40558 Azure public Multi-Access Edge Compute (MEC)
c20fd445-607c-6af4-8dff-7e248c950344 Azure Quantum - Preview
b701b8d6-fc99-aba8-bab9-bc2e171fa89c Azure RedHat OpenShift
cb6b214b-fbeb-8fd1-a055-3d60bbe81c28 Azure Resource Graph
3366336e-70d9-3450-f04d-5eecce9374fe Azure Resource Mover
c0ea59a0-318d-3a01-8b10-eeb155952e7c Azure Route Server
7ab45c4c-7827-cedf-07bd-2b38f63540ae Azure RTOS
b1d432df-e9cc-ff08-d261-32586b843bc1 Azure Site Recovery
a6475480-6048-1d77-76fc-3118551f24c1 Azure Sphere
bbc183d4-df10-8580-d10b-4123c10ae34d Azure Spring Apps
2950380d-f11a-136b-1b95-017b71f25ef8 Azure Stack Edge
297c5dfa-56dd-8040-1ae5-88f78d60e055 Azure Stack Edge Mini R
65f78722-e5a1-858a-6d66-0d5640d688a2 Azure Stack Edge Pro R
5804950e-8756-4711-367a-57965175f0ad Azure Stack HCI
32d322a8-acae-202d-e9a9-7371dccf381b Azure Stack Hub
47e87a02-77c6-23d1-bdd3-858d9b64d4e0 Azure Stack Hub Ruggedized
ba5ef5c8-031a-aa1e-76b6-bd58e6f5c452 Azure Storage Mover - Preview
1dcbb98a-fbff-9e2a-08c6-0f1fbe934906 Azure StorSimple 1200 Series
9fccedfd-3d56-635e-e377-c72e2cdb402f Azure StorSimple 8000 Series
9f858284-99ed-c476-0dc6-75be58efedfb Azure Synapse Analytics Apache Spark Pool
5e76fec8-ad4b-4350-47e6-9b90efd844dc Azure Synapse Analytics Data Explorer Pool
6175465c-97bb-e2fe-3e94-a8ffccdb3dd1 Azure Synapse Analytics Dedicated SQL Pool
b25ffe84-5478-16e3-3427-00fdf5a5cd91 Azure Synapse Analytics Pipeline and Data Flow
19726725-bf71-155c-a930-1fca742d1b87 Azure Synapse Analytics Serverless SQL Pool
b5fc3c5d-ce14-ef83-5816-89984205d0e5 Azure Synapse Analytics Synapse Link
8d8fb5f1-f55d-f3c6-8d4b-ab84f9084bca Azure Synapse Analytics Workspace
9112da51-73b5-92d8-3f2e-1fddb504f4b5 Azure Synapse Pathway
393f9162-a29a-1e9f-1972-d524c7bc7026 Azure Video Indexer
63cefc01-98f2-7ef4-2b5f-0c4b268a7dad Azure Virtual Desktop
0030df58-1e6e-8958-770e-1ba656360372 Azure Virtual Network Manager - Preview
8df50d5e-6cdd-3a3a-0cb5-95dbef9e09ab Azure VM Image Builder
e7b24d57-0431-7d60-a4bf-e28adc11d23e Azure VMware Solution
440fc530-a802-3276-f67b-7c39d1c8e972 Azure VMware Solution by CloudSimple
a4ecd5be-8461-dde6-6761-353dc7d7bf54 Azure Web PubSub Service
ec9fcee4-7ede-9ba9-7edb-0e6b95428ea5 Azure Workbooks
468c696a-3e6b-a470-a3c9-1b59cd4abae4 BareMetal Infrastructure
ffc9bb42-93e4-eb40-5421-ba3537f3a012 Bastion
3f33d852-e61f-d835-8217-a9a677d96914 Batch Service
517f2da6-78fd-0498-4e22-ad26996b1dfc Billing
a2c69e6c-34b6-fc5d-0f35-b496a071c28d Blob Storage
f26f06d5-c3b1-0372-8c5b-93a371ec434c Blueprint - Preview
98134488-9bd9-db12-619c-06636d1ee55e Bot Service
275635f1-6a9b-cca1-af9e-c379b30890ff Cache for Redis
18f0ceb2-fe97-722d-f789-0dfcde3ab2e4 Cache for Redis Enterprise
2b6e85ee-b01f-0479-f799-b37634d993e3 Change Analysis
c508dfe2-0a4d-06b0-67a2-28cef284d243 Change Tracking and Inventory
70e113c2-39fd-2640-f1f5-fd5a6beaefa7 Chaos Studio - Preview
2f9ed23d-9575-75e3-cdfb-3e9a5ad5223c Cloud App Discovery
c4b5fb5c-e277-0fba-1a6e-967912edac0c Cloud Service (Extended Support) (Web roles/Worker roles)
e79dcabe-5f77-3326-2112-74487e1e5f78 Cloud Services (Web roles/Worker roles)
70a6ce77-640d-fb3b-d2e2-942c479a929b Cloud Shell
87112f97-cf14-d714-03cb-28af2e422e31 Cognitive Services
c811355a-31ae-acc0-7364-60bc67ab4ca7 Cognitive Services-All-in-One Key
3c9e9005-bd01-4331-8483-68c4c0a9c1b9 Cognitive Services-Anomaly Detector
9e65c540-e7ae-b43c-1e0a-ba8dc860dbbd Cognitive Services-Bing Custom Search
355c72f1-6700-8523-f274-8b65d1f10c7b Cognitive Services-Bing Search
71e0f29e-91d4-acb4-329e-fb16cd7c366e Cognitive Services-Bing Spell Check
00677266-37a0-73ba-d7c4-ad3c814b2b11 Cognitive Services-Computer Vision
7f35b180-0014-494f-df00-68fc50a92976 Cognitive Services-Content Moderator
6dfefaed-7312-8350-bbe6-c452fe5749c7 Cognitive Services-Custom Vision
01cde781-0618-be89-60ce-14ca8e939c7d Cognitive Services-Face API
1a8bf6aa-6385-da93-8884-b1de5934f242 Cognitive Services-Form Recognizer
e78c1fb0-1fd4-7ad6-df28-6b8d6f2c803f Cognitive Services-Immersive Reader
7faf083e-7dd5-a35b-ba18-52eeac29d9a1 Cognitive Services-LUIS
97c076d2-d123-a335-a64b-362198ae7004 Cognitive Services-Metrics Advisor
13fc6b1d-b65d-0800-19e3-77521c7e4e09 Cognitive Services-Personalizer
9a2cd2eb-f793-9717-a145-3497086f40b4 Cognitive Services-QnA Maker
8d2d990b-173c-fbee-3913-05e3f338b67b Cognitive Services-Speech Services
b1bfd43f-f4f6-7e3c-4a01-ed74b71b6dd7 Cognitive Services-Text Analytics
4bc4301f-b40e-080d-9252-a523f88a16e7 Cognitive Services-Translator Text
2e9d497d-e486-8d76-3582-ad201c974730 Communication Services
98594b2e-741c-7d1c-2eb5-b06e25670cc4 Communications Gateway
6db223ca-4ea9-41b9-af8a-61a0a5b6a150 Confidential Ledger
6f3d78e8-246d-880c-acec-31033f3a7a8f Confluent on Azure
5bc1fc7c-358f-3640-9d3f-f051a51c1e93 Container Apps
44557205-b0ce-df77-a5b5-5e145323f4a1 Container insights
fd718335-8143-4759-bb14-cf7cff4f585e Container Instances
f100a6d5-17df-c517-a2bc-ecc2a5bfb975 Container Registry
201a3899-cb54-d8ec-d02f-7b0a4fd0d67f Container Registry on Azure Stack Hub - Preview
d9516a10-74b5-45f4-943d-a5281d7cf1bb Cosmos DB
33476b0f-7f52-9f63-56d0-5924636304ff Customer Lockbox for Microsoft Azure
53cdda84-33c0-81db-6a25-adaac64419d6 CycleCloud
a091fbc6-3624-42e8-4b3c-654a29d6958e Data Box
5d6f97e5-c9cf-e3c7-98e0-6011d194d84f Data Box Gateway
9a7df480-f592-a980-906c-bd1fd3060aa8 Data Catalog
f0bd9b83-fcdc-15ec-a9db-47068d512d4f Data Collection Rules (DCR) and Agent (AMA)
0d06686e-fac3-fde3-a8c1-6dfbc8bd3865 Data Explorer
113715b9-70c6-3019-fa70-5d9f0c15c610 Data Factory
eea96939-cf20-792a-ed0a-f11eb11336df Data Lake Analytics
7ecbaeae-c1bc-285f-a3bd-b5a3ba00b294 Data Lake Storage Gen1
a95c4ceb-9637-4484-2205-d1162a7d2249 Data Lake Storage Gen2
0c1a625e-85d1-f83b-7248-2367293c9d85 Data Share
8c615be4-9081-f10c-5866-afa4fab9666d Database Migration Service
3461f86b-df79-07f2-aad9-34a81b2d9023 Databricks
251a4e5f-1aac-be01-3279-4249c348b4cb Datadog on Azure
d22650a0-c129-647b-967c-fb18c83584c6 DDOS Protection
7d1ce754-b825-74b6-8022-87193cd96b6e Dedicated HSM
546aaccb-cb73-2d7a-546f-e4001c2a0670 Device Update for IoT Hub
5405fb26-173b-7571-9998-98e23cd8643d DevTest Labs
39dc26f0-c1b1-2323-c39f-3ae3860e0c37 Diagnostic Logs and Diagnostic Settings
41331489-2fbf-a39d-d107-fefba43bc4af Disk Pools
1d311e9b-0852-2f19-07bf-22f48e57d71a Disk Storage
633d88dc-7cf1-cc96-7053-3552fcc9235a Dynatrace on Azure
8b583bd0-6368-dc07-8719-f7d94a4ea536 Elastic on Azure
a79c6645-e39b-3410-6e3c-24c6b96b616b Enrollment administration
bfe4c4f0-96eb-41a9-a9aa-23a3b5ed9974 Event Grid
e8b3dd28-f3eb-c73f-e03a-20159685defa Event Grid on Kubernetes with Azure Arc - Preview
4fa35c58-016c-a25b-4105-bd667c24ab1f Event Hubs
48ffed53-baf4-c26a-c7a1-4bea807be2a0 Event Hubs on Azure Stack Hub
759b4975-eee7-178d-6996-31047d078bf2 ExpressRoute
74e3c1c3-412f-e934-70c5-24629ea33cf7 ExpressRoute Direct
ce989245-7b7b-ab4f-ac5a-a4ca2ee9d2a2 ExpressRoute Service Provider
30dfd88b-b455-1748-a4a0-e4c5aa795663 Files Storage
fafcf178-45ee-85df-ef14-982729bf2f82 Front Door Service
2a1d6261-5ecd-a128-739f-9bd4f2154ba5 Front Door Standard and Premium
5ce8de69-abba-65a0-e0e4-a684bcbc7931 Function App
24629f4c-b450-03f7-aa4f-e2c48f422560 Function App on Azure Arc
427b19fb-0b81-d9e9-f443-83e78bb5d47f GHAE
5ffad63a-3267-d6b7-2fa1-6d9134c1fa62 HDInsight Service
e00b1ed8-fc24-fef4-6f4c-36d963708ae1 High Performance Computing (HPC)
6b415938-2927-0d9d-6c3c-fbacea64e42d HPC Cache
ecba36d5-97f3-bc2f-33d0-f1bae2547fb8 Insights for Azure Cache for Redis
a25f6c13-8267-c757-d267-94999f8b395b Insights for Azure Data Explorer clusters
9f7ef27e-7bdb-0570-4e15-f50c870f03aa Insights for Azure Stack HCI - Preview
34efaf67-544f-5186-0680-6a67d789c694 Insights for SQL - Preview
370cf612-d7bd-b9e5-5a3c-42532257212c Intelligent Recommendations
fb35bf64-b744-16ba-68d1-e1853af0816e IoT Central
ea37799f-166b-c702-e4d1-e17fa52b2984 IoT Device Provisioning Service
0ebfa061-1e74-5f8f-ed46-5a46e13e5d33 IoT Edge
b8b1c1dd-dfe1-63e8-cc06-e6a1a1c5a853 IoT Hub
4ba83714-c274-28d6-af7f-43c12863bf2f IoT SDKs
e7c01763-5374-faf0-d1ac-1719f8da4612 IP Services
0283d26b-bad8-f0e2-37f4-86dc0328c710 Key Vault
8f1ddc5f-0c5e-50c7-9810-e01a8d1da925 Kubernetes (AKS Engine) on Azure Stack Hub
5a3a423f-8667-9095-1770-0a554a934512 Kubernetes Service (AKS)
7f2f38ed-ca01-fd3a-b7d4-d029e970f574 Kubernetes Service (AKS) on Azure Stack Hub - Preview
b8925cb6-338d-9b0c-2655-1ef611982fc4 Lab Services with lab account
9c87a292-835f-d089-8368-9a6daaad2f24 Lab Services with lab plan
b0882e3d-d09c-ca61-725b-b5d318365454 Lighthouse
7b29574f-b855-9dec-9b08-fe4aeaa3bbc0 Load Balancer
1bfb8072-ed96-9acc-b57c-34d716b5f674 Log Analytics
908d4c6f-e217-fecc-1fd8-284779c5aaf5 Log Analytics agent (MMA and OMS)
9239daee-9951-e495-0aee-bf6b73708882 Logic App
bd329b99-32f4-07bf-22e1-717f87d355b9 Logic App on Azure Arc
65e73690-23aa-be68-83be-a6b9bd188345 Logic App-Integration Service Environment (ISE)
6a2a5a09-c969-3adc-bc12-bfd87296f968 Logic App-Logic App (Standard)
68ad5d5e-ba0d-c8d9-7642-1278dfc99ad3 Logz.io on Azure
a1799293-1194-133d-4407-156c57152643 Machine Learning
afd16b5d-3a02-dd9d-8f7f-9768a7345f81 Machine Learning Studio (Classic)
7fa9504c-364e-66b7-830e-f1333a2e4fe4 Managed Apps Service Catalog
c967e89c-dd01-34fa-231a-5645bdd79459 Managed HSM
4600d245-9a8d-be9c-b0b7-945467c24186 Managed Identities for Azure Resources
c6054aa4-96df-3b22-b4bf-1c5b16912def Managed Instance for Apache Cassandra
1b982b2f-8561-caed-b2b3-aed8c249bb07 Managed Prometheus - Preview
2c32f727-0b95-8324-22c8-b953c938833c Management Groups
c52a04cc-be90-03ef-d76e-80cd1b338fb3 Maps
efa0fcb8-3325-6eb7-b451-8e3a853aaead Media Service
9636b9f4-3013-b4d0-1dbe-8b202575f592 Metrics
a96cb196-59fe-00a7-5ff7-889765d10494 Microsoft Antimalware for Azure
a3247669-8dd8-ffa6-e0b2-c603cb95bf6c Microsoft Azure Attestation
9db8a797-7fec-d348-fc3e-c24665973f2c Microsoft Azure Center for SAP solutions - Preview
fca74ae8-fb8b-53d4-39cb-105200f54379 Microsoft Bing Services
2dd10780-72c7-5527-32c3-2cd565a9857b Microsoft build of OpenJDK
49741e2b-0418-835b-8305-2e3992042a28 Microsoft Connected Vehicle Platform
d3f5a8bd-677e-f210-8c9a-9b0bd8a2ee8c Microsoft Defender External Attack Surface Management (EASM)
fb1b37f8-2716-86c2-c2e1-684b5292d401 Microsoft Defender for Cloud
7dc03991-4dcf-cf5a-904f-35a243ca5551 Microsoft Defender for Cloud Apps
809e8afe-489e-08b0-95f2-08f835a383e8 Microsoft Defender for Identity
82c88f35-1b8e-f274-ec11-c6efdd6dd099 Microsoft Defender for IoT
8b8d5b15-1c6d-7fa4-3884-e134fa0adaa7 Microsoft Dev Box - Preview
6d7a548d-93fe-2d06-23d6-8a7f7c9981d1 Microsoft Energy Data Services - Preview
0d9aae13-ff27-8f75-6e18-304247937071 Microsoft Entra Permissions Management
3f816e19-cbf7-f192-a725-63c0ebe7d07d Microsoft Genomics
e76cbe81-8c12-1f2f-85c7-6064644116a4 Microsoft Graph Authentication and Authorization (Azure AD)
437e7d94-a4b3-68bd-a23a-087f528d47dd Microsoft Graph Files, Sites and Lists APIs
af52d398-4ddb-1e1d-2c6c-6767634b015e Microsoft Graph Messages, Calendar and Contacts APIs
c9a40005-5758-83c0-32b8-9e7910c21595 Microsoft Graph Other Microsoft Graph APIs
46c9bb77-3f94-f481-375c-911d8f0f9a0e Microsoft Graph Teamwork APIs (Teams)
53aa5987-de52-9110-f612-9fe34980e53a Microsoft Graph Users, Groups, and Identity and Access APIs
389d15a1-c6fa-bbb6-f3fd-523a62a2b3c5 Microsoft Intune
a674bd96-b6a2-0636-3fb9-c665e6497b88 Microsoft Purview
ce08c87f-a4b1-24e7-5e27-dd7f8282da40 Microsoft Security Code Analysis
9cd60433-a646-8748-7e7f-fd0781fea78e Microsoft Sentinel
5280bdc9-af4d-0716-24b9-4ec6b7523c01 Microsoft Test Base
4b38e388-9d77-9c61-da1e-4d92d751e51f Modular Datacenter (MDC)
b7743438-942e-ef29-9abc-589fd697fb9e Network Performance Monitor (NPM)
01c5defa-028b-c44f-cefa-e5d836887f2e Network Virtual Appliance
29297681-a8c0-eaa9-341f-f72630a5b9c3 Network Watcher
b773917a-ba16-d351-b92e-3f0a6a2e65ac NGINX on Azure
b9710604-e660-5d57-1b18-3aef73bd21d3 Notification Hub
e7735f37-971a-bdb3-8222-3628413e826a Nutanix Cluster on Azure
cac35d2a-0335-5628-57ff-db564fda4f3a Odyssey
176fac6b-1982-68b4-6f2e-3e5d3a0c99a4 Open Datasets
7d7bdc73-e381-941a-28e6-b60656de5df0 OpenAI
3e5e1bc3-2000-2473-a9cd-35edf7ae7f5f Partner Solutions
fae15df4-4549-8074-e6ab-11ca2b5a1645 Peering Service
6d3f465f-843e-e142-40aa-fd1eda4c80c8 Portal
3faebc17-db7f-212f-8536-9a5048474831 Power BI Embedded
86d840c0-45c7-7931-24bc-f976ddc54c1c Power BI Report Server in VM
17cbfbe8-fbbe-a755-4cbc-14e025c370cd PyTorch Enterprise
5d4f816f-f02c-f8f8-a8f4-423509f8b036 Queue Storage
351dadd2-b167-7960-06bc-be843b705826 Relay
4b218fe9-a91b-9143-05e3-da8c5a9bd5c7 Remote Rendering
c2804d27-8e0a-f2a3-8540-f4318f539ff6 Role Based Access Control (RBAC) for Azure Resources (IAM)
4b42e182-ce1c-ee75-e32b-e85fe73d6fbb SAP Cloud Platform
dd1ed832-cfdd-b06b-d11b-77b590a10d4c SAP HANA Large Instance
f90fce27-e23e-9db8-cbf3-0f9a879b3a62 SCOM Managed Instance - Preview
1b9679f1-9cb9-a8db-549e-2fcdfbb89e7c Search
0abb876a-a5f2-b881-f49e-dc6157fd07bd Security Incident Response
06bfd9d3-516b-d5c6-5802-169c800dec89 Service and subscription limits (quotas)
23e2c469-4b37-ebf5-0a3f-72e8b1407301 Service Bus
a730ab7a-33ae-c83a-bca5-4935433e38ff Service Fabric
c9d3b345-6b9c-bc78-88f5-4867854e925a Service Fabric Managed Cluster
a76b7230-2d2f-b294-8189-319db5e5d116 Service Fabric on Linux
bfd77156-870d-17ee-c9d1-5450f390f63f SignalR Service
e4ddc3b0-1e6d-aaa2-4279-8e5027351d76 Spatial Anchors
95412dd5-f222-a91f-98a6-144a84418c66 SQL Database
9b629e89-4ea0-53ec-9409-1579b8c41453 SQL Managed Instance
40ef020e-8ae7-8d57-b538-9153c47cee69 SQL Server in VM - Linux
53b14ef9-9b69-4d8c-a458-b8e4c132a815 SQL Server in VM - Windows
effcf656-f62f-92f2-8cef-2b28aea2da1f SQL Server Stretch Database
0ef96678-fa9b-9ea2-2cdc-39ee36e1f4db Start-Stop V2
94a7406a-b31a-86f8-49f9-377d30047b25 Static Web Apps
6a9c20ed-85c7-c289-d5e2-560da8f2a7c8 Storage Account Management
94c5f326-7ab1-6ef3-c3c0-8e0b5a584085 Storage Explorer
30e73728-5d13-cbf4-5c57-3036ed1067fd Stream Analytics
f3dc5421-79ef-1efa-41a5-42bf3cbb52c6 Subscription management
8418caaf-4634-b4c0-d9b6-27c266b6b67b Table Storage
e4d6b9b0-79d5-3133-c4db-460a39e8a622 Time Series Insights
66fff2d6-c34e-ac9b-d1ba-6631ab20989e Traffic Manager – DNS based load balancing
99dd2657-2a74-8c5a-951f-23abdd7851c6 Universal Print
5c41904f-1bcf-76e4-7a54-5fc07468f3cc Update management center - Preview
722ccc66-c988-d2ac-1ec6-b7aebc857f2d Virtual Machine running Citrix
b6492139-637a-c445-ee02-5dc6749337c3 Virtual Machine running Cloud Foundry
cddd3eb5-1830-b494-44fd-782f691479dc Virtual Machine running Linux
de8937fc-74cc-daa7-2639-e1fe433dcb87 Virtual Machine running RedHat
f66fac5c-01e5-e8db-2ef8-e1a98a88e214 Virtual Machine running SAP
98e5cec8-2650-28c1-92e8-0ecaa232eec0 Virtual Machine running SUSE
2340ae8b-c745-572f-6ea8-661d68c08bd7 Virtual Machine running Ubuntu
6f16735c-b0ae-b275-ad3a-03479cfa1396 Virtual Machine running Windows
e9e31931-21fa-d50a-e6e7-e37d5d784591 Virtual Machine Scale Sets
b25271d3-6431-dfbc-5f12-5693326809b3 Virtual Network
e980d0ab-c6c3-894b-8a1d-74564e159e3b Virtual Network NAT
d3b69052-33aa-55e7-6d30-ebb7040f9766 Virtual WAN
4268a408-46cf-347c-6806-09dc5967d2f6 VM insights
5a813df8-0060-7015-892d-9f17015a6706 VPN Gateway
b452a42b-3779-64de-532c-8a32738357a6 Web App (Linux)
1890289e-747c-7ef6-b4f5-b1dbb0bead28 Web App (Windows)
d40f17bb-8b19-117c-f69a-d1be4187f657 Web App for Containers
272fd66a-e8b1-260f-0066-01caae8895cf Web App on Azure Arc
6ad1058f-d6a2-bfcb-9aad-1ab895e39c02 Web Application Firewall (WAF)
f7eb21eb-eb80-8817-4bd8-c0d89e93833b Windows Admin Center in the Azure Portal
66ea76c9-5d31-568e-cf01-919415d2756c Windows Update for Business Reports


> Get-AzSupportProblemClassification -ServiceName 06bfd9d3-516b-d5c6-5802-169c800dec89 
Name                                 DisplayName
----                                 -----------
7e2c375c-2383-b50f-1d14-cdf15f17478b Action groups
38d30c86-d4e3-aa14-bdee-167725f7ccd0 Active Directory
805b9781-4c0c-9740-b714-af2c69a58af8 Alerts
41dddec0-4071-9086-60b7-fd94ab2a6c6d Application Insights
f5327750-42cb-2667-1086-f53ee3c23c0d Autoscale
2ef73080-8fd9-19d2-de9c-fc8594dcf71f Azure Database for MariaDB
a651f078-f88c-b811-4720-8943f30ffb7b Azure Database for MySQL single server
404eb2fd-b3d5-7751-3063-1e8cd0fa50e7 Azure Database for PostgreSQL single server
f3288da4-4d60-5b10-7091-98dcf73ca91f Azure Healthcare APIs
4c6012da-5dcf-7a3a-43b4-99ec73125c83 Azure Lab Services
1e43cc7f-7ff1-9a9a-2b32-eddc9c67c618 Azure Load Testing
6181ccf6-28d6-7843-76d4-4f3c1ad88e7a Azure Purview
a8bd999a-1389-6508-d4a8-bda7616e88e3 Azure Quantum
6a6d517d-5de7-f0ed-356f-e70fa3ee2a09 Azure RemoteApp
0bc962e0-5f61-f291-1919-24a6241c843a Azure Synapse Analytics
831b2fb3-4db3-3d32-af35-bbb3d3eaeba2 Batch
37700aeb-d9ba-400a-31db-ee2ef09aec97 CDN
e0709e43-3f96-13c1-050f-e3b0891922b0 Cloud Services
2a0a9b68-0981-14f4-d590-a7eecb8d6bee Cognitive Services
e12e3d1d-7fa0-af33-c6d0-3c50df9658a3 Compute-VM (cores-vCPUs) subscription limit increases
a11041c8-bf9f-820b-f1ef-c859995c6040 Container Instances
a8237f6d-9e1e-1b82-c001-723cb8ad8cfa Cosmos DB
de105c19-f61a-b826-0761-aa51bb935682 Data Factory
6c436f2a-bf67-9d05-a887-67ff74f512c0 Data Lake Analytics
fa707566-4d6b-35b8-b8da-fb28b5f3dfce DNS
8d34ed57-45e4-7de5-c098-282a560812b0 Event Hub
fb2b3a54-7782-1ec1-30f1-9b13c6071c9d Genomics
917919a1-68f9-199b-e6b2-0f20631763e4 HDInsight
7a6d4622-bdc6-24ff-1b47-25bc03ca0a04 HPC Cache
9c6b13e6-097a-36b1-fe05-3195b5e20942 Machine Learning Service: Cluster Quota
8203c025-412c-f0c2-229a-142d6267f2ee Machine Learning Service: Endpoint Limits
28219731-78c4-da47-b70a-120b7c35856e Machine Learning Service: Spark vCore Quota
c8800fe7-23e4-8cca-0d90-2379734c0006 Machine Learning Service: Virtual Machine Quota
a12efd28-299b-2fef-a7c4-91424f798270 Managed Prometheus
eb747862-5a4c-b6de-e173-02095d17fd4d Media Services
16becfc4-de9a-4db5-90fd-5051b67ad309 Microsoft Dev Box
d37c211c-4257-d859-ffa8-68bd54d8d188 Mobile Engagement
3460e0f5-0881-e6b5-6abd-07b4f233c000 Multi - Factor Authentication
4b994745-d2fe-c6cf-00d0-b358c8526f2d Networking
599a339a-a959-d783-24fc-81a42d3fd5fb Other Requests
2f3107e0-e21c-8c17-391b-0f9c4ca5f47a Search
1f8b6f41-52fd-aaec-1cbb-fca2273ae421 Service Bus
95bae7c6-a1ad-9477-7eb5-706424cfb6b6 SQL database
83ab35e7-7b4d-819e-be8f-3c20a8554920 SQL Database Managed Instance
2e1abb1b-2428-9a2f-6521-01c708d0bb4b Storage: Accounts limit for Classic
22f96a7f-37b3-1504-0258-909e9f5ab3ac Storage: Azure NetApp Files limits
e2c2bb3e-3ec6-5f1b-0eb0-53acab1f2b3a Storage: Managed Disks limits
42f49519-c88b-0328-cc2a-96919e4f5655 Storage: Per account limits
10c0d1d7-a9dd-ffe2-bfe7-fa47f13163fe Stream Analytics
ecb0610e-9f64-003f-89a3-a24c01dc2706 Traffic Manager





$Location = 'East US'
$VMSize = 'Standard_B2ms'
$SKU = Get-AzComputeResourceSku -Location $Location | where ResourceType -eq "virtualMachines" | select Name,Family
$VMFamily = ($SKU | where Name -eq $VMSize | select -Property Family).Family
$Usage = Get-AzVMUsage -Location $Location | Where-Object { $_.Name.Value -eq $VMFamily } 
$Usage = Get-AzVMUsage -Location $Location | Where-Object { $_.Name.Value -eq $VMFamily } | Select-Object @{label="Name";expression={$_.name.LocalizedValue}},currentvalue,limit, @{label="PercentageUsed";expression={[math]::Round(($_.currentvalue/$_.limit)*100,1)}}


$Usage = Get-AzVMUsage -Location $Location | select @{label="Name";expression={$_.name.LocalizedValue}},currentvalue,limit, @{label="PercentageUsed";expression={[math]::Round(($_.currentvalue/$_.limit)*100,1)}},@{label="Location";expression={$loc}}

Get-AzVMUsage -Location $Location | Select-Object @{Name = 'Name';Expression = {"$($_.Name.LocalizedValue)"}},CurrentValue,Limit,@{Name = 'PercentUsed';Expression = {"{0:P2}" -f ($_.CurrentValue / $_.Limit)}}  | sort-object  { [INT]($_.percentused -replace '%')  } -descending


Write-Output "$($Usage.Name.LocalizedValue): You have consumed Percentage: $($USage.PercentageUsed)% | $($Usage.CurrentValue) /$($Usage.Limit)  / available quota"




#>

