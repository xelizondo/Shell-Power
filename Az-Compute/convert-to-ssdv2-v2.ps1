# This script will convert all data disks on an Azure VM to SSD v2

# Variables


# Name of the resource group that contains the VM
$rgName = 'lab-ssdv2'

# Name of the your virtual machine
$vmName = 'vm1'

# Choose between Standard_LRS, StandardSSD_LRS, StandardSSD_ZRS, Premium_ZRS, Premium_LRS, and PremiumV2_LRS based on your scenario
$storageType = 'PremiumV2_LRS'

# Premium capable size
# Required only if converting storage from Standard to Premium
$size = 'Standard_DS2_v2'

# Stop and deallocate the VM before changing the size
Stop-AzVM -ResourceGroupName $rgName -Name $vmName -Force

$vm = Get-AzVM -Name $vmName -resourceGroupName $rgName

# Change the VM size to a size that supports Premium storage
# Skip this step if converting storage from Premium to Standard
$vm.HardwareProfile.VmSize = $size
Update-AzVM -VM $vm -ResourceGroupName $rgName

# Get all disks in the resource group of the VM
$vmDisks = Get-AzDisk -ResourceGroupName $rgName

# For disks that belong to the selected VM, convert to Premium storage except for the OS disk
# The OS disk is already Premium and does not need to be converted again

foreach ($disk in $vmDisks)
{
	if ($disk.ManagedBy -eq $vm.Id)
	{
		$disk.Sku = [Microsoft.Azure.Management.Compute.Models.DiskSku]::new($storageType)
		$disk | Update-AzDisk
	}
}

Start-AzVM -ResourceGroupName $rgName -Name $vmName