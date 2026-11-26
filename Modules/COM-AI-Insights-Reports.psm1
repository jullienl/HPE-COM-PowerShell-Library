#------------------- FUNCTIONS FOR COMPUTE OPS MANAGEMENT REPORTS -----------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1

# Public functions
Function Get-HPECOMReport {
    <#
    .SYNOPSIS
    Retrieve the list of reports.

    .DESCRIPTION
    This Cmdlet returns a collection of reports and their associated data that are available in the specified region.

    Note: To get more information about report details, you can use Get-HPECOMServerInventory and Get-HPECOMSustainabilityReport.
    
    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) from which to retrieve the reports.
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER ServerHardwareInventoryReport
    Optional switch parameter that can be used to display the server hardware inventory report.

    .PARAMETER ServerHardwareInventoryData
    Optional switch parameter that can be used to display the data of the server hardware inventory report.  

    .PARAMETER SustainabilityReport
    Optional switch parameter that can be used to display the sustainability report.
    
    .PARAMETER SustainabilityData
    Optional switch parameter that can be used to display the data of the sustainability report.  

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMReport -Region us-west 

    Return all reports resources located in the western US region. 

    .EXAMPLE
    Get-HPECOMReport -Region us-west -ServerHardwareInventoryReport 

    Return the server hardware inventory report located in the western US region. 

    .EXAMPLE
    Get-HPECOMReport -Region us-west -ServerHardwareInventoryData 
    
    Return the data of the server hardware inventory report. 
    
    .EXAMPLE
    Get-HPECOMReport -Region eu-central -SustainabilityReport 

    Return the sustainability report located in the western US region. 

    .EXAMPLE
    Get-HPECOMReport -Region eu-central -SustainabilityData 
    
    Return the data of the sustainability report. 

    
   #>
    [CmdletBinding(DefaultParameterSetName = "Region")]
    Param( 
        [Parameter (Mandatory, ParameterSetName = 'Region')]
        [Parameter (Mandatory, ParameterSetName = 'ServerHardwareInventoryReport')]
        [Parameter (Mandatory, ParameterSetName = 'ServerHardwareInventoryData')]
        [Parameter (Mandatory, ParameterSetName = 'SustainabilityReport')]
        [Parameter (Mandatory, ParameterSetName = 'Co2Emissions')]
        [Parameter (Mandatory, ParameterSetName = 'EnergyConsumption')]
        [Parameter (Mandatory, ParameterSetName = 'EnergyCost')]
        [Parameter (Mandatory, ParameterSetName = 'Co2EmissionsTotal')]
        [Parameter (Mandatory, ParameterSetName = 'EnergyConsumptionTotal')]
        [Parameter (Mandatory, ParameterSetName = 'EnergyCostTotal')]
        [ValidateScript({
                # First check if there's an active session with COM regions
                if (-not $Global:HPEGreenLakeSession) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use the cmdlets of the HPECOMCmdlets module."
                }
                if (-not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "Compute Ops Management is not provisioned in this workspace!`n`nCAUSE:`nNo provisioned Compute Ops Management region was found.`n`nACTION REQUIRED:`nVerify the Compute Ops Management service is provisioned using:`n    Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned`n`nIf not provisioned, you can provision it using 'New-HPEGLService'."
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


        [Parameter (ParameterSetName = 'ServerHardwareInventoryReport')]
        [Switch]$ServerHardwareInventoryReport,

        [Parameter (ParameterSetName = 'ServerHardwareInventoryData')]
        [Switch]$ServerHardwareInventoryData,

        [Parameter (ParameterSetName = 'SustainabilityReport')]
        [Switch]$SustainabilityReport,

        [Parameter (ParameterSetName = 'Co2Emissions')]
        [Switch]$SustainabilityData,
    
        [Switch]$WhatIf
       
    ) 

    Begin {
    
        $Caller = (Get-PSCallStack)[1].Command
    
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose


    }


    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        
        if ($ServerHardwareInventoryReport) {
            # $Uri = (Get-COMReportsUri) + "?filter=reportType eq 'SERVER_HARDWARE_INVENTORY'"
            $Uri = (Get-COMReportsUri) + "?filter=reportType eq 'SERVER_HARDWARE_INVENTORY'&limit=10"
            
        }        
        elseif ($ServerHardwareInventoryData) {

            # $Uri = Get-COMReportsUri
            $Uri = (Get-COMReportsUri) + "?limit=10"

            try {

                $ReportList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region
                
                "[{0}] Server hardware inventory report: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ReportList | ConvertTo-Json -d 10) | Write-Verbose

                $ReportID = ($ReportList | Where-Object reportType -eq "SERVER_HARDWARE_INVENTORY" ).id

                "[{0}] ID found for 'Server hardware inventory report': '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ReportID | Write-Verbose

                if ($Null -eq $ReportID) { Throw "Error: Server hardware inventory report not found! You need to run New-HPECOMServerInventory first" }
    
                $Uri = (Get-COMReportsUri) + "/" + $ReportID + "/data" + "?limit=10"
             
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
           
            }
        }
        elseif ($SustainabilityReport) {
            # $Uri = (Get-COMReportsUri) + "?filter=reportType eq 'CARBON_FOOTPRINT'"
            $Uri = (Get-COMReportsUri) + "?filter=reportType eq 'CARBON_FOOTPRINT'&limit=10"
            
        }
        elseif ($SustainabilityData) {
           
            # $Uri = Get-COMReportsUri 
            $Uri = (Get-COMReportsUri) + "?limit=10"

            try {

                $ReportList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region
                
                "[{0}] Sustainability report: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ReportList | ConvertTo-Json -d 10) | Write-Verbose

                $ReportID = ($ReportList | Where-Object reportType -eq "CARBON_FOOTPRINT" ).id

                "[{0}] ID found for 'sustainability report': '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ReportID | Write-Verbose

                if ($Null -eq $ReportID) { Throw "Error: Sustainability report not found! You need to run New-HPECOMSustainabilityReport first" }
    
                $Uri = (Get-COMReportsUri) + "/" + $ReportID + "/data" + "?limit=10"
             
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
           
            }
            
        }
        else {
            # $Uri = (Get-COMReportsUri) 
            $Uri = (Get-COMReportsUri) + "?limit=10"
            
        }


        try {
            [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
    
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
                   
        }           
        

        $ReturnData = @()
       
        if ($Null -ne $CollectionList) {    
            
            # Add region to object
            $CollectionList | Add-Member -type NoteProperty -name region -value $Region            


            if ($ServerHardwareInventoryData) {

                $CollectionList = $CollectionList.data.rows.items
               
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Reports.ServerHardwareInventoryData"    
                $ReturnData = $ReturnData | Sort-Object name

            }
            
            elseif ($SustainabilityData) {

                $CollectionList = $CollectionList.data.series

                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Reports.SustainabilityData"    
                $ReturnData = $ReturnData | Sort-Object { $_.name, $_.subject.displayName }

            }
            else {
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Reports"    
                $ReturnData = $ReturnData | Sort-Object name
            }

        
            return $ReturnData 
                
        }
        else {

            return
                
        }     

    
    }
}

function New-HPECOMServerInventory {
    <#
    .SYNOPSIS
    Collect server inventory data.
    
    .DESCRIPTION   
    This cmdlet collects inventory data from a directly managed or OneView managed server.
    It also provides options for scheduling execution at a specific time and setting recurring schedules.
    
    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the server is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER Name
    Name, hostname, or serial number of the server on which server inventory data will be collected. 
    
    .PARAMETER Chassis
    Switch parameter that can be used to collect the chassis inventory data.
    When no inventory list is provided, all inventory resources will be collected.
    
    .PARAMETER Devices
    Switch parameter that can be used to collect the devices inventory data.
    When no inventory list is provided, all inventory resources will be collected.

    .PARAMETER Fans
    Switch parameter that can be used to collect the fans inventory data.
    When no inventory list is provided, all inventory resources will be collected.

    .PARAMETER Firmware
    Switch parameter that can be used to collect the firmware inventory data.
    When no inventory list is provided, all inventory resources will be collected.

    .PARAMETER LocalStorage
    Switch parameter that can be used to collect the local storage inventory data.
    When no inventory list is provided, all inventory resources will be collected.

    .PARAMETER Memory
    Switch parameter that can be used to collect the memory inventory data.
    When no inventory list is provided, all inventory resources will be collected.

    .PARAMETER NetworkAdapters
    Switch parameter that can be used to collect the network adapters inventory data.
    When no inventory list is provided, all inventory resources will be collected.

    .PARAMETER PowerSupplies
    Switch parameter that can be used to collect the power supplies inventory data.
    When no inventory list is provided, all inventory resources will be collected.

    .PARAMETER Processor
    Switch parameter that can be used to collect the processor inventory data.
    When no inventory list is provided, all inventory resources will be collected.

    .PARAMETER Software
    Switch parameter that can be used to collect the software inventory data.
    When no inventory list is provided, all inventory resources will be collected.

    .PARAMETER ScheduleTime
    Specifies the date and time when the server inventory operation should be executed. 
    This parameter accepts a DateTime object or a string representation of a date and time. 
    If not specified, the server inventory operation will be executed immediately.

    Examples for setting the date and time using `Get-Date`:
    - (Get-Date).AddMonths(6)
    - (Get-Date).AddDays(15)
    - (Get-Date).AddHours(3)
    Example for using a specific date string:
    - "2024-05-20 08:00:00"
    
    .PARAMETER Interval
    Specifies the interval at which the server inventory operation should be repeated. This parameter accepts a TimeSpan object or a string representation of a time interval. 
    If not specified, the server inventory operation will not be repeated.

    This parameter supports common ISO 8601 period durations such as:
    - P1D (1 Day)
    - P1W (1 Week)
    - P1M (1 Month)
    - P1Y (1 Year)
    
    The accepted formats include periods (P) referencing days, weeks, months, years but not time (T) designations that reference hours, minutes, and seconds.

    A valid interval must be greater than 15 minutes (PT15M) and less than 1 year (P1Y).

    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties). By default, the Cmdlet will wait for the job to complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    New-HPECOMServerInventory -Region us-west -Name CN70490RXQ  

    Collects a full inventory data from server 'CN70490RXQ' in the western US region.

    .EXAMPLE
    New-HPECOMServerInventory -Region us-west -Name CN70490RXQ -Chassis -Fans 

    Collects the chassis and fans inventory data from server 'CN70490RXQ' in the western US region.

    .EXAMPLE
    Get-HPECOMServer -Region us-west -Name HOL19  | New-HPECOMServerInventory

    Collects the full inventory data from server named 'HOL19' in the western US region.    
    
    .EXAMPLE
    New-HPECOMServerInventory -Region eu-central -Name CZ12312312 -ScheduleTime (Get-Date).AddDays(1) 

    Creates a new server inventory in the 'eu-central' region for server 'CZ12312312', scheduled to start one day from the current date.

    .EXAMPLE
    New-HPECOMServerInventory -Region eu-central -Name CZ12312312 -ScheduleTime (Get-Date).AddDays(1) -Interval P1W

    Creates a new server inventory in the 'eu-central' region for server 'CZ12312312', scheduled to start one day from the current date and recur weekly.

    .EXAMPLE
    "CZ12312312", "CZ12312313" | New-HPECOMServerInventory -Region eu-central

    Collects a full inventory data from servers 'CZ12312312' and 'CZ12312313' in the 'eu-central' region.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's name, hostname, or serial number.
    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer'. 

    .OUTPUTS
    HPEGreenLake.COM.Jobs.Status [System.Management.Automation.PSCustomObject]

        - When the job completes, the returned object contains detailed job status information, including:
            - `state`: The final state of the job, such as:
                - COMPLETE (job finished successfully)
                - ERROR (job failed)
                - STALLED (job is not making progress)
                - PENDING (job is queued and waiting to start)
                - RUNNING (job is currently in progress)
            - `resultCode`: The result of the job execution, such as:
                - SUCCESS (operation completed successfully)
                - FAILURE (operation failed)
                - null (job is still running or in a non-terminal state)
            - Additional properties may include:
                - `associatedResource`: The resource associated with the job
                - `date`: The date and time when the job was created
                - `jobUri`: The URI of the job resource
                - `duration`: The time taken for the job to complete
                - `message`: Any informational or error messages returned by the job
                - `details`: The full job resource object with all available metadata

        - If the `-Async` switch is used, the cmdlet returns the job resource immediately, allowing you to monitor its progress using the `state` and `resultCode` properties, or by passing the job object to `Wait-HPECOMJobComplete` for blocking/waiting behavior.

    HPEGreenLake.COM.Schedules.Status [System.Management.Automation.PSCustomObject]

        - The schedule job object that includes the schedule details when `-ScheduleTime` is used.
    #>

    [CmdletBinding(DefaultParameterSetName = 'Async')]
    Param
    (
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
        [ValidateScript({
                # First check if there's an active session with COM regions
                if (-not $Global:HPEGreenLakeSession) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use the cmdlets of the HPECOMCmdlets module."
                }
                if (-not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "Compute Ops Management is not provisioned in this workspace!`n`nCAUSE:`nNo provisioned Compute Ops Management region was found.`n`nACTION REQUIRED:`nVerify the Compute Ops Management service is provisioned using:`n    Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned`n`nIf not provisioned, you can provision it using 'New-HPEGLService'."
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
        
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [Alias('SerialNumber', 'serial')]
        [ValidateNotNullOrEmpty()]
        [String]$Name,
        
        [switch]$Chassis,

        [switch]$Devices,

        [switch]$Fans,

        [switch]$Firmware,
        
        [switch]$LocalStorage,

        [switch]$Memory,
        
        [switch]$NetworkAdapters,
        
        [switch]$PowerSupplies,

        [switch]$Processor,

        [switch]$Software,

        [Parameter (Mandatory, ParameterSetName = 'Schedule')]
        [ValidateScript({
                if ($_ -ge (Get-Date) -and $_ -le (Get-Date).AddYears(1)) {
                    $true
                }
                else {
                    throw "The ScheduleTime must be within one year from the current date."
                }
            })]
        [DateTime]$ScheduleTime,

        [ValidateScript({
                if ($_ -match '^P(\d+Y)?(\d+M)?(\d+W)?(\d+D)?$') {
                    return $true
                }
                else {
                    throw "Invalid period interval format. Please use an ISO 8601 period interval without time components (e.g., P1D, P1W, P1M, P1Y)"
                }
            })]
        [Parameter (ParameterSetName = 'Schedule')]
        [String]$Interval, 

        [Parameter (ParameterSetName = 'Async')]
        [switch]$Async,

        [switch]$WhatIf


    )

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $_JobTemplateName = 'GetFullServerInventory'

        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $Uri = Get-COMJobsUri

        $ObjectStatusList = [System.Collections.ArrayList]::new()

        
    }

    Process {  

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $Filters = [System.Collections.ArrayList]::new()

        # Build tracking object for a schedule output
        if ($ScheduleTime) {

            $objStatus = [pscustomobject]@{
                name               = $Null
                description        = if ($Name) { "Scheduled task to collect inventory data from server '$Name'" } else { "Scheduled task to collect inventory data from all servers" }
                associatedResource = if ($Name) { $Name } else { "All servers" }
                purpose            = "INVENTORY_REPORT"
                id                 = $Null
                nextStartAt        = $Null
                lastRun            = $Null
                scheduleUri        = $Null
                schedule           = $Null
                resultCode         = $Null
                message            = $Null    
                details            = $Null        
            }

        }
        # Build tracking object for non-schedule output
        else {

            $objStatus = [pscustomobject]@{               
                name               = $_JobTemplateName
                associatedResource = if ($Name) { $Name } else { "All servers" }
                date               = "$((Get-Date).ToString())"
                state              = $Null
                duration           = $Null
                status             = $Null
                jobUri             = $Null 
                region             = $Region  
                resultCode         = $Null
                message            = $Null    
                details            = $Null        
            }
        }

        try {

            $_server = Get-HPECOMServer -Region $Region -Name $Name
            $_ResourceUri = $_server.resourceUri
            $_ResourceId = $_server.Id
            $_ResourceType = $_server.type

            "[{0}] Resource is 'SERVERS' type: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_ResourceUri | Write-Verbose
          
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
        
        if (-not $_ResourceUri) {
            # Must return a message if not found

            if ($ScheduleTime) {
                $objStatus.resultCode = "FAILURE"
                $objStatus.message = "Server cannot be found in the Compute Ops Management instance!"
            }
            else {
                $objStatus.state = "WARNING"
                $objStatus.duration = '00:00:00'
                $objStatus.resultCode = "FAILURE"
                $objStatus.status = "Warning"
                $objStatus.message = "Server cannot be found in the Compute Ops Management instance!"
            }
            
            if ($WhatIf) {
                $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Name
                Write-Warning "$ErrorMessage Cannot display API request."
                return

            }
        }
        else {

            $componentMap = @{
                Chassis         = "Chassis"
                Processor       = "Processor"
                Memory          = "memory"
                NetworkAdapters = "networkAdapters"
                LocalStorage    = "localStorageV2"
                LocalStorageV2  = "localStorageV2"
                Devices         = "devicesV2"
                DevicesV2       = "devicesV2"
                PowerSupplies   = "powerSupplies"
                Fans            = "fans"
                Firmware        = "firmware"
                Software        = "software"
            }
            
            foreach ($param in $componentMap.Keys) {
                if ($PSBoundParameters.ContainsKey($param)) {
                    [void]$Filters.Add($componentMap[$param])
                }
            }
            
            if ($Filters.Count -gt 0) {
                $data = @{
                    filters                    = $Filters
                    is_activity_message_needed = $true
                }
            }   
            else {
                $data = @{
                    is_activity_message_needed = $true
                }
            }                   

            if ($ScheduleTime) {

                $Uri = Get-COMSchedulesUri

                if ($data) {
                    
                    $_Body = @{
                        jobTemplateUri = "/api/compute/v1/job-templates/" + $JobTemplateId
                        resourceUri    = $_ResourceUri
                        data           = $data
                    }      
                }
                else {

                    $_Body = @{
                        jobTemplateUri = "/api/compute/v1/job-templates/" + $JobTemplateId
                        resourceUri    = $_ResourceUri
                    }    

                }
                
                $Operation = @{
                    type   = "REST"
                    method = "POST"
                    uri    = "/api/compute/v1/jobs"
                    body   = $_Body

                }

                $randomNumber = Get-Random -Minimum 000000 -Maximum 999999

                $ScheduleName = "$($Name)_Inventory_Report_Schedule_$($randomNumber)"
                $Description = "Scheduled task to run an inventory report on server '$($Name)'"

                if ($Interval) {
                    
                    $Schedule = @{
                        startAt  = $ScheduleTime.ToString("o")  # Convert to ISO 8601 format as $ScheduleTime alone is converted by PS5.1 to '/Date(...)\/ notation'
                        interval = $Interval
                    }
                }
                else {

                    $Schedule = @{
                        startAt = $ScheduleTime.ToString("o")  # Convert to ISO 8601 format as $ScheduleTime alone is convert by PS5.1 to '/Date(...)\/ notation'
                        # interval = $Null
                    }
                }

                $Payload = @{
                    name                  = $ScheduleName
                    description           = $Description
                    associatedResourceUri = $_ResourceUri
                    purpose               = "INVENTORY_REPORT"
                    schedule              = $Schedule
                    operation             = $Operation

                }

            }
            else {

                if ($data) {

                    $payload = @{
                        jobTemplate  = $JobTemplateId
                        resourceId   = $_ResourceId
                        resourceType = $_ResourceType
                        jobParams    = $data
                    }
                }
                else {
    
                    $payload = @{
                        jobTemplate  = $JobTemplateId
                        resourceId   = $_ResourceId
                        resourceType = $_ResourceType
                        jobParams    = @{}
                    }    
                }
            }
            

            $payload = ConvertTo-Json $payload -Depth 10 

            try {
                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference -ErrorAction Stop   

                if ($ScheduleTime) {

                    if (-not $WhatIf) {
        
                        "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
                        
                        $objStatus.name = $_resp.name
                        $objStatus.id = $_resp.id
                        $objStatus.nextStartAt = $_resp.nextStartAt
                        $objStatus.lastRun = $_resp.lastRun
                        $objStatus.scheduleUri = $_resp.resourceUri
                        $objStatus.schedule = $Schedule
                        $objStatus.lastRun = $_resp.lastRun
                        $objStatus.resultCode = "SUCCESS"
                        $objStatus.details = $_resp
                        $objStatus.message = "The schedule to collect inventory data has been successfully created."

                    }

                }
                else {

                    if (-not $WhatIf -and -not $Async) {
            
                        "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri) | Write-Verbose
            
                        $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout 600 # 10 minutes timeout
    
                        "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
    
                    }

                    if (-not $WhatIf ) {
            
                        if ($_resp -and $_resp.PSObject.Properties.Name -contains 'createdAt' -and $_resp.PSObject.Properties.Name -contains 'updatedAt') {
                            # Calculate duration only if createdAt and updatedAt properties are present
                            $Duration = ((Get-Date $_resp.updatedAt) - (Get-Date $_resp.createdAt)).ToString('hh\:mm\:ss')
                        }
                        else {
                            $Duration = '00:00:00'
                        }

                        $objStatus.state = $_resp.state
                        $objStatus.duration = $Duration
                        $objStatus.resultCode = $_resp.resultCode
                        $objStatus.message = $_resp.message
                        $objStatus.status = $_resp.Status
                        $objStatus.details = $_resp
                        $objStatus.jobUri = $_resp.resourceUri        
                        
                    }
                }

                "[{0}] ObjStatus content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus | Write-Verbose


            }
            catch {

                "[{0}] Error details from `$_.Exception.Message: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                "[{0}] Error details from `$_.Exception.Details: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Details | Write-Verbose
                # "[{0}] Global error details: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Global:HPECOMInvokeReturnData | Out-String) | Write-Verbose

                if (-not $WhatIf) {
                    if ($ScheduleTime) {
                        $objStatus.name = $Name
                        $objStatus.schedule = $Schedule
                        $objStatus.resultCode = "FAILURE"
                        $objStatus.message = $_.Exception.Details
                    }
                    else {
                        $objStatus.state = "ERROR"
                        $objStatus.duration = '00:00:00'
                        $objStatus.resultCode = "FAILURE"
                        $objStatus.status = "Failed"
                        $objStatus.message = $_.Exception.Details
                    }      
                }
            } 
            
        }

        # Add tracking object to the list of object status list
        if (-not $WhatIf) { [void]$ObjectStatusList.Add($objStatus) }

        
    }

    end {

        if ($ObjectStatusList.Count -gt 0) {

            if ($ScheduleTime) {

                $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "COM.Schedules.Status" 
            }
            else {

                $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "COM.Jobs.Status" 
            }

            "[{0}] Output content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList | Out-String) | Write-Verbose
            Return $ObjectStatusList
        }
    }
}

Function Get-HPECOMServerInventory {
    <#
    .SYNOPSIS
    Retrieve the inventories of a server.
    
    .DESCRIPTION
    This Cmdlet can be used to retrieve firmware, software, storage inventories, PCI devices and smart update tool settings for a server specified by the 
    name or serial number of the server.   

    To retrieve HPE drivers and software inventory, ensure the server has a running operating system with the HPE Agentless Management Service (AMS) installed and active.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER Name 
    Parameter that can be used to specify a server's name or serial number in order to obtain its inventory.
    
   .PARAMETER ShowChassis
    Parameter that can be used to get the chassis inventory.   

   .PARAMETER ShowDevice
    Parameter that can be used to get the device inventory (OCP, PCI, embedded, etc.).

   .PARAMETER ShowFans
    Parameter that can be used to get the fan inventory.

   .PARAMETER ShowFirmware
    Parameter that can be used to get the firmware inventory.

   .PARAMETER ShowMemory
    Parameter that can be used to get the memory inventory.

   .PARAMETER ShowNetworkAdapter
    Parameter that can be used to get the network adapter inventory (NIC, CNA, HBA, etc.).

   .PARAMETER ShowPowerSupply
    Parameter that can be used to get the power supply inventory.

   .PARAMETER ShowProcessor
    Parameter that can be used to get the processor inventory.

   .PARAMETER ShowSmartUpdateTool
    Parameter that can be used to get the Smart Update Tool (SUT) information details.

   .PARAMETER ShowSoftware
    Parameter that can be used to get the software inventory.

   .PARAMETER ShowStorageController
    Parameter that can be used to get the storage controller inventory.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.
    
    .EXAMPLE
    Get-HPECOMServerInventory -Region us-west -Name TWA22565A6
    
    Retrieves the inventory for the server with the serial number TWA22565A6 in the western US region.
    
    .EXAMPLE
    # Retrieve the firmware inventory details of a server using its serial number
    Get-HPECOMServerInventory -Region us-west -Name TWA22565A6 -ShowFirmware

    # Alternatively, if the serial number is not known, use the server name
    Get-HPECOMServer -Region us-west -Name WIN-2022-1 | Get-HPECOMServerInventory -ShowFirmware
    
    This command returns the firmware inventory details of the server with serial number 'TWA22565A6' in the western US region.

    .EXAMPLE
    # Retrieve the software inventory details of a server using its serial number
    Get-HPECOMServerInventory -Region us-west -Name TWA22565A6 -ShowSoftware
    
    # Alternatively, if the serial number is not known, use the server name
    Get-HPECOMServer -Region us-west -Name WIN-2022-1 | Get-HPECOMServerInventory -ShowSoftware
    
    This command returns the software inventory details of the server with serial number 'TWA22565A6' in the western US region.

    .EXAMPLE
    # Retrieve the device inventory details of a server using its serial number
    Get-HPECOMServerInventory -Region us-west -Name TWA22565A6 -ShowDevice
    
    # Alternatively, if the serial number is not known, use the server name
    Get-HPECOMServer -Region us-west -Name WIN-2022-1 | Get-HPECOMServerInventory -ShowDevice
    
    This command returns the device inventory details of the server with serial number 'TWA22565A6' in the western US region.

    .EXAMPLE
    # Retrieve the fan inventory details of a server using its serial number
    Get-HPECOMServerInventory -Region us-west -Name TWA22565A6 -ShowFans
    
    # Alternatively, if the serial number is not known, use the server name
    Get-HPECOMServer -Region us-west -Name WIN-2022-1 | Get-HPECOMServerInventory -ShowFans
    
    This command returns the fan inventory details of the server with serial number 'TWA22565A6' in the western US region.

    .EXAMPLE
    # Retrieve the memory inventory details of a server using its serial number
    Get-HPECOMServerInventory -Region us-west -Name TWA22565A6 -ShowMemory
    
    # Alternatively, if the serial number is not known, use the server name
    Get-HPECOMServer -Region us-west -Name WIN-2022-1 | Get-HPECOMServerInventory -ShowMemory
    
    This command returns the memory inventory details of the server with serial number 'TWA22565A6' in the western US region.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.
    System.Collections.ArrayList
        List of servers retrieved using 'Get-HPECOMServer -Name $Name'.

   #>

    [CmdletBinding(DefaultParameterSetName = 'SerialNumber')]
    Param( 
    
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)] 
        [ValidateScript({
                # First check if there's an active session with COM regions
                if (-not $Global:HPEGreenLakeSession) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use the cmdlets of the HPECOMCmdlets module."
                }
                if (-not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "Compute Ops Management is not provisioned in this workspace!`n`nCAUSE:`nNo provisioned Compute Ops Management region was found.`n`nACTION REQUIRED:`nVerify the Compute Ops Management service is provisioned using:`n    Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned`n`nIf not provisioned, you can provision it using 'New-HPEGLService'."
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
   
        [Parameter (Mandatory, ParameterSetName = 'SerialNumber', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter (Mandatory, ParameterSetName = 'InventorySN', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter (Mandatory, ParameterSetName = 'InventorysoftwareSN', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter (Mandatory, ParameterSetName = 'InventoryFirmwareSN', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter (Mandatory, ParameterSetName = 'InventorystorageSN', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter (Mandatory, ParameterSetName = 'InventorysmartStorageSN', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter (Mandatory, ParameterSetName = 'InventorydeviceSN', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter (Mandatory, ParameterSetName = 'InventorysmartUpdateToolSN', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter (Mandatory, ParameterSetName = 'InventorychassisSN', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter (Mandatory, ParameterSetName = 'InventorymemorySN', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter (Mandatory, ParameterSetName = 'InventorynetworkAdapterSN', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter (Mandatory, ParameterSetName = 'InventoryprocessorSN', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter (Mandatory, ParameterSetName = 'InventorypowerSupplySN', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter (Mandatory, ParameterSetName = 'InventorythermalSN', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias ('serialNumber')]
        [ValidateNotNullOrEmpty()]
        [String]$Name,
       
        # [Parameter (ParameterSetName = 'InventorychassisName')]
        [Parameter (ParameterSetName = 'InventorychassisSN')]
        [Switch]$ShowChassis,

        # [Parameter (ParameterSetName = 'InventorydeviceName')]
        [Parameter (ParameterSetName = 'InventorydeviceSN')]
        [Switch]$ShowDevice,
        
        # [Parameter (ParameterSetName = 'InventorythermalName')]
        [Parameter (ParameterSetName = 'InventorythermalSN')]
        [Switch]$ShowFans,

        # [Parameter (ParameterSetName = 'InventoryFirmwareName')]
        [Parameter (ParameterSetName = 'InventoryFirmwareSN')]
        [Switch]$ShowFirmware,
        
        # [Parameter (ParameterSetName = 'InventorymemoryName')]
        [Parameter (ParameterSetName = 'InventorymemorySN')]
        [Switch]$ShowMemory,

        # [Parameter (ParameterSetName = 'InventorynetworkAdapterName')]
        [Parameter (ParameterSetName = 'InventorynetworkAdapterSN')]
        [Switch]$ShowNetworkAdapter,

        # [Parameter (ParameterSetName = 'InventorypowerSupplyName')]
        [Parameter (ParameterSetName = 'InventorypowerSupplySN')]
        [Switch]$ShowPowerSupply,

        # [Parameter (ParameterSetName = 'InventoryprocessorName')]
        [Parameter (ParameterSetName = 'InventoryprocessorSN')]
        [Switch]$ShowProcessor,

        # [Parameter (ParameterSetName = 'InventorysmartStorageName')]
        # [Parameter (ParameterSetName = 'InventorysmartStorageSN')]
        # [Switch]$ShowSmartStorage,

        # [Parameter (ParameterSetName = 'InventorysmartUpdateToolName')]
        [Parameter (ParameterSetName = 'InventorysmartUpdateToolSN')]
        [Switch]$ShowSmartUpdateTool,

        # [Parameter (ParameterSetName = 'InventorysoftwareName')]
        [Parameter (ParameterSetName = 'InventorysoftwareSN')]
        [Switch]$ShowSoftware,
        
        # [Parameter (ParameterSetName = 'InventorystorageName')]
        [Parameter (ParameterSetName = 'InventorystorageSN')]
        [Switch]$ShowStorageController,

        [Switch]$WhatIf
        
    ) 

    Begin {
  
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

    
    }
      
      
    Process {
      
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose  

        # Get server ID using SN   
        # if ($SerialNumber) {
        #     $Uri = (Get-COMServersUri) + "?filter=hardware/serialNumber eq '$SerialNumber'"
                
        # }
        # elseif ($Name) {
        #     $Uri = (Get-COMServersUri) + "?filter=host/hostname eq '$Name'"     
                
        # }

        # $Uri = (Get-COMServersUri) + "?filter=name eq '$Name'"   # Filter that supports only serial numbers
        $Uri = (Get-COMServersUri) + "?filter=host/hostname eq '$Name' or name eq '$Name'"   # Filter that supports both serial numbers and server names

        try {
            [Array]$Server = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region

        
            if ($Null -eq $Server) { 
            
                Return
        
            }
            else {
                
                $ServerID = $Server.id
                
                # if ($SerialNumber) {
                    
                #     "[{0}] ID found for server serial number '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, $ServerID | Write-Verbose
                    
                    
                # }
                # elseif ($Name) {
                    
                "[{0}] ID found for server name '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $ServerID | Write-Verbose
                    
                # }
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
           
        }
       

     
        # Requests using $ServerID
        $Uri = (Get-COMServersUri) + "/" + $ServerID + "/inventory"

        try {
            [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

            $FullInventoryAlreadyRun = if ($CollectionList.lastFullInventoryCollectionAt) { $True }

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
                   
        }



        $ReturnData = @()
               
        # Format response with Repackage Object With Type
        if ($Null -ne $CollectionList) {      
            
            # Add region, servername and serialNumber (only serial is provided)
            try {
                $_ServerName = Get-HPECOMServer -Region $Region -Name $CollectionList.serial                        
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
            
            $CollectionList | Add-Member -type NoteProperty -name region -value $Region
            $CollectionList | Add-Member -type NoteProperty -name serialNumber -value $CollectionList.serial  
            $CollectionList | Add-Member -Type NoteProperty -Name serverName -Value $_ServerName.name


            if ($Showsoftware) {
                $ReturnData = $CollectionList.software.data 
                if ($Null -ne $ReturnData) {
                    $ReturnData | Add-Member -Type NoteProperty -Name serverName -Value $_ServerName.name
                }
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $ReturnData -ObjectName "COM.Servers.Inventory.Software"    

            }
    
            elseif ($Showfirmware) {
                $ReturnData = $CollectionList.firmware.data 
                if ($Null -ne $ReturnData) {
                    $ReturnData | Add-Member -Type NoteProperty -Name serverName -Value $_ServerName.name
                }
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $ReturnData -ObjectName "COM.Servers.Inventory.Software"    

            }

            elseif ($ShowStorageController) {
                $ReturnData = $CollectionList.storage.data 
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $ReturnData -ObjectName "COM.Servers.Inventory.Storage"    

            }

            elseif ($ShowsmartStorage) {
                $ReturnData = $CollectionList.smartStorage.data 
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $ReturnData -ObjectName "COM.Servers.Inventory.Storage"    

            }

            elseif ($Showdevice) {
                $ReturnData = $CollectionList.device.data 
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $ReturnData -ObjectName "COM.Servers.Inventory.Device"    

            }

            elseif ($ShowSmartUpdateTool) {
                $ReturnData = $CollectionList.smartUpdateToolInventory.data 
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $ReturnData -ObjectName "COM.Servers.Inventory.smartUpdateToolInventory"    

            }

            elseif ($Showchassis) {
                $ReturnData = $CollectionList.chassis.data 
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $ReturnData -ObjectName "COM.Servers.Inventory.Chassis"    

            }

            elseif ($Showmemory) {
                $ReturnData = $CollectionList.memory.data 
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $ReturnData -ObjectName "COM.Servers.Inventory.Memory"    

            }

            elseif ($ShownetworkAdapter) {
                $ReturnData = $CollectionList.networkAdapter.data 
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $ReturnData -ObjectName "COM.Servers.Inventory.NetworkAdapter"    

            }

            elseif ($Showprocessor) {
                $ReturnData = $CollectionList.processor.data 
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $ReturnData -ObjectName "COM.Servers.Inventory.Processor"    

            }

            elseif ($ShowpowerSupply) {
                $ReturnData = $CollectionList.powerSupply.data 
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $ReturnData -ObjectName "COM.Servers.Inventory.PowerSupply"    

            }

            elseif ($ShowFans) {
                $ReturnData = $CollectionList.thermal.data 
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $ReturnData -ObjectName "COM.Servers.Inventory.Thermal"    

            }
            else {
           
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Servers.Inventory"    
                
            }

            if ($Null -eq $ReturnData) {

                Write-Verbose ($PSCmdlet.MyInvocation.BoundParameters.Keys | Where-Object { $_ -like 'Show*' } )

                if ($ShowSoftware) {
                    $ErrorMessage = "Unable to discover HPE drivers and software inventory at this time. Ensure the server has a running operating system with the HPE Agentless Management Service (AMS) installed and running."

                }
                elseif ($ShowSmartUpdateTool) {
                    $ErrorMessage = "Unable to retrieve Smart Update Tool inventory at this time. Ensure Smart Update Tool (SUT) is installed on the server operating system."
                }
                elseif (-not $FullInventoryAlreadyRun) {
                    $ErrorMessage = "Unable to retrieve {0} inventory data. The inventory has not been collected yet or the data is not available. Run 'New-HPECOMServerInventory' to collect the full server inventory, then try again." -f (($PSCmdlet.MyInvocation.BoundParameters.Keys | Where-Object { $_ -like 'Show*' } ) -replace "Show")
                }
                else {
                    $ErrorMessage = "Unable to retrieve {0} - Inventory is not available or collection is not supported for the server type." -f (($PSCmdlet.MyInvocation.BoundParameters.Keys | Where-Object { $_ -like 'Show*' } ) -replace "Show")
                }
                
                if ($ErrorMessage) {
                    Write-Warning $ErrorMessage
                }

            }
            else {
                
                return $ReturnData 
            }
        }
    }
}

#Region 'New-HPECOMSustainabilityReport' is deprecated - Metrics data collection is now enabled by default and controlled by 'Enable-HPECOMMetricsConfiguration'
# function New-HPECOMSustainabilityReport {
#     <#
#     .SYNOPSIS
#     Generates a carbon footprint report.
    
#     .DESCRIPTION   
#     This cmdlet generates a Carbon Footprint Report for all managed servers. It also provides options to schedule the execution at a specific time and to set recurring schedules.
    
#     .PARAMETER Region     
#     Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
#     This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

#     Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
#     .PARAMETER ScheduleTime
#     Specifies the date and time when the carbon footprint report creation should be executed. 
#     This parameter accepts a DateTime object or a string representation of a date and time. 
#     If not specified, the operation will be executed immediately.

#     Examples for setting the date and time using `Get-Date`:
#     - (Get-Date).AddMonths(6)
#     - (Get-Date).AddDays(15)
#     - (Get-Date).AddHours(3)
#     Example for using a specific date string:
#     - "2024-05-20 08:00:00"

#     .PARAMETER Interval
#     Specifies the interval at which the carbon footprint report creation should be repeated. This parameter accepts a TimeSpan object or a string representation of a time interval. 
#     If not specified, the carbon footprint report creation will not be repeated.

#     This parameter supports common ISO 8601 period durations such as:
#     - P1D (1 Day)
#     - P1W (1 Week)
#     - P1M (1 Month)
#     - P1Y (1 Year)
    
#     The accepted formats include periods (P) referencing days, weeks, months, years but not time (T) designations that reference hours, minutes, and seconds.

#     A valid interval must be greater than 15 minutes (PT15M) and less than 1 year (P1Y).

#     .PARAMETER Async
#     Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties). By default, the Cmdlet will wait for the job to complete.

#     .PARAMETER WhatIf
#     Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

#     .EXAMPLE
#     New-HPECOMSustainabilityReport -Region us-west 
    
#     Generates a carbon footprint report in the western US region for all managed servers.

#     .EXAMPLE
#     New-HPECOMSustainabilityReport -Region eu-central -ScheduleTime (get-Date).addminutes(10) 

#     Schedules the execution of a sustainability report in the `eu-central` region starting 10 minutes from now. 

#     .EXAMPLE
#     New-HPECOMSustainabilityReport -Region eu-central -ScheduleTime (get-Date).addhours(6) -Interval P1M

#     Schedules a monthly execution of a sustainability report in the `eu-central` region. The first execution will occur six hours from the current time.

#     .INPUTS
#     You cannot pipe objects to this cmdlet.

#     .OUTPUTS
#     HPEGreenLake.COM.Jobs.Status [System.Management.Automation.PSCustomObject]

#         - When the job completes, the returned object contains detailed job status information, including:
#             - `state`: The final state of the job, such as:
#                 - COMPLETE (job finished successfully)
#                 - ERROR (job failed)
#                 - STALLED (job is not making progress)
#                 - PENDING (job is queued and waiting to start)
#                 - RUNNING (job is currently in progress)
#             - `resultCode`: The result of the job execution, such as:
#                 - SUCCESS (operation completed successfully)
#                 - FAILURE (operation failed)
#                 - null (job is still running or in a non-terminal state)
#             - Additional properties may include:
#                 - `associatedResource`: The resource associated with the job
#                 - `date`: The date and time when the job was created
#                 - `jobUri`: The URI of the job resource
#                 - `duration`: The time taken for the job to complete
#                 - `message`: Any informational or error messages returned by the job
#                 - `details`: The full job resource object with all available metadata

#         - If the `-Async` switch is used, the cmdlet returns the job resource immediately, allowing you to monitor its progress using the `state` and `resultCode` properties, or by passing the job object to `Wait-HPECOMJobComplete` for blocking/waiting behavior.

#     HPEGreenLake.COM.Schedules [System.Management.Automation.PSCustomObject]

#         - The schedule job object that includes the schedule details when `-ScheduleTime` is used.

#     #>

#     [CmdletBinding(DefaultParameterSetName = 'SerialNumber')]
#     Param
#     (
#         [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
#         [ValidateScript({
#                 if (($_ -in $Global:HPECOMRegions.region)) {
#                     $true
#                 }
#                 else {
#                     Throw "The COM region '$_' is not provisioned in this workspace! Please specify a valid region code (e.g., 'us-west', 'eu-central'). `nYou can retrieve the region code using: Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned. `nYou can also use the Tab key for auto-completion to see the list of provisioned region codes."
#                 }
#             })]
#         [ArgumentCompleter({
#                 param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
#                 # Filter region based on $Global:HPECOMRegions global variable and create completions
#                 $Global:HPECOMRegions.region | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
#                     [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
#                 }
#             })]
#         [String]$Region,      

#         [Parameter (Mandatory, ParameterSetName = 'Scheduled')]
#         [ValidateScript({
#                 if ($_ -ge (Get-Date) -and $_ -le (Get-Date).AddYears(1)) {
#                     $true
#                 }
#                 else {
#                     throw "The ScheduleTime must be within one year from the current date."
#                 }
#             })]
#         [DateTime]$ScheduleTime,

#         [ValidateScript({
#             # Validate ISO 8601 duration format
#             if ($_ -notmatch '^P(?!$)(\d+Y)?(\d+M)?(\d+W)?(\d+D)?(T(\d+H)?(\d+M)?(\d+S)?)?$') {
#                 throw "Invalid duration format. Please use an ISO 8601 period interval (e.g., P1D, P1W, P1M, P1Y, PT1H, PT15M)"
#             }

#             # Extract duration parts
#             $years   = [int]($matches[1] -replace '\D', '')  # Y
#             $months  = [int]($matches[2] -replace '\D', '')  # M (before T)
#             $weeks   = [int]($matches[3] -replace '\D', '')  # W
#             $days    = [int]($matches[4] -replace '\D', '')  # D
#             $hours   = [int]($matches[6] -replace '\D', '')  # H
#             $minutes = [int]($matches[7] -replace '\D', '')  # M (after T)
#             $seconds = [int]($matches[8] -replace '\D', '')  # S

#             # Calculate total duration in seconds (approximate months/years)
#             $totalSeconds = 0
#             if ($years)   { $totalSeconds += $years * 365 * 24 * 3600 }
#             if ($months)  { $totalSeconds += $months * 30 * 24 * 3600 }
#             if ($weeks)   { $totalSeconds += $weeks * 7 * 24 * 3600 }
#             if ($days)    { $totalSeconds += $days * 24 * 3600 }
#             if ($hours)   { $totalSeconds += $hours * 3600 }
#             if ($minutes) { $totalSeconds += $minutes * 60 }
#             if ($seconds) { $totalSeconds += $seconds }

#             $minSeconds = 15 * 60
#             $maxSeconds = 365 * 24 * 3600  # 1 year

#             if ($totalSeconds -lt $minSeconds) {
#                 throw "The interval must be greater than 15 minutes (PT15M)."
#             }
#             if ($totalSeconds -gt $maxSeconds) {
#                 throw "The interval must be less than 1 year (P1Y)."
#             }
#             return $true
#         })]
#         [Parameter (ParameterSetName = 'ScheduleSerialNumber')]
#         [String]$Interval,    
        
#         [Parameter (ParameterSetName = 'Async')]
#         [switch]$Async,
        
#         [switch]$WhatIf

#     )



#     Begin {

        
#         $Caller = (Get-PSCallStack)[1].Command

#         "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

#         $_JobTemplateName = 'DataRoundupReportOrchestrator'

#         $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

#         $Uri = Get-COMJobsUri
#         $SustainabilityReportStatus = [System.Collections.ArrayList]::new()

        
#     }

#     Process {

#         "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

#         try {

#             $_AllServersFilter = Get-HPECOMFilter -Region $Region -Name "All servers"
#             $_ResourceUri = $_AllServersFilter.resourceUri
#             $_ResourceId = $_AllServersFilter.Id
#             $_ResourceType = $_AllServersFilter.type           
            
#             "[{0}] Resource is 'FILTERS' type: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_ResourceUri | Write-Verbose

#         }
#         catch {
#             $PSCmdlet.ThrowTerminatingError($_)
#         }
        
#         if (-not $_ResourceUri) {

#             # Must return a message if not found
#             $ErrorMessage = "Filter 'All servers' cannot be found in the Compute Ops Management instance!" 
#             $ErrorRecord = New-ErrorRecord FilterNotFoundInCOM ObjectNotFound -TargetObject 'Filter' -Message $ErrorMessage 
#             $PSCmdlet.ThrowTerminatingError($ErrorRecord)

#         }
#         else {

#             $data = @{
#                 reportType = "CARBON_FOOTPRINT"

#             }
             
#             if ($ScheduleTime) {

#                 $Uri = Get-COMSchedulesUri

#                 $_Body = @{
#                     jobTemplateUri = "/api/compute/v1/job-templates/" + $JobTemplateId
#                     resourceUri    = $_ResourceUri
#                     data           = $data
#                 }      

#                 $Operation = @{
#                     type   = "REST"
#                     method = "POST"
#                     uri    = "/api/compute/v1/jobs"
#                     body   = $_Body

#                 }

#                 $randomNumber = Get-Random -Minimum 000000 -Maximum 999999

#                 $Name = "All_Servers_SustainabilityReport_Schedule_$($randomNumber)"
#                 $Description = "Scheduled task to run a sustainability report for all servers"

#                 if ($Interval) {
                    
#                     $Schedule = @{
#                         startAt  = $ScheduleTime.ToString("o")  # Convert to ISO 8601 format as $ScheduleTime alone is converted by PS5.1 to '/Date(...)\/ notation'
#                         interval = $Interval
#                     }
#                 }
#                 else {

#                     $Schedule = @{
#                         startAt = $ScheduleTime.ToString("o")  # Convert to ISO 8601 format as $ScheduleTime alone is converted by PS5.1 to '/Date(...)\/ notation'
#                         # interval = $Null
#                     }
#                 }

#                 $Payload = @{
#                     name                  = $Name
#                     description           = $Description
#                     associatedResourceUri = $_ResourceUri
#                     purpose               = "SUSTAINABILITY_REPORT"
#                     schedule              = $Schedule
#                     operation             = $Operation

#                 }

#             }
#             else {

#                 $payload = @{
#                     jobTemplate = $JobTemplateId
#                     resourceId   = $_ResourceId
#                     resourceType = $_ResourceType
#                     jobParams = $data
#                 }
#             }

#             $payload = ConvertTo-Json $payload -Depth 10 

#             try {
#                 $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

#                 # Add region to object
#                 $_resp | Add-Member -type NoteProperty -name region -value $Region

#                 if ($ScheduleTime) {

#                     if (-not $WhatIf) {
    
#                         $ReturnData = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Schedules"

#                         "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

#                     }

#                 }
#                 else {

#                     if (-not $WhatIf -and -not $Async) {
            
#                         "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri) | Write-Verbose
            
#                         $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri
    
#                         "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
    
#                     }
#                     else {

#                         $ReturnData = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs" 

#                     }
                    
#                 }

#             }
#             catch {

#                 if (-not $WhatIf) {

#                     $PSCmdlet.ThrowTerminatingError($_)

#                 }
#             }  

#             if ($ScheduleTime) {

#                 if (-not $WhatIf ) {
        
#                     Return $ReturnData
                
#                 }
#             }
#         }

#         if (-not $ScheduleTime) {

#             [void] $SustainabilityReportStatus.add($_resp)
#         }


#     }

#     End {

#         if (-not $ScheduleTime -and -not $WhatIf ) {
            
#             Return $SustainabilityReportStatus
        
#         }

#     }
# }
#EndRegion

Function Get-HPECOMSustainabilityInsights {
    <#
    .SYNOPSIS
    Retrieves sustainability insights for servers managed by HPE Compute Ops Management.

    .DESCRIPTION
    This cmdlet retrieves sustainability insights for servers managed by Compute Ops Management (COM) in the specified region.
    It provides detailed information on energy consumption, CO2 emissions, and associated costs, helping organizations monitor 
    and manage the environmental impact of their server infrastructure.

    By default, the cmdlet returns aggregated estimated values (total energy consumption, CO2 emissions, and energy cost) 
    for all managed servers in the specified region. Historical data covers the past 90 days, with projections extending 
    180 days into the future.

    Users can:
    - Filter results to view data for individual servers by specifying a server's serial number or by piping server objects 
      from the `Get-HPECOMServer` cmdlet
    - Customize the time range using the `LookbackDays` and `ProjectionDays` parameters
    - View granular metrics per server using switches like `-Co2Emissions`, `-EnergyConsumption`, or `-EnergyCost`
    - View aggregated totals using switches like `-Co2EmissionsTotal`, `-EnergyConsumptionTotal`, or `-EnergyCostTotal`

    IMPORTANT: Metrics data collection must be enabled in your COM instance to retrieve sustainability insights. 
    Metrics collection is enabled by default. Use `Get-HPECOMMetricsConfiguration` to verify the current status 
    and `Enable-HPECOMMetricsConfiguration` to enable it if needed.

    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in your workspace (e.g., 'us-west', 'eu-central').
    This mandatory parameter can be retrieved using:
    - 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned'
    - 'Get-HPEGLRegion -ShowProvisioned'

    Tab completion is supported for this parameter, displaying a list of provisioned region codes in your workspace.
    
    .PARAMETER Name
    Optional parameter to filter insights for a specific server by its name (hostname) or serial number.
    This parameter accepts values from the pipeline and can be used with piped server objects from `Get-HPECOMServer`.
    You can specify either the server's hostname (e.g., "pveauto") or its serial number (e.g., "CZJ3100GD9").
    The `-SerialNumber` alias is available for backward compatibility.
    
    .PARAMETER Co2Emissions
    Switch parameter that displays detailed carbon emissions data for each server, including collected values, 
    projected values, and totals. Results include metadata such as server model, generation, processor, and location.
    
    .PARAMETER Co2EmissionsTotal
    Switch parameter that displays aggregated carbon emissions data for all servers in the region, 
    including total collected, projected, and estimated emissions.

    .PARAMETER EnergyConsumption
    Switch parameter that displays detailed energy consumption data (in kWh) for each server, including collected values, 
    projected values, and totals. Results include metadata such as server model, generation, processor, and location.
    
    .PARAMETER EnergyConsumptionTotal
    Switch parameter that displays aggregated energy consumption data (in kWh) for all servers in the region, 
    including total collected, projected, and estimated consumption.
        
    .PARAMETER EnergyCost
    Switch parameter that displays detailed energy cost data for each server, including collected costs, 
    projected costs, and totals. Results include metadata such as server model, generation, processor, and location.

    .PARAMETER EnergyCostTotal
    Switch parameter that displays aggregated energy cost data for all servers in the region, 
    including total collected, projected, and estimated costs.

    .PARAMETER LookbackDays
    Specifies the number of historical days to include in the insights. 
    - Default: 90 days (3 months)
    - Valid range: 1 to 180 days
    - Use this parameter to analyze historical trends over a custom time period

    .PARAMETER ProjectionDays
    Specifies the number of future days to project energy consumption, CO2 emissions, and costs.
    - Default: 180 days (6 months)
    - Valid range: 1 to 180 days
    - Use this parameter to forecast future sustainability metrics based on historical data

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. 
    This option is useful for understanding the underlying REST API operations and for troubleshooting.

    .EXAMPLE
    Get-HPECOMSustainabilityInsights -Region us-west 

    Returns the total estimated sustainability insights for all servers in the 'us-west' region, 
    including aggregated energy consumption, CO2 emissions, and energy cost. 
    Data covers the past 90 days with projections for the next 180 days.

    .EXAMPLE
    Get-HPECOMSustainabilityInsights -Region eu-central -EnergyConsumptionTotal 

    Returns the total estimated energy consumption (in kWh) for all servers in the 'eu-central' region, 
    including collected data from the past 90 days and projected consumption for the next 180 days.
    
    .EXAMPLE
    Get-HPECOMSustainabilityInsights -Region eu-central -EnergyConsumptionTotal -LookbackDays 7 -ProjectionDays 100

    Returns the total estimated energy consumption for all servers in the 'eu-central' region, 
    with data from the past 7 days and projections for the next 100 days.

    .EXAMPLE
    Get-HPECOMSustainabilityInsights -Region eu-central -EnergyCostTotal

    Returns the total estimated energy cost for all servers in the 'eu-central' region, 
    including data from the past 90 days and cost projections for the next 180 days.

    .EXAMPLE
    Get-HPECOMSustainabilityInsights -Region eu-central -Co2EmissionsTotal

    Returns the total estimated CO2 emissions for all servers in the 'eu-central' region, 
    including data from the past 90 days and emission projections for the next 180 days.

    .EXAMPLE
    Get-HPECOMSustainabilityInsights -Region eu-central -Co2Emissions -LookbackDays 7 -ProjectionDays 100

    Returns detailed CO2 emissions data for each server in the 'eu-central' region, 
    including values from the past 7 days and projections for the next 100 days.
    Results include server metadata (model, generation, processor, location).
  
    .EXAMPLE
    Get-HPECOMSustainabilityInsights -Region eu-central -EnergyCost

    Returns detailed energy cost data for each server in the 'eu-central' region, 
    including collected costs from the past 90 days and projected costs for the next 180 days.
    Results include server metadata (model, generation, processor, location).

    .EXAMPLE
    Get-HPECOMSustainabilityInsights -Region eu-central -Name 123456789 -EnergyCost

    Returns the estimated energy cost data for the server with serial number '123456789' in the 'eu-central' region, 
    including data from the past 90 days and cost projections for the next 180 days.

    .EXAMPLE
    Get-HPECOMSustainabilityInsights -Region eu-central -Name 123456789 -Co2Emissions -LookbackDays 7 -ProjectionDays 100

    Returns the estimated CO2 emissions data for the server with serial number '123456789' in the 'eu-central' region, 
    including emissions from the past 7 days and projections for the next 100 days.

    .EXAMPLE
    Get-HPECOMSustainabilityInsights -Region eu-central -Name "pveauto" -EnergyCost

    Returns the estimated energy cost data for the server with hostname 'pveauto' in the 'eu-central' region.
    The -SerialNumber alias is available for backward compatibility when filtering by serial number.

    .EXAMPLE
    Get-HPECOMServer -Region us-west -ConnectionType Direct -PowerState ON | Select-Object -First 2 | Get-HPECOMSustainabilityInsights -Co2Emissions 

    Retrieves the first two directly managed, powered-on servers from the 'us-west' region and displays 
    their CO2 emissions insights, including collected and projected values.

    .EXAMPLE
    '123456789', '987654321' | Get-HPECOMSustainabilityInsights -Region us-west -EnergyCost

    Returns the estimated energy cost data for servers with serial numbers '123456789' and '987654321' 
    in the 'us-west' region, including data from the past 90 days and cost projections for the next 180 days.

    .INPUTS
    System.String, System.String[]
        A single string or an array of strings representing server names (hostnames) or serial numbers.
        The cmdlet accepts both formats and will match against either the serialNumber or name field.
    
    System.Collections.ArrayList
        A collection of server objects retrieved using 'Get-HPECOMServer'.

    .OUTPUTS
    HPEGreenLake.COM.Reports.SustainabilityData [System.Management.Automation.PSCustomObject]
        Returned by default (no data-type switch). Contains aggregated sustainability totals across CO2 emissions, energy consumption, and energy costs.

    HPEGreenLake.COM.Reports.SustainabilityData.Co2Emissions [System.Management.Automation.PSCustomObject]
        Returned when -Co2Emissions is used. Per-server CO2 emissions data.

    HPEGreenLake.COM.Reports.SustainabilityData.Co2Emissions.AllServers [System.Management.Automation.PSCustomObject]
        Returned when -Co2EmissionsTotal is used. Aggregated CO2 emissions data across all servers.

    HPEGreenLake.COM.Reports.SustainabilityData.EnergyConsumption [System.Management.Automation.PSCustomObject]
        Returned when -EnergyConsumption is used. Per-server energy consumption data.

    HPEGreenLake.COM.Reports.SustainabilityData.EnergyConsumption.AllServers [System.Management.Automation.PSCustomObject]
        Returned when -EnergyConsumptionTotal is used. Aggregated energy consumption data across all servers.

    HPEGreenLake.COM.Reports.SustainabilityData.EnergyCost [System.Management.Automation.PSCustomObject]
        Returned when -EnergyCost is used. Per-server energy cost data.

    HPEGreenLake.COM.Reports.SustainabilityData.EnergyCost.AllServers [System.Management.Automation.PSCustomObject]
        Returned when -EnergyCostTotal is used. Aggregated energy cost data across all servers.

    .NOTES
    - At least one day of metrics data collection is required to generate sustainability insights
    - Historical and projection periods can be customized using `-LookbackDays` and `-ProjectionDays`

    .LINK
    Get-HPECOMServer
    Get-HPECOMMetricsConfiguration
    Enable-HPECOMMetricsConfiguration
    Get-HPEGLService
    Get-HPEGLRegion
   #>
    [CmdletBinding(DefaultParameterSetName = "Region")]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Region')]
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Co2Emissions')]
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'EnergyConsumption')]
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'EnergyCost')]
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Co2EmissionsTotal')]
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'EnergyConsumptionTotal')]
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'EnergyCostTotal')]
        [ValidateScript({
                # First check if there's an active session with COM regions
                if (-not $Global:HPEGreenLakeSession) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use the cmdlets of the HPECOMCmdlets module."
                }
                if (-not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "Compute Ops Management is not provisioned in this workspace!`n`nCAUSE:`nNo provisioned Compute Ops Management region was found.`n`nACTION REQUIRED:`nVerify the Compute Ops Management service is provisioned using:`n    Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned`n`nIf not provisioned, you can provision it using 'New-HPEGLService'."
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
    

        [Parameter (ParameterSetName = 'Co2Emissions', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter (ParameterSetName = 'EnergyConsumption', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter (ParameterSetName = 'EnergyCost', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [alias('SerialNumber', 'serial', 'ServerName')]
        [String]$Name,

        [Parameter (Mandatory, ParameterSetName = 'Co2Emissions')]
        [Switch]$Co2Emissions,

        [Parameter (Mandatory, ParameterSetName = 'Co2EmissionsTotal')]
        [Switch]$Co2EmissionsTotal,

        [Parameter (Mandatory, ParameterSetName = 'EnergyConsumption')]
        [Switch]$EnergyConsumption,

        [Parameter (Mandatory, ParameterSetName = 'EnergyConsumptionTotal')]
        [Switch]$EnergyConsumptionTotal,

        [Parameter (Mandatory, ParameterSetName = 'EnergyCost')]
        [Switch]$EnergyCost,

        [Parameter (Mandatory, ParameterSetName = 'EnergyCostTotal')]
        [Switch]$EnergyCostTotal,

        [Parameter (ParameterSetName = 'Region')]
        [Parameter (ParameterSetName = 'Co2Emissions')]
        [Parameter (ParameterSetName = 'EnergyConsumption')]
        [Parameter (ParameterSetName = 'EnergyCost')]
        [Parameter (ParameterSetName = 'Co2EmissionsTotal')]
        [Parameter (ParameterSetName = 'EnergyConsumptionTotal')]
        [Parameter (ParameterSetName = 'EnergyCostTotal')]
        [ValidateRange(1, 180)]
        $LookbackDays = 90,

        [Parameter (ParameterSetName = 'Region')]
        [Parameter (ParameterSetName = 'Co2Emissions')]
        [Parameter (ParameterSetName = 'EnergyConsumption')]
        [Parameter (ParameterSetName = 'EnergyCost')]
        [Parameter (ParameterSetName = 'Co2EmissionsTotal')]
        [Parameter (ParameterSetName = 'EnergyConsumptionTotal')]
        [Parameter (ParameterSetName = 'EnergyCostTotal')]
        [ValidateRange(1, 180)]
        $ProjectionDays = 180,

        [Switch]$WhatIf
       
    ) 

    Begin {
  
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $ServerNamesList = [System.Collections.ArrayList]::new() 
    }      
      
    Process {
      
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        if ($Name) {
            [void]$ServerNamesList.Add($Name)
        }

    }

    End {

        $ProjectionDate = (Get-Date).AddDays($ProjectionDays).ToString("yyyy-MM-dd")
        $LookbackDate = (Get-Date).AddDays(-$LookbackDays).ToString("yyyy-MM-dd")

        # Use end-date format (projection-days is deprecated) - start-date = today - lookback, end-date = today + projection
        $StartDate = (Get-Date).AddDays(-$LookbackDays).ToString("yyyy-MM-dd")
        $EndDate = (Get-Date).AddDays($ProjectionDays).ToString("yyyy-MM-dd")
        $Uri = (Get-COMEnergyByEntityUri) + "?start-date=$StartDate&end-date=$EndDate"
        
        # If specific server(s) requested, add resource-uri parameter for single server queries
        if ($ServerNamesList.Count -eq 1) {
            '[{0}] Single server requested: {1}' -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServerNamesList[0] | Write-Verbose
            
            try {
                $Server = Get-HPECOMServer -Region $Region -Name $ServerNamesList[0]
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
                
            if ($Server) {
                $ResourceURI = $server.resourceUri
                $EncodedResourceURI = [uri]::EscapeDataString($ResourceURI)
                $Uri += "&resource-uri=$EncodedResourceURI"
                "[{0}] Added resource-uri parameter for server: {1} (Resource URI: {2})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServerNamesList[0], $ResourceURI | Write-Verbose
            }
            else {
                # Server not found - handle based on WhatIf parameter
                "[{0}] Server '{1}' not found in region '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServerNamesList[0], $Region | Write-Verbose
                
                if ($WhatIf) {
                    $WarningMessage = "Server with serial number '{0}' not found in region '{1}'. Cannot display API request." -f $ServerNamesList[0], $Region
                    Write-Warning $WarningMessage
                    return
                }
                else {
                    # Get-* cmdlets return nothing silently for "not found"
                    return
                }
            }
        }
        elseif ($ServerNamesList.Count -gt 1) {
            "[{0}] Multiple servers requested - will retrieve all servers and filter results" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
        }
            
        try {
            # Use SkipPaginationParameters when resource-uri is specified (single server query)
            # This prevents automatic limit/offset addition which could interfere with resource-uri filtering
            if ($Uri -match 'resource-uri=') {
                "[{0}] Using SkipPaginationParameters for resource-uri query" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                $CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference -ReturnFullObject -SkipPaginationParameters
            }
            else {
                $CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference -ReturnFullObject
            }
            
            if ($CollectionList) {
                "[{0}] CollectionList type: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CollectionList.GetType().Name | Write-Verbose
                "[{0}] CollectionList properties: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($CollectionList.PSObject.Properties.Name | Select-Object -First 10) -join ", " | Write-Verbose
            }
            else {
                "[{0}] CollectionList is null (likely WhatIf mode)" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            }
        
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
                       
        }           
        
        # Skip processing if WhatIf was used (no actual API call made)
        if ($WhatIf) {
            return
        }
    
        $ReturnData = @()
           
        if ($Null -ne $CollectionList) {   
            
            # Extract items array when ReturnFullObject is used
            if ($CollectionList.PSObject.Properties.Name -contains 'items') {
                "[{0}] CollectionList has 'items' property, extracting items array" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                $ItemsArray = $CollectionList.items
            }
            else {
                "[{0}] CollectionList does not have 'items' property, using CollectionList directly" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                $ItemsArray = $CollectionList
            }
                
            if ($Co2Emissions) {
                    
                if ($ItemsArray -is [System.Collections.IEnumerable] -and $ItemsArray.Count -gt 0) {
                    $ItemsArray = $ItemsArray | Sort-Object name, serialNumber
                }

                Foreach ($Item in $ItemsArray) {
                    $Item | Add-Member -type NoteProperty -name ProjectionDays -value $ProjectionDays
                    $Item | Add-Member -type NoteProperty -name LookbackDays -value  $LookbackDays
                    $Item | Add-Member -type NoteProperty -name ProjectionDate -value $ProjectionDate
                    $Item | Add-Member -type NoteProperty -name LookbackDate -value  $LookbackDate
                    $Item | Add-Member -type NoteProperty -name serialNumber -value ($Item.id.split('+')[-1] ) 
                    $Item | Add-Member -type NoteProperty -name region -value $Region
                    $Item | Add-Member -type NoteProperty -name model -value $Item.entityDetails.model  
                    $Item | Add-Member -type NoteProperty -name generation -value $Item.entityDetails.generation  
                    $Item | Add-Member -type NoteProperty -name processor -value $Item.entityDetails.processor  
                    $Item | Add-Member -type NoteProperty -name location -value $Item.entityDetails.location  
                    $Item | Add-Member -type NoteProperty -name CollectedCarbonEmissions -value $Item.co2eKg.collected 
                    $Item | Add-Member -type NoteProperty -name ProjectedCarbonEmissions -value $Item.co2eKg.projected
                    $Item | Add-Member -type NoteProperty -name TotalCarbonEmissions -value $Item.co2eKg.total 
                } 
                    
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $ItemsArray -ObjectName "COM.Reports.SustainabilityData.Co2Emissions"    

            }
            elseif ($Co2EmissionsTotal) {
                    
                Foreach ($Item in $CollectionList) {
                    $Item | Add-Member -type NoteProperty -name ProjectionDays -value  $ProjectionDays
                    $Item | Add-Member -type NoteProperty -name LookbackDays -value  $LookbackDays
                    $Item | Add-Member -type NoteProperty -name ProjectionDate -value $ProjectionDate
                    $Item | Add-Member -type NoteProperty -name LookbackDate -value  $LookbackDate
                    $Item | Add-Member -type NoteProperty -name region -value $Region
                    $Item | Add-Member -type NoteProperty -name TotalEstimatedCarbonEmissions -value $Item.co2eKgSums.total 
                    $Item | Add-Member -type NoteProperty -name TotalCollectedCarbonEmissions -value $Item.co2eKgSums.collected 
                    $Item | Add-Member -type NoteProperty -name TotalProjectedCarbonEmissions -value $Item.co2eKgSums.projected
                }

                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Reports.SustainabilityData.Co2Emissions.AllServers"    

            }  
            elseif ($EnergyConsumption) {

                if ($ItemsArray -is [System.Collections.IEnumerable] -and $ItemsArray.Count -gt 0) {
                    $ItemsArray = $ItemsArray | Sort-Object name, serialNumber
                }

                Foreach ($Item in $ItemsArray) {
                    $Item | Add-Member -type NoteProperty -name ProjectionDays -value  $ProjectionDays
                    $Item | Add-Member -type NoteProperty -name LookbackDays -value  $LookbackDays      
                    $Item | Add-Member -type NoteProperty -name ProjectionDate -value $ProjectionDate
                    $Item | Add-Member -type NoteProperty -name LookbackDate -value  $LookbackDate              
                    $Item | Add-Member -type NoteProperty -name serialNumber -value ($Item.id.split('+')[-1] ) 
                    $Item | Add-Member -type NoteProperty -name region -value $Region
                    $Item | Add-Member -type NoteProperty -name model -value $Item.entityDetails.model  
                    $Item | Add-Member -type NoteProperty -name generation -value $Item.entityDetails.generation  
                    $Item | Add-Member -type NoteProperty -name processor -value $Item.entityDetails.processor  
                    $Item | Add-Member -type NoteProperty -name location -value $Item.entityDetails.location  
                    $Item | Add-Member -type NoteProperty -name CollectedEnergyConsumption -value $Item.kwh.collected 
                    $Item | Add-Member -type NoteProperty -name ProjectedEnergyConsumption -value $Item.kwh.projected
                    $Item | Add-Member -type NoteProperty -name TotalEnergyConsumption -value $Item.kwh.total 
                } 
                    

                $ReturnData = Invoke-RepackageObjectWithType -RawObject $ItemsArray -ObjectName "COM.Reports.SustainabilityData.EnergyConsumption"    

            }
            elseif ($EnergyConsumptionTotal) {

                Foreach ($Item in $CollectionList) {
                    $Item | Add-Member -type NoteProperty -name ProjectionDays -value  $ProjectionDays
                    $Item | Add-Member -type NoteProperty -name LookbackDays -value  $LookbackDays       
                    $Item | Add-Member -type NoteProperty -name ProjectionDate -value $ProjectionDate
                    $Item | Add-Member -type NoteProperty -name LookbackDate -value  $LookbackDate             
                    $Item | Add-Member -type NoteProperty -name region -value $Region
                    $Item | Add-Member -type NoteProperty -name TotalEstimatedEnergyConsumption -value $Item.kwhSums.total 
                    $Item | Add-Member -type NoteProperty -name TotalCollectedEnergyConsumption -value $Item.kwhSums.collected 
                    $Item | Add-Member -type NoteProperty -name TotalProjectedEnergyConsumption -value $Item.kwhSums.projected
                }

                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Reports.SustainabilityData.EnergyConsumption.AllServers"    

            }
            elseif ($EnergyCost) {

                        
                if ($ItemsArray -is [System.Collections.IEnumerable] -and $ItemsArray.Count -gt 0) {
                    $ItemsArray = $ItemsArray | Sort-Object name, serialNumber
                }

                Foreach ($Item in $ItemsArray) {
                    $Item | Add-Member -type NoteProperty -name ProjectionDays -value  $ProjectionDays
                    $Item | Add-Member -type NoteProperty -name LookbackDays -value  $LookbackDays        
                    $Item | Add-Member -type NoteProperty -name ProjectionDate -value $ProjectionDate
                    $Item | Add-Member -type NoteProperty -name LookbackDate -value  $LookbackDate            
                    $Item | Add-Member -type NoteProperty -name serialNumber -value ($Item.id.split('+')[-1] ) 
                    $Item | Add-Member -type NoteProperty -name region -value $Region
                    $Item | Add-Member -type NoteProperty -name model -value $Item.entityDetails.model  
                    $Item | Add-Member -type NoteProperty -name generation -value $Item.entityDetails.generation  
                    $Item | Add-Member -type NoteProperty -name processor -value $Item.entityDetails.processor  
                    $Item | Add-Member -type NoteProperty -name location -value $Item.entityDetails.location  
                    $Item | Add-Member -type NoteProperty -name CollectedEnergyCost -value $Item.cost.collected 
                    $Item | Add-Member -type NoteProperty -name ProjectedEnergyCost -value $Item.cost.projected
                    $Item | Add-Member -type NoteProperty -name TotalEnergyCost -value $Item.cost.total 
                } 
                    

                $ReturnData = Invoke-RepackageObjectWithType -RawObject $ItemsArray -ObjectName "COM.Reports.SustainabilityData.EnergyCost"    

            }
            elseif ($EnergyCostTotal) {
                        
                Foreach ($Item in $CollectionList) {
                    $Item | Add-Member -type NoteProperty -name ProjectionDays -value  $ProjectionDays
                    $Item | Add-Member -type NoteProperty -name LookbackDays -value  $LookbackDays      
                    $Item | Add-Member -type NoteProperty -name ProjectionDate -value $ProjectionDate
                    $Item | Add-Member -type NoteProperty -name LookbackDate -value  $LookbackDate              
                    $Item | Add-Member -type NoteProperty -name region -value $Region
                    $Item | Add-Member -type NoteProperty -name TotalEstimatedEnergyCost -value $Item.costSums.total 
                    $Item | Add-Member -type NoteProperty -name TotalCollectedEnergyCost -value $Item.costSums.collected 
                    $Item | Add-Member -type NoteProperty -name TotalProjectedEnergyCost -value $Item.costSums.projected
                }

                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Reports.SustainabilityData.EnergyCost.AllServers"      

            }
            else {
   
                Foreach ($Item in $CollectionList) {
                    $Item | Add-Member -type NoteProperty -name ProjectionDays -value  $ProjectionDays
                    $Item | Add-Member -type NoteProperty -name LookbackDays -value  $LookbackDays      
                    $Item | Add-Member -type NoteProperty -name ProjectionDate -value $ProjectionDate
                    $Item | Add-Member -type NoteProperty -name LookbackDate -value  $LookbackDate              
                    $Item | Add-Member -type NoteProperty -name region -value $Region
                    $Item | Add-Member -type NoteProperty -name TotalEstimatedEnergyCost -value $Item.costSums.total 
                    $Item | Add-Member -type NoteProperty -name TotalEstimatedEnergyConsumption -value $Item.kwhSums.total 
                    $Item | Add-Member -type NoteProperty -name TotalEstimatedCarbonEmissions -value $Item.co2eKgSums.total
                }

                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Reports.SustainabilityData"    
            }
                    
            if ( $ServerNamesList.Count -gt 0 ) {

                '[{0}] List of server names/serial numbers to process: {1}' -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServerNamesList -join ", ") | Write-Verbose

                # Only filter if we retrieved all servers (no resource-uri used)
                # When resource-uri was used for a single server, the API already filtered the results
                if ($ServerNamesList.Count -gt 1 -or (-not ($Uri -match 'resource-uri='))) {
                    $ReturnData = $ReturnData | Where-Object { ($ServerNamesList -contains $_.serialNumber) -or ($ServerNamesList -contains $_.name) }
                }
                
                if ($ReturnData.Count -eq 0) {
                    $WarningMessage = @"
No sustainability insights data were found for the specified server(s): $($ServerNamesList -join ', ')

Possible causes:
- Server(s) do not have enough metrics data collected yet (at least 1 day required)
- Metrics collection is not enabled for these server(s)
- Server serial number(s) or hostname(s) may be incorrect or server(s) not found in COM

To resolve:
1. Verify server exists: Get-HPECOMServer -Region $Region -Name <serial_number_or_hostname>
2. Check metrics configuration: Get-HPECOMMetricsConfiguration -Region $Region
3. Enable metrics if needed: Enable-HPECOMMetricsConfiguration -Region $Region
4. Wait at least 24 hours after enabling metrics for data collection to begin
"@
                    Write-Warning $WarningMessage
                }
                
                return $ReturnData
            }
            else {
                return $ReturnData                     
            }
        }
        else {
            Write-Warning "No sustainability insights data were found for the specified server(s) in the Compute Ops Management instance.`nNone of the servers could be analyzed. At least one day of metrics data collection is required.`nTo access utilization insights, ensure that metrics data collection is enabled in your Compute Ops Management instance. You can enable it using the 'Enable-HPECOMMetricsConfiguration' cmdlet and verify the current status with 'Get-HPECOMMetricsConfiguration'."
        }     
    }
}

Function Get-HPECOMServerUtilizationInsights {
    <#
    .SYNOPSIS
    Retrieve the utilization insights.

    .DESCRIPTION
    This cmdlet retrieves utilization insights for servers managed by COM in the specified region.
    It provides information on CPU, memory bus, and I/O bus usage. These insights help organizations monitor and manage the performance of their server infrastructure.
    By default, the cmdlet returns utilization insights over the past 90 days but users can customize the time range by using the `LookbackDays` parameter.
    Users can filter the results to view data for individual servers by specifying a server's name, hostname, or serial number, or by piping server objects from the `Get-HPECOMServer` cmdlet.

    Note: 
    - Server utilization insights are primarily designed for HPE ProLiant Intel-based servers
    - Some non-Intel processor architectures may not support utilization insights
    - HPE OneView managed servers do not support utilization insights
    - Metrics data collection must be enabled (it is enabled by default) to retrieve utilization insights
    - To enable metrics data collection, use `Enable-HPECOMMetricsConfiguration`
    - To verify the current metrics data collection status, use `Get-HPECOMMetricsConfiguration`

    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) from which to retrieve the utilization insights.
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER Name
    Name, hostname, or serial number of the server for which to retrieve report data.

    .PARAMETER CPUUtilization
    Optional switch parameter that can be used to display the CPU utilization data.

    .PARAMETER MemoryBusUtilization
    Optional switch parameter that can be used to display the memory bus utilization data.

    .PARAMETER IOBusUtilization
    Optional switch parameter that can be used to display the I/O bus utilization data.

    .PARAMETER CPUInterconnectUtilization
    Optional switch parameter that can be used to display the CPU interconnect utilization data.

    .PARAMETER LookbackDays
    Optional parameter that specifies the number of days to look back for data. The default value is 90 days (3 months). 
    The maximum value is 180 days (6 months).

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMServerUtilizationInsights -Region eu-central -Name 123456789 -CPUUtilization 

    Returns the CPU utilization insights for server '123456789' in the eu-central region, including data from the past 90 days.

    .EXAMPLE
    Get-HPECOMServerUtilizationInsights -Region eu-central -Name 123456789 -CPUUtilization -LookbackDays 180

    Returns the CPU utilization insights for server '123456789' in the eu-central region, including data from the past 180 days.

    .EXAMPLE
    Get-HPECOMServerUtilizationInsights -Region eu-central -Name 123456789 -MemoryBusUtilization 

    Returns the memory bus utilization insights for server '123456789' in the eu-central region, including data from the past 90 days.

    .EXAMPLE
    Get-HPECOMServerUtilizationInsights -Region eu-central -Name 123456789 -IOBusUtilization

    Returns the I/O bus utilization insights for server '123456789' in the eu-central region, including data from the past 90 days.

    .EXAMPLE
    Get-HPECOMServerUtilizationInsights -Region eu-central -Name 123456789 -CPUInterconnectUtilization

    Returns the CPU interconnect utilization insights for server '123456789' in the eu-central region, including data from the past 90 days.

    .EXAMPLE
    Get-HPECOMServer -Region us-west -ConnectionType Direct -PowerState ON | Select-Object -First 2 | Get-HPECOMServerUtilizationInsights -CPUUtilization

    This command pipes the first two servers that are directly managed and powered on in the 'us-west' region to `Get-HPECOMServerUtilizationInsights`, returning the CPU utilization insights for each server.

    .EXAMPLE
    '123456789', '987654321' | Get-HPECOMServerUtilizationInsights -Region us-west -MemoryBusUtilization

    This command returns the memory bus utilization insights for the servers '123456789' and '987654321' in the 'us-west' region, including data from the past 90 days.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's name, hostname, or serial number.

    System.Collections.ArrayList
        List of servers retrieved using 'Get-HPECOMServer'.
        
   #>
    [CmdletBinding()]
    Param( 

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript({
                # First check if there's an active session with COM regions
                if (-not $Global:HPEGreenLakeSession) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use the cmdlets of the HPECOMCmdlets module."
                }
                if (-not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "Compute Ops Management is not provisioned in this workspace!`n`nCAUSE:`nNo provisioned Compute Ops Management region was found.`n`nACTION REQUIRED:`nVerify the Compute Ops Management service is provisioned using:`n    Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned`n`nIf not provisioned, you can provision it using 'New-HPEGLService'."
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
        [Alias('SerialNumber', 'serial')]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Parameter (Mandatory, ParameterSetName = 'CPUUtilization')]
        [Switch]$CPUUtilization,

        [Parameter (Mandatory, ParameterSetName = 'MemoryBusUtilization')]
        [Switch]$MemoryBusUtilization,

        [Parameter (Mandatory, ParameterSetName = 'IOBusUtilization')]
        [Switch]$IOBusUtilization,

        [Parameter (Mandatory, ParameterSetName = 'CPUInterconnectUtilization')]
        [Switch]$CPUInterconnectUtilization,

        [ValidateRange(1, 180)]
        $LookbackDays = 90,

        [Switch]$WhatIf
       
    ) 

    Begin {
  
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $ServerNameList = [System.Collections.ArrayList]::new() 

        $ListOfReturnData = [System.Collections.ArrayList]::new() 

        $ServerExcluded = $false

    }
      
    Process {
      
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        if ($Name) {
            [void]$ServerNameList.Add($Name)
        }

    }
      
    End {

        $LookbackDate = (Get-Date).AddDays(-$LookbackDays).ToString("yyyy-MM-dd")

        if ($ServerNameList.Count -gt 0) {
            '[{0}] List of servers to process: {1}' -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServerNameList -join ", ") | Write-Verbose
        }

        foreach ($ServerName in $ServerNameList) {

            "[{0}] Processing server: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServerName | Write-Verbose

            $Server = $False

            try {
                $Server = Get-HPECOMServer -Region $Region -Name $ServerName
    
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
    
            if (-not $Server) {
                # Server not found - handle based on WhatIf parameter
                "[{0}] Server '{1}' not found in region '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServerName, $Region | Write-Verbose
                
                if ($WhatIf) {
                    $WarningMessage = "Server '{0}' not found in region '{1}'. Cannot display API request." -f $ServerName, $Region
                    Write-Warning $WarningMessage
                }
                Continue
            }
            elseif ($Server.connectionType -eq "ONEVIEW") {
                # OneView managed server - handle based on WhatIf parameter
                "[{0}] Server '{1}' is a OneView managed server and does not support utilization insights" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServerName | Write-Verbose
                
                if ($WhatIf) {
                    $WarningMessage = "Server '{0}' is a OneView managed server and does not support utilization insights. Cannot display API request." -f $ServerName
                    Write-Warning $WarningMessage
                }
                Continue
            }
            else {
                $ResourceURI = $Server.resourceUri
                $EncodedResourceURI = [uri]::EscapeDataString($ResourceURI)
            }
    
            switch ($PSCmdlet.ParameterSetName) {
                'CPUUtilization' {
                    $MetricType = 'CPU_UTILIZATION'
                }
                'MemoryBusUtilization' {
                    $MetricType = 'MEMORY_BUS_UTILIZATION'
                }
                'IOBusUtilization' {
                    $MetricType = 'IO_BUS_UTILIZATION'
                }
                'CPUInterconnectUtilization' {
                    $MetricType = 'CPU_INTERCONNECT_UTILIZATION'
                }
                Default {}
            }
    
            $Uri = (Get-COMUtilizationByEntityUri) + "?start-date=$((Get-Date).AddDays(-$LookbackDays).ToString("yyyy-MM-dd"))&end-date=$((Get-Date).ToString("yyyy-MM-dd"))&resource-uri=$EncodedResourceURI&metric-type=$MetricType"
    
            try {
                # Always use SkipPaginationParameters since resource-uri is always specified (single server query)
                $CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference -ReturnFullObject -SkipPaginationParameters
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }           
    
            $ReturnData = @()
           
            if ($Null -ne $CollectionList) {        

                # Unwrap array if needed to access the actual response object
                $ResponseObject = if ($CollectionList -is [Array] -and $CollectionList.Count -eq 1) { $CollectionList[0] } else { $CollectionList }

                "[{0}] Response object properties: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ResponseObject.PSObject.Properties.Name -join ", ") | Write-Verbose
                "[{0}] Response object content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ResponseObject | ConvertTo-Json -Depth 3) | Write-Verbose

                # Check if servers were excluded from results
                if ($ResponseObject.PSObject.Properties.Name -contains 'excluded' -and $ResponseObject.excluded -gt 0) {
                    "[{0}] API returned {1} excluded server(s) for server: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ResponseObject.excluded, $ServerName | Write-Verbose
                    $ServerExcluded = $true
                    
                    # Check if this is a non-Intel server and add processor-specific guidance
                    if ($Server.processorVendor -and $Server.processorVendor -ne "INTEL") {
                        $ProcessorInfo = $Server.processorVendor.Trim()
                        $WarningMessage = @"
Server '$ServerName' was excluded from utilization insights (API returned excluded=1).

Note: This server has a non-Intel processor ($ProcessorInfo).
Server utilization insights may not be available for all non-Intel processor architectures.

Server details:
- Name: $ServerName
- Model: $($Server.hardware.model)
- Processor: $ProcessorInfo

If this server should support utilization insights, check:
1. Verify metrics configuration: Get-HPECOMMetricsConfiguration -Region $Region
2. Enable metrics if needed: Enable-HPECOMMetricsConfiguration -Region $Region
3. Wait at least 24 hours after enabling metrics for data collection to begin
"@
                    }
                    else {
                        $WarningMessage = @"
Server '$ServerName' was excluded from utilization insights (API returned excluded=1).

Possible causes:
- Metrics collection is not enabled for this server
- The server is not generating metrics data
- The specified date range has no available data

To resolve:
1. Verify metrics configuration: Get-HPECOMMetricsConfiguration -Region $Region
2. Enable metrics if needed: Enable-HPECOMMetricsConfiguration -Region $Region
3. Wait at least 24 hours after enabling metrics for data collection to begin
"@
                    }
                    Write-Warning $WarningMessage
                    Continue
                }
    
                if ($CPUUtilization) {
                 
                    # Extract items array from ResponseObject when using ReturnFullObject
                    if ($ResponseObject.PSObject.Properties.Name -contains 'items') {
                        $ItemsArray = $ResponseObject.items
                        # Ensure it's an array even for single item
                        if ($ItemsArray -isnot [Array]) {
                            $ItemsArray = @($ItemsArray)
                        }
                    }
                    else {
                        $ItemsArray = @($ResponseObject)
                    }
    
                    Foreach ($Item in $ItemsArray) {
                        $Item | Add-Member -type NoteProperty -name LookbackDays -value  $LookbackDays
                        $Item | Add-Member -type NoteProperty -name LookbackDate -value  $LookbackDate
                        $Item | Add-Member -type NoteProperty -name serialNumber -value ($Item.id.split('+')[-1] ) 
                        $Item | Add-Member -type NoteProperty -name region -value $Region
                        $Item | Add-Member -type NoteProperty -name CPUCount -value $Item.metadata.processorCount  
                        
                        $cpuSpeedGHz = $null
                        $cpuDetail = $null
                        if ($Item.metadata.processorDetails -and $Item.metadata.processorDetails.Count -gt 0) {
                            $cpuSpeedGHz = $Item.metadata.processorDetails[0].speedGHz
                            $cpuDetail = $Item.metadata.processorDetails[0].cpu
                        }
                        $Item | Add-Member -Type NoteProperty -Name CPUSpeedGHz -Value $cpuSpeedGHz
                        
                        $Item | Add-Member -type NoteProperty -name CPUDetail -value $cpuDetail  
                        $Item | Add-Member -type NoteProperty -name CPUHighPercent -value $Item.collected.high
                        $Item | Add-Member -type NoteProperty -name CPULowPercent -value $Item.collected.low
                        $Item | Add-Member -type NoteProperty -name CPUAveragePercent -value $Item.collected.average
                    } 
                
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $ItemsArray -ObjectName "COM.Reports.ServerUtilizationInsights.CPUUtilization"    
    
                }
                elseif ($MemoryBusUtilization) {
                  
                    # Extract items array from ResponseObject when using ReturnFullObject
                    if ($ResponseObject.PSObject.Properties.Name -contains 'items') {
                        $ItemsArray = $ResponseObject.items
                        # Ensure it's an array even for single item
                        if ($ItemsArray -isnot [Array]) {
                            $ItemsArray = @($ItemsArray)
                        }
                    }
                    else {
                        $ItemsArray = @($ResponseObject)
                    }
    
                    Foreach ($Item in $ItemsArray) {
                        $Item | Add-Member -type NoteProperty -name LookbackDays -value  $LookbackDays
                        $Item | Add-Member -type NoteProperty -name LookbackDate -value  $LookbackDate
                        $Item | Add-Member -type NoteProperty -name serialNumber -value ($Item.id.split('+')[-1] ) 
                        $Item | Add-Member -type NoteProperty -name region -value $Region
                        
                        $memoryType = $null
                        $memoryOpFrequencyMHz = $null
                        if ($Item.metadata.memoryDetails -and $Item.metadata.memoryDetails.Count -gt 0) {
                            $memoryType = $Item.metadata.memoryDetails[0].memoryType
                            $memoryOpFrequencyMHz = $Item.metadata.memoryDetails[0].opFrequencyMHz
                        }
                        
                        $Item | Add-Member -type NoteProperty -name MemoryType -value $memoryType
                        $Item | Add-Member -type NoteProperty -name MemoryOpFrequencyMHz -value $memoryOpFrequencyMHz
                        $Item | Add-Member -type NoteProperty -name DIMMCount -value $Item.metadata.memoryCount
                        $Item | Add-Member -type NoteProperty -name TotalMemorySizeGB -value $Item.metadata.totalMemorySizeGB
                        $Item | Add-Member -type NoteProperty -name MemoryBusHighPercent -value $Item.collected.high
                        $Item | Add-Member -type NoteProperty -name MemoryBusLowPercent -value $Item.collected.low
                        $Item | Add-Member -type NoteProperty -name MemoryBusAveragePercent -value $Item.collected.average
                    } 
                
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $ItemsArray -ObjectName "COM.Reports.ServerUtilizationInsights.MemoryBusUtilization"    
                }  
                elseif ($IOBusUtilization) {
                  
                    # Extract items array from ResponseObject when using ReturnFullObject
                    if ($ResponseObject.PSObject.Properties.Name -contains 'items') {
                        $ItemsArray = $ResponseObject.items
                        # Ensure it's an array even for single item
                        if ($ItemsArray -isnot [Array]) {
                            $ItemsArray = @($ItemsArray)
                        }
                    }
                    else {
                        $ItemsArray = @($ResponseObject)
                    }
    
                    Foreach ($Item in $ItemsArray) {
                        $Item | Add-Member -type NoteProperty -name LookbackDays -value  $LookbackDays
                        $Item | Add-Member -type NoteProperty -name LookbackDate -value  $LookbackDate
                        $Item | Add-Member -type NoteProperty -name serialNumber -value ($Item.id.split('+')[-1] ) 
                        $Item | Add-Member -type NoteProperty -name region -value $Region
                        $Item | Add-Member -type NoteProperty -name PCIeDevicesCount -value $Item.metadata.pcieDevicesCount
                        $Item | Add-Member -type NoteProperty -name IOBusHighPercent -value $Item.collected.high
                        $Item | Add-Member -type NoteProperty -name IOBusLowPercent -value $Item.collected.low
                        $Item | Add-Member -type NoteProperty -name IOBusAveragePercent -value $Item.collected.average
                    } 
                
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $ItemsArray -ObjectName "COM.Reports.ServerUtilizationInsights.IOBusUtilization"    
                }
                elseif ($CPUInterconnectUtilization) {
                  
                    # Extract items array from ResponseObject when using ReturnFullObject
                    if ($ResponseObject.PSObject.Properties.Name -contains 'items') {
                        $ItemsArray = $ResponseObject.items
                        # Ensure it's an array even for single item
                        if ($ItemsArray -isnot [Array]) {
                            $ItemsArray = @($ItemsArray)
                        }
                    }
                    else {
                        $ItemsArray = @($ResponseObject)
                    }
    
                    Foreach ($Item in $ItemsArray) {
                        $Item | Add-Member -type NoteProperty -name LookbackDays -value  $LookbackDays
                        $Item | Add-Member -type NoteProperty -name LookbackDate -value  $LookbackDate
                        $Item | Add-Member -type NoteProperty -name serialNumber -value ($Item.id.split('+')[-1] ) 
                        $Item | Add-Member -type NoteProperty -name region -value $Region
                        $Item | Add-Member -type NoteProperty -name CPUCount -value $Item.metadata.processorCount  
                        $Item | Add-Member -type NoteProperty -name CPUInterconnectHighPercent -value $Item.collected.high
                        $Item | Add-Member -type NoteProperty -name CPUInterconnectLowPercent -value $Item.collected.low
                        $Item | Add-Member -type NoteProperty -name CPUInterconnectAveragePercent -value $Item.collected.average
                    } 
                
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $ItemsArray -ObjectName "COM.Reports.ServerUtilizationInsights.CPUInterconnectUtilization"    
                }

                if ($ReturnData){
                    [void]$ListOfReturnData.Add($ReturnData)
                }
            }
        }

        if ($ListOfReturnData.Count -eq 0) {
            # Get-* cmdlets return nothing silently for 'not found' scenarios
            return
        }
        else {
            $ListOfReturnData = $ListOfReturnData | Sort-Object name, serialnumber
            return $ListOfReturnData
        }
        
    }
}

Function Get-HPECOMFirmwareAnalysisReport {
    <#
    .SYNOPSIS
    Retrieve the firmware analysis report of the servers, including the security bulletins and customer advisories resolved by the latest baselines.

    .DESCRIPTION
    This cmdlet returns the "Latest baseline firmware analysis report" of a Compute Ops Management region, the report shown in the
    Compute Ops Management console under AI Insights > Firmware analysis.

    For each server generation, Compute Ops Management compares the firmware of every server with the latest firmware baseline (SPP)
    and reports which servers and components need an update, and which security bulletins and customer advisories the update resolves.

    The analysis is maintained by Compute Ops Management and cannot be triggered manually. It is re-evaluated automatically when:
    - The inventory of a server changes
    - A customer advisory or security bulletin document is updated
    - Support for a new baseline is added to Compute Ops Management

    Without any switch, the cmdlet returns the report summary, one object per server generation. Use one of the switches below to
    get the details shown in the console tabs:
    - -ShowServersToUpdate: servers that are not compliant with the latest baseline
    - -ShowComponentsToUpdate: firmware components to update, with the number of servers concerned
    - -ShowAdvisories: security bulletins and customer advisories resolved by updating to the latest baseline
    - -ShowServersUpToDate: servers already compliant with the latest baseline
    - -ShowServersNotAnalyzed: servers that could not be analyzed, with the reason (for example, server not connected)

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER ShowServersToUpdate
    Returns the servers that need a firmware update to match the latest baseline, with the number of components to update,
    critical updates, resolved advisories, reboot requirement and total download size.

    .PARAMETER ShowComponentsToUpdate
    Returns the firmware components to update, with their category, baseline version, update category, reboot requirement,
    the number of servers to update and the number of advisories resolved.

    .PARAMETER ShowAdvisories
    Returns the security bulletins and customer advisories resolved by the components of the latest baseline, with their severity,
    type, title, the number of servers affected and a link to the HPE support document.

    .PARAMETER ShowServersUpToDate
    Returns the servers whose firmware already matches the latest baseline.

    .PARAMETER ShowServersNotAnalyzed
    Returns the servers that could not be analyzed, with the reason reported by Compute Ops Management.

    .PARAMETER ServerName
    Optional filter on the server name or serial number. Wildcards are supported.
    Can be used with -ShowServersToUpdate, -ShowServersUpToDate and -ShowServersNotAnalyzed.

    .PARAMETER Severity
    Optional filter on the severity of the advisories (Critical, High, Medium, Low). Can be used with -ShowAdvisories.

    .PARAMETER Type
    Optional filter on the type of the advisories ('Security Bulletin', 'Customer Advisory'). Can be used with -ShowAdvisories.

    .PARAMETER UpdateCategory
    Optional filter on the update category of the components (Critical, Recommended, Optional). Can be used with -ShowComponentsToUpdate.

    .PARAMETER Generation
    Optional filter on the server generation of the baseline, for example 10 (Gen10 and Gen10 Plus), 11 or 12.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMFirmwareAnalysisReport -Region eu-central

    Returns the firmware analysis summary for each server generation: baseline, number of servers analyzed, servers to update,
    components to update and advisories resolved.

    .EXAMPLE
    Get-HPECOMFirmwareAnalysisReport -Region eu-central -ShowAdvisories

    Returns the security bulletins and customer advisories that are resolved by updating the servers to the latest baselines.

    .EXAMPLE
    Get-HPECOMFirmwareAnalysisReport -Region eu-central -ShowAdvisories -Severity Critical, High -Type 'Security Bulletin'

    Returns only the critical and high severity security bulletins resolved by the latest baselines.

    .EXAMPLE
    Get-HPECOMFirmwareAnalysisReport -Region eu-central -ShowAdvisories | Select-Object severity, title, advisoryLink

    Lists the resolved advisories with the link to each HPE support document.

    .EXAMPLE
    Get-HPECOMFirmwareAnalysisReport -Region eu-central -ShowServersToUpdate

    Returns the servers that need a firmware update, with the number of components to update and advisories resolved for each server.

    .EXAMPLE
    Get-HPECOMFirmwareAnalysisReport -Region eu-central -ShowServersToUpdate | Where-Object advisoriesResolved -gt 0 | Update-HPECOMServerFirmware -FirmwareBaselineReleaseVersion 2026.09.00.00 -WhatIf

    Previews a firmware update to baseline 2026.09.00.00 for every server whose update resolves at least one advisory or security bulletin.

    .EXAMPLE
    Get-HPECOMFirmwareAnalysisReport -Region eu-central -ShowComponentsToUpdate -UpdateCategory Critical -Generation 11

    Returns the Gen11 firmware components with a critical update in the latest Gen11 baseline.

    .EXAMPLE
    Get-HPECOMFirmwareAnalysisReport -Region eu-central -ShowServersNotAnalyzed

    Returns the servers excluded from the analysis and the reason, for example servers that are not connected.

    .EXAMPLE
    'eu-central', 'us-west' | ForEach-Object { Get-HPECOMFirmwareAnalysisReport -Region $_ -ShowAdvisories }

    Returns the resolved advisories of the eu-central and us-west regions.

    .INPUTS
    None. You cannot pipe objects to this cmdlet.

    .OUTPUTS
    HPEGreenLake.COM.FirmwareAnalysis [System.Management.Automation.PSCustomObject]
        Report summary per server generation: generation, baseline, baselineName, reportUpdated, totalServers, analyzed, notAnalyzed,
        serversToUpdate, componentsToUpdate, advisoriesResolved, serversUpToDate, serversNotAnalyzed, sppId, region.

    HPEGreenLake.COM.FirmwareAnalysis.Servers [System.Management.Automation.PSCustomObject]
        With -ShowServersToUpdate or -ShowServersUpToDate: name, serialNumber, model, group, location, rebootRequired, criticalUpdates,
        componentsToUpdate, advisoriesResolved, downloadSize, baseline, id, sppId, region.

    HPEGreenLake.COM.FirmwareAnalysis.Components [System.Management.Automation.PSCustomObject]
        With -ShowComponentsToUpdate: name, componentCategory, baselineVersion, updateCategory, rebootRequired, serversToUpdate,
        advisoriesResolved, componentId, region.

    HPEGreenLake.COM.FirmwareAnalysis.Advisories [System.Management.Automation.PSCustomObject]
        With -ShowAdvisories: severity, type, title, serversAffected, status, documentId, advisoryLink, advisoryId, region.

    HPEGreenLake.COM.FirmwareAnalysis.ServersNotAnalyzed [System.Management.Automation.PSCustomObject]
        With -ShowServersNotAnalyzed: name, serialNumber, reason, generation, baseline, id, region.
    #>

    [CmdletBinding(DefaultParameterSetName = 'Overview')]
    Param(
        [Parameter (Mandatory)]
        [ValidateScript({
                if (-not $Global:HPEGreenLakeSession) {
                    Throw "No active HPE GreenLake session found.`n`nCAUSE:`nYou have not authenticated to HPE GreenLake yet, or your previous session has been disconnected.`n`nACTION REQUIRED:`nRun 'Connect-HPEGL' to establish an authenticated session.`n`nExample:`n    Connect-HPEGL`n    Connect-HPEGL -Credential (Get-Credential)`n    Connect-HPEGL -Workspace `"MyWorkspace`"`n`nAfter connecting, you will be able to use the cmdlets of the HPECOMCmdlets module."
                }
                if (-not $Global:HPECOMRegions -or $Global:HPECOMRegions.Count -eq 0) {
                    Throw "Compute Ops Management is not provisioned in this workspace!`n`nCAUSE:`nNo provisioned Compute Ops Management region was found.`n`nACTION REQUIRED:`nVerify the Compute Ops Management service is provisioned using:`n    Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned`n`nIf not provisioned, you can provision it using 'New-HPEGLService'."
                }
                if (($_ -in $Global:HPECOMRegions.region)) {
                    $true
                }
                else {
                    Throw "The COM region '$_' is not provisioned in this workspace! Please specify a valid region code (e.g., 'us-west', 'eu-central'). `nYou can retrieve the region code using: Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned. `nYou can also use the Tab key for auto-completion to see the list of provisioned region codes."
                }
            })]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Global:HPECOMRegions.region | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [String]$Region,

        [Parameter (Mandatory, ParameterSetName = 'ServersToUpdate')]
        [Switch]$ShowServersToUpdate,

        [Parameter (Mandatory, ParameterSetName = 'ComponentsToUpdate')]
        [Switch]$ShowComponentsToUpdate,

        [Parameter (Mandatory, ParameterSetName = 'Advisories')]
        [Switch]$ShowAdvisories,

        [Parameter (Mandatory, ParameterSetName = 'ServersUpToDate')]
        [Switch]$ShowServersUpToDate,

        [Parameter (Mandatory, ParameterSetName = 'ServersNotAnalyzed')]
        [Switch]$ShowServersNotAnalyzed,

        [Parameter (ParameterSetName = 'ServersToUpdate')]
        [Parameter (ParameterSetName = 'ServersUpToDate')]
        [Parameter (ParameterSetName = 'ServersNotAnalyzed')]
        [ValidateNotNullOrEmpty()]
        [String]$ServerName,

        [Parameter (ParameterSetName = 'Advisories')]
        [ValidateSet('Critical', 'High', 'Medium', 'Low')]
        [String[]]$Severity,

        [Parameter (ParameterSetName = 'Advisories')]
        [ValidateSet('Security Bulletin', 'Customer Advisory')]
        [String[]]$Type,

        [Parameter (ParameterSetName = 'ComponentsToUpdate')]
        [ValidateSet('Critical', 'Recommended', 'Optional')]
        [String[]]$UpdateCategory,

        [ValidateRange(8, 99)]
        [Int]$Generation,

        [Switch]$WhatIf
    )

    Begin {

        $Caller = (Get-PSCallStack)[1].Command
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $SeverityRank = @{ 'Critical' = 0; 'High' = 1; 'Medium' = 2; 'Low' = 3 }
        $UpdateCategoryRank = @{ 'Critical' = 0; 'Recommended' = 1; 'Optional' = 2 }
    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        $IsOverview = $PSCmdlet.ParameterSetName -eq 'Overview'

        # The details endpoints must be filtered by the baselines of the summary, as the console does, to exclude servers that were not analyzed.
        try {
            [Array]$Overview = Invoke-HPECOMWebRequest -Method GET -Uri (Get-COMFirmwareAnalysisOverviewUri) -Region $Region -SkipPaginationParameters -WhatIfBoolean ($WhatIf -and $IsOverview) -Verbose:$VerbosePreference
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if ($WhatIf -and $IsOverview) { return }

        $BundleMap = @{}
        try {
            foreach ($Bundle in @(Get-HPECOMFirmwareBaseline -Region $Region -Verbose:$false)) { $BundleMap[$Bundle.id] = $Bundle }
        }
        catch {
            "[{0}] Firmware baselines cannot be retrieved: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
        }

        # The report label can lag behind the baseline, so the generation of the baseline itself is preferred.
        foreach ($Item in @($Overview)) {
            $BundleGen = "$($BundleMap[$Item.sppId].bundleGeneration)" -replace '^BUNDLE_GEN_', ''
            $Gen = if ($BundleGen) { $BundleGen } else { "$($Item.bundleGeneration)" -replace '^GEN_', '' }
            $Item | Add-Member -NotePropertyName _generation -NotePropertyValue $Gen -Force
        }

        if ($Generation) {
            $Overview = @($Overview | Where-Object { $_._generation -eq "$Generation" })
        }

        if (-not $Overview) {
            "[{0}] No firmware analysis data found in the '{1}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose
            return
        }

        $SppIds = @($Overview.sppId | Where-Object { $_ } | Sort-Object -Unique)
        "[{0}] Baselines in the firmware analysis report: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($SppIds -join ', ') | Write-Verbose

        $ReturnList = [System.Collections.ArrayList]::new()

        if ($IsOverview -or $ShowServersNotAnalyzed) {

            foreach ($Item in $Overview) {
                $Bundle = $BundleMap[$Item.sppId]
                $Gen = $Item._generation

                if ($IsOverview) {
                    [void]$ReturnList.Add([PSCustomObject]@{
                            generation         = $Gen
                            baseline           = $Bundle.releaseVersion
                            baselineName       = $Bundle.name
                            reportUpdated      = $Item.reportUpdated
                            totalServers       = $Item.analysisResults.totalServers
                            analyzed           = $Item.analysisResults.analyzed
                            notAnalyzed        = $Item.analysisResults.notAnalyzed
                            serversToUpdate    = $Item.analysisResults.serversToUpdate
                            componentsToUpdate = $Item.analysisResults.componentsToUpdate
                            advisoriesResolved = $Item.analysisResults.advisoriesResolved
                            serversUpToDate    = $Item.analysisResults.serversUpToDate
                            serversNotAnalyzed = $Item.analysisResults.serversNotAnalyzed
                            sppId              = $Item.sppId
                            region             = $Region
                        })
                }
                else {
                    foreach ($Server in @($Item.analysisResults.serversNotAnalyzed | Where-Object { $_ })) {
                        $Serial = ($Server.serverId -split '\+')[-1]
                        if ($ServerName -and $Server.displayName -notlike $ServerName -and $Serial -notlike $ServerName) { continue }
                        [void]$ReturnList.Add([PSCustomObject]@{
                                name         = $Server.displayName
                                serialNumber = $Serial
                                reason       = $Server.failedReason
                                generation   = $Gen
                                baseline     = $Bundle.releaseVersion
                                id           = $Server.serverId
                                region       = $Region
                            })
                    }
                }
            }

            if ($ReturnList.Count -eq 0) { return }

            if ($IsOverview) {
                return Invoke-RepackageObjectWithType -RawObject ($ReturnList | Sort-Object generation, baseline) -ObjectName "COM.FirmwareAnalysis"
            }
            return Invoke-RepackageObjectWithType -RawObject ($ReturnList | Sort-Object name) -ObjectName "COM.FirmwareAnalysis.ServersNotAnalyzed"
        }

        $Endpoint = switch ($PSCmdlet.ParameterSetName) {
            'ServersToUpdate' { 'servers-to-update' }
            'ComponentsToUpdate' { 'components-to-update' }
            'Advisories' { 'customer-advisories' }
            'ServersUpToDate' { 'servers-up-to-date' }
        }
        $Filter = '(' + (($SppIds | ForEach-Object { "sppId eq '$_'" }) -join ' or ') + ')'
        $Uri = "{0}/{1}?filter={2}" -f (Get-COMFirmwareAnalysisUIDoorwayUri), $Endpoint, $Filter

        try {
            [Array]$CollectionList = Invoke-HPECOMWebRequest -Method GET -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if ($WhatIf -or -not $CollectionList) { return }

        switch ($PSCmdlet.ParameterSetName) {

            'ComponentsToUpdate' {
                foreach ($Item in $CollectionList) {
                    if ($UpdateCategory -and $Item.updateCategory -notin $UpdateCategory) { continue }
                    [void]$ReturnList.Add([PSCustomObject]@{
                            name               = $Item.name
                            componentCategory  = $Item.componentCategory
                            baselineVersion    = $Item.baselineVersion
                            updateCategory     = $Item.updateCategory
                            rebootRequired     = $Item.rebootRequired
                            serversToUpdate    = $Item.serversToUpdate
                            advisoriesResolved = $Item.advisoriesResolved
                            componentId        = $Item.componentId
                            region             = $Region
                        })
                }
                if ($ReturnList.Count -eq 0) { return }
                $Sorted = $ReturnList | Sort-Object { if ($UpdateCategoryRank.ContainsKey("$($_.updateCategory)")) { $UpdateCategoryRank["$($_.updateCategory)"] } else { 9 } }, name
                return Invoke-RepackageObjectWithType -RawObject $Sorted -ObjectName "COM.FirmwareAnalysis.Components"
            }

            'Advisories' {
                foreach ($Item in $CollectionList) {
                    if ($Severity -and $Item.severity -notin $Severity) { continue }
                    if ($Type -and $Item.type -notin $Type) { continue }
                    [void]$ReturnList.Add([PSCustomObject]@{
                            severity        = $Item.severity
                            type            = $Item.type
                            title           = $Item.title
                            serversAffected = $Item.serversAffected
                            status          = $Item.status
                            documentId      = ($Item.advisoryId -split '-')[0]
                            advisoryLink    = $Item.advisoryLink
                            advisoryId      = $Item.advisoryId
                            region          = $Region
                        })
                }
                if ($ReturnList.Count -eq 0) { return }
                $Sorted = $ReturnList | Sort-Object { if ($SeverityRank.ContainsKey("$($_.severity)")) { $SeverityRank["$($_.severity)"] } else { 9 } }, title
                return Invoke-RepackageObjectWithType -RawObject $Sorted -ObjectName "COM.FirmwareAnalysis.Advisories"
            }

            default {
                foreach ($Item in $CollectionList) {
                    $Serial = ($Item.id -split '\+')[-1]
                    if ($ServerName -and $Item.name -notlike $ServerName -and $Serial -notlike $ServerName) { continue }
                    $Detail = $Item.serverFirmwareComplianceDetail_
                    [void]$ReturnList.Add([PSCustomObject]@{
                            name               = $Item.name
                            serialNumber       = $Serial
                            model              = $Item.hardware.model
                            group              = $Item.group_.name
                            location           = $Item.locationInfo_.displayName_
                            rebootRequired     = $Detail.details.rebootRequired
                            criticalUpdates    = $Detail.summary.totalCriticalUpdates
                            componentsToUpdate = $Detail.summary.totalComponentsToUpdate
                            advisoriesResolved = $Detail.summary.totalAdvisoriesResolved
                            downloadSize       = $Detail.details.totalDownloadSize
                            baseline           = $BundleMap[$Detail.sppId].releaseVersion
                            id                 = $Item.id
                            sppId              = $Detail.sppId
                            region             = $Region
                        })
                }
                if ($ReturnList.Count -eq 0) { return }
                return Invoke-RepackageObjectWithType -RawObject ($ReturnList | Sort-Object name) -ObjectName "COM.FirmwareAnalysis.Servers"
            }
        }
    }
}


# Private functions (not exported)
function New-ErrorRecord {
    <#
        .Synopsis
        Creates an custom ErrorRecord that can be used to report a terminating or non-terminating error.

        .Description
        Creates an custom ErrorRecord that can be used to report a terminating or non-terminating error.

        .Parameter Exception
        The Exception that will be associated with the ErrorRecord. Uses RuntimeException by default.

        .Parameter ErrorID
        A scripter-defined identifier of the error. This identifier must be a non-localized string for a specific error type.

        .Parameter ErrorCategory
        An ErrorCategory enumeration that defines the category of the error.  The supported Category Members are (from: http://msdn.microsoft.com/en-us/library/system.management.automation.errorcategory(v=vs.85).aspx) :

            * AuthenticationError - An error that occurs when the user cannot be authenticated by the service. This could mean that the credentials are invalid or that the authentication system is not functioning properly.
            * CloseError - An error that occurs during closing.
            * ConnectionError - An error that occurs when a network connection that the operation depEnds on cannot be established or maintained.
            * DeadlockDetected - An error that occurs when a deadlock is detected.
            * DeviceError - An error that occurs when a device reports an error.
            * FromStdErr - An error that occurs when a non-Windows PowerShell command reports an error to its STDERR pipe.
            * InvalidArgument - An error that occurs when an argument that is not valid is specified.
            * InvalidData - An error that occurs when data that is not valid is specified.
            * InvalidOperation - An error that occurs when an operation that is not valid is requested.
            * InvalidResult - An error that occurs when a result that is not valid is returned.
            * InvalidType - An error that occurs when a .NET Framework type that is not valid is specified.
            * LimitsExceeded - An error that occurs when internal limits prevent the operation from being executed.
            * MetadataError - An error that occurs when metadata contains an error.
            * NotEnabled - An error that occurs when the operation attempts to use functionality that is currently disabled.
            * NotImplemented - An error that occurs when a referenced application programming interface (API) is not implemented.
            * NotInstalled - An error that occurs when an item is not installed.
            * NotSpecified - An unspecified error. Use only when not enough is known about the error to assign it to another error category. Avoid using this category if you have any information about the error, even if that information is incomplete.
            * ObjectNotFound - An error that occurs when an object cannot be found.
            * OpenError - An error that occurs during opening.
            * OperationStopped - An error that occurs when an operation has stopped. For example, the user interrupts the operation.
            * OperationTimeout - An error that occurs when an operation has exceeded its timeout limit.
            * ParserError - An error that occurs when a parser encounters an error.
            * PermissionDenied - An error that occurs when an operation is not permitted.
            * ProtocolError An error that occurs when the contract of a protocol is not being followed. This error should not happen with well-behaved components.
            * QuotaExceeded An error that occurs when controls on the use of traffic or resources prevent the operation from being executed.
            * ReadError An error that occurs during reading.
            * ResourceBusy An error that occurs when a resource is busy.
            * ResourceExists An error that occurs when a resource already exists.
            * ResourceUnavailable An error that occurs when a resource is unavailable.
            * SecurityError An error that occurs when a security violation occurs. This field is introduced in Windows PowerShell 2.0.
            * SyntaxError An error that occurs when a command is syntactically incorrect.
            * WriteError An error that occurs during writing.

        .Parameter TargetObject
        The object that was being Processed when the error took place.

        .Parameter Message
        Describes the Exception to the user.

        .Parameter InnerException
        The Exception instance that caused the Exception association with the ErrorRecord.

        .Parameter TargetType
        To customize the TargetType value, specify the appropriate Target object type.  Values can be "Array", "PSObject", "HashTable", etc.  Can be provided by ${ParameterName}.GetType().Name.

        .Example
        $errorMessage = "Timeout reached waiting for job to complete."
        $errorRecord = New-ErrorRecord TimeoutError OperationTimeout -Message $ErrorMessage
        $PSCmdlet.ThrowTerminatingError($ErrorRecord )

        .EXAMPLE
        $ErrorMessage = "Filter '{0}' cannot be found in the Compute Ops Management instance!" -f $Name
        $ErrorRecord = New-ErrorRecord FilterNotFoundInCOM ObjectNotFound -TargetObject 'Filter' -Message $ErrorMessage -TargetType $Name.GetType().Name
        $PSCmdlet.ThrowTerminatingError($ErrorRecord )

    #>

    [CmdletBinding ()]
    Param
    (        
        
        [Parameter (Mandatory, Position = 0)]
        [Alias ('ID')]
        [System.String]$ErrorId,
        
        [Parameter (Mandatory, Position = 1)]
        [Alias ('Category')]
        [ValidateSet ('AuthenticationError', 'ConnectionError', 'NotSpecified', 'OpenError', 'CloseError', 'DeviceError',
            'DeadlockDetected', 'InvalidArgument', 'InvalidData', 'InvalidOperation',
            'InvalidResult', 'InvalidType', 'MetadataError', 'NotImplemented',
            'NotInstalled', 'ObjectNotFound', 'OperationStopped', 'OperationTimeout',
            'SyntaxError', 'ParserError', 'PermissionDenied', 'ResourceBusy',
            'ResourceExists', 'ResourceUnavailable', 'ReadError', 'WriteError',
            'FromStdErr', 'SecurityError')]
        [System.Management.Automation.ErrorCategory]$ErrorCategory,
            
        [Parameter (Position = 2)]
        [System.Object]$TargetObject,
            
        [System.String]$Exception = "System.Management.Automation.RuntimeException",
        
        # [Parameter (Mandatory)]
        [System.String]$Message,
        
        [System.Exception]$InnerException,
        
        [System.String]$TargetType = "String"

    )

    Process {

        # ...build and save the new Exception depending on present arguments, if it...
        $_exception = if ($Message -and $InnerException) {
            # ...includes a custom message and an inner exception
            New-Object $Exception $Message, $InnerException
        }
        elseif ($Message) {
            # ...includes a custom message only
            New-Object $Exception $Message
        }
        else {
            # ...is just the exception full name
            New-Object $Exception
        }

        # now build and output the new ErrorRecord
        "[{0}] Building ErrorRecord object" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

        $record = [Management.Automation.ErrorRecord]::new($_exception, $ErrorID, $ErrorCategory, $TargetObject)

        $record.CategoryInfo.TargetType = $TargetType

        Return $record
    }
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

            # Auto-save last job result for easy post-execution inspection
            if ($ObjectName -in @('COM.Jobs.Status', 'COM.Schedules.Status')) {
                $Global:HPECOMLastJobResult = $OutputObject
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
Export-ModuleMember -Function 'Get-HPECOMReport', 'New-HPECOMServerInventory', 'Get-HPECOMServerInventory', 'Get-HPECOMSustainabilityInsights', 'Get-HPECOMServerUtilizationInsights', 'Get-HPECOMFirmwareAnalysisReport' -Alias *


# SIG # Begin signature block
# MIIn2gYJKoZIhvcNAQcCoIInyzCCJ8cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAK0n8oKhrZb+7R
# O88jUTVPkU1NNBlaskpJLSWb6LPNe6CCDIMwggYaMIIEAqADAgECAhBiHW0MUgGe
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
# A+rbZZyGZkz3xbUYKTGCGq0wghqpAgEBMGkwVDELMAkGA1UEBhMCR0IxGDAWBgNV
# BAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMgQ29k
# ZSBTaWduaW5nIENBIFIzNgIRAMgx4fswkMFDciVfUuoKqr0wDQYJYIZIAWUDBAIB
# BQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGCNwIB
# BDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQxIgQg
# shkOYSf67Cf2ZQKqvCvyRz1YrdIJrj0qHtBVfoKdDhswDQYJKoZIhvcNAQEBBQAE
# ggIAGlOhXPuar17KSWVMBRlu/URY5RE3wxiX1FW+EE6xxdpe8ArgCZaqeoPCgyJm
# BSVSDcO6kjMC0BbhU495uu+F7Au1n9DftGwI2uODs2QC+nqDX6vlBjmsuWPotJak
# +b4m7g1NAZ2c7HMgX2gXJ5wPKWvnNG3g/WH9lA6l0zrVAZaU1o2LPiX/XU1asArI
# q/ZqGGPAQq0HYLf4bUr9yNAWDMAmJD9FsQhD8Y6QDKEX4rHFVxFe0B4WoBzgoTd5
# oEY+fo7gOkPxn2MsXQozaRUdG3B+oeXbs03fxcbPOyWQ89e+gaLmRCWA2N/xUv36
# fSr7/9rzX9akbXKB1kRKxERHqaw64bEt39qwH6jl1mKcdtxNXr3p1L+wyZ37XJPC
# mSqz7E0aJ+Bq4cYPK640QESvcG3zlZEhhYyFB4kpAOBLzH6neuOApQDtrH42NHCf
# ae02DGJYHV0wduKFfc33pSTIUlsPHDVl2Ab/U/bsLlSxUyxf5MHkL6BPjvLk6n+J
# 9vKzHKj+EmEI8P3o/YdJuyn4s9xM9ZOIXv4Kib9TBodpNXB8JZvRp66eTRzcLP1a
# pmrRlZwwmJ6Ulelv6I4hXB0kR+xMlil2hbyF4WS5E8+/m+ROuAWiVU5qupDxeuru
# 3dgnQiWpOorFLe8qwOD+JGg7+7fPJ31Tk7wUSn6fEJlIvbShgheXMIIXkwYKKwYB
# BAGCNwMDATGCF4Mwghd/BgkqhkiG9w0BBwKgghdwMIIXbAIBAzEPMA0GCWCGSAFl
# AwQCAgUAMIGHBgsqhkiG9w0BCRABBKB4BHYwdAIBAQYJYIZIAYb9bAcBMEEwDQYJ
# YIZIAWUDBAICBQAEMCrH+WRapXdyoSOXOcVaI3pGzPyzAX/jJukdgidhwPUWjgTB
# G/M8BVyRnTbIN3f0rwIQbiSjQnOayN5NQU9aILlC0xgPMjAyNjExMjYxNzQ4MTFa
# oIITOjCCBu0wggTVoAMCAQICEA4euzIrXIp1PhI/Ic7Q8tkwDQYJKoZIhvcNAQEM
# BQAwaTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYD
# VQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2IFNI
# QTI1NiAyMDI1IENBMTAeFw0yNjA4MDUwMDAwMDBaFw0zNzExMDQyMzU5NTlaMGMx
# CzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UEAxMy
# RGlnaUNlcnQgU0hBMzg0IFJTQTQwOTYgVGltZXN0YW1wIFJlc3BvbmRlciAyMDI2
# IDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDGzb2TVObgnNpRsbsm
# C4sUxF6ibiz7n2oKTHqpIcDpFLue7BsPlDPjLxlp0a8qe6LqReZneD2FUX0fpWg3
# QFscsFDtCz4JZJ2YephpY0c50LM0KUwUQVNXwDJs5MI8T/HFS41bSefLLKWSVY/p
# +ZTN6K0mPstoOpxlrWflIrIKqv7DDIS4BYL3YT71oqYz1kfbpw6TeOVzol27pLfz
# PzHfuoP6nXkaZHz+3tbu7HaoiyyqbuNrNJu6mdUPyPmUPpzIKudi0Ye6i7tsfdzn
# 0VtFIw6gvSwNnPTUnztvWrvpD8rqNS4q7tQKXuBBuMlSYtoa4j/k2FRk7xWlkMq6
# WnIeNXbmFjGxYMwrk5PZSzowcWPm90ElKd3R+Fd6qroBUGnzLhqgNthg+sRidN1O
# Ub7uH1ZxcjTIwdQ+14hnGpMmDDHdmTMvaSZ3p5C+ebogrCn+xDV35N4wign/Aynt
# //1acKG7MQ29bmPgtQWRhXM2uOVciCyDETdFCdGhtK1rK4zYE2n8+Cws8PAnsBCK
# 5IKRgvmKS4LOq3CT4OU7TOcCQcR+XFTvuu+N61wLqToKG9z48uLFc0h5I9HwEkCE
# s71ERUvOXIjRWqJaI9K8G4B0sPi56WolBXnbRrOr4GMV9w2Sce1ByYxg5Go9J4E4
# WWRb2kwO+aclHZbGXnGmzidBSwIDAQABo4IBlTCCAZEwDAYDVR0TAQH/BAIwADAd
# BgNVHQ4EFgQUi29SldV7kStiCZ9aQQeHUAshjJIwHwYDVR0jBBgwFoAU729TSunk
# Bnx6yuKQVvYv1Ensy04wDgYDVR0PAQH/BAQDAgeAMBYGA1UdJQEB/wQMMAoGCCsG
# AQUFBwMIMIGVBggrBgEFBQcBAQSBiDCBhTAkBggrBgEFBQcwAYYYaHR0cDovL29j
# c3AuZGlnaWNlcnQuY29tMF0GCCsGAQUFBzAChlFodHRwOi8vY2FjZXJ0cy5kaWdp
# Y2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRUaW1lU3RhbXBpbmdSU0E0MDk2U0hB
# MjU2MjAyNUNBMS5jcnQwXwYDVR0fBFgwVjBUoFKgUIZOaHR0cDovL2NybDMuZGln
# aWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGltZVN0YW1waW5nUlNBNDA5NlNI
# QTI1NjIwMjVDQTEuY3JsMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG/WwH
# ATANBgkqhkiG9w0BAQwFAAOCAgEAILS9cQL2Fnk9lQBRBz8qK80fw7XgvGb5p6hz
# dPj3GsqTDX7T/iRRFFRyRAQIc1bkAzHq8C+ZFwsDFCE8KQWiSU9fFM1WGr6hzIh1
# O3LqncMeU+heFY45F18If1YcU9JOmRURy4Sdr+s6rkwYd38Hxvy1b1XIwE5grqjI
# zfD9k6k87M4l3q4uwSDwAo+HTiHpUHCqzFxSFHDLqKC0A6nGQL1nvUDhxslTRXP7
# hnXjcLzRAhsSsV06G9vH+uC9L/Rz1eZmDnRDcMBOTVhjZQnI2/88M4ZnqmHKNG6y
# cpu918rBdF4rUahg3HI5uJeYtIq6Zw/b07RCAE/ceO3iH94OqGYngGAVhSy66qI/
# rOHLQq+T/UNdLez4LBvzMTsbLvdz1jzrLtuIVAqJC1sS9k1tf/cHtRRtSuSKbJly
# ud2ayy6ax3CZVHi5ArpYlRt3/mIrYu+BikzOsXeMtXv4tDrCWY/ymBdEZZPz0OZC
# cnIdYXJ2ak8y46jAS+HQOY1mAG0koHd9LrO7GvhOVvIMtOpgfpE7/7Qb5afMMh4f
# Ayx22mFrNhFaH/1LsNsyBR6LSrtRZnm9K9Jo013PjWkZWBIZO09olBU6m/ZuV4bA
# RRbSHyzL9YlD4GcEy9mgZq9dglj7HyIkvemPuEFe8tnHA6TSK0WBksSRQz54AfR8
# kRFAXCAwgga0MIIEnKADAgECAhANx6xXBf8hmS5AQyIMOkmGMA0GCSqGSIb3DQEB
# CwUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAXBgNV
# BAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0ZWQg
# Um9vdCBHNDAeFw0yNTA1MDcwMDAwMDBaFw0zODAxMTQyMzU5NTlaMGkxCzAJBgNV
# BAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGlnaUNl
# cnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAyNSBD
# QTEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC0eDHTCphBcr48RsAc
# rHXbo0ZodLRRF51NrY0NlLWZloMsVO1DahGPNRcybEKq+RuwOnPhof6pvF4uGjwj
# qNjfEvUi6wuim5bap+0lgloM2zX4kftn5B1IpYzTqpyFQ/4Bt0mAxAHeHYNnQxqX
# mRinvuNgxVBdJkf77S2uPoCj7GH8BLuxBG5AvftBdsOECS1UkxBvMgEdgkFiDNYi
# OTx4OtiFcMSkqTtF2hfQz3zQSku2Ws3IfDReb6e3mmdglTcaarps0wjUjsZvkgFk
# riK9tUKJm/s80FiocSk1VYLZlDwFt+cVFBURJg6zMUjZa/zbCclF83bRVFLeGkuA
# hHiGPMvSGmhgaTzVyhYn4p0+8y9oHRaQT/aofEnS5xLrfxnGpTXiUOeSLsJygoLP
# p66bkDX1ZlAeSpQl92QOMeRxykvq6gbylsXQskBBBnGy3tW/AMOMCZIVNSaz7BX8
# VtYGqLt9MmeOreGPRdtBx3yGOP+rx3rKWDEJlIqLXvJWnY0v5ydPpOjL6s36czwz
# sucuoKs7Yk/ehb//Wx+5kMqIMRvUBDx6z1ev+7psNOdgJMoiwOrUG2ZdSoQbU2rM
# kpLiQ6bGRinZbI4OLu9BMIFm1UUl9VnePs6BaaeEWvjJSjNm2qA+sdFUeEY0qVjP
# KOWug/G6X5uAiynM7Bu2ayBjUwIDAQABo4IBXTCCAVkwEgYDVR0TAQH/BAgwBgEB
# /wIBADAdBgNVHQ4EFgQU729TSunkBnx6yuKQVvYv1Ensy04wHwYDVR0jBBgwFoAU
# 7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQMMAoG
# CCsGAQUFBwMIMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDovL29j
# c3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5kaWdp
# Y2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6MDig
# NqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9v
# dEc0LmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJKoZI
# hvcNAQELBQADggIBABfO+xaAHP4HPRF2cTC9vgvItTSmf83Qh8WIGjB/T8ObXAZz
# 8OjuhUxjaaFdleMM0lBryPTQM2qEJPe36zwbSI/mS83afsl3YTj+IQhQE7jU/kXj
# jytJgnn0hvrV6hqWGd3rLAUt6vJy9lMDPjTLxLgXf9r5nWMQwr8Myb9rEVKChHyf
# pzee5kH0F8HABBgr0UdqirZ7bowe9Vj2AIMD8liyrukZ2iA/wdG2th9y1IsA0QF8
# dTXqvcnTmpfeQh35k5zOCPmSNq1UH410ANVko43+Cdmu4y81hjajV/gxdEkMx1NK
# U4uHQcKfZxAvBAKqMVuqte69M9J6A47OvgRaPs+2ykgcGV00TYr2Lr3ty9qIijan
# rUR3anzEwlvzZiiyfTPjLbnFRsjsYg39OlV8cipDoq7+qNNjqFzeGxcytL5TTLL4
# ZaoBdqbhOhZ3ZRDUphPvSRmMThi0vw9vODRzW6AxnJll38F0cuJG7uEBYTptMSbh
# dhGQDpOXgpIUsWTjd6xpR6oaQf/DJbg3s6KCLPAlZ66RzIg9sC+NJpud/v4+7RWs
# WCiKi9EOLLHfMR2ZyJ/+xhCx9yHbxtl5TPau1j/1MIDpMPx0LckTetiSuEtQvLsN
# z3Qbp7wGWqbIiOWCnb5WqxL3/BAPvIXKUjPSxyZsq8WhbaM2tszWkPZPubdcMIIF
# jTCCBHWgAwIBAgIQDpsYjvnQLefv21DiCEAYWjANBgkqhkiG9w0BAQwFADBlMQsw
# CQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cu
# ZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJvb3Qg
# Q0EwHhcNMjIwODAxMDAwMDAwWhcNMzExMTA5MjM1OTU5WjBiMQswCQYDVQQGEwJV
# UzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNlcnQu
# Y29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwggIiMA0GCSqG
# SIb3DQEBAQUAA4ICDwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz7MKnJS7JIT3y
# ithZwuEppz1Yq3aaza57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS5F/WBTxSD1If
# xp4VpX6+n6lXFllVcq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb7iDV
# ySAdYyktzuxeTsiT+CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfISKhmV1efVFiO
# DCu3T6cw2Vbuyntd463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jHtrHEtWoYOAMQ
# jdjUN6QuBX2I9YI+EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSaM0C/
# CNdaSaTC5qmgZ92kJ7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI8OCi
# EhtmmnTK3kse5w5jrubU75KSOp493ADkRSWJtppEGSt+wJS00mFt6zPZxd9LBADM
# fRyVw4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPRiQfhvbfmQ6QY
# uKZ3AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ERElvlEFDrMcXK
# chYiCd98THU/Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4KJpn15GkvmB0t
# 9dmpsh3lGwIDAQABo4IBOjCCATYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4EFgQU
# 7NfjgtJxXWRM3y5nP+e6mK4cD08wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGLp6ch
# nfNtyA8wDgYDVR0PAQH/BAQDAgGGMHkGCCsGAQUFBwEBBG0wazAkBggrBgEFBQcw
# AYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRwOi8v
# Y2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3J0
# MEUGA1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9EaWdp
# Q2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwEQYDVR0gBAowCDAGBgRVHSAAMA0GCSqG
# SIb3DQEBDAUAA4IBAQBwoL9DXFXnOF+go3QbPbYW1/e/Vwe9mqyhhyzshV6pGrsi
# +IcaaVQi7aSId229GhT0E0p6Ly23OO/0/4C5+KH38nLeJLxSA8hO0Cre+i1Wz/n0
# 96wwepqLsl7Uz9FDRJtDIeuWcqFItJnLnU+nBgMTdydE1Od/6Fmo8L8vC6bp8jQ8
# 7PcDx4eo0kxAGTVGamlUsLihVo7spNU96LHc/RzY9HdaXFSMb++hUD38dglohJ9v
# ytsgjTVgHAIDyyCwrFigDkBjxZgiwbJZ9VVrzyerbHbObyMt9H5xaiNrIv8SuFQt
# J37YOtnwtoeW/VvRXKwYw02fc7cBqZ9Xql4o4rmUMYIDjDCCA4gCAQEwfTBpMQsw
# CQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERp
# Z2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIw
# MjUgQ0ExAhAOHrsyK1yKdT4SPyHO0PLZMA0GCWCGSAFlAwQCAgUAoIHhMBoGCSqG
# SIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjYxMTI2MTc0
# ODExWjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBTpqKcjtIUE9eDhQ4tnPs6HzyxQ
# mzA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCBxHdd7HC5xsmHXVY1pnAB3yX0SAzCa
# YI7cEFY0wVBQezA/BgkqhkiG9w0BCQQxMgQwCIwk5p7LRVUhV8nA8jnfUjCeqQQt
# CBaHQZnnAsxcvczmKNmQtukCY5OH9pu5qas8MA0GCSqGSIb3DQEBAQUABIICACMW
# +MCLgq1JTuKWf7mwpu05V532MNR3kt8hC0+U249lIA7EsksDtgZF3tBiW64JHFVs
# 0ow5DYVL7EFic/EMtMUkVOz679SJNd94EOuJTIB2Mxndrv/grPawdQV/rIvG0bzs
# 4tcvh3juhbxjy02vhCHE/S49WQln5r/1APyTYE+RQPl5JOYAF5gs45sLmrlZeJHP
# aeNjQCL/tzAEuGBJt8HqNVRmtYDno20drz/sBK58Ji/jBToeg6voLVc20ji4qvb8
# dmfYQ1DZoMec5VuQUU3nhkPyMk1cs+5WO92DBKWfIZ0++bCPC9McOv7ZX6OD4vSM
# Xfd4R74ocu33fk3K4IlTi2ljkOrKK3XA1pd/8hZeXCv17scIOEQq12ZrbUKA3MSF
# v8e06swB/3b461CSV3lXv+qeKgAwVGgHB/TELpCJsL9JB6GgUQHHNFDpS0QSbxpj
# 4exgNyNH1jMW00HEPKFen6N1dGTUKhqHtaiyEWUdnTx2txyPYCwHmv4x/marMbY2
# zBPVuDRHMX0ZWitEwmzDXcUipRiJzNw1qRh1+iKCWMeaIhsJ4PlDA0MFUGW8260U
# peZYDKW6IF0G7xePGlhKEB9AXF/JQcG0H9GMXdlWGpCnX+4a/rw2Dpn2g2qKK+Ft
# 16XhaTceCivEb0up/vzqvqHgEjnrjJlXa3ziUayp
# SIG # End signature block
