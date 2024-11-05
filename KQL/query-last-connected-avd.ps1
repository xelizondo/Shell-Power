Set-AzContext -Subscription MS-XE-CSA-AIA-LZ 
$avdSessionHosts = Get-AzWvdSessionHost -HostPoolName HP-Personal-Desktops -ResourceGroupName RG-AVD-Personal
$avdSessionHosts | Where-Object { $_.ActiveSessionCount -eq 0 -and $_.LastConnectionTime -gt (Get-Date).AddDays(-5) }
