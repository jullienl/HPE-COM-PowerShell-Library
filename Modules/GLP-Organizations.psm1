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
# MIIvswYJKoZIhvcNAQcCoIIvpDCCL6ACAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCClQCChRoxZQ0HH
# KUenDP9BC2yGEItj7QEZcL6ZfEen6qCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# nZ+oA+rbZZyGZkz3xbUYKTGCHRMwgh0PAgEBMGkwVDELMAkGA1UEBhMCR0IxGDAW
# BgNVBAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMg
# Q29kZSBTaWduaW5nIENBIFIzNgIRAMgx4fswkMFDciVfUuoKqr0wDQYJYIZIAWUD
# BAIBBQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGC
# NwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQx
# IgQgA5j6Cw5gqxmfdI60HXCHDhzOrFAz7Fcrccw5IZtGou8wDQYJKoZIhvcNAQEB
# BQAEggIAk1DmoTLjTKEterOFamYTk+XwwRpsoT65CRM4H3sd+i3S8PJW4nwbDzEz
# 81BS5RglAJVr+eTXpdmIYxV8Q+L0uVy1Iv9CZBdvkj7qQvOlp2g67JV1bjwOlUIv
# TRFmOU+OiVM0Qf6wuZjdFVODlSVkfy8HLyZWyb7q1hd1gsof2ZbwllBHwYDiwxEL
# CtkyImIG7UB6uaj82m6o1qchz4pvrCrXU9mhmqrUmtbjFqnJ3+dFQrPOko8fL0q6
# GqeRHbUcUGO1jMYyTsLJTWyo+eN9/1d0fujt8tyq1qZhUAidWNNL/YaRcvlBfYs7
# 60JqNshJVdilQRtMohMyqM8n7H7U6KhgAZh1T4GJZtp7WJD/Jo9GRppfGtGtrmph
# qXdJaOU8zQcW953E1m9oe2HClTFAHKVf7XSldek0XsxT7J2tI9TZEI7l3/X1i0V5
# kUuUs9/MbtRB02B0EaWOKrgjmVmSJkVZhiofwrsb/E4fDZPCyfWKpOiwuZVexpaR
# plulDMctIElFXyyQcxJWrCPivjpR9CHEpJD/htS/xElZqfgsMFIP4zl0EHXsXlKF
# EiSgJFW7xGidVdtX8GRUq7DlvsFPmTPxZY1kVf4mXDa6fKe39h/AsJwHVErB29w+
# r7rxU7NeSNhaa2NJRvzeNmixz3uxQ+0GvwDUsboZqpyFl7iwjwWhghn9MIIZ+QYK
# KwYBBAGCNwMDATGCGekwghnlBgkqhkiG9w0BBwKgghnWMIIZ0gIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBCAYLKoZIhvcNAQkQAQSggfgEgfUwgfICAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQw4VOKp2Sfe/WvFgClqdSUvYzwG92tPtqIgOmd
# yU3kwVY9TXOQuWsJx9VM2uxZRGy6AhUA7JSNXGoUQ+BlmDX2h482pIOKIeEYDzIw
# MjYwNjI2MTM0NzI5WqB2pHQwcjELMAkGA1UEBhMCR0IxFzAVBgNVBAgTDkdyZWF0
# ZXIgTG9uZG9uMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxMDAuBgNVBAMTJ1Nl
# Y3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgU2lnbmVyIFIzN6CCFBcwggbiMIIE
# yqADAgECAhEA507yVbBQT/rbpt/3/IujFTANBgkqhkiG9w0BAQwFADBVMQswCQYD
# VQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSwwKgYDVQQDEyNTZWN0
# aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIENBIFI0MTAeFw0yNjAzMjUwMDAwMDBa
# Fw0zNzA2MjQyMzU5NTlaMHIxCzAJBgNVBAYTAkdCMRcwFQYDVQQIEw5HcmVhdGVy
# IExvbmRvbjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMTAwLgYDVQQDEydTZWN0
# aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIFNpZ25lciBSMzcwggIiMA0GCSqGSIb3
# DQEBAQUAA4ICDwAwggIKAoICAQCy/8NtS9xQ2UUtBRF32bj7VK3n4m50Uqjk/zTc
# iSziYV40H1LKah0/oEklYG42E4VCP3DvsBUB6DmpCkDZ0jCnZBPIEevaH15ZJOQw
# FWP2ZXr5YjlJpb68Nlbs+ElNvKx32/1YHde3qqUSLybjulxPLz6T85+HOIqK7M1B
# ep8LspyhEP/q6nw5kGxTSrGvufmeH+JF8CnVBcVMFA40FlIYh0cDJVFhhfTfdWgL
# y/vWuLMQoKkf3s/FvByf16r0rtbyHm/iemwxSioJL9zyZDDKUNAbHXl0dhXo2VxU
# V2NcPXWXuoKsjL+6cfk6Vm2DHnxAlFdFsaBDIF1JOkSnC6PeLlBznZn2buF3vIIY
# Jcq6N/zeFRCk4/HXDz7zgRsRRMdUB+rhyk5FoZaBjw0nLq3GZ3fClLUx5es5pUAx
# zNODMBn7JkFYip2BAGBPER5eV0ROhk6tGTG+fUiMiV+vgjg1YnP5FvnYWyEtWeQD
# /B2hp3vz0RvtdkM0p3igyadzrfpOBq5ppVk/YsuhTQkP99ivneHAGfi5e7lmxJ+m
# eoBPrRLuzMmb81rzzbESjJHMsn5RVtc6Ucs7rcMqQC13PUIO7BbGBETV2ufCmV6l
# PTp3P7XJOvmnUCRTPbVvMTpxP/z+SOHg4/OCBhiqs4FA9+4oQvlkk9w32NGASli9
# GWrm5wIDAQABo4IBjjCCAYowHwYDVR0jBBgwFoAUOnSlDGfGQlDC/bX8x7spNIL0
# erkwHQYDVR0OBBYEFGEQ6XoSr1HEhdTyz6R0D1DNIK/4MA4GA1UdDwEB/wQEAwIG
# wDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMEoGA1UdIARD
# MEEwCAYGZ4EMAQQCMDUGDCsGAQQBsjEBAgEDCDAlMCMGCCsGAQUFBwIBFhdodHRw
# czovL3NlY3RpZ28uY29tL0NQUzBKBgNVHR8EQzBBMD+gPaA7hjlodHRwOi8vY3Js
# LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdDQVI0MS5jcmww
# egYIKwYBBQUHAQEEbjBsMEUGCCsGAQUFBzAChjlodHRwOi8vY3J0LnNlY3RpZ28u
# Y29tL1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdDQVI0MS5jcnQwIwYIKwYBBQUH
# MAGGF2h0dHA6Ly9vY3NwLnNlY3RpZ28uY29tMA0GCSqGSIb3DQEBDAUAA4ICAQAD
# 6j2N0azN+hl6k6bKB5/U6VuSOs93ZBb3Pczy9VtBIKu4947Z5GwL0aFngIxl+GSu
# LFrJgPruBCRvKJEJsm7kv+LQ1COVCEG9tZ+IRtr4ocUoa53lgdFaENlS0N4wgkZk
# bQEPv+x+1lSjYh+T4JeL9mUznT7Erc6Sp5dWLka5sMP/m3GZi6oJPdPcsCKWagH7
# m2H2xDGIyHJC5PdH9phvi/KmhkktiSVTNNqVeV5bWdX2zhRE6UTfz0IcMoCL996l
# FIydXxOCE4MNDHDM0as4lnTiT/KHMccO6l8c9TnUVgmpci9ar1IABZ2U1XUkYjGG
# Sn9MC3EHDP9V39VuBVvZ33/BEV/EWSRrf07T7jFplKX+gQr/UOqPGMlE7ZJ72UaU
# kNJy7bVl3bcLKzdpjIHzLkf/4MVa1V7w8wqCv5W4gOnRGTlud5UMARbRM8BPxR/C
# XYXoMmIOD8pmTk2axgRL4LG8XtuchISdCHRmtacAmLGq5XSYSVTHTXADlO48iDKh
# 3HM2r98LSF6f0sG12d8V9Jn7C3wDUieOxuKj4MdWrW+hiJU2kF87v6eH00HgCFFc
# 2V0+CvfOCMn7juzS41jLaINcBlKWQ/fKb/uDLfWOW73z1I2lFY7Xj8tQ1XYtK5eR
# EjWItM8jpl1cbQOc88btR+0XS2TmboE/141+va2PWzCCBqcwggSPoAMCAQICEQCQ
# rAhyIP3Fp8RrXMcN9z0GMA0GCSqGSIb3DQEBDAUAMFcxCzAJBgNVBAYTAkdCMRgw
# FgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGlj
# IFRpbWUgU3RhbXBpbmcgUm9vdCBSNDYwHhcNMjYwMzI1MDAwMDAwWhcNNDEwMzI0
# MjM1OTU5WjBVMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVk
# MSwwKgYDVQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIENBIFI0MTCC
# AiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK7kSqIBrYIcYvlmLVuaA8zw
# 1RfBhkn4G1CoemzjcYtML6yNUvKmwGH7y6/5MuSC1UYP/+9KYDSqvMQt/1hEKHYx
# MAD9oZpBkoaDQFEKbOJHelsKe+BaO0ZcENTKfePcraVkA7wrGAW2XHA5gQCQv4IK
# ori/3PNOXxnDMOk8yIMgVrlMeTxqfWJ4XkjT1xc2s9DD7URHWWJOFobTPoWs6mrD
# FlaY9FlAHDYTfbzvxQHVsvRmn3W+5ZmCwyk02I8KgGPT/UX4sTz41GiR+ppwUjQX
# a1+2tEHZbsdAKUtH3OPEVtZvlt7atx4h83IdRR8oYi8wjY3OjFKXFecWpQbzzsPx
# bUKPwMWiTrzwkrFa8dH/1pDKRJt371W62PfqKPayCr/XbnBOlRn8CALSmHnRtGzu
# AWtTJpcT3BKw6oy8IIL6wSbu938F6ZIbRNIc1dKbIJtr4ULN6R5ZfTdNEhwXctqp
# 3RHDbg4fuOl6LjNoaFwjud92EEDhzxFJzE1jqN4csceZIwxOT1aqfsfh0uFQE/lg
# TBuBs3i6/WL2W1OceWLy3XEdXRK1f0EWCuea6dNfX2RRdjUfk5EltFnJkN2+bWhn
# K14OPRKcyjOv5hKZ0iV4NRNd1+hjtva1rPyzb5Bs7EvFxqEQhgZbOq7qH3nm0rBw
# A0dxniBOYCFPdu246JCxAgMBAAGjggFuMIIBajAfBgNVHSMEGDAWgBT2d2rdP/0B
# E/8WoWyCAi/QCj0UJTAdBgNVHQ4EFgQUOnSlDGfGQlDC/bX8x7spNIL0erkwDgYD
# VR0PAQH/BAQDAgGGMBIGA1UdEwEB/wQIMAYBAf8CAQAwEwYDVR0lBAwwCgYIKwYB
# BQUHAwgwIwYDVR0gBBwwGjAIBgZngQwBBAIwDgYMKwYBBAGyMQECAQMIMEwGA1Ud
# HwRFMEMwQaA/oD2GO2h0dHA6Ly9jcmwuc2VjdGlnby5jb20vU2VjdGlnb1B1Ymxp
# Y1RpbWVTdGFtcGluZ1Jvb3RSNDYuY3JsMHwGCCsGAQUFBwEBBHAwbjBHBggrBgEF
# BQcwAoY7aHR0cDovL2NydC5zZWN0aWdvLmNvbS9TZWN0aWdvUHVibGljVGltZVN0
# YW1waW5nUm9vdFI0Ni5wN2MwIwYIKwYBBQUHMAGGF2h0dHA6Ly9vY3NwLnNlY3Rp
# Z28uY29tMA0GCSqGSIb3DQEBDAUAA4ICAQAy3lJHZvGeA2b43yhzoarvobHVzbfl
# +RfuPDwej0wCQkYAN6scTt2GwFe22qbOCv/tllqFlLKQZE+E9jVyuPTbyQHwrM7R
# 0oLapAEDC1+CowsqSRf/ptira5Pfd4PoHICnb9coPQtyZmHSQp5y9IGvqWf1qNfq
# 7V2fHZ8DvEQrLUzeoGF9BJRYu2OzacW3QQtUum3NOVf0gPRwv6I4991uhncJ6VP4
# lcpUpHZKB7R3hiIUC09mR9KjzPVnXHvL9n2bAwiUECfK5Zezhiw27F2tgi39DETf
# U8M4n0N6xLgFzsf05M5GURX8C9+IX9V6kpmmKtrUzMti4LD66gtmf+mSm934K81N
# L6YQeMEk1rpYrWPypcW76Mir6wb1AgseLIHqn/GkeuQm7zOTDf3f5WoX14qVNjZW
# NHF3JxkutV6ZnhinfCLfdv5bnwKWUfceqOajCVntI6uCbHxjBg6SCsexc5AfIGno
# 7gVFvwifT4XONPsSUaJ71XsJ+EvciVUVnjOO4qxm0fWJTd8a7jP8mc4ZPqwJvQFt
# Op7+6G+kUJAF0fnE8YgD8uttBReNTa1YmAeFMiqc38e8fI4eLm0zjM/eeGCHasno
# qqrbGwcF41iz9HXzFDwN4iD5z3QShp6HRiU3UpTwDJiiXcr0z6pjl7PyzJ3/tmWt
# GehV7CAfc/WlyzCCBoIwggRqoAMCAQICEDbCsL18Gzrno7PdNsvJdWgwDQYJKoZI
# hvcNAQEMBQAwgYgxCzAJBgNVBAYTAlVTMRMwEQYDVQQIEwpOZXcgSmVyc2V5MRQw
# EgYDVQQHEwtKZXJzZXkgQ2l0eTEeMBwGA1UEChMVVGhlIFVTRVJUUlVTVCBOZXR3
# b3JrMS4wLAYDVQQDEyVVU0VSVHJ1c3QgUlNBIENlcnRpZmljYXRpb24gQXV0aG9y
# aXR5MB4XDTIxMDMyMjAwMDAwMFoXDTM4MDExODIzNTk1OVowVzELMAkGA1UEBhMC
# R0IxGDAWBgNVBAoTD1NlY3RpZ28gTGltaXRlZDEuMCwGA1UEAxMlU2VjdGlnbyBQ
# dWJsaWMgVGltZSBTdGFtcGluZyBSb290IFI0NjCCAiIwDQYJKoZIhvcNAQEBBQAD
# ggIPADCCAgoCggIBAIid2LlFZ50d3ei5JoGaVFTAfEkFm8xaFQ/ZlBBEtEFAgXcU
# manU5HYsyAhTXiDQkiUvpVdYqZ1uYoZEMgtHES1l1Cc6HaqZzEbOOp6YiTx63ywT
# on434aXVydmhx7Dx4IBrAou7hNGsKioIBPy5GMN7KmgYmuu4f92sKKjbxqohUSfj
# k1mJlAjthgF7Hjx4vvyVDQGsd5KarLW5d73E3ThobSkob2SL48LpUR/O627pDchx
# ll+bTSv1gASn/hp6IuHJorEu6EopoB1CNFp/+HpTXeNARXUmdRMKbnXWflq+/g36
# NJXB35ZvxQw6zid61qmrlD/IbKJA6COw/8lFSPQwBP1ityZdwuCysCKZ9ZjczMqb
# UcLFyq6KdOpuzVDR3ZUwxDKL1wCAxgL2Mpz7eZbrb/JWXiOcNzDpQsmwGQ6Stw8t
# TCqPumhLRPb7YkzM8/6NnWH3T9ClmcGSF22LEyJYNWCHrQqYubNeKolzqUbCqhSq
# mr/UdUeb49zYHr7ALL8bAJyPDmubNqMtuaobKASBqP84uhqcRY/pjnYd+V5/dcu9
# ieERjiRKKsxCG1t6tG9oj7liwPddXEcYGOUiWLm742st50jGwTzxbMpepmOP1mLn
# JskvZaN5e45NuzAHteORlsSuDt5t4BBRCJL+5EZnnw0ezntk9R8QJyAkL6/bAgMB
# AAGjggEWMIIBEjAfBgNVHSMEGDAWgBRTeb9aqitKz1SA4dibwJ3ysgNmyzAdBgNV
# HQ4EFgQU9ndq3T/9ARP/FqFsggIv0Ao9FCUwDgYDVR0PAQH/BAQDAgGGMA8GA1Ud
# EwEB/wQFMAMBAf8wEwYDVR0lBAwwCgYIKwYBBQUHAwgwEQYDVR0gBAowCDAGBgRV
# HSAAMFAGA1UdHwRJMEcwRaBDoEGGP2h0dHA6Ly9jcmwudXNlcnRydXN0LmNvbS9V
# U0VSVHJ1c3RSU0FDZXJ0aWZpY2F0aW9uQXV0aG9yaXR5LmNybDA1BggrBgEFBQcB
# AQQpMCcwJQYIKwYBBQUHMAGGGWh0dHA6Ly9vY3NwLnVzZXJ0cnVzdC5jb20wDQYJ
# KoZIhvcNAQEMBQADggIBAA6+ZUHtaES45aHF1BGH5Lc7JYzrftrIF5Ht2PFDxKKF
# Oct/awAEWgHQMVHol9ZLSyd/pYMbaC0IZ+XBW9xhdkkmUV/KbUOiL7g98M/yzRyq
# UOZ1/IY7Ay0YbMniIibJrPcgFp73WDnRDKtVutShPSZQZAdtFwXnuiWl8eFARK3P
# mLqEm9UsVX+55DbVIz33Mbhba0HUTEYv3yJ1fwKGxPBsP/MgTECimh7eXomvMm0/
# GPxX2uhwCcs/YLxDnBdVVlxvDjHjO1cuwbOpkiJGHmLXXVNbsdXUC2xBrq9fLrfe
# 8IBsA4hopwsCj8hTuwKXJlSTrZcPRVSccP5i9U28gZ7OMzoJGlxZ5384OKm0r568
# Mo9TYrqzKeKZgFo0fj2/0iHbj55hc20jfxvK3mQi+H7xpbzxZOFGm/yVQkpo+ffv
# 5gdhp+hv1GDsvJOtJinJmgGbBFZIThbqI+MHvAmMmkfb3fTxmSkop2mSJL1Y2x/9
# 55S29Gu0gSJIkc3z30vU/iXrMpWx2tS7UVfVP+5tKuzGtgkP7d/doqDrLF1u6Ci3
# TpjAZdeLLlRQZm867eVeXED58LXd1Dk6UvaAhvmWYXoiLz4JA5gPBcz7J311uahx
# CweNxE+xxxR3kT0WKzASo5G/PyDez6NHdIUKBeE3jDPs2ACc6CkJ1Sji4PKWVT0/
# MYIEkzCCBI8CAQEwajBVMQswCQYDVQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBM
# aW1pdGVkMSwwKgYDVQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIENB
# IFI0MQIRAOdO8lWwUE/626bf9/yLoxUwDQYJYIZIAWUDBAICBQCgggH6MBoGCSqG
# SIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjYwNjI2MTM0
# NzI5WjA/BgkqhkiG9w0BCQQxMgQwK8Ivtqb682H6pp/g9hqaDCV5/ZGyIcK4ULL0
# huzfrBUq5ClrPWhl7EAzrfyUP/mvMIIBewYLKoZIhvcNAQkQAgwxggFqMIIBZjCC
# AWIwFgQU6XgYqSjaFQqf4b+czHqruaAO7qwwgYgEFGXDKGlvfU5QLP0Dx8IGlxjK
# +/dPMHAwW6RZMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0
# ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgUm9vdCBS
# NDYCEQCQrAhyIP3Fp8RrXMcN9z0GMIG8BBSFPWMtk4KCYXzQkDXEkd6SwULaxzCB
# ozCBjqSBizCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5ldyBKZXJzZXkxFDAS
# BgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNFUlRSVVNUIE5ldHdv
# cmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNhdGlvbiBBdXRob3Jp
# dHkCEDbCsL18Gzrno7PdNsvJdWgwDQYJKoZIhvcNAQEBBQAEggIAS2vMqYrkz2DH
# Kc7+++ze3Pa3/eFeMO4E14TgMJlvSvlDUf0Q/zDlWKLNHNG3mIxwlZQmW09bwddT
# DJf9t82WbIaX6/PcTMXiqmocIplYbSwZ3vTz0yP7XtjF2Aoy4zuA6a0eGlpgJGfc
# Ed0+PRP0pPF5gB8FS5pe9t0+iB13DDhSyTarVn6awBSwmzyvCH/i4wgeGETiXRlx
# /eBHSf3WNGuD7Ru3xJezF319F78OkTkEjjyy8h2yYATOMDBqjWzJEvX5l4RCRGqM
# 5l0yGnOebjYM/gqNjq/q9RzwEXWuvd702aIdmBPxSpBDQVKzQG2HhQVOIU85Nj+m
# EE9Fg9+Xu6EkpZUXUEo+Tl/B/ZT59INxYjW16IaafB7QhKHoJLSHfL73//kNIlJu
# xaI4YXV+vBjWpuThDhjeeSd6qJdZpe4OlRSEELa6R/aLzARkI7IDV1W0TVqHBzKt
# CxTNytbeoheiq2vuXf/bKtiOZWmLlydp0LkuEdzq1j4xOOIm0xgXL9DIaFNTWncF
# fZJy5UKNtnUZxLt/X+QLxKo+KCShZUqHQjNlAAJdNKx/Ik+EE6zy3V8usiEedYLD
# 0Fxe5vnGHd3qhlRoz5yuUrM4LISOjNm4pLkkHkahT9shuWFjcHzVUqQfNdfnXfqM
# iR92fMwZwQ70R+p2pKlFwMh4vnzwA1E=
# SIG # End signature block
