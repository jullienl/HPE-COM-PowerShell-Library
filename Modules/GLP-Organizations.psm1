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
                    $objStatus.Details = "Organization cannot be created!"
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
                $objStatus.Details = "Organization details cannot be updated!"
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
                            
                            $objStatus.Exception = $_.Exception.message
                        }
                    }
                }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
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
# MIIungYJKoZIhvcNAQcCoIIujzCCLosCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBz7rRsucgkxBGs
# 97sfbJjmVPl7sweWZtFql+GWnp96kKCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQgYfIsYMAnGK0GwSI8IbPjniHX66JaBJbL+PxMIOO3E4swDQYJKoZIhvcNAQEB
# BQAEggIANSHalMhw/h4PVIOyVFAnwdJSkIR66UA9K6fbDnpKq42V7Ufy2rd/TluF
# fYXy8H5i5t8XtQ17j+B59nyFKySZi2Wb71wzZagVI9wBAdl7bT4nNlUfEE06oIVO
# c7R0YIn0lVLK4iEjKhv8QklC3/YYnLGyMPoGM9tARG5QiLyQXSYg9XcVLnrkr3Og
# Fnkyucsz7y6lvbNtoN7fQFu+aAIC95rsWYRa41xXrDuO4bSfZbSqnEiwtM350ygu
# fr4rwi/qsG8qbN/wnoUxW72mR6xlh/rh/uGg5xs76GyLXNuwXlfp/c7B5eKjiy7p
# y4mfi8e0Gs0k7nfiwbjBjoom0X++cp86/MmTCz4EuWRxacNXWYmAZtdx6n1IAcNV
# sjfCPyW3enTw8yI6IZCwTO/J9vqJUzvuOvlOmJJZdJ4gakfPb1/TA1VFwzZwugBX
# 6s8QgeBjiUsYSFaVhGWGiE6Ftesmu6ov3E9eS5XxZrjW4tTVuY9ct1gR3sZU3GM7
# CZTi1PjlSBj6G89lh/LzdGW6ua+xDorrt6LvO//ZxBwQyFyGcwKc0pIKOz9f2hpi
# XoCmohNujAS/9uJtMqcZa6/siwHKBjVDefxBCdLrF0DQjjS4Fg117HmsaTbTRuEh
# whJ1+X9pNF4fWjlzZcJ78AGAYIQFTYTeqk3vZBcL6B+0/DlP286hghjoMIIY5AYK
# KwYBBAGCNwMDATGCGNQwghjQBgkqhkiG9w0BBwKgghjBMIIYvQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBBwYLKoZIhvcNAQkQAQSggfcEgfQwgfECAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQwsN2Lva70w60b6aocWOFLNNNThGffQYRZmNPP
# xNVWYDVUXhmloVo33AZ1sZPM2hF5AhQb/FTtSLgW16zvRe30YqnaX3K3SRgPMjAy
# NjAxMTkxODIzNDNaoHakdDByMQswCQYDVQQGEwJHQjEXMBUGA1UECBMOV2VzdCBZ
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
# DxcNMjYwMTE5MTgyMzQzWjA/BgkqhkiG9w0BCQQxMgQwVlBlTHK/ldgXrVjlBWAX
# qNZFgIayHB4J6zwHtK+ID2lfNjIRIzu1s1PLrXLlLjrgMIIBegYLKoZIhvcNAQkQ
# AgwxggFpMIIBZTCCAWEwFgQUOMkUgRBEtNxmPpPUdEuBQYaptbEwgYcEFMauVOR4
# hvF8PVUSSIxpw0p6+cLdMG8wW6RZMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRpbWUgU3Rh
# bXBpbmcgUm9vdCBSNDYCEHojrtpTaZYPkcg+XPTH4z8wgbwEFIU9Yy2TgoJhfNCQ
# NcSR3pLBQtrHMIGjMIGOpIGLMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKTmV3
# IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBVU0VS
# VFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZpY2F0
# aW9uIEF1dGhvcml0eQIQNsKwvXwbOuejs902y8l1aDANBgkqhkiG9w0BAQEFAASC
# AgCDgm1i70QWMaU4kQPsP81HAfBlgcsGYKBmxIEd8w4dG03qviIxvthCw/wM74u9
# e5keMjilueC6SZBomTp3lCVqg9U5B4kFgA2OftPDcjXsT54/4vYRDO1ec7uIbPmS
# 1e9CLqfWoQKQCSboM67DPkNpNK1vRvMbrd/dgwW0PERqOwrsBTvED6siDjR74iwg
# xgA6GH2LlGF5x1G2V5V+hJc8xsPHwEw/L25Sj4VmJgtycOO9gH2JH8oczyn3LotA
# lqcjmOBHa+uHTEeiuRjkgtbIWO4omCYkSAsLoxuEVTDdcpviqKDSXE3nAx7FyHht
# 80hhbOLK1fRa0w7nSYLErthLVAQrWp6OaYbeP8vwGXUNkJR2cNhHZaPQPdfTBiEc
# iaNUnq9mj5zH6hCDqG0Xmbnf2OZBROPMIbWywhuROBFMm3StTlRYp8DT32mE9G3V
# B/Se/o0TjHSIVoq0Mf2i676/9zFP2pjS5IXHr2zbTCHoDm+1UmwI0aavTELabQef
# qVYnEBB7zPCfAK8sFAYvtQstID3ZQFwOv3VRbY24kFliB5pjOpatGUjqSCG+c0Rm
# b0RCsef6jHQfVHA6g34CwAkl5NGXKvjOa7fGvcztZiTAwmyZy/yU3hBrEJdH63ha
# 4BcwAbgqIpEu0NkGgEc2DNsvrvF6EmpplmUxxgzgxIR3Lg==
# SIG # End signature block
