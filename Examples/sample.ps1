

# Import module from unzip file
import-module .\HPEGreenLakeForCOM.psd1 -force  

# HPE Account 
$MyEmail = "xxxx@xxx.xxr"
$credentials = Get-Credential -UserName $MyEmail


#Region -------------------------------------------------------- Connection to HPE GreenLake -----------------------------------------------------------------------------------------

# [Method A] - Connection if you have NO workspace #######################################################

  Connect-HPEGL -Credential $credentials

  # Create your first workspace
  New-HPEGLWorkspace `
  -Name "<WorkspaceName>"  `
  -Type 'Standard enterprise workspace' `
  -Email $MyEmail `
  -Street "<StreetAddress>" `
  -Street2 "<StreetAddress2>" `
  -City "<City>" `
  -PostalCode "<PostalCode>" `
  -Country "<Country>" `
  -PhoneNumber "<phoneNumber>" 
  # -> Automatically disconnect the session after creating the workspace

  # Connect to the new created workspace
  Connect-HPEGL -Credential $credentials -Workspace "My_first_workspace_name"


# [Method B] - Connection if you have a workspace #######################################################

  $WorkspaceName = "HPEWorkspace_53751220"
  Connect-HPEGL -Credential $credentials -Workspace $WorkspaceName

#EndRegion


#Region -------------------------------------------------------- GLP workspace configuration -----------------------------------------------------------------------------------------


##################### Invite new users #############################################################################################################
  
  $NewUserEmail = "AdminCOM@gmail.com"

  Send-HPEGLUserInvitation -Email $NewUserEmail -Role 'Workspace Administrator' -SenderEmail $MyEmail 


##################### Add the HPE GreenLake role 'Workspace Observer' to the new user

  Add-HPEGLRoleToUser -Email $NewUserEmail -HPEGreenLakeRole 'Workspace Observer' 


##################### Provision the Compute Ops Management service manager in the central european region###########################################

  $Region = "eu-central"
  New-HPEGLService -Name "Compute Ops Management" -Region $Region
 

##################### Add the Compute Ops Management role 'Administrator' to your user #############################################################
  
  Add-HPEGLRoleToUser -Email $MyEmail -ComputeOpsManagementRole Administrator


##################### Add the Compute Ops Management role 'Administrator' to the new user###########################################################

  Add-HPEGLRoleToUser -Email $NewUserEmail -ComputeOpsManagementRole Administrator


##################### Create a new location#########################################################################################################
  
  $LocationName = "Mougins"
  
  New-HPEGLLocation -Name $LocationName -Description "My french location" `
    -Country France -Street "790 Avenue du Docteur Donat" -Street2 "Marco Polo - Bat B" -City $LocationName -State "N/A" -PostalCode "06254" `
    -PrimaryContactEmail $MyEmail -PrimaryContactPhone "+1234567890" 


##################### Add a device subscription key#################################################################################################

  New-HPEGLDeviceSubscription -SubscriptionKey "ABCDEFGH"


##################### Set auto compute device subscription##########################################################################################

  Set-HPEGLDeviceAutoSubscription -ComputeSubscriptionTier ENHANCED


##################### Add devices ##################################################################################################################


  # [Method 1] - Add devices one by one #################################################################
  
    Add-HPEGLDeviceCompute -SerialNumber "CZ2311004G" -PartNumber "P28948-B21" -Tags "Country=FR, App=AI, Departement=IT" 
    Add-HPEGLDeviceCompute -SerialNumber "CZ2311004H" -PartNumber "P28948-B21" -Tags "Country=FR, App=AI, Departement=IT" 


  # [Method 2] - Add devices using a CSV file and HPEiLOCmdlets module ##################################

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


  # [Method 3] - Add devices using Compute Ops Management Activation key ################################
  
    # Retrieve a valid subscription key with available quantity
    $Subscription_Key = Get-HPEGLDeviceSubscription -ShowWithAvailableQuantity -ShowValid -FilterByDeviceType SERVER | select -First 1 -ExpandProperty subscription_key

    # Retrieve an activation key for the Compute Ops Management service manager in the central european region using the subscription key
    $COM_Activation_Key = Get-HPECOMServerActivationKey -Region $Region -SubscriptionKey $Subscription_Key 
    
    $iLO_secureString_Proxy_Password = Read-Host -Prompt "Enter the proxy password" -AsSecureString

    # Connect all iLOs to the COM instance with proxy settings and activation key
    ForEach ($iLO in $iLOs) {
      
      try {
    
        $iLO_credential = Get-Credential -UserName $iLO.Username -Password $iLO.Password

        Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLO_credential -IloIP $iLO.IP -ActivationKeyfromCOM $COM_Activation_Key -IloProxyServer "web-proxy.domain.com" -IloProxyPort 8080 -IloProxyUserName "<username>" -IloProxyPassword $iLO_secureString_Proxy_Password
    
      }
      catch {
        "iLO {0} cannot be added ! Check your network access, iLO IP or credentials !" -f $iLO.IP
        continue
      }          
    }


##################### Set Device location ##########################################################################################################

  # Assign all devices to the location
  Get-HPEGLdevice | ? tags -like "*App=AI*" | Set-HPEGLDeviceLocation -LocationName $LocationName 

  # Or assign one device to the location
  Set-HPEGLDeviceLocation -DeviceSerialNumber "CZ2311004G" -LocationName $LocationName 

 
##################### Attach devices to a COM instance - Not required if [Method 3] is used ########################################################

  # Attach all devices to the COM instance
  Get-HPEGLDevice -ShowRequireAssignment | Add-HPEGLDeviceToService -ServiceName "Compute Ops Management" -ServiceRegion "$Region" 

  # Attach one device to a COM instance
  Add-HPEGLDeviceToService -DeviceSerialNumber "CZ2311004G"  -ServiceName "Compute Ops Management" -ServiceRegion "$Region" 


##################### Apply a device subscription key - Not required if auto-subscription is enabled or if [Method 3] is used ######################

  # Apply a subscription key to one device
  Set-HPEGLDeviceSubscription -DeviceSerialNumber "CZ2311004G" -SubscriptionKey $SubscriptionKey 

  # Apply a subscription key to all devices without a subscription
  Get-HPEGLdevice -ShowRequireAssignment | Set-HPEGLDeviceSubscription -SubscriptionKey $SubscriptionKey 


##################### Connect iLOs to a COM instance - Not required if [Method 3] is used ##########################################################
 
  # - Requirement: the compute device must be first assigned to a Compute Ops Management instance and attached to a valid subscription key.   

  $iLO_secureString_Proxy_Password = Read-Host -Prompt "Enter the proxy password" -AsSecureString

  # Connect all iLOs to the COM instance with proxy settings
  ForEach ($iLO in $iLOs) {
    
    try {

      $iLO_credential = Get-Credential -UserName $iLO.Username -Password $iLO.Password

      Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLO_credential -IloIP $iLO.IP -IloProxyServer "web-proxy.domain.com" -IloProxyPort 8080 -IloProxyUserName "<username>" -IloProxyPassword $iLO_secureString_Proxy_Password

    }
    catch {
      "iLO {0} cannot be added ! Check your network access, iLO IP or credentials !" -f $iLO.IP
      continue
    }          
  }

#EndRegion


#Region -------------------------------------------------------- COM instance configuration -----------------------------------------------------------------------------------------


##################### Create a new BIOS setting ####################################################################################################

  New-HPECOMSettingServerBios -Region $Region -Name "Custom-Bios-For-AI" -WorkloadProfileName "Virtualization - Max Performance" -AsrStatus:$True -AsrTimeoutMinutes Timeout10


##################### Create a new server setting for internal storage ############################################################################# 

  New-HPECOMSettingServerInternalStorage -Region $Region -Name "RAID-1" -RAID  RAID1 -Description "My RAID1 server setting for the OS" -EntireDisk


##################### Create a new server setting for the OS #######################################################################################

  New-HPECOMSettingServerOSImage -Region  $Region  -Name "Rocky9.4" -Description "Unattended deployment for Rocky 9.4" -OperatingSystem VMWARE_ESXI -OSImageURL "https://liogw.lj.lab/deployment/rocky94-x64/images/install.img"


##################### Create a new server setting for firmware #####################################################################################

  New-HPECOMSettingServerFirmware -Region $Region -Name "Firmware-bundle-2024.04.00.01" -Description "My FW bundle" -Gen10FirmwareBundleReleaseVersion $Gen10_Firmware_Bundle -Gen11FirmwareBundleReleaseVersion $Gen11_Firmware_Bundle -w


##################### Create a new group ###########################################################################################################

  # To find an existing firmware bundle
  $FW_Bundle_Name = Get-HPECOMFirmwareBundle -Region $Region -LatestVersion -Generation 10 | select -ExpandProperty Name

  New-HPECOMGroup -Region $Region -Name "AI_Group" -Description "My new group for AI servers" `
  -BiosSettingName "Custom-Bios-For-AI" -AutoBiosApplySettingsOnAdd:$true   `
  -FirmwareSettingName $FW_Bundle_Name -AutoFirmwareUpdateOnAdd:$True -PowerOffServerAfterFirmwareUpdate:$True -FirmwareDowngrade:$True `
  -OSSettingName "Rocky9.4" -AutoOsImageInstallOnAdd:$True -OsCompletionTimeoutMin 60 `
  -StorageSettingName "RAID-1" -StorageVolumeName "OS-vol" -AutoStorageVolumeCreationOnAdd:$True -AutoStorageVolumeDeletionOnAdd:$True  `
  -EnableiLOSettingsForSecurity:$True -AutoIloApplySettingsOnAdd:$True  `
  -TagUsedForAutoAddServer "App=AI" -w


######################################### Add servers to new group #################################################################################

  Get-HPECOMServer -Region $Region | ? tags -like "*App=AI*"  | Add-HPECOMServerToGroup -GroupName AI_Group 


######################################### Disable iLO Ignore Security Settings for Default SSL Certificate In Use ##################################
  
  Get-HPECOMServer -Region $Region | ? tags -like "*App=AI*"  |  Disable-HPECOMIloIgnoreSecuritySetting -DefaultSSLCertificateInUse 


######################################### Run a job to collect servers inventory data ##############################################################
  
  Get-HPECOMServer -Region $Region | ? tags -like "*App=AI*"  | New-HPECOMServerInventory 


######################################### Set iLO auto firmware update for servers #################################################################

  Get-HPECOMServer -Region $Region | ? tags -like "*App=AI*"  | ? autoIloFwUpdate -eq $False | Enable-HPECOMServerAutoiLOFirmwareUpdate 


######################################### Power on servers #########################################################################################

  Get-HPECOMServer -Region $Region | ? tags -like "*App=AI*"  | Start-HPECOMServer


######################################### Update server firmware  ##################################################################################

  # Get the latest firmware bundle
  $FW_Bundle_Release_Version = Get-HPECOMFirmwareBundle -Region $Region -LatestVersion -Generation 10 | select -ExpandProperty releaseVersion

  # Run a firmware update on all servers with a specific tag (without a schedule)
  Get-HPECOMServer -Region $Region | ? tags -like "*App=AI*"  | Update-HPECOMServerFirmware -FirmwareBundleReleaseVersion $FW_Bundle_Release_Version -InstallHPEDriversAndSoftware -AllowFirmwareDowngrade

  # Run a firmware update on all servers with a specific tag (with a specified schedule)
  Get-HPECOMServer -Region $Region | ? tags -like "*App=AI*"  | Update-HPECOMServerFirmware -FirmwareBundleReleaseVersion $FW_Bundle_Release_Version -InstallHPEDriversAndSoftware -AllowFirmwareDowngrade -ScheduleTime (Get-date).AddDays(1)


######################################### Update firmware on servers in a group ####################################################################

  # Run a group job to update firmware on all AI servers (without a schedule)
  Update-HPECOMGroupFirmware -Region $Region -GroupName "AI_Group" -AllowFirmwareDowngrade -InstallHPEDriversAndSoftware -PowerOffAfterUpdate -DisablePrerequisiteCheck 

  # Run a group job to update firmware on all AI servers (with a 4 days schedule)
  Update-HPECOMGroupFirmware -Region $Region -GroupName "AI_Group" -ScheduleTime (Get-Date).AddDays(4) -AllowFirmwareDowngrade -InstallHPEDriversAndSoftware -PowerOffAfterUpdate -DisablePrerequisiteCheck 

  # Run a group firmware compliance check on all servers in a group
  Invoke-HPECOMGroupFirmwareComplianceCheck -Region $Region -GroupName 'AI_Group' 

  # Get the firmware compliance status of servers in a group
  Get-HPECOMGroup -Region $Region -Name 'AI_Group' -ShowCompliance  


##################### Apply BIOS configuration on servers in a group ###############################################################################

  # Apply BIOS configuration on all servers in a group 
  Invoke-HPECOMGroupBiosConfiguration -Region $Region -GroupName "AI_Group" 

  # Apply BIOS configuration on servers with a specific tag
  Get-HPECOMServer -Region $Region | ? tags -like "*App=AI*" | Invoke-HPECOMGroupBiosConfiguration -GroupName "AI_Group"
  

##################### Apply Internal Storage Configuration on servers in a group ###################################################################

  # Apply internal storage configuration on all servers in a group 
  Invoke-HPECOMGroupInternalStorageConfiguration -Region $Region -GroupName "AI_Group" 

  # Apply internal storage configuration on servers with a specific tag
  Get-HPECOMServer -Region $Region | ? tags -like "*App=AI*" | Invoke-HPECOMGroupInternalStorageConfiguration -GroupName "AI_Group"


##################### Install OS on servers in a group #############################################################################################

  # Run a group job to install OS on all servers (without a schedule)
  Invoke-HPECOMGroupOSInstallation -Region $Region -GroupName "AI_Group" -ParallelInstallations -StopOnFailure -OSCompletionTimeoutMin 100

  # Run a group job to install OS on all servers (with a 4 hours schedule)
  Invoke-HPECOMGroupOSInstallation -Region $Region -GroupName "AI_Group" -ParallelInstallations -StopOnFailure -OSCompletionTimeoutMin 100 -ScheduleTime (Get-Date).AddHours(4)

  # Run a group job to install OS only on servers with a specific tag
  Get-HPECOMServer -Region $Region | ? tags -like "*App=AI*" | Invoke-HPECOMGroupOSInstallation -GroupName "AI_Group" 


##################### Generate a sustainability report every 7 days ################################################################################

  New-HPECOMSustainabilityReport -Region $Region -ScheduleTime (get-Date).addminutes(10) -Interval P7D 


##################### Enable email notification  ###################################################################################################

  # Subscribe the user account, used with 'Connect-HPEGL', to server notifications (service event issues) and daily summary notifications.
  Enable-HPECOMEmailNotificationPolicy -Region $Region -ServiceEventIssues -DailySummary


##################### Add ServiceNow ###############################################################################################################

  New-HPECOMExternalService -Name MyServiceNow_Name -Region $Region -Description "This is my description" -Credential $credential -RefreshToken "541646646434684343" -OauthUrl "https://example.service-now.com/oauth_token.do" -IncidentUrl "https://example.service-now.com/api/now/import/u_demo_incident_inbound_api" -refreshTokenExpiryInDays 100 


##################### Add OneView appliances  ######################################################################################################

  # Add an HPE OneView appliance to the Compute Ops Management instance (Requires OneView PowerShell library)
  $credentials = Get-Credential
  Connect-OVMgmt -Appliance "composer.domain.com"  -Credential $credentials
  $AddTask = Get-OVComputeOpsManagement | New-HPECOMApplianceOneView -Region $Region 
  Enable-OVComputeOpsManagement -ActivationKey  $AddTask.activationkey


##################### Upgrade OneView appliances  ##################################################################################################

  # Upgrade all OneView appliances (Synergy and VM) in the Compute Ops Management instance to latest FW bundle (if supported)
  $Appliance_FW_Bundle_Release_Version = Get-HPECOMApplianceFirmwareBundle -Region $Region -LatestVersion | select -first 1 -ExpandProperty applianceVersion
  $SupportedUpgrades = Get-HPECOMApplianceFirmwareBundle -Region $Region -LatestVersion -SupportedUpgrades
  $Appliances = Get-HPECOMOneViewAppliance -Region $Region 

  foreach ($Appliance in $Appliances) {

    $applianceVersion = $Appliance.version.substring(0, 7)

    if ($applianceVersion -in $SupportedUpgrades) {
      Update-HPECOMApplianceFirmware -Region $Region -IPAddress $Appliance.ipaddress -ApplianceFirmwareBundleReleaseVersion $Appliance_FW_Bundle_Release_Version -WhatIf
    }
    else {
      Write-Warning "The firmware bundle version ($Appliance_FW_Bundle_Release_Version) is not supported for upgrade with the current appliance version ($applianceVersion)."
    }
  }


#EndRegion


#Region -------------------------------------------------------- Disconnection from HPE GreenLake -----------------------------------------------------------------------------------

  # Disconnect from HPE GreenLake and clean up the session, temporary library API credentials, and environment variables
  Disconnect-HPEGL

#EndRegion