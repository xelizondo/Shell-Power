Function Format-UserSessionId($StringId){
    $pos = $stringId.IndexOf("/")
    $rightPart = $stringId.Substring($pos+1)
    $stringId2 = $rightPart
    $pos2 = $stringId2.IndexOf("/")
    $rightPart2 = $stringId2.Substring($pos2+1)
    return $rightPart2
    }

Function Get-TextWithin {
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

Function ProcessUserSession($ResourceGroupName,$HostPoolName,$CSVfile){ 
    $LogOffOrRemove = "Remove"
    ForEach ($Item in $CSVfile)
        {
            $SessHost = $Item.Name
            $CurSessID = $Item.Name
            $ADUserName = $Item.ActiveDirectoryUserName
            Start-Sleep -Seconds 1
            IF([string]::IsNullOrWhiteSpace($CurSessID))
            {
                write-host "no user sessions, exiting." -ForegroundColor Yellow -BackgroundColor DarkGreen
                Start-Sleep -Seconds 1
                
            }
            else
            {
                $Lstring = "@'"
                $Rstring = "'@"
                $s= $Lstring+$SessHost+$Rstring
                $SessionHostName = Get-TextWithin $s "/"
                Start-Sleep -Seconds 1
                $SessionId = Format-UserSessionId($CurSessID)
                $Error.Clear()
                IF ($LogOffOrRemove -eq "Remove")
                {
                    write-host "Forcing User session Log Off: " $ADUserName "from session host: " $SessionHostName -ForegroundColor Yellow -BackgroundColor DarkGreen
                    Start-Sleep -Seconds 1
                    Remove-AzWvdUserSession -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -SessionHostName $SessionHostName -Id $SessionId -Force
                }
                IF ($LogOffOrRemove -eq "Logoff")
                {
                    write-host "Disconnecting User session : " $ADUserName "from session host: " $SessionHostName -ForegroundColor Yellow -BackgroundColor DarkGreen
                    Start-Sleep -Seconds 1
                    Disconnect-AzWvdUserSession -ResourceGroupName $ResourceGroupName -HostPoolName $HostPoolName -SessionHostName $SessionHostName -Id $SessionId
                }
                IF ($Error.Count -eq 0)
                {
                    write-host "Done with user session action ..."  -ForegroundColor Yellow -BackgroundColor DarkGreen
                }
                else
                {
                    write-host "ErrorRemovingUser:$Error"
                }
        }
    }
}

Function Unregister-AppGroup($ResourceGroupName,$WorkspaceName,$ApplicationGroupPath){
    write-host "Unregistering app group from workspace: " $WorkspaceName -ForegroundColor Yellow -BackgroundColor DarkGreen
    Start-Sleep -Seconds 1
    Unregister-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupName `
            -WorkspaceName $WorkspaceName `
            -ApplicationGroupPath $ApplicationGroupPath
}

Function Register-AppGroup($ResourceGroupName,$WorkspaceName,$ApplicationGroupPath){
    write-host "Registering app group to workspace: " $WorkspaceName -ForegroundColor Yellow -BackgroundColor DarkGreen
    Start-Sleep -Seconds 1
    register-AzWvdApplicationGroup -ResourceGroupName $ResourceGroupName `
            -WorkspaceName $WorkspaceName `
            -ApplicationGroupPath $ApplicationGroupPath
}

#Region-1- EUS variables
$SubscriptionIdEUS = "e446e661-f7b9-4343-b93a-1e719e986bd0"
$ResourceGroupNameEUS = "rg-avd-pool-1"
$WorkspaceNameEUS = "WS-Pooled-Desktops"
$HostPoolEUS = "HP-Pooled-Desktops"
$ApplicationGroupNameEUS = "AG-Pooled-Desktops"
$ApplicationGroupPathEUS = "/subscriptions/$SubscriptionIdEUS/resourceGroups/$ResourceGroupNameEUS/providers/Microsoft.DesktopVirtualization/applicationGroups/$ApplicationGroupNameEUS"
$RGVMtoFailEUS ="RG-AVD-POOL-1-COMPUTE"
$VMtoFailEUS = "vd-pd-0"

#Region-2- EUS2 variables
$SubscriptionIdEUS2 = "e446e661-f7b9-4343-b93a-1e719e986bd0"
$ResourceGroupNameEUS2 = "RG-AVD-Pool-1-EUS2"
$WorkspaceNameEUS2 = "WS-Pooled-Desktops-EUS2"
$HostPoolEUS2 = "HP-Pooled-Desktops-EUS2"
$ApplicationGroupNameEUS2 = "HP-Pooled-Desktops-EUS2-DAG"
$ApplicationGroupPathEUS2 = "/subscriptions/$SubscriptionIdEUS2/resourceGroups/$ResourceGroupNameEUS2/providers/Microsoft.DesktopVirtualization/applicationGroups/$ApplicationGroupNameEUS2"
$RGVMtoFailEUS2 ="RG-AVD-Pool-1-Compute-EUS2"
$VMtoFailEUS2 = "vdeus2-0"

$UserSessFile = "AllUserSessions.csv"
Select-AzSubscription -SubscriptionId $subscriptionIdEUS 

$Title = "DR Playbook"
$Prompt = "Enter your choice:"
$Choices = [System.Management.Automation.Host.ChoiceDescription[]] @("&Quit", "&Fail-Over", "&Switch-Back")
$Default = 0
 
# Prompt for the choice
$Choice = $host.UI.PromptForChoice($Title, $Prompt, $Choices, $Default)
 
# Action based on the choice
switch($Choice)
{
  0 { exit }
  1 {   write-host "FAILOVER to EUS2" -ForegroundColor Yellow -BackgroundColor DarkGreen
        Stop-AzVM -ResourceGroupName $RGVMtoFailEUS -Name $VMtoFailEUS -StayProvisioned -Force
        Get-AzWvdUserSession -ResourceGroupName $ResourceGroupNameEUS -HostPoolName $HostPoolEUS | Select-Object * | Export-CSV $UserSessFile
        $CSV = Import-CSV $UserSessFile
        Start-Sleep -Seconds 1

        ProcessUserSession $ResourceGroupNameEUS $HostPoolEUS $CSV
        Unregister-AppGroup $ResourceGroupNameEUS $WorkspaceNameEUS $ApplicationGroupPathEUS
        Register-AppGroup $ResourceGroupNameEUS2 $WorkspaceNameEUS2 $ApplicationGroupPathEUS2
        write-host "FAILOVER to EUS2 COMPLETE" -ForegroundColor Yellow -BackgroundColor DarkGreen
    }

  2 { 
        write-host "FAILOVER to EUS" -ForegroundColor Yellow -BackgroundColor DarkGreen
        Stop-AzVM -ResourceGroupName $RGVMtoFailEUS2 -Name $VMtoFailEUS2 -StayProvisioned -Force
        Get-AzWvdUserSession -ResourceGroupName $ResourceGroupNameEUS2 -HostPoolName $HostPoolEUS2 | Select-Object * | Export-CSV $UserSessFile
        $CSV = Import-CSV $UserSessFile
        Start-Sleep -Seconds 1
        
        #ProcessUserSession $ResourceGroupNameEUS2 $HostPoolEUS2 $CSV
        Unregister-AppGroup $ResourceGroupNameEUS2 $WorkspaceNameEUS2 $ApplicationGroupPathEUS2
        Register-AppGroup $ResourceGroupNameEUS $WorkspaceNameEUS $ApplicationGroupPathEUS
        write-host "FAILOVER to EUS COMPLETE" -ForegroundColor Yellow -BackgroundColor DarkGreen
    }    
}


