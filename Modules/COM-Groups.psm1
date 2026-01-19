#------------------- FUNCTIONS FOR COMPUTE OPS MANAGEMENT GROUPS -----------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1

# Public functions
Function Get-HPECOMGroup {
    <#
    .SYNOPSIS
    Retrieve the list of groups.

    .DESCRIPTION
    This Cmdlet returns a collection of groups that are available in the specified region.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name
    Optional parameter that can be used to specify the name of a group to display.

    .PARAMETER ShowCompliance
    Optional switch parameter that can be used to get comprehensive compliance details for all compliance types (firmware, iLO settings, and external storage) of a group using the UI-Doorway endpoint.

    .PARAMETER ShowFirmwareCompliance
    Optional switch parameter that can be used to get firmware compliance details of servers in a group.
    
    Returns the following properties for each server:
    - Server: Server name
    - SerialNumber: Server serial number
    - Group: Group name the server belongs to
    - State: Compliance state (Compliant, Not Compliant, Unknown, etc.)
    - Score: Compliance score percentage (e.g., 25% indicates 25% compliant)
    - ErrorReason: Reason for compliance failure if applicable
    - Criticality: Severity level of the firmware update (Recommended, Critical, Optional)
    - Deviations: Number of firmware components that deviate from the group's baseline
    - WillItRebootTheServer: Indicates if applying the update will reboot the server (Yes/No)
    - GracefullShutdownAttempt: Indicates if a graceful shutdown will be attempted before reboot (Yes/No)
    - TotalDownloadSize: Total size of firmware updates to download (e.g., 40 MB)

    .PARAMETER ShowiLOSettingsCompliance
    Optional switch parameter that can be used to get iLO settings compliance details of servers in a group.

    .PARAMETER ShowExternalStorageCompliance
    Optional switch parameter that can be used to get external storage compliance details of servers in a group.

    .PARAMETER ShowMembers
    Optional parameter that can be used to obtain a list of servers that are members of the designated group. 

    .PARAMETER ShowPolicies
    Optional parameter that can be used to obtain a list of policies that are assigned to the designated group.
    
    .PARAMETER ShowSettings
    Optional parameter that can be used to obtain a list of server settings that are assigned to the designated group. 

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMGroup -Region us-west

    Return all groups resources located in the western US region. 

    .EXAMPLE
    Get-HPECOMGroup -Region us-west -Name DLV24-ESX8-Mgmt-Cluster

    Return the group resource named 'DLV24-ESX8-Mgmt-Cluster' located in the western US region. 

    .EXAMPLE
    Get-HPECOMGroup -Region us-west -Name DLV24-ESX8-Mgmt-Cluster -ShowCompliance

    Return comprehensive compliance details (firmware, iLO settings, and external storage) for the group resource named 'DLV24-ESX8-Mgmt-Cluster'.

    .EXAMPLE
    Get-HPECOMGroup -Region us-west -Name DLV24-ESX8-Mgmt-Cluster -ShowFirmwareCompliance

    Return firmware compliance details for servers in the group 'DLV24-ESX8-Mgmt-Cluster'.

    .EXAMPLE
    Get-HPECOMGroup -Region us-west -Name DLV24-ESX8-Mgmt-Cluster -ShowiLOSettingsCompliance

    Return iLO settings compliance details for servers in the group 'DLV24-ESX8-Mgmt-Cluster'.

    .EXAMPLE
    Get-HPECOMGroup -Region us-west -Name DLV24-ESX8-Mgmt-Cluster -ShowExternalStorageCompliance

    Return external storage compliance details for servers in the group 'DLV24-ESX8-Mgmt-Cluster'. 

    .EXAMPLE
    Get-HPECOMGroup -Region us-west -Name Hypervisors -ShowMembers

    Return the list of servers that are members of the group 'Hypervisors'.

    .EXAMPLE
    Get-HPECOMGroup -Region us-west -Name Hypervisors -ShowSettings

    Return the list of server settings that are assigned to the group 'Hypervisors'.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -Name ESXi_group -ShowPolicies

    Return the list of policies that are assigned to the group 'ESXi_group'.
    
    .INPUTS
    No pipeline support   
    
   #>
    [CmdletBinding(DefaultParameterSetName = 'Name')]
    Param( 
    
        [Parameter (Mandatory)] 
        [ValidateScript({
                # First check if there's an active session with COM regions
                if (-not $Global:HPEGreenLakeSession -or -not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use HPE GreenLake cmdlets."
                }
                # Then validate the region
                if (($_ -in $Global:HPECOMRegions.region)) {
                    $true
                }
                else {
                    Throw "The COM region '$_' is not provisioned in this workspace! Please specify a valid region code (e.g., 'us-west', 'eu-central'). `nYou can retrieve the region code using: Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned. `nYou can also use the Tab key for auto-completion to see the list of provisioned region codes."
                }
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                # Filter region based on $Global:HPECOMRegions global variable and create completions
                $Global:HPECOMRegions.region | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [String]$Region,  

        [Parameter (ParameterSetName = 'Name')]
        [Parameter (Mandatory, ParameterSetName = 'ShowMembers')]
        [Parameter (Mandatory, ParameterSetName = 'Compliance')]
        [Parameter (Mandatory, ParameterSetName = 'FirmwareCompliance')]
        [Parameter (Mandatory, ParameterSetName = 'iLOSettingsCompliance')]
        [Parameter (Mandatory, ParameterSetName = 'ExternalStorageCompliance')]
        [Parameter (Mandatory, ParameterSetName = 'ShowSettings')]
        [Parameter (Mandatory, ParameterSetName = 'ShowPolicies')]
        [String]$Name,

        [Parameter (ParameterSetName = 'Compliance')]
        [Switch]$ShowCompliance,

        [Parameter (ParameterSetName = 'FirmwareCompliance')]
        [Switch]$ShowFirmwareCompliance,

        [Parameter (ParameterSetName = 'iLOSettingsCompliance')]
        [Switch]$ShowiLOSettingsCompliance,

        [Parameter (ParameterSetName = 'ExternalStorageCompliance')]
        [Switch]$ShowExternalStorageCompliance,

        [Parameter (ParameterSetName = 'ShowMembers')]
        [Switch]$ShowMembers,
        
        [Parameter (ParameterSetName = 'ShowPolicies')]
        [Switch]$ShowPolicies,
                
        [Parameter (ParameterSetName = 'ShowSettings')]
        [Switch]$ShowSettings,

        [Switch]$WhatIf
       
    ) 


    Begin {
  
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
      
      
    }
      
      
    Process {
      
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
      
        if ($Filterableproperties) {
            $Uri = (Get-COMGroupsUri) + "/properties"
            
        }
        elseif ($ShowMembers -or $ShowCompliance -or $ShowFirmwareCompliance -or $ShowiLOSettingsCompliance -or $ShowExternalStorageCompliance) {

            $Uri = (Get-COMGroupsUri) + "?filter=name eq '$name'"

            try {
                $GroupID = (Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region).id

                "[{0}] ID found for group '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $GroupID | Write-Verbose

                if ($Null -eq $GroupID) { 
                    # Write-warning "Group '$name' cannot be found in the Compute Ops Management instance!" 
                    return
                }

                if ($ShowCompliance) {
                    $Uri = (Get-COMGroupsUIDoorwayUri) + "/" + $GroupID
                }

                if ($ShowFirmwareCompliance) {
                    $Uri = (Get-COMGroupsUri) + "/" + $GroupID + "/compliance"
                }

                if ($ShowiLOSettingsCompliance) {
                    $Uri = (Get-COMGroupsUIDoorwayUri) + "/" + $GroupID
                }

                if ($ShowExternalStorageCompliance) {
                    $Uri = (Get-COMGroupsUri) + "/" + $GroupID + "/external-storage-compliance"
                }

                if ($ShowMembers) {
                    $Uri = (Get-COMGroupsUri) + "/" + $GroupID + "/devices"
                }
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
           
            }
        }
        elseif ($Name) {

            $Uri = (Get-COMGroupsUri) + "?filter=name eq '$name'" 
        }
        else {
            $Uri = Get-COMGroupsUri
            
        }

        try {
            [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
    
        }
        catch {
            # For ShowExternalStorageCompliance, 404 means no external storage data available
            if ($ShowExternalStorageCompliance -and $_.Exception.Message -match '404') {
                "[{0}] No external storage compliance data available for group '{1}' (404 - may indicate no external storage configured)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                return
            }
            $PSCmdlet.ThrowTerminatingError($_)
                   
        }           
        

        $ReturnData = @()
      
        if ($Null -ne $CollectionList) {   
            
            # Add region to object
            $CollectionList | Add-Member -type NoteProperty -name region -value $Region
                       
            if ($ShowCompliance) {
                
                # Extract only compliance-relevant fields from UI-Doorway comprehensive response
                # Convert PSCustomObjects to formatted strings for display
                $firmwareDevices = if ($CollectionList.'deviceCounts_'.'firmwareCompliance' -and $CollectionList.'deviceCounts_'.'firmwareCompliance'.PSObject.Properties.Count -gt 0) {
                    ($CollectionList.'deviceCounts_'.'firmwareCompliance'.PSObject.Properties | ForEach-Object { "$($_.Name):$($_.Value)" }) -join ', '
                } else { 'None' }
                
                $iloDevices = if ($CollectionList.'deviceCounts_'.'iloSettingCompliance' -and $CollectionList.'deviceCounts_'.'iloSettingCompliance'.PSObject.Properties.Count -gt 0) {
                    ($CollectionList.'deviceCounts_'.'iloSettingCompliance'.PSObject.Properties | ForEach-Object { "$($_.Name):$($_.Value)" }) -join ', '
                } else { 'None' }
                
                $externalStorageDevices = if ($CollectionList.'deviceCounts_'.'externalStorageCompliance' -and $CollectionList.'deviceCounts_'.'externalStorageCompliance'.PSObject.Properties.Count -gt 0) {
                    ($CollectionList.'deviceCounts_'.'externalStorageCompliance'.PSObject.Properties | ForEach-Object { "$($_.Name):$($_.Value)" }) -join ', '
                } else { 'None' }
                
                $ComplianceData = [PSCustomObject]@{
                    groupName = $Name
                    groupComplianceStatus = $CollectionList.groupComplianceStatus
                    firmwareComplianceStatus = $CollectionList.firmwareComplianceStatus_
                    groupIloSettingsComplianceStatus = $CollectionList.groupIloSettingsComplianceStatus
                    groupExternalStorageComplianceStatus = $CollectionList.groupExternalStorageComplianceStatus
                    groupSummaryComplianceStatus = $CollectionList.groupSummaryComplianceStatus
                    firmwareDevices = $firmwareDevices
                    iloDevices = $iloDevices
                    externalStorageDevices = $externalStorageDevices
                    groupComplianceUpdatedAt = $CollectionList.groupComplianceUpdatedAt
                    groupIloSettingsComplianceUpdatedAt = $CollectionList.groupIloSettingsComplianceUpdatedAt
                    groupExternalStorageComplianceUpdatedAt = $CollectionList.groupExternalStorageComplianceUpdatedAt
                    groupSummaryComplianceUpdatedAt = $CollectionList.groupSummaryComplianceUpdatedAt
                    complianceCheckedAt = $CollectionList.complianceCheckedAt_
                    region = $Region
                }
                
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $ComplianceData -ObjectName "COM.Groups.All.Compliance"    

            }
            elseif ($ShowFirmwareCompliance) {
                
                # Add groupName, servername and serialNumber (only serial is provided)
                # groupName is used in Invoke-HPECOMGroupInternalStorageConfiguration, Update-HPECOMGroupFirmware, etc. 
                Foreach ($Item in $CollectionList) {

                    try {
                        $ServerName = Get-HPECOMServer -Region $Region -Name $Item.serial                        
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }

                    $Item | Add-Member -type NoteProperty -name groupName -value $Name
                    $Item | Add-Member -type NoteProperty -name serialNumber -value $Item.serial
                    $item | Add-Member -Type NoteProperty -Name serverName -Value $ServerName.name
                    
                }

                $CollectionList = $CollectionList | Sort-Object serverName
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Groups.Firmware.Compliance"    

            }
            elseif ($ShowiLOSettingsCompliance) {
                
                # Extract iLO settings compliance from UI-Doorway data and format device counts
                $iloDevices = if ($CollectionList.'deviceCounts_'.'iloSettingCompliance' -and $CollectionList.'deviceCounts_'.'iloSettingCompliance'.PSObject.Properties.Count -gt 0) {
                    ($CollectionList.'deviceCounts_'.'iloSettingCompliance'.PSObject.Properties | ForEach-Object { "$($_.Name):$($_.Value)" }) -join ', '
                } else { 'None' }
                
                $iLOComplianceData = [PSCustomObject]@{
                    groupName = $Name
                    groupIloSettingsComplianceStatus = $CollectionList.groupIloSettingsComplianceStatus
                    deviceCounts = $iloDevices
                }
                
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $iLOComplianceData -ObjectName "COM.Groups.iLO.Settings.Compliance"    

            }
            elseif ($ShowExternalStorageCompliance) {
                
                # Add groupName, servername and serialNumber (only serial is provided)
                # groupName is used for consistency with other compliance commands
                Foreach ($Item in $CollectionList) {

                    try {
                        $ServerName = Get-HPECOMServer -Region $Region -Name $Item.serial                        
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }

                    $Item | Add-Member -type NoteProperty -name groupName -value $Name
                    $Item | Add-Member -type NoteProperty -name serialNumber -value $Item.serial
                    $item | Add-Member -Type NoteProperty -Name serverName -Value $ServerName.name
                    
                }

                $CollectionList = $CollectionList | Sort-Object serverName
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Groups.External.Storage.Compliance"    

            }
            elseif ($ShowMembers) {

                # Add groupName, servername and serialNumber (only serial is provided)
                # groupName is used in Invoke-HPECOMGroupInternalStorageConfiguration, Update-HPECOMGroupFirmware, etc. 
                Foreach ($Item in $CollectionList) {

                    try {
                        $ServerName = Get-HPECOMServer -Region $Region -Name $Item.serial                        
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }

                    $Item | Add-Member -type NoteProperty -name groupName -value $Name
                    $Item | Add-Member -type NoteProperty -name serialNumber -value $Item.serial
                    $item | Add-Member -Type NoteProperty -Name serverName -Value $ServerName.name
                    
                }

                $CollectionList = $CollectionList | Sort-Object serverName
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Groups.Members"    

            }
            elseif ($ShowSettings) {

                $_CollectionList = [System.Collections.ArrayList]::new()

                $_Settings = Get-HPECOMSetting -Region $Region 

                foreach ($SettingUri in $CollectionList.settingsUris) {

                    $SettingId = $SettingUri.split('/')[-1]

                    "[{0}] Setting uri found for group '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $SettingId | Write-Verbose

                    $_serversetting = $_Settings | Where-Object id -eq $SettingId
                    
                    if ($_serversetting){
                        "[{0}] Setting found: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_serversetting.name | Write-Verbose
                        [void]$_CollectionList.add($_serversetting)
                    }
                }

                # Add groupName to object (used in Invoke-HPECOMGroupInternalStorageConfiguration, Update-HPECOMGroupFirmware, etc. )
                $_CollectionList | Add-Member -type NoteProperty -name groupName -value $Name

                $_CollectionList = $_CollectionList | Sort-Object name
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $_CollectionList -ObjectName "COM.Settings"    

            }
            elseif ($ShowPolicies) {

                $ListOfGroupSettingCategories = [System.Collections.ArrayList]::new()

                $_Settings = Get-HPECOMSetting -Region $Region 

                foreach ($SettingUri in $CollectionList.settingsUris) {

                    $SettingId = $SettingUri.split('/')[-1]

                    "[{0}] Setting uri found for group '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $SettingId | Write-Verbose

                    $_serversetting = $_Settings | Where-Object id -eq $SettingId

                    "[{0}] Setting found: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_serversetting.name | Write-Verbose

                    if($_serversetting){
                        "[{0}] Setting found: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_serversetting.name | Write-Verbose
                        $SettingCategoryFound = $_serversetting.category
                        [void]$ListOfGroupSettingCategories.add($SettingCategoryFound)
                    }
                                           
                    "[{0}] List of category settings found: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ListOfGroupSettingCategories | out-string) | Write-Verbose

                }

                # Removing the firmwareDowngrade property (deprecated) as it is now in OnDeviceApply policy
                $ReturnData = $CollectionList.policies
  
                $PoliciesList = [System.Collections.ArrayList]::new()

                # BIOS
                if ($ListOfGroupSettingCategories -like 'BIOS') {      

                    foreach ($item in $ReturnData.onDeviceAdd.psobject.properties) {    
                        if ($item.name -eq "biosApplySettings") {

                            $Policy = [PSCustomObject]@{
                                Policy   = "Auto apply BIOS setting when server is added to the group"
                                Setting  = $item.value
                                Category = "BIOS"
                            }

                            [void]$PoliciesList.add($Policy)
                        }
                        if ($item.name -eq "biosFactoryReset") {

                            $Policy = [PSCustomObject]@{
                                Policy   = "Reset BIOS configuration settings to defaults"
                                Setting  = $item.value
                                Category = "BIOS"
                            }
                        
                            [void]$PoliciesList.add($Policy)
                        }
                    }
                }
                # EXTERNAL_STORAGE
                if ($ListOfGroupSettingCategories -like 'EXTERNAL_STORAGE') {
                    
                    foreach ($item in $ReturnData.onDeviceAdd.psobject.properties) {

                        if ($item.name -eq "externalStorageConfiguration") {

                            $Policy = [PSCustomObject]@{
                                Policy   = "Auto apply external storage setting when server is added to the group"
                                Setting  = $item.value
                                Category = "EXTERNAL_STORAGE"
                            }

                            [void]$PoliciesList.add($Policy)
                        }
                    }
                }
                # FIRMWARE
                if ($ListOfGroupSettingCategories -like 'FIRMWARE') {

                    foreach ($item in $ReturnData.onDeviceAdd.psobject.properties) {
                        if ($item.name -eq "firmwareUpdate") {

                            $Policy = [PSCustomObject]@{
                                Policy   = "Auto apply firmware baseline when server is added to the group"
                                Setting  = $item.value
                                Category = "FIRMWARE"
                            }

                            [void]$PoliciesList.add($Policy)
                        }
                        if ($item.name -eq "firmwarePowerOff") {

                            $Policy = [PSCustomObject]@{
                                Policy   = "Power off server after firmware update"
                                Setting  = $item.value
                                Category = "FIRMWARE"
                            }

                            [void]$PoliciesList.add($Policy)
                        }
                    }
                    foreach ($item in $ReturnData.onDeviceApply.psobject.properties) {

                        if ($item.name -eq "firmwareDowngrade") {

                            $Policy = [PSCustomObject]@{
                                Policy   = "Downgrade components to match baseline"
                                Setting  = $item.value
                                Category = "FIRMWARE"
                            }

                            [void]$PoliciesList.add($Policy)
                        }
                    }
                }
                # ILO
                if ($ListOfGroupSettingCategories -like 'ILO_SETTINGS') {

                    foreach ($item in $ReturnData.onDeviceAdd.psobject.properties) {

                        if ($item.name -eq "iloApplySettings") {

                            $Policy = [PSCustomObject]@{
                                Policy   = "Auto apply iLO settings when server is added to the group"
                                Setting  = $item.value
                                Category = "ILO_SETTINGS"
                            }

                            [void]$PoliciesList.add($Policy)
                        }
                    }
                }
                # OS
                if ($ListOfGroupSettingCategories -like 'OS') {

                    foreach ($item in $ReturnData.onDeviceAdd.psobject.properties) {
                        
                        if ($item.name -like "osInstall") {
                      
                            $Policy = [PSCustomObject]@{
                                Policy   = "Auto install operating system when a server is added to the group"
                                Setting  = $item.value
                                Category = "OS"
                            }

                            [void]$PoliciesList.add($Policy)
                        }
                        if ($item.name -like "osCompletionTimeoutMin") {

                            $Policy = [PSCustomObject]@{
                                Policy   = "OS install completion timeout"
                                Setting  = $item.value
                                Category = "OS"
                            }

                            [void]$PoliciesList.add($Policy)
                        }
                    }
                }
                
                if ($ListOfGroupSettingCategories -like 'STORAGE') {

                    foreach ($item in $ReturnData.onDeviceAdd.psobject.properties) {
                        if ($item.name -like "storageConfiguration") {

                            $Policy = [PSCustomObject]@{
                                Policy   = "Auto apply storage setting when server is added to the group"
                                Setting  = $item.value
                                Category = "STORAGE"
                            }

                            [void]$PoliciesList.add($Policy)
                        }
                        if ($item.name -like "storageVolumeDeletion") {

                            $Policy = [PSCustomObject]@{
                                Policy   = "Erase existing internal storage configuration when server is added to the group"
                                Setting  = $item.value
                                Category = "STORAGE"
                            }

                            [void]$PoliciesList.add($Policy)
                        }
                        if ($item.name -like "storageVolumeName") {

                            $Policy = [PSCustomObject]@{
                                Policy   = "Volume label name when server is added to the group"
                                Setting  = $item.value
                                Category = "STORAGE"
                            }

                            [void]$PoliciesList.add($Policy)
                        }
                    }
                }
               
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $PoliciesList -ObjectName "COM.Groups.Policies"    
                $ReturnData = $ReturnData | Sort-Object Category, policy
               
            }
            else {

                # Add groupName to object (used in Invoke-HPECOMGroupInternalStorageConfiguration, Update-HPECOMGroupFirmware, etc. )
                foreach ($item in $CollectionList) {
                    $item | Add-Member -MemberType NoteProperty -Name groupName -Value $item.name
                }

                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Groups"    
                $ReturnData = $ReturnData | Sort-Object name
            }
        
            return $ReturnData 
                
        }
        else {

            return
                
        }     

    
    }
}

Function New-HPECOMGroup {
    <#
    .SYNOPSIS
    Create a new group resource in a region.

    .DESCRIPTION
    This Cmdlet can be used to create a new group with specific settings and policies.
    Alternatively, it can create a new group using the settings and group policies of an existing group.
    Settings includes server settings such as BIOS, firmware, OS, storage, and iLO settings.
    Policies include automatic application of settings when a server is added to the group, firmware update policies, OS installation policies, and storage configuration policies.

    .PARAMETER Name
    Name of the group to create.
    This mandatory parameter must be unique within the Compute Ops Management instance in the specified region.
        
    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where to create the group. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Description 
    Optional parameter to describe the group. 

    .PARAMETER DeviceType
    Specifies the type of device to be added to the group. Servers is the only supported device type at the moment.

    .PARAMETER SettingsObject
    Specifies the server settings to assign to the group. The settings object must be retrieved from 'Get-HPECOMSetting -Region $Region'.

    .PARAMETER BiosSettingName
    Name of a bios server settings resource to assign to the group from 'Get-HPECOMSetting -Region $Region -Category Bios'.

    .PARAMETER ExternalStorageSettingName
    Name of an external storage server settings resource to assign to the group from 'Get-HPECOMSetting -Region $Region -Category ExternalStorage'.

    .PARAMETER FirmwareSettingName
    Name of a firmware server settings resource to assign to the group from 'Get-HPECOMSetting -Region $Region -Category Firmware'.

    .PARAMETER iLOSettingName
    Name of an iLO settings server settings resource to assign to the group from 'Get-HPECOMSetting -Region $Region -Category ILO_SETTINGS'. 
    To assign the HPE-recommended security settings for iLOs, use the pre-defined setting named 'iLO settings enabled for security'.

    .PARAMETER OSSettingName
    Name of an OS server settings resource to assign to the group from 'Get-HPECOMSetting -Region $Region -Category Os'.

    .PARAMETER StorageSettingName
    Name of a storage server settings resource to assign to the group from 'Get-HPECOMSetting -Region $Region -Category Storage'.
        
    .PARAMETER AutoBiosApplySettingsOnAdd
    Enable automatic application of BIOS settings when a server is added to a group. 
    A server group must have one of the HPE pre-defined BIOS/Workload profiles to allow the auto apply of BIOS settings.
    Note: This parameter is effective only when a bios server setting is defined in the group.

    .PARAMETER ResetBIOSConfigurationSettingsToDefaultsonAdd
    Reset BIOS configuration settings to defaults when a server is added to a group.
    Note: This parameter is effective only when a bios server setting is defined in the group.

    .PARAMETER AutoFirmwareUpdateOnAdd
    Enable automatic firmware updates to the configured baseline when a server is added to a group. 
    Note: This parameter is effective only when a firmware server setting is defined in the group.
    
    .PARAMETER PowerOffServerAfterFirmwareUpdate
    Power off server after firmware update is performed.
    Note: This parameter is effective only when a firmware server setting is defined in the group.

    .PARAMETER FirmwareDowngrade
    Allow or forbid downgrade of a firmware when firmware update is performed.
    Note: This parameter is effective only when a firmware server setting is defined in the group.

    .PARAMETER AutoOsImageInstallOnAdd
    When a server is added to the group, install the operating system image immediately if the server is activated or when the server is activated at a later time.
    Note: This parameter is effective only when an OS server setting is defined in the group.
    
    .PARAMETER OsCompletionTimeoutMin
    When a server is added to the group and automatic install of operating system is enabled, this property sets the amount of time (in minutes) the operating system 
    installation will be allowed to continue before it times out. The timeout specified is applicable for each individual server in the group.
    Note: This parameter is effective only when an OS server setting is defined in the group.
    
    .PARAMETER AutoStorageVolumeCreationOnAdd
    When server is added to the group, the OS volume will be created immediately if the server is activated or when the server is activated at a later time.
    Note: This parameter is effective only when an OS server setting is defined in the group.
    
    .PARAMETER AutoStorageVolumeDeletionOnAdd
    When server is added to the group, any existing internal storage configuration will be erased prior to creating the new OS volume if the server 
    is activated or when the server is activated at a later time.
    Note: This parameter is effective only when a storage server setting is defined in the group.
        
    .PARAMETER AutoIloApplySettingsOnAdd
    Enable automatic application of iLO settings when a server is added to a group. A server group must have HPE pre-defined 
    iLO settngs to allow the auto apply of iLO settings.
    Note: This parameter is effective only when an iLO settings server setting is defined in the group.

    .PARAMETER AutoExternalStorageConfigurationOnAdd
    When a server is added to the group, apply the external storage configuration immediately if the server is activated or when the server is activated at a later time.
    Note: This parameter is effective only when an external storage server setting is defined in the group.

    .PARAMETER TagUsedForAutoAddServer    
    Associates a case-insensitive tag with a group to automatically add servers to the group when they are activated. 
    
    The tag must meet the following string format <Name>=<Value> and can contain any alphaneumeric characters, any Unicode space separators, and the following characters: _ . : + - @ such as:
     - "Country=US"
     - "App=ESX-8"
     - "Site=Houston site"
     - "Domain=my.lab@domain.com"
    
    Note: 
        - A group can have a maximum of one tag and multiple groups can not have the same tag.
        - Automatic addition to groups can only occur before server activation. If a server’s tags match more than one group, it won’t be added to any group, and will need to be added using a different method.
        - When a server is onboarded or has its tags changed, the server's tags will be checked against the group's autoAddServerTags. 
        - If at least one of the server tags matches one group's autoAddServerTags, the server will be placed into the associated group. 
        - Once a server has been connected, the server becomes ineligible for automatically being placed into groups, even if it is later disconnected.
        - If a server is in a group, any further tag changes will not move it to another group. 
    
    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    $BiosSettingName = "AI_BIOS_Profile"
    $FirmwareSettingName = "AI_Firmware_Baseline"
    $InternalStorageSettingName = "AI_Internal_Storage"
    $iLOSettingName = "AI_iLO_Settings"
    $GroupName = "AI_Servers_Group"
    $Region = "us-west"

    New-HPECOMGroup -Region $Region -Name $GroupName -Description "My new group for AI servers" `
    -BiosSettingName $BiosSettingName -AutoBiosApplySettingsOnAdd:$false `
    -iLOSettingName $iLOSettingName -AutoIloApplySettingsOnAdd:$true `
    -FirmwareSettingName $FirmwareSettingName -AutoFirmwareUpdateOnAdd:$false -PowerOffServerAfterFirmwareUpdate:$false -FirmwareDowngrade:$false `
    -StorageSettingName $InternalStorageSettingName -AutoStorageVolumeCreationOnAdd:$false -AutoStorageVolumeDeletionOnAdd:$false `
    -TagUsedForAutoAddServer "App=AI" 

    Create a new server group named "AI_Servers_Group" in the specified region and provides a description for the group.
    The command specifies settings for BIOS, iLO, firmware, and storage configurations using the provided variables.
    It includes options to automatically apply iLO settings when a server is added to the group.
    Additionally, it uses a specific tag for auto-adding servers to the group.
            
    .EXAMPLE
    $Settings = Get-HPECOMSetting -Region us-west | Where-Object {$_.name -eq "Firmware_Baseline" -or $_.name -eq "Virtualization - Power Efficient"}
    
    New-HPECOMGroup -Region us-west -Name Hypervisors_Group `
    -Description "My group for hypervisors" -SettingsObject $Settings `
    -AutoFirmwareUpdateOnAdd -AutoBiosApplySettingsOnAdd `
    -PowerOffServerAfterFirmwareUpdate -FirmwareDowngrade `
    -TagUsedForAutoAddServer "App=ESXi"

    Create a new group named 'Hypervisors_Group' in the central western US region using a list of bios and firmware settings URIs.  
    Set the group with automatic firmware update and Bios apply settings when a server is added to the group.
    Set also the group to power off server after firmware update is performed and allow firmware downgrade. 
    Set the "App=ESXi" tag so that any server defined with this tag during onboarding will automatically be added to this group.    

    .EXAMPLE
    $Settings = Get-HPECOMSetting -Region eu-central | Where-Object { $_.name -eq "ESXi_firmware_baseline_24_04_Gen10" -or $_.name -eq "Virtualization - Power Efficient" -or $_.name -eq "iLO settings enabled for security" }
    $Settings | New-HPECOMGroup -Region eu-central -Name Hypervisors_Group -Description "My group for hypervisors" `
     -AutoFirmwareUpdateOnAdd -AutoBiosApplySettingsOnAdd -PowerOffServerAfterFirmwareUpdate -FirmwareDowngrade -TagUsedForAutoAddServer "Domain=lab@lab.net" 

    Create a new group named 'Hypervisors_Group' in the central European region using a list of bios, firmware, and iLO settings URIs.
    Set the group with automatic firmware update and Bios apply settings when a server is added to the group.
    Set also the group to power off server after firmware update is performed and allow firmware downgrade.
    Set the "Domain=lab@lab.net" tag so that any server defined with this tag during onboarding will automatically be added to this group.    
    
    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -Name "RHEL_group" | New-HPECOMGroup -Name K8s_group 

    This command creates a new group named 'K8s_group' in the central European region using the settings and group policies of the existing 'RHEL_group', except for the autoAddServerTag, as an autoAddServerTag can only be associated with one group at a time.

    .INPUTS
    System.Collections.ArrayList
        List of server settings from 'Get-HPECOMSetting'.
        or
        A single group obtained from 'Get-HPECOMGroup -Name <GroupName>' if you want to copy an existing group to a new one.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - Name of the group attempted to be created
        * Region - Name of the region
        * Status - Status of the creation attempt (Failed for http error return; Complete if creation is successful; Warning if no action is needed) 
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.

   #>

    [CmdletBinding()]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
        [ValidateScript({
                # First check if there's an active session with COM regions
                if (-not $Global:HPEGreenLakeSession -or -not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use HPE GreenLake cmdlets."
                }
                # Then validate the region
                if (($_ -in $Global:HPECOMRegions.region)) {
                    $true
                }
                else {
                    Throw "The COM region '$_' is not provisioned in this workspace! Please specify a valid region code (e.g., 'us-west', 'eu-central'). `nYou can retrieve the region code using: Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned. `nYou can also use the Tab key for auto-completion to see the list of provisioned region codes."
                }
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                # Filter region based on $Global:HPECOMRegions global variable and create completions
                $Global:HPECOMRegions.region | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [String]$Region,  

        [Parameter (Mandatory)]
        [ValidateScript({ $_.Length -le 100 })]
        [String]$Name,
        
        # [Parameter (ValueFromPipelineByPropertyName)] # Removed to avoid taking it from Get-HPECOMSetting pipeline object
        [ValidateScript({ $_.Length -le 1000 })]
        [String]$Description,

        [Parameter (ValueFromPipelineByPropertyName)] 
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Servers') #, 'OneView Synergy appliances', 'OneView VM appliances')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        # [ValidateSet ('Servers')] # , 'OneView Synergy appliances', 'OneView VM appliances')]
        [String]$DeviceType = "Servers",

        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "SettingsObject")] 
        [Alias("settingsUris", "resourceuri")]
        [object]$SettingsObject,

        [Parameter (ValueFromPipelineByPropertyName, ParameterSetName = "SettingsObject")] 
        [Alias("policies")]
        [object]$PoliciesObject,

        [Parameter (ParameterSetName = "Settings")] 
        [String]$BiosSettingName,        
       
        [Parameter (ParameterSetName = "Settings")] 
        [String]$ExternalStorageSettingName,

        [Parameter (ParameterSetName = "Settings")] 
        [string]$FirmwareSettingName,

        [Parameter (ParameterSetName = "Settings")] 
        [string]$iLOSettingName,
                
        [Parameter (ParameterSetName = "Settings")] 
        [String]$OSSettingName,
        
        [Parameter (ParameterSetName = "Settings")] 
        [String]$StorageSettingName,
        
        # BIOS settings
        [switch]$AutoBiosApplySettingsOnAdd,
        [switch]$ResetBIOSConfigurationSettingsToDefaultsonAdd,  

        # Firmware settings
        [switch]$AutoFirmwareUpdateOnAdd,
        [switch]$PowerOffServerAfterFirmwareUpdate,
        [switch]$FirmwareDowngrade,

        # OS settings
        [switch]$AutoOSImageInstallOnAdd,
        [ValidateScript({ $_ -ge 60 -and $_ -le 720 })]
        [Int]$OsCompletionTimeoutMin = 240,

        # Storage settings
        [switch]$AutoStorageVolumeCreationOnAdd,
        [switch]$AutoStorageVolumeDeletionOnAdd,

        # iLO settings
        [switch]$AutoIloApplySettingsOnAdd,

        # External storage settings       
        [switch]$AutoExternalStorageConfigurationOnAdd,

        # Tags settings
        # [Parameter (ValueFromPipelineByPropertyName)] # Removed as an autoAddServerTag can only exist in one group
        [ValidateScript({
                # Allows empty strings to pass the validation when a group without tag is provided in the pipeline
                # if (($_.psobject.properties | Where-Object { $_.MemberType -eq 'NoteProperty' }).count -eq 0) {
                #     $True
                # }   
                # Checks if the input string matches a specific pattern that starts with '@{' and ends with '}', 
                # containing letters, digits, underscores, spaces, dots, colons, plus signs, hyphens, and at signs.
                if ($_ -match '^@\{[\p{L}\p{Nd}_ .:+\-@]+\=[\p{L}\p{Nd}_ .:+\-@]+\}$') {
                    $True
                }
                elseif (($_ -split '=').Count -gt 2) {
                    throw "Input '$_' is not in a valid tag format. Only one tag is expected such as <Name>=<Value>"
                }
                elseif ($_ -match '^[\p{L}\p{Nd}_ .:+\-@]+\=[\p{L}\p{Nd}_ .:+\-@]+$') { 
                    $True
                }
                elseif ($_ -notmatch '^[\p{L}\p{Nd}_ .:+\-@]+\=[\p{L}\p{Nd}_ .:+\-@]+$') {
                    throw "Input '$_' is not in a valid tag format. Expected format is <Name>=<Value> and can only contain alphanumeric characters, Unicode space separators, and the following: _ . : + - @"
                }
            })] 
        # [alias("autoAddTags")]
        [Object]$TagUsedForAutoAddServer,
        
        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-COMGroupsUri  
        $CreateGroupStatus = [System.Collections.ArrayList]::new()
        $ListOfSettingURIs = [System.Collections.ArrayList]::new()
        $ListOfSettingURIsFromSetting = [System.Collections.ArrayList]::new()
        $ListOfSettingURIsFromGroup = [System.Collections.ArrayList]::new()
        $ListOfPoliciesFromGroup = [System.Collections.ArrayList]::new()

        $count = 0

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Name      = $Name
            Region    = $Region                            
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }


        try {
            $GroupResource = Get-HPECOMGroup -Region $Region -Name $Name

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)

        }

        if ($GroupResource) {

            "[{0}] Group '{1}' is already present in the '{2}' region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
    
            if ($WhatIf) {
                $ErrorMessage = "Group '{0}': Resource is already present in the '{1}' region! No action needed." -f $Name, $Region
                Write-warning $ErrorMessage
                $objStatus.Status = "Warning" # required to not display the Whatif when group already exists
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "Group already exists in the region! No action needed."

            }
        }
        else {

            if ($PSCmdlet.MyInvocation.ExpectingInput) {
                
                # If pipeline is Get-HPECOMGroup, add to list group object
                if ($PSBoundParameters.ContainsKey('SettingsObject') -and $SettingsObject.GetType().baseType -eq [System.Array]) {
                    [void]$ListOfSettingURIsFromGroup.add($SettingsObject)
                    [void]$ListOfPoliciesFromGroup.add($PoliciesObject)
                    $count++ 
                }
                # If pipeline is Get-HPECOMSettings, add to list group object
                elseif ($PSBoundParameters.ContainsKey('SettingsObject')) {
                    [void]$ListOfSettingURIsFromSetting.add($SettingsObject)
    
                }
            }     
        }
    }

    end {

        if ($objStatus.Status -eq "Warning" ) {

            if (-not $WhatIf) {
                
                return $objStatus
            }

        }
        else {

            if ($count -gt 1) {
            
                Throw "Error: The group pipeline input contains more than one group. Please refine your query to filter to only one group."
               
            }
    
            if (-not $ListOfSettingURIsFromSetting -and -not $ListOfSettingURIsFromGroup -and -not $SettingsObject) {
    
                "[{0}] Detected no ListOfSettingURIs and no SettingsObject" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
    
                try {
                    $Settings = Get-HPECOMSetting -Region $Region -ErrorAction Stop
    
                }
                catch {
    
                    $PSCmdlet.ThrowTerminatingError($_)
                }
    
                if ($BiosSettingName) {
                    
                    $resourceUri = ($Settings | Where-Object category -eq "BIOS" | Where-Object name -eq $BiosSettingName).resourceUri
    
                    if (-not $resourceUri) {
                        
                        # Throw "Bios setting '$BiosSettingName' cannot be found in the Compute Ops Management instance!"   
                        $ErrorMessage = "Setting '{0}' using the category '{1}' cannot be found in the Compute Ops Management instance!" -f $BiosSettingName, "BIOS"
                        $ErrorRecord = New-ErrorRecord ServerSettingeNotFoundInCOM ObjectNotFound -TargetObject 'Server-settings' -Message $ErrorMessage -TargetType $BiosSettingName.GetType().Name
                    
                        $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    
                    }
                    else {
    
                        [void]$ListOfSettingURIs.add($resourceUri) 
                    }
                }
                if ($ExternalStorageSettingName) {
                    
                    $resourceUri = ($Settings | Where-Object category -eq "EXTERNAL_STORAGE" | Where-Object name -eq $ExternalStorageSettingName).resourceUri
    
                    if (-not $resourceUri) {
                        
                        # Throw "External storage setting '$ExternalStorageSettingName' cannot be found in the Compute Ops Management instance!"
                        $ErrorMessage = "Setting '{0}' using the category '{1}' cannot be found in the Compute Ops Management instance!" -f $ExternalStorageSettingName, "EXTERNAL_STORAGE"
                        $ErrorRecord = New-ErrorRecord ServerSettingeNotFoundInCOM ObjectNotFound -TargetObject 'Server-settings' -Message $ErrorMessage -TargetType $ExternalStorageSettingName.GetType().Name
                        
                        $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    
    
                    }
                    else {
    
                        [void]$ListOfSettingURIs.add($resourceUri) 
                    }
                }
                if ($FirmwareSettingName) {
                    
                    $resourceUri = ($Settings | Where-Object category -eq "FIRMWARE" | Where-Object name -eq $FirmwareSettingName).resourceUri
    
                    if (-not $resourceUri) {
                        
                        # Throw "Firmware setting '$FirmwareSettingName' cannot be found in the Compute Ops Management instance!"
                        $ErrorMessage = "Setting '{0}' using the category '{1}' cannot be found in the Compute Ops Management instance!" -f $FirmwareSettingName, "FIRMWARE"
                        $ErrorRecord = New-ErrorRecord ServerSettingeNotFoundInCOM ObjectNotFound -TargetObject 'Server-settings' -Message $ErrorMessage -TargetType $FirmwareSettingName.GetType().Name
                    
                        $PSCmdlet.ThrowTerminatingError($ErrorRecord)       
    
    
                    }
                    else {
    
                        [void]$ListOfSettingURIs.add($resourceUri) 
                    }
                }
                if ($iLOSettingName) {

                    $resourceUri = ($Settings | Where-Object category -eq "ILO_SETTINGS" | Where-Object name -eq $iLOSettingName).resourceUri

                    if (-not $resourceUri) {
                        # Throw "iLO setting '$iLOSettingName' cannot be found in the Compute Ops Management instance!"
                        $ErrorMessage = "Setting '{0}' using the category '{1}' cannot be found in the Compute Ops Management instance!" -f $iLOSettingName, "ILO_SETTINGS"
                        $ErrorRecord = New-ErrorRecord ServerSettingeNotFoundInCOM ObjectNotFound -TargetObject 'Server-settings' -Message $ErrorMessage -TargetType $iLOSettingName.GetType().Name

                        $PSCmdlet.ThrowTerminatingError($ErrorRecord)
    
                    }
                    else {
    
                        [void]$ListOfSettingURIs.add($resourceUri) 
                    }
                }
                if ($OSSettingName) {
                    
                    $resourceUri = ($Settings | Where-Object category -eq "OS" | Where-Object name -eq $OSSettingName).resourceUri
    
                    if (-not $resourceUri) {
                        
                        # Throw "OS setting '$OSSettingName' cannot be found in the Compute Ops Management instance!"
                        $ErrorMessage = "Setting '{0}' using the category '{1}' cannot be found in the Compute Ops Management instance!" -f $OSSettingName, "OS"
                        $ErrorRecord = New-ErrorRecord ServerSettingeNotFoundInCOM ObjectNotFound -TargetObject 'Server-settings' -Message $ErrorMessage -TargetType $OSSettingName.GetType().Name
                    
                        $PSCmdlet.ThrowTerminatingError($ErrorRecord)   
    
    
                    }
                    else {
    
                        [void]$ListOfSettingURIs.add($resourceUri) 
                    }
                }
                if ($StorageSettingName) {
                    
                    $resourceUri = ($Settings | Where-Object category -eq "STORAGE" | Where-Object name -eq $StorageSettingName).resourceUri
    
                    if (-not $resourceUri) {
                        
                        # Throw "Storage setting '$StorageSettingName' cannot be found in the Compute Ops Management instance!"
                        $ErrorMessage = "Setting '{0}' using the category '{1}' cannot be found in the Compute Ops Management instance!" -f $StorageSettingName, "STORAGE"
                        $ErrorRecord = New-ErrorRecord ServerSettingeNotFoundInCOM ObjectNotFound -TargetObject 'Server-settings' -Message $ErrorMessage -TargetType $StorageSettingName.GetType().Name
                    
                        $PSCmdlet.ThrowTerminatingError($ErrorRecord)        
    
                    }
                    else {
    
                        [void]$ListOfSettingURIs.add($resourceUri) 
                    }
                }
    
                $SettingsObject = $ListOfSettingURIs
                
            }
            # Pipeline is Get-HPECOMGroup 
            elseif ($ListOfSettingURIsFromGroup) {
    
                "[{0}] Detected SettingURIs from Get-HPECOMGroup in pipeline: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ListOfSettingURIsFromGroup | out-string) | Write-Verbose
                # Need top flatten the list of lists
                $SettingsObject = ($ListOfSettingURIsFromGroup | out-string) -split '\r\n' | Where-Object { $_ -ne "" }
            }
            # Pipeline is Get-HPECOMSetting
            elseif ($ListOfSettingURIsFromSetting) {
        
                "[{0}] Detected SettingURIs from Get-HPECOMSetting in pipeline: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ListOfSettingURIsFromSetting | out-string) | Write-Verbose
    
                $SettingsObject = $ListOfSettingURIsFromSetting
    
            }
            # Direct (when -SettingsObject $Settings is used with $Settings = Get-HPECOMSetting)
            elseif ($SettingsObject.GetType().baseType -eq [System.Array]) {
    
                "[{0}] Detected SettingURIs in direct from -SettingsObject: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($SettingsObject.resourceuri | out-string) | Write-Verbose
    
                $SettingsObject = $SettingsObject.resourceuri
            }
            else {
                "[{0}] Detected nothing!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
    
                $SettingsObject = @{}
            }
    
    
            if ($TagUsedForAutoAddServer) {
           
                if ($TagUsedForAutoAddServer -is [string]) {
               
                    # Remove space at the end of the string if any
                    $AutoAddServerTag = $TagUsedForAutoAddServer.TrimEnd()
        
                    # Check for more than one '=' character (if more than one tag is provided)
                    if (($AutoAddServerTag -split '=').Count -gt 2) {
        
                        "[{0}] Tag '{1}' is not supported! Only one tag is expected such as <tagname>=<value>" -f $MyInvocation.InvocationName.ToString().ToUpper(), $TagUsedForAutoAddServer | Write-Verbose
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Tag not supported! Only one tag is expected such as <tagname>=<value>"
                        [void] $CreateGroupStatus.add($objStatus)
                        return  
                    }
        
                    # Check tag format, if format is not <tagname>=<value>, return error
                    if ($AutoAddServerTag -notmatch "^[A-Za-z0-9_-]+=[A-Za-z0-9_-][^=]*$") {
        
                        "[{0}] Tag '{1}' format not supported! Expected format is <tagname>=<value>" -f $MyInvocation.InvocationName.ToString().ToUpper(), $TagUsedForAutoAddServer | Write-Verbose
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Tag format not supported! Expected format is <tagname>=<value>"
                        [void] $CreateGroupStatus.add($objStatus)
                        return  
                    }
        
                    $tagname = $AutoAddServerTag.split('=')[0]
                    $tagvalue = $AutoAddServerTag.split('=')[1]
                    
                    $TagList = @{
                        $tagname = $tagvalue 
                    }
                    
                }
                else {
                    $TagList = $TagUsedForAutoAddServer 
                }
    
            }
            else {
                $TagList = @{}
            }
    
                
            If ($ListOfPoliciesFromGroup) {
    
                $AutoBiosApplySettingsOnAdd = $ListOfPoliciesFromGroup.onDeviceAdd.biosApplySettings
                $ResetBIOSConfigurationSettingsToDefaultsonAdd = $ListOfPoliciesFromGroup.onDeviceAdd.biosFactoryReset
                $AutoExternalStorageConfigurationOnAdd = $ListOfPoliciesFromGroup.onDeviceAdd.externalStorageConfiguration
                $PowerOffServerAfterFirmwareUpdate = $ListOfPoliciesFromGroup.onDeviceAdd.firmwarePowerOff
                $AutoFirmwareUpdateOnAdd = $ListOfPoliciesFromGroup.onDeviceAdd.firmwareUpdate
                $AutoIloApplySettingsOnAdd = $ListOfPoliciesFromGroup.onDeviceAdd.iloApplySettings
                $osCompletionTimeoutMin = $ListOfPoliciesFromGroup.onDeviceAdd.osCompletionTimeoutMin
                $AutoOsImageInstallOnAdd = $ListOfPoliciesFromGroup.onDeviceAdd.osInstall
                $AutoStorageVolumeCreationOnAdd = $ListOfPoliciesFromGroup.onDeviceAdd.storageConfiguration
                $AutoStorageVolumeDeletionOnAdd = $ListOfPoliciesFromGroup.onDeviceAdd.storageVolumeDeletion
    
                $firmwareDowngrade = $ListOfPoliciesFromGroup.onDeviceApply.firmwareDowngrade
            }
    
    
            $onDeviceAdd = @{
                biosApplySettings            = [bool]$AutoBiosApplySettingsOnAdd
                biosFactoryReset             = [bool]$ResetBIOSConfigurationSettingsToDefaultsonAdd
                externalStorageConfiguration = [bool]$AutoExternalStorageConfigurationOnAdd
                firmwarePowerOff             = [bool]$PowerOffServerAfterFirmwareUpdate
                firmwareUpdate               = [bool]$AutoFirmwareUpdateOnAdd
                iloApplySettings             = [bool]$AutoIloApplySettingsOnAdd
                osCompletionTimeoutMin       = [int]$osCompletionTimeoutMin
                osInstall                    = [bool]$AutoOsImageInstallOnAdd
                storageConfiguration         = [bool]$AutoStorageVolumeCreationOnAdd
                storageVolumeDeletion        = [bool]$AutoStorageVolumeDeletionOnAdd
            }
    
            
            if ($FirmwareDowngrade) {
                
                $onDeviceApply = @{ 
                    firmwareDowngrade = [bool]$firmwareDowngrade 
                }
                            
                $Policies = @{
                    onDeviceAdd   = $onDeviceAdd
                    onDeviceApply = $onDeviceApply                
                }
            }
            else {
                 
                $Policies = @{
                    onDeviceAdd = $onDeviceAdd
                    
                }
            }
    
            if ($DeviceType -eq "Servers") {
                $DeviceTypeValue = "DIRECT_CONNECT_SERVER"
            }
            elseif ($DeviceType -eq "OneView Synergy appliances") {
                $DeviceTypeValue = "OVE_APPLIANCE_SYNERGY"
            }
            elseif ($DeviceType -eq "OneView VM appliances") {
                $DeviceTypeValue = "OVE_APPLIANCE_VM"
            }
            else {
                # When pipeline is group, we capture DeviceType directly from the object
                $DeviceTypeValue = $DeviceType
            }
                         
            # Build payload
            $payload = ConvertTo-Json -Depth 10 @{
                name         = $Name
                description  = $Description
                deviceType   = $DeviceTypeValue 
                settingsUris = $SettingsObject
                policies     = $Policies
                autoAddTags  = $TagList
    
            }
    
    
            try {
                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                
                if (-not $WhatIf) {
    
                    "[{0}] Group creation raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose
                    
                    "[{0}] Group '{1}' successfully created in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Region | Write-Verbose
                        
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Group successfully created in $Region region"
    
                }
    
            }
            catch {
    
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Group cannot be created!"
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                }
            }           
    
    
            [void] $CreateGroupStatus.add($objStatus)
    
            if (-not $WhatIf) {
    
                $CreateGroupStatus = Invoke-RepackageObjectWithType -RawObject $CreateGroupStatus -ObjectName "COM.objStatus.NSDE"
                Return $CreateGroupStatus
            }
            
        }
    }
}    

Function Remove-HPECOMGroup {
    <#
    .SYNOPSIS
    Deletes a group from a specified region.

    .DESCRIPTION
    This Cmdlet deletes a group from a specified region.
    
    Note: If you want to delete a group without modifying the server configuration, you must first remove the servers from the group using 'Remove-HPECOMServerfromGroup' before deleting the group.

    Note: If the group you want to delete is part of a scope filter in HPE GreenLake, this filter will not be updated and should be manually reviewed. Check the user accounts associated with scope groups in HPE GreenLake using 'Get-HPEGLUserRole' or 'Get-HPEGLScopeGroup'.
    If necessary, adjust the user account scope group assignments using 'Add-HPEGLRoleToUser' to ensure that the intended scope-based access control is preserved.

    .PARAMETER Name 
    The name of the group to remove. 
    
    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) from which to remove the group. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Force
    A switch parameter to force the removal of the group even if servers are still assigned to it. With this parameter, all group policies and configurations on the servers will be removed.
    
    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Remove-HPECOMGroup -Region eu-central -Name 'vmware_horizon'
    
    Removes the group named 'vmware_horizon' from the central EU region. 

    .EXAMPLE
    Get-HPECOMGroup -Region us-west -Name ESXi_Hypervisors | Remove-HPECOMGroup 

    Removes the group 'ESXi_Hypervisors' from the western US region. 

    .EXAMPLE 
    Get-HPECOMGroup -Region us-west | Where-Object {$_.name -eq 'ESXi_Hypervisors' -or $_.name -eq 'RHEL_Hypervisor'} | Remove-HPECOMGroup
    
    Removes the groups 'ESXi_Hypervisors' and 'RHEL_Hypervisor' from the western US region. 

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central | Remove-HPECOMGroup -Force

    Removes all groups from the central EU region, even if servers are still assigned to the groups, using the -Force switch. In this case, all group policies and configurations on the servers will be removed.

    .INPUTS
    System.Collections.ArrayList
        A list of groups from 'Get-HPECOMGroup'. 

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - The name of the group attempted to be removed
        * Region - The name of the region from which the group is removed
        * Status - The status of the removal attempt (Failed for HTTP error return; Complete if removal is successful; Warning if no action is needed) 
        * Details - More information about the status 
        * Exception - Information about any exceptions generated during the operation.

    
#>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
        [ValidateScript({
                # First check if there's an active session with COM regions
                if (-not $Global:HPEGreenLakeSession -or -not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use HPE GreenLake cmdlets."
                }
                # Then validate the region
                if (($_ -in $Global:HPECOMRegions.region)) {
                    $true
                }
                else {
                    Throw "The COM region '$_' is not provisioned in this workspace! Please specify a valid region code (e.g., 'us-west', 'eu-central'). `nYou can retrieve the region code using: Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned. `nYou can also use the Tab key for auto-completion to see the list of provisioned region codes."
                }
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                # Filter region based on $Global:HPECOMRegions global variable and create completions
                $Global:HPECOMRegions.region | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [String]$Region,  

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [String]$Name,

        [Switch]$Force,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $RemoveGroupStatus = [System.Collections.ArrayList]::new()
        
    }
    
    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        
        try {
            $GroupResource = Get-HPECOMGroup -Region $Region -Name $Name
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Name      = $Name
            Region    = $Region                            
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }
                     
        $GroupID = $GroupResource.id

        
        if (-not $GroupID) {

            # Must return a message if not found

            if ($WhatIf) {

                $ErrorMessage = "Group '{0}': Resource cannot be found in the '{1}' region!" -f $Name, $Region
                Write-warning $ErrorMessage
                return
            
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "Group cannot be found in the region!"
            }
        }
        else {
            
            if ($Force) {

                $Uri = (Get-COMGroupsUri) + "/" + $GroupID + "?force=true"
            }
            else {
                
                $Uri = (Get-COMGroupsUri) + "/" + $GroupID
            }

            # Removal task  
            try {
                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method DELETE -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                
                if (-not $WhatIf) {

                    "[{0}] Group removal raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose

                    "[{0}] Group '{1}' successfully deleted from '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Region | Write-Verbose
                    
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Group successfully deleted from $Region region"

                }

            }
            catch {

                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Group cannot be deleted!"
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                }
            }           

        }
        [void] $RemoveGroupStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            $RemoveGroupStatus = Invoke-RepackageObjectWithType -RawObject $RemoveGroupStatus -ObjectName "COM.objStatus.NSDE"
            Return $RemoveGroupStatus
        }


    }
}

Function Set-HPECOMGroup {
    <#
    .SYNOPSIS
    Update a group resource in a specified region.

    .DESCRIPTION
    This Cmdlet modifies a group resource in a given region. If a parameter is not provided, the cmdlet retains the current settings and only updates the provided parameters.

    .PARAMETER Name 
    Specifies the name of the group to update. 

    .PARAMETER Region 
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the group will be updated. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER NewName 
    Specifies the new name for the group. 

    .PARAMETER Description 
    Specifies a new description of the group.

    .PARAMETER DeviceType
    Specifies the type of device to be added to the group. Servers is the only supported device type at the moment.

    .PARAMETER BiosSettingName
    Specifies the name of a BIOS setting resource.

    .PARAMETER ExternalStorageSettingName
    Specifies the name of an external storage setting resource.

    .PARAMETER FirmwareSettingName
    Specifies the name of a firmware setting resource.

    .PARAMETER iLOSettingName
    Specifies the name of an iLO-settings setting resource.
    To assign the HPE-recommended security settings for iLOs, use the pre-defined setting named 'iLO settings enabled for security'.

    .PARAMETER OSSettingName
    Specifies the name of an OS setting resource.

    .PARAMETER StorageSettingName
    Specifies the name of a storage setting resource.

    .PARAMETER AutoBiosApplySettingsOnAdd
    Enables automatic application of BIOS settings when a server is added to the group. A group must have one of the HPE pre-defined BIOS/Workload profiles for this setting to be effective.
    Note: Effective only when a BIOS setting is defined in the group.

    .PARAMETER ResetBIOSConfigurationSettingsToDefaultsonAdd
    Resets the BIOS configuration settings to default when a server is added to the group.
    Note: Effective only when a BIOS setting is defined in the group.

    .PARAMETER AutoFirmwareUpdateOnAdd
    Enables automatic firmware updates to the configured baseline when a server is added to the group. 
    Note: Effective only when a firmware setting is defined in the group.
       
    .PARAMETER PowerOffServerAfterFirmwareUpdate
    Powers off the server after performing a firmware update.
    Note: Effective only when a firmware setting is defined in the group.
        
    .PARAMETER FirmwareDowngrade
    Allows or forbids the downgrade of firmware during updates.
    Note: Effective only when a firmware setting is defined in the group.
    
    .PARAMETER AutoOsImageInstallOnAdd
    Installs the operating system image immediately when a server is added to the group if it is activated; otherwise, it will install when the server is activated at a later time.
    Note: Effective only when an OS setting is defined in the group.

    .PARAMETER OsCompletionTimeoutMin
    Sets the timeout duration (in minutes) for operating system installation when a server is added to the group with automatic OS installation enabled. The timeout applies per individual server.
    Note: Effective only when an OS setting is defined in the group.
        
    .PARAMETER AutoStorageVolumeCreationOnAdd
    Creates the storage volume for the Operating system immediately when the server is added to the group if it is activated; otherwise, it will create when the server is activated at a later time.
    Note: Effective only when an OS setting is defined in the group.
        
    .PARAMETER AutoStorageVolumeDeletionOnAdd
    Erases any existing internal storage configuration prior to creating a new OS volume when a server is added to the group if the server is activated; otherwise, it will erase when the server is activated at a later time.
    Note: Effective only when a storage setting is defined in the group.
    
    .PARAMETER AutoIloApplySettingsOnAdd
    Enables automatic application of iLO settings when a server is added to the group. A group must have HPE pre-defined iLO settings for this setting to be effective.
    Note: Effective only when an iLO-settings setting is defined in the group.
        
    .PARAMETER AutoExternalStorageConfigurationOnAdd
    Applies the external storage configuration immediately when a server is added to the group if the server is activated; otherwise, it will apply when the server is activated at a later time.
    Note: Effective only when an external storage setting is defined in the group.

    .PARAMETER TagUsedForAutoAddServer
    Associates a case-insensitive tag with a group to automatically add servers to the group when they are activated. 
    
    The tag must meet the following string format <Name>=<Value> and can contain any alphaneumeric characters, any Unicode space separators, and the following characters: _ . : + - @ such as:
     - "Country=US"
     - "App=ESX-8"
     - "Site=Houston site"
     - "Domain=my.lab@domain.com"
    
    Note: 
        - A group can have a maximum of one tag and multiple groups can not have the same tag.
        - Automatic addition to groups can only occur before server activation. If a server’s tags match more than one group, it won’t be added to any group, and will need to be added using a different method.
        - When a server is onboarded or has its tags changed, the server's tags will be checked against the group's autoAddServerTags. 
        - If at least one of the server tags matches one group's autoAddServerTags, the server will be placed into the associated group. 
        - Once a server has been connected, the server becomes ineligible for automatically being placed into groups, even if it is later disconnected.
        - If a server is in a group, any further tag changes will not move it to another group. 

    .PARAMETER WhatIf
    Displays the raw REST API call to COM instead of sending the request. Useful for understanding the native REST API calls used by COM.

    .EXAMPLE
    Set-HPECOMGroup -Region eu-central -Name AI_Group -NewName "AI_Servers_Group" -Description "Group for AI systems" `
        -BiosSettingName "Virtualization - Power Efficient" -AutoBiosApplySettingsOnAdd:$true -ResetBIOSConfigurationSettingsToDefaultsonAdd:$True `
        -FirmwareSettingName "ESXi firmware baseline"   -AutoFirmwareUpdateOnAdd:$True -PowerOffServerAfterFirmwareUpdate:$True -FirmwareDowngrade:$True `
        -iLOSettingName "HPE iLO Security Settings" -AutoIloApplySettingsOnAdd:$True  `
        -OSSettingName OS_ESXi -AutoOsImageInstallOnAdd:$True -OsCompletionTimeoutMin 60 `
        -StorageSettingName "RAID1" -AutoStorageVolumeCreationOnAdd:$True -AutoStorageVolumeDeletionOnAdd:$True  `
        -TagUsedForAutoAddServer "App=RHEL"

    This example demonstrates how to configure a group named "AI_Group" in the "eu-central" region with various settings.
    The group is renamed to "AI_Servers_Group" and given a description "Group for AI systems".
    It applies a BIOS setting named "Virtualization - Power Efficient" with automatic application and resets to default on server addition.
    It sets a firmware baseline named "ESXi firmware baseline" with automatic updates, powers off after updates, and allows downgrades.
    It applies iLO security settings named "HPE iLO Security Settings" automatically on server addition.
    It configures an OS setting named "OS_ESXi" with automatic installation and a completion timeout of 60 minutes.
    It sets a storage configuration named "RAID1" with automatic volume creation and deletion.
    Additionally, it associates the tag "App=RHEL" with the group for automatic server addition based on this tag.
    
    .EXAMPLE
    Set-HPECOMGroup -Region eu-central -Name AI_Group -AutoBiosApplySettingsOnAdd:$false -AutoFirmwareUpdateOnAdd:$false -AutoOsImageInstallOnAdd:$false -AutoStorageVolumeCreationOnAdd:$false -AutoStorageVolumeDeletionOnAdd:$false -AutoIloApplySettingsOnAdd:$false 

    This example demonstrates how to disable all automatic settings when servers are added to the group named "AI_Group" in the "eu-central" region.
        
    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -Name 'Hypervisors_Group' | Set-HPECOMGroup `
    -NewName "ESX_Hypervisors_Group" `
    -Description "My new description" `
    -AutoFirmwareUpdateOnAdd:$False -AutoBiosApplySettingsOnAdd:$True `
    -BiosSettingName "Virtualization - Power Efficient"

    The first command retrieves the server group named 'Hypervisors_Group' located in the 'eu-central' region. 
    The second command updates the group with a new name 'ESX_Hypervisors_Group', a new description 'My new description', and disables automatic firmware updates when a server is added to the group.
       
    .EXAMPLE
    Set-HPECOMGroup -Name AI_Group -Region eu-central -TagUsedForAutoAddServer "" -OSSettingName "" -iLOSettingName "" 

    This example demonstrates how to remove the tag and disable OS settings and iLO settings from the group named "AI_Group" in the "eu-central" region.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central | Set-HPECOMGroup -AutoFirmwareUpdateOnAdd:$False

    This example modifies all groups in the eu-central region to disable automatic firmware updates when a server is added to the group.

    .INPUTS
    System.Collections.ArrayList
        List of groups from 'Get-HPECOMGroup'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following keys:  
        * Name - Name of the group attempted to be updated
        * Region - Name of the region where the group is updated
        * Status - Status of the modification attempt (Failed for HTTP error return; Complete if successful; Warning if no action is needed)
        * Details - More information about the status 
        * Exception - Information about any exceptions generated during the operation.
    #>

    [CmdletBinding(DefaultParameterSetName = 'Filter')]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
        [ValidateScript({
                # First check if there's an active session with COM regions
                if (-not $Global:HPEGreenLakeSession -or -not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use HPE GreenLake cmdlets."
                }
                # Then validate the region
                if (($_ -in $Global:HPECOMRegions.region)) {
                    $true
                }
                else {
                    Throw "The COM region '$_' is not provisioned in this workspace! Please specify a valid region code (e.g., 'us-west', 'eu-central'). `nYou can retrieve the region code using: Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned. `nYou can also use the Tab key for auto-completion to see the list of provisioned region codes."
                }
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                # Filter region based on $Global:HPECOMRegions global variable and create completions
                $Global:HPECOMRegions.region | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [String]$Region,  

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateScript({ $_.Length -le 100 })]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [ValidateScript({ $_.Length -le 100 })]
        [String]$NewName,
        
        # [Parameter (ValueFromPipelineByPropertyName)] 
        [ValidateScript({ $_.Length -le 10000 })]
        [String]$Description,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Servers') #, 'OneView Synergy appliances', 'OneView VM appliances')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Servers')] # , 'OneView Synergy appliances', 'OneView VM appliances')]
        # [Parameter (ValueFromPipelineByPropertyName)] 
        [String]$DeviceType = "Servers",

        [String]$BiosSettingName,        
       
        [String]$ExternalStorageSettingName,

        [string]$FirmwareSettingName,

        [string]$iLOSettingName,
                
        [String]$OSSettingName,
        
        [String]$StorageSettingName,        
        
        # BIOS settings
        [bool]$AutoBiosApplySettingsOnAdd,
        [bool]$ResetBIOSConfigurationSettingsToDefaultsonAdd,  
                
        # Firmware settings
        [bool]$AutoFirmwareUpdateOnAdd,
        [bool]$PowerOffServerAfterFirmwareUpdate,
        [bool]$FirmwareDowngrade,
        
        # OS settings
        [bool]$AutoOsImageInstallOnAdd,
        [ValidateScript({ $_ -ge 60 -and $_ -le 720 })]
        [Int]$OsCompletionTimeoutMin,
        
        # Storage settings
        [bool]$AutoStorageVolumeCreationOnAdd,
        [bool]$AutoStorageVolumeDeletionOnAdd,

        # iLO settings
        [bool]$AutoIloApplySettingsOnAdd,

        # External storage settings       
        [bool]$AutoExternalStorageConfigurationOnAdd,
        
        # Tags settings  
        [ValidateScript({
                # Allows empty strings to pass the validation when "" is provided to remove the tag or when group in the pipeline does not have a tag
                if ($_ -eq '' -or $_ -eq $null) {
                    $True
                }    
                # Checks if the input string matches a specific pattern that starts with '@{' and ends with '}', 
                # containing letters, digits, underscores, spaces, dots, colons, plus signs, hyphens, and at signs.
                elseif ($_ -match '^@\{[\p{L}\p{Nd}_ .:+\-@]+\=[\p{L}\p{Nd}_ .:+\-@]+\}$') {
                    $True
                }
            
                elseif (($_ -split '=').Count -gt 2) {
                    throw "Input '$_' is not in a valid tag format. Only one tag is expected such as <Name>=<Value>"
                }
                # Checks if the input string matches a specific pattern <Name>=<Value> that starts with a letter, followed by letters, digits, underscores, spaces, dots, colons, plus signs, hyphens, and at signs,
                elseif ($_ -match '^[\p{L}\p{Nd}_ .:+\-@]+\=[\p{L}\p{Nd}_ .:+\-@]+$') { 
                    $True
                }
                elseif ($_ -notmatch '^[\p{L}\p{Nd}_ .:+\-@]+\=[\p{L}\p{Nd}_ .:+\-@]+$') {
                    throw "Input '$_' is not in a valid tag format. Expected format is <Name>=<Value> and can only contain alphanumeric characters, Unicode space separators, and the following: _ . : + - @"
                }
            })] 
        [String]$TagUsedForAutoAddServer,      

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $SetGroupStatus = [System.Collections.ArrayList]::new()
        $onDeviceAdd = [System.Collections.Hashtable]::new()
        $Policies = [System.Collections.Hashtable]::new()

        
    }
    
    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        try {
           
            $GroupResource = Get-HPECOMGroup -Region $Region -Name $Name 
            $GroupID = $GroupResource.id
        }   
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
        

        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Name      = $Name
            Region    = $Region                            
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

      
     
        if (-not $GroupID) {
            
            # Must return a message if not found

            if ($WhatIf) {

                $ErrorMessage = "Group '{0}': Resource cannot be found in the '{1}' region!" -f $Name, $Region
                Write-warning $ErrorMessage
                return
            
            
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "Group cannot be found in the region!"
            }
        }
        else {
            
            $Uri = (Get-COMGroupsUri) + "/" + $GroupID

            # Get existing group settings
            $ExistingGroupSettings = Get-HPECOMGroup -Region $Region -Name $Name -ShowSettings
                           
            # Get settings from the Compute Ops Management instance
            try {
                $Settings = Get-HPECOMSetting -Region $Region -ErrorAction Stop
                
            }
            catch {
                
                $PSCmdlet.ThrowTerminatingError($_)
            }
            
            
            $SettingsUris = [System.Collections.ArrayList]::new()

            # Check if settings are provided or not, if provided, get the resourceUri and add it to the settingsUris list, if not, get the existing settings from the group
            if (-not $PSBoundParameters.ContainsKey('BiosSettingName')) {

                $Category = 'BIOS'

                if ($ExistingGroupSettings | Where-Object category -eq $Category) {

                    $_RessourceUri = $ExistingGroupSettings | Where-Object category -eq $Category | ForEach-Object resourceUri

                    if ($_RessourceUri) {

                        "[{0}] {1} setting found in group: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Category, $_RessourceUri | Write-Verbose
                        
                        [void]$SettingsUris.add($_RessourceUri) 

                        $BiosSettingFound = $True
                    }
                }
            }
            else {
                
                if ($BiosSettingName) {

                    $Category = 'BIOS'

                    $_RessourceUri = ($Settings | Where-Object category -eq $Category | Where-Object name -eq $BiosSettingName).resourceUri
                
                    if (-not $_RessourceUri) {

                        # Must return a message if not found    
                        $ErrorMessage = "Setting '{0}' using the category '{1}' cannot be found in the Compute Ops Management instance!" -f $BiosSettingName, $Category
                        $ErrorRecord = New-ErrorRecord ServerSettingeNotFoundInCOM ObjectNotFound -TargetObject 'Server-settings' -Message $ErrorMessage -TargetType $BiosSettingName.GetType().Name
                    
                        $PSCmdlet.ThrowTerminatingError($ErrorRecord)   

                    }
                    else {

                        [void]$SettingsUris.add($_RessourceUri) 
                    }
                }   
                else {
                    # Need to disable bios configuration if bios setting name provided is ""
                    $DeleteBiosSettings = $True

                }              
            }           

            if (-not $PSBoundParameters.ContainsKey('ExternalStorageSettingName')) {

                $Category = 'EXTERNAL_STORAGE'

                if ($ExistingGroupSettings | Where-Object category -eq $Category) {

                    $_RessourceUri = $ExistingGroupSettings | Where-Object category -eq $Category | ForEach-Object resourceUri

                    if ($_RessourceUri) {

                        "[{0}] {1} setting found in group: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Category, $_RessourceUri | Write-Verbose
                        
                        [void]$SettingsUris.add($_RessourceUri) 

                        $ExternalStorageSettingFound = $True

                    }
                }
            }
            else {
                
                if ($ExternalStorageSettingName) {

                    $Category = 'EXTERNAL_STORAGE'

                    $_RessourceUri = ($Settings | Where-Object category -eq $Category | Where-Object name -eq $ExternalStorageSettingName).resourceUri
                
                    if (-not $_RessourceUri) {

                        # Must return a message if not found    
                        $ErrorMessage = "Setting '{0}' using the category '{1}' cannot be found in the Compute Ops Management instance!" -f $ExternalStorageSettingName, $Category
                        $ErrorRecord = New-ErrorRecord ServerSettingeNotFoundInCOM ObjectNotFound -TargetObject 'Server-settings' -Message $ErrorMessage -TargetType $ExternalStorageSettingName.GetType().Name
                    
                        $PSCmdlet.ThrowTerminatingError($ErrorRecord)   

                    }
                    else {

                        [void]$SettingsUris.add($_RessourceUri) 
                    }
                }
                else {
                    # Need to disable external configuration if external storage setting name provided is ""
                    $DeleteExternalStorageSettings = $True

                }                   
            }
            
            if (-not $PSBoundParameters.ContainsKey('FirmwareSettingName')) {

                $Category = 'FIRMWARE'

                if ($ExistingGroupSettings | Where-Object category -eq $Category) {

                    $_RessourceUri = $ExistingGroupSettings | Where-Object category -eq $Category | ForEach-Object resourceUri

                    if ($_RessourceUri) {

                        "[{0}] {1} setting found in group: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Category, $_RessourceUri | Write-Verbose
                        
                        [void]$SettingsUris.add($_RessourceUri) 

                        $FirmwareSettingFound = $True

                    }
                }
            }
            else {
                
                if ($FirmwareSettingName) {

                    $Category = 'FIRMWARE'

                    $_RessourceUri = ($Settings | Where-Object category -eq $Category | Where-Object name -eq $FirmwareSettingName).resourceUri
                
                    if (-not $_RessourceUri) {

                        # Must return a message if not found    
                        $ErrorMessage = "Setting '{0}' using the category '{1}' cannot be found in the Compute Ops Management instance!" -f $FirmwareSettingName, $Category
                        $ErrorRecord = New-ErrorRecord ServerSettingeNotFoundInCOM ObjectNotFound -TargetObject 'Server-settings' -Message $ErrorMessage -TargetType $FirmwareSettingName.GetType().Name
                    
                        $PSCmdlet.ThrowTerminatingError($ErrorRecord)   

                    }
                    else {

                        [void]$SettingsUris.add($_RessourceUri) 
                    }
                }  
                else {
                    # Need to disable Firmware configuration if firmware setting name provided is ""
                    $DeleteFirmwareSettings = $True

                }                
            }
            

            if (-not $PSBoundParameters.ContainsKey('iLOSettingName')) {

                $Category = 'ILO_SETTINGS'

                if ($ExistingGroupSettings | Where-Object category -eq $Category) {

                    $_RessourceUri = $ExistingGroupSettings | Where-Object category -eq $Category | ForEach-Object resourceUri

                    if ($_RessourceUri) {

                        "[{0}] {1} setting found in group: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Category, $_RessourceUri | Write-Verbose
                        
                        [void]$SettingsUris.add($_RessourceUri) 

                        $iLOSettingFound = $True

                    }
                }
            }
            else {
                
                if ($iLOSettingName) {

                    $Category = 'ILO_SETTINGS'

                    $_RessourceUri = ($Settings | Where-Object category -eq $Category | Where-Object name -eq $iLOSettingName).resourceUri
                
                    if (-not $_RessourceUri) {

                        # Must return a message if not found    
                        $ErrorMessage = "Setting '{0}' using the category '{1}' cannot be found in the Compute Ops Management instance!" -f $iLOSettingName, $Category
                        $ErrorRecord = New-ErrorRecord ServerSettingeNotFoundInCOM ObjectNotFound -TargetObject 'Server-settings' -Message $ErrorMessage -TargetType $iLOSettingName.GetType().Name
                    
                        $PSCmdlet.ThrowTerminatingError($ErrorRecord)   

                    }
                    else {

                        [void]$SettingsUris.add($_RessourceUri) 
                    }
                }   
                else {
                    # Need to disable iLO configuration if iLO setting name provided is ""
                    $DeleteiLOSettings = $True

                }              
            }

            if (-not $PSBoundParameters.ContainsKey('OSSettingName')) {

                $Category = 'OS'

                if ($ExistingGroupSettings | Where-Object category -eq $Category) {

                    $_RessourceUri = $ExistingGroupSettings | Where-Object category -eq $Category | ForEach-Object resourceUri

                    if ($_RessourceUri) {

                        "[{0}] {1} setting found in group: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Category, $_RessourceUri | Write-Verbose
                        
                        [void]$SettingsUris.add($_RessourceUri) 

                        $OSSettingFound = $True

                    }
                }
            }
            else {
                
                if ($OSSettingName) {

                    $Category = 'OS'

                    $_RessourceUri = ($Settings | Where-Object category -eq $Category | Where-Object name -eq $OSSettingName).resourceUri
                
                    if (-not $_RessourceUri) {

                        # Must return a message if not found    
                        $ErrorMessage = "Setting '{0}' using the category '{1}' cannot be found in the Compute Ops Management instance!" -f $OSSettingName, $Category
                        $ErrorRecord = New-ErrorRecord ServerSettingeNotFoundInCOM ObjectNotFound -TargetObject 'Server-settings' -Message $ErrorMessage -TargetType $OSSettingName.GetType().Name
                    
                        $PSCmdlet.ThrowTerminatingError($ErrorRecord)   

                    }
                    else {

                        [void]$SettingsUris.add($_RessourceUri) 
                    }
                }  
                else {
                    # Need to disable OS configuration if OS setting name provided is ""
                    $DeleteOSSettings = $True

                }             
            }

            if (-not $PSBoundParameters.ContainsKey('StorageSettingName')) {

                $Category = 'STORAGE'

                if ($ExistingGroupSettings | Where-Object category -eq $Category) {

                    $_RessourceUri = $ExistingGroupSettings | Where-Object category -eq $Category | ForEach-Object resourceUri

                    if ($_RessourceUri) {

                        "[{0}] {1} setting found in group: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Category, $_RessourceUri | Write-Verbose
                        
                        [void]$SettingsUris.add($_RessourceUri) 

                        $StorageSettingFound = $True

                    }
                }
            }
            else {
                
                if ($StorageSettingName) {

                    $Category = 'STORAGE'

                    $_RessourceUri = ($Settings | Where-Object category -eq $Category | Where-Object name -eq $StorageSettingName).resourceUri
                
                    if (-not $_RessourceUri) {

                        # Must return a message if not found    
                        $ErrorMessage = "Setting '{0}' using the category '{1}' cannot be found in the Compute Ops Management instance!" -f $StorageSettingName, $Category
                        $ErrorRecord = New-ErrorRecord ServerSettingeNotFoundInCOM ObjectNotFound -TargetObject 'Server-settings' -Message $ErrorMessage -TargetType $StorageSettingName.GetType().Name
                    
                        $PSCmdlet.ThrowTerminatingError($ErrorRecord)   

                    }
                    else {

                        [void]$SettingsUris.add($_RessourceUri) 
                    }
                }      
                else {
                    # Need to disable storage configuration if storage setting name provided is ""
                    $DeleteStorageSettings = $True

                }        
            }
            

            if (-not $PSBoundParameters.ContainsKey('TagUsedForAutoAddServer')) {

                if ($GroupResource.autoAddTags) {

                    $TagList = $GroupResource.autoAddTags
                }
                else {
                    $TagList = @{}
                }
            
            }
            else {

                if ($TagUsedForAutoAddServer) {
                    
                    "[{0}] TagUsedForAutoAddServer value: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $TagUsedForAutoAddServer | Write-Verbose

                    # Remove space at the end of the string if any
                    $AutoAddServerTag = $TagUsedForAutoAddServer.TrimEnd()
    
                    $Tagname = $AutoAddServerTag.split('=')[0]
                    $Tagvalue = $AutoAddServerTag.split('=')[1]


                    # Remove existing tag (if any) and if the new tag is different from the existing tag name 
                    if ( ($GroupResource.autoAddTags.psobject.properties.name -and $GroupResource.autoAddTags.psobject.properties.name -ne $Tagname) ) {

                        "[{0}] Existing AutoAddTags object: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($GroupResource.autoAddTags.psobject.properties | out-string) | Write-Verbose
                    
                        $TagNameToRemove = $GroupResource.autoAddTags.psobject.properties.name
                        $TagList += @{ $TagNameToRemove = $Null }
                    }
                    
                    # Set existing tag (if any) and if the new tag name is the same as the existing one but with a different value 
                    if ( $GroupResource.autoAddTags.psobject.properties.name -and $GroupResource.autoAddTags.psobject.properties.name -eq $Tagname -and $GroupResource.autoAddTags.psobject.properties.value -ne $Tagvalue ) {

                        "[{0}] Existing AutoAddTags object: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($GroupResource.autoAddTags.psobject.properties | out-string) | Write-Verbose
                    
                        $TagList += @{ $Tagname = $Tagvalue }
                    }
                    else {

                        $TagList += @{ $Tagname = $Tagvalue }
                    }
                }
                else {
                    if ( $GroupResource.autoAddTags.psobject.properties.name) {
                        
                        $Tagname = $GroupResource.autoAddTags.psobject.properties.name
                        $TagList = @{ $Tagname = $Null }
                    }
                    else {
                        $TagList = @{}
                    }    
                }           
            }


            # BIOS settings
            if (-not $PSBoundParameters.ContainsKey('AutoBiosApplySettingsOnAdd')) {
                if ($BiosSettingFound -and $GroupResource.policies.onDeviceAdd.biosApplySettings) {
                    $onDeviceAdd["biosApplySettings"] = $GroupResource.policies.onDeviceAdd.biosApplySettings
                }
            }
            else {
                $onDeviceAdd["biosApplySettings"] = $AutoBiosApplySettingsOnAdd
            }

            if (-not $PSBoundParameters.ContainsKey('ResetBIOSConfigurationSettingsToDefaultsonAdd')) {
                if ($BiosSettingFound -and $GroupResource.policies.onDeviceAdd.biosFactoryReset) {
                    $onDeviceAdd["biosFactoryReset"] = $GroupResource.policies.onDeviceAdd.biosFactoryReset
                }
            }
            else {
                $onDeviceAdd["biosFactoryReset"] = $ResetBIOSConfigurationSettingsToDefaultsonAdd
            }

            # Firmware settings
            if (-not $PSBoundParameters.ContainsKey('AutoFirmwareUpdateOnAdd')) {
                if ($FirmwareSettingFound -and $GroupResource.policies.onDeviceAdd.firmwareUpdate) {
                    $onDeviceAdd["firmwareUpdate"] = $GroupResource.policies.onDeviceAdd.firmwareUpdate
                }
            }  
            else {
                $onDeviceAdd["firmwareUpdate"] = $AutoFirmwareUpdateOnAdd
            }
            if (-not $PSBoundParameters.ContainsKey('firmwareDowngrade')) {
                if ($FirmwareSettingFound -and $GroupResource.policies.onDeviceApply.firmwareDowngrade) {
                    $onDeviceApply = @{ firmwareDowngrade = $GroupResource.policies.onDeviceApply.firmwareDowngrade }
                }
            }
            else {
                $onDeviceApply = @{ firmwareDowngrade = $FirmwareDowngrade }
            }
            if (-not $PSBoundParameters.ContainsKey('PowerOffServerAfterFirmwareUpdate')) {
                if ($FirmwareSettingFound -and $GroupResource.policies.onDeviceAdd.firmwarePowerOff) {
                    $onDeviceAdd["firmwarePowerOff"] = $GroupResource.policies.onDeviceAdd.firmwarePowerOff
                }
            }
            else {
                $onDeviceAdd["firmwarePowerOff"] = $PowerOffServerAfterFirmwareUpdate
            }
             
            # OS settings
            if (-not $PSBoundParameters.ContainsKey('AutoOsImageInstallOnAdd')) {
                if ($OSSettingFound -and $GroupResource.policies.onDeviceAdd.osInstall) {
                    $onDeviceAdd["osInstall"] = $GroupResource.policies.onDeviceAdd.osInstall
                }
            }
            else {
                $onDeviceAdd["osInstall"] = $AutoOsImageInstallOnAdd
            }
            if (-not $PSBoundParameters.ContainsKey('osCompletionTimeoutMin')) {
                if ($OSSettingFound -and $GroupResource.policies.onDeviceAdd.osCompletionTimeoutMin) {
                    $onDeviceAdd["osCompletionTimeoutMin"] = $GroupResource.policies.onDeviceAdd.osCompletionTimeoutMin
                }
            }
            else {
                $onDeviceAdd["osCompletionTimeoutMin"] = $OsCompletionTimeoutMin
            }
            
            # Storage settings
            if (-not $PSBoundParameters.ContainsKey('AutoStorageVolumeCreationOnAdd')) {
                if ($StorageSettingFound -and $GroupResource.policies.onDeviceAdd.storageConfiguration) {
                    $onDeviceAdd["storageConfiguration"] = $GroupResource.policies.onDeviceAdd.storageConfiguration
                }
            }
            else {
                $onDeviceAdd["storageConfiguration"] = $AutoStorageVolumeCreationOnAdd
            }
            if (-not $PSBoundParameters.ContainsKey('AutoStorageVolumeDeletionOnAdd')) {
                if ($StorageSettingFound -and $GroupResource.policies.onDeviceAdd.storageVolumeDeletion) {
                    $onDeviceAdd["storageVolumeDeletion"] = $GroupResource.policies.onDeviceAdd.storageVolumeDeletion
                }
            }
            else {
                $onDeviceAdd["storageVolumeDeletion"] = $AutoStorageVolumeDeletionOnAdd
            }
          
            # iLO settings

            if (-not $PSBoundParameters.ContainsKey('AutoIloApplySettingsOnAdd')) {
                if ($iLOSettingFound -and $GroupResource.policies.onDeviceAdd.iloApplySettings) {
                    $onDeviceAdd["iloApplySettings"] = $GroupResource.policies.onDeviceAdd.iloApplySettings
                }
            }
            else {
                $onDeviceAdd["iloApplySettings"] = $AutoIloApplySettingsOnAdd
            }

            # External storage settings
            if (-not $PSBoundParameters.ContainsKey('AutoExternalStorageConfigurationOnAdd')) {
                if ($ExternalStorageSettingFound -and $GroupResource.policies.onDeviceAdd.externalStorageConfiguration) {
                    $onDeviceAdd["externalStorageConfiguration"] = $GroupResource.policies.onDeviceAdd.externalStorageConfiguration
                }
            }
            else {
                $onDeviceAdd["externalStorageConfiguration"] = $AutoExternalStorageConfigurationOnAdd
            }


            # Conditionally add properties
            if ($NewName) {
                $Name = $NewName
            }
           
            if (-not $PSBoundParameters.ContainsKey('Description')) {
	    
                if ($GroupResource.description) {
                              
                    $Description = $GroupResource.description
                }
                else {
                    $Description = $Null
                }
            }
            else {
                $Description = $Description
            }

            # $onDeviceAdd = @{
            #     biosApplySettings            = [bool]$AutoBiosApplySettingsOnAdd
            #     biosFactoryReset	           = [bool]$ResetBIOSConfigurationSettingsToDefaultsonAdd
            #     externalStorageConfiguration = [bool]$AutoExternalStorageConfigurationOnAdd
            #     firmwarePowerOff             = [bool]$PowerOffServerAfterFirmwareUpdate
            #     firmwareUpdate               = [bool]$AutoFirmwareUpdateOnAdd
            #     iloApplySettings             = [bool]$AutoIloApplySettingsOnAdd
            #     osCompletionTimeoutMin       = [int]$osCompletionTimeoutMin
            #     osInstall                    = [bool]$AutoOsImageInstallOnAdd
            #     storageConfiguration         = [bool]$AutoStorageVolumeCreationOnAdd
            #     storageVolumeDeletion        = [bool]$AutoStorageVolumeDeletionOnAdd
            # }

   

            # Disabling bios configuration if bios setting is ""
            If ($DeleteBiosSettings) {
                $onDeviceAdd = $onDeviceAdd | Select-Object -Property * -ExcludeProperty biosApplySettings, biosFactoryReset

            }

            # Disabling firmware configuration if firmware setting is ""
            If ($DeleteFirmwareSettings) {
                $onDeviceAdd = $onDeviceAdd | Select-Object -Property * -ExcludeProperty firmwareUpdate, firmwarePowerOff

            }

            # Disabling iLO configuration if iLO setting is $False
            If ($DeleteIloSettings) {
                $onDeviceAdd = $onDeviceAdd | Select-Object -Property * -ExcludeProperty iloApplySettings

            }

            # Disabling OS configuration if OS setting is ""
            If ($DeleteOSSettings) {
                $onDeviceAdd = $onDeviceAdd | Select-Object -Property * -ExcludeProperty osCompletionTimeoutMin, osInstall

            }

            # Disabling external storage configuration if external storage setting is ""
            If ($DeleteExternalStorageSettings) {
                $onDeviceAdd = $onDeviceAdd | Select-Object -Property * -ExcludeProperty externalStorageConfiguration

            }

            # Disabling storage configuration if storage setting is ""
            If ($DeleteStorageSettings) {
                $onDeviceAdd = $onDeviceAdd | Select-Object -Property * -ExcludeProperty storageVolumeDeletion, storageConfiguration
                
            }

            
            If ($onDeviceApply) {
               
                $Policies = @{
                    onDeviceAdd   = $onDeviceAdd
                    onDeviceApply = $onDeviceApply
                }

            }
            elseif ($onDeviceAdd.count -gt 0) {
                $Policies = @{
                    onDeviceAdd = $onDeviceAdd
                }
            }
            else {
                $Policies = @{}
            }

            # Build payload
            $payload = ConvertTo-Json -Depth 10 @{
                name         = $Name
                description  = $Description
                settingsUris = $SettingsUris
                policies     = $Policies
                autoAddTags  = $TagList
            }          
          
            # Set resource
            try {
                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method PATCH -body $payload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                
                if (-not $WhatIf) {

                    "[{0}] Group update raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose
                
                    "[{0}] Group '{1}' successfully updated in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Region | Write-Verbose
                    
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Group successfully updated in $Region region"

                }

            }
            catch {

                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Group cannot be updated!"
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 

                }
            }           
        }

        [void] $SetGroupStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            $SetGroupStatus = Invoke-RepackageObjectWithType -RawObject $SetGroupStatus -ObjectName "COM.objStatus.NSDE"
            Return $SetGroupStatus
        }
    }
}

Function Add-HPECOMServerToGroup {
    <#
    .SYNOPSIS
    Add server to a group in a specified region.

    .DESCRIPTION   
    This cmdlet adds a server to a group within a specified region. It does not support transferring a server directly from one group to another. 
    To transfer a server, first use `Remove-HPECOMServerFromGroup` to remove the server from its current group, and then use `Add-HPECOMServerToGroup` to add it to the new group.

    .PARAMETER Region 
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the group is located.  
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER ServerSerialNumber
    Specifies the serial number of the server to be assigned to the group.

    .PARAMETER GroupName 
    Specifies the name of the group to which servers will be added. 

    .PARAMETER WhatIf
    Displays the raw REST API call that would be made to COM instead of sending the request. Useful for understanding the native REST API calls used by COM.

    .EXAMPLE
    Add-HPECOMServerToGroup -Region us-west -ServerSerialNumber "J208PP0026" -GroupName RHEL_Hypervisors 
   
    This example adds a server with the serial number 'J208PP0026' to the group 'RHEL_Hypervisors' in the western US region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name "esx5-2.domain.lab" | Add-HPECOMServerToGroup -GroupName ESXi_group 

    This command retrieves a server named 'esx5-2.domain.lab' in the central EU region and adds it to the group 'ESXi_group'.

    .EXAMPLE
    Get-HPECOMServer -Region us-west -Model "ProLiant DL345 Gen10 Plus" | Add-HPECOMServerToGroup -GroupName RHEL_Hypervisors

    This command retrieves servers with the model 'ProLiant DL345 Gen10 Plus' in the western US region and adds them to the group 'RHEL_Hypervisors'.
    
    .EXAMPLE
    "J208PP0026", "J208PP000X" | Add-HPECOMServerToGroup -Region us-west -GroupName RHEL_Hypervisors 

    This command adds servers with serial numbers 'J208PP0026' and 'J208PP000X' to the group 'RHEL_Hypervisors' in the western US region.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.
    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following keys:  
        * SerialNumber - Serial number of the server attempted to be added to the group
        * Region - Name of the region where the group is located
        * Group - Name of the group to which the server is added
        * Status - The status of the addition attempt (`Failed` for HTTP error return; `Complete` if successful; `Warning` if no action is needed) 
        * Details - More information about the status 
        * Exception - Information about any exceptions generated during the operation.

    
    #>

    [CmdletBinding()]
    Param( 
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
        [ValidateScript({
                # First check if there's an active session with COM regions
                if (-not $Global:HPEGreenLakeSession -or -not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use HPE GreenLake cmdlets."
                }
                # Then validate the region
                if (($_ -in $Global:HPECOMRegions.region)) {
                    $true
                }
                else {
                    Throw "The COM region '$_' is not provisioned in this workspace! Please specify a valid region code (e.g., 'us-west', 'eu-central'). `nYou can retrieve the region code using: Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned. `nYou can also use the Tab key for auto-completion to see the list of provisioned region codes."
                }
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                # Filter region based on $Global:HPECOMRegions global variable and create completions
                $Global:HPECOMRegions.region | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [String]$Region,  

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)] 
        [Alias('serial', 'serialnumber')]
        [String]$ServerSerialNumber,

        [Parameter (Mandatory)]
        [String]$GroupName,
        
        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose


        $ObjectStatusList = [System.Collections.ArrayList]::new()
        $DevicesList = [System.Collections.ArrayList]::new()
        $DevicesTrackingList = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            SerialNumber = $ServerSerialNumber
            Region       = $Region         
            Group        = $GroupName                   
            Status       = $Null
            Details      = $Null
            Exception    = $Null
        }

       
        [void] $ObjectStatusList.add($objStatus)

    }

    end {

        
        try {
            $Group = Get-HPECOMGroup -Region $Region -Name $GroupName
            $GroupMembers = $Group.devices 

            $Uri = (Get-COMGroupsUri) + "/" + $Group.ID + "/devices"
           
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        if ( -not $Group) {

            $ErrorMessage = "Group '{0}' cannot be found in the region!" -f $GroupName

            throw $ErrorMessage

        }


        try {
            
            $Servers = Get-HPECOMServer -Region $Region 
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }
        
        
        "[{0}] List of servers to add to group: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList.SerialNumber | out-string) | Write-Verbose


        foreach ($Object in $ObjectStatusList) {

            "[{0}] Checking server '{1}' " -f $MyInvocation.InvocationName.ToString().ToUpper(), $Object.SerialNumber | Write-Verbose

            $Server = $Servers | Where-Object serialNumber -eq $Object.SerialNumber

            if ( -not $Server) {

                # Must return a message if device not found
                $Object.Status = "Failed"
                $Object.Details = "Server cannot be found in the region!"

                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Resource cannot be found in the '{1}' region!" -f $Object.SerialNumber, $Region
                    Write-warning $ErrorMessage
                    continue
                }

            } 
            elseif ($GroupMembers | Where-Object serial -eq $Object.SerialNumber) {  

                # Must return a message if server already member of the group
                $Object.Status = "Warning"
                $Object.Details = "Server already a member of the group!"

                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Resource is already a member of the '{1}' group!" -f $Object.SerialNumber, $GroupName
                    Write-warning $ErrorMessage
                    continue
                }

            }
            elseif ($Server.associatedGroupname) {
                # Must return a message if server already member of another group
                $Object.Status = "Warning"
                $Object.Details = "Server is already a member of another group ('{0}')!" -f $Server.associatedGroupname

                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Resource is already a member of another group ('{1}')!" -f $Object.SerialNumber, $Server.associatedGroupname
                    Write-warning $ErrorMessage
                    continue
                }
            }
            else {       

                "[{0}] Server '{1}' is not a member of the group '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Object.SerialNumber, $GroupName | Write-Verbose
            
                # Build DeviceList object for paylaod
                $DeviceList = [PSCustomObject]@{
                    deviceId = $server.id
                }

                # Build DeviceInfo object for tracking
                $DeviceInfo = [PSCustomObject]@{
                    serialnumber = $server.serialNumber
                }

                # Building the list of devices object for payload
                [void]$DevicesList.Add($DeviceList)

                # Building the list of devices object for tracking
                [void]$DevicesTrackingList.Add($DeviceInfo)
                    
            }
        }

        
        if ($DevicesList) {

            # Build payload
            $payload = ConvertTo-Json -Depth 10 @{
                devices = $DevicesList
            } 
        
            # Add Devices to group  
            try {

                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -Body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                
                if (-not $WhatIf) {
                   
                    foreach ($Object in $ObjectStatusList) {

                        $DeviceSet = $DevicesTrackingList | Where-Object serialnumber -eq $Object.SerialNumber

                        If ($DeviceSet) {
                            
                            $Object.Status = "Complete"
                            $Object.Details = "Server successfully added to '$groupname' group in '$Region' region"

                        }
                    }
                }
            }
            catch {
                
                if (-not $WhatIf) {

                    foreach ($Object in $ObjectStatusList) {

                        $DeviceSet = $DevicesTrackingList | Where-Object serialnumber -eq $Object.SerialNumber

                        If ($DeviceSet) {
                            
                            $Object.Status = "Failed"
                            $Object.Details = "Server cannot be added to '$groupname' group!"
                            $Object.Exception = $_.Exception.message 

                        }
                    }
                }
            }
        }
        

        if (-not $WhatIf) {

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "COM.Groups.SGSDE"
            Return $ObjectStatusList
        }


    }
}

Function Remove-HPECOMServerFromGroup {
    <#
    .SYNOPSIS
    Remove a server from a group in a specified region.

    .DESCRIPTION   
    This cmdlet removes a server from a specified group within a region. It can also remove all servers from the group and initiate a factory reset of the server BIOS once the removal is complete.

    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the group is located.  
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER ServerSerialNumber
    Specifies the serial number of the server to be removed from the group. Serial numbers can be found using 'Get-HPECOMGroup -Region $Region -Name $GroupName -ShowMembers'.
    
    .PARAMETER GroupName 
    The name of the group from which the servers will be removed. 
 
    .PARAMETER All
    An optional parameter to remove all servers from the group.

    .PARAMETER ResetBios
    An optional parameter that initiates a factory reset of the server BIOS once the removal is complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Remove-HPECOMServerFromGroup -Region us-west -ServerSerialNumber "J208PP0026" -GroupName RHEL_Hypervisors 
   
    This example removes the server with serial number 'J208PP0026' from the group 'RHEL_Hypervisors' in the western US region.

    .EXAMPLE
    Remove-HPECOMServerFromGroup -Region us-west -GroupName RHEL_Hypervisors -All -ResetBios 
 
    This example removes all servers from the group 'RHEL_Hypervisors' in the western US region and initiates a factory reset of all servers' BIOS once the removal is complete.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -Name ESXi_group -ShowMembers | Remove-HPECOMServerFromGroup

    This example retrieves all servers from the group 'ESXi_group' in the central EU region and removes them from the group.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-Gen10P-1.lab | Remove-HPECOMServerFromGroup -GroupName ESXi_group 

    This example retrieves the server named 'ESX-Gen10P-1.lab' in the central EU region and removes it from the group 'ESXi_group'.

    .EXAMPLE
    "J208PP0026", "J208PP000X" | Remove-HPECOMServerFromGroup -Region us-west -GroupName RHEL_Hypervisors 

    This example removes servers with serial numbers 'J208PP0026' and 'J208PP000X' from the group 'RHEL_Hypervisors' in the western US region.

    .EXAMPLE
    Get-HPECOMServer -Region us-west -Model "ProLiant DL345 Gen10 Plus" | Remove-HPECOMServerFromGroup -GroupName RHEL_Hypervisors 

    This example retrieves servers with the model 'ProLiant DL345 Gen10 Plus' in the western US region and removes them from the group 'RHEL_Hypervisors'.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.
    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer' or 'Get-HPECOMGroup -ShowMembers'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * SerialNumber - Serial number of the server attempted to be removed from the group
        * Region - Name of the region where the group is located
        * Group - Name of the group from which the server is removed
        * Status - The status of the removal attempt (Failed for http error return; Complete if removal is successful; Warning if no action is needed) 
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.

    
   #>

    [CmdletBinding()]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
        [ValidateScript({
                # First check if there's an active session with COM regions
                if (-not $Global:HPEGreenLakeSession -or -not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use HPE GreenLake cmdlets."
                }
                # Then validate the region
                if (($_ -in $Global:HPECOMRegions.region)) {
                    $true
                }
                else {
                    Throw "The COM region '$_' is not provisioned in this workspace! Please specify a valid region code (e.g., 'us-west', 'eu-central'). `nYou can retrieve the region code using: Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned. `nYou can also use the Tab key for auto-completion to see the list of provisioned region codes."
                }
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                # Filter region based on $Global:HPECOMRegions global variable and create completions
                $Global:HPECOMRegions.region | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [String]$Region,  
        
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = "serialnumber")] 
        [Alias('serial', 'serialnumber')]
        [String]$ServerSerialNumber,

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [String]$GroupName,
        
        [Parameter(ParameterSetName = "All")]
        [Switch]$All,

        [Switch]$ResetBios,

        [Switch]$WhatIf
    ) 

    Begin {

        
        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $ObjectStatusList = [System.Collections.ArrayList]::new()
        $DevicesList = [System.Collections.ArrayList]::new()
        $DevicesTrackingList = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            SerialNumber = $Null
            Region       = $Region                            
            Group        = $GroupName                   
            Status       = $Null
            Details      = $Null
            Exception    = $Null
        }

        if ($ServerSerialNumber) {

            $objStatus.SerialNumber = $ServerSerialNumber
        }

       

        [void] $ObjectStatusList.add($objStatus)

    }

    end {

        try {
            $Group = Get-HPECOMGroup -Region $Region -Name $GroupName
            $GroupMembers = $Group.devices 

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        if ( -not $Group) {

            $ErrorMessage = "Group '{0}': Resource cannot be found in the '{1}' region!" -f $GroupName, $Region

            if ($WhatIf) {
                Write-Warning $ErrorMessage
                return
            }

            foreach ($Object in $ObjectStatusList) {
                $Object.Status = "Failed"
                $Object.Details = $ErrorMessage
            }

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "COM.Groups.SGSDE"
            return $ObjectStatusList

        }

        
        If (-not $All) {
        
            try {
        
                $Servers = Get-HPECOMServer -Region $Region
                    
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)                
            }
                
            "[{0}] List of servers to remove from group: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList.SerialNumber | out-string) | Write-Verbose
        

            foreach ($Object in $ObjectStatusList) {
                
                "[{0}] Checking server '{1}' " -f $MyInvocation.InvocationName.ToString().ToUpper(), $Object.SerialNumber | Write-Verbose

                $Server = $Servers | Where-Object serialNumber -eq $Object.SerialNumber

                if ( -not $Server) {

                    if ($WhatIf) {
                        $ErrorMessage = "Server '{0}': Resource cannot be found in the '{1}' region!" -f $Object.SerialNumber, $Region
                        Write-warning $ErrorMessage
                        continue
                    }

                    # Must return a message if device not found
                    $Object.Status = "Failed"
                    $Object.Details = "Server cannot be found in the region!"
                    
                } 
                elseif (-not ( $GroupMembers | Where-Object serial -eq $Object.SerialNumber)) { 

                    if ($WhatIf) {
                        $ErrorMessage = "Server '{0}': Resource is not a member of the '{1}' group!" -f $Object.SerialNumber, $GroupName
                        Write-warning $ErrorMessage
                        continue
                    }

                    # Must return a message if server not member of the group
                    $Object.Status = "Warning"
                    $Object.Details = "Server is not a member of the group!"
                    
                }
                else {    

                    "[{0}] Server '{1}' is a member of the group '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Object.SerialNumber, $GroupName | Write-Verbose
                    
                    # Build DeviceList object for paylaod
                    $DeviceList = [PSCustomObject]@{
                        deviceId = $server.id
                        
                    }
                    
                    # Build DeviceInfo object for tracking
                    $DeviceInfo = [PSCustomObject]@{
                        serialnumber = $server.serialNumber
                        
                    }
                    
                    # Building the list of devices object for payload
                    [void]$DevicesList.Add($DeviceList)
                    
                    # Building the list of devices object for tracking
                    [void]$DevicesTrackingList.Add($DeviceInfo)
                    
                }
            }
        }
        elseif ($all -and -not $GroupMembers) {

            "[{0}] Tracking object: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList | out-string) | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "Group '{0}': No servers are member of the group!" -f $GroupName
                Write-warning $ErrorMessage
            }
            else {
                # Must return a message if no servers are member of the group when all is used
                $ObjectStatusList[0].SerialNumber = "[All]"
                $ObjectStatusList[0].Status = "Warning"
                $ObjectStatusList[0].Details = "No servers are member of the group!"
            }
        }

        
       
      

        if ($DevicesList) {

            if ($ResetBios) {

                $Uri = (Get-COMGroupsUri) + "/" + $Group.ID + "/devices/unassign" + "?reset-subsystems=BIOS"

            }
            else {
                
                $Uri = (Get-COMGroupsUri) + "/" + $Group.ID + "/devices/unassign" 
            
            }

            # Build payload
            $payload = ConvertTo-Json -Depth 10 @{
                devices = $DevicesList
            } 

            # Remove Devices from group  
            try {

                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -Body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                
                if (-not $WhatIf) {
                   
                    foreach ($Object in $ObjectStatusList) {

                        $DeviceSet = $DevicesTrackingList | Where-Object serialnumber -eq $Object.SerialNumber

                        If ($DeviceSet) {
                            
                            $Object.Status = "Complete"
                            $Object.Details = "Server successfully removed from '$groupname' group in '$Region' region"

                        }
                    }
                }
            }
            catch {
                
                if (-not $WhatIf) {

                    foreach ($Object in $ObjectStatusList) {

                        $DeviceSet = $DevicesTrackingList | Where-Object serialnumber -eq $Object.SerialNumber

                        If ($DeviceSet) {
                            
                            $Object.Status = "Failed"
                            $Object.Details = "Server cannot be removed from '$groupname' group!"
                            $Object.Exception = $_.Exception.message 

                        }
                    }
                }
            }
        }

        elseif ($All -and $_group.devices) {

            if ($ResetBios) {

                $Uri = (Get-COMGroupsUri) + "/" + $Group.ID + "/devices/unassign" + "?force=true&reset-subsystems=BIOS"
                
            }
            else {
                
                $Uri = (Get-COMGroupsUri) + "/" + $Group.ID + "/devices/unassign" + "?force=true"

            }

            # Remove all devices from group  
            try {

                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                
                if (-not $WhatIf) {
                    
                    $ObjectStatusList[0].SerialNumber = "[All]"
                    $ObjectStatusList[0].Status = "Complete"
                    $ObjectStatusList[0].Details = "All servers successfully removed from '$groupname' group in '$Region' region"
                }                    
            }
            catch {
                
                if (-not $WhatIf) {
                    
                    $ObjectStatusList[0].SerialNumber = "[All]"
                    $ObjectStatusList[0].Status = "Failed"
                    $ObjectStatusList[0].Details = "Servers cannot be removed from '$groupname' group!"
                    $ObjectStatusList[0].Exception = $_.Exception.message 
                }
            }
        }


        if (-not $WhatIf) {

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "COM.Groups.SGSDE"
            Return $ObjectStatusList
        }
    }
}


# Private functions (not exported)
function New-ErrorRecord {
    <#
        .Synopsis
        Creates an custom ErrorRecord that can be used to report a terminating or non-terminating error.

        .Description
        Creates an custom ErrorRecord that can be used to report a terminating or non-terminating error.

        .Parameter Exception
        The Exception that will be associated with the ErrorRecord. Uses RuntimeException by default.

        .Parameter ErrorID
        A scripter-defined identifier of the error. This identifier must be a non-localized string for a specific error type.

        .Parameter ErrorCategory
        An ErrorCategory enumeration that defines the category of the error.  The supported Category Members are (from: http://msdn.microsoft.com/en-us/library/system.management.automation.errorcategory(v=vs.85).aspx) :

            * AuthenticationError - An error that occurs when the user cannot be authenticated by the service. This could mean that the credentials are invalid or that the authentication system is not functioning properly.
            * CloseError - An error that occurs during closing.
            * ConnectionError - An error that occurs when a network connection that the operation depEnds on cannot be established or maintained.
            * DeadlockDetected - An error that occurs when a deadlock is detected.
            * DeviceError - An error that occurs when a device reports an error.
            * FromStdErr - An error that occurs when a non-Windows PowerShell command reports an error to its STDERR pipe.
            * InvalidArgument - An error that occurs when an argument that is not valid is specified.
            * InvalidData - An error that occurs when data that is not valid is specified.
            * InvalidOperation - An error that occurs when an operation that is not valid is requested.
            * InvalidResult - An error that occurs when a result that is not valid is returned.
            * InvalidType - An error that occurs when a .NET Framework type that is not valid is specified.
            * LimitsExceeded - An error that occurs when internal limits prevent the operation from being executed.
            * MetadataError - An error that occurs when metadata contains an error.
            * NotEnabled - An error that occurs when the operation attempts to use functionality that is currently disabled.
            * NotImplemented - An error that occurs when a referenced application programming interface (API) is not implemented.
            * NotInstalled - An error that occurs when an item is not installed.
            * NotSpecified - An unspecified error. Use only when not enough is known about the error to assign it to another error category. Avoid using this category if you have any information about the error, even if that information is incomplete.
            * ObjectNotFound - An error that occurs when an object cannot be found.
            * OpenError - An error that occurs during opening.
            * OperationStopped - An error that occurs when an operation has stopped. For example, the user interrupts the operation.
            * OperationTimeout - An error that occurs when an operation has exceeded its timeout limit.
            * ParserError - An error that occurs when a parser encounters an error.
            * PermissionDenied - An error that occurs when an operation is not permitted.
            * ProtocolError An error that occurs when the contract of a protocol is not being followed. This error should not happen with well-behaved components.
            * QuotaExceeded An error that occurs when controls on the use of traffic or resources prevent the operation from being executed.
            * ReadError An error that occurs during reading.
            * ResourceBusy An error that occurs when a resource is busy.
            * ResourceExists An error that occurs when a resource already exists.
            * ResourceUnavailable An error that occurs when a resource is unavailable.
            * SecurityError An error that occurs when a security violation occurs. This field is introduced in Windows PowerShell 2.0.
            * SyntaxError An error that occurs when a command is syntactically incorrect.
            * WriteError An error that occurs during writing.

        .Parameter TargetObject
        The object that was being Processed when the error took place.

        .Parameter Message
        Describes the Exception to the user.

        .Parameter InnerException
        The Exception instance that caused the Exception association with the ErrorRecord.

        .Parameter TargetType
        To customize the TargetType value, specify the appropriate Target object type.  Values can be "Array", "PSObject", "HashTable", etc.  Can be provided by ${ParameterName}.GetType().Name.

        .Example
        $errorMessage = "Timeout reached waiting for job to complete."
        $errorRecord = New-ErrorRecord TimeoutError OperationTimeout -Message $ErrorMessage
        $PSCmdlet.ThrowTerminatingError($ErrorRecord )

        .EXAMPLE
        $ErrorMessage = "Filter '{0}' cannot be found in the Compute Ops Management instance!" -f $Name
        $ErrorRecord = New-ErrorRecord FilterNotFoundInCOM ObjectNotFound -TargetObject 'Filter' -Message $ErrorMessage -TargetType $Name.GetType().Name
        $PSCmdlet.ThrowTerminatingError($ErrorRecord )

    #>

    [CmdletBinding ()]
    Param
    (        
        
        [Parameter (Mandatory, Position = 0)]
        [Alias ('ID')]
        [System.String]$ErrorId,
        
        [Parameter (Mandatory, Position = 1)]
        [Alias ('Category')]
        [ValidateSet ('AuthenticationError', 'ConnectionError', 'NotSpecified', 'OpenError', 'CloseError', 'DeviceError',
            'DeadlockDetected', 'InvalidArgument', 'InvalidData', 'InvalidOperation',
            'InvalidResult', 'InvalidType', 'MetadataError', 'NotImplemented',
            'NotInstalled', 'ObjectNotFound', 'OperationStopped', 'OperationTimeout',
            'SyntaxError', 'ParserError', 'PermissionDenied', 'ResourceBusy',
            'ResourceExists', 'ResourceUnavailable', 'ReadError', 'WriteError',
            'FromStdErr', 'SecurityError')]
        [System.Management.Automation.ErrorCategory]$ErrorCategory,
            
        [Parameter (Position = 2)]
        [System.Object]$TargetObject,
            
        [System.String]$Exception = "System.Management.Automation.RuntimeException",
        
        # [Parameter (Mandatory)]
        [System.String]$Message,
        
        [System.Exception]$InnerException,
        
        [System.String]$TargetType = "String"

    )

    Process {

        # ...build and save the new Exception depending on present arguments, if it...
        $_exception = if ($Message -and $InnerException) {
            # ...includes a custom message and an inner exception
            New-Object $Exception $Message, $InnerException
        }
        elseif ($Message) {
            # ...includes a custom message only
            New-Object $Exception $Message
        }
        else {
            # ...is just the exception full name
            New-Object $Exception
        }

        # now build and output the new ErrorRecord
        "[{0}] Building ErrorRecord object" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

        $record = [Management.Automation.ErrorRecord]::new($_exception, $ErrorID, $ErrorCategory, $TargetObject)

        $record.CategoryInfo.TargetType = $TargetType

        Return $record
    }
}

function Invoke-RepackageObjectWithType {   
    Param   (   
        $RawObject,
        $ObjectName,
        [boolean]   $WhatIf = $false
    )
    process {
        if ( $RawObject ) {
            $OutputObject = @()
            if ( $WhatIf ) {
                Return 
            }
            foreach ( $RawElementObject in $RawObject ) {

                # "[{0}] Element: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($RawElementObject | out-string) | write-verbose

                $DataSetType = "HPEGreenLake.$ObjectName"
                $RawElementObject.PSTypeNames.Insert(0, $DataSetType)
                # "[{0}] Element PSTypeName set: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($RawElementObject.PSTypeNames[0] | out-string)| write-verbose
                # "[{0}] Element PSObject TypeNames set: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($RawElementObject.PSObject.TypeNames[0] | out-string)| write-verbose
                
                $RawElementObject.PSObject.TypeNames.Insert(0, $DataSetType)
                # "[{0}] Element PSObject TypeNames set: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($RawElementObject.PSObject.TypeNames[0] | out-string)| write-verbose

                $OutputObject += $RawElementObject
            }

            # "[{0}] Object typenames : `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($OutputObject.PSObject.TypeNames | Out-String) | write-verbose

            if ($OutputObject.PSObject.TypeNames -notcontains $DataSetType) {

                # "[{0}] Object typenames added using Add-Member as the object is read only" -f $MyInvocation.InvocationName.ToString().ToUpper() | write-verbose

                foreach ($item in $OutputObject) {
                    [void]($item | Add-Member -MemberType NoteProperty -Name PSObject.TypeNames -Value @( $DataSetType) -Force)
                }
            }

            return $OutputObject
        }
        else {
 
            # "[{0}] Null value sent to create object type." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            
            return
        }
    }   
}


# Export only public functions and aliases
Export-ModuleMember -Function 'Get-HPECOMGroup', 'New-HPECOMGroup', 'Remove-HPECOMGroup', 'Set-HPECOMGroup', 'Add-HPECOMServerToGroup', 'Remove-HPECOMServerFromGroup' -Alias *

# SIG # Begin signature block
# MIItTgYJKoZIhvcNAQcCoIItPzCCLTsCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBGzASqcqfFryox
# IWMsxzs68ksq2QkIyQilwVk9LsGvTKCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
# jTanyYqJ1pQWMA0GCSqGSIb3DQEBDAUAMHsxCzAJBgNVBAYTAkdCMRswGQYDVQQI
# DBJHcmVhdGVyIE1hbmNoZXN0ZXIxEDAOBgNVBAcMB1NhbGZvcmQxGjAYBgNVBAoM
# EUNvbW9kbyBDQSBMaW1pdGVkMSEwHwYDVQQDDBhBQUEgQ2VydGlmaWNhdGUgU2Vy
# dmljZXMwHhcNMjEwNTI1MDAwMDAwWhcNMjgxMjMxMjM1OTU5WjBWMQswCQYDVQQG
# EwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMS0wKwYDVQQDEyRTZWN0aWdv
# IFB1YmxpYyBDb2RlIFNpZ25pbmcgUm9vdCBSNDYwggIiMA0GCSqGSIb3DQEBAQUA
# A4ICDwAwggIKAoICAQCN55QSIgQkdC7/FiMCkoq2rjaFrEfUI5ErPtx94jGgUW+s
# hJHjUoq14pbe0IdjJImK/+8Skzt9u7aKvb0Ffyeba2XTpQxpsbxJOZrxbW6q5KCD
# J9qaDStQ6Utbs7hkNqR+Sj2pcaths3OzPAsM79szV+W+NDfjlxtd/R8SPYIDdub7
# P2bSlDFp+m2zNKzBenjcklDyZMeqLQSrw2rq4C+np9xu1+j/2iGrQL+57g2extme
# me/G3h+pDHazJyCh1rr9gOcB0u/rgimVcI3/uxXP/tEPNqIuTzKQdEZrRzUTdwUz
# T2MuuC3hv2WnBGsY2HH6zAjybYmZELGt2z4s5KoYsMYHAXVn3m3pY2MeNn9pib6q
# RT5uWl+PoVvLnTCGMOgDs0DGDQ84zWeoU4j6uDBl+m/H5x2xg3RpPqzEaDux5mcz
# mrYI4IAFSEDu9oJkRqj1c7AGlfJsZZ+/VVscnFcax3hGfHCqlBuCF6yH6bbJDoEc
# QNYWFyn8XJwYK+pF9e+91WdPKF4F7pBMeufG9ND8+s0+MkYTIDaKBOq3qgdGnA2T
# OglmmVhcKaO5DKYwODzQRjY1fJy67sPV+Qp2+n4FG0DKkjXp1XrRtX8ArqmQqsV/
# AZwQsRb8zG4Y3G9i/qZQp7h7uJ0VP/4gDHXIIloTlRmQAOka1cKG8eOO7F/05QID
# AQABo4IBEjCCAQ4wHwYDVR0jBBgwFoAUoBEKIz6W8Qfs4q8p74Klf9AwpLQwHQYD
# VR0OBBYEFDLrkpr/NZZILyhAQnAgNpFcF4XmMA4GA1UdDwEB/wQEAwIBhjAPBgNV
# HRMBAf8EBTADAQH/MBMGA1UdJQQMMAoGCCsGAQUFBwMDMBsGA1UdIAQUMBIwBgYE
# VR0gADAIBgZngQwBBAEwQwYDVR0fBDwwOjA4oDagNIYyaHR0cDovL2NybC5jb21v
# ZG9jYS5jb20vQUFBQ2VydGlmaWNhdGVTZXJ2aWNlcy5jcmwwNAYIKwYBBQUHAQEE
# KDAmMCQGCCsGAQUFBzABhhhodHRwOi8vb2NzcC5jb21vZG9jYS5jb20wDQYJKoZI
# hvcNAQEMBQADggEBABK/oe+LdJqYRLhpRrWrJAoMpIpnuDqBv0WKfVIHqI0fTiGF
# OaNrXi0ghr8QuK55O1PNtPvYRL4G2VxjZ9RAFodEhnIq1jIV9RKDwvnhXRFAZ/ZC
# J3LFI+ICOBpMIOLbAffNRk8monxmwFE2tokCVMf8WPtsAO7+mKYulaEMUykfb9gZ
# pk+e96wJ6l2CxouvgKe9gUhShDHaMuwV5KZMPWw5c9QLhTkg4IUaaOGnSDip0TYl
# d8GNGRbFiExmfS9jzpjoad+sPKhdnckcW67Y8y90z7h+9teDnRGWYpquRRPaf9xH
# +9/DUp/mBlXpnYzyOmJRvOwkDynUWICE5EV7WtgwggYaMIIEAqADAgECAhBiHW0M
# UgGeO5B5FSCJIRwKMA0GCSqGSIb3DQEBDAUAMFYxCzAJBgNVBAYTAkdCMRgwFgYD
# VQQKEw9TZWN0aWdvIExpbWl0ZWQxLTArBgNVBAMTJFNlY3RpZ28gUHVibGljIENv
# ZGUgU2lnbmluZyBSb290IFI0NjAeFw0yMTAzMjIwMDAwMDBaFw0zNjAzMjEyMzU5
# NTlaMFQxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxKzAp
# BgNVBAMTIlNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBDQSBSMzYwggGiMA0G
# CSqGSIb3DQEBAQUAA4IBjwAwggGKAoIBgQCbK51T+jU/jmAGQ2rAz/V/9shTUxjI
# ztNsfvxYB5UXeWUzCxEeAEZGbEN4QMgCsJLZUKhWThj/yPqy0iSZhXkZ6Pg2A2NV
# DgFigOMYzB2OKhdqfWGVoYW3haT29PSTahYkwmMv0b/83nbeECbiMXhSOtbam+/3
# 6F09fy1tsB8je/RV0mIk8XL/tfCK6cPuYHE215wzrK0h1SWHTxPbPuYkRdkP05Zw
# mRmTnAO5/arnY83jeNzhP06ShdnRqtZlV59+8yv+KIhE5ILMqgOZYAENHNX9SJDm
# +qxp4VqpB3MV/h53yl41aHU5pledi9lCBbH9JeIkNFICiVHNkRmq4TpxtwfvjsUe
# dyz8rNyfQJy/aOs5b4s+ac7IH60B+Ja7TVM+EKv1WuTGwcLmoU3FpOFMbmPj8pz4
# 4MPZ1f9+YEQIQty/NQd/2yGgW+ufflcZ/ZE9o1M7a5Jnqf2i2/uMSWymR8r2oQBM
# dlyh2n5HirY4jKnFH/9gRvd+QOfdRrJZb1sCAwEAAaOCAWQwggFgMB8GA1UdIwQY
# MBaAFDLrkpr/NZZILyhAQnAgNpFcF4XmMB0GA1UdDgQWBBQPKssghyi47G9IritU
# pimqF6TNDDAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADATBgNV
# HSUEDDAKBggrBgEFBQcDAzAbBgNVHSAEFDASMAYGBFUdIAAwCAYGZ4EMAQQBMEsG
# A1UdHwREMEIwQKA+oDyGOmh0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1
# YmxpY0NvZGVTaWduaW5nUm9vdFI0Ni5jcmwwewYIKwYBBQUHAQEEbzBtMEYGCCsG
# AQUFBzAChjpodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2Rl
# U2lnbmluZ1Jvb3RSNDYucDdjMCMGCCsGAQUFBzABhhdodHRwOi8vb2NzcC5zZWN0
# aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOCAgEABv+C4XdjNm57oRUgmxP/BP6YdURh
# w1aVcdGRP4Wh60BAscjW4HL9hcpkOTz5jUug2oeunbYAowbFC2AKK+cMcXIBD0Zd
# OaWTsyNyBBsMLHqafvIhrCymlaS98+QpoBCyKppP0OcxYEdU0hpsaqBBIZOtBajj
# cw5+w/KeFvPYfLF/ldYpmlG+vd0xqlqd099iChnyIMvY5HexjO2AmtsbpVn0OhNc
# WbWDRF/3sBp6fWXhz7DcML4iTAWS+MVXeNLj1lJziVKEoroGs9Mlizg0bUMbOalO
# hOfCipnx8CaLZeVme5yELg09Jlo8BMe80jO37PU8ejfkP9/uPak7VLwELKxAMcJs
# zkyeiaerlphwoKx1uHRzNyE6bxuSKcutisqmKL5OTunAvtONEoteSiabkPVSZ2z7
# 6mKnzAfZxCl/3dq3dUNw4rg3sTCggkHSRqTqlLMS7gjrhTqBmzu1L90Y1KWN/Y5J
# KdGvspbOrTfOXyXvmPL6E52z1NZJ6ctuMFBQZH3pwWvqURR8AgQdULUvrxjUYbHH
# j95Ejza63zdrEcxWLDX6xWls/GDnVNueKjWUH3fTv1Y8Wdho698YADR7TNx8X8z2
# Bev6SivBBOHY+uqiirZtg0y9ShQoPzmCcn63Syatatvx157YK9hlcPmVoa1oDE5/
# L9Uo2bC5a4CH2RwwggZhMIIEyaADAgECAhEAyDHh+zCQwUNyJV9S6gqqvTANBgkq
# hkiG9w0BAQwFADBUMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1p
# dGVkMSswKQYDVQQDEyJTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2
# MB4XDTI1MDUyMDAwMDAwMFoXDTI4MDUxOTIzNTk1OVowdzELMAkGA1UEBhMCVVMx
# DjAMBgNVBAgMBVRleGFzMSswKQYDVQQKDCJIZXdsZXR0IFBhY2thcmQgRW50ZXJw
# cmlzZSBDb21wYW55MSswKQYDVQQDDCJIZXdsZXR0IFBhY2thcmQgRW50ZXJwcmlz
# ZSBDb21wYW55MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA37AD03qw
# cmuCQyxRB2VBM7SfUf0SmpQb8iaPvGmxw5uoDBY3gdC/3Xq/rfM3ndCn03hNdGyu
# cpC7tD4zmel6yYqxyXDVr45Jd2cz9jFXoYTOMcuDV6I6CvU/EnbFxWhv0VCp+2Ip
# z4+uJGI6aVlMpFpLbgPjhp9ogd/89HEyi1FkSFoarnvxxaXm93S81k7FD/4Edtvu
# muGI4V8p39GfbCiMuHku8BzSQ2g86gWFnOaVhY6h4XWvEmE8LPYkU/STrej28Flg
# kSt9f/Jg6+dvRKm92uN2Z760Eql9+DTWkGmGe4YrIyD25XDa07sS9tIpVWzLrGOy
# ecaVpJwVVBqCadXDgkgTYKw/UlS+cEqsviT6wREGl4aX/GbeNO6Y4oDTTYkabW3p
# eg1ku0v90oDqzoTaWEE5ly2UajvXIgzpFLLXqpR6GYkv/y3ZJV0chBqRtAObebH7
# XOBa5a2kqMBw0gkIZBJHd8+PCPH/U7eJkeKXtGGj2uTudcGjZgOjVcFYdCRnufJd
# isrV7bj0Hzghcv3QyRXL3rRjcNb4ccKNnSgF/8cmiTVpvFHTfUKsYdkbM6wsbjXR
# dJNADjGOYRms7tKsii3/oXO+2S1Um7yomBZQ2+wVRCY6MrRX1onDKid5t5AyWFtR
# u0aQcdBmHG6JeDiQ3Hrb2g9kZhuFkgABVBkCAwEAAaOCAYkwggGFMB8GA1UdIwQY
# MBaAFA8qyyCHKLjsb0iuK1SmKaoXpM0MMB0GA1UdDgQWBBQH4rUE0gsy8LW2G3vm
# oYtOnZ8zEjAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAK
# BggrBgEFBQcDAzBKBgNVHSAEQzBBMDUGDCsGAQQBsjEBAgEDAjAlMCMGCCsGAQUF
# BwIBFhdodHRwczovL3NlY3RpZ28uY29tL0NQUzAIBgZngQwBBAEwSQYDVR0fBEIw
# QDA+oDygOoY4aHR0cDovL2NybC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljQ29k
# ZVNpZ25pbmdDQVIzNi5jcmwweQYIKwYBBQUHAQEEbTBrMEQGCCsGAQUFBzAChjho
# dHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmluZ0NB
# UjM2LmNydDAjBggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wDQYJ
# KoZIhvcNAQEMBQADggGBAIax+Yaj5EciDlztft4iAfD2CtIWEF0cxR+UbbvJEs86
# 5wyoO3ZQoujr0FJ+P5fjDKLbamHrEWmyoD2YC4lzecmnFOnY0y4uJ9zBY8B6X6TU
# 9e6+TfZtlXd44YffXYAfoLX+uYjVJcZOaMuXF61+CFpjLJjepsD8m1gdj5QUz2sH
# 6GOfU6mEm8SHvKpgPMV/yhEKqgjlenY6Ao49RkxnDuvRlMP8SFPB+8bxiLegEdGa
# ei8nSr/j5YeDZFevUJ696T4W45QGrwAhBBpbKDz6CzlImC1b2C8Bp02XBAsOQs/u
# CIaQv5XxUmVxmb85tDJkd7QfqHo2z1T2NYMkvXUcSClYRuVxxC/frpqcrxS9O9xE
# v65BoUztAJSXsTdfpUjWeNOnhq8lrwa2XAD3fbagNF6ElsBiNDSbwHCG/iY4kAya
# VpbAYtaa6TfzdI/I0EaCX5xYRW56ccI2AnbaEVKz9gVjzi8hBLALlRhrs1uMFtPj
# nZ+oA+rbZZyGZkz3xbUYKTGCGq4wghqqAgEBMGkwVDELMAkGA1UEBhMCR0IxGDAW
# BgNVBAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMg
# Q29kZSBTaWduaW5nIENBIFIzNgIRAMgx4fswkMFDciVfUuoKqr0wDQYJYIZIAWUD
# BAIBBQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGC
# NwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQx
# IgQgavLBdUkUwklU3XnscxuB8XcAJXx8SsJ1hsL9W8XLe+UwDQYJKoZIhvcNAQEB
# BQAEggIAYnlFSj/bEkyPE3PV2GLYSDtwFsQYzQna13u82k0WtOUhwal7dhpvPQAf
# /4+fjQy1zp/FAAs059bAUtyGehCqj6qxNegdor4v0tDsCd8n3bOUl34s/UlsqRTH
# tKiZDM6UAxQr9QcTkmXxZt2Y5Yt/N2zfdenGeS64MjZ4GxG+OYkCBlqQBjofuCPX
# 9j4ijyJCZXrAmYgRR5btqlgp+VeVaMgfeE/cDbVf0kh3SthhGWBMUVXkndJPi0WP
# elvolshQBwdPQNHEp5raKc6D0hkgH5Xi/Jk4tv00wEK58LBYo03EcavVqm4BBFZs
# mxd82OMWav6eBPFZcY+Kf9G3pmnagXB5aQ3sVqYgPt29dvXVdYH4DoX9JMCbzMvM
# HEhKnkk7FN5TgfK3Kr+mksp2Sir/Lq47TLkClE6J8ZZFm/GT2A/n3vS+s+QTh7+X
# fZE10/fq68kQcjmCUE4APerwOdpS/SJTiXnjq6UYB8IXqLDUTExcX4iSJn6I+QKc
# ob1FsK/EB5BC+IXUu1LNmhOXqz0oEcveKle+thuNDVS+QfUFudrq3agYZ5PpW+Yj
# NrtszlKal7yMq23qlr42FWH3dHzlUO9mRmkWy4QKFfi/3o//gApRHYl5JVsLopZk
# 0HNHUsnSZX4Y9uwsdOoyPeQNQzwKKStOI4LOWrCEjXm1dedC1sahgheYMIIXlAYK
# KwYBBAGCNwMDATGCF4QwgheABgkqhkiG9w0BBwKgghdxMIIXbQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIGIBgsqhkiG9w0BCRABBKB5BHcwdQIBAQYJYIZIAYb9bAcBMEEw
# DQYJYIZIAWUDBAICBQAEMC2v5Zto9LWfRsvbUKyTwgeoCbf/ddUObeobeEW5xXU8
# 8yvTpEiqDLaHrxwSzOSUAgIRAI2KQ4Dw6qmJ3W5BMaBNEmMYDzIwMjYwMTE5MTgx
# ODA5WqCCEzowggbtMIIE1aADAgECAhAMIENJ+dD3WfuYLeQIG4h7MA0GCSqGSIb3
# DQEBDAUAMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFB
# MD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5
# NiBTSEEyNTYgMjAyNSBDQTEwHhcNMjUwNjA0MDAwMDAwWhcNMzYwOTAzMjM1OTU5
# WjBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNV
# BAMTMkRpZ2lDZXJ0IFNIQTM4NCBSU0E0MDk2IFRpbWVzdGFtcCBSZXNwb25kZXIg
# MjAyNSAxMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA2zlS+4t0t+XJ
# DVHY+vNJxpv794sM3O4UQycmKRXmYLs+YRfztyl8QJ7n/UqxNTKWmjdFDWGv43+a
# 2oiJ41yxOe0sLoFx8F1az2JRTZc7dhAxbne+byd5bf2SEZlCruGxxWSqbpUY6dAG
# RCCyBOaiFaoXhkn+L15efcomDSrTnA5Vgd9pvMO+7bM+tSW4JzAiIbO2mIPyCEdK
# YscmPl+YBuenSP7NJw9icL1tWpn61uM6WyUNv4RcyBAz+NvJbNf5kTM7F46cvBwp
# 0lZYisZR985y5sYj4e4yUBbPBxyrT5aNMZ++5tis8GDmHCpqyVLQ4eLHwpim5iwR
# 49TREfETtlEFORWTkJ2hOO1zzVAWs6jtdep12VtFZoQOhIwdUfPHSsAw39xFVevF
# EFf2u+DVr1sOV7JACY+xcG8hWIeqPGVUwkiyBRUTgA7HeAxJb0iQl4GDBC6ZBA4w
# GN/ahMxF4fuJsOs1zwkPBSnXmHkm18HwHgIPKk287dMIchZyjm7zGcCYZ4bisoUY
# WL9oTga9JCfFMTc9yl26XDB0zl9rdSwviOmaYSlaRanF84oxAYnqgBy6Z89ykPgW
# nb7SRi31NyP359Whok+36fkyxTPjSrCWvMK7pzbRg8tfIRlUnxl7G5bIrkPqMbD9
# zJoB79MHFgLr5ljU7rrcLwy+cEfpzFMCAwEAAaOCAZUwggGRMAwGA1UdEwEB/wQC
# MAAwHQYDVR0OBBYEFFWeuednyJEQSbQ2Uo15tyTFPy34MB8GA1UdIwQYMBaAFO9v
# U0rp5AZ8esrikFb2L9RJ7MtOMA4GA1UdDwEB/wQEAwIHgDAWBgNVHSUBAf8EDDAK
# BggrBgEFBQcDCDCBlQYIKwYBBQUHAQEEgYgwgYUwJAYIKwYBBQUHMAGGGGh0dHA6
# Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBdBggrBgEFBQcwAoZRaHR0cDovL2NhY2VydHMu
# ZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGltZVN0YW1waW5nUlNBNDA5
# NlNIQTI1NjIwMjVDQTEuY3J0MF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly9jcmwz
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFRpbWVTdGFtcGluZ1JTQTQw
# OTZTSEEyNTYyMDI1Q0ExLmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgB
# hv1sBwEwDQYJKoZIhvcNAQEMBQADggIBABt+CySH2AlqxUHnUWnZJI7rpdAqo0Pc
# ikyV48Ltk5QWFgxpHP9WtjR3lskEAOk3TszmuNyMid7VuxHlQJl4KcdTr5cQ2YLy
# +l560peBgM7kA4HCJqGqdQdzjXyrlg3YCdfnjs9w/7BO8xUmlAaq/D+PTZZO+Mnx
# a3/IoyYsF+L9gWX4VJxZLljVs5JKmpSonnysMYv7CaqkQpBDmJWU2F68mLLZXfU0
# wXbDy9QQTskgcHviyQDeB1l6jl/WwOQiSNTNafYQUR2ZsJ5rPJu1NPzO1htKwdiU
# jWenHwq5BRK1BR7+D+TwG97UHX4V0W+JvFZp8z3d3G5sA7Pt9qO5/6AWZ+0yf8nN
# 58D+HAAShHmny25t6W7qF6VSRZCIpGr8hbAjfbBhO4MY8G2U9zwVKp6SljuKknxd
# 2buihO33dioCGsB6trX++xQKf4QlYSggFvD9ZWSG4ysJPYOx+hbsBTEONFtr99x6
# OgJnnyVkDoudIn+gmV+Bq+a2G++BLU5AXOVclExpuoUQXUZF5p3sUrd21QjF9Ra0
# x4RD02gS4XwgzN+tvuY+tjhPICwXmH3ERL+fPIoxZT0XgwVP+17UqUbi5Zpe4Yda
# dG5WjCTBvtmlM4JVovGYRvyAyfmYJJx0/0T+qK05wRJpg4q81vOKuCQPaE9H99JC
# VvfCDBm4KjrEMIIGtDCCBJygAwIBAgIQDcesVwX/IZkuQEMiDDpJhjANBgkqhkiG
# 9w0BAQsFADBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkw
# FwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVz
# dGVkIFJvb3QgRzQwHhcNMjUwNTA3MDAwMDAwWhcNMzgwMTE0MjM1OTU5WjBpMQsw
# CQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERp
# Z2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIw
# MjUgQ0ExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAtHgx0wqYQXK+
# PEbAHKx126NGaHS0URedTa2NDZS1mZaDLFTtQ2oRjzUXMmxCqvkbsDpz4aH+qbxe
# Lho8I6jY3xL1IusLopuW2qftJYJaDNs1+JH7Z+QdSKWM06qchUP+AbdJgMQB3h2D
# Z0Mal5kYp77jYMVQXSZH++0trj6Ao+xh/AS7sQRuQL37QXbDhAktVJMQbzIBHYJB
# YgzWIjk8eDrYhXDEpKk7RdoX0M980EpLtlrNyHw0Xm+nt5pnYJU3Gmq6bNMI1I7G
# b5IBZK4ivbVCiZv7PNBYqHEpNVWC2ZQ8BbfnFRQVESYOszFI2Wv82wnJRfN20VRS
# 3hpLgIR4hjzL0hpoYGk81coWJ+KdPvMvaB0WkE/2qHxJ0ucS638ZxqU14lDnki7C
# coKCz6eum5A19WZQHkqUJfdkDjHkccpL6uoG8pbF0LJAQQZxst7VvwDDjAmSFTUm
# s+wV/FbWBqi7fTJnjq3hj0XbQcd8hjj/q8d6ylgxCZSKi17yVp2NL+cnT6Toy+rN
# +nM8M7LnLqCrO2JP3oW//1sfuZDKiDEb1AQ8es9Xr/u6bDTnYCTKIsDq1BtmXUqE
# G1NqzJKS4kOmxkYp2WyODi7vQTCBZtVFJfVZ3j7OgWmnhFr4yUozZtqgPrHRVHhG
# NKlYzyjlroPxul+bgIspzOwbtmsgY1MCAwEAAaOCAV0wggFZMBIGA1UdEwEB/wQI
# MAYBAf8CAQAwHQYDVR0OBBYEFO9vU0rp5AZ8esrikFb2L9RJ7MtOMB8GA1UdIwQY
# MBaAFOzX44LScV1kTN8uZz/nupiuHA9PMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUE
# DDAKBggrBgEFBQcDCDB3BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6
# Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMu
# ZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYDVR0fBDww
# OjA4oDagNIYyaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3Rl
# ZFJvb3RHNC5jcmwwIAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMA0G
# CSqGSIb3DQEBCwUAA4ICAQAXzvsWgBz+Bz0RdnEwvb4LyLU0pn/N0IfFiBowf0/D
# m1wGc/Do7oVMY2mhXZXjDNJQa8j00DNqhCT3t+s8G0iP5kvN2n7Jd2E4/iEIUBO4
# 1P5F448rSYJ59Ib61eoalhnd6ywFLerycvZTAz40y8S4F3/a+Z1jEMK/DMm/axFS
# goR8n6c3nuZB9BfBwAQYK9FHaoq2e26MHvVY9gCDA/JYsq7pGdogP8HRtrYfctSL
# ANEBfHU16r3J05qX3kId+ZOczgj5kjatVB+NdADVZKON/gnZruMvNYY2o1f4MXRJ
# DMdTSlOLh0HCn2cQLwQCqjFbqrXuvTPSegOOzr4EWj7PtspIHBldNE2K9i697cva
# iIo2p61Ed2p8xMJb82Yosn0z4y25xUbI7GIN/TpVfHIqQ6Ku/qjTY6hc3hsXMrS+
# U0yy+GWqAXam4ToWd2UQ1KYT70kZjE4YtL8Pbzg0c1ugMZyZZd/BdHLiRu7hAWE6
# bTEm4XYRkA6Tl4KSFLFk43esaUeqGkH/wyW4N7OigizwJWeukcyIPbAvjSabnf7+
# Pu0VrFgoiovRDiyx3zEdmcif/sYQsfch28bZeUz2rtY/9TCA6TD8dC3JE3rYkrhL
# ULy7Dc90G6e8BlqmyIjlgp2+VqsS9/wQD7yFylIz0scmbKvFoW2jNrbM1pD2T7m3
# XDCCBY0wggR1oAMCAQICEA6bGI750C3n79tQ4ghAGFowDQYJKoZIhvcNAQEMBQAw
# ZTELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQ
# d3d3LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBS
# b290IENBMB4XDTIyMDgwMTAwMDAwMFoXDTMxMTEwOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2lj
# ZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAv+aQc2jeu+RdSjwwIjBpM+zCpyUu
# ySE98orYWcLhKac9WKt2ms2uexuEDcQwH/MbpDgW61bGl20dq7J58soR0uRf1gU8
# Ug9SH8aeFaV+vp+pVxZZVXKvaJNwwrK6dZlqczKU0RBEEC7fgvMHhOZ0O21x4i0M
# G+4g1ckgHWMpLc7sXk7Ik/ghYZs06wXGXuxbGrzryc/NrDRAX7F6Zu53yEioZldX
# n1RYjgwrt0+nMNlW7sp7XeOtyU9e5TXnMcvak17cjo+A2raRmECQecN4x7axxLVq
# GDgDEI3Y1DekLgV9iPWCPhCRcKtVgkEy19sEcypukQF8IUzUvK4bA3VdeGbZOjFE
# mjNAvwjXWkmkwuapoGfdpCe8oU85tRFYF/ckXEaPZPfBaYh2mHY9WV1CdoeJl2l6
# SPDgohIbZpp0yt5LHucOY67m1O+SkjqePdwA5EUlibaaRBkrfsCUtNJhbesz2cXf
# SwQAzH0clcOP9yGyshG3u3/y1YxwLEFgqrFjGESVGnZifvaAsPvoZKYz0YkH4b23
# 5kOkGLimdwHhD5QMIR2yVCkliWzlDlJRR3S+Jqy2QXXeeqxfjT/JvNNBERJb5RBQ
# 6zHFynIWIgnffEx1P2PsIV/EIFFrb7GrhotPwtZFX50g/KEexcCPorF+CiaZ9eRp
# L5gdLfXZqbId5RsCAwEAAaOCATowggE2MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0O
# BBYEFOzX44LScV1kTN8uZz/nupiuHA9PMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1R
# i6enIZ3zbcgPMA4GA1UdDwEB/wQEAwIBhjB5BggrBgEFBQcBAQRtMGswJAYIKwYB
# BQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0
# cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENB
# LmNydDBFBgNVHR8EPjA8MDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20v
# RGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMBEGA1UdIAQKMAgwBgYEVR0gADAN
# BgkqhkiG9w0BAQwFAAOCAQEAcKC/Q1xV5zhfoKN0Gz22Ftf3v1cHvZqsoYcs7IVe
# qRq7IviHGmlUIu2kiHdtvRoU9BNKei8ttzjv9P+Aufih9/Jy3iS8UgPITtAq3vot
# Vs/59PesMHqai7Je1M/RQ0SbQyHrlnKhSLSZy51PpwYDE3cnRNTnf+hZqPC/Lwum
# 6fI0POz3A8eHqNJMQBk1RmppVLC4oVaO7KTVPeix3P0c2PR3WlxUjG/voVA9/HYJ
# aISfb8rbII01YBwCA8sgsKxYoA5AY8WYIsGyWfVVa88nq2x2zm8jLfR+cWojayL/
# ErhULSd+2DrZ8LaHlv1b0VysGMNNn3O3AamfV6peKOK5lDGCA4wwggOIAgEBMH0w
# aTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQD
# EzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2IFNIQTI1
# NiAyMDI1IENBMQIQDCBDSfnQ91n7mC3kCBuIezANBglghkgBZQMEAgIFAKCB4TAa
# BgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI2MDEx
# OTE4MTgwOVowKwYLKoZIhvcNAQkQAgwxHDAaMBgwFgQUcrz9oBB/STSwBxxhD+bX
# llAAmHcwNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgMvPjsb2i17JtTx0bjN29j4uE
# dqF4ntYSzTyqep7/NcIwPwYJKoZIhvcNAQkEMTIEMOkhro1T6niga3/oMtPyekgm
# 2Cgnxfkt/tKhITSQQrs3iMMP0HGrdd+viv9+1tKeqzANBgkqhkiG9w0BAQEFAASC
# AgAgjPb4P7cDqd2PDHEKP0v41huXsUiP8Z7cuLlVmcE4SJVf63LPWNxt0lp+j0it
# oWYzhKpKWCIXWnpEaMp/tjoKkMgRzjx6KTRMryM/IeNESku9PAHs1H9HiJKXbJSG
# m/eI+ELXo4hO2Njxfcl9SUCYpxwNj4KhYJKIKQsGdZZGV8e8f8s3qtMeUqg+dDaM
# zLAdDuZ/+qNSFxXGhaHGbQjyLqSlK1kxvaD1EJp/CQZK0PKY/iPaAxi9yzxPTTrw
# kl31ZgGMTZXTcx0md1+CAwM3+R7MnAqm3UXlOuchIrsFasOR6gVLvlWub4LwyeB5
# YcGBsxrI6OES4qkLBIjR5KRJxqeppUojnCi8EDPUfJZFNAB+7+fOpU7e8aMZjIgL
# 8a6RUTri/uedaz2PVuHABDu2i1yAQRkQ4P9dl8H2NjMt5EkvaS86E5GcdiRI+mXU
# C5cMpwHwP4SlD5MtkjejZlAY/P4XFwYlt3jH6VLwduZncgwi/aXw+MXryBUlBG3V
# YmkimprD4R9I9RAGkllkNwjJn3UXxn4ycZ9NZbOpyDgPgd+yMjiz7XKpY+zuXfr4
# SqU9JylyARSVhkcgztFgBXMiJh8kYvUuayb7AGYF2AEV80X6VirBibFOZ8ovLckt
# BGhq8aQztfcup1Z48IWrRx3mOp/9jGxzbb21q7rf8GlGyQ==
# SIG # End signature block
