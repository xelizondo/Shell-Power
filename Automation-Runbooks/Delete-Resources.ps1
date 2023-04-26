# Input bindings are passed in via param block.
param($Timer)

# Get the current universal time in the default string format.
$currentUTCtime = (Get-Date).ToUniversalTime()

# The 'IsPastDue' property is 'true' when the current function invocation is later than scheduled.
if ($Timer.IsPastDue) {
    Write-Host "PowerShell timer is running late!"
}

(get-azresourcegroup | where-object {(($_.Tags.CreatedDate -lt (get-date).AddDays(-7)) -and ($_.Tags.DeleteDate -lt (get-date))) -or $_.Tags.CreatedDate -eq $null}) | ForEach-Object {remove-azresourcegroup -name $_.resourcegroupname -force }


# Write an information log with the current time.
Write-Host "PowerShell timer trigger function ran! TIME: $currentUTCtime"
