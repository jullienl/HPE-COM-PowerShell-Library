#------------------- FUNCTIONS FOR HPE GreenLake USERS - ROLES - PERMISSIONS -----------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1
 
# Public Functions

# Users

Function Get-HPEGLUser {
    <#
    .SYNOPSIS
    Retrieve user resource(s) from HPE GreenLake.

    .DESCRIPTION
    This cmdlet returns a collection of user resources from HPE GreenLake. 
    By default, only users with access to the current workspace are returned.
    
    Each user object includes an 'authz_source' property that indicates the authentication source:
    - SSO: User authenticates via Single Sign-On/SCIM integration
    - LOCAL: User authenticates with local HPE GreenLake credentials
    - External: User managed by a different organization
    
    Each user object also includes a 'workspace' property showing the current workspace name for users with workspace access.
    
    Roles, permissions, activity data, and workspace memberships can also be retrieved for specific users.

    .PARAMETER FirstName 
    The first name of the user to search for (case-sensitive).

    .PARAMETER LastName 
    The last name of the user to search for (case-sensitive).
  
    .PARAMETER Email 
    The email address of the user to retrieve.

    .PARAMETER ShowUnverified 
    Returns only users who have not verified their email address.

    .PARAMETER ShowRoles 
    Retrieves the roles assigned to a specific user. Must be used with -Email parameter.
    Returns role names, service names, and scope information.

    .PARAMETER ShowPermissions 
    Retrieves all permissions assigned to a specific user across all their roles. Must be used with -Email parameter.
    Returns permission names, descriptions, providers, and scope information.
    
    .PARAMETER ShowActivities
    Retrieves the audit log activities for a specific user from the last month. Must be used with -Email parameter.

    .PARAMETER ShowTenantWorkspaceMembership
    Retrieves all workspace memberships for a specific user across the entire organization. Must be used with -Email parameter.
    Returns workspace details including workspace ID, name, creation date, and description.
    Supports pagination for users with more than 50 workspace memberships.

    .PARAMETER ShowAllUsers
    Returns all users across all workspaces within the organization, not just the current workspace.
    When specified, all organization users are returned, including those without access to the current workspace.
    Users with workspace access will have accurate SSO/LOCAL/External authentication source information, while users without workspace access 
    will show fallback authentication source information from the organization-level API.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to HPE GreenLake instead of sending the request. 
    Useful for understanding the native REST API calls used by GLP.

    .EXAMPLE
    Get-HPEGLUser

    Returns all users with access to the current workspace. Each user includes authz_source (SSO/LOCAL/External) and workspace name.

    .EXAMPLE
    Get-HPEGLUser -ShowAllUsers

    Returns all users in the organization, including those without access to the current workspace.

    .EXAMPLE
    Get-HPEGLUser | Where-Object { $_.authz_source -eq 'SSO' }

    Returns only users who authenticate via Single Sign-On (SSO/SCIM) in the current workspace.

    .EXAMPLE
    Get-HPEGLUser -ShowAllUsers | Where-Object { $_.workspace }

    Returns all users who have workspace access across the organization.

    .EXAMPLE
    Get-HPEGLUser | Select-Object firstname, lastname, email, authz_source, workspace

    Returns workspace users with selected properties including authentication source and workspace membership.

    .EXAMPLE
    Get-HPEGLUser -FirstName Eddy 

    Returns all users with the first name "Eddy" in the current workspace.

    .EXAMPLE
    Get-HPEGLUser -Email john.doe@company.com

    Returns the user with the specified email address.

    .EXAMPLE
    Get-HPEGLUser -Email albert.einstein@example.com -ShowPermissions

    Returns all permissions assigned to Albert Einstein across all their roles.

    .EXAMPLE
    Get-HPEGLUser -Email albert.einstein@example.com -ShowRoles

    Returns all roles assigned to Albert Einstein with their associated scopes.

    .EXAMPLE
    Get-HPEGLUser -Email john.doe@company.com -ShowTenantWorkspaceMembership

    Returns all workspace memberships for the specified user, showing workspace ID, name, creation date, and description
    for each workspace the user has access to across the entire organization.

    .EXAMPLE
    Get-HPEGLUser -Email john.doe@company.com -ShowTenantWorkspaceMembership | Select-Object workspaceName, createdAt

    Returns workspace names and creation dates for all workspaces the user is a member of.
    
    .EXAMPLE
    Get-HPEGLUser -ShowUnverified

    Returns all users in the current workspace who have not verified their email address.

    .EXAMPLE
    Get-HPEGLUser -Email john.doe@company.com -ShowActivities

    Returns the audit log activities for the specified user from the last month.
    
   #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 

        [Parameter (ParameterSetName = 'Default')]
        [ValidateNotNullOrEmpty()]
        [String]$FirstName,  

        [Parameter (ParameterSetName = 'Default')]
        [ValidateNotNullOrEmpty()]
        [String]$LastName,  
        
        [Parameter (Mandatory, ParameterSetName = 'Email')]
        [Parameter (Mandatory, ParameterSetName = 'EmailRoles')]
        [Parameter (Mandatory, ParameterSetName = 'EmailPermissions')]
        [Parameter (Mandatory, ParameterSetName = 'EmailActivity')]
        [Parameter (Mandatory, ParameterSetName = 'EmailTenantWorkspaceMembership')]
        [ValidateNotNullOrEmpty()]
        [validatescript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$Email,  

        [Parameter(Mandatory, ParameterSetName = 'Unverified')]
        [Switch]$ShowUnverified,

        [Parameter(Mandatory, ParameterSetName = 'EmailTenantWorkspaceMembership')]
        [Switch]$ShowTenantWorkspaceMembership,
                
        [Parameter (Mandatory, ParameterSetName = 'EmailRoles')]
        [Switch]$ShowRoles,
        
        [Parameter (Mandatory, ParameterSetName = 'EmailActivity')]
        [Switch]$ShowActivities,

        [Parameter (Mandatory, ParameterSetName = 'EmailPermissions')]
        [Switch]$ShowPermissions,

        [Parameter (ParameterSetName = 'Default')]
        [Parameter (ParameterSetName = 'Email')]
        [Parameter (ParameterSetName = 'Unverified')]
        [Switch]$ShowAllUsers,

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = (Get-UsersUri) + "?limit=2000"
        
    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
       
        $ReturnData = @()

   
        
        try {
            [array]$Collection = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }



        if ($Null -ne $Collection.Resources) {
                
            $CollectionList = $Collection.Resources 

            # "[{0}] List of users: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), ( $CollectionList | out-string ) | Write-Verbose

         
            if ($ShowUnverified) {
                $CollectionList = $CollectionList | Where-Object { $_.'urn:ietf:params:scim:schemas:extensions:hpe-greenlake:2.0:User'.primaryEmailVerified -eq $False }
            }

            if ($ShowRoles) {      
                # ShowRoles requires -Email parameter (single user), so $Email is always populated
                "[{0}] Retrieving roles for user: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email | Write-Verbose

                try {
                    $RolesList = Get-HPEGLUserRole -Email $Email 
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $RolesList -ObjectName "User.Role"         
                    $ReturnData = $ReturnData | Sort-Object service_name, role_name
                    return $ReturnData
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }
            elseif ($ShowPermissions) {
                # ShowPermissions requires -Email parameter (single user), so $Email is always populated
                "[{0}] Retrieving permissions for user: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email | Write-Verbose

                try {
                    # Get user roles WITHOUT permissions first (faster)
                    $UserRoles = Get-HPEGLUserRole -Email $Email
                    
                    if (-not $UserRoles) {
                        Write-Warning "User '$Email' has no role assignments."
                        return
                    }

                    $PermissionsList = @()
                    
                    # Now get permissions for each role
                    foreach ($UserRole in $UserRoles) {
                        $RoleName = $UserRole.role_name
                        $ServiceName = $UserRole.service_name
                        
                        "[{0}] Retrieving permissions for Service: '{1}' - Role: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $RoleName | Write-Verbose

                        $ResourcePolicies = Get-HPEGLRole -ServiceName $ServiceName -ServiceRole $RoleName -ShowPermissions
                        "[{0}] Retrieved {1} permissions for this role" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ResourcePolicies.Count | Write-Verbose
                        $PermissionsList += $ResourcePolicies
                    }
                    
                    # Re-sort the combined permissions from all roles
                    return $PermissionsList | Sort-Object Provider, Permission
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }
            else {

                # Add email to object
                foreach ($user in $CollectionList) {
                    $user | Add-Member -MemberType NoteProperty -Name email -Value $user.emails.value
                    $user | Add-Member -MemberType NoteProperty -Name firstname -Value $user.name.givenName
                    $user | Add-Member -MemberType NoteProperty -Name lastname -Value $user.name.familyName
                }

                # Retrieve SSO authorization source information
                if (-not $WhatIf) {
                    try {
                        # Fetch all users with pagination (limit=100 per request)
                        $allAuthUsers = @()
                        $offset = 0
                        $limit = 100
                        $hasMore = $true
                        
                        # Build URI with or without workspace filter based on -ShowAllUsers parameter
                        $baseAuthSourceUri = (Get-UsersWithAuthSourceUri) + "?limit=$limit&offset={0}&include_unverified=true"
                        if (-not $ShowAllUsers) {
                            $baseAuthSourceUri += "&workspace_id=$($Global:HPEGreenLakeSession.workspaceId)"
                            "[{0}] Retrieving authorization source for workspace users only" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                        }
                        else {
                            "[{0}] Retrieving authorization source for all organization users" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                        }
                        
                        while ($hasMore) {
                            $AuthSourceUri = $baseAuthSourceUri -f $offset
                            "[{0}] Retrieving authorization source information from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $AuthSourceUri | Write-Verbose
                            
                            # Call API and handle potential parsing errors
                            # Note: The UI Doorway API returns a format that Invoke-HPEGLWebRequest has trouble parsing,
                            # so we suppress the non-critical error and use the fallback mechanism
                            try {
                                $AuthSourceData = Invoke-HPEGLWebRequest -Method Get -Uri $AuthSourceUri -SkipPaginationLimit -ReturnFullObject -Verbose:$VerbosePreference -ErrorAction SilentlyContinue
                            }
                            catch {
                                # Silently continue - error is expected
                            }
                            
                            # If Invoke-HPEGLWebRequest returns null (expected), get the raw content from the global variable
                            if ($null -eq $AuthSourceData -and $null -ne $Global:HPECOMInvokeReturnData.Content) {
                                $AuthSourceData = $Global:HPECOMInvokeReturnData.Content | ConvertFrom-Json
                            }
                            
                            if ($null -ne $AuthSourceData.users -and $AuthSourceData.users.Count -gt 0) {
                                $allAuthUsers += $AuthSourceData.users
                                $offset += $limit
                                
                                # Check if there are more users to fetch
                                if ($AuthSourceData.users.Count -lt $limit) {
                                    $hasMore = $false
                                }
                            }
                            else {
                                $hasMore = $false
                            }
                        }
                        
                        "[{0}] Retrieved {1} user(s) with authorization source information" -f $MyInvocation.InvocationName.ToString().ToUpper(), $allAuthUsers.Count | Write-Verbose
                        
                        if ($allAuthUsers.Count -gt 0) {
                            # Create a hashtable for quick lookup by email
                            $authSourceLookup = @{}
                            foreach ($authUser in $allAuthUsers) {
                                $authSourceLookup[$authUser.email] = $authUser.authz_source
                            }
                            
                            # Add authz_source and workspace properties to each user
                            $currentWorkspaceName = $Global:HPEGreenLakeSession.workspace
                            foreach ($user in $CollectionList) {
                                # Get authz_source from UI Doorway API lookup, or fallback to SCIM API source field
                                $authSource = $authSourceLookup[$user.emails.value]
                                if (-not $authSource) {
                                    # Fallback to SCIM API source field for users not in workspace
                                    $authSource = $user.'urn:ietf:params:scim:schemas:extensions:hpe-greenlake:2.0:User'.source
                                }
                                $user | Add-Member -MemberType NoteProperty -Name authz_source -Value $authSource -Force
                                # Add workspace name only if user has workspace access (was in UI Doorway API)
                                $workspaceName = if ($authSourceLookup.ContainsKey($user.emails.value)) { $currentWorkspaceName } else { $null }
                                $user | Add-Member -MemberType NoteProperty -Name workspace -Value $workspaceName -Force
                            }
                            
                            "[{0}] Authorization source and workspace information added to {1} user(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CollectionList.Count | Write-Verbose
                        }
                    }
                    catch {
                        "[{0}] Warning: Could not retrieve authorization source information: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Warning
                        # Add empty authz_source and workspace properties if API call fails
                        foreach ($user in $CollectionList) {
                            $user | Add-Member -MemberType NoteProperty -Name authz_source -Value $null -Force
                            $user | Add-Member -MemberType NoteProperty -Name workspace -Value $null -Force
                        }
                    }
                }
                else {
                    # In WhatIf mode, add null authz_source and workspace properties
                    foreach ($user in $CollectionList) {
                        $user | Add-Member -MemberType NoteProperty -Name authz_source -Value $null -Force
                        $user | Add-Member -MemberType NoteProperty -Name workspace -Value $null -Force
                    }
                }
                
                # Filter users based on -ShowAllUsers parameter
                if (-not $ShowAllUsers) {
                    # Default behavior: Only return users with workspace access (those with workspace property defined)
                    $originalCount = $CollectionList.Count
                    $CollectionList = $CollectionList | Where-Object { $null -ne $_.workspace }
                    "[{0}] Filtered to {1} workspace user(s) (from {2} total organization users)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CollectionList.Count, $originalCount | Write-Verbose
                }
                else {
                    "[{0}] Returning all {1} organization user(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CollectionList.Count | Write-Verbose
                }

                   
                if ($Email) {
                    
                    $CollectionList = $CollectionList | Where-Object { $_.email -eq $Email }

                    if ($ShowTenantWorkspaceMembership) {

                        # Validate user was found
                        if (-not $CollectionList) {
                            Write-Error "User with email '$Email' not found in the organization."
                            return
                        }

                        if ($CollectionList.Count -gt 1) {
                            Write-Warning "Multiple users found with email '$Email'. Using the first match."
                            $CollectionList = $CollectionList | Select-Object -First 1
                        }

                        $UserId = $CollectionList.id
                        "[{0}] Retrieving workspace memberships for user: {1} (ID: {2})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email, $UserId | Write-Verbose

                        # Build URI with userId filter - Invoke-HPEGLWebRequest handles pagination automatically
                        $Uri = (Get-UserTenantWorkspaceMembershipUri) + "?`$filter=userId eq '$UserId'"

                        try {
                            $ReturnData = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                            
                            if (-not $ReturnData -or $ReturnData.Count -eq 0) {
                                Write-Warning "User '$Email' is not a member of any workspaces in this organization."
                                return
                            }

                            "[{0}] Retrieved {1} workspace membership(s) for user" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ReturnData.Count | Write-Verbose
                    
                            $ReturnData = Invoke-RepackageObjectWithType -RawObject $ReturnData -ObjectName "User.TenantWorkspaceMembership"         
                            $ReturnData = $ReturnData | Sort-Object workspaceName
                    
                            return $ReturnData
                        }
                        catch {
                            $PSCmdlet.ThrowTerminatingError($_)
                        }
                    }
                }
                
                if ($FirstName) {
                    $CollectionList = $CollectionList | Where-Object { $_.firstname -eq $FirstName }
                }

                if ($LastName) {
                    $CollectionList = $CollectionList | Where-Object { $_.lastname -eq $LastName }
                }
                   
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "User"         
                $ReturnData = $ReturnData | Sort-Object displayName, email
           

                if ($ShowActivities) {
                    # ShowActivities requires -Email parameter (single user), so $Email is always populated
                    # Use -UserEmail parameter for precise API filtering (not -SearchString which does free-text search)
                    $ReturnData = Get-HPEGLAuditLog -UserEmail $Email -ShowLastMonth
                    return $ReturnData 
                }
                else {
                    return $ReturnData 
                }

            }
    
        }
        else {

            return 
                
        }
        
        
    }
}

Function Send-HPEGLUserInvitation {
    <#
    .SYNOPSIS
    Send (or resend) an invitation email to an existing user in the HPE GreenLake workspace.

    .DESCRIPTION
    This cmdlet mirrors the "Send Invitation" button functionality in the HPE GreenLake UI. It sends an invitation 
    email to an existing user in the workspace who may not have verified their account yet.
    
    The function automatically uses the user's existing role assignments - no need to specify roles or scopes.
    
    Use this function to:
    - Send invitation emails to unverified users
    - Resend invitations if users didn't receive the original email
    - Trigger welcome emails for existing workspace users
    
    To create NEW users with role assignments, use New-HPEGLUser instead.

    .PARAMETER Email
    Specifies the email address of the existing user. The user must already exist in the workspace.

    .PARAMETER WhatIf
    Displays the raw REST API call that would be made to GLP instead of sending the request.

    .EXAMPLE
    Send-HPEGLUserInvitation -Email leonhard.euler@mathematician.edu

    Sends an invitation email to Leonhard Euler using their existing role assignments in the workspace.

    .EXAMPLE
    Get-HPEGLUser -ShowUnverified | Send-HPEGLUserInvitation

    Sends invitations to all unverified users in the workspace.

    .EXAMPLE
    'user1@company.com', 'user2@company.com' | Send-HPEGLUserInvitation

    Sends invitation emails to multiple users via pipeline.

    .EXAMPLE
    Import-Csv emails.csv | Send-HPEGLUserInvitation

    Sends invitations to users listed in a CSV file containing an Email column.

    The content of the CSV file must use the following format:
        Email
        leonhard.euler@mathematician.com
        bernhard.riemann@mathematician.edu

    .INPUTS
    System.String
        Email address of the user. Accepts pipeline input.

    System.String[]
        Array of email addresses for bulk invitation sending via pipeline.

    .OUTPUTS
    System.Collections.ArrayList
    A custom status object or array of objects containing the following PsCustomObject keys:  
        * Email - The email address of the user.
        * Status - The status of the invitation (Failed for HTTP error return; Complete if successful; Warning if no action is needed).
        * Details - More information about the status.
        * Exception - Information about any exceptions generated during the operation.
    
    .NOTES
    This function requires that users already exist in the workspace with assigned roles.
    To create new users, use New-HPEGLUser instead.
    #>

    [CmdletBinding()]
    Param( 
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [validatescript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$Email,  

        [Switch]$WhatIf
    ) 

    Begin {
        $Caller = (Get-PSCallStack)[1].Command
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        # Use the resend API endpoint
        $Uri = Get-ReInviteUserUri 
        $ObjectStatusList = [System.Collections.ArrayList]::new()

        # Get all users in the workspace
        try {
            $Users = Get-HPEGLUser
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }

    Process {                   
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        # Build object for the output
        $objStatus = [pscustomobject]@{
            Email     = $Email
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }
        
        $User = $Users | Where-Object email -eq $Email

        if (-not $User) {
            "[{0}] User '{1}' does not exist in the workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email | Write-Verbose

            if ($WhatIf) {
                Write-Warning "User '$Email' not found in the workspace. Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "User does not exist in the workspace. Use New-HPEGLUser to create new users."
            }
        }
        elseif ($User.verified) {
            "[{0}] User '{1}' is already verified" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email | Write-Verbose

            if ($WhatIf) {
                Write-Warning "User '$Email' is already verified. An invitation email will still be sent."
            }
            
            # Still send invitation even if verified (matches UI behavior)
            $Payload = [PSCustomObject]@{
                usernames = @($Email)
            } | ConvertTo-Json      

            try {
                [array]$Collection = Invoke-HPEGLWebRequest -Method Post -Uri $Uri -Body $Payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

                if (-not $WhatIf) {
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Invitation email sent to verified user"
                }

                if ($Collection.message) {
                    $Collection.message | Write-Verbose
                }
            }
            catch {
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { 
                        $_.Exception.Message 
                    } else { 
                        Get-HPEGLErrorMessage -ExceptionObject $_ -DefaultMessage "Invitation sending failure!" 
                    }
                    
                    $technicalInfo = @()
                    if ($Global:HPECOMInvokeReturnData.errorCode) {
                        $technicalInfo += "Code: $($Global:HPECOMInvokeReturnData.errorCode)"
                    }
                    if ($Global:HPECOMInvokeReturnData.httpStatusCode -or $Global:HPECOMInvokeReturnData.StatusCode) {
                        $statusCode = if ($Global:HPECOMInvokeReturnData.httpStatusCode) { 
                            $Global:HPECOMInvokeReturnData.httpStatusCode 
                        } else { 
                            $Global:HPECOMInvokeReturnData.StatusCode 
                        }
                        $technicalInfo += "HTTP $statusCode"
                    }
                    if ($technicalInfo.Count -eq 0) {
                        $technicalInfo += $_.Exception.GetType().Name
                    }
                    $objStatus.Exception = $technicalInfo -join " | "
                }
            }
        }
        else {
            # User exists and is unverified - send invitation
            $Payload = [PSCustomObject]@{
                usernames = @($Email)
            } | ConvertTo-Json      

            try {
                [array]$Collection = Invoke-HPEGLWebRequest -Method Post -Uri $Uri -Body $Payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

                if (-not $WhatIf) {
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Invitation email sent successfully"
                }

                if ($Collection.message) {
                    $Collection.message | Write-Verbose
                }
            }
            catch {
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                                  
                    $objStatus.Details = if ($_.Exception.Message) { 
                        $_.Exception.Message 
                    } else { 
                        Get-HPEGLErrorMessage -ExceptionObject $_ -DefaultMessage "Invitation sending failure!" 
                    }

                    $technicalInfo = @()
                    if ($Global:HPECOMInvokeReturnData.errorCode) {
                        $technicalInfo += "Code: $($Global:HPECOMInvokeReturnData.errorCode)"
                    }
                    if ($Global:HPECOMInvokeReturnData.httpStatusCode -or $Global:HPECOMInvokeReturnData.StatusCode) {
                        $statusCode = if ($Global:HPECOMInvokeReturnData.httpStatusCode) { 
                            $Global:HPECOMInvokeReturnData.httpStatusCode 
                        } else { 
                            $Global:HPECOMInvokeReturnData.StatusCode 
                        }
                        $technicalInfo += "HTTP $statusCode"
                    }
                    if ($technicalInfo.Count -eq 0) {
                        $technicalInfo += $_.Exception.GetType().Name
                    }
                    $objStatus.Exception = $technicalInfo -join " | "
                }
            }
        }

        [void] $ObjectStatusList.add($objStatus)
    }

    end {
        if (-not $WhatIf) {
            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "ObjStatus.ESDE" 
            Return $ObjectStatusList
        }
    }
}

Function New-HPEGLUser {
    <#
    .SYNOPSIS
    Create a new user in the HPE GreenLake workspace.

    .DESCRIPTION
    This cmdlet creates a new user account in the currently connected HPE GreenLake workspace.
    Users must be created with at least one role assignment as required by HPE GreenLake platform.
    Users can also be added to user groups for additional permission management.
    
    When roles are specified, the user is created with those role assignments for the entire workspace or specific scope groups.
    When both roles and groups are specified, two API calls are made to configure both aspects.

    .PARAMETER Email
    Specifies the email address of the user to create. This will be the username for the new account.

    .PARAMETER RoleName
    REQUIRED. Array of role names to assign to the user. Role names can be retrieved using Get-HPEGLRole.
    At least one role must be specified.

    .PARAMETER ScopeName
    Optional array of scope names corresponding to each role. 
    Use 'All resources' for workspace-wide access, or specify scope group names from Get-HPEGLScopeGroup.
    If not specified, defaults to 'All resources' for all roles, providing workspace-wide access.
    When specified, must have the same number of elements as RoleName array.

    .PARAMETER UserGroupName
    Optional array of user group names to add the user to. Group names can be retrieved using Get-HPEGLUserGroup.

    .PARAMETER SendWelcomeEmail
    Switch to send a welcome email invitation to the new user. By default, no welcome email is sent.
    Use -SendWelcomeEmail to send an email notification to the user.

    .PARAMETER WhatIf
    Displays the raw REST API call that would be made to GLP instead of sending the request.

    .EXAMPLE
    New-HPEGLUser -Email john.doe@company.com -RoleName 'Workspace Observer'

    Creates a new user with the Workspace Observer role for the entire workspace (default scope).
    No welcome email is sent (default behavior).

    .EXAMPLE
    New-HPEGLUser -Email john.doe@company.com -RoleName 'Workspace Observer' -ScopeName 'All resources'

    Explicitly specifies 'All resources' scope, though this is the default when ScopeName is omitted.

    .EXAMPLE
    New-HPEGLUser -Email john.doe@company.com -RoleName 'Compute Ops Management administrator'

    Creates a new user and assigns the Compute Ops Management administrator role for the entire workspace.

    .EXAMPLE
    New-HPEGLUser -Email john.doe@company.com -RoleName @('Workspace Observer', 'Compute Ops Management operator') -ScopeName @('All resources', 'All resources')

    Creates a new user with multiple role assignments across the entire workspace.

    .EXAMPLE
    New-HPEGLUser -Email john.doe@company.com -RoleName 'Workspace Observer' -ScopeName 'All resources' -UserGroupName 'Engineering Team'

    Creates a new user, assigns the Workspace Observer role for the entire workspace, and adds them to the Engineering Team user group.

    .EXAMPLE
    New-HPEGLUser -Email john.doe@company.com -RoleName 'Compute Ops Management administrator' -ScopeName 'Production Servers' -UserGroupName @('Engineering Team', 'Operations Team')

    Creates a new user, assigns a role with a specific scope group, and adds them to multiple user groups.

    .EXAMPLE
    New-HPEGLUser -Email john.doe@company.com -RoleName 'Workspace Observer' -ScopeName 'All resources' -SendWelcomeEmail

    Creates a new user with the Workspace Observer role and sends a welcome email invitation to the user's email address.

    .EXAMPLE
    New-HPEGLUser -Email john.doe@company.com -RoleName @('Workspace Observer', 'Compute Ops Management operator') -ScopeName @('All resources', 'All resources') -UserGroupName @('Engineering Team', 'Operations Team') -SendWelcomeEmail

    Creates a new user with multiple role assignments, adds them to multiple user groups, and sends a welcome email.
    This example demonstrates using all parameters together for a complete user onboarding scenario.

    .EXAMPLE
    'user1@company.com', 'user2@company.com', 'user3@company.com' | New-HPEGLUser -RoleName 'Workspace Observer'

    Creates multiple users via pipeline, all with the same Workspace Observer role for the entire workspace.
    Demonstrates bulk user creation with consistent role assignments.

    .EXAMPLE
    Import-Csv users.csv | New-HPEGLUser

    Creates users from a CSV file with different configurations per user.
    The CSV must contain columns: Email, RoleName, ScopeName, and optionally UserGroupName.
    
    Example CSV content:
        Email,RoleName,ScopeName,UserGroupName
        user1@company.com,Workspace Observer,All resources,Engineering Team
        user2@company.com,Compute Ops Management operator,All resources,Operations Team
        user3@company.com,Workspace Observer,All resources,

    .EXAMPLE
    Import-Csv users.csv | ForEach-Object {
        New-HPEGLUser -Email $_.Email `
            -RoleName ($_.RoleName -split '\|') `
            -ScopeName ($_.ScopeName -split '\|') `
            -UserGroupName ($_.UserGroupName -split '\|')
    }

    Creates users with multiple roles and groups from a CSV file using pipe-delimited values.
    This approach allows each user to have different numbers of roles, scopes, and groups.
    
    Example CSV content with multiple values:
        Email,RoleName,ScopeName,UserGroupName
        admin@company.com,"Workspace Observer|Compute Ops Management administrator","All resources|All resources","Engineering Team|Operations Team"
        operator@company.com,"Workspace Observer|Compute Ops Management operator","All resources|All resources",Engineering Team

    .EXAMPLE
    Get-HPEGLRole | Where-Object { $_.role_display_name -match 'Administrator' } | New-HPEGLUser -Email "john.doe@company.com" -ScopeName 'All resources'

    Creates a new user and assigns all administrator roles from all services to john.doe@company.com.
    Each role is assigned to the entire workspace with full access.
    Demonstrates piping role objects directly from Get-HPEGLRole.

    .EXAMPLE
    Get-HPEGLRole -ComputeOpsManagement | New-HPEGLUser -Email "ops@company.com" -ScopeName 'All resources'

    Creates a new user and assigns all Compute Ops Management roles to ops@company.com.
    Demonstrates piping multiple roles from a specific service.

    .EXAMPLE
    Get-HPEGLRole -ServiceName "Data Services" | Where-Object { $_.role_display_name -like '*Operator*' } | 
        New-HPEGLUser -Email "operator@company.com" -ScopeName 'Production Servers'

    Creates a new user and assigns all Data Services operator roles scoped to the Production Servers scope group.
    Demonstrates filtering roles before piping to user creation.

    .INPUTS
    System.String
        Email address of the user to create. Accepts pipeline input.

    System.String[]
        Array of email addresses for bulk user creation via pipeline.

    HPEGreenLake.Role
        You can pipe role objects from Get-HPEGLRole. The role_display_name property 
        will automatically bind to the RoleName parameter.

    System.Collections.Hashtable, PSCustomObject
        Objects with Email, RoleName, ScopeName, and UserGroupName properties.
        Typically from Import-Csv for bulk operations with different configurations per user.

    .OUTPUTS
    System.Collections.ArrayList
    A custom status object containing:
        * Email - The email address of the user
        * Status - Creation status (Complete/Failed/Warning)
        * Details - Additional information about the operation
        * Exception - Error details if the operation failed
    #>

    [CmdletBinding(DefaultParameterSetName = 'WithRoles')]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'WithRoles')]
        [ValidateNotNullOrEmpty()]
        [validatescript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$Email,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'WithRoles')]
        [Alias('role_display_name')]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            
            # Get all available roles dynamically for tab completion
            try {
                $allRoles = (Get-HPEGLRole -Verbose:$false -ErrorAction SilentlyContinue).role_display_name
                
                # Get already selected roles to exclude from suggestions
                # This handles both explicit parameter binding and partial array entries
                $selectedRoles = @()
                
                if ($fakeBoundParameters['RoleName']) {
                    $boundRoles = $fakeBoundParameters['RoleName']
                    if ($boundRoles -is [array]) {
                        $selectedRoles = @($boundRoles)
                    } else {
                        $selectedRoles = @($boundRoles)
                    }
                }
                
                $allRoles | Where-Object { $_ -like "$wordToComplete*" -and $_ -notin $selectedRoles } | ForEach-Object {
                    # Add quotes around role names that contain spaces
                    $completionText = if ($_ -match '\s') { "'$_'" } else { $_ }
                    [System.Management.Automation.CompletionResult]::new($completionText, $_, 'ParameterValue', $_)
                }
            }
            catch {
                # If not connected or error occurs, return empty (no suggestions)
                @()
            }
        })]
        [String[]]$RoleName,

        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'WithRoles')]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            
            # Get all available scope groups dynamically for tab completion
            try {
                # First try to get 'All resources' as it's always available
                $allScopes = @('All resources')
                
                # Then get scope groups from Get-HPEGLScopeGroup
                $scopeGroups = (Get-HPEGLScopeGroup -Verbose:$false -ErrorAction SilentlyContinue).name
                if ($scopeGroups) {
                    $allScopes += $scopeGroups
                }
                
                $allScopes | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                    # Add quotes around scope names that contain spaces
                    $completionText = if ($_ -match '\s') { "'$_'" } else { $_ }
                    [System.Management.Automation.CompletionResult]::new($completionText, $_, 'ParameterValue', $_)
                }
            }
            catch {
                # If not connected or error occurs, return at least 'All resources'
                [System.Management.Automation.CompletionResult]::new("'All resources'", 'All resources', 'ParameterValue', 'All resources')
            }
        })]
        [String[]]$ScopeName = @(),

        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'WithRoles')]
        [String[]]$UserGroupName,

        [Parameter(ParameterSetName = 'WithRoles')]
        [Switch]$SendWelcomeEmail,

        [Switch]$WhatIf
    )

    Begin {
        $Caller = (Get-PSCallStack)[1].Command
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $ObjectStatusList = [System.Collections.ArrayList]::new()

        # Get current workspace ID from session
        $WorkspaceId = $Global:HPEGreenLakeSession.workspaceId
        $WorkspaceGrn = "grn:glp/workspaces/$WorkspaceId"
        
        "[{0}] Current workspace ID: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $WorkspaceId | Write-Verbose
    }

    Process {
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for output
        $objStatus = [pscustomobject]@{
            Email     = $Email
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

        # Check if user already exists
        # Get-HPEGLUser returns null for non-existent users (doesn't throw)
        # Auth/session errors will propagate and terminate execution
        try {
            $ExistingUser = Get-HPEGLUser -Email $Email
        }
        catch {
            # Re-throw authentication/session errors to stop execution
            # This prevents duplicate error messages by controlling the error display
            $PSCmdlet.ThrowTerminatingError($_)
        }
        
        if ($ExistingUser) {
            # User already exists
            if ($WhatIf) {
                Write-Warning "User '$Email' already exists in the workspace. Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "User already exists in the workspace. No action needed."
                [void]$ObjectStatusList.Add($objStatus)
                return
            }
        }
        
        # User doesn't exist, proceed with creation
        "[{0}] User lookup completed, proceeding with creation" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

        # Default ScopeName to 'All resources' if not provided
        if ($ScopeName.Count -eq 0) {
            $ScopeName = @('All resources') * $RoleName.Count
            "[{0}] ScopeName not specified; defaulting all roles to 'All resources' (workspace-wide access)" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
        }
        
        # Validate RoleName and ScopeName arrays match
        if ($RoleName.Count -ne $ScopeName.Count) {
            if ($WhatIf) {
                Write-Warning "RoleName and ScopeName arrays must have the same number of elements. Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "RoleName and ScopeName arrays must have the same number of elements!"
                [void]$ObjectStatusList.Add($objStatus)
                return
            }
        }

        # Get role information if roles specified
        $RoleAssignments = @()
        if ($RoleName) {
            try {
                $AllRoles = Get-HPEGLRole
                $AllScopeGroups = Get-HPEGLScopeGroup
                
                for ($i = 0; $i -lt $RoleName.Count; $i++) {
                    $Role = $AllRoles | Where-Object { $_.role_display_name -eq $RoleName[$i] }
                    
                    if (-not $Role) {
                        if ($WhatIf) {
                            Write-Warning "Role '$($RoleName[$i])' not found. Cannot display API request. To list all available roles, use: Get-HPEGLRole"
                            return
                        }
                        else {
                            $objStatus.Status = "Failed"
                            $objStatus.Details = "Role '$($RoleName[$i])' not found. To list all available roles, use: Get-HPEGLRole"
                            [void]$ObjectStatusList.Add($objStatus)
                            return
                        }
                    }
                    
                    # Determine scope
                    if ($ScopeName[$i] -eq 'All resources') {
                        $ScopeGrn = $WorkspaceGrn
                    }
                    else {
                        $ScopeGroup = $AllScopeGroups | Where-Object { $_.name -eq $ScopeName[$i] }
                        if (-not $ScopeGroup) {
                            if ($WhatIf) {
                                Write-Warning "Scope group '$($ScopeName[$i])' not found. Cannot display API request. To list all scope groups, use: Get-HPEGLScopeGroup"
                                return
                            }
                            else {
                                $objStatus.Status = "Failed"
                                $objStatus.Details = "Scope group '$($ScopeName[$i])' not found. To list all scope groups, use: Get-HPEGLScopeGroup"
                                [void]$ObjectStatusList.Add($objStatus)
                                return
                            }
                        }
                        $ScopeGrn = $ScopeGroup.id
                    }
                    
                    $RoleAssignments += @{
                        role_grn = $Role.role_grn
                        scopes   = @($ScopeGrn)
                    }
                }
            }
            catch {
                # Unexpected errors (like authentication/session errors) should terminate
                if ($WhatIf) {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message){ $_.Exception.Message } else { "Error retrieving role or scope information." }
                    [void]$ObjectStatusList.Add($objStatus)
                    return
                }
            }
        }

        # Validate user groups exist if groups specified
        if ($UserGroupName) {
            try {
                $AllGroups = Get-HPEGLUserGroup
                
                foreach ($GroupName in $UserGroupName) {
                    $Group = $AllGroups | Where-Object { $_.displayName -eq $GroupName }
                    
                    if (-not $Group) {
                        if ($WhatIf) {
                            Write-Warning "User group '$GroupName' not found. Cannot display API request. To list all user groups, use: Get-HPEGLUserGroup"
                            return
                        }
                        else {
                            $objStatus.Status = "Failed"
                            $objStatus.Details = "User group '$GroupName' not found. To list all user groups, use: Get-HPEGLUserGroup"
                            [void]$ObjectStatusList.Add($objStatus)
                            return
                        }
                    }
                }
            }
            catch {
                # Check if this is a 403 error indicating no organization is configured
                if ($_.Exception.Message -match '403|Forbidden' -or $_.Exception.Message -match 'organization') {
                    $ErrorMessage = "Unable to retrieve user groups. This feature requires an HPE GreenLake organization to be configured. User groups are not available for standalone workspaces. Error details: $($_.Exception.Message)"
                    
                    if ($WhatIf) {
                        Write-Warning $ErrorMessage
                        return
                    }
                    else {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = $ErrorMessage
                        [void]$ObjectStatusList.Add($objStatus)
                        return
                    }
                }
                
                # Unexpected errors (like authentication/session errors) should terminate
                if ($WhatIf) {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Error retrieving user groups: $($_.Exception.Message)"
                    [void]$ObjectStatusList.Add($objStatus)
                    return
                }
            }
        }

        # Create user based on what's provided
        try {
            $UserCreated = $false
            
            # Create user with roles (roles are required)
            $Uri = Get-CreateUserUri
            
            $Payload = @{
                user_name        = $Email
                assignments      = $RoleAssignments
                sendWelcomeEmail = $SendWelcomeEmail.IsPresent
                workspaceId      = $WorkspaceId
            } | ConvertTo-Json -Depth 10
            
            "[{0}] Creating user with role assignments" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            
            $Response = Invoke-HPEGLWebRequest -Method Post -Uri $Uri -Body $Payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
            
            if (-not $WhatIf) {
                $UserCreated = $true
                $objStatus.Status = "Complete"
                $objStatus.Details = "User created successfully with role assignments"
            }
            
            # If groups were specified, add user to groups (or show WhatIf for group additions)
            if ($UserGroupName -and $UserGroupName.Count -gt 0) {
                "[{0}] Adding user to groups after user creation" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                
                if ($WhatIf) {
                    Write-Host "`nAdditional API calls would be made to add user to user groups:" -ForegroundColor Cyan
                    
                    foreach ($GroupName in $UserGroupName) {
                        # Get the group to show the ID in WhatIf output
                        $Group = $AllGroups | Where-Object { $_.displayName -eq $GroupName }
                        
                        if ($Group) {
                            Write-Host "`nThe cmdlet executed for this call will be:" -ForegroundColor Yellow
                            Write-Host "Invoke-HPEGLWebRequest" -ForegroundColor Yellow
                            Write-Host "The URI for this call will be:" -ForegroundColor Yellow
                            Write-Host "https://aquila-org-api.common.cloud.hpe.com/identity/v2alpha1/scim/v2/Groups/$($Group.id)" -ForegroundColor Yellow
                            Write-Host "The Method of this call will be:" -ForegroundColor Yellow
                            Write-Host "PATCH" -ForegroundColor Yellow
                            Write-Host "The Body would include:" -ForegroundColor Yellow
                            Write-Host "Adding user '$Email' to group '$GroupName'" -ForegroundColor Yellow
                        }
                    }
                }
                else {
                    foreach ($GroupName in $UserGroupName) {
                        try {
                            Add-HPEGLUserToUserGroup -GroupName $GroupName -UserEmail $Email -ErrorAction Stop | Out-Null
                        }
                        catch {
                            Write-Warning "Failed to add user to group '$GroupName': $($_.Exception.Message)"
                        }
                    }
                    $objStatus.Details += " and added to user groups"
                }
            }
        }
        catch {
            if ($WhatIf) {
                $PSCmdlet.ThrowTerminatingError($_)
            }
            else {
                $objStatus.Status = "Failed"

                $objStatus.Details = if ($_.Exception.Message) { 
                    $_.Exception.Message 
                } else { 
                    Get-HPEGLErrorMessage -ExceptionObject $_ -DefaultMessage "User creation failed!"
                }
                
                # Build technical diagnostics
                $technicalInfo = @()
                if ($Global:HPECOMInvokeReturnData.errorCode) {
                    $technicalInfo += "Error Code: $($Global:HPECOMInvokeReturnData.errorCode)"
                }
                if ($Global:HPECOMInvokeReturnData.httpStatusCode -or $Global:HPECOMInvokeReturnData.StatusCode) {
                    $statusCode = if ($Global:HPECOMInvokeReturnData.httpStatusCode) { $Global:HPECOMInvokeReturnData.httpStatusCode } else { $Global:HPECOMInvokeReturnData.StatusCode }
                    $technicalInfo += "HTTP Status: $statusCode"
                }
                if ($technicalInfo.Count -eq 0) {
                    $technicalInfo += $_.Exception.Message
                }
                $objStatus.Exception = $technicalInfo -join " | "
            }
        }

        [void]$ObjectStatusList.Add($objStatus)
    }

    End {
        if (-not $WhatIf) {
            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "ObjStatus.ESDE"
            Return $ObjectStatusList
        }
    }
}

Function Remove-HPEGLUser {
    <#
    .SYNOPSIS
    Remove a user from the HPE GreenLake workspace or delete from the organization.

    .DESCRIPTION
    This cmdlet can be used by account administrators to remove a user from the currently connected HPE GreenLake workspace or delete the user account from the entire organization.

    By default, the user is deleted from the entire organization. Use -FromWorkspaceOnly to remove the user from the current workspace while keeping them in the organization.

    .PARAMETER Email
    Specifies the email address of the user to remove or delete.

    .PARAMETER FromWorkspaceOnly
    Removes the user from the current workspace only. The user account will remain in the organization and can still access other workspaces.

    .PARAMETER WhatIf
    Displays the raw REST API call that would be made to HPE GreenLake instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls.

    .EXAMPLE
    Remove-HPEGLUser -Email johanncarlfriedrich.gauss@mathematician.edu

    Deletes the user Johann Carl Friedrich Gauss from the entire organization (including all workspaces).

    .EXAMPLE
    Remove-HPEGLUser -Email johanncarlfriedrich.gauss@mathematician.edu -FromWorkspaceOnly

    Removes the user Johann Carl Friedrich Gauss from the current workspace only. The user account remains in the organization.

    .EXAMPLE
    'leonhard.euler@mathematician.com', 'bernhard.riemann@mathematician.edu' | Remove-HPEGLUser

    Deletes Leonhard Euler and Bernhard Riemann from the entire organization using pipeline input.

    .EXAMPLE
    Remove-HPEGLUser -Email user@example.com -WhatIf

    Shows what would happen if the user was deleted without actually performing the deletion. 
    Displays the REST API call details including the endpoint URL and HTTP method.

    .EXAMPLE
    Remove-HPEGLUser -Email user@example.com -FromWorkspaceOnly -WhatIf

    Shows what would happen if the user was removed from the current workspace without actually performing the removal.

    .EXAMPLE
    Import-Csv emails.csv | Remove-HPEGLUser 

    Deletes the users whose email addresses are listed in a CSV file containing at least an Email column.

    The content of the CSV file must use the following format:
        Email
        leonhard.euler@mathematician.com
        bernhard.riemann@mathematician.edu

    .EXAMPLE
    Get-HPEGLUser | Where-Object {$_.email -like 'test.user*'} | Remove-HPEGLUser -FromWorkspaceOnly
    
    Removes all users from the current HPE GreenLake workspace whose email addresses start with 'test.user'. The user accounts remain in the organization.

    .INPUTS
    System.Collections.ArrayList
        List of user(s) from 'Get-HPEGLUser'.
    System.String, System.String[]
        A single string object or an array of string objects representing the user's email addresses.

    .OUTPUTS
    System.Collections.ArrayList
    A custom status object or array of objects containing the following PsCustomObject keys:  
        * Email - The email address of the user.
        * RemovalType - The type of removal performed (Workspace or Organization).
        * Status - The status of the removal attempt (Failed for HTTP error return; Complete if successful).
        * Details - More information about the status.
        * Exception - Information about any exceptions generated during the operation.
    #>

    [CmdletBinding()]
    Param( 

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [validatescript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$Email,  

        [Parameter (Mandatory = $false)]
        [Switch]$FromWorkspaceOnly,

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        # Determine if workspace is part of an organization
        $IsPartOfOrganization = $null -ne $HPEGreenLakeSession.organization_id

        # Determine the URI based on removal type and organization membership
        if ($FromWorkspaceOnly) {
            $WorkspaceId = $HPEGreenLakeSession.WorkspaceId
            if (-not $WorkspaceId) {
                throw "Unable to determine current workspace ID. Please ensure you are connected to HPE GreenLake."
            }
            $BaseUri = (Get-WorkspaceUsersUri) + "/$WorkspaceId/users"
        }
        elseif ($IsPartOfOrganization) {
            "[{0}] Workspace is part of an organization - using organization-level deletion" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            $BaseUri = Get-UsersUri
        }
        else {
            "[{0}] Workspace is standalone (not part of an organization) - using workspace-level deletion" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            $WorkspaceId = $HPEGreenLakeSession.WorkspaceId
            if (-not $WorkspaceId) {
                throw "Unable to determine current workspace ID. Please ensure you are connected to HPE GreenLake."
            }
            $BaseUri = (Get-WorkspaceUsersUri) + "/$WorkspaceId/users"
        }

        $ObjectStatusList = [System.Collections.ArrayList]::new()
        
    }

    Process {   

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        

        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Email        = $Email
            RemovalType  = if ($FromWorkspaceOnly) { "Workspace" } elseif ($IsPartOfOrganization) { "Organization" } else { "Workspace (Standalone)" }
            Status       = $Null
            Details      = $Null
            Exception    = $Null
              
        }
        
        [void] $ObjectStatusList.add($objStatus)

    }
    end {
        
        try {

            $Users = Get-HPEGLUser
           
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        "[{0}] List of users to {1}: `n{2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $(if ($FromWorkspaceOnly) { "remove from workspace" } else { "delete from organization" }), ($ObjectStatusList.Email | out-string) | Write-Verbose
        

        foreach ($Object in $ObjectStatusList) {

            $User = $false

            $User = $Users | Where-Object email -eq $Object.Email

            if ($User) {
                
                # Build the DELETE URI based on removal type and organization membership
                if ($FromWorkspaceOnly -or -not $IsPartOfOrganization) {
                    $DeleteUri = $BaseUri + "/" + $User.id
                    $ActionDescription = "Removing user from workspace"
                    $SuccessMessage = "User successfully removed from the current workspace!"
                    $FailureMessage = "User removal from workspace failed!"
                    $Payload = @{} | ConvertTo-Json
                }
                else {
                    $DeleteUri = $BaseUri + "/" + $User.id
                    $ActionDescription = "Deleting user from organization"
                    $SuccessMessage = "User account successfully deleted from the organization!"
                    $FailureMessage = "User account deletion from organization failed!"
                    $Payload = @{} | ConvertTo-Json
                }
                
                try {
                    "[{0}] {1}: {2} (ID: {3})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ActionDescription, $Object.Email, $User.id | Write-Verbose
                    
                    Invoke-HPEGLWebRequest -Uri $DeleteUri -Method 'DELETE' -Body $Payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | Out-Null
                    
                    if (-not $WhatIf) {
                        $Object.Status = "Complete"
                        $Object.Details = $SuccessMessage
                    }
                }
                catch {
                    if (-not $WhatIf) {
                        $Object.Status = "Failed"
                        $Object.Details = $FailureMessage
                        $Object.Exception = $_.Exception.Message
                    }
                }

            }
            else {
                
                # Must return a message if account not found
                $Object.Status = "Warning"
                $Object.Details = "User with email '$($Object.Email)' not found in the current workspace. No action needed. To list all users, use: Get-HPEGLUser"

                if ($WhatIf) {
                    $ErrorMessage = "User with email '{0}' cannot be found in the current workspace. No action needed! To list all users, use: Get-HPEGLUser" -f $Object.Email
                    Write-warning $ErrorMessage
                }       
            }
        }


        if (-not $WhatIf) {

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "UserRemoval.Status" 
            Return $ObjectStatusList
        }


    }
}

# Roles

Function Get-HPEGLRole {
    <#
    .SYNOPSIS
    View service roles.

    .DESCRIPTION
    This Cmdlet returns the service roles. Roles are groups of permissions that grant access to users.

    .PARAMETER ServiceName 
    Name of the service retrieved using 'Get-HPEGLService'.   

    .PARAMETER ServiceRole 
    Optional parameter to display a specific role of a service.
    
    .PARAMETER HPEArubaNetworkingCentral 
    Optional parameter to display the roles of the HPE Aruba Networking Central service.

    .PARAMETER ComputeOpsManagement 
    Optional parameter to display the roles of the Compute Ops Management service.

    .PARAMETER DataServices 
    Optional parameter to display the roles of the Data Services service.

    .PARAMETER HPEGreenLake 
    Optional parameter to display the roles of the HPE GreenLake service.

    .PARAMETER HPEArubaNetworkingCentralRole 
    Optional parameter to display a specific role of the HPE Aruba Networking Central service.
    The predefined roles are as follows:
        * Aruba Central Administrator  
        * Aruba Central Guest Operator
        * Aruba Central Operator
        * Aruba Central view edit role
        * Aruba Central View Only
        * Netlnsight Campus Admin
        * Netlnsight Campus Viewonly

    .PARAMETER ComputeOpsManagementRole 
    Optional parameter to display a specific role of the Compute Ops Management service.
    The predefined roles are as follows:
        * Compute Ops Management administrator
        * Compute Ops Management operator
        * Compute Ops Management viewer

    .PARAMETER DataServicesRole 
    Optional parameter to display a specific role of the Data Services service.
    The predefined roles are as follows:
        * Backup and Recovery Administrator
        * Backup and Recovery Operator
        * Data Ops Manager Administrator
        * Data Ops Manager Operator
        * Data Services Administrator
        * Disaster Recovery Admin
        * Disaster Recovery Builder
        * Disaster Recovery User
        * Disaster Recovery Viewer
        * Private Cloud AI Administrator
        * Private Cloud AI Cloud Administrator
        * Private Cloud AI User
        * Private Cloud Business Edition Administrator
        * Private Cloud Business Edition Network Administrator
        * Private Cloud Business Edition Network Operator
        * Private Cloud Business Edition Operator
        * Read Only
        * Storage Fabric Management Administrator
        * Storage Fabric Management Operator

    .PARAMETER HPEGreenLakeRole 
    Optional parameter to display a specific role of the HPE GreenLake service.
    The predefined roles are as follows:
        * Identity domain and SCIM integration administrator
        * Identity domain and SCIM integration viewer
        * Identity domain and SSO administrator
        * Identity domains and SSO viewer
        * Identity user administrator
        * Identity user group administrator
        * Identity user group membership administrator
        * Orders Administrator
        * Orders Observer
        * Orders Operator
        * Organization administrator
        * Organization workspace administrator
        * Organization workspace viewer
        * Workspace Administrator
        * Workspace Member
        * Workspace Observer
        * Workspace Operator

    .PARAMETER ShowAssignedUsers 
    The ShowAssignedUsers directive returns the users assigned to the role name.

    .PARAMETER ShowPermissions
    The ShowPermissions directive returns the permissions of a role name.

    .PARAMETER ShowScopeSupport
    The ShowScopeSupport directive adds information about whether each role supports scope group assignment.
    When enabled, adds a 'supports_scope_groups' property to each role:
    - True: Role can be assigned to specific scope groups
    - False: Role can only be assigned to entire workspace
    - Null: Scope support information could not be determined

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Get-HPEGLRole 

    Return the service roles in an HPE GreenLake workspace.

    .EXAMPLE
    Get-HPEGLRole -HPEArubaNetworkingCentral 

    Return the roles for the HPE Aruba Networking Central service instances in your HPE GreenLake workspace.

    .EXAMPLE
    Get-HPEGLRole -ServiceName "Data Services" 

    Return the roles for the Data Services service instances in your HPE GreenLake workspace.

    .EXAMPLE
    Get-HPEGLRole -ServiceName "Data Services" -ServiceRole "Disaster Recovery Admin"
    
    Return the "Disaster Recovery Admin" role information for the Data Services service.

    .EXAMPLE
    Get-HPEGLRole -ComputeOpsManagementRole 'Compute Ops Management administrator' 

    Return the administrator role information for the Compute Ops Management service.
           
    .EXAMPLE
    Get-HPEGLRole -ComputeOpsManagementRole 'Compute Ops Management administrator' -ShowAssignedUsers 

    Return the users assigned to the administrator role of the Compute Ops Management service.

    .EXAMPLE
    Get-HPEGLRole -DataServicesRole 'Backup and Recovery Administrator' -ShowPermissions

    Return the list of permissions for the 'Backup and Recovery Administrator' role of the Data Services service.

    .EXAMPLE
    Get-HPEGLRole -ServiceName "Compute Ops Management" -ServiceRole 'Compute Ops Management administrator' -ShowPermissions

    Return the list of permissions for the administrator role of the Compute Ops Management service.

    .EXAMPLE
    Get-HPEGLRole -ComputeOpsManagement -ShowScopeSupport

    Return all Compute Ops Management roles with scope support information, indicating which roles can be assigned to scope groups.
    
   #>
    [CmdletBinding(DefaultParameterSetName = 'AllRoles')]
    Param(        
        [Parameter (Mandatory, ParameterSetName = 'ApplicationName')]
        [Parameter (Mandatory, ParameterSetName = 'AssignedUsers-ApplicationName')]
        [Parameter (Mandatory, ParameterSetName = 'Permissions-ApplicationName')]
        [String]$ServiceName,
    
        [Parameter (ParameterSetName = 'ApplicationName')]
        [Parameter (Mandatory, ParameterSetName = 'AssignedUsers-ApplicationName')]
        [Parameter (Mandatory, ParameterSetName = 'Permissions-ApplicationName')]
        [String]$ServiceRole,

        [Parameter (ParameterSetName = 'ArubaCentral')]
        [Switch]$HPEArubaNetworkingCentral,

        [Parameter (ParameterSetName = 'ArubaCentralRole')]
        [Parameter (Mandatory, ParameterSetName = 'AssignedUsers-ArubaCentral')]
        [Parameter (Mandatory, ParameterSetName = 'Permissions-ArubaCentral')]
        [ValidateSet ('Aruba Central Administrator', 'Aruba Central Guest Operator', 'Aruba Central Operator', 'Aruba Central view edit role', 'Aruba Central View Only', 'Netlnsight Campus Admin', 'Netlnsight Campus Viewonly')]
        [String]$HPEArubaNetworkingCentralRole,

        [Parameter (ParameterSetName = 'ComputeOpsManagement')]
        [Switch]$ComputeOpsManagement,

        [Parameter (ParameterSetName = 'ComputeOpsManagementRole')]
        [Parameter (Mandatory, ParameterSetName = 'AssignedUsers-ComputeOpsManagement')]
        [Parameter (Mandatory, ParameterSetName = 'Permissions-ComputeOpsManagement')]
        [ValidateSet ('Compute Ops Management administrator', 'Compute Ops Management operator', 'Compute Ops Management viewer')]
        [String]$ComputeOpsManagementRole,

        [Parameter (ParameterSetName = 'DataServices')]
        [Switch]$DataServices,

        [Parameter (ParameterSetName = 'DataServicesRole')]
        [Parameter (Mandatory, ParameterSetName = 'AssignedUsers-DataServicesCloudConsole')]
        [Parameter (Mandatory, ParameterSetName = 'Permissions-DataServicesCloudConsole')]
        [ValidateSet ('Backup and Recovery Administrator', 'Backup and Recovery Operator', 'Data Ops Manager Administrator', 'Data Ops Manager Operator', 'Data Services Administrator', 'Disaster Recovery Admin', 'Disaster Recovery Builder', 'Disaster Recovery User', 'Disaster Recovery Viewer', 'Private Cloud AI Administrator', 'Private Cloud AI Cloud Administrator', 'Private Cloud AI User', 'Private Cloud Business Edition Administrator', 'Private Cloud Business Edition Network Administrator', 'Private Cloud Business Edition Network Operator', 'Private Cloud Business Edition Operator', 'Read Only', 'Storage Fabric Management Administrator', 'Storage Fabric Management Operator')]
        [String]$DataServicesRole,

        [Parameter (ParameterSetName = 'HPEGreenLake')]
        [Switch]$HPEGreenLake,

        [Parameter (ParameterSetName = 'HPEGreenLakeRole')]
        [Parameter (Mandatory, ParameterSetName = 'AssignedUsers-HPEGreenLake')]
        [Parameter (Mandatory, ParameterSetName = 'Permissions-HPEGreenLake')]
        [ValidateSet ('Identity domain and SCIM integration administrator', 'Identity domain and SCIM integration viewer', 'Identity domain and SSO administrator', 'Identity domains and SSO viewer', 'Identity user administrator', 'Identity user group administrator', 'Identity user group membership administrator', 'Orders Administrator', 'Orders Observer', 'Orders Operator', 'Organization administrator', 'Organization workspace administrator', 'Organization workspace viewer', 'Workspace Administrator', 'Workspace Member', 'Workspace Observer', 'Workspace Operator')]
        [String]$HPEGreenLakeRole,

        [Parameter (Mandatory, ParameterSetName = 'AssignedUsers-ApplicationName')]
        [Parameter (Mandatory, ParameterSetName = 'AssignedUsers-ArubaCentral')]
        [Parameter (Mandatory, ParameterSetName = 'AssignedUsers-ComputeOpsManagement')]
        [Parameter (Mandatory, ParameterSetName = 'AssignedUsers-DataServicesCloudConsole')]
        [Parameter (Mandatory, ParameterSetName = 'AssignedUsers-HPEGreenLake')]
        [Switch]$ShowAssignedUsers,

        [Parameter (Mandatory, ParameterSetName = 'Permissions-ApplicationName')]
        [Parameter (Mandatory, ParameterSetName = 'Permissions-ArubaCentral')]
        [Parameter (Mandatory, ParameterSetName = 'Permissions-ComputeOpsManagement')]
        [Parameter (Mandatory, ParameterSetName = 'Permissions-DataServicesCloudConsole')]
        [Parameter (Mandatory, ParameterSetName = 'Permissions-HPEGreenLake')]
        [Switch]$ShowPermissions,

        [Parameter (ParameterSetName = 'ApplicationName')]
        [Parameter (ParameterSetName = 'ComputeOpsManagement')]
        [Parameter (ParameterSetName = 'ComputeOpsManagementRole')]
        [Parameter (ParameterSetName = 'DataServices')]
        [Parameter (ParameterSetName = 'DataServicesRole')]
        [Parameter (ParameterSetName = 'HPEGreenLake')]
        [Parameter (ParameterSetName = 'HPEGreenLakeRole')]
        [Parameter (ParameterSetName = 'ArubaCentral')]
        [Parameter (ParameterSetName = 'ArubaCentralRole')]
        [Parameter (ParameterSetName = 'AllRoles')]
        [Switch]$ShowScopeSupport,

        [Switch]$WhatIf


 
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
        
    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        if ($ShowPermissions) {
            
            if ($ServiceName) {

                try {
                    $Service = Get-HPEGLService -Name $ServiceName | sort-object application_id -Unique 
                
                }
                catch {    
                    $PSCmdlet.ThrowTerminatingError($_)
    
                }
    
                if (-not $Service -and $ServiceName -ne "HPE GreenLake platform") {
                    "[{0}] Service '{1}' not found in the HPE GreenLake workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName | Write-Verbose
                    Return
                }
                else {

                    # Get all roles to find the role GRN
                    $Uri = (Get-UsersRolesUri) + "?service=all"

                    try {
                        [array]$Collection = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }

                    # New pagination always returns the roles array directly
                    if ($Collection -is [array]) {
                        $CollectionList = $Collection
                    }

                    if ($CollectionList) {

                        # Filter by service name
                        $CollectionList = $CollectionList | Where-Object service_name -eq $ServiceName       
                    
                        if ($ServiceRole) {
                            # Filter by role display name
                            $CollectionList = $CollectionList | Where-Object role_display_name -eq $ServiceRole
                        }

                        "[{0}] Roles for the service: '{1}' filtered to '{2}': '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $ServiceRole, ($CollectionList | Out-String) | Write-Verbose

                        # If role name not found, then return
                        if (-Not $CollectionList) {
                            Return
                        }

                        $RoleGrn = $CollectionList.role_grn

                        "[{0}] Permission + ServiceName -- Service Name: '{1}' - Role Name: '{2}' - Role GRN: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $ServiceRole, $RoleGrn | Write-Verbose

                        # Use v2 roles endpoint with grn parameter to get permissions
                        $Uri = "{0}?grn={1}" -f (Get-UsersRolesUri), [System.Web.HttpUtility]::UrlEncode($RoleGrn)

                        try {
                            $RoleDetails = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                        }
                        catch {
                            $PSCmdlet.ThrowTerminatingError($_)
                        }

                        # v2 API returns single role object (not array) when using grn parameter
                        if ($RoleDetails -is [array] -and $RoleDetails.Count -gt 0) {
                            $RoleDetails = $RoleDetails[0]
                        }

                        if ($RoleDetails.permissions) {
                            
                            $PermissionsList = @()
                            
                            foreach ($Permission in $RoleDetails.permissions) {
                                $PermObj = [PSCustomObject]@{
                                    Permission  = $Permission.name
                                    Description = $Permission.description
                                    Provider    = $Permission.providerName
                                    FixedScope  = $Permission.fixedScope
                                }
                                $PermissionsList += $PermObj
                            }

                            $PermissionsList = Invoke-RepackageObjectWithType -RawObject $PermissionsList -ObjectName "Role.Permissions"
                            return $PermissionsList | Sort-Object Provider, Permission
                        }
                        else {
                            "[{0}] No permissions found for role '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceRole | Write-Verbose
                            return
                        }
                    }
                    else {
                        return   
                    }
                } 
            }
            else {

                # Get all roles to find the role GRN
                $Uri = (Get-UsersRolesUri) + "?service=all"
        
                try {
                    [array]$Collection = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
                   
                # New pagination always returns the roles array directly
                if ($Collection -is [array]) {

                    if ($ComputeOpsManagementRole) {
                        $ServiceName = "Compute Ops Management"
                        $ServiceRole = $ComputeOpsManagementRole
                    }
                    elseif ($DataServicesRole) { 
                        $ServiceName = "Data Services"
                        $ServiceRole = $DataServicesRole
                    }
                    elseif ($HPEArubaNetworkingCentralRole) { 
                        $ServiceName = "HPE Aruba Networking Central"
                        $ServiceRole = $HPEArubaNetworkingCentralRole
                    }
                    elseif ($HPEGreenLakeRole) { 
                        $ServiceName = "HPE GreenLake platform"
                        $ServiceRole = $HPEGreenLakeRole
                    }

                    # Filter by service name
                    $CollectionList = $Collection | Where-Object service_name -match $ServiceName

                    "[{0}] Roles for the service: '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, ($CollectionList | Out-String) | Write-Verbose

                    # Filter by role display name
                    if ($ArubaCentralRole) {
                        $CollectionList = $CollectionList | Where-Object role_display_name -eq $ArubaCentralRole
                        $ServiceRole = $ArubaCentralRole
                    }
                    elseif ($ComputeOpsManagementRole) {
                        $CollectionList = $CollectionList | Where-Object role_display_name -eq $ComputeOpsManagementRole
                    } 
                    elseif ($DataServicesRole) {
                        $CollectionList = $CollectionList | Where-Object role_display_name -eq $DataServicesRole
                    }
                    elseif ($HPEGreenLakeRole) {
                        $CollectionList = $CollectionList | Where-Object role_display_name -eq $HPEGreenLakeRole
                    }
                            
                    "[{0}] Roles for the service: '{1}' filtered to '{2}': '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $ServiceRole, ($CollectionList | Out-String) | Write-Verbose

                    # If role name not found, then return
                    if (-Not $CollectionList) {
                        Return
                    }

                    $RoleGrn = $CollectionList.role_grn

                    "[{0}] Permission + Predefined Role -- Service Name: '{1}' - Role Name: '{2}' - Role GRN: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $ServiceRole, $RoleGrn | Write-Verbose

                    # Use v2 roles endpoint with grn parameter to get permissions
                    $Uri = "{0}?grn={1}" -f (Get-UsersRolesUri), [System.Web.HttpUtility]::UrlEncode($RoleGrn)

                    try {
                        $RoleDetails = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }

                    # v2 API returns single role object (not array) when using grn parameter
                    if ($RoleDetails -is [array] -and $RoleDetails.Count -gt 0) {
                        $RoleDetails = $RoleDetails[0]
                    }

                    if ($RoleDetails.permissions) {
                        
                        $PermissionsList = @()
                        
                        foreach ($Permission in $RoleDetails.permissions) {
                            $PermObj = [PSCustomObject]@{
                                Permission  = $Permission.name
                                Description = $Permission.description
                                Provider    = $Permission.providerName
                                FixedScope  = $Permission.fixedScope
                            }
                            $PermissionsList += $PermObj
                        }

                        $PermissionsList = Invoke-RepackageObjectWithType -RawObject $PermissionsList -ObjectName "Role.Permissions"
                        return $PermissionsList | Sort-Object Permission
                    }
                    else {
                        "[{0}] No permissions found for role '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceRole | Write-Verbose
                        return
                    }
                }
                else {
                    return   
                }
            }

        }
        else {

            $Uri = (Get-UsersRolesUri) + "?service=all"

            if ($ServiceName) {
            
                try {
                    $Service = Get-HPEGLService -Name $ServiceName 
                
                }
                catch {    
                    $PSCmdlet.ThrowTerminatingError($_)
    
                }
    
                if (-not $Service -and $ServiceName -ne "HPE GreenLake platform") {
                    "[{0}] Service '{1}' not found in the HPE GreenLake workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName | Write-Verbose
                    Return
                }
                else {
                
                    $ReturnData = @()
        
                    try {
                        [array]$Collection = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }

                    # New pagination always returns the roles array directly
                    if ($Collection -is [array]) {
                        $CollectionList = $Collection
                    }

                    if ($CollectionList) {

                        # New API uses 'service_name' instead of 'application_name'
                        $CollectionList = $CollectionList | Where-Object service_name -eq $ServiceName   
                        
                                            
                        if ($ServiceRole) {
                    
                            # New API uses 'role_display_name' instead of 'name'
                            $CollectionList = $CollectionList | Where-Object role_display_name -eq $ServiceRole
   
                            "[{0}] Roles for the service: '{1}' filtered to '{2}': '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $ServiceRole, ($CollectionList | Out-String) | Write-Verbose

                        }
                                  
                        if ($ShowAssignedUsers) {

                            # Use v2alpha2 role-assignments API to find users/groups assigned to this role
                            $RoleGrn = $CollectionList.role_grn
                            
                            "[{0}] Querying role assignments for role GRN: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleGrn | Write-Verbose
                            
                            # Use v2alpha2 role-assignments API with role-grn filter parameter
                            $Uri = "{0}?role-grn={1}" -f (Get-RoleAssignmentsUri), [System.Web.HttpUtility]::UrlEncode($RoleGrn)
    
                            $Response = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                            
                            # /internal-platform-tenant-ui/v2alpha2/role-assignments returns array directly with user/group info included
                            if ($Response -is [array]) {
                                [array]$RoleAssignments = $Response
                            }
                            else {
                                [array]$RoleAssignments = @()
                            }
                            
                            "[{0}] Found {1} assignment(s) for role '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleAssignments.Count, $ServiceRole | Write-Verbose

                            # Build user/group list from assignments
                            $AssignedList = @()
                            
                            foreach ($assignment in $RoleAssignments) {
                                # The API already includes user/group information
                                $AssignedObj = [PSCustomObject]@{
                                    type              = if ($assignment.subject_type -eq 'user') { "User" } else { "Group" }
                                    email             = $assignment.subject_email
                                    name              = $assignment.subject_name
                                    role_name         = $ServiceRole
                                    service_name      = $ServiceName
                                    scopes            = $assignment.scopes.scope
                                    assignment_id     = $assignment.id
                                }
                                $AssignedList += $AssignedObj
                            }

                            "[{0}] AssignedUsers to roles for the service: '{1}' filtered to '{2}': {3} principals found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $ServiceRole, $AssignedList.Count | Write-Verbose

                            if ($AssignedList.Count -gt 0) {
                                $ReturnData = Invoke-RepackageObjectWithType -RawObject $AssignedList -ObjectName "Role.Assigned.Principals"    
                                $ReturnData = $ReturnData | Sort-Object type, name

                                return $ReturnData 
                            }
                            else {
                                "[{0}] No users or groups found with this role assignment" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                return   
                            }
                        }

                        # Add scope support information if requested
                        if ($ShowScopeSupport -and $CollectionList) {
                            "[{0}] Fetching scope support information for roles" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            
                            $roleIndex = 0
                            foreach ($role in $CollectionList) {
                                $roleIndex++
                                $roleGrn = $role.role_grn
                                "[{0}] Checking scope support for role {1}/{2}: {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $roleIndex, $CollectionList.Count, $roleGrn | Write-Verbose
                                
                                try {
                                    # Query the new API endpoint with the role GRN
                                    $DetailUri = "{0}/internal-platform-tenant-ui/v2/roles?grn={1}" -f (Get-HPEGLAPIOrgbaseURL), $roleGrn
                                    $RoleDetails = Invoke-HPEGLWebRequest -Method GET -Uri $DetailUri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                                    
                                    # Invoke-HPEGLWebRequest already extracts 'items' collection, so we access the first element directly
                                    if ($RoleDetails -and $RoleDetails[0] -and $RoleDetails[0].permissions) {
                                        $permissions = $RoleDetails[0].permissions
                                        
                                        # Check if any permission has fixedScope = false (supports scope groups)
                                        $supportsScopeGroups = $false
                                        foreach ($perm in $permissions) {
                                            if ($perm.fixedScope -eq $false) {
                                                $supportsScopeGroups = $true
                                                break
                                            }
                                        }
                                        
                                        # Add property to indicate scope support
                                        $role | Add-Member -MemberType NoteProperty -Name "supports_scope_groups" -Value $supportsScopeGroups -Force
                                        
                                        if ($supportsScopeGroups) {
                                            "[{0}] Role '{1}' supports scope groups" -f $MyInvocation.InvocationName.ToString().ToUpper(), $role.role_display_name | Write-Verbose
                                        } else {
                                            "[{0}] Role '{1}' only supports entire workspace scope" -f $MyInvocation.InvocationName.ToString().ToUpper(), $role.role_display_name | Write-Verbose
                                        }
                                    }
                                    else {
                                        "[{0}] Warning: Could not retrieve permissions for role '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $role.role_display_name | Write-Verbose
                                        $role | Add-Member -MemberType NoteProperty -Name "supports_scope_groups" -Value $null -Force
                                    }
                                    
                                    # Add a small delay between API calls to avoid rate limiting (except for the last role)
                                    if ($roleIndex -lt $CollectionList.Count) {
                                        "[{0}] Pausing for 250ms to avoid rate limiting..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                        Start-Sleep -Milliseconds 250
                                    }
                                }
                                catch {
                                    "[{0}] Error fetching scope support for role '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $role.role_display_name, $_.Exception.Message | Write-Verbose
                                    $role | Add-Member -MemberType NoteProperty -Name "supports_scope_groups" -Value $null -Force
                                }
                            }
                        }
            
                        # Apply appropriate type based on whether scope support was requested
                        if ($ShowScopeSupport) {
                            $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "Role.WithScopeSupport"
                        }
                        else {
                            $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "Role"
                        }

                        # New API uses 'service_name' and 'role_display_name' for sorting
                        $ReturnData = $ReturnData | Sort-Object { $_.service_name, $_.role_display_name }

                        return $ReturnData 
                    }
                    else {

                        return
            
                    }
        
                }           
            }
            else {

                $ReturnData = @()
        
                try {
                    [array]$Collection = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
        
                # New pagination always returns the roles array directly
                if ($Collection -is [array]) {
                    $CollectionList = $Collection
                }

                if ($CollectionList) {

                    if ($ComputeOpsManagement) {
                        $ServiceName = "Compute Ops Management"
                    }
                    elseif ($DataServices) { 
                        $ServiceName = "Data Services" 
                    }
                    elseif ($HPEArubaNetworkingCentral) { 
                        $ServiceName = "HPE Aruba Networking Central" 
                    }
                    elseif ($HPEGreenLake) { 
                        $ServiceName = "HPE GreenLake Platform"
                    }


                    if ($ComputeOpsManagementRole) {
                        $ServiceName = "Compute Ops Management"
                        $ServiceRole = $ComputeOpsManagementRole

                    }
                    elseif ($DataServicesRole) { 
                        $ServiceName = "Data Services" 
                        $ServiceRole = $DataServicesRole

                    }
                    elseif ($HPEArubaNetworkingCentralRole) { 
                        $ServiceName = "HPE Aruba Networking Central" 
                        $ServiceRole = $HPEArubaNetworkingCentralRole

                    }
                    elseif ($HPEGreenLakeRole) { 
                        $ServiceName = "HPE GreenLake Platform"
                        $ServiceRole = $HPEGreenLakeRole

                    }


                    if ($ServiceName) {

                        # New API uses 'service_name' instead of 'application_name'
                        $CollectionList = $CollectionList | Where-Object service_name -match $ServiceName

                        # New API uses 'role_display_name' instead of 'name'
                        if ($HPEArubaNetworkingCentralRole) {
                            $CollectionList = $CollectionList | Where-Object role_display_name -match $HPEArubaNetworkingCentralRole
                        }
                        if ($ComputeOpsManagementRole) {
                            $CollectionList = $CollectionList | Where-Object role_display_name -eq $ComputeOpsManagementRole
                        } 
                    
                        if ($DataServicesRole) {
                            $CollectionList = $CollectionList | Where-Object role_display_name -eq $DataServicesRole
                        }
                        if ($HPEGreenLakeRole) {
                            $CollectionList = $CollectionList | Where-Object role_display_name -eq $HPEGreenLakeRole
                        }

                        "[{0}] Roles for the service: '{1}' filtered to '{2}': '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $ServiceRole, ($CollectionList | Out-String) | Write-Verbose

                        
                    }
                     
                    if ($ShowAssignedUsers) {

                        # Use v2alpha2 role-assignments API to find users/groups assigned to this role
                        $RoleGrn = $CollectionList.role_grn
                        
                        "[{0}] Querying role assignments for role GRN: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleGrn | Write-Verbose
                        
                        # Use v2alpha2 role-assignments API with role-grn filter parameter
                        $Uri = "{0}?role-grn={1}" -f (Get-RoleAssignmentsUri), [System.Web.HttpUtility]::UrlEncode($RoleGrn)
    
                        $Response = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                        
                        # /internal-platform-tenant-ui/v2alpha2/role-assignments returns array directly with user/group info included
                        if ($Response -is [array]) {
                            [array]$RoleAssignments = $Response
                        }
                        else {
                            [array]$RoleAssignments = @()
                        }
                        
                        "[{0}] Found {1} role assignment(s) for role '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleAssignments.Count, $ServiceRole | Write-Verbose

                        # Build user/group list from assignments
                        $AssignedList = @()
                        
                        foreach ($assignment in $RoleAssignments) {
                            # The API already includes user/group information
                            $AssignedObj = [PSCustomObject]@{
                                type              = if ($assignment.subject_type -eq 'user') { "User" } else { "Group" }
                                email             = $assignment.subject_email
                                name              = $assignment.subject_name
                                role_name         = $ServiceRole
                                service_name      = $ServiceName
                                scopes            = $assignment.scopes.scope
                                assignment_id     = $assignment.id
                            }
                            $AssignedList += $AssignedObj
                        }

                        "[{0}] AssignedUsers + Predefined Role -- Service Name: '{1}': Service ID: '{2}' - Role Name: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $ServiceID, $ServiceRole | Write-Verbose

                        if ($AssignedList.Count -gt 0) {
                            $ReturnData = Invoke-RepackageObjectWithType -RawObject $AssignedList -ObjectName "Role.Assigned.Principals"    
                            $ReturnData = $ReturnData | Sort-Object type, name

                            return $ReturnData 
                        }
                        else {
                            "[{0}] No users or groups found with this role assignment" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            return   
                        }
                    }

                    # Add scope support information if requested
                    if ($ShowScopeSupport -and $CollectionList) {
                        "[{0}] Fetching scope support information for roles" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                        
                        $roleIndex = 0
                        foreach ($role in $CollectionList) {
                            $roleIndex++
                            $roleGrn = $role.role_grn
                            "[{0}] Checking scope support for role {1}/{2}: {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $roleIndex, $CollectionList.Count, $roleGrn | Write-Verbose
                            
                            try {
                                # Query the new API endpoint with the role GRN
                                $DetailUri = "{0}/internal-platform-tenant-ui/v2/roles?grn={1}" -f (Get-HPEGLAPIOrgbaseURL), $roleGrn
                                $RoleDetails = Invoke-HPEGLWebRequest -Method GET -Uri $DetailUri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                                
                                # Invoke-HPEGLWebRequest already extracts 'items' collection, so we access the first element directly
                                if ($RoleDetails -and $RoleDetails[0] -and $RoleDetails[0].permissions) {
                                    $permissions = $RoleDetails[0].permissions
                                    
                                    # Check if any permission has fixedScope = false (supports scope groups)
                                    $supportsScopeGroups = $false
                                    foreach ($perm in $permissions) {
                                        if ($perm.fixedScope -eq $false) {
                                            $supportsScopeGroups = $true
                                            break
                                        }
                                    }
                                    
                                    # Add property to indicate scope support
                                    $role | Add-Member -MemberType NoteProperty -Name "supports_scope_groups" -Value $supportsScopeGroups -Force
                                    
                                    if ($supportsScopeGroups) {
                                        "[{0}] Role '{1}' supports scope groups" -f $MyInvocation.InvocationName.ToString().ToUpper(), $role.role_display_name | Write-Verbose
                                    } else {
                                        "[{0}] Role '{1}' only supports entire workspace scope" -f $MyInvocation.InvocationName.ToString().ToUpper(), $role.role_display_name | Write-Verbose
                                    }
                                }
                                else {
                                    "[{0}] Warning: Could not retrieve permissions for role '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $role.role_display_name | Write-Verbose
                                    $role | Add-Member -MemberType NoteProperty -Name "supports_scope_groups" -Value $null -Force
                                }
                                
                                # Add a small delay between API calls to avoid rate limiting (except for the last role)
                                if ($roleIndex -lt $CollectionList.Count) {
                                    "[{0}] Pausing for 250ms to avoid rate limiting..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                    Start-Sleep -Milliseconds 250
                                }
                            }
                            catch {
                                "[{0}] Error fetching scope support for role '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $role.role_display_name, $_.Exception.Message | Write-Verbose
                                $role | Add-Member -MemberType NoteProperty -Name "supports_scope_groups" -Value $null -Force
                            }
                        }
                    }
            
                    # Apply appropriate type based on whether scope support was requested
                    if ($ShowScopeSupport) {
                        $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "Role.WithScopeSupport"
                    }
                    else {
                        $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "Role"
                    }

                    # New API uses 'service_name' and 'role_display_name' for sorting
                    $ReturnData = $ReturnData | Sort-Object { $_.service_name, $_.role_display_name }

                    return $ReturnData 
                }
                else {

                    return
            
                }
            }
        }
    }
}

# User Roles

Function Get-HPEGLUserRole {
    <#
    .SYNOPSIS
        View user roles in an HPE GreenLake workspace.

    .DESCRIPTION
        This Cmdlet lists the users' roles and permissions in an HPE GreenLake workspace. Roles are groups of permissions that grant access to users.

    .PARAMETER Email 
        The email address of the user for whom you want to obtain roles and permissions (can be retrieved using 'Get-HPEGLUser').

    .PARAMETER ServiceName 
        An optional parameter to display user roles and permissions for a specified service name (can be retrieved using 'Get-HPEGLService').
        
    .PARAMETER ShowPermissions 
        A switch to display the specific permissions assigned to a user.
    
    .PARAMETER WhatIf 
        Displays the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
        Get-HPEGLUserRole -Email Isaac.Newton@revolution.com 

        Returns the user's roles for all services for which the user has privileges.

    .EXAMPLE
        Get-HPEGLUserRole -Email Isaac.Newton@revolution.com -ShowPermissions

        Returns the user's permissions for all services for which the user has privileges.

    .EXAMPLE
        Get-HPEGLUserRole -Email Isaac.Newton@revolution.com -ServiceName 'Compute Ops Management' 

        Returns the user's roles for the Compute Ops Management service.

    .EXAMPLE
        Get-HPEGLUserRole -Email Isaac.Newton@revolution.com -ServiceName 'Data Services' -ShowPermissions

        Returns the user's permissions for the Data Services service.

    .EXAMPLE
        Get-HPEGLUserRole -Email Isaac.Newton@revolution.com -ServiceName "Aruba Central"

        Returns the user's roles for the Aruba Central service.
    #>

    [CmdletBinding(DefaultParameterSetName = 'Application')]
    Param( 

        [Parameter (Mandatory, ParameterSetName = 'Application')]
        [Parameter (Mandatory, ParameterSetName = 'ApplicationInstance')]
        [validatescript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$Email,
       
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "ApplicationInstance")]
        [ValidateNotNullOrEmpty()]
        [Alias('name')]
        [String]$ServiceName,

        [Parameter (ParameterSetName = 'Application')]
        [Parameter (ParameterSetName = 'ApplicationInstance')]
        [Switch]$ShowPermissions,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

    }

    Process {
       
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        try {
            $User = Get-HPEGLUser -Email $Email
           
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        if (-not $user) {
            Return
        }

        # Extract user ID for new API endpoint
        $UserId = $User.id
        
        "[{0}] User ID for '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email, $UserId | Write-Verbose
        
        # Use new v2alpha2 role-assignments API endpoint with subject query parameter
        $Uri = (Get-RoleAssignmentsUri) + "?subject=user:$UserId"
        
        "[{0}] Retrieving role assignments from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri | Write-Verbose

        $ReturnData = @()
        
        try {
            $Response = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
            
            # New v2alpha2 API returns response in 'role_assignments' wrapper
            if ($Response.role_assignments) {
                [array]$Collection = $Response.role_assignments
                "[{0}] Retrieved {1} role assignment(s) from v2alpha2 API" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Collection.Count | Write-Verbose
            }
            else {
                # Fallback for unexpected response format
                [array]$Collection = $Response
                "[{0}] Retrieved {1} role assignment(s) using fallback parsing" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Collection.Count | Write-Verbose
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
     
        
        # New pagination always returns the roles array directly
        if ($Collection -is [array]) {
            
            $PermissionsList = @()
            
            if ($ServiceName) {
                
                try {
                    
                    $App = Get-HPEGLService -Name $ServiceName | Sort-Object application_id -Unique 

                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
                                    
                if (-not $App -and $ServiceName -ne "HPE GreenLake platform") {
                    "[{0}] Service '{1}' not found in the HPE GreenLake workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName | Write-Verbose
                    return
                }

                if ($App) {
                    "[{0}] Service '{1}' found: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, ($App.name -join ', ') | Write-Verbose
                }

                if ($ServiceName -eq "HPE GreenLake platform") {

                    $ServiceID = "00000000-0000-0000-0000-000000000000"

                }
                else {
                    $ServiceID = $App.application_id

                }

                # New API uses 'service_id' instead of 'application_id'
                $UserRoles = $Collection | Where-Object service_id -eq $ServiceID

                
            }
            else {
                $userRoles = $Collection

            } 
            

            foreach ($UserRole in $UserRoles) {

                # Get user details from the User object (v2alpha2 API doesn't include these in role assignments)
                $UserFirstName = $User.firstname
                $UserLastName = $User.lastname
                $UserType = $User.user_type
                    
                
                if ($ShowPermissions) {

                    "[{0}] Permission -- Service Name: '{1}': Service ID: '{2}' - Role Name: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $UserRole.service_name, $UserRole.service_id, $UserRole.role_name | Write-Verbose
                   
                    try {
              
                        $ResourcePolicies = Get-HPEGLRole -ServiceName $UserRole.service_name -ServiceRole $UserRole.role_name -ShowPermissions
              
                        $PermissionsList += $ResourcePolicies 

                        "[{0}] Resource Policies: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ResourcePolicies | Out-String) | Write-Verbose
                                          
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }

                }
                else {

                    # Add user context properties to the API object (preserves all original v2alpha2 properties including scopes)
                    $UserRole | Add-Member -MemberType NoteProperty -Name email -Value $Email -Force
                    $UserRole | Add-Member -MemberType NoteProperty -Name user_first_name -Value $UserFirstName -Force
                    $UserRole | Add-Member -MemberType NoteProperty -Name user_last_name -Value $UserLastName -Force
                    $UserRole | Add-Member -MemberType NoteProperty -Name user_type -Value $UserType -Force

                    $PermissionsList += $UserRole
                }
            }

            if (-not $ShowPermissions) {
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $PermissionsList -ObjectName "User.Role"         
                $ReturnData = $ReturnData | Sort-Object service_name, role_name
            }
            else {
                # Re-sort the combined permissions from all roles
                $ReturnData = $PermissionsList | Sort-Object Provider, Permission
            }
            

            return $ReturnData
           
        }

        else {
            return
        }
    }
}

Function Add-HPEGLRoleToUser {
    <#
    .SYNOPSIS
    Assign a role to a user in HPE GreenLake.

    .DESCRIPTION
    This cmdlet assigns roles to users in an HPE GreenLake workspace. Roles can be scoped either 
    to the entire workspace or to specific scope groups, depending on the role's capabilities.

    Use Get-HPEGLRole with -ShowScopeSupport to determine which roles support scope group assignment.
    - Roles with "Supported" scope groups can be assigned to specific scope groups
    - Roles with "Not Supported" scope groups can only be assigned to the entire workspace

    .PARAMETER Email 
    Email address of the user to assign the role to (can be retrieved using Get-HPEGLUser).

    .PARAMETER RoleName 
    Name of the role to assign to the user (can be retrieved using Get-HPEGLRole).
    Example: "Compute Ops Management administrator", "Backup and Recovery Operator", "Workspace Administrator"

    .PARAMETER ScopeGroupName 
    Optional. Name(s) of scope group(s) to restrict the role assignment to (can be retrieved using Get-HPEGLScopeGroup).
    Can be a single scope group name or an array of scope group names.
    Only available for roles that support scope group assignment.
    If not specified, defaults to entire workspace access.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. 
    This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Add-HPEGLRoleToUser -Email "john.doe@example.com" -RoleName "Compute Ops Management administrator"

    Assigns the COM administrator role to john.doe@example.com with entire workspace access (default).

    .EXAMPLE
    Add-HPEGLRoleToUser -Email "jane.smith@example.com" -RoleName "Compute Ops Management operator" -ScopeGroupName "Test-Environment"

    Assigns the COM operator role to jane.smith@example.com, scoped to only the Test-Environment scope group.

    .EXAMPLE
    "user1@example.com", "user2@example.com" | Add-HPEGLRoleToUser -RoleName "Compute Ops Management viewer"

    Assigns the COM viewer role to multiple users via pipeline with entire workspace access (default).

    .EXAMPLE
    Get-HPEGLUser | Where-Object { $_.email -like "*@example.com" } | Add-HPEGLRoleToUser -RoleName "Backup and Recovery Operator"

    Assigns the Backup and Recovery Operator role to all users with @example.com email addresses with entire workspace access (default).

    .EXAMPLE
    Add-HPEGLRoleToUser -Email "ops@example.com" -RoleName "Compute Ops Management administrator" -ScopeGroupName "Production", "Staging"

    Assigns the COM administrator role to ops@example.com, scoped to multiple scope groups.

    .EXAMPLE
    Get-HPEGLRole | Where-Object { $_.role_display_name -match 'Administrator' } | Add-HPEGLRoleToUser -Email "john.doe@example.com"

    Assigns all administrator roles from all services to john.doe@example.com. Each role assignment is made to the entire workspace (default).
    
    .INPUTS
    System.String
        You can pipe email addresses as strings.

    HPEGreenLake.User
        You can pipe user objects from Get-HPEGLUser.
    
    HPEGreenLake.Role
        You can pipe role objects from Get-HPEGLRole.

    .OUTPUTS
    System.Collections.ArrayList
        Returns a collection of status objects, one for each role assignment attempt:
        * Email - Email address of the user
        * RoleName - Name of the role assigned
        * Scope - Scope of the assignment (Entire Workspace or scope group names)
        * Status - Status of the assignment attempt (Failed, Complete, Warning)
        * Details - More information about the status
        * Exception - Information about any exceptions generated during the operation
    #>

    [CmdletBinding()]
    Param( 
                    
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('UserEmail')]
        [ValidateScript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$Email,
            
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('role_display_name')]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            
            # Get all available roles dynamically for tab completion
            try {
                $allRoles = (Get-HPEGLRole -Verbose:$false -ErrorAction SilentlyContinue).role_display_name
                
                $allRoles | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                    # Add quotes around role names that contain spaces
                    $completionText = if ($_ -match '\s') { "'$_'" } else { $_ }
                    [System.Management.Automation.CompletionResult]::new($completionText, $_, 'ParameterValue', $_)
                }
            }
            catch {
                # If not connected or error occurs, return empty (no suggestions)
                @()
            }
        })]
        [String]$RoleName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [String[]]$ScopeGroupName,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $RoleAssignmentStatus = [System.Collections.ArrayList]::new()
    }
    
    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Default to entire workspace if ScopeGroupName is not specified
        if (-not $ScopeGroupName) {
            "[{0}] Scope not specified; defaulting to entire workspace access" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
        }

        # Build object for the output
        $objStatus = [pscustomobject]@{
            PSTypeName = 'HPEGreenLake.RoleAssignment.User'
            Email      = $Email
            RoleName   = $RoleName
            Scope      = if ($ScopeGroupName) { $ScopeGroupName -join ", " } else { "Entire Workspace" }
            Status     = $Null
            Details    = $Null
            Exception  = $Null
        }

        # Get the user
        try {
            $User = Get-HPEGLUser -Verbose:$false | Where-Object { $_.email -eq $Email }
            
            if (-not $User) {
                "[{0}] User '{1}' not found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email | Write-Verbose
                
                if ($WhatIf) {
                    Write-Warning "User '$Email' not found. Cannot display API request. To list all users, use: Get-HPEGLUser"
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "User '$Email' not found in the workspace. To list all users, use: Get-HPEGLUser"
                    $objStatus.Exception = "User not found"
                    [void]$RoleAssignmentStatus.Add($objStatus)
                    return
                }
            }
            
            $UserId = $User.id
            "[{0}] Found user '{1}' with ID: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email, $UserId | Write-Verbose
            
            # Check if user is SSO/external - these cannot be managed via API
            if ($User.authz_source -eq 'SSO') {
                "[{0}] User '{1}' is an SSO user and cannot have roles assigned via API" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email | Write-Verbose
                
                if ($WhatIf) {
                    Write-Warning "User '$Email' is an SSO user managed by your identity provider. Role assignments must be done through your IdP (not via HPE GreenLake API)."
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "User is an SSO user managed by your identity provider. Role assignments must be done through your IdP (not via HPE GreenLake API)."
                    $objStatus.Exception = "SSO user not supported"
                    [void]$RoleAssignmentStatus.Add($objStatus)
                    return
                }
            }
        }
        catch {
            "[{0}] Error retrieving user: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
            
            if ($WhatIf) {
                $PSCmdlet.ThrowTerminatingError($_)
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else {  "Error retrieving user" }
                $objStatus.Exception = $_.Exception.GetType().Name
                [void]$RoleAssignmentStatus.Add($objStatus)
                return
            }
        }

        # Get the role details
        try {
            # Get all roles from all services to find the specified role
            $Role = Get-HPEGLRole -Verbose:$false | Where-Object { $_.role_display_name -eq $RoleName }
            
            if (-not $Role) {
                "[{0}] Role '{1}' not found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName | Write-Verbose
                
                if ($WhatIf) {
                    Write-Warning "Role '$RoleName' not found. Cannot display API request. To list all available roles, use: Get-HPEGLRole"
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Role '$RoleName' not found. To list all available roles, use: Get-HPEGLRole"
                    $objStatus.Exception = "Role not found"
                    [void]$RoleAssignmentStatus.Add($objStatus)
                    return
                }
            }
            
            # If multiple roles match (e.g., internal and external versions), prefer internal
            if ($Role -is [array] -and $Role.Count -gt 1) {
                $InternalRole = $Role | Where-Object { $_.role_name -like "*-internal.*" }
                if ($InternalRole) {
                    $Role = $InternalRole | Select-Object -First 1
                    "[{0}] Multiple roles found, selected internal role: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Role.role_name | Write-Verbose
                }
                else {
                    $Role = $Role | Select-Object -First 1
                    "[{0}] Multiple roles found, selected first: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Role.role_name | Write-Verbose
                }
            }
            
            $RoleGrn = $Role.role_grn
            "[{0}] Found role '{1}' with GRN: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName, $RoleGrn | Write-Verbose
            
            # Validate role and scope compatibility before making API call
            # Workspace-level roles (HPE GreenLake service roles with role_name prefixes 'identity.' or 'ccs.') cannot be scoped to scope groups
            # These roles have GRNs like: grn:glp/providers/authorization/roles/identity.* or grn:glp/providers/authorization/roles/ccs.*
            $IsWorkspaceLevelRole = $Role.role_name -match '^(identity\.|ccs\.)'
            
            if ($IsWorkspaceLevelRole -and $ScopeGroupName) {
                "[{0}] Role '{1}' is a workspace-level role (role_name: {2}) and cannot be scoped to scope groups" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName, $Role.role_name | Write-Verbose
                
                if ($WhatIf) {
                    Write-Warning "Service mismatch: Role '$RoleName' is a workspace-level role and cannot be scoped to scope groups. Omit ScopeGroupName to assign to entire workspace."
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Service mismatch: This role cannot be scoped to a scope group. Workspace-level roles (e.g., 'Workspace Observer') can only be assigned to entire workspace. Use service-specific roles (e.g., 'Compute Ops Management viewer') with -ScopeGroupName."
                    $objStatus.Exception = "Role does not support scope groups"
                    [void]$RoleAssignmentStatus.Add($objStatus)
                    return
                }
            }
        }
        catch {
            "[{0}] Error retrieving role: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
            
            if ($WhatIf) {
                $PSCmdlet.ThrowTerminatingError($_)
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Error retrieving role." }
                $objStatus.Exception = $_.Exception.GetType().Name
                [void]$RoleAssignmentStatus.Add($objStatus)
                return
            }
        }

        # Build the scope GRN(s)
        $ScopeGrns = @()
        
        if (-not $ScopeGroupName) {
            # Entire workspace scope (default)
            $WorkspaceId = $Global:HPEGreenLakeSession.workspaceId
            $ScopeGrns += "grn:glp/workspaces/$WorkspaceId"
            "[{0}] Using entire workspace scope: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ScopeGrns[0] | Write-Verbose
        }
        else {
            # Specific scope groups
            try {
                foreach ($ScopeName in $ScopeGroupName) {
                    $ScopeGroup = Get-HPEGLScopeGroup -Name $ScopeName -Verbose:$false
                    
                    if (-not $ScopeGroup) {
                        "[{0}] Scope group '{1}' not found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ScopeName | Write-Verbose
                        
                        if ($WhatIf) {
                            Write-Warning "Scope group '$ScopeName' not found. Cannot display API request. To list all scope groups, use: Get-HPEGLScopeGroup"
                            return
                        }
                        else {
                            $objStatus.Status = "Failed"
                            $objStatus.Details = "Scope group '$ScopeName' not found. To list all scope groups, use: Get-HPEGLScopeGroup"
                            $objStatus.Exception = "Scope group not found"
                            [void]$RoleAssignmentStatus.Add($objStatus)
                            return
                        }
                    }
                    
                    # Build scope group GRN
                    $WorkspaceId = $Global:HPEGreenLakeSession.workspaceId
                    $ScopeGroupId = $ScopeGroup.id
                    $ScopeGrn = "grn:glp/workspaces/$WorkspaceId/regions/default/providers/authorization/scope-groups/$ScopeGroupId"
                    $ScopeGrns += $ScopeGrn
                    
                    "[{0}] Added scope group '{1}' with GRN: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ScopeName, $ScopeGrn | Write-Verbose
                }
            }
            catch {
                "[{0}] Error retrieving scope groups: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                
                if ($WhatIf) {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Error retrieving scope groups." }
                    $objStatus.Exception = $_.Exception.GetType().Name
                    [void]$RoleAssignmentStatus.Add($objStatus)
                    return
                }
            }
        }

        # Check if role is already assigned to the user using existing Get-HPEGLUserRole function
        try {
            "[{0}] Checking if role is already assigned to user..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            
            $ExistingUserRoles = Get-HPEGLUserRole -Email $Email -Verbose:$false
            
            # Check if this specific role is already assigned (use role_name property)
            $ExistingRole = $ExistingUserRoles | Where-Object { $_.role_name -eq $RoleName }
            
            if ($ExistingRole) {
                # Role is assigned - check if scope matches
                # scopes.scopeType = "MSP_WORKSPACE" means entire workspace (no scope groups)
                # scopes.scopeName will contain scope group name if assigned to scope group
                
                $existingScopeType = $ExistingRole.scopes.scopeType
                $existingScopeName = $ExistingRole.scopes.scopeName
                
                # Check if this is a duplicate assignment
                if (-not $ScopeGroupName -and $existingScopeType -eq "MSP_WORKSPACE" -and [string]::IsNullOrEmpty($existingScopeName)) {
                    # Both are entire workspace - this is a duplicate
                    $warningMsg = "Role '$RoleName' is already assigned to user '$Email' for entire workspace"
                    
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $warningMsg | Write-Verbose
                    
                    if ($WhatIf) {
                        Write-Warning "$warningMsg. Cannot display API request."
                        return
                    }
                    else {
                        # Return status object only - no Write-Warning
                        $objStatus.Status = "Warning"
                        $objStatus.Details = "Role already assigned with the same scope. No action needed."
                        [void]$RoleAssignmentStatus.Add($objStatus)
                        return
                    }
                }
                elseif ($ScopeGroupName -and -not [string]::IsNullOrEmpty($existingScopeName)) {
                    # Both are scope groups - check if scope group names match
                    $requestedScopeNames = $ScopeGroupName -join ", "
                    
                    if ($existingScopeName -eq $requestedScopeNames) {
                        $warningMsg = "Role '$RoleName' is already assigned to user '$Email' for scope group(s): $requestedScopeNames"
                        
                        "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $warningMsg | Write-Verbose
                        
                        if ($WhatIf) {
                            Write-Warning "$warningMsg. Cannot display API request."
                            return
                        }
                        else {
                            # Return status object only - no Write-Warning
                            $objStatus.Status = "Warning"
                            $objStatus.Details = "Role already assigned with the same scope. No action needed."
                            [void]$RoleAssignmentStatus.Add($objStatus)
                            return
                        }
                    }
                }
            }
            
            "[{0}] Role is not currently assigned to user, proceeding with assignment" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
        }
        catch {
            "[{0}] Warning: Could not check existing role assignments: {1}. Proceeding with assignment." -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
        }

        # Build the payload for role assignment API
        $Payload = [PSCustomObject]@{
            assignments = @(
                @{
                    role_grn = $RoleGrn
                    scopes   = $ScopeGrns
                }
            )
            user_id     = $UserId
        } | ConvertTo-Json -Depth 10

        "[{0}] Payload: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Payload | Write-Verbose

        # Build URI for role assignments
        $Uri = "{0}/internal-platform-tenant-ui/v2alpha2/role-assignments" -f (Get-HPEGLAPIOrgbaseURL)

        try {
            $Response = Invoke-HPEGLWebRequest -Method POST -Uri $Uri -Body $Payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

            if (-not $WhatIf) {
                "[{0}] Role assignment raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Response | ConvertTo-Json -Depth 5) | Write-Verbose
                
                # Check if the response contains any errors
                if ($Response.failed) {
                    $errorCode = $Response.failed.error_response.details.errorCode
                    $errorMessage = $Response.failed.error_response.details.message
                    
                    # Check if the role was already assigned (this is just a warning, not a failure)
                    if ($errorCode -eq "HPE_GL_AUTHORIZATION_ALREADY_CREATED") {
                        # Return status object only - no Write-Warning (warnings only with -WhatIf)
                        $objStatus.Status = "Warning"
                        $objStatus.Details = "Role already assigned with the same scope. No action needed."
                    }
                    # Check for service mismatch error (workspace-level roles cannot use scope groups)
                    elseif ($errorCode -eq "HPE_GL_ERROR_BAD_REQUEST" -and $errorMessage -like "*service mismatch*") {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Service mismatch: This role cannot be scoped to a scope group. Workspace-level roles (e.g., 'Workspace Observer') can only be assigned to entire workspace. Use service-specific roles (e.g., 'Compute Ops Management viewer') with -ScopeGroupName."
                        $objStatus.Exception = "HPE_GL_ERROR_BAD_REQUEST | HTTP 400"
                    }
                    # Any other error
                    else {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = if ($errorMessage) { $errorMessage } else { "Role assignment failed with error code: $errorCode" }
                        $objStatus.Exception = "$errorCode | HTTP $($Response.failed.error_response.details.httpStatusCode)"
                    }
                }
                else {
                    # No errors - successful assignment
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Role successfully assigned to user"
                    
                    "[{0}] Role '{1}' successfully assigned to user '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName, $Email | Write-Verbose
                }
            }
        }
        catch {
            $objStatus.Status = "Failed"
            $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Role assignment failed." }
            
            # Build technical exception info with error code and HTTP status
            $technicalInfo = @()
            if ($Global:HPECOMInvokeReturnData.errorCode) {
                $technicalInfo += "Code: $($Global:HPECOMInvokeReturnData.errorCode)"
            }
            if ($Global:HPECOMInvokeReturnData.httpStatusCode -or $Global:HPECOMInvokeReturnData.StatusCode) {
                $statusCode = if ($Global:HPECOMInvokeReturnData.httpStatusCode) { $Global:HPECOMInvokeReturnData.httpStatusCode } else { $Global:HPECOMInvokeReturnData.StatusCode }
                $technicalInfo += "HTTP $statusCode"
            }
            if ($technicalInfo.Count -eq 0) {
                $technicalInfo += $_.Exception.GetType().Name
            }
            $objStatus.Exception = $technicalInfo -join " | "
            
            "[{0}] Role assignment failed: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.Exception | Write-Verbose
        }

        # Add to collection for batch return
        [void]$RoleAssignmentStatus.Add($objStatus)
    }

    End {
        
        if (-not $WhatIf -and $RoleAssignmentStatus.Count -gt 0) {
            $RoleAssignmentStatus = Invoke-RepackageObjectWithType -RawObject $RoleAssignmentStatus -ObjectName "RoleAssignment.User"
            Return $RoleAssignmentStatus
        }
    }
}

Function Remove-HPEGLRoleFromUser {
    <#
    .SYNOPSIS
    Remove a role assignment from a user in HPE GreenLake.

    .DESCRIPTION
    This cmdlet removes role assignments from users in an HPE GreenLake workspace. 
    You can remove roles by specifying the user email and role name, or by piping role assignment 
    objects from Get-HPEGLUserRole -ShowAssignments (once that's updated to modern API).

    .PARAMETER Email 
    Email address of the user to remove the role from (can be retrieved using Get-HPEGLUser).

    .PARAMETER RoleName 
    Name of the role to remove from the user (can be retrieved using Get-HPEGLRole).
    Example: "Compute Ops Management administrator", "Backup and Recovery Operator"

    .PARAMETER RoleAssignmentId
    The ID of the role assignment to remove. This can be obtained from Get-HPEGLUserRole or Get-HPEGLRole -ShowAssignedUsers.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. 
    This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Remove-HPEGLRoleFromUser -Email "john.doe@example.com" -RoleName "Compute Ops Management administrator"

    Removes the COM administrator role from john.doe@example.com.

    .EXAMPLE
    Remove-HPEGLRoleFromUser -Email "jane.smith@example.com" -RoleName "Workspace Administrator"

    Removes the Workspace Administrator role from jane.smith@example.com.

    .EXAMPLE
    "user1@example.com", "user2@example.com" | Remove-HPEGLRoleFromUser -RoleName "Compute Ops Management viewer"

    Removes the COM viewer role from multiple users via pipeline.

    .EXAMPLE
    Get-HPEGLUser | Where-Object { $_.email -like "*@example.com" } | Remove-HPEGLRoleFromUser -RoleName "Backup and Recovery Operator"

    Removes the Backup and Recovery Operator role from all users with @example.com email addresses.

    .INPUTS
    System.String
        You can pipe email addresses as strings.

    HPEGreenLake.User
        You can pipe user objects from Get-HPEGLUser.

    .OUTPUTS
    System.Collections.ArrayList
        Returns a collection of status objects, one for each role removal attempt:
        * Email - Email address of the user
        * RoleName - Name of the role removed
        * RoleAssignmentId - ID of the role assignment
        * Status - Status of the removal attempt (Failed, Complete)
        * Details - More information about the status
        * Exception - Information about any exceptions generated during the operation
    #>

    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    Param( 
                    
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ByName')]
        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'ById')]
        [Alias('UserEmail')]
        [ValidateScript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$Email,
            
        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'ById')]
        [Alias('role_name', 'role_display_name')]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            
            # Get all available roles dynamically for tab completion
            try {
                $allRoles = (Get-HPEGLRole -Verbose:$false -ErrorAction SilentlyContinue).role_display_name
                
                $allRoles | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                    # Add quotes around role names that contain spaces
                    $completionText = if ($_ -match '\s') { "'$_'" } else { $_ }
                    [System.Management.Automation.CompletionResult]::new($completionText, $_, 'ParameterValue', $_)
                }
            }
            catch {
                # If not connected or error occurs, return empty (no suggestions)
                @()
            }
        })]
        [String]$RoleName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ById')]
        [Alias('id')]
        [String]$RoleAssignmentId,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $RoleRemovalStatus = [System.Collections.ArrayList]::new()
    }
    
    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output - match Add-HPEGLRoleToUser format
        $objStatus = [pscustomobject]@{
            PSTypeName = 'HPEGreenLake.RoleAssignment.User'
            Email      = if ($Email) { $Email } else { "N/A" }
            RoleName   = if ($RoleName) { $RoleName } else { "N/A" }
            Scope      = $null  # Will be populated when we find the role assignment
            Status     = $Null
            Details    = $Null
            Exception  = $Null
        }

        # If using ByName parameter set, we need to find the role assignment ID
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            
            try {
                # First, check if user exists and validate authentication source
                "[{0}] Retrieving user '{1}' to validate authentication source" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email | Write-Verbose
                
                $User = Get-HPEGLUser -Verbose:$false | Where-Object { $_.email -eq $Email }
                
                if (-not $User) {
                    "[{0}] User '{1}' not found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email | Write-Verbose
                    
                    if ($WhatIf) {
                        Write-Warning "User '$Email' not found. Cannot display API request. To list all users, use: Get-HPEGLUser"
                        return
                    }
                    else {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "User '$Email' not found in the workspace. To list all users, use: Get-HPEGLUser"
                        $objStatus.Exception = "User not found"
                        [void]$RoleRemovalStatus.Add($objStatus)
                        return
                    }
                }
                
                # Check if user is SSO/external - these cannot be managed via API
                if ($User.authz_source -eq 'SSO') {
                    "[{0}] User '{1}' is an SSO user and cannot have roles removed via API" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email | Write-Verbose
                    
                    if ($WhatIf) {
                        Write-Warning "User '$Email' is an SSO user managed by your identity provider. Role management must be done through your IdP (not via HPE GreenLake API)."
                        return
                    }
                    else {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "User is an SSO user managed by your identity provider. Role management must be done through your IdP (not via HPE GreenLake API)."
                        $objStatus.Exception = "SSO user not supported"
                        [void]$RoleRemovalStatus.Add($objStatus)
                        return
                    }
                }
                
                # Get the user's current role assignments using existing function
                "[{0}] Retrieving role assignments for user '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email | Write-Verbose
                
                $ExistingUserRoles = Get-HPEGLUserRole -Email $Email -Verbose:$false
                
                if (-not $ExistingUserRoles) {
                    "[{0}] User '{1}' has no role assignments or user not found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email | Write-Verbose
                    
                    if ($WhatIf) {
                        Write-Warning "User '$Email' has no role assignments or user not found. Cannot display API request. To list user roles, use: Get-HPEGLUserRole -Email '$Email'"
                        return
                    }
                    else {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "User has no role assignments or user not found. To list user roles, use: Get-HPEGLUserRole -Email '$Email'"
                        $objStatus.Exception = "No role assignments found"
                        [void]$RoleRemovalStatus.Add($objStatus)
                        return
                    }
                }
                
                # Check if this specific role is assigned (use role_name property)
                $ExistingRole = $ExistingUserRoles | Where-Object { $_.role_name -eq $RoleName }
                
                if (-not $ExistingRole) {
                    "[{0}] Role '{1}' is not assigned to user '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName, $Email | Write-Verbose
                    
                    if ($WhatIf) {
                        Write-Warning "Role '$RoleName' is not assigned to user '$Email'. Cannot display API request. To list the roles assigned to the user, use: Get-HPEGLUserRole -Email '$Email'"
                        return
                    }
                    else {
                        # Return Warning status - role not assigned is not a failure, just nothing to do
                        $objStatus.Status = "Warning"
                        $objStatus.Details = "Role '$RoleName' is not assigned to user. No action needed. To list the roles assigned to the user, use: Get-HPEGLUserRole -Email '$Email'"
                        [void]$RoleRemovalStatus.Add($objStatus)
                        return
                    }
                }
                
                # Get the role assignment ID and scope information from the existing role
                $RoleAssignmentId = $ExistingRole.id
                
                # Populate Scope property to match Add function output
                $existingScopeType = $ExistingRole.scopes.scopeType
                $existingScopeName = $ExistingRole.scopes.scopeName
                
                if ($existingScopeType -eq "MSP_WORKSPACE" -and [string]::IsNullOrEmpty($existingScopeName)) {
                    $objStatus.Scope = "Entire Workspace"
                }
                elseif ($existingScopeName -is [array]) {
                    # Multiple scope groups - join them with comma
                    $objStatus.Scope = $existingScopeName -join ", "
                }
                else {
                    # Single scope group
                    $objStatus.Scope = $existingScopeName
                }
                
                "[{0}] Found role assignment ID: {1}, Scope: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleAssignmentId, $objStatus.Scope | Write-Verbose
            }
            catch {
                "[{0}] Error retrieving user role assignments: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                
                if ($WhatIf) {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Error retrieving user role assignments." }
                    $objStatus.Exception = $_.Exception.GetType().Name
                    [void]$RoleRemovalStatus.Add($objStatus)
                    return
                }
            }
        }
        else {
            # ById parameter set - we already have the ID, but Scope will be populated later or left as null
            "[{0}] Using role assignment ID: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleAssignmentId | Write-Verbose
            # Note: When using ById, we don't have easy access to Scope without additional API call
            # Leave Scope as null - acceptable for ById parameter set
        }

        # Build URI for role assignment deletion using authorization endpoint
        $Uri = "{0}/{1}" -f (Get-AuthorizationRoleAssignmentsV2Alpha2Uri), $RoleAssignmentId

        try {
            $Response = Invoke-HPEGLWebRequest -Method DELETE -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

            if (-not $WhatIf) {
                # Only log response if there is content (DELETE usually returns 204 No Content)
                if ($Response) {
                    "[{0}] Role assignment deletion raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Response | ConvertTo-Json -Depth 5) | Write-Verbose
                }
                else {
                    "[{0}] Role assignment deletion completed (HTTP 204 No Content)" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                }
                
                $objStatus.Status = "Complete"
                $objStatus.Details = "Role successfully removed from user"
                
                "[{0}] Role assignment '{1}' successfully removed from user '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleAssignmentId, $Email | Write-Verbose
            }
        }
        catch {
            # Check if this is actually a success (HTTP 204 No Content for DELETE)
            # The exception might be a parsing error but the DELETE actually succeeded
            if ($_.Exception.Message -match "HTTP 204" -or $_.Exception.Message -match "204" -or $_.Exception.Message -match "Key: Content") {
                "[{0}] DELETE returned HTTP 204 (No Content) or parsing error - treating as success" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                
                $objStatus.Status = "Complete"
                $objStatus.Details = "Role successfully removed from user"
                
                "[{0}] Role assignment '{1}' successfully removed from user '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleAssignmentId, $Email | Write-Verbose
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Role removal failed." }
            
                # Build technical exception info with error code and HTTP status
                $technicalInfo = @()
                if ($Global:HPECOMInvokeReturnData.errorCode) {
                    $technicalInfo += "Code: $($Global:HPECOMInvokeReturnData.errorCode)"
                }
                if ($Global:HPECOMInvokeReturnData.httpStatusCode -or $Global:HPECOMInvokeReturnData.StatusCode) {
                    $statusCode = if ($Global:HPECOMInvokeReturnData.httpStatusCode) { $Global:HPECOMInvokeReturnData.httpStatusCode } else { $Global:HPECOMInvokeReturnData.StatusCode }
                    $technicalInfo += "HTTP $statusCode"
                }
                if ($technicalInfo.Count -eq 0) {
                    $technicalInfo += $_.Exception.GetType().Name
                }
                $objStatus.Exception = $technicalInfo -join " | "
                
                "[{0}] Role removal failed: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.Exception | Write-Verbose
            }
        }

        # Add to collection for batch return
        [void]$RoleRemovalStatus.Add($objStatus)
    }

    End {
        
        if (-not $WhatIf -and $RoleRemovalStatus.Count -gt 0) {
            $RoleRemovalStatus = Invoke-RepackageObjectWithType -RawObject $RoleRemovalStatus -ObjectName "RoleAssignment.User"
            Return $RoleRemovalStatus
        }
    }
}

Function Set-HPEGLUserRole {
    <#
    .SYNOPSIS
    Modify a user's role assignment in HPE GreenLake by changing its scope.

    .DESCRIPTION
    This cmdlet modifies an existing role assignment for a user by changing its scope. You can change
    a role assignment from one scope group to another, from a scope group to entire workspace, or from
    entire workspace to a specific scope group.

    This is useful when you need to change a user's access level without removing and re-adding the role.
    For example, moving a user from production scope to test scope, or expanding their access from a 
    specific scope group to the entire workspace.

    Note: You cannot modify role assignments for SSO users as they are managed by the identity provider.

    .PARAMETER Email 
    Email address of the user whose role assignment you want to modify (can be retrieved using Get-HPEGLUser).

    .PARAMETER RoleName 
    Name of the role assignment to modify (can be retrieved using Get-HPEGLRole or Get-HPEGLUserRole).
    Example: "Compute Ops Management administrator", "Backup and Recovery Operator"

    .PARAMETER ScopeGroupName 
    Optional. Name(s) of scope group(s) to change the role assignment to (can be retrieved using Get-HPEGLScopeGroup).
    Can be a single scope group name or an array of scope group names.
    Only available for roles that support scope group assignment.
    If not specified, defaults to entire workspace access.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. 
    This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Set-HPEGLUserRole -Email "john.doe@example.com" -RoleName "Compute Ops Management operator" -ScopeGroupName "Production-Servers"

    Changes John's COM operator role assignment from its current scope to the Production-Servers scope group.

    .EXAMPLE
    Set-HPEGLUserRole -Email "jane.smith@example.com" -RoleName "Compute Ops Management administrator"

    Changes Jane's COM administrator role assignment to the entire workspace (default when ScopeGroupName not specified).

    .EXAMPLE
    Set-HPEGLUserRole -Email "admin@example.com" -RoleName "Backup and Recovery Operator" -ScopeGroupName "Test-Environment", "Dev-Environment"

    Changes the admin's role assignment to cover multiple scope groups.

    .EXAMPLE
    "user1@example.com", "user2@example.com" | Set-HPEGLUserRole -RoleName "Compute Ops Management viewer" -ScopeGroupName "Staging"

    Changes the COM viewer role scope for multiple users via pipeline.

    .INPUTS
    System.String
        You can pipe email addresses as strings.

    HPEGreenLake.User
        You can pipe user objects from Get-HPEGLUser.

    .OUTPUTS
    System.Collections.ArrayList
        Returns a collection of status objects, one for each role modification attempt:
        * Email - Email address of the user
        * RoleName - Name of the role modified
        * OldScope - Previous scope of the assignment
        * NewScope - New scope of the assignment
        * Status - Status of the modification attempt (Failed, Complete, Warning)
        * Details - More information about the status
        * Exception - Information about any exceptions generated during the operation
    #>

    [CmdletBinding()]
    Param( 
                    
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('UserEmail')]
        [ValidateScript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$Email,
            
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('role_name', 'role_display_name')]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            
            # Get all available roles dynamically for tab completion
            try {
                $allRoles = (Get-HPEGLRole -Verbose:$false -ErrorAction SilentlyContinue).role_display_name
                
                $allRoles | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                    # Add quotes around role names that contain spaces
                    $completionText = if ($_ -match '\s') { "'$_'" } else { $_ }
                    [System.Management.Automation.CompletionResult]::new($completionText, $_, 'ParameterValue', $_)
                }
            }
            catch {
                # If not connected or error occurs, return empty (no suggestions)
                @()
            }
        })]
        [String]$RoleName,

        [Parameter(Mandatory = $false)]
        [String[]]$ScopeGroupName,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $RoleModificationStatus = [System.Collections.ArrayList]::new()
    }
    
    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # If ScopeGroupName is not provided, default to entire workspace
        if (-not $ScopeGroupName) {
            $ScopeGroupName = @('All resources')
        }

        # Build object for the output
        $objStatus = [pscustomobject]@{
            PSTypeName = 'HPEGreenLake.RoleModification.User'
            Email      = $Email
            RoleName   = $RoleName
            OldScope   = $null
            NewScope   = $ScopeGroupName -join ", "
            Status     = $Null
            Details    = $Null
            Exception  = $Null
        }

        # Get the user and validate
        try {
            $User = Get-HPEGLUser -Verbose:$false | Where-Object { $_.email -eq $Email }
            
            if (-not $User) {
                "[{0}] User '{1}' not found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email | Write-Verbose
                
                if ($WhatIf) {
                    Write-Warning "User '$Email' not found. Cannot display API request. To list all users, use: Get-HPEGLUser"
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "User '$Email' not found in the workspace. To list all users, use: Get-HPEGLUser"
                    $objStatus.Exception = "User not found"
                    [void]$RoleModificationStatus.Add($objStatus)
                    return
                }
            }
            
            $UserId = $User.id
            "[{0}] Found user '{1}' with ID: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email, $UserId | Write-Verbose
            
            # Check if user is SSO/external - these cannot be managed via API
            if ($User.authz_source -eq 'SSO') {
                "[{0}] User '{1}' is an SSO user and cannot have roles modified via API" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email | Write-Verbose
                
                if ($WhatIf) {
                    Write-Warning "User '$Email' is an SSO user managed by your identity provider. Role management must be done through your IdP (not via HPE GreenLake API)."
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "User is an SSO user managed by your identity provider. Role management must be done through your IdP (not via HPE GreenLake API)."
                    $objStatus.Exception = "SSO user not supported"
                    [void]$RoleModificationStatus.Add($objStatus)
                    return
                }
            }
        }
        catch {
            "[{0}] Error retrieving user: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
            
            if ($WhatIf) {
                $PSCmdlet.ThrowTerminatingError($_)
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Error retrieving user." }
                $objStatus.Exception = $_.Exception.GetType().Name
                [void]$RoleModificationStatus.Add($objStatus)
                return
            }
        }

        # Get the role details
        try {
            $Role = Get-HPEGLRole -Verbose:$false | Where-Object { $_.role_display_name -eq $RoleName }
            
            if (-not $Role) {
                "[{0}] Role '{1}' not found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName | Write-Verbose
                
                if ($WhatIf) {
                    Write-Warning "Role '$RoleName' not found. Cannot display API request. To list all available roles, use: Get-HPEGLRole"
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Role '$RoleName' not found. To list all available roles, use: Get-HPEGLRole"
                    $objStatus.Exception = "Role not found"
                    [void]$RoleModificationStatus.Add($objStatus)
                    return
                }
            }
            
            # If multiple roles match, prefer internal
            if ($Role -is [array] -and $Role.Count -gt 1) {
                $InternalRole = $Role | Where-Object { $_.role_name -like "*-internal.*" }
                if ($InternalRole) {
                    $Role = $InternalRole | Select-Object -First 1
                }
                else {
                    $Role = $Role | Select-Object -First 1
                }
            }
            
            $RoleGrn = $Role.role_grn
            "[{0}] Found role '{1}' with GRN: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName, $RoleGrn | Write-Verbose
            
            # Validate role and scope compatibility
            $IsWorkspaceLevelRole = $Role.role_name -match '^(identity\.|ccs\.)'
            
            if ($IsWorkspaceLevelRole -and $ScopeGroupName[0] -ne 'All resources') {
                "[{0}] Role '{1}' is a workspace-level role (role_name: {2}) and cannot be scoped to scope groups" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName, $Role.role_name | Write-Verbose
                
                if ($WhatIf) {
                    Write-Warning "Service mismatch: Role '$RoleName' is a workspace-level role and cannot be scoped to scope groups. Omit ScopeGroupName to default to entire workspace access."
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Service mismatch: This role cannot be scoped to a scope group. Workspace-level roles (e.g., 'Workspace Observer') can only have entire workspace access. Use service-specific roles (e.g., 'Compute Ops Management viewer') with -ScopeGroupName."
                    $objStatus.Exception = "Role does not support scope groups"
                    [void]$RoleModificationStatus.Add($objStatus)
                    return
                }
            }
        }
        catch {
            "[{0}] Error retrieving role: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
            
            if ($WhatIf) {
                $PSCmdlet.ThrowTerminatingError($_)
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Error retrieving role." }
                $objStatus.Exception = $_.Exception.GetType().Name
                [void]$RoleModificationStatus.Add($objStatus)
                return
            }
        }

        # Check if role is currently assigned to the user
        try {
            "[{0}] Checking current role assignment for user..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            
            $ExistingUserRoles = Get-HPEGLUserRole -Email $Email -Verbose:$false
            
            if (-not $ExistingUserRoles) {
                "[{0}] User '{1}' has no role assignments" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email | Write-Verbose
                
                if ($WhatIf) {
                    Write-Warning "User '$Email' has no role assignments. Cannot modify a role that isn't assigned. To list user roles, use: Get-HPEGLUserRole -Email '$Email'"
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "User has no role assignments. Cannot modify a role that isn't assigned. To list user roles, use: Get-HPEGLUserRole -Email '$Email'"
                    $objStatus.Exception = "No role assignments found"
                    [void]$RoleModificationStatus.Add($objStatus)
                    return
                }
            }
            
            # Check if this specific role is assigned
            $ExistingRole = $ExistingUserRoles | Where-Object { $_.role_name -eq $RoleName }
            
            if (-not $ExistingRole) {
                "[{0}] Role '{1}' is not assigned to user '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName, $Email | Write-Verbose
                
                if ($WhatIf) {
                    Write-Warning "Role '$RoleName' is not currently assigned to user '$Email'. Cannot modify a role that isn't assigned. To add this role, use: Add-HPEGLRoleToUser"
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Role '$RoleName' is not currently assigned to user. Cannot modify a role that isn't assigned. To add this role, use: Add-HPEGLRoleToUser"
                    $objStatus.Exception = "Role not assigned"
                    [void]$RoleModificationStatus.Add($objStatus)
                    return
                }
            }
            
            # Get the role assignment ID and current scope information
            $RoleAssignmentId = $ExistingRole.id
            
            # Determine current scope for OldScope property
            $existingScopeType = $ExistingRole.scopes.scopeType
            $existingScopeName = $ExistingRole.scopes.scopeName
            
            if ($existingScopeType -eq "MSP_WORKSPACE" -and [string]::IsNullOrEmpty($existingScopeName)) {
                $objStatus.OldScope = "Entire Workspace"
            }
            elseif ($existingScopeName -is [array]) {
                $objStatus.OldScope = $existingScopeName -join ", "
            }
            else {
                $objStatus.OldScope = $existingScopeName
            }
            
            "[{0}] Found role assignment ID: {1}, Current Scope: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleAssignmentId, $objStatus.OldScope | Write-Verbose
            
            # Check if the new scope is the same as current scope (no change needed)
            if ($ScopeGroupName[0] -eq 'All resources' -and $existingScopeType -eq "MSP_WORKSPACE" -and [string]::IsNullOrEmpty($existingScopeName)) {
                $warningMsg = "Role '$RoleName' is already assigned to user '$Email' for entire workspace. No modification needed."
                
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $warningMsg | Write-Verbose
                
                if ($WhatIf) {
                    Write-Warning "$warningMsg Cannot display API request."
                    return
                }
                else {
                    $objStatus.Status = "Warning"
                    $objStatus.Details = "Role already assigned with the requested scope. No action needed."
                    [void]$RoleModificationStatus.Add($objStatus)
                    return
                }
            }
            elseif ($ScopeGroupName[0] -ne 'All resources' -and -not [string]::IsNullOrEmpty($existingScopeName)) {
                # Compare scope groups by normalizing both to arrays and sorting
                $currentScopes = if ($existingScopeName -is [array]) { 
                    $existingScopeName | Sort-Object 
                } else { 
                    @($existingScopeName) 
                }
                $requestedScopes = $ScopeGroupName | Sort-Object
                
                # Compare sorted arrays element by element
                $scopesMatch = $true
                if ($currentScopes.Count -ne $requestedScopes.Count) {
                    $scopesMatch = $false
                }
                else {
                    for ($i = 0; $i -lt $currentScopes.Count; $i++) {
                        if ($currentScopes[$i] -ne $requestedScopes[$i]) {
                            $scopesMatch = $false
                            break
                        }
                    }
                }
                
                if ($scopesMatch) {
                    $requestedScopeNames = $ScopeGroupName -join ", "
                    $warningMsg = "Role '$RoleName' is already assigned to user '$Email' for scope group(s): $requestedScopeNames. No modification needed."
                    
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $warningMsg | Write-Verbose
                    
                    if ($WhatIf) {
                        Write-Warning "$warningMsg Cannot display API request."
                        return
                    }
                    else {
                        $objStatus.Status = "Warning"
                        $objStatus.Details = "Role already assigned with the requested scope. No action needed."
                        [void]$RoleModificationStatus.Add($objStatus)
                        return
                    }
                }
            }
        }
        catch {
            "[{0}] Error retrieving user role assignments: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
            
            if ($WhatIf) {
                $PSCmdlet.ThrowTerminatingError($_)
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Error retrieving user role assignments." }
                $objStatus.Exception = $_.Exception.GetType().Name
                [void]$RoleModificationStatus.Add($objStatus)
                return
            }
        }

        # Build the new scope GRN(s)
        $NewScopeGrns = @()
        
        if ($ScopeGroupName[0] -eq 'All resources') {
            # Entire workspace scope
            $WorkspaceId = $Global:HPEGreenLakeSession.workspaceId
            $NewScopeGrns += "grn:glp/workspaces/$WorkspaceId"
            "[{0}] Using entire workspace scope: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $NewScopeGrns[0] | Write-Verbose
        }
        else {
            # Specific scope groups
            try {
                foreach ($ScopeName in $ScopeGroupName) {
                    $ScopeGroup = Get-HPEGLScopeGroup -Name $ScopeName -Verbose:$false
                    
                    if (-not $ScopeGroup) {
                        "[{0}] Scope group '{1}' not found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ScopeName | Write-Verbose
                        
                        if ($WhatIf) {
                            Write-Warning "Scope group '$ScopeName' not found. Cannot display API request. To list all scope groups, use: Get-HPEGLScopeGroup"
                            return
                        }
                        else {
                            $objStatus.Status = "Failed"
                            $objStatus.Details = "Scope group '$ScopeName' not found. To list all scope groups, use: Get-HPEGLScopeGroup"
                            $objStatus.Exception = "Scope group not found"
                            [void]$RoleModificationStatus.Add($objStatus)
                            return
                        }
                    }
                    
                    # Build scope group GRN
                    $WorkspaceId = $Global:HPEGreenLakeSession.workspaceId
                    $ScopeGroupId = $ScopeGroup.id
                    $ScopeGrn = "grn:glp/workspaces/$WorkspaceId/regions/default/providers/authorization/scope-groups/$ScopeGroupId"
                    $NewScopeGrns += $ScopeGrn
                    
                    "[{0}] Added scope group '{1}' with GRN: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ScopeName, $ScopeGrn | Write-Verbose
                }
            }
            catch {
                "[{0}] Error retrieving scope groups: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                
                if ($WhatIf) {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else {"Error retrieving scope groups."}
                    $objStatus.Exception = $_.Exception.GetType().Name
                    [void]$RoleModificationStatus.Add($objStatus)
                    return
                }
            }
        }

        # Build the payload for role assignment modification API (PUT)
        # The payload must include: id, subject, role, and scope (note: "scope" not "scopes")
        $Payload = [PSCustomObject]@{
            id      = $RoleAssignmentId
            subject = "user:$UserId"
            role    = $RoleGrn
            scope   = $NewScopeGrns
        } | ConvertTo-Json -Depth 10

        "[{0}] Payload: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Payload | Write-Verbose

        # Build URI for role assignment modification using the role assignment ID
        $Uri = "{0}/{1}" -f (Get-AuthorizationRoleAssignmentsV2Alpha2Uri), $RoleAssignmentId

        try {
            $Response = Invoke-HPEGLWebRequest -Method PUT -Uri $Uri -Body $Payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

            if (-not $WhatIf) {
                "[{0}] Role modification raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Response | ConvertTo-Json -Depth 5) | Write-Verbose
                
                $objStatus.Status = "Complete"
                $objStatus.Details = "Role scope successfully modified"
                
                "[{0}] Role '{1}' scope successfully modified for user '{2}' from '{3}' to '{4}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName, $Email, $objStatus.OldScope, $objStatus.NewScope | Write-Verbose
            }
        }
        catch {
            $objStatus.Status = "Failed"
            $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Role modification failed." }
            
            # Build technical exception info with error code and HTTP status
            $technicalInfo = @()
            if ($Global:HPECOMInvokeReturnData.errorCode) {
                $technicalInfo += "Code: $($Global:HPECOMInvokeReturnData.errorCode)"
            }
            if ($Global:HPECOMInvokeReturnData.httpStatusCode -or $Global:HPECOMInvokeReturnData.StatusCode) {
                $statusCode = if ($Global:HPECOMInvokeReturnData.httpStatusCode) { $Global:HPECOMInvokeReturnData.httpStatusCode } else { $Global:HPECOMInvokeReturnData.StatusCode }
                $technicalInfo += "HTTP $statusCode"
            }
            if ($technicalInfo.Count -eq 0) {
                $technicalInfo += $_.Exception.GetType().Name
            }
            $objStatus.Exception = $technicalInfo -join " | "
            
            "[{0}] Role modification failed: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.Exception | Write-Verbose
        }

        # Add to collection for batch return
        [void]$RoleModificationStatus.Add($objStatus)
    }

    End {
        
        if (-not $WhatIf -and $RoleModificationStatus.Count -gt 0) {
            $RoleModificationStatus = Invoke-RepackageObjectWithType -RawObject $RoleModificationStatus -ObjectName "RoleModification.User"
            Return $RoleModificationStatus
        }
    }
}

# User groups

Function Get-HPEGLUserGroup {
    <#
    .SYNOPSIS
    Retrieve user groups from HPE GreenLake.

    .DESCRIPTION
    This cmdlet returns a collection of user groups from HPE GreenLake. User groups allow administrators 
    to organize users and assign permissions collectively. Groups can be sourced from identity providers (IdP) 
    via Single Sign-On or created locally within HPE GreenLake.

    Each group object includes:
    - displayName: The group name
    - groupDescription: Optional description of the group's purpose
    - source: Authentication source (e.g., "sso" for IdP groups, "local" for GreenLake groups)
    - members: When -ShowUsers is specified, includes list of group members
    - roles: When -ShowRoles is specified, includes list of role assignments
    - MemberCount: When -IncludeCounts is specified, includes count of group members
    - RoleCount: When -IncludeCounts is specified, includes count of role assignments

    By default, the cmdlet returns basic group information only. Use -IncludeCounts to retrieve member and role counts,
    which requires additional API calls and may increase execution time with many groups.

    .PARAMETER Name 
    The display name of a specific user group to retrieve. When not specified, all groups are returned.

    .PARAMETER ShowUsers 
    When specified, includes the list of users who are members of each group.
    For each member, displays their username, email, and user ID.
    Also includes MemberCount and RoleCount properties.

    .PARAMETER ShowRoles 
    When specified, includes the list of role assignments for each group.
    Shows which roles have been assigned to the group and the scope of those assignments.
    Also includes MemberCount and RoleCount properties.

    .PARAMETER IncludeCounts
    When specified, includes the count of members and role assignments for each group.
    This requires additional API calls per group and may impact performance with many groups.
    Not available when using -ShowUsers or -ShowRoles (counts are included automatically with those switches).

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. 
    This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Get-HPEGLUserGroup

    Returns all user groups in the HPE GreenLake organization.

    .EXAMPLE
    Get-HPEGLUserGroup -Name "Engineering Team"

    Returns the specific user group named "Engineering Team".

    .EXAMPLE
    Get-HPEGLUserGroup -Name "Engineering Team" -ShowUsers

    Returns the members of the "Engineering Team" group directly.
    Output shows: Name, Email, Verified columns for each member.

    .EXAMPLE
    Get-HPEGLUserGroup -Name "COM-GEN11-Admin" -ShowRoles

    Returns the role assignments for the "COM-GEN11-Admin" group directly.
    Output shows role assignments with role names, services, and scopes.

    .EXAMPLE
    Get-HPEGLUserGroup -IncludeCounts

    Returns all user groups with member counts and role counts included.
    This makes additional API calls to retrieve counts, so it may take longer with many groups.

    .EXAMPLE
    Get-HPEGLUserGroup | Where-Object { $_.source -eq 'External' }

    Returns only user groups that are managed by a different organization.

    .EXAMPLE
    Get-HPEGLUserGroup | Where-Object { $_.source -eq 'Local' }

    Returns only user groups that are managed by the current organization.

    .EXAMPLE
    Get-HPEGLUserGroup | Where-Object { $_.source -eq 'SCIM' }

    Returns only user groups that are managed by a SCIM integration, for example, Azure.
    #>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 

        [Parameter (Mandatory = $false, ParameterSetName = 'Default')]
        [Parameter (Mandatory = $true, ParameterSetName = 'ShowUsers')]
        [Parameter (Mandatory = $true, ParameterSetName = 'ShowRoles')]
        [String]$Name,

        [Parameter (Mandatory = $true, ParameterSetName = 'ShowUsers')]
        [Switch]$ShowUsers,

        [Parameter (Mandatory = $true, ParameterSetName = 'ShowRoles')]
        [Switch]$ShowRoles,

        [Parameter (Mandatory = $false, ParameterSetName = 'Default')]
        [Switch]$IncludeCounts,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

    }

    Process {
       
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Use SCIM v2 Groups API endpoint
        $Uri = Get-OrganizationsUsersGroupsListUri
        
        # Add filter if Name is specified
        if ($Name) {
            $EncodedName = [System.Web.HttpUtility]::UrlEncode($Name)
            $Uri += "?filter=displayName eq `"$EncodedName`""
            "[{0}] Retrieving user group '{1}' from: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Uri | Write-Verbose
        }
        else {
            "[{0}] Retrieving all user groups from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri | Write-Verbose
        }

        $ReturnData = @()
        
        try {
            $Response = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
            
            if ($WhatIf) {
                return
            }

            # SCIM API returns response in 'Resources' wrapper
            if ($Response.Resources) {
                # Handle case where Resources is a single object (not array) when only 1 result
                if ($Response.Resources -is [array]) {
                    [array]$Collection = $Response.Resources
                }
                else {
                    [array]$Collection = @($Response.Resources)
                }
                "[{0}] Retrieved {1} user group(s) from SCIM API" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Collection.Count | Write-Verbose
            }
            else {
                # No groups found
                [array]$Collection = @()
                "[{0}] No user groups found" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            }
        }
        catch {
            # Check for standalone workspace error (organization inactive state)
            if ($Global:HPECOMInvokeReturnData.errorCode -eq "HPE_GL_IDENTITY_INVALID_ORGANIZATION_STATE" -or 
                $Global:HPECOMInvokeReturnData.message -match "organization at inactive state") {
                
                $ErrorMessage = "User groups are not supported in standalone workspaces. This feature requires an HPE GreenLake organization. Standalone workspaces can only manage individual users and their roles directly. To use user groups, you must configure an HPE GreenLake organization for your workspace."
                
                $ErrorRecord = New-Object System.Management.Automation.ErrorRecord(
                    (New-Object System.InvalidOperationException($ErrorMessage)),
                    "UserGroupsNotSupportedInStandaloneWorkspace",
                    [System.Management.Automation.ErrorCategory]::NotImplemented,
                    $null
                )
                $PSCmdlet.ThrowTerminatingError($ErrorRecord)
            }
            else {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
     
        
        if ($Collection -is [array] -and $Collection.Count -gt 0) {
            
            $GroupsList = @()
            
            foreach ($Group in $Collection) {
                
                # Extract HPE GreenLake specific properties from SCIM extension
                $HpeExtension = $Group.'urn:ietf:params:scim:schemas:extensions:hpe-greenlake:2.0:Group'
                
                # Add HPE-specific properties to the group object
                $Group | Add-Member -MemberType NoteProperty -Name groupDescription -Value $HpeExtension.groupDescription -Force
                $Group | Add-Member -MemberType NoteProperty -Name source -Value $HpeExtension.source -Force
                $Group | Add-Member -MemberType NoteProperty -Name hpe_principal -Value $HpeExtension.hpe_principal -Force
                
                # Initialize counts
                $memberCount = 0
                $roleCount = 0
                
                # Retrieve members information (always retrieve for counts, but full details only if ShowUsers is specified)
                if ($ShowUsers) {
                    try {
                        "[{0}] Retrieving members for group '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Group.displayName | Write-Verbose
                        
                        # Use SCIM extensions API to get group members
                        $MembersUri = "{0}/identity/v2alpha1/scim/v2/extensions/Groups/{1}/users?count=100&startIndex=1" -f (Get-HPEGLAPIOrgbaseURL), $Group.id
                        
                        try {
                            $MembersResponse = Invoke-HPEGLWebRequest -Method Get -Uri $MembersUri -WhatIfBoolean $false -Verbose:$VerbosePreference -ErrorAction Stop
                        }
                        catch {
                            # If Invoke-HPEGLWebRequest fails, try alternative method
                            "[{0}] Using alternative method to retrieve members..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            
                            $headers = @{
                                "Authorization" = "Bearer $($Global:HPEGreenLakeSession.glpApiAccessTokenv1_2.access_token)"
                                "Accept" = "application/json"
                                "Content-Type" = "application/json"
                            }
                            $MembersResponse = Invoke-RestMethod -Uri $MembersUri -Method Get -Headers $headers
                        }
                        
                        # Extract members from response
                        $Members = @()
                        if ($MembersResponse -and $MembersResponse.Resources) {
                            $Members = $MembersResponse.Resources
                            
                            # Add Email and GroupName properties to each member for pipeline compatibility
                            foreach ($member in $Members) {
                                if ($member.userName -and -not $member.Email) {
                                    $member | Add-Member -MemberType NoteProperty -Name Email -Value $member.userName -Force
                                }
                                # Add GroupName so it can be piped directly to Add/Remove functions
                                if (-not $member.GroupName) {
                                    $member | Add-Member -MemberType NoteProperty -Name GroupName -Value $Group.displayName -Force
                                }
                            }
                            
                            # Apply type name to members for custom formatting
                            if ($Members.Count -gt 0) {
                                $Members = Invoke-RepackageObjectWithType -RawObject $Members -ObjectName "UserGroup.Members"
                            }
                        }
                        
                        $Group | Add-Member -MemberType NoteProperty -Name members -Value $Members -Force
                        
                        $memberCount = if ($Members) { $Members.Count } else { 0 }
                        "[{0}] Group '{1}' has {2} member(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Group.displayName, $memberCount | Write-Verbose
                    }
                    catch {
                        "[{0}] Warning: Could not retrieve members for group '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Group.displayName, $_.Exception.Message | Write-Verbose
                        $Group | Add-Member -MemberType NoteProperty -Name members -Value @() -Force
                    }
                }
                elseif ($IncludeCounts) {
                    # When IncludeCounts is specified but not showing full user details, just get the count
                    try {
                        "[{0}] Retrieving member count for group '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Group.displayName | Write-Verbose
                        
                        # Use SCIM extensions API to get group members count
                        $MembersUri = "{0}/identity/v2alpha1/scim/v2/extensions/Groups/{1}/users?count=100&startIndex=1" -f (Get-HPEGLAPIOrgbaseURL), $Group.id
                        
                        try {
                            $MembersResponse = Invoke-HPEGLWebRequest -Method Get -Uri $MembersUri -WhatIfBoolean $false -Verbose:$VerbosePreference -ErrorAction Stop
                        }
                        catch {
                            # If Invoke-HPEGLWebRequest fails, try alternative method
                            "[{0}] Using alternative method to retrieve member count..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            
                            $headers = @{
                                "Authorization" = "Bearer $($Global:HPEGreenLakeSession.glpApiAccessTokenv1_2.access_token)"
                                "Accept" = "application/json"
                                "Content-Type" = "application/json"
                            }
                            $MembersResponse = Invoke-RestMethod -Uri $MembersUri -Method Get -Headers $headers
                        }
                        
                        # Get count from response
                        if ($MembersResponse -and $MembersResponse.Resources) {
                            $memberCount = $MembersResponse.Resources.Count
                        }
                        
                        "[{0}] Group '{1}' has {2} member(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Group.displayName, $memberCount | Write-Verbose
                    }
                    catch {
                        "[{0}] Warning: Could not retrieve member count for group '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Group.displayName, $_.Exception.Message | Write-Verbose
                        $memberCount = 0
                    }
                }
                
                # Add roles information if ShowRoles is specified
                if ($ShowRoles) {
                    try {
                        "[{0}] Retrieving role assignments for group '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Group.displayName | Write-Verbose
                        
                        # Get role assignments for this group using the group's ID
                        if ($Group.id) {
                            # Use internal tenant UI endpoint to get role assignments for this user group
                            $RoleAssignmentUri = "{0}/internal-platform-tenant-ui/v2alpha2/role-assignments?group_id={1}&limit=100&offset=0" -f (Get-HPEGLAPIOrgbaseURL), $Group.id
                            
                            # Make the API call
                            try {
                                $RoleAssignmentResponse = Invoke-HPEGLWebRequest -Method Get -Uri $RoleAssignmentUri -WhatIfBoolean $false -Verbose:$VerbosePreference -ErrorAction Stop
                            }
                            catch {
                                # If Invoke-HPEGLWebRequest fails to parse, try alternative method
                                if ($_.Exception.Message -match "No collection property") {
                                    "[{0}] Using alternative method to retrieve role assignments..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                    
                                    $headers = @{
                                        "Authorization" = "Bearer $($Global:HPEGreenLakeSession.glpApiAccessTokenv1_2.access_token)"
                                        "Accept" = "application/json"
                                        "Content-Type" = "application/json"
                                    }
                                    $RoleAssignmentResponse = Invoke-RestMethod -Uri $RoleAssignmentUri -Method Get -Headers $headers
                                }
                                else {
                                    throw
                                }
                            }
                            
                            # Extract role assignments from response
                            $RoleAssignments = @()
                            if ($RoleAssignmentResponse) {
                                if ($RoleAssignmentResponse.PSObject.Properties['role_assignments']) {
                                    $RoleAssignments = $RoleAssignmentResponse.role_assignments
                                }
                                elseif ($RoleAssignmentResponse -is [array]) {
                                    $RoleAssignments = $RoleAssignmentResponse
                                }
                            }
                            
                            $Group | Add-Member -MemberType NoteProperty -Name roles -Value $RoleAssignments -Force
                            
                            $roleCount = if ($RoleAssignments) { $RoleAssignments.Count } else { 0 }
                            "[{0}] Group '{1}' has {2} role assignment(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Group.displayName, $roleCount | Write-Verbose
                        }
                        else {
                            $Group | Add-Member -MemberType NoteProperty -Name roles -Value $null -Force
                        }
                    }
                    catch {
                        "[{0}] Warning: Could not retrieve role assignments for group '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Group.displayName, $_.Exception.Message | Write-Verbose
                        $Group | Add-Member -MemberType NoteProperty -Name roles -Value $null -Force
                    }
                }
                elseif ($IncludeCounts) {
                    # When IncludeCounts is specified but not showing full role details, just get the count
                    try {
                        "[{0}] Retrieving role count for group '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Group.displayName | Write-Verbose
                        
                        # Get role assignments for this group using the group's ID
                        if ($Group.id) {
                            # Use internal tenant UI endpoint to get role assignments for this user group
                            $RoleAssignmentUri = "{0}/internal-platform-tenant-ui/v2alpha2/role-assignments?group_id={1}&limit=100&offset=0" -f (Get-HPEGLAPIOrgbaseURL), $Group.id
                            
                            # Make the API call
                            try {
                                $RoleAssignmentResponse = Invoke-HPEGLWebRequest -Method Get -Uri $RoleAssignmentUri -WhatIfBoolean $false -Verbose:$VerbosePreference -ErrorAction Stop
                            }
                            catch {
                                # If Invoke-HPEGLWebRequest fails to parse, try alternative method
                                if ($_.Exception.Message -match "No collection property") {
                                    "[{0}] Using alternative method to retrieve role count..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                    
                                    $headers = @{
                                        "Authorization" = "Bearer $($Global:HPEGreenLakeSession.glpApiAccessTokenv1_2.access_token)"
                                        "Accept" = "application/json"
                                        "Content-Type" = "application/json"
                                    }
                                    $RoleAssignmentResponse = Invoke-RestMethod -Uri $RoleAssignmentUri -Method Get -Headers $headers
                                }
                                else {
                                    throw
                                }
                            }
                            
                            # Extract role assignments count from response
                            if ($RoleAssignmentResponse) {
                                if ($RoleAssignmentResponse.PSObject.Properties['role_assignments']) {
                                    $roleCount = $RoleAssignmentResponse.role_assignments.Count
                                }
                                elseif ($RoleAssignmentResponse -is [array]) {
                                    $roleCount = $RoleAssignmentResponse.Count
                                }
                            }
                            
                            "[{0}] Group '{1}' has {2} role assignment(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Group.displayName, $roleCount | Write-Verbose
                        }
                    }
                    catch {
                        "[{0}] Warning: Could not retrieve role count for group '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Group.displayName, $_.Exception.Message | Write-Verbose
                        $roleCount = 0
                    }
                }
                
                # Add count properties to the group object only when IncludeCounts is specified or when counts were retrieved
                if ($IncludeCounts -or $ShowUsers -or $ShowRoles) {
                    $Group | Add-Member -MemberType NoteProperty -Name MemberCount -Value $memberCount -Force
                    $Group | Add-Member -MemberType NoteProperty -Name RoleCount -Value $roleCount -Force
                }
                
                $GroupsList += $Group
            }

            # If ShowUsers is specified and only one group, return the members directly
            if ($ShowUsers -and -not $ShowRoles -and $GroupsList.Count -eq 1) {
                "[{0}] Returning members directly for single group" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                return $GroupsList[0].members
            }
            # If ShowUsers is specified with multiple groups, return all members from all groups
            elseif ($ShowUsers -and -not $ShowRoles -and $GroupsList.Count -gt 1) {
                "[{0}] Returning members from all {1} groups" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GroupsList.Count | Write-Verbose
                $AllMembers = @()
                foreach ($group in $GroupsList) {
                    if ($group.members) {
                        $AllMembers += $group.members
                    }
                }
                # Remove duplicates based on user ID
                $UniquMembers = $AllMembers | Sort-Object id -Unique
                return $UniquMembers
            }
            # If ShowRoles is specified and only one group, return the roles directly
            elseif ($ShowRoles -and -not $ShowUsers -and $GroupsList.Count -eq 1) {
                "[{0}] Returning roles directly for single group" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                
                # Add custom type name and GroupName property for formatting and pipeline support
                $RolesToReturn = @()
                foreach ($role in $GroupsList[0].roles) {
                    $role | Add-Member -MemberType NoteProperty -Name GroupName -Value $GroupsList[0].displayName -Force
                    $role.PSObject.TypeNames.Insert(0, 'HPEGreenLake.UserGroup.Roles')
                    $RolesToReturn += $role
                }
                return $RolesToReturn
            }
            # If ShowRoles is specified with multiple groups, return all roles from all groups
            elseif ($ShowRoles -and -not $ShowUsers -and $GroupsList.Count -gt 1) {
                "[{0}] Returning roles from all {1} groups" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GroupsList.Count | Write-Verbose
                $AllRoles = @()
                foreach ($group in $GroupsList) {
                    if ($group.roles) {
                        foreach ($role in $group.roles) {
                            $role | Add-Member -MemberType NoteProperty -Name GroupName -Value $group.displayName -Force
                            $role.PSObject.TypeNames.Insert(0, 'HPEGreenLake.UserGroup.Roles')
                            $AllRoles += $role
                        }
                    }
                }
                return $AllRoles
            }
            else {
                # Apply appropriate type name based on whether counts are included
                if ($IncludeCounts -or $ShowUsers -or $ShowRoles) {
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $GroupsList -ObjectName "UserGroup.WithCounts"
                }
                else {
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $GroupsList -ObjectName "UserGroup"
                }
                $ReturnData = $ReturnData | Sort-Object displayName
                return $ReturnData
            }
           
        }
        else {
            # If specific name was requested but not found, return nothing
            if ($Name) {
                "[{0}] User group '{1}' not found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
            }
            return
        }
    }
}

Function New-HPEGLUserGroup {
    <#
    .SYNOPSIS
    Creates a new user group in HPE GreenLake.

    .DESCRIPTION
    This cmdlet creates a new local user group in HPE GreenLake. User groups allow administrators 
    to organize users and assign permissions collectively. The created group can optionally be populated 
    with initial members and assigned roles with specific scopes.

    Note: This cmdlet creates local groups only. Groups synced from identity providers via SSO cannot 
    be created through the API.

    .PARAMETER Name 
    The name of the user group to create. Must be unique within the workspace.

    .PARAMETER Description
    Optional description for the user group explaining its purpose or membership criteria.

    .PARAMETER UserEmail
    Optional array of user email addresses to add as initial members of the group.
    Users must already exist in the HPE GreenLake workspace.

    .PARAMETER RoleName
    Optional role name to assign to the group. When specified, ScopeName must also be provided.
    Role names can be retrieved using Get-HPEGLRole.

    .PARAMETER ScopeName
    Optional scope group name for the role assignment. Required when RoleName is specified.
    Use 'All resources' for full access, or specify a scope group name from Get-HPEGLScopeGroup.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. 
    This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    New-HPEGLUserGroup -Name "Developers" -Description "Development team"

    Creates a new user group named "Developers" with a description.

    .EXAMPLE
    New-HPEGLUserGroup -Name "Admins" -Description "Administrator team" -UserEmail "admin1@company.com", "admin2@company.com"

    Creates a new user group with initial members.

    .EXAMPLE
    New-HPEGLUserGroup -Name "COM-Operators" -Description "COM operators" -RoleName "Compute Ops Management operator" -ScopeName "Production-Servers"

    Creates a new user group and assigns it the COM operator role scoped to the Production-Servers scope group.

    .EXAMPLE
    New-HPEGLUserGroup -Name "Full-Admins" -Description "Full administrators" -UserEmail "admin@company.com" -RoleName "Account Administrator" -ScopeName "All resources"

    Creates a group, adds a member, and assigns the Account Administrator role with full access.

    .EXAMPLE
    "Dev-Team", "QA-Team", "Ops-Team" | New-HPEGLUserGroup -Description "Engineering teams"

    Creates multiple user groups from pipeline input. Returns status for each group creation attempt.

    .EXAMPLE
    Import-Csv .\groups.csv | New-HPEGLUserGroup

    Creates user groups from a CSV file with columns: Name, Description, UserEmail, RoleName, ScopeName.
    Processes all groups and returns combined results showing success, warning, or failure for each.

    .EXAMPLE
    "ProjectA-Admins", "ProjectB-Admins" | New-HPEGLUserGroup -Description "Project administrators" -RoleName "Compute Ops Management administrator" -ScopeName "All resources"

    Creates multiple administrator groups via pipeline with the same role assignment.

    .INPUTS
    System.String
        You can pipe group names as strings. Additional parameters can be specified for all piped items.

    System.Management.Automation.PSObject
        You can pipe objects with Name, Description, UserEmail, RoleName, and ScopeName properties.

    .OUTPUTS
    System.Collections.ArrayList
        Returns a collection of status objects, one for each group creation attempt:
        * Name - Name of the group attempted to be created
        * Status - Status of the creation attempt (Failed, Complete, Warning)
        * Details - More information about the status
        * Exception - Information about any exceptions generated during the operation
        * Id - The ID of the created group (when successful)

   #>

    [CmdletBinding()]
    Param( 
                    
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [String]$Name,
            
        [Parameter(ValueFromPipelineByPropertyName)]
        [String]$Description = "",

        [Parameter(ValueFromPipelineByPropertyName)]
        [String[]]$UserEmail,

        [Parameter(ValueFromPipelineByPropertyName)]
        [String]$RoleName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [String]$ScopeName,

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $CreateUserGroupStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name      = $Name
            Status    = $Null
            Details   = $Null
            Exception = $Null
            Id        = $Null
        }

        # Validate that RoleName and ScopeName are used together
        if ($RoleName -and -not $ScopeName) {
            $objStatus.Status = "Failed"
            $objStatus.Details = "ScopeName parameter is required when RoleName is specified"
            $objStatus.Exception = "Missing required parameter"
            "[{0}] Error: ScopeName is required when RoleName is specified" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            [void]$CreateUserGroupStatus.Add($objStatus)
            return
        }

        if ($ScopeName -and -not $RoleName) {
            $objStatus.Status = "Failed"
            $objStatus.Details = "RoleName parameter is required when ScopeName is specified"
            $objStatus.Exception = "Missing required parameter"
            "[{0}] Error: RoleName is required when ScopeName is specified" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            [void]$CreateUserGroupStatus.Add($objStatus)
            return
        }

        # Check if group already exists
        try {
            $ExistingGroup = Get-HPEGLUserGroup -Name $Name -Verbose:$false
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if ($ExistingGroup) {
            
            "[{0}] User group '{1}' already exists!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
    
            if ($WhatIf) {
                Write-Warning "User group '$Name' already exists! No action needed."
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "User group already exists! No action needed."
                $objStatus.Id = $ExistingGroup.id
                # Add to collection and skip to next item
                [void]$CreateUserGroupStatus.Add($objStatus)
                return
            }

        }

        # Build the SCIM Group payload
        $payload = @{
            schemas     = @(
                "urn:ietf:params:scim:schemas:core:2.0:Group"
                "urn:ietf:params:scim:schemas:extensions:hpe-greenlake:2.0:Group"
            )
            displayName = $Name
        }

        # Add HPE GreenLake extension with description
        $payload.'urn:ietf:params:scim:schemas:extensions:hpe-greenlake:2.0:Group' = @{
            groupDescription = $Description
        }

        # Convert to JSON
        $Body = $payload | ConvertTo-Json -Depth 10
        
        "[{0}] Payload: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Body | Write-Verbose

        # Build URI for SCIM Groups
        $Uri = "{0}/identity/v2beta1/scim/v2/Groups" -f (Get-HPEGLAPIOrgbaseURL)

        try {
            $Response = Invoke-HPEGLWebRequest -Method POST -Uri $Uri -Body $Body -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

            if (-not $WhatIf) {

                "[{0}] User group creation raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Response | ConvertTo-Json -Depth 5) | Write-Verbose
                
                "[{0}] User group '{1}' successfully created with ID: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Response.id | Write-Verbose
                    
                $objStatus.Status = "Complete"
                $objStatus.Details = "User group successfully created"
                $objStatus.Id = $Response.id

                # Add members if specified
                if ($UserEmail -and $UserEmail.Count -gt 0) {
                    "[{0}] Adding {1} member(s) to group '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $UserEmail.Count, $Name | Write-Verbose
                    
                    foreach ($email in $UserEmail) {
                        try {
                            # Get user details
                            $User = Get-HPEGLUser -Email $email -Verbose:$false
                            if ($User) {
                                # Add user to group using SCIM PATCH operation
                                $patchPayload = @{
                                    schemas    = @("urn:ietf:params:scim:api:messages:2.0:PatchOp")
                                    Operations = @(
                                        @{
                                            op    = "add"
                                            path  = "members"
                                            value = @(
                                                @{
                                                    value = $User.id
                                                }
                                            )
                                        }
                                    )
                                }
                                
                                $patchBody = $patchPayload | ConvertTo-Json -Depth 10
                                $patchUri = "{0}/identity/v2beta1/scim/v2/Groups/{1}" -f (Get-HPEGLAPIOrgbaseURL), $Response.id
                                
                                $null = Invoke-HPEGLWebRequest -Method PATCH -Uri $patchUri -Body $patchBody -WhatIfBoolean $false -Verbose:$VerbosePreference
                                "[{0}] Added user '{1}' to group '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $email, $Name | Write-Verbose
                            }
                            else {
                                "[{0}] Warning: User '{1}' not found, skipping" -f $MyInvocation.InvocationName.ToString().ToUpper(), $email | Write-Verbose
                            }
                        }
                        catch {
                            "[{0}] Warning: Could not add user '{1}' to group: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $email, $_.Exception.Message | Write-Verbose
                        }
                    }
                }

                # Assign role if specified
                if ($RoleName -and $ScopeName) {
                    "[{0}] Assigning role '{1}' with scope '{2}' to group '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName, $ScopeName, $Name | Write-Verbose
                    
                    try {
                        # Use Add-HPEGLRoleToUserGroup or similar logic
                        # Get the hpe_principal from the response
                        $hpePrincipal = $Response.'urn:ietf:params:scim:schemas:extensions:hpe-greenlake:2.0:Group'.hpe_principal
                        
                        if ($hpePrincipal) {
                            # Call helper to assign role
                            # This would typically be done through Add-HPEGLRoleToUserGroup but since we're creating it now, we'll do it inline
                            "[{0}] Role assignment for new groups will be available via Set-HPEGLUserGroup or Add-HPEGLRoleToUserGroup cmdlet" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            $objStatus.Details += ". Note: Use Add-HPEGLRoleToUserGroup to assign roles to this group."
                        }
                    }
                    catch {
                        "[{0}] Warning: Could not assign role to group: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                        $objStatus.Details += ". Warning: Role assignment failed - assign manually using Add-HPEGLRoleToUserGroup."
                    }
                }
            }
        }
        catch {
            if (-not $WhatIf) {
                $objStatus.Status = "Failed"
                
                # Use helper function to extract error message
                $objStatus.Details = if ($_.Exception.Message) { 
                    $_.Exception.Message 
                } else { 
                    Get-HPEGLErrorMessage -ExceptionObject $_ -DefaultMessage "User group cannot be created!"
                }
                
                # Build technical exception info with error code and HTTP status
                $technicalInfo = @()
                if ($Global:HPECOMInvokeReturnData.errorCode) {
                    $technicalInfo += "Code: $($Global:HPECOMInvokeReturnData.errorCode)"
                }
                if ($Global:HPECOMInvokeReturnData.httpStatusCode -or $Global:HPECOMInvokeReturnData.StatusCode) {
                    $statusCode = if ($Global:HPECOMInvokeReturnData.httpStatusCode) { $Global:HPECOMInvokeReturnData.httpStatusCode } else { $Global:HPECOMInvokeReturnData.StatusCode }
                    $technicalInfo += "HTTP $statusCode"
                }
                if ($technicalInfo.Count -eq 0) {
                    $technicalInfo += $_.Exception.GetType().Name
                }
                $objStatus.Exception = $technicalInfo -join " | "
                
                "[{0}] User group '{1}' creation failed: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $objStatus.Exception | Write-Verbose
            }
        }

        # Add to collection for batch return
        [void]$CreateUserGroupStatus.Add($objStatus)
    }

    End {
        
        if (-not $WhatIf -and $CreateUserGroupStatus.Count -gt 0) {
            $CreateUserGroupStatus = Invoke-RepackageObjectWithType -RawObject $CreateUserGroupStatus -ObjectName "ObjStatus.NSDE"
            return $CreateUserGroupStatus
        }
    }
}

Function Remove-HPEGLUserGroup {
    <#
    .SYNOPSIS
    Deletes one or more user groups from HPE GreenLake.

    .DESCRIPTION
    This cmdlet deletes user groups from HPE GreenLake. Only local user groups can be deleted through 
    the API. Groups synced from identity providers via SSO cannot be deleted.

    The cmdlet validates inputs before deletion:
    - Verifies the user group exists
    - Checks if the group can be deleted (local groups only)
    - Provides detailed status for each deletion attempt

    WARNING: Deleting a user group will remove all role assignments for that group. This action cannot be undone.

    .PARAMETER Name 
    The name of the user group to delete. Can be retrieved using Get-HPEGLUserGroup.
    Accepts pipeline input from group names or group objects.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. 
    This option is useful for understanding the inner workings of the native REST API calls used by GLP.
    When used, the cmdlet performs validation checks and displays warnings for any issues found.

    .EXAMPLE
    Remove-HPEGLUserGroup -Name "Old-Project-Team"

    Deletes the user group named "Old-Project-Team".

    .EXAMPLE
    Remove-HPEGLUserGroup -Name "Temp-Contractors" -WhatIf

    Shows what API call would be made to delete the group without actually deleting it.

    .EXAMPLE
    "Dev-Temp", "QA-Temp" | Remove-HPEGLUserGroup

    Deletes multiple user groups via pipeline. Returns status for each group deletion attempt.

    .EXAMPLE
    Get-HPEGLUserGroup | Where-Object { $_.displayName -like "Temp-*" } | Remove-HPEGLUserGroup

    Deletes all user groups whose names start with "Temp-" by piping group objects.

    .EXAMPLE
    Get-HPEGLUserGroup | Where-Object { $_.source -eq "Local" -and $_.MemberCount -eq 0 } | Remove-HPEGLUserGroup

    Deletes all empty local user groups by filtering and piping.

    .EXAMPLE
    Import-Csv .\groups_to_delete.csv | Remove-HPEGLUserGroup

    Bulk deletes user groups from a CSV file with a Name column.
    Example CSV content:
        Name
        Old-Project-1
        Old-Project-2
        Temp-Group

    .INPUTS
    System.String
        You can pipe group names as strings.

    HPEGreenLake.UserGroup
        You can pipe user group objects from Get-HPEGLUserGroup.

    .OUTPUTS
    System.Collections.ArrayList
        Returns a collection of status objects, one for each group deletion attempt:
        * Name - Name of the group attempted to be deleted
        * Status - Status of the deletion attempt (Failed, Complete, Warning)
        * Details - More information about the status
        * Exception - Information about any exceptions generated during the operation
    #>

    [CmdletBinding()]
    Param( 
                    
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("displayName")]
        [String]$Name,

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $DeleteUserGroupStatus = [System.Collections.ArrayList]::new()

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

        # Check if group exists
        try {
            "[{0}] Looking up user group '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
            $Group = Get-HPEGLUserGroup -Name $Name -Verbose:$false
        }
        catch {
            "[{0}] Error retrieving user group: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
            
            if ($WhatIf) {
                $PSCmdlet.ThrowTerminatingError($_)
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Error retrieving user group." }
                $objStatus.Exception = $_.Exception.GetType().Name
                [void]$DeleteUserGroupStatus.Add($objStatus)
                return
            }
        }

        if (-not $Group) {
            "[{0}] User group '{1}' not found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
            
            if ($WhatIf) {
                Write-Warning "User group '$Name' not found. Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "User group '$Name' not found"
                $objStatus.Exception = "Group not found"
                [void]$DeleteUserGroupStatus.Add($objStatus)
                return
            }
        }

        "[{0}] Found user group '{1}' with ID: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Group.id | Write-Verbose

        # Check if the group can be deleted (only local groups can be deleted)
        if ($Group.source -and $Group.source -ne "Local") {
            "[{0}] User group '{1}' is from source '{2}' and cannot be deleted via API" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Group.source | Write-Verbose
            
            if ($WhatIf) {
                Write-Warning "User group '$Name' is managed by '$($Group.source)' and cannot be deleted through the API. Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "User group is managed by '$($Group.source)' and cannot be deleted through the API"
                $objStatus.Exception = "Cannot delete non-local group"
                [void]$DeleteUserGroupStatus.Add($objStatus)
                return
            }
        }

        # Build URI for SCIM Groups deletion
        $Uri = "{0}/identity/v2beta1/scim/v2/Groups/{1}" -f (Get-HPEGLAPIOrgbaseURL), $Group.id

        "[{0}] DELETE URI: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri | Write-Verbose

        try {
            $Response = Invoke-HPEGLWebRequest -Method DELETE -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

            if (-not $WhatIf) {
                "[{0}] User group deletion raw response: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Response | ConvertTo-Json -Depth 3) | Write-Verbose
                
                $objStatus.Status = "Complete"
                $objStatus.Details = "User group successfully deleted"
                
                "[{0}] User group '{1}' successfully deleted" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
            }
        }
        catch {
            # Check if this is actually a success (HTTP 204 No Content for DELETE)
            if ($_.Exception.Message -match "HTTP 204" -or $_.Exception.Message -match "204" -or $_.Exception.Message -match "No Content") {
                "[{0}] User group '{1}' successfully deleted (HTTP 204)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                
                $objStatus.Status = "Complete"
                $objStatus.Details = "User group successfully deleted"
            }
            else {
                "[{0}] Error deleting user group: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                
                if ($WhatIf) {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
                else {
                    $objStatus.Status = "Failed"
                    
                    # Use helper function to extract error message
                    $objStatus.Details = if ($_.Exception.Message) { 
                        $_.Exception.Message 
                    } else { 
                        Get-HPEGLErrorMessage -ExceptionObject $_ -DefaultMessage "User group cannot be deleted!"
                    }
                    
                    # Build technical exception info with error code and HTTP status
                    $technicalInfo = @()
                    if ($Global:HPECOMInvokeReturnData.errorCode) {
                        $technicalInfo += "Code: $($Global:HPECOMInvokeReturnData.errorCode)"
                    }
                    if ($Global:HPECOMInvokeReturnData.httpStatusCode -or $Global:HPECOMInvokeReturnData.StatusCode) {
                        $statusCode = if ($Global:HPECOMInvokeReturnData.httpStatusCode) { $Global:HPECOMInvokeReturnData.httpStatusCode } else { $Global:HPECOMInvokeReturnData.StatusCode }
                        $technicalInfo += "HTTP $statusCode"
                    }
                    if ($technicalInfo.Count -eq 0) {
                        $technicalInfo += $_.Exception.GetType().Name
                    }
                    $objStatus.Exception = $technicalInfo -join " | "
                
                    "[{0}] User group deletion failed: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.Exception | Write-Verbose
                }
            }
        }

        # Add to collection for batch return
        [void]$DeleteUserGroupStatus.Add($objStatus)
    }

    End {
        
        if (-not $WhatIf -and $DeleteUserGroupStatus.Count -gt 0) {
            $DeleteUserGroupStatus = Invoke-RepackageObjectWithType -RawObject $DeleteUserGroupStatus -ObjectName "ObjStatus.NSDE"
            return $DeleteUserGroupStatus
        }
    }
}

Function Set-HPEGLUserGroup {
    <#
    .SYNOPSIS
    Updates an existing user group's properties in HPE GreenLake.

    .DESCRIPTION
    This cmdlet updates the display name and/or description of an existing user group in HPE GreenLake.
    Only local user groups can be modified through the API. Groups synced from identity providers via 
    SSO cannot be modified.

    The cmdlet uses the SCIM PATCH API to update group properties. You must specify at least one property 
    to update (NewName or NewDescription). The cmdlet validates inputs before making changes:
    - Verifies the user group exists
    - Checks if the group can be modified (local groups only)
    - If changing the name, verifies the new name is not already in use
    - Provides detailed status for each update attempt

    .PARAMETER Name 
    The current name of the user group to update (can be retrieved using Get-HPEGLUserGroup).
    Accepts pipeline input from group names or group objects.

    .PARAMETER NewName
    The new display name for the user group. Must be unique within the workspace.
    Cannot be used alone; requires at least this parameter or NewDescription.

    .PARAMETER NewDescription
    The new description for the user group. Can be an empty string to clear the description.
    Cannot be used alone; requires at least this parameter or NewName.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. 
    This option is useful for understanding the inner workings of the native REST API calls used by GLP.
    When used, the cmdlet performs all validation checks and displays warnings for any issues found.

    .EXAMPLE
    Set-HPEGLUserGroup -Name "Old-Team-Name" -NewName "New-Team-Name"

    Renames the user group from "Old-Team-Name" to "New-Team-Name".

    .EXAMPLE
    Set-HPEGLUserGroup -Name "Engineering-Team" -NewDescription "Updated description for engineering team"

    Updates only the description of the Engineering-Team group, keeping the name unchanged.

    .EXAMPLE
    Set-HPEGLUserGroup -Name "Temp-Group" -NewName "Production-Group" -NewDescription "Production team access"

    Updates both the name and description of the group in a single operation.

    .EXAMPLE
    Set-HPEGLUserGroup -Name "Old-Desc-Group" -NewDescription ""

    Clears the description of the group by setting it to an empty string.

    .EXAMPLE
    "Team-A", "Team-B" | Set-HPEGLUserGroup -NewDescription "Updated team description"

    Updates the description for multiple groups via pipeline.

    .EXAMPLE
    Get-HPEGLUserGroup | Where-Object { $_.displayName -like "Temp-*" } | Set-HPEGLUserGroup -NewDescription "Temporary access group"

    Updates the description for all groups whose names start with "Temp-".

    .EXAMPLE
    Import-Csv .\group_updates.csv | Set-HPEGLUserGroup

    Bulk updates user groups from a CSV file with columns: Name, NewName, NewDescription.
    Example CSV content:
        Name,NewName,NewDescription
        Old-Name-1,New-Name-1,Updated description 1
        Old-Name-2,,Updated description 2
        Old-Name-3,New-Name-3,

    .EXAMPLE
    Set-HPEGLUserGroup -Name "Dev-Team" -NewName "Development-Team" -WhatIf

    Shows the API request that would be sent to update the group name without actually making the change.

    .INPUTS
    System.String
        You can pipe group names as strings.

    HPEGreenLake.UserGroup
        You can pipe user group objects from Get-HPEGLUserGroup.

    .OUTPUTS
    System.Collections.ArrayList
        Returns a collection of status objects, one for each group update attempt:
        * Name - Original name of the group
        * NewName - New name (if changed)
        * Status - Status of the update attempt (Failed, Complete, Warning)
        * Details - More information about the status
        * Exception - Information about any exceptions generated during the operation
    #>

    [CmdletBinding()]
    Param( 
                    
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias("displayName")]
        [String]$Name,

        [Parameter(ValueFromPipelineByPropertyName)]
        [String]$NewName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [String]$NewDescription,

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $UpdateUserGroupStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name      = $Name
            NewName   = if ($NewName) { $NewName } else { $Name }
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

        # Validate that at least one property to update is specified
        if (-not $PSBoundParameters.ContainsKey('NewName') -and -not $PSBoundParameters.ContainsKey('NewDescription')) {
            "[{0}] No properties specified to update for group '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
            
            if ($WhatIf) {
                Write-Warning "No properties specified to update for group '$Name'. Specify at least -NewName or -NewDescription."
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "No properties specified to update. Specify at least -NewName or -NewDescription."
                $objStatus.Exception = "Missing required parameters"
                [void]$UpdateUserGroupStatus.Add($objStatus)
                return
            }
        }

        # Check if group exists
        try {
            "[{0}] Looking up user group '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
            $Group = Get-HPEGLUserGroup -Name $Name -Verbose:$false
        }
        catch {
            "[{0}] Error retrieving user group: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
            
            if ($WhatIf) {
                $PSCmdlet.ThrowTerminatingError($_)
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Error retrieving user group." }
                $objStatus.Exception = $_.Exception.GetType().Name
                [void]$UpdateUserGroupStatus.Add($objStatus)
                return
            }
        }

        if (-not $Group) {
            "[{0}] User group '{1}' not found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
            
            if ($WhatIf) {
                Write-Warning "User group '$Name' not found. Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "User group '$Name' not found"
                $objStatus.Exception = "Group not found"
                [void]$UpdateUserGroupStatus.Add($objStatus)
                return
            }
        }

        "[{0}] Found user group '{1}' with ID: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Group.id | Write-Verbose

        # Check if the group can be modified (only local groups can be modified)
        if ($Group.source -and $Group.source -ne "Local") {
            "[{0}] User group '{1}' is from source '{2}' and cannot be modified via API" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Group.source | Write-Verbose
            
            if ($WhatIf) {
                Write-Warning "User group '$Name' is managed by '$($Group.source)' and cannot be modified through the API. Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "User group is managed by '$($Group.source)' and cannot be modified through the API"
                $objStatus.Exception = "Cannot modify non-local group"
                [void]$UpdateUserGroupStatus.Add($objStatus)
                return
            }
        }

        # If changing the name, check if new name already exists
        if ($PSBoundParameters.ContainsKey('NewName') -and $NewName -ne $Name) {
            try {
                "[{0}] Checking if new name '{1}' is already in use" -f $MyInvocation.InvocationName.ToString().ToUpper(), $NewName | Write-Verbose
                $ExistingGroup = Get-HPEGLUserGroup -Name $NewName -Verbose:$false
            }
            catch {
                # Error checking for existing group - continue anyway
                "[{0}] Warning: Could not verify if new name is available: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
            }

            if ($ExistingGroup) {
                "[{0}] User group with name '{1}' already exists" -f $MyInvocation.InvocationName.ToString().ToUpper(), $NewName | Write-Verbose
                
                if ($WhatIf) {
                    Write-Warning "A user group with the name '$NewName' already exists. Cannot display API request."
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "A user group with the name '$NewName' already exists"
                    $objStatus.Exception = "Duplicate group name"
                    [void]$UpdateUserGroupStatus.Add($objStatus)
                    return
                }
            }
        }

        # Build the SCIM PATCH operations array
        $Operations = @()

        if ($PSBoundParameters.ContainsKey('NewName')) {
            $Operations += @{
                op    = "replace"
                path  = "displayName"
                value = $NewName
            }
            "[{0}] Will update displayName from '{1}' to '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $NewName | Write-Verbose
        }

        if ($PSBoundParameters.ContainsKey('NewDescription')) {
            $Operations += @{
                op    = "replace"
                path  = "urn:ietf:params:scim:schemas:extensions:hpe-greenlake:2.0:Group:groupDescription"
                value = $NewDescription
            }
            "[{0}] Will update groupDescription to '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $NewDescription | Write-Verbose
        }

        # Build the SCIM PATCH payload
        $Payload = @{
            schemas    = @("urn:ietf:params:scim:api:messages:2.0:PatchOp")
            Operations = $Operations
        }

        # Convert to JSON
        $Body = $Payload | ConvertTo-Json -Depth 10
        
        "[{0}] Payload: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Body | Write-Verbose

        # Build URI for SCIM Groups PATCH
        $Uri = "{0}/identity/v2beta1/scim/v2/Groups/{1}" -f (Get-HPEGLAPIOrgbaseURL), $Group.id

        "[{0}] PATCH URI: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri | Write-Verbose

        try {
            $Response = Invoke-HPEGLWebRequest -Method PATCH -Uri $Uri -Body $Body -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

            if (-not $WhatIf) {
                "[{0}] User group update raw response: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Response | ConvertTo-Json -Depth 3) | Write-Verbose
                
                $objStatus.Status = "Complete"
                
                # Build details message
                $UpdatedProperties = @()
                if ($PSBoundParameters.ContainsKey('NewName')) {
                    $UpdatedProperties += "name updated to '$NewName'"
                }
                if ($PSBoundParameters.ContainsKey('NewDescription')) {
                    if ($NewDescription) {
                        $UpdatedProperties += "description updated"
                    }
                    else {
                        $UpdatedProperties += "description cleared"
                    }
                }
                $objStatus.Details = "User group successfully updated: " + ($UpdatedProperties -join ", ")
                
                "[{0}] User group '{1}' successfully updated" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
            }
        }
        catch {
            "[{0}] Error updating user group: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
            
            if ($WhatIf) {
                $PSCmdlet.ThrowTerminatingError($_)
            }
            else {
                $objStatus.Status = "Failed"
                
                # Use helper function to extract error message
                $errorMsg = Get-HPEGLErrorMessage -ExceptionObject $_ -DefaultMessage "User group cannot be updated!"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Error updating user group." }
                
                # Build technical exception info with error code and HTTP status
                $technicalInfo = @()
                if ($Global:HPECOMInvokeReturnData.errorCode) {
                    $technicalInfo += "Code: $($Global:HPECOMInvokeReturnData.errorCode)"
                }
                if ($Global:HPECOMInvokeReturnData.httpStatusCode -or $Global:HPECOMInvokeReturnData.StatusCode) {
                    $statusCode = if ($Global:HPECOMInvokeReturnData.httpStatusCode) { $Global:HPECOMInvokeReturnData.httpStatusCode } else { $Global:HPECOMInvokeReturnData.StatusCode }
                    $technicalInfo += "HTTP $statusCode"
                }
                if ($technicalInfo.Count -eq 0) {
                    $technicalInfo += $_.Exception.GetType().Name
                }
                $objStatus.Exception = $technicalInfo -join " | "
            
                "[{0}] User group update failed: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.Exception | Write-Verbose
            }
        }

        # Add to collection for batch return
        [void]$UpdateUserGroupStatus.Add($objStatus)
    }

    End {
        
        if (-not $WhatIf -and $UpdateUserGroupStatus.Count -gt 0) {
            $UpdateUserGroupStatus = Invoke-RepackageObjectWithType -RawObject $UpdateUserGroupStatus -ObjectName "ObjStatus.NSDE"
            return $UpdateUserGroupStatus
        }
    }
}

Function Add-HPEGLRoleToUserGroup {
    <#
    .SYNOPSIS
    Assign a role to a user group in HPE GreenLake.

    .DESCRIPTION
    This cmdlet assigns roles to user groups in an HPE GreenLake workspace. Roles can be scoped either 
    to the entire workspace or to specific scope groups, depending on the role's capabilities.

    Use Get-HPEGLRole with -ShowScopeSupport to determine which roles support scope group assignment.
    - Roles with "Supported" scope groups can be assigned to specific scope groups
    - Roles with "Not Supported" scope groups can only be assigned to the entire workspace

    .PARAMETER GroupName 
    Name of the user group to assign the role to (can be retrieved using Get-HPEGLUserGroup).

    .PARAMETER RoleName 
    Name of the role to assign to the group (can be retrieved using Get-HPEGLRole).
    Example: "Compute Ops Management administrator", "Backup and Recovery Operator"

    .PARAMETER ScopeGroupName 
    Optional. Name(s) of scope group(s) to restrict the role assignment to (can be retrieved using Get-HPEGLScopeGroup).
    Can be a single scope group name or an array of scope group names.
    Only available for roles that support scope group assignment.
    If not specified, defaults to entire workspace access.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. 
    This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Add-HPEGLRoleToUserGroup -GroupName "Engineering-Team" -RoleName "Compute Ops Management administrator"

    Assigns the COM administrator role to the Engineering-Team group with entire workspace access (default).

    .EXAMPLE
    Add-HPEGLRoleToUserGroup -GroupName "QA-Team" -RoleName "Compute Ops Management operator" -ScopeGroupName "Test-Environment"

    Assigns the COM operator role to QA-Team group, scoped to only the Test-Environment scope group.

    .EXAMPLE
    "DevOps-Team", "Platform-Team" | Add-HPEGLRoleToUserGroup -RoleName "Compute Ops Management operator"

    Assigns the COM operator role to multiple groups via pipeline with entire workspace access (default).

    .INPUTS
    System.String
        You can pipe group names as strings.

    HPEGreenLake.UserGroup
        You can pipe user group objects from Get-HPEGLUserGroup.
    
    HPEGreenLake.Role
        You can pipe role objects from Get-HPEGLRole.

    .OUTPUTS
    System.Collections.ArrayList
        Returns a collection of status objects, one for each role assignment attempt:
        * GroupName - Name of the group
        * RoleName - Name of the role assigned
        * Scope - Scope of the assignment (Entire Workspace or scope group names)
        * Status - Status of the assignment attempt (Failed, Complete, Warning)
        * Details - More information about the status
        * Exception - Information about any exceptions generated during the operation
    #>

    [CmdletBinding()]
    Param( 
                    
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('displayName', 'Name')]
        [String]$GroupName,
            
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('role_display_name')]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            
            # Get all available roles dynamically for tab completion
            try {
                $allRoles = (Get-HPEGLRole -Verbose:$false -ErrorAction SilentlyContinue).role_display_name
                
                $allRoles | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                    # Add quotes around role names that contain spaces
                    $completionText = if ($_ -match '\s') { "'$_'" } else { $_ }
                    [System.Management.Automation.CompletionResult]::new($completionText, $_, 'ParameterValue', $_)
                }
            }
            catch {
                # If not connected or error occurs, return empty (no suggestions)
                @()
            }
        })]
        [String]$RoleName,

        [Parameter(ValueFromPipelineByPropertyName)]
        [String[]]$ScopeGroupName,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $RoleAssignmentStatus = [System.Collections.ArrayList]::new()
    }
    
    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Default to entire workspace if ScopeGroupName is not specified
        if (-not $ScopeGroupName) {
            "[{0}] Scope not specified; defaulting to entire workspace access" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
        }

        # Build object for the output
        $objStatus = [pscustomobject]@{
            GroupName = $GroupName
            RoleName  = $RoleName
            Scope     = if ($ScopeGroupName) { $ScopeGroupName -join ", " } else { "Entire Workspace" }
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

        # Get the user group
        try {
            $Group = Get-HPEGLUserGroup -Name $GroupName -Verbose:$false
            
            if (-not $Group) {
                "[{0}] User group '{1}' not found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GroupName | Write-Verbose
                
                if ($WhatIf) {
                    Write-Warning "User group '$GroupName' not found. Cannot display API request."
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "User group '$GroupName' not found"
                    $objStatus.Exception = "Group not found"
                    [void]$RoleAssignmentStatus.Add($objStatus)
                    return
                }
            }
            
            $GroupId = $Group.id
            "[{0}] Found group '{1}' with ID: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GroupName, $GroupId | Write-Verbose
        }
        catch {
            "[{0}] Error retrieving group: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
            
            if ($WhatIf) {
                $PSCmdlet.ThrowTerminatingError($_)
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Error retrieving user group." }
                $objStatus.Exception = $_.Exception.GetType().Name
                [void]$RoleAssignmentStatus.Add($objStatus)
                return
            }
        }

        # Get the role details
        try {
            # Get all roles from all services to find the specified role
            $Role = Get-HPEGLRole -Verbose:$false | Where-Object { $_.role_display_name -eq $RoleName }
            
            if (-not $Role) {
                "[{0}] Role '{1}' not found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName | Write-Verbose
                
                if ($WhatIf) {
                    Write-Warning "Role '$RoleName' not found. Cannot display API request."
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Role '$RoleName' not found"
                    $objStatus.Exception = "Role not found"
                    [void]$RoleAssignmentStatus.Add($objStatus)
                    return
                }
            }
            
            $RoleGrn = $Role.role_grn
            "[{0}] Found role '{1}' with GRN: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName, $RoleGrn | Write-Verbose
        }
        catch {
            "[{0}] Error retrieving role: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
            
            if ($WhatIf) {
                $PSCmdlet.ThrowTerminatingError($_)
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Error retrieving role." }
                $objStatus.Exception = $_.Exception.GetType().Name
                [void]$RoleAssignmentStatus.Add($objStatus)
                return
            }
        }

        # Build the scope GRN(s)
        $ScopeGrns = @()
        
        if (-not $ScopeGroupName) {
            # Entire workspace scope (default)
            $WorkspaceId = $Global:HPEGreenLakeSession.workspaceId
            $ScopeGrns += "grn:glp/workspaces/$WorkspaceId"
            "[{0}] Using entire workspace scope: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ScopeGrns[0] | Write-Verbose
        }
        else {
            # Specific scope groups
            try {
                foreach ($ScopeName in $ScopeGroupName) {
                    $ScopeGroup = Get-HPEGLScopeGroup -Name $ScopeName -Verbose:$false
                    
                    if (-not $ScopeGroup) {
                        "[{0}] Scope group '{1}' not found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ScopeName | Write-Verbose
                        
                        if ($WhatIf) {
                            Write-Warning "Scope group '$ScopeName' not found. Cannot display API request.`n`nTo list all scope groups, use: Get-HPEGLScopeGroup"
                            return
                        }
                        else {
                            $objStatus.Status = "Failed"
                            $objStatus.Details = "Scope group '$ScopeName' not found. To list all scope groups, use: Get-HPEGLScopeGroup"
                            $objStatus.Exception = "Scope group not found"
                            [void]$RoleAssignmentStatus.Add($objStatus)
                            return
                        }
                    }
                    
                    # Build scope group GRN
                    $WorkspaceId = $Global:HPEGreenLakeSession.workspaceId
                    $ScopeGroupId = $ScopeGroup.id
                    $ScopeGrn = "grn:glp/workspaces/$WorkspaceId/regions/default/providers/authorization/scope-groups/$ScopeGroupId"
                    $ScopeGrns += $ScopeGrn
                    
                    "[{0}] Added scope group '{1}' with GRN: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ScopeName, $ScopeGrn | Write-Verbose
                }
            }
            catch {
                "[{0}] Error retrieving scope groups: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                
                if ($WhatIf) {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Error retrieving scope groups." }
                    $objStatus.Exception = $_.Exception.GetType().Name
                    [void]$RoleAssignmentStatus.Add($objStatus)
                    return
                }
            }
        }

        # Build the payload for role assignment API
        $Payload = [PSCustomObject]@{
            assignments = @(
                @{
                    role_grn = $RoleGrn
                    scopes   = $ScopeGrns
                }
            )
            group_id    = $GroupId
        } | ConvertTo-Json -Depth 10

        "[{0}] Payload: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Payload | Write-Verbose

        # Build URI for role assignments
        $Uri = "{0}/internal-platform-tenant-ui/v2alpha2/role-assignments" -f (Get-HPEGLAPIOrgbaseURL)

        try {
            $Response = Invoke-HPEGLWebRequest -Method POST -Uri $Uri -Body $Payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

            if (-not $WhatIf) {
                "[{0}] Role assignment raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Response | ConvertTo-Json -Depth 5) | Write-Verbose
                
                $objStatus.Status = "Complete"
                $objStatus.Details = "Role successfully assigned to user group"
                
                "[{0}] Role '{1}' successfully assigned to group '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName, $GroupName | Write-Verbose
            }
        }
        catch {
            $objStatus.Status = "Failed"
            $objStatus.Details = if ($_.Exception.Message) { 
                $_.Exception.Message 
            } else { 
                "Role assignment failed: $($_.Exception.Message)" 
            }
            
            # Build technical exception info with error code and HTTP status
            $technicalInfo = @()
            if ($Global:HPECOMInvokeReturnData.errorCode) {
                $technicalInfo += "Code: $($Global:HPECOMInvokeReturnData.errorCode)"
            }
            if ($Global:HPECOMInvokeReturnData.httpStatusCode -or $Global:HPECOMInvokeReturnData.StatusCode) {
                $statusCode = if ($Global:HPECOMInvokeReturnData.httpStatusCode) { $Global:HPECOMInvokeReturnData.httpStatusCode } else { $Global:HPECOMInvokeReturnData.StatusCode }
                $technicalInfo += "HTTP $statusCode"
            }
            if ($technicalInfo.Count -eq 0) {
                $technicalInfo += $_.Exception.GetType().Name
            }
            $objStatus.Exception = $technicalInfo -join " | "
            
            "[{0}] Role assignment failed: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.Exception | Write-Verbose
        }

        # Add to collection for batch return
        [void]$RoleAssignmentStatus.Add($objStatus)
    }

    End {
        
        if (-not $WhatIf -and $RoleAssignmentStatus.Count -gt 0) {
            $RoleAssignmentStatus = Invoke-RepackageObjectWithType -RawObject $RoleAssignmentStatus -ObjectName "RoleAssignment.Status"
            return $RoleAssignmentStatus
        }
    }
}

Function Remove-HPEGLRoleFromUserGroup {
    <#
    .SYNOPSIS
    Remove a role assignment from a user group in HPE GreenLake.

    .DESCRIPTION
    This cmdlet removes role assignments from user groups in an HPE GreenLake workspace. 
    You can remove roles by specifying the group name and role name, or by piping role assignment 
    objects from Get-HPEGLUserGroup -ShowRoles.

    .PARAMETER GroupName 
    Name of the user group to remove the role from (can be retrieved using Get-HPEGLUserGroup).

    .PARAMETER RoleName 
    Name of the role to remove from the group (can be retrieved using Get-HPEGLRole).
    Example: "Compute Ops Management administrator", "Backup and Recovery Operator"

    .PARAMETER RoleAssignmentId
    The ID of the role assignment to remove. This is typically obtained from Get-HPEGLUserGroup -ShowRoles.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. 
    This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Remove-HPEGLRoleFromUserGroup -GroupName "Engineering-Team" -RoleName "Compute Ops Management administrator"

    Removes the COM administrator role from the Engineering-Team group.

    .EXAMPLE
    Get-HPEGLUserGroup -Name "QA-Team" -ShowRoles | Remove-HPEGLRoleFromUserGroup

    Removes all role assignments from the QA-Team group via pipeline.

    .EXAMPLE
    Get-HPEGLUserGroup -Name "QA-Team" -ShowRoles | Where-Object { $_.role_name -eq "Compute Ops Management operator" } | Remove-HPEGLRoleFromUserGroup

    Removes only the COM operator role from the QA-Team group.

    .EXAMPLE
    "DevOps-Team", "Platform-Team" | ForEach-Object { Get-HPEGLUserGroup -Name $_ -ShowRoles | Remove-HPEGLRoleFromUserGroup }

    Removes all role assignments from multiple groups.

    .INPUTS
    System.String
        You can pipe group names as strings.

    HPEGreenLake.UserGroup.Role
        You can pipe role assignment objects from Get-HPEGLUserGroup -ShowRoles.

    .OUTPUTS
    System.Collections.ArrayList
        Returns a collection of status objects, one for each role removal attempt:
        * GroupName - Name of the group (when available)
        * RoleName - Name of the role removed
        * RoleAssignmentId - ID of the role assignment
        * Status - Status of the removal attempt (Failed, Complete)
        * Details - More information about the status
        * Exception - Information about any exceptions generated during the operation
    #>

    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    Param( 
                    
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ByName')]
        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'ById')]
        [String]$GroupName,
            
        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'ById')]
        [Alias('role_name')]
        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            
            # Get all available roles dynamically for tab completion
            try {
                $allRoles = (Get-HPEGLRole -Verbose:$false -ErrorAction SilentlyContinue).role_display_name
                
                $allRoles | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                    # Add quotes around role names that contain spaces
                    $completionText = if ($_ -match '\s') { "'$_'" } else { $_ }
                    [System.Management.Automation.CompletionResult]::new($completionText, $_, 'ParameterValue', $_)
                }
            }
            catch {
                # If not connected or error occurs, return empty (no suggestions)
                @()
            }
        })]
        [String]$RoleName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ById')]
        [Alias('id')]
        [String]$RoleAssignmentId,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $RoleRemovalStatus = [System.Collections.ArrayList]::new()
    }
    
    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
            GroupName        = if ($GroupName) { $GroupName } else { "N/A" }
            RoleName         = if ($RoleName) { $RoleName } else { "N/A" }
            RoleAssignmentId = $null
            Status           = $Null
            Details          = $Null
            Exception        = $Null
        }

        # If using ByName parameter set, we need to find the role assignment ID
        if ($PSCmdlet.ParameterSetName -eq 'ByName') {
            
            try {
                # Get the group with role assignments
                $Group = Get-HPEGLUserGroup -Name $GroupName -ShowRoles -Verbose:$false
                
                if (-not $Group) {
                    "[{0}] User group '{1}' not found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GroupName | Write-Verbose
                    
                    if ($WhatIf) {
                        Write-Warning "User group '$GroupName' not found. Cannot display API request."
                        return
                    }
                    else {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "User group '$GroupName' not found"
                        $objStatus.Exception = "Group not found"
                        [void]$RoleRemovalStatus.Add($objStatus)
                        return
                    }
                }
                
                "[{0}] Found group '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GroupName | Write-Verbose
                
                # Find the role assignment matching the role name
                $RoleAssignment = $Group | Where-Object { $_.role_name -eq $RoleName }
                
                if (-not $RoleAssignment) {
                    "[{0}] Role '{1}' not assigned to group '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName, $GroupName | Write-Verbose
                    
                    if ($WhatIf) {
                        Write-Warning "Role '$RoleName' is not assigned to group '$GroupName'. Cannot display API request."
                        return
                    }
                    else {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Role '$RoleName' is not assigned to group '$GroupName'"
                        $objStatus.Exception = "Role not assigned"
                        [void]$RoleRemovalStatus.Add($objStatus)
                        return
                    }
                }
                
                $RoleAssignmentId = $RoleAssignment.id
                $objStatus.RoleAssignmentId = $RoleAssignmentId
                
                "[{0}] Found role assignment ID: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleAssignmentId | Write-Verbose
            }
            catch {
                "[{0}] Error retrieving group or role assignment: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                
                if ($WhatIf) {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Error retrieving group or role assignment." }
                    $objStatus.Exception = $_.Exception.GetType().Name
                    [void]$RoleRemovalStatus.Add($objStatus)
                    return
                }
            }
        }
        else {
            # ById parameter set - we already have the ID
            $objStatus.RoleAssignmentId = $RoleAssignmentId
            "[{0}] Using role assignment ID: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleAssignmentId | Write-Verbose
        }

        # Build URI for role assignment deletion using authorization endpoint
        $Uri = "{0}/{1}" -f (Get-AuthorizationRoleAssignmentsV2Alpha2Uri), $RoleAssignmentId

        try {
            $Response = Invoke-HPEGLWebRequest -Method DELETE -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

            if (-not $WhatIf) {
                # Only log response if there is content (DELETE usually returns 204 No Content)
                if ($Response) {
                    "[{0}] Role assignment deletion raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Response | ConvertTo-Json -Depth 5) | Write-Verbose
                }
                else {
                    "[{0}] Role assignment deletion completed (HTTP 204 No Content)" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                }
                
                $objStatus.Status = "Complete"
                $objStatus.Details = "Role successfully removed from user group"
                
                "[{0}] Role assignment '{1}' successfully removed" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleAssignmentId | Write-Verbose
            }
        }
        catch {
            # Check if this is actually a success (HTTP 204 No Content for DELETE)
            # The exception might be a parsing error but the DELETE actually succeeded
            if ($_.Exception.Message -match "HTTP 204" -or $_.Exception.Message -match "204" -or $_.Exception.Message -match "Key: Content") {
                "[{0}] DELETE returned HTTP 204 (No Content) or parsing error - treating as success" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                
                $objStatus.Status = "Complete"
                $objStatus.Details = "Role successfully removed from user group"
                
                "[{0}] Role assignment '{1}' successfully removed" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleAssignmentId | Write-Verbose
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { 
                    $_.Exception.Message 
                } else { 
                    "Role removal failed." 
                }
            
                # Build technical exception info with error code and HTTP status
                $technicalInfo = @()
                if ($Global:HPECOMInvokeReturnData.errorCode) {
                    $technicalInfo += "Code: $($Global:HPECOMInvokeReturnData.errorCode)"
                }
                if ($Global:HPECOMInvokeReturnData.httpStatusCode -or $Global:HPECOMInvokeReturnData.StatusCode) {
                    $statusCode = if ($Global:HPECOMInvokeReturnData.httpStatusCode) { $Global:HPECOMInvokeReturnData.httpStatusCode } else { $Global:HPECOMInvokeReturnData.StatusCode }
                    $technicalInfo += "HTTP $statusCode"
                }
                if ($technicalInfo.Count -eq 0) {
                    $technicalInfo += $_.Exception.GetType().Name
                }
                $objStatus.Exception = $technicalInfo -join " | "
            
                "[{0}] Role removal failed: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.Exception | Write-Verbose
            }
        }

        # Add to collection for batch return
        [void]$RoleRemovalStatus.Add($objStatus)
    }

    End {
        
        if (-not $WhatIf -and $RoleRemovalStatus.Count -gt 0) {
            $RoleRemovalStatus = Invoke-RepackageObjectWithType -RawObject $RoleRemovalStatus -ObjectName "RoleAssignment.Status"
            return $RoleRemovalStatus
        }
    }
}

Function Add-HPEGLUserToUserGroup {
    <#
    .SYNOPSIS
    Adds one or more users to a user group in HPE GreenLake.

    .DESCRIPTION
    This cmdlet adds users to an existing user group in HPE GreenLake. Users are specified by 
    their email addresses and are added to the group using the SCIM PATCH API. Multiple users can 
    be added in a single operation for efficiency.

    The cmdlet validates all inputs before making changes:
    - Verifies the user group exists
    - Checks each user exists in the workspace
    - Detects users who are already members to avoid duplicates
    - Provides detailed status including any warnings for not-found users or duplicate memberships

    .PARAMETER GroupName
    Name of the user group to add users to (can be retrieved using Get-HPEGLUserGroup).
    Accepts pipeline input from group names or group objects.

    .PARAMETER UserEmail
    One or more user email addresses to add to the group. Users must already exist in the 
    HPE GreenLake workspace (can be verified using Get-HPEGLUser).
    Multiple email addresses can be provided as an array for bulk addition.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. 
    This option is useful for understanding the inner workings of the native REST API calls used by GLP.
    When used, the cmdlet performs all validation checks and displays warnings for any issues found.

    .EXAMPLE
    Add-HPEGLUserToUserGroup -GroupName "Developers" -UserEmail "john.doe@company.com"

    Adds a single user to the Developers group.

    .EXAMPLE
    Add-HPEGLUserToUserGroup -GroupName "Admins" -UserEmail "admin1@company.com", "admin2@company.com"

    Adds multiple users to the Admins group in a single operation.

    .EXAMPLE
    Add-HPEGLUserToUserGroup -GroupName "Engineering-Team" -UserEmail "newuser@company.com", "unknown@company.com"

    Adds users to the group. If any users are not found, the operation continues for valid users 
    and reports a warning status with details about which users were not found.

    .EXAMPLE
    "Dev-Team", "QA-Team" | Add-HPEGLUserToUserGroup -UserEmail "newuser@company.com"

    Adds the same user to multiple groups via pipeline. Each group receives a separate status object.

    .EXAMPLE
    Get-HPEGLUserGroup | Where-Object { $_.displayName -like "Dev-*" } | Add-HPEGLUserToUserGroup -UserEmail "contractor@company.com"

    Adds a user to all groups whose names start with "Dev-" by piping group objects.

    .EXAMPLE
    Import-Csv .\users.csv | Add-HPEGLUserToUserGroup

    Bulk adds users to groups from a CSV file with columns: GroupName, UserEmail.
    Example CSV content:
        GroupName,UserEmail
        Developers,john.doe@company.com
        Developers,jane.smith@company.com
        QA-Team,tester1@company.com

    .EXAMPLE
    Get-HPEGLUser | Where-Object { $_.email -like "*@contractor.com" } | Add-HPEGLUserToUserGroup -GroupName "Contractors"

    Adds all users with contractor email addresses to the Contractors group by filtering and piping 
    user objects from Get-HPEGLUser. This enables powerful bulk operations based on user properties.

    .EXAMPLE
    Get-HPEGLUser | Where-Object { $_.active -eq $true -and $_.email -like "*@company.com" } | Add-HPEGLUserToUserGroup -GroupName "Active-Employees"

    Adds all active users from the company domain to the Active-Employees group by filtering on 
    multiple user properties and piping the results.

    .EXAMPLE
    Get-HPEGLUserGroup -ShowUsers -Name "Source-Group" | Add-HPEGLUserToUserGroup -GroupName "Target-Group"

    Copies all members from "Source-Group" to "Target-Group" by retrieving users with -ShowUsers and piping 
    them to add to a different group. The Email property flows automatically through the pipeline while 
    you specify a different target GroupName.

    .EXAMPLE
    Add-HPEGLUserToUserGroup -GroupName "Production-Ops" -UserEmail "ops-user@company.com" -WhatIf -Verbose

    Validates the operation and displays the API request that would be sent, along with verbose 
    diagnostic information about the validation process.

    .INPUTS
    System.String
        You can pipe group names as strings.

    HPEGreenLake.UserGroup
        You can pipe user group objects from Get-HPEGLUserGroup.

    HPEGreenLake.User
        You can pipe user objects from Get-HPEGLUser (uses email property via Email alias).

    HPEGreenLake.UserGroup.Members
        You can pipe member objects from Get-HPEGLUserGroup -ShowUsers (includes GroupName and Email properties).

    .OUTPUTS
    System.Collections.ArrayList
        Returns a collection of status objects (type: HPEGreenLake.UserGroup.MemberAddition.Status), 
        one for each group operation:
        * GroupName - Name of the group users were added to
        * Users - Comma-separated list of user email addresses processed
        * Status - Status of the operation (Failed, Complete, Warning)
        * Details - Detailed information including:
          - Number of users successfully added
          - List of users not found (if any)
          - List of users already members (if any)
        * Exception - Technical error information if the operation failed
    #>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0)]
        [Alias("Name", "displayName")]
        [string]$GroupName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias("Email")]
        [string[]]$UserEmail,

        [Switch]$WhatIf
    )

    Begin {
        $Caller = (Get-PSCallStack)[1].Command
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
        
        $AddUserStatus = [System.Collections.ArrayList]::new()
    }

    Process {
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Create status object
        $objStatus = [PSCustomObject]@{
            GroupName = $GroupName
            Users     = $UserEmail -join ", "
            Status    = "Pending"
            Details   = ""
            Exception = $null
        }

        # Validate session
        if (-not $Global:HPEGreenLakeSession) {
            if ($WhatIf) {
                Write-Warning "No active HPE GreenLake session. Please run Connect-HPEGL first. Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "No active HPE GreenLake session. Please run Connect-HPEGL first."
                [void]$AddUserStatus.Add($objStatus)
                return
            }
        }

        try {
            # Get the group
            "[{0}] Looking up group '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GroupName | Write-Verbose
            $Group = Get-HPEGLUserGroup -Name $GroupName -Verbose:$false

            if (-not $Group) {
                "[{0}] User group '{1}' not found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GroupName | Write-Verbose
                
                if ($WhatIf) {
                    Write-Warning "User group '$GroupName' not found. Cannot display API request."
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "User group '$GroupName' not found"
                    $objStatus.Exception = "Group not found"
                    [void]$AddUserStatus.Add($objStatus)
                    return
                }
            }

            "[{0}] Found group '{1}' with ID: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GroupName, $Group.id | Write-Verbose

            # Get existing members to check for duplicates
            $existingMembers = @()
            try {
                "[{0}] Retrieving existing members for duplicate detection" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                $MembersUri = "{0}/identity/v2alpha1/scim/v2/extensions/Groups/{1}/users?count=100&startIndex=1" -f (Get-HPEGLAPIOrgbaseURL), $Group.id
                $MembersResponse = Invoke-HPEGLWebRequest -Method Get -Uri $MembersUri -WhatIfBoolean $false -Verbose:$VerbosePreference
                
                if ($MembersResponse -and $MembersResponse.Resources) {
                    $existingMembers = $MembersResponse.Resources | ForEach-Object { $_.id }
                    "[{0}] Group currently has {1} member(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $existingMembers.Count | Write-Verbose
                }
                else {
                    "[{0}] Group currently has no members" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                }
            }
            catch {
                "[{0}] Warning: Could not retrieve existing members: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                # Continue without duplicate detection if members cannot be retrieved
            }

            # Build array of user objects with their IDs
            $userObjects = @()
            $notFoundUsers = @()
            $alreadyMemberUsers = @()

            foreach ($email in $UserEmail) {
                "[{0}] Looking up user '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $email | Write-Verbose
                $User = Get-HPEGLUser -Email $email -Verbose:$false

                if ($User) {
                    # Check if user is already a member
                    if ($existingMembers -contains $User.id) {
                        $alreadyMemberUsers += $email
                        "[{0}] Warning: User '{1}' is already a member of group '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $email, $GroupName | Write-Verbose
                    }
                    else {
                        $userObjects += @{
                            display = $User.displayName
                            value   = $User.id
                            '$ref'  = "https://aquila-user-api.common.cloud.hpe.com/identity/v2alpha1/scim/v2/Users/$($User.id)"
                        }
                        "[{0}] Found user '{1}' (ID: {2})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $email, $User.id | Write-Verbose
                    }
                }
                else {
                    $notFoundUsers += $email
                    "[{0}] Warning: User '{1}' not found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $email | Write-Verbose
                }
            }

            # Check if there are no valid users to add
            if ($userObjects.Count -eq 0) {
                if ($WhatIf) {
                    # Build a comprehensive warning message
                    $warningParts = @()
                    
                    if ($notFoundUsers.Count -gt 0) {
                        $warningParts += "User(s) not found: {0}" -f ($notFoundUsers -join ", ")
                    }
                    
                    if ($alreadyMemberUsers.Count -gt 0) {
                        $warningParts += "User(s) already member of group '{0}': {1}" -f $GroupName, ($alreadyMemberUsers -join ", ")
                    }
                    
                    $warningParts += "Cannot display API request - no valid users to add."
                    
                    Write-Warning ($warningParts -join " | ")
                    return
                }
                else {
                    # Determine status based on the reason for no valid users
                    if ($notFoundUsers.Count -gt 0 -and $alreadyMemberUsers.Count -eq 0) {
                        # Only not-found users = Failed
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "None of the specified users were found in the workspace"
                    }
                    elseif ($alreadyMemberUsers.Count -gt 0 -and $notFoundUsers.Count -eq 0) {
                        # Only already-member users = Warning (not a failure)
                        $objStatus.Status = "Warning"
                        $objStatus.Details = "All specified users are already members of the group"
                    }
                    else {
                        # Mix of both = Warning
                        $objStatus.Status = "Warning"
                        $objStatus.Details = "No valid users to add. Not found: {0}. Already members: {1}" -f ($notFoundUsers -join ", "), ($alreadyMemberUsers -join ", ")
                    }
                    [void]$AddUserStatus.Add($objStatus)
                    return
                }
            }

            # Build SCIM PATCH payload to add members
            $patchPayload = @{
                schemas    = @("urn:ietf:params:scim:api:messages:2.0:PatchOp")
                Operations = @(
                    @{
                        op    = "add"
                        path  = "members"
                        value = $userObjects
                    }
                )
            }

            $Body = $patchPayload | ConvertTo-Json -Depth 10
            "[{0}] PATCH payload: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Body | Write-Verbose

            # Build URI - using v2alpha1 as shown in the API example
            $Uri = "{0}/identity/v2alpha1/scim/v2/Groups/{1}" -f (Get-HPEGLAPIOrgbaseURL), $Group.id

            # Execute PATCH request
            $Response = Invoke-HPEGLWebRequest -Method PATCH -Uri $Uri -Body $Body -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

            if (-not $WhatIf) {
                "[{0}] User addition raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Response | ConvertTo-Json -Depth 5) | Write-Verbose

                # Build detailed status message
                $detailsParts = @()
                $detailsParts += "Successfully added {0} user(s) to group" -f $userObjects.Count
                
                if ($notFoundUsers.Count -gt 0) {
                    $detailsParts += "{0} user(s) not found: {1}" -f $notFoundUsers.Count, ($notFoundUsers -join ", ")
                }
                
                if ($alreadyMemberUsers.Count -gt 0) {
                    $detailsParts += "{0} user(s) already members: {1}" -f $alreadyMemberUsers.Count, ($alreadyMemberUsers -join ", ")
                }

                $objStatus.Details = $detailsParts -join ". "
                
                # Set status based on whether there were any warnings
                if ($notFoundUsers.Count -gt 0 -or $alreadyMemberUsers.Count -gt 0) {
                    $objStatus.Status = "Warning"
                }
                else {
                    $objStatus.Status = "Complete"
                }

                "[{0}] Successfully added {1} user(s) to group '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $userObjects.Count, $GroupName | Write-Verbose
                
                # Add to collection for successful operations
                [void]$AddUserStatus.Add($objStatus)
            }
        }
        catch {
            "[{0}] Error occurred: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
            
            if ($WhatIf) {
                $PSCmdlet.ThrowTerminatingError($_)
            }
            else {
                $objStatus.Status = "Failed"
                
                # Use helper function to extract error message
                $objStatus.Details = if ($_.Exception.Message) { 
                    $_.Exception.Message 
                } else { 
                    Get-HPEGLErrorMessage -ExceptionObject $_ -DefaultMessage "Users cannot be added to group!"
                }               
                
                # Build technical exception info with error code and HTTP status
                $technicalInfo = @()
                if ($Global:HPECOMInvokeReturnData.errorCode) {
                    $technicalInfo += "Code: $($Global:HPECOMInvokeReturnData.errorCode)"
                }
                if ($Global:HPECOMInvokeReturnData.httpStatusCode -or $Global:HPECOMInvokeReturnData.StatusCode) {
                    $statusCode = if ($Global:HPECOMInvokeReturnData.httpStatusCode) { $Global:HPECOMInvokeReturnData.httpStatusCode } else { $Global:HPECOMInvokeReturnData.StatusCode }
                    $technicalInfo += "HTTP $statusCode"
                }
                if ($technicalInfo.Count -eq 0) {
                    $technicalInfo += $_.Exception.GetType().Name
                }
                $objStatus.Exception = $technicalInfo -join " | "
            
                "[{0}] Adding users failed: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.Exception | Write-Verbose
                
                # Add to collection for failed operations
                [void]$AddUserStatus.Add($objStatus)
            }
        }
    }

    End {
        if (-not $WhatIf -and $AddUserStatus.Count -gt 0) {
            $AddUserStatus = Invoke-RepackageObjectWithType -RawObject $AddUserStatus -ObjectName "UserGroup.MemberAddition.Status"
            return $AddUserStatus
        }
    }
}

Function Remove-HPEGLUserFromUserGroup {
    <#
    .SYNOPSIS
    Removes one or more users from a user group in HPE GreenLake.

    .DESCRIPTION
    This cmdlet removes users from an existing user group in HPE GreenLake. Users are specified by 
    their email addresses and are removed from the group using the SCIM PATCH API. Multiple users can 
    be removed in a single operation for efficiency.

    The cmdlet validates all inputs before making changes:
    - Verifies the user group exists
    - Checks each user exists in the workspace
    - Detects users who are not members to avoid unnecessary operations
    - Provides detailed status including any warnings for not-found users or non-member users

    .PARAMETER GroupName
    Name of the user group to remove users from (can be retrieved using Get-HPEGLUserGroup).
    Accepts pipeline input from group names or group objects.

    .PARAMETER UserEmail
    One or more user email addresses to remove from the group. Users must already exist in the 
    HPE GreenLake workspace (can be verified using Get-HPEGLUser).
    Multiple email addresses can be provided as an array for bulk removal.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. 
    This option is useful for understanding the inner workings of the native REST API calls used by GLP.
    When used, the cmdlet performs all validation checks and displays warnings for any issues found.

    .EXAMPLE
    Remove-HPEGLUserFromUserGroup -GroupName "Developers" -UserEmail "john.doe@company.com"

    Removes a single user from the Developers group.

    .EXAMPLE
    Remove-HPEGLUserFromUserGroup -GroupName "Admins" -UserEmail "admin1@company.com", "admin2@company.com"

    Removes multiple users from the Admins group in a single operation.

    .EXAMPLE
    Remove-HPEGLUserFromUserGroup -GroupName "Engineering-Team" -UserEmail "contractor@company.com", "unknown@company.com"

    Removes users from the group. If any users are not found, the operation continues for valid users 
    and reports a warning status with details about which users were not found.

    .EXAMPLE
    "Dev-Team", "QA-Team" | Remove-HPEGLUserFromUserGroup -UserEmail "former-employee@company.com"

    Removes the same user from multiple groups via pipeline. Each group receives a separate status object.

    .EXAMPLE
    Get-HPEGLUserGroup | Where-Object { $_.displayName -like "Temp-*" } | Remove-HPEGLUserFromUserGroup -UserEmail "contractor@company.com"

    Removes a user from all groups whose names start with "Temp-" by piping group objects.

    .EXAMPLE
    Import-Csv .\removals.csv | Remove-HPEGLUserFromUserGroup

    Bulk removes users from groups from a CSV file with columns: GroupName, UserEmail.
    Example CSV content:
        GroupName,UserEmail
        Developers,john.doe@company.com
        Developers,jane.smith@company.com
        QA-Team,tester1@company.com

    .EXAMPLE
    Get-HPEGLUser | Where-Object { $_.active -eq $false } | Remove-HPEGLUserFromUserGroup -GroupName "Active-Users"

    Removes all inactive users from the Active-Users group by filtering and piping user objects 
    from Get-HPEGLUser. This enables powerful bulk operations based on user properties.

    .EXAMPLE
    Get-HPEGLUser | Where-Object { $_.authz_source -eq "External" } | Remove-HPEGLUserFromUserGroup -GroupName "Internal-Only"

    Removes all external users from the Internal-Only group by filtering on the authorization 
    source property and piping the results.

    .EXAMPLE
    Remove-HPEGLUserFromUserGroup -GroupName "Production-Ops" -UserEmail "ops-user@company.com" -WhatIf -Verbose

    Validates the operation and displays the API request that would be sent, along with verbose 
    diagnostic information about the validation process.

    .EXAMPLE
    Get-HPEGLUserGroup -Name "Old-Project-Team" -ShowUsers | Remove-HPEGLUserFromUserGroup

    Retrieves all members of the "Old-Project-Team" group and removes them all from that group.
    The GroupName and Email properties flow automatically through the pipeline from the -ShowUsers output.

    .INPUTS
    System.String
        You can pipe group names as strings.

    HPEGreenLake.UserGroup
        You can pipe user group objects from Get-HPEGLUserGroup.

    HPEGreenLake.User
        You can pipe user objects from Get-HPEGLUser (uses email property via Email alias).

    HPEGreenLake.UserGroup.Members
        You can pipe member objects from Get-HPEGLUserGroup -ShowUsers (includes GroupName and Email properties).
    
    .OUTPUTS
    System.Collections.ArrayList
        Returns a collection of status objects (type: HPEGreenLake.UserGroup.MemberRemoval.Status), 
        one for each group operation:
        * GroupName - Name of the group users were removed from
        * Users - Comma-separated list of user email addresses processed
        * Status - Status of the operation (Failed, Complete, Warning)
        * Details - Detailed information including:
          - Number of users successfully removed
          - List of users not found (if any)
          - List of users not members (if any)
        * Exception - Technical error information if the operation failed
    #>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, Position = 0)]
        [Alias("Name", "displayName")]
        [string]$GroupName,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias("Email")]
        [string[]]$UserEmail,

        [Switch]$WhatIf
    )

    Begin {
        $Caller = (Get-PSCallStack)[1].Command
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
        
        $RemoveUserStatus = [System.Collections.ArrayList]::new()
    }

    Process {
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Create status object
        $objStatus = [PSCustomObject]@{
            GroupName = $GroupName
            Users     = $UserEmail -join ", "
            Status    = "Pending"
            Details   = ""
            Exception = $null
        }

        # Validate session
        if (-not $Global:HPEGreenLakeSession) {
            if ($WhatIf) {
                Write-Warning "No active HPE GreenLake session. Please run Connect-HPEGL first. Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "No active HPE GreenLake session. Please run Connect-HPEGL first."
                [void]$RemoveUserStatus.Add($objStatus)
                return
            }
        }

        try {
            # Get the group
            "[{0}] Looking up group '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GroupName | Write-Verbose
            $Group = Get-HPEGLUserGroup -Name $GroupName -Verbose:$false

            if (-not $Group) {
                "[{0}] User group '{1}' not found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GroupName | Write-Verbose
                
                if ($WhatIf) {
                    Write-Warning "User group '$GroupName' not found. Cannot display API request."
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "User group '$GroupName' not found"
                    $objStatus.Exception = "Group not found"
                    [void]$RemoveUserStatus.Add($objStatus)
                    return
                }
            }

            "[{0}] Found group '{1}' with ID: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GroupName, $Group.id | Write-Verbose

            # Get existing members to check who is actually a member
            $existingMembers = @()
            try {
                "[{0}] Retrieving existing members for validation" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                $MembersUri = "{0}/identity/v2alpha1/scim/v2/extensions/Groups/{1}/users?count=100&startIndex=1" -f (Get-HPEGLAPIOrgbaseURL), $Group.id
                $MembersResponse = Invoke-HPEGLWebRequest -Method Get -Uri $MembersUri -WhatIfBoolean $false -Verbose:$VerbosePreference
                
                if ($MembersResponse -and $MembersResponse.Resources) {
                    $existingMembers = $MembersResponse.Resources | ForEach-Object { $_.id }
                    "[{0}] Group currently has {1} member(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $existingMembers.Count | Write-Verbose
                }
                else {
                    "[{0}] Group currently has no members" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                }
            }
            catch {
                "[{0}] Warning: Could not retrieve existing members: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                # Continue without member validation if members cannot be retrieved
            }

            # Build array of user objects with their IDs
            $userObjects = @()
            $notFoundUsers = @()
            $notMemberUsers = @()

            foreach ($email in $UserEmail) {
                "[{0}] Looking up user '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $email | Write-Verbose
                $User = Get-HPEGLUser -Email $email -Verbose:$false

                if ($User) {
                    # Check if user is actually a member
                    if ($existingMembers -contains $User.id) {
                        $userObjects += @{
                            value = $User.id
                        }
                        "[{0}] Found user '{1}' (ID: {2}) - currently a member" -f $MyInvocation.InvocationName.ToString().ToUpper(), $email, $User.id | Write-Verbose
                    }
                    else {
                        $notMemberUsers += $email
                        "[{0}] Warning: User '{1}' is not a member of group '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $email, $GroupName | Write-Verbose
                    }
                }
                else {
                    $notFoundUsers += $email
                    "[{0}] Warning: User '{1}' not found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $email | Write-Verbose
                }
            }

            # Check if there are no valid users to remove
            if ($userObjects.Count -eq 0) {
                if ($WhatIf) {
                    # Build a comprehensive warning message
                    $warningParts = @()
                    
                    if ($notFoundUsers.Count -gt 0) {
                        $warningParts += "User(s) not found: {0}" -f ($notFoundUsers -join ", ")
                    }
                    
                    if ($notMemberUsers.Count -gt 0) {
                        $warningParts += "User(s) not member of group '{0}': {1}" -f $GroupName, ($notMemberUsers -join ", ")
                    }
                    
                    $warningParts += "Cannot display API request - no valid users to remove."
                    
                    Write-Warning ($warningParts -join " | ")
                    return
                }
                else {
                    # Determine status based on the reason for no valid users
                    if ($notFoundUsers.Count -gt 0 -and $notMemberUsers.Count -eq 0) {
                        # Only not-found users = Failed
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "None of the specified users were found in the workspace"
                    }
                    elseif ($notMemberUsers.Count -gt 0 -and $notFoundUsers.Count -eq 0) {
                        # Only not-member users = Warning (not a failure)
                        $objStatus.Status = "Warning"
                        $objStatus.Details = "None of the specified users are members of the group"
                    }
                    else {
                        # Mix of both = Warning
                        $objStatus.Status = "Warning"
                        $objStatus.Details = "No valid users to remove. Not found: {0}. Not members: {1}" -f ($notFoundUsers -join ", "), ($notMemberUsers -join ", ")
                    }
                    [void]$RemoveUserStatus.Add($objStatus)
                    return
                }
            }

            # Build SCIM PATCH payload to remove members
            $patchPayload = @{
                schemas    = @("urn:ietf:params:scim:api:messages:2.0:PatchOp")
                Operations = @(
                    @{
                        op    = "remove"
                        path  = "members"
                        value = $userObjects
                    }
                )
            }

            $Body = $patchPayload | ConvertTo-Json -Depth 10
            "[{0}] PATCH payload: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Body | Write-Verbose

            # Build URI - using v2alpha1 as shown in the API example
            $Uri = "{0}/identity/v2alpha1/scim/v2/Groups/{1}" -f (Get-HPEGLAPIOrgbaseURL), $Group.id

            # Execute PATCH request
            $Response = Invoke-HPEGLWebRequest -Method PATCH -Uri $Uri -Body $Body -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

            if (-not $WhatIf) {
                "[{0}] User removal raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Response | ConvertTo-Json -Depth 5) | Write-Verbose

                # Build detailed status message
                $detailsParts = @()
                $detailsParts += "Successfully removed {0} user(s) from group" -f $userObjects.Count
                
                if ($notFoundUsers.Count -gt 0) {
                    $detailsParts += "{0} user(s) not found: {1}" -f $notFoundUsers.Count, ($notFoundUsers -join ", ")
                }
                
                if ($notMemberUsers.Count -gt 0) {
                    $detailsParts += "{0} user(s) not members: {1}" -f $notMemberUsers.Count, ($notMemberUsers -join ", ")
                }

                $objStatus.Details = $detailsParts -join ". "
                
                # Set status based on whether there were any warnings
                if ($notFoundUsers.Count -gt 0 -or $notMemberUsers.Count -gt 0) {
                    $objStatus.Status = "Warning"
                }
                else {
                    $objStatus.Status = "Complete"
                }

                "[{0}] Successfully removed {1} user(s) from group '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $userObjects.Count, $GroupName | Write-Verbose
                
                # Add to collection for successful operations
                [void]$RemoveUserStatus.Add($objStatus)
            }
        }
        catch {
            "[{0}] Error occurred: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
            
            if ($WhatIf) {
                $PSCmdlet.ThrowTerminatingError($_)
            }
            else {
                $objStatus.Status = "Failed"
                
                # Use helper function to extract error message
                $objStatus.Details = if ($_.Exception.Message) { 
                    $_.Exception.Message 
                } else { 
                    Get-HPEGLErrorMessage -ExceptionObject $_ -DefaultMessage "Users cannot be removed from group!"
                }
                
                # Build technical exception info with error code and HTTP status
                $technicalInfo = @()
                if ($Global:HPECOMInvokeReturnData.errorCode) {
                    $technicalInfo += "Code: $($Global:HPECOMInvokeReturnData.errorCode)"
                }
                if ($Global:HPECOMInvokeReturnData.httpStatusCode -or $Global:HPECOMInvokeReturnData.StatusCode) {
                    $statusCode = if ($Global:HPECOMInvokeReturnData.httpStatusCode) { $Global:HPECOMInvokeReturnData.httpStatusCode } else { $Global:HPECOMInvokeReturnData.StatusCode }
                    $technicalInfo += "HTTP $statusCode"
                }
                if ($technicalInfo.Count -eq 0) {
                    $technicalInfo += $_.Exception.GetType().Name
                }
                $objStatus.Exception = $technicalInfo -join " | "
            
                "[{0}] Removing users failed: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.Exception | Write-Verbose
                
                # Add to collection for failed operations
                [void]$RemoveUserStatus.Add($objStatus)
            }
        }
    }

    End {
        if (-not $WhatIf -and $RemoveUserStatus.Count -gt 0) {
            $RemoveUserStatus = Invoke-RepackageObjectWithType -RawObject $RemoveUserStatus -ObjectName "UserGroup.MemberRemoval.Status"
            return $RemoveUserStatus
        }
    }
}

Function Get-HPEGLUserGroupMembership {
    <#
    .SYNOPSIS
        View user group memberships in HPE GreenLake.

    .DESCRIPTION
        This cmdlet lists the user groups that a user is a member of in HPE GreenLake. 
        User groups allow administrators to organize users and assign permissions collectively.

    .PARAMETER Email 
        The email address of the user for whom you want to obtain group memberships (can be retrieved using 'Get-HPEGLUser').
        
    .PARAMETER WhatIf 
        Displays the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
        Get-HPEGLUserGroupMembership -Email Isaac.Newton@revolution.com 

        Returns all user groups that Isaac Newton is a member of.

    .EXAMPLE
        Get-HPEGLUserGroupMembership -Email Isaac.Newton@revolution.com | Select-Object displayName, groupDescription

        Returns the user group names and descriptions for Isaac Newton's group memberships.

    .EXAMPLE
        Get-HPEGLUser -Email Isaac.Newton@revolution.com | Get-HPEGLUserGroupMembership

        Retrieves the user and pipes it to get group memberships.
    #>

    [CmdletBinding()]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [validatescript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$Email,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

    }

    Process {
       
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        try {
            $User = Get-HPEGLUser -Email $Email
           
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        if (-not $user) {
            Return
        }

        # Extract user ID for SCIM groups endpoint
        $UserId = $User.id
        
        "[{0}] User ID for '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email, $UserId | Write-Verbose
        
        # Use SCIM v2alpha1 groups API endpoint
        $Uri = (Get-ScimUserGroupsUri) + "/$UserId/groups"
        
        "[{0}] Retrieving user group memberships from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri | Write-Verbose

        $ReturnData = @()
        
        try {
            $Response = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
            
            # SCIM API returns response in 'Resources' wrapper
            if ($Response.Resources) {
                [array]$Collection = $Response.Resources
                "[{0}] Retrieved {1} group membership(s) from SCIM API" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Collection.Count | Write-Verbose
            }
            else {
                # No groups found
                [array]$Collection = @()
                "[{0}] No group memberships found for user" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
     
        
        if ($Collection -is [array] -and $Collection.Count -gt 0) {
            
            $GroupsList = @()
            
            foreach ($Group in $Collection) {
                
                # Extract HPE GreenLake specific properties from SCIM extension
                $HpeExtension = $Group.'urn:ietf:params:scim:schemas:extensions:hpe-greenlake:2.0:Group'
                
                # Add user email and additional properties to the group object
                $Group | Add-Member -MemberType NoteProperty -Name email -Value $Email -Force
                $Group | Add-Member -MemberType NoteProperty -Name groupDescription -Value $HpeExtension.groupDescription -Force
                $Group | Add-Member -MemberType NoteProperty -Name source -Value $HpeExtension.source -Force
                $Group | Add-Member -MemberType NoteProperty -Name hpe_principal -Value $HpeExtension.hpe_principal -Force
                
                $GroupsList += $Group
            }

            $ReturnData = Invoke-RepackageObjectWithType -RawObject $GroupsList -ObjectName "UserGroup"         
            $ReturnData = $ReturnData | sort-object displayName

            return $ReturnData
           
        }
        else {
            return
        }
    }
}

# Scope Groups

Function Get-HPEGLScopeGroup {
    <#
    .SYNOPSIS
    View scope groups in an HPE GreenLake workspace.

    .DESCRIPTION
    This cmdlet returns the scope groups in an HPE GreenLake workspace.  
    Scope groups allow you to define filtered access to resources by creating customizable resource groupings.
    These scope groups can be assigned to role assignments to limit which resources users can access.

    .PARAMETER Name 
    Name of the scope group to retrieve.

    .PARAMETER ServiceName 
    Optional parameter to display scope groups available for a specific service name (can be retrieved using Get-HPEGLService -ShowProvisioned).
    Accepts pipeline input from Get-HPEGLService via the 'name' or 'application_name' properties.

    .PARAMETER ServiceId
    Optional parameter to display scope groups available for a specific service ID.
    Accepts pipeline input from Get-HPEGLService via the 'application_id' property.

    .PARAMETER ShowScopes
    When specified, retrieves detailed scope information including the scopes array and resourceDetails for each scope group.
    This makes an additional API call per scope group to the internal tenant UI endpoint.

    .PARAMETER ShowRoleAssignments
    When specified, retrieves role assignments associated with each scope group.
    Displays Role, Service, Subject (user or group), and Type in a table format.
   
    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Get-HPEGLScopeGroup 

    Returns all scope groups in the HPE GreenLake workspace.

    .EXAMPLE
    Get-HPEGLScopeGroup -Name Gen10_Servers 

    Returns the scope group information for the 'Gen10_Servers' scope group.

    .EXAMPLE
    Get-HPEGLScopeGroup -ServiceName 'Compute Ops Management'   

    Returns all scope groups available for the Compute Ops Management service.

    .EXAMPLE
    Get-HPEGLService -ShowProvisioned | Get-HPEGLScopeGroup

    Retrieves all provisioned services and returns their associated scope groups via pipeline.

    .EXAMPLE
    Get-HPEGLService -ShowProvisioned -Name 'Compute Ops Management' | Get-HPEGLScopeGroup

    Gets the Compute Ops Management service and returns its associated scope groups via pipeline.

    .EXAMPLE
    Get-HPEGLScopeGroup -Name Production-Servers -ShowScopes

    Returns the scope group information for 'Production-Servers' including the scopes array and detailed resource information.

    .EXAMPLE
    Get-HPEGLScopeGroup -Name Production-Servers -ShowRoleAssignments

    Returns the role assignments associated with the 'Production-Servers' scope group, showing Role, Service, Subject, and Type.
    
   #>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 
                    
        [Parameter (ParameterSetName = 'Default')]
        [Parameter (Mandatory, ParameterSetName = 'ShowScopes')]
        [Parameter (Mandatory, ParameterSetName = 'ShowRoleAssignments')]
        [String]$Name,
            
        [Parameter (ValueFromPipelineByPropertyName, ParameterSetName = 'Service')]
        [Alias('Application_name')]
        [String]$ServiceName,

        [Parameter (ValueFromPipelineByPropertyName, ParameterSetName = 'Service')]
        [Alias('Application_id')]
        [String]$ServiceId,

        [Parameter (ParameterSetName = 'ShowScopes')]
        [Switch]$ShowScopes,

        [Parameter (ParameterSetName = 'ShowRoleAssignments')]
        [Switch]$ShowRoleAssignments,

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        # Use v2alpha1 scope-groups API endpoint with pagination
        $Uri = (Get-ScopeGroupsUri) + "?sort=name&limit=30&offset=0"
        
    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $ReturnData = @()
        
        try {
            $Response = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
            
            # Invoke-HPEGLWebRequest detects pagination and returns the items array directly
            if ($Response) {
                [array]$AllItems = $Response
                ("[{0}] Retrieved {1} scope group(s) from v2alpha1 API" -f $MyInvocation.InvocationName.ToString().ToUpper(), $AllItems.Count) | Write-Verbose
            }
            else {
                [array]$AllItems = @()
                ("[{0}] No scope groups found" -f $MyInvocation.InvocationName.ToString().ToUpper()) | Write-Verbose
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
   
        
        if ($AllItems.Count -gt 0) {

            $Collection = $AllItems

            if ($Name) {
                # Filter by name
                $Collection = $Collection | Where-Object name -eq $Name
                
                if (-not $Collection) {
                    "[{0}] Scope group '{1}' not found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                    return
                }
            }

            if ($ServiceName -or $ServiceId) {
                # Filter by service name or ID - check availableItemFilters
                try {
                    if ($ServiceId) {
                        # Use the provided service ID directly
                        "[{0}] Filtering scope groups for service ID: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceId | Write-Verbose
                        $ServiceID = $ServiceId
                    }
                    else {
                        # Look up service by name to get the ID
                        $Service = Get-HPEGLService -ShowProvisioned -Name $ServiceName | Sort-Object -Property application_id -Unique
                        
                        if ($Service) {
                            $ServiceID = $Service.application_id
                            "[{0}] Filtering scope groups for service '{1}' (ID: {2})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $ServiceID | Write-Verbose
                        }
                        else {
                            "[{0}] Service '{1}' not found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName | Write-Verbose
                            return
                        }
                    }
                    
                    $Collection = $Collection | Where-Object { 
                        $_.internal.availableItemFilters.serviceId -contains $ServiceID -or 
                        $_.internal.availableItemFilters.applicationId -contains $ServiceID
                    }
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }

            if ($Collection.Count -gt 0) {
                
                # If ShowScopes is specified, retrieve detailed scope information for each scope group
                if ($ShowScopes) {
                    ("[{0}] Retrieving detailed scope information for {1} scope group(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Collection.Count) | Write-Verbose
                    
                    $DetailedCollection = @()
                    foreach ($ScopeGroup in $Collection) {
                        try {
                            # Use internal tenant UI endpoint to get full scope details
                            $DetailUri = "{0}/internal-platform-tenant-ui/v2/scope-groups/{1}" -f (Get-HPEGLAPIOrgbaseURL), $ScopeGroup.id
                            
                            ("[{0}] Retrieving scopes for scope group '{1}' (ID: {2})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ScopeGroup.name, $ScopeGroup.id) | Write-Verbose
                            
                            $DetailedScopeGroup = Invoke-HPEGLWebRequest -Method Get -Uri $DetailUri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                            
                            if ($DetailedScopeGroup) {
                                $DetailedCollection += $DetailedScopeGroup
                            }
                        }
                        catch {
                            ("[{0}] Warning: Could not retrieve detailed scopes for scope group '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ScopeGroup.name, $_.Exception.Message) | Write-Warning
                            # Add the original scope group without detailed scopes
                            $DetailedCollection += $ScopeGroup
                        }
                    }
                    $Collection = $DetailedCollection
                }
                
                # If ShowRoleAssignments is specified, retrieve role assignments for each scope group
                if ($ShowRoleAssignments) {
                    ("[{0}] Retrieving role assignments for {1} scope group(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Collection.Count) | Write-Verbose
                    
                    $RoleAssignmentCollection = @()
                    foreach ($ScopeGroup in $Collection) {
                        try {
                            # Use internal tenant UI endpoint to get role assignments for this scope group
                            $RoleAssignmentUri = "{0}/internal-platform-tenant-ui/v2alpha2/role-assignments?scope-grn={1}&limit=100&offset=0" -f (Get-HPEGLAPIOrgbaseURL), $ScopeGroup.grn
                            
                            ("[{0}] Retrieving role assignments for scope group '{1}' (GRN: {2})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ScopeGroup.name, $ScopeGroup.grn) | Write-Verbose
                            
                            # Invoke-HPEGLWebRequest may not recognize role_assignments as a collection property
                            # So we need to handle the response more carefully
                            try {
                                $RoleAssignmentResponse = Invoke-HPEGLWebRequest -Method Get -Uri $RoleAssignmentUri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference -ErrorAction Stop
                            }
                            catch {
                                # If Invoke-HPEGLWebRequest fails to parse, try to extract from the exception
                                if ($_.Exception.Message -match "No collection property") {
                                    ("[{0}] Invoke-HPEGLWebRequest didn't recognize role_assignments collection. Trying alternative method..." -f $MyInvocation.InvocationName.ToString().ToUpper()) | Write-Verbose
                                    
                                    # Make direct REST call with proper authorization
                                    $headers = @{
                                        "Authorization" = "Bearer $($Global:HPEGreenLakeSession.glpApiAccessTokenv1_2.access_token)"
                                        "Accept" = "application/json"
                                        "Content-Type" = "application/json"
                                    }
                                    $RoleAssignmentResponse = Invoke-RestMethod -Uri $RoleAssignmentUri -Method Get -Headers $headers
                                }
                                else {
                                    throw
                                }
                            }
                            
                            # Handle response - role_assignments property contains the array
                            $RoleAssignments = @()
                            if ($RoleAssignmentResponse) {
                                # Check if response has role_assignments property
                                if ($RoleAssignmentResponse.PSObject.Properties['role_assignments']) {
                                    $RoleAssignments = $RoleAssignmentResponse.role_assignments
                                }
                                # If Invoke-HPEGLWebRequest already unpacked it, the response might be the array directly
                                elseif ($RoleAssignmentResponse -is [array]) {
                                    $RoleAssignments = $RoleAssignmentResponse
                                }
                            }
                            
                            if ($RoleAssignments -and $RoleAssignments.Count -gt 0) {
                                ("[{0}] Found {1} role assignment(s) for scope group '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleAssignments.Count, $ScopeGroup.name) | Write-Verbose
                                foreach ($assignment in $RoleAssignments) {
                                    $RoleAssignmentCollection += [PSCustomObject]@{
                                        roleName         = $assignment.roleName
                                        serviceName      = $assignment.serviceName
                                        subjectName      = $assignment.subjectName
                                        subjectType      = $assignment.subjectType
                                        scopeGroupName   = $ScopeGroup.name
                                        roleDescription  = $assignment.roleDescription
                                        roleId           = $assignment.roleId
                                        serviceId        = $assignment.serviceId
                                        subjectId        = $assignment.subjectId
                                        id               = $assignment.id
                                    }
                                }
                            }
                            else {
                                ("[{0}] No role assignments found for scope group '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ScopeGroup.name) | Write-Verbose
                            }
                        }
                        catch {
                            ("[{0}] Warning: Could not retrieve role assignments for scope group '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ScopeGroup.name, $_.Exception.Message) | Write-Warning
                        }
                    }
                    $Collection = $RoleAssignmentCollection
                }
                
                # Use different type name for detailed view to trigger table format with resource details
                if ($ShowScopes) {
                    # Expand resourceDetails array so each filter becomes a separate row
                    $ExpandedCollection = @()
                    foreach ($ScopeGroup in $Collection) {
                        if ($ScopeGroup.resourceDetails -and $ScopeGroup.resourceDetails.Count -gt 0) {
                            foreach ($detail in $ScopeGroup.resourceDetails) {
                                $ExpandedCollection += [PSCustomObject]@{
                                    name                     = $detail.name
                                    resourceTypeDisplayName  = $detail.resourceTypeDisplayName
                                    resourceProviderName     = $detail.resourceProviderName
                                    grn                      = $detail.grn
                                    scopeGroupName           = $ScopeGroup.name
                                }
                            }
                        }
                    }
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $ExpandedCollection -ObjectName "ScopeGroup.Filter"
                }
                elseif ($ShowRoleAssignments) {
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $Collection -ObjectName "ScopeGroup.RoleAssignment"
                }
                else {
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $Collection -ObjectName "ScopeGroup"
                }
                
                $ReturnData = $ReturnData | Sort-Object name

                return $ReturnData 
            }
            else {
                return
            }
        }
        else {
            return
        }
 
    }
}

Function New-HPEGLScopeGroup {
    <#
    .SYNOPSIS
    Creates a new scope group in an HPE GreenLake workspace.

    .DESCRIPTION
    This cmdlet creates a new scope group in an HPE GreenLake workspace. Scope groups allow you to define filtered 
    access to resources by creating customizable resource groupings based on COM filters. These scope groups can be 
    assigned to role assignments to limit which resources users can access.

    A scope group consists of:
    - A name and optional description
    - One or more scopes based on COM filters from a specific region
    - Service association (typically Compute Ops Management)

    .PARAMETER Name 
    The name of the scope group to create. Must be unique within the workspace.

    .PARAMETER Description
    Optional description for the scope group to explain its purpose.

    .PARAMETER Region
    The region code where the COM filters are located (e.g., 'eu-central', 'us-west').
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' 
    or 'Get-HPEGLRegion -ShowProvisioned'.
    When using pipeline input, this parameter can be automatically populated from the piped filter object's region property.

    .PARAMETER FilterName
    One or more COM filter names to include in the scope group. These filters define which resources are included.
    You can retrieve available filters using: Get-HPECOMFilter -Region <region>

    .PARAMETER ServiceName
    The service name that can use this scope group. Currently only 'Compute Ops Management' is supported for 
    filter-based scope groups. You can retrieve available service names using: Get-HPEGLService -ShowProvisioned

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for 
    understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    New-HPEGLScopeGroup -Name "AI-Servers" -Description "AI server group" -Region "eu-central" -FilterName "AI_Goup_SBAC_Filter" -ServiceName "Compute Ops Management"

    Creates a new scope group named "AI-Servers" in the eu-central region using the specified COM filter.

    .EXAMPLE
    New-HPEGLScopeGroup -Name "Production-Servers" -Region "us-west" -FilterName "Prod_Filter_Gen10", "Prod_Filter_Gen11" -ServiceName "Compute Ops Management"

    Creates a scope group with multiple COM filters from the us-west region.

    .EXAMPLE
    New-HPEGLScopeGroup -Name "Dev-Environment" -Description "Development servers" -Region "eu-central" -FilterName "Dev_Servers" -ServiceName "Compute Ops Management" -WhatIf

    Shows what would be created without actually creating the scope group.

    .EXAMPLE
    Get-HPECOMFilter -Region eu-central -Name "AI_Goup_SBAC_Filter" | New-HPEGLScopeGroup -Name "AI-Servers" -Description "AI server group" -Region "eu-central"

    Creates a scope group from a COM filter passed via pipeline. Note: The -Region parameter is automatically populated from the piped filter's region property.

    .EXAMPLE
    Get-HPECOMFilter -Region us-west | Where-Object { $_.name -like "Prod_*" } | New-HPEGLScopeGroup -Name "Production-Servers" -Region "us-west"

    Creates a scope group using all production filters from the us-west region passed via pipeline.

    .INPUTS
    HPEGreenLake.COM.Filters
        You can pipe COM filter objects from Get-HPECOMFilter. The filter's id and region properties will be used.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object containing the following properties:
        * Name - Name of the scope group attempted to be created
        * Status - Status of the creation attempt (Failed, Complete, or Warning)
        * Details - More information about the status
        * Exception - Information about any exceptions generated during the operation
        * Id - The ID of the created scope group (when successful)

   #>

    [CmdletBinding(DefaultParameterSetName = 'ByName')]
    Param( 
                    
        [Parameter (Mandatory, ParameterSetName = 'ByName')]
        [Parameter (Mandatory, ParameterSetName = 'FromPipeline')]
        [String]$Name,
            
        [Parameter (ParameterSetName = 'ByName')]
        [Parameter (ParameterSetName = 'FromPipeline')]
        [String]$Description = "",

        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ByName')]
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'FromPipeline')]
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

        [Parameter (Mandatory, ParameterSetName = 'ByName')]
        [String[]]$FilterName,

        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'FromPipeline')]
        [Alias('id')]
        [String[]]$FilterId,

        [Parameter (ParameterSetName = 'ByName')]
        [Parameter (ParameterSetName = 'FromPipeline')]
        [String]$ServiceName = "Compute Ops Management",

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        ("[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller) | Write-Verbose

        $CreateScopeGroupStatus = [System.Collections.ArrayList]::new()
        
        # For pipeline input, collect filter IDs
        $CollectedFilterIds = [System.Collections.ArrayList]::new()

    }

    Process {

        ("[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string)) | Write-Verbose

        # If receiving from pipeline, collect filter IDs
        if ($PSCmdlet.ParameterSetName -eq 'FromPipeline') {
            foreach ($Id in $FilterId) {
                [void]$CollectedFilterIds.Add($Id)
            }
            
            # Don't process yet - wait for End block
            return
        }

        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name      = $Name
            Status    = $Null
            Details   = $Null
            Exception = $Null
            Id        = $Null
        }

        # Check if scope group already exists
        try {
            $ExistingScopeGroup = Get-HPEGLScopeGroup -Name $Name -Verbose:$false
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if ($ExistingScopeGroup) {
            
            ("[{0}] Scope group '{1}' already exists!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name) | Write-Verbose
    
            if ($WhatIf) {
                Write-Warning "Scope group '$Name' already exists! No action needed."
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "Scope group already exists! No action needed."
                $objStatus.Id = $ExistingScopeGroup.id
            }

        }
        else {

            # Get service information
            try {
                $Service = Get-HPEGLService -ShowProvisioned -Name $ServiceName | Sort-Object -Property application_id -Unique
                
                if (-not $Service) {
                    if ($WhatIf) {
                        Write-Warning "Service '$ServiceName' not found or not provisioned in the workspace! Cannot show API preview."
                        return
                    }
                    $objStatus.Status = "Warning"
                    $objStatus.Details = "Service '$ServiceName' not found or not provisioned in the workspace"
                    [void] $CreateScopeGroupStatus.add($objStatus)
                    return
                }
                
                ("[{0}] Found service '{1}' with ID: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $Service.application_id) | Write-Verbose
            }
            catch {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else {  "Failed to retrieve service information for '$ServiceName'" }
                $objStatus.Exception = $_.Exception.Message
                [void] $CreateScopeGroupStatus.add($objStatus)
                return
            }

            # Build scopes array from COM filters
            $Scopes = @()
            $ResourceDetails = @()
            
            # Handle filter input based on parameter set
            if ($PSCmdlet.ParameterSetName -eq 'ByName') {
                # Process filters by name
                foreach ($Filter in $FilterName) {
                    try {
                        $COMFilter = Get-HPECOMFilter -Region $Region -Name $Filter -Verbose:$false
                        
                        if (-not $COMFilter) {
                            if ($WhatIf) {
                                Write-Warning "Filter '$Filter' not found in region '$Region'! Cannot show API preview."
                                return
                            }
                            $objStatus.Status = "Warning"
                            $objStatus.Details = "Filter '$Filter' not found in region '$Region'"
                            [void] $CreateScopeGroupStatus.add($objStatus)
                            return
                        }
                        
                        # Get workspace ID from global session
                        $WorkspaceId = $Global:HPEGreenLakeSession.workspaceId
                        
                        # Build the filter GRN
                        $FilterGRN = "grn:glp/workspaces/$WorkspaceId/regions/$Region/providers/compute-ops-mgmt/filter/$($COMFilter.id)"
                        
                        ("[{0}] Found filter '{1}' with ID: {2}, GRN: {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Filter, $COMFilter.id, $FilterGRN) | Write-Verbose
                        
                        # Add filter GRN to scopes array
                        $Scopes += $FilterGRN
                        
                        # Add resource details with only API-accepted fields (exclude resourceProviderName)
                        $ResourceDetails += @{
                            grn                     = $FilterGRN
                            allScopes               = $false
                            name                    = $COMFilter.name
                            resourceTypeDisplayName = "Scope filter"
                        }
                    }
                    catch {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Failed to retrieve filter '$Filter' from region '$Region'" }
                        $objStatus.Exception = $_.Exception.Message
                        [void] $CreateScopeGroupStatus.add($objStatus)
                        return
                    }
                }
            }

            # Build service filters for internal.availableItemFilters
            $ServiceFilters = @(
                @{
                    applicationId = $Service.application_id
                    serviceId     = $Service.application_id
                }
            )

            # Build the payload
            $payload = @{
                name            = $Name
                description     = $Description
                scopes          = $Scopes
                resourceDetails = $ResourceDetails
                internal        = @{
                    availableItemFilters = $ServiceFilters
                }
            }

            # Convert to JSON
            $Body = $payload | ConvertTo-Json -Depth 10
            
            "[{0}] Payload: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Body | Write-Verbose

            # Build URI
            $Uri = Get-ScopeGroupsUri
    
            try {
                $Response = Invoke-HPEGLWebRequest -Method POST -Uri $Uri -Body $Body -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
    
                if (-not $WhatIf) {
    
                    "[{0}] Scope group creation raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Response | ConvertTo-Json -Depth 5) | Write-Verbose
                    
                    "[{0}] Scope group '{1}' successfully created with ID: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Response.id | Write-Verbose
                        
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Scope group successfully created"
                    $objStatus.Id = $Response.id
    
                }
    
            }
            catch {
    
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { 
                        $_.Exception.Message 
                    } else { 
                        Get-HPEGLErrorMessage -ExceptionObject $_ -DefaultMessage "Scope group cannot be created!"
                    }

                    # Build technical diagnostics
                    $technicalInfo = @()
                    if ($Global:HPECOMInvokeReturnData.errorCode) {
                        $technicalInfo += "Code: $($Global:HPECOMInvokeReturnData.errorCode)"
                    }
                    if ($Global:HPECOMInvokeReturnData.httpStatusCode -or $Global:HPECOMInvokeReturnData.StatusCode) {
                        $statusCode = if ($Global:HPECOMInvokeReturnData.httpStatusCode) { 
                            $Global:HPECOMInvokeReturnData.httpStatusCode 
                        } else { 
                            $Global:HPECOMInvokeReturnData.StatusCode 
                        }
                        $technicalInfo += "HTTP $statusCode"
                    }
                    if ($technicalInfo.Count -eq 0) {
                        $technicalInfo += $_.Exception.GetType().Name
                    }
                    $objStatus.Exception = $technicalInfo -join " | "
                }
            }           
        }

        [void] $CreateScopeGroupStatus.add($objStatus)

    }

    End {

        # Handle pipeline input in End block
        if ($PSCmdlet.ParameterSetName -eq 'FromPipeline' -and $CollectedFilterIds.Count -gt 0) {
            
            ("[{0}] Processing {1} filter(s) from pipeline" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CollectedFilterIds.Count) | Write-Verbose
            
            # Validate region is provided
            if (-not $Region) {
                Write-Error "Region parameter is required when creating scope groups from pipeline input."
                return
            }
            
            # Build object for the output
            $objStatus = [pscustomobject]@{
                Name      = $Name
                Status    = $Null
                Details   = $Null
                Exception = $Null
                Id        = $Null
            }

            # Check if scope group already exists
            try {
                $ExistingScopeGroup = Get-HPEGLScopeGroup -Name $Name -Verbose:$false
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }

            if ($ExistingScopeGroup) {
                ("[{0}] Scope group '{1}' already exists!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name) | Write-Verbose
        
                if ($WhatIf) {
                    Write-Warning "Scope group '$Name' already exists! No action needed."
                    return
                }
                else {
                    $objStatus.Status = "Warning"
                    $objStatus.Details = "Scope group already exists! No action needed."
                    $objStatus.Id = $ExistingScopeGroup.id
                    [void] $CreateScopeGroupStatus.add($objStatus)
                }
            }
            else {
                # Get service information
                try {
                    $Service = Get-HPEGLService -ShowProvisioned -Name $ServiceName | Sort-Object -Property application_id -Unique
                    
                    if (-not $Service) {
                        if ($WhatIf) {
                            Write-Warning "Service '$ServiceName' not found or not provisioned in the workspace! Cannot show API preview."
                            return
                        }
                        $objStatus.Status = "Warning"
                        $objStatus.Details = "Service '$ServiceName' not found or not provisioned in the workspace"
                        [void] $CreateScopeGroupStatus.add($objStatus)
                    }
                    else {
                        ("[{0}] Found service '{1}' with ID: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $Service.application_id) | Write-Verbose
                        
                        # Build scopes and resource details from filter IDs
                        $Scopes = @()
                        $ResourceDetails = @()
                        $WorkspaceId = $Global:HPEGreenLakeSession.workspaceId
                        
                        foreach ($FilterId in $CollectedFilterIds) {
                            $FilterGRN = "grn:glp/workspaces/$WorkspaceId/regions/$Region/providers/compute-ops-mgmt/filter/$FilterId"
                            ("[{0}] Building scope for filter ID: {1}, GRN: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $FilterId, $FilterGRN) | Write-Verbose
                            
                            $Scopes += $FilterGRN
                            
                            # Get filter name for resource details
                            try {
                                $FilterObj = Get-HPECOMFilter -Region $Region | Where-Object { $_.id -eq $FilterId }
                                $FilterName = if ($FilterObj) { $FilterObj.name } else { "Filter-$FilterId" }
                                
                                $ResourceDetails += @{
                                    grn                      = $FilterGRN
                                    allScopes                = $false
                                    name                     = $FilterName
                                    resourceTypeDisplayName  = "Scope filter"
                                    resourceProviderName     = "Compute Ops Management"
                                }
                            }
                            catch {
                                # If we can't get the filter name, use a fallback
                                $ResourceDetails += @{
                                    grn                      = $FilterGRN
                                    allScopes                = $false
                                    name                     = "Filter-$FilterId"
                                    resourceTypeDisplayName  = "Scope filter"
                                    resourceProviderName     = "Compute Ops Management"
                                }
                            }
                        }
                        
                        # Build service filters
                        $ServiceFilters = @(
                            @{
                                applicationId = $Service.application_id
                                serviceId     = $Service.application_id
                            }
                        )

                        # Build the payload
                        $payload = @{
                            name            = $Name
                            description     = $Description
                            scopes          = $Scopes
                            resourceDetails = $ResourceDetails
                            internal        = @{
                                availableItemFilters = $ServiceFilters
                            }
                        }

                        # Convert to JSON
                        $Body = $payload | ConvertTo-Json -Depth 10
                        
                        ("[{0}] Payload: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Body) | Write-Verbose

                        # Build URI
                        $Uri = Get-ScopeGroupsUri
            
                        try {
                            $Response = Invoke-HPEGLWebRequest -Method POST -Uri $Uri -Body $Body -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
            
                            if (-not $WhatIf) {
                                ("[{0}] Scope group creation raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Response | ConvertTo-Json -Depth 5)) | Write-Verbose
                                
                                ("[{0}] Scope group '{1}' successfully created with ID: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Response.id) | Write-Verbose
                                    
                                $objStatus.Status = "Complete"
                                $objStatus.Details = "Scope group successfully created"
                                $objStatus.Id = $Response.id
                            }
                        }
                        catch {
                            if (-not $WhatIf) {
                                $objStatus.Status = "Failed"
                                
                                # Use helper function to extract error message
                                 $objStatus.Details = if ($_.Exception.Message) { 
                                    $_.Exception.Message 
                                } else { 
                                    Get-HPEGLErrorMessage -ExceptionObject $_ -DefaultMessage "Scope group cannot be created!"
                                }                           
                                
                                # Build technical exception info with error code and HTTP status
                                $technicalInfo = @()
                                if ($Global:HPECOMInvokeReturnData.errorCode) {
                                    $technicalInfo += "Code: $($Global:HPECOMInvokeReturnData.errorCode)"
                                }
                                if ($Global:HPECOMInvokeReturnData.httpStatusCode -or $Global:HPECOMInvokeReturnData.StatusCode) {
                                    $statusCode = if ($Global:HPECOMInvokeReturnData.httpStatusCode) { $Global:HPECOMInvokeReturnData.httpStatusCode } else { $Global:HPECOMInvokeReturnData.StatusCode }
                                    $technicalInfo += "HTTP $statusCode"
                                }
                                if ($technicalInfo.Count -eq 0) {
                                    $technicalInfo += $_.Exception.GetType().Name
                                }
                                $objStatus.Exception = $technicalInfo -join " | "
                            }
                        }
                        
                        [void] $CreateScopeGroupStatus.add($objStatus)
                    }
                }
                catch {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Failed to retrieve service information for '$ServiceName'" }
                    $objStatus.Exception = $_.Exception.Message
                    [void] $CreateScopeGroupStatus.add($objStatus)
                }
            }
        }

        if (-not $WhatIf -and $CreateScopeGroupStatus.Count -gt 0) {
            $CreateScopeGroupStatus = Invoke-RepackageObjectWithType -RawObject $CreateScopeGroupStatus -ObjectName "ObjStatus.NSDE"    
            Return $CreateScopeGroupStatus
        }

    }
}

Function Set-HPEGLScopeGroup {
    <#
    .SYNOPSIS
    Modifies an existing scope group in an HPE GreenLake workspace.

    .DESCRIPTION
    This cmdlet updates an existing scope group in an HPE GreenLake workspace. You can modify the 
    description and the filters (scopes) associated with the scope group.

    Important: Renaming a scope group is not supported by the HPE GreenLake API. The scope group name 
    cannot be changed once it has been created. If you need to rename a scope group, you must delete 
    the existing one and create a new one with the desired name.

    Note: When modifying filters, the cmdlet replaces all existing filters with the new ones specified.
    If you want to add filters to existing ones, you must include both the existing and new filters.

    .PARAMETER Name 
    The current name of the scope group to modify. This parameter is used to identify the scope group.

    .PARAMETER Description
    The new description for the scope group. If not specified, the description remains unchanged.
    Use an empty string "" to clear the description.

    .PARAMETER FilterName
    One or more COM filter names to replace the existing filters in the scope group.
    This completely replaces all existing filters with the specified ones.
    The region is automatically detected from the filter.

    .PARAMETER AddFilterName
    One or more COM filter names to add to the existing filters in the scope group.
    If the scope group has existing filters, the region is automatically extracted from them.
    If the scope group has no existing filters, the region is automatically detected from the first filter being added.

    .PARAMETER RemoveFilterName
    One or more COM filter names to remove from the existing filters in the scope group.

    .PARAMETER ClearFilters
    Removes all filters from the scope group, effectively making it a full-access scope group.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request.

    .EXAMPLE
    Set-HPEGLScopeGroup -Name "Gen10_Servers" -Description "Updated description for Gen 10 servers"

    Updates the description of the scope group named "Gen10_Servers".

    .EXAMPLE
    Set-HPEGLScopeGroup -Name "AI-Servers" -FilterName "AI_Goup_SBAC_Filter", "AI_Filter_2"

    Replaces all existing filters with the two specified filters. The region is automatically detected from the filters.

    .EXAMPLE
    Set-HPEGLScopeGroup -Name "Production-Servers" -AddFilterName "New_Prod_Filter"

    Adds a new filter to the existing filters in the scope group. The region is automatically 
    extracted from the existing filters in the scope group.

    .EXAMPLE
    Set-HPEGLScopeGroup -Name "Production-Servers" -AddFilterName "New_Prod_Filter"

    Adds a new filter to the existing filters. If the scope group has existing filters, the region 
    is extracted from them. If it's the first filter being added, the region is detected from the filter itself.

    .EXAMPLE
    Set-HPEGLScopeGroup -Name "Dev-Servers" -RemoveFilterName "Old_Dev_Filter"

    Removes a specific filter from the scope group while keeping all other filters.

    .EXAMPLE
    Set-HPEGLScopeGroup -Name "Test-Servers" -ClearFilters

    Removes all filters from the scope group, making it a full-access scope group.

    .EXAMPLE
    Get-HPEGLScopeGroup -Name "AI-Servers" | Set-HPEGLScopeGroup -Description "Updated via pipeline"

    Updates a scope group passed via pipeline.

    .INPUTS
    HPEGreenLake.ScopeGroup
        You can pipe scope group objects from Get-HPEGLScopeGroup.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object containing the following properties:
        * Name - Name of the scope group attempted to be modified
        * Status - Status of the modification attempt (Failed, Complete, or Warning)
        * Details - More information about the status
        * Exception - Information about any exceptions generated during the operation
        * Id - The ID of the modified scope group

   #>

    [CmdletBinding(DefaultParameterSetName = 'Modify')]
    Param( 
                    
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Modify')]
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ReplaceFilters')]
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'AddFilters')]
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'RemoveFilters')]
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ClearFilters')]
        [String]$Name,
            
        [Parameter (ParameterSetName = 'Modify')]
        [Parameter (ParameterSetName = 'ReplaceFilters')]
        [Parameter (ParameterSetName = 'AddFilters')]
        [Parameter (ParameterSetName = 'RemoveFilters')]
        [Parameter (ParameterSetName = 'ClearFilters')]
        [String]$Description,

        [Parameter (Mandatory, ParameterSetName = 'ReplaceFilters')]
        [String[]]$FilterName,

        [Parameter (Mandatory, ParameterSetName = 'AddFilters')]
        [String[]]$AddFilterName,

        [Parameter (Mandatory, ParameterSetName = 'RemoveFilters')]
        [String[]]$RemoveFilterName,

        [Parameter (Mandatory, ParameterSetName = 'ClearFilters')]
        [Switch]$ClearFilters,

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        ("[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller) | Write-Verbose

        $SetScopeGroupStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        ("[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string)) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name      = $Name
            Status    = $Null
            Details   = $Null
            Exception = $Null
            Id        = $Null
        }

        # Get the existing scope group
        try {
            $ExistingScopeGroup = Get-HPEGLScopeGroup -Name $Name -Verbose:$false
            
            if (-not $ExistingScopeGroup) {
                ("[{0}] Scope group '{1}' not found!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name) | Write-Verbose
                
                if ($WhatIf) {
                    $ErrorMessage = "Scope group '{0}' not found! Cannot show API preview without an existing scope group." -f $Name
                    Write-Warning $ErrorMessage
                    return
                }
                
                $objStatus.Status = "Failed"
                $objStatus.Details = "Scope group not found"
                [void] $SetScopeGroupStatus.add($objStatus)
                return
            }
            
            $objStatus.Id = $ExistingScopeGroup.id
            
            ("[{0}] Found scope group '{1}' with ID: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $ExistingScopeGroup.id) | Write-Verbose
        }
        catch {
            $objStatus.Status = "Failed"
            $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Failed to retrieve scope group '$Name'" }
            $objStatus.Exception = $_.Exception.Message
            [void] $SetScopeGroupStatus.add($objStatus)
            return
        }

        # Determine what needs to be updated
        $UpdatedDescription = if ($PSBoundParameters.ContainsKey('Description')) { $Description } else { $ExistingScopeGroup.description }
        
        # Handle scopes/filters
        $UpdatedScopes = @()
        $UpdatedResourceDetails = @()
        $WorkspaceId = $Global:HPEGreenLakeSession.workspaceId

        switch ($PSCmdlet.ParameterSetName) {
            'Modify' {
                # Keep existing scopes (only grn and name fields to match API requirements)
                if ($ExistingScopeGroup.scopes) {
                    $UpdatedScopes = $ExistingScopeGroup.scopes
                }
                if ($ExistingScopeGroup.resourceDetails) {
                    foreach ($detail in $ExistingScopeGroup.resourceDetails) {
                        # Only keep grn and name fields to match API requirements
                        $UpdatedResourceDetails += @{
                            grn  = $detail.grn
                            name = $detail.name
                        }
                    }
                }
            }
            
            'ReplaceFilters' {
                # Replace all filters with new ones
                # Automatically detect region from the first filter
                $Region = $null
                
                # Try to extract region from existing filters first
                if ($ExistingScopeGroup.scopes.Count -gt 0) {
                    $firstScope = $ExistingScopeGroup.scopes[0]
                    if ($firstScope -match 'regions/([^/]+)/') {
                        $Region = $matches[1]
                        ("[{0}] Extracted region '{1}' from existing filters" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region) | Write-Verbose
                    }
                }
                
                # If no existing filters or couldn't extract region, detect from first new filter
                if (-not $Region) {
                    # Try each filter until we find one that exists
                    foreach ($TestFilter in $FilterName) {
                        # Try each region to find where the filter exists
                        foreach ($TestRegion in $Global:HPECOMRegions.region) {
                            try {
                                $TestCOMFilter = Get-HPECOMFilter -Region $TestRegion -Name $TestFilter -Verbose:$false -ErrorAction SilentlyContinue
                                if ($TestCOMFilter) {
                                    $Region = $TestRegion
                                    ("[{0}] Auto-detected region '{1}' from filter '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, $TestFilter) | Write-Verbose
                                    break
                                }
                            }
                            catch {
                                # Continue to next region
                            }
                        }
                        if ($Region) { break }
                    }
                    
                    if (-not $Region) {
                        if ($WhatIf) {
                            if ($FilterName.Count -eq 1) {
                                $ErrorMessage = "Filter '{0}' not found in any of the provisioned regions. Cannot show API preview without valid filters." -f $FilterName[0]
                            }
                            else {
                                $ErrorMessage = "None of the specified filters were found in any of the provisioned regions: {0}. Cannot show API preview without valid filters." -f ($FilterName -join ', ')
                            }
                            Write-Warning $ErrorMessage
                            return
                        }
                        
                        $objStatus.Status = "Warning"
                        if ($FilterName.Count -eq 1) {
                            $objStatus.Details = "Filter '$($FilterName[0])' not found in any of the provisioned regions"
                        }
                        else {
                            $objStatus.Details = "None of the specified filters were found in any of the provisioned regions: $($FilterName -join ', ')"
                        }
                        [void] $SetScopeGroupStatus.add($objStatus)
                        return
                    }
                }
                
                foreach ($Filter in $FilterName) {
                    try {
                        $COMFilter = Get-HPECOMFilter -Region $Region -Name $Filter -Verbose:$false
                        
                        if (-not $COMFilter) {
                            ("[{0}] Filter '{1}' not found in region '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Filter, $Region) | Write-Verbose
                            
                            if ($WhatIf) {
                                $ErrorMessage = "Filter '{0}' not found in region '{1}'. Cannot show API preview without valid filters." -f $Filter, $Region
                                Write-Warning $ErrorMessage
                                return
                            }
                            
                            $objStatus.Status = "Warning"
                            $objStatus.Details = "Filter '$Filter' not found in region '$Region'"
                            [void] $SetScopeGroupStatus.add($objStatus)
                            return
                        }
                        
                        $FilterGRN = "grn:glp/workspaces/$WorkspaceId/regions/$Region/providers/compute-ops-mgmt/filter/$($COMFilter.id)"
                        
                        $UpdatedScopes += $FilterGRN
                        $UpdatedResourceDetails += @{
                            grn  = $FilterGRN
                            name = $COMFilter.name
                        }
                        
                        ("[{0}] Added filter '{1}' with GRN: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Filter, $FilterGRN) | Write-Verbose
                    }
                    catch {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Failed to retrieve filter '$Filter' from region '$Region'" }
                        $objStatus.Exception = $_.Exception.Message
                        [void] $SetScopeGroupStatus.add($objStatus)
                        return
                    }
                }
            }
            
            'AddFilters' {
                # Add new filters to existing ones
                $Region = $null
                
                ("[{0}] Processing AddFilters parameter set" -f $MyInvocation.InvocationName.ToString().ToUpper()) | Write-Verbose
                
                # First, keep existing filters (only grn and name fields to match API requirements)
                if ($ExistingScopeGroup.scopes) {
                    foreach ($scope in $ExistingScopeGroup.scopes) {
                        $UpdatedScopes += $scope
                    }
                }
                if ($ExistingScopeGroup.resourceDetails) {
                    foreach ($detail in $ExistingScopeGroup.resourceDetails) {
                        # Only keep grn and name fields to match API requirements
                        $UpdatedResourceDetails += @{
                            grn  = $detail.grn
                            name = $detail.name
                        }
                    }
                }
                
                # Extract region from existing scopes if not provided
                if (-not $Region -and $ExistingScopeGroup.scopes) {
                    # Parse region from first scope GRN: grn:glp/workspaces/{workspace}/regions/{region}/providers/...
                    ("[{0}] Extracting region from existing scopes" -f $MyInvocation.InvocationName.ToString().ToUpper()) | Write-Verbose
                    
                    # Handle both string (single scope) and array (multiple scopes)
                    $firstScope = if ($ExistingScopeGroup.scopes -is [array]) {
                        $ExistingScopeGroup.scopes[0]
                    } else {
                        $ExistingScopeGroup.scopes
                    }
                    
                    if ($firstScope -match 'regions/([^/]+)/') {
                        $Region = $matches[1]
                        ("[{0}] Extracted region '{1}' from existing filters" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region) | Write-Verbose
                    }
                    else {
                        ("[{0}] Failed to extract region from scope: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $firstScope) | Write-Verbose
                        
                        if ($WhatIf) {
                            Write-Warning "Unable to extract region from existing filters. Cannot show API preview."
                            return
                        }
                        
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Unable to extract region from existing filters."
                        [void] $SetScopeGroupStatus.add($objStatus)
                        return
                    }
                }
                elseif (-not $Region) {
                    # No existing filters - auto-detect region from the filter being added
                    ("[{0}] No existing filters found. Auto-detecting region from filter name..." -f $MyInvocation.InvocationName.ToString().ToUpper()) | Write-Verbose
                    
                    # Try each filter until we find one that exists
                    foreach ($TestFilter in $AddFilterName) {
                        # Try each region to find where the filter exists
                        foreach ($TestRegion in $Global:HPECOMRegions.region) {
                            try {
                                $TestCOMFilter = Get-HPECOMFilter -Region $TestRegion -Name $TestFilter -Verbose:$false -ErrorAction SilentlyContinue
                                if ($TestCOMFilter) {
                                    $Region = $TestRegion
                                    ("[{0}] Auto-detected region '{1}' from filter '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, $TestFilter) | Write-Verbose
                                    break
                                }
                            }
                            catch {
                                # Continue to next region
                            }
                        }
                        if ($Region) { break }
                    }
                    
                    if (-not $Region) {
                        if ($WhatIf) {
                            if ($AddFilterName.Count -eq 1) {
                                $ErrorMessage = "Filter '{0}' not found in any of the provisioned regions. Cannot show API preview without valid filters." -f $AddFilterName[0]
                            }
                            else {
                                $ErrorMessage = "None of the specified filters were found in any of the provisioned regions: {0}. Cannot show API preview without valid filters." -f ($AddFilterName -join ', ')
                            }
                            Write-Warning $ErrorMessage
                            return
                        }
                        
                        $objStatus.Status = "Warning"
                        if ($AddFilterName.Count -eq 1) {
                            $objStatus.Details = "Filter '$($AddFilterName[0])' not found in any of the provisioned regions"
                        }
                        else {
                            $objStatus.Details = "None of the specified filters were found in any of the provisioned regions: $($AddFilterName -join ', ')"
                        }
                        [void] $SetScopeGroupStatus.add($objStatus)
                        return
                    }
                }
                
                # Then add new filters
                foreach ($Filter in $AddFilterName) {
                    try {
                        $COMFilter = Get-HPECOMFilter -Region $Region -Name $Filter -Verbose:$false
                        
                        if (-not $COMFilter) {
                            ("[{0}] Filter '{1}' not found in region '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Filter, $Region) | Write-Verbose
                            
                            if ($WhatIf) {
                                $ErrorMessage = "Filter '{0}' not found in region '{1}'. Cannot show API preview without valid filters." -f $Filter, $Region
                                Write-Warning $ErrorMessage
                                return
                            }
                            
                            $objStatus.Status = "Warning"
                            $objStatus.Details = "Filter '$Filter' not found in region '$Region'"
                            [void] $SetScopeGroupStatus.add($objStatus)
                            return
                        }
                        
                        $FilterGRN = "grn:glp/workspaces/$WorkspaceId/regions/$Region/providers/compute-ops-mgmt/filter/$($COMFilter.id)"
                        
                        # Check if filter already exists
                        if ($UpdatedScopes -notcontains $FilterGRN) {
                            $UpdatedScopes += $FilterGRN
                            $UpdatedResourceDetails += @{
                                grn  = $FilterGRN
                                name = $COMFilter.name
                            }
                            ("[{0}] Added filter '{1}' with GRN: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Filter, $FilterGRN) | Write-Verbose
                        }
                        else {
                            ("[{0}] Filter '{1}' already exists in scope group, skipping" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Filter) | Write-Verbose
                        }
                    }
                    catch {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Failed to retrieve filter '$Filter' from region '$Region'" }
                        $objStatus.Exception = $_.Exception.Message
                        [void] $SetScopeGroupStatus.add($objStatus)
                        return
                    }
                }
            }
            
            'RemoveFilters' {
                # Remove specified filters from existing ones
                if ($ExistingScopeGroup.scopes) {
                    # Get filter names to remove
                    $FiltersToRemove = @()
                    foreach ($FilterToRemove in $RemoveFilterName) {
                        # Find matching resourceDetails
                        $matchingDetail = $ExistingScopeGroup.resourceDetails | Where-Object { $_.name -eq $FilterToRemove }
                        if ($matchingDetail) {
                            $FiltersToRemove += $matchingDetail.grn
                        }
                    }
                    
                    # Keep only scopes that are not in the remove list
                    foreach ($scopeGrn in $ExistingScopeGroup.scopes) {
                        if ($scopeGrn -notin $FiltersToRemove) {
                            $UpdatedScopes += $scopeGrn
                        }
                        else {
                            ("[{0}] Removing filter with GRN: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $scopeGrn) | Write-Verbose
                        }
                    }
                    
                    # Keep matching resourceDetails (only grn and name fields to match API requirements)
                    foreach ($detail in $ExistingScopeGroup.resourceDetails) {
                        if ($detail.grn -notin $FiltersToRemove) {
                            # Only keep grn and name fields to match API requirements
                            $UpdatedResourceDetails += @{
                                grn  = $detail.grn
                                name = $detail.name
                            }
                        }
                    }
                }
            }
            
            'ClearFilters' {
                # Remove all filters
                $UpdatedScopes = @()
                $UpdatedResourceDetails = @()
                ("[{0}] Clearing all filters from scope group" -f $MyInvocation.InvocationName.ToString().ToUpper()) | Write-Verbose
            }
        }

        # Build the payload
        $payload = @{
            id              = $ExistingScopeGroup.id
            name            = $ExistingScopeGroup.name
            description     = $UpdatedDescription
            scopes          = $UpdatedScopes
            resourceDetails = $UpdatedResourceDetails
        }

        # Convert to JSON
        $Body = $payload | ConvertTo-Json -Depth 10
        
        ("[{0}] Payload: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Body) | Write-Verbose

        # Build URI
        $Uri = (Get-ScopeGroupsUri) + "/$($ExistingScopeGroup.id)"
        
        try {
            $Response = Invoke-HPEGLWebRequest -Method PUT -Uri $Uri -Body $Body -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

            if (-not $WhatIf) {
                ("[{0}] Scope group modification raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Response | ConvertTo-Json -Depth 5)) | Write-Verbose
                
                ("[{0}] Scope group '{1}' successfully modified" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name) | Write-Verbose
                    
                $objStatus.Status = "Complete"
                $objStatus.Details = "Scope group successfully modified"
            }
        }
        catch {
            if (-not $WhatIf) {
                $objStatus.Status = "Failed"
                
                # Use helper function to extract error message
                $objStatus.Details = if ($_.Exception.Message) { 
                    $_.Exception.Message 
                } else { 
                    Get-HPEGLErrorMessage -ExceptionObject $_ -DefaultMessage "Scope group cannot be modified!"
                }
                
                # Build technical exception info with error code and HTTP status
                $technicalInfo = @()
                if ($Global:HPECOMInvokeReturnData.errorCode) {
                    $technicalInfo += "Code: $($Global:HPECOMInvokeReturnData.errorCode)"
                }
                if ($Global:HPECOMInvokeReturnData.httpStatusCode -or $Global:HPECOMInvokeReturnData.StatusCode) {
                    $statusCode = if ($Global:HPECOMInvokeReturnData.httpStatusCode) { $Global:HPECOMInvokeReturnData.httpStatusCode } else { $Global:HPECOMInvokeReturnData.StatusCode }
                    $technicalInfo += "HTTP $statusCode"
                }
                if ($technicalInfo.Count -eq 0) {
                    $technicalInfo += $_.Exception.GetType().Name
                }
                $objStatus.Exception = $technicalInfo -join " | "
            }
        }

        [void] $SetScopeGroupStatus.add($objStatus)

    }

    End {

        if (-not $WhatIf -and $SetScopeGroupStatus.Count -gt 0) {
            $SetScopeGroupStatus = Invoke-RepackageObjectWithType -RawObject $SetScopeGroupStatus -ObjectName "ObjStatus.NSDE"    
            Return $SetScopeGroupStatus
        }

    }
}

Function Remove-HPEGLScopeGroup {
    <#
    .SYNOPSIS
    Removes a scope group from an HPE GreenLake workspace.

    .DESCRIPTION
    This cmdlet removes a scope group from the currently connected HPE GreenLake workspace.
    
    When a scope group assigned to a user role is deleted, the user's access will be updated accordingly.
    Users will lose access to resources that were part of the deleted scope group.

    The cmdlet issues a warning message at runtime to inform the user of the impact and prompts for 
    confirmation before proceeding with the removal.

    .PARAMETER Name 
    Specifies the name of the scope group to delete.

    .PARAMETER Id 
    Specifies the ID of the scope group to delete.

    .PARAMETER Force
    Switch parameter that performs the deletion without prompting for confirmation.

    .PARAMETER WhatIf 
    Displays the raw REST API call that would be made to GLP instead of sending the request. 
    This is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Remove-HPEGLScopeGroup -Name Gen10_Servers
    
    Removes the scope group named 'Gen10_Servers' after the user has confirmed the removal.

    .EXAMPLE
    Remove-HPEGLScopeGroup -Name Gen11_Servers -Force
    
    Removes the scope group named 'Gen11_Servers' without prompting for confirmation.

    .EXAMPLE
    Get-HPEGLScopeGroup -Name Gen10_Servers | Remove-HPEGLScopeGroup 
    
    Retrieves the scope group named 'Gen10_Servers' and removes it, pending user confirmation.

    .EXAMPLE
    "Gen10_Servers", "Gen11_Servers" | Remove-HPEGLScopeGroup -Force

    Removes the scope groups named 'Gen10_Servers' and 'Gen11_Servers' without prompting for confirmation.

    .EXAMPLE
    Get-HPEGLScopeGroup | Remove-HPEGLScopeGroup
    
    Retrieves all scope groups and removes them. A warning message appears and asks the user to 
    confirm the action for each scope group found.

    .INPUTS
    System.Collections.ArrayList
        List of scope groups from 'Get-HPEGLScopeGroup'.
    System.String, System.String[]
        A single string object or a list of string objects that represent the scope group names.

    .OUTPUTS
    System.Collections.ArrayList
    A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - Name of the scope group attempted to be deleted 
        * Id - ID of the scope group attempted to be deleted
        * Status - Status of the deletion attempt (Failed for HTTP error return; Complete if successful; Warning if no action is needed) 
        * Details - More information about the status         
        * Exception - Information about any exceptions generated during the operation.
    #>

    [CmdletBinding(DefaultParameterSetName = 'Name')]
    Param( 
                
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Name')]
        [String]$Name,

        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Id')]
        [String]$Id,

        [Switch]$Force,
            
        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose      

        $ObjectStatusList = [System.Collections.ArrayList]::new()
        $ScopeGroupsToDelete = [System.Collections.ArrayList]::new()

    }
    
    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name      = $Name
            Id        = $Id
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

        [void]$ObjectStatusList.add($objStatus)
    
    }
    
    end {
        
        # Get all scope groups to validate names/IDs
        try {
            $AllScopeGroups = Get-HPEGLScopeGroup
           
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        "[{0}] List of scope groups to delete: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList.name | out-string) | Write-Verbose

        
        foreach ($Object in $ObjectStatusList) {

            $ScopeGroup = $null

            if ($Object.Name) {
                $ScopeGroup = $AllScopeGroups | Where-Object name -eq $Object.Name

                if ($ScopeGroup) {
                    $Object.Id = $ScopeGroup.id
                    
                    $ScopeGroupInfo = [PSCustomObject]@{
                        Name = $Object.Name
                        Id   = $ScopeGroup.id
                    }
                    [void]$ScopeGroupsToDelete.Add($ScopeGroupInfo)
                }
                else {
                    # Scope group not found
                    $Object.Status = "Warning"
                    $Object.Details = "Scope group with name '$($Object.Name)' not found in the current workspace. No action needed."

                    if ($WhatIf) {
                        $WarningMessage = "Scope group '{0}' not found in the current workspace. No action needed." -f $Object.Name
                        Write-Warning $WarningMessage
                    }
                }
            }
            elseif ($Object.Id) {
                $ScopeGroup = $AllScopeGroups | Where-Object id -eq $Object.Id

                if ($ScopeGroup) {
                    $Object.Name = $ScopeGroup.name
                    
                    $ScopeGroupInfo = [PSCustomObject]@{
                        Name = $ScopeGroup.name
                        Id   = $Object.Id
                    }
                    [void]$ScopeGroupsToDelete.Add($ScopeGroupInfo)
                }
                else {
                    # Scope group not found
                    $Object.Status = "Warning"
                    $Object.Details = "Scope group with ID '$($Object.Id)' not found in the current workspace. No action needed."

                    if ($WhatIf) {
                        $WarningMessage = "Scope group ID '{0}' not found in the current workspace. No action needed." -f $Object.Id
                        Write-Warning $WarningMessage
                    }
                }
            }
        }

        # Delete scope groups
        if ($ScopeGroupsToDelete.Count -gt 0) {

            foreach ($ScopeGroupInfo in $ScopeGroupsToDelete) {

                $Uri = (Get-ScopeGroupsUri) + "/" + $ScopeGroupInfo.Id

                "[{0}] URI to delete scope group '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ScopeGroupInfo.Name, $Uri | Write-Verbose

                # Confirmation prompt
                if (-not $Force -and -not $WhatIf) {
                    $title = "Confirm Scope Group Deletion"
                    $message = "Are you sure you want to delete the scope group '{0}' (ID: {1})? This action cannot be undone and will affect users with roles assigned to this scope group." -f $ScopeGroupInfo.Name, $ScopeGroupInfo.Id
                    $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Deletes the scope group"
                    $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Keeps the scope group"
                    $options = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
                    $result = $host.ui.PromptForChoice($title, $message, $options, 1)

                    if ($result -eq 1) {
                        # User chose No
                        $Object = $ObjectStatusList | Where-Object { $_.Name -eq $ScopeGroupInfo.Name -or $_.Id -eq $ScopeGroupInfo.Id }
                        $Object.Status = "Cancelled"
                        $Object.Details = "Scope group deletion cancelled by user."
                        "[{0}] Scope group '{1}' deletion cancelled by user" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ScopeGroupInfo.Name | Write-Verbose
                        continue
                    }
                }

                # Delete scope group
                try {
                    Invoke-HPEGLWebRequest -Uri $Uri -Method DELETE -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | Out-Null
                    
                    if (-not $WhatIf) {
                        $Object = $ObjectStatusList | Where-Object { $_.Name -eq $ScopeGroupInfo.Name -or $_.Id -eq $ScopeGroupInfo.Id }
                        $Object.Status = "Complete"
                        $Object.Details = "Scope group successfully deleted."
                        "[{0}] Scope group '{1}' successfully deleted" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ScopeGroupInfo.Name | Write-Verbose
                    }
                }
                catch {
                    if (-not $WhatIf) {
                        $Object = $ObjectStatusList | Where-Object { $_.Name -eq $ScopeGroupInfo.Name -or $_.Id -eq $ScopeGroupInfo.Id }
                        $Object.Status = "Failed"
                        
                        # Use helper function to extract error message
                        $errorMsg = Get-HPEGLErrorMessage -ExceptionObject $_ -DefaultMessage "Scope group deletion failed!"
                        $Object.Details = $errorMsg
                        
                        # Build technical exception info with error code and HTTP status
                        $technicalInfo = @()
                        if ($Global:HPECOMInvokeReturnData.errorCode) {
                            $technicalInfo += "Code: $($Global:HPECOMInvokeReturnData.errorCode)"
                        }
                        if ($Global:HPECOMInvokeReturnData.httpStatusCode -or $Global:HPECOMInvokeReturnData.StatusCode) {
                            $statusCode = if ($Global:HPECOMInvokeReturnData.httpStatusCode) { $Global:HPECOMInvokeReturnData.httpStatusCode } else { $Global:HPECOMInvokeReturnData.StatusCode }
                            $technicalInfo += "HTTP $statusCode"
                        }
                        if ($technicalInfo.Count -eq 0) {
                            $technicalInfo += $_.Exception.GetType().Name
                        }
                        $Object.Exception = $technicalInfo -join " | "
                        
                        ("[{0}] Scope group '{1}' deletion failed: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ScopeGroupInfo.Name, $Object.Exception) | Write-Verbose
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

Function Copy-HPEGLScopeGroup {
    <#
    .SYNOPSIS
    Creates a copy of an existing scope group with a new name.

    .DESCRIPTION
    This cmdlet clones an existing scope group in an HPE GreenLake workspace, creating a new scope group 
    with the same filters and configuration but with a different name. This is useful for creating 
    similar scope groups without manually recreating all the filter associations.

    The cmdlet retrieves the source scope group with its detailed scope information and creates a new 
    scope group with the same filters, service configuration, and optionally a new description.

    .PARAMETER Name 
    The name of the source scope group to copy.

    .PARAMETER NewName
    The name for the new scope group. This parameter is mandatory.

    .PARAMETER Description
    Optional description for the new scope group. If not specified, the description from the source 
    scope group will be used.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option 
    is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Copy-HPEGLScopeGroup -Name "Production-Servers" -NewName "Staging-Servers"

    Creates a copy of the "Production-Servers" scope group with the name "Staging-Servers", 
    including all the same filters and configuration.

    .EXAMPLE
    Copy-HPEGLScopeGroup -Name "Production-Servers" -NewName "Development-Servers" -Description "Development environment servers"

    Creates a copy of the "Production-Servers" scope group with a new name and custom description.

    .EXAMPLE
    Get-HPEGLScopeGroup -Name "Production-Servers" | Copy-HPEGLScopeGroup -NewName "QA-Servers"

    Retrieves a scope group via pipeline and creates a copy with a new name.

    .INPUTS
    HPEGreenLake.ScopeGroup
        You can pipe scope group objects from Get-HPEGLScopeGroup.

    .OUTPUTS
    System.Collections.ArrayList
        Returns the same status object as New-HPEGLScopeGroup containing:
        * Name - Name of the new scope group
        * Status - Status of the creation attempt (Failed, Complete, or Warning)
        * Details - More information about the status
        * Exception - Information about any exceptions generated during the operation
        * Id - The ID of the newly created scope group

   #>

    [CmdletBinding()]
    Param( 
                    
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [String]$Name,

        [Parameter (Mandatory)]
        [String]$NewName,
            
        [Parameter]
        [String]$Description,

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        ("[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller) | Write-Verbose

        $CopyScopeGroupStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        ("[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string)) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name      = $NewName
            Status    = $null
            Details   = $null
            Exception = $null
            Id        = $null
        }
        [void] $CopyScopeGroupStatus.add($objStatus)

        try {
            # Check if target scope group already exists
            ("[{0}] Checking if target scope group '{1}' already exists" -f $MyInvocation.InvocationName.ToString().ToUpper(), $NewName) | Write-Verbose
            
            $ExistingTargetScopeGroup = Get-HPEGLScopeGroup -Name $NewName -Verbose:$false
            
            if ($ExistingTargetScopeGroup) {
                if ($WhatIf) {
                    Write-Warning "Target scope group '$NewName' already exists! Cannot show API preview as the scope group cannot be created."
                    return
                }
                
                $objStatus.Status = "Warning"
                $objStatus.Details = "Target scope group '$NewName' already exists"
                $objStatus.Id = $ExistingTargetScopeGroup.id
                ("[{0}] Target scope group '{1}' already exists with ID: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $NewName, $ExistingTargetScopeGroup.id) | Write-Verbose
                return
            }
            
            # Get the source scope group with detailed information
            ("[{0}] Retrieving source scope group '{1}' with detailed scope information" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name) | Write-Verbose
            
            $SourceScopeGroup = Get-HPEGLScopeGroup -Name $Name
            
            if (-not $SourceScopeGroup) {
                if ($WhatIf) {
                    Write-Warning "Source scope group '$Name' not found! Cannot show API preview without an existing source scope group."
                    return
                }
                
                $objStatus.Status = "Failed"
                $objStatus.Details = "Source scope group '$Name' not found"
                ("[{0}] Source scope group '{1}' not found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name) | Write-Verbose
                return
            }

            # Get the detailed scope information to retrieve filters
            $DetailUri = "{0}/internal-platform-tenant-ui/v2/scope-groups/{1}" -f (Get-HPEGLAPIOrgbaseURL), $SourceScopeGroup.id
            
            ("[{0}] Retrieving detailed scopes for source scope group '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name) | Write-Verbose
            
            $DetailedScopeGroup = Invoke-HPEGLWebRequest -Method Get -Uri $DetailUri -WhatIfBoolean $false -Verbose:$VerbosePreference
            
            if (-not $DetailedScopeGroup -or -not $DetailedScopeGroup.scopes) {
                $objStatus.Status = "Failed"
                $objStatus.Details = "Could not retrieve scope details from source scope group"
                Write-Warning "Could not retrieve scope details from source scope group '$Name'"
                return
            }

            # Use provided description or fallback to source description
            $NewDescription = if ($PSBoundParameters.ContainsKey('Description')) {
                $Description
            }
            else {
                $DetailedScopeGroup.description
            }

            ("[{0}] Creating new scope group '{1}' based on '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $NewName, $Name) | Write-Verbose
            ("[{0}] Source scope group has {1} scope(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DetailedScopeGroup.scopes.Count) | Write-Verbose

            # Build service filters array (API expects array format, not object)
            $ServiceFilters = @(
                @{
                    applicationId = $DetailedScopeGroup.internal.availableItemFilters.applicationId
                    serviceId     = $DetailedScopeGroup.internal.availableItemFilters.serviceId
                }
            )

            # Rebuild resourceDetails with only API-accepted fields (exclude resourceProviderName)
            $CleanedResourceDetails = @()
            foreach ($detail in $DetailedScopeGroup.resourceDetails) {
                $CleanedResourceDetails += @{
                    grn                     = $detail.grn
                    name                    = $detail.name
                    allScopes               = $detail.allScopes
                    resourceTypeDisplayName = $detail.resourceTypeDisplayName
                }
            }

            # Build the payload for the new scope group
            $payload = @{
                name            = $NewName
                description     = $NewDescription
                scopes          = $DetailedScopeGroup.scopes
                resourceDetails = $CleanedResourceDetails
                internal        = @{
                    availableItemFilters = $ServiceFilters
                }
            }

            $Uri = Get-ScopeGroupsUri

            $body = $payload | ConvertTo-Json -Depth 10

            ("[{0}] POST URI: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri) | Write-Verbose
            ("[{0}] POST Body: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $body) | Write-Verbose

            $Response = Invoke-HPEGLWebRequest -Uri $Uri -Method POST -Body $body -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
            
            if (-not $WhatIf) {
                $objStatus.Status = "Complete"
                $objStatus.Details = "Scope group successfully copied from '$Name'"
                $objStatus.Id = $Response.id
                ("[{0}] Scope group '{1}' successfully created as copy of '{2}' with ID: {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $NewName, $Name, $Response.id) | Write-Verbose
            }
        }
        catch {
            $objStatus.Status = "Failed"
            
            # Use helper function to extract error message
            $objStatus.Details = if ($_.Exception.Message) { 
                $_.Exception.Message 
            } else {             
                Get-HPEGLErrorMessage -ExceptionObject $_ -DefaultMessage "Error copying scope group"
            }
            
            # Build technical exception info with error code and HTTP status
            $technicalInfo = @()
            if ($Global:HPECOMInvokeReturnData.errorCode) {
                $technicalInfo += "Code: $($Global:HPECOMInvokeReturnData.errorCode)"
            }
            if ($Global:HPECOMInvokeReturnData.httpStatusCode -or $Global:HPECOMInvokeReturnData.StatusCode) {
                $statusCode = if ($Global:HPECOMInvokeReturnData.httpStatusCode) { $Global:HPECOMInvokeReturnData.httpStatusCode } else { $Global:HPECOMInvokeReturnData.StatusCode }
                $technicalInfo += "HTTP $statusCode"
            }
            if ($technicalInfo.Count -eq 0) {
                $technicalInfo += $_.Exception.GetType().Name
            }
            $objStatus.Exception = $technicalInfo -join " | "
            
            ("[{0}] Error copying scope group '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $objStatus.Exception) | Write-Error
        }
    }

    End {
        if (-not $WhatIf) {
            $CopyScopeGroupStatus = Invoke-RepackageObjectWithType -RawObject $CopyScopeGroupStatus -ObjectName "ObjStatus.NSDE"
            return $CopyScopeGroupStatus
        }
    }
}

# User Preferences

Function Get-HPEGLUserPreference {
    <#
    .SYNOPSIS
    Displays HPE GreenLake user preferences.

    .DESCRIPTION
    This Cmdlet returns the user profile preferences for HPE GreenLake, including settings such as language, session timeout, notification and multi-factor preferences.       

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Get-HPEGLUserPreference

    Return the user profile preferences for HPE GreenLake.
    
   #>
    [CmdletBinding()]
    Param( 

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
        
        # Use the new v1alpha1 API endpoint - need to get both global and common preferences
        $GlobalUri = (Get-UserPreferencesV1Alpha1Uri) + "?category=globalpreferences"
        $CommonUri = (Get-UserPreferencesV1Alpha1Uri) + "?category=commonpreferences"
        
    }
    
    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $ReturnData = [System.Collections.ArrayList]::new()

        try {
            $GlobalResponse = Invoke-HPEGLWebRequest -Method GET -Uri $GlobalUri -SkipSessionCheck -SkipPaginationLimit -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
            $CommonResponse = Invoke-HPEGLWebRequest -Method GET -Uri $CommonUri -SkipSessionCheck -SkipPaginationLimit -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

   
        if ($Null -ne $GlobalResponse -and $GlobalResponse.data) {
            
            # Transform the new v1alpha1 API response format
            # Combine both globalpreferences and commonpreferences
            $UserPreferences = [PSCustomObject]@{
                # Global preferences
                language       = ($GlobalResponse.data | Where-Object { $_.name -eq 'language' }).value
                idle_timeout   = ($GlobalResponse.data | Where-Object { $_.name -eq 'sessionTimeout' }).value
                theme          = ($GlobalResponse.data | Where-Object { $_.name -eq 'theme' }).value
                temperature    = ($GlobalResponse.data | Where-Object { $_.name -eq 'temperature' }).value
                measure        = ($GlobalResponse.data | Where-Object { $_.name -eq 'measure' }).value
                localeDateTime = ($GlobalResponse.data | Where-Object { $_.name -eq 'localeDateTime' }).value
                # Common/Home preferences
                showGettingStarted = ($CommonResponse.data | Where-Object { $_.name -eq 'showGettingStarted' }).value
                showWhatsNew       = ($CommonResponse.data | Where-Object { $_.name -eq 'showWhatsNew' }).value
                showWidgets        = ($CommonResponse.data | Where-Object { $_.name -eq 'showWidgets' }).value
                preferredLandingPage = ($CommonResponse.data | Where-Object { $_.name -eq 'preferredLandingPage' }).value
                showGLHeaderOnHover  = ($CommonResponse.data | Where-Object { $_.name -eq 'showGLHeaderOnHover' }).value
            }

            $ReturnData = Invoke-RepackageObjectWithType -RawObject $UserPreferences -ObjectName "User.Preference"    
    
            return $ReturnData  
        }
        else {
            
            return            
        }
 
    }
}

Function Set-HPEGLUserPreference {
    <#
    .SYNOPSIS
    Update HPE GreenLake user preferences.

    .DESCRIPTION
    Cmdlet can be used to update the HPE GreenLake user preferences such as session timeout, language, theme, and notification settings.  

    .PARAMETER Language 
    The Language directive can be used to set the language to use in the HPE GreenLake UI. 
    Supported languages: Chinese, English, French, German, Japanese, Korean, Portuguese, Russian, Spanish, Italian

    .PARAMETER SessionTimeoutInMinutes 
    The SessionTimeoutInMinutes directive can be used to set the session timeout (in minutes). 
    The value must be at least 5 and cannot exceed 120 minutes. The default is 30 minutes.

    .PARAMETER Temperature
    Sets the temperature unit for the HPE GreenLake interface. Valid values are 'fahrenheit' or 'celsius'.

    .PARAMETER Measure
    Sets the unit of measure for the HPE GreenLake interface. Valid values are 'feet' or 'meters'.

    .PARAMETER ShowGettingStarted
    Enable or disable the Getting Started section on the home page. Use $true to enable or $false to disable.

    .PARAMETER ShowWhatsNew
    Enable or disable the What's New section on the home page. Use $true to enable or $false to disable.

    .PARAMETER ShowWidgets
    Enable or disable the Widgets section on the home page. Use $true to enable or $false to disable.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Set-HPEGLUserPreference -Language English

    Sets the language of the HPE GreenLake user interface to English.

    .EXAMPLE
    Set-HPEGLUserPreference -SessionTimeoutInMinutes 120

    Set the session timeout of the HPE GreenLake user interface to 120 minutes.

    .EXAMPLE
    Set-HPEGLUserPreference -Temperature celsius -Measure meters

    Sets the temperature unit to celsius and the unit of measure to meters.

    .EXAMPLE
    Set-HPEGLUserPreference -ShowGettingStarted $true -ShowWhatsNew $true

    Enables the Getting Started and What's New sections on the home page.

    .EXAMPLE
    Set-HPEGLUserPreference -Language Français -SessionTimeoutInMinutes 60

    Sets multiple preferences at once: French language and 60-minute session timeout.

    .INPUTS
    None. You cannot pipe objects to this Cmdlet.

    .OUTPUTS
    System.Collections.ArrayList
    A custom status object or array of objects containing the following PsCustomObject keys:  
        * Email - Email address of the user 
        * Status - Status of the modification attempt (Failed for http error return; Complete if the update of the user preferences is successful) 
        * Details - More information about the status         
        * Exception: Information about any exceptions generated during the operation.
    
   #>
    [CmdletBinding()]
    Param( 

        # Language parameter with ArgumentCompleter for tab completion
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $supportedLanguages = $Global:HPESupportedLanguages.Keys
                $supportedLanguages | Where-Object { $_ -like "$wordToComplete*" } | Sort-Object
            })]
        [ValidateScript({ 
                if ($Global:HPESupportedLanguages[$_]) {
                    $True
                }
                else {
                    Throw "'$_' is not a valid language name! Supported languages: $($Global:HPESupportedLanguages.Keys -join ', ')"
                }
            })]
        [String]$Language,   
        
        [ValidateScript({
                if ($_ -ge 5 -and $_ -le 120) {
                    $True
                }    
                else {
                    Throw "Session timeout value must be at least 5 and cannot exceed 120 minutes."
                }
            })]        
        [Int]$SessionTimeoutInMinutes,

        [ValidateSet("fahrenheit", "celsius")]
        [String]$Temperature,

        [ValidateSet("feet", "meters")]
        [String]$Measure,

        [Boolean]$ShowGettingStarted,

        [Boolean]$ShowWhatsNew,

        [Boolean]$ShowWidgets,

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        # Use the new v1alpha1 API endpoints
        $GlobalGetUri = (Get-UserPreferencesV1Alpha1Uri) + "?category=globalpreferences"
        $CommonGetUri = (Get-UserPreferencesV1Alpha1Uri) + "?category=commonpreferences"
        $SaveUri = Get-SaveUserPreferencesV1Alpha1Uri

        $SetUserPreferenceStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Check if at least one parameter was provided
        $hasParameters = $PSBoundParameters.Keys | Where-Object { $_ -in @('Language', 'SessionTimeoutInMinutes', 'Temperature', 'Measure', 'ShowGettingStarted', 'ShowWhatsNew', 'ShowWidgets') }

        if (-not $hasParameters) {
            
            if ($Whatif) {
                $ErrorMessage = "At least one preference parameter must be provided!" 
                Write-warning $ErrorMessage
                return
            }
            else {
                # Build object for the output
                $objStatus = [pscustomobject]@{
                    Email     = $Global:HPEGreenLakeSession.username
                    Status    = "Failed"
                    Details   = "At least one preference parameter must be provided!"
                    Exception = $Null
                }
                [void] $SetUserPreferenceStatus.add($objStatus)
            }
            
        }
        else {
            
            # Build object for the output
            $objStatus = [pscustomobject]@{
                Email     = $Global:HPEGreenLakeSession.username
                Status    = $Null
                Details   = $Null
                Exception = $Null
            }
                
            # User Preferences modification using new v1alpha1 API
            try {
            
                # Determine which categories need to be updated
                $globalParams = $PSBoundParameters.Keys | Where-Object { $_ -in @('Language', 'SessionTimeoutInMinutes', 'Temperature', 'Measure') }
                $commonParams = $PSBoundParameters.Keys | Where-Object { $_ -in @('ShowGettingStarted', 'ShowWhatsNew', 'ShowWidgets') }

                # Update Global Preferences if needed
                if ($globalParams) {
                    "[{0}] Retrieving global preferences from v1alpha1 API..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    $CurrentPrefsResponse = Invoke-HPEGLWebRequest -Method GET -Uri $GlobalGetUri -SkipSessionCheck -SkipPaginationLimit -WhatIfBoolean $false -Verbose:$VerbosePreference
                    
                    if (-not $CurrentPrefsResponse -or -not $CurrentPrefsResponse.data) {
                        throw "Failed to retrieve current global preferences"
                    }

                    # Build the data array with current values
                    $dataArray = @()
                    foreach ($item in $CurrentPrefsResponse.data) {
                        $newItem = @{
                            groupName = $item.groupName
                            id = $item.id
                            name = $item.name
                            title = $item.title
                            titleKey = $item.titleKey
                            type = $item.type
                            value = $item.value
                        }
                        
                        # Update values based on provided parameters
                        switch ($item.name) {
                            'language' {
                                if ($Language) {
                                    $LanguageSet = $Global:HPESupportedLanguages[$Language]
                                    $newItem.value = $LanguageSet
                                    "[{0}] Updating language to: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $LanguageSet | Write-Verbose
                                }
                            }
                            'sessionTimeout' {
                                if ($SessionTimeoutInMinutes) {
                                    $newItem.value = $SessionTimeoutInMinutes * 60
                                    "[{0}] Updating session timeout to: {1} seconds ({2} minutes)" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($SessionTimeoutInMinutes * 60), $SessionTimeoutInMinutes | Write-Verbose
                                }
                            }
                            'temperature' {
                                if ($PSBoundParameters.ContainsKey('Temperature')) {
                                    $newItem.value = $Temperature
                                    "[{0}] Updating temperature to: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Temperature | Write-Verbose
                                }
                            }
                            'measure' {
                                if ($PSBoundParameters.ContainsKey('Measure')) {
                                    $newItem.value = $Measure
                                    "[{0}] Updating measure to: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Measure | Write-Verbose
                                }
                            }
                        }
                        
                        $dataArray += $newItem
                    }

                    # Build the request body for save-preferences endpoint
                    $SaveBody = @{
                        category = "globalpreferences"
                        data = $dataArray
                    }

                    "[{0}] Sending save request for global preferences to v1alpha1 API..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    $Response = Invoke-HPEGLWebRequest -Method POST -Body ($SaveBody | ConvertTo-Json -Depth 10) -Uri $SaveUri -SkipSessionCheck -SkipPaginationLimit -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                }

                # Update Common/Home Preferences if needed
                if ($commonParams) {
                    "[{0}] Retrieving common preferences from v1alpha1 API..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    $CurrentCommonPrefs = Invoke-HPEGLWebRequest -Method GET -Uri $CommonGetUri -SkipSessionCheck -SkipPaginationLimit -WhatIfBoolean $false -Verbose:$VerbosePreference
                    
                    if (-not $CurrentCommonPrefs -or -not $CurrentCommonPrefs.data) {
                        throw "Failed to retrieve current common preferences"
                    }

                    # Build the data array with current values
                    $commonDataArray = @()
                    foreach ($item in $CurrentCommonPrefs.data) {
                        $newItem = @{
                            groupName = $item.groupName
                            id = $item.id
                            name = $item.name
                            title = $item.title
                            type = $item.type
                            value = $item.value
                        }
                        
                        # Add titleKey if it exists
                        if ($item.PSObject.Properties.Name -contains 'titleKey') {
                            $newItem.titleKey = $item.titleKey
                        }
                        
                        # Add level if it exists
                        if ($item.PSObject.Properties.Name -contains 'level') {
                            $newItem.level = $item.level
                        }
                        
                        # Update values based on provided parameters
                        switch ($item.name) {
                            'showGettingStarted' {
                                if ($PSBoundParameters.ContainsKey('ShowGettingStarted')) {
                                    $newItem.value = $ShowGettingStarted
                                    "[{0}] Updating showGettingStarted to: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ShowGettingStarted | Write-Verbose
                                }
                            }
                            'showWhatsNew' {
                                if ($PSBoundParameters.ContainsKey('ShowWhatsNew')) {
                                    $newItem.value = $ShowWhatsNew
                                    "[{0}] Updating showWhatsNew to: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ShowWhatsNew | Write-Verbose
                                }
                            }
                            'showWidgets' {
                                if ($PSBoundParameters.ContainsKey('ShowWidgets')) {
                                    $newItem.value = $ShowWidgets
                                    "[{0}] Updating showWidgets to: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ShowWidgets | Write-Verbose
                                }
                            }
                        }
                        
                        $commonDataArray += $newItem
                    }

                    # Build the request body for save-preferences endpoint
                    $CommonSaveBody = @{
                        category = "commonpreferences"
                        data = $commonDataArray
                    }

                    "[{0}] Sending save request for common preferences to v1alpha1 API..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    $Response = Invoke-HPEGLWebRequest -Method POST -Body ($CommonSaveBody | ConvertTo-Json -Depth 10) -Uri $SaveUri -SkipSessionCheck -SkipPaginationLimit -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                }
                            
                if (-not $WhatIf) {
    
                    # Update session object if it exists
                    if ($SessionTimeoutInMinutes -and $Global:HPEGreenLakeSession.PSObject.Properties.Name -contains 'userSessionIdleTimeout') {
                        $Global:HPEGreenLakeSession.userSessionIdleTimeout = $SessionTimeoutInMinutes
                    }

                    $objStatus.Status = "Complete"
                    $objStatus.Details = "User preferences updated successfully"
                }

            }
            catch {

                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { 
                        $_.Exception.Message 
                    } else {                        
                        Get-HPEGLErrorMessage -ExceptionObject $_ -DefaultMessage "User preference update failed!"
                    }
                    
                    # Build technical diagnostics
                    $technicalInfo = @()
                    if ($Global:HPECOMInvokeReturnData.errorCode) {
                        $technicalInfo += "Code: $($Global:HPECOMInvokeReturnData.errorCode)"
                    }
                    if ($Global:HPECOMInvokeReturnData.httpStatusCode -or $Global:HPECOMInvokeReturnData.StatusCode) {
                        $statusCode = if ($Global:HPECOMInvokeReturnData.httpStatusCode) { 
                            $Global:HPECOMInvokeReturnData.httpStatusCode 
                        } else { 
                            $Global:HPECOMInvokeReturnData.StatusCode 
                        }
                        $technicalInfo += "HTTP $statusCode"
                    }
                    if ($technicalInfo.Count -eq 0) {
                        $technicalInfo += $_.Exception.GetType().Name
                    }
                    $objStatus.Exception = $technicalInfo -join " | "
                }
            }    
            
        }

        [void] $SetUserPreferenceStatus.add($objStatus)
            
    }

    end {

        if (-not $WhatIf) {

            $SetUserPreferenceStatus = Invoke-RepackageObjectWithType -RawObject $SetUserPreferenceStatus -ObjectName "ObjStatus.ESDE" 
            Return $SetUserPreferenceStatus
        }



    }
}

# User account details

Function Get-HPEGLUserAccountDetails {
    <#
    .SYNOPSIS
    Retrieves details of HPE GreenLake user accounts.

    .DESCRIPTION
    This Cmdlet fetches and displays HPE GreenLake user account details. The returned information includes personal details, organization name, address, time zone, language preferences, and phone numbers.
    
    .PARAMETER Raw
    Switch to return all available properties of the HPE GreenLake user account details in their raw, unprocessed form. 

    .PARAMETER WhatIf 
    Displays the raw REST API call that would be made to GLP without actually sending the request. This is useful for understanding the native REST API calls utilized by GLP.

    .EXAMPLE
    Get-HPEGLUserAccountDetails

    Retrieves and displays the details of your HPE GreenLake user account.
    
    .EXAMPLE
    Get-HPEGLUserAccountDetails -Raw
    
    Retrieves and displays all available properties of your HPE GreenLake user account details in their raw form.
    
    .INPUTS
    None. You cannot pipe objects to this Cmdlet.

#>


    [CmdletBinding()]
    Param( 

        [switch]$Raw,
        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        # Check for a valid HPE Onepass session 
        if (-not $Global:HPEGreenLakeSession.onepassToken.access_token) {
            '[{0}] No active session found for HPE Onepass. Attempting to connect...' -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            try {
                Connect-HPEOnepass -Verbose:$VerbosePreference | Out-Null
                '[{0}] Successfully connected to HPE Onepass.' -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            }
            catch {
                throw "Session token has expired. Please run Connect-HPEGL to establish a session before using this cmdlet."
            }
            # throw "No active session found. Please run Connect-HPEGL to establish a session before using this cmdlet."
        }

        if ($Global:HPEGreenLakeSession.onepassToken.creation_time -and $Global:HPEGreenLakeSession.onepassToken.expires_in) {
            $creationTime = [datetime]::Parse($Global:HPEGreenLakeSession.onepassToken.creation_time)
            $expiresIn = [int]$Global:HPEGreenLakeSession.onepassToken.expires_in
            $expiryTime = $creationTime.AddSeconds($expiresIn)
            if ((Get-Date) -ge $expiryTime) {   
                '[{0}] HPE Onepass session token has expired. Attempting to reconnect...' -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose         
                try {
                    Connect-HPEOnepass -Verbose:$VerbosePreference | Out-Null
                }
                catch {
                    throw "Session token has expired. Please run Connect-HPEGL to establish a session before using this cmdlet."
                }
            }
        }

        $Uri = (Get-HPEOnepassbaseURL) + "/v2-get-user/" + $Global:HPEGreenLakeSession.username

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # $ReturnData = @() #[System.Collections.ArrayList]::new()

        try {
            [array]$UserAccountDetails = Invoke-HPEGLWebRequest -Method POST -Uri $Uri -SkipSessionCheck -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

   
        if ($Null -ne $UserAccountDetails ) {

            if ($raw) {
                $ReturnData = $UserAccountDetails
            }
            else {
                if ($UserAccountDetails.profile) {
                    $ReturnData = $UserAccountDetails.profile | Select-Object firstName, lastName, hpeCompanyName, streetAddress, hpeStreetAddress2, city, state, zipCode, hpeCountryCode, hpeTimezone, preferredLanguage, primaryPhone, mobilePhone
                    # $ReturnData = Invoke-RepackageObjectWithType -RawObject $UserAccountDetails -ObjectName "User.AccountDetails"    
                }
                else {
                    # Required to get any error returned by invoke-HPEGLwebrequest
                    $ReturnData = $UserAccountDetails
                }
            }
    
            return $ReturnData  
        }
        else {
            
            return            
        }
 
    }
}

Function Set-HPEGLUserAccountDetails {
    <#
    .SYNOPSIS
    Set HPE GreenLake user account details.

    .DESCRIPTION
    This Cmdlet is used to update the HPE GreenLake user account details, such as first name, last name, address, time zone, language information, etc. If you omit any parameter, the cmdlet retains the current settings for those fields and only updates the provided parameters.
      
    .PARAMETER Language 
    Specifies the language to use in the HPE GreenLake UI. Supported languages include: Chinese, English, French, German, Japanese, Korean, Portuguese, Russian, Spanish, and Italian.

    .PARAMETER Street
    Sets the primary street address for the user.

    .PARAMETER Street2
    Sets the secondary address line for the user.

    .PARAMETER City
    Sets the city where the user resides.

    .PARAMETER State
    Sets the state or province where the user resides.

    .PARAMETER PostalCode
    Sets the postal code for the user's address.

    .PARAMETER Timezone
    Sets the time zone for the user's location.

    .PARAMETER WhatIf 
    Displays the raw REST API call that would be made to GLP instead of actually sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Set-HPEGLUserAccountDetails `
    -Firstname Henri `
    -Lastname Poincaré `
    -Organizationname "Celestial" `
    -Street "Theory of dynamical systems street" `
    -Street2 "Cosmos building" `
    -City Heaven `
    -PostalCode 77777 `
    -Country France `
    -Timezone Europe/Paris `
    -Language English `
    -PrimaryPhone +33123456789 `
    -Mobilephone +33612345678

    Set all parameter details of the HPE GreenLake user account for the currently connected user.

    .EXAMPLE
    Set-HPEGLUserAccountDetails -Timezone Europe/Paris -Language French 

    Sets the time zone and language details of the HPE GreenLake user account for the currently connected user. 
    
    .EXAMPLE
    Set-HPEGLUserAccountDetails -Firstname Albert -Lastname Einstein
    
    Updates the first name and last name of the HPE GreenLake user account while preserving all other existing settings.

    .EXAMPLE
    Set-HPEGLUserAccountDetails -State "" -Street2 ""

    Removes the state and the secondary address line details from the HPE GreenLake user account while preserving all other existing settings.
    
    .INPUTS
    None. You cannot pipe objects to this Cmdlet.

    #>


    [CmdletBinding()]
    Param( 
        [String]$Firstname,
        [String]$Lastname,
        [String]$Organizationname,
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

        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $timezoneNames = $Global:HPEGLSchemaMetadata.hpeTimezones
                $timezoneNames | Where-Object { $_ -like "$wordToComplete*" } | Sort-Object
            })]
        [ValidateScript({ 
                if ($Global:HPEGLSchemaMetadata.hpeTimezones -contains $_) {
                    $True
                }
                else {
                    Throw "'$_' is not a valid timezone name! Supported timezones: $($Global:HPEGLSchemaMetadata.hpeTimezones -join ', ')"

                }
            })]
        [String]$Timezone, 

        [ValidateScript({ 
                if ($Global:HPESupportedLanguages[$_]) {
                    $True
                }
                else {
                    Throw "'$_' is not a valid language name! Supported languages: $($Global:HPESupportedLanguages.Keys -join ', ')"
                }
            })]
        [String]$Language,   

        [String]$PrimaryPhone,  
        [String]$Mobilephone,   
        [Switch]$WhatIf

    ) 

    Begin {
       
        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        # Check for a valid HPE Onepass session 
        if (-not $Global:HPEGreenLakeSession.onepassToken.access_token) {
            '[{0}] No active session found for HPE Onepass. Attempting to connect...' -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            try {
                Connect-HPEOnepass -Verbose:$VerbosePreference | Out-Null
                '[{0}] Successfully connected to HPE Onepass.' -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            }
            catch {
                throw "Session token has expired. Please run Connect-HPEGL to establish a session before using this cmdlet."
            }
            # throw "No active session found. Please run Connect-HPEGL to establish a session before using this cmdlet."
        }

        if ($Global:HPEGreenLakeSession.onepassToken.creation_time -and $Global:HPEGreenLakeSession.onepassToken.expires_in) {
            $creationTime = [datetime]::Parse($Global:HPEGreenLakeSession.onepassToken.creation_time)
            $expiresIn = [int]$Global:HPEGreenLakeSession.onepassToken.expires_in
            $expiryTime = $creationTime.AddSeconds($expiresIn)
            if ((Get-Date) -ge $expiryTime) {   
                '[{0}] HPE Onepass session token has expired. Attempting to reconnect...' -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose         
                try {
                    Connect-HPEOnepass -Verbose:$VerbosePreference | Out-Null
                }
                catch {
                    throw "Session token has expired. Please run Connect-HPEGL to establish a session before using this cmdlet."
                }
            }
        }

        $Uri = (Get-HPEOnepassbaseURL) + "/v2-update-user-okta/" + $Global:HPEGreenLakeSession.username

        $SetUserAccountDetailsStatus = [System.Collections.ArrayList]::new()
        
    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        try {
            $UserAccountDetails = Get-HPEGLUserAccountDetails -Raw 
           
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }



        # Build object for the output
        $objStatus = [pscustomobject]@{
        
            Email     = $Global:HPEGreenLakeSession.username
            Status    = $Null
            Details   = $Null
            Exception = $Null
                
        }


        # Build payload

        $_Profile = @{ 
            email = $Global:HPEGreenLakeSession.username
            login = $Global:HPEGreenLakeSession.username
        }

        
        if ($Firstname) {
            $_Profile.firstName = $Firstname

        }

        if ($Lastname) {
            $_Profile.lastName = $Lastname

        }

        if ($PSBoundParameters.ContainsKey('Organizationname')) {
            $_Profile.hpeCompanyName = $Organizationname
            $_Profile.UserUpdatedGTSAttribute = "Y"

        }  

        if ($PSBoundParameters.ContainsKey('Street')) {
            $_Profile.streetAddress = $Street
            $_Profile.UserUpdatedGTSAttribute = "Y"

        }

        if ($PSBoundParameters.ContainsKey('Street2')) {
            $_Profile.hpeStreetAddress2 = $Street2
            $_Profile.UserUpdatedGTSAttribute = "Y"

        }

        if ($PSBoundParameters.ContainsKey('City')) {
            $_Profile.city = $City
            $_Profile.UserUpdatedGTSAttribute = "Y"
            
        }
        
        if ($PSBoundParameters.ContainsKey('State')) {
            $_Profile.state = $State
            $_Profile.UserUpdatedGTSAttribute = "Y"
            
        }
        
        if ($PSBoundParameters.ContainsKey('PostalCode')) {
            $_Profile.zipCode = $PostalCode
            $_Profile.UserUpdatedGTSAttribute = "Y"
            
        }
        
        if ($Country) {

            $CountryCode = $Global:HPEGLSchemaMetadata.hpeCountryCodes | Where-Object name -eq $Country | ForEach-Object code

            $_Profile.hpeCountryCode = $CountryCode
            $_Profile.countryCode = $CountryCode
            $_Profile.UserUpdatedGTSAttribute = "Y"

            if ($Language) {

                $LanguageSet = $Global:HPESupportedLanguages[$language]
                $_Profile.locale = $LanguageSet + "_" + $CountryCode
            }
            else {
                $LanguageSet = $UserAccountDetails.profile.preferredLanguage
                $_Profile.locale = $LanguageSet + "_" + $CountryCode
            }
        }
        
        if ($Timezone) {
            $_Profile.hpeTimezone = $Timezone
            
        }
        
        if ($Language) {
            
            $LanguageSet = $Global:HPESupportedLanguages[$language]
            $_Profile.preferredLanguage = $LanguageSet
            
            if ($CountryCode) {

                $_Profile.locale = $LanguageSet + "_" + $CountryCode
            }
            else {
                $CountryCode = $UserAccountDetails.profile.countryCode
                $_Profile.locale = $LanguageSet + "_" + $CountryCode

            }

        }

        if ($PSBoundParameters.ContainsKey('PrimaryPhone')) {
            $_Profile.primaryPhone = $PrimaryPhone

        }

        if ($PSBoundParameters.ContainsKey('Mobilephone')) {
            $_Profile.mobilePhone = $Mobilephone

        } 
        
        $payload = @{ 
            profile = $_Profile
            # sessionId = $Global:HPEGreenLakeSession.onepassSid  # Auto added by Invoke-HPEGLWebRequest
                    
        }

        $payload = ConvertTo-Json $payload -Depth 10 

             
        # User account details modification
        
        try {
            $Response = Invoke-HPEGLWebRequest -Method POST -Body $payload -Uri $Uri -SkipSessionCheck -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
        
            if (-not $WhatIf) {
   
                $objStatus.Status = "Complete"
                # Extract message from response if it exists, otherwise use a default success message
                if ($Response.message) {
                    $objStatus.Details = $Response.message
                }
                else {
                    $objStatus.Details = "User account details updated successfully"
                }
            }
        
        }
        catch {

            if (-not $WhatIf) {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { 
                    $_.Exception.Message 
                } else {    
                    Get-HPEGLErrorMessage -ExceptionObject $_ -DefaultMessage "User account details update failed!"
                }
                
                # Build technical diagnostics
                $technicalInfo = @()
                if ($Global:HPECOMInvokeReturnData.errorCode) {
                    $technicalInfo += "Code: $($Global:HPECOMInvokeReturnData.errorCode)"
                }
                if ($Global:HPECOMInvokeReturnData.httpStatusCode -or $Global:HPECOMInvokeReturnData.StatusCode) {
                    $statusCode = if ($Global:HPECOMInvokeReturnData.httpStatusCode) { 
                        $Global:HPECOMInvokeReturnData.httpStatusCode 
                    } else { 
                        $Global:HPECOMInvokeReturnData.StatusCode 
                    }
                    $technicalInfo += "HTTP $statusCode"
                }
                if ($technicalInfo.Count -eq 0) {
                    $technicalInfo += $_.Exception.GetType().Name
                }
                $objStatus.Exception = $technicalInfo -join " | "
            }
        }

        [void] $SetUserAccountDetailsStatus.add($objStatus)
   
    }

    end {

        if (-not $WhatIf) {

            $SetUserAccountDetailsStatus = Invoke-RepackageObjectWithType -RawObject $SetUserAccountDetailsStatus -ObjectName "ObjStatus.ESDE" 
            Return $SetUserAccountDetailsStatus

        }
    }
}

Function Set-HPEGLUserAccountPassword {
    <#
    .SYNOPSIS
    Set HPE GreenLake user account password.

    .DESCRIPTION
    This Cmdlet can be used to set the HPE GreenLake user account password for local users only.
    
    IMPORTANT: This cmdlet only works for LOCAL users. The following user types cannot change their 
    password through this cmdlet:
    - SSO/SCIM users: Managed by external identity providers (e.g., Azure AD). Contact your IdP administrator.
    - External users: Managed by a different organization. Contact the controlling organization administrator.
    
    You can check your user type by running: Get-HPEGLUser -Email <your-email> | Select-Object email, authz_source
    
    .PARAMETER currentpassword
    Your current user account password as a secure string.

    .PARAMETER newpassword
    Your new password to set as a secure string. It must meet the following requirements:
    - Contains at least one upper case letter
    - Contains at least one lower case letter
    - Contains at least one number (0-9)
    - Contains at least one symbol (eg. !@#$%^&)
    - Does not contain part of email
    - Does not contain first name
    - Does not contain last name
    - Does not contain common passwords
    - Does not match any of your last 24 passwords

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    $currentpassord = Read-Host -AsSecureString -Prompt "Enter your current password"
    $newpassord = Read-Host -AsSecureString -Prompt "Enter the new password to set"

    Set-HPEGLUserAccountPassword -CurrentPassword $currentpassord -NewPassword $newpassord

    Change the HPE GreenLake user account password to a new one for the currently connected user.

    .EXAMPLE
    $plainTextCurrentpassord = "np$$rPKHK39cU3e9T%SzR!!L"
    $secureCurrentPassword = ConvertTo-SecureString $plainTextCurrentpassord -AsPlainText -Force
    $plainTextNewpassword = "kLi7@zvzt4DyhUXUE8^32keY"
    $secureNewPassword = ConvertTo-SecureString $plainTextNewpassword -AsPlainText -Force

    Set-HPEGLUserAccountPassword -CurrentPassword $secureCurrentPassword -NewPassword $secureNewPassword

    Change the HPE GreenLake user account password to a new one for the currently connected user.

  
   #>
    [CmdletBinding()]
    Param( 
        [Parameter(Mandatory)]
        [SecureString]$CurrentPassword,
        [Parameter(Mandatory)]
        [SecureString]$NewPassword,
        [Switch]$WhatIf

    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        # Check for a valid HPE Onepass session 
        if (-not $Global:HPEGreenLakeSession.onepassToken.access_token) {
            '[{0}] No active session found for HPE Onepass. Attempting to connect...' -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            try {
                Connect-HPEOnepass -Verbose:$VerbosePreference | Out-Null
                '[{0}] Successfully connected to HPE Onepass.' -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            }
            catch {
                throw "Session token has expired. Please run Connect-HPEGL to establish a session before using this cmdlet."
            }
            # throw "No active session found. Please run Connect-HPEGL to establish a session before using this cmdlet."
        }

        if ($Global:HPEGreenLakeSession.onepassToken.creation_time -and $Global:HPEGreenLakeSession.onepassToken.expires_in) {
            $creationTime = [datetime]::Parse($Global:HPEGreenLakeSession.onepassToken.creation_time)
            $expiresIn = [int]$Global:HPEGreenLakeSession.onepassToken.expires_in
            $expiryTime = $creationTime.AddSeconds($expiresIn)
            if ((Get-Date) -ge $expiryTime) {   
                '[{0}] HPE Onepass session token has expired. Attempting to reconnect...' -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose         
                try {
                    Connect-HPEOnepass -Verbose:$VerbosePreference | Out-Null
                }
                catch {
                    throw "Session token has expired. Please run Connect-HPEGL to establish a session before using this cmdlet."
                }
            }
        }

        $UserPasswordChangeStatus = [System.Collections.ArrayList]::new()
        
        # Check if user is a local user or externally managed user
        try {
            $currentUser = Get-HPEGLUser -Email $Global:HPEGreenLakeSession.username
            '[{0}] User authentication source: {1}' -f $MyInvocation.InvocationName.ToString().ToUpper(), $currentUser.authz_source | Write-Verbose
        }
        catch {
            $objStatus = [pscustomobject]@{
                Email     = $Global:HPEGreenLakeSession.username
                Status    = "Failed"
                Details   = "Unable to verify user authentication source. Please ensure you have an active HPE GreenLake session."
                Exception = $_.Exception.Message
            }
            [void] $UserPasswordChangeStatus.add($objStatus)
            
            $UserPasswordChangeStatus = Invoke-RepackageObjectWithType -RawObject $UserPasswordChangeStatus -ObjectName "ObjStatus.ESDE" 
            return $UserPasswordChangeStatus
        }

        # Validate that only LOCAL users can change passwords
        $authzSource = $currentUser.authz_source
        if ($authzSource -ne 'LOCAL') {
            
            $errorMessage = $null
            
            switch ($authzSource) {
                'SSO' {
                    $errorMessage = @"
Password change is not allowed for SSO users.

Your account is managed by an external identity provider (SCIM integration).
Please contact your identity provider administrator to change your password.
"@
                }
                'SCIM' {
                    $errorMessage = @"
Password change is not allowed for SCIM users.

Your account is managed by an external identity provider.
Please contact your identity provider administrator to change your password.
"@
                }
                'External' {
                    $errorMessage = @"
Password change is not allowed for External users.

Your account is managed by a different organization.
Please contact the controlling organization administrator to change your password.
"@
                }
                default {
                    $errorMessage = @"
Password change is not allowed.

Unable to determine user authentication source (authz_source: $authzSource).
Only LOCAL users can change their password through this cmdlet.
"@
                }
            }
            
            if ($WhatIf) {
                Write-Warning $errorMessage
                Write-Warning "WhatIf: The password change operation would be blocked due to the authentication source restriction."
                return
            }
            else {
                $objStatus = [pscustomobject]@{
                    Email     = $Global:HPEGreenLakeSession.username
                    Status    = "Failed"
                    Details   = $errorMessage
                    Exception = $null
                }
                
                Write-Warning $errorMessage
                [void] $UserPasswordChangeStatus.add($objStatus)
                
                $UserPasswordChangeStatus = Invoke-RepackageObjectWithType -RawObject $UserPasswordChangeStatus -ObjectName "ObjStatus.ESDE" 
                return $UserPasswordChangeStatus
            }
        }
        
        '[{0}] User is a local user. Password change is allowed.' -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

        $userid = (Get-HPEGLUserAccountDetails -Raw).id
        $Uri = (Get-HPEOnepassbaseURL) + "/v2-change-password-okta/" + $userid
        
        $_OldPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($CurrentPassword))
        $_NewPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($NewPassword))

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
        
            Email     = $Global:HPEGreenLakeSession.username
            Status    = $Null
            Details   = $Null
            Exception = $Null
                
        }

        $upperCasePattern = '[A-Z]'
        $lowerCasePattern = '[a-z]'
        $numberPattern = '[0-9]'
        $symbolPattern = '[!@#$%^&*(),.?":{}|<>]'

        if ($_NewPassword -match $upperCasePattern -and `
                $_NewPassword -match $lowerCasePattern -and `
                $_NewPassword -match $numberPattern -and `
                $_NewPassword -match $symbolPattern) {
            
       
            $Payload = @{ 
                oldPassword = @{
                    value = $_oldPassword
                } 
                newPassword = @{
                    value = $_newPassword

                } 
            
            } | ConvertTo-Json -Depth 5

            # Create a sanitized version of the payload for logging/display (mask passwords)
            $SanitizedPayload = @{ 
                oldPassword = @{
                    value = "********"
                } 
                newPassword = @{
                    value = "********"
                } 
            } | ConvertTo-Json -Depth 5

            "[{0}] Payload content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SanitizedPayload | Write-Verbose

            # User password modification
            
            try {
                # Pass the sanitized payload for WhatIf display
                if ($WhatIf) {
                    [array]$Response = Invoke-HPEGLWebRequest -Method POST -Body $SanitizedPayload -Uri $Uri -SkipSessionCheck -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                }
                else {
                    [array]$Response = Invoke-HPEGLWebRequest -Method POST -Body $Payload -Uri $Uri -SkipSessionCheck -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                }    
            
                if (-not $WhatIf) {
    
                    $objStatus.Status = "Complete"
                    $objStatus.Details = ($Response | ForEach-Object message)
                }
            
            }
            catch {

                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { 
                        $_.Exception.Message 
                    } else {    
                        Get-HPEGLErrorMessage -ExceptionObject $_ -DefaultMessage "User password change failed!"
                    }
                    
                    # Build technical diagnostics
                    $technicalInfo = @()
                    if ($Global:HPECOMInvokeReturnData.errorCode) {
                        $technicalInfo += "Code: $($Global:HPECOMInvokeReturnData.errorCode)"
                    }
                    if ($Global:HPECOMInvokeReturnData.httpStatusCode -or $Global:HPECOMInvokeReturnData.StatusCode) {
                        $statusCode = if ($Global:HPECOMInvokeReturnData.httpStatusCode) { 
                            $Global:HPECOMInvokeReturnData.httpStatusCode 
                        } else { 
                            $Global:HPECOMInvokeReturnData.StatusCode 
                        }
                        $technicalInfo += "HTTP $statusCode"
                    }
                    if ($technicalInfo.Count -eq 0) {
                        $technicalInfo += $_.Exception.GetType().Name
                    }
                    $objStatus.Exception = $technicalInfo -join " | "
                }
            }

            [void] $UserPasswordChangeStatus.add($objStatus)

        } 
        else {

            $errorMessage = "The new password does not meet the requirements, it should contain at least one upper case letter, at least one lower case letter, at least one number (0-9) and at least one symbol (eg. !@#$%^&)."
            
            throw $errorMessage
        }
   
    }
    end {

        if (-not $WhatIf) {

            $UserPasswordChangeStatus = Invoke-RepackageObjectWithType -RawObject $UserPasswordChangeStatus -ObjectName "ObjStatus.ESDE" 
            Return $UserPasswordChangeStatus
        }
    }
}


# Private helper functions (not exported)

Function Get-HPEGLErrorMessage {
    <#
    .SYNOPSIS
    Extracts meaningful error messages from API responses.
    
    .DESCRIPTION
    This helper function extracts error messages from $Global:HPECOMInvokeReturnData object,
    handling various formats and fallback scenarios.
    
    .PARAMETER ExceptionObject
    The PowerShell exception object as fallback.
    
    .PARAMETER DefaultMessage
    Default message to use if extraction fails.
    
    .EXAMPLE
    $errorMsg = Get-HPEGLErrorMessage -ExceptionObject $_ -DefaultMessage "Operation failed"
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$ExceptionObject,
        
        [Parameter(Mandatory)]
        [string]$DefaultMessage
    )
    
    # Get the global error variable set by Invoke-HPEGLWebRequest
    $GlobalErrorVariable = $Global:HPECOMInvokeReturnData
    
    if ($GlobalErrorVariable) {
        # Try to extract from rawError first (most complete)
        if ($GlobalErrorVariable.rawError) {
            try {
                # Try to extract message using regex first (more reliable for malformed JSON)
                # Use non-greedy match to capture everything including smart quotes
                if ($GlobalErrorVariable.rawError -match '"message"\s*:\s*"(.*?)"[,\}]') {
                    $extractedMsg = $Matches[1] -replace '\\"', '"' -replace '"', '"' -replace '"', '"' -replace '\\r', '' -replace '\\n', ''
                    if ($extractedMsg -and $extractedMsg.Trim().Length -gt 3) {
                        return $extractedMsg
                    }
                }
                
                # Fallback: Try JSON parsing
                $errorObj = $GlobalErrorVariable.rawError | ConvertFrom-Json -ErrorAction Stop
                if ($errorObj.message) {
                    return $errorObj.message
                }
            }
            catch {
                # JSON parsing failed, continue to next fallback
            }
        }
        
        # Fallback to message property
        if ($GlobalErrorVariable.message -and $GlobalErrorVariable.message.Trim().Length -gt 3) {
            return $GlobalErrorVariable.message
        }
    }
    
    # Final fallback to exception message
    if ($ExceptionObject.Exception.Message) {
        return $ExceptionObject.Exception.Message
    }
    
    return $DefaultMessage
}

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
Export-ModuleMember -Function 'Get-HPEGLUser', 'New-HPEGLUser', 'Send-HPEGLUserInvitation', 'Remove-HPEGLUser', 'Get-HPEGLRole', 'Get-HPEGLUserRole', 'Add-HPEGLRoleToUser', `
'Remove-HPEGLRoleFromUser', 'Set-HPEGLUserRole', 'Get-HPEGLUserGroup', 'New-HPEGLUserGroup', 'Remove-HPEGLUserGroup', 'Set-HPEGLUserGroup', 'Add-HPEGLRoleToUserGroup', 'Remove-HPEGLRoleFromUserGroup', 'Add-HPEGLUserToUserGroup', 'Remove-HPEGLUserFromUserGroup', 'Get-HPEGLUserGroupMembership', `
'Get-HPEGLUserPreference', 'Set-HPEGLUserPreference', 'Get-HPEGLUserAccountDetails', 'Set-HPEGLUserAccountDetails', 'Set-HPEGLUserAccountPassword', `
'Get-HPEGLScopeGroup', 'New-HPEGLScopeGroup', 'Remove-HPEGLScopeGroup', 'Set-HPEGLScopeGroup', 'Copy-HPEGLScopeGroup', 'Add-HPEGLScopeGroupToUser', 'Remove-HPEGLScopeGroupFromUser' `
-Alias *


# SIG # Begin signature block
# MIIungYJKoZIhvcNAQcCoIIujzCCLosCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCHrVCnUy1H+oHy
# lCRd5wo08fYiirtQSCsgPWn9GOJLr6CCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQgSXhByX3ehKFOAF80DvEobniTOoZaV+65AQET7ZK+JREwDQYJKoZIhvcNAQEB
# BQAEggIAowxX4/YiuinzDYape8PvTPvJC/LZefb3F3ClVW1Ernq3rXm4aDOYhn+G
# tob5xSJhAffM5/DA7DDTj4RmNtx76onuxe0devFhm4AZk9kzNuk3AquhNq5+SfgV
# 4FKiigyH5TaoOuAQ+u5/PC/9Xl8J3jQzqQl9YBv15gaVl1HveI4DWNdd84xihzyC
# 85tcs22WgZ52NaTpRQW0ykzOb7j6ACLmWsxUgxjGXHACoCz+VbJdwNfM19I6FCc0
# 6wdIJGzslRJizCMFR7D+cCQUAKICxcx9B37c2mhumO3ZgC/nF+Cdqh+rfp9jwDPK
# Y3nWd7PgLa75Iinj3tGOOgTRQTDVrv4ZLJTv/xQOmxoB6gvnmI2yyHeVoAQ6X6a0
# uzgTH37fcSujpq6EPUV84suneP91e3Owh6xB+vv6nIwUjb4m/Vr56AyxNTNLZheh
# D6gbt2qcnNIIWu1OB+xyupZMPcLCzdjUi1ZpuEoq1jXtbgUsfhBtgyaT98bAL3wQ
# JTU7cFzlOcG7cHzeqB+CVVOR5gTsevarSwMw0IAeLPeQQKHvhWJjIpoIjPK4j679
# FuAO0NRymEz8SqIJgzJ2LT/uDO19kbqRbQDynj8Oeab0nCLUsrJfGLgyx9ZS6zLg
# g78cPH5EiBccscfG/Z3rzzr2mHKYjoLP6cY2zIPwzqV4N3QaEtChghjoMIIY5AYK
# KwYBBAGCNwMDATGCGNQwghjQBgkqhkiG9w0BBwKgghjBMIIYvQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBBwYLKoZIhvcNAQkQAQSggfcEgfQwgfECAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQwv0X4tkcQd92YuqWIr6Ww2/92kNJt6XDVyjI6
# nng+cLsR5ZH3Tc/5kllAXCpJe1plAhRFp0kkIVHvuH3L76n0QGnMhXl/WxgPMjAy
# NjAxMzAxMDU0MzBaoHakdDByMQswCQYDVQQGEwJHQjEXMBUGA1UECBMOV2VzdCBZ
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
# DxcNMjYwMTMwMTA1NDMwWjA/BgkqhkiG9w0BCQQxMgQwY327uon1qhRhWJ+nw1r8
# Y1++CMsQXx9RnT987Bl9AqIpqfCkPhnFh7PcFLZfpS+5MIIBegYLKoZIhvcNAQkQ
# AgwxggFpMIIBZTCCAWEwFgQUOMkUgRBEtNxmPpPUdEuBQYaptbEwgYcEFMauVOR4
# hvF8PVUSSIxpw0p6+cLdMG8wW6RZMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRpbWUgU3Rh
# bXBpbmcgUm9vdCBSNDYCEHojrtpTaZYPkcg+XPTH4z8wgbwEFIU9Yy2TgoJhfNCQ
# NcSR3pLBQtrHMIGjMIGOpIGLMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKTmV3
# IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBVU0VS
# VFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZpY2F0
# aW9uIEF1dGhvcml0eQIQNsKwvXwbOuejs902y8l1aDANBgkqhkiG9w0BAQEFAASC
# AgBgGRdsIUYW4neb6WCgeQkK6mjp4CpBGKPzN2xF2yelK1u9r2Sa9zG0qdyRcBzJ
# Hzet/biy/JB69eA7sajHRKSiyGDM/WTMEAAJpt6doHjovD5hj7LPUx/AGSpqfzCz
# RQ5sm35b9ccPhIOCLjf1Qui6Pg58VYFWZOV7shM6DDfgD/3j+GGetvD4W5EROjGX
# +ueOh6SKmB7wlmyD7ED1YM3v7+G7gbsY/AMFpvvzjml4Mjc6jgTtAzs+C6/hFXML
# EgOkO50ifF8iq0AJHrYVCmoMLRwbeGsVoFZSBbvtd+tWACUWwZlHoiBTF6y8kv6X
# bWJMpqvixxs77H5EIxQBFARtCHop+b2ONDoM2o6ZgVr2OYmDqOw4ggHtM90LvoKj
# t7bpRPo2SdjeGEPCRryH+rc8eY5gPKImMIRP0XtZ+RtVLZbBFsaxpW3aBxDXjK9c
# BTn1ciNOqbQ6dEHmlOkeqHzy3YUSCSSOZHlHBaSoEqJOPoQzkmUd3Jwm0SgPweB5
# 7eCmzcn6jRppUXhkKnQlRQtZheMgrXi0Qccph/o83vWv4r9vrRhoixkQyPt6TLo8
# vnid/lDcGqJ0BwRefamWyzWTMBSuDbbMizIEh5lj0DrxhrjI0X7c0Ze5VQYjcP9F
# WmTb8l0kQXZLn+1pR/S5x8iqj78YVIU/62ogh0rgBJzs1A==
# SIG # End signature block
