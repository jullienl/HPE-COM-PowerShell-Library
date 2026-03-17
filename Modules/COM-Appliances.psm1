#------------------- FUNCTIONS FOR COMPUTE OPS MANAGEMENT APPLIANCES -----------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1

# Public functions
Function Get-HPECOMAppliance {
    <#
    .SYNOPSIS
    Retrieve the list of appliances.
    
    .DESCRIPTION
    This Cmdlet returns a collection of appliance resources in the specified region. 
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.  

    .PARAMETER Name
    Specifies the name or IP address of the appliance resource.
    This parameter accepts both hostnames and IP addresses. The cmdlet automatically detects whether the provided value is an IP address or hostname.
    You can also use the -IPAddress alias for clarity when providing an IP address.

    .PARAMETER Limit 
    This parameter allows you to define the number of appliances to be displayed. 
   
    .PARAMETER Type 
    Optional parameter that can be used to get a certain type of appliances such as HPE Secure Gateway appliances, HPE OneView VM - VMware vSphere appliances, or HPE Synergy Composer appliances.

    .PARAMETER ShowActivationKey
    Optional switch parameter that can be used to display the activation key of the appliance.

    .PARAMETER ShowActivities
    Optional switch parameter that can be used to retrieve activities from the last month for the specified appliance(s). 
    When used with -Name, it retrieves activities for that specific appliance.
    When used without -Name, it retrieves activities for all appliances in the region using the Appliance category filter.

    .PARAMETER ShowJobs
    Optional switch parameter that can be used to retrieve jobs from the last month for the specified appliance(s).
    When used with -Name, it retrieves jobs for that specific appliance.
    When used without -Name, it retrieves jobs for all appliances in the region using the Appliance category filter.

    .PARAMETER ShowSettings
    Optional switch parameter that can be used to retrieve OneView settings available on the specified appliance.
    This parameter requires -Name to identify the specific appliance and can only be used with OneView appliances (VM or Synergy).
    The settings retrieved include appliance settings, server profile templates, and software/firmware bundles configured in OneView.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central

    Return all appliances in the central european region. 

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Name oneview.hpelab.net

    Return the OneView appliance named 'oneview.hpelab.net' in the central european region. 

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Name 192.168.1.65

    Return the appliance with IP address '192.168.1.65' in the central european region.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -IPAddress 192.168.1.65

    Return the appliance with IP address '192.168.1.65' in the central european region using the -IPAddress alias.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Name oneview.hpelab.net -ShowActivationKey

    Return the activation key for the OneView appliance named 'oneview.hpelab.net' in the central european region.
    
    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Type OneViewVM

    Return data for all HPE OneView VM - VMware vSphere appliances located in the central European region.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Type SynergyComposer

    Return data for all HPE Synergy Composer appliances located in the central European region.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Type SecureGateway

    Return data for all HPE Secure Gateway Appliance located in the central European region.

    .EXAMPLE
    Get-HPECOMAppliance -Region us-west -name comgw.lab -ShowActivationKey 

    Return the activation key for the Secure Gateway appliance named 'comgw.lab' in the "us-west" region.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Name oneview.hpelab.net -ShowActivities

    Return activities from the last month for the OneView appliance named 'oneview.hpelab.net'.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -ShowActivities

    Return activities from the last month for all appliances in the eu-central region.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Name oneview.hpelab.net -ShowJobs

    Return jobs from the last month for the OneView appliance named 'oneview.hpelab.net'.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -ShowJobs

    Return jobs from the last month for all appliances in the eu-central region.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Name oneview.hpelab.net -ShowSettings

    Return all OneView settings (appliance settings, server templates, software bundles) available on the OneView appliance named 'oneview.hpelab.net'.

    .PARAMETER ShowAssociatedServers
    Optional switch parameter that can be used to retrieve the list of servers associated with the specified OneView appliance.
    This parameter requires -Name to identify the specific appliance and returns the server names and IDs managed by that appliance.

    .PARAMETER ShowCertificate
    Optional switch parameter that can be used to retrieve the TLS certificate (in PEM format) of the specified Secure Gateway appliance.
    This parameter requires -Name to identify the specific appliance and is only supported for HPE Secure Gateway appliances.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Name composer.lj.lab -ShowAssociatedServers

    Return the list of servers associated with the OneView appliance named 'composer.lj.lab' in the eu-central region.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Name sg01.lj.lab -ShowCertificate

    Return the TLS certificate of the Secure Gateway appliance named 'sg01.lj.lab' in the eu-central region.

    .EXAMPLE
    $cert = Get-HPECOMAppliance -Region eu-central -Name sg01.lj.lab -ShowCertificate
    $cert | Set-Content -Path "sg01.lj.lab.pem" -NoNewline

    Retrieve the TLS certificate (PEM format) of the Secure Gateway appliance named 'sg01.lj.lab' and save it as a PEM file.

    
   #>
    [CmdletBinding(DefaultParameterSetName = 'Limit')]
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

        [Parameter (Mandatory, ParameterSetName = 'Name')]  
        [Parameter (ParameterSetName = 'ShowActivities')]
        [Parameter (ParameterSetName = 'ShowJobs')]
        [Parameter (Mandatory, ParameterSetName = 'ShowSettings')]
        [Parameter (Mandatory, ParameterSetName = 'ShowAssociatedServers')]
        [Parameter (Mandatory, ParameterSetName = 'ShowCertificate')]
        [Alias('IPAddress')]
        [String]$Name,

        [Parameter (ParameterSetName = 'Limit')]
        [ValidateScript({ $_ -le 1000 })]
        [int]$Limit,

        [Parameter (ParameterSetName = 'Limit')]
        [Parameter (ParameterSetName = 'ShowActivities')]
        [Parameter (ParameterSetName = 'Name')]
        [Parameter (ParameterSetName = 'ShowJobs')]
        [Parameter (ParameterSetName = 'ShowSettings')]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $environments = @('SynergyComposer', 'OneViewVM', 'SecureGateway')
                $filteredEnvironments = $environments | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredEnvironments | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateScript({
                $validOptions = @('SynergyComposer', 'OneViewVM', 'SecureGateway')
                
                if ($validOptions -contains $_) {
                    $True
                }
                else {
                    throw "'$_' is not a valid option."
                }
                
            })]                
        [String]$Type,

        [Parameter (ParameterSetName = 'Name')]
        [Switch]$ShowActivationKey,

        [Parameter (Mandatory, ParameterSetName = 'ShowActivities')]
        [Switch]$ShowActivities,

        [Parameter (Mandatory, ParameterSetName = 'ShowJobs')]
        [Switch]$ShowJobs,

        [Parameter (Mandatory, ParameterSetName = 'ShowSettings')]
        [Switch]$ShowSettings,

        [Parameter (Mandatory, ParameterSetName = 'ShowAssociatedServers')]
        [Switch]$ShowAssociatedServers,

        [Parameter (Mandatory, ParameterSetName = 'ShowCertificate')]
        [Switch]$ShowCertificate,

        [Switch]$WhatIf
       
    ) 

    Begin {
  
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
      
      
    }
      
      
    Process {

        if ($ShowActivationKey -and (-not $Name) -and (-not $IPAddress)) {
            Throw "When using the -ShowActivationKey switch, you must also specify either the -Name or -IPAddress parameter to identify the specific appliance."
        }
      
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # For ShowSettings/ShowAssociatedServers with WhatIf, we need to get appliances without WhatIf for validation, then apply WhatIf to the detail API call
        $UseWhatIfForInitialCall = $WhatIf -and (-not $ShowSettings) -and (-not $ShowAssociatedServers)

        # No limit by default
        if ($Limit) {

            $Uri = (Get-COMOneViewAppliancesUri) + "?limit=$Limit"
       
        } 
        else {
            
            $Uri = Get-COMOneViewAppliancesUri 
        }           


        try {
            [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $UseWhatIfForInitialCall -Verbose:$VerbosePreference

        }
        catch {

            "[{0}] Exception object: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($_.Exception.data | Out-String) | Write-Verbose

            if ($_.Exception.Message -match 412) {

                "[{0}] Received 412 error due to missing OneView Edition subscription" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                
                Write-Warning "Looks like you do not have a Compute Ops Management - OneView Edition subscription to manage a OneView appliance."
                Return
            }
            else {

                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
        

        $ReturnData = @()
       
        if ($Null -ne $CollectionList) {      

            # Add region to object
            $CollectionList | Add-Member -type NoteProperty -name region -value $Region            
            
            if ($Type) {
                
                switch ($Type) {
                    "SecureGateway" { $_applianceType = "GATEWAY" }
                    "SynergyComposer" { $_applianceType = "SYNERGY" }
                    "OneViewVM" { $_applianceType = "VM" }
                }
                
                $CollectionList = $CollectionList | Where-Object applianceType -eq $_applianceType
            }
            
            
            if ($Name) {
                # Check if $Name is an IP address or a hostname
                if ($Name -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
                    $CollectionList = $CollectionList | Where-Object ipaddress -eq $Name
                }
                else {
                    $CollectionList = $CollectionList | Where-Object name -eq $Name
                }
            }       
            
            if ($CollectionList.applianceType -eq "GATEWAY" -and $ShowActivationKey) {

                try {
                    $ActivationKey = New-HPECOMAppliance -Region $Region -SecureGateway 
                    Return $ActivationKey.ActivationKey
                
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }
            elseif ($ShowActivationKey) {
                    
                $CollectionList = $CollectionList.activationkey
                return $CollectionList 
                
            }
            elseif ($ShowActivities) {

                if ($Name) {
                    # Get activities for specific appliance
                    if (-not $CollectionList -or $CollectionList.Count -eq 0) {
                        return
                    }

                    if ($CollectionList.Count -gt 1) {
                        Write-Warning "Multiple appliances found. Please refine your query to return only one appliance."
                        return
                    }

                    $ApplianceName = $CollectionList.name

                    try {
                        "[{0}] Retrieving activities for appliance '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ApplianceName | Write-Verbose
                        [Array]$Activities = Get-HPECOMActivity -Region $Region -SourceName $ApplianceName -ShowLastMonth -Verbose:$VerbosePreference -WhatIf:$WhatIf -WarningAction SilentlyContinue
                        return $Activities
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }
                } else {
                    # Get activities for all appliances using Category filter
                    "[{0}] Retrieving activities for all appliances in region '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose
                    return Get-HPECOMActivity -Region $Region -Category Appliance -ShowLastMonth -Verbose:$VerbosePreference -WhatIf:$WhatIf -WarningAction SilentlyContinue
                }
            }
            elseif ($ShowJobs) {

                if ($Name) {
                    # Get jobs for specific appliance
                    # Need to get the appliance name first
                    if ($Name -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
                        $ApplianceMatch = $CollectionList | Where-Object ipaddress -eq $Name
                    }
                    else {
                        $ApplianceMatch = $CollectionList | Where-Object name -eq $Name
                    }

                    if (-not $ApplianceMatch -or $ApplianceMatch.Count -eq 0) {
                        return
                    }

                    if ($ApplianceMatch.Count -gt 1) {
                        Write-Warning "Multiple appliances found. Please refine your query to return only one appliance."
                        return
                    }

                    $ApplianceName = $ApplianceMatch.name

                    try {
                        "[{0}] Retrieving jobs for appliance '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ApplianceName | Write-Verbose
                        [Array]$Jobs = Get-HPECOMJob -Region $Region -SourceName $ApplianceName -ShowLastMonth -Verbose:$VerbosePreference -WhatIf:$WhatIf -WarningAction SilentlyContinue
                        return $Jobs
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }
                } else {
                    # Get jobs for all appliances using Category filter
                    "[{0}] Retrieving jobs for all appliances in region '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose
                    return Get-HPECOMJob -Region $Region -Category Appliance -ShowLastMonth -Verbose:$VerbosePreference -WhatIf:$WhatIf -WarningAction SilentlyContinue
                }
            }
            elseif ($ShowSettings) {
                
                # Validate that Name parameter is provided (should not happen due to parameter sets, but defensive check)
                if (-not $Name) {
                    "[{0}] ShowSettings requires Name parameter" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    
                    if ($WhatIf) {
                        Write-Warning "The -ShowSettings parameter requires -Name to identify the specific appliance. Cannot display API request."
                        return
                    }
                    return
                }

                # Get the appliance details
                if (-not $CollectionList -or $CollectionList.Count -eq 0) {
                    "[{0}] Appliance '{1}' not found in region '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
                    
                    if ($WhatIf) {
                        Write-Warning "Appliance not found. Cannot display API request."
                        return
                    }
                    return
                }

                if ($CollectionList.Count -gt 1) {
                    "[{0}] Multiple appliances found matching '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                    
                    if ($WhatIf) {
                        Write-Warning "Multiple appliances found. Please refine your query to return only one appliance. Cannot display API request."
                        return
                    }
                    return
                }

                # Validate it's a OneView appliance (not Secure Gateway)
                if ($CollectionList.applianceType -eq "GATEWAY") {
                    "[{0}] ShowSettings is not supported for Secure Gateway appliances" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    
                    if ($WhatIf) {
                        Write-Warning "The -ShowSettings parameter is only supported for OneView appliances (VM or Synergy), not Secure Gateway appliances. Cannot display API request."
                        return
                    }
                    return
                }

                # Get the appliance ID
                $ApplianceId = $CollectionList.id
                $ApplianceName = $CollectionList.name

                "[{0}] Retrieving OneView settings for appliance '{1}' (ID: {2})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ApplianceName, $ApplianceId | Write-Verbose

                # Build the URI for oneview-settings endpoint using function-style filter syntax
                $SettingsUri = "/compute-ops-mgmt/v1beta1/oneview-settings?filter=eq(applianceId,'{0}')" -f $ApplianceId

                try {
                    [Array]$Settings = Invoke-HPECOMWebRequest -Method Get -Uri $SettingsUri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference -ErrorAction Stop
                    
                    if ($Settings -and $Settings.Count -gt 0) {
                        # Process each settings object
                        $ExpandedSettings = @()
                        
                        foreach ($Setting in $Settings) {
                            # Check if this is an appliance settings object with a settings array
                            if ($Setting.settings -and $Setting.settings.Count -gt 0) {
                                # Expand each setting type into individual objects
                                foreach ($IndividualSetting in $Setting.settings) {
                                    # Extract meaningful status based on settingsType
                                    $Status = switch ($IndividualSetting.settingsType) {
                                        'security' { 
                                            $parts = @()
                                            if ($IndividualSetting.settingsValue.enableServiceAccess) { $parts += "Service Access" }
                                            if ($IndividualSetting.settingsValue.twoFactorAuthenticationEnabled) { $parts += "2FA" }
                                            if ($IndividualSetting.settingsValue.allowSshAccess) { $parts += "SSH" }
                                            if ($parts.Count -gt 0) { "Enabled: $($parts -join ', ')" } else { "Basic Security" }
                                        }
                                        'notifications' { 
                                            if ($IndividualSetting.settingsValue.alertEmailDisabled) { 
                                                "Alert Email Disabled" 
                                            } 
                                            elseif ($IndividualSetting.settingsValue.smtpServer) { 
                                                "SMTP: $($IndividualSetting.settingsValue.smtpServer):$($IndividualSetting.settingsValue.smtpPort)" 
                                            }
                                            else { 
                                                "Alert Email Enabled" 
                                            }
                                        }
                                        'proxy' { 
                                            if ($IndividualSetting.settingsValue.server) { 
                                                "$($IndividualSetting.settingsValue.communicationProtocol): $($IndividualSetting.settingsValue.server):$($IndividualSetting.settingsValue.port)" 
                                            } 
                                            else { "Not Configured" }
                                        }
                                        'snmp' { 
                                            $snmpParts = @()
                                            if ($IndividualSetting.settingsValue.snmpv1ReadCommunityString) { $snmpParts += "SNMPv1" }
                                            if ($IndividualSetting.settingsValue.snmpv3Users) { $snmpParts += "SNMPv3" }
                                            if ($snmpParts.Count -gt 0) { $snmpParts -join ', ' } else { "Not Configured" }
                                        }
                                        'timeAndLocale' { 
                                            "Time: $($IndividualSetting.settingsValue.timeSource), Locale: $($IndividualSetting.settingsValue.localeDisplayName)" 
                                        }
                                        'updates' { 
                                            "$($IndividualSetting.settingsValue.state), $($IndividualSetting.settingsValue.scheduleInterval) ($($IndividualSetting.settingsValue.scheduleDay) $($IndividualSetting.settingsValue.scheduleTimeUTC))" 
                                        }
                                        'globalSettings' { 
                                            $globalParts = @()
                                            if ($IndividualSetting.settingsValue.profileBIOSConsistency) { $globalParts += "BIOS Consistency" }
                                            if ($IndividualSetting.settingsValue.reservedVlanRange) { 
                                                $globalParts += "VLAN Range: $($IndividualSetting.settingsValue.reservedVlanRange.vlanRange)" 
                                            }
                                            if ($globalParts.Count -gt 0) { $globalParts -join ', ' } else { "Configured" }
                                        }
                                        'remoteSupport' { 
                                            if ($IndividualSetting.settingsValue.configuration.enableRemoteSupport) { 
                                                "Enabled, Contact: $($IndividualSetting.settingsValue.contacts.email)" 
                                            } 
                                            else { "Disabled" }
                                        }
                                        default { "Configured" }
                                    }
                                    
                                    $ExpandedSetting = [PSCustomObject]@{
                                        region          = $Region
                                        applianceName   = $ApplianceName
                                        applianceId     = $ApplianceId
                                        name            = $null
                                        settingsType    = $IndividualSetting.settingsType
                                        status          = $Status
                                        settingsValue   = $IndividualSetting.settingsValue
                                        resourceUri     = $Setting.resourceUri
                                        id              = $Setting.id
                                        type            = $Setting.type
                                        createdAt       = $Setting.createdAt
                                        updatedAt       = $Setting.updatedAt
                                    }
                                    $ExpandedSettings += $ExpandedSetting
                                }
                            }
                            else {
                                # If it's a different structure (server templates, software bundles), use as-is
                                $Setting | Add-Member -type NoteProperty -name region -value $Region -Force
                                $Setting | Add-Member -type NoteProperty -name applianceName -value $ApplianceName -Force
                                $Setting | Add-Member -type NoteProperty -name applianceId -value $ApplianceId -Force
                                $ExpandedSettings += $Setting
                            }
                        }
                        
                        # Also add group-level COM settings (server templates, software bundles) that apply to this appliance
                        try {
                            $_AllGroups = Get-HPECOMGroup -Region $Region -Verbose:$false -ErrorAction SilentlyContinue
                            $_applianceGroup = $_AllGroups | Where-Object {
                                $_.deviceType -match '^OVE_APPLIANCE' -and ($_.devices | Where-Object serial -eq $ApplianceId)
                            } | Select-Object -First 1

                            if ($_applianceGroup) {
                                "[{0}] Appliance '{1}' belongs to group '{2}' — fetching group COM settings" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ApplianceName, $_applianceGroup.name | Write-Verbose

                                $_AllComSettings = Get-HPECOMSetting -Region $Region -Verbose:$false -ErrorAction SilentlyContinue
                                $_settingIds     = $_applianceGroup.settingsUris | ForEach-Object { $_.split('/')[-1] }
                                $_groupComSettings = @($_AllComSettings | Where-Object { $_.id -in $_settingIds -and $_.category -match '^OVE_(SERVER_TEMPLATES|SOFTWARE)' })

                                foreach ($_cs in $_groupComSettings) {
                                    $_typeLabel = switch -Regex ($_cs.category) {
                                        '^OVE_SERVER_TEMPLATES_VM'      { 'serverProfileTemplates (VM)' }
                                        '^OVE_SERVER_TEMPLATES_SYNERGY' { 'serverProfileTemplates (Synergy)' }
                                        '^OVE_SOFTWARE_VM'              { 'applianceSoftware (VM)' }
                                        '^OVE_SOFTWARE_SYNERGY'         { 'applianceSoftware (Synergy)' }
                                        default                         { $_cs.category }
                                    }
                                    $_statusLabel = if ($_cs.category -match '^OVE_SERVER_TEMPLATES') {
                                        $count = @($_cs.data[0].templates).Count
                                        "$count template$(if ($count -ne 1) {'s'}) defined in COM setting '$($_cs.name)'"
                                    } else {
                                        "Version $($_cs.applianceVersion) defined in COM setting '$($_cs.name)'"
                                    }
                                    $ExpandedSettings += [PSCustomObject]@{
                                        region        = $Region
                                        applianceName = $ApplianceName
                                        applianceId   = $ApplianceId
                                        name          = $_cs.name
                                        settingsType  = $_typeLabel
                                        status        = $_statusLabel
                                        resourceUri   = $_cs.resourceUri
                                        id            = $_cs.id
                                        type          = $_cs.type
                                        createdAt     = $_cs.createdAt
                                        updatedAt     = $_cs.updatedAt
                                    }
                                }
                            }
                        }
                        catch {
                            "[{0}] Warning: Unable to fetch group COM settings for appliance '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ApplianceName, $_.Exception.Message | Write-Verbose
                        }

                        if ($ExpandedSettings.Count -gt 0) {
                            $ReturnSettings = Invoke-RepackageObjectWithType -RawObject $ExpandedSettings -ObjectName "COM.Appliances.OneViewSettings"
                            return $ReturnSettings | Sort-Object settingsType, category, name
                        }
                    }
                    else {
                        "[{0}] No OneView settings found for appliance '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ApplianceName | Write-Verbose
                        return
                    }
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }
            elseif ($ShowAssociatedServers) {

                # Validate that an appliance was found
                if (-not $CollectionList -or $CollectionList.Count -eq 0) {
                    "[{0}] Appliance '{1}' not found in region '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
                    if ($WhatIf) {
                        Write-Warning "Appliance not found. Cannot display API request."
                        return
                    }
                    return
                }

                if ($CollectionList.Count -gt 1) {
                    "[{0}] Multiple appliances found matching '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                    Write-Warning "Multiple appliances found. Please refine your query to return only one appliance."
                    return
                }

                $ApplianceId = $CollectionList.id
                $ApplianceName = $CollectionList.name

                "[{0}] Retrieving associated servers for appliance '{1}' (ID: {2})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ApplianceName, $ApplianceId | Write-Verbose

                $DetailUri = "/ui-doorway/compute/v2/appliances/{0}" -f $ApplianceId

                try {
                    $ApplianceDetail = Invoke-HPECOMWebRequest -Method Get -Uri $DetailUri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference -ErrorAction Stop

                    if ($WhatIf) { return }

                    if ($ApplianceDetail -and $ApplianceDetail.servers_ -and $ApplianceDetail.servers_.Count -gt 0) {

                        $AssociatedServerIds = $ApplianceDetail.servers_.id

                        "[{0}] Retrieving full server details for {1} server(s) associated with appliance '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $AssociatedServerIds.Count, $ApplianceName | Write-Verbose

                        $AllServers = Invoke-HPECOMWebRequest -Method Get -Uri (Get-COMServersUri) -Region $Region -WhatIfBoolean $False -Verbose:$VerbosePreference -ErrorAction Stop

                        $AssociatedServers = $AllServers | Where-Object { $AssociatedServerIds -contains $_.id } | ForEach-Object {
                            $_ | Add-Member -type NoteProperty -name region -value $Region -Force
                            $_ | Add-Member -type NoteProperty -name applianceName -value $ApplianceName -Force
                            $_.PSObject.TypeNames.Insert(0, 'HPEGreenLake.COM.Servers')
                            $_
                        }

                        return $AssociatedServers
                    }
                    else {
                        "[{0}] No associated servers found for appliance '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ApplianceName | Write-Verbose
                        return
                    }
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }
            elseif ($ShowCertificate) {

                if (-not $CollectionList -or $CollectionList.Count -eq 0) {
                    Write-Warning "Appliance '$Name' not found in region '$Region'."
                    return
                }

                if ($CollectionList.Count -gt 1) {
                    Write-Warning "Multiple appliances found. Please refine your query to return only one appliance."
                    return
                }

                if ($CollectionList.applianceType -ne "GATEWAY") {
                    Write-Warning "The -ShowCertificate parameter is only supported for HPE Secure Gateway appliances. '$($CollectionList.name)' is a $($CollectionList.modelNumber) which does not expose a TLS certificate through this cmdlet."
                    return
                }

                "[{0}] Returning applianceCert for appliance '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CollectionList.name | Write-Verbose

                return $CollectionList.applianceCert
            }
             
            # Enrich each appliance with the server count from the detail endpoint
            foreach ($Appliance in $CollectionList) {
                $_DetailUri = "/ui-doorway/compute/v2/appliances/{0}" -f $Appliance.id
                try {
                    "[{0}] Retrieving server count for appliance '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Appliance.name | Write-Verbose
                    $_ApplianceDetail = Invoke-HPECOMWebRequest -Method Get -Uri $_DetailUri -Region $Region -WhatIfBoolean $False -Verbose:$VerbosePreference
                    $_ServerCount = if ($_ApplianceDetail -and $_ApplianceDetail.servers_) { $_ApplianceDetail.servers_.Count } else { 0 }
                }
                catch {
                    $_ServerCount = 0
                }
                $Appliance | Add-Member -type NoteProperty -name serverCount -value $_ServerCount -Force
            }

            # Enrich each appliance with the name of the OVE group it belongs to
            try {
                $_AllGroups = Get-HPECOMGroup -Region $Region -Verbose:$false -ErrorAction SilentlyContinue
            }
            catch {
                $_AllGroups = $null
            }
            foreach ($Appliance in $CollectionList) {
                $_groupMatch = if ($_AllGroups) {
                    $_AllGroups | Where-Object {
                        $_.deviceType -match '^OVE_APPLIANCE' -and ($_.devices | Where-Object serial -eq $Appliance.id)
                    } | Select-Object -First 1
                }
                $Appliance | Add-Member -type NoteProperty -name groupName -value ($_groupMatch.name) -Force
            }

            $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Appliances"    
    
            $ReturnData = $ReturnData | Sort-Object name, ipaddress
        
            return $ReturnData 
           
        }
        else {

            return
                
        }     

    
    }
}

Function New-HPECOMAppliance {
    <#
    .SYNOPSIS
    Adds an HPE OneView or Secure Gateway appliance for management to a specific region. 

    .DESCRIPTION   
    This cmdlet adds an HPE OneView or Secure Gateway appliance to the specified Compute Ops Management region for management. It generates an activation key that is used to connect the appliance to Compute Ops Management.
    
    For OneView appliances, the activation key can be retrieved using the 'Get-HPECOMAppliance -Name <OV hostname> -ShowActivationKey' cmdlet. 
    This activation key is required to enable Compute Ops Management in OneView using the 'Enable-OVComputeOpsManagement -ActivationKey $ActivationKey' cmdlet from the HPE OneView PowerShell library.

    For Secure Gateway appliances, the same activation key can be used to connect multiple Secure Gateway appliances to Compute Ops Management within 72 hours.

    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the appliance will be located.  
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER SecureGateway    
    Specifies that the appliance to be added is an HPE Secure Gateway appliance. This parameter is mandatory when adding an HPE Secure Gateway appliance.
    
    .PARAMETER OneView    
    Specifies that the appliance to be added is an HPE OneView appliance. This parameter is mandatory when adding an HPE OneView appliance.

    .PARAMETER OneViewID
    Specifies the ID of the OneView appliance to be added to the region. This parameter is mandatory when adding an HPE OneView appliance.

    Note: The OneView ID can be retrieved using the 'Get-OVComputeOpsManagement' cmdlet from the HPE OneView PowerShell library.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    $credentials = Get-Credential
    Connect-OVMgmt -Appliance OV.domain.com -Credential $credentials
    $AddTask = Get-OVComputeOpsManagement | New-HPECOMAppliance -Region eu-central -OneView
    Enable-OVComputeOpsManagement -ActivationKey $AddTask.activationkey
    
    In this example:
    1. Prompts the user to enter their credentials and stores them in the $credentials variable.
    2. Establishes a connection to the OV.domain.com appliance using the Connect-OVMgmt cmdlet, passing the appliance URL (OV.domain.com) and the credentials stored in the $credentials variable.
    3. Retrieves the Compute Ops Management configuration from OneView using the HPE OneView PowerShell library, then pipes the output to add the OneView appliance to the 'eu-central' region.
    4. Activates the Compute Ops Management configuration in OneView using the obtained activation key from the returned $AddTask object with the 'Enable-OVComputeOpsManagement' cmdlet. The activation key is required for enabling Compute Ops Management in OneView.

    .EXAMPLE
    $credentials = Get-Credential
    Connect-OVMgmt -Appliance OV.domain.com -Credential $credentials
    $ApplianceID = (Get-OVComputeOpsManagement).ApplianceID
    $AddTask = New-HPECOMAppliance -Region eu-central -OneView -OneViewID $ApplianceID 
    Enable-OVComputeOpsManagement -ActivationKey $AddTask.activationkey

    In this example:
    1. Prompts the user to enter their credentials and stores them in the $credentials variable.
    2. Establishes a connection to the OV.domain.com appliance using the Connect-OVMgmt cmdlet, passing the appliance URL (OV.domain.com) and the credentials stored in the $credentials variable.
    3. Retrieves the ApplianceID from 'Get-OVComputeOpsManagement'.
    4. Adds the OneView appliance to the 'eu-central' region using the appliance ID.
    5. Activates the Compute Ops Management configuration in OneView using the obtained activation key from the returned $AddTask object with the 'Enable-OVComputeOpsManagement' cmdlet. The activation key is required for enabling Compute Ops Management in OneView.

    .EXAMPLE
    New-HPECOMAppliance -Region us-west -SecureGateway 

    Adds an HPE Secure Gateway appliance to the 'us-west' region and returns the activation key to use in the secure gateway console to connect the appliance to Compute Ops Management.

    .INPUTS
    System.Collections.ArrayList
        OneView appliance details from 'Get-OVComputeOpsManagement' (HPE OneView PowerShell library).

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Region - Name of the region 
        * ApplianceType - Type of the appliance (OneView or Secure Gateway)
        * ID - ID of the OneView appliance attempted to be added to the region
        * ActivationKey - The activation key to be used in the appliance for enabling Compute Ops Management
        * ExpiresOn - The expiration date of the Secure Gateway activation key (72 hours from the time of appliance addition)
        * Status - The status of the addition attempt (Failed for HTTP error return; Complete if addition is successful; Warning if no action is needed) 
        * Details - More information about the status 
        * Exception - Information about any exceptions generated during the operation.
#>

    [CmdletBinding(DefaultParameterSetName = 'OneView')]
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

        [Parameter (Mandatory, ParameterSetName = 'SecureGateway')]
        [Switch]$SecureGateway,

        [Parameter (Mandatory, ParameterSetName = 'OneView')]
        [Switch]$OneView,
                
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'OneView')]
        [alias('ApplianceID')]
        [String]$OneViewID,
                  
        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $AddApplianceStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose


        if ($OneView) {

            # Build object for the output
            $objStatus = [pscustomobject]@{
  
                Region        = $Region   
                ApplianceType = "OneView"
                ID            = $OneViewID
                ActivationKey = $Null                         
                Status        = $Null
                Details       = $Null
                Exception     = $Null
            }

            $Uri = Get-COMOneViewAppliancesCreateUri           
            
            try {
                $CurrentAppliances = Get-HPECOMAppliance -Region $Region 

                $ApplianceSubscrition = Get-HPEGLSubscription -ShowValid -ShowWithAvailableQuantity -ShowServiceSubscriptions | Where-Object { $_.skudescription -match "Compute Ops Management - OneView Edition" }
              
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }

            # Alert if appliance already exists in the region
            if ($CurrentAppliances | Where-Object { $_.ID -eq $OneViewID }) {

                "[{0}] OneView appliance with ID '{1}' is already present in this service instance!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $OneViewID | Write-Verbose
            
                if ($WhatIf) {
                    $ErrorMessage = "OneView appliance '{0}': Resource is already present in the '{1}' region! No action needed." -f $OneViewID, $Region
                    Write-Warning "$ErrorMessage Cannot display API request."
                    return
                }
                else {
                    $objStatus.Status = "Warning"
                    $objStatus.Details = "OneView appliance already exists in '$Region' region. No action needed."
                }

            }
            # Error if COM-OVE license is not available
            elseif (-not $ApplianceSubscrition) {

                "[{0}] No Compute Ops Management - OneView Edition license available in the workspace." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            
                if ($WhatIf) {
                    $ErrorMessage = "No Compute Ops Management - OneView Edition license available in the workspace. Please add a license first using 'New-HPEGLSubscription' to add the appliance."
                    Write-Warning "$ErrorMessage Cannot display API request."
                    return
                }
                else {
                  
                    $objStatus.Status = "Warning"
                    $objStatus.Details = "No Compute Ops Management - OneView Edition license available in the workspace. Please add a license first using 'New-HPEGLSubscription' to add the appliance."
                }

            }
            else {
                
                # Build payload
                $payload = ConvertTo-Json @{
                    id = $OneViewID
                }          
                      
                # Add resource
                try {
                    $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                                
                    if (-not $WhatIf) {
        
                        "[{0}] Add OneView appliance call response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose
                            
                        "[{0}] OneView appliance '{1}' successfully added to '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $OneViewID, $Region | Write-Verbose
                                
                        $objStatus.Status = "Complete"
                        $objStatus.Details = "Use 'Enable-OVComputeOpsManagement -ActivationKey <activation key>' from the OneView Powershell library to activate the appliance for Compute Ops Management"
                        $objStatus.ActivationKey = $Response.ActivationKey
            
                    }
            
                }
                catch {
            
                    if (-not $WhatIf) {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "OneView appliance cannot be added to $Region region!"}
                        $objStatus.Exception = $Global:HPECOMInvokeReturnData 
            
                    }
                }   
            }
    
                    
            if (-not $WhatIf) {
                [void] $AddApplianceStatus.add($objStatus)
            }

        }
        elseif ($SecureGateway) {

            # Build object for the output
            $objStatus = [pscustomobject]@{
  
                Region        = $Region   
                ApplianceType = "Secure Gateway"
                ActivationKey = $Null   
                ExpiresOn     = (get-date).AddHours(72)
                Status        = $Null
                Details       = $Null
                Exception     = $Null
            }

            $Uri = Get-COMActivationKeysUri

            
            # Build payload
            $payload = ConvertTo-Json @{
                expirationInHours = 72
                targetDevice      = "SECURE_GATEWAY"
            }          
                  
  
            # Add resource
            try {
                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                            
                if (-not $WhatIf) {
    
                    "[{0}] Add Secure Gateway appliance call response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose
                        
                    "[{0}] Secure Gateway appliance activation key successfully generated for '{1}' region: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, $Response.activationKey | Write-Verbose
                            
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Enter the activation key in the secure gateway console to connect the appliance(s) to Compute Ops Management."
                    $objStatus.ActivationKey = $Response.ActivationKey
        
                }
        
            }
            catch {
        
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Secure Gateway appliance activation key cannot be generated!"}
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
        
                }
            }   

            if (-not $WhatIf) {
                [void] $AddApplianceStatus.add($objStatus)
            }

        }          
    }

    end {

        if ($AddApplianceStatus.Count -gt 0) {

            if ($OneView) {

                $AddApplianceStatus = Invoke-RepackageObjectWithType -RawObject $AddApplianceStatus -ObjectName "COM.Appliances.OneView"    
            }
            elseif ($SecureGateway) {

                $AddApplianceStatus = Invoke-RepackageObjectWithType -RawObject $AddApplianceStatus -ObjectName "COM.Appliances.SecureGateway"    
            }

            Return $AddApplianceStatus
        }


    }
}

Function Remove-HPECOMAppliance {
    <#
    .SYNOPSIS
    Remove an appliance from management.

   .DESCRIPTION   
    This cmdlet removes an appliance from a specified Compute Ops Management region. 

    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the appliance is located.  
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name
    Specifies the name of the appliance resource.      

    .PARAMETER IPAddress
    Specifies the IP address of the appliance resource.    

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

   .EXAMPLE
    Remove-HPECOMAppliance -Region eu-central -Name oneview.lab
    
    This example removes the appliance named 'oneview.lab' from the eu-central region.
        
    .EXAMPLE
    Remove-HPECOMAppliance -Region eu-central -IPAddress 192.168.1.22

    This example removes the appliance with the IP address '192.168.1.22' from the eu-central region.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Type SynergyComposer | Remove-HPECOMAppliance 

    This example removes all Synergy Composer appliances from the eu-central region.

    .EXAMPLE
    "192.168.1.10", "192.168.1.20" | Remove-HPECOMAppliance -Region eu-central 

    This example removes the appliances with the IP addresses '192.168.1.10' and '192.168.1.20' from the eu-central region.

    .EXAMPLE
    $ApplianceID = (Get-OVComputeOpsManagement ).ApplianceID
    Remove-HPECOMAppliance -Region eu-central -Hostname $ApplianceID 

    This example removes a OneView appliance from the 'eu-central' region using the appliance ID returned by the 'Get-OVComputeOpsManagement' cmdlet from the HPE OneView PowerShell library. This is typically done for appliances that have not been activated.
    
    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the appliance's IP addresses.

    System.Collections.ArrayList
        A list of OneView appliances from 'Get-HPECOMAppliance'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - Name of the appliance attempted to be removed from the region
        * Region - Name of the region 
        * Status - The status of the removal attempt (Failed for http error return; Complete if removal is successful; Warning if no action is needed) 
        * Details - Additional information about the status.
        * Exception: Information about any exceptions generated during the operation.

   #>

    [CmdletBinding(DefaultParameterSetName = 'Name')]
    Param( 

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)] 
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

        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Name')]
        [String]$Name,

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'IP')]
        [ValidateScript({ [String]::IsNullOrEmpty($_) -or $_ -match [Net.IPAddress]$_ })]
        [string]$IPAddress,
                  
        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $RemoveApplianceStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose


        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name      = $Null
            Region    = $Region   
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

        try {

            if ($Name) {
    
                $ParamUsed = $Name
    
                $_Appliance = Get-HPECOMAppliance -Region $Region -Name $Name
            }
            else {
    
                $ParamUsed = $IPAddress
    
                $_Appliance = Get-HPECOMAppliance -Region $Region -IPAddress $IPAddress
    
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }
        

        $objStatus.name = $ParamUsed

        if (-not $_Appliance) {
                
            # Must return a message if not found

            if ($WhatIf) {

                $ErrorMessage = "Appliance '{0}': Resource cannot be found in the '{1}' region!" -f $ParamUsed, $Region
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "Appliance cannot be found in the region!"
              
            }

        }
        else {   
            
            $Uri = $_Appliance.resourceUri                    
              
            try {
                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method DELETE -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                        
                if (-not $WhatIf) {

                    "[{0}] Remove appliance call response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose
                    
                    "[{0}] Appliance '{1}' successfully removed from '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ParamUsed, $Region | Write-Verbose
                        
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Appliance successfully removed from $Region region"
    
                }
    
            }
            catch {
    
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Appliance cannot be removed from $Region region!"}
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
    
                }
            }   
            
        }

        if (-not $WhatIf) {
            [void] $RemoveApplianceStatus.add($objStatus)
        }

    }

    end {

        if ($RemoveApplianceStatus.Count -gt 0) {

            $RemoveApplianceStatus = Invoke-RepackageObjectWithType -RawObject $RemoveApplianceStatus -ObjectName "COM.objStatus.NSDE"  
            Return $RemoveApplianceStatus
        }


    }
}

Function Get-HPECOMApplianceFirmwareBundle {
    <#
    .SYNOPSIS
    Retrieve the list of appliance firmware bundles in the specified region.

    .DESCRIPTION
    This Cmdlet returns a collection of appliance firmware bundles that are available to update an appliance.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Version 
    Optional parameter that can be used to display the appliance firmware bundles of a specific version such as 8.6, 8.60 or 8.60.01.

    .PARAMETER LatestVersion 
    Optional parameter that can be used to display the latest appliance firmware bundles version.

    .PARAMETER Type 
    Optional parameter that can be used to display the appliance firmware bundles of a specific type such as VM or Synergy.

    .PARAMETER SupportedUpgrades 
    Optional parameter to show the supported upgrade paths for upgrading an appliance with the specified bundle version (or latest version if -LatestVersion is used). 
    The list returns the versions from which an appliance can be upgraded. This parameter requires either the -Version or -LatestVersion parameter to be specified.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMApplianceFirmwareBundle -Region eu-central 

    Return all appliance firmware bundles data in the central european region. 

    .EXAMPLE
    Get-HPECOMApplianceFirmwareBundle -Region eu-central -Version "8.9" 

    Return all appliance firmware bundles data for a specified version. 

    .EXAMPLE
    Get-HPECOMApplianceFirmwareBundle -Region eu-central -Version "8.9" -Type Synergy

    Return all Synergy appliance firmware bundles data for a specified version. 

    .EXAMPLE
    Get-HPECOMApplianceFirmwareBundle -Region eu-central -LatestVersion

    Return the latest appliance firmware bundles version. 

    .EXAMPLE
    Get-HPECOMApplianceFirmwareBundle -Region eu-central -Version 10.00.00 -Type Synergy -SupportedUpgrades 

    Return the supported upgrade paths for upgrading a Synergy appliance to version 10.00.00.

    .EXAMPLE
    Get-HPECOMApplianceFirmwareBundle -Region eu-central -LatestVersion -Type VM -SupportedUpgrades

    Return the supported upgrade paths for upgrading a VM appliance to the latest version.

    
   #>
    [CmdletBinding(DefaultParameterSetName = 'Version')]
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

        [Parameter (Mandatory, ParameterSetName = 'SupportedUpgrades')]
        [Parameter (ParameterSetName = 'Version', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("Name")]
        [String]$Version,

        [Parameter (ParameterSetName = 'Latest')]
        [Switch]$LatestVersion,

        [Parameter (ParameterSetName = 'Latest')]
        [Parameter (Mandatory, ParameterSetName = 'SupportedUpgrades')]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $environments = @('Synergy', 'VM')
                $filteredEnvironments = $environments | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredEnvironments | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateScript({
                $validOptions = @('Synergy', 'VM')
                
                if ($validOptions -contains $_) {
                    $True
                }
                else {
                    throw "'$_' is not a valid option."
                }
                
            })]
        [String]$Type,

        [Parameter (ParameterSetName = 'Latest')]
        [Parameter (ParameterSetName = 'SupportedUpgrades')]
        [Switch]$SupportedUpgrades,

        [Switch]$WhatIf
       
    ) 


    Begin {
  
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
      
        # If supported upgrades is specified, ensure that either version or latestversion is also specified
        if ($SupportedUpgrades -and -not ($Version -or $LatestVersion)) {
            Throw "The -SupportedUpgrades parameter requires either the -Version or -LatestVersion parameter to be specified."
        }
      
    }
      
      
    Process {
      
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose    

        $Uri = Get-COMApplianceFirmwareBundlesUri

        try {
            [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
               
        }

        $ReturnData = @()
       
        if ($Null -ne $CollectionList) {     
                

            if ($Version) {

                $CollectionList = $CollectionList | Where-Object applianceVersion -match $Version

            }   

            if ($Type) {

                $CollectionList = $CollectionList | Where-Object applianceType -match $Type

            }  

            if ($LatestVersion) {

                $Latestversionitems = @()
                $maxVersion = [version]'0.0.0'

                foreach ($item in $CollectionList) {
                    $currentVersion = [version]$item.applianceVersion
                    if ($currentVersion -gt $maxVersion) {
                        $maxVersion = $currentVersion
                        $Latestversionitems = @()
                        $Latestversionitems += $item
                    }
                    elseif ($currentVersion -eq $maxVersion) {
                        # If current version matches the max version, add it to the list
                        $Latestversionitems += $item
                    }
                }

                $CollectionList = $Latestversionitems

            }  

            
            if ($SupportedUpgrades) {

                $CollectionList = $CollectionList.supportedUpgrades

            } 

            # Add region and a true [version]-typed property for correct numeric sorting
            $CollectionList | ForEach-Object {
                $_ | Add-Member -Type NoteProperty -Name region  -Value $Region -Force
                $_ | Add-Member -Type NoteProperty -Name version -Value ([version]$_.applianceVersion) -Force
            }

            $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.ApplianceFirmwareBundles"    
    
            $ReturnData = $ReturnData | Sort-Object version -Descending
        
            return $ReturnData 
                
        }
        else {

            return
                
        }     

    
    }
}


Function Get-HPECOMOneViewServerProfileTemplate {
    <#
    .SYNOPSIS
    Retrieve OneView server profile templates from a Compute Ops Management region.

    .DESCRIPTION
    This cmdlet returns the list of OneView server profile templates synchronised from all connected OneView appliances in the specified region.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name
    Specifies the name of the server profile template to retrieve. When omitted, all templates are returned.

    .PARAMETER ApplianceName
    Filters results to templates belonging to a specific OneView appliance.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMOneViewServerProfileTemplate -Region eu-central

    Return all OneView server profile templates in the eu-central region.

    .EXAMPLE
    Get-HPECOMOneViewServerProfileTemplate -Region eu-central -Name "ESXi_BFS_EG_100G"

    Return the server profile template named 'ESXi_BFS_EG_100G' in the eu-central region.

    .EXAMPLE
    Get-HPECOMOneViewServerProfileTemplate -Region eu-central -ApplianceName "composer.lj.lab"

    Return all server profile templates from the 'composer.lj.lab' OneView appliance in the eu-central region.

    .PARAMETER ShowAttributes
    Displays a summary of the key template attributes (BIOS, boot, firmware, storage, connections, etc.) alongside the template name.

    .EXAMPLE
    Get-HPECOMOneViewServerProfileTemplate -Region eu-central -ShowAttributes

    Return all OneView server profile templates in the eu-central region with a flattened view of their main attributes (BIOS, boot mode, firmware, SAN/local storage, connections, management processor).

    .INPUTS
    None. You cannot pipe objects to this cmdlet.

    .OUTPUTS
    HPEGreenLake.COM.OneViewServerTemplates
        Returns a collection of OneView server profile template objects.

    HPEGreenLake.COM.OneViewServerTemplates.Attributes
        Returns a flattened collection of OneView server profile template attribute objects when -ShowAttributes is used.
    #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param(

        [Parameter(Mandatory, ParameterSetName = 'Default')]
        [Parameter(Mandatory, ParameterSetName = 'ShowAttributes')]
        [ValidateScript({
                if (-not $Global:HPEGreenLakeSession -or -not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use HPE GreenLake cmdlets."
                }
                if (($_ -in $Global:HPECOMRegions.region)) {
                    $true
                }
                else {
                    Throw "The COM region '$_' is not provisioned in this workspace! Please specify a valid region code (e.g., 'us-west', 'eu-central'). `nYou can retrieve the region code using: Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned. `nYou can also use the Tab key for auto-completion to see the list of provisioned region codes."
                }
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Global:HPECOMRegions.region | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [String]$Region,

        [Parameter(ParameterSetName = 'Default')]
        [Parameter(Mandatory, ParameterSetName = 'ShowAttributes')]
        [String]$Name,

        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'ShowAttributes')]
        [String]$ApplianceName,

        [Parameter(Mandatory, ParameterSetName = 'ShowAttributes')]
        [Switch]$ShowAttributes,

        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'ShowAttributes')]
        [Switch]$WhatIf
    )

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | Out-String) | Write-Verbose

        # This API enforces a maximum page size of 50; build URI with explicit limit
        # so the web request wrapper does not auto-append ?limit=100.
        $PageSize = 50
        $AllItems  = [System.Collections.ArrayList]::new()

        # Paginate until all results are collected
        $Offset = 0
        do {
            $Uri = (Get-COMOneViewServerTemplatesUri) + "?limit=$PageSize&offset=$Offset"
            try {
                [Array]$Page = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
            }
            catch {
                "[{0}] Exception object: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($_.Exception.data | Out-String) | Write-Verbose
                $PSCmdlet.ThrowTerminatingError($_)
            }
            if ($Page -and $Page.Count -gt 0) {
                [void]$AllItems.AddRange($Page)
                $Offset += $PageSize
            }
            else {
                break
            }
        } while ($Page.Count -eq $PageSize)

        $CollectionList = $AllItems.ToArray()

        if ($CollectionList -and $CollectionList.Count -gt 0) {

            $CollectionList | Add-Member -Type NoteProperty -Name region -Value $Region

            if ($ApplianceName) {
                $CollectionList = $CollectionList | Where-Object applianceName -eq $ApplianceName
            }

            if ($Name) {
                $CollectionList = $CollectionList | Where-Object name -eq $Name
            }

            if (-not $CollectionList) {
                "[{0}] No OneView server template found matching the specified filter(s)" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                return
            }

            if ($ShowAttributes) {
                $AttributeList = $CollectionList | ForEach-Object {
                    [PSCustomObject]@{
                        name              = $_.name
                        applianceName     = $_.applianceName
                        status            = $_.status
                        biosManaged       = $_.attributes.bios.manageBios
                        bootManaged       = $_.attributes.boot.manageBoot
                        bootMode          = $_.attributes.bootMode.mode
                        firmwareManaged   = $_.attributes.firmware.manageFirmware
                        sanStorageManaged = $_.attributes.sanStorage.manageSanStorage
                        connections       = ($_.attributes.connectionSettings.connections | Measure-Object).Count
                        mpManaged         = $_.attributes.managementProcessor.manageMp
                    }
                }
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $AttributeList -ObjectName "COM.OneViewServerTemplates.Attributes"
                $ReturnData = $ReturnData | Sort-Object name
                return $ReturnData
            }

            $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.OneViewServerTemplates"

            $ReturnData = $ReturnData | Sort-Object name

            return $ReturnData
        }
        else {
            return
        }
    }
}


Function Invoke-HPECOMApplianceRefreshSettings {
    <#
    .SYNOPSIS
    Refresh the settings of a OneView appliance in Compute Ops Management.

    .DESCRIPTION
    This Cmdlet triggers a settings refresh job for a OneView appliance (VM or Synergy Composer) registered in Compute Ops Management.

    The refresh operation retrieves the current appliance configuration and updates the Compute Ops Management inventory with the latest settings data.

    By default, the Cmdlet waits for the job to complete and returns a status object. Use -Async to return the job resource immediately for monitoring, or -ScheduleTime to schedule the refresh for a later time.

    Only appliances with an applianceType of 'VM' or 'SYNERGY' are supported. HPE Secure Gateway appliances are not supported.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the appliance is registered.
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name
    Specifies the hostname or IP address of the OneView appliance to refresh settings for.

    .PARAMETER ScheduleTime
    Specifies the date and time when the refresh should be executed.
    This parameter accepts a DateTime object or a string representation of a date and time.
    If not specified, the refresh will be executed immediately.

    Examples for setting the date and time using `Get-Date`:
    - (Get-Date).AddMonths(6)
    - (Get-Date).AddDays(15)
    - (Get-Date).AddHours(3)
    Example for using a specific date string:
    - "2024-05-20 08:00:00"

    .PARAMETER Interval
    Specifies the interval at which the refresh should be repeated. This parameter accepts a string representation of an ISO 8601 period duration. If not specified, the refresh will not be repeated.

    This parameter supports common ISO 8601 period durations such as:
    - P1D (1 Day)
    - P1W (1 Week)
    - P1M (1 Month)
    - P1Y (1 Year)

    The accepted formats include periods (P) referencing days, weeks, months, years but not time (T) designations that reference hours, minutes, and seconds.

    A valid interval must be greater than 15 minutes (PT15M) and less than 1 year (P1Y).

    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties). By default, the Cmdlet will wait for the job to complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Invoke-HPECOMApplianceRefreshSettings -Region eu-central -Name "oneview.domain.lab"

    Triggers a settings refresh for the specified OneView appliance in the 'eu-central' region and waits for completion.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central | Invoke-HPECOMApplianceRefreshSettings

    Triggers a settings refresh for all OneView appliances in the 'eu-central' region and waits for each job to complete.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Name "oneview.domain.lab" | Invoke-HPECOMApplianceRefreshSettings -Async

    Triggers a settings refresh and immediately returns the job resource to monitor.

    .EXAMPLE
    Invoke-HPECOMApplianceRefreshSettings -Region eu-central -Name "oneview.domain.lab" -ScheduleTime (Get-Date).AddHours(2)

    Schedules a settings refresh to run 2 hours from now.

    .EXAMPLE
    Invoke-HPECOMApplianceRefreshSettings -Region eu-central -Name "oneview.domain.lab" -ScheduleTime (Get-Date).AddDays(1) -Interval P1W

    Schedules a weekly settings refresh starting tomorrow.

    .INPUTS
    System.Collections.ArrayList
        List of appliance(s) from 'Get-HPECOMAppliance'.

    .OUTPUTS
    HPEGreenLake.COM.Appliances.RefreshSettings.Status [System.Management.Automation.PSCustomObject]

        - When the job completes (default synchronous mode), the returned object contains:
            - Name - Hostname of the appliance for which the refresh was attempted
            - Region - Name of the region where the refresh was triggered
            - Status - Status of the refresh attempt (Complete / Failed / Warning)
            - Details - More information about the status
            - Exception - Information about any exceptions generated during the operation

        - If the `-Async` switch is used, the cmdlet returns the job resource immediately, allowing you to monitor its progress using the `state` and `resultCode` properties, or by passing the job object to `Wait-HPECOMJobComplete`.

    HPEGreenLake.COM.Schedules [System.Management.Automation.PSCustomObject]

        - The schedule object that includes the schedule details when `-ScheduleTime` is used.

    #>

    [CmdletBinding(DefaultParameterSetName = 'Async')]
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
        [Alias('IPAddress')]
        [String]$Name,

        [Parameter (Mandatory, ParameterSetName = 'Schedule')]
        [ValidateScript({
                if ($_ -ge (Get-Date) -and $_ -le (Get-Date).AddYears(1)) {
                    $true
                }
                else {
                    throw "The ScheduleTime must be within one year from the current date."
                }
            })]
        [DateTime]$ScheduleTime,

        [ValidateScript({
                # Validate ISO 8601 duration format
                if ($_ -notmatch '^P(?!$)(\d+Y)?(\d+M)?(\d+W)?(\d+D)?(T(\d+H)?(\d+M)?(\d+S)?)?$') {
                    throw "Invalid duration format. Please use an ISO 8601 period interval (e.g., P1D, P1W, P1M, P1Y, PT1H, PT15M)"
                }

                # Extract duration parts
                $years   = [int]($matches[1] -replace '\D', '')
                $months  = [int]($matches[2] -replace '\D', '')
                $weeks   = [int]($matches[3] -replace '\D', '')
                $days    = [int]($matches[4] -replace '\D', '')
                $hours   = [int]($matches[6] -replace '\D', '')
                $minutes = [int]($matches[7] -replace '\D', '')
                $seconds = [int]($matches[8] -replace '\D', '')

                # Calculate total duration in seconds (approximate months/years)
                $totalSeconds = 0
                if ($years)   { $totalSeconds += $years * 365 * 24 * 3600 }
                if ($months)  { $totalSeconds += $months * 30 * 24 * 3600 }
                if ($weeks)   { $totalSeconds += $weeks * 7 * 24 * 3600 }
                if ($days)    { $totalSeconds += $days * 24 * 3600 }
                if ($hours)   { $totalSeconds += $hours * 3600 }
                if ($minutes) { $totalSeconds += $minutes * 60 }
                if ($seconds) { $totalSeconds += $seconds }

                $minSeconds = 15 * 60
                $maxSeconds = 365 * 24 * 3600  # 1 year

                if ($totalSeconds -lt $minSeconds) {
                    throw "The interval must be greater than 15 minutes (PT15M)."
                }
                if ($totalSeconds -gt $maxSeconds) {
                    throw "The interval must be less than 1 year (P1Y)."
                }
                return $true
            })]
        [Parameter (ParameterSetName = 'Schedule')]
        [String]$Interval,

        [Parameter (ParameterSetName = 'Async')]
        [switch]$Async,

        [Switch]$WhatIf
    )

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $StatusList = [System.Collections.ArrayList]::new()

        $_JobTemplateName = 'GetOneViewSettings'
        $JobTemplateId    = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id
        $JobsUri          = Get-COMJobsUri

        "[{0}] Job template '{1}' ID: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_JobTemplateName, $JobTemplateId | Write-Verbose

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | Out-String) | Write-Verbose

        try {
            $ApplianceResource = Get-HPECOMAppliance -Region $Region -Name $Name -Verbose:$false
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        # Build object for the output (used in synchronous mode)
        $objStatus = [pscustomobject]@{
            Name      = $Name
            Region    = $Region
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

        if (-not $ApplianceResource) {

            $ErrorMessage = "Appliance '{0}' cannot be found in the '{1}' region!" -f $Name, $Region
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = $ErrorMessage
            }

        }
        elseif ($ApplianceResource.applianceType -eq "GATEWAY") {

            $ErrorMessage = "Appliance '{0}': Settings refresh is only supported for OneView appliances (VM or Synergy). HPE Secure Gateway appliances are not supported." -f $Name
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = $ErrorMessage
            }

        }
        elseif (-not $JobTemplateId) {

            $ErrorMessage = "Job template '$_JobTemplateName' cannot be found in the loaded templates. Ensure you are connected and job templates are loaded."
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = $ErrorMessage
            }

        }
        else {

            $_ApplianceResourceUri = $ApplianceResource.resourceUri
            $_ApplianceId         = $ApplianceResource.deviceId
            # Construct the oneview-appliance URI (required by GetOneViewSettings job template)
            $_OneViewApplianceUri = "/compute-ops-mgmt/v1beta1/oneview-appliances/" + $_ApplianceId

            if ($ScheduleTime) {

                $Uri = Get-COMSchedulesUri

                $_Body = @{
                    jobTemplateUri = "/api/compute/v1/job-templates/" + $JobTemplateId
                    resourceUri    = $_OneViewApplianceUri
                }

                $Operation = @{
                    type   = "REST"
                    method = "POST"
                    uri    = "/api/compute/v1/jobs"
                    body   = $_Body
                }

                $randomNumber = Get-Random -Minimum 000000 -Maximum 999999

                $ScheduleName = "$($Name)_RefreshSettings_Schedule_$($randomNumber)"
                $Description  = "Scheduled task to refresh OneView appliance settings for '$($Name)'"

                if ($Interval) {
                    $Schedule = @{
                        startAt  = $ScheduleTime.ToString("o")
                        interval = $Interval
                    }
                }
                else {
                    $Schedule = @{
                        startAt = $ScheduleTime.ToString("o")
                    }
                }

                $payload = @{
                    name                  = $ScheduleName
                    description           = $Description
                    associatedResourceUri = $_OneViewApplianceUri
                    purpose               = $Null
                    schedule              = $Schedule
                    operation             = $Operation
                }

            }
            else {

                $Uri = $JobsUri

                $payload = @{
                    jobTemplate  = $JobTemplateId
                    resourceId   = $_ApplianceId
                    resourceType = "compute-ops-mgmt/oneview-appliance"
                }
            }

            $payload = ConvertTo-Json $payload -Depth 10

            try {
                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

                if ($ScheduleTime) {

                    if (-not $WhatIf) {
                        $ReturnData = Invoke-RepackageObjectWithType -RawObject $Response -ObjectName "COM.Schedules"
                        "[{0}] Schedule created for appliance '{1}' in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
                    }

                }
                else {

                    if (-not $WhatIf -and -not $Async) {

                        "[{0}] Refresh settings job submitted for appliance '{1}' in '{2}' region, waiting for completion..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose

                        $JobResult = Wait-HPECOMJobComplete -Region $Region -Job $Response.resourceUri -Verbose:$VerbosePreference

                        "[{0}] Job result: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($JobResult | Out-String) | Write-Verbose

                        if ($JobResult.resultCode -eq "SUCCESS") {
                            "[{0}] Settings successfully refreshed for appliance '{1}' in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
                            $objStatus.Status = "Complete"
                            $objStatus.Details = "OneView appliance settings successfully refreshed for '$Name' in $Region region"
                        }
                        else {
                            $objStatus.Status = "Failed"
                            $objStatus.Details = if ($JobResult.message) { $JobResult.message } else { "Refresh settings job did not complete successfully. Result: $($JobResult.resultCode)" }
                            $objStatus.Exception = $JobResult
                        }

                    }
                    else {

                        # Async — return raw job resource
                        if (-not $WhatIf) {
                            $Response | Add-Member -type NoteProperty -name region -value $Region
                            $ReturnData = Invoke-RepackageObjectWithType -RawObject $Response -ObjectName "COM.Jobs"
                        }
                    }
                }
            }
            catch {
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "OneView appliance settings refresh cannot be triggered for '$Name'!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData
                }
            }

            # ScheduleTime → $ReturnData (COM.Schedules), Async → $ReturnData (COM.Jobs)
            # Sync         → $objStatus accumulated into $StatusList for End block
            # Only return $ReturnData when it was actually set (not on exception path)
            if (-not $WhatIf) {
                if (($ScheduleTime -or $Async) -and $ReturnData) {
                    Return $ReturnData
                }
            }
        }

        if (-not $WhatIf) {
            [void] $StatusList.add($objStatus)
        }

    }

    End {

        if ($StatusList.Count -gt 0) {
            $StatusList = Invoke-RepackageObjectWithType -RawObject $StatusList -ObjectName "COM.Appliances.RefreshSettings.Status"
            Return $StatusList
        }
    }
}


Function Restart-HPECOMAppliance {
    <#
    .SYNOPSIS
    Reboot a Secure Gateway appliance in Compute Ops Management.

    .DESCRIPTION
    This Cmdlet triggers a reboot of a Secure Gateway appliance registered in Compute Ops Management.

    Rebooting the appliance initiates a reboot of the appliance operating system. New actions on the appliance cannot be initiated until the operation is complete. After the reboot, each server will be reconnected to Compute Ops Management. The reboot is expected to take a couple of minutes.

    The appliance must be in the 'Connected' state to initiate a reboot.

    Only HPE Secure Gateway appliances are supported. OneView appliances (VM or Synergy) are not supported.

    By default, the Cmdlet waits for the job to complete and returns a status object. Use -Async to return the job resource immediately for monitoring.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the appliance is registered.
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name
    Specifies the hostname or IP address of the Secure Gateway appliance to reboot.

    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties). By default, the Cmdlet will wait for the job to complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Restart-HPECOMAppliance -Region eu-central -Name "sg01.lj.lab"

    Triggers a reboot for the specified Secure Gateway appliance in the 'eu-central' region and waits for completion.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Type SecureGateway | Restart-HPECOMAppliance

    Triggers a reboot for all Secure Gateway appliances in the 'eu-central' region and waits for each operation to complete.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Name "sg01.lj.lab" | Restart-HPECOMAppliance -Async

    Triggers a reboot and immediately returns the job resource to monitor.

    .INPUTS
    System.Collections.ArrayList
        List of appliance(s) from 'Get-HPECOMAppliance'.

    .OUTPUTS
    HPEGreenLake.COM.Appliances.Reboot.Status [System.Management.Automation.PSCustomObject]

        - When the job completes (default synchronous mode), the returned object contains:
            - Name - Hostname of the appliance for which the reboot was attempted
            - Region - Name of the region where the reboot was triggered
            - Status - Status of the reboot attempt (Complete / Failed / Warning)
            - Details - More information about the status
            - Exception - Information about any exceptions generated during the operation

        - If the `-Async` switch is used, the cmdlet returns the job resource immediately, allowing you to monitor its progress using the `state` and `resultCode` properties, or by passing the job object to `Wait-HPECOMJobComplete`.

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

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('IPAddress')]
        [String]$Name,

        [switch]$Async,

        [Switch]$WhatIf
    )

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $StatusList = [System.Collections.ArrayList]::new()

        $_JobTemplateName = 'GatewayReboot'
        $JobTemplateId    = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id
        $JobsUri          = Get-COMJobsUri

        "[{0}] Job template '{1}' ID: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_JobTemplateName, $JobTemplateId | Write-Verbose

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | Out-String) | Write-Verbose

        try {
            $ApplianceResource = Get-HPECOMAppliance -Region $Region -Name $Name -Verbose:$false
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        # Build object for the output (used in synchronous mode)
        $objStatus = [pscustomobject]@{
            Name      = $Name
            Region    = $Region
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

        if (-not $ApplianceResource) {

            $ErrorMessage = "Appliance '{0}' cannot be found in the '{1}' region!" -f $Name, $Region
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = $ErrorMessage
            }

        }
        elseif ($ApplianceResource.applianceType -ne "GATEWAY") {

            $ErrorMessage = "Appliance '{0}': Reboot is only supported for HPE Secure Gateway appliances. OneView appliances (VM or Synergy) are not supported." -f $Name
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = $ErrorMessage
            }

        }
        elseif ($ApplianceResource.state -ne "Connected") {

            $ErrorMessage = "Appliance '{0}': The Secure Gateway appliance must be in the 'Connected' state to initiate a reboot. Current state: '{1}'." -f $Name, $ApplianceResource.state
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = $ErrorMessage
            }

        }
        elseif (-not $JobTemplateId) {

            $ErrorMessage = "Job template '$_JobTemplateName' cannot be found in the loaded templates. Ensure you are connected and job templates are loaded."
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = $ErrorMessage
            }

        }
        else {

            $_ApplianceId = $ApplianceResource.deviceId

            $Uri = $JobsUri

            $payload = @{
                jobTemplate  = $JobTemplateId
                resourceId   = $_ApplianceId
                resourceType = "compute-ops-mgmt/appliance"
            }

            $payload = ConvertTo-Json $payload -Depth 10

            try {
                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

                if (-not $WhatIf -and -not $Async) {

                    "[{0}] Reboot job submitted for appliance '{1}' in '{2}' region, waiting for completion..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose

                    $JobResult = Wait-HPECOMJobComplete -Region $Region -Job $Response.resourceUri -Verbose:$VerbosePreference

                    "[{0}] Job result: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($JobResult | Out-String) | Write-Verbose

                    if ($JobResult.resultCode -eq "SUCCESS") {
                        "[{0}] Appliance '{1}' successfully rebooted in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
                        $objStatus.Status = "Complete"
                        $objStatus.Details = "Secure Gateway appliance '$Name' successfully rebooted in $Region region"
                    }
                    else {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = if ($JobResult.message) { $JobResult.message } else { "Reboot job did not complete successfully. Result: $($JobResult.resultCode)" }
                        $objStatus.Exception = $JobResult
                    }

                }
                else {

                    # Async — return raw job resource
                    if (-not $WhatIf) {
                        $Response | Add-Member -type NoteProperty -name region -value $Region
                        $ReturnData = Invoke-RepackageObjectWithType -RawObject $Response -ObjectName "COM.Jobs"
                    }
                }
            }
            catch {
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Reboot cannot be triggered for Secure Gateway appliance '$Name'!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData
                }
            }

            if (-not $WhatIf) {
                if ($Async -and $ReturnData) {
                    Return $ReturnData
                }
            }
        }

        if (-not $WhatIf) {
            [void] $StatusList.add($objStatus)
        }

    }

    End {

        if ($StatusList.Count -gt 0) {
            $StatusList = Invoke-RepackageObjectWithType -RawObject $StatusList -ObjectName "COM.Appliances.Reboot.Status"
            Return $StatusList
        }
    }
}


# Private functions (not exported)
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
Export-ModuleMember -Function 'Get-HPECOMAppliance', 'Restart-HPECOMAppliance', 'Invoke-HPECOMApplianceRefreshSettings', 'New-HPECOMAppliance', 'Remove-HPECOMAppliance', 'Get-HPECOMApplianceFirmwareBundle', 'Get-HPECOMOneViewServerProfileTemplate' -Alias *

# SIG # Begin signature block
# MIIungYJKoZIhvcNAQcCoIIujzCCLosCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD8zr0wgt3EnbIc
# DB8scVXP6e0TpSPgNkSu9bj5GM9vSqCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# nZ+oA+rbZZyGZkz3xbUYKTGCG/4wghv6AgEBMGkwVDELMAkGA1UEBhMCR0IxGDAW
# BgNVBAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMg
# Q29kZSBTaWduaW5nIENBIFIzNgIRAMgx4fswkMFDciVfUuoKqr0wDQYJYIZIAWUD
# BAIBBQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGC
# NwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQx
# IgQgFLA7U+nldwni1cdp6MRRqrkoBsu3KVkq+JgtG3QwQFYwDQYJKoZIhvcNAQEB
# BQAEggIAZQ/G8L7VoUyD6srIcJxF30masM5x5MwgM3DSUUiIb+dXfyDxRkb3nEPw
# XY/1Jn/4Bkpv8agH2fJnDwCB6vS/g0qXachCN0/fk7De5KN41Gy0ix3wE/gN8+Ou
# YGElGgsFADE/AdMzlARQI6A7NaVM0iXGWOqIDyv6m2PZD4RtNonIWvdQ8NRUSfWR
# FY71pKktW634LJQ9u2n//2f80lbIU5lfm0HKaA2x6k8q6jlqGKwfMsMT9I+6MzmZ
# rD2tT9gE2cOuLVSYZsY9nhhi0YhoF1X6SZTqxhyEl6oJ3W/zcsRPSOZDGj1fBzMD
# EGxgl+e6o8uN7dwAUQiczftOcK59W7gx9IDjDYF/22+a1vrIzxcExwXkLp6A4IpS
# DEss+r8v+CThRggePwfeUY8CsGfH6G1GgCnkDg9d/8+pmzIzk1C/avu2MGjCsn3b
# rZQ9SlLXDP73/eqcOEs6f/20EhCu1aNubY+UPc6LcYOX5mgIiHu/10A2vYNYarkS
# o8rGe0GLEL4wPJQvD8PWHT0GjSZmMjYtSZUrsAQcZomo1j4ae05ubod0l2yh2UDc
# PbZCgJnJPjX1TvkevdsiC8cPoIUIYCKiuBp6AqtFtXCtwsLWE/9uQ3JgnKkHe2hR
# gfDsCdOFqi5+kWXal1EhMhi/6cDUKpSeDmjJMgzwe7OSspZVL0ihghjoMIIY5AYK
# KwYBBAGCNwMDATGCGNQwghjQBgkqhkiG9w0BBwKgghjBMIIYvQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBBwYLKoZIhvcNAQkQAQSggfcEgfQwgfECAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQwiwevk/rxLYdJsjjKF+SRhTYJxV3TBkqCx+Hi
# 7e+mJghfHrd3zHgqWvQ7ZzoM0nnYAhQorlFYbS155AXIeJPTS0cHRZhByRgPMjAy
# NjAzMTcxNDIyNThaoHakdDByMQswCQYDVQQGEwJHQjEXMBUGA1UECBMOV2VzdCBZ
# b3Jrc2hpcmUxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEwMC4GA1UEAxMnU2Vj
# dGlnbyBQdWJsaWMgVGltZSBTdGFtcGluZyBTaWduZXIgUjM2oIITBDCCBmIwggTK
# oAMCAQICEQCkKTtuHt3XpzQIh616TrckMA0GCSqGSIb3DQEBDAUAMFUxCzAJBgNV
# BAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLDAqBgNVBAMTI1NlY3Rp
# Z28gUHVibGljIFRpbWUgU3RhbXBpbmcgQ0EgUjM2MB4XDTI1MDMyNzAwMDAwMFoX
# DTM2MDMyMTIzNTk1OVowcjELMAkGA1UEBhMCR0IxFzAVBgNVBAgTDldlc3QgWW9y
# a3NoaXJlMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxMDAuBgNVBAMTJ1NlY3Rp
# Z28gUHVibGljIFRpbWUgU3RhbXBpbmcgU2lnbmVyIFIzNjCCAiIwDQYJKoZIhvcN
# AQEBBQADggIPADCCAgoCggIBANOElfRupFN48j0QS3gSBzzclIFTZ2Gsn7BjsmBF
# 659/kpA2Ey7NXK3MP6JdrMBNU8wdmkf+SSIyjX++UAYWtg3Y/uDRDyg8RxHeHRJ+
# 0U1jHEyH5uPdk1ttiPC3x/gOxIc9P7Gn3OgW7DQc4x07exZ4DX4XyaGDq5LoEmk/
# BdCM1IelVMKB3WA6YpZ/XYdJ9JueOXeQObSQ/dohQCGyh0FhmwkDWKZaqQBWrBwZ
# ++zqlt+z/QYTgEnZo6dyIo2IhXXANFkCHutL8765NBxvolXMFWY8/reTnFxk3Maj
# gM5NX6wzWdWsPJxYRhLxtJLSUJJ5yWRNw+NBqH1ezvFs4GgJ2ZqFJ+Dwqbx9+rw+
# F2gBdgo4j7CVomP49sS7CbqsdybbiOGpB9DJhs5QVMpYV73TVV3IwLiBHBECrTgU
# fZVOMF0KSEq2zk/LsfvehswavE3W4aBXJmGjgWSpcDz+6TqeTM8f1DIcgQPdz0IY
# gnT3yFTgiDbFGOFNt6eCidxdR6j9x+kpcN5RwApy4pRhE10YOV/xafBvKpRuWPjO
# PWRBlKdm53kS2aMh08spx7xSEqXn4QQldCnUWRz3Lki+TgBlpwYwJUbR77DAayNw
# AANE7taBrz2v+MnnogMrvvct0iwvfIA1W8kp155Lo44SIfqGmrbJP6Mn+Udr3MR2
# oWozAgMBAAGjggGOMIIBijAfBgNVHSMEGDAWgBRfWO1MMXqiYUKNUoC6s2GXGaIy
# mzAdBgNVHQ4EFgQUiGGMoSo3ZIEoYKGbMdCM/SwCzk8wDgYDVR0PAQH/BAQDAgbA
# MAwGA1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwSgYDVR0gBEMw
# QTA1BgwrBgEEAbIxAQIBAwgwJTAjBggrBgEFBQcCARYXaHR0cHM6Ly9zZWN0aWdv
# LmNvbS9DUFMwCAYGZ4EMAQQCMEoGA1UdHwRDMEEwP6A9oDuGOWh0dHA6Ly9jcmwu
# c2VjdGlnby5jb20vU2VjdGlnb1B1YmxpY1RpbWVTdGFtcGluZ0NBUjM2LmNybDB6
# BggrBgEFBQcBAQRuMGwwRQYIKwYBBQUHMAKGOWh0dHA6Ly9jcnQuc2VjdGlnby5j
# b20vU2VjdGlnb1B1YmxpY1RpbWVTdGFtcGluZ0NBUjM2LmNydDAjBggrBgEFBQcw
# AYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wDQYJKoZIhvcNAQEMBQADggGBAAKB
# PqSGclEh+WWpLj1SiuHlm8xLE0SThI2yLuq+75s11y6SceBchpnKpxWaGtXc8dya
# 1Aq3RuW//y3wMThsvT4fSba2AoSWlR67rA4fTYGMIhgzocsids0ct/pHaocLVJSw
# nTYxY2pE0hPoZAvRebctbsTqENmZHyOVjOFlwN2R3DRweFeNs4uyZN5LRJ5EnVYl
# cTOq3bl1tI5poru9WaQRWQ4eynXp7Pj0Fz4DKr86HYECRJMWiDjeV0QqAcQMFsIj
# JtrYTw7mU81qf4FBc4u4swphLeKRNyn9DDrd3HIMJ+CpdhSHEGleeZ5I79YDg3B3
# A/fmVY2GaMik1Vm+FajEMv4/EN2mmHf4zkOuhYZNzVm4NrWJeY4UAriLBOeVYODd
# A1GxFr1ycbcUEGlUecc4RCPgYySs4d00NNuicR4a9n7idJlevAJbha/arIYMEuUq
# TeRRbWkhJwMKmb9yEvppRudKyu1t6l21sIuIZqcpVH8oLWCxHS0LpDRF9Y4jijCC
# BhQwggP8oAMCAQICEHojrtpTaZYPkcg+XPTH4z8wDQYJKoZIhvcNAQEMBQAwVzEL
# MAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEuMCwGA1UEAxMl
# U2VjdGlnbyBQdWJsaWMgVGltZSBTdGFtcGluZyBSb290IFI0NjAeFw0yMTAzMjIw
# MDAwMDBaFw0zNjAzMjEyMzU5NTlaMFUxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxLDAqBgNVBAMTI1NlY3RpZ28gUHVibGljIFRpbWUgU3Rh
# bXBpbmcgQ0EgUjM2MIIBojANBgkqhkiG9w0BAQEFAAOCAY8AMIIBigKCAYEAzZjY
# Q0GrboIr7PYzfiY05ImM0+8iEoBUPu8mr4wOgYPjoiIz5vzf7d5wu8GFK1JWN5hc
# iN9rdqOhbdxLcSVwnOTJmUGfAMQm4eXOls3iQwfapEFWuOsYmBKXPNSpwZAFoLGl
# 5y1EaGGc5LByM8wjcbSF52/Z42YaJRsPXY545E3QAPN2mxDh0OLozhiGgYT1xtjX
# VfEzYBVmfQaI5QL35cTTAjsJAp85R+KAsOfuL9Z7LFnjdcuPkZWjssMETFIueH69
# rxbFOUD64G+rUo7xFIdRAuDNvWBsv0iGDPGaR2nZlY24tz5fISYk1sPY4gir99aX
# AGnoo0vX3Okew4MsiyBn5ZnUDMKzUcQrpVavGacrIkmDYu/bcOUR1mVBIZ0X7P4b
# Kf38JF7Mp7tY3LFF/h7hvBS2tgTYXlD7TnIMPrxyXCfB5yQq3FFoXRXM3/DvqQ4s
# hoVWF/mwwz9xoRku05iphp22fTfjKRIVpm4gFT24JKspEpM8mFa9eTgKWWCvAgMB
# AAGjggFcMIIBWDAfBgNVHSMEGDAWgBT2d2rdP/0BE/8WoWyCAi/QCj0UJTAdBgNV
# HQ4EFgQUX1jtTDF6omFCjVKAurNhlxmiMpswDgYDVR0PAQH/BAQDAgGGMBIGA1Ud
# EwEB/wQIMAYBAf8CAQAwEwYDVR0lBAwwCgYIKwYBBQUHAwgwEQYDVR0gBAowCDAG
# BgRVHSAAMEwGA1UdHwRFMEMwQaA/oD2GO2h0dHA6Ly9jcmwuc2VjdGlnby5jb20v
# U2VjdGlnb1B1YmxpY1RpbWVTdGFtcGluZ1Jvb3RSNDYuY3JsMHwGCCsGAQUFBwEB
# BHAwbjBHBggrBgEFBQcwAoY7aHR0cDovL2NydC5zZWN0aWdvLmNvbS9TZWN0aWdv
# UHVibGljVGltZVN0YW1waW5nUm9vdFI0Ni5wN2MwIwYIKwYBBQUHMAGGF2h0dHA6
# Ly9vY3NwLnNlY3RpZ28uY29tMA0GCSqGSIb3DQEBDAUAA4ICAQAS13sgrQ41WAye
# gR0lWP1MLWd0r8diJiH2VVRpxqFGhnZbaF+IQ7JATGceTWOS+kgnMAzGYRzpm8jI
# cjlSQ8JtcqymKhgx1s6cFZBSfvfeoyigF8iCGlH+SVSo3HHr98NepjSFJTU5KSRK
# K+3nVSWYkSVQgJlgGh3MPcz9IWN4I/n1qfDGzqHCPWZ+/Mb5vVyhgaeqxLPbBIqv
# 6cM74Nvyo1xNsllECJJrOvsrJQkajVz4xJwZ8blAdX5umzwFfk7K/0K3fpjgiXpq
# NOpXaJ+KSRW0HdE0FSDC7+ZKJJSJx78mn+rwEyT+A3z7Ss0gT5CpTrcmhUwIw9jb
# vnYuYRKxFVWjKklW3z83epDVzoWJttxFpujdrNmRwh1YZVIB2guAAjEQoF42H0BA
# 7WBCueHVMDyV1e4nM9K4As7PVSNvQ8LI1WRaTuGSFUd9y8F8jw22BZC6mJoB40d7
# SlZIYfaildlgpgbgtu6SDsek2L8qomG57Yp5qTqof0DwJ4Q4HsShvRl/59T4IJBo
# vRwmqWafH0cIPEX7cEttS5+tXrgRtMjjTOp6A9l0D6xcKZtxnLqiTH9KPCy6xZEi
# 0UDcMTww5Fl4VvoGbMG2oonuX3f1tsoHLaO/Fwkj3xVr3lDkmeUqivebQTvGkx5h
# GuJaSVQ+x60xJ/Y29RBr8Tm9XJ59AjCCBoIwggRqoAMCAQICEDbCsL18Gzrno7Pd
# NsvJdWgwDQYJKoZIhvcNAQEMBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpO
# ZXcgSmVyc2V5MRQwEgYDVQQHEwtKZXJzZXkgQ2l0eTEeMBwGA1UEChMVVGhlIFVT
# RVJUUlVTVCBOZXR3b3JrMS4wLAYDVQQDEyVVU0VSVHJ1c3QgUlNBIENlcnRpZmlj
# YXRpb24gQXV0aG9yaXR5MB4XDTIxMDMyMjAwMDAwMFoXDTM4MDExODIzNTk1OVow
# VzELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEuMCwGA1UE
# AxMlU2VjdGlnbyBQdWJsaWMgVGltZSBTdGFtcGluZyBSb290IFI0NjCCAiIwDQYJ
# KoZIhvcNAQEBBQADggIPADCCAgoCggIBAIid2LlFZ50d3ei5JoGaVFTAfEkFm8xa
# FQ/ZlBBEtEFAgXcUmanU5HYsyAhTXiDQkiUvpVdYqZ1uYoZEMgtHES1l1Cc6HaqZ
# zEbOOp6YiTx63ywTon434aXVydmhx7Dx4IBrAou7hNGsKioIBPy5GMN7KmgYmuu4
# f92sKKjbxqohUSfjk1mJlAjthgF7Hjx4vvyVDQGsd5KarLW5d73E3ThobSkob2SL
# 48LpUR/O627pDchxll+bTSv1gASn/hp6IuHJorEu6EopoB1CNFp/+HpTXeNARXUm
# dRMKbnXWflq+/g36NJXB35ZvxQw6zid61qmrlD/IbKJA6COw/8lFSPQwBP1ityZd
# wuCysCKZ9ZjczMqbUcLFyq6KdOpuzVDR3ZUwxDKL1wCAxgL2Mpz7eZbrb/JWXiOc
# NzDpQsmwGQ6Stw8tTCqPumhLRPb7YkzM8/6NnWH3T9ClmcGSF22LEyJYNWCHrQqY
# ubNeKolzqUbCqhSqmr/UdUeb49zYHr7ALL8bAJyPDmubNqMtuaobKASBqP84uhqc
# RY/pjnYd+V5/dcu9ieERjiRKKsxCG1t6tG9oj7liwPddXEcYGOUiWLm742st50jG
# wTzxbMpepmOP1mLnJskvZaN5e45NuzAHteORlsSuDt5t4BBRCJL+5EZnnw0ezntk
# 9R8QJyAkL6/bAgMBAAGjggEWMIIBEjAfBgNVHSMEGDAWgBRTeb9aqitKz1SA4dib
# wJ3ysgNmyzAdBgNVHQ4EFgQU9ndq3T/9ARP/FqFsggIv0Ao9FCUwDgYDVR0PAQH/
# BAQDAgGGMA8GA1UdEwEB/wQFMAMBAf8wEwYDVR0lBAwwCgYIKwYBBQUHAwgwEQYD
# VR0gBAowCDAGBgRVHSAAMFAGA1UdHwRJMEcwRaBDoEGGP2h0dHA6Ly9jcmwudXNl
# cnRydXN0LmNvbS9VU0VSVHJ1c3RSU0FDZXJ0aWZpY2F0aW9uQXV0aG9yaXR5LmNy
# bDA1BggrBgEFBQcBAQQpMCcwJQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0
# cnVzdC5jb20wDQYJKoZIhvcNAQEMBQADggIBAA6+ZUHtaES45aHF1BGH5Lc7JYzr
# ftrIF5Ht2PFDxKKFOct/awAEWgHQMVHol9ZLSyd/pYMbaC0IZ+XBW9xhdkkmUV/K
# bUOiL7g98M/yzRyqUOZ1/IY7Ay0YbMniIibJrPcgFp73WDnRDKtVutShPSZQZAdt
# FwXnuiWl8eFARK3PmLqEm9UsVX+55DbVIz33Mbhba0HUTEYv3yJ1fwKGxPBsP/Mg
# TECimh7eXomvMm0/GPxX2uhwCcs/YLxDnBdVVlxvDjHjO1cuwbOpkiJGHmLXXVNb
# sdXUC2xBrq9fLrfe8IBsA4hopwsCj8hTuwKXJlSTrZcPRVSccP5i9U28gZ7OMzoJ
# GlxZ5384OKm0r568Mo9TYrqzKeKZgFo0fj2/0iHbj55hc20jfxvK3mQi+H7xpbzx
# ZOFGm/yVQkpo+ffv5gdhp+hv1GDsvJOtJinJmgGbBFZIThbqI+MHvAmMmkfb3fTx
# mSkop2mSJL1Y2x/955S29Gu0gSJIkc3z30vU/iXrMpWx2tS7UVfVP+5tKuzGtgkP
# 7d/doqDrLF1u6Ci3TpjAZdeLLlRQZm867eVeXED58LXd1Dk6UvaAhvmWYXoiLz4J
# A5gPBcz7J311uahxCweNxE+xxxR3kT0WKzASo5G/PyDez6NHdIUKBeE3jDPs2ACc
# 6CkJ1Sji4PKWVT0/MYIEkjCCBI4CAQEwajBVMQswCQYDVQQGEwJHQjEYMBYGA1UE
# ChMPU2VjdGlnbyBMaW1pdGVkMSwwKgYDVQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1l
# IFN0YW1waW5nIENBIFIzNgIRAKQpO24e3denNAiHrXpOtyQwDQYJYIZIAWUDBAIC
# BQCgggH5MBoGCSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUx
# DxcNMjYwMzE3MTQyMjU4WjA/BgkqhkiG9w0BCQQxMgQwFGc/6hMU4Z71X51yVunK
# HnFDbtDlp9LrIpoqJdGH85qF6cRgqV1lu84n26NXtaW/MIIBegYLKoZIhvcNAQkQ
# AgwxggFpMIIBZTCCAWEwFgQUOMkUgRBEtNxmPpPUdEuBQYaptbEwgYcEFMauVOR4
# hvF8PVUSSIxpw0p6+cLdMG8wW6RZMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRpbWUgU3Rh
# bXBpbmcgUm9vdCBSNDYCEHojrtpTaZYPkcg+XPTH4z8wgbwEFIU9Yy2TgoJhfNCQ
# NcSR3pLBQtrHMIGjMIGOpIGLMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKTmV3
# IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBVU0VS
# VFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZpY2F0
# aW9uIEF1dGhvcml0eQIQNsKwvXwbOuejs902y8l1aDANBgkqhkiG9w0BAQEFAASC
# AgApYl3PgpXiuRWBQWgnsMt3F3MSRZl7j2HzgSYlGzBhotJBYUFKRcjYvniBa2/n
# RvVEe0tzj37LFY+vItRlLQ5CDNlD7hb5a7/vAO7NaAxBzcxQzSjAjxCtdWIu1yyU
# J7Apoc2KIXrtLr3wjPfNaEtNrXC//NejR8+VV33olPO1L7/FvvzEfjiFkZzv+IAK
# Ni4ZZ3Ft/e1p8Dgl5GzH2wlrboLaXbgxaR+W7vjS1SznG9r+0SVFbH6umz4Yjuur
# L9U0osxvsW0NBrbGptFCxU6J/q75RASFRRANUACDTrNoMmqWOk8zQYDNNWalAnNl
# ZCJgg1or0m5XFz35w/Dz9HpER/OHkzbcxY1xCJfGcu9+EWivFdu2Doyuf22G58am
# muAosYVxMBfUrgbAX0+a6tItT0EWlK9f/be3iuNHkxZiI/nSI/j31Ss1arQT1u0Q
# K3Q7UiK4H3ETuJassLqKWQWYxKaFCZmseF05Sll2ai/vZYBRrY1OrSvvKNpgQZon
# KwEDNEPxrp6BsYT6Mo2DYAL+dv9HlfP4OvOPzl+U7M2cvvNbSYKRCm8eo/B9sxOu
# 3XSHQZiOiT/8pSOqs+0HBnifnlYL6cJ5HFncWTgREwAyfQrA9R/xejTONEyqDPiq
# +PWFk5d+Xgv9EoJQtGK93yHASUUZI8n4/FpaIbXxxoT6mg==
# SIG # End signature block
