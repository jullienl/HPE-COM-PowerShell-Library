#------------------- FUNCTIONS FOR HPE GreenLake WORKSPACES -----------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1

# Public Functions
Function Get-HPEGLWorkspace {
    <#
    .SYNOPSIS
    Retrieve workspace resource(s) from HPE GreenLake.

    .DESCRIPTION
    This Cmdlet returns a collection of workspace resources available in HPE GreenLake. The "current" column indicates the workspace you are currently connected to.
    
    .PARAMETER Name
    Specifies the name of a workspace to retrieve.

    .PARAMETER ShowCurrent
    Retrieves details of the workspace you are currently connected to.
    
    .PARAMETER ShowActivationKey
    Fetches the activation key of the workspace you are presently connected to.
    The activation key is necessary for connecting iLOs to Compute Ops Management.

    .PARAMETER WhatIf 
    Displays the raw REST API call that would be executed, without actually sending the request. Useful for understanding the native REST API interactions with GLP.

    .EXAMPLE
    Get-HPEGLWorkspace

    Retrieves all workspaces available on the HPE GreenLake platform.

    .EXAMPLE
    Get-HPEGLWorkspace -ShowCurrent

    Retrieves general information about the current HPE GreenLake workspace.

    .EXAMPLE
    Get-HPEGLWorkspace -ShowActivationKey

    Retrieves the activation key for the current HPE GreenLake workspace, required for connecting iLOs to Compute Ops Management.
    #>

    
    [CmdletBinding(DefaultParameterSetName = "Default")]
    Param( 

        [Parameter (ParameterSetName = "Default")]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Parameter (ParameterSetName = "Current")]
        [Alias("Current")]
        [Switch]$ShowCurrent,

        [Parameter (ParameterSetName = "ActivationKey")]
        [Switch]$ShowActivationKey,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command
    
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $ReturnData = [System.Collections.ArrayList]::new()
        $AllCollection = [System.Collections.ArrayList]::new()
        
        $Uri = (Get-WorkspacesListUri) + "?count_per_page=50"
        
        # GET WORKSPACES (if any) [Does not include the currently connected workspace]

        try {

            if ($Global:HPEGreenLakeSession.workspaceId) {     

                [Array]$Collection = Invoke-HPEGLWebRequest -Method GET -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference      
            }
            else {
                # Skip parameter must be used to avoid error when Connect-HPEGLWorkspace has not been executed yet (i.e. when no workspace session exists yet).
                [Array]$Collection = Invoke-HPEGLWebRequest -Method GET -Uri $Uri -SkipSessionCheck -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
            }

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if ($Collection.customers) {
            $Collection = $Collection.customers
        }
        else {
            $Collection = @()
        }

        # Add current property to all workspaces (default False)
        $Collection | Add-Member -Type NoteProperty -Name "current" -Value $False -Force

        $AllCollection += $Collection
            
        "[{0}] Content of all workspaces from list-accounts: `n {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($AllCollection | Out-String) | Write-Verbose

        # FETCH AND ADD CURRENT WORKSPACE (if any and if not already in collection)
        
        if ($Global:HPEGreenLakeSession.workspace) {
        
            # Check if current workspace is already in the collection
            $CurrentWorkspaceInCollection = $AllCollection | Where-Object platform_customer_id -eq $Global:HPEGreenLakeSession.workspaceId
            
            if ($CurrentWorkspaceInCollection) {
                # Mark it as current
                $CurrentWorkspaceInCollection.current = $True
                "[{0}] Current workspace '{1}' found in collection, marked as current" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CurrentWorkspaceInCollection.company_name | Write-Verbose
            }
            else {
                # Current workspace not in list, fetch it separately using the contact API
                "[{0}] Current workspace not in list-accounts, fetching separately..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                
                $uri = Get-CurrentWorkspaceUri    # /accounts/ui/v1/customer/profile/contact
                
                try {
                    [Array]$CurrentWorkspaceDetails = Invoke-HPEGLWebRequest -Method GET -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                    
                    # Add platform_customer_id property
                    $CurrentWorkspaceDetails | Add-Member -Type NoteProperty -Name "platform_customer_id" -Value $Global:HPEGreenLakeSession.workspaceId -Force
                    
                    # Add account_type (MSP or STANDALONE) from $Global:HPEGLworkspaces
                    $_AccountType = $Global:HPEGLworkspaces | Where-Object platform_customer_id -eq $Global:HPEGreenLakeSession.workspaceId | ForEach-Object account_type
                    $CurrentWorkspaceDetails | Add-Member -Type NoteProperty -Name "account_type" -Value $_AccountType -Force
                    $CurrentWorkspaceDetails | Add-Member -Type NoteProperty -Name "current" -Value $True -Force
                                   
                    "[{0}] Content of current workspace: `n {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($CurrentWorkspaceDetails | Out-String) | Write-Verbose

                    $AllCollection += $CurrentWorkspaceDetails
                    
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }
            
            
            # Add name and version properties
            foreach ($_workspace in $AllCollection) {

                $_workspace | Add-Member -Type NoteProperty -Name "name" -Value $_workspace.company_name -Force

                ### Determine if the workspace is v1 or v2 (NOT WORKING - iam_v2_workspace is always returned empty by the API )
                # $_workspace | Add-Member -Type NoteProperty -Name "version" -Value $_.iam_v2_workspace -Force
            }

            "[{0}] Content of all workspaces: `n {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($AllCollection | Out-String) | Write-Verbose

            $CurrentWorkspace = $AllCollection | Where-Object platform_customer_id -eq $Global:HPEGreenLakeSession.workspaceId
        }

        if ($ShowActivationKey) {

            if ($Global:HPEGreenLakeSession.workspaceId) {
                return $Global:HPEGreenLakeSession.workspaceId
                
            }
            elseif ($Global:HPEGreenLakeSession.workspacesCount -eq 0) {

                "[{0}] Error: No workspace found! Please execute New-HPEGLWorkspace first to create the initial workspace." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                Write-Warning "Error: No workspace found! Please execute New-HPEGLWorkspace first to create the initial workspace."
                return
            }
            elseif ($Global:HPEGreenLakeSession.workspacesCount -ge 1) {
                
                "[{0}] Error: No workspace connection found! Please execute Connect-HPEGLWorkspace first to establish a connection to a workspace." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                Write-Warning "Error: No workspace connection found! Please execute Connect-HPEGLWorkspace first to establish a connection to a workspace."
                return
            }
            else {
        
                "[{0}] Error: No session found! Please execute Connect-HPEGL first to establish a session." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                Write-Warning "Error: No session found! Please execute Connect-HPEGL first to establish a session."
                return
            }


        }
        elseif ($ShowCurrent) {      

            $ReturnData = Invoke-RepackageObjectWithType -RawObject $CurrentWorkspace -ObjectName "Workspace"    
            return $ReturnData  
                    
        }
        else {

            if ($AllCollection.Count -gt 0) {

                "[{0}] Found {1} workspace(s)." -f $MyInvocation.InvocationName.ToString().ToUpper(), $AllCollection.Count | Write-Verbose

                if ($Name) {
    
                    $AllCollection = $AllCollection | Where-Object company_name -eq $Name
                }
       
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $AllCollection -ObjectName "Workspace"    
    
                $ReturnData = $ReturnData | Sort-Object { $_.company_name }
        
                return $ReturnData  
            }
            else {

                "[{0}] No workspaces found in the current environment." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                
                return            
            }
        } 
    }
}

Function Get-HPEGLTenantWorkspace {
    <#
    .SYNOPSIS
    Retrieve tenant workspace resource(s) from the currently connected workspace.

    .DESCRIPTION
    This Cmdlet returns a collection of tenant workspace resources available in the currently connected HPE GreenLake workspace. 
    The "current" column indicates the workspace you are currently connected to.
    
    .PARAMETER Name
    Specifies the name of the tenant workspace to retrieve.

    .PARAMETER ShowParent
    If specified, returns only the parent (management) workspace. Note: There is only one management workspace per organization.

    .PARAMETER WhatIf 
    Displays the raw REST API call that would be executed, without actually sending the request. Useful for understanding the native REST API interactions with GLP.

    .EXAMPLE
    Get-HPEGLTenantWorkspace

    Retrieves all tenant workspaces available on the HPE GreenLake platform.

    .EXAMPLE
    Get-HPEGLTenantWorkspace -Name "MyWorkspace"
    
    Retrieves details of the tenant workspace named "MyWorkspace".

    .EXAMPLE
    Get-HPEGLTenantWorkspace -ShowParent
    
    Retrieves only the parent (management) workspace. There is only one parent workspace per organization.

    #>

    
    [CmdletBinding(DefaultParameterSetName = "Default")]
    Param( 

        [Parameter (ParameterSetName = "Default")]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Parameter (ParameterSetName = "Default")]
        [Switch]$ShowParent,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command
    
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $ReturnData = [System.Collections.ArrayList]::new()
        
        $Uri = (Get-Workspacev2Uri) 
        
        try {

            [Array]$Collection = Invoke-HPEGLWebRequest -Method GET -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference      

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
                
        "[{0}] Content of all tenant workspaces" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Collection | Out-String) | Write-Verbose

        if ($Collection.Count -gt 0) {

            "[{0}] Found {1} workspace(s)." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Collection.Count | Write-Verbose

            # Get organizations to determine parent workspaces
            try {
                $Organizations = Get-HPEGLOrganization -ErrorAction SilentlyContinue
                "[{0}] Retrieved {1} organization(s) to determine parent workspaces" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Organizations.Count | Write-Verbose
            }
            catch {
                "[{0}] Could not retrieve organizations: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                $Organizations = @()
            }

            # Build hash tables for fast lookups
            # Hash table: workspace ID -> management workspace name (for member workspaces)
            $WorkspaceToParentHash = @{}
            
            # Hash table: management workspace ID -> $true (to identify management workspaces)
            $ManagementWorkspaceHash = @{}
            
            # Populate management workspace hash
            foreach ($Org in $Organizations) {
                $MgmtIdNormalized = $Org.associatedWorkspace.id -replace '-', ''
                $ManagementWorkspaceHash[$MgmtIdNormalized] = $true
            }
            
            # Get all organization workspaces once (if we have organizations)
            if ($Organizations.Count -gt 0) {
                try {
                    $OrgWorkspacesUri = (Get-Workspacev2Uri)
                    $OrgWorkspaces = (Invoke-HPEGLWebRequest -Method GET -Uri $OrgWorkspacesUri -ErrorAction SilentlyContinue -Verbose:$VerbosePreference)
                    "[{0}] Retrieved {1} organization workspace(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $OrgWorkspaces.Count | Write-Verbose
                    
                    # Build hash table of org workspace IDs for fast lookup
                    $OrgWorkspaceIdsHash = @{}
                    foreach ($ws in $OrgWorkspaces) {
                        $normalizedId = $ws.id -replace '-', ''
                        $OrgWorkspaceIdsHash[$normalizedId] = $true
                    }
                    
                    # For each organization, if its management workspace is in the org workspaces list,
                    # then all workspaces in that list are members with this management workspace as parent
                    foreach ($Org in $Organizations) {
                        $MgmtIdNormalized = $Org.associatedWorkspace.id -replace '-', ''
                        
                        if ($OrgWorkspaceIdsHash.ContainsKey($MgmtIdNormalized)) {
                            # This org is active, map all its workspaces to this parent
                            foreach ($ws in $OrgWorkspaces) {
                                $wsIdNormalized = $ws.id -replace '-', ''
                                if (-not $ManagementWorkspaceHash.ContainsKey($wsIdNormalized)) {
                                    # Only set parent for non-management workspaces
                                    $WorkspaceToParentHash[$wsIdNormalized] = $Org.associatedWorkspaceName
                                }
                            }
                            break  # Assuming a workspace can only belong to one org
                        }
                    }
                }
                catch {
                    "[{0}] Could not retrieve organization workspaces: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                }
            }

            # Add parent and isParent properties to each workspace using hash table lookups
            foreach ($Workspace in $Collection) {
                $WorkspaceIdNormalized = $Workspace.id -replace '-', ''
                
                if ($ManagementWorkspaceHash.ContainsKey($WorkspaceIdNormalized)) {
                    # This is a management workspace
                    $Workspace | Add-Member -Type NoteProperty -Name "parent" -Value $null -Force
                    $Workspace | Add-Member -Type NoteProperty -Name "isParent" -Value $true -Force
                }
                elseif ($WorkspaceToParentHash.ContainsKey($WorkspaceIdNormalized)) {
                    # This is a member workspace
                    $Workspace | Add-Member -Type NoteProperty -Name "parent" -Value $WorkspaceToParentHash[$WorkspaceIdNormalized] -Force
                    $Workspace | Add-Member -Type NoteProperty -Name "isParent" -Value $false -Force
                }
                else {
                    # Standalone workspace
                    $Workspace | Add-Member -Type NoteProperty -Name "parent" -Value $null -Force
                    $Workspace | Add-Member -Type NoteProperty -Name "isParent" -Value $false -Force
                }
            }

            if ($ShowParent) {

                $Collection = $Collection | Where-Object isParent -eq $true
            }

            if ($Name) {

                $Collection = $Collection | Where-Object workspaceName -eq $Name
            }

            $ReturnData = Invoke-RepackageObjectWithType -RawObject $Collection -ObjectName "Workspace.Tenant"

            $ReturnData = $ReturnData | Sort-Object { $_.workspaceName }
    
            return $ReturnData  
        }
        else {

            "[{0}] No tenant workspace found in the current environment." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            
            return            
        }
        
    }
}

Function New-HPEGLWorkspace {
    <#
    .SYNOPSIS
    Creates a workspace in HPE GreenLake.

    .DESCRIPTION
    This cmdlet creates a new workspace in HPE GreenLake. If this is the first workspace being created, the cmdlet will automatically terminate the current HPE GreenLake session and log out the user. 
    Workspaces are created as IAMv2 by default with enhanced identity and access management features and an option for organizational governance. 
    
    To create an IAMv1 workspace, use the -EnableIAMv1Workspace switch.

    When you log in to HPE GreenLake for the first time with an HPE account, you must create a workspace for your organization.

    .PARAMETER Name
    The name of the workspace. The name must be unique across all workspaces on the HPE GreenLake platform.

    .PARAMETER Type
    Specifies the workspace type to create. There are two types of workspace in HPE GreenLake:
        - Standard enterprise workspace: This is the standard workspace for teams wanting to use GreenLake services.
        - Managed service provider workspace: MSP workspaces are for service providers who manage their customers' services, devices, and subscriptions.

    .PARAMETER Street
    Specifies the postal street address of the workspace (optional).

    .PARAMETER Street2
    Specifies the secondary postal street address (Apt, suite, building, floor, etc.) of the workspace (optional).

    .PARAMETER Country
    Specifies the country of origin for the company.

    .PARAMETER City
    Specifies the city of the workspace (optional).

    .PARAMETER State
    Specifies the state of the workspace (optional).

    .PARAMETER PostalCode
    Specifies the postal code of the workspace (optional).

    .PARAMETER PhoneNumber
    Specifies the contact phone number of the workspace (optional).

    .PARAMETER Email
    Specifies the contact email address of the workspace (optional).

    .PARAMETER EnableIAMv1Workspace
    When enabled, creates the workspace using the legacy Identity and Access Management (IAM v1) experience instead of the default IAM v2.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    # This example demonstrates how to create a first workspace in an HPE GreenLake console.

    New-HPEGLWorkspace -Name "My_first_workspace_name" -Type "Managed Service Provider workspace" -Country "United States"
    Connect-HPEGL -Credential $credentials -Workspace "My_first_workspace_name"

    The first command creates a new 'Managed Service Provider' workspace named "My_first_workspace_name" in the United States. 
    If the cmdlet detects that this workspace is the first one created, it terminates the current HPE GreenLake session by logging out the user. 
    The next step is to reconnect using the `Connect-HPEGL` cmdlet with the credentials and the newly created workspace name.

    .EXAMPLE
    New-HPEGLWorkspace `
        -Name Velocity  `
        -Type 'Standard enterprise workspace' `
        -Email 'HenriPoincaré@Velocity.com' `
        -Street "Theory of dynamical systems street" `
        -Street2 "Cosmos building" `
        -City Paris `
        -PostalCode 75000 `
        -Country France `
        -PhoneNumber +33612345678 `
        -EnableIAMv2Workspace 

    Creates a new HPE GreenLake workspace named "Velocity" with the standard enterprise workspace type and the specified contact and address details.
    The workspace is created as an IAMv2 workspace, which provides enhanced identity and access management features and organizational governance.

    .INPUTS
    None. You cannot pipe objects to this Cmdlet.

    .OUTPUTS
    System.Collections.ArrayList
    A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - Name of the workspace object attempted to be created 
        * Status - Status of the creation attempt (Failed for HTTP error return; Complete if the creation is successful; Warning if no action is needed) 
        * Details - More information about the status         
        * Exception: Information about any exceptions generated during the operation.
    #>
    
    [CmdletBinding()]
    Param( 

        [Parameter (Mandatory)]
        [String]$Name,

        [Parameter (Mandatory)]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Standard enterprise workspace', 'Managed Service Provider workspace')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Standard enterprise workspace', 'Managed Service Provider workspace')]
        [String]$Type,
       
        [parameter (Mandatory)]
        [String]$Street,
        [String]$Street2,
        [String]$City,
        [String]$State,
        [String]$PostalCode,
        
        [Parameter (Mandatory)]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $countryNames = $Global:HPEGLSchemaMetadata.hpeCountryCodes.Name
                $countryNames | Where-Object { $_ -like "$wordToComplete*" } | Sort-Object
            })]
        [ValidateScript({
                $countryNames = $Global:HPEGLSchemaMetadata.hpeCountryCodes.Name
                if ($countryNames -contains $_) { 
                    $true 
                }
                else { 
                    Throw "Country '$_' is not valid. Supported countries are: $($countryNames -join ', ')."
                }
            })]
        [ValidateNotNullOrEmpty()]
        [String]$Country,

        [String]$PhoneNumber,

        [validatescript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$Email,     
        
        [switch]$EnableIAMv1Workspace,  

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
                
        $Uri = Get-NewWorkspaceUri

        $WorkspaceCreationStatus = [System.Collections.ArrayList]::new()
        
    }
    
    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        try {
            
            $WorkspaceFound = Get-HPEGLWorkspace

            $WorkspaceNameFound = $WorkspaceFound | Where-Object company_name -eq $Name

            
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

        if ($WorkspaceNameFound) {
            
            # Must return a message if Workspace found
            "[{0}] Workspace '{1}' found!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "Workspace '{0}': Resource already exists in HPE GreenLake! No action needed." -f $Name
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "This workspace already exists in HPE GreenLake! No action needed."
            }
            
        }
        else {

            $CountryCode = $Global:HPEGLSchemaMetadata.hpeCountryCodes | Where-Object name -eq $Country | ForEach-Object code           

            if ($Type -eq "Managed Service Provider workspace") {
                $WorkspaceType = "MSP"
            }
            elseif ($Type -eq "Standard enterprise workspace") {
                $WorkspaceType = "STANDALONE"
                
            }

            # Create payload  

            $Payload = [PSCustomObject]@{
                workspace_type   = $WorkspaceType
                company_name     = $Name
                created_by       = $Global:HPEGreenLakeSession.username
                email            = $Email
                phone_number     = $PhoneNumber
                iam_v2_workspace = if ($EnableIAMv1Workspace.IsPresent) { $false } else { $true }  # IAMv2 by default
                address          = @{
                    street_address   = $Street
                    street_address_2 = $Street2
                    city             = $City
                    state_or_region  = $State
                    zip              = $PostalCode
                    country_code     = $CountryCode
                }
            } | ConvertTo-Json -Depth 5


            # Create workspace

            try {
                            
                if ($Global:HPEGreenLakeSession.workspaceId) {
                    $Response = Invoke-HPEGLWebRequest -Uri $Uri -method 'POST' -body $Payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                    
                } 
                # If this is the first workspace beeing created, the workspace session check must be skipped with Invoke-HPEGLWebRequest
                else {
                    $Response = Invoke-HPEGLWebRequest -Uri $Uri -method 'POST' -body $Payload -SkipSessionCheck -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                }

                if (-not $WhatIf) {

                    "[{0}] Workspace '{1}' successfully created!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

                    # When the first workspace is created, it is necessary to run 'Connect-HPEGL -workspace <workspace_name>' to access the first new workspace.
                    if (-not $Global:HPEGreenLakeSession.workspaceId) {
                        $objStatus.Status = "Complete"
                        $objStatus.Details = "Workspace successfully created! Session disconnected, you must run `Connect-HPEGL -workspace <workspace_name>` to access the new workspace."
                        
                    }
                    else {
                        $objStatus.Status = "Complete"
                        $objStatus.Details = "Workspace successfully created!"
                    }

                }


            }
            catch {

                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Workspace cannot be created!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 

                }
            }
        }

        [void] $WorkspaceCreationStatus.add($objStatus)

    }

    End {

        if (-not $WhatIf) {

            # Must disconnect if this is the first workspace beeing created
            if (-not $WorkspaceFound) {
                Disconnect-HPEGL
            }
            else {
                $Global:HPEGreenLakeSession.workspacesCount++
            }

            $WorkspaceCreationStatus = Invoke-RepackageObjectWithType -RawObject $WorkspaceCreationStatus -ObjectName "ObjStatus.NSDE" 
            Return $WorkspaceCreationStatus
        }
    }
}

Function Set-HPEGLWorkspace {
    <#
    .SYNOPSIS
    Updates the current workspace details.

    .DESCRIPTION
    Updates general information about the HPE GreenLake workspace to which you are currently connected. If you omit any parameter, the cmdlet retains the current settings for those fields and only updates the provided parameters.

    .PARAMETER NewName 
    Specifies the new name of the workspace. The new name must be unique across all workspaces on the HPE GreenLake platform.

    .PARAMETER Street
    Specifies the postal street address of the workspace.

    .PARAMETER Street2
    Specifies the secondary postal street address (Apt, suite, building, floor, etc.) of the workspace.

    .PARAMETER Country
    Specifies the country of origin for the company.

    .PARAMETER City
    Specifies the city of the workspace.

    .PARAMETER State
    Specifies the state of the workspace.

    .PARAMETER PostalCode
    Specifies the postal code of the workspace.

    .PARAMETER PhoneNumber
    Specifies the contact phone number of the workspace.

    .PARAMETER Email
    Specifies the contact email address of the workspace. 

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Set-HPEGLWorkspace `
        -Street "Theory of Dynamical Systems Street" `
        -City Heaven `
        -PostalCode 77777 `
        -Country France `
        -PhoneNumber +33612345678

    Sets the street address, city, postal code, country, and phone number information of the currently connected HPE GreenLake workspace.

    .EXAMPLE
    Set-HPEGLWorkspace -State "" -Street2 ""

    Removes the state and the secondary address line details from the currently connected HPE GreenLake workspace while preserving all other existing settings.

    .INPUTS
    No pipeline input is supported.

    .OUTPUTS
    System.Collections.ArrayList
    A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - Name of the workspace object attempted to be updated.
        * Status - Status of the modification attempt (Failed for HTTP error return; Complete if the workspace update is successful).
        * Details - More information about the status.
        * Exception - Information about any exceptions generated during the operation.
    #>


    [CmdletBinding()]
    Param( 
        [ValidateNotNullOrEmpty()]
        [String]$NewName,

        [String]$Street,
        [String]$Street2,
        [String]$City,
        [String]$State,
        [String]$PostalCode,

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $countryNames = $Global:HPEGLSchemaMetadata.hpeCountryCodes.Name
                $countryNames | Where-Object { $_ -like "$wordToComplete*" } | Sort-Object
            })]
        [ValidateScript({
                $countryNames = $Global:HPEGLSchemaMetadata.hpeCountryCodes.Name
                if ($countryNames -contains $_) { 
                    $true 
                }
                else { 
                    Throw "Country '$_' is not valid. Supported countries are: $($countryNames -join ', ')."
                }
            })]
        [ValidateNotNullOrEmpty()]
        [String]$Country,

        [String]$PhoneNumber,

        [validatescript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$Email,    

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $SetWorkspaceStatus = [System.Collections.ArrayList]::new()
        
    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Check current workspace

        try {
            $WorkspaceDetails = Get-HPEGLWorkspace -ShowCurrent
           
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        $Uri = Get-CurrentWorkspaceUri

        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Name      = $WorkspaceDetails.company_name
            Status    = $Null
            Details   = $Null
            Exception = $Null
                  
        }

        # Conditionally add properties
        if ($NewName) {
            $Name = $NewName
        }
        else {
            $Name = $WorkspaceDetails.company_name
        }
       
        if (-not $PSBoundParameters.ContainsKey('Street')) {
	    
            if ($WorkspaceDetails.address.street_address) {
                          
                $Street = $WorkspaceDetails.address.street_address
            }
            else {
                $Street = $Null
            }
        }

        if (-not $PSBoundParameters.ContainsKey('Street2')) {
	    
            if ($WorkspaceDetails.address.street_address_2) {
                          
                $Street2 = $WorkspaceDetails.address.street_address_2

            }
            else {
                $Street2 = $Null
            }
        }

        if (-not $PSBoundParameters.ContainsKey('State')) {
	    
            if ($WorkspaceDetails.address.state_or_region) {
                          
                $State = $WorkspaceDetails.address.state_or_region

            }
            else {
                $State = $Null
            }
        }

        if (-not $PSBoundParameters.ContainsKey('PostalCode')) {
	    
            if ($WorkspaceDetails.address.zip) {
                          
                $PostalCode = $WorkspaceDetails.address.zip

            }
            else {
                $PostalCode = $Null
            }
        }

        if (-not $PSBoundParameters.ContainsKey('City')) {
	    
            if ($WorkspaceDetails.address.city) {
                          
                $City = $WorkspaceDetails.address.city

            }
            else {
                $City = $Null
            }
        }
 
        if (-not $PSBoundParameters.ContainsKey('Country')) {
	    
            if ($WorkspaceDetails.address.country_code) {
                          
                $CountryCode = $WorkspaceDetails.address.country_code

            }

        }
        else {
            $CountryCode = $Global:HPEGLSchemaMetadata.hpeCountryCodes | Where-Object name -eq $Country | ForEach-Object code
        }
        
        if (-not $PSBoundParameters.ContainsKey('PhoneNumber')) {
	    
            if ($WorkspaceDetails.phone_number) {
                          
                $PhoneNumber = $WorkspaceDetails.phone_number

            }
            else {
                $PhoneNumber = $Null
            }

        }

        if (-not $PSBoundParameters.ContainsKey('Email')) {
	    
            if ($WorkspaceDetails.email) {
                          
                $Email = $WorkspaceDetails.email

            }
            else {
                $Email = $Null
            }

        }

        $Payload = [PSCustomObject]@{
            company_name = $Name
            email        = $Email
            phone_number = $PhoneNumber
            address      = @{
                street_address   = $Street
                street_address_2 = $Street2
                city             = $City
                state_or_region  = $State
                zip              = $PostalCode
                country_code     = $CountryCode
            }
        } | ConvertTo-Json -Depth 5


        # Current workspace modification
        try {
        
            $Response = Invoke-HPEGLWebRequest -Method 'PUT' -Body $Payload -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                         
            if (-not $WhatIf) {
                $objStatus.Status = "Complete"
                $objStatus.Details = ($Response | ForEach-Object message)
            }

        }
        catch {

            if (-not $WhatIf) {
                $objStatus.Status = "Failed"
                $objStatus.Details = ($Response | ForEach-Object message)
                $objStatus.Exception = $Global:HPECOMInvokeReturnData 
            }
        }    

        [void] $SetWorkspaceStatus.add($objStatus)
        

    }

    end {

        if (-not $WhatIf) {

            $SetWorkspaceStatus = Invoke-RepackageObjectWithType -RawObject $SetWorkspaceStatus -ObjectName "ObjStatus.NSDE" 
            Return $SetWorkspaceStatus
        }


    }
}

Function Remove-HPEGLWorkspace {
    <#
    .SYNOPSIS
    Deletes the currently connected workspace from HPE GreenLake.

    .DESCRIPTION
    This cmdlet permanently deletes the currently connected workspace from HPE GreenLake. You must be connected to a workspace before attempting deletion.
    
    IMPORTANT: This action will permanently and irrevocably delete all data associated with the workspace from HPE GreenLake and will automatically 
    terminate all active sessions within the workspace, including yours.

    WARNING: If this is the last workspace in an organization, the organization itself will also be deleted when this operation is carried out.

    The cmdlet prompts for confirmation before proceeding with the deletion unless the -Force parameter is specified. This safeguard helps prevent 
    accidental data loss.

    PREREQUISITES: You cannot delete a workspace if there are subscriptions, devices, or services associated with it. Ensure that all such resources are removed or reassigned before attempting to delete the workspace.
    
    COMPATIBILITY: Only IAM v2 workspaces are supported for deletion. Attempting to delete an IAM v1 workspace will result in an error.
    
    POST-DELETION: After successful workspace deletion, you will be disconnected from HPE GreenLake. To access another workspace, run 
    'Connect-HPEGL -workspace <workspace_name>'.
    
    .PARAMETER Force
    Bypasses the confirmation prompt and immediately proceeds with workspace deletion. Use this parameter with extreme caution, as the deletion 
    is permanent and cannot be undone.

    .PARAMETER NotifyAllWorkspaceUsersByEmail
    Sends an email notification to all users associated with the workspace informing them about its deletion.

    .PARAMETER WhatIf
    Displays the raw REST API call that would be executed without actually performing the deletion. This is useful for understanding the underlying 
    API interaction with HPE GreenLake platform.

    .EXAMPLE
    Remove-HPEGLWorkspace

    Deletes the currently connected workspace after prompting for confirmation.

    .EXAMPLE
    Remove-HPEGLWorkspace -Force -NotifyAllWorkspaceUsersByEmail
    
    Immediately deletes the currently connected workspace without confirmation and sends email notifications to all associated users.

    .EXAMPLE
    Remove-HPEGLWorkspace -WhatIf
    
    Shows what would happen if the workspace were deleted, including the REST API call, without actually performing the deletion.

    .INPUTS
    None. This cmdlet does not accept pipeline input.

    .OUTPUTS
    System.Collections.ArrayList
    A custom status object containing the following properties:
        * Name - The name of the workspace that was attempted to be deleted
        * Status - The outcome of the deletion attempt:
          - "Complete" if deletion was successful
          - "Failed" if deletion failed (see Exception for details)
          - "Warning" if the operation was cancelled by the user
        * Details - Additional information about the operation result
        * Exception - Error details if the operation failed

    #>

    [CmdletBinding()]
    Param(

        [Switch]$Force,

        [Switch]$NotifyAllWorkspaceUsersByEmail,

        [Switch]$WhatIf
    )

    Begin {
        $Caller = (Get-PSCallStack)[1].Command
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
        $DeleteStatus = [System.Collections.ArrayList]::new()
    }

    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $WorkspaceId = $Global:HPEGreenLakeSession.workspaceId

        $objStatus = [pscustomobject]@{
            Name      = $Global:HPEGreenLakeSession.workspace
            Status    = $null
            Details   = $null
            Exception = $null
        }

        if (-not $WorkspaceId) {

            if ($WhatIf) {
                $ErrorMessage = "No workspace connection found! Make sure you are connected to a workspace before attempting to delete it." 
                Write-warning $ErrorMessage
                return
            }
            else {                
                $objStatus.Status = "Failed"
                $objStatus.Details = "No workspace connection found! Make sure you are connected to a workspace before attempting to delete it."
                [void]$DeleteStatus.Add($objStatus)
                return
            }
        }

        # Check if this workspace is part of an organization and if it's the last workspace
        $isLastWorkspaceInOrg = $false
        $organizationName = $null
        
        if ($Global:HPEGreenLakeSession.organizationId) {
            "[{0}] Workspace is part of organization. Checking if this is the last workspace..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            
            try {
                # Get all workspaces in the organization
                $allWorkspaces = Get-HPEGLTenantWorkspace -Verbose:$false
                
                if ($allWorkspaces.Count -eq 1) {
                    $isLastWorkspaceInOrg = $true
                    $organizationName = $Global:HPEGreenLakeSession.organization
                    "[{0}] This is the LAST workspace in organization '{1}'. Organization will also be deleted!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $organizationName | Write-Verbose
                }
                else {
                    "[{0}] Organization has {1} workspace(s). Organization will remain after this workspace is deleted." -f $MyInvocation.InvocationName.ToString().ToUpper(), $allWorkspaces.Count | Write-Verbose
                }
            }
            catch {
                "[{0}] Could not determine if this is the last workspace in the organization. Proceeding with deletion anyway." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            }
        }

        $uriBase = (Get-Workspacev2Uri) + "/$($WorkspaceId)"
        if ($NotifyAllWorkspaceUsersByEmail) {
            $Uri = "$($uriBase)?send-email=true"
        }
        else {
            $Uri = $uriBase
        }

        $shouldDelete = $Force
        if (-not $Force) {
            # Build the warning message
            $warningMessage = "This action will permanently and irrecoverably delete all data associated with workspace '{0}' from HPE GreenLake and will automatically terminate your and all other sessions within the workspace." -f $Global:HPEGreenLakeSession.workspace
            
            if ($isLastWorkspaceInOrg) {
                $warningMessage += "`n`nWARNING: This is the LAST workspace in organization '{0}'. The organization itself will also be DELETED when this operation is carried out!" -f $organizationName
            }
            
            $title = $warningMessage
            $question = "`nThis action is irreversible and cannot be canceled or undone once the process has begun. Are you sure you want to proceed?"
            
            $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Confirm deletion of the workspace and all associated data. This action is permanent and cannot be undone."
            $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Cancel the deletion operation. The workspace will remain intact."
            $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
            
            $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
            $shouldDelete = ($decision -eq 0)
        }

        if ($shouldDelete) {
            try {
                $Response = Invoke-HPEGLWebRequest -Method DELETE -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                if (-not $WhatIf) {
                    "[{0}] Workspace '{1}' was successfully deleted." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Global:HPEGreenLakeSession.workspace | Write-Verbose
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Workspace deleted successfully. You have been disconnected. To access another workspace, please run 'Connect-HPEGL -workspace <workspace_name>'."
                    # Remove session only after successful deletion
                    Remove-Variable -Name HPEGreenLakeSession -Scope Global -Force -ErrorAction SilentlyContinue
                }
            }
            catch {
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    if ($_.Exception.Message -match "500") {
                        $objStatus.Details = "Workspace cannot be deleted. Only IAM v2 workspaces are supported for deletion."
                    }
                    else {
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Workspace could not be deleted." }
                    }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData
                }
            }
        }
        else {
            "[{0}] User cancelled the deletion of the workspace '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Global:HPEGreenLakeSession.workspace | Write-Verbose
            if ($WhatIf) {
                Write-warning "Operation cancelled by the user!"
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "Operation cancelled by the user! Workspace not deleted!"
            }
        }

        [void]$DeleteStatus.Add($objStatus)
    }

    End {
        if (-not $WhatIf) {
            $DeleteStatus = Invoke-RepackageObjectWithType -RawObject $DeleteStatus -ObjectName "ObjStatus.NSDE"
            return $DeleteStatus
        }
    }
}

Function Get-HPEGLDomain {
    <#
    .SYNOPSIS
    Retrieves information about domains.

    .DESCRIPTION
    This function retrieves detailed information about domains or a specified domain within the HPE GreenLake workspace.

    .PARAMETER DomainName
    Specifies the name of the domain to retrieve information for.

    .PARAMETER WhatIf
    Displays the raw REST API call that would be executed, without actually sending the request. Useful for understanding the native REST API interactions with GLP.

    .EXAMPLE
    Get-HPEGLDomain 

    Retrieves information about all domains in the workspace.
   
    .EXAMPLE
    Get-HPEGLDomain -DomainName "example.com"

    Retrieves information about the domain "example.com".

    #>

    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Switch]$WhatIf
    )

    Begin {

        $Caller = (Get-PSCallStack)[1].Command
    
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $ReturnData = [System.Collections.ArrayList]::new()
        
        $Uri = (Get-DomainUri) 
        
        try {

            [Array]$Collection = Invoke-HPEGLWebRequest -Method GET -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference      

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
                
        "[{0}] Content of all domains" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Collection | Out-String) | Write-Verbose

        if ($Collection.Count -gt 0) {

            "[{0}] Found {1} domain(s)." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Collection.Count | Write-Verbose

            if ($Name) {

                $Collection = $Collection | Where-Object Name -eq $Name
            }

            $ReturnData = Invoke-RepackageObjectWithType -RawObject $Collection -ObjectName "Workspace.Domain"

            $ReturnData = $ReturnData | Sort-Object { $_.Name }
    
            return $ReturnData  
        }
        else {

            "[{0}] No domain found in the current environment." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

            return            
        }
        
    }
}

Function New-HPEGLDomain {
    <#
    .SYNOPSIS
    Adds a domain to the workspace.

    .DESCRIPTION
    This cmdlet adds a domain to your HPE GreenLake workspace by claiming it for your organization.

    Claiming a domain enables your organization to manage and control access for all users associated with that domain.

    Once a domain is claimed, you can configure Single Sign-On (SSO) and/or integrate external SCIM identity management for the domain, providing centralized authentication and user provisioning.

    Note: A domain can only be claimed by one organization in the GreenLake platform. Domains already claimed by another organization cannot be added.

    .PARAMETER Name
    Specifies the name of the domain to add. This domain must be unique within the GreenLake platform and cannot be claimed by another organization.

    Note: Public domains (e.g., gmail.com, outlook.com, yahoo.com, etc.) cannot be claimed.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    New-HPEGLDomain -Name "example.com"
    Adds the domain "example.com" to the HPE GreenLake workspace. You will need to verify ownership of the domain via DNS before it is fully claimed.
    Add verification record

    The domain is placed in a verification pending state and verification will be attempted periodically.
    1- Sign into your domain host’s website and navigate to the DNS records section.
    2- Copy the TXT record form the DnsTxtRecord property output into the DNS page of the domain provider for google.hpelabs.us.
    3- Once the TXT record is added, wait for the DNS provider to propagate the change. This may take up to 72 hours.
    4- When the domain claim has been verified, it will be shown as such and can then be configured for SSO.

    .INPUTS
    None. You cannot pipe objects to this Cmdlet.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following keys:
        * Name - The name of the domain attempted to be added.
        * DnsTxtRecord - The DNS TXT record that needs to be added for domain verification.
        * Status - The status of the domain creation attempt (Failed for HTTP error return; Complete if the domain was successfully added; Warning if no action is needed).
        * Details - More information about the status.
        * Exception - Information about any exceptions generated during the operation.
#>

    [CmdletBinding()]
    Param( 

        [Parameter (Mandatory)]
        [String]$Name,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $AddDomainStatus = [System.Collections.ArrayList]::new()

    }
    
    Process {        
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
 
        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name         = $Name
            Status       = $Null
            DNSTxtRecord = $Null
            Details      = $Null
            Exception    = $Null                          
        }    

        # Check if domain already exists
        try {
            $DomainId = (Get-HPEGLDomain -Name $Name).id
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        if ($DomainId) {

            # Must return a message if domain is already present
            "[{0}] Domain '{1}' is already claimed in the workspace." -f $MyInvocation.InvocationName.ToString().ToUpper(), $name | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "Domain '{0}' is already claimed in the workspace." -f $name
                Write-warning $ErrorMessage
                return
            }
            else {                
                $objStatus.Status = "Warning"
                $objStatus.Details = "Domain is already claimed in the workspace." 

            }
        }
        else {
            "[{0}] Adding domain '{1}' to the workspace..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
        
            # Add domain name
            $Payload = @{
                name = $Name
            } | ConvertTo-Json -Depth 5

            try {
                $NewDomain = Invoke-HPEGLWebRequest -Uri (Get-DomainUri) -method 'Post' -ContentType application/json -Body $Payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                    
                if ($Global:HPECOMInvokeReturnData.StatusCode -eq 201) {

                    if (-not $WhatIf) {

                        $objStatus.Status = "Complete"
                        $objStatus.Details = "Domain claim initiated for '{0}'. Verify ownership by adding the DNS TXT record shown in the 'DnsTxtRecord' property. The domain will be fully claimed once verification completes (may take up to 72 hours for DNS propagation)." -f $Name
                        $objStatus.dnsTxtRecord = $NewDomain.dnsTxtRecord

                        "[{0}] Domain '{1}' successfully added to the workspace." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                    }
                }    
            }
            catch {    

                if ($Global:HPECOMInvokeReturnData.StatusCode -eq 409) {

                    "[{0}] Domain '{1}' is already claimed by another organization." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

                    if ($WhatIf) {
                        $ErrorMessage = "Domain '{0}' is already claimed by another organization." -f $Name
                        Write-warning $ErrorMessage
                        return
                    }
                    else {
                        $objStatus.Status = "Warning"
                        $objStatus.Details = "Domain is already claimed by another organization."
                    }
                }
                else {

                    if (-not $WhatIf) {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Domain cannot be added!" }
                        $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                    }
                }
        
            }
        }

        [void] $AddDomainStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            $AddDomainStatus = Invoke-RepackageObjectWithType -RawObject $AddDomainStatus -ObjectName "ObjStatus.NSDDE" 
            Return $AddDomainStatus
        }
    }
}

Function Test-HPEGLDomain {
    <#
    .SYNOPSIS
    Verifies domain ownership by checking for the presence of the required DNS TXT record in your DNS configuration.

    .DESCRIPTION
    This cmdlet tests if a domain has been verified in the HPE GreenLake workspace by checking for the presence of the required DNS TXT record in your DNS configuration.

    .PARAMETER Name
    Specifies the name of the domain to test.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Test-HPEGLDomain -Name "example.com"
    
    Tests the domain "example.com" in the HPE GreenLake workspace for verification.
    
    .EXAMPLE
    Get-HPEGLDomain | Test-HPEGLDomain

    Tests all domains in the HPE GreenLake workspace for verification.

    .INPUTS
    System.String
        The name of the domain to test. Can be piped from Get-HPEGLDomain.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following keys:
        * Name - The name of the domain attempted to be tested.
        * Status - The status of the verification attempt (Pending if verification is pending; Complete if verification is successful; Failed if verification fails).
        * Details - More information about the status.
        * Exception - Information about any exceptions generated during the operation.

    #>

    [CmdletBinding()]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $TestDomainStatus = [System.Collections.ArrayList]::new()
    }

    Process {       
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name      = $Name
            Status    = $Null
            Details   = $Null
            Exception = $Null                          
        }    

        # Check if domain already exists
        try {
            $DomainId = (Get-HPEGLDomain -Name $Name).id
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        if (-not $DomainId) {

            # Must return a message if domain cannot be found
            "[{0}] Domain '{1}' cannot be found in the workspace." -f $MyInvocation.InvocationName.ToString().ToUpper(), $name | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "Domain '{0}' cannot be found in the workspace." -f $name
                Write-warning $ErrorMessage
                return
            }
            else {                
                $objStatus.Status = "Failed"
                $objStatus.Details = "cannot be found in the workspace." 
                [void] $AddDomainStatus.add($objStatus)
                return
            }
        }
        
        "[{0}] Verifying domain '{1}' in the workspace..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

        $Uri = (Get-DomainUri) + "/" + $DomainId + "/verify?share-contact=false"
        
        try {
            $Response = Invoke-HPEGLWebRequest -Uri $Uri -method 'POST' -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

            if ($Response.lifeCycleState -eq "PENDING") {
                
                "[{0}] Domain '{1}' verification is still pending." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                $objStatus.Status = "Pending"
                $objStatus.Details = "Domain verification is still pending. Please verify that the DNS TXT record has been correctly added to your DNS provider and allow sufficient time (up to 72 hours) for DNS propagation to complete."
            }
            elseif ($Response.lifeCycleState -eq "VERIFIED") {
                "[{0}] Domain '{1}' has been successfully verified in the workspace." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                $objStatus.Status = "Complete"
                $objStatus.Details = "Domain has been successfully verified in the workspace."
            }
            else {
                "[{0}] Domain '{1}' verification failed." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                $objStatus.Status = "Failed"
                $objStatus.Details = "Domain verification failed. Current state: {0}" -f $Response.lifeCycleState
            }
        }
        catch {    
            if (-not $WhatIf) {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Domain cannot be verified!" }
                $objStatus.Exception = $Global:HPECOMInvokeReturnData
            }
        }

        [void] $TestDomainStatus.add($objStatus)

    }
    end {

        if (-not $WhatIf) {

            $TestDomainStatus = Invoke-RepackageObjectWithType -RawObject $TestDomainStatus -ObjectName "ObjStatus.NSDE" 
            Return $TestDomainStatus

        }
    }
}

Function Remove-HPEGLDomain {
    <#
    .SYNOPSIS
    Removes a domain from the workspace.

    .DESCRIPTION
    This cmdlet removes a domain from your HPE GreenLake workspace.

    .PARAMETER Name
    Specifies the name of the domain to remove.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Remove-HPEGLDomain -Name "example.com"

    Removes the domain "example.com" from the HPE GreenLake workspace.

    .EXAMPLE
    Get-HPEGLDomain | Remove-HPEGLDomain

    Removes all domains from the HPE GreenLake workspace.

    .INPUTS
    System.String
        The name of the domain to remove. Can be piped from Get-HPEGLDomain.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following keys:
        * Name - The name of the domain attempted to be removed.
        * Status - The status of the removal attempt (Failed for HTTP error return and if domain is not found; Complete if removal is successful).
        * Details - More information about the status.
        * Exception - Information about any exceptions generated during the operation.
    #>

    [CmdletBinding()]
    Param( 

        [Parameter (Mandatory, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
        $DeleteStatus = [System.Collections.ArrayList]::new()

    }
    
    Process {       
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        try {
            $Domain = Get-HPEGLDomain -Name $Name
            $DomainRequestId = $Domain.id
            $DomainState = $Domain.lifeCycleState
            
            # For VERIFIED domains, we need to get the actual domain ID from /domains endpoint
            if ($DomainState -eq "VERIFIED") {
                "[{0}] Domain is VERIFIED, retrieving actual domain ID from /domains endpoint..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                $DomainsUri = (Get-DomainDeleteUri)
                $VerifiedDomains = Invoke-HPEGLWebRequest -Method GET -Uri $DomainsUri -Verbose:$VerbosePreference
                $DomainId = ($VerifiedDomains | Where-Object { $_.name -eq $Name }).id
                
                if (-not $DomainId) {
                    throw "Unable to find domain ID for VERIFIED domain '$Name' in /domains endpoint"
                }
                "[{0}] Found domain ID: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DomainId | Write-Verbose
            }
            else {
                # For PENDING domains, use the domain-request ID
                $DomainId = $DomainRequestId
            }
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        $objStatus = [pscustomobject]@{
            Name      = $Name
            Status    = $null
            Details   = $null
            Exception = $null
        }

        if (-not $DomainId) {

            # Must return a message if domain is not found
            "[{0}] Domain '{1}' not available!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "Domain '{0}' not found in the workspace!" -f $name
                Write-warning $ErrorMessage
                return
            }
            else {                
                $objStatus.Status = "Failed"
                $objStatus.Details = "Domain not found in the workspace!"
            }
        }
        else {
            "[{0}] Removing domain '{1}' (state: {2}) from the workspace..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $DomainState | Write-Verbose
       
            # Use different endpoint based on domain state
            # PENDING domains: DELETE /domain-requests/{domain-request-id}
            # VERIFIED domains: DELETE /domains/{domain-id}
            if ($DomainState -eq "PENDING") {
                $Uri = (Get-DomainUri) + "/" + $DomainId
            }
            else {
                # VERIFIED domain - use the domain ID from /domains endpoint
                $Uri = (Get-DomainDeleteUri) + "/" + $DomainId
            }
    
            try {
                $Response = Invoke-HPEGLWebRequest -Uri $Uri -method 'DELETE' -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
    
                if ($Global:HPECOMInvokeReturnData.StatusCode -eq 204) {
                    if (-not $WhatIf) {
                        "[{0}] Domain '{1}' successfully removed from the workspace." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                        $objStatus.Status = "Complete"
                        $objStatus.Details = "Domain successfully removed from the workspace."
                    }
                }
            }
            catch {
                "[{0}] Error occurred while removing domain '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $_.Exception.Message | Write-Verbose

                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Domain cannot be removed!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData
                }
            }
        }

        [void] $DeleteStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            $DeleteStatus = Invoke-RepackageObjectWithType -RawObject $DeleteStatus -ObjectName "ObjStatus.NSDE" 
            Return $DeleteStatus

        }
    }
}

Function Get-HPEGLSSOConnection {
    <#
    .SYNOPSIS
    Retrieves information about SSO connections.

    .DESCRIPTION
    This function retrieves detailed information about SSO connections within the HPE GreenLake workspace. 
    For SAML-based (Security Assertion Markup Language) SSO connections, additional details such as SAML IdP configuration, attributes, and certificates can be retrieved. 
    For OIDC-based (OpenID Connect) SSO connections, the OIDC configuration can be retrieved.

    .PARAMETER Name
    Specifies the name of the SSO connection to retrieve information for.

    .PARAMETER ShowSAMLAttributes
    If specified, returns the SAML attribute mappings for the specified SAML SSO connection. Only applicable to SAML-based connections.

    .PARAMETER ShowSAMLIdPConfiguration
    If specified, returns the SAML Identity Provider (IdP) configuration for the specified SAML SSO connection. Only applicable to SAML-based connections.

    .PARAMETER ShowSAMLIdPCertificate
    If specified, returns the Identity Provider (IdP) X509 certificate for the specified SAML SSO connection. Only applicable to SAML-based connections.

    .PARAMETER ShowSAMLSPConfiguration
    If specified, returns the SAML Service Provider (i.e., HPE GreenLake) configuration for SAML SSO connections. Only applicable to SAML-based connections.
    This parameter is optional and is used to retrieve the Service Provider (SP) configuration details needed to configure HPE GreenLake in your identity provider for SSO integration.

    .PARAMETER ShowSAMLSPCertificate
    If specified, returns the Service Provider (SP, i.e., HPE GreenLake) X509 certificate for the domain associated with the specified SSO connection. Only applicable to SAML-based connections.

    .PARAMETER DownloadServiceProviderMetadata
    If specified, downloads the SAML SSO metadata file of the Service Provider (SP, i.e., HPE GreenLake) to the specified file path. This metadata is used by Identity Providers (IdPs) to establish trust and facilitate Single Sign-On (SSO) interactions. Only applicable to SAML-based connections.

    .PARAMETER ShowOIDCConfiguration
    If specified, returns the OIDC Identity Provider (IdP) configuration for the specified OIDC SSO connection. Only applicable to OIDC-based connections.

    .PARAMETER WhatIf
    Displays the raw REST API call that would be executed, without actually sending the request. Useful for understanding the native REST API interactions with GLP.

    .EXAMPLE
    Get-HPEGLSSOConnection 

    Retrieves information about all SSO connections in the workspace.

    .EXAMPLE
    Get-HPEGLSSOConnection -Name "example.com"

    Retrieves information about the SSO connection "example.com".

    .EXAMPLE
    Get-HPEGLSSOConnection -Name "example.com" -ShowSAMLAttributes

    Retrieves the SAML attribute mappings for the SAML SSO connection "example.com".

    .EXAMPLE
    Get-HPEGLSSOConnection -Name "example.com" -ShowSAMLIdPConfiguration

    Returns the SAML IdP configuration for the SAML SSO connection "example.com".

    .EXAMPLE
    Get-HPEGLSSOConnection -Name "example.com" -ShowSAMLIdPCertificate

    Returns the Identity Provider (IdP) X509 certificate for the SAML SSO connection "example.com".

    .EXAMPLE
    Get-HPEGLSSOConnection -ShowSAMLSPConfiguration

    Returns the SAML Service Provider (i.e., HPE GreenLake) configuration details for SAML SSO connections. Use this information to configure HPE GreenLake as an application in your identity provider.

    .EXAMPLE
    Get-HPEGLSSOConnection -Name "example.com" -ShowSAMLSPCertificate

    Returns the Service Provider (SP, i.e., HPE GreenLake) X509 certificate for the domain associated with the SSO connection "example.com".

    .EXAMPLE
    Get-HPEGLSSOConnection -Name "example.com" -DownloadServiceProviderMetadata "C:\path\to\metadata.xml"

    Downloads the Service Provider metadata file for the domain associated with the SSO connection "example.com" to the specified file path.

    .EXAMPLE
    Get-HPEGLSSOConnection -Name "example.com" -ShowOIDCConfiguration

    Returns the OIDC IdP configuration for the OIDC SSO connection "example.com".

    #>

    [CmdletBinding(DefaultParameterSetName = "Default")]
    Param(
        [Parameter(ParameterSetName = "Default")]
        [Parameter(Mandatory, ParameterSetName = "NameSAMLAttributes")]
        [Parameter(Mandatory, ParameterSetName = "NameSAMLIdPConfiguration")]
        [Parameter(Mandatory, ParameterSetName = "NameIDP")]
        [Parameter(Mandatory, ParameterSetName = "NameOIDCConfiguration")]
        [Parameter(Mandatory, ParameterSetName = "NameSAMLSPCertificate")]
        [Parameter(Mandatory, ParameterSetName = "NameMetadataDownload")]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Parameter(ParameterSetName = "NameSAMLAttributes")]
        [switch]$ShowSAMLAttributes,

        [Parameter(ParameterSetName = "NameSAMLIdPConfiguration")]
        [switch]$ShowSAMLIdPConfiguration,

        [Parameter(ParameterSetName = "NameIDP")]
        [switch]$ShowSAMLIdPCertificate,

        [Parameter(ParameterSetName = "NameSAMLSPConfiguration")]
        [switch]$ShowSAMLSPConfiguration,

        [Parameter(ParameterSetName = "NameSAMLSPCertificate")]
        [switch]$ShowSAMLSPCertificate,

        [Parameter(Mandatory, ParameterSetName = "NameMetadataDownload")]
        [String]$DownloadServiceProviderMetadata,

        [Parameter(ParameterSetName = "NameOIDCConfiguration")]
        [switch]$ShowOIDCConfiguration,

        [Switch]$WhatIf
    )

    Begin {

        $Caller = (Get-PSCallStack)[1].Command
    
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $ReturnData = [System.Collections.ArrayList]::new()
        
        $Uri = (Get-SSOConnectionUri) 
        
        try {

            [Array]$Collection = Invoke-HPEGLWebRequest -Method GET -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference      

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
                
        "[{0}] Content of all SSO connections" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Collection | Out-String) | Write-Verbose

        if ($Collection.Count -gt 0) {

            "[{0}] Found {1} SSO connection(s)." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Collection.Count | Write-Verbose

            if ($Name) {

                $Collection = $Collection | Where-Object Name -eq $Name

                # Check if specific details are requested
                if ($ShowSAMLIdPCertificate) {

                    if ($Collection.samlIdpConfig) {
                        "[{0}] Retrieving Identity Provider (IdP) certificate for SSO connection '{1}'." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                        $certBase64 = $Collection | Select-Object -ExpandProperty samlIdpConfig | Select-Object -ExpandProperty Certificate
    
                        if ($certBase64) {
                            
                            $pemCert = "-----BEGIN CERTIFICATE-----`n"
                            $pemCert += ($certBase64 -split '(.{64})' | Where-Object { $_ }) -join "`r`n"
                            $pemCert += "`n-----END CERTIFICATE-----"
                            return $pemCert
                        }
                    }                     
                    else {
                        Write-Warning "Identity Provider (IdP) certificate not found for SSO connection '$Name'. The connection may not be SAML-based."
                        return
                    }
                }
                elseif ($ShowSAMLAttributes) {
                    
                    $SAMLAttributes = $Collection | Select-Object -ExpandProperty attributeMapping

                    if ($SAMLAttributes.Count -gt 1) {
                    
                        $FilteredSAMLAttributes = @()

                        Foreach ($SAMLAttribute in $SAMLAttributes) {
                            
                            if ($SAMLAttribute.name -eq "Email") {
                                # Add description member to the SAML attribute
                                $SAMLAttribute | Add-Member -MemberType NoteProperty -Name "description" -Value "Email address" -Force
                                $FilteredSAMLAttributes += $SAMLAttribute
                            }
                            if ($SAMLAttribute.name -eq "LastName") {
                                $SAMLAttribute | Add-Member -MemberType NoteProperty -Name "description" -Value "Last name" -Force
                                $FilteredSAMLAttributes += $SAMLAttribute
                            }
                            if ($SAMLAttribute.name -eq "FirstName") {
                                $SAMLAttribute | Add-Member -MemberType NoteProperty -Name "description" -Value "First name" -Force
                                $FilteredSAMLAttributes += $SAMLAttribute
                            }
                            if ($SAMLAttribute.name -eq "HPECCSAttribute") {
                                $SAMLAttribute | Add-Member -MemberType NoteProperty -Name "description" -Value "HPE GreenLake authorization attribute" -Force
                                $FilteredSAMLAttributes += $SAMLAttribute
                            }
                        }
                        
                        $ReturnData = Invoke-RepackageObjectWithType -RawObject $FilteredSAMLAttributes -ObjectName "Workspace.SSOConnection.AttributeMapping"    
                        return $ReturnData
                    
                    }
                    else {
                        Write-Warning "No SAML attributes found for SSO connection '$Name'. The connection may not be SAML-based."
                        return
                    }              
                }
                elseif ($ShowSAMLIdPConfiguration) {

                    # Retrieve the SAML IdP configuration details
                    if ($Collection.samlIdpConfig) {
                        $SAMLIdpConfiguration = $Collection | Select-Object -ExpandProperty samlIdpConfig
                        $ReturnData = Invoke-RepackageObjectWithType -RawObject $SAMLIdpConfiguration -ObjectName "Workspace.SSOConnection.SAMLIdpConfig"
                        return $ReturnData
                    }
                    else {
                        Write-Warning "SAML IdP configuration not found for SSO connection '$Name'. The connection may not be SAML-based."
                        return
                    }


                }
                elseif ($ShowOIDCConfiguration) {

                    # Retrieve the OIDC IdP configuration details
                    if ($Collection.oidcIdpConfig) {
                        $OIDCIdpConfiguration = $Collection | Select-Object -ExpandProperty oidcIdpConfig
                        $ReturnData = Invoke-RepackageObjectWithType -RawObject $OIDCIdpConfiguration -ObjectName "Workspace.SSOConnection.OIDCIdpConfig"
                        return $ReturnData
                    }
                    else {
                        Write-Warning "OIDC IdP configuration not found for SSO connection '$Name'. The connection may not be OIDC-based."
                        return
                    }


                }
                elseif ($DownloadServiceProviderMetadata -or $ShowSAMLSPCertificate) {

                    # Get the domain name associated with this SSO connection
                    # The domain name is linked via the authentication policy name
                    $Domains = Get-HPEGLDomain
                    $AuthPolicies = Get-HPEGLSSOAuthenticationPolicy
                    
                    "[{0}] SSO Connection ID: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Collection.id | Write-Verbose
                    
                    # Find the authentication policy for this SSO connection
                    $AuthPolicy = $AuthPolicies | Where-Object { $_.action.authsource -eq $Collection.id }
                    $AuthPolicyName = $AuthPolicy.name
                    
                    "[{0}] Authentication policy name: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $AuthPolicyName | Write-Verbose
                    
                    # Match domain name with authentication policy name
                    $MatchedDomain = $Domains | Where-Object { $_.name -eq $AuthPolicyName }
                    $DomainName = $MatchedDomain.name

                    if (-not $DomainName) {
                        Write-Warning "No domain found associated with SSO connection '$Name' (Authentication policy: '$AuthPolicyName'). Cannot retrieve Service Provider metadata."
                        return
                    }

                    "[{0}] Domain name found for SSO connection '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $DomainName | Write-Verbose

                    $Uri = (Get-AuthnSAMLSSOMetadataUri) + $DomainName

                    try {
                        [string]$MetadataURL = (Invoke-HPEGLWebRequest -Method GET -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference).metadata_url
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }
        
                    if ($MetadataURL) {
    
                        [xml]$MetadataFile = Invoke-WebRequest -Method GET -Uri $MetadataURL
        
                        if ($ShowSAMLSPCertificate) {
                            $certBase64 = $MetadataFile.EntityDescriptor.SPSSODescriptor.KeyDescriptor.KeyInfo.X509Data.X509Certificate
                            $pemCert = "-----BEGIN CERTIFICATE-----`n"
                            $pemCert += ($certBase64 -split '(.{64})' | Where-Object { $_ }) -join "`r`n"
                            $pemCert += "`n-----END CERTIFICATE-----"
                            return $pemCert
                        }
                        elseif ($DownloadServiceProviderMetadata) {
                            $MetadataFile.Save($DownloadServiceProviderMetadata)
                            Write-Output "Metadata file '$DownloadServiceProviderMetadata' successfully downloaded." 
                        }
                        else {
                            return $MetadataFile
                        }
                    }
                    else {
                        return
                    }

                }                
                else {
                    # Retrieve all SSO connections without SAML-specific details
                    $AuthPolicies = Get-HPEGLSSOAuthenticationPolicy

                    # Add authenticationPolicy object to the authenticationPolicy property
                    foreach ( $SSOConnection in $Collection ) {

                        $AuthPolicy = $AuthPolicies | Where-Object { $_.action.authsource -eq $SSOConnection.id }
                        "[{0}] SSO Connection auth policy: {1} " -f $MyInvocation.InvocationName.ToString().ToUpper(), $AuthPolicy.name | Write-Verbose
                    
                        $IdleSessionTimeout = ($SSOConnection.attributeMapping | Where-Object { $_.name -eq "IdleSessionTimeout" }).expression
                        "[{0}] IdleSessionTimeout found: {1} " -f $MyInvocation.InvocationName.ToString().ToUpper(), $IdleSessionTimeout | Write-Verbose

                        if ( $AuthPolicy ) {
                            $SSOConnection | Add-Member -MemberType NoteProperty -Name authenticationPolicy -Value $AuthPolicy.name -Force
                        }
                    
                        if ( $IdleSessionTimeout ) {
                            $SSOConnection | Add-Member -MemberType NoteProperty -Name idleSessionTimeout -Value $IdleSessionTimeout -Force
                        }
                    }

                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $Collection -ObjectName "Workspace.SSOConnection"

                    $ReturnData = $ReturnData | Sort-Object { $_.Name }
        
                    return $ReturnData
                }
            }
            elseif ($ShowSAMLSPConfiguration) {
                # Build the SAML SP configuration details
                # Entity ID: https://sso.common.cloud.hpe.com
                # ACS URL: https://sso.common.cloud.hpe.com/sp/ACS.saml2
                # Default Relay State: https://common.cloud.hpe.com

                $SAMLSpConfiguration = [pscustomobject]@{
                    entityId          = "https://sso.common.cloud.hpe.com"
                    acsUrl            = "https://sso.common.cloud.hpe.com/sp/ACS.saml2"
                    defaultRelayState = "https://common.cloud.hpe.com"
                }
                    
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $SAMLSpConfiguration -ObjectName "Workspace.SSOConnection.SAMLSpConfig"
                return $ReturnData
            }
            else {
                # Retrieve all SSO connections without SAML-specific details
                $AuthPolicies = Get-HPEGLSSOAuthenticationPolicy

                # Add authenticationPolicy object to the authenticationPolicy property
                foreach ( $SSOConnection in $Collection ) {

                    $AuthPolicy = $AuthPolicies | Where-Object { $_.action.authsource -eq $SSOConnection.id }
                    "[{0}] SSO Connection auth policy: {1} " -f $MyInvocation.InvocationName.ToString().ToUpper(), $AuthPolicy.name | Write-Verbose
                    
                    $IdleSessionTimeout = ($SSOConnection.attributeMapping | Where-Object { $_.name -eq "IdleSessionTimeout" }).expression
                    "[{0}] IdleSessionTimeout found: {1} " -f $MyInvocation.InvocationName.ToString().ToUpper(), $IdleSessionTimeout | Write-Verbose

                    if ( $AuthPolicy ) {
                        $SSOConnection | Add-Member -MemberType NoteProperty -Name authenticationPolicy -Value $AuthPolicy.name -Force
                    }
                    
                    if ( $IdleSessionTimeout ) {
                        $SSOConnection | Add-Member -MemberType NoteProperty -Name idleSessionTimeout -Value $IdleSessionTimeout -Force
                    }
                }

                $ReturnData = Invoke-RepackageObjectWithType -RawObject $Collection -ObjectName "Workspace.SSOConnection"

                $ReturnData = $ReturnData | Sort-Object { $_.Name }
        
                return $ReturnData
            }
        }
        else {

            "[{0}] No SSO connection found in the current environment." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

            return            
        }
        
    }
}

Function New-HPEGLSSOConnection {
    <#
    .SYNOPSIS
    Adds an SSO connection to the workspace.

    .DESCRIPTION
    This cmdlet creates an SSO connection in your HPE GreenLake workspace. An SSO connection defines how users authenticate to HPE GreenLake using an external Identity Provider (IdP).

    SSO connections support two protocols:
    - SAML 2.0: Security Assertion Markup Language for federated authentication
    - OIDC: OpenID Connect for modern authentication flows

    The IdP metadata can be provided as either a URL or a local XML file. For SAML connections, the metadata must contain the IdP's Entity ID, login URL, logout URL, and signing certificate. For OIDC connections, the metadata must include the issuer, authorization endpoint, token endpoint, JWKS endpoint, and user info endpoint.

    .PARAMETER Name
    Specifies the name of the SSO connection to create. The name must be unique within the workspace.

    .PARAMETER SAML20
    Creates a SAML 2.0 SSO connection. Use this for Identity Providers that support SAML-based authentication.

    .PARAMETER OIDC
    Creates an OIDC (OpenID Connect) SSO connection. Use this for Identity Providers that support modern OAuth 2.0/OIDC authentication flows.

    .PARAMETER OIDClientId
    For OIDC connections only. Specifies the client ID provided by your Identity Provider when registering HPE GreenLake as an application.

    .PARAMETER OIDClientSecret
    For OIDC connections only. Specifies the client secret as a SecureString provided by your Identity Provider when registering HPE GreenLake as an application.

    .PARAMETER EmailAttribute
    For SAML connections only. Specifies the SAML attribute name that contains the user's email address. Default is "NameId".

    .PARAMETER FirstNameAttribute
    For SAML connections only. Specifies the SAML attribute name that contains the user's first name. Default is "FirstName".

    .PARAMETER LastNameAttribute
    For SAML connections only. Specifies the SAML attribute name that contains the user's last name. Default is "LastName".

    .PARAMETER GreenLakeAttribute
    For SAML connections only. Specifies the SAML attribute name that contains HPE GreenLake authorization information (roles and permissions). Default is "hpe_ccs_attribute". This attribute is required when using SAML for authorization (AuthorizationMode).

    .PARAMETER IdleSessionTimeout
    Specifies the idle session timeout in minutes. Users will be logged out after this period of inactivity. Valid range is 1-1440 minutes (24 hours). Default is 60 minutes.

    .PARAMETER MetadataSource
    Specifies the source of the IdP metadata. This can be either:
    - A URL pointing to the IdP's metadata endpoint (e.g., https://idp.example.com/metadata)
    - A file path to a local XML metadata file (e.g., C:\metadata\idp-metadata.xml)

    .PARAMETER RecoveryAccountSecurePassword
    Specifies the recovery account password as a SecureString. The password must be at least 8 characters long and include upper-case, lower-case, number, and symbol characters.
    
    The recovery account provides a fallback authentication method when SSO is unavailable or fails. It is strongly recommended when configuring SSO for the first time or making significant changes to SSO configuration.
    
    Once SSO is successfully configured and verified, you may delete the recovery account if desired. However, retaining it is recommended as a safeguard against SSO disruptions caused by:
    - External IdP configuration changes
    - Certificate expiration
    - Network connectivity issues
    - Misconfiguration during SSO updates
    
    The recovery account username is auto-generated in the format: <random-string>@recovery.auth.greenlake.hpe.com
    Save this username and password for emergency access if SSO authentication fails.

    .PARAMETER RecoveryAccountContactEmail
    Specifies the contact email address for password recovery of the recovery account. This email will be used to reset the recovery account password if forgotten.
    
    It is recommended to use a distribution list or team alias rather than an individual's email to ensure continuity of access regardless of personnel changes.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    # SAML 2.0 SSO Connection with metadata URL
    $password = ConvertTo-SecureString "MySecurePass123!" -AsPlainText -Force
    New-HPEGLSSOConnection -Name "PingID SSO" -SAML20 -MetadataSource "https://idp.example.com/federationmetadata/2007-06/federationmetadata.xml" -RecoveryAccountSecurePassword $password -RecoveryAccountContactEmail "it-admin@example.com"

    Creates a SAML 2.0 SSO connection named "PingID SSO" using IdP metadata from a URL, with a recovery account for emergency access.

    .EXAMPLE
    # SAML 2.0 SSO Connection with local metadata file
    $password = ConvertTo-SecureString "MySecurePass123!" -AsPlainText -Force
    New-HPEGLSSOConnection -Name "Okta SSO" -SAML20 -MetadataSource "C:\IdP\metadata.xml" -EmailAttribute "email" -FirstNameAttribute "givenName" -LastNameAttribute "sn" -IdleSessionTimeout 120 -RecoveryAccountSecurePassword $password -RecoveryAccountContactEmail "it-team@example.com"

    Creates a SAML 2.0 SSO connection with custom SAML attribute mappings and a 2-hour idle timeout, using a local metadata file.

    .EXAMPLE
    # OIDC SSO Connection
    $password = ConvertTo-SecureString "MySecurePass123!" -AsPlainText -Force
    $clientSecret = ConvertTo-SecureString "client-secret-from-idp" -AsPlainText -Force

    New-HPEGLSSOConnection -Name "EntraID OIDC SSO" -OIDC -IdleSessionTimeout 500 -OIDClientId "b64a82cs-3492-5rdy-9573-aeb1d32329a" `
     -MetadataSource "https://idp.example.com/.well-known/openid-configuration" -OIDClientSecret $clientSecret `
     -RecoveryAccountSecurePassword $password -RecoveryAccountContactEmail "security@example.com"

    Creates an OIDC SSO connection using the IdP's OIDC discovery endpoint with a recovery account.

    .EXAMPLE
    # SAML SSO Connection without recovery account
    New-HPEGLSSOConnection -Name "company-saml" -SAML20 -MetadataSource "https://idp.example.com/metadata"

    Creates a SAML 2.0 SSO connection without a recovery account. Note: This is not recommended for production use as it provides no fallback authentication method.

    .INPUTS
    None. You cannot pipe objects to this cmdlet.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following keys:
        * Name - The name of the SSO connection attempted to be created.
        * RecoveryUserEmail - The auto-generated recovery account email (if recovery account was created).
        * Status - The status of the creation attempt:
          - "Complete" if the SSO connection was successfully created
          - "Failed" if the creation failed (see Exception for details)
          - "Warning" if no action was needed (e.g., connection already exists)
        * Details - Additional information about the operation status.
        * Exception - Information about any exceptions or errors encountered during the operation.
    #>

    [CmdletBinding(DefaultParameterSetName = "SAML20")]
    Param( 

        [Parameter (Mandatory)]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Parameter (Mandatory, ParameterSetName = "SAML20")]
        [switch]$SAML20,

        [Parameter (Mandatory, ParameterSetName = "OIDC")]
        [switch]$OIDC,

        [Parameter (ParameterSetName = "OIDC")]
        [String]$OIDClientId,

        [Parameter (ParameterSetName = "OIDC")]
        [SecureString]$OIDClientSecret,

        [Parameter (ParameterSetName = "SAML20")]
        [String]$EmailAttribute = "NameId", 
        
        [Parameter (ParameterSetName = "SAML20")]
        [String]$FirstNameAttribute = "FirstName",
        
        [Parameter (ParameterSetName = "SAML20")]
        [String]$LastNameAttribute = "LastName",

        [Parameter (ParameterSetName = "SAML20")]
        [String]$GreenLakeAttribute = "hpe_ccs_attribute",

        [ValidateScript({
                if ($_ -le 1440) {
                    $true
                }
                else {
                    throw "Idle time cannot exceed 1,440 minutes (24 hours)."
                }
            })]
        [Int]$IdleSessionTimeout = 60,

        [Parameter (Mandatory, ValueFromPipeline)]
        [String]$MetadataSource,

        [SecureString]$RecoveryAccountSecurePassword,

        [validatescript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$RecoveryAccountContactEmail,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-SSOConnectionUri

        $AddSSOConnectionStatus = [System.Collections.ArrayList]::new()

        # Check that if RecoveryAccountSecurePassword is provided, then RecoveryAccountContactEmail is also provided
        if ($PSBoundParameters.ContainsKey('RecoveryAccountSecurePassword') -and -not $PSBoundParameters.ContainsKey('RecoveryAccountContactEmail')) {
            Throw "If 'RecoveryAccountSecurePassword' is provided, then 'RecoveryAccountContactEmail' must also be provided."
        }
        # and the opposite
        if ($PSBoundParameters.ContainsKey('RecoveryAccountContactEmail') -and -not $PSBoundParameters.ContainsKey('RecoveryAccountSecurePassword')) {
            Throw "If 'RecoveryAccountContactEmail' is provided, then 'RecoveryAccountSecurePassword' must also be provided."
        }

    }
    
    Process {        
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name      = $Name
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

        # Only add RecoveryUserEmail if RecoveryAccountSecurePassword is provided
        if ($RecoveryAccountSecurePassword) {
            $objStatus | Add-Member -MemberType NoteProperty -Name "RecoveryUserEmail" -Value $Null
        }
        
        if ($OIDC) {
            "[{0}] Adding OIDC SSO connection '{1}' to the workspace..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose            
        }
        else {
            "[{0}] Adding SAML 2.0 SSO connection '{1}' to the workspace..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
        }
        
        # Validate MetadataSource (URL or file)

        $FileFound = $false

        # Check if the MetadataSource is a URL
        if ($MetadataSource -match '^https?://') {

            "[{0}] MetadataSource detected as a URL" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

            # Validate IdP metadata
            try {
                
                $Uri = (Get-IdPValidateMetadataUrlUri) 

                if ($OIDC) {
                    "[{0}] Validating OIDC IdP Metadata URL: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $MetadataSource | Write-Verbose
                    $Payload = @{ 
                        url      = $MetadataSource 
                        protocol = "OIDC"
                    } | ConvertTo-Json -Depth 5
                }
                else {
                    "[{0}] Validating SAML IdP Metadata URL: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $MetadataSource | Write-Verbose
                    $Payload = @{ 
                        url      = $MetadataSource 
                        protocol = "SAML"
                    } | ConvertTo-Json -Depth 5
                }

                $MetadataRequestResponse = Invoke-HPEGLWebRequest -Uri $Uri -method 'Post' -ContentType application/json -Body $Payload                

                "[{0}] IdP Metadata URL validation successful! Response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($MetadataRequestResponse | ConvertTo-Json -Depth 5) | Write-Verbose
            
                $MetadataData = $MetadataRequestResponse

                $FileFound = $true

            }
            catch {    

                if ($Global:HPECOMInvokeReturnData.StatusCode -eq 400) {
                    # Must return a message if url cannot be validated
                    "[{0}] Call to the IdP Metadata URL failed!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
    
                    if ($WhatIf) {
                        $ErrorMessage = "The IdP Metadata URL cannot be validated! Please check the URL."
                        Write-warning $ErrorMessage
                        return
                    }
                    else {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "The IdP Metadata URL cannot be validated! Please check the URL." }
                        $objStatus.Exception = $Global:HPECOMInvokeReturnData.message
                    }
                }
                else {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }
        }
        else {

            "[{0}] MetadataSource detected as a file" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

            # Test the path of the XML file 
            $FileFound = Test-Path -Path $MetadataSource

            if ($FileFound) {

                "[{0}] MetadataSource file has been found!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                $Uri = (Get-IdPValidateMetadataFileUri)

                # Create multipart form-data payload for metadata file upload
                $metadataFile = Get-Item -Path $MetadataSource
                $boundary = "----geckoformboundary$([guid]::NewGuid().ToString('N'))"
                $fileName = $metadataFile.Name
                $fileContent = [System.IO.File]::ReadAllText($metadataFile.FullName)
            
                # Build multipart form-data body matching browser format exactly
                $bodyLines = @()
                $bodyLines += "--$boundary"
                $bodyLines += 'Content-Disposition: form-data; name="metadata_file"; filename="{0}"' -f $fileName
                $bodyLines += 'Content-Type: text/xml'
                $bodyLines += ''
                $bodyLines += $fileContent
                $bodyLines += "--$boundary--"
                $bodyLines += ''
            
                $Payload = $bodyLines -join "`r`n"
                $ContentType = "multipart/form-data; boundary=$boundary"
            
                "[{0}] Metadata validation URI: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri | Write-Verbose
                "[{0}] Payload size: {1} bytes" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Payload.Length | Write-Verbose
                "[{0}] Boundary: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $boundary | Write-Verbose
            
                # Use API access token (v1_2 preferred, fallback to v1_1) - matching Invoke-HPEGLWebRequest logic
                if ($Global:HPEGreenLakeSession.glpApiAccessTokenv1_2.access_token) {
                    $glpApiAccessToken = $Global:HPEGreenLakeSession.glpApiAccessTokenv1_2.access_token
                } 
                elseif ($Global:HPEGreenLakeSession.glpApiAccessToken.access_token) {
                    $glpApiAccessToken = $Global:HPEGreenLakeSession.glpApiAccessToken.access_token
                }
                else {
                    Throw "Error - No API Access Token found in `$Global:HPEGreenLakeSession! 'Connect-HPEGL' must be executed first!"
                }
            
                # Build headers with API token (same pattern as Invoke-HPEGLWebRequest for non-UI endpoints)
                $headers = @{} 
                $headers["Accept"] = "application/json"
                $headers["Content-Type"] = $ContentType
                $headers["Authorization"] = "Bearer $($glpApiAccessToken)"
            
                try {
                    $MetadataRequestResponse = Invoke-WebRequest -Uri $Uri -Method POST -Headers $headers -Body $Payload
                
                    "[{0}] Metadata validation successful!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                
                    # Store response in global variable for consistency
                    $Global:HPECOMInvokeReturnData = $MetadataRequestResponse

                    # Parse the JSON response from Invoke-WebRequest
                    $MetadataData = $MetadataRequestResponse.Content | ConvertFrom-Json
                }
                catch {
                    "[{0}] Failed to validate metadata file!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                
                    # Parse error response from Invoke-WebRequest exception
                    $errorResponse = $null
                    $statusCode = $null
                
                    if ($_.Exception.Response) {
                        $statusCode = [int]$_.Exception.Response.StatusCode
                    
                        # PowerShell 7+ uses different response object
                        $errorBody = $_.ErrorDetails.Message
                    
                        if ($errorBody) {
                            try {
                                $errorResponse = $errorBody | ConvertFrom-Json
                                # Store in global variable for consistency with other cmdlets
                                $Global:HPECOMInvokeReturnData = $errorResponse
                            }
                            catch {
                                $errorResponse = @{ message = $errorBody }
                                $Global:HPECOMInvokeReturnData = $errorResponse
                            }
                        }
                    }
                
                    if ($statusCode -eq 400) {
                        # Must return a message if metadata file cannot be validated
                        "[{0}] Metadata file validation failed!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                        if ($WhatIf) {
                            $ErrorMessage = "Metadata file validation failed! Message: {0}" -f $errorResponse.message
                            Write-warning $ErrorMessage
                            return
                        }
                        else {
                            $objStatus.Status = "Failed"
                            $objStatus.Details = "Metadata file validation failed!"
                            $objStatus.Exception = $errorResponse
                        }
                    }
                    else {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }
                }
            }
            else {

                "[{0}] MetadataSource file not found!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                # Must return a message if Metadata file is not found
                if ($WhatIf) {
                    $ErrorMessage = "Metadata XML file cannot be found at '{0}'" -f $MetadataSource
                    Write-warning $ErrorMessage
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Metadata file cannot be found at $MetadataSource"

                }       
            }
        }

        if ($FileFound) {   

            "[{0}] Metadata file request response: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $MetadataData | Write-Verbose

            if ($OIDC) {
                
                "[{0}] Capturing OIDC IdP configuration from metadata..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                # Capture the IdP data from the metadata response 
                $Issuer = $MetadataData.issuer
                $JwksEndpoint = $MetadataData.jwksEndpoint
                $AuthorizationEndpoint = $MetadataData.authorizationEndpoint
                $TokenEndpoint = $MetadataData.tokenEndpoint
                $UserInfoEndpoint = $MetadataData.userInfoEndpoint


                # Create payload for OIDC metadata 

                $OidcIDPConfig = [PSCustomObject]@{
                    authorizationEndpoint = $AuthorizationEndpoint
                    clientId              = $OIDClientId
                    clientSecret          = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($OIDClientSecret))
                    issuer                = $Issuer
                    jwksEndpoint          = $JwksEndpoint
                    tokenEndpoint         = $TokenEndpoint
                    usePkce               = $true
                    userInfoEndpoint      = $UserInfoEndpoint
                }

                $AttributeMapping = @(
                    [PSCustomObject]@{
                        name       = "IdleSessionTimeout"
                        expression = [string]$IdleSessionTimeout
                    }
                )
            }
            else {
                
                "[{0}] Capturing SAML IdP configuration from metadata..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                # Capture the IdP data from the metadata response 
                $EntityID = $MetadataData.entityID
                $LoginURL = $MetadataData.loginUrl
                $LogoutURL = $MetadataData.logoutUrl
                $SigningCertificate = $MetadataData.certificate

                # Create payload for SAML metadata 

                $SamlIDPConfig = [PSCustomObject]@{
                    entityId    = $EntityID
                    loginUrl    = $LoginURL
                    logoutUrl   = $LogoutURL
                    certificate = $SigningCertificate
                }

                $AttributeMapping = @(
                    [PSCustomObject]@{
                        name       = "Email"
                        expression = $EmailAttribute
                    },
                    [PSCustomObject]@{
                        name       = "FirstName"
                        expression = $FirstNameAttribute
                    },
                    [PSCustomObject]@{
                        name       = "LastName"
                        expression = $LastNameAttribute
                    },
                    [PSCustomObject]@{
                        name       = "IdleSessionTimeout"
                        expression = [string]$IdleSessionTimeout
                    }
                    [PSCustomObject]@{
                        name       = "HPECCSAttribute"
                        expression = $GreenLakeAttribute
                    }
                )
            }

            # Build the final payload   

            "[{0}] Building SSO connection payload..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

            if ($RecoveryAccountSecurePassword) {
                
                # Auto-generate recovery username in format flg8xkzm0jkx66i85sxst0jwmzhzdu6z@recovery.auth.greenlake.hpe.com
                $RandomString = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object { [char]$_ })
                $RecoveryUsername = "{0}@recovery.auth.greenlake.hpe.com" -f $RandomString
                "[{0}] Generated recovery username: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RecoveryUsername | Write-Verbose

                # Save recovery username to output object
                $objStatus.RecoveryUserEmail = $RecoveryUsername

                # Convert SecureString to plain text for API submission
                $RecoveryPasswordPlainText = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($RecoveryAccountSecurePassword))

                If ($OIDC) {
                    "[{0}] Building OIDC SSO connection payload with recovery user..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    
                    $Payload = @{
                        name             = $Name
                        oidcIdpConfig    = $OidcIDPConfig
                        attributeMapping = $AttributeMapping
                        recoveryUser     = @{
                            password      = $RecoveryPasswordPlainText
                            recoveryEmail = $RecoveryAccountContactEmail
                            username      = $RecoveryUsername
                        }
    
                    } | ConvertTo-Json -Depth 5
                }
                else {
                    "[{0}] Building SAML 2.0 SSO connection payload with recovery user..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    
                    $Payload = @{
                        name             = $Name
                        samlIdpConfig    = $SamlIDPConfig
                        attributeMapping = $AttributeMapping
                        recoveryUser     = @{
                            password      = $RecoveryPasswordPlainText
                            recoveryEmail = $RecoveryAccountContactEmail
                            username      = $RecoveryUsername
                        }
    
                    } | ConvertTo-Json -Depth 5
                }
                
            }
            else {

                if ($OIDC) {
                    "[{0}] Building OIDC SSO connection payload without recovery user..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                    $Payload = @{
                        name             = $Name
                        oidcIdpConfig    = $OidcIDPConfig
                        attributeMapping = $AttributeMapping
                    } | ConvertTo-Json -Depth 5
                }
                else {
                    "[{0}] Building SAML 2.0 SSO connection payload without recovery user..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                    $Payload = @{
                        name             = $Name
                        samlIdpConfig    = $SamlIDPConfig
                        attributeMapping = $AttributeMapping
                    } | ConvertTo-Json -Depth 5
                }                
            }

            # Create masked payload for verbose logging (mask sensitive data)
            if ($RecoveryAccountSecurePassword -or $OIDC) {
                $PayloadForLogging = $Payload
                # Mask recovery password if present
                $PayloadForLogging = $PayloadForLogging -replace '"password":\s*"[^"]*"', '"password": "********"'
                # Mask OIDC client secret if present
                $PayloadForLogging = $PayloadForLogging -replace '"clientSecret":\s*"[^"]*"', '"clientSecret": "********"'
                "[{0}] SSO connection payload (sensitive data masked): {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $PayloadForLogging | Write-Verbose
            }
            else {
                "[{0}] SSO connection payload: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Payload | Write-Verbose
            }

            $Uri = Get-SSOConnectionUri 

            try {

                # For WhatIf, we need to show the masked payload, not the real one
                if ($WhatIf) {
                    # Use masked payload for WhatIf display
                    $PayloadForWhatIf = $Payload
                    if ($RecoveryAccountSecurePassword -or $OIDC) {
                        # Mask recovery password if present
                        $PayloadForWhatIf = $PayloadForWhatIf -replace '"password":\s*"[^"]*"', '"password": "********"'
                        # Mask OIDC client secret if present
                        $PayloadForWhatIf = $PayloadForWhatIf -replace '"clientSecret":\s*"[^"]*"', '"clientSecret": "********"'
                    }
                    $Response = Invoke-HPEGLWebRequest -Method 'POST' -Body $PayloadForWhatIf -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                }
                else {
                    # Use real payload for actual API call
                    # Don't pass VerbosePreference to suppress detailed output with sensitive data
                    $Response = Invoke-HPEGLWebRequest -Method 'POST' -Body $Payload -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$false
                }

                if ($Global:HPECOMInvokeReturnData.StatusCode -in @(200, 201)) {

                    if (-not $WhatIf) {
                        "[{0}] SSO connection '{1}' successfully added to the workspace." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                        $objStatus.Status = "Complete"
                        $objStatus.Details = "SSO connection successfully added to the workspace."
                        
                        # Log recovery username if it was created (property already set earlier during payload building)
                        if ($RecoveryAccountSecurePassword) {
                            "[{0}] Recovery username: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RecoveryUsername | Write-Verbose
                        }
                    }
                }
            }
            catch {

                if ($Global:HPECOMInvokeReturnData.StatusCode -eq 409) {

                    "[{0}] SSO connection '{1}' with the same Entity ID already exists in this or another organization." -f $MyInvocation.InvocationName.ToString().ToUpper(), $EntityID | Write-Verbose
                    if ($WhatIf) {
                        $ErrorMessage = "SSO connection '{0}' with the same Entity ID already exists in this or another organization." -f $Name
                        Write-warning $ErrorMessage
                        return
                    }
                    else {
                        $objStatus.Status = "Warning"
                        $objStatus.Details = "SSO connection with the same Entity ID already exists in this or another organization."
                    }
                }
                else {
                    "[{0}] SSO connection '{1}' failed to add." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                    if (-not $WhatIf) {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "SSO connection cannot be added!" }
                        $objStatus.Exception = $Global:HPECOMInvokeReturnData
                    }
                }
        
            }
        }

        [void] $AddSSOConnectionStatus.add($objStatus)
    
    }

    end {

        if (-not $WhatIf) {

            if ($RecoveryAccountSecurePassword) {
                $AddSSOConnectionStatus = Invoke-RepackageObjectWithType -RawObject $AddSSOConnectionStatus -ObjectName "ObjStatus.NRSDE" 
            }
            else {
                $AddSSOConnectionStatus = Invoke-RepackageObjectWithType -RawObject $AddSSOConnectionStatus -ObjectName "ObjStatus.NSDE"
            }
            Return $AddSSOConnectionStatus
        }
    }
}

Function Set-HPEGLSSOConnection {
    <#
    .SYNOPSIS
    Updates an existing SSO connection in the workspace.

    .DESCRIPTION
    This cmdlet updates an existing SSO connection in your HPE GreenLake workspace. You can update the IdP metadata (URL or file), modify SAML attribute mappings, change the idle session timeout, or update OIDC client credentials.

    For SAML connections, you can update the IdP certificate, endpoints, and attribute mappings.
    For OIDC connections, you can update the metadata endpoint and client credentials.

    .PARAMETER Name
    Specifies the name of the SSO connection to update.

    .PARAMETER NewName
    Specifies the new name for the SSO connection. Use this parameter to rename the connection.

    .PARAMETER MetadataSource
    Specifies the new source of the IdP metadata. This can be either:
    - A URL pointing to the IdP's metadata endpoint (e.g., https://idp.example.com/metadata)
    - A file path to a local XML metadata file (e.g., C:\metadata\idp-metadata.xml)

    .PARAMETER OIDClientId
    For OIDC connections only. Specifies the new client ID provided by your Identity Provider.

    .PARAMETER OIDClientSecret
    For OIDC connections only. Specifies the new client secret as a SecureString provided by your Identity Provider.

    .PARAMETER EmailAttribute
    For SAML connections only. Specifies the new SAML attribute name that contains the user's email address.

    .PARAMETER FirstNameAttribute
    For SAML connections only. Specifies the new SAML attribute name that contains the user's first name.

    .PARAMETER LastNameAttribute
    For SAML connections only. Specifies the new SAML attribute name that contains the user's last name.

    .PARAMETER GreenLakeAttribute
    For SAML connections only. Specifies the new SAML attribute name that contains HPE GreenLake authorization information (roles and permissions).

    .PARAMETER IdleSessionTimeout
    Specifies the new idle session timeout in minutes. Users will be logged out after this period of inactivity. Valid range is 1-1440 minutes (24 hours).

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Set-HPEGLSSOConnection -Name "company-saml" -NewName "company-saml-prod"

    Renames the SSO connection from "company-saml" to "company-saml-prod".

    .EXAMPLE
    Set-HPEGLSSOConnection -Name "company-saml" -IdleSessionTimeout 120

    Updates the idle session timeout to 120 minutes for the SSO connection "company-saml".

    .EXAMPLE
    Set-HPEGLSSOConnection -Name "company-saml" -MetadataSource "https://idp.example.com/metadata"

    Updates the IdP metadata for the SSO connection "company-saml" using a new metadata URL.

    .EXAMPLE
    Set-HPEGLSSOConnection -Name "company-saml" -EmailAttribute "mail" -FirstNameAttribute "givenName"

    Updates the SAML attribute mappings for email and first name for the SSO connection "company-saml".

    .EXAMPLE
    $clientSecret = ConvertTo-SecureString "new-client-secret" -AsPlainText -Force
    Set-HPEGLSSOConnection -Name "company-oidc" -OIDClientSecret $clientSecret

    Updates the OIDC client secret for the SSO connection "company-oidc".

    .EXAMPLE
    Get-HPEGLSSOConnection | Set-HPEGLSSOConnection -IdleSessionTimeout 90

    Updates the idle session timeout to 90 minutes for all SSO connections in the workspace by piping the output of Get-HPEGLSSOConnection to Set-HPEGLSSOConnection.
    
    .INPUTS
    System.String
        The name of the authentication policy to update. Can be piped from Get-HPEGLSSOConnection.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following keys:
        * Name - The name of the SSO connection attempted to be updated.
        * Status - The status of the update attempt:
          - "Complete" if the SSO connection was successfully updated
          - "Failed" if the update failed (see Exception for details)
          - "Warning" if no action was needed (e.g., connection not found)
        * Details - Additional information about the operation status.
        * Exception - Information about any exceptions or errors encountered during the operation.
    #>

    [CmdletBinding(DefaultParameterSetName = "SAML20")]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [ValidateNotNullOrEmpty()]
        [String]$NewName,

        [String]$MetadataSource,

        [Parameter (ParameterSetName = "OIDC")]
        [String]$OIDClientId,

        [Parameter (ParameterSetName = "OIDC")]
        [SecureString]$OIDClientSecret,

        [Parameter (ParameterSetName = "SAML20")]
        [String]$EmailAttribute, 
        
        [Parameter (ParameterSetName = "SAML20")]
        [String]$FirstNameAttribute,
        
        [Parameter (ParameterSetName = "SAML20")]
        [String]$LastNameAttribute,

        [Parameter (ParameterSetName = "SAML20")]
        [String]$GreenLakeAttribute,

        [ValidateScript({
                if ($_ -le 1440) {
                    $true
                }
                else {
                    throw "Idle time cannot exceed 1,440 minutes (24 hours)."
                }
            })]
        [Int]$IdleSessionTimeout,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $SetSSOConnectionStatus = [System.Collections.ArrayList]::new()

    }
    
    Process {        
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name      = $Name
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

        # Get existing SSO connection
        try {
            $ExistingConnection = Get-HPEGLSSOConnection -Name $Name
            
            if (-not $ExistingConnection) {
                throw "SSO connection '$Name' not found in the workspace!"
            }

            $SSOConnectionId = $ExistingConnection.id
            
            # Determine protocol based on IdP config type
            if ($ExistingConnection.oidcIdpConfig) {
                $Protocol = "OIDC"
            }
            elseif ($ExistingConnection.samlIdpConfig) {
                $Protocol = "SAML"
            }
            else {
                throw "Unable to determine protocol type for SSO connection '$Name'!"
            }

            "[{0}] Found SSO connection '{1}' with protocol '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Protocol | Write-Verbose

        }
        catch {
            "[{0}] SSO connection '{1}' not available!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "SSO connection '{0}' not found in the workspace!" -f $Name
                Write-warning $ErrorMessage
                return
            }
            else {                
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "SSO connection not found in the workspace!" }
                $objStatus.Exception = $_.Exception.Message
                [void]$SetSSOConnectionStatus.Add($objStatus)
                return
            }
        }

        "[{0}] Updating SSO connection '{1}' in the workspace..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

        # Initialize variables for payload building
        $MetadataData = $null
        $UpdateMetadata = $false

        # Process MetadataSource if provided
        if ($PSBoundParameters.ContainsKey('MetadataSource')) {

            $FileFound = $false
            $UpdateMetadata = $true

            # Check if the MetadataSource is a URL
            if ($MetadataSource -match '^https?://') {

                "[{0}] MetadataSource detected as a URL" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                # Validate IdP metadata
                try {
                    
                    $Uri = (Get-IdPValidateMetadataUrlUri) 

                    if ($Protocol -eq "OIDC") {
                        "[{0}] Validating OIDC IdP Metadata URL: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $MetadataSource | Write-Verbose
                        $Payload = @{ 
                            url      = $MetadataSource 
                            protocol = "OIDC"
                        } | ConvertTo-Json -Depth 5
                    }
                    else {
                        "[{0}] Validating SAML IdP Metadata URL: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $MetadataSource | Write-Verbose
                        $Payload = @{ 
                            url      = $MetadataSource 
                            protocol = "SAML"
                        } | ConvertTo-Json -Depth 5
                    }

                    $MetadataRequestResponse = Invoke-HPEGLWebRequest -Uri $Uri -method 'Post' -ContentType application/json -Body $Payload                

                    "[{0}] IdP Metadata URL validation successful! Response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($MetadataRequestResponse | ConvertTo-Json -Depth 5) | Write-Verbose
                
                    $MetadataData = $MetadataRequestResponse

                    $FileFound = $true

                }
                catch {    

                    if ($Global:HPECOMInvokeReturnData.StatusCode -eq 400) {
                        "[{0}] Call to the IdP Metadata URL failed!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
        
                        if ($WhatIf) {
                            $ErrorMessage = "The IdP Metadata URL cannot be validated! Please check the URL."
                            Write-warning $ErrorMessage
                            return
                        }
                        else {
                            $objStatus.Status = "Failed"
                            $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "The IdP Metadata URL cannot be validated! Please check the URL." }
                            $objStatus.Exception = $Global:HPECOMInvokeReturnData.message
                        }
                    }
                    else {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }
                }
            }
            else {

                "[{0}] MetadataSource detected as a file" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                # Test the path of the XML file 
                $FileFound = Test-Path -Path $MetadataSource

                if ($FileFound) {

                    "[{0}] MetadataSource file has been found!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                    $Uri = (Get-IdPValidateMetadataFileUri)

                    # Create multipart form-data payload for metadata file upload
                    $metadataFile = Get-Item -Path $MetadataSource
                    $boundary = "----geckoformboundary$([guid]::NewGuid().ToString('N'))"
                    $fileName = $metadataFile.Name
                    $fileContent = [System.IO.File]::ReadAllText($metadataFile.FullName)
                
                    # Build multipart form-data body matching browser format exactly
                    $bodyLines = @()
                    $bodyLines += "--$boundary"
                    $bodyLines += 'Content-Disposition: form-data; name="metadata_file"; filename="{0}"' -f $fileName
                    $bodyLines += 'Content-Type: text/xml'
                    $bodyLines += ''
                    $bodyLines += $fileContent
                    $bodyLines += "--$boundary--"
                    $bodyLines += ''
                
                    $Payload = $bodyLines -join "`r`n"
                    $ContentType = "multipart/form-data; boundary=$boundary"
                
                    "[{0}] Metadata validation URI: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri | Write-Verbose
                    "[{0}] Payload size: {1} bytes" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Payload.Length | Write-Verbose
                    "[{0}] Boundary: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $boundary | Write-Verbose
                
                    # Use API access token (v1_2 preferred, fallback to v1_1)
                    if ($Global:HPEGreenLakeSession.glpApiAccessTokenv1_2.access_token) {
                        $glpApiAccessToken = $Global:HPEGreenLakeSession.glpApiAccessTokenv1_2.access_token
                    } 
                    elseif ($Global:HPEGreenLakeSession.glpApiAccessToken.access_token) {
                        $glpApiAccessToken = $Global:HPEGreenLakeSession.glpApiAccessToken.access_token
                    }
                    else {
                        Throw "Error - No API Access Token found in `$Global:HPEGreenLakeSession! 'Connect-HPEGL' must be executed first!"
                    }
                
                    # Build headers with API token
                    $headers = @{} 
                    $headers["Accept"] = "application/json"
                    $headers["Content-Type"] = $ContentType
                    $headers["Authorization"] = "Bearer $($glpApiAccessToken)"
                
                    try {
                        $MetadataRequestResponse = Invoke-WebRequest -Uri $Uri -Method POST -Headers $headers -Body $Payload
                    
                        "[{0}] Metadata validation successful!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    
                        # Store response in global variable for consistency
                        $Global:HPECOMInvokeReturnData = $MetadataRequestResponse

                        # Parse the JSON response from Invoke-WebRequest
                        $MetadataData = $MetadataRequestResponse.Content | ConvertFrom-Json
                    }
                    catch {
                        "[{0}] Failed to validate metadata file!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    
                        # Parse error response from Invoke-WebRequest exception
                        $errorResponse = $null
                        $statusCode = $null
                    
                        if ($_.Exception.Response) {
                            $statusCode = [int]$_.Exception.Response.StatusCode
                        
                            $errorBody = $_.ErrorDetails.Message
                        
                            if ($errorBody) {
                                try {
                                    $errorResponse = $errorBody | ConvertFrom-Json
                                    $Global:HPECOMInvokeReturnData = $errorResponse
                                }
                                catch {
                                    $errorResponse = @{ message = $errorBody }
                                    $Global:HPECOMInvokeReturnData = $errorResponse
                                }
                            }
                        }
                    
                        if ($statusCode -eq 400) {
                            "[{0}] Metadata file validation failed!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                            if ($WhatIf) {
                                $ErrorMessage = "Metadata file validation failed! Message: {0}" -f $errorResponse.message
                                Write-warning $ErrorMessage
                                return
                            }
                            else {
                                $objStatus.Status = "Failed"
                                $objStatus.Details = "Metadata file validation failed!"
                                $objStatus.Exception = $errorResponse
                            }
                        }
                        else {
                            $PSCmdlet.ThrowTerminatingError($_)
                        }
                    }
                }
                else {

                    "[{0}] MetadataSource file not found!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                    if ($WhatIf) {
                        $ErrorMessage = "Metadata XML file cannot be found at '{0}'" -f $MetadataSource
                        Write-warning $ErrorMessage
                        return
                    }
                    else {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Metadata file cannot be found at $MetadataSource"
                        [void]$SetSSOConnectionStatus.Add($objStatus)
                        return
                    }       
                }
            }
        }

        # Build the update payload based on protocol
        if ($Protocol -eq "OIDC") {

            "[{0}] Building OIDC SSO connection update payload..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

            # Start with existing configuration from the connection
            if ($UpdateMetadata -and $MetadataData) {
                "[{0}] Capturing OIDC IdP configuration from metadata..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                
                $OidcIDPConfig = @{
                    authorizationEndpoint = $MetadataData.authorizationEndpoint
                    issuer                = $MetadataData.issuer
                    jwksEndpoint          = $MetadataData.jwksEndpoint
                    tokenEndpoint         = $MetadataData.tokenEndpoint
                    userInfoEndpoint      = $MetadataData.userInfoEndpoint
                    usePkce               = $true
                }
                
                # Preserve client credentials from existing connection if not updating metadata
                if (-not $PSBoundParameters.ContainsKey('OIDClientId') -and $ExistingConnection.oidcIdpConfig.clientId) {
                    $OidcIDPConfig["clientId"] = $ExistingConnection.oidcIdpConfig.clientId
                }
                if (-not $PSBoundParameters.ContainsKey('OIDClientSecret') -and $ExistingConnection.oidcIdpConfig.clientSecret) {
                    $OidcIDPConfig["clientSecret"] = $ExistingConnection.oidcIdpConfig.clientSecret
                }
            }
            else {
                # Use existing IdP configuration
                "[{0}] Using existing OIDC IdP configuration..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                $OidcIDPConfig = @{
                    authorizationEndpoint = $ExistingConnection.oidcIdpConfig.authorizationEndpoint
                    issuer                = $ExistingConnection.oidcIdpConfig.issuer
                    jwksEndpoint          = $ExistingConnection.oidcIdpConfig.jwksEndpoint
                    tokenEndpoint         = $ExistingConnection.oidcIdpConfig.tokenEndpoint
                    userInfoEndpoint      = $ExistingConnection.oidcIdpConfig.userInfoEndpoint
                    usePkce               = $ExistingConnection.oidcIdpConfig.usePkce
                    clientId              = $ExistingConnection.oidcIdpConfig.clientId
                }
                
                # Note: clientSecret is not returned by GET, so we can't include it unless updating
                if ($ExistingConnection.oidcIdpConfig.clientSecret) {
                    $OidcIDPConfig["clientSecret"] = $ExistingConnection.oidcIdpConfig.clientSecret
                }
            }

            # Update client credentials if provided
            if ($PSBoundParameters.ContainsKey('OIDClientId')) {
                $OidcIDPConfig["clientId"] = $OIDClientId
            }

            if ($PSBoundParameters.ContainsKey('OIDClientSecret')) {
                $OidcIDPConfig["clientSecret"] = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($OIDClientSecret))
            }

            # Build attribute mapping - start with existing attributes
            $AttributeMapping = @()
            
            # Preserve existing attribute mappings that aren't being updated
            foreach ($existingAttr in $ExistingConnection.attributeMapping) {
                if ($existingAttr.name -eq "IdleSessionTimeout" -and $PSBoundParameters.ContainsKey('IdleSessionTimeout')) {
                    # Skip, will be added below with new value
                    continue
                }
                $AttributeMapping += $existingAttr
            }

            if ($PSBoundParameters.ContainsKey('IdleSessionTimeout')) {
                $AttributeMapping += [PSCustomObject]@{
                    name       = "IdleSessionTimeout"
                    expression = [string]$IdleSessionTimeout
                }
            }

            # Build final payload
            $PayloadHash = @{
                name = if ($PSBoundParameters.ContainsKey('NewName')) { $NewName } else { $Name }
            }

            if ($OidcIDPConfig.Count -gt 0) {
                $PayloadHash["oidcIdpConfig"] = $OidcIDPConfig
            }

            if ($AttributeMapping.Count -gt 0) {
                $PayloadHash["attributeMapping"] = $AttributeMapping
            }

            $Payload = $PayloadHash | ConvertTo-Json -Depth 5

        }
        else {
            # SAML protocol

            "[{0}] Building SAML 2.0 SSO connection update payload..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

            # Start with existing configuration from the connection
            if ($UpdateMetadata -and $MetadataData) {
                "[{0}] Capturing SAML IdP configuration from metadata..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                
                $SamlIDPConfig = @{
                    entityId    = $MetadataData.entityID
                    loginUrl    = $MetadataData.loginUrl
                    logoutUrl   = $MetadataData.logoutUrl
                    certificate = $MetadataData.certificate
                }
            }
            else {
                # Use existing IdP configuration
                "[{0}] Using existing SAML IdP configuration..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                $SamlIDPConfig = @{
                    entityId    = $ExistingConnection.samlIdpConfig.entityId
                    loginUrl    = $ExistingConnection.samlIdpConfig.loginUrl
                    logoutUrl   = $ExistingConnection.samlIdpConfig.logoutUrl
                    certificate = $ExistingConnection.samlIdpConfig.certificate
                }
            }

            # Build attribute mapping - start with existing attributes
            $AttributeMapping = @()
            
            # Preserve existing attribute mappings that aren't being updated
            foreach ($existingAttr in $ExistingConnection.attributeMapping) {
                $skipAttribute = $false
                
                # Skip attributes that are being updated with new values
                if ($existingAttr.name -eq "Email" -and $PSBoundParameters.ContainsKey('EmailAttribute')) {
                    $skipAttribute = $true
                }
                if ($existingAttr.name -eq "FirstName" -and $PSBoundParameters.ContainsKey('FirstNameAttribute')) {
                    $skipAttribute = $true
                }
                if ($existingAttr.name -eq "LastName" -and $PSBoundParameters.ContainsKey('LastNameAttribute')) {
                    $skipAttribute = $true
                }
                if ($existingAttr.name -eq "IdleSessionTimeout" -and $PSBoundParameters.ContainsKey('IdleSessionTimeout')) {
                    $skipAttribute = $true
                }
                if ($existingAttr.name -eq "HPECCSAttribute" -and $PSBoundParameters.ContainsKey('GreenLakeAttribute')) {
                    $skipAttribute = $true
                }
                
                if (-not $skipAttribute) {
                    $AttributeMapping += $existingAttr
                }
            }

            # Add new/updated attributes
            if ($PSBoundParameters.ContainsKey('EmailAttribute')) {
                $AttributeMapping += [PSCustomObject]@{
                    name       = "Email"
                    expression = $EmailAttribute
                }
            }

            if ($PSBoundParameters.ContainsKey('FirstNameAttribute')) {
                $AttributeMapping += [PSCustomObject]@{
                    name       = "FirstName"
                    expression = $FirstNameAttribute
                }
            }

            if ($PSBoundParameters.ContainsKey('LastNameAttribute')) {
                $AttributeMapping += [PSCustomObject]@{
                    name       = "LastName"
                    expression = $LastNameAttribute
                }
            }

            if ($PSBoundParameters.ContainsKey('IdleSessionTimeout')) {
                $AttributeMapping += [PSCustomObject]@{
                    name       = "IdleSessionTimeout"
                    expression = [string]$IdleSessionTimeout
                }
            }

            if ($PSBoundParameters.ContainsKey('GreenLakeAttribute')) {
                $AttributeMapping += [PSCustomObject]@{
                    name       = "HPECCSAttribute"
                    expression = $GreenLakeAttribute
                }
            }

            # Build final payload
            $PayloadHash = @{
                name             = if ($PSBoundParameters.ContainsKey('NewName')) { $NewName } else { $Name }
                samlIdpConfig    = $SamlIDPConfig
                attributeMapping = $AttributeMapping
            }

            $Payload = $PayloadHash | ConvertTo-Json -Depth 5
        }

        # Create masked payload for verbose logging (mask sensitive data)
        if ($Protocol -eq "OIDC") {
            $PayloadForLogging = $Payload
            # Mask OIDC client secret if present
            $PayloadForLogging = $PayloadForLogging -replace '"clientSecret":\s*"[^"]*"', '"clientSecret": "********"'
            "[{0}] SSO connection update payload (sensitive data masked): {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $PayloadForLogging | Write-Verbose
        }
        else {
            "[{0}] SSO connection update payload: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Payload | Write-Verbose
        }

        $Uri = (Get-SSOConnectionUri) + "/" + $SSOConnectionId

        "[{0}] SSO connection ID: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SSOConnectionId | Write-Verbose
        "[{0}] Update URI: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri | Write-Verbose

        try {

            # For WhatIf, we need to show the masked payload, not the real one
            if ($WhatIf) {
                # Use masked payload for WhatIf display (if OIDC)
                $PayloadForWhatIf = $Payload
                if ($Protocol -eq "OIDC") {
                    # Mask OIDC client secret if present
                    $PayloadForWhatIf = $PayloadForWhatIf -replace '"clientSecret":\s*"[^"]*"', '"clientSecret": "********"'
                }
                $Response = Invoke-HPEGLWebRequest -Method 'PUT' -Body $PayloadForWhatIf -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
            }
            else {
                # Use real payload for actual API call
                # Don't pass VerbosePreference to suppress detailed output with sensitive data
                $Response = Invoke-HPEGLWebRequest -Method 'PUT' -Body $Payload -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$false
            }

            if ($Global:HPECOMInvokeReturnData.StatusCode -in @(200, 201)) {

                if (-not $WhatIf) {
                    "[{0}] SSO connection '{1}' successfully updated in the workspace." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "SSO connection successfully updated in the workspace."
                }
            }
        }
        catch {

            "[{0}] SSO connection '{1}' failed to update." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
            if (-not $WhatIf) {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "SSO connection cannot be updated!" }
                $objStatus.Exception = $Global:HPECOMInvokeReturnData
            }
        }

        [void] $SetSSOConnectionStatus.add($objStatus)
    
    }

    end {

        if (-not $WhatIf) {

            $SetSSOConnectionStatus = Invoke-RepackageObjectWithType -RawObject $SetSSOConnectionStatus -ObjectName "ObjStatus.NSDE" 
            Return $SetSSOConnectionStatus
        }
    }
}

Function Remove-HPEGLSSOConnection {
    <#
    .SYNOPSIS
    Deletes an SSO connection from the workspace.

    .DESCRIPTION
    This cmdlet deletes an SSO connection from your HPE GreenLake workspace.

    .PARAMETER Name
    Specifies the name of the SSO connection to delete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Remove-HPEGLSSOConnection -Name "example.com"
    Deletes the SSO connection "example.com" from the HPE GreenLake workspace.

    .EXAMPLE
    Get-HPEGLSSOConnection | Remove-HPEGLSSOConnection

    Deletes all SSO connections retrieved by Get-HPEGLSSOConnection from the HPE GreenLake workspace.

    .INPUTS
    System.String
        The name of the SSO connection to remove. Can be piped from Get-HPEGLSSOConnection.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following keys:
        * Name - The name of the SSO connection attempted to be removed.
        * Status - The status of the removal attempt (Failed for HTTP error return or if SSO connection is not found; Complete if removal is successful).
        * Details - More information about the status.
        * Exception - Information about any exceptions generated during the operation.
    #>

    [CmdletBinding()]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
        $DeleteStatus = [System.Collections.ArrayList]::new()

    }

    Process {
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        try {
            $SSOConnectionId = (Get-HPEGLSSOConnection -Name $Name).id

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        $objStatus = [pscustomobject]@{
            Name      = $Name
            Status    = $null
            Details   = $null
            Exception = $null
        }

        if (-not $SSOConnectionId) {

            # Must return a message if SSO connection is not found
            "[{0}] SSO connection '{1}' not available!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "SSO connection '{0}' not found in the workspace!" -f $name
                Write-warning $ErrorMessage
                return
            }
            else {                
                $objStatus.Status = "Failed"
                $objStatus.Details = "SSO connection not found in the workspace!" 
                [void]$DeleteStatus.Add($objStatus)
            }
        }
        else {
            $Uri = (Get-SSOConnectionUri) + "/" + $SSOConnectionId

            try {
                $Response = Invoke-HPEGLWebRequest -Uri $Uri -method DELETE -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

                if (-not $WhatIf) {
                    "[{0}] SSO connection '{1}' successfully removed from the workspace." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "SSO connection successfully removed from the workspace."
                    [void] $DeleteStatus.add($objStatus)
                }

            }
            catch {    
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "SSO connection cannot be removed!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData
                    [void] $DeleteStatus.add($objStatus)
                }            
            }
        }

    }
    end {

        if (-not $WhatIf) {

            $DeleteStatus = Invoke-RepackageObjectWithType -RawObject $DeleteStatus -ObjectName "ObjStatus.NSDE" 
            Return $DeleteStatus

        }
    }
}

Function Get-HPEGLSSOAuthenticationPolicy {
    <#
    .SYNOPSIS
    Retrieves information about SSO authentication policies.

    .DESCRIPTION
    This function retrieves detailed information about SSO authentication policies within the HPE GreenLake workspace.

    .PARAMETER WhatIf
    Displays the raw REST API call that would be executed, without actually sending the request. Useful for understanding the native REST API interactions with GLP.

    .EXAMPLE
    Get-HPEGLSSOAuthenticationPolicy 

    Retrieves information about all SSO authentication policies in the workspace.

    .EXAMPLE
    Get-HPEGLSSOAuthenticationPolicy -Name "Default Policy"

    Retrieves information about the SSO authentication policy "Default Policy".
    #>

    [CmdletBinding()]
    Param(        
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Switch]$WhatIf
    )

    Begin {

        $Caller = (Get-PSCallStack)[1].Command
    
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $Uri = (Get-AuthenticationPolicyUri) 
        
        try {

            [Array]$Collection = Invoke-HPEGLWebRequest -Method GET -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference      

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
                
        "[{0}] Content of all authentication policies" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Collection | Out-String) | Write-Verbose

        if ($Collection.Count -gt 0) {

            "[{0}] Found {1} authentication policy(s)." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Collection.Count | Write-Verbose

            if ($Name) {

                $Collection = $Collection | Where-Object Name -eq $Name
            }

            $ReturnData = Invoke-RepackageObjectWithType -RawObject $Collection -ObjectName "Workspace.AuthenticationPolicy"

            # Get SSO connections for mapping authentication policies to SSO connection names
            try {

                $SSOConnections = Invoke-HPEGLWebRequest -Method GET -Uri (Get-SSOConnectionUri) -Verbose:$VerbosePreference       

            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }

            # Add SSO connection mapping to the ssoConnection property
            foreach ( $Policy in $ReturnData ) {

                if ( $Policy.action.authSource -eq "HPE MyAccount" ) {

                    $Policy | Add-Member -MemberType NoteProperty -Name ssoConnection -Value "My HPE account" -Force

                }
                elseif ( $Policy.action.authSource ) {

                    $SSOConnection = $SSOConnections | Where-Object { $_.id -eq $Policy.action.authSource }

                    if ( $SSOConnection ) {

                        $Policy | Add-Member -MemberType NoteProperty -Name ssoConnection -Value $SSOConnection.name -Force
                    }
                }
            }
            
            $ReturnData = $ReturnData | Sort-Object { $_.Name }
    
            return $ReturnData  
        }
        else {

            "[{0}] No authentication policy found in the current environment." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

            return            
        }
    }
}

Function New-HPEGLSSOAuthenticationPolicy {
    <#
    .SYNOPSIS
    Adds an SSO authentication policy to the workspace.

    .DESCRIPTION
    This cmdlet creates an SSO authentication policy in your HPE GreenLake workspace. A maximum of 20 SSO authentication policies can be created per workspace.

    An SSO authentication policy defines how users authenticate to HPE GreenLake by associating a verified or external domain with an SSO connection and specifying the authorization method.

    When creating the first SSO authentication policy, a recovery account is required. This account provides a fallback authentication method if SSO becomes unavailable. The recovery account is shared across all authentication policies in the workspace.

    .PARAMETER VerifiedDomainName
    Specifies the verified domain name to associate with this SSO authentication policy. The domain must be verified before it can be used in an SSO authentication policy. This parameter cannot be used together with ExternalDomainName.

    .PARAMETER ExternalDomainName
    Specifies an external domain name to associate with this SSO authentication policy. Use this parameter when the domain is verified and owned by another organization but you want to allow users from that domain to authenticate to your workspace. This parameter cannot be used together with VerifiedDomainName.
    
    When using an external domain, the domain owner maintains full control over user authentication and lifecycle management, including:
    - User authentication and access control to their domain
    - User deactivation and removal capabilities
    - Management of user role assignments
    - Visibility into which organizations and workspaces their users access
    
    Note: The external domain must be verified by its owner before it can be used in an authentication policy.

    .PARAMETER SSOConnectionName
    Specifies the name of the SSO connection to use for authentication. The SSO connection must exist in the workspace before creating the SSO authentication policy. This parameter is required when VerifiedDomainName is specified, and optional when ExternalDomainName is specified.

    .PARAMETER AuthorizationMethod
    Specifies how user authorization is managed. Supported values are:
    - AuthorizationMode: Authorization is managed by the SSO provider through the SSO SAML response. In this mode, users are granted access and roles based on the information provided by the SSO provider during authentication.
    - AuthenticationOnlyMode: Authorization is managed locally within the HPE GreenLake workspace. In this mode, SSO is used solely for authentication. Users must be added to the workspace manually or through SCIM integration, and their roles and permissions must be explicitly assigned within HPE GreenLake.

    When using AuthorizationMode, you must ensure that the identity provider is configured with authorization mappings before users can access organization workspaces. Without proper identity provider configuration, users subject to this authentication policy will not be able to access organization workspaces. This parameter serves as an explicit acknowledgment of this requirement.
    
    Note: Users whose authorization comes from SSO role assignments (AuthorizationMode) cannot be members of user groups where they can receive additional role assignments. Existing group members subject to this authentication policy will be removed from groups automatically. Users subject to SSO role assignments will be prohibited from being added to groups, including via external SCIM integrations.

    Note: Using SSO role assignments (AuthorizationMode) for an external authentication policy requires that the protocol used by the SSO connection supports authorization attributes and requires the ability to configure authorization mappings in the identity provider. Without identity provider-specified authorization, users affected by the authentication policy will not be able to access organization workspaces.

    .PARAMETER RecoveryAccountSecurePassword
    Specifies the recovery account password as a SecureString. Required when creating the first SSO authentication policy in the workspace. The password must be at least 8 characters long and include upper-case, lower-case, number, and symbol characters.
    
    The recovery account provides a fallback authentication method when SSO is unavailable. It is strongly recommended to retain this account as a safeguard against SSO disruptions.
    
    If a recovery account already exists in the workspace (from a previous authentication policy), this parameter is optional.

    .PARAMETER RecoveryAccountContactEmail
    Specifies the contact email address for password recovery of the recovery account. Required when RecoveryAccountSecurePassword is provided.
    
    This email will be used to reset the recovery account password if forgotten. It is recommended to use a distribution list or team alias rather than an individual's email.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    # Example 1: Create authentication policy for verified domain with recovery account
    $password = ConvertTo-SecureString "MySecurePass123!" -AsPlainText -Force
    New-HPEGLSSOAuthenticationPolicy -VerifiedDomainName "example.com" -SSOConnectionName "example.com" -AuthorizationMethod "AuthorizationMode" -RecoveryAccountSecurePassword $password -RecoveryAccountContactEmail "it-admin@example.com"

    Creates an authentication policy for the verified domain "example.com" with SSO-managed authorization and creates a recovery account for emergency access.

    .EXAMPLE
    # Example 2: Create authentication policy with local authorization (recovery account already exists)
    New-HPEGLSSOAuthenticationPolicy -VerifiedDomainName "example.com" -SSOConnectionName "example.com" -AuthorizationMethod "AuthenticationOnlyMode"

    Creates an authentication policy that uses SSO for authentication but manages user authorization locally in HPE GreenLake. Assumes a recovery account already exists in the workspace.

    .EXAMPLE
    # Example 3: Create authentication policy for external domain
    $password = ConvertTo-SecureString "SecureRecovery456!" -AsPlainText -Force
    New-HPEGLSSOAuthenticationPolicy -ExternalDomainName "partner.com" -AuthorizationMethod "AuthorizationMode" -RecoveryAccountSecurePassword $password -RecoveryAccountContactEmail "security-team@company.com"

    Creates an authentication policy for an external domain "partner.com", allowing users from that domain to authenticate while the partner organization maintains control over their users. Note: SSOConnectionName is not specified because external domains use the domain owner's SSO configuration.

    .INPUTS
    None. You cannot pipe objects to this cmdlet.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following keys:
        * Name - The name of the SSO authentication policy attempted to be added. The name is automatically generated from the domain name associated with the SSO authentication policy.
        * RecoveryUserEmail - The auto-generated recovery account email (if a new recovery account was created).
        * Status - The status of the creation attempt:
          - "Complete" if the authentication policy was successfully created
          - "Failed" if the creation failed (see Exception for details)
          - "Warning" if no action was needed (e.g., policy already exists)
        * Details - Additional information about the operation status.
        * Exception - Information about any exceptions or errors encountered during the operation.
    #>

    [CmdletBinding()]
    Param( 

        [Parameter (Mandatory, ParameterSetName = "VerifiedDomainName")]
        [ValidateNotNullOrEmpty()]
        [String]$VerifiedDomainName,

        [Parameter (Mandatory, ParameterSetName = "ExternalDomainName")]
        [ValidateNotNullOrEmpty()]
        [String]$ExternalDomainName,

        [Parameter (Mandatory, ParameterSetName = "VerifiedDomainName")]
        [ValidateNotNullOrEmpty()]
        [String]$SSOConnectionName,

        [Parameter (Mandatory)]
        [ValidateSet("AuthorizationMode", "AuthenticationOnlyMode")]
        [String]$AuthorizationMethod,

        [SecureString]$RecoveryAccountSecurePassword,

        [validatescript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$RecoveryAccountContactEmail,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-AuthenticationPolicyUri

        $AddAuthPolicyStatus = [System.Collections.ArrayList]::new()

        # Check that if RecoveryAccountSecurePassword is provided, then RecoveryAccountContactEmail is also provided
        if ($PSBoundParameters.ContainsKey('RecoveryAccountSecurePassword') -and -not $PSBoundParameters.ContainsKey('RecoveryAccountContactEmail')) {
            Throw "If 'RecoveryAccountSecurePassword' is provided, then 'RecoveryAccountContactEmail' must also be provided."
        }
        # and the opposite
        if ($PSBoundParameters.ContainsKey('RecoveryAccountContactEmail') -and -not $PSBoundParameters.ContainsKey('RecoveryAccountSecurePassword')) {
            Throw "If 'RecoveryAccountContactEmail' is provided, then 'RecoveryAccountSecurePassword' must also be provided."
        }

    }
    
    Process {        
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
         
        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Name      = if ($VerifiedDomainName) { $VerifiedDomainName } else { $ExternalDomainName }
            Status    = $Null
            Details   = $Null
            Exception = $Null
                                  
        }  
        
        # Only add RecoveryUserEmail if RecoveryAccountSecurePassword is provided
        if ($RecoveryAccountSecurePassword) {
            $objStatus | Add-Member -MemberType NoteProperty -Name "RecoveryUserEmail" -Value $Null
        }
        
        # Check if authentication policy with the same name already exists
        try {
            $ExistingPolicies = Get-HPEGLSSOAuthenticationPolicy 
            $ExistingPolicy = $ExistingPolicies | Where-Object { $_.Name -eq $VerifiedDomainName }

            # Check if a recovery user already exists in the authentication policies
            # Recovery users are identified by policyType = "USER_RECOVERY"
            $ExistingRecoveryUser = $ExistingPolicies | Where-Object { $_.policyType -eq "USER_RECOVERY" }

            if ($ExistingPolicy) {

                "[{0}] SSO Authentication policy '{1}' already exists in the workspace for this domain!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $VerifiedDomainName | Write-Verbose

                if ($WhatIf) {
                    $ErrorMessage = "SSO Authentication policy '{0}' already exists in the workspace for this domain!" -f $VerifiedDomainName
                    Write-warning $ErrorMessage
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "SSO Authentication policy already exists in the workspace for this domain." 
                    [void]$AddAuthPolicyStatus.Add($objStatus)
                    return
                }
            }
        }
        catch {
            if (-not $WhatIf) {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "SSO connection cannot be created!" }
                $objStatus.Exception = $Global:HPECOMInvokeReturnData
                [void] $AddAuthPolicyStatus.Add($objStatus)
                return
            }
        }

        if ($PSBoundParameters.ContainsKey('ExternalDomainName')) {

            "[{0}] External domain '{1}' specified for the authentication policy." -f $MyInvocation.InvocationName.ToString().ToUpper(), $ExternalDomainName | Write-Verbose
        }
        else {

            "[{0}] Claimed domain '{1}' specified for the authentication policy." -f $MyInvocation.InvocationName.ToString().ToUpper(), $ClaimedDomainName | Write-Verbose

            # Check if domain exists and is verified

            "[{0}] Checking if verified domain '{1}' exists and is verified in the workspace..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $VerifiedDomainName | Write-Verbose

            try {
                $Domain = Get-HPEGLDomain -Name $VerifiedDomainName
    
                if (-not $Domain) {
    
                    "[{0}] Verified domain '{1}' not found in the workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $VerifiedDomainName | Write-Verbose
    
                    if ($WhatIf) {
                        $ErrorMessage = "Domain '{0}' not found in the workspace!" -f $VerifiedDomainName
                        Write-warning $ErrorMessage
                        return
                    }
                    else {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Domain not found in the workspace!" 
                        [void]$AddAuthPolicyStatus.Add($objStatus)
                        return
                    }
                }
                elseif ($Domain.lifeCycleState -ne "VERIFIED") {
    
                    "[{0}] Domain '{1}' is not verified!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $VerifiedDomainName | Write-Verbose
    
                    if ($WhatIf) {
                        $ErrorMessage = "Domain '{0}' is not verified! Please verify the domain by adding the DNS TXT record to your DNS provider and running the 'Test-HPEGLDomain' cmdlet to complete the verification process." -f $VerifiedDomainName
                        Write-warning $ErrorMessage
                        return
                    }
                    else {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Domain is not verified! Please verify the domain by adding the DNS TXT record to your DNS provider and running the 'Test-HPEGLDomain' cmdlet to complete the verification process." 
                        [void]$AddAuthPolicyStatus.Add($objStatus)
                        return
                    }
                }
            }
            catch {
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "SSO connection cannot be created!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData
                    [void] $AddAuthPolicyStatus.Add($objStatus)
                    return
                }
            }
    
            # Check if SSO connection exists
            
            "[{0}] Checking if SSO connection '{1}' exists in the workspace..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $SSOConnectionName | Write-Verbose

            try {
                $SSOConnection = Get-HPEGLSSOConnection -Name $SSOConnectionName
    
                if (-not $SSOConnection) {
    
                    "[{0}] SSO connection '{1}' not found in the workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SSOConnectionName | Write-Verbose
    
                    if ($WhatIf) {
                        $ErrorMessage = "SSO connection '{0}' not found in the workspace!" -f $SSOConnectionName
                        Write-warning $ErrorMessage
                        return
                    }
                    else {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "SSO connection not found in the workspace!" 
                        [void]$AddAuthPolicyStatus.Add($objStatus)
                        return
                    }
                }
            }
            catch {
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "SSO connection cannot be created!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData
                    [void] $AddAuthPolicyStatus.Add($objStatus)
                    return
                }
            }
        }

        # If there is no existing recovery user email, one must be created and if RecoveryAccountSecurePassword is not provided, an error must be returned.
        if (-not $ExistingRecoveryUser) {

            "[{0}] No existing recovery user found in the workspace. A recovery account must be created." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

            if (-not $RecoveryAccountSecurePassword) {

                "[{0}] RecoveryAccountSecurePassword parameter is required when adding the first SSO authentication policy. No existing recovery user found in the workspace." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                
                if ($WhatIf) {
                    $ErrorMessage = "A recovery account is required because no existing recovery user was found. Please provide the RecoveryAccountSecurePassword parameter to create the recovery account when adding this SSO authentication policy."
                    Write-warning $ErrorMessage
                    return
                }
                else {                
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "A recovery account is required because no existing recovery user was found. Please provide the RecoveryAccountSecurePassword parameter to create the recovery account when adding this SSO authentication policy."
                    [void]$AddAuthPolicyStatus.Add($objStatus)
                    return 
                }
            }
            else {

                "[{0}] Creating recovery account for the workspace..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    
                # Auto-generate recovery username in format flg8xkzm0jkx66i85sxst0jwmzhzdu6z@recovery.auth.greenlake.hpe.com
                $RandomString = -join ((48..57) + (65..90) + (97..122) | Get-Random -Count 32 | ForEach-Object { [char]$_ })
                $RecoveryUsername = "{0}@recovery.auth.greenlake.hpe.com" -f $RandomString
                "[{0}] Generated recovery username: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RecoveryUsername | Write-Verbose
    
                # Save recovery username to output object
                $objStatus.RecoveryUserEmail = $RecoveryUsername
    
                # Convert SecureString to plain text for API submission
                $RecoveryPasswordPlainText = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($RecoveryAccountSecurePassword))
            
                "[{0}] Building recovery account payload..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
    
                # Create payload for the recovery account (keep as hashtable, not JSON string)
                $Payload = @{
                    action     = @{
                        type = "DEFAULT"
                    }
                    condition  = @{
                        user = @{
                            email           = $RecoveryUsername
                            password        = $RecoveryPasswordPlainText
                            recoveryAccount = $RecoveryAccountContactEmail
                        }
                    }
                    policyType = "USER_RECOVERY" 
                } | ConvertTo-Json -Depth 5
    
                "[{0}] About to run a POST {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri | Write-Verbose

                # Create masked payload for logging (mask password)
                $PayloadForLogging = $Payload -replace '"password":\s*"[^"]*"', '"password": "********"'
                "[{0}] Recovery account payload (password masked): `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $PayloadForLogging | Write-Verbose
    
                try {
    
                    # For WhatIf, we need to show the masked payload, not the real one
                    if ($WhatIf) {
                        # Use masked payload for WhatIf display
                        $Response = Invoke-HPEGLWebRequest -Method 'POST' -Body $PayloadForLogging -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                    }
                    else {
                        # Use real payload for actual API call
                        # Don't pass VerbosePreference to suppress detailed output with sensitive data
                        $Response = Invoke-HPEGLWebRequest -Method 'POST' -Body $Payload -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$false
                    }
    
                    if ($Global:HPECOMInvokeReturnData.StatusCode -in @(200, 201)) {
    
                        if (-not $WhatIf) {
                            "[{0}] Recovery account successfully added to the workspace." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            $objStatus.Status = "Complete"
                            $objStatus.Details = "Recovery account successfully added to the workspace."
                        }
                    }
                    else {
                        # Handle non-success status codes
                        "[{0}] Recovery account failed to add. Status code: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Global:HPECOMInvokeReturnData.StatusCode | Write-Verbose
                        if (-not $WhatIf) {
                            $objStatus.Status = "Failed"
                            $objStatus.Details = "Recovery account cannot be added! Status code: $($Global:HPECOMInvokeReturnData.StatusCode)"
                            $objStatus.Exception = $Global:HPECOMInvokeReturnData
                            [void] $AddAuthPolicyStatus.Add($objStatus)
                            return
                        }
                    }
                }
                catch {
    
                    "[{0}] Recovery account failed to add with exception." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    if (-not $WhatIf) {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else {"Recovery account cannot be added!"}
                        $objStatus.Exception = $Global:HPECOMInvokeReturnData
                        [void] $AddAuthPolicyStatus.Add($objStatus)
                        return
                    }
                }        
            }
        }

        # Build the final payload   

        "[{0}] Building authentication policy payload..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

        if ($PSBoundParameters.ContainsKey('ExternalDomainName')) {
            if ($AuthorizationMethod -eq "AuthorizationMode") {
                $Payload = @{
                    policyType = "DOMAIN_EXTERNAL"
                    condition  = @{
                        domain = $ExternalDomainName 
                    }
                    action     = @{
                        authSource = ""
                        type       = "EXTERNAL"
                    }
                    targets    = @{
                        authorizationMode = @{
                            managedOrganizations   = @("*")
                            organizationWorkspaces = @("*")
                        }
                    }
                } | ConvertTo-Json -Depth 5
            }
            else {
                $Payload = @{
                    policyType = "DOMAIN_EXTERNAL"
                    condition  = @{
                        domain = $ExternalDomainName 
                    }
                    action     = @{
                        authSource = ""
                        type       = "EXTERNAL"
                    }
                    targets    = @{
                        authenticationOnlyMode = @{
                            managedOrganizations   = @("*")
                            organizationWorkspaces = @("*")
                        }
                    }
                } | ConvertTo-Json -Depth 5
            }
        }
        else {
            if ($AuthorizationMethod -eq "AuthorizationMode") {
                $Payload = @{
                    policyType = "DOMAIN_VERIFIED"
                    condition  = @{
                        domain = $VerifiedDomainName 
                    }
                    action     = @{
                        authSource = $SSOConnection.Id
                        type       = "SSO_PROFILE"
                    }
                    targets    = @{
                        authorizationMode = @{
                            managedOrganizations   = @("*")
                            organizationWorkspaces = @("*")
                        }
                    }
                } | ConvertTo-Json -Depth 5
            }
            else {
                $Payload = @{
                    policyType = "DOMAIN_VERIFIED"
                    condition  = @{
                        domain = $VerifiedDomainName 
                    }
                    action     = @{
                        authSource = $SSOConnection.Id
                        type       = "SSO_PROFILE"
                    }
                    targets    = @{
                        authenticationOnlyMode = @{
                            managedOrganizations   = @("*")
                            organizationWorkspaces = @("*")
                        }
                    }
                } | ConvertTo-Json -Depth 5
            }
        }

        "[{0}] SSO Authentication policy payload: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Payload | Write-Verbose
    
        try {

            $Response = Invoke-HPEGLWebRequest -Method 'POST' -Body $Payload -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

            if ($Global:HPECOMInvokeReturnData.StatusCode -eq 200) {

                if (-not $WhatIf) {
                    "[{0}] SSO Authentication policy '{1}' successfully added to the workspace." -f $MyInvocation.InvocationName.ToString().ToUpper(), $VerifiedDomainName | Write-Verbose
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "SSO Authentication policy successfully added to the workspace."
                }
            }
        }
        catch {

            "[{0}] SSO Authentication policy '{1}' failed to add." -f $MyInvocation.InvocationName.ToString().ToUpper(), $VerifiedDomainName | Write-Verbose
            if (-not $WhatIf) {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "SSO Authentication policy cannot be added!" }
                $objStatus.Exception = $Global:HPECOMInvokeReturnData
            }
        }
            
        [void] $AddAuthPolicyStatus.Add($objStatus)
    }
    end {

        if (-not $WhatIf) {

            if ($RecoveryAccountSecurePassword) {
                $AddAuthPolicyStatus = Invoke-RepackageObjectWithType -RawObject $AddAuthPolicyStatus -ObjectName "ObjStatus.NRSDE" 
            }
            else {
                $AddAuthPolicyStatus = Invoke-RepackageObjectWithType -RawObject $AddAuthPolicyStatus -ObjectName "ObjStatus.NSDE"
            }

            Return $AddAuthPolicyStatus
        }
    }
}

Function Remove-HPEGLSSOAuthenticationPolicy {
    <#
    .SYNOPSIS
    Deletes an authentication policy from the workspace.

    .DESCRIPTION
    This cmdlet deletes an authentication policy from your HPE GreenLake workspace.

    .PARAMETER Name
    Specifies the name of the authentication policy to delete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Remove-HPEGLSSOAuthenticationPolicy -Name "Default Policy"
    Deletes the authentication policy "Default Policy" from the HPE GreenLake workspace.

    .EXAMPLE
    Get-HPEGLSSOAuthenticationPolicy | Remove-HPEGLSSOAuthenticationPolicy

    Deletes all authentication policies retrieved by Get-HPEGLSSOAuthenticationPolicy from the HPE GreenLake workspace.

    .INPUTS
    System.String
        The name of the authentication policy to delete. Can be piped from Get-HPEGLSSOAuthenticationPolicy.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following keys:
        * Name - The name of the authentication policy attempted to be deleted.
        * Status - The status of the deletion attempt (Failed for HTTP error return or if authentication policy is not found; Deleting if deletion is in progress).
        * Details - More information about the status.
        * Exception - Information about any exceptions generated during the operation.

    #>

    [CmdletBinding()]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
        $DeleteStatus = [System.Collections.ArrayList]::new()

    }

    Process {
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        try {
            $AuthenticationPolicyId = (Get-HPEGLSSOAuthenticationPolicy -Name $Name).id

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        $objStatus = [pscustomobject]@{
            Name      = $Name
            Status    = $null
            Details   = $null
            Exception = $null
        }

        if (-not $AuthenticationPolicyId) {

            # Must return a message if authentication policy is not found
            "[{0}] Authentication policy '{1}' not available!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "Authentication policy '{0}' not found in the workspace!" -f $name
                Write-warning $ErrorMessage
                return
            }
            else {                
                $objStatus.Status = "Failed"
                $objStatus.Details = "Authentication policy not found in the workspace!" 
                [void]$DeleteStatus.Add($objStatus)
            }
        }
        else {
            $Uri = (Get-AuthenticationPolicyUri) + "/" + $AuthenticationPolicyId

            try {
                $Response = Invoke-HPEGLWebRequest -Uri $Uri -method 'DELETE' -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

                if (-not $WhatIf) {
                    "[{0}] Authentication policy '{1}' successfully removed from the workspace." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                    $objStatus.Status = "Deleting"
                    $objStatus.Details = "Authentication policy successfully removed from the workspace."
                    [void] $DeleteStatus.add($objStatus)
                }

            }
            catch {    
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else {"Authentication policy cannot be removed!"}
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                    [void] $DeleteStatus.add($objStatus)
                }
            
            }
        }

    }

    end {

        if (-not $WhatIf) {

            $DeleteStatus = Invoke-RepackageObjectWithType -RawObject $DeleteStatus -ObjectName "ObjStatus.NSDE" 
            Return $DeleteStatus

        }
    }
}

Function Set-HPEGLSSOAuthenticationPolicy {
    <#
    .SYNOPSIS
    Updates an existing authentication policy in the workspace.

    .DESCRIPTION
    This cmdlet modifies an existing authentication policy in your HPE GreenLake workspace. You can update the authorization method (SSO-managed or Locally-managed), change the SSO connection associated with the policy, and specify a user removal policy when changing authorization methods.

    .PARAMETER Name
    Specifies the name of the authentication policy to update.

    .PARAMETER AuthorizationMethod
    Specifies the authorization method for the authentication policy. Supported values are:
    - AuthorizationMode: Use the SSO connection for session-based authorization.
    - AuthenticationOnlyMode: Manage authorization locally via the GreenLake workspace.

    .PARAMETER UserRemovalPolicy
    Specifies what happens to users when changing authorization methods. Required when switching between AuthorizationMode and AuthenticationOnlyMode authorization. Supported values are:
    - Remove users: Users will be removed when changing authorization method.
    - Retain users: Users will be retained when changing authorization method.

    .PARAMETER SSOConnection
    Specifies the name of the SSO connection to associate with this authentication policy. Use this to change which SSO connection is used for authentication.
    
    Note: This parameter cannot be used with external SSO domain policies, as those use the domain owner's SSO connection.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Set-HPEGLSSOAuthenticationPolicy -Name "Default Policy" -SSOConnection "example.com"
    Updates the "Default Policy" to use the SSO connection "example.com" for authentication.

    .EXAMPLE
    Set-HPEGLSSOAuthenticationPolicy -Name "Default Policy" -AuthorizationMethod "AuthenticationOnlyMode" -UserRemovalPolicy "Retain users"
    Changes the authorization method to AuthenticationOnlyMode (locally-managed) while retaining existing users.

    .EXAMPLE
    Set-HPEGLSSOAuthenticationPolicy -Name "Default Policy" -AuthorizationMethod "AuthorizationMode" -UserRemovalPolicy "Remove users"
    Changes the authorization method to AuthorizationMode (SSO-managed) and removes existing users during the transition.

    .EXAMPLE
    Get-HPEGLSSOAuthenticationPolicy | Set-HPEGLSSOAuthenticationPolicy -AuthorizationMethod AuthorizationMode -UserRemovalPolicy 'Retain users' 

    Updates all authentication policies in the workspace to use SSO-managed authorization while retaining existing users.

    .INPUTS
    System.String
        The name of the authentication policy to update. Can be piped from Get-HPEGLSSOAuthenticationPolicy.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following keys:
        * Name - The name of the authentication policy attempted to be updated.
        * Status - The status of the update attempt (Failed for HTTP error return; Configuring if update is successful, Warning if no change is detected).
        * Details - More information about the status.
        * Exception - Information about any exceptions generated during the operation.

    #>

    [CmdletBinding(DefaultParameterSetName = "AuthorizationMethod")]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Parameter(ParameterSetName = "AuthorizationMethod")]
        [ValidateSet("AuthorizationMode", "AuthenticationOnlyMode")]
        [String]$AuthorizationMethod,

        [Parameter(ParameterSetName = "AuthorizationMethod")]
        [ValidateSet("Remove users", "Retain users")]
        [String]$UserRemovalPolicy,

        [Parameter(ParameterSetName = "SSOConnection")]
        [string]$SSOConnection,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $SetAuthenticationPolicyStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name      = $Name
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }   

        # Validate that at least one update parameter is provided
        if (-not $SSOConnection -and -not $AuthorizationMethod) {
            if ($WhatIf) {
                $ErrorMessage = "No update parameters provided. Please specify either -SSOConnection or -AuthorizationMethod parameter."
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "No update parameters provided. Please specify either -SSOConnection or -AuthorizationMethod parameter."
                [void] $SetAuthenticationPolicyStatus.add($objStatus)
                return
            }
        }

        # Validate authentication policy existence

        try {
            $ExistingPolicy = Get-HPEGLSSOAuthenticationPolicy -Name $Name

            $ExistingPolicyAuthorizationMethod = ($ExistingPolicy.targets | Get-Member -MemberType NoteProperty).name
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
        
        if (-not $ExistingPolicy) {
            if ($WhatIf) {
                $ErrorMessage = "Authentication policy '{0}' not found in the workspace!" -f $Name
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "Authentication policy '{0}' not found in the workspace!" -f $Name
                [void] $SetAuthenticationPolicyStatus.add($objStatus)
                return
            }
        }
        elseif ($ExistingPolicy.policyType -eq "USER_RECOVERY") {
            if ($WhatIf) {
                $ErrorMessage = "Authentication policy '{0}' is a User Recovery policy and cannot be modified!" -f $Name
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "Authentication policy '{0}' is a User Recovery policy and cannot be modified!" -f $Name
                [void] $SetAuthenticationPolicyStatus.add($objStatus)
                return
            }
        }
        else {

            "[{0}] Authentication policy '{1}' found in the workspace." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
            
            # Validate SSO connection if provided
            if ($SSOConnection) {

                "[{0}] SSO connection '{1}' specified for the authentication policy update." -f $MyInvocation.InvocationName.ToString().ToUpper(), $SSOConnection | Write-Verbose

                # Check if the policy is using an external SSO (EXTERNAL type) which doesn't have SSO connection
                if ($ExistingPolicy.action.type -eq "EXTERNAL") {
                    if ($WhatIf) {
                        $ErrorMessage = "Authentication policy '{0}' is using external SSO authentication (EXTERNAL type) and cannot be associated with an SSO connection." -f $Name
                        Write-warning $ErrorMessage
                        return
                    }
                    else {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Authentication policy is using external SSO authentication (EXTERNAL type) and cannot be associated with an SSO connection."
                        [void] $SetAuthenticationPolicyStatus.add($objStatus)
                        return
                    }
                }

                try {
                    $SSOConnectionObj = Get-HPEGLSSOConnection -Name $SSOConnection

                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }

                if (-not $SSOConnectionObj) {
                    if ($WhatIf) {
                        $ErrorMessage = "SSO connection '{0}' not found in the workspace!" -f $SSOConnection
                        Write-warning $ErrorMessage
                        return
                    }
                    else {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "SSO connection '{0}' not found in the workspace!" -f $SSOConnection
                        [void] $SetAuthenticationPolicyStatus.add($objStatus)
                        return
                    }
                }
                elseif ( $ExistingPolicy.action.authSource -eq $SSOConnectionObj.id ) {
                    
                    "[{0}] SSO connection '{1}' is already associated with the authentication policy." -f $MyInvocation.InvocationName.ToString().ToUpper(), $SSOConnection | Write-Verbose

                    if ($WhatIf) {
                        $ErrorMessage = "SSO connection '{0}' is already associated with the authentication policy." -f $SSOConnection
                        Write-warning $ErrorMessage
                        return
                    }
                    else {
                        $objStatus.Status = "Warning"
                        $objStatus.Details = "SSO connection '{0}' is already associated with the authentication policy." -f $SSOConnection
                        [void] $SetAuthenticationPolicyStatus.add($objStatus)
                        return
                    }
                }
                else {
                    "[{0}] SSO connection '{1}' found in the workspace." -f $MyInvocation.InvocationName.ToString().ToUpper(), $SSOConnection | Write-Verbose

                    $Body = @{
                        action = @{ 
                            type       = "SSO_PROFILE"
                            authSource = $SSOConnectionObj.id
                        }
                    } | ConvertTo-Json -Depth 5

                    $uri = (Get-AuthenticationPolicyUri) + "/" + $ExistingPolicy.id

                    # Update the authentication policy with new SSO connection
                    "[{0}] Updating authentication policy '{1}' with SSO connection '{2}'..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $SSOConnection | Write-Verbose

                    try {
                        $Response = Invoke-HPEGLWebRequest -Uri $uri -Method 'PATCH' -Body $Body -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
    
                        if (-not $WhatIf) {
                            "[{0}] Authentication policy '{1}' successfully updated with SSO connection '{2}'." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $SSOConnection | Write-Verbose
                            $objStatus.Status = "Configuring"
                            $objStatus.Details = "Authentication policy successfully updated with SSO connection '{0}'." -f $SSOConnection
                        }
                    }
                    catch {
                        if (-not $WhatIf) {
                            "[{0}] Failed to update authentication policy '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $_.Exception.Message | Write-Verbose
                            $objStatus.Status = "Failed"
                            $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Authentication policy cannot be updated!" }
                            $objStatus.Exception = $Global:HPECOMInvokeReturnData
                        }
                    }

                    [void] $SetAuthenticationPolicyStatus.Add($objStatus)
                }
            }

            # Check change autorization impact
            if ($AuthorizationMethod ) {

                if ( $AuthorizationMethod -ne $ExistingPolicyAuthorizationMethod ) {
                    
                    "[{0}] Authorization method change detected: from '{1}' to '{2}'." -f $MyInvocation.InvocationName.ToString().ToUpper(), $ExistingPolicyAuthorizationMethod, $AuthorizationMethod | Write-Verbose

                    if ($ExistingPolicyAuthorizationMethod -eq "AuthorizationMode" -and $AuthorizationMethod -eq "AuthenticationOnlyMode") {

                        # Changing from AuthorizationMode to AuthenticationOnlyMode
                        if (-not $UserRemovalPolicy) {
                            if ($WhatIf) {
                                $ErrorMessage = "Changing authorization method in '{0}' from 'AuthorizationMode' to 'AuthenticationOnlyMode' requires specifying the UserRemovalPolicy parameter." -f $Name
                                Write-warning $ErrorMessage
                                return
                            }
                            else {
                                $objStatus.Status = "Failed"
                                $objStatus.Details = "Changing authorization method from 'AuthorizationMode' to 'AuthenticationOnlyMode' requires specifying the UserRemovalPolicy parameter."
                                [void] $SetAuthenticationPolicyStatus.add($objStatus)
                                return
                            }
                        }
                        else {
                            "[{0}] User removal policy set to '{1}'." -f $MyInvocation.InvocationName.ToString().ToUpper(), $UserRemovalPolicy | Write-Verbose

                            if ($UserRemovalPolicy -eq "Remove users") {
                                $RemoveUsers = "true"
                            }
                            else {
                                $RemoveUsers = "false"
                            }

                            $Body = @{
                                condition = @{}
                                targets   = @{
                                    authenticationOnlyMode = @{
                                        managedOrganizations   = @("*")
                                        organizationWorkspaces = @("*")
                                    }
                                }
                            } | ConvertTo-Json -Depth 5

                            $uri = (Get-AuthenticationPolicyUri) + "/" + $ExistingPolicy.id + "?remove-users=$RemoveUsers"
                        }
                    }
                    elseif ( $ExistingPolicyAuthorizationMethod -eq "AuthenticationOnlyMode" -and $AuthorizationMethod -eq "AuthorizationMode") {
    
                        # Changing from AuthenticationOnlyMode to AuthorizationMode
                        if (-not $UserRemovalPolicy) {
                            if ($WhatIf) {
                                $ErrorMessage = "Changing authorization method in '{0}' from 'AuthenticationOnlyMode' to 'AuthorizationMode' requires specifying the UserRemovalPolicy parameter." -f $Name
                                Write-warning $ErrorMessage
                                return
                            }
                            else {
                                $objStatus.Status = "Failed"
                                $objStatus.Details = "Changing authorization method from 'AuthenticationOnlyMode' to 'AuthorizationMode' requires specifying the UserRemovalPolicy parameter."
                                [void] $SetAuthenticationPolicyStatus.add($objStatus)
                                return
                            }
                        }
                        else {

                            "[{0}] User removal policy set to '{1}'." -f $MyInvocation.InvocationName.ToString().ToUpper(), $UserRemovalPolicy | Write-Verbose

                            if ($UserRemovalPolicy -eq "Remove users") {
                                $RemoveUsers = "true"
                            }
                            else {
                                $RemoveUsers = "false"
                            }

                            $Body = @{
                                condition = @{}
                                targets   = @{
                                    authorizationMode = @{
                                        managedOrganizations   = @("*")
                                        organizationWorkspaces = @("*")
                                    }
                                }
                            } | ConvertTo-Json -Depth 5

                            $uri = (Get-AuthenticationPolicyUri) + "/" + $ExistingPolicy.id + "?remove-users=$RemoveUsers"
                        }
                    }
                    
                    # Proceed to update the authentication policy
                    "[{0}] Updating authentication policy '{1}'..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose   

                    try {
                        $Response = Invoke-HPEGLWebRequest -Uri $uri -Method 'PATCH' -Body $Body -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
    
                        if (-not $WhatIf) {
                            "[{0}] Authentication policy '{1}' successfully updated." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                            $objStatus.Status = "Configuring"
                            $objStatus.Details = "Authentication policy successfully updated."
                        }
                    }
                    catch {
                        if (-not $WhatIf) {
                            "[{0}] Failed to update authentication policy '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $_.Exception.Message | Write-Verbose
                            $objStatus.Status = "Failed"
                            $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Authentication policy cannot be updated!" }
                            $objStatus.Exception = $Global:HPECOMInvokeReturnData

                        }
                    }
                }
                else {
                    "[{0}] No authorization method change detected." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    if ($WhatIf) {
                        $ErrorMessage = "No authorization method change detected in '{0}'." -f $Name
                        Write-warning $ErrorMessage
                        return
                    }
                    else {
                        $objStatus.Status = "Warning"
                        $objStatus.Details = "No authorization method change detected."
                        [void] $SetAuthenticationPolicyStatus.add($objStatus)
                        return
                    }
                }

                [void] $SetAuthenticationPolicyStatus.add($objStatus)
            }
        }
    }

    end {

        if (-not $WhatIf) {

            $SetAuthenticationPolicyStatus = Invoke-RepackageObjectWithType -RawObject $SetAuthenticationPolicyStatus -ObjectName "ObjStatus.NSDE" 
            Return $SetAuthenticationPolicyStatus
        }
    }
}

# Deprecated functions (kept for backward compatibility with IAMv1 workspaces)

Function Get-HPEGLWorkspaceSAMLSSODomain {
    <#
    .SYNOPSIS
    Retrieves details of the SAML SSO domain.

    .DESCRIPTION
    [DEPRECATED] This function is deprecated and maintained only for IAMv1 workspace compatibility. It will be removed in a future release.
    
    For IAMv2 workspaces, use 'Get-HPEGLDomain' to retrieve domain information and 'Get-HPEGLSSOConnection' to retrieve SSO connection details.
    
    This function retrieves information about the SAML SSO domain configured in the workspace. It can return SAML attributes, download the metadata file for a specified domain, and extract the X509 certificate from the metadata file if requested.

    .PARAMETER DomainName
    Specifies the name of the SAML SSO domain.

    .PARAMETER ShowSAMLAttributes
    If specified, returns the SAML attributes for the specified domain.

    .PARAMETER ShowSPCertificate
    If specified, returns the Service Provider (SP, i.e., HPE GreenLake) X509 certificate.

    .PARAMETER ShowIDPCertificate
    If specified, returns the Identity Provider (IdP) X509 certificate.

    .PARAMETER DownloadServiceProviderMetadata
    If specified, downloads the SAML SSO metadata file of the Service Provider (SP, i.e., HPE GreenLake) to the specified file path. This metadata is used by Identity Providers (IdPs) like OKTA to establish trust and facilitate Single Sign-On (SSO) interactions.

    .PARAMETER WhatIf
    Displays the raw REST API call that would be executed, without actually sending the request. Useful for understanding the native REST API interactions with GLP.

    .EXAMPLE
    Get-HPEGLWorkspaceSAMLSSODomain

    Retrieves all SAML SSO domains configured in the workspace.

    .EXAMPLE
    Get-HPEGLWorkspaceSAMLSSODomain -DomainName "example.com"

    Returns the SAML SSO domain "example.com" details.

    .EXAMPLE
    Get-HPEGLWorkspaceSAMLSSODomain -DomainName "example.com" -ShowSAMLAttributes

    Retrieves the SAML attributes for the SAML SSO domain "example.com".

    .EXAMPLE
    Get-HPEGLWorkspaceSAMLSSODomain -DomainName "example.com" -ShowSPCertificate

    Returns the Service Provider (SP, i.e., HPE GreenLake) X509 certificate for the SAML SSO domain "example.com".

    .EXAMPLE
    Get-HPEGLWorkspaceSAMLSSODomain -DomainName "example.com" -ShowIDPCertificate

    Returns the Identity Provider (IdP) X509 certificate for the SAML SSO domain "example.com".

    .EXAMPLE
    Get-HPEGLWorkspaceSAMLSSODomain -DomainName "example.com" -DownloadServiceProviderMetadata "C:\path\to\metadata.xml"

    Downloads the metadata file for the SAML SSO domain "example.com" to the specified file path.

    #>

    [CmdletBinding(DefaultParameterSetName = "Default")]
    Param(
        [Parameter(ParameterSetName = "Default")]
        [Parameter(Mandatory, ParameterSetName = "DomainNameSAMLAttributes")]
        [Parameter(Mandatory, ParameterSetName = "DomainNameSP")]
        [Parameter(Mandatory, ParameterSetName = "DomainNameIDP")]
        [Parameter(Mandatory, ParameterSetName = "DomainNameMetadataDownload")]
        [String]$DomainName,

        [Parameter(ParameterSetName = "DomainNameSAMLAttributes")]
        [switch]$ShowSAMLAttributes,
        
        [Parameter(ParameterSetName = "DomainNameSP")]
        [switch]$ShowSPCertificate,

        [Parameter(ParameterSetName = "DomainNameIDP")]
        [switch]$ShowIDPCertificate,

        [Parameter(ParameterSetName = "DomainNameMetadataDownload")]
        [String]$DownloadServiceProviderMetadata,

        [Switch]$WhatIf
    )

    Begin {
        $Caller = (Get-PSCallStack)[1].Command
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
    }

    Process {

        # DEPRECATION WARNING
        Write-Warning "[DEPRECATED] This function is deprecated. Use 'Get-HPEGLDomain' and 'Get-HPEGLSSOConnection' instead. This function is maintained for IAMv1 workspace compatibility only and will be removed in a future release."

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $ReturnData = [System.Collections.ArrayList]::new()
        
        $Uri = Get-AuthnSAMLSSOUri
        

        try {
          
            [Array]$Collection = Invoke-HPEGLWebRequest -Method GET -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }


        if ($Collection.domains.count -gt 0) {

            $Collection = $Collection.domains
        }     
        else {
            $Collection = $Null
        }
        

        if ($Null -ne $Collection ) {

            if ($DomainName) {
                
                $DomainFound = $Collection | Where-Object domain -eq $DomainName

                if (($DomainFound -or ($DomainFound -and $ShowIDPCertificate)) -and -not $ShowSAMLAttributes -and -not $ShowSPCertificate -and -not $DownloadServiceProviderMetadata) {

                    $Uri = (Get-AuthnSAMLSSOUri) + "/" + $DomainName

                    [Array]$Collection = Invoke-HPEGLWebRequest -Method GET -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

                    if ($ShowIDPCertificate) {

                        $certBase64 = $Collection.saml_idp_config.signing_certificate

                        $pemCert = "-----BEGIN CERTIFICATE-----`n"
                        $pemCert += ($certBase64 -split '(.{64})' | Where-Object { $_ }) -join "`r`n"
                        $pemCert += "`n-----END CERTIFICATE-----"
                        return $pemCert

                    }
                    else {
                        
                        $ReturnData = Invoke-RepackageObjectWithType -RawObject $Collection -ObjectName "Workspace.SAML.Domain.Details"    
                    }

                    return $ReturnData  

                }
                elseif ($DomainFound -and $ShowSAMLAttributes) {
                    
                    $Uri = (Get-SAMLAttributesUri) + $DomainFound.domain
                    
                    try {
                        $SAMLAttributes = (Invoke-HPEGLWebRequest -Method GET -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference)
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }

                    if ($SAMLAttributes) {

                        # Add the GLP application to the applications property as it does not exist
                        $GLP_object = [PSCustomObject]@{
                            application_id   = "00000000-0000-0000-0000-000000000000"
                            application_name = "HPE GreenLake platform"
                        }

                        $SAMLAttributes.applications += $GLP_object

                        # Add the missing properties to each applications item
                        foreach ($currentItemName in $SAMLAttributes.applications) {
                            $currentItemName | Add-Member -Type NoteProperty -Name "entity_id" -Value $SAMLAttributes.entity_id	
                            $currentItemName | Add-Member -Type NoteProperty -Name "sign_on_url" -Value $SAMLAttributes.sign_on_url		
                            $currentItemName | Add-Member -Type NoteProperty -Name "platform_customer_id" -Value $SAMLAttributes.platform_customer_id			
                        }

                        $ReturnData = Invoke-RepackageObjectWithType -RawObject $SAMLAttributes.applications -ObjectName "Workspace.SAML.Attributes"    

                        return $ReturnData

                    }
                    else {

                        return

                    }

                }
                elseif ($DomainFound -and ($DownloadServiceProviderMetadata -or $ShowSPCertificate)) {

                    $Uri = (Get-AuthnSAMLSSOMetadataUri) + $DomainFound.domain

                    try {
                        [string]$MetadataURL = (Invoke-HPEGLWebRequest -Method GET -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference).metadata_url
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }
        
                    if ($MetadataURL) {
    
                        [xml]$MetadataFile = Invoke-WebRequest -Method GET -Uri $MetadataURL
        
                        if ($ShowSPCertificate) {
                            $certBase64 = $MetadataFile.EntityDescriptor.SPSSODescriptor.KeyDescriptor.KeyInfo.X509Data.X509Certificate
                            $pemCert = "-----BEGIN CERTIFICATE-----`n"
                            $pemCert += ($certBase64 -split '(.{64})' | Where-Object { $_ }) -join "`r`n"
                            $pemCert += "`n-----END CERTIFICATE-----"
                            return $pemCert
                        }
                        elseif ($DownloadServiceProviderMetadata) {
                            $MetadataFile.Save($DownloadServiceProviderMetadata)
                            Write-Output "Metadata file '$DownloadServiceProviderMetadata' successfully downloaded." 
                        }
                        else {
                            return $MetadataFile
                        }
                    }
                    else {
                        return
                    }
    
                }
                elseif (($DownloadServiceProviderMetadata -or $ShowSPCertificate -or $ShowSAMLAttributes -or $ShowIDPCertificate) -and -not $DomainFound) {

                    "[{0}] SAML SSO Domain '{1}' cannot be found!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DomainName | Write-Verbose
        
                    $ErrorMessage = "SAML SSO Domain '{0}': Resource cannot be found in the workspace!" -f $DomainName
                    Write-Warning $ErrorMessage
                    return
                }
                else {

                    return

                }
                
            }            
            else {
                
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $Collection -ObjectName "Workspace.SAML.Domain"    
                
                $ReturnData = $ReturnData | Sort-Object { $_.domain }
                
                return $ReturnData  

            }
        }    
        else {
            Return
        } 
    }
}

Function New-HPEGLWorkspaceSAMLSSODomain {
    # [DEPRECATED] Use New-HPEGLDomain + New-HPEGLSSOConnection instead
    <#
    .SYNOPSIS
    Adds a SAML SSO domain to the workspace.

    .DESCRIPTION
    [DEPRECATED] This function is deprecated and maintained only for IAMv1 workspace compatibility. It will be removed in a future release.
    
    For IAMv2 workspaces, use 'New-HPEGLDomain' to create a domain and 'New-HPEGLSSOConnection' to configure the SSO connection.
    
    Configures a SAML SSO domain in the workspace to enable Single Sign-On (SSO). The SSO connection can be used for authentication only or can also provide role information via the SAML response.
    
    The SAML SSO domain must be a private domain that you own, such as example.com, mycompany.com, or mydomain.com. Public domains like facebook.com, gmail.com, outlook.com, or yahoo.com cannot be used to configure SSO. 
    
    The domain must have at least one verified user belonging to it defined in the workspace.
    
    .PARAMETER DomainName
    Specifies the name of the SAML SSO domain to create. There must be at least one verified user belonging to the domain.

    .PARAMETER AuthorizationMethod
    Specifies the authorization method for the SAML SSO domain. Supported values are "SAML" or "Locally-managed".
    - SAML: Use the SSO SAML response for session-based authorization.
    - Locally-managed: Manage authorization locally via the GreenLake Platform.

    .PARAMETER MetadataSource
    Specifies the source of the metadata file for the SAML SSO domain. The metadata file can be provided as a file path or a URL. The metadata file must be in XML format.

    .PARAMETER EmailAttribute
    Optional attribute to set the email mapping attribute. The default value is "NameId", which is commonly used by identity providers.

    .PARAMETER FirstNameAttribute
    Optional attribute to set the first name mapping attribute. The default value is "FirstName", which is commonly used by identity providers. Set this attribute if your identity provider uses a different attribute. If your identity provider does not have SAML attributes for these values, you can ignore this parameter.

    .PARAMETER LastNameAttribute
    Optional attribute to set the last name mapping attribute. The default value is "LastName", which is commonly used by identity providers. Set this attribute if your identity provider uses a different attribute. If your identity provider does not have SAML attributes for these values, you can ignore this parameter.

    .PARAMETER GreenLakeAttribute
    SAML attribute name for the HPE GreenLake attribute. This is required when SAML is being used for authorization. The default value is "hpe_ccs_attribute".

    .PARAMETER IdleSessionTimeout
    Specifies the amount of time in minutes a user can be inactive before a session ends. Idle time cannot exceed 1,440 minutes (24 hours).

    .PARAMETER RecoveryUserPassword
    Specifies the recovery user password. The password must be at least 8 characters long and include upper-case, lower-case, number, and symbol.

    .PARAMETER PointOfContactEmail
    Specifies the point of contact email that will be used to regain access to your account if you forget your password.

    .PARAMETER DisableRecoveryUser
    Disables the recovery user for the SAML SSO domain.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    $PlainTextPassword = "YourPlainTextPassword!10"
    $SecurePassword = ConvertTo-SecureString -String $PlainTextPassword -AsPlainText -Force
    New-HPEGLWorkspaceSAMLSSODomain -DomainName "example.com" -AuthorizationMethod SAML -MetadataSource "C:\Documents\federationmetadata.xml" -RecoveryUserSecurePassword $SecurePassword -PointOfContactEmail leonhard.euler@mathematician.com
    
    Adds a new SAML SSO domain named "example.com" with a specified metadata file provided as a file path, a recovery user password, and a point of contact email. The SAML SSO domain is configured for SAML-based authorization, i.e., the SSO SAML response defines the session-based authorization.

    .EXAMPLE
    New-HPEGLWorkspaceSAMLSSODomain -DomainName "example.com" -AuthorizationMethod Locally-managed -MetadataSource "https://example.com/federationmetadata/2007-06/federationmetadata.xml" -RecoveryUserSecurePassword $SecurePassword -PointOfContactEmail leonhard.euler@mathematician.com
    
    Adds a new SAML SSO domain named "example.com" with the specified metadata file provided as a URL, a recovery user password, and a point of contact email. The SAML SSO domain is configured for locally-managed authorization, i.e., authorization is managed locally via the GreenLake Platform.

    .EXAMPLE
    New-HPEGLWorkspaceSAMLSSODomain -DomainName "example.com" -AuthorizationMethod Locally-managed -MetadataSource "https://example.com/federationmetadata/2007-06/federationmetadata.xml" -DisableRecoveryUser
    
    Adds a new SAML SSO domain named "example.com" with the specified metadata file provided as a URL and disables the recovery user for the SAML SSO domain. The SAML SSO domain is configured for locally-managed authorization, i.e., authorization is managed locally via the GreenLake Platform.

    .INPUTS
    Pipeline input is not supported.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following keys:
        * Name - The name of the SAML SSO domain to add.
        * RecoveryUserEmail - The email of the generated recovery user (if not disabled).
        * Status - The status of the creation attempt (Failed for HTTP error return; Complete if deployment is successful; Warning if no action is needed).
        * Details - More information about the status.
        * Exception - Information about any exceptions generated during the operation.
#>

    [CmdletBinding(DefaultParameterSetName = "MetadataFileEnableRecoveryUser")]
    Param( 

        [Parameter (Mandatory, ParameterSetName = "MetadataFileEnableRecoveryUser")]
        [Parameter (Mandatory, ParameterSetName = "MetadataFileDisableRecoveryUser")]
        [String]$DomainName,

        [Parameter (Mandatory)]
        [ValidateSet("SAML", "Locally-managed")]
        [String]$AuthorizationMethod,

        [Parameter (Mandatory, ValueFromPipeline, ParameterSetName = "MetadataFileEnableRecoveryUser")]
        [Parameter (Mandatory, ValueFromPipeline, ParameterSetName = "MetadataFileDisableRecoveryUser")]
        [String]$MetadataSource,

        [String]$EmailAttribute = "NameId", 
        
        [String]$FirstNameAttribute = "FirstName",
        
        [String]$LastNameAttribute = "LastName",
        
        [String]$GreenLakeAttribute = "hpe_ccs_attribute",

        [ValidateScript({
                if ($_ -le 1440) {
                    $true
                }
                else {
                    throw "Idle time cannot exceed 1,440 minutes (24 hours)."
                }
            })]
        [Int]$IdleSessionTimeout = 60,

        [Parameter (Mandatory, ParameterSetName = "MetadataFileEnableRecoveryUser")]
        [SecureString]$RecoveryUserSecurePassword,

        [Parameter (Mandatory, ParameterSetName = "MetadataFileEnableRecoveryUser")]
        [validatescript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$PointOfContactEmail,

        [Parameter (Mandatory, ParameterSetName = "MetadataFileDisableRecoveryUser")]
        [switch]$DisableRecoveryUser,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-ApplicationProvisioningUri

        $AddSAMLSSODomainStatus = [System.Collections.ArrayList]::new()

        
        
    }
    
    Process {
        
        # DEPRECATION WARNING
        Write-Warning "[DEPRECATED] This function is deprecated. Use 'New-HPEGLDomain' and 'New-HPEGLSSOConnection' instead. This function is maintained for IAMv1 workspace compatibility only and will be removed in a future release."

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        if ($RecoveryUserSecurePassword) {

            # Convert SecureString to plain text
            $RecoveryUserPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($RecoveryUserSecurePassword))
            
            if ($RecoveryUserPassword -notmatch '^(?=.*[a-z])(?=.*[A-Z])(?=.*\d)(?=.*[\W_]).{8,}$') {
                throw "The recovery user password must be at least 8 characters long and include upper-case, lower-case, number, and symbol."
            }
        }
        
        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Name              = $DomainName
            RecoveryUserEmail = $Null
            Status            = $Null
            Details           = $Null
            Exception         = $Null
                                  
        }      

        # Validate domain name
        try {

            "[{0}] Validating SAML SSO domain '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DomainName | Write-Verbose

            $Uri = (Get-SAMLValidateDomainUri) + $DomainName
            $ValidateDomain = Invoke-HPEGLWebRequest -Uri $Uri -method 'Get' 

        }
        catch { 

            if ($_ -match "Error status Code: 412") {

                if ($WhatIf) {
                    $ErrorMessage = "Domain {0} already claimed by the user for the workspace" -f $DomainName
                    Write-warning $ErrorMessage
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Domain {0} already claimed by the user for the workspace" -f $DomainName }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData

                }
            }
        }
        
        if ($ValidateDomain.message -ne "Domain valid." -or $objStatus.Status -eq "Failed") {

            # Must return a message if domain is not valid 
            "[{0}] SAML SSO domain '{1}' is not valid!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DomainName | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "SAML SSO domain '{0}' is not valid! Error: {1}" -f $DomainName, $ValidateDomain.message
                Write-warning $ErrorMessage
                return
            }
            else {

                if ($objStatus.Status -ne "Failed") {

                    $objStatus.Status = "Failed"
                    $objStatus.Details = "SAML SSO domain is not valid!"
                    $objStatus.Exception = $ValidateDomain.message
                }
            }
        }
        else {

            $FileFound = $false

            # Check if the MetadataSource is a URL
            if ($MetadataSource -match '^https?://') {

                "[{0}] MetadataSource detected as a URL" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                # Read the XML file from the URL
                try {
                    [xml]$MetadataXMLFile = Invoke-WebRequest -Uri $MetadataSource -UseBasicParsing -Method Get -ContentType 'application/xml' | Select-Object -ExpandProperty Content
                    
                    "[{0}] MetadataSource file has been found!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                    $FileFound = $True
                }
                catch {
                    $MetadataXMLFile = $Null
                }

            }
            else {

                "[{0}] MetadataSource detected as a file" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                # Test the path of the XML file 
                $FileFound = Test-Path -Path $MetadataSource

                if ($FileFound -eq $True) {

                    "[{0}] MetadataSource file has been found!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                    [xml]$MetadataXMLFile = Get-Content $MetadataSource -Raw

                }
            }
        

            if ($FileFound -eq $False) {

                "[{0}] Error! MetadataSource cannot be found!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                # Must return a message if Metadata file is not found
                if ($WhatIf) {
                    $ErrorMessage = "Metadata XML file cannot be found at '{0}'" -f $MetadataSource
                    Write-warning $ErrorMessage
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Metadata file cannot be found at $MetadataSource"
                }                

            } 
            else {
                
                "[{0}] Metadata file content: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $MetadataXMLFile | Write-Verbose
    
                $EntityID = $MetadataXMLFile.EntityDescriptor.entityID
                $LoginURL = $MetadataXMLFile.EntityDescriptor.IDPSSODescriptor.SingleSignOnService | Where-Object { $_.Binding -eq "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" } | Select-Object -ExpandProperty Location
                $LogoutURL = $MetadataXMLFile.EntityDescriptor.IDPSSODescriptor.SingleLogoutService | Where-Object { $_.Binding -eq "urn:oasis:names:tc:SAML:2.0:bindings:HTTP-Redirect" } | Select-Object -ExpandProperty Location
                $SigningCertificate = $MetadataXMLFile.EntityDescriptor.IDPSSODescriptor.KeyDescriptor | Where-Object { $_.use -eq "signing" } | Select-Object -ExpandProperty KeyInfo | Select-Object -ExpandProperty X509Data | Select-Object -ExpandProperty X509Certificate

           
                # Valid metadata file
    
                $SamlIDPConfig = [PSCustomObject]@{
                    entity_id           = $EntityID
                    login_url           = $LoginURL
                    logout_url          = $LogoutURL
                    signing_certificate = $SigningCertificate
                   
                }
                
                $Payload = $SamlIDPConfig | ConvertTo-Json -Depth 5
    
                try {
                    $Uri = (Get-SAMLValidateMetadataUri) + $DomainName
                    $ValidateMetadata = Invoke-HPEGLWebRequest -Uri $Uri -method 'Post' -ContentType application/json -Body $Payload
        
                }
                catch {    
                    $PSCmdlet.ThrowTerminatingError($_)
            
                }
    
                if ($ValidateMetadata.message -ne "Metadata Valid") {
                    # Must return a message if domain is not valid 
                    "[{0}] Metadata is not valid!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
        
                    if ($WhatIf) {
                        $ErrorMessage = "Metadata is not valid! Message: {1} - Error code: {2}" -f $ValidateMetadata.message, $ValidateMetadata.error_code
                        Write-warning $ErrorMessage
                        return
                    }
                    else {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Metadata is not valid! Message: {0}" -f $ValidateMetadata.message
                        $objStatus.Exception = $ValidateMetadata.error_code
                    }
                }
                else {
    
                    if ($AuthorizationMethod -eq "SAML") {
                        
                        $SSOMode = "AUTHORIZATION"
                    }
                    else {
                        $SSOMode = "AUTHENTICATION_ONLY"
                    }
    
    
                    if ($DisableRecoveryUser) {

                        if ($AuthorizationMethod -eq "Locally-Managed") {
                            
                            $Payload = [PSCustomObject]@{
                                domain               = $DomainName
                                authorization_method = $AuthorizationMethod
                                saml_idp_config      = $SamlIDPConfig
                                attribute_mapping    = @{
                                    email                = $EmailAttribute
                                    first_name           = $FirstNameAttribute
                                    last_name            = $LastNameAttribute
                                    idle_session_timeout = $IdleSessionTimeout
                                }
                                recovery_user        = $Null
                                sso_mode             = $SSOMode
        
                            } | ConvertTo-Json -Depth 5
                        }
                        else {

                            $Payload = [PSCustomObject]@{
                                domain               = $DomainName
                                authorization_method = $AuthorizationMethod
                                saml_idp_config      = $SamlIDPConfig
                                attribute_mapping    = @{
                                    email                = $EmailAttribute
                                    first_name           = $FirstNameAttribute
                                    last_name            = $LastNameAttribute
                                    idle_session_timeout = $IdleSessionTimeout
                                    hpe_ccs_attribute    = $GreenLakeAttribute
                                }
                                recovery_user        = $Null
                                sso_mode             = $SSOMode
        
                            } | ConvertTo-Json -Depth 5
                        }
                    }
                    else {
    
                        # Create recovery user email account using workspace ID       
                        $RecoveryUserEmail = "sso_re_" + $Global:HPEGreenLakeSession.workspaceId + "@" + $DomainName
    
                        $objStatus.RecoveryUserEmail = $RecoveryUserEmail

                        if ($AuthorizationMethod -eq "Locally-Managed") {

                            $Payload = [PSCustomObject]@{
                                domain               = $DomainName
                                authorization_method = $AuthorizationMethod
                                saml_idp_config      = $SamlIDPConfig
                                attribute_mapping    = @{
                                    email                = $EmailAttribute
                                    first_name           = $FirstNameAttribute
                                    last_name            = $LastNameAttribute
                                    idle_session_timeout = $IdleSessionTimeout
                                }
                                recovery_user        = @{
                                    username       = $RecoveryUserEmail
                                    password       = $RecoveryUserPassword
                                    recovery_email = $PointOfContactEmail
                                    
                                }
                                sso_mode             = $SSOMode
                            } | ConvertTo-Json -Depth 5
                        }
                        else {
                            
                            $Payload = [PSCustomObject]@{
                                domain               = $DomainName
                                authorization_method = $AuthorizationMethod
                                saml_idp_config      = $SamlIDPConfig
                                attribute_mapping    = @{
                                    email                = $EmailAttribute
                                    first_name           = $FirstNameAttribute
                                    last_name            = $LastNameAttribute
                                    idle_session_timeout = $IdleSessionTimeout
                                    hpe_ccs_attribute    = $GreenLakeAttribute
                                }
                                recovery_user        = @{
                                    username       = $RecoveryUserEmail
                                    password       = $RecoveryUserPassword
                                    recovery_email = $PointOfContactEmail
                                    
                                }
                                sso_mode             = $SSOMode
                            } | ConvertTo-Json -Depth 5
                        }        
                    }
        
                    $Uri = Get-AuthnSAMLSSOConfigUri 
    
    
                    try {
    
                        $counter = 1
    
                        # Define the spinning cursor characters
                        $spinner = @('|', '/', '-', '\')
                        
                        # Get the current width of the terminal window                
                        $terminalWidth = (Get-Host).UI.RawUI.WindowSize.Width                    
                        
                        # Create a clear line string based on the terminal width to ensure the entire line is overwritten
                        if (-not $psISE) {
                            $clearLine = " " * ($terminalWidth - 1)
                        }   
    
                        $Response = Invoke-HPEGLWebRequest -Method 'POST' -Body $Payload -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

                        if (-not $WhatIf) {

                            $TaskTrackingId = $Response.task_tracking_id

                            $Uri = (Get-AuthnSAMLSSOConfigTaskTrackerUri) + $TaskTrackingId

                            do {
            
                                $subcounter = 0
            
                                do {
            
                                    $TaskTrackingStatus = Invoke-HPEGLWebRequest -Uri $Uri -method GET 
            
                                    # Calculate the current spinner character
                                    $spinnerChar = $spinner[$subcounter % $spinner.Length]
                                    
                                    # Display the spinner character, replacing the previous content
                                    $output = "Adding SAML SSO domain '{0}' to the workspace: {1} {2}" -f $DomainName, $TaskTrackingStatus.Status, $spinnerChar
            
                                    if (-not $psISE) {
                                        Write-Host "`r$clearLine`r$output" -NoNewline -ForegroundColor Yellow
                                    }
                                    else {
                                        Write-Host "$output" -ForegroundColor Yellow
                                    }
            
                                    $subcounter++
                                    Start-Sleep -Seconds 1
                                    
                                    
                                } while (
                                    $TaskTrackingStatus.Status -eq "IN_PROGRESS"
                                )
            
                                # Increment counter
                                $counter++
            
                            } until ($TaskTrackingStatus.Status -eq "DONE" -or $counter -gt 10)       
        
                            # Clear the message after do/until is complete
                            if (-not $psISE) {
                                "`r$clearLine`r" | Write-Host -NoNewline                    
                            }
                            
                            if ($counter -gt 10) {
                                
                                $objStatus.Status = "Failed"
                                $objStatus.Details = "Failed to add the SAML SSO domain to the workspace."
        
                            }
                            else {
        
                                "[{0}] Adding SAML SSO domain '{1}' to the workspace... status: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DomainName, $TaskTrackingStatus.Status | Write-Verbose
                                
                                if (-not $WhatIf) {
        
                                    $objStatus.Status = $TaskTrackingStatus.status
                                    $objStatus.Details = $TaskTrackingStatus.response.data.message
                                    
                                }
                            }
                        }    
                    }
                    catch {
    
                        if (-not $WhatIf) {
    
                            # Clear the message after do/until is complete
                            if (-not $psISE) {
                                "`r$clearLine`r" | Write-Host -NoNewline                    
                            }
        
                            $objStatus.Status = "Failed"
                            $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Failed to add the SAML SSO domain to the workspace." }
                            $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                        }
                    }   
                }
            }
        }

        [void] $AddSAMLSSODomainStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            $AddSAMLSSODomainStatus = Invoke-RepackageObjectWithType -RawObject $AddSAMLSSODomainStatus -ObjectName "ObjStatus.NRSDE" 
            Return $AddSAMLSSODomainStatus
        }
    }
}

Function Set-HPEGLWorkspaceSAMLSSODomain {
    # [DEPRECATED] Use Set-HPEGLSSOConnection instead
    <#
    .SYNOPSIS
    Sets details of the SAML SSO domain.

    .DESCRIPTION
    [DEPRECATED] This function is deprecated and maintained only for IAMv1 workspace compatibility. It will be removed in a future release.
    
    For IAMv2 workspaces, use 'Set-HPEGLSSOConnection' to modify SSO connection settings.
    
    This function modifies the SAML SSO information of a domain configured in the workspace. It can set the SAML attributes, upload the metadata file for a specified domain, and update the X509 certificate if requested.

    .PARAMETER DomainName
    Specifies the name of the SAML SSO domain to set.

    .PARAMETER X509Certificate
    Specifies the new X509 certificate for the specified domain.

    .PARAMETER EmailAttribute
    Specifies the new email address attribute for the specified domain.

    .PARAMETER FirstNameAttribute
    Specifies the new first name attribute for the specified domain.

    .PARAMETER LastNameAttribute
    Specifies the new last name attribute for the specified domain.

    .PARAMETER GreenLakeAttribute
    Specifies the new HPE GreenLake attribute for the specified domain.

    .PARAMETER IdleSessionTimeout
    Specifies the new idle session timeout attribute for the specified domain.

    .PARAMETER LoginURL
    Specifies the new login URL for the specified domain.

    .PARAMETER LogoutURL
    Specifies the new logout URL for the specified domain.

    .PARAMETER WhatIf
    Displays the raw REST API call that would be executed, without actually sending the request. Useful for understanding the native REST API interactions with GLP.

    .EXAMPLE
    $certificate = "MIIE5DCCAsygAwIBAgIQUK3zqnGiHrNBkAvI5tS8bDANBgkqhkiG9w0BAQsFADAuMSwwKgYDVQQDEyN....xkUqNXSHY="
    Set-HPEGLWorkspaceSAMLSSODomain -DomainName "example.com" -X509Certificate $certificate

    Sets the new X509 certificate for the SAML SSO domain "example.com".

    .EXAMPLE
    Set-HPEGLWorkspaceSAMLSSODomain -DomainName "example.com" -EmailAttribute "email"

    Sets the new email address attribute for the SAML SSO domain "example.com".

    .EXAMPLE
    Set-HPEGLWorkspaceSAMLSSODomain -DomainName "example.com" -FirstNameAttribute "FirstName"

    Sets the new first name attribute for the SAML SSO domain "example.com".

    .EXAMPLE
    Set-HPEGLWorkspaceSAMLSSODomain -DomainName "example.com" -LastNameAttribute "LastName"

    Sets the new last name attribute for the SAML SSO domain "example.com".

    .EXAMPLE
    Set-HPEGLWorkspaceSAMLSSODomain -DomainName "example.com" -GreenLakeAttribute "GreenLakeAttribute"

    Sets the new HPE GreenLake attribute for the SAML SSO domain "example.com".

    .EXAMPLE
    Set-HPEGLWorkspaceSAMLSSODomain -DomainName "example.com" -IdleSessionTimeout 30

    Sets the new idle session timeout attribute for the SAML SSO domain "example.com".

    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory)]
        [String]$DomainName,

        [String]$X509Certificate,

        [String]$EmailAttribute,

        [String]$FirstNameAttribute,

        [String]$LastNameAttribute,

        [String]$GreenLakeAttribute,

        [String]$LoginURL,

        [String]$LogoutURL,

        [Int]$IdleSessionTimeout,

        [Switch]$WhatIf
    )

    Begin {
       
        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $ObjectStatusList = [System.Collections.ArrayList]::new()

    }

    Process {

        # DEPRECATION WARNING
        Write-Warning "[DEPRECATED] This function is deprecated. Use 'Set-HPEGLSSOConnection' instead. This function is maintained for IAMv1 workspace compatibility only and will be removed in a future release."

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name      = $DomainName
            Status    = $Null
            Details   = $Null
            Exception = $Null
                          
        }
        

        [void] $ObjectStatusList.add($objStatus)

    }

    end {

        try {
            
            $DomainFound = Get-HPEGLWorkspaceSAMLSSODomain -DomainName $DomainName -WarningAction SilentlyContinue
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }
        
        
        foreach ($Object in $ObjectStatusList) {
            
            $Uri = Get-AuthnSAMLSSOConfigUri

            if (-not $DomainFound) {

                # Must return a message if domain not found
                $Object.Status = "Failed"
                $Object.Details = "SAML SSO domain cannot be found in the workspace!"

                if ($WhatIf) {
                    $ErrorMessage = "SAML SSO domain '{0}': Resource cannot be found in the workspace!" -f $Object.Name
                    Write-warning $ErrorMessage
                    continue
                }

            }
            else {

                if ($PSBoundParameters.ContainsKey('EmailAttribute')) {

                    $DomainFound.attribute_mapping.email = $EmailAttribute
                
                }

                if ($PSBoundParameters.ContainsKey('FirstNameAttribute')) {

                    $DomainFound.attribute_mapping.first_name = $FirstNameAttribute
                
                }

                if ($PSBoundParameters.ContainsKey('LastNameAttribute')) {

                    $DomainFound.attribute_mapping.last_name = $LastNameAttribute
                
                }

                if ($PSBoundParameters.ContainsKey('GreenLakeAttribute')) {

                    $DomainFound.attribute_mapping.hpe_ccs_attribute = $GreenLakeAttribute
                
                }

                if ($PSBoundParameters.ContainsKey('IdleSessionTimeout')) {

                    $DomainFound.attribute_mapping.idle_session_timeout = $IdleSessionTimeout
                
                }

                if ($PSBoundParameters.ContainsKey('X509Certificate')) {

                    $DomainFound.saml_idp_config.signing_certificate = $X509Certificate
                
                }
      
                if ($PSBoundParameters.ContainsKey('LoginURL')) {

                    $DomainFound.saml_idp_config.login_url = $LoginURL
                
                }
      
                if ($PSBoundParameters.ContainsKey('LogoutURL')) {

                    $DomainFound.saml_idp_config.logout_url = $LogoutURL
                
                }

                
                $DomainFound | Add-Member -Type NoteProperty -Name "auth_method" -Value "SAML / SSO"
                $DomainFound | Add-Member -Type NoteProperty -Name "edited" -Value $True
                
                # Exclude the PSObject.TypeNames property
                $DomainFound = $DomainFound | Select-Object -Property * -ExcludeProperty PSObject.TypeNames

                $Payload = $DomainFound | ConvertTo-Json -Depth 5

                try {

                    $counter = 1
    
                    # Define the spinning cursor characters
                    $spinner = @('|', '/', '-', '\')
                    
                    # Get the current width of the terminal window                
                    $terminalWidth = (Get-Host).UI.RawUI.WindowSize.Width                    
                    
                    # Create a clear line string based on the terminal width to ensure the entire line is overwritten
                    if (-not $psISE) {
                        $clearLine = " " * ($terminalWidth - 1)
                    }   
                    
                    $Response = Invoke-HPEGLWebRequest -Method PUT -Uri $Uri -Body $Payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

                    if (-not $WhatIf) {

                        $TaskTrackingId = $Response.task_tracking_id

                        $Uri = (Get-AuthnSAMLSSOConfigTaskTrackerUri) + $TaskTrackingId

                        do {
        
                            $subcounter = 0
        
                            do {
        
                                $TaskTrackingStatus = Invoke-HPEGLWebRequest -Uri $Uri -method GET 
        
                                # Calculate the current spinner character
                                $spinnerChar = $spinner[$subcounter % $spinner.Length]
                                
                                # Display the spinner character, replacing the previous content
                                $output = "Setting SAML SSO domain '{0}': {1} {2}" -f $DomainName, $TaskTrackingStatus.Status, $spinnerChar
        
                                if (-not $psISE) {
                                    Write-Host "`r$clearLine`r$output" -NoNewline -ForegroundColor Yellow
                                }
                                else {
                                    Write-Host "$output" -ForegroundColor Yellow
                                }
        
                                $subcounter++
                                Start-Sleep -Seconds 1
                                
                                
                            } while (
                                $TaskTrackingStatus.Status -eq "IN_PROGRESS"
                            )
        
                            # Increment counter
                            $counter++
        
                        } until ($TaskTrackingStatus.Status -eq "DONE" -or $counter -gt 10)       
    
                        # Clear the message after do/until is complete
                        if (-not $psISE) {
                            "`r$clearLine`r" | Write-Host -NoNewline                    
                        }
                        
                        if ($counter -gt 10) {
                            
                            $objStatus.Status = "Failed"
                            $objStatus.Details = "Failed to set the SAML SSO domain."
    
                        }
                        else {
    
                            "[{0}] SAML SSO domain '{1}' successfully updated. Status: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DomainName, $TaskTrackingStatus.Status | Write-Verbose
                            
                            if (-not $WhatIf) {
    
                                $objStatus.Status = $TaskTrackingStatus.status
                                $objStatus.Details = $TaskTrackingStatus.response.data.message
                                
                            }
                        }
                    }
                }
                catch {

                    if (-not $WhatIf) {

                        # Clear the message after do/until is complete
                        if (-not $psISE) {
                            "`r$clearLine`r" | Write-Host -NoNewline                    
                        }

                        $Object.Status = "Failed"
                        $Object.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "SAML SSO domain cannot be updated!" }
                        $Object.Exception = $_.Exception.message 
                    }
                }
            }
        }

        if (-not $WhatIf) {

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "ObjStatus.NSDE" 
            Return $ObjectStatusList
        }
    }
}

Function Remove-HPEGLWorkspaceSAMLSSODomain {
    # [DEPRECATED] Use Remove-HPEGLDomain + Remove-HPEGLSSOConnection instead
    <#
    .SYNOPSIS
    Removes a SAML SSO domain.

    .DESCRIPTION
    [DEPRECATED] This function is deprecated and maintained only for IAMv1 workspace compatibility. It will be removed in a future release.
    
    For IAMv2 workspaces, use 'Remove-HPEGLDomain' to remove a domain and 'Remove-HPEGLSSOConnection' to remove the SSO connection.
    
    This function removes a SAML SSO domain from the workspace. It can remove the domain by name or by the domain object.

    .PARAMETER DomainName
    Specifies the name of the SAML SSO domain to remove.

    .PARAMETER WhatIf
    Displays the raw REST API call that would be executed, without actually sending the request. Useful for understanding the native REST API interactions with GLP.

   .EXAMPLE
    Remove-HPEGLWorkspaceSAMLSSODomain -DomainName "example.com"

    Removes the SAML SSO domain "example.com" from the workspace.

    .EXAMPLE
    Get-HPEGLWorkspaceSAMLSSODomain -DomainName "example.com" | Remove-HPEGLWorkspaceSAMLSSODomain 

    Removes the SAML SSO domain "example.com" from the workspace.
    
    .INPUTS
    System.Collections.ArrayList
        A list of domains obtained from 'Get-HPEGLWorkspaceSAMLSSODomain'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following keys:
        * Name - The name of the SAML SSO domain attempted to be removed.
        * Status - The status of the removal attempt (Failed for HTTP error return; Complete if removal is successful).
        * Details - More information about the status.
        * Exception - Information about any exceptions generated during the operation.

    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [alias("domain")]
        [String]$DomainName,

        [Switch]$WhatIf
    )

    Begin {
       
        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $RemoveSAMLSSODomainStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        # DEPRECATION WARNING
        Write-Warning "[DEPRECATED] This function is deprecated. Use 'Remove-HPEGLDomain' and 'Remove-HPEGLSSOConnection' instead. This function is maintained for IAMv1 workspace compatibility only and will be removed in a future release."

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        try {
            $DomainNameFound = Get-HPEGLWorkspaceSAMLSSODomain -DomainName $DomainName -WarningAction SilentlyContinue

        }
        catch {    
            $PSCmdlet.ThrowTerminatingError($_)
        
        }

        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name      = $DomainName
            Status    = $Null
            Details   = $Null
            Exception = $Null
                          
        }

        if (-not $DomainNameFound) {
            # Must return a message if domain not present
            "[{0}] SAML SSO domain '{1}' cannot be found in the workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DomainName | Write-Verbose
        
            if ($WhatIf) {
                $ErrorMessage = "SAML SSO domain '{0}': Resource cannot be found in the workspace!" -f $DomainName
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "SAML SSO domain cannot be found in the workspace!"
            }
        }
        else {

            $Uri = (Get-AuthnSAMLSSOConfigUri) + "/" + $DomainName

            try {

                $counter = 1

                # Define the spinning cursor characters
                $spinner = @('|', '/', '-', '\')
                
                # Get the current width of the terminal window                
                $terminalWidth = (Get-Host).UI.RawUI.WindowSize.Width                    
                
                # Create a clear line string based on the terminal width to ensure the entire line is overwritten
                if (-not $psISE) {
                    $clearLine = " " * ($terminalWidth - 1)
                }


                $Response = Invoke-HPEGLWebRequest -Uri $Uri -method DELETE -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                $TaskTrackingId = $Response.task_tracking_id

                $Uri = (Get-AuthnSAMLSSOConfigTaskTrackerUri) + $TaskTrackingId

                do {

                    $subcounter = 0

                    do {

                        $TaskTrackingStatus = Invoke-HPEGLWebRequest -Uri $Uri -method GET 

                        # Calculate the current spinner character
                        $spinnerChar = $spinner[$subcounter % $spinner.Length]
                        
                        # Display the spinner character, replacing the previous content
                        $output = "Removing SAML SSO domain '{0}' from the workspace: {1} {2}" -f $DomainName, $TaskTrackingStatus.Status, $spinnerChar

                        if (-not $psISE) {
                            Write-Host "`r$clearLine`r$output" -NoNewline -ForegroundColor Yellow
                        }
                        else {
                            Write-Host "$output" -ForegroundColor Yellow
                        }

                        $subcounter++
                        Start-Sleep -Seconds 1
                        
                        
                    } while (
                        $TaskTrackingStatus.Status -eq "IN_PROGRESS"
                    )

                    # Increment counter
                    $counter++

                } until ($TaskTrackingStatus.Status -eq "DONE" -or $counter -gt 10)       
                
                # Clear the message after do/until is complete
                if (-not $psISE) {
                    "`r$clearLine`r" | Write-Host -NoNewline                    
                }
                
                if ($counter -gt 10) {
                    
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Failed to remove the SAML SSO domain from the workspace."

                }
                else {

                    "[{0}] Removing SAML SSO domain '{1}' from the workspace... status: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DomainName, $TaskTrackingStatus.Status | Write-Verbose
                    
                    if (-not $WhatIf) {

                        $objStatus.Status = $TaskTrackingStatus.status
                        $objStatus.Details = $TaskTrackingStatus.response.data.message
                        
                    }
                }
            }
            catch {

                if (-not $WhatIf) {

                    # Clear the message after do/until is complete
                    if (-not $psISE) {
                        "`r$clearLine`r" | Write-Host -NoNewline                    
                    }

                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else {"Failed to remove the SAML SSO domain from the workspace."}
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                }
            
            }   
        } 

        [void] $RemoveSAMLSSODomainStatus.add($objStatus)



    }

    end {


        if (-not $WhatIf) {

            $RemoveSAMLSSODomainStatus = Invoke-RepackageObjectWithType -RawObject $RemoveSAMLSSODomainStatus -ObjectName "ObjStatus.NSDE" 
            Return $RemoveSAMLSSODomainStatus
        }
    }
}

Function Send-HPEGLWorkspaceSAMLSSODomainNotifications {
    # [DEPRECATED] Domain notifications handled differently in IAMv2
    <#
    .SYNOPSIS
    Send a notification to all active users part of the SAML SSO domain that has been enabled in the workspace. 

    .DESCRIPTION
    [DEPRECATED] This function is deprecated and maintained only for IAMv1 workspace compatibility. It will be removed in a future release.
    
    Domain notifications are handled differently in IAMv2 workspaces through the workspace authentication policy configuration.
    
    This function sends an email to notify all active users part of a configured SAML SSO Domain that Single sign-on (SSO) has been enabled for the workspace in HPE GreenLake.
    
    .PARAMETER DomainName
    Specifies the name of the SAML SSO domain to send the notification.

    .PARAMETER WhatIf
    Displays the raw REST API call that would be executed, without actually sending the request. Useful for understanding the native REST API interactions with GLP.

   .EXAMPLE
    Send-HPEGLWorkspaceSAMLSSODomainNotifications -DomainName "example.com"

    Sends a notification to all active users part of the SAML SSO domain "example.com" that SSO has been enabled for the workspace.

    .EXAMPLE
    Get-HPEGLWorkspaceSAMLSSODomain | Send-HPEGLWorkspaceSAMLSSODomainNotifications

    Sends a notification to all active users in the various SAML SSO domains, informing them that SSO has been enabled for the workspace.

    .INPUTS
    System.Collections.ArrayList
        List of domains retrieved using 'Get-HPEGLWorkspaceSAMLSSODomain'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following keys:
        * Name - The name of the SAML SSO domain where the notification was sent.
        * Status - The status of the notification attempt (Failed for HTTP error return; Complete if successful).
        * Details - More information about the status.
        * Exception - Information about any exceptions generated during the operation.

    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [alias("domain")]
        [String]$DomainName,

        [Switch]$WhatIf
    )

    Begin {
       
        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $SAMLSSODomainNotificationStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        # DEPRECATION WARNING
        Write-Warning "[DEPRECATED] This function is deprecated. Domain notifications are handled differently in IAMv2 workspaces. This function is maintained for IAMv1 workspace compatibility only and will be removed in a future release."

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        try {
            $DomainNameFound = Get-HPEGLWorkspaceSAMLSSODomain -DomainName $DomainName -WarningAction SilentlyContinue

        }
        catch {    
            $PSCmdlet.ThrowTerminatingError($_)
        
        }

        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name      = $DomainName
            Status    = $Null
            Details   = $Null
            Exception = $Null
                          
        }

        if (-not $DomainNameFound) {
            # Must return a message if domain not present
            "[{0}] SAML SSO domain '{1}' cannot be found in the workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DomainName | Write-Verbose
        
            if ($WhatIf) {
                $ErrorMessage = "SAML SSO domain '{0}': Resource cannot be found in the workspace!" -f $DomainName
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "SAML SSO domain cannot be found in the workspace!"
            }
        }
        else {

            $Uri = (Get-AccountSAMLNotifyUsersUri) + $DomainName

            try {

                $Response = Invoke-HPEGLWebRequest -Uri $Uri -method POST -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                if ($Global:HPECOMInvokeReturnData.StatusCode -eq 204) {
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Notification sent successfully to users of the SAML SSO domain."
                } 
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Unexpected response code: $($Global:HPECOMInvokeReturnData.StatusCode)"
                }
                
            }
            catch {

                if (-not $WhatIf) {

                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Failed to send the notification to users of the SAML SSO domain." }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                }            
            }   
        } 

        [void] $SAMLSSODomainNotificationStatus.add($objStatus)



    }

    end {

        if (-not $WhatIf) {

            $SAMLSSODomainNotificationStatus = Invoke-RepackageObjectWithType -RawObject $SAMLSSODomainNotificationStatus -ObjectName "ObjStatus.NSDE" 
            Return $SAMLSSODomainNotificationStatus
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
Export-ModuleMember -Function 'Get-HPEGLWorkspace', 'New-HPEGLWorkspace', 'Set-HPEGLWorkspace', 'Remove-HPEGLWorkspace', `
    'Get-HPEGLTenantWorkspace', 'Get-HPEGLDomain', 'New-HPEGLDomain', 'Remove-HPEGLDomain', 'Get-HPEGLSSOConnection', `
    'Get-HPEGLSSOAuthenticationPolicy', 'Remove-HPEGLSSOAuthenticationPolicy', 'Remove-HPEGLSSOConnection', 'New-HPEGLSSOConnection', `
    'Set-HPEGLSSOConnection', 'Set-HPEGLSSOAuthenticationPolicy', 'New-HPEGLSSOAuthenticationPolicy', 'Test-HPEGLDomain', `
    'Get-HPEGLWorkspaceSAMLSSODomain', 'New-HPEGLWorkspaceSAMLSSODomain', 'Set-HPEGLWorkspaceSAMLSSODomain', `
    'Remove-HPEGLWorkspaceSAMLSSODomain', 'Send-HPEGLWorkspaceSAMLSSODomainNotifications' `
    -Alias *


# SIG # Begin signature block
# MIIunwYJKoZIhvcNAQcCoIIukDCCLowCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA0aFEJl3472p7q
# RjjVO9XH15+27Z2WkS5wGIJAhdmKI6CCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQgyFsfqzMueYBBTjWa025CWuy8nnlFwxAfmaB6qRaPFrMwDQYJKoZIhvcNAQEB
# BQAEggIAKwAdZniBAN60JXRKPmN6qxm7ZDqBF8nDsDzr2Cqy0cIShrYN83+JrrMv
# 2jF5DttfAcg9/EsFj+0OI440QJFeDps6zfrK0Ro0ZdM/lw7DSVPy/KrXk4bL2Gpn
# Ul+oh+7sTUetJCmRJVzFBL9+kvLWgJl08IQdi/uLc989NKeS0t5ZsDBnSVjEKtI5
# EtQWK5ENvRJWh/5dw1ntA8i6scqJrVrGBaAePxnstIXR2PmlrBk2q1HAYhgCzK4W
# Gkx/zw86sNyuTMagFAre/IAdCZ0kAe3S8llgQ4zy1yo9nVVfAumhVZ7AAZvN0NIR
# wffHDW98LC6VcQ0R8poBAYBIxlUeU8B6DRoPjeow6DZadlbNwh9iCUkxEyvih2En
# lK6ogR4S491UR5IPv+/2ktErMH7ucAtrWjMv/sgBZMOepx4tKtpQ/VT8iMsdZJvq
# Q6CS74ChY95Y+QuB3Dv4cyersJ2ZGGEL6PYP04PBXySYcuybJf+9row4RP97aXA7
# hZfIgCrtw5W9ddJH81wX6tNLy87mkXE0n7F/2Thcdrus8c8piPxZzXwdvvhDsZOr
# x8kVH6JDwDYFKaZ3Md/BM4qhgZ6E+6oCURW8mpdfYKdDqzB9jgU7gm3tarlENxQs
# 9vwtOPnRFOcT4ARlssWT1ZpYCDKZobIZJVZ8ynowyZcblzpzYYGhghjpMIIY5QYK
# KwYBBAGCNwMDATGCGNUwghjRBgkqhkiG9w0BBwKgghjCMIIYvgIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBCAYLKoZIhvcNAQkQAQSggfgEgfUwgfICAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQwkWLPckBT7LYet1hzZsh9f/H/8qe6n0uQ/f0P
# GRo2/rh66ON0LwZQ/SKCD7XbRyFgAhUAmOPDGkI7rI6ELaHcTTAhZskKUSgYDzIw
# MjYwMTMwMTA1NTMyWqB2pHQwcjELMAkGA1UEBhMCR0IxFzAVBgNVBAgTDldlc3Qg
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
# MQ8XDTI2MDEzMDEwNTUzMlowPwYJKoZIhvcNAQkEMTIEMBkyhiPDCShD5wErD2kb
# jm+3tNUUUNhf677z9DT9s2/z+4RvaA1NWfWf6LpGtbOBbTCCAXoGCyqGSIb3DQEJ
# EAIMMYIBaTCCAWUwggFhMBYEFDjJFIEQRLTcZj6T1HRLgUGGqbWxMIGHBBTGrlTk
# eIbxfD1VEkiMacNKevnC3TBvMFukWTBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMP
# U2VjdGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBUaW1lIFN0
# YW1waW5nIFJvb3QgUjQ2AhB6I67aU2mWD5HIPlz0x+M/MIG8BBSFPWMtk4KCYXzQ
# kDXEkd6SwULaxzCBozCBjqSBizCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5l
# dyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNF
# UlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNh
# dGlvbiBBdXRob3JpdHkCEDbCsL18Gzrno7PdNsvJdWgwDQYJKoZIhvcNAQEBBQAE
# ggIAVH4q0Wrj/UbtcxCo+oQ2lpRs3cqbmbqGE3pa5oXJzLqm1E7S3tizuSKJKZM2
# hmGAv8PyegcH3+XkDqjs0jM38vVMx/tvVEKUmp4CODMtceT1N4T24ctJJBYcw4Mt
# pXcX/rsbYnBIuja+hYoRYN2RPGnxz5+7KFA8bcTX19lLZ7Sfn1b5lQPnoDZXPznM
# G40xPVCO1xmyIH7olukQuE74R1sPJHAIoPwpqf4quEq8RSuresDP5XKsScKpr625
# AMT5rhMWvWj+rh7RhamxdrwNoksu9/o0bKh+bJru33D7nWai3+ic0uM9hUUM+wRL
# KMbYe/SxVxCRmKnI2cn26PF5O6QNp3oW6ccwdUf1aX3NjtDn/6NN8yDPj5/BXDVi
# mU177pj7CFUWcqiAKMBmCgvgC4lAl8TOEnQ7jx/yMQ0tFgUaaYRCDrdgLsye9vKp
# GooIqDOuLr5aAeS8fxx1XDS8lnTumcEGw2l6YthlpeGahI6qkaE/LNM7gLSEEVNF
# 3nXC+Jnpip1VMwcAbsU2IZj+vqMLjLkQ76Wflvrd/ZDJjuOxZ6zh8+mSEYWOyHoa
# qOZwjSyDOfuvpQ2fevWTB1xHeNIZ2lWA3PkqDsf5hk40e0K9y1ld0tWr/N4o06L8
# kDn4GfaBaP2donczSOdTFdI9Qa9MQzgVxDX9nXJ50CAkNGA=
# SIG # End signature block
