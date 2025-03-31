
# MBR2GPT /validate /allowFullOS
# MBR2GPT /convert /allowFullOS

set-AzContext -SubscriptionId "MS-XE-CSA-AIA-Connectivity"

$rg = "0-tub"
$vmname = "vm1" 

Stop-AzVM -ResourceGroupName $rg -Name $vmname -Force

Get-AzVM -ResourceGroupName $rg -VMName $vmname | Update-AzVM -SecurityType TrustedLaunch -EnableSecureBoot $true -EnableVtpm $true

(Get-AzVM -ResourceGroupName 0-tub -VMName vm1 `
    | Select-Object -Property SecurityProfile `
        -ExpandProperty SecurityProfile).SecurityProfile.SecurityType

(Get-AzVM -ResourceGroupName 0-tub -VMName vm1 `
    | Select-Object -Property SecurityProfile `
        -ExpandProperty SecurityProfile).SecurityProfile.Uefisettings


Start-AzVM -ResourceGroupName $rg -Name $vmname -Force