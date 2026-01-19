<#
.SYNOPSIS
This sample file provides a comprehensive guide for a typical zero-touch Compute Ops Management (COM) scenario.

.DESCRIPTION
This script demonstrates the process of creating a GreenLake workspace from scratch, including the creation of groups, settings, and other necessary configurations. 

It covers the following steps:

  1. Connect to the HPE GreenLake environment
  2. Create and manage an HPE GreenLake workspace
  3. Invite and manage users within the HPE GreenLake workspace
  4. Provision and manage services within the HPE GreenLake workspace
  5. Add service subscriptions
  6. Onboard servers to a service instance
  7. Generate detailed reports on server inventory data and sustainability
  8. Schedule weekly sustainability reports
  9. Apply location and tags to servers
  10. Create a group with policies and settings
  11. Add servers to the group
  12. Apply group settings to servers
  13. Generate server firmware compliance reports and update firmware
  14. Set email notifications for monitoring and maintenance of the workspace
  15. Add a ServiceNow instance to the Compute Ops Management instance
  16. Add OneView and Secure Gateway appliances
  17. Upgrade OneView appliances and set OneView server location
  18. Unprovision the HPE GreenLake workspace by removing server devices from service assignments and removing all subscriptions for workspace re-allocation, and deleting service instances.
  19. Disconnect from the HPE GreenLake environment

.NOTES
- This script cannot be used as is, as it contains many examples of how to use the library and provides several methods for the same task. 
- Users need to adapt this script to their specific use case. 
- It is intended for use by administrators who are familiar with HPE GreenLake and COM environments and assumes that the necessary permissions and access rights are in place.

#>


# HPE Account 
$MyEmail = "xxxx@xxx.xx"
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
  -State "<State>" `
  -PhoneNumber "<PhoneNumber>" 
  # -> This command automatically disconnects the session after creating the first and only workspace.

  # Connect to the new created workspace
  Connect-HPEGL -Credential $credentials -Workspace "My_first_workspace_name"


# [Method B] - Connection if you have a workspace #######################################################

  $WorkspaceName = "HPEWorkspace_53751220"
  Connect-HPEGL -Credential $credentials -Workspace $WorkspaceName


# [Method C] - Connect to a workspace when the workspace name is unknown ################################

  Connect-HPEGL -Credential $credentials
  # Get the list of workspaces
  Get-HPEGLWorkspace 
  # Connect to a workspace
  Connect-HPEGLWorkspace -Name "<WorkspaceName>"


#EndRegion


#Region -------------------------------------------------------- GLP workspace configuration -----------------------------------------------------------------------------------------


##################### Invite new users #############################################################################################################
  
  $NewUserEmail = "AdminCOM@gmail.com"

  Send-HPEGLUserInvitation -Email $NewUserEmail -Role 'Workspace Administrator' -SenderEmail $MyEmail 

  # Check the list of users that have been invited
  Get-HPEGLUser


  ##################### Add the HPE GreenLake role 'Workspace Observer' to the new user

  Add-HPEGLRoleToUser -Email $NewUserEmail -HPEGreenLakeRole 'Workspace Observer' 

  # Check the roles of the new user
  Get-HPEGLUserRole -Email $NewUserEmail


##################### Provision the Compute Ops Management service manager in the central european region ##########################################

  $Region = "eu-central"
  New-HPEGLService -Name "Compute Ops Management" -Region $Region
  
  # Check the list of services that have been provisioned
  Get-HPEGLService -ShowProvisioned


##################### Add the Compute Ops Management role 'Administrator' to your user #############################################################
  
  Add-HPEGLRoleToUser -Email $MyEmail -ComputeOpsManagementRole Administrator
  
  # Check the roles of your user 
  Get-HPEGLUserRole -Email $MyEmail


##################### Add the Compute Ops Management role 'Administrator' to the new user ##########################################################

  Add-HPEGLRoleToUser -Email $NewUserEmail -ComputeOpsManagementRole Administrator
  
  # Check the roles of the new user
  Get-HPEGLUserRole -Email $NewUserEmail


##################### Create a new location ########################################################################################################
  
  $LocationName = "<Name>"
  
  New-HPEGLLocation -Name $LocationName -Description "<Description>" `
    -Country "<Country>" -Street "<StreetAddress>" -Street2 "<StreetAddress2>" -City $LocationName -State "<State>" -PostalCode "<PostalCode>" `
    -PrimaryContactEmail $MyEmail -PrimaryContactPhone "<Phone number>" 

  # Check the list of locations that have been created
  Get-HPEGLLocation


##################### Add a subscription key #######################################################################################################

  New-HPEGLSubscription -SubscriptionKey "ABCDEFGH"
  
  # Check the list of subscription keys
  Get-HPEGLSubscription


##################### Set auto compute device subscription #########################################################################################

  Set-HPEGLDeviceAutoSubscription -ComputeSubscriptionTier ENHANCED
  # Remove-HPEGLDeviceAutoSubscription -Computes 
  
  # Check the auto compute device subscription
  Get-HPEGLDeviceAutoSubscription

  
##################### Set auto compute device subscription reassignment ############################################################################

Set-HPEGLDeviceAutoReassignSubscription -Computes
# Remove-HPEGLDeviceAutoReassignSubscription -Computes

# Check the auto compute device subscription reassignment
Get-HPEGLDeviceAutoReassignSubscription


##################### Add devices ##################################################################################################################


  # [Method 1] - Add devices one by one #################################################################
  
    Add-HPEGLDeviceCompute -SerialNumber "CZ12345678" -PartNumber "P28948-B21" -Tags "Country=FR, App=AI, Department=IT" 
    Add-HPEGLDeviceCompute -SerialNumber "DZ12345678" -PartNumber "P28948-B21" -Tags "Country=FR, App=AI, Department=IT" 

    # Check the list of devices that have been added
    Get-HPEGLDevice 


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

    # Check the list of devices that have been added
    Get-HPEGLDevice



  # [Method 3] - Add devices using the Compute Ops Management Activation Key [Supported only with iLO5: version 3.09 or later and iLO6: version 1.64 or later] ################################
  
  # With this method:
  # 1- Compute devices are added to the HPE GreenLake workspace.
  # 2- Compute devices are attached to the Compute Ops Management instance from which the provided activation key was generated.
  # 3- Compute devices are assigned to the Compute Ops Management subscription key set by 'New-HPECOMServerActivationKey' or by the auto subscription policy using 'Set-HPEGLDeviceAutoSubscription'.
  # 4- iLOs of the compute devices are connected to the Compute Ops Management instance from which the provided activation key was generated.
   
  # - Requirement: An activation key is required and can be generated using 'New-HPECOMServerActivationKey'. The COM activation key is not supported for iLO5 versions lower than v3.09 and iLO6 versions lower than v1.59 
  # - You can use 'Get-HPECOMServerActivationKey' to retrieve all generated and valid activation keys for the different Compute Ops Management instances where you want the compute device to be connected.
  
  # The CSV file should contain the iLO IP address, a user account, password in the following format:
  
    #    IP, Username, Password
    #    192.168.0.1, admin, password
    #    192.168.0.2, Administrator, password
    #    192.168.0.3, demo, password
  
    $iLOs = import-csv Sample\iLOs.csv -Delimiter ","

    # Retrieve a valid subscription key with available quantity (required when 'Set-HPEGLDeviceAutoSubscription' is not used)
    # $Subscription_Key = Get-HPEGLSubscription -ShowWithAvailableQuantity -ShowValid -ShowDeviceSubscriptions -FilterBySubscriptionType Server | Select-Object -First 1 -ExpandProperty key

    # A- Direct connection:

      # Generate an activation key for connecting servers to the Compute Ops Management service manager in the central european region [with iLO5: v3.09 or later - iLO6: v1.64 or later] 
      $Activation_Key = New-HPECOMServerActivationKey -Region $Region # -SubscriptionKey $Subscription_Key (required when 'Set-HPEGLDeviceAutoSubscription' is not used)
      
    # B- Secure gateway connection:

      # Generate an activation key for the Compute Ops Management secure gateway in the central european region 
      $SecureGatewayName = Get-HPECOMAppliance -Region $Region -Type SecureGateway | Select-Object -first 1 -ExpandProperty name
      $Activation_Key = New-HPECOMServerActivationKey -Region $Region -SecureGateway $SecureGatewayName  # -SubscriptionKey $Subscription_Key (required when 'Set-HPEGLDeviceAutoSubscription' is not used)
      
    Get-HPECOMServerActivationKey -Region $Region
      
    # Connect all iLOs to the COM instance with proxy settings and activation key

    ForEach ($iLO in $iLOs) {
      
      try {
        
        $iLO_SecurePassword = ConvertTo-SecureString $ILO.Password -AsPlainText -Force
        $iLO_credential = New-Object System.Management.Automation.PSCredential ($iLO.Username, $iLO_SecurePassword)
        
        # 1- Connect iLO directly
        Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLO_credential -IloIP $iLO.IP -ActivationKeyfromCOM $Activation_Key 

        # 2- Connect iLO through the COM secure gateway
        Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLO_credential -IloIP $iLO.IP -ActivationKeyfromCOM $Activation_Key -IloProxyServer $SecureGatewayName -IloProxyPort 8080 
        
        # 3- Connect iLO directly through a proxy 
        $iLO_secureString_Proxy_Password = Read-Host -Prompt "Enter the proxy password" -AsSecureString
        Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLO_credential -IloIP $iLO.IP -ActivationKeyfromCOM $Activation_Key -IloProxyServer "webproxy.domain.com" -IloProxyPort 8080 -IloProxyUserName "<username>" -IloProxyPassword $iLO_secureString_Proxy_Password
  
      }
      catch {
        "iLO {0} cannot be connected to COM ! Check your network access, iLO IP or credentials !" -f $iLO.IP
        continue
      }          
    }

    # Add tags to all devices
    Get-HPEGLDevice | Add-HPEGLDeviceTagToDevice -Tags "Country=FR, App=AI, Department=IT" 


    # Check the list of devices that have been added
    Get-HPEGLdevice

    # Check the list of devices that have been added with tags
    Get-HPEGLdevice -ShowTags

    # Check the list of devices that have been added in direct connection
    Get-HPECOMServer -Region $Region -ConnectionType Direct

    # Check the list of devices that have been added through the secure gateway
    Get-HPECOMServer -Region $Region -ConnectionType 'Secure gateway'


##################### Set Device location ##########################################################################################################

  # Assign all devices to the location
  Get-HPEGLdevice | Where-Object tags -match "AI" | Set-HPEGLDeviceLocation -LocationName $LocationName 

  # Or assign one device to the location
  Set-HPEGLDeviceLocation -DeviceSerialNumber "CZ12345678" -LocationName $LocationName 

  # Check the location that have been assigned in the list of devices 
  Get-HPEGLdevice
 
##################### Attach devices to a COM instance - Not required if [Method 3] was used ########################################################

  # Attach all devices to the COM instance
  Get-HPEGLDevice -ShowRequireAssignment | Add-HPEGLDeviceToService -ServiceName "Compute Ops Management" -ServiceRegion $Region

  # Attach one device to a COM instance
  Add-HPEGLDeviceToService -DeviceSerialNumber "CZ12345678"  -ServiceName "Compute Ops Management" -ServiceRegion $Region

  # Get the list of devices that have a tag 'AI' 
  Get-HPEGLdevice | Where-Object tags -match "AI"


##################### Apply a device subscription key - Not required if auto-subscription is enabled or if [Method 3] was used ######################

  # Apply a subscription key to one device
  Add-HPEGLSubscriptionToDevice -SubscriptionKey $SubscriptionKey -DeviceSerialNumber "CZ12345678" 

  # Apply a subscription key to all devices without a subscription
  Get-HPEGLdevice -ShowRequireAssignment | Add-HPEGLSubscriptionToDevice -SubscriptionKey $SubscriptionKey 

  # Get the list of devices that are ready to be connected to COM
  Get-HPEGLdevice -ShowComputeReadyForCOMIloConnection 


##################### Connect iLOs to a COM instance - Not required if [Method 3] was used ##########################################################
 
  # - Requirement: the compute device must be first assigned to a Compute Ops Management instance and attached to a valid subscription key.   

  $iLO_secureString_Proxy_Password = Read-Host -Prompt "Enter the proxy password" -AsSecureString

  # Connect all iLOs to the COM instance with proxy settings
  ForEach ($iLO in $iLOs) {
    
    try {

      $iLO_credential = Get-Credential -UserName $iLO.Username -Password $iLO.Password

      Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLO_credential -IloIP $iLO.IP -IloProxyServer "webproxy.domain.com" -IloProxyPort 8080 -IloProxyUserName "<username>" -IloProxyPassword $iLO_secureString_Proxy_Password

    }
    catch {
      "iLO {0} cannot be added ! Check your network access, iLO IP or credentials !" -f $iLO.IP
      continue
    }          
  }

  # Check the connection status of all devices (ConnectedState property)
  Get-HPECOMServer -Region $Region -ConnectionType Direct

#EndRegion


#Region -------------------------------------------------------- COM instance configuration -----------------------------------------------------------------------------------------


##################### Create a new BIOS setting ####################################################################################################

  $BiosSettingName = "Custom-Bios-For-AI"
  New-HPECOMSettingServerBios -Region $Region -Name  $BiosSettingName -WorkloadProfileName "Virtualization - Max Performance" -AsrStatus:$True -AsrTimeoutMinutes Timeout10

  # Get the BIOS setting
  Get-HPECOMSetting -Region $Region -Name  $BiosSettingName


##################### Create a new server setting for internal storage ############################################################################# 

  $InternalStorageSettingName = "RAID-1"
  New-HPECOMSettingServerInternalStorage -Region $Region -Name $InternalStorageSettingName -RAID  RAID1 -Description "My RAID1 server setting for the OS" -EntireDisk

  # Get the internal storage setting
  Get-HPECOMSetting -Region $Region -Name $InternalStorageSettingName


##################### Create a new server setting for the OS #######################################################################################

  $OSSettingName = "Rocky9.4"
  New-HPECOMSettingServerOSImage -Region  $Region -Name  $OSSettingName -Description "Unattended deployment of Rocky 9.4" -OperatingSystem CUSTOM -OSImageURL "https://webserver.lab/deployment/rocky94-x64/Rocky-9.4-x86_64-boot.iso"

  # Get the OS setting
  Get-HPECOMSetting -Region $Region -Name $OSSettingName


##################### Create a new server setting for firmware #####################################################################################

  $FirmwareSettingName = "Firmware-bundle-2024.04.00.01"
  $Gen10_Firmware_Bundle = Get-HPECOMFirmwareBaseline -Region $Region -LatestVersion -Generation 10 | Select-Object -ExpandProperty releaseVersion
  $Gen11_Firmware_Bundle = Get-HPECOMFirmwareBaseline -Region $Region -LatestVersion -Generation 11 | Select-Object -ExpandProperty releaseVersion
  New-HPECOMSettingServerFirmware -Region $Region -Name $FirmwareSettingName -Description "FW bundle for AI servers" -Gen10FirmwareBundleReleaseVersion $Gen10_Firmware_Bundle -Gen11FirmwareBundleReleaseVersion $Gen11_Firmware_Bundle 

  # Get the firmware setting
  Get-HPECOMSetting -Region $Region -Name $FirmwareSettingName


##################### Create a new group ###########################################################################################################

  $GroupName = "AI_Group"

  New-HPECOMGroup -Region $Region -Name $GroupName -Description "My new group for AI servers" `
  -BiosSettingName $BiosSettingName -AutoBiosApplySettingsOnAdd:$false   `
  -FirmwareSettingName $FirmwareSettingName -AutoFirmwareUpdateOnAdd:$false -PowerOffServerAfterFirmwareUpdate:$false -FirmwareDowngrade:$false `
  -OSSettingName $OSSettingName -AutoOsImageInstallOnAdd:$false -OsCompletionTimeoutMin 60 `
  -StorageSettingName $InternalStorageSettingName -StorageVolumeName "OS-vol" -AutoStorageVolumeCreationOnAdd:$false -AutoStorageVolumeDeletionOnAdd:$false  `
  -EnableiLOSettingsForSecurity:$true -AutoIloApplySettingsOnAdd:$true  `
  -TagUsedForAutoAddServer "App=AI" 

  # Check the group settings
  Get-HPECOMGroup -Region $Region -Name $GroupName -ShowSettings

  # Check the group policies
  Get-HPECOMGroup -Region $Region -Name $GroupName -ShowPolicies


######################################### Add servers to new group #################################################################################

  Get-HPECOMServer -Region $Region | Where-Object tags -match "AI" | Add-HPECOMServerToGroup -GroupName $GroupName  

  # Check the group membership
  Get-HPECOMGroup -Region $Region -Name $GroupName -ShowMembers
  # Alternative command to get the group membership of all servers
  Get-HPECOMServer -Region $Region -ShowGroupMembership


######################################### Disable iLO Ignore Security Settings for Default SSL Certificate In Use ##################################
  
  Get-HPECOMServer -Region $Region | Where-Object tags -match "AI" |  Disable-HPECOMIloIgnoreRiskSetting -DefaultSSLCertificateInUse 
  Get-HPECOMServer -Region $Region | Where-Object tags -match "AI" |  Get-HPECOMServer -ShowSecurityParameters 

  # Check the status of the iLO Ignore Security Settings
  Get-HPECOMServer -Region $Region -Name "<servername>" -ShowSecurityParametersDetails 
  
  # Enable iLO Ignore Security Settings for Default SSL Certificate In Use
  Get-HPECOMServer -Region $Region -Name "<servername>" |  Enable-HPECOMIloIgnoreSecuritySetting -DefaultSSLCertificateInUse 


######################################### Run a job to collect servers inventory data ##############################################################
  
  Get-HPECOMServer -Region $Region | Where-Object tags -match "AI" | New-HPECOMServerInventory -Async

  # Check the status of jobs with the category 'Server' and the name 'GetFullServerInventory'
  Get-HPECOMJob -Region $Region -Category Server -Name GetFullServerInventory
  # Alternative command to get the status of all running jobs with the category 'Server'
  Get-HPECOMJob -Region $Region -Category Server -ShowRunning

  # Get memory inventory data for a server
  Get-HPECOMServer -Region $Region -Name "<servername>" | Get-HPECOMServerInventory -ShowMemory
  # Get processor inventory data for a server
  Get-HPECOMServer -Region $Region -Name "<servername>" | Get-HPECOMServerInventory -ShowProcessor
  # Get network adapter inventory data for a server
  Get-HPECOMServer -Region $Region -Name "<servername>" | Get-HPECOMServerInventory -ShowNetworkAdapter
  # etc.

######################################### Set iLO auto firmware update for servers #################################################################

  Get-HPECOMServer -Region $Region | Where-Object tags -match "AI" | Where-Object autoIloFwUpdate -eq $False | Enable-HPECOMServerAutoiLOFirmwareUpdate 

  # Check the status of the iLO auto firmware update
  Get-HPECOMServer -Region $Region | Where-Object tags -match "AI" | Get-HPECOMServer -ShowAutoiLOFirmwareUpdateStatus 


######################################### Power actions on servers #########################################################################################

  Get-HPECOMServer -Region $Region | Where-Object tags -match "AI" | Start-HPECOMServer -Async
  Get-HPECOMServer -Region $Region | Where-Object tags -match "AI" | Stop-HPECOMServer -Async
  Get-HPECOMServer -Region $Region | Where-Object tags -match "AI" | Restart-HPECOMServer -ScheduleTime (Get-Date).AddMinutes(60)  # Restart in 60 minutes
  
  # Check the status of the power state of servers
  Get-HPECOMServer -Region $Region | Where-Object tags -match "AI" 

  # Check the list of job schedules 
  Get-HPECOMSchedule -Region $Region 

  # Remove all schedules
  Get-HPECOMSchedule -Region $Region | Remove-HPECOMSchedule 


######################################### Update server firmware  ##################################################################################

  # Get the latest firmware bundle for Gen10
  $FW_Bundle_Release_Version = Get-HPECOMFirmwareBaseline -Region $Region -LatestVersion  -Generation 10 | Select-Object -ExpandProperty releaseVersion

  # Run a firmware update on all Gen10 servers (without a schedule)
  Get-HPECOMServer -Region $Region | Where-Object serverGeneration -match "10" | Update-HPECOMServerFirmware -FirmwareBundleReleaseVersion $FW_Bundle_Release_Version -InstallHPEDriversAndSoftware -AllowFirmwareDowngrade -Async

  # Run a firmware update on all servers with a specific tag (with a specified schedule)
  Get-HPECOMServer -Region $Region | Where-Object tags -match "AI" | Update-HPECOMServerFirmware -FirmwareBundleReleaseVersion $FW_Bundle_Release_Version -InstallHPEDriversAndSoftware -AllowFirmwareDowngrade -ScheduleTime (Get-date).AddDays(1) # Run in 1 day

  # Check the status of the firmware update job
  Get-HPECOMSchedule -Region $Region
  # Get the status of all running jobs with the category 'Server'
  Get-HPECOMJob -Region $Region -Category Server -ShowRunning


######################################### Update firmware on servers in a group ####################################################################

  # Run a group job to update firmware on all AI servers (without a schedule)
  Update-HPECOMGroupFirmware -Region $Region -GroupName $GroupName -AllowFirmwareDowngrade -InstallHPEDriversAndSoftware -PowerOffAfterUpdate -DisablePrerequisiteCheck -Async

  # Run a group job to update firmware on all AI servers (with a 4 days schedule)
  Update-HPECOMGroupFirmware -Region $Region -GroupName $GroupName -AllowFirmwareDowngrade -InstallHPEDriversAndSoftware -PowerOffAfterUpdate -DisablePrerequisiteCheck -ScheduleTime (Get-Date).AddDays(4)  

  # Check the list of job schedules 
  Get-HPECOMSchedule -Region $Region
  # Get the status of all running jobs with the category 'Group'
  Get-HPECOMJob -Region $Region -Category Group -ShowRunning


######################################### Run a group firmware compliance check ####################################################################

  # Run a group firmware compliance check on all servers in a group
  Invoke-HPECOMGroupFirmwareComplianceCheck -Region $Region -GroupName $GroupName -Async

  # Check the status of the group firmware compliance check job
  Get-HPECOMJob -Region $Region -Category Group
  # Get the status of all running jobs with the category 'Group'
  Get-HPECOMJob -Region $Region -Category Group -ShowRunning
  

######################################### Get the firmware compliance status of servers in a group ####################################################

  # Get the firmware compliance status of servers in a group
  Get-HPECOMGroup -Region $Region -Name $GroupName -ShowCompliance  

  # Get the firmware deviation status of a server in a group
  Get-HPECOMServer -Region $Region -Name "<servername>" -ShowGroupFirmwareDeviation


##################### Apply BIOS configuration on servers in a group ###############################################################################

  # Apply BIOS configuration on all servers in a group 
  Invoke-HPECOMGroupBiosConfiguration -Region $Region -GroupName $GroupName -Async

  # Apply BIOS configuration on servers with a specific tag
  Get-HPECOMServer -Region $Region | Where-Object tags -match "AI"| Invoke-HPECOMGroupBiosConfiguration -GroupName $GroupName -Async

  # Get the status of all running jobs with the category 'Group'
  Get-HPECOMJob -Region $Region -Category Group -ShowRunning
  

##################### Apply Internal Storage Configuration on servers in a group ###################################################################

  # Apply internal storage configuration on all servers in a group 
  Invoke-HPECOMGroupInternalStorageConfiguration -Region $Region -GroupName $GroupName -Async 

  # Apply internal storage configuration on servers with a specific tag
  Get-HPECOMServer -Region $Region | Where-Object tags -match "AI"| Invoke-HPECOMGroupInternalStorageConfiguration -GroupName $GroupName -Async

  # Get the status of all running jobs with the category 'Group'
  Get-HPECOMJob -Region $Region -Category Group -ShowRunning


##################### Install OS on servers in a group #############################################################################################

  # Run a group job to install OS on all servers (without a schedule)
  Invoke-HPECOMGroupOSInstallation -Region $Region -GroupName $GroupName -ParallelInstallations -StopOnFailure -OSCompletionTimeoutMin 100 -Async

  # Run a group job to install OS only on servers with a specific tag
  Get-HPECOMServer -Region $Region | Where-Object tags -match "AI"| Invoke-HPECOMGroupOSInstallation -GroupName $GroupName -Async

  # Run a group job to install OS on all servers (with a 4 hours schedule)
  Invoke-HPECOMGroupOSInstallation -Region $Region -GroupName $GroupName -ParallelInstallations -StopOnFailure -OSCompletionTimeoutMin 100 -ScheduleTime (Get-Date).AddHours(4)

  # Check the list of job schedules 
  Get-HPECOMSchedule -Region $Region

  # Get the status of all running jobs with the category 'Group'
  Get-HPECOMJob -Region $Region -Category Group -ShowRunning


##################### Generate a sustainability report every 7 days ################################################################################

  # Generate a sustainability report (CO2 emissions, energy cost, energy consumption) for all servers in the central european region
  New-HPECOMSustainabilityReport -Region $Region -Async

  # Generate a sustainability report every 7 days
  New-HPECOMSustainabilityReport -Region $Region -ScheduleTime (get-Date).addminutes(10) -Interval P7D 

  # Check the list of job schedules 
  Get-HPECOMSchedule -Region $Region

  # Get the status of all running jobs with the category 'Filter'
  Get-HPECOMJob -Region $Region -Category Filter

  # Get the status of all running jobs with the category 'Sustainability'
  Get-HPECOMSustainabilityReport -Region $Region -Co2EmissionsTotal
  Get-HPECOMSustainabilityReport -Region $Region -EnergyCostTotal
  Get-HPECOMSustainabilityReport -Region $Region -EnergyConsumptionTotal 


##################### Enable email notification  ###################################################################################################

  # Subscribe the user account, used with 'Connect-HPEGL', to server notifications (service event issues) and daily summary notifications.
  Enable-HPECOMEmailNotificationPolicy -Region $Region -ServiceEventIssues -DailySummary 

  # Get the email notification policy
  Get-HPECOMEmailNotificationPolicy -Region $Region 


##################### ServiceNow integration #######################################################################################################

  # Create a ServiceNow integration in the Compute Ops Management instance.
  $ServiceNowCredential = Get-Credential -Message "Enter your ServiceNow clientID and clientSecret"

  New-HPECOMExternalService -Region $Region -ServiceNow -Name "ServiceNow integrastion" -Credential $ServiceNowCredential `
  -Description "This is my ServiceNow integration" -RefreshToken "541646646434684343" -OauthUrl "https://example.service-now.com/oauth_token.do" `
  -IncidentUrl "https://example.service-now.com/api/now/import/u_demo_incident_inbound_api" -refreshTokenExpiryInDays 100 

  # Get the list of external services that have been added
  Get-HPECOMExternalService -Region $Region 


##################### Data Services Cloud Console integration #####################################################################################

  # Create in the Compute Ops Management instance a Data Services Cloud Console integration configured in the US-west region.
  $DSCCcredentials = Get-Credential -Message "Enter your clientID and clientSecret"

  New-HPECOMExternalService -Region eu-central -DSCC -Name "Data Services Cloud Console integration" -Description "This is my DSCC service in US-West" -DSCCRegion "us-west" -Credential $DSCCcredentials

  # Get the list of external services that have been added
  Get-HPECOMExternalService -Region $Region 
  

##################### Add OneView appliance ########################################################################################################

  # Add an HPE OneView appliance to the Compute Ops Management instance (requires OneView PowerShell library)
  $credentials = Get-Credential
  # Connect to the OneView appliance
  Connect-OVMgmt -Appliance "composer.domain.com"  -Credential $credentials
  # Add the OneView appliance to the Compute Ops Management instance
  $AddTask = Get-OVComputeOpsManagement | New-HPECOMAppliance -Region $Region 
  # Collect the Activation key returned by the previous command and use it to connect the OneView appliance to COM
  Enable-OVComputeOpsManagement -ActivationKey  $AddTask.activationkey

  # Get the list of OneView appliances that have been added
  Get-HPECOMAppliance -Region $Region


##################### Add Secure Gateway appliance #################################################################################################

  # Add an Secure Gateway appliance to the Compute Ops Management instance (requires access to the Secure Gateway console)
  New-HPECOMAppliance -Region $Region -SecureGateway 
  # Collect the Activation key returned by the command and enter it in the Secure Gateway console to connect the appliance to COM

  # Get the list of OneView appliances that have been added
  Get-HPECOMAppliance -Region $Region

  # Get the list of servers that are connected to a OneView appliance
  Get-HPECOMServer -Region $Region -ConnectionType 'OneView managed'
  # Get the list of servers that are connected to a Secure Gateway appliance
  Get-HPECOMServer -Region $Region -ConnectionType 'Secure gateway'


##################### Upgrade OneView appliances  ##################################################################################################

  # Upgrade all OneView appliances (Synergy and VM) in the Compute Ops Management instance to latest FW bundle (if supported)
  $Appliance_FW_Bundle_Release_Version = Get-HPECOMApplianceFirmwareBundle -Region $Region -LatestVersion | Select-Object -first 1 -ExpandProperty applianceVersion
  $SupportedUpgrades = Get-HPECOMApplianceFirmwareBundle -Region $Region -LatestVersion -SupportedUpgrades
  $Appliances = Get-HPECOMAppliance -Region $Region 

  foreach ($Appliance in $Appliances) {

    $applianceVersion = $Appliance.version.substring(0, 7)

    if ($applianceVersion -in $SupportedUpgrades) {
      Update-HPECOMApplianceFirmware -Region $Region -IPAddress $Appliance.ipaddress -ApplianceFirmwareBundleReleaseVersion $Appliance_FW_Bundle_Release_Version -Async
    }
    else {
      Write-Warning "The firmware bundle version ($Appliance_FW_Bundle_Release_Version) is not supported for upgrade with the current appliance version ($applianceVersion)."
    }
  }

  # Check the status of the appliance firmware upgrade job
  Get-HPECOMJob -Region $Region -Category Oneview-appliance


##################### Set OneView server location ###################################################################################################

  # Set server using 'OneView managed' connection type to a location 
  Get-HPECOMServer -Region $Region -ConnectionType 'OneView managed' | Set-HPECOMOneViewServerLocation -LocationName $LocationName 

  # Check the location that have been assigned in the list of OneView managed servers
  Get-HPECOMServer -Region $Region -ConnectionType 'OneView managed' -ShowLocation
  

#EndRegion


#Region -------------------------------------------------------- GLP workspace cleaning -----------------------------------------------------------------------------------

  # Remove server devices from service assignment
  Get-HPEGLDevice -FilterByDeviceType SERVER | Remove-HPEGLDeviceFromService 

  # Check the servers have been removed from their assignments
  Get-HPEGLDevice -ShowRequireAssignment

  # Remove all 'Server' type subscriptions from the workspace (in case you want to use the same keys for another workspace)
  Get-HPEGLSubscription -FilterBySubscriptionType Server | Remove-HPEGLSubscription

  # Check the subscription keys have been removed
  Get-HPEGLDeviceSubscription

  # Delete the COM service instance. This will remove all servers, groups, settings, and policies associated with the service instance.
  Get-HPEGLService -ShowProvisioned -Name "Compute Ops Management" | Remove-HPEGLService
  
#EndRegion


#Region -------------------------------------------------------- Disconnection from HPE GreenLake -----------------------------------------------------------------------------------

  # Disconnect from HPE GreenLake and clean up the session, temporary library API credentials, and environment variables
  Disconnect-HPEGL

#EndRegion