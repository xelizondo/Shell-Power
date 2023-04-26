<#	
	.NOTES
	===========================================================================
		 Created on:   	07/08/2020 10:37
	 Created by:   	Ryan Mangan
	 Organization: 	Ryanmangansitblog.com
	 Filename:     	WVD Auto MSTeams Install 
	===========================================================================
	.DESCRIPTION
		This script is to be used with Azure Custom Scrpt Extentions to deploy MS Teams on to a Windows 10 Multi Session Host.
		
		Steps....
		1. add regkey to state environment is a WVD Environment
		2. Download the required applications to c:\temp\
		3. Install C++ run time
		4. Install MSRDCWEBRTCSvc 
	
#>


$RegistrationToken = "sadf324256762345t543$%#@@$%^&^%$#"
$InstallFolder = "c:\temp"


if (!(Test-Path $InstallFolder))
{
New-Item -itemType Directory -Path c:\ -Name temp
}
else
{
write-host "Folder already exists"
}

if (!$RegistrationToken) {
    throw "No registration token specified"
}


function Test-IsAdmin {
    ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
}


# Add registry Keys
reg add "HKLM\SOFTWARE\Microsoft\Teams" /v IsWVDEnvironment /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\office\16.0\common\officeupdate" /v preventteamsinstall /t REG_DWORD /d 1 /f
reg add "HKLM\SOFTWARE\Policies\Microsoft\office\16.0\common\officeupdate" /v PreventFirstLaunchAfterInstall /t REG_DWORD /d 1 /f

#Download WVD agent
invoke-WebRequest -Uri "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrmXv" -OutFile "$InstallFolder\Microsoft.RDInfra.RDAgent.Installer-x64.msi"

#Download WVD agent bootloader
invoke-WebRequest -Uri "https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RWrxrH" -OutFile "$InstallFolder\Microsoft.RDInfra.RDAgentBootLoader.Installer-x64.msi"

#Download C++ Runtime
invoke-WebRequest -Uri https://aka.ms/vs/16/release/vc_redist.x64.exe -OutFile "$InstallFolder\vc_redist.x64.exe"
Start-Sleep -s 5

#Download RDCWEBRTCSvc
invoke-WebRequest -Uri https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RE4AQBt -OutFile "$InstallFolder\MsRdcWebRTCSvc_HostSetup_x64.msi"
Start-Sleep -s 5

#Download Teams 
#invoke-WebRequest -Uri https://statics.teams.cdn.office.net/production-windows-x64/1.4.00.2879/Teams_windows_x64.msi -OutFile "$InstallFolder\Teams_windows_x64.msi"
invoke-WebRequest -Uri "https://teams.microsoft.com/downloads/desktopurl?env=production&plat=windows&arch=x64&managedInstaller=true&download=true" -OutFile "$InstallFolder\Teams_windows_x64.msi"
Start-Sleep -s 5

#Install C++ runtime
Start-Process -FilePath $InstallFolder\vc_redist.x64.exe -ArgumentList '/q', '/norestart'
Start-Sleep -s 10

#Install MSRDCWEBTRCSVC
msiexec /i "$InstallFolder\MsRdcWebRTCSvc_HostSetup_x64.msi" /q /n
Start-Sleep -s 10

# Install Teams
msiexec /i "$InstallFolder\Teams_windows_x64.msi" /l*v teamsinstall.txt ALLUSER=1 /q
Start-Sleep -s 10

# Install WVD agent bootLoader
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $InstallFolder\Microsoft.RDInfra.RDAgentBootLoader.Installer-x64.msi", "/quiet", "/qn", "/norestart", "/passive", "/l* $InstallFolder\AgentBootLoaderInstall.log" -Wait -Passthru

# Install WVD agent 
Start-Process -FilePath "msiexec.exe" -ArgumentList "/i $InstallFolder\Microsoft.RDInfra.RDAgent.Installer-x64.msi", "/quiet", "/qn", "/norestart", "/passive", "REGISTRATIONTOKEN=$RegistrationToken", "/l*v $InstallFolder\AgentInstall.log" -Wait -Passthru

$LocalTempDir = $env:TEMP; $ChromeInstaller = "ChromeInstaller.exe"; (new-object System.Net.WebClient).DownloadFile('http://dl.google.com/chrome/install/375.126/chrome_installer.exe', "$LocalTempDir\$ChromeInstaller"); & "$LocalTempDir\$ChromeInstaller" /silent /install; $Process2Monitor = "ChromeInstaller"; Do { $ProcessesFound = Get-Process | ?{$Process2Monitor -contains $_.Name} | Select-Object -ExpandProperty Name; If ($ProcessesFound) { "Still running: $($ProcessesFound -join ', ')" | Write-Host; Start-Sleep -Seconds 2 } else { rm "$LocalTempDir\$ChromeInstaller" -ErrorAction SilentlyContinue -Verbose } } Until (!$ProcessesFound)
#https://statics.teams.cdn.office.net/production-windows-x64/1.4.00.2879/Teams_windows_x64.msi
#https://query.prod.cms.rt.microsoft.com/cms/api/am/binary/RE4AQBt