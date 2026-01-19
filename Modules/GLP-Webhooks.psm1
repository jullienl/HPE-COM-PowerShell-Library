#------------------- FUNCTIONS FOR HPE GreenLake LOGS -----------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1

# Public Functions
Function Get-HPEGLWebhook {
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
    Get-HPEGLWebhook -Region us-west 

    Returns a collection of webhooks available in the western US region.

    .EXAMPLE
    Get-HPEGLWebhook -Region us-west -Name 'Webhook event for server shutdown'

    Returns the webhook resource named 'Webhook event for server shutdown' located in the western US region. 

    .EXAMPLE
    Get-HPEGLWebhook -Region us-west -Name 'Webhook event for server shutdown' -Deliveries
    
    Returns the most recent deliveries attempted by the webhook named 'Webhook event for server shutdown'.
    
    .INPUTS
    None. You cannot pipe objects to this Cmdlet.


    
   #>
    [CmdletBinding(DefaultParameterSetName = 'Region')]
    Param( 


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
                [Array]$Webhook = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -Region $Region
                
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
            [Array]$CollectionList = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    -ErrorAction Stop
    
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

Function New-HPEGLWebhook {
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
    New-HPEGLWebhook -Region eu-central -Name "Webhook for servers that disconnect" `
    -Destination "https://hook.eu2.make.com/baea2fa0f8be4d546445c98253392058" `
    -EventFilter "type eq 'compute-ops/alert' and old/hardware/powerState eq 'ON' and changed/hardware/powerState eq True"

    This example creates a webhook named "Webhook for servers that disconnect" in the `eu-central` region. 
    The webhook will send events to the specified destination URL when a server's hardware power state changes from 'ON'. 
    The filter criteria are defined using OData syntax.

    .EXAMPLE
    New-HPEGLWebhook -Region eu-central -Name "Webhook for servers that become unhealthy" `
    -Destination "https://hook.eu2.make.com/baea2fa0f8be4d546445c98253392058" `
    -EventFilter "type eq 'compute-ops/server' and old/hardware/health/summary eq 'OK' and changed/hardware/health/summary eq True"

    This example creates a webhook named "Webhook for servers that become unhealthy" in the `eu-central` region. 
    The webhook will trigger when servers transition from a healthy state (`OK`) to an unhealthy state. 
    The events will be sent to the specified destination URL, filtered according to the provided OData criteria.

    .EXAMPLE
    New-HPEGLWebhook -Region eu-central -Name "Webhook for new activated servers" `
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
            $WebhookResource = Get-HPEGLWebhook -Region $Region -Name $Name

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
                $Response = Invoke-HPEGLWebRequest -Region $Region -Uri $Uri -method POST -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
    
                
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

Function Set-HPEGLWebhook {
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
    Set-HPEGLWebhook -Region eu-central -Name "New_webhook" -NewName "Webhook for servers that become unhealthy" `
     -Destination "https://hook.eu2.make.com/baea2fa0f8be4d546445c98253392058" `
     -EventFilter "type eq 'compute-ops/server' and old/hardware/health/summary eq 'OK' and changed/hardware/health/summary eq True"

    This example updates an existing webhook named "New_webhook" to a new name "Webhook for servers that become unhealthy" in the `eu-central` region. 
    The webhook will send events to the specified destination URL when a server's health summary transitions from `OK` to unhealthy (`True`), using the specified OData filter.

    .EXAMPLE
    Set-HPEGLWebhook -Region eu-central -Name "Webhook for servers that become unhealthy" -RetryWebhookHandshake

    This example re-initiates the verification handshake for the webhook named "Webhook for servers that become unhealthy" in the `eu-central` region.

    .EXAMPLE
    Set-HPEGLWebhook -Region eu-central -Name "Webhook for servers that become unhealthy" -Destination "https://hook.us1.make.com/wwedws2fa0f8be4d546445c98253392058"

    This example updates the destination URL for the webhook named "Webhook for servers that become unhealthy" in the `eu-central` region. 

    .EXAMPLE
    Set-HPEGLWebhook -Region eu-central -Name "Webhook for servers that become unhealthy" -EventFilter "type eq 'compute-ops/server' and old/hardware/health/summary eq 'OK' and changed/hardware/health/summary eq True"

    This example updates the OData filter configuration for the webhook named "Webhook for servers that become unhealthy" in the `eu-central` region.

    .EXAMPLE
    Get-HPEGLWebhook -Region eu-central | Set-HPEGLWebhook  -RetryWebhookHandshake 

    This example re-initiates the verification handshake for all webhooks in the `eu-central` region.

    .EXAMPLE
    "POSH_webhook_Alert", "POSH_webhook_firmwarebundle" | Set-HPEGLWebhook -Region eu-central  -RetryWebhookHandshake 

    This example re-initiates the verification handshake for the webhooks named "POSH_webhook_Alert" and "POSH_webhook_firmwarebundle" in the `eu-central` region.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the webhooks's names.

    System.Collections.ArrayList
        List of webhooks from 'Get-HPEGLWebhook'.

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
            $WebhookResource = Get-HPEGLWebhook -Region $Region -Name $Name
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
               
                $Response = Invoke-HPEGLWebRequest -Region $Region -Uri $Uri -method PATCH -body $jsonPayload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                              
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

Function Send-HPEGLWebhookTest {
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
    Send-HPEGLWebhookTest -Region eu-central -Name "Webhook event for servers that are disconnected"

    Sends a typical resource object that matches the filtering configuration (i.e. a server resource object in this case) of the existing webhook named 'Webhook event for servers that are disconnected' located in the 'eu-central' region to the destination endpoint.
    
    .EXAMPLE
    Get-HPEGLWebhook -Region eu-central | Send-HPEGLWebhookTest

    Sends a typical resource object that matches the filtering configuration of all existing webhooks in the 'eu-central' region to their respective destination endpoints.

    .EXAMPLE
    "Webhook event for servers that are disconnected", "Webhook event for servers that are unhealthy" | Send-HPEGLWebhookTest -Region eu-central

    Sends a typical resource object that matches the filtering configuration of the webhooks named 'Webhook event for servers that are disconnected' and 'Webhook event for servers that are unhealthy' located in the 'eu-central' region to their respective destination endpoints.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the webhooks's names.

    System.Collections.ArrayList
        List of webhooks from 'Get-HPEGLWebhook'.

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
            $WebhookResource = Get-HPEGLWebhook -Region $Region -Name $Name
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
                    $Object = Get-HPEGLServer -Region $Region | Select-Object -First 1
                }
                alert { 
                    $_SerialNumber = Get-HPEGLServer -Region $Region | Select-Object -First 1 | ForEach-Object serialNumber
                    $Object = Get-HPEGLServer -Region $Region -Name $_SerialNumber -ShowAlerts | Select-Object -First 1

                }                
                group { 
                    $Object = Get-HPEGLGroup -Region $Region | Where-Object { $_.devices.count -gt 1 } | Select-Object -first 1

                }                
                server-setting { 
                    $Object = Get-HPEGLSetting -Region $Region -Category Firmware | Select-Object -First 1

                }                
                job { 
                    $Object = Get-HPEGLJob -Region $Region | Select-Object -First 1

                }                
                compliance { 
                    $_name = Get-HPEGLGroup -Region $Region | Where-Object { $_.devices.count -gt 1 } | Select-Object -first 1 | ForEach-Object name
                    $Object = Get-HPEGLGroup -Region $Region -Name $_name -ShowCompliance | Select-Object -First 1

                }
                firmware-bundle { 
                    $Object = Get-HPEGLFirmwareBundle -Region $Region | Select-Object -First 1

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

Function Remove-HPEGLWebhook {
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
    Remove-HPEGLWebhook -Region eu-central -Name "Webhook for servers that become unhealthy" 
    
    Removes the webhook named 'Webhook for servers that become unhealthy' from the central EU region.

    .EXAMPLE
    Get-HPEGLWebhook -Region us-west -Name "Webhook for servers that become unhealthy" | Remove-HPEGLWebhook 

    Removes the webhook named 'Webhook for servers that become unhealthy' from the western US region.

    .EXAMPLE
    Get-HPEGLWebhook -Region eu-central | Remove-HPEGLWebhook 

    Removes all webhooks from the central EU region.

    .EXAMPLE
    "POSH_webhook_Alert", "POSH_webhook_firmwarebundle" | Remove-HPEGLWebhook -Region eu-central 
    
    Removes the webhooks named 'POSH_webhook_Alert' and 'POSH_webhook_firmwarebundle' from the central EU region.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the webhooks's names.

    System.Collections.ArrayList
        A list of webhooks retrieved from 'Get-HPEGLWebhook'. 

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
            $WebhookResource = Get-HPEGLWebhook -Region $Region -Name $Name
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
                $Response = Invoke-HPEGLWebRequest -Region $Region -Uri $Uri -method DELETE -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

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
        [ValidateSet ('Invoke-HPEGLWebRequest', 'Invoke-HPEGLWebRequest', 'Invoke-RestMethod', 'Invoke-WebRequest')]
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
Export-ModuleMember -Function 'Get-HPEGLWebhook', 'New-HPEGLWebhook', 'Set-HPEGLWebhook', 'Send-HPEGLWebhookTest', 'Remove-HPEGLWebhook' -Alias *



# SIG # Begin signature block
# MIItTgYJKoZIhvcNAQcCoIItPzCCLTsCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCsvFM3+bzJMqU7
# a8QHUu8l0jntDo1BOcMwDR5Lv36U46CCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQgd3qPi5iY9JH8wBWsPhSSxauVAkmF4lPnSjTxIPcKaqEwDQYJKoZIhvcNAQEB
# BQAEggIAtI4OCacHLG2HLpvCYzJYeQzPOPutwxvd8JoR8Xa9ojazrjMV9Ohc9bSJ
# qPVshKAJYT3N2iHRnxONxKB24IFJHFPbmIRi+Ts7FAmrUWaTgGDZp2Wy3REYSJGk
# oZ1/Qc3ntkFA+HRxdUJX/QleHp+1EDspH2STp0v97p9H8OWiRwOsXCoZ3ZVbhGP2
# uiw3T1SQFm2pZK5HQMI9YO3TxmPLD9/FXmasJubnpBjW9MZXxEPAMtnHS75wukLS
# KtD13tnLgTpD/Ukh0DPXm3ue7zdHr6fwRkr/ItI0nPUrOnbMvSel+YjICZD21skH
# dpNfglYRfwPbPyu882iF5xhE+u/a3dmYTa/z47LwfT+cOtIc7QXke+RtoEuLbhoA
# GGGEafZVWGuRshwTaNItaiHKJzLIV0kDF4euTwqM213jReGDHzK6D8lMav5gjhsN
# tb1fShyeIC45Gi1BWL/1OOHBxYjPG660McDj4SPXca9MKgLJeg7JeYMntzmpA9lt
# B0dT7luHpOIZ0pXwWx9sRyMKptAb0DcqsNezZoq1JLEZoXI8k3wV28N9SHgmujqR
# JsQ806R7DNwWpIc4rZpT6DGeby8wONWdg6GZF/vYUmhyN8NQCWitplGPdaVOyjuf
# t8vuMfhH7n37cNTUZNQkabid8ThogcKk5AxB7+O24SpydNMzYvuhgheYMIIXlAYK
# KwYBBAGCNwMDATGCF4QwgheABgkqhkiG9w0BBwKgghdxMIIXbQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIGIBgsqhkiG9w0BCRABBKB5BHcwdQIBAQYJYIZIAYb9bAcBMEEw
# DQYJYIZIAWUDBAICBQAEMD2JyUM6aLmbPbU6lf2OCv5tZ5ZmmG4vXoI0/V6A5WR7
# 4uYBY6PzAOZdlrdMaJf4qwIRALEBv2w6pDLswd/BGBpeXxQYDzIwMjYwMTE5MTgy
# NTQ3WqCCEzowggbtMIIE1aADAgECAhAMIENJ+dD3WfuYLeQIG4h7MA0GCSqGSIb3
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
# BgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI2MDEx
# OTE4MjU0N1owKwYLKoZIhvcNAQkQAgwxHDAaMBgwFgQUcrz9oBB/STSwBxxhD+bX
# llAAmHcwNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgMvPjsb2i17JtTx0bjN29j4uE
# dqF4ntYSzTyqep7/NcIwPwYJKoZIhvcNAQkEMTIEMPIrznXhMq+MxOX5d2ZqIC3Y
# oYroy4NYKE+UpYtGqfbJ9T0Nl5d/MK44jbY4L6h4QzANBgkqhkiG9w0BAQEFAASC
# AgBoOVSkD2Jmc0Ugd4SuTV0gwMxtnmEx9q1EINbRtbOjLF/s9976FAJNyqnXfd6b
# /jFJONnoVI1RWOfOK9MkiehKs8vw62Fev5CCEQTvana/2uDMA+5YUWg9A28pLJWH
# M/S1MhFRJpcgTVOhZi/xctf09hFsPffa3Q5zDlgy0SdF6dtZNz4OSU3+DFAeT2k1
# RISRCrFxKhM+qVnOtisRKENFJEzqTqiIFihuMDAaNXxs7E49wWjxc/WnPZrFVz0n
# bZRsl6d1W8mzka+T0IWHG6joHjw0+xVad0+IIXEgcp/O0tXf+rjgnblHDX+uuGP4
# vaOoMyoDjNaloYn0v0iuwPUuTcdTh7XQ6tid15Hqkelxo530As00jvx0PT4xtsdd
# TtN27g7C+G3we39mKPSuHFCCcl7bbwMlUOeRJPBwTH/okwtIUj91OuwP8YUqlBVc
# PeFliX/dLP6ASRTubaE9d2tdwBtAGl9Vvg7/c3MTnHyesrprJZ9LzPoYdNLJjEUG
# xXSvEBWMe32AUoxWb+EA1lSQsrwHNl77HHcrT5UPu/E+HSi9meGS1uyGcztC9iid
# 8dM6rWIzwaCtaKKY14p6AaCIjDUBCoCrgGO3ehjGpH2aKpZBWwJEOpAsXmH28NZz
# 0yVHmzXIgt3TltP+UbNNzZMBR1VHWxH8Dg3sSawtfr7SwA==
# SIG # End signature block
