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
                        
                        $PreclaimError = $_
                        $errorData = $Global:HPECOMInvokeReturnData
                        $workspaceId = $null
                        $workspaceName = $null
                        $fullMessage = $null

                        # Parsed error object (current wrapper) or raw JSON string (older wrapper)
                        if ($errorData.errorCode -or $errorData.message) {
                            $fullMessage = $errorData.message
                            $workspaceId = @($errorData.errorDetails.metadata.workspaceId | Where-Object { $_ })[0]
                            $workspaceName = @($errorData.errorDetails.metadata.workspaceName | Where-Object { $_ })[0]
                        }
                        elseif ($errorData.rawError) {
                            if ($errorData.rawError -match '"workspaceId":\s*"([^"]+)"') { $workspaceId = $Matches[1] }
                            if ($errorData.rawError -match '"workspaceName":\s*"([^"]+)"') { $workspaceName = $Matches[1] }
                            if ($errorData.rawError -match '"message":\s*"([^"]+)"') { $fullMessage = $Matches[1] }
                        }

                        if (-not $fullMessage) {
                            $fullMessage = if ($PreclaimError.Exception.Message) { $PreclaimError.Exception.Message } else { "Subscription validation failed!" }
                        }

                        if ($workspaceId -and -not $workspaceName) {
                            try {
                                $workspaceName = Get-HPEGLWorkspace -Verbose:$false | Where-Object platform_customer_id -eq $workspaceId | Select-Object -First 1 -ExpandProperty company_name
                            }
                            catch {}
                        }

                        $workspaceLabel = if ($workspaceName) { "'{0}'" -f $workspaceName } elseif ($workspaceId) { "with ID '{0}'" -f $workspaceId }

                        if ($workspaceId -and $workspaceId -eq $Global:HPEGreenLakeSession.workspaceId) {
                            $fullMessage = "Subscription key is already claimed in the current workspace. No action needed!"
                        }
                        elseif ($errorData.errorCode -match 'CLAIMED' -or $workspaceId) {
                            $fullMessage = "Subscription key is already claimed in another workspace{0}. Remove it from that workspace first with 'Remove-HPEGLSubscription', or contact HPE support if you do not have access to that workspace." -f $(if ($workspaceLabel) { " ($workspaceLabel)" })
                        }
                        elseif ($fullMessage -notmatch '[.!]$') {
                            $fullMessage = "$fullMessage."
                        }

                        if ($WhatIf) {
                            $ErrorMessage = "Subscription '{0}': {1}" -f $Object.SubscriptionKey, $fullMessage
                            Write-Warning "$ErrorMessage Cannot display API request."
                        }
                        else {
                            $Object.Status = if ($fullMessage -match 'No action needed') { "Warning" } else { "Failed" }
                            $Object.Details = $fullMessage
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
# MIIqPwYJKoZIhvcNAQcCoIIqMDCCKiwCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCEkEDw8LgeuvIP
# jBOcGCqlhQjiSptGcyhhRsoSa6jaPaCCDIMwggYaMIIEAqADAgECAhBiHW0MUgGe
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
# s2+2QiiypE9F8sJAMY/J0e896Wl3WIJZCveguwiA1PowDQYJKoZIhvcNAQEBBQAE
# ggIALpFYU1QGJr9LkEa3rhpkUcF+YAqLIWC5CnmpAnxOHzOm6+u7dES7lswMImJ6
# 8Z96pEtSpDzzsJG2bG+r3zEYXHnvfzZ8ZCLlusiGS9HGFqTq/yi44jvvWbrg5JLu
# powBQaEi+GoMy8eCW+OHvtCtFCf3Sw30/Sanv9dsHKeipcvDVct1idS/F8DTFKie
# jfr7zAO+2+lFsXS9lyDKmzYFnyu9MUTjDIWaC/u4NhZgz//AfJoacMTXA4vOjc4e
# OyiXtrLRtor4p9YbGszHSO1tpUPWX+t6CkkKr5U/f48hrShsYk2Hwm0OtQyr+JtA
# QNVrWoLmhMAePUU+xvQ8PCsOhalJEs+ePlKHrlyDzIVVso6y+9sddXe6mu2meMiJ
# KgihxUaqU6ZmUbTYxfZ1QXy6UhdNA8Xh5q1Y3HdYsh2Wc/LknR+1wLrm5IVr5Aa+
# vaMNVf842Ac7UqJhFjBG81Iv22kdsAoIS7IkBRkYBP+hCKsrGcWbIvi2IyZ1eebU
# 4s0836ERR2IbFlUAyyxStu+/+5Rz4/TjwZyaIapwFvpUUk/9iHBR79Nsxx3hwHCN
# wUeUIdgDM3yvJIdI5j9e7jx4KjTAo+rVtaImb17LBGTBkvr+dzUo3JMZe6NKT/bf
# +LqLnvD6L1EvAQa+JUUEr30rblGXSflF3bauhVwb7X0SRpihghn8MIIZ+AYKKwYB
# BAGCNwMDATGCGegwghnkBgkqhkiG9w0BBwKgghnVMIIZ0QIBAzEPMA0GCWCGSAFl
# AwQCAgUAMIIBBwYLKoZIhvcNAQkQAQSggfcEgfQwgfECAQEGCisGAQQBsjECAQEw
# QTANBglghkgBZQMEAgIFAAQwvlUQfdK93AaFvZ4FYjGK56qhlMO+CFJTSQxE+Qec
# 35Jao1ws/2CaJeDmJELAfdrmAhQVCbZw7E/8mB+iRed+pOl+/5iLRhgPMjAyNjEx
# MjYxNzU2MzNaoHakdDByMQswCQYDVQQGEwJHQjEXMBUGA1UECBMOR3JlYXRlciBM
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
# AQkDMQ0GCyqGSIb3DQEJEAEEMBwGCSqGSIb3DQEJBTEPFw0yNjExMjYxNzU2MzNa
# MD8GCSqGSIb3DQEJBDEyBDC0D9S9Iqy6Mz2bu7wr0cmrTVW9y4Zl5fw0pGg8zArj
# VW3fHv/Z+aC+hGtlzYJmu10wggF7BgsqhkiG9w0BCRACDDGCAWowggFmMIIBYjAW
# BBTpeBipKNoVCp/hv5zMequ5oA7urDCBiAQUZcMoaW99TlAs/QPHwgaXGMr7908w
# cDBbpFkwVzELMAkGA1UEBhMCR0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEu
# MCwGA1UEAxMlU2VjdGlnbyBQdWJsaWMgVGltZSBTdGFtcGluZyBSb290IFI0NgIR
# AJCsCHIg/cWnxGtcxw33PQYwgbwEFIU9Yy2TgoJhfNCQNcSR3pLBQtrHMIGjMIGO
# pIGLMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKTmV3IEplcnNleTEUMBIGA1UE
# BxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBVU0VSVFJVU1QgTmV0d29yazEu
# MCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZpY2F0aW9uIEF1dGhvcml0eQIQ
# NsKwvXwbOuejs902y8l1aDANBgkqhkiG9w0BAQEFAASCAgCMsD1msvHeqp4Pv4gp
# qTsstlxfDIhlyR9ag7XNRStUOtKGooecpimZT5vG5vb1J8maJ6SEkzLgzQeAs5u7
# jWETNV1IqcMxqJFiOEWYw3TvxcI4DisQV2neO6a+h7DbV5D3T1vOa53dH/Ze9EnL
# OYSkND49wOCuYw4tdAott81XEIRU2fh3BbI5HsB7XCP3SCYzmpI9rjEEwyXznITi
# lkthHUoBCO7YMeb2EWvgpQyCPllM2dtRY3V7NKjq3OcUt6NF1YAM1I4r3ZEnKwQK
# 2CuiqoncBorvvGO/KiaCqCszlrvPd1NG32A7yFqkwaHbvN1KGSTu0FkwJVm6tRGo
# Gvb/Szg285B8KUc7gARQaqAsaoVkscbRqwvsNdcBPSNJk2WTNeKMXISsB2uzT8lV
# +stGJTkKfdoXFgi0UaoqLwg4zCdB6Zxdan/FKLCR6E9kRcq+DPuC/Jveq7spSLeD
# 8nQ7w5+xjfndSa9Pie21LwVE9jAMbzoPZkPeNy2njb8FtwRursAIqo2ZVcRdmGA4
# Zx2nDjPhKDZrqNc/rlZbsAinN1P7kc9M1p/TK0xvOcWGXbuEJw/BwZjzC8/yHs8c
# XFBwDqsKtoO2eQN5Jbz2CGDdTUraiQeRMFEKl12JryI1zPVEHqH+t4xO88gPTB1i
# E5A8eXG+gMCLsTIRL/ODnyM7ng==
# SIG # End signature block
