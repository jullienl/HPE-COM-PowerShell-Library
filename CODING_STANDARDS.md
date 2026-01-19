# HPECOMCmdlets Coding Standards

## ⚠️ CRITICAL CHECKLIST - Read This First!

Before implementing ANY function, verify these requirements:

### ✅ WhatIf Implementation
- [ ] Add manual `[Switch]$WhatIf` parameter (NOT `SupportsShouldProcess`)
- [ ] Pass `-WhatIfBoolean $WhatIf` to `Invoke-HPEGLWebRequest` or `Invoke-HPECOMWebRequest`
- [ ] Perform ALL validation checks BEFORE the API call
- [ ] With `-WhatIf` + validation failure: Show `Write-Warning` with "Cannot display API request." and return
- [ ] With `-WhatIf` + validation success: API wrapper displays request details
- [ ] Without `-WhatIf`: Never use `Write-Warning` for validation failures

### ✅ Get-* Cmdlet Behavior
- [ ] Return nothing silently for "not found" (no warning, no error)
- [ ] Use verbose messages for "not found" scenarios
- [ ] Throw terminating errors only for authentication/session failures
- [ ] Never return status objects (status objects are for Add/Set/Remove cmdlets)

### ✅ Add-*/Set-*/Remove-* Cmdlet Behavior  
- [ ] Always return status objects with Status/Details/Exception properties
- [ ] Pre-validate BEFORE API call (user exists, role exists, no duplicates)
- [ ] With `-WhatIf` + validation failure: `Write-Warning` + return (no status object)
- [ ] Without `-WhatIf` + validation failure: Return status object with "Warning" status
- [ ] Use ONLY these status values: "Complete", "Failed", "Warning"

### ✅ Code Reuse
- [ ] Check for existing Get-* functions BEFORE writing new API calls
- [ ] Use `Invoke-HPEGLWebRequest` or `Invoke-HPECOMWebRequest` (never `Invoke-RestMethod`)
- [ ] Add new constants to `Constants.psm1` with getter functions
- [ ] Use `$Global:HPEGreenLakeSession` for workspace/session info

### ✅ Module Export
- [ ] Add function to individual module's `Export-ModuleMember` (e.g., `GLP-Services.psm1`)
- [ ] Add function to root `HPECOMCmdlets.psd1` FunctionsToExport array
- [ ] Add format definition to `HPECOMCmdlets.Format.ps1xml` for status objects

### ✅ Parameters
- [ ] Add `ValueFromPipeline` and `ValueFromPipelineByPropertyName` where appropriate
- [ ] Add `ArgumentCompleter` for parameters with finite lists (~50-100 items)
- [ ] Use parameter sets for mutually exclusive options

### ✅ Verbose Logging
- [ ] Add caller info in Begin block: `"[{0}] Called from: {1}" -f $MyInvocation...`
- [ ] Add bound parameters in Process block: `"[{0}] Bound PS Parameters: {1}" -f...`
- [ ] Add verbose messages for validation results, API calls, errors

---

## Status Values
Functions must use **ONLY** these three status values:
- **Complete** - Operation succeeded
- **Failed** - Operation failed with an error
- **Warning** - Operation skipped due to validation (e.g., already exists, already assigned)

**NEVER use**: "Skipped", "Success", "Error", or any other status values.

## WhatIf Parameter Behavior
When `-WhatIf` is used:
1. Perform all validation checks (user exists, role exists, scope exists, duplicates, etc.)
2. If validation **passes**: Display the API request details (URI, Method, Headers, Body)
3. If validation **fails**: Show warning with "Cannot display API request." and return immediately
4. **NEVER** make the actual API call
5. **NEVER** return a status object when validation fails

### Write-Warning Usage with -WhatIf
**CRITICAL RULE**: `Write-Warning` should **ONLY** be used with `-WhatIf` for **validation failures**, NOT for errors

- **With -WhatIf and validation failure** (like "already exists"): Use `Write-Warning` to explain why API request cannot be displayed
- **With -WhatIf and authentication/session error**: Use `$PSCmdlet.ThrowTerminatingError($_)` to properly terminate
- **Without -WhatIf**: Return status object with "Warning" status - **NO Write-Warning**

### Example Pattern - Validation Failure:
```powershell
# Check for duplicate (this is a validation, not an error)
if ($AlreadyExists) {
    if ($WhatIf) {
        $ErrorMessage = "Item '{0}' already exists! Cannot display API request." -f $Object.SerialNumber, $GroupName
        Write-warning $ErrorMessage
        return/continue
    }

    # Must return a message if server not member of the group
    $Object.Status = "Warning"
    $Object.Details = "Server is not a member of the group!"
}
# or
if ($AlreadyExists) {
    if ($WhatIf) {
        Write-Warning "Error message"
        return/continue
    }
    else {
        $Object.Status = "Failed"
        $Object.Details = "Error details"
    }
}
```


### Example Pattern - Authentication/Session Error:
```powershell
# Catch block for API calls that might fail due to authentication
try {
    $result = Invoke-HPEGLWebRequest -Method Get -Uri $uri
}
catch {
    # Authentication/session errors should terminate, not just warn
    if ($WhatIf) {
        $PSCmdlet.ThrowTerminatingError($_)  # Throw error, don't warn
    }
    else {
        $objStatus.Status = "Failed"
        $objStatus.Details = $_.Exception.Message
        [void]$StatusList.Add($objStatus)
        return
    }
}
```

**Why this distinction?**
- **Validation failures** (like duplicates): Expected scenarios that should show as warnings
- **Authentication/session errors**: Unexpected failures that should terminate with proper error messages
- With `-WhatIf`: Validation warnings are informative; auth errors need immediate attention and proper error display
- Without `-WhatIf`: Status object provides structured output; warnings would pollute pipeline/automation

## Pre-Validation Pattern
**Always perform pre-validation checks BEFORE attempting the API call:**
1. Check if user/group exists
2. Check if role exists
3. Check if scope group exists
4. **Check for duplicates** (role already assigned, user already exists, etc.)
5. Only proceed with API call if all validations pass

### Duplicate Detection:
- Use GET API to query existing assignments/items
- Compare all relevant fields (role, scope, subject, etc.)
- Show warning if duplicate found
- Status = "Warning" with message "Already exists. No action needed."

## Error Handling Conventions
- **Get-\* cmdlets**: Return nothing silently for "not found" (no error)
- **Add-\*/Remove-\* cmdlets**: Throw terminating errors for invalid parameters
- **Set-\*/Update-\* cmdlets**: Throw terminating errors for validation failures

### Try/Catch Blocks and Error Propagation

#### When Calling Get-* Functions from Your Module:

**RULE**: When calling Get-HPE* functions inside other functions, wrap in try/catch to prevent duplicate error messages.

✅ **CORRECT - Clean single error message:**
```powershell
try {
    $ExistingUser = Get-HPEGLUser -Email $Email
}
catch {
    $PSCmdlet.ThrowTerminatingError($_)
}

if ($ExistingUser) {
    # User exists, handle accordingly
}
```

**Why:** Get-* functions return `$null` for "not found" but throw errors for authentication/session failures. Without try/catch, errors display twice (once from Get-*, once from calling function).

#### Empty Catch Blocks

❌ **WRONG - Never use empty catch blocks without fallback logic:**
```powershell
try {
    $ExistingUser = Get-HPEGLUser -Email $Email
}
catch {
    # Empty - suppresses authentication errors!
}
```

✅ **ACCEPTABLE - Empty catch with explicit fallback:**
```powershell
try { 
    $parsedError = $errorString | ConvertFrom-Json -ErrorAction Stop 
}
catch {}
$errorMsg = if ($parsedError) { $parsedError.message } else { $errorString }
```

### Catch Block Error Messages
**CRITICAL RULE**: In catch blocks, use the exception message directly without appending extra text.

❌ **WRONG - Don't append extra text:**
```powershell
catch {
    Write-Warning "$($_.Exception.Message) Cannot display API request."
}

catch {
    Write-Warning "Error retrieving user: $($_.Exception.Message). Cannot display API request."
}
```

✅ **CORRECT - Use exception message directly:**
```powershell
catch {
    Write-Warning $_.Exception.Message
}

catch {
    $objStatus.Status = "Failed"
    $objStatus.Details = if ($Global:HPECOMInvokeReturnData.message) { 
        $Global:HPECOMInvokeReturnData.message 
    } else { 
        $_.Exception.Message 
    }
}
```

**Why this matters:**
- Exception messages are already complete and descriptive
- Appending "Cannot display API request." is redundant and confusing
- Users get cleaner, more professional error messages
- Status objects should capture the actual error, not generic text

**Note:** "Cannot display API request." should ONLY appear in WhatIf validation blocks (not catch blocks) when pre-validation fails and prevents the API request from being shown.

### Throwing Errors - Multi-line vs Single-line

**CRITICAL RULE**: Use `Write-Error` with `-ErrorAction Stop` for multi-line error messages. Use `throw` only for simple single-line errors.

❌ **WRONG - Don't use throw with multi-line here-strings:**
```powershell
throw @"
Multi-line error message
with details
and examples
"@
```

✅ **CORRECT - Use Write-Error with -ErrorAction Stop for multi-line messages:**
```powershell
Write-Error @"
Multi-line error message
with details
and examples
"@ -ErrorAction Stop
```

✅ **CORRECT - Use throw for simple single-line errors:**
```powershell
throw "Simple error message without formatting"
```

**Why this matters:**
- `throw` with here-strings doesn't preserve formatting properly in PowerShell error output
- `Write-Error` with `-ErrorAction Stop` displays multi-line messages correctly with proper line breaks
- `throw` is fine for simple single-line error messages
- `-ErrorAction Stop` makes `Write-Error` a terminating error (same behavior as `throw`)

## Code Reuse and Simplicity

### Golden Rule: Always Use Existing Functions First
**Before writing ANY new API call, check if an existing function already provides the data.**

This is the **#1 most important principle** for code quality and maintainability.

❌ **WRONG:**
```powershell
# Don't make direct API calls for data that existing functions provide
$Uri = "{0}/some/api/endpoint" -f (Get-HPEGLAPIOrgbaseURL)
$Response = Invoke-HPEGLWebRequest -Method GET -Uri $Uri
```

✅ **CORRECT:**
```powershell
# Use existing Get-* functions
$ExistingData = Get-HPEGLUserRole -Email $Email -Verbose:$false
$ExistingData = Get-HPEGLUser -Email $Email -Verbose:$false
$ExistingData = Get-HPEGLScopeGroup -Name $Name -Verbose:$false
```

**Why this matters:**
- Simpler, more readable code
- Less chance of bugs
- Consistent behavior across the module
- Better performance (existing functions may have optimizations)
- Easier maintenance

**When to use Invoke-HPEGLWebRequest:**
- ONLY for POST/PUT/DELETE operations (creating/modifying/deleting)
- ONLY when no existing Get-* function provides the needed data
- For new API endpoints not yet implemented

## Output Objects

### Object Structure
- Use descriptive property names (e.g., `Email` not `UserEmail`)
- Include: Status, Details, Exception (if applicable)
- Build objects in Process block, add to ArrayList

### Output Formatting (End Block)
**Always use `Invoke-RepackageObjectWithType` at the end:**
```powershell
End {
    if (-not $WhatIf -and $StatusList.Count -gt 0) {
        $StatusList = Invoke-RepackageObjectWithType -RawObject $StatusList -ObjectName "ObjectType.Name"
        Return $StatusList
    }
}
```

### Format Definitions (HPECOMCmdlets.Format.ps1xml)
**CRITICAL**: When you create a new function that returns status objects, you **MUST** add a format definition to `HPECOMCmdlets.Format.ps1xml`.

Without a format definition, the output will display as raw PSObject properties instead of a nice formatted table.

**Steps:**
1. Create format view with TypeName matching the ObjectName used in `Invoke-RepackageObjectWithType`
2. Example: If using `"RoleModification.User"`, create format for `HPEGreenLake.RoleModification.User`
3. Define table columns matching the object properties
4. Use PropertyName or ScriptBlock for column values

**Example:**
```xml
<View>
    <Name>User Role Modification Status</Name>
    <ViewSelectedBy>
        <TypeName>HPEGreenLake.RoleModification.User</TypeName>
    </ViewSelectedBy>
    <TableControl>
        <TableHeaders>
            <TableColumnHeader><Label>Email</Label></TableColumnHeader>
            <TableColumnHeader><Label>RoleName</Label></TableColumnHeader>
            <TableColumnHeader><Label>OldScope</Label></TableColumnHeader>
            <TableColumnHeader><Label>NewScope</Label></TableColumnHeader>
            <TableColumnHeader><Label>Status</Label></TableColumnHeader>
            <TableColumnHeader><Label>Details</Label></TableColumnHeader>
            <TableColumnHeader><Label>Exception</Label></TableColumnHeader>
        </TableHeaders>
        <TableRowEntries>
            <TableRowEntry>
                <TableColumnItems>
                    <TableColumnItem><PropertyName>Email</PropertyName></TableColumnItem>
                    <TableColumnItem><PropertyName>RoleName</PropertyName></TableColumnItem>
                    <TableColumnItem>
                        <ScriptBlock>
                            if ($_.OldScope -is [array]) {
                                $_.OldScope -join ', '
                            } else {
                                $_.OldScope
                            }
                        </ScriptBlock>
                    </TableColumnItem>
                    <TableColumnItem>
                        <ScriptBlock>
                            if ($_.NewScope -is [array]) {
                                $_.NewScope -join ', '
                            } else {
                                $_.NewScope
                            }
                        </ScriptBlock>
                    </TableColumnItem>
                    <TableColumnItem><PropertyName>Status</PropertyName></TableColumnItem>
                    <TableColumnItem><PropertyName>Details</PropertyName></TableColumnItem>
                    <TableColumnItem><PropertyName>Exception</PropertyName></TableColumnItem>
                </TableColumnItems>
            </TableRowEntry>
        </TableRowEntries>
    </TableControl>
</View>
```

**Use ScriptBlock for:**
- Array properties that need to be joined with commas (e.g., `$_.OldScope -join ', '`)
- Conditional formatting
- Calculated values

**Testing Format:**
After adding the format definition, reload the module and test the output:
```powershell
Import-Module .\HPECOMCmdlets.psd1 -Force
YourNewFunction -Parameters | Format-Table  # Should show nice formatted table
```

## API Response Handling
Check for partial success responses (HTTP 206):
```powershell
if ($Response.failed -and $Response.failed.error_response.details.errorCode -eq "HPE_GL_AUTHORIZATION_ALREADY_CREATED") {
    # Handle as Warning status
}
```

## Verbose Logging

### Required Verbose Messages
Always include verbose messages for:
- Bound parameters (at start of Process block)
- Function caller information (in Begin block)
- API calls being made
- Validation results
- Errors encountered

### Standard Verbose Patterns

**Begin Block - Caller Information:**
```powershell
Begin {
    $Caller = (Get-PSCallStack)[1].Command
    "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
}
```

**Process Block - Bound Parameters (REQUIRED):**
```powershell
Process {
    "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
    
    # Rest of process logic
}
```

**General Verbose Messages:**
```powershell
# User/resource found
"[{0}] Found user '{1}' with ID: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Email, $UserId | Write-Verbose

# API call result
"[{0}] Role '{1}' successfully assigned to user '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $RoleName, $Email | Write-Verbose

# Validation results
"[{0}] Role is not currently assigned to user, proceeding with assignment" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

# Errors
"[{0}] Error retrieving user: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
```

### Verbose Message Format
- Always use uppercase function name: `$MyInvocation.InvocationName.ToString().ToUpper()`
- Always use string formatting with -f operator
- Format: `"[FUNCTIONNAME] Message text"`
- Include relevant variable values in messages

## ArgumentCompleter Guidelines
- Use for parameters with finite, reasonable lists (~50-100 items)
- Performance should be acceptable (~1 second max)
- Add quotes for multi-word values: `if ($_ -match '\s') { "'$_'" } else { $_ }`
- **DO NOT use** for parameters that could have 1000+ items (e.g., scope groups)
- Return empty array on error: `catch { @() }`

## Function Documentation
Include in comment-based help:
- Clear description of what the function does
- All parameter descriptions
- Examples showing common usage patterns
- Notes about special behaviors (e.g., WhatIf, duplicate detection)

## Constants Management

### Constants.psm1 File
All API endpoints, base URLs, and other constants are stored in `Modules\Constants.psm1`.

### Naming Convention for Constants
**Use simple, clean names WITHOUT API versions:**

✅ **CORRECT:**
```powershell
$RoleAssignmentsUri = "/internal-platform-tenant-ui/role-assignments"
$RolesUri = "/internal-platform-tenant-ui/roles"
```

❌ **WRONG:**
```powershell
$RoleAssignmentsV2Alpha2Uri = "/internal-platform-tenant-ui/v2alpha2/role-assignments"
$RolesV2Uri = "/internal-platform-tenant-ui/v2/roles"
```

### Adding New Constants
When creating a new function that requires a new API endpoint:
1. Add the constant to `Modules\Constants.psm1`
2. Use a descriptive name without version numbers
3. Include the full URI path with version in the constant value
4. **Create a getter function for the constant**
5. Reference the getter function in your function (NOT the constant directly)

**Example:**
```powershell
# In Constants.psm1
[String]$UsersUri = $HPEGLAPIOrgbaseURL + '/identity/v2beta1/scim/v2/Users'
function Get-UsersUri { $script:UsersUri }

[String]$WorkspaceUsersUri = $HPEGLAPIOrgbaseURL + '/workspaces/v2alpha1/workspaces'
function Get-WorkspaceUsersUri { $script:WorkspaceUsersUri }

# In your function - use the getter function
$Uri = Get-UsersUri
$DeleteUri = $Uri + "/" + $User.id
```

**❌ WRONG - Never hardcode URIs in .psm1 files:**
```powershell
# DON'T DO THIS:
$BaseUri = $HPEGLAPIOrgbaseURL + "/workspaces/v2alpha1/workspaces/$WorkspaceId/users"
```

**✅ CORRECT - Always use getter functions:**
```powershell
# DO THIS:
$BaseUri = (Get-WorkspaceUsersUri) + "/$WorkspaceId/users"
```

This approach:
- Centralizes all URI definitions in Constants.psm1
- Allows easy version updates without changing function code
- Maintains consistency across the entire codebase
- Uses getter functions to access constants (not direct variable access)

## Global Variables and Session Tracking

### $Global:HPEGreenLakeSession Object
The module maintains a global tracking object `$Global:HPEGreenLakeSession` that contains essential session information.

**ALWAYS use this object instead of making extra API requests to retrieve:**
- `$Global:HPEGreenLakeSession.workspaceId` - Current workspace ID
- `$Global:HPEGreenLakeSession.workspaceName` - Current workspace name
- `$Global:HPEGreenLakeSession.username` - Logged in user
- `$Global:HPEGreenLakeSession.glpApiAccessTokenv1_2` - Access token
- Other session-related data

### Best Practice
✅ **CORRECT - Use global session data:**
```powershell
$WorkspaceId = $Global:HPEGreenLakeSession.workspaceId
$WorkspaceGrn = "grn:glp/workspaces/$WorkspaceId"
```

❌ **WRONG - Don't make unnecessary API calls:**
```powershell
$Workspace = Get-HPEGLWorkspace -Current
$WorkspaceId = $Workspace.id
```

### Benefits
- Faster execution (no extra API calls)
- Reduced API load
- Consistent data across functions
- Session information already available from Connect-HPEGL

**Always check $Global:HPEGreenLakeSession first before making API calls to retrieve basic session information.**

## API Request Wrapper - Invoke-HPEGLWebRequest

### Using the Custom Wrapper
**ALWAYS use `Invoke-HPEGLWebRequest` (for GreenLake APIs) and `Invoke-HPECOMWebRequest` (for COM APIs) instead of `Invoke-RestMethod` or `Invoke-WebRequest`.**

This custom wrapper provides:
- Automatic authentication with session tokens
- Automatic pagination handling
- Retry logic for transient failures
- Consistent error handling
- Response data in `$Global:HPECOMInvokeReturnData`

### Basic Usage
```powershell
# For GreenLake APIs
$Response = Invoke-HPEGLWebRequest -Method GET -Uri $Uri -Verbose:$VerbosePreference

# For COM APIs
$Response = Invoke-HPECOMWebRequest -Method GET -Uri $Uri -Verbose:$VerbosePreference
```

### WhatIf Support
**CRITICAL**: Functions must declare `-WhatIf` as a manual `[Switch]` parameter. Do NOT use `SupportsShouldProcess`.

Always declare the parameter and pass it to `Invoke-HPEGLWebRequest` or `Invoke-HPECOMWebRequest` using `-WhatIfBoolean`:

```powershell
# In function parameters
Param(
    [Switch]$WhatIf
)

# When calling Invoke-HPEGLWebRequest (for GreenLake APIs)
$Response = Invoke-HPEGLWebRequest -Method POST -Uri $Uri -Body $Payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

# When calling Invoke-HPECOMWebRequest (for COM APIs)
$Response = Invoke-HPECOMWebRequest -Method POST -Uri $Uri -Body $Payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
```

### Response Data Object - $Global:HPECOMInvokeReturnData
After any API call, error details are available in `$Global:HPECOMInvokeReturnData`:
- `$Global:HPECOMInvokeReturnData.message` - Error message from API
- `$Global:HPECOMInvokeReturnData.errorCode` - API error code
- `$Global:HPECOMInvokeReturnData.httpStatusCode` - HTTP status code

**Use this for error handling:**
```powershell
catch {
    $objStatus.Status = "Failed"
    $objStatus.Details = if ($Global:HPECOMInvokeReturnData.message) { 
        $Global:HPECOMInvokeReturnData.message 
    } else { 
        "Operation failed: $($_.Exception.Message)" 
    }
}
```

### Skip Pagination Limit
For operations that need to handle large result sets or special API behaviors:
```powershell
# For GreenLake APIs
$Response = Invoke-HPEGLWebRequest -Method GET -Uri $Uri -SkipPaginationLimit -Verbose:$VerbosePreference

# For COM APIs
$Response = Invoke-HPECOMWebRequest -Method GET -Uri $Uri -SkipPaginationLimit -Verbose:$VerbosePreference
```

Use `-SkipPaginationLimit` when:
- API doesn't support pagination
- Need to retrieve all results in one call
- Working with internal/admin APIs that handle pagination differently

### Skip Session Check
For special API calls that don't require standard session validation:
```powershell
# For GreenLake APIs
$Response = Invoke-HPEGLWebRequest -Method POST -Body $Payload -Uri $Uri -SkipSessionCheck -Verbose:$VerbosePreference

# For COM APIs
$Response = Invoke-HPECOMWebRequest -Method POST -Body $Payload -Uri $Uri -SkipSessionCheck -Verbose:$VerbosePreference
```

### Common Patterns

**GET Request:**
```powershell
# GreenLake API
$Uri = "{0}{1}" -f (Get-HPEGLAPIOrgbaseURL), $ApiEndpoint
$Response = Invoke-HPEGLWebRequest -Method GET -Uri $Uri -Verbose:$VerbosePreference

# COM API
$Uri = "{0}{1}" -f (Get-HPECOMAPIOrgbaseURL), $ApiEndpoint
$Response = Invoke-HPECOMWebRequest -Method GET -Uri $Uri -Verbose:$VerbosePreference
```

**POST Request with WhatIf:**
```powershell
# GreenLake API
$Payload = $Data | ConvertTo-Json -Depth 10
$Uri = "{0}{1}" -f (Get-HPEGLAPIOrgbaseURL), $ApiEndpoint
$Response = Invoke-HPEGLWebRequest -Method POST -Uri $Uri -Body $Payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

# COM API
$Payload = $Data | ConvertTo-Json -Depth 10
$Uri = "{0}{1}" -f (Get-HPECOMAPIOrgbaseURL), $ApiEndpoint
$Response = Invoke-HPECOMWebRequest -Method POST -Uri $Uri -Body $Payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
```

**Error Handling:**
```powershell
try {
    # For GreenLake APIs
    $Response = Invoke-HPEGLWebRequest -Method POST -Uri $Uri -Body $Payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
    
    # For COM APIs
    $Response = Invoke-HPECOMWebRequest -Method POST -Uri $Uri -Body $Payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
    
    # Check for specific error patterns in response
    if ($Response.failed -and $Response.failed.error_response.details.errorCode -eq "SPECIFIC_ERROR") {
        # Handle specific error
    }
}
catch {
    $objStatus.Status = "Failed"
    $objStatus.Details = if ($Global:HPECOMInvokeReturnData.message) { 
        $Global:HPECOMInvokeReturnData.message 
    } else { 
        "Operation failed: $($_.Exception.Message)" 
    }
}
```

## Module Export Requirements

### Adding New Functions to the Module
When creating a new function, you **MUST** add it to **TWO** places:

1. **Individual .psm1 module file** (e.g., `Modules/GLP-Users-Roles-Permissions.psm1`) - Export-ModuleMember at the end of that specific module file
2. **HPECOMCmdlets.psd1** - FunctionsToExport array in the root manifest file

**Note**: The function definition itself goes in the appropriate module file under `Modules/`, but that's where you're writing the function code - the export requirement is separate.

### Step 1: Individual Module File Export (e.g., GLP-Users-Roles-Permissions.psm1)
**CRITICAL**: Each .psm1 file in the `Modules/` folder has its own `Export-ModuleMember` at the end. You MUST add your function there first.

**Example** - At the end of `Modules/GLP-Users-Roles-Permissions.psm1`:
```powershell
# Export only public functions and aliases
Export-ModuleMember -Function 'Get-HPEGLUser', 'New-HPEGLUser', 'Send-HPEGLUserInvitation', 'Remove-HPEGLUser', 'Get-HPEGLRole', 'Get-HPEGLUserRole', 'Add-HPEGLRoleToUser', `
'Remove-HPEGLRoleFromUser', 'Set-HPEGLUserRole',  ` # <-- Add your new function here
'Get-HPEGLUserGroup', 'New-HPEGLUserGroup', 'Remove-HPEGLUserGroup', 'Set-HPEGLUserGroup' `
-Alias *
```

**IMPORTANT**: The individual module files use explicit function name strings, NOT an array with @(). 
- ✅ Correct: `Export-ModuleMember -Function 'Func1', 'Func2', 'Func3'`
- ❌ Wrong: `Export-ModuleMember -Function @('Func1', 'Func2', 'Func3')`

### Step 2: Root Module Manifest (HPECOMCmdlets.psd1)
Add the function name to the `FunctionsToExport` array in the root module manifest:

**Example** - In root `HPECOMCmdlets.psd1`:
```powershell
# In HPECOMCmdlets.psd1
FunctionsToExport = @(
    'Connect-HPEGL',
    'Get-HPEGLUser',
    'Add-HPEGLRoleToUser',
    'Remove-HPEGLRoleFromUser',
    'Set-HPEGLUserRole',  # <-- Add your new function here
    # ... other functions
)
```

### Module Structure
The module uses nested module structure:
- Root: `HPECOMCmdlets.psm1` and `HPECOMCmdlets.psd1`
- Nested modules: `Modules/GLP-Users-Roles-Permissions.psm1`, `Modules/COM-Servers.psm1`, etc.

Each nested module exports its own functions, which are then re-exported by the root manifest.

### Alphabetical Order
Maintain alphabetical order within functional groups (Connect, Get, Add, Set, Remove, etc.) for easier maintenance.

### Verification
After adding a new function, verify it's exported correctly:
```powershell
Import-Module .\HPECOMCmdlets.psd1 -Force
Get-Command -Module HPECOMCmdlets -Name YourNewFunction
```

**If the function doesn't appear:**
1. Check the individual module file's Export-ModuleMember (e.g., `Modules/GLP-Users-Roles-Permissions.psm1`)
2. Check the root manifest's FunctionsToExport (`HPECOMCmdlets.psd1`)
3. Verify function syntax is correct (no PowerShell parsing errors)

### Common Mistakes
❌ **Forgetting the individual module export** - Most common error! Each .psm1 file needs its own Export-ModuleMember
❌ **Only adding to .psd1** - Not sufficient, the individual module must export it first
❌ **Using wrong syntax** - Individual modules use quoted strings with backticks, not @() arrays
❌ **Typo in function name** - Function name must match exactly in all three places

## Testing Guidelines

### No Test Files
**DO NOT generate test files or test scripts.**

The preferred testing approach is:
- Test one example at a time using the execution button in VS Code
- Test directly in the terminal/console
- Use real function calls, not test frameworks
- If you need to create a script for some important reasons, create it in Private\AI scripts
- If you need to create a makdown file for some important reasons, create it in Private\AI reports

### Test Commands
When providing test examples, use **direct function calls only**:

✅ **CORRECT:**
```powershell
Add-HPEGLRoleToUser -Email user@example.com -RoleName 'Workspace Administrator' 
```

❌ **WRONG - Don't use Write-Host or test frameworks:**
```powershell
Write-Host "Testing Add-HPEGLRoleToUser..."
$result = Add-HPEGLRoleToUser -Email user@example.com -RoleName 'Workspace Administrator' 
Write-Host "Test completed: $($result.Status)"
```

### Testing Approach
1. Provide clean, executable examples
2. Test with actual API calls (when connected)
3. Test with `-WhatIf` first to verify API call structure
4. Test error scenarios (invalid parameters, duplicates, etc.)
5. No output formatting or decorative messages in test code

**Keep test examples simple and direct - just the function call.**

### Required Test Scenarios
When testing a function, provide examples for **ALL** these scenarios:

#### 1. Success Case
```powershell
Add-HPEGLRoleToUser -Email user@example.com -RoleName 'Workspace Administrator' 
```

#### 2. Success Case with -WhatIf
```powershell
Add-HPEGLRoleToUser -Email user@example.com -RoleName 'Workspace Administrator'  -WhatIf
```

#### 3. Pre-Validation Failures (without -WhatIf)
Test each validation scenario:
```powershell
# Invalid user
Add-HPEGLRoleToUser -Email invalid@example.com -RoleName 'Workspace Administrator' 

# Invalid role
Add-HPEGLRoleToUser -Email user@example.com -RoleName 'Invalid Role Name' -

# Invalid scope group
Add-HPEGLRoleToUser -Email user@example.com -RoleName 'Workspace Administrator' -ScopeGroupName 'NonExistentGroup'

# Duplicate (already assigned)
Add-HPEGLRoleToUser -Email user@example.com -RoleName 'Workspace Administrator' 
```

#### 4. Pre-Validation Failures (with -WhatIf)
Test same validation scenarios with -WhatIf to ensure "Cannot display API request" message:
```powershell
# Invalid user with WhatIf
Add-HPEGLRoleToUser -Email invalid@example.com -RoleName 'Workspace Administrator'  -WhatIf

# Invalid role with WhatIf
Add-HPEGLRoleToUser -Email user@example.com -RoleName 'Invalid Role Name'  -WhatIf

# Duplicate with WhatIf
Add-HPEGLRoleToUser -Email user@example.com -RoleName 'Workspace Administrator'  -WhatIf
```

#### 5. All Parameter Sets
Test all parameter combinations:
```powershell
# Entire workspace
Add-HPEGLRoleToUser -Email user@example.com -RoleName 'Role Name' 

# Single scope group
Add-HPEGLRoleToUser -Email user@example.com -RoleName 'Role Name' -ScopeGroupName 'GroupName'

# Multiple scope groups
Add-HPEGLRoleToUser -Email user@example.com -RoleName 'Role Name' -ScopeGroupName 'Group1','Group2'
```

### Expected Outcomes
- **Success**: Status = "Complete", appropriate details message
- **Validation Failure**: Status = "Failed" or "Warning", clear error message
- **Duplicate**: Status = "Warning", message stating already exists
- **WhatIf Success**: Display API call details (URI, Method, Body)
- **WhatIf Validation Failure**: Warning with "Cannot display API request" + return

**Always test comprehensively across all scenarios before considering a function complete.**

## Pipeline Support

### Pipeline Input Requirements
**All functions MUST support pipeline input wherever possible.**

### Parameter Attributes for Pipeline
Use appropriate parameter attributes to enable pipeline support:

```powershell
[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
[String]$Email

[Parameter(Mandatory, ValueFromPipelineByPropertyName)]
[String]$RoleName
```

### Pipeline Pattern
Functions should support:
1. **ValueFromPipeline** - Accept objects directly from pipeline
2. **ValueFromPipelineByPropertyName** - Accept objects with matching property names

### Example Pipeline Usage
```powershell
# Single object
Get-HPEGLUser -Email user@example.com | Add-HPEGLRoleToUser -RoleName 'Workspace Administrator' 

# Multiple objects
Get-HPEGLUser | Where-Object { $_.email -like "*@example.com" } | Add-HPEGLRoleToUser -RoleName 'Viewer' 

# CSV import
Import-Csv users.csv | Add-HPEGLRoleToUser -RoleName 'Workspace Administrator' 
```

### Process Block Required
When supporting pipeline, use Process block to handle each object:

```powershell
Begin {
    $ResultsList = [System.Collections.ArrayList]::new()
}

Process {
    # Process each pipeline object here
    foreach ($item in $InputObject) {
        # Handle each item
    }
}

End {
    if (-not $WhatIf -and $ResultsList.Count -gt 0) {
        $ResultsList = Invoke-RepackageObjectWithType -RawObject $ResultsList -ObjectName "Type.Name"
        Return $ResultsList
    }
}
```

## Parameter Validation

### Use Parameter Sets
Define parameter sets for mutually exclusive options:

```powershell
[Parameter(Mandatory, ParameterSetName = 'EntireWorkspace')]
[Switch]$EntireWorkspace

[Parameter(Mandatory, ParameterSetName = 'ScopeGroups')]
[String[]]$ScopeGroupName
```

### Parameter Validation Attributes
Use built-in validation attributes:

```powershell
# Validate not null or empty
[Parameter(Mandatory)]
[ValidateNotNullOrEmpty()]
[String]$Email

# Validate email format
[ValidatePattern('^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')]
[String]$Email

# Validate against a set of values (for small, static lists)
[ValidateSet('Low', 'Medium', 'High')]
[String]$Priority

# Validate count for arrays
[ValidateCount(1, 10)]
[String[]]$Items

# Validate script condition
[ValidateScript({
    if ($_ -match '^\d+$') { $true }
    else { throw "Must be a numeric value" }
})]
[String]$Value
```

### Parameter Dependencies
Document parameter relationships in help:
```powershell
<#
.PARAMETER ScopeGroupName
Scope group name(s) for the role assignment. Cannot be used with -EntireWorkspace.
Requires the role to support scope group assignment.
#>
```

### Common Validation Patterns
```powershell
# Email parameter
[Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
[ValidateNotNullOrEmpty()]
[String]$Email

# Array parameter with validation
[Parameter(Mandatory)]
[ValidateNotNullOrEmpty()]
[ValidateCount(1, 100)]
[String[]]$RoleNames

# Mutually exclusive switches
[Parameter(Mandatory, ParameterSetName = 'ByName')]
[String]$Name

[Parameter(Mandatory, ParameterSetName = 'ById')]
[String]$Id
```

**Always implement pipeline support and proper parameter validation to ensure robust, user-friendly functions.**

## Performance Optimization

### Critical Performance Considerations
This module will be used with **thousands of resources** in enterprise HPE GreenLake environments. Always optimize for performance and response time.

### Golden Rule: ALWAYS Use Existing Functions First

**MOST IMPORTANT RULE**: Before writing any new API call with `Invoke-HPEGLWebRequest`, **ALWAYS check if an existing Get-* function already provides the data you need.**

❌ **WRONG - Over-complicated with direct API calls:**
```powershell
# Checking if role is already assigned - BAD APPROACH
$CheckUri = "{0}/internal-platform-tenant-ui/v2alpha2/role-assignments?subject=user:{1}&role-grn={2}" -f (Get-HPEGLAPIOrgbaseURL), $UserId, $RoleGrn
$ExistingAssignments = Invoke-HPEGLWebRequest -Method GET -Uri $CheckUri -Verbose:$false
# Then complicated logic to parse and compare scopes...
```

✅ **CORRECT - Use existing function:**
```powershell
# Checking if role is already assigned - CORRECT APPROACH
$ExistingUserRoles = Get-HPEGLUserRole -Email $Email -Verbose:$false
$ExistingRole = $ExistingUserRoles | Where-Object { $_.role -eq $RoleName }
if ($ExistingRole) {
    # Simple, readable logic using familiar properties
}
```

**Benefits of using existing functions:**
1. **Simpler code** - Less complexity, easier to maintain
2. **More reliable** - Already tested and working
3. **Better performance** - Often optimized with caching/pagination
4. **Consistent behavior** - Same data format across all functions
5. **Less duplication** - Reuse existing logic instead of reimplementing

**When to use Invoke-HPEGLWebRequest directly:**
- ONLY when no existing Get-* function provides the needed data
- ONLY for POST/PUT/DELETE operations (modifications)
- For new features not yet implemented in any function

### Performance Best Practices

**1. Minimize API Calls**
- **AVOID**: Making multiple API calls when one will suffice
- **AVOID**: Calling Get-* functions multiple times for the same data
- **DO**: Cache results in variables when data is used multiple times
- **DO**: Use pagination limits appropriately

```powershell
# BAD - Multiple redundant calls
foreach ($user in $users) {
    $role = Get-HPEGLRole -Name $roleName  # Called repeatedly!
    # Process...
}

# GOOD - Single call, cache result
$role = Get-HPEGLRole -Name $roleName
foreach ($user in $users) {
    # Use cached $role
    # Process...
}
```

**2. Avoid Expensive Operations in Loops**
- **AVOID**: Calling `Get-HPEGLRole` without parameters (retrieves all roles from all services)
- **AVOID**: Calling functions with `-ShowAssignments`, `-ShowUsers`, or similar switches inside loops
- **DO**: Filter data after retrieval rather than making multiple filtered API calls
- **DO**: Use specific parameters to limit data retrieval

```powershell
# BAD - Expensive call in loop
foreach ($scopeGroup in $scopeGroups) {
    $group = Get-HPEGLScopeGroup -Name $scopeGroup  # Individual API calls
}

# GOOD - Single bulk call, then filter
$allScopeGroups = Get-HPEGLScopeGroup
foreach ($scopeGroupName in $scopeGroupNames) {
    $group = $allScopeGroups | Where-Object { $_.name -eq $scopeGroupName }
}
```

**3. ArgumentCompleter Performance**
- **AVOID**: Using ArgumentCompleter for resources with 1000+ items (scope groups, servers, etc.)
- **DO**: Use ArgumentCompleter only for manageable datasets (<100-200 items)
- **DO**: Test ArgumentCompleter performance - target <1000ms response time
- **DO**: Add `-Verbose:$false` and `-ErrorAction SilentlyContinue` to Get-* calls in ArgumentCompleters

```powershell
# GOOD - ArgumentCompleter with performance optimizations
[ArgumentCompleter({
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    try {
        # Disable verbose and error output for speed
        $allRoles = (Get-HPEGLRole -Verbose:$false -ErrorAction SilentlyContinue).role_display_name
        
        $allRoles | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            $completionText = if ($_ -match '\s') { "'$_'" } else { $_ }
            [System.Management.Automation.CompletionResult]::new($completionText, $_, 'ParameterValue', $_)
        }
    }
    catch { @() }  # Fail silently
})]
```

**4. Efficient Data Processing**
- **AVOID**: Using `+=` to build arrays (reallocates memory each time)
- **DO**: Use `[System.Collections.ArrayList]` for building result collections
- **DO**: Use `-join` instead of repeated string concatenation
- **DO**: Use `.Add()` method with `[void]` to suppress output

```powershell
# BAD - Slow for large datasets
$results = @()
foreach ($item in $items) {
    $results += $item  # Reallocates entire array each iteration
}

# GOOD - Fast for any size
$results = [System.Collections.ArrayList]::new()
foreach ($item in $items) {
    [void]$results.Add($item)  # Efficient in-place addition
}
```

**5. Leverage Global Session Data**
- **DO**: Use `$Global:HPEGreenLakeSession.workspaceId` instead of API calls
- **DO**: Use `$Global:HPEGreenLakeSession.username` when available
- **AVOID**: Making API calls to retrieve data that's already in the session

```powershell
# GOOD - Use cached session data
$WorkspaceId = $Global:HPEGreenLakeSession.workspaceId
$ScopeGrn = "grn:glp/workspaces/$WorkspaceId/regions/default/providers/authorization/scope-groups/$ScopeGroupId"
```

**6. Pagination Strategy**
- **DO**: Use pagination for large datasets (default page size is usually 100-500)
- **DO**: Use `-SkipPaginationLimit` parameter when you need all results
- **AVOID**: Requesting more data than needed

**7. Parallel Processing Considerations**
- **CONSIDER**: Using `ForEach-Object -Parallel` for independent operations on large datasets (PowerShell 7+)
- **CAUTION**: Be aware of API rate limits when parallelizing
- **TEST**: Always verify parallel operations don't overwhelm the API

### Performance Testing
- **DO**: Test functions with realistic enterprise-scale datasets (100s-1000s of items)
- **DO**: Measure execution time for critical operations
- **DO**: Profile and optimize bottlenecks before releasing

### Example: Performance-Optimized Function Pattern
```powershell
Function Add-HPEGLRoleToUsers {
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory, ValueFromPipeline)]
        [String[]]$Emails,
        
        [Parameter(Mandatory)]
        [String]$RoleName
    )
    
    Begin {
        # OPTIMIZE: Get role once before processing pipeline
        $Role = Get-HPEGLRole -Verbose:$false | Where-Object { $_.role_display_name -eq $RoleName }
        if (-not $Role) {
            throw "Role '$RoleName' not found"
        }
        
        # OPTIMIZE: Use ArrayList for results
        $Results = [System.Collections.ArrayList]::new()
    }
    
    Process {
        # Process each email efficiently using cached role data
        foreach ($Email in $Emails) {
            # Process with $Role (already retrieved)
            [void]$Results.Add($objStatus)
        }
    }
    
    End {
        if ($Results.Count -gt 0) {
            $Results = Invoke-RepackageObjectWithType -RawObject $Results -ObjectName "RoleAssignment.Status"
            Return $Results
        }
    }
}
```

**Key Performance Principle**: *"Call once, use many times"* - Retrieve data once and reuse it throughout the function execution.

---

**NOTE TO AI**: Always reference this file when creating or modifying functions. These patterns are established and should be followed consistently without asking for confirmation.
