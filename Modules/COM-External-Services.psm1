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
    Specifies the type of external service to retrieve. The available options are 'SERVICE_NOW', 'DSCC', 'VMWARE_VCENTER', and 'ARUBA_CENTRAL'.
   
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
                if (-not $Global:HPEGreenLakeSession) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use the cmdlets of the HPECOMCmdlets module."
                }
                if (-not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "Compute Ops Management is not provisioned in this workspace!`n`nCAUSE:`nNo provisioned Compute Ops Management region was found.`n`nACTION REQUIRED:`nVerify the Compute Ops Management service is provisioned using:`n    Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned`n`nIf not provisioned, you can provision it using 'New-HPEGLService'."
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

        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [ValidateSet("SERVICE_NOW", "DSCC", "VMWARE_VCENTER", "ARUBA_CENTRAL")]
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
            $Uri = (Get-COMExternalServicesUri) + "?filter=serviceType eq 'SERVICE_NOW'"
        }
        elseif ($ServiceType -eq "DSCC") {
            $Uri = (Get-COMExternalServicesUri) + "?filter=serviceType eq 'DSCC'"
        }
        elseif ($ServiceType -eq "VMWARE_VCENTER") {
            $Uri = (Get-COMExternalServicesUri) + "?filter=serviceType eq 'VMWARE_VCENTER'"
        }
        elseif ($ServiceType -eq "ARUBA_CENTRAL") {
            $Uri = (Get-COMExternalServicesUri) + "?filter=serviceType eq 'ARUBA_CENTRAL'"
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

            # Tag VMware vCenter items with a dedicated TypeName so the vCenter-specific format view is applied
            # Also resolve the SecureGateway name from the associatedGatewayUri
            $_Appliances = $null
            foreach ($item in $ReturnData) {
                if ($item.serviceType -eq "VMWARE_VCENTER") {
                    $item.PSObject.TypeNames.Insert(0, "HPEGreenLake.COM.ExternalServices.VMwareVCenter")

                    # Resolve SecureGateway name from associatedGatewayUri (fetch appliances once)
                    if ($item.serviceData.associatedGatewayUri) {
                        if (-not $_Appliances) {
                            $_Appliances = Get-HPECOMAppliance -Region $Region -ErrorAction SilentlyContinue
                        }
                        $_SGName = $_Appliances | Where-Object { $_.resourceUri -eq $item.serviceData.associatedGatewayUri } | Select-Object -ExpandProperty name -ErrorAction SilentlyContinue
                        $item | Add-Member -Type NoteProperty -Name secureGatewayName -Value $_SGName -Force
                    }
                }
                elseif ($item.serviceType -eq "SERVICE_NOW") {
                    $item.PSObject.TypeNames.Insert(0, "HPEGreenLake.COM.ExternalServices.ServiceNow")
                }
            }
    
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
    This cmdlet deploys a ServiceNow, Data Services Cloud Console (DSCC), VMware vCenter, or Aruba Central external service application in a specified region.
    - The ServiceNow integration enables COM to automatically create incidents in ServiceNow when iLOs report hardware-related service events.
    - The Data Services Cloud Console (DSCC) integration allows COM to configure and manage external storage.
    - The VMware vCenter integration enables the HPE Compute Ops Management plug-in for VMware vCenter.  
    - The Aruba Central integration allows Compute Ops Management to show the connectivity between server network adapter ports and switch ports.  
    
    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) to deploy the external web service. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER ServiceNow
    Switch parameter to specify the deployment of a ServiceNow integration.
    
    .PARAMETER DSCC
    Switch parameter to specify the deployment of a Data Services Cloud Console integration

    .PARAMETER VMwareVCenter
    Switch parameter to specify the deployment of a VMware vCenter integration.

    .PARAMETER ArubaCentral
    Switch parameter to specify the deployment of an Aruba Central integration.

    .PARAMETER VCenterServer
    The FQDN or IPv4 address of the vCenter server.

    .PARAMETER SecureGatewayName
    The name (FQDN or hostname) of the HPE Compute Ops Management Secure Gateway appliance associated with this vCenter integration.
    The cmdlet resolves this name to the appliance resource URI automatically.
    This parameter accepts pipeline input from 'Get-HPECOMAppliance' via the 'name' property.

    .PARAMETER VCenterCertFingerprint
    The SHA-256 fingerprint of the vCenter server certificate.
    If not provided, the cmdlet automatically retrieves it from the vCenter server specified in '-VCenterServer' on port 443.
    Provide this parameter explicitly when auto-retrieval is not possible (e.g., the vCenter server is not directly reachable). See the examples section for a PowerShell snippet to retrieve this value manually.

    .PARAMETER Credential 
    Parameter to specify the PSCredential object for the external service.
    This parameter is mandatory for creating external services.
    [SERVICE_NOW]  The PSCredential object whose username is the OAuth clientId and password is the clientSecret.
    [DSCC] The PSCredential object whose username is the OAuth clientId and password is the clientSecret.
    [VMWARE_VCENTER] The PSCredential object whose username is the vCenter login and password is the vCenter password.
    [ARUBA_CENTRAL] The PSCredential object whose username is the OAuth clientId and password is the clientSecret. To obtain these values, log in to Aruba Central. Navigate to the Organization > Platform Integration > REST API page. In the My Apps & Tokens section, copy the Client ID/Client Secret.

    .PARAMETER RefreshToken 
    Parameter to specify the refresh token of the external web service. Applies to ServiceNow and Aruba Central integrations. 
    [ARUBA_CENTRAL] To obtain this value, log in to Aruba Central. Navigate to the Organization > Platform Integration > REST API page. In the My Apps & Tokens section, copy the Refresh Token corresponding to the Client ID used for authentication.
    
    .PARAMETER OauthUrl 
    Authentication URL of the external web service to obtain OAuth tokens. 

    .PARAMETER IncidentUrl 
    Incident URL of the external web service that is used to create incidents.
    
    .PARAMETER RefreshTokenExpiryInDays 
    Parameter to specify the number of days after which the refresh token will expire.

    .PARAMETER APIGatewayURL
    The Aruba Central API gateway URL (e.g., 'https://central.arubanetworks.com'). This parameter is required for Aruba Central integrations.
    
    To obtain this value, log in to Aruba Central. Navigate to the Organization > Platform Integration > REST API page. In the APIs section, copy the first part of the URL in the All Published APIs section, stopping after .com. Do not include any characters after .com. For example: https://central.arubanetworks.com. 

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    $ExternalServiceCredential = Get-Credential -Message "Enter your clientID and clientSecret"
    New-HPECOMExternalService -Region eu-central -Credential $ExternalServiceCredential -RefreshToken "541646646434684343" -OauthUrl "https://example.service-now.com/oauth_token.do" -IncidentUrl "https://example.service-now.com/api/now/import/u_demo_incident_inbound_api" -refreshTokenExpiryInDays 100 
    
    Create a ServiceNow integration in the central EU region. 

    .EXAMPLE
    $DSCCcredentials = Get-Credential -Message "Enter your clientID and clientSecret"
    New-HPECOMExternalService -Region eu-central -DSCC -DSCCRegion us-west -Credential $DSCCcredentials

    Create in the central EU region a Data Services Cloud Console integration configured in the US-west region.

    .EXAMPLE
    $vCenterCredential = Get-Credential -Message "Enter your vCenter username and password"
    New-HPECOMExternalService -Region eu-central -VMwareVCenter -Credential $vCenterCredential -VCenterServer "vcenter.example.com" -SecureGatewayName "comsgw.lj.lab" -VCenterCertFingerprint "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99"

    Create a VMware vCenter integration in the central EU region.

    .EXAMPLE
    $vCenterCredential = Get-Credential -Message "Enter your vCenter username and password"
    Get-HPECOMAppliance -Region eu-central -Type SecureGateway -Name comsgw.lj.lab | New-HPECOMExternalService -VMwareVCenter -Credential $vCenterCredential -VCenterServer "vcenter.lj.lab" -VCenterCertFingerprint "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99"

    Create a VMware vCenter integration using a piped Secure Gateway appliance object to automatically populate the SecureGatewayName and Region parameters.

    .EXAMPLE
    $vCenterFQDN = "vcenter.example.com"
    $tcpClient = New-Object System.Net.Sockets.TcpClient($vCenterFQDN, 443)
    $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, { $true })
    $sslStream.AuthenticateAsClient($vCenterFQDN)
    $cert = $sslStream.RemoteCertificate
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $hashBytes = $sha256.ComputeHash($cert.GetRawCertData())
    $VCenterCertFingerprint = ($hashBytes | ForEach-Object { $_.ToString("x2") }) -join ""
    $sslStream.Close(); $tcpClient.Close()
    Write-Host "vCenter SHA-256 fingerprint: $VCenterCertFingerprint"

    Retrieve the SHA-256 certificate fingerprint from a vCenter server on port 443 using .NET SSL classes. The resulting value can be provided to the -VCenterCertFingerprint parameter when you prefer to supply it manually. Otherwise, the cmdlet auto-retrieves the fingerprint when this parameter is omitted.

    .EXAMPLE
    $vCenterCredential = Get-Credential -Message "Enter your vCenter username and password"
    New-HPECOMExternalService -Region eu-central -VMwareVCenter -Credential $vCenterCredential -VCenterServer "vcenter.lj.lab" -SecureGatewayName "comsgw.lj.lab"

    Create a VMware vCenter integration without specifying a certificate fingerprint. The cmdlet automatically connects to 'vcenter.lj.lab' on port 443 and retrieves the SHA-256 fingerprint.

    .INPUTS
    System.Management.Automation.PSCustomObject
        A Secure Gateway appliance object from 'Get-HPECOMAppliance'. The 'name' property is bound to the SecureGatewayName parameter and the 'region' property is bound to the Region parameter.

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
        
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
        [ValidateScript({
                # First check if there's an active session with COM regions
                if (-not $Global:HPEGreenLakeSession) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use the cmdlets of the HPECOMCmdlets module."
                }
                if (-not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "Compute Ops Management is not provisioned in this workspace!`n`nCAUSE:`nNo provisioned Compute Ops Management region was found.`n`nACTION REQUIRED:`nVerify the Compute Ops Management service is provisioned using:`n    Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned`n`nIf not provisioned, you can provision it using 'New-HPEGLService'."
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

        [Parameter(Mandatory, ParameterSetName = 'DSCC')]
        [switch]$DSCC,

        [Parameter(Mandatory, ParameterSetName = 'ServiceNow')]
        [switch]$ServiceNow,

        [Parameter(Mandatory, ParameterSetName = 'VMwareVCenter')]
        [switch]$VMwareVCenter,

        [Parameter(Mandatory, ParameterSetName = 'ArubaCentral')]
        [switch]$ArubaCentral,

        [Parameter (Mandatory)]
        [PSCredential]$Credential,

        [Parameter (Mandatory, ParameterSetName = 'ServiceNow')]
        [Parameter (Mandatory, ParameterSetName = 'ArubaCentral')]
        [ValidateNotNullOrEmpty()]
        [String]$RefreshToken,

        [Parameter (Mandatory, ParameterSetName = 'ServiceNow')]
        [ValidateNotNullOrEmpty()]
        [String]$OauthUrl,

        [Parameter (Mandatory, ParameterSetName = 'ServiceNow')]
        [ValidateNotNullOrEmpty()]
        [String]$IncidentUrl,

        [Parameter (Mandatory, ParameterSetName = 'ServiceNow')]
        [ValidateRange(100, 365)]
        [Int]$RefreshTokenExpiryInDays,

        [Parameter (Mandatory, ParameterSetName = 'DSCC')]
        [ValidateNotNullOrEmpty()]
        [String]$DSCCRegion,

        [Parameter (Mandatory, ParameterSetName = 'ArubaCentral')]
        [ValidateNotNullOrEmpty()]
        [String]$APIGatewayURL,

        [Parameter (Mandatory, ParameterSetName = 'VMwareVCenter')]
        [ValidateNotNullOrEmpty()]
        [String]$VCenterServer,

        [Parameter (Mandatory, ParameterSetName = 'VMwareVCenter', ValueFromPipelineByPropertyName)]
        [Alias('name')]
        [ValidateNotNullOrEmpty()]
        [String]$SecureGatewayName,

        [Parameter (ParameterSetName = 'VMwareVCenter')]
        [String]$VCenterCertFingerprint,

        [Switch]$WhatIf
    ) 

    Begin {

        
        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-COMExternalServicesUri  
        $DeployExternalServiceStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        if ($ServiceNow) {
            $Name = "ServiceNow_" + $Region
        }
        elseif ($DSCC) {
            $Name = "DSCC_" + $Region
        }
        elseif ($ArubaCentral) {
            $Name = "ArubaCentral_" + $Region
        }
        else {
            $Name = $VCenterServer
        }

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

            # ARUBA_CENTRAL: the API enforces one instance per region regardless of name.
            # If the name-based lookup missed an existing entry (e.g. created with a different name),
            # fall back to a service-type check to catch the conflict before POSTing.
            if (-not $ExternalServiceResource -and $ArubaCentral) {
                $ExternalServiceResource = Get-HPECOMExternalService -Region $Region -ServiceType "ARUBA_CENTRAL" | Select-Object -First 1
            }

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)

        }

        if ($ExternalServiceResource) {

            "[{0}] External service '{1}' already exists in '{2}' region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "External service '{0}': Resource already exists in the '{1}' region! No action needed." -f $Name, $Region
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "External service already exists in the region! No action needed."
                $objStatus.ServiceType = $ExternalServiceResource.servicetype
            }

        }
        else {

            $ClientID = $Credential.UserName
            $clientSecret = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password))
    
            if ($ServiceNow) {            
    
                $ServiceType = "SERVICE_NOW"
                $AuthenticationType = "OAUTH"
                $objStatus.ServiceType = $ServiceType 
    
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
            elseif ($VMwareVCenter) {

                $ServiceType = "VMWARE_VCENTER"
                $AuthenticationType = "BASIC"
                $objStatus.ServiceType = $ServiceType 


                $Authentication = @{
                    username = $ClientID
                    password = $clientSecret
                }

                try {
                    $SecureGatewayResource = Get-HPECOMAppliance -Region $Region -Name $SecureGatewayName -ErrorAction Stop
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }

                if (-not $SecureGatewayResource) {
                    $ErrorMessage = "Secure Gateway appliance '$SecureGatewayName' cannot be found in the '$Region' region!"
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                    if ($WhatIf) {
                        Write-Warning "$ErrorMessage Cannot display API request."
                        return
                    }
                    $objStatus.Status = "Warning"
                    $objStatus.Details = $ErrorMessage

                }
                else {
                    # Auto-retrieve vCenter certificate fingerprint if not provided
                    if (-not $VCenterCertFingerprint) {
                        try {
                            $tcpClient = New-Object System.Net.Sockets.TcpClient($VCenterServer, 443)
                            $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, { $true })
                            $sslStream.AuthenticateAsClient($VCenterServer)
                            $cert = $sslStream.RemoteCertificate
                            $sha256 = [System.Security.Cryptography.SHA256]::Create()
                            $hashBytes = $sha256.ComputeHash($cert.GetRawCertData())
                            $VCenterCertFingerprint = ($hashBytes | ForEach-Object { $_.ToString("x2") }) -join ""
                            $sslStream.Close(); $tcpClient.Close()
                            "[{0}] Auto-retrieved vCenter certificate fingerprint from '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $VCenterServer, $VCenterCertFingerprint | Write-Verbose
                        }
                        catch {
                            $ErrorMessage = "Failed to auto-retrieve vCenter certificate fingerprint from '$VCenterServer' on port 443!"
                            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                            if ($WhatIf) {
                                Write-Warning "$ErrorMessage Cannot display API request."
                                return
                            }
                            $objStatus.Status = "Failed"
                            $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { $ErrorMessage }
                        }
                    }

                    $ServiceData = @{
                        vCenterUrl             = $VCenterServer
                        associatedGatewayUri   = $SecureGatewayResource.resourceUri
                        vCenterCertFingerprint = $VCenterCertFingerprint.Replace(":", "").ToLower()
                    }
                }
            }
            elseif ($ArubaCentral) {

                $ServiceType = "ARUBA_CENTRAL"
                $AuthenticationType = "OAUTH"
                $objStatus.ServiceType = $ServiceType

                $Authentication = @{
                    clientId     = $ClientID
                    clientSecret = $clientSecret
                    refreshToken = $RefreshToken
                }

                $ServiceData = @{
                    nbUrl = $APIGatewayURL
                }
            }
            # ServiceType is DSCC
            else {
    
                $ServiceType = "DSCC"
                $AuthenticationType = "OAUTH"
                $objStatus.ServiceType = $ServiceType 

    
                $Authentication = @{
                    clientId     = $ClientID
                    clientSecret = $clientSecret
                }
    
                $ServiceData = @{
                    region = $DSCCRegion       
                }           
            }
    
    
            # Build payload and deploy only if no earlier validation failure
            if (-not $objStatus.Status) {

                $payload = ConvertTo-Json @{
                    name               = $Name
                    serviceType        = $ServiceType 
                    authenticationType = $AuthenticationType
                    authentication     = $Authentication
                    serviceData        = $ServiceData
                }

                # Build sanitized payload for WhatIf display (mask sensitive credential fields)
                $SanitizedPayload = $payload -replace '"(clientSecret|password|refreshToken)":\s*"[^"]*"', '"$1": "[REDACTED]"'
    
                # Deploy the external service. 
                try {
                    if ($WhatIf) {
                        $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $SanitizedPayload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                    }
                    else {
                        $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                    }
    
                    if (-not $WhatIf) {
    
                        "[{0}] '{1}' external service creation raw response: `n{2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceType, $Response | Write-Verbose
    
                        do {
                            $ExternalService_status = (Get-HPECOMExternalService -Region $Region | Where-Object name -eq $Name ).status
                            Start-Sleep 1
                        } until ($ExternalService_status -eq "ENABLED")
                        
                        "[{0}] '{1}' external service successfully deployed in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
                            
                        $objStatus.Status = "Complete"
                        $objStatus.Details = "External service successfully deployed in $Region region"
    
                    }
    
                }
                catch {
    
                    if (-not $WhatIf) {
                        $_errMsg = if ($_.Exception.Message) { $_.Exception.Message } else { "" }
                        if ($_errMsg -match "already exists" -or $Global:HPECOMInvokeReturnData.errorCode -match "1700004") {
                            $objStatus.Status = "Warning"
                            $objStatus.Details = "External service already exists in the region! No action needed."
                        }
                        else {
                            $objStatus.Status = "Failed"
                            $objStatus.Details = if ($_errMsg) { $_errMsg } else { "External service cannot be deployed!" }
                            $objStatus.Exception = $Global:HPECOMInvokeReturnData
                        }
                    }
                }           
            }
        }


        if (-not $WhatIf) {
            [void] $DeployExternalServiceStatus.add($objStatus)
        }

    }

    end {

        if ($DeployExternalServiceStatus.Count -gt 0) {

            $DeployExternalServiceStatus = Invoke-RepackageObjectWithType -RawObject $DeployExternalServiceStatus -ObjectName "COM.ExternalServices.NSDE"   
            Return $DeployExternalServiceStatus
        }


    }
}

Function Remove-HPECOMExternalService {
    <#
    .SYNOPSIS
    Remove an external service (ServiceNow, DSCC, or VMware vCenter) from a region.

    .DESCRIPTION
    This Cmdlet removes an external service from the specified region.
    - For ServiceNow and DSCC integrations, the resource is deleted directly via a REST DELETE call.
    - For VMware vCenter integrations, deletion is performed via a 'DeleteVCenter' job because the API does not support direct deletion. The cmdlet submits the job and waits for it to complete.
        
    .PARAMETER Name 
    Name of the external service to remove. 
    
    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where to remove the external service. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Remove-HPECOMExternalService -Region eu-central -Name 'ServiceNow_eu-central'
    
    Remove the ServiceNow integration from the central EU region. 

    .EXAMPLE
    Remove-HPECOMExternalService -Region us-west -Name 'vcenter.lj.lab'
    
    Remove the VMware vCenter integration named 'vcenter.lj.lab' from the us-west region using a job.

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
        * ServiceType - Type of the external service (SERVICE_NOW, DSCC, VMWARE_VCENTER)
        * Status - Status of the removal attempt (Failed for http error return; Complete if removal is successful; Warning if no action is needed) 
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.

    
   #>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
        [ValidateScript({
                # First check if there's an active session with COM regions
                if (-not $Global:HPEGreenLakeSession) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use the cmdlets of the HPECOMCmdlets module."
                }
                if (-not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "Compute Ops Management is not provisioned in this workspace!`n`nCAUSE:`nNo provisioned Compute Ops Management region was found.`n`nACTION REQUIRED:`nVerify the Compute Ops Management service is provisioned using:`n    Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned`n`nIf not provisioned, you can provision it using 'New-HPEGLService'."
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
        [ValidateNotNullOrEmpty()]
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
            $ErrorMessage = "External service '{0}': Resource cannot be found in the '{1}' region!" -f $Name, $Region
            if ($WhatIf) {
                
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {

                $objStatus.Status = "Warning"
                $objStatus.Details = "External service cannot be found in the region!"

            }
        }
        else {

            $_ServiceType = $ExternalServicesResource.serviceType

            if ($_ServiceType -eq "VMWARE_VCENTER") {

                # VMware vCenter services cannot be deleted directly — a job must be used
                $_JobTemplateName = 'DeleteVCenter'
                $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

                if (-not $JobTemplateId) {
                    $ErrorMessage = "Job template '$_JobTemplateName' cannot be found. Ensure you are connected and the job templates are loaded."
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                    if ($WhatIf) {
                        Write-Warning "$ErrorMessage Cannot display API request."
                        return
                    }
                    $objStatus.Status = "Warning"
                    $objStatus.Details = $ErrorMessage
                }
                else {

                    $JobUri = Get-COMJobsUri

                    $payload = ConvertTo-Json @{
                        jobTemplate  = $JobTemplateId
                        resourceId   = $ExternalServiceID
                        resourceType = "compute-ops-mgmt/external-service"
                        jobParams    = @{
                            vCenterUuid          = $ExternalServiceID
                            externalServiceId    = $ExternalServiceID
                            vCenterUrl           = $ExternalServicesResource.serviceData.vCenterUrl
                            associatedGatewayUri = $ExternalServicesResource.serviceData.associatedGatewayUri
                        }
                    }

                    try {
                        $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $JobUri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

                        if (-not $WhatIf) {

                            "[{0}] '{1}' job submitted, waiting for completion..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $_JobTemplateName | Write-Verbose

                            $JobResult = Wait-HPECOMJobComplete -Region $Region -Job $Response.resourceUri -Verbose:$VerbosePreference

                            "[{0}] Job result: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $JobResult | Write-Verbose

                            if ($JobResult.resultCode -eq "SUCCESS") {
                                "[{0}] External service '{1}' successfully deleted from '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
                                $objStatus.Status = "Complete"
                                $objStatus.Details = "External service successfully deleted from $Region region"
                            }
                            else {
                                $objStatus.Status = "Failed"
                                $objStatus.Details = if ($JobResult.message) { $JobResult.message } else { "DeleteVCenter job did not complete successfully. Result: $($JobResult.resultCode)" }
                                $objStatus.Exception = $JobResult
                            }
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
            }
            else {

                $Uri = (Get-COMExternalServicesUri) + "/" + $ExternalServiceID

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
        }
        if (-not $WhatIf) {
            [void] $RemoveExternalServiceStatus.add($objStatus)
        }

    }

    end {

        if ($RemoveExternalServiceStatus.Count -gt 0) {

            $RemoveExternalServiceStatus = Invoke-RepackageObjectWithType -RawObject $RemoveExternalServiceStatus -ObjectName "COM.ExternalServices.NSDE"   
            Return $RemoveExternalServiceStatus
        }


    }
}

Function Set-HPECOMExternalService {
    <#
    .SYNOPSIS
    Updates an external service in a specified region.

    .DESCRIPTION
    This cmdlet modifies the settings of a ServiceNow, DSCC, VMware vCenter, or Aruba Central external service in a specified region.
    Only the parameters you supply are updated — any parameter not provided retains its current value (PATCH semantics).

    The cmdlet auto-detects the service type from the existing resource, so no type switch is needed.
    Supply only the parameters relevant to the service type being updated:

      SERVICE_NOW parameters  : -Credential, -RefreshToken, -OauthUrl, -IncidentUrl, -RefreshTokenExpiryInDays,
                                 -ServiceEventIssues, -CriticalEventIssues, -WarningEventIssues, -UtilizationAlerts,
                                 -PowerResetEvent, -DisconnectedEvent
      DSCC parameters         : -Credential, -DSCCRegion
      VMWARE_VCENTER parameters: -Credential, -VCenterServer, -AssociatedGatewayUri, -VCenterCertFingerprint
      ARUBA_CENTRAL parameters : -Credential, -RefreshToken, -APIGatewayURL

    For all service types, -Name, -NewName, and -Description can be updated independently without supplying credentials.

    Incident scope for SERVICE_NOW follows a mandatory hierarchy (lower selections must be True before higher ones can be True):
      serviceEventIssues (minimum) → criticalEventIssues → warningEventIssues (maximum scope)
    Additionally, at least one of -ServiceEventIssues or -UtilizationAlerts must be True.
    -PowerResetEvent and -DisconnectedEvent are fully independent.

    .PARAMETER Name 
    Specifies the name of the external service to update.

    .PARAMETER NewName
    Specifies a new name for the external service.

    .PARAMETER Region 
    Specifies the region code of the Compute Ops Management instance where the external service is located (e.g., 'us-west', 'eu-central').
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Description 
    Specifies a new description for the external service. Applies to both SERVICE_NOW and VMWARE_VCENTER services.

    .PARAMETER Credential 
    [SERVICE_NOW]  The PSCredential object whose username is the OAuth clientId and password is the clientSecret.
    [DSCC] The PSCredential object whose username is the OAuth clientId and password is the clientSecret.
    [VMWARE_VCENTER] The PSCredential object whose username is the vCenter login and password is the vCenter password.
    [ARUBA_CENTRAL] The PSCredential object whose username is the OAuth clientId and password is the clientSecret. To obtain these values, log in to Aruba Central. Navigate to the Organization > Platform Integration > REST API page. In the My Apps & Tokens section, copy the Client ID/Client Secret.

    This parameter is optional. If omitted, the existing credential stored in the service is preserved.
    When supplied for SERVICE_NOW or ARUBA_CENTRAL, -RefreshToken must also be provided.

    .PARAMETER RefreshToken 
    [SERVICE_NOW / ARUBA_CENTRAL] The OAuth refresh token used to obtain access tokens.
    Required when -Credential is provided for a SERVICE_NOW or ARUBA_CENTRAL service.
    Note: refreshToken is stored in the authentication block alongside clientId/clientSecret. Updating it requires -Credential to be provided as well.
    [ARUBA_CENTRAL] To obtain this value, log in to Aruba Central. Navigate to the Organization > Platform Integration > REST API page. In the My Apps & Tokens section, copy the Refresh Token corresponding to the Client ID used for authentication.

    .PARAMETER OauthUrl 
    [SERVICE_NOW only] The OAuth token endpoint URL (e.g., 'https://instance.service-now.com/oauth_token.do').
    Optional — can be updated independently without providing -Credential. If omitted, the existing URL is retained.

    .PARAMETER IncidentUrl 
    [SERVICE_NOW only] The REST API endpoint used to create incidents (e.g., 'https://instance.service-now.com/api/now/import/...').
    Optional — can be updated independently without providing -Credential. If omitted, the existing URL is retained.

    .PARAMETER RefreshTokenExpiryInDays 
    [SERVICE_NOW only] The number of days until the refresh token expires. Valid range: 100–365.
    Optional — can be updated independently without providing -Credential. If omitted, the existing value is retained.

    .PARAMETER ServiceEventIssues
    [SERVICE_NOW only] When True, incidents are created for service events (events with severity 'warning' or 'critical' that are classified as service events).
    This is the minimum scope level. Must be True before -CriticalEventIssues or -WarningEventIssues can be set to True.
    Optional — if omitted, the existing value is retained.

    .PARAMETER CriticalEventIssues
    [SERVICE_NOW only] When True, incidents are created for non-service events with severity 'critical'.
    Requires -ServiceEventIssues to be True. Must be True before -WarningEventIssues can be set to True.
    Optional — if omitted, the existing value is retained.

    .PARAMETER WarningEventIssues
    [SERVICE_NOW only] When True, incidents are created for non-service events with severity 'warning'.
    Requires both -ServiceEventIssues and -CriticalEventIssues to be True.
    Optional — if omitted, the existing value is retained.

    .PARAMETER UtilizationAlerts
    [SERVICE_NOW only] When True, incidents are created for power utilization threshold breach events.
    Independent of the serviceEventIssues/criticalEventIssues/warningEventIssues hierarchy, but at least one of -ServiceEventIssues or -UtilizationAlerts must be True.
    Optional — if omitted, the existing value is retained.

    .PARAMETER PowerResetEvent
    [SERVICE_NOW only] When True, incidents are created for power change (reset) events.
    Fully independent of all other scope settings.
    Optional — if omitted, the existing value is retained.

    .PARAMETER DisconnectedEvent
    [SERVICE_NOW only] Sets the number of hours of disconnectivity before an incident is created (0 = disabled, 1, 2, or 3 hours).
    Fully independent of all other scope settings.
    Optional — if omitted, the existing value is retained.

    .PARAMETER DSCCRegion
    [DSCC only] The region code of the Data Services Cloud Console instance (e.g., 'us-west', 'eu-central').
    Optional — if omitted, the existing region is retained.

    .PARAMETER APIGatewayURL
    [ARUBA_CENTRAL only] The Aruba Central API gateway URL (e.g., 'https://central.arubanetworks.com').
    Optional — if omitted, the existing URL is retained.

    To obtain this value, log in to Aruba Central. Navigate to the Organization > Platform Integration > REST API page. In the APIs section, copy the first part of the URL in the All Published APIs section, stopping after .com. Do not include any characters after .com. For example: https://central.arubanetworks.com. 

    .PARAMETER VCenterServer
    [VMWARE_VCENTER only] The FQDN or IPv4 address of the vCenter server.
    Optional — if omitted, the existing value is retained.

    .PARAMETER AssociatedGatewayUri
    [VMWARE_VCENTER only] The resource URI of the Secure Gateway appliance associated with this vCenter integration.
    Optional — if omitted, the existing URI is retained.

    .PARAMETER VCenterCertFingerprint
    [VMWARE_VCENTER only] The SHA-256 fingerprint of the vCenter server TLS certificate, as a plain lowercase hex string with no separators (e.g., '035fa3f6e64b195b...').
    Colons and mixed case are accepted and normalized automatically.
    Optional — if omitted, the existing stored fingerprint is retained. If no fingerprint is stored, the cmdlet auto-retrieves it from the vCenter server on port 443.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request, useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    $credential = Get-Credential -Message "Enter your Aruba Central clientID and clientSecret"
    Set-HPECOMExternalService -Region us-west -Name "ArubaCentral_us-west" -Credential $credential -RefreshToken "newRefreshToken" -APIGatewayURL "https://central.arubanetworks.com"

    Updates the authentication credentials, refresh token, and Aruba Central URL for an existing Aruba Central integration.

    .EXAMPLE
    Get-HPECOMExternalService -Region us-west -Name "my-vcenter" | Set-HPECOMExternalService -Description "Updated description"

    Updates only the description of the VMware vCenter integration 'my-vcenter'. No credentials required for a description-only update.

    .EXAMPLE
    $DSCCcredentials = Get-Credential -Message "Enter your DSCC clientID and clientSecret"
    Set-HPECOMExternalService -Region eu-central -Name "DSCC_eu-central" -Credential $DSCCcredentials -DSCCRegion us-west

    Updates the credentials and DSCC region for a DSCC integration.

    .EXAMPLE
    $vCenterCredential = Get-Credential -Message "Enter vCenter username and password"
    Set-HPECOMExternalService -Region us-west -Name "my-vcenter" -Credential $vCenterCredential -VCenterServer "vcenter2.example.com"

    Updates the vCenter server address and credentials for an existing VMware vCenter integration.

    .EXAMPLE
    Set-HPECOMExternalService -Region eu-central -Name MyServiceNow -NewName MyServiceNow_v2 -Description "Updated description"

    Renames the ServiceNow integration and updates its description. No credentials required.

    .EXAMPLE
    $credential = Get-Credential -Message "Enter ServiceNow clientId and clientSecret"
    Set-HPECOMExternalService -Region eu-central -Name MyServiceNow -Credential $credential -RefreshToken "newtoken123" -OauthUrl "https://instance.service-now.com/oauth_token.do" -IncidentUrl "https://instance.service-now.com/api/now/import/u_incidents" -RefreshTokenExpiryInDays 200

    Updates the authentication settings for an existing ServiceNow integration.

    .EXAMPLE
    Set-HPECOMExternalService -Region eu-central -Name MyServiceNow -ServiceEventIssues $True -CriticalEventIssues $True -WarningEventIssues $True -UtilizationAlerts $True -PowerResetEvent $True -DisconnectedEvent 2

    Sets the maximum incident scope for a ServiceNow integration: all event types enabled, incidents created after 2 hours of disconnectivity.

    .EXAMPLE
    Set-HPECOMExternalService -Region eu-central -Name MyServiceNow -ServiceEventIssues $True -UtilizationAlerts $False -PowerResetEvent $False -DisconnectedEvent 0

    Sets the minimum incident scope: only service events, no utilization alerts, no power reset events, disconnected events disabled.

    .EXAMPLE
    Get-HPECOMExternalService -Region eu-central -Name MyServiceNow | Set-HPECOMExternalService -Description "This is my new description" -Credential $credential -RefreshToken "541646646434684343" -OauthUrl "https://example.service-now.com/oauth_token.do" -IncidentUrl "https://example.service-now.com/api/now/import/u_demo_incident_inbound_api" -RefreshTokenExpiryInDays 150

    Updates both the description and authentication settings for a ServiceNow integration using the pipeline.

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
                if (-not $Global:HPEGreenLakeSession) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use the cmdlets of the HPECOMCmdlets module."
                }
                if (-not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "Compute Ops Management is not provisioned in this workspace!`n`nCAUSE:`nNo provisioned Compute Ops Management region was found.`n`nACTION REQUIRED:`nVerify the Compute Ops Management service is provisioned using:`n    Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned`n`nIf not provisioned, you can provision it using 'New-HPEGLService'."
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

        [PSCredential]$Credential,

        [String]$RefreshToken,

        [String]$OauthUrl,

        [String]$IncidentUrl,

        [ValidateRange(100, 365)]
        [Int]$RefreshTokenExpiryInDays,

        [Bool]$ServiceEventIssues,

        [Bool]$CriticalEventIssues,

        [Bool]$WarningEventIssues,

        [Bool]$UtilizationAlerts,

        [Bool]$PowerResetEvent,

        [ValidateRange(0, 3)]
        [Int]$DisconnectedEvent,

        [String]$VCenterServer,

        [String]$AssociatedGatewayUri,

        [String]$VCenterCertFingerprint,

        [String]$DSCCRegion,

        [String]$APIGatewayURL,

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
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {

                $objStatus.Status = "Warning"
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

            # Build authentication and service data based on service type
            $_ServiceType = $ExternalServicesResource.serviceType

            # Extract credential values only when a credential object was provided
            if ($Credential) {
                $ClientID = $Credential.UserName
                $clientSecret = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password))
            }

            if ($_ServiceType -eq "VMWARE_VCENTER") {

                # Determine whether any vCenter-specific field is being changed
                $_anyVCenterChange = $Credential -or
                                     $PSBoundParameters.ContainsKey('VCenterServer') -or
                                     $PSBoundParameters.ContainsKey('AssociatedGatewayUri') -or
                                     $PSBoundParameters.ContainsKey('VCenterCertFingerprint')

                if ($_anyVCenterChange) {

                    if (-not $VCenterServer) {
                        $VCenterServer = $ExternalServicesResource.serviceData.vCenterUrl
                    }

                    if (-not $AssociatedGatewayUri) {
                        $AssociatedGatewayUri = $ExternalServicesResource.serviceData.associatedGatewayUri
                    }

                    if (-not $VCenterCertFingerprint) {
                        $VCenterCertFingerprint = $ExternalServicesResource.serviceData.vCenterCertFingerprint
                    }

                    # Auto-retrieve vCenter certificate fingerprint from server if still not available
                    if (-not $VCenterCertFingerprint) {
                        try {
                            $tcpClient = New-Object System.Net.Sockets.TcpClient($VCenterServer, 443)
                            $sslStream = New-Object System.Net.Security.SslStream($tcpClient.GetStream(), $false, { $true })
                            $sslStream.AuthenticateAsClient($VCenterServer)
                            $cert = $sslStream.RemoteCertificate
                            $sha256 = [System.Security.Cryptography.SHA256]::Create()
                            $hashBytes = $sha256.ComputeHash($cert.GetRawCertData())
                            $VCenterCertFingerprint = ($hashBytes | ForEach-Object { $_.ToString("x2") }) -join ""
                            $sslStream.Close(); $tcpClient.Close()
                            "[{0}] Auto-retrieved vCenter certificate fingerprint from '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $VCenterServer, $VCenterCertFingerprint | Write-Verbose
                        }
                        catch {
                            $ErrorMessage = "Failed to auto-retrieve vCenter certificate fingerprint from '$VCenterServer' on port 443!"
                            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                            if ($WhatIf) {
                                Write-Warning "$ErrorMessage Cannot display API request."
                                return
                            }
                            $objStatus.Status = "Failed"
                            $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { $ErrorMessage }
                        }
                    }
                }

                # Build payload hash — only include authentication/serviceData when something changed
                $payloadHash = [ordered]@{
                    name        = $Name
                    state       = "ENABLED"
                    description = $Description
                }

                if ($_anyVCenterChange -and -not $objStatus.Status) {

                    if ($Credential) {
                        $payloadHash['authentication'] = @{
                            username = $ClientID
                            password = $clientSecret
                        }
                    }

                    $payloadHash['serviceData'] = @{
                        vCenterUrl             = $VCenterServer
                        associatedGatewayUri   = $AssociatedGatewayUri
                        vCenterCertFingerprint = $VCenterCertFingerprint.Replace(":", "").ToLower()
                    }
                }

                $payload = ConvertTo-Json $payloadHash

                # Build sanitized payload for WhatIf display (mask sensitive credential fields)
                $SanitizedPayload = $payload -replace '"(clientSecret|password|refreshToken)":\s*"[^"]*"', '"$1": "[REDACTED]"'

            }
            elseif ($_ServiceType -eq "DSCC") {

                # DSCC authentication uses clientId/clientSecret only (no refreshToken)
                $_credentialChange  = [bool]$Credential
                $_serviceDataChange = $PSBoundParameters.ContainsKey('DSCCRegion')

                $payloadHash = [ordered]@{
                    name        = $Name
                    state       = "ENABLED"
                    description = $Description
                }

                if ($_credentialChange) {
                    $payloadHash['authentication'] = @{
                        clientId     = $ClientID
                        clientSecret = $clientSecret
                    }
                }

                if ($_serviceDataChange) {
                    $payloadHash['serviceData'] = @{
                        region = $DSCCRegion
                    }
                }

                $payload = ConvertTo-Json $payloadHash

                # Build sanitized payload for WhatIf display (mask sensitive credential fields)
                $SanitizedPayload = $payload -replace '"(clientSecret|password|refreshToken)":\s*"[^"]*"', '"$1": "[REDACTED]"'

            }
            elseif ($_ServiceType -eq "ARUBA_CENTRAL") {

                # ARUBA_CENTRAL uses clientId/clientSecret/refreshToken for auth and nbUrl (APIGatewayURL) for serviceData
                $_credentialChange  = $Credential -or $PSBoundParameters.ContainsKey('RefreshToken')
                $_serviceDataChange = $PSBoundParameters.ContainsKey('APIGatewayURL')

                $payloadHash = [ordered]@{
                    name        = $Name
                    state       = "ENABLED"
                    description = $Description
                }

                if ($_credentialChange) {

                    if (-not $Credential) {
                        $ErrorMessage = "External service '{0}': Parameter '-Credential' (clientId/clientSecret) is required when updating the authentication token for ARUBA_CENTRAL services in the '{1}' region!" -f $Name, $Region
                        if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
                        $objStatus.Status = "Warning"
                        $objStatus.Details = $ErrorMessage
                    }
                    elseif (-not $RefreshToken) {
                        $ErrorMessage = "External service '{0}': Parameter '-RefreshToken' is required when updating credentials for ARUBA_CENTRAL services in the '{1}' region!" -f $Name, $Region
                        if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
                        $objStatus.Status = "Warning"
                        $objStatus.Details = $ErrorMessage
                    }
                    else {
                        $payloadHash['authentication'] = @{
                            clientId     = $ClientID
                            clientSecret = $clientSecret
                            refreshToken = $RefreshToken
                        }
                    }
                }

                if ($_serviceDataChange -and -not $objStatus.Status) {
                    $payloadHash['serviceData'] = @{
                        nbUrl = $APIGatewayURL
                    }
                }

                $payload = ConvertTo-Json $payloadHash

                # Build sanitized payload for WhatIf display (mask sensitive credential fields)
                $SanitizedPayload = $payload -replace '"(clientSecret|password|refreshToken)":\s*"[^"]*"', '"$1": "[REDACTED]"'

            }
            else {
                # SERVICE_NOW
                # Split into two independent concerns:
                #   - Authentication change: requires both -Credential and -RefreshToken (refreshToken lives in the authentication block)
                #   - ServiceData change   : oauthUrl / incidentUrl / refreshTokenExpiryInDays — can be updated without credentials

                $_credentialChange  = $Credential -or $PSBoundParameters.ContainsKey('RefreshToken')
                $_serviceDataChange = $PSBoundParameters.ContainsKey('OauthUrl') -or
                                      $PSBoundParameters.ContainsKey('IncidentUrl') -or
                                      $PSBoundParameters.ContainsKey('RefreshTokenExpiryInDays') -or
                                      $PSBoundParameters.ContainsKey('ServiceEventIssues') -or
                                      $PSBoundParameters.ContainsKey('CriticalEventIssues') -or
                                      $PSBoundParameters.ContainsKey('WarningEventIssues') -or
                                      $PSBoundParameters.ContainsKey('UtilizationAlerts') -or
                                      $PSBoundParameters.ContainsKey('PowerResetEvent') -or
                                      $PSBoundParameters.ContainsKey('DisconnectedEvent')

                $payloadHash = [ordered]@{
                    name        = $Name
                    state       = "ENABLED"
                    description = $Description
                }

                if ($_credentialChange) {

                    if (-not $Credential) {
                        $ErrorMessage = "External service '{0}': Parameter '-Credential' (clientId/clientSecret) is required when updating the authentication token for SERVICE_NOW services in the '{1}' region!" -f $Name, $Region
                        if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
                        $objStatus.Status = "Warning"
                        $objStatus.Details = $ErrorMessage
                    }
                    elseif (-not $RefreshToken) {
                        $ErrorMessage = "External service '{0}': Parameter '-RefreshToken' is required when updating credentials for SERVICE_NOW services in the '{1}' region!" -f $Name, $Region
                        if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
                        $objStatus.Status = "Warning"
                        $objStatus.Details = $ErrorMessage
                    }
                    else {
                        $payloadHash['authentication'] = @{
                            clientId     = $ClientID
                            clientSecret = $clientSecret
                            refreshToken = $RefreshToken
                        }
                    }
                }

                if ($_serviceDataChange -and -not $objStatus.Status) {

                    if (-not $OauthUrl) {
                        $OauthUrl = $ExternalServicesResource.serviceData.oauthUrl
                    }

                    if (-not $IncidentUrl) {
                        $IncidentUrl = $ExternalServicesResource.serviceData.incidentUrl
                    }

                    if (-not $refreshTokenExpiryInDays) {
                        $refreshTokenExpiryInDays = $ExternalServicesResource.serviceData.refreshTokenExpiryInDays
                    }

                    # Incident scope: detect if any hierarchical scope field is being changed
                    $_anyScopeChange = $PSBoundParameters.ContainsKey('ServiceEventIssues') -or
                                       $PSBoundParameters.ContainsKey('CriticalEventIssues') -or
                                       $PSBoundParameters.ContainsKey('WarningEventIssues') -or
                                       $PSBoundParameters.ContainsKey('UtilizationAlerts')

                    if ($_anyScopeChange) {

                        # Resolve effective values: use supplied parameter if provided, otherwise retain the existing stored value
                        $_effServiceEventIssues  = if ($PSBoundParameters.ContainsKey('ServiceEventIssues'))  { $ServiceEventIssues }  else { [bool]$ExternalServicesResource.serviceData.serviceEventIssues }
                        $_effCriticalEventIssues = if ($PSBoundParameters.ContainsKey('CriticalEventIssues')) { $CriticalEventIssues } else { [bool]$ExternalServicesResource.serviceData.criticalEventIssues }
                        $_effWarningEventIssues  = if ($PSBoundParameters.ContainsKey('WarningEventIssues'))  { $WarningEventIssues }  else { [bool]$ExternalServicesResource.serviceData.warningEventIssues }
                        $_effUtilizationAlerts   = if ($PSBoundParameters.ContainsKey('UtilizationAlerts'))   { $UtilizationAlerts }   else { [bool]$ExternalServicesResource.serviceData.utilizationAlerts }

                        # Validate hierarchy: warningEventIssues requires criticalEventIssues
                        if ($_effWarningEventIssues -and -not $_effCriticalEventIssues) {
                            $ErrorMessage = "External service '{0}': -WarningEventIssues requires -CriticalEventIssues to be True in the '{1}' region!" -f $Name, $Region
                            if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
                            $objStatus.Status = "Warning"
                            $objStatus.Details = $ErrorMessage
                        }
                        # Validate hierarchy: criticalEventIssues requires serviceEventIssues
                        elseif ($_effCriticalEventIssues -and -not $_effServiceEventIssues) {
                            $ErrorMessage = "External service '{0}': -CriticalEventIssues requires -ServiceEventIssues to be True in the '{1}' region!" -f $Name, $Region
                            if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
                            $objStatus.Status = "Warning"
                            $objStatus.Details = $ErrorMessage
                        }
                        # At least one of serviceEventIssues or utilizationAlerts must be True
                        elseif (-not $_effServiceEventIssues -and -not $_effUtilizationAlerts) {
                            $ErrorMessage = "External service '{0}': At least one of -ServiceEventIssues or -UtilizationAlerts must be True in the '{1}' region!" -f $Name, $Region
                            if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request."; return }
                            $objStatus.Status = "Warning"
                            $objStatus.Details = $ErrorMessage
                        }
                    }

                    if (-not $objStatus.Status) {

                        $serviceDataBlock = @{
                            oauthUrl                 = $OauthUrl
                            incidentUrl              = $IncidentUrl
                            refreshTokenExpiryInDays = $refreshTokenExpiryInDays
                        }

                        if ($_anyScopeChange) {
                            $serviceDataBlock['serviceEventIssues']  = $_effServiceEventIssues
                            $serviceDataBlock['criticalEventIssues'] = $_effCriticalEventIssues
                            $serviceDataBlock['warningEventIssues']  = $_effWarningEventIssues
                            $serviceDataBlock['utilizationAlerts']   = $_effUtilizationAlerts
                        }

                        if ($PSBoundParameters.ContainsKey('PowerResetEvent')) {
                            $serviceDataBlock['powerResetEvent'] = $PowerResetEvent
                        }

                        if ($PSBoundParameters.ContainsKey('DisconnectedEvent')) {
                            $serviceDataBlock['disconnectedEvent'] = $DisconnectedEvent
                        }

                        $payloadHash['serviceData'] = $serviceDataBlock
                    }
                }

                $payload = ConvertTo-Json $payloadHash

                # Build sanitized payload for WhatIf display (mask sensitive credential fields)
                $SanitizedPayload = $payload -replace '"(clientSecret|password|refreshToken)":\s*"[^"]*"', '"$1": "[REDACTED]"'
            }

            # Deploy the external service. 
            if (-not $objStatus.Status) {
                try {
                    if ($WhatIf) {
                        $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method PATCH -body $SanitizedPayload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                    }
                    else {
                        $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method PATCH -body $payload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                    }

                    
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
    Test a configured external service integration in a region.

    .DESCRIPTION
    This Cmdlet can be used to verify the integration of a configured external service in a region.
    
    - For external service with serviceType SERVICE_NOW, the cmdlet generates a test incident in ServiceNow.
    - For external service with serviceType DSCC, the cmdlet tests the integration connection to Data Services Cloud Console. This test is available even if the configured DSCC integration is disabled.
    - VMware vCenter does not support a connectivity test.
       
    An activity will be generated as a result of this test and indicates the success or failure of the test.   
        
    .PARAMETER Name 
    Name of the external web service to test. 
    
    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) to update the external web service. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Test-HPECOMExternalService -Region eu-central -Name MyServiceNow_Name
    
    Generate a test incident for a ServiceNow external service integration.

    .EXAMPLE
    Get-HPECOMExternalService -Region eu-central | Test-HPECOMExternalService

    Test all supported external service integrations in the eu-central region. VMware vCenter integrations will be skipped with a warning.

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
                if (-not $Global:HPEGreenLakeSession) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use the cmdlets of the HPECOMCmdlets module."
                }
                if (-not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "Compute Ops Management is not provisioned in this workspace!`n`nCAUSE:`nNo provisioned Compute Ops Management region was found.`n`nACTION REQUIRED:`nVerify the Compute Ops Management service is provisioned using:`n    Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned`n`nIf not provisioned, you can provision it using 'New-HPEGLService'."
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
        $_ActivitySearchCriteria = [System.Collections.ArrayList]::new()

        $_Date = [datetime]::UtcNow

        
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
            $ErrorMessage = "External service '{0}': Resource cannot be found in the '{1}' region!" -f $Name, $Region
            if ($WhatIf) {
                
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {

                $objStatus.Status = "Warning"
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
                "VMWARE_VCENTER" {
                    $ErrorMessage = "External service '{0}': VMware vCenter does not support a connectivity test." -f $Name
                    if ($WhatIf) {
                        Write-Warning "$ErrorMessage Cannot display API request."
                        return
                    }
                    else {
                        $objStatus.Status = "Warning"
                        $objStatus.Details = $ErrorMessage
                    }
                }
                Default {
                        $ErrorMessage = "External service '{0}': Service type '{1}' is not supported for testing in the '{2}' region!" -f $Name, $ServiceType, $Region
                        if ($WhatIf) {
                            Write-Warning "$ErrorMessage Cannot display API request."
                            return
                        }
                        else {
                            $objStatus.Status = "Warning"
                            $objStatus.Details = $ErrorMessage
                        }
                }
            }

            $Uri = (Get-COMExternalServicesUri) + "/" + $ExternalServiceID + "/test"

            # Generate a test incident 
                     
            if (-not $objStatus.Status) {
                try {
                    $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -ContentType 'application/json' -Body (@{} | ConvertTo-Json) -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                
                    if (-not $WhatIf) {
                        "[{0}] External service test raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose
                        "[{0}] Test incident '{1}' has been successfully generated for '{2}' in '{3}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $ServiceTypeName, $Region | Write-Verbose
                        $objStatus.Status = "Complete"
                        $objStatus.Details = "Test incident has been successfully generated for $ServiceTypeName in $Region region"
                        [void] $_ActivitySearchCriteria.Add([pscustomobject]@{
                            Region      = $Region
                            SourceName  = $ServiceTypeSourceName
                            Category    = $ServiceTypeCategory
                            DisplayName = $Name
                        })
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
        }

        if (-not $WhatIf) {
            [void] $TestExternalServiceStatus.add($objStatus)
        }

    }

    end {

        if ($TestExternalServiceStatus.Count -gt 0) {

            if ($_ActivitySearchCriteria.Count -gt 0) {

                $_AllActivities = [System.Collections.ArrayList]::new()

                foreach ($_Criteria in $_ActivitySearchCriteria) {

                    "[{0}] Polling for activity: Region='{1}', SourceName='{2}', Category='{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_Criteria.Region, $_Criteria.SourceName, $_Criteria.Category | Write-Verbose

                    $_Elapsed = 0
                    $_MaxWait = 30
                    $_Activity = $null

                    do {
                        $_PercentComplete = [int](($_Elapsed / $_MaxWait) * 100)
                        Write-Progress -Id 10 -Activity "Testing external service '$($_Criteria.DisplayName)'" -Status "$_Elapsed / $_MaxWait seconds" -PercentComplete $_PercentComplete
                        $_Activity = Get-HPECOMActivity -Region $_Criteria.Region -SourceName $_Criteria.SourceName -Category $_Criteria.Category -WarningAction SilentlyContinue | Where-Object { ([datetime]$_.createdAt).ToUniversalTime() -gt $_Date }
                        if (-not $_Activity) { Start-Sleep 1; $_Elapsed++ }
                    } until ($_Activity -or $_Elapsed -ge $_MaxWait)

                    Write-Progress -Id 10 -Activity "Testing external service '$($_Criteria.DisplayName)'" -Completed

                    if ($_Activity) {
                        [void] $_AllActivities.Add($_Activity)
                    }
                    else {
                        "[{0}] Timed out waiting for activity: Region='{1}', SourceName='{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_Criteria.Region, $_Criteria.SourceName | Write-Verbose
                    }
                }

                $TestExternalServiceStatus = Invoke-RepackageObjectWithType -RawObject $TestExternalServiceStatus -ObjectName "COM.ExternalServices.NSDE"

                if ($_AllActivities.Count -gt 0) {
                    Return $_AllActivities
                }
                else {
                    Return $TestExternalServiceStatus
                }
            }
            else {
                $TestExternalServiceStatus = Invoke-RepackageObjectWithType -RawObject $TestExternalServiceStatus -ObjectName "COM.ExternalServices.NSDE"   
                Return $TestExternalServiceStatus
            }
        }
    }
}



Function Invoke-HPECOMExternalServiceVCenterFirmwareBaselineSync {
    <#
    .SYNOPSIS
    Synchronize the firmware baseline for a VMware vCenter external service integration in a region.

    .DESCRIPTION
    This Cmdlet triggers a firmware baseline synchronization job for a configured VMware vCenter external service.
    
    The synchronization retrieves the current firmware baseline from the connected vCenter server and updates the Compute Ops Management inventory.
    
    By default, the Cmdlet waits for the job to complete and returns a status object. Use -Async to return the job resource immediately, or -ScheduleTime to schedule the synchronization for a later time.
    
    Only external services with serviceType VMWARE_VCENTER are supported. Other service types will produce a warning.
        
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the VMware vCenter external service is configured.
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name
    Specifies the name of the VMware vCenter external service to synchronize.

    .PARAMETER ScheduleTime
    Specifies the date and time when the synchronization should be executed.
    This parameter accepts a DateTime object or a string representation of a date and time.
    If not specified, the synchronization will be executed immediately.

    Examples for setting the date and time using `Get-Date`:
    - (Get-Date).AddMonths(6)
    - (Get-Date).AddDays(15)
    - (Get-Date).AddHours(3)
    Example for using a specific date string:
    - "2024-05-20 08:00:00"

    .PARAMETER Interval
    Specifies the interval at which the synchronization should be repeated. This parameter accepts a string representation of an ISO 8601 period duration. If not specified, the synchronization will not be repeated.

    This parameter supports common ISO 8601 period durations such as:
    - P1D (1 Day)
    - P1W (1 Week)
    - P1M (1 Month)
    - P1Y (1 Year)

    The accepted formats include periods (P) referencing days, weeks, months, years but not time (T) designations that reference hours, minutes, and seconds.

    A valid interval must be greater than 15 minutes (PT15M) and less than 1 year (P1Y).

    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties). By default, the Cmdlet will wait for the job to complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Invoke-HPECOMExternalServiceVCenterFirmwareBaselineSync -Region us-west -Name "team13-vcsa.hol.enablement.local"
    
    Triggers a firmware baseline synchronization for the specified VMware vCenter external service integration and waits for completion.

    .EXAMPLE
    Get-HPECOMExternalService -Region us-west -ServiceType VMWARE_VCENTER | Invoke-HPECOMExternalServiceVCenterFirmwareBaselineSync
    
    Triggers firmware baseline synchronization for all VMware vCenter external service integrations in the us-west region and waits for each job to complete.

    .EXAMPLE
    Invoke-HPECOMExternalServiceVCenterFirmwareBaselineSync -Region us-west -Name "team13-vcsa.hol.enablement.local" -Async
    
    Triggers a firmware baseline synchronization and immediately returns the job resource to monitor.

    .EXAMPLE
    Invoke-HPECOMExternalServiceVCenterFirmwareBaselineSync -Region us-west -Name "team13-vcsa.hol.enablement.local" -ScheduleTime (Get-Date).AddHours(6)
    
    Schedules a firmware baseline synchronization to run 6 hours from now.

    .EXAMPLE
    Invoke-HPECOMExternalServiceVCenterFirmwareBaselineSync -Region us-west -Name "team13-vcsa.hol.enablement.local" -ScheduleTime (Get-Date).AddDays(1) -Interval P1W
    
    Schedules a weekly firmware baseline synchronization starting tomorrow.

    .INPUTS
    System.Collections.ArrayList
        List of external service(s) from 'Get-HPECOMExternalService'. 

    .OUTPUTS
    HPEGreenLake.COM.ExternalServices.NSDE [System.Management.Automation.PSCustomObject]

        Status object returned in default synchronous mode, with the following properties:
        - Name: Name of the external service for which synchronization was attempted
        - ServiceType: Service type of the external service
        - Region: Name of the region where the synchronization was triggered
        - Status: "Complete", "Failed", or "Warning"
        - Details: More information about the status
        - Exception: Exception object if an error occurred

    HPEGreenLake.COM.Jobs [System.Management.Automation.PSCustomObject]

        When the `-Async` switch is used, the cmdlet returns the job resource immediately.
        Monitor its progress using the `state` and `resultCode` properties, or pass it to `Wait-HPECOMJobComplete`.

    HPEGreenLake.COM.Schedules [System.Management.Automation.PSCustomObject]

        The schedule object returned when `-ScheduleTime` is used.

    #>

    [CmdletBinding(DefaultParameterSetName = 'Async')]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
        [ValidateScript({
                # First check if there's an active session with COM regions
                if (-not $Global:HPEGreenLakeSession) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use the cmdlets of the HPECOMCmdlets module."
                }
                if (-not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "Compute Ops Management is not provisioned in this workspace!`n`nCAUSE:`nNo provisioned Compute Ops Management region was found.`n`nACTION REQUIRED:`nVerify the Compute Ops Management service is provisioned using:`n    Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned`n`nIf not provisioned, you can provision it using 'New-HPEGLService'."
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

        [Parameter (Mandatory, ParameterSetName = 'Schedule')]
        [ValidateScript({
                if ($_ -ge (Get-Date) -and $_ -le (Get-Date).AddYears(1)) {
                    $true
                }
                else {
                    throw "The ScheduleTime must be within one year from the current date."
                }
            })]
        [DateTime]$ScheduleTime,

        [ValidateScript({
            # Validate ISO 8601 duration format
            if ($_ -notmatch '^P(?!$)(\d+Y)?(\d+M)?(\d+W)?(\d+D)?(T(\d+H)?(\d+M)?(\d+S)?)?$') {
                throw "Invalid duration format. Please use an ISO 8601 period interval (e.g., P1D, P1W, P1M, P1Y, PT1H, PT15M)"
            }

            # Extract duration parts
            $years   = [int]($matches[1] -replace '\D', '')
            $months  = [int]($matches[2] -replace '\D', '')
            $weeks   = [int]($matches[3] -replace '\D', '')
            $days    = [int]($matches[4] -replace '\D', '')
            $hours   = [int]($matches[6] -replace '\D', '')
            $minutes = [int]($matches[7] -replace '\D', '')
            $seconds = [int]($matches[8] -replace '\D', '')

            # Calculate total duration in seconds (approximate months/years)
            $totalSeconds = 0
            if ($years)   { $totalSeconds += $years * 365 * 24 * 3600 }
            if ($months)  { $totalSeconds += $months * 30 * 24 * 3600 }
            if ($weeks)   { $totalSeconds += $weeks * 7 * 24 * 3600 }
            if ($days)    { $totalSeconds += $days * 24 * 3600 }
            if ($hours)   { $totalSeconds += $hours * 3600 }
            if ($minutes) { $totalSeconds += $minutes * 60 }
            if ($seconds) { $totalSeconds += $seconds }

            $minSeconds = 15 * 60
            $maxSeconds = 365 * 24 * 3600  # 1 year

            if ($totalSeconds -lt $minSeconds) {
                throw "The interval must be greater than 15 minutes (PT15M)."
            }
            if ($totalSeconds -gt $maxSeconds) {
                throw "The interval must be less than 1 year (P1Y)."
            }
            return $true
        })]
        [Parameter (ParameterSetName = 'Schedule')]
        [String]$Interval,

        [Parameter (ParameterSetName = 'Async')]
        [switch]$Async,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $SyncStatus = [System.Collections.ArrayList]::new()

        $_JobTemplateName  = 'VcenterFirmwareBundlesSync'
        $JobTemplateId     = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id
        $JobsUri           = Get-COMJobsUri

        "[{0}] Job template '{1}' ID: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_JobTemplateName, $JobTemplateId | Write-Verbose

    }
    
    Process {
        
        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        try {
            $ExternalServicesResource = Get-HPECOMExternalService -Region $Region -Name $Name 
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        # Build object for the output (used in synchronous mode)
        $objStatus = [pscustomobject]@{
            Name        = $Name
            ServiceType = $ExternalServicesResource.ServiceType                       
            Region      = $Region                            
            Status      = $Null
            Details     = $Null
            Exception   = $Null
        }

        if (-not $ExternalServicesResource) {

            $ErrorMessage = "External service '{0}': Resource cannot be found in the '{1}' region!" -f $Name, $Region
            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "External service cannot be found in the region!"
            }

        }
        else {

            $ServiceType = $ExternalServicesResource.ServiceType

            if ($ServiceType -ne "VMWARE_VCENTER") {

                $ErrorMessage = "External service '{0}': Firmware baseline synchronization is only supported for VMware vCenter integrations. Service type '{1}' is not supported." -f $Name, $ServiceType
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

                if (-not $JobTemplateId) {
                    $ErrorMessage = "Job template '$_JobTemplateName' cannot be found in the loaded templates. Ensure you are connected and job templates are loaded."
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

                    $_ResourceUri = $ExternalServicesResource.resourceUri
                    $_ResourceId  = $ExternalServicesResource.id

                    if ($ScheduleTime) {

                        $Uri = Get-COMSchedulesUri

                        $_Body = @{
                            jobTemplateUri = "/api/compute/v1/job-templates/" + $JobTemplateId
                            resourceUri    = $_ResourceUri
                        }

                        $Operation = @{
                            type   = "REST"
                            method = "POST"
                            uri    = "/api/compute/v1/jobs"
                            body   = $_Body
                        }

                        $randomNumber = Get-Random -Minimum 000000 -Maximum 999999

                        $ScheduleName = "$($Name)_VCenterFirmwareBaselineSync_Schedule_$($randomNumber)"
                        $Description  = "Scheduled task to run a firmware baseline synchronization for vCenter integration '$($Name)'"

                        if ($Interval) {
                            $Schedule = @{
                                startAt  = $ScheduleTime.ToString("o")
                                interval = $Interval
                            }
                        }
                        else {
                            $Schedule = @{
                                startAt = $ScheduleTime.ToString("o")
                            }
                        }

                        $payload = @{
                            name                  = $ScheduleName
                            description           = $Description
                            associatedResourceUri = $_ResourceUri
                            purpose               = $Null
                            schedule              = $Schedule
                            operation             = $Operation
                        }

                    }
                    else {

                        $Uri = $JobsUri

                        $payload = @{
                            jobTemplate  = $JobTemplateId
                            resourceId   = $_ResourceId
                            resourceType = "compute-ops-mgmt/external-service"
                        }
                    }

                    $payload = ConvertTo-Json $payload -Depth 10

                    try {
                        $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                        if ($ScheduleTime) {

                            if (-not $WhatIf) {
                                $ReturnData = Invoke-RepackageObjectWithType -RawObject $Response -ObjectName "COM.Schedules"
                                "[{0}] Schedule created for '{1}' in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
                            }

                        }
                        else {

                            if (-not $WhatIf -and -not $Async) {

                                "[{0}] Firmware baseline sync job submitted for '{1}' in '{2}' region, waiting for completion..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose

                                $JobResult = Wait-HPECOMJobComplete -Region $Region -Job $Response.resourceUri -Verbose:$VerbosePreference

                                "[{0}] Job result: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($JobResult | Out-String) | Write-Verbose

                                if ($JobResult.resultCode -eq "SUCCESS") {
                                    "[{0}] Firmware baseline successfully synchronized for '{1}' in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
                                    $objStatus.Status = "Complete"
                                    $objStatus.Details = "Firmware baseline successfully synchronized for VMware vCenter integration '$Name' in $Region region"
                                }
                                else {
                                    $objStatus.Status = "Failed"
                                    $objStatus.Details = if ($JobResult.message) { $JobResult.message } else { "Firmware baseline sync job did not complete successfully. Result: $($JobResult.resultCode)" }
                                    $objStatus.Exception = $JobResult
                                }

                            }
                            else {

                                # Async — return raw job resource
                                if (-not $WhatIf) {
                                    $Response | Add-Member -type NoteProperty -name region -value $Region
                                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $Response -ObjectName "COM.Jobs"
                                }
                            }
                        }
                    }
                    catch {
                        if (-not $WhatIf) {
                            $objStatus.Status = "Failed"
                            $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Firmware baseline synchronization cannot be triggered for VMware vCenter integration '$Name'" }
                            $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                        }
                    }

                    # ScheduleTime → $ReturnData (COM.Schedules), Async → $ReturnData (COM.Jobs)
                    # Sync         → $objStatus accumulated into $SyncStatus for End block
                    if (-not $WhatIf) {
                        if (($ScheduleTime -or $Async) -and $ReturnData) {
                            Return $ReturnData
                        }
                    }
                }
            }
        }

        if (-not $WhatIf) {
            [void] $SyncStatus.add($objStatus)
        }

    }

    end {

        if ($SyncStatus.Count -gt 0) {
            $SyncStatus = Invoke-RepackageObjectWithType -RawObject $SyncStatus -ObjectName "COM.ExternalServices.NSDE"
            Return $SyncStatus
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
Export-ModuleMember -Function 'Get-HPECOMExternalService', 'Invoke-HPECOMExternalServiceVCenterFirmwareBaselineSync', 'New-HPECOMExternalService', 'Remove-HPECOMExternalService', 'Set-HPECOMExternalService', 'Test-HPECOMExternalService' -Alias *

# SIG # Begin signature block
# MIItTgYJKoZIhvcNAQcCoIItPzCCLTsCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBj0podRXSuaOh7
# j70aC7QGFD6kDdQplN8xLVSx3TKi/6CCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQgw3k0THabiGew6y4cU+xCpaB8WN3kQYcL6NPJpExrOekwDQYJKoZIhvcNAQEB
# BQAEggIA0iIfLT05arZZ1Z8Y0yuO8M/l61iCz0GGIl1s6QFfoNLb1+IbkCPdFjJn
# 2AjusmuMHsNKC3/I9Wh4q3qldKQyuK+PNLWzi68r+p9/ZAOlGtggYgC2Chf+J+f/
# vXfVMW9GmGbN6Eavg3kwzve8eMLu9TkCtU/PIHxQM09Ah2gEQT2T/GfbyWMbGhXo
# Q0WsBOZ/CgLYs7iWKADIykxA4bswYFt2b1E+Zq05Jb/8F2vqCnxZP+6qnHM5gCNp
# b3xrXne2NHm9PTdxsUnvFB4+5yg4b6elvtVclgOgqhXanY8DthxVGmzwdyHOr1dU
# EJ919GNFLBeGNI42HETmYzxx1XRlqG0+yxTgqyMWNoOuFNAk0LepqKk6l/jRxdRn
# XlNwty8//8LF/5qDLpTqhIYG2jn6/RIqq9g6TyzwtlXy3AtyBxpzwt2p7b+ZBSAC
# dKmF1gfdFVg7gnklvmoFdDFKpbx9kwd9+v5NWZATv2pVfDK4umQBHrFLjEyCJAKA
# TpprKH2MfGc6CrrmUQrEjc+EV3zEFGyHgodKNem8x6K4L3k0pSU1LIMtxp3MwuJk
# RxTD+s87JsvwfOWCzrKqZ9H0sLI2HTvR5s46tVZcf+QurWjAPCS8p6Uw6HICEgZD
# /PKHQjARve+1WQTdXap89HRcVGUr5lsRZKf3NoUgYL2HJw1AIkOhgheYMIIXlAYK
# KwYBBAGCNwMDATGCF4QwgheABgkqhkiG9w0BBwKgghdxMIIXbQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIGIBgsqhkiG9w0BCRABBKB5BHcwdQIBAQYJYIZIAYb9bAcBMEEw
# DQYJYIZIAWUDBAICBQAEMJitffIV4MLYvjdi6ohYZb1UPgLlcdrCc3iCcdEGxV4X
# H9QNSzqE8pza/Mv4lIPkeQIRANuOw9TgmWNa3yCDTu6JSIAYDzIwMjYwNDE1MDkw
# NjM0WqCCEzowggbtMIIE1aADAgECAhAMIENJ+dD3WfuYLeQIG4h7MA0GCSqGSIb3
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
# BgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI2MDQx
# NTA5MDYzNFowKwYLKoZIhvcNAQkQAgwxHDAaMBgwFgQUcrz9oBB/STSwBxxhD+bX
# llAAmHcwNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgMvPjsb2i17JtTx0bjN29j4uE
# dqF4ntYSzTyqep7/NcIwPwYJKoZIhvcNAQkEMTIEMItRG0KuxCnKTYgewDKyI7DL
# giVwny9m6f9n2MvOMfWid8SCA43qxdqaxm16GQ38KjANBgkqhkiG9w0BAQEFAASC
# AgDKtC1OJsRRm/bFo6uYUI/UbTjnvqmmYlCjkdG0wEPJrXA8LrJqlqtZO7IEwOue
# 3+YLpBj+hn+6aQmfx1vs+6Cbtgh7DMbpprAn6K5CCLDSWOAHP6OMkl7oPZeKRX+/
# fwIfy6c9CasAPDbtb0dvhppJjOj/53Oiq0VQBIraljd8JG48CLnH1doRJMUyXAOB
# 7y2k2SGOw9ZFzKHXpeDLTUZaBCKGXsRGbo0dCDZwYjC3LWT7K9wMYjMIKLKiTDKm
# FEV2njn0kKGqCAFtawU/Ss9oOwCqMQtrqoyKiPQUp5nx2zpT+sI8lkoT3HwqrEin
# r8I1OKH8yc3Bl+urkq2LjNX30ZOnbz8J1uDmDDS7KA9R8kTB/RUWc8RAiTWA2WMf
# k/6s3r8pvbJGJQqFvN25eLGyGv+X+cUDj5RoL6HKWFzybJXivAAS9q9GR/4mk2FG
# Avip6oV9WKWJn2kpGNwuzxkDQoQHJzWgQybzYr5MZXLHXuWT3mGTCxhy0haFFROy
# DLNlkWpvgIAB9yPtYOle7js61XQAWuNKfcDuLhlkhs99p725NSQNwGgvUzySthev
# UQRKH/NdVs3T4wUrWsNmOS/XHG1V5pSju94PCNWx/WixRg2Me9D95bHfSNS6Qq/W
# f/oYXFnpeKDvWouMFuFcwM6B19W2BW5A45LbS/RgH/XX3g==
# SIG # End signature block
