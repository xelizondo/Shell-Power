$ResourceGroupName = "rg-gts-avd-contractors-eastus"
$StorageAccountName = "sagtsavdstorage"

New-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -KeyName kerb1
Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $StorageAccountName -ListKerbKey #| where-object{$_.Keyname -contains "kerb1"}

#Created a new Active Directory Computer Account named "sagtsavdstorage" in US.DDI.NET domain

#Set Active Directory Attribute on the new Computer account
#ServicePrincipalName set to cifs/sagtsavdstorage.file.core.windows.net

#Reset password on Computer Account using this command:
#The Password is the Storage Account Key from above
Set-ADAccountPassword -Identity 'CN=sagtsavdstorage,OU=AVD-Computers,OU=US Offices,DC=US,DC=DDI,DC=NET' -Reset -NewPassword (ConvertTo-SecureString -AsPlainText "<Password>" -Force)

#Used to Get SID of New computer Object:
get-adcomputer SAGTSAVDSTORAGE -prop sid

# Set the feature flag on the target storage account and provide the required AD domain information
Set-AzStorageAccount `
        -ResourceGroupName $ResourceGroupName `
        -Name $StorageAccountName `
        -EnableActiveDirectoryDomainServicesForFile $true `
        -ActiveDirectoryDomainName "us.ddi.net" `
        -ActiveDirectoryNetBiosDomainName "DDI" `
        -ActiveDirectoryForestName "DDI.NET" `
        -ActiveDirectoryDomainGuid "59a4762a-e64b-4cd1-a7c2-2e85ddffa025" `
        -ActiveDirectoryDomainsid "S-1-5-21-2036949977-1304579848-9522986" `
        -ActiveDirectoryAzureStorageSid "S-1-5-21-2036949977-1304579848-9522986-54029"


        
