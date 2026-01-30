#------------------- FUNCTIONS FOR COMPUTE OPS MANAGEMENT EXTERNAL-SERVICES -----------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1

# Public functions
Function Get-HPECOMExternalService {
    <#
    .SYNOPSIS
    Retrieve the list of external services configured.

    .DESCRIPTION
    This Cmdlet returns a collection of external services configured that are available in the specified region.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name
    Name of an external services resource.

    .PARAMETER ServiceType
    Specifies the type of external service to retrieve. The available options are 'SERVICE_NOW' and 'DSCC'.
   
    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMExternalService -Region eu-central

    Return all external services configured in the central european region. 

    .EXAMPLE
    Get-HPECOMExternalService -Region eu-central -name MyServiceNow

    Return the external services 'MyServiceNow' configured in the central european region. 

    
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

        [String]$Name,

        [ValidateSet("SERVICE_NOW", "DSCC")]
        [String]$ServiceType,

        [Switch]$WhatIf
       
    ) 


    Begin {
  
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
      
      
    }
      
      
    Process {
      
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $Uri = Get-COMExternalServicesUri

        if ($ServiceType -eq "SERVICE_NOW") {
            $Uri = (Get-Uri) + "?filter=serviceType eq 'SERVICE_NOW'"
        }
        elseif ($ServiceType -eq "DSCC") {
            $Uri = (Get-Uri) + "?filter=serviceType eq 'DSCC'"    
        }

        try {
            [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
               
        }

        $ReturnData = @()
       
        if ($Null -ne $CollectionList) {     

            if ($Name) {
                $CollectionList = $CollectionList | Where-Object name -eq $Name

            }
                
            # Add region to object
            $CollectionList | Add-Member -type NoteProperty -name region -value $Region

            $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.ExternalServices"    
    
            $ReturnData = $ReturnData #| Sort-Object { $_.updatedAt }
        
            return $ReturnData 
                
        }
        else {

            return
                
        }     

    
    }
}

Function New-HPECOMExternalService {
    <#
    .SYNOPSIS
    Deploy an external service application in a specified region.

    .DESCRIPTION
    This cmdlet deploys either a ServiceNow or Data Services Cloud Console (DSCC) external service application in a specified region.
    - The ServiceNow integration enables COM to automatically create incidents in ServiceNow when iLOs report hardware-related service events.
    - The Data Services Cloud Console (DSCC) integration allows COM to configure and manage external storage.

    .PARAMETER Name 
    Name of the external service application to deploy. 
    
    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) to deploy the external web service. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER ServiceNow
    Switch parameter to specify the deployment of a ServiceNow integration.
    
    .PARAMETER DSCC
    Switch parameter to specify the deployment of a Data Services Cloud Console integration

    .PARAMETER Description 
    Parameter to specify a description. 

    .PARAMETER Credential 
    Parameter to specify the credential (clientID and client secret) of the external service. 

    .PARAMETER RefreshToken 
    Parameter to specify the refresh token of the external web service. 
 
    .PARAMETER OauthUrl 
    Authentication URL of the external web service to obtain OAuth tokens. 

    .PARAMETER IncidentUrl 
    Incident URL of the external web service that is used to create incidents.
    
    .PARAMETER RefreshTokenExpiryInDays 
    Parameter to specify the number of days after which the refresh token will expire.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    $ExternalServiceCredential = Get-Credential -Message "Enter your clientID and clientSecret"
    New-HPECOMExternalService -Name MyServiceNow -Region eu-central -Description "This is my ServiceNow integration" -Credential $ExternalServiceCredential -RefreshToken "541646646434684343" -OauthUrl "https://example.service-now.com/oauth_token.do" -IncidentUrl "https://example.service-now.com/api/now/import/u_demo_incident_inbound_api" -refreshTokenExpiryInDays 100 
    
    Create a ServiceNow integration in the central EU region. 

    .EXAMPLE
    $DSCCcredentials = Get-Credential -Message "Enter your clientID and clientSecret"
    New-HPECOMExternalService -Region eu-central -DSCC -Name "Data Services Cloud Console integration" -Description "This is my DSCC service in US-West" -DSCCRegion us-west -Credential $DSCCcredentials

    Create in the central EU region a Data Services Cloud Console integration configured in the US-west region.

    .INPUTS
    Pipeline input is not supported

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - Name of the external service attempted to be deployed
        * Region - Name of the region where the external service is deployed
        * Status - Status of the deployment attempt (Failed for http error return; Complete if deployment is successful; Warning if no action is needed) 
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.

   #>

    [CmdletBinding(DefaultParameterSetName = 'ServiceNow')]
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

        [Parameter(Mandatory, ParameterSetName = 'ServiceNow')]
        [switch]$ServiceNow,

        [Parameter(Mandatory, ParameterSetName = 'DSCC')]
        [switch]$DSCC,

        [Parameter (Mandatory)]
        [ValidateScript({ $_.Length -lt 256 })]
        [String]$Description,

        [Parameter (Mandatory)]
        [PSCredential]$Credential,

        [Parameter (Mandatory, ParameterSetName = 'ServiceNow')]
        [String]$RefreshToken,

        [Parameter (Mandatory, ParameterSetName = 'ServiceNow')]
        [String]$OauthUrl,

        [Parameter (Mandatory, ParameterSetName = 'ServiceNow')]
        [String]$IncidentUrl,

        [Parameter (Mandatory, ParameterSetName = 'ServiceNow')]
        [ValidateRange(100, 365)]
        [Int]$RefreshTokenExpiryInDays,

        [Parameter (Mandatory, ParameterSetName = 'DSCC')]
        [String]$DSCCRegion,

        [Switch]$WhatIf
    ) 

    Begin {

        
        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-COMExternalServicesUri  
        $DeployExternalServiceStatus = [System.Collections.ArrayList]::new()

        $AuthenticationType = "OAUTH"

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Name        = $Name
            ServiceType = $Null
            Region      = $Region                            
            Status      = $Null
            Details     = $Null
            Exception   = $Null
        }

        try {
            $ExternalServiceResource = Get-HPECOMExternalService -Region $Region -Name $Name

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)

        }

        if ($ExternalServiceResource) {

            "[{0}] External service '{1}' already exists in '{2}' region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "External service '{0}': Resource already exists in the '{1}' region! No action needed." -f $OneViewID, $Region
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "External service already exists in the region! No action needed."

            }

        }
        else {

            $ClientID = $Credential.UserName
            $clientSecret = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password))
    
            if ($ServiceNow) {            
    
                $ServiceType = "SERVICE_NOW"
    
                $Authentication = @{
                    clientId     = $ClientID
                    clientSecret = $clientSecret
                    refreshToken = $RefreshToken
                }
    
                $ServiceData = @{
                    oauthUrl                 = $OauthUrl
                    incidentUrl              = $IncidentUrl
                    refreshTokenExpiryInDays = $refreshTokenExpiryInDays
                }           
            }
            # ServiceType is DSCC
            else {
    
                $ServiceType = "DSCC"
    
                $Authentication = @{
                    clientId     = $ClientID
                    clientSecret = $clientSecret
                }
    
                $ServiceData = @{
                    region = $DSCCRegion       
                }           
            }
    
            $objStatus.ServiceType = $ServiceType 
    
            # Build payload
            $payload = ConvertTo-Json @{
                name               = $Name
                serviceType        = $ServiceType 
                authenticationType = $authenticationType
                description        = $Description
                authentication     = $Authentication
                serviceData        = $ServiceData
            }
    
    
            # Deploy the external service. 
            try {
                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
    
                
                if (-not $WhatIf) {
    
                    "[{0}] '{1}' external service creation raw response: `n{2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceType, $Response | Write-Verbose
    
                    do {
                        $ExternalService_status = (Get-HPECOMExternalService -Region $Region | Where-Object name -eq $Name ).status
                        Start-Sleep 1
                    } until ($ExternalService_status -eq "ENABLED")
                    
                    "[{0}] '{1}' external service successfully deployed in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Region | Write-Verbose
                        
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "External service successfully deployed in $Region region"
    
                }
    
            }
            catch {
    
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "External service cannot be deployed!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                }
            }           
        }


        [void] $DeployExternalServiceStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            $DeployExternalServiceStatus = Invoke-RepackageObjectWithType -RawObject $DeployExternalServiceStatus -ObjectName "COM.ExternalServices.NSDE"   
            Return $DeployExternalServiceStatus
        }


    }
}

Function Remove-HPECOMExternalService {
    <#
    .SYNOPSIS
    Remove a ServiceNow application in a region.

    .DESCRIPTION
    This Cmdlet can be used to remove the ServiceNow application in a region.    
        
    .PARAMETER Name 
    Name of the ServiceNow application to remove. 
    
    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where to remove ServiceNow. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Remove-HPECOMExternalService -Region eu-central -Name 'MyServiceNow_Name' 
    
    Remove the ServiceNow integration from the central EU region. 

    .EXAMPLE
    Get-HPECOMExternalService -Region eu-central -Name MyServiceNow_Name  | Remove-HPECOMExternalService 

    Remove the ServiceNow integration 'MyServiceNow_Name' from the central EU region. 

    .EXAMPLE
    Get-HPECOMExternalService -Region eu-central | Remove-HPECOMExternalService 

    Remove from the central EU region all external services returned by the 'Get-HPECOMExternalService' cmdlet. 

    .INPUTS
    System.Collections.ArrayList
        List of external service(s) from 'Get-HPECOMExternalService'. 

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - Name of the external service attempted to be removed
        * Region - Name of the region where the external service is removed
        * Status - Status of the removal attempt (Failed for http error return; Complete if removal is successful; Warning if no action is needed) 
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.

    
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

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [String]$Name,

        [Switch]$WhatIf
    ) 

    Begin {

        
        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $RemoveExternalServiceStatus = [System.Collections.ArrayList]::new()


    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        try {
            $ExternalServicesResource = Get-HPECOMExternalService -Region $Region -Name $Name
           
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
           
        }


        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Name        = $Name
            Region      = $Region    
            ServiceType = $ExternalServicesResource.ServiceType                       
            Status      = $Null
            Details     = $Null
            Exception   = $Null
        }
                     
        $ExternalServiceID = $ExternalServicesResource.id
        
        if (-not $ExternalServiceID) {
            # Must return a message if not found
            if ($WhatIf) {
                
                $ErrorMessage = "External service '{0}': Resource cannot be found in the '{1}' region!" -f $Name, $Region
                Write-warning $ErrorMessage
                return
            }
            else {

                $objStatus.Status = "Failed"
                $objStatus.Details = "External service cannot be found in the region!"

            }
        }
        else {

            $Uri = (Get-COMExternalServicesUri) + "/" + $ExternalServiceID

            # Deploy the external service. 
            try {
                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method DELETE -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                
                if (-not $WhatIf) {

                    "[{0}] External service removal raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose

                    "[{0}] External service '{1}' successfully deleted from '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Region | Write-Verbose
                    
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "External service successfully deleted from $Region region"

                }

            }
            catch {

                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "External service cannot be deleted!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                }
            }           

        }
        [void] $RemoveExternalServiceStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            $RemoveExternalServiceStatus = Invoke-RepackageObjectWithType -RawObject $RemoveExternalServiceStatus -ObjectName "COM.ExternalServices.NSDE"   
            Return $RemoveExternalServiceStatus
        }


    }
}

Function Set-HPECOMExternalService {
    <#
    .SYNOPSIS
    Updates an external services item in a specified region.

    .DESCRIPTION
    This Cmdlet modifies the ServiceNow application settings in a specified region. If a parameter is not provided, the cmdlet retains the current setting and only updates the provided parameters.
            
    .PARAMETER Name 
    Specifies the name of the external web service to update. 

    .PARAMETER NewName
    Specifies the new name for the external web service.
        
    .PARAMETER Region 
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the external web service is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Description 
    Specifies a description for the external web service. 

    .PARAMETER Credential 
    Specifies the credentials (clientID and client secret) of the external web service. 

    .PARAMETER RefreshToken 
    Specifies the refresh token of the external web service. 
    
    .PARAMETER OauthUrl 
    Specifies the authentication URL of the external web service used to obtain OAuth tokens. 

    .PARAMETER IncidentUrl 
    Specifies the incident URL of the external web service that is used to create incidents.
        
    .PARAMETER RefreshTokenExpiryInDays 
    Specifies the number of days after which the refresh token will expire.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request, useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Set-HPECOMExternalService -Region eu-central -Name MyServiceNow_Name -NewName MyServiceNow_for_COM -Description "This is my new description" -Credential $credentials -RefreshToken "541646646434684343" 

    Updates the external service 'MyServiceNow_Name' in the 'eu-central' region with a new name 'MyServiceNow_for_COM' and a new description.
    
    .EXAMPLE
    Set-HPECOMExternalService -Region eu-central -Name MyServiceNow_Name -Description "This is my new description" -Credential $credential -RefreshToken "541646646434684343" -OauthUrl "https://example.service-now.com/oauth_token.do" -IncidentUrl "https://example.service-now.com/api/now/import/u_demo_incident_inbound_api" -RefreshTokenExpiryInDays 200
        
    Updates the external service 'MyServiceNow_Name' in the central EU region with new parameters.

    .EXAMPLE
    Get-HPECOMExternalService -Region eu-central -Name MyServiceNow_Name | Set-HPECOMExternalService -Description "This is my new description" -Credential $credential -RefreshToken "541646646434684343" -OauthUrl "https://example.service-now.com/oauth_token.do" -IncidentUrl "https://example.service-now.com/api/now/import/u_demo_incident_inbound_api" -RefreshTokenExpiryInDays 150

    Updates the external service 'MyServiceNow_Name' in the central EU region with new parameters.

    .INPUTS
    System.Collections.ArrayList
        List of external service(s) from 'Get-HPECOMExternalService'. 

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - Name of the external service attempted to be updated
        * Region - Name of the region where the external service is updated
        * Status - Status of the modification attempt (Failed for HTTP error return; Complete if modification is successful; Warning if no action is needed)
        * Details - More information about the status 
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

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateScript({ $_.Length -lt 256 })]
        [String]$Name,

        [ValidateScript({ $_.Length -le 100 })]
        [String]$NewName,

        [ValidateScript({ $_.Length -lt 256 })]
        [String]$Description,

        [Parameter (Mandatory)]
        [PSCredential]$Credential,

        [Parameter (Mandatory)]
        [String]$RefreshToken,

        # [Parameter (Mandatory)]
        [String]$OauthUrl,

        # [Parameter (Mandatory)]
        [String]$IncidentUrl,

        # [Parameter (Mandatory)]
        [ValidateRange(100, 365)]
        [Int]$RefreshTokenExpiryInDays,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $SetExternalServiceStatus = [System.Collections.ArrayList]::new()

        
    }
    
    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        try {
            
            $ExternalServicesResource = Get-HPECOMExternalService -Region $Region -Name $Name
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
           
        }


        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Name        = $Name
            ServiceType = $ExternalServicesResource.ServiceType                       
            Region      = $Region                            
            Status      = $Null
            Details     = $Null
            Exception   = $Null
        }

        $ExternalServiceID = $ExternalServicesResource.id

        
        if (-not $ExternalServiceID) {
            # Must return a message if not found
            if ($WhatIf) {
                            
                $ErrorMessage = "External service '{0}': Resource cannot be found in the '{1}' region!" -f $Name, $Region
                Write-warning $ErrorMessage
                return
            }
            else {

                $objStatus.Status = "Failed"
                $objStatus.Details = "External service cannot be found in the region!"
            }
        }
        else {

            $Uri = (Get-COMExternalServicesUri) + "/" + $ExternalServiceID

            # Conditionally add properties
            if ($NewName) {
                $Name = $NewName
            }
                       
            if (-not $PSBoundParameters.ContainsKey('Description')) {
	
                if ($ExternalServicesResource.description) {
                       
                    $Description = $ExternalServicesResource.description

                }
                else {
                    $Description = $Null
                }
            }


            if (-not $OauthUrl) {
                $OauthUrl = $ExternalServicesResource.serviceData.oauthUrl
            }

            if (-not $IncidentUrl) {
                $IncidentUrl = $ExternalServicesResource.serviceData.incidentUrl
            }

            if (-not $refreshTokenExpiryInDays) {
                $refreshTokenExpiryInDays = $ExternalServicesResource.serviceData.refreshTokenExpiryInDays
            }

            # Deploy the external service. 
                     
            $ClientID = $Credential.UserName
            $clientSecret = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password))

            $Authentication = @{
                clientId     = $ClientID
                clientSecret = $clientSecret
                refreshToken = $RefreshToken
            }



            $ServiceData = @{
                oauthUrl                 = $OauthUrl
                incidentUrl              = $IncidentUrl
                refreshTokenExpiryInDays = $refreshTokenExpiryInDays
            }

            # Build payload
            $payload = ConvertTo-Json @{
                name           = $Name
                state          = "ENABLED"
                description    = $Description
                authentication = $Authentication
                serviceData    = $ServiceData
            }

        

            # Deploy the external service. 
            try {
                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method PATCH -body $payload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                
                if (-not $WhatIf) {

                    "[{0}] External service update raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose
                
                    "[{0}] External service '{1}' successfully updated in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Region | Write-Verbose
                    
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "External service successfully updated in $Region region"

                }

            }
            catch {

                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "External service cannot be updated!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 

                }
            }           
        }

        [void] $SetExternalServiceStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            $SetExternalServiceStatus = Invoke-RepackageObjectWithType -RawObject $SetExternalServiceStatus -ObjectName "COM.ExternalServices.NSDE"   
            Return $SetExternalServiceStatus
        }


    }
}

Function Test-HPECOMExternalService {
    <#
    .SYNOPSIS
    Generate a test incident in a region.

    .DESCRIPTION
    This Cmdlet can be used to generate a test incident in a region. For external service with serviceType as SERVICE_NOW, the cmdlet will generate a test incident for ServiceNow.
    For external service with serviceType as DSCC, the cmdlet will test the integration connection to Data Services Cloud Console. 
       
    An activity will be generated as a result of this test and indicates the success or failure of creating the test incident.   
        
    .PARAMETER Name 
    Name of the external web service to test. 
    
    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) to update the external web service. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Test-HPECOMExternalServiceServiceNow -Region eu-central -Name MyServiceNow_Name
    
    Generate a test incident for ServiceNow.

    .EXAMPLE
    Test-HPECOMExternalServiceServiceNow -Region eu-central  | Test-HPECOMExternalService 

    Generate a test incident for ServiceNow.

    .INPUTS
    System.Collections.ArrayList
        List of external service(s) from 'Get-HPECOMExternalService'. 

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - Name of the external service attempted to be tested
        * Region - Name of the region where the external services is tested
        * Status - Status of the testing attempt (Failed for http error return; Complete if testing is successful; Warning if no action is needed) 
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.

    
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

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateScript({ $_.Length -lt 256 })]
        [String]$Name,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $TestExternalServiceStatus = [System.Collections.ArrayList]::new()

        $_Date = Get-Date

        
    }
    
    Process {
        
        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        try {
            
            $ExternalServicesResource = Get-HPECOMExternalService -Region $Region -Name $Name 
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
           
        }

        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Name        = $Name
            ServiceType = $ExternalServicesResource.ServiceType                       
            Region      = $Region                            
            Status      = $Null
            Details     = $Null
            Exception   = $Null
        }


        
        if (-not $ExternalServicesResource) {

            # Must return a message if not found
            if ($WhatIf) {
                
                $ErrorMessage = "External service '{0}': Resource cannot be found in the '{1}' region!" -f $Name, $Region
                Write-warning $ErrorMessage
                return
            }
            else {

                $objStatus.Status = "Failed"
                $objStatus.Details = "External service cannot be found in the region!"
            }

        }
        else {

            $ExternalServiceID = $ExternalServicesResource.id
            $ServiceType = $ExternalServicesResource.ServiceType

            Switch ($ServiceType) {
                "SERVICE_NOW" { 
                    $ServiceTypeName = "ServiceNow"
                    $ServiceTypeCategory = "External service"
                    $ServiceTypeSourceName = "ServiceNow"
                }
                "DSCC" {
                    $ServiceTypeName = "Data Services Cloud Console"
                    $ServiceTypeCategory = "External service"
                    $ServiceTypeSourceName = "Data Services Cloud Console integration"
                }
                Default {
                        $ErrorMessage = "External service '{0}': Service type '{1}' is not supported for testing in the '{2}' region!" -f $Name, $ServiceType, $Region
                        Write-warning $ErrorMessage
                        return
                }
            }

            $Uri = (Get-COMExternalServicesUri) + "/" + $ExternalServiceID + "/test"

            # Generate a test incident 
                     
            try {
                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -ContentType 'application/json' -Body (@{} | ConvertTo-Json) -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                
                if (-not $WhatIf) {
                    "[{0}] External service test raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose
                    "[{0}] Test incident '{1}' has been successfully generated for '{2}' in '{3}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $ServiceTypeName, $Region | Write-Verbose
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Test incident has been successfully generated for $ServiceTypeName in $Region region"
                }

            }
            catch {
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Test incident cannot be generated for $ServiceTypeName" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                }
            }           
        }

        [void] $TestExternalServiceStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            if ($TestExternalServiceStatus.Status -notcontains "Failed") {
                do {
                    $_Activity = Get-HPECOMActivity -Region $Region -SourceName $ServiceTypeSourceName -Category $ServiceTypeCategory -WarningAction SilentlyContinue | Where-Object { ([datetime]$_.createdAt) -gt $_Date }
                    Start-Sleep 1
                    
                } until ($_Activity)
                
                $TestExternalServiceStatus = Invoke-RepackageObjectWithType -RawObject $TestExternalServiceStatus -ObjectName "COM.ExternalServices.NSDE"   
                Write-Host $TestExternalServiceStatus.details -ForegroundColor Green
                Return  $_Activity
            }
            else {
                $TestExternalServiceStatus = Invoke-RepackageObjectWithType -RawObject $TestExternalServiceStatus -ObjectName "COM.ExternalServices.NSDE"   
                Return $TestExternalServiceStatus
            }
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
Export-ModuleMember -Function 'Get-HPECOMExternalService', 'New-HPECOMExternalService', 'Remove-HPECOMExternalService', 'Set-HPECOMExternalService', 'Test-HPECOMExternalService' -Alias *

# SIG # Begin signature block
# MIItTQYJKoZIhvcNAQcCoIItPjCCLToCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAdIQPz9Oxua0yw
# qGB7+vNvL4u2AQrWrOtZDIBMyytqt6CCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQg5emNhIpfhvJ8Idm8jON7WLJfq1ZMsQkn1lcSanTEKgQwDQYJKoZIhvcNAQEB
# BQAEggIAuhQAi6ArVInc+w4atvfri2qD8mVOxMxdP2Ty3XqKY8+klJFRuQvic3Qz
# Hi597rziGW8jT63Fg4WGxHCjllQqF2kOGeGo0t5ke6jw5a8Ri3o3CF94awG9YSDI
# ePjsAZu/KtG4ZKM70Lm85BoSE/VHiFuExG60hy2+Cciz+rXn0zd2kIxADj5s8hQ4
# buqedLSb/j5JtJ1Z9k1VEWsiDQPreKsOknFqqS9JolVSfmS5f/PvANBfwR0rsi35
# j913PYAh0Z2KmQs/FH4HOFDcN4yrkkqc3IdzmY+DmjwCffP5ajenMbRdVYy+RTTl
# JR7XZ7ldVWTgG21VCN6Ss0o2Icsr/hY+CS5zoS3Q9MuT0XGjwzjF7xzFU15j1T+Z
# oDFlci+5dBG8+u9S9ENICHmue5g+Jf/gnuTI3K9lCeBtWl6W6pBdP6W9ryxUSrfe
# lsRWybPJfp0UUAIdEAN0zb+q34eEYxtyRy2H4g/xIyyjkCTMzmkfW0XMdVzaXoT5
# N/6vHgZtyNSr+L/wZXw3PAcXI3gR1tqlRwkC/2Ez+pDDJ1Gf4Jm62zkPhPjIGKIZ
# JL8al5ndehEDVU4sOQC1RXgaEQbFC9Q3CB1OPk4UbAW6whTwRLcBtXMJhNKbb+J5
# sixlaCvTsn+oQZdgvi335VMqTvmv1yNqYOLiA0hIyAARM/Q3rPKhgheXMIIXkwYK
# KwYBBAGCNwMDATGCF4Mwghd/BgkqhkiG9w0BBwKgghdwMIIXbAIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIGHBgsqhkiG9w0BCRABBKB4BHYwdAIBAQYJYIZIAYb9bAcBMEEw
# DQYJYIZIAWUDBAICBQAEMGMYtMsKhbtJept66kHS6/RCOe2XPVHpbaD6y1ZWXJeM
# zzAt6wEpeePvvJTWUn8oEgIQdqpvAj+esORhwKLUAoYdhRgPMjAyNjAxMzAxMDQ2
# MDdaoIITOjCCBu0wggTVoAMCAQICEAwgQ0n50PdZ+5gt5AgbiHswDQYJKoZIhvcN
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
# CSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjYwMTMw
# MTA0NjA3WjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBRyvP2gEH9JNLAHHGEP5teW
# UACYdzA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCAy8+OxvaLXsm1PHRuM3b2Pi4R2
# oXie1hLNPKp6nv81wjA/BgkqhkiG9w0BCQQxMgQwMO1lc+E29bW28h1PbZi4CJYi
# nVRlE2nX5AIEy/4IaBDWphdkYnPUuHobXpb+//NGMA0GCSqGSIb3DQEBAQUABIIC
# AIUrp2+KPKHaBx5NfFiuT74qnT+Z29LZYmi+9aYf6YeYM+uVtlhFTMktRDiLvhW/
# TAj6y6uh9Jnqm+IzEyyLhpkrq7TPcSHHD6qq2s/7pFqZCSlSrRwDt8kkn2PEnc3x
# Wzn/pqGZUPIXXLdqdACTCSWhRMU3x/bF2pOs2MVYDFfPIWcChCYSYvfXUK3bEyRw
# IfyAZy3fQsTwkckk65UC2mafrqxfC+w9Dv8CcfUW0dNA57Z0Lp13t0H+SZLGI3Mq
# CHLKGh5DyRFzWUPMuV/oMQKqnDQeS6/2LqcvVbHrgtuqHBZ8JsAxOAtTtz5Ek196
# Qc/S6AdI6siqdB1kxf0DTs+7bCXQHh2F0PL8RalChepJdMHWcSRhnmVKcqDRTQJ4
# OKBC4ocQ5e6ToFj9Bme0e9dPEtF0AvKbrtzdwjxymexkj+36XIsQrEeOen8Oh1a8
# gFX8PmXZFAkeR74BbpP0zAYe6mn2Ad5LyGfvS7GWKjqqsqT2bTF4+My/6siKXVe3
# 0AXySFCtLrOZbW3X6vu2GXD5g+S5bOuhzXGu+w5Fw1D7zeO0OesbkY58zzygrRnV
# 94Bq9kSDzd7F6149cw/WRm5zwQ9AsAyiSyY+q8rLDw3tiUTI5Www0CNLQs3+mA+u
# uyL71mx7Dr5JHCoRywpuE3xtG1HZVwF8nu04bA/U9ErQ
# SIG # End signature block
