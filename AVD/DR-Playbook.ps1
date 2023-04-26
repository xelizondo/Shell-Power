function Format-UserSessionId($StringId){
    $pos = $stringId.IndexOf("/")
    $rightPart = $stringId.Substring($pos+1)
    $stringId2 = $rightPart
    $pos2 = $stringId2.IndexOf("/")
    $rightPart2 = $stringId2.Substring($pos2+1)
    return $rightPart2
    }

function Get-TextWithin {
    <#    
        .SYNOPSIS
            Get the text between two surrounding characters (e.g. brackets, quotes, or custom characters)
        .DESCRIPTION
            Use RegEx to retrieve the text within enclosing characters.
	    .PARAMETER Text
            The text to retrieve the matches from.
        .PARAMETER WithinChar
            Single character, indicating the surrounding characters to retrieve the enclosing text for. 
            If this paramater is used the matching ending character is "guessed" (e.g. '(' = ')')
        .PARAMETER StartChar
            Single character, indicating the start surrounding characters to retrieve the enclosing text for. 
        .PARAMETER EndChar
            Single character, indicating the end surrounding characters to retrieve the enclosing text for. 
        .EXAMPLE
            # Retrieve all text within single quotes
		    $s=@'
here is 'some data'
here is "some other data"
this is 'even more data'
'@
             Get-TextWithin $s "'"
    .EXAMPLE
    # Retrieve all text within custom start and end characters
    $s=@'
here is /some data\
here is /some other data/
this is /even more data\
'@
    Get-TextWithin $s -StartChar / -EndChar \
#>
    [CmdletBinding()]
    param( 
        [Parameter(Mandatory, 
            ValueFromPipeline = $true,
            Position = 0)]   
        $Text,
        [Parameter(ParameterSetName = 'Single', Position = 1)] 
        [char]$WithinChar = '"',
        [Parameter(ParameterSetName = 'Double')] 
        [char]$StartChar,
        [Parameter(ParameterSetName = 'Double')] 
        [char]$EndChar
    )
    $htPairs = @{
        '(' = ')'
        '[' = ']'
        '{' = '}'
        '<' = '>'
    }
    if ($PSBoundParameters.ContainsKey('WithinChar')) {
        $StartChar = $EndChar = $WithinChar
        if ($htPairs.ContainsKey([string]$WithinChar)) {
            $EndChar = $htPairs[[string]$WithinChar]
        }
    }
    $pattern = @"
(?<=\$StartChar).+?(?=\$EndChar)
"@
    [regex]::Matches($Text, $pattern).Value
}

$LogOffOrRemove = "Remove"
$UserSessFile = "AllUserSessions.csv"

$Title = "DR action"
$Prompt = "Enter your choice"
$Choices = [System.Management.Automation.Host.ChoiceDescription[]] @("&Quit", "&Fail-Over", "&Switch-Back")
$Default = 0
 
# Prompt for the choice
$Choice = $host.UI.PromptForChoice($Title, $Prompt, $Choices, $Default)
 
# Action based on the choice
switch($Choice)
{
  0 { exit }
  1 {   #FAILOVER to EUS2 - Unegister EUS Region Workspace
        $SubscriptionIdEUS = "e446e661-f7b9-4343-b93a-1e719e986bd0"
        $ResourceGroupNameEUS = "rg-avd-pool-1"
        $WorkspaceNameEUS = "WS-Pooled-Desktops"
        $HostPoolEUS = "HP-Pooled-Desktops"
        $ApplicationGroupNameEUS = "AG-Pooled-Desktops"
        $ApplicationGroupPathEUS = "/subscriptions/$SubscriptionIdEUS/resourceGroups/$ResourceGroupNameEUS/providers/Microsoft.DesktopVirtualization/applicationGroups/$ApplicationGroupNameEUS"
        $ResourceGroupNameEUS2 = "RG-AVD-Pool-1-EUS2"
        $WorkspaceNameEUS2 = "WS-Pooled-Desktops-EUS2"
        $SubscriptionIdEUS2 = "e446e661-f7b9-4343-b93a-1e719e986bd0"
        $ApplicationGroupNameEUS2 = "HP-Pooled-Desktops-EUS2-DAG"
        $ApplicationGroupPathEUS2 = "/subscriptions/$SubscriptionIdEUS2/resourceGroups/$ResourceGroupNameEUS2/providers/Microsoft.DesktopVirtualization/applicationGroups/$ApplicationGroupNameEUS2"
        $RGVMtoFailEUS ="RG-AVD-POOL-1-COMPUTE"
        $VMtoFailEUS = "vd-pd-0"
        Select-AzSubscription -SubscriptionId $subscriptionIdEUS 
        Stop-AzVM -ResourceGroupName $RGVMtoFailEUS -Name $VMtoFailEUS 
        Get-AzWvdUserSession -ResourceGroupName $ResourceGroupNameEUS -HostPoolName $HostPoolEUS | Select-Object * | Export-CSV $UserSessFile
        $CSV = Import-CSV $UserSessFile
        ForEach ($Item in $CSV)
        {
            $SessHost = $Item.Name
            $CurSessID = $Item.Name
            IF([string]::IsNullOrWhiteSpace($CurSessID))
            {
                write-host "no user sessions, exiting."
                
            }
            else
            {
                $Lstring = "@'"
                $Rstring = "'@"
                $s= $Lstring+$SessHost+$Rstring
                $SessionHostName = Get-TextWithin $s "/"
                $SessionId = Format-UserSessionId($CurSessID)
                $Error.Clear()
                IF ($LogOffOrRemove -eq "Remove")
                {
                    Write-Host "Forcing User Log Off"
                    Remove-AzWvdUserSession -ResourceGroupName $ResourceGroupNameEUS -HostPoolName $HostPoolEUS -SessionHostName $SessionHostName -Id $SessionId -Force
                }
                IF ($LogOffOrRemove -eq "Logoff")
                {
                    Disconnect-AzWvdUserSession -ResourceGroupName $ResourceGroupNameEUS -HostPoolName $HostPoolEUS -SessionHostName $SessionHostName -Id $SessionId
                }
                IF ($Error.Count -eq 0)
                {
                    Write-Host "User Was Removed..."
                }
                else
                {
                    Write-Host "ErrorRemovingUser:$Error"
                }
            }
        Unregister-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupNameEUS `
        -WorkspaceName $WorkspaceNameEUS `
        -ApplicationGroupPath $ApplicationGroupPathEUS
        Register-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupNameEUS2 `
        -WorkspaceName $WorkspaceNameEUS2 `
        -ApplicationGroupPath $ApplicationGroupPathEUS2
    }
    

    }  
  2 { #FAILOVER to EUS - Unegister EUS2 Region Workspace
    $SubscriptionIdEUS = "e446e661-f7b9-4343-b93a-1e719e986bd0"
    $ResourceGroupNameEUS = "rg-avd-pool-1"
    $WorkspaceNameEUS = "WS-Pooled-Desktops"
    $HostPoolEUS = "HP-Pooled-Desktops"
    $ApplicationGroupNameEUS = "AG-Pooled-Desktops"
    $ApplicationGroupPathEUS = "/subscriptions/$SubscriptionIdEUS/resourceGroups/$ResourceGroupNameEUS/providers/Microsoft.DesktopVirtualization/applicationGroups/$ApplicationGroupNameEUS"
    $ResourceGroupNameEUS2 = "RG-AVD-Pool-1-EUS2"
    $WorkspaceNameEUS2 = "WS-Pooled-Desktops-EUS2"
    $SubscriptionIdEUS2 = "e446e661-f7b9-4343-b93a-1e719e986bd0"
    $ApplicationGroupNameEUS2 = "HP-Pooled-Desktops-EUS2-DAG"
    $ApplicationGroupPathEUS2 = "/subscriptions/$SubscriptionIdEUS2/resourceGroups/$ResourceGroupNameEUS2/providers/Microsoft.DesktopVirtualization/applicationGroups/$ApplicationGroupNameEUS2"
    $RGVMtoFailEUS2 ="RG-AVD-Pool-1-Compute-EUS2"
    $VMtoFailEUS2 = "vdeus2-0"
    Select-AzSubscription -SubscriptionId $subscriptionIdEUS 
    Stop-AzVM -ResourceGroupName $RGVMtoFailEUS2 -Name $VMtoFailEUS2
    Get-AzWvdUserSession -ResourceGroupName $ResourceGroupNameEUS2 -HostPoolName $HostPoolEUS2 | Select-Object * | Export-CSV $UserSessFile
    $CSV = Import-CSV $UserSessFile
    ForEach ($Item in $CSV)
    {
        $SessHost = $Item.Name
        $CurSessID = $Item.Name
        IF([string]::IsNullOrWhiteSpace($CurSessID))
        {
            write-host "no user sessions, exiting."
            
        }
        else
        {
            $Lstring = "@'"
            $Rstring = "'@"
            $s= $Lstring+$SessHost+$Rstring
            $SessionHostName = Get-TextWithin $s "/"
            $SessionId = Format-UserSessionId($CurSessID)
            $Error.Clear()
            IF ($LogOffOrRemove -eq "Remove")
            {
                Write-Host "Forcing User Log Off"
                Remove-AzWvdUserSession -ResourceGroupName $ResourceGroupNameEUS2 -HostPoolName $HostPoolEUS2 -SessionHostName $SessionHostName -Id $SessionId -Force
            }
            IF ($LogOffOrRemove -eq "Logoff")
            {
                Disconnect-AzWvdUserSession -ResourceGroupName $ResourceGroupNameEUS2 -HostPoolName $HostPoolEUS2 -SessionHostName $SessionHostName -Id $SessionId
            }
            IF ($Error.Count -eq 0)
            {
                Write-Host "User Was Removed..."
            }
            else
            {
                Write-Host "ErrorRemovingUser:$Error"
            }
        }
    Unregister-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupNameEUS2 `
    -WorkspaceName $WorkspaceNameEUS2 `
    -ApplicationGroupPath $ApplicationGroupPathEUS2    
    Register-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupNameEUS `
    -WorkspaceName $WorkspaceNameEUS `
    -ApplicationGroupPath $ApplicationGroupPathEUS
}     
        
    }
}


