#------------------- FUNCTIONS FOR HPE GreenLake ORGANIZATIONS -----------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1

# Public Functions
Function Get-HPEGLOrganization {
    <#
    .SYNOPSIS
    Retrieve organization resource(s) from HPE GreenLake.

    .DESCRIPTION
    This Cmdlet returns a collection of organization resources available in HPE GreenLake. It returns both organization but also standalone IAMv2 Workspaces that are not members of an organization.

    Note: Organization governance features are available only for IAMv2 workspaces. To enable these features, make sure to create workspaces using 'New-HPEGLWorkspace' with the -EnableIAMv2Workspace parameter.

    .PARAMETER Name
    Specifies the name of an organization to retrieve.

    .PARAMETER ShowCurrent
    When specified, retrieves information about the current organization associated with the workspace you are connected to. If the current workspace is not part of any organization, no data is returned.
    
    .PARAMETER IncludeJoinEligibleOnly
    When specified, filters the results to include only organizations that are eligible to join. Organizations that are not eligible to join will be excluded from the results.
    
    .PARAMETER WhatIf
    Displays the raw REST API call that would be executed, without actually sending the request. Useful for understanding the native REST API interactions with GLP.

    .EXAMPLE
    Get-HPEGLOrganization

    Retrieves all organizations available on the HPE GreenLake platform.

    .EXAMPLE
    Get-HPEGLOrganization -ShowCurrent

    Retrieves general information about the current HPE GreenLake organization.

   .EXAMPLE
    Get-HPEGLOrganization -Name "My_organization_name"

    Retrieves detailed information about the organization named "My_organization_name".

    .EXAMPLE
    Get-HPEGLOrganization -IncludeJoinEligibleOnly

    Retrieves only organizations that are eligible to join.

    #>

    
    [CmdletBinding(DefaultParameterSetName = "Default")]
    Param( 

        [Parameter (ParameterSetName = "Default")]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Parameter (ParameterSetName = "ShowCurrent")]
        [Alias("Current")]
        [Switch]$ShowCurrent,

        [Parameter (ParameterSetName = "Default")]
        [Switch]$IncludeJoinEligibleOnly,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command
    
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $ReturnData = [System.Collections.ArrayList]::new()

        $Uri = (Get-OrganizationsListUri) + "?filter=lifecycleState eq 'ACTIVE'"
        
        # Add excludeJoinIneligible query parameter if IncludeJoinEligibleOnly is specified
        if ($IncludeJoinEligibleOnly) {
            $Uri += "&excludeJoinIneligible=true"
        }
        
        try {
            [Array]$Collection = (Invoke-HPEGLWebRequest -Method GET -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference).items
            $WorkspaceList = Get-HPEGLWorkspace
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        # Add current property to all organizations (default to False)
        $Collection | Add-Member -Type NoteProperty -Name "current" -Value $False -Force

        foreach ($Organization in $Collection) {

            $OrgManagementWorkspaceId = $Organization.associatedWorkspace.id

            try {
                $OrgManagementWorkspace = $WorkspaceList | Where-Object { $_.platform_customer_id -eq $OrgManagementWorkspaceId }

                if ($OrgManagementWorkspace) {
                    $Organization | Add-Member -MemberType NoteProperty -Name "associatedWorkspaceName" -Value $OrgManagementWorkspace.name -Force
                    $Organization.associatedWorkspace | Add-Member -MemberType NoteProperty -Name "Name" -Value $OrgManagementWorkspace.name -Force
                }
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }


        if ($Collection.Count -gt 0) {

            "[{0}] Found {1} organizations." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Collection.Count | Write-Verbose

            # Mark current organization if we have session organization ID
            if ($Global:HPEGreenLakeSession.organizationId) {
                $CurrentOrg = $Collection | Where-Object { $_.id -eq $Global:HPEGreenLakeSession.organizationId }
                if ($CurrentOrg) {
                    $CurrentOrg.current = $True
                }
            }

            if ($Name) {

                $Collection = $Collection | Where-Object name -eq $Name
            }
            elseif ($ShowCurrent) {

                $OrganizationID = $Global:HPEGreenLakeSession.organizationId
                
                if ($OrganizationID) {
                    # Step 1: Use cached organization ID from session
                    "[{0}] Retrieved organization ID from session: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $OrganizationID | Write-Verbose
                    $Collection = $Collection | Where-Object { $_.id -eq $OrganizationID }
                }
                elseif ($Global:HPEGreenLakeSession.workspaceId) {
                    # Step 2: Check if current workspace is the management workspace of an organization
                    "[{0}] Searching for organization where current workspace is the management workspace: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Global:HPEGreenLakeSession.workspaceId | Write-Verbose
                    $OrgCollection = $Collection | Where-Object { $_.associatedWorkspace.id -eq $Global:HPEGreenLakeSession.workspaceId }
                    
                    if (-not $OrgCollection) {
                        # Step 3: Check if current workspace is a member workspace of an organization
                        "[{0}] Not a management workspace. Checking if workspace is a member of any organization..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                        
                        try {
                            # Get all organization-accessible workspaces
                            $OrgWorkspacesUri = (Get-Workspacev2Uri)
                            $OrgWorkspaces = (Invoke-HPEGLWebRequest -Method GET -Uri $OrgWorkspacesUri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference)
                            
                            "[{0}] Retrieved {1} organization workspaces" -f $MyInvocation.InvocationName.ToString().ToUpper(), $OrgWorkspaces.Count | Write-Verbose
                            "[{0}] Current workspace ID: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Global:HPEGreenLakeSession.workspaceId | Write-Verbose
                            
                            # Check if current workspace exists in the organization workspaces list
                            $CurrentWorkspaceIdNormalized = $Global:HPEGreenLakeSession.workspaceId -replace '-', ''
                            $CurrentWorkspaceInOrg = $OrgWorkspaces | Where-Object { ($_.id -replace '-', '') -eq $CurrentWorkspaceIdNormalized }
                            
                            "[{0}] Current workspace in org list: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($null -ne $CurrentWorkspaceInOrg) | Write-Verbose
                            
                            if ($CurrentWorkspaceInOrg) {
                                "[{0}] Current workspace found in organization workspaces list. Determining which organization..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                
                                # Build a hash table of normalized workspace IDs from the org workspaces list for fast lookup
                                $OrgWorkspaceIdsHash = @{}
                                foreach ($ws in $OrgWorkspaces) {
                                    $normalizedId = $ws.id -replace '-', ''
                                    $OrgWorkspaceIdsHash[$normalizedId] = $true
                                }
                                
                                # Find the organization by checking if its management workspace is in the hash table
                                foreach ($Org in $Collection) {
                                    $MgmtWorkspaceIdNormalized = $Org.associatedWorkspace.id -replace '-', ''
                                    
                                    if ($OrgWorkspaceIdsHash.ContainsKey($MgmtWorkspaceIdNormalized)) {
                                        "[{0}] Found organization: {1} (ID: {2})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Org.name, $Org.id | Write-Verbose
                                        $OrgCollection = $Org
                                        break
                                    }
                                }
                            }
                        }
                        catch {
                            "[{0}] Failed to query organization workspaces: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                        }
                    }
                    
                    if (-not $OrgCollection) {
                        "[{0}] Organization not found. The workspace is not part of any organization." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                        return
                    }
                    
                    $Collection = $OrgCollection
                }
                else {
                    "[{0}] No workspace session found. Please connect with Connect-HPEGLWorkspace first." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    Write-Error -Message "No workspace session found. Please connect with Connect-HPEGLWorkspace first." -ErrorAction Stop
                }
            }

            $ReturnData = Invoke-RepackageObjectWithType -RawObject $Collection -ObjectName "Organization"

            $ReturnData = $ReturnData | Sort-Object { $_.name }
    
            return $ReturnData  
        }
        else {

            "[{0}] No organization found in the current environment." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            
            return            
        }
    }
}


Function New-HPEGLOrganization {
    <#
    .SYNOPSIS
    Creates a new organization governance policy in the current IAMv2 workspace.

    .DESCRIPTION
    This cmdlet creates a new organization governance policy in the current IAMv2 workspace. 

    If your company requires enterprise capabilities including multiple workspaces, single sign-on, and enhanced user and group management, these capabilities may be activated by creating a new organization.
    Only for when workspace is a standalone workspace and is not a member of an organization. Organization governance capabilities have not been activated.

    .PARAMETER Name
    The name of the organization to create. Maximum length is 256 characters.   
    
    .PARAMETER PhoneNumber
    Specifies the contact phone number of the workspace (optional).

    .PARAMETER Email
    Specifies the contact email address of the workspace (optional).
   
    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    New-HPEGLOrganization -Name "My_Organization" -Description "This is my organization" -PhoneNumber "+1234567890" -Email "contact@myorganization.com"

    This command creates a new organization named "My_Organization" with the provided description, phone number, and email address. The organization will be linked to the current IAMv2 workspace, which must not already belong to another organization.
    Upon successful creation, the workspace becomes the management workspace for the new organization, enabling organization governance features in HPE GreenLake.

    .INPUTS
    None. You cannot pipe objects to this Cmdlet.

    .OUTPUTS
    System.Collections.ArrayList
    A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - Name of the organization object attempted to be created 
        * Status - Status of the creation attempt (Failed for HTTP error return; Complete if the creation is successful; Warning if no action is needed) 
        * Details - More information about the status         
        * Exception: Information about any exceptions generated during the operation.
    #>
    
    [CmdletBinding()]
    Param( 

        [Parameter (Mandatory)]
        [ValidateNotNullOrEmpty()]
        [validatescript({ if ($_.Length -le 256) { $true } else { Throw "The Parameter value exceeds the maximum length of 256 characters. Please correct the value and try again." } })]
        [String]$Name,

        # The max length is 4096 characters.
        [Validatescript({ if ($_.Length -le 4096) { $true } else { Throw "The Parameter value exceeds the maximum length of 4096 characters. Please correct the value and try again." } })]
        [String]$Description,
       
        # Numbers and characters ( ) - . + and space are allowed. The max length is 30.
        [validatescript({ if ($_.Length -le 30 -and $_ -match '^[a-zA-Z0-9\s\(\)\-\.\+]*$') { $true } else { Throw "The Parameter value is not valid. Only numbers and characters ( ) - . + and space are allowed. The max length is 30. Please correct the value and try again." } })]        
        [String]$PhoneNumber,

        [validatescript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [ValidateNotNullOrEmpty()]
        [String]$Email,     
        
        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
 
        $Uri = Get-OrganizationsListUri

        $OrganizationCreationStatus = [System.Collections.ArrayList]::new()
        
    }
    
    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        try {
            
            $OrganizationFound = Get-HPEGLOrganization

            $OrganizationNameFound = $OrganizationFound | Where-Object name -eq $Name

            # $OrganizationAlreadySet = $OrganizationFound | Where-Object { $_.associatedWorkspace.id -eq $Global:HPEGreenLakeSession.workspaceId }
            
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

        if ($OrganizationNameFound) {
            
            # Must return a message if Organization found
            "[{0}] Organization '{1}' found!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "Organization '{0}': Resource already exists in HPE GreenLake! No action needed." -f $Name
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "This organization already exists in HPE GreenLake! No action needed."
            }
            
        }
        # elseif ($OrganizationAlreadySet) {
            
        #     # Must return a message if Organization already set for this workspace
        #     "[{0}] Organization already set for this workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

        #     if ($WhatIf) {
        #         $ErrorMessage = "Organization already set for this workspace! No action needed."
        #         Write-Warning "$ErrorMessage Cannot display API request."
        #         return
        #     }
        #     else {
        #         $objStatus.Status = "Warning"
        #         $objStatus.Details = "Organization already set for this workspace! No action needed."
        #     }
            
        # }
        else {           

            # Create payload  

            $Payload = [PSCustomObject]@{
                name                = $Name
                description         = $description
                email               = $Email
                phoneNumber         = $PhoneNumber
                associatedWorkspace = @{
                    id          = $Global:HPEGreenLakeSession.workspaceId
                    resourceUri = "/workspaces/v1/workspaces/$($Global:HPEGreenLakeSession.workspaceId)"
                }

            } | ConvertTo-Json -Depth 5


            # Create organization

            try {
                            
                $Response = Invoke-HPEGLWebRequest -Uri $Uri -method 'POST' -body $Payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                    
               
                if (-not $WhatIf) {
                    "[{0}] Organization '{1}' successfully created!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Organization successfully created!"
                }
            }
            catch {
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Organization cannot be created!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData
                }
            }
        }

        if (-not $WhatIf) {
            [void] $OrganizationCreationStatus.add($objStatus)
        }

    }

    End {

        if ($OrganizationCreationStatus.Count -gt 0) {
            
            $Global:HPEGreenLakeSession.organization = $Name
            $Global:HPEGreenLakeSession.organizationId = $Response.id

            $OrganizationCreationStatus = Invoke-RepackageObjectWithType -RawObject $OrganizationCreationStatus -ObjectName "ObjStatus.NSDE" 
            Return $OrganizationCreationStatus
        }
    }
}


Function Set-HPEGLOrganization {
    <#
    .SYNOPSIS
    Updates the current organization details.

    .DESCRIPTION
    Updates general information about the HPE GreenLake organization to which you are currently connected. If you omit any parameter, the cmdlet retains the current settings for those fields and only updates the provided parameters.

    .PARAMETER Name
    Specifies the new name of the organization. The new name must be unique across all organizations on the HPE GreenLake platform.

    .PARAMETER Description
    Specifies the new description of the organization.
    
    .PARAMETER PhoneNumber
    Specifies the contact phone number of the organization.

    .PARAMETER Email
    Specifies the contact email address of the organization. 

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Set-HPEGLOrganization -Name "New_Organization_Name" -Description "Updated description" -PhoneNumber "+0987654321" -Email "new_email@example.com"
    
    Updates the current organization's name, description, phone number, and email address with the provided values.

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

        [validatescript({ if ($_.Length -le 256) { $true } else { Throw "The Parameter value exceeds the maximum length of 256 characters. Please correct the value and try again." } })]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        # The max length is 4096 characters.
        [Validatescript({ if ($_.Length -le 4096) { $true } else { Throw "The Parameter value exceeds the maximum length of 4096 characters. Please correct the value and try again." } })]
        [String]$Description,
       
        # Numbers and characters ( ) - . + and space are allowed. The max length is 30.
        [validatescript({ if ($_.Length -le 30 -and $_ -match '^[a-zA-Z0-9\s\(\)\-\.\+]*$') { $true } else { Throw "The Parameter value is not valid. Only numbers and characters ( ) - . + and space are allowed. The max length is 30. Please correct the value and try again." } })]
        [String]$PhoneNumber,

        [validatescript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$Email,    

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $SetOrganizationStatus = [System.Collections.ArrayList]::new()
        
    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Check current organization

        try {
            $OrganizationDetails = Get-HPEGLOrganization -ShowCurrent

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        $Uri = (Get-OrganizationsListUri) + "/" + $OrganizationDetails.id

        # Build object for the output
        $objStatus = [pscustomobject]@{

            Name      = $OrganizationDetails.name
            Status    = $Null
            Details   = $Null
            Exception = $Null
                  
        }

        $Payload = @()

        # Conditionally add properties
        if ($PSBoundParameters.ContainsKey('Name')) {

            $Payload += @{
                op    = "replace"
                path  = "/name"
                value = $Name
            }
        }

        if ($PSBoundParameters.ContainsKey('Description')) {
            $Payload += @{
                op    = "replace"
                path  = "/description"
                value = $Description
            }
        }

        if ($PSBoundParameters.ContainsKey('Email')) {
            $Payload += @{
                op    = "replace"
                path  = "/email"
                value = $Email
            }
        }

        if ($PSBoundParameters.ContainsKey('PhoneNumber')) {
            $Payload += @{
                op    = "replace"
                path  = "/phoneNumber"
                value = $PhoneNumber
            }
        }

        $Payload = $Payload | ConvertTo-Json -Depth 5


        # Current organization modification
        try {
            
            $_resp = Invoke-HPEGLWebRequest -Method 'PATCH' -Body $Payload -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference 
                         
            if (-not $WhatIf) {
                "[{0}] Organization details updated successfully!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                $objStatus.Status = "Complete"
                $objStatus.Details = "Organization details updated successfully."
            }
        }
        catch {
            if (-not $WhatIf) {
                "[{0}] Organization details cannot be updated!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Organization details cannot be updated!" }
                $objStatus.Exception = $Global:HPECOMInvokeReturnData
            }
        }    

        if (-not $WhatIf) {
            [void] $SetOrganizationStatus.add($objStatus)
        }
        

    }

    end {

        if ($SetOrganizationStatus.Count -gt 0) {

            $SetOrganizationStatus = Invoke-RepackageObjectWithType -RawObject $SetOrganizationStatus -ObjectName "ObjStatus.NSDE" 
            Return $SetOrganizationStatus
        }
    }
}


Function Join-HPEGLOrganization {
    <#
    .SYNOPSIS
    Joins the current workspace to an existing HPE GreenLake organization.

    .DESCRIPTION
    This cmdlet activates organization membership for the current workspace by joining an existing organization. The workspace must be a standalone IAMv2 workspace that is not already a member of any organization.
    
    Upon successful activation, the current workspace becomes a member workspace of the specified organization, and organization governance features are enabled.

    Joining an existing organization enables governance of this workspace within that organization.

    Note: Joining an existing organization requires having organization administration permission in the organization. If you do not see your organization listed when using 'Get-HPEGLOrganization -IncludeJoinEligibleOnly', contact an organization administrator to perform this action.

    Note: If the organization being joined uses SSO, workspace users will need to SSO in order to access the workspace after the join is complete. If the organization uses SSO role assignments, this workspace will not be accessible until role assignments have been added to the SSO identity provider for this workspace.
    
    .PARAMETER Name
    Specifies the name of the organization to join. The organization must exist and be eligible for joining. You can use Get-HPEGLOrganization -IncludeJoinEligibleOnly to list available organizations.
    
    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Join-HPEGLOrganization -Name "My organization" 

    Joins the current workspace to the organization named "My organization".

    .EXAMPLE
    Get-HPEGLOrganization -Name "MyOrganization" | Join-HPEGLOrganization 

    Retrieves the organization named "MyOrganization" and joins the current workspace to it using pipeline input.

    .EXAMPLE
    Get-HPEGLOrganization -IncludeJoinEligibleOnly | Where-Object name -eq "Production" | Join-HPEGLOrganization

    Finds the join-eligible organization named "Production" and joins the current workspace to it.

    .INPUTS
    HPEGreenLake.Organization
    You can pipe organization objects from Get-HPEGLOrganization to this cmdlet.

    .OUTPUTS
    System.Collections.ArrayList
    A custom status object containing the following PsCustomObject keys:
        * OrganizationId - ID of the organization attempted to join
        * Status - Status of the join attempt (Failed for HTTP error return; Complete if successful; Warning if no action is needed)
        * Details - More information about the status
        * Exception - Information about any exceptions generated during the operation
    #>
    
    [CmdletBinding()]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [validatescript({ 
            if ($_.Length -le 256 -and $_ -notmatch '[<>{}]') { 
                $true 
            } 
            else { 
                Throw "The Parameter value exceeds the maximum length of 256 characters or contains invalid characters (< > { }). Please correct the value and try again." 
            } 
        })]
        [String]$Name,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $JoinOrganizationStatus = [System.Collections.ArrayList]::new()
        
    }
    
    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name           = $Name
            Status         = $Null
            Details        = $Null
            Exception      = $Null
        }

        # Verify the organization exists and is join-eligible
        try {
            $Organization = Get-HPEGLOrganization -IncludeJoinEligibleOnly | Where-Object { $_.name -eq $Name }
            
            if (-not $Organization) {
                "[{0}] Organization '{1}' not found or not eligible to join!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

                if ($WhatIf) {
                    $ErrorMessage = "Organization '{0}': Not found or not eligible to join! No action taken. Cannot display API request." -f $Name
                    Write-Warning "$ErrorMessage Cannot display API request."
                    return
                }
                else {
                    $objStatus.Status = "Warning"
                    $objStatus.Details = "This organization was not found or is not eligible to join! No action taken."
                }
            }
            # Check if current workspace is already part of an organization
            elseif ($Organization) {
                # Check session variable first (faster and doesn't require API permissions)
                if ($Global:HPEGreenLakeSession.organizationId) {
                    "[{0}] Current workspace is already part of organization '{1}' (ID: {2})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Global:HPEGreenLakeSession.organization, $Global:HPEGreenLakeSession.organizationId | Write-Verbose
                    
                    if ($WhatIf) {
                        $ErrorMessage = "Current workspace is already part of organization '{0}'! No action needed. Cannot display API request." -f $Global:HPEGreenLakeSession.organization
                        Write-Warning "$ErrorMessage Cannot display API request."
                        return
                    }
                    else {
                        $objStatus.Status = "Warning"
                        $objStatus.Details = "Current workspace is already part of organization '$($Global:HPEGreenLakeSession.organization)'! No action needed."
                    }
                }
                else {
                    # Build URI
                    $Uri = (Get-Workspacev2Uri) + "/$($HPEGreenLakeSession.workspaceId)/join-organization"

                    # Build payload with only provided parameters
                    $PayloadObject = @{
                        organizationId = $Organization.id
                    }       

                    $Payload = $PayloadObject | ConvertTo-Json -Depth 5

                    # Join organization
                    try {
                        $Response = Invoke-HPEGLWebRequest -Uri $Uri -Method 'POST' -Body $Payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                        
                        if (-not $WhatIf) {
                            "[{0}] Successfully joined organization '{1}'!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Organization.name | Write-Verbose
                            
                            # Update the HPEGreenLakeSession with organization information
                            "[{0}] Organization object ID before assignment: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Organization.id | Write-Verbose
                            "[{0}] Organization object Name before assignment: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Organization.name | Write-Verbose
                            
                            if ($Organization.id) {
                                $Global:HPEGreenLakeSession.organizationId = $Organization.id
                                "[{0}] Set session organizationId to: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Global:HPEGreenLakeSession.organizationId | Write-Verbose
                            }
                            else {
                                "[{0}] WARNING: Organization.id is null or empty, cannot set organizationId" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            }
                            
                            if ($Organization.name) {
                                $Global:HPEGreenLakeSession.organization = $Organization.name
                                "[{0}] Set session organization to: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Global:HPEGreenLakeSession.organization | Write-Verbose
                            }
                            
                            # Reconnect to the workspace to refresh the session token with updated RBAC permissions
                            "[{0}] Reconnecting to workspace to refresh session token with organization permissions..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            try {
                                $currentWorkspace = $Global:HPEGreenLakeSession.workspace
                                
                                # Force reconnection to refresh token (uses current workspace)
                                Connect-HPEGLWorkspace -Force -NoProgress | Out-Null
                                
                                "[{0}] Successfully reconnected to workspace '{1}' with updated permissions." -f $MyInvocation.InvocationName.ToString().ToUpper(), $currentWorkspace | Write-Verbose
                                $objStatus.Status = "Complete"
                                $objStatus.Details = "Successfully joined organization '$($Organization.name)' and refreshed session with updated permissions!"
                            }
                            catch {
                                "[{0}] WARNING: Failed to automatically reconnect to workspace. You may need to manually reconnect to access organization resources. Error: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                                $objStatus.Status = "Complete"
                                $objStatus.Details = "Successfully joined organization '$($Organization.name)'! Note: Please reconnect to the workspace to refresh your session and access organization resources."
                            }
                        }
                    }
                    catch {
                        if (-not $WhatIf) {
                            "[{0}] Failed to join organization!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            $objStatus.Status = "Failed"
                            
                            # Check the error response for specific error messages
                            if ($Global:HPECOMInvokeReturnData) {
                                $errorResponse = $Global:HPECOMInvokeReturnData
                                
                                # Check for 400 Bad Request with inactive state error
                                if ($errorResponse.httpStatusCode -eq 400 -and $errorResponse.errorDetails) {
                                    $inactiveStateIssue = $errorResponse.errorDetails.issues | Where-Object { $_.description -match "not in inactive state" }
                                    if ($inactiveStateIssue) {
                                        $objStatus.Details = "Failed to join organization! Workspace is already part of an organization. Only workspaces not yet in an organization can join."
                                    }
                                    else {
                                        $objStatus.Details = "Failed to join organization! $($errorResponse.message)"
                                    }
                                }
                                # Check for 403 Forbidden error
                                elseif ($errorResponse.httpStatusCode -eq 403) {
                                    $objStatus.Details = "Failed to join organization! Organization administrator role is required for this operation."
                                }
                                else {
                                    $objStatus.Details = "Failed to join organization!"
                                }
                            }
                            # Fallback if no Global response data
                            elseif ($_.Exception.message -match "403" -or $_.Exception.message -match "Forbidden") {
                                $objStatus.Details = "Failed to join organization! Organization administrator role is required for this operation."
                            }
                            elseif ($_.Exception.message -match "400" -or $_.Exception.message -match "Bad Request") {
                                $objStatus.Details = "Failed to join organization! Bad request - please verify organization details."
                            }
                            else {
                                $objStatus.Details = "Failed to join organization!"
                            }
                            
                            $objStatus.Exception = $Global:HPECOMInvokeReturnData
                        }
                    }
                }
            }
        }
        catch {
            if (-not $WhatIf) {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Organization cannot be joined!" }
                $objStatus.Exception = $Global:HPECOMInvokeReturnData 
            }            
        }

        if (-not $WhatIf) {
            [void] $JoinOrganizationStatus.add($objStatus)
        }
    }

    End {

        if ($JoinOrganizationStatus.Count -gt 0) {
            
            # Session variables are already updated in the Process block, no need to update here again
            
            $JoinOrganizationStatus = Invoke-RepackageObjectWithType -RawObject $JoinOrganizationStatus -ObjectName "ObjStatus.NSDE" 
            Return $JoinOrganizationStatus
        }
    }
}


#------------------- END OF FUNCTIONS FOR HPE GreenLake ORGANIZATIONS -----------------------------------------------------------------------------------------------------------------------------------------------



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
Export-ModuleMember -Function 'Get-HPEGLOrganization', 'New-HPEGLOrganization', 'Set-HPEGLOrganization', 'Join-HPEGLOrganization' -Alias *


# SIG # Begin signature block
# MIIunwYJKoZIhvcNAQcCoIIukDCCLowCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAPZncIo/SNaCJi
# VoV1M7GurjA4NBaZ+6GKIWTrMgpwPaCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQg1EsRQ+jS7S1VnnGQQPkR6zajW0GlWPfWBgeOF6LpsYgwDQYJKoZIhvcNAQEB
# BQAEggIAqGW7vhLYLs9dHFpBFdPlFaJyqCX1h3QKoMnvZfO8779KoXeDkJWre51x
# i+1zj0Gvz8gfDq8dY1gpg/EST8cUKqJZUTDeVSZKCVB1C257tW7mNQ2tFirXx+AU
# EZMTUQB25FFrAT5v0ALIO4sdfBWcnuHV4fKP1tsk4l7dzFnr6JJd0JFXzbiY3xsb
# rF+8bHV74Y97P411rtEGr0ZpR+imVpDTcr8atwWTeYx9otRVU+l+BWlt6bd2GenA
# X6BKzNwGyDGzXa3ixJgnUmD5J+zk1aHeML5rOet3I8uy5Lb8QbjE6D0091Yg606S
# OcJmE37Ie1hnImJRhj+XJv9CgeND6J6Y9wdKiRyCbRAtOa+N7w0N+18QH+4DY/ih
# hNzzaRxsj2M5qh5YPrZGrh/fT+UI/OcBSqIzPewfKvlKm9IaQB2MRtR9dQBUDin2
# TE0hrho47DT7D1/4y6CDjRIaChqsNQ9SPsQkTbvOtPr9lD7ousv2dc2EcvXOR/ic
# mc1dpmMqcJXt8zM3F/y705NtyXOrJVoym6C8KvhmM+jqHvtyCiFH7hjcr+DwHnVf
# QWWpXI8u3AkiB/dDkXCOZvUl7NNc7aLjdP8JG3LA1keXl9ZyX3ErzJGM3m1OOlHp
# Ua7kJJT4DHDtNgjwUHEY9+KGTSsRLSdVGgQZx1brFZ5QzTeOBWyhghjpMIIY5QYK
# KwYBBAGCNwMDATGCGNUwghjRBgkqhkiG9w0BBwKgghjCMIIYvgIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBCAYLKoZIhvcNAQkQAQSggfgEgfUwgfICAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQwJictvMvcV3EeFaDV8vd/se9vJT0ZoHvpoq6H
# PvmIjHol5Z/8CuEYmq6SU+/IB72KAhUAu9SqGU53wS4aN+L19M29JsMW9JUYDzIw
# MjYwMzE3MTQzNTIxWqB2pHQwcjELMAkGA1UEBhMCR0IxFzAVBgNVBAgTDldlc3Qg
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
# MQ8XDTI2MDMxNzE0MzUyMVowPwYJKoZIhvcNAQkEMTIEMLqEjHJevBQZnRQHumJo
# dvZfUK0vf/BxbtBK1Wfg38jTbBFPkIjiUC4bXYiQfGPryDCCAXoGCyqGSIb3DQEJ
# EAIMMYIBaTCCAWUwggFhMBYEFDjJFIEQRLTcZj6T1HRLgUGGqbWxMIGHBBTGrlTk
# eIbxfD1VEkiMacNKevnC3TBvMFukWTBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMP
# U2VjdGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBUaW1lIFN0
# YW1waW5nIFJvb3QgUjQ2AhB6I67aU2mWD5HIPlz0x+M/MIG8BBSFPWMtk4KCYXzQ
# kDXEkd6SwULaxzCBozCBjqSBizCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5l
# dyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNF
# UlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNh
# dGlvbiBBdXRob3JpdHkCEDbCsL18Gzrno7PdNsvJdWgwDQYJKoZIhvcNAQEBBQAE
# ggIAFpeZiHPI4Hk1Dz6+EmLxrlFegnxE4raqvDW1Wk4On6aUZsKV5D2543sS5L6K
# sX5EqLbdzwJIEFxlxiaPOfcfhsydUAfo7eu3uvsKDEaPIb/1zla1xAHegDUiqdDn
# /iYW6yk1O5kLyBScULjxlrcpdGfJ48JK7xTsLzmHePCkesq3l140bC1cO8oodztt
# cr/lTbw+VYmUJYo01AlGvWN/RXso8ELZI/rch0mJ/6kICSjyZXghiJyibmukAU02
# el4mfCJyPQE3Ke2GVgZSSu0rKflpQLRuqZ8C7a+aTvnqY7XUDpLY3ko/iTVcHt0p
# 1aviLUxjRpAka/Ntc9QvJb4ep8L/vaYm+uv+7YqiQL3rCLhG6tzxApEjyrbAEI3a
# w9a7E/5QjbDjjniNrCGzlH2ahF51Pdh2mgfsX8IA7dWaf5YukqKT0+SPrgQkWiIY
# /jqTqbIRE1tNaKvE9IHeyxHaJkSOgEBbV9D0RyUPCh0dyVNASJ25vnlyA4hFrbx7
# 7uXw9+LL2qed6FptrUa6wv0AEP1SEhWpIwY8VGtftSfE4qDNEWjk9qvUr5mQckuT
# qUuUdAzT4eoAvycKJ5CebDJKV0EHIWa4KjrooPyzzgGEBhB21OvKtQ7rDkO/GApd
# PyhUJS/OaNdHP5zkeopFMjtCq5OecLAnZYpc1gOjDQX3QMo=
# SIG # End signature block
