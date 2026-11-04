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
                if (-not $Global:HPEGreenLakeSession) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use the cmdlets of the HPECOMCmdlets module."
                }
                if (-not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "Compute Ops Management is not provisioned in this workspace!`n`nCAUSE:`nNo provisioned Compute Ops Management region was found.`n`nACTION REQUIRED:`nVerify the Compute Ops Management service is provisioned using:`n    Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned`n`nIf not provisioned, you can provision it using 'New-HPEGLService'."
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
        [ValidateNotNullOrEmpty()]
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
                if (-not $Global:HPEGreenLakeSession) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use the cmdlets of the HPECOMCmdlets module."
                }
                if (-not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "Compute Ops Management is not provisioned in this workspace!`n`nCAUSE:`nNo provisioned Compute Ops Management region was found.`n`nACTION REQUIRED:`nVerify the Compute Ops Management service is provisioned using:`n    Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned`n`nIf not provisioned, you can provision it using 'New-HPEGLService'."
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
        [ValidateNotNullOrEmpty()]
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
                if (-not $Global:HPEGreenLakeSession) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use the cmdlets of the HPECOMCmdlets module."
                }
                if (-not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "Compute Ops Management is not provisioned in this workspace!`n`nCAUSE:`nNo provisioned Compute Ops Management region was found.`n`nACTION REQUIRED:`nVerify the Compute Ops Management service is provisioned using:`n    Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned`n`nIf not provisioned, you can provision it using 'New-HPEGLService'."
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
        [ValidateNotNullOrEmpty()]
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
                if (-not $Global:HPEGreenLakeSession) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use the cmdlets of the HPECOMCmdlets module."
                }
                if (-not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "Compute Ops Management is not provisioned in this workspace!`n`nCAUSE:`nNo provisioned Compute Ops Management region was found.`n`nACTION REQUIRED:`nVerify the Compute Ops Management service is provisioned using:`n    Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned`n`nIf not provisioned, you can provision it using 'New-HPEGLService'."
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
        [ValidateNotNullOrEmpty()]
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
                if (-not $Global:HPEGreenLakeSession) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use the cmdlets of the HPECOMCmdlets module."
                }
                if (-not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "Compute Ops Management is not provisioned in this workspace!`n`nCAUSE:`nNo provisioned Compute Ops Management region was found.`n`nACTION REQUIRED:`nVerify the Compute Ops Management service is provisioned using:`n    Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned`n`nIf not provisioned, you can provision it using 'New-HPEGLService'."
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
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Parameter(ParameterSetName = 'Default')]
        [Parameter(ParameterSetName = 'ShowAttributes')]
        [ValidateNotNullOrEmpty()]
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
    HPEGreenLake.COM.Jobs [System.Management.Automation.PSCustomObject]

        - If the -Async switch is used, the cmdlet returns the job resource immediately, allowing you to monitor
          its progress using the `state` and `resultCode` properties, or by passing the job object to
          `Wait-HPECOMJobComplete` for blocking/waiting behavior.

    HPEGreenLake.COM.Appliances.RefreshSettings.Status [System.Management.Automation.PSCustomObject]

        - When the job completes (default synchronous mode), the returned object contains:
            - Name - Hostname of the appliance for which the refresh was attempted
            - Region - Name of the region where the refresh was triggered
            - Status - Status of the refresh attempt (Complete / Failed / Warning)
            - Details - More information about the status
            - Exception - Information about any exceptions generated during the operation

    HPEGreenLake.COM.Schedules [System.Management.Automation.PSCustomObject]

        - The schedule object that includes the schedule details when `-ScheduleTime` is used.

    #>

    [CmdletBinding(DefaultParameterSetName = 'Async')]
    Param(

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateScript({
                # First check if there's an active session with COM regions
                if (-not $Global:HPEGreenLakeSession) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use the cmdlets of the HPECOMCmdlets module."
                }
                if (-not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "Compute Ops Management is not provisioned in this workspace!`n`nCAUSE:`nNo provisioned Compute Ops Management region was found.`n`nACTION REQUIRED:`nVerify the Compute Ops Management service is provisioned using:`n    Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned`n`nIf not provisioned, you can provision it using 'New-HPEGLService'."
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
        [ValidateNotNullOrEmpty()]
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

                        # Save last job result for easy post-execution inspection
                        $Global:HPECOMLastJobResult = $JobResult

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
    HPEGreenLake.COM.Jobs [System.Management.Automation.PSCustomObject]

        - If the -Async switch is used, the cmdlet returns the job resource immediately, allowing you to monitor
          its progress using the `state` and `resultCode` properties, or by passing the job object to
          `Wait-HPECOMJobComplete` for blocking/waiting behavior.

    HPEGreenLake.COM.Appliances.Reboot.Status [System.Management.Automation.PSCustomObject]

        - When the job completes (default synchronous mode), the returned object contains:
            - Name - Hostname of the appliance for which the reboot was attempted
            - Region - Name of the region where the reboot was triggered
            - Status - Status of the reboot attempt (Complete / Failed / Warning)
            - Details - More information about the status
            - Exception - Information about any exceptions generated during the operation

    #>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param(

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateScript({
                # First check if there's an active session with COM regions
                if (-not $Global:HPEGreenLakeSession) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use the cmdlets of the HPECOMCmdlets module."
                }
                if (-not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "Compute Ops Management is not provisioned in this workspace!`n`nCAUSE:`nNo provisioned Compute Ops Management region was found.`n`nACTION REQUIRED:`nVerify the Compute Ops Management service is provisioned using:`n    Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned`n`nIf not provisioned, you can provision it using 'New-HPEGLService'."
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
        [ValidateNotNullOrEmpty()]
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

                    # Save last job result for easy post-execution inspection
                    $Global:HPECOMLastJobResult = $JobResult

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


Function Invoke-HPECOMSecureGatewayServerDiscovery {
    <#
    .SYNOPSIS
    Discover servers behind an HPE Secure Gateway appliance using a network scan.

    .DESCRIPTION
    This cmdlet triggers a server discovery operation on an HPE Secure Gateway appliance in Compute Ops Management.
    Two discovery modes are supported:

    - Automatic (nmap network scan) - the default. The discovery runs an nmap network scan from the Secure Gateway
      across its local subnet to detect HPE iLO devices that are reachable through the gateway but not yet connected
      to Compute Ops Management.
    - Manual (targeted IP addresses) - used when -IPAddress and/or -IPRange are specified. Only the IP addresses you
      provide (individual addresses and/or expanded ranges) are probed, instead of scanning the whole subnet. This is
      faster and more precise than the nmap scan and is useful when you already know the iLO addresses.

    Note: Nmap host discovery relies on ICMP and TCP probe packets to identify reachable hosts. In private LR4 networks where 
    ICMP traffic is blocked, host detection might be affected and some reachable systems might not be identified accurately.

    Note: The scan duration depends on the size of the subnet behind the Secure Gateway. Scanning a large subnet (for
    example a /16, or networks with many unreachable addresses) can take a long time - from several minutes to much
    longer. By default the cmdlet waits for the discovery job to complete; use -Async to submit the job and return
    immediately, then retrieve the results later with 'Get-HPECOMSecureGatewayServerDiscovery'.

    If two network interfaces are configured in the HPE Secure Gateway, the scan uses the secure gateway device network.

    By default, the cmdlet submits the discovery job, waits for it to complete, then retrieves the list of discovered
    servers, including each server's IP address, iLO generation, iLO firmware version, whether an iLO firmware update is
    required before the server can be connected to Compute Ops Management, and the iLO certificate fingerprint.

    Use -Async to submit the discovery job and immediately return the job resource without waiting (the list of
    discovered servers can then be retrieved separately). Use -ScheduleTime (optionally with -Interval) to schedule the
    discovery to run later or on a recurring basis.

    The returned objects (default mode) are designed to be piped directly to 'Connect-HPEGLDeviceComputeiLOtoCOM' to
    onboard the discovered iLOs to Compute Ops Management through the Secure Gateway.

    SECURITY NOTICE:
    The discovery performs an active nmap network scan from the Secure Gateway appliance. This scan probes hosts on
    the appliance's local subnet (host discovery and TCP port checks) and may trigger intrusion detection/prevention
    systems (IDS/IPS) or security monitoring alerts. It may also be subject to your organization's network scanning
    authorization policy. Ensure you are authorized to scan the target network before proceeding. Depending on the
    size of the subnet, the scan can take a long time to complete. By default, the cmdlet prompts for confirmation
    before launching the scan. Use -Force to bypass the confirmation prompt.

    Note that, to be connected to Compute Ops Management, iLO must be updated to the following minimum versions:
    - iLO 5: v3.09 or later
    - iLO 6: v1.64 or later
    - iLO 7: v1.12.00 or later
    Discovered servers running an older iLO firmware are reported with 'iLOUpdateRequired = Yes'.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the Secure Gateway appliance is registered.
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER SecureGateway
    Specifies the HPE Secure Gateway appliance on which to run the server discovery.
    This parameter accepts either the name (hostname) of the Secure Gateway as a string, or a Secure Gateway object retrieved from 'Get-HPECOMAppliance -Type SecureGateway'.

    .PARAMETER IPAddress
    Specifies one or more individual IPv4 addresses to probe (manual discovery mode). When this parameter (or -IPRange) is
    used, the cmdlet performs a targeted discovery of only the specified addresses instead of an nmap subnet scan.

    Example: -IPAddress '192.168.3.105' or -IPAddress '192.168.3.105','192.168.2.10'

    .PARAMETER IPRange
    Specifies one or more IPv4 address ranges to probe (manual discovery mode). Each range is expressed as 'startIP-endIP'
    and is expanded to the full list of addresses it contains. Can be combined with -IPAddress; the resulting set of
    addresses is de-duplicated. A maximum of 4096 addresses is allowed across all ranges and individual addresses.

    Example: -IPRange '192.168.3.10-192.168.3.20' or -IPRange '192.168.3.10-192.168.3.20','192.168.2.10-192.168.2.14'

    .PARAMETER Force
    Bypasses the confirmation prompt warning about the nmap network scan and launches the discovery immediately.

    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties). By default, the cmdlet waits for the discovery job to complete and returns the list of discovered servers.

    .PARAMETER ScheduleTime
    Specifies the date and time when the server discovery should be executed.
    This parameter accepts a DateTime object or a string representation of a date and time.
    If not specified, the discovery is executed immediately.

    Examples for setting the date and time using `Get-Date`:
    - (Get-Date).AddMonths(6)
    - (Get-Date).AddDays(15)
    - (Get-Date).AddHours(3)
    Example for using a specific date string:
    - "2024-05-20 08:00:00"

    .PARAMETER Interval
    Specifies the interval at which the server discovery should be repeated.

    This parameter supports common ISO 8601 period durations such as:
    - P1D (1 Day)
    - P1W (1 Week)
    - P1M (1 Month)
    - P1Y (1 Year)

    A valid interval must be greater than 15 minutes (PT15M) and less than 1 year (P1Y).

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Invoke-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lj.lab"

    Runs an nmap-based server discovery on the Secure Gateway 'sg01.lj.lab' in the 'eu-central' region (after prompting for confirmation) and returns the list of discovered servers.

    .EXAMPLE
    Invoke-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lj.lab" -IPAddress '192.168.3.105' -Force

    Runs a manual (targeted) server discovery on the Secure Gateway 'sg01.lj.lab', probing only the single IP address '192.168.3.105' instead of scanning the whole subnet.

    .EXAMPLE
    Invoke-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lj.lab" -IPAddress '192.168.1.56','192.168.1.57' -Force

    Runs a manual server discovery on the Secure Gateway 'sg01.lj.lab', probing the two individual IP addresses '192.168.1.56' and '192.168.1.57'.

    .EXAMPLE
    Invoke-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lj.lab" -IPRange '192.168.3.10-192.168.3.20' -Force

    Runs a manual server discovery on the Secure Gateway 'sg01.lj.lab', probing every address in the range 192.168.3.10-192.168.3.20.

    .EXAMPLE
    Invoke-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lj.lab" -IPRange '192.168.3.10-192.168.3.20','192.168.4.10-192.168.4.20' -Force

    Runs a manual server discovery on the Secure Gateway 'sg01.lj.lab', probing every address in both ranges 192.168.3.10-192.168.3.20 and 192.168.4.10-192.168.4.20.

    .EXAMPLE
    Invoke-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lj.lab" -IPAddress '192.168.1.56','192.168.1.57' -IPRange '192.168.3.10-192.168.3.20' -Force

    Runs a manual server discovery on the Secure Gateway 'sg01.lj.lab', probing the two individual IP addresses and every address in the range 192.168.3.10-192.168.3.20 (duplicates are removed automatically).

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Type SecureGateway -Name "sg01.lj.lab" | Invoke-HPECOMSecureGatewayServerDiscovery -Force

    Retrieves the Secure Gateway 'sg01.lj.lab' and runs the server discovery without prompting for confirmation.

    .EXAMPLE
    $iLO_credential = Get-Credential

    Invoke-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lj.lab" -Force |
        Where-Object iLOUpdateRequired -eq 'No' |
        Connect-HPEGLDeviceComputeiLOtoCOM -IloCredential $iLO_credential

    Discovers servers behind the Secure Gateway 'sg01.lj.lab', filters out any iLO that requires a firmware update first, and onboards the remaining iLOs to Compute Ops Management through the Secure Gateway.

    .EXAMPLE
    $iLO_credential = Get-Credential
    $DiscoveredServers = Invoke-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lj.lab" -IPRange '192.168.3.10-192.168.3.20' -Force
    $COM_Activation_Key = New-HPECOMServerActivationKey -Region eu-central -SecureGateway "sg01.lj.lab"
    $DiscoveredServers | Where-Object iLOUpdateRequired -eq 'No' | Connect-HPEGLDeviceComputeiLOtoCOM -IloCredential $iLO_credential -ActivationKeyfromCOM $COM_Activation_Key -SkipCertificateValidation

    Runs a manual server discovery of the IP range 192.168.3.10-192.168.3.20 on the Secure Gateway 'sg01.lj.lab', generates a Secure Gateway activation key, then onboards to Compute Ops Management every discovered iLO whose firmware already meets the minimum version required to connect.

    .EXAMPLE
    Invoke-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lj.lab" -Force -Async

    Submits the discovery job on the Secure Gateway 'sg01.lj.lab' and immediately returns the job resource to monitor, without waiting for completion.

    .EXAMPLE
    Invoke-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lj.lab" -Force -ScheduleTime (Get-Date).AddHours(6)

    Schedules an nmap-based server discovery on the Secure Gateway 'sg01.lj.lab' to run six hours from now.

    .EXAMPLE
    Invoke-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lj.lab" -Force -ScheduleTime (Get-Date).AddHours(6) -Interval P1W

    Schedules a weekly nmap-based server discovery on the Secure Gateway 'sg01.lj.lab', with the first execution six hours from now.

    .INPUTS
    System.String
        The name of a Secure Gateway appliance.
    HPEGreenLake.COM.Appliances
        A Secure Gateway object from 'Get-HPECOMAppliance -Type SecureGateway'.

    .OUTPUTS
    HPEGreenLake.COM.DiscoveredServers [System.Management.Automation.PSCustomObject]

        In the default (synchronous) mode, returns one object per discovered server, with the following properties:
            - IP - IP address of the discovered iLO (can be piped to 'Connect-HPEGLDeviceComputeiLOtoCOM')
            - iLOGeneration - iLO generation reported by the discovery (e.g. 'iLO 6')
            - iLOVersion - iLO firmware version detected
            - iLOUpdateRequired - 'Yes' if the iLO firmware is below the minimum version required to connect to Compute Ops Management, 'No' if it meets the minimum, 'Unknown' if it could not be determined
            - CertificateFingerprint - SHA-256 fingerprint of the iLO TLS certificate
            - SecureGateway - Name of the Secure Gateway used for the discovery
            - Region - Name of the region where the discovery was run
            - ApplianceId - Identifier of the Secure Gateway appliance

    HPEGreenLake.COM.Jobs [System.Management.Automation.PSCustomObject]

        - When -Async is used, the cmdlet returns the job resource immediately, allowing you to monitor its progress
          using the `state` and `resultCode` properties, or by passing the job object to `Wait-HPECOMJobComplete`.

    HPEGreenLake.COM.Schedules [System.Management.Automation.PSCustomObject]

        - When -ScheduleTime is used, the cmdlet returns the schedule object containing the schedule details.

    #>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param(

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateScript({
                # First check if there's an active session with COM regions
                if (-not $Global:HPEGreenLakeSession) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use the cmdlets of the HPECOMCmdlets module."
                }
                if (-not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "Compute Ops Management is not provisioned in this workspace!`n`nCAUSE:`nNo provisioned Compute Ops Management region was found.`n`nACTION REQUIRED:`nVerify the Compute Ops Management service is provisioned using:`n    Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned`n`nIf not provisioned, you can provision it using 'New-HPEGLService'."
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
        [Alias('name')]
        [object]$SecureGateway,

        [Parameter (ValueFromPipelineByPropertyName)]
        [ValidateScript({
                foreach ($_ip in $_) {
                    $_parsed = $null
                    if (-not [System.Net.IPAddress]::TryParse($_ip, [ref]$_parsed) -or $_parsed.AddressFamily -ne 'InterNetwork') {
                        throw "Invalid IPv4 address: '$_ip'. Provide a valid IPv4 address (e.g., '192.168.3.105')."
                    }
                }
                $true
            })]
        [String[]]$IPAddress,

        [Parameter (ValueFromPipelineByPropertyName)]
        [ValidateScript({
                foreach ($_range in $_) {
                    if ($_range -notmatch '^\s*(\d{1,3}(?:\.\d{1,3}){3})\s*-\s*(\d{1,3}(?:\.\d{1,3}){3})\s*$') {
                        throw "Invalid IP range format: '$_range'. Use 'startIP-endIP' (e.g., '192.168.3.10-192.168.3.20')."
                    }
                    $_startParsed = $null
                    $_endParsed   = $null
                    if (-not [System.Net.IPAddress]::TryParse($matches[1], [ref]$_startParsed) -or $_startParsed.AddressFamily -ne 'InterNetwork') {
                        throw "Invalid start IPv4 address in range '$_range'."
                    }
                    if (-not [System.Net.IPAddress]::TryParse($matches[2], [ref]$_endParsed) -or $_endParsed.AddressFamily -ne 'InterNetwork') {
                        throw "Invalid end IPv4 address in range '$_range'."
                    }
                }
                $true
            })]
        [String[]]$IPRange,

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

        [Parameter (ParameterSetName = 'Schedule')]
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
        [String]$Interval,

        [Parameter (ParameterSetName = 'Default')]
        [Switch]$Async,

        [Switch]$Force,

        [Switch]$WhatIf
    )

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $DiscoveredList = [System.Collections.ArrayList]::new()

        $_JobTemplateName = 'GatewayDiscoverIlos'
        $JobTemplateId    = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id
        $JobsUri          = Get-COMJobsUri

        "[{0}] Job template '{1}' ID: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_JobTemplateName, $JobTemplateId | Write-Verbose

        # Minimum iLO firmware versions required to connect a server to Compute Ops Management
        $_iLOMinimumVersions = @{
            '5' = [version]'3.09'
            '6' = [version]'1.64'
            '7' = [version]'1.12.00'
        }

        # Maximum number of IP addresses allowed for a manual discovery (safeguard against accidental large ranges)
        $_ManualIPMaxCount = 4096

        # Helpers to expand an IPv4 range ('startIP-endIP') into the list of addresses it contains
        function ConvertTo-UInt32IPv4 ([string]$IPv4) {
            $_bytes = ([System.Net.IPAddress]::Parse($IPv4)).GetAddressBytes()
            [Array]::Reverse($_bytes)
            return [System.BitConverter]::ToUInt32($_bytes, 0)
        }
        function ConvertFrom-UInt32IPv4 ([uint32]$IPv4Int) {
            $_bytes = [System.BitConverter]::GetBytes($IPv4Int)
            [Array]::Reverse($_bytes)
            return ([System.Net.IPAddress]($_bytes)).ToString()
        }

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | Out-String) | Write-Verbose

        # Resolve the Secure Gateway resource (accept a name string or a Secure Gateway object)
        try {
            if ($SecureGateway -is [string]) {
                "[{0}] SecureGateway parameter is a string" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                $ApplianceResource = Get-HPECOMAppliance -Region $Region -Type SecureGateway -Name $SecureGateway -Verbose:$false
                $SecureGatewayName = $SecureGateway
            }
            else {
                "[{0}] SecureGateway parameter is an object" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                $SecureGatewayName = $SecureGateway.name
                $ApplianceResource = Get-HPECOMAppliance -Region $Region -Type SecureGateway -Name $SecureGatewayName -Verbose:$false
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if (-not $ApplianceResource) {

            $ErrorMessage = "Secure Gateway '{0}' cannot be found in the '{1}' region!" -f $SecureGatewayName, $Region
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            $Exception = New-Object System.Exception($ErrorMessage)
            $ErrorRecord = New-Object System.Management.Automation.ErrorRecord($Exception, 'SecureGatewayNotFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $SecureGatewayName)
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }

        if ($ApplianceResource.applianceType -ne "GATEWAY") {

            $ErrorMessage = "Appliance '{0}': Server discovery is only supported for HPE Secure Gateway appliances. OneView appliances (VM or Synergy) are not supported." -f $SecureGatewayName
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            $Exception = New-Object System.Exception($ErrorMessage)
            $ErrorRecord = New-Object System.Management.Automation.ErrorRecord($Exception, 'NotASecureGateway', [System.Management.Automation.ErrorCategory]::InvalidOperation, $SecureGatewayName)
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }

        if ($ApplianceResource.state -ne "Connected") {

            $ErrorMessage = "Secure Gateway '{0}': The appliance must be in the 'Connected' state to run a server discovery. Current state: '{1}'." -f $SecureGatewayName, $ApplianceResource.state
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            $Exception = New-Object System.Exception($ErrorMessage)
            $ErrorRecord = New-Object System.Management.Automation.ErrorRecord($Exception, 'SecureGatewayNotConnected', [System.Management.Automation.ErrorCategory]::InvalidOperation, $SecureGatewayName)
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }

        if (-not $JobTemplateId) {

            $ErrorMessage = "Job template '$_JobTemplateName' cannot be found in the loaded templates. Ensure you are connected and job templates are loaded."
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            $Exception = New-Object System.Exception($ErrorMessage)
            $ErrorRecord = New-Object System.Management.Automation.ErrorRecord($Exception, 'JobTemplateNotFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $_JobTemplateName)
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }

        $_ApplianceResourceUri = $ApplianceResource.resourceUri
        $_ApplianceDeviceId    = $ApplianceResource.deviceId
        # The appliance identifier used by the discovered-servers endpoint is the segment that follows 'gateway+' in the resource URI
        if ($_ApplianceResourceUri -match 'gateway\+(.+)$') {
            $_ApplianceId = $matches[1]
        }
        else {
            $_ApplianceId = $_ApplianceDeviceId
        }

        "[{0}] Secure Gateway '{1}' resource URI: '{2}' (appliance ID: '{3}')" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SecureGatewayName, $_ApplianceResourceUri, $_ApplianceId | Write-Verbose

        # Determine the discovery mode: 'manual' when explicit IP addresses/ranges are supplied, otherwise 'nmapScan'
        $_IsManual      = [bool]($IPAddress -or $IPRange)
        $_DiscoveryMode = if ($_IsManual) { "manual" } else { "nmapScan" }

        # For manual discovery, build the flat, de-duplicated list of target IPv4 addresses (expanding any ranges)
        $_ManualIPs = $null
        if ($_IsManual) {

            $_ManualIPList = [System.Collections.Generic.List[string]]::new()

            if ($IPAddress) {
                foreach ($_ip in $IPAddress) {
                    $_ManualIPList.Add($_ip.Trim())
                }
            }

            if ($IPRange) {
                foreach ($_range in $IPRange) {
                    $null = $_range -match '^\s*(\d{1,3}(?:\.\d{1,3}){3})\s*-\s*(\d{1,3}(?:\.\d{1,3}){3})\s*$'
                    $_startIP  = $matches[1]
                    $_endIP    = $matches[2]
                    $_startInt = ConvertTo-UInt32IPv4 $_startIP
                    $_endInt   = ConvertTo-UInt32IPv4 $_endIP

                    if ($_endInt -lt $_startInt) {
                        $ErrorMessage = "Invalid IP range '{0}': the end address must be greater than or equal to the start address." -f $_range
                        if ($WhatIf) {
                            Write-Warning "$ErrorMessage Cannot display API request."
                            return
                        }
                        $Exception = New-Object System.Exception($ErrorMessage)
                        $ErrorRecord = New-Object System.Management.Automation.ErrorRecord($Exception, 'InvalidIPRange', [System.Management.Automation.ErrorCategory]::InvalidArgument, $_range)
                        $PSCmdlet.ThrowTerminatingError($ErrorRecord)
                    }

                    for ($_i = $_startInt; $_i -le $_endInt; $_i++) {
                        $_ManualIPList.Add((ConvertFrom-UInt32IPv4 $_i))
                        # Guard against unsigned overflow when the range ends at 255.255.255.255
                        if ($_i -eq [uint32]::MaxValue) { break }
                    }
                }
            }

            # De-duplicate while preserving order
            $_ManualIPs = [System.Collections.Generic.List[string]]::new()
            $_seenIPs   = [System.Collections.Generic.HashSet[string]]::new()
            foreach ($_ip in $_ManualIPList) {
                if ($_seenIPs.Add($_ip)) {
                    $_ManualIPs.Add($_ip)
                }
            }

            "[{0}] Manual discovery: {1} target IP address(es) resolved" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_ManualIPs.Count | Write-Verbose

            if ($_ManualIPs.Count -eq 0) {
                $ErrorMessage = "Manual discovery requires at least one valid IP address. No target IP addresses were resolved from -IPAddress / -IPRange."
                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
                    return
                }
                $Exception = New-Object System.Exception($ErrorMessage)
                $ErrorRecord = New-Object System.Management.Automation.ErrorRecord($Exception, 'NoManualIPs', [System.Management.Automation.ErrorCategory]::InvalidArgument, $SecureGatewayName)
                $PSCmdlet.ThrowTerminatingError($ErrorRecord)
            }

            if ($_ManualIPs.Count -gt $_ManualIPMaxCount) {
                $ErrorMessage = "Manual discovery resolved {0} IP addresses, which exceeds the maximum of {1}. Reduce the size or number of ranges specified with -IPRange." -f $_ManualIPs.Count, $_ManualIPMaxCount
                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
                    return
                }
                $Exception = New-Object System.Exception($ErrorMessage)
                $ErrorRecord = New-Object System.Management.Automation.ErrorRecord($Exception, 'TooManyManualIPs', [System.Management.Automation.ErrorCategory]::InvalidArgument, $SecureGatewayName)
                $PSCmdlet.ThrowTerminatingError($ErrorRecord)
            }
        }

        # Warn about the network scan and prompt for confirmation (unless -Force or -WhatIf)
        if (-not $Force -and -not $WhatIf) {

            if ($_IsManual) {
                Write-Warning ("Server discovery on Secure Gateway '{0}' will probe {1} specified IP address(es) to detect HPE iLO devices. This probe may trigger intrusion detection/prevention systems (IDS/IPS) or security monitoring alerts, and may be subject to your organization's network scanning authorization policy. Ensure you are authorized to scan these addresses before proceeding." -f $SecureGatewayName, $_ManualIPs.Count)
                $question = "Do you want to start the manual server discovery on Secure Gateway '$SecureGatewayName' in the '$Region' region?"
            }
            else {
                Write-Warning ("Server discovery on Secure Gateway '{0}' runs an active nmap network scan across the appliance's local subnet to detect HPE iLO devices. This scan may trigger intrusion detection/prevention systems (IDS/IPS) or security monitoring alerts, and may be subject to your organization's network scanning authorization policy. Depending on the size of the subnet, the scan can take a long time to complete (from several minutes to much longer for large subnets). Ensure you are authorized to scan this network before proceeding." -f $SecureGatewayName)
                $question = "Do you want to start the nmap-based server discovery on Secure Gateway '$SecureGatewayName' in the '$Region' region?"
            }

            $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Start the server discovery."
            $no  = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Cancel the server discovery."
            $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
            $decision = $Host.UI.PromptForChoice("Confirm Secure Gateway server discovery", $question, $choices, 1)

            if ($decision -eq 1) {
                "[{0}] Server discovery cancelled by user for Secure Gateway '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SecureGatewayName | Write-Verbose
                Write-Verbose "Operation cancelled by the user!"
                return
            }
        }

        # Build the job or schedule payload following the working COM job pattern
        # (immediate job: jobTemplate / resourceId / resourceType / jobParams)
        if ($ScheduleTime) {

            $Uri = Get-COMSchedulesUri

            $_Data = @{
                discoveryMode = $_DiscoveryMode
            }
            if ($_IsManual) {
                $_Data.ips = @($_ManualIPs)
            }

            $_Body = @{
                jobTemplateUri = "/api/compute/v1/job-templates/" + $JobTemplateId
                resourceUri    = $_ApplianceResourceUri
                data           = $_Data
            }

            $Operation = @{
                type   = "REST"
                method = "POST"
                uri    = "/api/compute/v1/jobs"
                body   = $_Body
            }

            $randomNumber = Get-Random -Minimum 000000 -Maximum 999999
            $ScheduleName = "$($SecureGatewayName)_SecureGatewayServerDiscovery_Schedule_$($randomNumber)"
            $Description  = if ($_IsManual) {
                "Scheduled task to run manual server discovery on Secure Gateway '$($SecureGatewayName)'"
            }
            else {
                "Scheduled task to run nmap-based server discovery on Secure Gateway '$($SecureGatewayName)'"
            }

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
                associatedResourceUri = $_ApplianceResourceUri
                purpose               = "SECURE_GATEWAY_SERVER_DISCOVERY"
                schedule              = $Schedule
                operation             = $Operation
            }
        }
        else {

            $Uri = $JobsUri

            $_JobParams = @{
                discoveryMode = $_DiscoveryMode
            }
            if ($_IsManual) {
                $_JobParams.ips = @($_ManualIPs)
            }

            $payload = @{
                jobTemplate  = $JobTemplateId
                resourceId   = $_ApplianceDeviceId
                resourceType = "compute-ops-mgmt/appliance"
                jobParams    = $_JobParams
            }
        }

        $payload = ConvertTo-Json $payload -Depth 10

        try {
            $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if ($WhatIf) {
            return
        }

        # Schedule mode: return the created schedule resource
        if ($ScheduleTime) {
            "[{0}] Discovery schedule created for Secure Gateway '{1}' in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SecureGatewayName, $Region | Write-Verbose
            $ReturnData = Invoke-RepackageObjectWithType -RawObject $Response -ObjectName "COM.Schedules"
            Return $ReturnData
        }

        # Async mode: return the job resource immediately without waiting
        if ($Async) {
            "[{0}] Discovery job submitted for Secure Gateway '{1}' in '{2}' region (async)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SecureGatewayName, $Region | Write-Verbose
            $Response | Add-Member -type NoteProperty -name region -value $Region -Force
            $ReturnData = Invoke-RepackageObjectWithType -RawObject $Response -ObjectName "COM.Jobs"
            Return $ReturnData
        }

        # Synchronous mode: wait for the discovery job to complete, then retrieve discovered servers
        "[{0}] Discovery job submitted for Secure Gateway '{1}' in '{2}' region, waiting for completion..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $SecureGatewayName, $Region | Write-Verbose

        try {
            $JobResult = Wait-HPECOMJobComplete -Region $Region -Job $Response.resourceUri -Timeout 600 -Verbose:$VerbosePreference
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        "[{0}] Job result: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($JobResult | Out-String) | Write-Verbose

        # Save last job result for easy post-execution inspection
        $Global:HPECOMLastJobResult = $JobResult

        if ($JobResult.resultCode -ne "SUCCESS") {

            $ErrorMessage = if ($JobResult.message) { $JobResult.message } else { "Server discovery job did not complete successfully on Secure Gateway '$SecureGatewayName'. Result: $($JobResult.resultCode)" }
            $Exception = New-Object System.Exception($ErrorMessage)
            $ErrorRecord = New-Object System.Management.Automation.ErrorRecord($Exception, 'DiscoveryJobFailed', [System.Management.Automation.ErrorCategory]::OperationStopped, $SecureGatewayName)
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }

        # Retrieve the list of discovered servers.
        # Note: the discovered-servers list endpoint requires a 'method' filter that must match the discovery mode used
        # ('nmapScan' or 'manual'). For manual discovery the endpoint only returns results when queried with just the
        # 'applianceID' and 'method=manual' parameters - adding the nmap-style filters (hide / externalManager /
        # onboarding) causes an empty result set - so each mode uses its own query string.
        if ($_IsManual) {
            $DiscoveredServersUri = "{0}?applianceID={1}&method=manual" -f (Get-COMDiscoveredServersUri), $_ApplianceId
        }
        else {
            $DiscoveredServersUri = "{0}?hide=false&externalManager=None&onboarding=false&applianceID={1}&method=nmapScan" -f (Get-COMDiscoveredServersUri), $_ApplianceId
        }

        try {
            [Array]$DiscoveredServers = Invoke-HPECOMWebRequest -Method Get -Uri $DiscoveredServersUri -Region $Region -WhatIfBoolean $false -Verbose:$VerbosePreference
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        "[{0}] Discovered {1} server(s) on Secure Gateway '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DiscoveredServers.Count, $SecureGatewayName | Write-Verbose

        # Collect addresses the Secure Gateway could not discover (marked with a non-empty 'error' field, e.g. 'SG-DIS-00001')
        $_FailedServers = [System.Collections.Generic.List[string]]::new()

        foreach ($_server in $DiscoveredServers) {

            # A non-empty 'error' field means the Secure Gateway failed to discover/reach this address - skip it and report it separately
            if ($_server.error) {
                "[{0}] Discovery failed for IP '{1}' on Secure Gateway '{2}' (error code: '{3}')" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_server.ip, $SecureGatewayName, $_server.error | Write-Verbose
                if ($_server.ip) {
                    $_FailedServers.Add($_server.ip)
                }
                continue
            }

            # Determine the iLO generation number from the 'ilo' field (e.g. 'iLO 6' -> 6)
            $_genNumber = $null
            if ($_server.ilo -and $_server.ilo -match '(\d+)') {
                $_genNumber = $matches[1]
                $_iLOGeneration = "iLO $_genNumber"
            }
            else {
                $_iLOGeneration = "Unknown"
            }

            # Determine whether the iLO firmware needs to be updated before it can connect to Compute Ops Management
            $_iLOUpdateRequired = "Unknown"
            if ($_genNumber -and $_iLOMinimumVersions.ContainsKey($_genNumber) -and $_server.iloVersion -and $_server.iloVersion -ne 'N/A') {
                try {
                    $_parsedVersion = [version]($_server.iloVersion -replace '[^\d.].*$', '')
                    $_iLOUpdateRequired = if ($_parsedVersion -ge $_iLOMinimumVersions[$_genNumber]) { "No" } else { "Yes" }
                }
                catch {
                    "[{0}] Could not parse iLO version '{1}' for {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_server.iloVersion, $_server.ip | Write-Verbose
                }
            }

            $objDiscovered = [PSCustomObject]@{
                IP                     = $_server.ip
                iLOGeneration          = $_iLOGeneration
                iLOVersion             = $_server.iloVersion
                iLOUpdateRequired      = $_iLOUpdateRequired
                CertificateFingerprint = $_server.certificateFingerprint
                SecureGateway          = $SecureGatewayName
                Region                 = $Region
                ApplianceId            = $_ApplianceId
            }

            [void]$DiscoveredList.Add($objDiscovered)
        }

        # Warn about any addresses the Secure Gateway failed to discover (matches the HPE GreenLake console behavior)
        if ($_FailedServers.Count -gt 0) {
            $_failedIPList = $_FailedServers -join ', '
            Write-Warning ("{0} server(s) failed to be added for onboarding on Secure Gateway '{1}': {2}. Verify the specified IPv4 address(es) are reachable HPE iLO devices behind the Secure Gateway and try again." -f $_FailedServers.Count, $SecureGatewayName, $_failedIPList)
        }

    }

    End {

        if ($DiscoveredList.Count -gt 0) {
            $DiscoveredList = Invoke-RepackageObjectWithType -RawObject $DiscoveredList -ObjectName "COM.DiscoveredServers"
            Return $DiscoveredList
        }
    }
}


Function Get-HPECOMSecureGatewayServerDiscovery {
    <#
    .SYNOPSIS
    Retrieve the servers discovered behind an HPE Secure Gateway appliance.

    .DESCRIPTION
    This cmdlet returns the list of servers discovered behind an HPE Secure Gateway appliance in Compute Ops Management,
    as produced by the most recent network (nmap) discovery run with 'Invoke-HPECOMSecureGatewayServerDiscovery'.

    For each discovered server, the cmdlet reports the IP address, iLO generation, iLO firmware version, whether an iLO
    firmware update is required before the server can be connected to Compute Ops Management, and the iLO certificate
    fingerprint.

    If no discovery has ever been run on the Secure Gateway, the cmdlet returns a warning recommending that you run
    'Invoke-HPECOMSecureGatewayServerDiscovery' first. If a discovery has been run but no servers were detected, the
    cmdlet returns nothing.

    The returned objects are designed to be piped directly to 'Connect-HPEGLDeviceComputeiLOtoCOM' to onboard the
    discovered iLOs to Compute Ops Management through the Secure Gateway.

    Note that, to be connected to Compute Ops Management, iLO must be updated to the following minimum versions:
    - iLO 5: v3.09 or later
    - iLO 6: v1.64 or later
    - iLO 7: v1.12.00 or later
    Discovered servers running an older iLO firmware are reported with 'iLOUpdateRequired = Yes'.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the Secure Gateway appliance is registered.
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER SecureGateway
    Specifies the HPE Secure Gateway appliance for which to retrieve the discovered servers.
    This parameter accepts either the name (hostname) of the Secure Gateway as a string, or a Secure Gateway object retrieved from 'Get-HPECOMAppliance -Type SecureGateway'.

    .PARAMETER ReadyForConnection
    Returns only the discovered servers whose iLO firmware already meets the minimum version required to connect to Compute Ops Management (i.e. 'iLOUpdateRequired = No').
    This is a convenience switch that replaces piping the output to 'Where-Object iLOUpdateRequired -eq "No"', making it easy to onboard only the servers that are ready by piping directly to 'Connect-HPEGLDeviceComputeiLOtoCOM'.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lj.lab"

    Returns the servers discovered behind the Secure Gateway 'sg01.lj.lab' in the 'eu-central' region.

    .EXAMPLE
    Get-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lj.lab" -ReadyForConnection

    Returns only the servers discovered behind the Secure Gateway 'sg01.lj.lab' whose iLO firmware already meets the minimum version required to connect to Compute Ops Management.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Type SecureGateway -Name "sg01.lj.lab" | Get-HPECOMSecureGatewayServerDiscovery

    Retrieves the Secure Gateway 'sg01.lj.lab' and returns the servers discovered behind it.

    .EXAMPLE
    $iLO_credential = Get-Credential
    $COM_Activation_Key = New-HPECOMServerActivationKey -Region eu-central -SecureGateway "sg01.lj.lab"

    Get-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lj.lab" -ReadyForConnection |
        Connect-HPEGLDeviceComputeiLOtoCOM -IloCredential $iLO_credential -ActivationKeyfromCOM $COM_Activation_Key

    Retrieves the servers discovered behind the Secure Gateway 'sg01.lj.lab', keeps only the iLOs that do not require a firmware update first, and onboards them to Compute Ops Management through the Secure Gateway using a COM activation key.
    Because the activation key is generated for the Secure Gateway, the onboarded iLOs are automatically configured to connect to Compute Ops Management through that gateway.

    .EXAMPLE
    $iLO_credential = Get-Credential
    $SubscriptionKey = Get-HPEGLSubscription -ShowDeviceSubscriptions -ShowWithAvailableQuantity -ShowValid | Where-Object tier -eq "ENHANCED_PROLIANT" | Select-Object -First 1 -ExpandProperty Key

    Get-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lj.lab" |
        Connect-HPECOMSecureGatewayDiscoveredServer -IloCredential $iLO_credential -SubscriptionKey $SubscriptionKey

    Retrieves all servers discovered behind the Secure Gateway 'sg01.lj.lab' and onboards them to Compute Ops Management through the gateway using 'Connect-HPECOMSecureGatewayDiscoveredServer'.

    Unlike the previous example (which uses 'Connect-HPEGLDeviceComputeiLOtoCOM' with a pre-generated activation key), this approach does not require creating an activation key beforehand: Compute Ops Management generates the Secure Gateway activation key automatically and updates the iLO firmware on any server reported with 'iLOUpdateRequired = Yes' before connecting it. It only requires a valid COM subscription key with available quantity (retrieved here with 'Get-HPEGLSubscription').

    .INPUTS
    System.String
        The name of a Secure Gateway appliance.
    HPEGreenLake.COM.Appliances
        A Secure Gateway object from 'Get-HPECOMAppliance -Type SecureGateway'.

    .OUTPUTS
    HPEGreenLake.COM.DiscoveredServers [System.Management.Automation.PSCustomObject]

        Returns one object per discovered server, with the following properties:
            - IP - IP address of the discovered iLO (can be piped to 'Connect-HPEGLDeviceComputeiLOtoCOM')
            - iLOGeneration - iLO generation reported by the discovery (e.g. 'iLO 6')
            - iLOVersion - iLO firmware version detected
            - iLOUpdateRequired - 'Yes' if the iLO firmware is below the minimum version required to connect to Compute Ops Management, 'No' if it meets the minimum, 'Unknown' if it could not be determined
            - CertificateFingerprint - SHA-256 fingerprint of the iLO TLS certificate
            - SecureGateway - Name of the Secure Gateway used for the discovery
            - Region - Name of the region where the discovery was run
            - ApplianceId - Identifier of the Secure Gateway appliance

    #>

    [CmdletBinding()]
    Param(

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateScript({
                # First check if there's an active session with COM regions
                if (-not $Global:HPEGreenLakeSession) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use the cmdlets of the HPECOMCmdlets module."
                }
                if (-not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "Compute Ops Management is not provisioned in this workspace!`n`nCAUSE:`nNo provisioned Compute Ops Management region was found.`n`nACTION REQUIRED:`nVerify the Compute Ops Management service is provisioned using:`n    Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned`n`nIf not provisioned, you can provision it using 'New-HPEGLService'."
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
        [Alias('name')]
        [object]$SecureGateway,

        [Alias('Ready')]
        [Switch]$ReadyForConnection,

        [Switch]$WhatIf
    )

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $DiscoveredList = [System.Collections.ArrayList]::new()

        # Minimum iLO firmware versions required to connect a server to Compute Ops Management
        $_iLOMinimumVersions = @{
            '5' = [version]'3.09'
            '6' = [version]'1.64'
            '7' = [version]'1.12.00'
        }

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | Out-String) | Write-Verbose

        # Resolve the Secure Gateway resource (accept a name string or a Secure Gateway object)
        try {
            if ($SecureGateway -is [string]) {
                "[{0}] SecureGateway parameter is a string" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                $SecureGatewayName = $SecureGateway
                $ApplianceResource = Get-HPECOMAppliance -Region $Region -Type SecureGateway -Name $SecureGatewayName -Verbose:$false
            }
            else {
                "[{0}] SecureGateway parameter is an object" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                $SecureGatewayName = $SecureGateway.name
                $ApplianceResource = Get-HPECOMAppliance -Region $Region -Type SecureGateway -Name $SecureGatewayName -Verbose:$false
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if (-not $ApplianceResource) {
            "[{0}] Secure Gateway '{1}' cannot be found in the '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SecureGatewayName, $Region | Write-Verbose
            if ($WhatIf) {
                Write-Warning ("Secure Gateway '{0}' cannot be found in the '{1}' region! Cannot display API request." -f $SecureGatewayName, $Region)
            }
            return
        }

        if ($ApplianceResource.applianceType -ne "GATEWAY") {
            "[{0}] Appliance '{1}' is not a Secure Gateway" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SecureGatewayName | Write-Verbose
            Write-Warning ("Appliance '{0}': Server discovery is only supported for HPE Secure Gateway appliances. OneView appliances (VM or Synergy) are not supported." -f $SecureGatewayName)
            return
        }

        $_ApplianceResourceUri = $ApplianceResource.resourceUri
        $_ApplianceDeviceId    = $ApplianceResource.deviceId
        # The appliance identifier used by the discovered-servers endpoint is the segment that follows 'gateway+' in the resource URI
        if ($_ApplianceResourceUri -match 'gateway\+(.+)$') {
            $_ApplianceId = $matches[1]
        }
        else {
            $_ApplianceId = $_ApplianceDeviceId
        }

        "[{0}] Secure Gateway '{1}' resource URI: '{2}' (appliance ID: '{3}')" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SecureGatewayName, $_ApplianceResourceUri, $_ApplianceId | Write-Verbose

        # Probe the discovery summary endpoint to determine whether a discovery has ever been run on this Secure Gateway.
        # The summary resource does not exist until a discovery has been performed, so a failed/empty response means
        # no discovery has been run yet.
        if (-not $WhatIf) {

            $SummaryUri = "{0}?applianceID={1}&method=nmapScan" -f (Get-COMDiscoveredServersSummaryUri), $_ApplianceId

            $_DiscoveryHasRun = $false
            try {
                $Summary = Invoke-HPECOMWebRequest -Method Get -Uri $SummaryUri -Region $Region -ReturnFullObject -WhatIfBoolean $false -Verbose:$VerbosePreference
                if ($null -ne $Summary) {
                    $_DiscoveryHasRun = $true
                }
            }
            catch {
                "[{0}] No discovery summary available for Secure Gateway '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SecureGatewayName, $_.Exception.Message | Write-Verbose
            }

            if (-not $_DiscoveryHasRun) {
                "[{0}] No discovery has been run on Secure Gateway '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SecureGatewayName | Write-Verbose
                Write-Warning ("No server discovery has been run yet on Secure Gateway '{0}' in the '{1}' region. Run 'Invoke-HPECOMSecureGatewayServerDiscovery' first to discover servers." -f $SecureGatewayName, $Region)
                return
            }
        }

        # Retrieve the list of discovered servers
        $DiscoveredServersUri = "{0}?hide=false&externalManager=None&onboarding=false&applianceID={1}&method=nmapScan" -f (Get-COMDiscoveredServersUri), $_ApplianceId

        try {
            [Array]$DiscoveredServers = Invoke-HPECOMWebRequest -Method Get -Uri $DiscoveredServersUri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if ($WhatIf) {
            return
        }

        "[{0}] Discovered {1} server(s) on Secure Gateway '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DiscoveredServers.Count, $SecureGatewayName | Write-Verbose

        foreach ($_server in $DiscoveredServers) {

            # Determine the iLO generation number from the 'ilo' field (e.g. 'iLO 6' -> 6)
            $_genNumber = $null
            if ($_server.ilo -and $_server.ilo -match '(\d+)') {
                $_genNumber = $matches[1]
                $_iLOGeneration = "iLO $_genNumber"
            }
            else {
                $_iLOGeneration = "Unknown"
            }

            # Determine whether the iLO firmware needs to be updated before it can connect to Compute Ops Management
            $_iLOUpdateRequired = "Unknown"
            if ($_genNumber -and $_iLOMinimumVersions.ContainsKey($_genNumber) -and $_server.iloVersion -and $_server.iloVersion -ne 'N/A') {
                try {
                    $_parsedVersion = [version]($_server.iloVersion -replace '[^\d.].*$', '')
                    $_iLOUpdateRequired = if ($_parsedVersion -ge $_iLOMinimumVersions[$_genNumber]) { "No" } else { "Yes" }
                }
                catch {
                    "[{0}] Could not parse iLO version '{1}' for {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_server.iloVersion, $_server.ip | Write-Verbose
                }
            }

            $objDiscovered = [PSCustomObject]@{
                IP                     = $_server.ip
                iLOGeneration          = $_iLOGeneration
                iLOVersion             = $_server.iloVersion
                iLOUpdateRequired      = $_iLOUpdateRequired
                CertificateFingerprint = $_server.certificateFingerprint
                SecureGateway          = $SecureGatewayName
                Region                 = $Region
                ApplianceId            = $_ApplianceId
            }

            [void]$DiscoveredList.Add($objDiscovered)
        }

    }

    End {

        # When -ReadyForConnection is set, keep only the servers whose iLO firmware meets the minimum version required to connect to Compute Ops Management
        if ($ReadyForConnection) {
            $DiscoveredList = [System.Collections.ArrayList]::new(@($DiscoveredList | Where-Object { $_.iLOUpdateRequired -eq 'No' }))
        }

        if ($DiscoveredList.Count -gt 0) {
            $DiscoveredList = Invoke-RepackageObjectWithType -RawObject $DiscoveredList -ObjectName "COM.DiscoveredServers"
            $DiscoveredList =  $DiscoveredList | Sort-Object -Property IP
            Return $DiscoveredList
        }
    }
}


Function Connect-HPECOMSecureGatewayDiscoveredServer {
    <#
    .SYNOPSIS
    Onboard servers discovered behind an HPE Secure Gateway appliance to Compute Ops Management.

    .DESCRIPTION
    This cmdlet onboards one or more servers that were discovered behind an HPE Secure Gateway appliance (using
    'Invoke-HPECOMSecureGatewayServerDiscovery' / 'Get-HPECOMSecureGatewayServerDiscovery') to Compute Ops Management,
    connecting their iLOs to Compute Ops Management through the Secure Gateway.

    This is the automated, gateway-driven onboarding workflow (the equivalent of the "add multiple servers via Secure
    Gateway" wizard in the Compute Ops Management UI). Unlike 'Connect-HPEGLDeviceComputeiLOtoCOM' (which connects a
    single iLO directly and requires a pre-generated activation key), this cmdlet submits a single batch request to
    Compute Ops Management, which then orchestrates the whole onboarding through the Secure Gateway:
    - generates the Secure Gateway activation key automatically (no activation key needs to be provided),
    - updates the iLO firmware on each server whose discovery result reports 'iLOUpdateRequired = Yes' (an iLO below the minimum version cannot connect to Compute Ops Management),
    - configures DNS and NTP on the iLO when provided,
    - assigns an optional subscription, location, service delivery contact and tags,
    - connects each iLO to Compute Ops Management through the Secure Gateway.

    Servers whose discovery reports 'iLOUpdateRequired = Unknown' (the iLO generation or firmware version could not be
    determined) are skipped with a warning and are not onboarded, because the Secure Gateway cannot safely decide whether
    a firmware update is required.

    The cmdlet accepts the discovered server objects directly from the pipeline (their IP, certificate fingerprint,
    Secure Gateway and appliance ID are reused automatically). It accumulates all servers piped in and submits a single
    onboarding job per Secure Gateway.

    The operation returns a job that you can monitor. By default the cmdlet waits for the onboarding job to complete; use
    -Async to return the job resource immediately.

    iLO CREDENTIALS:
    Two modes are supported, matching the Compute Ops Management UI:
    - Same credential for all iLOs: pass -IloCredential once on the command line; it is applied to every discovered
      server piped in.
    - Different credential per iLO: attach an 'IloCredential' property (a PSCredential) to each discovered server object
      before piping it in; each server then uses its own credential. For example:

          $servers = Get-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lj.lab"
          foreach ($s in $servers) {
              $s | Add-Member -NotePropertyName IloCredential -NotePropertyValue (Get-Credential -Message $s.IP)
          }
          $servers | Connect-HPECOMSecureGatewayDiscoveredServer -SubscriptionKey "KA5DJYHUU4A2D"

    Note that, to be connected to Compute Ops Management, iLO must be updated to the following minimum versions:
    - iLO 5: v3.09 or later
    - iLO 6: v1.64 or later
    - iLO 7: v1.12.00 or later
    Servers running an older iLO firmware are updated by the Secure Gateway before onboarding; updating the iLO firmware
    reboots the iLO.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the Secure Gateway appliance is registered.
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER SecureGateway
    Specifies the name (hostname/FQDN) of the HPE Secure Gateway appliance through which the discovered servers are onboarded.
    When the discovered server objects are piped from 'Get-HPECOMSecureGatewayServerDiscovery', this value is supplied automatically.

    .PARAMETER IloIP
    Specifies the IP address (host) of the discovered iLO to onboard.
    When the discovered server objects are piped from 'Get-HPECOMSecureGatewayServerDiscovery', this value is supplied automatically from the 'IP' property.

    .PARAMETER IloCredential
    Specifies the iLO credential (PSCredential) used to onboard the server.
    Pass it once on the command line to apply the same credential to every server (same-credential mode), or attach an 'IloCredential' property to each piped server object to use a different credential per iLO (per-iLO mode). See the description for details.

    .PARAMETER CertificateFingerprint
    Specifies the SHA-256 fingerprint of the iLO TLS certificate (as reported by the discovery).
    When the discovered server objects are piped from 'Get-HPECOMSecureGatewayServerDiscovery', this value is supplied automatically.

    .PARAMETER iLOUpdateRequired
    Indicates whether the iLO firmware must be updated to the minimum version required to connect to Compute Ops Management ('Yes', 'No' or 'Unknown').
    When the discovered server objects are piped from 'Get-HPECOMSecureGatewayServerDiscovery', this value is supplied automatically and determines whether the Secure Gateway updates the iLO firmware before onboarding each server: servers reported as 'Yes' have their iLO firmware updated, servers reported as 'No' are onboarded without a firmware update, and servers reported as 'Unknown' (firmware compliance could not be determined) are skipped with a warning. If omitted, no firmware update is requested for that server.

    .PARAMETER ApplianceId
    Specifies the identifier of the Secure Gateway appliance.
    When the discovered server objects are piped from 'Get-HPECOMSecureGatewayServerDiscovery', this value is supplied automatically. If omitted, it is resolved from the Secure Gateway name.

    .PARAMETER Dns
    Specifies the DNS server IP address to configure on the iLO during onboarding.

    .PARAMETER Ntp
    Specifies the NTP server IP address (or hostname) to configure on the iLO during onboarding.

    .PARAMETER SubscriptionKey
    Specifies the device subscription key to assign to the onboarded servers.
    This value can be retrieved using 'Get-HPEGLSubscription -ShowWithAvailableQuantity -ShowValid -FilterBySubscriptionType Server'.
    If omitted, no subscription is assigned (which requires the workspace automatic device subscription to be enabled; see 'Set-HPEGLDeviceAutoSubscription').

    .PARAMETER LocationName
    Specifies the name of an existing location to assign to the onboarded servers. The location can be retrieved using 'Get-HPEGLLocation'.

    .PARAMETER ServiceDeliveryContact
    Specifies the email address of the service delivery contact to assign to the onboarded servers.

    .PARAMETER Tags
    Specifies one or more tags to assign to the onboarded servers. Tags must use the string format: <Name>=<Value>, <Name>=<Value>.

    Supported tags example:
        - "Country=US"
        - "Country=US, App=VMware ESX"
        - "Country=US, State =TX ,App= Grafana " (surrounding spaces are trimmed)

    .PARAMETER Async
    Returns the onboarding job resource immediately to monitor (using 'state' and 'resultCode' properties). By default, the cmdlet waits for the onboarding job to complete.

    .PARAMETER Force
    Bypasses the confirmation prompt that is displayed when one or more iLO firmware updates will be performed (because updating the iLO firmware reboots the iLO).

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    $iLO_credential = Get-Credential

    Get-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lj.lab" -ReadyForConnection |
        Connect-HPECOMSecureGatewayDiscoveredServer -IloCredential $iLO_credential -SubscriptionKey "KA5DJYHUU4A2D"

    Onboards every discovered server that is ready to connect (iLO firmware already compliant) behind the Secure Gateway 'sg01.lj.lab', using the same iLO credential for all of them, and assigns the specified subscription. Waits for the onboarding job to complete.

    .EXAMPLE
    $iLO_credential = Get-Credential
    $SubscriptionKey = Get-HPEGLSubscription -ShowDeviceSubscriptions -ShowWithAvailableQuantity -ShowValid | Where-Object tier -eq "ENHANCED_PROLIANT" | Select-Object -First 1 -ExpandProperty Key

    Get-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lj.lab" |
        Connect-HPECOMSecureGatewayDiscoveredServer -IloCredential $iLO_credential -SubscriptionKey $SubscriptionKey -Dns 192.168.2.1 -Ntp 1.1.1.1 -LocationName "Houston" -ServiceDeliveryContact "support@example.com" -Tags "App=AI, Country=US" -Force

    Onboards all servers discovered behind the Secure Gateway 'sg01.lj.lab' with a full configuration in a single call: it assigns the subscription, configures the iLO DNS (192.168.2.1) and NTP (1.1.1.1) servers, sets the location to "Houston", the service delivery contact to "support@example.com", and applies the tags 'App=AI' and 'Country=US'.

    Any server whose discovery reports 'iLOUpdateRequired = Yes' has its iLO firmware updated by the Secure Gateway before onboarding (which reboots that iLO). The -Force switch bypasses the confirmation prompt that would otherwise warn about these firmware updates.

    .EXAMPLE
    $SubscriptionKey = Get-HPEGLSubscription -ShowDeviceSubscriptions -ShowWithAvailableQuantity -ShowValid | Where-Object tier -eq "ENHANCED_PROLIANT" | Select-Object -First 1 -ExpandProperty Key

    $servers = Get-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lj.lab"
    foreach ($s in $servers) {
        $s | Add-Member -NotePropertyName IloCredential -NotePropertyValue (Get-Credential -Message $s.IP)
    }
    $servers | Connect-HPECOMSecureGatewayDiscoveredServer -SubscriptionKey $SubscriptionKey

    Onboards all servers discovered behind the Secure Gateway 'sg01.lj.lab' using a different iLO credential for each server (per-iLO credential mode).

    Instead of passing a single -IloCredential on the command line, an 'IloCredential' property is attached to each discovered server object (here prompting once per server, using the iLO IP as the prompt message). When the objects are piped in, each server is onboarded with its own credential.

    .EXAMPLE
    # iLO_credentials.csv content:
    #   IP,Username,Password
    #   192.168.1.45,admin,Password123
    #   192.168.1.46,Administrator,S3cr3t!

    $CsvCredentials = @{}
    foreach ($row in (Import-Csv -Path .\iLO_credentials.csv)) {
        $securePassword = ConvertTo-SecureString $row.Password -AsPlainText -Force
        $CsvCredentials[$row.IP] = [System.Management.Automation.PSCredential]::new($row.Username, $securePassword)
    }

    $servers = Get-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lj.lab"
    foreach ($s in $servers) {
        $s | Add-Member -NotePropertyName IloCredential -NotePropertyValue $CsvCredentials[$s.IP]
    }
    $servers | Connect-HPECOMSecureGatewayDiscoveredServer -SubscriptionKey $SubscriptionKey

    Onboards all servers discovered behind the Secure Gateway 'sg01.lj.lab' using per-iLO credentials read from a CSV file (per-iLO credential mode), avoiding any interactive credential prompt.

    The CSV (with 'IP', 'Username' and 'Password' columns) is loaded into a hashtable keyed by iLO IP address. Each discovered server is then matched to its credential by IP and gets an 'IloCredential' property before being piped in. Note that storing iLO passwords in clear text in a CSV file is a security risk; restrict access to the file and delete it after use, or use an encrypted credential store instead.

    .EXAMPLE
    Get-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lj.lab" -ReadyForConnection |
        Connect-HPECOMSecureGatewayDiscoveredServer -IloCredential $iLO_credential -SubscriptionKey $SubscriptionKey -WhatIf

    Shows the raw onboarding REST API request that would be sent to Compute Ops Management, without onboarding anything.

    .INPUTS
    HPEGreenLake.COM.DiscoveredServers [System.Management.Automation.PSCustomObject]
        Discovered server objects from 'Get-HPECOMSecureGatewayServerDiscovery' or 'Invoke-HPECOMSecureGatewayServerDiscovery'.

    .OUTPUTS
    HPEGreenLake.COM.Jobs [System.Management.Automation.PSCustomObject]
        The onboarding job resource. By default the completed job is returned; with -Async the job is returned immediately.

    #>

    [CmdletBinding()]
    Param(

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateScript({
                if (-not $Global:HPEGreenLakeSession) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use the cmdlets of the HPECOMCmdlets module."
                }
                if (-not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "Compute Ops Management is not provisioned in this workspace!`n`nCAUSE:`nNo provisioned Compute Ops Management region was found.`n`nACTION REQUIRED:`nVerify the Compute Ops Management service is provisioned using:`n    Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned`n`nIf not provisioned, you can provision it using 'New-HPEGLService'."
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

        [Parameter (Mandatory, ValueFromPipelineByPropertyName, DontShow)]
        [ValidateNotNullOrEmpty()]
        [String]$SecureGateway,

        [Parameter (Mandatory, ValueFromPipelineByPropertyName, DontShow)]
        [Alias('IP')]
        [ValidateNotNullOrEmpty()]
        [String]$IloIP,

        [Parameter (ValueFromPipelineByPropertyName)]
        [PSCredential]$IloCredential,

        [Parameter (ValueFromPipelineByPropertyName, DontShow)]
        [String]$CertificateFingerprint,

        [Parameter (ValueFromPipelineByPropertyName, DontShow)]
        [ValidateSet('Yes', 'No', 'Unknown')]
        [String]$iLOUpdateRequired,

        [Parameter (ValueFromPipelineByPropertyName, DontShow)]
        [String]$ApplianceId,

        [ValidateNotNullOrEmpty()]
        [String]$Dns,

        [ValidateNotNullOrEmpty()]
        [String]$Ntp,

        [ValidateNotNullOrEmpty()]
        [String]$SubscriptionKey,

        [ValidateNotNullOrEmpty()]
        [String]$LocationName,

        [ValidateNotNullOrEmpty()]
        [String]$ServiceDeliveryContact,

        [ValidateNotNullOrEmpty()]
        [String]$Tags,

        [Switch]$Async,

        [Switch]$Force,

        [Switch]$WhatIf
    )

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        # Accumulates one entry per server piped in; servers are grouped per Secure Gateway and submitted as a single onboarding request in the End block
        $OnboardList = [System.Collections.ArrayList]::new()

        $OnboardUri = "{0}/actions/onboard" -f (Get-COMDiscoveredServersUri)

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | Out-String) | Write-Verbose

        # Skip servers whose firmware compliance could not be determined (iLOUpdateRequired = 'Unknown'): their iLO generation
        # or firmware version is unknown, so the Secure Gateway cannot safely decide whether a firmware update is needed.
        if ($iLOUpdateRequired -eq 'Unknown') {
            Write-Warning ("iLO '{0}': Skipped because its firmware compliance could not be determined (iLOUpdateRequired = 'Unknown'). Verify the iLO is reachable and rerun the discovery before onboarding this server." -f $IloIP)
            return
        }

        # Resolve the iLO credential (same-credential mode = explicit -IloCredential; per-iLO mode = 'IloCredential' property on the piped object)
        if (-not $IloCredential) {
            $ErrorMessage = "iLO '{0}': No iLO credential was provided. Pass -IloCredential to use the same credential for all servers, or attach an 'IloCredential' property to each piped server to use a different credential per iLO." -f $IloIP
            $Exception = New-Object System.Exception($ErrorMessage)
            $ErrorRecord = New-Object System.Management.Automation.ErrorRecord($Exception, 'MissingIloCredential', [System.Management.Automation.ErrorCategory]::InvalidArgument, $IloIP)
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }

        # Resolve the Secure Gateway appliance ID when it was not provided by the pipeline
        $_ApplianceId = $ApplianceId
        if (-not $_ApplianceId) {
            try {
                $ApplianceResource = Get-HPECOMAppliance -Region $Region -Type SecureGateway -Name $SecureGateway -Verbose:$false
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }

            if (-not $ApplianceResource) {
                $ErrorMessage = "Secure Gateway '{0}' cannot be found in the '{1}' region!" -f $SecureGateway, $Region
                $Exception = New-Object System.Exception($ErrorMessage)
                $ErrorRecord = New-Object System.Management.Automation.ErrorRecord($Exception, 'SecureGatewayNotFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $SecureGateway)
                $PSCmdlet.ThrowTerminatingError($ErrorRecord)
            }

            if ($ApplianceResource.resourceUri -match 'gateway\+(.+)$') {
                $_ApplianceId = $matches[1]
            }
            else {
                $_ApplianceId = $ApplianceResource.deviceId
            }
        }

        # The iLO firmware is updated only when the discovery reported it as below the minimum required version (iLOUpdateRequired = 'Yes')
        $_iloUpdate = ($iLOUpdateRequired -eq 'Yes')

        $_ilo = [PSCustomObject]@{
            host                   = $IloIP
            username               = $IloCredential.UserName
            password               = $IloCredential.GetNetworkCredential().Password
            certificateFingerprint = $CertificateFingerprint
            iloUpdate              = $_iloUpdate
        }

        [void]$OnboardList.Add([PSCustomObject]@{
            Region            = $Region
            SecureGatewayName = $SecureGateway
            ApplianceId       = $_ApplianceId
            iLO               = $_ilo
            UpdateRequired    = $_iloUpdate
        })
    }

    End {

        if ($OnboardList.Count -eq 0) {
            return
        }

        # Resolve the subscription available seats once (the onboard body expects subscriptionKey + availableSeats)
        $_Subscriptions = @()
        if ($SubscriptionKey) {
            try {
                $_SubResource = Get-HPEGLSubscription -ShowWithAvailableQuantity -ShowValid -Verbose:$false | Where-Object { $_.key -eq $SubscriptionKey } | Select-Object -First 1
            }
            catch {
                $_SubResource = $null
            }

            if (-not $_SubResource) {
                $ErrorMessage = "Subscription key '{0}' cannot be found, is expired, or has no available quantity in the workspace! Retrieve a valid key using 'Get-HPEGLSubscription -ShowWithAvailableQuantity -ShowValid -FilterBySubscriptionType Server'." -f $SubscriptionKey
                $Exception = New-Object System.Exception($ErrorMessage)
                $ErrorRecord = New-Object System.Management.Automation.ErrorRecord($Exception, 'SubscriptionNotFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $SubscriptionKey)
                $PSCmdlet.ThrowTerminatingError($ErrorRecord)
            }

            $_Subscriptions = @([PSCustomObject]@{
                subscriptionKey = $SubscriptionKey
                availableSeats  = $_SubResource.availableQuantity
            })
        }

        # Resolve the location once
        $_Location = $null
        if ($LocationName) {
            try {
                $_LocationResource = Get-HPEGLLocation -Name $LocationName -Verbose:$false
            }
            catch {
                $_LocationResource = $null
            }

            if (-not $_LocationResource) {
                $ErrorMessage = "Location '{0}' cannot be found in the workspace! Retrieve an existing location using 'Get-HPEGLLocation'." -f $LocationName
                $Exception = New-Object System.Exception($ErrorMessage)
                $ErrorRecord = New-Object System.Management.Automation.ErrorRecord($Exception, 'LocationNotFound', [System.Management.Automation.ErrorCategory]::ObjectNotFound, $LocationName)
                $PSCmdlet.ThrowTerminatingError($ErrorRecord)
            }

            $_Location = [PSCustomObject]@{ id = $_LocationResource.id }
        }

        # Build the tags object map (the onboard body expects tags as an object of key/value pairs)
        # Tags are provided as a string using the format '<Name>=<Value>, <Name>=<Value>' (same as Add-HPEGLDeviceTagToDevice)
        $_Tags = [PSCustomObject]@{}
        if ($Tags) {
            foreach ($tag in $Tags.Split(',')) {

                if ($tag -notmatch '^[\p{L}\p{Nd}_ .:+\-@]+=[\p{L}\p{Nd}_ .:+\-@]+$') {
                    throw "Tag '$($tag.Trim())' format not supported! Expected format is <Name>=<Value>, <Name>=<Value>!"
                }

                $tagName = $tag.Split('=')[0].Trim()
                $tagValue = $tag.Split('=')[1].Trim()
                $_Tags | Add-Member -NotePropertyName $tagName -NotePropertyValue $tagValue -Force
            }
        }

        # Confirm the onboarding only when at least one iLO firmware update will be performed (which reboots the iLO) unless -Force or -WhatIf
        $_ServersRequiringUpdate = @($OnboardList | Where-Object { $_.UpdateRequired })

        if ($_ServersRequiringUpdate.Count -gt 0 -and -not $Force -and -not $WhatIf) {

            Write-Warning ("{0} of {1} server(s) have an iLO below the minimum required firmware version and will be updated by the Secure Gateway before onboarding. Updating the iLO firmware reboots the iLO." -f $_ServersRequiringUpdate.Count, $OnboardList.Count)

            $question = "Do you want to onboard {0} server(s) and update the iLO firmware on {1} of them?" -f $OnboardList.Count, $_ServersRequiringUpdate.Count
            $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Onboard the servers (updating the iLO firmware where required)."
            $no  = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Cancel the onboarding."
            $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
            $decision = $Host.UI.PromptForChoice("Confirm Secure Gateway server onboarding", $question, $choices, 1)

            if ($decision -eq 1) {
                "[{0}] Onboarding cancelled by user" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                return
            }
        }

        $ReturnData = [System.Collections.ArrayList]::new()

        # Group the accumulated servers per Secure Gateway and submit one onboarding request per group
        $Groups = $OnboardList | Group-Object -Property { "{0}|{1}|{2}" -f $_.Region, $_.SecureGatewayName, $_.ApplianceId }

        foreach ($Group in $Groups) {

            $_GroupRegion      = $Group.Group[0].Region
            $_GroupGatewayName = $Group.Group[0].SecureGatewayName
            $_GroupApplianceId = $Group.Group[0].ApplianceId
            $_iloArray         = @($Group.Group | ForEach-Object { $_.iLO })

            $payload = [PSCustomObject]@{
                secureGateway          = [PSCustomObject]@{
                    fqdn        = $_GroupGatewayName
                    applianceID = $_GroupApplianceId
                }
                dns                    = if ($Dns) { $Dns } else { "" }
                ntp                    = if ($Ntp) { $Ntp } else { "" }
                hideUnselectedServers  = "False"
                subscriptions          = $_Subscriptions
                location               = $_Location
                serviceDeliveryContact = if ($ServiceDeliveryContact) { $ServiceDeliveryContact } else { "" }
                tags                   = $_Tags
                ilo                    = $_iloArray
            }

            $payloadJson = ConvertTo-Json $payload -Depth 10

            try {
                $Response = Invoke-HPECOMWebRequest -Region $_GroupRegion -Uri $OnboardUri -method POST -body $payloadJson -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }

            if ($WhatIf) {
                continue
            }

            $_JobId = $Response.job_id
            if (-not $_JobId) {
                $ErrorMessage = "Secure Gateway '{0}': The onboarding request did not return a job identifier." -f $_GroupGatewayName
                $Exception = New-Object System.Exception($ErrorMessage)
                $ErrorRecord = New-Object System.Management.Automation.ErrorRecord($Exception, 'OnboardJobNotReturned', [System.Management.Automation.ErrorCategory]::InvalidResult, $_GroupGatewayName)
                $PSCmdlet.ThrowTerminatingError($ErrorRecord)
            }

            $_JobUri = "{0}/{1}" -f (Get-COMJobsUri), $_JobId

            # Async mode: return the job resource immediately without waiting
            if ($Async) {
                "[{0}] Onboarding job '{1}' submitted for Secure Gateway '{2}' in '{3}' region (async)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_JobId, $_GroupGatewayName, $_GroupRegion | Write-Verbose
                try {
                    $JobResource = Invoke-HPECOMWebRequest -Method Get -Uri $_JobUri -Region $_GroupRegion -WhatIfBoolean $false -Verbose:$VerbosePreference
                    $JobResource | Add-Member -type NoteProperty -name region -value $_GroupRegion -Force
                    [void]$ReturnData.Add($JobResource)
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
                continue
            }

            # Synchronous mode: wait for the onboarding job to complete
            "[{0}] Onboarding job '{1}' submitted for Secure Gateway '{2}' in '{3}' region, waiting for completion..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $_JobId, $_GroupGatewayName, $_GroupRegion | Write-Verbose

            try {
                $JobResult = Wait-HPECOMJobComplete -Region $_GroupRegion -Job $_JobUri -Timeout 1800 -Verbose:$VerbosePreference
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }

            $Global:HPECOMLastJobResult = $JobResult
            [void]$ReturnData.Add($JobResult)
        }

        if ($WhatIf) {
            return
        }

        if ($ReturnData.Count -gt 0) {
            $ReturnData = Invoke-RepackageObjectWithType -RawObject $ReturnData -ObjectName "COM.Jobs"
            Return $ReturnData
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
Export-ModuleMember -Function 'Get-HPECOMAppliance', 'Restart-HPECOMAppliance', 'Invoke-HPECOMApplianceRefreshSettings', 'Invoke-HPECOMSecureGatewayServerDiscovery', 'Get-HPECOMSecureGatewayServerDiscovery', 'Connect-HPECOMSecureGatewayDiscoveredServer', 'New-HPECOMAppliance', 'Remove-HPECOMAppliance', 'Get-HPECOMApplianceFirmwareBundle', 'Get-HPECOMOneViewServerProfileTemplate' -Alias *

# SIG # Begin signature block
# MIIqPwYJKoZIhvcNAQcCoIIqMDCCKiwCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCj82m5lNey2VuT
# JAd7+rrPybCGB1Ll4i+7RL9AxdasmqCCDIMwggYaMIIEAqADAgECAhBiHW0MUgGe
# O5B5FSCJIRwKMA0GCSqGSIb3DQEBDAUAMFYxCzAJBgNVBAYTAkdCMRgwFgYDVQQK
# Ew9TZWN0aWdvIExpbWl0ZWQxLTArBgNVBAMTJFNlY3RpZ28gUHVibGljIENvZGUg
# U2lnbmluZyBSb290IFI0NjAeFw0yMTAzMjIwMDAwMDBaFw0zNjAzMjEyMzU5NTla
# MFQxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxKzApBgNV
# BAMTIlNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBDQSBSMzYwggGiMA0GCSqG
# SIb3DQEBAQUAA4IBjwAwggGKAoIBgQCbK51T+jU/jmAGQ2rAz/V/9shTUxjIztNs
# fvxYB5UXeWUzCxEeAEZGbEN4QMgCsJLZUKhWThj/yPqy0iSZhXkZ6Pg2A2NVDgFi
# gOMYzB2OKhdqfWGVoYW3haT29PSTahYkwmMv0b/83nbeECbiMXhSOtbam+/36F09
# fy1tsB8je/RV0mIk8XL/tfCK6cPuYHE215wzrK0h1SWHTxPbPuYkRdkP05ZwmRmT
# nAO5/arnY83jeNzhP06ShdnRqtZlV59+8yv+KIhE5ILMqgOZYAENHNX9SJDm+qxp
# 4VqpB3MV/h53yl41aHU5pledi9lCBbH9JeIkNFICiVHNkRmq4TpxtwfvjsUedyz8
# rNyfQJy/aOs5b4s+ac7IH60B+Ja7TVM+EKv1WuTGwcLmoU3FpOFMbmPj8pz44MPZ
# 1f9+YEQIQty/NQd/2yGgW+ufflcZ/ZE9o1M7a5Jnqf2i2/uMSWymR8r2oQBMdlyh
# 2n5HirY4jKnFH/9gRvd+QOfdRrJZb1sCAwEAAaOCAWQwggFgMB8GA1UdIwQYMBaA
# FDLrkpr/NZZILyhAQnAgNpFcF4XmMB0GA1UdDgQWBBQPKssghyi47G9IritUpimq
# F6TNDDAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADATBgNVHSUE
# DDAKBggrBgEFBQcDAzAbBgNVHSAEFDASMAYGBFUdIAAwCAYGZ4EMAQQBMEsGA1Ud
# HwREMEIwQKA+oDyGOmh0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1Ymxp
# Y0NvZGVTaWduaW5nUm9vdFI0Ni5jcmwwewYIKwYBBQUHAQEEbzBtMEYGCCsGAQUF
# BzAChjpodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2ln
# bmluZ1Jvb3RSNDYucDdjMCMGCCsGAQUFBzABhhdodHRwOi8vb2NzcC5zZWN0aWdv
# LmNvbTANBgkqhkiG9w0BAQwFAAOCAgEABv+C4XdjNm57oRUgmxP/BP6YdURhw1aV
# cdGRP4Wh60BAscjW4HL9hcpkOTz5jUug2oeunbYAowbFC2AKK+cMcXIBD0ZdOaWT
# syNyBBsMLHqafvIhrCymlaS98+QpoBCyKppP0OcxYEdU0hpsaqBBIZOtBajjcw5+
# w/KeFvPYfLF/ldYpmlG+vd0xqlqd099iChnyIMvY5HexjO2AmtsbpVn0OhNcWbWD
# RF/3sBp6fWXhz7DcML4iTAWS+MVXeNLj1lJziVKEoroGs9Mlizg0bUMbOalOhOfC
# ipnx8CaLZeVme5yELg09Jlo8BMe80jO37PU8ejfkP9/uPak7VLwELKxAMcJszkye
# iaerlphwoKx1uHRzNyE6bxuSKcutisqmKL5OTunAvtONEoteSiabkPVSZ2z76mKn
# zAfZxCl/3dq3dUNw4rg3sTCggkHSRqTqlLMS7gjrhTqBmzu1L90Y1KWN/Y5JKdGv
# spbOrTfOXyXvmPL6E52z1NZJ6ctuMFBQZH3pwWvqURR8AgQdULUvrxjUYbHHj95E
# jza63zdrEcxWLDX6xWls/GDnVNueKjWUH3fTv1Y8Wdho698YADR7TNx8X8z2Bev6
# SivBBOHY+uqiirZtg0y9ShQoPzmCcn63Syatatvx157YK9hlcPmVoa1oDE5/L9Uo
# 2bC5a4CH2RwwggZhMIIEyaADAgECAhEAyDHh+zCQwUNyJV9S6gqqvTANBgkqhkiG
# 9w0BAQwFADBUMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVk
# MSswKQYDVQQDEyJTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2MB4X
# DTI1MDUyMDAwMDAwMFoXDTI4MDUxOTIzNTk1OVowdzELMAkGA1UEBhMCVVMxDjAM
# BgNVBAgMBVRleGFzMSswKQYDVQQKDCJIZXdsZXR0IFBhY2thcmQgRW50ZXJwcmlz
# ZSBDb21wYW55MSswKQYDVQQDDCJIZXdsZXR0IFBhY2thcmQgRW50ZXJwcmlzZSBD
# b21wYW55MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA37AD03qwcmuC
# QyxRB2VBM7SfUf0SmpQb8iaPvGmxw5uoDBY3gdC/3Xq/rfM3ndCn03hNdGyucpC7
# tD4zmel6yYqxyXDVr45Jd2cz9jFXoYTOMcuDV6I6CvU/EnbFxWhv0VCp+2Ipz4+u
# JGI6aVlMpFpLbgPjhp9ogd/89HEyi1FkSFoarnvxxaXm93S81k7FD/4EdtvumuGI
# 4V8p39GfbCiMuHku8BzSQ2g86gWFnOaVhY6h4XWvEmE8LPYkU/STrej28FlgkSt9
# f/Jg6+dvRKm92uN2Z760Eql9+DTWkGmGe4YrIyD25XDa07sS9tIpVWzLrGOyecaV
# pJwVVBqCadXDgkgTYKw/UlS+cEqsviT6wREGl4aX/GbeNO6Y4oDTTYkabW3peg1k
# u0v90oDqzoTaWEE5ly2UajvXIgzpFLLXqpR6GYkv/y3ZJV0chBqRtAObebH7XOBa
# 5a2kqMBw0gkIZBJHd8+PCPH/U7eJkeKXtGGj2uTudcGjZgOjVcFYdCRnufJdisrV
# 7bj0Hzghcv3QyRXL3rRjcNb4ccKNnSgF/8cmiTVpvFHTfUKsYdkbM6wsbjXRdJNA
# DjGOYRms7tKsii3/oXO+2S1Um7yomBZQ2+wVRCY6MrRX1onDKid5t5AyWFtRu0aQ
# cdBmHG6JeDiQ3Hrb2g9kZhuFkgABVBkCAwEAAaOCAYkwggGFMB8GA1UdIwQYMBaA
# FA8qyyCHKLjsb0iuK1SmKaoXpM0MMB0GA1UdDgQWBBQH4rUE0gsy8LW2G3vmoYtO
# nZ8zEjAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggr
# BgEFBQcDAzBKBgNVHSAEQzBBMDUGDCsGAQQBsjEBAgEDAjAlMCMGCCsGAQUFBwIB
# FhdodHRwczovL3NlY3RpZ28uY29tL0NQUzAIBgZngQwBBAEwSQYDVR0fBEIwQDA+
# oDygOoY4aHR0cDovL2NybC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljQ29kZVNp
# Z25pbmdDQVIzNi5jcmwweQYIKwYBBQUHAQEEbTBrMEQGCCsGAQUFBzAChjhodHRw
# Oi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmluZ0NBUjM2
# LmNydDAjBggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wDQYJKoZI
# hvcNAQEMBQADggGBAIax+Yaj5EciDlztft4iAfD2CtIWEF0cxR+UbbvJEs865wyo
# O3ZQoujr0FJ+P5fjDKLbamHrEWmyoD2YC4lzecmnFOnY0y4uJ9zBY8B6X6TU9e6+
# TfZtlXd44YffXYAfoLX+uYjVJcZOaMuXF61+CFpjLJjepsD8m1gdj5QUz2sH6GOf
# U6mEm8SHvKpgPMV/yhEKqgjlenY6Ao49RkxnDuvRlMP8SFPB+8bxiLegEdGaei8n
# Sr/j5YeDZFevUJ696T4W45QGrwAhBBpbKDz6CzlImC1b2C8Bp02XBAsOQs/uCIaQ
# v5XxUmVxmb85tDJkd7QfqHo2z1T2NYMkvXUcSClYRuVxxC/frpqcrxS9O9xEv65B
# oUztAJSXsTdfpUjWeNOnhq8lrwa2XAD3fbagNF6ElsBiNDSbwHCG/iY4kAyaVpbA
# Ytaa6TfzdI/I0EaCX5xYRW56ccI2AnbaEVKz9gVjzi8hBLALlRhrs1uMFtPjnZ+o
# A+rbZZyGZkz3xbUYKTGCHRIwgh0OAgEBMGkwVDELMAkGA1UEBhMCR0IxGDAWBgNV
# BAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMgQ29k
# ZSBTaWduaW5nIENBIFIzNgIRAMgx4fswkMFDciVfUuoKqr0wDQYJYIZIAWUDBAIB
# BQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIB
# BDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg
# WcvmUAb0Cm0D5VHoRoaAg4r92r0hr5njA+B7ENA4TqkwDQYJKoZIhvcNAQEBBQAE
# ggIAO52qBmerRY0NTIslAMP1a3BUfK7OreLV7CMRZwJxOi8tGEOd2h6xeVXuHVjM
# wsg65YPBbUS1ji5GiFm/74+yuX+/HgXXdjxbnxcC+8dfnSGm3Xk2w2crXdX6uo//
# WZAA5zkZYgXe8sF369X0WQA5A41SIFNqpJptu/WrHjwnqRsitCnCuY6kl8E26gir
# o03Urt3kHcGcLUF3WmkuQqNAH5xl5eveUEeyJbAWG/ttVb68XQRXH4YwDpn+IY72
# oYvnnmLIWAAscqCxmxZZnzPJEYFzuKlt6DcwxE+GciMtcEeJfVPFlH0d7zJ0+lpa
# lRshWhczj33/N4p1ilvbFvPwHHLkFoyOssWwf2IbQxfrZ/5J+CXqQh3WzSc0CPdS
# st3w9SLUxvo2aKwrZxyT5o3xSmobUSHX16x5koeixsv9GXi8J0N+b4c+QQWG3UHI
# 1XT5C6SJLmEym3REX+jZ5C0pg9KCcq2GK+7nvcQvyTccuKtBKE/EEobbJP9eSCGK
# 6phWlGxWRfmNpOXvTQnqKRKyXr4+ir36SnrcwopSRaKJ4yz9G2XZh04MzHm/waNF
# iaO1AYsgq1Z3HhslpTxq0oR4vYCkFHGbGoitSyiJ0N687wf6uCoiZ8jzkPplWMoB
# VpFUjCOa014JG8Qjwpoi+Dg4wRDhQ5Q88Y4w63aWCLy8wZihghn8MIIZ+AYKKwYB
# BAGCNwMDATGCGegwghnkBgkqhkiG9w0BBwKgghnVMIIZ0QIBAzEPMA0GCWCGSAFl
# AwQCAgUAMIIBBwYLKoZIhvcNAQkQAQSggfcEgfQwgfECAQEGCisGAQQBsjECAQEw
# QTANBglghkgBZQMEAgIFAAQwxRaaBqh2hE8Lid+V9QbOjojgW6W2O04YVwPPCuQm
# LmSTrONR9w0pgoV9BKdWXO27AhQJoE1gYWMRj8kPC/6yqmo75HTAwhgPMjAyNjEx
# MDQwODE5MzRaoHakdDByMQswCQYDVQQGEwJHQjEXMBUGA1UECBMOR3JlYXRlciBM
# b25kb24xGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEwMC4GA1UEAxMnU2VjdGln
# byBQdWJsaWMgVGltZSBTdGFtcGluZyBTaWduZXIgUjM3oIIUFzCCBuIwggTKoAMC
# AQICEQDnTvJVsFBP+tum3/f8i6MVMA0GCSqGSIb3DQEBDAUAMFUxCzAJBgNVBAYT
# AkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLDAqBgNVBAMTI1NlY3RpZ28g
# UHVibGljIFRpbWUgU3RhbXBpbmcgQ0EgUjQxMB4XDTI2MDMyNTAwMDAwMFoXDTM3
# MDYyNDIzNTk1OVowcjELMAkGA1UEBhMCR0IxFzAVBgNVBAgTDkdyZWF0ZXIgTG9u
# ZG9uMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxMDAuBgNVBAMTJ1NlY3RpZ28g
# UHVibGljIFRpbWUgU3RhbXBpbmcgU2lnbmVyIFIzNzCCAiIwDQYJKoZIhvcNAQEB
# BQADggIPADCCAgoCggIBALL/w21L3FDZRS0FEXfZuPtUrefibnRSqOT/NNyJLOJh
# XjQfUspqHT+gSSVgbjYThUI/cO+wFQHoOakKQNnSMKdkE8gR69ofXlkk5DAVY/Zl
# evliOUmlvrw2Vuz4SU28rHfb/Vgd17eqpRIvJuO6XE8vPpPzn4c4iorszUF6nwuy
# nKEQ/+rqfDmQbFNKsa+5+Z4f4kXwKdUFxUwUDjQWUhiHRwMlUWGF9N91aAvL+9a4
# sxCgqR/ez8W8HJ/XqvSu1vIeb+J6bDFKKgkv3PJkMMpQ0BsdeXR2FejZXFRXY1w9
# dZe6gqyMv7px+TpWbYMefECUV0WxoEMgXUk6RKcLo94uUHOdmfZu4Xe8ghglyro3
# /N4VEKTj8dcPPvOBGxFEx1QH6uHKTkWhloGPDScurcZnd8KUtTHl6zmlQDHM04Mw
# GfsmQViKnYEAYE8RHl5XRE6GTq0ZMb59SIyJX6+CODVic/kW+dhbIS1Z5AP8HaGn
# e/PRG+12QzSneKDJp3Ot+k4GrmmlWT9iy6FNCQ/32K+d4cAZ+Ll7uWbEn6Z6gE+t
# Eu7MyZvzWvPNsRKMkcyyflFW1zpRyzutwypALXc9Qg7sFsYERNXa58KZXqU9Onc/
# tck6+adQJFM9tW8xOnE//P5I4eDj84IGGKqzgUD37ihC+WST3DfY0YBKWL0Zaubn
# AgMBAAGjggGOMIIBijAfBgNVHSMEGDAWgBQ6dKUMZ8ZCUML9tfzHuyk0gvR6uTAd
# BgNVHQ4EFgQUYRDpehKvUcSF1PLPpHQPUM0gr/gwDgYDVR0PAQH/BAQDAgbAMAwG
# A1UdEwEB/wQCMAAwFgYDVR0lAQH/BAwwCgYIKwYBBQUHAwgwSgYDVR0gBEMwQTAI
# BgZngQwBBAIwNQYMKwYBBAGyMQECAQMIMCUwIwYIKwYBBQUHAgEWF2h0dHBzOi8v
# c2VjdGlnby5jb20vQ1BTMEoGA1UdHwRDMEEwP6A9oDuGOWh0dHA6Ly9jcmwuc2Vj
# dGlnby5jb20vU2VjdGlnb1B1YmxpY1RpbWVTdGFtcGluZ0NBUjQxLmNybDB6Bggr
# BgEFBQcBAQRuMGwwRQYIKwYBBQUHMAKGOWh0dHA6Ly9jcnQuc2VjdGlnby5jb20v
# U2VjdGlnb1B1YmxpY1RpbWVTdGFtcGluZ0NBUjQxLmNydDAjBggrBgEFBQcwAYYX
# aHR0cDovL29jc3Auc2VjdGlnby5jb20wDQYJKoZIhvcNAQEMBQADggIBAAPqPY3R
# rM36GXqTpsoHn9TpW5I6z3dkFvc9zPL1W0Egq7j3jtnkbAvRoWeAjGX4ZK4sWsmA
# +u4EJG8okQmybuS/4tDUI5UIQb21n4hG2vihxShrneWB0VoQ2VLQ3jCCRmRtAQ+/
# 7H7WVKNiH5Pgl4v2ZTOdPsStzpKnl1YuRrmww/+bcZmLqgk909ywIpZqAfubYfbE
# MYjIckLk90f2mG+L8qaGSS2JJVM02pV5XltZ1fbOFETpRN/PQhwygIv33qUUjJ1f
# E4ITgw0McMzRqziWdOJP8ocxxw7qXxz1OdRWCalyL1qvUgAFnZTVdSRiMYZKf0wL
# cQcM/1Xf1W4FW9nff8ERX8RZJGt/TtPuMWmUpf6BCv9Q6o8YyUTtknvZRpSQ0nLt
# tWXdtwsrN2mMgfMuR//gxVrVXvDzCoK/lbiA6dEZOW53lQwBFtEzwE/FH8Jdhegy
# Yg4PymZOTZrGBEvgsbxe25yEhJ0IdGa1pwCYsarldJhJVMdNcAOU7jyIMqHcczav
# 3wtIXp/SwbXZ3xX0mfsLfANSJ47G4qPgx1atb6GIlTaQXzu/p4fTQeAIUVzZXT4K
# 984IyfuO7NLjWMtog1wGUpZD98pv+4Mt9Y5bvfPUjaUVjtePy1DVdi0rl5ESNYi0
# zyOmXVxtA5zzxu1H7RdLZOZugT/XjX69rY9bMIIGpzCCBI+gAwIBAgIRAJCsCHIg
# /cWnxGtcxw33PQYwDQYJKoZIhvcNAQEMBQAwVzELMAkGA1UEBhMCR0IxGDAWBgNV
# BAoTD1NlY3RpZ28gTGltaXRlZDEuMCwGA1UEAxMlU2VjdGlnbyBQdWJsaWMgVGlt
# ZSBTdGFtcGluZyBSb290IFI0NjAeFw0yNjAzMjUwMDAwMDBaFw00MTAzMjQyMzU5
# NTlaMFUxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLDAq
# BgNVBAMTI1NlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgQ0EgUjQxMIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAruRKogGtghxi+WYtW5oDzPDVF8GG
# SfgbUKh6bONxi0wvrI1S8qbAYfvLr/ky5ILVRg//70pgNKq8xC3/WEQodjEwAP2h
# mkGShoNAUQps4kd6Wwp74Fo7RlwQ1Mp949ytpWQDvCsYBbZccDmBAJC/ggqiuL/c
# 805fGcMw6TzIgyBWuUx5PGp9YnheSNPXFzaz0MPtREdZYk4WhtM+hazqasMWVpj0
# WUAcNhN9vO/FAdWy9Gafdb7lmYLDKTTYjwqAY9P9RfixPPjUaJH6mnBSNBdrX7a0
# Qdlux0ApS0fc48RW1m+W3tq3HiHzch1FHyhiLzCNjc6MUpcV5xalBvPOw/FtQo/A
# xaJOvPCSsVrx0f/WkMpEm3fvVbrY9+oo9rIKv9ducE6VGfwIAtKYedG0bO4Ba1Mm
# lxPcErDqjLwggvrBJu73fwXpkhtE0hzV0psgm2vhQs3pHll9N00SHBdy2qndEcNu
# Dh+46XouM2hoXCO533YQQOHPEUnMTWOo3hyxx5kjDE5PVqp+x+HS4VAT+WBMG4Gz
# eLr9YvZbU5x5YvLdcR1dErV/QRYK55rp019fZFF2NR+TkSW0WcmQ3b5taGcrXg49
# EpzKM6/mEpnSJXg1E13X6GO29rWs/LNvkGzsS8XGoRCGBls6ruofeebSsHADR3Ge
# IE5gIU927bjokLECAwEAAaOCAW4wggFqMB8GA1UdIwQYMBaAFPZ3at0//QET/xah
# bIICL9AKPRQlMB0GA1UdDgQWBBQ6dKUMZ8ZCUML9tfzHuyk0gvR6uTAOBgNVHQ8B
# Af8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADATBgNVHSUEDDAKBggrBgEFBQcD
# CDAjBgNVHSAEHDAaMAgGBmeBDAEEAjAOBgwrBgEEAbIxAQIBAwgwTAYDVR0fBEUw
# QzBBoD+gPYY7aHR0cDovL2NybC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljVGlt
# ZVN0YW1waW5nUm9vdFI0Ni5jcmwwfAYIKwYBBQUHAQEEcDBuMEcGCCsGAQUFBzAC
# hjtodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBp
# bmdSb290UjQ2LnA3YzAjBggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5j
# b20wDQYJKoZIhvcNAQEMBQADggIBADLeUkdm8Z4DZvjfKHOhqu+hsdXNt+X5F+48
# PB6PTAJCRgA3qxxO3YbAV7baps4K/+2WWoWUspBkT4T2NXK49NvJAfCsztHSgtqk
# AQMLX4KjCypJF/+m2Ktrk993g+gcgKdv1yg9C3JmYdJCnnL0ga+pZ/Wo1+rtXZ8d
# nwO8RCstTN6gYX0ElFi7Y7NpxbdBC1S6bc05V/SA9HC/ojj33W6GdwnpU/iVylSk
# dkoHtHeGIhQLT2ZH0qPM9Wdce8v2fZsDCJQQJ8rll7OGLDbsXa2CLf0MRN9Twzif
# Q3rEuAXOx/TkzkZRFfwL34hf1XqSmaYq2tTMy2LgsPrqC2Z/6ZKb3fgrzU0vphB4
# wSTWulitY/KlxbvoyKvrBvUCCx4sgeqf8aR65CbvM5MN/d/lahfXipU2NlY0cXcn
# GS61XpmeGKd8It92/lufApZR9x6o5qMJWe0jq4JsfGMGDpIKx7FzkB8gaejuBUW/
# CJ9Phc40+xJRonvVewn4S9yJVRWeM47irGbR9YlN3xruM/yZzhk+rAm9AW06nv7o
# b6RQkAXR+cTxiAPy620FF41NrViYB4UyKpzfx7x8jh4ubTOMz954YIdqyeiqqtsb
# BwXjWLP0dfMUPA3iIPnPdBKGnodGJTdSlPAMmKJdyvTPqmOXs/LMnf+2Za0Z6FXs
# IB9z9aXLMIIGgjCCBGqgAwIBAgIQNsKwvXwbOuejs902y8l1aDANBgkqhkiG9w0B
# AQwFADCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDASBgNV
# BAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdvcmsx
# LjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3JpdHkw
# HhcNMjEwMzIyMDAwMDAwWhcNMzgwMTE4MjM1OTU5WjBXMQswCQYDVQQGEwJHQjEY
# MBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVTZWN0aWdvIFB1Ymxp
# YyBUaW1lIFN0YW1waW5nIFJvb3QgUjQ2MIICIjANBgkqhkiG9w0BAQEFAAOCAg8A
# MIICCgKCAgEAiJ3YuUVnnR3d6LkmgZpUVMB8SQWbzFoVD9mUEES0QUCBdxSZqdTk
# dizICFNeINCSJS+lV1ipnW5ihkQyC0cRLWXUJzodqpnMRs46npiJPHrfLBOifjfh
# pdXJ2aHHsPHggGsCi7uE0awqKggE/LkYw3sqaBia67h/3awoqNvGqiFRJ+OTWYmU
# CO2GAXsePHi+/JUNAax3kpqstbl3vcTdOGhtKShvZIvjwulRH87rbukNyHGWX5tN
# K/WABKf+Gnoi4cmisS7oSimgHUI0Wn/4elNd40BFdSZ1EwpuddZ+Wr7+Dfo0lcHf
# lm/FDDrOJ3rWqauUP8hsokDoI7D/yUVI9DAE/WK3Jl3C4LKwIpn1mNzMyptRwsXK
# rop06m7NUNHdlTDEMovXAIDGAvYynPt5lutv8lZeI5w3MOlCybAZDpK3Dy1MKo+6
# aEtE9vtiTMzz/o2dYfdP0KWZwZIXbYsTIlg1YIetCpi5s14qiXOpRsKqFKqav9R1
# R5vj3NgevsAsvxsAnI8Oa5s2oy25qhsoBIGo/zi6GpxFj+mOdh35Xn91y72J4RGO
# JEoqzEIbW3q0b2iPuWLA911cRxgY5SJYubvjay3nSMbBPPFsyl6mY4/WYucmyS9l
# o3l7jk27MAe145GWxK4O3m3gEFEIkv7kRmefDR7Oe2T1HxAnICQvr9sCAwEAAaOC
# ARYwggESMB8GA1UdIwQYMBaAFFN5v1qqK0rPVIDh2JvAnfKyA2bLMB0GA1UdDgQW
# BBT2d2rdP/0BE/8WoWyCAi/QCj0UJTAOBgNVHQ8BAf8EBAMCAYYwDwYDVR0TAQH/
# BAUwAwEB/zATBgNVHSUEDDAKBggrBgEFBQcDCDARBgNVHSAECjAIMAYGBFUdIAAw
# UAYDVR0fBEkwRzBFoEOgQYY/aHR0cDovL2NybC51c2VydHJ1c3QuY29tL1VTRVJU
# cnVzdFJTQUNlcnRpZmljYXRpb25BdXRob3JpdHkuY3JsMDUGCCsGAQUFBwEBBCkw
# JzAlBggrBgEFBQcwAYYZaHR0cDovL29jc3AudXNlcnRydXN0LmNvbTANBgkqhkiG
# 9w0BAQwFAAOCAgEADr5lQe1oRLjlocXUEYfktzsljOt+2sgXke3Y8UPEooU5y39r
# AARaAdAxUeiX1ktLJ3+lgxtoLQhn5cFb3GF2SSZRX8ptQ6IvuD3wz/LNHKpQ5nX8
# hjsDLRhsyeIiJsms9yAWnvdYOdEMq1W61KE9JlBkB20XBee6JaXx4UBErc+YuoSb
# 1SxVf7nkNtUjPfcxuFtrQdRMRi/fInV/AobE8Gw/8yBMQKKaHt5eia8ybT8Y/Ffa
# 6HAJyz9gvEOcF1VWXG8OMeM7Vy7Bs6mSIkYeYtddU1ux1dQLbEGur18ut97wgGwD
# iGinCwKPyFO7ApcmVJOtlw9FVJxw/mL1TbyBns4zOgkaXFnnfzg4qbSvnrwyj1Ni
# urMp4pmAWjR+Pb/SIduPnmFzbSN/G8reZCL4fvGlvPFk4Uab/JVCSmj59+/mB2Gn
# 6G/UYOy8k60mKcmaAZsEVkhOFuoj4we8CYyaR9vd9PGZKSinaZIkvVjbH/3nlLb0
# a7SBIkiRzfPfS9T+JesylbHa1LtRV9U/7m0q7Ma2CQ/t392ioOssXW7oKLdOmMBl
# 14suVFBmbzrt5V5cQPnwtd3UOTpS9oCG+ZZheiIvPgkDmA8FzPsnfXW5qHELB43E
# T7HHFHeRPRYrMBKjkb8/IN7Po0d0hQoF4TeMM+zYAJzoKQnVKOLg8pZVPT8xggST
# MIIEjwIBATBqMFUxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0
# ZWQxLDAqBgNVBAMTI1NlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgQ0EgUjQx
# AhEA507yVbBQT/rbpt/3/IujFTANBglghkgBZQMEAgIFAKCCAfowGgYJKoZIhvcN
# AQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNjExMDQwODE5MzRa
# MD8GCSqGSIb3DQEJBDEyBDAgiF514ftkr1PN2Oy2ubpunVdmf9UFvdG6WWy6+xKj
# JKag7KDhnMunlLSzur2adK4wggF7BgsqhkiG9w0BCRACDDGCAWowggFmMIIBYjAW
# BBTpeBipKNoVCp/hv5zMequ5oA7urDCBiAQUZcMoaW99TlAs/QPHwgaXGMr7908w
# cDBbpFkwVzELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEu
# MCwGA1UEAxMlU2VjdGlnbyBQdWJsaWMgVGltZSBTdGFtcGluZyBSb290IFI0NgIR
# AJCsCHIg/cWnxGtcxw33PQYwgbwEFIU9Yy2TgoJhfNCQNcSR3pLBQtrHMIGjMIGO
# pIGLMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKTmV3IEplcnNleTEUMBIGA1UE
# BxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBVU0VSVFJVU1QgTmV0d29yazEu
# MCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eQIQ
# NsKwvXwbOuejs902y8l1aDANBgkqhkiG9w0BAQEFAASCAgCvtWJ07T13HtU4GqbM
# tmeeh+wKjGXfmd50kibKQJiiGo0WFzdFlLRkIgBq82K2uROorYSkOHthKAR43JUV
# nGB/FSLWCdAHqMzdfs6oLS9f0cmTWMp0bwxtGjf4NbrvIew/xYp0eznpWaWJD0f9
# qCvLpembEukAe/fsxdgBLhLHtnueKv6nalXRU1ohqRVWXZ3iHLuqMDvOwXGc7ekW
# UrmXp/EKo5hhI9wAjAh5Lxy40PysiAA8YVY1XJH0DNG7EZOlIi/10DrcKEqA4XF2
# 6Tsmz0XmtD99itoZIBPAioCN3bHF9WDt/Y84wGKcPvxAdZkK1jwcz+80SddEcWjH
# 4Ja+DjQdnWliks0ZIQ23D4rPs81e0ski3LmkLy4xlegzCkH1BkY/RdiIkWoORYLr
# vLegWnbFcg3a7MM/G5pLlSPI4ahqZjnZbuPZGwUu26tf8wzflG1f1mojS3G4g5IW
# G+LsYJqLsf+aEUMGNd68Q5MD60zyM21A43G7M2/lW8BpO2nuybYFr5YcZEB31mUs
# gtU2X9oDhEHt/udMw9UN0wn48LfloU6GJdYp3Ucto0H2ZDBIoau2X6S1culXNUDm
# 6/DpON74TmWmnZLtfyMqvr3VBYcg7tIKQ7DDC3H80tLEXMM2r2Ppiu85Um1E+VNN
# Q2EY/96CJIbRx4aIypIXFyEQbQ==
# SIG # End signature block
