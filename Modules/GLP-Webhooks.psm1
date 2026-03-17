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
                    $WorkspaceName = $Global:HPEGreenLakeSession.workspaceName
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
        [String]$WebhookName,

        [Parameter (Mandatory)]
        [String]$EventType,

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
        [String]$WebhookName,

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
        [String]$Name,

        [Parameter (ValueFromPipelineByPropertyName)]
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
# MIItTQYJKoZIhvcNAQcCoIItPjCCLToCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAiOBM6AhjyBkWD
# OwIAkjRP9nzlHBpssLyr8+8IWA4VDqCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# nZ+oA+rbZZyGZkz3xbUYKTGCGq0wghqpAgEBMGkwVDELMAkGA1UEBhMCR0IxGDAW
# BgNVBAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMg
# Q29kZSBTaWduaW5nIENBIFIzNgIRAMgx4fswkMFDciVfUuoKqr0wDQYJYIZIAWUD
# BAIBBQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGC
# NwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQx
# IgQgqaYkNnqQIJJHML49wiELaBY53SWmsHd5q4eglQjy17wwDQYJKoZIhvcNAQEB
# BQAEggIAE+UJnEPD+QsY+38tQfo7uZAG+erJkYg+sYJsBGxvi85qhMdgVQySnXxw
# GNbHogFOmZoSR7XWn+3yWswO1y7Kp+yIrwBgiQ/VjunZiJt+7Udt9FKsKK2IiVS2
# aAAcDg4+7OR8RUNWWI3qu7HcMspFAfmk9Vmlb+spcCy0iuHxjdSuy5v+Q28QHCQU
# kH1kRXG8cOMiULrco61wgL7PBepjAxitOBJhz8A8JoQgWhRixApUL6SsO13MtUeJ
# Fd3Vw9quC/8fJEK0aQkc5BQLN9cER8G3pe9Pg9O1zLODbDKBYhfZxGlH4QSFa4rc
# p4aqM4upXb/OfxhEG1mTZxVZDZ39mZJp0kmiI64Lf6gdwyBkw3qupsssQr30gm+f
# 4ju/cNrt8YSiSqeF6sUjaV35kqIPHwZJ9PYMyXpq8VDBhT+5s98u6/mYNk5M0ufZ
# S4Lar8bIJg0XUMYXHJRN01m4vT7SpTeWOa7g2QhUk33dvWuUxyFI4kdPFbG+lORG
# jYndEauJcrHrYbgKLOAuy0Ca05cLm+5SSMJhiaKU8OtiZY8COu3N9V8qTct1+grq
# H6ed7ypRLCBecO/BmAnPPjuMjv8V7etX3fgPE4hFysgr8OmlOAc04n30fNigaDhX
# fbnX2zXb+uxN4EOZaEjksGlU7qk5JRxHgDeeKjWaulgY8grStfahgheXMIIXkwYK
# KwYBBAGCNwMDATGCF4Mwghd/BgkqhkiG9w0BBwKgghdwMIIXbAIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIGHBgsqhkiG9w0BCRABBKB4BHYwdAIBAQYJYIZIAYb9bAcBMEEw
# DQYJYIZIAWUDBAICBQAEMPIjdawEnKbAH0qHymHkR6RwFz3L7o4ndTlziFNZ/Hzj
# v5QUhQy5NNMn7sUPkoj51wIQP/PbN1LQVuiZjKJDT40UQBgPMjAyNjAzMTcxNDM4
# NDhaoIITOjCCBu0wggTVoAMCAQICEAwgQ0n50PdZ+5gt5AgbiHswDQYJKoZIhvcN
# AQEMBQAwaTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEw
# PwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2
# IFNIQTI1NiAyMDI1IENBMTAeFw0yNTA2MDQwMDAwMDBaFw0zNjA5MDMyMzU5NTla
# MGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UE
# AxMyRGlnaUNlcnQgU0hBMzg0IFJTQTQwOTYgVGltZXN0YW1wIFJlc3BvbmRlciAy
# MDI1IDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDbOVL7i3S35ckN
# Udj680nGm/v3iwzc7hRDJyYpFeZguz5hF/O3KXxAnuf9SrE1MpaaN0UNYa/jf5ra
# iInjXLE57SwugXHwXVrPYlFNlzt2EDFud75vJ3lt/ZIRmUKu4bHFZKpulRjp0AZE
# ILIE5qIVqheGSf4vXl59yiYNKtOcDlWB32m8w77tsz61JbgnMCIhs7aYg/IIR0pi
# xyY+X5gG56dI/s0nD2JwvW1amfrW4zpbJQ2/hFzIEDP428ls1/mRMzsXjpy8HCnS
# VliKxlH3znLmxiPh7jJQFs8HHKtPlo0xn77m2KzwYOYcKmrJUtDh4sfCmKbmLBHj
# 1NER8RO2UQU5FZOQnaE47XPNUBazqO116nXZW0VmhA6EjB1R88dKwDDf3EVV68UQ
# V/a74NWvWw5XskAJj7FwbyFYh6o8ZVTCSLIFFROADsd4DElvSJCXgYMELpkEDjAY
# 39qEzEXh+4mw6zXPCQ8FKdeYeSbXwfAeAg8qTbzt0whyFnKObvMZwJhnhuKyhRhY
# v2hOBr0kJ8UxNz3KXbpcMHTOX2t1LC+I6ZphKVpFqcXzijEBieqAHLpnz3KQ+Bad
# vtJGLfU3I/fn1aGiT7fp+TLFM+NKsJa8wrunNtGDy18hGVSfGXsblsiuQ+oxsP3M
# mgHv0wcWAuvmWNTuutwvDL5wR+nMUwIDAQABo4IBlTCCAZEwDAYDVR0TAQH/BAIw
# ADAdBgNVHQ4EFgQUVZ6552fIkRBJtDZSjXm3JMU/LfgwHwYDVR0jBBgwFoAU729T
# SunkBnx6yuKQVvYv1Ensy04wDgYDVR0PAQH/BAQDAgeAMBYGA1UdJQEB/wQMMAoG
# CCsGAQUFBwMIMIGVBggrBgEFBQcBAQSBiDCBhTAkBggrBgEFBQcwAYYYaHR0cDov
# L29jc3AuZGlnaWNlcnQuY29tMF0GCCsGAQUFBzAChlFodHRwOi8vY2FjZXJ0cy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRUaW1lU3RhbXBpbmdSU0E0MDk2
# U0hBMjU2MjAyNUNBMS5jcnQwXwYDVR0fBFgwVjBUoFKgUIZOaHR0cDovL2NybDMu
# ZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGltZVN0YW1waW5nUlNBNDA5
# NlNIQTI1NjIwMjVDQTEuY3JsMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG
# /WwHATANBgkqhkiG9w0BAQwFAAOCAgEAG34LJIfYCWrFQedRadkkjuul0CqjQ9yK
# TJXjwu2TlBYWDGkc/1a2NHeWyQQA6TdOzOa43IyJ3tW7EeVAmXgpx1OvlxDZgvL6
# XnrSl4GAzuQDgcImoap1B3ONfKuWDdgJ1+eOz3D/sE7zFSaUBqr8P49Nlk74yfFr
# f8ijJiwX4v2BZfhUnFkuWNWzkkqalKiefKwxi/sJqqRCkEOYlZTYXryYstld9TTB
# dsPL1BBOySBwe+LJAN4HWXqOX9bA5CJI1M1p9hBRHZmwnms8m7U0/M7WG0rB2JSN
# Z6cfCrkFErUFHv4P5PAb3tQdfhXRb4m8VmnzPd3cbmwDs+32o7n/oBZn7TJ/yc3n
# wP4cABKEeafLbm3pbuoXpVJFkIikavyFsCN9sGE7gxjwbZT3PBUqnpKWO4qSfF3Z
# u6KE7fd2KgIawHq2tf77FAp/hCVhKCAW8P1lZIbjKwk9g7H6FuwFMQ40W2v33Ho6
# AmefJWQOi50if6CZX4Gr5rYb74EtTkBc5VyUTGm6hRBdRkXmnexSt3bVCMX1FrTH
# hEPTaBLhfCDM362+5j62OE8gLBeYfcREv588ijFlPReDBU/7XtSpRuLlml7hh1p0
# blaMJMG+2aUzglWi8ZhG/IDJ+ZgknHT/RP6orTnBEmmDirzW84q4JA9oT0f30kJW
# 98IMGbgqOsQwgga0MIIEnKADAgECAhANx6xXBf8hmS5AQyIMOkmGMA0GCSqGSIb3
# DQEBCwUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAX
# BgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0
# ZWQgUm9vdCBHNDAeFw0yNTA1MDcwMDAwMDBaFw0zODAxMTQyMzU5NTlaMGkxCzAJ
# BgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGln
# aUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAy
# NSBDQTEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC0eDHTCphBcr48
# RsAcrHXbo0ZodLRRF51NrY0NlLWZloMsVO1DahGPNRcybEKq+RuwOnPhof6pvF4u
# GjwjqNjfEvUi6wuim5bap+0lgloM2zX4kftn5B1IpYzTqpyFQ/4Bt0mAxAHeHYNn
# QxqXmRinvuNgxVBdJkf77S2uPoCj7GH8BLuxBG5AvftBdsOECS1UkxBvMgEdgkFi
# DNYiOTx4OtiFcMSkqTtF2hfQz3zQSku2Ws3IfDReb6e3mmdglTcaarps0wjUjsZv
# kgFkriK9tUKJm/s80FiocSk1VYLZlDwFt+cVFBURJg6zMUjZa/zbCclF83bRVFLe
# GkuAhHiGPMvSGmhgaTzVyhYn4p0+8y9oHRaQT/aofEnS5xLrfxnGpTXiUOeSLsJy
# goLPp66bkDX1ZlAeSpQl92QOMeRxykvq6gbylsXQskBBBnGy3tW/AMOMCZIVNSaz
# 7BX8VtYGqLt9MmeOreGPRdtBx3yGOP+rx3rKWDEJlIqLXvJWnY0v5ydPpOjL6s36
# czwzsucuoKs7Yk/ehb//Wx+5kMqIMRvUBDx6z1ev+7psNOdgJMoiwOrUG2ZdSoQb
# U2rMkpLiQ6bGRinZbI4OLu9BMIFm1UUl9VnePs6BaaeEWvjJSjNm2qA+sdFUeEY0
# qVjPKOWug/G6X5uAiynM7Bu2ayBjUwIDAQABo4IBXTCCAVkwEgYDVR0TAQH/BAgw
# BgEB/wIBADAdBgNVHQ4EFgQU729TSunkBnx6yuKQVvYv1Ensy04wHwYDVR0jBBgw
# FoAU7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQM
# MAoGCCsGAQUFBwMIMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDov
# L29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6
# MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVk
# Um9vdEc0LmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJ
# KoZIhvcNAQELBQADggIBABfO+xaAHP4HPRF2cTC9vgvItTSmf83Qh8WIGjB/T8Ob
# XAZz8OjuhUxjaaFdleMM0lBryPTQM2qEJPe36zwbSI/mS83afsl3YTj+IQhQE7jU
# /kXjjytJgnn0hvrV6hqWGd3rLAUt6vJy9lMDPjTLxLgXf9r5nWMQwr8Myb9rEVKC
# hHyfpzee5kH0F8HABBgr0UdqirZ7bowe9Vj2AIMD8liyrukZ2iA/wdG2th9y1IsA
# 0QF8dTXqvcnTmpfeQh35k5zOCPmSNq1UH410ANVko43+Cdmu4y81hjajV/gxdEkM
# x1NKU4uHQcKfZxAvBAKqMVuqte69M9J6A47OvgRaPs+2ykgcGV00TYr2Lr3ty9qI
# ijanrUR3anzEwlvzZiiyfTPjLbnFRsjsYg39OlV8cipDoq7+qNNjqFzeGxcytL5T
# TLL4ZaoBdqbhOhZ3ZRDUphPvSRmMThi0vw9vODRzW6AxnJll38F0cuJG7uEBYTpt
# MSbhdhGQDpOXgpIUsWTjd6xpR6oaQf/DJbg3s6KCLPAlZ66RzIg9sC+NJpud/v4+
# 7RWsWCiKi9EOLLHfMR2ZyJ/+xhCx9yHbxtl5TPau1j/1MIDpMPx0LckTetiSuEtQ
# vLsNz3Qbp7wGWqbIiOWCnb5WqxL3/BAPvIXKUjPSxyZsq8WhbaM2tszWkPZPubdc
# MIIFjTCCBHWgAwIBAgIQDpsYjvnQLefv21DiCEAYWjANBgkqhkiG9w0BAQwFADBl
# MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
# d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJv
# b3QgQ0EwHhcNMjIwODAxMDAwMDAwWhcNMzExMTA5MjM1OTU5WjBiMQswCQYDVQQG
# EwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNl
# cnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwggIiMA0G
# CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz7MKnJS7J
# IT3yithZwuEppz1Yq3aaza57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS5F/WBTxS
# D1Ifxp4VpX6+n6lXFllVcq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb
# 7iDVySAdYyktzuxeTsiT+CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfISKhmV1ef
# VFiODCu3T6cw2Vbuyntd463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jHtrHEtWoY
# OAMQjdjUN6QuBX2I9YI+EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSa
# M0C/CNdaSaTC5qmgZ92kJ7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI
# 8OCiEhtmmnTK3kse5w5jrubU75KSOp493ADkRSWJtppEGSt+wJS00mFt6zPZxd9L
# BADMfRyVw4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPRiQfhvbfm
# Q6QYuKZ3AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ERElvlEFDr
# McXKchYiCd98THU/Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4KJpn15Gkv
# mB0t9dmpsh3lGwIDAQABo4IBOjCCATYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4E
# FgQU7NfjgtJxXWRM3y5nP+e6mK4cD08wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGL
# p6chnfNtyA8wDgYDVR0PAQH/BAQDAgGGMHkGCCsGAQUFBwEBBG0wazAkBggrBgEF
# BQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRw
# Oi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0Eu
# Y3J0MEUGA1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9E
# aWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwEQYDVR0gBAowCDAGBgRVHSAAMA0G
# CSqGSIb3DQEBDAUAA4IBAQBwoL9DXFXnOF+go3QbPbYW1/e/Vwe9mqyhhyzshV6p
# Grsi+IcaaVQi7aSId229GhT0E0p6Ly23OO/0/4C5+KH38nLeJLxSA8hO0Cre+i1W
# z/n096wwepqLsl7Uz9FDRJtDIeuWcqFItJnLnU+nBgMTdydE1Od/6Fmo8L8vC6bp
# 8jQ87PcDx4eo0kxAGTVGamlUsLihVo7spNU96LHc/RzY9HdaXFSMb++hUD38dglo
# hJ9vytsgjTVgHAIDyyCwrFigDkBjxZgiwbJZ9VVrzyerbHbObyMt9H5xaiNrIv8S
# uFQtJ37YOtnwtoeW/VvRXKwYw02fc7cBqZ9Xql4o4rmUMYIDjDCCA4gCAQEwfTBp
# MQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMT
# OERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2
# IDIwMjUgQ0ExAhAMIENJ+dD3WfuYLeQIG4h7MA0GCWCGSAFlAwQCAgUAoIHhMBoG
# CSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjYwMzE3
# MTQzODQ4WjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBRyvP2gEH9JNLAHHGEP5teW
# UACYdzA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCAy8+OxvaLXsm1PHRuM3b2Pi4R2
# oXie1hLNPKp6nv81wjA/BgkqhkiG9w0BCQQxMgQwHPbz83gR7QmfzMMWsy4Z1tEP
# Oh1RWy25Uy26sUDHW9K9JNq0biWh5Oos7Mx53BtRMA0GCSqGSIb3DQEBAQUABIIC
# AJvHjM16+hQeozSQ3BgScOiRGQoYPQThPQfbUz4AuRq5yBxv9um95btC4BUwOzqr
# idLc7Qzel1WmzcoKi6bdIBrybjgP6rnp+19cuznDyv7iC8WK/As6ekJe8/cLEcVh
# pAJdlFRhQ1jHCcZKub5pJKQW9hbKwCXw3gqj3BdbA21I6y8XvYU0yIU948jzOTTz
# fekn7wgCAx0ksiZmPADvGfFK12rajlzyiFnqASC0IUQLnrH3w6UUyZyC7cNHy794
# BJAcrkP6YhZHcikndANLOioWSpuwgpSxXVdJFgDAK9AC2f/pKEpL0cJiq1kIxZ7e
# rQrCOZjmdS5T6EOFBeFzDQ5/1pHKoIfw/MOHMWMnVLuDLvrxTNZXFXABAwcXI3m8
# g26pAmtDpf+ZTCfwODH7z3kJN/r5gkihYEwEvPHU6ZNe+h9Hr3WkZndRL92okJZY
# igaRj0E9KE8QqgYJl0a+8aleQEQxLHqf1VJlPTBr5B0V+CXpnf+AwG1IrWmVxK0G
# 9qSCfnRj2643P5F/q6OeZMRWDO6Qh3u8p3lSnnLV89bV/W3XCPB4bFefobORqeyL
# qSV+u85pCrLdBocjGETp1aBDFKdUzimbZcYhSB3P6ljltbEsQ2Jen59ndd5NmVps
# eYi4ITGRDHzF0+/6TSvzyM7JXxj8wnYUwJqETqQw8Vhf
# SIG # End signature block
