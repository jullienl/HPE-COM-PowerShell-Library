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

    .PARAMETER DryRun
    Performs a pre-claim validation check without actually adding the subscription. Returns detailed information including whether the subscription key is valid, already claimed in another workspace (with workspace name), expired, or has other issues. This is useful for troubleshooting subscription problems before making actual changes.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    New-HPEGLSubscription -SubscriptionKey 'Kxxxxxxxxxx' 

    Adds the subscription key 'Kxxxxxxxxxx'.
        
    .EXAMPLE
    New-HPEGLSubscription -SubscriptionKey 'Kxxxxxxxxxx' -DryRun

    Validates if the subscription key 'Kxxxxxxxxxx' can be added without actually adding it. Returns detailed information about the subscription including validation status, whether it's already claimed in another workspace with workspace details, expiration status, and other validation errors.
        
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
        
        [Switch]$DryRun,
        
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

        # Handle DryRun mode first before any other processing
        if ($DryRun) {
            "[{0}] Dry-run mode enabled - performing preclaim validation" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            
            $preclaimResults = @()
            
            foreach ($Object in $ObjectStatusList) {
                $subscriptionKey = $Object.SubscriptionKey
                
                try {
                    $Uri = "{0}/{1}/preclaim" -f (Get-PreclaimLicenseUri), $subscriptionKey
                    
                    "[{0}] Checking preclaim status for key: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $subscriptionKey | Write-Verbose
                    
                    $response = Invoke-HPEGLWebRequest -Uri $Uri -method 'GET' -Verbose:$VerbosePreference
                    
                    # Add subscription key to response for clarity
                    $response | Add-Member -NotePropertyName 'subscriptionKey' -NotePropertyValue $subscriptionKey -Force
                    $response | Add-Member -NotePropertyName 'canBeClaimed' -NotePropertyValue $true -Force
                    
                    $preclaimResults += $response
                    
                }
                catch {
                    # Extract detailed error information from the API response
                    "[{0}] Preclaim validation error for key {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $subscriptionKey | Write-Verbose
                    
                    # Try to get structured error data from Global variable set by Invoke-HPEGLWebRequest
                    $errorData = $Global:HPECOMInvokeReturnData
                    
                    # Try to extract workspace information from rawError if available
                    $errorMessage = $_.Exception.Message
                    $workspaceId = $null
                    $workspaceName = $null
                    $fullMessage = $null
                    
                    # Check if rawError contains the full error JSON
                    if ($errorData.rawError -and $errorData.rawError -match '"workspaceId":\s*"([^"]+)"') {
                        $workspaceId = $Matches[1]
                    }
                    if ($errorData.rawError -and $errorData.rawError -match '"workspaceName":\s*"([^"]+)"') {
                        $workspaceName = $Matches[1]
                    }
                    if ($errorData.rawError -and $errorData.rawError -match '"message":\s*"([^"]+)"') {
                        $fullMessage = $Matches[1]
                    }
                    
                    # Build structured error result
                    $errorResult = [PSCustomObject]@{
                        subscriptionKey = $subscriptionKey
                        canBeClaimed = $false
                        errorCode = if ($errorData.errorCode) { $errorData.errorCode } else { 'UNKNOWN' }
                        message = if ($fullMessage) { $fullMessage } else { $errorMessage }
                        httpStatusCode = if ($errorData.httpStatusCode) { $errorData.httpStatusCode } else { '400' }
                        workspaceId = $workspaceId
                        workspaceName = $workspaceName
                    }
                    
                    $preclaimResults += $errorResult
                }
            }
            
            # Add TypeName for custom formatting and return results
            $preclaimResults = Invoke-RepackageObjectWithType -RawObject $preclaimResults -ObjectName "License.Preclaim"
            return $preclaimResults
        }

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

                    "[{0}] Subscription '{1}' already exists in the workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Object.SubscriptionKey | Write-Verbose

                    if ($WhatIf) {
                        $ErrorMessage = "Subscription '{0}': Resource already exists in the workspace! No action needed." -f $Object.SubscriptionKey
                        Write-warning $ErrorMessage
                        return
                    }
                    else {
                        $Object.Status = "Warning"
                        $Object.Details = "Subscription already exists in the workspace! No action needed."
                    }
                   
                }
                else {
                    # Perform preclaim validation before adding
                    "[{0}] Performing preclaim validation for key: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Object.SubscriptionKey | Write-Verbose
                    
                    try {
                        $preclaimUri = "{0}/{1}/preclaim" -f (Get-PreclaimLicenseUri), $Object.SubscriptionKey
                        $preclaimResponse = Invoke-HPEGLWebRequest -Uri $preclaimUri -method 'GET' -Verbose:$VerbosePreference
                        
                        "[{0}] Preclaim validation passed for key: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Object.SubscriptionKey | Write-Verbose
                        
                        if ($WhatIf) {
                            # For WhatIf, show what would be added with validation details
                            $whatIfMessage = "What if: Performing the operation `"Add Subscription`" on target `"{0}`"" -f $Object.SubscriptionKey
                            if ($preclaimResponse.claim_status) {
                                $whatIfMessage += "`n  Claim Status: {0}" -f $preclaimResponse.claim_status
                            }
                            if ($preclaimResponse.tier) {
                                $whatIfMessage += "`n  Tier: {0}" -f $preclaimResponse.tier
                            }
                            Write-Host $whatIfMessage
                        }
                        else {
                            # Add to list for actual addition
                            $Uri = Get-SubscriptionsUri

                            # Build Key object for payload
                            $Key = [PSCustomObject]@{
                                key = $Object.SubscriptionKey
                            }
                            
                            # Building the list of keys object for payload
                            [void]$SubscriptionKeysList.Add($Key)
                        }
                    }
                    catch {
                        # Preclaim validation failed - extract error details
                        "[{0}] Preclaim validation failed for key: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Object.SubscriptionKey | Write-Verbose
                        
                        $errorData = $Global:HPECOMInvokeReturnData
                        $workspaceId = $null
                        $workspaceName = $null
                        $fullMessage = $null
                        
                        # Extract workspace ID, name and message from error
                        if ($errorData.rawError -and $errorData.rawError -match '"workspaceId":\s*"([^"]+)"') {
                            $workspaceId = $Matches[1]
                        }
                        if ($errorData.rawError -and $errorData.rawError -match '"workspaceName":\s*"([^"]+)"') {
                            $workspaceName = $Matches[1]
                        }
                        if ($errorData.rawError -and $errorData.rawError -match '"message":\s*"([^"]+)"') {
                            $fullMessage = $Matches[1]
                        }
                        
                        # Replace workspace ID with workspace name in message if available
                        if ($fullMessage -and $workspaceId -and $workspaceName) {
                            $fullMessage = $fullMessage -replace $workspaceId, "'$workspaceName'"
                        }
                        
                        if ($WhatIf) {
                            $ErrorMessage = "Subscription '{0}': Preclaim validation failed. {1}" -f $Object.SubscriptionKey, ($fullMessage -replace '\\s+', ' ')
                            Write-Warning $ErrorMessage
                        }
                        else {
                            $Object.Status = "Failed"
                            if ($workspaceName) {
                                $Object.Details = "Subscription cannot be added - already claimed in workspace '{0}'" -f $workspaceName
                            }
                            else {
                                $Object.Details = if ($fullMessage) { $fullMessage } else { "Subscription validation failed" }
                            }
                            $Object.Exception = $_.Exception.Message
                        }
                    }
                }
            }


            if ($SubscriptionKeysList -and -not $WhatIf) {
                
                # Build payload
                $payload = ConvertTo-Json -Depth 10 @{
                    subscriptions = @($SubscriptionKeysList)
                } 
                
                # Add subscription keys
                try {
                
                    $response = Invoke-HPEGLWebRequest -Uri $Uri -method 'POST' -body $payload -ContentType "application/json" -Verbose:$VerbosePreference    

                    foreach ($Object in $ObjectStatusList) {

                        if ($Object.Status -ne "Warning" -and $Object.Status -ne "Failed") {
                            
                            $Object.Status = "Complete"
                            $Object.Details = "Service subscription successfully added to the HPE GreenLake platform"
                            $Object.Exception = $_.Exception.message 
                        }
                    }
                    
                }
                catch {

                    foreach ($Object in $ObjectStatusList) {
                            
                        if ($Object.Status -ne "Warning" -and $Object.Status -ne "Failed") {
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
    
    Note: If no auto-subscription settings have been configured yet, this cmdlet returns no output. 
    Use Set-HPEGLDeviceAutoSubscription to configure automatic subscription settings for device types.
    
    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Get-HPEGLDeviceAutoSubscription

    Returns the automatic subscription status of device(s) in the HPE GreenLake workspace.
    If no settings have been configured, no output is returned.
    
   #>

    [CmdletBinding()]
    Param( 
        [Switch]$WhatIf   
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-AutoSubscriptionSettingsUri
        
    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $ReturnData = @()
        
        # Step 1: Get all auto-subscription settings to retrieve the settings ID
        try {
            $Collection = Invoke-HPEGLWebRequest -Method GET -Uri $Uri -WhatIfBoolean $WhatIf -SkipPaginationLimit -ReturnFullObject -Verbose:$VerbosePreference
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
  
        
        if ($Null -ne $Collection.items) {

            # Get the settings ID from the collection
            $settingsId = $null
            if ($Collection.items -is [array] -and $Collection.items.Count -gt 0) {
                $settingsId = $Collection.items[0].id
            }
            elseif ($Collection.items.id) {
                # items is a single object
                $settingsId = $Collection.items.id
            }

            if ($settingsId) {
                "[{0}] Found settings record with ID: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $settingsId | Write-Verbose

                # Step 2: Get the detailed settings using the ID
                try {
                    $DetailedUri = "$Uri/$settingsId"
                    "[{0}] Retrieving detailed settings from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DetailedUri | Write-Verbose
                    $DetailedSettings = Invoke-HPEGLWebRequest -Method GET -Uri $DetailedUri -WhatIfBoolean $WhatIf -SkipPaginationLimit -ReturnFullObject -Verbose:$VerbosePreference
                    
                    if ($DetailedSettings.autoSubscriptionSettings) {
                        # Handle both array and single object responses
                        $settingsArray = @()
                        if ($DetailedSettings.autoSubscriptionSettings -is [array]) {
                            $settingsArray = $DetailedSettings.autoSubscriptionSettings
                        }
                        else {
                            # Single object - wrap in array
                            $settingsArray = @($DetailedSettings.autoSubscriptionSettings)
                        }
                        
                        # Transform new API properties to old format for compatibility
                        $transformedSettings = @()
                        foreach ($setting in $settingsArray) {
                            $transformedSetting = [PSCustomObject]@{
                                device_type = $setting.deviceType
                                enabled = $true  # If settings exist, they're enabled
                                auto_license_subscription_tier_description = $setting.tier
                            }
                            $transformedSettings += $transformedSetting
                        }
                        
                        $ReturnData = Invoke-RepackageObjectWithType -RawObject $transformedSettings -ObjectName "License.AutoSubscribe"    
                        $ReturnData = $ReturnData | Sort-Object { $_.device_type }
                        return $ReturnData
                    }
                    else {
                        "[{0}] No auto-subscription settings configured for this workspace. Use Set-HPEGLDeviceAutoSubscription to configure automatic subscription settings." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                        return
                    }
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }
            else {
                "[{0}] No settings ID found in response" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                return
            }
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

        $AutoSubscriptionStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Get existing settings first to retrieve the ID
        try {
            $BaseUri = Get-AutoSubscriptionSettingsUri
            
            $settingsResponse = Invoke-HPEGLWebRequest -Method GET -Uri $BaseUri -WhatIfBoolean $false -SkipPaginationLimit -ReturnFullObject -Verbose:$VerbosePreference
            
            if ($settingsResponse.items -and $settingsResponse.items.Count -gt 0) {
                $settingsId = $settingsResponse.items[0].id
                $Uri = "$BaseUri/$settingsId"
                "[{0}] Found existing settings with ID: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $settingsId | Write-Verbose
            }
            else {
                throw "No auto-subscription settings found for this workspace. Settings record may not exist yet."
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
      
        if ($AccessPointSubscriptionTier -eq 'FOUNDATION' ) {
            $Tier = "FOUNDATION_AP"
            $DeviceType = "AP"
        }
        elseif ($AccessPointSubscriptionTier -eq 'ADVANCED' ) {
            $Tier = "ADVANCED_AP"
            $DeviceType = "AP"
        }


        if ($GatewaySubscriptionTier -eq 'FOUNDATION' ) {
            $Tier = "FOUNDATION_GW"
            $DeviceType = "GATEWAY"

        }
        elseif ($GatewaySubscriptionTier -eq 'ADVANCED' ) {
            $Tier = "ADVANCED_GW"
            $DeviceType = "GATEWAY"

        }


        if ($ComputeSubscriptionTier -eq 'STANDARD' ) {
            $Tier = "STANDARD_COMPUTE"
            $DeviceType = "COMPUTE"

        }
        elseif ($ComputeSubscriptionTier -eq 'ENHANCED' ) {
            $Tier = "ENHANCED_COMPUTE"
            $DeviceType = "COMPUTE"

        }


        if ($SwitchSubscriptionTier -eq 'FOUNDATION' ) {
            $Tier = "FOUNDATION_SWITCH"
            $DeviceType = "SWITCH"

        }
        elseif ($SwitchSubscriptionTier -eq 'ADVANCED' ) {
            $Tier = "ADVANCED_SWITCH"
            $DeviceType = "SWITCH"

        }


        if ($SensorSubscriptionTier -eq 'FOUNDATION' ) {
            $Tier = "FOUNDATION_SENSOR"
            $DeviceType = "SENSOR"

        }
       

        # Build object for the output
        $objStatus = [pscustomobject]@{
 
            DeviceType = $DeviceType
            Status     = $Null
            Details    = $Null
            Exception  = $Null
                 
        }


        # Build payload for PATCH request with new API format
        $payload = ConvertTo-Json @{
            autoSubscriptionSettings = @(
                @{
                    deviceType = $DeviceType
                    tier       = $Tier
                }
            )
        } -Depth 5
  

        try {
            Invoke-HPEGLWebRequest -Uri $Uri -method 'PATCH' -body $payload -ContentType 'application/merge-patch+json' -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    | Out-Null
               
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

    Automatic subscription reassignment is a feature to switch the device when a subscription expires to another subscription of the same type preventing disruptions.
    
    If no settings have been configured yet, this cmdlet returns no output. Use Set-HPEGLDeviceAutoReassignSubscription to configure settings.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Get-HPEGLDeviceAutoReassignSubscription

    Returns the automatic subscription reassignment status of device(s) in the HPE GreenLake workspace.
    If no settings have been configured, no output is returned.
    
   #>

    [CmdletBinding()]
    Param( 
        [Switch]$WhatIf   
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-AutoReassignmentSettingsUri

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $ReturnData = @()
        
        try {
            $Collection = Invoke-HPEGLWebRequest -Method GET -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
  
        
        if ($Collection.renewalSettingsList) {
            
            # Transform to add friendly device names
            $transformedSettings = @()
            foreach ($setting in $Collection.renewalSettingsList) {
                $deviceName = switch ($setting.deviceType) {
                    'AP' { "Access Points" }
                    'SWITCH' { "Switches" }
                    'GATEWAY' { "Gateways" }
                    'COMPUTE' { "Compute" }
                    'SD_WAN_GW' { "SD-WAN Gateways" }
                    'SENSOR' { "Sensors" }
                    'BRIDGE' { "Bridge" }
                    'EC_V' { "Edge Compute Virtual" }
                    default { $setting.deviceType }
                }
                
                $transformedSetting = [PSCustomObject]@{
                    deviceType = $setting.deviceType
                    deviceName = $deviceName
                    enabled = $setting.enabled
                }
                $transformedSettings += $transformedSetting
            }
            
            $ReturnData = Invoke-RepackageObjectWithType -RawObject $transformedSettings -ObjectName "License.AutoReassign"    
            $ReturnData = $ReturnData | Sort-Object { $_.deviceType }
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
    
    Automatic subscription reassignment is a feature that switches a device to another subscription of the same type when the current subscription expires, preventing service disruptions.
    
    Note: Auto-reassignment is enabled by default for all device types in HPE GreenLake. This cmdlet is used to re-enable auto-reassignment if it has been previously disabled using Remove-HPEGLDeviceAutoReassignSubscription.

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

        $AutoReassignmentStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $Uri = Get-AutoReassignmentSettingsUri

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

        # Remove PSObject.TypeNames and deviceName properties
        $CleanedSettings = $ExistingSettings | Select-Object -Property deviceType, enabled

        # Build payload
        $payload = ConvertTo-Json @{ 
            renewalSettingsList = $CleanedSettings
        } -Depth 5
              

        try {
            Invoke-HPEGLWebRequest -Uri $Uri -Method PATCH -Body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | Out-Null
               
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
# MIIunwYJKoZIhvcNAQcCoIIukDCCLowCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB+g6hh7FTGbnZt
# z5KgLtuMtMk6YRy/XvkZ8V0HWi0GcqCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQg8SKPxxRAcpFqKJoO5UVL46RXVpn6Z0/wExY1NzugGP0wDQYJKoZIhvcNAQEB
# BQAEggIALGZWWme3J7ezm/70vofTXxrjB8QbxY8wcaXdgqaEUD5M1nzxwkR+ZxTB
# IacjdtTmzoLUchN9B61bQBj2C5+QEp3LtG4GOJ6jbWh+VvUtYZtaKqMbIeevSYip
# 1TVd8ynjXndJ2CQcuuk7VyaGWMCS6GSJOprXJO1pMSbY/Ypa0UKOFXK2hXcyBHss
# X29cH+ijdEKqAZp4gOP5ud6XUJ1+Kmg77BEPgfo/rVr9PPtXFw71IVJM61PAev8J
# cNDbJnhOdo/ueUoBNamWN2mXYTq9ZBQu/HncBseph1nfekFgdTuyOHmTArHeBGro
# 5Yv5z9YuRXQQv95Qbl1r+GbnjDJf3te37rS/1NpCY8axf2bfPI4sPrH2zj8VMOag
# xqbECkgdOickaSUK8iEVe+Po0SCCztwGpypt6FH8qNABDEkj1SH1Zh4hA8aDe6QB
# 9cL+nGr41DtUXmwQA6zc1Pf0VLjZMDSV1nwHbXLxJm5Fw2wYH7PBfYuPun4i1qL5
# aZ8HvogKdmoR06A2xajIfx0EGLpS3M2qIsh+obhUGc/UnPwyRp4T5KOi1uMa66/+
# P9hyyMmFmx8sUQ8au1u/yj8E13mGCKeGWo0OsaFJw20chjbu9Vi+1NvKyNfvz0hJ
# IapedfKJprcst5zQGqR097HrR7A/ag9jAaQEDyNEE1MlfIv4fVahghjpMIIY5QYK
# KwYBBAGCNwMDATGCGNUwghjRBgkqhkiG9w0BBwKgghjCMIIYvgIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBCAYLKoZIhvcNAQkQAQSggfgEgfUwgfICAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQwyNTNMKD//OW9a/lnighAW9wshHOKzrIzueIy
# njAtzne4bxgDqYjobuIpkZUM1zUlAhUAkan5r6FfySinnwKmBOngpLzCPCYYDzIw
# MjYwMTE5MTgyNDQ1WqB2pHQwcjELMAkGA1UEBhMCR0IxFzAVBgNVBAgTDldlc3Qg
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
# MQ8XDTI2MDExOTE4MjQ0NVowPwYJKoZIhvcNAQkEMTIEMDcN1JeOv/BPT6fX4Tps
# 8yD6Gy7jrXkq38zdZOpKPg+GikePsKHy+Il39znUyNmT4zCCAXoGCyqGSIb3DQEJ
# EAIMMYIBaTCCAWUwggFhMBYEFDjJFIEQRLTcZj6T1HRLgUGGqbWxMIGHBBTGrlTk
# eIbxfD1VEkiMacNKevnC3TBvMFukWTBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMP
# U2VjdGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBUaW1lIFN0
# YW1waW5nIFJvb3QgUjQ2AhB6I67aU2mWD5HIPlz0x+M/MIG8BBSFPWMtk4KCYXzQ
# kDXEkd6SwULaxzCBozCBjqSBizCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5l
# dyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNF
# UlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNh
# dGlvbiBBdXRob3JpdHkCEDbCsL18Gzrno7PdNsvJdWgwDQYJKoZIhvcNAQEBBQAE
# ggIAe83vnSQLn3MUyvsalBqgGFx3U0W1yhMPBNJwHjhphmKZnIweOQnk5s1JCtio
# nZstR8/KE3pVRp4mv6CG/MYTHjdAG4g1QYXXIebC+WSAFBID0gTWM9PBS7LbJp7r
# SfZ2U96ZcfKP5qOMPiCiwvYMnCaNCiZZJppoZ2S00rBwJRsNnFbzrypDdC7IPw8q
# qs79w5CiBs6Hw0FCc8L4Br5KZ5DlkfjodhcdD9hCxCOyogp1aiPSGNJvr11MYaV/
# 7hNuqlxUTc6jX5kfUCFSqwxHqp8RJHaNcaIBmV3UkhM9DKxIwo9t80vng4+Dr149
# 8BgRnEQsDh5VUrfQRUoTpkAazWs32z47ZFgU+3k+9kD5i3asP+KZvZlcllQdjnfX
# TEsRqqpZK/ANO3IwIJEukLlKUDw4H1c4y6gL97/xlUr8MdOtLAztxygtOXGFWlov
# O37LN0AainIO8ALaUhNVXK9iUBymHU9sl8OJ3YahuYn49IdQBci1/rzQ82YdDbYc
# NpdnrMfY7G6jF0XgDA4TY6wd9bAB+C9Jki5VGx0noyMnBk7mgYfWlmEO6hurBDnh
# RjjfE2751n6tVM2poFDm6SPERNJvlVngMIBNY491ghQZCJj7LMQp0b2fgJRjP53L
# Vl0AVjL+Y/nWWJlPI77PPOX1u6Rrcnhow+PX88Hjx7aAqco=
# SIG # End signature block
