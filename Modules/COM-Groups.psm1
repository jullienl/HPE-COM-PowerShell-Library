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

    .PARAMETER ShowApprovalPolicy
    Optional switch parameter that can be used to retrieve the approval policies assigned to the designated group.
    
    .PARAMETER ShowSettings
    Optional parameter that can be used to obtain a list of server settings that are assigned to the designated group. 

    .PARAMETER ShowActivities
    Optional parameter that can be used to retrieve activities from the last month for the specified group.

    .PARAMETER ShowJobs
    Optional parameter that can be used to retrieve jobs from the last month for the specified group.

    .PARAMETER ShowDeviceType
    Optional parameter to filter groups by device type. Supported values:
    - DIRECT_CONNECT_SERVER: Returns server groups (directly connected servers).
    - OVE_APPLIANCE_VM: Returns appliance groups for OneView VM appliances.
    - OVE_APPLIANCE_SYNERGY: Returns appliance groups for OneView Synergy appliances.
    - OVE_APPLIANCE: Returns all OneView appliance groups (both VM and Synergy).

    Auto-completion (Tab key) is supported for this parameter.

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

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -Name Team1 -ShowApprovalPolicy

    Return the approval policies assigned to the group 'Team1'.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -Name ESXi_group -ShowActivities

    Return activities from the last month for the group 'ESXi_group'.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -Name ESXi_group -ShowJobs

    Return jobs from the last month for the group 'ESXi_group'.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -ShowDeviceType OVE_APPLIANCE_VM

    Return all groups configured for OneView VM appliances in the 'eu-central' region.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -ShowDeviceType OVE_APPLIANCE

    Return all OneView appliance groups (both VM and Synergy) in the 'eu-central' region.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -ShowDeviceType DIRECT_CONNECT_SERVER

    Return all server groups (directly connected servers) in the 'eu-central' region.
    
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
        [Parameter (Mandatory, ParameterSetName = 'ShowApprovalPolicy')]
        [Parameter (ParameterSetName = 'ShowActivities')]
        [Parameter (ParameterSetName = 'ShowJobs')]
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

        [Parameter (ParameterSetName = 'ShowApprovalPolicy')]
        [Switch]$ShowApprovalPolicy,
                
        [Parameter (ParameterSetName = 'ShowSettings')]
        [Switch]$ShowSettings,

        [Parameter (ParameterSetName = 'ShowActivities')]
        [Switch]$ShowActivities,

        [Parameter (ParameterSetName = 'ShowJobs')]
        [Switch]$ShowJobs,

        [Parameter (ParameterSetName = 'Name')]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $deviceTypes = @('DIRECT_CONNECT_SERVER', 'OVE_APPLIANCE_SYNERGY', 'OVE_APPLIANCE_VM', 'OVE_APPLIANCE')
                $deviceTypes | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('DIRECT_CONNECT_SERVER', 'OVE_APPLIANCE_SYNERGY', 'OVE_APPLIANCE_VM', 'OVE_APPLIANCE')]
        [String]$ShowDeviceType,

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
        elseif (($ShowMembers -or $ShowCompliance -or $ShowFirmwareCompliance -or $ShowiLOSettingsCompliance -or $ShowExternalStorageCompliance) -or ($ShowActivities -and $Name) -or ($ShowJobs -and $Name)) {

            try {
                # Fetch all groups and match case-insensitively to handle API case sensitivity
                $_allGroupsTemp = Invoke-HPECOMWebRequest -Method Get -Uri (Get-COMGroupsUri) -Region $Region
                $GroupFetch = @($_allGroupsTemp) | Where-Object { $_.name -ieq $name } | Select-Object -First 1
                $GroupID = $GroupFetch.id
                $GroupDeviceType = $GroupFetch.deviceType

                "[{0}] ID found for group '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $GroupID | Write-Verbose

                if ($Null -eq $GroupID) { 
                    # Write-Warning "Group '$name' cannot be found in the Compute Ops Management instance!" 
                    return
                }

                if ($ShowCompliance) {
                    if ($GroupDeviceType -match '^OVE_APPLIANCE') {
                        $Uri = (Get-COMGroupsUri) + "/" + $GroupID
                    } else {
                        $Uri = (Get-COMGroupsUIDoorwayUri) + "/" + $GroupID
                    }
                }

                if ($ShowFirmwareCompliance) {
                    if ($GroupDeviceType -match '^OVE_APPLIANCE') {
                        Write-Warning "'-ShowFirmwareCompliance' is not supported for OneView appliance groups (deviceType: '$GroupDeviceType'). Use '-ShowCompliance' instead."
                        return
                    }
                    $Uri = (Get-COMGroupsUri) + "/" + $GroupID + "/compliance"
                }

                if ($ShowiLOSettingsCompliance) {
                    if ($GroupDeviceType -match '^OVE_APPLIANCE') {
                        Write-Warning "'-ShowiLOSettingsCompliance' is not supported for OneView appliance groups (deviceType: '$GroupDeviceType'). Use '-ShowCompliance' instead."
                        return
                    }
                    $Uri = (Get-COMGroupsUIDoorwayUri) + "/" + $GroupID
                }

                if ($ShowExternalStorageCompliance) {
                    if ($GroupDeviceType -match '^OVE_APPLIANCE') {
                        Write-Warning "'-ShowExternalStorageCompliance' is not supported for OneView appliance groups (deviceType: '$GroupDeviceType'). Use '-ShowCompliance' instead."
                        return
                    }
                    $Uri = (Get-COMGroupsUri) + "/" + $GroupID + "/external-storage-compliance"
                }

                if ($ShowMembers) {
                    $Uri = (Get-COMGroupsUri) + "/" + $GroupID + "/devices"
                }

                if ($ShowActivities) {
                    # No URI needed here, we'll call Get-HPECOMActivity directly
                }

                if ($ShowJobs) {
                    # No URI needed here, we'll call Get-HPECOMJob directly
                }
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
           
            }
        }
        elseif ($Name) {

            # Fetch all groups; filter case-insensitively on the client side below
            $Uri = Get-COMGroupsUri
            $_applyNameFilter = $true
        }
        else {
            $Uri = Get-COMGroupsUri
            $_applyNameFilter = $false
        }

        if ($ShowActivities) {
            try {
                if ($Name) {
                    # Get activities for specific group
                    "[{0}] Retrieving activities for group '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                    [Array]$CollectionList = Get-HPECOMActivity -Region $Region -SourceName $Name -ShowLastMonth -Verbose:$VerbosePreference -WhatIf:$WhatIf -WarningAction SilentlyContinue
                }
                else {
                    # Get activities for all groups using Category filter
                    "[{0}] Retrieving activities for all groups in region '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose
                    [Array]$CollectionList = Get-HPECOMActivity -Region $Region -Category Group -ShowLastMonth -Verbose:$VerbosePreference -WhatIf:$WhatIf -WarningAction SilentlyContinue
                }
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
        elseif ($ShowJobs) {
            try {
                if ($Name) {
                    # Get jobs for specific group
                    "[{0}] Retrieving jobs for group '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                    [Array]$CollectionList = Get-HPECOMJob -Region $Region -SourceName $Name -ShowLastMonth -Verbose:$VerbosePreference -WhatIf:$WhatIf -WarningAction SilentlyContinue
                }
                else {
                    # Get jobs for all groups using Category filter
                    "[{0}] Retrieving jobs for all groups in region '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose
                    [Array]$CollectionList = Get-HPECOMJob -Region $Region -Category Group -ShowLastMonth -Verbose:$VerbosePreference -WhatIf:$WhatIf -WarningAction SilentlyContinue
                }
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
        else {
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
        }           

        # Apply case-insensitive name filter for the plain -Name and Show* (policy/setting) paths
        if ($_applyNameFilter -and $CollectionList) {
            $CollectionList = @($CollectionList | Where-Object { $_.name -ieq $Name })
        }

        $ReturnData = @()
      
        if ($Null -ne $CollectionList) {   
            
            # Add region to object (skip for activities and jobs as they already have it)
            if (-not $ShowActivities -and -not $ShowJobs) {
                $CollectionList | Add-Member -type NoteProperty -name region -value $Region
            }
                       
            if ($ShowCompliance) {

                if ($GroupDeviceType -match '^OVE_APPLIANCE') {

                    # OVE appliance group compliance — cross-reference settingsUris with Get-HPECOMSetting
                    try { $AllSettings = Get-HPECOMSetting -Region $Region -Verbose:$false } catch {}
                    $complianceRows = [System.Collections.ArrayList]::new()
                    $overallCompliance = $CollectionList.groupCompliance.summary

                    foreach ($settingUri in $CollectionList.settingsUris) {
                        $settingId = $settingUri -replace '^.*/', ''
                        $setting = $AllSettings | Where-Object id -eq $settingId | Select-Object -First 1
                        $settingName     = if ($setting) { $setting.name }     else { $settingUri }
                        $rawCategory     = if ($setting) { $setting.category } else { 'Unknown' }

                        $settingTypeLabel = switch ($rawCategory) {
                            'OVE_SOFTWARE_VM'                { 'Appliance Software (VM)' }
                            'OVE_SOFTWARE_SYNERGY'           { 'Appliance Software (Synergy)' }
                            'OVE_APPLIANCE_SETTINGS_ANY'     { 'Appliance Settings' }
                            'OVE_APPLIANCE_SETTINGS_SYNERGY' { 'Appliance Settings (Synergy)' }
                            'OVE_SERVER_TEMPLATES_VM'        { 'Server Profile Templates (VM)' }
                            'OVE_SERVER_TEMPLATES_SYNERGY'   { 'Server Profile Templates (Synergy)' }
                            default                         { $rawCategory }
                        }

                        [void]$complianceRows.Add([PSCustomObject]@{
                            groupName        = $Name
                            deviceType       = $CollectionList.deviceType
                            settingType      = $settingTypeLabel
                            settingName      = $settingName
                            complianceStatus = $overallCompliance
                            region           = $Region
                        })
                    }

                    if ($complianceRows.Count -eq 0) {
                        [void]$complianceRows.Add([PSCustomObject]@{
                            groupName        = $Name
                            deviceType       = $CollectionList.deviceType
                            settingType      = 'None'
                            settingName      = 'No settings assigned'
                            complianceStatus = $overallCompliance
                            region           = $Region
                        })
                    }

                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $complianceRows -ObjectName "COM.Groups.OVE.Appliance.Compliance"

                }
                else {

                    # Extract only compliance-relevant fields from UI-Doorway comprehensive response
                    # Convert PSCustomObjects to formatted strings for display
                    $firmwareDevices = if ($CollectionList.'deviceCounts_'.'firmwareCompliance' -and $CollectionList.'deviceCounts_'.'firmwareCompliance'.PSObject.Properties.Count -gt 0) {
                        ($CollectionList.'deviceCounts_'.'firmwareCompliance'.PSObject.Properties | ForEach-Object { "$($_.Name):$($_.Value)" }) -join ', '
                    }
                    else { 'None' }

                    $iloDevices = if ($CollectionList.'deviceCounts_'.'iloSettingCompliance' -and $CollectionList.'deviceCounts_'.'iloSettingCompliance'.PSObject.Properties.Count -gt 0) {
                        ($CollectionList.'deviceCounts_'.'iloSettingCompliance'.PSObject.Properties | ForEach-Object { "$($_.Name):$($_.Value)" }) -join ', '
                    }
                    else { 'None' }

                    $externalStorageDevices = if ($CollectionList.'deviceCounts_'.'externalStorageCompliance' -and $CollectionList.'deviceCounts_'.'externalStorageCompliance'.PSObject.Properties.Count -gt 0) {
                        ($CollectionList.'deviceCounts_'.'externalStorageCompliance'.PSObject.Properties | ForEach-Object { "$($_.Name):$($_.Value)" }) -join ', '
                    }
                    else { 'None' }

                    $ComplianceData = [PSCustomObject]@{
                        groupName                               = $Name
                        groupComplianceStatus                   = $CollectionList.groupComplianceStatus
                        firmwareComplianceStatus                = $CollectionList.firmwareComplianceStatus_
                        groupIloSettingsComplianceStatus        = $CollectionList.groupIloSettingsComplianceStatus
                        groupExternalStorageComplianceStatus    = $CollectionList.groupExternalStorageComplianceStatus
                        groupSummaryComplianceStatus            = $CollectionList.groupSummaryComplianceStatus
                        firmwareDevices                         = $firmwareDevices
                        iloDevices                              = $iloDevices
                        externalStorageDevices                  = $externalStorageDevices
                        groupComplianceUpdatedAt                = $CollectionList.groupComplianceUpdatedAt
                        groupIloSettingsComplianceUpdatedAt     = $CollectionList.groupIloSettingsComplianceUpdatedAt
                        groupExternalStorageComplianceUpdatedAt = $CollectionList.groupExternalStorageComplianceUpdatedAt
                        groupSummaryComplianceUpdatedAt         = $CollectionList.groupSummaryComplianceUpdatedAt
                        complianceCheckedAt                     = $CollectionList.complianceCheckedAt_
                        region                                  = $Region
                    }

                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $ComplianceData -ObjectName "COM.Groups.All.Compliance"

                }

            }
            elseif ($ShowFirmwareCompliance) {

                # Add groupName, servername and serialNumber (only serial is provided)
                # groupName is used in Invoke-HPECOMGroupServerInternalStorageConfiguration, Update-HPECOMGroupServerFirmware, etc. 
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
                }
                else { 'None' }
                
                $iLOComplianceData = [PSCustomObject]@{
                    groupName                        = $Name
                    groupIloSettingsComplianceStatus = $CollectionList.groupIloSettingsComplianceStatus
                    deviceCounts                     = $iloDevices
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

                if ($GroupDeviceType -match '^OVE_APPLIANCE') {

                    # For OVE appliance groups, return full appliance objects (reuses COM.Appliances format)
                    try { $AllAppliances = Get-HPECOMAppliance -Region $Region -Verbose:$false } catch {}

                    $MemberIds = $CollectionList | ForEach-Object { $_.serial }
                    $MemberAppliances = $AllAppliances | Where-Object { $MemberIds -contains $_.id }

                    if ($MemberAppliances) {
                        $MemberAppliances | Add-Member -Type NoteProperty -Name groupName -Value $Name -Force
                        $ReturnData = $MemberAppliances | Sort-Object name
                    }

                }
                else {

                    # Add groupName, servername and serialNumber (only serial is provided)
                    # groupName is used in Invoke-HPECOMGroupServerInternalStorageConfiguration, Update-HPECOMGroupServerFirmware, etc. 
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

            }
            elseif ($ShowSettings) {

                $_CollectionList = [System.Collections.ArrayList]::new()

                $_Settings = Get-HPECOMSetting -Region $Region -Verbose:$false

                # Determine which OVE categories need a firmware-bundle lookup (OVE_SOFTWARE_*).
                # All other OVE enrichment is computed inline from the raw API object (zero extra calls).
                $_settingIds   = $CollectionList.settingsUris | ForEach-Object { $_.split('/')[-1] }
                $_groupSettings = @($_Settings | Where-Object id -in $_settingIds)
                $_AllBundles   = $null
                if ($_groupSettings | Where-Object category -match '^OVE_SOFTWARE_') {
                    try { $_AllBundles = Get-HPECOMApplianceFirmwareBundle -Region $Region -Verbose:$false } catch {}
                }

                foreach ($SettingUri in $CollectionList.settingsUris) {

                    $SettingId = $SettingUri.split('/')[-1]

                    "[{0}] Setting uri found for group '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $SettingId | Write-Verbose

                    $_serversetting = $_Settings | Where-Object id -eq $SettingId | Select-Object -First 1

                    if ($_serversetting) {
                        "[{0}] Setting found: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_serversetting.name | Write-Verbose

                        # Lightweight inline OVE enrichment — only what the Attributes format column needs.
                        # Avoids re-calling Get-HPECOMSetting per category (which triggers expensive sub-fetches).
                        switch -Regex ($_serversetting.category) {

                            '^OVE_SOFTWARE_' {
                                # Resolve firmware bundle ID -> applianceVersion (bundles already fetched above)
                                $_bundleId = $_serversetting.applianceFirmwareId
                                $_bundle   = if ($_AllBundles) { $_AllBundles | Where-Object id -eq $_bundleId | Select-Object -First 1 } else { $null }
                                $_version  = if ($_bundle) { $_bundle.applianceVersion } else { $_bundleId }
                                $_appType  = if ($_serversetting.category -match 'VM$') { 'VM' } else { 'Synergy' }
                                $_serversetting | Add-Member -Type NoteProperty -Name applianceVersion -Value $_version  -Force
                                $_serversetting | Add-Member -Type NoteProperty -Name applianceType    -Value $_appType  -Force
                            }

                            '^OVE_APPLIANCE_SETTINGS_SYNERGY' {
                                # Synergy appliance settings only have two global include flags
                                $_gs = $_serversetting.settings.DEFAULT.globalSettings
                                $_serversetting | Add-Member -Type NoteProperty -Name interconnectSettingsIncluded        -Value ($null -ne $_gs.interconnectManagerNtpSource) -Force
                                $_serversetting | Add-Member -Type NoteProperty -Name logicalInterconnectSettingsIncluded -Value ($null -ne $_gs.reservedVlanRange)             -Force
                            }

                            '^OVE_APPLIANCE_SETTINGS' {
                                # VM / ANY appliance settings — compute *Selected counts from raw settings.DEFAULT.*
                                $_def = $_serversetting.settings.DEFAULT

                                # Security
                                $_sec = $_def.security
                                if ($null -ne $_sec) {
                                    $_secProps = @('allowSshAccess','enforceComplexPasswordEnabled','enableServiceAccess','certValidationConfig','auditLogForwarding','productImprovement',
                                                   'allowLocalLogin','emergencyLocalLoginEnabled','twoFactorAuthenticationEnabled','strictTwoFactorAuthentication','userGroups','directories')
                                    $_secCount = ($_secProps | Where-Object { $null -ne $_sec.$_ }).Count
                                    $_secValue = "$_secCount/$($_secProps.Count)"
                                } else { $_secValue = "-" }
                                $_serversetting | Add-Member -Type NoteProperty -Name securitySelected -Value $_secValue -Force

                                # Notifications
                                $_notif = $_def.notifications
                                if ($null -ne $_notif) {
                                    $_nProps = @('smtpServer','alertEmailFilters')
                                    $_nCount = ($_nProps | Where-Object { $null -ne $_notif.$_ }).Count
                                    $_notifValue = "$_nCount/2"
                                } else { $_notifValue = "-" }
                                $_serversetting | Add-Member -Type NoteProperty -Name notificationsSelected -Value $_notifValue -Force

                                # Proxy
                                $_serversetting | Add-Member -Type NoteProperty -Name proxySelected -Value $(if ($null -ne $_def.proxy) { '1/1' } else { '-' }) -Force

                                # Remote Support
                                $_rs = $_def.remoteSupport
                                if ($null -ne $_rs) {
                                    $_rsProps = @('configuration','schedule')
                                    $_rsCount = ($_rsProps | Where-Object { $null -ne $_rs.$_ }).Count
                                    $_rsValue = "$_rsCount/2"
                                } else { $_rsValue = "-" }
                                $_serversetting | Add-Member -Type NoteProperty -Name remoteSupportSelected -Value $_rsValue -Force

                                # SNMP
                                $_serversetting | Add-Member -Type NoteProperty -Name snmpSelected -Value $(if ($null -ne $_def.snmp) { '1/1' } else { '-' }) -Force

                                # Time & Locale
                                $_tal = $_def.timeAndLocale
                                if ($null -ne $_tal) {
                                    $_tProps = @('locale','timeSource')
                                    $_tCount = ($_tProps | Where-Object { $null -ne $_tal.$_ }).Count
                                    $_talValue = "$_tCount/2"
                                } else { $_talValue = "-" }
                                $_serversetting | Add-Member -Type NoteProperty -Name timeLocaleSelected -Value $_talValue -Force

                                # Updates
                                $_serversetting | Add-Member -Type NoteProperty -Name updatesSelected -Value $(if ($null -ne $_def.updates) { '1/1' } else { '-' }) -Force

                                # Global Settings
                                $_gs = $_def.globalSettings
                                if ($null -ne $_gs) {
                                    $_gsProps = @('proxy','ntp','directoryServices','timeoutPolicy')
                                    $_gsCount = ($_gsProps | Where-Object { $null -ne $_gs.$_ }).Count
                                    $_gsValue = "$_gsCount/4"
                                } else { $_gsValue = "-" }
                                $_serversetting | Add-Member -Type NoteProperty -Name globalSettingsSelected -Value $_gsValue -Force
                            }
                        }

                        [void]$_CollectionList.add($_serversetting)
                    }
                }

                # Add groupName to object (used in Invoke-HPECOMGroupServerInternalStorageConfiguration, Update-HPECOMGroupServerFirmware, etc. )
                $_CollectionList | Add-Member -type NoteProperty -name groupName -value $Name

                $_CollectionList = $_CollectionList | Sort-Object name
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $_CollectionList -ObjectName "COM.Settings"    

            }
            elseif ($ShowActivities) {

                # Activities are already in the correct format from Get-HPECOMActivity
                # Just return them directly without repackaging
                $ReturnData = $CollectionList
                
            }
            elseif ($ShowJobs) {

                # Jobs are already in the correct format from Get-HPECOMJob
                # Just return them directly without repackaging
                $ReturnData = $CollectionList
                
            }
            elseif ($ShowPolicies) {

                if ($CollectionList.deviceType -match '^OVE_APPLIANCE') {
                    Write-Warning "'-ShowPolicies' is not supported for OneView appliance groups (deviceType: '$($CollectionList.deviceType)'). Policies only apply to server groups."
                    return
                }

                $ListOfGroupSettingCategories = [System.Collections.ArrayList]::new()

                $_Settings = Get-HPECOMSetting -Region $Region 

                foreach ($SettingUri in $CollectionList.settingsUris) {

                    $SettingId = $SettingUri.split('/')[-1]

                    "[{0}] Setting uri found for group '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $SettingId | Write-Verbose

                    $_serversetting = $_Settings | Where-Object id -eq $SettingId

                    "[{0}] Setting found: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_serversetting.name | Write-Verbose

                    if ($_serversetting) {
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
            elseif ($ShowApprovalPolicy) {

                if ($CollectionList.deviceType -match '^OVE_APPLIANCE') {
                    Write-Warning "'-ShowApprovalPolicy' is not supported for OneView appliance groups (deviceType: '$($CollectionList.deviceType)'). Approval policies only apply to server groups."
                    return
                }

                "[{0}] Retrieving approval policies assigned to group '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

                $allPolicies = Get-HPECOMApprovalPolicy -Region $Region -Verbose:$false

                $ReturnData = $allPolicies | Where-Object {
                    $_.policyData.resources | Where-Object { $_.id -eq $CollectionList.id }
                }

            }
            else {

                # Add groupName to object (used in Invoke-HPECOMGroupServerInternalStorageConfiguration, Update-HPECOMGroupServerFirmware, etc. )
                foreach ($item in $CollectionList) {
                    $item | Add-Member -MemberType NoteProperty -Name groupName -Value $item.name
                }

                # Apply device type filter if specified
                if ($ShowDeviceType -eq 'OVE_APPLIANCE') {
                    $CollectionList = @($CollectionList | Where-Object { $_.deviceType -match '^OVE_APPLIANCE' })
                }
                elseif ($ShowDeviceType) {
                    $CollectionList = @($CollectionList | Where-Object { $_.deviceType -eq $ShowDeviceType })
                }

                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Groups"    
                $ReturnData = $ReturnData | Sort-Object name

                # Insert a more-specific TypeName for OneView appliance groups so dedicated format views apply.
                # Skip when ShowDeviceType is 'OVE_APPLIANCE' (mixed VM + Synergy result): assigning different
                # TypeNames to objects in the same collection causes PowerShell to fall back to expanded list
                # format for all but the first item. The base COM.Groups format handles mixed results uniformly.
                if ($ShowDeviceType -ne 'OVE_APPLIANCE') {
                    foreach ($item in $ReturnData) {
                        $specificType = switch ($item.deviceType) {
                            'OVE_APPLIANCE_VM'      { 'HPEGreenLake.COM.Groups.OVE_APPLIANCE_VM' }
                            'OVE_APPLIANCE_SYNERGY' { 'HPEGreenLake.COM.Groups.OVE_APPLIANCE_SYNERGY' }
                        }
                        if ($specificType) {
                            $item.PSTypeNames.Insert(0, $specificType)
                            $item.PSObject.TypeNames.Insert(0, $specificType)
                        }
                    }
                }
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

    A Compute Ops Management setting is a collection of parameters that you can apply to one or more server or appliance groups. Two setting types are supported:
    - Server settings: Define configuration details and policies for server groups. Supported types include BIOS, firmware, OS, storage, iLO, and external storage settings.
    - Appliance settings: Create sets of common configuration preferences and server profile templates to apply to appliance groups (OneView VM or Synergy appliances).

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

    .PARAMETER OneViewVMAppliances
    Switch that creates an appliance group for OneView VM appliances.
    When specified, only OneView VM appliance setting parameters are available for this cmdlet.
    Retrieve compatible settings using 'Get-HPECOMSetting -Region $Region -Category OneViewSoftwareVM',
    'OneViewApplianceSettings', or 'OneViewServerProfileTemplatesVM'.

    .PARAMETER OneViewSynergyAppliances
    Switch that creates an appliance group for OneView Synergy appliances.
    When specified, only OneView Synergy appliance setting parameters are available for this cmdlet,
    including the Synergy-specific appliance setting parameter.
    Retrieve compatible settings using 'Get-HPECOMSetting -Region $Region -Category OneViewSoftwareSynergy',
    'OneViewApplianceSettings', 'OneViewApplianceSettingsSynergy', or 'OneViewServerProfileTemplatesSynergy'.

    .PARAMETER SettingsObject
    Specifies one or more server settings to assign to a server group. The settings object must be retrieved from 'Get-HPECOMSetting -Region $Region'.
    Note: This parameter applies to server groups only (DeviceType = 'Servers').

    .PARAMETER BiosSettingName
    Name of a BIOS server setting resource to assign to the server group, retrieved from 'Get-HPECOMSetting -Region $Region -Category Bios'.

    .PARAMETER ExternalStorageSettingName
    Name of an external storage server setting resource to assign to the server group, retrieved from 'Get-HPECOMSetting -Region $Region -Category ExternalStorage'.

    .PARAMETER FirmwareSettingName
    Name of a firmware server setting resource to assign to the server group, retrieved from 'Get-HPECOMSetting -Region $Region -Category Firmware'.

    .PARAMETER iLOSettingName
    Name of an iLO server setting resource to assign to the server group, retrieved from 'Get-HPECOMSetting -Region $Region -Category ILO_SETTINGS'.
    To assign the HPE-recommended security settings for iLOs, use the pre-defined setting named 'iLO settings enabled for security'.

    .PARAMETER OSSettingName
    Name of an OS server setting resource to assign to the server group, retrieved from 'Get-HPECOMSetting -Region $Region -Category Os'.

    .PARAMETER StorageSettingName
    Name of a storage server setting resource to assign to the server group, retrieved from 'Get-HPECOMSetting -Region $Region -Category Storage'.

    .PARAMETER OneViewApplianceSoftwareSettingName
    Name of a OneView appliance software setting resource to assign to the appliance group.
    This appliance setting defines the software configuration preferences applied to OneView appliances.
    For OneView VM appliance groups (-OneViewVMAppliances), retrieve the setting using 'Get-HPECOMSetting -Region $Region -Category OneViewSoftwareVM'.
    For OneView Synergy appliance groups (-OneViewSynergyAppliances), retrieve the setting using 'Get-HPECOMSetting -Region $Region -Category OneViewSoftwareSynergy'.
    The correct category is automatically determined by the switch used (-OneViewVMAppliances or -OneViewSynergyAppliances).

    .PARAMETER OneViewApplianceSettingName
    Name of a OneView appliance setting resource to assign to the appliance group.
    This appliance setting defines common configuration preferences that apply to both OneView VM and OneView Synergy appliance groups.
    Retrieve the setting using 'Get-HPECOMSetting -Region $Region -Category OneViewApplianceSettings'.

    .PARAMETER OneViewSynergyApplianceSettingName
    Name of a OneView Synergy-specific appliance setting resource to assign to the appliance group.
    This appliance setting defines configuration preferences specific to OneView Synergy appliances and is only applicable with -OneViewSynergyAppliances.
    Retrieve the setting using 'Get-HPECOMSetting -Region $Region -Category OneViewApplianceSettingsSynergy'.

    .PARAMETER OneViewServerProfileTemplateSettingName
    Name of a OneView server profile template setting resource to assign to the appliance group.
    This appliance setting defines the server profile templates applied to servers managed by OneView appliances.
    For OneView VM appliance groups (-OneViewVMAppliances), retrieve the setting using 'Get-HPECOMSetting -Region $Region -Category OneViewServerProfileTemplatesVM'.
    For OneView Synergy appliance groups (-OneViewSynergyAppliances), retrieve the setting using 'Get-HPECOMSetting -Region $Region -Category OneViewServerProfileTemplatesSynergy'.
    The correct category is automatically determined by the switch used (-OneViewVMAppliances or -OneViewSynergyAppliances).
        
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

    .EXAMPLE
    New-HPECOMGroup -Region eu-central -Name OneView_VM_Grp -Description "Group for OneView VM appliances" `
        -OneViewVMAppliances `
        -OneViewApplianceSoftwareSettingName "OV_Software" `
        -OneViewApplianceSettingName "OV_Appliance_Config" `
        -OneViewServerProfileTemplateSettingName "OV_SPT_ESXi"

    Create a new appliance group for OneView VM appliances in the eu-central region, assigning a software setting, a common appliance setting, and a server profile template setting.

    .EXAMPLE
    New-HPECOMGroup -Region eu-central -Name OneView_Synergy_Grp -Description "Group for OneView Synergy appliances" `
        -OneViewSynergyAppliances `
        -OneViewApplianceSoftwareSettingName "OV_Synergy_Appliance_Software" `
        -OneViewApplianceSettingName "OV_Settings" `
        -OneViewSynergyApplianceSettingName "Composer_settings" `
        -OneViewServerProfileTemplateSettingName "OneView_SY_Template_1"

    Create a new appliance group for OneView Synergy appliances in the eu-central region, assigning a Synergy software setting, a common appliance setting, a Synergy-specific appliance setting, and a server profile template setting.

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

    [CmdletBinding(DefaultParameterSetName = "Settings")]
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

        [Parameter (ValueFromPipelineByPropertyName, ParameterSetName = "SettingsObject")]
        [String]$DeviceType,

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

        # OneView VM appliances
        [Parameter (Mandatory, ParameterSetName = "SettingsOneViewVM")] 
        [Switch]$OneViewVMAppliances,

        [Parameter (ParameterSetName = "SettingsOneViewVM")] 
        [Parameter (ParameterSetName = "SettingsOneViewSynergy")] 
        [String]$OneViewApplianceSoftwareSettingName,

        [Parameter (ParameterSetName = "SettingsOneViewVM")] 
        [Parameter (ParameterSetName = "SettingsOneViewSynergy")] 
        [String]$OneViewApplianceSettingName,

        [Parameter (ParameterSetName = "SettingsOneViewVM")] 
        [Parameter (ParameterSetName = "SettingsOneViewSynergy")] 
        [String]$OneViewServerProfileTemplateSettingName,

        # OneView Synergy appliances
        [Parameter (Mandatory, ParameterSetName = "SettingsOneViewSynergy")] 
        [Switch]$OneViewSynergyAppliances,

        [Parameter (ParameterSetName = "SettingsOneViewSynergy")] 
        [String]$OneViewSynergyApplianceSettingName,

        # BIOS settings
        [Parameter (ParameterSetName = "Settings")]
        [Parameter (ParameterSetName = "SettingsObject")]
        [switch]$AutoBiosApplySettingsOnAdd,
        [Parameter (ParameterSetName = "Settings")]
        [Parameter (ParameterSetName = "SettingsObject")]
        [switch]$ResetBIOSConfigurationSettingsToDefaultsonAdd,  

        # Firmware settings
        [Parameter (ParameterSetName = "Settings")]
        [Parameter (ParameterSetName = "SettingsObject")]
        [switch]$AutoFirmwareUpdateOnAdd,
        [Parameter (ParameterSetName = "Settings")]
        [Parameter (ParameterSetName = "SettingsObject")]
        [switch]$PowerOffServerAfterFirmwareUpdate,
        [Parameter (ParameterSetName = "Settings")]
        [Parameter (ParameterSetName = "SettingsObject")]
        [switch]$FirmwareDowngrade,

        # OS settings
        [Parameter (ParameterSetName = "Settings")]
        [Parameter (ParameterSetName = "SettingsObject")]
        [switch]$AutoOSImageInstallOnAdd,
        [Parameter (ParameterSetName = "Settings")]
        [Parameter (ParameterSetName = "SettingsObject")]
        [ValidateScript({ $_ -ge 60 -and $_ -le 720 })]
        [Int]$OsCompletionTimeoutMin = 240,

        # Storage settings
        [Parameter (ParameterSetName = "Settings")]
        [Parameter (ParameterSetName = "SettingsObject")]
        [switch]$AutoStorageVolumeCreationOnAdd,
        [Parameter (ParameterSetName = "Settings")]
        [Parameter (ParameterSetName = "SettingsObject")]
        [switch]$AutoStorageVolumeDeletionOnAdd,

        # iLO settings
        [Parameter (ParameterSetName = "Settings")]
        [Parameter (ParameterSetName = "SettingsObject")]
        [switch]$AutoIloApplySettingsOnAdd,

        # External storage settings       
        [Parameter (ParameterSetName = "Settings")]
        [Parameter (ParameterSetName = "SettingsObject")]
        [switch]$AutoExternalStorageConfigurationOnAdd,

        # Tags settings
        # [Parameter (ValueFromPipelineByPropertyName)] # Removed as an autoAddServerTag can only exist in one group
        [Parameter (ParameterSetName = "Settings")]
        [Parameter (ParameterSetName = "SettingsObject")]
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
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "Group already exists in the region! No action needed."
                [void] $CreateGroupStatus.Add($objStatus)
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

        if ($CreateGroupStatus.Count -eq 0) {

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
                        $ErrorMessage = "Setting '{0}' using the category '{1}' cannot be found in the Compute Ops Management instance!" -f $BiosSettingName, "BIOS"
                        "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                        if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
                        $objStatus.Status = "Warning"; $objStatus.Details = $ErrorMessage
                        [void] $CreateGroupStatus.add($objStatus)
                        $CreateGroupStatus = Invoke-RepackageObjectWithType -RawObject $CreateGroupStatus -ObjectName "COM.objStatus.NSDE"
                        Return $CreateGroupStatus
                    }
                    else {
    
                        [void]$ListOfSettingURIs.add($resourceUri) 
                    }
                }
                if ($ExternalStorageSettingName) {
                    
                    $resourceUri = ($Settings | Where-Object category -eq "EXTERNAL_STORAGE" | Where-Object name -eq $ExternalStorageSettingName).resourceUri
    
                    if (-not $resourceUri) {
                        $ErrorMessage = "Setting '{0}' using the category '{1}' cannot be found in the Compute Ops Management instance!" -f $ExternalStorageSettingName, "EXTERNAL_STORAGE"
                        "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                        if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
                        $objStatus.Status = "Warning"; $objStatus.Details = $ErrorMessage
                        [void] $CreateGroupStatus.add($objStatus)
                        $CreateGroupStatus = Invoke-RepackageObjectWithType -RawObject $CreateGroupStatus -ObjectName "COM.objStatus.NSDE"
                        Return $CreateGroupStatus
                    }
                    else {
    
                        [void]$ListOfSettingURIs.add($resourceUri) 
                    }
                }
                if ($FirmwareSettingName) {
                    
                    $resourceUri = ($Settings | Where-Object category -eq "FIRMWARE" | Where-Object name -eq $FirmwareSettingName).resourceUri
    
                    if (-not $resourceUri) {
                        $ErrorMessage = "Setting '{0}' using the category '{1}' cannot be found in the Compute Ops Management instance!" -f $FirmwareSettingName, "FIRMWARE"
                        "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                        if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
                        $objStatus.Status = "Warning"; $objStatus.Details = $ErrorMessage
                        [void] $CreateGroupStatus.add($objStatus)
                        $CreateGroupStatus = Invoke-RepackageObjectWithType -RawObject $CreateGroupStatus -ObjectName "COM.objStatus.NSDE"
                        Return $CreateGroupStatus
                    }
                    else {
    
                        [void]$ListOfSettingURIs.add($resourceUri) 
                    }
                }
                if ($iLOSettingName) {

                    $resourceUri = ($Settings | Where-Object category -eq "ILO_SETTINGS" | Where-Object name -eq $iLOSettingName).resourceUri

                    if (-not $resourceUri) {
                        $ErrorMessage = "Setting '{0}' using the category '{1}' cannot be found in the Compute Ops Management instance!" -f $iLOSettingName, "ILO_SETTINGS"
                        "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                        if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
                        $objStatus.Status = "Warning"; $objStatus.Details = $ErrorMessage
                        [void] $CreateGroupStatus.add($objStatus)
                        $CreateGroupStatus = Invoke-RepackageObjectWithType -RawObject $CreateGroupStatus -ObjectName "COM.objStatus.NSDE"
                        Return $CreateGroupStatus
                    }
                    else {
    
                        [void]$ListOfSettingURIs.add($resourceUri) 
                    }
                }
                if ($OSSettingName) {
                    
                    $resourceUri = ($Settings | Where-Object category -eq "OS" | Where-Object name -eq $OSSettingName).resourceUri
    
                    if (-not $resourceUri) {
                        $ErrorMessage = "Setting '{0}' using the category '{1}' cannot be found in the Compute Ops Management instance!" -f $OSSettingName, "OS"
                        "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                        if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
                        $objStatus.Status = "Warning"; $objStatus.Details = $ErrorMessage
                        [void] $CreateGroupStatus.add($objStatus)
                        $CreateGroupStatus = Invoke-RepackageObjectWithType -RawObject $CreateGroupStatus -ObjectName "COM.objStatus.NSDE"
                        Return $CreateGroupStatus
                    }
                    else {
    
                        [void]$ListOfSettingURIs.add($resourceUri) 
                    }
                }
                if ($StorageSettingName) {
                    
                    $resourceUri = ($Settings | Where-Object category -eq "STORAGE" | Where-Object name -eq $StorageSettingName).resourceUri
    
                    if (-not $resourceUri) {
                        $ErrorMessage = "Setting '{0}' using the category '{1}' cannot be found in the Compute Ops Management instance!" -f $StorageSettingName, "STORAGE"
                        "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                        if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
                        $objStatus.Status = "Warning"; $objStatus.Details = $ErrorMessage
                        [void] $CreateGroupStatus.add($objStatus)
                        $CreateGroupStatus = Invoke-RepackageObjectWithType -RawObject $CreateGroupStatus -ObjectName "COM.objStatus.NSDE"
                        Return $CreateGroupStatus
                    }
                    else {
    
                        [void]$ListOfSettingURIs.add($resourceUri) 
                    }
                }
                if ($OneViewApplianceSoftwareSettingName) {

                    $OVESoftwareCategory = if ($PSCmdlet.ParameterSetName -eq "SettingsOneViewSynergy") { "OVE_SOFTWARE_SYNERGY" } else { "OVE_SOFTWARE_VM" }
                    $resourceUri = ($Settings | Where-Object category -eq $OVESoftwareCategory | Where-Object name -eq $OneViewApplianceSoftwareSettingName).resourceUri

                    if (-not $resourceUri) {
                        $ErrorMessage = "Setting '{0}' using the category '{1}' cannot be found in the Compute Ops Management instance!" -f $OneViewApplianceSoftwareSettingName, $OVESoftwareCategory
                        "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                        if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
                        $objStatus.Status = "Warning"; $objStatus.Details = $ErrorMessage
                        [void] $CreateGroupStatus.add($objStatus)
                        $CreateGroupStatus = Invoke-RepackageObjectWithType -RawObject $CreateGroupStatus -ObjectName "COM.objStatus.NSDE"
                        Return $CreateGroupStatus
                    }
                    else {
                        [void]$ListOfSettingURIs.add($resourceUri)
                    }
                }
                if ($OneViewApplianceSettingName) {

                    $resourceUri = ($Settings | Where-Object category -eq "OVE_APPLIANCE_SETTINGS_ANY" | Where-Object name -eq $OneViewApplianceSettingName).resourceUri

                    if (-not $resourceUri) {
                        $ErrorMessage = "Setting '{0}' using the category 'OVE_APPLIANCE_SETTINGS_ANY' cannot be found in the Compute Ops Management instance!" -f $OneViewApplianceSettingName
                        "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                        if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
                        $objStatus.Status = "Warning"; $objStatus.Details = $ErrorMessage
                        [void] $CreateGroupStatus.add($objStatus)
                        $CreateGroupStatus = Invoke-RepackageObjectWithType -RawObject $CreateGroupStatus -ObjectName "COM.objStatus.NSDE"
                        Return $CreateGroupStatus
                    }
                    else {
                        [void]$ListOfSettingURIs.add($resourceUri)
                    }
                }
                if ($OneViewSynergyApplianceSettingName) {

                    $resourceUri = ($Settings | Where-Object category -eq "OVE_APPLIANCE_SETTINGS_SYNERGY" | Where-Object name -eq $OneViewSynergyApplianceSettingName).resourceUri

                    if (-not $resourceUri) {
                        $ErrorMessage = "Setting '{0}' using the category 'OVE_APPLIANCE_SETTINGS_SYNERGY' cannot be found in the Compute Ops Management instance!" -f $OneViewSynergyApplianceSettingName
                        "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                        if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
                        $objStatus.Status = "Warning"; $objStatus.Details = $ErrorMessage
                        [void] $CreateGroupStatus.add($objStatus)
                        $CreateGroupStatus = Invoke-RepackageObjectWithType -RawObject $CreateGroupStatus -ObjectName "COM.objStatus.NSDE"
                        Return $CreateGroupStatus
                    }
                    else {
                        [void]$ListOfSettingURIs.add($resourceUri)
                    }
                }
                if ($OneViewServerProfileTemplateSettingName) {

                    $OVETemplateCategory = if ($PSCmdlet.ParameterSetName -eq "SettingsOneViewSynergy") { "OVE_SERVER_TEMPLATES_SYNERGY" } else { "OVE_SERVER_TEMPLATES_VM" }
                    $resourceUri = ($Settings | Where-Object category -eq $OVETemplateCategory | Where-Object name -eq $OneViewServerProfileTemplateSettingName).resourceUri

                    if (-not $resourceUri) {
                        $ErrorMessage = "Setting '{0}' using the category '{1}' cannot be found in the Compute Ops Management instance!" -f $OneViewServerProfileTemplateSettingName, $OVETemplateCategory
                        "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                        if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
                        $objStatus.Status = "Warning"; $objStatus.Details = $ErrorMessage
                        [void] $CreateGroupStatus.add($objStatus)
                        $CreateGroupStatus = Invoke-RepackageObjectWithType -RawObject $CreateGroupStatus -ObjectName "COM.objStatus.NSDE"
                        Return $CreateGroupStatus
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
                    $tagError = $null
                    if (($AutoAddServerTag -split '=').Count -gt 2) {
                        $tagError = "Tag not supported! Only one tag is expected such as <tagname>=<value>"
                    }
                    elseif ($AutoAddServerTag -notmatch "^[A-Za-z0-9_-]+=[A-Za-z0-9_-][^=]*$") {
                        $tagError = "Tag format not supported! Expected format is <tagname>=<value>"
                    }
                    if ($tagError) {
                        "[{0}] Tag '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $TagUsedForAutoAddServer, $tagError | Write-Verbose
                        if ($WhatIf) {
                            Write-Warning "$tagError. Cannot display API request."
                            return
                        }
                        $objStatus.Status = "Warning"
                        $objStatus.Details = $tagError
                        [void] $CreateGroupStatus.add($objStatus)
                        $CreateGroupStatus = Invoke-RepackageObjectWithType -RawObject $CreateGroupStatus -ObjectName "COM.objStatus.NSDE"
                        Return $CreateGroupStatus
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
    
            if ($PSCmdlet.ParameterSetName -eq "SettingsOneViewSynergy") {
                $DeviceTypeValue = "OVE_APPLIANCE_SYNERGY"
            }
            elseif ($PSCmdlet.ParameterSetName -eq "SettingsOneViewVM") {
                $DeviceTypeValue = "OVE_APPLIANCE_VM"
            }
            elseif ($PSCmdlet.ParameterSetName -eq "Settings") {
                $DeviceTypeValue = "DIRECT_CONNECT_SERVER"
            }
            else {
                # SettingsObject parameter set: DeviceType comes from pipeline (Get-HPECOMGroup) as a raw API value
                # e.g. "DIRECT_CONNECT_SERVER", "OVE_APPLIANCE_VM", "OVE_APPLIANCE_SYNERGY"
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
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Group cannot be created!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                }
            }           
    
    
            if (-not $WhatIf) {
                [void] $CreateGroupStatus.add($objStatus)
            }

        }

        if ($CreateGroupStatus.Count -gt 0) {
            $CreateGroupStatus = Invoke-RepackageObjectWithType -RawObject $CreateGroupStatus -ObjectName "COM.objStatus.NSDE"
            Return $CreateGroupStatus
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
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            
            }
            else {
                $objStatus.Status = "Warning"
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
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Group cannot be deleted!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                }
            }           

        }
        if (-not $WhatIf) {
            [void] $RemoveGroupStatus.add($objStatus)
        }

    }

    end {

        if ($RemoveGroupStatus.Count -gt 0) {

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

    .PARAMETER OneViewApplianceSoftwareSettingName
    Specifies the name of a OneView appliance software setting resource to assign to the appliance group.
    The correct category (OVE_SOFTWARE_VM or OVE_SOFTWARE_SYNERGY) is automatically determined from the group's device type.
    Use an empty string "" to remove the current software setting from the group.
    Note: Only supported for OneView appliance groups.

    .PARAMETER OneViewApplianceSettingName
    Specifies the name of a OneView appliance setting resource (category OVE_APPLIANCE_SETTINGS_ANY) to assign to the appliance group.
    Use an empty string "" to remove the current appliance setting from the group.
    Note: Only supported for OneView appliance groups.

    .PARAMETER OneViewSynergyApplianceSettingName
    Specifies the name of a OneView Synergy-specific appliance setting resource (category OVE_APPLIANCE_SETTINGS_SYNERGY) to assign to the appliance group.
    Use an empty string "" to remove the current Synergy appliance setting from the group.
    Note: Only supported for OneView Synergy appliance groups.

    .PARAMETER OneViewServerProfileTemplateSettingName
    Specifies the name of a OneView server profile template setting resource to assign to the appliance group.
    The correct category (OVE_SERVER_TEMPLATES_VM or OVE_SERVER_TEMPLATES_SYNERGY) is automatically determined from the group's device type.
    Use an empty string "" to remove the current server profile template setting from the group.
    Note: Only supported for OneView appliance groups.

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

    .EXAMPLE
    Set-HPECOMGroup -Region eu-central -Name OneView_VM_Grp `
        -OneViewApplianceSoftwareSettingName "OV_VM_Software_11.10.00" `
        -OneViewApplianceSettingName "OV_Settings" `
        -OneViewServerProfileTemplateSettingName "OneView-Server-Templates"

    Updates the OneView VM appliance group named 'OneView_VM_Grp' in the eu-central region, assigning a new software setting, a common appliance setting, and a server profile template setting.

    .EXAMPLE
    Set-HPECOMGroup -Region eu-central -Name OneView_Synergy_Grp `
        -OneViewApplianceSoftwareSettingName "OV_Synergy_Software_11.10.00" `
        -OneViewApplianceSettingName "OV_Settings" `
        -OneViewSynergyApplianceSettingName "Synergy-Appliance-Setting" `
        -OneViewServerProfileTemplateSettingName "Synergy-Server-Templates"

    Updates the OneView Synergy appliance group named 'OneView_Synergy_Grp' in the eu-central region with a full set of appliance settings.

    .EXAMPLE
    Set-HPECOMGroup -Region eu-central -Name OneView_VM_Grp -OneViewServerProfileTemplateSettingName ""

    Removes the server profile template setting from the OneView VM appliance group named 'OneView_VM_Grp'.

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

        # OneView appliance group settings
        [String]$OneViewApplianceSoftwareSettingName,

        [String]$OneViewApplianceSettingName,

        [String]$OneViewSynergyApplianceSettingName,

        [String]$OneViewServerProfileTemplateSettingName,

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
        $onDeviceAdd = @{}
        $Policies = @{}

        
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
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            
            
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "Group cannot be found in the region!"
            }
        }
        else {
            
            $Uri = (Get-COMGroupsUri) + "/" + $GroupID

            # Detect group type
            $GroupDeviceType = $GroupResource.deviceType
            $IsOVEGroup      = $GroupDeviceType -match '^OVE_APPLIANCE'

            # Guard: server-specific params are not valid for OVE appliance groups
            $_serverOnlyParams = @('BiosSettingName','ExternalStorageSettingName','FirmwareSettingName','iLOSettingName','OSSettingName','StorageSettingName',
                                   'AutoBiosApplySettingsOnAdd','ResetBIOSConfigurationSettingsToDefaultsonAdd',
                                   'AutoFirmwareUpdateOnAdd','PowerOffServerAfterFirmwareUpdate','FirmwareDowngrade',
                                   'AutoOsImageInstallOnAdd','OsCompletionTimeoutMin','AutoStorageVolumeCreationOnAdd',
                                   'AutoStorageVolumeDeletionOnAdd','AutoIloApplySettingsOnAdd','AutoExternalStorageConfigurationOnAdd')
            $_oveOnlyParams    = @('OneViewApplianceSoftwareSettingName','OneViewApplianceSettingName','OneViewSynergyApplianceSettingName','OneViewServerProfileTemplateSettingName')

            if ($IsOVEGroup) {
                $_bad = @($_serverOnlyParams | Where-Object { $PSBoundParameters.ContainsKey($_) })
                if ($_bad.Count) {
                    $_guardMessage = "Parameters '-$($_bad -join "', '-")' are not supported for OneView appliance groups (deviceType: '$GroupDeviceType'). Use '-OneViewApplianceSoftwareSettingName', '-OneViewApplianceSettingName', '-OneViewSynergyApplianceSettingName', or '-OneViewServerProfileTemplateSettingName' instead."
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_guardMessage | Write-Verbose
                    if ($WhatIf) { Write-Warning $_guardMessage; return }
                    $objStatus.Status  = 'Warning'
                    $objStatus.Details = $_guardMessage
                }
            }
            else {
                $_bad = @($_oveOnlyParams | Where-Object { $PSBoundParameters.ContainsKey($_) })
                if ($_bad.Count) {
                    $_guardMessage = "Parameters '-$($_bad -join "', '-")' are not supported for server groups (deviceType: '$GroupDeviceType'). Use server setting parameters instead."
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_guardMessage | Write-Verbose
                    if ($WhatIf) { Write-Warning $_guardMessage; return }
                    $objStatus.Status  = 'Warning'
                    $objStatus.Details = $_guardMessage
                }
            }

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
                        if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
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
                        if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
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
                        if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
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
                        if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
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
                        if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
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
                        if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
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

            # OVE appliance group settings (software, appliance, Synergy-specific, server profile templates)
            if ($IsOVEGroup) {

                $_oveSoftwareCategory  = if ($GroupDeviceType -eq 'OVE_APPLIANCE_VM') { 'OVE_SOFTWARE_VM' } else { 'OVE_SOFTWARE_SYNERGY' }
                $_oveTemplateCategory  = if ($GroupDeviceType -eq 'OVE_APPLIANCE_VM') { 'OVE_SERVER_TEMPLATES_VM' } else { 'OVE_SERVER_TEMPLATES_SYNERGY' }

                # OVE Software setting
                if (-not $PSBoundParameters.ContainsKey('OneViewApplianceSoftwareSettingName')) {
                    if ($ExistingGroupSettings | Where-Object category -match '^OVE_SOFTWARE_') {
                        $_RessourceUri = $ExistingGroupSettings | Where-Object category -match '^OVE_SOFTWARE_' | ForEach-Object resourceUri
                        if ($_RessourceUri) {
                            "[{0}] OVE Software setting found in group: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_RessourceUri | Write-Verbose
                            [void]$SettingsUris.add($_RessourceUri)
                        }
                    }
                }
                else {
                    if ($OneViewApplianceSoftwareSettingName) {
                        $_RessourceUri = ($Settings | Where-Object category -eq $_oveSoftwareCategory | Where-Object name -eq $OneViewApplianceSoftwareSettingName).resourceUri
                        if (-not $_RessourceUri) {
                            $ErrorMessage = "Setting '{0}' using the category '{1}' cannot be found in the Compute Ops Management instance!" -f $OneViewApplianceSoftwareSettingName, $_oveSoftwareCategory
                            $ErrorRecord  = New-ErrorRecord ServerSettingeNotFoundInCOM ObjectNotFound -TargetObject 'Server-settings' -Message $ErrorMessage -TargetType $OneViewApplianceSoftwareSettingName.GetType().Name
                            if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
                            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
                        }
                        else { [void]$SettingsUris.add($_RessourceUri) }
                    }
                    # else: empty string -> remove setting from group (omit from settingsUris)
                }

                # OVE Appliance setting (OVE_APPLIANCE_SETTINGS_ANY — valid for both VM and Synergy)
                if (-not $PSBoundParameters.ContainsKey('OneViewApplianceSettingName')) {
                    if ($ExistingGroupSettings | Where-Object category -eq 'OVE_APPLIANCE_SETTINGS_ANY') {
                        $_RessourceUri = $ExistingGroupSettings | Where-Object category -eq 'OVE_APPLIANCE_SETTINGS_ANY' | ForEach-Object resourceUri
                        if ($_RessourceUri) {
                            "[{0}] OVE Appliance setting (ANY) found in group: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_RessourceUri | Write-Verbose
                            [void]$SettingsUris.add($_RessourceUri)
                        }
                    }
                }
                else {
                    if ($OneViewApplianceSettingName) {
                        $_RessourceUri = ($Settings | Where-Object category -eq 'OVE_APPLIANCE_SETTINGS_ANY' | Where-Object name -eq $OneViewApplianceSettingName).resourceUri
                        if (-not $_RessourceUri) {
                            $ErrorMessage = "Setting '{0}' using the category 'OVE_APPLIANCE_SETTINGS_ANY' cannot be found in the Compute Ops Management instance!" -f $OneViewApplianceSettingName
                            $ErrorRecord  = New-ErrorRecord ServerSettingeNotFoundInCOM ObjectNotFound -TargetObject 'Server-settings' -Message $ErrorMessage -TargetType $OneViewApplianceSettingName.GetType().Name
                            if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
                            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
                        }
                        else { [void]$SettingsUris.add($_RessourceUri) }
                    }
                }

                # Guard: OneViewSynergyApplianceSettingName is only valid for Synergy groups — reject silently if used on VM group
                if ($PSBoundParameters.ContainsKey('OneViewSynergyApplianceSettingName') -and $GroupDeviceType -ne 'OVE_APPLIANCE_SYNERGY' -and $null -eq $objStatus.Status) {
                    $_guardMessage = "Parameter '-OneViewSynergyApplianceSettingName' is only applicable to Synergy OVE groups. Group '$Name' is of type '$GroupDeviceType'"
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_guardMessage | Write-Verbose
                    if ($WhatIf) { Write-Warning "$_guardMessage. Cannot display API request."; return }
                    $objStatus.Status  = 'Warning'
                    $objStatus.Details = $_guardMessage
                }

                # OVE Synergy-specific appliance setting (only for Synergy groups)
                if ($GroupDeviceType -eq 'OVE_APPLIANCE_SYNERGY') {
                    if (-not $PSBoundParameters.ContainsKey('OneViewSynergyApplianceSettingName')) {
                        if ($ExistingGroupSettings | Where-Object category -eq 'OVE_APPLIANCE_SETTINGS_SYNERGY') {
                            $_RessourceUri = $ExistingGroupSettings | Where-Object category -eq 'OVE_APPLIANCE_SETTINGS_SYNERGY' | ForEach-Object resourceUri
                            if ($_RessourceUri) {
                                "[{0}] OVE Synergy appliance setting found in group: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_RessourceUri | Write-Verbose
                                [void]$SettingsUris.add($_RessourceUri)
                            }
                        }
                    }
                    else {
                        if ($OneViewSynergyApplianceSettingName) {
                            $_RessourceUri = ($Settings | Where-Object category -eq 'OVE_APPLIANCE_SETTINGS_SYNERGY' | Where-Object name -eq $OneViewSynergyApplianceSettingName).resourceUri
                            if (-not $_RessourceUri) {
                                $ErrorMessage = "Setting '{0}' using the category 'OVE_APPLIANCE_SETTINGS_SYNERGY' cannot be found in the Compute Ops Management instance!" -f $OneViewSynergyApplianceSettingName
                                $ErrorRecord  = New-ErrorRecord ServerSettingeNotFoundInCOM ObjectNotFound -TargetObject 'Server-settings' -Message $ErrorMessage -TargetType $OneViewSynergyApplianceSettingName.GetType().Name
                                if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
                                $PSCmdlet.ThrowTerminatingError($ErrorRecord)
                            }
                            else { [void]$SettingsUris.add($_RessourceUri) }
                        }
                    }
                }

                # OVE Server Profile Template setting
                if (-not $PSBoundParameters.ContainsKey('OneViewServerProfileTemplateSettingName')) {
                    if ($ExistingGroupSettings | Where-Object category -match '^OVE_SERVER_TEMPLATES_') {
                        $_RessourceUri = $ExistingGroupSettings | Where-Object category -match '^OVE_SERVER_TEMPLATES_' | ForEach-Object resourceUri
                        if ($_RessourceUri) {
                            "[{0}] OVE Server Profile Template setting found in group: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_RessourceUri | Write-Verbose
                            [void]$SettingsUris.add($_RessourceUri)
                        }
                    }
                }
                else {
                    if ($OneViewServerProfileTemplateSettingName) {
                        $_RessourceUri = ($Settings | Where-Object category -eq $_oveTemplateCategory | Where-Object name -eq $OneViewServerProfileTemplateSettingName).resourceUri
                        if (-not $_RessourceUri) {
                            $ErrorMessage = "Setting '{0}' using the category '{1}' cannot be found in the Compute Ops Management instance!" -f $OneViewServerProfileTemplateSettingName, $_oveTemplateCategory
                            $ErrorRecord  = New-ErrorRecord ServerSettingeNotFoundInCOM ObjectNotFound -TargetObject 'Server-settings' -Message $ErrorMessage -TargetType $OneViewServerProfileTemplateSettingName.GetType().Name
                            if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
                            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
                        }
                        else { [void]$SettingsUris.add($_RessourceUri) }
                    }
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

            # Build payload and call API only when no guard warning was raised
            if ($null -eq $objStatus.Status) {

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
                    
                        $objStatus.Status  = "Complete"
                        $objStatus.Details = "Group successfully updated in $Region region"

                    }

                }
                catch {

                    if (-not $WhatIf) {
                        $objStatus.Status  = "Failed"
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Group cannot be updated!" }
                        $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                    }
                }

            } # end if ($null -eq $objStatus.Status)
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

    .PARAMETER ServerName
    Specifies the name, hostname, or serial number of the server to be assigned to the group.

    .PARAMETER GroupName 
    Specifies the name of the group to which servers will be added. 

    .PARAMETER WhatIf
    Displays the raw REST API call that would be made to COM instead of sending the request. Useful for understanding the native REST API calls used by COM.

    .EXAMPLE
    Add-HPECOMServerToGroup -Region us-west -ServerName "J208PP0026" -GroupName RHEL_Hypervisors 
   
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
        [Alias('ServerSerialNumber', 'serial', 'serialnumber')]
        [String]$ServerName,

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
  
            SerialNumber = $ServerName
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

            $ErrorMessage = "Group '{0}': Resource cannot be found in the '{1}' region!" -f $GroupName, $Region

            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }

            foreach ($Object in $ObjectStatusList) {
                $Object.Status = "Warning"
                $Object.Details = $ErrorMessage
            }

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "COM.Groups.SGSDE"
            return $ObjectStatusList

        }

        if ($Group.deviceType -match '^OVE_APPLIANCE') {

            $ErrorMessage = "Group '{0}' is an OVE appliance group (deviceType: '{1}'). Servers cannot be added to appliance groups." -f $GroupName, $Group.deviceType
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }

            foreach ($Object in $ObjectStatusList) {
                $Object.Status = "Warning"
                $Object.Details = $ErrorMessage
            }

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "COM.Groups.SGSDE"
            return $ObjectStatusList

        }


        try {
            
            $Servers = Get-HPECOMServer -Region $Region -ShowGroupMembership
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)               
        }
        
        
        "[{0}] List of servers to add to group: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList.SerialNumber | out-string) | Write-Verbose


        foreach ($Object in $ObjectStatusList) {

            "[{0}] Checking server '{1}' " -f $MyInvocation.InvocationName.ToString().ToUpper(), $Object.SerialNumber | Write-Verbose

            $Server = $Servers | Where-Object { $_.name -eq $Object.SerialNumber -or $_.host.hostname -eq $Object.SerialNumber -or $_.hardware.serialNumber -eq $Object.SerialNumber }

            if ( -not $Server) {

                # Must return a message if device not found
                $Object.Status = "Warning"
                $Object.Details = "Server cannot be found in the region!"

                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Resource cannot be found in the '{1}' region!" -f $Object.SerialNumber, $Region
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }

            } 
            elseif ($GroupMembers | Where-Object serial -eq $Server.hardware.serialNumber) {  

                # Must return a message if server already member of the group
                $Object.SerialNumber = $Server.hardware.serialNumber
                $Object.Status = "Warning"
                $Object.Details = "Server already a member of the group!"

                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Resource is already a member of the '{1}' group!" -f $Server.name, $GroupName
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }

            }
            elseif ($Server.associatedGroupname) {
                # Must return a message if server already member of another group
                $Object.SerialNumber = $Server.hardware.serialNumber
                $Object.Status = "Warning"
                $Object.Details = "Server is already a member of another group ('{0}')!" -f $Server.associatedGroupname

                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Resource is already a member of another group ('{1}')!" -f $Server.name, $Server.associatedGroupname
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }
            }
            else {       

                $Object.SerialNumber = $Server.hardware.serialNumber
                "[{0}] Server '{1}' is not a member of the group '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Server.name, $GroupName | Write-Verbose
            
                # Build DeviceList object for paylaod
                $DeviceList = [PSCustomObject]@{
                    deviceId = $server.id
                }

                # Build DeviceInfo object for tracking
                $DeviceInfo = [PSCustomObject]@{
                    serialnumber = $server.hardware.serialNumber
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
                            $Object.Exception = $Global:HPECOMInvokeReturnData

                        }
                    }
                }
            }
        }
        

        if ($ObjectStatusList.Count -gt 0) {

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
    
    .PARAMETER ServerName
    Specifies the name, hostname, or serial number of the server to be removed from the group. Serial numbers can be found using 'Get-HPECOMGroup -Region $Region -Name $GroupName -ShowMembers'.
    
    .PARAMETER GroupName 
    The name of the group from which the servers will be removed. 
 
    .PARAMETER All
    An optional parameter to remove all servers from the group.

    .PARAMETER ResetBios
    An optional parameter that initiates a factory reset of the server BIOS once the removal is complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Remove-HPECOMServerFromGroup -Region us-west -ServerName "J208PP0026" -GroupName RHEL_Hypervisors 
   
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
        [Alias('ServerSerialNumber', 'serial', 'serialnumber')]
        [String]$ServerName,

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

        if ($ServerName) {

            $objStatus.SerialNumber = $ServerName
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
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }

            foreach ($Object in $ObjectStatusList) {
                $Object.Status = "Warning"
                $Object.Details = $ErrorMessage
            }

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "COM.Groups.SGSDE"
            return $ObjectStatusList

        }

        if ($Group.deviceType -match '^OVE_APPLIANCE') {

            $ErrorMessage = "Group '{0}' is an OVE appliance group (deviceType: '{1}'). Servers cannot be removed from appliance groups." -f $GroupName, $Group.deviceType
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }

            foreach ($Object in $ObjectStatusList) {
                $Object.Status = "Warning"
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

                $Server = $Servers | Where-Object { $_.name -eq $Object.SerialNumber -or $_.host.hostname -eq $Object.SerialNumber -or $_.hardware.serialNumber -eq $Object.SerialNumber }

                if ( -not $Server) {

                    if ($WhatIf) {
                        $ErrorMessage = "Server '{0}': Resource cannot be found in the '{1}' region!" -f $Object.SerialNumber, $Region
                        Write-Warning "$ErrorMessage Cannot display API request."
                        continue
                    }

                    # Must return a message if device not found
                    $Object.Status = "Warning"
                    $Object.Details = "Server cannot be found in the region!"
                } 
                elseif (-not ( $GroupMembers | Where-Object serial -eq $Server.hardware.serialNumber)) { 

                    $Object.SerialNumber = $Server.hardware.serialNumber
                    $ErrorMessage = "Server '{0}': Resource is not a member of the '{1}' group!" -f $Server.name, $GroupName
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                    if ($WhatIf) {
                        Write-Warning "$ErrorMessage Cannot display API request."
                        continue
                    }

                    # Must return a message if server not member of the group
                    $Object.Status = "Warning"
                    $Object.Details = "Server is not a member of the group!"
                }
                else {

                    $Object.SerialNumber = $Server.hardware.serialNumber
                    "[{0}] Server '{1}' is a member of the group '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Server.name, $GroupName | Write-Verbose
                    
                    # Build DeviceList object for payload
                    $DeviceList = [PSCustomObject]@{
                        deviceId = $server.id
                    }
                    
                    # Build DeviceInfo object for tracking
                    $DeviceInfo = [PSCustomObject]@{
                        serialnumber = $server.hardware.serialNumber
                    }
                    
                    # Building the list of devices object for payload
                    [void]$DevicesList.Add($DeviceList)
                    
                    # Building the list of devices object for tracking
                    [void]$DevicesTrackingList.Add($DeviceInfo)
                }
            }
        } elseif ($all -and -not $GroupMembers) {

            "[{0}] Tracking object: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList | out-string) | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "Group '{0}': No servers are member of the group!" -f $GroupName
                Write-Warning "$ErrorMessage Cannot display API request."
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
                            $Object.Exception = $Global:HPECOMInvokeReturnData

                        }
                    }
                }
            }
        } elseif ($All -and $_group.devices) {

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
                    $ObjectStatusList[0].Exception = $Global:HPECOMInvokeReturnData
                }
            }
        }

        if ($ObjectStatusList.Count -gt 0) {

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "COM.Groups.SGSDE"
            Return $ObjectStatusList
        }
    }
}


Function Add-HPECOMApplianceToGroup {
    <#
    .SYNOPSIS
    Add a OneView appliance to an OVE appliance group in a specified region.

    .DESCRIPTION   
    This cmdlet adds a OneView appliance (VM or Synergy) to an OVE appliance group within a specified region. 
    Only groups with deviceType 'OVE_APPLIANCE_VM' or 'OVE_APPLIANCE_SYNERGY' are supported.
    
    This cmdlet does not support transferring an appliance directly from one group to another. 
    To transfer an appliance, first use 'Remove-HPECOMApplianceFromGroup' to remove it from its current group, and then use 'Add-HPECOMApplianceToGroup' to add it to the new group.

    .PARAMETER Region 
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the group is located.  
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER ApplianceName
    Specifies the name (hostname or IP address) of the appliance to be assigned to the group.
    Appliance names can be found using 'Get-HPECOMAppliance -Region $Region'.

    .PARAMETER GroupName 
    Specifies the name of the OVE appliance group to which the appliance will be added. 
    Only groups with deviceType 'OVE_APPLIANCE_VM' or 'OVE_APPLIANCE_SYNERGY' are supported.

    .PARAMETER WhatIf
    Displays the raw REST API call that would be made to COM instead of sending the request. Useful for understanding the native REST API calls used by COM.

    .EXAMPLE
    Add-HPECOMApplianceToGroup -Region eu-central -ApplianceName "composer.domain.lab" -GroupName OVE_Synergy_Group 
   
    This example adds the appliance named 'composer.domain.lab' to the OVE appliance group 'OVE_Synergy_Group' in the central EU region.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Name "composer.domain.lab" | Add-HPECOMApplianceToGroup -GroupName OVE_Synergy_Group 

    This command retrieves the appliance named 'composer.domain.lab' in the central EU region and adds it to the OVE appliance group 'OVE_Synergy_Group'.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Type SynergyComposer | Add-HPECOMApplianceToGroup -GroupName OVE_Synergy_Group

    This command retrieves all Synergy Composer appliances in the central EU region and adds them to the OVE appliance group 'OVE_Synergy_Group'.

    .EXAMPLE
    "composer.domain.lab", "oneview.domain.lab" | Add-HPECOMApplianceToGroup -Region eu-central -GroupName OVE_VM_Group 

    This command adds two appliances to the OVE appliance group 'OVE_VM_Group' in the central EU region.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the appliance names (hostnames or IP addresses).
    System.Collections.ArrayList
        List of appliances from 'Get-HPECOMAppliance'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following keys:  
        * ApplianceName - Name of the appliance attempted to be added to the group
        * Region - Name of the region where the group is located
        * Group - Name of the group to which the appliance is added
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
        [Alias('name', 'IPAddress')]
        [String]$ApplianceName,

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
  
            ApplianceName = $ApplianceName
            Region        = $Region         
            Group         = $GroupName                   
            Status        = $Null
            Details       = $Null
            Exception     = $Null
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

            $ErrorMessage = "Group '{0}': Resource cannot be found in the '{1}' region!" -f $GroupName, $Region

            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }

            foreach ($Object in $ObjectStatusList) {
                $Object.Status = "Warning"
                $Object.Details = $ErrorMessage
            }

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "COM.Groups.AGDE"
            return $ObjectStatusList

        }

        if ($Group.deviceType -notmatch '^OVE_APPLIANCE') {

            $ErrorMessage = "Group '{0}' is not a OneView appliance group (deviceType: '{1}'). Only OVE appliance groups support appliances." -f $GroupName, $Group.deviceType
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }

            foreach ($Object in $ObjectStatusList) {
                $Object.Status = "Warning"
                $Object.Details = $ErrorMessage
            }

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "COM.Groups.AGDE"
            return $ObjectStatusList

        }


        try {
            
            $Appliances = Get-HPECOMAppliance -Region $Region 
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)               
        }
        
        
        "[{0}] List of appliances to add to group: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList.ApplianceName | out-string) | Write-Verbose


        foreach ($Object in $ObjectStatusList) {

            "[{0}] Checking appliance '{1}' " -f $MyInvocation.InvocationName.ToString().ToUpper(), $Object.ApplianceName | Write-Verbose

            # Match by IP address or hostname
            if ($Object.ApplianceName -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
                $Appliance = $Appliances | Where-Object ipaddress -eq $Object.ApplianceName
            }
            else {
                $Appliance = $Appliances | Where-Object name -eq $Object.ApplianceName
            }

            if ( -not $Appliance) {

                # Must return a message if device not found
                $Object.Status = "Warning"
                $Object.Details = "Appliance cannot be found in the region!"

                if ($WhatIf) {
                    $ErrorMessage = "Appliance '{0}': Resource cannot be found in the '{1}' region!" -f $Object.ApplianceName, $Region
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }

            }
            elseif ($Appliance.applianceType -ne ($Group.deviceType -replace '^OVE_APPLIANCE_', '')) {

                # Must return a message if appliance type does not match group type
                $RequiredType = $Group.deviceType -replace '^OVE_APPLIANCE_', ''
                $ErrorMessage = "Appliance '{0}' (applianceType: '{1}') is not compatible with group '{2}' which requires '{3}' appliances." -f $Object.ApplianceName, $Appliance.applianceType, $GroupName, $RequiredType
                $Object.Status = "Warning"
                $Object.Details = $ErrorMessage

                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }

            }
            elseif ($GroupMembers | Where-Object serial -eq $Appliance.id) {  

                # Must return a message if appliance already member of the group
                $Object.Status = "Warning"
                $Object.Details = "Appliance is already a member of the group!"

                if ($WhatIf) {
                    $ErrorMessage = "Appliance '{0}': Resource is already a member of the '{1}' group!" -f $Object.ApplianceName, $GroupName
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }

            }
            else {       

                "[{0}] Appliance '{1}' is not a member of the group '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Object.ApplianceName, $GroupName | Write-Verbose
            
                # Build DeviceList object for payload
                $DeviceList = [PSCustomObject]@{
                    deviceId = $Appliance.deviceId
                }

                # Build DeviceInfo object for tracking (use the input name as provided by the user)
                $DeviceInfo = [PSCustomObject]@{
                    applianceName = $Object.ApplianceName
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

                        $DeviceSet = $DevicesTrackingList | Where-Object applianceName -eq $Object.ApplianceName

                        If ($DeviceSet) {
                            
                            $Object.Status = "Complete"
                            $Object.Details = "Appliance successfully added to '$groupname' group in '$Region' region"

                        }
                    }
                }
            }
            catch {
                
                if (-not $WhatIf) {

                    foreach ($Object in $ObjectStatusList) {

                        $DeviceSet = $DevicesTrackingList | Where-Object applianceName -eq $Object.ApplianceName

                        If ($DeviceSet) {
                            
                            $Object.Status = "Failed"
                            $Object.Details = "Appliance cannot be added to '$groupname' group!"
                            $Object.Exception = $Global:HPECOMInvokeReturnData

                        }
                    }
                }
            }
        }
        

        if ($ObjectStatusList.Count -gt 0) {

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "COM.Groups.AGDE"
            Return $ObjectStatusList
        }


    }
}


Function Remove-HPECOMApplianceFromGroup {
    <#
    .SYNOPSIS
    Remove a OneView appliance from an OVE appliance group in a specified region.

    .DESCRIPTION   
    This cmdlet removes a OneView appliance (VM or Synergy) from a specified OVE appliance group within a region.

    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the group is located.  
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER ApplianceName
    Specifies the name (hostname or IP address) of the appliance to be removed from the group.
    Appliance names can be found using 'Get-HPECOMAppliance -Region $Region' or 'Get-HPECOMGroup -Region $Region -Name $GroupName -ShowMembers'.
    
    .PARAMETER GroupName 
    The name of the OVE appliance group from which the appliance will be removed. 
 
    .PARAMETER All
    An optional parameter to remove all appliances from the group.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Remove-HPECOMApplianceFromGroup -Region eu-central -ApplianceName "composer.domain.lab" -GroupName OVE_Synergy_Group 
   
    This example removes the appliance named 'composer.domain.lab' from the OVE appliance group 'OVE_Synergy_Group' in the central EU region.

    .EXAMPLE
    Remove-HPECOMApplianceFromGroup -Region eu-central -GroupName OVE_Synergy_Group -All
 
    This example removes all appliances from the OVE appliance group 'OVE_Synergy_Group' in the central EU region.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -Name OVE_Synergy_Group -ShowMembers | Remove-HPECOMApplianceFromGroup

    This example retrieves all appliances from the group 'OVE_Synergy_Group' in the central EU region and removes them from the group.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Name "composer.domain.lab" | Remove-HPECOMApplianceFromGroup -GroupName OVE_Synergy_Group 

    This example retrieves the appliance named 'composer.domain.lab' in the central EU region and removes it from the OVE appliance group 'OVE_Synergy_Group'.

    .EXAMPLE
    "composer.domain.lab", "oneview.domain.lab" | Remove-HPECOMApplianceFromGroup -Region eu-central -GroupName OVE_Synergy_Group 

    This example removes two appliances from the OVE appliance group 'OVE_Synergy_Group' in the central EU region.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the appliance names (hostnames or IP addresses).
    System.Collections.ArrayList
        List of appliances from 'Get-HPECOMAppliance' or 'Get-HPECOMGroup -ShowMembers'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * ApplianceName - Name of the appliance attempted to be removed from the group
        * Region - Name of the region where the group is located
        * Group - Name of the group from which the appliance is removed
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
        
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = "appliancename")] 
        [Alias('name', 'IPAddress')]
        [String]$ApplianceName,

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [String]$GroupName,
        
        [Parameter(ParameterSetName = "All")]
        [Switch]$All,

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
  
            ApplianceName = $Null
            Region        = $Region                            
            Group         = $GroupName                   
            Status        = $Null
            Details       = $Null
            Exception     = $Null
        }

        if ($ApplianceName) {

            $objStatus.ApplianceName = $ApplianceName
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
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }

            foreach ($Object in $ObjectStatusList) {
                $Object.Status = "Warning"
                $Object.Details = $ErrorMessage
            }

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "COM.Groups.AGDE"
            return $ObjectStatusList

        }

        if ($Group.deviceType -notmatch '^OVE_APPLIANCE') {

            $ErrorMessage = "Group '{0}' is not a OneView appliance group (deviceType: '{1}'). Only OVE appliance groups support appliances." -f $GroupName, $Group.deviceType
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }

            foreach ($Object in $ObjectStatusList) {
                $Object.Status = "Warning"
                $Object.Details = $ErrorMessage
            }

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "COM.Groups.AGDE"
            return $ObjectStatusList

        }

        
        If (-not $All) {
        
            try {
        
                $Appliances = Get-HPECOMAppliance -Region $Region
                    
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)                
            }
                
            "[{0}] List of appliances to remove from group: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList.ApplianceName | out-string) | Write-Verbose
        

            foreach ($Object in $ObjectStatusList) {
                
                "[{0}] Checking appliance '{1}' " -f $MyInvocation.InvocationName.ToString().ToUpper(), $Object.ApplianceName | Write-Verbose

                # Match by IP address or hostname
                if ($Object.ApplianceName -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
                    $Appliance = $Appliances | Where-Object ipaddress -eq $Object.ApplianceName
                }
                else {
                    $Appliance = $Appliances | Where-Object name -eq $Object.ApplianceName
                }

                if ( -not $Appliance) {

                    if ($WhatIf) {
                        $ErrorMessage = "Appliance '{0}': Resource cannot be found in the '{1}' region!" -f $Object.ApplianceName, $Region
                        Write-Warning "$ErrorMessage Cannot display API request."
                        continue
                    }

                    # Must return a message if device not found
                    $Object.Status = "Warning"
                    $Object.Details = "Appliance cannot be found in the region!"
                }
                elseif ($GroupMembers | Where-Object serial -eq $Appliance.id) { 

                    "[{0}] Appliance '{1}' is a member of the group '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Object.ApplianceName, $GroupName | Write-Verbose
                    
                    # Build DeviceList object for payload
                    $DeviceList = [PSCustomObject]@{
                        deviceId = $Appliance.deviceId
                    
                    }
                    
                    # Build DeviceInfo object for tracking
                    $DeviceInfo = [PSCustomObject]@{
                        applianceName = $Object.ApplianceName
                    
                    }
                    
                    # Building the list of devices object for payload
                    [void]$DevicesList.Add($DeviceList)
                    
                    # Building the list of devices object for tracking
                    [void]$DevicesTrackingList.Add($DeviceInfo)
                    
                }
                else {

                    # Must return a message if appliance not member of the group
                    $Object.Status = "Warning"
                    $Object.Details = "Appliance is not a member of the group!"

                    if ($WhatIf) {
                        $ErrorMessage = "Appliance '{0}': Resource is not a member of the '{1}' group!" -f $Object.ApplianceName, $GroupName
                        Write-Warning "$ErrorMessage Cannot display API request."
                        continue
                    }

                }
            }
        }
        elseif ($all -and -not $GroupMembers) {

            "[{0}] Tracking object: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList | out-string) | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "Group '{0}': No appliances are member of the group!" -f $GroupName
                Write-Warning "$ErrorMessage Cannot display API request."
            }
            else {
                # Must return a message if no appliances are member of the group when all is used
                $ObjectStatusList[0].ApplianceName = "[All]"
                $ObjectStatusList[0].Status = "Warning"
                $ObjectStatusList[0].Details = "No appliances are member of the group!"
            }
        }     

            if ($DevicesList) {

                $Uri = (Get-COMGroupsUri) + "/" + $Group.ID + "/devices/unassign"

                # Build payload
                $payload = ConvertTo-Json -Depth 10 @{
                    devices = $DevicesList
                } 

                # Remove Devices from group  
                try {

                    $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -Body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                
                    if (-not $WhatIf) {
                   
                        foreach ($Object in $ObjectStatusList) {

                            $DeviceSet = $DevicesTrackingList | Where-Object applianceName -eq $Object.ApplianceName

                            If ($DeviceSet) {
                            
                                $Object.Status = "Complete"
                                $Object.Details = "Appliance successfully removed from '$groupname' group in '$Region' region"

                            }
                        }
                    }
                }
                catch {
                
                    if (-not $WhatIf) {

                        foreach ($Object in $ObjectStatusList) {

                            $DeviceSet = $DevicesTrackingList | Where-Object applianceName -eq $Object.ApplianceName

                            If ($DeviceSet) {
                            
                                $Object.Status = "Failed"
                                $Object.Details = "Appliance cannot be removed from '$groupname' group!"
                                $Object.Exception = $Global:HPECOMInvokeReturnData

                            }
                        }
                    }
                }
            } elseif ($All -and $GroupMembers) {

                $Uri = (Get-COMGroupsUri) + "/" + $Group.ID + "/devices/unassign" + "?force=true"

                # Remove all devices from group  
                try {

                    $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                
                    if (-not $WhatIf) {
                    
                        $ObjectStatusList[0].ApplianceName = "[All]"
                        $ObjectStatusList[0].Status = "Complete"
                        $ObjectStatusList[0].Details = "All appliances successfully removed from '$groupname' group in '$Region' region"
                    }                    
                }
                catch {
                
                    if (-not $WhatIf) {
                    
                        $ObjectStatusList[0].ApplianceName = "[All]"
                        $ObjectStatusList[0].Status = "Failed"
                        $ObjectStatusList[0].Details = "Appliances cannot be removed from '$groupname' group!"
                        $ObjectStatusList[0].Exception = $Global:HPECOMInvokeReturnData
                    }
                }
            }


            if ($ObjectStatusList.Count -gt 0) {

                $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "COM.Groups.AGDE"
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
Export-ModuleMember -Function 'Get-HPECOMGroup', 'New-HPECOMGroup', 'Remove-HPECOMGroup', 'Set-HPECOMGroup', 'Add-HPECOMServerToGroup', 'Remove-HPECOMServerFromGroup', 'Add-HPECOMApplianceToGroup', 'Remove-HPECOMApplianceFromGroup' -Alias *

# SIG # Begin signature block
# MIItTQYJKoZIhvcNAQcCoIItPjCCLToCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCeJle682RPqWMr
# aAtitxz6w+BY3AtjKBWWQpLN2ZfDmaCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# nZ+oA+rbZZyGZkz3xbUYKTGCGq0wghqpAgEBMGkwVDELMAkGA1UEBhMCR0IxGDAW
# BgNVBAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMg
# Q29kZSBTaWduaW5nIENBIFIzNgIRAMgx4fswkMFDciVfUuoKqr0wDQYJYIZIAWUD
# BAIBBQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGC
# NwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQx
# IgQgz7fA+DIW3AK2h05cbSFKQRnQ0LpdnErUkdbw4/A+zp4wDQYJKoZIhvcNAQEB
# BQAEggIAf+58dg3mupvlxsH9adeUc1oMyeDfSGwVn67YXZiQcL9jrHpna258K7Lf
# PoYybzqrANPgBcKzjY6O+JrNTNbvAcDw+R8+/vMeVMzWsH6EOZkqWDp2bl/onGaA
# DDswa2R7XtuUx7je9T4YrVZlbmZRs5lnQWKM4Vhc7+ObUTDgo8mbPXiqKTpia7VD
# KqeI92HV4p/Cs4O14ySWPjZdSclZu4wVufoJJTqBxidy+ibBm15jI3o9jmOQOhrp
# LVLzdG5yWZBV8QkX8hiJCS1EQEvh5doGcCrCySFZUUQ7ti77jsOG6oojvsXEd8Hm
# tuUmtWMQwWipa38ZDUwSk3S3/PsppflxF1qbOJPyK2++eAyu1mF5vGb3WFp+VWgY
# oSTl5XKYno5WtRLaBNJaYDSITSWm++5nJLrxvZG8Hq/EYWLq0iFfOtS1wksxsRuN
# P8+Z/01xNDh5DadLIKBOFj2cJH3aHPnTW5XJ7naOYHMP2vKU+L4DLSVN09i5lhwY
# keGU+/iygoKjGecXZ+aMh68zUi5qTTex8Io2v4438L4DI95UrU0e258DSKpSaHmx
# hGzf61yHlPfZNS/52g5a9cvV4FbtX2V5v2EOZjkgDdzBrAkmsWbpAEK9ReREk5S2
# uV/1bdfennVScH3j2jZKc9pHYOp9Pcp69Pfj/TA6jR5WrkAn3cGhgheXMIIXkwYK
# KwYBBAGCNwMDATGCF4Mwghd/BgkqhkiG9w0BBwKgghdwMIIXbAIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIGHBgsqhkiG9w0BCRABBKB4BHYwdAIBAQYJYIZIAYb9bAcBMEEw
# DQYJYIZIAWUDBAICBQAEMNn7wkKeAdrMuxpnWxyaIX8qbVkeKVlBz4P6Flo/0dL1
# h+Y05FVA4AMrR/d9SGlpewIQNSNo6UOOUUPbNLhNr8zrvRgPMjAyNjAzMTcxNDI2
# MzVaoIITOjCCBu0wggTVoAMCAQICEAwgQ0n50PdZ+5gt5AgbiHswDQYJKoZIhvcN
# AQEMBQAwaTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEw
# PwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2
# IFNIQTI1NiAyMDI1IENBMTAeFw0yNTA2MDQwMDAwMDBaFw0zNjA5MDMyMzU5NTla
# MGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UE
# AxMyRGlnaUNlcnQgU0hBMzg0IFJTQTQwOTYgVGltZXN0YW1wIFJlc3BvbmRlciAy
# MDI1IDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDbOVL7i3S35ckN
# Udj680nGm/v3iwzc7hRDJyYpFeZguz5hF/O3KXxAnuf9SrE1MpaaN0UNYa/jf5ra
# iInjXLE57SwugXHwXVrPYlFNlzt2EDFud75vJ3lt/ZIRmUKu4bHFZKpulRjp0AZE
# ILIE5qIVqheGSf4vXl59yiYNKtOcDlWB32m8w77tsz61JbgnMCIhs7aYg/IIR0pi
# xyY+X5gG56dI/s0nD2JwvW1amfrW4zpbJQ2/hFzIEDP428ls1/mRMzsXjpy8HCnS
# VliKxlH3znLmxiPh7jJQFs8HHKtPlo0xn77m2KzwYOYcKmrJUtDh4sfCmKbmLBHj
# 1NER8RO2UQU5FZOQnaE47XPNUBazqO116nXZW0VmhA6EjB1R88dKwDDf3EVV68UQ
# V/a74NWvWw5XskAJj7FwbyFYh6o8ZVTCSLIFFROADsd4DElvSJCXgYMELpkEDjAY
# 39qEzEXh+4mw6zXPCQ8FKdeYeSbXwfAeAg8qTbzt0whyFnKObvMZwJhnhuKyhRhY
# v2hOBr0kJ8UxNz3KXbpcMHTOX2t1LC+I6ZphKVpFqcXzijEBieqAHLpnz3KQ+Bad
# vtJGLfU3I/fn1aGiT7fp+TLFM+NKsJa8wrunNtGDy18hGVSfGXsblsiuQ+oxsP3M
# mgHv0wcWAuvmWNTuutwvDL5wR+nMUwIDAQABo4IBlTCCAZEwDAYDVR0TAQH/BAIw
# ADAdBgNVHQ4EFgQUVZ6552fIkRBJtDZSjXm3JMU/LfgwHwYDVR0jBBgwFoAU729T
# SunkBnx6yuKQVvYv1Ensy04wDgYDVR0PAQH/BAQDAgeAMBYGA1UdJQEB/wQMMAoG
# CCsGAQUFBwMIMIGVBggrBgEFBQcBAQSBiDCBhTAkBggrBgEFBQcwAYYYaHR0cDov
# L29jc3AuZGlnaWNlcnQuY29tMF0GCCsGAQUFBzAChlFodHRwOi8vY2FjZXJ0cy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRUaW1lU3RhbXBpbmdSU0E0MDk2
# U0hBMjU2MjAyNUNBMS5jcnQwXwYDVR0fBFgwVjBUoFKgUIZOaHR0cDovL2NybDMu
# ZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGltZVN0YW1waW5nUlNBNDA5
# NlNIQTI1NjIwMjVDQTEuY3JsMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG
# /WwHATANBgkqhkiG9w0BAQwFAAOCAgEAG34LJIfYCWrFQedRadkkjuul0CqjQ9yK
# TJXjwu2TlBYWDGkc/1a2NHeWyQQA6TdOzOa43IyJ3tW7EeVAmXgpx1OvlxDZgvL6
# XnrSl4GAzuQDgcImoap1B3ONfKuWDdgJ1+eOz3D/sE7zFSaUBqr8P49Nlk74yfFr
# f8ijJiwX4v2BZfhUnFkuWNWzkkqalKiefKwxi/sJqqRCkEOYlZTYXryYstld9TTB
# dsPL1BBOySBwe+LJAN4HWXqOX9bA5CJI1M1p9hBRHZmwnms8m7U0/M7WG0rB2JSN
# Z6cfCrkFErUFHv4P5PAb3tQdfhXRb4m8VmnzPd3cbmwDs+32o7n/oBZn7TJ/yc3n
# wP4cABKEeafLbm3pbuoXpVJFkIikavyFsCN9sGE7gxjwbZT3PBUqnpKWO4qSfF3Z
# u6KE7fd2KgIawHq2tf77FAp/hCVhKCAW8P1lZIbjKwk9g7H6FuwFMQ40W2v33Ho6
# AmefJWQOi50if6CZX4Gr5rYb74EtTkBc5VyUTGm6hRBdRkXmnexSt3bVCMX1FrTH
# hEPTaBLhfCDM362+5j62OE8gLBeYfcREv588ijFlPReDBU/7XtSpRuLlml7hh1p0
# blaMJMG+2aUzglWi8ZhG/IDJ+ZgknHT/RP6orTnBEmmDirzW84q4JA9oT0f30kJW
# 98IMGbgqOsQwgga0MIIEnKADAgECAhANx6xXBf8hmS5AQyIMOkmGMA0GCSqGSIb3
# DQEBCwUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAX
# BgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0
# ZWQgUm9vdCBHNDAeFw0yNTA1MDcwMDAwMDBaFw0zODAxMTQyMzU5NTlaMGkxCzAJ
# BgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGln
# aUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAy
# NSBDQTEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC0eDHTCphBcr48
# RsAcrHXbo0ZodLRRF51NrY0NlLWZloMsVO1DahGPNRcybEKq+RuwOnPhof6pvF4u
# GjwjqNjfEvUi6wuim5bap+0lgloM2zX4kftn5B1IpYzTqpyFQ/4Bt0mAxAHeHYNn
# QxqXmRinvuNgxVBdJkf77S2uPoCj7GH8BLuxBG5AvftBdsOECS1UkxBvMgEdgkFi
# DNYiOTx4OtiFcMSkqTtF2hfQz3zQSku2Ws3IfDReb6e3mmdglTcaarps0wjUjsZv
# kgFkriK9tUKJm/s80FiocSk1VYLZlDwFt+cVFBURJg6zMUjZa/zbCclF83bRVFLe
# GkuAhHiGPMvSGmhgaTzVyhYn4p0+8y9oHRaQT/aofEnS5xLrfxnGpTXiUOeSLsJy
# goLPp66bkDX1ZlAeSpQl92QOMeRxykvq6gbylsXQskBBBnGy3tW/AMOMCZIVNSaz
# 7BX8VtYGqLt9MmeOreGPRdtBx3yGOP+rx3rKWDEJlIqLXvJWnY0v5ydPpOjL6s36
# czwzsucuoKs7Yk/ehb//Wx+5kMqIMRvUBDx6z1ev+7psNOdgJMoiwOrUG2ZdSoQb
# U2rMkpLiQ6bGRinZbI4OLu9BMIFm1UUl9VnePs6BaaeEWvjJSjNm2qA+sdFUeEY0
# qVjPKOWug/G6X5uAiynM7Bu2ayBjUwIDAQABo4IBXTCCAVkwEgYDVR0TAQH/BAgw
# BgEB/wIBADAdBgNVHQ4EFgQU729TSunkBnx6yuKQVvYv1Ensy04wHwYDVR0jBBgw
# FoAU7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQM
# MAoGCCsGAQUFBwMIMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDov
# L29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6
# MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVk
# Um9vdEc0LmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJ
# KoZIhvcNAQELBQADggIBABfO+xaAHP4HPRF2cTC9vgvItTSmf83Qh8WIGjB/T8Ob
# XAZz8OjuhUxjaaFdleMM0lBryPTQM2qEJPe36zwbSI/mS83afsl3YTj+IQhQE7jU
# /kXjjytJgnn0hvrV6hqWGd3rLAUt6vJy9lMDPjTLxLgXf9r5nWMQwr8Myb9rEVKC
# hHyfpzee5kH0F8HABBgr0UdqirZ7bowe9Vj2AIMD8liyrukZ2iA/wdG2th9y1IsA
# 0QF8dTXqvcnTmpfeQh35k5zOCPmSNq1UH410ANVko43+Cdmu4y81hjajV/gxdEkM
# x1NKU4uHQcKfZxAvBAKqMVuqte69M9J6A47OvgRaPs+2ykgcGV00TYr2Lr3ty9qI
# ijanrUR3anzEwlvzZiiyfTPjLbnFRsjsYg39OlV8cipDoq7+qNNjqFzeGxcytL5T
# TLL4ZaoBdqbhOhZ3ZRDUphPvSRmMThi0vw9vODRzW6AxnJll38F0cuJG7uEBYTpt
# MSbhdhGQDpOXgpIUsWTjd6xpR6oaQf/DJbg3s6KCLPAlZ66RzIg9sC+NJpud/v4+
# 7RWsWCiKi9EOLLHfMR2ZyJ/+xhCx9yHbxtl5TPau1j/1MIDpMPx0LckTetiSuEtQ
# vLsNz3Qbp7wGWqbIiOWCnb5WqxL3/BAPvIXKUjPSxyZsq8WhbaM2tszWkPZPubdc
# MIIFjTCCBHWgAwIBAgIQDpsYjvnQLefv21DiCEAYWjANBgkqhkiG9w0BAQwFADBl
# MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
# d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJv
# b3QgQ0EwHhcNMjIwODAxMDAwMDAwWhcNMzExMTA5MjM1OTU5WjBiMQswCQYDVQQG
# EwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNl
# cnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwggIiMA0G
# CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz7MKnJS7J
# IT3yithZwuEppz1Yq3aaza57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS5F/WBTxS
# D1Ifxp4VpX6+n6lXFllVcq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb
# 7iDVySAdYyktzuxeTsiT+CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfISKhmV1ef
# VFiODCu3T6cw2Vbuyntd463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jHtrHEtWoY
# OAMQjdjUN6QuBX2I9YI+EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSa
# M0C/CNdaSaTC5qmgZ92kJ7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI
# 8OCiEhtmmnTK3kse5w5jrubU75KSOp493ADkRSWJtppEGSt+wJS00mFt6zPZxd9L
# BADMfRyVw4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPRiQfhvbfm
# Q6QYuKZ3AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ERElvlEFDr
# McXKchYiCd98THU/Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4KJpn15Gkv
# mB0t9dmpsh3lGwIDAQABo4IBOjCCATYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4E
# FgQU7NfjgtJxXWRM3y5nP+e6mK4cD08wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGL
# p6chnfNtyA8wDgYDVR0PAQH/BAQDAgGGMHkGCCsGAQUFBwEBBG0wazAkBggrBgEF
# BQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRw
# Oi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0Eu
# Y3J0MEUGA1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9E
# aWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwEQYDVR0gBAowCDAGBgRVHSAAMA0G
# CSqGSIb3DQEBDAUAA4IBAQBwoL9DXFXnOF+go3QbPbYW1/e/Vwe9mqyhhyzshV6p
# Grsi+IcaaVQi7aSId229GhT0E0p6Ly23OO/0/4C5+KH38nLeJLxSA8hO0Cre+i1W
# z/n096wwepqLsl7Uz9FDRJtDIeuWcqFItJnLnU+nBgMTdydE1Od/6Fmo8L8vC6bp
# 8jQ87PcDx4eo0kxAGTVGamlUsLihVo7spNU96LHc/RzY9HdaXFSMb++hUD38dglo
# hJ9vytsgjTVgHAIDyyCwrFigDkBjxZgiwbJZ9VVrzyerbHbObyMt9H5xaiNrIv8S
# uFQtJ37YOtnwtoeW/VvRXKwYw02fc7cBqZ9Xql4o4rmUMYIDjDCCA4gCAQEwfTBp
# MQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMT
# OERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2
# IDIwMjUgQ0ExAhAMIENJ+dD3WfuYLeQIG4h7MA0GCWCGSAFlAwQCAgUAoIHhMBoG
# CSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjYwMzE3
# MTQyNjM1WjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBRyvP2gEH9JNLAHHGEP5teW
# UACYdzA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCAy8+OxvaLXsm1PHRuM3b2Pi4R2
# oXie1hLNPKp6nv81wjA/BgkqhkiG9w0BCQQxMgQw20IBcUo6VqMKFtOk/1FK6AS+
# Nl983cnAO1+TP298aWF5OfyhPIGfICeOJv6qhGrZMA0GCSqGSIb3DQEBAQUABIIC
# AFmrZiQv3LMGZPWGZIuyS6rCHFVX3M2XaB/Sh+P7eC8Wb8TeUEsd6OZd0RLyY7PG
# Fjj6FgYoEGGVw7SGtXr/gM957/rLQtt0Tfj6EyerC+AVOL+tGLxVcC39HO9SJl+K
# ZVgZlxqJ2XJ2vPMfcfGFga5usT+2re57t6/YrASJArFKTVSpti0x4iVWrEJwsnMM
# EacgiHa1jjq8pBxcbGSePgQ07wJxABm98w60aG0MGij6hV8PoLmleo/o2lA3Kegh
# zcDlDchOTnRetty/DmsqTlrjKpMiUZg7NzdDL0JrpeQIdvLEf3I84+KUjm4Ycmtm
# 7MFJjhHZqaHt/1ibMFQTIBPVsQGZAmnBvdAFMRE2P3La3/6D7sj0byASkEaTGCeb
# XpTiMXJQuDo7vg3CU79emAmYdQNIXNBbyW2IbgjZlg+ZeSPUMgBKi05WYnnQ3B5R
# 2sF/ntByZWymIoDmmbpSwOLwrHPzNV9+zbhnUlYYImzA5zdA6lwK4JiX2G2zaxcE
# Fbrsbi9vyH1LlWr5u+S/fHBmesOAHAcQH0/hCxDyroNZU7FupcNjF5htpmXTKhn8
# Lm/M2PC1hNXakiWhPYoMT1lnX6CoDhSVxHBnxHBqnQQQHVYg747amn60tJ9GmmfG
# +PrQznxaICIClc2YgpMNwLoEvO/4cfyurCNEf/O2i9Gu
# SIG # End signature block
