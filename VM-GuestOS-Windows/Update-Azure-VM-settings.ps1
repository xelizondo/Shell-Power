$resourceGroupName = "lab-um"

Get-AzVM -ResourceGroupName $resourceGroupName | Set-AzVMOperatingSystem -PatchMode "AutomaticByOS" -AssessmentMode "ImageDefault" | Update-AzVM

Get-AzVM -ResourceGroupName $resourceGroupName | Set-AzVMOperatingSystem -PatchMode "AutomaticByPlatform" -AssessmentMode "AutomaticByPlatform" | Update-AzVM

Get-AzVM -ResourceGroupName $resourceGroupName  | Select-Object -ExpandProperty OSProfile | Select-Object -ExpandProperty WindowsConfiguration | Select-Object -ExpandProperty PatchSettings



$vms = Get-AzVM -ResourceGroupName $resourceGroupName
foreach ($vm in $vms) {
    $vm.Name
    if ($vm.OSProfile.LinuxConfiguration)
    {
        $vm.OSProfile.LinuxConfiguration.PatchSettings | Format-List
    }
    else
    {
        $vm.OSProfile.WindowsConfiguration.PatchSettings | Format-List
    }
}


$vmName = "dummy1"
$vm = Get-AzVM -ResourceGroupName $resourceGroupName -Name $vmName
Set-AzVMOperatingSystem -VM $vm -PatchMode "AutomaticByOS" -AssessmentMode "ImageDefault"  #AutomaticByPlatform or AutomaticByOS  "AKA: Patch Orchestration"
#Set-AzVMOperatingSystem -VM $vm -AssessmentMode "ImageDefault" #AutomaticByPlatform or ImageDefault  "AKA: Periodic Assessment"
Update-AzVM -ResourceGroupName $resourceGroupName -VM $vm
$vm.OSProfile.WindowsConfiguration.PatchSettings | Format-List



$vms = Get-AzVM -ResourceGroupName $resourceGroupName
foreach ($vm in $vms) {
    $vm.Name
    #Set-AzVMOperatingSystem -VM $vm -PatchMode "AutomaticByOS" -AssessmentMode "ImageDefault" #AutomaticByPlatform or AutomaticByOS  "AKA: Patch Orchestration"
    Set-AzVMOperatingSystem -VM $vm -AssessmentMode "ImageDefault" #AutomaticByPlatform or ImageDefault  "enableAutomaticUpdates"
    Set-AzVMOperatingSystem -VM $vm -PatchMode "AutomaticByOS" #AutomaticByPlatform or AutomaticByOS  "AKA: Patch Orchestration"
    Update-AzVM -ResourceGroupName $resourceGroupName -VM $vm
    $vm.OSProfile.WindowsConfiguration.PatchSettings | Format-List
}


$vms = Get-AzVM -ResourceGroupName $resourceGroupName
foreach ($vm in $vms) {
    $vm.Name
    Set-AzVMOperatingSystem -VM $vm -PatchMode "AutomaticByOS" -AssessmentMode "ImageDefault" 
    Update-AzVM -ResourceGroupName $resourceGroupName -VM $vm
    if ($vm.OSProfile.LinuxConfiguration)
    {
        $vm.OSProfile.LinuxConfiguration.PatchSettings | Format-List
    }
    else
    {
        $vm.OSProfile.WindowsConfiguration.PatchSettings | Format-List
    }
}


$vms = Get-AzVM -ResourceGroupName $resourceGroupName
foreach ($vm in $vms) {
    $vm.Name
    $vm.OSProfile.WindowsConfiguration.PatchSettings | Format-List
}

az policy state trigger-scan --resource-group
$job = Start-AzPolicyComplianceScan -ResourceGroupName $resourceGroupName -AsJob
$job | Format-List

#[{"key": "patchingTime","value": "EST-1:00am"},{"key": "patchingTimeOverride","value": ""}]
