#------------------- FUNCTIONS FOR COMPUTE OPS MANAGEMENT SERVERS -----------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1

# Public functions
Function Get-HPECOMServer {
    <#
    .SYNOPSIS
    Retrieve the list of servers.
    
    .DESCRIPTION
    This Cmdlet returns a collection of server resources in the specified region. Switch parameters can be used to retrieve specific data such as alerts, external storage details, notification status, security parameters, adapter to switch port mapping, and to check the presence of storage volume for OS installation.
    
    For server inventory data, you must use 'Get-HPECOMServerInventory'.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER Name 
    Specifies the name or serial number of the server to display. 
    
    .PARAMETER Model 
    Optional parameter that can be used to display a specific server model only, such as 'ProLiant DL380 Gen11', 'ProLiant DL365 Gen11', etc. 
    Partial model names are not supported.
    
    .PARAMETER ConnectionType
    Optional parameter that can be used to display servers based on the connection type (Direct, OneView managed or Secure gateway).
    
    .PARAMETER ConnectedState
    A Boolean value (True or False). When set to True, only servers that are connected to HPE GreenLake will be displayed. When set to False, only servers that are not connected will be displayed.
    
    .PARAMETER PowerState
    A value of ON or OFF. When set to ON, only servers that are powered on will be displayed. When set to OFF, only servers that are powered off will be displayed.

    .PARAMETER Limit 
    This parameter allows you to define a limit on the number of servers to be displayed. 

    .PARAMETER ShowActivities
    Optional parameter that can be used to retrieve activities from the last month for the specified server.
    When used with -Name, retrieves activities for that specific server. 
    When used without -Name, retrieves activities for all servers in the region.

    .PARAMETER ShowJobs
    Optional parameter that can be used to retrieve jobs from the last month for the specified server.
    When used with -Name, retrieves jobs for that specific server.
    When used without -Name, retrieves jobs for all servers in the region.
    
    .PARAMETER ShowAlerts 
    Optional parameter that can be used to get the server alerts. Alerts provide security information and issues related to servers.

    .PARAMETER ShowHealthStatus 
    Optional parameter that can be used to get the server health status including overall health summary, fans, memory, network, power supplies, processor, storage, temperature, BIOS, and health LED status.
    Note: The default table view displays the most commonly used properties. Use Format-List or Select-Object * to view all properties including redundancy states (fanRedundancy, liquidCoolingRedundancy, powerSupplyRedundancy), liquidCooling, smartStorage, and connectionType.

    .PARAMETER ShowLocation 
    Optional parameter that can be used to get the server location.

    .PARAMETER ShowGroupMembership 
    Optional parameter that can be used to get the server group membership.

    .PARAMETER ShowGroupCompliance
    Optional parameter that can be used when a server is a member of a group to get comprehensive compliance status for all compliance types (firmware, iLO settings, and external storage).

    .PARAMETER ShowGroupFirmwareCompliance
    Optional parameter that can be used when a server is a member of a group to get the group firmware compliance. 
    This parameter allows you to check if the server is compliant with the group's firmware baseline (if any).
    
    Returns the following properties for the server:
    - Server: Server name
    - SerialNumber: Server serial number
    - Group: Group name the server belongs to
    - State: Compliance state (Compliant, Not Compliant, Unknown, etc.)
    - Score: Compliance score percentage (e.g., 25% indicates 25% compliant)
    - ErrorReason: Reason for compliance failure if applicable
    - Criticality: Severity level of the firmware update (Recommended, Critical, Optional)
    - Deviations: Number of firmware components that deviate from the group's baseline
    - WillItRebootTheServer: Indicates if applying the update will reboot the server (Yes/No)
    - GracefullShutdownAttempt: Indicates if a graceful shutdown will be attempted before reboot (Yes/No)
    - TotalDownloadSize: Total size of firmware updates to download (e.g., 40 MB)

    .PARAMETER ShowGroupFirmwareDeviation
    Optional parameter that can be used when a server is a member of a group to get detailed firmware component deviations from the group's firmware baseline.
    
    Returns the following properties for each firmware component that deviates:
    - ComponentName: Name of the firmware component (e.g., System ROM, NIC, Boot Controller)
    - ExpectedVersion: Firmware version expected by the group's baseline
    - InstalledVersion: Currently installed firmware version on the server
    - ComponentFilename: Filename of the firmware update package
    
    This parameter is useful for identifying specific firmware components that need updates to comply with the group's baseline.

    .PARAMETER ShowGroupiLOSettingsCompliance
    Optional parameter that can be used when a server is a member of a group to get the group iLO settings compliance.

    .PARAMETER ShowGroupExternalStorageCompliance
    Optional parameter that can be used when a server is a member of a group to get the group external storage compliance.

    .PARAMETER ShowSupportDetails
    Optional parameter that can be used to get the server support details.

    .PARAMETER ShowServersWithRecentSupportCases
    Optional parameter that can be used to get the servers with recent support cases.
    This parameter can be useful for identifying servers that have had recent issues or support cases opened, allowing for proactive management and resolution of potential problems.
    
    .PARAMETER ShowSupportCases
    Optional parameter to retrieve HPE support cases automatically generated by Compute Ops Management for issues related to the specified server. 
    If no support cases are found for the specified server, the cmdlet returns no output.

    .PARAMETER ShowSubscriptionDetails
    Optional parameter that can be used to get the subscription details for the specified server.

    .PARAMETER ShowAutoiLOFirmwareUpdateStatus
    Optional parameter that can be used to get the status of the automatic iLO firmware update configuration.
    
    .PARAMETER ShowNotificationStatus 
    Optional parameter that can be used to get the server notification status. 
    
    .PARAMETER ShowSecurityParameters 
    Optional parameter that can be used to get the server security parameters. 

    .PARAMETER ShowSecurityParametersDetails 
    Optional parameter that can be used to get the server security parameter details. 

    .PARAMETER CheckifserverHasStorageVolume 
    Optional parameter that can be used to validate the presence of a storage volume for the server 
    specified for operating system installation. The response returned is a boolean.

    .PARAMETER ShowExternalStorageDetails 
    Optional parameter that can be used to get the server external storage details. 
    
    .PARAMETER ShowAdapterToSwitchPortMappings 
    Optional parameter that can be used to get the network connectivity of the adapter port to the connected switch port of the server. 

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central

    Returns data for all servers located in the Central European region. 

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Limit 50

    Returns the first 50 servers located in the Central European region. 
    
    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name sles15sp4

    Returns the server data for the server named 'sles15sp4' located in the Central European region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name TWA22525A6 

    Returns the server data for the server with the serial number 'TWA22525A6'.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-1.domain.lab -ShowGroupMembership

    This command returns the group membership of the server with name 'ESX-1.domain.lab'.

    .EXAMPLE
    Get-HPECOMserver -Region eu-central -Name ESX-1 -ShowGroupFirmwareCompliance 

    This command returns the group firmware compliance report of the server with name 'ESX-1' if it is a member of a group with a compatible firmware baseline.

    .EXAMPLE
    Get-HPECOMserver -Region eu-central -Name ESX-1 -ShowGroupCompliance 

    This command returns the comprehensive group compliance report (firmware, iLO settings, and external storage) for the server with name 'ESX-1' if it is a member of a group.

    .EXAMPLE
    Get-HPECOMserver -Region eu-central -Name ESX-1 -ShowGroupiLOSettingsCompliance 

    This command returns the group iLO settings compliance report for the server with name 'ESX-1' if it is a member of a group.

    .EXAMPLE
    Get-HPECOMserver -Region eu-central -Name ESX-1 -ShowGroupExternalStorageCompliance 

    This command returns the group external storage compliance report for the server with name 'ESX-1' if it is a member of a group with external storage configured.

    .EXAMPLE
    Get-HPECOMserver -Region eu-central -Name ESX-1 -ShowGroupFirmwareDeviation 

    This command returns the firmware components of the server with name 'ESX-1' that have deviations from the group's firmware baseline if it is a member of a group with a compatible firmware baseline.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-1.domain.lab -ShowAlerts

    This command returns the alerts of the server with name 'ESX-1.domain.lab'.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-1 -ShowHealthStatus

    This command returns the health status details of the server with name 'ESX-1', including overall health summary, component health (fans, memory, network, power supplies, processor, storage, temperature, BIOS), redundancy states, and health LED status.

    .EXAMPLE
    Get-HPECOMServer -Region us-west -ShowServersWithRecentSupportCases

    This command returns the servers that have had recent support cases opened in the US West region.

    .EXAMPLE
    Get-HPECOMServer -Region us-west -Name ESX-1 -ShowSupportCases 

    This command returns the support cases for the server with name 'ESX-1' in the US West region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name TWA22525A6 -ShowSubscriptionDetails

    This command returns the subscription details for the server with name 'TWA22525A6' in the Central European region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -ConnectionType Direct

    This command returns the servers that are directly connected to HPE GreenLake in the Central European region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -ConnectionType 'OneView managed'

    This command returns the servers that are managed by OneView in the Central European region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -ConnectionType 'Secure gateway'

    This command returns the servers that are connected to HPE GreenLake through a secure gateway in the Central European region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -ShowLocation

    This command returns the location of all servers in the Central European region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-1.domain.lab -ShowLocation

    This command returns the location of the server with name 'ESX-1.domain.lab'.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-1.domain.lab -ShowNotificationStatus

    This command returns the notification status of the server with name 'ESX-1.domain.lab'.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -ShowSecurityParameters

    This command returns the security parameters of all servers in the Central European region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-1.domain.lab -ShowSecurityParameters

    This command returns the security parameters of the server with name 'ESX-1.domain.lab'.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-1.domain.lab -ShowSecurityParametersDetails

    This command returns the security parameters details of the server with name 'ESX-1.domain.lab'.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-1.domain.lab -ShowAdapterToSwitchPortMappings

    This command returns the adapter to switch port mappings of the server with name 'ESX-1.domain.lab'.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -ShowAutoiLOFirmwareUpdateStatus

    This command returns the auto iLO firmware update status of all servers in the Central European region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-1.domain.lab -ShowAutoiLOFirmwareUpdateStatus

    This command returns the auto iLO firmware update status of the server with name 'ESX-1.domain.lab'.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-1.domain.lab -ShowExternalStorageDetails

    This command returns the external storage details of the server with name 'ESX-1.domain.lab'.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-1.domain.lab -ShowActivities

    This command returns the last month activities for the server with name 'ESX-1.domain.lab'.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-1.domain.lab -ShowJobs

    This command returns the last month jobs for the server with name 'ESX-1.domain.lab'.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -PowerState ON -ShowJobs

    This command returns the last month jobs for all powered on servers in the central EU region.

    .EXAMPLE
    Get-HPECOMServer -Region us-west -ConnectedState False
    
    Lists all servers that are not connected to Compute Ops Management.

    .EXAMPLE
    Get-HPECOMServer -Region us-west -ConnectedState True -PowerState ON

    Lists all servers that are powered on and connected to Compute Ops Management.
    
    .EXAMPLE
    Get-HPECOMServer -Region us-west -Model "ProLiant DL325 Gen10 Plus" -PowerState ON 

    Lists all ProLiant DL325 Gen10 Plus servers that are powered on.
    
    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-1.domain.lab -CheckIfServerHasStorageVolume

    This command returns a True or False to indicate if the server with name 'ESX-1.domain.lab' has a storage volume for OS installation.

    .EXAMPLE
    "ESX-1", "ESX-2" | Get-HPECOMServer -Region eu-central

    Returns all servers that match the names given in the pipeline.

    .EXAMPLE
    "ESX-1", "ESX-2" | Get-HPECOMServer -Region eu-central -ShowSecurityParameters

    Retrieves server security parameters for the two servers with the specified names in the pipeline.

    .EXAMPLE
    Get-HPECOMServer -Limit 2 | Get-HPECOMServer -Region eu-central -ShowNotificationStatus 
    
    Gets the first two servers in HPE GreenLake and passes their names into the pipeline to retrieve their server notification status.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's names.
    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer'.

#>

    [CmdletBinding(DefaultParameterSetName = 'ByName')]
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

        [Parameter (ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ByName')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'WithNameForbidFilters')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'JobsWithNameForbidFilters')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'AdapterToSwitchPortMappingsName')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'AlertsName')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ShowServersWithShowSupportDetails')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ShowSupportCasesName')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'GroupFirmwareDeviationName')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SecurityParametersDetailsName')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SubscriptionDetailsName')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ShowSupportDetailsName')]
        [String]$Name,
        
        # Filter Parameters
        [Parameter (ParameterSetName = 'ByName')]
        [Parameter (ParameterSetName = 'Other')]
        [Parameter (ParameterSetName = 'ShowSupportDetailsWithoutName')]
        [Parameter (ParameterSetName = 'ActivitiesWithoutName')]
        [Parameter (ParameterSetName = 'JobsWithoutName')]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Direct', 'OneView managed', 'Secure gateway')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Direct', 'OneView managed', 'Secure gateway')]
        [String]$ConnectionType,

        
        [Parameter (ParameterSetName = 'ByName')]
        [Parameter (ParameterSetName = 'Other')]
        [Parameter (ParameterSetName = 'ShowSupportDetailsWithoutName')]
        [Parameter (ParameterSetName = 'ActivitiesWithoutName')]
        [Parameter (ParameterSetName = 'JobsWithoutName')]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('True', 'False')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('True', 'False')]
        [String]$ConnectedState,
    
        [Parameter (ParameterSetName = 'ByName')]
        [Parameter (ParameterSetName = 'Other')]
        [Parameter (ParameterSetName = 'ShowSupportDetailsWithoutName')]
        [Parameter (ParameterSetName = 'ActivitiesWithoutName')]
        [Parameter (ParameterSetName = 'JobsWithoutName')]
        [String]$Model,
        
        [Parameter (ParameterSetName = 'ByName')]
        [Parameter (ParameterSetName = 'Other')]
        [Parameter (ParameterSetName = 'ShowSupportDetailsWithoutName')]
        [Parameter (ParameterSetName = 'ActivitiesWithoutName')]
        [Parameter (ParameterSetName = 'JobsWithoutName')]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('ON', 'OFF')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('ON', 'OFF')]
        [String]$PowerState,

        [Parameter (ParameterSetName = 'ByName')]
        [Parameter (ParameterSetName = 'Other')]
        [Parameter (ParameterSetName = 'ShowServersWithRecentSupportCases')]
        [Parameter (ParameterSetName = 'ShowSupportDetailsWithoutName')]
        [Parameter (ParameterSetName = 'ActivitiesWithoutName')]
        [Parameter (ParameterSetName = 'JobsWithoutName')]
        [ValidateRange(1, 100)]
        [int]$Limit,

        [Parameter (ParameterSetName = 'ActivitiesWithoutName')]
        [Parameter (ParameterSetName = 'WithNameForbidFilters')]
        [Switch]$ShowActivities,

        [Parameter (ParameterSetName = 'JobsWithoutName')]
        [Parameter (ParameterSetName = 'JobsWithNameForbidFilters')]
        [Switch]$ShowJobs,

        [Parameter (ParameterSetName = 'AlertsName')]
        [Switch]$ShowAlerts,

        # Basic Server Information
        [Parameter (ParameterSetName = 'HealthStatusWithoutName')]
        [Parameter (ParameterSetName = 'WithNameForbidFilters')]
        [Switch]$ShowHealthStatus,

        [Parameter (ParameterSetName = 'LocationWithoutName')]
        [Parameter (ParameterSetName = 'WithNameForbidFilters')]
        [Switch]$ShowLocation,

        # Group-Related Parameters
        [Parameter (ParameterSetName = 'GroupMembershipWithoutName')]
        [Parameter (ParameterSetName = 'WithNameForbidFilters')]
        [Switch]$ShowGroupMembership,

        [Parameter (ParameterSetName = 'GroupComplianceWithoutName')]
        [Parameter (ParameterSetName = 'WithNameForbidFilters')]
        [Switch]$ShowGroupCompliance,

        [Parameter (ParameterSetName = 'GroupFirmwareComplianceWithoutName')]
        [Parameter (ParameterSetName = 'WithNameForbidFilters')]
        [Switch]$ShowGroupFirmwareCompliance,
            
        [Parameter (ParameterSetName = 'GroupFirmwareDeviationName')]
        [Switch]$ShowGroupFirmwareDeviation,

        [Parameter (ParameterSetName = 'GroupiLOSettingsComplianceWithoutName')]
        [Parameter (ParameterSetName = 'WithNameForbidFilters')]
        [Switch]$ShowGroupiLOSettingsCompliance,

        [Parameter (ParameterSetName = 'GroupExternalStorageComplianceWithoutName')]
        [Parameter (ParameterSetName = 'WithNameForbidFilters')]
        [Switch]$ShowGroupExternalStorageCompliance,

        # Support & Subscription Parameters
        [Parameter (ParameterSetName = 'ShowSupportDetailsName')]
        [Parameter (ParameterSetName = 'ShowSupportDetailsWithoutName')]
        [Switch]$ShowSupportDetails,

        [Parameter (ParameterSetName = 'ShowServersWithRecentSupportCases')]
        [Switch]$ShowServersWithRecentSupportCases,
        
        [Parameter (ParameterSetName = 'ShowSupportCasesName')]
        [Switch]$ShowSupportCases,

        [Parameter (ParameterSetName = 'SubscriptionDetailsWithoutName')]
        [Parameter (ParameterSetName = 'SubscriptionDetailsName')]
        [Switch]$ShowSubscriptionDetails,

        # Configuration & Settings Parameters
        [Parameter (ParameterSetName = 'AutoiLOFirmwareUpdateStatusWithoutName')]
        [Parameter (ParameterSetName = 'WithNameForbidFilters')]
        [Switch]$ShowAutoiLOFirmwareUpdateStatus,
    
        [Parameter (ParameterSetName = 'NotificationStatusWithoutName')]
        [Parameter (ParameterSetName = 'WithNameForbidFilters')]
        [Switch]$ShowNotificationStatus,
        
        [Parameter (ParameterSetName = 'SecurityParametersWithoutName')]
        [Parameter (ParameterSetName = 'WithNameForbidFilters')]
        [Switch]$ShowSecurityParameters,
        
        [Parameter (ParameterSetName = 'SecurityParametersDetailsName')]
        [Switch]$ShowSecurityParametersDetails,

        # Storage & Network Parameters
        [Parameter (ParameterSetName = 'CheckifserverHasStorageVolumeWithoutName')]
        [Parameter (ParameterSetName = 'WithNameForbidFilters')]
        [Switch]$CheckIfServerHasStorageVolume,
        
        [Parameter (ParameterSetName = 'ExternalStorageDetailsWithoutName')]
        [Parameter (ParameterSetName = 'WithNameForbidFilters')]
        [Switch]$ShowExternalStorageDetails,
        
        [Parameter (ParameterSetName = 'AdapterToSwitchPortMappingsName')]
        [Switch]$ShowAdapterToSwitchPortMappings,

        [Switch]$WhatIf
        
    ) 

    Begin {
  
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        # Validate only one Show* parameter is specified
        $ShowParameters = @(
            'ShowAlerts', 'ShowSupportDetails', 'ShowServersWithRecentSupportCases', 'ShowSupportCases',
            'ShowSubscriptionDetails', 'ShowAdapterToSwitchPortMappings', 'ShowAutoiLOFirmwareUpdateStatus',
            'ShowExternalStorageDetails', 'ShowGroupMembership', 'ShowGroupFirmwareCompliance',
            'ShowGroupCompliance', 'ShowGroupiLOSettingsCompliance', 'ShowGroupExternalStorageCompliance',
            'ShowGroupFirmwareDeviation', 'ShowLocation', 'ShowNotificationStatus', 'ShowSecurityParameters',
            'ShowSecurityParametersDetails', 'ShowHealthStatus', 'ShowActivities', 'ShowJobs'
        )
        
        $SpecifiedShowParams = $ShowParameters | Where-Object { $PSBoundParameters.ContainsKey($_) }
        
        if ($SpecifiedShowParams.Count -gt 1) {
            throw "Only one Show* parameter can be specified at a time. You specified: $($SpecifiedShowParams -join ', ')"
        }

        # Validate CheckIfServerHasStorageVolume is not combined with any Show* parameter
        if ($PSBoundParameters.ContainsKey('CheckIfServerHasStorageVolume') -and $SpecifiedShowParams.Count -gt 0) {
            throw "CheckIfServerHasStorageVolume cannot be combined with Show* parameters. You specified: CheckIfServerHasStorageVolume and $($SpecifiedShowParams -join ', ')"
        }

        $Uri = Get-COMServersUri 
   
      
    }
      
      
    Process {
      
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        # Set URI
        if ($Name) {       

            # $Uri = (Get-COMServersUri) + "?filter=name eq '$Name'"   # Filter that supports only serial numbers
            $Uri = (Get-COMServersUri) + "?filter=(host/hostname eq '$Name' or name eq '$Name')"   # Filter that supports both serial numbers and server names
            # Added the parentheses to fix issue when other filters are added with and
        }
        else {
            
            $Uri = Get-COMServersUri 

        }       
           
        if ($PSBoundParameters.ContainsKey('Model')) {

            if ($Uri -match "\?filter=" ) {
                
                $Uri = $Uri + " and hardware/model eq '$Model'"

            }
            else {

                $Uri = $Uri + "?filter=hardware/model eq '$Model'"

            }
        }
       
        if ($PSBoundParameters.ContainsKey('ConnectedState')) {

            if ($ConnectedState -eq 'True') {	
    
                if ($Uri -match "\?filter=" ) {

                    $Uri = $Uri + " and state/connected eq true"

                }
                else {
                    $Uri = $Uri + "?filter=state/connected eq true"

                }
            }
            else {

                if ($Uri -match "\?filter=" ) {

                    $Uri = $Uri + " and state/connected eq false"

                }
                else {
                    $Uri = $Uri + "?filter=state/connected eq false"

                }
            }
        }

        if ($PSBoundParameters.ContainsKey('PowerState')) {

            if ($PowerState -eq 'ON') {    

                if ($Uri -match "\?filter=" ) {

                    $Uri = $Uri + " and hardware/powerState eq 'ON'"

                }
                else {
                    $Uri = $Uri + "?filter=hardware/powerState eq 'ON'"

                }               
            }
            else {

                if ($Uri -match "\?filter=" ) {

                    $Uri = $Uri + " and hardware/powerState eq 'OFF'"

                }
                else {
                    $Uri = $Uri + "?filter=hardware/powerState eq 'OFF'"

                }   
            }
        }

        if ($PSBoundParameters.ContainsKey('Limit')) {
            
            if ($Uri -match "\?") {
                
                $Uri = $Uri + "&limit=$Limit"

            }
            else {
            
                $Uri = $Uri + "?limit=$Limit"

            }

        }


        # Parameters with $Name: verify only one server is found with $Name then collect server ID, SN and server ConnectionType (to detect OneView managed servers)
        if (       
                $ShowAlerts `
            -or $ShowSupportCases `
            -or ($ShowExternalStorageDetails -and $Name) `
            -or ($ShowLocation -and $Name) `
            -or ($ShowActivities -and $Name) `
            -or ($ShowJobs -and $Name) `
            -or ($ShowSupportDetails -and $Name) `
            -or ($ShowNotificationStatus -and $Name) `
            -or $ShowSecurityParametersDetails `
            -or $ShowAdapterToSwitchPortMappings `
            -or ($CheckifserverHasStorageVolume -and $Name) `
            -or ($ShowSubscriptionDetails -and $Name) `
        ) {
                

            try {
                [Array]$Server = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region 

                if ($Server.total -eq 0) { 
                    "[{0}] Server name '{1}' cannot be found. Exiting." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                    return           
                }
                elseif ($server.total -gt 1) {
                    "[{0}] Multiple servers found with the name '{1}'. Please refine your query to return only one server or use the serial number to retrieve the server details." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                    throw "Multiple servers found with the name '$Name'. Please refine your query to return only one server or use the serial number to retrieve the server details."
                }
                else {                    
                    $ServerID = $Server.id
                    $ServerSerialNumber = $Server.hardware.serialnumber
                    $ServerConnectionType = $server.connectionType # direct or oneview

                    if ($Null -eq $ServerID) {
                        "[{0}] No ID found for server name '{1}'. Exiting." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                        return
                    }
                    else {
                        "[{0}] ID found for server name '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $ServerID | Write-Verbose
                        "[{0}] Serial Number found for server name '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $ServerSerialNumber | Write-Verbose
                        "[{0}] Connection Type found for server name '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $ServerConnectionType | Write-Verbose
                    }
                }
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
           
            }
        }
     
        # Requests using $ServerID in URI    
        if ($ShowAlerts) {

            try {
                # Use Get-HPECOMAlert cmdlet instead of native API call
                $ServerNameOrSerial = if ($Name) { $Name } else { ($ServerID -split '\+')[1] }
                [Array]$CollectionList = Get-HPECOMAlert -Region $Region -SourceName $ServerNameOrSerial -WhatIf:$WhatIf -Verbose:$false
    
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
                   
            }

        }
        elseif ($ShowSupportDetails -or $ShowServersWithRecentSupportCases) {

            # Support details are retrieved today exclusively via the UI Doorway API endpoint
            if ($ShowSupportDetails -and $Name) {

                $Uri = (Get-COMServersUIDoorwayUri) + "/" + $ServerID 
            }
            else {
                $Uri = Get-COMServersUIDoorwayUri
            }

            if ($PSBoundParameters.ContainsKey('Model')) {

                if ($Uri -match "\?filter=" ) {
                    
                    $Uri = $Uri + " and hardware/model eq '$Model'"

                }
                else {

                    $Uri = $Uri + "?filter=hardware/model eq '$Model'"

                }
            }
        
            if ($PSBoundParameters.ContainsKey('ConnectedState')) {

                if ($ConnectedState -eq 'True') {	
        
                    if ($Uri -match "\?filter=" ) {

                        $Uri = $Uri + " and state/connected eq true"

                    }
                    else {
                        $Uri = $Uri + "?filter=state/connected eq true"

                    }
                }
                else {

                    if ($Uri -match "\?filter=" ) {

                        $Uri = $Uri + " and state/connected eq false"

                    }
                    else {
                        $Uri = $Uri + "?filter=state/connected eq false"

                    }
                }
            }

            if ($PSBoundParameters.ContainsKey('PowerState')) {

                if ($PowerState -eq 'ON') {    

                    if ($Uri -match "\?filter=" ) {

                        $Uri = $Uri + " and hardware/powerState eq 'ON'"

                    }
                    else {
                        $Uri = $Uri + "?filter=hardware/powerState eq 'ON'"

                    }               
                }
                else {

                    if ($Uri -match "\?filter=" ) {

                        $Uri = $Uri + " and hardware/powerState eq 'OFF'"

                    }
                    else {
                        $Uri = $Uri + "?filter=hardware/powerState eq 'OFF'"

                    }   
                }
            }

            if ($PSBoundParameters.ContainsKey('Limit')) {
                
                if ($Uri -match "\?") {
                    
                    $Uri = $Uri + "&limit=$Limit"

                }
                else {
                
                    $Uri = $Uri + "?limit=$Limit"

                }

            }

            "[{0}] Invoke web request using the UI Doorway URL to get support details: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri | Write-Verbose
            
            try {
                [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

                # Remove all items from $CollectionList that have the attribute connectionType equal to OneView and return a warning msg for each one this is removed
                foreach ($Item in $CollectionList) {
                    if ($Item.connectionType -eq 'OneView') {
                        if ($ShowSupportDetails){
                            Write-Warning "Support details are not available for server '$($Item.hardware.serialnumber)' because it is managed by HPE OneView."
                        }
                        else {
                            Write-Warning "Support case details are not available for server '$($Item.hardware.serialnumber)' because it is managed by HPE OneView."

                        }
                    }
                }
                $CollectionList = $CollectionList | Where-Object { $_.connectionType -ne 'OneView' }
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
        }
        elseif ($ShowSupportCases) {

            if ($ServerConnectionType -eq "DIRECT"){

                # Get server info
                $Uri = (Get-COMServersUIDoorwayUri) + "/" + $ServerID 
    
                # Invoke the web request using the UI Doorway URL - Needed to get support case information
                "[{0}] Invoke web request using the UI Doorway URL to get support case information: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri | Write-Verbose
                
                try {
                    [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
        
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                       
                }
    
                # Get server alerts
                $Uri = (Get-COMServersUIDoorwayUri) + "/" + $ServerID + "/alerts?offset=0&limit=800"
    
                # Invoke the web request using the UI Doorway URL - Needed to get support case information
                "[{0}] Invoke web request using the UI Doorway URL to get support case information: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri | Write-Verbose
                
                try {
                    [Array]$AlertsCollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference                 
    
                    $ListofCases = [System.Collections.ArrayList]::new()
    
                    foreach ($alert in $AlertsCollectionList) {
    
                        $Object = [PSCustomObject]@{
                            name = $CollectionList.name
                            serialnumber = $CollectionList.hardware.serialNumber
                            model = $CollectionList.hardware.model
                            iloIpAddress = $CollectionList.hardware.bmc.ip
                            description = $Null
                            resolution = $Null
                            message = $Null
                            caseId  = $Null
                            caseState = $Null
                            caseURL = $Null
                            caseMessage = $Null
                            createdAt = $Null
                            severity = $Null
                        }
    
                        if ($null -ne $alert.case_.Id) {
    
                            $Object.description = $alert.description
                            $Object.resolution = $alert.resolution
                            $Object.message = $alert.message
                            $Object.caseId = $alert.case_.caseId
                            $Object.caseState = $alert.case_.caseState
                            $Object.caseURL = $alert.case_.caseURL
                            $Object.caseMessage = $alert.case_.userMessage_
                            $Object.createdAt = $alert.createdAt
                            $Object.severity = $alert.severity
                            
                            [void]$ListofCases.Add($Object)                     
                        }
                    }
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                       
                }
            }
            else {
                Write-Warning "Support cases details are not available for server '$($Name)' because it is managed by HPE OneView."
                return
            }
        }
        elseif ($ShowExternalStorageDetails -and $Name) {

            if ($ServerConnectionType -eq "DIRECT"){

                $Uri = (Get-COMServersUri) + "/" + $ServerID + "/external-storage-details"

                "[{0}] About to run Invoke-HPECOMWebRequest using the URI to get external storage details: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri | Write-Verbose

                try {
                    [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference -ErrorAction Stop
                }
                catch {
                       
                    $exception = $_.Exception

                    "[{0}] Exception message: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $exception.Message | Write-Verbose                    
                    "[{0}] Exception type: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $exception.GetType().FullName | Write-Verbose
                    "[{0}] HTTP status code: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $exception.httpStatusCode | Write-Verbose

                    # Detect if this is the expected 404 "Run external storage details job" error
                    $isExternalStorage404 = $false
                    if (($exception.httpStatusCode -eq 404 -and $exception.message -match 'Run external storage details job')) {
                        $isExternalStorage404 = $true
                        "[{0}] Unable to retrieve external storage details for '{1}'. Detected 404 with 'Run external storage details job' message." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                    }

                    if (-not $isExternalStorage404) {
                        "[{0}] Rethrowing exception as it does not match expected 404 condition." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                        $PSCmdlet.ThrowTerminatingError($exception)
                    }
                    
                    if ($isExternalStorage404 ) {
                        # Trigger the external storage details job and then retry the GET request
                        try {
                            "[{0}] Triggering external storage details job for '{1}' to get external storage information." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
    
                            # throw "Operation stopped"
    
                            $jobResponse = Invoke-HPECOMServerExternalStorage -Region $Region -ServerSerialNumber $Name -Verbose:$VerbosePreference -ErrorAction Stop
    
                            if ($jobResponse.State -eq "Complete" -and $jobResponse.resultCode -eq "Success") {
                                
                                "[{0}] Job completed. Retrying GET request." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                Start-Sleep -Seconds 3
                                [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -Verbose:$VerbosePreference -ErrorAction Stop
                            } 
                            elseif ($jobResponse.State -eq "Complete" -and $jobResponse.resultCode -ne "Success" -and $jobResponse.Status -match "Server not in correct state for external storage details retrieval") {
                                Write-Warning "Unable to retrieve external storage details for '$($Name)'. Job result code: '$($jobResponse.resultCode)'. Please verify that the server is in the correct state for external storage details retrieval."
                                return
                            }
                            else {
                                Write-Warning "Unable to retrieve external storage details for '$($Name)'. Job result code: '$($jobResponse.resultCode)'. Please verify that the Data Services Cloud Console client credentials are correctly configured in your COM instance."
                                return
                            }
                        } 
                        catch {
                            "[{0}] Error during job trigger or retry: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                            Write-Warning "Unable to retrieve external storage details for '$($Name)': $_.Exception.Message"
                            return
                        }
                    }
                }
            }
            else {
                Write-Warning "External storage details are not available for server '$($Name)' because it is managed by HPE OneView."
                return
            }
        }
        elseif ($Showlocation){

            if ($Name){
                # if direct managed servers, use Get-HPEGLDevice
                if ($ServerConnectionType -eq "DIRECT"){

                    try {
                        $CollectionList = Get-HPEGLDevice -Name $ServerSerialNumber
                        $CollectionList | ForEach-Object { $_ | Add-Member -Type NoteProperty -Name LocationName -Value $_.location.name -Force }                            
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }
                }
                # if OneView managed servers use UI_Doorway (only place where location can be found)
                else {

                    $Uri = (Get-COMServersUIDoorwayUri) + "/" + $serverID

                    try {
                        # As OneView servers are not available in GLP, location must be retrieved from /ui-doorway/compute/v2/servers
                        $CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                        $CollectionList | ForEach-Object { $_ | Add-Member -Type NoteProperty -Name serverName -Value $_.name -Force }

                        $CollectionList | ForEach-Object { $_ | Add-Member -Type NoteProperty -Name serialNumber -Value ($_.Id -split '\+')[1] -Force }
                        $CollectionList | ForEach-Object { $_ | Add-Member -Type NoteProperty -Name Model -Value $_.hardware.model -Force }
                        $CollectionList | ForEach-Object { $_ | Add-Member -Type NoteProperty -Name LocationName -Value $_.locationInfo_.name -Force }
                        $CollectionList | ForEach-Object { $_ | Add-Member -Type NoteProperty -Name LocationID -Value $_.locationInfo_.locationId -Force }
                        
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                            
                    }
                }
            }
            else {

                # As OneView servers are not available in GLP, location must be retrieved from /ui-doorway/compute/v2/servers
                $Uri = Get-COMServersUIDoorwayUri 

                try {
                    $CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                    $CollectionList | ForEach-Object { $_ | Add-Member -Type NoteProperty -Name serverName -Value $_.name -Force }

                    $CollectionList | ForEach-Object { $_ | Add-Member -Type NoteProperty -Name serialNumber -Value ($_.Id -split '\+')[1] -Force }
                    $CollectionList | ForEach-Object { $_ | Add-Member -Type NoteProperty -Name Model -Value $_.hardware.model -Force }
                    $CollectionList | ForEach-Object { $_ | Add-Member -Type NoteProperty -Name LocationName -Value $_.locationInfo_.name -Force }
                    $CollectionList | ForEach-Object { $_ | Add-Member -Type NoteProperty -Name LocationID -Value $_.locationInfo_.locationId -Force }
                    
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)                        
                }
            }
        
        }
        elseif ($ShowNotificationStatus -and $Name) {
                            
            $Uri = (Get-COMServersUri) + "/" + $ServerID + "/notifications"
           
            try {
                [Array]$CollectionList = Invoke-HPECOMWebRequest -Method GET -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                            
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
                    
            }
                    
        }
        elseif ($ShowSecurityParametersDetails) {

            if ($server.connectionType -eq "ONEVIEW") {

                Write-Warning "'$($Name)': The iLO security settings are not supported for OneView managed servers."
                return
    
            }
            else {
                
                $Uri = (Get-COMServersUri) + "/" + $ServerID + "/security-parameters"
                
                try {
                    [Array]$CollectionList = Invoke-HPECOMWebRequest -Method GET -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                    
                }
                catch {
                    
                    Write-Error "Unable to retrieve iLO security parameters details for '$Name'. Please check the iLO event logs for more details."
                    $PSCmdlet.ThrowTerminatingError($_)
                }
                    
            }
                    
        }
        elseif ($ShowAdapterToSwitchPortMappings) {
                            
            $Uri = (Get-COMServersUri) + "/" + $ServerID + "/tor-port-mappings"
           
            try {
                [Array]$CollectionList = Invoke-HPECOMWebRequest -Method GET -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                            
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
                    
            }
                    
        }
        elseif ($ShowActivities) {

            if ($Name) {
                # Get activities for the specific server

                try {
                    "[{0}] Retrieving activities for server '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                    [Array]$CollectionList = Get-HPECOMActivity -Region $Region -SourceName $ServerSerialNumber -ShowLastMonth -Verbose:$VerbosePreference -WhatIf:$WhatIf -WarningAction SilentlyContinue
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }
            else {
                # Get activities for all servers
                try {
                    "[{0}] Retrieving activities for all servers in region '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose
                    
                    [Array]$CollectionList = Get-HPECOMActivity -Region $Region -Category 'Server' -ShowLastMonth -Verbose:$VerbosePreference -WhatIf:$WhatIf -WarningAction SilentlyContinue
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }
        }
        elseif ($ShowJobs) {

            if ($Name) {
                # Get jobs for the specific server

                try {
                    "[{0}] Retrieving jobs for server '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                    [Array]$CollectionList = Get-HPECOMJob -Region $Region -SourceName $ServerSerialNumber -ShowLastMonth -Verbose:$VerbosePreference -WhatIf:$WhatIf -WarningAction SilentlyContinue
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }
            else {
                # Get jobs for all servers
                try {
                    "[{0}] Retrieving jobs for all servers in region '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose
                    
                    [Array]$CollectionList = Get-HPECOMJob -Region $Region -Category 'Server' -ShowLastMonth -Verbose:$VerbosePreference -WhatIf:$WhatIf -WarningAction SilentlyContinue
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }
        }
        else {

            try {
                [Array]$AllCollection = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
               
            }


            if ($Null -ne $AllCollection) {     
                            
                $CollectionList = $AllCollection
        
            }

        }

        $ReturnData = @()
               
        # Format response with Repackage Object With Type
        if ($Null -ne $CollectionList) {     
            
            # Add region to object
            $CollectionList | Add-Member -type NoteProperty -name region -value $Region -Force
            
            # Add serverName and iLOname to object
            $CollectionList | ForEach-Object { 
                if ($_.name) {
                    $_ | Add-Member -type NoteProperty -name serverName -value $_.name -Force
                }
                if ($_.hardware.bmc.hostname) {
                    $_ | Add-Member -type NoteProperty -name iLOName -value $_.hardware.bmc.hostname -Force
                }

            }

            # Add iLOIPAddress to object
            $CollectionList | ForEach-Object {
                if ($_.hardware.bmc.ip) {
                    $_ | Add-Member -type NoteProperty -name iLOIPAddress -value $_.hardware.bmc.ip -Force
                }
            }

            if ($ConnectionType) {
                   
                switch ($ConnectionType) {
                    'Secure gateway' { $_ConnectionType = 'GATEWAY' }
                    'OneView managed' { $_ConnectionType = 'ONEVIEW' }
                    'Direct' { $_ConnectionType = 'DIRECT' }
                }

                $CollectionList = $CollectionList | where-Object ConnectionType -eq $_ConnectionType

                "[{0}] --------------------------- Final content of `$CollectionList - Number of items : {1} ------------------------------------------------" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($CollectionList.count) | Write-Verbose
                "[{0}] --------------------------- Final content of `$CollectionList ------------------------------------------------------------------------`n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($CollectionList | Out-String) | Write-Verbose
                "[{0}] ---------------------------------------------------------------------------------------------------------------------------------------" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                
            }
                                       
            if ($ShowAlerts) {

                # Alerts are already in the correct format from Get-HPECOMAlert
                # Just return them directly without repackaging
                $ReturnData = $CollectionList
                
            }
            elseif ($ShowActivities) {

                # Activities are already in the correct format from Get-HPECOMActivity
                # Just return them directly without repackaging
                $ReturnData = $CollectionList
                
            }
            elseif ($ShowJobs) {

                # Jobs are already in the correct format from Get-HPECOMJob
                # Just return them directly without repackaging
                $ReturnData = $CollectionList
                
            }
            elseif ($ShowServersWithRecentSupportCases -or $ShowSupportDetails) {

                #  if connectionType_ equal "OneView managed" then remove the item from $CollectionList as support details is not supported
                $CollectionList = $CollectionList | Where-Object { $_.connectionType_ -ne "OneView managed" }
                
                "[{0}] --------------------------- Final content of `$CollectionList - Number of items : {1} ------------------------------------------------" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($CollectionList.count) | Write-Verbose
                "[{0}] --------------------------- Final content of `$CollectionList ------------------------------------------------------------------------`n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($CollectionList | Out-String) | Write-Verbose
                "[{0}] ---------------------------------------------------------------------------------------------------------------------------------------" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                
                $CollectionList | ForEach-Object { $_ | Add-Member -type NoteProperty -name serialNumber -value ($_.Id -split '\+')[1] -Force }
                
                $CollectionList | ForEach-Object { $_ | Add-Member -type NoteProperty -name supportState -value $_.warranty_.supportState -Force }
                $CollectionList | ForEach-Object { $_ | Add-Member -type NoteProperty -name supportLevel -value $_.warranty_.supportLevel -Force }
                $CollectionList | ForEach-Object { $_ | Add-Member -type NoteProperty -name contractLevel -value $_.warranty_.contractLevel -Force }
                $CollectionList | ForEach-Object { $_ | Add-Member -type NoteProperty -name supportEndDate -value $_.warranty_.supportEndDate -Force }
                
                $CollectionList | ForEach-Object { $_ | Add-Member -type NoteProperty -name supportCaseCount -value $_.supportCaseCount_ -Force }

                if ($ShowServersWithRecentSupportCases) {
                    $CollectionList = $CollectionList | Where-Object { $_.supportCaseCount_ -gt 0 }
                }

                $CollectionList = $CollectionList | Sort-Object -Property serverName, serialNumber
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Servers.SupportDetails"    

            }
            elseif ($ShowSupportCases) {

                $ListofCases = $ListofCases | Sort-Object -Property caseId
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $ListofCases -ObjectName "COM.Servers.Support"    
                
            }
            elseif ($ShowExternalStorageDetails) {

                if ($Name) {
                    # Add serial number, servername, model and connectionType to object
                    $_Server = (Get-HPECOMServer -Region $Region -Name  ($CollectionList.serverId -split '\+')[1])
                    $CollectionList | Add-Member -type NoteProperty -name serverName -value $_Server.name -Force
                    $CollectionList | ForEach-Object { $_ | Add-Member -type NoteProperty -name serialNumber -value ($_.serverId -split '\+')[1] -Force}
                    $CollectionList | ForEach-Object { $_ | Add-Member -type NoteProperty -name model -value $_Server.hardware.model -Force}
                    $CollectionList | ForEach-Object { $_ | Add-Member -type NoteProperty -name connectionType -value $_Server.connectionType -Force}

                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Servers.ExternalStorageDetails"

                }
                else {

                    $NewCollectionList = [System.Collections.ArrayList]::new()

                    foreach ($Item in $CollectionList) {

                        if ($Item.connectionType -eq 'DIRECT'){

                            $Uri = (Get-COMServersUri) + "/" + $Item.ID + "/external-storage-details"
    
                            try {
                                     
                                $ServerExternalStorageDetails = Invoke-HPECOMWebRequest -Method GET -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    -ErrorAction SilentlyContinue
    
                                if ($ServerExternalStorageDetails ) {
    
                                    $_ServerExternalStorageDetails = [PSCustomObject]@{
                                        model          = $Item.hardware.model
                                        serverId       = $Item.id
                                        serverName     = $Item.name   
                                        serialNumber   = $Item.hardware.serialNumber 
                                        connectionType = $Item.connectionType
                                        volumeDetails  = $ServerExternalStorageDetails.VolumeDetails
                                        HostName       = $ServerExternalStorageDetails.HostName
                                        HostGroups     = $ServerExternalStorageDetails.HostGroups
                                        HostOS         = $ServerExternalStorageDetails.HostOS
                                        region         = $Region
                                    }
                                        
    
                                    "[{0}] _ServerExternalStorageDetails object built content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($_ServerExternalStorageDetails | Out-String) | Write-Verbose
    
                                    [void]$NewCollectionList.add($_ServerExternalStorageDetails)
    
                                    "----------------------------------------- Item added to collection:--------------------------------------------------- `n{0}" -f ($_ServerExternalStorageDetails | out-String ) | Write-Verbose
                                }
                                
                            }
                            catch {
    
                                "[{0}] Unable to retrieve external storage details for '{1}'. Error: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Item.name, $_.Exception.Message | Write-Verbose
    
                                "[{0}] External storage details not available for '{1}'. Attempting to run the external storage details collection job..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Item.name | Write-Verbose
    
                                # When a catch is triggered, it could be due to the need to run the external storage details collection job
                                try {
    
                                    $jobResponse = Invoke-HPECOMServerExternalStorage -Region $Region -ServerSerialNumber $Name 
    
                                    if ($jobResponse.State -eq "Complete") {
                                        "[{0}] External storage details collection job for '{1}' completed successfully." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Item.name | Write-Verbose
                                        
                                        # Retry to get the external storage details after the job completion
                                        [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -ErrorAction Stop
                                        
                                    }
                                    else {
                                        Write-Warning "Unable to retrieve external storage details for '$($Item.name)'. The job result code is '$($jobResponse.resultCode)'. Please verify that the Data Services Cloud Console client credentials are correctly configured in your COM instance."
                                        continue
                                    }
                                }
                                catch {
                                    Write-Warning "Unable to retrieve external storage details for '$($Item.name)'. Please verify that the Data Services Cloud Console client credentials are correctly configured in your COM instance."
                                    continue
                                }
                            }
                        }
                        else {
                            Write-Warning "External storage details are not available for server '$($Item.name)' because it is managed by HPE OneView."
                            continue
                        }

                    }

                    $NewCollectionList = $NewCollectionList | Sort-Object -Property serverName, serialNumber
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $NewCollectionList -ObjectName "COM.Servers.ExternalStorageDetails" 
                }   
            }
            elseif ($ShowNotificationStatus) {

                if ($Name) {

                    # Add serial number, servername, model and connectionType to object
                    $_Server = (Get-HPECOMServer -Region $Region -Name  ($CollectionList.serverId -split '\+')[1])
                    $CollectionList | Add-Member -type NoteProperty -name serverName -value $_Server.name -Force
                    $CollectionList | ForEach-Object { $_ | Add-Member -type NoteProperty -name serialNumber -value ($_.serverId -split '\+')[1] -Force }
                    $CollectionList | ForEach-Object { $_ | Add-Member -type NoteProperty -name model -value $_Server.hardware.model -Force }
                    $CollectionList | ForEach-Object { $_ | Add-Member -type NoteProperty -name connectionType -value $_Server.connectionType -Force }

                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Servers.NotificationStatus"

                }
                else {

                    $NewCollectionList = [System.Collections.ArrayList]::new()

                    foreach ($Item in $CollectionList) {

                        # Not using COM API 
                        # $Uri = (Get-COMServersUri) + "/" + $Item.ID + "/security-parameters"
                        # Using /ui-doorway/compute/v2/servers/<serverID>
                        $Uri = (Get-COMServersUIDoorwayUri) + "/" + $Item.ID 

                        try {
                                
                            # $_ServerSecurityParameters = Invoke-HPECOMWebRequest -Method GET -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                            $_Server = Invoke-HPECOMWebRequest -Method GET -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

                            "[{0}] Response type: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_Server.GetType().FullName | Write-Verbose

                            if ($Null -ne $_Server.notifications_ ) {

                                "[{0}] notifications_ content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($_Server.notifications_ | Out-String) | Write-Verbose

                                $_ServerNotifications = [PSCustomObject]@{
                                    model                          = $_Server.hardware.model
                                    serverId                       = $_Server.id
                                    serverName                     = $_Server.name   
                                    serialNumber                   = $_Server.hardware.serialNumber 
                                    connectionType                 = $_Server.connectionType_
                                    healthNotification             = $_Server.notifications_.healthNotification
                                    healthNotificationUsersCount   = $_Server.notifications_.healthNotificationUsersCount_
                                    criticalNotification           = $_Server.notifications_.criticalNotification
                                    criticalNotificationUsersCount = $_Server.notifications_.criticalNotificationUsersCount_
                                    criticalNonServiceNotification = $_Server.notifications_.criticalNonServiceNotification
                                    warningNotification            = $_Server.notifications_.warningNotification
                                    serverNotificationUsersCount   = $_Server.notifications_.serverNotificationUsersCount_
                                    region                         = $Region
                                }
                                    

                                "[{0}] _ServerNotifications object built content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($_ServerNotifications | Out-String) | Write-Verbose

                            }
                            else {

                                "[{0}] notifications_ content not available" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                               
                            }

                            [void]$NewCollectionList.add($_ServerNotifications)

                            "----------------------------------------- item added to collection:--------------------------------------------------- `n{0}" -f ($_ServerNotifications | out-String ) | Write-Verbose
    

                        }
                        catch {

                            $PSCmdlet.ThrowTerminatingError($_)
                        }

                    }

                    $NewCollectionList = $NewCollectionList | Sort-Object -Property serverName, serialNumber
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $NewCollectionList -ObjectName "COM.Servers.NotificationStatus"  

                }                
            }
            elseif ($ShowSecurityParameters) {

                $NewCollectionList = [System.Collections.ArrayList]::new()

                foreach ($Item in $CollectionList) {

                    # Not using COM API as there is an issue with OneView servers at the moment (Error 404 with OneView servers, case 5385212183 )
                    # $Uri = (Get-COMServersUri) + "/" + $Item.ID + "/security-parameters"
                    # So retrieved from /ui-doorway/compute/v2/servers/<serverID>
                    $Uri = (Get-COMServersUIDoorwayUri) + "/" + $Item.ID 

                    try {
                            
                        # $_ServerSecurityParameters = Invoke-HPECOMWebRequest -Method GET -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                        $_Server = Invoke-HPECOMWebRequest -Method GET -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

                        "[{0}] Response: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_Server | Write-Verbose

                        "[{0}] Response type: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_Server.GetType().FullName | Write-Verbose

                        # Due to convert response from json exception returned by this request sometimes, object generated is a PSObject with name/value that breaks the .add() later, so it needs to be converted to PSCustomObject
                        if ($Null -ne $_Server.iloSecurity_ ) {

                            "[{0}] Response detected with iloSecurity_ content" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_Server.GetType().FullName | Write-Verbose
                                                            
                            $_ServerSecurityParameters = [PSCustomObject]@{
                                iLOVersion            = $_Server.iloSecurity_.iLOVersion 
                                overallSecurityStatus = $_Server.iloSecurity_.overallSecurityStatus
                                iLOGeneration         = $_Server.iloSecurity_.iLOGeneration 
                                id                    = $_Server.iloSecurity_.id
                                IloSecurityParams     = $_Server.iloSecurity_.iloSecurityParams      
                            }
                                

                            "[{0}] iloSecurity_ content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($_ServerSecurityParameters | Out-String) | Write-Verbose

                        }
                        else {

                            "[{0}] iloSecurity_ content not available, creating object..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                            # If server is connected
                            if ($Item.state.connected -eq $True) {

                                if ($_Server.iloFirmwareVersion_ -eq "UNKNOWN") {

                                    $iLOVersion = "UNKNOWN"
                                    $iLOGeneration = "UNKNOWN"


                                }
                                else {
                                    $iLOVersion = $_Server.iloFirmwareVersion_.substring(5)
                                    $iLOGeneration = $_Server.iloFirmwareVersion_.substring(0, 4)
                                }
                               
                                $_ServerSecurityParameters = [PSCustomObject]@{
                                    iLOVersion            = $iLOVersion
                                    overallSecurityStatus = "Not available"
                                    iLOGeneration         = $iLOGeneration
                                    id                    = $Item.id
                                    IloSecurityParams     = @()
                                }

                            }
                            else {

                                $_ServerSecurityParameters = [PSCustomObject]@{
                                    iLOVersion            = $Item.iloFirmwareVersion_
                                    overallSecurityStatus = "Not available"
                                    iLOGeneration         = $Item.iloFirmwareVersion_
                                    id                    = $Item.id
                                    IloSecurityParams     = @()
                                }

                            }
                        }



                        # Add serial number, servername, model and connectionType to object
                        # $_ServerName = (Get-HPECOMServer -Region $Region -Name  ($Item.id -split '\+')[1]).name
                        # $_ServerSecurityParameters | Add-Member -type NoteProperty -name serverName -value $_ServerName 
                            
                        $_ServerSecurityParameters | Add-Member -type NoteProperty -name serverName -value $_Server.Name -Force
                        # $_ServerSecurityParameters | Add-Member -type NoteProperty -name serialNumber -value ($Item.id -split '\+')[1]
                            
                        $_ServerSecurityParameters | Add-Member -type NoteProperty -name serialNumber -value $_Server.hardware.serialNumber -Force

                        $_ServerSecurityParameters | Add-Member -type NoteProperty -name model -value $_Server.hardware.model -Force
                        $_ServerSecurityParameters | Add-Member -type NoteProperty -name connectionType -value $_Server.connectionType_ -Force


                        [void]$NewCollectionList.add($_ServerSecurityParameters)

                        "----------------------------------------- item added to collection:--------------------------------------------------- `n{0}" -f ($_ServerSecurityParameters | out-String ) | Write-Verbose

                    }
                    catch {

                        $PSCmdlet.ThrowTerminatingError($_)
                        
                    }
                }

                # "-------------- Content of final object: `n{0}" -f   ($NewCollectionList|Out-String )| Write-Verbose

                $NewCollectionList = $NewCollectionList | Sort-Object -Property serverName, serialNumber
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $NewCollectionList -ObjectName "COM.Servers.SecurityParameters"  

            }  
            elseif ($ShowHealthStatus) {

                $NewCollectionList = [System.Collections.ArrayList]::new()

                foreach ($Item in $CollectionList) {

                    "[{0}] Item: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Item | Write-Verbose

                    # Extract health data from hardware.health object
                    $healthData = [PSCustomObject]@{
                        name = $Item.name
                        serialNumber = $Item.hardware.serialNumber
                        model = $Item.hardware.model
                        connectionType = $Item.connectionType
                        healthSummary = if ($Item.hardware.health.summary) { $Item.hardware.health.summary } else { "UNKNOWN" }
                        fans = if ($Item.hardware.health.fans) { $Item.hardware.health.fans } else { "UNKNOWN" }
                        fanRedundancy = if ($Item.hardware.health.fanRedundancy) { $Item.hardware.health.fanRedundancy } else { "NOT_PRESENT" }
                        liquidCooling = if ($Item.hardware.health.liquidCooling) { $Item.hardware.health.liquidCooling } else { "UNKNOWN" }
                        liquidCoolingRedundancy = if ($Item.hardware.health.liquidCoolingRedundancy) { $Item.hardware.health.liquidCoolingRedundancy } else { "NOT_PRESENT" }
                        memory = if ($Item.hardware.health.memory) { $Item.hardware.health.memory } else { "UNKNOWN" }
                        network = if ($Item.hardware.health.network) { $Item.hardware.health.network } else { "UNKNOWN" }
                        powerSupplies = if ($Item.hardware.health.powerSupplies) { $Item.hardware.health.powerSupplies } else { "UNKNOWN" }
                        powerSupplyRedundancy = if ($Item.hardware.health.powerSupplyRedundancy) { $Item.hardware.health.powerSupplyRedundancy } else { "NOT_PRESENT" }
                        processor = if ($Item.hardware.health.processor) { $Item.hardware.health.processor } else { "UNKNOWN" }
                        storage = if ($Item.hardware.health.storage) { $Item.hardware.health.storage } else { "UNKNOWN" }
                        temperature = if ($Item.hardware.health.temperature) { $Item.hardware.health.temperature } else { "UNKNOWN" }
                        bios = if ($Item.hardware.health.bios) { $Item.hardware.health.bios } else { "UNKNOWN" }
                        smartStorage = if ($Item.hardware.health.smartStorage) { $Item.hardware.health.smartStorage } else { "UNKNOWN" }
                        healthLED = if ($Item.hardware.health.healthLED) { $Item.hardware.health.healthLED } else { "UNKNOWN" }
                    }

                    [void]$NewCollectionList.add($healthData)
                }

                $NewCollectionList = $NewCollectionList | Sort-Object -Property name, serialNumber
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $NewCollectionList -ObjectName "COM.Servers.Health"  

            }  
            elseif ($ShowSubscriptionDetails) {

                # Add required properties to object
                $CollectionList | ForEach-Object { $_ | Add-Member -type NoteProperty -name serialNumber -value $_.hardware.serialNumber -Force }
                $CollectionList | ForEach-Object { $_ | Add-Member -type NoteProperty -name model -value $_.hardware.model -Force }
                $CollectionList | ForEach-Object { $_ | Add-Member -type NoteProperty -name subscriptionState -value $_.state.subscriptionState -Force }
                $CollectionList | ForEach-Object { $_ | Add-Member -type NoteProperty -name subscriptionTier -value $_.state.subscriptionTier -Force }
                $CollectionList | ForEach-Object { $_ | Add-Member -type NoteProperty -name subscriptionKey -value $_.state.subscriptionKey -Force }
                $CollectionList | ForEach-Object { $_ | Add-Member -type NoteProperty -name subscriptionExpiresAt -value $_.state.subscriptionExpiresAt -Force }

                # Get unique subscription keys from servers
                $uniqueKeys = $CollectionList | Where-Object { $_.subscriptionKey } | Select-Object -ExpandProperty subscriptionKey -Unique

                # Build lookup hashtable for subscription available quantities
                $subscriptionLookup = @{}
                foreach ($key in $uniqueKeys) {
                    try {
                        $subscription = Get-HPEGLSubscription -SubscriptionKey $key
                        if ($subscription) {
                            $subscriptionLookup[$key] = $subscription.availableQuantity
                        }
                    }
                    catch {
                        # Silently continue if subscription not found
                    }
                }

                # Add available quantity to each server
                $CollectionList | ForEach-Object {
                    if ($_.subscriptionKey -and $subscriptionLookup.ContainsKey($_.subscriptionKey)) {
                        $_ | Add-Member -type NoteProperty -name subscriptionAvailable -value $subscriptionLookup[$_.subscriptionKey] -Force
                    }
                    else {
                        $_ | Add-Member -type NoteProperty -name subscriptionAvailable -value $null -Force
                    }
                }

                # Get location from GLP first
                try {
                    $_DeviceLocations = Get-HPECOMserver -Region $Region -ShowLocation 
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }

                # Add location member 
                $CollectionList | ForEach-Object {
                    $_SN = $_.serialNumber
                    if ($_DeviceLocations | Where-Object serialNumber -eq $_SN) {
                        $_ | Add-Member -type NoteProperty -name LocationName -value (($_DeviceLocations | Where-Object serialNumber -eq $_SN).LocationName) -Force
                        $_ | Add-Member -type NoteProperty -name LocationID -value (($_DeviceLocations | Where-Object serialNumber -eq $_SN).LocationID) -Force
                    }
                }

                # Order collectionList
                $CollectionList = $CollectionList | Sort-Object -Property name, { $_.hardware.serialnumber }
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Servers.SubscriptionDetails"
    
            }   
            elseif ($ShowSecurityParametersDetails) {
       
                $NewCollectionList = [System.Collections.ArrayList]::new()

                $_ServerName = (Get-HPECOMServer -Region $Region -Name  ($CollectionList.Id -split '\+')[1]).name

                if ($CollectionList.IloSecurityParams) {

                    foreach ($IloSecurityParam in $CollectionList.IloSecurityParams) {
                        # Add serial number and region to object
                        $IloSecurityParam | Add-Member -type NoteProperty -name serialNumber -value ($CollectionList.Id -split '\+')[1]  
                        $IloSecurityParam | Add-Member -type NoteProperty -name serverName -value $_ServerName -Force
                        $IloSecurityParam | Add-Member -type NoteProperty -name region -value $Region
                        
                        [void]$NewCollectionList.add($IloSecurityParam)
                    }
                    
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $NewCollectionList -ObjectName "COM.Servers.SecurityParameters.Details"    
                }    
                else {
                    Return
                } 
                
            }                       
            elseif ($ShowAdapterToSwitchPortMappings) {
                # Add serial number and servername to object
                $_ServerName = (Get-HPECOMServer -Region $Region -Name  ($CollectionList.serverId -split '\+')[1]).name
                $CollectionList | Add-Member -type NoteProperty -name serverName -value $_ServerName -Force
                $CollectionList | ForEach-Object { $_ | Add-Member -type NoteProperty -name serialNumber -value ($_.serverId -split '\+')[1] }        
         
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Servers.AdapterToSwitchPortMappings"    
                
            } 
            elseif ($ShowGroupMembership) {

                $NewCollectionList = [System.Collections.ArrayList]::new()

                # Get Groups with members
                $_Groups = Get-HPECOMGroup -Region $Region | Where-Object { $_.devices.count -gt 0 }

                foreach ($Item in $CollectionList) {

                    if ($_Groups) {

                        $GroupName = ($_Groups | Where-Object { $_.devices.serial -eq $Item.hardware.serialNumber }).name
                        
                        # Groups are not supported with OneView servers
                        if (-not $GroupName -and $Item.connectionType -eq "ONEVIEW") {   
                            
                            $GroupName = "UNSUPPORTED"
                            
                        }
                        elseif (-Not $GroupName) {
                            $GroupName = ""
                            # $GroupName = "No group"
                        }

                        
                        # Add group name to object
                        $Item | Add-Member -type NoteProperty -name associatedGroupname -value $GroupName
                        # Add serialnumber to object
                        $Item | Add-Member -type NoteProperty -name serialNumber -value $Item.hardware.serialNumber

                        [void]$NewCollectionList.add($Item)
                        
                    }
                }                
                
                $NewCollectionList = $NewCollectionList | Sort-Object -Property name, { $_.hardware.serialnumber }
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $NewCollectionList -ObjectName "COM.Servers.GroupMembership"    

            }       
            elseif ($ShowLocation) {
                
                $CollectionList = $CollectionList | Sort-Object -Property name, { $_.hardware.serialnumber }
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Servers.Location"    
                
            } 
            elseif ($CheckifserverHasStorageVolume) {

                $NewCollectionList = [System.Collections.ArrayList]::new()

                foreach ($Item in $CollectionList) {

                    $Uri = (Get-COMServersUri) + "/" + $Item.ID + "/analyze-os-install"
                    $Payload = @{id = $Item.ID } | ConvertTo-Json

                    try {
                        [Array]$_ServerAnalyseOSInstall = Invoke-HPECOMWebRequest -Method POST -Uri $Uri -Body $payload -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    -ErrorAction SilentlyContinue
                        
                        # if ($_ServerAnalyseOSInstall.serverHasStorageVolume) {
                        $Item | Add-Member -type NoteProperty -name serverHasStorageVolume -value $_ServerAnalyseOSInstall.serverHasStorageVolume
                        [void]$NewCollectionList.add($Item)
                        # }
                    }
                    catch [System.Net.Http.HttpRequestException] {
                        continue
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                            
                    }
                }

                $ReturnData = Invoke-RepackageObjectWithType -RawObject $NewCollectionList -ObjectName "COM.Servers.OSInstallAnalysis"    

            }
            elseif ($ShowGroupFirmwareCompliance) {

                $NewCollectionList = [System.Collections.ArrayList]::new()

                $_GroupMemberships = (Get-HPECOMServer -Region $Region -ShowGroupMembership )

                foreach ($Item in $CollectionList) {

                    "[{0}] Item: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Item | Write-Verbose

                    if ($Item.connectionType -eq 'OneView') {
                        Write-Warning "Group firmware compliance details are not available for server '$($Item.hardware.serialnumber)' because it is managed by HPE OneView."
                        continue
                    }

                    try {

                        $_GroupName = $_GroupMemberships | Where-Object { $_.hardware.serialNumber -eq $Item.hardware.serialNumber } | Select-Object -ExpandProperty associatedGroupname

                        "[{0}] `$_Groupname found: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_GroupName | Write-Verbose
                        
                        if ($_GroupName -and $_GroupName -ne "No group" -and $_GroupName -ne "Unsupported") {

                            $_Resp = Get-HPECOMGroupFirmwareCompliance -Region $Region -GroupName $_GroupName -ServerSerialNumber $Item.hardware.serialNumber
                            
                            [void]$NewCollectionList.add($_Resp)
                            
                        }
                        else {
                            "[{0}] No group found!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                        }

                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                            
                    }
                }

                $ReturnData = $NewCollectionList

            }
            elseif ($ShowGroupCompliance) {

                $NewCollectionList = [System.Collections.ArrayList]::new()

                $_GroupMemberships = (Get-HPECOMServer -Region $Region -ShowGroupMembership )

                foreach ($Item in $CollectionList) {

                    "[{0}] Item: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Item | Write-Verbose

                    if ($Item.connectionType -eq 'OneView') {
                        Write-Warning "Group compliance details are not available for server '$($Item.hardware.serialnumber)' because it is managed by HPE OneView."
                        continue
                    }

                    try {

                        $_GroupName = $_GroupMemberships | Where-Object { $_.hardware.serialNumber -eq $Item.hardware.serialNumber } | Select-Object -ExpandProperty associatedGroupname

                        "[{0}] `$_Groupname found: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_GroupName | Write-Verbose
                        
                        if ($_GroupName -and $_GroupName -ne "No group" -and $_GroupName -ne "Unsupported") {

                            $_Resp = Get-HPECOMGroup -Region $Region -Name $_GroupName -ShowCompliance
                            
                            # Add server information to the compliance data
                            $_Resp | Add-Member -type NoteProperty -name serverName -value $Item.name -Force
                            $_Resp | Add-Member -type NoteProperty -name serialNumber -value $Item.hardware.serialNumber -Force
                            
                            [void]$NewCollectionList.add($_Resp)
                            
                        }
                        else {
                            "[{0}] No group found!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                        }

                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                            
                    }
                }

                $ReturnData = Invoke-RepackageObjectWithType -RawObject $NewCollectionList -ObjectName "COM.Servers.GroupCompliance"

            }
            elseif ($ShowGroupiLOSettingsCompliance) {

                $NewCollectionList = [System.Collections.ArrayList]::new()

                $_GroupMemberships = (Get-HPECOMServer -Region $Region -ShowGroupMembership )

                foreach ($Item in $CollectionList) {

                    "[{0}] Item: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Item | Write-Verbose

                    if ($Item.connectionType -eq 'OneView') {
                        Write-Warning "Group iLO settings compliance details are not available for server '$($Item.hardware.serialnumber)' because it is managed by HPE OneView."
                        continue
                    }

                    try {

                        $_GroupName = $_GroupMemberships | Where-Object { $_.hardware.serialNumber -eq $Item.hardware.serialNumber } | Select-Object -ExpandProperty associatedGroupname

                        "[{0}] `$_Groupname found: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_GroupName | Write-Verbose
                        
                        if ($_GroupName -and $_GroupName -ne "No group" -and $_GroupName -ne "Unsupported") {

                            $_Resp = Get-HPECOMGroup -Region $Region -Name $_GroupName -ShowiLOSettingsCompliance
                            
                            # Add server information to the compliance data
                            $_Resp | Add-Member -type NoteProperty -name serverName -value $Item.name -Force
                            $_Resp | Add-Member -type NoteProperty -name serialNumber -value $Item.hardware.serialNumber -Force
                            
                            [void]$NewCollectionList.add($_Resp)
                            
                        }
                        else {
                            "[{0}] No group found!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                        }

                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                            
                    }
                }

                $ReturnData = Invoke-RepackageObjectWithType -RawObject $NewCollectionList -ObjectName "COM.Servers.GroupiLOSettingsCompliance"

            }
            elseif ($ShowGroupExternalStorageCompliance) {

                $NewCollectionList = [System.Collections.ArrayList]::new()

                $_GroupMemberships = (Get-HPECOMServer -Region $Region -ShowGroupMembership )

                foreach ($Item in $CollectionList) {

                    "[{0}] Item: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Item | Write-Verbose

                    if ($Item.connectionType -eq 'OneView') {
                        Write-Warning "Group external storage compliance details are not available for server '$($Item.hardware.serialnumber)' because it is managed by HPE OneView."
                        continue
                    }

                    try {

                        $_GroupName = $_GroupMemberships | Where-Object { $_.hardware.serialNumber -eq $Item.hardware.serialNumber } | Select-Object -ExpandProperty associatedGroupname

                        "[{0}] `$_Groupname found: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_GroupName | Write-Verbose
                        
                        if ($_GroupName -and $_GroupName -ne "No group" -and $_GroupName -ne "Unsupported") {

                            $_Resp = Get-HPECOMGroup -Region $Region -Name $_GroupName -ShowExternalStorageCompliance
                            
                            # Filter for only this server from the returned array and add group name
                            if ($_Resp) {
                                $_ServerCompliance = $_Resp | Where-Object { $_.serialNumber -eq $Item.hardware.serialNumber }
                                if ($_ServerCompliance) {
                                    $_ServerCompliance | Add-Member -type NoteProperty -name groupName -value $_GroupName -Force
                                    [void]$NewCollectionList.add($_ServerCompliance)
                                }
                            }
                            
                        }
                        else {
                            "[{0}] No group found!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                        }

                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                            
                    }
                }

                $ReturnData = Invoke-RepackageObjectWithType -RawObject $NewCollectionList -ObjectName "COM.Servers.GroupExternalStorageCompliance"

            }
            elseif ($ShowGroupFirmwareDeviation) {

                $NewCollectionList = [System.Collections.ArrayList]::new()

                $_GroupMemberships = (Get-HPECOMServer -Region $Region -ShowGroupMembership )

                foreach ($Item in $CollectionList) {

                    "[{0}] Item: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Item | Write-Verbose

                    if ($Item.connectionType -eq 'OneView') {
                        Write-Warning "Group firmware deviation details are not available for server '$($Item.hardware.serialnumber)' because it is managed by HPE OneView."
                        continue
                    }

                    try {
                        
                        $_GroupName = $_GroupMemberships | Where-Object { $_.hardware.serialNumber -eq $Item.hardware.serialNumber } | Select-Object -ExpandProperty associatedGroupname

                        "[{0}] `$_Groupname found: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_GroupName | Write-Verbose
                       
                        if ($_GroupName -and $_GroupName -ne "No group" -and $_GroupName -ne "Unsupported") {
                            
                            $_Resp = Get-HPECOMGroupFirmwareCompliance -Region $Region -GroupName $_GroupName -ServerSerialNumber $Item.hardware.serialNumber -ShowDeviations
                            
                            # # Add serial number and servername to object
                            $_Resp | Add-Member -type NoteProperty -name serialNumber -value $Item.serialNumber
                            $_Resp | Add-Member -type NoteProperty -name serverName -value $Item.ServerName 
                            
                            [void]$NewCollectionList.add($_Resp)
                            
                        }
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                            
                    }
                }

                $ReturnData = $NewCollectionList

            }
            else {

                $NewCollectionList = [System.Collections.ArrayList]::new()
                
                foreach ($Item in $CollectionList) {

                    # "[{0}] Item: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Item | Write-Verbose
                    
                    # Add serial number and part number to object
                    $Item | Add-Member -type NoteProperty -name serialNumber -value ($Item.Id -split '\+')[1] -Force
                    $Item | Add-Member -type NoteProperty -name partNumber -value $Item.hardware.productId -Force

                    # "[{0}] added SN: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Item.Id -split '\+')[1]   | Write-Verbose

                    [void]$NewCollectionList.add($Item)

                }      
               

                if ($ShowAutoiLOFirmwareUpdateStatus ) {

                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $NewCollectionList -ObjectName "COM.Servers.autoIloFwUpdateStatus"    
                    $ReturnData = $ReturnData | Sort-Object name, serialNumber 
   
                }
                elseif ($ShowGroupFirmwareDeviation) {

                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $NewCollectionList -ObjectName "COM.Groups.Firmware.Compliance.Deviations"   

                    $ReturnData = $ReturnData | Sort-Object name, { $_.hardware.serialNumber }
                } 
                elseif (-not $ShowGroupFirmwareCompliance) {

                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $NewCollectionList -ObjectName "COM.Servers"   
                    $ReturnData = $ReturnData | Sort-Object name, { $_.hardware.serialNumber }
                } 
                else {
                    $ReturnData = $NewCollectionList
                }
            }

            if (-not $WhatIf) {
                
                return $ReturnData 

            }
           
        }
        else {

            "[{0}] No content returned from the request" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            return $null

        }         
    }
}

Function Get-HPECOMServeriLOSSO {
    <#
    .DESCRIPTION
    Obtain an iLO SSO Token URL or iLO session object to authenticate to an iLO.

    The generated SSO token or session object can be used with other HPE libraries that support iLO session tokens, such as the HPEiLOCmdlets module. 
    This allows for seamless integration and interaction with iLOs, enabling tasks such as running native iLO API RedFish calls or using the HPEiLOCmdlets module for various iLO operations.

    Important note: SSO is not currently supported on servers managed by HPE OneView.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER SerialNumber
    The serial number of the server for which the iLO SSO token will be generated.

    .PARAMETER GenerateXAuthToken 
    Generates an iLO session object that can be used later to configure the iLO via native RedFish calls (compliant with the X-Auth-Token header) or via the HPEiLOCmdlets (compliant with the XAuthToken parameter of Connect-HPEiLO).

    .PARAMETER RemoteConsoleOnly
    Generates an SSO URL Token for accessing the Remote Console.

    .PARAMETER SkipCertificateValidation
    Optional parameter that can be used to skip certificate validation checks, including all validations such as expiration, revocation, trusted root authority, etc.

    [WARNING]: Using this parameter is not secure and is not recommended. This switch is only intended to be used against known hosts using a self-signed certificate for testing purposes. Use at your own risk.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    # Get server information
    $server = Get-HPECOMServer -Region $Region -Name "TWA4614528" 

    # Generate an iLO SSO Object that can then be used with the HPEiLOCmdlets module.
    $SSOObject = $server | Get-HPECOMServeriLOSSO -GenerateXAuthToken -SkipCertificateValidation

    # Get iLO SSO Token 
    $iLOSessionKey = $SSOObject."X-Auth-Token"

    # Connect to iLO using HPEiLOCmdlets module and the iLO SSO Token
    $connection = Connect-HPEiLO -Address $server.iLOIPAddress -XAuthToken $iLOSessionKey 

    # Get iLO User Information
    (Get-HPEiLOUser -Connection $connection ).userinformation

    This example shows how to generate an iLO SSO Object that can then be used with the HPEiLOCmdlets module to connect to an iLO and retrieve user information.

    .EXAMPLE
    # Get server information
    $server = Get-HPECOMServer -Region $Region -Name "TWA4614528"

    # Generate an iLO SSO Object that can then be used with the HPEiLOCmdlets module.
    $SSOObject = $server | Get-HPECOMServeriLOSSO -GenerateXAuthToken -SkipCertificateValidation

    # Get iLO SSO Token and baseURL
    $iLOSessionKey = $SSOObject."X-Auth-Token"
    $RootUri = $SSOObject.BaseURL

    # Create the headers
    $headers = @{} 
    $headers["OData-Version"] = "4.0"
    $headers["X-Auth-Token"] = $iLOSessionKey

    # iLO5 Redfish URI
    $Location = "/redfish/v1/Managers/1/SecurityService"

    # Method
    $Method = "Get"

    # Request
    try {
        $response = Invoke-WebRequest -Uri ($RootUri + $Location) -Headers $headers -Method $Method -ErrorAction Stop -SkipCertificateCheck # -SkipCertificateCheck is only supported with PowerShell 7
        $content = $response.Content | ConvertFrom-Json
        
    }
    catch {
        Write-Host "iLO $($iloHost) Patch operation failure ! Message returned: [$($_)]"
    }

    # Response
    $content
    $content.SecurityState

    This example shows how to generate an iLO SSO Object that can then be used to perform native RedFish API calls against the iLO.

    .EXAMPLE
    Get-HPECOMServeriLOSSO -Region eu-central -SerialNumber "CZ2311004H" -GenerateXAuthToken  -SkipCertificateValidation

    Generate an iLO SSO Object that can then be used with the HPEiLOCmdlets module, skipping certificate validation.
    [WARNING]: Using this parameter is not secure and is not recommended. This switch is only intended to be used against known hosts using a self-signed certificate for testing purposes. Use at your own risk.

    .EXAMPLE
    $SSOObject = Get-HPECOMServer -Region eu-central -Name ESX-Gen10P-1.lj.lab | Get-HPECOMServeriLOSSO

    Generate an iLO SSO Object for the server named 'ESX-Gen10P-1.lj.lab' located in the Central European region.

    .EXAMPLE
    $SSOObject = Get-HPECOMServer -Region eu-central -Name CZ1234567 | Get-HPECOMServeriLOSSO -GenerateXAuthToken 

    Generate an iLO SSO Object that can then be used with the HPEiLOCmdlets module.

    .EXAMPLE
    $SSOObjects = Get-HPECOMServer -Region eu-central | Get-HPECOMServeriLOSSO

    Generate iLO SSO Objects for all servers located in the Central European region.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's names.
    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer'.

    .OUTPUTS
    System.Management.Automation.PSCustomObject
        When called for a single server, returns an object with properties such as:
            - iloSsoUrl: The SSO URL for iLO login.
            - remoteConsoleUrl: The SSO URL for remote console access (when -RemoteConsoleOnly is used).
            - baseUrl, X-Auth-Token: When -GenerateXAuthToken is used, returns the iLO Redfish base URL and session token for API authentication.

    System.Object[]
        When called for multiple servers (e.g., via pipeline), returns an array of the above objects, one per server.
    #>

    [CmdletBinding(DefaultParameterSetName = 'SerialNumberGenerateXAuthToken ')]
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

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SerialNumberGenerateXAuthToken ')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SerialNumberRemoteConsoleOnly')]
        [alias('serial')]
        [String]$SerialNumber,
        
        [Parameter (ParameterSetName = 'SerialNumberGenerateXAuthToken ')]
        [Switch]$GenerateXAuthToken ,

        [Parameter (ParameterSetName = 'SerialNumberRemoteConsoleOnly')]
        [Switch]$RemoteConsoleOnly,

        [Switch]$SkipCertificateValidation,
        
        [Switch]$WhatIf
        
    ) 

    Begin {
  
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $_JobTemplateName = 'GetSSOUrl'

        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $ObjectStatusList = [System.Collections.ArrayList]::new()

        $Uri = Get-COMJobsUri

        $Timeout = 20 # in seconds 
   
    }
      
    Process {
      
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $objStatus = [pscustomobject]@{               
            associatedResource = $SerialNumber
        }

        # Add tracking object to the list of object status list
        [void]$ObjectStatusList.Add($objStatus)
       
    }

    End {
        
        "[{0}] ObjectStatusList content `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList | out-string) | Write-Verbose

        try {
            
            $Servers = Get-HPECOMServer -Region $Region
       
        }
        catch {

            $PSCmdlet.ThrowTerminatingError($_)
            
        }
         
        foreach ($Resource in $ObjectStatusList) {
            
            $Server = $Servers | Where-Object serialNumber -eq $Resource.associatedResource
            
            if (-not $Server) {
                
                Throw "Server with serial number '$($Resource.associatedResource)' not found in the region '$Region'."

            } 
            else {     
                
                $_serverId = $Server.id
                $_serverIloIpAddress = $Server.hardware.bmc.ip
                
                # Test network connectivity with iLO
                # $IsILOAccessible = (New-Object System.Net.NetworkInformation.Ping).Send($_serverIloIpAddress, 4000) 

                # Test actual iLO connectivity using RedFish API (most reliable particularly if OS proxy is set)
               try {
                   $testUri = "https://$_serverIloIpAddress/redfish/v1/"
                   
                   "[{0}] Testing connectivity with iLO '{1}' using RedFish URL '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_serverIloIpAddress, $testUri | Write-Verbose

                    if ($SkipCertificateValidation) {
                        $response = Invoke-RestMethod -Uri $testUri -Method Get -TimeoutSec 10 -SkipCertificateCheck -ErrorAction Stop
                    } 
                    else {
                        $response = Invoke-RestMethod -Uri $testUri -Method Get -TimeoutSec 10 -ErrorAction Stop
                    }
                    
                    $IsILOAccessible = $true

                }
                catch {
                    $IsILOAccessible = $false
                }

                "[{0}] Connectivity test to iLO '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_serverIloIpAddress, ($IsILOAccessible ? "Successful" : "Failed") | Write-Verbose

                # Check if server is managed by OneView
                if ($Server.connectionType -eq "ONEVIEW") {

                    Throw "iLO SSO is currently not supported on servers managed by HPE OneView."
                }
                # Check if server is connected to COM
                elseif ($server.state.connected -ne $True) {

                    Throw "The server's iLO is not connected to COM. Please connect your iLO to Compute Ops Management first."
                }
                elseif ($IsILOAccessible -eq $False) {
                    
                    throw "The server's iLO IP address '$($_serverIloIpAddress)' is not reachable. Please ensure your are connected to the iLO network."
                }


                # Build payload
                $payload = @{
                    jobTemplate = $JobTemplateId
                    resourceId   = $_serverId
                    resourceType = "compute-ops-mgmt/server"
                    jobParams = @{
                        iloTargetUrl = $_serverIloIpAddress
                    }
                }
                                

                $payload = ConvertTo-Json $payload -Depth 10 

                try {

                    "[{0}] About to run POST {1} with payload: `n{2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri, $payload | Write-Verbose
                    # Issue with new endpoints - Must use legacy one
                    $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -Method POST -body $payload -ContentType "application/json" -UseLegacyEndpoints -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                                        
                    "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

                    if (-not $Whatif) {
                        
                        "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose

                        $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout 
                        
                        "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
                        
                        $ssoResourceUri = $_resp.statusDetails.sso_resource_uri
                        
                        "[{0}] ssoResourceUri returned: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ssoResourceUri | Write-Verbose
                        
                        $ssoUrlContent = Invoke-HPECOMWebRequest -Region $Region -Uri $ssoResourceUri -Method GET -UseLegacyEndpoints
                        
                        $ssoUrl = $ssoUrlContent.sso_url

                        "[{0}] SSO URL returned: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ssoUrl | Write-Verbose
                       
                        if ($GenerateXAuthToken  -or $RemoteConsoleOnly) {
                            
                            # Make an HTTP request to the SSO URL
                            "[{0}] About to run GET with the SSO URL..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose  

                            if ($SkipCertificateValidation) {

                                "[{0}] SkipCertificateValidation parameter detected." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose  
                                
                                $response = Invoke-WebRequest -Uri $ssoUrl -Method Get -SessionVariable session -SkipCertificateCheck -ErrorAction Stop
                                                            
                            }
                            else {

                                "[{0}] SkipCertificateValidation parameter not detected." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose  
                
                                $response = Invoke-WebRequest -Uri $ssoUrl -Method Get -SessionVariable session -ErrorAction Stop
                            }

                            "[{0}] Received status code response: {1} - Description: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $response.StatusCode, $response.StatusDescription | Write-verbose           
        
                            $cookies = $null
                            if ($null -ne $session.Cookies) {
                                $cookies = $session.Cookies.GetCookies($ssoUrl)
                            }

                            # Extract cookies from the response headers if any
                            if ($cookies -and $cookies.Count -gt 0) {
                                "[{0}] Cookies content from response headers:" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                                $sessionKey = $null
                                foreach ($cookie in $cookies) {
                                    "[{0}] {1} = {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $cookie.Name, $cookie.Value | Write-Verbose

                                    # Extract the 'sessionKey' cookie value
                                    if ($cookie.Name -eq 'sessionKey') {
                                        $sessionKey = $cookie.Value
                                        "[{0}] `$sessionKey = {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $sessionKey | Write-Verbose
                                    }
                                }
                                if (-not $sessionKey) {
                                    "[{0}] SessionKey cookie not found in the response from the SSO URL. Cannot extract X-Auth-Token." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                    $sessionKey = "[Cannot be extracted. Check iLO Security log for SSO errors]"
                                }
                            }
                            else {
                                "[{0}] SessionKey cookie not found in the response from the SSO URL. Cannot extract X-Auth-Token." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                $sessionKey = "[Cannot be extracted. Check iLO Security log for SSO errors]"
                            }
        
                        }
                    
                        if ($GenerateXAuthToken ) {
                        
                            # Extract the base URL using regex
                            $baseUrl = $ssoUrl -replace "^(https://[^/]+).*", '$1'

                            "[{0}] X-Auth-Token extracted from SSO URL: {1} " -f $MyInvocation.InvocationName.ToString().ToUpper(), $baseUrl | Write-Verbose

                            # $rootUri = $baseUrl + "/rest/v1"
                            
                            $object = [PSCustomObject]@{
                                baseUrl        = $baseUrl
                                'X-Auth-Token' = $sessionKey
                            }

                            return $object

                        }
                        elseif ($RemoteConsoleOnly) {
                            
                            # Extract the IP address using regex
                            $ipAddress = $ssoUrl -replace "https://([0-9]+\.[0-9]+\.[0-9]+\.[0-9]+).*", '$1'

                            $RemoteConsoleUrl = "hplocons://addr=" + $ipAddress + "&sessionkey=" + $sessionKey
        
                            $object = [PSCustomObject]@{
                                remoteConsoleUrl = $RemoteConsoleUrl                            
                            }
                            
                            return $object

                        }
                        else {
                            
                            $object = [PSCustomObject]@{
                                iloSsoUrl = $ssoUrl                            
                            }
                            
                            return $object
                        }   
                    }                                                        
                }                    
                catch {
                    
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }
        }
    }
}

Function Enable-HPECOMServerAutoiLOFirmwareUpdate {
    <#
    .SYNOPSIS
    Enable the automatic iLO firmware update.

    .DESCRIPTION
    This Cmdlet can be used to enable the iLO automatic firmware update for a specified server in a region.    

    The iLO automatic firmware update status can be checked using 'Get-HPECOMServer -Region eu-central -ShowAutoiLOFirmwareUpdateStatus -Name <nameserver>' 
        
    .PARAMETER Region 
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where to enable the automatic iLO firmware update
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER SerialNumber
    Serial number of the server on which the iLO automatic firmware update preference will be enabled.
    
    .PARAMETER Name
    Name of the server on which the iLO automatic firmware update preference will be enabled.   

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.
  
    .EXAMPLE
    Enable-HPECOMServerAutoiLOFirmwareUpdate -Region eu-central -SerialNumber 2M240400JN 

    This command enables the automatic iLO firmware update for the server with the serial number "2M240400JN" located in the "eu-central" region. 

    .EXAMPLE 
    Enable-HPECOMServerAutoiLOFirmwareUpdate -Region us-west -Name  'HOL45' 

    This command enables the automatic iLO firmware update for the server with the name "HOL45" located in the "us-west" region.

    .EXAMPLE
    Get-HPECOMServer -Region us-west | Enable-HPECOMServerAutoiLOFirmwareUpdate 

    This command enables the automatic iLO firmware update for all servers located in the "us-west" region. 

    .EXAMPLE
    "CZ12312312", "DZ12312312" | Enable-HPECOMServerAutoiLOFirmwareUpdate -Region eu-central 

    This command enables the automatic iLO firmware update for the servers with the serial numbers "CZ12312312" and "DZ12312312" located in the "eu-central" region.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.

    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - Name of the server where to enable the automatic iLO firmware update
        * Region - Name of the region 
        * Status - Status of the modification attempt (Failed for http error return; Complete if modification is successful; Warning if no action is needed) 
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.
    
   #>

    [CmdletBinding(DefaultParameterSetName = 'SerialNumber')]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
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

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SerialNumber')]
        [String]$SerialNumber,
        
        [Parameter (Mandatory, ParameterSetName = 'Name')]
        [String]$Name,

        [Switch]$WhatIf
    ) 

    Begin {
              
        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $EnableServerAutoiLOFirmwareUpdatetatus = [System.Collections.ArrayList]::new()
        
    }
    
    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        try {

            if ($SerialNumber) {

                $ParamUsed = $SerialNumber
                $_server = Get-HPECOMServer -Region $Region -Name $SerialNumber

            } 
            elseif ($Name) {

                $ParamUsed = $Name
                $_server = Get-HPECOMServer -Region $Region -Name $Name

            }
      

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Name      = $ParamUsed
            Region    = $Region                            
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }
        
        if (-not $_server) {

            # Must return a message if not found
            if ($WhatIf) {
                
                $ErrorMessage = "Server '{0}': Resource cannot be found in the '{1}' region!" -f $ParamUsed, $Region
                Write-Warning $ErrorMessage
                return

            }
            else {

                $objStatus.Status = "Failed"
                $objStatus.Details = "Server cannot be found in the region!"
            }              

        }
        else {

            # ID uses a '+' sign, it needs to be replaced with '%2B' to avoid 404 resource not found error (URL encoding not working: $encodedServerID = [System.Web.HttpUtility]::UrlEncode($_serverId) )
            $ServerID = $_server.id.replace('+', '%2B') 
            "[{0}] Server ID found: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServerID | Write-Verbose
            
            $Uri = (Get-COMServersUri) + "?id=" + $ServerID 
            "[{0}] URI: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri | Write-Verbose

            # Build payload
            $payload = ConvertTo-Json -Depth 10 @{
                autoIloFwUpdate = $true    
            }          
          
            # Set resource
            try {
                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method PATCH -body $payload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                
                if (-not $WhatIf) {

                    "[{0}] Server auto iLO firmware enable raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose
                
                    "[{0}] Server auto iLO firmware '{1}' successfully enabled in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Region | Write-Verbose
                    
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Server auto iLO firmware successfully enabled in $Region region"

                }

            }
            catch {

                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Server auto iLO firmware cannot be enabled!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 

                }
            }           
        }

        [void] $EnableServerAutoiLOFirmwareUpdatetatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            $EnableServerAutoiLOFirmwareUpdatetatus = Invoke-RepackageObjectWithType -RawObject $EnableServerAutoiLOFirmwareUpdatetatus -ObjectName "COM.objStatus.NSDE"
            Return $EnableServerAutoiLOFirmwareUpdatetatus
        }


    }
}

Function Disable-HPECOMServerAutoiLOFirmwareUpdate {
    <#
    .SYNOPSIS
    Disable the automatic iLO firmware update.

    .DESCRIPTION
    This Cmdlet can be used to disable the iLO automatic firmware update for a specified server in a region.    

    The iLO automatic firmware update status can be checked using 'Get-HPECOMServer -Region eu-central -ShowAutoiLOFirmwareUpdateStatus -Name <nameserver>' 
        
    .PARAMETER Region 
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where to disable the automatic iLO firmware update.
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER SerialNumber
    Serial number of the server on which the iLO automatic firmware update preference will be disabled.
    
    .PARAMETER Name
    Name of the server on which the iLO automatic firmware update preference will be disabled.   

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.
  
    .EXAMPLE
    Disable-HPECOMServerAutoiLOFirmwareUpdate -Region eu-central -SerialNumber 2M240400JN 

    This command disables the automatic iLO firmware update for the server with the serial number "2M240400JN" located in the "eu-central" region. 

    .EXAMPLE
    Disable-HPECOMServerAutoiLOFirmwareUpdate -Region us-west -Name 'HOL45' 

    This command disables the automatic iLO firmware update for the server with the name "HOL45" located in the "us-west" region. 

    .EXAMPLE
    Get-HPECOMServer -Region us-west | Disable-HPECOMServerAutoiLOFirmwareUpdate

    This command disables the automatic iLO firmware update for all servers in the "us-west" region. 

    .EXAMPLE
    "CZ12312312", "DZ12312312" | Disable-HPECOMServerAutoiLOFirmwareUpdate -Region eu-central 

    This command disables the automatic iLO firmware update for the servers with the serial numbers "CZ12312312" and "DZ12312312" located in the "eu-central" region.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.

    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - Name of the server where to disable the automatic iLO firmware update
        * Region - Name of the region 
        * Status - Status of the modification attempt (Failed for http error return; Complete if modification is successful; Warning if no action is needed) 
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.
    
   #>

    [CmdletBinding(DefaultParameterSetName = 'SerialNumber')]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
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

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SerialNumber')]
        [alias('serial')]
        [String]$SerialNumber,
        
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Name')]
        [String]$Name,

        [Switch]$WhatIf
    ) 

    Begin {

        
        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
              
        $DisableServerAutoiLOFirmwareUpdatetatus = [System.Collections.ArrayList]::new()
        
    }
    
    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        try {

            if ($SerialNumber) {

                $ParamUsed = $SerialNumber
                $_server = Get-HPECOMServer -Region $Region -Name $SerialNumber

            } 
            elseif ($Name) {

                $ParamUsed = $Name
                $_server = Get-HPECOMServer -Region $Region -Name $Name

            }
      

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            Name      = $ParamUsed
            Region    = $Region                            
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }
        
        if (-not $_server) {

            # Must return a message if not found
            if ($WhatIf) {
                
                $ErrorMessage = "Server '{0}': Resource cannot be found in the '{1}' region!" -f $ParamUsed, $Region
                Write-Warning $ErrorMessage
            }
            else {

                $objStatus.Status = "Failed"
                $objStatus.Details = "Server cannot be found in the region!"
            }              

        }
        else {

            # ID uses a '+' sign, it needs to be replaced with '%2B' to avoid 404 resource not found error (URL encoding not working: $encodedServerID = [System.Web.HttpUtility]::UrlEncode($_serverId) )
            $ServerID = $_server.id.replace('+', '%2B') 
            "[{0}] Server ID found: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServerID | Write-Verbose
            
            $Uri = (Get-COMServersUri) + "?id=" + $ServerID 
            "[{0}] URI: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri | Write-Verbose

            # Build payload
            $payload = ConvertTo-Json -Depth 10 @{
                autoIloFwUpdate = $false    
            }          
          
            # Set resource
            try {
                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method PATCH -body $payload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                
                if (-not $WhatIf) {
                    
                    "[{0}] Server auto iLO firmware disable raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose

                    "[{0}] Server auto iLO firmware '{1}' successfully disabled in '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $name, $Region | Write-Verbose
                    
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Server auto iLO firmware successfully disabled in $Region region"

                }

            }
            catch {

                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Server auto iLO firmware cannot be disabled!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 

                }
            }           
        }

        [void] $DisableServerAutoiLOFirmwareUpdatetatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            $DisableServerAutoiLOFirmwareUpdatetatus = Invoke-RepackageObjectWithType -RawObject $DisableServerAutoiLOFirmwareUpdatetatus -ObjectName "COM.objStatus.NSDE"
            Return $DisableServerAutoiLOFirmwareUpdatetatus
        }
    }
}

Function Get-HPECOMServerActivationKey {
    <#
    .SYNOPSIS
    Retrieve server activation keys.

    .DESCRIPTION   
    This Cmdlet returns a collection of activation keys for adding servers to a Compute Ops Management service instance. The keys will be removed from the collection on expiry.
    
    .PARAMETER Region 
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the server will be added.  
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Type
    Specifies the type of activation key to retrieve. The valid values are:
    - 'Secure Gateway': Retrieves activation keys associated with a secure gateway.
    - 'Direct': Retrieves activation keys for direct connections to Compute Ops Management without using a secure gateway.
    If this parameter is not specified, all available activation keys will be returned.

    .PARAMETER WhatIf
    Displays the raw REST API call that would be made to COM instead of sending the request. Useful for understanding the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMServerActivationKey -Region eu-central

    This command retrieves the activation keys required to add servers to a Compute Ops Management service instance in the "eu-central" region.
        
    #>

    [CmdletBinding()]
    Param( 
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
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

        [ValidateSet('Secure Gateway', 'Direct')]
        [String]$Type,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $Uri = Get-COMActivationKeysUri

        if ($Type -eq "Secure Gateway") {
            $Uri = "$($Uri)?filter=applianceUri ne null"
        }
        elseif ($Type -eq "Direct") {
            $Uri = "$($Uri)?filter=applianceUri eq null"
        }
       
        try {
            [Array]$Collection = Invoke-HPECOMWebRequest -Method GET -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference


        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
               
        }     

        if ($Collection) {

            # Add region to objects
            $Collection | ForEach-Object { $_ | Add-Member -type NoteProperty -name region -value $Region }

            $ReturnData = Invoke-RepackageObjectWithType -RawObject $Collection -ObjectName "COM.Servers.ActivationKeys"   
            $ReturnData = $ReturnData | Sort-Object activationKey

            return $ReturnData
        }
        else {
            return
        }

    }   
}

Function Get-HPECOMServerLogs {
    <#
    .SYNOPSIS
    Collects and downloads server logs in zip format.

    .DESCRIPTION   
    This cmdlet submits a job to collect server logs (AHS logs) for a specified server in a Compute Ops Management service instance.
    Once the logs are collected, a download URL is provided which can be used to download the logs in zip format.
    The log collection process may take some time (up to 2-4 minutes) as it gathers diagnostic information from the server.
    
    Optionally, you can use the -Path parameter to automatically download the logs to a specified directory.
    
    TIMEOUT HANDLING:
    If the job does not complete within the specified timeout period, the cmdlet returns a status of "Timeout" along with the job URI.
    You can then use one of the following methods to retrieve the logs once the job completes:
    
    1. Continue waiting for the job:
       Wait-HPECOMJobComplete -Region <region> -Job <JobUri>
    
    2. Check the job status:
       $Job = Get-HPECOMJob -Region <region> -JobResourceUri <JobUri>
    
    3. Once the job completes (state = "COMPLETE"), retrieve the download URL:
       $ServerID =  $Job.resource.id
       $response = Invoke-HPECOMWebRequest -Region <region> -Uri "/compute-ops-mgmt/v1/servers/$ServerID/download-logs" -Method GET
       $logsUrl = $response.downloadUrl

    4. Download the logs using the URL:
       Invoke-WebRequest -Uri $logsUrl -OutFile "C:\Path\To\DownloadedLogs.zip"
    
    .PARAMETER Region 
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).  
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name
    Specifies the server name or serial number for which to collect and download logs.
    This parameter accepts pipeline input and can be used with Get-HPECOMServer.

    .PARAMETER Path
    Optional parameter that specifies the local path where the logs should be downloaded.
    If not specified, only the logs URL will be returned without downloading.
    The filename will be automatically generated as "server-logs-<servername>-<timestamp>.zip".

    .PARAMETER DownloadAHSLogs
    Optional switch parameter to download the AHS (Active Health System) logs in addition to the standard server logs. 
    AHS logs contain comprehensive diagnostic data that HPE support typically requests when troubleshooting hardware issues or analyzing support cases. These logs provide detailed hardware health and performance information.
    By default, only standard server logs are collected. Use this switch when HPE support specifically requests AHS logs for case analysis.

    .PARAMETER Timeout
    Timeout in seconds before the cmdlet stops waiting for job completion. Default is 240 seconds (4 minutes).
    This parameter is ignored when using -Async.

    .PARAMETER Async
    Optional switch to submit the job and return immediately without waiting for completion.
    Returns the job resource URI in the output, which can be monitored using Wait-HPECOMJobComplete or Get-HPECOMJob.
    When using -Async, the download URL will not be available in the initial response.

    .PARAMETER WhatIf
    Displays the raw REST API call that would be made to COM instead of sending the request. 
    Useful for understanding the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMServerLogs -Region eu-central -Name "ESX-1.domain.lab"

    Submits a job to collect logs for the server named "ESX-1.domain.lab" in the "eu-central" region and returns a download URL once collection is complete.

    .EXAMPLE
    $logsUrl = Get-HPECOMServerLogs -Region us-west -Name "2M240400JN"

    Collects logs from server with serial number "2M240400JN" and stores the download URL in the $logsUrl variable.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name "ESX-1" | Get-HPECOMServerLogs -Path "C:\Logs"

    Collects and downloads server logs for "ESX-1" to the C:\Logs directory using pipeline input.

    .EXAMPLE
    Get-HPECOMServer -Region us-west -PowerState ON | Get-HPECOMServerLogs 

    Collects logs from all powered-on servers in the US West region and returns download URLs for each.

    .EXAMPLE
    Get-HPECOMServerLogs -Region eu-central -Name "ESX-1.domain.lab" -DownloadAHSLogs

    Collects server logs and AHS logs for the specified server.

    .EXAMPLE
    Get-HPECOMServerLogs -Region eu-central -Name "ESX-1.domain.lab" -Async

    Submits log collection job and returns immediately without waiting. Use the returned JobUri with Wait-HPECOMJobComplete to monitor progress.

    .EXAMPLE
    Get-HPECOMServerLogs -Region eu-central -Name "ESX-1.domain.lab" -Timeout 600

    Collects logs with a custom timeout of 10 minutes (600 seconds) instead of the default 4 minutes.

    .EXAMPLE
    # Handle timeout scenario - retrieve logs after job completes
    $result = Get-HPECOMServerLogs -Region eu-central -Name "ESX-1.domain.lab"
    if ($result.Status -eq "Timeout") {
        # Wait for job to complete
        Wait-HPECOMJobComplete -Region eu-central -Job $result.JobUri
        
        # Get server ID from the result
        $server = Get-HPECOMServer -Region eu-central -Name $result.ServerName
        
        # Retrieve download URL
        $downloadInfo = Invoke-HPECOMWebRequest -Region eu-central -Uri "/compute-ops-mgmt/v1/servers/$($server.id)/download-logs" -Method GET
        
        Write-Host "Download URL: $($downloadInfo.downloadUrl)"
    }

    .INPUTS
    System.String
        A server name or serial number.
    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer'.

    .OUTPUTS
    System.Management.Automation.PSCustomObject
        Returns an object with the following properties:
        - ServerName: Name of the server
        - SerialNumber: Serial number of the server
        - Region: Region code
        - JobUri: Job resource URI (available when using -Async or on timeout)
        - LogsUrl: Download URL for the collected logs (null when using -Async)
        - DownloadPath: Local path where logs were downloaded (if -Path was specified)
        - Status: Status of the operation (Running, Complete, Failed, Timeout)
        - Details: Additional details about the operation
    
    #>

    [CmdletBinding()]
    Param( 
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
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

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [String]$Name,

        [String]$Path,

        [Switch]$DownloadAHSLogs,

        [Parameter()]
        [int]$Timeout = 240,

        [Switch]$Async,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        # Get job template for CollectServerLogs
        $_JobTemplateName = 'CollectServerLogs'
        $JobTemplateUri = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object resourceUri
        
        "[{0}] Job template '{1}' URI: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_JobTemplateName, $JobTemplateUri | Write-Verbose

        $ServerLogsList = [System.Collections.ArrayList]::new()

        $JobsUri = Get-COMJobsUri

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Pre-validation: Get server information
        try {
            "[{0}] Retrieving server information for '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
            
            $Server = Get-HPECOMServer -Region $Region -Name $Name -Verbose:$false
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        # Validation: Check if server exists
        if (-not $Server) {
            "[{0}] Server '{1}' not found in region '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Region | Write-Verbose
            
            if ($WhatIf) {
                $ErrorMessage = "Server '{0}' not found in region '{1}'. Cannot display API request." -f $Name, $Region
                Write-Warning $ErrorMessage
                return
            }
            else {
                # For Get-* cmdlets, return nothing silently for "not found"
                return
            }
        }

        "[{0}] Server ID: '{1}', Serial Number: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Server.id, $Server.hardware.serialNumber | Write-Verbose

        # Build object for status tracking
        $objStatus = [pscustomobject]@{
            ServerName   = $Server.name
            SerialNumber = $Server.hardware.serialNumber
            Region       = $Region
            JobUri       = $null
            LogsUrl      = $null
            DownloadPath = $null
            Status       = $null
            Details      = $null
        }

        # Extract Job Template ID from URI
        $ServerID = $Server.id
        $JobTemplateId = $JobTemplateUri -replace '.*/([^/]+)$', '$1'

        "[{0}] Server ID: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServerID | Write-Verbose
        "[{0}] Job Template ID: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $JobTemplateId | Write-Verbose

        # Build job payload
        if ($DownloadAHSLogs) {

            $payload = @{
                jobTemplate  = $JobTemplateId
                resourceId   = $ServerID
                resourceType = "compute-ops-mgmt/server"
                jobParams    = @{
                    collect_ahs_log = $true
                }
            }
        }
        else {
            $payload = @{
                jobTemplate  = $JobTemplateId
                resourceId   = $ServerID
                resourceType = "compute-ops-mgmt/server"
            }
        }

        $payload = ConvertTo-Json $payload -Depth 10

        "[{0}] Job payload: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $payload | Write-Verbose

        try {
            # Submit the job to collect server logs
            "[{0}] Submitting job to collect logs for server '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Server.name | Write-Verbose
            
            $JobResponse = Invoke-HPECOMWebRequest -Method POST -Uri $JobsUri -Body $payload -ContentType "application/json" -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

            if (-not $WhatIf) {
                
                "[{0}] Job submitted, response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($JobResponse | Out-String) | Write-Verbose

                # If Async, return immediately with job URI
                if ($Async) {
                    "[{0}] Async mode: Returning job URI without waiting" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    
                    $objStatus.JobUri = $JobResponse.resourceUri
                    $objStatus.Status = "Running"
                    $objStatus.Details = "Job submitted successfully. Use Wait-HPECOMJobComplete or Get-HPECOMJob to monitor progress and retrieve logs URL when complete."
                }
                else {
                    # Wait for job to complete
                    "[{0}] Waiting for job to complete (timeout: {1} seconds)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Timeout | Write-Verbose
                    
                    try {
                        $JobResult = Wait-HPECOMJobComplete -Region $Region -Job $JobResponse.resourceUri -Timeout $Timeout

                        "[{0}] Job completed with state: {1}, resultCode: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $JobResult.State, $JobResult.resultCode | Write-Verbose

                # Check if job completed successfully
                if ($JobResult.State -eq "Complete" -and $JobResult.resultCode -eq "SUCCESS") {
                    
                    # Get the download URL by calling the download-logs endpoint
                    $DownloadLogsUri = "/compute-ops-mgmt/v1/servers/$ServerID/download-logs"
                    
                    "[{0}] Retrieving download URL from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DownloadLogsUri | Write-Verbose
                    
                    try {
                        $DownloadResponse = Invoke-HPECOMWebRequest -Method GET -Uri $DownloadLogsUri -Region $Region -Verbose:$VerbosePreference
                        
                        "[{0}] Download response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($DownloadResponse | ConvertTo-Json -Depth 5) | Write-Verbose
                        
                        $LogsUrl = $DownloadResponse.downloadUrl
                        
                        if ($LogsUrl) {
                            "[{0}] Download URL received: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $LogsUrl | Write-Verbose
                            
                            $objStatus.LogsUrl = $LogsUrl
                            $objStatus.Status = "Complete"
                            $objStatus.Details = "Server logs collected successfully"

                            # Download the file if Path parameter was provided
                            if ($Path) {
                                try {
                                    # Create directory if it doesn't exist
                                    if (-not (Test-Path -Path $Path)) {
                                        "[{0}] Creating directory: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Path | Write-Verbose
                                        New-Item -ItemType Directory -Path $Path -Force | Out-Null
                                    }

                                    # Generate filename with timestamp
                                    $timestamp = Get-Date -Format "yyyyMMdd-HHmmss"
                                    $filename = "server-logs-{0}-{1}.zip" -f $Server.name, $timestamp
                                    $fullPath = Join-Path -Path $Path -ChildPath $filename

                                    "[{0}] Downloading logs to: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $fullPath | Write-Verbose

                                    # Download the file
                                    Invoke-WebRequest -Uri $LogsUrl -OutFile $fullPath -ErrorAction Stop

                                    "[{0}] Download completed successfully" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                                    $objStatus.DownloadPath = $fullPath
                                    $objStatus.Details = "Logs downloaded successfully to $fullPath"

                                }
                                catch {
                                    "[{0}] Download failed: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                                    
                                    $objStatus.Status = "Failed"
                                    $objStatus.Details = if ($_.Exception.Message) { "Logs collected but download failed: $($_.Exception.Message)" } else { "Logs collected but download failed!" }
                                }
                            }
                        }
                        else {
                            "[{0}] No download URL in response" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            
                            $objStatus.Status = "Failed"
                            $objStatus.Details = "Job completed but no download URL was returned from the download-logs endpoint"
                        }
                    }
                    catch {
                        "[{0}] Failed to retrieve download URL: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                        
                        $objStatus.Status = "Failed"
                        $objStatus.Details = if ($_.Exception.Message) { "Job completed but failed to retrieve download URL: $($_.Exception.Message)" } else { "Job completed but failed to retrieve download URL!" }
                    }
                }
                else {
                    "[{0}] Job failed with state: {1}, resultCode: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $JobResult.State, $JobResult.resultCode | Write-Verbose
                    
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($JobResult.Status) { "Job failed: $($JobResult.Status)" } else { "Job did not complete successfully. State: $($JobResult.State), ResultCode: $($JobResult.resultCode)" }
                }
            }
            catch {
                # Handle timeout gracefully
                if ($_.Exception.Message -match "Timeout") {
                    "[{0}] Job timed out after {1} seconds" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Timeout | Write-Verbose
                    
                    $objStatus.JobUri = $JobResponse.resourceUri
                    $objStatus.Status = "Timeout"
                    $objStatus.Details = "Job timed out after $Timeout seconds. Job is still running. See warning message for instructions on retrieving logs."
                    
                    # Display warning with instructions on how to retrieve logs
                    $TimeoutWarning = @"

Log collection job for server '$($Server.name)' timed out after $Timeout seconds, but the job is still running in the background.

TO RETRIEVE LOGS AFTER JOB COMPLETES:

1. Wait for the job to complete:
   Wait-HPECOMJobComplete -Region $Region -Job '$($JobResponse.resourceUri)'

2. Check job status:
   Get-HPECOMJob -Region $Region -JobResourceUri '$($JobResponse.resourceUri)'

3. Once job completes (state = 'COMPLETE'), retrieve the download URL:
   `$downloadInfo = Invoke-HPECOMWebRequest -Region $Region -Uri '/compute-ops-mgmt/v1/servers/$ServerID/download-logs' -Method GET
   `$downloadUrl = `$downloadInfo.downloadUrl

4. Download the logs using the URL:
   Invoke-WebRequest -Uri `$downloadUrl -OutFile "C:\Path\To\DownloadedLogs.zip"

TIP: You can increase the timeout using -Timeout parameter (e.g., -Timeout 600 for 10 minutes)
"@
                    Write-Warning $TimeoutWarning
                }
                else {
                    # Re-throw other errors
                    throw
                }
            }
                }
            }

        }
        catch {
            if (-not $WhatIf) {
                "[{0}] Error collecting logs: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Failed to collect server logs!" }
            }
        }

        [void]$ServerLogsList.Add($objStatus)

    }

    End {

        if (-not $WhatIf -and $ServerLogsList.Count -gt 0) {
            $ServerLogsList = Invoke-RepackageObjectWithType -RawObject $ServerLogsList -ObjectName "COM.Servers.Logs"
            Return $ServerLogsList
        }

    }   
}

Function New-HPECOMServerActivationKey {
    <#
    .SYNOPSIS
    Generate a activation key required to connect servers to a Compute Ops Management service instance.
    
    .DESCRIPTION   
    This cmdlet generates an activation key necessary for connecting servers to a Compute Ops Management service instance using the 'Connect-HPEGLDeviceComputeiLOtoCOM -ActivationKey' command.

    The activation key is valid for a duration specified by the ExpirationInHours parameter.

    Note that a maximum of 10 server activation keys per user per region is allowed. The generated activation key will consist of 9 alphanumeric characters.

    Note that iLO must be updated to the following minimum versions prior to support activation keys:
    - iLO 5: v3.09 or later
    - iLO 6: v1.64 or later
    
    .PARAMETER Region 
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the server will be added.  
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER SecureGateway
    Specifies the name of the Compute Ops Management secure gateway to use for the activation key. The name can be retrieved using 'Get-HPECOMAppliance'.
    When this parameter is used, servers connect to Compute Ops Management through the secure gateway present in the network infrastructure, rather than directly.

    .PARAMETER SubscriptionKey
    Optional parameter that specifies a new or an existing device subscription key to assign to the server. 
    This parameter is not required if the automatic subscription status of Compute device is enabled (see Get-HPEGLDeviceAutoSubscription and Set-HPEGLDeviceAutoSubscription).
    An existing key can be retrieved using 'Get-HPEGLSubscription -ShowWithAvailableQuantity -ShowValid -FilterBySubscriptionType Server'.

    .PARAMETER ExpirationInHours
    Specifies the expiration time of the activation key in hours. The default value is 1 hour. The valid range is from 0.5 hours (30 minutes) to 168 hours (7 days).

    .PARAMETER WhatIf
    Displays the raw REST API call that would be made to COM instead of sending the request. Useful for understanding the native REST API calls used by COM.

    .EXAMPLE
    $Activation_Key = New-HPECOMServerActivationKey -Region eu-central -ExpirationInHours 2

    This command generates an activation key required to add servers to a Compute Ops Management service instance in the "eu-central" region. 
    The activation key will expire in 2 hours and can then be used with 'Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLO_credential -IloIP $iLO_IP -ActivationKeyfromCOM $Activation_Key'. 
    This command requires that the automatic subscription status of the Compute device is enabled and that a valid subscription key with available quantity is available, as no subscription key was provided.

    .EXAMPLE
    $Activation_Key = New-HPECOMServerActivationKey -Region eu-central -SubscriptionKey "123456789" -ExpirationInHours 24

    This command generates an activation key required to add servers to a Compute Ops Management service instance in the "eu-central" region using the new subscription key "123456789" that will be added to the workspace.
    The activation key will expire in 24 hours and can then be used with 'Connect-HPEGLDeviceComputeiLOtoCOM'.

    .EXAMPLE
    $Subscription_Key = Get-HPEGLSubscription -ShowWithAvailableQuantity -ShowValid -FilterBySubscriptionType Server | select -First 1 -ExpandProperty key
        
    $Activation_Key = New-HPECOMServerActivationKey -Region eu-central -SubscriptionKey $Subscription_Key 
   
    The first command retrieves the first available server subscription key that is valid and with available quantity.
    The second command retrieves the activation key required to add servers to a Compute Ops Management service instance in the "eu-central" region using the subscription key retrieved in the first command.
    The activation key will expire in 1 hour and can then be used with 'Connect-HPEGLDeviceComputeiLOtoCOM'
    
    .EXAMPLE
    $Activation_Key = New-HPECOMServerActivationKey -Region eu-central -ExpirationInHours 2 -SecureGateway "sg01.domain.lab"
    
    This command generates an activation key required to add servers to a Compute Ops Management service instance in the "eu-central" region using the secure gateway "sg01.domain.labm". 
    The activation key will expire in 2 hours and can then be used with 'Connect-HPEGLDeviceComputeiLOtoCOM'.
    
    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Type SecureGateway -Name sg01.domain.lab | New-HPECOMServerActivationKey

    This command retrieves the secure gateway "sg01.domain.lab" and generates an activation key required to add servers via secure gateway to a Compute Ops Management service instance in the "eu-central" region.
    The activation key will expire in 1 hour and can then be used with 'Connect-HPEGLDeviceComputeiLOtoCOM'.

    .INPUTS
    HPEGreenLake.COM.Appliances
        A Secure Gateway object from 'Get-HPECOMAppliance -Region $Region -Type SecureGateway'.

    .OUTPUTS
    System.String
        A string object representing the activation key generated for adding servers to a Compute Ops Management service instance.
    
    #>

    [CmdletBinding()]
    Param( 
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
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

        [Parameter (ValueFromPipelineByPropertyName, ValueFromPipeline)] 
        [alias('name')]
        [object]$SecureGateway,

        [String]$SubscriptionKey,

        [ValidateScript({
                if ($_ -ge 0.5 -and $_ -le 168) {
                    $true
                }
                else {
                    Throw "ExpirationInHours must be between 0.5 and 168."
                }
            })]
        [Double]$ExpirationInHours = 1,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        if (-not $SubscriptionKey) {

            $SubscriptionKey = ""
        }

        if ($SecureGateway) {

            try {
                # Check $SecureGateway object type 
                if ($SecureGateway -is [string]) {
                    "[{0}] SecureGateway parameter is a string" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    $SecureGatewayResource = Get-HPECOMAppliance -Region $Region -Type SecureGateway -Name $SecureGateway
                    $SecureGatewayResourceUri = $SecureGatewayResource.resourceUri 
                    $SecureGatewayName = $SecureGatewayResource.name
                }
                else {
                    "[{0}] SecureGateway parameter is a PSCustomObject." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    $SecureGatewayResourceUri = $SecureGateway.resourceUri                     
                    "[{0}] Secure Gateway URI: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SecureGatewayResourceUri | Write-Verbose
                    $SecureGatewayName = $SecureGateway.name
                    "[{0}] Secure Gateway name: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SecureGatewayName | Write-Verbose
                }
           
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }

            If (-not $SecureGatewayResourceUri) {

                # Must return a message if secure gateway not found
                "[{0}] Secure Gateway '{1}' cannot be found in the Compute Ops Management instance" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SecureGatewayName | Write-Verbose
    
                $ErrorMessage = "Secure Gateway '{0}' cannot be found in the Compute Ops Management instance!" -f $SecureGatewayName
                Write-warning $ErrorMessage
                return               
            }
            else {
        
                $Uri = Get-COMActivationKeysUri

                $body = @{
                    expirationInHours   = $ExpirationInHours
                    subscriptionKey     = $SubscriptionKey   
                    applianceUri        = $SecureGatewayResourceUri      
                    targetDevice     = 'ILO'
                } | ConvertTo-Json
        
            }
        }
        else {

            $Uri = Get-COMActivationKeysUri

            $body = @{
                expirationInHours = $ExpirationInHours
                subscriptionKey   = $SubscriptionKey       
                targetDevice      = 'ILO'  
            } | ConvertTo-Json

        }

       
        try {
            [Array]$Collection = Invoke-HPECOMWebRequest -Method POST -Uri $Uri -Region $Region -Body $body -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

            $ReturnData = $Collection.activationKey     
            return $ReturnData

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
               
        }     

    }   
}

Function Remove-HPECOMServerActivationKey {
    <#
    .SYNOPSIS
    Delete an activation key.
    
    .DESCRIPTION   
    This cmdlet deletes a generated activation key necessary for connecting servers to a Compute Ops Management service instance.

    
    .PARAMETER Region 
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the server will be added.  
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER ActivationKey
    Specifies the activation key to be deleted from the Compute Ops Management service instance. The key can be retrieved using 'Get-HPECOMServerActivationKey'.
   
    .PARAMETER WhatIf
    Displays the raw REST API call that would be made to COM instead of sending the request. Useful for understanding the native REST API calls used by COM.

    .EXAMPLE
    Remove-HPECOMServerActivationKey -Region eu-central -ActivationKey 123456789    

    .EXAMPLE
    Get-HPECOMServerActivationKey -Region eu-central | Remove-HPECOMServerActivationKey 

    This command deletes all activation keys for the Compute Ops Management service instance in the "eu-central" region.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the activation keys.
    System.Collections.ArrayList
        List of keys retrieved using 'Get-HPECOMServerActivationKey'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * ActivationKey - Name of the activation key to be removed from the region
        * Region - Name of the region 
        * Status - The status of the removal attempt (Failed for http error return; Complete if removal is successful; Warning if no action is needed) 
        * Details - Additional information about the status.
        * Exception: Information about any exceptions generated during the operation.

       
    #>

    [CmdletBinding()]
    Param( 
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
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

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [String]$ActivationKey,
            
        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $RemoveKeyStatus = [System.Collections.ArrayList]::new()


    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        
        # Build object for the output
        $objStatus = [pscustomobject]@{
            ActivationKey = $ActivationKey
            Region        = $Region   
            Status        = $Null
            Details       = $Null
            Exception     = $Null
        }


        try {
    
            $_ActivationKey = Get-HPECOMServerActivationKey -Region $Region | Where-Object activationKey -eq $ActivationKey
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }
        

        if (-not $_ActivationKey) {
                
            "[{0}] Activation key '{1}' cannot be found in the '{2}' region!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ActivationKey, $Region | Write-Verbose

            if ($WhatIf) {

                $ErrorMessage = "Activation key '{0}': Resource cannot be found in the '{1}' region!" -f $ActivationKey, $Region
                Write-warning $ErrorMessage
                return
            
            }
            else {
                $objStatus.Status = "Failed"
                $objStatus.Details = "Activation key cannot be found in the region!"
              
            }

        }
        else {   

            $Uri = (Get-COMActivationKeysUri) + '/' + $_ActivationKey.activationKey

            try {
                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method DELETE -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                        
                if (-not $WhatIf) {

                    "[{0}] Remove activation key call response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose
                    
                    "[{0}] Activation key '{1}' successfully removed from '{2}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ActivationKey, $Region | Write-Verbose
                        
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Activation key successfully removed from $Region region"
    
                }
    
            }
            catch {
    
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Activation key cannot be removed from $Region region!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData 
    
                }
            }   
            
        }

        [void] $RemoveKeyStatus.add($objStatus)

    }   
    end {

        if (-not $WhatIf) {
            
            $RemoveKeyStatus = Invoke-RepackageObjectWithType -RawObject $RemoveKeyStatus -ObjectName "COM.Servers.ActivationKeys.ASDE"
            Return $RemoveKeyStatus
        }
    }
}

Function Get-HPECOMEmailNotificationPolicy {
    <#
    .SYNOPSIS
    Get the email notification policy preference that is applied when servers are activated for management.

    .DESCRIPTION
    This Cmdlet returns the user preferences for the current user that are available in the specified region.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER SerialNumber
    Specifies the serial number of the server on which the email notification preferences will be retrieved.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMUserPreference -Region us-west

    Return the user preferences for the current user. 

    .EXAMPLE
    Get-HPECOMUserPreference -Region  eu-central -SerialNumber CZ12312312 


    .INPUTS
    None. You cannot pipe objects to this Cmdlet.

    
    
   #>
    [CmdletBinding()]
    Param( 

        [Parameter (Mandatory)] 
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

        [String]$SerialNumber,


        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
    
    }

    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        if ($SerialNumber) {
            
            try {

                $_server = Get-HPECOMServer -Region $Region -Name $SerialNumber

            }
            catch {
                
                $PSCmdlet.ThrowTerminatingError($_)
            }
            
            if (-not $_server) {

                Return

            }
            else {
                
                $_serverId = $_server.id

                "[{0}] Server ID found: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_serverId | Write-Verbose

                $Uri = (Get-COMServersUri) + "/" + $_serverId + "/notifications"  
                
            }

        }
        else {
            
            $Uri = Get-COMUserPreferencesUri            
        }


        try {
            [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    -ErrorAction Stop
    
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
                   
        }           
        

        $ReturnData = @()
       
        if ($Null -ne $CollectionList) {   

            # Add region to object
            $CollectionList | Add-Member -type NoteProperty -name region -value $Region

            if ($SerialNumber) {
                
                $CollectionList | Add-Member -type NoteProperty -name serialNumber -value $SerialNumber
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Servers.NotificationStatus"    


            }
            else {

                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.User.Preferences"    
            }

    
            # $ReturnData = $ReturnData #| Sort-Object { $_.updatedAt }
        
            return $ReturnData 
                
        }
        else {

            Write-Warning "Looks like email notification policy preference has not been configured. See Enable-HPECOMEmailNotificationPolicy"
            return
                
        }     

    
    }
}

Function Enable-HPECOMEmailNotificationPolicy {
    <#
    .SYNOPSIS
    Enable a service instance email notification policy in a region.

    .DESCRIPTION   
    Compute Ops Management supports email notification policies that users can enable for each service instance. When enabled, the email notification policy preference settings are applied when a server is assigned to a service instance.

    HPE GreenLake user account holders can configure an email notification policy for each service instance in a workspace. Notifications are sent to the email address that is associated with the user account that is used to configure the policy.
        
    Note: If a server you configure for automatic support case creation or integration with ServiceNow experiences a supported service event, the support case ID or ServiceNow incident ID is included in the server notification.   
    
    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the email notification preferences will be enabled.
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER ServerSerialNumber
    Specifies the serial number of the server on which the email notification preferences will be enabled.
    
    Note: Changing the email notification preferences at the individual server level does not reapply the service instance email notification policy.

    Note: Servers managed by HPE OneView are not supported.
        
    .PARAMETER ServiceEventIssues 
    Enables notifications for service events. A service event is a failure requiring an HPE support case and possibly a service repair.
    
    .PARAMETER ServiceEventAndCriticalIssues
    Enables notifications for service events and other critical severity events.

    .PARAMETER ServiceEventAndCriticalAndWarningIssues
    Enables notifications for service events and events of critical or warning severity.

    .PARAMETER DailySummary
    Enables a daily email summarizing the health of all servers configured for daily notifications. This email includes a summary of server health status values and potential actions such as activating or connecting servers, resolving subscription issues, and available firmware updates.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.
   
    .EXAMPLE
    Enable-HPECOMEmailNotificationPolicy -Region eu-central -ServiceEventIssues -DailySummary

    Subscribe the user account, used with 'Connect-HPEGL', to server notifications (service event issues) and daily summary notifications.
    
    .EXAMPLE
    Enable-HPECOMEmailNotificationPolicy -Region eu-central -ServiceEventAndCriticalIssues

    Subscribe the user account, used with 'Connect-HPEGL', to server notifications for service events and critical issues, without daily summary notifications.

    .EXAMPLE
    Enable-HPECOMEmailNotificationPolicy -Region eu-central -ServerSerialNumber CZ12312312 -ServiceEventAndCriticalAndWarningIssues 

    Subscribe the user account, used with 'Connect-HPEGL', to server notifications for service events and critical issues for the server with serial number 'CZ12312312'.    

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name 'ESX-2.lab' | Enable-HPECOMEmailNotificationPolicy -ServiceEventAndCriticalIssues

    Subscribe the user account, used with 'Connect-HPEGL', to server notifications for service events and critical issues for the server with the name 'ESX-2.lab'.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -ConnectedState True -Model "ProLiant DL360 Gen10 Plus" | Enable-HPECOMEmailNotificationPolicy -DailySummary 

    Subscribe the user account, used with 'Connect-HPEGL', to daily summary notifications for all servers with the model 'ProLiant DL360 Gen10 Plus' that are connected.

    .EXAMPLE
    "CZ12312312", "DZ12312312" | Enable-HPECOMEmailNotificationPolicy -Region eu-central -ServiceEventIssues

    Subscribe the user account, used with 'Connect-HPEGL', to server notifications for service events for the servers with serial numbers 'CZ12312312' and 'DZ12312312'.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.

    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * User - Email address of the current user
        * Server - Serial number of the server on which the email notification preferences will be enabled
        * Region - Name of the region where the email notification preferences will be enabled
        * Status - Status of the modification attempt (Failed for http error return; Complete if modification is successful; Warning if no action is needed) 
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.

   #>

    [CmdletBinding(DefaultParameterSetName = 'ServiceEvent')]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
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

        [Parameter (ValueFromPipeline, ValueFromPipelineByPropertyName)] 
        [alias('serialnumber')]
        [String]$ServerSerialNumber,
        
        [Parameter (ParameterSetName = 'ServiceEvent')]       
        [Switch]$ServiceEventIssues,

        [Parameter (ParameterSetName = 'ServiceEventAndCriticalIssues')]       
        [Switch]$ServiceEventAndCriticalIssues,

        [Parameter (ParameterSetName = 'ServiceEventAndCriticalAndWarningIssues')]       
        [Switch]$ServiceEventAndCriticalAndWarningIssues,

        [Switch]$DailySummary,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
  

        $EnableEmailPreferencesStatus = [System.Collections.ArrayList]::new()

        if ($ServiceEventIssues) {
            $criticalNotification = $true
            $warningNotification = $false
            $criticalNonServiceNotification = $false
        }
        elseif ($ServiceEventAndCriticalIssues) {
            $criticalNotification = $true
            $warningNotification = $false
            $criticalNonServiceNotification = $True
        } 
        elseif ($ServiceEventAndCriticalAndWarningIssues) {
            $criticalNotification = $true
            $warningNotification = $true
            $criticalNonServiceNotification = $True
        
        }
        else {
            $criticalNotification = $false
            $warningNotification = $false
            $criticalNonServiceNotification = $false
        }


        if ($DailySummary) {
            $healthNotification = $True

        }
        else {
            $healthNotification = $False

        }


    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
       

        # Check if at least one of the switches is used
        if (-not $DailySummary -and -not ($ServiceEventIssues -or $ServiceEventAndCriticalIssues -or $ServiceEventAndCriticalAndWarningIssues)) {
            Write-Error "You must specify either a service event notification or -DailySummary, or both."
            return
        }
                
        if ($ServerSerialNumber) {
            
            try {

                $_server = Get-HPECOMServer -Region $Region -Name $ServerSerialNumber

            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
            
            if (-not $_server) {

                # Must return a message if not found                    
                $ErrorMessage = "Server '{0}': Resource cannot be found in the '{1}' region!" -f $ServerSerialNumber, $Region
                Write-Warning $ErrorMessage

            }
            else {

                $_serverId = $_server.id

                "[{0}] Server ID found: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_serverId | Write-Verbose

                try {

                    $_serverNotifications = Get-HPECOMEmailNotificationPolicy -Region $Region -SerialNumber $ServerSerialNumber -WarningAction SilentlyContinue
        
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
                    
        
                if ($_serverNotifications) {
    
                    $Uri = (Get-COMServersUri) + "/" + $_serverId + "/notifications"

                    $Method = "PUT"
    
                    # Build object for the output
                    $objStatus = [pscustomobject]@{
            
                        Email     = $Global:HPEGreenLakeSession.username
                        Server    = $ServerSerialNumber
                        Region    = $Region                            
                        Status    = $Null
                        Details   = $Null
                        Exception = $Null
                    }

    
                    if (-not $ServiceEventIssues -and -not $ServiceEventAndCriticalIssues -and -not $ServiceEventAndCriticalAndWarningIssues ) {
    
                        $criticalNotification = $_serverNotifications.criticalNotification  
                        $warningNotification = $_serverNotifications.warningNotification
                        $criticalNonServiceNotification = $_serverNotifications.criticalNonServiceNotification
                    }
                  
                    if (-not $DailySummary) {
                        $healthNotification = $_serverNotifications.healthNotification  
                    }
    
                }
                else {
    
                    Write-Error "You cannot specify a server serial number at this time as no user email notification policy exists yet!"
                    return
        
                }
            }
        }
        else {

            try {

                $_userNotifications = Get-HPECOMEmailNotificationPolicy -Region $Region -WarningAction SilentlyContinue
    
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
                
    
            if ($_userNotifications) {

                $Uri = (Get-COMUserPreferencesUri) + "/" + $_userNotifications.id
                $Method = "PUT"

                if (-not $ServiceEventIssues -and -not $ServiceEventAndCriticalIssues -and -not $ServiceEventAndCriticalAndWarningIssues ) {

                    $criticalNotification = $_userNotifications.criticalNotification  
                    $warningNotification = $_userNotifications.warningNotification
                    $criticalNonServiceNotification = $_userNotifications.criticalNonServiceNotification
                }
              
                if (-not $DailySummary) {
                    $healthNotification = $_userNotifications.healthNotification  
                }

            }
            else {

                $Uri = Get-COMUserPreferencesUri
                $Method = "POST"
    
            }

            # Build object for the output
            $objStatus = [pscustomobject]@{

                Email     = $Global:HPEGreenLakeSession.username
                Server    = "All unless an individual definition has been configured"
                Region    = $Region                            
                Status    = $Null
                Details   = $Null
                Exception = $Null
            }
        }
        
        $Payload = @{
            criticalNotification           = $criticalNotification
            criticalNonServiceNotification = $criticalNonServiceNotification 
            warningNotification            = $warningNotification
            healthNotification             = $healthNotification
        }   




        # Convert the hashtable to JSON
        $jsonPayload = $Payload | ConvertTo-Json


        # Set resource
        try {
            $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method $Method -body $jsonPayload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                
            if (-not $WhatIf) {

                "[{0}] Email notification policy modification raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose
                
                "[{0}] Email notification policy successfully modified in '{1}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose
                    
                $objStatus.Status = "Complete"
                $objStatus.Details = "Email notification policy successfully modified in $Region region"

            }

        }
        catch {

            "[{0}] Error details from `$_.Exception.Message: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
            "[{0}] Error details from `$_.Exception.Details: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Details | Write-Verbose
            
            if (-not $WhatIf) {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Email notification policy cannot be modified!" }
                $objStatus.Exception = $Global:HPECOMInvokeReturnData
            }
        }                  

        [void] $EnableEmailPreferencesStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            $EnableEmailPreferencesStatus = Invoke-RepackageObjectWithType -RawObject $EnableEmailPreferencesStatus -ObjectName "COM.User.Preferences.NSDE"               
            Return $EnableEmailPreferencesStatus
        }


    }
}

Function Disable-HPECOMEmailNotificationPolicy {
    <#
    .SYNOPSIS
    Disable a service instance email notification policy in a region.

    .DESCRIPTION   
    This Cmdlet disables email notification policies for a specified service instance within a designated region.
    
    .PARAMETER Region 
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the email notification preferences will be disabled.
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
        
    .PARAMETER SerialNumber
    Specifies the serial number of the server on which the email notification preferences will be disabled.
    
    Note: Changing the email notification preferences at the individual server level does not reapply the service instance email notification policy.

    Note: Servers managed by HPE OneView are not supported.
        
    .PARAMETER AllServiceEvents
    Disables all notifications for service events and issues. 
    
    .PARAMETER DailySummary
    Disables the daily email summary.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.
   
    .EXAMPLE
    Disable-HPECOMEmailNotificationPolicy -Region eu-central  -AllServiceEvents -DailySummary

    Unsubscribe the user account, used with 'Connect-HPEGL', from all server notifications and the daily summary notifications.

    .EXAMPLE
    Disable-HPECOMEmailNotificationPolicy -Region eu-central -SerialNumber CZ12312312 -AllServiceEvents

    Unsubscribe the user account, used with 'Connect-HPEGL', from all server notifications for the server with serial number 'CZ12312312'.    

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name 'ESX-2.lab' | Disable-HPECOMEmailNotificationPolicy -DailySummary

    Unsubscribe the user account, used with 'Connect-HPEGL', from the daily summary notifications for the server with the name 'ESX-2.lab'.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -ConnectedState True -Model "ProLiant DL360 Gen10 Plus" | Disable-HPECOMEmailNotificationPolicy -DailySummary 

    Unsubscribe the user account, used with 'Connect-HPEGL', from the daily summary notifications for all servers with the model 'ProLiant DL360 Gen10 Plus' that are connected.

    .EXAMPLE
    "CZ12312312", "DZ12312312" | Disable-HPECOMEmailNotificationPolicy -Region eu-central -AllServiceEvents

    Unsubscribe the user account, used with 'Connect-HPEGL', from all server notifications for the servers with serial numbers 'CZ12312312' and 'DZ12312312'.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.

    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * User - Email address of the current user
        * Server - Serial number of the server on which the email notification preferences will be disabled
        * Region - Name of the region where the email notification preferences will be disabled
        * Status - Status of the modification attempt (Failed for http error return; Complete if modification is successful; Warning if no action is needed) 
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.

   #>

    [CmdletBinding()]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
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

        [Parameter (ValueFromPipeline, ValueFromPipelineByPropertyName)] 
        [alias('serialnumber')]
        [String]$ServerSerialNumber,
        
        [Switch]$AllServiceEvents,
        
        [Switch]$DailySummary,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $DisableEmailPreferencesStatus = [System.Collections.ArrayList]::new()

        if ($AllServiceEvents) {
            $criticalNotification = $false
            $warningNotification = $false
            $criticalNonServiceNotification = $false
        }

       
        if ($DailySummary) {
            $healthNotification = $False

        }


    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
       
        # Check if at least one of the switches is used
        if (-not $AllServiceEvents -and -not $DailySummary) {
            Write-Error "You must specify either -AllServiceEvents, -DailySummary, or both."
            return
        }
    
        if ($ServerSerialNumber) {
            
            try {

                $_server = Get-HPECOMServer -Region $Region -Name $ServerSerialNumber

            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
            
            if (-not $_server) {

                # Must return a message if not found
                $ErrorMessage = "Server '{0}': Resource cannot be found in the '{1}' region!" -f $ServerSerialNumber, $Region
                Write-Warning $ErrorMessage

            }
            else {

                $_serverId = $_server.id

                "[{0}] Server ID found: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_serverId | Write-Verbose


                try {

                    $_serverNotifications = Get-HPECOMEmailNotificationPolicy -Region $Region -SerialNumber $ServerSerialNumber -WarningAction SilentlyContinue
        
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
                    
        
                if ($_serverNotifications) {
    
                    $Uri = (Get-COMServersUri) + "/" + $_serverId + "/notifications"

                    $Method = "PUT"
    
                    # Build object for the output
                    $objStatus = [pscustomobject]@{
            
                        Email     = $Global:HPEGreenLakeSession.username
                        Server    = $ServerSerialNumber
                        Region    = $Region                            
                        Status    = $Null
                        Details   = $Null
                        Exception = $Null
                    }

    
                    if (-not $ServiceEventIssues -and -not $ServiceEventAndCriticalIssues -and -not $ServiceEventAndCriticalAndWarningIssues ) {
    
                        $criticalNotification = $_serverNotifications.criticalNotification  
                        $warningNotification = $_serverNotifications.warningNotification
                        $criticalNonServiceNotification = $_serverNotifications.criticalNonServiceNotification
                    }
                  
                    if (-not $DailySummary) {
                        $healthNotification = $_serverNotifications.healthNotification  
                    }
    
                }
                else {
    
                    Write-Error "You cannot specify a server serial number at this time as no user email notification policy exists yet!"
                    return
        
                }
               
            }
        }
        else {

            try {

                $_userNotifications = Get-HPECOMEmailNotificationPolicy -Region $Region -WarningAction SilentlyContinue
    
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
                
    
            if ($_userNotifications) {

                $Uri = (Get-COMUserPreferencesUri) + "/" + $_userNotifications.id
                $Method = "PUT"

                if (-not $AllServiceEvents) {

                    $criticalNotification = $_userNotifications.criticalNotification  
                    $warningNotification = $_userNotifications.warningNotification
                    $criticalNonServiceNotification = $_userNotifications.criticalNonServiceNotification
                }

                if (-not $DailySummary) {
                    $healthNotification = $_userNotifications.healthNotification  
                }

            }
            else {

                $Uri = Get-COMUserPreferencesUri
                $Method = "POST"

    
            }

            # Build object for the output
            $objStatus = [pscustomobject]@{

                Email     = $Global:HPEGreenLakeSession.username
                Server    = "All unless an individual definition has been configured"
                Region    = $Region                            
                Status    = $Null
                Details   = $Null
                Exception = $Null
            }
        }
        
        $Payload = @{
            criticalNotification           = $criticalNotification
            criticalNonServiceNotification = $criticalNonServiceNotification 
            warningNotification            = $warningNotification
            healthNotification             = $healthNotification
        }   


        # Convert the hashtable to JSON
        $jsonPayload = $Payload | ConvertTo-Json


        # Set resource
        try {
            $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method $Method -body $jsonPayload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                
            if (-not $WhatIf) {

                "[{0}] Email notification policy modification raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Response | Write-Verbose
                
                "[{0}] Email notification policy successfully modified in '{1}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose
                    
                $objStatus.Status = "Complete"
                $objStatus.Details = "Email notification policy successfully modified in $Region region"

            }

        }
        catch {

            if (-not $WhatIf) {
                $objStatus.Status = "Failed"
                $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Email notification policy cannot be modified!" }
                $objStatus.Exception = $Global:HPECOMInvokeReturnData 
            }
        }           
        

        [void] $DisableEmailPreferencesStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {
           
            $DisableEmailPreferencesStatus = Invoke-RepackageObjectWithType -RawObject $DisableEmailPreferencesStatus -ObjectName "COM.User.Preferences.NSDE"               
            Return $DisableEmailPreferencesStatus
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
Export-ModuleMember -Function `
    'Get-HPECOMServer', `
    'Get-HPECOMServeriLOSSO', `
    'Enable-HPECOMServerAutoiLOFirmwareUpdate', `
    'Disable-HPECOMServerAutoiLOFirmwareUpdate', `
    'Get-HPECOMServerActivationKey', `
    'Get-HPECOMServerLogs', `
    'New-HPECOMServerActivationKey', `
    'Remove-HPECOMServerActivationKey', `
    'Get-HPECOMEmailNotificationPolicy', `
    'Enable-HPECOMEmailNotificationPolicy', `
    'Disable-HPECOMEmailNotificationPolicy' `
    -Alias *










# SIG # Begin signature block
# MIIunwYJKoZIhvcNAQcCoIIukDCCLowCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCClKIEk7BAUCQzO
# 51aybEGErjikL+i3/2Wb/lOxGXDctKCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# nZ+oA+rbZZyGZkz3xbUYKTGCG/8wghv7AgEBMGkwVDELMAkGA1UEBhMCR0IxGDAW
# BgNVBAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMg
# Q29kZSBTaWduaW5nIENBIFIzNgIRAMgx4fswkMFDciVfUuoKqr0wDQYJYIZIAWUD
# BAIBBQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGC
# NwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQx
# IgQg+GOplOXuASMHzS9cuRlixUcl/ItcSJ+kZ3po5f4lGyMwDQYJKoZIhvcNAQEB
# BQAEggIAKE3yKvTwim15oE5I6sglCO5RVwR6YINcpnZNQtV0FeKWAk/cIp/g0HFw
# eTYu5eKN6x4OGaM5lM4zb9Hutps9PheYslcuNNJFvy5lvKyQas+b0tEAZXWlxr78
# tzOtKtHwhxQ0FGx8IwS6WHCtFppVxQaGAXL1owctigBYxVOPHG3nVKRowJotKRYi
# tlUOonwNsb5t8AVpGEq1J6o419M6t27XQ2GM+jkV0OkWmwzNP3pCvnnqRDr2LFiV
# EHHAb/2HTVuGLK/Sup+hVYXvm0trXEALXAvQrIt05OkpFDJN1hNF7Q+0RqWPCfV3
# 5w2HQl+P5BMUAVhX2GrzVDQD9yrlD0cpXKmyhh8/QAFKNiyLZoI81a/Hc4AD14XS
# U/Y/bYS/yL9B/ufKZ4aeIEc7JhhK7MMiD8GpcH5AlDYllX20CDFQL475juQXKRZO
# Okg+K7rxIB5jmdgAZI7OOqHafliUKTvg4i0aXA1l1jpAsPtRt3EUbPdpDF0vLgcA
# n8q37qxG8ClwFEZEBpE1BWvlsjgg3UGfB/RXXxeNFPB9DcpxV21eYTKUxrQet+8h
# PKDQBlQ8eOwvCGU017IkTL0LKY6mmvpQuv0M7BESlCCxElBUGtZQw9oh+mxrrcMd
# M//U0oAQAh4qg9GPEe+Pq3SsycxMmq4lJYH2Zx1YlDMlRMcJaSOhghjpMIIY5QYK
# KwYBBAGCNwMDATGCGNUwghjRBgkqhkiG9w0BBwKgghjCMIIYvgIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBCAYLKoZIhvcNAQkQAQSggfgEgfUwgfICAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQwgP+oTOHM+qyXKvKOH8FfNrVEa4p9LBd7ZvwJ
# bYpSfLCTtZ2oYafCK+e0Na7MUBbpAhUAoR7/3Ci+Xg9jeefXocG0kR2O1CcYDzIw
# MjYwMTMwMTA1MDAwWqB2pHQwcjELMAkGA1UEBhMCR0IxFzAVBgNVBAgTDldlc3Qg
# WW9ya3NoaXJlMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxMDAuBgNVBAMTJ1Nl
# Y3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgU2lnbmVyIFIzNqCCEwQwggZiMIIE
# yqADAgECAhEApCk7bh7d16c0CIetek63JDANBgkqhkiG9w0BAQwFADBVMQswCQYD
# VQQGEwJHQjEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMSwwKgYDVQQDEyNTZWN0
# aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIENBIFIzNjAeFw0yNTAzMjcwMDAwMDBa
# Fw0zNjAzMjEyMzU5NTlaMHIxCzAJBgNVBAYTAkdCMRcwFQYDVQQIEw5XZXN0IFlv
# cmtzaGlyZTEYMBYGA1UEChMPU2VjdGlnbyBMaW1pdGVkMTAwLgYDVQQDEydTZWN0
# aWdvIFB1YmxpYyBUaW1lIFN0YW1waW5nIFNpZ25lciBSMzYwggIiMA0GCSqGSIb3
# DQEBAQUAA4ICDwAwggIKAoICAQDThJX0bqRTePI9EEt4Egc83JSBU2dhrJ+wY7Jg
# Reuff5KQNhMuzVytzD+iXazATVPMHZpH/kkiMo1/vlAGFrYN2P7g0Q8oPEcR3h0S
# ftFNYxxMh+bj3ZNbbYjwt8f4DsSHPT+xp9zoFuw0HOMdO3sWeA1+F8mhg6uS6BJp
# PwXQjNSHpVTCgd1gOmKWf12HSfSbnjl3kDm0kP3aIUAhsodBYZsJA1imWqkAVqwc
# Gfvs6pbfs/0GE4BJ2aOnciKNiIV1wDRZAh7rS/O+uTQcb6JVzBVmPP63k5xcZNzG
# o4DOTV+sM1nVrDycWEYS8bSS0lCSeclkTcPjQah9Xs7xbOBoCdmahSfg8Km8ffq8
# PhdoAXYKOI+wlaJj+PbEuwm6rHcm24jhqQfQyYbOUFTKWFe901VdyMC4gRwRAq04
# FH2VTjBdCkhKts5Py7H73obMGrxN1uGgVyZho4FkqXA8/uk6nkzPH9QyHIED3c9C
# GIJ098hU4Ig2xRjhTbengoncXUeo/cfpKXDeUcAKcuKUYRNdGDlf8WnwbyqUblj4
# zj1kQZSnZud5EtmjIdPLKce8UhKl5+EEJXQp1Fkc9y5Ivk4AZacGMCVG0e+wwGsj
# cAADRO7Wga89r/jJ56IDK773LdIsL3yANVvJKdeeS6OOEiH6hpq2yT+jJ/lHa9zE
# dqFqMwIDAQABo4IBjjCCAYowHwYDVR0jBBgwFoAUX1jtTDF6omFCjVKAurNhlxmi
# MpswHQYDVR0OBBYEFIhhjKEqN2SBKGChmzHQjP0sAs5PMA4GA1UdDwEB/wQEAwIG
# wDAMBgNVHRMBAf8EAjAAMBYGA1UdJQEB/wQMMAoGCCsGAQUFBwMIMEoGA1UdIARD
# MEEwNQYMKwYBBAGyMQECAQMIMCUwIwYIKwYBBQUHAgEWF2h0dHBzOi8vc2VjdGln
# by5jb20vQ1BTMAgGBmeBDAEEAjBKBgNVHR8EQzBBMD+gPaA7hjlodHRwOi8vY3Js
# LnNlY3RpZ28uY29tL1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdDQVIzNi5jcmww
# egYIKwYBBQUHAQEEbjBsMEUGCCsGAQUFBzAChjlodHRwOi8vY3J0LnNlY3RpZ28u
# Y29tL1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdDQVIzNi5jcnQwIwYIKwYBBQUH
# MAGGF2h0dHA6Ly9vY3NwLnNlY3RpZ28uY29tMA0GCSqGSIb3DQEBDAUAA4IBgQAC
# gT6khnJRIfllqS49Uorh5ZvMSxNEk4SNsi7qvu+bNdcuknHgXIaZyqcVmhrV3PHc
# mtQKt0blv/8t8DE4bL0+H0m2tgKElpUeu6wOH02BjCIYM6HLInbNHLf6R2qHC1SU
# sJ02MWNqRNIT6GQL0Xm3LW7E6hDZmR8jlYzhZcDdkdw0cHhXjbOLsmTeS0SeRJ1W
# JXEzqt25dbSOaaK7vVmkEVkOHsp16ez49Bc+Ayq/Oh2BAkSTFog43ldEKgHEDBbC
# Iyba2E8O5lPNan+BQXOLuLMKYS3ikTcp/Qw63dxyDCfgqXYUhxBpXnmeSO/WA4Nw
# dwP35lWNhmjIpNVZvhWoxDL+PxDdpph3+M5DroWGTc1ZuDa1iXmOFAK4iwTnlWDg
# 3QNRsRa9cnG3FBBpVHnHOEQj4GMkrOHdNDTbonEeGvZ+4nSZXrwCW4Wv2qyGDBLl
# Kk3kUW1pIScDCpm/chL6aUbnSsrtbepdtbCLiGanKVR/KC1gsR0tC6Q0RfWOI4ow
# ggYUMIID/KADAgECAhB6I67aU2mWD5HIPlz0x+M/MA0GCSqGSIb3DQEBDAUAMFcx
# CzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMT
# JVNlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgUm9vdCBSNDYwHhcNMjEwMzIy
# MDAwMDAwWhcNMzYwMzIxMjM1OTU5WjBVMQswCQYDVQQGEwJHQjEYMBYGA1UEChMP
# U2VjdGlnbyBMaW1pdGVkMSwwKgYDVQQDEyNTZWN0aWdvIFB1YmxpYyBUaW1lIFN0
# YW1waW5nIENBIFIzNjCCAaIwDQYJKoZIhvcNAQEBBQADggGPADCCAYoCggGBAM2Y
# 2ENBq26CK+z2M34mNOSJjNPvIhKAVD7vJq+MDoGD46IiM+b83+3ecLvBhStSVjeY
# XIjfa3ajoW3cS3ElcJzkyZlBnwDEJuHlzpbN4kMH2qRBVrjrGJgSlzzUqcGQBaCx
# pectRGhhnOSwcjPMI3G0hedv2eNmGiUbD12OeORN0ADzdpsQ4dDi6M4YhoGE9cbY
# 11XxM2AVZn0GiOUC9+XE0wI7CQKfOUfigLDn7i/WeyxZ43XLj5GVo7LDBExSLnh+
# va8WxTlA+uBvq1KO8RSHUQLgzb1gbL9Ihgzxmkdp2ZWNuLc+XyEmJNbD2OIIq/fW
# lwBp6KNL19zpHsODLIsgZ+WZ1AzCs1HEK6VWrxmnKyJJg2Lv23DlEdZlQSGdF+z+
# Gyn9/CRezKe7WNyxRf4e4bwUtrYE2F5Q+05yDD68clwnweckKtxRaF0VzN/w76kO
# LIaFVhf5sMM/caEZLtOYqYadtn034ykSFaZuIBU9uCSrKRKTPJhWvXk4CllgrwID
# AQABo4IBXDCCAVgwHwYDVR0jBBgwFoAU9ndq3T/9ARP/FqFsggIv0Ao9FCUwHQYD
# VR0OBBYEFF9Y7UwxeqJhQo1SgLqzYZcZojKbMA4GA1UdDwEB/wQEAwIBhjASBgNV
# HRMBAf8ECDAGAQH/AgEAMBMGA1UdJQQMMAoGCCsGAQUFBwMIMBEGA1UdIAQKMAgw
# BgYEVR0gADBMBgNVHR8ERTBDMEGgP6A9hjtodHRwOi8vY3JsLnNlY3RpZ28uY29t
# L1NlY3RpZ29QdWJsaWNUaW1lU3RhbXBpbmdSb290UjQ2LmNybDB8BggrBgEFBQcB
# AQRwMG4wRwYIKwYBBQUHMAKGO2h0dHA6Ly9jcnQuc2VjdGlnby5jb20vU2VjdGln
# b1B1YmxpY1RpbWVTdGFtcGluZ1Jvb3RSNDYucDdjMCMGCCsGAQUFBzABhhdodHRw
# Oi8vb2NzcC5zZWN0aWdvLmNvbTANBgkqhkiG9w0BAQwFAAOCAgEAEtd7IK0ONVgM
# noEdJVj9TC1ndK/HYiYh9lVUacahRoZ2W2hfiEOyQExnHk1jkvpIJzAMxmEc6ZvI
# yHI5UkPCbXKspioYMdbOnBWQUn733qMooBfIghpR/klUqNxx6/fDXqY0hSU1OSkk
# Sivt51UlmJElUICZYBodzD3M/SFjeCP59anwxs6hwj1mfvzG+b1coYGnqsSz2wSK
# r+nDO+Db8qNcTbJZRAiSazr7KyUJGo1c+MScGfG5QHV+bps8BX5Oyv9Ct36Y4Il6
# ajTqV2ifikkVtB3RNBUgwu/mSiSUice/Jp/q8BMk/gN8+0rNIE+QqU63JoVMCMPY
# 2752LmESsRVVoypJVt8/N3qQ1c6FibbcRabo3azZkcIdWGVSAdoLgAIxEKBeNh9A
# QO1gQrnh1TA8ldXuJzPSuALOz1Ujb0PCyNVkWk7hkhVHfcvBfI8NtgWQupiaAeNH
# e0pWSGH2opXZYKYG4Lbukg7HpNi/KqJhue2Keak6qH9A8CeEOB7Eob0Zf+fU+CCQ
# aL0cJqlmnx9HCDxF+3BLbUufrV64EbTI40zqegPZdA+sXCmbcZy6okx/SjwsusWR
# ItFA3DE8MORZeFb6BmzBtqKJ7l939bbKBy2jvxcJI98Va95Q5JnlKor3m0E7xpMe
# YRriWklUPsetMSf2NvUQa/E5vVyefQIwggaCMIIEaqADAgECAhA2wrC9fBs656Oz
# 3TbLyXVoMA0GCSqGSIb3DQEBDAUAMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMK
# TmV3IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBV
# U0VSVFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZp
# Y2F0aW9uIEF1dGhvcml0eTAeFw0yMTAzMjIwMDAwMDBaFw0zODAxMTgyMzU5NTla
# MFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9TZWN0aWdvIExpbWl0ZWQxLjAsBgNV
# BAMTJVNlY3RpZ28gUHVibGljIFRpbWUgU3RhbXBpbmcgUm9vdCBSNDYwggIiMA0G
# CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQCIndi5RWedHd3ouSaBmlRUwHxJBZvM
# WhUP2ZQQRLRBQIF3FJmp1OR2LMgIU14g0JIlL6VXWKmdbmKGRDILRxEtZdQnOh2q
# mcxGzjqemIk8et8sE6J+N+Gl1cnZocew8eCAawKLu4TRrCoqCAT8uRjDeypoGJrr
# uH/drCio28aqIVEn45NZiZQI7YYBex48eL78lQ0BrHeSmqy1uXe9xN04aG0pKG9k
# i+PC6VEfzutu6Q3IcZZfm00r9YAEp/4aeiLhyaKxLuhKKaAdQjRaf/h6U13jQEV1
# JnUTCm511n5avv4N+jSVwd+Wb8UMOs4netapq5Q/yGyiQOgjsP/JRUj0MAT9Yrcm
# XcLgsrAimfWY3MzKm1HCxcquinTqbs1Q0d2VMMQyi9cAgMYC9jKc+3mW62/yVl4j
# nDcw6ULJsBkOkrcPLUwqj7poS0T2+2JMzPP+jZ1h90/QpZnBkhdtixMiWDVgh60K
# mLmzXiqJc6lGwqoUqpq/1HVHm+Pc2B6+wCy/GwCcjw5rmzajLbmqGygEgaj/OLoa
# nEWP6Y52Hflef3XLvYnhEY4kSirMQhtberRvaI+5YsD3XVxHGBjlIli5u+NrLedI
# xsE88WzKXqZjj9Zi5ybJL2WjeXuOTbswB7XjkZbErg7ebeAQUQiS/uRGZ58NHs57
# ZPUfECcgJC+v2wIDAQABo4IBFjCCARIwHwYDVR0jBBgwFoAUU3m/WqorSs9UgOHY
# m8Cd8rIDZsswHQYDVR0OBBYEFPZ3at0//QET/xahbIICL9AKPRQlMA4GA1UdDwEB
# /wQEAwIBhjAPBgNVHRMBAf8EBTADAQH/MBMGA1UdJQQMMAoGCCsGAQUFBwMIMBEG
# A1UdIAQKMAgwBgYEVR0gADBQBgNVHR8ESTBHMEWgQ6BBhj9odHRwOi8vY3JsLnVz
# ZXJ0cnVzdC5jb20vVVNFUlRydXN0UlNBQ2VydGlmaWNhdGlvbkF1dGhvcml0eS5j
# cmwwNQYIKwYBBQUHAQEEKTAnMCUGCCsGAQUFBzABhhlodHRwOi8vb2NzcC51c2Vy
# dHJ1c3QuY29tMA0GCSqGSIb3DQEBDAUAA4ICAQAOvmVB7WhEuOWhxdQRh+S3OyWM
# 637ayBeR7djxQ8SihTnLf2sABFoB0DFR6JfWS0snf6WDG2gtCGflwVvcYXZJJlFf
# ym1Doi+4PfDP8s0cqlDmdfyGOwMtGGzJ4iImyaz3IBae91g50QyrVbrUoT0mUGQH
# bRcF57olpfHhQEStz5i6hJvVLFV/ueQ21SM99zG4W2tB1ExGL98idX8ChsTwbD/z
# IExAopoe3l6JrzJtPxj8V9rocAnLP2C8Q5wXVVZcbw4x4ztXLsGzqZIiRh5i111T
# W7HV1AtsQa6vXy633vCAbAOIaKcLAo/IU7sClyZUk62XD0VUnHD+YvVNvIGezjM6
# CRpcWed/ODiptK+evDKPU2K6synimYBaNH49v9Ih24+eYXNtI38byt5kIvh+8aW8
# 8WThRpv8lUJKaPn37+YHYafob9Rg7LyTrSYpyZoBmwRWSE4W6iPjB7wJjJpH2930
# 8ZkpKKdpkiS9WNsf/eeUtvRrtIEiSJHN899L1P4l6zKVsdrUu1FX1T/ubSrsxrYJ
# D+3f3aKg6yxdbugot06YwGXXiy5UUGZvOu3lXlxA+fC13dQ5OlL2gIb5lmF6Ii8+
# CQOYDwXM+yd9dbmocQsHjcRPsccUd5E9FiswEqORvz8g3s+jR3SFCgXhN4wz7NgA
# nOgpCdUo4uDyllU9PzGCBJIwggSOAgEBMGowVTELMAkGA1UEBhMCR0IxGDAWBgNV
# BAoTD1NlY3RpZ28gTGltaXRlZDEsMCoGA1UEAxMjU2VjdGlnbyBQdWJsaWMgVGlt
# ZSBTdGFtcGluZyBDQSBSMzYCEQCkKTtuHt3XpzQIh616TrckMA0GCWCGSAFlAwQC
# AgUAoIIB+TAaBgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkF
# MQ8XDTI2MDEzMDEwNTAwMFowPwYJKoZIhvcNAQkEMTIEMPKu92yUGhUZJJM2UjJ7
# /5LAm4WGhNVQr6GrAiNyV+EPXi1qDKpx8m1HuoYZBjTwADCCAXoGCyqGSIb3DQEJ
# EAIMMYIBaTCCAWUwggFhMBYEFDjJFIEQRLTcZj6T1HRLgUGGqbWxMIGHBBTGrlTk
# eIbxfD1VEkiMacNKevnC3TBvMFukWTBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMP
# U2VjdGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBUaW1lIFN0
# YW1waW5nIFJvb3QgUjQ2AhB6I67aU2mWD5HIPlz0x+M/MIG8BBSFPWMtk4KCYXzQ
# kDXEkd6SwULaxzCBozCBjqSBizCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5l
# dyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNF
# UlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNh
# dGlvbiBBdXRob3JpdHkCEDbCsL18Gzrno7PdNsvJdWgwDQYJKoZIhvcNAQEBBQAE
# ggIASY8kdtiAIqzyYDlouPnp59MpKE0ELEiIAsqZSW/M6KkykWBP/wKM5yKlLVae
# g9/TGHgwF1m9i6pV/pm9SQ9pCiqKcb9rasNBTWtELpcnMNXmZw2tJCsX+s+5HdqM
# 9W7/S1rnHnHxOA79iqSK8mEn3ycyfb8m8eT7o+lrVVhfAyj+ryrU2yT87heC8qv5
# rHs9cpqnuXooSzmlybgZ/4rNmlvLuB8W6oyUI3Oyxc3eeMTivfk+NVL69xLvC3ZX
# EPhSNKmGfWlYpSG70b+oPvAxJmqWrePH9yW5dbA48IX4FZhjCOQKVUCIwn5iFz1n
# crIo7liAsnuhsh5wGyIebMI+eALdPcfx9x6X+s+fRgDIN7aiRKMRIYHi5cXpDbz/
# o2vZMc/+ggVNOWSTq+pbtL+3mOK7sjO+U+yfktFcaFL9CFhTtgXTLtleY2b+B9sy
# ydupupH+OxkD9M5qIRmbyRhZY7IOvwjlNLvdufGU256l3vX7vlgnEV/kt6DKmXZS
# TOVak0HxV96AyAZDd4F47sTr1NirwXqZXcOMuJtlL9xr0OmBafFcxqYd6i770twi
# O7JZxMYRACSHvB0J3Y2hmokIu+6t8KU67bY0bvCMqdz3hs1bg19xmh5RbNa1srdn
# UD+dU9YIDK2Ou5NGS6P4d7txZ3f7lCITpY9r1tO53+PRTyM=
# SIG # End signature block
