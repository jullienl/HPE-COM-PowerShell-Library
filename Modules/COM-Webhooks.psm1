#------------------- FUNCTIONS FOR COMPUTE OPS MANAGEMENT WEBHOOKS-----------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1

# Public functions
Function Get-HPECOMWebhook {
    <#
    .SYNOPSIS
    Retrieve webhook resources in the specified region.

    .DESCRIPTION
    This Cmdlet retrieves a collection of webhooks available in the specified region.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name 
    An optional parameter to specify the name of a webhook to display.

    .PARAMETER Deliveries
    An optional switch parameter to retrieve details of the most recent deliveries attempted. 
    Compute Ops Management stores the ten most recent deliveries and the five most recent failures.
    
    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMWebhook -Region us-west 

    Returns a collection of webhooks available in the western US region.

    .EXAMPLE
    Get-HPECOMWebhook -Region us-west -Name 'Webhook event for server shutdown'

    Returns the webhook resource named 'Webhook event for server shutdown' located in the western US region. 

    .EXAMPLE
    Get-HPECOMWebhook -Region us-west -Name 'Webhook event for server shutdown' -Deliveries
    
    Returns the most recent deliveries attempted by the webhook named 'Webhook event for server shutdown'.
    
    .INPUTS
    None. You cannot pipe objects to this Cmdlet.


    
   #>
    [CmdletBinding(DefaultParameterSetName = 'Region')]
    Param( 

        [Parameter (Mandatory)] 
        [ValidateScript({
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

        [Parameter (ParameterSetName = 'Region')]
        [Parameter (Mandatory, ParameterSetName = 'Deliveries')]
        [String]$Name,

        [Parameter (ParameterSetName = 'Deliveries')]
        [Switch]$Deliveries,

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
    
    }

    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        
        if ($Name -and -not $Deliveries) {
            $Uri = (Get-COMWebhooksUri) + "?filter=name eq '$Name'"
            
        }
        elseif ($Deliveries) {
            
            $Uri = (Get-COMWebhooksUri) + "?filter=name eq '$Name'"
            
            try {
                [Array]$Webhook = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region
                
                $WebhookID = $Webhook.id
                
                "[{0}] ID found for Webhook name '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $WebhookID | Write-Verbose
                
                if ($Null -eq $WebhookID) { Throw "Webhook with this name cannot be found!" }
                
                $Uri = (Get-COMWebhooksUri) + "/" + $WebhookID + "/deliveries"
                
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
                
            }
            
        }
        else {

            $Uri = Get-COMWebhooksUri     
            
        }

        try {
            [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    -ErrorAction Stop
    
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
                   
        }           
        

        $ReturnData = @()
       
        if ($Null -ne $CollectionList) {   

            # Add region to object
            $CollectionList | Add-Member -type NoteProperty -name region -value $Region
                        
            if ($Deliveries) {

                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Webhooks.Deliveries"    
            }
            else {
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Webhooks"    
                $ReturnData = $ReturnData | Sort-Object name
            }   
        
            return $ReturnData 
                
        }
        else {

            return
                
        }         
    }
}

Function New-HPECOMWebhook {
    <#
    .SYNOPSIS
    Creates a new webhook in a specified region.

    .DESCRIPTION
    This Cmdlet can be used to create a new webhook with a destination endpoint and an OData configuration for event filtering.
        
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the webhook will be created.
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace. 

    .PARAMETER Name 
    Specifies the name of the webhook to create. 
    
    .PARAMETER EventFilter  
    Specifies the OData configuration for events to receive.
    
    Filters use OData style filters as described in https://developer.greenlake.hpe.com/docs/greenlake/services/compute-ops-mgmt/public/guide/#filtering 

    The general syntax for an OData filter looks like 'property op value' with:
     - 'property' refers to the field or property to filter on in the entity.
     - 'op' is the operator, such as eq (equals), ne (not equal), gt (greater than), ge (greater or equal), lt (less than), le (less or equal), etc.
     - 'value' is the value to compare against the property.

    Filtering examples:

    - To receive webhooks for group and server events only:         
        type eq 'compute-ops/group' or type eq 'compute-ops/server'
    - To receive webhooks for all servers that are shut down:       
        type eq 'compute-ops/server' and old/hardware/powerState eq 'ON' and changed/hardware/powerState eq True
    - To receive webhooks for all servers that get disconnect from COM:
        type eq 'compute-ops/server' and old/state/connected eq True and changed/state/connected eq True
    -To receive webhooks for all jobs that run a server firmware update:
        type eq 'compute-ops/job' and contains(name, 'FirmwareUpdate.New') and new/state eq 'RUNNING'
    - To receive webhooks for all servers that transition to an unhealthy status:
        type eq 'compute-ops/server' and old/hardware/health/summary eq 'OK' and changed/hardware/health/summary eq True
    - To receive webhooks for all events within a specified group:
        type eq 'compute-ops/group' and contains(name, 'Production')
    - To receive webhooks for all new firmware bundles that are available:
        type eq 'compute-ops/firmware-bundle' and operation eq 'Created'
    - To receive webhooks for all servers added to COM that require activation:
        type eq 'compute-ops/server' and operation eq 'Created'
    - To receive webhooks for all new servers added and connected to COM:
        type eq 'compute-ops/server' and old/state/connected eq False and changed/state/connected eq True
   
    For more information about COM webhooks, see https://jullienl.github.io/Implementing-webhooks-with-COM/ 

    .PARAMETER Destination 
    Specifies the HTTPS webhook endpoint capable of receiving HTTP GET and POST requests.
    
    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    New-HPECOMWebhook -Region eu-central -Name "Webhook for servers that disconnect" `
    -Destination "https://hook.eu2.make.com/baea2fa0f8be4d546445c98253392058" `
    -EventFilter "type eq 'compute-ops/alert' and old/hardware/powerState eq 'ON' and changed/hardware/powerState eq True"

    This example creates a webhook named "Webhook for servers that disconnect" in the `eu-central` region. 
    The webhook will send events to the specified destination URL when a server's hardware power state changes from 'ON'. 
    The filter criteria are defined using OData syntax.

    .EXAMPLE
    New-HPECOMWebhook -Region eu-central -Name "Webhook for servers that become unhealthy" `
    -Destination "https://hook.eu2.make.com/baea2fa0f8be4d546445c98253392058" `
    -EventFilter "type eq 'compute-ops/server' and old/hardware/health/summary eq 'OK' and changed/hardware/health/summary eq True"

    This example creates a webhook named "Webhook for servers that become unhealthy" in the `eu-central` region. 
    The webhook will trigger when servers transition from a healthy state (`OK`) to an unhealthy state. 
    The events will be sent to the specified destination URL, filtered according to the provided OData criteria.

    .EXAMPLE
    New-HPECOMWebhook -Region eu-central -Name "Webhook for new activated servers" `
    -Destination "https://hook.eu2.make.com/baea2fa0f8be4d546445c98253392058" `
    -EventFilter "type eq 'compute-ops/server' and old/state/connected eq False and changed/state/connected eq True"

    This example creates a webhook named "Webhook for new activated servers" in the `eu-central` region. 
    This webhook will send notifications to the given destination URL whenever new servers are activated and connected to COM. 
    The filter ensures that the event captures the change in connection state from `False` to `True`.

    .INPUTS
    Pipeline input is not supported

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - Name of the webhook attempted to be created
        * Region - Name of the region where to create the webhook
        * Status - Status of the creation attempt (Failed for http error return; Complete if creation is successful; Warning if no action is needed) 
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.

   
   #>

    [CmdletBinding()]
    Param( 
        
        [Parameter (Mandatory)] 
        [ValidateScript({
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

        [Parameter (Mandatory)]
        [ValidateScript({ $_.Length -lt 256 })]
        [String]$Name,
        
        [Parameter (Mandatory)] 
        [ValidateScript({
                # Regex pattern to validate OData filter strings with multiple 'and'/'or' conditions
                if ($_ -match "^\s*([\w/]+ (eq|ne|gt|lt|ge|le) '.+'|[\w/]+ eq (true|false))(\s+(and|or)\s+([\w/]+ (eq|ne|gt|lt|ge|le) '.+'|[\w/]+ eq (true|false)))*\s*$") {
                    return $true
                }
                else {
                    throw "The filter string '$_' is not a valid OData filter."
                }
            })]
        [String]$EventFilter,
        
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
        
        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $CreateWebhookStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $Uri = Get-COMWebhooksUri

        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Name      = $Name
            Region    = $Region                            
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

        try {
            $WebhookResource = Get-HPECOMWebhook -Region $Region -Name $Name

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)

        }

        if ($WebhookResource) {
            
            "[{0}] Webhook '{1}' is already present in the '{2}' region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
    
            if ($WhatIf) {
                $ErrorMessage = "Webhook '{0}': Resource is already present in the '{1}' region! No action needed." -f $Name, $Region
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "Webhook already exists in the region! No action needed."
            }

        }
        else {

            # Build payload
            $payload = ConvertTo-Json @{
                name        = $Name
                destination = $Destination
                state       = "ENABLED"
                eventFilter = $EventFilter
                headers     = @{}
            }
                
    
            try {
                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
    
                
                if (-not $WhatIf) {
    
                    "[{0}] Webhook creation raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose
                    
                    "[{0}] Webhook '{1}' successfully created in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Region | Write-Verbose
                        
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Webhook successfully created in $Region region"
    
                }
    
            }
            catch {
    
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Webhook cannot be created!"
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                }
            }           
        }

                     
        [void] $CreateWebhookStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            $CreateWebhookStatus = Invoke-RepackageObjectWithType -RawObject $CreateWebhookStatus -ObjectName "COM.objStatus.NSDE"    
            Return $CreateWebhookStatus
        }


    }
}

Function Set-HPECOMWebhook {
    <#
    .SYNOPSIS
    Update an existing webhook in a specified region.

    .DESCRIPTION
    This Cmdlet is used to update an existing webhook to modify its destination, its OData filtering configuration, or to re-initiate the verification handshake. 
    If a parameter is not provided, the cmdlet retains the current settings and only updates the provided parameters.
        
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the webhook to be updated is located.
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name
    Specifies the name of the webhook to update.

    .PARAMETER NewName
    Specifies the new name for the webhook.

    .PARAMETER EventFilter
    Specifies the new OData filter configuration for events to receive.

    Filters use OData style filters as described in [HPE Developer Documentation](https://developer.greenlake.hpe.com/docs/greenlake/services/compute-ops-mgmt/public/guide/#filtering).

    The general syntax for an OData filter is 'property op value', where:
    - `property` refers to the field or property to filter on within the entity.
    - `op` is the operator, such as eq (equals), ne (not equal), gt (greater than), ge (greater or equal), lt (less than), le (less or equal), etc.
    - `value` is the value to compare against the property.

    Filtering examples:

    - To receive webhooks for group and server events only:         
        type eq 'compute-ops/group' or type eq 'compute-ops/server'
    - To receive webhooks for all servers that are shut down:       
        type eq 'compute-ops/server' and old/hardware/powerState eq 'ON' and changed/hardware/powerState eq True
    - To receive webhooks for all servers that get disconnect from COM:
        type eq 'compute-ops/server' and old/state/connected eq True and changed/state/connected eq True
    -To receive webhooks for all jobs that run a server firmware update:
        type eq 'compute-ops/job' and contains(name, 'FirmwareUpdate.New') and new/state eq 'RUNNING'
    - To receive webhooks for all servers that transition to an unhealthy status:
        type eq 'compute-ops/server' and old/hardware/health/summary eq 'OK' and changed/hardware/health/summary eq True
    - To receive webhooks for all events within a specified group:
        type eq 'compute-ops/group' and contains(name, 'Production')
    - To receive webhooks for all new firmware bundles that are available:
        type eq 'compute-ops/firmware-bundle' and operation eq 'Created'
    - To receive webhooks for all servers added to COM that require activation:
        type eq 'compute-ops/server' and operation eq 'Created'
    - To receive webhooks for all new servers added and connected to COM:
        type eq 'compute-ops/server' and old/state/connected eq False and changed/state/connected eq True
   
    For more information about COM webhooks, see https://jullienl.github.io/Implementing-webhooks-with-COM/ 

    .PARAMETER Destination
    Specifies the new HTTPS webhook endpoint that is able to receive HTTP GET and POST requests.

    .PARAMETER RetryWebhookHandshake
    Re-initiates the webhook verification handshake.
    
    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Set-HPECOMWebhook -Region eu-central -Name "New_webhook" -NewName "Webhook for servers that become unhealthy" `
     -Destination "https://hook.eu2.make.com/baea2fa0f8be4d546445c98253392058" `
     -EventFilter "type eq 'compute-ops/server' and old/hardware/health/summary eq 'OK' and changed/hardware/health/summary eq True"

    This example updates an existing webhook named "New_webhook" to a new name "Webhook for servers that become unhealthy" in the `eu-central` region. 
    The webhook will send events to the specified destination URL when a server's health summary transitions from `OK` to unhealthy (`True`), using the specified OData filter.

    .EXAMPLE
    Set-HPECOMWebhook -Region eu-central -Name "Webhook for servers that become unhealthy" -RetryWebhookHandshake

    This example re-initiates the verification handshake for the webhook named "Webhook for servers that become unhealthy" in the `eu-central` region.

    .EXAMPLE
    Set-HPECOMWebhook -Region eu-central -Name "Webhook for servers that become unhealthy" -Destination "https://hook.us1.make.com/wwedws2fa0f8be4d546445c98253392058"

    This example updates the destination URL for the webhook named "Webhook for servers that become unhealthy" in the `eu-central` region. 

    .EXAMPLE
    Set-HPECOMWebhook -Region eu-central -Name "Webhook for servers that become unhealthy" -EventFilter "type eq 'compute-ops/server' and old/hardware/health/summary eq 'OK' and changed/hardware/health/summary eq True"

    This example updates the OData filter configuration for the webhook named "Webhook for servers that become unhealthy" in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMWebhook -Region eu-central | Set-HPECOMWebhook  -RetryWebhookHandshake 

    This example re-initiates the verification handshake for all webhooks in the `eu-central` region.

    .EXAMPLE
    "POSH_webhook_Alert", "POSH_webhook_firmwarebundle" | Set-HPECOMWebhook -Region eu-central  -RetryWebhookHandshake 

    This example re-initiates the verification handshake for the webhooks named "POSH_webhook_Alert" and "POSH_webhook_firmwarebundle" in the `eu-central` region.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the webhooks's names.

    System.Collections.ArrayList
        List of webhooks from 'Get-HPECOMWebhook'.

    .OUTPUTS
    System.Collections.ArrayList
        Returns a custom status object or array of objects containing the following properties:
        * Name - Name of the webhook attempted to be set.
        * Region - Name of the region where the webhook is updated.
        * Status - Status of the modification attempt (Failed if an HTTP error occurs; Complete if successful; Warning if no action is needed).
        * Details - Additional information about the status.
        * Exception - Information about any exceptions generated during the operation.

      
   #>

    [CmdletBinding()]
    Param( 
        
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
        [ValidateScript({
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
        [ValidateScript({ $_.Length -lt 256 })]
        [String]$Name,

        [ValidateScript({ $_.Length -lt 256 })]
        [String]$NewName,
        
        [ValidateScript({
                # Regex pattern to validate OData filter strings with multiple 'and'/'or' conditions
                if ($_ -match "^\s*([\w/]+ (eq|ne|gt|lt|ge|le) '.+'|[\w/]+ eq (true|false))(\s+(and|or)\s+([\w/]+ (eq|ne|gt|lt|ge|le) '.+'|[\w/]+ eq (true|false)))*\s*$") {
                    return $true
                }
                else {
                    throw "The filter string '$_' is not a valid OData filter."
                }
            })]
        [String]$EventFilter,
        
        [ValidateScript({
                if ($_ -match '^https?:\/\/[a-zA-Z0-9-\.]+\.[a-z]{2,4}(/\S*)?$') {
                    return $true
                }
                else {
                    throw "The URL '$_' is not a valid HTTP/HTTPS URL."
                }
            })]
        [String]$Destination,

        [Switch]$RetryWebhookHandshake,
        
        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $SetWebhookStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        try {
            $WebhookResource = Get-HPECOMWebhook -Region $Region -Name $Name
            $WebhookID = $WebhookResource.id
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)

        }

        "[{0}] Webhook ID found: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $WebhookID | Write-Verbose


        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Name      = $Name
            Region    = $Region                            
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

        if (-not $WebhookID) {

            # Must return a message if not found
            if ($WhatIf) {
                
                $ErrorMessage = "Webhook '{0}': Resource cannot be found in the '{1}' region!" -f $Name, $Region
                Write-warning $ErrorMessage
                return
            }
            else {

                $objStatus.Status = "Failed"
                $objStatus.Details = "Webhook cannot be found in the region!"
            }
        }
        else {

            $Uri = (Get-COMWebhooksUri) + "/" + $WebhookID

            $Payload = @{}

            # Conditionally add properties
            if ($NewName) {
                $Payload.name = $NewName
            }
            else {
                $Payload.name = $Name
               
            }

            if ($Destination) {
                $Payload.destination = $Destination
            }
            else {
                $Payload.destination = $WebhookResource.destination
            }

            if ($RetryWebhookHandshake) {
                $Payload.state = "ENABLED"
            }
            else {
                $Payload.state = $WebhookResource.state
            }

            if ($EventFilter) {
                $Payload.eventFilter = $EventFilter
            }
            else {
                $Payload.eventFilter = $WebhookResource.eventFilter
            }

            # Convert the hashtable to JSON
            $jsonPayload = $Payload | ConvertTo-Json
           
            try {
               
                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method PATCH -body $jsonPayload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                              
                if (-not $WhatIf) {
                   
                    "[{0}] Webhook update raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose
                   
                    "[{0}] Webhook '{1}' successfully updated in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Region | Write-Verbose
                   
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Webhook successfully updated in $Region region"
                   
                }
                
            }
            catch {
                
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Webhook cannot be updated!"
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                }
            }           
        }


        [void] $SetWebhookStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            $SetWebhookStatus = Invoke-RepackageObjectWithType -RawObject $SetWebhookStatus -ObjectName "COM.objStatus.NSDE"    
            Return $SetWebhookStatus
        }


    }
}

Function Send-HPECOMWebhookTest {
    <#
   
    .SYNOPSIS
    Simulate a webhook by sending a typical resource object to its configured endpoint URL.

    .DESCRIPTION
    This Cmdlet can simulate a webhook by sending a resource object that matches the filtering configuration of an existing webhook to its configured endpoint URL.

    This test is useful for validating communication between COM and the webhook destination endpoint. It also helps capture data content and test the flow of your automation process.

    .PARAMETER Region 
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the webhook is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name 
    The name of the webhook to be used for the sending test. 
   
    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Send-HPECOMWebhookTest -Region eu-central -Name "Webhook event for servers that are disconnected"

    Sends a typical resource object that matches the filtering configuration (i.e. a server resource object in this case) of the existing webhook named 'Webhook event for servers that are disconnected' located in the 'eu-central' region to the destination endpoint.
    
    .EXAMPLE
    Get-HPECOMWebhook -Region eu-central | Send-HPECOMWebhookTest

    Sends a typical resource object that matches the filtering configuration of all existing webhooks in the 'eu-central' region to their respective destination endpoints.

    .EXAMPLE
    "Webhook event for servers that are disconnected", "Webhook event for servers that are unhealthy" | Send-HPECOMWebhookTest -Region eu-central

    Sends a typical resource object that matches the filtering configuration of the webhooks named 'Webhook event for servers that are disconnected' and 'Webhook event for servers that are unhealthy' located in the 'eu-central' region to their respective destination endpoints.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the webhooks's names.

    System.Collections.ArrayList
        List of webhooks from 'Get-HPECOMWebhook'.

   .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - The name of the webhook used for the sending test.
        * Region - The name of the region where the webhook is located.
        * Status - The status of the send test attempt (Failed for HTTP error return; Complete if successful; Warning if no action is needed). 
        * Details - Additional information about the status. 
        * Exception - Information about any exceptions generated during the operation.
    
   #>

    [CmdletBinding()]
    Param( 
        
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
        [ValidateScript({
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
            Region    = $Region                            
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

        try {
            $WebhookResource = Get-HPECOMWebhook -Region $Region -Name $Name
            $WebhookID = $WebhookResource.id


        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)

        }

        "[{0}] Webhook ID found: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $WebhookID | Write-Verbose

        if (-not $WebhookID) {

            # Must return a message if not found
            if ($WhatIf) {
                
                $ErrorMessage = "Webhook '{0}' cannot be found in the Compute Ops Management instance!" -f $Name
                Write-Warning $ErrorMessage
            }
            else {

                $objStatus.Status = "Failed"
                $objStatus.Details = "Webhook cannot be found in the Compute Ops Management instance!"
            }
        }
        else {

            $EventFilter = $WebhookResource.eventFilter
            $Destination = $WebhookResource.destination


            # Define the regex pattern to match the resource type of webhook filter
            $pattern = "type eq '([^']*)'"

            # Use the -match operator to apply the pattern and capture the webhook resource type value
            if ($EventFilter -match $pattern) {
                
                # Extract the full type value (e.g. 'compute-ops/server')
                $fullTypeValue = $matches[1]

                # Extract the part after the last slash (e.g. 'server')
                $typeValue = $fullTypeValue -split '/' | Select-Object -Last 1

                "[{0}] Extracted webhook resource type: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $typeValue | Write-Verbose

            }
            else {
                throw "The webhook test cannot be sent as the webhook resource type cannot be extracted from the webhook filter definition."
            }

            # Object to send creation
            switch ($typeValue) {
                server { 
                    $Object = Get-HPECOMServer -Region $Region | Select-Object -First 1
                }
                alert { 
                    $_SerialNumber = Get-HPECOMServer -Region $Region | Select-Object -First 1 | ForEach-Object serialNumber
                    $Object = Get-HPECOMServer -Region $Region -Name $_SerialNumber -ShowAlerts | Select-Object -First 1

                }                
                group { 
                    $Object = Get-HPECOMGroup -Region $Region | Where-Object { $_.devices.count -gt 1 } | Select-Object -first 1

                }                
                server-setting { 
                    $Object = Get-HPECOMSetting -Region $Region -Category Firmware | Select-Object -First 1

                }                
                job { 
                    $Object = Get-HPECOMJob -Region $Region | Select-Object -First 1

                }                
                compliance { 
                    $_name = Get-HPECOMGroup -Region $Region | Where-Object { $_.devices.count -gt 1 } | Select-Object -first 1 | ForEach-Object name
                    $Object = Get-HPECOMGroup -Region $Region -Name $_name -ShowCompliance | Select-Object -First 1

                }
                firmware-bundle { 
                    $Object = Get-HPECOMFirmwareBundle -Region $Region | Select-Object -First 1

                }

            }
         
            $jsonPayload = ConvertTo-Json -Depth 20 -InputObject $Object

            "[{0}] Webhook test object that will be sent: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $jsonPayload | Write-Verbose

            
           
            try {

                if ($WhatIf) {

                    Invoke-RestMethodWhatIf -Uri $Destination -Method POST -Body $jsonPayload -ContentType "application/json" -Cmdlet Invoke-RestMethod


                } 
                else {

                    $Response = Invoke-RestMethod -Uri $Destination -method POST -body $jsonPayload -ContentType "application/json" 
                }
               
                              
                if (-not $WhatIf) {
                   
                    "[{0}] Webhook test raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose
                   
                    "[{0}] Webhook '{1}' test successfully send to '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Destination | Write-Verbose
                   
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Webhook test successfully sent to '$Destination' using a resource object of type '$typeValue'."
                   
                }
                
            }
            catch {

                $errorResponse = $_.Exception.Response
                
                if ($errorResponse) {
                
                    $statusCode = $errorResponse.StatusCode
                
                    if (-not $WhatIf -and $statusCode -eq 410) {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Error: The destination webhook '$Destination' is no longer available!"
                        $objStatus.Exception = $_.Exception.message 

                    } 
                    elseif (-not $WhatIf) {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Webhook test sent to '$Destination' using a resource object of type '$typeValue' was not accepted!"
                        $objStatus.Exception = $_.Exception.message 
                    }
                }                  
            }


            [void] $SendWebhookTestStatus.add($objStatus)

        }
    }


    end {

        if (-not $WhatIf) {

            $SendWebhookTestStatus = Invoke-RepackageObjectWithType -RawObject $SendWebhookTestStatus -ObjectName "COM.objStatus.NSDE"    
            Return $SendWebhookTestStatus
        }


    }
}

Function Remove-HPECOMWebhook {
    <#
    .SYNOPSIS
    Removes a webhook resource from a specified region.

    .DESCRIPTION
    This Cmdlet removes a webhook resource from a specific region using its name property.

    .PARAMETER Name 
    The name of the webhook to remove. 

    .PARAMETER Region 
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the webhook should be removed.
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER WhatIf
    Displays the raw REST API call that would be made to COM instead of executing the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Remove-HPECOMWebhook -Region eu-central -Name "Webhook for servers that become unhealthy" 
    
    Removes the webhook named 'Webhook for servers that become unhealthy' from the central EU region.

    .EXAMPLE
    Get-HPECOMWebhook -Region us-west -Name "Webhook for servers that become unhealthy" | Remove-HPECOMWebhook 

    Removes the webhook named 'Webhook for servers that become unhealthy' from the western US region.

    .EXAMPLE
    Get-HPECOMWebhook -Region eu-central | Remove-HPECOMWebhook 

    Removes all webhooks from the central EU region.

    .EXAMPLE
    "POSH_webhook_Alert", "POSH_webhook_firmwarebundle" | Remove-HPECOMWebhook -Region eu-central 
    
    Removes the webhooks named 'POSH_webhook_Alert' and 'POSH_webhook_firmwarebundle' from the central EU region.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the webhooks's names.

    System.Collections.ArrayList
        A list of webhooks retrieved from 'Get-HPECOMWebhook'. 

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following properties:  
        * Name - The name of the webhook attempted to be removed.
        * Region - The name of the region where the webhook was removed.
        * Status - The status of the removal attempt (Failed for HTTP error; Complete if removal is successful; Warning if no action is needed).
        * Details - Additional information about the status.
        * Exception - Information about any exceptions generated during the operation.
    
   #>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
        [ValidateScript({
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
            $WebhookResource = Get-HPECOMWebhook -Region $Region -Name $Name
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }
        
        # Build object for the output
        $objStatus = [pscustomobject]@{
            
            Name      = $Name
            Region    = $Region                            
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }
        
        $WebhookID = $WebhookResource.id

        
        if (-not $WebhookID) {

            # Must return a message if not found
            if ($WhatIf) {
                
                $ErrorMessage = "Webhook '{0}': Resource cannot be found in the '{1}' region!" -f $Name, $Region
                Write-warning $ErrorMessage
                return

            }
            else {

                $objStatus.Status = "Failed"
                $objStatus.Details = "Webhook cannot be found in the region!"

            }

        }
        else {
            
            $Uri = (Get-COMWebhooksUri) + "/" + $WebhookID

            # Removal task  
            try {
                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method DELETE -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                if (-not $WhatIf) {

                    "[{0}] Webhook removal raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose

                    "[{0}] Webhook '{1}' successfully deleted from '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Region | Write-Verbose
                    
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Webhook successfully deleted from $Region region"

                }

            }
            catch {

                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Webhook cannot be deleted!"
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                }
            }           

        }
        [void] $RemoveWebhookStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            $RemoveWebhookStatus = Invoke-RepackageObjectWithType -RawObject $RemoveWebhookStatus -ObjectName "COM.objStatus.NSDE"    
            Return $RemoveWebhookStatus
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
        [ValidateSet ('Invoke-HPEGLWebRequest', 'Invoke-HPECOMWebRequest', 'Invoke-RestMethod', 'Invoke-WebRequest')]
        $Cmdlet
    )
    process {
        if ( -not $Body ) {
            $Body = 'No Body provided'
        }
        write-warning "You have selected the 'What-If' option; therefore, the call will not be made. Instead, you will see a preview of the REST API call."
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
Export-ModuleMember -Function 'Get-HPECOMWebhook', 'New-HPECOMWebhook', 'Set-HPECOMWebhook', 'Send-HPECOMWebhookTest', 'Remove-HPECOMWebhook' -Alias *







# SIG # Begin signature block
# MIItTQYJKoZIhvcNAQcCoIItPjCCLToCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDwF/Q/sVjIwAZC
# jMtYafq5EFAVEGoK0eEQeVH88A8UjKCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQg/e1ox/JQpzjXtMHrtU5GdIfiU4tTtBmldJfe27AhYDUwDQYJKoZIhvcNAQEB
# BQAEggIAc3siYQKTVsMn9g0EX7AQCvTbaWsriZ5obTLJNho4PdXQaS44HO+PcjZt
# 9eJ9lEGide+cQa6eXPm9srSAm5a4hxwWGqO8+ZWAcsW8umcpp03pAwpD5vfVuHVq
# DDcCIFf0k8IGoWX1ss56rp1tm/RNJalL0gDitX8Tgi8G+Tl3BieURmTw9jTo6q3c
# djA/ycn94WwWe/bGK4+unHwnIQ5JNqQqFqt6kzO0BSCuTVpC6ifRj5tyt3pNqSs5
# hJjESthSUB4eIUqum4I2mV4JIFd7Z0+D4CL37xz2PDY1zvbtGambHhpDXqJVRLIz
# OuwYfYRSJk957d1Bbix5bgzyKaFzntLoBzpUTzHFYepvtlRMUMrQP7VgnqpNfgEX
# 4SbCy2fKt6GaybcyiqF8UH6+QzRsod+A7uOopzc1ntlTgbVfYyaWy22OvIP0HCTL
# 5cPJv6eB/zsbEssCDNX62GTcKEwocqQ8Zco54V9ZduhiBmPKL2Spoh/gKdXDApl/
# UNgpqzX7FoljHoT7nd9ilbIwoUctfaCIrFcLIuAt/aVB3/vOyqPcvUbs48xUVi7M
# SDMtpfi/AnTCLBeD4bZslTqWPBCUYrJBbS2Gx++UgK8H3JNjV/fgqQibo8t3FPw8
# 79CIE9KFDSkpxD5HQQ4n58zZFYOj+b/YRtsuXTlvssTiUXalEK+hgheXMIIXkwYK
# KwYBBAGCNwMDATGCF4Mwghd/BgkqhkiG9w0BBwKgghdwMIIXbAIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIGHBgsqhkiG9w0BCRABBKB4BHYwdAIBAQYJYIZIAYb9bAcBMEEw
# DQYJYIZIAWUDBAICBQAEMI5cPrpFhWJqh6Um8NnDr5wuSAlgzroJvU5bb2VgiyGx
# 7M4CdGVw2DtCxO2zNOT7hgIQGIzLPWH71Cvt0By7wbd0bBgPMjAyNTEwMDIxNTUw
# MTFaoIITOjCCBu0wggTVoAMCAQICEAwgQ0n50PdZ+5gt5AgbiHswDQYJKoZIhvcN
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
# CSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjUxMDAy
# MTU1MDExWjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBRyvP2gEH9JNLAHHGEP5teW
# UACYdzA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCAy8+OxvaLXsm1PHRuM3b2Pi4R2
# oXie1hLNPKp6nv81wjA/BgkqhkiG9w0BCQQxMgQwNB5kmH1dEswFPKvsfh/YZ8c5
# cW/7geweo16q9z19Dd8mxw3YVZhgFaQx9GJYqXzlMA0GCSqGSIb3DQEBAQUABIIC
# ADhVkOovh62wdUEsvVNGlfBjmhxzq7XfcH9UjbPDT9B5eV5mxfPSekVAcclHViMy
# B/2kBmBMOAEK3+O13ZZM5hQVFBpL+F1PVeB4Yy7siF2Teu3s6rjEPKNCabe0lFVD
# Wc28hj53p+0qIUZurLZYvlu5KI3Tn8TzEY+LSfIwXWK23/AI4Ijl619SUUxgr1fe
# hQFcv/7C3BB8ld0RdVmlAP/DVsmkVuNbrLIoW5Pswv2V+IbDO/OnCSwviF3n9AL4
# HGfJmT/R26Z6f6pMhn0XHn37OocveHVpxqBUfHKcpy5KLXvyHqQ1tud1l+cDsh2k
# NhQQjAwFtXj5a69lNcfHwYDmB+j7WodiO8aEzFAAETCGlzf12LPUyUvZdHrbbfvY
# W1G59pU9jT2PuevowSDC048043ek/m06c81m7Oq2SPp3RWJu0SwDR5LX0huzflBC
# YdP+3Rblrye/26ka0Va2OLVeut3rDEiLFwFzX2oOsACLKaAxOvganBczUqB+BMk6
# CIPnWU/EM1qforz7teHOGnbWOw29TJPTEY1LHiG0EVmFNJHxsDagdOfLcz9cB+pN
# nTttmdqgHUZ3oEYKxS4I0BDIlEynUWF1BFNwFG4FmoAm3hUm+0ilb9/ve+84Q9Nf
# G2NDSRPrY+js0EX1a58zIr9E7fBz2MP/vk9gJpQ5rW0y
# SIG # End signature block
