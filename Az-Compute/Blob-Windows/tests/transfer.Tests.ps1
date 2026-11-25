$ErrorActionPreference = 'Stop'
$template = Get-Content -LiteralPath (Join-Path $PSScriptRoot '..\copy.ps1.tftpl') -Raw
$template = $template.Replace('${storage_name}', 'teststorage').Replace('$${', '${')
$template = $template.Replace('$azcopy = Join-Path $labPath ''azcopy.exe''', '$azcopy = ''Test-AzCopy''')
$scriptBlock = [scriptblock]::Create($template)

function Add-Content { param($Path, $Value) }
function Start-Sleep { param($Seconds) $global:sleeps++ }
function Get-ChildItem { param($Path, [switch]$File, [switch]$Recurse, [switch]$Force) $global:listedPaths += $Path; if ($global:hasFiles) { 'sample.txt' } }
function Test-AzCopy { $global:copies += ,@($args); $global:LASTEXITCODE = 0 }
function Invoke-WebRequest {
    param($Uri, $Method, $Headers, [switch]$UseBasicParsing)
    if ($global:invalidDirectory) { return @{ Headers = @{ 'x-ms-resource-type' = 'file' } } }
    return @{ Headers = @{ 'x-ms-resource-type' = 'directory' } }
}
function Invoke-RestMethod {
    param($Uri, $Method, $Headers)
    if ($Uri -like '*metadata/identity*') { return @{ access_token = 'test-token' } }
    $global:requests += $Uri
    if ($global:responses.Count -gt 0) {
        $response = $global:responses[0]
        $global:responses = @($global:responses | Select-Object -Skip 1)
        if ($response -ne 'ok') {
            $parts = $response.Split(':')
            $exception = [Exception]::new('Mock storage error')
            $exception | Add-Member -NotePropertyName Response -NotePropertyValue @{
                StatusCode = [int]$parts[0]
                Headers = @{ 'x-ms-error-code' = $parts[1] }
            }
            throw $exception
        }
    }
}
function Reset-Mocks {
    $global:requests = @()
    $global:copies = @()
    $global:listedPaths = @()
    $global:responses = @()
    $global:sleeps = 0
    $global:hasFiles = $true
    $global:invalidDirectory = $false
}
function Assert($condition, $message) { if (-not $condition) { throw $message } }

Reset-Mocks
& $scriptBlock -InitializeOnly
Assert ($global:requests.Count -eq 2) 'Initialization must create both directories.'
Assert ($global:requests[0] -eq 'https://teststorage.dfs.core.windows.net/container1/folder-in?resource=directory') 'Incorrect folder-in initialization URL.'
Assert ($global:requests[1] -eq 'https://teststorage.dfs.core.windows.net/container1/folder-out?resource=directory') 'Incorrect folder-out initialization URL.'
Assert ($global:copies.Count -eq 0) 'Initialization must not transfer files.'

Reset-Mocks
$global:responses = @('409:PathAlreadyExists', '412:ConditionNotMet')
& $scriptBlock
Assert ($global:copies.Count -eq 2) 'Expected upload and download.'
Assert ($global:listedPaths.Count -eq 1 -and $global:listedPaths[0] -eq 'C:\adls-out') 'Must check the upload source directory.'
Assert (($global:copies[0] -join '|') -eq 'copy|C:\adls-out\*|https://teststorage.blob.core.windows.net/container1/folder-in|--recursive=true|--overwrite=ifSourceNewer') 'Incorrect upload arguments.'
Assert (($global:copies[1] -join '|') -eq 'copy|https://teststorage.blob.core.windows.net/container1/folder-out/*|C:\adls-in|--recursive=true|--overwrite=ifSourceNewer') 'Incorrect download arguments.'

Reset-Mocks
$global:hasFiles = $false
$global:responses = @('403:AuthorizationPermissionMismatch', 'ok', 'ok')
& $scriptBlock
Assert ($global:sleeps -eq 1) 'Expected RBAC propagation retry.'
Assert ($global:copies.Count -eq 1 -and $global:copies[0][1] -like '*/folder-out/*') 'Empty local directory must still download.'

Reset-Mocks
$global:responses = @('409:PathAlreadyExists')
$global:invalidDirectory = $true
$failed = $false
try { & $scriptBlock -InitializeOnly } catch { $failed = $true }
Assert $failed 'A preexisting file must not be accepted as a directory.'

Reset-Mocks
$global:responses = @('403:AuthorizationPermissionMismatch') * 7
$failed = $false
try { & $scriptBlock -InitializeOnly } catch { $failed = $true }
Assert ($failed -and $global:sleeps -eq 6) 'RBAC retry must stop and report failure.'

Reset-Mocks
$global:responses = @('409:OtherConflict')
$failed = $false
try { & $scriptBlock -InitializeOnly } catch { $failed = $true }
Assert $failed 'Unexpected conflicts must remain errors.'
Write-Output 'Transfer initialization, routing, conflict, and retry checks passed.'
