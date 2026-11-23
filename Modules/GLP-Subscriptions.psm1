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
        [ValidateNotNullOrEmpty()]
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
        [ValidateNotNullOrEmpty()]
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
                    
                    # Set canBeClaimed based on actual claim_status from API
                    $canClaim = $response.claim_status -eq "NOT_CLAIMED"
                    $response | Add-Member -NotePropertyName 'canBeClaimed' -NotePropertyValue $canClaim -Force
                    
                    # Initialize workspaceId and workspaceName as empty (will be populated if subscription is claimed)
                    $response | Add-Member -NotePropertyName 'workspaceId' -NotePropertyValue $null -Force
                    $response | Add-Member -NotePropertyName 'workspaceName' -NotePropertyValue $null -Force
                    
                    # If already claimed, check if it's in current workspace or elsewhere
                    if ($response.claim_status -eq "CLAIMED") {
                        "[{0}] Subscription already claimed - checking workspace location" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                        
                        # First check if subscription exists in current workspace
                        try {
                            $existingSubscription = Get-HPEGLSubscription -SubscriptionKey $subscriptionKey -ErrorAction SilentlyContinue
                            
                            if ($existingSubscription) {
                                # Subscription is in current workspace
                                "[{0}] Subscription found in current workspace: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Global:HPEGreenLakeSession.workspace | Write-Verbose
                                $response | Add-Member -NotePropertyName 'workspaceName' -NotePropertyValue $Global:HPEGreenLakeSession.workspace -Force
                            }
                            else {
                                # Subscription claimed elsewhere - attempt claim to get workspace from error
                                "[{0}] Subscription not in current workspace - attempting claim to retrieve workspace details" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                
                                try {
                                    $claimUri = Get-SubscriptionsUri
                                    $claimPayload = ConvertTo-Json -Depth 10 @{ subscriptions = @(@{ key = $subscriptionKey }) }
                                    Invoke-HPEGLWebRequest -Uri $claimUri -method 'POST' -body $claimPayload -ContentType "application/json" -Verbose:$VerbosePreference | Out-Null
                                }
                                catch {
                                    # Expected to fail - extract workspace info from error
                                    $errorData = $Global:HPECOMInvokeReturnData
                                    $workspaceId = $null
                                    
                                    # Try to extract from exception raw content
                                    $rawContent = $_.Exception.Message
                                    if ($_.ErrorDetails.Message) {
                                        $rawContent = $_.ErrorDetails.Message
                                    }
                                    
                                    # Parse workspaceId and workspaceName from errorDetails metadata
                                    if ($rawContent -match '"workspaceId":\s*"([^"]+)"') {
                                        $workspaceId = $Matches[1]
                                        $response | Add-Member -NotePropertyName 'workspaceId' -NotePropertyValue $workspaceId -Force
                                    }
                                    
                                    if ($rawContent -match '"workspaceName":\s*"([^"]+)"') {
                                        $response | Add-Member -NotePropertyName 'workspaceName' -NotePropertyValue $Matches[1] -Force
                                    }
                                    elseif ($workspaceId) {
                                        # Fallback: Try to get workspace name from workspace list if not in error
                                        try {
                                            $allWorkspaces = Get-HPEGLWorkspace -ErrorAction SilentlyContinue
                                            $targetWorkspace = $allWorkspaces | Where-Object { $_.id -eq $workspaceId }
                                            if ($targetWorkspace) {
                                                $response | Add-Member -NotePropertyName 'workspaceName' -NotePropertyValue $targetWorkspace.name -Force
                                            }
                                        }
                                        catch {
                                            "[{0}] Could not retrieve workspace name for ID: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $workspaceId | Write-Verbose
                                        }
                                    }
                                    
                                    # Fallback: try old regex patterns
                                    if (-not $workspaceId -and $errorData.rawError) {
                                        if ($errorData.rawError -match '"workspaceName":\s*"([^"]+)"') {
                                            $response | Add-Member -NotePropertyName 'workspaceName' -NotePropertyValue $Matches[1] -Force
                                        }
                                        if ($errorData.rawError -match '"workspaceId":\s*"([^"]+)"') {
                                            $response | Add-Member -NotePropertyName 'workspaceId' -NotePropertyValue $Matches[1] -Force
                                        }
                                    }
                                }
                            }
                        }
                        catch {
                            "[{0}] Error checking subscription in current workspace: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                        }
                    }
                    
                    $preclaimResults += $response
                    
                }
                catch {
                    # Extract detailed error information from the API response
                    "[{0}] Preclaim validation error for key {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $subscriptionKey | Write-Verbose
                    
                    # Try to get structured error data from Global variable set by Invoke-HPEGLWebRequest
                    $errorData = $Global:HPECOMInvokeReturnData
                    
                    # Extract workspace information
                    $workspaceId = $null
                    $workspaceName = $null
                    $fullMessage = if ($errorData.message) { $errorData.message } else { $_.Exception.Message }
                    
                    # Extract from errorData.errorDetails.metadata
                    if ($errorData.errorDetails -and $errorData.errorDetails.Count -gt 0) {
                        foreach ($detail in $errorData.errorDetails) {
                            if ($detail.metadata) {
                                if ($detail.metadata.workspaceId) {
                                    $workspaceId = $detail.metadata.workspaceId
                                    "[{0}] Extracted workspaceId: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $workspaceId | Write-Verbose
                                }
                                if ($detail.metadata.workspaceName) {
                                    $workspaceName = $detail.metadata.workspaceName
                                    "[{0}] Extracted workspaceName: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $workspaceName | Write-Verbose
                                }
                            }
                        }
                    }
                    
                    # If we have workspaceId but no workspaceName, look it up
                    if ($workspaceId -and -not $workspaceName) {
                        "[{0}] workspaceName not available, looking up workspace ID: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $workspaceId | Write-Verbose
                        try {
                            $allWorkspaces = Get-HPEGLWorkspace -ErrorAction SilentlyContinue
                            "[{0}] Get-HPEGLWorkspace returned {1} workspace(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $(if ($allWorkspaces) { $allWorkspaces.Count } else { 0 }) | Write-Verbose
                            
                            if ($allWorkspaces) {
                                "[{0}] Searching for workspace ID: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $workspaceId | Write-Verbose
                                "[{0}] Available workspace IDs: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), (($allWorkspaces.platform_customer_id | Select-Object -First 5) -join ', ') | Write-Verbose
                                
                                $targetWorkspace = $allWorkspaces | Where-Object { $_.platform_customer_id -eq $workspaceId }
                                if ($targetWorkspace) {
                                    $workspaceName = $targetWorkspace.company_name
                                    "[{0}] Found workspace name: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $workspaceName | Write-Verbose
                                }
                                else {
                                    "[{0}] Workspace ID {1} not found in workspace list" -f $MyInvocation.InvocationName.ToString().ToUpper(), $workspaceId | Write-Verbose
                                }
                            }
                            else {
                                "[{0}] Get-HPEGLWorkspace returned no workspaces" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            }
                        }
                        catch {
                            "[{0}] Error during workspace lookup: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                        }
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
            if ($WhatIf) {
                Write-Warning "Maximum of 5 subscriptions per request is allowed! Cannot display API request."
                return
            }
            foreach ($Object in $ObjectStatusList) {
                $Object.Status = "Warning"
                $Object.Details = "Maximum of 5 subscriptions per request is allowed!"
            }
            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "License.SSDE"
            Return $ObjectStatusList
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
                        Write-Warning "$ErrorMessage Cannot display API request."
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
                            $ErrorMessage = "Subscription '{0}': Preclaim validation failed. {1}." -f $Object.SubscriptionKey, ($fullMessage -replace '\\s+', ' ')
                            Write-Warning "$ErrorMessage Cannot display API request."
                        }
                        else {
                            $Object.Status = "Failed"
                            if ($workspaceName) {
                                $Object.Details = "Subscription cannot be added - already claimed in workspace '{0}'" -f $workspaceName
                            }
                            else {
                                $Object.Details = if ($fullMessage) { $fullMessage } else { "Subscription validation failed" }
                            }
                            $Object.Exception = $Global:HPECOMInvokeReturnData
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
                        }
                    }
                    
                }
                catch {

                    foreach ($Object in $ObjectStatusList) {
                            
                        if ($Object.Status -ne "Warning" -and $Object.Status -ne "Failed") {
                            $Object.Status = "Failed"
                            $Object.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Service subscription was not added to the HPE GreenLake platform" }
                            $Object.Exception = $Global:HPECOMInvokeReturnData 
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
        [ValidateNotNullOrEmpty()]
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
                Write-Warning "$ErrorMessage Cannot display API request."
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
                Write-Warning "$ErrorMessage Cannot display API request."
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
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Failed to remove the device subscription from the workspace." }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                }
            
            }   
        } 

        if (-not $WhatIf) {
            [void] $RemoveSubscriptionStatus.add($objStatus)
        }

  
    }
    end {

        if ($RemoveSubscriptionStatus.Count -gt 0) {

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
                        if (-not $WhatIf) {
                            Write-Warning "No auto-subscription settings are configured for this workspace. Use Set-HPEGLDeviceAutoSubscription to configure automatic subscription settings."
                        }
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
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Automatic assignment of subscriptions to '$DeviceType' cannot be set!" }
                $objStatus.Exception = $Global:HPECOMInvokeReturnData 
            }
        }
        

        if (-not $WhatIf) {
            [void] $AutoSubscriptionStatus.add($objStatus)
        }
    }

    end {

        if ($AutoSubscriptionStatus.Count -gt 0) {

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
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Automatic assignment of subscriptions to '$DeviceType' cannot be set!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                }
            }
        }
        else {

            if ($WhatIf) {
                $ErrorMessage = "Automatic subscription cannot be found for '$DeviceType'!"
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "Automatic subscription cannot be found!"
            }
           
        }

        if (-not $WhatIf) {
            [void] $AutoSubscriptionStatus.add($objStatus)
        }

    }

    end {

        if ($AutoSubscriptionStatus.Count -gt 0) {

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
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Automatic reassignment of subscriptions cannot be set!" }
                $objStatus.Exception = $Global:HPECOMInvokeReturnData 
            }
        }
        

        if (-not $WhatIf) {
            [void] $AutoReassignmentStatus.add($objStatus)
        }
    }

    end {

        if ($AutoReassignmentStatus.Count -gt 0) {

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
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Automatic reassignment of subscriptions cannot be disabled!" }
                $objStatus.Exception = $Global:HPECOMInvokeReturnData 
            }
        }
        

        if (-not $WhatIf) {
            [void] $AutoReassignmentStatus.add($objStatus)
        }
    }

    end {

        if ($AutoReassignmentStatus.Count -gt 0) {

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
                $Object.Status = "Warning"
                $Object.Details = "Device cannot be found in the workspace!" 

                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource cannot be found in the workspace!" -f $Object.SerialNumber
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }

            } 
            elseif ( $device.subscription.key ) {

                # Must return a message if device is already attached to a subscription key
                $Object.Status = "Warning"
                $Object.Details = "Device already attached to a subscription key!"

                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource is already attached to a subscription key!" -f $Object.SerialNumber
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }

            }
            elseif (-not $device.application.name) {
        
                # Must return a message if the device is not assigned to a service
                $Object.Status = "Warning"
                $Object.Details = "Device not assigned to a service! Use first Add-HPEGLDeviceToService!"

                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource is not assigned to a service! Use first 'Add-HPEGLDeviceToService'!" -f $Object.SerialNumber
                    Write-Warning "$ErrorMessage Cannot display API request."
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
                                        $Object.Exception = $Global:HPECOMInvokeReturnData
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
                                $Object.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Device cannot be attached to the subscription key!" }
                                $Object.Exception = $Global:HPECOMInvokeReturnData 
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
                $Object.Status = "Warning"
                $Object.Details = "Device cannot be found in the workspace!" 

                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource cannot be found in the workspace!" -f $Object.SerialNumber
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }

            } 
            elseif ( -not $device.subscription.key ) {

                # Must return a message if device is not attached to a subscription key
                $Object.Status = "Warning"
                $Object.Details = "Device is not attached to a subscription key!"

                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource is not attached to a subscription key!" -f $Object.SerialNumber
                    Write-Warning "$ErrorMessage Cannot display API request."
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
                                    $Object.Exception = $Global:HPECOMInvokeReturnData
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
                            $Object.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Device cannot be detached from the subscription key!" }
                            $Object.Exception = $Global:HPECOMInvokeReturnData 
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
# MIIn2gYJKoZIhvcNAQcCoIInyzCCJ8cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDQGhvkrmtLNSfH
# uVXQablR4qEX5gpEZN764XO5JZw3mqCCDIMwggYaMIIEAqADAgECAhBiHW0MUgGe
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
# A+rbZZyGZkz3xbUYKTGCGq0wghqpAgEBMGkwVDELMAkGA1UEBhMCR0IxGDAWBgNV
# BAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMgQ29k
# ZSBTaWduaW5nIENBIFIzNgIRAMgx4fswkMFDciVfUuoKqr0wDQYJYIZIAWUDBAIB
# BQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIB
# BDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg
# 5Ccz9pvg4EqaSyDl7Knz41qXyBTDYctoajFg0VvLSecwDQYJKoZIhvcNAQEBBQAE
# ggIAM1OAIQA0L6NMM818D3g5CrEc7Hhb79uphDSS7SmMzlE+xjIr0lVi4PbTwWsb
# 1cWtj+skiy25ffSOmme7rVztAVffmGdKz1FvFfRoSzG3163TfEF6vDFnjmgk0HnY
# nP0s0ZL92ZBgqI/l9IiJHKscufFg/Dk2CLGLlyc1zod2NjbD5Z63IBDksgG/6SA0
# QwMBU+nMf722SRdkYOGpWvWb8y5nLML7jr7RR9KM707p0gx6MJAU3Ew+ipSZVXcu
# pqpkT8dEsmCrAuFpqVhzsLvT4HcVc2TTe5IVc5fhXrV9w44ljpbCmZ6lRclVUY83
# wc15tBEqf6TDiE6jSYqNfSYlewpZn+suUHmPKgQZUvm1UuYFa0v+ck7dh8bH9bdG
# Dfdw5XDkulRa+au+Gfer45pFSN+5LWuCtKnFcXt2PGwykadEZicus3noRjbQFDi3
# H6ZcxZ39FrbDvlFjxiKKCqgU2+IBt8kjjAP0qMaNcstOCc0OWb/N35RsVL33Qyli
# BVf1JDCkx3c6FrtaMiRVIkadIhVwBP3Cm4nKXynjwiAvnZHa2TvFGwUd7Usybe72
# fvihmvLVlg6AR5wF3nqPMIBZGJ1KFKPu8OGY2mGOeHMvtq5tgVPOGl04/eih9+T4
# 74rwCS/lYRGd9EFjxDyN0MRbYF1KrP9JcpMDiCtyA/5k0RChgheXMIIXkwYKKwYB
# BAGCNwMDATGCF4Mwghd/BgkqhkiG9w0BBwKgghdwMIIXbAIBAzEPMA0GCWCGSAFl
# AwQCAgUAMIGHBgsqhkiG9w0BCRABBKB4BHYwdAIBAQYJYIZIAYb9bAcBMEEwDQYJ
# YIZIAWUDBAICBQAEMHZodfxI1P17tQgRvzahVIu75xmk7DhFy8ILIjLd5ana34F+
# 9f76dKcOp7cnouYlnwIQGrCuaVEvA2VFZ2AzZJ9BLBgPMjAyNjExMjMwODQyMDla
# oIITOjCCBu0wggTVoAMCAQICEA4euzIrXIp1PhI/Ic7Q8tkwDQYJKoZIhvcNAQEM
# BQAwaTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYD
# VQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2IFNI
# QTI1NiAyMDI1IENBMTAeFw0yNjA4MDUwMDAwMDBaFw0zNzExMDQyMzU5NTlaMGMx
# CzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMy
# RGlnaUNlcnQgU0hBMzg0IFJTQTQwOTYgVGltZXN0YW1wIFJlc3BvbmRlciAyMDI2
# IDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDGzb2TVObgnNpRsbsm
# C4sUxF6ibiz7n2oKTHqpIcDpFLue7BsPlDPjLxlp0a8qe6LqReZneD2FUX0fpWg3
# QFscsFDtCz4JZJ2YephpY0c50LM0KUwUQVNXwDJs5MI8T/HFS41bSefLLKWSVY/p
# +ZTN6K0mPstoOpxlrWflIrIKqv7DDIS4BYL3YT71oqYz1kfbpw6TeOVzol27pLfz
# PzHfuoP6nXkaZHz+3tbu7HaoiyyqbuNrNJu6mdUPyPmUPpzIKudi0Ye6i7tsfdzn
# 0VtFIw6gvSwNnPTUnztvWrvpD8rqNS4q7tQKXuBBuMlSYtoa4j/k2FRk7xWlkMq6
# WnIeNXbmFjGxYMwrk5PZSzowcWPm90ElKd3R+Fd6qroBUGnzLhqgNthg+sRidN1O
# Ub7uH1ZxcjTIwdQ+14hnGpMmDDHdmTMvaSZ3p5C+ebogrCn+xDV35N4wign/Aynt
# //1acKG7MQ29bmPgtQWRhXM2uOVciCyDETdFCdGhtK1rK4zYE2n8+Cws8PAnsBCK
# 5IKRgvmKS4LOq3CT4OU7TOcCQcR+XFTvuu+N61wLqToKG9z48uLFc0h5I9HwEkCE
# s71ERUvOXIjRWqJaI9K8G4B0sPi56WolBXnbRrOr4GMV9w2Sce1ByYxg5Go9J4E4
# WWRb2kwO+aclHZbGXnGmzidBSwIDAQABo4IBlTCCAZEwDAYDVR0TAQH/BAIwADAd
# BgNVHQ4EFgQUi29SldV7kStiCZ9aQQeHUAshjJIwHwYDVR0jBBgwFoAU729TSunk
# Bnx6yuKQVvYv1Ensy04wDgYDVR0PAQH/BAQDAgeAMBYGA1UdJQEB/wQMMAoGCCsG
# AQUFBwMIMIGVBggrBgEFBQcBAQSBiDCBhTAkBggrBgEFBQcwAYYYaHR0cDovL29j
# c3AuZGlnaWNlcnQuY29tMF0GCCsGAQUFBzAChlFodHRwOi8vY2FjZXJ0cy5kaWdp
# Y2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRUaW1lU3RhbXBpbmdSU0E0MDk2U0hB
# MjU2MjAyNUNBMS5jcnQwXwYDVR0fBFgwVjBUoFKgUIZOaHR0cDovL2NybDMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGltZVN0YW1waW5nUlNBNDA5NlNI
# QTI1NjIwMjVDQTEuY3JsMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwH
# ATANBgkqhkiG9w0BAQwFAAOCAgEAILS9cQL2Fnk9lQBRBz8qK80fw7XgvGb5p6hz
# dPj3GsqTDX7T/iRRFFRyRAQIc1bkAzHq8C+ZFwsDFCE8KQWiSU9fFM1WGr6hzIh1
# O3LqncMeU+heFY45F18If1YcU9JOmRURy4Sdr+s6rkwYd38Hxvy1b1XIwE5grqjI
# zfD9k6k87M4l3q4uwSDwAo+HTiHpUHCqzFxSFHDLqKC0A6nGQL1nvUDhxslTRXP7
# hnXjcLzRAhsSsV06G9vH+uC9L/Rz1eZmDnRDcMBOTVhjZQnI2/88M4ZnqmHKNG6y
# cpu918rBdF4rUahg3HI5uJeYtIq6Zw/b07RCAE/ceO3iH94OqGYngGAVhSy66qI/
# rOHLQq+T/UNdLez4LBvzMTsbLvdz1jzrLtuIVAqJC1sS9k1tf/cHtRRtSuSKbJly
# ud2ayy6ax3CZVHi5ArpYlRt3/mIrYu+BikzOsXeMtXv4tDrCWY/ymBdEZZPz0OZC
# cnIdYXJ2ak8y46jAS+HQOY1mAG0koHd9LrO7GvhOVvIMtOpgfpE7/7Qb5afMMh4f
# Ayx22mFrNhFaH/1LsNsyBR6LSrtRZnm9K9Jo013PjWkZWBIZO09olBU6m/ZuV4bA
# RRbSHyzL9YlD4GcEy9mgZq9dglj7HyIkvemPuEFe8tnHA6TSK0WBksSRQz54AfR8
# kRFAXCAwgga0MIIEnKADAgECAhANx6xXBf8hmS5AQyIMOkmGMA0GCSqGSIb3DQEB
# CwUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNV
# BAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQg
# Um9vdCBHNDAeFw0yNTA1MDcwMDAwMDBaFw0zODAxMTQyMzU5NTlaMGkxCzAJBgNV
# BAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNl
# cnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBD
# QTEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC0eDHTCphBcr48RsAc
# rHXbo0ZodLRRF51NrY0NlLWZloMsVO1DahGPNRcybEKq+RuwOnPhof6pvF4uGjwj
# qNjfEvUi6wuim5bap+0lgloM2zX4kftn5B1IpYzTqpyFQ/4Bt0mAxAHeHYNnQxqX
# mRinvuNgxVBdJkf77S2uPoCj7GH8BLuxBG5AvftBdsOECS1UkxBvMgEdgkFiDNYi
# OTx4OtiFcMSkqTtF2hfQz3zQSku2Ws3IfDReb6e3mmdglTcaarps0wjUjsZvkgFk
# riK9tUKJm/s80FiocSk1VYLZlDwFt+cVFBURJg6zMUjZa/zbCclF83bRVFLeGkuA
# hHiGPMvSGmhgaTzVyhYn4p0+8y9oHRaQT/aofEnS5xLrfxnGpTXiUOeSLsJygoLP
# p66bkDX1ZlAeSpQl92QOMeRxykvq6gbylsXQskBBBnGy3tW/AMOMCZIVNSaz7BX8
# VtYGqLt9MmeOreGPRdtBx3yGOP+rx3rKWDEJlIqLXvJWnY0v5ydPpOjL6s36czwz
# sucuoKs7Yk/ehb//Wx+5kMqIMRvUBDx6z1ev+7psNOdgJMoiwOrUG2ZdSoQbU2rM
# kpLiQ6bGRinZbI4OLu9BMIFm1UUl9VnePs6BaaeEWvjJSjNm2qA+sdFUeEY0qVjP
# KOWug/G6X5uAiynM7Bu2ayBjUwIDAQABo4IBXTCCAVkwEgYDVR0TAQH/BAgwBgEB
# /wIBADAdBgNVHQ4EFgQU729TSunkBnx6yuKQVvYv1Ensy04wHwYDVR0jBBgwFoAU
# 7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoG
# CCsGAQUFBwMIMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDovL29j
# c3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5kaWdp
# Y2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6MDig
# NqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9v
# dEc0LmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZI
# hvcNAQELBQADggIBABfO+xaAHP4HPRF2cTC9vgvItTSmf83Qh8WIGjB/T8ObXAZz
# 8OjuhUxjaaFdleMM0lBryPTQM2qEJPe36zwbSI/mS83afsl3YTj+IQhQE7jU/kXj
# jytJgnn0hvrV6hqWGd3rLAUt6vJy9lMDPjTLxLgXf9r5nWMQwr8Myb9rEVKChHyf
# pzee5kH0F8HABBgr0UdqirZ7bowe9Vj2AIMD8liyrukZ2iA/wdG2th9y1IsA0QF8
# dTXqvcnTmpfeQh35k5zOCPmSNq1UH410ANVko43+Cdmu4y81hjajV/gxdEkMx1NK
# U4uHQcKfZxAvBAKqMVuqte69M9J6A47OvgRaPs+2ykgcGV00TYr2Lr3ty9qIijan
# rUR3anzEwlvzZiiyfTPjLbnFRsjsYg39OlV8cipDoq7+qNNjqFzeGxcytL5TTLL4
# ZaoBdqbhOhZ3ZRDUphPvSRmMThi0vw9vODRzW6AxnJll38F0cuJG7uEBYTptMSbh
# dhGQDpOXgpIUsWTjd6xpR6oaQf/DJbg3s6KCLPAlZ66RzIg9sC+NJpud/v4+7RWs
# WCiKi9EOLLHfMR2ZyJ/+xhCx9yHbxtl5TPau1j/1MIDpMPx0LckTetiSuEtQvLsN
# z3Qbp7wGWqbIiOWCnb5WqxL3/BAPvIXKUjPSxyZsq8WhbaM2tszWkPZPubdcMIIF
# jTCCBHWgAwIBAgIQDpsYjvnQLefv21DiCEAYWjANBgkqhkiG9w0BAQwFADBlMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3Qg
# Q0EwHhcNMjIwODAxMDAwMDAwWhcNMzExMTA5MjM1OTU5WjBiMQswCQYDVQQGEwJV
# UzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQu
# Y29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwggIiMA0GCSqG
# SIb3DQEBAQUAA4ICDwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz7MKnJS7JIT3y
# ithZwuEppz1Yq3aaza57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS5F/WBTxSD1If
# xp4VpX6+n6lXFllVcq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb7iDV
# ySAdYyktzuxeTsiT+CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfISKhmV1efVFiO
# DCu3T6cw2Vbuyntd463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jHtrHEtWoYOAMQ
# jdjUN6QuBX2I9YI+EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSaM0C/
# CNdaSaTC5qmgZ92kJ7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI8OCi
# EhtmmnTK3kse5w5jrubU75KSOp493ADkRSWJtppEGSt+wJS00mFt6zPZxd9LBADM
# fRyVw4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPRiQfhvbfmQ6QY
# uKZ3AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ERElvlEFDrMcXK
# chYiCd98THU/Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4KJpn15GkvmB0t
# 9dmpsh3lGwIDAQABo4IBOjCCATYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU
# 7NfjgtJxXWRM3y5nP+e6mK4cD08wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6ch
# nfNtyA8wDgYDVR0PAQH/BAQDAgGGMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcw
# AYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8v
# Y2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0
# MEUGA1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwEQYDVR0gBAowCDAGBgRVHSAAMA0GCSqG
# SIb3DQEBDAUAA4IBAQBwoL9DXFXnOF+go3QbPbYW1/e/Vwe9mqyhhyzshV6pGrsi
# +IcaaVQi7aSId229GhT0E0p6Ly23OO/0/4C5+KH38nLeJLxSA8hO0Cre+i1Wz/n0
# 96wwepqLsl7Uz9FDRJtDIeuWcqFItJnLnU+nBgMTdydE1Od/6Fmo8L8vC6bp8jQ8
# 7PcDx4eo0kxAGTVGamlUsLihVo7spNU96LHc/RzY9HdaXFSMb++hUD38dglohJ9v
# ytsgjTVgHAIDyyCwrFigDkBjxZgiwbJZ9VVrzyerbHbObyMt9H5xaiNrIv8SuFQt
# J37YOtnwtoeW/VvRXKwYw02fc7cBqZ9Xql4o4rmUMYIDjDCCA4gCAQEwfTBpMQsw
# CQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERp
# Z2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIw
# MjUgQ0ExAhAOHrsyK1yKdT4SPyHO0PLZMA0GCWCGSAFlAwQCAgUAoIHhMBoGCSqG
# SIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjYxMTIzMDg0
# MjA5WjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBTpqKcjtIUE9eDhQ4tnPs6HzyxQ
# mzA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCBxHdd7HC5xsmHXVY1pnAB3yX0SAzCa
# YI7cEFY0wVBQezA/BgkqhkiG9w0BCQQxMgQw1GFXO+kri046gP0M5HuCp9rCPS0A
# Ec0oQjF85D96iR65D1J8XLLio2qeAt2TszkBMA0GCSqGSIb3DQEBAQUABIICALie
# bHw4U//1g6LCFtJrXinNXcqD9VMHa2t3AhQWApwjg57fa65PtQjuzPozFm/PZfsY
# VIjqwqYqZrmRU3fdxysMZVVPYScRHF7RR6sFYdhNwRh0XJYEM3IB29rhjtlhFFaO
# VjATOHr0xfMyd7dhpV6sdUSbaR38u4/ZmOmM6dZ/iMq8TCpyQ2W/kZcZyIgqg01Z
# AlrzhEBHH83Pq7vk8gjFmSLwkcYgpB1Fjy5iUXEqLffCwyLML2xN6F/bcn8e2lAA
# 5QJnhLNM1MjVkoquci9+tfMHap7gi1bJbRRiFqTqC3kMoSLUF9ubZpPk0MT3TAJT
# UEwDfDHygj9vRmd69WgUYifjWeBOcyx64P6MupWvsrQaesT2YH0SE4TDf1DIy29b
# DCAMylgMVjDRngmSVLKOAAIWGFEvm13vNP7okZ8D04bLjDT8FZM85p5QkxBE3D/2
# r3nppJ2TybqA53D1NdSq/T6+mnZ88/Np8bCNvCFXZHNe2xSitCjWTRRujvv8PIjQ
# LkulwciqlmRZPJW6f/KzZUVSG7Iv9uAaAzFeBA8QVFoSQyx5VG7CdPD1VCEBKdlY
# f/hGmN5/M7LqkpUIWAB7XfW6u8sMGveG6C4gIFb57ul1CXGxM5j6JW/zlEf6GU1n
# lQBDr+doHn3MlrXhvtQh15fkI7g8Y1/a3Z2EzpiJ
# SIG # End signature block
