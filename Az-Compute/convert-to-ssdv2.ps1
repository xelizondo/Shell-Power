# This script will convert all data disks on an Azure VM to SSD v2

# Variables
$ResourceGroupName = "lab-ssdv2" # Replace with your resource group name
$VMName = "vm1" # Replace with your VM name

# Login to Azure (if not already logged in)
Connect-AzAccount
Set-AzContext -SubscriptionId "MS-XE-CSA-AIA-Connectivity" # Replace with your subscription ID

# Get the VM
$vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName
Stop-AzVM -ResourceGroupName $ResourceGroupName -Name $VMName -Force

# Loop through all data disks
foreach ($disk in $vm.StorageProfile.DataDisks) {
    # Get the disk
    $dataDisk = Get-AzDisk -ResourceGroupName $ResourceGroupName -DiskName $disk.Name
    #echo $disk.Name
    #echo $dataDisk.Sku.Name
    #echo $dataDisk.Name

    # Check if the disk is already SSD v2
    if ($dataDisk.Sku.Name -ne "PremiumV2_LRS") {
        Write-Host "Converting disk $($disk.Name) to SSD v2..."

        # Update the disk SKU to SSD v2
        $dataDisk.Sku.Name = "PremiumV2_LRS"
        #Update-AzDisk -ResourceGroupName $ResourceGroupName -Disk $dataDisk.Name
        $storageType = "PremiumV2_LRS"
        $dataDisk.Sku = [Microsoft.Azure.Management.Compute.Models.DiskSku]::new($storageType)
		$dataDisk | Update-AzDisk 

        Write-Host "Disk $($disk.Name) converted to SSD v2."
    } else {
        Write-Host "Disk $($disk.Name) is already SSD v2."
    }
}

Write-Host "All data disks have been processed."
