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
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Webhook cannot be created!" }
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
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Webhook cannot be updated!" }
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
                    $Object = Get-HPECOMJob -Region $Region -WarningAction SilentlyContinue | Select-Object -First 1

                }                
                compliance { 
                    $_name = Get-HPECOMGroup -Region $Region | Where-Object { $_.devices.count -gt 1 } | Select-Object -first 1 | ForEach-Object name
                    $Object = Get-HPECOMGroup -Region $Region -Name $_name -ShowCompliance | Select-Object -First 1

                }
                firmware-bundle { 
                    $Object = Get-HPECOMFirmwareBaseline -Region $Region | Select-Object -First 1

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
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Error: The destination webhook '$Destination' is no longer available!" }
                        $objStatus.Exception = $_.Exception.message 

                    } 
                    elseif (-not $WhatIf) {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Webhook test sent to '$Destination' using a resource object of type '$typeValue' was not accepted!" }
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
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Webhook cannot be deleted!" }
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
        write-warning "You have selected the '-WhatIf' option; therefore, the call will not be made. Instead, you will see a preview of the REST API call."
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
# MIIungYJKoZIhvcNAQcCoIIujzCCLosCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBsfyKAXJA89zfS
# 3x/72Fd5NLLTV4c0thoaANTkm9YICaCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQgIKGO3+14zZOwdfL2kp4M0rQyfuD/6PjC78mUu9GOAXQwDQYJKoZIhvcNAQEB
# BQAEggIACJfjDp866dScpFE9kOr9P6MzYeo28viHXxkTUNDtEgBQ0jN+lWsLdIKe
# Ca4IOR6zs3LCMhpwFn4JWR1WEJh4PWfOBIAmanb1jaGr2UON/euyq9dThc+dhDjp
# ZkHb4Y5K+wuCAApTAf6DpU1+YTYwe7o9hMNkMbgx9a/I213QhdstdpzGk4XyDcRn
# 8Ehr1MX97pONuqVBl3TGOgg71cIAU6mnNO9llRSs7UP+6YxGATXXFoXMM1xmJZUY
# VIqoBfuzCS2kHQwf66xTDyuLbEIJ/4w5e9QRrQlWoZ/T2WjTVrTJeVdhCuuzrv6U
# Dm4N6czIT+YOvm0sbtRbDqh2pBMEUI1SfRxBGzi12I6wI3mFLgF+Fz4otj6oDcHy
# wNsHCtTIm38bU6wiDtx1f27yZeCg+F9cfJfRkpxJmLbtCX/T6A5jq5hF1iW4EO5h
# DpFmO+retC5NgS/XRJi3p/3ETrO1pT7sQFpNKzDJEaBOGkKMmniYWSNryNL7wnGB
# 9ooq08lm8ymOyrJMno+RFLwnfqowzO44rIbBvIsIieFQbzX3cvDlp07VmkdM6DYi
# hpnNCyW8TspoVr3uKe+na05p1GGilxtmorOyCJyFmGvGYfJgh5rOjGHncFTY/OjT
# SkBD9u0tqTaNZkLyQKiaMPkJs7BWnipZdWjf6s4DZyKTyeHGvN+hghjoMIIY5AYK
# KwYBBAGCNwMDATGCGNQwghjQBgkqhkiG9w0BBwKgghjBMIIYvQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBBwYLKoZIhvcNAQkQAQSggfcEgfQwgfECAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQwzEI5er3W2EoxlZVobgeZ3W2anJ48YnY5KKUj
# aU/4dp7BGqrbNYCyVdKcOeIuUjQTAhRlf0EaFfr/S1I6ybm9wRHSJKHG5xgPMjAy
# NjAxMzAxMDUxMjRaoHakdDByMQswCQYDVQQGEwJHQjEXMBUGA1UECBMOV2VzdCBZ
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
# DxcNMjYwMTMwMTA1MTI0WjA/BgkqhkiG9w0BCQQxMgQwB3omlWRAuUl1W9b1ll2g
# oBoWxEUsI5ephXVW7dBKtBfG/yNXKtDRaVA9UL4qo88YMIIBegYLKoZIhvcNAQkQ
# AgwxggFpMIIBZTCCAWEwFgQUOMkUgRBEtNxmPpPUdEuBQYaptbEwgYcEFMauVOR4
# hvF8PVUSSIxpw0p6+cLdMG8wW6RZMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRpbWUgU3Rh
# bXBpbmcgUm9vdCBSNDYCEHojrtpTaZYPkcg+XPTH4z8wgbwEFIU9Yy2TgoJhfNCQ
# NcSR3pLBQtrHMIGjMIGOpIGLMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKTmV3
# IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBVU0VS
# VFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZpY2F0
# aW9uIEF1dGhvcml0eQIQNsKwvXwbOuejs902y8l1aDANBgkqhkiG9w0BAQEFAASC
# AgCUtWe5eepl9N11DyxgUY5o/LK4Xd5wlGjqlZ3itaa8UPCu/JS9Ls7RMYXHly3q
# T/U/eEbSnL2NDWfG1F+IGSnbL9PjNLfWifsT7wDCfEwAptjrbi9etCKnXk6PE1qR
# WOtha2+FQ/nFDuLNCPHrPzEUhDbCLXPLCiYyP6QXDXIWf1Yx58CjcxRc/3xdue9w
# 3k7t9ON46V1H5u16Ux+WQ+VcXPMwk1mJFRBHr4khlFHJdQyuX09rA5GM00t+qUiG
# /+8uKvjEjavwPEp5hPfoaMgmI/+yoP8/5tPGyDyTXyqSGhraROsPZ0U/wbHb8bBW
# bsV2kUxv3D6aIdDRdZArt9uxmDL48o80+JGXtDIBwJaGsXULmTpD2nMyLEemmrrO
# l6YllhopVw3jxqcDv7+P4SYf0rV+0gPfFT2DaNqEWw57krNsmQMR2q7YbeDcgC16
# fssWqNcCbnrrx8X4S8XMLYbImWI6L5QoTgfx4/QPcb6/dBNhSTysSsl7CGNEbsUn
# eCEPMY0DrObf7Gi1roCcUWmU4QHiXnJ8ESUOqcjk1LXewm036MtiRg/TTRvtAB9e
# bO0xwMHn026i+kE4ZRjz9NJrEiiA8TJEwqjBIdJ156fDiD5nSQhyTYzTtff28v+f
# kEa3arm1AcKDLCi1cOLgCZAAftrGLoRHk0+lSjgJsII9qA==
# SIG # End signature block
