#------------------- FUNCTIONS FOR HPE GreenLake USERS - ROLES - PERMISSIONS -----------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1
 
# Public Functions
Function Get-HPEGLUser {
    <#
    .SYNOPSIS
    Retrieve user resource(s).

    .DESCRIPTION
    This Cmdlet returns a collection of user resources or user statistics. Roles and permissions can also be retrieved.

    .PARAMETER FirstName 
    Specifies the first name associated with resources (case-sensitive!).

    .PARAMETER LastName 
    Specifies the last name associated with resources (case-sensitive!).
  
    .PARAMETER Email 
    Specifies the email associated with resources.

    .PARAMETER ShowUnverified 
    Optional parameter that can be used to display unverified users.

    .PARAMETER ShowStats 
    Optional parameter that can be used to display user statistics.

    .PARAMETER ShowRoles 
    This option can be used to see the roles assigned to a user.

    .PARAMETER ShowPermissions 
    This option can be used to see the permissions assigned to a user.
    
    .PARAMETER ShowActivities
    This option can be used to see the last month activities data of a user.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Get-HPEGLUser -FirstName Eddy 

    Return the user resource with first name "Eddy".

    .EXAMPLE
    Get-HPEGLUser -ShowStats 

    Return user statistics.

    .EXAMPLE
    Get-HPEGLUser -ShowPermissions -FirstName Albert -LastName Einstein

    Return Albert Einstein permissions.

    .EXAMPLE
    Get-HPEGLUser -ShowRoles -FirstName Albert -LastName Einstein

    Return Albert Einstein roles.
    
   #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 

        [Parameter (ParameterSetName = 'Default')]
        [Parameter (Mandatory, ParameterSetName = 'Roles')]
        [Parameter (Mandatory, ParameterSetName = 'Permissions')]
        [Parameter (Mandatory, ParameterSetName = 'Activity')]
        [ValidateNotNullOrEmpty()]
        [String]$FirstName,  

        [Parameter (ParameterSetName = 'Default')]
        [Parameter (Mandatory, ParameterSetName = 'Roles')]
        [Parameter (Mandatory, ParameterSetName = 'Permissions')]
        [Parameter (Mandatory, ParameterSetName = 'Activity')]
        [ValidateNotNullOrEmpty()]
        [String]$LastName,  
        
        [Parameter (Mandatory, ParameterSetName = 'Email')]
        [Parameter (Mandatory, ParameterSetName = 'EmailRoles')]
        [Parameter (Mandatory, ParameterSetName = 'EmailPermissions')]
        [Parameter (Mandatory, ParameterSetName = 'EmailActivity')]
        [ValidateNotNullOrEmpty()]
        [validatescript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$Email,  

        [Parameter(Mandatory, ParameterSetName = 'Unverified')]
        [Switch]$ShowUnverified,
                
        [Parameter (Mandatory, ParameterSetName = 'Roles')]
        [Parameter (Mandatory, ParameterSetName = 'EmailRoles')]
        [Switch]$ShowRoles,
        
        [Parameter (Mandatory, ParameterSetName = 'EmailActivity')]
        [Parameter (Mandatory, ParameterSetName = 'Activity')]
        [Switch]$ShowActivities,

        [Parameter (Mandatory, ParameterSetName = 'Permissions')]
        [Parameter (Mandatory, ParameterSetName = 'EmailPermissions')]
        [Switch]$ShowPermissions,
        
        [Parameter(Mandatory, ParameterSetName = 'Stats')]
        [Switch]$ShowStats,

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = (Get-UsersUri) + "?limit=2000&include_unverified=true"

        $query = @()

        if ($FirstName) {
            $query += "first_name=$FirstName"
        }

        if ($LastName) {
            $query += "last_name=$LastName"
        }

        if ($ShowStats) {
            $Uri = Get-UsersStatsUri
        }
        
        if ($query) {
            foreach ($Item in $query) {
                if ($query.count -eq 1) {
                    $queries = $Item
                }
                else {
                    $queries += ($Item + "&")
                }

                $Uri = $Uri + "&" + $queries

            }
            
        }
        
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

        if ($ShowStats) {

            $ReturnData = Invoke-RepackageObjectWithType -RawObject $Collection -ObjectName "User.stat"         
            return $ReturnData 

        }
        else {

            if ($Null -ne $Collection.users) {
                
                $CollectionList = $Collection.users 

                # "[{0}] List of users: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), ( $CollectionList | out-string ) | Write-Verbose

                if ($Email) {
                    $CollectionList = $CollectionList | Where-Object { $_.contact.email -eq $email }
                }

                if ($ShowUnverified) {
                    $CollectionList = $CollectionList | Where-Object { $_.user_status -eq "UNVERIFIED" }
                }

                if ($ShowRoles) {      
                    
                    $RolesList = @()                    

                    if (-not $Email) {
                         
                        $Emailfound = $CollectionList.contact.email
                        
                    }
                    else {
                        $Emailfound = $Email
                    }

                    "[{0}] Number of users: '{1}': retreiving role for: '{2}': '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CollectionList.count, $Emailfound, ( $CollectionList | out-string ) | Write-Verbose

                    foreach ($Item in $Emailfound) {
                        
                        try {

                            $Rolesfound = Get-HPEGLUserRole -Email $Item 
                            $RolesList += $Rolesfound
                        
                    
                        }
                        catch {
                            $PSCmdlet.ThrowTerminatingError($_)
                        }
                
                    }
    
                    
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $RolesList -ObjectName "User.Role"         
                    $ReturnData = $ReturnData | sort-object email, application_name, role, resource_restriction_policy
                    
                    return $ReturnData
                       
                    
                }
                elseif ($ShowPermissions) {

                    $PermissionsList = @()

                    if ($Email) {
                         
                        $CollectionList = $CollectionList | Where-Object { $_.contact.email -eq $Email }
                    }

                    "[{0}] Number of users: '{1}': retreiving permissions for: '{2}': '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CollectionList.count, $Email, ( $CollectionList | out-string ) | Write-Verbose

            
                    if ($CollectionList.count -ne "1") {
                        throw "You need to refine your query as several users have been found and this is not compatible with the Permissions parameter!"
                    }
                    else {

                        $UserRoles = $CollectionList.user_role
                                       
                        foreach ($UserRole in $UserRoles) {

                            $Rolename = $UserRole | ForEach-Object role_name
                            $AppName = $UserRole | ForEach-Object application_name
                        
                            "[{0}] Service: '{1}' - Role: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $AppName, $Rolename | Write-Verbose

                            try {
                                $ResourcePolicies = Get-HPEGLRole -ServiceName $AppName -ServiceRole $RoleName -ShowPermissions

                                $PermissionsList += $ResourcePolicies

                            }
                            catch {
                                $PSCmdlet.ThrowTerminatingError($_)
                            }

                     
                       
                        }
                        
                        $PermissionsList = $PermissionsList | Sort-Object application, rolename, resource
                        return $PermissionsList

                    }


                }
                else {


                    # Add email to object
                    foreach ($user in $CollectionList) {
                        $user | Add-Member -MemberType NoteProperty -Name email -Value $user.contact.email
                        $user | Add-Member -MemberType NoteProperty -Name firstname -Value $user.contact.first_name
                        $user | Add-Member -MemberType NoteProperty -Name lastname -Value $user.contact.last_name
                    }
                   
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "User"         
                    $ReturnData = $ReturnData | Sort-Object firstName, lastname, email
           

                    if ($ShowActivities) {

                        $SearchString = $ReturnData.contact.Email
                        $ReturnData = Get-HPEGLAuditLog -SearchString $SearchString -ShowLastMonth
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
}

Function Send-HPEGLUserInvitation {
    <#
    .SYNOPSIS
    Send an invitation email to join the HPE GreenLake workspace.

    .DESCRIPTION
    This cmdlet is used by workspace administrators to invite team members to join the currently connected HPE GreenLake workspace. 
    An email notification is sent to the specified user's address, and the user is added to the team members with the designated role.

    .PARAMETER Email
    Specifies the email address of the user to be invited.

    .PARAMETER Role
    Specifies the HPE GreenLake role to assign to the user.
    The predefined roles are:
        * Workspace Administrator
        * Workspace Observer
        * Workspace Operator
        * Orders Administrator
        * Orders Observer
        * Orders Operator

    .PARAMETER SenderEmail
    (Optional) Specifies the email address of the sender of this invitation. When not defined, the user email address used with Connect-HPEGL to create a session with the worksapce is used.

    .PARAMETER Resend
    Indicates that a new invitation should be sent to an existing user.

    .PARAMETER WhatIf
    Displays the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Send-HPEGLUserInvitation -Email leonhard.euler@mathematician.edu -Role 'Orders Operator' -SenderEmail bernhard.riemann@mathematician.edu

    Leonhard Euler is added to the team members as an Orders Operator, and an email notification is sent to the specified email address.
    Bernhard Riemann is recorded as the administrator who added Leonhard Euler to the group.

    .EXAMPLE
    Send-HPEGLUserInvitation -Email leonhard.euler@mathematician.com -Resend

    A new invitation is re-sent to Leonhard Euler.

    .EXAMPLE
    'leonhard.euler@mathematician.com','bernhard.riemann@mathematician.edu' | Send-HPEGLUserInvitation -Role 'Account Administrator'

    Leonhard Euler and Bernhard Riemann are added to the team members as Account Administrators, and email notifications are sent to them.

    .EXAMPLE
    Import-Csv emails.csv | Send-HPEGLUserInvitation 

    Sends an invitation to the email addresses listed in a CSV file containing at least the Email and Role columns.

    The content of the CSV file must use the following format:
        Email, Role
        leonhard.euler@mathematician.com, Workspace Administrator
        bernhard.riemann@mathematician.edu, Workspace Observer

    .INPUTS
    System.String, System.String[]
        A single string object or an array of string objects that represent the user's email addresses.
    System.Collections.ArrayList
       List of users from a CSV file containing columns for email and role.
    

    .OUTPUTS
    System.Collections.ArrayList
    A custom status object or array of objects containing the following PsCustomObject keys:  
        * Email - The email address of the user.
        * Status - The status of the join group/email notification attempt (Failed for HTTP error return; Complete if successful; Warning if no action is needed).
        * Details - More information about the status.
        * Exception - Information about any exceptions generated during the operation.
    #>


    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = 'Default')]
        [Parameter (Mandatory, ValueFromPipeline, ParameterSetName = 'Resend')]
        [ValidateNotNullOrEmpty()]
        [validatescript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$Email,  

        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Default')]
        [ValidateSet('Workspace Administrator', 'Workspace Observer', 'Workspace Operator', 'Orders Administrator', 'Orders Observer', 'Orders Operator')]
        [String]$Role,

        [Parameter (ParameterSetName = 'Default')]
        [validatescript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$SenderEmail,  

        [Parameter (ParameterSetName = 'Resend')]
        [Switch]$Resend,

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        if ($Resend) {
            # Resend an invite
            $Uri = Get-ReInviteUserUri 
        }
        else {
            $Uri = Get-InviteUserUri
        }
        
        $ObjectStatusList = [System.Collections.ArrayList]::new()
        # $UsernamesList = [System.Collections.ArrayList]::new()


        try {
            $AppRole = Get-HPEGLRole -HPEGreenLake
            $Users = Get-HPEGLUser

            $RoleSlug = $AppRole | Where-Object name -eq $Role | ForEach-Object slug

            $WorkspaceType = Get-HPEGLWorkspace -ShowCurrent | Select-Object -ExpandProperty account_type

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

        if ($Resend) {

            if (-not $User) {
                # Must return a message if account not found
                "[{0}] User '{1}' account does not exist!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email | Write-Verbose

                if ($WhatIf) {
                    $ErrorMessage = "User '{0}' cannot be found in the workspace to resend an invitation!" -f $Email
                    Write-warning $ErrorMessage
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "User account cannot be found in the workspace to resend an invitation!"
                    
                }

            }
            elseif ($User.user_status -eq "VERIFIED") {
                # Must return a message if account is already verified
                "[{0}] User '{1}' account is already verified!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email | Write-Verbose

                if ($WhatIf) {
                    $ErrorMessage = "User '{0}' is already verified!" -f $Email
                    Write-warning $ErrorMessage
                    return
                }
                else {
                    $objStatus.Status = "Warning"
                    $objStatus.Details = "User is already verified!"
                    
                }

            }
            else {
             
                # Create payload  
                $Payload = [PSCustomObject]@{
                    usernames = @($Email)
            
                } | ConvertTo-Json      

                # Resend invitation      
                
                try {
                    [array]$Collection = Invoke-HPEGLWebRequest -Method Post -Uri $Uri -Body $Payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

                    if (-not $WhatIf) {
                        $objStatus.Status = "Complete"
                        $objStatus.Details = "Invitation resent!"
                    }

                    if ($Collection.message) {
                        $Collection.message | Write-Verbose
                    }
                }
                catch {
            
                    if (-not $WhatIf) {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Invitation resending failure!"
                        $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                    }
                }
           
            }
        }
        else {

            if ($User) {
                # Must return a message if account found
                "[{0}] User '{1}' account has already been invited!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email | Write-Verbose

                if ($WhatIf) {
                    $ErrorMessage = "User '{0}' has already been invited to the HPE GreenLake workspace!" -f $Email
                    Write-warning $ErrorMessage
                    return
                }
                else {
                    $objStatus.Status = "Warning"
                    $objStatus.Details = "User account has already been invited!"
                }
            }
            else {
            
                $RoleSlug = $AppRole | Where-Object name -eq $Role | ForEach-Object slug
                     
                # Create payload  
                $Payload = [PSCustomObject]@{
                    user_names          = @($Email)
                    contact_information = if ($SenderEmail) { $SenderEmail } else { $Global:HPEGreenLakeSession.username }
                    roles               = @(
                        @{ 
                            role = @{
                                application_id = "00000000-0000-0000-0000-000000000000"
                                slug           = $RoleSlug 
                            }
                        })
                } 

                if ($WorkspaceType -eq "MSP") {
                    $Payload.roles[0].access_rules = @{
                        msp     = $true
                        tenants = @( "ALL" )
                    } 
                }                

                $Payload = $Payload | ConvertTo-Json -Depth 5

                # Send invitation      
                
                try {
                    [array]$Collection = Invoke-HPEGLWebRequest -Method Post -Uri $Uri -Body $Payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
        
                    if (-not $WhatIf) {
                        $objStatus.Status = "Complete"
                        $objStatus.Details = "Invitation sent!"
                    }
        
                    if ($Collection.message) {
                        $Collection.message | Write-Verbose
                    }
                }
                catch {
                    
                    if (-not $WhatIf) {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Invitation sending failure!"
                        $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                    }
                }
            }
        }     



        [void] $ObjectStatusList.add($objStatus)
    }

    end {

        # API DOES NOT SUPPORT LIST OF EMAILS IN PAYLOAD RIGHT NOW !

        # try {
        #     $Users = Get-HPEGLUser
           
        # }
        # catch {
        #     $PSCmdlet.ThrowTerminatingError($_)
            
        # }


        # "[{0}] List of users to send an invitation: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList.Email | out-string) | Write-Verbose

        # foreach ($Object in $ObjectStatusList) {

        #     $User = $Users | Where-Object email -eq $Object.Email

        #     if ($Resend) {
                
        #         if (-not $User) {
                    
        #             # Must return a message if not found
        #             $Object.Status = "Failed"
        #             $Object.Details =  "User account cannot be found in the HPE GreenLake workspace to resend an invitation!"
                    
        #             if ($WhatIf) {
        #                 $ErrorMessage = "User '{0}' cannot be found in the HPE GreenLake workspace to resend an invitation!" -f $Object.Email
        #                 Write-warning $ErrorMessage
        #                 continue
        #             }
                    
        #         } 

        #     }
        #     else {

        #         if ( $User) {
                    
        #             # Must return a message if account found
        #             $Object.Status = "Warning"
        #             $Object.Details = "User account has already been invited!"
                    
        #             if ($WhatIf) {
        #                 $ErrorMessage = "User '{0}' has already been invited to the HPE GreenLake workspace!" -f $Object.Email
        #                 Write-warning $ErrorMessage
        #                 continue
        #             }
                    
        #         } 
        #     }

        #     # Building the list of email object where to send the invitation
        #     [void]$UsernamesList.Add($Object.Email)

        # }


        # if ($UsernamesList) {

        #     # Build payload
        #     $payload = ConvertTo-Json $UsernamesList
            
        #     if ($Resend) {
                
        #         # Create payload  
        #         $Payload = [PSCustomObject]@{
        #             usernames = $UsernamesList
            
        #         } | ConvertTo-Json  
                
        #     }
        #     else {
                
        #         # Create payload  
        #         $Payload = [PSCustomObject]@{
        #             user_names          = $UsernamesList
        #             contact_information = if ($SenderEmail) { $SenderEmail } else { $Global:HPEGreenLakeSession.username }
        #             roles               = @(
        #                 @{ role = @{
        #                         application_id = "00000000-0000-0000-0000-000000000000"
        #                         slug           = $RoleSlug 
        #                     }
                            
        #                 })
        #         } | ConvertTo-Json -Depth 5

        #     }
            
            
        #     # Send invitation      
        #     try {

        #         Invoke-HPEGLWebRequest -Uri $Uri -method 'POST' -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    | out-Null
                
        #         if (-not $WhatIf) {
                    
        #             foreach ($Object in $ObjectStatusList) {

        #                 $Username = $UsernamesList | Where-Object {$_ -eq $Object.email}

        #                 If ($Username) {

        #                     if ($Resend) {

        #                         $Object.Status = "Complete"
        #                         $Object.Details = "Invitation resent successfully!"

        #                     }
        #                     else {
        #                         $Object.Status = "Complete"
        #                         $Object.Details = "Invitation sent successfully!"
        #                     }
        #                 }
        #             }
        #         }
        #     }
        #     catch {
                
        #         if (-not $WhatIf) {

        #             foreach ($Object in $ObjectStatusList) {

        #                 $Username = $UsernamesList | Where-Object {$_ -eq $Object.email}
                        
        #                 If ($Username) {

        #                     if ($Resend) {

        #                         $Object.Status = "Failed"
        #                         $Object.Details =  "Invitation resending failure!"
        #                         $Object.Exception = $_.Exception.message 
                                

        #                     }
        #                     else {
                                  
        #                         $Object.Status = "Failed"
        #                         $Object.Details =  "Invitation sending failure!"
        #                         $Object.Exception = $_.Exception.message 
        #                     }
        #                 }
        #             }
        #         }
        #     }
        # }
                            

        if (-not $WhatIf) {

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "ObjStatus.ESDE" 
            Return $ObjectStatusList
        }
    }
}

Function Remove-HPEGLUser {
    <#
    .SYNOPSIS
    Delete a user from the HPE GreenLake workspace.

    .DESCRIPTION
    This cmdlet can be used by account administrators to delete a user account from the currently connected HPE GreenLake workspace.

    .PARAMETER Email
    Specifies the email address of the user to delete.

    .PARAMETER WhatIf
    Displays the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Remove-HPEGLUser -Email johanncarlfriedrich.gauss@mathematician.edu

    Deletes the user Johann Carl Friedrich Gauss.

    .EXAMPLE
    'leonhard.euler@mathematician.com','bernhard.riemann@mathematician.edu' | Remove-HPEGLUser

    Deletes Leonhard Euler and Bernhard Riemann from the currently connected HPE GreenLake workspace.

    .EXAMPLE
    Import-Csv emails.csv | Remove-HPEGLUser 

    Deletes the users whose email addresses are listed in a CSV file containing at least an Email column.

    The content of the CSV file must use the following format:
        Email
        leonhard.euler@mathematician.com
        bernhard.riemann@mathematician.edu

    .EXAMPLE
    Get-HPEGLUser | Remove-HPEGLUser 
    
    Deletes all users from the HPE GrenLake workspace.

    .INPUTS
    System.Collections.ArrayList
        List of user(s) from 'Get-HPEGLUser'.
    System.String, System.String[]
        A single string object or an array of string objects representing the user's email addresses.

    .OUTPUTS
    System.Collections.ArrayList
    A custom status object or array of objects containing the following PsCustomObject keys:  
        * Email - The email address of the user.
        * Status - The status of the removal attempt (Failed for HTTP error return; Complete if successful).
        * Details - More information about the status.
        * Exception - Information about any exceptions generated during the operation.
    #>

    [CmdletBinding()]
    Param( 

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [validatescript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$Email,  

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-UsersUri

        $ObjectStatusList = [System.Collections.ArrayList]::new()
        $UsernamesList = [System.Collections.ArrayList]::new()
        
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
        
        [void] $ObjectStatusList.add($objStatus)

    }
    end {
        
        try {

            $Users = Get-HPEGLUser
           
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        "[{0}] List of users to delete: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList.Email | out-string) | Write-Verbose
        

        foreach ($Object in $ObjectStatusList) {

            $User = $false

            $User = $Users | Where-Object email -eq $Object.Email

            if ($User) {
                
                # Building the list of email object to delete
                [void]$UsernamesList.Add($Object.Email)

            }
            else {
                
                # Must return a message if account not found
                $Object.Status = "Warning"
                $objStatus.Details = "User with email '$($Object.Email)' not found in the current workspace. No action needed."

                if ($WhatIf) {
                    $ErrorMessage = "User with email '{0}' cannot be found in the current workspace. No action needed!" -f $Object.Email
                    Write-warning $ErrorMessage
                    continue
                }       
            }
        }


        if ($UsernamesList) {

            # Build payload
            $Payload = [PSCustomObject]@{
                usernames = $UsernamesList
                
            } | ConvertTo-Json     
                       
            # Send delete request
            try {

                Invoke-HPEGLWebRequest -Uri $Uri -method 'DELETE' -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | out-Null
                
                if (-not $WhatIf) {
                    
                    foreach ($Object in $ObjectStatusList) {

                        $Username = $UsernamesList | Where-Object { $_ -eq $Object.email }

                        If ($Username) {

                            $Object.Status = "Complete"
                            $Object.Details = "User account successfully removed!"
                        }
                    }
                }
            }
            catch {
                
                if (-not $WhatIf) {

                    foreach ($Object in $ObjectStatusList) {

                        $Username = $UsernamesList | Where-Object { $_ -eq $Object.email }
                        
                        If ($Username) {

                            $Object.Status = "Failed"
                            $Object.Details = "User account removal failure!"
                            $Object.Exception = $_.Exception.message 
                            
                        }
                    }
                }
            }
        }


        if (-not $WhatIf) {

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "ObjStatus.ESDE" 
            Return $ObjectStatusList
        }


    }
}

Function Get-HPEGLRole {
    <#
    .SYNOPSIS
    View service roles.

    .DESCRIPTION
    This Cmdlet returns the service roles. Roles are groups of permissions that grant access to users.

    .PARAMETER ServiceName 
    Name of the service retrieved using 'Get-HPEGLService'.   
    
    .PARAMETER ArubaCentral 
    Optional parameter to display the roles of the Aruba Central service.

    .PARAMETER ComputeOpsManagement 
    Optional parameter to display the roles of the Compute Ops Management service.

    .PARAMETER DataServices 
    Optional parameter to display a specific role of the Data Services service.

    .PARAMETER HPEGreenLake 
    Optional parameter to display the roles of the HPE GreenLake service.

    .PARAMETER ArubaCentralRole 
    Optional parameter to display a specific role of the Aruba Central service.
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
        * Administrator
        * Observer
        * Operator

    .PARAMETER DataServicesRole 
    Optional parameter to display a specific role of the Data Services service.
    The predefined roles are as follows:
        * Administrator
        * Backup and Recovery Administrator
        * Backup and Recovery Operator
        * Data Ops Manager Administrator
        * Data Ops Manager Operator
        * Disaster Recovery Admin
        * Read only

    .PARAMETER HPEGreenLakeRole 
    Optional parameter to display a specific role of the HPE GreenLake service.
    The predefined roles are as follows:
        * Workspace Administrator
        * Workspace Observer
        * Workspace Operator
        * Orders Administrator
        * Orders Observer
        * Orders Operator

    .PARAMETER ShowAssignedUsers 
    The AssignedUsers directive returns the users assigned to the role name.

    .PARAMETER ShowPermissions
    The ShowPermissions directive returns the permissions of a role name.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Get-HPEGLRole 

    Return the service roles in an HPE GreenLake workspace.

    .EXAMPLE
    Get-HPEGLRole -ArubaCentral 

    Return the roles for the Aruba Central service instances in your HPE GreenLake workspace.

    .EXAMPLE
    Get-HPEGLRole -ServiceName "Data Services" 

    Return the roles for the Data Services service instances in your HPE GreenLake workspace.

    .EXAMPLE
    Get-HPEGLRole -ServiceName "Data Services" -ServiceRole "Disaster Recovery Admin"
    
    Return the "Disaster Recovery Admin" role information for the Data Services service.

    .EXAMPLE
    Get-HPEGLRole -ComputeOpsManagementRole Administrator 

    Return the Administrator role information for the Compute Ops Management service.
           
    .EXAMPLE
    Get-HPEGLRole -ComputeOpsManagementRole Administrator -ShowAssignedUsers 

    Return the users assigned to the Administrator role of the Compute Ops Management service.

    .EXAMPLE
    Get-HPEGLRole -DataServicesRole 'Backup and Recovery Administrator' -ShowPermissions

    Return the list of permissions for the 'Backup and Recovery Administrator' role of the Data Services service.

    .EXAMPLE
    Get-HPEGLRole -ServiceName "Compute Ops Management" -ServiceRole Administrator -ShowPermissions

    Return the list of permissions for the Administrator role of the Compute Ops Management service.

    
   #>
    [CmdletBinding(DefaultParameterSetName = 'ComputeOpsManagement')]
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
        [Switch]$ArubaCentral,

        [Parameter (ParameterSetName = 'ArubaCentralRole')]
        [Parameter (Mandatory, ParameterSetName = 'AssignedUsers-ArubaCentral')]
        [Parameter (Mandatory, ParameterSetName = 'Permissions-ArubaCentral')]
        [ValidateSet ('Aruba Central Administrator', 'Aruba Central Guest Operator', 'Aruba Central Operator', 'Aruba Central view edit role', 'Aruba Central View Only', 'Netlnsight Campus Admin', 'Netlnsight Campus Viewonly')]
        [String]$ArubaCentralRole,

        [Parameter (ParameterSetName = 'ComputeOpsManagement')]
        [Switch]$ComputeOpsManagement,

        [Parameter (ParameterSetName = 'ComputeOpsManagementRole')]
        [Parameter (Mandatory, ParameterSetName = 'AssignedUsers-ComputeOpsManagement')]
        [Parameter (Mandatory, ParameterSetName = 'Permissions-ComputeOpsManagement')]
        [ValidateSet ('Administrator', 'Observer', 'Operator')]
        [String]$ComputeOpsManagementRole,

        [Parameter (ParameterSetName = 'DataServices')]
        [Switch]$DataServices,

        [Parameter (ParameterSetName = 'DataServicesRole')]
        [Parameter (Mandatory, ParameterSetName = 'AssignedUsers-DataServicesCloudConsole')]
        [Parameter (Mandatory, ParameterSetName = 'Permissions-DataServicesCloudConsole')]
        [ValidateSet ('Administrator', 'Backup and Recovery Administrator', 'Backup and Recovery Operator', 'Data Ops Manager Administrator', 'Data Ops Manager Operator', 'Disaster Recovery Admin', 'Read only')]
        [String]$DataServicesRole,

        [Parameter (ParameterSetName = 'HPEGreenLake')]
        [Switch]$HPEGreenLake,

        [Parameter (ParameterSetName = 'HPEGreenLakeRole')]
        [Parameter (Mandatory, ParameterSetName = 'AssignedUsers-HPEGreenLake')]
        [Parameter (Mandatory, ParameterSetName = 'Permissions-HPEGreenLake')]
        [ValidateSet ('Workspace Administrator', 'Workspace Observer', 'Workspace Operator', 'Orders Administrator', 'Orders Observer', 'Orders Operator')]
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
                    "[{0}] Service'{1}' not found in the HPE GreenLake workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName | Write-Verbose
                    Return
                }
                else {

                    $Uri = Get-UsersRolesUri 

                    $ReturnData = @()
                    $PermissionsList = @()

        
                    try {
                        [array]$Collection = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }

                    if ($Null -ne $Collection.roles) {

                        $CollectionList = $Collection.roles | Where-Object application_name -eq $ServiceName       
                    
                        if ($ServiceRole) {
                    
                            $CollectionList = $CollectionList | Where-Object name -eq $ServiceRole
                        }

                        "[{0}] Roles for the service: '{1}' filtered to '{2}': '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $ServiceRole, ($CollectionList | Out-String) | Write-Verbose


                        # If role name not found, then return
                        if (-Not $CollectionList) {
                            Return
                        }

                        $Slug = $CollectionList.slug 
                        $ServiceID = $CollectionList.application_id

                        "[{0}] Permission + ServiceName -- Service Name: '{1}': Service ID: '{2}' - Role Name: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $ServiceID, $ServiceRole | Write-Verbose

    
                        # GET /ui-doorway/ui/v2/um/customers/roles/ccs.observer?application_id=00000000-0000-0000-0000-000000000000
                        $Uri = (Get-UsersRolesUri) + "/" + $Slug + "?application_id=" + $ServiceID

                        try {
                            [array]$Collection = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                        }
                        catch {
                            $PSCmdlet.ThrowTerminatingError($_)
                        }

                        if ($Null -ne $Collection.resource_policies) {

                            foreach ($ResourcePolicy in $Collection.resource_policies) {

                                if ($ResourcePolicy.resource.Name) {
                                    $ReturnData = $ResourcePolicy | Select-Object  @{N = "Application"; E = { $ServiceName } }, @{N = "Rolename"; E = { $ServiceRole } }, @{N = "Resource"; E = { $_.resource.name } }, @{N = "Permissions"; E = { $_.permissions.name } }
                                }
                                else {
                                    $ReturnData = $ResourcePolicy | Select-Object  @{N = "Application"; E = { $ServiceName } }, @{N = "Rolename"; E = { $ServiceRole } }, @{N = "Resource"; E = { $_.resource.matcher } }, @{N = "Permissions"; E = { $_.permissions.slug } }
                                }
                                $PermissionsList += $ReturnData 
                            }

                            $PermissionsList = $PermissionsList | Sort-Object application, rolename, resource
                            return $PermissionsList
                           
                        }

    
                                    
                    }
                    else {
                        return   
                    }

                } 

            }
        
            else {

                $Uri = Get-UsersRolesUri 

                $ReturnData = @()
                $PermissionsList = @()
        
                try {
                    [array]$Collection = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
                   
                if ($Null -ne $Collection.roles) {

                    if ($ComputeOpsManagementRole) {
                        $ServiceName = "Compute Ops Management"
                    }
                    elseif ($DataServicesRole) { 
                        $ServiceName = "Data Services" 
                    }
                    elseif ($ArubaCentralRole) { 
                        $ServiceName = "Aruba Central" 
                    }
                    elseif ($HPEGreenLakeRole) { 
                        $ServiceName = "HPE GreenLake platform"
                    }

                        
                    $CollectionList = $Collection.roles | Where-Object application_name -eq $ServiceName

                    "[{0}] Roles for the service: '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, ($CollectionList | Out-String) | Write-Verbose

                    if ($ArubaCentralRole) {
                        
                        $CollectionList = $CollectionList | Where-Object name -eq $ArubaCentralRole
                        $ServiceRole = $ArubaCentralRole
                    }
                    if ($ComputeOpsManagementRole) {
                        
                        $CollectionList = $CollectionList | Where-Object name -eq $ComputeOpsManagementRole
                        $ServiceRole = $ComputeOpsManagementRole

                    } 
                        
                    if ($DataServicesRole) {
                        
                        $CollectionList = $CollectionList | Where-Object name -eq $DataServicesRole
                        $ServiceRole = $DataServicesRole

                    }
                    if ($HPEGreenLakeRole) {
    
                        $CollectionList = $CollectionList | Where-Object name -eq $HPEGreenLakeRole
                        $ServiceRole = $HPEGreenLakeRole

                    }
                            
                    "[{0}] Roles for the service: '{1}' filtered to '{2}': '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $ServiceRole, ($CollectionList | Out-String) | Write-Verbose

                    
                    # If role name not found, then return
                    if (-Not $CollectionList) {
                        Return
                    }

                    $Slug = $CollectionList.slug 
                    $ServiceID = $CollectionList.application_id 

                    "[{0}] Permission + Predefined Role -- Service Name: '{1}': Service ID: '{2}' - Role Name: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $ServiceID, $ServiceRole | Write-Verbose

    
                    # GET /ui-doorway/ui/v1/um/customers/roles/ccs.observer?application_id=00000000-0000-0000-0000-000000000000
                    $Uri = (Get-UsersRolesUri) + "/" + $Slug + "?application_id=" + $ServiceID

                    try {
                        [array]$Collection = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }

                    if ($Null -ne $Collection.resource_policies) {

                        foreach ($ResourcePolicy in $Collection.resource_policies) {

                            if ($ResourcePolicy.resource.Name) {
                                $ReturnData = $ResourcePolicy | Select-Object  @{N = "Application"; E = { $ServiceName } }, @{N = "Rolename"; E = { $ServiceRole } }, @{N = "Resource"; E = { $_.resource.name } }, @{N = "Permissions"; E = { $_.permissions.name } }
                            }
                            else {
                                $ReturnData = $ResourcePolicy | Select-Object  @{N = "Application"; E = { $ServiceName } }, @{N = "Rolename"; E = { $ServiceRole } }, @{N = "Resource"; E = { $_.resource.matcher } }, @{N = "Permissions"; E = { $_.permissions.slug } }
                            }
                            $PermissionsList += $ReturnData 
                        }

                        $PermissionsList = $PermissionsList | Sort-Object application, rolename, resource
                        return $PermissionsList
                           
                    }

    
                                    
                }
                else {
                    return   
                }
            }

        }
        else {

            $Uri = Get-UsersRolesUri

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

                    if ($Null -ne $Collection.roles) {

                        $CollectionList = $Collection.roles | Where-Object application_name -eq $ServiceName   
                        
                                            
                        if ($ServiceRole) {
                    
                            $CollectionList = $CollectionList | Where-Object name -eq $ServiceRole
   
                            "[{0}] Roles for the service: '{1}' filtered to '{2}': '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $ServiceRole, ($CollectionList | Out-String) | Write-Verbose

                        }
                                  
                        if ($ShowAssignedUsers) {

                            $ServiceID = $CollectionList.application_id
                            $Slug = $CollectionList.slug
    
                            $Uri = (Get-AuthzRolesUri) + $Global:HPEGreenLakeSession.workspaceId + "/applications/" + $ServiceID + "/roles/" + $Slug + "/user_assignments"
    
                            try {
                                [array]$UserCollection = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                            }
                            catch {
                                $PSCmdlet.ThrowTerminatingError($_)
                            }

                            "[{0}] AssignedUsers to roles for the service: '{1}' filtered to '{2}': '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $ServiceRole, ($CollectionList | Out-String) | Write-Verbose


                            if ($Null -ne $UserCollection.users) {
            
                                $ReturnData = Invoke-RepackageObjectWithType -RawObject $UserCollection.users -ObjectName "User.Role.Assigned.Users"    
                                $ReturnData = $UserCollection.users | Sort-Object { $_.email }

                                return $ReturnData 

                                        
                            }
                            else {
                                return   
                            }
                        }

            
                        $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "Role"    

                        $ReturnData = $ReturnData | Sort-Object { $_.application_name, $_.name }

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
        
   
                if ($Null -ne $Collection.roles) {

                    $CollectionList = $Collection.roles 

                    if ($ComputeOpsManagement) {
                        $ServiceName = "Compute Ops Management"
                    }
                    elseif ($DataServices) { 
                        $ServiceName = "Data Services" 
                    }
                    elseif ($ArubaCentral) { 
                        $ServiceName = "Aruba Central" 
                    }
                    elseif ($HPEGreenLake) { 
                        # $Service = "Common Cloud Service" 
                        $ServiceName = "HPE GreenLake platform"

                    }


                    if ($ComputeOpsManagementRole) {
                        $ServiceName = "Compute Ops Management"
                        $ServiceRole = $ComputeOpsManagementRole

                    }
                    elseif ($DataServicesRole) { 
                        $ServiceName = "Data Services" 
                        $ServiceRole = $DataServicesRole

                    }
                    elseif ($ArubaCentralRole) { 
                        $ServiceName = "Aruba Central" 
                        $ServiceRole = $ArubaCentralRole

                    }
                    elseif ($HPEGreenLakeRole) { 
                        $ServiceName = "HPE GreenLake platform"
                        $ServiceRole = $HPEGreenLakeRole

                    }


                    if ($ServiceName) {

                        $CollectionList = $CollectionList | Where-Object application_name -eq $ServiceName

                        if ($ArubaCentralRole) {
                    
                            $CollectionList = $CollectionList | Where-Object name -eq $ArubaCentralRole
                        }
                        if ($ComputeOpsManagementRole) {
                    
                            $CollectionList = $CollectionList | Where-Object name -eq $ComputeOpsManagementRole
                        } 
                    
                        if ($DataServicesRole) {
                    
                            $CollectionList = $CollectionList | Where-Object name -eq $DataServicesRole
                        }
                        if ($HPEGreenLakeRole) {

                            $CollectionList = $CollectionList | Where-Object name -eq $HPEGreenLakeRole
                        }

                        "[{0}] Roles for the service: '{1}' filtered to '{2}': '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $ServiceRole, ($CollectionList | Out-String) | Write-Verbose

                        
                    }
                     
                    if ($ShowAssignedUsers) {

                        $ServiceID = $CollectionList.application_id
                        $Slug = $CollectionList.slug
    
                        $Uri = (Get-AuthzRolesUri) + $Global:HPEGreenLakeSession.workspaceId + "/applications/" + $ServiceID + "/roles/" + $Slug + "/user_assignments"
    
                        try {
                            [array]$UserCollection = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                        }
                        catch {
                            $PSCmdlet.ThrowTerminatingError($_)
                        }

                        "[{0}] AssignedUsers + Predefined Role -- Service Name: '{1}': Service ID: '{2}' - Role Name: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $ServiceID, $ServiceRole | Write-Verbose


                        if ($Null -ne $UserCollection.users) {
            
                            $ReturnData = Invoke-RepackageObjectWithType -RawObject $UserCollection.users -ObjectName "User.Role.Assigned.Users"    
                            $ReturnData = $UserCollection.users | Sort-Object { $_.email }

                            return $ReturnData 

                                        
                        }
                        else {
                            return   
                        }
                    }

            
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "Role"    

                    $ReturnData = $ReturnData | Sort-Object { $_.application_name, $_.name }

                    return $ReturnData 
                }
                else {

                    return
            
                }
            }
        }
    }
}

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

        $Uri = (Get-AuthzUsersRolesAssignmentsUri) + $Global:HPEGreenLakeSession.workspaceId + "/users/" + $Email.ToLower() + "/role_assignments"

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

        $ReturnData = @()
        
        try {
            [array]$Collection = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
     
        
        if ($Null -ne $Collection.roles) {
            
            $PermissionsList = @()
            
            if ($ServiceName) {
                
                try {
                    
                    $App = Get-HPEGLService -Name $ServiceName | sort-object application_id -Unique 
                    
                    "[{0}] Service '{1}' found: `n{2}!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName, $App | Write-Verbose

                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
                                    
                if (-not $App -and $ServiceName -ne "HPE GreenLake platform") {
                    "[{0}] Service '{1}' not found in the HPE GreenLake workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName | Write-Verbose
                    Throw "Error! Service name not found!"
                }

                if ($ServiceName -eq "HPE GreenLake platform") {

                    $ServiceID = "00000000-0000-0000-0000-000000000000"

                }
                else {
                    $ServiceID = $App.application_id

                }

                $UserRoles = $Collection.roles | Where-Object application_id -eq $ServiceID

                
            }
            else {
                $userRoles = $Collection.roles

            } 
            

            foreach ($UserRole in $UserRoles) {

                $UserFirstName = $Collection | ForEach-Object user_first_name
                $UserLastName = $Collection | ForEach-Object user_last_name
                $UserType = $Collection | ForEach-Object user_type

                $RoleName = $UserRole | ForEach-Object role_name
                $AppName = $UserRole | ForEach-Object application_name

                $AppID = $UserRole | ForEach-Object application_id
             
                $Slug = $UserRole | ForEach-Object slug
                    
                
                if ($ShowPermissions) {

                    "[{0}] Permission -- Service Name: '{1}': Service ID: '{2}' - Role Name: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $AppName, $AppID, $RoleName | Write-Verbose
                   
                    try {
              
                        $ResourcePolicies = Get-HPEGLRole -ServiceName $AppName -ServiceRole $RoleName -ShowPermissions
              
                        $PermissionsList += $ResourcePolicies 

                        "[{0}] Resource Policies: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ResourcePolicies | Out-String) | Write-Verbose
                                          
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }

                }
                else {

                    if ($UserRole.resource_restriction_policies) {
                            
                        "[{0}] Resource Restriction policies found!" -f $MyInvocation.InvocationName.ToString().ToUpper() | write-Verbose
                                                       
                        if ($UserRole.resource_restriction_policies.name -eq "Allscopes") {
                            $RRPName = "Full Access"

                        }
                        elseif (-not $UserRole.resource_restriction_policies.name ) {
                            $RRPName = "None"

                        }
                        else {
                            $RRPName = $UserRole.resource_restriction_policies.name 

                        }

                        $RRPDescription = $UserRole.resource_restriction_policies.description 
                        $ResourceRestrictionPolicyId = $UserRole.resource_restriction_policies.resource_restriction_policy_id
                          

                        $ReturnData = $UserRole | Select-Object `
                        @{N = "email"; E = { $Email } }, `
                        @{N = "user_first_name"; E = { $UserFirstName } }, `
                        @{N = "user_last_name"; E = { $UserLastName } }, `
                        @{N = "user_type"; E = { $UserType } }, `
                        @{N = "application_name"; E = { $AppName } }, `
                        @{N = "application_id"; E = { $AppID } }, `
                        @{N = "resource_restriction_policy_description"; E = { $RRPDescription } }, `
                        @{N = "resource_restriction_policy_id"; E = { $ResourceRestrictionPolicyId } }, `
                        @{N = "role"; E = { $Rolename } }, `
                        @{N = "resource_restriction_policy"; E = { $RRPName } }, `
                        @{N = "slug"; E = { $Slug } }

                        $PermissionsList += $ReturnData 
                            
                    }
                    else {

                        $RRPName = "None"
              
                        $ReturnData = $UserRole | Select-Object `
                        @{N = "email"; E = { $Email } }, `
                        @{N = "user_first_name"; E = { $UserFirstName } }, `
                        @{N = "user_last_name"; E = { $UserLastName } }, `
                        @{N = "user_type"; E = { $UserType } }, `
                        @{N = "application_name"; E = { $AppName } }, `
                        @{N = "application_id"; E = { $AppID } }, `
                        @{N = "resource_restriction_policy_description"; E = { $Null } }, `
                        @{N = "resource_restriction_policy_id"; E = { $Null } }, `
                        @{N = "role"; E = { $Rolename } }, `
                        @{N = "resource_restriction_policy"; E = { $RRPName } }, `
                        @{N = "slug"; E = { $Slug } }

                        $PermissionsList += $ReturnData 

                    }
                }
            }

            if (-not $ShowPermissions) {
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $PermissionsList -ObjectName "User.Role"         
                $ReturnData = $ReturnData | sort-object application_name, role

            }
            else {
                
                $ReturnData = $PermissionsList

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
    Assign a role to a user.

    .DESCRIPTION
    This cmdlet assigns roles and permissions to a user in an HPE GreenLake workspace. Roles are collections of permissions that grant users access to various HPE GreenLake services.

    Roles are assigned to a service across all regions. To further restrict the scope of resources a user role can access, you can use the resource restriction policy feature with 'Set-HPEGLResourceRestrictionPolicy'.

    .PARAMETER Email 
    Email address of the user for whom you want to set roles and permissions (can be retrieved using 'Get-HPEGLUser').

    .PARAMETER ArubaCentralRole 
    Name of the Aruba Central role to add to the user's roles. 
    The predefined roles are as follows:
    - Aruba Central Administrator  
    - Aruba Central Guest Operator
    - Aruba Central Operator
    - Aruba Central View Edit Role
    - Aruba Central View Only
    - Netlnsight Campus Admin
    - Netlnsight Campus Viewonly

    .PARAMETER ComputeOpsManagementRole 
    Name of the Compute Ops Management role to add to the user's roles. 
    The predefined roles are as follows:
    - Administrator
    - Observer
    - Operator

    .PARAMETER DataServicesRole 
    Name of the Data Services role to add to the user's roles. 
    The predefined roles are as follows:
    - Administrator
    - Backup and Recovery Administrator
    - Backup and Recovery Operator
    - Data Ops Manager Administrator
    - Data Ops Manager Operator
    - Disaster Recovery Admin
    - Read Only

    .PARAMETER HPEGreenLakeRole 
    Name of the HPE GreenLake role to add to the user's roles. 
    The predefined roles are as follows:
    - Workspace Administrator
    - Workspace Observer
    - Workspace Operator
    - Orders Administrator
    - Orders Observer
    - Orders Operator

    .PARAMETER ServiceName 
    Name of the service to which the role name will be assigned (can be retrieved using 'Get-HPEGLRole').   
        
    .PARAMETER RoleName 
    Name of the role of a service to be assigned to the user (can be retrieved using 'Get-HPEGLRole').   

    .PARAMETER ResourceRestrictionPolicyName 
    Specifies the name of a resource restriction policy to further limit the scope of resources accessible by the user (can be retrieved using 'Get-HPEGLResourceRestrictionPolicy').

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Add-HPEGLRoleToUser -Email richardfeynman@quantummechanics.lab -ComputeOpsManagementRole Observer 

    Adds the Observer role to richardfeynman@quantummechanics.lab for the "Compute Ops Management" service.

    .EXAMPLE
    Add-HPEGLRoleToUser -Email richardfeynman@quantummechanics.lab -ServiceName "Data Services" -RoleName "Backup and Recovery Administrator"

    Adds the Backup and Recovery Administrator role to richardfeynman@quantummechanics.lab for the "Data Services" service.

    .EXAMPLE
    "richardfeynman@quantummechanics.lab", "alexandreliapounov@math.edu" | Add-HPEGLRoleToUser -ComputeOpsManagementRole Administrator 

    Adds the Administrator role to richardfeynman@quantummechanics.lab and alexandreliapounov@math.edu for the "Compute Ops Management" service.

    .EXAMPLE
    $AdministratorUserEmails = @("richardfeynman@quantummechanics.lab","alexandreliapounov@math.edu")
    $AdministratorUserEmails | Add-HPEGLRoleToUser -ComputeOpsManagementRole Administrator

    Adds the Administrator role to the users in the $AdministratorUserEmails array for the "Compute Ops Management" service.

    .EXAMPLE
    Get-HPEGLUser | Where-Object email -match "quantummechanics" | Add-HPEGLRoleToUser -ArubaCentralRole 'Aruba Central Administrator'

    Adds the Aruba Central Administrator role to all users whose email addresses contain the string 'quantummechanics'.

    .EXAMPLE
    Add-HPEGLRoleToUser -Email alexandreliapounov@math.edu -ComputeOpsManagementRole 'Administrator' -ResourceRestrictionPolicyName 'RRP_COM-Location-Texas'

    Adds the Administrator role to alexandreliapounov@math.edu for the "Compute Ops Management" service, limiting the scope of accessible resources to the Texas location using the resource restriction policy named 'RRP_COM-Location-Texas'.
      
    .INPUTS
    System.Collections.ArrayList
        List of users from 'Get-HPEGLUser'.        
    System.String, System.String[]
        A single string object or a list of string objects that represent the email addresses.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        - Email: Email of the user 
        - Role: Name of the role to add 
        - Service: Name of the service 
        - ResourceRestrictionPolicyName: Name of the resource restriction policy to assign
        - Status: Status of the role assignment attempt (Failed for HTTP error return; Complete if successful; Warning if no action is needed) 
        - Details: More information about the status 
        - Exception: Information about any exceptions generated during the operation.
    #>


    [CmdletBinding(DefaultParameterSetName = 'ComputeOpsManagement')]
    Param( 

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName , ParameterSetName = 'ArubaCentral')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName , ParameterSetName = 'HPEGreenLake')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName , ParameterSetName = 'ComputeOpsManagement')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName , ParameterSetName = 'DataServices')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName , ParameterSetName = 'Other')]
        [validatescript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$Email,
       
        [Parameter (Mandatory, ParameterSetName = 'ArubaCentral')]
        [ValidateSet ('Aruba Central Administrator', 'Aruba Central Guest Operator', 'Aruba Central Operator', 'Aruba Central view edit role', 'Aruba Central View Only', 'Netlnsight Campus Admin', 'Netlnsight Campus Viewonly')]
        [String]$ArubaCentralRole,

        [Parameter (Mandatory, ParameterSetName = 'HPEGreenLake')]
        [ValidateSet ('Workspace Administrator', 'Workspace Observer', 'Workspace Operator', 'Orders Administrator', 'Orders Observer', 'Orders Operator')]
        [String]$HPEGreenLakeRole,

        [Parameter (Mandatory, ParameterSetName = 'ComputeOpsManagement')]
        [ValidateSet ('Administrator', 'Observer', 'Operator')]
        [String]$ComputeOpsManagementRole,

        [Parameter (Mandatory, ParameterSetName = 'DataServices')]
        [ValidateSet ('Administrator', 'Backup and Recovery Administrator', 'Backup and Recovery Operator', 'Data Ops Manager Administrator', 'Data Ops Manager Operator', 'Disaster Recovery Admin', 'Read only')]
        [String]$DataServicesRole,

        [Parameter (Mandatory, ParameterSetName = 'Other')]
        [String]$ServiceName,

        [Parameter (Mandatory, ParameterSetName = 'Other')]
        [String]$RoleName,

        [Parameter (ParameterSetName = 'ArubaCentral')]
        [Parameter (ParameterSetName = 'HPEGreenLake')]
        [Parameter (ParameterSetName = 'ComputeOpsManagement')]
        [Parameter (ParameterSetName = 'DataServices')]
        [Parameter (ParameterSetName = 'Other')]
        [String]$ResourceRestrictionPolicyName,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        
        $UserRoleAssignmentStatus = [System.Collections.ArrayList]::new()
        
        
    }
    
    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        $Uri = (Get-AuthzUsersRolesUri) + $Email.ToLower() + "/roles"

        # Test if user present
        try {
            $User = (Get-HPEGLUser).contact | Where-Object email -eq $Email
           
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }


        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Email                         = $Email
            Role                          = $Null
            Service                       = $Null
            ResourceRestrictionPolicyName = $Null
            Status                        = $Null
            Details                       = $Null
            Exception                     = $Null
                  
        }
        
        if (-not $User) {
            # Must return a message if user not found
            "[{0}] User '{1}' not found." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email | Write-Verbose

            if ($Whatif) {
                $ErrorMessage = "User '{0}': Resource cannot be found in the workspace!" -f $Email
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "User cannot be found in the workspace!"
                $objStatus.Service = $ServiceName
                    
            }

            
        }
        
        ############## If RoleName / ServiceName ##############
        elseif ($RoleName) {

            $objStatus.Role = $RoleName
            $objStatus.Service = $ServiceName

            try {
                $Service = Get-HPEGLService -ShowProvisioned -Name $ServiceName | sort-object -Property application_id  -Unique

                $ServiceID = $Service.application_id
                
            }
            catch {    
                $PSCmdlet.ThrowTerminatingError($_)

            }

            # If ServiceName not found except if GreenLake service
            if (-not $Service -and $ServiceName -ne "HPE GreenLake platform") {
                # Must return a message if Service is not provisioned in the region
                "[{0}] Service '{1}' not provisioned in a region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName | Write-Verbose
    
                if ($Whatif) {
                    $ErrorMessage = "Service '{0}': Resource is not provisioned in any region!" -f $ServiceName
                    Write-warning $ErrorMessage
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Service not provisioned in any region!"
                    $objStatus.Service = $ServiceName
                               
                }

    
            }

            # If ServiceName 
            else {

                # Role already assigned?                       
                try {

                    $AppRoles = Get-HPEGLRole -ServiceName $ServiceName 
                    $AppRole = $AppRoles | Where-Object name -eq $RoleName
                    $Slug = $AppRole.slug
                              
                    "[{0}] role '{1}' found for '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Rolename, $ServiceName | Write-Verbose
                    "[{0}] Slug = '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Slug | write-verbose

                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }

                # If service role found
                if ( $AppRole) {
                    
                    try {

                        $ExistingUserRoles = Get-HPEGLUserRole -Email $email

                        $ServiceNameUserRoles = $ExistingUserRoles | Where-Object application_name -eq $ServiceName

                        $Rolefound = $ServiceNameUserRoles | Where-Object role -eq $RoleName

                        # Check if RRP name already assigned to the role
                        $RRPAlreadyAssigned = $Rolefound.resource_restriction_policy


                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }


                    # Role found without RRP parameter = ERROR
                    if ($Rolefound -and -not $ResourceRestrictionPolicyName) {

                        # Must return a message if Rolename is already assigned
                        "[{0}] Role name '{1}' is already assigned to this user!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName | Write-Verbose
    
                        if ($Whatif) {
                            $ErrorMessage = "Service role '{0}': Resource is already assigned to this user!" -f $RoleName
                            Write-warning $ErrorMessage
                            return
                        }
                        else {
                            $objStatus.Status = "Warning"
                            $objStatus.Details = "Service role name is already assigned to this user!"
                            
                        }                      

                    }

                    
                    # Role found with RRP parameter = MODIFICATION
                    elseif ($Rolefound -and $ResourceRestrictionPolicyName) {

                        $objStatus.ResourceRestrictionPolicyName = $ResourceRestrictionPolicyName

                        try {
                            $Service = Get-HPEGLService -ShowProvisioned -Name $ServiceName | sort-object -Property application_id  -Unique
        
                        }
                        catch {    
                            $PSCmdlet.ThrowTerminatingError($_)

                        }


                        # Check if RRP is available
                        try {
                            $RRP = Get-HPEGLResourceRestrictionPolicy -Name $ResourceRestrictionPolicyName
                        }
                        catch {
                            $PSCmdlet.ThrowTerminatingError($_)
                        }

                        if ($RRP) {
                   
                            $ResourceRestrictionPolicyIDToSet = $RRP.resource_restriction_policy_id

                            # If RRP name not already assigned to the role: Overwrite needed !
                            if ( $RRPAlreadyAssigned -ne $ResourceRestrictionPolicyName) {

                                $RolesList = [System.Collections.ArrayList]::new()
                
                                foreach ($ExistingUserRole in $ExistingUserRoles) {
                 
                                    $Slug = $ExistingUserRole.slug
                                    $ServiceID = $ExistingUserRole.application_id
                 
                                    # If ExistingUserRole is not the one we want to modify with new RRP, we capture existing RRP
                                    if ($ExistingUserRole.resource_restriction_policy) {

                                        $ResourceRestrictionPolicyID = $ExistingUserRole.resource_restriction_policy_id

                                        # If ExistingUserRole is the one we want to modify with new RRP
                                        if ($ExistingUserRole.application_name -eq $ServiceName -and $ExistingUserRole.role -eq $RoleName) {
                        
                                            $ResourceRestrictionPolicyID = $ResourceRestrictionPolicyIDToSet
                      
                                        }
                        
                                        $Role = [PSCustomObject]@{
                                            role                          = @{  
                                                slug           = $Slug
                                                application_id = $ServiceID
                                            }
                                            resource_restriction_policies = @(
                                                $ResourceRestrictionPolicyID
                                            )
                                        }

                                    }
                                    else {                                
                  
                                        $Role = [PSCustomObject]@{
                                            role                          = @{  
                                                slug           = $Slug
                                                application_id = $ServiceID
                                            }
                                            resource_restriction_policies = @( )
                                        }
                                    }

                                    $RolesList += $Role

                                }
                

                                # Build payload
                                $Payload = [PSCustomObject]@{ overwrite = @( 
                                        $RolesList
                                    )
                                } | ConvertTo-Json -Depth 5
                

                                # Set user role with RRP      
                                try {
                                    Invoke-HPEGLWebRequest -Method 'PUT' -Body $Payload -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | Out-Null

                                    if (-not $WhatIf) {

                                        "[{0}] Role '{1}' with resource restriction policy '{2}' successfully set for '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName, $ResourceRestrictionPolicyName, $Email | Write-Verbose

                                        $objStatus.Status = "Complete"
                                        $objStatus.Details = "Resource restriction policy successfully set!"
                                        $objStatus.Service = $ServiceName

                                    }

                                }
                                catch {
                                    if (-not $WhatIf) {
                                        $objStatus.Status = "Failed"
                                        $objStatus.Details = "Resource restriction policy cannot be set!"
                                        $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                                        $objStatus.Service = $ServiceName
                                    }
                                }

                            }
                            # If RRP name already assigned to the role
                            else {
                                # Must return a message if RRP name is already assigned to the role
                                "[{0}] Resource restriction policy name '{1}' is already assigned to this role!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ResourceRestrictionPolicyName | Write-Verbose

                                if ($Whatif) {
                                    $ErrorMessage = "Resource restriction policy '{0}' is already assigned to this role!" -f $ResourceRestrictionPolicyName
                                    Write-warning $ErrorMessage
                                    return
                                }
                                else {
                                    $objStatus.Status = "Warning"
                                    $objStatus.Details = "Resource restriction policy name is already assigned to this role!"
                                    
                                }

                            }
                        }
                        else {
                            # Must return a message if RRP name is not found in the region
                            "[{0}] Resource restriction policy name '{1}' cannot be found in this region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ResourceRestrictionPolicyName | Write-Verbose

                            if ($Whatif) {
                                $ErrorMessage = "Resource restriction policy '{0}' cannot be found in this region!" -f $ResourceRestrictionPolicyName
                                Write-warning $ErrorMessage
                                return
                            }
                            else {
                                $objStatus.Status = "Failed"
                                $objStatus.Details = "Resource restriction policy name cannot be found in this region!"
                                
                            }
         
                        } 
                    }

                    # Role not found without RRP parameter = CREATION
                    # Role not found with RRP parameter = CREATION
                    elseif (-not $Rolefound) {    

                        $objStatus.ResourceRestrictionPolicyName = $ResourceRestrictionPolicyName

                        if ($ServiceName -eq "HPE GreenLake platform") {
                            $ServiceID = "00000000-0000-0000-0000-000000000000"
                        }
                        else {
                            $ServiceID = $Service.application_id
                        }

                        # If not RRP
                        if (-Not $ResourceRestrictionPolicyName) {

                            # Build payload
                            $Payload = [PSCustomObject]@{ add = @( 
                                    @{ 
                                        role                          = @{  
                                            slug           = $Slug
                                            application_id = $ServiceID
                                        }
                                        resource_restriction_policies = $Null
                                    
                                    }
    
                                )
                            } | ConvertTo-Json -Depth 5

                            # Set user roles without RRP       
                            try { 
                                Invoke-HPEGLWebRequest -Method 'PUT' -Body $Payload -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | Out-Null 
                                
                                if (-not $WhatIf) {

                                    "[{0}] Role '{1}' successfully assigned to user '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Role, $Email | Write-Verbose

                                    $objStatus.Status = "Complete"
                                    $objStatus.Details = "Role successfully assigned!"
                                    $objStatus.Service = $ServiceName

                                }
                            }
                            catch {
                                if (-not $WhatIf) {
                                    $objStatus.Status = "Failed"
                                    $objStatus.Details = "Role cannot be assigned to user!"
                                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                                    $objStatus.Service = $ServiceName
                                }
                            }

                        }
                        # If RRP
                        else {

                            $objStatus.ResourceRestrictionPolicyName = $ResourceRestrictionPolicyName

                            # Check if RRP is available

                            try {
                                $RRP = Get-HPEGLResourceRestrictionPolicy -Name $ResourceRestrictionPolicyName
                            }
                            catch {
                                $PSCmdlet.ThrowTerminatingError($_)
                            }
                            # If RRP name found
                            if ($RRP) {
                               
                                $ResourceRestrictionPolicyID = $RRP.resource_restriction_policy_id

                                # Check if RRP name already assigned to the role

                                try {
                                    $RRPAlreadyAssigned = ($ServiceNameUserRoles | Where-Object role -eq $RoleName).resource_restriction_policy
                                }
                                catch {
                                    $PSCmdlet.ThrowTerminatingError($_)
                                }


                                if ( $RRPAlreadyAssigned -ne $ResourceRestrictionPolicyName) {

                                    # Build payload
                                    $Payload = [PSCustomObject]@{ add = @( 
                                            @{ 
                                                role                          = @{  
                                                    slug           = $Slug
                                                    application_id = $ServiceID
                                                }
                                                resource_restriction_policies = @(
                                                    $ResourceRestrictionPolicyID
                                                )
                                            }
        
                                        )
                                    } | ConvertTo-Json -Depth 5
                        
                                    # Set user roles with RRP    
                                    try { 
                                        Invoke-HPEGLWebRequest -Method 'PUT' -Body $Payload -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | Out-Null 
                                    
                                        if (-not $WhatIf) {

                                            "[{0}] Role '{1}' successfully assigned to user '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Role, $Email | Write-Verbose

                                            $objStatus.Status = "Complete"
                                            $objStatus.Details = "Role successfully assigned!"
                                            $objStatus.Service = $ServiceName

                                        }
                                    }
                                    catch {
                                        if (-not $WhatIf) {
                                            $objStatus.Status = "Failed"
                                            $objStatus.Details = "Role cannot be assigned to user!"
                                            $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                                            $objStatus.Service = $ServiceName
                                        }
                                    }
                                }
                                else {
                                    # Must return a message if RRP name is already assigned to the role
                                    "[{0}] Resource restriction policy name '{1}' is already assigned to this role!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ResourceRestrictionPolicyName | Write-Verbose

                                    if ($Whatif) {
                                        $ErrorMessage = "Resource restriction policy '{0}' is already assigned to this role!" -f $ResourceRestrictionPolicyName
                                        Write-warning $ErrorMessage
                                        return
                                    }
                                    else {
                                        $objStatus.Status = "Warning"
                                        $objStatus.Details = "Resource restriction policy name is already assigned to this role!"
                                        
                                    }

                
                                }
                            
                            }
                            # If not RRP name not found
                            else {
                                # Must return a message if RRP name is not found in the region
                                "[{0}] Resource restriction policy nam '{1}' cannot be found in this region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ResourceRestrictionPolicyName | Write-Verbose
    
                                if ($Whatif) {
                                    $ErrorMessage = "Resource restriction policy '{0}' cannot be found in this region!" -f $ResourceRestrictionPolicyName
                                    Write-warning $ErrorMessage
                                    return
                                }
                                else {
                                    $objStatus.Status = "Failed"
                                    $objStatus.Details = "Resource restriction policy name cannot be found in this region!"
                                    
                                }

                              
                            }
                        }
                    }
                }
                # If role not found
                else {
                    # Must return a message if Rolename is not found
                    "[{0}] Role name '{1}' cannot be found for service '{2}'!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName, $ServiceName | Write-Verbose
    
                    if ($Whatif) {
                        $ErrorMessage = "Role '{0}' cannot be found for service '{1}'!" -f $RoleName, $ServiceName
                        Write-warning $ErrorMessage
                        return
                    }
                    else {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Role name cannot be found for this service!"
                        $objStatus.Service = $ServiceName
                        
                    }

                }            
            }
            
        }

        ############## If Predefined roles (i.e. -ComputeOpsManagementRole, etc.) ##############
        else {

            try {
                $ExistingUserRoles = Get-HPEGLUserRole -Email $email
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }


            # Role already assigned?
            if ($MyInvocation.BoundParameters["ArubaCentralRole"] ) {
            
                $ServiceName = "Aruba Central"
                $Rolename = $ArubaCentralRole
            
            }
            elseif ($MyInvocation.BoundParameters["HPEGreenLakeRole"] ) {
            
                $ServiceName = "HPE GreenLake platform"
                $Rolename = $HPEGreenLakeRole
            
            }
            elseif ($MyInvocation.BoundParameters["ComputeOpsManagementRole"] ) {

                $ServiceName = "Compute Ops Management"
                $Rolename = $ComputeOpsManagementRole
            
            }
            elseif ($MyInvocation.BoundParameters["DataServicesRole"] ) {
            
                $ServiceName = "Data Services"
                $Rolename = $DataServicesRole

            }

            $ServiceNameUserRoles = $ExistingUserRoles | Where-Object application_name -eq $ServiceName
            $Rolefound = $ServiceNameUserRoles | Where-Object role -eq $RoleName

            $objStatus.Role = $Rolename
            $objStatus.Service = $ServiceName
        
            # Role found without RRP parameter = ERROR
            if ($Rolefound -and -not $ResourceRestrictionPolicyName) {
        
                # Must return a message if Rolename is already assigned
                "[{0}] Role name '{1}' is already assigned to this user!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName | Write-Verbose
        
                if ($Whatif) {
                    $ErrorMessage = "Service role '{0}' is already assigned to this user!" -f $RoleName
                    Write-warning $ErrorMessage
                    return
                }
                else {
                    $objStatus.Status = "Warning"
                    $objStatus.Details = "Service role name is already assigned to this user!"
                    $objStatus.Service = $ServiceName
                    
                }


            }

            # Role found with RRP parameter = MODIFICATION
            elseif ($Rolefound -and $ResourceRestrictionPolicyName) {

                $objStatus.ResourceRestrictionPolicyName = $ResourceRestrictionPolicyName

                # Get slug
                try {
                    $Slug = (Get-HPEGLRole -ServiceName $ServiceName -ServiceRole $RoleName).slug
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }

                "[{0}] Slug = '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Slug | write-verbose
                

                try {
                    $Service = Get-HPEGLService -ShowProvisioned -Name $ServiceName | sort-object -Property application_id  -Unique

                    $ServiceID = $Service.application_id

                    
                }
                catch {    
                    $PSCmdlet.ThrowTerminatingError($_)
    
                }

                if (-not $Service) {
                    # Must return a message if Service is not provisioned in the region
                    "[{0}] Service '{1}' not provisioned in a region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName | Write-Verbose
        
                    if ($Whatif) {
                        $ErrorMessage = "Service '{0}' is not provisioned in a region!" -f $ServiceName
                        Write-warning $ErrorMessage
                        return
                    }
                    else {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Service not provisioned in a region!"
                        $objStatus.Service = $ServiceName
                        
                    }

        
                }
                else {

                    # Check if RRP is available

                    try {
                        $RRP = Get-HPEGLResourceRestrictionPolicy -Name $ResourceRestrictionPolicyName
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }

                    if ($RRP) {
                               
                        $ResourceRestrictionPolicyIDToSet = $RRP.resource_restriction_policy_id

                        # Check if RRP name already assigned to the role
                        $RRPAlreadyAssigned = $Rolefound.resource_restriction_policy

                        # If RRP name not already assigned to the role: Overwrite needed !
                        if ( $RRPAlreadyAssigned -ne $ResourceRestrictionPolicyName) {

                            $RolesList = [System.Collections.ArrayList]::new()
                            
                            foreach ($ExistingUserRole in $ExistingUserRoles) {
                             
                                $Slug = $ExistingUserRole.slug
                                $ServiceID = $ExistingUserRole.application_id
                             
                                # If ExistingUserRole is not the one we want to modify with new RRP, we capture existing RRP
                                if ($ExistingUserRole.resource_restriction_policy) {

                                    $ResourceRestrictionPolicyID = $ExistingUserRole.resource_restriction_policy_id

                                    # If ExistingUserRole is the one we want to modify with new RRP
                                    if ($ExistingUserRole.application_name -eq $ServiceName -and $ExistingUserRole.role -eq $RoleName) {
                                    
                                        $ResourceRestrictionPolicyID = $ResourceRestrictionPolicyIDToSet
                                  
                                    }
                                    
                                    $Role = [PSCustomObject]@{
                                        role                          = @{  
                                            slug           = $Slug
                                            application_id = $ServiceID
                                        }
                                        resource_restriction_policies = @(
                                            $ResourceRestrictionPolicyID
                                        )
                                    }

                                }
                                else {                                
                              
                                    $Role = [PSCustomObject]@{
                                        role                          = @{  
                                            slug           = $Slug
                                            application_id = $ServiceID
                                        }
                                        resource_restriction_policies = @( )
                                    }
                                }

                                $RolesList += $Role

                            }
                            

                            # Build payload
                            $Payload = [PSCustomObject]@{ overwrite = @( 
                                    $RolesList
                                )
                            } | ConvertTo-Json -Depth 5
                            

                            # Set user role with RRP      
                            try {
                                Invoke-HPEGLWebRequest -Method 'PUT' -Body $Payload -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | Out-Null

                                if (-not $WhatIf) {

                                    "[{0}] Role '{1}' with resource restriction policy '{2}' successfully set for '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName, $ResourceRestrictionPolicyName, $Email | Write-Verbose

                                    $objStatus.Status = "Complete"
                                    $objStatus.Details = "Resource restriction policy successfully set!"
                                    $objStatus.Service = $ServiceName

                                }

                            }
                            catch {
                                if (-not $WhatIf) {
                                    $objStatus.Status = "Failed"
                                    $objStatus.Details = "Resource restriction policy cannot be set!"
                                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                                    $objStatus.Service = $ServiceName
                                }
                            }

                        }
                        # If RRP name already assigned to the role
                        else {
                            # Must return a message if RRP name is already assigned to the role
                            "[{0}] Resource restriction policy name '{1}' is already assigned to this role!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ResourceRestrictionPolicyName | Write-Verbose

                            if ($Whatif) {
                                $ErrorMessage = "Resource restriction policy '{0}' is already assigned to this role!" -f $ResourceRestrictionPolicyName
                                Write-warning $ErrorMessage
                                return
                            }
                            else {
                                $objStatus.Status = "Warning"
                                $objStatus.Details = "Resource restriction policy name is already assigned to this role!"
                                
                            }

                        }
                    }
                    else {
                        # Must return a message if RRP name is not found in the region
                        "[{0}] Resource restriction policy name '{1}' cannot be found in this region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ResourceRestrictionPolicyName | Write-Verbose

                        if ($Whatif) {
                            $ErrorMessage = "Resource restriction policy '{0}' cannot be found in this region!" -f $ResourceRestrictionPolicyName
                            Write-warning $ErrorMessage
                            return
                        }
                        else {
                            $objStatus.Status = "Failed"
                            $objStatus.Details = "Resource restriction policy name cannot be found in this region!"
                            
                        }
                    }
                }
            }
            
            # Role not found without RRP parameter = CREATION
            # Role not found with RRP parameter = CREATION
            elseif (-not $Rolefound) {   

                $objStatus.ResourceRestrictionPolicyName = $ResourceRestrictionPolicyName

                # Get slug
                try {
                    $Slug = (Get-HPEGLRole -ServiceName $ServiceName -ServiceRole $RoleName).slug
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }

                "[{0}] Slug = '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Slug | write-verbose
                
                # If all apps except GreenLake service
                if (-not $MyInvocation.BoundParameters["HPEGreenLakeRole"]) {

                    try {
                        $Service = Get-HPEGLService -ShowProvisioned -Name $ServiceName | sort-object -Property application_id  -Unique
                    
                    }
                    catch {    
                        $PSCmdlet.ThrowTerminatingError($_)
    
                    }

                    if (-not $Service) {
                        # Must return a message if Service is not provisioned in the region
                        "[{0}] Service '{1}' not provisioned in a region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName | Write-Verbose
        
                        if ($Whatif) {
                            $ErrorMessage = "Service '{0}' is not provisioned in a region!" -f $ServiceName
                            Write-warning $ErrorMessage
                            return
                        }
                        else {
                            $objStatus.Status = "Failed"
                            $objStatus.Details = "Service not provisioned in a region!"
                            $objStatus.Service = $ServiceName
                            
                        }       
        
                    }
                    else {

                        $ServiceID = $Service.application_id
                        
                        # If not RRP
                        if (-Not $ResourceRestrictionPolicyName) {

                            # Build payload
                            $Payload = [PSCustomObject]@{ add = @( 
                                    @{ 
                                        role                          = @{  
                                            slug           = $Slug
                                            application_id = $ServiceID
                                        }
                                        resource_restriction_policies = $Null
                                    
                                    }
    
                                )
                            } | ConvertTo-Json -Depth 5

                            # Set user roles without RRP       
                            try { 
                                Invoke-HPEGLWebRequest -Method 'PUT' -Body $Payload -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | Out-Null 
                                
                                if (-not $WhatIf) {

                                    "[{0}] Role '{1}' successfully assigned to user: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Role, $Email | Write-Verbose

                                    $objStatus.Status = "Complete"
                                    $objStatus.Details = "Role successfully assigned!"
                                    $objStatus.Service = $ServiceName

                                }
                            }
                            catch {
                                if (-not $WhatIf) {
                                    $objStatus.Status = "Failed"
                                    $objStatus.Details = "Role cannot be assigned to user!"
                                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                                    $objStatus.Service = $ServiceName
                                }
                            }

                        }
                        
                        # If RRP
                        else {

                            $objStatus.ResourceRestrictionPolicyName = $ResourceRestrictionPolicyName

                            # Check if RRP is available

                            try {
                                $RRP = Get-HPEGLResourceRestrictionPolicy -Name $ResourceRestrictionPolicyName
                            }
                            catch {
                                $PSCmdlet.ThrowTerminatingError($_)
                            }

                            if ($RRP) {
                               
                                $ResourceRestrictionPolicyID = $RRP.resource_restriction_policy_id

                                # Check if RRP name already assigned to the role

                                try {
                                    $RRPAlreadyAssigned = (Get-HPEGLUserRole -Email $email -ServiceName $ServiceName | Where-Object role -eq $RoleName).resource_restriction_policy
                                }
                                catch {
                                    $PSCmdlet.ThrowTerminatingError($_)
                                }

                                # If RRP name not already assigned to the role
                                if ( $RRPAlreadyAssigned -ne $ResourceRestrictionPolicyName) {

                                    # Build payload
                                    $Payload = [PSCustomObject]@{ add = @( 
                                            @{ 
                                                role                          = @{  
                                                    slug           = $Slug
                                                    application_id = $ServiceID
                                                }
                                                resource_restriction_policies = @(
                                                    $ResourceRestrictionPolicyID
                                                )
                                            }
        
                                        )
                                    } | ConvertTo-Json -Depth 5
                            

                                    # Set user role with RRP      
                                    try {
                                        Invoke-HPEGLWebRequest -Method 'PUT' -Body $Payload -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | Out-Null

                                        if (-not $WhatIf) {

                                            "[{0}] Role '{1}' successfully assigned to user: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName, $Email | Write-Verbose

                                            $objStatus.Status = "Complete"
                                            $objStatus.Details = "Role successfully assigned!"
                                            $objStatus.Service = $ServiceName

                                        }

                                    }
                                    catch {
                                        if (-not $WhatIf) {
                                            $objStatus.Status = "Failed"
                                            $objStatus.Details = "Role cannot be assigned to user!"
                                            $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                                            $objStatus.Service = $ServiceName
                                        }
                                    }

                                }
                                # If RRP name already assigned to the role
                                else {
                                    # Must return a message if RRP name is already assigned to the role
                                    "[{0}] Resource restriction policy name '{1}' is already assigned to this role!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ResourceRestrictionPolicyName | Write-Verbose

                                    if ($Whatif) {
                                        $ErrorMessage = "Resource restriction policy '{0}' is already assigned to this role!" -f $ResourceRestrictionPolicyName
                                        Write-warning $ErrorMessage
                                        return
                                    }
                                    else {
                                        $objStatus.Status = "Warning"
                                        $objStatus.Details = "Resource restriction policy name is already assigned to this role!"
                                        
                                    }
                    
                                }
                            }
                            else {
                                # Must return a message if RRP name is not found in the region
                                "[{0}] Resource restriction policy name '{1}' cannot be found in this region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ResourceRestrictionPolicyName | Write-Verbose

                                if ($Whatif) {
                                    $ErrorMessage = "Resource restriction policy '{0}' cannot be found in this region!" -f $ResourceRestrictionPolicyName
                                    Write-warning $ErrorMessage
                                    return
                                }
                                else {
                                    $objStatus.Status = "Failed"
                                    $objStatus.Details = "Resource restriction policy name cannot be found in this region!"
                                    
                                }
                
                      
                            }
                        }
                    }
                }

                # If GreenLake service
                else {

                    $ServiceID = "00000000-0000-0000-0000-000000000000"

                    # Build payload

                    # No resource restriction policy exists for HPE GreenLake = "HPE GreenLake platform"

                    # Build payload
                    $Payload = [PSCustomObject]@{ add = @( 
                            @{ 
                                role                          = @{  
                                    slug           = $Slug
                                    application_id = $ServiceID
                                }
                                resource_restriction_policies = $Null
                                
                            }

                        )
                    } | ConvertTo-Json -Depth 5

                    # Set user roles without RRP       
                    try { 
                        Invoke-HPEGLWebRequest -Method 'PUT' -Body $Payload -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | Out-Null 
                            
                        if (-not $WhatIf) {

                            "[{0}] Role '{1}' successfully assigned to user '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Role, $Email | Write-Verbose

                            $objStatus.Status = "Complete"
                            $objStatus.Details = "Role successfully assigned!"
                            $objStatus.Service = $ServiceName

                        }
                    }
                    catch {
                        if (-not $WhatIf) {
                            $objStatus.Status = "Failed"
                            $objStatus.Details = "Role cannot be assigned to user!"
                            $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                            $objStatus.Service = $ServiceName
                        }
                    }

                               
                }
            }
        }

        [void] $UserRoleAssignmentStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            $UserRoleAssignmentStatus = Invoke-RepackageObjectWithType -RawObject $UserRoleAssignmentStatus -ObjectName "User.Role.ERSRSDE" 
            Return $UserRoleAssignmentStatus
        }


    }
}

Function Remove-HPEGLRoleFromUser {
    <#
    .SYNOPSIS
    Removes a role from a user.

    .DESCRIPTION
    This Cmdlet removes roles and permissions from users in an HPE GreenLake workspace. 
    Roles are collections of permissions that provide users access to HPE GreenLake services.

    Roles are unassigned from a service across all regions.

    .PARAMETER Email 
    Email address of the user for whom you want to remove roles and permissions (can be retrieved using Get-HPEGLUser).    

    .PARAMETER ArubaCentralRole 
    Name of the Aruba Central role to remove from the user's roles. 
    The predefined roles are as follows:
        * Aruba Central Administrator  
        * Aruba Central Guest Operator
        * Aruba Central Operator
        * Aruba Central view edit role
        * Aruba Central View Only
        * Netlnsight Campus Admin
        * Netlnsight Campus Viewonly

    .PARAMETER ComputeOpsManagementRole 
    Name of the Compute Ops Management role to remove from the user's roles. 
    The predefined roles are as follows:
        * Administrator
        * Observer
        * Operator

    .PARAMETER DataServicesRole 
    Name of the Data Services role to remove from the user's roles. 
    The predefined roles are as follows:
        * Administrator
        * Backup and Recovery Administrator
        * Backup and Recovery Operator
        * Data Ops Manager Administrator
        * Data Ops Manager Operator
        * Disaster Recovery Admin
        * Read only

    .PARAMETER HPEGreenLakeRole 
    Name of the HPE GreenLakeRole role to remove from the user's roles. 
    The predefined roles are as follows:
        * Workspace Administrator
        * Workspace Observer
        * Workspace Operator
        * Orders Administrator
        * Orders Observer
        * Orders Operator

    .PARAMETER RoleName 
    Role name of a service to be unassigned (can be retrieved using Get-HPEGLUserRole).   
        
    .PARAMETER ServiceName 
    Name of the service to which the role name will be unassigned (can be retrieved using Get-HPEGLUserRole).   

    .PARAMETER ResourceRestrictionPolicyName 
    Name of a resource restriction policy to be removed (can be retrieved with Get-HPEGLUserRole ).  

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Remove-HPEGLRoleFromUser -Email richardfeynman@quantummechanics.lab -ComputeOpsManagementRole Observer 

    Removes the Observer role to richardfeynman@quantummechanics.lab for the "Compute Ops Management" service.

    .EXAMPLE
    Remove-HPEGLRoleFromUser -Email richardfeynman@quantummechanics.lab -ServiceName "Aruba Central" -RoleName 'Aruba Central Administrator'

    Removes the Aruba Central Administrator role to richardfeynman@quantummechanics.lab for the "Aruba Central" service.
  
    .EXAMPLE
    "richardfeynman@quantummechanics.lab", "alexandreliapounov@math.edu" | Remove-HPEGLRoleFromUser -ComputeOpsManagementRole Administrator 

    Removes the Administrator role to richardfeynman@quantummechanics.lab and alexandreliapounov@math.edu for the "Compute Ops Management" service.

    .EXAMPLE
    $AdministratorUserEmails = @("richardfeynman@quantummechanics.lab","alexandreliapounov@math.edu")
    $AdministratorUserEmails | Remove-HPEGLRoleFromUser -ComputeOpsManagementRole Administrator
  
    Removes the Administrator role to the users in the $AdministratorUserEmails array for the "Compute Ops Management" service.

    .EXAMPLE
    Get-HPEGLUser | Where-Object email -match "quantummechanics" | Remove-HPEGLRoleFromUser -DataServicesRole Administrator

    Removes the Data Service Administrator role to all users whose email addresses contain the string 'quantummechanics'.

    .EXAMPLE
    Get-HPEGLUserRole -Email richardfeynman@quantummechanics.lab -ServiceName "Compute Ops Management" | Remove-HPEGLRoleFromUser

    Removes all Compute Ops Management roles for the user richardfeynman@quantummechanics.lab

    .EXAMPLE
    Remove-HPEGLRoleFromUser -Email richardfeynman@quantummechanics.lab -ComputeOpsManagementRole Administrator -ResourceRestrictionPolicyName RRP_COM-Location-Texas

    Removes the resource restriction policy named 'RRP_COM-Location-Texas' to the user Alexandre Liapounov for the "Compute Ops Management" service with the Administrator role. 
        
    .INPUTS
    System.Collections.ArrayList          
        List of roles from 'Get-HPEGLUserRole'.        
    System.Collections.ArrayList
        List of users from 'Get-HPEGLUser'.      
    System.String, System.String[]
        A single string object or a list of string objects that represent the email addresses.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Email - Email of the user 
        * Role - Name of the role to remove 
        * Service - Name of the service 
        * ResourceRestrictionPolicyName - Name of the resource restriction policy to remove
        * Status - Status of the role unassignment attempt (Failed for http error return; Complete if successful; Warning if no action is needed) 
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.

    
   #>
    [CmdletBinding(DefaultParameterSetName = 'ComputeOpsManagement')]
    Param( 

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ArubaCentral')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'HPEGreenLake')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ComputeOpsManagement')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'DataServices')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'Other')]
        [validatescript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$Email,
      
        [Parameter (Mandatory, ParameterSetName = 'ArubaCentral')]
        [ValidateSet ('Aruba Central Administrator', 'Aruba Central Guest Operator', 'Aruba Central Operator', 'Aruba Central view edit role', 'Aruba Central View Only', 'Netlnsight Campus Admin', 'Netlnsight Campus Viewonly')]
        [String]$ArubaCentralRole,

        [Parameter (Mandatory, ParameterSetName = 'HPEGreenLake')]
        [ValidateSet ('Workspace Administrator', 'Workspace Observer', 'Workspace Operator', 'Orders Administrator', 'Orders Observer', 'Orders Operator')]
        [String]$HPEGreenLakeRole,

        [Parameter (Mandatory, ParameterSetName = 'ComputeOpsManagement')]
        [ValidateSet ('Administrator', 'Observer', 'Operator')]
        [String]$ComputeOpsManagementRole,

        [Parameter (Mandatory, ParameterSetName = 'DataServices')]
        [ValidateSet ('Administrator', 'Backup and Recovery Administrator', 'Backup and Recovery Operator', 'Data Ops Manager Administrator', 'Data Ops Manager Operator', 'Disaster Recovery Admin', 'Read only')]
        [String]$DataServicesRole,

        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Other')]
        [Alias('Application_name')]
        [String]$ServiceName,

        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Other')]
        [Alias('Role')]
        [String]$RoleName,

        [Parameter (ParameterSetName = 'ArubaCentral')]
        [Parameter (ParameterSetName = 'HPEGreenLake')]
        [Parameter (ParameterSetName = 'ComputeOpsManagement')]
        [Parameter (ParameterSetName = 'DataServices')]
        [Parameter (ParameterSetName = 'Other')]
        [String]$ResourceRestrictionPolicyName,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $UserRoleUnassignmentStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $Uri = (Get-AuthzUsersRolesUri) + $Email.ToLower() + "/roles"


        # Test if user present
        try {
            
            $User = (Get-HPEGLUser).contact | Where-Object email -eq $Email
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }


        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Email                         = $Email
            Role                          = $Null
            Service                       = $Null
            ResourceRestrictionPolicyName = $Null
            Status                        = $Null
            Details                       = $Null
            Exception                     = $Null
                  
        }
        
        if (-not $User) {
            # Must return a message if user not found
            "[{0}] User '{1}' not found." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "User '{0}': Resource cannot be found in the workspace!" -f $Email
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "User cannot be found in the workspace!"
            }
    
            $objStatus.Service = $ServiceName
            
        }

        ############### If RoleName / ServiceName ###############
        elseif ($RoleName) {

            $objStatus.Role = $RoleName
            $objStatus.Service = $ServiceName


            try {
                $Service = Get-HPEGLService -ShowProvisioned -Name $ServiceName | sort-object -Property application_id  -Unique
                
            }
            catch {    
                $PSCmdlet.ThrowTerminatingError($_)

            }
            # If ServiceName not found except if GreenLake service
            if (-not $Service -and $ServiceName -ne "HPE GreenLake platform") {
                # Must return a message if Service is not provisioned in the region
                "[{0}] Service '{1}' not provisioned in a region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName | Write-Verbose

                if ($WhatIf) {
                    $ErrorMessage = "Service '{0}' is not provisioned in any region!" -f $ServiceName
                    Write-warning $ErrorMessage
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Service is not provisioned in any region!"
                }
        
                $objStatus.Service = $ServiceName
    
            }
            else {
                
                # Role assigned?  
                try {
                   
                    $ExistingUserRoles = Get-HPEGLUserRole -Email $email

                    $ServiceNameUserRoles = $ExistingUserRoles | Where-Object application_name -eq $ServiceName

                    $Rolefound = $ServiceNameUserRoles | Where-Object role -eq $RoleName

                    $Slug = $Rolefound.slug

                    "[{0}] Rolefound = '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Rolefound | write-verbose

                 

                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }

                # Role found but not RRP modification = DELETE
                if ( $Rolefound -and -not $ResourceRestrictionPolicyName) {

                    "[{0}] Role '{1}' found for '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Rolename, $ServiceName | Write-Verbose
                    "[{0}] Slug = '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Slug | write-verbose


                    if ($ServiceName -eq "HPE GreenLake platform") {

                        $ServiceID = "00000000-0000-0000-0000-000000000000"

                    }
                    else {
                        $ServiceID = $Service.application_id
                    }

                    # Build payload
                    $Payload = [PSCustomObject]@{ delete = @( 
                            @{ 
                                slug           = $Slug
                                application_id = $ServiceID
                            }
                        )
                    } | ConvertTo-Json -Depth 5
                  

                    # Remove user role      
                    try {
                        Invoke-HPEGLWebRequest -Method 'PUT' -Body $Payload -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | Out-Null

                        if (-not $WhatIf) {

                            "[{0}] Role '{1}' successfully removed from user: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Role, $Email | Write-Verbose

                            $objStatus.Status = "Complete"
                            $objStatus.Details = "Role successfully removed!"
                            $objStatus.Service = $ServiceName

                        }

                    }
                    catch {
                        if (-not $WhatIf) {
                            $objStatus.Status = "Failed"
                            $objStatus.Details = "Role cannot be removed from user!"
                            $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                            $objStatus.Service = $ServiceName
                        }
                    }

                }

                # Role found with RRP parameter = MODIFICATION 
                elseif ($Rolefound -and $ResourceRestrictionPolicyName) {

                    $objStatus.ResourceRestrictionPolicyName = $ResourceRestrictionPolicyName

                    # Check if RRP name assigned to the role
                    $RRPAssigned = $Rolefound.resource_restriction_policy
                    
                    # If RRP assigned to role, modification
                    if ($RRPAssigned -eq $ResourceRestrictionPolicyName) {
    
                        $RolesList = [System.Collections.ArrayList]::new()

                        foreach ($ExistingUserRole in $ExistingUserRoles) {
                 
                            $Slug = $ExistingUserRole.slug
                            $ServiceID = $ExistingUserRole.application_id
         
                            if ($ExistingUserRole.resource_restriction_policy) {

                                $ResourceRestrictionPolicyID = $ExistingUserRole.resource_restriction_policy_id

                                # If ExistingUserRole is the one we want to remove the exisiting RRP and set the default AllScopes RRP back
                                if ($ExistingUserRole.application_name -eq $ServiceName -and $ExistingUserRole.role -eq $RoleName) {
                        
                                    # Get the AllScopes default resource restriction policy ID of this role
                                    $ResourceRestrictionPolicyID = (Get-HPEGLResourceRestrictionPolicy -Name 'Allscopes' | Where-Object application_name -eq $ServiceName).resource_restriction_policy_id
              
                                }
                                    
                                $Role = [PSCustomObject]@{
                                    role                          = @{  
                                        slug           = $Slug
                                        application_id = $ServiceID
                                    }
                                    resource_restriction_policies = @(
                                        $ResourceRestrictionPolicyID
                                    )
                                }

                            }
                            else {                                
          
                                $Role = [PSCustomObject]@{
                                    role                          = @{  
                                        slug           = $Slug
                                        application_id = $ServiceID
                                    }
                                    resource_restriction_policies = @( )
                                }
                            }

                            $RolesList += $Role

                        }
        

                        # Build payload
                        $Payload = [PSCustomObject]@{ overwrite = @( 
                                $RolesList
                            )
                        } | ConvertTo-Json -Depth 5
        

                        # Set user role with RRP      
                        try {
                            Invoke-HPEGLWebRequest -Method 'PUT' -Body $Payload -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | Out-Null

                            if (-not $WhatIf) {

                                "[{0}] Role '{1}' with resource restriction policy '{2}' successfully removed for '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName, $ResourceRestrictionPolicyName, $Email | Write-Verbose

                                $objStatus.Status = "Complete"
                                $objStatus.Details = "Resource restriction policy successfully removed!"
                                $objStatus.Service = $ServiceName

                            }

                        }
                        catch {
                            if (-not $WhatIf) {
                                $objStatus.Status = "Failed"
                                $objStatus.Details = "Resource restriction policy cannot be removed!"
                                $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                                $objStatus.Service = $ServiceName
                            }
                        }


                    }

                    # If RRP name not assigned to the role: ERROR
                    else {
                        # Must return a message if RRP name is not found
                        "[{0}] Resource restriction policy name '{1}' cannot be found for the role '{2}'!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ResourceRestrictionPolicyName, $Rolename | Write-Verbose

                        if ($WhatIf) {
                            $ErrorMessage = "Resource restriction policy '{0}' cannot be found for the role '{1}'!" -f $Name, $Rolename
                            Write-warning $ErrorMessage
                            return
                        }
                        else {
                            $objStatus.Status = "Failed"
                            $objStatus.Details = "Resource restriction policy name cannot be found for this role!"
                        }
                        
                    }




                }

                # Role not found = ERROR
                elseif (-not $Rolefound) {
                    # Must return a message if Rolename is not found
                    "[{0}] Role name '{1}' is not assigned to user '{2}'!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName, $Email | Write-Verbose

                    if ($WhatIf) {
                        $ErrorMessage = "Role name '{0}' is not assigned to user '{1}'!" -f $RoleName, $Email
                        Write-warning $ErrorMessage
                        return
                    }
                    else {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Role name is not assigned to the user!"
                    }
    
                    $objStatus.Service = $ServiceName
                }            
            }
            
        }

        ############## If Predefined roles (i.e. -ComputeOpsManagementRole, etc.) ##############
        else {

            try {
                $ExistingUserRoles = Get-HPEGLUserRole -Email $email
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }


            if ($MyInvocation.BoundParameters["ArubaCentralRole"] ) {
            
                $ServiceName = "Aruba Central"
                $Rolename = $ArubaCentralRole
            
            }
            elseif ($MyInvocation.BoundParameters["HPEGreenLakeRole"] ) {
            
                $ServiceName = "HPE GreenLake platform"
                $Rolename = $HPEGreenLakeRole
            
            }
            elseif ($MyInvocation.BoundParameters["ComputeOpsManagementRole"] ) {

                $ServiceName = "Compute Ops Management"
                $Rolename = $ComputeOpsManagementRole
            
            }
            elseif ($MyInvocation.BoundParameters["DataServicesRole"] ) {
            
                $ServiceName = "Data Services"
                $Rolename = $DataServicesRole

            }

            $ServiceNameUserRoles = $ExistingUserRoles | Where-Object application_name -eq $ServiceName
            $Rolefound = $ServiceNameUserRoles | Where-Object role -eq $RoleName
            $Slug = $Rolefound.slug

            $objStatus.Role = $Rolename
            $objStatus.Service = $ServiceName
            
            # Role found but not RRP modification = DELETE
            if ($Rolefound -and -not $ResourceRestrictionPolicyName) {
                            
                if (-not $MyInvocation.BoundParameters["HPEGreenLakeRole"]) {

                    try {
                        $Service = Get-HPEGLService -ShowProvisioned -Name $ServiceName | sort-object -Property application_id  -Unique
                    
                    }
                    catch {    
                        $PSCmdlet.ThrowTerminatingError($_)
    
                    }

                    if (-not $Service) {
                        # Must return a message if Service is not provisioned in the region
                        "[{0}] Service '{1}' not provisioned in a region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName | Write-Verbose


                        if ($WhatIf) {
                            $ErrorMessage = "Service '{0}' not provisioned in any region!" -f $ServiceName
                            Write-warning $ErrorMessage
                            return
                        }
                        else {
                            $objStatus.Status = "Failed"
                            $objStatus.Details = "Service not provisioned in a region!"
                        }

                        $objStatus.Service = $ServiceName
        
                    }
                    else {

                        $ServiceID = $Service.application_id

                        $Payload = [PSCustomObject]@{ delete = @( 
                                @{ 
                                    slug           = $Slug
                                    application_id = $ServiceID
                                }
                            )
                        } | ConvertTo-Json -Depth 5
                      

                        # Remove user role      
                        try {
                            Invoke-HPEGLWebRequest -Method 'PUT' -Body $Payload -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | Out-Null

                            if (-not $WhatIf) {

                                "[{0}] Role '{1}' successfully removed from user '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Rolename, $Email | Write-Verbose

                                $objStatus.Status = "Complete"
                                $objStatus.Details = "Role successfully removed!"
                                $objStatus.Service = $ServiceName

                            }

                        }
                        catch {
                            if (-not $WhatIf) {
                                $objStatus.Status = "Failed"
                                $objStatus.Details = "Role cannot be removed!"
                                $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                                $objStatus.Service = $ServiceName
                            }
                        }
                    }
                }

                else {

                    $ServiceID = "00000000-0000-0000-0000-000000000000"

                    # Build payload
                    $Payload = [PSCustomObject]@{ delete = @( 
                            @{ 
                                slug           = $Slug
                                application_id = $ServiceID
                            }
                        )
                    } | ConvertTo-Json -Depth 5
              

                    # Remove user role     
    
                    try {
                        Invoke-HPEGLWebRequest -Method 'PUT' -Body $Payload -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | Out-Null

                        if (-not $WhatIf) {

                            "[{0}] Role '{1}' successfully removed from user: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName, $Email | Write-Verbose

                            $objStatus.Status = "Complete"
                            $objStatus.Details = "Role successfully removed!"
                            $objStatus.Service = $ServiceName

                        }

                    }
                    catch {
                        if (-not $WhatIf) {
                            $objStatus.Status = "Failed"
                            $objStatus.Details = "Role cannot be removed!"
                            $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                            $objStatus.Service = $ServiceName
                        }
                    }

                }

            }

            # Role found with RRP parameter = MODIFICATION 
            elseif ($Rolefound -and $ResourceRestrictionPolicyName) {

                $objStatus.ResourceRestrictionPolicyName = $ResourceRestrictionPolicyName

                # Check if RRP name assigned to the role
                $RRPAssigned = $Rolefound.resource_restriction_policy
                
                # If RRP assigned to role, modification
                if ($RRPAssigned -eq $ResourceRestrictionPolicyName) {

                    $RolesList = [System.Collections.ArrayList]::new()

                    foreach ($ExistingUserRole in $ExistingUserRoles) {
             
                        $Slug = $ExistingUserRole.slug
                        $ServiceID = $ExistingUserRole.application_id
     
                        if ($ExistingUserRole.resource_restriction_policy) {

                            $ResourceRestrictionPolicyID = $ExistingUserRole.resource_restriction_policy_id

                            # If ExistingUserRole is the one we want to remove the exisiting RRP and set the default AllScopes RRP back
                            if ($ExistingUserRole.application_name -eq $ServiceName -and $ExistingUserRole.role -eq $RoleName) {
                    
                                # Get the AllScopes default resource restriction policy ID of this role
                                $ResourceRestrictionPolicyID = (Get-HPEGLResourceRestrictionPolicy -Name 'Allscopes' | Where-Object application_name -eq $ServiceName).resource_restriction_policy_id
          
                            }
                                
                            $Role = [PSCustomObject]@{
                                role                          = @{  
                                    slug           = $Slug
                                    application_id = $ServiceID
                                }
                                resource_restriction_policies = @(
                                    $ResourceRestrictionPolicyID
                                )
                            }

                        }
                        else {                                
      
                            $Role = [PSCustomObject]@{
                                role                          = @{  
                                    slug           = $Slug
                                    application_id = $ServiceID
                                }
                                resource_restriction_policies = @( )
                            }
                        }

                        $RolesList += $Role

                    }
    

                    # Build payload
                    $Payload = [PSCustomObject]@{ overwrite = @( 
                            $RolesList
                        )
                    } | ConvertTo-Json -Depth 5
    

                    # Set user role with RRP      
                    try {
                        Invoke-HPEGLWebRequest -Method 'PUT' -Body $Payload -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | Out-Null

                        if (-not $WhatIf) {

                            "[{0}] Role '{1}' with resource restriction policy '{2}' successfully removed for '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName, $ResourceRestrictionPolicyName, $Email | Write-Verbose

                            $objStatus.Status = "Complete"
                            $objStatus.Details = "Resource restriction policy successfully removed!"
                            $objStatus.Service = $ServiceName

                        }

                    }
                    catch {
                        if (-not $WhatIf) {
                            $objStatus.Status = "Failed"
                            $objStatus.Details = "Resource restriction policy cannot be removed!"
                            $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                            $objStatus.Service = $ServiceName
                        }
                    }


                }

                # If RRP name not assigned to the role: ERROR
                else {
                    # Must return a message if RRP name is not found
                    "[{0}] Resource restriction policy name '{1}' cannot be found for the role '{2}'!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ResourceRestrictionPolicyName, $Rolename | Write-Verbose

                    if ($WhatIf) {
                        $ErrorMessage = "Resource restriction policy name '{0}' cannot be found for the role '{1}'!" -f $ResourceRestrictionPolicyName, $Rolename
                        Write-warning $ErrorMessage
                        return
                    }
                    else {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Resource restriction policy name cannot be found for this role!"
                    }
    

                }




            }

            # Role not found = ERROR
            elseif (-not $Rolefound) {
                # Must return a message if Rolename is not found
                "[{0}] Role name '{1}' is not assigned to this user!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName | Write-Verbose

                if ($WhatIf) {
                    $ErrorMessage = "Role name '{0}' is not assigned to user '{1}'!" -f $RoleName, $Email
                    Write-warning $ErrorMessage
                    return
                }
                else {
                    $objStatus.Status = "Warning"
                    $objStatus.Details = "Role name is not assigned to this user!"
                }

                $objStatus.Service = $ServiceName
              
            }
        }

        [void] $UserRoleUnassignmentStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            $UserRoleUnassignmentStatus = Invoke-RepackageObjectWithType -RawObject $UserRoleUnassignmentStatus -ObjectName "User.Role.ERSRSDE" 
            Return $UserRoleUnassignmentStatus
        }


    }
}

Function Get-HPEGLResourceRestrictionPolicy {
    <#
    .SYNOPSIS
    View resource restriction policies in an HPE GreenLake workspace.

    .DESCRIPTION
    This Cmdlet returns the resource restriction policies in an HPE GreenLake workspace.  
    Resource restriction policies limit which resources can be accessed by creating customizable resource groupings.

    .PARAMETER Name 
    Name of the resource restriction policy.

    .PARAMETER ServiceName 
    Optional parameter to display resource restriction policies for a service name (can be retrieved using Get-HPEGLService -ShowProvisioned).
   
    .PARAMETER ShowFilter 
    Switch parameter to get the filters used by a resource restriction policy.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Get-HPEGLResourceRestrictionPolicy 

    Return the resource restriction policies in an HPE GreenLake workspace.

    .EXAMPLE
    Get-HPEGLResourceRestrictionPolicy -Name RRP_COM-Location-Texas 

    Return the resource restriction policy information with the filter names in use for the 'RRP_COM-Location-Texas' resource restriction policy name.

    .EXAMPLE
    Get-HPEGLResourceRestrictionPolicy -ServiceName 'Compute Ops Management'   

    Return all resource restriction policies for the Compute Ops Management service instances.

    .EXAMPLE
    Get-HPEGLResourceRestrictionPolicy -Name RRP_with_3_COM_filters -ShowFilter
 
    Return all filters used by the 'RRP_with_3_COM_filters' resource restriction policy.
    
   #>

    [CmdletBinding(DefaultParameterSetName = 'Name')]
    Param( 
                    
        [Parameter (ParameterSetName = 'Name')]
        [String]$Name,
            
        [Parameter (ValueFromPipelineByPropertyName, ParameterSetName = 'ApplicationName')]
        [Alias('Application_name')]
        [String]$ServiceName,

        [Parameter (ParameterSetName = 'Name')]
        [Switch]$ShowFilter,

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $FilterList = [System.Collections.ArrayList]::new()

        $Uri = Get-ResourceRestrictionsPolicyUri 
        
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
   
        
        if ($Null -ne $Collection.policies) {

            if ($Name -and $ShowFilter) {

                if ($Collection.policies | Where-Object name -eq $Name) {

                    $ResourceRestrictionPolicyID = ( $Collection.policies | Where-Object name -eq $Name).resource_restriction_policy_id
                    "[{0}] Resource Restriction Policy ID: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ResourceRestrictionPolicyID | Write-Verbose
                    
                    $Uri = (Get-ResourceRestrictionPolicyUri) + $ResourceRestrictionPolicyID
                    
                    "[{0}] URIAdd to retrieve the RRP '{1}': '{2}' " -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Uri | Write-Verbose
                    
                    try {
                        
                        [array]$Collection = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                        
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }    

                    $Uri = (Get-ResourceRestrictionsPolicyUsersUri) + $ResourceRestrictionPolicyID + "/users?limit=2000"

                    "[{0}] URIAdd to retrieve the users using the RRP '{1}': '{2}' " -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Uri | Write-Verbose

                    try {

                        [array]$Users = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }    
                    
                    foreach ($_Filter in $collection.scope_resource_instances) {
                        
                        $Region = (Get-HPEGLService -Name $Collection.application_name ) | Where-Object application_instance_id -eq $_Filter.application_instance_id | ForEach-Object region
                        
                        $ReturnData = $Collection | Select-Object `
                        @{N = "name"; E = { $_Filter.name } }, `
                        @{N = "description"; E = { $_Filter.description } }, `
                        @{N = "slug"; E = { $_Filter.slug } }, `
                        @{N = "application_instance_id"; E = { $_Filter.application_instance_id } }, `
                        @{N = "region"; E = { $Region } }, `
                        @{N = "application_cid"; E = { $_Filter.application_cid } }, `
                        @{N = "type"; E = { $_Filter.type } }, `
                        @{N = "scope_type_name"; E = { $_Filter.scope_type_name } }, `
                        @{N = "resource_restriction_policy_name"; E = { $Name } }, `
                        @{N = "resource_restriction_policy_id"; E = { $_.resource_restriction_policy_id } }, `
                        @{N = "resource_restriction_policy_description"; E = { $_.description } }, `
                        @{N = "platform_cid"; E = { $_.platform_cid } }, `
                        @{N = "application_id"; E = { $_.application_id } }, `
                        @{N = "application_name"; E = { $_.application_name } }, `
                        @{N = "users"; E = { $Users.users } }, `
                        @{N = "created_at"; E = { $_.created_at } }, `
                        @{N = "updated_at"; E = { $_.updated_at } }
                        
                        $FilterList += $ReturnData 
                        
                    }
                    
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $FilterList -ObjectName "Resource.Restriction.Policy.GetFilter"    
                    $ReturnData = $ReturnData | Sort-Object { $_.name }
                }
                else {
                    Return
                }


            }
            elseif ($Name -and -not $ShowFilter) {

                if ($Collection.policies | Where-Object name -eq $Name) {

                    $ResourceRestrictionPolicyID = ( $Collection.policies | Where-Object name -eq $Name).resource_restriction_policy_id
                    "[{0}] Resource Restriction Policy ID: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ResourceRestrictionPolicyID | Write-Verbose

                    $Uri = (Get-ResourceRestrictionPolicyUri) + $ResourceRestrictionPolicyID

                    "[{0}] URIAdd: '{1}' " -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri | Write-Verbose
                    
                    try {
                        
                        [array]$Collection = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                        
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }    
                    
                    "[{0}] Number of filters: '{1}' " -f $MyInvocation.InvocationName.ToString().ToUpper(), $collection.scope_resource_instances.Length | write-Verbose
                    
                    $FilterCount = ($collection.scope_resource_instances).count
                    
                    if (-not $FilterCount) {
                        $FilterCount = 1
                    }
                    
                    # $ReturnData = $Collection  |  Select-Object `
                    # @{N = "resource_restriction_policy_name"; E = { $Name } }, `
                    # @{N = "resource_restriction_policy_id"; E = { $_.resource_restriction_policy_id } }, `
                    # @{N = "resource_restriction_policy_description"; E = { $_.description } }, `
                    # @{N = "platform_cid"; E = { $_.platform_cid } }, `
                    # @{N = "application_id"; E = { $_.application_id } }, `
                    # @{N = "application_name"; E = { $_.application_name } }, `
                    # @{N = "filter_number"; E = { $FilterCount } }, `
                    # @{N = "created_at"; E = { $_.created_at } }, `
                    # @{N = "updated_at"; E = { $_.updated_at } }
                    
                    
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $Collection -ObjectName "Resource.Restriction.Policy"    
                }
                else {
                    Return
                }

            }
            else {

                $CollectionList = $Collection.policies 

            
                if ($ServiceName) {

                    $CollectionList = $CollectionList | Where-Object application_name -eq $ServiceName
                }

                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "Resource.Restrictions.Policy"    

                $ReturnData = $ReturnData | Sort-Object { $_.name }


            }

            return $ReturnData 

        }
        else {

            return
            
        }
 
    }
}

Function New-HPEGLResourceRestrictionPolicy {
    <#
    .SYNOPSIS
    Creates a resource restriction policy in an HPE GreenLake workspace.

    .DESCRIPTION
    This Cmdlet creates a resource restriction policy for a service instance. 
    A resource restriction policy can limit users' ability to perform actions on a selected list of resources provided by a service instance.

    Note that the resource restriction policy requires filters, which need to be created and saved with the resource restriction policy option enabled in the service instance.
    For Compute Ops Management, use 'New-HPECOMFilter'.

    .PARAMETER Name 
    Specifies the name of the resource restriction policy.

    .PARAMETER ServiceName 
    Specifies the name of the service to which the resource restriction policy will be applied.

    .PARAMETER ServiceRegion 
    Specifies the service region to which the resource restriction policy will be applied.

    .PARAMETER FilterName 
    Specifies the name of the filter to assign to the resource restriction policy. This can be retrieved using 'Get-HPEGLServiceResourceRestrictionPolicy' and created using 'New-HPECOMFilter'.

    .PARAMETER Description 
    Provides a description of the resource restriction policy.

    .PARAMETER WhatIf 
    Displays the raw REST API call that would be made to GLP instead of sending the request. This is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    New-HPEGLResourceRestrictionPolicy -Name COM-US-West -ServiceName "Compute Ops Management" -ServiceRegion us-west -FilterName "RRP_ESXi_Group" -Description "My description"
    
    Defines a resource restriction policy named "COM-US-West" for the "Compute Ops Management" service in the US-West region using the filter "RRP_ESXi_Group".

    .EXAMPLE
    Get-HPEGLServiceResourceRestrictionPolicy -ServiceName "Compute Ops Management" -ServiceRegion us-west | New-HPEGLResourceRestrictionPolicy -Name RRP_Group_1
    
    Defines a resource restriction policy named "RRP_Group_1" for the "Compute Ops Management" service in the US-West region using all available filters in this service instance.

    .INPUTS
    System.Collections.ArrayList
        List of resource restriction policy filters from 'Get-HPEGLServiceResourceRestrictionPolicy'.

    .OUTPUTS
    System.Collections.ArrayList
    A custom status object or array of objects containing the following PsCustomObject keys:
        * Name - Name of the resource restriction policy attempted to be created 
        * Service - Name of the service to which the resource restriction policy will be applied
        * Region - Name of the service region to which the resource restriction policy will be applied
        * Filtername - Name of the filter assigned to the resource restriction policy
        * Status - Status of the creation attempt (Failed for HTTP error return; Complete if successful) 
        * Details - More information about the status         
        * Exception - Information about any exceptions generated during the operation.
    #>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 
                
        [Parameter (ParameterSetName = 'Default')]
        [String]$Name,
            
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Default')]
        [Alias('application_name')]
        [String]$ServiceName,

        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Default')]
        [Alias('region')]
        [String]$ServiceRegion,

        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Default')]
        [Alias('filter_name')]
        [String]$FilterName,

        [Parameter (ParameterSetName = 'Default')]
        [String]$Description,

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $SetResourceRestrictionPolicyStatus = [System.Collections.ArrayList]::new()

        $FilterList = [System.Collections.ArrayList]::new()

        $objStatus = @{}
        $FilternamesList = [System.Collections.ArrayList]::new()


    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        

        try {
            $Service = Get-HPEGLService -ShowProvisioned -Name $ServiceName -Region $ServiceRegion
            
        }
        catch {    
            $PSCmdlet.ThrowTerminatingError($_)

        }

        '[{0}] Service instance: {1}' -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Service | out-string) | Write-Verbose
        
        # Build object for the output
        $objStatus = [pscustomobject]@{

            Name       = $Name
            Service    = $ServiceName
            Region     = $ServiceRegion 
            Filtername = [System.Collections.ArrayList]::new()
            Status     = $Null
            Details    = $Null
            Exception  = $Null
                                  
        }


        if ( $ServiceName -eq "HPE GreenLake platform") {
            # Must return a message if Service is CCS 
            "[{0}] HPE GreenLake service '{1}' does not support RRP!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName | Write-Verbose

            
            if ($WhatIf) {
                $ErrorMessage = "HPE GreenLake service does not support resource restriction policy!" 
                Write-warning $ErrorMessage
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "HPE GreenLake service does not support resource restriction policy!"
    
            }


        }
        elseif (-not $Service) {
            # Must return a message if Service is not provisioned in the region
            "[{0}] Service instance '{1}' cannot be found!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServiceName | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "Service instance '{0}': Resource cannot be found in the workspace!" -f $ServiceName
                Write-warning $ErrorMessage
                return
            }
            else {

                $objStatus.Status = "Failed"
                $objStatus.Details = "Service instance cannot be found in the workspace!"
    
            }


        }
        else {

            $ServiceID = $Service.application_id
            $ApplicatrionCid = $Service.application_customer_id
            $ServiceInstanceId = $Service.application_instance_id

            $Uri = (Get-SetResourceRestrictionPolicyUri) + "/" + $ServiceID + "/resource_restriction"

            #  Get filters
            try {
                $Filterfound = Get-HPEGLServiceResourceRestrictionPolicy -ServiceName $ServiceName -ServiceRegion $ServiceRegion -PolicyName $FilterName
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
            

            if (-not $Filterfound) {
                # Must return a message if Service is not provisioned in the region
                "[{0}] Filter name '{1}' cannot be found in this service instance!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Filtername | Write-Verbose

                # Must return a message if resource not found

                if ($WhatIf) {
                    $ErrorMessage = "Filter '{0}' cannot be found in the '{1}' region of '{2}'!" -f $Filtername, $ServiceRegion, $ServiceName
                    Write-warning $ErrorMessage
                    continue # Continue in Process block stop processing the object in pipeline and DOES NOT go to End block 
                    
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Filter name cannot be found in this service instance!"
                }
    
            }
            else {

                "[{0}] Filter '{1}' found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Filtername | Write-Verbose


                #  Get RRPs
                try {
                    $RRPfound = Get-HPEGLResourceRestrictionPolicy -Name $Name
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
                

                if ($RRPfound) {
                    # Must return a message if RRP is present
                    "[{0}] RRP name '{1}' is already present in the workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

                    if ($WhatIf) {
                        $ErrorMessage = "Resource restriction policy '{0}' is already present in the HPE GreenLake workspace!" -f $Name
                        Write-warning $ErrorMessage
                        return
                        
                    }
                    else {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = "Resource restriction policy name already present in the HPE GreenLake workspace!!"
                    }
                }
                else {

                    $Slug = $Filterfound.slug
                    $ScopeTypeName = "Server filter"
                    # $ScopeTypeName = $Filterfound.scope_type_name
                    $ScopeTypeSlug = "/compute/filter"
                    # $ScopeTypeSlug = $Filterfound.scope_type_slug
                    
                    # Build object               
                    $FilterList += [PSCustomObject]@{
                        name                    = $Filtername
                        slug                    = $Slug 
                        # description             = $Null
                        matcher                 = $Slug 
                        scope_type_name         = $ScopeTypeName
                        scope_type_slug         = $ScopeTypeSlug
                        type                    = $ScopeTypeSlug
                        application_cid         = $ApplicatrionCid
                        application_instance_id = $ServiceInstanceId
                    }
                    
                    
                    # Build payload
                    $payload = [PSCustomObject]@{
                        
                        name                     = $Name
                        description              = $Description
                        application_name         = $ServiceName
                        scope_resource_instances = $FilterList
                        
                    } | ConvertTo-Json -Depth 5
                    
                    $FilternamesList += $FilterName
                    
                }
            }
        }
    }

    end {

        $FilternamesList | write-verbose

        foreach ($Item in $FilternamesList) {

            $objStatus.filtername += $Item
        }
          

        # Set resource restriction policy

        try {
            Invoke-HPEGLWebRequest -Uri $Uri -method 'POST' -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | out-Null

            if (-not $WhatIf) {

                $objStatus.Status = "Complete"
                $objStatus.Details = "Resource restriction policy successfully created!"

            }

        }
        catch {

            if (-not $WhatIf) {

                if ($objStatus.Status -ne "Failed") {
                
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Resource restriction policy cannot be created!"
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                
                }            
            }

        }    
        
        [void] $SetResourceRestrictionPolicyStatus.add($objStatus)

        if (-not $WhatIf) {

            $SetResourceRestrictionPolicyStatus = Invoke-RepackageObjectWithType -RawObject $SetResourceRestrictionPolicyStatus -ObjectName "Resource.Restriction.Policy.NSRFSDE" 
            Return $SetResourceRestrictionPolicyStatus
        }


    }


}

Function Remove-HPEGLResourceRestrictionPolicy {
    <#
    .SYNOPSIS
    Removes a resource restriction policy from an HPE GreenLake workspace.

    .DESCRIPTION
    This Cmdlet removes a resource restriction policy from the currently connected HPE GreenLake workspace.
    
    When a resource restriction policy assigned to a user is deleted, the user's resource access will still be marked as "Limited access", and the user will have read-only access to all server resources.

    The cmdlet issues a message at runtime to warn the user of the irreversible impact of this action and prompts for confirmation before proceeding with the removal.

    .PARAMETER Name 
    Specifies the name of the resource restriction policy to delete.

    .PARAMETER Force
    Switch parameter that performs the deletion without prompting for confirmation.

    .PARAMETER WhatIf 
    Displays the raw REST API call that would be made to GLP instead of sending the request. This is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Remove-HPEGLResourceRestrictionPolicy -Name COM-RRP-US-West
    
    Removes the resource restriction policy named 'COM-RRP-US-West' after the user has confirmed the removal.

    .EXAMPLE
    Remove-HPEGLResourceRestrictionPolicy -Name COM-RRP-US-West -Force
    
    Removes the resource restriction policy named 'COM-RRP-US-West' without prompting for confirmation.

    .EXAMPLE
    Get-HPEGLResourceRestrictionPolicy -Name RRP_with_2_COM_filters | Remove-HPEGLResourceRestrictionPolicy 
    
    Retrieves the resource restriction policy named 'RRP_with_2_COM_filters' and removes it, pending user confirmation.

    .EXAMPLE
    "RRP_with_2_COM_filters", "RRP_Gen11_filters" | Remove-HPEGLResourceRestrictionPolicy -Force

    Removes the resource restriction policy named 'RRP_with_2_COM_filters' and 'RRP_Gen11_filters' without prompting for confirmation.

    .EXAMPLE
    Get-HPEGLResourceRestrictionPolicy | Remove-HPEGLResourceRestrictionPolicy
    
    Retrieves all resource restriction policies and removes them. A warning message appears and asks the user to confirm the action for each resource restriction policy found.

    .INPUTS
    System.Collections.ArrayList
        List of resource restriction policy filters from 'Get-HPEGLResourceRestrictionPolicy'.
    System.String, System.String[]
        A single string object or a list of string objects that represent the resource restriction policy's names.


    .OUTPUTS
    System.Collections.ArrayList
    A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - Name of the resource restriction policy object attempted to be deleted 
        * Status - Status of the deletion attempt (Failed for HTTP error return; Complete if successful; Warning if no action is needed) 
        * Details - More information about the status         
        * Exception - Information about any exceptions generated during the operation.
    #>


    [CmdletBinding()]
    Param( 
                
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [String]$Name,

        [Switch]$Force,
            
        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose      

        $Uri = Get-DeleteResourceRestrictionPolicyUri

        $ObjectStatusList = [System.Collections.ArrayList]::new()
        $RRPIdsList = [System.Collections.ArrayList]::new()
        $RRPNameIdsList = [System.Collections.ArrayList]::new()

    }
    
    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        
        # Condition met when 'Get-HPEGLResourceRestrictionPolicy |  Remove-HPEGLResourceRestrictionPolicy' is used 
        if ($name -eq "AllScopes" -and $PSCmdlet.MyInvocation.ExpectingInput) {
            
            # Skipping All scopes from deletion as read only.
            return

        }
        # Condition met when 'Remove-HPEGLResourceRestrictionPolicy -Name Allscopes' is used
        elseif ($name -eq "AllScopes") {
            
            $ErrorMessage = "Resource restriction policy '{0}' does not support delete operation!" -f $Name
            Write-warning $ErrorMessage
            break

        }
        else {

            # Build object for the output
            $objStatus = [pscustomobject]@{

                Name      = $Name
                Status    = $Null
                Details   = $Null
                Exception = $Null
                            
            }
                
        }

        [void]$ObjectStatusList.add($objStatus)
    
    }
    end {
        
        try {
            $ResourceRestrictionPolicies = Get-HPEGLResourceRestrictionPolicy 
            
        }
        catch {    
            $PSCmdlet.ThrowTerminatingError($_)

        }

        "[{0}] List of policies to delete: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList.name | out-string) | Write-Verbose

        
        foreach ($Object in $ObjectStatusList) {

            $RRP = $ResourceRestrictionPolicies | Where-Object name -eq $Object.Name

            if (-not $RRP) {
                    
                # Must return a message if not found
                $Object.Status = "Failed"
                $Object.Details = "Resource restriction policy cannot be found in the workspace!"
                
                if ($WhatIf) {
                    $ErrorMessage = "Resource restriction policy '{0}': Resource cannot be found in the workspace!" -f $Object.name
                    Write-warning $ErrorMessage
                    continue
                }
            } 
            else {

                $ID = $RRP.resource_restriction_policy_id
                

                # Building the list of RRP IDs object for payload
                [void]$RRPIdsList.Add($ID)

                
                # Building the list of RRP name and IDs object for tracking
                $_Obj = [pscustomobject]@{
                    Name = $Object.Name
                    ID   = $ID
                }

                [void]$RRPNameIdsList.Add($_Obj)
            }
        }

        If ($RRPNameIdsList) {

            if ($Force) {
                $decision = 0
            }
            else {
    
                if ($RRPNameIdsList.Count -gt 1) {
                    $title = "All data associated with the restriction policies will be deleted. Confirm that you would like to remove {0} policies: {1}" -f $RRPNameIdsList.count, ($RRPNameIdsList.name -join ", ")
                    $question = 'This action cannot be undone. Are you sure you want to proceed?'
                    $choices = '&Yes', '&No'
    
                    $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
                }
                else {
                    $name = $RRPNameIdsList.name
                    $title = "All data associated with the '{0}' restriction policy will be deleted. Confirm that you would like to remove '{0}'." -f $name
                    $question = 'This action cannot be undone. Are you sure you want to proceed?'
                    $choices = '&Yes', '&No'
    
                    $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
                }
            }
    
            if ($decision -eq 0) {
                
                # Build payload
                $payload = [PSCustomObject]@{
    
                    ids = $RRPIdsList
                
                } | ConvertTo-Json -Depth 5
    
    
                # Remove resource restriction policy
    
                try {
                    Invoke-HPEGLWebRequest -Uri $Uri -method 'DELETE' -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | out-Null
    
                    if (-not $WhatIf) {
    
                        foreach ($Object in $ObjectStatusList) {

                            $RRPName = $RRPNameIdsList | Where-Object name -eq $Object.name

                            If ($RRPName) {

                                $Object.Status = "Complete"
                                $Object.Details = "Resource restriction policy successfully deleted!"
                            }
                        }
                    }
        
                }
                catch {
    
                    if (-not $WhatIf) {

                        foreach ($Object in $ObjectStatusList) {

                            $RRPName = $RRPNameIdsList | Where-Object name -eq $Object.name

                            If ($RRPName) {
    
                                $Object.Status = "Failed"
                                $Object.Details = "Resource restriction policy cannot be deleted!"
                                $Object.Exception = $_.Exception.message 
                                
                            }
                        }
                    }
    
                }    
            }
            else {

                'Operation cancelled by user!' | Write-Verbose
    
                if (-not $Whatif) {
                    
                    foreach ($Object in $ObjectStatusList) {
                        
                        $RRPName = $RRPNameIdsList | Where-Object name -eq $Object.name
                        
                        If ($RRPName) {
                            
                            $Object.Status = "Failed"
                            $Object.Details = "Operation cancelled by the user!"
                            $Object.Exception = $_.Exception.message 
                            
                        }
                    }
                }
                else {
                    
                    $ErrorMessage = "Operation cancelled by the user!"
                    Write-warning $ErrorMessage

                }
            }
        }        

        if (-not $WhatIf) {

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "Resource.Restriction.Policy.NSDE" 
            Return $ObjectStatusList
        }
    }
}

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
        
        $Uri = Get-UserPreferencesUri
        
    }
    
    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $ReturnData = [System.Collections.ArrayList]::new()

        try {
            [array]$UserPreferences = Invoke-HPEGLWebRequest -Method GET -Uri $Uri -SkipSessionCheck -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

   
        if ($Null -ne $UserPreferences ) {

    
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
    Cmdlet can be used to update the HPE GreenLake user preferences such as session timeout and Language.  

    .PARAMETER Language 
    The Language directive can be used to set the language to use in the HPE GreenLake UI. 
    Supported languages: Chinese, English, French, German, Japanese, Korean, Portuguese, Russian, Spanish, ltalian

    .PARAMETER SessionTimeoutInMinutes 
    The SessionTimeoutInMinutes directive can be used to set the session timeout (in minutes). 
    The value must be at least 5 and cannot exceed 120 minutes. The default is 30 minutes.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Set-HPEGLUserPreference -Language French

    Sets the language of the HPE GreenLake user interface to French.

    .EXAMPLE
    Set-HPEGLUserPreference -SessionTimeout 120

    Set the session timeout of the HPE GreenLake user interface to 120 minutes.

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

        # Argument completer registered in library module 
        [ValidateScript({ 
                if ($Global:HPESupportedLanguages[$_]   ) {
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

        

        # [ValidateSet("Fleet", "Meters")]
        # [string]$UnitOfMeasure = "Meters",

        # [ValidateSet("Fahrenheit", "Celsius")]
        # [string]$TemperatureUnit = "Celsius",

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-UserPreferencesUri

        $SetUserPreferenceStatus = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        try {
            $UserPreferences = Get-HPEGLUserPreference 
            
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

               
        if ($Language) {

            $LanguageSet = $Global:HPESupportedLanguages[$language]
            
            $UserPreferences.language = $LanguageSet
        }

 
        if ($SessionTimeoutInMinutes) {
                
            $UserPreferences.idle_timeout = $SessionTimeoutInMinutes * 60
        }

        if (-Not $Language -and -Not $SessionTimeoutInMinutes) {
            
            if ($Whatif) {
                $ErrorMessage = "At least one parameter must be provided!" 
                Write-warning $ErrorMessage
                return
            }
            else {
                
                $objStatus.Status = "Failed"
                $objStatus.Details = "At least one parameter must be provided!"
            }
            
        }
        else {
                
            # User Preferences modification
            try {
            
                $Response = Invoke-HPEGLWebRequest -Method 'PUT' -Body ($UserPreferences | ConvertTo-Json -Depth 5) -Uri $Uri -SkipSessionCheck -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                            
                if (-not $WhatIf) {
    
                    $Global:HPEGreenLakeSession.userSessionIdleTimeout = $SessionTimeoutInMinutes

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
    This Cmdlet can be used to set the HPE GreenLake user account password.       
    
    .PARAMETER currentpassword
    Your current user account password as a secure string.

    .PARAMETER newpassword
    Your new password to set as a secure string. It must meet the following requirements:
    - Contains at least one upper case letter
    - Contains at least one lower case letter
    - Contains at •east one number (0-9)
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

        $userid = (Get-HPEGLUserAccountDetails -Raw).id
        $Uri = (Get-HPEOnepassbaseURL) + "/v2-change-password-okta/" + $userid

        $UserPasswordChangeStatus = [System.Collections.ArrayList]::new()
        
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


            "[{0}] Payload content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Payload | Write-Verbose

            # User password modification
            
            try {
                [array]$Response = Invoke-HPEGLWebRequest -Method POST -Body $Payload -Uri $Uri -SkipSessionCheck -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
            
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
Export-ModuleMember -Function 'Get-HPEGLUser', 'Send-HPEGLUserInvitation', 'Remove-HPEGLUser', 'Get-HPEGLRole', 'Get-HPEGLUserRole', 'Add-HPEGLRoleToUser', 'Remove-HPEGLRoleFromUser', 'Get-HPEGLResourceRestrictionPolicy', 'New-HPEGLResourceRestrictionPolicy', 'Remove-HPEGLResourceRestrictionPolicy', 'Get-HPEGLUserPreference', 'Set-HPEGLUserPreference', 'Get-HPEGLUserAccountDetails', 'Set-HPEGLUserAccountDetails', 'Set-HPEGLUserAccountPassword' -Alias *

# SIG # Begin signature block
# MIIungYJKoZIhvcNAQcCoIIujzCCLosCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCcF/28xU6jAkcf
# JN9EjJamQXRJkQk97Ion5q2piUGq1KCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQglF3BYHuZqmRoHhlo6GmVVz3AXIui80C22Zrq7hSXEKEwDQYJKoZIhvcNAQEB
# BQAEggIA3R8s31yfU03oSc07nh0w4a3CiZgyzCylFZulb55+aCgJnNsCItMZiUXz
# OlLMebP7NCMxfqjORfOUDPsik7UJfydRaiKGjzOQYg6mWRmhqvJ73qr476gRwL5U
# vNHcdJa+2z3Zh2USYE+bmGfSg2XUs20cNfSgrEn2LwmN66jcFvgFa/CFQGIaPBVJ
# 98+zDYRqAlyOhfGjnBSBXYK3AHJZBLXYS93Ft2CDv6/I0nJilU7Bci7hSKjj2o9R
# kRYVF4wMNHaEuW7krVaA1fQ9+5u/pyguHEcGFxn3apfjpUPPiBcL+GMQJ6GDtUml
# 4Ze3rjGTgUtv3iyTmd2aJjJMMA7v7EGyhkj91EnfoBk4pWptMyHLMQ86I0PHPfju
# 0wRweVtc78bv51PP5a9RpWNeFC5OxQID3zYf00O99dAmu7Eg6QMJFgSW+TaUM5UI
# NKygXc1+hgUXX9oiY0Ck4CF+a/5JUSDO/Yw2qI+5n/gZ5NApnSllrwA/dsAdcO28
# Re5mxakQUr1efmJckzBF3latZTM1vi4rCY61v8jUoGogAt/4Xb8EZRw4mil2485+
# aJFxBuVSzZ8+z5ArnzMb1JnLEZPpwWyhoP1QouU7px7uowCdW4zupxPShpDfHnb0
# d5LhmnzaxFGSS1q2IvBLhu1d/GRgnHYOYnmHfpTl2m5/wIp1Mq2hghjoMIIY5AYK
# KwYBBAGCNwMDATGCGNQwghjQBgkqhkiG9w0BBwKgghjBMIIYvQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBBwYLKoZIhvcNAQkQAQSggfcEgfQwgfECAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQw5hQCwPjlK1u5v5Q2bqh7Ghn78J/GAV8B9F+t
# YD6VUxPUWF5LvS2EfLe0zFlbWa/lAhRYqLPMSCfl6dif/WDV+S+B7AVDLBgPMjAy
# NTEwMDIxNTU0MTJaoHakdDByMQswCQYDVQQGEwJHQjEXMBUGA1UECBMOV2VzdCBZ
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
# DxcNMjUxMDAyMTU1NDEyWjA/BgkqhkiG9w0BCQQxMgQw7k7mqj6OBQMmawctrKfI
# vSBW+BSyvRKzBIVRpNoVnON7BGPcz9HZIyi5BV1E9JjoMIIBegYLKoZIhvcNAQkQ
# AgwxggFpMIIBZTCCAWEwFgQUOMkUgRBEtNxmPpPUdEuBQYaptbEwgYcEFMauVOR4
# hvF8PVUSSIxpw0p6+cLdMG8wW6RZMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRpbWUgU3Rh
# bXBpbmcgUm9vdCBSNDYCEHojrtpTaZYPkcg+XPTH4z8wgbwEFIU9Yy2TgoJhfNCQ
# NcSR3pLBQtrHMIGjMIGOpIGLMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKTmV3
# IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBVU0VS
# VFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZpY2F0
# aW9uIEF1dGhvcml0eQIQNsKwvXwbOuejs902y8l1aDANBgkqhkiG9w0BAQEFAASC
# AgBh60s4SWT/nOXP5oUJdZGm4jM7rQJGDbCGIv5+axcqWbMH3YAk6daT77hJmODx
# et/JKyvVWRiO4t2UWxOaTbZctbqcgWCRddULvgZa1C5f5KOD5S7RfI2nBqROkiL1
# Nxzx2bCtNRL3cxy5sJiYRSPfeM0tncBYNE4FKX4Qi3z42An0CRrJALF5/ZuwV1wN
# iehuhuczWHaHQRi7u5DwPJznnhlJG51cWjVwfYmYRZU9zUVnhypf0ZRV5b1RkS4R
# UZibkF/wF43iHT47WjVaiJzA/zHWt4LOWH/wxIzgoLraUXjCBPm/7uZzV5Hfmpjy
# hb8eVhNRfKNYl9s3j2Ku16CpSMeH6UotMjao77smA26BN7XTGDjNnI98Ira1eVrC
# /tDsnm5YAPMNxfwtdlVS00iJqqsAiuP3yyqFGrlogXGOs86IxI1e4WimoKVZ2vAT
# QcqlA5eFzHXquUBkslXdnbQSQIY+KzJLvpVw1AEV/bvxUmwfY+4BkT8h4xUr8Ovt
# wKZ0qiuMeCN9dGvSZL2/PsoWU7R5XloZAYFFTIE5IOhg/VFD3lUJIFbd61xzjrnW
# 1W9BljczKJhEkutv3tSxTDpfTiYN/rYULbh5bJIpmSrkP7eXeAr3xeVJ5ZYX5uEB
# GBXKR1zEs2YXtfQH4lB2529YrVTQh/exTBOIfFnDr2Lrng==
# SIG # End signature block
