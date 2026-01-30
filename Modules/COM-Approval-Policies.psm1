#------------------- FUNCTIONS FOR COMPUTE OPS MANAGEMENT APPROVAL POLICIES -----------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1

# Public functions

Function Get-HPECOMApprovalPolicy {
    <#
    .SYNOPSIS
    Retrieve approval policies.

    .DESCRIPTION
    This cmdlet retrieves approval policies that add a required approval step to supported actions on server groups and server group members.
    This helps ensure that high impact actions are reviewed and authorized before they are applied.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER Name
    Optional parameter to filter approval policies by name.

    .PARAMETER ShowPolicyDetails
    Optional switch to expand and display the detailed policy configuration including approvables (operations requiring approval with approvers) and resources (groups/servers the policy applies to).
    Without this switch, the policyData property is returned as a nested object that may not be fully visible in the default output.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMApprovalPolicy -Region eu-central

    Retrieves all approval policies in the eu-central region.

    .EXAMPLE
    Get-HPECOMApprovalPolicy -Region us-west -Name "Production Approvals"

    Retrieves the approval policy named "Production Approvals" in the us-west region.

    .EXAMPLE
    Get-HPECOMApprovalPolicy -Region eu-central -ShowPolicyDetails

    Retrieves all approval policies with expanded details showing approvables and resources configuration.

    .EXAMPLE
    Get-HPECOMApprovalPolicy -Region eu-central -Name "Production Approvals" -ShowPolicyDetails | Format-List *

    Retrieves a specific approval policy with full details and displays all properties in list format.

    .INPUTS
    None. You cannot pipe objects to this cmdlet.

    .OUTPUTS
    HPEGreenLake.COM.ApprovalPolicies [System.Management.Automation.PSCustomObject]

        Approval policy objects with the following key properties:
        - id: The unique identifier of the approval policy
        - name: The name of the approval policy
        - description: Description of the approval policy
        - state: The state of the policy (ACTIVE or INACTIVE)
        - policyData: Contains approvables and resources
            - approvables: Array of operations requiring approval with approvers list and minimum number of approvers
            - resources: Array of resources (groups, servers) this policy applies to
        - createdAt: Timestamp when the policy was created
        - updatedAt: Timestamp when the policy was last updated
        - resourceUri: The URI of the approval policy resource
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

        [Parameter(ParameterSetName = 'Name')]
        [Parameter(Mandatory, ParameterSetName = 'NameShowPolicyDetails')]
        [String]$Name,

        [Parameter(ParameterSetName = 'NameShowPolicyDetails')]
        [Switch]$ShowPolicyDetails,

        [Switch]$WhatIf
    )

    Begin {
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
    }

    Process {
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Determine the URI
        $Uri = Get-COMApprovalPoliciesUri
        
        # Add name filter if specified
        if ($Name) {
            $EncodedName = [System.Web.HttpUtility]::UrlEncode($Name)
            $Uri += "?filter=name eq '$EncodedName'"
        }

        try {
            [Array]$Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -Method GET -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

            if ($Response) {
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $Response -ObjectName "COM.ApprovalPolicies"
                
                # If ShowPolicyDetails is specified, expand the policyData details
                if ($ShowPolicyDetails) {
                    $detailsOutput = @()
                    
                    # Fetch all groups once to avoid multiple calls
                    $allGroups = Get-HPECOMGroup -Region $Region -ErrorAction SilentlyContinue
                    
                    $ReturnData | ForEach-Object {
                        $policy = $_
                        
                        # Get group name(s) and ID(s) from resources
                        $groupName = "(Not applied to groups)"
                        $groupIds = @()
                        
                        if ($policy.policyData.resources) {
                            # Check if resources is an array (multiple groups) or single object (one group)
                            $resourcesList = if ($policy.policyData.resources -is [Array]) {
                                $policy.policyData.resources
                            } else {
                                @($policy.policyData.resources)
                            }
                            
                            # Process each resource
                            $groupNames = @()
                            foreach ($resource in $resourcesList) {
                                if ($resource.type -eq "compute-ops-mgmt/group") {
                                    $groupIds += $resource.id
                                    $matchingGroup = $allGroups | Where-Object { $_.id -eq $resource.id }
                                    
                                    if ($matchingGroup) {
                                        $groupNames += $matchingGroup.name
                                    }
                                    else {
                                        $groupNames += "Unknown"
                                    }
                                }
                            }
                            
                            if ($groupNames.Count -gt 0) {
                                $groupName = $groupNames -join ", "
                            }
                        }
                        
                        # Create an object for each approvable operation
                        if ($policy.policyData.approvables -and $policy.policyData.approvables.Count -gt 0) {
                            foreach ($approvable in $policy.policyData.approvables) {
                                $approvalText = if ($approvable.minApprovers -eq 1) {
                                    "1 approval required"
                                } else {
                                    "$($approvable.minApprovers) approvals required"
                                }
                                
                                $approversList = if ($approvable.approvers -and $approvable.approvers.Count -gt 0) {
                                    ($approvable.approvers | ForEach-Object { $_.email }) -join ", "
                                } else {
                                    "(No approvers)"
                                }
                                
                                $detailsOutput += [PSCustomObject]@{
                                    PSTypeName = 'HPEGreenLake.COM.ApprovalPolicies.Details'
                                    Operation = $approvable.approvableName
                                    Status = "Enabled"
                                    Approvals = $approvalText
                                    Approvers = $approversList
                                    GroupName = $groupName
                                    GroupIds = $groupIds
                                }
                            }
                        }
                    }
                    
                    return ( $detailsOutput | Sort-Object Operation)
                }
                
                return $ReturnData
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

Function New-HPECOMApprovalPolicy {
    <#
    .SYNOPSIS
    Create a new approval policy.

    .DESCRIPTION
    This cmdlet creates a new approval policy that adds a required approval step to supported actions on server groups and server group members.
    This helps ensure that high impact actions are reviewed and authorized before they are applied.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER Name
    The name of the approval policy.

    .PARAMETER Description
    Optional description of the approval policy.

    .PARAMETER EnableAllApprovers
    Email addresses of users who can approve all actions. When specified, enables approval requirement for all supported actions.

    .PARAMETER EnableAllRequired
    Number of required approvals (1-4) when EnableAllApprovers is used. Defaults to 1.

    .PARAMETER UpdateFirmwareApprovers
    Email addresses of users who can approve firmware updates. When specified, enables approval requirement for firmware updates.

    .PARAMETER UpdateFirmwareRequired
    Number of required approvals (1-4) for firmware updates. Defaults to 1.

    .PARAMETER ApplyInternalStorageConfigurationApprovers
    Email addresses of users who can approve internal storage configuration. When specified, enables approval requirement for internal storage configuration.

    .PARAMETER ApplyInternalStorageConfigurationRequired
    Number of required approvals (1-4) for internal storage configuration. Defaults to 1.

    .PARAMETER InstallOperatingSystemImageApprovers
    Email addresses of users who can approve OS installations. When specified, enables approval requirement for OS installations.

    .PARAMETER InstallOperatingSystemImageRequired
    Number of required approvals (1-4) for OS installations. Defaults to 1.

    .PARAMETER ApplyExternalStorageConfigurationApprovers
    Email addresses of users who can approve external storage configuration. When specified, enables approval requirement for external storage configuration.

    .PARAMETER ApplyExternalStorageConfigurationRequired
    Number of required approvals (1-4) for external storage configuration. Defaults to 1.

    .PARAMETER PowerOnApprovers
    Email addresses of users who can approve power on actions. When specified, enables approval requirement for power on.

    .PARAMETER PowerOnRequired
    Number of required approvals (1-4) for power on. Defaults to 1.

    .PARAMETER PowerOffApprovers
    Email addresses of users who can approve power off actions. When specified, enables approval requirement for power off.

    .PARAMETER PowerOffRequired
    Number of required approvals (1-4) for power off. Defaults to 1.

    .PARAMETER ResetApprovers
    Email addresses of users who can approve reset actions. When specified, enables approval requirement for reset.

    .PARAMETER ResetRequired
    Number of required approvals (1-4) for reset. Defaults to 1.

    .PARAMETER ColdBootApprovers
    Email addresses of users who can approve cold boot actions. When specified, enables approval requirement for cold boot.

    .PARAMETER ColdBootRequired
    Number of required approvals (1-4) for cold boot. Defaults to 1.

    .PARAMETER UpdateiLOFirmwareApprovers
    Email addresses of users who can approve iLO firmware updates. When specified, enables approval requirement for iLO firmware updates.

    .PARAMETER UpdateiLOFirmwareRequired
    Number of required approvals (1-4) for iLO firmware updates. Defaults to 1.

    .PARAMETER ApplyServerSettingsApprovers
    Email addresses of users who can approve server settings changes. When specified, enables approval requirement for server settings.

    .PARAMETER ApplyServerSettingsRequired
    Number of required approvals (1-4) for server settings. Defaults to 1.

    .PARAMETER DownloadFirmwareApprovers
    Email addresses of users who can approve firmware downloads. When specified, enables approval requirement for firmware downloads.

    .PARAMETER DownloadFirmwareRequired
    Number of required approvals (1-4) for firmware downloads. Defaults to 1.

    .PARAMETER GroupNames
    Name(s) of the group(s) to apply this approval policy to. Accepts a single group name or an array of group names.
    The cmdlet will automatically look up the group IDs and build the resources configuration.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    New-HPECOMApprovalPolicy -Region eu-central -Name "Production Approvals" -Description "Approval policy for production servers" `
        -UpdateFirmwareApprovers "admin@example.com", "manager@example.com" -UpdateFirmwareRequired 2 `
        -PowerOffApprovers "admin@example.com" -PowerOffRequired 1 `
        -GroupNames "Production Servers"

    Creates a new approval policy requiring 2 approvals for firmware updates and 1 approval for power off actions.

    .EXAMPLE
    New-HPECOMApprovalPolicy -Region eu-central -Name "All Actions Policy" `
        -EnableAllApprovers "admin@example.com", "manager@example.com" -EnableAllRequired 2 `
        -GroupNames "Production Servers"

    Creates an approval policy requiring 2 approvals for all supported actions (firmware updates, power operations, storage configuration, OS installation, etc.).

    .EXAMPLE
    New-HPECOMApprovalPolicy -Region eu-central -Name "Firmware Approval" `
        -UpdateFirmwareApprovers "admin@example.com" `
        -GroupNames "Production Servers", "Test Servers"

    Creates an approval policy for firmware updates requiring 1 approval (default) applied to multiple groups.

    .EXAMPLE
    New-HPECOMApprovalPolicy -Region eu-central -Name "All Actions Approval" `
        -EnableAllApprovers "admin@example.com", "manager@example.com" -EnableAllRequired 2 `
        -GroupNames "Critical Servers"

    Creates an approval policy requiring 2 approvals for all server actions.

    .INPUTS
    None. You cannot pipe objects to this cmdlet.

    .OUTPUTS
    HPEGreenLake.COM.ApprovalPolicies.Status [System.Management.Automation.PSCustomObject]

        Status object with the following properties:
        - Status: "Complete", "Failed", or "Warning"
        - Details: Detailed message about the operation result
        - Exception: Exception object if an error occurred
        - ApprovalPolicy: The created approval policy object (when successful)
    #>

    [CmdletBinding()]
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

        [Parameter(Mandatory)]
        [String]$Name,

        [String]$Description,

        # Enable all actions
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$EnableAllApprovers,
        [ValidateRange(1, 4)]
        [Int]$EnableAllRequired = 1,

        # Update firmware
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$UpdateFirmwareApprovers,
        [ValidateRange(1, 4)]
        [Int]$UpdateFirmwareRequired = 1,

        # Apply internal storage configuration
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$ApplyInternalStorageConfigurationApprovers,
        [ValidateRange(1, 4)]
        [Int]$ApplyInternalStorageConfigurationRequired = 1,

        # Install operating system image
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$InstallOperatingSystemImageApprovers,
        [ValidateRange(1, 4)]
        [Int]$InstallOperatingSystemImageRequired = 1,

        # Apply external storage configuration
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$ApplyExternalStorageConfigurationApprovers,
        [ValidateRange(1, 4)]
        [Int]$ApplyExternalStorageConfigurationRequired = 1,

        # Power on
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$PowerOnApprovers,
        [ValidateRange(1, 4)]
        [Int]$PowerOnRequired = 1,

        # Power off
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$PowerOffApprovers,
        [ValidateRange(1, 4)]
        [Int]$PowerOffRequired = 1,

        # Reset
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$ResetApprovers,
        [ValidateRange(1, 4)]
        [Int]$ResetRequired = 1,

        # Cold boot
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$ColdBootApprovers,
        [ValidateRange(1, 4)]
        [Int]$ColdBootRequired = 1,

        # Update iLO firmware
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$UpdateiLOFirmwareApprovers,
        [ValidateRange(1, 4)]
        [Int]$UpdateiLOFirmwareRequired = 1,

        # Apply server settings (BIOS and iLO)
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$ApplyServerSettingsApprovers,
        [ValidateRange(1, 4)]
        [Int]$ApplyServerSettingsRequired = 1,

        # Download firmware
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$DownloadFirmwareApprovers,
        [ValidateRange(1, 4)]
        [Int]$DownloadFirmwareRequired = 1,

        [String[]]$GroupNames,

        [Switch]$WhatIf
    )

    Begin {
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
    }

    Process {
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Create status object
        $objStatus = [PSCustomObject]@{
            Name           = $Name
            Status         = ""
            Details        = ""
            Exception      = $null
            ApprovalPolicy = $null
        }

        # Step 0: Check if approval policy with same name already exists
        "[{0}] Checking if approval policy '{1}' already exists..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
        
        try {
            $existingPolicy = Get-HPECOMApprovalPolicy -Region $Region -Name $Name -ErrorAction Stop -Verbose:$false
            
            if ($existingPolicy) {
                "[{0}] Approval policy '{1}' already exists" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                
                if ($WhatIf) {
                    Write-Warning "Approval policy '$Name' already exists. Cannot display API request."
                    return
                }
                else {
                    $objStatus.Status = "Warning"
                    $objStatus.Details = "Approval policy '$Name' already exists. Please use a different name or use Set-HPECOMApprovalPolicy to update the existing policy."
                    return Invoke-RepackageObjectWithType -RawObject $objStatus -ObjectName "COM.ApprovalPolicies.Status"
                }
            }
            else {
                "[{0}] Approval policy '{1}' does not exist - proceeding with creation" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
            }
        }
        catch {
            "[{0}] Error checking for existing approval policy: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
            
            if ($WhatIf) {
                Write-Warning "Cannot verify if approval policy exists: $($_.Exception.Message). Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Failed to verify if approval policy already exists." }
                $objStatus.Exception = $_.Exception
                return Invoke-RepackageObjectWithType -RawObject $objStatus -ObjectName "COM.ApprovalPolicies.Status"
            }
        }

        # Step 1: Get all users once for efficient validation
        "[{0}] Retrieving all users from workspace..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
        
        try {
            $Users = Get-HPEGLUser -ErrorAction Stop -Verbose:$false
            "[{0}] Retrieved {1} users from workspace" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Users.Count | Write-Verbose
        }
        catch {
            "[{0}] Error retrieving users: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
            
            if ($WhatIf) {
                Write-Warning "Cannot retrieve users from workspace: $($_.Exception.Message). Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Failed to retrieve users from workspace." }
                $objStatus.Exception = $_.Exception
                return Invoke-RepackageObjectWithType -RawObject $objStatus -ObjectName "COM.ApprovalPolicies.Status"
            }
        }

        # Validate users exist in workspace BEFORE building approvables
        $allApproversParams = @(
            "EnableAllApprovers", "UpdateFirmwareApprovers", "ApplyInternalStorageConfigurationApprovers",
            "InstallOperatingSystemImageApprovers", "ApplyExternalStorageConfigurationApprovers",
            "PowerOnApprovers", "PowerOffApprovers", "ResetApprovers", "ColdBootApprovers",
            "UpdateiLOFirmwareApprovers", "ApplyServerSettingsApprovers", "DownloadFirmwareApprovers"
        )

        $invalidUsers = @()
        foreach ($paramName in $allApproversParams) {
            if ($PSBoundParameters.ContainsKey($paramName)) {
                $emails = Get-Variable -Name $paramName -ValueOnly
                if ($emails) {
                    foreach ($email in $emails) {
                        "[{0}] Validating user exists: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $email | Write-Verbose
                        
                        $user = $Users | Where-Object { $_.email -eq $email }
                        
                        if (-not $user) {
                            "[{0}] User '{1}' not found in workspace" -f $MyInvocation.InvocationName.ToString().ToUpper(), $email | Write-Verbose
                            $invalidUsers += $email
                        }
                        else {
                            "[{0}] User '{1}' found in workspace" -f $MyInvocation.InvocationName.ToString().ToUpper(), $email | Write-Verbose
                        }
                    }
                }
            }
        }

        if ($invalidUsers.Count -gt 0) {
            $userList = $invalidUsers -join "', '"
            if ($WhatIf) {
                Write-Warning "User(s) not found in workspace: '$userList'. Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "User(s) not found in workspace: '$userList'. Please verify the users exist."
                return Invoke-RepackageObjectWithType -RawObject $objStatus -ObjectName "COM.ApprovalPolicies.Status"
            }
        }

        # Step 2: Validate at least one action is specified
        $hasActions = $false
        foreach ($paramName in $allApproversParams) {
            if ($PSBoundParameters.ContainsKey($paramName) -and (Get-Variable -Name $paramName -ValueOnly)) {
                $hasActions = $true
                break
            }
        }

        if (-not $hasActions) {
            "[{0}] No actions specified" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            
            if ($WhatIf) {
                Write-Warning "You must specify at least one action with approvers (e.g., -UpdateFirmwareApprovers, -PowerOffApprovers). Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "You must specify at least one action with approvers (e.g., -UpdateFirmwareApprovers, -PowerOffApprovers, -EnableAllApprovers, etc.)."
                return Invoke-RepackageObjectWithType -RawObject $objStatus -ObjectName "COM.ApprovalPolicies.Status"
            }
        }

        # Validate GroupNames parameter is provided
        if (-not $GroupNames -or $GroupNames.Count -eq 0) {
            "[{0}] No group names specified" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            
            if ($WhatIf) {
                Write-Warning "You must specify at least one group name using -GroupNames parameter. Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "You must specify at least one group name using -GroupNames parameter."
                return Invoke-RepackageObjectWithType -RawObject $objStatus -ObjectName "COM.ApprovalPolicies.Status"
            }
        }

        # Step 3: Get all groups once for efficient validation
        "[{0}] Retrieving all groups from region..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
        
        try {
            $Groups = Get-HPECOMGroup -Region $Region -ErrorAction Stop -Verbose:$false
            "[{0}] Retrieved {1} groups from region {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Groups.Count, $Region | Write-Verbose
        }
        catch {
            "[{0}] Error retrieving groups: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
            
            if ($WhatIf) {
                Write-Warning "Cannot retrieve groups from region ${Region}: $($_.Exception.Message). Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Failed to retrieve groups from region $Region." }
                $objStatus.Exception = $_.Exception
                return Invoke-RepackageObjectWithType -RawObject $objStatus -ObjectName "COM.ApprovalPolicies.Status"
            }
        }

        # Validate groups exist BEFORE building resources array
        "[{0}] Validating group names..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
        
        $validatedGroups = @()
        $invalidGroups = @()
        foreach ($gName in $GroupNames) {
            "[{0}] Looking up group: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $gName | Write-Verbose
            
            $group = $Groups | Where-Object { $_.name -eq $gName }
            
            if ($group) {
                "[{0}] Group '{1}' found with ID: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $gName, $group.id | Write-Verbose
                $validatedGroups += $group
            }
            else {
                "[{0}] Group '{1}' not found in region '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $gName, $Region | Write-Verbose
                $invalidGroups += $gName
            }
        }
        
        if ($invalidGroups.Count -gt 0) {
            $groupList = $invalidGroups -join "', '"
            if ($WhatIf) {
                Write-Warning "Group(s) not found in region ${Region}: '$groupList'. Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "Group(s) not found in region ${Region}: '$groupList'. Please verify the group names exist."
                return Invoke-RepackageObjectWithType -RawObject $objStatus -ObjectName "COM.ApprovalPolicies.Status"
            }
        }

        # Step 4: Build resources array from validated groups
        $Resources = @()
        foreach ($group in $validatedGroups) {
            $Resources += @{
                resourceId = $group.id
                resourceType = "compute-ops-mgmt/group"
            }
        }

        # Step 5: Build approvables array from parameters
        $Approvables = @()
        
        # If EnableAllApprovers is specified, expand to all actions
        if ($PSBoundParameters.ContainsKey("EnableAllApprovers") -and $EnableAllApprovers) {
            "[{0}] EnableAllApprovers specified - expanding to all individual actions" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            
            $allActions = @(
                @{Name = "Update firmware"; Approvers = $EnableAllApprovers; MinApprovers = $EnableAllRequired}
                @{Name = "Apply internal storage configuration"; Approvers = $EnableAllApprovers; MinApprovers = $EnableAllRequired}
                @{Name = "Install operating system image"; Approvers = $EnableAllApprovers; MinApprovers = $EnableAllRequired}
                @{Name = "Apply external storage configuration"; Approvers = $EnableAllApprovers; MinApprovers = $EnableAllRequired}
                @{Name = "Power on"; Approvers = $EnableAllApprovers; MinApprovers = $EnableAllRequired}
                @{Name = "Power off"; Approvers = $EnableAllApprovers; MinApprovers = $EnableAllRequired}
                @{Name = "Reset"; Approvers = $EnableAllApprovers; MinApprovers = $EnableAllRequired}
                @{Name = "Cold boot"; Approvers = $EnableAllApprovers; MinApprovers = $EnableAllRequired}
                @{Name = "Update iLO firmware"; Approvers = $EnableAllApprovers; MinApprovers = $EnableAllRequired}
                @{Name = "Apply server settings (BIOS and iLO)"; Approvers = $EnableAllApprovers; MinApprovers = $EnableAllRequired}
                @{Name = "Download firmware"; Approvers = $EnableAllApprovers; MinApprovers = $EnableAllRequired}
            )
            
            foreach ($action in $allActions) {
                $approversList = @()
                foreach ($email in $action.Approvers) {
                    $approversList += @{email = $email}
                }
                
                $Approvables += @{
                    approvableName = $action.Name
                    approvers = $approversList
                    minApprovers = $action.MinApprovers
                }
            }
        }
        
        $actionMap = @{
            "UpdateFirmwareApprovers" = @{Name = "Update firmware"; RequiredParam = "UpdateFirmwareRequired"}
            "ApplyInternalStorageConfigurationApprovers" = @{Name = "Apply internal storage configuration"; RequiredParam = "ApplyInternalStorageConfigurationRequired"}
            "InstallOperatingSystemImageApprovers" = @{Name = "Install operating system image"; RequiredParam = "InstallOperatingSystemImageRequired"}
            "ApplyExternalStorageConfigurationApprovers" = @{Name = "Apply external storage configuration"; RequiredParam = "ApplyExternalStorageConfigurationRequired"}
            "PowerOnApprovers" = @{Name = "Power on"; RequiredParam = "PowerOnRequired"}
            "PowerOffApprovers" = @{Name = "Power off"; RequiredParam = "PowerOffRequired"}
            "ResetApprovers" = @{Name = "Reset"; RequiredParam = "ResetRequired"}
            "ColdBootApprovers" = @{Name = "Cold boot"; RequiredParam = "ColdBootRequired"}
            "UpdateiLOFirmwareApprovers" = @{Name = "Update iLO firmware"; RequiredParam = "UpdateiLOFirmwareRequired"}
            "ApplyServerSettingsApprovers" = @{Name = "Apply server settings (BIOS and iLO)"; RequiredParam = "ApplyServerSettingsRequired"}
            "DownloadFirmwareApprovers" = @{Name = "Download firmware"; RequiredParam = "DownloadFirmwareRequired"}
        }

        foreach ($approversParam in $actionMap.Keys) {
            if ($PSBoundParameters.ContainsKey($approversParam) -and (Get-Variable -Name $approversParam -ValueOnly)) {
                $actionInfo = $actionMap[$approversParam]
                $requiredParam = $actionInfo.RequiredParam
                
                $approvers = Get-Variable -Name $approversParam -ValueOnly
                $required = Get-Variable -Name $requiredParam -ValueOnly
                
                # Build approvers array
                $approversList = @()
                foreach ($email in $approvers) {
                    $approversList += @{email = $email}
                }
                
                $Approvables += @{
                    approvableName = $actionInfo.Name
                    approvers = $approversList
                    minApprovers = $required
                }
            }
        }

        # Step 6: Build the payload
        $payload = @{
            name        = $Name
            description = $Description
            policyData  = @{
                approvables = $Approvables
                resources   = $Resources
            }
        }

        $Uri = Get-COMApprovalPoliciesUri
        $body = $payload | ConvertTo-Json -Depth 10

        try {
            $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -Method POST -Body $body -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

            if ($WhatIf) {
                return
            }

            if ($Response) {
                $objStatus.Status = "Complete"
                $objStatus.Details = "Approval policy '$Name' created successfully."
                $objStatus.ApprovalPolicy = $Response
            }
        }
        catch {
            $objStatus.Status = "Failed"
            $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Failed to create approval policy." }
            $objStatus.Exception = $_.Exception
        }

        $ReturnData = Invoke-RepackageObjectWithType -RawObject $objStatus -ObjectName "COM.ApprovalPolicies.Status"
        return $ReturnData
    }
}

Function Set-HPECOMApprovalPolicy {
    <#
    .SYNOPSIS
    Update an existing approval policy.

    .DESCRIPTION
    This cmdlet updates an existing approval policy. You can modify the name, description, approvables (operations requiring approval with their approvers), and resources (server groups).
    Approval policies add a required approval step to supported actions on server groups and server group members, helping ensure that high impact actions are reviewed and authorized before being applied.

    IMPORTANT BEHAVIOR FOR ACTION APPROVERS:
    - If you specify ANY action approver parameters (e.g., UpdateFirmwareApprovers, PowerOffApprovers, etc.), ALL existing action approvals will be replaced with the new configuration.
    - If you only specify one action, all other existing actions will be removed from the policy.
    - To preserve existing actions while adding/modifying others, you must specify all actions you want in the policy.
    - If you do NOT specify any action parameters, existing actions are preserved unchanged.
    - You can safely update Name, Description, or GroupNames without affecting existing action approvals.
    
    Use Get-HPECOMApprovalPolicy first to review the current configuration before making changes.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER Name
    The name of the approval policy to update.

    .PARAMETER ResourceUri
    The resource URI of the approval policy to update. Typically used with pipeline input.

    .PARAMETER NewName
    Optional new name for the approval policy.

    .PARAMETER Description
    Optional new description for the approval policy.

    .PARAMETER EnableAllApprovers
    Email addresses of users who can approve all actions. When specified, sets approval requirement for all supported actions.

    .PARAMETER EnableAllRequired
    Number of required approvals (1-4) when EnableAllApprovers is used. Defaults to 1.

    .PARAMETER UpdateFirmwareApprovers
    Email addresses of users who can approve firmware updates. When specified, sets approval requirement for firmware updates.

    .PARAMETER UpdateFirmwareRequired
    Number of required approvals (1-4) for firmware updates. Defaults to 1.

    .PARAMETER ApplyInternalStorageConfigurationApprovers
    Email addresses of users who can approve internal storage configuration.

    .PARAMETER ApplyInternalStorageConfigurationRequired
    Number of required approvals (1-4) for internal storage configuration. Defaults to 1.

    .PARAMETER InstallOperatingSystemImageApprovers
    Email addresses of users who can approve OS installations.

    .PARAMETER InstallOperatingSystemImageRequired
    Number of required approvals (1-4) for OS installations. Defaults to 1.

    .PARAMETER ApplyExternalStorageConfigurationApprovers
    Email addresses of users who can approve external storage configuration.

    .PARAMETER ApplyExternalStorageConfigurationRequired
    Number of required approvals (1-4) for external storage configuration. Defaults to 1.

    .PARAMETER PowerOnApprovers
    Email addresses of users who can approve power on actions.

    .PARAMETER PowerOnRequired
    Number of required approvals (1-4) for power on. Defaults to 1.

    .PARAMETER PowerOffApprovers
    Email addresses of users who can approve power off actions.

    .PARAMETER PowerOffRequired
    Number of required approvals (1-4) for power off. Defaults to 1.

    .PARAMETER ResetApprovers
    Email addresses of users who can approve reset actions.

    .PARAMETER ResetRequired
    Number of required approvals (1-4) for reset. Defaults to 1.

    .PARAMETER ColdBootApprovers
    Email addresses of users who can approve cold boot actions.

    .PARAMETER ColdBootRequired
    Number of required approvals (1-4) for cold boot. Defaults to 1.

    .PARAMETER UpdateiLOFirmwareApprovers
    Email addresses of users who can approve iLO firmware updates.

    .PARAMETER UpdateiLOFirmwareRequired
    Number of required approvals (1-4) for iLO firmware updates. Defaults to 1.

    .PARAMETER ApplyServerSettingsApprovers
    Email addresses of users who can approve server settings changes.

    .PARAMETER ApplyServerSettingsRequired
    Number of required approvals (1-4) for server settings. Defaults to 1.

    .PARAMETER DownloadFirmwareApprovers
    Email addresses of users who can approve firmware downloads.

    .PARAMETER DownloadFirmwareRequired
    Number of required approvals (1-4) for firmware downloads. Defaults to 1.

    .PARAMETER GroupNames
    Name(s) of the group(s) to apply this approval policy to. Accepts a single group name or an array of group names.
    When specified, replaces the existing group assignments.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request.

    .EXAMPLE
    Set-HPECOMApprovalPolicy -Region eu-central -Name "Production Approvals" -Description "Updated description"

    Updates the description of an approval policy.

    .EXAMPLE
    Set-HPECOMApprovalPolicy -Region eu-central -Name "Production Approvals" -NewName "Production Approvals v2"

    Renames an existing approval policy.

    .EXAMPLE
    Set-HPECOMApprovalPolicy -Region eu-central -Name "Production Approvals" -GroupNames "Production Servers", "Critical Systems"

    Updates the groups that the approval policy applies to. This replaces any existing group assignments.

    .EXAMPLE
    Set-HPECOMApprovalPolicy -Region eu-central -Name "Production Approvals" `
        -UpdateFirmwareApprovers "admin@example.com", "manager@example.com" -UpdateFirmwareRequired 2

    Updates the firmware update approvers for an existing policy. WARNING: This replaces ALL existing action approvals with only the firmware update action.

    .EXAMPLE
    Get-HPECOMApprovalPolicy -Region eu-central -Name "Production Approvals" | `
        Set-HPECOMApprovalPolicy -Region eu-central -EnableAllApprovers "admin@example.com"

    Updates an existing approval policy via pipeline to require approval from admin@example.com for all actions.

    .INPUTS
    HPEGreenLake.COM.ApprovalPolicies [System.Management.Automation.PSCustomObject]

    .OUTPUTS
    HPEGreenLake.COM.ApprovalPolicies.Status [System.Management.Automation.PSCustomObject]
    #>

    [CmdletBinding()]
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

        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [String]$Name,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ByResourceUri')]
        [Alias('uri')]
        [String]$ResourceUri,

        [String]$NewName,

        [String]$Description,

        # Enable all actions
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$EnableAllApprovers,
        [ValidateRange(1, 4)]
        [Int]$EnableAllRequired = 1,

        # Update firmware
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$UpdateFirmwareApprovers,
        [ValidateRange(1, 4)]
        [Int]$UpdateFirmwareRequired = 1,

        # Apply internal storage configuration
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$ApplyInternalStorageConfigurationApprovers,
        [ValidateRange(1, 4)]
        [Int]$ApplyInternalStorageConfigurationRequired = 1,

        # Install operating system image
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$InstallOperatingSystemImageApprovers,
        [ValidateRange(1, 4)]
        [Int]$InstallOperatingSystemImageRequired = 1,

        # Apply external storage configuration
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$ApplyExternalStorageConfigurationApprovers,
        [ValidateRange(1, 4)]
        [Int]$ApplyExternalStorageConfigurationRequired = 1,

        # Power on
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$PowerOnApprovers,
        [ValidateRange(1, 4)]
        [Int]$PowerOnRequired = 1,

        # Power off
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$PowerOffApprovers,
        [ValidateRange(1, 4)]
        [Int]$PowerOffRequired = 1,

        # Reset
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$ResetApprovers,
        [ValidateRange(1, 4)]
        [Int]$ResetRequired = 1,

        # Cold boot
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$ColdBootApprovers,
        [ValidateRange(1, 4)]
        [Int]$ColdBootRequired = 1,

        # Update iLO firmware
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$UpdateiLOFirmwareApprovers,
        [ValidateRange(1, 4)]
        [Int]$UpdateiLOFirmwareRequired = 1,

        # Apply server settings (BIOS and iLO)
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$ApplyServerSettingsApprovers,
        [ValidateRange(1, 4)]
        [Int]$ApplyServerSettingsRequired = 1,

        # Download firmware
        [ValidateScript({
            foreach ($email in $_) {
                if (-not ($email -as [Net.Mail.MailAddress])) {
                    Throw "'$email' is not a valid email address. Please provide a valid email address."
                }
            }
            $true
        })]
        [String[]]$DownloadFirmwareApprovers,
        [ValidateRange(1, 4)]
        [Int]$DownloadFirmwareRequired = 1,

        [String[]]$GroupNames,

        [Switch]$WhatIf
    )

    Begin {
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
    }

    Process {
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Create status object
        $objStatus = [PSCustomObject]@{
            Name           = if ($Name) { $Name } else { "" }
            Status         = ""
            Details        = ""
            Exception      = $null
            ApprovalPolicy = $null
        }

        # Step 0: Get existing policy and validate it exists
        "[{0}] Retrieving existing approval policy..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
        
        try {
            if ($ResourceUri) {
                # When ResourceUri is provided, make a GET call to verify it exists
                $existingPolicy = Invoke-HPECOMWebRequest -Region $Region -Uri $ResourceUri -Method GET -ErrorAction Stop -Verbose:$false
            }
            else {
                # When Name is provided, use Get-HPECOMApprovalPolicy
                $existingPolicy = Get-HPECOMApprovalPolicy -Region $Region -Name $Name -ErrorAction Stop -Verbose:$false
            }
            
            if (-not $existingPolicy) {
                "[{0}] Approval policy not found" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                
                if ($WhatIf) {
                    Write-Warning "Approval policy not found. Cannot display API request."
                    return
                }
                else {
                    $objStatus.Status = "Warning"
                    $objStatus.Details = "Approval policy not found."
                    return Invoke-RepackageObjectWithType -RawObject $objStatus -ObjectName "COM.ApprovalPolicies.Status"
                }
            }
            
            # Update Name in status object if it was retrieved via ResourceUri
            if (-not $objStatus.Name) {
                $objStatus.Name = $existingPolicy.name
            }
            
            "[{0}] Found existing policy: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $existingPolicy.name | Write-Verbose
        }
        catch {
            "[{0}] Error retrieving existing approval policy: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
            
            if ($WhatIf) {
                Write-Warning "Cannot retrieve approval policy: $($_.Exception.Message). Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Failed to retrieve existing approval policy." }
                $objStatus.Exception = $_.Exception
                return Invoke-RepackageObjectWithType -RawObject $objStatus -ObjectName "COM.ApprovalPolicies.Status"
            }
        }

        # Check if any approvers parameters are specified
        $allApproversParams = @(
            "EnableAllApprovers", "UpdateFirmwareApprovers", "ApplyInternalStorageConfigurationApprovers",
            "InstallOperatingSystemImageApprovers", "ApplyExternalStorageConfigurationApprovers",
            "PowerOnApprovers", "PowerOffApprovers", "ResetApprovers", "ColdBootApprovers",
            "UpdateiLOFirmwareApprovers", "ApplyServerSettingsApprovers", "DownloadFirmwareApprovers"
        )
        
        $hasApproversParams = $false
        foreach ($paramName in $allApproversParams) {
            if ($PSBoundParameters.ContainsKey($paramName)) {
                $hasApproversParams = $true
                break
            }
        }

        # Step 1: If approvers are specified, validate users exist
        if ($hasApproversParams) {
            "[{0}] Retrieving all users from workspace..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            
            try {
                $Users = Get-HPEGLUser -ErrorAction Stop -Verbose:$false
                "[{0}] Retrieved {1} users from workspace" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Users.Count | Write-Verbose
            }
            catch {
                "[{0}] Error retrieving users: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                
                if ($WhatIf) {
                    Write-Warning "Cannot retrieve users from workspace: $($_.Exception.Message). Cannot display API request."
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Failed to retrieve users from workspace." }
                    $objStatus.Exception = $_.Exception
                    return Invoke-RepackageObjectWithType -RawObject $objStatus -ObjectName "COM.ApprovalPolicies.Status"
                }
            }

            # Validate users exist in workspace
            $invalidUsers = @()
            foreach ($paramName in $allApproversParams) {
                if ($PSBoundParameters.ContainsKey($paramName)) {
                    $emails = Get-Variable -Name $paramName -ValueOnly
                    if ($emails) {
                        foreach ($email in $emails) {
                            "[{0}] Validating user exists: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $email | Write-Verbose
                            
                            $user = $Users | Where-Object { $_.email -eq $email }
                            
                            if (-not $user) {
                                "[{0}] User '{1}' not found in workspace" -f $MyInvocation.InvocationName.ToString().ToUpper(), $email | Write-Verbose
                                $invalidUsers += $email
                            }
                            else {
                                "[{0}] User '{1}' found in workspace" -f $MyInvocation.InvocationName.ToString().ToUpper(), $email | Write-Verbose
                            }
                        }
                    }
                }
            }

            if ($invalidUsers.Count -gt 0) {
                $userList = $invalidUsers -join "', '"
                if ($WhatIf) {
                    Write-Warning "User(s) not found in workspace: '$userList'. Cannot display API request."
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "User(s) not found in workspace: '$userList'. Please verify the users exist."
                    return Invoke-RepackageObjectWithType -RawObject $objStatus -ObjectName "COM.ApprovalPolicies.Status"
                }
            }
        }

        # Step 2: If GroupNames are specified, validate groups exist
        if ($PSBoundParameters.ContainsKey('GroupNames') -and $GroupNames) {
            "[{0}] Retrieving all groups from region..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            
            try {
                $Groups = Get-HPECOMGroup -Region $Region -ErrorAction Stop -Verbose:$false
                "[{0}] Retrieved {1} groups from region {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Groups.Count, $Region | Write-Verbose
            }
            catch {
                "[{0}] Error retrieving groups: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                
                if ($WhatIf) {
                    Write-Warning "Cannot retrieve groups from region ${Region}: $($_.Exception.Message). Cannot display API request."
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Failed to retrieve groups from region $Region." }
                    $objStatus.Exception = $_.Exception
                    return Invoke-RepackageObjectWithType -RawObject $objStatus -ObjectName "COM.ApprovalPolicies.Status"
                }
            }

            # Validate groups exist
            "[{0}] Validating group names..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            
            $validatedGroups = @()
            $invalidGroups = @()
            foreach ($gName in $GroupNames) {
                "[{0}] Looking up group: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $gName | Write-Verbose
                
                $group = $Groups | Where-Object { $_.name -eq $gName }
                
                if ($group) {
                    "[{0}] Group '{1}' found with ID: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $gName, $group.id | Write-Verbose
                    $validatedGroups += $group
                }
                else {
                    "[{0}] Group '{1}' not found in region '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $gName, $Region | Write-Verbose
                    $invalidGroups += $gName
                }
            }
            
            if ($invalidGroups.Count -gt 0) {
                $groupList = $invalidGroups -join "', '"
                if ($WhatIf) {
                    Write-Warning "Group(s) not found in region ${Region}: '$groupList'. Cannot display API request."
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Group(s) not found in region ${Region}: '$groupList'. Please verify the group names exist."
                    return Invoke-RepackageObjectWithType -RawObject $objStatus -ObjectName "COM.ApprovalPolicies.Status"
                }
            }

            # Build resources array from validated groups
            $Resources = @()
            foreach ($group in $validatedGroups) {
                $Resources += @{
                    resourceId = $group.id
                    resourceType = "compute-ops-mgmt/group"
                }
            }
        }

        # Step 3: Build approvables array from parameters (if any approvers specified)
        if ($hasApproversParams) {
            $Approvables = @()
            
            # If EnableAllApprovers is specified, expand to all actions
            if ($PSBoundParameters.ContainsKey("EnableAllApprovers") -and $EnableAllApprovers) {
                "[{0}] EnableAllApprovers specified - expanding to all individual actions" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                
                $allActions = @(
                    @{Name = "Update firmware"; Approvers = $EnableAllApprovers; MinApprovers = $EnableAllRequired}
                    @{Name = "Apply internal storage configuration"; Approvers = $EnableAllApprovers; MinApprovers = $EnableAllRequired}
                    @{Name = "Install operating system image"; Approvers = $EnableAllApprovers; MinApprovers = $EnableAllRequired}
                    @{Name = "Apply external storage configuration"; Approvers = $EnableAllApprovers; MinApprovers = $EnableAllRequired}
                    @{Name = "Power on"; Approvers = $EnableAllApprovers; MinApprovers = $EnableAllRequired}
                    @{Name = "Power off"; Approvers = $EnableAllApprovers; MinApprovers = $EnableAllRequired}
                    @{Name = "Reset"; Approvers = $EnableAllApprovers; MinApprovers = $EnableAllRequired}
                    @{Name = "Cold boot"; Approvers = $EnableAllApprovers; MinApprovers = $EnableAllRequired}
                    @{Name = "Update iLO firmware"; Approvers = $EnableAllApprovers; MinApprovers = $EnableAllRequired}
                    @{Name = "Apply server settings (BIOS and iLO)"; Approvers = $EnableAllApprovers; MinApprovers = $EnableAllRequired}
                    @{Name = "Download firmware"; Approvers = $EnableAllApprovers; MinApprovers = $EnableAllRequired}
                )
                
                foreach ($action in $allActions) {
                    $approversList = @()
                    foreach ($email in $action.Approvers) {
                        $approversList += @{email = $email}
                    }
                    
                    $Approvables += @{
                        approvableName = $action.Name
                        approvers = $approversList
                        minApprovers = $action.MinApprovers
                    }
                }
            }
            
            $actionMap = @{
                "UpdateFirmwareApprovers" = @{Name = "Update firmware"; RequiredParam = "UpdateFirmwareRequired"}
                "ApplyInternalStorageConfigurationApprovers" = @{Name = "Apply internal storage configuration"; RequiredParam = "ApplyInternalStorageConfigurationRequired"}
                "InstallOperatingSystemImageApprovers" = @{Name = "Install operating system image"; RequiredParam = "InstallOperatingSystemImageRequired"}
                "ApplyExternalStorageConfigurationApprovers" = @{Name = "Apply external storage configuration"; RequiredParam = "ApplyExternalStorageConfigurationRequired"}
                "PowerOnApprovers" = @{Name = "Power on"; RequiredParam = "PowerOnRequired"}
                "PowerOffApprovers" = @{Name = "Power off"; RequiredParam = "PowerOffRequired"}
                "ResetApprovers" = @{Name = "Reset"; RequiredParam = "ResetRequired"}
                "ColdBootApprovers" = @{Name = "Cold boot"; RequiredParam = "ColdBootRequired"}
                "UpdateiLOFirmwareApprovers" = @{Name = "Update iLO firmware"; RequiredParam = "UpdateiLOFirmwareRequired"}
                "ApplyServerSettingsApprovers" = @{Name = "Apply server settings (BIOS and iLO)"; RequiredParam = "ApplyServerSettingsRequired"}
                "DownloadFirmwareApprovers" = @{Name = "Download firmware"; RequiredParam = "DownloadFirmwareRequired"}
            }

            foreach ($approversParam in $actionMap.Keys) {
                if ($PSBoundParameters.ContainsKey($approversParam) -and (Get-Variable -Name $approversParam -ValueOnly)) {
                    $actionInfo = $actionMap[$approversParam]
                    $requiredParam = $actionInfo.RequiredParam
                    
                    $approvers = Get-Variable -Name $approversParam -ValueOnly
                    $required = Get-Variable -Name $requiredParam -ValueOnly
                    
                    # Build approvers array
                    $approversList = @()
                    foreach ($email in $approvers) {
                        $approversList += @{email = $email}
                    }
                    
                    $Approvables += @{
                        approvableName = $actionInfo.Name
                        approvers = $approversList
                        minApprovers = $required
                    }
                }
            }
        }

        # Step 4: Build the payload with updated and existing values
        # Important: When using existing data, we must clean it up to only include what the API expects
        
        # Prepare approvables (use new if specified, otherwise clean existing)
        $finalApprovables = if ($hasApproversParams) {
            $Approvables
        }
        else {
            # Clean up existing approvables to match API expectations
            $cleanedApprovables = @()
            foreach ($existingApprovable in $existingPolicy.policyData.approvables) {
                $cleanedApprovers = @()
                foreach ($approver in $existingApprovable.approvers) {
                    $cleanedApprovers += @{email = $approver.email}
                }
                $cleanedApprovables += @{
                    approvableName = $existingApprovable.approvableName
                    approvers = $cleanedApprovers
                    minApprovers = $existingApprovable.minApprovers
                }
            }
            $cleanedApprovables
        }
        
        # Prepare resources (use new if specified, otherwise clean existing)
        $finalResources = if ($PSBoundParameters.ContainsKey('GroupNames')) {
            $Resources
        }
        else {
            # Clean up existing resources to match API expectations
            # Ensure resources is always treated as an array (even if single item)
            $cleanedResources = @()
            $existingResources = @($existingPolicy.policyData.resources)
            foreach ($existingResource in $existingResources) {
                $cleanedResources += @{
                    resourceId = $existingResource.id
                    resourceType = $existingResource.type
                }
            }
            $cleanedResources
        }
        
        $payload = [PSCustomObject]@{
            name        = if ($NewName) { $NewName } else { $existingPolicy.name }
            description = if ($PSBoundParameters.ContainsKey('Description')) { $Description } else { $existingPolicy.description }
            policyData  = [PSCustomObject]@{
                approvables = [array]$finalApprovables
                resources   = [array]$finalResources
            }
        }

        $Uri = $existingPolicy.resourceUri
        $body = $payload | ConvertTo-Json -Depth 10

        try {
            $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -Method PATCH -Body $body -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

            if ($WhatIf) {
                return
            }

            if ($Response) {
                $objStatus.Status = "Complete"
                $objStatus.Details = "Approval policy updated successfully."
                $objStatus.ApprovalPolicy = $Response
            }
        }
        catch {
            $objStatus.Status = "Failed"
            $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Failed to update approval policy." }
            $objStatus.Exception = $_.Exception
        }

        $ReturnData = Invoke-RepackageObjectWithType -RawObject $objStatus -ObjectName "COM.ApprovalPolicies.Status"
        return $ReturnData
    }
}

Function Remove-HPECOMApprovalPolicy {
    <#
    .SYNOPSIS
    Delete an approval policy.

    .DESCRIPTION
    This cmdlet deletes an existing approval policy that was used to add required approval steps to supported actions on server groups and server group members.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER Name
    The name of the approval policy to delete.

    .PARAMETER ResourceUri
    The resource URI of the approval policy to delete. Typically used with pipeline input.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request.

    .EXAMPLE
    Remove-HPECOMApprovalPolicy -Region eu-central -Name "Old Policy"

    Deletes the specified approval policy by name.

    .EXAMPLE
    Get-HPECOMApprovalPolicy -Region eu-central -Name "Old Policy" | Remove-HPECOMApprovalPolicy -Region eu-central

    Gets an approval policy by name and deletes it.

    .EXAMPLE
    Get-HPECOMApprovalPolicy -Region eu-central | Remove-HPECOMApprovalPolicy -Region eu-central

    Deletes all approval policies in the specified region.

    .INPUTS
    HPEGreenLake.COM.ApprovalPolicies [System.Management.Automation.PSCustomObject]

    .OUTPUTS
    HPEGreenLake.COM.ApprovalPolicies.Status [System.Management.Automation.PSCustomObject]
    #>

    [CmdletBinding()]
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

        [Parameter(Mandatory, ParameterSetName = 'ByName')]
        [String]$Name,

        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'ByResourceUri')]
        [Alias('uri')]
        [String]$ResourceUri,

        [Switch]$WhatIf
    )

    Begin {
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
    }

    Process {
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Create status object
        $objStatus = [PSCustomObject]@{
            Name      = if ($Name) { $Name } else { "" }
            Status    = ""
            Details   = ""
            Exception = $null
        }

        # Step 1: Get existing policy and validate it exists
        "[{0}] Retrieving approval policy to verify it exists..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
        
        try {
            if ($ResourceUri) {
                # When ResourceUri is provided, make a GET call to verify it exists
                $existingPolicy = Invoke-HPECOMWebRequest -Region $Region -Uri $ResourceUri -Method GET -ErrorAction Stop -Verbose:$false
            }
            else {
                # When Name is provided, use Get-HPECOMApprovalPolicy
                $existingPolicy = Get-HPECOMApprovalPolicy -Region $Region -Name $Name -ErrorAction Stop -Verbose:$false
            }
            
            if (-not $existingPolicy) {
                "[{0}] Approval policy not found" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                
                if ($WhatIf) {
                    Write-Warning "Approval policy not found. Cannot display API request."
                    return
                }
                else {
                    $objStatus.Status = "Warning"
                    $objStatus.Details = "Approval policy not found."
                    return Invoke-RepackageObjectWithType -RawObject $objStatus -ObjectName "COM.ApprovalPolicies.Status"
                }
            }
            
            # Update Name in status object if it was retrieved via ResourceUri
            if (-not $objStatus.Name) {
                $objStatus.Name = $existingPolicy.name
            }
            
            "[{0}] Found existing policy: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $existingPolicy.name | Write-Verbose
        }
        catch {
            "[{0}] Error retrieving approval policy: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
            
            if ($WhatIf) {
                Write-Warning "Cannot retrieve approval policy: $($_.Exception.Message). Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Failed to retrieve approval policy." }
                $objStatus.Exception = $_.Exception
                return Invoke-RepackageObjectWithType -RawObject $objStatus -ObjectName "COM.ApprovalPolicies.Status"
            }
        }

        $Uri = if ($ResourceUri) { $ResourceUri } else { $existingPolicy.resourceUri }

        try {
            $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -Method DELETE -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

            if ($WhatIf) {
                return
            }

            $objStatus.Status = "Complete"
            $objStatus.Details = "Approval policy deleted successfully."
        }
        catch {
            $objStatus.Status = "Failed"
            $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Failed to delete approval policy." }
            $objStatus.Exception = $_.Exception
        }

        $ReturnData = Invoke-RepackageObjectWithType -RawObject $objStatus -ObjectName "COM.ApprovalPolicies.Status"
        return $ReturnData
    }
}

# Private helper function for repackaging objects with custom type names
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

                $DataSetType = "HPEGreenLake.$ObjectName"
                $RawElementObject.PSTypeNames.Insert(0, $DataSetType)
                
                $RawElementObject.PSObject.TypeNames.Insert(0, $DataSetType)

                $OutputObject += $RawElementObject
            }

            if ($OutputObject.PSObject.TypeNames -notcontains $DataSetType) {

                foreach ($item in $OutputObject) {
                    [void]($item | Add-Member -MemberType NoteProperty -Name PSObject.TypeNames -Value @( $DataSetType) -Force)
                }
            }

            return $OutputObject
        }
        else {
            return
        }
    }   
}

Export-ModuleMember -Function 'Get-HPECOMApprovalPolicy', 'New-HPECOMApprovalPolicy', 'Set-HPECOMApprovalPolicy', 'Remove-HPECOMApprovalPolicy' -Alias *

# SIG # Begin signature block
# MIIungYJKoZIhvcNAQcCoIIujzCCLosCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCAM1TNON/YAZNv
# jnes6esSIw4VNhORx3VJ5F/JZfC+4KCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQgoc1OLmfajkXEjmuO5kxn7LkfSrz3a+Eiz4r9o57VHvgwDQYJKoZIhvcNAQEB
# BQAEggIAim/UBL8MYB9pT7GVLX/ReV1WO5kGYGEE/b3oE6c+V1s817tv28kRJPYJ
# lRvXTQ7wSg7a55AWn3pidFjEFf5FQPD976XQQGSKaJQgQJS1bx56rTloSxfAX49M
# lHp6kFB5Ov50f4O/qF4L+EpRPXGc8viVLhPUABYxWgaNmNv7VuddXcPVMjwjPzv9
# Yq03ikORj7Njc6LatBWb64RgP/TNUNzN2Y0Iw6HcRs/vjJZxc1EYxNfu45T837PB
# VlkOyaQu004HmJh/kSfc1fr96GJ1XV8/be7Yp4VatUpQNt+xs4d+B/FbjxdzjBjF
# eOu/DU9hxeLV/A0LdSfMJO7J1OIWvCsBmBvX131PtNEy19O8T6pdEc7qwPdGQvFc
# BBu67ZnwnooLWaxAGdgGCQmptdex50xZ7dWmXg2CUcJm+w7jAIzIhyEOGUiGlnf7
# 1MPO9hR+o4ZVMrrhDSDPvFqeszFkA4E/QAx3HcWISmn7Ik+6aNy+gseW0sGw/DWd
# ULCMUj0VnWdd72Kcb6nmoltiRQcq3htRta4/rAwcgglvQmsbvJuc3sUZBVQqMcZJ
# A/q+BrMprDysbcH7lrVZUAdNQGr6fBy43L+bNcCYn/NPZWU9BehAixx/pEJ1AbLQ
# at+vJwWa9mo4SurDLwchLh70OSCRTk0Qfpz4E1tAwW/20bUh4O2hghjoMIIY5AYK
# KwYBBAGCNwMDATGCGNQwghjQBgkqhkiG9w0BBwKgghjBMIIYvQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBBwYLKoZIhvcNAQkQAQSggfcEgfQwgfECAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQwME9w2CPot/oWaAu+sUpfoHX/zkkX0AWVsu2H
# rOnrlwTjPhYIa3gFzUvCaJpCxoQZAhRA/WWI/FknDOVe1h5gyukSXpJPYRgPMjAy
# NjAxMzAxMDQ1NDFaoHakdDByMQswCQYDVQQGEwJHQjEXMBUGA1UECBMOV2VzdCBZ
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
# DxcNMjYwMTMwMTA0NTQxWjA/BgkqhkiG9w0BCQQxMgQwh46hgU6sha8gomsGpFXS
# Ivha9RwwoY7r1gyfE5Ci7vFxIfJnTYGrxJT+25AIE3gKMIIBegYLKoZIhvcNAQkQ
# AgwxggFpMIIBZTCCAWEwFgQUOMkUgRBEtNxmPpPUdEuBQYaptbEwgYcEFMauVOR4
# hvF8PVUSSIxpw0p6+cLdMG8wW6RZMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRpbWUgU3Rh
# bXBpbmcgUm9vdCBSNDYCEHojrtpTaZYPkcg+XPTH4z8wgbwEFIU9Yy2TgoJhfNCQ
# NcSR3pLBQtrHMIGjMIGOpIGLMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKTmV3
# IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBVU0VS
# VFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZpY2F0
# aW9uIEF1dGhvcml0eQIQNsKwvXwbOuejs902y8l1aDANBgkqhkiG9w0BAQEFAASC
# AgCQLHFrJpE5agIbGpCC+3KEWBGZf4x/NtWmANIyd7B8cFceRu+GUGFORvVCMDHk
# FvZ3Y2h0PaRp4j6Sg9oQOvQtw73e1bcPq1xckMAz9tBOQ7p/JZIqtKiIaR+1P5U1
# ECGUiN89SFvLf0jw12gxKFD5mT5RSyTLP4CEjiS4qYPQQQhAdIDL4hjo0ZwowQeV
# kdfzOOPG61ECZHRN+Hfki8Xt3m6SM/WkjE+ZbVH6CUdVqAq1maZP//pe3O1X4fhd
# RHaLosQYny4XgyPFOC1qxGYRsJTs6BJpZQau9Gcwe6SDE8Pu9Tlqg9aRSGOwYKeq
# 5gDNoc2bVT98kBdS/hyu4TFSbwhRzv1BKIgI+jJCiDuguRduRwdn0JgsioZQ/1e4
# MVXxOgcvGgf1yOe/brVKXHG2CsE56ESSYXdEV3uR5AHhlNLhQnFJ656QUTT5vdtT
# ArWNkTh653fdwqJsGAzV3KV4VNhWMu+yLff0YWwrxKOaqK8BXgFdTMJlTJWRj8dd
# mLVge4fB/A4HWHoQ7M1UPoEN2wdMPxSFD6h9pxAqKGDfqGGF1QEE5vhkRMFz9h4E
# KAo7I3fbfkKrpPMYwP+BYXMJh5S6InkS1PA1vIGe5U2bb0dtj+JOLhXfP85VTGyi
# 1plFGPyKHfkOjzymn6fn+Tz/PBuANt6WjOCwtDZFSTgdEA==
# SIG # End signature block
