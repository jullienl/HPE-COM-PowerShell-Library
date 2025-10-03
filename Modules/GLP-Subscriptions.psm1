#------------------- FUNCTIONS FOR HPE GreenLake SUBSCRIPTIONS -----------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1

# Public Functions
Function Get-HPEGLSubscription {
    <#
    .SYNOPSIS
    Retrieve device and service subscriptions from HPE GreenLake.

    .DESCRIPTION
    This Cmdlet returns a collection of device and service subscriptions or a filtered collection based on optional parameters.
    Subscriptions are necessary for assigning them to devices using the 'Add-HPEGLSubscriptionToDevice' Cmdlet.

    .PARAMETER SubscriptionKey
    Specifies the subscription key to display.

    .PARAMETER ShowDeviceSubscriptions 
    Optional parameter used to display device subscriptions.

    .PARAMETER ShowServiceSubscriptions
    Optional parameter used to display service subscriptions.

    .PARAMETER FilterBySubscriptionType
    Specifies the subscription type to filter the results. 
    This parameter accepts the following values: 'Access Point', 'Bridge', 'Gateway', 'Sensor', 'Server', 'Storage', 'Switch'.

    .PARAMETER ShowWithAvailableQuantity 
    Optional parameter that displays only the subscriptions with available quantity.
    
    .PARAMETER ShowValid 
    Optional parameter that displays only the subscriptions that are not expired.
    If $ShowValid is specified, only subscriptions that are not expired will be included in the results.

    .PARAMETER ShowExpired 
    Optional parameter that displays only the subscriptions that are expired.
    If $ShowExpired is specified, only subscriptions that are expired will be included in the results.

    .PARAMETER ShowAssignedServers
    Optional parameter. When used with the SubscriptionKey parameter, displays all servers currently assigned to the specified subscription key.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Get-HPEGLSubscription

    Returns all device subscriptions.
    
    .EXAMPLE
    Get-HPEGLSubscription -SubscriptionKey "000000000000"
    
    Returns the subscription with the key '000000000000'.

    .EXAMPLE
    Get-HPEGLSubscription -ShowServiceSubscriptions 

    Returns all service subscriptions.

    .EXAMPLE
    Get-HPEGLSubscription -ShowDeviceSubscriptions 

    Returns all device subscriptions.

    .EXAMPLE
    Get-HPEGLSubscription -ShowValid
        
    Returns all device subscriptions that are not expired.

    .EXAMPLE
    Get-HPEGLSubscription -FilterBySubscriptionType Switch 

    Returns all device subscriptions of type 'Switch'.

    .EXAMPLE
    Get-HPEGLSubscription -ShowValid -ShowWithAvailableQuantity
        
    Returns all device subscriptions that are not expired and have available quantity.

    .EXAMPLE
    Get-HPEGLSubscription -ShowWithAvailableQuantity -ShowValid -FilterBySubscriptionType Server

    Returns all device subscriptions that are not expired, have available quantity, and are of type 'Server'.

    .EXAMPLE
    Get-HPEGLSubscription -SubscriptionKey "000000000000" -ShowAssignedServers 
    Returns all servers assigned to the subscription with the key '000000000000'.

    #>   

    [CmdletBinding(DefaultParameterSetName = 'Device')]
    Param( 

        [Parameter (ParameterSetName = 'Device')]
        [Parameter (Mandatory, ParameterSetName = 'AssignedServers')]
        [String]$SubscriptionKey,

        [Parameter (ParameterSetName = 'Device')]
        [Switch]$ShowDeviceSubscriptions,

        [Parameter (ParameterSetName = 'Service')]
        [Switch]$ShowServiceSubscriptions,

        [Parameter (ParameterSetName = 'Device')]
        [ValidateSet('Access Point', 'Bridge', 'Gateway', 'Sensor', 'Server', 'Storage', 'Switch')]
        [String]$FilterBySubscriptionType,

        [Parameter (ParameterSetName = 'Device')]
        [Parameter (ParameterSetName = 'Service')]
        [Switch]$ShowWithAvailableQuantity,

        [Parameter (ParameterSetName = 'Device')]
        [Parameter (ParameterSetName = 'Service')]
        [Switch]$ShowValid,
        
        [Parameter (ParameterSetName = 'Expired')]
        [Switch]$ShowExpired,

        [Parameter (ParameterSetName = 'AssignedServers')]
        [Switch]$ShowAssignedServers,

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-SubscriptionsUri
        # $Uri = Get-LicenseDevicesProductTypeDeviceUri
        
    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $ReturnData = @()
        
        try {
            [array]$Collection = Invoke-HPEGLWebRequest -Method get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
                
        if ($Null -ne $Collection) {
            
            $CollectionList = $Collection
            
            $CurrentDate = Get-Date
            
            if ($ShowWithAvailableQuantity -and $ShowValid) {  
                
                "ShowWithAvailableQuantity and ShowValid" | Write-Verbose
                $CollectionList = $CollectionList | Where-Object { $_.availableQuantity -ge 1 -and $_.endTime -gt $CurrentDate }
            }  
            elseif ($ShowWithAvailableQuantity -and -not $ShowValid) {    

                "ShowWithAvailableQuantity and not ShowValid" | Write-Verbose
                $CollectionList = $CollectionList | Where-Object { $_.availableQuantity -ge 1 }
            }
            elseif ($ShowValid -and -not $ShowWithAvailableQuantity) {
                
                "ShowValid and not ShowWithAvailableQuantity" | Write-Verbose
                $CollectionList = $CollectionList | Where-Object { $_.endTime -gt $CurrentDate }
            }    
            elseif ($ShowExpired) {
                
                "ShowExpired" | Write-Verbose
                $CollectionList = $CollectionList | Where-Object { $_.endTime -lt $CurrentDate }
            }    
   

            if ($ShowDeviceSubscriptions) {
                $CollectionList = $CollectionList | Where-Object { $_.productType -eq "DEVICE" }
            }
            elseif ($ShowServiceSubscriptions) {
                $CollectionList = $CollectionList | Where-Object { $_.productType -eq "SERVICE" }
            }

            # FilterBySubscriptionType can be one of the following values:
            # 'Access Point', 'Bridge', 'Gateway', 'Sensor', 'Server', 'Storage', 'Switch'  
            # API:
            # "CENTRAL_AP" "CENTRAL_COMPUTE" "CENTRAL_CONTROLLER" "CENTRAL_GW" "CENTRAL_NW_THIRD_PARTY" "CENTRAL_STORAGE" 
            # "CENTRAL_SWITCH" "OPSRAMP" "PRIVATE_CLOUD_ENTERPRISE" "SERVICE" "SUPPORT" "UNKNOWN" "UXI_AGENT_ANDROID"
            # "UXI_AGENT_CLOUD" "UXI_SENSOR_CLOUD" "UXI_SENSOR_LTE" 
            if ($FilterBySubscriptionType) {

                if ($FilterBySubscriptionType -eq "Access Point") {
                    $_SubscriptionType = "CENTRAL_AP"
                }
                
                if ($FilterBySubscriptionType -eq "Bridge") {
                    $_SubscriptionType = "CENTRAL_CONTROLLER"
                }

                if ($FilterBySubscriptionType -eq "Gateway") {
                    $_SubscriptionType = "CENTRAL_GW"
                }
        
                if ($FilterBySubscriptionType -eq "Server") {
                    $_SubscriptionType = "CENTRAL_COMPUTE"
                }
        
                if ($FilterBySubscriptionType -eq "Storage") {
                    $_SubscriptionType = "CENTRAL_STORAGE"
                }
        
                if ($FilterBySubscriptionType -eq "Switch") {
                    $_SubscriptionType = "CENTRAL_SWITCH"
                }
      
                if ($FilterBySubscriptionType -eq "Sensor") {
                    $_SubscriptionType = "UXI_SENSOR_CLOUD"
                }

                $CollectionList = $CollectionList | Where-Object subscriptionType -match $_SubscriptionType
            } 
            

            if ($SubscriptionKey) {

                if ($ShowAssignedServers) {

                    foreach ($Region in ($Global:HPECOMRegions.region)) {

                        "[{0}] Search server resource in region '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose

                        $serversfound = $null

                        # Get servers using the subscription key
                        $serversfound = Get-HPECOMServer -Region $Region -ShowSubscriptionDetails | Where-Object SubscriptionKey -eq $SubscriptionKey
                        # "[{0}] Server resource found: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($serversfound.name | Out-String )| Write-Verbose

                        if ($serversfound) {
                            $ReturnData += $serversfound
                        }
                    }

                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $ReturnData -ObjectName "COM.Servers.Subscription.AssignedServers"   
                    $ReturnData = $ReturnData | Sort-Object name, { $_.hardware.serialNumber }
                    return $ReturnData 
                }
                else {                    
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "License"    
                    $ReturnData = $ReturnData | Where-Object key -eq $SubscriptionKey
                    return $ReturnData 
                }
            }
            else {
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "License"    
                $ReturnData = $ReturnData | Sort-Object { $_.key }
                return $ReturnData 
            }
    
        }
        else {

            return 
            
        }
    }
}

Function New-HPEGLSubscription {
    <#
    .SYNOPSIS
    Add a subscription to HPE GreenLake.

    .DESCRIPTION
    This Cmdlet adds a service or device subscription to the HPE GreenLake workspace. You can add up to five subscriptions in a single pipeline input.

    .PARAMETER SubscriptionKey 
    The subscription key to add to the GreenLake workspace.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    New-HPEGLSubscription -SubscriptionKey 'Kxxxxxxxxxx' 

    Adds the subscription key 'Kxxxxxxxxxx'.
        
    .EXAMPLE
    "Kxxxxxxxxxx","Kxxxxxxxxxx","Kxxxxxxxxxx" | New-HPEGLSubscription

    Adds the subscription keys 'Kxxxxxxxxxx', 'Kxxxxxxxxxx', 'Kxxxxxxxxxx'.

    .EXAMPLE
    Import-Csv Private\csv\Subscription_keys.csv  | New-HPEGLSubscription

    Adds the subscription keys from the CSV file 'Subscription_keys.csv'.

    The content of the CSV file must use the following format:

        Key
        EZ12312312
        DZ12312312
        CZ12312312
        BZ12312312
        AZ12312312

    .INPUTS
    System.Collections.ArrayList
        List of subscription key(s) with the key property. 
    System.String, System.String[]
        A single string object or a list of string objects that represent the subscription keys.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * SubscriptionKey - The subscription key attempted to be added 
        * Status - The status of the addition attempt (Failed for HTTP error return; Complete if addition is successful) 
        * Details - More information about the status 
        * Exception - Information about any exceptions generated during the operation.
    #>


    [CmdletBinding()]
    Param( 

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('key')]
        [String]$SubscriptionKey,
        
        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $ObjectStatusList = [System.Collections.ArrayList]::new()
        $SubscriptionKeysList = [System.Collections.ArrayList]::new()
        
    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        if ($Subscription.Key) {
            $SubscriptionKey = $Subscription.Key
        }

        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            SubscriptionKey = $SubscriptionKey
            Status          = $Null
            Details         = $Null
            Exception       = $Null
          
        }

        [void] $ObjectStatusList.add($objStatus)

  
    }
    end {

        try {
            $SubscriptionKeys = Get-HPEGLSubscription 
        }
        catch {    
            $PSCmdlet.ThrowTerminatingError($_)
        
        }

        "[{0}] List of keys to add to workspace: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList.SubscriptionKey | out-string) | Write-Verbose

        # API supports Maximum five subscriptions per request

        if ($ObjectStatusList.Count -gt 5) {
            $ErrorMessage = "Maximum of 5 subscriptions per request is allowed!"
            Write-warning $ErrorMessage
            return
        }
        else {
            
            foreach ($Object in $ObjectStatusList) {
                
                "[{0}] Checking key '{1}' " -f $MyInvocation.InvocationName.ToString().ToUpper(), $Object.SubscriptionKey | Write-Verbose
                
                $Subscription = $SubscriptionKeys | Where-Object key -eq $Object.SubscriptionKey
                
                
                if ($Subscription) {

                    # Must return a message if subscription already present

                    "[{0}] Subscription '{1}' already exists in the workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

                    if ($WhatIf) {
                        $ErrorMessage = "Subscription '{0}': Resource already exists in the workspace! No action needed." -f $Name
                        Write-warning $ErrorMessage
                        return
                    }
                    else {
                        $objStatus.Status = "Warning"
                        $objStatus.Details = "Subscription already exists in the workspace! No action needed."
                    }
                   
                }
                else {

                    $Uri = Get-SubscriptionsUri

                    # Build Key object for paylaod
                    $Key = [PSCustomObject]@{
                        key = $Object.SubscriptionKey
                        
                    }
                    
                    # Building the list of keys object for payload
                    [void]$SubscriptionKeysList.Add($Key)
                }
            }


            if ($SubscriptionKeysList) {
                
                # Build payload
                $payload = ConvertTo-Json -Depth 10 @{
                    subscriptions = @($SubscriptionKeysList)
                } 
                
                # Add subscription keys
                try {
                
                    Invoke-HPEGLWebRequest -Uri $Uri -method 'POST' -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    | out-Null
                
                    if (-not $WhatIf) {

                        foreach ($Object in $ObjectStatusList) {

                            if ($Object.Status -ne "Warning") {
                                
                                $Object.Status = "Complete"
                                $Object.Details = "Service subscription successfully added to the HPE GreenLake platform"
                                $Object.Exception = $_.Exception.message 
                            }
                        }
                    
                    }
                    
                }
                catch {
                    
                    if (-not $WhatIf) {

                        foreach ($Object in $ObjectStatusList) {
                                
                            $Object.Status = "Failed"
                            $Object.Details = "Service subscription was not added to the HPE GreenLake platform"
                            $Object.Exception = $_.Exception.message 
    
                        }
                    }
                }   
            } 
    


            if (-not $WhatIf) {

                $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "License.SSDE"    
                Return $ObjectStatusList
            }
        }
    }     
}

Function Remove-HPEGLSubscription {
    <#
    .SYNOPSIS
    Delete a subscription from the HPE GreenLake Workspace.

    .DESCRIPTION
    This cmdlet removes a subscription from the HPE GreenLake workspace. A subscription can be removed only if it has not been consumed.

    .PARAMETER SubscriptionKey 
    The subscription key to remove from the GreenLake workspace.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Remove-HPEGLSubscription -SubscriptionKey 'Kxxxxxxxxxx'

    Removes the subscription key 'Kxxxxxxxxxx'.

    .EXAMPLE
    Get-HPEGLSubscription -FilterBySubscriptionType Server | Remove-HPEGLSubscription

    Removes all 'Server' type subscriptions from the workspace.

    .EXAMPLE
    "Kxxxxxxxxxx","Kxxxxxxxxxx","Kxxxxxxxxxx","Kxxxxxxxxxx" | Remove-HPEGLSubscription 

    Removes multiple subscriptions from the workspace.

    .INPUTS
    System.Collections.ArrayList
        A list of subscriptions retrieved from 'Get-HPEGLSubscription'. 
    System.String, System.String[]
        A single string object or a list of string objects that represent the subscription keys.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * SubscriptionKey - The subscription key attempted to be removed 
        * Status - The status of the removal attempt (Failed for HTTP error return; Complete if addition is successful) 
        * Details - More information about the status 
        * Exception - Information about any exceptions generated during the operation.
    
    #>

    [CmdletBinding()]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [alias('key')]
        [String]$SubscriptionKey,
        
        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $RemoveSubscriptionStatus = [System.Collections.ArrayList]::new()
        
    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        try {
            $SubscriptionKeyFound = Get-HPEGLSubscription -SubscriptionKey $SubscriptionKey

            $SubscriptionKeyNotConsumed = $SubscriptionKeyFound | Where-Object { $_.quantity -eq $_.availableQuantity }
      
        }
        catch {    
            $PSCmdlet.ThrowTerminatingError($_)
        
        }

        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            SubscriptionKey = $SubscriptionKey
            Status          = $Null
            Details         = $Null
            Exception       = $Null
          
        }


        if (-not $SubscriptionKeyFound) {
            # Must return a message if subscription not present
            "[{0}] Subscription '{1}' cannot be found in the workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SubscriptionKey | Write-Verbose
        
            if ($WhatIf) {
                $ErrorMessage = "Subscription '{0}': Resource cannot be found in the workspace!" -f $SubscriptionKey
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "Subscription cannot be found in the workspace!"
            }
        }
        elseif (-not $SubscriptionKeyNotConsumed) {
            # Must return a message if subscription has been consumed
            "[{0}] Subscription '{1}' has been consumed and cannot be removed from the workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SubscriptionKey | Write-Verbose
        
            if ($WhatIf) {
                $ErrorMessage = "Subscription '{0}': Resource has been consumed and cannot be removed from the workspace! This can be resolved by unassigning the device from its service instance using 'Remove-HPEGLDeviceFromService'." -f $SubscriptionKey
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "Subscription has been consumed and cannot be removed from the workspace! This can be resolved by unassigning the device from its service instance using 'Remove-HPEGLDeviceFromService'."
            }
            
        }
        else {
           
            $SubscriptionKeyId = $SubscriptionKeyFound.key

            $Uri = Get-RemoveLicensesUri

            
            # Build payload
            $payload = [PSCustomObject]@{
                subscription_keys = @($SubscriptionKeyId)                

            } | ConvertTo-Json 


            
            try {
                Invoke-HPEGLWebRequest -Uri $Uri -method 'POST' -Body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    | out-Null

                if (-not $WhatIf) {

                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Device subscription successfully removed from the workspace"
                    
                }
                
            }
            catch {

                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Failed to remove the device subscription from the workspace."
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                }
            
            }   
        } 

        [void] $RemoveSubscriptionStatus.add($objStatus)

  
    }
    end {

        if (-not $WhatIf) {

            $RemoveSubscriptionStatus = Invoke-RepackageObjectWithType -RawObject $RemoveSubscriptionStatus -ObjectName "License.SSDE"    

            Return $RemoveSubscriptionStatus
        }
    }

}

Function Get-HPEGLDeviceAutoSubscription {
    <#
    .SYNOPSIS
    Retrieve the automatic subscription status of device(s) in the HPE GrenLake workspace.

    .DESCRIPTION
    This Cmdlet returns the automatic subscription status of device(s) in the HPE GreenLake workspace.

    Automatic subscription assignment allows HPE GreenLake to automatically assign an valid license to devices.
    
    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Get-HPEGLDeviceAutoSubscription

    Returns the automatic subscription status of device(s) in the HPE GreenLake workspace.
    
   #>

    [CmdletBinding()]
    Param( 
        [Switch]$WhatIf   
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-AutoLicenseDevicesUri
        
    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $ReturnData = @()
        
        try {
            [array]$Collection = Invoke-HPEGLWebRequest -Method GET -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
  
        
        if ($Null -ne $Collection.autolicenses) {

            $CollectionList = $Collection.autolicenses #| Where-Object { $_.enabled -eq $True }

            $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "License.AutoSubscribe"    

            $ReturnData = $ReturnData | Sort-Object { $_device_type }
    
            return $ReturnData 
        }
        else {

            return 
            
        }  
    }
}

function Set-HPEGLDeviceAutoSubscription {
    <#
    .SYNOPSIS
    Configure automatic subscription assignment for each supported device type.

    .DESCRIPTION
    This Cmdlet enables the automatic assignment of subscriptions to different type of devices. 
    
    Automatic subscription assignment allows HPE GreenLake to automatically assign an valid license to devices.

    .PARAMETER AccessPointSubscriptionTier 
    Defines the automatic subscription for "Access Points". The subscription level can be selected from a predefined list.

    .PARAMETER GatewaySubscriptionTier 
    Defines the automatic subscription for "Gateways". The subscription level can be selected from a predefined list.

    .PARAMETER ComputeSubscriptionTier 
    Defines the automatic subscription for "Computes". The subscription level can be selected from a predefined list.

    .PARAMETER SwitchSubscriptionTier 
    Defines the automatic subscription for "Switches". The subscription level can be selected from a predefined list.

    .PARAMETER SensorsSubscriptionTier 
    Defines the automatic subscription for "Sensors". The subscription level can be selected from a predefined list.

    .PARAMETER WhatIf
    Displays the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Set-HPEGLDeviceAutoSubscription -ComputeSubscriptionTier ENHANCED

    Configures auto-subscription for compute devices using the Enhanced subscription tier.

    .EXAMPLE
    Set-HPEGLDeviceAutoSubscription -SwitchSubscriptionTier ADVANCED

    Configures auto-subscription for switch devices using the Advanced subscription tier.

    .INPUTS
    None. You cannot pipe objects to this Cmdlet.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or an array of objects containing the following PsCustomObject keys:  
        * DeviceType - The type of device configured for auto-subscription.
        * Status - The status of the auto-subscription assignment attempt (Failed for HTTP error return; Complete if successful).
        * Details - Additional information about the status.
        * Exception - Information about any exceptions generated during the operation.
    #>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 

        [Parameter (Mandatory, ParameterSetName = "AP")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('FOUNDATION', 'ADVANCED')]
        [String]$AccessPointSubscriptionTier,

        [Parameter (Mandatory, ParameterSetName = "Gateway")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('FOUNDATION', 'ADVANCED')]
        [String]$GatewaySubscriptionTier,

        [Parameter (Mandatory, ParameterSetName = "Compute")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('STANDARD', 'ENHANCED')]
        [String]$ComputeSubscriptionTier,

        [Parameter (Mandatory, ParameterSetName = "Switch")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('FOUNDATION', 'ADVANCED')]
        [String]$SwitchSubscriptionTier,

        [Parameter (Mandatory, ParameterSetName = "Sensor")]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('FOUNDATION')]
        [String]$SensorSubscriptionTier,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-AutoLicenseDevicesUri
        $AutoSubscriptionStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

      
        if ($AccessPointSubscriptionTier -eq 'FOUNDATION' ) {
            $AutoLicenseSubscriptionTierGroup = "FOUNDATION_AP"
            $DeviceType = "AP"
        }
        elseif ($AccessPointSubscriptionTier -eq 'ADVANCED' ) {
            $AutoLicenseSubscriptionTierGroup = "ADVANCED_AP"
            $DeviceType = "AP"
        }


        if ($GatewaySubscriptionTier -eq 'FOUNDATION' ) {
            $AutoLicenseSubscriptionTierGroup = "FOUNDATION_GW"
            $DeviceType = "GATEWAY"

        }
        elseif ($GatewaySubscriptionTier -eq 'ADVANCED' ) {
            $AutoLicenseSubscriptionTierGroup = "ADVANCED_GW"
            $DeviceType = "GATEWAY"

        }


        if ($ComputeSubscriptionTier -eq 'STANDARD' ) {
            $AutoLicenseSubscriptionTierGroup = "STANDARD_COMPUTE"
            $DeviceType = "COMPUTE"

        }
        elseif ($ComputeSubscriptionTier -eq 'ENHANCED' ) {
            $AutoLicenseSubscriptionTierGroup = "ENHANCED_COMPUTE"
            $DeviceType = "COMPUTE"

        }


        if ($SwitchSubscriptionTier -eq 'FOUNDATION' ) {
            $AutoLicenseSubscriptionTierGroup = "FOUNDATION_SWITCH"
            $DeviceType = "SWITCH"

        }
        elseif ($SwitchSubscriptionTier -eq 'ADVANCED' ) {
            $AutoLicenseSubscriptionTierGroup = "ADVANCED_SWITCH"
            $DeviceType = "SWITCH"

        }


        if ($SensorSubscriptionTier -eq 'FOUNDATION' ) {
            $AutoLicenseSubscriptionTierGroup = "FOUNDATION_SENSOR"
            $DeviceType = "SENSOR"

        }
       

        # Build object for the output
        $objStatus = [pscustomobject]@{
 
            DeviceType = $DeviceType
            Status     = $Null
            Details    = $Null
            Exception  = $Null
                 
        }


        # Build payload
        $payload = ConvertTo-Json @(
            @{
                device_type                          = $DeviceType
                enabled                              = $True 
                auto_license_subscription_tier_group = $AutoLicenseSubscriptionTierGroup
                    
            }
        ) 
  

        try {
            Invoke-HPEGLWebRequest -Uri $Uri -method 'POST' -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    | Out-Null
               
            if (-not $WhatIf) {

                $objStatus.Status = "Complete"
                $objStatus.Details = "Automatic assignment of subscriptions to '$DeviceType' successfully set!"
                

            }
        }
        catch {
            if (-not $WhatIf) {
                $objStatus.Status = "Failed"
                $objStatus.Details = "Automatic assignment of subscriptions to '$DeviceType' cannot be set!"
                $objStatus.Exception = $Global:HPECOMInvokeReturnData 
            }
        }
        

        [void] $AutoSubscriptionStatus.add($objStatus)
    }

    end {

        if (-not $WhatIf) {

            $AutoSubscriptionStatus = Invoke-RepackageObjectWithType -RawObject $AutoSubscriptionStatus -ObjectName "License.DSDE" 
            Return $AutoSubscriptionStatus
        }


    }
}

function Remove-HPEGLDeviceAutoSubscription {
    <#
    .SYNOPSIS
    Remove automatic subscription assignment for specified device types.

    .DESCRIPTION
    This Cmdlet disables the automatic assignment of subscriptions to specified device types. It allows you to remove auto-subscription settings for Access Points, Gateways, Computes, Sensors and Switches.

    Automatic subscription assignment allows HPE GreenLake to automatically assign an valid license to devices.

    .PARAMETER AccessPoints 
    Removes the automatic subscription assignment for "Access Points".

    .PARAMETER Gateways 
    Removes the automatic subscription assignment for "Gateways".

    .PARAMETER Computes 
    Removes the automatic subscription assignment for "Computes".

    .PARAMETER Switches 
    Removes the automatic subscription assignment for "Switches".

    .PARAMETER WhatIf
    Displays the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Remove-HPEGLDeviceAutoSubscription -Computes

    Removes the auto-subscription for Compute devices.

    .EXAMPLE
    Remove-HPEGLDeviceAutoSubscription -Switches

    Removes the auto-subscription for Switch devices.

    .INPUTS
    None. You cannot pipe objects to this Cmdlet.
    
    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or an array of objects containing the following PsCustomObject keys:  
        * DeviceType - The type of device removed from auto-subscription.
        * Status - The status of the auto-subscription unassignment attempt (Failed for HTTP error return; Complete if successful).
        * Details - Additional information about the status.
        * Exception - Information about any exceptions generated during the operation.
    #>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 

        [Parameter (Mandatory, ParameterSetName = "AP")]
        [Switch]$AccessPoints,

        [Parameter (Mandatory, ParameterSetName = "Gateway")]
        [Switch]$Gateways,

        [Parameter (Mandatory, ParameterSetName = "Compute")]
        [Switch]$Computes,

        [Parameter (Mandatory, ParameterSetName = "Switch")]
        [Switch]$Switches,

        [Parameter (Mandatory, ParameterSetName = "Sensor")]
        [Switch]$Sensors,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-AutoLicenseDevicesUri
        $AutoSubscriptionStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

      
        switch ($true) {
            $AccessPoints { $DeviceType = "AP" }
            $Gateways { $DeviceType = "GATEWAY" }
            $Computes { $DeviceType = "COMPUTE" }
            $Switches { $DeviceType = "SWITCH" }
            $Sensors { $DeviceType = "SENSOR" }
        }

        # Build object for the output
        $objStatus = [pscustomobject]@{

            DeviceType = $DeviceType
            Status     = $Null
            Details    = $Null
            Exception  = $Null
             
        }


        try {
            
            $AutoLicenseSubscriptionTierGroup = (Get-HPEGLDeviceAutoSubscription | Where-Object { $_.device_Type -eq $DeviceType }).auto_license_subscription_tier_group

            "[{0}] Found Auto License Subscription Tier Group: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $AutoLicenseSubscriptionTierGroup | Write-Verbose
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        if ($AutoLicenseSubscriptionTierGroup) {

            # Build payload
            $payload = ConvertTo-Json @(
                @{
                    device_type                          = $DeviceType
                    enabled                              = $False 
                    auto_license_subscription_tier_group = $AutoLicenseSubscriptionTierGroup
                    
                }
            ) 
  

            # Assign Device to Service 
    
            try {
                Invoke-HPEGLWebRequest -Uri $Uri -method 'POST' -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    | Out-Null
               
                if (-not $WhatIf) {

                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Automatic assignment of subscriptions to '$DeviceType' successfully set!"
                
                }
            }
            catch {
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Automatic assignment of subscriptions to '$DeviceType' cannot be set!"
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                }
            }
        }
        else {

            if ($WhatIf) {
                $ErrorMessage = "Automatic subscription cannot be found for '$DeviceType'!" -f $Name
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "Automatic subscription cannot be found!"
            }
           
        }

        [void] $AutoSubscriptionStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            $AutoSubscriptionStatus = Invoke-RepackageObjectWithType -RawObject $AutoSubscriptionStatus -ObjectName "License.DSDE" 
            Return $AutoSubscriptionStatus
        }


    }
}

Function Get-HPEGLDeviceAutoReassignSubscription {
    <#
    .SYNOPSIS
    Retrieve the automatic subscription reassignment status of device(s) in the HPE GrenLake workspace.

    .DESCRIPTION
    This Cmdlet returns the device types enabled for automatic subscription reassignment.

    Automatic subscription reassignment is a feature to switche the device when a subscription expires to another subscription of the same type preventing disruptions.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Get-HPEGLDeviceAutoReassignSubscription

    Returns the automatic subscription reassignment status of device(s) in the HPE GreenLake workspace.
    
   #>

    [CmdletBinding()]
    Param( 
        [Switch]$WhatIf   
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-AutoRenewalDevicesUri

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $ReturnData = @()
        
        try {
            [array]$Collection = Invoke-HPEGLWebRequest -Method GET -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
  
        
        if ($Null -ne $Collection.renewalSettingsList) {

            $CollectionList = $Collection.renewalSettingsList #| Where-Object { $_.enabled -eq $True }

            $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "License.AutoReassign"    

            $ReturnData = $ReturnData | Sort-Object { $_device_type }
    
            return $ReturnData 
        }
        else {

            return 
            
        }  
    }
}

function Set-HPEGLDeviceAutoReassignSubscription {
    <#
    .SYNOPSIS
    Configure automatic subscription reassignment for each supported device type.

    .DESCRIPTION
    This Cmdlet enables the automatic reassignment of subscriptions to devices. 
    Automatic subscription reassignment is a feature to switche the device when a subscription expires to another subscription of the same type preventing disruptions.

    .PARAMETER AccessPoints
    Defines the automatic subscription reassignment for "Access Points".

    .PARAMETER Gateways 
    Defines the automatic subscription reassignment for "Gateways".

    .PARAMETER Computes 
    Defines the automatic subscription reassignment for "Computes".

    .PARAMETER Switches 
    Defines the automatic subscription reassignment for "Switches".

    .PARAMETER Sensors 
    Defines the automatic subscription reassignment for "Sensors".

    .PARAMETER Bridges 
    Defines the automatic subscription reassignment for "Bridges".

    .PARAMETER EdgeComputeVirtual
    Defines the automatic subscription reassignment for "Edge Compute Virtual".

    .PARAMETER SDWANGateway
    Defines the automatic subscription reassignment for "SD-WAN Gateway".

    .PARAMETER WhatIf
    Displays the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Set-HPEGLDeviceAutoReassignSubscription -Computes

    Configures auto-reassignment for compute devices.

    .EXAMPLE
    Set-HPEGLDeviceAutoReassignSubscription -Switches

    Configures auto-reassignment for switch devices.

    .EXAMPLE
    Set-HPEGLDeviceAutoReassignSubscription -AccessPoints -Gateways

    Configures auto-reassignment for access points and gateways.

    .INPUTS
    None. You cannot pipe objects to this Cmdlet.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or an array of objects containing the following PsCustomObject keys:  
        * DeviceType - The type of device configured for auto-subscription.
        * Status - The status of the auto-subscription assignment attempt (Failed for HTTP error return; Complete if successful).
        * Details - Additional information about the status.
        * Exception - Information about any exceptions generated during the operation.
    #>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 

        [switch]$AccessPoints,

        [switch]$Gateways,

        [switch]$Computes,

        [switch]$Switches,

        [switch]$Sensors,

        [switch]$Bridges,

        [Switch]$EdgeComputeVirtual,

        [Switch]$SDWANGateway,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-AutoRenewalDevicesUri
        $AutoReassignmentStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        try {

            $ExistingSettings = Get-HPEGLDeviceAutoReassignSubscription
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        switch ($true) {
            $AccessPoints { 
            ($ExistingSettings | Where-Object deviceType -eq "AP").enabled = $true
            $DeviceType = "AccessPoints"
            }
            $Gateways { 
            ($ExistingSettings | Where-Object deviceType -eq "GATEWAY").enabled = $true
            $DeviceType = "Gateways"
            }
            $Computes { 
            ($ExistingSettings | Where-Object deviceType -eq "COMPUTE").enabled = $true
            $DeviceType = "Computes"
            }
            $Sensors { 
            ($ExistingSettings | Where-Object deviceType -eq "SENSOR").enabled = $true
            $DeviceType = "Sensors"
            }
            $Switches { 
            ($ExistingSettings | Where-Object deviceType -eq "SWITCH").enabled = $true
            $DeviceType = "Switches"
            }
            $Bridges { 
            ($ExistingSettings | Where-Object deviceType -eq "BRIDGE").enabled = $true
            $DeviceType = "Bridges"
            }
            $SDWANGateway { 
            ($ExistingSettings | Where-Object deviceType -eq "SD_WAN_GW").enabled = $true
            $DeviceType = "SD_WAN_GW"
            }   
            $EdgeComputeVirtual { 
            ($ExistingSettings | Where-Object deviceType -eq "EC_V").enabled = $true
            $DeviceType = "EC_V"
            }
        }

        if ($PSBoundParameters.Count -gt 1) {
            $DeviceType = "Multiple Types"
        }


        # Build object for the output
        $objStatus = [pscustomobject]@{
 
            DeviceType = $DeviceType
            Status     = $Null
            Details    = $Null
            Exception  = $Null
                 
        }

       
        # Remove PSObject.TypeNames property
        $CleanedSettings = $ExistingSettings | Select-Object -Property * -ExcludeProperty PSObject.TypeNames 

        # Build payload
        $payload = ConvertTo-Json @{ 
            
            renewalSettingsList = $CleanedSettings
        
        }
              

        try {
            Invoke-HPEGLWebRequest -Uri $Uri -method PATCH -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    | Out-Null
               
            if (-not $WhatIf) {

                $objStatus.Status = "Complete"
                $objStatus.Details = "Automatic reassignment of subscriptions successfully set!"
                

            }
        }
        catch {
            if (-not $WhatIf) {
                $objStatus.Status = "Failed"
                $objStatus.Details = "Automatic reassignment of subscriptions cannot be set!"
                $objStatus.Exception = $Global:HPECOMInvokeReturnData 
            }
        }
        

        [void] $AutoReassignmentStatus.add($objStatus)
    }

    end {

        if (-not $WhatIf) {

            $AutoReassignmentStatus = Invoke-RepackageObjectWithType -RawObject $AutoReassignmentStatus -ObjectName "License.DSDE" 
            Return $AutoReassignmentStatus
        }


    }
}

function Remove-HPEGLDeviceAutoReassignSubscription {
    <#
    .SYNOPSIS
    Remove automatic subscription reassignment for specified device types.

    .DESCRIPTION
    This Cmdlet disables the automatic reassignment of subscriptions to specified device types.
    Automatic subscription reassignment is a feature to switche the device when a subscription expires to another subscription of the same type preventing disruptions.

    .PARAMETER AccessPoints 
    Removes the automatic subscription reassignment for "Access Points".

    .PARAMETER Gateways 
    Removes the automatic subscription reassignment for "Gateways".

    .PARAMETER Computes 
    Removes the automatic subscription reassignment for "Computes".

    .PARAMETER Switches 
    Removes the automatic subscription reassignment for "Switches".
    
    .PARAMETER Sensors 
    Removes the automatic subscription reassignment for "Sensors".
    
    .PARAMETER Bridges
    Removes the automatic subscription reassignment for "Bridges".

    .PARAMETER EdgeComputeVirtual
    Removes the automatic subscription reassignment for "Edge Compute Virtual".

    .PARAMETER SDWANGateway
    Removes the automatic subscription reassignment for "SD-WAN Gateway".

    .PARAMETER WhatIf
    Displays the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Remove-HPEGLDeviceAutoReassignSubscription -Computes

    Removes the auto-reassignment for compute devices.
    
    .EXAMPLE
    Remove-HPEGLDeviceAutoReassignSubscription -Switches

    Removes the auto-reassignment for switch devices.

    .EXAMPLE
    Remove-HPEGLDeviceAutoReassignSubscription -Gateways -Computes -Switches 

    Removes the auto-reassignment for gateways, computes, and switches.

    .INPUTS
    None. You cannot pipe objects to this Cmdlet.
    
    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or an array of objects containing the following PsCustomObject keys:  
        * DeviceType - The type of device removed from auto-subscription.
        * Status - The status of the auto-subscription unassignment attempt (Failed for HTTP error return; Complete if successful).
        * Details - Additional information about the status.
        * Exception - Information about any exceptions generated during the operation.
    #>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 

        [Switch]$AccessPoints,

        [Switch]$Gateways,

        [Switch]$Computes,

        [Switch]$Switches,

        [Switch]$Sensors,

        [Switch]$Bridges,

        [Switch]$EdgeComputeVirtual,

        [Switch]$SDWANGateway,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-AutoRenewalDevicesUri
        $AutoReassignmentStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

      
        try {

            $ExistingSettings = Get-HPEGLDeviceAutoReassignSubscription
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

      switch ($true) {
            $AccessPoints { 
            ($ExistingSettings | Where-Object deviceType -eq "AP").enabled = $false
            $DeviceType = "AccessPoints"
            }
            $Gateways { 
            ($ExistingSettings | Where-Object deviceType -eq "GATEWAY").enabled = $false
            $DeviceType = "Gateways"
            }
            $Computes { 
            ($ExistingSettings | Where-Object deviceType -eq "COMPUTE").enabled = $false
            $DeviceType = "Computes"
            }
            $Sensors { 
            ($ExistingSettings | Where-Object deviceType -eq "SENSOR").enabled = $false
            $DeviceType = "Sensors"
            }
            $Switches { 
            ($ExistingSettings | Where-Object deviceType -eq "SWITCH").enabled = $false
            $DeviceType = "Switches"
            }
            $Bridges { 
            ($ExistingSettings | Where-Object deviceType -eq "BRIDGE").enabled = $false
            $DeviceType = "Bridges"
            }
            $SDWANGateway { 
            ($ExistingSettings | Where-Object deviceType -eq "SD_WAN_GW").enabled = $false
            $DeviceType = "SD_WAN_GW"
            }   
            $EdgeComputeVirtual { 
            ($ExistingSettings | Where-Object deviceType -eq "EC_V").enabled = $false
            $DeviceType = "EC_V"
            }
        }


        if ($PSBoundParameters.Count -gt 1) {
            $DeviceType = "Multiple types"
        }


        # Build object for the output
        $objStatus = [pscustomobject]@{

            DeviceType = $DeviceType
            Status     = $Null
            Details    = $Null
            Exception  = $Null
             
        }

          
        # Remove PSObject.TypeNames property
        $CleanedSettings = $ExistingSettings | Select-Object -Property * -ExcludeProperty PSObject.TypeNames 

        # Build payload
        $payload = ConvertTo-Json @{ 
            
            renewalSettingsList = $CleanedSettings
        
        }
              

        try {
            Invoke-HPEGLWebRequest -Uri $Uri -method PATCH -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    | Out-Null
               
            if (-not $WhatIf) {

                $objStatus.Status = "Complete"
                $objStatus.Details = "Automatic reassignment of subscriptions successfully disabled!"
                

            }
        }
        catch {
            if (-not $WhatIf) {
                $objStatus.Status = "Failed"
                $objStatus.Details = "Automatic reassignment of subscriptions cannot be disabled!"
                $objStatus.Exception = $Global:HPECOMInvokeReturnData 
            }
        }
        

        [void] $AutoReassignmentStatus.add($objStatus)
    }

    end {

        if (-not $WhatIf) {

            $AutoReassignmentStatus = Invoke-RepackageObjectWithType -RawObject $AutoReassignmentStatus -ObjectName "License.DSDE" 
            Return $AutoReassignmentStatus
        }


    }

      
}

Function Add-HPEGLSubscriptionToDevice {
    <#
        .SYNOPSIS
        Apply a subscription key to device(s). 

        .DESCRIPTION
        This Cmdlet applies a license subscription key to device(s).     
            
        .PARAMETER DeviceSerialNumber 
        Specifies the serial number of the device to which a subscription key will be applied. This value can be retrieved using 'Get-HPEGLDevice'.

        .PARAMETER SubscriptionKey 
        Specifies the subscription key of a valid and non-expired license. This value can be retrieved using 'Get-HPEGLSubscription -ShowWithAvailableQuantity -ShowValid'.

        .PARAMETER WhatIf
        Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

        .EXAMPLE
        Add-HPEGLSubscriptionToDevice -DeviceSerialNumber CNX2380BLC -SubscriptionKey ABCDEFG1234

        Applies a the subscription key 'ABCDEFG1234' to the device with the serial number CNX2380BLC.

        .EXAMPLE
        Get-HPEGLSubscription -ShowWithAvailableQuantity -ShowValid -FilterBySubscriptionType Server | Select-Object -First 1 | Add-HPEGLSubscriptionToDevice -DeviceSerialNumber CNX2380BLC 
        
        Retrieves the first available valid server subscription key with available quantity and assigns it to the device with serial number CNX2380BLC.
        
        .EXAMPLE
        $Subscription_Key = Get-HPEGLSubscription -ShowWithAvailableQuantity -ShowValid -FilterBySubscriptionType Server | select -First 1 -ExpandProperty key

        'CNX2380BLC', 'MXQ73200W1' | Add-HPEGLSubscriptionToDevice -SubscriptionKey $SubscriptionKey

        Applies a server subscription key to devices with serial numbers 'CNX2380BLC' and 'MXQ73200W1'.

        .EXAMPLE
        Import-Csv Tests/Network_Devices.csv | Add-HPEGLSubscriptionToDevice -SubscriptionKey $SubscriptionKey

        Applies a subscription key to devices listed in a CSV file containing at least a SerialNumber column.

        .INPUTS
        System.Collections.ArrayList
            List of device(s) retrieved using the 'Get-HPEGLDevice' cmdlet.
        System.String, System.String[]
            A single string object or a list of string objects representing device serial numbers.
        System.String
            A subscription key obtained from the 'Get-HPEGLSubscription' cmdlet.

        .OUTPUTS
        System.Collections.ArrayList
            A custom status object or array of objects containing the following PsCustomObject keys:
                * SerialNumber - Serial number of the device assigned to a subscription key.
                * Status - Status of the assignment attempt (Failed for HTTP error return; Complete if assignment is successful; Warning if no action is needed).
                * Details - More information about the status.
                * Exception - Information about any exceptions generated during the operation.
    #>


    [CmdletBinding()]
    Param( 
 
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [Alias('SerialNumber')]
        [ValidateNotNullOrEmpty()]
        [String]$DeviceSerialNumber,

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias('key')]
        [String]$SubscriptionKey,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-LicenseDevicesUri

        $ObjectStatusList = [System.Collections.ArrayList]::new()
        $DevicesList = [System.Collections.ArrayList]::new()
        $DeviceIDsList = [System.Collections.ArrayList]::new()

        try {
            
            $subscriptionKeyFound = Get-HPEGLSubscription -ShowWithAvailableQuantity -ShowValid | Where-Object key -eq $SubscriptionKey

            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }

        if ( -not $subscriptionKeyFound) {

            $ErrorMessage = "'{0}' is not a valid subscription or without available quantity or it cannot be found in the HPE GreenLake workspace!" -f $SubscriptionKey
            throw $ErrorMessage

        }


    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        # Check for empty or null serial number
        if (-not $DeviceSerialNumber) {
            Write-Warning "Empty or null serial number skipped."
            continue
        }

        # Build object for the output
        $objStatus = [pscustomobject]@{            
            SerialNumber = $DeviceSerialNumber
            Status       = $Null
            Details      = $Null
            Exception    = $Null            
        }
        

        [void] $ObjectStatusList.add($objStatus)
    }

    end {
        
        try {
            
            $devices = Get-HPEGLdevice 
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }

        # Create a hashtable for performance
        $DeviceHashtable = @{}

        foreach ($Device in $Devices) {
            $DeviceHashtable[$Device.serialNumber] = $Device
        }
                
        "[{0}] List of device SNs to be assigned to the subscription: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList.serialnumber | out-string) | Write-Verbose


        foreach ($Object in $ObjectStatusList) {

            $Device = $DeviceHashtable[$Object.SerialNumber]

            "[{0}] Processing device: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Device | convertto-json -d 5 )| Write-Verbose

            if ( -not $Device) {

                # Must return a message if device not found
                $Object.Status = "Failed"
                $Object.Details = "Device cannot be found in the workspace!" 

                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource cannot be found in the workspace!" -f $Object.SerialNumber
                    Write-warning $ErrorMessage
                    continue
                }

            } 
            elseif ( $device.subscription.key ) {

                # Must return a message if device is already attached to a subscription key
                $Object.Status = "Warning"
                $Object.Details = "Device already attached to a subscription key!"

                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource is already attached to a subscription key!" -f $Object.SerialNumber
                    Write-warning $ErrorMessage
                    continue
                }

            }
            elseif (-not $device.application.name) {
        
                # Must return a message if the device is not assigned to a service
                $Object.Status = "Failed"
                $Object.Details = "Device not assigned to a service! Use first Add-HPEGLDeviceToService!"

                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource is not assigned to a service! Use first 'Add-HPEGLDeviceToService'!" -f $Object.SerialNumber
                    Write-warning $ErrorMessage
                    continue
                }
          
            }
            else {       
            
                $DeviceId = $device.id   
                
                # Building the list of device IDs object that will be assigned to the service instance
                [void]$DeviceIDsList.Add($DeviceId)
                # Add the device object to the list of devices to be assigned to the service instance
                [void]$DevicesList.Add($Object)                             
                 
            }
        }

        if ($DevicesList.Count -gt 0) {
            "[{0}] List of device IDs to be attached to the subscription key: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($DeviceIDsList | out-string) | Write-Verbose
            
            # Check to see if there is enough license available for the number of devices
            if ( [int]$subscriptionKeyFound.availableQuantity -lt [int]$DeviceIDsList.Count ) {
                $ErrorMessage = "There are not enough licenses available ({0}) in $subscriptionKey for the number of devices ({1}) to be assigned!" -f $subscriptionKeyFound.availableQuantity, $DeviceIDsList.Count
                throw $ErrorMessage
            }
            else {
                
                # Build the uri
                $_DevicesList = $DeviceIDsList -join ","
                "[{0}] List of device IDs to be attached to the subscription key: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_DevicesList | Write-Verbose

                $Uri = (Get-DevicesApplicationInstanceUri) + "?id=" + $_DevicesList

                # Build payload
                $payload = [PSCustomObject]@{ 
                    subscription = @(
                        @{
                            id = $subscriptionKeyFound.id
                        }
                    )
                } | ConvertTo-Json -Depth 5

                "[{0}] About to run a PATCH {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri | Write-Verbose
                "[{0}] Payload: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $payload | Write-Verbose
                                    
                # Attach devices to subscription key  
                try {

                    $response = Invoke-HPEGLWebRequest -Uri $Uri -method 'PATCH' -body $payload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                    
                    "[{0}] Response code: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $response.code | Write-Verbose

                    if (-not $WhatIf) {
                        switch ($response.code) {
                            202 {
                                foreach ($Object in $ObjectStatusList) {
                                    $DeviceSet = $DevicesList | Where-Object SerialNumber -eq $Object.SerialNumber
                                    if ($DeviceSet) {
                                        $Object.Status = "Complete"
                                        $Object.Details = "Device successfully assigned to the service instance!"
                                    }
                                }
                            }
                            400 {
                                $Object.Status = "Failed"
                                $Object.Details = "Bad request - Device cannot be attached to the subscription key!"
                            }
                            401 {
                                $Object.Status = "Failed"
                                $Object.Details = "Unauthorized request - Device cannot be attached to the subscription key!"
                            }
                            403 {
                                $Object.Status = "Failed"
                                $Object.Details = "The operation is forbidden - Device cannot be attached to the subscription key!"
                            }
                            422 {
                                $Object.Status = "Failed"
                                $Object.Details = "Validation error. Device cannot be attached to the subscription key!"
                            }
                            429 {
                                $Object.Status = "Failed"
                                $Object.Details = "Too many requests - Device cannot be attached to the subscription key!"
                            }
                            500 {
                                $Object.Status = "Failed"
                                $Object.Details = "Internal server error - Device cannot be attached to the subscription key!"
                            }
                            default {
                                foreach ($Object in $ObjectStatusList) {
                                    $DeviceSet = $DevicesList | Where-Object SerialNumber -eq $Object.SerialNumber
                                    if ($DeviceSet) {
                                        $Object.Status = "Failed"
                                        $Object.Details = "Device cannot be attached to the subscription key!"
                                        $Object.Exception = "HTTP Error: $($response.httpStatusCode) - $($response.message)"
                                    }
                                }
                            }
                        }
                    }
                }
                catch {

                    if (-not $WhatIf) {
                        foreach ($Object in $ObjectStatusList) {
                            $DeviceSet = $DeviceHashtable[$Object.SerialNumber]
                            If ($DeviceSet) {
                                $Object.Status = "Failed"
                                $Object.Details = "Device cannot be attached to the subscription key!"
                                $Object.Exception = $_.Exception.message 
                            }
                        }
                    }                   
                }
            }
        }
        

        if (-not $WhatIf) {

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "ObjStatus.SSDE"  
            Return $ObjectStatusList
        }
    }
}
Function Remove-HPEGLSubscriptionFromDevice {
    <#
    .SYNOPSIS
    Detach a subscription key from device(s). 

    .DESCRIPTION
    This Cmdlet detaches a license subscription key from device(s).     

    .PARAMETER DeviceSerialNumber 
    Serial number of the device to which a subscription key must be detached. This value can be retrieved from 'Get-HPEGLDevice'.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.
   
    .EXAMPLE
    Remove-HPEGLSubscriptionFromDevice -DeviceSerialNumber CNX2380BLC 

    Detach a subscription key from a device using its serial number.

    .EXAMPLE
    'CNX2380BLC', 'MXQ73200W1' | Remove-HPEGLSubscriptionFromDevice

    Detach subscription keys from devices with serial numbers 'CNX2380BLC' and 'MXQ73200W1'.

    .EXAMPLE
    Import-Csv Tests/Network_Devices.csv  |  Remove-HPEGLSubscriptionFromDevice 

    Detach subscription keys from devices listed in a csv file containing at least a SerialNumber column.

    .EXAMPLE
    Get-HPEGLdevice | Remove-HPEGLSubscriptionFromDevice 

    Detach subscription keys from all devices found in the workspace.

    .INPUTS
    System.Collections.ArrayList
        List of devices(s) from 'Get-HPEGLDevice'.
    System.String, System.String[]
        A single string object or a list of string objects that represent the device's serial numbers. 

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * SerialNumber - Serial number of the device detached from a subscription key. 
        * Status - Status of the detachment attempt (Failed for http error return; Complete if assignment is successful) 
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.

    
   #>

    [CmdletBinding()]
    Param( 
 
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [Alias('SerialNumber')]
        [ValidateNotNullOrEmpty()]
        [String]$DeviceSerialNumber,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-LicenseDevicesUri

        $ObjectStatusList = [System.Collections.ArrayList]::new()
        $DevicesList = [System.Collections.ArrayList]::new()
        $DeviceIDsList = [System.Collections.ArrayList]::new()

    }

    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Check for empty or null serial number
        if (-not $DeviceSerialNumber) {
            Write-Warning "Empty or null serial number skipped."
            continue
        }
      
        # Build object for the output
        $objStatus = [pscustomobject]@{
            SerialNumber = $DeviceSerialNumber
            Status       = $Null
            Details      = $Null
            Exception    = $Null                      
        }    

        [void] $ObjectStatusList.add($objStatus)

    }

    end {

        try {
            
            $devices = Get-HPEGLdevice 
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }
        
        # Create a hashtable for performance
        $DeviceHashtable = @{}

        foreach ($Device in $Devices) {
            $DeviceHashtable[$Device.serialNumber] = $Device
        }
        
        "[{0}] List of device SNs to be detached from the subscription key: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList.serialnumber | out-string) | Write-Verbose

        foreach ($Object in $ObjectStatusList) {

            $Device = $DeviceHashtable[$Object.SerialNumber]

            "[{0}] Processing device: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Device | convertto-json -d 20 )| Write-Verbose

            if ( -not $Device) {

                # Must return a message if device not found
                $Object.Status = "Failed"
                $Object.Details = "Device cannot be found in the workspace!" 

                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource cannot be found in the workspace!" -f $Object.SerialNumber
                    Write-warning $ErrorMessage
                    continue
                }

            } 
            elseif ( -not $device.subscription.key ) {

                # Must return a message if device is not attached to a subscription key
                $Object.Status = "Warning"
                $Object.Details = "Device is not attached to a subscription key!"

                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource is not attached to a subscription key!" -f $Object.SerialNumber
                    Write-warning $ErrorMessage
                    continue
                }

            }
            else {       
            
                $DeviceId = $device.id                 

                # Building the list of device IDs object that will be detached from the subscription key
                [void]$DeviceIDsList.Add($DeviceId)

                # Add the device object to the list of devices to be detached from the subscription key
                [void]$DevicesList.Add($Object)
                    
            }
        }

        if ($DevicesList.Count -gt 0) {

            "[{0}] List of device IDs to be detached from the subscription key: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($DeviceIDsList | out-string) | Write-Verbose
            
            # Build the uri
            $_DevicesList = $DeviceIDsList -join ","
            "[{0}] List of device IDs to be detached from the subscription key: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_DevicesList | Write-Verbose

            $Uri = (Get-DevicesApplicationInstanceUri) + "?id=" + $_DevicesList

            # # Build payload
            $payload = [PSCustomObject]@{ 
                subscription = @()
            } | ConvertTo-Json -Depth 5    
            
            "[{0}] About to run a PATCH {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri | Write-Verbose
            "[{0}] Payload: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $payload | Write-Verbose  
                                
            # Detach devices from the subscription key
            try {

                $response = Invoke-HPEGLWebRequest -Uri $Uri -method 'PATCH' -body $payload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                
                if (-not $WhatIf) {                    
                     switch ($response.code) {
                        202 {
                            foreach ($Object in $ObjectStatusList) {
                                $DeviceSet = $DevicesList | Where-Object SerialNumber -eq $Object.SerialNumber
                                if ($DeviceSet) {
                                    $Object.Status = "Complete"
                                    $Object.Details = "Device successfully detached from the subscription key!"
                                }
                            }
                        }
                        400 {
                            $Object.Status = "Failed"
                            $Object.Details = "Bad request - Device cannot be detached from the subscription key!"
                        }
                        401 {
                            $Object.Status = "Failed"
                            $Object.Details = "Unauthorized request - Device cannot be detached from the subscription key!"
                        }
                        403 {
                            $Object.Status = "Failed"
                            $Object.Details = "The operation is forbidden - Device cannot be detached from the subscription key!"
                        }
                        422 {
                            $Object.Status = "Failed"
                            $Object.Details = "Validation error. Device cannot be detached from the subscription key!"
                        }
                        429 {
                            $Object.Status = "Failed"
                            $Object.Details = "Too many requests - Device cannot be detached from the subscription key!"
                        }
                        500 {
                            $Object.Status = "Failed"
                            $Object.Details = "Internal server error - Device cannot be detached from the subscription key!"
                        }
                        default {
                            foreach ($Object in $ObjectStatusList) {
                                $DeviceSet = $DevicesList | Where-Object SerialNumber -eq $Object.SerialNumber
                                if ($DeviceSet) {
                                    $Object.Status = "Failed"
                                    $Object.Details = "Device cannot be detached from the subscription key!"
                                    $Object.Exception = "HTTP Error: $($response.httpStatusCode) - $($response.message)"
                                }
                            }
                        }
                    }
                }
            }
            catch {
                
                if (-not $WhatIf) {
                    foreach ($Object in $ObjectStatusList) {
                        # $DeviceSet = $DevicesList | Where-Object serialNumber -eq $Object.SerialNumber
                        $DeviceSet = $DeviceHashtable[$Object.SerialNumber]
                        If ($DeviceSet) {
                            $Object.Status = "Failed"
                            $Object.Details = "Device cannot be detached from the subscription key!"
                            $Object.Exception = $_.Exception.message 
                        }
                    }
                }
            }
        }
        

        if (-not $WhatIf) {

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "ObjStatus.SSDE"  
            Return $ObjectStatusList
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
Export-ModuleMember -Function `
    'Get-HPEGLSubscription', `
    'New-HPEGLSubscription', `
    'Remove-HPEGLSubscription', `
    'Get-HPEGLDeviceAutoSubscription', `
    'Set-HPEGLDeviceAutoSubscription', `
    'Remove-HPEGLDeviceAutoSubscription', `
    'Get-HPEGLDeviceAutoReassignSubscription', `
    'Set-HPEGLDeviceAutoReassignSubscription', `
    'Remove-HPEGLDeviceAutoReassignSubscription', `
    'Add-HPEGLSubscriptionToDevice', `
    'Remove-HPEGLSubscriptionFromDevice' `
    -Alias *


# SIG # Begin signature block
# MIIungYJKoZIhvcNAQcCoIIujzCCLosCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCD+tFHrv05WM0E1
# SmbIEhhq44ckBUfTQN9Kvw+vGDfzKaCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQgfGoHrdpcP1z7Z61LIP/0boRyIOfrjTCZ4Q3LWSHjNNgwDQYJKoZIhvcNAQEB
# BQAEggIAU8MwDWwidxwpC+BCbgJQcAyM66WqwLU9NnONEBsakVnPxSvbpgkKoC7I
# MM5O6o0Wnb7UONjoC5Ik/Sp2wbWRY0zNVPY2JpCp8scljimrZPKbKdpZmqbw1Cyt
# YMkvNRcK+Q3ke6fwLaX+FjvY3mmLkvHdIpHH2Uq2pA18q7yE96NJ/5fIaklhTOFc
# 1duAGB+Ly4DsXrWS9OWeF4pyrZaZSdG1tnPsPd4xcoz1wSmckiNdOEIg9CtxLNyT
# Q+TPy0g3LatQbsPMnn6j6f0fA7l/sMyXECzc7ULKwzJRiJlOM6XBSWlhYeKRGF7W
# waosvra+NIaXXhcb1OSOmyrGp7fU1LGwXkM2WUCNcUM8R7GChpYI8Twx+TXbjm0/
# qxkb3vZXNje/vAuZOxil01R3ObXly0dF8zq2dWN1t4s3AlEqVLSttR+uTK9pfrfJ
# WeHU7K2b16Ad9JzXru+ctk05Kq0pC9whVjfWXnVC8s9k8//YFIfuQgI4mZ+bTvK9
# LSuxHjAZBA8qFWmAmpmXLge+2lGqObBOMQEgQXUpx395aGga/qiuNQcX1dvqmEyh
# dD2J69ptdSqjIoAoSOKqF9BGypY9SIkWOGmL+3BIaaq5uX+gjmOeZyrbuxtdHHIX
# 1qPBSu8gj1gc/GdbEp2ERDjKLSCDnuteAJr2p5LMB9BF86ccoGehghjoMIIY5AYK
# KwYBBAGCNwMDATGCGNQwghjQBgkqhkiG9w0BBwKgghjBMIIYvQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBBwYLKoZIhvcNAQkQAQSggfcEgfQwgfECAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQwjaiDAsfpCvN17j4eKvzApih1dNOr54bYI5i+
# sxBL02rYmotorCeF79e8E9B/J1EeAhQqq51mtK7hLmRjE2TtLMHpd5703RgPMjAy
# NTEwMDIxNTUzNDFaoHakdDByMQswCQYDVQQGEwJHQjEXMBUGA1UECBMOV2VzdCBZ
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
# DxcNMjUxMDAyMTU1MzQxWjA/BgkqhkiG9w0BCQQxMgQw3D/H+kJLbqliXMCrks5z
# rkWZ5O7b6YONudIlNjLfa/RmRmmXqG5aQTzYE7A2r0wxMIIBegYLKoZIhvcNAQkQ
# AgwxggFpMIIBZTCCAWEwFgQUOMkUgRBEtNxmPpPUdEuBQYaptbEwgYcEFMauVOR4
# hvF8PVUSSIxpw0p6+cLdMG8wW6RZMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRpbWUgU3Rh
# bXBpbmcgUm9vdCBSNDYCEHojrtpTaZYPkcg+XPTH4z8wgbwEFIU9Yy2TgoJhfNCQ
# NcSR3pLBQtrHMIGjMIGOpIGLMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKTmV3
# IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBVU0VS
# VFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZpY2F0
# aW9uIEF1dGhvcml0eQIQNsKwvXwbOuejs902y8l1aDANBgkqhkiG9w0BAQEFAASC
# AgBew8OIukBUymyX4w280RET2bJ4Gad5/gXZgUw1OF/wReI2ggDuRQTDdRX/ov7s
# 4BejwQNxWfP8bi8+4R/yNsJyEDMEA+A8js5u0UcLHgr9VAXwA3bcwPdin0IuVvV3
# 7Q+jh18RT7REg9vpuOyqu7LruKzzBjBQFG3To3M4/nUHP1kW1CjwtjnbMhtd9Vri
# yDR34vbm0beBx41gPCOSS+6qs6BNAMDP6m6OUrxz7MDinQn7rF1d2X+CujND266S
# OZ+h7O3qJUTM5kyofQ8Yjk1GW39U3MMcudllW8rdzZiDK8Ktxaly0OUHuIs4PvUu
# F55NJ+jiK5jgfjSN7650y+nO3weYlUeeh8/NCl1vpXdRimbo1ktPPqFpdK1ZC8dJ
# 6gg3S2vfjSW7/YfGKSgrQHFLw0V3qrG+5PTBIY0BHp+CA87h5rk2HzWzVXpQKBAd
# JwZtOcYMYLzGFFQkNkzbG0aYBOd5fUnsi0YYLJaB3r8E2tWKWsfHZTMrwXWrlkDA
# SWeH2ZTS1erxBvMXJf2f/WL4JMuw+f/8e5mq53xpOaFxC+81zqC0a0laWZGCjWNk
# KQph8/9aK1rUgk379+ODMDM8Ohk8T/RoufRfq6qBUlkPceff+ghx9zY+qyF0iuzs
# OBChlypIlg2NjdvcKJdOv3m5yg5TsvjjvYlUbote+eFtTw==
# SIG # End signature block
