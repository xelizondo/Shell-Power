   #Get all VM disks with public access enabled
    $disks = Get-AzDisk | Where-Object { $_.DiskState -eq 'Reserved' -and $_.DiskSizeGB -gt 0 -and $_.PublicNetworkAccess -eq 'Enabled' }
    $diskupdateconfig | New-AzDiskUpdateConfig -PublicNetworkAccess Disabled -NetworkAccessPolicy 'DenyAll'

    #Disable public access for each disk
    foreach ($disk in $disks) {
        Write-Host "Disabling public access for disk $($disk.Name)..."    
        # Update the disk with public access disabled
        Write-Host "Public access disabled for disk $($disk.Name)."
        $disk | update-azdisk -DiskUpdate $diskupdateconfig
    }