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
                    $objStatus.Details = "External service cannot be deployed!"
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
                    $objStatus.Details = "External service cannot be deleted!"
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
                    $objStatus.Details = "External service cannot be updated!"
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
                    $objStatus.Details = "Test incident cannot be generated for $ServiceTypeName"
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
                    $_Activity = Get-HPECOMActivity -Region $Region -SourceName $ServiceTypeSourceName -Category $ServiceTypeCategory | Where-Object { ([datetime]$_.createdAt) -gt $_Date }
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
# MIIunwYJKoZIhvcNAQcCoIIukDCCLowCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBKANSjzOKDEsZm
# dTOOf5tP+hdlyVR/8QgDjV9exWAUAaCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQgPFwcQdb0CLHIOx0nnMK2IY9glK40G5FzbUFZwODbLFIwDQYJKoZIhvcNAQEB
# BQAEggIAkLykH47GZfq2g/7f3ejn0JvKYAdEf2zphUqb2ArQp24FXtHFZXVEX9z5
# L+/rnZ1Hknj9pPW0qPcLy2vOQmtk17jMtnaurQOH3hBzuuyLLrxLbOA3zjUaezpG
# 70REg/1ula4wnaX4fLz0KoFg+MSUaoQR7/drjhFQgDw7pt0qVGSyIy71yaMiiA1S
# 7RBLfstbfzF+S+TTSyivKtjKPl9nkOIAWVhak+6uQDiclqQ4yi0ki4X4Xda8cCkq
# uezURMuPWgAqc3aNKk+Wt6J9NLYMol08qzOg60BrOh/PX8XAwnBwTWJi39mXmuZj
# 9Uf8B8dHjsoekrJV0V6HIw8KMp+ZMUFy0BpQypcbe+hD3fiAqZO+Iz/w1zeEHHmt
# bO+dnGJJKb4Xkv6accOMNXij/g2neWY3Pp5p5A0kQbtsHs8nfoS9++z0Oi9QE0ql
# QCMSylXSEzOHvG4KKsxAq6Ew/4FiY5DnYSoSV3ovgpCB4W3vK34NhSO8GCcgeT/6
# 41BUMo3FhMMHXL3cVvb8EkaOnBEy/1bml3AkcQ2S4ov+gdzKyOAl252ozyKGNHq+
# rqcX7AYjapcR0FZmFggI0ZzFC1ILL0YbZ3xCJy4P8/intpaGsRxhIY3N4wiIbEBB
# bKwMaZ6nh8P0+A/l28cJsHFoiqPoAwpJ+HEOyuE+y/6G090d5t+hghjpMIIY5QYK
# KwYBBAGCNwMDATGCGNUwghjRBgkqhkiG9w0BBwKgghjCMIIYvgIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBCAYLKoZIhvcNAQkQAQSggfgEgfUwgfICAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQwZrMV+HeOeyOue0ObNkXBL4WGorw2U7l6JdUa
# s4y4Fl57P3uCUQqmgopuk5DO/MpNAhUAz2+GKw6jpiL5tgi+VZXVzy6Lc/sYDzIw
# MjYwMTE5MTgxNjIyWqB2pHQwcjELMAkGA1UEBhMCR0IxFzAVBgNVBAgTDldlc3Qg
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
# MQ8XDTI2MDExOTE4MTYyMlowPwYJKoZIhvcNAQkEMTIEMP14i/MQ9o9iYI6J/u7T
# 6tV3T0JvIXD6hqHScrpVN6nxcY+tfUtDwybZwxF74qlA+zCCAXoGCyqGSIb3DQEJ
# EAIMMYIBaTCCAWUwggFhMBYEFDjJFIEQRLTcZj6T1HRLgUGGqbWxMIGHBBTGrlTk
# eIbxfD1VEkiMacNKevnC3TBvMFukWTBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMP
# U2VjdGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBUaW1lIFN0
# YW1waW5nIFJvb3QgUjQ2AhB6I67aU2mWD5HIPlz0x+M/MIG8BBSFPWMtk4KCYXzQ
# kDXEkd6SwULaxzCBozCBjqSBizCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5l
# dyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNF
# UlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNh
# dGlvbiBBdXRob3JpdHkCEDbCsL18Gzrno7PdNsvJdWgwDQYJKoZIhvcNAQEBBQAE
# ggIAhKMDB+PxJa3neYiyVAf8c/pwOX5kPYohwP6PrAkvChvvlicgYxEqaQw8f6JV
# 57Q/0TMcJh7+xspydd1s0l8Ndl7iBGKWUbv/aptzIEldUzKRrJJvkxUf59GxB2BT
# BJDsWLfClZe2RtDwy6bKmEdJLJA4mKzzIHIZErEMqbiPYUVkWvD32MChK0+PRS5R
# VGYtftnYMmT4uxYxzP4fuHaAqTa33WM/NYf4rakE1hl7Pq4WegfolXjK/RWW+3gJ
# x3BPgL3eohBCO0OolCB51Mh+j4QUAG/RQNHQPyz+pTHYq7N9LS0CB6U9XiJ19bSl
# zXB1oNWexL1UtM01bebrScUJfDrF160o3JTSSnjUQN4t7PhXPACrVc6oxrF+vm/Z
# 8QhA4QdzRwfVB03SX74TC9fYCPAX7dO+QjQCYa8KHC/xhEgOj9X9ASS5CUhcTBCs
# 28sxOkKp3ti8j1i/T9wuNZTW/a0uRGFp4wM4FdLarcEbKAp0KVl9O9AxXr32yO0/
# Ymtp0X4Bcr2SG7fQlXE5fJfg7mALG7wzwHbJLJyoo/u/C6FAr8qeJYFeq1ALOnl3
# iFfA9Y6gko9CjON2+sVTjmgnWiloW+OUAU53YvsQjco2AM9V8umL0WCUTja4cAjo
# OTIRUat0LnSAMufjFes7V5xYk/gUYhyRwRlqVHaftJ3KQTQ=
# SIG # End signature block
