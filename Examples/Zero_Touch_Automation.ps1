<#

.DESCRIPTION
This script creates an HPE GreenLake workspace from scratch, including the onboarding of servers, the creation of groups, settings, and other necessary configurations.

It covers the following steps:

  1. Connect to the HPE GreenLake environment.
  2. Create a new HPE GreenLake workspace.
  3. Invite new admin and observer users.
  4. Provision a Compute Ops Management (COM) service.
  5. Add the COM admin and observer roles to the users.
  6. Create a new location.
  7. Add a COM subscription key.
  8. Set automatic device subscription for the COM service manager.
  9. Generate a COM activation key for connecting servers to the COM service manager in the specified region.
  10. Onboard the specified servers to the COM service instance.
  11. Check device presence in HPE GreenLake.
  12. Add tags to all devices.
  13. Assign all devices to the defined location for automated HPE support case creation and services.
  14. Check server presence in COM.
  15. Wait for inventory to be completed.
  16. Create a new server setting for BIOS.
  17. Create a new server setting for internal storage.
  18. Create a new server setting for OS.
  19. Create a new server setting for firmware.
  20. Create a new group.
  21. Add all servers to the new group.
  22. Set iLO auto firmware update for all servers.
  23. Enable email notifications.
  24. Create a ServiceNow integration in COM.
  25. Disable iLO Ignore Security Settings for Default SSL Certificate In Use.
  26. Disconnect from the HPE GreenLake environment.

.NOTES
- Customize the variables in the variable definition section as needed.
- This script is intended for use by administrators who are familiar with HPE GreenLake and COM environments and assumes that the necessary permissions and access rights are in place.
- The script uses the HPECOMCmdlets PowerShell module to interact with the HPE GreenLake environment. See https://github.com/jullienl/HPE-COM-PowerShell-Library
- The script has been tested with PowerShell 7.1.3 and HPECOMCmdlets 1.0.10.

#>



#Region -------------------------------------------------------- Variables definition -----------------------------------------------------------------------------------------

# HPE account Credentials
$MyHPEAccount = "email@domain.com"
$MyHPEAccountSecuredPassword = Read-Host -AsSecureString "Enter password for your HPE account '$MyHPEAccount'"

# Workspace name to create
$WorkspaceName = "HPEWorkspace_1524014010"
$WorkspaceType = 'Standard enterprise workspace'
$WorkspaceCountry = "France"

# Administrator users to invite to workspace

$AdministratorUserEmails = @("Admin1@email.com", "Admin2@email.com")

# Observer users to invite to workspace

$ObserverUserEmails = @("Observer1@email.com", "Observer2@email.com")
  
# Compute Ops Management instance to provision in the workspace
$Region = "eu-central"

# Location details (a location must be assigned to devices for automated HPE support case creation and services)
$LocationName = "Nice"
$LocationCity = "Nice"
$LocationAddress = "Promenade des anglais"
$LocationState = "N/A"
$LocationPostalCode = 06000
$LocationCountry = "France"

# Compute Ops Management subscription key
$COMSubscriptionKey = "ABCDEFGHIJKLM"

# Servers to onboard to the workspace
$ServersList = @"
IP, Username, Password
192.168.0.1, admin, password
192.168.0.2, Administrator, password
192.168.0.3, demo, password
"@

# Tags to assign to devices
$Tags = "Country=FR, App=AI, Department=IT" 

# Secure Gateway (if any) to use for iLO connections (optional)
# $SecureGateway = "sg01.domain.com

# Server BIOS setting name
$BiosSettingName = "Custom-Bios-For-AI"
$WorkloadProfileName = "Virtualization - Max Performance"

# Server OS setting name
$OSSettingName = "Rocky-9.4"
$OSSettingImageURL = "https://webserver.lab/deployment/rocky94-x64/Rocky-9.4-x86_64-boot.iso"
$OSSettingOSType = "CUSTOM"  # MICROSOFT_WINDOWS, RHEL, SUSE_LINUX, VMWARE_ESXI
$OSVolumeName = "OSVolume_" + $OSSettingName

# Server internal storage setting name
$InternalStorageSettingName = "RAID1&5-For-AI"

# Server firmware setting name
$FirmwareSettingName = "Firmware-bundle-2024.04.00.01"

# Group name
$GroupName = "AI_Group"

# ServiceNow integration details
# $ServiceNowCredential = Get-Credential -Message "Enter your ServiceNow clientID and clientSecret"
$clientID = "121367875-423-04230423400"
$clientSecret = "xxxxxxxxxxxxxxxxxxxxxx"
$secclientSecret = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force
$ServiceNowCredential = New-Object System.Management.Automation.PSCredential ($clientID, $secclientSecret)
$ServiceNowName = "ServiceNow"
$ServiceNowRefreshToken = "541646646434684343" 
$ServiceNowOauthUrl = "https://example.service-now.com/oauth_token.do" 
$ServiceNowIncidentUrl = "https://example.service-now.com/api/now/import/u_demo_incident_inbound_api" 
$ServiceNowRefreshTokenExpiryInDays = 100 

# Data Services Cloud Console integration details
# $DSCCcredentials = Get-Credential -Message "Enter your DSCC clientID and clientSecret"
$clientID = "121367875-423-04230423400"
$clientSecret = "xxxxxxxxxxxxxxxxxxxxxx"
$secclientSecret = ConvertTo-SecureString -String $clientSecret -AsPlainText -Force
$DSCCcredentials = New-Object System.Management.Automation.PSCredential ($clientID, $secclientSecret)
$DSCCName = "Data Services Cloud Console integration"
$DSCCRegion = "eu-central"

# Importing the servers list

$iLOs = $ServersList | ConvertFrom-Csv

# Testing network access to first iLO

$pingResult = Test-Connection -ComputerName $iLOs[0].ip -Count 2 -ErrorAction SilentlyContinue

if ($pingResult.Status[1] -ne 'Success') {
    Write-Warning "Unable to access iLOs. Please check your network connection or ensure that your VPN is connected."
    return
}

#EndRegion

#Region -------------------------------------------------------- Connection to HPE GreenLake -----------------------------------------------------------------------------------------

$GLPcredentials = New-Object System.Management.Automation.PSCredential ($MyHPEAccount, $MyHPEAccountSecuredPassword)

Connect-HPEGL -Credential $GLPcredentials

#EndRegion


#Region -------------------------------------------------------- GLP workspace configuration -----------------------------------------------------------------------------------------

# Create new workspace

$resp = New-HPEGLWorkspace -Name $WorkspaceName -Type $WorkspaceType -Country $WorkspaceCountry 
"`n[Create new workspace '{0}'] - Status: {1} - Details: {2}" -f $WorkspaceName, $resp.Status, $resp.Details

# Connect to workspace

if (-not $HPEGreenLakeSession.workspaceId) {
    Connect-HPEGL -Credential $GLPcredentials -Workspace $WorkspaceName 

}
elseif ($HPEGreenLakeSession.workspace -ne $WorkspaceName) {
    
    Connect-HPEGLWorkspace -Name $WorkspaceName 
}

# Invite new users

foreach ($AdministratorUserEmail in $AdministratorUserEmails) {
    $resp = $AdministratorUserEmail | Send-HPEGLUserInvitation -Role 'Workspace Administrator'
    "`n[Invite new administrator user '{0}'] - Status: {1} - Details: {2}" -f $AdministratorUserEmail, $resp.Status, $resp.Details
}

foreach ($ObserverUserEmail in $ObserverUserEmails) {
    $resp = $ObserverUserEmail | Send-HPEGLUserInvitation -Role 'Workspace Observer'
    "`n[Invite new observer user '{0}'] - Status: {1} - Details: {2}" -f $ObserverUserEmail, $resp.Status, $resp.Details
}

# Provision the Compute Ops Management service manager in the central european region 

$resp = New-HPEGLService -Name "Compute Ops Management" -Region $Region
"`n[Provision COM in '{0}'] - Status: {1} - Details: {2}" -f $Region, $resp.Status, $resp.Details

# Add the Compute Ops Management roles to the users
   
$resp = $MyHPEAccount | Add-HPEGLRoleToUser -ComputeOpsManagementRole Administrator
"`n[Add the Compute Ops Management administrator roles to '{0}'] - Status: {1} - Details: {2}" -f $MyHPEAccount, $resp.Status, $resp.Details

foreach ($AdministratorUserEmail in $AdministratorUserEmails) {
    $resp = $AdministratorUserEmail | Add-HPEGLRoleToUser -ComputeOpsManagementRole Administrator
    "`n[Add the Compute Ops Management administrator role to '{0}'] - Status: {1} - Details: {2}" -f $AdministratorUserEmail, $resp.Status, $resp.Details
}

foreach ($ObserverUserEmail in $ObserverUserEmails) {
    $resp = $ObserverUserEmail | Add-HPEGLRoleToUser -ComputeOpsManagementRole Observer
    "`n[Add the Compute Ops Management observer role to '{0}'] - Status: {1} - Details: {2}" -f $ObserverUserEmail, $resp.Status, $resp.Details
}

# Create a new location 
    
$resp = New-HPEGLLocation -Name $LocationName -Country $LocationCountry -City $LocationCity -Street $LocationAddress -State $LocationState -PostalCode $LocationPostalCode -PrimaryContactEmail $MyHPEAccount
"`n[Create location '{0}'] - Status: {1} - Details: {2}" -f $LocationName, $resp.Status, $resp.Details

# Add a Compute Ops Management subscription key

$resp = New-HPEGLSubscription -SubscriptionKey $COMSubscriptionKey
"`n[Add COM subscription] - Status: {0} - Details: {1}" -f $resp.Status, $resp.Details
  
# Set automatic device subscription for Compute Ops Management service manager

$resp = Set-HPEGLDeviceAutoSubscription -ComputeSubscriptionTier ENHANCED
"`n[Set COM automatic device subscription] - Status: {0} - Details: {1}" -f $resp.Status, $resp.Details
  
# Add a Secure Gateway appliance (optional)

$resp = New-HPECOMAppliance -Region us-west -SecureGateway 
"`n[Adding Secure Gateway] - Status: {0} - Details: {1}" -f $resp.Status, $resp.Details
# Returns the activation key to use in the secure gateway console to connect the appliance to Compute Ops Management.

# Generate a Compute Ops Management activation key for connecting servers to the Compute Ops Management service manager in the central european region [with iLO5: v3.09 or later - iLO6: v1.59 or later] 

$ActivationKey = New-HPECOMServerActivationKey -Region $Region # -SecureGateway
"`n[Generate COM activation key] - Key generated: {0}" -f $ActivationKey

# Add and connect compute devices using the Compute Ops Management activation key, this operation includes the following steps:
# 1- Compute devices are added to the HPE GreenLake workspace.
# 2- Compute devices are attached to the Compute Ops Management instance from which the provided activation key was generated.
# 3- Compute devices are assigned to the Compute Ops Management subscription key set by 'New-HPECOMServerActivationKey' or by the auto subscription policy using 'Set-HPEGLDeviceAutoSubscription'.
# 4- iLOs of the compute devices are connected to the Compute Ops Management instance from which the provided activation key was generated.
   
Start-Sleep -Seconds 5

$SerialNumberList = @()
     
ForEach ($iLO in $iLOs) {             
    $iLOSecurePassword = ConvertTo-SecureString $ILO.Password -AsPlainText -Force
    $iLOCredential = New-Object System.Management.Automation.PSCredential ($iLO.Username, $iLOSecurePassword)
    
    $resp = Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLOCredential -IloIP $iLO.IP -ActivationKeyfromCOM $ActivationKey -SkipCertificateValidation  # -IloProxyServer $SecureGateway -IloProxyPort "8080"
        
    "`n[Connect iLO '{0}' to COM] - Status: {1} - Details: {2}" -f $resp.iLO, $resp.iLOConnectionStatus, $resp.iLOConnectionDetails
    $SerialNumberList += $resp.SerialNumber
}

if ($resp.iLOConnectionStatus -ne "Complete") {
    "`n[Connect iLO '{0}' to COM] - Error detected ! Exiting..." -f $resp.iLO
    return
}

# Check devices presence in GLP

Start-Sleep -Seconds 3

foreach ($deviceSerialNumber in $SerialNumberList) {
    
    do {
        $resp = Get-HPEGLdevice -SerialNumber $deviceSerialNumber -ShowComputeReadyForCOMIloConnection
        Start-Sleep -Seconds 1
        
    } until (
        $resp.subscription_key -and $resp.application_instance_id
    )

    "`n[Check if device '{0}' is present in GLP] - Device found! Continuing configuration..." -f $deviceSerialNumber
}


# Add tags to all devices

$devices = Get-HPEGLDevice 

foreach ($device in $devices) {
    $resp = $device | Add-HPEGLDeviceTagToDevice -Tags $Tags 
    "`n[Add tags '{0}' to device '{1}'] - Status: {2} - Details: {3}" -f $Tags, $device.serial_number, $resp.Status, $resp.Details
}


# Assign all devices to the defined location for automated HPE support case creation and services

foreach ($device in $devices) {
    $resp = $device | Set-HPEGLDeviceLocation -LocationName $LocationName 
    "`n[Assign device '{0}' to location '{1}'] - Status: {2} - Details: {3}" -f $device.serial_number, $LocationName, $resp.Status, $resp.Details
}
 
#EndRegion


#Region -------------------------------------------------------- COM instance configuration -----------------------------------------------------------------------------------------


# Check servers presence in COM

foreach ($deviceSerialNumber in $SerialNumberList) {
    
    do {
        $resp = Get-HPECOMServer -Region $Region -Name $deviceSerialNumber
        Start-Sleep -Seconds 1
        
    } until (
        $resp
    )

    "`n[Check if server '{0}' is present in COM] - Server found! Continuing configuration..." -f $deviceSerialNumber
}

# Wait for inventory to be completed

foreach ($deviceSerialNumber in $SerialNumberList) {
    
    do {
        $resp = Get-HPECOMServer -Region $Region -Name $deviceSerialNumber
        $FWVersion = $resp.firmwareInventory | Where-object name -match "iLO" | Select-object -ExpandProperty version
        Start-Sleep -Seconds 1
        
    } until (
        $FWVersion -is [string]
    )

    "`n[Check if server '{0}' basic inventory is complete] - Inventory for server '{0}' is completed! Continuing configuration..." -f $deviceSerialNumber
}

# Create a new server setting for BIOS

$resp = New-HPECOMSettingServerBios -Region $Region -Name $BiosSettingName -WorkloadProfileName $WorkloadProfileName 
"`n[Create a new server setting for BIOS] - Status: {0} - Details: {1}" -f $resp.Status, $resp.Details

# Create a new server setting for INTERNAL STORAGE  
$volume1 = New-HPECOMSettingServerInternalStorageVolume -RAID RAID5 -DriveTechnology NVME_SSD -IOPerformanceMode -ReadCachePolicy OFF -WriteCachePolicy WRITE_THROUGH -SizeinGB 100 -DrivesNumber 3 -SpareDriveNumber 2
$volume2 = New-HPECOMSettingServerInternalStorageVolume -RAID RAID1 -DriveTechnology SAS_HDD
$resp = New-HPECOMSettingServerInternalStorage -Region $Region -Name $InternalStorageSettingName -Description "My server setting for the AI servers" -Volume $volume1,$volume2 

"`n[Create a new server setting for INTERNAL STORAGE with 2 x volumes] - Status: {0} - Details: {1}" -f $resp.Status, $resp.Details

# Create a new server setting for OS 

$resp = New-HPECOMSettingServerOSImage -Region $Region -Name $OSSettingName -OperatingSystem $OSSettingOSType -OSImageURL $OSSettingImageURL
"`n[Create a new server setting for OS] - Status: {0} - Details: {1}" -f $resp.Status, $resp.Details

# Create a new server setting for FIRMWARE 
 
$Gen10_Firmware_Bundle = Get-HPECOMFirmwareBundle -Region $Region -LatestVersion -Generation 10 | Select-Object -ExpandProperty releaseVersion
$Gen11_Firmware_Bundle = Get-HPECOMFirmwareBundle -Region $Region -LatestVersion -Generation 11 | Select-Object -ExpandProperty releaseVersion
$resp = New-HPECOMSettingServerFirmware -Region $Region -Name $FirmwareSettingName -Gen10FirmwareBundleReleaseVersion $Gen10_Firmware_Bundle -Gen11FirmwareBundleReleaseVersion $Gen11_Firmware_Bundle 
"`n[Create a new server setting for FIRMWARE ] - Status: {0} - Details: {1}" -f $resp.Status, $resp.Details

# Create a new group 

$resp = New-HPECOMGroup -Region $Region -Name $GroupName `
    -BiosSettingName $BiosSettingName -AutoBiosApplySettingsOnAdd:$false   `
    -FirmwareSettingName $FirmwareSettingName -AutoFirmwareUpdateOnAdd:$false -PowerOffServerAfterFirmwareUpdate:$false -FirmwareDowngrade:$false `
    -OSSettingName $OSSettingName -AutoOsImageInstallOnAdd:$false -OsCompletionTimeoutMin 60 `
    -StorageSettingName $InternalStorageSettingName -AutoStorageVolumeCreationOnAdd:$false -AutoStorageVolumeDeletionOnAdd:$false  `
    -EnableiLOSettingsForSecurity:$true -AutoIloApplySettingsOnAdd:$false 
"`n[Create group '{0}'] - Status: {1} - Details: {2}" -f $GroupName, $resp.Status, $resp.Details

# Add all servers to new group 

$servers = Get-HPECOMServer -Region $Region 

foreach ($server in $servers) {
    $resp = $server | Add-HPECOMServerToGroup -GroupName $GroupName  
    "`n[Add server '{0}' to group '{1}'] - Status: {2} - Details: {3}" -f $resp.SerialNumber, $GroupName, $resp.Status, $resp.Details
}

# Run a job to collect inventory data on all servers
  
# foreach ($server in $servers) {
#     $resp = $server | New-HPECOMServerInventory -Async
#     "`n[Collect inventory data on server '{0}'] - Status: {1}" -f $server.SerialNumber, $resp.State
# }

# Set iLO auto firmware update for all servers (should be enabled by default)

foreach ($server in $servers) {
    $resp = $server | Enable-HPECOMServerAutoiLOFirmwareUpdate 
    "`n[Set iLO auto firmware update for server '{0}'] - Status: {1} - Details: {2}" -f $server.SerialNumber, $resp.Status, $resp.Details
}

# Power on all servers that are off

# foreach ($server in $servers) {
#     $resp = $server | Start-HPECOMServer -ErrorAction SilentlyContinue
#     "`n[Power on server '{0}'] - Status: {1} - Details: {2}" -f $server.SerialNumber, $resp.Status, $resp.message
# }

# Apply BIOS configuration on all servers in the group 

# $resp = Invoke-HPECOMGroupBiosConfiguration -Region $Region -GroupName $GroupName -Async
# "`n[Apply BIOS configuration on all servers in the group] - Status: {0} - Details: {1}" -f $resp.Status, $resp.Details

# Apply Internal Storage Configuration on all servers in the group 

# $resp = Invoke-HPECOMGroupInternalStorageConfiguration -Region $Region -GroupName $GroupName -Async -AllowStorageVolumeDeletion -StorageVolumeName $OSVolumeName
# "`n[Apply Internal Storage Configuration on all servers in the group] - Status: {0} - Details: {1}" -f $resp.Status, $resp.Details

# Update firmware on all servers in the group 

# $resp = Update-HPECOMGroupFirmware -Region $Region -GroupName $GroupName -Async
# "`n[Update firmware on all servers in the group ] - Status: {0} - Details: {1}" -f $resp.Status, $resp.Details

# Install OS on all servers in the group 

# $resp = Invoke-HPECOMGroupOSInstallation -Region $Region -GroupName $GroupName -ParallelInstallations -StopOnFailure -OSCompletionTimeoutMin 150 -Async
# "`n[Install OS on all servers in the group] - Status: {0} - Details: {1}" -f $resp.Status, $resp.Details

# Generate a sustainability report (CO2 emissions, energy cost, energy consumption) for all servers and schedule the task to repeat every 7 days 

# $resp = New-HPECOMSustainabilityReport -Region $Region -ScheduleTime (get-Date).addminutes(1) -Interval P7D 
# "`n[Generate a sustainability report] - Status: {0} - Details: {1}" -f $resp.Status, $resp.Details

# Enable email notifications for the user account, used with 'Connect-HPEGL', to server notifications (service event issues) and daily summary notifications.

$resp = Enable-HPECOMEmailNotificationPolicy -Region $Region -ServiceEventIssues -DailySummary 
"`n[Enable email notifications] - Status: {0} - Details: {1}" -f $resp.Status, $resp.Details

# Create a ServiceNow integration in the Compute Ops Management instance

$resp = New-HPECOMExternalService -Region $Region -ServiceNow -Name $ServiceNowName -Credential $ServiceNowCredential -RefreshToken $ServiceNowRefreshToken -OauthUrl $ServiceNowOauthUrl -IncidentUrl $ServiceNowIncidentUrl -refreshTokenExpiryInDays $ServiceNowRefreshTokenExpiryInDays -Description "This is my ServiceNow integration"
"`n[Create a ServiceNow integration] - Status: {0} - Details: {1}" -f $resp.Status, $resp.Details

# Create a Data Services Cloud Console integration in the Compute Ops Management instance

# $resp = New-HPECOMExternalService -Region eu-central -DSCC -Name $DSCCName -Description "This is my DSCC service integration" -DSCCRegion $DSCCRegion -Credential $DSCCcredentials 
# "`n[Create a Data Services Cloud Console integration] - Status: {0} - Details: {1}" -f $resp.Status, $resp.Details

# Disable iLO Ignore Security Settings for Default SSL Certificate In Use 

foreach ($server in $servers) {
    # Required to wait until the iLO security settings are discovered
    do {
        $OverallSecurityStatus = Get-HPECOMServer -Region $Region -ShowSecurityParameters | Select-Object -ExpandProperty overallSecurityStatus
        Start-Sleep -Seconds 1
    } while (
        $OverallSecurityStatus -eq "Not available"
    )

    $resp = $server | Disable-HPECOMIloIgnoreRiskSetting -DefaultSSLCertificateInUse 
    "`n[Disable iLO Ignore Security Settings for Default SSL Certificate In Use in server '{0}'] - Status: {1} - Details: {2}" -f $server.SerialNumber, $resp.Status, $resp.resultCode
}

#EndRegion


#Region -------------------------------------------------------- Disconnection from HPE GreenLake -----------------------------------------------------------------------------------

# Disconnect from HPE GreenLake and clean up the session, temporary library API credentials, and environment variables
$resp = Disconnect-HPEGL
"`n[Disconnected '{0}' from '{1}' workspace]" -f $MyHPEAccount, $WorkspaceName

#EndRegion

