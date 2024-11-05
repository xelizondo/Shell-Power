#Connect-AzAccount -Tenant "af733ba9-a713-454b-1b4b5"
 
param (
    [Parameter (Mandatory=$false)]
    [string] $SubId = "edf6dd9d-7c4a-0000-11111111",
    [Parameter (Mandatory=$false)]
    [string] $tenantId = "8dc94566-0000-4aad-51b2222",
    [Parameter (Mandatory= $true)]
    [string] $ResourceGroupOfMachine = "rg-arc-onsite",
    [Parameter (Mandatory= $true)]
    [string] $ResourceGroupOfLicense = "rg-arc-onsite",
    [Parameter (Mandatory= $true)]
    [string] $license_name = "lic-arc-esu-win2012-std",
    [Parameter (Mandatory= $true)]
    [string] $MachineName = "ARC-VM-01",   
    [Parameter (Mandatory= $false)]
    [string] $service_principal_id = "8625dbbc-0000-4e65-b3050000",
    [Parameter (Mandatory= $false)]
    [string] $sp_secret = "U3G8Q~2a.C.-KS~VxHx5sNWGHWaU1P111111111"
)
 
$SecureStringPwd = $sp_secret | ConvertTo-SecureString -AsPlainText -Force
$pscredential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $service_principal_id,$SecureStringPwd
Connect-AzAccount -ServicePrincipal -Credential $pscredential -Tenant $tenantId
 
$token = (Get-AzAccessToken -ResourceUrl 'https://management.azure.com').Token
$headers = @{Authorization="Bearer $token"}
 
 
function CheckModule ($m) {
 
    # This function ensures that the specified module is imported into the session
    # If module is already imported - do nothing
 
    if (!(Get-Module | Where-Object {$_.Name -eq $m})) {
         # If module is not imported, but available on disk then import
        if (Get-Module -ListAvailable | Where-Object {$_.Name -eq $m}) {
            Import-Module $m
        }
        else {
 
            # If module is not imported, not available on disk, but is in online gallery then install and import
            if (Find-Module -Name $m | Where-Object {$_.Name -eq $m}) {
                Install-Module -Name $m -Force -Verbose -Scope CurrentUser
                Import-Module $m
            }
            else {
 
                # If module is not imported, not available and not in online gallery then abort
                write-host "Module $m not imported, not available and not in online gallery, exiting."
                EXIT 1
            }
        }
    }
}
 
 
function ConvertTo-Hashtable {
    [CmdletBinding()]
    [OutputType('hashtable')]
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )
    process {
        ## Return null if the input is null. This can happen when calling the function
        ## recursively and a property is null
        if ($null -eq $InputObject) {
            return $null
        }
        ## Check if the input is an array or collection. If so, we also need to convert
        ## those types into hash tables as well. This function will convert all child
        ## objects into hash tables (if applicable)
        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = @(
                foreach ($object in $InputObject) {
                    ConvertTo-Hashtable -InputObject $object
                }
            )
            ## Return the array but don't enumerate it because the object may be pretty complex
            Write-Output -NoEnumerate $collection
        } elseif ($InputObject -is [psobject]) {
            ## If the object has properties that need enumeration, cxonvert it to its own hash table and return it
            $hash = @{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertTo-Hashtable -InputObject $property.Value
            }
            $hash
        } else {
            ## If the object isn't an array, collection, or other object, it's already a hash table
            ## So just return it.
            $InputObject
        }
    }
}
 
#
# Suppress warnings
#
Update-AzConfig -DisplayBreakingChangeWarning $false
 
# Load required modules
$requiredModules = @(
    "AzureAD",    
    "Az.Accounts",
    "Az.ConnectedMachine",
    "Az.ResourceGraph"
)
$requiredModules | Foreach-Object {CheckModule $_}
 
 
$win2012resources = Search-AzGraph -Query "resources
| where type =~ 'microsoft.hybridcompute/machines' and properties.osSku contains 'Windows Server 2012'"
 
 
foreach($machine in $win2012resources)
{
   Write-Host "#### Calling API"
 
   $url = "https://management.azure.com/subscriptions/$($SubId)/resourceGroups/$($ResourceGroup)/providers/Microsoft.HybridCompute/machines/$($machine.name)/licenseProfiles/default?api-version=2023-06-20-preview"
   $body = @{location = $($machine.location);properties=@{esuProfile=@{assignedLicense=$($null)}}}
   Write-Host "##$($machine.name)"
   write-host "Invoke-RestMethod -Headers $headers -Uri "https://management.azure.com/subscriptions/$subId/resourceGroups/$ResourceGroup/providers/Microsoft.HybridCompute/licenses/$($license_name)?api-version=2023-06-20-preview" -Method Put -Body $($body | ConvertTo-Json) -ContentType 'application/json'"
   Invoke-RestMethod -Headers $headers -Uri "https://management.azure.com/subscriptions/$($subId)/resourceGroups/$($ResourceGroupOfMachine)/providers/Microsoft.HybridCompute/machines/$($MachineName)/licenseProfiles/default?api-version=2023-06-20-preview" -Method Put -Body $($body | ConvertTo-Json) -ContentType 'application/json'
 
} # FOREACH LOOP ENDS