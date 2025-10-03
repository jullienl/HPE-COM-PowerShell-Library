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
    
    .PARAMETER SerialNumber
    Serial number of the server on which server inventory data will be collected. 
    
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
    New-HPECOMServerInventory -Region us-west -SerialNumber CN70490RXQ  

    Collects a full inventory data from server 'CN70490RXQ' in the western US region.

    .EXAMPLE
    New-HPECOMServerInventory -Region us-west -SerialNumber CN70490RXQ -Chassis -Fans 

    Collects the chassis and fans inventory data from server 'CN70490RXQ' in the western US region.

    .EXAMPLE
    Get-HPECOMServer -Region us-west -Name HOL19  | New-HPECOMServerInventory

    Collects the full inventory data from server named 'HOL19' in the western US region.    
    
    .EXAMPLE
    New-HPECOMServerInventory -Region eu-central -SerialNumber CZ12312312 -ScheduleTime (Get-Date).AddDays(1) 

    Creates a new server inventory in the 'eu-central' region with serial number 'CZ12312312', scheduled to start one day from the current date.

    .EXAMPLE
    New-HPECOMServerInventory -Region eu-central -SerialNumber CZ12312312 -ScheduleTime (Get-Date).AddDays(1) -Interval P1W

    Creates a new server inventory in the 'eu-central' region with serial number 'CZ12312312', scheduled to start one day from the current date and recur weekly.

    .EXAMPLE
    "CZ12312312", "CZ12312313" | New-HPECOMServerInventory -Region eu-central

    Collects a full inventory data from servers 'CZ12312312' and 'CZ12312313' in the 'eu-central' region.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects that represent the server's serial numbers.
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
        [String]$SerialNumber,
        
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

        $JobTemplateUri = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object resourceuri
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
                description        = if ($SerialNumber) { "Scheduled task to collect inventory data from server '$SerialNumber'" } else { "Scheduled task to collect inventory data from all servers" }
                associatedResource = if ($SerialNumber) { $SerialNumber } else { "All servers" }
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
                associatedResource = if ($SerialNumber) { $SerialNumber } else { "All servers" }
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

            $_server = Get-HPECOMServer -Region $Region -Name $SerialNumber
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
                $objStatus.state = "ERROR"
                $objStatus.duration = '00:00:00'
                $objStatus.resultCode = "FAILURE"
                $objStatus.status = "Failed"
                $objStatus.message = "Server cannot be found in the Compute Ops Management instance!"
            }
            
            if ($WhatIf) {
                $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $SerialNumber
                Write-warning $ErrorMessage
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

                $Name = "$($SerialNumber)_Inventory_Report_Schedule_$($randomNumber)"
                $Description = "Scheduled task to run an inventory report on server '$($SerialNumber)'"

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
                    name                  = $Name
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
        [void]$ObjectStatusList.Add($objStatus)

        
    }

    end {

        if (-not $WhatIf) {

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
    
    Note: 
    A server hardware inventory report must be available or created with `New-HPECOMServerInventory` before using this cmdlet. 
    You can check reports using `Get-HPECOMReport`.

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
                $ReturnData | Add-Member -Type NoteProperty -Name serverName -Value $_ServerName.name
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $ReturnData -ObjectName "COM.Servers.Inventory.Software"    

            }
    
            elseif ($Showfirmware) {
                $ReturnData = $CollectionList.firmware.data 
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

            if ($Null -eq $ReturnData -and -not $FullInventoryAlreadyRun) {

                Write-Verbose ($PSCmdlet.MyInvocation.BoundParameters.Keys | Where-Object { $_ -like 'Show*' } )

                $ErrorMessage = "{0} inventory data is not populated. Please run New-HPECOMServerInventory first." -f (($PSCmdlet.MyInvocation.BoundParameters.Keys | Where-Object { $_ -like 'Show*' } ) -replace "Show")
                Write-Warning $ErrorMessage

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
    Retrieve the sustainability insights.

    .DESCRIPTION
    This cmdlet retrieves sustainability insights for servers managed by COM in the specified region.
    It provides information on energy consumption, CO2 emissions, and cost savings. These insights help organizations monitor and manage the environmental impact of their server infrastructure.
    By default, the cmdlet returns total estimated values for energy consumption, CO2 emissions, and energy cost for all managed servers in the specified region over the past 90 days, along with projections for the next 180 days.
    Users can filter the results to view data for individual servers by specifying a server's serial number or by piping server objects from the `Get-HPECOMServer` cmdlet.
    Additionally, users can customize the time range and granularity of the data by using the `LookbackDays` and `ProjectionDays` parameters.

    Note: 
    Metrics data collection must be enabled (it is enabled by default) to retrieve sustainability insights.
    To enable metrics data collection, use `Enable-HPECOMMetricsConfiguration`.
    To verify the current metrics data collection status, use `Get-HPECOMMetricsConfiguration`.

    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) from which to retrieve the sustainability insights.
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER SerialNumber
    Optional parameter that can be used to get the report data of a specific server.
    
    .PARAMETER Co2Emissions
    Optional switch parameter that can be used to display the carbon emissions data.    
    
    .PARAMETER Co2EmissionsTotal
    Optional switch parameter that can be used to display the total carbon emissions data.    

    .PARAMETER EnergyConsumption
    Optional switch parameter that can be used to display the energy consumption data.   
    
    .PARAMETER EnergyConsumptionTotal
    Optional switch parameter that can be used to display the total energy consumption data.  
        
    .PARAMETER EnergyCost
    Optional switch parameter that can be used to display the energy cost data.    

    .PARAMETER EnergyCostTotal
    Optional switch parameter that can be used to display the total energy cost data.     

    .PARAMETER LookbackDays
    Optional parameter that specifies the number of days to look back for data. The default value is 90 days (3 months). 
    The maximum value is 180 days (6 months).

    .PARAMETER ProjectionDays
    Optional parameter that specifies the number of days to project energy consumption, CO2 emissions and costs into the future. The default value is 180 days (6 months). 
    The maximum value is 180 days (6 months).

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMSustainabilityInsights -Region us-west 

    Returns the total estimated sustainability insights for the us-west region, including energy consumption, CO2 emissions, and energy cost. Data covers the past 90 days and projects the next 180 days.

    .EXAMPLE
    Get-HPECOMSustainabilityInsights -Region eu-central -EnergyConsumptionTotal 

    Returns the total estimated energy consumption data available in the eu-central region, including data from the past 90 days and projections for the next 180 days.
    
    .EXAMPLE
    Get-HPECOMSustainabilityInsights -Region eu-central -EnergyConsumptionTotal -LookbackDays 7 -ProjectionDays 100

    Returns the total estimated energy consumption data available in the eu-central region, including data from the past 7 days and projections for the next 100 days.

    .EXAMPLE
    Get-HPECOMSustainabilityInsights -Region eu-central -EnergyCostTotal

    Returns the total estimated energy cost data available in the eu-central region, including data from the past 90 days and projections for the next 180 days.

    .EXAMPLE
    Get-HPECOMSustainabilityInsights -Region eu-central -Co2EmissionsTotal

    Returns the total estimated CO2 emissions data available in the eu-central region, including data from the past 90 days and projections for the next 180 days.

    .EXAMPLE
    Get-HPECOMSustainabilityInsights -Region eu-central -Co2Emissions -LookbackDays 7 -ProjectionDays 100

    Returns the estimated CO2 emissions data for each server in the eu-central region, including values from the past 7 days and projections for the next 100 days.
  
    .EXAMPLE
    Get-HPECOMSustainabilityInsights -Region eu-central -EnergyCost

    Returns the estimated energy cost data for each server in the eu-central region, including values from the past 90 days and projections for the next 180 days.

    .EXAMPLE
    Get-HPECOMSustainabilityInsights -Region eu-central -SerialNumber 123456789 -EnergyCost

    Returns the estimated energy cost data for the server with serial number '123456789' in the eu-central region, including data from the past 90 days and projections for the next 180 days.

    .EXAMPLE
    Get-HPECOMSustainabilityInsights -Region eu-central -SerialNumber 123456789 -Co2Emissions -LookbackDays 7 -ProjectionDays 100

    Returns the estimated CO2 emissions data for the server with serial number '123456789' in the eu-central region, including data from the past 7 days and projections for the next 100 days.

    .EXAMPLE
    Get-HPECOMServer -Region us-west -ConnectionType Direct -PowerState ON | select -first 2 | Get-HPECOMSustainabilityInsights -Co2Emissions 

    This command pipes the first two servers that are directly managed and powered on in the 'us-west' region to `Get-HPECOMSustainabilityInsights`, returning the CO2 emissions insights for each server.

    .EXAMPLE
    '123456789', '987654321' | Get-HPECOMSustainabilityInsights -Region us-west -EnergyCost

    This command returns the estimated energy cost data for the servers with serial numbers '123456789' and '987654321' in the 'us-west' region, including data from the past 90 days and projections for the next 180 days.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.
    
    System.Collections.ArrayList
        List of servers retrieved using 'Get-HPECOMServer'.

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
        [alias('serial')]
        [String]$SerialNumber,

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

        $ServerSerialNumbersList = [System.Collections.ArrayList]::new() 
    }      
      
    Process {
      
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        if ($SerialNumber) {
            [void]$ServerSerialNumbersList.Add($SerialNumber)
        }

    }

    End {

        $ProjectionDate = (Get-Date).AddDays($ProjectionDays).ToString("yyyy-MM-dd")
        $LookbackDate = (Get-Date).AddDays(-$LookbackDays).ToString("yyyy-MM-dd")

        $Uri = (Get-COMEnergyByEntityUri) + "?start-date=$((Get-Date).AddDays(-$LookbackDays).ToString("yyyy-MM-dd"))&projection-days=$ProjectionDays"
            
        try {
            [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference -ReturnFullObject
        
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
                       
        }           
            
    
        $ReturnData = @()
           
        if ($Null -ne $CollectionList) {   
                
            if ($Co2Emissions) {
                    
                if ($CollectionList -is [System.Collections.IEnumerable] -and $CollectionList.Count -gt 0 -and $CollectionList[0].PSObject.Properties.Name -contains 'items') {
                    $CollectionList = $CollectionList.items
                    $CollectionList = $CollectionList | Sort-Object name, serialNumber
                }

                Foreach ($Item in $CollectionList) {
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
                    
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Reports.SustainabilityData.Co2Emissions"    

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

                if ($CollectionList -is [System.Collections.IEnumerable] -and $CollectionList.Count -gt 0 -and $CollectionList[0].PSObject.Properties.Name -contains 'items') {
                    $CollectionList = $CollectionList.items
                    $CollectionList = $CollectionList | Sort-Object name, serialNumber
                }

                Foreach ($Item in $CollectionList) {
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
                    

                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Reports.SustainabilityData.EnergyConsumption"    

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

                        
                if ($CollectionList -is [System.Collections.IEnumerable] -and $CollectionList.Count -gt 0 -and $CollectionList[0].PSObject.Properties.Name -contains 'items') {
                    $CollectionList = $CollectionList.items
                    $CollectionList = $CollectionList | Sort-Object name, serialNumber
                }

                Foreach ($Item in $CollectionList) {
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
                    

                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Reports.SustainabilityData.EnergyCost"    

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
                    
            if ( $ServerSerialNumbersList.Count -gt 0 ) {

                '[{0}] List of serial numbers to process: {1}' -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServerSerialNumbersList -join ", ") | Write-Verbose

                $ReturnData = $ReturnData | Where-Object { $ServerSerialNumbersList -contains $_.serialNumber }
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
    Users can filter the results to view data for individual servers by specifying a server's serial number or by piping server objects from the `Get-HPECOMServer` cmdlet.

    Note: 
    Metrics data collection must be enabled (it is enabled by default) to retrieve utilization insights.
    To enable metrics data collection, use `Enable-HPECOMMetricsConfiguration`.
    To verify the current metrics data collection status, use `Get-HPECOMMetricsConfiguration`.

    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) from which to retrieve the utilization insights.
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER SerialNumber
    Mandatory parameter that can be used to get the report data of a specific server.

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
    Get-HPECOMServerUtilizationInsights -Region eu-central -SerialNumber 123456789 -CPUUtilization 

    Returns the CPU utilization insights for the server with serial number '123456789' in the eu-central region, including data from the past 90 days.

    .EXAMPLE
    Get-HPECOMServerUtilizationInsights -Region eu-central -SerialNumber 123456789 -CPUUtilization -LookbackDays 180

    Returns the CPU utilization insights for the server with serial number '123456789' in the eu-central region, including data from the past 180 days.

    .EXAMPLE
    Get-HPECOMServerUtilizationInsights -Region eu-central -SerialNumber 123456789 -MemoryBusUtilization 

    Returns the memory bus utilization insights for the server with serial number '123456789' in the eu-central region, including data from the past 90 days.

    .EXAMPLE
    Get-HPECOMServerUtilizationInsights -Region eu-central -SerialNumber 123456789 -IOBusUtilization

    Returns the I/O bus utilization insights for the server with serial number '123456789' in the eu-central region, including data from the past 90 days.

    .EXAMPLE
    Get-HPECOMServerUtilizationInsights -Region eu-central -SerialNumber 123456789 -CPUInterconnectUtilization

    Returns the CPU interconnect utilization insights for the server with serial number '123456789' in the eu-central region, including data from the past 90 days.

    .EXAMPLE
    Get-HPECOMServer -Region us-west -ConnectionType Direct -PowerState ON | Select-Object -First 2 | Get-HPECOMServerUtilizationInsights -CPUUtilization

    This command pipes the first two servers that are directly managed and powered on in the 'us-west' region to `Get-HPECOMServerUtilizationInsights`, returning the CPU utilization insights for each server.

    .EXAMPLE
    '123456789', '987654321' | Get-HPECOMServerUtilizationInsights -Region us-west -MemoryBusUtilization

    This command returns the memory bus utilization insights for the servers with serial numbers '123456789' and '987654321' in the 'us-west' region, including data from the past 90 days.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.

    System.Collections.ArrayList
        List of servers retrieved using 'Get-HPECOMServer'.
        
   #>
    [CmdletBinding()]
    Param( 

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
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

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [String]$SerialNumber,

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

        $ServerSerialNumbersList = [System.Collections.ArrayList]::new() 

        $ListOfReturnData = [System.Collections.ArrayList]::new() 

    }
      
    Process {
      
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        if ($SerialNumber) {
            [void]$ServerSerialNumbersList.Add($SerialNumber)
        }

    }
      
    End {

        $LookbackDate = (Get-Date).AddDays(-$LookbackDays).ToString("yyyy-MM-dd")

        if ($ServerSerialNumbersList.Count -gt 0) {
            '[{0}] List of serial numbers to process: {1}' -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServerSerialNumbersList -join ", ") | Write-Verbose
        }

        foreach ($ServerSerialNumber in $ServerSerialNumbersList) {

            "[{0}] Processing serial number: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServerSerialNumber | Write-Verbose

            $Server = $False

            try {
                $Server = Get-HPECOMServer -Region $Region -Name $ServerSerialNumber
    
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }
    
            if (-not $Server) {
                # Must return a message if not found
                $WarningMessage = "Server with serial number '$ServerSerialNumber' cannot be found in the Compute Ops Management instance!"
                Write-Warning $WarningMessage
                Continue
            }
            elseif ($Server.connectionType -eq "ONEVIEW") {
                $WarningMessage = "Server with serial number '$ServerSerialNumber' is a OneView managed server and does not support utilization insights!"
                Write-Warning $WarningMessage
                Continue
            }
            else {
                $ResourceURI = $Server.resourceUri
                $EncodedResourceURI = [System.Web.HttpUtility]::UrlEncode($ResourceURI)
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
                [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference -ReturnFullObject
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }           
    
            $ReturnData = @()
           
            if ($Null -ne $CollectionList) {        
    
                if ($CPUUtilization) {
                 
                    if ($CollectionList -is [System.Collections.IEnumerable] -and $CollectionList.Count -gt 0 -and $CollectionList[0].PSObject.Properties.Name -contains 'items') {
                        $CollectionList = $CollectionList.items
                    }                    
    
                    Foreach ($Item in $CollectionList) {
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
                
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Reports.ServerUtilizationInsights.CPUUtilization"    
    
                }
                elseif ($MemoryBusUtilization) {
                  
                    if ($CollectionList -is [System.Collections.IEnumerable] -and $CollectionList.Count -gt 0 -and $CollectionList[0].PSObject.Properties.Name -contains 'items') {
                        $CollectionList = $CollectionList.items
                    }
    
                    Foreach ($Item in $CollectionList) {
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
                
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Reports.ServerUtilizationInsights.MemoryBusUtilization"    
                }  
                elseif ($IOBusUtilization) {
                  
                    if ($CollectionList -is [System.Collections.IEnumerable] -and $CollectionList.Count -gt 0 -and $CollectionList[0].PSObject.Properties.Name -contains 'items') {
                        $CollectionList = $CollectionList.items
                    }
    
                    Foreach ($Item in $CollectionList) {
                        $Item | Add-Member -type NoteProperty -name LookbackDays -value  $LookbackDays
                        $Item | Add-Member -type NoteProperty -name LookbackDate -value  $LookbackDate
                        $Item | Add-Member -type NoteProperty -name serialNumber -value ($Item.id.split('+')[-1] ) 
                        $Item | Add-Member -type NoteProperty -name region -value $Region
                        $Item | Add-Member -type NoteProperty -name PCIeDevicesCount -value $Item.metadata.pcieDevicesCount
                        $Item | Add-Member -type NoteProperty -name IOBusHighPercent -value $Item.collected.high
                        $Item | Add-Member -type NoteProperty -name IOBusLowPercent -value $Item.collected.low
                        $Item | Add-Member -type NoteProperty -name IOBusAveragePercent -value $Item.collected.average
                    } 
                
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Reports.ServerUtilizationInsights.IOBusUtilization"    
                }
                elseif ($CPUInterconnectUtilization) {
                  
                    if ($CollectionList -is [System.Collections.IEnumerable] -and $CollectionList.Count -gt 0 -and $CollectionList[0].PSObject.Properties.Name -contains 'items') {
                        $CollectionList = $CollectionList.items
                    }
    
                    Foreach ($Item in $CollectionList) {
                        $Item | Add-Member -type NoteProperty -name LookbackDays -value  $LookbackDays
                        $Item | Add-Member -type NoteProperty -name LookbackDate -value  $LookbackDate
                        $Item | Add-Member -type NoteProperty -name serialNumber -value ($Item.id.split('+')[-1] ) 
                        $Item | Add-Member -type NoteProperty -name region -value $Region
                        $Item | Add-Member -type NoteProperty -name CPUCount -value $Item.metadata.processorCount  
                        $Item | Add-Member -type NoteProperty -name CPUInterconnectHighPercent -value $Item.collected.high
                        $Item | Add-Member -type NoteProperty -name CPUInterconnectLowPercent -value $Item.collected.low
                        $Item | Add-Member -type NoteProperty -name CPUInterconnectAveragePercent -value $Item.collected.average
                    } 
                
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Reports.ServerUtilizationInsights.CPUInterconnectUtilization"    
                }

                if ($ReturnData){
                    [void]$ListOfReturnData.Add($ReturnData)
                }
            }
        }

        if ($ListOfReturnData.Count -eq 0) {
            Write-Warning "No utilization insights data were found for the specified server(s) in the Compute Ops Management instance.`nNone of the servers could be analyzed. At least one day of metrics data collection is required.`nTo access utilization insights, ensure that metrics data collection is enabled in your Compute Ops Management instance. You can enable it using the 'Enable-HPECOMMetricsConfiguration' cmdlet and verify the current status with 'Get-HPECOMMetricsConfiguration'."
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
# MIItTgYJKoZIhvcNAQcCoIItPzCCLTsCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCbT19ixEPa7pYG
# EbLEaW3Cq+Q+UgxGQ0rLJulujcnVC6CCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# nZ+oA+rbZZyGZkz3xbUYKTGCGq4wghqqAgEBMGkwVDELMAkGA1UEBhMCR0IxGDAW
# BgNVBAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMg
# Q29kZSBTaWduaW5nIENBIFIzNgIRAMgx4fswkMFDciVfUuoKqr0wDQYJYIZIAWUD
# BAIBBQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGC
# NwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQx
# IgQgW/df7XqHCk1xQGEeMeNkh7ard07yqV11TRdMhXuHAAkwDQYJKoZIhvcNAQEB
# BQAEggIAn5pJ+xOfylQEFrUDvJRHTIqlZWVri1vj987X6mfwqo2HJXLv37fjLt8b
# /CyYKNsuw7aylHzgFCJXtO4CafFfGS42nXGqMTQ6gxGMi8qR5qcGMExWpbtk6J0C
# 9XCAim78UiH+GF6J4C6wHofbQvfeL0QYfs64BxLAkO1b0m3zn4JKFmxLRqS9Aaox
# Cx3L39Qg4D7NM2a85CYFGwrDoe9d4U1MKxZx3iPQtuJURzAO21ZKAz6XxYXyE7I/
# 6kE2nATzWfMD1KbNOpv22GMRVHpGjtY+u78DI08YPc0EsGEnCrD9HL7DkEojF79V
# KN1YTfD3alKricsIT3Y/CHyXQke/HLj6sURd1s/MO23Bofc1QlFuavnWxvgWvBxL
# AIKaQywxcH67lkL46Xvb8IODsD8MFLH9wXRDMBp2BwJ9Q8k2QHngLMldcSVIzGIM
# JLkkiTPpaCctoq5OPk7fkDRWt1dt9ftbKZTz28mwfeCEVtBQ3xDQxx7J7yRpYLdN
# uDhzYmAkOPyP74QJ+8i6wbe+oSFTT1lF83eKp31fUdWS3KXtpNjGgwWnjXBhMgSI
# yQmeXQZ0gHfrWQqXQbhBrV6tQoxHda4mQAQNSrSCEJF6pCZvUKP7qBC8IdtMOl9I
# DTm6ioThl/tfqShp63EcIb4i85rRFWmeWA3881OIv3+qx4uXZp2hgheYMIIXlAYK
# KwYBBAGCNwMDATGCF4QwgheABgkqhkiG9w0BBwKgghdxMIIXbQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIGIBgsqhkiG9w0BCRABBKB5BHcwdQIBAQYJYIZIAYb9bAcBMEEw
# DQYJYIZIAWUDBAICBQAEMLzr6fAldgcRqy0S7IvpDzoN63OBL/7mO9aXrmXtdn0s
# +1UIwzaN2uv43VIWcD8yZgIRAIFZMixndFc7Pnli4rx7L6wYDzIwMjUxMDAyMTU0
# MzIzWqCCEzowggbtMIIE1aADAgECAhAMIENJ+dD3WfuYLeQIG4h7MA0GCSqGSIb3
# DQEBDAUAMGkxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFB
# MD8GA1UEAxM4RGlnaUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5
# NiBTSEEyNTYgMjAyNSBDQTEwHhcNMjUwNjA0MDAwMDAwWhcNMzYwOTAzMjM1OTU5
# WjBjMQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xOzA5BgNV
# BAMTMkRpZ2lDZXJ0IFNIQTM4NCBSU0E0MDk2IFRpbWVzdGFtcCBSZXNwb25kZXIg
# MjAyNSAxMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEA2zlS+4t0t+XJ
# DVHY+vNJxpv794sM3O4UQycmKRXmYLs+YRfztyl8QJ7n/UqxNTKWmjdFDWGv43+a
# 2oiJ41yxOe0sLoFx8F1az2JRTZc7dhAxbne+byd5bf2SEZlCruGxxWSqbpUY6dAG
# RCCyBOaiFaoXhkn+L15efcomDSrTnA5Vgd9pvMO+7bM+tSW4JzAiIbO2mIPyCEdK
# YscmPl+YBuenSP7NJw9icL1tWpn61uM6WyUNv4RcyBAz+NvJbNf5kTM7F46cvBwp
# 0lZYisZR985y5sYj4e4yUBbPBxyrT5aNMZ++5tis8GDmHCpqyVLQ4eLHwpim5iwR
# 49TREfETtlEFORWTkJ2hOO1zzVAWs6jtdep12VtFZoQOhIwdUfPHSsAw39xFVevF
# EFf2u+DVr1sOV7JACY+xcG8hWIeqPGVUwkiyBRUTgA7HeAxJb0iQl4GDBC6ZBA4w
# GN/ahMxF4fuJsOs1zwkPBSnXmHkm18HwHgIPKk287dMIchZyjm7zGcCYZ4bisoUY
# WL9oTga9JCfFMTc9yl26XDB0zl9rdSwviOmaYSlaRanF84oxAYnqgBy6Z89ykPgW
# nb7SRi31NyP359Whok+36fkyxTPjSrCWvMK7pzbRg8tfIRlUnxl7G5bIrkPqMbD9
# zJoB79MHFgLr5ljU7rrcLwy+cEfpzFMCAwEAAaOCAZUwggGRMAwGA1UdEwEB/wQC
# MAAwHQYDVR0OBBYEFFWeuednyJEQSbQ2Uo15tyTFPy34MB8GA1UdIwQYMBaAFO9v
# U0rp5AZ8esrikFb2L9RJ7MtOMA4GA1UdDwEB/wQEAwIHgDAWBgNVHSUBAf8EDDAK
# BggrBgEFBQcDCDCBlQYIKwYBBQUHAQEEgYgwgYUwJAYIKwYBBQUHMAGGGGh0dHA6
# Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBdBggrBgEFBQcwAoZRaHR0cDovL2NhY2VydHMu
# ZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGltZVN0YW1waW5nUlNBNDA5
# NlNIQTI1NjIwMjVDQTEuY3J0MF8GA1UdHwRYMFYwVKBSoFCGTmh0dHA6Ly9jcmwz
# LmRpZ2ljZXJ0LmNvbS9EaWdpQ2VydFRydXN0ZWRHNFRpbWVTdGFtcGluZ1JTQTQw
# OTZTSEEyNTYyMDI1Q0ExLmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgB
# hv1sBwEwDQYJKoZIhvcNAQEMBQADggIBABt+CySH2AlqxUHnUWnZJI7rpdAqo0Pc
# ikyV48Ltk5QWFgxpHP9WtjR3lskEAOk3TszmuNyMid7VuxHlQJl4KcdTr5cQ2YLy
# +l560peBgM7kA4HCJqGqdQdzjXyrlg3YCdfnjs9w/7BO8xUmlAaq/D+PTZZO+Mnx
# a3/IoyYsF+L9gWX4VJxZLljVs5JKmpSonnysMYv7CaqkQpBDmJWU2F68mLLZXfU0
# wXbDy9QQTskgcHviyQDeB1l6jl/WwOQiSNTNafYQUR2ZsJ5rPJu1NPzO1htKwdiU
# jWenHwq5BRK1BR7+D+TwG97UHX4V0W+JvFZp8z3d3G5sA7Pt9qO5/6AWZ+0yf8nN
# 58D+HAAShHmny25t6W7qF6VSRZCIpGr8hbAjfbBhO4MY8G2U9zwVKp6SljuKknxd
# 2buihO33dioCGsB6trX++xQKf4QlYSggFvD9ZWSG4ysJPYOx+hbsBTEONFtr99x6
# OgJnnyVkDoudIn+gmV+Bq+a2G++BLU5AXOVclExpuoUQXUZF5p3sUrd21QjF9Ra0
# x4RD02gS4XwgzN+tvuY+tjhPICwXmH3ERL+fPIoxZT0XgwVP+17UqUbi5Zpe4Yda
# dG5WjCTBvtmlM4JVovGYRvyAyfmYJJx0/0T+qK05wRJpg4q81vOKuCQPaE9H99JC
# VvfCDBm4KjrEMIIGtDCCBJygAwIBAgIQDcesVwX/IZkuQEMiDDpJhjANBgkqhkiG
# 9w0BAQsFADBiMQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkw
# FwYDVQQLExB3d3cuZGlnaWNlcnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVz
# dGVkIFJvb3QgRzQwHhcNMjUwNTA3MDAwMDAwWhcNMzgwMTE0MjM1OTU5WjBpMQsw
# CQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMTOERp
# Z2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2IDIw
# MjUgQ0ExMIICIjANBgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAtHgx0wqYQXK+
# PEbAHKx126NGaHS0URedTa2NDZS1mZaDLFTtQ2oRjzUXMmxCqvkbsDpz4aH+qbxe
# Lho8I6jY3xL1IusLopuW2qftJYJaDNs1+JH7Z+QdSKWM06qchUP+AbdJgMQB3h2D
# Z0Mal5kYp77jYMVQXSZH++0trj6Ao+xh/AS7sQRuQL37QXbDhAktVJMQbzIBHYJB
# YgzWIjk8eDrYhXDEpKk7RdoX0M980EpLtlrNyHw0Xm+nt5pnYJU3Gmq6bNMI1I7G
# b5IBZK4ivbVCiZv7PNBYqHEpNVWC2ZQ8BbfnFRQVESYOszFI2Wv82wnJRfN20VRS
# 3hpLgIR4hjzL0hpoYGk81coWJ+KdPvMvaB0WkE/2qHxJ0ucS638ZxqU14lDnki7C
# coKCz6eum5A19WZQHkqUJfdkDjHkccpL6uoG8pbF0LJAQQZxst7VvwDDjAmSFTUm
# s+wV/FbWBqi7fTJnjq3hj0XbQcd8hjj/q8d6ylgxCZSKi17yVp2NL+cnT6Toy+rN
# +nM8M7LnLqCrO2JP3oW//1sfuZDKiDEb1AQ8es9Xr/u6bDTnYCTKIsDq1BtmXUqE
# G1NqzJKS4kOmxkYp2WyODi7vQTCBZtVFJfVZ3j7OgWmnhFr4yUozZtqgPrHRVHhG
# NKlYzyjlroPxul+bgIspzOwbtmsgY1MCAwEAAaOCAV0wggFZMBIGA1UdEwEB/wQI
# MAYBAf8CAQAwHQYDVR0OBBYEFO9vU0rp5AZ8esrikFb2L9RJ7MtOMB8GA1UdIwQY
# MBaAFOzX44LScV1kTN8uZz/nupiuHA9PMA4GA1UdDwEB/wQEAwIBhjATBgNVHSUE
# DDAKBggrBgEFBQcDCDB3BggrBgEFBQcBAQRrMGkwJAYIKwYBBQUHMAGGGGh0dHA6
# Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBBBggrBgEFBQcwAoY1aHR0cDovL2NhY2VydHMu
# ZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZFJvb3RHNC5jcnQwQwYDVR0fBDww
# OjA4oDagNIYyaHR0cDovL2NybDMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3Rl
# ZFJvb3RHNC5jcmwwIAYDVR0gBBkwFzAIBgZngQwBBAIwCwYJYIZIAYb9bAcBMA0G
# CSqGSIb3DQEBCwUAA4ICAQAXzvsWgBz+Bz0RdnEwvb4LyLU0pn/N0IfFiBowf0/D
# m1wGc/Do7oVMY2mhXZXjDNJQa8j00DNqhCT3t+s8G0iP5kvN2n7Jd2E4/iEIUBO4
# 1P5F448rSYJ59Ib61eoalhnd6ywFLerycvZTAz40y8S4F3/a+Z1jEMK/DMm/axFS
# goR8n6c3nuZB9BfBwAQYK9FHaoq2e26MHvVY9gCDA/JYsq7pGdogP8HRtrYfctSL
# ANEBfHU16r3J05qX3kId+ZOczgj5kjatVB+NdADVZKON/gnZruMvNYY2o1f4MXRJ
# DMdTSlOLh0HCn2cQLwQCqjFbqrXuvTPSegOOzr4EWj7PtspIHBldNE2K9i697cva
# iIo2p61Ed2p8xMJb82Yosn0z4y25xUbI7GIN/TpVfHIqQ6Ku/qjTY6hc3hsXMrS+
# U0yy+GWqAXam4ToWd2UQ1KYT70kZjE4YtL8Pbzg0c1ugMZyZZd/BdHLiRu7hAWE6
# bTEm4XYRkA6Tl4KSFLFk43esaUeqGkH/wyW4N7OigizwJWeukcyIPbAvjSabnf7+
# Pu0VrFgoiovRDiyx3zEdmcif/sYQsfch28bZeUz2rtY/9TCA6TD8dC3JE3rYkrhL
# ULy7Dc90G6e8BlqmyIjlgp2+VqsS9/wQD7yFylIz0scmbKvFoW2jNrbM1pD2T7m3
# XDCCBY0wggR1oAMCAQICEA6bGI750C3n79tQ4ghAGFowDQYJKoZIhvcNAQEMBQAw
# ZTELMAkGA1UEBhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQ
# d3d3LmRpZ2ljZXJ0LmNvbTEkMCIGA1UEAxMbRGlnaUNlcnQgQXNzdXJlZCBJRCBS
# b290IENBMB4XDTIyMDgwMTAwMDAwMFoXDTMxMTEwOTIzNTk1OVowYjELMAkGA1UE
# BhMCVVMxFTATBgNVBAoTDERpZ2lDZXJ0IEluYzEZMBcGA1UECxMQd3d3LmRpZ2lj
# ZXJ0LmNvbTEhMB8GA1UEAxMYRGlnaUNlcnQgVHJ1c3RlZCBSb290IEc0MIICIjAN
# BgkqhkiG9w0BAQEFAAOCAg8AMIICCgKCAgEAv+aQc2jeu+RdSjwwIjBpM+zCpyUu
# ySE98orYWcLhKac9WKt2ms2uexuEDcQwH/MbpDgW61bGl20dq7J58soR0uRf1gU8
# Ug9SH8aeFaV+vp+pVxZZVXKvaJNwwrK6dZlqczKU0RBEEC7fgvMHhOZ0O21x4i0M
# G+4g1ckgHWMpLc7sXk7Ik/ghYZs06wXGXuxbGrzryc/NrDRAX7F6Zu53yEioZldX
# n1RYjgwrt0+nMNlW7sp7XeOtyU9e5TXnMcvak17cjo+A2raRmECQecN4x7axxLVq
# GDgDEI3Y1DekLgV9iPWCPhCRcKtVgkEy19sEcypukQF8IUzUvK4bA3VdeGbZOjFE
# mjNAvwjXWkmkwuapoGfdpCe8oU85tRFYF/ckXEaPZPfBaYh2mHY9WV1CdoeJl2l6
# SPDgohIbZpp0yt5LHucOY67m1O+SkjqePdwA5EUlibaaRBkrfsCUtNJhbesz2cXf
# SwQAzH0clcOP9yGyshG3u3/y1YxwLEFgqrFjGESVGnZifvaAsPvoZKYz0YkH4b23
# 5kOkGLimdwHhD5QMIR2yVCkliWzlDlJRR3S+Jqy2QXXeeqxfjT/JvNNBERJb5RBQ
# 6zHFynIWIgnffEx1P2PsIV/EIFFrb7GrhotPwtZFX50g/KEexcCPorF+CiaZ9eRp
# L5gdLfXZqbId5RsCAwEAAaOCATowggE2MA8GA1UdEwEB/wQFMAMBAf8wHQYDVR0O
# BBYEFOzX44LScV1kTN8uZz/nupiuHA9PMB8GA1UdIwQYMBaAFEXroq/0ksuCMS1R
# i6enIZ3zbcgPMA4GA1UdDwEB/wQEAwIBhjB5BggrBgEFBQcBAQRtMGswJAYIKwYB
# BQUHMAGGGGh0dHA6Ly9vY3NwLmRpZ2ljZXJ0LmNvbTBDBggrBgEFBQcwAoY3aHR0
# cDovL2NhY2VydHMuZGlnaWNlcnQuY29tL0RpZ2lDZXJ0QXNzdXJlZElEUm9vdENB
# LmNydDBFBgNVHR8EPjA8MDqgOKA2hjRodHRwOi8vY3JsMy5kaWdpY2VydC5jb20v
# RGlnaUNlcnRBc3N1cmVkSURSb290Q0EuY3JsMBEGA1UdIAQKMAgwBgYEVR0gADAN
# BgkqhkiG9w0BAQwFAAOCAQEAcKC/Q1xV5zhfoKN0Gz22Ftf3v1cHvZqsoYcs7IVe
# qRq7IviHGmlUIu2kiHdtvRoU9BNKei8ttzjv9P+Aufih9/Jy3iS8UgPITtAq3vot
# Vs/59PesMHqai7Je1M/RQ0SbQyHrlnKhSLSZy51PpwYDE3cnRNTnf+hZqPC/Lwum
# 6fI0POz3A8eHqNJMQBk1RmppVLC4oVaO7KTVPeix3P0c2PR3WlxUjG/voVA9/HYJ
# aISfb8rbII01YBwCA8sgsKxYoA5AY8WYIsGyWfVVa88nq2x2zm8jLfR+cWojayL/
# ErhULSd+2DrZ8LaHlv1b0VysGMNNn3O3AamfV6peKOK5lDGCA4wwggOIAgEBMH0w
# aTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEwPwYDVQQD
# EzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2IFNIQTI1
# NiAyMDI1IENBMQIQDCBDSfnQ91n7mC3kCBuIezANBglghkgBZQMEAgIFAKCB4TAa
# BgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI1MTAw
# MjE1NDMyM1owKwYLKoZIhvcNAQkQAgwxHDAaMBgwFgQUcrz9oBB/STSwBxxhD+bX
# llAAmHcwNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgMvPjsb2i17JtTx0bjN29j4uE
# dqF4ntYSzTyqep7/NcIwPwYJKoZIhvcNAQkEMTIEMBaPjcDeCuSt0IeALT59YpnU
# EstCoJ4tCamZzQ8Xy1CjynaT/0N5LarYQR3mwIzYoTANBgkqhkiG9w0BAQEFAASC
# AgAyi4OQom2jlN1dGcTEFcZ51jAFGjIoG1Ef4lTmZ11SEmvMwcG7/sjNRDIK2x/j
# Z0a8ozUQo7lj0U5781VJ98mssmZPrQsfxqMj06DozOscbFbb9sghb1hvXudj/Tuz
# 2qNoFB4XCkBd8OTY7dreCVVjkM/KATYysON+yuUv8AnFKA1Cy3Mk8SA/HWxOHRJt
# o5vQ5BkjaElVro6vG7wW+ZvAVFygjwJretp3N+cVzzx3ykBH7ET0G8SjFUHoLcr6
# 9jUFBKT9Znlxat3i5K8BFjfLEzFL793cegFK3EtPGNv/lNjyGT73DFH+QOQKti7U
# 1/NMSrnKnTDS8GO0zbRX+IHrZF7EZvuckwqH0ZicGzFiZIPQIiUCrgBB7ENy6MTA
# jdaHOovH3qdGtVuhmuyKFL/peGUw20PNFLZ0M8VMo6VXOk9AaEh7MxvnYH4Ek1oN
# NpCLr9eYG/N+sxxBOQqdlOEVSSpNAqhBKEBkU9NU3SP0YZ4uImGYkG5AoX+Zixnv
# r2OJMUFtQEKnR9kC5dh97I6ru+FCCUkFhSDhhim6zOa4vJYHbQP3IjmG8V+tybB7
# ORqGsUAzXxOqjz8OUXz3b7GQb1b/d09nu+UZ1WbLBkRS8LfVY/8cHtBJOuEZsbyL
# NsM14MRXgwDgYJ9ydt7X3S7+KmJ/3RC8CnSM5wwiFBK5Ww==
# SIG # End signature block
