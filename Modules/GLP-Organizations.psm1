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

            # Mark current organization — use cached session ID, or fall back to JWT claim
            $currentOrgId = $Global:HPEGreenLakeSession.organizationId
            if (-not $currentOrgId) {
                $jwt = $Global:HPEGreenLakeSession.glpApiAccessTokenv1_2.access_token
                if ($jwt) {
                    try {
                        $jwtPayload = $jwt.Split('.')[1]
                        $padLength = (4 - $jwtPayload.Length % 4) % 4
                        $jwtPayload = $jwtPayload.PadRight($jwtPayload.Length + $padLength, '=')
                        $jwtClaims = [System.Text.Encoding]::UTF8.GetString(
                            [Convert]::FromBase64String($jwtPayload.Replace('-', '+').Replace('_', '/'))
                        ) | ConvertFrom-Json
                        $currentOrgId = $jwtClaims.hpe_organization_id
                    } catch {}
                }
            }
            if ($currentOrgId) {
                $CurrentOrg = $Collection | Where-Object { $_.id -eq $currentOrgId }
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
                    # Note: $Collection is type-constrained as [Array], so a filtered single result is
                    # re-wrapped into an array. Setting '.current' must be done per-element (setting a
                    # property directly on the array object throws "property cannot be found").
                    foreach ($_org in $Collection) { $_org.current = $True }
                }
                elseif ($Global:HPEGreenLakeSession.workspaceId) {
                    # Step 2: Check if current workspace is the management workspace of an organization
                    "[{0}] Searching for organization where current workspace is the management workspace: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Global:HPEGreenLakeSession.workspaceId | Write-Verbose
                    $OrgCollection = $Collection | Where-Object { $_.associatedWorkspace.id -eq $Global:HPEGreenLakeSession.workspaceId }
                    
                    if (-not $OrgCollection) {
                        # Step 3: Extract organization ID from the GLP API v1.2 JWT token.
                        # The organizations/v2alpha1/workspaces API only returns member workspaces, never the
                        # management workspace, so hash-based lookups against associatedWorkspace.id always fail.
                        # The hpe_organization_id claim in the v1.2 token is the authoritative, direct source.
                        "[{0}] Not a management workspace. Checking GLP API v1.2 JWT token for organization membership..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                        
                        try {
                            $jwt = $Global:HPEGreenLakeSession.glpApiAccessTokenv1_2.access_token
                            if ($jwt) {
                                $jwtPayload = $jwt.Split('.')[1]
                                $padLength = (4 - $jwtPayload.Length % 4) % 4
                                $jwtPayload = $jwtPayload.PadRight($jwtPayload.Length + $padLength, '=')
                                $jwtClaims = [System.Text.Encoding]::UTF8.GetString(
                                    [Convert]::FromBase64String($jwtPayload.Replace('-', '+').Replace('_', '/'))
                                ) | ConvertFrom-Json
                                $jwtOrgId = $jwtClaims.hpe_organization_id
                                
                                if ($jwtOrgId) {
                                    "[{0}] Found organization ID in JWT token: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $jwtOrgId | Write-Verbose
                                    $OrgCollection = $Collection | Where-Object { $_.id -eq $jwtOrgId }
                                    if ($OrgCollection) {
                                        "[{0}] Found organization: {1} (ID: {2})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $OrgCollection.name, $OrgCollection.id | Write-Verbose
                                    }
                                }
                                else {
                                    "[{0}] JWT token has no hpe_organization_id claim — current workspace is standalone (not part of any organization)." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                }
                            }
                        }
                        catch {
                            "[{0}] Failed to extract organization ID from JWT token: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                        }
                    }
                    
                    if (-not $OrgCollection) {
                        "[{0}] Organization not found. The workspace is not part of any organization." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                        return
                    }
                    
                    $OrgCollection.current = $True
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

                # Secondary unfiltered lookup to distinguish "does not exist" from "exists but not eligible"
                $ExistingOrganization = Get-HPEGLOrganization -Name $Name

                if (-not $ExistingOrganization) {
                    # Organization does not exist at all in the current environment
                    "[{0}] Organization '{1}' not found in the current environment!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

                    if ($WhatIf) {
                        $ErrorMessage = "Organization '{0}': Resource cannot be found in the current environment! No action taken." -f $Name
                        Write-Warning "$ErrorMessage Cannot display API request."
                        return
                    }
                    else {
                        $objStatus.Status = "Warning"
                        $objStatus.Details = "Organization cannot be found in the current environment! No action taken."
                    }
                }
                else {
                    # Organization exists but is not eligible to join. Determine the most likely reason.
                    "[{0}] Organization '{1}' exists but is not eligible to join. Determining reason..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

                    if ($Global:HPEGreenLakeSession.organizationId) {
                        # The current workspace is already a member of an organization
                        $IneligibleReason = "The current workspace is already a member of organization '$($Global:HPEGreenLakeSession.organization)'. A workspace can only belong to one organization. To join a different organization, the workspace must first leave its current organization."
                    }
                    else {
                        # Workspace is standalone, so ineligibility is due to organization-side constraints
                        # (missing organization administration permission is the most common cause)
                        $IneligibleReason = "You do not have organization administration permission in this organization, or the organization's policies prevent this workspace from joining. Joining an existing organization requires organization administrator permission. Contact an organization administrator of '$Name' to perform this action or to grant you the required permission."
                    }

                    "[{0}] Ineligibility reason: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IneligibleReason | Write-Verbose

                    if ($WhatIf) {
                        $ErrorMessage = "Organization '{0}': Not eligible to join! {1} No action taken." -f $Name, $IneligibleReason
                        Write-Warning "$ErrorMessage Cannot display API request."
                        return
                    }
                    else {
                        $objStatus.Status = "Warning"
                        $objStatus.Details = "Organization is not eligible to join! $IneligibleReason No action taken."
                    }
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
# MIIn2wYJKoZIhvcNAQcCoIInzDCCJ8gCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCArx+GJPFdSeWq9
# 6wcoZAy2ZVfb2dwzjtRToHOzY3NLLaCCDIMwggYaMIIEAqADAgECAhBiHW0MUgGe
# O5B5FSCJIRwKMA0GCSqGSIb3DQEBDAUAMFYxCzAJBgNVBAYTAkdCMRgwFgYDVQQK
# Ew9TZWN0aWdvIExpbWl0ZWQxLTArBgNVBAMTJFNlY3RpZ28gUHVibGljIENvZGUg
# U2lnbmluZyBSb290IFI0NjAeFw0yMTAzMjIwMDAwMDBaFw0zNjAzMjEyMzU5NTla
# MFQxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxKzApBgNV
# BAMTIlNlY3RpZ28gUHVibGljIENvZGUgU2lnbmluZyBDQSBSMzYwggGiMA0GCSqG
# SIb3DQEBAQUAA4IBjwAwggGKAoIBgQCbK51T+jU/jmAGQ2rAz/V/9shTUxjIztNs
# fvxYB5UXeWUzCxEeAEZGbEN4QMgCsJLZUKhWThj/yPqy0iSZhXkZ6Pg2A2NVDgFi
# gOMYzB2OKhdqfWGVoYW3haT29PSTahYkwmMv0b/83nbeECbiMXhSOtbam+/36F09
# fy1tsB8je/RV0mIk8XL/tfCK6cPuYHE215wzrK0h1SWHTxPbPuYkRdkP05ZwmRmT
# nAO5/arnY83jeNzhP06ShdnRqtZlV59+8yv+KIhE5ILMqgOZYAENHNX9SJDm+qxp
# 4VqpB3MV/h53yl41aHU5pledi9lCBbH9JeIkNFICiVHNkRmq4TpxtwfvjsUedyz8
# rNyfQJy/aOs5b4s+ac7IH60B+Ja7TVM+EKv1WuTGwcLmoU3FpOFMbmPj8pz44MPZ
# 1f9+YEQIQty/NQd/2yGgW+ufflcZ/ZE9o1M7a5Jnqf2i2/uMSWymR8r2oQBMdlyh
# 2n5HirY4jKnFH/9gRvd+QOfdRrJZb1sCAwEAAaOCAWQwggFgMB8GA1UdIwQYMBaA
# FDLrkpr/NZZILyhAQnAgNpFcF4XmMB0GA1UdDgQWBBQPKssghyi47G9IritUpimq
# F6TNDDAOBgNVHQ8BAf8EBAMCAYYwEgYDVR0TAQH/BAgwBgEB/wIBADATBgNVHSUE
# DDAKBggrBgEFBQcDAzAbBgNVHSAEFDASMAYGBFUdIAAwCAYGZ4EMAQQBMEsGA1Ud
# HwREMEIwQKA+oDyGOmh0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1Ymxp
# Y0NvZGVTaWduaW5nUm9vdFI0Ni5jcmwwewYIKwYBBQUHAQEEbzBtMEYGCCsGAQUF
# BzAChjpodHRwOi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2ln
# bmluZ1Jvb3RSNDYucDdjMCMGCCsGAQUFBzABhhdodHRwOi8vb2NzcC5zZWN0aWdv
# LmNvbTANBgkqhkiG9w0BAQwFAAOCAgEABv+C4XdjNm57oRUgmxP/BP6YdURhw1aV
# cdGRP4Wh60BAscjW4HL9hcpkOTz5jUug2oeunbYAowbFC2AKK+cMcXIBD0ZdOaWT
# syNyBBsMLHqafvIhrCymlaS98+QpoBCyKppP0OcxYEdU0hpsaqBBIZOtBajjcw5+
# w/KeFvPYfLF/ldYpmlG+vd0xqlqd099iChnyIMvY5HexjO2AmtsbpVn0OhNcWbWD
# RF/3sBp6fWXhz7DcML4iTAWS+MVXeNLj1lJziVKEoroGs9Mlizg0bUMbOalOhOfC
# ipnx8CaLZeVme5yELg09Jlo8BMe80jO37PU8ejfkP9/uPak7VLwELKxAMcJszkye
# iaerlphwoKx1uHRzNyE6bxuSKcutisqmKL5OTunAvtONEoteSiabkPVSZ2z76mKn
# zAfZxCl/3dq3dUNw4rg3sTCggkHSRqTqlLMS7gjrhTqBmzu1L90Y1KWN/Y5JKdGv
# spbOrTfOXyXvmPL6E52z1NZJ6ctuMFBQZH3pwWvqURR8AgQdULUvrxjUYbHHj95E
# jza63zdrEcxWLDX6xWls/GDnVNueKjWUH3fTv1Y8Wdho698YADR7TNx8X8z2Bev6
# SivBBOHY+uqiirZtg0y9ShQoPzmCcn63Syatatvx157YK9hlcPmVoa1oDE5/L9Uo
# 2bC5a4CH2RwwggZhMIIEyaADAgECAhEAyDHh+zCQwUNyJV9S6gqqvTANBgkqhkiG
# 9w0BAQwFADBUMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVk
# MSswKQYDVQQDEyJTZWN0aWdvIFB1YmxpYyBDb2RlIFNpZ25pbmcgQ0EgUjM2MB4X
# DTI1MDUyMDAwMDAwMFoXDTI4MDUxOTIzNTk1OVowdzELMAkGA1UEBhMCVVMxDjAM
# BgNVBAgMBVRleGFzMSswKQYDVQQKDCJIZXdsZXR0IFBhY2thcmQgRW50ZXJwcmlz
# ZSBDb21wYW55MSswKQYDVQQDDCJIZXdsZXR0IFBhY2thcmQgRW50ZXJwcmlzZSBD
# b21wYW55MIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA37AD03qwcmuC
# QyxRB2VBM7SfUf0SmpQb8iaPvGmxw5uoDBY3gdC/3Xq/rfM3ndCn03hNdGyucpC7
# tD4zmel6yYqxyXDVr45Jd2cz9jFXoYTOMcuDV6I6CvU/EnbFxWhv0VCp+2Ipz4+u
# JGI6aVlMpFpLbgPjhp9ogd/89HEyi1FkSFoarnvxxaXm93S81k7FD/4EdtvumuGI
# 4V8p39GfbCiMuHku8BzSQ2g86gWFnOaVhY6h4XWvEmE8LPYkU/STrej28FlgkSt9
# f/Jg6+dvRKm92uN2Z760Eql9+DTWkGmGe4YrIyD25XDa07sS9tIpVWzLrGOyecaV
# pJwVVBqCadXDgkgTYKw/UlS+cEqsviT6wREGl4aX/GbeNO6Y4oDTTYkabW3peg1k
# u0v90oDqzoTaWEE5ly2UajvXIgzpFLLXqpR6GYkv/y3ZJV0chBqRtAObebH7XOBa
# 5a2kqMBw0gkIZBJHd8+PCPH/U7eJkeKXtGGj2uTudcGjZgOjVcFYdCRnufJdisrV
# 7bj0Hzghcv3QyRXL3rRjcNb4ccKNnSgF/8cmiTVpvFHTfUKsYdkbM6wsbjXRdJNA
# DjGOYRms7tKsii3/oXO+2S1Um7yomBZQ2+wVRCY6MrRX1onDKid5t5AyWFtRu0aQ
# cdBmHG6JeDiQ3Hrb2g9kZhuFkgABVBkCAwEAAaOCAYkwggGFMB8GA1UdIwQYMBaA
# FA8qyyCHKLjsb0iuK1SmKaoXpM0MMB0GA1UdDgQWBBQH4rUE0gsy8LW2G3vmoYtO
# nZ8zEjAOBgNVHQ8BAf8EBAMCB4AwDAYDVR0TAQH/BAIwADATBgNVHSUEDDAKBggr
# BgEFBQcDAzBKBgNVHSAEQzBBMDUGDCsGAQQBsjEBAgEDAjAlMCMGCCsGAQUFBwIB
# FhdodHRwczovL3NlY3RpZ28uY29tL0NQUzAIBgZngQwBBAEwSQYDVR0fBEIwQDA+
# oDygOoY4aHR0cDovL2NybC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljQ29kZVNp
# Z25pbmdDQVIzNi5jcmwweQYIKwYBBQUHAQEEbTBrMEQGCCsGAQUFBzAChjhodHRw
# Oi8vY3J0LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNDb2RlU2lnbmluZ0NBUjM2
# LmNydDAjBggrBgEFBQcwAYYXaHR0cDovL29jc3Auc2VjdGlnby5jb20wDQYJKoZI
# hvcNAQEMBQADggGBAIax+Yaj5EciDlztft4iAfD2CtIWEF0cxR+UbbvJEs865wyo
# O3ZQoujr0FJ+P5fjDKLbamHrEWmyoD2YC4lzecmnFOnY0y4uJ9zBY8B6X6TU9e6+
# TfZtlXd44YffXYAfoLX+uYjVJcZOaMuXF61+CFpjLJjepsD8m1gdj5QUz2sH6GOf
# U6mEm8SHvKpgPMV/yhEKqgjlenY6Ao49RkxnDuvRlMP8SFPB+8bxiLegEdGaei8n
# Sr/j5YeDZFevUJ696T4W45QGrwAhBBpbKDz6CzlImC1b2C8Bp02XBAsOQs/uCIaQ
# v5XxUmVxmb85tDJkd7QfqHo2z1T2NYMkvXUcSClYRuVxxC/frpqcrxS9O9xEv65B
# oUztAJSXsTdfpUjWeNOnhq8lrwa2XAD3fbagNF6ElsBiNDSbwHCG/iY4kAyaVpbA
# Ytaa6TfzdI/I0EaCX5xYRW56ccI2AnbaEVKz9gVjzi8hBLALlRhrs1uMFtPjnZ+o
# A+rbZZyGZkz3xbUYKTGCGq4wghqqAgEBMGkwVDELMAkGA1UEBhMCR0IxGDAWBgNV
# BAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMgQ29k
# ZSBTaWduaW5nIENBIFIzNgIRAMgx4fswkMFDciVfUuoKqr0wDQYJYIZIAWUDBAIB
# BQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIB
# BDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg
# EnPGJUCzKgE3nQXxC5QQDlO+2q+TKVL7LDcIEe2Dm9gwDQYJKoZIhvcNAQEBBQAE
# ggIAdj+MvoZ2teYH/COp9sfJBoj8pl+hUArLlx32iapGS3ULlihfwsyJWTXiDrC7
# 1pIgLaswLEh2A6fXbLGsG/Yt7ls8gk9hwQr3SjKqqfw5viPA7/7DMITcPMzQM/Hm
# RxcpaH5ykMx9kziPuV1PDPSqN110yJGyFaGaMpMK2WUpHIgtty9XYjKXmojF/6ed
# aFvN7vTVWQvoKPSE6Lvx61dXiaV6vqgO7SZ+6TyB/Hh5MLRSEyxiAoa8SaUDQY/a
# d0RTesmV1rnI5Taw/VRe6DnGZggsDIyRZvZOink1t85HjkYDRuwDSpb7argpU5JW
# vgl5wQwox4aeJrFSdC0Ej4jke5dwCXqwcVOKxDFiabySuX3jgy5191DYZf5mwKq4
# XlRCMBjARGK1ZsocJ0hoQ+vkFcfWU6RN6HbaiMhqMibxbXBaKtEHLZaDtpaYKTlx
# UY+b7i+dna2e4e8E5k6ymSH9xI+p8PxPdAghjZMZzr7rPhuLX2xiqCJiWIxPg5Pe
# r1qpYVQtb7G1xXz5QR/6Y2t207+wXhtMZiGuGgJCSoNnE38o7Cbzxy+2qAHcvs6H
# ilJARKmDZGaqo62qIeoTB/G9zVjP8czu2GpOYcCuXsoCTM4R5cT8E/kJmu5RCRHs
# IbdBFPuFGf64jkxKMPVN4J0onJdSvSdddm4mB7L/V5O41eehgheYMIIXlAYKKwYB
# BAGCNwMDATGCF4QwgheABgkqhkiG9w0BBwKgghdxMIIXbQIBAzEPMA0GCWCGSAFl
# AwQCAgUAMIGIBgsqhkiG9w0BCRABBKB5BHcwdQIBAQYJYIZIAYb9bAcBMEEwDQYJ
# YIZIAWUDBAICBQAEMD9VoFDYhRKbmQt+yjKS78KmoClToJTzRKf4gDc+eKntKSNG
# uQRBFV+lXoays9vDsgIRAIMCeAxOso4vqmK8uH5PhX0YDzIwMjYxMTA0MDgyMzUz
# WqCCEzowggbtMIIE1aADAgECAhAOHrsyK1yKdT4SPyHO0PLZMA0GCSqGSIb3DQEB
# DAUAMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8G
# A1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBT
# SEEyNTYgMjAyNSBDQTEwHhcNMjYwODA1MDAwMDAwWhcNMzcxMTA0MjM1OTU5WjBj
# MQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNVBAMT
# MkRpZ2lDZXJ0IFNIQTM4NCBSU0E0MDk2IFRpbWVzdGFtcCBSZXNwb25kZXIgMjAy
# NiAxMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAxs29k1Tm4JzaUbG7
# JguLFMReom4s+59qCkx6qSHA6RS7nuwbD5Qz4y8ZadGvKnui6kXmZ3g9hVF9H6Vo
# N0BbHLBQ7Qs+CWSdmHqYaWNHOdCzNClMFEFTV8AybOTCPE/xxUuNW0nnyyylklWP
# 6fmUzeitJj7LaDqcZa1n5SKyCqr+wwyEuAWC92E+9aKmM9ZH26cOk3jlc6Jdu6S3
# 8z8x37qD+p15GmR8/t7W7ux2qIssqm7jazSbupnVD8j5lD6cyCrnYtGHuou7bH3c
# 59FbRSMOoL0sDZz01J87b1q76Q/K6jUuKu7UCl7gQbjJUmLaGuI/5NhUZO8VpZDK
# ulpyHjV25hYxsWDMK5OT2Us6MHFj5vdBJSnd0fhXeqq6AVBp8y4aoDbYYPrEYnTd
# TlG+7h9WcXI0yMHUPteIZxqTJgwx3ZkzL2kmd6eQvnm6IKwp/sQ1d+TeMIoJ/wMp
# 7f/9WnChuzENvW5j4LUFkYVzNrjlXIgsgxE3RQnRobStayuM2BNp/PgsLPDwJ7AQ
# iuSCkYL5ikuCzqtwk+DlO0znAkHEflxU77rvjetcC6k6Chvc+PLixXNIeSPR8BJA
# hLO9REVLzlyI0VqiWiPSvBuAdLD4uelqJQV520azq+BjFfcNknHtQcmMYORqPSeB
# OFlkW9pMDvmnJR2Wxl5xps4nQUsCAwEAAaOCAZUwggGRMAwGA1UdEwEB/wQCMAAw
# HQYDVR0OBBYEFItvUpXVe5ErYgmfWkEHh1ALIYySMB8GA1UdIwQYMBaAFO9vU0rp
# 5AZ8esrikFb2L9RJ7MtOMA4GA1UdDwEB/wQEAwIHgDAWBgNVHSUBAf8EDDAKBggr
# BgEFBQcDCDCBlQYIKwYBBQUHAQEEgYgwgYUwJAYIKwYBBQUHMAGGGGh0dHA6Ly9v
# Y3NwLmRpZ2ljZXJ0LmNvbTBdBggrBgEFBQcwAoZRaHR0cDovL2NhY2VydHMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGltZVN0YW1waW5nUlNBNDA5NlNI
# QTI1NjIwMjVDQTEuY3J0MF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly9jcmwzLmRp
# Z2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFRpbWVTdGFtcGluZ1JTQTQwOTZT
# SEEyNTYyMDI1Q0ExLmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1s
# BwEwDQYJKoZIhvcNAQEMBQADggIBACC0vXEC9hZ5PZUAUQc/KivNH8O14Lxm+aeo
# c3T49xrKkw1+0/4kURRUckQECHNW5AMx6vAvmRcLAxQhPCkFoklPXxTNVhq+ocyI
# dTty6p3DHlPoXhWOORdfCH9WHFPSTpkVEcuEna/rOq5MGHd/B8b8tW9VyMBOYK6o
# yM3w/ZOpPOzOJd6uLsEg8AKPh04h6VBwqsxcUhRwy6igtAOpxkC9Z71A4cbJU0Vz
# +4Z143C80QIbErFdOhvbx/rgvS/0c9XmZg50Q3DATk1YY2UJyNv/PDOGZ6phyjRu
# snKbvdfKwXReK1GoYNxyObiXmLSKumcP29O0QgBP3Hjt4h/eDqhmJ4BgFYUsuuqi
# P6zhy0Kvk/1DXS3s+Cwb8zE7Gy73c9Y86y7biFQKiQtbEvZNbX/3B7UUbUrkimyZ
# crndmssumsdwmVR4uQK6WJUbd/5iK2LvgYpMzrF3jLV7+LQ6wlmP8pgXRGWT89Dm
# QnJyHWFydmpPMuOowEvh0DmNZgBtJKB3fS6zuxr4TlbyDLTqYH6RO/+0G+WnzDIe
# HwMsdtphazYRWh/9S7DbMgUei0q7UWZ5vSvSaNNdz41pGVgSGTtPaJQVOpv2bleG
# wEUW0h8sy/WJQ+BnBMvZoGavXYJY+x8iJL3pj7hBXvLZxwOk0itFgZLEkUM+eAH0
# fJERQFwgMIIGtDCCBJygAwIBAgIQDcesVwX/IZkuQEMiDDpJhjANBgkqhkiG9w0B
# AQsFADBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYD
# VQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVk
# IFJvb3QgRzQwHhcNMjUwNTA3MDAwMDAwWhcNMzgwMTE0MjM1OTU5WjBpMQswCQYD
# VQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERpZ2lD
# ZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIwMjUg
# Q0ExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAtHgx0wqYQXK+PEbA
# HKx126NGaHS0URedTa2NDZS1mZaDLFTtQ2oRjzUXMmxCqvkbsDpz4aH+qbxeLho8
# I6jY3xL1IusLopuW2qftJYJaDNs1+JH7Z+QdSKWM06qchUP+AbdJgMQB3h2DZ0Ma
# l5kYp77jYMVQXSZH++0trj6Ao+xh/AS7sQRuQL37QXbDhAktVJMQbzIBHYJBYgzW
# Ijk8eDrYhXDEpKk7RdoX0M980EpLtlrNyHw0Xm+nt5pnYJU3Gmq6bNMI1I7Gb5IB
# ZK4ivbVCiZv7PNBYqHEpNVWC2ZQ8BbfnFRQVESYOszFI2Wv82wnJRfN20VRS3hpL
# gIR4hjzL0hpoYGk81coWJ+KdPvMvaB0WkE/2qHxJ0ucS638ZxqU14lDnki7CcoKC
# z6eum5A19WZQHkqUJfdkDjHkccpL6uoG8pbF0LJAQQZxst7VvwDDjAmSFTUms+wV
# /FbWBqi7fTJnjq3hj0XbQcd8hjj/q8d6ylgxCZSKi17yVp2NL+cnT6Toy+rN+nM8
# M7LnLqCrO2JP3oW//1sfuZDKiDEb1AQ8es9Xr/u6bDTnYCTKIsDq1BtmXUqEG1Nq
# zJKS4kOmxkYp2WyODi7vQTCBZtVFJfVZ3j7OgWmnhFr4yUozZtqgPrHRVHhGNKlY
# zyjlroPxul+bgIspzOwbtmsgY1MCAwEAAaOCAV0wggFZMBIGA1UdEwEB/wQIMAYB
# Af8CAQAwHQYDVR0OBBYEFO9vU0rp5AZ8esrikFb2L9RJ7MtOMB8GA1UdIwQYMBaA
# FOzX44LScV1kTN8uZz/nupiuHA9PMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUEDDAK
# BggrBgEFBQcDCDB3BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6Ly9v
# Y3NwLmRpZ2ljZXJ0LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYDVR0fBDwwOjA4
# oDagNIYyaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJv
# b3RHNC5jcmwwIAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMA0GCSqG
# SIb3DQEBCwUAA4ICAQAXzvsWgBz+Bz0RdnEwvb4LyLU0pn/N0IfFiBowf0/Dm1wG
# c/Do7oVMY2mhXZXjDNJQa8j00DNqhCT3t+s8G0iP5kvN2n7Jd2E4/iEIUBO41P5F
# 448rSYJ59Ib61eoalhnd6ywFLerycvZTAz40y8S4F3/a+Z1jEMK/DMm/axFSgoR8
# n6c3nuZB9BfBwAQYK9FHaoq2e26MHvVY9gCDA/JYsq7pGdogP8HRtrYfctSLANEB
# fHU16r3J05qX3kId+ZOczgj5kjatVB+NdADVZKON/gnZruMvNYY2o1f4MXRJDMdT
# SlOLh0HCn2cQLwQCqjFbqrXuvTPSegOOzr4EWj7PtspIHBldNE2K9i697cvaiIo2
# p61Ed2p8xMJb82Yosn0z4y25xUbI7GIN/TpVfHIqQ6Ku/qjTY6hc3hsXMrS+U0yy
# +GWqAXam4ToWd2UQ1KYT70kZjE4YtL8Pbzg0c1ugMZyZZd/BdHLiRu7hAWE6bTEm
# 4XYRkA6Tl4KSFLFk43esaUeqGkH/wyW4N7OigizwJWeukcyIPbAvjSabnf7+Pu0V
# rFgoiovRDiyx3zEdmcif/sYQsfch28bZeUz2rtY/9TCA6TD8dC3JE3rYkrhLULy7
# Dc90G6e8BlqmyIjlgp2+VqsS9/wQD7yFylIz0scmbKvFoW2jNrbM1pD2T7m3XDCC
# BY0wggR1oAMCAQICEA6bGI750C3n79tQ4ghAGFowDQYJKoZIhvcNAQEMBQAwZTEL
# MAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3
# LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBSb290
# IENBMB4XDTIyMDgwMTAwMDAwMFoXDTMxMTEwOTIzNTk1OVowYjELMAkGA1UEBhMC
# VVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2ljZXJ0
# LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MIICIjANBgkq
# hkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAv+aQc2jeu+RdSjwwIjBpM+zCpyUuySE9
# 8orYWcLhKac9WKt2ms2uexuEDcQwH/MbpDgW61bGl20dq7J58soR0uRf1gU8Ug9S
# H8aeFaV+vp+pVxZZVXKvaJNwwrK6dZlqczKU0RBEEC7fgvMHhOZ0O21x4i0MG+4g
# 1ckgHWMpLc7sXk7Ik/ghYZs06wXGXuxbGrzryc/NrDRAX7F6Zu53yEioZldXn1RY
# jgwrt0+nMNlW7sp7XeOtyU9e5TXnMcvak17cjo+A2raRmECQecN4x7axxLVqGDgD
# EI3Y1DekLgV9iPWCPhCRcKtVgkEy19sEcypukQF8IUzUvK4bA3VdeGbZOjFEmjNA
# vwjXWkmkwuapoGfdpCe8oU85tRFYF/ckXEaPZPfBaYh2mHY9WV1CdoeJl2l6SPDg
# ohIbZpp0yt5LHucOY67m1O+SkjqePdwA5EUlibaaRBkrfsCUtNJhbesz2cXfSwQA
# zH0clcOP9yGyshG3u3/y1YxwLEFgqrFjGESVGnZifvaAsPvoZKYz0YkH4b235kOk
# GLimdwHhD5QMIR2yVCkliWzlDlJRR3S+Jqy2QXXeeqxfjT/JvNNBERJb5RBQ6zHF
# ynIWIgnffEx1P2PsIV/EIFFrb7GrhotPwtZFX50g/KEexcCPorF+CiaZ9eRpL5gd
# LfXZqbId5RsCAwEAAaOCATowggE2MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0OBBYE
# FOzX44LScV1kTN8uZz/nupiuHA9PMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1Ri6en
# IZ3zbcgPMA4GA1UdDwEB/wQEAwIBhjB5BggrBgEFBQcBAQRtMGswJAYIKwYBBQUH
# MAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0cDov
# L2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENBLmNy
# dDBFBgNVHR8EPjA8MDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGln
# aUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMBEGA1UdIAQKMAgwBgYEVR0gADANBgkq
# hkiG9w0BAQwFAAOCAQEAcKC/Q1xV5zhfoKN0Gz22Ftf3v1cHvZqsoYcs7IVeqRq7
# IviHGmlUIu2kiHdtvRoU9BNKei8ttzjv9P+Aufih9/Jy3iS8UgPITtAq3votVs/5
# 9PesMHqai7Je1M/RQ0SbQyHrlnKhSLSZy51PpwYDE3cnRNTnf+hZqPC/Lwum6fI0
# POz3A8eHqNJMQBk1RmppVLC4oVaO7KTVPeix3P0c2PR3WlxUjG/voVA9/HYJaISf
# b8rbII01YBwCA8sgsKxYoA5AY8WYIsGyWfVVa88nq2x2zm8jLfR+cWojayL/ErhU
# LSd+2DrZ8LaHlv1b0VysGMNNn3O3AamfV6peKOK5lDGCA4wwggOIAgEBMH0waTEL
# MAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQDEzhE
# aWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2IFNIQTI1NiAy
# MDI1IENBMQIQDh67MitcinU+Ej8hztDy2TANBglghkgBZQMEAgIFAKCB4TAaBgkq
# hkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI2MTEwNDA4
# MjM1M1owKwYLKoZIhvcNAQkQAgwxHDAaMBgwFgQU6ainI7SFBPXg4UOLZz7Oh88s
# UJswNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgcR3XexwucbJh11WNaZwAd8l9EgMw
# mmCO3BBWNMFQUHswPwYJKoZIhvcNAQkEMTIEMKViWmHvJL2awTA4UiJm21ALa1Fx
# A/cnIx78UNzko/6ty9QiFBmvoJ9of+i5jJ28uzANBgkqhkiG9w0BAQEFAASCAgCb
# c97v0S5TABpKrdgtioNVQtrOTaQI4xbSktSlZDuKeH6Qqo+c22uVrYnmGUhfldKL
# lo1aE4tFdQp22TsYcTUf1CU5TwEEclpy8YvJeBsPmTOLIC3Q72zxAsFge4gCffiC
# bCcWm1cdwHJp83lpTbpfg18ElSdDox38qEqmowcmTAk/Aa9onZVBh+u8Ipr9O5gZ
# jNvQ87V8o7U6njI8T/Z7qouPOS05NbvCKh2fbdYIur9XDSq6KAcTF5qGe8FqU4rk
# SFa0lzHWuY/EDm7YFZiIQjhZDdUD4svvh5l/9nm6dsJQ8Kkh5xHvbNa8DKKur6hn
# 7S1qnPk1uvLyt0mOCWNR41lUg6oLIxnipO9fiPKHInEyaSqMXM0orBOdGoqo8vOJ
# c4ZLpaBJJq3yOP4ioEiOyH90vLJkNf1WPhQFv/imboyiVHlzC9hL9yHsdaYCctLf
# B3Qefxu5ZPRmhjKlIiaJ2gY4Pl57MovTsliZLGvB6H3UwsMG+MfboZLIEijfF+3s
# 3KSilOf9qOxzD88u5FVWC8wRwm/qnXbdWMVQfZGCr+tuQsZAEerDNjk1c10qVdvM
# B6o/N4v26V1u9WI+PLilC+bum9MmUA0z/py5wAsCwmDMiwkDUPSnfbKOo3ZNKNc4
# KHHg+5Ogsdn+63VF2BTuvVqmg1YE/3yW9lJPdHnF5A==
# SIG # End signature block
