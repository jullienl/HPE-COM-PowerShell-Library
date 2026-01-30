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
    Specifies the name or IP address of the appliance resource.
    This parameter accepts both hostnames and IP addresses. The cmdlet automatically detects whether the provided value is an IP address or hostname.
    You can also use the -IPAddress alias for clarity when providing an IP address.

    .PARAMETER Limit 
    This parameter allows you to define the number of appliances to be displayed. 
   
    .PARAMETER Type 
    Optional parameter that can be used to get a certain type of appliances such as HPE Secure Gateway appliances, HPE OneView VM - VMware vSphere appliances, or HPE Synergy Composer appliances.

    .PARAMETER ShowActivationKey
    Optional switch parameter that can be used to display the activation key of the appliance.

    .PARAMETER ShowActivities
    Optional switch parameter that can be used to retrieve activities from the last month for the specified appliance(s). 
    When used with -Name, it retrieves activities for that specific appliance.
    When used without -Name, it retrieves activities for all appliances in the region using the Appliance category filter.

    .PARAMETER ShowJobs
    Optional switch parameter that can be used to retrieve jobs from the last month for the specified appliance(s).
    When used with -Name, it retrieves jobs for that specific appliance.
    When used without -Name, it retrieves jobs for all appliances in the region using the Appliance category filter.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central

    Return all appliances in the central european region. 

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Name oneview.hpelab.net

    Return the OneView appliance named 'oneview.hpelab.net' in the central european region. 

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Name 192.168.1.65

    Return the appliance with IP address '192.168.1.65' in the central european region.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -IPAddress 192.168.1.65

    Return the appliance with IP address '192.168.1.65' in the central european region using the -IPAddress alias.

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

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Name oneview.hpelab.net -ShowActivities

    Return activities from the last month for the OneView appliance named 'oneview.hpelab.net'.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -ShowActivities

    Return activities from the last month for all appliances in the eu-central region.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Name oneview.hpelab.net -ShowJobs

    Return jobs from the last month for the OneView appliance named 'oneview.hpelab.net'.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -ShowJobs

    Return jobs from the last month for all appliances in the eu-central region.

    
   #>
    [CmdletBinding(DefaultParameterSetName = 'Limit')]
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

        [Parameter (Mandatory, ParameterSetName = 'Name')]  
        [Parameter (ParameterSetName = 'ShowActivities')]
        [Parameter (ParameterSetName = 'ShowJobs')]
        [Alias('IPAddress')]
        [String]$Name,

        [Parameter (ParameterSetName = 'Limit')]
        [ValidateScript({ $_ -le 1000 })]
        [int]$Limit,

        [Parameter (ParameterSetName = 'Limit')]
        [Parameter (ParameterSetName = 'ShowActivities')]
        [Parameter (ParameterSetName = 'Name')]
        [Parameter (ParameterSetName = 'ShowJobs')]
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

        [Parameter (Mandatory, ParameterSetName = 'ShowActivities')]
        [Switch]$ShowActivities,

        [Parameter (Mandatory, ParameterSetName = 'ShowJobs')]
        [Switch]$ShowJobs,

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
            
            
            if ($Name) {
                # Check if $Name is an IP address or a hostname
                if ($Name -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
                    $CollectionList = $CollectionList | Where-Object ipaddress -eq $Name
                }
                else {
                    $CollectionList = $CollectionList | Where-Object name -eq $Name
                }
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
            elseif ($ShowActivities) {

                if ($Name) {
                    # Get activities for specific appliance
                    if (-not $CollectionList -or $CollectionList.Count -eq 0) {
                        Write-Warning "Appliance not found."
                        return
                    }

                    if ($CollectionList.Count -gt 1) {
                        Write-Warning "Multiple appliances found. Please refine your query to return only one appliance."
                        return
                    }

                    $ApplianceName = $CollectionList.name

                    try {
                        "[{0}] Retrieving activities for appliance '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ApplianceName | Write-Verbose
                        [Array]$Activities = Get-HPECOMActivity -Region $Region -SourceName $ApplianceName -ShowLastMonth -Verbose:$VerbosePreference -WhatIf:$WhatIf -WarningAction SilentlyContinue
                        return $Activities
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }
                } else {
                    # Get activities for all appliances using Category filter
                    "[{0}] Retrieving activities for all appliances in region '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose
                    return Get-HPECOMActivity -Region $Region -Category Appliance -ShowLastMonth -Verbose:$VerbosePreference -WhatIf:$WhatIf -WarningAction SilentlyContinue
                }
            }
            elseif ($ShowJobs) {

                if ($Name) {
                    # Get jobs for specific appliance
                    # Need to get the appliance name first
                    if ($Name -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
                        $ApplianceMatch = $CollectionList | Where-Object ipaddress -eq $Name
                    }
                    else {
                        $ApplianceMatch = $CollectionList | Where-Object name -eq $Name
                    }

                    if (-not $ApplianceMatch -or $ApplianceMatch.Count -eq 0) {
                        Write-Warning "Appliance not found."
                        return
                    }

                    if ($ApplianceMatch.Count -gt 1) {
                        Write-Warning "Multiple appliances found. Please refine your query to return only one appliance."
                        return
                    }

                    $ApplianceName = $ApplianceMatch.name

                    try {
                        "[{0}] Retrieving jobs for appliance '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ApplianceName | Write-Verbose
                        [Array]$Jobs = Get-HPECOMJob -Region $Region -SourceName $ApplianceName -ShowLastMonth -Verbose:$VerbosePreference -WhatIf:$WhatIf -WarningAction SilentlyContinue
                        return $Jobs
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }
                } else {
                    # Get jobs for all appliances using Category filter
                    "[{0}] Retrieving jobs for all appliances in region '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose
                    return Get-HPECOMJob -Region $Region -Category Appliance -ShowLastMonth -Verbose:$VerbosePreference -WhatIf:$WhatIf -WarningAction SilentlyContinue
                }
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
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "OneView appliance cannot be added to $Region region!"}
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
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Secure gateway appliance activation key cannot be generated!"}
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
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Appliance cannot be removed from $Region region!"}
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
# MIIunwYJKoZIhvcNAQcCoIIukDCCLowCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCGb7BpzKbebl5y
# yJc+vy0q/kYenmUI9F/icWTIGm4jW6CCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQgh16j9zEEwfi3DBcsJ2shXxqULa68b1JqNefje4k9GMEwDQYJKoZIhvcNAQEB
# BQAEggIAm8Fn2XWz4qO3sUuihmGWZx2bL25EIO+gheHDrtt0ErnD826EYjlQpNlF
# 7JXi/GHRIvAmejZJ6epqhF/ObZG3SE4XLA8ejKyYTO/+Qxs+ORC4QSyZGtnf5jRC
# iX8jbF1qF8kAgWPfLdrFFbC8yMHPhAP+OqwOkKf73ttKiU5N/5bB10AWctfHeqPN
# hcw5c1f7t8s0wMkpBBZGFv+SgvAbGQVse9nxLdFszFykIQk8bw1kMhH0YDrFGXGU
# j6cYGN32vU4Othyb+tHGdlxrnbXrhMSUPHcvmMsTWrWVUCIFLtVULEsabdVZPTNQ
# HRYKtPscQBoyAsfl0liqbEngoAwdV0fDEWeETcOOWjlOsTCWcIGachUuFfD2xIG/
# bDBXcncz03efHH1DFWQT+a/5ajMGSsiIgdjNUYMqRlH3y4xgdC7xBy7om5RSvED4
# MDW0KHNfmVy8ihn6KkSgUhg9QsVIti3TVFhhvMRWbmBfyEecpiQpQ3fxxaNRqKHj
# dNnaRyi2VOW54273zbr8JNK5rovQieJB+TUkIgdPHvqpahf/o6LJrTc9KjXD8d0Z
# 0r7uqFVocftpd2NlH6Pj29Kc10ABUz7IudZXzqAFE59y2TiOU1ffvESIGtH8N5pb
# ZxcE0Q2WfjSp95kAh9dDDr0ctNZHkEa1tWMGuBkrVU61PiAEf2WhghjpMIIY5QYK
# KwYBBAGCNwMDATGCGNUwghjRBgkqhkiG9w0BBwKgghjCMIIYvgIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBCAYLKoZIhvcNAQkQAQSggfgEgfUwgfICAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQwYnRWF1lgy7Qxc4ZMTLwZR/ogmrYwBi3Wtke2
# tTG39eMO9DQ8KVeZ79grJq2QHue4AhUAvTH5GsYiVQazvP9bDTnU2Os/zaoYDzIw
# MjYwMTMwMTA0NTA1WqB2pHQwcjELMAkGA1UEBhMCR0IxFzAVBgNVBAgTDldlc3Qg
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
# MQ8XDTI2MDEzMDEwNDUwNVowPwYJKoZIhvcNAQkEMTIEMAHddeSKMqE2Th15GeUY
# iBDruDIeuge6VuOowGd5jM88LG2b9vpjRmv+8R7hH1a64TCCAXoGCyqGSIb3DQEJ
# EAIMMYIBaTCCAWUwggFhMBYEFDjJFIEQRLTcZj6T1HRLgUGGqbWxMIGHBBTGrlTk
# eIbxfD1VEkiMacNKevnC3TBvMFukWTBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMP
# U2VjdGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBUaW1lIFN0
# YW1waW5nIFJvb3QgUjQ2AhB6I67aU2mWD5HIPlz0x+M/MIG8BBSFPWMtk4KCYXzQ
# kDXEkd6SwULaxzCBozCBjqSBizCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5l
# dyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNF
# UlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNh
# dGlvbiBBdXRob3JpdHkCEDbCsL18Gzrno7PdNsvJdWgwDQYJKoZIhvcNAQEBBQAE
# ggIAJNPdyEXG0QHeNMXR9o1YdJlF/pd+gduXc9JrS7FE4Xr58N+gU/K8ExNGwnOw
# U+tH7Omn7ZomjRx/1LzCLrzVxhw79hG1zMgCbr8OBoZv22tssNiXCQsWoqO4orWB
# Y9tpC1iLcKcii4Rm6duMSOqH/+6R3nZGYNReaHo6t9gTbn25DU3i/2CTdCZiupaZ
# +zYwJy7IyYzV2YyjCW+z0PLcWroTgkGebfwVQCnuZn9Qt1EaoIqKNBLvVXyIrC8Z
# hPxCBwPK22URM1v9nDxadSrpXQdPJ9aD6w6qlwVxbB0NY+AKetFZl4HxvIHdwJSu
# 5ur4BAFdm7WYivT+CeeCsNpwij88eI4qtTvaKD1DuRGc+Ypduqi6PQmvOtVclxjA
# 0y6p++s5gPIWGtSyAUeaYaXoVsGsv1TbvBBP2Nx7mFchWU1NR4Nl6t8Z5Yj3oKKO
# hX3yunbf9fuj39T81HjBJfovxWjWIF3aYkHYBxhlXaoA9lsgSy6NoWinZA2mNiHk
# aod4fYrtWxakGP51fBZlKpED+74rxH4rTwa0juNEWtd/yHygTnAKi9+g+/lOs1BO
# N+kpLk6bZTXsmTqlZi4SLPcRj0g7NwG85jGxA4MpAtXR/scBqPjUWE0xytoxLwZr
# SQizmPHdzIEU1I9nP4Vro68KVNi/4TBJWiN26QW4unQdSjE=
# SIG # End signature block
