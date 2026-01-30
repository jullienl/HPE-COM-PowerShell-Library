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
    - Safely tear down test environments with comprehensive cleanup
    
    Workflow Steps:
    1. Workspace Provisioning
       - Creates a new HPE GreenLake workspace
       - Provisions users with appropriate roles
       - Enables Compute Ops Management service
    
    2. Infrastructure Setup
       - Creates physical locations
       - Adds subscriptions and configures auto-subscription policies
       - Generates activation keys for server onboarding
    
    3. Server Onboarding
       - Connects iLO to Compute Ops Management
       - Configures device properties (location, tags, contacts)
       - Verifies successful onboarding
    
    4. Configuration Management
       - Creates server settings (BIOS, firmware, storage, iLO)
       - Creates server groups with auto-apply policies
       - Adds servers to groups for centralized management
    
    5. Monitoring & Maintenance
       - Enables email notifications for alerts and daily summaries
       - Schedules firmware updates
    
    6. Optional Cleanup (prompted at end)
       - Removes device assignments from service
       - Disconnects iLOs from Compute Ops Management
       - Removes subscriptions and additional users
       - Disables Compute Ops Management service
       - Moves devices to parking lot workspace (if configured)
       - Deletes the workspace and validates cleanup success

.NOTES
    Prerequisites:
    - HPECOMCmdlets PowerShell module (Install-Module HPECOMCmdlets)
    - Valid HPE GreenLake credentials with appropriate permissions
    - Network access to iLO management interfaces
    - Valid Compute Ops Management subscription keys
    
    Before Running:
    - Update the configuration section with your environment details
    - Ensure iLO credentials are correct
    - Verify subscription keys are valid
    - Review and customize settings to match your requirements
    
    Author: HPE
    Version: 1.0
    Last Updated: January 2026

.EXAMPLE
    .\COM-Zero-Touch-Automation.ps1
    
    Runs the complete Zero Touch Automation workflow with the configuration defined in the script.

    Output summary:  
    
    HPE COMPUTE OPS MANAGEMENT - ZERO TOUCH AUTOMATION
    ================================================================================
    ℹ Started at: 2026-01-26 10:57:27
    ℹ Workspace: Production-Workspace-5551

    STEP 1: Module Import and Authentication
    ================================================================================
    ✓ HPECOMCmdlets module imported successfully
    ℹ Connecting to HPE GreenLake (you will be prompted for credentials)...
    ✓ Connected to HPE GreenLake successfully                                                                               
                                                                                                                            
    STEP 2: Workspace Creation
    ================================================================================
    ℹ Creating workspace: Production-Workspace-5551...
    ✓ Workspace 'Production-Workspace-5551' created successfully
    ℹ Connecting to workspace: Production-Workspace-5551...
    ✓ Connected to workspace 'Production-Workspace-5551' successfully

    STEP 3: User Provisioning
    ================================================================================
    ℹ Creating user: operations@company.com...
    ✓ User 'operations@company.com' created with role 'Workspace Administrator'

    STEP 4: Enable Compute Ops Management Service
    ================================================================================
    ℹ Enabling Compute Ops Management in region: us-west...
    ✓ Compute Ops Management service enabled in region 'us-west'
    ℹ Assigning COM administrator roles...
    ✓ COM administrator role assigned to admin@company.com
    ✓ COM administrator role assigned to operations@company.com

    STEP 5: Location Creation
    ================================================================================
    ℹ Creating location: Primary Data Center...
    ✓ Location 'Primary Data Center' created successfully

    STEP 6: Add Subscriptions and Configure Policies
    ================================================================================
    ℹ Adding subscription key: xxxxxxxxx...
    ✓ Subscription key added successfully
    ℹ Adding subscription key: xxxxxxxxx...
    ✓ Subscription key added successfully
    ℹ Configuring auto-subscription policy to ENHANCED tier...
    ✓ Auto-subscription policy configured to ENHANCED tier
    ℹ Enabling auto-reassign subscription policy...
    ✓ Auto-reassign subscription policy enabled

    STEP 7: Server Onboarding (2 servers)
    ================================================================================
    ℹ
    Onboarding server: 192.168.1.100 (DL360 Gen11)...
    ✓ Activation key generated: xxxxxxxxx                                                                                   
    ℹ Connecting iLO 192.168.1.100 to Compute Ops Management...
    ℹ Connection attempt 1 failed. Retrying in 5 seconds...
    ✓ iLO 192.168.1.100 connected to Compute Ops Management
    ℹ Waiting for device to appear in COM inventory...
    ℹ 
    Onboarding server: 192.168.1.101 (DL360 Gen11)...
    ✓ Activation key generated: xxxxxxxxx
    ℹ Connecting iLO 192.168.1.101 to Compute Ops Management...
    ✓ iLO 192.168.1.101 connected to Compute Ops Management
    ℹ Waiting for device to appear in COM inventory...
    ℹ 
    Successfully onboarded 2 of 2 servers

    STEP 8: Device Configuration
    ================================================================================
    ℹ Found 2 device(s) in workspace
    ℹ Setting device location to 'Primary Data Center'...
    ✓ Device location set to 'Primary Data Center'
    ℹ Adding device tags: Environment=Production, Application=WebServices, Tier=Frontend...
    ✓ Device tags added successfully
    ℹ Setting service delivery contact to admin@company.com...
    ✓ Service delivery contact set to admin@company.com

    STEP 9: Create Server Settings
    ================================================================================
    ℹ Creating BIOS setting: Production-BIOS-Settings...
    ✓ BIOS setting 'Production-BIOS-Settings' created successfully
    ℹ Creating storage setting: Production-Storage-RAID...
    ✓ Storage setting 'Production-Storage-RAID' created successfully
    ℹ Creating firmware setting with latest baselines...
    ℹ Gen10: 2025.11.00.00, Gen11: 2025.11.00.00, Gen12: 2025.11.00.00
    ✓ Firmware setting 'Production-Firmware-Baseline' created with latest baselines
    ℹ Creating iLO setting: Production-iLO-Settings...
    ✓ iLO setting 'Production-iLO-Settings' created successfully

    STEP 10: Create Group and Add Servers
    ================================================================================
    ℹ Creating group: Production-Web-Servers...
    ✓ Group 'Production-Web-Servers' created successfully
    ℹ Adding servers to group 'Production-Web-Servers'...
    ✓ Servers added to group 'Production-Web-Servers'

    STEP 11: Enable Email Notifications
    ================================================================================
    ℹ Enabling email notification policies...
    ✓ Email notification policies enabled successfully

    STEP 12: Schedule Firmware Update
    ================================================================================
    ℹ Scheduling firmware update for group 'Production-Web-Servers' on 2026-02-25 11:00...
    ✓ Firmware update scheduled for 2026-02-25T10:00:57.638646Z

    AUTOMATION COMPLETED
    ================================================================================
    ✓ Zero Touch Automation workflow completed!
    ℹ Workspace: Production-Workspace-5551
    ℹ Region: us-west
    ℹ Servers Onboarded: 2
    ℹ Duration: 03:31
    ℹ Completed at: 2026-01-26 11:00:59

    Next Steps:
    1. Log in to HPE GreenLake portal to verify workspace and server configuration
    2. Review server settings and adjust as needed for your environment
    3. Monitor firmware update schedule and server health
    4. Configure additional automation workflows as required


    Do you want to clean up the environment now? (Y/N): y

    ENVIRONMENT CLEANUP
    ================================================================================
    ℹ Starting cleanup process for workspace: Production-Workspace-5551
    ℹ Found 2 device(s) in workspace
    ℹ Removing device assignments from service...
    ✓ Device(s) removed from service
    ℹ Disconnecting iLO(s) from Compute Ops Management...
    ✓ iLO 192.168.1.100 disconnected from COM
    ✓ iLO 192.168.1.101 disconnected from COM
    ℹ Removing subscription(s)...
    ✓ Subscription(s) removed
    ℹ Removing additional user...
    ✓ Additional user(s) removed
    ℹ Removing Compute Ops Management service...
    ✓ Compute Ops Management service removed from region 'us-west'
    ℹ Moving 2 device(s) to parking lot workspace 'MyParkingLotWorkspace'...
    ✓ Device 'xxxxxxxxxx' moved to parking lot
    ✓ Device 'xxxxxxxxxx' moved to parking lot
    ℹ Waiting for device moves and service removal to propagate...
    ℹ Reconnecting to workspace for deletion...
    ℹ Deleting workspace 'Production-Workspace-5551'...
    ✓ Workspace 'Production-Workspace-5551' deleted successfully                                                            

    CLEANUP COMPLETED
    ================================================================================
    ✓ Environment cleanup completed successfully!
    ℹ Workspace: Production-Workspace-5551
    ℹ Cleanup Duration: 01:33
    ℹ Completed at: 2026-01-26 11:02:55
    ℹ Total Script Duration (Provisioning + Cleanup): 05:27


.LINK
    https://github.com/jullienl/HPE-COM-PowerShell-Library
    https://jullienl.github.io/PowerShell-library-for-HPE-GreenLake
#>

#Requires -Version 7.0
#Requires -Modules HPECOMCmdlets

# ============================================================================
# CONFIGURATION SECTION - Customize these values for your environment
# ============================================================================

# Workspace Configuration
$WorkspaceConfig = @{
    Name        = "Production-Workspace-$(Get-Random -Maximum 9999)"
    Type        = 'Standard enterprise workspace'
    Street      = "3000 Hanover Street"
    City        = "Palo Alto"
    State       = "CA"
    PostalCode  = "94304"
    Country     = "United States"
}

# HPE GreenLake Credentials
$MyEmail = "admin@company.com"  # Your HPE GreenLake account email

# Additional User to Provision
$AdditionalUser = @{
    Email = "operations@company.com"
    Role  = 'Workspace Administrator'
    SendWelcomeEmail = $true
}

# Compute Ops Management Region
# Options: "us-west", "us-east", "eu-central", "ap-northeast", "ap-southeast"
$COMRegion = "us-west"

# Location Configuration
$LocationConfig = @{
    Name                 = "Primary Data Center"
    Description          = "Main production data center"
    Street               = "3000 Hanover Street"
    City                 = "Palo Alto"
    State                = "CA"
    PostalCode           = "94304"
    Country              = "United States"
    PrimaryContactEmail  = "operations@company.com"
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
        iLOPassword = "YourSecurePassword1"
        Model       = "DL360 Gen11"
        Description = "Production Web Server 1"
    },
    @{
        iLOIP       = "192.168.1.101"
        iLOUsername = "Administrator"
        iLOPassword = "YourSecurePassword2"
        Model       = "DL360 Gen11"
        Description = "Production Web Server 2"
    }
)

# Device Tags (Key-Value pairs)
$DeviceTags = "Environment=Production, Application=WebServices, Tier=Frontend"

# Server Settings Configuration
$SettingsConfig = @{
    BiosSettingName             = "Production-BIOS-Settings"
    BiosWorkloadProfile         = "Virtualization - Max Performance"
    BiosASREnabled              = $true
    BiosASRTimeout              = "Timeout10"
    
    StorageSettingName          = "Production-Storage-RAID"
    StorageDescription          = "Standard RAID configuration for production servers"
    
    FirmwareSettingName         = "Production-Firmware-Baseline"
    FirmwareDescription         = "Latest firmware baselines for production servers"
    
    iLOSettingName              = "Production-iLO-Settings"
    iLODescription              = "Secure iLO settings for production environment"
    iLOVirtualMedia             = "Enabled"
    iLOPasswordComplexity       = "Enabled"
    iLOWebServerSSL             = "Enabled"
    iLOThirdPartyFirmware       = "Disabled"
}

# Group Configuration
$GroupConfig = @{
    Name                                = "Production-Web-Servers"
    Description                         = "Production web server fleet"
    AutoBiosApplyOnAdd                  = $false
    AutoIloApplyOnAdd                   = $true
    AutoFirmwareUpdateOnAdd             = $false
    PowerOffServerAfterFirmwareUpdate   = $false
    FirmwareDowngradeAllowed            = $false
    AutoStorageVolumeCreationOnAdd      = $false
    AutoStorageVolumeDeletionOnAdd      = $false
    TagUsedForAutoAddServer             = "Application=WebServices"
}

# Email Notification Settings
$EmailNotifications = @{
    DailySummary                        = $true
    ServiceEventAndCriticalAndWarning   = $true
}

# Firmware Update Schedule (days from now)
$FirmwareUpdateInDays = 30

# Parking Lot Workspace (for cleanup - optional)
# If specified, devices will be moved here before workspace deletion
# If not specified, workspace deletion will be skipped if devices exist
# $ParkingLotWorkspace = $null  
$ParkingLotWorkspace = "MyParkingLotWorkspace"  

# ============================================================================
# SCRIPT EXECUTION - Do not modify below unless you know what you're doing
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

Write-SectionHeader "HPE COMPUTE OPS MANAGEMENT - ZERO TOUCH AUTOMATION"
Write-Info "Started at: $($StartTime.ToString('yyyy-MM-dd HH:mm:ss'))"
Write-Info "Workspace: $($WorkspaceConfig.Name)"



# ============================================================================
# STEP 1: Module Import and Authentication
# ============================================================================
Write-SectionHeader "STEP 1: Module Import and Authentication"

try {
    Import-Module HPECOMCmdlets -ErrorAction Stop
    Write-Success "HPECOMCmdlets module imported successfully"
}
catch {
    Write-Failure "Failed to import HPECOMCmdlets module: $($_.Exception.Message)"
    Write-Info "Install the module using: Install-Module HPECOMCmdlets"
    exit 1
}

# Check for existing valid session
$SessionValid = $false
$Credential = $null

if ($Global:HPEGreenLakeSession.IsValid -and $Global:HPEGreenLakeSession.username -eq $MyEmail) {
    Write-Success "Using existing valid session for $MyEmail"
    $SessionValid = $true
}

if (-not $SessionValid) {
    Write-Info "Connecting to HPE GreenLake (you will be prompted for credentials)..."
    try {
        $Credential = Get-Credential -UserName $MyEmail -Message "Enter your HPE GreenLake credentials"
        Connect-HPEGL -Credential $Credential -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
        Write-Success "Connected to HPE GreenLake successfully"
    }
    catch {
        Write-Failure "Failed to connect to HPE GreenLake: $($_.Exception.Message)"
        exit 1
    }
}

# ============================================================================
# STEP 2: Workspace Creation
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
    
    # Reuse credentials if we already have them, otherwise prompt
    if (-not $Credential) {
        $Credential = Get-Credential -UserName $MyEmail -Message "Enter your HPE GreenLake credentials"
    }
    
    Connect-HPEGL -Credential $Credential -Workspace $WorkspaceConfig.Name -NoProgress -ErrorAction Stop -WarningAction SilentlyContinue | Out-Null
    Write-Success "Connected to workspace '$($WorkspaceConfig.Name)' successfully"
}
catch {
    Write-Failure "Failed to connect to workspace: $($_.Exception.Message)"
    exit 1
}

# ============================================================================
# STEP 3: User Provisioning
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

# ============================================================================
# STEP 4: Enable Compute Ops Management Service
# ============================================================================
Write-SectionHeader "STEP 4: Enable Compute Ops Management Service"

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
    
    $RoleTask2 = Add-HPEGLRoleToUser -RoleName 'Compute Ops Management administrator' -Email $AdditionalUser.Email
    if ($RoleTask2.Status -eq "Complete") {
        Write-Success "COM administrator role assigned to $($AdditionalUser.Email)"
    }
}
catch {
    Write-Failure "Failed to assign roles: $($_.Exception.Message)"
    exit 1
}

# ============================================================================
# STEP 5: Location Creation
# ============================================================================
Write-SectionHeader "STEP 5: Location Creation"

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

# ============================================================================
# STEP 6: Add Subscriptions and Configure Policies
# ============================================================================
Write-SectionHeader "STEP 6: Add Subscriptions and Configure Policies"

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
}
catch {
    Write-Failure "Failed to enable auto-reassign policy: $($_.Exception.Message)"
}

# ============================================================================
# STEP 7: Server Onboarding
# ============================================================================
Write-SectionHeader "STEP 7: Server Onboarding ($($Servers.Count) servers)"

$OnboardedServers = @()

foreach ($Server in $Servers) {
    Write-Info "`nOnboarding server: $($Server.iLOIP) ($($Server.Model))..."
    
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
        
        $maxRetries = 3
        $retryCount = 0
        $ConnectionTask = $null
        
        while ($retryCount -lt $maxRetries) {
            $retryCount++
            try {
                $ConnectionTask = Connect-HPEGLDeviceComputeiLOtoCOM `
                    -iLOCredential $iLOCredential `
                    -IloIP $Server.iLOIP `
                    -ActivationKeyfromCOM $ActivationKey `
                    -SkipCertificateValidation `
                    -RemoveExistingiLOProxySettings `
                    -ResetiLOIfProxyErrorPersists
                
                if ($ConnectionTask.Status -eq "Complete") {
                    break
                }
                else {
                    if ($retryCount -lt $maxRetries) {
                        Write-Info "Connection attempt $retryCount failed. Retrying in 5 seconds..."
                        Start-Sleep -Seconds 5
                    }
                }
            }
            catch {
                if ($retryCount -lt $maxRetries) {
                    Write-Info "Connection attempt $retryCount failed: $($_.Exception.Message). Retrying..."
                    Start-Sleep -Seconds 5
                }
                else {
                    throw
                }
            }
        }
        
        if ($retryCount -eq $maxRetries -and $ConnectionTask.Status -ne "Complete") {
            Write-Host "✗ iLO connection task failed after $maxRetries attempts: $($ConnectionTask.Details)" -ForegroundColor Red
            exit
        }
        elseif ($ConnectionTask.Status -eq "Complete") {
            Write-Success "iLO $($Server.iLOIP) connected to Compute Ops Management"
            $OnboardedServers += $Server.iLOIP
        }
        else {
            Write-Failure "iLO connection failed: $($ConnectionTask.Status) - $($ConnectionTask.Details)"
            continue
        }
    }
    catch {
        Write-Failure "Failed to connect iLO to COM: $($_.Exception.Message)"
        continue
    }
    
    # Wait for device to appear in COM (give it some time to sync)
    Write-Info "Waiting for device to appear in COM inventory..."
    Start-Sleep -Seconds 10
}

Write-Info "`nSuccessfully onboarded $($OnboardedServers.Count) of $($Servers.Count) servers"

# ============================================================================
# STEP 8: Device Configuration (Location, Tags, Contacts)
# ============================================================================
Write-SectionHeader "STEP 8: Device Configuration"

# Get all devices
$Devices = Get-HPEGLDevice
Write-Info "Found $($Devices.Count) device(s) in workspace"

if ($Devices) {
    # Set Location
    try {
        Write-Info "Setting device location to '$($LocationConfig.Name)'..."
        $LocationSetTask = $Devices | Set-HPEGLDeviceLocation -LocationName $LocationConfig.Name
        
        if ($LocationSetTask.Status -eq "Complete") {
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
        
        if ($TagsTask.Status -eq "Complete") {
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
        
        if ($ContactTask.Status -eq "Complete") {
            Write-Success "Service delivery contact set to $MyEmail"
        }
    }
    catch {
        Write-Failure "Failed to set service delivery contact: $($_.Exception.Message)"
    }
}

# ============================================================================
# STEP 9: Create Server Settings
# ============================================================================
Write-SectionHeader "STEP 9: Create Server Settings"

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
        -PasswordComplexity $SettingsConfig.iLOPasswordComplexity `
        -WebServerSSL $SettingsConfig.iLOWebServerSSL `
        -AcceptThirdPartyFirmwareUpdates $SettingsConfig.iLOThirdPartyFirmware
    
    if ($iLOTask.Status -eq "Complete") {
        Write-Success "iLO setting '$($SettingsConfig.iLOSettingName)' created successfully"
    }
}
catch {
    Write-Failure "Failed to create iLO setting: $($_.Exception.Message)"
}

# ============================================================================
# STEP 10: Create Group and Add Servers
# ============================================================================
Write-SectionHeader "STEP 10: Create Group and Add Servers"

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
        Write-Success "Group '$($GroupConfig.Name)' created successfully"
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
        
        if ($AddServerTask.Status -eq "Complete") {
            Write-Success "Servers added to group '$($GroupConfig.Name)'"
        }
    }
    else {
        Write-Info "No servers found in COM to add to group"
    }
}
catch {
    Write-Failure "Failed to add servers to group: $($_.Exception.Message)"
}

# ============================================================================
# STEP 11: Enable Email Notifications
# ============================================================================
Write-SectionHeader "STEP 11: Enable Email Notifications"

try {
    Write-Info "Enabling email notification policies..."
    $EmailTask = Enable-HPECOMEmailNotificationPolicy `
        -Region $COMRegion `
        -DailySummary:$EmailNotifications.DailySummary `
        -ServiceEventAndCriticalAndWarningIssues:$EmailNotifications.ServiceEventAndCriticalAndWarning
    
    if ($EmailTask.Status -eq "Complete") {
        Write-Success "Email notification policies enabled successfully"
    }
}
catch {
    Write-Failure "Failed to enable email notifications: $($_.Exception.Message)"
}

# ============================================================================
# STEP 12: Schedule Firmware Update
# ============================================================================
Write-SectionHeader "STEP 12: Schedule Firmware Update"

try {
    $UpdateDate = (Get-Date).AddDays($FirmwareUpdateInDays)
    Write-Info "Scheduling firmware update for group '$($GroupConfig.Name)' on $($UpdateDate.ToString('yyyy-MM-dd HH:mm'))..."
    
    $FirmwareUpdateTask = Update-HPECOMGroupFirmware `
        -Region $COMRegion `
        -GroupName $GroupConfig.Name `
        -AllowFirmwareDowngrade `
        -InstallHPEDriversAndSoftware `
        -ScheduleTime $UpdateDate
    
    if ($FirmwareUpdateTask.NextStartAt) {
        Write-Success "Firmware update scheduled for $($FirmwareUpdateTask.NextStartAt)"
    }
}
catch {
    Write-Failure "Failed to schedule firmware update: $($_.Exception.Message)"
}

# ============================================================================
# COMPLETION SUMMARY
# ============================================================================
$EndTime = Get-Date
$Duration = $EndTime - $StartTime

Write-SectionHeader "AUTOMATION COMPLETED"
Write-Success "Zero Touch Automation workflow completed!"
Write-Info "Workspace: $($WorkspaceConfig.Name)"
Write-Info "Region: $COMRegion"
Write-Info "Servers Onboarded: $($OnboardedServers.Count)"
Write-Info "Duration: $($Duration.ToString('mm\:ss'))"
Write-Info "Completed at: $($EndTime.ToString('yyyy-MM-dd HH:mm:ss'))"

Write-Host "`nNext Steps:" -ForegroundColor Cyan
Write-Host "  1. Log in to HPE GreenLake portal to verify workspace and server configuration" -ForegroundColor White
Write-Host "  2. Review server settings and adjust as needed for your environment" -ForegroundColor White
Write-Host "  3. Monitor firmware update schedule and server health" -ForegroundColor White
Write-Host "  4. Configure additional automation workflows as required" -ForegroundColor White

# ============================================================================
# OPTIONAL: CLEANUP ENVIRONMENT
# ============================================================================
Write-Host "`n" -ForegroundColor White
$CleanupResponse = Read-Host "Do you want to clean up the environment now? (Y/N)"

if ($CleanupResponse -eq 'Y' -or $CleanupResponse -eq 'y') {
    Write-SectionHeader "ENVIRONMENT CLEANUP"
    $CleanupStartTime = Get-Date
    $CleanupErrors = @()
    
    Write-Info "Starting cleanup process for workspace: $($WorkspaceConfig.Name)"
    
    # Save current workspace session for later restoration
    $CurrentWorkspaceSession = $Global:HPEGreenLakeSession.Clone()
    
    # Get devices before any cleanup
    $DevicesBeforeCleanup = $null
    try {
        $DevicesBeforeCleanup = Get-HPEGLDevice
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
        $Devices = Get-HPEGLDevice
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
                            # Write-Info "iLO $($Server.iLOIP) is already disconnected from COM"
                            Write-Success "iLO $($Server.iLOIP) disconnected from COM"
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
            $Users | Remove-HPEGLUser | Out-Null
            Write-Success "Additional user(s) removed"
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
        }
        else {
            Write-Info "No COM service to remove"
        }
    }
    catch {
        Write-Failure "Error removing service: $($_.Exception.Message)"
        $CleanupErrors += "Service removal: $($_.Exception.Message)"
    }
    
    # Move devices to parking lot workspace (if configured and devices exist)
    if ($DevicesBeforeCleanup -and $DevicesBeforeCleanup.Count -gt 0) {
        if ($ParkingLotWorkspace) {
            try {
                Write-Info "Moving $($DevicesBeforeCleanup.Count) device(s) to parking lot workspace '$ParkingLotWorkspace'..."
                
                # Connect to parking lot workspace
                Connect-HPEGL -Credential $Credential -Workspace $ParkingLotWorkspace -NoProgress -ErrorAction Stop | Out-Null
                
                foreach ($device in $DevicesBeforeCleanup) {
                    try {
                        Add-HPEGLDeviceCompute -SerialNumber $device.serialnumber -PartNumber $device.partNumber | Out-Null
                        Write-Success "Device '$($device.serialnumber)' moved to parking lot"
                    }
                    catch {
                        Write-Failure "Error moving device '$($device.serialnumber)': $($_.Exception.Message)"
                        $CleanupErrors += "Device move: $($_.Exception.Message)"
                    }
                }
                
                # Restore workspace session for deletion
                $Global:HPEGreenLakeSession = $CurrentWorkspaceSession
                
                # Wait for operations to settle
                Write-Info "Waiting for device moves and service removal to propagate..."
                Start-Sleep -Seconds 5
            }
            catch {
                Write-Failure "Error moving devices to parking lot: $($_.Exception.Message)"
                $CleanupErrors += "Parking lot move: $($_.Exception.Message)"
                # Restore workspace session even on error
                $Global:HPEGreenLakeSession = $CurrentWorkspaceSession
            }
        }
        else {
            Write-Failure "Cannot delete workspace: $($DevicesBeforeCleanup.Count) device(s) still present"
            Write-Info "Configure `$ParkingLotWorkspace variable to move devices before workspace deletion"
            $CleanupErrors += "Workspace has devices but no parking lot configured"
        }
    }
    else {
        # No devices to move, just wait for service removal
        Write-Info "Waiting for service removal to propagate..."
        Start-Sleep -Seconds 10
    }
    
    # Delete workspace (only if no devices or devices were moved)
    $CanDeleteWorkspace = (-not $DevicesBeforeCleanup) -or ($ParkingLotWorkspace -and $DevicesBeforeCleanup)
    
    if ($CanDeleteWorkspace) {
        try {
            # Reconnect to workspace to ensure proper session state before deletion
            Write-Info "Reconnecting to workspace for deletion..."
            $Global:HPEGreenLakeSession = $CurrentWorkspaceSession.Clone()
            
            Write-Info "Deleting workspace '$($WorkspaceConfig.Name)'..."
            $RemoveResult = Remove-HPEGLWorkspace -Force
            if ($RemoveResult.status -in @("Complete", "Completed")) {
                Write-Success "Workspace '$($WorkspaceConfig.Name)' deleted successfully"
            }
            else {
                Write-Failure "Workspace deletion returned unexpected status: $($RemoveResult.status)"
                $CleanupErrors += "Workspace deletion status: $($RemoveResult.status)"
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
    Write-Info "Cleanup Duration: $($CleanupDuration.ToString('mm\:ss'))"
    Write-Info "Completed at: $($CleanupEndTime.ToString('yyyy-MM-dd HH:mm:ss'))"
    Write-Info "Total Script Duration (Provisioning + Cleanup): $(($CleanupEndTime - $StartTime).ToString('mm\:ss'))"
}
else {
    Write-Host "`nCleanup skipped. Workspace '$($WorkspaceConfig.Name)' remains active." -ForegroundColor Cyan
}

Write-Host "`n" -ForegroundColor White
