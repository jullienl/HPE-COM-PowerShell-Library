#------------------- FUNCTIONS FOR HPE GreenLake WEBHOOKS -----------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1

# Public Functions
Function Get-HPEGLWebhook {
    <#
    .SYNOPSIS
    Retrieve webhook resources in a workspace.

    .DESCRIPTION
    This Cmdlet retrieves a collection of webhooks available in the workspace.
    Use the -Show* parameters to filter results by webhook status.

    .PARAMETER Name 
    An optional parameter to specify the name of a webhook to display.

    .PARAMETER ShowActive
    Returns only webhooks with a status of ACTIVE.

    .PARAMETER ShowDisabled
    Returns only webhooks with a status of DISABLED.

    .PARAMETER ShowPending
    Returns only webhooks with a status of PENDING.

    .PARAMETER ShowWarning
    Returns only webhooks with a status of WARNING.

    .PARAMETER ShowError
    Returns only webhooks with a status of ERROR.

    .PARAMETER ShowRecentDeliveries
    When specified along with -Name, returns the recent delivery history for the named webhook.
    Each delivery record shows the outcome status, HTTP response code, and timestamp of a recent event delivery attempt.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to HPE GreenLake instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by the cmdlet.

    .EXAMPLE
    Get-HPEGLWebhook 

    Returns all webhooks available in the workspace.

    .EXAMPLE
    Get-HPEGLWebhook -Name 'Webhook for audit log events'

    Returns the webhook resource named 'Webhook for audit log events'.

    .EXAMPLE
    Get-HPEGLWebhook -ShowActive

    Returns all webhooks with a status of ACTIVE.

    .EXAMPLE
    Get-HPEGLWebhook -ShowWarning -ShowError

    Returns all webhooks with a status of WARNING or ERROR.

    .EXAMPLE
    Get-HPEGLWebhook -Name 'Webhook for audit log events' -ShowRecentDeliveries

    Returns the recent delivery history for the webhook named 'Webhook for audit log events'.

    .INPUTS
    None. You cannot pipe objects to this Cmdlet.

   #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 

        [Parameter(ParameterSetName = 'Default')]
        [Parameter(Mandatory, ParameterSetName = 'RecentDeliveries')]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Parameter(ParameterSetName = 'Default')]
        [Switch]$ShowActive,

        [Parameter(ParameterSetName = 'Default')]
        [Switch]$ShowDisabled,

        [Parameter(ParameterSetName = 'Default')]
        [Switch]$ShowPending,

        [Parameter(ParameterSetName = 'Default')]
        [Switch]$ShowWarning,

        [Parameter(ParameterSetName = 'Default')]
        [Switch]$ShowError,

        [Parameter(Mandatory, ParameterSetName = 'RecentDeliveries')]
        [Switch]$ShowRecentDeliveries,

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
    
    }

    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        if ($PSCmdlet.ParameterSetName -eq 'RecentDeliveries') {

            try {
                $WebhookResource = Get-HPEGLWebhook -Name $Name
                $WebhookID = $WebhookResource.id
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }

            if (-not $WebhookID) {
                "[{0}] Webhook '{1}' cannot be found in the workspace." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                return
            }

            "[{0}] Webhook '{1}' found with ID: '{2}'. Fetching recent deliveries." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $WebhookID | Write-Verbose

            $Uri = (Get-GLWebhooksUri) + "/" + $WebhookID + "/recent-deliveries"

            try {
                [Array]$CollectionList = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference -ErrorAction Stop
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }

            if ($Null -ne $CollectionList) {
                foreach ($item in $CollectionList) {
                    $item | Add-Member -NotePropertyName 'delivery'     -NotePropertyValue $item.requestBody.type  -Force
                    $item | Add-Member -NotePropertyName 'response'     -NotePropertyValue $item.httpResponseCode  -Force
                    $item | Add-Member -NotePropertyName 'webhookName'  -NotePropertyValue $Name                   -Force
                }
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "GL.WebhookDeliveries"
                $ReturnData = $ReturnData | Sort-Object -Descending createdAt
                return $ReturnData
            }
            else {
                return
            }

        }
        else {

            $Uri = Get-GLWebhooksUri

            try {
                [Array]$CollectionList = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference -ErrorAction Stop
    
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
                       
            }           
            
            $ReturnData = @()
           
            if ($Null -ne $CollectionList) {

                if ($Name) {
                    $CollectionList = @($CollectionList | Where-Object { $_.name -ieq $Name })
                }

                # Apply status filter if any -Show* switch is specified
                $StatusFilters = @()
                if ($ShowActive)   { $StatusFilters += 'ACTIVE' }
                if ($ShowDisabled) { $StatusFilters += 'DISABLED' }
                if ($ShowPending)  { $StatusFilters += 'PENDING' }
                if ($ShowWarning)  { $StatusFilters += 'WARNING' }
                if ($ShowError)    { $StatusFilters += 'ERROR' }

                if ($StatusFilters.Count -gt 0) {
                    $CollectionList = @($CollectionList | Where-Object { $_.status -in $StatusFilters })
                }

                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "GL.Webhooks"    
                $ReturnData = $ReturnData | Sort-Object name
            
                return $ReturnData 
                    
            }
            else {

                return
                    
            }         
        }
    }
}

Function New-HPEGLWebhook {
    <#
    .SYNOPSIS
    Creates a new webhook in the workspace.

    .DESCRIPTION
    This Cmdlet registers a new webhook with a destination endpoint and authentication settings.
    After creating the webhook, use Add-HPEGLWebhookSubscription to subscribe it to event types.

    By default, HPE GreenLake sends an HMAC SHA-256 challenge request to the destination endpoint
    during registration to verify the URL is reachable and correctly configured. Use -SkipVerification
    to bypass this check and create the webhook in ACTIVE status immediately.
    
    An optional secondary shared secret can be specified with -SecondarySecret to enable zero-downtime
    secret rotation. When a secondary secret is provided, HPE GreenLake signs each delivery with BOTH
    secrets simultaneously (dualSecret mode). This allows you to update the primary secret on the
    receiving side without missing any events during the transition.
        
    .PARAMETER Name 
    Specifies the name of the webhook to create.

    .PARAMETER Description
    Specifies an optional short description to identify the purpose of the webhook.

    .PARAMETER Destination 
    Specifies the HTTPS webhook endpoint capable of receiving HTTP GET and POST requests.

    .PARAMETER Secret
    A shared secret used to sign webhook deliveries. HPE GreenLake includes this value 
    in each request so the receiving endpoint can validate the request origin.
    Required for all authentication types, including 'No authentication'.

    .PARAMETER AuthenticationType
    Specifies the authentication type used when HPE GreenLake calls the webhook destination endpoint.
    Valid values are: 'API Key', 'OAuth', 'No authentication'.

    .PARAMETER ApiKey
    The API key value sent by HPE GreenLake in each request to the webhook destination.
    Required when -AuthenticationType is 'API Key'.

    .PARAMETER ClientId
    The OAuth 2.0 client ID used to obtain access tokens for authenticating webhook delivery.
    Required when -AuthenticationType is 'OAuth'.

    .PARAMETER ClientSecret
    The OAuth 2.0 client secret corresponding to the specified client ID.
    Required when -AuthenticationType is 'OAuth'.

    .PARAMETER IssuerUrl
    The base URL of the OAuth 2.0 token issuer (authorization server) used to obtain access tokens.
    Required when -AuthenticationType is 'OAuth'.

    .PARAMETER BatchingEnabled
    When specified, events will be sent in batches of 10 or when the oldest event in a batch is 1 minute old.

    .PARAMETER SkipVerification
    When specified, bypasses the HMAC SHA-256 challenge request handshake that HPE GreenLake normally
    sends to the destination endpoint during webhook registration. The webhook is created in ACTIVE
    status immediately without verifying that the endpoint is reachable.
    By default, the challenge request is enabled, and the webhook remains in PENDING status until 
    the destination endpoint responds correctly to the challenge.

    .PARAMETER SecondarySecret
    An optional secondary shared secret used to enable zero-downtime secret rotation (dual-secret mode).
    When provided, HPE GreenLake signs each event delivery with both the primary and secondary secrets
    simultaneously. This allows you to update the secret on the receiving endpoint without missing
    any events during the transition. Once the rotation is complete, use Set-HPEGLWebhook to remove
    the secondary secret.
    
    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to HPE GreenLake instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by the cmdlet.

    .EXAMPLE
    $Secret = ConvertTo-SecureString "my-webhook-secret" -AsPlainText -Force
    New-HPEGLWebhook -Name "Webhook for audit log events" `
    -Destination "https://hook.eu2.make.com/baea2fa0f8be4d546445c98253392058" `
    -Secret $Secret `
    -AuthenticationType "No authentication"

    Creates a webhook with no authentication.
    Use Add-HPEGLWebhookSubscription to subscribe this webhook to event types.

    .EXAMPLE
    $Secret = ConvertTo-SecureString "my-webhook-secret" -AsPlainText -Force
    $ApiKey = ConvertTo-SecureString "my-secret-api-key" -AsPlainText -Force
    New-HPEGLWebhook -Name "Webhook for audit log events" `
    -Destination "https://hook.eu2.make.com/baea2fa0f8be4d546445c98253392058" `
    -Secret $Secret `
    -AuthenticationType "API Key" -ApiKey $ApiKey

    Creates a webhook that uses API Key authentication.

    .EXAMPLE
    $Secret = ConvertTo-SecureString "my-webhook-secret" -AsPlainText -Force
    $ClientSecret = ConvertTo-SecureString "my-client-secret" -AsPlainText -Force
    New-HPEGLWebhook -Name "Webhook for OAuth events" `
    -Destination "https://hook.eu2.make.com/baea2fa0f8be4d546445c98253392058" `
    -Secret $Secret `
    -AuthenticationType "OAuth" `
    -ClientId "my-client-id" `
    -ClientSecret $ClientSecret `
    -IssuerUrl "https://auth.example.com"

    Creates a webhook that uses OAuth 2.0 authentication.

    .EXAMPLE
    $Secret = ConvertTo-SecureString "my-webhook-secret" -AsPlainText -Force
    New-HPEGLWebhook -Name "Webhook for testing" `
    -Destination "https://hook.eu2.make.com/baea2fa0f8be4d546445c98253392058" `
    -Secret $Secret `
    -AuthenticationType "No authentication" `
    -SkipVerification

    Creates a webhook without performing the challenge request handshake. The webhook is immediately ACTIVE.

    .EXAMPLE
    $Secret = ConvertTo-SecureString "my-webhook-secret" -AsPlainText -Force
    $SecondarySecret = ConvertTo-SecureString "my-secondary-secret" -AsPlainText -Force
    New-HPEGLWebhook -Name "Webhook for audit log events" `
    -Destination "https://hook.eu2.make.com/baea2fa0f8be4d546445c98253392058" `
    -Secret $Secret `
    -SecondarySecret $SecondarySecret `
    -AuthenticationType "No authentication"

    Creates a webhook with dual-secret authentication enabled for zero-downtime secret rotation.

    .INPUTS
    Pipeline input is not supported

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - Name of the webhook attempted to be created
        * Status - Status of the creation attempt (Failed for http error return; Complete if creation is successful; Warning if no action is needed) 
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.

   #>

    [CmdletBinding()]
    Param( 
        
        [Parameter (Mandatory)]
        [ValidateScript({ $_.Length -lt 256 })]
        [String]$Name,

        [ValidateScript({ $_.Length -lt 256 })]
        [String]$Description,
        
        [Parameter (Mandatory)]
        [ValidateScript({
                if ($_ -match '^https?:\/\/[a-zA-Z0-9-\.]+\.[a-z]{2,4}(/\S*)?$') {
                    return $true
                }
                else {
                    throw "The URL '$_' is not a valid HTTP/HTTPS URL."
                }
            })]
        [String]$Destination,

        [Parameter (Mandatory)]
        [ValidateSet('API Key', 'OAuth', 'No authentication')]
        [String]$AuthenticationType,

        [Parameter (Mandatory)]
        [SecureString]$Secret,

        [SecureString]$ApiKey,

        [ValidateNotNullOrEmpty()]
        [String]$ClientId,

        [SecureString]$ClientSecret,

        [ValidateScript({
                if ($_ -match '^https?:\/\/[a-zA-Z0-9-\.]+\.[a-z]{2,4}(/\S*)?$') {
                    return $true
                }
                else {
                    throw "The URL '$_' is not a valid HTTP/HTTPS URL."
                }
            })]
        [String]$IssuerUrl,

        [Switch]$BatchingEnabled,

        [Switch]$SkipVerification,

        [SecureString]$SecondarySecret,
        
        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $CreateWebhookStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $Uri = Get-GLWebhooksUri

        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Name      = $Name
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

        try {
            $WebhookResource = Get-HPEGLWebhook -Name $Name

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)

        }

        if ($WebhookResource) {
            
            "[{0}] Webhook '{1}' is already present in the workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
    
            if ($WhatIf) {
                $ErrorMessage = "Webhook '{0}': Resource is already present in the workspace! No action needed." -f $Name
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "Webhook already exists in the workspace! No action needed."
            }

        }
        else {

            # Validate authentication-type-specific parameters
            if ($AuthenticationType -eq 'API Key' -and -not $ApiKey) {
                $ErrorMessage = "Webhook '{0}': Parameter -ApiKey is required when -AuthenticationType is 'API Key'." -f $Name
                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
                    return
                }
                else {
                    $objStatus.Status = "Warning"
                    $objStatus.Details = "Parameter -ApiKey is required when -AuthenticationType is 'API Key'."
                }
            }
            elseif ($AuthenticationType -eq 'OAuth') {
                $missingOAuthParams = @()
                if (-not $ClientId)     { $missingOAuthParams += '-ClientId' }
                if (-not $ClientSecret) { $missingOAuthParams += '-ClientSecret' }
                if (-not $IssuerUrl)    { $missingOAuthParams += '-IssuerUrl' }
                if ($missingOAuthParams.Count -gt 0) {
                    $ErrorMessage = "Webhook '{0}': Parameter(s) {1} required when -AuthenticationType is 'OAuth'." -f $Name, ($missingOAuthParams -join ', ')
                    if ($WhatIf) {
                        Write-Warning "$ErrorMessage Cannot display API request."
                        return
                    }
                    else {
                        $objStatus.Status = "Warning"
                        $objStatus.Details = "Parameter(s) {0} required when -AuthenticationType is 'OAuth'." -f ($missingOAuthParams -join ', ')
                    }
                }
            }

            if (-not $objStatus.Status) {

                # Map authentication type to API value
                $authTypeMap = @{
                    'API Key'           = 'APIKey'
                    'OAuth'             = 'Oauth'
                    'No authentication' = ''
                }

                # Build payload
                $payloadObj = @{
                    name        = $Name
                    destination = $Destination
                    secret      = [System.Net.NetworkCredential]::new('', $Secret).Password
                    authType    = $authTypeMap[$AuthenticationType]
                    batching    = $BatchingEnabled.IsPresent
                }

                if ($Description) {
                    $payloadObj.description = $Description
                }

                if ($SkipVerification) {
                    $payloadObj.challengeRequestEnabled = $false
                }

                if ($SecondarySecret) {
                    $payloadObj.secondarySecret = [System.Net.NetworkCredential]::new('', $SecondarySecret).Password
                }

                if ($AuthenticationType -eq 'API Key') {
                    $payloadObj.apiKey = [System.Net.NetworkCredential]::new('', $ApiKey).Password
                }
                elseif ($AuthenticationType -eq 'OAuth') {
                    $payloadObj.clientId     = $ClientId
                    $payloadObj.clientSecret = [System.Net.NetworkCredential]::new('', $ClientSecret).Password
                    $payloadObj.issuerUrl    = $IssuerUrl
                }

                $payload = ConvertTo-Json $payloadObj
                
                try {
                    $Response = Invoke-HPEGLWebRequest -Uri $Uri -method POST -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
    
                    if (-not $WhatIf) {
    
                        "[{0}] Webhook creation raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose
                        
                        "[{0}] Webhook '{1}' successfully created in the workspace" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name | Write-Verbose
                            
                        $objStatus.Status = "Complete"
                        $objStatus.Details = "Webhook successfully created."
    
                    }
    
                }
                catch {
    
                    if (-not $WhatIf) {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Webhook cannot be created!"}
                        $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                    }
                }           
            }
        }

                     
        if (-not $WhatIf) { [void] $CreateWebhookStatus.add($objStatus) }

    }

    end {

        if ($CreateWebhookStatus.Count -gt 0) {

            $CreateWebhookStatus = Invoke-RepackageObjectWithType -RawObject $CreateWebhookStatus -ObjectName "GL.objStatus.NSDE"    
            Return $CreateWebhookStatus
        }


    }
}

Function Set-HPEGLWebhook {
    <#
    .SYNOPSIS
    Update an existing webhook in the workspace.

    .DESCRIPTION
    This Cmdlet is used to update an existing webhook. Only the parameters explicitly provided are updated;
    all other webhook settings remain unchanged.
    To manage event subscriptions, use Add-HPEGLWebhookSubscription and Remove-HPEGLWebhookSubscription.

    Shared secret management: use -Secret to rotate the primary secret and -SecondarySecret to add or
    remove the secondary secret used for zero-downtime rotation. When a secondary secret is present,
    HPE GreenLake signs deliveries with both secrets simultaneously (dualSecret mode). To remove the
    secondary secret after rotation is complete, use Set-HPEGLWebhook -SecondarySecret (empty string as SecureString).
    
    Challenge request management: use -SkipVerification to disable the challenge request handshake
    or -EnableChallengeRequest to re-enable it. These two switches are mutually exclusive.
        
    .PARAMETER Name
    Specifies the name of the webhook to update.

    .PARAMETER NewName
    Specifies the new name for the webhook.

    .PARAMETER Destination
    Specifies the new HTTPS webhook endpoint that is able to receive HTTP GET and POST requests.

    .PARAMETER Secret
    The new primary shared secret used to sign webhook deliveries.
    HPE GreenLake includes this value in each request so the receiving endpoint can validate the request origin.

    .PARAMETER SecondarySecret
    An optional secondary shared secret used to enable zero-downtime secret rotation (dual-secret mode).
    When provided, HPE GreenLake signs each event delivery with both the primary and secondary secrets
    simultaneously. Once the rotation is complete on the receiving side, remove the secondary secret
    by calling Set-HPEGLWebhook with -SecondarySecret set to an empty string (converted to SecureString).

    .PARAMETER SkipVerification
    When specified, disables the challenge request handshake (sets challengeRequestEnabled to false).
    Cannot be combined with -EnableChallengeRequest.

    .PARAMETER EnableChallengeRequest
    When specified, re-enables the challenge request handshake (sets challengeRequestEnabled to true).
    Cannot be combined with -SkipVerification.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to HPE GreenLake instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by the cmdlet.

    .EXAMPLE
    Set-HPEGLWebhook -Name "My_webhook" -NewName "Webhook for audit log events" `
     -Destination "https://hook.eu2.make.com/baea2fa0f8be4d546445c98253392058"

    Updates the webhook named "My_webhook" with a new name and destination URL.

    .EXAMPLE
    Set-HPEGLWebhook -Name "Webhook for audit log events" -Destination "https://hook.us1.make.com/wwedws2fa0f8be4d546445c98253392058"

    Updates the destination URL for the webhook named "Webhook for audit log events".

    .EXAMPLE
    Get-HPEGLWebhook | Set-HPEGLWebhook -Destination "https://hook.eu2.make.com/baea2fa0f8be4d546445c98253392058"

    Updates the destination URL for all webhooks in the workspace.

    .EXAMPLE
    "POSH_webhook_Alert", "POSH_webhook_firmwarebundle" | Set-HPEGLWebhook -Destination "https://hook.us1.make.com/wwedws"

    Updates the destination URL for two webhooks by name.

    .EXAMPLE
    $NewSecret = ConvertTo-SecureString "new-primary-secret" -AsPlainText -Force
    Set-HPEGLWebhook -Name "Webhook for audit log events" -Secret $NewSecret

    Rotates the primary shared secret for the webhook.

    .EXAMPLE
    $SecondarySecret = ConvertTo-SecureString "temp-secondary-secret" -AsPlainText -Force
    Set-HPEGLWebhook -Name "Webhook for audit log events" -SecondarySecret $SecondarySecret

    Adds a secondary shared secret to enable zero-downtime secret rotation.
    Once the receiving endpoint is updated to use the new primary secret, remove the secondary secret.

    .EXAMPLE
    Set-HPEGLWebhook -Name "Webhook for audit log events" -SkipVerification

    Disables the challenge request handshake for the webhook.

    .EXAMPLE
    Set-HPEGLWebhook -Name "Webhook for audit log events" -EnableChallengeRequest

    Re-enables the challenge request handshake for the webhook.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the webhooks's names.

    System.Collections.ArrayList
        List of webhooks from 'Get-HPEGLWebhook'.

    .OUTPUTS
    System.Collections.ArrayList
        Returns a custom status object or array of objects containing the following properties:
        * Name - Name of the webhook attempted to be set.
        * Status - Status of the modification attempt (Failed if an HTTP error occurs; Complete if successful; Warning if no action is needed).
        * Details - Additional information about the status.
        * Exception - Information about any exceptions generated during the operation.

      
   #>

    [CmdletBinding()]
    Param( 
        
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript({ $_.Length -lt 256 })]
        [String]$Name,

        [ValidateScript({ $_.Length -lt 256 })]
        [String]$NewName,
        
        [ValidateScript({
                if ($_ -match '^https?:\/\/[a-zA-Z0-9-\.]+\.[a-z]{2,4}(/\S*)?$') {
                    return $true
                }
                else {
                    throw "The URL '$_' is not a valid HTTP/HTTPS URL."
                }
            })]
        [String]$Destination,

        [SecureString]$Secret,

        [SecureString]$SecondarySecret,

        [Switch]$SkipVerification,

        [Switch]$EnableChallengeRequest,
        
        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $SetWebhookStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Validate mutually exclusive switches
        if ($SkipVerification -and $EnableChallengeRequest) {
            $ErrorMessage = "Webhook '{0}': Parameters -SkipVerification and -EnableChallengeRequest cannot be used together. Specify only one." -f $Name
            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {
                $objStatus = [pscustomobject]@{
                    Name      = $Name
                    Status    = 'Warning'
                    Details   = 'Parameters -SkipVerification and -EnableChallengeRequest cannot be used together. Specify only one.'
                    Exception = $Null
                }
                [void] $SetWebhookStatus.add($objStatus)
                return
            }
        }

        try {
            $WebhookResource = Get-HPEGLWebhook -Name $Name
            $WebhookID = $WebhookResource.id
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)

        }

        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Name      = $Name
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

        if (-not $WebhookID) {

            "[{0}] Webhook '{1}' cannot be found in the workspace." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

            if ($WhatIf) {
                
                $ErrorMessage = "Webhook '{0}': Resource cannot be found in the workspace!" -f $Name
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {

                $objStatus.Status = "Warning"
                $objStatus.Details = "Webhook cannot be found in the workspace!"
            }
        }
        else {

            "[{0}] Webhook '{1}' found with ID: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $WebhookID | Write-Verbose

            $Uri = (Get-GLWebhooksUri) + "/" + $WebhookID

            $Payload = @{}

            if ($NewName -and $NewName -ne $WebhookResource.name) {
                $Payload.name = $NewName
            }

            if ($Destination -and $Destination -ne $WebhookResource.destination) {
                $Payload.destination = $Destination
            }

            if ($Secret) {
                $Payload.secret = [System.Net.NetworkCredential]::new('', $Secret).Password
            }

            if ($PSBoundParameters.ContainsKey('SecondarySecret')) {
                $Payload.secondarySecret = [System.Net.NetworkCredential]::new('', $SecondarySecret).Password
            }

            if ($SkipVerification) {
                $Payload.challengeRequestEnabled = $false
            }
            elseif ($EnableChallengeRequest) {
                $Payload.challengeRequestEnabled = $true
            }

            if ($Payload.Count -eq 0) {

                if ($WhatIf) {
                    $ErrorMessage = "Webhook '{0}': No changes to apply. The provided values are identical to the current webhook settings." -f $Name
                    Write-Warning "$ErrorMessage Cannot display API request."
                    return
                }

                $objStatus.Status = "Warning"
                $objStatus.Details = "No changes to apply. The provided values are identical to the current webhook settings."

            }
            else {

                # Convert the hashtable to JSON
                $jsonPayload = $Payload | ConvertTo-Json
           
                try {
               
                    $Response = Invoke-HPEGLWebRequest -Uri $Uri -method PATCH -body $jsonPayload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                              
                    if (-not $WhatIf) {
                   
                        "[{0}] Webhook update raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose
                   
                        "[{0}] Webhook '{1}' successfully updated in the workspace" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name | Write-Verbose
                   
                        $objStatus.Status = "Complete"
                        $objStatus.Details = "Webhook successfully updated."
                   
                    }
                
                }
                catch {
                
                    if (-not $WhatIf) {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Webhook cannot be updated!" }
                        $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                    }
                }           
            }
        }


        if (-not $WhatIf) { [void] $SetWebhookStatus.add($objStatus) }

    }

    end {

        if ($SetWebhookStatus.Count -gt 0) {

            $SetWebhookStatus = Invoke-RepackageObjectWithType -RawObject $SetWebhookStatus -ObjectName "GL.objStatus.NSDE"    
            Return $SetWebhookStatus
        }


    }
}

Function Send-HPEGLWebhookTest {
    <#
   
    .SYNOPSIS
    Send a test event to a webhook's configured endpoint URL.

    .DESCRIPTION
    This Cmdlet constructs a CloudEvents-format test event and sends it directly to the destination endpoint of an existing webhook.

    The event type used in the test payload is derived from the first event subscription configured on the webhook. 
    If no subscriptions are configured, the cmdlet returns a Warning status with guidance to add subscriptions first.

    This test is useful for validating end-to-end communication between the webhook destination and your automation process.

    .PARAMETER Name 
    The name of the webhook to test.
   
    .PARAMETER WhatIf
    Shows the REST call that would be made to the webhook destination instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by the cmdlet.

    .EXAMPLE
    Send-HPEGLWebhookTest -Name "Webhook for audit log events"

    Sends a CloudEvents-format test event to the destination endpoint of the webhook named 'Webhook for audit log events'.
    
    .EXAMPLE
    Get-HPEGLWebhook | Send-HPEGLWebhookTest

    Sends a CloudEvents-format test event to the destination endpoints of all webhooks in the workspace.

    .EXAMPLE
    "Webhook for audit log events", "Webhook for expiring subscriptions" | Send-HPEGLWebhookTest

    Sends a CloudEvents-format test event to the destination endpoints of the two named webhooks.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the webhooks's names.

    System.Collections.ArrayList
        List of webhooks from 'Get-HPEGLWebhook'.

   .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - The name of the webhook used for the sending test.
        * Status - The status of the send test attempt (Failed for HTTP error return; Complete if successful; Warning if no action is needed). 
        * Details - Additional information about the status. 
        * Exception - Information about any exceptions generated during the operation.
    
   #>

    [CmdletBinding()]
    Param( 
        
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $SendWebhookTestStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Name      = $Name
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

        try {
            $WebhookResource = Get-HPEGLWebhook -Name $Name
            $WebhookID = $WebhookResource.id

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)

        }

        if (-not $WebhookID) {

            "[{0}] Webhook '{1}' cannot be found in the workspace." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

            if ($WhatIf) {
                
                $ErrorMessage = "Webhook '{0}' cannot be found in the workspace!" -f $Name
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {

                $objStatus.Status = "Warning"
                $objStatus.Details = "Webhook cannot be found in the workspace!"
            }
        }
        else {

            "[{0}] Webhook '{1}' found with ID: '{2}'. Fetching subscriptions." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $WebhookID | Write-Verbose

            $Destination = $WebhookResource.destination

            # Get subscriptions to find the event type for the test payload
            try {
                $Subscriptions = Get-HPEGLWebhookSubscription -WebhookName $Name
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }

            if (-not $Subscriptions) {

                "[{0}] No event subscriptions found for webhook '{1}'." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

                if ($WhatIf) {
                    $ErrorMessage = "Webhook '{0}': No event subscriptions are configured. Add subscriptions using Add-HPEGLWebhookSubscription before sending a test." -f $Name
                    Write-Warning "$ErrorMessage Cannot display API request."
                    return
                }
                else {
                    $objStatus.Status = "Warning"
                    $objStatus.Details = "No event subscriptions are configured for this webhook. Add subscriptions using Add-HPEGLWebhookSubscription before sending a test."
                }
            }
            else {

                # Use the first subscription's event type for the test payload
                $EventType = $Subscriptions | Select-Object -First 1 -ExpandProperty eventType

                "[{0}] Using event type '{1}' for test payload. Destination: '{2}'." -f $MyInvocation.InvocationName.ToString().ToUpper(), $EventType, $Destination | Write-Verbose

                # Build a CloudEvents-format test event payload
                $TestEventId  = [System.Guid]::NewGuid().ToString()
                $TestEventNow = (Get-Date).ToUniversalTime()
                $TestEventIso = $TestEventNow.ToString("o")
                $TestEpochMs  = [long](($TestEventNow - [datetime]'1970-01-01T00:00:00Z').TotalMilliseconds)

                if ($EventType -like "com.hpe.greenlake.audit-log.*") {

                    $WorkspaceId   = $Global:HPEGreenLakeSession.workspaceId
                    $WorkspaceName = $Global:HPEGreenLakeSession.workspace
                    $Username      = $Global:HPEGreenLakeSession.username

                    $EventObject = [ordered]@{
                        specversion     = "1.0"
                        id              = $TestEventId
                        source          = "//global.api.greenlake.hpe.com/audit-log"
                        type            = $EventType
                        datacontenttype = "application/json"
                        dataschema      = "https://developer.greenlake.hpe.com/docs/greenlake/services/audit-logs/public/catalog/audit-log-event-latest/paths/Audit%20Log%20Created/post/"
                        time            = $TestEventIso
                        subject         = ($WorkspaceId -replace '-', '').ToLower().PadRight(32, '0').Substring(0, 32)
                        data            = [ordered]@{
                            id          = $TestEventId
                            user        = @{ username = $Username }
                            workspace   = @{
                                id             = ($WorkspaceId -replace '-', '').ToLower().PadRight(32, '0').Substring(0, 32)
                                workspace_name = $WorkspaceName
                                workspace_type = $null
                            }
                            application = @{ id = "00000000-0000-0000-0000-000000000000" }
                            category    = "user_management"
                            description = "HPECOMCmdlets Send-HPEGLWebhookTest: test audit log event. User $Username logged out."
                            created_at  = $TestEpochMs
                            updated_at  = $TestEpochMs
                            additional_info = @{
                                ip_address     = "0.0.0.0"
                                account_name   = $WorkspaceName
                                ip_address_str = "0.0.0.0"
                            }
                            has_details = $false
                        }
                    }
                }
                elseif ($EventType -like "com.hpe.greenlake.subscriptions.*") {

                    $EventObject = [ordered]@{
                        specversion     = "1.0"
                        id              = $TestEventId
                        source          = "//global.api.greenlake.hpe.com/subscriptions"
                        type            = $EventType
                        datacontenttype = "application/json"
                        time            = $TestEventIso
                        data            = [ordered]@{
                            id              = $TestEventId
                            subscription_id = "00000000-0000-0000-0000-000000000000"
                            quantity        = 1
                            expiration_date = $TestEventNow.AddDays(30).ToString("o")
                            description     = "HPECOMCmdlets Send-HPEGLWebhookTest: test subscription expiry event."
                        }
                    }
                }
                else {

                    $EventObject = [ordered]@{
                        specversion     = "1.0"
                        id              = $TestEventId
                        source          = "//global.api.greenlake.hpe.com/test"
                        type            = $EventType
                        datacontenttype = "application/json"
                        time            = $TestEventIso
                        data            = @{
                            testEvent = $true
                            message   = "HPECOMCmdlets Send-HPEGLWebhookTest: test event."
                        }
                    }
                }

                $jsonPayload = ConvertTo-Json $EventObject -Depth 5

                "[{0}] Webhook test payload: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $jsonPayload | Write-Verbose

                try {

                    if ($WhatIf) {

                        Invoke-RestMethodWhatIf -Uri $Destination -Method POST -Body $jsonPayload -ContentType "application/json" -Cmdlet Invoke-RestMethod

                    }
                    else {

                        $Response = Invoke-RestMethod -Uri $Destination -Method POST -Body $jsonPayload -ContentType "application/json"
                    }

                    if (-not $WhatIf) {

                        "[{0}] Webhook test raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose

                        "[{0}] Webhook '{1}' test event successfully sent to '{2}'." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Destination | Write-Verbose

                        $objStatus.Status = "Complete"
                        $objStatus.Details = "Test event of type '$EventType' successfully sent to '$Destination'."

                    }

                }
                catch {

                    $errorResponse = $_.Exception.Response

                    if (-not $WhatIf -and $errorResponse -and $errorResponse.StatusCode -eq 410) {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Error: The destination webhook '$Destination' is no longer available!" }
                        $objStatus.Exception = $_.Exception.message
                    }
                    elseif (-not $WhatIf) {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Test event could not be sent to '$Destination'!" }
                        $objStatus.Exception = $_.Exception.message
                    }
                }
            }
        }

        if (-not $WhatIf) { [void] $SendWebhookTestStatus.add($objStatus) }

    }


    end {

        if ($SendWebhookTestStatus.Count -gt 0) {

            $SendWebhookTestStatus = Invoke-RepackageObjectWithType -RawObject $SendWebhookTestStatus -ObjectName "GL.objStatus.NSDE"    
            Return $SendWebhookTestStatus
        }


    }
}

Function Remove-HPEGLWebhook {
    <#
    .SYNOPSIS
    Removes a webhook resource from the workspace.

    .DESCRIPTION
    This Cmdlet removes a webhook resource from the workspace using its name property.

    Before attempting removal, the cmdlet checks whether any event subscriptions are still associated with the webhook.
    If subscriptions exist, the removal is blocked and a Warning status is returned, because the HPE GreenLake API does not allow deleting a webhook that has active subscriptions.
    Use 'Remove-HPEGLWebhookSubscription' to remove all subscriptions first, then retry the removal.

    .PARAMETER Name 
    The name of the webhook to remove. 

    .PARAMETER WhatIf
    Displays the raw REST API call that would be made to HPE GreenLake instead of executing the request. This option is useful for understanding the inner workings of the native REST API calls used by the cmdlet.

    .EXAMPLE
    Remove-HPEGLWebhook -Name "Webhook for server alerts" 
    
    Removes the webhook named 'Webhook for server alerts' from the workspace.

    .EXAMPLE
    Get-HPEGLWebhook -Name "Webhook for server alerts" | Remove-HPEGLWebhook 

    Removes the webhook named 'Webhook for server alerts' from the workspace.

    .EXAMPLE
    Get-HPEGLWebhook | Remove-HPEGLWebhook 

    Removes all webhooks from the workspace.

    .EXAMPLE
    "POSH_webhook_Alert", "POSH_webhook_firmwarebundle" | Remove-HPEGLWebhook 
    
    Removes the webhooks named 'POSH_webhook_Alert' and 'POSH_webhook_firmwarebundle' from the workspace.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the webhooks's names.

    System.Collections.ArrayList
        A list of webhooks retrieved from 'Get-HPEGLWebhook'. 

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following properties:  
        * Name - The name of the webhook attempted to be removed.
        * Status - The status of the removal attempt (Failed for HTTP error; Complete if removal is successful; Warning if no action is needed).
        * Details - Additional information about the status.
        * Exception - Information about any exceptions generated during the operation.
    
   #>

    [CmdletBinding()]
    Param( 

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $RemoveWebhookStatus = [System.Collections.ArrayList]::new()
        
    }
    
    Process {
        
        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
              
        try {
            $WebhookResource = Get-HPEGLWebhook -Name $Name
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }
        
        # Build object for the output
        $objStatus = [pscustomobject]@{
            
            Name      = $Name
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }
        
        $WebhookID = $WebhookResource.id

        
        if (-not $WebhookID) {

            if ($WhatIf) {
                
                $ErrorMessage = "Webhook '{0}': Resource cannot be found in the workspace!" -f $Name
                Write-Warning "$ErrorMessage Cannot display API request."
                return

            }
            else {

                $objStatus.Status = "Warning"
                $objStatus.Details = "Webhook cannot be found in the workspace!"

            }

        }
        else {

            # Pre-check: block removal if active subscriptions exist
            try {
                $Subscriptions = Get-HPEGLWebhookSubscription -WebhookName $Name
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }

            if ($Subscriptions) {
                $SubCount = @($Subscriptions).Count
                $ErrorMessage = "Webhook '{0}': Cannot be removed because it has {1} active event subscription{2}. Remove all subscriptions first using Remove-HPEGLWebhookSubscription, then retry." -f $Name, $SubCount, $(if ($SubCount -gt 1) { 's' } else { '' })
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

            $Uri = (Get-GLWebhooksUri) + "/" + $WebhookID

            # Removal task  
            try {
                $Response = Invoke-HPEGLWebRequest -Uri $Uri -method DELETE -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                if (-not $WhatIf) {

                    "[{0}] Webhook removal raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose

                    "[{0}] Webhook '{1}' successfully deleted from the workspace" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name | Write-Verbose
                    
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Webhook successfully deleted."

                }

            }
            catch {

                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Webhook cannot be deleted!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                }
            }           

            } # end else (no subscriptions)
        }
        if (-not $WhatIf) { [void] $RemoveWebhookStatus.add($objStatus) }

    }

    end {

        if ($RemoveWebhookStatus.Count -gt 0) {

            $RemoveWebhookStatus = Invoke-RepackageObjectWithType -RawObject $RemoveWebhookStatus -ObjectName "GL.objStatus.NSDE"    
            Return $RemoveWebhookStatus
        }


    }
}

Function Get-HPEGLWebhookSubscription {
    <#
    .SYNOPSIS
    Retrieve event subscriptions in the workspace.

    .DESCRIPTION
    This Cmdlet retrieves event subscriptions configured in the workspace.
    Optionally filter by webhook name to show only subscriptions for a specific webhook.

    .PARAMETER WebhookName
    An optional parameter to filter subscriptions by a specific webhook name.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to HPE GreenLake instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by the cmdlet.

    .EXAMPLE
    Get-HPEGLWebhookSubscription

    Returns all event subscriptions in the workspace.

    .EXAMPLE
    Get-HPEGLWebhookSubscription -WebhookName "Webhook for audit log events"

    Returns all event subscriptions associated with the webhook named 'Webhook for audit log events'.

    .INPUTS
    None. You cannot pipe objects to this Cmdlet.

   #>
    [CmdletBinding()]
    Param(

        [ValidateNotNullOrEmpty()]
        [String]$WebhookName,

        [Switch]$WhatIf

    )

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $Uri = Get-GLSubscriptionsUri

        if ($WebhookName) {

            try {
                $WebhookResource = Get-HPEGLWebhook -Name $WebhookName
                $WebhookID = $WebhookResource.id
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }

            if (-not $WebhookID) {
                "[{0}] Webhook '{1}' cannot be found in the workspace." -f $MyInvocation.InvocationName.ToString().ToUpper(), $WebhookName | Write-Verbose
                return
            }

            $encodedFilter = [uri]::EscapeDataString("webhookId eq '$WebhookID'")
            $Uri = $Uri + "?filter=" + $encodedFilter

        }

        try {
            [Array]$CollectionList = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference -ErrorAction Stop
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        $ReturnData = @()

        if ($Null -ne $CollectionList) {

            # Enrich each subscription with the webhook name
            if ($WebhookName) {
                # Already filtered by webhook — all subscriptions belong to the same webhook
                foreach ($sub in $CollectionList) {
                    $sub | Add-Member -NotePropertyName 'webhookName' -NotePropertyValue $WebhookName -Force
                }
            }
            else {
                # Build a webhook ID → name lookup to resolve names for all subscriptions
                $WebhookLookup = @{}
                try {
                    $AllWebhooks = Get-HPEGLWebhook
                    foreach ($wh in $AllWebhooks) {
                        $WebhookLookup[$wh.id] = $wh.name
                    }
                }
                catch { }

                foreach ($sub in $CollectionList) {
                    $whId = $sub.webhook.resourceUri -replace '.*/webhooks/', ''
                    $sub | Add-Member -NotePropertyName 'webhookName' -NotePropertyValue ($WebhookLookup[$whId]) -Force
                }
            }

            $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "GL.WebhookSubscriptions"
            $ReturnData = $ReturnData | Sort-Object webhookName, friendlyName
            return $ReturnData

        }
        else {

            return

        }
    }
}

Function Add-HPEGLWebhookSubscription {
    <#
    .SYNOPSIS
    Adds an event subscription to a webhook in the workspace.

    .DESCRIPTION
    This Cmdlet subscribes a webhook to an event type, enabling the webhook to receive events of that type.
    An optional event filter can be specified to limit which events are delivered using OData-style filter expressions.

    Up to 5 event subscriptions can be configured per webhook.

    .PARAMETER WebhookName
    Specifies the name of the webhook to subscribe to the event.

    .PARAMETER EventType
    Specifies the event type to subscribe to. Event types follow the pattern:
    'com.hpe.greenlake.<api-group>.<version>.<resource>.<event>'
    The API validates the event type against the catalog of registered event types for your workspace.
    Only event types supported by the services subscribed in your workspace are accepted.
    Use the HPE GreenLake event catalog (https://developer.greenlake.hpe.com/docs/greenlake/services) to find available event types for your subscribed services.
    Confirmed working examples:
    - 'com.hpe.greenlake.audit-log.v1.logs.created'
    - 'com.hpe.greenlake.subscriptions.v1.expiring-subscriptions'

    .PARAMETER EventFilter
    An optional OData-style filter expression to control which events are delivered to the webhook.
    Examples:
    - "status eq 'active'"
    - "quantity lt 10"
    Leave blank to receive all events of the specified event type.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to HPE GreenLake instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by the cmdlet.

    .EXAMPLE
    Add-HPEGLWebhookSubscription -WebhookName "Webhook for audit log events" `
    -EventType "com.hpe.greenlake.audit-log.v1.logs.created"

    Subscribes the webhook to receive all audit log created events.

    .EXAMPLE
    Add-HPEGLWebhookSubscription -WebhookName "Webhook for subscription alerts" `
    -EventType "com.hpe.greenlake.subscriptions.v1.expiring-subscriptions" `
    -EventFilter "quantity lt 10"

    Subscribes the webhook to receive expiring subscription events where the subscription quantity is less than 10 (i.e., running low).

    .INPUTS
    None. You cannot pipe objects to this Cmdlet.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:
        * Name - Name of the webhook for which the subscription was attempted
        * Status - Status of the operation (Failed for http error return; Complete if successful; Warning if no action is needed)
        * Details - More information about the status
        * Exception - Information about any exceptions generated during the operation.

   #>

    [CmdletBinding()]
    Param(

        [Parameter (Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$WebhookName,

        [Parameter (Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$EventType,

        [ValidateNotNullOrEmpty()]
        [String]$EventFilter,

        [Switch]$WhatIf

    )

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $AddSubscriptionStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{

            Name      = $WebhookName
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

        try {
            $WebhookResource = Get-HPEGLWebhook -Name $WebhookName
            $WebhookID = $WebhookResource.id
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if (-not $WebhookID) {

            if ($WhatIf) {
                Write-Warning "Webhook '$WebhookName': Resource cannot be found in the workspace! Cannot display API request."
                return
            }

            $objStatus.Status = "Warning"
            $objStatus.Details = "Webhook cannot be found in the workspace!"

        }
        else {

            $WebhookResourceUri = $WebhookResource.resourceUri

            # Check if a subscription for this event type already exists
            try {
                $ExistingSubscriptions = Get-HPEGLWebhookSubscription -WebhookName $WebhookName
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }

            $DuplicateSubscription = $ExistingSubscriptions | Where-Object { $_.eventType -ieq $EventType }

            if ($DuplicateSubscription) {

                if ($WhatIf) {
                    Write-Warning "Webhook '$WebhookName': A subscription for event type '$EventType' already exists! No action needed. Cannot display API request."
                    return
                }

                $objStatus.Status = "Warning"
                $objStatus.Details = "A subscription for event type '$EventType' already exists on this webhook! No action needed."

            }
            else {

                $payloadObj = @{
                    eventType = $EventType
                    webhook   = @{ resourceUri = $WebhookResourceUri }
                }

                if ($EventFilter) {
                    $payloadObj.eventFilter = $EventFilter
                }

                $payload = ConvertTo-Json @($payloadObj) -Depth 5

                $Uri = Get-GLSubscriptionsUri

                try {
                    $Response = Invoke-HPEGLWebRequest -Uri $Uri -Method POST -Body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

                    if (-not $WhatIf) {

                        "[{0}] Subscription creation raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose

                        "[{0}] Subscription for event type '{1}' successfully added to webhook '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $EventType, $WebhookName | Write-Verbose

                        $objStatus.Status = "Complete"
                        $objStatus.Details = "Subscription for event type '$EventType' successfully added to the webhook."

                    }
                }
                catch {

                    if (-not $WhatIf) {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Subscription cannot be created!" }
                        $objStatus.Exception = $Global:HPECOMInvokeReturnData
                    }
                }
            }
        }

        if (-not $WhatIf) { [void] $AddSubscriptionStatus.add($objStatus) }

    }

    end {

        if ($AddSubscriptionStatus.Count -gt 0) {

            $AddSubscriptionStatus = Invoke-RepackageObjectWithType -RawObject $AddSubscriptionStatus -ObjectName "GL.objStatus.NSDE"
            Return $AddSubscriptionStatus
        }

    }
}

Function Remove-HPEGLWebhookSubscription {
    <#
    .SYNOPSIS
    Removes an event subscription from a webhook in the workspace.

    .DESCRIPTION
    This Cmdlet removes an event type subscription from a webhook.
    If no EventType is specified, all subscriptions for the webhook are removed.

    .PARAMETER WebhookName
    Specifies the name of the webhook from which to remove the subscription.

    .PARAMETER EventType
    Specifies the event type subscription to remove. Event types follow the pattern:
    'com.hpe.greenlake.<api-group>.<version>.<resource>.<event>'
    If not provided, all subscriptions for the webhook are removed.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to HPE GreenLake instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by the cmdlet.

    .EXAMPLE
    Remove-HPEGLWebhookSubscription -WebhookName "Webhook for audit log events" `
    -EventType "com.hpe.greenlake.audit-log.v1.logs.created"

    Removes the audit log subscription from the webhook named 'Webhook for audit log events'.

    .EXAMPLE
    Remove-HPEGLWebhookSubscription -WebhookName "Webhook for audit log events"

    Removes all event subscriptions from the webhook named 'Webhook for audit log events'.

    .EXAMPLE
    Get-HPEGLWebhook | Remove-HPEGLWebhookSubscription

    Removes all event subscriptions from all webhooks in the workspace.

    .EXAMPLE
    "POSH_GL_webhook_audit-log", "POSH_GL_webhook_subscriptions" | Remove-HPEGLWebhookSubscription

    Removes all event subscriptions from the two named webhooks.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing webhook names.

    System.Collections.ArrayList
        List of webhooks from 'Get-HPEGLWebhook'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:
        * Name - Name of the webhook
        * Status - Status of the removal attempt (Failed for http error; Complete if successful; Warning if no action is needed)
        * Details - Additional information about the status
        * Exception - Information about any exceptions generated during the operation.

   #>

    [CmdletBinding()]
    Param(

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('name')]
        [ValidateNotNullOrEmpty()]
        [String]$WebhookName,

        [ValidateNotNullOrEmpty()]
        [String]$EventType,

        [Switch]$WhatIf

    )

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $RemoveSubscriptionStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{

            Name      = $WebhookName
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

        try {
            $Subscriptions = Get-HPEGLWebhookSubscription -WebhookName $WebhookName
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if ($EventType) {
            $Subscriptions = @($Subscriptions | Where-Object { $_.eventType -ieq $EventType })
        }

        if (-not $Subscriptions -or $Subscriptions.Count -eq 0) {

            $msgPart = if ($EventType) { "for event type '$EventType'" } else { "(any)" }

            if ($WhatIf) {
                Write-Warning "Webhook '$WebhookName': No subscription $msgPart found in the workspace! Cannot display API request."
                return
            }

            $objStatus.Status = "Warning"
            $objStatus.Details = "No subscription $msgPart found for this webhook."

        }
        else {

            foreach ($Subscription in $Subscriptions) {

                $SubscriptionUri = (Get-GLSubscriptionsUri) + "?id=" + $Subscription.id

                try {
                    Invoke-HPEGLWebRequest -Uri $SubscriptionUri -Method DELETE -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | Out-Null
                }
                catch {

                    if (-not $WhatIf) {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Subscription '$($Subscription.eventType)' cannot be removed!" }
                        $objStatus.Exception = $Global:HPECOMInvokeReturnData
                    }
                }
            }

            if (-not $WhatIf -and (-not $objStatus.Status)) {
                $removedMsg = if ($EventType) { "Subscription for event type '$EventType' successfully removed." } else { "$($Subscriptions.Count) subscription(s) successfully removed." }
                $objStatus.Status = "Complete"
                $objStatus.Details = $removedMsg
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $removedMsg | Write-Verbose
            }
        }

        if (-not $WhatIf) { [void] $RemoveSubscriptionStatus.add($objStatus) }

    }

    end {

        if ($RemoveSubscriptionStatus.Count -gt 0) {

            $RemoveSubscriptionStatus = Invoke-RepackageObjectWithType -RawObject $RemoveSubscriptionStatus -ObjectName "GL.objStatus.NSDE"
            Return $RemoveSubscriptionStatus
        }

    }
}

Function Confirm-HPEGLWebhookEndpoint {
    <#
    .SYNOPSIS
    Verifies that the webhook endpoint URL is accessible and ready to receive events.

    .DESCRIPTION
    This Cmdlet verifies the destination endpoint of an existing webhook to confirm it is reachable
    and the receiving server is properly configured to accept webhook requests from HPE GreenLake.

    This is useful to validate a webhook endpoint after creation or after making changes to the destination server.

    .PARAMETER Name 
    The name of the webhook whose endpoint to verify.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to HPE GreenLake instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by the cmdlet.

    .EXAMPLE
    Confirm-HPEGLWebhookEndpoint -Name "Webhook for audit log events"

    Verifies the destination endpoint of the webhook named 'Webhook for audit log events'.

    .EXAMPLE
    Get-HPEGLWebhook | Confirm-HPEGLWebhookEndpoint

    Verifies the destination endpoints of all webhooks in the workspace.

    .EXAMPLE
    "Webhook for audit log events", "Webhook for subscription alerts" | Confirm-HPEGLWebhookEndpoint

    Verifies the destination endpoints of the two named webhooks.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the webhooks's names.

    System.Collections.ArrayList
        List of webhooks from 'Get-HPEGLWebhook'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - The name of the webhook used for the endpoint verification.
        * Status - The status of the verification attempt (Failed for HTTP error return; Complete if successful; Warning if no action is needed). 
        * Details - Additional information about the status. 
        * Exception - Information about any exceptions generated during the operation.
    
   #>

    [CmdletBinding()]
    Param( 
        
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $ConfirmEndpointStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Name      = $Name
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

        try {
            $WebhookResource = Get-HPEGLWebhook -Name $Name
            $WebhookID = $WebhookResource.id
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if (-not $WebhookID) {

            "[{0}] Webhook '{1}' cannot be found in the workspace." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "Webhook '{0}' cannot be found in the workspace!" -f $Name
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "Webhook cannot be found in the workspace!"
            }
        }
        else {

            "[{0}] Webhook '{1}' found with ID: '{2}'. Verifying endpoint." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $WebhookID | Write-Verbose

            $Uri = (Get-GLWebhooksUri) + "/" + $WebhookID + "/verify"

            try {
                $Response = Invoke-HPEGLWebRequest -Uri $Uri -method POST -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                if (-not $WhatIf) {

                    "[{0}] Webhook endpoint verification raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose

                    "[{0}] Webhook '{1}' endpoint verified successfully." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Webhook endpoint verified successfully."

                }
            }
            catch {
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Webhook endpoint verification failed!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                }
            }           
        }

        if (-not $WhatIf) { [void] $ConfirmEndpointStatus.add($objStatus) }

    }

    end {

        if ($ConfirmEndpointStatus.Count -gt 0) {

            $ConfirmEndpointStatus = Invoke-RepackageObjectWithType -RawObject $ConfirmEndpointStatus -ObjectName "GL.objStatus.NSDE"    
            Return $ConfirmEndpointStatus
        }

    }
}

Function Invoke-HPEGLWebhookDeliveryRetry {
    <#
    .SYNOPSIS
    Retries a failed webhook delivery.

    .DESCRIPTION
    This Cmdlet submits a retry request for a specific failed webhook delivery.
    
    Use 'Get-HPEGLWebhook -Name <name> -ShowRecentDeliveries' to list recent deliveries and identify
    failures eligible for retry (those with 'RetryStatus' set to 'RETRY'). The 'FailureId' of a
    retryable delivery can then be passed directly or through the pipeline to this cmdlet.

    .PARAMETER Name
    The name of the webhook that owns the delivery failure.

    .PARAMETER FailureId
    The unique identifier of the delivery failure to retry. This is the 'failureId' property
    of a delivery object returned by 'Get-HPEGLWebhook -ShowRecentDeliveries'.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to HPE GreenLake instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by the cmdlet.

    .EXAMPLE
    Invoke-HPEGLWebhookDeliveryRetry -Name "Webhook for audit log events" -FailureId "a4831e24-c536-4719-88ca-2afe5a959237"

    Retries the specified delivery failure for the webhook named 'Webhook for audit log events'.

    .EXAMPLE
    Get-HPEGLWebhook -Name "Webhook for audit log events" -ShowRecentDeliveries | Where-Object { $_.retryStatus -eq "RETRY" } | Invoke-HPEGLWebhookDeliveryRetry

    Retries all eligible failed deliveries for the webhook named 'Webhook for audit log events'.

    .EXAMPLE
    Get-HPEGLWebhook -Name "Webhook for audit log events" -ShowRecentDeliveries | Where-Object { $_.retryStatus -eq "RETRY" } | Invoke-HPEGLWebhookDeliveryRetry -WhatIf

    Shows the REST API calls that would be made to retry all eligible failed deliveries without actually submitting them.

    .INPUTS
    System.Collections.ArrayList
        List of recent webhook deliveries from 'Get-HPEGLWebhook -ShowRecentDeliveries'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - The name of the webhook.
        * Status - The status of the retry attempt (Failed for HTTP error return; Complete if successful; Warning if no action is needed). 
        * Details - Additional information about the status. 
        * Exception - Information about any exceptions generated during the operation.
    
   #>

    [CmdletBinding()]
    Param( 
        
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("webhookName")]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Parameter (ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String]$FailureId,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $DeliveryRetryStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Name      = $Name
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

        if (-not $FailureId) {

            "[{0}] No FailureId provided for webhook '{1}'." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "No failure ID provided for webhook '{0}'!" -f $Name
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "No failure ID provided. Delivery cannot be retried."
            }
        }
        else {

            try {
                $WebhookResource = Get-HPEGLWebhook -Name $Name
                $WebhookID = $WebhookResource.id
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }

            if (-not $WebhookID) {

                "[{0}] Webhook '{1}' cannot be found in the workspace." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

                if ($WhatIf) {
                    $ErrorMessage = "Webhook '{0}' cannot be found in the workspace!" -f $Name
                    Write-Warning "$ErrorMessage Cannot display API request."
                    return
                }
                else {
                    $objStatus.Status = "Warning"
                    $objStatus.Details = "Webhook cannot be found in the workspace!"
                }
            }
            else {

                "[{0}] Webhook '{1}' found with ID: '{2}'. Retrying delivery failure '{3}'." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $WebhookID, $FailureId | Write-Verbose

                $Uri = (Get-GLWebhooksUri) + "/" + $WebhookID + "/delivery-failures/" + $FailureId + "/retry"

                try {
                    $Response = Invoke-HPEGLWebRequest -Uri $Uri -method POST -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                    if (-not $WhatIf) {

                        "[{0}] Delivery retry raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose

                        "[{0}] Delivery failure '{1}' retry successfully submitted for webhook '{2}'." -f $MyInvocation.InvocationName.ToString().ToUpper(), $FailureId, $Name | Write-Verbose

                        $objStatus.Status = "Complete"
                        $objStatus.Details = "Delivery retry for failure ID '{0}' successfully submitted." -f $FailureId

                    }
                }
                catch {
                    if (-not $WhatIf) {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Delivery retry failed!" }
                        $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                    }
                }           

            }

        }

        if (-not $WhatIf) { [void] $DeliveryRetryStatus.add($objStatus) }

    }

    end {

        if ($DeliveryRetryStatus.Count -gt 0) {

            $DeliveryRetryStatus = Invoke-RepackageObjectWithType -RawObject $DeliveryRetryStatus -ObjectName "GL.objStatus.NSDE"    
            Return $DeliveryRetryStatus
        }

    }
}

# Private functions (not exported)
function Invoke-RestMethodWhatIf {   
    Param   (   
        $Uri,
        $Method,
        $Headers,
        $Websession,
        $ContentType,
        $Body,
        [ValidateSet ('Invoke-HPEGLWebRequest', 'Invoke-HPEGLWebRequest', 'Invoke-RestMethod', 'Invoke-WebRequest')]
        $Cmdlet
    )
    process {
        if ( -not $Body ) {
            $Body = 'No Body provided'
        }
        Write-Warning "You have selected the '-WhatIf' option; therefore, the call will not be made. Instead, you will see a preview of the REST API call."
        Write-host "The cmdlet executed for this call will be:" 
        write-host  "$Cmdlet" -ForegroundColor green
        Write-host "The URI for this call will be:" 
        write-host  "$Uri" -ForegroundColor green
        Write-host "The Method of this call will be:"
        write-host -ForegroundColor green $Method

        if ($headers) {
            Write-host "The Header for this call will be:"
            $headerString = ($Headers | ConvertTo-Json) -Replace 'Bearer \S+', 'Bearer [REDACTED]' | Out-String
            $headerString = $headerString.TrimEnd("`r", "`n")
            Write-host -ForegroundColor green $headerString
        }
        if ($websession) {
            Write-host "The Websession for this call will be:"
            $websessionString = ($websession.headers | ConvertTo-Json) -Replace 'Bearer \S+', 'Bearer [REDACTED]' | Out-String
            $websessionString = $websessionString.TrimEnd("`r", "`n")
            write-host -ForegroundColor green $websessionString
        }
        if ( $ContentType ) {
            write-host "The Content-Type is set to:"
            write-host -ForegroundColor green $ContentType
        }  
        if ( $Body ) {
            write-host "The Body of this call will be:"
            write-host -foregroundcolor green ($Body -Replace '"access_token"\s*:\s*"[^"]+"', '"access_token": "[REDACTED]"' | Out-String)
        }
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
Export-ModuleMember -Function 'Get-HPEGLWebhook', 'New-HPEGLWebhook', 'Set-HPEGLWebhook', 'Send-HPEGLWebhookTest', 'Remove-HPEGLWebhook', 'Get-HPEGLWebhookSubscription', 'Add-HPEGLWebhookSubscription', 'Remove-HPEGLWebhookSubscription', 'Confirm-HPEGLWebhookEndpoint', 'Invoke-HPEGLWebhookDeliveryRetry' -Alias *



# SIG # Begin signature block
# MIIn2gYJKoZIhvcNAQcCoIInyzCCJ8cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAZUgn/ifZ21aTZ
# A4BsBR7H9LsV/5WuMcok3ZvxdmWlEKCCDIMwggYaMIIEAqADAgECAhBiHW0MUgGe
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
# +BhFboXenYJ6mnI1mobg+0JDadCbqOoiln6MEIq93McwDQYJKoZIhvcNAQEBBQAE
# ggIA08I/8YxsgFvGJzByqZXp6qWJw4AoyfPVhUFJ2fVxXgVjNcEZknNIptENI+Go
# bPAYJoOzbKDwL8YBk2oSb9UWjnHKXchjZai12LOob05WriN6loiGGc7aWq7xZhjG
# kk/NGu4VUI71ZocqTk5kQQbEaf1ZrirEmNW94wocC49u8gpfvf6qQjPZeAPOpMhJ
# TVGJqXjC61ib3X+CAEkOBt3mmB+B2KMddfm0QxZvXdDIwuY+stxVu4r4TqMxIB/q
# s1E3OM4ftu3fVDI+wp+XyMKOrdwf0jvnIpOZ1zAjj2kLe6hatYWSz1UsEw1QM+qL
# dGhjK3xlxwtOnir/gGGaFOQar/jIZVhWJORh7V4Fzqon1gPzwgwmVx6RGMMDdEWA
# f+MLYbWyMs6Lvf0nUNReD2qlN+5wFlvWPv/Ncj+j8L/x+UiAoA1KsOIIjfe3KfDE
# ddyZD2vYytMWG7m+hrl5r8/OUeF5p8Qw+9dCPIWlBSwJ+Ctqy7F8yD/7bWBaVP6G
# AFeoKkCMV+lWRlF+Zucvnb+mDB5zjBWY2SeazHA/bj1ZbEOsu+/oy3c02YJQzuHU
# B/9VT7TeASYGzZBx1J71EY0j4lKq5gOhcRXeS6tTee174GA8xsv65yg+38nyQFsb
# tJv3XLdBexJGr8ZeGWtUwQnugA6b4qalOQCxR4REZGM+8XehgheXMIIXkwYKKwYB
# BAGCNwMDATGCF4Mwghd/BgkqhkiG9w0BBwKgghdwMIIXbAIBAzEPMA0GCWCGSAFl
# AwQCAgUAMIGHBgsqhkiG9w0BCRABBKB4BHYwdAIBAQYJYIZIAYb9bAcBMEEwDQYJ
# YIZIAWUDBAICBQAEMEqmcqMZgTPo/oe+Q8XJFk6DTJOSLDDB0+C3Bl5uljamZi7Q
# +yLrjTFMuOqRoBPSDwIQI2xsCViaauyJox4dU/jImxgPMjAyNjExMDQwODI3MDda
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
# SIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjYxMTA0MDgy
# NzA3WjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBTpqKcjtIUE9eDhQ4tnPs6HzyxQ
# mzA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCBxHdd7HC5xsmHXVY1pnAB3yX0SAzCa
# YI7cEFY0wVBQezA/BgkqhkiG9w0BCQQxMgQwca6uCpDJkDotkPAFxFr6n5OnK7vv
# bjmEkQkMfXsTqBFdpD21aLqOU+9UN5epx8ugMA0GCSqGSIb3DQEBAQUABIICAKL0
# o8DikWl671/SZb4G8b3UKoQuNf18VFMpad/YV9ImXCxcStfNT9vArpHp3WRW6zmo
# 3d6hNK0wCTSLnWHYeNiGzoNmpvYzysK33w30zxe2Ag/cb86it0aMECyv/bqr3qQL
# g+ZRwDfP2zrPbGriylzX2ywQqd3EfQAWSIE4bUHgLHKumhe9m6qsDfGAel0ZeZj3
# h0RGvtEWFJ4DtRGjiiKM49aNfkuEbCi+GyLWStPzF4EVX++7om1Z3XIQDH/ED/M3
# bYSVwDTTYV2GpWjKaK7Ngm7EKrcY5WvAx6+OXoNxTdHaNZLfRrekTyKc6/l70Xex
# p2vlLtWFJu5D2sFvE1LGZ0YUbpw6qTVJsi0V3wMbdYUIDNlKjBjOxco33zfCNEXB
# z5VYis59+PDHtylefOJQ1i8oLE3OwQBHqlvZPNl+LlvPqE4BNcjjdCzPpPT6wLCE
# FKGckA+1zo1dLwM8Xz/5b+Hc21LTCBPFNpO1EV1LlgvR2yDc3vHYxkD22hUhMiRi
# NiHBs/84XGL3i4xWB7I4LTpu3ER9DKC0XZ9kWONRTOqd0H2YUpXdA4ZrktLtBO5M
# E08tJDOJ7H09np7AFjEo/DobQJiXAKc0EXzsSYpARggT/BODl8VY1MKql+C/wy2u
# FQ+E8bZL+5MBXKncK0RjoXuOnhtjkWXQCoPph3JI
# SIG # End signature block
