#------------------- FUNCTIONS FOR COMPUTE OPS MANAGEMENT SETTINGS -----------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1

# Public functions
Function Get-HPECOMSetting {
    <#
    .SYNOPSIS
    Retrieve the list of settings.

    .DESCRIPTION
    This Cmdlet returns a collection of settings that are available in the specified region.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name 
    Optional parameter that can be used to specify the name of a setting to display.

    .PARAMETER Category 
    Optional parameter that can be used to specify a category of server settings to display.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMSetting -Region us-west

    Return all server settings resources located in the western US region. 

    .EXAMPLE
    Get-HPECOMSetting -Region eu-central -Name 'DLV24-ESX8.0-Installation'
   
    Return the server settings resource named 'DLV24-ESX8.0-Installation' located in the central EU region. 

    .EXAMPLE
    Get-HPECOMSetting -Region eu-central -Category Os
   
    Return the server settings resources for the OS category located in the Central EU region.

    .EXAMPLE
    Get-HPECOMSetting -Region eu-central -Name RAID-FOR_AI -ShowVolumes

    Return the volumes associated with the server internal storage setting named 'RAID-FOR_AI' located in the central EU region.

    .INPUTS
    None. You cannot pipe objects to this Cmdlet.

   #>
    [CmdletBinding(DefaultParameterSetName = 'default')]
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

        [Parameter(ParameterSetName = 'default')]
        [Parameter(Mandatory, ParameterSetName = 'ShowVolumes')]
        [String]$Name,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $categories = @('Bios', 'Os', 'Firmware', 'ExternalStorage', 'IloSecuritySettings', 'IloSettings', 'Storage')
                
                $filteredCategories = $categories | Where-Object { $_ -like "$wordToComplete*" }

                return $filteredCategories | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }

            })]
        [ValidateScript({
                $validOptions = @('Bios', 'Os', 'Firmware', 'ExternalStorage', 'IloSecuritySettings', 'IloSettings', 'Storage')
                
                if ($validOptions -contains $_) {
                    $True
                }
                else {
                    throw "'$_' is not a valid option."
                }
                
            })]    
        [String]$Category,

        [Parameter(ParameterSetName = 'ShowVolumes')]
        [Switch]$ShowVolumes,
        
        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command
  
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        try {
            $_bundles = Get-HPECOMFirmwareBaseline -Region $Region 
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

    }

    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
           
        if ($Name) {
            $Uri = (Get-COMSettingsUri) + "?filter=name eq '$name'"

        }
        elseif ($Category) {

            switch ($Category) {
                Bios { 
                    $Uri = (Get-COMSettingsUri) + "?filter=category eq 'BIOS'"
                }
                Os { 
                    $Uri = (Get-COMSettingsUri) + "?filter=category eq 'OS'"
                }                
                Firmware { 
                    $Uri = (Get-COMSettingsUri) + "?filter=category eq 'FIRMWARE'"
                }                
                ExternalStorage { 
                    $Uri = (Get-COMSettingsUri) + "?filter=category eq 'EXTERNAL_STORAGE'"
                }   
                # both IloSecuritySettings and IloSettings use the same category 'ILO_SETTINGS'     
                # Filterable properties include: settings, description, platformFamily, category and name
                # Name is always "iLO settings enabled for security".
                IloSecuritySettings { 
                    $Uri = (Get-COMSettingsUri) + "?filter=category eq 'ILO_SETTINGS' and name eq 'iLO settings enabled for security'"
                }                
                IloSettings { 
                    $Uri = (Get-COMSettingsUri) + "?filter=category eq 'ILO_SETTINGS' and name ne 'iLO settings enabled for security'"
                }                
                Storage { 
                    $Uri = (Get-COMSettingsUri) + "?filter=category eq 'STORAGE'"
                }

            }
        }
        else {
            $Uri = Get-COMSettingsUri   

        }


        try {
            [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    -ErrorAction Stop
    
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
                   
        }           
        

        $ReturnData = @()
       
        if ($Null -ne $CollectionList) {   

            # Add region to object
            $CollectionList | Add-Member -type NoteProperty -name region -value $Region
            
            if ($Name) {
                $CollectionList = $CollectionList | Where-Object name -eq $Name
            }

            $allFirmware = $allbios = $allstorage = $allos = $allIlosettings = $allExternalStorage = $true

            foreach ($setting in $CollectionList) {
                
                $_settings = $setting.settings

                # When firmware category
                if ($_settings.DEFAULT) {
                    # if ($setting.category -eq "FIRMWARE") {

                    foreach ($Item in $_settings.DEFAULT) {
                        
                        foreach ($property in $item.PSObject.Properties) {

                            $setting | Add-Member -type NoteProperty -name $property.Name -value $property.Value

                        } 
                    }                                 
                
                }
                # When other categories
                else {

                    $_Gens = ($setting.settings | Get-Member -MemberType NoteProperty).name  # it's where GEN10, GEN11 are usually provided for firmware server settings

                    foreach ($Gen in $_Gens) {

                        $_settings = $setting.settings.$($Gen)
                        
                        foreach ($property in $setting.settings.$($Gen)) {
                                
                            $_baselineName = $_bundles | Where-Object id -eq $property.id | ForEach-Object displayName

                            $_propertyName = $Gen + "FirmwareBaseline"

                            $setting | Add-Member -type NoteProperty -name $_propertyName -value $_baselineName
                                
                        } 
                    }                   
                }   
                
                # Detect object type for object repackage 
                if ("FIRMWARE" -ne $setting.Category) {
                    $allFirmware = $false
                }
                
                if ("BIOS" -ne $setting.Category) {
                    $allbios = $false                   
                }
                
                if ("STORAGE" -ne $setting.Category) {
                    $allstorage = $false
                }

                if ("OS" -ne $setting.Category) {
                    $allos = $false
                }
                
                if ("EXTERNAL_STORAGE" -ne $setting.Category) {
                    $allExternalStorage = $false
                }
                
                if ("ILO_SETTINGS" -ne $setting.Category) {
                    $allIlosettings = $false
                }                
            }         


            if ($allstorage) { 
                    
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Settings.STORAGE"   
            } 
            elseif ($allos) {
            
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Settings.OS"   
            }
            elseif ($allExternalStorage) {
                
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Settings.EXTERNAL_STORAGE"   
            }
            elseif ($allIlosettings) {
                
                if ($Category -eq "IloSecuritySettings") {
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Settings.ILO_SECURITY_SETTINGS"   
                }
                else {
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Settings.ILO_SETTINGS"   
                }
            }
            elseif ($allbios) {
            
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Settings.BIOS"   
            }   
            elseif ($allFirmware) {
                
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Settings.FIRMWARE"    
            }
            else {
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Settings"    
                
            }

            if ($ShowVolumes) {
                
                $CollectionList = $CollectionList.volumes | Sort-Object { $_.raidType }    
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Settings.STORAGE.volumes"
                
            }

            $ReturnData = $ReturnData | Sort-Object { $_.name }
        
            return $ReturnData 
                
        }
        else {

            return
                
        }     

    
    }
}

Function New-HPECOMSettingServerBios {
    <#
    .SYNOPSIS
    Creates a BIOS server setting resource in a specified region.

    .DESCRIPTION
    This Cmdlet is used to create a new bios server setting set either with a workload profile or a customized one with provided parameters.
    Bios settings enable you to apply a consistent bios configuration to servers in a group.

    For a detailed description of all iLO BIOS attribute parameters:
        - For iLO7, see https://servermanagementportal.ext.hpe.com/docs/redfishservices/ilos/ilo7/ilo7_113/ilo7_bios_resourcedefns113/
        - For iLO6, see: https://servermanagementportal.ext.hpe.com/docs/redfishservices/ilos/ilo6/ilo6_159/ilo6_bios_resourcedefns159/
        - For iLO5, see: https://servermanagementportal.ext.hpe.com/docs/redfishservices/ilos/ilo5/ilo5_304/ilo5_bios_resourcedefns304/

    Note: This cmdlet supports over 300 BIOS configuration parameters covering processor, memory, storage, network, PCI, power, thermal, security, and boot settings. 
    Due to the extensive number of parameters, this help documentation provides descriptions for the most commonly used ones. For complete parameter descriptions, 
    valid values, and platform-specific availability, please refer to the HPE iLO BIOS documentation links above. Parameter availability varies by server generation 
    and model. Use Get-Help New-HPECOMSettingServerBios -Parameter <ParameterName> to view individual parameter details, or use tab completion to discover available parameters.

    Note: If a parameter is incompatible with your iLO generation or server platform, 'Invoke-HPECOMGroupBiosConfiguration' will return an error message stating "Apply BIOS settings failed…".
    To get more detailed information about the parameters that caused these errors, access the iLO Redfish API using a GET request to /redfish/v1/Systems/1/Bios/ and inspect the @Redfish.Settings.Messages property.

    Note: If one or more unsupported parameters are selected, the other BIOS settings will still be applied successfully. Unsupported parameters will be ignored without affecting the application of the other settings.

    Warning: This cmdlet uses documented BIOS API attributes from the HPE developer portal. Some attributes may not be supported on certain server models or firmware versions. Always test your configuration to ensure compatibility with your specific hardware. 

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central').
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.
    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name
    Specifies the name of the BIOS server setting to create.

    .PARAMETER Description
    Specifies a description for the BIOS server setting.

    .PARAMETER WorkloadProfileName
    Mandatory parameter that specifies the name of a predefined workload profile to apply to the BIOS settings. Valid values and their recommended use cases:
        - Decision Support: For business intelligence workloads focused on data warehouses, data mining, or OLAP.
        - General Peak Frequency Compute: For workloads needing maximum core or memory frequency at any time; prioritizes speed over latency.
        - General Power Efficient Compute: Balances performance and power efficiency for most applications; ideal for users not tuning BIOS for specific workloads.
        - General Throughput Compute: For workloads requiring maximum sustained throughput across all cores; best for NUMA-optimized applications.
        - Graphic Processing: Optimized for GPU-based workloads; disables power management and virtualization to maximize I/O and memory bandwidth.
        - High Performance Compute (HPC): For clustered, high-utilization scientific/engineering workloads; disables power management for maximum bandwidth and compute.
        - I/O Throughput: For configurations needing maximum I/O and memory throughput; disables power management features that impact these links.
        - Low Latency: Minimizes computational latency by reducing speed/throughput and disabling power management; for RTOS or latency-sensitive workloads.
        - Mission Critical: Enables advanced memory RAS features, increasing reliability at the cost of bandwidth and latency; for reliability-focused environments.
        - Transactional Application Processing: Balances peak frequency and throughput; for OLTP and transactional business applications with database back-ends.
        - Virtual Radio Access Network (vRAN): Optimized for vRAN processing with best CPU, NIC, and hardware acceleration; supported on HPE Edgeline blades.
        - Virtualization - Max Performance: Enables all virtualization options and disables power management for maximum performance.
        - Virtualization - Power Efficient: Enables all virtualization options with power-efficient settings.

    You can set a workload profile (e.g., 'Low Latency') and still customize individual BIOS settings. If a profile conflicts with a specific BIOS setting, your individual customization takes precedence. For example, enabling 'EnergyEfficientTurbo' after selecting 'Virtual Radio Access Network (vRAN)' will override the vRAN profile's setting for that option.

    For details on which profiles affect which BIOS options and guidance on custom tuning, refer to the 'UEFI Workload-based Performance Tuning Guide'.


    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.
    
    .EXAMPLE
    New-HPECOMSettingServerBios -Region eu-central -Name "Custom-Bios-For-ESX" -Description "Description..." -WorkloadProfileName "Virtualization - Max Performance"

    This example shows how to create a new BIOS setting named "Custom-Bios-For-ESX" in the eu-central region. It sets a description and uses the "Virtualization - Max Performance" workload profile.

    .EXAMPLE
    New-HPECOMSettingServerBios -Region eu-central -Name "Custom-Bios-HPC" -Description "HPC with custom settings" -WorkloadProfileName "High Performance Compute (HPC)" `
      -AdminName Albert -AdminEmail "alb@domain.com" -AsrTimeoutMinutes Timeout10 -AutoPowerOn AlwaysPowerOn -CoreBoosting:$true -F11BootMenu:$False -ThermalConfig OptimalCooling 

    This example creates a new BIOS setting named "Custom-Bios-HPC" in the eu-central region using the "High Performance Compute (HPC)" workload profile as a base. It then customizes specific settings including admin details (AdminName and AdminEmail), ASR timeout, auto power on behavior, core boosting, F11 boot menu access, and thermal configuration for optimal cooling.

    .INPUTS
    Pipeline input is not supported.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:
        * Name - The name of the bios server setting attempted to be created
        * Region - The name of the region
        * Status - Status of the creation attempt (Failed for HTTP error return; Complete if creation is successful; Warning if no action is needed)
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.

    
   #>
    [CmdletBinding(DefaultParameterSetName = 'ilo6')]
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
        
        [ValidateScript({ $_.Length -le 1000 })]
        [String]$Description,    
        
        [Parameter (Mandatory)]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $WorkloadProfiles = @('Decision Support', 'General Peak Frequency Compute', 'General Power Efficient Compute', 'General Throughput Compute', 'Graphic Processing', 'High Performance Compute (HPC)', 'I/O Throughput', 'Low Latency', 'Mission Critical', 'Transactional Application Processing',  'Virtual Radio Access Network (vRAN)', 'Virtualization - Max Performance', 'Virtualization - Power Efficient')
                $filteredWorkloadProfiles = $WorkloadProfiles | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredWorkloadProfiles | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Decision Support', 'General Peak Frequency Compute', 'General Power Efficient Compute', 'General Throughput Compute', 'Graphic Processing', 'High Performance Compute (HPC)', 'I/O Throughput', 'Low Latency', 'Mission Critical', 'Transactional Application Processing', 'Virtual Radio Access Network (vRAN)', 'Virtualization - Max Performance', 'Virtualization - Power Efficient')]
        [String]$WorkloadProfileName,
        
        [bool]$AccessControlService,
        [bool]$AcpiHpet,
        [bool]$AcpiRootBridgePxm,
        [bool]$AcpiSlit,
        [bool]$AdjSecPrefetch,
        [string]$AdminEmail,
        [String]$AdminName,
        [string]$AdminOtherInfo,
        # Name of the server administrator
        [string]$AdminPhone,

        [bool]$AdvCrashDumpMode,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('FastFaultTolerantADDDC', 'AdvancedEcc', 'OnlineSpareAdvancedEcc', 'MirroredAdvancedEcc')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('FastFaultTolerantADDDC', 'AdvancedEcc', 'OnlineSpareAdvancedEcc', 'MirroredAdvancedEcc')]
        [String]$AdvancedMemProtection,

        [bool]$AllowLoginWithIlo,
        [bool]$Amd5LevelPage,
        [bool]$AmdCdma,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('800us', '18us')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('800us', '18us')]
        [String]$AmdCstC2Latency,

        [bool]$AmdDmaRemapping,
        [bool]$AmdL1Prefetcher,
        [bool]$AmdL2Prefetcher,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Disabled')]
        [String]$AmdMemPStates,
        
        [bool]$AmdMemoryBurstRefresh,
        [bool]$AmdPeriodicDirectoryRinse,
        [bool]$AmdSecureMemoryEncryption,
        [bool]$AmdSecureNestedPaging,
        [bool]$AmdVirtualDrtmDevice,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $WorkloadProfiles = @('Auto', 'AmdXGMILinkSpeed16', 'AmdXGMILinkSpeed18', 'AmdXGMILinkSpeed25', 'AmdXGMILinkSpeed32' )
                $filteredWorkloadProfiles = $WorkloadProfiles | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredWorkloadProfiles | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'AmdXGMILinkSpeed16', 'AmdXGMILinkSpeed18', 'AmdXGMILinkSpeed25', 'AmdXGMILinkSpeed32')]
        [String]$AmdXGMILinkSpeed,

        [bool]$ApplicationPowerBoost,

        # Use this option to configure the Automatic Server Recovery option, which enables the system to automatically reboot if the server locks up.
        [bool]$AsrStatus,

        # When Automatic Server Recovery is enabled, you can use this option to set the time to wait before rebooting the server in the event of an operating system crash or server lockup.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Timeout5', 'Timeout10', 'Timeout15', 'Timeout20', 'Timeout30')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Timeout5', 'Timeout10', 'Timeout15', 'Timeout20', 'Timeout30')]
        [string]$AsrTimeoutMinutes,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Locked', 'Unlocked')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Locked', 'Unlocked')]
        [String]$AssetTagProtection,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AlwaysPowerOn', 'AlwaysPowerOff', 'RestoreLastState')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('AlwaysPowerOn', 'AlwaysPowerOff', 'RestoreLastState')]
        [String]$AutoPowerOn,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('RetryIndefinitely', 'AttemptOnce', 'ResetAfterFailed')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('RetryIndefinitely', 'AttemptOnce', 'ResetAfterFailed')]
        [string]$BootOrderPolicy,

        [bool]$ChannelInterleaving,
        [bool]$CollabPowerControl,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('LomsAndSlots', 'LomsOnly', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('LomsAndSlots', 'LomsOnly', 'Disabled')]
        [string]$ConsistentDevNaming,

        [bool]$CoreBoosting,

        # Enter a message to be displayed on POST screen during system startup. This feature limits POST screen messaging to 62 characters, special characters are also accepted.
        [ValidateScript({
                if ($_.Length -le 62) {
                    $True
                }
                if ($_ -match '^[a-zA-Z0-9]+$') {
                    $true
                } 
                elseif ($_.Length -gt 62) {
                    throw "The POST screen message cannot have more than 62 characters!"

                }
                elseif ($_ -notmatch '^[a-zA-Z0-9]+$') {
                    throw "The POST screen message cannot contain special characters!"
                }
            })]
        [string]$CustomPostMessage,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Manual')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Manual')]
        [string]$CustomPstate0,
            
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'ForceEnabled', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'ForceEnabled', 'Disabled')]
        [string]$DataFabricCStateEnable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('DaylightSavingsTimeEnabled', 'DaylightSavingsTimeDisabled', 'Enabled', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('DaylightSavingsTimeEnabled', 'DaylightSavingsTimeDisabled', 'Enabled', 'Disabled')]
        [string]$DaylightSavingsTime,
         
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('DeterminismCtrlAuto', 'DeterminismCtrlManual')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('DeterminismCtrlAuto', 'DeterminismCtrlManual')]            
        [string]$DeterminismControl,        

        [bool]$DcuIpPrefetcher,
        [bool]$DcuStreamPrefetcher,
        [bool]$Dhcpv4,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Enabled', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Enabled', 'Disabled')]
        [string]$DirectToUpi,

        [bool]$DramControllerPowerDown,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Enabled', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Enabled', 'Disabled')]            
        [string]$DynamicPowerCapping,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'AspmL1Enabled', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'AspmL1Enabled', 'Disabled')]            
        [string]$EmbNicAspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Disabled')]            
        [string]$EmbNicEnable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'PcieGen1')]
        [string]$EmbNicLinkSpeed,
        
        [bool]$EmbNicPCIeOptionROM,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$EmbSas1Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('AllTargets', 'TwentyFourTargets', 'NoTargets')]
        [string]$EmbSas1Boot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Disabled')]
        [string]$EmbSas1Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$EmbSas1LinkSpeed,
        
        [bool]$EmbSas1PcieOptionROM,
        [bool]$EmbSata1Aspm,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Disabled')]
        [string]$EmbSata1Enable,
        
        [bool]$EmbSata1PCIeOptionROM,
        [bool]$EmbSata2Aspm,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Disabled')]
        [string]$EmbSata2Enable,
        
        [bool]$EmbSata2PCIeOptionROM,

        [bool]$EmbSata3Aspm,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Disabled')]
        [string]$EmbSata3Enable,
        
        [bool]$EmbSata3PCIeOptionROM,
        [bool]$EmbSata4Aspm,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Disabled')]
        [string]$EmbSata4Enable,
        
        [bool]$EmbSata4PCIeOptionROM,
               
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'AlwaysDisabled', 'AlwaysEnabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'AlwaysDisabled', 'AlwaysEnabled')]
        [string]$EmbVideoConnection,
        
        [bool]$EmbeddedDiagnostics,
        [bool]$EmbeddedIpxe,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('EmbeddedSata', 'IntelVrocSata', 'Ahci', 'Raid')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('EmbeddedSata', 'IntelVrocSata', 'Ahci', 'Raid')]
        [string]$EmbeddedSata,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Com1Irq4', 'Com2Irq3', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Com1Irq4', 'Com2Irq3', 'Disabled')]
        [string]$EmbeddedSerialPort,
        
        [bool]$EmbeddedUefiShell,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Disabled', 'Physical', 'Virtual')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Disabled', 'Physical', 'Virtual')]
        [string]$EmsConsole,
        
        # This attribute is a problem because in iLO5, value is an integer
        [Parameter (ParameterSetName = 'ilo6')]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('CoresPerProc0', 'CoresPerProc2', 'CoresPerProc4', 'CoresPerProc6', 'CoresPerProc8', 'CoresPerProc12', 'CoresPerProc16', 'CoresPerProc20', 'CoresPerProc24', 'CoresPerProc28', 'CoresPerProc32', 'CoresPerProc36', 'CoresPerProc40', 'CoresPerProc48', 'CoresPerProc56', 'CoresPerProc60', 'CoresPerProc64', 'CoresPerProc72', 'CoresPerProc80', 'CoresPerProc84', 'CoresPerProc96', 'CoresPerProc112')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('CoresPerProc0', 'CoresPerProc2', 'CoresPerProc4', 'CoresPerProc6', 'CoresPerProc8', 'CoresPerProc12', 'CoresPerProc16', 'CoresPerProc20', 'CoresPerProc24', 'CoresPerProc28', 'CoresPerProc32', 'CoresPerProc36', 'CoresPerProc40', 'CoresPerProc48', 'CoresPerProc56', 'CoresPerProc60', 'CoresPerProc64', 'CoresPerProc72', 'CoresPerProc80', 'CoresPerProc84', 'CoresPerProc96', 'CoresPerProc112')]
        [string]$EnabledCoresPerProcIlo6_7,

        [Parameter (ParameterSetName = 'ilo5')]
        [int]$EnabledCoresPerProcIlo5,

        [bool]$EnergyEfficientTurbo,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('MaxPerf', 'BalancedPerf', 'BalancedPower', 'PowerSavingsMode')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('MaxPerf', 'BalancedPerf', 'BalancedPower', 'PowerSavingsMode')]
        [string]$EnergyPerfBias,

        [bool]$EnhancedProcPerf,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Disabled', 'ASHRAE3', 'ASHRAE4')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Disabled', 'ASHRAE3', 'ASHRAE4')]
        [string]$ExtendedAmbientTemp,

        [bool]$ExtendedMemTest,
        [bool]$F11BootMenu,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'CardConfig')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'CardConfig')]
        [string]$FCScanPolicy,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Shutdown', 'Allow')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Shutdown', 'Allow')]
        [string]$FanFailPolicy,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('EnableMessaging', 'DisableMessaging')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('EnableMessaging', 'DisableMessaging')]
        [string]$FanInstallReq,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$FlexLom1Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Disabled')]
        [string]$FlexLom1Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$FlexLom1LinkSpeed,

        [bool]$FlexLom1PCIeOptionROM,
         

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('12Hours', '24Hours')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('12Hours', '24Hours')]
        [string]$HourFormat,


        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'HttpsOnly', 'HttpOnly', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'HttpsOnly', 'HttpOnly', 'Disabled')]
        [string]$HttpSupport,

        [bool]$HwPrefetcher,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('P0', 'P1', 'P2', 'P3', 'Auto')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('P0', 'P1', 'P2', 'P3', 'Auto')]
        [string]$InfinityFabricPstate,
        

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'DmiGen1', 'DmiGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'DmiGen1', 'DmiGen2')]            
        [string]$IntelDmiLinkFreq,
        
        [bool]$IntelNicDmaChannels,
        [bool]$IntelPerfMonitoring,
        [bool]$IntelProcVtd,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Base', 'Config1', 'Config2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Base', 'Config1', 'Config2')]
        [string]$IntelSpeedSelect,

        [bool]$IntelTxt,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'MinUpiSpeed')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'MinUpiSpeed')]
        [string]$IntelUpiFreq,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'SingleLink')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'SingleLink')]
        [string]$IntelUpiLinkEn,

        [bool]$IntelUpiPowerManagement,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('VmdDirectAssignEnabledAll', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('VmdDirectAssignEnabledAll', 'Disabled')]
        [string]$IntelVmdDirectAssign,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('IntelVmdEnabledAll', 'IntelVmdEnabledIndividual', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('IntelVmdEnabledAll', 'IntelVmdEnabledIndividual', 'Disabled')]
        [string]$IntelVmdSupport,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('None', 'Standard', 'Premium')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('None', 'Standard', 'Premium')]
        [string]$IntelVrocSupport,
                
        [bool]$IntelligentProvisioning,
        [bool]$InternalSDCardSlot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('PowerCycle', 'PowerDown', 'WarmBoot')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('PowerCycle', 'PowerDown', 'WarmBoot')]
        [string]$IpmiWatchdogTimerAction,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('IpmiWatchdogTimerOff', 'IpmiWatchdogTimerOn')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('IpmiWatchdogTimerOff', 'IpmiWatchdogTimerOn')]
        [string]$IpmiWatchdogTimerStatus,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Timeout10Min', 'Timeout15Min', 'Timeout20Min', 'Timeout30Min')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Timeout10Min', 'Timeout15Min', 'Timeout20Min', 'Timeout30Min')]
        [string]$IpmiWatchdogTimerTimeout,
        
        [string]$Ipv4Address,
        [string]$Ipv4Gateway,
        [string]$Ipv4PrimaryDNS,
        [string]$Ipv4SubnetMask,
        [string]$Ipv6Address,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Automatic', 'Manual')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Automatic', 'Manual')]
        [string]$Ipv6ConfigPolicy,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'DuidLlt', 'DUID-LLT')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'DuidLlt', 'DUID-LLT')]
        [string]$Ipv6Duid,

        [string]$Ipv6Gateway,
        [string]$Ipv6PrimaryDNS,
        [string]$Ipv6SecondaryDNS,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'AttachedMedia', 'NetworkLocation')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'AttachedMedia', 'NetworkLocation')]
        [string]$IpxeAutoStartScriptLocation,
        
        
        [bool]$IpxeBootOrder,
        [bool]$IpxeScriptAutoStart,
        [bool]$IpxeScriptVerification,
        [string]$IpxeStartupUrl,
        [bool]$LastLevelCacheAsNUMANode,
        

        [bool]$LLCDeadLineAllocation,
        [bool]$LlcPrefetch,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Low', 'Medium', 'High', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Low', 'Medium', 'High', 'Disabled')]
        [string]$LocalRemoteThreshold,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'MaxMemBusFreq4800', 'MaxMemBusFreq4400', 'MaxMemBusFreq4000', 'MaxMemBusFreq3600', 'MaxMemBusFreq3200', 'MaxMemBusFreq2933', 'MaxMemBusFreq2667', 'MaxMemBusFreq2400', 'MaxMemBusFreq2133', 'MaxMemBusFreq1867')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'MaxMemBusFreq4800', 'MaxMemBusFreq4400', 'MaxMemBusFreq4000', 'MaxMemBusFreq3600', 'MaxMemBusFreq3200', 'MaxMemBusFreq2933', 'MaxMemBusFreq2667', 'MaxMemBusFreq2400', 'MaxMemBusFreq2133', 'MaxMemBusFreq1867')]
        [string]$MaxMemBusFreqMHz,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('PerPortCtrl', 'PcieGen1', 'PcieGen2', 'PcieGen3', 'PcieGen4')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('PerPortCtrl', 'PcieGen1', 'PcieGen2', 'PcieGen3', 'PcieGen4')]
        [string]$MaxPcieSpeed,

        [bool]$MemClearWarmReset,
        [bool]$MemFastTraining,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Full', 'PartialOsConfig', 'PartialFirst4GB', 'Partial10PercentAbove4GB', 'Partial20PercentAbove4GB')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Full', 'PartialOsConfig', 'PartialFirst4GB', 'Partial10PercentAbove4GB', 'Partial20PercentAbove4GB')]
        [string]$MemMirrorMode,
        
        [bool]$MemPatrolScrubbing,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Refreshx1', 'Refreshx2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Refreshx1', 'Refreshx2')]
        [string]$MemRefreshRate,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Disabled')]
        [string]$MemoryControllerInterleaving,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NoAction', 'AllMemory')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NoAction', 'AllMemory')]
        [string]$MemoryRemap,

        [bool]$MicrosoftSecuredCoreSupport,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('C6Retention', 'C6NonRetention', 'NoState')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('C6Retention', 'C6NonRetention', 'NoState')]
        [string]$MinProcIdlePkgState,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('C6', 'C1', 'C1E', 'NoCStates')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('C6', 'C1', 'C1E', 'NoCStates')]
        [string]$MinProcIdlePower,

        [int]$MinimumSevAsid,

        [bool]$MixedPowerSupplyReporting,
        [bool]$NetworkBootRetry,
        [int]$NetworkBootRetryCount,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('NetworkBoot', 'Disabled')]
        [string]$NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('NetworkBoot', 'Disabled')]
        [string]$NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('NetworkBoot', 'Disabled')]
        [string]$NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('NetworkBoot', 'Disabled')]
        [string]$NicBoot4,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('NetworkBoot', 'Disabled')]
        [string]$NicBoot5,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('NetworkBoot', 'Disabled')]
        [string]$NicBoot6,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('NetworkBoot', 'Disabled')]
        [string]$NicBoot7,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [string]$NicBoot8,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('NetworkBoot', 'Disabled')]
        [string]$NicBoot9,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('NetworkBoot', 'Disabled')]
        [string]$NicBoot10,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('NetworkBoot', 'Disabled')]
        [string]$NicBoot11,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [string]$NicBoot12,

        [bool]$NodeInterleaving,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Flat', 'Clustered')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Flat', 'Clustered')]
        [string]$NumaGroupSizeOpt,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('OneMemoryDomainPerSocket', 'TwoMemoryDomainsPerSocket', 'FourMemoryDomainsPerSocket', 'Auto')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('OneMemoryDomainPerSocket', 'TwoMemoryDomainsPerSocket', 'FourMemoryDomainsPerSocket', 'Auto')]
        [string]$NumaMemoryDomainsPerSocket,
        
        [bool]$NvDimmNMemFunctionality,
        [bool]$NvDimmNMemInterleaving,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Disabled', 'SanitizeAndRebootSystem', 'SanitizeAndShutdownSystem', 'SanitizeAndBootToFirmwareUI', 'SanitizeToFactoryDefaults')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Disabled', 'SanitizeAndRebootSystem', 'SanitizeAndShutdownSystem', 'SanitizeAndBootToFirmwareUI', 'SanitizeToFactoryDefaults')]
        [string]$NvDimmNSanitizePolicy,

        [bool]$NvdimmLabelSupport,
        [bool]$NvmeOptionRom,
        [bool]$Ocp1AuxiliaryPower,
        [bool]$Ocp2AuxiliaryPower,
        [bool]$OmitBootDeviceEvent,
        [bool]$OpportunisticSelfRefresh,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Manual')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Manual')]
        [string]$PackagePowerLimitControlMode,

        [int]$PackagePowerLimitValue,
        [int]$PatrolScrubDuration,

        [bool]$PciPeerToPeerSerialization,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Normal', 'Medium', 'High')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Normal', 'Medium', 'High')]
        [string]$PciResourcePadding,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot20Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot20Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot20Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot20LinkSpeed,

        [bool]$PciSlot20OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot19Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot19Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot19Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot19LinkSpeed,

        [bool]$PciSlot19OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot18Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot18Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot18Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot18LinkSpeed,

        [bool]$PciSlot18OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot17Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot17Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot17Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot17LinkSpeed,

        [bool]$PciSlot17OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot16Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot16Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot16Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot16LinkSpeed,

        [bool]$PciSlot16OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot15Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot15Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot15Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot15LinkSpeed,

        [bool]$PciSlot15OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot14Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot14Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot14Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot14LinkSpeed,

        [bool]$PciSlot14OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot13Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot13Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot13Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot13LinkSpeed,

        [bool]$PciSlot13OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot12Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot12Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot12Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot12LinkSpeed,

        [bool]$PciSlot12OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot11Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot11Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot11Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot11LinkSpeed,

        [bool]$PciSlot11OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot10Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot10Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot10Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot10LinkSpeed,

        [bool]$PciSlot10OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot9Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot9Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot9Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot9LinkSpeed,

        [bool]$PciSlot9OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot8Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot8Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot8Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot8LinkSpeed,

        [bool]$PciSlot8OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot7Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot7Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot7Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot7LinkSpeed,

        [bool]$PciSlot7OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot6Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot6Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot6Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot6LinkSpeed,

        [bool]$PciSlot6OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot5Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot5Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot5Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot5LinkSpeed,

        [bool]$PciSlot5OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot4Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot4Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot4Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot4LinkSpeed,

        [bool]$PciSlot4OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot3Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot3Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot3Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot3LinkSpeed,

        [bool]$PciSlot3OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot2Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot2Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot2Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot2LinkSpeed,

        [bool]$PciSlot2OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot1Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot1Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot1Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot1LinkSpeed,
        
        [bool]$PciSlot1OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('PerformanceDeterministic', 'PowerDeterministic')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('PerformanceDeterministic', 'PowerDeterministic')]
        [string]$PerformanceDeterminism,
        
        [bool]$PersistentMemAddressRangeScrub,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('WaitForBackupPower', 'BootWithoutBackupPower', 'UseExternalBackupPower')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('WaitForBackupPower', 'BootWithoutBackupPower', 'UseExternalBackupPower')]
        [string]$PersistentMemBackupPowerPolicy,

        [bool]$PersistentMemScanMem,
        [bool]$PlatformCertificate,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('FirmwareFirst', 'OSFirst')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('FirmwareFirst', 'OSFirst')]
        [string]$PlatformRASPolicy,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('PostAsrOff', 'PostAsrOn')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('PostAsrOff', 'PostAsrOn')]
        [string]$PostAsr,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Delay30Min', 'Delay20Min', 'Delay15Min', 'Delay10Min')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Delay30Min', 'Delay20Min', 'Delay15Min', 'Delay10Min')]
        [string]$PostAsrDelay,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Disabled', 'Serial', 'All')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Disabled', 'Serial', 'All')]
        [string]$PostBootProgress,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'ForceFullDiscovery', 'ForceFastDiscovery')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'ForceFullDiscovery', 'ForceFastDiscovery')]
        [string]$PostDiscoveryMode,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Delayed20Sec', 'Delayed2Sec', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]    
        [ValidateSet('Delayed20Sec', 'Delayed2Sec', 'Disabled')]
        [string]$PostF1Prompt,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('QuietMode', 'VerboseMode')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('QuietMode', 'VerboseMode')]
        [string]$PostScreenMode,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('DisplayAll', 'DisplayEmbeddedOnly')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('DisplayAll', 'DisplayEmbeddedOnly')]
        [string]$PostVideoSupport,
        
        [bool]$PowerButton,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NoDelay', 'Random', 'Delay15Sec', 'Delay30Sec', 'Delay45Sec', 'Delay60Sec')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NoDelay', 'Random', 'Delay15Sec', 'Delay30Sec', 'Delay45Sec', 'Delay60Sec')]
        [string]$PowerOnDelay,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('DynamicPowerSavings', 'StaticLowPower', 'StaticHighPerf', 'OsControl')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('DynamicPowerSavings', 'StaticLowPower', 'StaticHighPerf', 'OsControl')]
        [string]$PowerRegulator,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'EmbNicPort1', 'EmbNicPort2', 'EmbNicPort3', 'EmbNicPort4', 'EmbNicPort5', 'EmbNicPort6', 'EmbNicPort7', 'EmbNicPort8', 'FlexLom1Port1', 'FlexLom1Port2', 'FlexLom1Port3', 'FlexLom1Port4', 'FlexLom1Port5', 'FlexLom1Port6', 'FlexLom1Port7', 'FlexLom1Port8', `
                        'Slot1NicPort1', 'Slot1NicPort2', 'Slot1NicPort3', 'Slot1NicPort4', 'Slot1NicPort5', 'Slot1NicPort6', 'Slot1NicPort7', 'Slot1NicPort8', 'Slot2NicPort1', 'Slot2NicPort3', 'Slot2NicPort4', 'Slot2NicPort5', 'Slot2NicPort6', 'Slot2NicPort7', 'Slot2NicPort8', `
                        'Slot3NicPort1', 'Slot3NicPort2', 'Slot3NicPort3', 'Slot3NicPort4', 'Slot3NicPort5', 'Slot3NicPort6', 'Slot3NicPort7', 'Slot3NicPort8', 'Slot4NicPort1', 'Slot4NicPort2', 'Slot4NicPort3', 'Slot4NicPort4', 'Slot4NicPort5', 'Slot4NicPort6', 'Slot4NicPort7', 'Slot4NicPort8', `
                        'Slot5NicPort1', 'Slot5NicPort2', 'Slot5NicPort3', 'Slot5NicPort4', 'Slot5NicPort5', 'Slot5NicPort6', 'Slot5NicPort7', 'Slot5NicPort8', 'Slot6NicPort1', 'Slot6NicPort2', 'Slot6NicPort3', 'Slot6NicPort4', 'Slot6NicPort5', 'Slot6NicPort6', 'Slot6NicPort7', 'Slot6NicPort8', `
                        'Slot7NicPort1', 'Slot7NicPort2', 'Slot7NicPort3', 'Slot7NicPort4', 'Slot7NicPort5', 'Slot7NicPort6', 'Slot7NicPort7', 'Slot7NicPort8', 'Slot8NicPort1', 'Slot8NicPort2', 'Slot8NicPort3', 'Slot8NicPort4', 'Slot8NicPort5', 'Slot8NicPort6', 'Slot8NicPort7', 'Slot8NicPort8')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'EmbNicPort1', 'EmbNicPort2', 'EmbNicPort3', 'EmbNicPort4', 'EmbNicPort5', 'EmbNicPort6', 'EmbNicPort7', 'EmbNicPort8', 'FlexLom1Port1', 'FlexLom1Port2', 'FlexLom1Port3', 'FlexLom1Port4', 'FlexLom1Port5', 'FlexLom1Port6', 'FlexLom1Port7', 'FlexLom1Port8', `
                'Slot1NicPort1', 'Slot1NicPort2', 'Slot1NicPort3', 'Slot1NicPort4', 'Slot1NicPort5', 'Slot1NicPort6', 'Slot1NicPort7', 'Slot1NicPort8', 'Slot2NicPort1', 'Slot2NicPort2', 'Slot2NicPort3', 'Slot2NicPort4', 'Slot2NicPort5', 'Slot2NicPort6', 'Slot2NicPort7', 'Slot2NicPort8', `
                'Slot3NicPort1', 'Slot3NicPort2', 'Slot3NicPort3', 'Slot3NicPort4', 'Slot3NicPort5', 'Slot3NicPort6', 'Slot3NicPort7', 'Slot3NicPort8', 'Slot4NicPort1', 'Slot4NicPort2', 'Slot4NicPort3', 'Slot4NicPort4', 'Slot4NicPort5', 'Slot4NicPort6', 'Slot4NicPort7', 'Slot4NicPort8', `
                'Slot5NicPort1', 'Slot5NicPort2', 'Slot5NicPort3', 'Slot5NicPort4', 'Slot5NicPort5', 'Slot5NicPort6', 'Slot5NicPort7', 'Slot5NicPort8', 'Slot6NicPort1', 'Slot6NicPort2', 'Slot6NicPort3', 'Slot6NicPort4', 'Slot6NicPort5', 'Slot6NicPort6', 'Slot6NicPort7', 'Slot6NicPort8', `
                'Slot7NicPort1', 'Slot7NicPort2', 'Slot7NicPort3', 'Slot7NicPort4', 'Slot7NicPort5', 'Slot7NicPort6', 'Slot7NicPort7', 'Slot7NicPort8', 'Slot8NicPort1', 'Slot8NicPort2', 'Slot8NicPort3', 'Slot8NicPort4', 'Slot8NicPort5', 'Slot8NicPort6', 'Slot8NicPort7', 'Slot8NicPort8')]
        [string]$PreBootNetwork,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'IPv4', 'IPv6')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'IPv4', 'IPv6')]
        [string]$PrebootNetworkEnvPolicy,
        
        [string]$PrebootNetworkProxy,
        [bool]$ProcAes,
        [bool]$ProcAMDBoost,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AmdFmaxBoostAuto', 'AmdFmaxBoostManual')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AmdFmaxBoostAuto', 'AmdFmaxBoostManual')]
        [string]$ProcAMDBoostControl,
        
        [int]$ProcAmdFmax,
        [bool]$ProcAmdIoVt,
        [bool]$ProcHyperthreading,
        [bool]$ProcSMT,
        [bool]$ProcTurbo,
        [bool]$ProcVirtualization,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Enabled', 'ForceEnabled', 'Disabled', 'Auto')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Enabled', 'ForceEnabled', 'Disabled', 'Auto')]
        [string]$ProcX2Apic,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Normal', 'Level1', 'Level2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Normal', 'Level1', 'Level2')]
        [string]$ProcessorConfigTDPLevel,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Disabled', 'Auto-tuned', 'Manual-tuned')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Disabled', 'Auto-tuned', 'Manual-tuned')]
        [string]$ProcessorJitterControl,
        
        [int]$ProcessorJitterControlFrequency,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('OptimizedForThroughput', 'OptimizedForLatency', 'ZeroLatency')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('OptimizedForThroughput', 'OptimizedForLatency', 'ZeroLatency')]
        [string]$ProcessorJitterControlOptimization,

        [string]$Pstate0Frequency,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('BalancedMode', 'HighEfficiencyAuto', 'HighEfficiencyOddStandby', 'HighEfficiencyEvenStandby')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('BalancedMode', 'HighEfficiencyAuto', 'HighEfficiencyOddStandby', 'HighEfficiencyEvenStandby')]
        [string]$RedundantPowerSupply,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('BalancedMode', 'HighEfficiencyAuto', 'HighEfficiencyOddStandby', 'HighEfficiencyEvenStandby')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('BalancedMode', 'HighEfficiencyAuto', 'HighEfficiencyOddStandby', 'HighEfficiencyEvenStandby')]
        [string]$RedundantPowerSupplyGpuDomain,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('BalancedMode', 'HighEfficiencyAuto', 'HighEfficiencyOddStandby', 'HighEfficiencyEvenStandby')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('BalancedMode', 'HighEfficiencyAuto', 'HighEfficiencyOddStandby', 'HighEfficiencyEvenStandby')]
        [string]$RedundantPowerSupplySystemDomain,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('InternalSdCardFirst', 'InternalKeysFirst', 'ExternalKeysFirst')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('InternalSdCardFirst', 'InternalKeysFirst', 'ExternalKeysFirst')]
        [string]$RemovableFlashBootSeq,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('CurrentRom', 'BackupRom')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('CurrentRom', 'BackupRom')]
        [string]$RomSelection,

        [bool]$SanitizeAllNvDimmN,
        [bool]$SataSanitize,
        [bool]$SataSecureErase,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Ghesv1Support', 'Ghesv2Support')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]    
        [ValidateSet('Ghesv1Support', 'Ghesv2Support')]
        [string]$SciRasSupport,

        [bool]$SecStartBackupImage,
        [bool]$SecureBootEnable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('BaudRate9600', 'BaudRate19200', 'BaudRate38400', 'BaudRate57600', 'BaudRate115200')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('BaudRate9600', 'BaudRate19200', 'BaudRate38400', 'BaudRate57600', 'BaudRate115200')]
        [string]$SerialConsoleBaudRate,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Vt100', 'Ansi', 'Vt100Plus', 'VtUtf8')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]    
        [ValidateSet('Vt100', 'Ansi', 'Vt100Plus', 'VtUtf8')]
        [string]$SerialConsoleEmulation,


        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'Physical', 'Virtual')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'Physical', 'Virtual')]
        [string]$SerialConsolePort,
        
        [string]$ServerAssetTag,
        [bool]$ServerConfigLockStatus,
        [string]$ServerOtherInfo,
        [string]$ServerPrimaryOs,
        [string]$ServiceEmail,
        [string]$ServiceName,
        [string]$ServiceOtherInfo,
        [string]$ServicePhone,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('GUI', 'Text', 'Auto')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('GUI', 'Text', 'Auto')]
        [string]$SetupBrowserSelection,     

        [bool]$Slot1MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot1NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot1NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot1NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot1NicBoot4,

        [bool]$Slot2MctpBroadcastSupport,        

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot2NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot2NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot2NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot2NicBoot4,

        [bool]$Slot3MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot3NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot3NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot3NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot3NicBoot4,

        [bool]$Slot4MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot4NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot4NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot4NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot4NicBoot4,

        [bool]$Slot5MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot5NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot5NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot5NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot5NicBoot4,

        [bool]$Slot6MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot6NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot6NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot6NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot6NicBoot4,
 
        [bool]$Slot7MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot7NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot7NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot7NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot7NicBoot4,

        [bool]$Slot8MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot8NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot8NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot8NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot8NicBoot4,
            
        [bool]$Slot9MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot9NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot9NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot9NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot9NicBoot4,

        [bool]$Slot10MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]    
        [string]$Slot10NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
  
        [string]$Slot10NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]     
        [string]$Slot10NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]      
        [string]$Slot10NicBoot4,

        [bool]$Slot11MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot11NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot11NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot11NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot11NicBoot4,


        [bool]$Slot12MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot12NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot12NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot12NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot12NicBoot4,


        [bool]$Slot13MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot13NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot13NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot13NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot13NicBoot4,


        [bool]$Slot14MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot14NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot14NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot14NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot14NicBoot4,


        [bool]$Slot15MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot15NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot15NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot15NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot15NicBoot4,


        [bool]$Slot16MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot16NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot16NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot16NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot16NicBoot4,

        [bool]$Slot17MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot17NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot17NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot17NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot17NicBoot4,

        [bool]$Slot18MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot18NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot18NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot18NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot18NicBoot4,

        [bool]$Slot19MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot19NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot19NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot19NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot19NicBoot4,

        [bool]$Slot20MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot20NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot20NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot20NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot20NicBoot4,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot1StorageBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot2StorageBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot3StorageBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot4StorageBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot5StorageBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot6StorageBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot7StorageBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot8StorageBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot9StorageBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot10StorageBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot11StorageBoot,
                
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot12StorageBoot,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot13StorageBoot,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot14StorageBoot,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot15StorageBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot16StorageBoot,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot17StorageBoot,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot18StorageBoot,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot19StorageBoot,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot20StorageBoot,

        [bool]$SpeculativeLockScheduling,
        [bool]$Sriov,


        [bool]$StaleAtoS,
        # When enabled, Sub-NUMA Clustering divides the processor's cores, cache, and memory into multiple NUMA domains. Enabling this feature can increase performance for workloads that are NUMA aware and optimized. Note: When this option is enabled, up to 1GB of system memory may become unavailable.
        
        [bool]$SubNumaClustering,

        [bool]$TPM2EndorsementDisable,
        [bool]$TPM2StorageDisable,

        # Use this option to select the fan cooling solution for the system. Optimal Cooling provides the most efficient solution by configuring fan speeds to the minimum required speed to provide adequate cooling. Increased Cooling runs fans at higher speeds to provide additional cooling. Select Increased Cooling when third-party storage controllers are cabled to the embedded hard drive cage, or if the system is experiencing thermal issues that cannot be resolved. Maximum cooling provides the maximum cooling available on this platform. Enhanced CPU Cooling runs the fans at a higher speed to provide additional cooling to the processors. Selecting Enhanced CPU Cooling may improve system performance with certain processor intensive workloads.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('OptimalCooling', 'IncreasedCooling', 'MaxCooling', 'EnhancedCPUCooling')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('OptimalCooling', 'IncreasedCooling', 'MaxCooling', 'EnhancedCPUCooling')]
        [string]$ThermalConfig,

        [bool]$ThermalShutdown,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Utc', 'Local')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Utc', 'Local')]
        [string]$TimeFormat,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('UtcM12', 'UtcM11', 'UtcM10', 'UtcM9 ', 'UtcM8', 'UtcM7', 'UtcM6', 'UtcM5', 'UtcM430', 'UtcM4', 'UtcM330', 'UtcM3', 'UtcM2', 'UtcM1', 'Utc0 ', 'UtcP1', 'UtcP2', 'UtcP3', 'UtcP330', 'UtcP4', 'UtcP430', 'UtcP5', 'UtcP530', 'UtcP545', 'UtcP6', 'UtcP630', 'UtcP7', 'UtcP8', 'UtcP9', 'UtcP930', 'UtcP10', 'UtcP11', 'UtcP12', 'UtcP13', 'UtcP14', 'Unspecified')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('UtcM12', 'UtcM11', 'UtcM10', 'UtcM9 ', 'UtcM8', 'UtcM7', 'UtcM6', 'UtcM5', 'UtcM430', 'UtcM4', 'UtcM330', 'UtcM3', 'UtcM2', 'UtcM1', 'Utc0 ', 'UtcP1', 'UtcP2', 'UtcP3', 'UtcP330', 'UtcP4', 'UtcP430', 'UtcP5', 'UtcP530', 'UtcP545', 'UtcP6', 'UtcP630', 'UtcP7', 'UtcP8', 'UtcP9', 'UtcP930', 'UtcP10', 'UtcP11', 'UtcP12', 'UtcP13', 'UtcP14', 'Unspecified')]
        [string]$TimeZone,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NoAction', 'Fifo', 'Crb')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NoAction', 'Fifo', 'Crb')]
        [string]$Tpm20SoftwareInterfaceOperation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NoAction', 'Fifo', 'Crb')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NoAction', 'Fifo', 'Crb')]
        [string]$Tpm20SoftwareInterfaceStatus,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NoAction', 'Clear')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NoAction', 'Clear')]
        [string]$Tpm2Operation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NotSpecified', 'Sha1', 'Sha256', 'Sha1Sha256', 'Sha256Sha384')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NotSpecified', 'Sha1', 'Sha256', 'Sha1Sha256', 'Sha256Sha384')]
        [string]$TpmActivePcrs,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('None', 'StMicroGen10', 'IntelPttFTpm', 'NationzTpm20', 'STMicroGen10Plus', 'STMicroGen11')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('None', 'StMicroGen10', 'IntelPttFTpm', 'NationzTpm20', 'STMicroGen10Plus', 'STMicroGen11')]
        [string]$TpmChipId,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NotSpecified', 'NonFipsMode', 'FipsMode')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NotSpecified', 'NonFipsMode', 'FipsMode')]
        [string]$TpmFips,
                
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NoAction', 'RegularMode', 'FipsMode')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NoAction', 'RegularMode', 'FipsMode')]
        [string]$TpmFipsModeSwitch,
                        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NoAction', 'Tpm12', 'Tpm20')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NoAction', 'Tpm12', 'Tpm20')]
        [string]$TpmModeSwitchOperation,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NoAction', 'Enable', 'Disable', 'Clear')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NoAction', 'Enable', 'Disable', 'Clear')]
        [string]$TpmOperation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NotPresent', 'PresentDisabled', 'PresentEnabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NotPresent', 'PresentDisabled', 'PresentEnabled')]
        [string]$TpmState,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NoTpm', 'Tpm12', 'Tpm20')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NoTpm', 'Tpm12', 'Tpm20')]
        [string]$TpmType,
        
        [bool]$TpmUefiOpromMeasuring,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Hidden', 'Visible')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Hidden', 'Visible')]
        [string]$TpmVisibility,

        [bool]$TransparentSecureMemoryEncryption,
        [bool]$UefiOptimizedBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Disabled', 'ErrorsOnly', 'Medium', 'Network', 'Verbose', 'Custom')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Disabled', 'ErrorsOnly', 'Medium', 'Network', 'Verbose', 'Custom')]
        [string]$UefiSerialDebugLevel,

        [bool]$UefiShellBootOrder,
        [bool]$UefiShellPhysicalPresenceKeystroke,
        [bool]$UefiShellScriptVerification,
        [bool]$UefiShellStartup,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'AttachedMedia', 'NetworkLocation')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'AttachedMedia', 'NetworkLocation')]
        [string]$UefiShellStartupLocation,
        
        [string]$UefiShellStartupUrl,
        [bool]$UefiShellStartupUrlFromDhcp,
        [bool]$UefiVariableAccessFwControl,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Maximum', 'Minimum')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Maximum', 'Minimum')]
        [string]$UncoreFreqScaling,

        [bool]$UpiPrefetcher,
        [string]$UrlBootFile,
        [string]$UrlBootFile2,
        [bool]$UsbBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('UsbEnabled', 'UsbDisabled', 'ExternalUsbDisabled', 'InternalUsbDisabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('UsbEnabled', 'UsbDisabled', 'ExternalUsbDisabled', 'InternalUsbDisabled')]
        [string]$UsbControl,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('English', 'Japanese', 'Chinese')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('English', 'Japanese', 'Chinese')]
        [string]$UtilityLang,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('OptionalVideoOnly', 'BothVideoEnabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('OptionalVideoOnly', 'BothVideoEnabled')]
        [string]$VideoOptions,

        [bool]$VirtualInstallDisk,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Com1Irq4', 'Com2Irq3', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Com1Irq4', 'Com2Irq3', 'Disabled')]
        [string]$VirtualSerialPort,
        
        
        [bool]$VlanControl,
        [int]$VlanId,
        [int]$VlanPriority,
        [bool]$WakeOnLan,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Enabled', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Enabled', 'Disabled')]
        [string]$XptPrefetcher,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'x4', 'x8', 'x16')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'x4', 'x8', 'x16')]
        [string]$XGMIForceLinkWidth,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'x4', 'x8', 'x16')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'x4', 'x8', 'x16')]
        [string]$XGMIMaxLinkWidth,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('SoftwareInitiator', 'AdapterInitiator')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('SoftwareInitiator', 'AdapterInitiator')]
        [string]$iSCSIPolicy,

        [bool]$iSCSISoftwareInitiator,

        [Switch]$WhatIf
       
    ) 
    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-COMSettingsUri
        $NewBiosSettingStatus = [System.Collections.ArrayList]::new()
        
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
            $SettingResource = Get-HPECOMSetting -Region $Region -Name $Name -Category Bios

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)

        }

        if ($SettingResource) {

            "[{0}] Setting '{1}' is already present in the '{2}' region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
    
            if ($WhatIf) {
                $ErrorMessage = "Setting '{0}': Resource is already present in the '{1}' region! No action needed." -f $Name, $Region
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "Setting already exists in the region! No action needed."
            }

        }
        else {

            # Map the workload profile friendly name to the actual value required by the API
            switch ($WorkloadProfileName) {
                "General Power Efficient Compute"       { $WorkloadProfileNameValue = "GeneralPowerEfficientCompute" }
                "General Peak Frequency Compute"        { $WorkloadProfileNameValue = "GeneralPeakFrequencyCompute" }
                "General Throughput Compute"            { $WorkloadProfileNameValue = "GeneralThroughputCompute" }
                "Virtualization - Power Efficient"      { $WorkloadProfileNameValue = "Virtualization-PowerEfficient" }
                "Virtualization - Max Performance"      { $WorkloadProfileNameValue = "Virtualization-MaxPerformance" }
                "Low Latency"                           { $WorkloadProfileNameValue = "LowLatency" }
                "Mission Critical"                      { $WorkloadProfileNameValue = "MissionCritical" }
                "Transactional Application Processing"  { $WorkloadProfileNameValue = "TransactionalApplicationProcessing" }
                "High Performance Compute (HPC)"        { $WorkloadProfileNameValue = "HighPerformanceCompute(HPC)" }
                "Decision Support"                      { $WorkloadProfileNameValue = "DecisionSupport" }
                "Graphic Processing"                    { $WorkloadProfileNameValue = "GraphicProcessing" }
                "I/O Throughput"                        { $WorkloadProfileNameValue = "I/OThroughput" }
                "Virtual Radio Access Network (vRAN)"  { $WorkloadProfileNameValue = "vRAN" }
                # "Custom"                           { $WorkloadProfileNameValue = "Custom" }
            }

            $Attributes = @{
                WorkloadProfile = $WorkloadProfileNameValue
                
            }

            # Boolean parameters

            #Region
            $boolParametersList = @(
                'AccessControlService',
                'AcpiHpet',
                'AcpiRootBridgePxm',
                'AcpiSlit',
                'AdjSecPrefetch',
                'AdvCrashDumpMode',
                'AllowLoginWithIlo',
                'Amd5LevelPage',
                'AmdCdma',
                'AmdDmaRemapping',
                'AmdL1Prefetcher',
                'AmdL2Prefetcher',
                'AmdMemoryBurstRefresh',
                'AmdPeriodicDirectoryRinse',
                'AmdSecureMemoryEncryption',
                'AmdSecureNestedPaging',
                'AmdVirtualDrtmDevice',
                'ApplicationPowerBoost',
                'AsrStatus',
                'ChannelInterleaving',
                'CollabPowerControl',
                'CoreBoosting',
                'DcuIpPrefetcher',
                'DcuStreamPrefetcher',
                'Dhcpv4',
                'DramControllerPowerDown',
                'EmbNicPCIeOptionROM',
                'EmbSas1PcieOptionROM',
                'EmbSata1Aspm',
                'EmbSata1PCIeOptionROM',
                'EmbSata2Aspm',
                'EmbSata2PCIeOptionROM',
                'EmbSata3Aspm',
                'EmbSata3PCIeOptionROM',
                'EmbSata4Aspm',
                'EmbSata4PCIeOptionROM',
                'EmbeddedDiagnostics',
                'EmbeddedIpxe',
                'EmbeddedUefiShell',
                'EnergyEfficientTurbo',
                'EnhancedProcPerf',
                'ExtendedMemTest',
                'F11BootMenu',
                'FlexLom1PCIeOptionROM',
                'HwPrefetcher',
                'IntelNicDmaChannels',
                'IntelPerfMonitoring',
                'IntelProcVtd',
                'IntelTxt',
                'IntelUpiPowerManagement',
                'IntelligentProvisioning',
                'InternalSDCardSlot',
                'IpxeBootOrder',
                'IpxeScriptAutoStart',
                'IpxeScriptVerification',
                'LastLevelCacheAsNUMANode',
                'LLCDeadLineAllocation',
                'LlcPrefetch',
                'MemClearWarmReset',
                'MemFastTraining',
                'MemPatrolScrubbing',
                'MicrosoftSecuredCoreSupport',
                'MixedPowerSupplyReporting',
                'NetworkBootRetry',
                'NodeInterleaving',
                'NvDimmNMemFunctionality',
                'NvDimmNMemInterleaving',
                'NvdimmLabelSupport',
                'NvmeOptionRom',
                'Ocp1AuxiliaryPower',
                'Ocp2AuxiliaryPower',
                'OmitBootDeviceEvent',
                'OpportunisticSelfRefresh',
                'PciPeerToPeerSerialization',
                'PciSlot20OptionROM',
                'PciSlot19OptionROM',
                'PciSlot18OptionROM',
                'PciSlot17OptionROM',
                'PciSlot16OptionROM',
                'PciSlot15OptionROM',
                'PciSlot14OptionROM',
                'PciSlot13OptionROM',
                'PciSlot12OptionROM',
                'PciSlot11OptionROM',
                'PciSlot10OptionROM',
                'PciSlot9OptionROM',
                'PciSlot8OptionROM',
                'PciSlot7OptionROM',
                'PciSlot6OptionROM',
                'PciSlot5OptionROM',
                'PciSlot4OptionROM',
                'PciSlot3OptionROM',
                'PciSlot2OptionROM',
                'PciSlot1OptionROM',
                'PersistentMemAddressRangeScrub',
                'PersistentMemScanMem',
                'PlatformCertificate',
                'PowerButton',
                'ProcAes',
                'ProcAMDBoost',
                'ProcAmdIoVt',
                'ProcHyperthreading',
                'ProcSMT',
                'ProcTurbo',
                'ProcVirtualization',
                'SanitizeAllNvDimmN',
                'SataSanitize',
                'SataSecureErase',
                'SecStartBackupImage',
                'SecureBootEnable',
                'ServerConfigLockStatus',
                'Slot1MctpBroadcastSupport',
                'Slot2MctpBroadcastSupport',
                'Slot3MctpBroadcastSupport',
                'Slot4MctpBroadcastSupport',
                'Slot5MctpBroadcastSupport',
                'Slot6MctpBroadcastSupport',
                'Slot7MctpBroadcastSupport',
                'Slot8MctpBroadcastSupport',
                'Slot9MctpBroadcastSupport',
                'Slot10MctpBroadcastSupport',
                'Slot11MctpBroadcastSupport',
                'Slot12MctpBroadcastSupport',
                'Slot13MctpBroadcastSupport',
                'Slot14MctpBroadcastSupport',
                'Slot15MctpBroadcastSupport',
                'Slot16MctpBroadcastSupport',
                'Slot17MctpBroadcastSupport',
                'Slot18MctpBroadcastSupport',
                'Slot19MctpBroadcastSupport',
                'Slot20MctpBroadcastSupport',
                'SpeculativeLockScheduling',
                'Sriov',
                'StaleAtoS',
                'SubNumaClustering',
                'TPM2EndorsementDisable',
                'TPM2StorageDisable',
                'ThermalShutdown',
                'TpmUefiOpromMeasuring',
                'TransparentSecureMemoryEncryption',
                'UefiOptimizedBoot',
                'UefiShellBootOrder',
                'UefiShellPhysicalPresenceKeystroke',
                'UefiShellScriptVerification',
                'UefiShellStartup',
                'UefiShellStartupUrlFromDhcp',
                'UefiVariableAccessFwControl',
                'UpiPrefetcher',
                'UsbBoot',
                'VirtualInstallDisk',
                'VlanControl',
                'WakeOnLan',
                'iSCSISoftwareInitiator'
    
            )
            #EndRegion
           
            $RequireCustomProfile = $False
    
            foreach ($boolparameter in $boolParametersList) {
            
                if ($PSBoundParameters.ContainsKey($boolparameter) -and $PSBoundParameters.ContainsKey('WorkloadProfileName')) {
        
                    $RequireCustomProfile = $True
        
                    if ($PSBoundParameters[$boolparameter] -eq $True) {
            
                        $Attributes."$boolparameter" = "Enabled"
            
                    }
                    else {
                        $Attributes."$boolparameter" = "Disabled"
            
                    }
                }        
            }
    
    
            #  String + Integer parameters

            #Region
            $stringparametersList = @(
                'AdminEmail',
                'AdminName',
                'AdminOtherInfo',
                'AdminPhone',
                'AdvancedMemProtection',
                'AmdCstC2Latency',
                'AmdMemPStates',
                'AmdXGMILinkSpeed',
                'AsrTimeoutMinutes',
                'AssetTagProtection',
                'AutoPowerOn',
                'BootOrderPolicy',
                'ConsistentDevNaming',
                'CustomPostMessage',
                'CustomPstate0',
                'DataFabricCStateEnable',
                'DaylightSavingsTime',
                'DeterminismControl',
                'DirectToUpi',
                'DynamicPowerCapping',
                'EmbNicAspm',
                'EmbNicEnable',
                'EmbNicLinkSpeed',
                'EmbSas1Aspm',
                'EmbSas1Boot',
                'EmbSas1Enable',
                'EmbSas1LinkSpeed',
                'EmbSata1Enable',
                'EmbSata2Enable',
                'EmbSata3Enable',
                'EmbSata4Enable',
                'EmbVideoConnection',
                'EmbeddedSata',
                'EmbeddedSerialPort',
                'EmsConsole',
                # 'EnabledCoresPerProcIlo6_7', # Removed as iLO5 and 6 do not use the same value types
                # 'EnabledCoresPerProcIlo5',
                'EnergyPerfBias',
                'ExtendedAmbientTemp',
                'FCScanPolicy',
                'FanFailPolicy',
                'FanInstallReq',
                'FlexLom1Aspm',
                'FlexLom1Enable',
                'FlexLom1LinkSpeed',
                'HourFormat',
                'HttpSupport',
                'InfinityFabricPstate',
                'IntelDmiLinkFreq',
                'IntelSpeedSelect',
                'IntelUpiFreq',
                'IntelUpiLinkEn',
                'IntelVmdDirectAssign',
                'IntelVmdSupport',
                'IntelVrocSupport',
                'IpmiWatchdogTimerAction',
                'IpmiWatchdogTimerStatus',
                'IpmiWatchdogTimerTimeout',
                'Ipv4Address',
                'Ipv4Gateway',
                'Ipv4PrimaryDNS',
                'Ipv4SubnetMask',
                'Ipv6Address',
                'Ipv6ConfigPolicy',
                'Ipv6Duid',
                'Ipv6Gateway',
                'Ipv6PrimaryDNS',
                'Ipv6SecondaryDNS',
                'IpxeAutoStartScriptLocation',
                'IpxeStartupUrl',
                'LocalRemoteThreshold',
                'MaxMemBusFreqMHz',
                'MaxPcieSpeed',
                'MemMirrorMode',
                'MemRefreshRate',
                'MemoryControllerInterleaving',
                'MemoryRemap',
                'MinProcIdlePkgState',
                'MinProcIdlePower',
                'MinimumSevAsid',
                'NetworkBootRetryCount',
                'NicBoot1',
                'NicBoot2',
                'NicBoot3',
                'NicBoot4',
                'NicBoot5',
                'NicBoot6',
                'NicBoot7',
                'NicBoot8',
                'NicBoot9',
                'NicBoot10',
                'NicBoot11',
                'NicBoot12',
                'NumaGroupSizeOpt',
                'NumaMemoryDomainsPerSocket',
                'NvDimmNSanitizePolicy',
                'PackagePowerLimitControlMode',
                'PackagePowerLimitValue',
                'PatrolScrubDuration',
                'PciResourcePadding',
                'PciSlot20Aspm',
                'PciSlot20Bifurcation',
                'PciSlot20Enable',
                'PciSlot20LinkSpeed',
                'PciSlot19Aspm',
                'PciSlot19Bifurcation',
                'PciSlot19Enable',
                'PciSlot19LinkSpeed',
                'PciSlot18Aspm',
                'PciSlot18Bifurcation',
                'PciSlot18Enable',
                'PciSlot18LinkSpeed',
                'PciSlot17Aspm',
                'PciSlot17Bifurcation',
                'PciSlot17Enable',
                'PciSlot17LinkSpeed',
                'PciSlot16Aspm',
                'PciSlot16Bifurcation',
                'PciSlot16Enable',
                'PciSlot16LinkSpeed',
                'PciSlot15Aspm',
                'PciSlot15Bifurcation',
                'PciSlot15Enable',
                'PciSlot15LinkSpeed',
                'PciSlot14Aspm',
                'PciSlot14Bifurcation',
                'PciSlot14Enable',
                'PciSlot14LinkSpeed',
                'PciSlot13Aspm',
                'PciSlot13Bifurcation',
                'PciSlot13Enable',
                'PciSlot13LinkSpeed',
                'PciSlot12Aspm',
                'PciSlot12Bifurcation',
                'PciSlot12Enable',
                'PciSlot12LinkSpeed',
                'PciSlot11Aspm',
                'PciSlot11Bifurcation',
                'PciSlot11Enable',
                'PciSlot11LinkSpeed',
                'PciSlot10Aspm',
                'PciSlot10Bifurcation',
                'PciSlot10Enable',
                'PciSlot10LinkSpeed',
                'PciSlot9Aspm',
                'PciSlot9Bifurcation',
                'PciSlot9Enable',
                'PciSlot9LinkSpeed',
                'PciSlot8Aspm',
                'PciSlot8Bifurcation',
                'PciSlot8Enable',
                'PciSlot8LinkSpeed',
                'PciSlot7Aspm',
                'PciSlot7Bifurcation',
                'PciSlot7Enable',
                'PciSlot7LinkSpeed',
                'PciSlot6Aspm',
                'PciSlot6Bifurcation',
                'PciSlot6Enable',
                'PciSlot6LinkSpeed',
                'PciSlot5Aspm',
                'PciSlot5Bifurcation',
                'PciSlot5Enable',
                'PciSlot5LinkSpeed',
                'PciSlot4Aspm',
                'PciSlot4Bifurcation',
                'PciSlot4Enable',
                'PciSlot4LinkSpeed',
                'PciSlot3Aspm',
                'PciSlot3Bifurcation',
                'PciSlot3Enable',
                'PciSlot3LinkSpeed',
                'PciSlot2Aspm',
                'PciSlot2Bifurcation',
                'PciSlot2Enable',
                'PciSlot2LinkSpeed',
                'PciSlot1Aspm',
                'PciSlot1Bifurcation',
                'PciSlot1Enable',
                'PciSlot1LinkSpeed',
                'PerformanceDeterminism',
                'PersistentMemBackupPowerPolicy',
                'PlatformRASPolicy',
                'PostAsr',
                'PostAsrDelay',
                'PostBootProgress',
                'PostDiscoveryMode',
                'PostF1Prompt',
                'PostScreenMode',
                'PostVideoSupport',
                'PowerOnDelay',
                'PowerRegulator',
                'PreBootNetwork',
                'PrebootNetworkEnvPolicy',
                'PrebootNetworkProxy',
                'ProcAMDBoostControl',
                'ProcAmdFmax',
                'ProcX2Apic',
                'ProcessorConfigTDPLevel',
                'ProcessorJitterControl',
                'ProcessorJitterControlFrequency',
                'ProcessorJitterControlOptimization',
                'Pstate0Frequency',
                'RedundantPowerSupply',
                'RedundantPowerSupplyGpuDomain',
                'RedundantPowerSupplySystemDomain',
                'RemovableFlashBootSeq',
                'RomSelection',
                'SciRasSupport',
                'SerialConsoleBaudRate',
                'SerialConsoleEmulation',
                'SerialConsolePort',
                'ServerAssetTag',
                'ServerOtherInfo',
                'ServerPrimaryOs',
                'ServiceEmail',
                'ServiceName',
                'ServiceOtherInfo',
                'ServicePhone',
                'SetupBrowserSelection',
                'Slot1NicBoot1',
                'Slot1NicBoot2',
                'Slot1NicBoot3',
                'Slot1NicBoot4',
                'Slot2NicBoot1',
                'Slot2NicBoot2',
                'Slot2NicBoot3',
                'Slot2NicBoot4',
                'Slot3NicBoot1',
                'Slot3NicBoot2',
                'Slot3NicBoot3',
                'Slot3NicBoot4',
                'Slot4NicBoot1',
                'Slot4NicBoot2',
                'Slot4NicBoot3',
                'Slot4NicBoot4',
                'Slot5NicBoot1',
                'Slot5NicBoot2',
                'Slot5NicBoot3',
                'Slot5NicBoot4',
                'Slot6NicBoot1',
                'Slot6NicBoot2',
                'Slot6NicBoot3',
                'Slot6NicBoot4',
                'Slot7NicBoot1',
                'Slot7NicBoot2',
                'Slot7NicBoot3',
                'Slot7NicBoot4',
                'Slot8NicBoot1',
                'Slot8NicBoot2',
                'Slot8NicBoot3',
                'Slot8NicBoot4',
                'Slot9NicBoot1',
                'Slot9NicBoot2',
                'Slot9NicBoot3',
                'Slot9NicBoot4',
                'Slot10NicBoot1',
                'Slot10NicBoot2',
                'Slot10NicBoot3',
                'Slot10NicBoot4',
                'Slot11NicBoot1',
                'Slot11NicBoot2',
                'Slot11NicBoot3',
                'Slot11NicBoot4',
                'Slot12NicBoot1',
                'Slot12NicBoot2',
                'Slot12NicBoot3',
                'Slot12NicBoot4',
                'Slot13NicBoot1',
                'Slot13NicBoot2',
                'Slot13NicBoot3',
                'Slot13NicBoot4',
                'Slot14NicBoot1',
                'Slot14NicBoot2',
                'Slot14NicBoot3',
                'Slot14NicBoot4',
                'Slot15NicBoot1',
                'Slot15NicBoot2',
                'Slot15NicBoot3',
                'Slot15NicBoot4',
                'Slot16NicBoot1',
                'Slot16NicBoot2',
                'Slot16NicBoot3',
                'Slot16NicBoot4',
                'Slot17NicBoot1',
                'Slot17NicBoot2',
                'Slot17NicBoot3',
                'Slot17NicBoot4',
                'Slot18NicBoot1',
                'Slot18NicBoot2',
                'Slot18NicBoot3',
                'Slot18NicBoot4',
                'Slot19NicBoot1',
                'Slot19NicBoot2',
                'Slot19NicBoot3',
                'Slot19NicBoot4',
                'Slot20NicBoot1',
                'Slot20NicBoot2',
                'Slot20NicBoot3',
                'Slot20NicBoot4',
                'Slot1StorageBoot',
                'Slot2StorageBoot',
                'Slot3StorageBoot',
                'Slot4StorageBoot',
                'Slot5StorageBoot',
                'Slot6StorageBoot',
                'Slot7StorageBoot',
                'Slot8StorageBoot',
                'Slot9StorageBoot',
                'Slot10StorageBoot',
                'Slot11StorageBoot',
                'Slot12StorageBoot',
                'Slot13StorageBoot',
                'Slot14StorageBoot',
                'Slot15StorageBoot',
                'Slot16StorageBoot',
                'Slot17StorageBoot',
                'Slot18StorageBoot',
                'Slot19StorageBoot',
                'Slot20StorageBoot',
                'ThermalConfig',
                'TimeFormat',
                'TimeZone',
                'Tpm20SoftwareInterfaceOperation',
                'Tpm20SoftwareInterfaceStatus',
                'Tpm2Operation',
                'TpmActivePcrs',
                'TpmChipId',
                'TpmFips',
                'TpmFipsModeSwitch',
                'TpmModeSwitchOperation',
                'TpmOperation',
                'TpmState',
                'TpmType',
                'TpmVisibility',
                'UefiSerialDebugLevel',
                'UefiShellStartupLocation',
                'UefiShellStartupUrl',
                'UncoreFreqScaling',
                'UrlBootFile',
                'UrlBootFile2',
                'UsbControl',
                'UtilityLang',
                'VideoOptions',
                'VirtualSerialPort',
                'VlanId',
                'VlanPriority',
                'XptPrefetcher',
                'XGMIForceLinkWidth',
                'XGMIMaxLinkWidth',
                'iSCSIPolicy'
            )
            #EndRegion
    
            foreach ($stringparameter in $stringparametersList) {

                if ($PSBoundParameters.ContainsKey($stringparameter) -and $PSBoundParameters.ContainsKey('WorkloadProfileName')) {

                    $RequireCustomProfile = $True
    
                    $param1Value = $PSBoundParameters[$stringparameter]
    
                    $Attributes."$stringparameter" = $param1Value
                }
            }
    
    
            if ($PSBoundParameters.ContainsKey('EnabledCoresPerProcIlo6_7') -and $PSBoundParameters.ContainsKey('WorkloadProfileName')) {
    
                $RequireCustomProfile = $True
    
                $Attributes.EnabledCoresPerProc = $EnabledCoresPerProcIlo6_7
            } 
            elseif ($PSBoundParameters.ContainsKey('EnabledCoresPerProcIlo5') -and $PSBoundParameters.ContainsKey('WorkloadProfileName')) {
    
                $RequireCustomProfile = $True
    
                $Attributes.EnabledCoresPerProc = $EnabledCoresPerProcIlo5
                
            }
    
    
    
            if ($AsrTimeoutMinutes) {
                $Attributes.AsrStatus = "Enabled"
    
            }
    
    
            if ($SubNumaClustering) {
                # Options that must be enabled when Sub-Numa Clustering (SNC) is enabled:
                $Attributes.XptPrefetcher = "Enabled"
                $Attributes.UpiPrefetcher = "Enabled"
            }
    
                   
            # Build payload
    
            # Create a body for a custom workload profile
            if ($RequireCustomProfile) {
                
                $Default = @{ 
                    redfishData                 = @{
                        Attributes = $Attributes
                    }
                    enableCustomWorkloadProfile = $True
                }
            }
            else {
                
                $Default = @{ 
                    redfishData = @{
                        Attributes = $Attributes
                    }
                }    
            }
    
            $Settings = @{ 
                DEFAULT = $Default
            }
    
            $payload = @{ 
                name           = $Name
                category       = "BIOS"
                description    = $Description
                settings       = $Settings                  
            }
    
            $payload = ConvertTo-Json $payload -Depth 10 
    
            try {
    
                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
    
                if (-not $WhatIf ) {
        
                    "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
    
                    "[{0}] Bios server setting '{1}' successfully created in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
                        
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Bios server setting successfully created in $Region region"
    
    
                }
            }
            catch {
    
                if (-not $WhatIf) {
    
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Bios server setting cannot be created!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
    
                }
            } 
        }

        [void] $NewBiosSettingStatus.add($objStatus)

    
    }
    
    
    End {
       

        if (-not $WhatIf ) {

            $NewBiosSettingStatus = Invoke-RepackageObjectWithType -RawObject $NewBiosSettingStatus -ObjectName "COM.objStatus.NSDE"    
            Return $NewBiosSettingStatus
        
        }

    }
}

Function Set-HPECOMSettingServerBios {
    <#
    .SYNOPSIS
    Updates a BIOS server setting resource in a specified region.

    .DESCRIPTION
    Modifies a BIOS server setting resource in a given region. If a parameter is not provided, the cmdlet retains the current value and only updates the provided parameters.

    For a detailed description of all iLO BIOS attribute parameters:
        - For iLO7, see https://servermanagementportal.ext.hpe.com/docs/redfishservices/ilos/ilo7/ilo7_113/ilo7_bios_resourcedefns113/
        - For iLO6, see: https://servermanagementportal.ext.hpe.com/docs/redfishservices/ilos/ilo6/ilo6_159/ilo6_bios_resourcedefns159/
        - For iLO5, see: https://servermanagementportal.ext.hpe.com/docs/redfishservices/ilos/ilo5/ilo5_304/ilo5_bios_resourcedefns304/

    Note: This cmdlet supports over 300 BIOS configuration parameters covering processor, memory, storage, network, PCI, power, thermal, security, and boot settings. 
    Due to the extensive number of parameters, this help documentation provides descriptions for the most commonly used ones. For complete parameter descriptions, 
    valid values, and platform-specific availability, please refer to the HPE iLO BIOS documentation links above. Parameter availability varies by server generation 
    and model. Use Get-Help Set-HPECOMSettingServerBios -Parameter <ParameterName> to view individual parameter details, or use tab completion to discover available parameters.

    Note: If a parameter is incompatible with your iLO generation or server platform, 'Invoke-HPECOMGroupBiosConfiguration' will return an error message stating "Apply BIOS settings failed…".
    To get more detailed information about the parameters that caused these errors, access the iLO Redfish API using a GET request to /redfish/v1/Systems/1/Bios/ and inspect the @Redfish.Settings.Messages property.

    Note: If one or more unsupported parameters are selected, the other BIOS settings will still be applied successfully. Unsupported parameters will be ignored without affecting the application of the other settings.

    Warning: This cmdlet uses documented BIOS API attributes from the HPE developer portal. Some attributes may not be supported on certain server models or firmware versions. Always test your configuration to ensure compatibility with your specific hardware. 

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central').
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.
    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name
    Specifies the name of the BIOS server setting to set.

    .PARAMETER Description
    Specifies a description for the BIOS server setting.

    .PARAMETER WorkloadProfileName
    Specifies the name of a customized or predefined workload profile to apply to the BIOS settings. Valid values and their recommended use cases:
        - Decision Support: For business intelligence workloads focused on data warehouses, data mining, or OLAP.
        - General Peak Frequency Compute: For workloads needing maximum core or memory frequency at any time; prioritizes speed over latency.
        - General Power Efficient Compute: Balances performance and power efficiency for most applications; ideal for users not tuning BIOS for specific workloads.
        - General Throughput Compute: For workloads requiring maximum sustained throughput across all cores; best for NUMA-optimized applications.
        - Graphic Processing: Optimized for GPU-based workloads; disables power management and virtualization to maximize I/O and memory bandwidth.
        - High Performance Compute (HPC): For clustered, high-utilization scientific/engineering workloads; disables power management for maximum bandwidth and compute.
        - I/O Throughput: For configurations needing maximum I/O and memory throughput; disables power management features that impact these links.
        - Low Latency: Minimizes computational latency by reducing speed/throughput and disabling power management; for RTOS or latency-sensitive workloads.
        - Mission Critical: Enables advanced memory RAS features, increasing reliability at the cost of bandwidth and latency; for reliability-focused environments.
        - Transactional Application Processing: Balances peak frequency and throughput; for OLTP and transactional business applications with database back-ends.
        - Virtual Radio Access Network (vRAN): Optimized for vRAN processing with best CPU, NIC, and hardware acceleration; supported on HPE Edgeline blades.
        - Virtualization - Max Performance: Enables all virtualization options and disables power management for maximum performance.
        - Virtualization - Power Efficient: Enables all virtualization options with power-efficient settings.

    You can set a workload profile (e.g., 'Low Latency') and still customize individual BIOS settings. If a profile conflicts with a specific BIOS setting, your individual customization takes precedence. For example, enabling 'EnergyEfficientTurbo' after selecting 'Virtual Radio Access Network (vRAN)' will override the vRAN profile's setting for that option.

    For details on which profiles affect which BIOS options and guidance on custom tuning, refer to the 'UEFI Workload-based Performance Tuning Guide'.

    .PARAMETER NewName
    Specifies a new name for the BIOS server setting.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Set-HPECOMSettingServerBios -Region eu-central -Name "Custom-Bios-For-ESX" -Description "Description..." -WorkloadProfileName "Virtualization - Max Performance"

    This example shows how to modify a BIOS setting named "Custom-Bios-For-ESX" in the eu-central region. The command updates the description and sets the workload profile to "Virtualization - Max Performance" while preserving all other existing settings.

    .EXAMPLE
    Set-HPECOMSettingServerBios -Region eu-central -Name "Custom-Bios-For-ESX" -Description "Description..." -WorkloadProfileName "Virtualization - Max Performance" `
        -AdminName Albert -AdminEmail "alb@domain.com" -AsrTimeoutMinutes Timeout10 -AutoPowerOn AlwaysPowerOn -CoreBoosting:$true -F11BootMenu:$False -ThermalConfig OptimalCooling

    This example modifies a customized BIOS configuration for "Custom-Bios-For-ESX" in the eu-central region. It sets new admin details (AdminName and AdminEmail), and various new BIOS feature configurations such as ASR timeout, auto power on, core boosting, F11 boot menu, and thermal configuration for optimal cooling.

    .EXAMPLE
    Get-HPECOMSetting -Region eu-central -Name Custom-Bios-For-ESX | Set-HPECOMSettingServerBios -NewName "Custom-Bios-For-ESX8" -FanFailPolicy Shutdown -PowerRegulator DynamicPowerSavings

    This example retrieves an existing BIOS setting named 'Custom-Bios-For-ESX' in the eu-central region and updates it. The command renames it to 'Custom-Bios-For-ESX8', sets the fan fail policy to Shutdown, and adjusts the power regulator to DynamicPowerSavings while preserving all other existing settings.

    .INPUTS
    System.Collections.ArrayList
    List of BIOS server settings from 'Get-HPECOMSetting -Category Bios'.

    .OUTPUTS
    System.Collections.ArrayList
    A custom status object or array of objects containing the following PsCustomObject keys:
        * Name     - The name of the BIOS server setting attempted to be updated
        * Region   - The name of the region
        * Status   - Status of the modification attempt (Failed for HTTP error return; Complete if creation is successful; Warning if no action is needed)
        * Details  - More information about the status
        * Exception- Information about any exceptions generated during the operation.

    #>
    [CmdletBinding(DefaultParameterSetName = 'ilo6')]
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
        [String]$Name,  

        [ValidateScript({ $_.Length -le 100 })]
        [String]$NewName,
        
        [ValidateScript({ $_.Length -le 1000 })]
        [String]$Description,    
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $WorkloadProfiles = @('None', 'Decision Support', 'General Peak Frequency Compute', 'General Power Efficient Compute', 'General Throughput Compute', 'Graphic Processing', 'High Performance Compute (HPC)', 'I/O Throughput', 'Low Latency', 'Mission Critical', 'Transactional Application Processing',  'Virtual Radio Access Network (vRAN)', 'Virtualization - Max Performance', 'Virtualization - Power Efficient')
                $filteredWorkloadProfiles = $WorkloadProfiles | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredWorkloadProfiles | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('None', 'Decision Support', 'General Peak Frequency Compute', 'General Power Efficient Compute', 'General Throughput Compute', 'Graphic Processing', 'High Performance Compute (HPC)', 'I/O Throughput', 'Low Latency', 'Mission Critical', 'Transactional Application Processing', 'Virtual Radio Access Network (vRAN)', 'Virtualization - Max Performance', 'Virtualization - Power Efficient')]
        [String]$WorkloadProfileName,
        
        [bool]$AccessControlService,
        [bool]$AcpiHpet,
        [bool]$AcpiRootBridgePxm,
        [bool]$AcpiSlit,
        [bool]$AdjSecPrefetch,
        [string]$AdminEmail,
        [String]$AdminName,
        [string]$AdminOtherInfo,
        # Name of the server administrator
        [string]$AdminPhone,

        [bool]$AdvCrashDumpMode,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('FastFaultTolerantADDDC', 'AdvancedEcc', 'OnlineSpareAdvancedEcc', 'MirroredAdvancedEcc')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('FastFaultTolerantADDDC', 'AdvancedEcc', 'OnlineSpareAdvancedEcc', 'MirroredAdvancedEcc')]
        [String]$AdvancedMemProtection,

        [bool]$AllowLoginWithIlo,
        [bool]$Amd5LevelPage,
        [bool]$AmdCdma,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('800us', '18us')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('800us', '18us')]
        [String]$AmdCstC2Latency,

        [bool]$AmdDmaRemapping,
        [bool]$AmdL1Prefetcher,
        [bool]$AmdL2Prefetcher,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Disabled')]
        [String]$AmdMemPStates,
        
        [bool]$AmdMemoryBurstRefresh,
        [bool]$AmdPeriodicDirectoryRinse,
        [bool]$AmdSecureMemoryEncryption,
        [bool]$AmdSecureNestedPaging,
        [bool]$AmdVirtualDrtmDevice,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $WorkloadProfiles = @('Auto', 'AmdXGMILinkSpeed16', 'AmdXGMILinkSpeed18', 'AmdXGMILinkSpeed25', 'AmdXGMILinkSpeed32' )
                $filteredWorkloadProfiles = $WorkloadProfiles | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredWorkloadProfiles | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'AmdXGMILinkSpeed16', 'AmdXGMILinkSpeed18', 'AmdXGMILinkSpeed25', 'AmdXGMILinkSpeed32')]
        [String]$AmdXGMILinkSpeed,

        [bool]$ApplicationPowerBoost,

        # Use this option to configure the Automatic Server Recovery option, which enables the system to automatically reboot if the server locks up.
        [bool]$AsrStatus,

        # When Automatic Server Recovery is enabled, you can use this option to set the time to wait before rebooting the server in the event of an operating system crash or server lockup.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Timeout5', 'Timeout10', 'Timeout15', 'Timeout20', 'Timeout30')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Timeout5', 'Timeout10', 'Timeout15', 'Timeout20', 'Timeout30')]
        [string]$AsrTimeoutMinutes,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Locked', 'Unlocked')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Locked', 'Unlocked')]
        [String]$AssetTagProtection,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AlwaysPowerOn', 'AlwaysPowerOff', 'RestoreLastState')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('AlwaysPowerOn', 'AlwaysPowerOff', 'RestoreLastState')]
        [String]$AutoPowerOn,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('RetryIndefinitely', 'AttemptOnce', 'ResetAfterFailed')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('RetryIndefinitely', 'AttemptOnce', 'ResetAfterFailed')]
        [string]$BootOrderPolicy,

        [bool]$ChannelInterleaving,
        [bool]$CollabPowerControl,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('LomsAndSlots', 'LomsOnly', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('LomsAndSlots', 'LomsOnly', 'Disabled')]
        [string]$ConsistentDevNaming,

        [bool]$CoreBoosting,

        # Enter a message to be displayed on POST screen during system startup. This feature limits POST screen messaging to 62 characters, special characters are also accepted.
        [ValidateScript({
                if ($_.Length -le 62) {
                    $True
                }
                if ($_ -match '^[a-zA-Z0-9]+$') {
                    $true
                } 
                elseif ($_.Length -gt 62) {
                    throw "The POST screen message cannot have more than 62 characters!"

                }
                elseif ($_ -notmatch '^[a-zA-Z0-9]+$') {
                    throw "The POST screen message cannot contain special characters!"
                }
            })]
        [string]$CustomPostMessage,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Manual')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Manual')]
        [string]$CustomPstate0,
            
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'ForceEnabled', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'ForceEnabled', 'Disabled')]
        [string]$DataFabricCStateEnable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('DaylightSavingsTimeEnabled', 'DaylightSavingsTimeDisabled', 'Enabled', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('DaylightSavingsTimeEnabled', 'DaylightSavingsTimeDisabled', 'Enabled', 'Disabled')]
        [string]$DaylightSavingsTime,
         
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('DeterminismCtrlAuto', 'DeterminismCtrlManual')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('DeterminismCtrlAuto', 'DeterminismCtrlManual')]            
        [string]$DeterminismControl,        

        [bool]$DcuIpPrefetcher,
        [bool]$DcuStreamPrefetcher,
        [bool]$Dhcpv4,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Enabled', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Enabled', 'Disabled')]
        [string]$DirectToUpi,

        [bool]$DramControllerPowerDown,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Enabled', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Enabled', 'Disabled')]            
        [string]$DynamicPowerCapping,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'AspmL1Enabled', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'AspmL1Enabled', 'Disabled')]            
        [string]$EmbNicAspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Disabled')]            
        [string]$EmbNicEnable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'PcieGen1')]
        [string]$EmbNicLinkSpeed,
        
        [bool]$EmbNicPCIeOptionROM,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$EmbSas1Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('AllTargets', 'TwentyFourTargets', 'NoTargets')]
        [string]$EmbSas1Boot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Disabled')]
        [string]$EmbSas1Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$EmbSas1LinkSpeed,
        
        [bool]$EmbSas1PcieOptionROM,
        [bool]$EmbSata1Aspm,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Disabled')]
        [string]$EmbSata1Enable,
        
        [bool]$EmbSata1PCIeOptionROM,
        [bool]$EmbSata2Aspm,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Disabled')]
        [string]$EmbSata2Enable,
        
        [bool]$EmbSata2PCIeOptionROM,

        [bool]$EmbSata3Aspm,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Disabled')]
        [string]$EmbSata3Enable,
        
        [bool]$EmbSata3PCIeOptionROM,
        [bool]$EmbSata4Aspm,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Disabled')]
        [string]$EmbSata4Enable,
        
        [bool]$EmbSata4PCIeOptionROM,
               
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'AlwaysDisabled', 'AlwaysEnabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'AlwaysDisabled', 'AlwaysEnabled')]
        [string]$EmbVideoConnection,
        
        [bool]$EmbeddedDiagnostics,
        [bool]$EmbeddedIpxe,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('EmbeddedSata', 'IntelVrocSata', 'Ahci', 'Raid')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('EmbeddedSata', 'IntelVrocSata', 'Ahci', 'Raid')]
        [string]$EmbeddedSata,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Com1Irq4', 'Com2Irq3', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Com1Irq4', 'Com2Irq3', 'Disabled')]
        [string]$EmbeddedSerialPort,
        
        [bool]$EmbeddedUefiShell,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Disabled', 'Physical', 'Virtual')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Disabled', 'Physical', 'Virtual')]
        [string]$EmsConsole,
        
        # This attribute is a problem because in iLO5, value is an integer
        [Parameter (ParameterSetName = 'ilo6')]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('CoresPerProc0', 'CoresPerProc2', 'CoresPerProc4', 'CoresPerProc6', 'CoresPerProc8', 'CoresPerProc12', 'CoresPerProc16', 'CoresPerProc20', 'CoresPerProc24', 'CoresPerProc28', 'CoresPerProc32', 'CoresPerProc36', 'CoresPerProc40', 'CoresPerProc48', 'CoresPerProc56', 'CoresPerProc60', 'CoresPerProc64', 'CoresPerProc72', 'CoresPerProc80', 'CoresPerProc84', 'CoresPerProc96', 'CoresPerProc112')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('CoresPerProc0', 'CoresPerProc2', 'CoresPerProc4', 'CoresPerProc6', 'CoresPerProc8', 'CoresPerProc12', 'CoresPerProc16', 'CoresPerProc20', 'CoresPerProc24', 'CoresPerProc28', 'CoresPerProc32', 'CoresPerProc36', 'CoresPerProc40', 'CoresPerProc48', 'CoresPerProc56', 'CoresPerProc60', 'CoresPerProc64', 'CoresPerProc72', 'CoresPerProc80', 'CoresPerProc84', 'CoresPerProc96', 'CoresPerProc112')]
        [string]$EnabledCoresPerProcIlo6_7,

        [Parameter (ParameterSetName = 'ilo5')]
        [int]$EnabledCoresPerProcIlo5,

        [bool]$EnergyEfficientTurbo,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('MaxPerf', 'BalancedPerf', 'BalancedPower', 'PowerSavingsMode')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('MaxPerf', 'BalancedPerf', 'BalancedPower', 'PowerSavingsMode')]
        [string]$EnergyPerfBias,

        [bool]$EnhancedProcPerf,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Disabled', 'ASHRAE3', 'ASHRAE4')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Disabled', 'ASHRAE3', 'ASHRAE4')]
        [string]$ExtendedAmbientTemp,

        [bool]$ExtendedMemTest,
        [bool]$F11BootMenu,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'CardConfig')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'CardConfig')]
        [string]$FCScanPolicy,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Shutdown', 'Allow')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Shutdown', 'Allow')]
        [string]$FanFailPolicy,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('EnableMessaging', 'DisableMessaging')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('EnableMessaging', 'DisableMessaging')]
        [string]$FanInstallReq,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$FlexLom1Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Disabled')]
        [string]$FlexLom1Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$FlexLom1LinkSpeed,

        [bool]$FlexLom1PCIeOptionROM,
         

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('12Hours', '24Hours')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('12Hours', '24Hours')]
        [string]$HourFormat,


        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'HttpsOnly', 'HttpOnly', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'HttpsOnly', 'HttpOnly', 'Disabled')]
        [string]$HttpSupport,

        [bool]$HwPrefetcher,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('P0', 'P1', 'P2', 'P3', 'Auto')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('P0', 'P1', 'P2', 'P3', 'Auto')]
        [string]$InfinityFabricPstate,
        

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'DmiGen1', 'DmiGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'DmiGen1', 'DmiGen2')]            
        [string]$IntelDmiLinkFreq,
        
        [bool]$IntelNicDmaChannels,
        [bool]$IntelPerfMonitoring,
        [bool]$IntelProcVtd,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Base', 'Config1', 'Config2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Base', 'Config1', 'Config2')]
        [string]$IntelSpeedSelect,

        [bool]$IntelTxt,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'MinUpiSpeed')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'MinUpiSpeed')]
        [string]$IntelUpiFreq,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'SingleLink')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'SingleLink')]
        [string]$IntelUpiLinkEn,

        [bool]$IntelUpiPowerManagement,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('VmdDirectAssignEnabledAll', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('VmdDirectAssignEnabledAll', 'Disabled')]
        [string]$IntelVmdDirectAssign,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('IntelVmdEnabledAll', 'IntelVmdEnabledIndividual', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('IntelVmdEnabledAll', 'IntelVmdEnabledIndividual', 'Disabled')]
        [string]$IntelVmdSupport,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('None', 'Standard', 'Premium')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('None', 'Standard', 'Premium')]
        [string]$IntelVrocSupport,
                
        [bool]$IntelligentProvisioning,
        [bool]$InternalSDCardSlot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('PowerCycle', 'PowerDown', 'WarmBoot')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('PowerCycle', 'PowerDown', 'WarmBoot')]
        [string]$IpmiWatchdogTimerAction,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('IpmiWatchdogTimerOff', 'IpmiWatchdogTimerOn')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('IpmiWatchdogTimerOff', 'IpmiWatchdogTimerOn')]
        [string]$IpmiWatchdogTimerStatus,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Timeout10Min', 'Timeout15Min', 'Timeout20Min', 'Timeout30Min')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Timeout10Min', 'Timeout15Min', 'Timeout20Min', 'Timeout30Min')]
        [string]$IpmiWatchdogTimerTimeout,
        
        [string]$Ipv4Address,
        [string]$Ipv4Gateway,
        [string]$Ipv4PrimaryDNS,
        [string]$Ipv4SubnetMask,
        [string]$Ipv6Address,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Automatic', 'Manual')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Automatic', 'Manual')]
        [string]$Ipv6ConfigPolicy,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'DuidLlt', 'DUID-LLT')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'DuidLlt', 'DUID-LLT')]
        [string]$Ipv6Duid,

        [string]$Ipv6Gateway,
        [string]$Ipv6PrimaryDNS,
        [string]$Ipv6SecondaryDNS,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'AttachedMedia', 'NetworkLocation')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'AttachedMedia', 'NetworkLocation')]
        [string]$IpxeAutoStartScriptLocation,
        
        
        [bool]$IpxeBootOrder,
        [bool]$IpxeScriptAutoStart,
        [bool]$IpxeScriptVerification,
        [string]$IpxeStartupUrl,
        [bool]$LastLevelCacheAsNUMANode,
        

        [bool]$LLCDeadLineAllocation,
        [bool]$LlcPrefetch,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Low', 'Medium', 'High', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Low', 'Medium', 'High', 'Disabled')]
        [string]$LocalRemoteThreshold,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'MaxMemBusFreq4800', 'MaxMemBusFreq4400', 'MaxMemBusFreq4000', 'MaxMemBusFreq3600', 'MaxMemBusFreq3200', 'MaxMemBusFreq2933', 'MaxMemBusFreq2667', 'MaxMemBusFreq2400', 'MaxMemBusFreq2133', 'MaxMemBusFreq1867')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'MaxMemBusFreq4800', 'MaxMemBusFreq4400', 'MaxMemBusFreq4000', 'MaxMemBusFreq3600', 'MaxMemBusFreq3200', 'MaxMemBusFreq2933', 'MaxMemBusFreq2667', 'MaxMemBusFreq2400', 'MaxMemBusFreq2133', 'MaxMemBusFreq1867')]
        [string]$MaxMemBusFreqMHz,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('PerPortCtrl', 'PcieGen1', 'PcieGen2', 'PcieGen3', 'PcieGen4')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('PerPortCtrl', 'PcieGen1', 'PcieGen2', 'PcieGen3', 'PcieGen4')]
        [string]$MaxPcieSpeed,

        [bool]$MemClearWarmReset,
        [bool]$MemFastTraining,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Full', 'PartialOsConfig', 'PartialFirst4GB', 'Partial10PercentAbove4GB', 'Partial20PercentAbove4GB')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Full', 'PartialOsConfig', 'PartialFirst4GB', 'Partial10PercentAbove4GB', 'Partial20PercentAbove4GB')]
        [string]$MemMirrorMode,
        
        [bool]$MemPatrolScrubbing,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Refreshx1', 'Refreshx2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Refreshx1', 'Refreshx2')]
        [string]$MemRefreshRate,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Auto', 'Disabled')]
        [string]$MemoryControllerInterleaving,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NoAction', 'AllMemory')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NoAction', 'AllMemory')]
        [string]$MemoryRemap,

        [bool]$MicrosoftSecuredCoreSupport,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('C6Retention', 'C6NonRetention', 'NoState')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('C6Retention', 'C6NonRetention', 'NoState')]
        [string]$MinProcIdlePkgState,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('C6', 'C1', 'C1E', 'NoCStates')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('C6', 'C1', 'C1E', 'NoCStates')]
        [string]$MinProcIdlePower,

        [int]$MinimumSevAsid,

        [bool]$MixedPowerSupplyReporting,
        [bool]$NetworkBootRetry,
        [int]$NetworkBootRetryCount,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('NetworkBoot', 'Disabled')]
        [string]$NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('NetworkBoot', 'Disabled')]
        [string]$NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('NetworkBoot', 'Disabled')]
        [string]$NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('NetworkBoot', 'Disabled')]
        [string]$NicBoot4,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('NetworkBoot', 'Disabled')]
        [string]$NicBoot5,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('NetworkBoot', 'Disabled')]
        [string]$NicBoot6,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('NetworkBoot', 'Disabled')]
        [string]$NicBoot7,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [string]$NicBoot8,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('NetworkBoot', 'Disabled')]
        [string]$NicBoot9,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('NetworkBoot', 'Disabled')]
        [string]$NicBoot10,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('NetworkBoot', 'Disabled')]
        [string]$NicBoot11,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [string]$NicBoot12,

        [bool]$NodeInterleaving,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Flat', 'Clustered')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Flat', 'Clustered')]
        [string]$NumaGroupSizeOpt,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('OneMemoryDomainPerSocket', 'TwoMemoryDomainsPerSocket', 'FourMemoryDomainsPerSocket', 'Auto')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('OneMemoryDomainPerSocket', 'TwoMemoryDomainsPerSocket', 'FourMemoryDomainsPerSocket', 'Auto')]
        [string]$NumaMemoryDomainsPerSocket,
        
        [bool]$NvDimmNMemFunctionality,
        [bool]$NvDimmNMemInterleaving,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Disabled', 'SanitizeAndRebootSystem', 'SanitizeAndShutdownSystem', 'SanitizeAndBootToFirmwareUI', 'SanitizeToFactoryDefaults')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Disabled', 'SanitizeAndRebootSystem', 'SanitizeAndShutdownSystem', 'SanitizeAndBootToFirmwareUI', 'SanitizeToFactoryDefaults')]
        [string]$NvDimmNSanitizePolicy,

        [bool]$NvdimmLabelSupport,
        [bool]$NvmeOptionRom,
        [bool]$Ocp1AuxiliaryPower,
        [bool]$Ocp2AuxiliaryPower,
        [bool]$OmitBootDeviceEvent,
        [bool]$OpportunisticSelfRefresh,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Manual')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Manual')]
        [string]$PackagePowerLimitControlMode,

        [int]$PackagePowerLimitValue,
        [int]$PatrolScrubDuration,

        [bool]$PciPeerToPeerSerialization,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Normal', 'Medium', 'High')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Normal', 'Medium', 'High')]
        [string]$PciResourcePadding,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot20Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot20Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot20Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot20LinkSpeed,

        [bool]$PciSlot20OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot19Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot19Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot19Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot19LinkSpeed,

        [bool]$PciSlot19OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot18Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot18Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot18Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot18LinkSpeed,

        [bool]$PciSlot18OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot17Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot17Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot17Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot17LinkSpeed,

        [bool]$PciSlot17OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot16Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot16Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot16Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot16LinkSpeed,

        [bool]$PciSlot16OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot15Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot15Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot15Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot15LinkSpeed,

        [bool]$PciSlot15OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot14Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot14Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot14Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot14LinkSpeed,

        [bool]$PciSlot14OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot13Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot13Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot13Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot13LinkSpeed,

        [bool]$PciSlot13OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot12Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot12Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot12Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot12LinkSpeed,

        [bool]$PciSlot12OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot11Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot11Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot11Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot11LinkSpeed,

        [bool]$PciSlot11OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot10Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot10Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot10Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot10LinkSpeed,

        [bool]$PciSlot10OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot9Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot9Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot9Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot9LinkSpeed,

        [bool]$PciSlot9OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot8Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot8Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot8Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot8LinkSpeed,

        [bool]$PciSlot8OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot7Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot7Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot7Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot7LinkSpeed,

        [bool]$PciSlot7OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot6Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot6Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot6Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot6LinkSpeed,

        [bool]$PciSlot6OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot5Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot5Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot5Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot5LinkSpeed,

        [bool]$PciSlot5OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot4Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot4Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot4Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot4LinkSpeed,

        [bool]$PciSlot4OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot3Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot3Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot3Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot3LinkSpeed,

        [bool]$PciSlot3OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot2Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot2Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot2Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot2LinkSpeed,

        [bool]$PciSlot2OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'AspmL1Enabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'AspmL1Enabled')]
        [string]$PciSlot1Aspm,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'NoBifurcation', 'SlotBifurcated', 'SlotDualBifurcated')]
        [string]$PciSlot1Bifurcation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled')]
        [string]$PciSlot1Enable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'PcieGen1', 'PcieGen2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]        
        [ValidateSet('Auto', 'PcieGen1', 'PcieGen2')]
        [string]$PciSlot1LinkSpeed,
        
        [bool]$PciSlot1OptionROM,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('PerformanceDeterministic', 'PowerDeterministic')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('PerformanceDeterministic', 'PowerDeterministic')]
        [string]$PerformanceDeterminism,
        
        [bool]$PersistentMemAddressRangeScrub,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('WaitForBackupPower', 'BootWithoutBackupPower', 'UseExternalBackupPower')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('WaitForBackupPower', 'BootWithoutBackupPower', 'UseExternalBackupPower')]
        [string]$PersistentMemBackupPowerPolicy,

        [bool]$PersistentMemScanMem,
        [bool]$PlatformCertificate,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('FirmwareFirst', 'OSFirst')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('FirmwareFirst', 'OSFirst')]
        [string]$PlatformRASPolicy,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('PostAsrOff', 'PostAsrOn')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('PostAsrOff', 'PostAsrOn')]
        [string]$PostAsr,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Delay30Min', 'Delay20Min', 'Delay15Min', 'Delay10Min')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Delay30Min', 'Delay20Min', 'Delay15Min', 'Delay10Min')]
        [string]$PostAsrDelay,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Disabled', 'Serial', 'All')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Disabled', 'Serial', 'All')]
        [string]$PostBootProgress,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'ForceFullDiscovery', 'ForceFastDiscovery')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'ForceFullDiscovery', 'ForceFastDiscovery')]
        [string]$PostDiscoveryMode,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Delayed20Sec', 'Delayed2Sec', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]    
        [ValidateSet('Delayed20Sec', 'Delayed2Sec', 'Disabled')]
        [string]$PostF1Prompt,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('QuietMode', 'VerboseMode')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('QuietMode', 'VerboseMode')]
        [string]$PostScreenMode,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('DisplayAll', 'DisplayEmbeddedOnly')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('DisplayAll', 'DisplayEmbeddedOnly')]
        [string]$PostVideoSupport,
        
        [bool]$PowerButton,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NoDelay', 'Random', 'Delay15Sec', 'Delay30Sec', 'Delay45Sec', 'Delay60Sec')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NoDelay', 'Random', 'Delay15Sec', 'Delay30Sec', 'Delay45Sec', 'Delay60Sec')]
        [string]$PowerOnDelay,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('DynamicPowerSavings', 'StaticLowPower', 'StaticHighPerf', 'OsControl')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('DynamicPowerSavings', 'StaticLowPower', 'StaticHighPerf', 'OsControl')]
        [string]$PowerRegulator,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'EmbNicPort1', 'EmbNicPort2', 'EmbNicPort3', 'EmbNicPort4', 'EmbNicPort5', 'EmbNicPort6', 'EmbNicPort7', 'EmbNicPort8', 'FlexLom1Port1', 'FlexLom1Port2', 'FlexLom1Port3', 'FlexLom1Port4', 'FlexLom1Port5', 'FlexLom1Port6', 'FlexLom1Port7', 'FlexLom1Port8', `
                        'Slot1NicPort1', 'Slot1NicPort2', 'Slot1NicPort3', 'Slot1NicPort4', 'Slot1NicPort5', 'Slot1NicPort6', 'Slot1NicPort7', 'Slot1NicPort8', 'Slot2NicPort1', 'Slot2NicPort3', 'Slot2NicPort4', 'Slot2NicPort5', 'Slot2NicPort6', 'Slot2NicPort7', 'Slot2NicPort8', `
                        'Slot3NicPort1', 'Slot3NicPort2', 'Slot3NicPort3', 'Slot3NicPort4', 'Slot3NicPort5', 'Slot3NicPort6', 'Slot3NicPort7', 'Slot3NicPort8', 'Slot4NicPort1', 'Slot4NicPort2', 'Slot4NicPort3', 'Slot4NicPort4', 'Slot4NicPort5', 'Slot4NicPort6', 'Slot4NicPort7', 'Slot4NicPort8', `
                        'Slot5NicPort1', 'Slot5NicPort2', 'Slot5NicPort3', 'Slot5NicPort4', 'Slot5NicPort5', 'Slot5NicPort6', 'Slot5NicPort7', 'Slot5NicPort8', 'Slot6NicPort1', 'Slot6NicPort2', 'Slot6NicPort3', 'Slot6NicPort4', 'Slot6NicPort5', 'Slot6NicPort6', 'Slot6NicPort7', 'Slot6NicPort8', `
                        'Slot7NicPort1', 'Slot7NicPort2', 'Slot7NicPort3', 'Slot7NicPort4', 'Slot7NicPort5', 'Slot7NicPort6', 'Slot7NicPort7', 'Slot7NicPort8', 'Slot8NicPort1', 'Slot8NicPort2', 'Slot8NicPort3', 'Slot8NicPort4', 'Slot8NicPort5', 'Slot8NicPort6', 'Slot8NicPort7', 'Slot8NicPort8')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'EmbNicPort1', 'EmbNicPort2', 'EmbNicPort3', 'EmbNicPort4', 'EmbNicPort5', 'EmbNicPort6', 'EmbNicPort7', 'EmbNicPort8', 'FlexLom1Port1', 'FlexLom1Port2', 'FlexLom1Port3', 'FlexLom1Port4', 'FlexLom1Port5', 'FlexLom1Port6', 'FlexLom1Port7', 'FlexLom1Port8', `
                'Slot1NicPort1', 'Slot1NicPort2', 'Slot1NicPort3', 'Slot1NicPort4', 'Slot1NicPort5', 'Slot1NicPort6', 'Slot1NicPort7', 'Slot1NicPort8', 'Slot2NicPort1', 'Slot2NicPort2', 'Slot2NicPort3', 'Slot2NicPort4', 'Slot2NicPort5', 'Slot2NicPort6', 'Slot2NicPort7', 'Slot2NicPort8', `
                'Slot3NicPort1', 'Slot3NicPort2', 'Slot3NicPort3', 'Slot3NicPort4', 'Slot3NicPort5', 'Slot3NicPort6', 'Slot3NicPort7', 'Slot3NicPort8', 'Slot4NicPort1', 'Slot4NicPort2', 'Slot4NicPort3', 'Slot4NicPort4', 'Slot4NicPort5', 'Slot4NicPort6', 'Slot4NicPort7', 'Slot4NicPort8', `
                'Slot5NicPort1', 'Slot5NicPort2', 'Slot5NicPort3', 'Slot5NicPort4', 'Slot5NicPort5', 'Slot5NicPort6', 'Slot5NicPort7', 'Slot5NicPort8', 'Slot6NicPort1', 'Slot6NicPort2', 'Slot6NicPort3', 'Slot6NicPort4', 'Slot6NicPort5', 'Slot6NicPort6', 'Slot6NicPort7', 'Slot6NicPort8', `
                'Slot7NicPort1', 'Slot7NicPort2', 'Slot7NicPort3', 'Slot7NicPort4', 'Slot7NicPort5', 'Slot7NicPort6', 'Slot7NicPort7', 'Slot7NicPort8', 'Slot8NicPort1', 'Slot8NicPort2', 'Slot8NicPort3', 'Slot8NicPort4', 'Slot8NicPort5', 'Slot8NicPort6', 'Slot8NicPort7', 'Slot8NicPort8')]
        [string]$PreBootNetwork,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'IPv4', 'IPv6')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'IPv4', 'IPv6')]
        [string]$PrebootNetworkEnvPolicy,
        
        [string]$PrebootNetworkProxy,
        [bool]$ProcAes,
        [bool]$ProcAMDBoost,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AmdFmaxBoostAuto', 'AmdFmaxBoostManual')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AmdFmaxBoostAuto', 'AmdFmaxBoostManual')]
        [string]$ProcAMDBoostControl,
        
        [int]$ProcAmdFmax,
        [bool]$ProcAmdIoVt,
        [bool]$ProcHyperthreading,
        [bool]$ProcSMT,
        [bool]$ProcTurbo,
        [bool]$ProcVirtualization,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Enabled', 'ForceEnabled', 'Disabled', 'Auto')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Enabled', 'ForceEnabled', 'Disabled', 'Auto')]
        [string]$ProcX2Apic,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Normal', 'Level1', 'Level2')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Normal', 'Level1', 'Level2')]
        [string]$ProcessorConfigTDPLevel,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Disabled', 'Auto-tuned', 'Manual-tuned')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Disabled', 'Auto-tuned', 'Manual-tuned')]
        [string]$ProcessorJitterControl,
        
        [int]$ProcessorJitterControlFrequency,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('OptimizedForThroughput', 'OptimizedForLatency', 'ZeroLatency')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('OptimizedForThroughput', 'OptimizedForLatency', 'ZeroLatency')]
        [string]$ProcessorJitterControlOptimization,

        [string]$Pstate0Frequency,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('BalancedMode', 'HighEfficiencyAuto', 'HighEfficiencyOddStandby', 'HighEfficiencyEvenStandby')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('BalancedMode', 'HighEfficiencyAuto', 'HighEfficiencyOddStandby', 'HighEfficiencyEvenStandby')]
        [string]$RedundantPowerSupply,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('BalancedMode', 'HighEfficiencyAuto', 'HighEfficiencyOddStandby', 'HighEfficiencyEvenStandby')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('BalancedMode', 'HighEfficiencyAuto', 'HighEfficiencyOddStandby', 'HighEfficiencyEvenStandby')]
        [string]$RedundantPowerSupplyGpuDomain,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('BalancedMode', 'HighEfficiencyAuto', 'HighEfficiencyOddStandby', 'HighEfficiencyEvenStandby')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('BalancedMode', 'HighEfficiencyAuto', 'HighEfficiencyOddStandby', 'HighEfficiencyEvenStandby')]
        [string]$RedundantPowerSupplySystemDomain,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('InternalSdCardFirst', 'InternalKeysFirst', 'ExternalKeysFirst')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('InternalSdCardFirst', 'InternalKeysFirst', 'ExternalKeysFirst')]
        [string]$RemovableFlashBootSeq,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('CurrentRom', 'BackupRom')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('CurrentRom', 'BackupRom')]
        [string]$RomSelection,

        [bool]$SanitizeAllNvDimmN,
        [bool]$SataSanitize,
        [bool]$SataSecureErase,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Ghesv1Support', 'Ghesv2Support')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]    
        [ValidateSet('Ghesv1Support', 'Ghesv2Support')]
        [string]$SciRasSupport,

        [bool]$SecStartBackupImage,
        [bool]$SecureBootEnable,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('BaudRate9600', 'BaudRate19200', 'BaudRate38400', 'BaudRate57600', 'BaudRate115200')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('BaudRate9600', 'BaudRate19200', 'BaudRate38400', 'BaudRate57600', 'BaudRate115200')]
        [string]$SerialConsoleBaudRate,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Vt100', 'Ansi', 'Vt100Plus', 'VtUtf8')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]    
        [ValidateSet('Vt100', 'Ansi', 'Vt100Plus', 'VtUtf8')]
        [string]$SerialConsoleEmulation,


        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Disabled', 'Physical', 'Virtual')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Disabled', 'Physical', 'Virtual')]
        [string]$SerialConsolePort,
        
        [string]$ServerAssetTag,
        [bool]$ServerConfigLockStatus,
        [string]$ServerOtherInfo,
        [string]$ServerPrimaryOs,
        [string]$ServiceEmail,
        [string]$ServiceName,
        [string]$ServiceOtherInfo,
        [string]$ServicePhone,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('GUI', 'Text', 'Auto')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('GUI', 'Text', 'Auto')]
        [string]$SetupBrowserSelection,     

        [bool]$Slot1MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot1NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot1NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot1NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot1NicBoot4,

        [bool]$Slot2MctpBroadcastSupport,        

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot2NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot2NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot2NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot2NicBoot4,

        [bool]$Slot3MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot3NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot3NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot3NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot3NicBoot4,

        [bool]$Slot4MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot4NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot4NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot4NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot4NicBoot4,

        [bool]$Slot5MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot5NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot5NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot5NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot5NicBoot4,

        [bool]$Slot6MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot6NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot6NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot6NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot6NicBoot4,
 
        [bool]$Slot7MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot7NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot7NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot7NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot7NicBoot4,

        [bool]$Slot8MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot8NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot8NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot8NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        
        [string]$Slot8NicBoot4,
            
        [bool]$Slot9MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot9NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot9NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot9NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot9NicBoot4,

        [bool]$Slot10MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]    
        [string]$Slot10NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
  
        [string]$Slot10NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]     
        [string]$Slot10NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]      
        [string]$Slot10NicBoot4,

        [bool]$Slot11MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot11NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot11NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot11NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot11NicBoot4,


        [bool]$Slot12MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot12NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot12NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot12NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot12NicBoot4,


        [bool]$Slot13MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot13NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot13NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot13NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot13NicBoot4,


        [bool]$Slot14MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot14NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot14NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot14NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot14NicBoot4,


        [bool]$Slot15MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot15NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot15NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot15NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot15NicBoot4,


        [bool]$Slot16MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot16NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot16NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot16NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot16NicBoot4,

        [bool]$Slot17MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot17NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot17NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot17NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot17NicBoot4,

        [bool]$Slot18MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot18NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot18NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot18NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot18NicBoot4,

        [bool]$Slot19MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot19NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot19NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot19NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot19NicBoot4,

        [bool]$Slot20MctpBroadcastSupport,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot20NicBoot1,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot20NicBoot2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot20NicBoot3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NetworkBoot', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NetworkBoot', 'Disabled')]
        [string]$Slot20NicBoot4,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot1StorageBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot2StorageBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot3StorageBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot4StorageBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot5StorageBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot6StorageBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot7StorageBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot8StorageBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot9StorageBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot10StorageBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot11StorageBoot,
                
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot12StorageBoot,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot13StorageBoot,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot14StorageBoot,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot15StorageBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot16StorageBoot,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot17StorageBoot,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot18StorageBoot,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot19StorageBoot,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('AllTargets', 'TwentyFourTargets', 'ThirtyTwoTargets', 'NoTargets')]
        [string]$Slot20StorageBoot,

        [bool]$SpeculativeLockScheduling,
        [bool]$Sriov,


        [bool]$StaleAtoS,
        # When enabled, Sub-NUMA Clustering divides the processor's cores, cache, and memory into multiple NUMA domains. Enabling this feature can increase performance for workloads that are NUMA aware and optimized. Note: When this option is enabled, up to 1GB of system memory may become unavailable.
        
        [bool]$SubNumaClustering,

        [bool]$TPM2EndorsementDisable,
        [bool]$TPM2StorageDisable,

        # Use this option to select the fan cooling solution for the system. Optimal Cooling provides the most efficient solution by configuring fan speeds to the minimum required speed to provide adequate cooling. Increased Cooling runs fans at higher speeds to provide additional cooling. Select Increased Cooling when third-party storage controllers are cabled to the embedded hard drive cage, or if the system is experiencing thermal issues that cannot be resolved. Maximum cooling provides the maximum cooling available on this platform. Enhanced CPU Cooling runs the fans at a higher speed to provide additional cooling to the processors. Selecting Enhanced CPU Cooling may improve system performance with certain processor intensive workloads.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('OptimalCooling', 'IncreasedCooling', 'MaxCooling', 'EnhancedCPUCooling')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('OptimalCooling', 'IncreasedCooling', 'MaxCooling', 'EnhancedCPUCooling')]
        [string]$ThermalConfig,

        [bool]$ThermalShutdown,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Utc', 'Local')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Utc', 'Local')]
        [string]$TimeFormat,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('UtcM12', 'UtcM11', 'UtcM10', 'UtcM9 ', 'UtcM8', 'UtcM7', 'UtcM6', 'UtcM5', 'UtcM430', 'UtcM4', 'UtcM330', 'UtcM3', 'UtcM2', 'UtcM1', 'Utc0 ', 'UtcP1', 'UtcP2', 'UtcP3', 'UtcP330', 'UtcP4', 'UtcP430', 'UtcP5', 'UtcP530', 'UtcP545', 'UtcP6', 'UtcP630', 'UtcP7', 'UtcP8', 'UtcP9', 'UtcP930', 'UtcP10', 'UtcP11', 'UtcP12', 'UtcP13', 'UtcP14', 'Unspecified')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('UtcM12', 'UtcM11', 'UtcM10', 'UtcM9 ', 'UtcM8', 'UtcM7', 'UtcM6', 'UtcM5', 'UtcM430', 'UtcM4', 'UtcM330', 'UtcM3', 'UtcM2', 'UtcM1', 'Utc0 ', 'UtcP1', 'UtcP2', 'UtcP3', 'UtcP330', 'UtcP4', 'UtcP430', 'UtcP5', 'UtcP530', 'UtcP545', 'UtcP6', 'UtcP630', 'UtcP7', 'UtcP8', 'UtcP9', 'UtcP930', 'UtcP10', 'UtcP11', 'UtcP12', 'UtcP13', 'UtcP14', 'Unspecified')]
        [string]$TimeZone,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NoAction', 'Fifo', 'Crb')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NoAction', 'Fifo', 'Crb')]
        [string]$Tpm20SoftwareInterfaceOperation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NoAction', 'Fifo', 'Crb')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NoAction', 'Fifo', 'Crb')]
        [string]$Tpm20SoftwareInterfaceStatus,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NoAction', 'Clear')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NoAction', 'Clear')]
        [string]$Tpm2Operation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NotSpecified', 'Sha1', 'Sha256', 'Sha1Sha256', 'Sha256Sha384')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NotSpecified', 'Sha1', 'Sha256', 'Sha1Sha256', 'Sha256Sha384')]
        [string]$TpmActivePcrs,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('None', 'StMicroGen10', 'IntelPttFTpm', 'NationzTpm20', 'STMicroGen10Plus', 'STMicroGen11')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('None', 'StMicroGen10', 'IntelPttFTpm', 'NationzTpm20', 'STMicroGen10Plus', 'STMicroGen11')]
        [string]$TpmChipId,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NotSpecified', 'NonFipsMode', 'FipsMode')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NotSpecified', 'NonFipsMode', 'FipsMode')]
        [string]$TpmFips,
                
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NoAction', 'RegularMode', 'FipsMode')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NoAction', 'RegularMode', 'FipsMode')]
        [string]$TpmFipsModeSwitch,
                        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NoAction', 'Tpm12', 'Tpm20')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NoAction', 'Tpm12', 'Tpm20')]
        [string]$TpmModeSwitchOperation,
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NoAction', 'Enable', 'Disable', 'Clear')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NoAction', 'Enable', 'Disable', 'Clear')]
        [string]$TpmOperation,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NotPresent', 'PresentDisabled', 'PresentEnabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NotPresent', 'PresentDisabled', 'PresentEnabled')]
        [string]$TpmState,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('NoTpm', 'Tpm12', 'Tpm20')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('NoTpm', 'Tpm12', 'Tpm20')]
        [string]$TpmType,
        
        [bool]$TpmUefiOpromMeasuring,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Hidden', 'Visible')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Hidden', 'Visible')]
        [string]$TpmVisibility,

        [bool]$TransparentSecureMemoryEncryption,
        [bool]$UefiOptimizedBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Disabled', 'ErrorsOnly', 'Medium', 'Network', 'Verbose', 'Custom')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Disabled', 'ErrorsOnly', 'Medium', 'Network', 'Verbose', 'Custom')]
        [string]$UefiSerialDebugLevel,

        [bool]$UefiShellBootOrder,
        [bool]$UefiShellPhysicalPresenceKeystroke,
        [bool]$UefiShellScriptVerification,
        [bool]$UefiShellStartup,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'AttachedMedia', 'NetworkLocation')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'AttachedMedia', 'NetworkLocation')]
        [string]$UefiShellStartupLocation,
        
        [string]$UefiShellStartupUrl,
        [bool]$UefiShellStartupUrlFromDhcp,
        [bool]$UefiVariableAccessFwControl,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Maximum', 'Minimum')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Maximum', 'Minimum')]
        [string]$UncoreFreqScaling,

        [bool]$UpiPrefetcher,
        [string]$UrlBootFile,
        [string]$UrlBootFile2,
        [bool]$UsbBoot,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('UsbEnabled', 'UsbDisabled', 'ExternalUsbDisabled', 'InternalUsbDisabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('UsbEnabled', 'UsbDisabled', 'ExternalUsbDisabled', 'InternalUsbDisabled')]
        [string]$UsbControl,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('English', 'Japanese', 'Chinese')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('English', 'Japanese', 'Chinese')]
        [string]$UtilityLang,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('OptionalVideoOnly', 'BothVideoEnabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('OptionalVideoOnly', 'BothVideoEnabled')]
        [string]$VideoOptions,

        [bool]$VirtualInstallDisk,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Com1Irq4', 'Com2Irq3', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Com1Irq4', 'Com2Irq3', 'Disabled')]
        [string]$VirtualSerialPort,
        
        
        [bool]$VlanControl,
        [int]$VlanId,
        [int]$VlanPriority,
        [bool]$WakeOnLan,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'Enabled', 'Disabled')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'Enabled', 'Disabled')]
        [string]$XptPrefetcher,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'x4', 'x8', 'x16')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'x4', 'x8', 'x16')]
        [string]$XGMIForceLinkWidth,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Auto', 'x4', 'x8', 'x16')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('Auto', 'x4', 'x8', 'x16')]
        [string]$XGMIMaxLinkWidth,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('SoftwareInitiator', 'AdapterInitiator')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet('SoftwareInitiator', 'AdapterInitiator')]
        [string]$iSCSIPolicy,

        [bool]$iSCSISoftwareInitiator,

        [Switch]$WhatIf
      
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-COMSettingsUri
        $SetServerSettingBiosStatus = [System.Collections.ArrayList]::new()

        
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
            $SettingResource = Get-HPECOMSetting -Region $Region -Name $Name -Category Bios
            $SettingID = $SettingResource.id
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)

        }


        if (-not $SettingResource) {

            "[{0}] Setting '{1}' is not present in the '{2}' region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
            
            # Must return a message if not found

            if ($WhatIf) {

                $ErrorMessage = "Setting '{0}': Resource cannot be found in the '{1}' region!" -f $Name, $Region
                Write-warning $ErrorMessage
                return
            
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "Setting cannot be found in the region!"
            }
        }
        else {

            $Uri = (Get-COMSettingsUri) + "/" + $SettingID


            # Conditionally add properties
            if ($NewName) {
                $Name = $NewName
            }

            if (-not $PSBoundParameters.ContainsKey('Description')) {
        
                if ($SettingResource.description) {
                            
                    $Description = $SettingResource.description
                }
                else {
                    $Description = $Null
                }
            }       

            # Boolean parameters

            #Region
            $boolParametersList = @(
                'AccessControlService',
                'AcpiHpet',
                'AcpiRootBridgePxm',
                'AcpiSlit',
                'AdjSecPrefetch',
                'AdvCrashDumpMode',
                'AllowLoginWithIlo',
                'Amd5LevelPage',
                'AmdCdma',
                'AmdDmaRemapping',
                'AmdL1Prefetcher',
                'AmdL2Prefetcher',
                'AmdMemoryBurstRefresh',
                'AmdPeriodicDirectoryRinse',
                'AmdSecureMemoryEncryption',
                'AmdSecureNestedPaging',
                'AmdVirtualDrtmDevice',
                'ApplicationPowerBoost',
                'AsrStatus',
                'ChannelInterleaving',
                'CollabPowerControl',
                'CoreBoosting',
                'DcuIpPrefetcher',
                'DcuStreamPrefetcher',
                'Dhcpv4',
                'DramControllerPowerDown',
                'EmbNicPCIeOptionROM',
                'EmbSas1PcieOptionROM',
                'EmbSata1Aspm',
                'EmbSata1PCIeOptionROM',
                'EmbSata2Aspm',
                'EmbSata2PCIeOptionROM',
                'EmbSata3Aspm',
                'EmbSata3PCIeOptionROM',
                'EmbSata4Aspm',
                'EmbSata4PCIeOptionROM',
                'EmbeddedDiagnostics',
                'EmbeddedIpxe',
                'EmbeddedUefiShell',
                'EnergyEfficientTurbo',
                'EnhancedProcPerf',
                'ExtendedMemTest',
                'F11BootMenu',
                'FlexLom1PCIeOptionROM',
                'HwPrefetcher',
                'IntelNicDmaChannels',
                'IntelPerfMonitoring',
                'IntelProcVtd',
                'IntelTxt',
                'IntelUpiPowerManagement',
                'IntelligentProvisioning',
                'InternalSDCardSlot',
                'IpxeBootOrder',
                'IpxeScriptAutoStart',
                'IpxeScriptVerification',
                'LastLevelCacheAsNUMANode',
                'LLCDeadLineAllocation',
                'LlcPrefetch',
                'MemClearWarmReset',
                'MemFastTraining',
                'MemPatrolScrubbing',
                'MicrosoftSecuredCoreSupport',
                'MixedPowerSupplyReporting',
                'NetworkBootRetry',
                'NodeInterleaving',
                'NvDimmNMemFunctionality',
                'NvDimmNMemInterleaving',
                'NvdimmLabelSupport',
                'NvmeOptionRom',
                'Ocp1AuxiliaryPower',
                'Ocp2AuxiliaryPower',
                'OmitBootDeviceEvent',
                'OpportunisticSelfRefresh',
                'PciPeerToPeerSerialization',
                'PciSlot20OptionROM',
                'PciSlot19OptionROM',
                'PciSlot18OptionROM',
                'PciSlot17OptionROM',
                'PciSlot16OptionROM',
                'PciSlot15OptionROM',
                'PciSlot14OptionROM',
                'PciSlot13OptionROM',
                'PciSlot12OptionROM',
                'PciSlot11OptionROM',
                'PciSlot10OptionROM',
                'PciSlot9OptionROM',
                'PciSlot8OptionROM',
                'PciSlot7OptionROM',
                'PciSlot6OptionROM',
                'PciSlot5OptionROM',
                'PciSlot4OptionROM',
                'PciSlot3OptionROM',
                'PciSlot2OptionROM',
                'PciSlot1OptionROM',
                'PersistentMemAddressRangeScrub',
                'PersistentMemScanMem',
                'PlatformCertificate',
                'PowerButton',
                'ProcAes',
                'ProcAMDBoost',
                'ProcAmdIoVt',
                'ProcHyperthreading',
                'ProcSMT',
                'ProcTurbo',
                'ProcVirtualization',
                'SanitizeAllNvDimmN',
                'SataSanitize',
                'SataSecureErase',
                'SecStartBackupImage',
                'SecureBootEnable',
                'ServerConfigLockStatus',
                'Slot1MctpBroadcastSupport',
                'Slot2MctpBroadcastSupport',
                'Slot3MctpBroadcastSupport',
                'Slot4MctpBroadcastSupport',
                'Slot5MctpBroadcastSupport',
                'Slot6MctpBroadcastSupport',
                'Slot7MctpBroadcastSupport',
                'Slot8MctpBroadcastSupport',
                'Slot9MctpBroadcastSupport',
                'Slot10MctpBroadcastSupport',
                'Slot11MctpBroadcastSupport',
                'Slot12MctpBroadcastSupport',
                'Slot13MctpBroadcastSupport',
                'Slot14MctpBroadcastSupport',
                'Slot15MctpBroadcastSupport',
                'Slot16MctpBroadcastSupport',
                'Slot17MctpBroadcastSupport',
                'Slot18MctpBroadcastSupport',
                'Slot19MctpBroadcastSupport',
                'Slot20MctpBroadcastSupport',
                'SpeculativeLockScheduling',
                'Sriov',
                'StaleAtoS',
                'SubNumaClustering',
                'TPM2EndorsementDisable',
                'TPM2StorageDisable',
                'ThermalShutdown',
                'TpmUefiOpromMeasuring',
                'TransparentSecureMemoryEncryption',
                'UefiOptimizedBoot',
                'UefiShellBootOrder',
                'UefiShellPhysicalPresenceKeystroke',
                'UefiShellScriptVerification',
                'UefiShellStartup',
                'UefiShellStartupUrlFromDhcp',
                'UefiVariableAccessFwControl',
                'UpiPrefetcher',
                'UsbBoot',
                'VirtualInstallDisk',
                'VlanControl',
                'WakeOnLan',
                'iSCSISoftwareInitiator'

            )
            #EndRegion

            $Attributes = @{}
        
            foreach ($boolparameter in $boolParametersList) {
            
                if ($PSBoundParameters.ContainsKey($boolparameter)) {
               
                    if ($PSBoundParameters[$boolparameter] -eq $True) {
            
                        $Attributes."$boolparameter" = "Enabled"
            
                    }
                    else {
                        $Attributes."$boolparameter" = "Disabled"
            
                    }
                }     
                elseif (-not $PSBoundParameters.ContainsKey($boolparameter)) {
                    
                    if ($null -ne $SettingResource.redfishData.Attributes."$boolparameter") {
                            
                        $Attributes."$boolparameter" = $SettingResource.redfishData.Attributes."$boolparameter"
                    }
                }   
            }


            # String + Integer parameters

            #Region
            $stringparametersList = @(
                'AdminEmail',
                'AdminName',
                'AdminOtherInfo',
                'AdminPhone',
                'AdvancedMemProtection',
                'AmdCstC2Latency',
                'AmdMemPStates',
                'AmdXGMILinkSpeed',
                'AsrTimeoutMinutes',
                'AssetTagProtection',
                'AutoPowerOn',
                'BootOrderPolicy',
                'ConsistentDevNaming',
                'CustomPostMessage',
                'CustomPstate0',
                'DataFabricCStateEnable',
                'DaylightSavingsTime',
                'DeterminismControl',
                'DirectToUpi',
                'DynamicPowerCapping',
                'EmbNicAspm',
                'EmbNicEnable',
                'EmbNicLinkSpeed',
                'EmbSas1Aspm',
                'EmbSas1Boot',
                'EmbSas1Enable',
                'EmbSas1LinkSpeed',
                'EmbSata1Enable',
                'EmbSata2Enable',
                'EmbSata3Enable',
                'EmbSata4Enable',
                'EmbVideoConnection',
                'EmbeddedSata',
                'EmbeddedSerialPort',
                'EmsConsole',
                # 'EnabledCoresPerProcIlo6_7', # Removed as iLO5 and 6 do not use the same value types
                # 'EnabledCoresPerProcIlo5',
                'EnergyPerfBias',
                'ExtendedAmbientTemp',
                'FCScanPolicy',
                'FanFailPolicy',
                'FanInstallReq',
                'FlexLom1Aspm',
                'FlexLom1Enable',
                'FlexLom1LinkSpeed',
                'HourFormat',
                'HttpSupport',
                'InfinityFabricPstate',
                'IntelDmiLinkFreq',
                'IntelSpeedSelect',
                'IntelUpiFreq',
                'IntelUpiLinkEn',
                'IntelVmdDirectAssign',
                'IntelVmdSupport',
                'IntelVrocSupport',
                'IpmiWatchdogTimerAction',
                'IpmiWatchdogTimerStatus',
                'IpmiWatchdogTimerTimeout',
                'Ipv4Address',
                'Ipv4Gateway',
                'Ipv4PrimaryDNS',
                'Ipv4SubnetMask',
                'Ipv6Address',
                'Ipv6ConfigPolicy',
                'Ipv6Duid',
                'Ipv6Gateway',
                'Ipv6PrimaryDNS',
                'Ipv6SecondaryDNS',
                'IpxeAutoStartScriptLocation',
                'IpxeStartupUrl',
                'LocalRemoteThreshold',
                'MaxMemBusFreqMHz',
                'MaxPcieSpeed',
                'MemMirrorMode',
                'MemRefreshRate',
                'MemoryControllerInterleaving',
                'MemoryRemap',
                'MinProcIdlePkgState',
                'MinProcIdlePower',
                'MinimumSevAsid',
                'NetworkBootRetryCount',
                'NicBoot1',
                'NicBoot2',
                'NicBoot3',
                'NicBoot4',
                'NicBoot5',
                'NicBoot6',
                'NicBoot7',
                'NicBoot8',
                'NicBoot9',
                'NicBoot10',
                'NicBoot11',
                'NicBoot12',
                'NumaGroupSizeOpt',
                'NumaMemoryDomainsPerSocket',
                'NvDimmNSanitizePolicy',
                'PackagePowerLimitControlMode',
                'PackagePowerLimitValue',
                'PatrolScrubDuration',
                'PciResourcePadding',
                'PciSlot20Aspm',
                'PciSlot20Bifurcation',
                'PciSlot20Enable',
                'PciSlot20LinkSpeed',
                'PciSlot19Aspm',
                'PciSlot19Bifurcation',
                'PciSlot19Enable',
                'PciSlot19LinkSpeed',
                'PciSlot18Aspm',
                'PciSlot18Bifurcation',
                'PciSlot18Enable',
                'PciSlot18LinkSpeed',
                'PciSlot17Aspm',
                'PciSlot17Bifurcation',
                'PciSlot17Enable',
                'PciSlot17LinkSpeed',
                'PciSlot16Aspm',
                'PciSlot16Bifurcation',
                'PciSlot16Enable',
                'PciSlot16LinkSpeed',
                'PciSlot15Aspm',
                'PciSlot15Bifurcation',
                'PciSlot15Enable',
                'PciSlot15LinkSpeed',
                'PciSlot14Aspm',
                'PciSlot14Bifurcation',
                'PciSlot14Enable',
                'PciSlot14LinkSpeed',
                'PciSlot13Aspm',
                'PciSlot13Bifurcation',
                'PciSlot13Enable',
                'PciSlot13LinkSpeed',
                'PciSlot12Aspm',
                'PciSlot12Bifurcation',
                'PciSlot12Enable',
                'PciSlot12LinkSpeed',
                'PciSlot11Aspm',
                'PciSlot11Bifurcation',
                'PciSlot11Enable',
                'PciSlot11LinkSpeed',
                'PciSlot10Aspm',
                'PciSlot10Bifurcation',
                'PciSlot10Enable',
                'PciSlot10LinkSpeed',
                'PciSlot9Aspm',
                'PciSlot9Bifurcation',
                'PciSlot9Enable',
                'PciSlot9LinkSpeed',
                'PciSlot8Aspm',
                'PciSlot8Bifurcation',
                'PciSlot8Enable',
                'PciSlot8LinkSpeed',
                'PciSlot7Aspm',
                'PciSlot7Bifurcation',
                'PciSlot7Enable',
                'PciSlot7LinkSpeed',
                'PciSlot6Aspm',
                'PciSlot6Bifurcation',
                'PciSlot6Enable',
                'PciSlot6LinkSpeed',
                'PciSlot5Aspm',
                'PciSlot5Bifurcation',
                'PciSlot5Enable',
                'PciSlot5LinkSpeed',
                'PciSlot4Aspm',
                'PciSlot4Bifurcation',
                'PciSlot4Enable',
                'PciSlot4LinkSpeed',
                'PciSlot3Aspm',
                'PciSlot3Bifurcation',
                'PciSlot3Enable',
                'PciSlot3LinkSpeed',
                'PciSlot2Aspm',
                'PciSlot2Bifurcation',
                'PciSlot2Enable',
                'PciSlot2LinkSpeed',
                'PciSlot1Aspm',
                'PciSlot1Bifurcation',
                'PciSlot1Enable',
                'PciSlot1LinkSpeed',
                'PerformanceDeterminism',
                'PersistentMemBackupPowerPolicy',
                'PlatformRASPolicy',
                'PostAsr',
                'PostAsrDelay',
                'PostBootProgress',
                'PostDiscoveryMode',
                'PostF1Prompt',
                'PostScreenMode',
                'PostVideoSupport',
                'PowerOnDelay',
                'PowerRegulator',
                'PreBootNetwork',
                'PrebootNetworkEnvPolicy',
                'PrebootNetworkProxy',
                'ProcAMDBoostControl',
                'ProcAmdFmax',
                'ProcX2Apic',
                'ProcessorConfigTDPLevel',
                'ProcessorJitterControl',
                'ProcessorJitterControlFrequency',
                'ProcessorJitterControlOptimization',
                'Pstate0Frequency',
                'RedundantPowerSupply',
                'RedundantPowerSupplyGpuDomain',
                'RedundantPowerSupplySystemDomain',
                'RemovableFlashBootSeq',
                'RomSelection',
                'SciRasSupport',
                'SerialConsoleBaudRate',
                'SerialConsoleEmulation',
                'SerialConsolePort',
                'ServerAssetTag',
                'ServerOtherInfo',
                'ServerPrimaryOs',
                'ServiceEmail',
                'ServiceName',
                'ServiceOtherInfo',
                'ServicePhone',
                'SetupBrowserSelection',
                'Slot1NicBoot1',
                'Slot1NicBoot2',
                'Slot1NicBoot3',
                'Slot1NicBoot4',
                'Slot2NicBoot1',
                'Slot2NicBoot2',
                'Slot2NicBoot3',
                'Slot2NicBoot4',
                'Slot3NicBoot1',
                'Slot3NicBoot2',
                'Slot3NicBoot3',
                'Slot3NicBoot4',
                'Slot4NicBoot1',
                'Slot4NicBoot2',
                'Slot4NicBoot3',
                'Slot4NicBoot4',
                'Slot5NicBoot1',
                'Slot5NicBoot2',
                'Slot5NicBoot3',
                'Slot5NicBoot4',
                'Slot6NicBoot1',
                'Slot6NicBoot2',
                'Slot6NicBoot3',
                'Slot6NicBoot4',
                'Slot7NicBoot1',
                'Slot7NicBoot2',
                'Slot7NicBoot3',
                'Slot7NicBoot4',
                'Slot8NicBoot1',
                'Slot8NicBoot2',
                'Slot8NicBoot3',
                'Slot8NicBoot4',
                'Slot9NicBoot1',
                'Slot9NicBoot2',
                'Slot9NicBoot3',
                'Slot9NicBoot4',
                'Slot10NicBoot1',
                'Slot10NicBoot2',
                'Slot10NicBoot3',
                'Slot10NicBoot4',
                'Slot11NicBoot1',
                'Slot11NicBoot2',
                'Slot11NicBoot3',
                'Slot11NicBoot4',
                'Slot12NicBoot1',
                'Slot12NicBoot2',
                'Slot12NicBoot3',
                'Slot12NicBoot4',
                'Slot13NicBoot1',
                'Slot13NicBoot2',
                'Slot13NicBoot3',
                'Slot13NicBoot4',
                'Slot14NicBoot1',
                'Slot14NicBoot2',
                'Slot14NicBoot3',
                'Slot14NicBoot4',
                'Slot15NicBoot1',
                'Slot15NicBoot2',
                'Slot15NicBoot3',
                'Slot15NicBoot4',
                'Slot16NicBoot1',
                'Slot16NicBoot2',
                'Slot16NicBoot3',
                'Slot16NicBoot4',
                'Slot17NicBoot1',
                'Slot17NicBoot2',
                'Slot17NicBoot3',
                'Slot17NicBoot4',
                'Slot18NicBoot1',
                'Slot18NicBoot2',
                'Slot18NicBoot3',
                'Slot18NicBoot4',
                'Slot19NicBoot1',
                'Slot19NicBoot2',
                'Slot19NicBoot3',
                'Slot19NicBoot4',
                'Slot20NicBoot1',
                'Slot20NicBoot2',
                'Slot20NicBoot3',
                'Slot20NicBoot4',
                'Slot1StorageBoot',
                'Slot2StorageBoot',
                'Slot3StorageBoot',
                'Slot4StorageBoot',
                'Slot5StorageBoot',
                'Slot6StorageBoot',
                'Slot7StorageBoot',
                'Slot8StorageBoot',
                'Slot9StorageBoot',
                'Slot10StorageBoot',
                'Slot11StorageBoot',
                'Slot12StorageBoot',
                'Slot13StorageBoot',
                'Slot14StorageBoot',
                'Slot15StorageBoot',
                'Slot16StorageBoot',
                'Slot17StorageBoot',
                'Slot18StorageBoot',
                'Slot19StorageBoot',
                'Slot20StorageBoot',
                'ThermalConfig',
                'TimeFormat',
                'TimeZone',
                'Tpm20SoftwareInterfaceOperation',
                'Tpm20SoftwareInterfaceStatus',
                'Tpm2Operation',
                'TpmActivePcrs',
                'TpmChipId',
                'TpmFips',
                'TpmFipsModeSwitch',
                'TpmModeSwitchOperation',
                'TpmOperation',
                'TpmState',
                'TpmType',
                'TpmVisibility',
                'UefiSerialDebugLevel',
                'UefiShellStartupLocation',
                'UefiShellStartupUrl',
                'UncoreFreqScaling',
                'UrlBootFile',
                'UrlBootFile2',
                'UsbControl',
                'UtilityLang',
                'VideoOptions',
                'VirtualSerialPort',
                'VlanId',
                'VlanPriority',
                'XptPrefetcher',
                'XGMIForceLinkWidth',
                'XGMIMaxLinkWidth',
                'iSCSIPolicy'
            )

            #EndRegion


            foreach ($stringparameter in $stringparametersList) {
                
                if ($PSBoundParameters.ContainsKey($stringparameter)) {
                    
                    $param1Value = $PSBoundParameters[$stringparameter]

                    $Attributes."$stringparameter" = $param1Value
                }
                elseif (-not $PSBoundParameters.ContainsKey($stringparameter)) {

                    if ($SettingResource.redfishData.Attributes."$stringparameter") {
                            
                        $Attributes."$stringparameter" = $SettingResource.redfishData.Attributes."$stringparameter"
                    }
                }
            }

            if ($PSBoundParameters.ContainsKey('EnabledCoresPerProcIlo6_7')) {

                $Attributes.EnabledCoresPerProc = $EnabledCoresPerProcIlo6_7
            } 
            elseif ($PSBoundParameters.ContainsKey('EnabledCoresPerProcIlo5')) {

                $Attributes.EnabledCoresPerProc = $EnabledCoresPerProcIlo5
                
            }
            elseif (-not $PSBoundParameters.ContainsKey('EnabledCoresPerProcIlo5') -and -not $PSBoundParameters.ContainsKey('EnabledCoresPerProcIlo6_7')) {

                if ($SettingResource.redfishData.Attributes.EnabledCoresPerProc) {
                    
                    $Attributes.EnabledCoresPerProc = $SettingResource.redfishData.Attributes.EnabledCoresPerProc
                }

            }

            if ($AsrTimeoutMinutes) {
                $Attributes.AsrStatus = "Enabled"
            }

            if ($SubNumaClustering) {
                # Options that must be enabled when Sub-Numa Clustering (SNC) is enabled:
                $Attributes.XptPrefetcher = "Enabled"
                $Attributes.UpiPrefetcher = "Enabled"
            }

            $CustomizedSettings = $False
             
            if ($Attributes.count -gt 0) {
                $CustomizedSettings = $True    
            }
            


            $WorkloadProfileNameValue = $False
            $RequireCustomProfile = $False

            
            if (-not $PSBoundParameters.ContainsKey('WorkloadProfileName')) {
        
                if ($SettingResource.redfishData.Attributes.WorkloadProfile) {
                            
                    $WorkloadProfileNameValue = $SettingResource.redfishData.Attributes.WorkloadProfile
                }

            }
            else {
                # Map the friendly name to the actual value
                switch ($WorkloadProfileName) {
                    "General Power Efficient Compute"       { $WorkloadProfileNameValue = "GeneralPowerEfficientCompute" }
                    "General Peak Frequency Compute"        { $WorkloadProfileNameValue = "GeneralPeakFrequencyCompute" }
                    "General Throughput Compute"            { $WorkloadProfileNameValue = "GeneralThroughputCompute" }
                    "Virtualization - Power Efficient"      { $WorkloadProfileNameValue = "Virtualization-PowerEfficient" }
                    "Virtualization - Max Performance"      { $WorkloadProfileNameValue = "Virtualization-MaxPerformance" }
                    "Low Latency"                           { $WorkloadProfileNameValue = "LowLatency" }
                    "Mission Critical"                      { $WorkloadProfileNameValue = "MissionCritical" }
                    "Transactional Application Processing"  { $WorkloadProfileNameValue = "TransactionalApplicationProcessing" }
                    "High Performance Compute (HPC)"        { $WorkloadProfileNameValue = "HighPerformanceCompute(HPC)" }
                    "Decision Support"                      { $WorkloadProfileNameValue = "DecisionSupport" }
                    "Graphic Processing"                    { $WorkloadProfileNameValue = "GraphicProcessing" }
                    "I/O Throughput"                        { $WorkloadProfileNameValue = "I/OThroughput" }
                    "Virtual Radio Access Network (vRAN)"   { $WorkloadProfileNameValue = "vRAN" }
                }
            }  
        
            if ($WorkloadProfileNameValue) {
                $Attributes.WorkloadProfile = $WorkloadProfileNameValue

                # Determine if a custom workload profile is required
                if ($True -eq $CustomizedSettings ) {
                    $RequireCustomProfile = $True 
                }
            }
            
            # Build payload

            if ($RequireCustomProfile) {
                $Default = @{ 
                    redfishData                 = @{
                        Attributes = $Attributes
                    }
                    enableCustomWorkloadProfile = $True
                }
            }
            else {
                $Default = @{ 
                    redfishData = @{
                        Attributes = $Attributes
                    }
                }
            }
            

            $Settings = @{ 
                DEFAULT = $Default
            }

            $payload = @{ 
                name           = $Name
                description    = $Description
                settings       = $Settings                  
            }

            $payload = ConvertTo-Json $payload -Depth 10 

            try {

                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method PATCH -body $payload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                if (-not $WhatIf ) {
        
                    "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

                    "[{0}] Bios server setting '{1}' successfully updated in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
                        
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Bios server setting successfully updated in $Region region"


                }
            }
            catch {

                if (-not $WhatIf) {

                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Bios server setting cannot be updated!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 

                }
            } 
        }

        [void] $SetServerSettingBiosStatus.add($objStatus)
    
    }
    
    
    End {
       

        if (-not $WhatIf ) {

            $SetServerSettingBiosStatus = Invoke-RepackageObjectWithType -RawObject $SetServerSettingBiosStatus -ObjectName "COM.objStatus.NSDE"    
            Return $SetServerSettingBiosStatus
        
        }

    }
}

Function New-HPECOMSettingServerInternalStorageVolume {
    <#
    .SYNOPSIS
    Create volumes to be used with Set-HPECOMSettingServerInternalStorage to create a server internal storage setting. 

    .DESCRIPTION
    This Cmdlet creates a volume object that is required to create a server internal storage setting using Set-HPECOMSettingServerInternalStorage.

    .PARAMETER RAID
    Specifies the RAID type:
        - RAID0: Uses disk striping. Optimized for I/O speed and efficient use of physical disk capacity, but provides no data redundancy.
          Requires a minimum of 1 drive. You can add drives in increments of 1 up to 32 drives.

        - RAID1: Uses disk mirroring. Optimized for data redundancy and I/O speed, but uses more physical disk drives.
          Requires 2 drives.

        - RAID10: Combines RAID0 and RAID1. Optimized for performance and fault tolerance.
          Requires a minimum of 4 drives. You can add drives in increments of 2 up to 32 drives.

        - RAID1Triple: Uses disk mirroring with three copies of data. Optimized for data redundancy and I/O speed.
          Requires 3 drives.

        - RAID10Triple: Combines RAID0 and RAID1 with three copies of data. Optimized for performance and fault tolerance.
          Requires a minimum of 6 drives. You can add drives in increments of 3 up to 30 drives.

        - RAID5: Uses disk striping with parity. Optimized for performance and fault tolerance.
          Requires a minimum of 3 drives. You can add drives in increments of 1 up to 32 drives.

        - RAID50: Combines RAID0 and RAID1 with parity. Optimized for performance and fault tolerance. 
          Requires a minimum of 6 drives. You can add drives in increments of 2 up to 32 drives.

        - RAID6: Uses disk striping with parity. Optimized for performance and fault tolerance.
          Requires a minimum of 4 drives. You can add drives in increments of 1 up to 32 drives.

        - RAID60: Combines RAID0 and RAID1 with parity. Optimized for performance and fault tolerance.
          Requires a minimum of 8 drives. You can add drives in increments of 2 up to 32 drives.

    .PARAMETER DrivesNumber
    Specifies the number of drives to be used. The default value is the minimum number of drives required for the selected RAID type.

    .PARAMETER DriveTechnology
    Specifies the drive technology. Selecting a drive technology value helps you to prepare volumes for future use. 
    For example, you might want to use SAS SSD drives to create a volume for OS installation, or use a SATA HDD drive for a long-term data storage solution. 
    Supported values: SAS HDD, SAS SSD, SATA HDD, SATA SDD, NVMe SSD

    .PARAMETER SpareDriveNumber
    Specifies the number of spare drives to be added to the volume. The default value is 0. 
    This option is not supported with RAID 0. Spare drives will not be accessible to other volumes defined within the same server setting.

    .PARAMETER SizeinGB
    Creates a volume using the full drive capacity of the selected drives.
    When not used, a volume using the full drive capacity of the selected drives is created.

    .PARAMETER IOPerformanceMode   
    Specifies the I/O performance mode for the internal storage server setting.
    I/O performance mode is an intelligent I/O passthrough mechanism for SSD arrays. This feature can boost storage subsystem and application performance, especially for applications that use high random read/write operation workloads.

    By default, this feature is set to 'Not managed', which means that Compute Ops Management does not set any value for the feature. When this feature is not managed through Compute Ops Management, the default value set by the controller is used.

    .PARAMETER ReadCachePolicy   
    Specifies the read cache policy for the internal storage server setting.
    Read cache policy controls the behavior when a server reads from a volume. When read caching is enabled, I/O performance is improved by satisfying read requests from the controller memory instead of from physical disks.

    By default, this feature is set to 'Not managed', which means that Compute Ops Management does not set any value for the feature. When this feature is not managed through Compute Ops Management, the default value set by the controller is used.

    .PARAMETER WriteCachePolicy   
    Specifies the write cache policy for the internal storage server setting.
    Write cache policy controls the behavior when a server writes to a volume. Data can be written to the cache and storage at the same time, or it can be written to the cache first, and then written to the storage later.

    By default, this feature is set to 'Not managed', which means that Compute Ops Management does not set any value for the feature. When this feature is not managed through Compute Ops Management, the default value set by the controller is used.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    $volume1 = New-HPECOMSettingServerInternalStorageVolume -RAID RAID5 -DriveTechnology NVME_SSD -IOPerformanceMode -ReadCachePolicy OFF -WriteCachePolicy WRITE_THROUGH -SizeinGB 100 -DrivesNumber 3 -SpareDriveNumber 2
    $volume2 = New-HPECOMSettingServerInternalStorageVolume -RAID RAID1 -DriveTechnology SAS_HDD
    New-HPECOMSettingServerInternalStorage -Region eu-central -Name "RAID_CONF_FOR_AI_SERVERS" -Description "My server setting for the AI servers" -Volume $volume1,$volume2 

    This example demonstrates how to create two internal storage volumes. The first volume is a RAID5 configuration with NVMe SSD drives, I/O performance mode enabled, and a size of 100GB. 
    The second volume is a RAID1 configuration with SAS HDD drives. Finally, the volumes are used to create a server setting named 'RAID_CONF_FOR_AI_SERVERS' in the central European region. 
    This server setting is created using the 'New-HPECOMSettingServerInternalStorage' Cmdlet, which allows for the configuration of internal storage settings for servers.  

    .INPUTS
    Pipeline input is not supported.

    .OUTPUTS
    [PSCustomObject]@{
        raidType           = $RAID
        capacityInGiB      = $SizeinGB
        driveCount         = $DrivesNumber
        spareDriveCount    = $SpareDriveNumber
        driveTechnology    = $DriveTechnology
        ioPerfModeEnabled  = $IOPerformanceMode
        readCachePolicy    = $ReadCachePolicy
        writeCachePolicy   = $WriteCachePolicy
    }
        
        

    #>

    [CmdletBinding()]
    Param(        
        [Parameter (Mandatory)]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $RAIDs = @('RAID0', 'RAID1', 'RAID1_TRIPLE', 'RAID10', 'RAID10_TRIPLE', 'RAID5', 'RAID50', 'RAID6', 'RAID60')
                $filteredRAIDs = $RAIDs | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredRAIDs | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('RAID0', 'RAID1', 'RAID1_TRIPLE', 'RAID10', 'RAID10_TRIPLE', 'RAID5', 'RAID50', 'RAID6', 'RAID60')]
        [String]$RAID,

        [Int]$DrivesNumber,

        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $RAIDs = @('SAS_HDD', 'SAS_SSD', 'SATA_HDD', 'SATA_SSD', 'NVME_SSD')
            $filteredRAIDs = $RAIDs | Where-Object { $_ -like "$wordToComplete*" }
            return $filteredRAIDs | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
            }
        })]
        [ValidateSet ('SAS_HDD', 'SAS_SSD', 'SATA_HDD', 'SATA_SSD', 'NVME_SSD')]
        [String]$DriveTechnology,

        [Int]$SpareDriveNumber,

        [Int]$SizeinGB,

        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $RAIDs = @('ENABLED', 'DISABLED')
            $filteredRAIDs = $RAIDs | Where-Object { $_ -like "$wordToComplete*" }
            return $filteredRAIDs | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
            }
        })]
        [ValidateSet ('ENABLED', 'DISABLED')]
        [String]$IOPerformanceMode,

        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $RAIDs = @('READ_AHEAD', 'ADAPTIVE_READ_AHEAD', 'OFF')
            $filteredRAIDs = $RAIDs | Where-Object { $_ -like "$wordToComplete*" }
            return $filteredRAIDs | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
            }
        })]
        [ValidateSet ('PROTECTED_WRITE_BACK', 'UNPROTECTED_WRITE_BACK', 'WRITE_THROUGH', 'OFF')]
        [String]$ReadCachePolicy,

        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            $RAIDs = @('PROTECTED_WRITE_BACK', 'UNPROTECTED_WRITE_BACK', 'WRITE_THROUGH', 'OFF')
            $filteredRAIDs = $RAIDs | Where-Object { $_ -like "$wordToComplete*" }
            return $filteredRAIDs | ForEach-Object {
                [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
            }
        })]
        [ValidateSet ('PROTECTED_WRITE_BACK', 'UNPROTECTED_WRITE_BACK', 'WRITE_THROUGH', 'OFF')]
        [String]$WriteCachePolicy,

        [Switch]$WhatIf
       
    ) 
    Begin {
        # Initialize the volume object
        $volume = [PSCustomObject]@{
            raidType           = $RAID
            capacityInGiB      = $null
            driveCount         = $null
            spareDriveCount    = $null
            driveTechnology    = $null
            ioPerfModeEnabled  = $null
            readCachePolicy    = $null
            writeCachePolicy   = $null
        }
    }

    Process {

        if ($RAID -eq "RAID0" -and $SpareDriveNumber -gt 0) {
            Write-Error "RAID0 does not support spare drives!"
            return
        }

        if ($PSBoundParameters.ContainsKey('SizeinGB')) {
            $volume.capacityInGiB = $SizeinGB
        }
       
        if ($PSBoundParameters.ContainsKey('DrivesNumber')) {
            $volume.driveCount = $DrivesNumber
        }
        else {
            if ($RAID -eq "RAID0") {
                $volume.driveCount = 1
            }
            elseif ($RAID -eq "RAID1") {
                $volume.driveCount = 2
            }
            elseif ($RAID -eq "RAID10") {
                $volume.driveCount = 4
            }
            elseif ($RAID -eq "RAID1Triple") {
                $volume.driveCount = 3
            }
            elseif ($RAID -eq "RAID10Triple") {
                $volume.driveCount = 6
            }
            elseif ($RAID -eq "RAID5") {
                $volume.driveCount = 3
            }
            elseif ($RAID -eq "RAID50") {
                $volume.driveCount = 6
            }   
            elseif ($RAID -eq "RAID6") {
                $volume.driveCount = 4
            }
            elseif ($RAID -eq "RAID60") {
                $volume.driveCount = 8
            } 
        }

        if ($PSBoundParameters.ContainsKey('SpareDriveNumber')) {
            $volume.spareDriveCount = $SpareDriveNumber
        }

        if ($PSBoundParameters.ContainsKey('DriveTechnology')) {
            $volume.driveTechnology = $DriveTechnology
        }

        if ($PSBoundParameters.ContainsKey('IOPerformanceMode')) {
            
            if ($IOPerformanceMode -eq "ENABLED") {
                $IOPerformanceModeBoolean = $true
            }
            elseif ($IOPerformanceMode -eq "DISABLED") {
                $IOPerformanceModeBoolean = $false
            }

            $volume.ioPerfModeEnabled = $IOPerformanceModeBoolean
        }

        if ($PSBoundParameters.ContainsKey('ReadCachePolicy')) {
            $volume.readCachePolicy = $ReadCachePolicy
        }
        
        if ($PSBoundParameters.ContainsKey('WriteCachePolicy')) {
            $volume.writeCachePolicy = $WriteCachePolicy
        }

        if ($WhatIf) {
            Write-Host "WhatIf: Would create volume object with properties:"
            $volume | Format-List
            return
        }

        # Output the volume object
        $volume
    }

    End {
        # No cleanup needed
    }
}

Function New-HPECOMSettingServerInternalStorage {
    <#
    .SYNOPSIS
    Configures an internal storage server setting.

    .DESCRIPTION
    This Cmdlet is used to create a new internal storage server setting with specified RAID type and size.
    Internal storage server settings enable consistent storage configurations across servers in a group.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name
    Specifies the name of the internal storage server setting.

    .PARAMETER Description
    Provides a description for the internal storage server setting.

   .PARAMETER Volumes
    Specifies the volumes to be included in the internal storage server setting. 
    This parameter accepts an array of volume objects created using the 'New-HPECOMSettingServerInternalStorageVolume' cmdlet.
     
    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. Useful for understanding the native REST API calls used by COM.

    .EXAMPLE
    $volume1 = New-HPECOMSettingServerInternalStorageVolume -RAID RAID5 -DriveTechnology NVME_SSD -IOPerformanceMode ENABLED -ReadCachePolicy OFF -WriteCachePolicy WRITE_THROUGH -SizeinGB 100 -DrivesNumber 3 -SpareDriveNumber 2 
    $volume2 = New-HPECOMSettingServerInternalStorageVolume -RAID RAID1 -DriveTechnology SAS_HDD 
    New-HPECOMSettingServerInternalStorage -Region "eu-central" -Name "MyStorage" -Description "My storage description" -Volumes $volume1, $volume2 

    Creates a new internal storage server setting named "MyStorage" in the "eu-central" region with the specified description and volumes.
    The volumes are created using the 'New-HPECOMSettingServerInternalStorageVolume' cmdlet.    

    .EXAMPLE
    New-HPECOMSettingServerInternalStorageVolume -RAID RAID1 -DriveTechnology SAS_HDD | New-HPECOMSettingServerInternalStorage -Region eu-central -Name "RAID-FOR_AI" -Description MyDescription 

    Creates a new internal storage server setting named "RAID-FOR_AI" in the "eu-central" region using the specified volume provided through the pipeline, along with a description.
    The volume is created using the 'New-HPECOMSettingServerInternalStorageVolume' cmdlet.

    .EXAMPLE
    $volume1, $Volume2 | New-HPECOMSettingServerInternalStorage -Region eu-central -Name "RAID-FOR_AI"

    Creates a new internal storage server setting named "RAID-FOR_AI" in the "eu-central" region using the specified volumes provided through the pipeline.

    .INPUTS
    Pipeline input is supported. The input must be an array of volume objects created using the 'New-HPECOMSettingServerInternalStorageVolume' cmdlet.
    The input can be passed directly to the 'Volumes' parameter.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:
        * Name - The name of the internal storage server setting attempted to be created.
        * Region - The name of the region.
        * Status - The creation attempt's status (Failed for HTTP error return; Complete if successful; Warning if no action is needed).
        * Details - Additional information about the status.
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

        [Parameter (Mandatory)]
        [ValidateScript({ $_.Length -le 100 })]
        [String]$Name,  
        
        [ValidateScript({ $_.Length -le 1000 })]
        [String]$Description,    
        
        [Parameter (Mandatory, ValueFromPipeline)]
        [Object]$Volumes,

        [Switch]$WhatIf
       
    ) 
    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-COMSettingsUri

        $VolumesObject = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        [void] $VolumesObject.add($Volumes)

    
    }
    
    End {

          # Build object for the output
          $objStatus = [pscustomobject]@{
            Name      = $Name
            Region    = $Region                            
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }
    
        try {
            $SettingResource = Get-HPECOMSetting -Region $Region -Name $Name -Category Storage

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)

        }

        if ($SettingResource) {

            "[{0}] Setting '{1}' is already present in the '{2}' region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
    
            if ($WhatIf) {
                $ErrorMessage = "Setting '{0}': Resource is already present in the '{1}' region! No action needed." -f $Name, $Region
                Write-warning $ErrorMessage
                Return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "Setting already exists in the region! No action needed."
            }
        }
        else {
            # Setting resource is not present, proceed to create it
            "[{0}] Setting '{1}' is not present in the '{2}' region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose

            # Build payload

            $Settings = @{ 
                DEFAULT = @{
                    volumes = @($VolumesObject | ForEach-Object { $_ })
                }
            }

            $payload = @{ 
                name           = $Name
                category       = "STORAGE"
                description    = $Description
                settings       = $Settings                  
            }

            $payload = ConvertTo-Json $payload -Depth 10 

            try {

                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                if (-not $WhatIf ) {
        
                    "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

                    "[{0}] Internal storage server setting '{1}' successfully created in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
                        
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Internal storage server setting successfully created in $Region region"


                }
            }
            catch {

                if (-not $WhatIf) {

                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Internal storage server setting cannot be created!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 

                }
            } 
        }

        if (-not $WhatIf ) {

            $NewServerSettingInternalStorageStatus = Invoke-RepackageObjectWithType -RawObject $objStatus -ObjectName "COM.objStatus.NSDE"    
            Return $NewServerSettingInternalStorageStatus
        
        }
    }
}

Function Set-HPECOMSettingServerInternalStorage {
    <#
    .SYNOPSIS
    Update an internal storage server setting resource in a specified region.

    .DESCRIPTION
    This Cmdlet modifies an internal storage server setting resource in a given region. If a parameter is not provided, the cmdlet retains the current settings and only updates the provided parameters.

    .PARAMETER Name
    Specifies the name of the internal storage server setting to update.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER NewName 
    Specifies the new name for the internal storage server setting.

    .PARAMETER Description
    Specifies a new description of the internal storage server setting.
    
    .PARAMETER Volumes   
    Specifies the volumes to be associated with the internal storage server setting. This parameter allows for detailed configuration of storage volumes, including RAID type and size.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Set-HPECOMSettingServerInternalStorage -Region eu-central -Name "RAID1" -NewName "RAID-1"

    This example updates the name of the internal storage server setting from "RAID1" to "RAID-1" in the "eu-central" region.

    .EXAMPLE
    Set-HPECOMSettingServerInternalStorage -Region eu-central -Name "RAID1" -Description "Local storage settings using RAID1 and entire disk for OS"
    
    This example updates the description of the internal storage server setting "RAID1" in the "eu-central" region, describing it as "Local storage settings using RAID1 and entire disk for OS".

    .EXAMPLE
    $volume1 = New-HPECOMSettingServerInternalStorageVolume -RAID RAID5 -DriveTechnology NVME_SSD -IOPerformanceMode -ReadCachePolicy OFF -WriteCachePolicy WRITE_THROUGH -SizeinGB 100 -DrivesNumber 3 -SpareDriveNumber 2 
    $volume2 = New-HPECOMSettingServerInternalStorageVolume -RAID RAID1 -DriveTechnology SAS_HDD 
    Set-HPECOMSettingServerInternalStorage -Region eu-central -Name "AI_SERVER_RAID1&5" -Volumes $volume1, $volume2 

    This example changes the volumes configuration of the internal storage server setting named "AI_SERVER_RAID1&5" in the "eu-central" region.

    .EXAMPLE
    Get-HPECOMSetting -Region eu-central -Category Storage | Set-HPECOMSettingServerInternalStorage -EntireDisk 
    
    This example retrieves all storage settings from the "eu-central" region and pipes them to update the internal storage server setting to use the entire disk.

    .EXAMPLE
    Get-HPECOMSetting -Region eu-central -Category Storage -Name 'AI_SERVER_RAID1' | Set-HPECOMSettingServerInternalStorage -Volumes $volume1 

    This example retrieves the internal storage server setting named "AI_SERVER_RAID1" from the "eu-central" region and updates its volumes configuration to use the specified volume object created using the 'New-HPECOMSettingServerInternalStorageVolume' cmdlet.

    .INPUTS
    System.Collections.ArrayList
        List of internal storage server settings from 'Get-HPECOMSetting -Category Storage'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:
        * Name - The name of the internal storage server setting attempted to be updated
        * Region - The name of the region
        * Status - Status of the modification attempt (Failed for HTTP error return; Complete if creation is successful; Warning if no action is needed)
        * Details - More information about the status 
        * Exception - Information about any exceptions generated during the operation.
    #>


    [CmdletBinding(DefaultParameterSetName = 'EntireDisk')]
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
        [String]$Name,  

        [ValidateScript({ $_.Length -le 100 })]
        [String]$NewName,
        
        [ValidateScript({ $_.Length -le 1000 })]
        [String]$Description,    
                
        [Object]$Volumes,

        [Switch]$WhatIf
       
    ) 
    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-COMSettingsUri
        $SetServerSettingInternalStorageStatus = [System.Collections.ArrayList]::new()
        
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
            $SettingResource = Get-HPECOMSetting -Region $Region -Name $Name -Category Storage
            $SettingID = $SettingResource.id
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)

        }


        if (-not $SettingResource) {
            
            # Must return a message if not found

            if ($WhatIf) {

                $ErrorMessage = "Setting '{0}': Resource cannot be found in the '{1}' region!" -f $Name, $Region
                Write-warning $ErrorMessage
                return
            
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "Setting cannot be found in the region!"
            }
        }
        else {

            $Uri = (Get-COMSettingsUri) + "/" + $SettingID

            # Conditionally add properties
            if ($NewName) {
                $Name = $NewName
            }

            if (-not $Volumes){
                $Volumes = $SettingResource.volumes
            }

            if (-not $PSBoundParameters.ContainsKey('Description')) {
	    
                if ($SettingResource.description) {
                              
                    $Description = $SettingResource.description
                }
                else {
                    $Description = $Null
                }
            }            


            # Build payload

            $Settings = @{ 
                DEFAULT = @{
                    volumes = @($Volumes)
                }
            }

            $payload = @{ 
                name           = $Name
                description    = $Description
                settings       = $Settings                  
            }

            $payload = ConvertTo-Json $payload -Depth 10 

            try {

                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method PATCH -body $payload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                if (-not $WhatIf ) {
    
                    "[{0}] Setting update raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

                    "[{0}] Internal storage server setting '{1}' successfully updated in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
                    
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Internal storage server setting successfully updated in $Region region"

                }
            }
            catch {

                if (-not $WhatIf) {

                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Internal storage server setting cannot be updated!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 

                }
            } 
        }

        [void] $SetServerSettingInternalStorageStatus.add($objStatus)

    
    }
    
    End {
       

        if (-not $WhatIf ) {

            $SetServerSettingInternalStorageStatus = Invoke-RepackageObjectWithType -RawObject $SetServerSettingInternalStorageStatus -ObjectName "COM.objStatus.NSDE"    
            Return $SetServerSettingInternalStorageStatus
        
        }

    }
}

Function New-HPECOMSettingServerOSImage {
    <#
    .SYNOPSIS
    Configure an OS image configuration server setting.

    .DESCRIPTION
    This Cmdlet is used to create a new operating system image configuration server setting.
    OS image configurations enable consistent OS installations across servers in a group.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name
    Specifies the name of the OS image configuration server setting.

    .PARAMETER Description
    Provides a description for the OS image configuration server setting.

    .PARAMETER OperatingSystem
    Specifies the operating system:
        - VMware ESXi
        - Microsoft Windows
        - Red Hat Enterprise Linux
        - Suse Linux
        - Ubuntu Linux

    Note: Compute Ops Management can detect completion of operating system install via HPE Agentless Management Service. 
          Ensure that the operating system image includes HPE Agentless Management Service utility.
    
    .PARAMETER OSImageURL
    Specifies the full URL location of the OS image.

    Example: https://hostname.domain.com/ImageName.iso

    Note: Compute Ops Management uses the iLO virtual media feature for operating system installation. 
          Ensure that iLO can access the virtual media URL and that there are no connectivity issues

    .PARAMETER UnattendedInstallationFileImageUrl
    Specifies the full URL location of the ISO file for the unattended installation file image.

    Example: https://hostname.domain.com/kickstart.iso

    Note: Compute Ops Management uses the iLO virtual media feature for operating system installation. 
          Ensure that iLO can access the virtual media URL and that there are no connectivity issues

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    New-HPECOMSettingServerOSImage -Region  us-west -Name OS-ESX -Description "My ESX OS image SS" -OperatingSystem VMWARE_ESXI -OSImageURL "https://domain.com/esx.iso" 

    This command creates a new OS image configuration server setting named 'OS-ESX' using a single image containing OS and unattended installation file from the URL 'https://domain.com/esx8.iso' in the 'us-west' region.

    .EXAMPLE
    New-HPECOMSettingServerOSImage -Region us-west -Name OS-ESX -Description "My ESX 8 OS image configuration" -OperatingSystem VMWARE_ESXI -OSImageURL "https://domain.com/esx8.iso" -UnattendedInstallationFileImageUrl "https://domain.com/esx_ks.iso" 
    
    This command creates a new OS image configuration server setting named 'OS-ESX' using a separate image for OS from the URL 'https://domain.com/esx8.iso' and for the unattended file from the URL 'https://domain.com/esx_ks.iso'.

    .INPUTS
    Pipeline input is not supported.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:
        * Name - The name of the OS image configuration server setting attempted to be created
        * Region - The name of the region
        * Status - Status of the creation attempt (Failed for HTTP error return; Complete if creation is successful; Warning if no action is needed)
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
        
        [ValidateScript({ $_.Length -le 1000 })]
        [String]$Description,    
        
        [Parameter (Mandatory)]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('MICROSOFT_WINDOWS', 'VMWARE_ESXI', 'RHEL', 'SUSE_LINUX', 'CUSTOM')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('MICROSOFT_WINDOWS', 'VMWARE_ESXI', 'RHEL', 'SUSE_LINUX', 'UBUNTU_LINUX', 'CUSTOM')]
        [String]$OperatingSystem,
        
        [Parameter (Mandatory, ParameterSetName = 'SingleImage')]
        [Parameter (Mandatory, ParameterSetName = 'SeparateImages')]
        [ValidateScript({
                if ($_ -match "^(http|https)://[^\s/$.?#].[^\s]*$") {
                    $true
                }
                else {
                    throw "The value '$($_)' is not a valid URL."
                }
            })]
        [string]$OSImageURL,

        [Parameter (Mandatory, ParameterSetName = 'SeparateImages')]
        [ValidateScript({
                if ($_ -match "^(http|https)://[^\s/$.?#].[^\s]*$") {
                    $true
                }
                else {
                    throw "The value '$($_)' is not a valid URL."
                }
            })]
        [string]$UnattendedInstallationFileImageUrl,

        [Switch]$WhatIf
       
    ) 
    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-COMSettingsUri
        $NewServerSettingOSImageConfigurationStatus = [System.Collections.ArrayList]::new()
        
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
            $SettingResource = Get-HPECOMSetting -Region $Region -Name $Name -Category Os

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)

        }

        if ($SettingResource) {

            "[{0}] Setting '{1}' is already present in the '{2}' region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
    
            if ($WhatIf) {
                $ErrorMessage = "Setting '{0}': Resource is already present in the '{1}' region! No action needed." -f $Name, $Region
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "Setting already exists in the region! No action needed."
            }

        }
        else {

            # Build payload
    
            if ($UnattendedInstallationFileImageUrl) {
    
                $Settings = @{ 
                    DEFAULT = @{
                        osType                        = $OperatingSystem
                        mediaUrl                      = $OSImageURL
                        unattendedInstallationFileUrl = $UnattendedInstallationFileImageUrl
    
                    }
                }
            }
            else {
                
                $Settings = @{ 
                    DEFAULT = @{
                        osType   = $OperatingSystem
                        mediaUrl = $OSImageURL
                    }
                }
            }
    
    
            $payload = @{ 
                name           = $Name
                category       = "OS"
                description    = $Description
                settings       = $Settings                  
            }
    
            $payload = ConvertTo-Json $payload -Depth 10 
    
            try {
    
                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
    
                if (-not $WhatIf ) {
        
                    "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
    
                    "[{0}] OS image configuration server setting '{1}' successfully created in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
                        
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "OS image configuration server setting successfully created in $Region region"
    
    
                }
            }
            catch {
    
                if (-not $WhatIf) {
    
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "OS image configuration server setting cannot be created!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
    
                }
            } 
        }
        

        [void] $NewServerSettingOSImageConfigurationStatus.add($objStatus)

    
    }
    
    End {

        if (-not $WhatIf ) {
            
            $NewServerSettingOSImageConfigurationStatus = Invoke-RepackageObjectWithType -RawObject $NewServerSettingOSImageConfigurationStatus -ObjectName "COM.objStatus.NSDE"    
            Return $NewServerSettingOSImageConfigurationStatus
        
        }

    }
}

Function Set-HPECOMSettingServerOSImage {
    <#
    .SYNOPSIS
    Update the configuration of an OS image server setting resource in a specified region.

    .DESCRIPTION
    This Cmdlet modifies an OS image configuration server setting resource in a designated Compute Ops Management (COM) region. If certain parameters are not specified, the cmdlet retains their existing settings and only updates those that are provided.

    .PARAMETER Name
    Specifies the name of the OS image configuration server setting to update.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER NewName 
    Specifies the new name for the OS image configuration server setting.

    .PARAMETER Description
    Specifies a new description for the OS image configuration server setting.

    .PARAMETER OperatingSystem
    Specifies the new operating system:
        - VMware ESXi
        - Microsoft Windows
        - Red Hat Enterprise Linux
        - SUSE Linux

    Note: Compute Ops Management can detect the completion of an operating system install via HPE Agentless Management Service. Ensure that the OS image includes this utility.

    .PARAMETER OSImageURL
    Specifies the new full URL location of the OS image.

    Example: https://hostname.domain.com/ImageName.iso

    Note: Compute Ops Management uses the iLO virtual media feature for operating system installation. Ensure that iLO can access the virtual media URL without any connectivity issues.

    .PARAMETER UnattendedInstallationFileImageUrl
    Specifies the new full URL location of the ISO file for the unattended installation file image.

    Example: https://hostname.domain.com/kickstart.iso

    Note: Compute Ops Management uses the iLO virtual media feature for operating system installation. Ensure that iLO can access the virtual media URL without any connectivity issues.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Set-HPECOMSettingServerOSImage -Region eu-central -Name OS_ESXi -NewName ESXi_800

    This command updates the name of the OS image configuration server setting from 'OS_ESXi' to 'ESXi_800' in the 'eu-central' region.

    .EXAMPLE
    Set-HPECOMSettingServerOSImage -Region eu-central -Name OS_ESXi -UnattendedInstallationFileImageUrl "https://domain.com/esx_ks.iso"
    
    This command updates the URL for the unattended installation file image to "https://domain.com/esx_ks.iso" for the OS image configuration named 'OS_ESXi' in the 'eu-central' region.

    .EXAMPLE
    Set-HPECOMSettingServerOSImage -Region eu-central -Name OS_ESXi -Description "OS Image for ESXi 8.00" -OperatingSystem VMWARE_ESXI -OSImageURL "https://domain.lab/deployment/esxi80u2/VMware-ESXi-8.0.2-22380479-HPE-802.0.0.11.4.0.14-Sep2023.iso" -UnattendedInstallationFileImageUrl ""
    
    This command updates multiple parameters for the OS image configuration named 'OS_ESXi':
     - Sets the description to "OS Image for ESXi 8.00"
     - Specifies the operating system as 'VMware ESXi'
     - Updates the OS image URL to the provided link
     - Clears the unattended installation file image URL
    This modification is applied in the 'eu-central' region.

    .EXAMPLE
    Get-HPECOMSetting -Region eu-central -Category OS | Set-HPECOMSettingServerOSImage -Description "My new description"
    
    This command first retrieves all OS image configuration settings in the 'eu-central' region using 'Get-HPECOMSetting'.
    It then pipes the retrieved settings into 'Set-HPECOMSettingServerOSImage' to update the description of each setting to "My new description".

    .INPUTS
    System.Collections.ArrayList
        List of internal OS image configuration settings from 'Get-HPECOMSetting -Category OS'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following keys:
        * Name - The name of the OS image configuration server setting attempted to be updated.
        * Region - The name of the region.
        * Status - Status of the modification attempt (Failed for HTTP error return; Complete if creation is successful; Warning if no action is needed).
        * Details - Additional information about the status.
        * Exception - Information regarding any exceptions generated during the operation.

    #>

    [CmdletBinding(DefaultParameterSetName = 'EntireDisk')]
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
        [String]$Name,  

        [ValidateScript({ $_.Length -le 100 })]
        [String]$NewName,
        
        [ValidateScript({ $_.Length -le 1000 })]
        [String]$Description,    
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $RAIDs = @('MICROSOFT_WINDOWS', 'VMWARE_ESXI', 'RHEL', 'SUSE_LINUX', 'CUSTOM')
                $filteredRAIDs = $RAIDs | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredRAIDs | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('MICROSOFT_WINDOWS', 'VMWARE_ESXI', 'RHEL', 'SUSE_LINUX', 'CUSTOM')]
        [String]$OperatingSystem,
        
        [ValidateScript({
                if ($_ -match "^(http|https)://[^\s/$.?#].[^\s]*$") {
                    $true
                }
                else {
                    throw "The value '$($_)' is not a valid URL."
                }
            })]
        [string]$OSImageURL,

        [ValidateScript({
                if ($_ -match "^(http|https)://[^\s/$.?#].[^\s]*$") {
                    $true
                }
                elseif ($_ -eq "") { 
                    $true
                }
                else {
                    throw "The value '$($_)' is not a valid URL."
                }
            })]
        [string]$UnattendedInstallationFileImageUrl,

        [Switch]$WhatIf
       
    ) 
    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-COMSettingsUri
        $SetServerSettingStatus = [System.Collections.ArrayList]::new()
        
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
            $SettingResource = Get-HPECOMSetting -Region $Region -Name $Name -Category Os
            $SettingID = $SettingResource.id
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)

        }


        if (-not $SettingResource) {
            
            # Must return a message if not found

            if ($WhatIf) {

                $ErrorMessage = "Setting '{0}': Resource cannot be found in the '{1}' region!" -f $Name, $Region
                Write-warning $ErrorMessage
                return
            
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "Setting cannot be found in the region!"
            }
        }
        else {

            $Uri = (Get-COMSettingsUri) + "/" + $SettingID

            # Conditionally add properties
            if ($NewName) {
                $Name = $NewName
            }

            if (-not $PSBoundParameters.ContainsKey('Description')) {
	    
                if ($SettingResource.description) {
                              
                    $Description = $SettingResource.description
                }
                else {
                    $Description = $Null
                }
            }            

          
            if (-not $OperatingSystem) {
                $OperatingSystem = $SettingResource.settings.default.osType
            }

            #  -UnattendedInstallationFileImageUrl "" must work as the unattended file is not mandatory so it should remove the UnattendedInstallationFileImageUrl if present
            if (-not $PSBoundParameters.ContainsKey('UnattendedInstallationFileImageUrl') ) {

                if ($SettingResource.settings.default.unattendedInstallationFileUrl) {

                    $UnattendedInstallationFileImageUrl = $SettingResource.settings.default.unattendedInstallationFileUrl
                }

            }

            if (-not $OSImageURL) {
                $OSImageURL = $SettingResource.settings.default.mediaUrl
            }

        
            if ($UnattendedInstallationFileImageUrl) {

                $Settings = @{ 
                    DEFAULT = @{
                        osType                        = $OperatingSystem
                        mediaUrl                      = $OSImageURL
                        unattendedInstallationFileUrl = $UnattendedInstallationFileImageUrl

                    }
                }
            }
            else {
            
                $Settings = @{ 
                    DEFAULT = @{
                        osType   = $OperatingSystem
                        mediaUrl = $OSImageURL
                    }
                }
            }


            $payload = @{ 
                name           = $Name
                description    = $Description
                settings       = $Settings                  
            }

            $payload = ConvertTo-Json $payload -Depth 10 

            try {

                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method PATCH -body $payload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    


                if (-not $WhatIf ) {
    
                    "[{0}] Setting update raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

                    "[{0}] OS Image server setting '{1}' successfully updated in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
                    
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "OS Image server setting successfully updated in $Region region"


                }
            }
            catch {

                if (-not $WhatIf) {

                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "OS Image server setting cannot be updated!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 

                }
            } 
        }

        [void] $SetServerSettingStatus.add($objStatus)

        
    }
    
    End {
       

        if (-not $WhatIf ) {

            $SetServerSettingStatus = Invoke-RepackageObjectWithType -RawObject $SetServerSettingStatus -ObjectName "COM.objStatus.NSDE"    
            Return $SetServerSettingStatus
        
        }

    }
}

Function New-HPECOMSettingServerFirmware {
    <#
    .SYNOPSIS
    Configure a firmware server setting.

    .DESCRIPTION
    This Cmdlet creates a new firmware baseline server setting with baseline and hotfix or patch settings.
    Firmware server settings enable you to apply consistent firmware configurations to servers in a group. 
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name
    Specifies the name of the firmware server setting.

    .PARAMETER Description
    Specifies a description for the firmware server setting.

    .PARAMETER Gen10FirmwareBaselineReleaseVersion
    Specifies the name of a baseline SPP or hotfix/patch baseline for Gen10/Gen10+ servers. 
    
    .PARAMETER Gen11FirmwareBaselineReleaseVersion
    Specifies the name of a baseline SPP or hotfix/patch baseline for Gen11 servers.

    .PARAMETER Gen12FirmwareBaselineReleaseVersion
    Specifies the name of a baseline SPP or hotfix/patch baseline for Gen12 servers.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM. 
   
    .EXAMPLE
    $Gen10_Firmware_Baseline = Get-HPECOMFirmwareBaseline -Region eu-central -Generation 10 | Select-Object -first 1 | ForEach-Object releaseversion
    $Gen11_Firmware_Baseline = Get-HPECOMFirmwareBaseline -Region eu-central -Generation 11 | Select-Object -first 1 | ForEach-Object releaseversion
    $Gen12_Firmware_Baseline = Get-HPECOMFirmwareBaseline -Region eu-central -Generation 12 | Select-Object -first 1 | ForEach-Object releaseversion

    New-HPECOMSettingServerFirmware -Region eu-central -Name Latest_Firmware_Bundle -Description "Server setting to update servers to latest firmware baseline" -Gen10FirmwareBaselineReleaseVersion $Gen10_Firmware_Baseline -Gen11FirmwareBaselineReleaseVersion $Gen11_Firmware_Baseline -Gen12FirmwareBaselineReleaseVersion $Gen12_Firmware_Baseline

    Create a new firmware server setting using dynamically retrieved firmware baseline release versions for Gen10/Gen10+, Gen11, and Gen12 servers.

    .EXAMPLE
    New-HPECOMSettingServerFirmware -Region us-west -Name SPP-2024.04.00.01 -Description "Server setting to update servers to 2024-04-00-01 firmware baseline" -Gen10FirmwareBaselineReleaseVersion 2024.04.00.01 -Gen11FirmwareBaselineReleaseVersion 2024.04.00.01 -Gen12FirmwareBaselineReleaseVersion 2024.04.00.01

    Create a new firmware server setting using specified firmware baseline release versions for Gen10, Gen11, and Gen12 servers.
       
    .INPUTS
    Pipeline input is not supported.
    
    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:
        * Name - The name of the firmware server setting attempted to be created
        * Region - The name of the region
        * Status - Status of the creation attempt (Failed for HTTP error return; Complete if creation is successful; Warning if no action is needed)
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.


    
   #>
    [CmdletBinding(DefaultParameterSetName = 'Together')]
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
        
        [ValidateScript({ $_.Length -le 1000 })]
        [String]$Description,    
        
        [Parameter (Mandatory, ParameterSetName = 'Gen10Baseline')]
        [Parameter (ParameterSetName = 'Together')]
        [Alias('Gen10FirmwareBundleReleaseVersion')]
        [String]$Gen10FirmwareBaselineReleaseVersion,

        [Parameter (Mandatory, ParameterSetName = 'Gen11Baseline')]
        [Parameter (ParameterSetName = 'Together')]
        [Alias('Gen11FirmwareBundleReleaseVersion')]
        [String]$Gen11FirmwareBaselineReleaseVersion,

        [Parameter (Mandatory, ParameterSetName = 'Gen12Baseline')]
        [Parameter (ParameterSetName = 'Together')]
        [Alias('Gen12FirmwareBundleReleaseVersion')]
        [String]$Gen12FirmwareBaselineReleaseVersion,
        
        [Switch]$WhatIf
       
    ) 
    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-COMSettingsUri
        $NewServerSettingFirmwareStatus = [System.Collections.ArrayList]::new()
        
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
            $SettingResource = Get-HPECOMSetting -Region $Region -Name $Name -Category Firmware

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)

        }

        if ($SettingResource) {

            "[{0}] Setting '{1}' is already present in the '{2}' region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
    
            if ($WhatIf) {
                $ErrorMessage = "Setting '{0}': Resource is already present in the '{1}' region! No action needed." -f $Name, $Region
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "Setting already exists in the region! No action needed."
            }

        }
        else {

            # Build payload - retrieve firmware baseline IDs for all provided generations

            $Settings = @{}
            $MissingBaselines = @()

            try {
                # Retrieve Gen10 baseline ID if specified
                if ($Gen10FirmwareBaselineReleaseVersion) {
                    $Gen10FirmwareBaselineID = (Get-HPECOMFirmwareBaseline -Region $Region -IsActive -ReleaseVersion $Gen10FirmwareBaselineReleaseVersion -Generation 10).id
                    
                    if (-not $Gen10FirmwareBaselineID) {
                        $MissingBaselines += "Gen10: $Gen10FirmwareBaselineReleaseVersion"
                    }
                    else {
                        $Settings.GEN10 = @{ id = $Gen10FirmwareBaselineID }
                    }
                }

                # Retrieve Gen11 baseline ID if specified
                if ($Gen11FirmwareBaselineReleaseVersion) {
                    $Gen11FirmwareBaselineID = (Get-HPECOMFirmwareBaseline -Region $Region -IsActive -ReleaseVersion $Gen11FirmwareBaselineReleaseVersion -Generation 11).id
                    
                    if (-not $Gen11FirmwareBaselineID) {
                        $MissingBaselines += "Gen11: $Gen11FirmwareBaselineReleaseVersion"
                    }
                    else {
                        $Settings.GEN11 = @{ id = $Gen11FirmwareBaselineID }
                    }
                }

                # Retrieve Gen12 baseline ID if specified
                if ($Gen12FirmwareBaselineReleaseVersion) {
                    $Gen12FirmwareBaselineID = (Get-HPECOMFirmwareBaseline -Region $Region -IsActive -ReleaseVersion $Gen12FirmwareBaselineReleaseVersion -Generation 12).id
                    
                    if (-not $Gen12FirmwareBaselineID) {
                        $MissingBaselines += "Gen12: $Gen12FirmwareBaselineReleaseVersion"
                    }
                    else {
                        $Settings.GEN12 = @{ id = $Gen12FirmwareBaselineID }
                    }
                }
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }

            # Check if any baselines are missing
            if ($MissingBaselines.Count -gt 0) {
                $ErrorMessage = "The following firmware baseline(s) cannot be found in the Compute Ops Management instance: $($MissingBaselines -join ', ')"
                $ErrorRecord = New-ErrorRecord FirmwareBaselineNotFoundInCOM ObjectNotFound -TargetObject 'Firmware-baselines' -Message $ErrorMessage -TargetType 'String'
                $PSCmdlet.ThrowTerminatingError($ErrorRecord)
            }

            $payload = @{ 
                name           = $Name
                category       = "FIRMWARE"
                description    = $Description
                settings       = $Settings                  
            }

            $payload = ConvertTo-Json $payload -Depth 10 

            try {

                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                if (-not $WhatIf ) {
        
                    "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

                    "[{0}] Firmware server setting '{1}' successfully created in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
                        
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Firmware server setting successfully created in $Region region"


                }
            }
            catch {

                if (-not $WhatIf) {

                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Firmware server setting cannot be created!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 

                }
            } 

        }
                

        [void] $NewServerSettingFirmwareStatus.add($objStatus)

    
    }
    
    End {
       

        if (-not $WhatIf ) {

            $NewServerSettingFirmwareStatus = Invoke-RepackageObjectWithType -RawObject $NewServerSettingFirmwareStatus -ObjectName "COM.objStatus.NSDE"
            Return $NewServerSettingFirmwareStatus
        
        }

    }
}

Function Set-HPECOMSettingServerFirmware {
    <#
    .SYNOPSIS
    Updates the configuration of a firmware server setting resource in a specified region.

    .DESCRIPTION
    This cmdlet modifies a firmware server setting resource within a designated Compute Ops Management (COM) region. 
    If certain parameters are not specified, the cmdlet retains their existing values and only updates the provided parameters.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central').
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name
    Specifies the name of the firmware server setting to update.

    .PARAMETER NewName 
    Specifies a new name for the firmware server setting.

    .PARAMETER Description
    Provides a new description for the firmware server setting.

    .PARAMETER Gen10FirmwareBaselineReleaseVersion
    Specifies the release version of the baseline SPP or hotfix/patch baseline for Gen10/Gen10+ servers. 
    Alias: Gen10FirmwareBundleReleaseVersion (for backward compatibility)

    .PARAMETER Gen11FirmwareBaselineReleaseVersion
    Specifies the release version of the baseline SPP or hotfix/patch baseline for Gen11 servers.
    Alias: Gen11FirmwareBundleReleaseVersion (for backward compatibility)

    .PARAMETER Gen12FirmwareBaselineReleaseVersion
    Specifies the release version of the baseline SPP or hotfix/patch baseline for Gen12 servers.
    Alias: Gen12FirmwareBundleReleaseVersion (for backward compatibility)

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Set-HPECOMSettingServerFirmware -Region eu-central -Name ESXi_firmware_baseline_24_04_Gen10 -NewName ESXi_firmware_baseline

    Updates the name of the firmware server setting from 'ESXi_firmware_baseline_24_04_Gen10' to 'ESXi_firmware_baseline' in the 'eu-central' region.

    .EXAMPLE
    Set-HPECOMSettingServerFirmware -Region eu-central -Name ESXi_firmware_baseline_24_04_Gen10 -Gen12FirmwareBaselineReleaseVersion 2024.04.00.01

    Updates the Gen12 firmware baseline release version to '2024.04.00.01' for the server setting named 'ESXi_firmware_baseline_24_04_Gen10' in the 'eu-central' region.

    .EXAMPLE
    Set-HPECOMSettingServerFirmware -Region eu-central -Name RHEL_firmware_baseline_2024_04_00_01 -Gen10FirmwareBaselineReleaseVersion "2024.04.00.01" -Gen11FirmwareBaselineReleaseVersion 2024.04.00.01 

    Updates both the Gen10 and Gen11 firmware baseline release versions to '2024.04.00.01' for the server setting named 'RHEL_firmware_baseline_2024_04_00_01' in the 'eu-central' region.

    .EXAMPLE
    Get-HPECOMSetting -Region eu-central -Category FIRMWARE -Name WIN_firmware_baseline | Set-HPECOMSettingServerFirmware -Description "FW server settings for 2024.04.00.02 Gen10 baseline" -Gen10FirmwareBaselineReleaseVersion "2024.04.00.02"

    Uses pipeline input to update the description and Gen10 firmware baseline release version for the server setting named 'WIN_firmware_baseline' retrieved from the 'eu-central' region.

    .INPUTS
    System.Collections.ArrayList
        List of firmware settings from 'Get-HPECOMSetting -Category FIRMWARE'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:
        * Name - The name of the firmware server setting attempted to be updated
        * Region - The name of the region
        * Status - Status of the modification attempt (Failed for HTTP error return; Complete if creation is successful; Warning if no action is needed)
        * Details - More information about the status
        * Exception - Information about any exceptions generated during the operation

    #>
    
    [CmdletBinding(DefaultParameterSetName = 'EntireDisk')]
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
        [String]$Name,  

        [ValidateScript({ $_.Length -le 100 })]
        [String]$NewName,
        
        [ValidateScript({ $_.Length -le 1000 })]
        [String]$Description,    
        
        [Alias('Gen10FirmwareBundleReleaseVersion')]
        [String]$Gen10FirmwareBaselineReleaseVersion,

        [Alias('Gen11FirmwareBundleReleaseVersion')]
        [String]$Gen11FirmwareBaselineReleaseVersion,

        [Alias('Gen12FirmwareBundleReleaseVersion')]
        [String]$Gen12FirmwareBaselineReleaseVersion,

        [Switch]$WhatIf
       
    ) 
    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-COMSettingsUri
        $SetServerSettingStatus = [System.Collections.ArrayList]::new()
        
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
            $SettingResource = Get-HPECOMSetting -Region $Region -Name $Name -Category Firmware
            $SettingID = $SettingResource.id
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)

        }


        if (-not $SettingResource) {
            
            # Must return a message if not found

            if ($WhatIf) {

                $ErrorMessage = "Setting '{0}': Resource cannot be found in the '{1}' region!" -f $Name, $Region
                Write-warning $ErrorMessage
                return
            
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "Setting cannot be found in the region!"
            }
        }
        else {

            $Uri = (Get-COMSettingsUri) + "/" + $SettingID

            # Conditionally add properties
            if ($NewName) {
                $Name = $NewName
            }

            if (-not $PSBoundParameters.ContainsKey('Description')) {
	    
                if ($SettingResource.description) {
                              
                    $Description = $SettingResource.description
                }
                else {
                    $Description = $Null
                }
            }     
            
            # Using containsKey to allow removing an already set parameter using -Gen10FirmwareBaselineReleaseVersion ""
            if (-not $PSBoundParameters.ContainsKey('Gen10FirmwareBaselineReleaseVersion') ) {
                
                if ($SettingResource.settings.GEN10.id) {

                    $Gen10FirmwareBaselineID = $SettingResource.settings.GEN10.id
                    $Gen10FirmwareBaselineReleaseVersion = $True
                }
            }
            elseif ($PSBoundParameters.ContainsKey('Gen10FirmwareBaselineReleaseVersion')) {
                
                try {
                    $Gen10FirmwareBaselineID = (Get-HPECOMFirmwareBaseline -Region $Region -IsActive -ReleaseVersion $Gen10FirmwareBaselineReleaseVersion -Generation 10).id
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                    
                }
    
                if (-not $Gen10FirmwareBaselineID) {
    
                    # Must return a message if SN/Name not found
                    
                    $ErrorMessage = "Firmware baseline '{0}' cannot be found in the Compute Ops Management instance!" -f $Gen10FirmwareBaselineReleaseVersion
                    $ErrorRecord = New-ErrorRecord FirmwareBaselineNotFoundInCOM ObjectNotFound -TargetObject 'Firmware-baselines' -Message $ErrorMessage -TargetType $Gen10FirmwareBaselineReleaseVersion.GetType().Name
                
                    $PSCmdlet.ThrowTerminatingError($ErrorRecord)
                }
                
            }

            if (-not $PSBoundParameters.ContainsKey('Gen11FirmwareBaselineReleaseVersion') ) {
                
                if ($SettingResource.settings.GEN11.id) {

                    $Gen11FirmwareBaselineID = $SettingResource.settings.GEN11.id
                    $Gen11FirmwareBaselineReleaseVersion = $True

                }
            }
            elseif ($PSBoundParameters.ContainsKey('Gen11FirmwareBaselineReleaseVersion')) {

                try {
                    $Gen11FirmwareBaselineID = (Get-HPECOMFirmwareBaseline -Region $Region -IsActive -ReleaseVersion $Gen11FirmwareBaselineReleaseVersion -Generation 11).id
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                    
                }
    
                if (-not $Gen11FirmwareBaselineID) {
    
                    # Must return a message if SN/Name not found
                    
                    $ErrorMessage = "Firmware baseline '{0}' cannot be found in the Compute Ops Management instance!" -f $Gen11FirmwareBaselineReleaseVersion
                    $ErrorRecord = New-ErrorRecord FirmwareBaselineNotFoundInCOM ObjectNotFound -TargetObject 'Firmware-baselines' -Message $ErrorMessage -TargetType $Gen11FirmwareBaselineReleaseVersion.GetType().Name
                
                    $PSCmdlet.ThrowTerminatingError($ErrorRecord)
                }
            }


            if ($Gen10FirmwareBaselineReleaseVersion -and -not $Gen11FirmwareBaselineReleaseVersion) {

                $Settings = @{ 
                    GEN10 = @{
                        id = $Gen10FirmwareBaselineID
    
                    }
                }
            }

            elseif ($Gen10FirmwareBaselineReleaseVersion -and $Gen11FirmwareBaselineReleaseVersion) {
                
                $Settings = @{ 
                    GEN10 = @{
                        id = $Gen10FirmwareBaselineID
    
                    }
                    GEN11 = @{
                        id = $Gen11FirmwareBaselineID
    
                    }
                }
            }

            elseif ($Gen11FirmwareBaselineReleaseVersion -and -not $Gen10FirmwareBaselineReleaseVersion ) {
                
                $Settings = @{ 
                    GEN11 = @{
                        id = $Gen11FirmwareBaselineID
    
                    }
                }

            }  


            $payload = @{ 
                name           = $Name
                description    = $Description
                settings       = $Settings                  
            }

            $payload = ConvertTo-Json $payload -Depth 10 

            try {

                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method PATCH -body $payload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    


                if (-not $WhatIf ) {
    
                    "[{0}] Setting update raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

                    "[{0}] Firmware server setting '{1}' successfully updated in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
                    
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Firmware server setting successfully updated in $Region region"


                }
            }
            catch {

                if (-not $WhatIf) {

                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Firmware server setting cannot be updated!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 

                }
            } 
        }

        [void] $SetServerSettingStatus.add($objStatus)

        

    
    }
    
    End {
       

        if (-not $WhatIf ) {

            $SetServerSettingStatus = Invoke-RepackageObjectWithType -RawObject $SetServerSettingStatus -ObjectName "COM.objStatus.NSDE"
            Return $SetServerSettingStatus
        
        }

    }
}

Function New-HPECOMSettingServerExternalStorage {
    <#
    .SYNOPSIS
    Configures an external storage server setting.

    .DESCRIPTION
    This Cmdlet is used to create a new external storage server setting to utilize an external storage resource managed within Data Ops Manager.
    External storage server settings enable you to apply a consistent external storage configuration to servers in a group.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name
    Specifies the name of the external storage server setting.

    .PARAMETER Description
    Provides a description for the external storage server setting.

    .PARAMETER HostOSType
    Specifies the OS installed on the server:
        - UNKNOWN
        - AIX
        - APPLE
        - CITRIX_HYPERVISOR
        - HP_UX
        - IBM_VIO_SERVER
        - INFORM
        - NETAPP
        - OE_LINUX_UEK
        - OPENVMS
        - ORACLE_VM
        - RHE_LINUX
        - RHE_VIRTUALIZATION
        - SOLARIS
        - SUSE_LINUX
        - SUSE_VIRTUALIZATION
        - UBUNTU
        - VMWARE_ESXI
        - WINDOWS_SERVER
   
    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.
   
    .EXAMPLE
    New-HPECOMSettingServerOSImage -Region  us-west -Name OS-ESX -Description "My ESX OS image SS" -OperatingSystem VMWARE_ESXI -OSImageURL "https://domain.com/esx.iso" 

    This command creates a new OS image configuration server setting named 'OS-ESX' using a single image containing OS and unattended installation file from the URL 'https://domain.com/esx8.iso' in the 'us-west' region.

    .EXAMPLE
    New-HPECOMSettingServerOSImage -Region us-west -Name OS-ESX -Description "My ESX 8 OS image configuration" -OperatingSystem VMWARE_ESXI -OSImageURL "https://domain.com/esx8.iso" -UnattendedInstallationFileImageUrl "https://domain.com/esx_ks.iso" 
    
    This command creates a new OS image configuration server setting named 'OS-ESX' using a separate image for OS from the URL 'https://domain.com/esx8.iso' and for the unattended file from the URL 'https://domain.com/esx_ks.iso'.

    .INPUTS
    Pipeline input is not supported.
    
    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:
        * Name - The name of the external storage server setting attempted to be created
        * Region - The name of the region
        * Status - Status of the creation attempt (Failed for HTTP error return; Complete if creation is successful; Warning if no action is needed)
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.
    
   #>
    [CmdletBinding(DefaultParameterSetName = 'Together')]
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
        
        [ValidateScript({ $_.Length -le 1000 })]
        [String]$Description,    
        
        [Parameter (Mandatory)]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @("UNKNOWN", "AIX", "APPLE", "CITRIX_HYPERVISOR", "HP_UX", "IBM_VIO_SERVER", "INFORM", "NETAPP", "OE_LINUX_UEK", "OPENVMS", "ORACLE_VM", "RHE_LINUX", "RHE_VIRTUALIZATION", "SOLARIS", "SUSE_LINUX", "SUSE_VIRTUALIZATION", "UBUNTU", "VMWARE_ESXI", "WINDOWS_SERVER"
                )
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet("UNKNOWN", "AIX", "APPLE", "CITRIX_HYPERVISOR", "HP_UX", "IBM_VIO_SERVER", "INFORM", "NETAPP", "OE_LINUX_UEK", "OPENVMS", "ORACLE_VM", "RHE_LINUX", "RHE_VIRTUALIZATION", "SOLARIS", "SUSE_LINUX", "SUSE_VIRTUALIZATION", "UBUNTU", "VMWARE_ESXI", "WINDOWS_SERVER")]
        [String]$HostOSType,

        
        [Switch]$WhatIf
       
    ) 
    Begin {
        
        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-COMSettingsUri
        $NewServerSettingFirmwareStatus = [System.Collections.ArrayList]::new()
        
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
            $SettingResource = Get-HPECOMSetting -Region $Region -Name $Name -Category ExternalStorage

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)

        }

        if ($SettingResource) {

            "[{0}] Setting '{1}' is already present in the '{2}' region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
    
            if ($WhatIf) {
                $ErrorMessage = "Setting '{0}': Resource is already present in the '{1}' region! No action needed." -f $Name, $Region
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "Setting already exists in the region! No action needed."
            }

        }
        else {

            # Build payload
            $Settings = @{ 
                DEFAULT = @{
                    externalStorageHostOs = $HostOSType
    
                }
            }
    
            $payload = @{ 
                name           = $Name
                category       = "EXTERNAL_STORAGE"
                description    = $Description
                settings       = $Settings                  
            }
    
            $payload = ConvertTo-Json $payload -Depth 10 
    
            try {
    
                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
    
                if (-not $WhatIf ) {
        
                    "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
    
                    "[{0}] Firmware server setting '{1}' successfully created in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
                        
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Firmware server setting successfully created in $Region region"
    
    
                }
            }
            catch {
    
                if (-not $WhatIf) {
    
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Firmware server setting cannot be created!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
    
                }
            } 
        }
        

        [void] $NewServerSettingFirmwareStatus.add($objStatus)

    
    }
    
    End {
       

        if (-not $WhatIf ) {

            $NewServerSettingFirmwareStatus = Invoke-RepackageObjectWithType -RawObject $NewServerSettingFirmwareStatus -ObjectName "COM.objStatus.NSDE"
            Return $NewServerSettingFirmwareStatus
        
        }

    }
}
Function Set-HPECOMSettingServerExternalStorage {
    <#
    .SYNOPSIS
    Updates the configuration of an external storage server setting resource in a specified region.

    .DESCRIPTION
    This Cmdlet modifies an external storage server setting resource within a designated Compute Ops Management (COM) region. If certain parameters are not specified, the cmdlet retains their existing settings and only updates those that are provided.

    .PARAMETER Name
    Specifies the name of the external storage server setting to update.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER NewName 
    Specifies the new name for the external storage server setting.

    .PARAMETER Description
    Provides a new description for the external storage server setting.

    .PARAMETER HostOSType
    Specifies the OS installed on the server. 

    "UNKNOWN" "AIX" "APPLE" "CITRIX_HYPERVISOR" "HP_UX" "IBM_VIO_SERVER" "INFORM" "NETAPP" "OE_LINUX_UEK" "OPENVMS" "ORACLE_VM" "RHE_LINUX" "RHE_VIRTUALIZATION" "SOLARIS" "SUSE_LINUX" "SUSE_VIRTUALIZATION" "UBUNTU" "VMWARE_ESXI" "WINDOWS_SERVER"
        
    .PARAMETER WhatIf 
    Displays the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the native REST API calls utilized by COM.

    .EXAMPLE
    Set-HPECOMSettingServerExternalStorage -Region eu-central -Name AI -NewName AI-External-Storage

    This example updates the name of the external storage server setting from 'AI' to 'AI-External-Storage' in the 'eu-central' region.

    .EXAMPLE
    Set-HPECOMSettingServerExternalStorage -Region eu-central -Name AI-External-Storage -Description "External storage for AI hosts" -HostOSType RHE_LINUX    

    This example updates the description to 'External storage for AI hosts' and sets the host OS type to 'RHE_LINUX' for the external storage server setting named 'AI-External-Storage' in the 'eu-central' region.

    .EXAMPLE
    Get-HPECOMSetting -Region eu-central -Name AI -Category ExternalStorage | Set-HPECOMSettingServerExternalStorage -Description "External storage for VMware hosts" -NewName "WMWARE-External-Storage"

    This example uses pipeline input to update the description to 'External storage for VMware hosts' and the name to 'WMWARE-External-Storage' for the external storage server setting named 'AI' retrieved from the 'eu-central' region.

    .INPUTS
    System.Collections.ArrayList
        List of external storage settings from 'Get-HPECOMSetting -Category ExternalStorage'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following keys:
        * Name - The name of the external storage server setting attempted to be updated.
        * Region - The name of the region.
        * Status - Status of the modification attempt (Failed for HTTP error return; Complete if creation is successful; Warning if no action is needed).
        * Details - Additional information about the status.
        * Exception - Information regarding any exceptions generated during the operation.
    #>

    [CmdletBinding(DefaultParameterSetName = 'EntireDisk')]
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
        [String]$Name,  

        [ValidateScript({ $_.Length -le 100 })]
        [String]$NewName,
        
        [ValidateScript({ $_.Length -le 1000 })]
        [String]$Description,    
        
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @("UNKNOWN", "AIX", "APPLE", "CITRIX_HYPERVISOR", "HP_UX", "IBM_VIO_SERVER", "INFORM", "NETAPP", "OE_LINUX_UEK", "OPENVMS", "ORACLE_VM", "RHE_LINUX", "RHE_VIRTUALIZATION", "SOLARIS", "SUSE_LINUX", "SUSE_VIRTUALIZATION", "UBUNTU", "VMWARE_ESXI", "WINDOWS_SERVER"
                )
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet("UNKNOWN", "AIX", "APPLE", "CITRIX_HYPERVISOR", "HP_UX", "IBM_VIO_SERVER", "INFORM", "NETAPP", "OE_LINUX_UEK", "OPENVMS", "ORACLE_VM", "RHE_LINUX", "RHE_VIRTUALIZATION", "SOLARIS", "SUSE_LINUX", "SUSE_VIRTUALIZATION", "UBUNTU", "VMWARE_ESXI", "WINDOWS_SERVER")]
        [String]$HostOSType,

        [Switch]$WhatIf
       
    ) 
    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-COMSettingsUri
        $SetServerSettingStatus = [System.Collections.ArrayList]::new()
        
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
            $SettingResource = Get-HPECOMSetting -Region $Region -Name $Name -Category ExternalStorage
            $SettingID = $SettingResource.id
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)

        }


        if (-not $SettingResource) {
            
            # Must return a message if not found

            if ($WhatIf) {

                $ErrorMessage = "Setting '{0}': Resource cannot be found in the '{1}' region!" -f $Name, $Region
                Write-warning $ErrorMessage
                return
            
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "Setting cannot be found in the region!"
            }
        }
        else {

            $Uri = (Get-COMSettingsUri) + "/" + $SettingID

            # Conditionally add properties
            if ($NewName) {
                $Name = $NewName
            }

            if (-not $PSBoundParameters.ContainsKey('Description')) {
	    
                if ($SettingResource.description) {
                              
                    $Description = $SettingResource.description
                }
                else {
                    $Description = $Null
                }
            }     
            
            if (-not $PSBoundParameters.ContainsKey('HostOSType') ) {
                
                if ($SettingResource.settings.default.externalStorageHostOs) {

                    $HostOSType = $SettingResource.settings.default.externalStorageHostOs
                }
            }
         

            # Build payload
            $Settings = @{ 
                DEFAULT = @{
                    externalStorageHostOs = $HostOSType
                }
            }

            $payload = @{ 
                name           = $Name
                description    = $Description
                settings       = $Settings                  
            }

            $payload = ConvertTo-Json $payload -Depth 10 

            try {

                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method PATCH -body $payload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    


                if (-not $WhatIf ) {
    
                    "[{0}] Setting update raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

                    "[{0}] External storage server setting '{1}' successfully updated in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
                    
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "External storage server setting successfully updated in $Region region"


                }
            }
            catch {

                if (-not $WhatIf) {

                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "External storage server setting cannot be updated!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 

                }
            } 
        }

        [void] $SetServerSettingStatus.add($objStatus)

        

    
    }
    
    End {
       

        if (-not $WhatIf ) {

            $SetServerSettingStatus = Invoke-RepackageObjectWithType -RawObject $SetServerSettingStatus -ObjectName "COM.objStatus.NSDE"
            Return $SetServerSettingStatus
        
        }

    }
}

Function New-HPECOMSettingiLOSettings {
<#
.SYNOPSIS
Create an iLO settings server setting resource in a specified region.

.DESCRIPTION
This Cmdlet is used to create a new iLO settings server setting resource in a specified Compute Ops Management region. 
iLO settings server settings enable you to apply a consistent iLO configuration to servers in a group.
It supports configuring various iLO settings such as network protocols, SNMP, account, security and update services.

All parameters can be used together. If you specify SNMPv3 user or SNMP alert destination parameters, all required related parameters must also be provided, otherwise the function will throw a clear error.

.PARAMETER Region
Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

.PARAMETER Name
Specifies the name of the iLO settings configuration to create. Mandatory.

.PARAMETER Description
Provides a description for the iLO settings configuration.

.PARAMETER AccountServiceAuthenticationFailureBeforeDelay
Specifies the number of authentication failures before delay (EveryFailureCausesDelay, 1FailureCausesNoDelay, 3FailuresCauseNoDelay, 5FailuresCausesNoDelay).

.PARAMETER AccountServiceAuthenticationFailureDelayTimeInSeconds
Specifies the delay time in seconds after authentication failures (2, 5, 10, 30).

.PARAMETER AccountServiceAuthenticationFailureLogging
Specifies the logging threshold for authentication failures (Enabled - every failure, every 2nd, 3rd, 5th failure, Disabled).

.PARAMETER AccountServicePasswordMinimumLength
Specifies the minimum password length (0-39).

.PARAMETER AccountServicePasswordComplexity
Enforces password complexity (Enabled, Disabled).

.PARAMETER PasswordComplexity
Specifies password complexity for network (Enabled, Disabled).

.PARAMETER AnonymousData
Controls anonymous data access (Enabled, Disabled).

.PARAMETER IPMIDCMIOverLAN
Enables or disables IPMI/DCMI over LAN (Enabled, Disabled). Default: Disabled

.PARAMETER IPMIDCMIOverLANPort
Specifies the port for IPMI/DCMI over LAN. Default: 623

.PARAMETER RemoteConsole
Enables or disables remote console (Enabled, Disabled). Default: Enabled

.PARAMETER RemoteConsolePort
Specifies the port for remote console. Default: 17990

.PARAMETER SSH
Enables or disables SSH (Enabled, Disabled). Default: Enabled

.PARAMETER SSHPort
Specifies the SSH port. Default: 22

.PARAMETER SNMP
Enables or disables SNMP (Enabled, Disabled). Default: Enabled

.PARAMETER SNMPPort
Specifies the SNMP port. Default: 161

.PARAMETER SNMPTrapPort
Specifies the SNMP trap port. Default: 162

.PARAMETER VirtualMedia
Enables or disables virtual media (Enabled, Disabled). Default: Enabled

.PARAMETER VirtualMediaPort
Specifies the virtual media port. Default: 17988

.PARAMETER VirtualSerialPortLogOverCLI
Enables or disables virtual serial port log over CLI (Enabled, Disabled).

.PARAMETER WebServerSSL
Enables or disables web server SSL (Enabled, Disabled). Default: Enabled

.PARAMETER WebServerSSLPort
Specifies the web server SSL port. Default: 443

.PARAMETER DownloadableVirtualSerialPortLog
Enables or disables downloadable virtual serial port log (Enabled, Disabled).

.PARAMETER IdleConnectionTimeoutinMinutes
Specifies idle connection timeout in minutes (Disabled, 15, 30, 60, 120).

.PARAMETER iLORIBCLInterface
Enables or disables iLO RIBCL interface (Enabled, Disabled).

.PARAMETER iLOROMSetupUtility
Enables or disables iLO ROM setup utility (Enabled, Disabled).

.PARAMETER iLOWebInterface
Enables or disables iLO web interface (Enabled, Disabled).

.PARAMETER iLORemoteConsoleThumbnail
Enables or disables remote console thumbnail (Enabled, Disabled).

.PARAMETER iLOHostAuthRequired
Requires host authentication (Enabled, Disabled).

.PARAMETER iLORBSULoginRequired
Requires login for iLO RBSU (Enabled, Disabled).

.PARAMETER SerialCommandLineInterfaceSpeed
Specifies serial CLI speed (115200, 57600, 38400, 19200, 9600). Default: 9600

.PARAMETER SerialCommandLineInterfaceStatus
Specifies serial CLI status (Enabled - authentication required, Enabled - no authentication required, Disabled).

.PARAMETER ShowiLOIPDuringPOST
Shows iLO IP during POST (Enabled, Disabled).

.PARAMETER ShowServerHealthOnExternalMonitor
Shows server health on external monitor (Enabled, Disabled).

.PARAMETER VGAPortDetectOverride
Controls VGA port detect override (Enabled, Disabled).

.PARAMETER VirtualNICEnabled
Enables or disables virtual NIC (Enabled, Disabled).

.PARAMETER AcceptThirdPartyFirmwareUpdates
Accepts third-party firmware updates (Enabled, Disabled).

.PARAMETER TrapSourceIdentifier
Specifies trap source identifier (OS hostname, iLO hostname).

.PARAMETER SNMPv1Request
Enables SNMPv1 request (Enabled, Disabled).

.PARAMETER SNMPv1Trap
Enables SNMPv1 trap (Enabled, Disabled).

.PARAMETER SNMPv3Request
Enables SNMPv3 request (Enabled, Disabled).

.PARAMETER SNMPv3Trap
Enables SNMPv3 trap (Enabled, Disabled).

.PARAMETER ColdStartTrap
Enables cold start trap (Enabled, Disabled).

.PARAMETER PeriodicHSATrapConfiguration
Configures periodic HSA trap (Daily, Weekly, Monthly, Disabled).

.PARAMETER SNMPSettingsSystemLocation
Specifies SNMP system location (up to 49 chars).

.PARAMETER SNMPSettingsSystemContact
Specifies SNMP system contact (up to 49 chars).

.PARAMETER SNMPSettingsSystemRole
Specifies SNMP system role (up to 64 chars).

.PARAMETER SNMPSettingsSystemRoleDetails
Specifies SNMP system role details (up to 512 chars).

.PARAMETER SNMPSettingsReadCommunity1
Specifies SNMP read community 1 (up to 64 chars).

.PARAMETER SNMPSettingsReadCommunity2
Specifies SNMP read community 2 (up to 64 chars).

.PARAMETER SNMPSettingsReadCommunity3
Specifies SNMP read community 3 (up to 64 chars).

.PARAMETER SNMPv3EngineID
Specifies SNMPv3 engine ID (hex string, 6-48 chars after 0x, even length).

.PARAMETER SNMPv3InformRetry
Specifies SNMPv3 inform retry count (0-5). Default: 2

.PARAMETER SNMPv3InformRetryInterval
Specifies SNMPv3 inform retry interval in seconds (1-120). Default: 15

.PARAMETER SNMPv3User1UserName
Specifies SNMPv3 user 1 name (1-32 chars). If provided, must also provide SNMPv3User1AuthenticationPassphrase and SNMPv3User1PrivacyPassphrase.

.PARAMETER SNMPv3User1AuthenticationProtocol
Specifies SNMPv3 user 1 authentication protocol (MD5, SHA, SHA256).

.PARAMETER SNMPv3User1AuthenticationPassphrase
Specifies SNMPv3 user 1 authentication passphrase (SecureString).

.PARAMETER SNMPv3User1PrivacyPassphrase
Specifies SNMPv3 user 1 privacy passphrase (SecureString).

.PARAMETER SNMPv3User1EngineID
Specifies SNMPv3 user 1 engine ID (hex string, 10-64 chars after 0x, even length).

.PARAMETER SNMPv3User2UserName
Specifies SNMPv3 user 2 name (1-32 chars).

.PARAMETER SNMPv3User2AuthenticationProtocol
Specifies SNMPv3 user 2 authentication protocol (MD5, SHA, SHA256).

.PARAMETER SNMPv3User2AuthenticationPassphrase
Specifies SNMPv3 user 2 authentication passphrase (SecureString).

.PARAMETER SNMPv3User2PrivacyPassphrase
Specifies SNMPv3 user 2 privacy passphrase (SecureString).

.PARAMETER SNMPv3User2EngineID
Specifies SNMPv3 user 2 engine ID (hex string, 10-64 chars after 0x, even length).

.PARAMETER SNMPAlertDestination1
Specifies SNMP alert destination 1 (up to 255 chars). If provided, must also provide SNMPTrapCommunityForDestination1 and SNMPProtocolForDestination1.

.PARAMETER SNMPTrapCommunityForDestination1
Specifies SNMP trap community for destination 1 (up to 64 chars).

.PARAMETER SNMPProtocolForDestination1
Specifies SNMP protocol for destination 1 (SNMPv1 Trap, SNMPv3 Trap, SNMPv3 Inform).

.PARAMETER SNMPv3UserForDestination1
Specifies the SNMPv3 user name to associate with SNMP alert destination 1. This parameter is required only when -SNMPProtocolForDestination1 is set to 'SNMPv3 Trap' or 'SNMPv3 Inform'.

.PARAMETER SNMPAlertDestination2
Specifies SNMP alert destination 2 (up to 255 chars).

.PARAMETER SNMPTrapCommunityForDestination2
Specifies SNMP trap community for destination 2 (up to 64 chars).

.PARAMETER SNMPProtocolForDestination2
Specifies SNMP protocol for destination 2 (SNMPv1 Trap, SNMPv3 Trap, SNMPv3 Inform).

.PARAMETER SNMPv3UserForDestination2
Specifies the SNMPv3 user name to associate with SNMP alert destination 2. This parameter is required only when -SNMPProtocolForDestination2 is set to 'SNMPv3 Trap' or 'SNMPv3 Inform'.

.PARAMETER SNMPAlertDestination3
Specifies SNMP alert destination 3 (up to 255 chars).

.PARAMETER SNMPTrapCommunityForDestination3
Specifies SNMP trap community for destination 3 (up to 64 chars).

.PARAMETER SNMPProtocolForDestination3
Specifies SNMP protocol for destination 3 (SNMPv1 Trap, SNMPv3 Trap, SNMPv3 Inform).

.PARAMETER SNMPv3UserForDestination3
Specifies the SNMPv3 user name to associate with SNMP alert destination 3. This parameter is required only when -SNMPProtocolForDestination3 is set to 'SNMPv3 Trap' or 'SNMPv3 Inform'.

.PARAMETER GlobalComponentIntegrityCheck
Enables or disables global component integrity check (Enabled, Disabled).

.PARAMETER GlobalComponentIntegrityPolicy
Specifies global integrity policy (No policy, Halt boot on SPDM failure).

.PARAMETER WhatIf
Shows the raw REST API call that would be made to COM instead of sending the request.

.EXAMPLE
New-HPECOMSettingiLOSettings -Region eu-central -Name "ILO_config_for_Gen12" -Description "iLO Settings for Gen12 servers" `
 -AccountServiceAuthenticationFailureBeforeDelay 3FailuresCauseNoDelay `
 -AccountServiceAuthenticationFailureDelayTimeInSeconds 30 `
 -AccountServiceAuthenticationFailureLogging Disabled

This example creates an iLO settings configuration named "ILO_config_for_Gen12" in the "eu-central" region.
It sets a description and customizes authentication failure handling:
- Delays are triggered after three failures.
- Delay time is set to 30 seconds.
- Authentication failure logging is disabled.

.EXAMPLE 
$SNMPv3User1authPass = ConvertTo-SecureString 'YourPasswordHere' -AsPlainText -Force
$SNMPv3User1privPass = ConvertTo-SecureString 'YourPrivacyPassHere' -AsPlainText -Force
$SNMPv3User2authPass = ConvertTo-SecureString 'YourPasswordHere' -AsPlainText -Force
$SNMPv3User2privPass = ConvertTo-SecureString 'YourPrivacyPassHere' -AsPlainText -Force

These commands create SecureString objects for SNMPv3 user authentication and privacy passphrases.
Use these variables as parameter values for -SNMPv3User1AuthenticationPassphrase, -SNMPv3User1PrivacyPassphrase, etc.

New-HPECOMSettingiLOSettings -Region eu-central -Name "ILO_config_for_Gen12" -Description "iLO Settings for Gen12 servers" `
 -AccountServiceAuthenticationFailureBeforeDelay 1FailureCausesNoDelay -AccountServiceAuthenticationFailureDelayTimeInSeconds 10 -AccountServiceAuthenticationFailureLogging Disabled `
 -AccountServicePasswordMinimumLength 13 -AccountServicePasswordComplexity Enabled -PasswordComplexity Enabled -AnonymousData Enabled -IPMIDCMIOverLAN Disabled -IPMIDCMIOverLANPort 342 -RemoteConsole Enabled `
 -RemoteConsolePort 339 -SSH Enabled -SSHPort 23 -SNMP Enabled -SNMPPort 162 -SNMPTrapPort 163  -VirtualMedia Enabled -VirtualMediaPort 350 -VirtualSerialPortLogOverCLI Enabled -WebServerSSL Enabled -WebServerSSLPort 443 `
 -DownloadableVirtualSerialPortLog Enabled -IdleConnectionTimeoutinMinutes 15 -iLORIBCLInterface Enabled -iLOROMSetupUtility Enabled -iLOWebInterface Enabled `
 -iLORemoteConsoleThumbnail Enabled -iLOHostAuthRequired Enabled -iLORBSULoginRequired Enabled -SerialCommandLineInterfaceSpeed 19200 -SerialCommandLineInterfaceStatus 'Enabled - no authentication required' -ShowiLOIPDuringPOST Enabled `
 -ShowServerHealthOnExternalMonitor Enabled -VGAPortDetectOverride Disabled -VirtualNICEnabled Enabled -AcceptThirdPartyFirmwareUpdates Disabled -TrapSourceIdentifier 'OS hostname' -SNMPv1Request Enabled -SNMPv1Trap Disabled `
 -SNMPv3Request Enabled -SNMPv3Trap Enabled -ColdStartTrap Disabled -PeriodicHSATrapConfiguration Monthly -SNMPSettingsSystemLocation 'My Location' -SNMPSettingsSystemContact 'Chris' -SNMPSettingsSystemRole 'Administrator' `
 -SNMPSettingsSystemRoleDetails "Admin role" -SNMPSettingsReadCommunity1 'ReadCommunity1' -SNMPSettingsReadCommunity2 'ReadCommunity2' -SNMPSettingsReadCommunity3 'ReadCommunity3' -SNMPv3EngineID '0x01020304abcdef' `
 -SNMPv3InformRetry 2 -SNMPv3InformRetryInterval 15 -SNMPv3User1UserName 'Chris' -SNMPv3User1AuthenticationProtocol 'MD5' -SNMPv3User1AuthenticationPassphrase  $SNMPv3User1authPass -SNMPv3User1PrivacyPassphrase $SNMPv3User1privPass `
 -SNMPv3User1EngineID '0x01020304abcdef' -SNMPv3User2UserName 'John' -SNMPv3User2AuthenticationProtocol 'SHA256' -SNMPv3User2AuthenticationPassphrase $SNMPv3User2authPass `
 -SNMPv3User2PrivacyPassphrase $SNMPv3User2privPass -SNMPv3User2EngineID '0x01020304abcdef' -GlobalComponentIntegrityCheck Disabled -GlobalComponentIntegrityPolicy 'Halt boot on SPDM failure' 

This example creates an iLO settings configuration named "ILO_config_for_Gen12" in the "eu-central" region.
It sets a name and a description, and customizes various iLO settings including account service, network protocols, SNMP settings, and security service. 
It demonstrates the use of multiple parameters to create a new comprehensive iLO settings profile.

.INPUTS
None. Pipeline input is not supported.

.OUTPUTS
System.Collections.ArrayList
A custom status object or array of objects containing:
    * Name      - The name of the iLO settings configuration
    * Region    - The region name
    * Status    - Status of the creation attempt (Failed, Complete, or Warning)
    * Details   - More information about the status
    * Exception - Any exception information

.NOTES
If you specify SNMPv3 user or SNMP alert destination parameters, all required related parameters must also be provided.
#>

    [CmdletBinding()]
    Param( 
    [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Default')]
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

    [Parameter (Mandatory, ParameterSetName = 'Default')]
        [ValidateScript({ $_.Length -le 100 })]
    [String]$Name,  
        
    [ValidateScript({ $_.Length -le 1000 })]
    [Parameter(ParameterSetName = 'Default')]
    [String]$Description,    
        
        # ACCOUNT SERVICE
    [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('EveryFailureCausesDelay', '1FailureCausesNoDelay', '3FailuresCauseNoDelay', '5FailuresCausesNoDelay')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('EveryFailureCausesDelay', '1FailureCausesNoDelay', '3FailuresCauseNoDelay', '5FailuresCausesNoDelay')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$AccountServiceAuthenticationFailureBeforeDelay,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('2', '5', '10', '30')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('2', '5', '10', '30')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$AccountServiceAuthenticationFailureDelayTimeInSeconds,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled - every failure', 'Enabled - every 2nd failure', 'Enabled - every 3rd failure', 'Enabled - every 5th failure', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled - every failure', 'Enabled - every 2nd failure', 'Enabled - every 3rd failure', 'Enabled - every 5th failure', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$AccountServiceAuthenticationFailureLogging,

    [ValidateScript({ $_ -ge 0 -and $_ -le 39 })]
    [Parameter(ParameterSetName = 'Default')]
    [Int]$AccountServicePasswordMinimumLength,  

        # The password complexity setting specifies the complexity requirements for user account passwords.
        # When enabled, new or updated user account passwords must include three of the following characteristics:
        # At least one uppercase ASCII character
        # At least one lowercase ASCII character
        # At least one ASCII digit
        # At least one other type of character (for example, a symbol, special character, or punctuation)
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$AccountServicePasswordComplexity,

        # NETWORK
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$PasswordComplexity,

        # NETWORK
        # Anonymous data—This setting controls the following:
        # - The XML object iLO provides in response to an anonymous request for basic system information.
        # - The information provided in response to an anonymous Redfish call to /redfish/v1.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$AnonymousData,

        # IPMI/DCMI over LAN—Allows you to send industry-standard IPMI and DCMI commands over the LAN to a specified port.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$IPMIDCMIOverLAN = "Disabled",
                
    [Parameter(ParameterSetName = 'Default')]
    [String]$IPMIDCMIOverLANPort = "623",

        # Remote console — Allows you to enable or disable access through the iLO remote console.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$RemoteConsole = "Enabled",

    [Parameter(ParameterSetName = 'Default')]
    [String]$RemoteConsolePort = "17990",


        # Secure shell (SSH)—Allows you to enable or disable the SSH feature.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SSH = "Enabled",

    [Parameter(ParameterSetName = 'Default')]
    [String]$SSHPort = "22",

        # SNMP—Specifies whether iLO responds to external SNMP requests.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMP = "Enabled",

    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPPort = "161",

    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPTrapPort = "162",

        # Virtual media—Allows you to enable or disable the iLO virtual media feature.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$VirtualMedia = "Enabled",

    [Parameter(ParameterSetName = 'Default')]
    [String]$VirtualMediaPort = "17988",

        # Virtual serial port log over CLI—Enables or disables logging of the virtual serial port that you can view by using the CLI.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$VirtualSerialPortLogOverCLI,

        # Web server (iLO 5 and iLO 6)—Allows you to enable or disable access through the iLO web server.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$WebServerSSL = "Enabled",

    [Parameter(ParameterSetName = 'Default')]
    [String]$WebServerSSLPort = "443",

    # REMOVED AS IT ALSO DISABLES HTTPS SO WEB GUI ACCESS IS LOST
    ##########################################################################################
    #     # Web server non-SSL port enabled (iLO 5 and iLO 6)—Enables or disables the HTTP port.
    #     [ArgumentCompleter({
    #             param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    #             $Values = @('Enabled', 'Disabled')
    #             $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
    #             return $FilteredValues | ForEach-Object {
    #                 [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    #             }
    #         })] 
    # [ValidateSet ('Enabled', 'Disabled')]
    # [Parameter(ParameterSetName = 'Default')]
    # [String]$WebServerNonSSL = "Enabled",
        
    # [Parameter(ParameterSetName = 'Default')]
    # [String]$WebServerNonSSLPort = "80",

        # ILO
        # Downloadable virtual serial port log—Enables or disables logging of the virtual serial port to a file that you can download through the iLO web interface.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$DownloadableVirtualSerialPortLog,

        # Idle connection timeout—Specifies how long iLO sessions can be inactive before they end automatically.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Disabled', '15', '30', '60', '120')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Disabled', '15', '30', '60', '120')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$IdleConnectionTimeoutinMinutes,

        # iLO RIBCL interface (iLO 5 and iLO 6)—Specifies whether RIBCL commands can be used to communicate with iLO.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$iLORIBCLInterface,

        # iLO ROM setup utility—Enables or disables the iLO configuration options in the UEFI System Utilities.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$iLOROMSetupUtility,

        # iLO web interface—Specifies whether the iLO web interface can be used to communicate with iLO.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$iLOWebInterface,

        # Remote console thumbnail—Enables or disables the display of the remote console thumbnail image in iLO.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$iLORemoteConsoleThumbnail,

        # Requires host authentication (iLO 5 and iLO 6)—Determines whether iLO user credentials are required to use host-based configuration utilities that access the management processor. 
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$iLOHostAuthRequired,

        # Require login for iLO RBSU (iLO 5 and iLO 6)—Determines whether user credentials are required when a user accesses the iLO configuration options in the UEFI System Utilities.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$iLORBSULoginRequired,

        # Serial command line interface speed (iLO 5 and iLO 6)—Enables you to change the speed of the serial port for the CLI feature.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('115200', '57600', '38400', '19200', '9600')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('115200', '57600', '38400', '19200', '9600')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SerialCommandLineInterfaceSpeed = "9600",


        # Serial command line interface status (iLO 5 and iLO 6)—Enables you to change the login model of the CLI feature through the serial port.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled - authentication required', 'Enabled - no authentication required', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled - authentication required', 'Enabled - no authentication required', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SerialCommandLineInterfaceStatus,

        # Show iLO IP during POST—Enables the display of the iLO network IP address during host server POST.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$ShowiLOIPDuringPOST,

        # Show server health on external monitor—Enables the display of the Server Health Summary screen on an external monitor.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$ShowServerHealthOnExternalMonitor,

        # VGA port detect override (iLO 5)—Controls how devices connected to the system video port are detected. Dynamic detection protects the system from abnormal port voltages.
        # This setting is not supported on Synergy compute modules.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$VGAPortDetectOverride,
        
        # Virtual NIC enabled—Determines whether you can use a virtual NIC over the USB subsystem to access iLOiLO from the host operating system.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$VirtualNICEnabled,

        # UPDATE SERVICE
        # Accept 3rd party firmware update packages—Specifies whether iLO will accept third-party firmware update packages that are not digitally signed. Platform Level Data Model (PLDM) firmware packages are supported.
    [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$AcceptThirdPartyFirmwareUpdates,

        # SNMP SERVICE
        # Trap source identifier—Determines the host name that is used in the SNMP-defined sysName variable when iLO generates SNMP traps.
        # The OS hostname is an OS construct. It does not remain persistent with the server when hard drives are moved to a new server platform. The iLO hostname, however, remains persistent with the system board.
    [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('OS hostname', 'iLO hostname')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('OS hostname', 'iLO hostname')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$TrapSourceIdentifier,

        # SNMPv1 request—Enables iLO to receive external SNMPv1 requests.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPv1Request,

        # SNMPv1 trap—Enables iLO to send SNMPv1 traps to the remote management systems configured in the alert destination.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPv1Trap,

        # SNMPv3 request—Enables iLO to receive external SNMPv3 requests.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPv3Request,

        # SNMPv3 trap—Enables iLO to send SNMPv3 traps to the remote management systems configured in the alert destination.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPv3Trap,

        # Cold start trap broadcast—The Cold Start Trap is broadcast to a subnet broadcast address when any of the following conditions is met:
        #    - SNMP Alert Destinations are not configured.
        #    - SNMP Alert Destinations are configured, but the SNMP protocol is disabled.
        #    - iLO failed to resolve all the SNMP Alert Destinations to IP addresses.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$ColdStartTrap,

        # Periodic HSA trap configuration—In the default configuration, iLO sends the health status array (HSA) trap only when a component status changes (for example, the fan status changed to failed).
        # Supported values: Daily, Weekly, Monthly, Disabled.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Daily', 'Weekly', 'Monthly', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Daily', 'Weekly', 'Monthly', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$PeriodicHSATrapConfiguration,

        # System location—A string of up to 49 characters that specifies the physical location of the server.
    [ValidateScript({ $_.Length -le 49 })]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPSettingsSystemLocation,

        # System contact—A string of up to 49 characters that specifies the system administrator or server owner. The string can include a name, email address, or phone number.
    [ValidateScript({ $_.Length -le 49 })]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPSettingsSystemContact,

        # System role—A string of up to 64 characters that describes the server role or function.
    [ValidateScript({ $_.Length -le 64 })]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPSettingsSystemRole,

        # System role details—A string of up to 512 characters that describes specific tasks that the server might perform.
    [ValidateScript({ $_.Length -le 512 })]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPSettingsSystemRoleDetails,

        # Read community 1, Read community 2, and Read Community 3—The configured SNMP read-only community strings.
        # The following formats are supported:
        #     A community string (for example, public).
        #     A community string followed by an IP address or FQDN (for example, public 192.168.0.1).
        #     Use this option to specify that SNMP access will be allowed from the specified IP address or FQDN.
        #     You can enter an IPv4 address, an IPv6 address, or an FQDN.
    [ValidateScript({ $_.Length -le 64 })]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPSettingsReadCommunity1,    
 
    [ValidateScript({ $_.Length -le 64 })]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPSettingsReadCommunity2,    
 
    [ValidateScript({ $_.Length -le 64 })]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPSettingsReadCommunity3,

        # SNMPv3 SETTINGS
        # Engine ID—The unique identifier of an SNMP engine belonging to an SNMP agent entity.
        # This value must be a hexadecimal string of 6 to 48 characters, not counting the preceding 0x, 
        # and must be an even number of characters (for example, 0x01020304abcdef). 
        # If you do not configure this setting, the value is system-generated.
    [ValidatePattern('^0x[0-9A-Fa-f]{6,48}$')]
    [Parameter(ParameterSetName = 'Default')]
    [ValidateScript({
                $hexPart = $_.Substring(2)  # Remove '0x' prefix
                if ($hexPart.Length % 2 -ne 0) {
                    throw "Engine ID must have an even number of hex characters after '0x'"
                }
                return $true
            })]
        [String]$SNMPv3EngineID,

        # Inform retry—The number of times iLO will resend an alert if the receiver does not send an acknowledgment to iLO.
        # Supported values are 0 to 5.
        [ValidateScript({ $_ -ge 0 -and $_ -le 5 })]
    [Parameter(ParameterSetName = 'Default')]
    [Int]$SNMPv3InformRetry = 2,

        # Inform retry interval—The number of seconds between attempts to resend an SNMPv3 Inform alert.
        # Supported values are 1 to 120.
        [ValidateScript({ $_ -ge 1 -and $_ -le 120 })]
    [Parameter(ParameterSetName = 'Default')]
    [Int]$SNMPv3InformRetryInterval = 15,


        # SNMPv3 USERS
        
        # User 1

        # Security name—The user profile name. Enter an alphanumeric string of 1 to 32 characters.
        [ValidateScript({ $_.Length -ge 1 -and $_.Length -le 32 })]
    # [Parameter(ParameterSetName = 'SNMPv3User1')]
        [String]$SNMPv3User1UserName,        

        # Authentication protocol—Sets the message digest algorithm to use for encoding the authorization passphrase. The message digest is calculated over an appropriate portion of an SNMP message, and is included as part of the message sent to the recipient.
        # Supported values: MD5, SHA, SHA256.
        # If iLO is configured to use the FIPS or CNSA security state, MD5 is not supported.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('MD5', 'SHA', 'SHA256')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('MD5', 'SHA', 'SHA256')]
        [String]$SNMPv3User1AuthenticationProtocol = 'SHA256',

        # Authentication passphrase—Sets the passphrase to use for sign operations.
        [ValidateNotNull()]
        [System.Security.SecureString]$SNMPv3User1AuthenticationPassphrase,

        # Privacy passphrase—Sets the passphrase used for encrypt operations.
        [ValidateNotNull()]
        [System.Security.SecureString]$SNMPv3User1PrivacyPassphrase,

        # User engine ID—Sets the user engine ID for SNMPv3 Inform packets. This value is used only for creating remote accounts used with INFORM messages.
        # If this value is not set, INFORM messages are sent with the default value or the configured SNMPv3 Engine ID.
        # This value must be a hexadecimal string with an even number of 10 to 64 characters, excluding the first two characters, 0x.
        # For example: 0x01020304abcdef
        [ValidatePattern('^0x[0-9A-Fa-f]{10,64}$')]
        [ValidateScript({
                $hexPart = $_.Substring(2)  # Remove '0x' prefix
                if ($hexPart.Length % 2 -ne 0) {
                    throw "User Engine ID must have an even number of hex characters after '0x'"
                }
                return $true
            })]
    # [Parameter(ParameterSetName = 'SNMPv3User1')]
        [String]$SNMPv3User1EngineID,

        # User 2
        
        # Security name—The user profile name. Enter an alphanumeric string of 1 to 32 characters.
        [ValidateScript({ $_.Length -ge 1 -and $_.Length -le 32 })]
        [String]$SNMPv3User2UserName,       

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('MD5', 'SHA', 'SHA256')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('MD5', 'SHA', 'SHA256')]
        [String]$SNMPv3User2AuthenticationProtocol = 'SHA256',

        # Authentication passphrase—Sets the passphrase to use for sign operations.
        [ValidateNotNull()]
        [System.Security.SecureString]$SNMPv3User2AuthenticationPassphrase,

        # Privacy passphrase—Sets the passphrase used for encrypt operations.
        [ValidateNotNull()]
        [System.Security.SecureString]$SNMPv3User2PrivacyPassphrase,

        # User engine ID—Sets the user engine ID for SNMPv3 Inform packets. This value is used only for creating remote accounts used with INFORM messages.
        # If this value is not set, INFORM messages are sent with the default value or the configured SNMPv3 Engine ID.
        # This value must be a hexadecimal string with an even number of 10 to 64 characters, excluding the first two characters, 0x.
        # For example: 0x01020304abcdef
        [ValidatePattern('^0x[0-9A-Fa-f]{10,64}$')]
        [ValidateScript({
                $hexPart = $_.Substring(2)  # Remove '0x' prefix
                if ($hexPart.Length % 2 -ne 0) {
                    throw "User Engine ID must have an even number of hex characters after '0x'"
                }
                return $true
            })]
        [String]$SNMPv3User2EngineID,

        # SNMP ALERT DESTINATIONS       

        # Destination—The IP address or FQDN of a management system that will receive SNMP alerts from iLO. This value can be up to 255 characters.
        # When SNMP Alert Destinations are configured using FQDNs, and DNS provides both IPv4 and IPv6 addresses for the FQDNs, iLO sends traps to the address specified by the iLO Client Applications use IPv6 first setting on the IPv6 page. If iLO Client Applications use IPv6 first is enabled, traps will be sent to IPv6 addresses (when available). When iLO Client Applications use IPv6 first is disabled, traps will be sent to IPv4 addresses (when available).
        [ValidateScript({ $_.Length -le 255 })]
        [String]$SNMPAlertDestination1,

        # Trap community—The configured SNMP trap community string.
        [ValidateScript({ $_.Length -le 64 })]
        [String]$SNMPTrapCommunityForDestination1,
       
        # SNMP protocol—The SNMP protocol to use with the configured alert destination (SNMPv1 Trap, SNMPv3 Trap, or SNMPv3 Inform).
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('SNMPv1 Trap', 'SNMPv3 Trap', 'SNMPv3 Inform')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('SNMPv1 Trap', 'SNMPv3 Trap', 'SNMPv3 Inform')]
        [String]$SNMPProtocolForDestination1,
       
        [String]$SNMPv3UserForDestination1,

        [ValidateScript({ $_.Length -le 255 })]
        [String]$SNMPAlertDestination2,

        [ValidateScript({ $_.Length -le 64 })]
        [String]$SNMPTrapCommunityForDestination2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('SNMPv1 Trap', 'SNMPv3 Trap', 'SNMPv3 Inform')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('SNMPv1 Trap', 'SNMPv3 Trap', 'SNMPv3 Inform')]
        [String]$SNMPProtocolForDestination2,

        [String]$SNMPv3UserForDestination2,
       
        [ValidateScript({ $_.Length -le 255 })]
        [String]$SNMPAlertDestination3,

        [ValidateScript({ $_.Length -le 64 })]
        [String]$SNMPTrapCommunityForDestination3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('SNMPv1 Trap', 'SNMPv3 Trap', 'SNMPv3 Inform')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('SNMPv1 Trap', 'SNMPv3 Trap', 'SNMPv3 Inform')]
        [String]$SNMPProtocolForDestination3,

        [String]$SNMPv3UserForDestination3,

        # SECURITY SERVICES
        # Global component integrity check (iLO 6 and iLO 7)—Enables or disables authentication of all applicable components in the server by using SPDM (Security Protocol and Data Model).
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Enabled', 'Disabled')]
        [String]$GlobalComponentIntegrityCheck,

        # Global integrity policy - No policy or Halt boot on SPDM failure
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('No policy', 'Halt boot on SPDM failure')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('No policy', 'Halt boot on SPDM failure')]
        [String]$GlobalComponentIntegrityPolicy = 'No policy',

    [Parameter(ParameterSetName = 'Default')]
    [Switch]$WhatIf
       
    ) 
    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-COMSettingsUri
        $NewiLOServerSettingStatus = [System.Collections.ArrayList]::new()

        # Custom validation for SNMPv3User1 block (when a user is added, AuthenticationPassphrase and Privacy passphrase must be provided)
        if (($SNMPv3User1UserName -and -not $PSBoundParameters.ContainsKey('SNMPv3User1AuthenticationPassphrase')) -or ($SNMPv3User1UserName -and -not $PSBoundParameters.ContainsKey('SNMPv3User1PrivacyPassphrase'))) {
            throw "If you use -SNMPv3User1UserName, you must also provide -SNMPv3User1AuthenticationPassphrase and -SNMPv3User1PrivacyPassphrase."
        }

        if (($PSBoundParameters.ContainsKey('SNMPv3User1AuthenticationPassphrase') -and -not $SNMPv3User1UserName) -or ($PSBoundParameters.ContainsKey('SNMPv3User1PrivacyPassphrase') -and -not $SNMPv3User1UserName) -or ($PSBoundParameters.ContainsKey('SNMPv3User1EngineID') -and -not $SNMPv3User1UserName) -or ($PSBoundParameters.ContainsKey('SNMPv3User1AuthenticationProtocol') -and -not $SNMPv3User1UserName)) {
            throw "If you use -SNMPv3User1AuthenticationPassphrase or -SNMPv3User1PrivacyPassphrase or -SNMPv3User1EngineID or -SNMPv3User1AuthenticationProtocol, you must also provide -SNMPv3User1UserName."
        }

        # Only convert SecureString if not null
        if ($PSBoundParameters.ContainsKey('SNMPv3User1AuthenticationPassphrase')) {
            $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SNMPv3User1AuthenticationPassphrase)
            $SNMPv3User1AuthenticationPassphrasePlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($Ptr)
        }

        if ($PSBoundParameters.ContainsKey('SNMPv3User1PrivacyPassphrase')) {
            $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SNMPv3User1PrivacyPassphrase)
            $SNMPv3User1PrivacyPassphrasePlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($Ptr)
        }
        
        # Custom validation for SNMPv3User2 block (when a user is added, AuthenticationPassphrase and Privacy passphrase must be provided)
        if (($SNMPv3User2UserName -and -not $PSBoundParameters.ContainsKey('SNMPv3User2AuthenticationPassphrase')) -or ($SNMPv3User2UserName -and -not $PSBoundParameters.ContainsKey('SNMPv3User2PrivacyPassphrase'))) {
            throw "If you use -SNMPv3User2UserName, you must also provide -SNMPv3User2AuthenticationPassphrase and -SNMPv3User2PrivacyPassphrase."
        }

        if (($PSBoundParameters.ContainsKey('SNMPv3User2AuthenticationPassphrase') -and -not $SNMPv3User2UserName) -or ($PSBoundParameters.ContainsKey('SNMPv3User2PrivacyPassphrase') -and -not $SNMPv3User2UserName) -or ($PSBoundParameters.ContainsKey('SNMPv3User2EngineID') -and -not $SNMPv3User2UserName) -or ($PSBoundParameters.ContainsKey('SNMPv3User2AuthenticationProtocol') -and -not $SNMPv3User2UserName)) {
            throw "If you use -SNMPv3User2AuthenticationPassphrase or -SNMPv3User2PrivacyPassphrase or -SNMPv3User2EngineID or -SNMPv3User2AuthenticationProtocol, you must also provide -SNMPv3User2UserName."
        }

        # Only convert SecureString if not null
        if ($PSBoundParameters.ContainsKey('SNMPv3User2AuthenticationPassphrase')) {
            $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SNMPv3User2AuthenticationPassphrase)
            $SNMPv3User2AuthenticationPassphrasePlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($Ptr)
        }
        if ($PSBoundParameters.ContainsKey('SNMPv3User2PrivacyPassphrase')) {
            $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SNMPv3User2PrivacyPassphrase)
            $SNMPv3User2PrivacyPassphrasePlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($Ptr)
        }

        # Custom validation for SNMPTrapDest1 block
        if ($PSBoundParameters.ContainsKey('SNMPAlertDestination1') -and $SNMPAlertDestination1 -ne "" -and -not $SNMPTrapCommunityForDestination1){
            throw "If you use -SNMPAlertDestination1, you must also provide -SNMPTrapCommunityForDestination1."
        }
        if ($PSBoundParameters.ContainsKey('SNMPAlertDestination1') -and $SNMPAlertDestination1 -ne "" -and -not $SNMPProtocolForDestination1) {
            throw "If you use -SNMPAlertDestination1, you must also provide -SNMPProtocolForDestination1."
        }
        if ($SNMPTrapCommunityForDestination1 -and -not $SNMPAlertDestination1) {
            throw "If you use -SNMPTrapCommunityForDestination1, you must also provide -SNMPAlertDestination1."
        }
        if ($SNMPTrapCommunityForDestination1 -and -not $SNMPProtocolForDestination1) {
            throw "If you use -SNMPTrapCommunityForDestination1, you must also provide -SNMPProtocolForDestination1."
        }
        if ($SNMPProtocolForDestination1 -and -not $SNMPTrapCommunityForDestination1) {
            throw "If you use -SNMPProtocolForDestination1, you must also provide -SNMPTrapCommunityForDestination1."
        }
        if ($SNMPProtocolForDestination1 -and -not $SNMPAlertDestination1) {
            throw "If you use -SNMPProtocolForDestination1, you must also provide -SNMPAlertDestination1."
        }
        if (($SNMPProtocolForDestination1 -eq "SNMPv3 Trap" -or $SNMPProtocolForDestination1 -eq "SNMPv3 Inform") -and -not $SNMPv3UserForDestination1) {
            throw "If you use -SNMPProtocolForDestination1 with SNMP v3, you must also provide -SNMPv3UserForDestination1."
        }   

        # Custom validation for SNMPTrapDest2 block
        if ($PSBoundParameters.ContainsKey('SNMPAlertDestination2') -and $SNMPAlertDestination2 -ne "" -and -not $SNMPTrapCommunityForDestination2){
            throw "If you use -SNMPAlertDestination2, you must also provide -SNMPTrapCommunityForDestination2."
        }
        if ($PSBoundParameters.ContainsKey('SNMPAlertDestination2') -and $SNMPAlertDestination2 -ne "" -and -not $SNMPProtocolForDestination2) {
            throw "If you use -SNMPAlertDestination2, you must also provide -SNMPProtocolForDestination2."
        }
        if ($SNMPTrapCommunityForDestination2 -and -not $SNMPAlertDestination2) {
            throw "If you use -SNMPTrapCommunityForDestination2, you must also provide -SNMPAlertDestination2."
        }
        if ($SNMPTrapCommunityForDestination2 -and -not $SNMPProtocolForDestination2) {
            throw "If you use -SNMPTrapCommunityForDestination2, you must also provide -SNMPProtocolForDestination2."
        }
        if ($SNMPProtocolForDestination2 -and -not $SNMPTrapCommunityForDestination2) {
            throw "If you use -SNMPProtocolForDestination2, you must also provide -SNMPTrapCommunityForDestination2."
        }
        if ($SNMPProtocolForDestination2 -and -not $SNMPAlertDestination2) {
            throw "If you use -SNMPProtocolForDestination2, you must also provide -SNMPAlertDestination2."
        }
        if (($SNMPProtocolForDestination2 -eq "SNMPv3 Trap" -or $SNMPProtocolForDestination2 -eq "SNMPv3 Inform") -and -not $SNMPv3UserForDestination2) {
            throw "If you use -SNMPProtocolForDestination2 with SNMP v3, you must also provide -SNMPv3UserForDestination2."
        }        

        # Custom validation for SNMPTrapDest3 block
        if ($PSBoundParameters.ContainsKey('SNMPAlertDestination3') -and $SNMPAlertDestination3 -ne "" -and -not $SNMPTrapCommunityForDestination3){
            throw "If you use -SNMPAlertDestination3, you must also provide -SNMPTrapCommunityForDestination3."
        }
        if ($PSBoundParameters.ContainsKey('SNMPAlertDestination3') -and $SNMPAlertDestination3 -ne "" -and -not $SNMPProtocolForDestination3) {
            throw "If you use -SNMPAlertDestination3, you must also provide -SNMPProtocolForDestination3."
        }
        if ($SNMPTrapCommunityForDestination3 -and -not $SNMPAlertDestination3) {
            throw "If you use -SNMPTrapCommunityForDestination3, you must also provide -SNMPAlertDestination3."
        }
        if ($SNMPTrapCommunityForDestination3 -and -not $SNMPProtocolForDestination3) {
            throw "If you use -SNMPTrapCommunityForDestination3, you must also provide -SNMPProtocolForDestination3."
        }
        if ($SNMPProtocolForDestination3 -and -not $SNMPTrapCommunityForDestination3) {
            throw "If you use -SNMPProtocolForDestination3, you must also provide -SNMPTrapCommunityForDestination3."
        }
        if ($SNMPProtocolForDestination3 -and -not $SNMPAlertDestination3) {
            throw "If you use -SNMPProtocolForDestination3, you must also provide -SNMPAlertDestination3."
        }
        if (($SNMPProtocolForDestination3 -eq "SNMPv3 Trap" -or $SNMPProtocolForDestination3 -eq "SNMPv3 Inform") -and -not $SNMPv3UserForDestination3) {
            throw "If you use -SNMPProtocolForDestination3 with SNMP v3, you must also provide -SNMPv3UserForDestination3."
        }  
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
            $SettingResource = Get-HPECOMSetting -Region $Region -Name $Name -Category IloSettings

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)

        }

        if ($SettingResource) {

            "[{0}] Setting '{1}' is already present in the '{2}' region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
    
            if ($WhatIf) {
                $ErrorMessage = "Setting '{0}': Resource is already present in the '{1}' region!" -f $Name, $Region
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "Setting already exists in the region!"
            }

        }
        else {

            # Build the payload with the provided parameters

            #Region ACCOUNT SERVICE ########################################
            $AccountService = @{}

            if ($AccountServiceAuthenticationFailureBeforeDelay) {
                $AccountServiceAuthenticationFailureBeforeDelayValue = 
                switch ($AccountServiceAuthenticationFailureBeforeDelay) {
                    'EveryFailureCausesDelay' { 0 }
                    '1FailureCausesNoDelay' { 1 }
                    '3FailuresCauseNoDelay' { 3 }
                    '5FailuresCausesNoDelay' { 5 }
                    Default { 
                        Throw "Invalid value for AccountServiceAuthenticationFailureBeforeDelay: $AccountServiceAuthenticationFailureBeforeDelay"
                    }   
                }

                $AccountService['AuthFailuresBeforeDelay'] = [int]$AccountServiceAuthenticationFailureBeforeDelayValue
            }

            if ($AccountServiceAuthenticationFailureDelayTimeInSeconds) {
                $AccountService['AuthFailureDelayTimeSeconds'] = [int]$AccountServiceAuthenticationFailureDelayTimeInSeconds
            }

            if ($AccountServiceAuthenticationFailureLogging) {

                $AccountServiceAuthenticationFailureLoggingValue = 
                switch ($AccountServiceAuthenticationFailureLogging) {
                    'Disabled' { 0 }
                    'Enabled - every failure' { 1 }
                    'Enabled - every 2nd failure' { 2 }
                    'Enabled - every 3rd failure' { 3 }
                    'Enabled - every 4th failure' { 4 }
                    'Enabled - every 5th failure' { 5 }
                    Default { 
                        Throw "Invalid value for AccountServiceAuthenticationFailureLogging: $AccountServiceAuthenticationFailureLogging"
                    }   
                }

                $AccountService['AuthFailureLoggingThreshold'] = [int]$AccountServiceAuthenticationFailureLoggingValue
            }

            if ($AccountServicePasswordMinimumLength) {
                $AccountService['MinPasswordLength'] = [int]$AccountServicePasswordMinimumLength
            }

            if ($AccountServicePasswordComplexity) {
                $AccountServicePasswordComplexityValue = 
                switch ($AccountServicePasswordComplexity) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for AccountServicePasswordComplexity: $AccountServicePasswordComplexity"
                    }   
                }
                $AccountService['EnforcePasswordComplexity'] = $AccountServicePasswordComplexityValue
            }

            #EndRegion

            #Region NETWORK PROTOCOL #######################################

            $NetworkProtocol = @{}

            if ($AnonymousData) {
                $AnonymousDataValue = 
                switch ($AnonymousData) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for AnonymousData: $AnonymousData"
                    }   
                }
                $NetworkProtocol['XMLResponseEnabled'] = $AnonymousDataValue
            }

            if ($IPMIDCMIOverLAN) {
                $IPMIDCMIOverLANValue = 
                switch ($IPMIDCMIOverLAN) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for IPMIDCMIOverLAN: $IPMIDCMIOverLAN"
                    }   
                }
                if (-not $NetworkProtocol.ContainsKey('IPMI')) {
                    $NetworkProtocol['IPMI'] = @{}
                }
                $NetworkProtocol['IPMI']['ProtocolEnabled'] = $IPMIDCMIOverLANValue
            }
        

            # $IPMIDCMIOverLANPort
            if ($IPMIDCMIOverLANPort) {
                if (-not $NetworkProtocol.ContainsKey('IPMI')) {
                    $NetworkProtocol['IPMI'] = @{}
                }
                $NetworkProtocol['IPMI']['Port'] = [int]$IPMIDCMIOverLANPort
            }

            # $RemoteConsole
            if ($RemoteConsole) {
                $RemoteConsoleValue = 
                switch ($RemoteConsole) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for RemoteConsole: $RemoteConsole"
                    }   
                }

                if (-not $NetworkProtocol.ContainsKey('KVMIP')) {
                    $NetworkProtocol['KVMIP'] = @{}
                }
                $NetworkProtocol['KVMIP']['ProtocolEnabled'] = $RemoteConsoleValue
            }

            # $RemoteConsolePort
            if ($RemoteConsolePort) {
                if (-not $NetworkProtocol.ContainsKey('KVMIP')) {
                    $NetworkProtocol['KVMIP'] = @{}
                }
                $NetworkProtocol['KVMIP']['Port'] = [int]$RemoteConsolePort
            }

            # $SSH
            if ($SSH) {
                $SSHValue = 
                switch ($SSH) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for SSH: $SSH"
                    }   
                }
                if (-not $NetworkProtocol.ContainsKey('SSH')) {
                    $NetworkProtocol['SSH'] = @{}
                }
                $NetworkProtocol['SSH']['ProtocolEnabled'] = $SSHValue
            }

            # $SSHPort
            if ($SSHPort) {
                if (-not $NetworkProtocol.ContainsKey('SSH')) {
                    $NetworkProtocol['SSH'] = @{}
                }
                $NetworkProtocol['SSH']['Port'] = [int]$SSHPort
            }

            # $SNMP
            if ($SNMP) {
                $SNMPValue = 
                switch ($SNMP) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for SNMP: $SNMP"
                    }   
                }
                if (-not $NetworkProtocol.ContainsKey('SNMP')) {
                    $NetworkProtocol['SNMP'] = @{}
                }
                $NetworkProtocol['SNMP']['ProtocolEnabled'] = $SNMPValue
            }

            # $SNMPPort
            if ($SNMPPort) {
                if (-not $NetworkProtocol.ContainsKey('SNMP')) {
                    $NetworkProtocol['SNMP'] = @{}
                }
                $NetworkProtocol['SNMP']['Port'] = [int]$SNMPPort
            }

            # $SNMPTrapPort
            if ($SNMPTrapPort) {
                if (-not $NetworkProtocol.ContainsKey('SNMP')) {
                    $NetworkProtocol['SNMP'] = @{}
                }
                $NetworkProtocol['SNMP']['SNMPTrapPort'] = [int]$SNMPTrapPort
            }

            # $VirtualMedia
            if ($VirtualMedia) {
                $VirtualMediaValue = 
                switch ($VirtualMedia) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for VirtualMedia: $VirtualMedia"
                    }   
                }
                if (-not $NetworkProtocol.ContainsKey('VirtualMedia')) {
                    $NetworkProtocol['VirtualMedia'] = @{}
                }
                $NetworkProtocol['VirtualMedia']['ProtocolEnabled'] = $VirtualMediaValue
            }

            # $VirtualMediaPort
            if ($VirtualMediaPort) {
                if (-not $NetworkProtocol.ContainsKey('VirtualMedia')) {
                    $NetworkProtocol['VirtualMedia'] = @{}
                }
                $NetworkProtocol['VirtualMedia']['Port'] = [int]$VirtualMediaPort
            }

            # $VirtualSerialPortLogOverCLI
            if ($VirtualSerialPortLogOverCLI) {
                $VirtualSerialPortLogOverCLIValue = 
                switch ($VirtualSerialPortLogOverCLI) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for VirtualSerialPortLogOverCLI: $VirtualSerialPortLogOverCLI"
                    }   
                }
                
                $NetworkProtocol['SerialOverLanLogging'] = $VirtualSerialPortLogOverCLIValue
            }

            # $WebServerSSL
            if ($WebServerSSL) {
                $WebServerSSLValue = 
                switch ($WebServerSSL) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for WebServerSSL: $WebServerSSL"
                    }   
                }
                if (-not $NetworkProtocol.ContainsKey('HTTPS')) {
                    $NetworkProtocol['HTTPS'] = @{}
                }
                $NetworkProtocol['HTTPS']['ProtocolEnabled'] = $WebServerSSLValue
            }

            # $WebServerSSLPort
            if ($WebServerSSLPort) {
                if (-not $NetworkProtocol.ContainsKey('HTTPS')) {
                    $NetworkProtocol['HTTPS'] = @{}
                }
                $NetworkProtocol['HTTPS']['Port'] = [int]$WebServerSSLPort
            }

            # # $WebServerNonSSL
            # if ($WebServerNonSSL) {
            #     $WebServerNonSSLValue = 
            #     switch ($WebServerNonSSL) {
            #         'Disabled' { $false }
            #         'Enabled' { $true }
            #         Default { 
            #             Throw "Invalid value for WebServerNonSSL: $WebServerNonSSL"
            #         }   
            #     }
            #     if (-not $NetworkProtocol.ContainsKey('HTTP')) {
            #         $NetworkProtocol['HTTP'] = @{}
            #     }
            #     $NetworkProtocol['HTTP']['ProtocolEnabled'] = $WebServerNonSSLValue
            # }

            # # $WebServerNonSSLPort
            # if ($WebServerNonSSLPort) {
            #     if (-not $NetworkProtocol.ContainsKey('HTTP')) {
            #         $NetworkProtocol['HTTP'] = @{}
            #     }
            #     $NetworkProtocol['HTTP']['Port'] = [int]$WebServerNonSSLPort
            # }

            #EndRegion

            #Region ILO ####################################################
            $1 = @{}

            # $DownloadableVirtualSerialPortLog
            if ($DownloadableVirtualSerialPortLog) {
                $DownloadableVirtualSerialPortLogValue = 
                switch ($DownloadableVirtualSerialPortLog) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for DownloadableVirtualSerialPortLog: $DownloadableVirtualSerialPortLog"
                    }   
                }
                $1['VSPLogDownloadEnabled'] = $DownloadableVirtualSerialPortLogValue
            }

            # $IdleConnectionTimeoutinMinutes
            if ($IdleConnectionTimeoutinMinutes) {
                $1['IdleConnectionTimeoutMinutes'] = [int]$IdleConnectionTimeoutinMinutes
            }

            # $iLORIBCLInterface
            if ($iLORIBCLInterface) {
                $iLORIBCLInterfaceValue =
                switch ($iLORIBCLInterface) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for iLORIBCLInterface: $iLORIBCLInterface"
                    }   
                }
                $1['RIBCLEnabled'] = $iLORIBCLInterfaceValue
            }

            # $iLOROMSetupUtility
            if ($iLOROMSetupUtility) {
                $iLOROMSetupUtilityValue =
                switch ($iLOROMSetupUtility) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for iLOROMSetupUtility: $iLOROMSetupUtility"
                    }   
                }
                $1['iLORBSUEnabled'] = $iLOROMSetupUtilityValue
            }

            # $iLOWebInterface
            if ($iLOWebInterface) {
                $iLOWebInterfaceValue =
                switch ($iLOWebInterface) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for iLOWebInterface: $iLOWebInterface"
                    }   
                }
                $1['WebGuiEnabled'] = $iLOWebInterfaceValue
            }

            # $iLORemoteConsoleThumbnail
            if ($iLORemoteConsoleThumbnail) {
                $iLORemoteConsoleThumbnailValue =
                switch ($iLORemoteConsoleThumbnail) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for iLORemoteConsoleThumbnail: $iLORemoteConsoleThumbnail"
                    }   
                }
                $1['RemoteConsoleThumbnailEnabled'] = $iLORemoteConsoleThumbnailValue
            }

            # $iLOHostAuthRequired
            if ($iLOHostAuthRequired) {
                $iLOHostAuthRequiredValue =
                switch ($iLOHostAuthRequired) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for iLOHostAuthRequired: $iLOHostAuthRequired"
                    }   
                }
                $1['RequireHostAuthentication'] = $iLOHostAuthRequiredValue
            }

            # $iLORBSULoginRequired
            if ($iLORBSULoginRequired) {
                $iLORBSULoginRequiredValue =
                switch ($iLORBSULoginRequired) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for iLORBSULoginRequired: $iLORBSULoginRequired"
                    }   
                }
                $1['RequiredLoginForiLORBSU'] = $iLORBSULoginRequiredValue
            }

            # $SerialCommandLineInterfaceSpeed
            if ($SerialCommandLineInterfaceSpeed) {
                $1['SerialCLISpeed'] = [int]$SerialCommandLineInterfaceSpeed
            }

            # $SerialCommandLineInterfaceStatus
            if ($SerialCommandLineInterfaceStatus) {
                $SerialCommandLineInterfaceStatusValue =
                switch ($SerialCommandLineInterfaceStatus) {
                    'Disabled' { 'Disabled' }
                    'Enabled - no authentication required' { 'EnabledNoAuth' }
                    'Enabled - authentication required' { 'EnabledAuthReq' }
                    Default { 
                        Throw "Invalid value for SerialCommandLineInterfaceStatus: $SerialCommandLineInterfaceStatus"
                    }   
                }
                $1['SerialCLIStatus'] = $SerialCommandLineInterfaceStatusValue
            }

            # $ShowiLOIPDuringPOST
            if ($ShowiLOIPDuringPOST) {
                $ShowiLOIPDuringPOSTValue =
                switch ($ShowiLOIPDuringPOST) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for ShowiLOIPDuringPOST: $ShowiLOIPDuringPOST"
                    }   
                }
                $1['iLOIPduringPOSTEnabled'] = $ShowiLOIPDuringPOSTValue
            }

            # $ShowServerHealthOnExternalMonitor
            if ($ShowServerHealthOnExternalMonitor) {
                $ShowServerHealthOnExternalMonitorValue =
                switch ($ShowServerHealthOnExternalMonitor) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for ShowServerHealthOnExternalMonitor: $ShowServerHealthOnExternalMonitor"
                    }   
                }
                $1['PhysicalMonitorHealthStatusEnabled'] = $ShowServerHealthOnExternalMonitorValue
            }

            # $VGAPortDetectOverride
            if ($VGAPortDetectOverride) {
                $VGAPortDetectOverrideValue =
                switch ($VGAPortDetectOverride) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for VGAPortDetectOverride: $VGAPortDetectOverride"
                    }   
                }
                $1['VideoPresenceDetectOverride'] = $VGAPortDetectOverrideValue
            }

            # $VirtualNICEnabled
            if ($VirtualNICEnabled) {
                $VirtualNICEnabledValue =
                switch ($VirtualNICEnabled) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for VirtualNICEnabled: $VirtualNICEnabled"
                    }   
                }
                $1['VirtualNICEnabled'] = $VirtualNICEnabledValue
            }

            #EndRegion
          
            #Region UPDATE SERVICE #########################################
            $UpdateService = @{}

            # $AcceptThirdPartyFirmwareUpdates
            if ($AcceptThirdPartyFirmwareUpdates) {
                $AcceptThirdPartyFirmwareUpdatesValue =
                switch ($AcceptThirdPartyFirmwareUpdates) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for AcceptThirdPartyFirmwareUpdates: $AcceptThirdPartyFirmwareUpdates"
                    }   
                }
                $UpdateService['Accept3rdPartyFirmware'] = $AcceptThirdPartyFirmwareUpdatesValue
            }

            #EndRegion

            #Region SNMP SERVICE ###########################################

            $SNMPService = @{}

            # $TrapSourceIdentifier
            if ($TrapSourceIdentifier) {
                $TrapSourceIdentifierValue =
                switch ($TrapSourceIdentifier) {
                    'OS hostname' { 'Manager' }
                    'iLO hostname' { 'System' }
                    Default { 
                        Throw "Invalid value for TrapSourceIdentifier: $TrapSourceIdentifier"
                    }   
                }
                $SNMPService['TrapSourceHostname'] = $TrapSourceIdentifierValue
            }

            # $SNMPv1Request
            if ($SNMPv1Request) {
                $SNMPv1RequestValue =
                switch ($SNMPv1Request) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for SNMPv1Request: $SNMPv1Request"
                    }   
                }
                $SNMPService['SNMPv1RequestsEnabled'] = $SNMPv1RequestValue
            }

            # $SNMPv1Trap
            if ($SNMPv1Trap) {
                $SNMPv1TrapValue =
                switch ($SNMPv1Trap) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for SNMPv1Trap: $SNMPv1Trap"
                    }   
                }
                $SNMPService['SNMPv1TrapEnabled'] = $SNMPv1TrapValue
            }

            # $SNMPv3Request
            if ($SNMPv3Request) {
                $SNMPv3RequestValue =
                switch ($SNMPv3Request) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for SNMPv3Request: $SNMPv3Request"
                    }   
                }
                $SNMPService['SNMPv3RequestsEnabled'] = $SNMPv3RequestValue
            }

            # $SNMPv3Trap
            if ($SNMPv3Trap) {
                $SNMPv3TrapValue =
                switch ($SNMPv3Trap) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for SNMPv3Trap: $SNMPv3Trap"
                    }   
                }
                $SNMPService['SNMPv3TrapEnabled'] = $SNMPv3TrapValue
            }

            # $ColdStartTrap
            if ($ColdStartTrap) {
                $ColdStartTrapValue =
                switch ($ColdStartTrap) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for ColdStartTrap: $ColdStartTrap"
                    }   
                }
                $SNMPService['SNMPColdStartTrapBroadcast'] = $ColdStartTrapValue
            }

            # $PeriodicHSATrapConfiguration
            if ($PeriodicHSATrapConfiguration) {
                $SNMPService['PeriodicHSATrapConfig'] = $PeriodicHSATrapConfiguration
            }

            # $SNMPSettingsSystemLocation
            if ($SNMPSettingsSystemLocation) {
                $SNMPService['Location'] = $SNMPSettingsSystemLocation
            }

            # $SNMPSettingsSystemContact
            if ($SNMPSettingsSystemContact) {
                $SNMPService['Contact'] = $SNMPSettingsSystemContact
            }

            # $SNMPSettingsSystemRole
            if ($SNMPSettingsSystemRole) {
                $SNMPService['Role'] = $SNMPSettingsSystemRole
            }

            # $SNMPSettingsSystemRoleDetails
            if ($SNMPSettingsSystemRoleDetails) {
                $SNMPService['RoleDetail'] = $SNMPSettingsSystemRoleDetails
            }

            # $SNMPSettingsReadCommunity1
            if ($SNMPSettingsReadCommunity1) {
                if (-not $SNMPService.ContainsKey('ReadCommunities')) {
                    $SNMPService['ReadCommunities'] = @()
                }
                $SNMPService['ReadCommunities'] += $SNMPSettingsReadCommunity1
            }

            # $SNMPSettingsReadCommunity2
            if ($SNMPSettingsReadCommunity2) { 
                if (-not $SNMPService.ContainsKey('ReadCommunities')) {
                    $SNMPService['ReadCommunities'] = @()
                }
                $SNMPService['ReadCommunities'] += $SNMPSettingsReadCommunity2
            }

            # $SNMPSettingsReadCommunity3
            if ($SNMPSettingsReadCommunity3) {
                if (-not $SNMPService.ContainsKey('ReadCommunities')) {
                    $SNMPService['ReadCommunities'] = @()
                }
                $SNMPService['ReadCommunities'] += $SNMPSettingsReadCommunity3
            }

            # $SNMPv3EngineID
            if ($SNMPv3EngineID) {
                $SNMPService['SNMPv3EngineID'] = $SNMPv3EngineID
            }

            # $SNMPv3InformRetry
            if ($SNMPv3InformRetry) {
                $SNMPService['SNMPv3InformRetryAttempt'] = $SNMPv3InformRetry
            }

            # $SNMPv3InformRetryInterval
            if ($SNMPv3InformRetryInterval) {
                $SNMPService['SNMPv3InformRetryIntervalSeconds'] = $SNMPv3InformRetryInterval
            }

            if (-not $SNMPService.ContainsKey('SNMPv3Users')) {
                $SNMPService['SNMPv3Users'] = @()
            }

            # $SNMPv3User1UserName
            if ($SNMPv3User1UserName) {
                                
                $SNMPv3User1 = @{
                    "SecurityName"      = $SNMPv3User1UserName
                    "AuthProtocol"      = $SNMPv3User1AuthenticationProtocol
                    "PrivacyProtocol"   = "AES"
                    "AuthPassphrase"    = $SNMPv3User1AuthenticationPassphrasePlainText
                    "PrivacyPassphrase" = $SNMPv3User1PrivacyPassphrasePlainText
                }

                # EngineID
                if ($PSBoundParameters.ContainsKey('SNMPv3User1EngineID')) {
                    $SNMPv3User1.UserEngineID = $SNMPv3User1EngineID
                }

                $SNMPService['SNMPv3Users'] += $SNMPv3User1
            }

            # $SNMPv3User2UserName
            if ($SNMPv3User2UserName) {
                                
                $SNMPv3User2 = @{
                    "SecurityName"      = $SNMPv3User2UserName
                    "AuthProtocol"      = $SNMPv3User2AuthenticationProtocol
                    "PrivacyProtocol"   = "AES"
                    "AuthPassphrase"    = $SNMPv3User2AuthenticationPassphrasePlainText
                    "PrivacyPassphrase" = $SNMPv3User2PrivacyPassphrasePlainText
                }

                # EngineID
                if ($PSBoundParameters.ContainsKey('SNMPv3User2EngineID')) {
                    $SNMPv3User2.UserEngineID = $SNMPv3User2EngineID
                } 
                                
                $SNMPService['SNMPv3Users'] += $SNMPv3User2
            }           

            # SNMP ALERT DESTINATIONS 
            
            if (-not $SNMPService.ContainsKey('SNMPAlertDestinations')) {
                $SNMPService['SNMPAlertDestinations'] = @()
            }            

            # $SNMPAlertDestination1
            if ($SNMPAlertDestination1) {

                # $SNMPProtocolForDestination1
                $SNMPProtocolForDestination1Value =
                switch ($SNMPProtocolForDestination1) {
                    'SNMPv1 Trap' { 'SNMPv1Trap' }
                    'SNMPv3 Trap' { 'SNMPv3Trap' }
                    'SNMPv3 Inform' { 'SNMPv3Inform' }
                    Default { 
                        Throw "Invalid value for SNMPProtocolForDestination1: $SNMPProtocolForDestination1"
                    }   
                }              
                     
                if ($SNMPProtocolForDestination1Value -eq "SNMPv3Trap" -or $SNMPProtocolForDestination1Value -eq "SNMPv3Inform"){
                    $AlertDestination1 = @{
                        "SecurityName"      = $SNMPv3UserForDestination1
                        "AlertDestination"  = $SNMPAlertDestination1
                        "TrapCommunity"     = $SNMPTrapCommunityForDestination1
                        "SNMPAlertProtocol" = $SNMPProtocolForDestination1Value
                    }                
                }
                else {
                    $AlertDestination1 = @{
                    "AlertDestination"  = $SNMPAlertDestination1
                    "TrapCommunity"     = $SNMPTrapCommunityForDestination1
                    "SNMPAlertProtocol" = $SNMPProtocolForDestination1Value
                    }
                }                
                
                $SNMPService['SNMPAlertDestinations'] += $AlertDestination1
            }

            # $SNMPAlertDestination2
            if ($SNMPAlertDestination2) {

                # $SNMPProtocolForDestination2
                $SNMPProtocolForDestination2Value =
                switch ($SNMPProtocolForDestination2) {
                    'SNMPv1 Trap' { 'SNMPv1Trap' }
                    'SNMPv3 Trap' { 'SNMPv3Trap' }
                    'SNMPv3 Inform' { 'SNMPv3Inform' }
                    Default { 
                        Throw "Invalid value for SNMPProtocolForDestination2: $SNMPProtocolForDestination2"
                    }   
                }              

                if ($SNMPProtocolForDestination2Value -eq "SNMPv3Trap" -or $SNMPProtocolForDestination2Value -eq "SNMPv3Inform"){
                    $AlertDestination2 = @{
                        "SecurityName"      = $SNMPv3UserForDestination2
                        "AlertDestination"  = $SNMPAlertDestination2
                        "TrapCommunity"     = $SNMPTrapCommunityForDestination2
                        "SNMPAlertProtocol" = $SNMPProtocolForDestination2Value
                    }                
                }
                else {
                    $AlertDestination2 = @{
                        "AlertDestination"  = $SNMPAlertDestination2
                        "TrapCommunity"     = $SNMPTrapCommunityForDestination2
                        "SNMPAlertProtocol" = $SNMPProtocolForDestination2Value
                    }
                }

                $SNMPService['SNMPAlertDestinations'] += $AlertDestination2
            }

            # $SNMPAlertDestination3
            if ($SNMPAlertDestination3) {

                # $SNMPProtocolForDestination3
                $SNMPProtocolForDestination3Value =
                switch ($SNMPProtocolForDestination3) {
                    'SNMPv1 Trap' { 'SNMPv1Trap' }
                    'SNMPv3 Trap' { 'SNMPv3Trap' }
                    'SNMPv3 Inform' { 'SNMPv3Inform' }
                    Default { 
                        Throw "Invalid value for SNMPProtocolForDestination3: $SNMPProtocolForDestination3"
                    }   
                }              

                if ($SNMPProtocolForDestination3Value -eq "SNMPv3Trap" -or $SNMPProtocolForDestination3Value -eq "SNMPv3Inform"){
                    $AlertDestination3 = @{
                        "SecurityName"      = $SNMPv3UserForDestination3
                        "AlertDestination"  = $SNMPAlertDestination3
                        "TrapCommunity"     = $SNMPTrapCommunityForDestination3
                        "SNMPAlertProtocol" = $SNMPProtocolForDestination3Value
                    }                
                }
                else {
                    $AlertDestination3 = @{
                        "AlertDestination"  = $SNMPAlertDestination3
                        "TrapCommunity"     = $SNMPTrapCommunityForDestination3
                        "SNMPAlertProtocol" = $SNMPProtocolForDestination3Value
                    }
                }                

                $SNMPService['SNMPAlertDestinations'] += $AlertDestination3
            }       
           
            #EndRegion

            #Region SECURITY SERVICE #######################################

            $SecurityService = @{}

            # $GlobalComponentIntegrityCheck
            if ($GlobalComponentIntegrityCheck) {            
                $SecurityService['GlobalComponentIntegrity'] = $GlobalComponentIntegrityCheck
            }

            # $GlobalComponentIntegrityPolicy
            if ($GlobalComponentIntegrityPolicy) {
                $GlobalComponentIntegrityPolicyValue =
                switch ($GlobalComponentIntegrityPolicy) {
                    'No policy' { 'NoPolicy' }
                    'Halt boot on SPDM failure' { 'HaltBootOnSPDMFailure' }
                        
                    Default { 
                        Throw "Invalid value for GlobalComponentIntegrityPolicy: $GlobalComponentIntegrityPolicy"
                    }   
                }
                $SecurityService['ComponentIntegrityPolicy'] = $GlobalComponentIntegrityPolicyValue           
            }


            #EndRegion

            # Build payload
    
            $Settings = @{
                Default = @{
                        "1"                      = $1
                        AccountService           = $AccountService
                        NetworkProtocol          = $NetworkProtocol
                        SecurityService          = $SecurityService 
                        UpdateService            = $UpdateService   
                        SnmpService              = $SnmpService
                }
            }
                
            $Payload = @{ 
                name           = $Name
                category       = "ILO_SETTINGS"
                description    = $Description
                settings       = $Settings                  
            }
    
            $Payload = $Payload | ConvertTo-Json -Depth 20
        
            try {
        
                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
        
                if (-not $WhatIf ) {
            
                    "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
        
                    "[{0}] iLO server setting '{1}' successfully created in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
                            
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "iLO server setting successfully created in $Region region"
    
    
                }
            }
            catch {
        
                if (-not $WhatIf) {
        
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "iLO server setting cannot be created!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData
    
                }
            }        
        }    

        [void] $NewiLOServerSettingStatus.add($objStatus)
    }
    
    End {
       
        if (-not $WhatIf ) {

            $NewiLOServerSettingStatus = Invoke-RepackageObjectWithType -RawObject $NewiLOServerSettingStatus -ObjectName "COM.objStatus.NSDE"
            Return $NewiLOServerSettingStatus

        }
    }
}

Function Set-HPECOMSettingiLOSettings {
<#
.SYNOPSIS
Update an iLO settings server setting resource in a specified region.

.DESCRIPTION
This Cmdlet is used to update an existing iLO settings server setting resource in a specified Compute Ops Management region. 
It supports configuring various iLO settings such as network protocols, SNMP, account, security and update services.

If a parameter is not provided, the cmdlet retains the current value and only updates the provided parameters.

All parameters can be used together. If you specify SNMPv3 user or SNMP alert destination parameters, all required related parameters must also be provided, otherwise the function will throw a clear error.

.PARAMETER Region
Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

.PARAMETER Name
Specifies the name of the iLO settings configuration to create. Mandatory.

.PARAMETER Description
Provides a description for the iLO settings configuration.

.PARAMETER NewName
Specifies a new name for the iLO settings configuration.

.PARAMETER AccountServiceAuthenticationFailureBeforeDelay
Specifies the number of authentication failures before delay (EveryFailureCausesDelay, 1FailureCausesNoDelay, 3FailuresCauseNoDelay, 5FailuresCausesNoDelay).

.PARAMETER AccountServiceAuthenticationFailureDelayTimeInSeconds
Specifies the delay time in seconds after authentication failures (2, 5, 10, 30).

.PARAMETER AccountServiceAuthenticationFailureLogging
Specifies the logging threshold for authentication failures (Enabled - every failure, every 2nd, 3rd, 5th failure, Disabled).

.PARAMETER AccountServicePasswordMinimumLength
Specifies the minimum password length (0-39).

.PARAMETER AccountServicePasswordComplexity
Enforces password complexity (Enabled, Disabled).

.PARAMETER PasswordComplexity
Specifies password complexity for network (Enabled, Disabled).

.PARAMETER AnonymousData
Controls anonymous data access (Enabled, Disabled).

.PARAMETER IPMIDCMIOverLAN
Enables or disables IPMI/DCMI over LAN (Enabled, Disabled). Default: Disabled

.PARAMETER IPMIDCMIOverLANPort
Specifies the port for IPMI/DCMI over LAN. Default: 623

.PARAMETER RemoteConsole
Enables or disables remote console (Enabled, Disabled). Default: Enabled

.PARAMETER RemoteConsolePort
Specifies the port for remote console. Default: 17990

.PARAMETER SSH
Enables or disables SSH (Enabled, Disabled). Default: Enabled

.PARAMETER SSHPort
Specifies the SSH port. Default: 22

.PARAMETER SNMP
Enables or disables SNMP (Enabled, Disabled). Default: Enabled

.PARAMETER SNMPPort
Specifies the SNMP port. Default: 161

.PARAMETER SNMPTrapPort
Specifies the SNMP trap port. Default: 162

.PARAMETER VirtualMedia
Enables or disables virtual media (Enabled, Disabled). Default: Enabled

.PARAMETER VirtualMediaPort
Specifies the virtual media port. Default: 17988

.PARAMETER VirtualSerialPortLogOverCLI
Enables or disables virtual serial port log over CLI (Enabled, Disabled).

.PARAMETER WebServerSSL
Enables or disables web server SSL (Enabled, Disabled). Default: Enabled

.PARAMETER WebServerSSLPort
Specifies the web server SSL port. Default: 443

.PARAMETER DownloadableVirtualSerialPortLog
Enables or disables downloadable virtual serial port log (Enabled, Disabled).

.PARAMETER IdleConnectionTimeoutinMinutes
Specifies idle connection timeout in minutes (Disabled, 15, 30, 60, 120).

.PARAMETER iLORIBCLInterface
Enables or disables iLO RIBCL interface (Enabled, Disabled).

.PARAMETER iLOROMSetupUtility
Enables or disables iLO ROM setup utility (Enabled, Disabled).

.PARAMETER iLOWebInterface
Enables or disables iLO web interface (Enabled, Disabled).

.PARAMETER iLORemoteConsoleThumbnail
Enables or disables remote console thumbnail (Enabled, Disabled).

.PARAMETER iLOHostAuthRequired
Requires host authentication (Enabled, Disabled).

.PARAMETER iLORBSULoginRequired
Requires login for iLO RBSU (Enabled, Disabled).

.PARAMETER SerialCommandLineInterfaceSpeed
Specifies serial CLI speed (115200, 57600, 38400, 19200, 9600). Default: 9600

.PARAMETER SerialCommandLineInterfaceStatus
Specifies serial CLI status (Enabled - authentication required, Enabled - no authentication required, Disabled).

.PARAMETER ShowiLOIPDuringPOST
Shows iLO IP during POST (Enabled, Disabled).

.PARAMETER ShowServerHealthOnExternalMonitor
Shows server health on external monitor (Enabled, Disabled).

.PARAMETER VGAPortDetectOverride
Controls VGA port detect override (Enabled, Disabled).

.PARAMETER VirtualNICEnabled
Enables or disables virtual NIC (Enabled, Disabled).

.PARAMETER AcceptThirdPartyFirmwareUpdates
Accepts third-party firmware updates (Enabled, Disabled).

.PARAMETER TrapSourceIdentifier
Specifies trap source identifier (OS hostname, iLO hostname).

.PARAMETER SNMPv1Request
Enables SNMPv1 request (Enabled, Disabled).

.PARAMETER SNMPv1Trap
Enables SNMPv1 trap (Enabled, Disabled).

.PARAMETER SNMPv3Request
Enables SNMPv3 request (Enabled, Disabled).

.PARAMETER SNMPv3Trap
Enables SNMPv3 trap (Enabled, Disabled).

.PARAMETER ColdStartTrap
Enables cold start trap (Enabled, Disabled).

.PARAMETER PeriodicHSATrapConfiguration
Configures periodic HSA trap (Daily, Weekly, Monthly, Disabled).

.PARAMETER SNMPSettingsSystemLocation
Specifies SNMP system location (up to 49 chars).

.PARAMETER SNMPSettingsSystemContact
Specifies SNMP system contact (up to 49 chars).

.PARAMETER SNMPSettingsSystemRole
Specifies SNMP system role (up to 64 chars).

.PARAMETER SNMPSettingsSystemRoleDetails
Specifies SNMP system role details (up to 512 chars).

.PARAMETER SNMPSettingsReadCommunity1
Specifies SNMP read community 1 (up to 64 chars).

.PARAMETER SNMPSettingsReadCommunity2
Specifies SNMP read community 2 (up to 64 chars).

.PARAMETER SNMPSettingsReadCommunity3
Specifies SNMP read community 3 (up to 64 chars).

.PARAMETER SNMPv3EngineID
Specifies SNMPv3 engine ID (hex string, 6-48 chars after 0x, even length).

.PARAMETER SNMPv3InformRetry
Specifies SNMPv3 inform retry count (0-5). Default: 2

.PARAMETER SNMPv3InformRetryInterval
Specifies SNMPv3 inform retry interval in seconds (1-120). Default: 15

.PARAMETER SNMPv3User1UserName
Specifies SNMPv3 user 1 name (1-32 chars). If provided, must also provide SNMPv3User1AuthenticationPassphrase and SNMPv3User1PrivacyPassphrase.

.PARAMETER SNMPv3User1AuthenticationProtocol
Specifies SNMPv3 user 1 authentication protocol (MD5, SHA, SHA256).

.PARAMETER SNMPv3User1AuthenticationPassphrase
Specifies SNMPv3 user 1 authentication passphrase (SecureString).

.PARAMETER SNMPv3User1PrivacyPassphrase
Specifies SNMPv3 user 1 privacy passphrase (SecureString).

.PARAMETER SNMPv3User1EngineID
Specifies SNMPv3 user 1 engine ID (hex string, 10-64 chars after 0x, even length).

.PARAMETER SNMPv3User2UserName
Specifies SNMPv3 user 2 name (1-32 chars).

.PARAMETER SNMPv3User2AuthenticationProtocol
Specifies SNMPv3 user 2 authentication protocol (MD5, SHA, SHA256).

.PARAMETER SNMPv3User2AuthenticationPassphrase
Specifies SNMPv3 user 2 authentication passphrase (SecureString).

.PARAMETER SNMPv3User2PrivacyPassphrase
Specifies SNMPv3 user 2 privacy passphrase (SecureString).

.PARAMETER SNMPv3User2EngineID
Specifies SNMPv3 user 2 engine ID (hex string, 10-64 chars after 0x, even length).

.PARAMETER SNMPAlertDestination1
Specifies SNMP alert destination 1 (up to 255 chars). If provided, must also provide SNMPTrapCommunityForDestination1 and SNMPProtocolForDestination1.

.PARAMETER SNMPTrapCommunityForDestination1
Specifies SNMP trap community for destination 1 (up to 64 chars).

.PARAMETER SNMPProtocolForDestination1
Specifies SNMP protocol for destination 1 (SNMPv1 Trap, SNMPv3 Trap, SNMPv3 Inform).

.PARAMETER SNMPv3UserForDestination1
Specifies the SNMPv3 user name to associate with SNMP alert destination 1. This parameter is required only when -SNMPProtocolForDestination1 is set to 'SNMPv3 Trap' or 'SNMPv3 Inform'.

.PARAMETER SNMPAlertDestination2
Specifies SNMP alert destination 2 (up to 255 chars).

.PARAMETER SNMPTrapCommunityForDestination2
Specifies SNMP trap community for destination 2 (up to 64 chars).

.PARAMETER SNMPProtocolForDestination2
Specifies SNMP protocol for destination 2 (SNMPv1 Trap, SNMPv3 Trap, SNMPv3 Inform).

.PARAMETER SNMPv3UserForDestination2
Specifies the SNMPv3 user name to associate with SNMP alert destination 2. This parameter is required only when -SNMPProtocolForDestination2 is set to 'SNMPv3 Trap' or 'SNMPv3 Inform'.

.PARAMETER SNMPAlertDestination3
Specifies SNMP alert destination 3 (up to 255 chars).

.PARAMETER SNMPTrapCommunityForDestination3
Specifies SNMP trap community for destination 3 (up to 64 chars).

.PARAMETER SNMPProtocolForDestination3
Specifies SNMP protocol for destination 3 (SNMPv1 Trap, SNMPv3 Trap, SNMPv3 Inform).

.PARAMETER SNMPv3UserForDestination3
Specifies the SNMPv3 user name to associate with SNMP alert destination 3. This parameter is required only when -SNMPProtocolForDestination3 is set to 'SNMPv3 Trap' or 'SNMPv3 Inform'.

.PARAMETER GlobalComponentIntegrityCheck
Enables or disables global component integrity check (Enabled, Disabled).

.PARAMETER GlobalComponentIntegrityPolicy
Specifies global integrity policy (No policy, Halt boot on SPDM failure).

.PARAMETER WhatIf
Shows the raw REST API call that would be made to COM instead of sending the request.

.EXAMPLE
Set-HPECOMSettingiLOSettings -Region eu-central -Name "ILO_config_for_Gen12" -Description "iLO Settings for Gen12 servers" `
    -AccountServiceAuthenticationFailureBeforeDelay 3FailuresCauseNoDelay `
    -AccountServiceAuthenticationFailureDelayTimeInSeconds 30 `
    -AccountServiceAuthenticationFailureLogging Disabled

This example updates the iLO settings configuration named "ILO_config_for_Gen12" in the "eu-central" region.
It sets a description and customizes authentication failure handling:
- Delays are triggered after three failures.
- Delay time is set to 30 seconds.
- Authentication failure logging is disabled.

.EXAMPLE
$SNMPv3User1authPass = ConvertTo-SecureString 'YourPasswordHere' -AsPlainText -Force
$SNMPv3User1privPass = ConvertTo-SecureString 'YourPrivacyPassHere' -AsPlainText -Force
$SNMPv3User2authPass = ConvertTo-SecureString 'YourPassword2Here' -AsPlainText -Force
$SNMPv3User2privPass = ConvertTo-SecureString 'YourPrivacyPass2Here' -AsPlainText -Force

These commands create SecureString objects for SNMPv3 user authentication and privacy passphrases.
Use these variables as parameter values for -SNMPv3User1AuthenticationPassphrase, -SNMPv3User1PrivacyPassphrase, etc.

Set-HPECOMSettingiLOSettings -Region eu-central -Name "ILO_config_for_Gen12" -NewName "ILOconfigforGen12" -Description "This is a new description" `
 -AccountServiceAuthenticationFailureBeforeDelay 1FailureCausesNoDelay -AccountServiceAuthenticationFailureDelayTimeInSeconds 10 -AccountServiceAuthenticationFailureLogging Disabled `
 -AccountServicePasswordMinimumLength 13 -AccountServicePasswordComplexity Enabled -PasswordComplexity Enabled -AnonymousData Enabled -IPMIDCMIOverLAN Disabled -IPMIDCMIOverLANPort 342 -RemoteConsole Enabled `
 -RemoteConsolePort 339 -SSH Enabled -SSHPort 23 -SNMP Enabled -SNMPPort 162 -SNMPTrapPort 163  -VirtualMedia Enabled -VirtualMediaPort 350 -VirtualSerialPortLogOverCLI Enabled -WebServerSSL Enabled -WebServerSSLPort 443 `
 -DownloadableVirtualSerialPortLog Enabled -IdleConnectionTimeoutinMinutes 15 -iLORIBCLInterface Enabled -iLOROMSetupUtility Enabled -iLOWebInterface Enabled `
 -iLORemoteConsoleThumbnail Enabled -iLOHostAuthRequired Enabled -iLORBSULoginRequired Enabled -SerialCommandLineInterfaceSpeed 19200 -SerialCommandLineInterfaceStatus 'Enabled - no authentication required' -ShowiLOIPDuringPOST Enabled `
 -ShowServerHealthOnExternalMonitor Enabled -VGAPortDetectOverride Disabled -VirtualNICEnabled Enabled -AcceptThirdPartyFirmwareUpdates Enabled -TrapSourceIdentifier 'OS hostname' -SNMPv1Request Enabled -SNMPv1Trap Disabled `
 -SNMPv3Request Enabled -SNMPv3Trap Enabled -ColdStartTrap Disabled -PeriodicHSATrapConfiguration Monthly -SNMPSettingsSystemLocation 'My Location' -SNMPSettingsSystemContact 'Chris' -SNMPSettingsSystemRole 'Administrator' `
 -SNMPSettingsSystemRoleDetails "Admin role" -SNMPSettingsReadCommunity1 'ReadCommunity1' -SNMPSettingsReadCommunity2 'ReadCommunity2' -SNMPSettingsReadCommunity3 'ReadCommunity3' -SNMPv3EngineID '0x01020304abcdef' `
 -SNMPv3InformRetry 2 -SNMPv3InformRetryInterval 15 -SNMPv3User1UserName 'Chris' -SNMPv3User1AuthenticationProtocol 'MD5' -SNMPv3User1AuthenticationPassphrase  $SNMPv3User1authPass -SNMPv3User1PrivacyPassphrase $SNMPv3User1privPass `
 -SNMPv3User1EngineID '0x01020304abcdef' -SNMPv3User2UserName 'John' -SNMPv3User2AuthenticationProtocol 'SHA256' -SNMPv3User2AuthenticationPassphrase $SNMPv3User2authPass `
 -SNMPv3User2PrivacyPassphrase $SNMPv3User2privPass -SNMPv3User2EngineID '0x01020304abcdef' -GlobalComponentIntegrityCheck Disabled -GlobalComponentIntegrityPolicy 'Halt boot on SPDM failure'

This example updates the iLO settings configuration named "ILO_config_for_Gen12" in the "eu-central" region.
It sets a new name, description, and customizes various iLO settings including account service, network protocols, SNMP settings, and security service. 
It demonstrates the use of multiple parameters to configure a comprehensive iLO settings profile.

.EXAMPLE
Set-HPECOMSettingiLOSettings -Region eu-central -Name "ILO_config_for_Gen12" -SNMPv3User2UserName "" -SNMPAlertDestination3 "" -SNMPSettingsReadCommunity3 ""

This example updates the iLO settings configuration named "ILO_config_for_Gen12" in the "eu-central" region.
It removes SNMPv3 user 2, SNMP alert destination 3, and the third SNMP read community by setting their values to empty strings. All other settings remain unchanged.

.EXAMPLE
Get-HPECOMSetting -Region eu-central -Name "ILO_config_for_Gen12" | Set-HPECOMSettingiLOSettings -VirtualMedia Disabled -PasswordComplexity Enabled -AcceptThirdPartyFirmwareUpdates Disabled

This example demonstrates how to update multiple properties of the iLO settings configuration named "ILO_config_for_Gen12" in the "eu-central" region. 
It disables virtual media, enables password complexity, and disables acceptance of third-party firmware updates.

.INPUTS
System.Collections.ArrayList
List of iLO server settings from 'Get-HPECOMSetting -Category IloSettings'.

.OUTPUTS
System.Collections.ArrayList
A custom status object or array of objects containing:
    * Name      - The name of the iLO settings configuration
    * Region    - The region name
    * Status    - Status of the creation attempt (Failed, Complete, or Warning)
    * Details   - More information about the status
    * Exception - Any exception information

.NOTES
If you specify SNMPv3 user or SNMP alert destination parameters, all required related parameters must also be provided.
#>

    [CmdletBinding()]
    Param( 
    [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Default')]
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

    [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Default')]
    [ValidateScript({ $_.Length -le 100 })]
    [String]$Name,  

    [ValidateScript({ $_.Length -le 100 })]        
    [String]$NewName,
        
    [ValidateScript({ $_.Length -le 1000 })]
    [Parameter(ParameterSetName = 'Default')]
    [String]$Description,    
        
    # ACCOUNT SERVICE
    [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('EveryFailureCausesDelay', '1FailureCausesNoDelay', '3FailuresCauseNoDelay', '5FailuresCausesNoDelay')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('EveryFailureCausesDelay', '1FailureCausesNoDelay', '3FailuresCauseNoDelay', '5FailuresCausesNoDelay')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$AccountServiceAuthenticationFailureBeforeDelay,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('2', '5', '10', '30')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('2', '5', '10', '30')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$AccountServiceAuthenticationFailureDelayTimeInSeconds,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled - every failure', 'Enabled - every 2nd failure', 'Enabled - every 3rd failure', 'Enabled - every 5th failure', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled - every failure', 'Enabled - every 2nd failure', 'Enabled - every 3rd failure', 'Enabled - every 5th failure', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$AccountServiceAuthenticationFailureLogging,

    [ValidateScript({ $_ -ge 0 -and $_ -le 39 })]
    [Parameter(ParameterSetName = 'Default')]
    [Int]$AccountServicePasswordMinimumLength,  

        # The password complexity setting specifies the complexity requirements for user account passwords.
        # When enabled, new or updated user account passwords must include three of the following characteristics:
        # At least one uppercase ASCII character
        # At least one lowercase ASCII character
        # At least one ASCII digit
        # At least one other type of character (for example, a symbol, special character, or punctuation)
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$AccountServicePasswordComplexity,

        # NETWORK
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$PasswordComplexity,

        # NETWORK
        # Anonymous data—This setting controls the following:
        # - The XML object iLO provides in response to an anonymous request for basic system information.
        # - The information provided in response to an anonymous Redfish call to /redfish/v1.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$AnonymousData,

        # IPMI/DCMI over LAN—Allows you to send industry-standard IPMI and DCMI commands over the LAN to a specified port.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$IPMIDCMIOverLAN = "Disabled",
                
    [Parameter(ParameterSetName = 'Default')]
    [String]$IPMIDCMIOverLANPort = "623",

        # Remote console — Allows you to enable or disable access through the iLO remote console.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$RemoteConsole = "Enabled",

    [Parameter(ParameterSetName = 'Default')]
    [String]$RemoteConsolePort = "17990",


        # Secure shell (SSH)—Allows you to enable or disable the SSH feature.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SSH = "Enabled",

    [Parameter(ParameterSetName = 'Default')]
    [String]$SSHPort = "22",

        # SNMP—Specifies whether iLO responds to external SNMP requests.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMP = "Enabled",

    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPPort = "161",

    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPTrapPort = "162",

        # Virtual media—Allows you to enable or disable the iLO virtual media feature.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$VirtualMedia = "Enabled",

    [Parameter(ParameterSetName = 'Default')]
    [String]$VirtualMediaPort = "17988",

        # Virtual serial port log over CLI—Enables or disables logging of the virtual serial port that you can view by using the CLI.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$VirtualSerialPortLogOverCLI,

        # Web server (iLO 5 and iLO 6)—Allows you to enable or disable access through the iLO web server.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$WebServerSSL = "Enabled",

    [Parameter(ParameterSetName = 'Default')]
    [String]$WebServerSSLPort = "443",

    # REMOVED AS IT ALSO DISABLES HTTPS SO WEB GUI ACCESS IS LOST
    ##########################################################################################
    #     # Web server non-SSL port enabled (iLO 5 and iLO 6)—Enables or disables the HTTP port.
    #     [ArgumentCompleter({
    #             param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    #             $Values = @('Enabled', 'Disabled')
    #             $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
    #             return $FilteredValues | ForEach-Object {
    #                 [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    #             }
    #         })] 
    # [ValidateSet ('Enabled', 'Disabled')]
    # [Parameter(ParameterSetName = 'Default')]
    # [String]$WebServerNonSSL = "Enabled",
        
    # [Parameter(ParameterSetName = 'Default')]
    # [String]$WebServerNonSSLPort = "80",

        # ILO
        # Downloadable virtual serial port log—Enables or disables logging of the virtual serial port to a file that you can download through the iLO web interface.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$DownloadableVirtualSerialPortLog,

        # Idle connection timeout—Specifies how long iLO sessions can be inactive before they end automatically.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Disabled', '15', '30', '60', '120')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Disabled', '15', '30', '60', '120')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$IdleConnectionTimeoutinMinutes,

        # iLO RIBCL interface (iLO 5 and iLO 6)—Specifies whether RIBCL commands can be used to communicate with iLO.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$iLORIBCLInterface,

        # iLO ROM setup utility—Enables or disables the iLO configuration options in the UEFI System Utilities.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$iLOROMSetupUtility,

        # iLO web interface—Specifies whether the iLO web interface can be used to communicate with iLO.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$iLOWebInterface,

        # Remote console thumbnail—Enables or disables the display of the remote console thumbnail image in iLO.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$iLORemoteConsoleThumbnail,

        # Requires host authentication (iLO 5 and iLO 6)—Determines whether iLO user credentials are required to use host-based configuration utilities that access the management processor. 
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$iLOHostAuthRequired,

        # Require login for iLO RBSU (iLO 5 and iLO 6)—Determines whether user credentials are required when a user accesses the iLO configuration options in the UEFI System Utilities.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$iLORBSULoginRequired,

        # Serial command line interface speed (iLO 5 and iLO 6)—Enables you to change the speed of the serial port for the CLI feature.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('115200', '57600', '38400', '19200', '9600')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('115200', '57600', '38400', '19200', '9600')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SerialCommandLineInterfaceSpeed = "9600",


        # Serial command line interface status (iLO 5 and iLO 6)—Enables you to change the login model of the CLI feature through the serial port.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled - authentication required', 'Enabled - no authentication required', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled - authentication required', 'Enabled - no authentication required', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SerialCommandLineInterfaceStatus,

        # Show iLO IP during POST—Enables the display of the iLO network IP address during host server POST.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$ShowiLOIPDuringPOST,

        # Show server health on external monitor—Enables the display of the Server Health Summary screen on an external monitor.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$ShowServerHealthOnExternalMonitor,

        # VGA port detect override (iLO 5)—Controls how devices connected to the system video port are detected. Dynamic detection protects the system from abnormal port voltages.
        # This setting is not supported on Synergy compute modules.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$VGAPortDetectOverride,
        
        # Virtual NIC enabled—Determines whether you can use a virtual NIC over the USB subsystem to access iLOiLO from the host operating system.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$VirtualNICEnabled,

        # UPDATE SERVICE
        # Accept 3rd party firmware update packages—Specifies whether iLO will accept third-party firmware update packages that are not digitally signed. Platform Level Data Model (PLDM) firmware packages are supported.
    [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$AcceptThirdPartyFirmwareUpdates,

        # SNMP SERVICE
        # Trap source identifier—Determines the host name that is used in the SNMP-defined sysName variable when iLO generates SNMP traps.
        # The OS hostname is an OS construct. It does not remain persistent with the server when hard drives are moved to a new server platform. The iLO hostname, however, remains persistent with the system board.
    [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('OS hostname', 'iLO hostname')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('OS hostname', 'iLO hostname')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$TrapSourceIdentifier,

        # SNMPv1 request—Enables iLO to receive external SNMPv1 requests.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPv1Request,

        # SNMPv1 trap—Enables iLO to send SNMPv1 traps to the remote management systems configured in the alert destination.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPv1Trap,

        # SNMPv3 request—Enables iLO to receive external SNMPv3 requests.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPv3Request,

        # SNMPv3 trap—Enables iLO to send SNMPv3 traps to the remote management systems configured in the alert destination.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPv3Trap,

        # Cold start trap broadcast—The Cold Start Trap is broadcast to a subnet broadcast address when any of the following conditions is met:
        #    - SNMP Alert Destinations are not configured.
        #    - SNMP Alert Destinations are configured, but the SNMP protocol is disabled.
        #    - iLO failed to resolve all the SNMP Alert Destinations to IP addresses.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Enabled', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$ColdStartTrap,

        # Periodic HSA trap configuration—In the default configuration, iLO sends the health status array (HSA) trap only when a component status changes (for example, the fan status changed to failed).
        # Supported values: Daily, Weekly, Monthly, Disabled.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Daily', 'Weekly', 'Monthly', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
    [ValidateSet ('Daily', 'Weekly', 'Monthly', 'Disabled')]
    [Parameter(ParameterSetName = 'Default')]
    [String]$PeriodicHSATrapConfiguration,

        # System location—A string of up to 49 characters that specifies the physical location of the server.
    [ValidateScript({ $_.Length -le 49 })]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPSettingsSystemLocation,

        # System contact—A string of up to 49 characters that specifies the system administrator or server owner. The string can include a name, email address, or phone number.
    [ValidateScript({ $_.Length -le 49 })]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPSettingsSystemContact,

        # System role—A string of up to 64 characters that describes the server role or function.
    [ValidateScript({ $_.Length -le 64 })]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPSettingsSystemRole,

        # System role details—A string of up to 512 characters that describes specific tasks that the server might perform.
    [ValidateScript({ $_.Length -le 512 })]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPSettingsSystemRoleDetails,

        # Read community 1, Read community 2, and Read Community 3—The configured SNMP read-only community strings.
        # The following formats are supported:
        #     A community string (for example, public).
        #     A community string followed by an IP address or FQDN (for example, public 192.168.0.1).
        #     Use this option to specify that SNMP access will be allowed from the specified IP address or FQDN.
        #     You can enter an IPv4 address, an IPv6 address, or an FQDN.
    [ValidateScript({ $_.Length -le 64 })]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPSettingsReadCommunity1,    
 
    [ValidateScript({ $_.Length -le 64 })]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPSettingsReadCommunity2,    
 
    [ValidateScript({ $_.Length -le 64 })]
    [Parameter(ParameterSetName = 'Default')]
    [String]$SNMPSettingsReadCommunity3,

        # SNMPv3 SETTINGS
        # Engine ID—The unique identifier of an SNMP engine belonging to an SNMP agent entity.
        # This value must be a hexadecimal string of 6 to 48 characters, not counting the preceding 0x, 
        # and must be an even number of characters (for example, 0x01020304abcdef). 
        # If you do not configure this setting, the value is system-generated.
    [ValidatePattern('^0x[0-9A-Fa-f]{6,48}$')]
    [Parameter(ParameterSetName = 'Default')]
    [ValidateScript({
                $hexPart = $_.Substring(2)  # Remove '0x' prefix
                if ($hexPart.Length % 2 -ne 0) {
                    throw "Engine ID must have an even number of hex characters after '0x'"
                }
                return $true
            })]
        [String]$SNMPv3EngineID,

        # Inform retry—The number of times iLO will resend an alert if the receiver does not send an acknowledgment to iLO.
        # Supported values are 0 to 5.
        [ValidateScript({ $_ -ge 0 -and $_ -le 5 })]
    [Parameter(ParameterSetName = 'Default')]
    [Int]$SNMPv3InformRetry = 2,

        # Inform retry interval—The number of seconds between attempts to resend an SNMPv3 Inform alert.
        # Supported values are 1 to 120.
        [ValidateScript({ $_ -ge 1 -and $_ -le 120 })]
    [Parameter(ParameterSetName = 'Default')]
    [Int]$SNMPv3InformRetryInterval = 15,


        # SNMPv3 USERS
        
        # User 1

        # Security name—The user profile name. Enter an alphanumeric string of 1 to 32 characters.
        [ValidateNotNull()]
        [ValidateScript({ ($_ -eq "") -or ($_.Length -ge 1 -and $_.Length -le 32) })]
        [String]$SNMPv3User1UserName,        

        # Authentication protocol—Sets the message digest algorithm to use for encoding the authorization passphrase. The message digest is calculated over an appropriate portion of an SNMP message, and is included as part of the message sent to the recipient.
        # Supported values: MD5, SHA, SHA256.
        # If iLO is configured to use the FIPS or CNSA security state, MD5 is not supported.
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('MD5', 'SHA', 'SHA256')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('MD5', 'SHA', 'SHA256')]
        [String]$SNMPv3User1AuthenticationProtocol = 'SHA256',

        # Authentication passphrase—Sets the passphrase to use for sign operations.
        # Check value is not null

        [ValidateNotNull()]
        [System.Security.SecureString]$SNMPv3User1AuthenticationPassphrase,

        # Privacy passphrase—Sets the passphrase used for encrypt operations.
        [ValidateNotNull()]
        [System.Security.SecureString]$SNMPv3User1PrivacyPassphrase,

        # User engine ID—Sets the user engine ID for SNMPv3 Inform packets. This value is used only for creating remote accounts used with INFORM messages.
        # If this value is not set, INFORM messages are sent with the default value or the configured SNMPv3 Engine ID.
        # This value must be a hexadecimal string with an even number of 10 to 64 characters, excluding the first two characters, 0x.
        # For example: 0x01020304abcdef
        [ValidatePattern('^0x[0-9A-Fa-f]{10,64}$')]
        [ValidateScript({
                $hexPart = $_.Substring(2)  # Remove '0x' prefix
                if ($hexPart.Length % 2 -ne 0) {
                    throw "User Engine ID must have an even number of hex characters after '0x'"
                }
                return $true
            })]
        [String]$SNMPv3User1EngineID,

        # User 2
        
        # Security name—The user profile name. Enter an alphanumeric string of 1 to 32 characters.
        [ValidateScript({ ($_ -eq "") -or ($_.Length -ge 1 -and $_.Length -le 32) })]
        [String]$SNMPv3User2UserName,       

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('MD5', 'SHA', 'SHA256')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('MD5', 'SHA', 'SHA256')]
        [String]$SNMPv3User2AuthenticationProtocol = 'SHA256',

        # Authentication passphrase—Sets the passphrase to use for sign operations.
        [ValidateNotNull()]
        [System.Security.SecureString]$SNMPv3User2AuthenticationPassphrase,

        # Privacy passphrase—Sets the passphrase used for encrypt operations.
        [ValidateNotNull()]
        [System.Security.SecureString]$SNMPv3User2PrivacyPassphrase,

        # User engine ID—Sets the user engine ID for SNMPv3 Inform packets. This value is used only for creating remote accounts used with INFORM messages.
        # If this value is not set, INFORM messages are sent with the default value or the configured SNMPv3 Engine ID.
        # This value must be a hexadecimal string with an even number of 10 to 64 characters, excluding the first two characters, 0x.
        # For example: 0x01020304abcdef
        [ValidatePattern('^0x[0-9A-Fa-f]{10,64}$')]
        [ValidateScript({
                $hexPart = $_.Substring(2)  # Remove '0x' prefix
                if ($hexPart.Length % 2 -ne 0) {
                    throw "User Engine ID must have an even number of hex characters after '0x'"
                }
                return $true
            })]
        [String]$SNMPv3User2EngineID,

        # SNMP ALERT DESTINATIONS       

        # Destination—The IP address or FQDN of a management system that will receive SNMP alerts from iLO. This value can be up to 255 characters.
        # When SNMP Alert Destinations are configured using FQDNs, and DNS provides both IPv4 and IPv6 addresses for the FQDNs, iLO sends traps to the address specified by the iLO Client Applications use IPv6 first setting on the IPv6 page. If iLO Client Applications use IPv6 first is enabled, traps will be sent to IPv6 addresses (when available). When iLO Client Applications use IPv6 first is disabled, traps will be sent to IPv4 addresses (when available).
        [ValidateScript({ $_.Length -le 255 })]
        [String]$SNMPAlertDestination1,

        # Trap community—The configured SNMP trap community string.
        [ValidateScript({ $_.Length -le 64 })]
        [String]$SNMPTrapCommunityForDestination1,
       
        # SNMP protocol—The SNMP protocol to use with the configured alert destination (SNMPv1 Trap, SNMPv3 Trap, or SNMPv3 Inform).
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('SNMPv1 Trap', 'SNMPv3 Trap', 'SNMPv3 Inform')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('SNMPv1 Trap', 'SNMPv3 Trap', 'SNMPv3 Inform')]
        [String]$SNMPProtocolForDestination1,

        [String]$SNMPv3UserForDestination1,
       
        [ValidateScript({ $_.Length -le 255 })]
        [String]$SNMPAlertDestination2,

        [ValidateScript({ $_.Length -le 64 })]
        [String]$SNMPTrapCommunityForDestination2,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('SNMPv1 Trap', 'SNMPv3 Trap', 'SNMPv3 Inform')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('SNMPv1 Trap', 'SNMPv3 Trap', 'SNMPv3 Inform')]
        [String]$SNMPProtocolForDestination2,

        [String]$SNMPv3UserForDestination2,
       
        [ValidateScript({ $_.Length -le 255 })]
        [String]$SNMPAlertDestination3,

        [ValidateScript({ $_.Length -le 64 })]
        [String]$SNMPTrapCommunityForDestination3,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('SNMPv1 Trap', 'SNMPv3 Trap', 'SNMPv3 Inform')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('SNMPv1 Trap', 'SNMPv3 Trap', 'SNMPv3 Inform')]
        [String]$SNMPProtocolForDestination3,

        [String]$SNMPv3UserForDestination3,

        # SECURITY SERVICES
        # Global component integrity check (iLO 6 and iLO 7)—Enables or disables authentication of all applicable components in the server by using SPDM (Security Protocol and Data Model).
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('Enabled', 'Disabled')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Enabled', 'Disabled')]
        [String]$GlobalComponentIntegrityCheck,

        # Global integrity policy - No policy or Halt boot on SPDM failure
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Values = @('No policy', 'Halt boot on SPDM failure')
                $FilteredValues = $Values | Where-Object { $_ -like "$wordToComplete*" }
                return $FilteredValues | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('No policy', 'Halt boot on SPDM failure')]
        [String]$GlobalComponentIntegrityPolicy = 'No policy',

    [Parameter(ParameterSetName = 'Default')]
    [Switch]$WhatIf
       
    ) 
    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-COMSettingsUri
        $SetiLOServerSettingStatus = [System.Collections.ArrayList]::new()

        # Custom validation for SNMPv3User1 block (when a user is added, AuthenticationPassphrase and Privacy passphrase must be provided)
        if (($SNMPv3User1UserName -and -not $PSBoundParameters.ContainsKey('SNMPv3User1AuthenticationPassphrase')) -or ($SNMPv3User1UserName -and -not $PSBoundParameters.ContainsKey('SNMPv3User1PrivacyPassphrase'))) {
            throw "If you use -SNMPv3User1UserName, you must also provide -SNMPv3User1AuthenticationPassphrase and -SNMPv3User1PrivacyPassphrase."
        }

        if (($PSBoundParameters.ContainsKey('SNMPv3User1AuthenticationPassphrase') -and -not $SNMPv3User1UserName) -or ($PSBoundParameters.ContainsKey('SNMPv3User1PrivacyPassphrase') -and -not $SNMPv3User1UserName) -or ($PSBoundParameters.ContainsKey('SNMPv3User1EngineID') -and -not $SNMPv3User1UserName) -or ($PSBoundParameters.ContainsKey('SNMPv3User1AuthenticationProtocol') -and -not $SNMPv3User1UserName)) {
            throw "If you use -SNMPv3User1AuthenticationPassphrase or -SNMPv3User1PrivacyPassphrase or -SNMPv3User1EngineID or -SNMPv3User1AuthenticationProtocol, you must also provide -SNMPv3User1UserName."
        }

        # Only convert SecureString if not null
        if ($PSBoundParameters.ContainsKey('SNMPv3User1AuthenticationPassphrase')) {
            $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SNMPv3User1AuthenticationPassphrase)
            $SNMPv3User1AuthenticationPassphrasePlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($Ptr)
        }

        if ($PSBoundParameters.ContainsKey('SNMPv3User1PrivacyPassphrase')) {
            $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SNMPv3User1PrivacyPassphrase)
            $SNMPv3User1PrivacyPassphrasePlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($Ptr)
        }
        
        # Custom validation for SNMPv3User2 block (when a user is added, AuthenticationPassphrase and Privacy passphrase must be provided)
        if (($SNMPv3User2UserName -and -not $PSBoundParameters.ContainsKey('SNMPv3User2AuthenticationPassphrase')) -or ($SNMPv3User2UserName -and -not $PSBoundParameters.ContainsKey('SNMPv3User2PrivacyPassphrase'))) {
            throw "If you use -SNMPv3User2UserName, you must also provide -SNMPv3User2AuthenticationPassphrase and -SNMPv3User2PrivacyPassphrase."
        }

        if (($PSBoundParameters.ContainsKey('SNMPv3User2AuthenticationPassphrase') -and -not $SNMPv3User2UserName) -or ($PSBoundParameters.ContainsKey('SNMPv3User2PrivacyPassphrase') -and -not $SNMPv3User2UserName) -or ($PSBoundParameters.ContainsKey('SNMPv3User2EngineID') -and -not $SNMPv3User2UserName) -or ($PSBoundParameters.ContainsKey('SNMPv3User2AuthenticationProtocol') -and -not $SNMPv3User2UserName)) {
            throw "If you use -SNMPv3User2AuthenticationPassphrase or -SNMPv3User2PrivacyPassphrase or -SNMPv3User2EngineID or -SNMPv3User2AuthenticationProtocol, you must also provide -SNMPv3User2UserName."
        }

        # Only convert SecureString if not null
        if ($PSBoundParameters.ContainsKey('SNMPv3User2AuthenticationPassphrase')) {
            $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SNMPv3User2AuthenticationPassphrase)
            $SNMPv3User2AuthenticationPassphrasePlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($Ptr)
        }
        if ($PSBoundParameters.ContainsKey('SNMPv3User2PrivacyPassphrase')) {
            $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SNMPv3User2PrivacyPassphrase)
            $SNMPv3User2PrivacyPassphrasePlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($Ptr)
        }

        # Custom validation for SNMPTrapDest1 block
        if ($PSBoundParameters.ContainsKey('SNMPAlertDestination1') -and $SNMPAlertDestination1 -ne "" -and -not $SNMPTrapCommunityForDestination1){
            throw "If you use -SNMPAlertDestination1, you must also provide -SNMPTrapCommunityForDestination1."
        }
        if ($PSBoundParameters.ContainsKey('SNMPAlertDestination1') -and $SNMPAlertDestination1 -ne "" -and -not $SNMPProtocolForDestination1) {
            throw "If you use -SNMPAlertDestination1, you must also provide -SNMPProtocolForDestination1."
        }
        if ($SNMPTrapCommunityForDestination1 -and -not $SNMPAlertDestination1) {
            throw "If you use -SNMPTrapCommunityForDestination1, you must also provide -SNMPAlertDestination1."
        }
        if ($SNMPTrapCommunityForDestination1 -and -not $SNMPProtocolForDestination1) {
            throw "If you use -SNMPTrapCommunityForDestination1, you must also provide -SNMPProtocolForDestination1."
        }
        if ($SNMPProtocolForDestination1 -and -not $SNMPTrapCommunityForDestination1) {
            throw "If you use -SNMPProtocolForDestination1, you must also provide -SNMPTrapCommunityForDestination1."
        }
        if ($SNMPProtocolForDestination1 -and -not $SNMPAlertDestination1) {
            throw "If you use -SNMPProtocolForDestination1, you must also provide -SNMPAlertDestination1."
        }
        if (($SNMPProtocolForDestination1 -eq "SNMPv3 Trap" -or $SNMPProtocolForDestination1 -eq "SNMPv3 Inform") -and -not $SNMPv3UserForDestination1) {
            throw "If you use -SNMPProtocolForDestination1 with SNMP v3, you must also provide -SNMPv3UserForDestination1."
        }   

        # Custom validation for SNMPTrapDest2 block
        if ($PSBoundParameters.ContainsKey('SNMPAlertDestination2') -and $SNMPAlertDestination2 -ne "" -and -not $SNMPTrapCommunityForDestination2){
            throw "If you use -SNMPAlertDestination2, you must also provide -SNMPTrapCommunityForDestination2."
        }
        if ($PSBoundParameters.ContainsKey('SNMPAlertDestination2') -and $SNMPAlertDestination2 -ne "" -and -not $SNMPProtocolForDestination2) {
            throw "If you use -SNMPAlertDestination2, you must also provide -SNMPProtocolForDestination2."
        }
        if ($SNMPTrapCommunityForDestination2 -and -not $SNMPAlertDestination2) {
            throw "If you use -SNMPTrapCommunityForDestination2, you must also provide -SNMPAlertDestination2."
        }
        if ($SNMPTrapCommunityForDestination2 -and -not $SNMPProtocolForDestination2) {
            throw "If you use -SNMPTrapCommunityForDestination2, you must also provide -SNMPProtocolForDestination2."
        }
        if ($SNMPProtocolForDestination2 -and -not $SNMPTrapCommunityForDestination2) {
            throw "If you use -SNMPProtocolForDestination2, you must also provide -SNMPTrapCommunityForDestination2."
        }
        if ($SNMPProtocolForDestination2 -and -not $SNMPAlertDestination2) {
            throw "If you use -SNMPProtocolForDestination2, you must also provide -SNMPAlertDestination2."
        }
        if (($SNMPProtocolForDestination2 -eq "SNMPv3 Trap" -or $SNMPProtocolForDestination2 -eq "SNMPv3 Inform") -and -not $SNMPv3UserForDestination2) {
            throw "If you use -SNMPProtocolForDestination2 with SNMP v3, you must also provide -SNMPv3UserForDestination2."
        }        

        # Custom validation for SNMPTrapDest3 block
        if ($PSBoundParameters.ContainsKey('SNMPAlertDestination3') -and $SNMPAlertDestination3 -ne "" -and -not $SNMPTrapCommunityForDestination3){
            throw "If you use -SNMPAlertDestination3, you must also provide -SNMPTrapCommunityForDestination3."
        }
        if ($PSBoundParameters.ContainsKey('SNMPAlertDestination3') -and $SNMPAlertDestination3 -ne "" -and -not $SNMPProtocolForDestination3) {
            throw "If you use -SNMPAlertDestination3, you must also provide -SNMPProtocolForDestination3."
        }
        if ($SNMPTrapCommunityForDestination3 -and -not $SNMPAlertDestination3) {
            throw "If you use -SNMPTrapCommunityForDestination3, you must also provide -SNMPAlertDestination3."
        }
        if ($SNMPTrapCommunityForDestination3 -and -not $SNMPProtocolForDestination3) {
            throw "If you use -SNMPTrapCommunityForDestination3, you must also provide -SNMPProtocolForDestination3."
        }
        if ($SNMPProtocolForDestination3 -and -not $SNMPTrapCommunityForDestination3) {
            throw "If you use -SNMPProtocolForDestination3, you must also provide -SNMPTrapCommunityForDestination3."
        }
        if ($SNMPProtocolForDestination3 -and -not $SNMPAlertDestination3) {
            throw "If you use -SNMPProtocolForDestination3, you must also provide -SNMPAlertDestination3."
        }
        if (($SNMPProtocolForDestination3 -eq "SNMPv3 Trap" -or $SNMPProtocolForDestination3 -eq "SNMPv3 Inform") -and -not $SNMPv3UserForDestination3) {
            throw "If you use -SNMPProtocolForDestination3 with SNMP v3, you must also provide -SNMPv3UserForDestination3."
        }  
         
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
            $ExistingSettingResource = Get-HPECOMSetting -Region $Region -Name $Name -Category IloSettings
            $SettingID = $ExistingSettingResource.id

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)

        }

        if (-not $ExistingSettingResource) {

            "[{0}] Setting '{1}' is not present in the '{2}' region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
    
            if ($WhatIf) {
                $ErrorMessage = "Setting '{0}': Resource cannot be found in the '{1}' region!" -f $Name, $Region
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "Setting cannot be found in the region!"
            }

        }
        else {

            $Uri = (Get-COMSettingsUri) + "/" + $SettingID
             
            # Conditionally add properties
            if ($NewName) {
                $Name = $NewName
            }

            if (-not $PSBoundParameters.ContainsKey('Description')) {
        
                if ($ExistingSettingResource.description) {
                            
                    $Description = $ExistingSettingResource.description
                }
                else {
                    $Description = $Null
                }
            }     
            

            # Build the payload with the provided parameters

            #Region ACCOUNT SERVICE ########################################
            $AccountService = @{}

            if (-not $PSBoundParameters.ContainsKey('AccountServiceAuthenticationFailureBeforeDelay')) { 
                if ($ExistingSettingResource.settings.Default.AccountService.AuthFailuresBeforeDelay) {
                     $AccountService['AuthFailuresBeforeDelay'] = $ExistingSettingResource.settings.Default.AccountService.AuthFailuresBeforeDelay
                }
            }
            else {
                $AccountServiceAuthenticationFailureBeforeDelayValue = 
                switch ($AccountServiceAuthenticationFailureBeforeDelay) {
                    'EveryFailureCausesDelay' { 0 }
                    '1FailureCausesNoDelay' { 1 }
                    '3FailuresCauseNoDelay' { 3 }
                    '5FailuresCausesNoDelay' { 5 }
                    Default { 
                        Throw "Invalid value for AccountServiceAuthenticationFailureBeforeDelay: $AccountServiceAuthenticationFailureBeforeDelay"
                    }   
                }

                $AccountService['AuthFailuresBeforeDelay'] = [int]$AccountServiceAuthenticationFailureBeforeDelayValue
            }

            if (-not $PSBoundParameters.ContainsKey('AccountServiceAuthenticationFailureDelayTimeInSeconds')) { 
                if ($ExistingSettingResource.settings.Default.AccountService.AuthFailureDelayTimeSeconds) {
                     $AccountService['AuthFailureDelayTimeSeconds'] = $ExistingSettingResource.settings.Default.AccountService.AuthFailureDelayTimeSeconds
                }
            }
            else {
                $AccountService['AuthFailureDelayTimeSeconds'] = [int]$AccountServiceAuthenticationFailureDelayTimeInSeconds
            }

            if (-not $PSBoundParameters.ContainsKey('AccountServiceAuthenticationFailureLogging')) { 
                if ($ExistingSettingResource.settings.Default.AccountService.AuthFailureLoggingThreshold) {
                     $AccountService['AuthFailureLoggingThreshold'] = $ExistingSettingResource.settings.Default.AccountService.AuthFailureLoggingThreshold
                }
            }
            else {
                $AccountServiceAuthenticationFailureLoggingValue = 
                switch ($AccountServiceAuthenticationFailureLogging) {
                    'Disabled' { 0 }
                    'Enabled - every failure' { 1 }
                    'Enabled - every 2nd failure' { 2 }
                    'Enabled - every 3rd failure' { 3 }
                    'Enabled - every 4th failure' { 4 }
                    'Enabled - every 5th failure' { 5 }
                    Default { 
                        Throw "Invalid value for AccountServiceAuthenticationFailureLogging: $AccountServiceAuthenticationFailureLogging"
                    }   
                }

                $AccountService['AuthFailureLoggingThreshold'] = [int]$AccountServiceAuthenticationFailureLoggingValue
            }

            if (-not $PSBoundParameters.ContainsKey('AccountServicePasswordMinimumLength')) { 
                if ($ExistingSettingResource.settings.Default.AccountService.MinPasswordLength) {
                     $AccountService['MinPasswordLength'] = $ExistingSettingResource.settings.Default.AccountService.MinPasswordLength
                }
            }
            else {
                $AccountService['MinPasswordLength'] = [int]$AccountServicePasswordMinimumLength
            }

            if (-not $PSBoundParameters.ContainsKey('AccountServicePasswordComplexity')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.AccountService.EnforcePasswordComplexity) {
                     $AccountService['EnforcePasswordComplexity'] = $ExistingSettingResource.settings.Default.AccountService.EnforcePasswordComplexity
                }
            }
            else {
                $AccountServicePasswordComplexityValue = 
                switch ($AccountServicePasswordComplexity) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for AccountServicePasswordComplexity: $AccountServicePasswordComplexity"
                    }   
                }
                $AccountService['EnforcePasswordComplexity'] = $AccountServicePasswordComplexityValue
            }

            #EndRegion

            #Region NETWORK PROTOCOL #######################################

            $NetworkProtocol = @{}

            if (-not $PSBoundParameters.ContainsKey('AnonymousData')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.NetworkProtocol.XMLResponseEnabled) {
                    $NetworkProtocol['XMLResponseEnabled'] = $ExistingSettingResource.settings.Default.NetworkProtocol.XMLResponseEnabled
                }
            }
            else {
                $AnonymousDataValue = 
                switch ($AnonymousData) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for AnonymousData: $AnonymousData"
                    }   
                }
                $NetworkProtocol['XMLResponseEnabled'] = $AnonymousDataValue
            }

            if (-not $PSBoundParameters.ContainsKey('IPMIDCMIOverLAN')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.NetworkProtocol.IPMI.ProtocolEnabled) {
                    if (-not $NetworkProtocol.ContainsKey('IPMI')) {
                        $NetworkProtocol['IPMI'] = @{}
                    }
                    $NetworkProtocol['IPMI']['ProtocolEnabled'] = $ExistingSettingResource.settings.Default.NetworkProtocol.IPMI.ProtocolEnabled
                }
            }
            else {
                $IPMIDCMIOverLANValue = 
                switch ($IPMIDCMIOverLAN) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for IPMIDCMIOverLAN: $IPMIDCMIOverLAN"
                    }   
                }
                if (-not $NetworkProtocol.ContainsKey('IPMI')) {
                    $NetworkProtocol['IPMI'] = @{}
                }
                $NetworkProtocol['IPMI']['ProtocolEnabled'] = $IPMIDCMIOverLANValue
            }
        

            # $IPMIDCMIOverLANPort
            if (-not $PSBoundParameters.ContainsKey('IPMIDCMIOverLANPort')) { 
                if ($ExistingSettingResource.settings.Default.NetworkProtocol.IPMI.Port) {
                    if (-not $NetworkProtocol.ContainsKey('IPMI')) {
                        $NetworkProtocol['IPMI'] = @{}
                    }
                    $NetworkProtocol['IPMI']['Port'] = $ExistingSettingResource.settings.Default.NetworkProtocol.IPMI.Port
                }
            }
            else {
                if (-not $NetworkProtocol.ContainsKey('IPMI')) {
                    $NetworkProtocol['IPMI'] = @{}
                }
                $NetworkProtocol['IPMI']['Port'] = [int]$IPMIDCMIOverLANPort
            }

            # $RemoteConsole
            if (-not $PSBoundParameters.ContainsKey('RemoteConsole')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.NetworkProtocol.KVMIP.ProtocolEnabled) {
                    if (-not $NetworkProtocol.ContainsKey('KVMIP')) {
                        $NetworkProtocol['KVMIP'] = @{}
                    }
                    $NetworkProtocol['KVMIP']['ProtocolEnabled'] = $ExistingSettingResource.settings.Default.NetworkProtocol.KVMIP.ProtocolEnabled
                }
            }
            else {
                $RemoteConsoleValue = 
                switch ($RemoteConsole) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for RemoteConsole: $RemoteConsole"
                    }   
                }

                if (-not $NetworkProtocol.ContainsKey('KVMIP')) {
                    $NetworkProtocol['KVMIP'] = @{}
                }
                $NetworkProtocol['KVMIP']['ProtocolEnabled'] = $RemoteConsoleValue
            }

            # $RemoteConsolePort
            if (-not $PSBoundParameters.ContainsKey('RemoteConsolePort')) { 
                if ($ExistingSettingResource.settings.Default.NetworkProtocol.KVMIP.Port) {
                    if (-not $NetworkProtocol.ContainsKey('KVMIP')) {
                        $NetworkProtocol['KVMIP'] = @{}
                    }
                    $NetworkProtocol['KVMIP']['Port'] = $ExistingSettingResource.settings.Default.NetworkProtocol.KVMIP.Port
                }
            }
            else {
                if (-not $NetworkProtocol.ContainsKey('KVMIP')) {
                    $NetworkProtocol['KVMIP'] = @{}
                }
                $NetworkProtocol['KVMIP']['Port'] = [int]$RemoteConsolePort
            }

            # $SSH
            if (-not $PSBoundParameters.ContainsKey('SSH')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.NetworkProtocol.SSH.ProtocolEnabled) {
                    if (-not $NetworkProtocol.ContainsKey('SSH')) {
                        $NetworkProtocol['SSH'] = @{}
                    }
                    $NetworkProtocol['SSH']['ProtocolEnabled'] = $ExistingSettingResource.settings.Default.NetworkProtocol.SSH.ProtocolEnabled
                }
            }
            else {
                $SSHValue = 
                switch ($SSH) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for SSH: $SSH"
                    }   
                }
                if (-not $NetworkProtocol.ContainsKey('SSH')) {
                    $NetworkProtocol['SSH'] = @{}
                }
                $NetworkProtocol['SSH']['ProtocolEnabled'] = $SSHValue
            }

            # $SSHPort
            if (-not $PSBoundParameters.ContainsKey('SSHPort')) { 
                if ($ExistingSettingResource.settings.Default.NetworkProtocol.SSH.Port) {
                    if (-not $NetworkProtocol.ContainsKey('SSH')) {
                        $NetworkProtocol['SSH'] = @{}
                    }
                    $NetworkProtocol['SSH']['Port'] = $ExistingSettingResource.settings.Default.NetworkProtocol.SSH.Port
                }
            }
            else {
                if (-not $NetworkProtocol.ContainsKey('SSH')) {
                    $NetworkProtocol['SSH'] = @{}
                }
                $NetworkProtocol['SSH']['Port'] = [int]$SSHPort
            }

            # $SNMP
            if (-not $PSBoundParameters.ContainsKey('SNMP')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.NetworkProtocol.SNMP.ProtocolEnabled) {
                    if (-not $NetworkProtocol.ContainsKey('SNMP')) {
                        $NetworkProtocol['SNMP'] = @{}
                    }
                    $NetworkProtocol['SNMP']['ProtocolEnabled'] = $ExistingSettingResource.settings.Default.NetworkProtocol.SNMP.ProtocolEnabled
                }
            }
            else {
                $SNMPValue = 
                switch ($SNMP) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for SNMP: $SNMP"
                    }   
                }
                if (-not $NetworkProtocol.ContainsKey('SNMP')) {
                    $NetworkProtocol['SNMP'] = @{}
                }
                $NetworkProtocol['SNMP']['ProtocolEnabled'] = $SNMPValue
            }

            # $SNMPPort
            if (-not $PSBoundParameters.ContainsKey('SNMPPort')) { 
                if ($ExistingSettingResource.settings.Default.NetworkProtocol.SNMP.Port) {
                    if (-not $NetworkProtocol.ContainsKey('SNMP')) {
                        $NetworkProtocol['SNMP'] = @{}
                    }
                    $NetworkProtocol['SNMP']['Port'] = $ExistingSettingResource.settings.Default.NetworkProtocol.SNMP.Port
                }
            }
            else {
                if (-not $NetworkProtocol.ContainsKey('SNMP')) {
                    $NetworkProtocol['SNMP'] = @{}
                }
                $NetworkProtocol['SNMP']['Port'] = [int]$SNMPPort
            }

            # $SNMPTrapPort
            if (-not $PSBoundParameters.ContainsKey('SNMPTrapPort')) { 
                if ($ExistingSettingResource.settings.Default.NetworkProtocol.SNMP.SNMPTrapPort) {
                    if (-not $NetworkProtocol.ContainsKey('SNMP')) {
                        $NetworkProtocol['SNMP'] = @{}
                    }
                    $NetworkProtocol['SNMP']['SNMPTrapPort'] = $ExistingSettingResource.settings.Default.NetworkProtocol.SNMP.SNMPTrapPort
                }
            }
            else {
                if (-not $NetworkProtocol.ContainsKey('SNMP')) {
                    $NetworkProtocol['SNMP'] = @{}
                }
                $NetworkProtocol['SNMP']['SNMPTrapPort'] = [int]$SNMPTrapPort
            }

            # $VirtualMedia
            if (-not $PSBoundParameters.ContainsKey('VirtualMedia')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.NetworkProtocol.VirtualMedia.ProtocolEnabled) {
                    if (-not $NetworkProtocol.ContainsKey('VirtualMedia')) {
                        $NetworkProtocol['VirtualMedia'] = @{}
                    }
                    $NetworkProtocol['VirtualMedia']['ProtocolEnabled'] = $ExistingSettingResource.settings.Default.NetworkProtocol.VirtualMedia.ProtocolEnabled
                }
            }
            else {
                $VirtualMediaValue = 
                switch ($VirtualMedia) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for VirtualMedia: $VirtualMedia"
                    }   
                }
                if (-not $NetworkProtocol.ContainsKey('VirtualMedia')) {
                    $NetworkProtocol['VirtualMedia'] = @{}
                }
                $NetworkProtocol['VirtualMedia']['ProtocolEnabled'] = $VirtualMediaValue
            }

            # $VirtualMediaPort
            if (-not $PSBoundParameters.ContainsKey('VirtualMediaPort')) { 
                if ($ExistingSettingResource.settings.Default.NetworkProtocol.VirtualMedia.Port) {
                    if (-not $NetworkProtocol.ContainsKey('VirtualMedia')) {
                        $NetworkProtocol['VirtualMedia'] = @{}
                    }
                    $NetworkProtocol['VirtualMedia']['Port'] = $ExistingSettingResource.settings.Default.NetworkProtocol.VirtualMedia.Port
                }
            }
            else {
                if (-not $NetworkProtocol.ContainsKey('VirtualMedia')) {
                    $NetworkProtocol['VirtualMedia'] = @{}
                }
                $NetworkProtocol['VirtualMedia']['Port'] = [int]$VirtualMediaPort
            }

            # $VirtualSerialPortLogOverCLI

            if (-not $PSBoundParameters.ContainsKey('VirtualSerialPortLogOverCLI')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.NetworkProtocol.SerialOverLanLogging) {
                    $NetworkProtocol['SerialOverLanLogging'] = $ExistingSettingResource.settings.Default.NetworkProtocol.SerialOverLanLogging
                }
            }
            else {
                $VirtualSerialPortLogOverCLIValue = 
                switch ($VirtualSerialPortLogOverCLI) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for VirtualSerialPortLogOverCLI: $VirtualSerialPortLogOverCLI"
                    }   
                }
                $NetworkProtocol['SerialOverLanLogging'] = $VirtualSerialPortLogOverCLIValue
            }

            # $WebServerSSL
            if (-not $PSBoundParameters.ContainsKey('WebServerSSL')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.NetworkProtocol.HTTPS.ProtocolEnabled) {
                    if (-not $NetworkProtocol.ContainsKey('HTTPS')) {
                        $NetworkProtocol['HTTPS'] = @{}
                    }
                    $NetworkProtocol['HTTPS']['ProtocolEnabled'] = $ExistingSettingResource.settings.Default.NetworkProtocol.HTTPS.ProtocolEnabled
                }
            }
            else {
                $WebServerSSLValue = 
                switch ($WebServerSSL) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for WebServerSSL: $WebServerSSL"
                    }   
                }
                if (-not $NetworkProtocol.ContainsKey('HTTPS')) {
                    $NetworkProtocol['HTTPS'] = @{}
                }
                $NetworkProtocol['HTTPS']['ProtocolEnabled'] = $WebServerSSLValue
            }

            # $WebServerSSLPort
            if (-not $PSBoundParameters.ContainsKey('WebServerSSLPort')) { 
                if ($ExistingSettingResource.settings.Default.NetworkProtocol.HTTPS.Port) {
                    if (-not $NetworkProtocol.ContainsKey('HTTPS')) {
                        $NetworkProtocol['HTTPS'] = @{}
                    }
                    $NetworkProtocol['HTTPS']['Port'] = $ExistingSettingResource.settings.Default.NetworkProtocol.HTTPS.Port
                }
            }
            else {
                if (-not $NetworkProtocol.ContainsKey('HTTPS')) {
                    $NetworkProtocol['HTTPS'] = @{}
                }
                $NetworkProtocol['HTTPS']['Port'] = [int]$WebServerSSLPort
            }

            # $WebServerNonSSL
            # if (-not $PSBoundParameters.ContainsKey('WebServerNonSSL')) { 
            #     if ($null -ne $ExistingSettingResource.settings.Default.NetworkProtocol.HTTP.Port) {
            #         if (-not $NetworkProtocol.ContainsKey('HTTP')) {
            #             $NetworkProtocol['HTTP'] = @{}
            #         }
            #         $NetworkProtocol['HTTP']['Port'] = $ExistingSettingResource.settings.Default.NetworkProtocol.HTTP.Port
            #     }
            # }
            # else {
            #     $WebServerNonSSLValue = 
            #     switch ($WebServerNonSSL) {
            #         'Disabled' { $false }
            #         'Enabled' { $true }
            #         Default { 
            #             Throw "Invalid value for WebServerNonSSL: $WebServerNonSSL"
            #         }   
            #     }
            #     if (-not $NetworkProtocol.ContainsKey('HTTP')) {
            #         $NetworkProtocol['HTTP'] = @{}
            #     }
            #     $NetworkProtocol['HTTP']['ProtocolEnabled'] = $WebServerNonSSLValue
            # }

            # # $WebServerNonSSLPort
            # if (-not $PSBoundParameters.ContainsKey('WebServerNonSSLPort')) { 
            #     if ($ExistingSettingResource.settings.Default.NetworkProtocol.HTTP.Port) {
            #         if (-not $NetworkProtocol.ContainsKey('HTTP')) {
            #             $NetworkProtocol['HTTP'] = @{}
            #         }
            #         $NetworkProtocol['HTTP']['Port'] = $ExistingSettingResource.settings.Default.NetworkProtocol.HTTP.Port
            #     }
            # }
            # else {
            #     if (-not $NetworkProtocol.ContainsKey('HTTP')) {
            #         $NetworkProtocol['HTTP'] = @{}
            #     }
            #     $NetworkProtocol['HTTP']['Port'] = [int]$WebServerNonSSLPort
            # }

            #EndRegion

            #Region ILO ####################################################
            $1 = @{}

            # $DownloadableVirtualSerialPortLog
            if (-not $PSBoundParameters.ContainsKey('DownloadableVirtualSerialPortLog')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.'1'.VSPLogDownloadEnabled) {

                    $1['VSPLogDownloadEnabled'] = $ExistingSettingResource.settings.Default.'1'.VSPLogDownloadEnabled
                }
            }
            else {
                $DownloadableVirtualSerialPortLogValue = 
                switch ($DownloadableVirtualSerialPortLog) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for DownloadableVirtualSerialPortLog: $DownloadableVirtualSerialPortLog"
                    }   
                }
                $1['VSPLogDownloadEnabled'] = $DownloadableVirtualSerialPortLogValue
            }

            # $IdleConnectionTimeoutinMinutes
            if (-not $PSBoundParameters.ContainsKey('IdleConnectionTimeoutinMinutes')) { 
                if ($ExistingSettingResource.settings.Default.'1'.IdleConnectionTimeoutMinutes) {

                    $1['IdleConnectionTimeoutMinutes'] = $ExistingSettingResource.settings.Default.'1'.IdleConnectionTimeoutMinutes
                }
            }
            else {
                $1['IdleConnectionTimeoutMinutes'] = [int]$IdleConnectionTimeoutinMinutes
            }

            # $iLORIBCLInterface
            if (-not $PSBoundParameters.ContainsKey('iLORIBCLInterface')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.'1'.RIBCLEnabled) {

                    $1['RIBCLEnabled'] = $ExistingSettingResource.settings.Default.'1'.RIBCLEnabled
                }
            }
            else {
                $iLORIBCLInterfaceValue =
                switch ($iLORIBCLInterface) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for iLORIBCLInterface: $iLORIBCLInterface"
                    }   
                }
                $1['RIBCLEnabled'] = $iLORIBCLInterfaceValue
            }

            # $iLOROMSetupUtility
            if (-not $PSBoundParameters.ContainsKey('iLOROMSetupUtility')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.'1'.iLORBSUEnabled) {

                    $1['iLORBSUEnabled'] = $ExistingSettingResource.settings.Default.'1'.iLORBSUEnabled
                }
            }
            else {
                $iLOROMSetupUtilityValue =
                switch ($iLOROMSetupUtility) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for iLOROMSetupUtility: $iLOROMSetupUtility"
                    }   
                }
                $1['iLORBSUEnabled'] = $iLOROMSetupUtilityValue
            }

            # $iLOWebInterface
            if (-not $PSBoundParameters.ContainsKey('iLOWebInterface')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.'1'.WebGuiEnabled) {

                    $1['WebGuiEnabled'] = $ExistingSettingResource.settings.Default.'1'.WebGuiEnabled
                }
            }
            else {            
                $iLOWebInterfaceValue =
                switch ($iLOWebInterface) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for iLOWebInterface: $iLOWebInterface"
                    }   
                }
                $1['WebGuiEnabled'] = $iLOWebInterfaceValue
            }

            # $iLORemoteConsoleThumbnail
            if (-not $PSBoundParameters.ContainsKey('iLORemoteConsoleThumbnail')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.'1'.RemoteConsoleThumbnailEnabled) {

                    $1['RemoteConsoleThumbnailEnabled'] = $ExistingSettingResource.settings.Default.'1'.RemoteConsoleThumbnailEnabled
                }
            }
            else {              
                $iLORemoteConsoleThumbnailValue =
                switch ($iLORemoteConsoleThumbnail) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for iLORemoteConsoleThumbnail: $iLORemoteConsoleThumbnail"
                    }   
                }
                $1['RemoteConsoleThumbnailEnabled'] = $iLORemoteConsoleThumbnailValue
            }

            # $iLOHostAuthRequired
            if (-not $PSBoundParameters.ContainsKey('iLOHostAuthRequired')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.'1'.RequireHostAuthentication) {

                    $1['RequireHostAuthentication'] = $ExistingSettingResource.settings.Default.'1'.RequireHostAuthentication
                }
            }
            else {                 
                $iLOHostAuthRequiredValue =
                switch ($iLOHostAuthRequired) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for iLOHostAuthRequired: $iLOHostAuthRequired"
                    }   
                }
                $1['RequireHostAuthentication'] = $iLOHostAuthRequiredValue
            }

            # $iLORBSULoginRequired
            if (-not $PSBoundParameters.ContainsKey('iLORBSULoginRequired')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.'1'.RequiredLoginForiLORBSU) {

                    $1['RequiredLoginForiLORBSU'] = $ExistingSettingResource.settings.Default.'1'.RequiredLoginForiLORBSU
                }
            }
            else {             
                $iLORBSULoginRequiredValue =
                switch ($iLORBSULoginRequired) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for iLORBSULoginRequired: $iLORBSULoginRequired"
                    }   
                }
                $1['RequiredLoginForiLORBSU'] = $iLORBSULoginRequiredValue
            }

            # $SerialCommandLineInterfaceSpeed
            if (-not $PSBoundParameters.ContainsKey('SerialCommandLineInterfaceSpeed')) { 
                if ($ExistingSettingResource.settings.Default.'1'.SerialCLISpeed) {

                    $1['SerialCLISpeed'] = $ExistingSettingResource.settings.Default.'1'.SerialCLISpeed
                }
            }
            else {        
                $1['SerialCLISpeed'] = [int]$SerialCommandLineInterfaceSpeed
            }

            # $SerialCommandLineInterfaceStatus
            if (-not $PSBoundParameters.ContainsKey('SerialCommandLineInterfaceStatus')) { 
                if ($ExistingSettingResource.settings.Default.'1'.SerialCLIStatus) {

                    $1['SerialCLIStatus'] = $ExistingSettingResource.settings.Default.'1'.SerialCLIStatus
                }
            }
            else {              
                $SerialCommandLineInterfaceStatusValue =
                switch ($SerialCommandLineInterfaceStatus) {
                    'Disabled' { 'Disabled' }
                    'Enabled - no authentication required' { 'EnabledNoAuth' }
                    'Enabled - authentication required' { 'EnabledAuthReq' }
                    Default { 
                        Throw "Invalid value for SerialCommandLineInterfaceStatus: $SerialCommandLineInterfaceStatus"
                    }   
                }
                $1['SerialCLIStatus'] = $SerialCommandLineInterfaceStatusValue
            }

            # $ShowiLOIPDuringPOST
            if (-not $PSBoundParameters.ContainsKey('ShowiLOIPDuringPOST')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.'1'.iLOIPduringPOSTEnabled) {

                    $1['iLOIPduringPOSTEnabled'] = $ExistingSettingResource.settings.Default.'1'.iLOIPduringPOSTEnabled
                }
            }
            else {               
                $ShowiLOIPDuringPOSTValue =
                switch ($ShowiLOIPDuringPOST) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for ShowiLOIPDuringPOST: $ShowiLOIPDuringPOST"
                    }   
                }
                $1['iLOIPduringPOSTEnabled'] = $ShowiLOIPDuringPOSTValue
            }

            # $ShowServerHealthOnExternalMonitor
            if (-not $PSBoundParameters.ContainsKey('ShowServerHealthOnExternalMonitor')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.'1'.PhysicalMonitorHealthStatusEnabled) {

                    $1['PhysicalMonitorHealthStatusEnabled'] = $ExistingSettingResource.settings.Default.'1'.PhysicalMonitorHealthStatusEnabled
                }
            }
            else {               
                $ShowServerHealthOnExternalMonitorValue =
                switch ($ShowServerHealthOnExternalMonitor) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for ShowServerHealthOnExternalMonitor: $ShowServerHealthOnExternalMonitor"
                    }   
                }
                $1['PhysicalMonitorHealthStatusEnabled'] = $ShowServerHealthOnExternalMonitorValue
            }

            # $VGAPortDetectOverride
            if (-not $PSBoundParameters.ContainsKey('VGAPortDetectOverride')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.'1'.VideoPresenceDetectOverride) {

                    $1['VideoPresenceDetectOverride'] = $ExistingSettingResource.settings.Default.'1'.VideoPresenceDetectOverride
                }
            }
            else {  
                $VGAPortDetectOverrideValue =
                switch ($VGAPortDetectOverride) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for VGAPortDetectOverride: $VGAPortDetectOverride"
                    }   
                }
                $1['VideoPresenceDetectOverride'] = $VGAPortDetectOverrideValue
            }

            # $VirtualNICEnabled
            if (-not $PSBoundParameters.ContainsKey('VirtualNICEnabled')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.'1'.VirtualNICEnabled) {

                    $1['VirtualNICEnabled'] = $ExistingSettingResource.settings.Default.'1'.VirtualNICEnabled
                }
            }
            else {             
                $VirtualNICEnabledValue =
                switch ($VirtualNICEnabled) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for VirtualNICEnabled: $VirtualNICEnabled"
                    }   
                }
                $1['VirtualNICEnabled'] = $VirtualNICEnabledValue
            }

            #EndRegion
          
            #Region UPDATE SERVICE #########################################
            $UpdateService = @{}

            # $AcceptThirdPartyFirmwareUpdates
            if (-not $PSBoundParameters.ContainsKey('AcceptThirdPartyFirmwareUpdates')) { 

                if ($null -ne $ExistingSettingResource.settings.Default.UpdateService.Accept3rdPartyFirmware) {
                    $UpdateService['Accept3rdPartyFirmware'] = [bool]$ExistingSettingResource.settings.Default.UpdateService.Accept3rdPartyFirmware
                }
            }
            else { 
                
                $AcceptThirdPartyFirmwareUpdatesValue =
                switch ($AcceptThirdPartyFirmwareUpdates) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for AcceptThirdPartyFirmwareUpdates: $AcceptThirdPartyFirmwareUpdates"
                    }   
                }
                $UpdateService['Accept3rdPartyFirmware'] = $AcceptThirdPartyFirmwareUpdatesValue
            }

            #EndRegion

            #Region SNMP SERVICE ###########################################

            $SNMPService = @{}

            # $TrapSourceIdentifier
            if (-not $PSBoundParameters.ContainsKey('TrapSourceIdentifier')) { 
                if ($ExistingSettingResource.settings.Default.SnmpService.TrapSourceHostname) {

                    $SNMPService['TrapSourceHostname'] = $ExistingSettingResource.settings.Default.SnmpService.TrapSourceHostname
                }
            }
            else {  
                $TrapSourceIdentifierValue =
                switch ($TrapSourceIdentifier) {
                    'OS hostname' { 'Manager' }
                    'iLO hostname' { 'System' }
                    Default { 
                        Throw "Invalid value for TrapSourceIdentifier: $TrapSourceIdentifier"
                    }   
                }
                $SNMPService['TrapSourceHostname'] = $TrapSourceIdentifierValue
            }

            # $SNMPv1Request
            if (-not $PSBoundParameters.ContainsKey('SNMPv1Request')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.SnmpService.SNMPv1RequestsEnabled) {

                    $SNMPService['SNMPv1RequestsEnabled'] = $ExistingSettingResource.settings.Default.SnmpService.SNMPv1RequestsEnabled
                }
            }
            else {  
                $SNMPv1RequestValue =
                switch ($SNMPv1Request) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for SNMPv1Request: $SNMPv1Request"
                    }   
                }
                $SNMPService['SNMPv1RequestsEnabled'] = $SNMPv1RequestValue
            }

            # $SNMPv1Trap
            if (-not $PSBoundParameters.ContainsKey('SNMPv1Trap')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.SnmpService.SNMPv1TrapEnabled) {

                    $SNMPService['SNMPv1TrapEnabled'] = $ExistingSettingResource.settings.Default.SnmpService.SNMPv1TrapEnabled
                }
            }
            else {  
                $SNMPv1TrapValue =
                switch ($SNMPv1Trap) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for SNMPv1Trap: $SNMPv1Trap"
                    }   
                }
                $SNMPService['SNMPv1TrapEnabled'] = $SNMPv1TrapValue
            }

            # $SNMPv3Request
            if (-not $PSBoundParameters.ContainsKey('SNMPv3Request')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.SnmpService.SNMPv3RequestsEnabled) {

                    $SNMPService['SNMPv3RequestsEnabled'] = $ExistingSettingResource.settings.Default.SnmpService.SNMPv3RequestsEnabled
                }
            }
            else {              
                $SNMPv3RequestValue =
                switch ($SNMPv3Request) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for SNMPv3Request: $SNMPv3Request"
                    }   
                }
                $SNMPService['SNMPv3RequestsEnabled'] = $SNMPv3RequestValue
            }

            # $SNMPv3Trap
            if (-not $PSBoundParameters.ContainsKey('SNMPv3Trap')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.SnmpService.SNMPv3TrapEnabled) {

                    $SNMPService['SNMPv3TrapEnabled'] = $ExistingSettingResource.settings.Default.SnmpService.SNMPv3TrapEnabled
                }
            }
            else { 
                $SNMPv3TrapValue =
                switch ($SNMPv3Trap) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for SNMPv3Trap: $SNMPv3Trap"
                    }   
                }
                $SNMPService['SNMPv3TrapEnabled'] = $SNMPv3TrapValue
            }

            # $ColdStartTrap
            if (-not $PSBoundParameters.ContainsKey('ColdStartTrap')) { 
                if ($null -ne $ExistingSettingResource.settings.Default.SnmpService.SNMPColdStartTrapBroadcast) {

                    $SNMPService['SNMPColdStartTrapBroadcast'] = $ExistingSettingResource.settings.Default.SnmpService.SNMPColdStartTrapBroadcast
                }
            }
            else {             
                $ColdStartTrapValue =
                switch ($ColdStartTrap) {
                    'Disabled' { $false }
                    'Enabled' { $true }
                    Default { 
                        Throw "Invalid value for ColdStartTrap: $ColdStartTrap"
                    }   
                }
                $SNMPService['SNMPColdStartTrapBroadcast'] = $ColdStartTrapValue
            }

            # $PeriodicHSATrapConfiguration
            if (-not $PSBoundParameters.ContainsKey('PeriodicHSATrapConfiguration')) { 
                if ($ExistingSettingResource.settings.Default.SnmpService.PeriodicHSATrapConfig) {

                    $SNMPService['PeriodicHSATrapConfig'] = $ExistingSettingResource.settings.Default.SnmpService.PeriodicHSATrapConfig
                }
            }
            else {  
                $SNMPService['PeriodicHSATrapConfig'] = $PeriodicHSATrapConfiguration
            }

            # $SNMPSettingsSystemLocation
            if (-not $PSBoundParameters.ContainsKey('SNMPSettingsSystemLocation')) { 
                if ($ExistingSettingResource.settings.Default.SnmpService.Location) {

                    $SNMPService['Location'] = $ExistingSettingResource.settings.Default.SnmpService.Location
                }
            }
            else {              
                $SNMPService['Location'] = $SNMPSettingsSystemLocation
            }

            # $SNMPSettingsSystemContact
            if (-not $PSBoundParameters.ContainsKey('SNMPSettingsSystemContact')) { 
                if ($ExistingSettingResource.settings.Default.SnmpService.Contact) {

                    $SNMPService['Contact'] = $ExistingSettingResource.settings.Default.SnmpService.Contact
                }
            }
            else {             
                $SNMPService['Contact'] = $SNMPSettingsSystemContact
            }

            # $SNMPSettingsSystemRole
            if (-not $PSBoundParameters.ContainsKey('SNMPSettingsSystemRole')) { 
                if ($ExistingSettingResource.settings.Default.SnmpService.Role) {

                    $SNMPService['Role'] = $ExistingSettingResource.settings.Default.SnmpService.Role
                }
            }
            else {                  
                $SNMPService['Role'] = $SNMPSettingsSystemRole
            }

            # $SNMPSettingsSystemRoleDetails
            if (-not $PSBoundParameters.ContainsKey('SNMPSettingsSystemRoleDetails')) { 
                if ($ExistingSettingResource.settings.Default.SnmpService.RoleDetail) {               

                    $SNMPService['RoleDetail'] = $ExistingSettingResource.settings.Default.SnmpService.RoleDetail
                }
            }
            else {                
                $SNMPService['RoleDetail'] = $SNMPSettingsSystemRoleDetails
            }

            # Read Communities
            # Ensure ReadCommunities is always an array, containing ReadCommunities if present, or empty if not
            if ($ExistingSettingResource.settings.Default.SnmpService.ReadCommunities -and $Null -ne $ExistingSettingResource.settings.Default.SnmpService.ReadCommunities -and $ExistingSettingResource.settings.Default.SnmpService.ReadCommunities.count -gt 0) {
                
                # Always wrap in @() to ensure array, then assign. This works whether the source is already an array, a single object, or $null.
                $SNMPService['ReadCommunities'] = @($ExistingSettingResource.settings.Default.SnmpService.ReadCommunities)
            }
            else {
                $SNMPService['ReadCommunities'] = @()
            }

            # $SNMPSettingsReadCommunity1
            if ($PSBoundParameters.ContainsKey('SNMPSettingsReadCommunity1')) { 

                if ($SNMPSettingsReadCommunity1 -ne "") {
                    
                    # Add the value to the first element of the array
                    if ($SNMPService['ReadCommunities'].count -gt 0) {
                        $SNMPService['ReadCommunities'][0] = $SNMPSettingsReadCommunity1
                    }
                    else {
                        $SNMPService['ReadCommunities'] += $SNMPSettingsReadCommunity1
                    }
                }
                else {
                    # if SNMPSettingsReadCommunity is empty, the community must be removed, so it must be set as "" and it will be removed later below with "" detection
                    if ($SNMPService['ReadCommunities'].count -gt 0) {
                        $SNMPService['ReadCommunities'][0] = ""
                    }
                }
            }
            

            # $SNMPSettingsReadCommunity2
            if ($PSBoundParameters.ContainsKey('SNMPSettingsReadCommunity2')) { 

                if ($SNMPSettingsReadCommunity2 -ne "") {
                    
                    # Add the value to the first element of the array
                    if ($SNMPService['ReadCommunities'].count -gt 1) {
                        $SNMPService['ReadCommunities'][1] = $SNMPSettingsReadCommunity2
                    }
                    else {
                        $SNMPService['ReadCommunities'] += $SNMPSettingsReadCommunity2
                    }
                }
                else {
                    # if SNMPSettingsReadCommunity is empty, the community must be removed, so it must be set as "" and it will be removed later below with "" detection
                    if ($SNMPService['ReadCommunities'].count -gt 1) {
                        $SNMPService['ReadCommunities'][1] = ""
                    }
                }
            }

            # $SNMPSettingsReadCommunity3
            if ($PSBoundParameters.ContainsKey('SNMPSettingsReadCommunity3')) { 

                if ($SNMPSettingsReadCommunity3 -ne "") {
                    
                    # Add the value to the first element of the array
                    if ($SNMPService['ReadCommunities'].count -gt 2) {
                        $SNMPService['ReadCommunities'][2] = $SNMPSettingsReadCommunity3
                    }
                    else {
                        $SNMPService['ReadCommunities'] += $SNMPSettingsReadCommunity3
                    }
                }
                else {
                    # if SNMPSettingsReadCommunity is empty, the community must be removed, so it must be set as "" and it will be removed later below with "" detection
                    if ($SNMPService['ReadCommunities'].count -gt 2) {
                        $SNMPService['ReadCommunities'][2] = ""
                    }
                }
            }

            # Filter out empty entries from the array. Required when "" is used with $SNMPSettingsReadCommunityX
            $SNMPService['ReadCommunities'] = @($SNMPService['ReadCommunities'] | Where-Object { $_ -ne "" -and $_ -ne $null })

            # $SNMPv3EngineID
            if (-not $PSBoundParameters.ContainsKey('SNMPv3EngineID')) { 
                if ($ExistingSettingResource.settings.Default.SnmpService.SNMPv3EngineID) {

                    $SNMPService['SNMPv3EngineID'] = $ExistingSettingResource.settings.Default.SnmpService.SNMPv3EngineID
                }
            }
            else {             
                $SNMPService['SNMPv3EngineID'] = $SNMPv3EngineID
            }

            # $SNMPv3InformRetry
            if (-not $PSBoundParameters.ContainsKey('SNMPv3InformRetry')) { 
                if ($ExistingSettingResource.settings.Default.SnmpService.SNMPv3InformRetryAttempt) {

                    $SNMPService['SNMPv3InformRetryAttempt'] = $ExistingSettingResource.settings.Default.SnmpService.SNMPv3InformRetryAttempt
                }
            }
            else {                 
                $SNMPService['SNMPv3InformRetryAttempt'] = $SNMPv3InformRetry
            }

            # $SNMPv3InformRetryInterval
            if (-not $PSBoundParameters.ContainsKey('SNMPv3InformRetryInterval')) { 
                if ($ExistingSettingResource.settings.Default.SnmpService.SNMPv3InformRetryIntervalSeconds) {

                    $SNMPService['SNMPv3InformRetryIntervalSeconds'] = $ExistingSettingResource.settings.Default.SnmpService.SNMPv3InformRetryIntervalSeconds
                }
            }
            else {             
                $SNMPService['SNMPv3InformRetryIntervalSeconds'] = $SNMPv3InformRetryInterval
            }

            # SNMPv3 Users #########################################

            # Ensure SNMPv3Users is always an array, containing users if present, or empty if not
            if ($ExistingSettingResource.settings.Default.SnmpService.SNMPv3Users -and $Null -ne $ExistingSettingResource.settings.Default.SnmpService.SNMPv3Users -and $ExistingSettingResource.settings.Default.SnmpService.SNMPv3Users.Count -gt 0) {
                
                # Always wrap in @() to ensure array, then assign. This works whether the source is already an array, a single object, or $null.
                $SNMPService['SNMPv3Users'] = @($ExistingSettingResource.settings.Default.SnmpService.SNMPv3Users)
            } else {
                $SNMPService['SNMPv3Users'] = @()
            }

            # $SNMPv3User1UserName
            # SNMPv3User1 block: update/add/remove user entry based on parameters
            if ($PSBoundParameters.ContainsKey('SNMPv3User1UserName')) {
                if ($SNMPv3User1UserName -ne "") {
                    # Build SNMPv3User1 object with all relevant properties
                    $SNMPv3User1 = @{
                        "SecurityName"    = $SNMPv3User1UserName
                        "AuthProtocol"    = $SNMPv3User1AuthenticationProtocol
                        "PrivacyProtocol" = "AES"
                    }
                    # EngineID
                    if ($PSBoundParameters.ContainsKey('SNMPv3User1EngineID')) {
                        $SNMPv3User1.UserEngineID = $SNMPv3User1EngineID
                    } elseif ($SNMPService['SNMPv3Users'].Count -gt 0 -and $SNMPService['SNMPv3Users'][0].PSObject.Properties['UserEngineID'] -ne $null) {
                        $SNMPv3User1.UserEngineID = $SNMPService['SNMPv3Users'][0].UserEngineID
                    }
                    # AuthPassphrase
                    $SNMPv3User1.AuthPassphrase = $SNMPv3User1AuthenticationPassphrasePlainText
                    
                    # PrivacyPassphrase
                    $SNMPv3User1.PrivacyPassphrase = $SNMPv3User1PrivacyPassphrasePlainText
                     
                    # Update or add user in array
                    if ($SNMPService['SNMPv3Users'].Count -gt 0) {
                        $SNMPService['SNMPv3Users'][0] = $SNMPv3User1
                    } else {
                        $SNMPService['SNMPv3Users'] += $SNMPv3User1
                    }
                } else {
                    # if username is empty, the user must be removed, so it must be set with SecurityName as "" and it will be removed later below with "" detection
                    $SNMPv3User1 = @{
                        "SecurityName" = ""
                    }

                    If ($SNMPService['SNMPv3Users'].Count -gt 1) {
                        $SNMPService['SNMPv3Users'][0] = $SNMPv3User1
                    }
                    else {
                        $SNMPService['SNMPv3Users'] += $SNMPv3User1
                    }  
                }
            }

            # $SNMPv3User2UserName
            if ($PSBoundParameters.ContainsKey('SNMPv3User2UserName')) {
                if ($SNMPv3User2UserName -ne "") {
                    # Build SNMPv3User2 object with all relevant properties
                    $SNMPv3User2 = @{
                        "SecurityName"    = $SNMPv3User2UserName
                        "AuthProtocol"    = $SNMPv3User2AuthenticationProtocol
                        "PrivacyProtocol" = "AES"
                    }
                    # EngineID
                    if ($PSBoundParameters.ContainsKey('SNMPv3User2EngineID')) {
                        $SNMPv3User2.UserEngineID = $SNMPv3User2EngineID
                    } elseif ($SNMPService['SNMPv3Users'].Count -gt 1 -and $SNMPService['SNMPv3Users'][1].PSObject.Properties['UserEngineID'] -ne $null) {
                        $SNMPv3User2.UserEngineID = $SNMPService['SNMPv3Users'][1].UserEngineID
                    }
                    # AuthPassphrase
                    $SNMPv3User2.AuthPassphrase = $SNMPv3User2AuthenticationPassphrasePlainText
                    
                    # PrivacyPassphrase
                    $SNMPv3User2.PrivacyPassphrase = $SNMPv3User2PrivacyPassphrasePlainText

                    # Update or add user in array
                    if ($SNMPService['SNMPv3Users'].Count -gt 1) {
                        $SNMPService['SNMPv3Users'][1] = $SNMPv3User2
                    } else {
                        $SNMPService['SNMPv3Users'] += $SNMPv3User2
                    }
                } else {
                    # if username is empty, the user must be removed, so it must be set with SecurityName as "" and it will be removed later below with "" detection
                    $SNMPv3User2 = @{
                        "SecurityName" = ""
                    }

                    If ($SNMPService['SNMPv3Users'].Count -gt 1) {
                        $SNMPService['SNMPv3Users'][1] = $SNMPv3User2
                    }
                    else {
                        $SNMPService['SNMPv3Users'] += $SNMPv3User2
                    }  
                }
            } 

            # Filter out empty entries from the array. Required when "" is used with $SNMPv3UserXUserName
            $SNMPService['SNMPv3Users'] = @($SNMPService['SNMPv3Users'] | Where-Object { $_.SecurityName -ne "" })


            # SNMP ALERT DESTINATIONS  
            if ($ExistingSettingResource.settings.Default.SnmpService.SNMPAlertDestinations -and $Null -ne $ExistingSettingResource.settings.Default.SnmpService.SNMPAlertDestinations -and $ExistingSettingResource.settings.Default.SnmpService.SNMPAlertDestinations.count -gt 0) {
                
                # Always wrap in @() to ensure array, then assign. This works whether the source is already an array, a single object, or $null.
                $SNMPService['SNMPAlertDestinations'] = @($ExistingSettingResource.settings.Default.SnmpService.SNMPAlertDestinations)

            } else {
                $SNMPService['SNMPAlertDestinations'] = @()
            }

            # $SNMPAlertDestination1
            if ($PSBoundParameters.ContainsKey('SNMPAlertDestination1')) { 
                
                if ($SNMPAlertDestination1 -ne "") {
                    
                    # $SNMPProtocolForDestination1
                    $SNMPProtocolForDestination1Value =
                    switch ($SNMPProtocolForDestination1) {
                        'SNMPv1 Trap' { 'SNMPv1Trap' }
                        'SNMPv3 Trap' { 'SNMPv3Trap' }
                        'SNMPv3 Inform' { 'SNMPv3Inform' }
                        Default { 
                            Throw "Invalid value for SNMPProtocolForDestination1: $SNMPProtocolForDestination1"
                        }   
                    }    

                    if ($SNMPProtocolForDestination1Value -eq "SNMPv3Trap" -or $SNMPProtocolForDestination1Value -eq "SNMPv3Inform"){
                        $AlertDestination1 = @{
                            "SecurityName"      = $SNMPv3UserForDestination1
                            "AlertDestination"  = $SNMPAlertDestination1
                            "TrapCommunity"     = $SNMPTrapCommunityForDestination1
                            "SNMPAlertProtocol" = $SNMPProtocolForDestination1Value
                        }                
                    }
                    else {
                        $AlertDestination1 = @{
                            "AlertDestination"  = $SNMPAlertDestination1
                            "TrapCommunity"     = $SNMPTrapCommunityForDestination1
                            "SNMPAlertProtocol" = $SNMPProtocolForDestination1Value
                        }   
                    }
                    
                        
                    if (($SNMPService['SNMPAlertDestinations']).count -gt 0) {
                        $SNMPService['SNMPAlertDestinations'][0] = $AlertDestination1
                    }
                    else {
                        $SNMPService['SNMPAlertDestinations'] += $AlertDestination1
                    }
                }
                else {
                    $AlertDestination1 = @{
                        "AlertDestination"  = ""
                    }

                    if ($SNMPService['SNMPAlertDestinations'].count -gt 0) {
                        $SNMPService['SNMPAlertDestinations'][0] = $AlertDestination1

                    }
                }
            }         

            # $SNMPAlertDestination2
            if ($PSBoundParameters.ContainsKey('SNMPAlertDestination2')) { 

                if ($SNMPAlertDestination2 -ne "") {

                    # $SNMPProtocolForDestination2
                    $SNMPProtocolForDestination2Value =
                    switch ($SNMPProtocolForDestination2) {
                        'SNMPv1 Trap' { 'SNMPv1Trap' }
                        'SNMPv3 Trap' { 'SNMPv3Trap' }
                        'SNMPv3 Inform' { 'SNMPv3Inform' }
                        Default { 
                            Throw "Invalid value for SNMPProtocolForDestination2: $SNMPProtocolForDestination2"
                        }   
                    }    

                    if ($SNMPProtocolForDestination2Value -eq "SNMPv3Trap" -or $SNMPProtocolForDestination2Value -eq "SNMPv3Inform"){
                        $AlertDestination2 = @{
                            "SecurityName"      = $SNMPv3UserForDestination2
                            "AlertDestination"  = $SNMPAlertDestination2
                            "TrapCommunity"     = $SNMPTrapCommunityForDestination2
                            "SNMPAlertProtocol" = $SNMPProtocolForDestination2Value
                        }                
                    }
                    else {
                        $AlertDestination2 = @{
                            "AlertDestination"  = $SNMPAlertDestination2
                            "TrapCommunity"     = $SNMPTrapCommunityForDestination2
                            "SNMPAlertProtocol" = $SNMPProtocolForDestination2Value
                        }   
                    }


                    if (($SNMPService['SNMPAlertDestinations']).count -gt 1) {
                        $SNMPService['SNMPAlertDestinations'][1] = $AlertDestination2
                    }
                    else {
                        $SNMPService['SNMPAlertDestinations'] += $AlertDestination2
                    }
                }
                else {
                    $AlertDestination2 = @{
                        "AlertDestination"  = ""
                    }

                    if ($SNMPService['SNMPAlertDestinations'].count -gt 1) {
                        $SNMPService['SNMPAlertDestinations'][1] = $AlertDestination2

                    }
                }
            }            

            # $SNMPAlertDestination3
            if ($PSBoundParameters.ContainsKey('SNMPAlertDestination3')) { 

                if ($SNMPAlertDestination3 -ne "") {

                    # $SNMPProtocolForDestination3
                    $SNMPProtocolForDestination3Value =
                    switch ($SNMPProtocolForDestination3) {
                        'SNMPv1 Trap' { 'SNMPv1Trap' }
                        'SNMPv3 Trap' { 'SNMPv3Trap' }
                        'SNMPv3 Inform' { 'SNMPv3Inform' }
                        Default { 
                            Throw "Invalid value for SNMPProtocolForDestination3: $SNMPProtocolForDestination3"
                        }   
                    }    

                    if ($SNMPProtocolForDestination3Value -eq "SNMPv3Trap" -or $SNMPProtocolForDestination3Value -eq "SNMPv3Inform"){
                        $AlertDestination3 = @{
                            "SecurityName"      = $SNMPv3UserForDestination3
                            "AlertDestination"  = $SNMPAlertDestination3
                            "TrapCommunity"     = $SNMPTrapCommunityForDestination3
                            "SNMPAlertProtocol" = $SNMPProtocolForDestination3Value
                        }                
                    }
                    else {
                        $AlertDestination3 = @{
                            "AlertDestination"  = $SNMPAlertDestination3
                            "TrapCommunity"     = $SNMPTrapCommunityForDestination3
                            "SNMPAlertProtocol" = $SNMPProtocolForDestination3Value
                        }   
                    }

                    if (($SNMPService['SNMPAlertDestinations']).count -gt 2) {
                        $SNMPService['SNMPAlertDestinations'][2] = $AlertDestination3
                    }
                    else {
                        $SNMPService['SNMPAlertDestinations'] += $AlertDestination3
                    }
                }
                else {
                    $AlertDestination3 = @{
                        "AlertDestination"  = ""
                    }

                    if ($SNMPService['SNMPAlertDestinations'].count -gt 2) {
                        $SNMPService['SNMPAlertDestinations'][2] = $AlertDestination3

                    }
                }
            }           

            # Filter out empty entries from the array. Required when "" is used with $SNMPAlertDestinationX
            $SNMPService['SNMPAlertDestinations'] = @($SNMPService['SNMPAlertDestinations'] | Where-Object { $_.AlertDestination -ne "" })

            #EndRegion

            #Region SECURITY SERVICE #######################################

            $SecurityService = @{}

            # $GlobalComponentIntegrityCheck
            if (-not $PSBoundParameters.ContainsKey('GlobalComponentIntegrityCheck')) { 
                if ($ExistingSettingResource.settings.Default.SecurityService.GlobalComponentIntegrity) {
                     $SecurityService['GlobalComponentIntegrity'] = $ExistingSettingResource.settings.Default.SecurityService.GlobalComponentIntegrity
                }
            }
            else {            
                $SecurityService['GlobalComponentIntegrity'] = $GlobalComponentIntegrityCheck
            }

            # $GlobalComponentIntegrityPolicy
            if (-not $PSBoundParameters.ContainsKey('GlobalComponentIntegrityPolicy')) { 
                if ($ExistingSettingResource.settings.Default.SecurityService.ComponentIntegrityPolicy) {
                     $SecurityService['ComponentIntegrityPolicy'] = $ExistingSettingResource.settings.Default.SecurityService.ComponentIntegrityPolicy
                }
            }
            else {              
                $GlobalComponentIntegrityPolicyValue =
                switch ($GlobalComponentIntegrityPolicy) {
                    'No policy' { 'NoPolicy' }
                    'Halt boot on SPDM failure' { 'HaltBootOnSPDMFailure' }
                        
                    Default { 
                        Throw "Invalid value for GlobalComponentIntegrityPolicy: $GlobalComponentIntegrityPolicy"
                    }   
                }
                $SecurityService['ComponentIntegrityPolicy'] = $GlobalComponentIntegrityPolicyValue           
            }


            #EndRegion

            # Build payload
    
            $Settings = @{
                Default = @{
                        "1"                      = $1
                        AccountService           = $AccountService
                        NetworkProtocol          = $NetworkProtocol
                        SecurityService          = $SecurityService 
                        UpdateService            = $UpdateService   
                        SnmpService              = $SnmpService
                }
            }
                
            $Payload = @{ 
                name           = $Name
                description    = $Description
                settings       = $Settings                  
            }
    
            $Payload = $Payload | ConvertTo-Json -Depth 20
        
            try {
        
                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method PATCH -body $payload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
        
                if (-not $WhatIf ) {
            
                    "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
        
                    "[{0}] iLO server setting '{1}' successfully set in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
                            
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "iLO server setting successfully set in $Region region"
    
    
                }
            }
            catch {
        
                if (-not $WhatIf) {
        
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "iLO server setting cannot be set!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData
    
                }  
            }        
        }    

        [void] $SetiLOServerSettingStatus.add($objStatus)
    }
    
    End {
       
        if (-not $WhatIf ) {

            $SetiLOServerSettingStatus = Invoke-RepackageObjectWithType -RawObject $SetiLOServerSettingStatus -ObjectName "COM.objStatus.NSDE"
            Return $SetiLOServerSettingStatus

        }
    }
}

#Region NOT IMPLEMENTED YET
# Function New-HPECOMSettingOneViewApplianceSettings {
#     <#
#     .SYNOPSIS
#     Configure a OneView appliance settings.

#     .DESCRIPTION
#     This Cmdlet creates a new setting for OneView appliances settings
    
#     Appliance settings allow you to create a set of common configuration preferences that you can easily apply to one or more appliances in a Compute Ops Management group.
    
#     .PARAMETER Region 
#     Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
#     This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

#     Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

#     .PARAMETER Name
#     Specifies the name of the external storage server setting.

#     .PARAMETER Description
#     Specifies a description of the external storage server setting.

#     .PARAMETER HostOSType
#     Specifies the OS installed on the server. 

#     "UNKNOWN" "AIX" "APPLE" "CITRIX_HYPERVISOR" "HP_UX" "IBM_VIO_SERVER" "INFORM" "NETAPP" "OE_LINUX_UEK" "OPENVMS" "ORACLE_VM" "RHE_LINUX" "RHE_VIRTUALIZATION" "SOLARIS" "SUSE_LINUX" "SUSE_VIRTUALIZATION" "UBUNTU" "VMWARE_ESXI" "WINDOWS_SERVER"
    
#     .PARAMETER WhatIf 
#     Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.
   
#     .EXAMPLE
#     New-HPECOMSettingServerOSImage -Region  us-west -Name OS-ESX -Description "My ESX OS image SS" -OperatingSystem VMWARE_ESXI -OSImageURL "https://domain.com/esx.iso" 

#     This command creates a new OS image configuration server setting named 'OS-ESX' using a single image containing OS and unattended installation file from the URL 'https://domain.com/esx8.iso' in the 'us-west' region.

#     .EXAMPLE
#     New-HPECOMSettingServerOSImage -Region us-west -Name OS-ESX -Description "My ESX 8 OS image configuration" -OperatingSystem VMWARE_ESXI -OSImageURL "https://domain.com/esx8.iso" -UnattendedInstallationFileImageUrl "https://domain.com/esx_ks.iso" 
    
#     This command creates a new OS image configuration server setting named 'OS-ESX' using a separate image for OS from the URL 'https://domain.com/esx8.iso' and for the unattended file from the URL 'https://domain.com/esx_ks.iso'.

#     .INPUTS
#     Pipeline input is not supported.
    
#     .OUTPUTS
#     System.Collections.ArrayList
#         A custom status object or array of objects containing the following PsCustomObject keys:
#         * Name - The name of the external storage server setting attempted to be created
#         * Region - The name of the region
#         * Status - Status of the creation attempt (Failed for HTTP error return; Complete if creation is successful; Warning if no action is needed)
#         * Details - More information about the status 
#         * Exception: Information about any exceptions generated during the operation.

    
#    #>
#     [CmdletBinding(DefaultParameterSetName = 'Together')]
#     Param( 
#         [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
#         [ArgumentCompleter({
#                 param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
#                 # Filter region based on $Global:HPECOMRegions global variable and create completions
#                 $Global:HPECOMRegions.region | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
#                     [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
#                 }
#             })]
#         [String]$Region,

#         [Parameter (Mandatory)]
#         [ValidateScript({ $_.Length -le 100 })]
#         [String]$Name,  
        
#         [ValidateScript({ $_.Length -le 1000 })]
#         [String]$Description,    
        

        
#         [Switch]$WhatIf
       
#     ) 
#     Begin {
        
#         $Caller = (Get-PSCallStack)[1].Command

#         "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

#         $Uri = Get-COMSettingsUri
#         $NewServerSettingFirmwareStatus = [System.Collections.ArrayList]::new()
        
#     }
    
#     Process {
        
#         "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

#         # Build object for the output
#         $objStatus = [pscustomobject]@{
  
#             Name      = $Name
#             Region    = $Region                            
#             Status    = $Null
#             Details   = $Null
#             Exception = $Null
#         }
    
        
#         # Build payload
#         $Settings = @{ 
#             DEFAULT = @{
#                 externalStorageHostOs = $HostOSType

#             }
#         }

#         $payload = @{ 
#             name           = $Name
#             category       = "EXTERNAL_STORAGE"
#             description    = $Description
#             settings       = $Settings                  
#         }

#         $payload = ConvertTo-Json $payload -Depth 10 

#         try {

#             $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

#             if (-not $WhatIf ) {
    
#                 "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

#                 "[{0}] Firmware server setting '{1}' successfully created in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
                    
#                 $objStatus.Status = "Complete"
#                 $objStatus.Details = "Firmware server setting successfully created in $Region region"


#             }
#         }
#         catch {

#             if (-not $WhatIf) {

#                 $objStatus.Status = "Failed"
#                 $objStatus.Details = "Firmware server setting cannot be created!"
#                 $objStatus.Exception = $Global:HPECOMInvokeReturnData 

#             }
#         } 

#         [void] $NewServerSettingFirmwareStatus.add($objStatus)

        

    
#     }
    
#     End {
       

#         if (-not $WhatIf ) {

#             Return $NewServerSettingFirmwareStatus
        
#         }

#     }
# }
#EndRegion

Function Remove-HPECOMSetting {
    <#
    .SYNOPSIS
    Remove a server setting from a region.

    .DESCRIPTION
    This Cmdlet can be used to remove a server setting resource from a region using its name property.       
        
    .PARAMETER Name 
    Name of the server setting to remove. 
    
    .PARAMETER Region 
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where to remove a server setting. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Force
    Switch parameter to force the removal. 
    
    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Remove-HPECOMSetting -Region eu-central -Name 'RAID1' 
    
    Remove the server setting named 'RAID1' from the central EU region. 

    .EXAMPLE
    Get-HPECOMSetting -Region eu-central -Name RAID-1 | Remove-HPECOMSetting 

    Remove server setting 'RAID-1' from the western central EU region. 

    .EXAMPLE 
    Get-HPECOMSetting -Region us-west | Where-Object {$_.name -eq 'RAID1' -or $_.name -eq 'RAID5'} | Remove-HPECOMSetting
    
    Remove server setting 'RAID1' and 'RAID5' from the western US region. 

    .EXAMPLE
    Get-HPECOMSetting -Region eu-central | Remove-HPECOMSetting -Force

    Remove all server settings from the central EU region using the force removal. 

    .INPUTS
    System.Collections.ArrayList
        List of server settings from 'Get-HPECOMSetting'. 

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - Name of the server setting attempted to be removed
        * Region - Name of the region
        * Status - Status of the removal attempt (Failed for http error return; Complete if removal is successful; Warning if no action is needed) 
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.

    
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

        $RemoveSettingstatus = [System.Collections.ArrayList]::new()
        
    }
    
    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
                
        try {
            $settingResource = Get-HPECOMSetting -Region $Region -Name $Name
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
                     
        $settingID = $settingResource.id

        
        if (-not $settingID) {

            # Must return a message if not found

            if ($WhatIf) {

                $ErrorMessage = "Server setting '{0}': Resource cannot be found in the '{1}' region!" -f $Name, $Region
       
                Write-warning $ErrorMessage
                return
            
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "Server setting cannot be found in the region!"

            }
        }
        elseif ($settingID -match "00000000-0000-0000-0000") {

            if ($WhatIf) {

                $ErrorMessage = "Server setting '{0}': This resource is an HPE pre-defined setting and cannot be removed from the Compute Ops Management instance!" -f $Name       
                Write-warning $ErrorMessage
                return
            
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "This server setting is an HPE pre-defined setting that cannot be removed from the Compute Ops Management instance!"
            }
        }
        else {
            
            if ($Force) {

                $Uri = (Get-COMSettingsUri) + "/" + $settingID + "?Force=true"
            }
            else {
                
                $Uri = (Get-COMSettingsUri) + "/" + $settingID
            }

            # Removal task  
            try {
                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method DELETE -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                
                if (-not $WhatIf) {
                    
                    "[{0}] Server setting removal raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose

                    "[{0}] Server setting '{1}' successfully deleted from '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Region | Write-Verbose
                    
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Server setting successfully deleted from $Region region"

                }

            }
            catch {

                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Server setting cannot be deleted!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                }
            }           

        }
        [void] $RemoveSettingstatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            $RemoveSettingstatus = Invoke-RepackageObjectWithType -RawObject $RemoveSettingstatus -ObjectName "COM.objStatus.NSDE"
            Return $RemoveSettingstatus
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
    Param (
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
Export-ModuleMember -Function `
    "Get-HPECOMAppliance", `
    "Remove-HPECOMAppliance", `
    "Get-HPECOMApplianceFirmwareBundle", `
    "Get-HPECOMSetting", `
    "New-HPECOMSettingServerBios", `
    "Set-HPECOMSettingServerBios", `
    "New-HPECOMSettingServerInternalStorageVolume", `
    "New-HPECOMSettingServerInternalStorage", `
    "Set-HPECOMSettingServerInternalStorage", `
    "New-HPECOMSettingServerOSImage", `
    "Set-HPECOMSettingServerOSImage", `
    "New-HPECOMSettingServerFirmware", `
    "Set-HPECOMSettingServerFirmware", `
    "New-HPECOMSettingServerExternalStorage", `
    "Set-HPECOMSettingServerExternalStorage", `
    "New-HPECOMSettingiLOSettings", `
    "Set-HPECOMSettingiLOSettings", `
    "Remove-HPECOMSetting" `
    -Alias *




# SIG # Begin signature block
# MIIunwYJKoZIhvcNAQcCoIIukDCCLowCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCLIvRV+kG5ePbB
# ClFvJBq0SoRwf1hai6bJ1w0QZ1IyeKCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# nZ+oA+rbZZyGZkz3xbUYKTGCG/8wghv7AgEBMGkwVDELMAkGA1UEBhMCR0IxGDAW
# BgNVBAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMg
# Q29kZSBTaWduaW5nIENBIFIzNgIRAMgx4fswkMFDciVfUuoKqr0wDQYJYIZIAWUD
# BAIBBQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGC
# NwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQx
# IgQgM7fcVEPaVlSQb31AxXf1NhujtCatMYsXfJr5IVOdx/8wDQYJKoZIhvcNAQEB
# BQAEggIAYREiWhwPcqSrDivlfudBfk/jOfyUSle5l02aNWZNUuSgPww0LZKQJ2O4
# D6rU+WcIpc9Ca8Rz3CEBW2+F/HUf7BiymLvbvtKoJ6DQRwsRqDaKqzCcTt1CMZ6J
# +bet23j2yK8u6isVCB5xL09I0/JFmnbq2TU5jVFfhIPlCkJ/kkPOVcPRuXbljb7D
# dOvObb2NSOvS7z/31QFwN6OzI++Thju7qnBB5E9HIFQl/4hNXijenpDAstO8XJdb
# sO7bW7AsT00v0a2HshWrA32aamUCU2/I0iqnAVLia4QFLpSHh395RJxioXKp7tSN
# ozYsT7+wz7AZ3xkTvLiXNAyKRw73AUdgLRS2Tqk/b2CmtSd0rxEw77pjs2ANlq6T
# PBatMhgRipMGoSzqh/1o+CMUzrdmpCkeEjhmtiY6v+ZJ3URbdtoa8uvXuetquWc/
# usMApZDGk5K9o48jS/hIzIWrQKOZf8W8dkUamxswehzsIuWBooiEyKLurY13TBYT
# pQGeq+Du8SpO32fx0bzLNDNJTBmBuTwmECze8Ckm18mCIiKcOGsNES7Y0ePcYeYg
# M+VyVNPcif5/pM5Rgw2tRJNjF7goNKXeUYz4RSd75iNUucWzQiCoSO2lMfdlwu7J
# geG0g4tZqKZLFHkT41moQihh3P+O7w//m2fZBTxlYH77AUVjL/KhghjpMIIY5QYK
# KwYBBAGCNwMDATGCGNUwghjRBgkqhkiG9w0BBwKgghjCMIIYvgIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBCAYLKoZIhvcNAQkQAQSggfgEgfUwgfICAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQw4CgJ8T55HwwmV1VPazJ28YeOwVptmMGp7dpX
# 3VsmZTRChQ+C4Gj3LX1fWXjjg0fNAhUAs74PDTMGRE2FboPwx9p0MTKylj8YDzIw
# MjYwMTMwMTA1MDM3WqB2pHQwcjELMAkGA1UEBhMCR0IxFzAVBgNVBAgTDldlc3Qg
# WW9ya3NoaXJlMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxMDAuBgNVBAMTJ1Nl
# Y3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgU2lnbmVyIFIzNqCCEwQwggZiMIIE
# yqADAgECAhEApCk7bh7d16c0CIetek63JDANBgkqhkiG9w0BAQwFADBVMQswCQYD
# VQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSwwKgYDVQQDEyNTZWN0
# aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIENBIFIzNjAeFw0yNTAzMjcwMDAwMDBa
# Fw0zNjAzMjEyMzU5NTlaMHIxCzAJBgNVBAYTAkdCMRcwFQYDVQQIEw5XZXN0IFlv
# cmtzaGlyZTEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMTAwLgYDVQQDEydTZWN0
# aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIFNpZ25lciBSMzYwggIiMA0GCSqGSIb3
# DQEBAQUAA4ICDwAwggIKAoICAQDThJX0bqRTePI9EEt4Egc83JSBU2dhrJ+wY7Jg
# Reuff5KQNhMuzVytzD+iXazATVPMHZpH/kkiMo1/vlAGFrYN2P7g0Q8oPEcR3h0S
# ftFNYxxMh+bj3ZNbbYjwt8f4DsSHPT+xp9zoFuw0HOMdO3sWeA1+F8mhg6uS6BJp
# PwXQjNSHpVTCgd1gOmKWf12HSfSbnjl3kDm0kP3aIUAhsodBYZsJA1imWqkAVqwc
# Gfvs6pbfs/0GE4BJ2aOnciKNiIV1wDRZAh7rS/O+uTQcb6JVzBVmPP63k5xcZNzG
# o4DOTV+sM1nVrDycWEYS8bSS0lCSeclkTcPjQah9Xs7xbOBoCdmahSfg8Km8ffq8
# PhdoAXYKOI+wlaJj+PbEuwm6rHcm24jhqQfQyYbOUFTKWFe901VdyMC4gRwRAq04
# FH2VTjBdCkhKts5Py7H73obMGrxN1uGgVyZho4FkqXA8/uk6nkzPH9QyHIED3c9C
# GIJ098hU4Ig2xRjhTbengoncXUeo/cfpKXDeUcAKcuKUYRNdGDlf8WnwbyqUblj4
# zj1kQZSnZud5EtmjIdPLKce8UhKl5+EEJXQp1Fkc9y5Ivk4AZacGMCVG0e+wwGsj
# cAADRO7Wga89r/jJ56IDK773LdIsL3yANVvJKdeeS6OOEiH6hpq2yT+jJ/lHa9zE
# dqFqMwIDAQABo4IBjjCCAYowHwYDVR0jBBgwFoAUX1jtTDF6omFCjVKAurNhlxmi
# MpswHQYDVR0OBBYEFIhhjKEqN2SBKGChmzHQjP0sAs5PMA4GA1UdDwEB/wQEAwIG
# wDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMEoGA1UdIARD
# MEEwNQYMKwYBBAGyMQECAQMIMCUwIwYIKwYBBQUHAgEWF2h0dHBzOi8vc2VjdGln
# by5jb20vQ1BTMAgGBmeBDAEEAjBKBgNVHR8EQzBBMD+gPaA7hjlodHRwOi8vY3Js
# LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdDQVIzNi5jcmww
# egYIKwYBBQUHAQEEbjBsMEUGCCsGAQUFBzAChjlodHRwOi8vY3J0LnNlY3RpZ28u
# Y29tL1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdDQVIzNi5jcnQwIwYIKwYBBQUH
# MAGGF2h0dHA6Ly9vY3NwLnNlY3RpZ28uY29tMA0GCSqGSIb3DQEBDAUAA4IBgQAC
# gT6khnJRIfllqS49Uorh5ZvMSxNEk4SNsi7qvu+bNdcuknHgXIaZyqcVmhrV3PHc
# mtQKt0blv/8t8DE4bL0+H0m2tgKElpUeu6wOH02BjCIYM6HLInbNHLf6R2qHC1SU
# sJ02MWNqRNIT6GQL0Xm3LW7E6hDZmR8jlYzhZcDdkdw0cHhXjbOLsmTeS0SeRJ1W
# JXEzqt25dbSOaaK7vVmkEVkOHsp16ez49Bc+Ayq/Oh2BAkSTFog43ldEKgHEDBbC
# Iyba2E8O5lPNan+BQXOLuLMKYS3ikTcp/Qw63dxyDCfgqXYUhxBpXnmeSO/WA4Nw
# dwP35lWNhmjIpNVZvhWoxDL+PxDdpph3+M5DroWGTc1ZuDa1iXmOFAK4iwTnlWDg
# 3QNRsRa9cnG3FBBpVHnHOEQj4GMkrOHdNDTbonEeGvZ+4nSZXrwCW4Wv2qyGDBLl
# Kk3kUW1pIScDCpm/chL6aUbnSsrtbepdtbCLiGanKVR/KC1gsR0tC6Q0RfWOI4ow
# ggYUMIID/KADAgECAhB6I67aU2mWD5HIPlz0x+M/MA0GCSqGSIb3DQEBDAUAMFcx
# CzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMT
# JVNlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgUm9vdCBSNDYwHhcNMjEwMzIy
# MDAwMDAwWhcNMzYwMzIxMjM1OTU5WjBVMQswCQYDVQQGEwJHQjEYMBYGA1UEChMP
# U2VjdGlnbyBMaW1pdGVkMSwwKgYDVQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1lIFN0
# YW1waW5nIENBIFIzNjCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAM2Y
# 2ENBq26CK+z2M34mNOSJjNPvIhKAVD7vJq+MDoGD46IiM+b83+3ecLvBhStSVjeY
# XIjfa3ajoW3cS3ElcJzkyZlBnwDEJuHlzpbN4kMH2qRBVrjrGJgSlzzUqcGQBaCx
# pectRGhhnOSwcjPMI3G0hedv2eNmGiUbD12OeORN0ADzdpsQ4dDi6M4YhoGE9cbY
# 11XxM2AVZn0GiOUC9+XE0wI7CQKfOUfigLDn7i/WeyxZ43XLj5GVo7LDBExSLnh+
# va8WxTlA+uBvq1KO8RSHUQLgzb1gbL9Ihgzxmkdp2ZWNuLc+XyEmJNbD2OIIq/fW
# lwBp6KNL19zpHsODLIsgZ+WZ1AzCs1HEK6VWrxmnKyJJg2Lv23DlEdZlQSGdF+z+
# Gyn9/CRezKe7WNyxRf4e4bwUtrYE2F5Q+05yDD68clwnweckKtxRaF0VzN/w76kO
# LIaFVhf5sMM/caEZLtOYqYadtn034ykSFaZuIBU9uCSrKRKTPJhWvXk4CllgrwID
# AQABo4IBXDCCAVgwHwYDVR0jBBgwFoAU9ndq3T/9ARP/FqFsggIv0Ao9FCUwHQYD
# VR0OBBYEFF9Y7UwxeqJhQo1SgLqzYZcZojKbMA4GA1UdDwEB/wQEAwIBhjASBgNV
# HRMBAf8ECDAGAQH/AgEAMBMGA1UdJQQMMAoGCCsGAQUFBwMIMBEGA1UdIAQKMAgw
# BgYEVR0gADBMBgNVHR8ERTBDMEGgP6A9hjtodHRwOi8vY3JsLnNlY3RpZ28uY29t
# L1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdSb290UjQ2LmNybDB8BggrBgEFBQcB
# AQRwMG4wRwYIKwYBBQUHMAKGO2h0dHA6Ly9jcnQuc2VjdGlnby5jb20vU2VjdGln
# b1B1YmxpY1RpbWVTdGFtcGluZ1Jvb3RSNDYucDdjMCMGCCsGAQUFBzABhhdodHRw
# Oi8vb2NzcC5zZWN0aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOCAgEAEtd7IK0ONVgM
# noEdJVj9TC1ndK/HYiYh9lVUacahRoZ2W2hfiEOyQExnHk1jkvpIJzAMxmEc6ZvI
# yHI5UkPCbXKspioYMdbOnBWQUn733qMooBfIghpR/klUqNxx6/fDXqY0hSU1OSkk
# Sivt51UlmJElUICZYBodzD3M/SFjeCP59anwxs6hwj1mfvzG+b1coYGnqsSz2wSK
# r+nDO+Db8qNcTbJZRAiSazr7KyUJGo1c+MScGfG5QHV+bps8BX5Oyv9Ct36Y4Il6
# ajTqV2ifikkVtB3RNBUgwu/mSiSUice/Jp/q8BMk/gN8+0rNIE+QqU63JoVMCMPY
# 2752LmESsRVVoypJVt8/N3qQ1c6FibbcRabo3azZkcIdWGVSAdoLgAIxEKBeNh9A
# QO1gQrnh1TA8ldXuJzPSuALOz1Ujb0PCyNVkWk7hkhVHfcvBfI8NtgWQupiaAeNH
# e0pWSGH2opXZYKYG4Lbukg7HpNi/KqJhue2Keak6qH9A8CeEOB7Eob0Zf+fU+CCQ
# aL0cJqlmnx9HCDxF+3BLbUufrV64EbTI40zqegPZdA+sXCmbcZy6okx/SjwsusWR
# ItFA3DE8MORZeFb6BmzBtqKJ7l939bbKBy2jvxcJI98Va95Q5JnlKor3m0E7xpMe
# YRriWklUPsetMSf2NvUQa/E5vVyefQIwggaCMIIEaqADAgECAhA2wrC9fBs656Oz
# 3TbLyXVoMA0GCSqGSIb3DQEBDAUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# TmV3IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBV
# U0VSVFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZp
# Y2F0aW9uIEF1dGhvcml0eTAeFw0yMTAzMjIwMDAwMDBaFw0zODAxMTgyMzU5NTla
# MFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLjAsBgNV
# BAMTJVNlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgUm9vdCBSNDYwggIiMA0G
# CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCIndi5RWedHd3ouSaBmlRUwHxJBZvM
# WhUP2ZQQRLRBQIF3FJmp1OR2LMgIU14g0JIlL6VXWKmdbmKGRDILRxEtZdQnOh2q
# mcxGzjqemIk8et8sE6J+N+Gl1cnZocew8eCAawKLu4TRrCoqCAT8uRjDeypoGJrr
# uH/drCio28aqIVEn45NZiZQI7YYBex48eL78lQ0BrHeSmqy1uXe9xN04aG0pKG9k
# i+PC6VEfzutu6Q3IcZZfm00r9YAEp/4aeiLhyaKxLuhKKaAdQjRaf/h6U13jQEV1
# JnUTCm511n5avv4N+jSVwd+Wb8UMOs4netapq5Q/yGyiQOgjsP/JRUj0MAT9Yrcm
# XcLgsrAimfWY3MzKm1HCxcquinTqbs1Q0d2VMMQyi9cAgMYC9jKc+3mW62/yVl4j
# nDcw6ULJsBkOkrcPLUwqj7poS0T2+2JMzPP+jZ1h90/QpZnBkhdtixMiWDVgh60K
# mLmzXiqJc6lGwqoUqpq/1HVHm+Pc2B6+wCy/GwCcjw5rmzajLbmqGygEgaj/OLoa
# nEWP6Y52Hflef3XLvYnhEY4kSirMQhtberRvaI+5YsD3XVxHGBjlIli5u+NrLedI
# xsE88WzKXqZjj9Zi5ybJL2WjeXuOTbswB7XjkZbErg7ebeAQUQiS/uRGZ58NHs57
# ZPUfECcgJC+v2wIDAQABo4IBFjCCARIwHwYDVR0jBBgwFoAUU3m/WqorSs9UgOHY
# m8Cd8rIDZsswHQYDVR0OBBYEFPZ3at0//QET/xahbIICL9AKPRQlMA4GA1UdDwEB
# /wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MBMGA1UdJQQMMAoGCCsGAQUFBwMIMBEG
# A1UdIAQKMAgwBgYEVR0gADBQBgNVHR8ESTBHMEWgQ6BBhj9odHRwOi8vY3JsLnVz
# ZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNBQ2VydGlmaWNhdGlvbkF1dGhvcml0eS5j
# cmwwNQYIKwYBBQUHAQEEKTAnMCUGCCsGAQUFBzABhhlodHRwOi8vb2NzcC51c2Vy
# dHJ1c3QuY29tMA0GCSqGSIb3DQEBDAUAA4ICAQAOvmVB7WhEuOWhxdQRh+S3OyWM
# 637ayBeR7djxQ8SihTnLf2sABFoB0DFR6JfWS0snf6WDG2gtCGflwVvcYXZJJlFf
# ym1Doi+4PfDP8s0cqlDmdfyGOwMtGGzJ4iImyaz3IBae91g50QyrVbrUoT0mUGQH
# bRcF57olpfHhQEStz5i6hJvVLFV/ueQ21SM99zG4W2tB1ExGL98idX8ChsTwbD/z
# IExAopoe3l6JrzJtPxj8V9rocAnLP2C8Q5wXVVZcbw4x4ztXLsGzqZIiRh5i111T
# W7HV1AtsQa6vXy633vCAbAOIaKcLAo/IU7sClyZUk62XD0VUnHD+YvVNvIGezjM6
# CRpcWed/ODiptK+evDKPU2K6synimYBaNH49v9Ih24+eYXNtI38byt5kIvh+8aW8
# 8WThRpv8lUJKaPn37+YHYafob9Rg7LyTrSYpyZoBmwRWSE4W6iPjB7wJjJpH2930
# 8ZkpKKdpkiS9WNsf/eeUtvRrtIEiSJHN899L1P4l6zKVsdrUu1FX1T/ubSrsxrYJ
# D+3f3aKg6yxdbugot06YwGXXiy5UUGZvOu3lXlxA+fC13dQ5OlL2gIb5lmF6Ii8+
# CQOYDwXM+yd9dbmocQsHjcRPsccUd5E9FiswEqORvz8g3s+jR3SFCgXhN4wz7NgA
# nOgpCdUo4uDyllU9PzGCBJIwggSOAgEBMGowVTELMAkGA1UEBhMCR0IxGDAWBgNV
# BAoTD1NlY3RpZ28gTGltaXRlZDEsMCoGA1UEAxMjU2VjdGlnbyBQdWJsaWMgVGlt
# ZSBTdGFtcGluZyBDQSBSMzYCEQCkKTtuHt3XpzQIh616TrckMA0GCWCGSAFlAwQC
# AgUAoIIB+TAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkF
# MQ8XDTI2MDEzMDEwNTAzN1owPwYJKoZIhvcNAQkEMTIEMNi5AV1wKxovxoe8cACn
# LQ/aYFFcWva0wvInMBAX9h/yj9lXeHqs9KcZvMr/7lOzQzCCAXoGCyqGSIb3DQEJ
# EAIMMYIBaTCCAWUwggFhMBYEFDjJFIEQRLTcZj6T1HRLgUGGqbWxMIGHBBTGrlTk
# eIbxfD1VEkiMacNKevnC3TBvMFukWTBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMP
# U2VjdGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBUaW1lIFN0
# YW1waW5nIFJvb3QgUjQ2AhB6I67aU2mWD5HIPlz0x+M/MIG8BBSFPWMtk4KCYXzQ
# kDXEkd6SwULaxzCBozCBjqSBizCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5l
# dyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNF
# UlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNh
# dGlvbiBBdXRob3JpdHkCEDbCsL18Gzrno7PdNsvJdWgwDQYJKoZIhvcNAQEBBQAE
# ggIAGFsQpqSfr1YGGLPYneGdsFFw5UV0y3nS264QwwJnrPrlaDjUKePbKaH+kH0k
# bZsAY5NscoSzRn3Yjq0q/cdKpw0Vs/d8TzCtis2hPfjFZqTFVGnUVDdUUmydabwU
# tBk4U0eRFHY7+6jgZ2lIBJFh/2xLaWmzcGuDf3kohkJKkLXZxNrjiLA06UG8e/L5
# ghwMxwm/hPvLX1FLKm0tV0ObBkaep0oMOf8YZs3X83pHz+d6cvkAIywGP2T9cW/B
# o/XI3RDlc/2TrEmuIKoF8uuk/4U76gvMPRBd0R1b76OwubvRVifYeHDANJ28BiA0
# jq3ps92e9YsTUnOUkcgdFZk2I09TnR1LVMhpUHuS6ZNwZzep/j2EfZOz/K6BZYb8
# f5USBV4j8lx+7KpuKCTAW+2Qw2DZU1+JnajZubq0BwQlpSa/z4yIoEpAvUEKWrfR
# 7J843QQj40Xjb0eLL+SJ/RKAsQLVrxuPWwiZk4A3daxQ7fiZbjDtCDlas/i6pvU8
# Ws/o53ko910vSl4Bfg/474vN7H2BPOqcomQp91zJEfeaZ0EgBJ1PNlF2Vz7X3io2
# Q5CGDiIVedXzlXRdr/9k/QNMPzCesmBg6BoBfM+zLjpYj1abimEZwlEnpcuwfDJB
# aYU9LOimR/gsUCHGXibxsCCyFBZtL60aO9EuITSImTfee7E=
# SIG # End signature block
