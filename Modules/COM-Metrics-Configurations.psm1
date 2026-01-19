#------------------- FUNCTIONS FOR COMPUTE OPS MANAGEMENT METRICS CONFIGURATION -----------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1

# Public functions
Function Get-HPECOMMetricsConfiguration {
    <#
    .SYNOPSIS
    Retrieve the metrics data collection configuration.

    .DESCRIPTION
    This Cmdlet returns the metrics data collection and utilization alerts that are configured in the specified region. 
    Metrics data collection allows Compute Ops Management to collect metrics data for sustainability AI insights, utilization reporting, and utilization alerting.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMMetricsConfiguration -Region us-west 

    Return metrics data collection configuration located in the western US region. 

    .INPUTS
    No pipeline support

    
   #>
    [CmdletBinding()]
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

        [Switch]$WhatIf
       
    ) 

    Begin {
  
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
      
      
    }
      
      
    Process {
      
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose      
        
        $Uri = Get-COMMetricsConfigurationsUri
            
        try {
            [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
    
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
                   
        }           
        

        $ReturnData = @()
       
        if ($Null -ne $CollectionList) {     

            # Add region to object
            $CollectionList | Add-Member -type NoteProperty -name region -value $Region            
             
            $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Metrics.Configuration" 
            
            return $ReturnData 
                
        }
        else {

            return
                
        }     

    
    }
}

Function Enable-HPECOMMetricsConfiguration {
    <#
    .SYNOPSIS
    Enable metrics data collection and utilization alerting in a region.

    .DESCRIPTION
    This cmdlet enables metrics data collection and utilization alerting settings for Compute Ops Management for all servers or specified server groups.
    Use this cmdlet to enable metrics collection and optionally configure utilization alerting with threshold and target server groups.

    Metrics data allows compute Ops Management to collect metrics data for sustainability AI insights, utilization reporting.
    Utilization alerting provides notifications when the sustainability metrics for the current month are greater than the previous month by a higher amount than the configured threshold change percentage.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER EnableUtilizationAlerting
    Enables utilization alerting in addition to metrics collection.

    .PARAMETER UtilizationAlertThresholdPercent
    Sets the threshold percentage for utilization alerts (1-100). Default is 80.
    Only applicable when EnableUtilizationAlerting is specified.

    .PARAMETER TargetServerGroups
    Specifies one or more server group names to target for utilization alerting.
    Only applicable when EnableUtilizationAlerting is specified.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request.

    .EXAMPLE
    Enable-HPECOMMetricsConfiguration -Region eu-central

    Enables metrics collection only in the eu-central region.

    .EXAMPLE
    Enable-HPECOMMetricsConfiguration -Region eu-central -EnableUtilizationAlerting -UtilizationAlertThresholdPercent 25 -TargetServerGroups "ESXi_group", "RHEL_group"

    Enables both metrics collection and utilization alerting with a 25% threshold for specified server groups.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -Name ESXi_group | Enable-HPECOMMetricsConfiguration -EnableUtilizationAlerting -UtilizationAlertThresholdPercent 23 

    Enables metrics collection and utilization alerting with a 23% threshold for the server group named "ESXi_group" in the eu-central region.

    .INPUTS
    System.String
        A server group name to target for utilization alerting.
    System.String[]
        A list of server group names to target for utilization alerting.
    System.Collections.ArrayList
        A list of server groups from 'Get-HPECOMServerGroup'.

    .OUTPUTS
    PSCustomObject
        A status object containing the configuration result.
    #>

    [CmdletBinding(DefaultParameterSetName = 'MetricsOnly')]
    Param( 
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateScript({
            if ($_ -in $Global:HPECOMRegions.region) {
                $true
            } else {
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
               
        [Parameter(Mandatory, ParameterSetName = 'MetricsAndAlerting')]
        [Switch]$EnableUtilizationAlerting,

        [Parameter(ParameterSetName = 'MetricsAndAlerting')]
        [ValidateRange(1, 100)]
        [Int]$UtilizationAlertThresholdPercent = 10,

        [Parameter(ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'MetricsAndAlerting')]
        [Object]$TargetServerGroups, 

        [Switch]$WhatIf
    ) 

    Begin {
        $Caller = (Get-PSCallStack)[1].Command
        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
        
        $TargetServerGroupsObject = [System.Collections.ArrayList]::new()        
    }
    
    Process {
        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | Out-String) | Write-Verbose

        if ($TargetServerGroups) {
            if ($TargetServerGroups -is [String]) {
                [void]$TargetServerGroupsObject.Add([PSCustomObject]@{ name = $TargetServerGroups })
            } elseif ($TargetServerGroups -is [PSCustomObject] -and $TargetServerGroups.name) {
                [void]$TargetServerGroupsObject.Add($TargetServerGroups)
            } elseif ($TargetServerGroups -is [Array]) {
                foreach ($group in $TargetServerGroups) {
                    if ($group -is [String]) {
                        [void]$TargetServerGroupsObject.Add([PSCustomObject]@{ name = $group })
                    } elseif ($group -is [PSCustomObject] -and $group.name) {
                        [void]$TargetServerGroupsObject.Add($group)
                    } else {
                        Write-Warning "Invalid pipeline input: $group"
                    }
                }
            } else {
                Write-Warning "Invalid pipeline input: $TargetServerGroups"
            }
        }

        "[{0}] Target server groups: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($TargetServerGroupsObject | Out-String) | Write-Verbose
    }
    
    End {
        $objStatus = [PSCustomObject]@{
            Name      = $MyInvocation.MyCommand.Name
            Region    = $Region                            
            Status    = $null
            Details   = $null
            Exception = $null
        }

        try {
            $CurrentMetricConfiguration = Get-HPECOMMetricsConfiguration -Region $Region 
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
         
        if (-not $CurrentMetricConfiguration) {
            if ($WhatIf) {
                $ErrorMessage = "Unable to retrieve metrics configuration for region '$Region'. Please check your configuration and try again."
                Write-Warning $ErrorMessage
                return
            } else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "Metrics configuration cannot be found in the region!"
                return $objStatus
            }  
        }

        $Uri = (Get-COMMetricsConfigurationsUri) + "/" + $CurrentMetricConfiguration.id
        $TargetServerGroupsList = @()

        if ($EnableUtilizationAlerting -and $TargetServerGroupsObject.Count -gt 0) {
            try {
                $ExistingServerGroups = Get-HPECOMGroup -Region $Region -ErrorAction Stop
                $ExistingGroupNames = $ExistingServerGroups | Select-Object -ExpandProperty name

                foreach ($group in $TargetServerGroupsObject) {
                    if ($group -is [String]) {
                        $group = [PSCustomObject]@{ name = $group }
                    }
                    
                    if ($ExistingGroupNames -contains $group.name) {
                        $TargetServerGroupsList += $group.name
                        "[{0}] Validated target server group: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $group.name | Write-Verbose
                    } else {
                        if ($WhatIf) {
                            Write-Warning "The server group '$($group.name)' does not exist in the '$Region' region. Please specify a valid server group name."
                            return
                        } else {
                            $objStatus.Status = "Failed"
                            $objStatus.Details = "The server group '$($group.name)' does not exist in the '$Region' region. Please specify a valid server group name."
                            return $objStatus
                        }
                    }
                }
            } catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }

            if (-not $TargetServerGroupsList) {
                if ($WhatIf) {
                    Write-Warning "No valid server groups specified. Please specify valid server group names available in the '$Region' region."
                    return
                } else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "No valid server groups specified. Please specify valid server group names available in the '$Region' region."
                    return $objStatus
                }
            }

            $alertResources = foreach ($groupName in $TargetServerGroupsList) {
                $group = $ExistingServerGroups | Where-Object { $_.name -eq $groupName }
                "[{0}] Adding server group to alert resources: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $groupName | Write-Verbose
                [PSCustomObject]@{
                    id = $group.id
                    name = $group.name
                    type = "group"
                }
            }
        } else {
            $alertResources = @()
        }

        $payload = if ($EnableUtilizationAlerting) {
            ConvertTo-Json -Depth 10 @{
                metricsCollection = "SYSTEM_SCHEDULED"
                powerThresholdAlerts = $true
                powerUtilizationThresholdPercentage = $UtilizationAlertThresholdPercent
                alertResources = $alertResources
            }
        } else {
            ConvertTo-Json -Depth 10 @{
                metricsCollection = "SYSTEM_SCHEDULED"
                powerThresholdAlerts = $false
            }
        }


        try {
            $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -Method PATCH -Body $payload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

            if (-not $WhatIf ) {
                if ($EnableUtilizationAlerting){
                    $objStatus.Details = "COM metrics configuration and utilization alerting successfully enabled in '$Region' region"
                }
                else {
                    $objStatus.Details = "COM metrics configuration successfully enabled in '$Region' region"
                }
                $objStatus.Status = "Complete"
            
            }
            
        } catch {
            if ($WhatIf) {
                if ($EnableUtilizationAlerting){
                    $objStatus.Details = "Failed to enable COM metrics configuration and utilization alerting in '$Region' region"
                }
                else {
                    $objStatus.Details = "Failed to enable COM metrics configuration in '$Region' region"
                }
                $objStatus.Status = "Failed"
                $objStatus.Exception = $Global:HPECOMInvokeReturnData
            }
        }
        
        if (-not $WhatIf ) {
            if ($objStatus.Status -eq "Failed" ) {
                if ($EnableUtilizationAlerting){
                    Write-Error "Failed to enable COM metrics configuration and utilization alerting in '$Region' region!"
                }
                else {
                    Write-Error "Failed to enable COM metrics configuration in '$Region' region!"
                }
            }
            $EnableMetricsConfigurationStatus = Invoke-RepackageObjectWithType -RawObject $objStatus -ObjectName "COM.objStatus.SDE"
            return $EnableMetricsConfigurationStatus
        }
    }
}

Function Disable-HPECOMMetricsConfiguration {
    <#
    .SYNOPSIS
    Disable metrics data collection and utilization alerting in a region.

    .DESCRIPTION
    This cmdlet disables metrics data collection and/or utilization alerting settings for COM in the specified region.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).

    .PARAMETER UtilizationAlertsOnly 
    Disables only utilization alerting while keeping metrics collection enabled.
    This parameter is used when you want to stop receiving utilization alerts but still want to collect metrics data.
    If this parameter is not specified, both metrics collection and utilization alerting will be disabled.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request.

    .EXAMPLE
    Disable-HPECOMMetricsConfiguration -Region eu-central

    Disables all metrics collection and utilization alerting for all servers.

    .EXAMPLE
    Disable-HPECOMMetricsConfiguration -Region eu-central -UtilizationAlertsOnly 

    Disables only utilization alerting while keeping metrics collection enabled.

    .INPUTS
    None. You cannot pipe objects to this cmdlet.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object containing the configuration result.
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
                $Global:HPECOMRegions.region | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [String]$Region,   
       
        [Switch]$UtilizationAlertsOnly,

        [Switch]$WhatIf
    ) 

    Begin {
        $Caller = (Get-PSCallStack)[1].Command
        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

    }
    
    Process {
        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        try {
            $CurrentMetricConfiguration = Get-HPECOMMetricsConfiguration -Region $Region 
        } catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
        
        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Region    = $Region                            
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

        if (-not $CurrentMetricConfiguration) {

            # Must return a message if not found
            if ($WhatIf) {

                $ErrorMessage = "Unable to retrieve metrics configuration for region '$Region'. Please check your configuration and try again."
                Write-Warning $ErrorMessage
                return
            }
            else {

                $objStatus.Status = "Failed"
                $objStatus.Details = "Metric configuration cannot be found in the region!"
                return $objStatus
            }

        }
        else {
        
            $Uri = (Get-COMMetricsConfigurationsUri) + "/" + $CurrentMetricConfiguration.id

            if ($UtilizationAlertsOnly ){

                # Build payload
                $payload = ConvertTo-Json -Depth 10 @{
                    powerThresholdAlerts = $false
                } 
            }
            else {
                # Build payload
                $payload = ConvertTo-Json -Depth 10 @{
                    metricsCollection = "ON_DEMAND"
                }   
            }
            
             # Set resource
            try {
                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method PATCH -body $payload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                
                if (-not $WhatIf) {

                    if ($UtilizationAlertsOnly) {
                        "[{0}] COM utilization alerting successfully disabled in '{1}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose
                        $objStatus.Status = "Complete"
                        $objStatus.Details = "COM utilization alerting successfully disabled in $Region region"
                    }
                    else {
                        "[{0}] COM metrics configuration successfully disabled in '{1}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose
                        $objStatus.Status = "Complete"
                        $objStatus.Details = "COM metrics configuration successfully disabled in $Region region"
                    }
                }

            }
            catch {

                if (-not $WhatIf) {
                    if ($UtilizationAlertsOnly) {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Failed to disable COM utilization alerting configuration"
                        $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                    }
                    else {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Failed to disable COM metrics configuration"
                        $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                    }
                }
            } 
        }  

        if (-not $WhatIf ) {
            if ($objStatus.Status -eq "Failed" ) {
                if ($UtilizationAlertsOnly) {
                    Write-Error "Failed to disable COM utilization alerting configuration!"
                }
                else {
                    Write-Error "Failed to disable COM metrics configuration!"
                }
                return
            }

            $DisableMetricsConfigurationStatus = Invoke-RepackageObjectWithType -RawObject $objStatus -ObjectName "COM.objStatus.SDE"    
            return $DisableMetricsConfigurationStatus
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
Export-ModuleMember -Function 'Get-HPECOMMetricsConfiguration', 'Enable-HPECOMMetricsConfiguration', 'Disable-HPECOMMetricsConfiguration' -Alias *




# SIG # Begin signature block
# MIIunwYJKoZIhvcNAQcCoIIukDCCLowCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA1DiwsBrIaPzIi
# +o5lDMNanr7ZDKtBV206MX8LrtilcKCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQga4FxM7ihZ9gcOectpn8hmjxvdjiZ43Qx3+N2X498n7IwDQYJKoZIhvcNAQEB
# BQAEggIAX1/2VfDr5km8buUEEd7g9HmMInYR8YIQUDNkJtjd2k1CjCPu703zrjXY
# 5hb3dblUZr6B2eHkdlhce8vvsehrFXik8iN5SYFP428N0QcLy+qmkcr/JB3pNvL3
# 05ZuBCRnNyp3TJ7Os+wndjpS9jZg0olYdU5pLNULL331WZhXKL1sZ7yqbSTh45Pt
# 05e1KdhfGwrOFlZKCCgpvKDWeQg9Qag/qrgyBqoAeWHzIdRwU+qvLECRs1Zk3AA2
# O+WY3RCPRu2Dg5NTjEBxmxcuDdgCy4I2Ltk2xeyqr1FjtmM4u9SnC4Lu7YVr421M
# DnWPPheO1AE8M9SQcTJrdfgyAli+noola8xP09HtADhygo60GdLXNKuyFRc6vqJ7
# nK7qwatIFI1I/f9P20ttdjk35I3rlWv6qnOBB1TT1SwfbF1cfi8YeTJAttotn0aB
# TgWm6hzZtmWgtCpDbpBUSN8d3vt8gx8qpHcA2zNYad8SHYJcivX4TYMCCX6zqLrX
# ISh+Vocyc2Y0clr1sN3j92rVsDxMh+iZkkjQYJ7ZV+K4LkWYSxcUdDxrDNq+Afpk
# ML4R6v/K8632fM158t+uee3h+feVRWh3ZfLNdVHxWEVT4W4Nm78VqkCpdHF4HANc
# QOnYTiP26VGY2/qLUzNKwuEd7Q/vTwxVSe8KA3f0Xkba8hhESR6hghjpMIIY5QYK
# KwYBBAGCNwMDATGCGNUwghjRBgkqhkiG9w0BBwKgghjCMIIYvgIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBCAYLKoZIhvcNAQkQAQSggfgEgfUwgfICAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQwrifCkbxK0q+kuf/czXb8SG6Hbr28cC0kE3DP
# 1rB4bk6AJ/l8/nGPAZpphBVjTY0LAhUAwn4tFDmibVq6jqpzBmEzj83HM7EYDzIw
# MjYwMTE5MTgxOTIyWqB2pHQwcjELMAkGA1UEBhMCR0IxFzAVBgNVBAgTDldlc3Qg
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
# MQ8XDTI2MDExOTE4MTkyMlowPwYJKoZIhvcNAQkEMTIEMLiMRnrONtw/XlNNkwjJ
# MQKmygrMoqq7FlMxVjbuXSlHxIOhQJfD5uKRsU2qE1ovJjCCAXoGCyqGSIb3DQEJ
# EAIMMYIBaTCCAWUwggFhMBYEFDjJFIEQRLTcZj6T1HRLgUGGqbWxMIGHBBTGrlTk
# eIbxfD1VEkiMacNKevnC3TBvMFukWTBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMP
# U2VjdGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBUaW1lIFN0
# YW1waW5nIFJvb3QgUjQ2AhB6I67aU2mWD5HIPlz0x+M/MIG8BBSFPWMtk4KCYXzQ
# kDXEkd6SwULaxzCBozCBjqSBizCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5l
# dyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNF
# UlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNh
# dGlvbiBBdXRob3JpdHkCEDbCsL18Gzrno7PdNsvJdWgwDQYJKoZIhvcNAQEBBQAE
# ggIAiKu3hib07kPn+O3fCG139I8hSdPisFC6tfycqAbh/ukLDcYmRbYCNAGo7mka
# /URt8657ppLMHiSwD4Z6dDjL5yT8Uk7d6W/IoZB7vjbCGdyclqGCqJSaUai4aY2g
# TR4mbB2CgmMECCOlsjhl7ExBmeGGF21z813p9JQD83E/W+SV6TAhwGgsz5of6NhZ
# ubEyYLxIoyJTcKgXAUQCilGPqC2j3Bj1Qor+hSQMIqbfES3+RG9Xf6TNz/NRkg5r
# V/AKYqZ7/I4RHTI3sa536oUKnQMqQku+iN9tdVpEpggvbljAXfwc7ikfjuReLZRJ
# BO5I6CGg8kTGnSydWKx4IIlBB5U5T3loR+ChqKJvPRVjFWWAeMtcGxWXZ3RgtB/W
# lr0eXTwdTVS1X0CCFKYR+9Pq01KbxslaZA0Xt+gxe3IUwfKuJKeVdl97PH4OEINW
# z1puitBB77v4I4RCTd7FKVvlBHq24210k72+Ook4UCLXUy5cJ9rqs73aBQUuqGqj
# 8xMSf3KPcb3xZMQdMu3KmJNpyopguaqNaY/knjQNvYS5kEm71LZWHoR1XtMJSz6u
# 8VSw9sIOKsnIMz4fYmFPYJyZmvUc2jdFGEjCPqBJUxWZd2ninh980BfhH5TcNQZ0
# qXl/eh/efgE+x0jF5/U6G6R/b5cV+TW2zkoSZwjc8RQzBJo=
# SIG # End signature block
