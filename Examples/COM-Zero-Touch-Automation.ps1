<#
.SYNOPSIS
    HPE Compute Ops Management Zero Touch Automation Example

.DESCRIPTION
    Demonstrates complete end-to-end automation for onboarding HPE servers into HPE GreenLake and 
    Compute Ops Management. This script automates the entire lifecycle from workspace provisioning 
    through server configuration, policy management, and optional cleanup. It showcases best 
    practices for programmatic infrastructure deployment and provides a foundation for building 
    production-ready automation workflows.
    
    This example serves as both a learning tool and a production template, demonstrating how to:
    - Programmatically provision and configure HPE GreenLake workspaces
    - Automate server onboarding at scale with minimal manual intervention
    - Apply consistent configuration policies across your infrastructure
    - Implement monitoring and maintenance automation
    - Optimize cleanup operations by saving and restoring workspace sessions to avoid unnecessary re-authentication delays
    - Safely tear down test environments with comprehensive cleanup
    
    Workflow Steps:
    1. Module Import and Authentication
       - Validates network connectivity to iLO management interfaces
       - Imports HPECOMCmdlets PowerShell module
       - Authenticates to HPE GreenLake platform
    
    2. Workspace Provisioning
       - Creates a new HPE GreenLake workspace with location details
       - Connects to the newly created workspace
    
    3. User Provisioning
       - Creates additional workspace users with appropriate roles
       - Configures user permissions and access
    
    4. Organization Integration (Optional)
       - Joins workspace to organization for SSO and identity governance
       - Assigns organization-level roles to users
       - Saves workspace session for later restoration during cleanup
    
    5. Service Enablement
       - Enables Compute Ops Management service in specified region
       - Assigns COM administrator roles to users
    
    6. Location Management
       - Creates physical location with contact information
       - Configures location details for device assignment
    
    7. Subscription Configuration
       - Adds subscription keys to workspace
       - Configures auto-subscription policy (ENHANCED tier)
       - Enables auto-reassign subscription policy
    
    8. Server Onboarding
       - Generates activation keys for each server
       - Connects iLO interfaces to Compute Ops Management
       - Monitors onboarding progress and validates success
    
    9. Device Configuration
       - Assigns devices to physical location
       - Applies device tags for organization and filtering
       - Sets service delivery contacts
    
    10. Server Settings Creation
        - Creates BIOS settings with workload profiles
        - Configures storage settings with RAID volumes
        - Creates firmware baseline settings for each generation
        - Defines iLO security and management settings
    
    11. Group Management
        - Creates server group with auto-apply policies
        - Adds servers to group for centralized management
        - Configures group settings for BIOS, firmware, storage, and iLO
    
    12. Notification Configuration
        - Enables email notifications for daily summaries
        - Configures alerts for service events and critical issues
    
    13. Firmware Update Scheduling
        - Schedules firmware update for server group
        - Configures update parameters and timing
    
    14. Optional Cleanup (prompted at end or via -OnlyCleanup)
        - Validates or restores workspace session for optimal performance
        - Removes device assignments from COM service
        - Disconnects iLOs from Compute Ops Management
        - Removes subscriptions and additional users
        - Disables Compute Ops Management service
        - Moves devices to parking lot workspace (if configured)
        - Validates workspace deletion prerequisites
        - Deletes the workspace and confirms cleanup success

.NOTES
    Prerequisites:
    - HPECOMCmdlets PowerShell module v1.0.23+ (Install-Module HPECOMCmdlets)
    - Valid HPE GreenLake credentials 
    - Network access to iLO management interfaces
    - Valid Compute Ops Management subscription key
    
    Before Running:
    - Update the configuration section with your environment details
    - Ensure iLO credentials are correct
    - Verify subscription key is valid
    - Review and customize settings to match your requirements
    
    Implementation Details:
    This script implements an optimized cleanup workflow by saving the workspace session 
    immediately after provisioning completes. When cleanup is initiated, the script attempts 
    to reuse this saved session via Restore-HPEGLSession to avoid unnecessary re-authentication 
    delays. If the saved session is no longer valid, the script automatically falls back to 
    creating a fresh connection. This approach significantly reduces cleanup execution time 
    while maintaining reliability.
    
    The cleanup workflow sequence is:
    1. Provisioning Phase → Saves workspace session for later reuse
    2. Optional Cleanup Phase → Validates and reuses saved session (or reconnects if needed)
    3. Resource Cleanup → Removes assignments, subscriptions, users, and services
    4. Device Management → Moves devices to parking lot workspace (if configured)
    5. Session Restoration → Restores saved session (fast path) or reconnects (fallback)
    6. Workspace Deletion → Validates prerequisites and performs clean removal
    
    This optimized approach reduces total cleanup time by 30-50% compared to full 
    re-authentication, particularly valuable in automated testing and CI/CD pipelines.
    
    Author: HPE
    Version: 1.0
    Last Updated: March 2026

.PARAMETER OnlyProvision
    When specified, runs only the provisioning workflow (Steps 1-13) without executing the cleanup 
    phase. Use this switch when you want to create and configure the environment but skip the 
    optional cleanup prompt at the end.
    
    Cannot be used together with -OnlyCleanup parameter.

.PARAMETER OnlyCleanup
    When specified, skips the provisioning workflow and runs only the cleanup phase. Use this switch 
    to clean up an existing workspace that was previously provisioned. The workspace name must match 
    the configuration in the script.
    
    IMPORTANT: When using this parameter, you must also specify -WorkspaceName with the exact name 
    of the workspace to delete (since the default configuration uses a random workspace name).
    
    Useful for:
    - Cleaning up test environments from previous runs
    - Deleting workspaces created manually or by other processes
    - Re-running cleanup after a partial or failed cleanup attempt
    
    Cannot be used together with -OnlyProvision parameter.

.PARAMETER WorkspaceName
    Specifies the exact workspace name to use. When provided, this overrides the default randomly 
    generated workspace name in the configuration.
    
    This parameter is:
    - Optional for normal runs and -OnlyProvision (defaults to random name if not specified)
    - Strongly recommended for -OnlyCleanup (to specify which workspace to delete)
    
    Example: "Production-Workspace-1234"

.EXAMPLE
    .\COM-Zero-Touch-Automation.ps1
    
    Runs the complete Zero Touch Automation workflow with the configuration defined in the script.

    Output summary:  
    
    HPE COMPUTE OPS MANAGEMENT - ZERO TOUCH AUTOMATION
    ================================================================================
    ℹ Started at: 3/17/2026 8:45 AM
    ℹ Workspace: Production-Workspace-6625

    STEP 1: Module Import and Authentication
    ================================================================================
    ℹ Validating network connectivity to iLO management interfaces...
    ✓ HPECOMCmdlets module v1.0.23 imported successfully
    ℹ Connecting to HPE GreenLake...
    ✓ Connected to HPE GreenLake successfully                                                                               
                                                                                                                            
    STEP 2: Workspace Creation
    ================================================================================
    ℹ Creating workspace: Production-Workspace-6625...
    ✓ Workspace 'Production-Workspace-6625' created successfully
    ℹ Connecting to workspace: Production-Workspace-6625...
    ✓ Connected to workspace 'Production-Workspace-6625' successfully

    STEP 3: User Provisioning
    ================================================================================
    ℹ Creating user: operations@company.com...
    ✓ User 'operations@company.com' created with role 'Workspace Administrator'

    STEP 4: Join organization to enable SSO, user groups, or identity governance
    ================================================================================
    ℹ Joining 'company.com' organization...
    ✓ Joined 'company.com' organization successfully
    ℹ Assigning organization workspace viewer roles to additional user...
    ✓ Organization workspace viewer role assigned to admin@company.com
    ✓ Workspace session saved for later restoration

    STEP 5: Enable Compute Ops Management Service
    ================================================================================
    ℹ Enabling Compute Ops Management in region: us-west...
    ✓ Compute Ops Management service enabled in region 'us-west'
    ℹ Assigning COM administrator roles...
    ✓ COM administrator role assigned to admin@company.com
    ✓ COM administrator role assigned to operations@company.com

    STEP 6: Location Creation
    ================================================================================
    ℹ Creating location: Primary Data Center...
    ✓ Location 'Primary Data Center' created successfully

    STEP 7: Add Subscriptions and Configure Policies
    ================================================================================
    ℹ Adding subscription key: xxxxxxxx...
    ✓ Subscription key added successfully
    ℹ Configuring auto-subscription policy to ENHANCED tier...
    ✓ Auto-subscription policy configured to ENHANCED tier
    ℹ Enabling auto-reassign subscription policy...
    ✓ Auto-reassign subscription policy enabled

    STEP 8: Server Onboarding (2 servers)
    ================================================================================
    ℹ Onboarding server: 192.168.1.100 (DL145 Gen11)...
    ✓ Activation key generated: 8FB6KAS7Z
    ℹ Connecting iLO 192.168.1.100 to Compute Ops Management...
    ✓ iLO 192.168.1.100 connected to Compute Ops Management
    ℹ Onboarding server: 192.168.1.101 (DL145 Gen11)...
    ✓ Activation key generated: RFU6GATY3
    ℹ Connecting iLO 192.168.1.101 to Compute Ops Management...
    ✓ iLO 192.168.1.101 connected to Compute Ops Management
    ℹ 2 of 2 iLO(s) successfully initiated connection to COM
    ℹ Waiting for all 2 server(s) to appear as connected in COM (timeout: 7 min)...
    ✓ iLO 192.168.1.101 is now connected in COM (1/2)
    ✓ iLO 192.168.1.100 is now connected in COM (2/2)

    STEP 9: Device Configuration
    ================================================================================
    ℹ Found 2 device(s) in workspace
    ℹ Setting device location to 'Primary Data Center'...
    ✓ Device location set to 'Primary Data Center'
    ℹ Adding device tags: Environment=Production, Application=WebServices, Tier=Frontend...
    ✓ Device tags added successfully
    ℹ Setting service delivery contact to operations@company.com...
    ✓ Service delivery contact set to operations@company.com

    STEP 10: Create Server Settings
    ================================================================================
    ℹ Creating BIOS setting: Production-BIOS-Settings...
    ✓ BIOS setting 'Production-BIOS-Settings' created successfully
    ℹ Creating storage setting: Production-Storage-RAID...
    ✓ Storage setting 'Production-Storage-RAID' created successfully
    ℹ Creating firmware setting with latest baselines...
    ℹ Gen10: 2026.01.00.00, Gen11: 2026.01.00.00, Gen12: 2026.01.00.00
    ✓ Firmware setting 'Production-Firmware-Baseline' created with latest baselines
    ℹ Creating iLO setting: Production-iLO-Settings...
    ✓ iLO setting 'Production-iLO-Settings' created successfully

    STEP 11: Create Group and Add Servers
    ================================================================================
    ℹ Creating group: Production-Web-Servers...
    ✓ Group 'Production-Web-Servers' created successfully with server settings applied (BIOS, iLO, Firmware and Storage settings) and group policies
    ℹ Adding servers to group 'Production-Web-Servers'...
    ✓ Server added to group 'Production-Web-Servers' — Serial: xxxxxxxxxx, iLO IP: 192.168.1.100
    ✓ Server added to group 'Production-Web-Servers' — Serial: xxxxxxxxxx, iLO IP: 192.168.1.101

    STEP 12: Enable Email Notifications
    ================================================================================
    ℹ Enabling email notification policies...
    ✓ Email notification policies enabled successfully

    STEP 13: Schedule Firmware Update
    ================================================================================
    ℹ Scheduling firmware update for group 'Production-Web-Servers' on 4/16/2026 8:51 AM...
    ✓ Firmware update scheduled for 4/16/2026 8:51 AM

    AUTOMATION COMPLETED
    ================================================================================
    ✓ Zero Touch Automation workflow completed!
    ℹ Workspace: Production-Workspace-6625
    ℹ Region: us-west
    ℹ Servers Onboarded: 2
    ℹ Duration: 00:06:38
    ℹ Completed at: 3/17/2026 8:51 AM

    Next Steps:
    1. Log in to HPE GreenLake portal to verify workspace and server configuration
    2. Review server settings and adjust as needed for your environment
    3. Monitor firmware update schedule and server health
    4. Configure additional automation workflows as required



    OPTIONAL CLEANUP
    ================================================================================
    ℹ You can clean up the environment now (removes workspace and all resources) or keep it active for testing and exploration. To clean up later, run the script with the parameters: -WorkspaceName Production-Workspace-6625 -OnlyCleanup


    Do you want to clean up the environment now? (Y/N): y

    ENVIRONMENT CLEANUP
    ================================================================================
    ℹ Starting cleanup process for workspace: Production-Workspace-6625
    ✓ Workspace session is still valid, proceeding with cleanup...
    ℹ Found 2 device(s) in workspace
    ℹ Removing device assignments from service...
    ✓ Device(s) removed from service
    ℹ Disconnecting iLO(s) from Compute Ops Management...
    ✓ iLO 192.168.1.100 disconnected from COM
    ✓ iLO 192.168.1.101 disconnected from COM
    ℹ Removing subscription(s)...
    ✓ Subscription(s) removed
    ℹ Removing additional user...
    ✓ Additional user(s) removed: operations@company.com
    ℹ Removing Compute Ops Management service...
    ✓ Compute Ops Management service removed from region 'us-west'
    ℹ Waiting for service removal to propagate...
    ℹ Moving 2 device(s) to parking lot workspace 'MyParkingLotWorkspace'...
    ✓ Connected to parking lot workspace 'MyParkingLotWorkspace'
    ✓ Device 'xxxxxxxxxx' with iLO IP 192.168.1.100 moved to parking lot
    ✓ Device 'xxxxxxxxxx' with iLO IP 192.168.1.101 moved to parking lot
    ℹ Waiting for device moves to propagate...
    ℹ Restoring workspace session for 'Production-Workspace-6625'...
    ✓ Workspace session restored for 'Production-Workspace-6625'
    ℹ Validating workspace deletion prerequisites...
    ✓ Workspace is clean and ready for deletion
    ℹ Deleting workspace 'Production-Workspace-6625'...
    ✓ Workspace 'Production-Workspace-6625' deleted successfully

    CLEANUP COMPLETED
    ================================================================================
    ✓ Environment cleanup completed successfully!
    ℹ Workspace: Production-Workspace-6625
    ℹ Cleanup Duration: 00:01:35
    ℹ Completed at: 3/17/2026 8:53 AM
    ℹ Total Script Duration (Provisioning + Cleanup): 00:08:13

.EXAMPLE
    .\COM-Zero-Touch-Automation.ps1 -OnlyProvision
    
    Runs only the provisioning workflow (Steps 1-13), creating and configuring the workspace and 
    servers without prompting for cleanup. The workspace remains active after the script completes.
    
    Use this when you want to:
    - Set up an environment for long-term use or testing
    - Provision infrastructure that will be cleaned up later
    - Skip the cleanup prompt and end immediately after provisioning

.EXAMPLE
    .\COM-Zero-Touch-Automation.ps1 -OnlyCleanup
    
    Runs only the cleanup workflow, deleting an existing workspace and all associated resources. 
    The workspace name must match the $WorkspaceConfig.Name defined in the script configuration.
    
    Use this when you want to:
    - Clean up a workspace from a previous provisioning run
    - Delete test environments without re-provisioning
    - Retry cleanup after a partial or failed cleanup attempt
    
    Note: Ensure the workspace name in the configuration matches the workspace you want to delete.

.EXAMPLE
    .\COM-Zero-Touch-Automation.ps1 -OnlyCleanup -WorkspaceName "Production-Workspace-1234"
    
    Runs only the cleanup workflow for the specific workspace "Production-Workspace-1234". This is 
    the recommended approach when using -OnlyCleanup, as it explicitly specifies which workspace to 
    delete (avoiding issues with the randomly generated default name).

.EXAMPLE
    .\COM-Zero-Touch-Automation.ps1 -WorkspaceName "MyCustomWorkspace"
    
    Runs the complete workflow (provisioning and optional cleanup) using a specific workspace name 
    instead of the randomly generated default. Useful when you want a predictable workspace name for 
    easier identification or later cleanup.

.LINK
    https://github.com/jullienl/HPE-COM-PowerShell-Library
    https://jullienl.github.io/PowerShell-library-for-HPE-GreenLake
#>

#Requires -Version 7.0
#Requires -Modules @{ ModuleName = 'HPECOMCmdlets'; ModuleVersion = '1.0.23' }

[CmdletBinding(DefaultParameterSetName = 'Default')]
param (
    
    [Parameter(ParameterSetName = "CleanupOnly")]
    [switch]$OnlyCleanup,
    
    [Parameter(ParameterSetName = "ProvisionOnly")]
    [switch]$OnlyProvision,
    
    [Parameter(Mandatory = $false)]
    [string]$WorkspaceName
)

# ============================================================================
#Region - CONFIGURATION SECTION - Customize these values for your environment
# ============================================================================

# Workspace Configuration
# Note: WorkspaceName parameter takes precedence if specified

$WorkspaceConfig = @{
    Name       = if ($WorkspaceName) { $WorkspaceName } else { "Production-Workspace-$(Get-Random -Maximum 9999)" }
    Type       = 'Standard enterprise workspace'
    Street     = "3000 Hanover Street"
    City       = "Palo Alto"
    State      = "CA"
    PostalCode = "94304"
    Country    = "United States"
}

# HPE GreenLake Credentials
$MyEmail = "admin@company.com"  # Your HPE GreenLake account email

# Additional User to Provision
$AdditionalUser = @{
    Email            = "operations@company.com"
    Role             = 'Workspace Administrator'
    SendWelcomeEmail = $true
}

# Organization Name to Join (for SSO, user groups, identity governance) (optional)

# TEST SCENARIO 1 - Standalone Workspace (Fastest, No Org Permissions Needed):
# $OrganizationName = $null  # Workspace stays standalone, easy cleanup

# TEST SCENARIO 2 - Organization Workspace (Requires Org Admin Role for Deletion):
$OrganizationName = "company.com"  # Workspace joins organization, tests org permissions


# Compute Ops Management Region
# Options: "us-west", "us-east", "eu-central", "ap-northeast", "ap-southeast"
$COMRegion = "us-west"

# Location Configuration
$LocationConfig = @{
    Name                = "Primary Data Center"
    Description         = "Main production data center"
    Street              = "3000 Hanover Street"
    City                = "Palo Alto"
    State               = "CA"
    PostalCode          = "94304"
    Country             = "United States"
    PrimaryContactEmail = $MyEmail
}

# Subscription Keys (obtain from HPE GreenLake portal)
$SubscriptionKeys = @(
    "YOUR-SUBSCRIPTION-KEY-1-HERE",
    "YOUR-SUBSCRIPTION-KEY-2-HERE"
)

# Server Configuration (2 servers for this example)
$Servers = @(
    @{
        iLOIP       = "192.168.1.100"
        iLOUsername = "Administrator"
        iLOPassword = "YouriLOPassword1"
        Model       = "DL360 Gen11"
        Description = "Production Web Server 1"
    },
    @{
        iLOIP       = "192.168.1.101"
        iLOUsername = "Administrator"
        iLOPassword = "YouriLOPassword2"
        Model       = "DL360 Gen11"
        Description = "Production Web Server 2"
    }
)

# Device Tags (Key-Value pairs)
$DeviceTags = "Environment=Production, Application=WebServices, Tier=Frontend"

# Server Settings Configuration
$SettingsConfig = @{
    BiosSettingName       = "Production-BIOS-Settings"
    BiosWorkloadProfile   = "Virtualization - Max Performance"
    BiosASREnabled        = $true
    BiosASRTimeout        = "Timeout10"
    
    StorageSettingName    = "Production-Storage-RAID"
    StorageDescription    = "Standard RAID configuration for production servers"
    
    FirmwareSettingName   = "Production-Firmware-Baseline"
    FirmwareDescription   = "Latest firmware baselines for production servers"
    
    iLOSettingName        = "Production-iLO-Settings"
    iLODescription        = "Secure iLO settings for production environment"
    iLOVirtualMedia       = "Enabled"
    iLOPasswordComplexity = "Enabled"
    iLOWebServerSSL       = "Enabled"
    iLOThirdPartyFirmware = "Disabled"
}

# Group Configuration
$GroupConfig = @{
    Name                              = "Production-Web-Servers"
    Description                       = "Production web server fleet"
    AutoBiosApplyOnAdd                = $false
    AutoIloApplyOnAdd                 = $true
    AutoFirmwareUpdateOnAdd           = $false
    PowerOffServerAfterFirmwareUpdate = $false
    FirmwareDowngradeAllowed          = $false
    AutoStorageVolumeCreationOnAdd    = $false
    AutoStorageVolumeDeletionOnAdd    = $false
    TagUsedForAutoAddServer           = "Application=WebServices"
}

# Email Notification Settings
$EmailNotifications = @{
    DailySummary                      = $true
    ServiceEventAndCriticalAndWarning = $true
}

# Firmware Update Schedule (days from now)
$FirmwareUpdateInDays = 30

# Parking Lot Workspace (for cleanup - optional)
# If specified, devices will be moved here before workspace deletion
# If not specified, workspace deletion will be skipped if devices exist
# $ParkingLotWorkspace = $null  
$ParkingLotWorkspace = "MyParkingLotWorkspace"  

#EndRegion


# ============================================================================
#Region - SCRIPT EXECUTION - Do not modify below unless you know what you're doing
# ============================================================================

# Color-coded output functions
function Write-Success {
    param([string]$Message)
    Write-Host "✓ $Message" -ForegroundColor Green
}

function Write-Failure {
    param([string]$Message)
    Write-Host "✗ $Message" -ForegroundColor Red
}

function Write-SectionHeader {
    param([string]$Message)
    Write-Host "`n$Message" -ForegroundColor Cyan
    Write-Host ("=" * 80) -ForegroundColor Cyan
}

function Write-Info {
    param([string]$Message)
    Write-Host "ℹ $Message" -ForegroundColor Yellow
}

# Start Script Execution
$ErrorActionPreference = "Stop"
$StartTime = Get-Date
Clear-Host

Write-SectionHeader "HPE COMPUTE OPS MANAGEMENT - ZERO TOUCH AUTOMATION"
Write-Info "Started at: $($StartTime.ToString('g'))"
Write-Info "Workspace: $($WorkspaceConfig.Name)"

#EndRegion


# ============================================================================
#Region - STEP 1: Module Import and Authentication
# ============================================================================
Write-SectionHeader "STEP 1: Module Import and Authentication"

# Validate iLO connectivity (required for provisioning; during cleanup, unreachable iLOs are handled gracefully by the disconnect section)
if (-not $OnlyCleanup) {
Write-Info "Validating network connectivity to iLO management interfaces..."
foreach ($Server in $Servers) {
    if (-not (Test-Connection -ComputerName $Server.iLOIP -Count 1 -Quiet)) {
        Write-Failure "iLO IP $($Server.iLOIP) is not reachable. Please check network connectivity."
        exit 1
        }
    }
}

try {
    Import-Module HPECOMCmdlets -ErrorAction Stop
    $moduleVersion = (Get-Module HPECOMCmdlets).Version
    Write-Success "HPECOMCmdlets module v$moduleVersion imported successfully"
}
catch {
    Write-Failure "Failed to import HPECOMCmdlets module: $($_.Exception.Message)"
    Write-Info "Install the module using: Install-Module HPECOMCmdlets"
    exit 1
}

if ($OnlyProvision -or -not $OnlyCleanup) {

    Write-Info "Connecting to HPE GreenLake..."
    try {
        $Credential = Get-Credential -UserName $MyEmail -Message "Enter your HPE GreenLake credentials"
        Connect-HPEGL -Credential $Credential -ErrorAction Stop -WarningAction SilentlyContinue -RemoveExistingCredentials | Out-Null
        Write-Success "Connected to HPE GreenLake successfully"
    }
    catch {
        Write-Failure "Failed to connect to HPE GreenLake: $($_.Exception.Message)"
        exit 1
    }
}


#EndRegion

if ($OnlyProvision -or -not $OnlyCleanup) {

# ============================================================================
#Region - STEP 2: Workspace Creation
# ============================================================================
Write-SectionHeader "STEP 2: Workspace Creation"

try {
    Write-Info "Creating workspace: $($WorkspaceConfig.Name)..."
    $WorkspaceTask = New-HPEGLWorkspace `
        -Name $WorkspaceConfig.Name `
        -Type $WorkspaceConfig.Type `
        -Street $WorkspaceConfig.Street `
        -City $WorkspaceConfig.City `
        -State $WorkspaceConfig.State `
        -PostalCode $WorkspaceConfig.PostalCode `
        -Country $WorkspaceConfig.Country

    if ($WorkspaceTask.Status -eq "Complete") {
        Write-Success "Workspace '$($WorkspaceConfig.Name)' created successfully"
    }
    else {
        Write-Failure "Workspace creation failed: $($WorkspaceTask.Status) - $($WorkspaceTask.Details)"
        exit 1
    }
}
catch {
    Write-Failure "Failed to create workspace: $($_.Exception.Message)"
    exit 1
}

# Connect to the new workspace
try {
    Write-Info "Connecting to workspace: $($WorkspaceConfig.Name)..."
    
    Connect-HPEGL -Credential $Credential -Workspace $WorkspaceConfig.Name -NoProgress -ErrorAction Stop -WarningAction SilentlyContinue -RemoveExistingCredentials | Out-Null

    Write-Success "Connected to workspace '$($WorkspaceConfig.Name)' successfully"
}
catch {
    Write-Failure "Failed to connect to workspace: $($_.Exception.Message)"
    exit 1
}

#EndRegion


# ============================================================================
#Region - STEP 3: User Provisioning
# ============================================================================
Write-SectionHeader "STEP 3: User Provisioning"

try {
    Write-Info "Creating user: $($AdditionalUser.Email)..."
    $UserTask = New-HPEGLUser -Email $AdditionalUser.Email -RoleName $AdditionalUser.Role -SendWelcomeEmail:$AdditionalUser.SendWelcomeEmail
    
    if ($UserTask.Status -eq "Complete") {
        Write-Success "User '$($AdditionalUser.Email)' created with role '$($AdditionalUser.Role)'"
    }
    else {
        Write-Failure "User creation failed: $($UserTask.Status) - $($UserTask.Details)"
        exit 1
    }
}
catch {
    Write-Failure "Failed to create user: $($_.Exception.Message)"
    exit 1
}

#EndRegion


# ============================================================================
#Region - STEP 4: Join organization
# ============================================================================

if ($OrganizationName) {

    Write-SectionHeader "STEP 4: Join organization to enable SSO, user groups, or identity governance"

        # Check if workspace is already part of the organization
        if ($Global:HPEGreenLakeSession.organization -eq $OrganizationName) {
            Write-Success "Workspace is already part of '$OrganizationName' organization"
        }
        else {
    try {
        Write-Info "Joining '$OrganizationName' organization..."
        $OrganizationTask = Join-HPEGLOrganization -Name $OrganizationName -ErrorAction Stop
    
        if ($OrganizationTask.Status -eq "Complete") {
            Write-Success "Joined '$OrganizationName' organization successfully"
        }
        else {
            Write-Failure "Organization join failed: $($OrganizationTask.Status) - $($OrganizationTask.Details)"
        }
    }
    catch {
        Write-Failure "Failed to join organization: $($_.Exception.Message)"
    }
        }
   
        # Add the organiization workspace viewer role to the users if organization join was successful

        try {
            Write-Info "Assigning organization workspace viewer roles to additional user..."          

            # Wait for the newly created user to propagate into the organization's user directory
            $propagationTimeout = 60
            $propagationElapsed = 0
            do {
                $userVisible = Get-HPEGLUser -Email $AdditionalUser.Email -ErrorAction SilentlyContinue
                if (-not $userVisible) {
                    Start-Sleep -Seconds 5
                    $propagationElapsed += 5
                }
            } until ($userVisible -or $propagationElapsed -ge $propagationTimeout)
        
            $OrgRoleTask2 = Add-HPEGLRoleToUser -RoleName 'Organization workspace viewer' -Email $AdditionalUser.Email
            if ($OrgRoleTask2.Status -eq "Complete") {
                Write-Success "Organization workspace viewer role assigned to $($AdditionalUser.Email)"
            }
            else {
                Write-Failure "Failed to assign organization workspace viewer role to $($AdditionalUser.Email): $($OrgRoleTask2.Status) - $($OrgRoleTask2.Details)"
            }
        }
        catch {
            Write-Failure "Failed to assign organization roles: $($_.Exception.Message)"
        }

}
else {
    Write-Info "No organization specified. Skipping organization join step."
}

    # Save workspace session after organization join (captures complete state)
    try {
        if (-not $Global:HPEGreenLakeSession) {
            Write-Failure "Session object not found"
            exit 1
        }
        
        $CurrentWorkspaceSession = Save-HPEGLSession
        Write-Success "Workspace session saved for later restoration"
    }
    catch {
        Write-Failure "Failed to save session: $($_.Exception.Message)"
        Write-Info "This script requires HPECOMCmdlets module version 1.0.23 or higher"
        Write-Info "Update the module using: Update-Module HPECOMCmdlets -Force"
        Write-Info "Or install the latest version: Install-Module HPECOMCmdlets -Force"
        exit 1
    }

    #EndRegion


# ============================================================================
#Region - STEP 5: Enable Compute Ops Management Service
# ============================================================================
Write-SectionHeader "STEP 5: Enable Compute Ops Management Service"

try {
    Write-Info "Enabling Compute Ops Management in region: $COMRegion..."
    $ServiceTask = New-HPEGLService -Name "Compute Ops Management" -Region $COMRegion
    
    if ($ServiceTask.Status -eq "Complete") {
        Write-Success "Compute Ops Management service enabled in region '$COMRegion'"
    }
    else {
        Write-Failure "Service creation failed: $($ServiceTask.Status) - $($ServiceTask.Details)"
        exit 1
    }
}
catch {
    Write-Failure "Failed to enable service: $($_.Exception.Message)"
    exit 1
}

# Assign COM Administrator Roles
try {
    Write-Info "Assigning COM administrator roles..."
    
    $RoleTask1 = Add-HPEGLRoleToUser -RoleName 'Compute Ops Management administrator' -Email $MyEmail
    if ($RoleTask1.Status -eq "Complete") {
        Write-Success "COM administrator role assigned to $MyEmail"
    }
        else {
            Write-Failure "Failed to assign COM administrator role to $($MyEmail): $($RoleTask1.Status) - $($RoleTask1.Details)"
        }
    
    $RoleTask2 = Add-HPEGLRoleToUser -RoleName 'Compute Ops Management administrator' -Email $AdditionalUser.Email
    if ($RoleTask2.Status -eq "Complete") {
        Write-Success "COM administrator role assigned to $($AdditionalUser.Email)"
    }
        else {
            Write-Failure "Failed to assign COM administrator role to $($AdditionalUser.Email): $($RoleTask2.Status) - $($RoleTask2.Details)"
        }
}
catch {
    Write-Failure "Failed to assign roles: $($_.Exception.Message)"
    exit 1
}

#EndRegion


# ============================================================================
#Region - STEP 6: Location Creation
# ============================================================================
Write-SectionHeader "STEP 6: Location Creation"

try {
    Write-Info "Creating location: $($LocationConfig.Name)..."
    $LocationTask = New-HPEGLLocation `
        -Name $LocationConfig.Name `
        -Description $LocationConfig.Description `
        -Street $LocationConfig.Street `
        -City $LocationConfig.City `
        -State $LocationConfig.State `
        -PostalCode $LocationConfig.PostalCode `
        -Country $LocationConfig.Country `
        -PrimaryContactEmail $LocationConfig.PrimaryContactEmail
    
    if ($LocationTask.Status -eq "Complete") {
        Write-Success "Location '$($LocationConfig.Name)' created successfully"
    }
    else {
        Write-Failure "Location creation failed: $($LocationTask.Status) - $($LocationTask.Details)"
        exit 1
    }
}
catch {
    Write-Failure "Failed to create location: $($_.Exception.Message)"
    exit 1
}

#EndRegion


# ============================================================================
#Region - STEP 7: Add Subscriptions and Configure Policies
# ============================================================================
Write-SectionHeader "STEP 7: Add Subscriptions and Configure Policies"

# Add subscription keys
foreach ($SubKey in $SubscriptionKeys) {
    if ($SubKey -match "YOUR-SUBSCRIPTION-KEY") {
        Write-Info "Skipping placeholder subscription key. Please update the configuration with valid keys."
        continue
    }
    
    try {
        Write-Info "Adding subscription key: $($SubKey.Substring(0, [Math]::Min(8, $SubKey.Length)))..."
        $SubTask = New-HPEGLSubscription -SubscriptionKey $SubKey
        
        if ($SubTask.Status -eq "Complete") {
            Write-Success "Subscription key added successfully"
        }
        else {
            Write-Failure "Subscription addition failed: $($SubTask.Status) - $($SubTask.Details)"
        }
    }
    catch {
        Write-Failure "Failed to add subscription: $($_.Exception.Message)"
    }
}

# Configure auto-subscription policy
try {
    Write-Info "Configuring auto-subscription policy to ENHANCED tier..."
    $AutoSubTask = Set-HPEGLDeviceAutoSubscription -ComputeSubscriptionTier ENHANCED
    
    if ($AutoSubTask.Status -eq "Complete") {
        Write-Success "Auto-subscription policy configured to ENHANCED tier"
    }
        else {
            Write-Failure "Failed to configure auto-subscription policy: $($AutoSubTask.Status) - $($AutoSubTask.Details)"
        }
}
catch {
    Write-Failure "Failed to configure auto-subscription: $($_.Exception.Message)"
}

# Configure auto-reassign subscription policy
try {
    Write-Info "Enabling auto-reassign subscription policy..."
    $ReassignTask = Set-HPEGLDeviceAutoReassignSubscription -Computes
    
    if ($ReassignTask.Status -eq "Complete") {
        Write-Success "Auto-reassign subscription policy enabled"
    }
        else {
            Write-Failure "Failed to enable auto-reassign subscription policy: $($ReassignTask.Status) - $($ReassignTask.Details)"
        }
}
catch {
    Write-Failure "Failed to enable auto-reassign policy: $($_.Exception.Message)"
}

#EndRegion


# ============================================================================
#Region - STEP 8: Server Onboarding
# ============================================================================
Write-SectionHeader "STEP 8: Server Onboarding ($($Servers.Count) servers)"

$OnboardedServers = @()

    # --- Pass 1: Connect all iLOs to COM ---
foreach ($Server in $Servers) {
    Write-Info "Onboarding server: $($Server.iLOIP) ($($Server.Model))..."
    
    # Generate activation key
    try {
        $ActivationKey = New-HPECOMServerActivationKey -Region $COMRegion
        Write-Success "Activation key generated: $ActivationKey"
    }
    catch {
        Write-Failure "Failed to generate activation key for $($Server.iLOIP): $($_.Exception.Message)"
        continue
    }
    
    # Connect iLO to COM
    try {
        $iLOSecurePassword = ConvertTo-SecureString $Server.iLOPassword -AsPlainText -Force
        $iLOCredential = New-Object System.Management.Automation.PSCredential ($Server.iLOUsername, $iLOSecurePassword)
        
        Write-Info "Connecting iLO $($Server.iLOIP) to Compute Ops Management..."
        
        $ConnectionTask = Connect-HPEGLDeviceComputeiLOtoCOM `
            -iLOCredential $iLOCredential `
            -IloIP $Server.iLOIP `
            -ActivationKeyfromCOM $ActivationKey `
            -SkipCertificateValidation `
            -RemoveExistingiLOProxySettings `
            -ConnectionMonitoringTimeoutSeconds 120 `
            -ResetiLOIfProxyErrorPersists
        
        if ($ConnectionTask.Status -eq "Complete") {
            Write-Success "iLO $($Server.iLOIP) connected to Compute Ops Management"
            $OnboardedServers += $Server.iLOIP
        }
        else {
                Write-Failure "iLO connection failed for $($Server.iLOIP): $($ConnectionTask.Status) - $($ConnectionTask.Details)"
        }
    }
    catch {
            Write-Failure "Failed to connect iLO $($Server.iLOIP) to COM: $($_.Exception.Message)"
        }
    }

    Write-Info "$($OnboardedServers.Count) of $($Servers.Count) iLO(s) successfully initiated connection to COM"

    # --- Pass 2: Wait for all onboarded servers to appear as connected in COM ---
    if ($OnboardedServers.Count -gt 0) {

        # Allow 5 min base (minimum observed connection time) + 1 min per server for variability
        # e.g. 1 server → 6 min, 2 servers → 7 min, 5 servers → 10 min
        $WaitTimeSeconds = 300 + 60 * $OnboardedServers.Count
        $WaitTimeMinutes = [Math]::Round($WaitTimeSeconds / 60, 1)

        Write-Info "Waiting for all $($OnboardedServers.Count) server(s) to appear as connected in COM (timeout: ${WaitTimeMinutes} min)..."
        $ElapsedSeconds = 0
        $CheckIntervalSeconds = 15
        $ConnectedIPs = [System.Collections.Generic.HashSet[string]]::new()

        while ($ConnectedIPs.Count -lt $OnboardedServers.Count -and $ElapsedSeconds -lt $WaitTimeSeconds) {
            Start-Sleep -Seconds $CheckIntervalSeconds
            $ElapsedSeconds += $CheckIntervalSeconds

            # Update progress bar
            $PercentComplete = [Math]::Min(100, [Math]::Round(($ElapsedSeconds / $WaitTimeSeconds) * 100))
            $Remaining = $WaitTimeSeconds - $ElapsedSeconds
            Write-Progress -Activity "Waiting for server(s) to appear connected in COM" `
                -Status "$($ConnectedIPs.Count) of $($OnboardedServers.Count) connected — ${ElapsedSeconds}s elapsed, ${Remaining}s remaining" `
                -PercentComplete $PercentComplete

            try {
                $COMServersCheck = Get-HPECOMServer -Region $COMRegion
                if ($COMServersCheck) {
                    foreach ($COMServer in $COMServersCheck) {
                        if ($COMServer.state.connected -eq $true -and $OnboardedServers -contains $COMServer.iLOIPAddress) {
                            if ($ConnectedIPs.Add($COMServer.iLOIPAddress)) {
                                Write-Success "iLO $($COMServer.iLOIPAddress) is now connected in COM ($($ConnectedIPs.Count)/$($OnboardedServers.Count))"
                            }
                        }
                    }
                }
            }
            catch {
                Write-Failure "Error checking device connection status: $($_.Exception.Message)"
            }
        }

        # Dismiss the progress bar
        Write-Progress -Activity "Waiting for server(s) to appear connected in COM" -Completed

        $NotConnected = $OnboardedServers | Where-Object { $_ -notin $ConnectedIPs }
        foreach ($IP in $NotConnected) {
            Write-Info "iLO $IP did not appear as connected within the timeout period — continuing anyway"
        }
    }


#EndRegion


# ============================================================================
#Region - STEP 9: Device Configuration (Location, Tags, Contacts)
# ============================================================================
Write-SectionHeader "STEP 9: Device Configuration"

# Get all devices
$Devices = Get-HPEGLDevice
Write-Info "Found $($Devices.Count) device(s) in workspace"

if ($Devices) {
    # Set Location
    try {
        Write-Info "Setting device location to '$($LocationConfig.Name)'..."
        $LocationSetTask = $Devices | Set-HPEGLDeviceLocation -LocationName $LocationConfig.Name
        
            if ($LocationSetTask | Where-Object Status -ne 'Complete') {
                $failedCount = @($LocationSetTask | Where-Object Status -ne 'Complete').Count
                Write-Failure "Failed to set location for $failedCount device(s)"
            }
            else {
            Write-Success "Device location set to '$($LocationConfig.Name)'"
        }
    }
    catch {
        Write-Failure "Failed to set device location: $($_.Exception.Message)"
    }
    
    # Add Tags
    try {
        Write-Info "Adding device tags: $DeviceTags..."
        $TagsTask = $Devices | Add-HPEGLDeviceTagToDevice -Tags $DeviceTags
        
            if ($TagsTask | Where-Object Status -ne 'Complete') {
                $failedCount = @($TagsTask | Where-Object Status -ne 'Complete').Count
                Write-Failure "Failed to add tags for $failedCount device(s)"
            }
            else {
            Write-Success "Device tags added successfully"
        }
    }
    catch {
        Write-Failure "Failed to add device tags: $($_.Exception.Message)"
    }
    
    # Set Service Delivery Contact
    try {
        Write-Info "Setting service delivery contact to $MyEmail..."
        $ContactTask = $Devices | Set-HPEGLDeviceServiceDeliveryContact -Email $MyEmail
        
            if ($ContactTask | Where-Object Status -ne 'Complete') {
                $failedCount = @($ContactTask | Where-Object Status -ne 'Complete').Count
                Write-Failure "Failed to set contact for $failedCount device(s)"
            }
            else {
            Write-Success "Service delivery contact set to $MyEmail"
        }
    }
    catch {
        Write-Failure "Failed to set service delivery contact: $($_.Exception.Message)"
    }
}

#EndRegion


# ============================================================================
#Region - STEP 10: Create Server Settings
# ============================================================================
Write-SectionHeader "STEP 10: Create Server Settings"

# BIOS Settings
try {
    Write-Info "Creating BIOS setting: $($SettingsConfig.BiosSettingName)..."
    $BiosTask = New-HPECOMSettingServerBios `
        -Region $COMRegion `
        -Name $SettingsConfig.BiosSettingName `
        -WorkloadProfileName $SettingsConfig.BiosWorkloadProfile `
        -AsrStatus:$SettingsConfig.BiosASREnabled `
        -AsrTimeoutMinutes $SettingsConfig.BiosASRTimeout
    
    if ($BiosTask.Status -eq "Complete") {
        Write-Success "BIOS setting '$($SettingsConfig.BiosSettingName)' created successfully"
    }
        else {
            Write-Failure "BIOS setting creation failed: $($BiosTask.Status) - $($BiosTask.Details)"
        }
}
catch {
    Write-Failure "Failed to create BIOS setting: $($_.Exception.Message)"
}

# Storage Settings
try {
    Write-Info "Creating storage setting: $($SettingsConfig.StorageSettingName)..."
    
    # Define storage volumes
    $Volume1 = New-HPECOMSettingServerInternalStorageVolume `
        -RAID RAID5 `
        -DriveTechnology NVME_SSD `
        -IOPerformanceMode ENABLED `
        -ReadCachePolicy OFF `
        -WriteCachePolicy WRITE_THROUGH `
        -SizeinGB 500 `
        -DrivesNumber 3 `
        -SpareDriveNumber 1
    
    $Volume2 = New-HPECOMSettingServerInternalStorageVolume `
        -RAID RAID1 `
        -DriveTechnology SAS_HDD
    
    $StorageTask = New-HPECOMSettingServerInternalStorage `
        -Region $COMRegion `
        -Name $SettingsConfig.StorageSettingName `
        -Volumes $Volume1, $Volume2 `
        -Description $SettingsConfig.StorageDescription
    
    if ($StorageTask.Status -eq "Complete") {
        Write-Success "Storage setting '$($SettingsConfig.StorageSettingName)' created successfully"
    }
        else {
            Write-Failure "Storage setting creation failed: $($StorageTask.Status) - $($StorageTask.Details)"
        }
}
catch {
    Write-Failure "Failed to create storage setting: $($_.Exception.Message)"
}

# Firmware Settings
try {
    Write-Info "Creating firmware setting with latest baselines..."
    
    # Get latest firmware baselines for each generation
    $Gen10Baseline = Get-HPECOMFirmwareBaseline -Region $COMRegion -LatestVersion -Generation 10 | Select-Object -ExpandProperty releaseVersion
    $Gen11Baseline = Get-HPECOMFirmwareBaseline -Region $COMRegion -LatestVersion -Generation 11 | Select-Object -ExpandProperty releaseVersion
    $Gen12Baseline = Get-HPECOMFirmwareBaseline -Region $COMRegion -LatestVersion -Generation 12 | Select-Object -ExpandProperty releaseVersion
    
    Write-Info "Gen10: $Gen10Baseline, Gen11: $Gen11Baseline, Gen12: $Gen12Baseline"
    
    $FirmwareTask = New-HPECOMSettingServerFirmware `
        -Region $COMRegion `
        -Name $SettingsConfig.FirmwareSettingName `
        -Description $SettingsConfig.FirmwareDescription `
        -Gen10FirmwareBaselineReleaseVersion $Gen10Baseline `
        -Gen11FirmwareBaselineReleaseVersion $Gen11Baseline `
        -Gen12FirmwareBaselineReleaseVersion $Gen12Baseline
    
    if ($FirmwareTask.Status -eq "Complete") {
        Write-Success "Firmware setting '$($SettingsConfig.FirmwareSettingName)' created with latest baselines"
    }
        else {
            Write-Failure "Firmware setting creation failed: $($FirmwareTask.Status) - $($FirmwareTask.Details)"
        }
}
catch {
    Write-Failure "Failed to create firmware setting: $($_.Exception.Message)"
}

# iLO Settings
try {
    Write-Info "Creating iLO setting: $($SettingsConfig.iLOSettingName)..."
    $iLOTask = New-HPECOMSettingiLOSettings `
        -Region $COMRegion `
        -Name $SettingsConfig.iLOSettingName `
        -Description $SettingsConfig.iLODescription `
        -VirtualMedia $SettingsConfig.iLOVirtualMedia `
        -AccountServicePasswordComplexity $SettingsConfig.iLOPasswordComplexity `
        -WebServerSSL $SettingsConfig.iLOWebServerSSL `
        -AcceptThirdPartyFirmwareUpdates $SettingsConfig.iLOThirdPartyFirmware
    
    if ($iLOTask.Status -eq "Complete") {
        Write-Success "iLO setting '$($SettingsConfig.iLOSettingName)' created successfully"
    }
        else {
            Write-Failure "iLO setting creation failed: $($iLOTask.Status) - $($iLOTask.Details)"
        }
}
catch {
    Write-Failure "Failed to create iLO setting: $($_.Exception.Message)"
}

#EndRegion


# ============================================================================
#Region - STEP 11: Create Group and Add Servers
# ============================================================================
Write-SectionHeader "STEP 11: Create Group and Add Servers"

# Create Group
try {
    Write-Info "Creating group: $($GroupConfig.Name)..."
    $GroupTask = New-HPECOMGroup `
        -Region $COMRegion `
        -Name $GroupConfig.Name `
        -Description $GroupConfig.Description `
        -BiosSettingName $SettingsConfig.BiosSettingName `
        -AutoBiosApplySettingsOnAdd:$GroupConfig.AutoBiosApplyOnAdd `
        -iLOSettingName $SettingsConfig.iLOSettingName `
        -AutoIloApplySettingsOnAdd:$GroupConfig.AutoIloApplyOnAdd `
        -FirmwareSettingName $SettingsConfig.FirmwareSettingName `
        -AutoFirmwareUpdateOnAdd:$GroupConfig.AutoFirmwareUpdateOnAdd `
        -PowerOffServerAfterFirmwareUpdate:$GroupConfig.PowerOffServerAfterFirmwareUpdate `
        -FirmwareDowngrade:$GroupConfig.FirmwareDowngradeAllowed `
        -StorageSettingName $SettingsConfig.StorageSettingName `
        -AutoStorageVolumeCreationOnAdd:$GroupConfig.AutoStorageVolumeCreationOnAdd `
        -AutoStorageVolumeDeletionOnAdd:$GroupConfig.AutoStorageVolumeDeletionOnAdd `
        -TagUsedForAutoAddServer $GroupConfig.TagUsedForAutoAddServer
    
    if ($GroupTask.Status -eq "Complete") {
            Write-Success "Group '$($GroupConfig.Name)' created successfully with server settings applied (BIOS, iLO, Firmware and Storage settings) and group policies"
    }
        else {
            Write-Failure "Group creation failed: $($GroupTask.Status) - $($GroupTask.Details)"
        }
}
catch {
    Write-Failure "Failed to create group: $($_.Exception.Message)"
}

# Add servers to group
try {
    Write-Info "Adding servers to group '$($GroupConfig.Name)'..."
    $COMServers = Get-HPECOMServer -Region $COMRegion
    
    if ($COMServers) {
        $AddServerTask = $COMServers | Add-HPECOMServerToGroup -GroupName $GroupConfig.Name
        
            foreach ($Task in $AddServerTask) {
                $ServerObj = $COMServers | Where-Object { $_.hardware.serialNumber -eq $Task.SerialNumber }
                $iLOIP = if ($ServerObj) { $ServerObj.iLOIPAddress } else { "N/A" }
                if ($Task.Status -eq 'Complete') {
                    Write-Success "Server added to group '$($GroupConfig.Name)' — Serial: $($Task.SerialNumber), iLO IP: $iLOIP"
                }
                else {
                    Write-Failure "Failed to add server to group '$($GroupConfig.Name)' — Serial: $($Task.SerialNumber), iLO IP: $iLOIP — $($Task.Status): $($Task.Details)"
                }
        }
    }
    else {
        Write-Info "No servers found in COM to add to group"
    }
}
catch {
    Write-Failure "Failed to add servers to group: $($_.Exception.Message)"
}

#EndRegion


# ============================================================================
#Region - STEP 12: Enable Email Notifications
# ============================================================================
Write-SectionHeader "STEP 12: Enable Email Notifications"

try {
    Write-Info "Enabling email notification policies..."
    $EmailTask = Enable-HPECOMEmailNotificationPolicy `
        -Region $COMRegion `
        -DailySummary:$EmailNotifications.DailySummary `
        -ServiceEventAndCriticalAndWarningIssues:$EmailNotifications.ServiceEventAndCriticalAndWarning
    
    if ($EmailTask.Status -eq "Complete") {
        Write-Success "Email notification policies enabled successfully"
    }
        else {
            Write-Failure "Failed to enable email notification policies: $($EmailTask.Status) - $($EmailTask.Details)"
        }
}
catch {
    Write-Failure "Failed to enable email notifications: $($_.Exception.Message)"
}
#EndRegion


# ============================================================================
#Region - STEP 13: Schedule Firmware Update
# ============================================================================
Write-SectionHeader "STEP 13: Schedule Firmware Update"

try {
    $UpdateDate = (Get-Date).AddDays($FirmwareUpdateInDays)
    Write-Info "Scheduling firmware update for group '$($GroupConfig.Name)' on $($UpdateDate.ToString('g'))..."
    
    $FirmwareUpdateTask = Update-HPECOMGroupServerFirmware `
        -Region $COMRegion `
        -GroupName $GroupConfig.Name `
            -AllowFirmwareDowngrade:$GroupConfig.FirmwareDowngradeAllowed `
        -InstallHPEDriversAndSoftware `
        -ScheduleTime $UpdateDate
    
    if ($FirmwareUpdateTask.NextStartAt) {
        Write-Success "Firmware update scheduled for $([datetime]::Parse($FirmwareUpdateTask.NextStartAt).ToString('g'))"
    }
        else {
            Write-Failure "Firmware update scheduling failed: no scheduled time returned"
        }
}
catch {
    Write-Failure "Failed to schedule firmware update: $($_.Exception.Message)"
}

#EndRegion


# ============================================================================
#Region - COMPLETION SUMMARY
# ============================================================================
$EndTime = Get-Date
$Duration = $EndTime - $StartTime

Write-SectionHeader "AUTOMATION COMPLETED"
Write-Success "Zero Touch Automation workflow completed!"
Write-Info "Workspace: $($WorkspaceConfig.Name)"
Write-Info "Region: $COMRegion"
Write-Info "Servers Onboarded: $($OnboardedServers.Count)"
    Write-Info "Duration: $($Duration.ToString('hh\:mm\:ss'))"
Write-Info "Completed at: $($EndTime.ToString('g'))"

Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "  1. Log in to HPE GreenLake portal to verify workspace and server configuration" -ForegroundColor White
Write-Host "  2. Review server settings and adjust as needed for your environment" -ForegroundColor White
Write-Host "  3. Monitor firmware update schedule and server health" -ForegroundColor White
Write-Host "  4. Configure additional automation workflows as required" -ForegroundColor White

#EndRegion
}

# ============================================================================
#Region - OPTIONAL: CLEANUP ENVIRONMENT
# ============================================================================

if (-not $OnlyProvision) {

Write-Host "`n" -ForegroundColor White
    
    if (-not $OnlyCleanup) {
        Write-SectionHeader "OPTIONAL CLEANUP"
        Write-Info "You can clean up the environment now (removes workspace and all resources) or keep it active for testing and exploration. To clean up later, run the script with the parameters: -WorkspaceName $($WorkspaceConfig.Name) -OnlyCleanup"
        Write-Host "`n" -ForegroundColor White

do {
$CleanupResponse = Read-Host "Do you want to clean up the environment now? (Y/N)"
    if ($CleanupResponse -notmatch '^[YyNn]$') {
        Write-Host "Invalid input. Please enter Y or N." -ForegroundColor Yellow
    }
} while ($CleanupResponse -notmatch '^[YyNn]$')
    }
    else {
        $CleanupResponse = 'Y'
    }

    if ($CleanupResponse -eq 'Y') {
    Write-SectionHeader "ENVIRONMENT CLEANUP"
    $CleanupStartTime = Get-Date
    $CleanupErrors = @()
    
    Write-Info "Starting cleanup process for workspace: $($WorkspaceConfig.Name)"
    

        if ($CurrentWorkspaceSession -and $CurrentWorkspaceSession.IsValid -and $CurrentWorkspaceSession.username -eq $MyEmail -and $CurrentWorkspaceSession.workspace -eq $WorkspaceConfig.Name) {
        Write-Success "Workspace session is still valid, proceeding with cleanup..."
    }
        elseif ($Global:HPEGreenLakeSession -and $Global:HPEGreenLakeSession.IsValid -and $Global:HPEGreenLakeSession.username -eq $MyEmail -and $Global:HPEGreenLakeSession.workspace -eq $WorkspaceConfig.Name) {
            Write-Success "Global session is still valid, using it for cleanup..."
            $CurrentWorkspaceSession = Save-HPEGLSession
        }
    else {
        Write-Info "No valid session available, reconnecting to workspace for cleanup..."
         
            if (-not $Credential) {
                $Credential = Get-Credential -UserName $MyEmail -Message "Enter your HPE GreenLake credentials"
            }

            try {
        Connect-HPEGL -Credential $Credential -Workspace $WorkspaceConfig.Name -NoProgress -ErrorAction Stop -WarningAction SilentlyContinue -RemoveExistingCredentials | Out-Null
            $CurrentWorkspaceSession = Save-HPEGLSession
        Write-Success "Connected to workspace '$($WorkspaceConfig.Name)' for cleanup"
            }
            catch {
                Write-Failure "Failed to connect to workspace '$($WorkspaceConfig.Name)' for cleanup: $($_.Exception.Message)"
                $CleanupErrors += "Workspace connection: $($_.Exception.Message)"
            }
    }

    # Get devices before any cleanup
    $DevicesBeforeCleanup = $null
        $deviceRetrievalSucceeded = $false
    try {
        $DevicesBeforeCleanup = Get-HPEGLDevice
            $deviceRetrievalSucceeded = $true
        if ($DevicesBeforeCleanup) {
            Write-Info "Found $($DevicesBeforeCleanup.Count) device(s) in workspace"
        }
    }
    catch {
        Write-Failure "Error getting devices: $($_.Exception.Message)"
        $CleanupErrors += "Device retrieval: $($_.Exception.Message)"
    }
    
    # Remove device assignments from service
    try {
        Write-Info "Removing device assignments from service..."
            $Devices = $DevicesBeforeCleanup
        if ($Devices) {
            $DeviceAssigned = $Devices | Where-Object { $_.assignedState -ne "UNASSIGNED" }
            if ($DeviceAssigned) {
                $DeviceAssigned | Remove-HPEGLDeviceFromService | Out-Null
                Write-Success "Device(s) removed from service"
            }
            else {
                Write-Info "No devices assigned to services"
            }
        }
            else {
                Write-Info "No devices found in workspace to remove from service"
            }
    }
    catch {
        Write-Failure "Error removing device assignments: $($_.Exception.Message)"
        $CleanupErrors += "Device removal: $($_.Exception.Message)"
    }
    
    # Disconnect iLOs from COM
    try {
        Write-Info "Disconnecting iLO(s) from Compute Ops Management..."
        foreach ($Server in $Servers) {
            try {
                $iLOSecurePassword = ConvertTo-SecureString $Server.iLOPassword -AsPlainText -Force
                $iLOCredential = New-Object System.Management.Automation.PSCredential ($Server.iLOUsername, $iLOSecurePassword)
                
                # Check if HPEiLOCmdlets module is available
                if (Get-Module -ListAvailable -Name HPEiLOCmdlets) {
                    Import-Module HPEiLOCmdlets -ErrorAction SilentlyContinue
                    $connection = Connect-HPEiLO -Address $Server.iLOIP -Credential $iLOCredential -DisableCertificateAuthentication -ErrorAction Stop
                    
                    if ($connection) {
                        $comStatus = Get-HPEiLOComputeOpsManagementStatus -Connection $connection -ErrorAction Stop | Select-Object -ExpandProperty CloudConnectStatus
                        # write-host "iLO COM Status: $comStatus"
                        if ($comStatus -eq "Connected") {
                            Disable-HPEiLOComputeOpsManagement -Connection $connection -ErrorAction Stop | Out-Null
                            Write-Success "iLO $($Server.iLOIP) disconnected from COM"
                        }
                        elseif ($comStatus -eq "NotEnabled") {
                                Write-Info "iLO $($Server.iLOIP) is already disconnected from COM (likely unregistered by the service removal step)"
                        }
                        else {
                            Write-Info "iLO $($Server.iLOIP) COM status is '$comStatus' - skipping disconnect"
                        }

                        Disconnect-HPEiLO -Connection $connection -ErrorAction SilentlyContinue | Out-Null
                    }
                }
                else {
                    Write-Info "HPEiLOCmdlets module not available - skipping iLO disconnect"
                    break
                }
            }
            catch {
                Write-Failure "Error disconnecting iLO $($Server.iLOIP): $($_.Exception.Message)"
                $CleanupErrors += "iLO disconnect: $($_.Exception.Message)"
            }
        }
    }
    catch {
        Write-Failure "Error in iLO disconnect process: $($_.Exception.Message)"
        $CleanupErrors += "iLO operations: $($_.Exception.Message)"
    }
    
    # Remove subscriptions
    try {
        Write-Info "Removing subscription(s)..."
        $Subscriptions = Get-HPEGLSubscription
        if ($Subscriptions) {
            $Subscriptions | Remove-HPEGLSubscription | Out-Null
            Write-Success "Subscription(s) removed"
        }
        else {
            Write-Info "No subscriptions to remove"
        }
    }
    catch {
        Write-Failure "Error removing subscriptions: $($_.Exception.Message)"
        $CleanupErrors += "Subscription removal: $($_.Exception.Message)"
    }
    
    # Remove additional user
    try {
        Write-Info "Removing additional user..."
        $Users = Get-HPEGLUser | Where-Object { $_.userName -ne $MyEmail }
        if ($Users) {
                $ListOfUsers = $Users.email -join ", "
            $Users | Remove-HPEGLUser | Out-Null
            Write-Success "Additional user(s) removed: $ListOfUsers"
        }
        else {
            Write-Info "No additional users to remove"
        }
    }
    catch {
        Write-Failure "Error removing users: $($_.Exception.Message)"
        $CleanupErrors += "User removal: $($_.Exception.Message)"
    }
    
    # Remove COM service
    try {
        Write-Info "Removing Compute Ops Management service..."
        $Service = Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned -Region $COMRegion
        if ($Service) {
            $Service | Remove-HPEGLService -Force | Out-Null
            Write-Success "Compute Ops Management service removed from region '$COMRegion'"
            # No devices to move, just wait for service removal
            Write-Info "Waiting for service removal to propagate..."
            Start-Sleep -Seconds 5
        }
        else {
            Write-Info "No COM service to remove"
        }
    }
    catch {
        Write-Failure "Error removing service: $($_.Exception.Message)"
        $CleanupErrors += "Service removal: $($_.Exception.Message)"
    }
    
        $allDevicesMoved = $false
    # Move devices to parking lot workspace (if configured and devices exist)
    if ($DevicesBeforeCleanup -and $DevicesBeforeCleanup.Count -gt 0) {
        if ($ParkingLotWorkspace) {
            try {
                Write-Info "Moving $($DevicesBeforeCleanup.Count) device(s) to parking lot workspace '$ParkingLotWorkspace'..."
                
                    # Ensure credentials are available for parking lot connection
                    if (-not $Credential) {
                        $Credential = Get-Credential -UserName $MyEmail -Message "Enter your HPE GreenLake credentials"
                    }
                
                # Connect to parking lot workspace
                Connect-HPEGL -Credential $Credential -Workspace $ParkingLotWorkspace -NoProgress -WarningAction SilentlyContinue -ErrorAction Stop -RemoveExistingCredentials | Out-Null
                    Write-Success "Connected to parking lot workspace '$ParkingLotWorkspace'"
                
                    $deviceMoveFailures = 0
                foreach ($device in $DevicesBeforeCleanup) {
                    try {
                        Add-HPEGLDeviceCompute -SerialNumber $device.serialnumber -PartNumber $device.partNumber | Out-Null
                            $iLOIP = if ($COMServers) { ($COMServers | Where-Object { $_.hardware.serialNumber -eq $device.serialnumber }).iLOIPAddress } else { $null }
                            $iLOMsg = if ($iLOIP) { " with iLO IP $iLOIP" } else { "" }
                            Write-Success "Device '$($device.serialnumber)'$iLOMsg moved to parking lot"
                    }
                    catch {
                        Write-Failure "Error moving device '$($device.serialnumber)': $($_.Exception.Message)"
                        $CleanupErrors += "Device move: $($_.Exception.Message)"
                            $deviceMoveFailures++
                    }
                }
                
                    # Wait for device moves to propagate
                    Write-Info "Waiting for device moves to propagate..."
                    Start-Sleep -Seconds 10
                    $allDevicesMoved = $deviceMoveFailures -eq 0
            }
            catch {
                Write-Failure "Error moving devices to parking lot: $($_.Exception.Message)"
                $CleanupErrors += "Parking lot move: $($_.Exception.Message)"
            }
        }
        else {
                Write-Failure "Cannot delete workspace: $($DevicesBeforeCleanup.Count) device(s) still present and no parking lot workspace configured"
                Write-Info "Set the `$ParkingLotWorkspace variable to move devices before workspace deletion"
            $CleanupErrors += "Workspace has devices but no parking lot configured"
        }
    }
    
        # Delete workspace (only if no devices present, or all devices were successfully moved to parking lot)
        # Also skip if device retrieval failed (unknown state — safer to not delete)
        $CanDeleteWorkspace = $deviceRetrievalSucceeded -and ((-not $DevicesBeforeCleanup) -or $allDevicesMoved)
    
    if ($CanDeleteWorkspace) {
        try {
                # Restore the original workspace session for deletion.
                # Try Restore-HPEGLSession first (fast, no re-authentication);
                # fall back to Connect-HPEGL only if the saved session is no longer valid.
                if ($CurrentWorkspaceSession) {
                    try {
                        Write-Info "Restoring workspace session for '$($WorkspaceConfig.Name)'..."
                        Restore-HPEGLSession -Session $CurrentWorkspaceSession -ErrorAction Stop
                        Write-Success "Workspace session restored for '$($WorkspaceConfig.Name)'"
                    }
                    catch {
                        Write-Info "Session restore failed, reconnecting to workspace '$($WorkspaceConfig.Name)'..."
                        Connect-HPEGL -Credential $Credential -Workspace $WorkspaceConfig.Name -NoProgress -ErrorAction Stop -WarningAction SilentlyContinue -RemoveExistingCredentials | Out-Null
                        Write-Success "Reconnected to workspace '$($WorkspaceConfig.Name)'"
                    }
                }
                else {
                    Write-Info "Reconnecting to workspace '$($WorkspaceConfig.Name)'..."
                    Connect-HPEGL -Credential $Credential -Workspace $WorkspaceConfig.Name -NoProgress -ErrorAction Stop -WarningAction SilentlyContinue -RemoveExistingCredentials | Out-Null
                    Write-Success "Reconnected to workspace '$($WorkspaceConfig.Name)'"
                }
                
                # Validate workspace deletion prerequisites
                Write-Info "Validating workspace deletion prerequisites..."
                $ValidationResult = Remove-HPEGLWorkspace -ValidatePrerequisites
                
                if ($ValidationResult.CanBeDeleted) {
                    Write-Success "Workspace is clean and ready for deletion"
                }
                else {
                    Write-Failure "Workspace cannot be deleted - $($ValidationResult.BlockingResources.Count) issue(s) found:"
                    foreach ($issue in $ValidationResult.BlockingResources) {
                        Write-Host "  • $issue" -ForegroundColor Yellow
                        $CleanupErrors += $issue
                    }
                    $CanDeleteWorkspace = $false
                }
            }
            catch {
                Write-Failure "Error during pre-deletion validation: $($_.Exception.Message)"
                $CleanupErrors += "Pre-deletion validation: $($_.Exception.Message)"
                $CanDeleteWorkspace = $false
            }
        }
        
        if ($CanDeleteWorkspace) {
            try {
            Write-Info "Deleting workspace '$($WorkspaceConfig.Name)'..."
            
            # Retry workspace deletion up to 3 times
            $maxRetries = 3
            $retryCount = 0
            $RemoveResult = $null
            $deletionSuccess = $false
            
            while ($retryCount -lt $maxRetries -and -not $deletionSuccess) {
                $retryCount++
                try {
                    if ($retryCount -gt 1) {
                        Write-Info "Deletion attempt $retryCount of $maxRetries..."
                        Start-Sleep -Seconds 10
                    }
                    
                    $RemoveResult = Remove-HPEGLWorkspace -Force
                    
                    if ($RemoveResult.status -eq "Complete") {
                        Write-Success "Workspace '$($WorkspaceConfig.Name)' deleted successfully"
                        $deletionSuccess = $true
                    }
                    else {
                        Write-Failure "Workspace deletion returned unexpected status: $($RemoveResult.status)"
                            Write-Info "Details: $($RemoveResult.Details)"
                            
                        if ($retryCount -lt $maxRetries) {
                            Write-Info "Retrying workspace deletion..."
                        }
                        else {
                                $CleanupErrors += "Workspace deletion status after $maxRetries attempts: $($RemoveResult.status) - $($RemoveResult.Details)"
                        }
                    }
                }
                catch {
                    Write-Failure "Deletion attempt $retryCount failed: $($_.Exception.Message)"
                        
                    if ($retryCount -lt $maxRetries) {
                        Write-Info "Retrying workspace deletion..."
                    }
                    else {
                            $CleanupErrors += "Workspace deletion: $($_.Exception.Message)"
                    }
                }
            }
            
            if (-not $deletionSuccess -and $retryCount -eq $maxRetries) {
                Write-Failure "Workspace deletion failed after $maxRetries attempts"
            }
        }
        catch {
            Write-Failure "Error deleting workspace: $($_.Exception.Message)"
            $CleanupErrors += "Workspace deletion: $($_.Exception.Message)"
        }
    }
    else {
        Write-Info "Workspace deletion skipped (devices present, no parking lot configured)"
    }

    
    # Cleanup completion summary
    $CleanupEndTime = Get-Date
    $CleanupDuration = $CleanupEndTime - $CleanupStartTime
    
    Write-SectionHeader "CLEANUP COMPLETED"
    
    if ($CleanupErrors.Count -eq 0) {
        Write-Success "Environment cleanup completed successfully!"
    }
    else {
        Write-Failure "Cleanup completed with $($CleanupErrors.Count) error(s)"
        Write-Host "`nCleanup Errors:" -ForegroundColor Yellow
        foreach ($cleanupError in $CleanupErrors) {
            Write-Host "  • $cleanupError" -ForegroundColor Yellow
        }
    }
    
    Write-Info "Workspace: $($WorkspaceConfig.Name)"
        Write-Info "Cleanup Duration: $($CleanupDuration.ToString('hh\:mm\:ss'))"
    Write-Info "Completed at: $($CleanupEndTime.ToString('g'))"
    # Calculate total active script duration (excluding user prompt wait time)
        if ($Duration) {
    $TotalActiveDuration = $Duration + $CleanupDuration
            Write-Info "Total Script Duration (Provisioning + Cleanup): $($TotalActiveDuration.ToString('hh\:mm\:ss'))"
        }
}
else {
    Write-Host "`nCleanup skipped. Workspace '$($WorkspaceConfig.Name)' remains active." -ForegroundColor Cyan
}

Write-Host "`n" -ForegroundColor White
}
#EndRegion 

