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

    HPEGreenLake.COM.Schedules [System.Management.Automation.PSCustomObject]

        - The schedule job object that includes the schedule details when `-ScheduleTime` is used.
    #>

    [CmdletBinding(DefaultParameterSetName = 'Async')]
    Param
    (
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
        
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [Alias('SerialNumber', 'serial')]
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
    HPEGreenLake.COM.Reports.SustainabilityData
        Returns detailed or aggregated sustainability insights based on the specified parameters.
        Output includes energy consumption, CO2 emissions, costs, and server metadata.

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
        [Alias('SerialNumber', 'serial')]
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

            return $OutputObject
        }
        else {
 
            # "[{0}] Null value sent to create object type." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            
            return
        }
    }   
}


# Export only public functions and aliases
Export-ModuleMember -Function 'Get-HPECOMReport', 'New-HPECOMServerInventory', 'Get-HPECOMServerInventory', 'Get-HPECOMSustainabilityInsights', 'Get-HPECOMServerUtilizationInsights' -Alias *


# SIG # Begin signature block
# MIIungYJKoZIhvcNAQcCoIIujzCCLosCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAQUUmH2n+B+amW
# zjti6rrb5Du3ryrBZHfb61PRDZ9ydqCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQgDRPu2EDGbCs0fJ00H9brb/LDNulAe6nFbCL0pfJvtuMwDQYJKoZIhvcNAQEB
# BQAEggIAsWQ61VvAdgytwUibprO0kxgej9en/vdgsGXdIb+RiuDBdvMYvFyyQGnx
# z7i+7ngYVMQ3pwHOw/OSLIOLvuOgm4+yii5nTZR5NDnGcrr0IDXuBYdepTIvGOg/
# iyN5UaZWY6dW9YjVf1YQaBD75/rfBSkRwtrez8rTtK+n5ac9LK96iXKzqlkH6POQ
# ooB4YS8h57AyTCrsoHIcYetXrmzjTz7aSxYCsFwTs9+MrlT2wpTAnxK2VKm4b0mN
# 30/CUeststgJOQ7/zD72M1UdIpjvvSZVYL5dp+SZVx3gCZMdqCCJtUMUjHHVH0DV
# y0Vehs/vwY8PURuckK3zs/+geVrlIYDUcbAudA6AEvEm5+N7dyrwTSQcveoCXtHb
# FZNuqovBQPHlmmR48B4WRveaBj8H9r6TkdzSlup3XfVW215jRSuR6QqmD3SpB+ha
# K6Lzyo4aUEcsqQrX10QoIgxT6kG0exixBK8QbNXCULlUwtubQiVJz+f5pDUGNAJC
# /dEWI65Mlx+/LG9ODo8x6ZDW8YLem2F1qTBTFtjwe5AHabF+WukysHypbBy6om3j
# CvcVl6JKiBgCtbbK0op9BMog39EAyxGsNkHMo5/jGP3D1Ps+uP/MqUd7E1JQc2Fz
# 76hvMkCzjGZv6KtA+gH7GZTMiRKrLsVsdu8Qpc29clcZTZCqebyhghjoMIIY5AYK
# KwYBBAGCNwMDATGCGNQwghjQBgkqhkiG9w0BBwKgghjBMIIYvQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBBwYLKoZIhvcNAQkQAQSggfcEgfQwgfECAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQw0KFnlPTQqkU/FQUaN1d2lTwqaWnEFIBIDduc
# e7qxh6xEHMS5Y0O2cO5B4lTePdNQAhRcVnudoQHTHzBZ4pzxoBddbWW0pxgPMjAy
# NjAzMTcxNDIxMjZaoHakdDByMQswCQYDVQQGEwJHQjEXMBUGA1UECBMOV2VzdCBZ
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
# DxcNMjYwMzE3MTQyMTI2WjA/BgkqhkiG9w0BCQQxMgQw+3fZZLKEp9RcJb+H/+94
# EJMwu4u7h8LjlHyCcmP2yNa5es0qwKSTlnnflJqwdAbdMIIBegYLKoZIhvcNAQkQ
# AgwxggFpMIIBZTCCAWEwFgQUOMkUgRBEtNxmPpPUdEuBQYaptbEwgYcEFMauVOR4
# hvF8PVUSSIxpw0p6+cLdMG8wW6RZMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRpbWUgU3Rh
# bXBpbmcgUm9vdCBSNDYCEHojrtpTaZYPkcg+XPTH4z8wgbwEFIU9Yy2TgoJhfNCQ
# NcSR3pLBQtrHMIGjMIGOpIGLMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKTmV3
# IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBVU0VS
# VFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZpY2F0
# aW9uIEF1dGhvcml0eQIQNsKwvXwbOuejs902y8l1aDANBgkqhkiG9w0BAQEFAASC
# AgABXDAdvqZ/aF9Y2wj5w0yh5R/LBmS35i2fwDoTs8N46i5X7Nhd31qLmFmI+YPg
# XKtoJt0/ctxiOukzOsh787TzQiMpvQuYDA1Stlzsd9prRsWCxi3V+WJ3nX/GKK3U
# kaN7pHCkKVreQA3g1YyWYWKzbeAcNLpsZ0LqeJnlBhuXcN0+I8j3Cb8ekXrg+YoA
# 5fcbzlbMezuJju3ZnuHke3PggTmzcnDacXY+O3hkwGmA+G8yS0HrPkArFbDQLRbG
# W+tDtmggBiG7qdO1cerCwtVGvX8Gajlbb5fPZkHbwFk6Ayjs8q8m5tqm7BmOD+Hh
# lodx7kqcqtMfmSGPj3Ev5IxEjzNJOTxudGifToqE26AEZfKNFX5Fo5oCvw+sA3jK
# gK8tVdg8LvF1J5fn9pzv1sdORFlfV6HHniETdX8n0emILiXvtHE+h/QboONPo+or
# FKaNx9T9QN3UfcGQylx3l9YF+iFMZWxIBofls/e97LC9HRN1lQeq7ESdfgUQUMbl
# QltU8gEmzyn6a8WaMa4FD0YQNn6lMiZlFeUZ8V5X2v5tYB9kzro+v3dXK6O5+8Ig
# m1zBL554Ga+i2ruvt92OuXK+CkaNbuuD4z2TD/gJrMyFHw+3I7V7J91Kv8lnkHwH
# RbPav+JKj2gPDPETa2Y0+E54aBni6SEu0pq3KhmmkbZ0/A==
# SIG # End signature block
