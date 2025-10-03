#------------------- FUNCTIONS FOR COMPUTE OPS MANAGEMENT APPLIANCES -----------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1

# Public functions
Function Get-HPECOMAppliance {
    <#
    .SYNOPSIS
    Retrieve the list of appliances.
    
    .DESCRIPTION
    This Cmdlet returns a collection of appliance resources in the specified region. 
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.  

    .PARAMETER Name
    Specifies the name of the appliance resource.      

    .PARAMETER IPAddress
    Specifies the IP address of the appliance resource.      

    .PARAMETER Limit 
    This parameter allows you to define the number of appliances to be displayed. 
   
    .PARAMETER Type 
    Optional parameter that can be used to get a certain type of appliances such as HPE Secure Gateway appliances, HPE OneView VM - VMware vSphere appliances, or HPE Synergy Composer appliances.

    .PARAMETER ShowActivationKey
    Optional switch parameter that can be used to display the activation key of the appliance.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central

    Return all appliances in the central european region. 

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Name oneview.hpelab.net

    Return the OneView appliance named 'oneview.hpelab.net' in the central european region. 

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Name oneview.hpelab.net -ShowActivationKey

    Return the activation key for the OneView appliance named 'oneview.hpelab.net' in the central european region.
    
    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Type OneViewVM

    Return data for all HPE OneView VM - VMware vSphere appliances located in the central European region.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Type SynergyComposer

    Return data for all HPE Synergy Composer appliances located in the central European region.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Type SecureGateway

    Return data for all HPE Secure Gateway Appliance located in the central European region.

    .EXAMPLE
    Get-HPECOMAppliance -Region us-west -name comgw.lab -ShowActivationKey 

    Return the activation key for the Secure Gateway appliance named 'comgw.lab' in the "us-west" region.

    
   #>
    [CmdletBinding(DefaultParameterSetName = 'Limit')]
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

        [Parameter (Mandatory, ParameterSetName = 'IP')]
        [ValidateScript({ [String]::IsNullOrEmpty($_) -or $_ -match [Net.IPAddress]$_ })]
        [string]$IPAddress,

        [Parameter (Mandatory, ParameterSetName = 'Name')]
        [String]$Name,

        [Parameter (ParameterSetName = 'Limit')]
        [ValidateScript({ $_ -le 1000 })]
        [int]$Limit,

        [Parameter (ParameterSetName = 'Limit')]
        [Parameter (ParameterSetName = 'IP')]
        [Parameter (ParameterSetName = 'Name')]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $environments = @('SynergyComposer', 'OneViewVM', 'SecureGateway')
                $filteredEnvironments = $environments | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredEnvironments | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateScript({
                $validOptions = @('SynergyComposer', 'OneViewVM', 'SecureGateway')
                
                if ($validOptions -contains $_) {
                    $True
                }
                else {
                    throw "'$_' is not a valid option."
                }
                
            })]                
        [String]$Type,

        [Switch]$ShowActivationKey,

        [Switch]$WhatIf
       
    ) 

    Begin {
  
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
      
      
    }
      
      
    Process {

        if ($ShowActivationKey -and (-not $Name) -and (-not $IPAddress)) {
            Throw "When using the -ShowActivationKey switch, you must also specify either the -Name or -IPAddress parameter to identify the specific appliance."
        }
      
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # No limit by default
        if ($Limit) {

            $Uri = (Get-COMOneViewAppliancesUri) + "?limit=$Limit"
       
        } 
        else {
            
            $Uri = Get-COMOneViewAppliancesUri 
        }           


        try {
            [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

        }
        catch {

            "[{0}] Exception object: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($_.Exception.data | Out-String) | Write-Verbose

            if ($_.Exception.Message -match 412) {

                "[{0}] Received 412 error due to missing OneView Edition subscription" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                
                Write-Warning "Looks like you do not have a Compute Ops Management - OneView Edition subscription to manage a OneView appliance."
                Return
            }
            else {

                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
        

        $ReturnData = @()
       
        if ($Null -ne $CollectionList) {      

            # Add region to object
            $CollectionList | Add-Member -type NoteProperty -name region -value $Region            
            
            if ($Type) {
                
                switch ($Type) {
                    "SecureGateway" { $_applianceType = "GATEWAY" }
                    "SynergyComposer" { $_applianceType = "SYNERGY" }
                    "OneViewVM" { $_applianceType = "VM" }
                }
                
                $CollectionList = $CollectionList | Where-Object applianceType -eq $_applianceType
            }
            
            
            if ($IPAddress) {
            
                $CollectionList = $CollectionList | Where-Object ipaddress -eq $IPAddress
                  
            } 
            elseif ($Name) {
                
                $CollectionList = $CollectionList | Where-Object name -eq $Name 
                
            }       
            
            if ($CollectionList.applianceType -eq "GATEWAY" -and $ShowActivationKey) {

                try {
                    $ActivationKey = New-HPECOMAppliance -Region $Region -SecureGateway 
                    Return $ActivationKey.ActivationKey
                
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }
            elseif ($ShowActivationKey) {
                    
                $CollectionList = $CollectionList.activationkey
                return $CollectionList 
                
            }
             
            $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Appliances"    
    
            $ReturnData = $ReturnData | Sort-Object name, ipaddress
        
            return $ReturnData 
           
        }
        else {

            return
                
        }     

    
    }
}

Function New-HPECOMAppliance {
    <#
    .SYNOPSIS
    Adds an HPE OneView or Secure Gateway appliance for management to a specific region. 

    .DESCRIPTION   
    This cmdlet adds an HPE OneView or Secure Gateway appliance to the specified Compute Ops Management region for management. It generates an activation key that is used to connect the appliance to Compute Ops Management.
    
    For OneView appliances, the activation key can be retrieved using the 'Get-HPECOMAppliance -Name <OV hostname> -ShowActivationKey' cmdlet. 
    This activation key is required to enable Compute Ops Management in OneView using the 'Enable-OVComputeOpsManagement -ActivationKey $ActivationKey' cmdlet from the HPE OneView PowerShell library.

    For Secure Gateway appliances, the same activation key can be used to connect multiple Secure Gateway appliances to Compute Ops Management within 72 hours.

    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the appliance will be located.  
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER SecureGateway    
    Specifies that the appliance to be added is an HPE Secure Gateway appliance. This parameter is mandatory when adding an HPE Secure Gateway appliance.
    
    .PARAMETER OneView    
    Specifies that the appliance to be added is an HPE OneView appliance. This parameter is mandatory when adding an HPE OneView appliance.

    .PARAMETER OneViewID
    Specifies the ID of the OneView appliance to be added to the region. This parameter is mandatory when adding an HPE OneView appliance.

    Note: The OneView ID can be retrieved using the 'Get-OVComputeOpsManagement' cmdlet from the HPE OneView PowerShell library.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    $credentials = Get-Credential
    Connect-OVMgmt -Appliance OV.domain.com -Credential $credentials
    $AddTask = Get-OVComputeOpsManagement | New-HPECOMAppliance -Region eu-central -OneView
    Enable-OVComputeOpsManagement -ActivationKey $AddTask.activationkey
    
    In this example:
    1. Prompts the user to enter their credentials and stores them in the $credentials variable.
    2. Establishes a connection to the OV.domain.com appliance using the Connect-OVMgmt cmdlet, passing the appliance URL (OV.domain.com) and the credentials stored in the $credentials variable.
    3. Retrieves the Compute Ops Management configuration from OneView using the HPE OneView PowerShell library, then pipes the output to add the OneView appliance to the 'eu-central' region.
    4. Activates the Compute Ops Management configuration in OneView using the obtained activation key from the returned $AddTask object with the 'Enable-OVComputeOpsManagement' cmdlet. The activation key is required for enabling Compute Ops Management in OneView.

    .EXAMPLE
    $credentials = Get-Credential
    Connect-OVMgmt -Appliance OV.domain.com -Credential $credentials
    $ApplianceID = (Get-OVComputeOpsManagement).ApplianceID
    $AddTask = New-HPECOMAppliance -Region eu-central -OneView -OneViewID $ApplianceID 
    Enable-OVComputeOpsManagement -ActivationKey $AddTask.activationkey

    In this example:
    1. Prompts the user to enter their credentials and stores them in the $credentials variable.
    2. Establishes a connection to the OV.domain.com appliance using the Connect-OVMgmt cmdlet, passing the appliance URL (OV.domain.com) and the credentials stored in the $credentials variable.
    3. Retrieves the ApplianceID from 'Get-OVComputeOpsManagement'.
    4. Adds the OneView appliance to the 'eu-central' region using the appliance ID.
    5. Activates the Compute Ops Management configuration in OneView using the obtained activation key from the returned $AddTask object with the 'Enable-OVComputeOpsManagement' cmdlet. The activation key is required for enabling Compute Ops Management in OneView.

    .EXAMPLE
    New-HPECOMAppliance -Region us-west -SecureGateway 

    Adds an HPE Secure Gateway appliance to the 'us-west' region and returns the activation key to use in the secure gateway console to connect the appliance to Compute Ops Management.

    .INPUTS
    System.Collections.ArrayList
        OneView appliance details from 'Get-OVComputeOpsManagement' (HPE OneView PowerShell library).

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Region - Name of the region 
        * ApplianceType - Type of the appliance (OneView or Secure Gateway)
        * ID - ID of the OneView appliance attempted to be added to the region
        * ActivationKey - The activation key to be used in the appliance for enabling Compute Ops Management
        * ExpiresOn - The expiration date of the Secure Gateway activation key (72 hours from the time of appliance addition)
        * Status - The status of the addition attempt (Failed for HTTP error return; Complete if addition is successful; Warning if no action is needed) 
        * Details - More information about the status 
        * Exception - Information about any exceptions generated during the operation.
#>

    [CmdletBinding(DefaultParameterSetName = 'OneView')]
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

        [Parameter (Mandatory, ParameterSetName = 'SecureGateway')]
        [Switch]$SecureGateway,

        [Parameter (Mandatory, ParameterSetName = 'OneView')]
        [Switch]$OneView,
                
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'OneView')]
        [alias('ApplianceID')]
        [String]$OneViewID,
                  
        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $AddApplianceStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose


        if ($OneView) {

            # Build object for the output
            $objStatus = [pscustomobject]@{
  
                Region        = $Region   
                ApplianceType = "OneView"
                ID            = $OneViewID
                ActivationKey = $Null                         
                Status        = $Null
                Details       = $Null
                Exception     = $Null
            }

            $Uri = Get-COMOneViewAppliancesUri           
            
            try {
                $CurrentAppliances = Get-HPECOMAppliance -Region $Region 

                $ApplianceSubscrition = Get-HPEGLSubscription -ShowValid -ShowWithAvailableQuantity -ShowServiceSubscriptions | Where-Object { $_.skudescription -match "Compute Ops Management - OneView Edition" }
              
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }

            # Alert if appliance already exists in the region
            if ($CurrentAppliances | Where-Object { $_.ID -eq $OneViewID }) {

                "[{0}] OneView appliance with ID '{1}' is already present in this service instance!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $OneViewID | Write-Verbose
            
                if ($WhatIf) {
                    $ErrorMessage = "OneView appliance '{0}': Resource is already present in the '{1}' region! No action needed." -f $OneViewID, $Region
                    Write-warning $ErrorMessage
                    return
                }
                else {
                    $objStatus.Status = "Warning"
                    $objStatus.Details = "OneView appliance already exists in '$Region' region. No action needed."
                }

            }
            # Error if COM-OVE license is not available
            elseif (-not $ApplianceSubscrition) {

                "[{0}] No Compute Ops Management - OneView Edition license available in the workspace." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            
                if ($WhatIf) {
                    $ErrorMessage = "No Compute Ops Management - OneView Edition license available in the workspace. Please add a license first using 'New-HPEGLSubscription' to add the appliance."
                    Write-warning $ErrorMessage
                    return
                }
                else {
                  
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "No Compute Ops Management - OneView Edition license available in the workspace. Please add a license first using 'New-HPEGLSubscription' to add the appliance."
                }

            }
            else {
                
                # Build payload
                $payload = ConvertTo-Json @{
                    id = $OneViewID
                }          
                      
                # Add resource
                try {
                    $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                                
                    if (-not $WhatIf) {
        
                        "[{0}] Add OneView appliance call response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose
                            
                        "[{0}] OneView appliance '{1}' successfully added to '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $OneViewID, $Region | Write-Verbose
                                
                        $objStatus.Status = "Complete"
                        $objStatus.Details = "Use 'Enable-OVComputeOpsManagement -ActivationKey <activation key>' from the OneView Powershell library to activate the appliance for Compute Ops Management"
                        $objStatus.ActivationKey = $Response.ActivationKey
            
                    }
            
                }
                catch {
            
                    if (-not $WhatIf) {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "OneView appliance cannot be added to $Region region!"
                        $objStatus.Exception = $Global:HPECOMInvokeReturnData 
            
                    }
                }   
            }
    
                    
            [void] $AddApplianceStatus.add($objStatus)

        }
        elseif ($SecureGateway) {

            # Build object for the output
            $objStatus = [pscustomobject]@{
  
                Region        = $Region   
                ApplianceType = "Secure Gateway"
                ActivationKey = $Null   
                ExpiresOn     = (get-date).AddHours(72)
                Status        = $Null
                Details       = $Null
                Exception     = $Null
            }

            $Uri = Get-COMActivationKeysUri

            
            # Build payload
            $payload = ConvertTo-Json @{
                expirationInHours = 72
                targetDevice      = "SECURE_GATEWAY"
            }          
                  
  
            # Add resource
            try {
                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                            
                if (-not $WhatIf) {
    
                    "[{0}] Add Secure gateway appliance call response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose
                        
                    "[{0}] Secure gateway appliance activation key successfully generated for '{1}' region: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, $Response.activationKey | Write-Verbose
                            
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Enter the activation key in the secure gateway console to connect the appliance(s) to Compute Ops Management."
                    $objStatus.ActivationKey = $Response.ActivationKey
        
                }
        
            }
            catch {
        
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Secure gateway appliance activation key cannot be generated!"
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
        
                }
            }   
                    
            [void] $AddApplianceStatus.add($objStatus)

        }          
    }

    end {

        if (-not $WhatIf) {

            if ($OneView) {

                $AddApplianceStatus = Invoke-RepackageObjectWithType -RawObject $AddApplianceStatus -ObjectName "COM.Appliances.OneView"    
            }
            elseif ($SecureGateway) {

                $AddApplianceStatus = Invoke-RepackageObjectWithType -RawObject $AddApplianceStatus -ObjectName "COM.Appliances.SecureGateway"    
            }

            Return $AddApplianceStatus
        }


    }
}

Function Remove-HPECOMAppliance {
    <#
    .SYNOPSIS
    Remove an appliance from management.

   .DESCRIPTION   
    This cmdlet removes an appliance from a specified Compute Ops Management region. 

    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the appliance is located.  
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name
    Specifies the name of the appliance resource.      

    .PARAMETER IPAddress
    Specifies the IP address of the appliance resource.    

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

   .EXAMPLE
    Remove-HPECOMAppliance -Region eu-central -Name oneview.lab
    
    This example removes the appliance named 'oneview.lab' from the eu-central region.
        
    .EXAMPLE
    Remove-HPECOMAppliance -Region eu-central -IPAddress 192.168.1.22

    This example removes the appliance with the IP address '192.168.1.22' from the eu-central region.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Type SynergyComposer | Remove-HPECOMAppliance 

    This example removes all Synergy Composer appliances from the eu-central region.

    .EXAMPLE
    "192.168.1.10", "192.168.1.20" | Remove-HPECOMAppliance -Region eu-central 

    This example removes the appliances with the IP addresses '192.168.1.10' and '192.168.1.20' from the eu-central region.

    .EXAMPLE
    $ApplianceID = (Get-OVComputeOpsManagement ).ApplianceID
    Remove-HPECOMAppliance -Region eu-central -Hostname $ApplianceID 

    This example removes a OneView appliance from the 'eu-central' region using the appliance ID returned by the 'Get-OVComputeOpsManagement' cmdlet from the HPE OneView PowerShell library. This is typically done for appliances that have not been activated.
    
    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the appliance's IP addresses.

    System.Collections.ArrayList
        A list of OneView appliances from 'Get-HPECOMAppliance'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - Name of the appliance attempted to be removed from the region
        * Region - Name of the region 
        * Status - The status of the removal attempt (Failed for http error return; Complete if removal is successful; Warning if no action is needed) 
        * Details - Additional information about the status.
        * Exception: Information about any exceptions generated during the operation.

   #>

    [CmdletBinding(DefaultParameterSetName = 'Name')]
    Param( 

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)] 
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

        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Name')]
        [String]$Name,

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'IP')]
        [ValidateScript({ [String]::IsNullOrEmpty($_) -or $_ -match [Net.IPAddress]$_ })]
        [string]$IPAddress,
                  
        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $RemoveApplianceStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose


        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name      = $Null
            Region    = $Region   
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

        try {

            if ($Name) {
    
                $ParamUsed = $Name
    
                $_Appliance = Get-HPECOMAppliance -Region $Region -Name $Name
            }
            else {
    
                $ParamUsed = $IPAddress
    
                $_Appliance = Get-HPECOMAppliance -Region $Region -IPAddress $IPAddress
    
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }
        

        $objStatus.name = $ParamUsed

        if (-not $_Appliance) {
                
            # Must return a message if not found

            if ($WhatIf) {

                $ErrorMessage = "Appliance '{0}': Resource cannot be found in the '{1}' region!" -f $ParamUsed, $Region
                Write-warning $ErrorMessage
                return
            
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "Appliance cannot be found in the region!"
              
            }

        }
        else {   
            
            $Uri = $_Appliance.resourceUri                    
              
            try {
                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method DELETE -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                        
                if (-not $WhatIf) {

                    "[{0}] Remove appliance call response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose
                    
                    "[{0}] Appliance '{1}' successfully removed from '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ParamUsed, $Region | Write-Verbose
                        
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Appliance successfully removed from $Region region"
    
                }
    
            }
            catch {
    
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Appliance cannot be removed from $Region region!"
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
    
                }
            }   
            
        }

        [void] $RemoveApplianceStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            $RemoveApplianceStatus = Invoke-RepackageObjectWithType -RawObject $RemoveApplianceStatus -ObjectName "COM.objStatus.NSDE"  
            Return $RemoveApplianceStatus
        }


    }
}

Function Get-HPECOMApplianceFirmwareBundle {
    <#
    .SYNOPSIS
    Retrieve the list of appliance firmware bundles in the specified region.

    .DESCRIPTION
    This Cmdlet returns a collection of appliance firmware bundles that are available to update an appliance.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Version 
    Optional parameter that can be used to display the appliance firmware bundles of a specific version such as 8.6, 8.60 or 8.60.01.

    .PARAMETER LatestVersion 
    Optional parameter that can be used to display the latest appliance firmware bundles version.

    .PARAMETER Type 
    Optional parameter that can be used to display the appliance firmware bundles of a specific type such as VM or Synergy.

    .PARAMETER SupportedUpgrades 
    Optional parameter to show the supported upgrade paths for upgrading an appliance with the specified bundle version (or latest version if -LatestVersion is used). 
    The list returns the versions from which an appliance can be upgraded. This parameter requires either the -Version or -LatestVersion parameter to be specified.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMApplianceFirmwareBundle -Region eu-central 

    Return all appliance firmware bundles data in the central european region. 

    .EXAMPLE
    Get-HPECOMApplianceFirmwareBundle -Region eu-central -Version "8.9" 

    Return all appliance firmware bundles data for a specified version. 

    .EXAMPLE
    Get-HPECOMApplianceFirmwareBundle -Region eu-central -Version "8.9" -Type Synergy

    Return all Synergy appliance firmware bundles data for a specified version. 

    .EXAMPLE
    Get-HPECOMApplianceFirmwareBundle -Region eu-central -LatestVersion

    Return the latest appliance firmware bundles version. 

    .EXAMPLE
    Get-HPECOMApplianceFirmwareBundle -Region eu-central -Version 10.00.00 -Type Synergy -SupportedUpgrades 

    Return the supported upgrade paths for upgrading a Synergy appliance to version 10.00.00.

    .EXAMPLE
    Get-HPECOMApplianceFirmwareBundle -Region eu-central -LatestVersion -Type VM -SupportedUpgrades

    Return the supported upgrade paths for upgrading a VM appliance to the latest version.

    
   #>
    [CmdletBinding(DefaultParameterSetName = 'Version')]
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

        [Parameter (Mandatory, ParameterSetName = 'SupportedUpgrades')]
        [Parameter (ParameterSetName = 'Version', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("Name")]
        [String]$Version,

        [Parameter (ParameterSetName = 'Latest')]
        [Switch]$LatestVersion,

        [Parameter (ParameterSetName = 'Latest')]
        [Parameter (Mandatory, ParameterSetName = 'SupportedUpgrades')]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $environments = @('Synergy', 'VM')
                $filteredEnvironments = $environments | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredEnvironments | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateScript({
                $validOptions = @('Synergy', 'VM')
                
                if ($validOptions -contains $_) {
                    $True
                }
                else {
                    throw "'$_' is not a valid option."
                }
                
            })]
        [String]$Type,

        [Parameter (ParameterSetName = 'Latest')]
        [Parameter (ParameterSetName = 'SupportedUpgrades')]
        [Switch]$SupportedUpgrades,

        [Switch]$WhatIf
       
    ) 


    Begin {
  
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
      
        # If supported upgrades is specified, ensure that either version or latestversion is also specified
        if ($SupportedUpgrades -and -not ($Version -or $LatestVersion)) {
            Throw "The -SupportedUpgrades parameter requires either the -Version or -LatestVersion parameter to be specified."
        }
      
    }
      
      
    Process {
      
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose    

        $Uri = Get-COMApplianceFirmwareBundlesUri

        try {
            [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
               
        }

        $ReturnData = @()
       
        if ($Null -ne $CollectionList) {     
                

            if ($Version) {

                $CollectionList = $CollectionList | Where-Object applianceVersion -match $Version

            }   

            if ($Type) {

                $CollectionList = $CollectionList | Where-Object applianceType -match $Type

            }  

            if ($LatestVersion) {

                $Latestversionitems = @()
                $maxVersion = [version]'0.0.0'

                foreach ($item in $CollectionList) {
                    $currentVersion = [version]$item.applianceVersion
                    if ($currentVersion -gt $maxVersion) {
                        $maxVersion = $currentVersion
                        $Latestversionitems = @()
                        $Latestversionitems += $item
                    }
                    elseif ($currentVersion -eq $maxVersion) {
                        # If current version matches the max version, add it to the list
                        $Latestversionitems += $item
                    }
                }

                $CollectionList = $Latestversionitems

            }  

            
            if ($SupportedUpgrades) {

                $CollectionList = $CollectionList.supportedUpgrades

            } 

            # Add region to object
            $CollectionList | Add-Member -type NoteProperty -name region -value $Region

            $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.ApplianceFirmwareBundles"    
    
            $ReturnData = $ReturnData #| Sort-Object { $_.updatedAt }
        
            return $ReturnData 
                
        }
        else {

            return
                
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
Export-ModuleMember -Function 'Get-HPECOMAppliance', 'New-HPECOMAppliance', 'Remove-HPECOMAppliance', 'Get-HPECOMApplianceFirmwareBundle' -Alias *

# SIG # Begin signature block
# MIItTgYJKoZIhvcNAQcCoIItPzCCLTsCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA7d0gpTDVqc8L5
# 2hBLVB31HYQNGNd0esovhCM+ZrvnOqCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQggszEOqp9q2SEbGJrnAWpT2omwhdE0XC5LXVLqEGG0YAwDQYJKoZIhvcNAQEB
# BQAEggIABh5OTKN2A1uYVH4Riqc9jVhCYJ+OhT9WIaIfnXzFnNsHwEJuTES1N2TB
# dU4YYyLjrWyfRoYktFP+UdyW2qO7upzZOdbPNwgQg9EqKYkJ2mp5MVzexWS43eUU
# VvOHKOjgHTKlIzcSuJyIIOlaBR/Dgv0tKdcbZvPa1XhxadbkYzLLo1GuJK9yACHg
# T2uOh+AnN1lsaz3ipTs5AMYaL2lfiDDgf8FFstiWGMZ4g80qA2bvCYNRYddnCwOs
# 5N1e/6XzNckK9CD51aD3bjt3Ox2UoVIsOZYElJVSCgn3vQCR3oY4seOmjb3uuuEz
# jjnrfrpx8cOAk8aFdryw/YHjoVTlMFWfMrsrp/upk7KFYU+kTk2Yp9OvXqCpbZRb
# aYC0Vdtn9zquvrEr62IFRVooxH8CKJVa7rxbyXVzbmHxwuV4ue16+lDsMzqLlLdz
# oWVytpP6eZCiSTajLtMEyMiaUOo/uBKMuz7pIl2JivY+2NttTU+cotGEN3dhCfuw
# OzhHJIXLOSXRh17OLK08SGoCOnqzIRgT//A0K8omqBhzDq3oPdRxUJvPYLg9YfoE
# j0Pc1p/VyRlczU7l0b70OVRj3Qy7N5DAXtkO/B3afHtbPde6DbQcTcXDZ+wQ0sQh
# 88XKyfiqPhoXj1wFiPm42UQudpBWiivFR2uJEGWcjGBOMzW7YWGhgheYMIIXlAYK
# KwYBBAGCNwMDATGCF4QwgheABgkqhkiG9w0BBwKgghdxMIIXbQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIGIBgsqhkiG9w0BCRABBKB5BHcwdQIBAQYJYIZIAYb9bAcBMEEw
# DQYJYIZIAWUDBAICBQAEMLfkAf/EZicJvkRK19tRHBXltu1nvo8Dkl5T6Y1oUou+
# svphflVG6QnG83DY6R6oLgIRANoVvQYCg4gH55Y/ns+1kvsYDzIwMjUxMDAyMTU0
# NDAwWqCCEzowggbtMIIE1aADAgECAhAMIENJ+dD3WfuYLeQIG4h7MA0GCSqGSIb3
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
# BgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI1MTAw
# MjE1NDQwMFowKwYLKoZIhvcNAQkQAgwxHDAaMBgwFgQUcrz9oBB/STSwBxxhD+bX
# llAAmHcwNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgMvPjsb2i17JtTx0bjN29j4uE
# dqF4ntYSzTyqep7/NcIwPwYJKoZIhvcNAQkEMTIEMAbP5HwxRvVK/LwdipvB3Kgy
# rupWUlXsN2GGcQ9YOxKPFPygdgxMyRk8jo/y+0T02TANBgkqhkiG9w0BAQEFAASC
# AgB1R4J1qIM7A9RFdLphundIfHV7zoNRqVZHx4pfeQFBLqisajuvSCCOX14NFFle
# q33KOGHHIVcB8XBs0ZxzzVHPIJBBN8Y4XSJkOBt+f6FeGUYIMLbEY60qg2k2xrAk
# h9cRegXb6oqStb7wT9TONSmr+jlEkI/XFs51BDP+eqD+YOguN12/zyWe24e79jyR
# oosywYqOwmnedES/jVFEGsItugGEc7Ege3FC73KpMbSkkzvFnK/Cm3ydpK7mFX4o
# jziInkjlKS+zg3Lp8HSW7yiHbJlWsuSa8Ta8ftdgX0Vw0OBjqEzepZYzoxnieeBk
# /l4ivd8ewkETTuUBcZfDv5oo5spzFpnH5Us3fQhHHFFXMso7FMm5Bi1ix6+3JYf8
# bd9oPXiZ/Bj+y10VuXjQw819ceiVdHIjq8E7eAwxqvWWINWH4zljL3XzRbPZObUF
# ss1aiefEJdl/sFytu93p8pjsXluPVPuTrO0eyeSBLHPQv2QNZI7gMm68OoWxU2BU
# 9KNZ3ug6r7x24cngnxe2sxfWewxHB5F9jzk6Jny/XdXLCo3Yr0+u/ygqMqdBuCWv
# jaLjhcDyM0XxKAC5kySOdqCDiQrLfNG4LDaL9+49Mj1mQcG/V3C72eKiWrU5hHls
# Hjqc+knYElLWaNK1KS/GV4FYm032gu7HeM410a9IVO3oLg==
# SIG # End signature block
