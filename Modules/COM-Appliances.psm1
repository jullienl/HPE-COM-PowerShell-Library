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
    The discovery runs an nmap network scan from the Secure Gateway across its local subnet to detect HPE iLO devices
    that are reachable through the gateway but not yet connected to Compute Ops Management.

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
    Get-HPECOMAppliance -Region eu-central -Type SecureGateway -Name "sg01.lj.lab" | Invoke-HPECOMSecureGatewayServerDiscovery -Force

    Retrieves the Secure Gateway 'sg01.lj.lab' and runs the server discovery without prompting for confirmation.

    .EXAMPLE
    $iLO_credential = Get-Credential

    Invoke-HPECOMSecureGatewayServerDiscovery -Region eu-central -SecureGateway "sg01.lj.lab" -Force |
        Where-Object iLOUpdateRequired -eq 'No' |
        Connect-HPEGLDeviceComputeiLOtoCOM -IloCredential $iLO_credential

    Discovers servers behind the Secure Gateway 'sg01.lj.lab', filters out any iLO that requires a firmware update first, and onboards the remaining iLOs to Compute Ops Management through the Secure Gateway.

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

        # Warn about the nmap network scan and prompt for confirmation (unless -Force or -WhatIf)
        if (-not $Force -and -not $WhatIf) {

            Write-Warning ("Server discovery on Secure Gateway '{0}' runs an active nmap network scan across the appliance's local subnet to detect HPE iLO devices. This scan may trigger intrusion detection/prevention systems (IDS/IPS) or security monitoring alerts, and may be subject to your organization's network scanning authorization policy. Depending on the size of the subnet, the scan can take a long time to complete (from several minutes to much longer for large subnets). Ensure you are authorized to scan this network before proceeding." -f $SecureGatewayName)

            $question = "Do you want to start the nmap-based server discovery on Secure Gateway '$SecureGatewayName' in the '$Region' region?"
            $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Start the server discovery (runs an nmap scan from the Secure Gateway)."
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

            $_Body = @{
                jobTemplateUri = "/api/compute/v1/job-templates/" + $JobTemplateId
                resourceUri    = $_ApplianceResourceUri
                data           = @{
                    discoveryMode = "nmapScan"
                }
            }

            $Operation = @{
                type   = "REST"
                method = "POST"
                uri    = "/api/compute/v1/jobs"
                body   = $_Body
            }

            $randomNumber = Get-Random -Minimum 000000 -Maximum 999999
            $ScheduleName = "$($SecureGatewayName)_SecureGatewayServerDiscovery_Schedule_$($randomNumber)"
            $Description  = "Scheduled task to run nmap-based server discovery on Secure Gateway '$($SecureGatewayName)'"

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

            $payload = @{
                jobTemplate  = $JobTemplateId
                resourceId   = $_ApplianceDeviceId
                resourceType = "compute-ops-mgmt/appliance"
                jobParams    = @{
                    discoveryMode = "nmapScan"
                }
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

        # Retrieve the list of discovered servers
        $DiscoveredServersUri = "{0}?hide=false&externalManager=None&onboarding=false&applianceID={1}&method=nmapScan" -f (Get-COMDiscoveredServersUri), $_ApplianceId

        try {
            [Array]$DiscoveredServers = Invoke-HPECOMWebRequest -Method Get -Uri $DiscoveredServersUri -Region $Region -WhatIfBoolean $false -Verbose:$VerbosePreference
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
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
# MIItTgYJKoZIhvcNAQcCoIItPzCCLTsCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDjCV1cMS5V3Anj
# jlD5iyoSxOgnYKNJBgbIa1gj9lFqP6CCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQguFYdMeCKtNclwnjhzWvKAblcwWGHtnWBAXYzXmqnR2UwDQYJKoZIhvcNAQEB
# BQAEggIABfsiVl/Xh/X+g6M2zZpn4xGnHJKBi0FWzZZkcQUMXGgVvs2ErK33gygA
# YL/seTsbjl8VNPBbq3luuc5qK/iDyIIOI6sIwvtAl484eipVw7YAecT/XayTBRZM
# 74p6GUrjHR3kymu88S6kzcTSJ2vd2Et5H6VSB1w8170EkzOknBjxDGIeRGegtekC
# ViyzDAM7/RH8v3xeYDf+uc0j8jnpo2eVi4N+JezGk/Y4hKuE4jbdIUfzbeIzCwRK
# M0EmeQ9s3z2VZd9DBoxd3mS4yoxGCexXkXxJv6mG7WBDEfYkdda9INa1v+xgUeru
# R83SSvhiA8v+W1vpEuiHDNNx1NUKlUB3PE2aLe3uTg6GXE4fYEgDs2LZ1OOOlotW
# EGRvSEXd+msyM7O1e2uuij5nVkdSBVnQHQ+ndfFSXkvAXfRONYpIYrLhG+GaKbDs
# MwWAah+nyZ+sl0Fjvjbcwnw3K4ifnqQMAyVj0zN3yduaL92aMXuiOnWkgWS483B6
# 7c2P771xcDDCmtYLYGRBIK6hdpCzGXMGLrNmuVyhe2XrO/FI7gv+AgWWxh3qqNIi
# t58Pe/FG/JPodiySTEiyIluPw41XKHwDY4UkX7/N1iv2PUpdjEAYbpkoVPu2+8a8
# bgEyfQsz7Oi6jKkKMsBdLlT+mBbAdzOs5rsGiCIfYPM+yHAK0CihgheYMIIXlAYK
# KwYBBAGCNwMDATGCF4QwgheABgkqhkiG9w0BBwKgghdxMIIXbQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIGIBgsqhkiG9w0BCRABBKB5BHcwdQIBAQYJYIZIAYb9bAcBMEEw
# DQYJYIZIAWUDBAICBQAEMB1FT+XJn/zzAG4n80FhV1B96fgwZIj9h+GL2u/901cc
# 6jxAM5ZHb4wZ6JG7EoXWiQIRAJUDkKuLwEjJMODbk23I7pgYDzIwMjYwNjI2MTM0
# MjU2WqCCEzowggbtMIIE1aADAgECAhAMIENJ+dD3WfuYLeQIG4h7MA0GCSqGSIb3
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
# BgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI2MDYy
# NjEzNDI1NlowKwYLKoZIhvcNAQkQAgwxHDAaMBgwFgQUcrz9oBB/STSwBxxhD+bX
# llAAmHcwNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgMvPjsb2i17JtTx0bjN29j4uE
# dqF4ntYSzTyqep7/NcIwPwYJKoZIhvcNAQkEMTIEMFKQJwIM8IedBZI9/aaw4oRI
# m6ppfZzhThJ2c4I5XVv3Yh/RGKZX6y+Vlg7Q9tV0/zANBgkqhkiG9w0BAQEFAASC
# AgAu5izleE1NxnIGrSGfhlCs1ejcAhKgj1Cf47kzJX9uY+bMmk/vy+nhTQVS2vpc
# hxAPmLRfdisOVL8eDS56WC8mH8eOp9IapuiCwjd6X0PPr6NlryUG/zHGNb4KZNsI
# tB14wpKMdMLxfj5NPz78fFnvNcJ9r7hGlaGTyGUzpewHcIs59D3H1DrtaJCA17Zl
# KyLaP48CgWX3KVeH0OZrhm7SnVUmZIBpGNHgcLo4jqkZtvwO+8aSMIsHrBLRijVr
# C5/lHOkPS5IGxvHiqIlyZWOA/FbCdDjuqBhykfsCRppdqNG/ENCHI5eYzHNTX2DL
# k/b2I8yCYqaXA3Neyu09xFF3mDNjRNt8ydlGqld0Yt7zMHxjoXDU23DQnWTiy/qE
# Xk3uoilymyTaXX5gQXziLQOzM4zB7Y57rzkx7bxgqfLXEN5iKubSXbLpa/pdf9Vg
# oKJ5+40TGgskPoPuJr4dBhyjkyicEfMbPnUYI95MrgXg72nkdWnU2rU17+4UuZbx
# VpjZBv5nfwqvWG2dob6TY5fwUraqz95CQQHBFBAjqqw9ihCQ5zYi6NhbQosMKHJR
# V8QS1NQmh3ZbS0qwFv+Y636nDNvAqrf/msH1wif/npM9BxkWcxv0lTNXufvaKsgs
# DSEPWeFFgNlWrhDjY23Pa4PZdY5gG6Q6roYaFl9VMhSjag==
# SIG # End signature block
