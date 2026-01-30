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
                        Write-Warning "Cannot determine organization for this workspace. The workspace may not be part of any organization."
                        return
                    }
                    
                    $Collection = $OrgCollection
                }
                else {
                    "[{0}] No workspace session found. Please connect with Connect-HPEGLWorkspace first." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    Write-Warning "No workspace session found. Please connect with Connect-HPEGLWorkspace first."
                    return
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

            $OrganizationAlreadySet = $OrganizationFound | Where-Object { $_.associatedWorkspace.id -eq $Global:HPEGreenLakeSession.workspaceId }
            
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
                Write-warning $ErrorMessage
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
        #         Write-warning $ErrorMessage
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
                    $objStatus.Exception = $_.Exception.message
                }
            }
        }

        [void] $OrganizationCreationStatus.add($objStatus)

    }

    End {

        if (-not $WhatIf) {
            
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
                $objStatus.Exception = $_.Exception.message 
            }
        }    

        [void] $SetOrganizationStatus.add($objStatus)
        

    }

    end {

        if (-not $WhatIf) {

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
                    $ErrorMessage = "Organization '{0}': Not found or not eligible to join! No action taken." -f $Name
                    Write-Warning $ErrorMessage
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
                        $ErrorMessage = "Current workspace is already part of organization '{0}'! No action needed." -f $Global:HPEGreenLakeSession.organization
                        Write-Warning $ErrorMessage
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
                                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Successfully joined organization '$($Organization.name)'! Note: Please reconnect to the workspace to refresh your session and access organization resources." }
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
                            
                            $objStatus.Exception = $_.Exception.message
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

        [void] $JoinOrganizationStatus.add($objStatus)
    }

    End {

        if (-not $WhatIf) {
            
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
# MIItTgYJKoZIhvcNAQcCoIItPzCCLTsCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBeFtjgTq3+nJp2
# ANneU/XleNWh7CWnAtd69GFIHQpALqCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQgrRZ/tzyImT3nOMXMK4+iYWRwScyqFiSd0HOYDGpN2qswDQYJKoZIhvcNAQEB
# BQAEggIAl7GO9SH3vyyxjQslRkuIxSytxxwOIn/Tj1a8F021EZGfDYGYZVF3Qo40
# jnDqQOKEiMmwskDnPjpYPHrYnPdl3txpAC7kahhv7lO5gVo1LDl1LZIGYx9pCHjH
# ++Yd696tqgPeFiA752kySw1HmbqrHnoRkeMHkFK40O+wSPueTvrKegx5Oq1vTHPA
# GTaBFPM8DlVdtq/B2T8yVuj1pT5Yq8dbXm+5V/p0FyCtg9l2osWO2F5Z0JrVYT2B
# eF0N2EIJ8bJPvdYSp2bzsBb5ZZxFunj7+iEbJeFDzS+LbHDU4NdZMteyW/lCdJaz
# mWTjAMN3ixCKWvNrLD0iKGBCBReL4QpCe3DZ9wHR8bbTNg/bxErU8ilQSHCWSm2j
# /5Dnhn+/K1YIjfZSOytdGvR6ROuPqK2jWQFPTzu/nhRm3Wy5Wc6pISHxeB4ywzl3
# peN3wOiLJNvtoSXWVjcczp8vpBarhd2osZlrkeWpaODWnDC218/kynQ1g5KBE3+y
# uVG9XI+MgwxLubGKRzIVOdvHK+84aX4l4DRLQpD57kg3Aqc51g7q8lsg3Tf07Ykp
# BKUicUchtr+tqYiKQor0AmABpI+csHPMUfmHqSa//PkY9Z0iPBoCwBntOmc3j3cJ
# gCwE3fjlehkhZdgqVanNFxMcSpcFc3tVDPvsGbV/kr+D+b6XlvGhgheYMIIXlAYK
# KwYBBAGCNwMDATGCF4QwgheABgkqhkiG9w0BBwKgghdxMIIXbQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIGIBgsqhkiG9w0BCRABBKB5BHcwdQIBAQYJYIZIAYb9bAcBMEEw
# DQYJYIZIAWUDBAICBQAEMAptfNm3xhNb+DsxrRrUySDDl/zs8f7+tmCLBDd2E2wG
# sXeJ/PsJ9YUXdBK8TxnoawIRAK6uwVdU1Q5QE4E4ckLk4W0YDzIwMjYwMTMwMTA1
# MjU1WqCCEzowggbtMIIE1aADAgECAhAMIENJ+dD3WfuYLeQIG4h7MA0GCSqGSIb3
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
# BgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI2MDEz
# MDEwNTI1NVowKwYLKoZIhvcNAQkQAgwxHDAaMBgwFgQUcrz9oBB/STSwBxxhD+bX
# llAAmHcwNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgMvPjsb2i17JtTx0bjN29j4uE
# dqF4ntYSzTyqep7/NcIwPwYJKoZIhvcNAQkEMTIEMIy/x7KSN4RVZUvZay5Xn5Jm
# oiDM227HvZXHznSBm645N6Y9IzYx9j1zMoRcKaOwPjANBgkqhkiG9w0BAQEFAASC
# AgAg45Bq6GaY8YIQmr/scmZqKQICC0f5KB/WKuWA966Nq5JJXFqx+MvIYxMnuqWY
# PwWs00p9N1PbtkvjZ5Cx4PlknpxNW5zsutRTO7CIyWgVqkRcurp/lcVqdlYX6QSK
# ih1uPBAP3Lm+JsZlvsyZ5OYYh7utRqwHOOA3GTM6SaAwztfwZ3090TV31SHJxLUr
# RnI4ddlZ3ePrZ/h7I8yH9NAsvPcdDSkOrqpa9dbHrNnPP674KyPwEiVsQFlNA5Dy
# u/lpINxb3fpo5HsdBsKgFMB8c0EA7/nIt2TeMfhx2duODsKqaEIeSOOAxynmELFg
# 8gRFIFTsC01NT7sJcljdzQ+j/enay5ORonQfEquGTIzupf1hjMVEBlEnf45N6yf/
# JKKq4Oi7hBrdENum2Aivp1bsGMK0PvlIa9ejDBv1zhVNNv96Eqi4JklwdpiwxR9/
# xapUKDEhzJ8ruR3eY4+z1P0qkFwCPlGhctJuzPtWHRcIXYDoVAfZudGnGpC0MceP
# As6EBeDet0j2mMp7/Bixb/UCzqXcQ+U3zFKZVS+8pTxmxFzy9rCl7Vtzn94CqeXr
# g4JkQB+oTEyEHWTcSHDGjZ1ss+F++bgaE81HNYQ+IR7bJFie0gLNfOoK2vdrGTHk
# iNHJRJNsI7XDLNTa82RIAZibxOe9m5SOnSXGRjVRXnv1XA==
# SIG # End signature block
