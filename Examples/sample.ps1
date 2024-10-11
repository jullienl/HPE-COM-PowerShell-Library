

# Import module from unzip file
import-module .\HPEGreenLakeForCOM.psd1 -force  

$MyEmail = "xxxx@xxx.xxr"
$WorkspaceName = "HPEWorkspace_XXXXXXXXXXX"


# Connection to HPE GreenLake
$credentials = Get-Credential -UserName $MyEmail
Connect-HPEGL -Credential $credentials

##################### GLP workspace configuration #########################

# A- Connection if you have NO workspace ##################################

# Create your first workspace
New-HPEGLWorkspace `
-Name "My_first_workspace_name"  `
-Type 'Standard enterprise workspace' `
-Email $MyEmail `
-Street "Theory of dynamical systems street" `
-Street2 "Cosmos building" `
-City Paris `
-PostalCode 75000 `
-Country France `
-PhoneNumber +33612345678 

# Connect to the new created workspace
Connect-HPEGL -Credential $credentials -Workspace "My_first_workspace_name"


# B- Connection if you have a workspace ##################################

$WorkspaceName = "HPEWorkspace_53751220"
$credentials = Get-Credential -UserName yojul@free.fr 
Connect-HPEGL -Credential $credentials -Workspace $WorkspaceName

#########################################################################

# Invite new users
$NewUserEmail = "AdminCOM@gmail.com"

Send-HPEGLUserInvitation -Email $NewUserEmail -Role 'Workspace Administrator' -SenderEmail $MyEmail 

# Add the HPE GreenLake role 'Workspace Observer' to the new user
Add-HPEGLRoleToUser -Email $NewUserEmail -HPEGreenLakeRole 'Workspace Observer' 

# Provision the Compute Ops Management service manager in the central european region
New-HPEGLService -Name "Compute Ops Management" -Region "eu-central" 
 
# Add the Compute Ops Management role 'Administrator' to your user 
Add-HPEGLRoleToUser -Email $MyEmail -ComputeOpsManagementRole Administrator

# Add the Compute Ops Management role 'Administrator' to the new user
Add-HPEGLRoleToUser -Email $NewUserEmail -ComputeOpsManagementRole Administrator

# Create a new location
$LocationName = "Mougins"
New-HPEGLLocation -Name $LocationName -Description "My french location" `
  -Country France -Street "790 Avenue du Docteur Donat" -Street2 "Marco Polo - Bat B" -City $LocationName -State "N/A" -PostalCode "06254" `
  -PrimaryContactEmail $MyEmail -PrimaryContactPhone "+1234567890" 


# Add a device subscription key
New-HPEGLDeviceSubscription -SubscriptionKey "ABCDEFGH"

# Set auto compute device subscription
Set-HPEGLDeviceAutoSubscription -ComputeSubscriptionTier ENHANCED

# Add a few devices [method 1]
Add-HPEGLDeviceCompute -SerialNumber "CZ2311004G" -PartNumber "P28948-B21" -Tags "Country=FR, App=AI, Departement=IT" 
Add-HPEGLDeviceCompute -SerialNumber "CZ2311004H" -PartNumber "P28948-B21" -Tags "Country=FR, App=AI, Departement=IT" 


# Add many devices [method] 2 using a CSV file and HPEiLOCmdlets module
# The CSV file should contain the iLO IP address, a user account, password, and optional tags in the following format:
#
#    IP; Username; Password; Tags
#    192.168.0.1; admin; password; Country=FR, State=PACA, App=RH
#    192.168.0.2; Administrator; password; State=Texas, Role=Prod
#    192.168.0.3; demo; password; 
#
# Note that for `192.168.0.3`, no tags are assigned in this example.


$iLOs = import-csv Sample\iLOs.csv -Delimiter ";"

if(-not (Get-Module -Name HPEiLOCmdlets)) {
    Install-Module -Name HPEiLOCmdlets 
}

ForEach ($iLO in $iLOs) {
   
  try {

    $connection = Connect-HPEiLO -Address $iLO.IP -Username $iLO.Username -Password $iLO.Password -DisableCertificateAuthentication -ErrorAction Stop

    # Retrieve the device information uisng the HPEiLOCmdlets module
    $response =    Get-HPEiLOSystemInfo -Connection $connection 

    $SerialNumber = $response.SerialNumber
    $PartNumber = $response.sku
    $Tags = $iLO.Tags

    # Add the device to HPE GreenLake
    Add-HPEGLDeviceCompute -SerialNumber $SerialNumber -PartNumber $PartNumber -Tags $Tags 

    Disconnect-HPEiLO -Connection $connection 

  }
  catch {
    "iLO {0} cannot be added ! Check your IP or credentials !" -f $iLO.IP
    continue
  }
        
}


# Assign all devices to the location
Get-HPEGLdevice | Set-HPEGLDeviceLocation -LocationName $LocationName 
# Or assign a device to the location
Set-HPEGLDeviceLocation -DeviceSerialNumber "CZ2311004G" -LocationName $LocationName 


# Assign all devices to the COM instance
Get-HPEGLDevice -ShowRequireAssignment | Add-HPEGLDeviceToService -ServiceName "Compute Ops Management" -ServiceRegion "eu-central" 
# Or assign a device to the COM instance
Add-HPEGLDeviceToService -DeviceSerialNumber "CZ2311004G"  -ServiceName "Compute Ops Management" -ServiceRegion "eu-central" 

# Apply a subscription key to devices - Not required as auto-subscription has been enabled earlier
Get-HPEGLdevice -ShowRequireAssignment | Set-HPEGLDeviceSubscription -SubscriptionKey $SubscriptionKey 

# Connect iLOS to COM instance
$iLOs | Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLO_credential -IloProxyServer "web-proxy.domain.com" -IloProxyPort 8080 -IloProxyUserName admin -IloProxyPassword $iLO_secureString_Proxy_Password

# $iLO_secureString_Proxy_Password = Read-Host -Prompt "Enter the proxy password" -AsSecureString


ForEach ($iLO in $iLOs) {
   
  try {

    $iLO_credential = Get-Credential -UserName $iLO.Username -Password $iLO.Password

    Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLO_credential  # -IloProxyServer "web-proxy.domain.com" -IloProxyPort 8080 -IloProxyUserName <username> -IloProxyPassword $iLO_secureString_Proxy_Password

  }
  catch {
    "iLO {0} cannot be added ! Check your network access, iLO IP or credentials !" -f $iLO.IP
    continue
  }
        
}


##################### COM instance configuration #########################


# Create a new BIOS setting

New-HPECOMSettingServerBios -Region eu-central -Name "Custom-Bios-For-AI" -AsrStatus:$True -WorkloadProfileName "Virtualization - Max Performance" -Whatif
New-HPECOMSettingServerBios -Region eu-central -Name "Custom-Bios-For-AI"  -WorkloadProfileName "Virtualization - Max Performance" -AsrTimeoutMinutes Timeout10 -Whatif # AsrStatus should be enabled

# Create a new server setting for internal storage 
New-HPECOMSettingServerInternalStorage -Region eu-central -Name "RAID-1" -RAID  RAID1 -Description "My RAID1 server setting for the OS" -EntireDisk

# Create a new server setting for the OS
New-HPECOMSettingServerOSImage -Region  eu-central  -Name "Rocky9.4" -Description "Unattended deployment for Rocky 9.4" -OperatingSystem VMWARE_ESXI -OSImageURL "https://liogw.lj.lab/deployment/rocky94-x64/images/install.img"

# Create a new server setting for firmware 
New-HPECOMSettingServerFirmware -Region eu-central -Name "Firmware-bundle-2024.04.00.01" -Description "My FW bundle" -Gen10FirmwareBundleReleaseVersion $Gen10_Firmware_Bundle -Gen11FirmwareBundleReleaseVersion $Gen11_Firmware_Bundle -w


# Create a new server group
New-HPECOMGroup -Region eu-central -Name "AI_Group" -Description "My new group for AI servers" `
-BiosSettingName "Custom-Bios-For-AI" -AutoBiosApplySettingsOnAdd:$true   `
-FirmwareSettingName "Firmware-bundle-2024.04.00.01"  -AutoFirmwareUpdateOnAdd:$True -PowerOffServerAfterFirmwareUpdate:$True -FirmwareDowngrade:$True `
-OSSettingName "Rocky9.4" -AutoOsImageInstallOnAdd:$True -OsCompletionTimeoutMin 60 `
-StorageSettingName "RAID-1" -StorageVolumeName "OS-vol" -AutoStorageVolumeCreationOnAdd:$True -AutoStorageVolumeDeletionOnAdd:$True  `
-EnableiLOSettingsForSecurity:$True -AutoIloApplySettingsOnAdd:$True  `
-TagUsedForAutoAddServer "App=AI" -w


# Add servers to new group
Get-HPECOMServer -Region eu-central | ? tags -like "*App=AI*"  | Add-HPECOMServerToGroup -GroupName AI_Group

# Disable iLO Ignore Security Settings for Default SSL Certificate In Use
Get-HPECOMServer -Region eu-central | ? tags -like "*App=AI*"  |  Disable-HPECOMIloIgnoreSecuritySetting -DefaultSSLCertificateInUse 

# Run a job to collect servers inventory data
Get-HPECOMServer -Region eu-central | ? tags -like "*App=AI*"  | New-HPECOMServerInventory 

# Set iLO auto firmware update for servers
Get-HPECOMServer -Region eu-central | ? tags -like "*App=AI*" | ? autoIloFwUpdate -eq $False | Enable-HPECOMServerAutoiLOFirmwareUpdate 


# More to come...


# Disconnect from HPE GreenLake
Disconnect-HPEGL
