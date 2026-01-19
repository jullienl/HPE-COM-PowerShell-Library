#------------------- FUNCTIONS FOR COMPUTE OPS MANAGEMENT JOBS -----------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1

# Public functions
function Wait-HPECOMJobComplete {
    <#
    .SYNOPSIS
    Wait for a job to complete.
    
    .DESCRIPTION    
    This blocking Cmdlet assists a caller with monitoring a specific job resource, and will wait for the given job to "complete" (get to a terminal state, including error) or timeout.  
    The Cmdlet accepts either the job URI or resource object via pipeline.
    Once the job is no longer in a running state, the cmlet will return the job resource object.  
    The caller should examine the taskState property/key for the final task status.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER Job
    Job URI or resource object  
    
    .PARAMETER Timeout
    Timeout in seconds before the cmdlet stops. Default is 300 seconds (5 minutes).

    .PARAMETER Interval
    Polling interval in seconds

    .EXAMPLE
    Get-HPECOMJob -Region us-west -ShowRunning | Wait-HPECOMJobComplete

    This example retrieves all job resources that are running in the western US region and waits for them to complete.

    .EXAMPLE
    Wait-HPECOMJobComplete -Region us-west -Job '/compute-ops-mgmt/v1beta3/jobs/1649bcb6-6362-44bf-a737-8caa5142be6e' 

    .EXAMPLE
    Stop-HPECOMserver -Region us-west -Name HOL58 -Async | Wait-HPECOMJobComplete 

    .EXAMPLE
    '/compute-ops-mgmt/v1beta3/jobs/1649bcb6-6362-44bf-a737-8caa5142be6e', '/compute-ops-mgmt/v1beta3/jobs/e8b39555-1dd0-4baf-8f62-bc39d584d8f3' | Wait-HPECOMJobComplete -Region us-west 
    
    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the job URIs.
    System.Collections.ArrayList
        A job from one of the cmdlets creating a job or a list of jobs retrieved using 'Get-HPECOMJob'.

    .OUTPUTS
    HPEGreenLake.COM.Jobs [System.Management.Automation.PSCustomObject]
                
    #>

    [CmdletBinding ()]
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

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [Alias ('resourceUri', 'jobUri')]
        [Object]$Job,

        # Timeout in seconds
        [Parameter (Mandatory = $false)]
        [int]$Timeout = 300, # $DefaultTimeout,

        # Polling interval in seconds
        [int]$Interval = 5

    )

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $startTime = Get-Date
        $endTime = $startTime.AddSeconds($Timeout)
        $jobState = ""
        $jobResource = $null
        # $jobResourceSN = $null
        $percentComplete = 0

        $JobCollection = [System.Collections.ArrayList]::new()
        
    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Validate the job object

        "[{0}] Job object type is: $($Job.GetType())" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose


        if (($Job -is [String]) -and ($Job.StartsWith((Get-COMJobsUri)))) {

            "[{0}] Processing job resource uri: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Job | Write-Verbose       
    
            $Uri = $Job

        }

        elseif (($Job -is [String]) -and ($Job.StartsWith((Get-COMJobsv1beta3Uri)))) {

            "[{0}] Processing job resource uri: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Job | Write-Verbose       
    
            $Uri = $Job

        }

        elseif ($Job -is [PSCustomObject] -and $Job.type -ieq 'compute-ops-mgmt/job') {

            "[{0}] Job is $($Job.GetType()). Job URI: $($Job.resourceUri)" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

            $Uri = $Job.resourceUri

        }
        elseif (($Job -is [String]) -and ($Job.StartsWith((Get-COMSchedulesUri)))) {

            $ErrorMessage = "Invalid job resource provided. You cannot use 'Wait-HPECOMJobComplete' with a Schedule resource type."         
            Write-Error $ErrorMessage
            return

        }    
        else {

            $ErrorMessage = "Invalid job resourceUri provided. Please verify the job object you are passing and try again."         
            Write-Error $ErrorMessage
            return

        }    

        while ($true) {

            # Update the progress bar
            $elapsedTime = (Get-Date) - $startTime
            $percentComplete = [math]::Min((($elapsedTime.TotalSeconds / $Timeout) * 100), 100)
            
            
            try {
                
                $jobResource = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method GET -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                
                "[{0}] Get job raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $jobResource | Write-Verbose
                
                
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
                
            }                                
            
            # Extract job state from the resource object
            $jobState = $jobResource.State
            
            if ($jobResource.associatedResourceId -like "*+*") {
                
                $_jobResource = ($jobResource.associatedResourceId -split "\+")[-1]

                Write-Progress -Activity "Waiting for job completion" `
                    -Status "$_jobResource - Current state: $jobState" `
                    -PercentComplete $percentComplete
            }
            else {

                Write-Progress -Activity "Waiting for job completion" `
                    -Status "Current state: $jobState" `
                    -PercentComplete $percentComplete

            }
          

            "[{0}] Current job state: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $jobState | Write-Verbose
            
            if ($jobState -match "COMPLETE|ERROR|STALLED") {

                Write-Progress -Activity "Job completion" -Status "Failed" -Completed
                break
            }

            if ((Get-Date) -ge $endTime) {
                # throw "Timeout reached waiting for job to complete."
                $errorMessage = "Timeout reached waiting for job '{0}' to complete." -f $jobResource.name
                $errorRecord = New-ErrorRecord TimeoutError OperationTimeout -Message $ErrorMessage 
                Write-Progress -Activity "Job timeout reached" -Status "Failed" -Completed
                $PSCmdlet.ThrowTerminatingError($ErrorRecord )
            }

            Start-Sleep -Seconds $Interval
        }

        Write-Progress -Activity "Job has reached terminal state" -Status "Completed" -Completed
        "[{0}] Job has reached terminal state: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $jobState | Write-Verbose
        "[{0}] Job URI: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $jobResource.resourceuri | Write-Verbose

        # Get activity resource message generated by the job        
        $_Message = Get-HPECOMActivity -Region $Region -JobResourceUri $jobResource.resourceuri | Select-Object -ExpandProperty formattedmessage

        # Add message to object
        $jobResource | Add-Member -type NoteProperty -name message -value $_Message

        [void]$JobCollection.Add($jobResource)

    }

    End {

        $ReturnData = Invoke-RepackageObjectWithType -RawObject $JobCollection -ObjectName "COM.Jobs"    

        return $ReturnData 

    }
}

Function Get-HPECOMJob {
    <#
    .SYNOPSIS
    Retrieve the list of jobs.

    .DESCRIPTION
    This Cmdlet returns a collection of the last seven days jobs that are available in the specified region.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER JobResourceUri
    Optional parameter that can be used to specify the Uri of a job to display.
    
    .PARAMETER Name
    Optional parameter that can be used to specify the name of a job to display.

    .PARAMETER Category 
    Optional parameter that can be used to display the jobs of a specific category. Auto-completion (Tab key) is supported for this parameter, providing a list of categories.
    
    .PARAMETER ShowRunning
    Optional switch parameter that can be used to display only running jobs.
    
    .PARAMETER ShowPending
    Optional switch parameter that can be used to display only pending jobs.
    
    .PARAMETER ShowLastMonth
    Optional switch parameter that can be used to display the jobs of the last month.  

    .PARAMETER ShowAll
    This switch parameter can be used to display the total number of jobs. Be aware, however, that this may take some time, depending on your history.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMJob -Region us-west 

    Return the last seven days jobs resources located in the western US region.

    .EXAMPLE
    Get-HPECOMJob -Region eu-central -Name IloOnlyFirmwareUpdate

    Return the last seven days jobs resources named 'IloOnlyFirmwareUpdate' located in the central EU region.

    .EXAMPLE
    Get-HPECOMJob -Region us-west -ShowLastMonth

    Return the last month jobs resources located in the western US region.

    .EXAMPLE
    Get-HPECOMJob -Region eu-central -Category server

    Return the last seven days jobs resources of type 'server' located in the central EU region. 

    .EXAMPLE
    Get-HPECOMJob -Region eu-central -Category server -ShowLastMonth 

    Return the last month jobs resources of type 'server' located in the central EU region.

    .EXAMPLE
    Get-HPECOMJob -Region eu-central -Category Analyze -ShowAll

    Return all jobs resources of type 'Analyze' located in the western US region.

    .EXAMPLE
    Get-HPECOMJob -Region us-west -ShowAll

    Return all jobs resources located in the western US region. 

    .EXAMPLE
    Get-HPECOMJob -Region us-west -JobResourceUri '/compute-ops-mgmt/v1beta3/jobs/1649bcb6-6362-44bf-a737-8caa5142be6e'

    Return the job resource with the specified resource URI located in the western US region. 

    .EXAMPLE
    $job = Update-HPECOMServeriLOFirmware -Region eu-central -ServerSerialNumber CZJ1233444 -Async
    $job | Get-HPECOMJob 
    $job | Get-HPECOMActivity 
    $job | Wait-HPECOMJobComplete

    This example retrieves the job resource created by the 'Update-HPECOMServeriLOFirmware' cmdlet in the central EU region.
    Then it retrieves the activity resource associated with the job.
    Then it waits for the job to complete.

    .INPUTS
    System.Collections.ArrayList
        A job from one of the cmdlets creating a job.
        
    
   #>
    [CmdletBinding(DefaultParameterSetName = "JobResourceUri")]
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

        [Parameter (ParameterSetName = 'ShowPending')]
        [Parameter (ParameterSetName = 'ShowRunning')]
        [Parameter (ParameterSetName = 'ShowLastMonth')]
        [Parameter (ParameterSetName = 'ShowLastThreeMonths')]
        [Parameter (ParameterSetName = 'ShowAll')]
        [Parameter (ParameterSetName = 'JobResourceUri')]
        [String]$Name,
        
        # Pipeline is supported but it requires to change the default parameter set to JobResourceUri but then 
        # it generates an error when -Name and -Category parameters are used alone as the parameter set name cannot then be identified. 
        # So I had to add the parameter set name JobResourceUri to the -Name and -Category parameters to avoid this issue + clear the $Name PS bound parameter if pipeline input
        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'JobResourceUri')]
        [Alias('jobUri', 'resourceUri')]
        [string]$JobResourceUri,

        [Parameter (ParameterSetName = 'ShowPending')]
        [Parameter (ParameterSetName = 'ShowRunning')]
        [Parameter (ParameterSetName = 'ShowLastMonth')]
        [Parameter (ParameterSetName = 'ShowLastThreeMonths')]
        [Parameter (ParameterSetName = 'ShowAll')]
        [Parameter (ParameterSetName = 'JobResourceUri')]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Analyze', 'Filter', 'Group', 'Oneview-appliance', 'Report', 'Server', 'Server-hardware', 'Setting')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Analyze', 'Filter', 'Group', 'Oneview-appliance', 'Report', 'Server', 'Server-hardware', 'Setting')]
        [string]$Category,
        
        [Parameter (ParameterSetName = 'ShowRunning')]
        [Switch]$ShowRunning,
        
        [Parameter (ParameterSetName = 'ShowPending')]
        [Switch]$ShowPending,
        
        [Parameter (ParameterSetName = 'ShowLastMonth')]
        [Switch]$ShowLastMonth,

        [Parameter (ParameterSetName = 'ShowLastThreeMonths')]
        [Switch]$ShowLastThreeMonths,

        [Parameter (ParameterSetName = 'ShowAll')]
        [Switch]$ShowAll,

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command
  
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        # Validate the job object

        if ($JobResourceUri) {

            if ($JobResourceUri -match '^/compute-ops-mgmt/[^/]+/jobs/[^/]+$') {

                "[{0}] Processing job resource uri: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $JobResourceUri | Write-Verbose       

            }

            else {

                $ErrorMessage = "Invalid job resourceUri provided. Please verify the job object you are passing and try again."         
                $ErrorRecord = New-ErrorRecord InvalidResourceUri InvalidArgument -TargetObject 'Job' -Message $ErrorMessage -TargetType $JobResourceUri.GetType().Name
                $PSCmdlet.ThrowTerminatingError($ErrorRecord )

            }  
        }

        # Get today's date in ISO 8601 format (UTC)
        $todayMinusSevenDays = (Get-Date).AddDays(-7).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ") 
        $todayMinusOneMonth = (Get-Date).AddMonths(-1).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")
        $todayMinusThreeMonths = (Get-Date).AddMonths(-3).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

        # Construct the filter query
        $filterSevenDays = "createdAt gt $todayMinusSevenDays"
        $filterOneMonth = "createdAt gt $todayMinusOneMonth"
        $filterThreeMonths = "createdAt gt $todayMinusThreeMonths"


    }
    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # If pipeline input, then don't take name PS bound parameter into account as it stores the name of the job and not the displayName of a resource
        if ($JobResourceUri) {
            $Name = $null
        }

        # Determine the base URI
        $Uri = if ($JobResourceUri) {
            "[{0}] Processing job resource uri: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $JobResourceUri | Write-Verbose
            $JobResourceUri
        }
        else {
            Get-COMJobsUri
        }

        # Helper function to add a filter to the URI
        function Add-FilterToUri {
            param (
                [string]$Uri,
                [string]$Filter
            )
            if ($Uri -match "\?") {
                if ($Uri -match "filter") {
                    $Uri + " and $Filter"
                }
                else {
                    $Uri + "&filter=$Filter"
                }
            }
            else {
                $Uri + "?filter=$Filter"
            }
        }

        # Add filters based on parameters
        if ($Name) {
            $Uri = Add-FilterToUri -Uri $Uri -Filter "name eq '$Name'"
        }

        if ($ShowRunning) {
            $Uri = Add-FilterToUri -Uri $Uri -Filter "state eq 'RUNNING'"
        }
        elseif ($ShowPending) {
            $Uri = Add-FilterToUri -Uri $Uri -Filter "state eq 'PENDING'"
        }

        # Filter 7 days except for the other cases
        if (-not $ShowAll -and -not $JobResourceUri -and -not $ShowRunning -and -not $ShowPending -and -not $ShowLastMonth -and -not $ShowLastThreeMonths) {
            $Uri = Add-FilterToUri -Uri $Uri -Filter $filterSevenDays
        }
        # Filter 1 month
        elseif ($ShowLastMonth) {
            $Uri = Add-FilterToUri -Uri $Uri -Filter $filterOneMonth
        } 
        # Filter 3 months
        elseif ($ShowLastThreeMonths) {
            $Uri = Add-FilterToUri -Uri $Uri -Filter $filterThreeMonths
        }
        elseif ($ShowAll) {
            # No filter
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
            # Add category to object
            $CollectionList | ForEach-Object { $_ | Add-Member -type NoteProperty -name Category -value $_.resource.type }
                       
            if ($Category) {

                $CollectionList = $CollectionList | Where-Object Category -match $Category

            }

            $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Jobs"    
            $ReturnData = $ReturnData | Sort-Object -Property createdAt -Descending
        
            return $ReturnData 
                
        }
        else {

            return
                
        }     

    
    }
}

Function Start-HPECOMserver {
    <#
    .SYNOPSIS
    Power on a server resource.

    .DESCRIPTION
    This cmdlet initiates the power-on operation for a server using the virtual power button.
    It provides options for scheduling the execution at a specific time and setting recurring schedules.

    .PARAMETER Region 
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the server is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER ServerSerialNumber 
    Specifies the serial number of the server to power on. 

    .PARAMETER ScheduleTime
    Specifies the date and time when the power-on operation should be executed. 
    This parameter accepts a DateTime object or a string representation of a date and time. 
    If not specified, the power-on operation will be executed immediately.

    Examples for setting the date and time using `Get-Date`:
    - (Get-Date).AddMonths(6)
    - (Get-Date).AddDays(15)
    - (Get-Date).AddHours(3)
    Example for using a specific date string:
    - "2024-05-20 08:00:00"

    .PARAMETER Interval
    Specifies the interval at which the power-on operation should be repeated. This parameter accepts a TimeSpan object or a string representation of a time interval. 
    If not specified, the power-on operation will not be repeated.
    
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
    Start-HPECOMserver -Region us-west -ServerSerialNumber CZ12312312
    
    This command powers on the server with the serial number 'CZ12312312' and waits for the job to complete before returning the job resource object. 

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-2  | Start-HPECOMserver -Async

    This command powers on the server named 'ESX-2' and immediately returns the asynchronous job resource to monitor.

    .EXAMPLE
    Get-HPECOMServer -Region us-west -PowerState OFF -ConnectionType Direct | Start-HPECOMserver 

    This command powers on all servers in the 'us-west' region that are currently powered off and are directly managed (not OneView managed, as power controls are unsupported).

    .EXAMPLE
    "CZ12312312", "DZ12312312" | Start-HPECOMserver -Region eu-central

    This command powers on the servers with the serial numbers 'CZ12312312' and 'DZ12312312' in the `eu-central` region.

    .EXAMPLE
    Start-HPECOMserver -Region eu-central -ServerSerialNumber CZ12312312 -ScheduleTime (Get-Date).AddHours(6)  

    This command schedules a power on operation for the server with the serial number 'CZ12312312' in the `eu-central` region to occur six hours from the current time. 

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name CZ12312312 | Start-HPECOMserver -ScheduleTime (Get-Date).AddDays(2)
  
    This command retrieves the server with the serial number 'CZ12312312' in the `eu-central` region and schedules a power on to occur two days from the current date.
    
    .EXAMPLE
    Start-HPECOMserver -Region eu-central -ServerSerialNumber CZ12312312 -ScheduleTime (Get-Date).AddHours(6) -Interval P1W
 
    Schedules a weekly power-on operation for the server with serial number 'CZ12312312' in the `eu-central` region. The first execution will occur six hours from the current time.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.

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
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ScheduleSerialNumber')]
        [Alias('serial', 'serialnumber')]
        [String]$ServerSerialNumber,

        [Parameter (Mandatory, ParameterSetName = 'ScheduleSerialNumber')]
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
            # Validate ISO 8601 duration format
            if ($_ -notmatch '^P(?!$)(\d+Y)?(\d+M)?(\d+W)?(\d+D)?(T(\d+H)?(\d+M)?(\d+S)?)?$') {
                throw "Invalid duration format. Please use an ISO 8601 period interval (e.g., P1D, P1W, P1M, P1Y, PT1H, PT15M)"
            }

            # Extract duration parts
            $years   = [int]($matches[1] -replace '\D', '')  # Y
            $months  = [int]($matches[2] -replace '\D', '')  # M (before T)
            $weeks   = [int]($matches[3] -replace '\D', '')  # W
            $days    = [int]($matches[4] -replace '\D', '')  # D
            $hours   = [int]($matches[6] -replace '\D', '')  # H
            $minutes = [int]($matches[7] -replace '\D', '')  # M (after T)
            $seconds = [int]($matches[8] -replace '\D', '')  # S

            # Calculate total duration in seconds (approximate months/years)
            $totalSeconds = 0
            if ($years)   { $totalSeconds += $years * 365 * 24 * 3600 }
            if ($months)  { $totalSeconds += $months * 30 * 24 * 3600 }
            if ($weeks)   { $totalSeconds += $weeks * 7 * 24 * 3600 }
            if ($days)    { $totalSeconds += $days * 24 * 3600 }
            if ($hours)   { $totalSeconds += $hours * 3600 }
            if ($minutes) { $totalSeconds += $minutes * 60 }
            if ($seconds) { $totalSeconds += $seconds }

            $minSeconds = 15 * 60
            $maxSeconds = 365 * 24 * 3600  # 1 year

            if ($totalSeconds -lt $minSeconds) {
                throw "The interval must be greater than 15 minutes (PT15M)."
            }
            if ($totalSeconds -gt $maxSeconds) {
                throw "The interval must be less than 1 year (P1Y)."
            }
            return $true
        })]
        [Parameter (ParameterSetName = 'ScheduleSerialNumber')]
        [String]$Interval,    

        [Parameter (ParameterSetName = 'SerialNumber')]
        [switch]$Async,

        [Switch]$WhatIf
    ) 
    
    Begin {

        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
        
        $_JobTemplateName = 'PowerOn.New'
        
        $JobTemplateUri = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object resourceuri
        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id
        
        $Uri = Get-COMJobsUri  
        
        $ObjectStatusList = [System.Collections.ArrayList]::new()
        
        $Timeout = 420 # Default timeout of 7 minutes
    }
    
    Process {
        
        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
                
        # Build tracking object for a schedule output
        if ($ScheduleTime) {

            $objStatus = [pscustomobject]@{
                name               = $Null
                description        = "Scheduled task to power on server '$ServerSerialNumber'"
                associatedResource = $ServerSerialNumber
                purpose            = "SERVER_POWER_ON"
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
                associatedResource = $ServerSerialNumber
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

        # Add tracking object to the list of object status list
        [void]$ObjectStatusList.Add($objStatus)

    }

    end {

        try {
            if ($Region) {
                $Servers = Get-HPECOMServer -Region $Region
            }
            else {
                return
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

         
        foreach ($Resource in $ObjectStatusList) {
            
            $Server = $Servers | Where-Object serialNumber -eq $Resource.associatedResource
              
            if (-not $Server) {

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Server cannot be found in the Compute Ops Management instance!"

                }
                else {

                    $Resource.state = "ERROR"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Failed"
                    $Resource.message = "Server cannot be found in the Compute Ops Management instance!"
                }
                
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Resource.associatedResource
                    Write-warning $ErrorMessage
                    continue
                }
            } 
            elseif ($Server.hardware.powerState -eq "ON") {

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Server requested power state is already on!"

                }
                else {
                    
                    $Resource.state = "ERROR"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Failed"
                    $Resource.message = "Server requested power state is already on!"
                }
                
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Requested power state is already on!" -f $Resource.associatedResource
                    Write-warning $ErrorMessage
                    continue
                }
            }
            else {       
        
                $_serverId = $Server.id
                $_serverResourceUri = $Server.resourceUri
                
                # Build payload

                if ($ScheduleTime) {

                    $Uri = Get-COMSchedulesUri

                    $_Body = @{
                        jobTemplateUri = "/api/compute/v1/job-templates/" + $JobTemplateId
                        resourceUri    = $_serverResourceUri
                        # data           = $data
                    }    
    
                    $Operation = @{
                        type   = "REST"
                        method = "POST"
                        uri    = "/api/compute/v1/jobs"
                        body   = $_Body
    
                    }
    
                    $randomNumber = Get-Random -Minimum 000000 -Maximum 999999
    
                    $Name = "$($ServerSerialNumber)_ServerPowerOn_Schedule_$($randomNumber)"
                    $Resource.name = $Name 

                    $Description = $Resource.description
    
    
                    if ($Interval) {
                        
                        $Schedule = @{
                            startAt  = $ScheduleTime.ToString("o")  # Convert to ISO 8601 format as $ScheduleTime alone is converted by PS5.1 to '/Date(...)\/ notation'
                            interval = $Interval
                        }
                    }
                    else {
    
                        $Schedule = @{
                            startAt  = $ScheduleTime.ToString("o")  # Convert to ISO 8601 format as $ScheduleTime alone is convert by PS5.1 to '/Date(...)\/ notation'
                            interval = $Null
                        }
                    }

                    $Resource.schedule = $Schedule 
    
                    $Payload = @{
                        name                  = $Name
                        description           = $Description
                        associatedResourceUri = $_serverResourceUri
                        purpose               = "SERVER_POWER_ON"
                        schedule              = $Schedule
                        operation             = $Operation
    
                    }
    
                }
                else {
                    
                    $payload = @{
                        jobTemplate = $JobTemplateId
                        resourceId   = $_serverId
                        resourceType = "compute-ops-mgmt/server"
                        jobParams = @{}
                    }
                    
                }          
                
                $payload = ConvertTo-Json $payload -Depth 10


                try {
        
                    $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference      

                    if ($ScheduleTime) {

                        if (-not $WhatIf) {
        
                            "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
                            
                            $Resource.name = $_resp.name
                            $Resource.id = $_resp.id
                            $Resource.nextStartAt = $_resp.nextStartAt
                            $Resource.lastRun = $_resp.lastRun
                            $Resource.scheduleUri = $_resp.resourceUri
                            $Resource.schedule = $Schedule
                            $Resource.lastRun = $_resp.lastRun
                            $Resource.resultCode = "SUCCESS"
                            $Resource.details = $_resp
                            $Resource.message = "The schedule to power on the server has been successfully created."
    
                        }
    
                    }
                    else {

                        if (-not $WhatIf -and -not $Async) {    
                             
                            "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose
            
                            $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout
            
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
        
                            $Resource.state = $_resp.state
                            $Resource.duration = $Duration
                            $Resource.resultCode = $_resp.resultCode
                            $Resource.message = $_resp.message
                            $Resource.status = $_resp.Status
                            $Resource.details = $_resp
                            $Resource.jobUri = $_resp.resourceUri        
                            
                        }
                    }
                    
                    "[{0}] Resource content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Resource | Write-Verbose

                }
                catch {
        
                    if (-not $WhatIf) {
                        
                        if ($ScheduleTime) {
                            
                            $Resource.name = $Name
                            $Resource.schedule = $Schedule
                            $Resource.resultCode = "FAILURE"
                            $Resource.message = $_.Exception.Message -replace "`r`n", " " -replace "`n", " " -replace "`r", " "

                        }
                        else {
                            
                            $Resource.state = "ERROR"
                            $Resource.duration = '00:00:00'
                            $Resource.resultCode = "FAILURE"
                            $Resource.status = "Failed"
                            $Resource.message = $_.Exception.Message -replace "`r`n", " " -replace "`n", " " -replace "`r", " "
                        }      
                    }
                }  
            }
        }
        
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

Function Restart-HPECOMserver {
    <#
    .SYNOPSIS
    Restart a server resource.

    .DESCRIPTION
    This cmdlet initiates a server restart, performing a warm boot that resets the CPUs and I/O resources. 
    It provides options for scheduling the restart at a specific time and setting recurring schedules.
    
    A warm-boot means that the server is restarted without completely powering it off. The system performs a reset of the CPUs and I/O resources while keeping the power on. 
    This type of reboot is quicker than a cold boot (where the system is completely powered off and then turned back on).
        
    During the warm boot, CPUs and I/O resources of the server are reset. This helps to clear any temporary issues or states that might be affecting the server's performance or stability.
        
    Note: This operation bypasses the operating system's graceful shutdown features. A graceful shutdown allows the operating system to close all running applications 
          and processes properly, saving any necessary data and ensuring that the system is in a consistent state before shutting down. By forcing a warm boot, this cmdlet 
          bypasses these graceful shutdown procedures, which means that any unsaved data or open applications may be lost, and the system may not be in a consistent state when it restarts.
            
    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the server is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER ServerSerialNumber 
    Specifies the serial number of the server to restart. 

    .PARAMETER ScheduleTime
    Specifies the date and time when the server restart operation should be executed. 
    This parameter accepts a DateTime object or a string representation of a date and time. 
    If not specified, the server restart operation will be executed immediately.

    Examples for setting the date and time using `Get-Date`:
    - (Get-Date).AddMonths(6)
    - (Get-Date).AddDays(15)
    - (Get-Date).AddHours(3)
    Example for using a specific date string:
    - "2024-05-20 08:00:00"

    .PARAMETER Interval
    Specifies the interval at which the server restart operation should be repeated. This parameter accepts a TimeSpan object or a string representation of a time interval. 
    If not specified, the server restart operation will not be repeated.

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
    Restart-HPECOMserver -Region us-west -ServerSerialNumber CZ12312312
    
    This command restarts the server with the serial number 'CZ12312312' and waits for the job to complete then return the job resource object. 

    .EXAMPLE
    Restart-HPECOMserver -Region us-west -ServerSerialNumber CZ12312312 -Async 

    This command restarts the server with the serial number 'CZ12312312' and immediately returns the asynchronous job resource to monitor.
    
    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-2  | Restart-HPECOMserver -Async

    This command restarts the server named 'ESX-2' and immediately returns the asynchronous job resource to monitor.

    .EXAMPLE
    Get-HPECOMServer -Region us-west -PowerState ON -ConnectionType Direct | Restart-HPECOMserver 

    This command restarts on all servers in the 'us-west' region that are currently powered on and are directly managed (not OneView managed, as power controls are unsupported).
    
    .EXAMPLE
    "CZ12312312", "DZ12312312" | Restart-HPECOMserver -Region eu-central

    This command restarts the servers with the serial numbers 'CZ12312312' and 'DZ12312312' in the `eu-central` region.

    .EXAMPLE
    Restart-HPECOMserver -Region eu-central -ServerSerialNumber CZ12312312 -ScheduleTime (Get-Date).AddHours(6)  

    This command schedules a restart operation for the server with the serial number 'CZ12312312' in the `eu-central` region to occur six hours from the current time. 

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name CZ12312312 | Restart-HPECOMserver -ScheduleTime (Get-Date).AddDays(2)
  
    This command retrieves the server with the serial number 'CZ12312312' in the `eu-central` region and schedules a restart to occur two days from the current date.

    .EXAMPLE
    Restart-HPECOMserver -Region eu-central -ServerSerialNumber CZ12312312 -ScheduleTime (Get-Date).AddHours(6) -Interval P1W
 
    Schedules a weekly restart operation for the server with serial number 'CZ12312312' in the `eu-central` region. The first execution will occur six hours from the current time.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.

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
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ScheduleSerialNumber')]
        [Alias('serial', 'serialnumber')]
        [String]$ServerSerialNumber,

        [Parameter (Mandatory, ParameterSetName = 'ScheduleSerialNumber')]
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
            # Validate ISO 8601 duration format
            if ($_ -notmatch '^P(?!$)(\d+Y)?(\d+M)?(\d+W)?(\d+D)?(T(\d+H)?(\d+M)?(\d+S)?)?$') {
                throw "Invalid duration format. Please use an ISO 8601 period interval (e.g., P1D, P1W, P1M, P1Y, PT1H, PT15M)"
            }

            # Extract duration parts
            $years   = [int]($matches[1] -replace '\D', '')  # Y
            $months  = [int]($matches[2] -replace '\D', '')  # M (before T)
            $weeks   = [int]($matches[3] -replace '\D', '')  # W
            $days    = [int]($matches[4] -replace '\D', '')  # D
            $hours   = [int]($matches[6] -replace '\D', '')  # H
            $minutes = [int]($matches[7] -replace '\D', '')  # M (after T)
            $seconds = [int]($matches[8] -replace '\D', '')  # S

            # Calculate total duration in seconds (approximate months/years)
            $totalSeconds = 0
            if ($years)   { $totalSeconds += $years * 365 * 24 * 3600 }
            if ($months)  { $totalSeconds += $months * 30 * 24 * 3600 }
            if ($weeks)   { $totalSeconds += $weeks * 7 * 24 * 3600 }
            if ($days)    { $totalSeconds += $days * 24 * 3600 }
            if ($hours)   { $totalSeconds += $hours * 3600 }
            if ($minutes) { $totalSeconds += $minutes * 60 }
            if ($seconds) { $totalSeconds += $seconds }

            $minSeconds = 15 * 60
            $maxSeconds = 365 * 24 * 3600  # 1 year

            if ($totalSeconds -lt $minSeconds) {
                throw "The interval must be greater than 15 minutes (PT15M)."
            }
            if ($totalSeconds -gt $maxSeconds) {
                throw "The interval must be less than 1 year (P1Y)."
            }
            return $true
        })]
        [Parameter (ParameterSetName = 'ScheduleSerialNumber')]
        [String]$Interval,    

        [Parameter (ParameterSetName = 'SerialNumber')]
        [switch]$Async,

        [Switch]$WhatIf
    ) 


    Begin {
        
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
        
        $_JobTemplateName = 'Restart.New'

        $JobTemplateUri = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object resourceuri
        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $Uri = Get-COMJobsUri  

        $ObjectStatusList = [System.Collections.ArrayList]::new()

        $Timeout = 420 # Default timeout of 7 minutes

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        
        # Build tracking object for a schedule output
        if ($ScheduleTime) {

            $objStatus = [pscustomobject]@{
                name               = $Null
                description        = "Scheduled task to restart server '$ServerSerialNumber'"
                associatedResource = $ServerSerialNumber
                purpose            = "SERVER_RESTART"
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
                associatedResource = $ServerSerialNumber
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

        # Add tracking object to the list of object status list
        [void]$ObjectStatusList.Add($objStatus)

    }

    end {

        try {
            if ($Region) {
                $Servers = Get-HPECOMServer -Region $Region
            }
            else {
                return
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

         
        foreach ($Resource in $ObjectStatusList) {
            
            $Server = $Servers | Where-Object serialNumber -eq $Resource.associatedResource
              
            if (-not $Server) {

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Server cannot be found in the Compute Ops Management instance!"

                }
                else {

                    $Resource.state = "ERROR"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Failed"
                    $Resource.message = "Server cannot be found in the Compute Ops Management instance!"
                }
                
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Resource.associatedResource
                    Write-warning $ErrorMessage
                    continue
                }
            } 
            elseif ($Server.hardware.powerState -eq "OFF") {

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Server power state must be ON to be restarted."

                }
                else {
                    
                    $Resource.state = "ERROR"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Failed"
                    $Resource.message = "Server power state must be ON to be restarted."
                }
                
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Power state must be ON to be restarted." -f $Resource.associatedResource
                    Write-warning $ErrorMessage
                    continue
                }
            }
            else {       
        
                $_serverId = $Server.id
                $_serverResourceUri = $Server.resourceUri

                # Build payload

                if ($ScheduleTime) {

                    $Uri = Get-COMSchedulesUri
    
                    $_Body = @{
                        jobTemplateUri = "/api/compute/v1/job-templates/" + $JobTemplateId
                        resourceUri    = $_serverResourceUri
                        # data           = $data
                    }      
    
                    $Operation = @{
                        type   = "REST"
                        method = "POST"
                        uri    = "/api/compute/v1/jobs"
                        body   = $_Body
    
                    }
    
                    $randomNumber = Get-Random -Minimum 000000 -Maximum 999999
    
                    $Name = "$($ServerSerialNumber)_ServerRestart_Schedule_$($randomNumber)"
                    $Resource.name = $Name 

                    $Description = $Resource.description
    
    
                    if ($Interval) {
                        
                        $Schedule = @{
                            startAt  = $ScheduleTime.ToString("o")  # Convert to ISO 8601 format as $ScheduleTime alone is converted by PS5.1 to '/Date(...)\/ notation'
                            interval = $Interval
                        }
                    }
                    else {
    
                        $Schedule = @{
                            startAt  = $ScheduleTime.ToString("o")  # Convert to ISO 8601 format as $ScheduleTime alone is convert by PS5.1 to '/Date(...)\/ notation'
                            interval = $Null
                        }
                    }

                    $Resource.schedule = $Schedule 
    
                    $Payload = @{
                        name                  = $Name
                        description           = $Description
                        associatedResourceUri = $_serverResourceUri
                        purpose               = "SERVER_RESTART"
                        schedule              = $Schedule
                        operation             = $Operation
    
                    }
    
                }
                else {
                    
                    $payload = @{
                        jobTemplate = $JobTemplateId
                        resourceId   = $_serverId
                        resourceType = "compute-ops-mgmt/server"
                        jobParams = @{}
                    }
                    
                }          
                
                $payload = ConvertTo-Json $payload -Depth 10 


                try {
        
                    $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference      

                    if ($ScheduleTime) {

                        if (-not $WhatIf) {
        
                            "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
                            
                            $Resource.name = $_resp.name
                            $Resource.id = $_resp.id
                            $Resource.nextStartAt = $_resp.nextStartAt
                            $Resource.lastRun = $_resp.lastRun
                            $Resource.scheduleUri = $_resp.resourceUri
                            $Resource.schedule = $Schedule
                            $Resource.lastRun = $_resp.lastRun
                            $Resource.resultCode = "SUCCESS"
                            $Resource.details = $_resp
                            $Resource.message = "The schedule to restart the server has been successfully created."
    
                        }
    
                    }
                    else {

                        if (-not $WhatIf -and -not $Async) {    
                             
                            "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose
            
                            $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout
            
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
    
                            $Resource.state = $_resp.state
                            $Resource.duration = $Duration
                            $Resource.resultCode = $_resp.resultCode
                            $Resource.message = $_resp.message
                            $Resource.status = $_resp.Status
                            $Resource.details = $_resp
                            $Resource.jobUri = $_resp.resourceUri        
                            
                        }
                    }
                    
                    "[{0}] Resource content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Resource | Write-Verbose

                }
                catch {
        
                    if (-not $WhatIf) {
                        
                        if ($ScheduleTime) {

                            $Resource.name = $Name
                            $Resource.schedule = $Schedule
                            $Resource.resultCode = "FAILURE"
                            $Resource.message = $_.Exception.Message -replace "`r`n", " " -replace "`n", " " -replace "`r", " "

                        }
                        else {
                            
                            $Resource.state = "ERROR"
                            $Resource.duration = '00:00:00'
                            $Resource.resultCode = "FAILURE"
                            $Resource.status = "Failed"
                            $Resource.message = $_.Exception.Message -replace "`r`n", " " -replace "`n", " " -replace "`r", " "
                        }      
                    }
                }  
            }
        }
        
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

Function Stop-HPECOMserver {
    <#
    .SYNOPSIS
    Power off a server resource.

    .DESCRIPTION
    This cmdlet initiates a graceful shutdown of a server using the virtual power button. It also provides options for scheduling the shutdown at a specific time and setting recurring schedules.

    Note: If the operating system does not shut down gracefully, this cmdlet will forcibly power off the server using the force-off option.
            
    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the server is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER ServerSerialNumber 
    Specifies the serial number of the server to power off. 

    .PARAMETER ScheduleTime
    Specifies the date and time when the power off operation should be executed. 
    This parameter accepts a DateTime object or a string representation of a date and time. 
    If not specified, the power off operation will be executed immediately.

    Examples for setting the date and time using `Get-Date`:
    - (Get-Date).AddMonths(6)
    - (Get-Date).AddDays(15)
    - (Get-Date).AddHours(3)
    Example for using a specific date string:
    - "2024-05-20 08:00:00"

    .PARAMETER Interval
    Specifies the interval at which the power off operation should be repeated. This parameter accepts a TimeSpan object or a string representation of a time interval. 
    If not specified, the power off operation will not be repeated.

    This parameter supports common ISO 8601 period durations such as:
    - P1D (1 Day)
    - P1W (1 Week)
    - P1M (1 Month)
    - P1Y (1 Year)
    
    The accepted formats include periods (P) referencing days, weeks, months, years but not time (T) designations that reference hours, minutes, and seconds.

    A valid interval must be greater than 15 minutes (PT15M) and less than 1 year (P1Y).

    .PARAMETER Force 
    Switch parameter to force the power off, akin to pressing the physical power button for 5 seconds and then releasing it.

    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties). By default, the Cmdlet will wait for the job to complete.
    
    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Stop-HPECOMserver -Region us-west -ServerSerialNumber CZ12312312
    
    This command initiates a graceful shutdown of the server with the serial number 'CZ12312312' and waits for the job to complete before returning the job resource object. 
    
    .EXAMPLE
    Stop-HPECOMserver -Region us-west -ServerSerialNumber CZ12312312 -Force
    
    This command forces the server with the serial number 'CZ12312312' to power off without waiting for a graceful shutdown of the OS, then waits for the job to complete, and finally returns the job resource object.

    .EXAMPLE 
    Get-HPECOMServer -Region eu-central -Name ESX-2  | Stop-HPECOMserver -Async

    This command powers off the server named 'ESX-2' and immediately returns the asynchronous job resource to monitor.

    .EXAMPLE
    Get-HPECOMServer -Region us-west -PowerState ON -ConnectionType Direct | Stop-HPECOMserver 

    This command initiates a graceful shutdown of all servers in the 'us-west' region that are currently powered on and are directly managed (not OneView managed, as power controls are unsupported).
    
    .EXAMPLE
    "CZ12312312", "DZ12312312" | Stop-HPECOMserver -Region eu-central

    This command powers off the servers with the serial numbers 'CZ12312312' and 'DZ12312312' in the `eu-central` region.

    .EXAMPLE
    Stop-HPECOMserver -Region eu-central -ServerSerialNumber CZ12312312 -ScheduleTime (Get-Date).AddHours(6)  

    This command schedules a power off operation for the server with the serial number 'CZ12312312' in the `eu-central` region to occur six hours from the current time. 

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name CZ12312312 | Stop-HPECOMserver -ScheduleTime (Get-Date).AddDays(2)
  
    This command retrieves the server with the serial number 'CZ12312312' in the `eu-central` region and schedules a power off to occur two days from the current date.
    
    .EXAMPLE
    Stop-HPECOMserver -Region eu-central -ServerSerialNumber CZ12312312 -ScheduleTime (Get-Date).AddHours(6) -Interval P1W
 
    This command schedules a weekly graceful shutdown operation for the server with serial number 'CZ12312312' in the `eu-central` region. The first execution will occur six hours from the current time.

    .EXAMPLE
    Stop-HPECOMserver -Region eu-central -ServerSerialNumber CZ12312312 -ScheduleTime (Get-Date).AddHours(6) -Interval P1W -Force
 
    This command schedules a weekly forced shutdown operation for the server with serial number 'CZ12312312' in the `eu-central` region. The first execution will occur six hours from the current time.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.
    
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
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ScheduleSerialNumber')]
        [Alias('serial', 'serialnumber')]
        [String]$ServerSerialNumber,
        
        [Parameter (ParameterSetName = 'SerialNumber')]
        [Parameter (ParameterSetName = 'ScheduleSerialNumber')]
        [switch]$Force,

        [Parameter (Mandatory, ParameterSetName = 'ScheduleSerialNumber')]
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
            # Validate ISO 8601 duration format
            if ($_ -notmatch '^P(?!$)(\d+Y)?(\d+M)?(\d+W)?(\d+D)?(T(\d+H)?(\d+M)?(\d+S)?)?$') {
                throw "Invalid duration format. Please use an ISO 8601 period interval (e.g., P1D, P1W, P1M, P1Y, PT1H, PT15M)"
            }

            # Extract duration parts
            $years   = [int]($matches[1] -replace '\D', '')  # Y
            $months  = [int]($matches[2] -replace '\D', '')  # M (before T)
            $weeks   = [int]($matches[3] -replace '\D', '')  # W
            $days    = [int]($matches[4] -replace '\D', '')  # D
            $hours   = [int]($matches[6] -replace '\D', '')  # H
            $minutes = [int]($matches[7] -replace '\D', '')  # M (after T)
            $seconds = [int]($matches[8] -replace '\D', '')  # S

            # Calculate total duration in seconds (approximate months/years)
            $totalSeconds = 0
            if ($years)   { $totalSeconds += $years * 365 * 24 * 3600 }
            if ($months)  { $totalSeconds += $months * 30 * 24 * 3600 }
            if ($weeks)   { $totalSeconds += $weeks * 7 * 24 * 3600 }
            if ($days)    { $totalSeconds += $days * 24 * 3600 }
            if ($hours)   { $totalSeconds += $hours * 3600 }
            if ($minutes) { $totalSeconds += $minutes * 60 }
            if ($seconds) { $totalSeconds += $seconds }

            $minSeconds = 15 * 60
            $maxSeconds = 365 * 24 * 3600  # 1 year

            if ($totalSeconds -lt $minSeconds) {
                throw "The interval must be greater than 15 minutes (PT15M)."
            }
            if ($totalSeconds -gt $maxSeconds) {
                throw "The interval must be less than 1 year (P1Y)."
            }
            return $true
        })]
        [Parameter (ParameterSetName = 'ScheduleSerialNumber')]
        [String]$Interval,    

        [Parameter (ParameterSetName = 'SerialNumber')]
        [switch]$Async,

        [Switch]$WhatIf
    ) 

    Begin {
        
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
        
        $_JobTemplateName = 'PowerOff.New'

        $JobTemplateUri = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object resourceuri
        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $Uri = Get-COMJobsUri  

        $ObjectStatusList = [System.Collections.ArrayList]::new()

        $Timeout = 420 # Default timeout of 7 minutes

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        
        # Build tracking object for a schedule output
        if ($ScheduleTime) {

            $objStatus = [pscustomobject]@{
                name               = $Null
                description        = "Scheduled task to power off server '$ServerSerialNumber'"
                associatedResource = $ServerSerialNumber
                purpose            = "SERVER_POWER_OFF"
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
                associatedResource = $ServerSerialNumber
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

        # Add tracking object to the list of object status list
        [void]$ObjectStatusList.Add($objStatus)

    }

    end {

        try {
            if ($Region) {
                $Servers = Get-HPECOMServer -Region $Region
            }
            else {
                return
            }
        
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

         
        foreach ($Resource in $ObjectStatusList) {
            
            $Server = $Servers | Where-Object serialNumber -eq $Resource.associatedResource
              
            if (-not $Server) {

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Server cannot be found in the Compute Ops Management instance!"

                }
                else {

                    $Resource.state = "ERROR"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Failed"
                    $Resource.message = "Server cannot be found in the Compute Ops Management instance!"
                }
                
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Resource.associatedResource
                    Write-warning $ErrorMessage
                    continue
                }
            } 
            elseif ($Server.hardware.powerState -eq "OFF") {

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Server requested power state is already off!"

                }
                else {
                    
                    $Resource.state = "ERROR"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Failed"
                    $Resource.message = "Server requested power state is already off!"
                }
                
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Requested power state is already off." -f $Resource.associatedResource
                    Write-warning $ErrorMessage
                    continue
                }
            }
            else {       
        
                $_serverId = $Server.id
                $_serverResourceUri = $Server.resourceUri

                # Build payload

                if ($ScheduleTime) {

                    if ($Force) {

                        $data = @{operationType = "ForceOff" }
                        
                    }
                    else {
    
                        $data = @{operationType = "GracefulShutdown" }
                        
                    }

                    $Uri = Get-COMSchedulesUri
    
                    $_Body = @{
                        jobTemplateUri = "/api/compute/v1/job-templates/" + $JobTemplateId
                        resourceUri    = $_serverResourceUri
                        data           = $data
                    }      
    
                    $Operation = @{
                        type   = "REST"
                        method = "POST"
                        uri    = "/api/compute/v1/jobs"
                        body   = $_Body
    
                    }
    
                    $randomNumber = Get-Random -Minimum 000000 -Maximum 999999
    
                    $Name = "$($ServerSerialNumber)_ServerPowerOff_Schedule_$($randomNumber)"
                    $Resource.name = $Name 

                    $Description = $Resource.description
    
    
                    if ($Interval) {
                        
                        $Schedule = @{
                            startAt  = $ScheduleTime.ToString("o")  # Convert to ISO 8601 format as $ScheduleTime alone is converted by PS5.1 to '/Date(...)\/ notation'
                            interval = $Interval
                        }
                    }
                    else {
    
                        $Schedule = @{
                            startAt  = $ScheduleTime.ToString("o")  # Convert to ISO 8601 format as $ScheduleTime alone is convert by PS5.1 to '/Date(...)\/ notation'
                            interval = $Null
                        }
                    }

                    $Resource.schedule = $Schedule 
    
                    $Payload = @{
                        name                  = $Name
                        description           = $Description
                        associatedResourceUri = $_serverResourceUri
                        purpose               = "SERVER_POWER_OFF"
                        schedule              = $Schedule
                        operation             = $Operation
    
                    }
    
                }
                else {
                    
                    if ($Force) {

                        $payload = @{
                            jobTemplate = $JobTemplateId
                            resourceId   = $_serverId
                            resourceType = "compute-ops-mgmt/server"
                            jobParams = @{operationType = "ForceOff"}
                        }
                    }
                    else {
    
                        $payload = @{
                            jobTemplate = $JobTemplateId
                            resourceId   = $_serverId
                            resourceType = "compute-ops-mgmt/server"
                            jobParams = @{operationType = "GracefulShutdown"}
                        }
                    }
                    
                }          
                
                $payload = ConvertTo-Json $payload -Depth 10 


                try {
        
                    $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference      

                    if ($ScheduleTime) {

                        if (-not $WhatIf) {
        
                            "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
                            
                            $Resource.name = $_resp.name
                            $Resource.id = $_resp.id
                            $Resource.nextStartAt = $_resp.nextStartAt
                            $Resource.lastRun = $_resp.lastRun
                            $Resource.scheduleUri = $_resp.resourceUri
                            $Resource.schedule = $Schedule
                            $Resource.lastRun = $_resp.lastRun
                            $Resource.resultCode = "SUCCESS"
                            $Resource.details = $_resp
                            $Resource.message = "The schedule to power off the server has been successfully created."
    
                        }
    
                    }
                    else {

                        if (-not $WhatIf -and -not $Async) {    
                             
                            "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose
            
                            $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout
            
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
    
                            $Resource.state = $_resp.state
                            $Resource.duration = $Duration
                            $Resource.resultCode = $_resp.resultCode
                            $Resource.message = $_resp.message
                            $Resource.status = $_resp.Status
                            $Resource.details = $_resp
                            $Resource.jobUri = $_resp.resourceUri        
                            
                        }
                    }
                    
                    "[{0}] Resource content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Resource | Write-Verbose

                }
                catch {
        
                    if (-not $WhatIf) {
                        
                        if ($ScheduleTime) {

                            $Resource.name = $Name
                            $Resource.schedule = $Schedule
                            $Resource.resultCode = "FAILURE"
                            $Resource.message = $_.Exception.Message -replace "`r`n", " " -replace "`n", " " -replace "`r", " "

                        }
                        else {
                            
                            $Resource.state = "ERROR"
                            $Resource.duration = '00:00:00'
                            $Resource.resultCode = "FAILURE"
                            $Resource.status = "Failed"
                            $Resource.message = $_.Exception.Message -replace "`r`n", " " -replace "`n", " " -replace "`r", " "
                        }      
                    }
                }  
            }
        }
        
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
 
function Update-HPECOMServerFirmware {
    <#
    .SYNOPSIS
    Update the firmware on a server.
    
    .DESCRIPTION   
    This cmdlet updates the firmware on a specified server, identified by its serial number. It also provides an option to schedule the update at a specific time.

    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the server is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER ServerSerialNumber
    Specifies the serial number of the server on which the firmware update will be performed.
    
    .PARAMETER FirmwareBaselineReleaseVersion
    Mandatory parameter that defines the firmware baseline release version to use for updating the server. This release version can be found using 'Get-HPECOMFirmwareBaseline'.

    .PARAMETER ScheduleTime
    Specifies the date and time when the server firmware update should be executed. 
    This parameter accepts a DateTime object or a string representation of a date and time. 
    If not specified, the server firmware update will be executed immediately.

    Examples for setting the date and time using `Get-Date`:
    - (Get-Date).AddMonths(6)
    - (Get-Date).AddDays(15)
    - (Get-Date).AddHours(3)
    Example for using a specific date string:
    - "2024-05-20 08:00:00"

    .PARAMETER InstallHPEDriversAndSoftware
    Specifies whether to install HPE drivers and software during the firmware update.

    .PARAMETER WaitForPowerOfforReboot
    Enable this to cause the update to wait for the user to reboot or power off the server before performing the installation.
    
    Note: Server reboot or power off must be performed outside of Compute Ops Management console.

    .PARAMETER WaitForPowerOfforRebootTimeout
    Specifies the timeout duration (in hours) to wait for the user to power off or reboot the server. If the timeout expires, the firmware update will be canceled. 
    The default timeout duration is 4 hours. Supported values are 1, 2, 4, 8, 12, 24.

    .PARAMETER PowerOffAfterUpdate
    Specifies whether to power off the server after the firmware update is complete.

    .PARAMETER SkipComponentUpdatesThatAreBlockedByKnownIssues
    Specifies whether to skip component updates that are blocked by known issues during the firmware update.

    .PARAMETER DisablePrerequisiteCheck
    Specifies whether to disable the prerequisites check before running the firmware update.

    .PARAMETER AllowFirmwareDowngrade
    Specifies whether to allow the downgrade of firmware during the firmware update.

    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties). By default, the Cmdlet will wait for the job to complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Update-HPECOMServerFirmware -Region us-west -ServerSerialNumber 2M28490180 -FirmwareBaselineReleaseVersion "2024.04.00.01" -InstallHPEDriversAndSoftware -PowerOffAfterUpdate -DisablePrerequisiteCheck -AllowFirmwareDowngrade

    This command updates the firmware on a server with serial number `2M28490180` located in the `us-west` region using firmware baseline release version `2024.04.00.01`. The cmdlet waits for the job to complete and displays a progress bar. 
    It also installs HPE drivers and software, powers off the server after the update, disables the prerequisite check, and allows firmware downgrade.
    
    .EXAMPLE
    Update-HPECOMServerFirmware -Region us-west -ServerSerialNumber 2M28490180 -FirmwareBaselineReleaseVersion "2024.04.00.01" -Async

    This command updates the firmware on a server with serial number `2M28490180` located in the `us-west` region using firmware baseline release version `2024.04.00.01`. The cmdlet immediately returns the asynchronous job resource to monitor.

    .EXAMPLE
    "CZ12312312", "DZ12312312" | Update-HPECOMServerFirmware -Region eu-central -FirmwareBaselineReleaseVersion "2024.04.00.01"

    This command updates the firmware on servers with serial numbers `CZ12312312` and `DZ12312312` located in the `eu-central` region using firmware baseline release version `2024.04.00.01`.
    By default, it does not install HPE drivers and software, does not power off the server after the update, enables the prerequisite check, and does not allow firmware downgrade.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name HOL58 | Update-HPECOMServerFirmware -FirmwareBaselineReleaseVersion "2024.04.00.01"

    This command updates the firmware on a server with the name `HOL58` located in the `us-west` region using firmware baseline release version `2024.04.00.01`. 
    By default, it does not install HPE drivers and software, does not power off the server after the update, enables the prerequisite check, and does not allow firmware downgrade.

    .EXAMPLE
    Get-HPECOMServer -Region us-west -ConnectedState True -PowerState OFF -Model 'ProLiant DL385 Gen10 Plus' | Update-HPECOMServerFirmware -FirmwareBaselineReleaseVersion "2024.04.00.01" -PowerOffAfterUpdate -AllowFirmwareDowngrade -Async 

    This command update all DL385 Gen10 Plus servers that are powered off and connected to COM with the specified firmware baseline release version. 
    The first command retrieves a list of all "ProLiant DL385 Gen10 Plus" servers in the "us-west" region that are currently powered off and connected.
    The retrieved servers are then piped (|) to the Update-HPECOMServerFirmware cmdlet, which updates their firmware to the specified version.
    The command also powers off the servers after the update, allows firmware downgrade and returns mmediately the async task.

    .EXAMPLE
    Update-HPECOMServerFirmware -Region eu-central -ServerSerialNumber DZ12312312 -FirmwareBaselineReleaseVersion 2024.04.00.02 -ScheduleTime (Get-Date).AddMonths(6) -InstallHPEDriversAndSoftware -PowerOffAfterUpdate -AllowFirmwareDowngrade

    This command creates a schedule to update the firmware of a server with the serial number `DZ12312312` in the `eu-central` region using firmware baseline release version `2024.04.00.01`. 
    The update is scheduled to occur six months from the current date and includes installing HPE drivers and software while allowing firmware downgrade.
    The command also powers off the server after the update.

    .EXAMPLE
    Update-HPECOMServerFirmware -Region eu-central -ServerSerialNumber DZ12312312 -FirmwareBaselineReleaseVersion "2024.04.00.01" -WaitForPowerOfforReboot -WaitForPowerOfforRebootTimeout 24 

    This command updates the firmware on a server with serial number `DZ12312312` located in the `eu-central` region using firmware baseline release version `2024.04.00.01`.
    The cmdlet waits for the user to power off or reboot the server before performing the installation, with a timeout of 24 hours.
    After 24 hours, if the server is not powered off or rebooted, the firmware update will be canceled.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Model "ProLiant DL360 Gen10 Plus" | Update-HPECOMServerFirmware -FirmwareBaselineReleaseVersion 2024.04.00.02 -ScheduleTime (Get-Date).AddDays(4) -InstallHPEDriversAndSoftware  -AllowFirmwareDowngrade

    This example retrieves a list of all "ProLiant DL360 Gen10 Plus" servers in the `eu-central` region and schedules a firmware update for them using baseline version `2024.04.00.02`. 
    The update is scheduled to occur four days from the current date and includes installing HPE drivers and software while allowing firmware downgrade.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.
    
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

    [CmdletBinding(DefaultParameterSetName = 'SerialNumber')]
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
        
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SerialNumber')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ScheduleSerialNumber')]
        [Alias('serial', 'serialnumber')]
        [String]$ServerSerialNumber,
        
        [Parameter (Mandatory)]
        [Alias('FirmwareBundleReleaseVersion')]
        [String]$FirmwareBaselineReleaseVersion,

        [Parameter (Mandatory, ParameterSetName = 'ScheduleSerialNumber')]
        [ValidateScript({
                if ($_ -ge (Get-Date) -and $_ -le (Get-Date).AddYears(1)) {
                    $true
                }
                else {
                    throw "The ScheduleTime must be within one year from the current date."
                }
            })]
        [DateTime]$ScheduleTime,

        [switch]$InstallHPEDriversAndSoftware,

        [switch]$WaitForPowerOfforReboot,

        
        [ValidateSet(1, 2, 4, 8, 12, 24)]
        [int]$WaitForPowerOfforRebootTimeout = 4,
        
        [switch]$PowerOffAfterUpdate,
        
        [switch]$SkipComponentUpdatesThatAreBlockedByKnownIssues,

        [switch]$DisablePrerequisiteCheck,

        [switch]$AllowFirmwareDowngrade,

        [Parameter (ParameterSetName = 'SerialNumber')]
        [switch]$Async,

        [switch]$WhatIf

    )

    Begin {

        [int]$TimeoutinSecondsPerServer = 3600 # Timeout 1 hour

        $Caller = (Get-PSCallStack)[1].Command
    
        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
        
        $_JobTemplateName = 'FirmwareUpdate.New'
        
        $JobTemplateUri = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object resourceuri
        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $Uri = Get-COMJobsUri

        $ObjectStatusList = [System.Collections.ArrayList]::new()

        
    }
    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build tracking object for a schedule output
        if ($ScheduleTime) {

            $objStatus = [pscustomobject]@{
                name               = $Null
                description        = $Null
                associatedResource = $ServerSerialNumber
                purpose            = $Null
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

                associatedResource = $ServerSerialNumber
                date               = "$((Get-Date).ToString())"
                state              = $Null
                name               = $_JobTemplateName
                duration           = $Null
                resultCode         = $Null
                status             = $Null
                message            = $Null    
                region             = $Region  
                jobUri             = $Null 
                Details            = $Null        
            
            }
        }
       
        # Add tracking object to the list of object status list
        [void]$ObjectStatusList.Add($objStatus)

    }

    end {
 
        try {
            if ($Region) {
                $Bundles = Get-HPECOMFirmwareBaseline -Region $Region -ReleaseVersion $FirmwareBaselineReleaseVersion 
            }
            else {
                return
            }
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        if (-not $Bundles) {

            # Must return a message if not found
            $ErrorMessage = "Firmware baseline release version '{0}' cannot be found in the Compute Ops Management instance!" -f $FirmwareBaselineReleaseVersion
            throw $ErrorMessage
            
        }


        try {
            $Servers = Get-HPECOMServer -Region $Region
        
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

           
        foreach ($Resource in $ObjectStatusList) {
            
            $Server = $Servers | Where-Object serialNumber -eq $Resource.associatedResource

            "[{0}] Server {1} - Found: `n{2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Resource.associatedResource, $Server | Write-Verbose


            if ($Server.serverGeneration -eq "UNKNOWN") {

                "[{0}] Server {1} - Unable to retrieve server hardware information. Please check the iLO event logs for further details." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Resource.associatedResource | Write-Verbose
            }
            else {

                [int]$_serverGeneration = $Server.serverGeneration -replace "GEN_", ""
                "[{0}] Server {1} - Generation: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Resource.associatedResource, $_serverGeneration | Write-Verbose

            }


            if (-not $Server) {

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Server cannot be found in the Compute Ops Management instance!"

                }
                else {
                    
                    $Resource.state = "ERROR"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.Status = "Failed"
                    $Resource.message = "Server cannot be found in the Compute Ops Management instance!"
                    
                }
                 
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Resource.associatedResource
                    Write-warning $ErrorMessage
                    continue
                }
            } 
            elseif ($Server.serverGeneration -eq "UNKNOWN") {

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Unable to retrieve server hardware information. Please check the iLO event logs for further details."

                }
                else {
                    
                    $Resource.state = "ERROR"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.Status = "Failed"
                    $Resource.message = "Unable to retrieve server hardware information. Please check the iLO event logs for further details."
                    
                }
                 
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Unable to retrieve hardware information. Please check the iLO event logs for further details." -f $Resource.associatedResource
                    Write-warning $ErrorMessage
                    continue
                }
            } 
            elseif ($Server.connectionType -eq "ONEVIEW") {

                # Not supported on OneView managed servers!
                # Must return a message if OneView managed server

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Operation not supported on OneView managed servers!"

                }
                else {

                    $Resource.state = "ERROR"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.Status = "Failed"
                    $Resource.message = "Operation not supported on OneView managed servers!"
                }
                
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Operation not supported on OneView managed servers!" -f $Resource.associatedResource
                    Write-warning $ErrorMessage
                    continue
                }
            }
            else {       
        
                $_serverResourceUri = $Server.resourceUri


                try {
                    $Bundle = $Bundles | Where-Object { $_.bundleGeneration -match $_serverGeneration }
                    $BundleID = $Bundle.id
                    
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                    
                }
    
                if (-not $BundleID) {

                    # Must return a message if not found
                       
                    $Resource.state = "ERROR"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.Status = "Failed"
                    $Resource.message = "Firmware baseline release version '{0}' cannot be found in the Compute Ops Management instance!" -f $FirmwareBaselineReleaseVersion
                    
                    if ($WhatIf) {
                        $ErrorMessage = "Firmware baseline release version '{0}' cannot be found in the Compute Ops Management instance!" -f $FirmwareBaselineReleaseVersion
                        Write-warning $ErrorMessage
                        continue
                    }
                }
                else {

                    if ($WaitForPowerOfforReboot) {
                        $WaitPowerOff = $true
                    }
                    else {
                        $WaitPowerOff = $false
                    }

                    if ($AllowFirmwareDowngrade) {
                        $Downgrade = $true
                    }
                    else {
                        $Downgrade = $false
                    }
    
                    if ($PowerOffAfterUpdate) {
                        $PowerOff = $true
                    }
                    else {
                        $PowerOff = $false
                    }
    
                    if ($InstallHPEDriversAndSoftware) {
                        $InstallSwDrivers = $true
                    }
                    else {
                        $InstallSwDrivers = $false
                    }
    
                    if ($DisablePrerequisiteCheck) {
                        $PrerequisiteCheck = $false
                    }
                    else {
                        $PrerequisiteCheck = $true
                    }

                    if ($SkipComponentUpdatesThatAreBlockedByKnownIssues) {
                        $SkipBlocklistedComponents = $true
                    }
                    else {
                        $SkipBlocklistedComponents = $false
                    }
            
                    $data = @{
                        bundle_id                               = $BundleID
                        downgrade                               = $Downgrade
                        install_sw_drivers                      = $InstallSwDrivers
                        power_off                               = $PowerOff
                        prerequisite_check                      = $PrerequisiteCheck
                        wait_for_power_off_or_reboot            = $WaitPowerOff
                        wait_for_power_off_or_reboot_timeout    = $WaitForPowerOfforRebootTimeout
                        skip_blocklisted_components             = $SkipBlocklistedComponents
                    }
    
                    if ($ScheduleTime) {
    
                        $Uri = Get-COMSchedulesUri
    
                        $_Body = @{
                            jobTemplateUri = "/api/compute/v1/job-templates/" + $JobTemplateId
                            # jobTemplateUri = $JobTemplateUri
                            resourceUri    = $_serverResourceUri
                            data           = $data
                        }      
        
                        $Operation = @{
                            type   = "REST"
                            method = "POST"
                            uri    = "/api/compute/v1/jobs"
                            body   = $_Body
        
                        }
    
                        $randomNumber = Get-Random -Minimum 000000 -Maximum 999999
    
                        $Name = "$($ServerSerialNumber)_ServerFirmwareUpdate_Schedule_$($randomNumber)"
                        $Description = "Scheduled task to update firmware for '$ServerSerialNumber' server"
        
    
                        $Schedule = @{
                            startAt = $ScheduleTime.ToString("o")  # Convert to ISO 8601 format as $ScheduleTime alone is convert by PS5.1 to '/Date(...)\/ notation'
                            # interval = $Null
                        }
        
    
                        $Payload = @{
                            name                  = $Name
                            description           = $Description
                            associatedResourceUri = $_serverResourceUri
                            purpose               = "SERVER_FW_UPDATE"
                            schedule              = $Schedule
                            operation             = $Operation
        
                        }
    
                    }
                    else {

                        $payload = @{
                            jobTemplate = $JobTemplateId
                            resourceId   = $Server.id
                            resourceType = "compute-ops-mgmt/server"
                            jobParams = $data
                        }
                    }
    
                    $payload = ConvertTo-Json $payload -Depth 10 


                    try {
            
                        $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference      
    
                        if ($ScheduleTime) {
    
                            if (-not $WhatIf) {
        
                                "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
                                
                                $Resource.name = $_resp.name
                                $Resource.description = $_resp.description
                                $Resource.id = $_resp.id
                                $Resource.purpose = $_resp.purpose
                                $Resource.nextStartAt = $_resp.nextStartAt
                                $Resource.lastRun = $_resp.lastRun
                                $Resource.scheduleUri = $_resp.resourceUri
                                $Resource.schedule = $Schedule
                                $Resource.lastRun = $_resp.lastRun
                                $Resource.resultCode = "SUCCESS"
                                $Resource.details = $_resp
                                $Resource.message = "The schedule to update server firmware has been successfully created."
        
                            }
                        }
                        else {
    
                            if (-not $WhatIf -and -not $Async) {    
                                 
                                "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose
                
                                $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $TimeoutinSecondsPerServer
                
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
            
                                $Resource.state = $_resp.state
                                $Resource.duration = $Duration
                                $Resource.resultCode = $_resp.resultCode
                                $Resource.message = $_resp.message
                                $Resource.status = $_resp.Status
                                $Resource.details = $_resp
                                $Resource.jobUri = $_resp.resourceUri
                                
                            }
                        }
                        
                        "[{0}] Resource content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Resource | Write-Verbose

                    }
                    catch {
            
                        if (-not $WhatIf) {

                            if ($ScheduleTime) {

                                $Resource.name = $Name
                                $Resource.description = $Description
                                $Resource.schedule = $Schedule
                                $Resource.resultCode = "FAILURE"
                                $Resource.message = $_.Exception.Message -replace "`r`n", " " -replace "`n", " " -replace "`r", " "
    
                            }
                            else {
                                
                                $Resource.state = "ERROR"
                                $Resource.duration = '00:00:00'
                                $Resource.resultCode = "FAILURE"
                                $Resource.Status = "Failed"
                                $Resource.message = $_.Exception.Message -replace "`r`n", " " -replace "`n", " " -replace "`r", " "

                            }
                        }
                    } 
                }             
            }
        }
        
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

function Update-HPECOMServeriLOFirmware {
    <#
    .SYNOPSIS
    Updates the iLO firmware component on a server. 
    
    .DESCRIPTION   
    This cmdlet updates the iLO firmware of a specified server using its serial number by installing the firmware version required by Compute Ops Management.
    It also provides an option to schedule the update at a specific time.

    Note: This cmdlet can ONLY be used when automatic iLO firmware updates are disabled in your workspace. 
          Refer to 'Get-HPECOMServer -Region $Region -Name $SerialNumber -ShowAutoiLOFirmwareUpdateStatus', 'Enable-HPECOMServerAutoiLOFirmwareUpdate', and 'Disable-HPECOMServerAutoiLOFirmwareUpdate' for more information.
    
    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the server is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER ServerSerialNumber
    Specifies the serial number of the server on which the iLO firmware update will be performed.
    
    .PARAMETER ScheduleTime
    Specifies the date and time when the iLO firmware update should be executed. 
    This parameter accepts a DateTime object or a string representation of a date and time. 
    If not specified, the iLO firmware update will be executed immediately.

    Examples for setting the date and time using `Get-Date`:
    - (Get-Date).AddMonths(6)
    - (Get-Date).AddDays(15)
    - (Get-Date).AddHours(3)
    Example for using a specific date string:
    - "2024-05-20 08:00:00"

    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties). By default, the Cmdlet will wait for the job to complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Update-HPECOMServeriLOFirmware -Region us-west -ServerSerialNumber 2M240400JN 

    This command updates the iLO firmware on a server with serial number `2M240400JN` located in the `us-west` region.
   
    .EXAMPLE
    Update-HPECOMServeriLOFirmware -Region us-west -ServerSerialNumber 2M240400JN -Async

    This command updates the iLO firmware on a server with serial number `2M240400JN` located in the `us-west` region and immediately returns the async task.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name "HOL58" | Update-HPECOMServeriLOFirmware 

    This command updates the iLO firmware on a server with the name `HOL58` located in the `eu-central` region.
    
    .EXAMPLE
    Get-HPECOMServer -Region us-west -Model 'ProLiant DL385 Gen10 Plus' | Update-HPECOMServeriLOFirmware 

    This command updates the iLO firmware on all 'ProLiant DL385 Gen10 Plus' servers located in the `us-west` region. 

    .EXAMPLE
    "CZ12312312", "DZ12312312" | Update-HPECOMServeriLOFirmware -Region eu-central 
    
    This command updates the iLO firmware on the servers with serial numbers `CZ12312312` and `DZ12312312` located in the `eu-central` region.
    
    .EXAMPLE
    Update-HPECOMServeriLOFirmware -Region eu-central -ServerSerialNumber CZ12312312 -ScheduleTime (Get-Date).AddMinutes(10)

    This command schedules the iLO firmware update for the server with serial number `CZ12312312` located in the `eu-central` region to run ten minutes from now.
    
    .EXAMPLE
    Get-HPECOMServer -Region eu-central -ConnectedState True -Model "ProLiant DL360 Gen10 Plus" | Update-HPECOMServeriLOFirmware -ScheduleTime (Get-Date).AddHours(12)

    This command schedules the iLO firmware update for all 'ProLiant DL360 Gen10 Plus' servers located in the `eu-central` region to run twelve hours from now. 

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.

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

    [CmdletBinding(DefaultParameterSetName = 'Scheduled')]
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
        
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)] 
        [Alias('serial', 'serialnumber')]
        [String]$ServerSerialNumber,

        [Parameter (ParameterSetName = 'Scheduled')]
        [ValidateScript({
                if ($_ -ge (Get-Date) -and $_ -le (Get-Date).AddYears(1)) {
                    $true
                }
                else {
                    throw "The ScheduleTime must be within one year from the current date."
                }
            })]
        [DateTime]$ScheduleTime,

        [Parameter (ParameterSetName = 'Async')]
        [switch]$Async,

        [switch]$WhatIf

    )

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $_JobTemplateName = 'IloOnlyFirmwareUpdate'
        
        $JobTemplateUri = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object resourceuri      
        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $Uri = Get-COMJobsUri

        $ObjectStatusList = [System.Collections.ArrayList]::new()

        $Timeout = 600 # Timeout 10 minutes
    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build tracking object for a schedule output
        if ($ScheduleTime) {

            $objStatus = [pscustomobject]@{

                name               = $Null
                description        = $Null
                associatedResource = $ServerSerialNumber
                purpose            = $Null
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

                associatedResource = $ServerSerialNumber
                date               = "$((Get-Date).ToString())"
                state              = $Null
                name               = $_JobTemplateName
                duration           = $Null
                resultCode         = $Null
                status             = $Null
                message            = $Null    
                region             = $Region  
                jobUri             = $Null 
                details            = $Null        
            
            }
        }
       
        # Add tracking object to the list of object status list
        [void]$ObjectStatusList.Add($objStatus)

    }

    end {

        try {
            if ($Region) {
                $Servers = Get-HPECOMServer -Region $Region
            }
            else {
                return
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }



        foreach ($Resource in $ObjectStatusList) {
            
            $Server = $Servers | Where-Object serialNumber -eq $Resource.associatedResource

            "[{0}] Server {1} - Found: `n{2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Resource.associatedResource, $Server | Write-Verbose


            if ($Server.serverGeneration -eq "UNKNOWN") {

                "[{0}] Server {1} - Unable to retrieve server hardware information. Please check the iLO event logs for further details." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Resource.associatedResource | Write-Verbose
            }
            else {

                [int]$_serverGeneration = $Server.serverGeneration -replace "GEN_", ""
                "[{0}] Server {1} - Generation: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Resource.associatedResource, $_serverGeneration | Write-Verbose

            }


            if (-not $Server) {

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Server cannot be found in the Compute Ops Management instance!"

                }
                else {
                    
                    $Resource.state = "ERROR"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Failed"
                    $Resource.message = "Server cannot be found in the Compute Ops Management instance!"
                    
                }
                 
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Resource.associatedResource
                    Write-warning $ErrorMessage
                    continue
                }
            } 
            elseif ($Server.serverGeneration -eq "UNKNOWN") {

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Unable to retrieve server hardware information. Please check the iLO event logs for further details."

                }
                else {
                    
                    $Resource.state = "ERROR"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Failed"
                    $Resource.message = "Unable to retrieve server hardware information. Please check the iLO event logs for further details."
                    
                }
                 
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Unable to retrieve hardware information. Please check the iLO event logs for further details." -f $Resource.associatedResource
                    Write-warning $ErrorMessage
                    continue
                }
            } 
            elseif ($Server.connectionType -eq "ONEVIEW") {

                # Not supported on OneView managed servers!
                # Must return a message if OneView managed server

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Operation not supported on OneView managed servers!"

                }
                else {

                    $Resource.state = "ERROR"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Failed"
                    $Resource.message = "Operation not supported on OneView managed servers!"
                }
                
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Operation not supported on OneView managed servers!" -f $Resource.associatedResource
                    Write-warning $ErrorMessage
                    continue
                }
            }
            elseif ($Server.autoIloFwUpdate -eq $True) {

                # Not supported if autoIloFwUpdate is enabled

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Operation not supported because auto iLO firmware update is enabled. To proceed, disable auto iLO firmware update using 'Disable-HPECOMServerAutoiLOFirmwareUpdate'."

                }
                else {

                    $Resource.state = "ERROR"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Failed"
                    $Resource.message = "Operation not supported because auto iLO firmware update is enabled. To proceed, disable auto iLO firmware update using 'Disable-HPECOMServerAutoiLOFirmwareUpdate'."
                }
                
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Operation not supported because auto iLO firmware update is enabled. To proceed, disable auto iLO firmware update using 'Disable-HPECOMServerAutoiLOFirmwareUpdate'." -f $Resource.associatedResource
                    Write-warning $ErrorMessage
                    continue
                }
            }
            else {    

                $_serverResourceUri = $Server.resourceUri

                if ($ScheduleTime) {

                    $Uri = Get-COMSchedulesUri
    
                    $_Body = @{
                        jobTemplateUri = "/api/compute/v1/job-templates/" + $JobTemplateId
                        resourceUri    = $_serverResourceUri
                        # data           = $data
                    }      
    
                    $Operation = @{
                        type   = "REST"
                        method = "POST"
                        uri    = "/api/compute/v1/jobs"
                        body   = $_Body
    
                    }
    
                    $randomNumber = Get-Random -Minimum 000000 -Maximum 999999
    
                    $Name = "$($ServerSerialNumber)_ServeriLOFirmwareUpdate_Schedule_$($randomNumber)"
                    $Description = "Scheduled task to update iLO firmware for '$ServerSerialNumber' server"
    
    
                    $Schedule = @{
                        startAt = $ScheduleTime.ToString("o")  # Convert to ISO 8601 format as $ScheduleTime alone is convert by PS5.1 to '/Date(...)\/ notation'
                        # interval = $Null
                    }
    
    
                    $Payload = @{
                        name                  = $Name
                        description           = $Description
                        associatedResourceUri = $_serverResourceUri
                        purpose               = "SERVER_ILO_FW_UPDATE"
                        schedule              = $Schedule
                        operation             = $Operation
    
                    }
    
                }
                else {

                    $payload = @{
                        jobTemplate = $JobTemplateId
                        resourceId   = $Server.id
                        resourceType = "compute-ops-mgmt/server"
                        jobParams = @{}
                    }                        
                }
    
                $payload = ConvertTo-Json $payload -Depth 10 

                try {
            
                    $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference      

                    if ($ScheduleTime) {

                        if (-not $WhatIf) {
    
                            "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
                            
                            $Resource.name = $_resp.name
                            $Resource.description = $_resp.description
                            $Resource.id = $_resp.id
                            $Resource.purpose = $_resp.purpose
                            $Resource.nextStartAt = $_resp.nextStartAt
                            $Resource.lastRun = $_resp.lastRun
                            $Resource.scheduleUri = $_resp.resourceUri
                            $Resource.schedule = $Schedule
                            $Resource.lastRun = $_resp.lastRun
                            $Resource.resultCode = "SUCCESS"
                            $Resource.details = $_resp
                            $Resource.message = "The schedule to update iLO firmware has been successfully created."
    
                        }
                    }
                    else {

                        if (-not $WhatIf -and -not $Async) {    
                             
                            "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose
            
                            $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout
            
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
    
                            $Resource.state = $_resp.state
                            $Resource.duration = $Duration
                            $Resource.resultCode = $_resp.resultCode
                            $Resource.message = $_resp.message
                            $Resource.status = $_resp.Status
                            $Resource.details = $_resp
                            $Resource.jobUri = $_resp.resourceUri
                            
                        }
                    }
                    
                    "[{0}] Resource content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Resource | Write-Verbose

                }
                catch {
        
                    if (-not $WhatIf) {

                        if ($ScheduleTime) {

                            $Resource.name = $Name
                            $Resource.description = $Description
                            $Resource.schedule = $Schedule
                            $Resource.resultCode = "FAILURE"
                            $Resource.message = $_.Exception.Message -replace "`r`n", " " -replace "`n", " " -replace "`r", " "

                        }
                        else {
                            
                            $Resource.state = "ERROR"
                            $Resource.duration = '00:00:00'
                            $Resource.resultCode = "FAILURE"
                            $Resource.status = "Failed"
                            $Resource.message = $_.Exception.Message -replace "`r`n", " " -replace "`n", " " -replace "`r", " "

                        }
                    }
                } 
            }             
        }
    
    
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

function Update-HPECOMGroupFirmware {
    <#
    .SYNOPSIS
    Updates the firmware of a group of servers.
    
    .DESCRIPTION   
    This cmdlet initiates a parallel server group firmware update that will affect some or all of the server group members. It also provides an option to schedule the update at a specific time.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the group is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
        
    .PARAMETER GroupName
    Name of the group on which the firmware update will be performed.     
    
    .PARAMETER ServerSerialNumber
    Specifies the serial number of the server on which the firmware update will be performed.

    .PARAMETER ScheduleTime
    Specifies the date and time when the group firmware update should be executed. 
    This parameter accepts a DateTime object or a string representation of a date and time. 
    If not specified, the group firmware update will be executed immediately.
    
    Examples for setting the date and time using `Get-Date`:
    - (Get-Date).AddMonths(6)
    - (Get-Date).AddDays(15)
    - (Get-Date).AddHours(3)
    Example for using a specific date string:
    - "2024-05-20 08:00:00"
    
    .PARAMETER InstallHPEDriversAndSoftware
    Specifies whether to install HPE drivers and software during the firmware update.

    .PARAMETER WaitForPowerOfforReboot
    Enable this to cause the update to wait for the user to reboot or power off the server before performing the installation.
    
    Note: Server reboot or power off must be performed outside of Compute Ops Management console.

    .PARAMETER WaitForPowerOfforRebootTimeout
    Specifies the timeout duration (in hours) to wait for the user to power off or reboot the server. If the timeout expires, the firmware update will be canceled. 
    The default timeout duration is 4 hours. Supported values are 1, 2, 4, 8, 12, 24.

    .PARAMETER SerialUpdates
    Specifies to perform the firmware updates to each server in the group in serial (instead of parallel by default). 

    .PARAMETER StopOnFailure
    Specifies if the group firmware serial update process will continue after the first failure. 
    When StopOnFailure is not used, the update continues after a failure. When used, the update stops after a failure and the remaining servers in the group will not be updated. 
    
    Note: This switch is only applicable for serial firmware updates (i.e. when SerialUpdates switch is used). 

    .PARAMETER PowerOffAfterUpdate
    Specifies whether to power off the server after the firmware update.

    .PARAMETER SkipComponentUpdatesThatAreBlockedByKnownIssues
    Specifies whether to skip component updates that are blocked by known issues during the firmware update.

    .PARAMETER DisablePrerequisiteCheck
    Specifies whether to disable the prerequisites check before running the firmware update.

    .PARAMETER AllowFirmwareDowngrade
    Specifies whether to allow the downgrade of firmware during the firmware update.

    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties). By default, the Cmdlet will wait for the job to complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Update-HPECOMGroupFirmware -Region eu-central -GroupName ESXi_800 -PowerOffAfterUpdate 

    This command updates in parallel the firmware for all servers in a group named `ESXi_800` located in the `eu-central` region. It also powers off the servers after the update.
   
    .EXAMPLE
    $task = Update-HPECOMGroupFirmware -Region eu-central -GroupName ESXi_800 -Async
    $task | Wait-HPECOMJobComplete

    This command updates in parallel the firmware for all servers in a group named `ESXi_800` located in the `eu-central` region. 
    The update runs asynchronously, and the task is monitored using the `Wait-HPECOMJobComplete` cmdlet.

    .EXAMPLE
    Update-HPECOMGroupFirmware -Region eu-central -GroupName ESXi_800 -SerialUpdates -StopOnFailure -AllowFirmwareDowngrade -InstallHPEDriversAndSoftware -DisablePrerequisiteCheck 
    
    This command updates in serial the firmware for all servers in a group named `ESXi_800` located in the `eu-central` region. It specifies that after a failure, the firmware update process will stop,
    and the remaining devices in the group will not be updated. It also installs HPE drivers and software, disables the prerequisites check, and allows firmware downgrade. 

    .EXAMPLE
    Update-HPECOMGroupFirmware -Region eu-central -GroupName ESXi_800 -ServerSerialNumber 'CZ2311004H' -AllowFirmwareDowngrade 

    This command updates the firmware for a specific server with the serial number `CZ2311004H` in a group named `ESXi_800` located in the `eu-central` region. It allows firmware downgrade.

    .EXAMPLE
    Update-HPECOMGroupFirmware -Region eu-central -GroupName ESXi_800 -WaitForPowerOfforReboot -WaitForPowerOfforRebootTimeout 8 

    This command updates in parallel the firmware for all servers in a group named `ESXi_800` located in the `eu-central` region. 
    It waits for the user to power off or reboot the server before performing the installation. The timeout for waiting is set to 8 hours.
    After 8 hours, if the server is not powered off or rebooted, the firmware update will be canceled.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central | Where-Object {$_.serialNumber -eq "CZ12312312" -or $_.serialNumber -eq "DZ12312312"}  | Update-HPECOMGroupFirmware -GroupName  ESXi_800 -AllowFirmwareDowngrade -Async
     
    The first command retrieves a list of all servers in the 'eu-central' region.
    The second command filters the list to include only the servers with serial numbers 'CZ12312312' or 'DZ12312312'.
    The last command updates the firmware of the selected servers as part of the 'ESXi_800' group.
    The update runs in parallel across the selected servers. Firmware downgrades are allowed if necessary. The update runs asynchronously, allowing other tasks to continue without waiting for completion.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -Name ESXi_800 -ShowMembers | Update-HPECOMGroupFirmware 
    
    This command retrieves the list of servers in a group named 'ESXi_800' located in the 'eu-central' region and updates the firmware for all servers in the group.

    .EXAMPLE
    "CZ12312312", "DZ12312312" | Update-HPECOMGroupFirmware -Region eu-central -GroupName ESXi_800
    
    This command updates the firmware for servers with serial numbers 'CZ12312312' and 'DZ12312312' in a group named 'ESXi_800' located in the 'eu-central' region.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central | ForEach-Object { $_ | Update-HPECOMGroupFirmware } 

    This command retrieves all groups in the 'eu-central' region and updates the firmware for each group.

    .EXAMPLE
    Update-HPECOMGroupFirmware -Region eu-central -GroupName ESXi_800 -ScheduleTime (Get-Date).AddDays(4)

    This command creates a schedule to update the firmware of all servers in a group named 'ESXi_800' located in the 'eu-central' region. The schedule is set to run four days from now.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central | Where-Object { $_.SerialNumber -eq "CZ12312312" -or $_.SerialNumber -eq "DZ12312312" } | Update-HPECOMGroupFirmware -GroupName ESXi_800 -ScheduleTime (Get-Date).AddHours(12)

    This command retrieves servers with specific serial numbers from the 'eu-central' region and schedules a firmware update for them in the 'ESXi_800' group in twelve hours.
   
    .EXAMPLE    
    Get-HPECOMGroup -Region eu-central -name ESXi_800 -ShowMembers | Select-Object -Last 2 | Update-HPECOMGroupFirmware -GroupName ESXi_800 -ScheduleTime (Get-Date).AddMonths(6)

    This example retrieves the last two servers from the 'ESXi_800' in the 'eu-central' region and schedules a firmware update for them six months from the current date.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.

    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer' or 'Get-HPECOMGroup -ShowMembers'.

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

    [CmdletBinding(DefaultParameterSetName = 'Scheduled')]
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
                
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [String]$GroupName,

        [Parameter (ValueFromPipeline, ValueFromPipelineByPropertyName)] 
        [Alias('serial', 'serialnumber')]
        [String]$ServerSerialNumber,

        [Parameter (ParameterSetName = 'Scheduled')]
        [ValidateScript({
                if ($_ -ge (Get-Date) -and $_ -le (Get-Date).AddYears(1)) {
                    $true
                }
                else {
                    throw "The ScheduleTime must be within one year from the current date."
                }
            })]
        [DateTime]$ScheduleTime,
        
        [switch]$InstallHPEDriversAndSoftware,

        [switch]$WaitForPowerOfforReboot,

        [ValidateSet(1, 2, 4, 8, 12, 24)]
        [int]$WaitForPowerOfforRebootTimeout = 4,
                
        [switch]$PowerOffAfterUpdate,

        [switch]$SkipComponentUpdatesThatAreBlockedByKnownIssues,
        
        [switch]$DisablePrerequisiteCheck,
        
        [switch]$SerialUpdates,
        
        [switch]$StopOnFailure,

        [switch]$AllowFirmwareDowngrade,

        [Parameter (ParameterSetName = 'Async')]
        [switch]$Async,

        [switch]$WhatIf

    )

    Begin {

        [int]$TimeoutinSecondsPerServer = 3600  # Timeout 1 hour

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $_JobTemplateName = 'GroupFirmwareUpdate'

        $JobTemplateUri = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object resourceuri
        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $Uri = Get-COMJobsUri

        $ServersList = [System.Collections.ArrayList]::new()
        $ServerIdsList = [System.Collections.ArrayList]::new()

        if ($WaitForPowerOfforReboot) {
            $WaitPowerOff = $true
        }
        else {
            $WaitPowerOff = $false
        }

        if ($AllowFirmwareDowngrade) {
            $Downgrade = $true
        }
        else {
            $Downgrade = $false
        }
       
        if ($StopOnFailure) {
            $StopOnFailureValue = $true
        }
        else {
            $StopOnFailureValue = $false
        }
        
        if ($PowerOffAfterUpdate) {
            $PowerOff = $true
        }
        else {
            $PowerOff = $false
        }

        if ($InstallHPEDriversAndSoftware) {
            $InstallSwDrivers = $true
        }
        else {
            $InstallSwDrivers = $false
        }

        if ($DisablePrerequisiteCheck) {
            $PrerequisiteCheck = $false
        }
        else {
            $PrerequisiteCheck = $true
        }
        
        if ($SerialUpdates -or $StopOnFailure) {
            $Parallel = $False
        }
        else {
            $Parallel = $True
        }

        if ($SkipComponentUpdatesThatAreBlockedByKnownIssues) {
            $SkipBlocklistedComponents = $true
        }
        else {
            $SkipBlocklistedComponents = $false
        }

        
    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Not match strings that start with @{, contain any characters in between, and end with }
        if ($ServerSerialNumber -and $ServerSerialNumber -notmatch '^@\{.*\}$') {
            
            [void]$ServersList.add($ServerSerialNumber)
        }

    }

    End {

        try {
            if ($Region) {
                $_group = Get-HPECOMGroup -Region $Region -Name $GroupName
                $GroupMembers = $_group.devices
    
                $_groupName = $_group.name
                $_groupResourceUri = $_group.resourceUri
                $_groupId = $_group.id
                $NbOfServers = $_group.devices.count
    
                "[{0}] GroupName '{1}' detected - URI: '{2}' - Nb of servers: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_groupName, $_groupResourceUri, $NbOfServers | Write-Verbose
            }
            else {
                return
            }           
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        if ( -not $_group) { 

            $ErrorMessage = "Group '{0}' cannot be found in the '{1}' region!" -f $GroupName, $Region
            throw $ErrorMessage

        }

        
        try {
            
            $Servers = Get-HPECOMServer -Region $Region
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }
        

        
        
        if ($ServersList) {

            "[{0}] List of servers to update: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServersList | out-string) | Write-Verbose

            foreach ($Object in $ServersList) {

                $Server = $Servers | Where-Object SerialNumber -eq $Object
    
                if ( -not $Server) {
    
                    $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Object
                    Write-warning $ErrorMessage
    
                } 
                elseif (-not ($GroupMembers | Where-Object serial -eq $Object)) {   
                   
                    $ErrorMessage = "Server '{0}': Resource is not a member of '{1}' group!" -f $Object, $GroupName
                    Write-warning $ErrorMessage
    
                }
                else {       
                   
                    # Building the list of devices object for payload
                    [void]$ServerIdsList.Add($server.id)       
                        
                }
            }
        }
        else {

            if ($GroupMembers) {
                foreach ($Object in $GroupMembers) {
                    [void]$ServerIdsList.Add($Object.id)
                }
            }
            else {

                # Must return a message if no server members are found in the group
                $ErrorMessage = "Group '{0}' has no members to be updated!" -f $GroupName
                Write-warning $ErrorMessage
                
            }
        }
            

        if ($ServerIdsList) {   
            
            "[{0}] List of server IDs to update: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServerIdsList | out-string) | Write-Verbose
            
            # Serial updates
            if (-not $Parallel -and -not $ServerIdsList) {

                $data = @{
                    parallel                                = $Parallel
                    stopOnFailure                           = $StopOnFailureValue
                    downgrade                               = $Downgrade
                    installSWDrivers                        = $InstallSwDrivers
                    powerOff                                = $PowerOff
                    prerequisite_check                      = $PrerequisiteCheck
                    wait_for_power_off_or_reboot            = $WaitPowerOff
                    wait_for_power_off_or_reboot_timeout    = $WaitForPowerOfforRebootTimeout
                    skip_blocklisted_components             = $SkipBlocklistedComponents

                }

            }
            elseif (-not $Parallel -and $ServerIdsList) {

                $data = @{
                    parallel                                = $Parallel
                    stopOnFailure                           = $StopOnFailureValue
                    downgrade                               = $Downgrade
                    installSWDrivers                        = $InstallSwDrivers
                    powerOff                                = $PowerOff
                    prerequisite_check                      = $PrerequisiteCheck
                    devices                                 = $ServerIdsList
                    wait_for_power_off_or_reboot            = $WaitPowerOff
                    wait_for_power_off_or_reboot_timeout    = $WaitForPowerOfforRebootTimeout
                    skip_blocklisted_components             = $SkipBlocklistedComponents

                }

            }

            # Parallel updates
            elseif ($Parallel -and -not $ServerIdsList) {

                $data = @{
                    parallel                                = $Parallel
                    downgrade                               = $Downgrade
                    installSWDrivers                        = $InstallSwDrivers
                    powerOff                                = $PowerOff
                    prerequisite_check                      = $PrerequisiteCheck
                    wait_for_power_off_or_reboot            = $WaitPowerOff
                    wait_for_power_off_or_reboot_timeout    = $WaitForPowerOfforRebootTimeout
                    skip_blocklisted_components             = $SkipBlocklistedComponents

                }

            }
            elseif ($Parallel -and $ServerIdsList) {

                $data = @{
                    parallel                                = $Parallel
                    downgrade                               = $Downgrade
                    installSWDrivers                        = $InstallSwDrivers
                    powerOff                                = $PowerOff
                    prerequisite_check                      = $PrerequisiteCheck
                    devices                                 = $ServerIdsList
                    wait_for_power_off_or_reboot            = $WaitPowerOff
                    wait_for_power_off_or_reboot_timeout    = $WaitForPowerOfforRebootTimeout
                    skip_blocklisted_components             = $SkipBlocklistedComponents

                }

            }
            
            if ($ScheduleTime) {

                $Uri = Get-COMSchedulesUri

                $_Body = @{
                    jobTemplateUri = "/api/compute/v1/job-templates/" + $JobTemplateId
                    # jobTemplateUri = $JobTemplateUri
                    resourceUri    = $_groupResourceUri
                    data           = $data
                }      
    
                $Operation = @{
                    type   = "REST"
                    method = "POST"
                    uri    = "/api/compute/v1/jobs"
                    body   = $_Body
    
                }
    
                $randomNumber = Get-Random -Minimum 000000 -Maximum 999999
    
                $Name = "$($GroupName)_ServerFirmwareUpdate_Schedule_$($randomNumber)"
                $Description = "Scheduled task to update firmware for '$_GroupName' group"
    
                
                # Get GMT time difference in hours
                # $GMTTimeDifferenceInHour = Get-GMTTimeDifferenceInMinutes
                
                # Calculate the schedule time for GMT
                # $ScheduleTimeForGMT = $ScheduleTime.AddMinutes(-$GMTTimeDifferenceInMinutes)
  
                $Schedule = @{
                    startAt = $ScheduleTime.ToString("o")  # Convert to ISO 8601 format as $ScheduleTime alone is convert by PS5.1 to '/Date(...)\/ notation' 
                    # interval = $Null
                }



                # Build payload
                $Payload = @{
                    name                  = $Name
                    description           = $Description
                    associatedResourceUri = $_groupResourceUri
                    purpose               = "GROUP_FW_UPDATE"
                    schedule              = $Schedule
                    operation             = $Operation
    
                }    

            }
            else {

                $payload = @{
                    jobTemplate = $JobTemplateId
                    resourceId   = $_groupId
                    resourceType = "compute-ops-mgmt/group"
                    jobParams = $data
                }
            }


            $payload = ConvertTo-Json $payload -Depth 10 

            try {
                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                # Add region to object
                $_resp | Add-Member -type NoteProperty -name region -value $Region

                if ($ScheduleTime) {

                    if (-not $WhatIf) {    
                                  
                        $ReturnData = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Schedules"
    
                        "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
    
                    }

                }
                else {
                    
                    if (-not $WhatIf -and -not $Async) {    
                    
                        # Timeout for parallel group FW update 
                        if ($ParallelUpdates) {
                            $Timeout = $TimeoutinSecondsPerServer
                        
                        }
                        # Timeout for serial (default):  default timeout x nb of servers found in the group
                        else {
                            $Timeout = $NbOfServers * $TimeoutinSecondsPerServer
                        }
                    
                        "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose
    
                        $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout 
                        "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
    
                    }
                    else {

                        $ReturnData = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs" 

                    }
                }

            }
            catch {

                if (-not $WhatIf) {

                    $PSCmdlet.ThrowTerminatingError($_)

                }
            }  

            if ($ScheduleTime) {

                if (-not $WhatIf ) {
            
                    Return $ReturnData
            
                }
        
            }
            else {

                if (-not $WhatIf ) {
                
                    Return $_resp
            
                }
            }
        }
    }
}

function Stop-HPECOMGroupFirmware {
    <#
    .SYNOPSIS
    Cancel an ongoing serial firmware update job.
    
    .DESCRIPTION   
    This cmdlet can be used to cancel an ongoing server group firmware update job that is running. Note that this job cannot be canceled if the Parallel update option is enabled. 
    Additionally, updates cannot be canceled on servers that have already started or completed the firmware update, or on servers that are in a stalled state.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the group/job is located.  
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER InputJobObject 
    The server group firmware update job resource from 'Get-HPECOMJob'. 

    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties). By default, the Cmdlet will wait for the job to complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    $Job = Update-HPECOMGroupFirmware -Region eu-central -GroupName ESXi_group -Async 
    Stop-HPECOMGroupFirmware -Region eu-central -InputJobObject $Job

    The first command initiates an asynchronous firmware update for the server group named ESXi_group in the eu-central region. The second command cancels this ongoing firmware update job.

    .EXAMPLE
    $Job = Update-HPECOMGroupFirmware -Region  eu-central -GroupName ESXi_group -Async 
    $Job | Stop-HPECOMGroupFirmware 

    This command starts an asynchronous firmware update for all servers in a group named `ESXi_group` located in the `eu-central` region, and then it stops the update process.

    .EXAMPLE
    Get-HPECOMJob -Region eu-central -Type groups | Select-Object -last 1 | Stop-HPECOMGroupFirmware 

    This command retrieves the last group firmware update job in the `eu-central` region and stops the update process.

    .INPUTS
    System.Collections.ArrayList
        List of jobs from 'Get-HPECOMJob'.

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

    #>

    [CmdletBinding(DefaultParameterSetName = 'GroupNameSerial')]
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

        [Parameter (ValueFromPipeline)]
        [Object]$InputJobObject,

        [switch]$Async,

        [switch]$WhatIf

    )

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $StopGroupFirmwareStatus = [System.Collections.ArrayList]::new()

    }
    
    Process {
        
        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        try {            
            
            if ($InputJobObject) {
                
                
                if ($InputJobObject.type -ieq "compute-ops-mgmt/job") {
                
                    "[{0}] Pipeline object detected as job type" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    
                    # $Server_InputObject_pipeline = $True
    
                    "[{0}] ID = '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $InputJobObject.id | Write-Verbose
                    $Uri = (Get-COMJobsUri) + '/' + $InputJobObject.id

                    $_job = Get-HPECOMJob -Region $Region -JobResourceUri $uri

    
                }
                else {    
                    
                    $ErrorMessage = "The parameter 'InputJobObject' value is invalid. Please validate the 'InputJobObject' parameter value you passed and try again."
                    throw $ErrorMessage
                    
                }
            }

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
        
        if (-not $_job) {
            
            # Must return a message if not found
            $ErrorMessage = "Job ID '{0}' cannot be found in the Compute Ops Management instance!" -f $InputJobObject.id
            Throw $ErrorMessage
            
        }
        elseif ($_job.state -eq "COMPLETE") {

            $ErrorMessage = "Job ID '{0}' is already in 'COMPLETE' state and cannot be stopped!" -f $InputJobObject.id
            Write-Warning $ErrorMessage

        }
        elseif ($_job.jobParams.parallel -eq $True) {

            $ErrorMessage = "Job ID '{0}' cannot be stopped because the server group firmware update is not set with the Serial update option enabled!" -f $InputJobObject.id
            Write-Error $ErrorMessage

        }
        else {
            
            # Build payload
            $payload = @{
                input = @{ 
                    stopOnRequest = $true
                }
            }      
    
    
            $payload = ConvertTo-Json $payload -Depth 10 
    
            try {

                if ($Region) {

                    $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method PATCH -body $payload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
        
                    # Add region to object
                    $_resp | Add-Member -type NoteProperty -name region -value $Region
                    # Apply Jobs format
                    $_resp = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs" 
        
                    if (-not $WhatIf -and -not $Async) {
            
                        $Timeout = 3600 # 1 hour
                                        
                        "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose
        
                        $_resp = Wait-HPECOMJobComplete -Region $Region -Job $MyInvocation.InvocationName.ToString().ToUpper(), $_resp.resourceuri -Timeout $Timeout 
        
                        "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
        
                    }
                    else {
    
                        $_resp = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs" 
    
                    }
                }
            }
            catch {
    
                if (-not $WhatIf) {
    
                    $PSCmdlet.ThrowTerminatingError($_)
    
                }
            }  
            
            [void]$StopGroupFirmwareStatus.add($_resp)
        }
    }
    
    End {
        
        if (-not $WhatIf ) {
            
            Return $StopGroupFirmwareStatus
        
        }
    }
}

function Invoke-HPECOMGroupFirmwareComplianceCheck {
    <#
    .SYNOPSIS
    Initiate a firmware compliance check on all servers in a group.
    
    .DESCRIPTION   
    This cmdlet initiates a group firmware compliance check to ensure all server components are at or above the group's baseline versions. 
    It also provides options for scheduling execution at a specific time and setting recurring schedules.

    Note: A firmware server setting must be configured in the server group for the compliance feature to be available. 
          This feature does not monitor HPE driver and software versions.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the group is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER GroupName
    Name of the group on which the firmware compliance check will be performed.    

    .PARAMETER ScheduleTime
    Specifies the date and time when the compliance check should be executed. 
    This parameter accepts a DateTime object or a string representation of a date and time. 
    If not specified, the compliance check will be executed immediately.

    Examples for setting the date and time using `Get-Date`:
    - (Get-Date).AddMonths(6)
    - (Get-Date).AddDays(15)
    - (Get-Date).AddHours(3)
    Example for using a specific date string:
    - "2024-05-20 08:00:00"
    
    .PARAMETER Interval
    Specifies the interval at which the compliance check should be repeated. This parameter accepts a TimeSpan object or a string representation of a time interval. If not specified, the compliance check will not be repeated.
    
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
    Invoke-HPECOMGroupFirmwareComplianceCheck -Region eu-central -GroupName ESX-800  

    This command checks firmware compliance of all servers in the group 'ESX-800' in the 'eu-central' region.
   
    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -Name ESXi_group | Invoke-HPECOMGroupFirmwareComplianceCheck

    This command checks firmware compliance of all servers in the group named 'ESXi_group' in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central | Invoke-HPECOMGroupFirmwareComplianceCheck 

    This command checks firmware compliance of all servers in all groups of the 'eu-central' region.

    .EXAMPLE
    Invoke-HPECOMGroupFirmwareComplianceCheck -Region eu-central -GroupName ESX-800 -ScheduleTime (get-Date).addminutes(10) 

    Schedules the execution of a group firmware compliance check on the group named 'ESX-800' in the `eu-central` region starting 10 minutes from now. 

    .EXAMPLE
    Invoke-HPECOMGroupFirmwareComplianceCheck -Region eu-central -GroupName ESX-800 -ScheduleTime (get-Date).addhours(6) -Interval P1M

    Schedules a monthly execution of a group firmware compliance check on the group named 'ESX-800' in the `eu-central` region. The first execution will start in 6 hours. 

    .EXAMPLE
    "ESXi_group", "RHEL_group" | Invoke-HPECOMGroupFirmwareComplianceCheck -Region  eu-central

    This command checks firmware compliance of all servers in the groups 'ESXi_group' and 'RHEL_group' in the `eu-central` region.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the group's names.
    
    System.Collections.ArrayList
        List of groups from 'Get-HPECOMGroup'.

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
        [alias('name')]
        [String]$GroupName,

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
            # Validate ISO 8601 duration format
            if ($_ -notmatch '^P(?!$)(\d+Y)?(\d+M)?(\d+W)?(\d+D)?(T(\d+H)?(\d+M)?(\d+S)?)?$') {
                throw "Invalid duration format. Please use an ISO 8601 period interval (e.g., P1D, P1W, P1M, P1Y, PT1H, PT15M)"
            }

            # Extract duration parts
            $years   = [int]($matches[1] -replace '\D', '')  # Y
            $months  = [int]($matches[2] -replace '\D', '')  # M (before T)
            $weeks   = [int]($matches[3] -replace '\D', '')  # W
            $days    = [int]($matches[4] -replace '\D', '')  # D
            $hours   = [int]($matches[6] -replace '\D', '')  # H
            $minutes = [int]($matches[7] -replace '\D', '')  # M (after T)
            $seconds = [int]($matches[8] -replace '\D', '')  # S

            # Calculate total duration in seconds (approximate months/years)
            $totalSeconds = 0
            if ($years)   { $totalSeconds += $years * 365 * 24 * 3600 }
            if ($months)  { $totalSeconds += $months * 30 * 24 * 3600 }
            if ($weeks)   { $totalSeconds += $weeks * 7 * 24 * 3600 }
            if ($days)    { $totalSeconds += $days * 24 * 3600 }
            if ($hours)   { $totalSeconds += $hours * 3600 }
            if ($minutes) { $totalSeconds += $minutes * 60 }
            if ($seconds) { $totalSeconds += $seconds }

            $minSeconds = 15 * 60
            $maxSeconds = 365 * 24 * 3600  # 1 year

            if ($totalSeconds -lt $minSeconds) {
                throw "The interval must be greater than 15 minutes (PT15M)."
            }
            if ($totalSeconds -gt $maxSeconds) {
                throw "The interval must be less than 1 year (P1Y)."
            }
            return $true
        })]
        [Parameter (ParameterSetName = 'Schedule')]
        [String]$Interval,    
        
        [Parameter (ParameterSetName = 'Async')]
        [switch]$Async,

        [switch]$WhatIf

    )

    Begin {

        [int]$TimeoutinSecondsPerServer = 900  # 15 minutes

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $_JobTemplateName = 'GroupFirmwareCompliance'
        
        $JobTemplateUri = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object resourceuri   
        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $Uri = Get-COMJobsUri

        $GroupFirmwareComplianceStatus = [System.Collections.ArrayList]::new()
        
    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        try {

            $_group = Get-HPECOMGroup -Region $Region -Name $GroupName      
            # $_groupMembers = Get-HPECOMGroup -Region $Region -Name $GroupName -ShowMembers

            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
        
        if (-not $_group) {
        
            # Must return a message if resource not found
            $ErrorMessage = "Group '{0}' cannot be found in the '{1}' region!" -f $GroupName, $Region
            Write-warning $ErrorMessage
            return
            
        }
        # elseif ($_groupCompliance.complianceState -like "Not Applicable") {
            
        #     # Must return an error if one of the server is not in good condition to run a compliance report (I had a 'Power stalled' condition which causes exception)
        #     $ErrorMessage = "Group '{0}' is not applicable for a compliance check. Please verify the state of each server in the group using 'Get-HPECOMGroup -ShowCompliance'." -f $GroupName
        #     Write-warning $ErrorMessage
        # }
        else {
            
            $_ResourceUri = $_group.resourceUri
            $_ResourceId = $_group.id
            $NbOfServers = $_group.devices.count

            "[{0}] GroupName '{1}' detected - URI: '{2}' - Nb of servers: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GroupName, $_ResourceUri, $NbOfServers | Write-Verbose         

            if ($NbOfServers -eq 0) {

                # Must return a message if no servers in group
                $ErrorMessage = "Group '{0}': Operation cannot be executed because no server has been found in the group!" -f $GroupName
                Write-warning $ErrorMessage
                return
            }


            if ($ScheduleTime) {

                $Uri = Get-COMSchedulesUri

                $_Body = @{
                    jobTemplateUri = "/api/compute/v1/job-templates/" + $JobTemplateId
                    resourceUri    = $_ResourceUri
                }      

                $Operation = @{
                    type   = "REST"
                    method = "POST"
                    uri    = "/api/compute/v1/jobs"
                    body   = $_Body

                }

                $randomNumber = Get-Random -Minimum 000000 -Maximum 999999

                $Name = "$($GroupName)_GroupFirmwareComplianceCheck_Schedule_$($randomNumber)"
                $Description = "Scheduled task to run a group firmware compliance check on '$($GroupName)'"

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
                    purpose               = "GROUP_FIRMWARE_COMPLIANCE_CHECK"
                    schedule              = $Schedule
                    operation             = $Operation

                }

            }
            else {

                $payload = @{
                    jobTemplate = $JobTemplateId
                    resourceId   = $_Resourceid
                    resourceType = "compute-ops-mgmt/group"
                    jobParams = $Null
                }
                
            }


            $payload = ConvertTo-Json $payload -Depth 10 

            try {
                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                # Add region to object
                $_resp | Add-Member -type NoteProperty -name region -value $Region
                
                if ($ScheduleTime) {

                    if (-not $WhatIf) {
    
                        $ReturnData = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Schedules"

                        "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

                    }

                }
                else {

                    if (-not $WhatIf -and -not $Async) {
    
                        # Timeout: default timeout x nb of servers found in the group
    
                        $Timeout = $NbOfServers * $TimeoutinSecondsPerServer 
        
                        "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose
        
                        $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout
    
                        "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
    
                    }
                    else {

                        $ReturnData = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs" 

                    }
                }

            }
            catch {

                if (-not $WhatIf) {

                    $PSCmdlet.ThrowTerminatingError($_)

                }
            }  

            if ($ScheduleTime) {

                if (-not $WhatIf ) {
        
                    Return $ReturnData
                
                }
            }
        }

        if (-not $ScheduleTime) {

            [void] $GroupFirmwareComplianceStatus.add($_resp)
        }


    }

    End {

        if (-not $ScheduleTime -and -not $WhatIf ) {
            
            Return $GroupFirmwareComplianceStatus
        
        }

    }
}

function Get-HPECOMGroupFirmwareCompliance {
    <#
    .SYNOPSIS
    Retrieves the firmware compliance details of servers within a specified group.
    
    .DESCRIPTION   
    The `Get-HPECOMGroupFirmwareCompliance` cmdlet allows you to obtain detailed information about the firmware compliance of all servers in a designated group. 
    This cmdlet can be useful for identifying deviations from the group's firmware baseline, ensuring that all devices are up to date and compliant with organizational standards.
    
    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the server group is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER GroupName
    Specifies the name of the server group on which the firmware compliance details will be retrieved.

    .PARAMETER ServerSerialNumber
    Specifies the serial number of an individual server to retrieve its specific compliance details within the group.

    .PARAMETER ShowDeviations
    Switch parameter that retrieves only the firmware components which have deviations from the group's firmware baseline.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMGroupFirmwareCompliance -Region eu-central -GroupName ESX-800  

    This command returns the firmware compliance of all servers in the group 'ESX-800' in the 'eu-central' region.
   
    .EXAMPLE
    Get-HPECOMGroupFirmwareCompliance -Region eu-central -GroupName ESX-800 -ServerSerialNumber CZ12312312 

    This command returns the firmware compliance of the server with serial number 'CZ12312312' in the group 'ESX-800' in the 'eu-central' region.

    .EXAMPLE
    Get-HPECOMGroupFirmwareCompliance -Region eu-central -GroupName ESX-800 -ServerSerialNumber CZ12312312 -ShowDeviations

    This command returns the firmware components which have a deviation with the group 'ESX-800' firmware baseline in the 'eu-central' region.
    
    .EXAMPLE
    Get-HPECOMGroup -Region eu-central | Get-HPECOMGroupFirmwareCompliance 

    This command returns the firmware compliance of all servers in all groups in the 'eu-central' region.

    .INPUTS
    System.Collections.ArrayList
        List of groups retrieved using the `Get-HPECOMGroup` cmdlet.


    #>

    [CmdletBinding(DefaultParameterSetName = "ServerSerialNumber")]
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
        
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [String]$GroupName,

        [Parameter (ValueFromPipelineByPropertyName, ParameterSetName = 'ServerSerialNumber')]
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'DeviationsServerSerialNumber')]
        [alias('serial', 'serialnumber')]
        [String]$ServerSerialNumber,

        [Parameter (ParameterSetName = 'DeviationsServerSerialNumber')]
        [Parameter (ParameterSetName = 'DeviationsServerName')]
        [switch]$ShowDeviations,

        [switch]$WhatIf

    )

    Begin {
  
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
      
      
    }
            
    Process {
      
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose      

        $Uri = (Get-COMGroupsUri) + "?filter=name eq '$GroupName'"

        try {

            $_group = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region
            $GroupID = $_group.id

            "[{0}] ID found for group '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $GroupID | Write-Verbose

            if ($Null -eq $GroupID) { return }

            $Uri = (Get-COMGroupsUri) + "/" + $GroupID + "/compliance"
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)

        }
        

        try {
            [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
    
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
                   
        }           
        

        $ReturnData = @()
      
        if ($Null -ne $CollectionList) {   
            
            # Add groupName, servername and serialNumber (only serial is provided)
            # groupName is used in Invoke-HPECOMGroupInternalStorageConfiguration, Update-HPECOMGroupFirmware, etc. 
            Foreach ($Item in $CollectionList) {

                try {
                    $_ServerName = Get-HPECOMServer -Region $Region -Name $Item.serial                        
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }

                $Item | Add-Member -type NoteProperty -name region -value $Region
                $Item | Add-Member -type NoteProperty -name groupName -value $GroupName
                $Item | Add-Member -type NoteProperty -name serialNumber -value $Item.serial
                $item | Add-Member -Type NoteProperty -Name serverName -Value $_ServerName.name
                
            }
                        
            if ($ServerSerialNumber) {

                
                if ($ShowDeviations) {
                    
                    $CollectionList = $CollectionList | Where-Object serial -eq $ServerSerialNumber | ForEach-Object deviations | Sort-Object -Property ComponentName


                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Groups.Firmware.Compliance.Deviations"   
                    
                }
                else {
                    
                    $CollectionList = $CollectionList | Where-Object serial -eq $ServerSerialNumber

                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Groups.Firmware.Compliance"   
                                        
                }
                
            }
            else {
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Groups.Firmware.Compliance"   

            }
            
            $ReturnData = $ReturnData | Sort-Object -Property serverName, serial
            return $ReturnData 
                
        }
        else {

            return
                
        }     
    }
}

function Invoke-HPECOMServerExternalStorage {
    <#
    .SYNOPSIS
    Initiates the collection of external storage details for a server.

    .DESCRIPTION
    This cmdlet collects external storage details for a specified server in Compute Ops Management.
    You can run the collection immediately or schedule it for a future time, including recurring schedules.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the server is located.
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER ServerSerialNumber
    Specifies the serial number of the server for which to collect external storage details.
        
    .PARAMETER ScheduleTime
    Specifies the date and time when the collection operation should be executed. 
    This parameter accepts a DateTime object or a string representation of a date and time. 
    If not specified, the collection operation will be executed immediately.

    Examples for setting the date and time using `Get-Date`:
    - (Get-Date).AddMonths(6)
    - (Get-Date).AddDays(15)
    - (Get-Date).AddHours(3)
    Example for using a specific date string:
    - "2024-05-20 08:00:00"
    
    .PARAMETER Interval
    Specifies the interval at which the collection operation should be repeated. This parameter accepts a TimeSpan object or a string representation of a time interval. 
    If not specified, the collection operation will not be repeated.

    This parameter supports common ISO 8601 period durations such as:
    - P1D (1 Day)
    - P1W (1 Week)
    - P1M (1 Month)
    - P1Y (1 Year)
    
    The accepted formats include periods (P) referencing days, weeks, months, years but not time (T) designations that reference hours, minutes, and seconds.

    A valid interval must be greater than 15 minutes (PT15M) and less than 1 year (P1Y).

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Invoke-HPECOMServerExternalStorage -Region 'us-west' -ServerSerialNumber '123456789' 

    Initiates a job to collect external storage details for the specified server in the US west region.

    .EXAMPLE
    Invoke-HPECOMServerExternalStorage -Region 'us-west' -ServerSerialNumber '123456789' -ScheduleTime (Get-Date).AddHours(1) -Interval 'P1W'

    Initiates a job to collect external storage details for the specified server in the `us-west` region and schedules it to run in one hour with a recurring interval of one week.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name CZ12312312 | Invoke-HPECOMServerExternalStorage

    This command retrieves the server with the serial number 'CZ12312312' in the `eu-central` region and initiates a job to collect external storage details for that server.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.

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

    [CmdletBinding()]
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
        
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SerialNumber')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ScheduleSerialNumber')]
        [Alias('serial', 'serialnumber')]
        [String]$ServerSerialNumber,

        [Parameter (Mandatory, ParameterSetName = 'ScheduleSerialNumber')]
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
            # Validate ISO 8601 duration format
            if ($_ -notmatch '^P(?!$)(\d+Y)?(\d+M)?(\d+W)?(\d+D)?(T(\d+H)?(\d+M)?(\d+S)?)?$') {
                throw "Invalid duration format. Please use an ISO 8601 period interval (e.g., P1D, P1W, P1M, P1Y, PT1H, PT15M)"
            }

            # Extract duration parts
            $years   = [int]($matches[1] -replace '\D', '')  # Y
            $months  = [int]($matches[2] -replace '\D', '')  # M (before T)
            $weeks   = [int]($matches[3] -replace '\D', '')  # W
            $days    = [int]($matches[4] -replace '\D', '')  # D
            $hours   = [int]($matches[6] -replace '\D', '')  # H
            $minutes = [int]($matches[7] -replace '\D', '')  # M (after T)
            $seconds = [int]($matches[8] -replace '\D', '')  # S

            # Calculate total duration in seconds (approximate months/years)
            $totalSeconds = 0
            if ($years)   { $totalSeconds += $years * 365 * 24 * 3600 }
            if ($months)  { $totalSeconds += $months * 30 * 24 * 3600 }
            if ($weeks)   { $totalSeconds += $weeks * 7 * 24 * 3600 }
            if ($days)    { $totalSeconds += $days * 24 * 3600 }
            if ($hours)   { $totalSeconds += $hours * 3600 }
            if ($minutes) { $totalSeconds += $minutes * 60 }
            if ($seconds) { $totalSeconds += $seconds }

            $minSeconds = 15 * 60
            $maxSeconds = 365 * 24 * 3600  # 1 year

            if ($totalSeconds -lt $minSeconds) {
                throw "The interval must be greater than 15 minutes (PT15M)."
            }
            if ($totalSeconds -gt $maxSeconds) {
                throw "The interval must be less than 1 year (P1Y)."
            }
            return $true
        })]
        [Parameter (ParameterSetName = 'ScheduleSerialNumber')]
        [String]$Interval,   

        [switch]$WhatIf

    )

    Begin {
  
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
      
        $_JobTemplateName = 'GetServerExternalStorage'
        
        $JobTemplateUri = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object resourceuri
        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id
        
        $Uri = Get-COMJobsUri  
        
        $ObjectStatusList = [System.Collections.ArrayList]::new()
      
        $Timeout = 420 # 7 minutes
    }
      
      
    Process {
      
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose      

        # Build tracking object for a schedule output
        if ($ScheduleTime) {

            $objStatus = [pscustomobject]@{
                name               = $Null
                description        = "Scheduled task to get external storage details on server '$ServerSerialNumber'"
                associatedResource = $ServerSerialNumber
                purpose            = "SERVER_GET_EXTERNAL_STORAGE_DETAILS"
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
                associatedResource = $ServerSerialNumber
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

        # Add tracking object to the list of object status list
        [void]$ObjectStatusList.Add($objStatus)
                
    }
    end {

         try {
            if ($Region) {
                $Servers = Get-HPECOMServer -Region $Region
            }
            else {
                return
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

         
        foreach ($Resource in $ObjectStatusList) {
            
            $Server = $Servers | Where-Object serialNumber -eq $Resource.associatedResource
              
            if (-not $Server) {

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Server cannot be found in the Compute Ops Management instance!"

                }
                else {

                    $Resource.state = "ERROR"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Failed"
                    $Resource.message = "Server cannot be found in the Compute Ops Management instance!"
                }
                
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Resource.associatedResource
                    Write-warning $ErrorMessage
                    continue
                }
            } 
            else {       
        
                $_serverId = $Server.id
                $_serverResourceUri = $Server.resourceUri
                
                # Build payload

                if ($ScheduleTime) {

                    $Uri = Get-COMSchedulesUri

                    $_Body = @{
                        jobTemplateUri = "/api/compute/v1/job-templates/" + $JobTemplateId
                        resourceUri    = $_serverResourceUri
                        # data           = $data
                    }    
    
                    $Operation = @{
                        type   = "REST"
                        method = "POST"
                        uri    = "/api/compute/v1/jobs"
                        body   = $_Body
    
                    }
    
                    $randomNumber = Get-Random -Minimum 000000 -Maximum 999999
    
                    $Name = "$($ServerSerialNumber)_GetServerExternalStorage_Schedule_$($randomNumber)"
                    $Resource.name = $Name 

                    $Description = $Resource.description
    
    
                    if ($Interval) {
                        
                        $Schedule = @{
                            startAt  = $ScheduleTime.ToString("o")  # Convert to ISO 8601 format as $ScheduleTime alone is converted by PS5.1 to '/Date(...)\/ notation'
                            interval = $Interval
                        }
                    }
                    else {
    
                        $Schedule = @{
                            startAt  = $ScheduleTime.ToString("o")  # Convert to ISO 8601 format as $ScheduleTime alone is convert by PS5.1 to '/Date(...)\/ notation'
                            interval = $Null
                        }
                    }

                    $Resource.schedule = $Schedule 
    
                    $Payload = @{
                        name                  = $Name
                        description           = $Description
                        associatedResourceUri = $_serverResourceUri
                        purpose               = "GET_SERVER_EXTERNAL_STORAGE_DETAILS"
                        schedule              = $Schedule
                        operation             = $Operation
    
                    }
    
                }
                else {
                    
                    $payload = @{
                        jobTemplate = $JobTemplateId
                        resourceId   = $_serverId
                        resourceType = "compute-ops-mgmt/server"
                        jobParams = @{}
                    }
                    
                }          
                
                $payload = ConvertTo-Json $payload -Depth 10


                try {
        
                    $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference      

                    if ($ScheduleTime) {

                        if (-not $WhatIf) {
        
                            "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
                            
                            $Resource.name = $_resp.name
                            $Resource.id = $_resp.id
                            $Resource.nextStartAt = $_resp.nextStartAt
                            $Resource.lastRun = $_resp.lastRun
                            $Resource.scheduleUri = $_resp.resourceUri
                            $Resource.schedule = $Schedule
                            $Resource.lastRun = $_resp.lastRun
                            $Resource.resultCode = "SUCCESS"
                            $Resource.details = $_resp
                            $Resource.message = "The schedule to retrieve the server external storage details has been successfully created."
    
                        }
    
                    }
                    else {

                        if (-not $WhatIf -and -not $Async) {    
                             
                            "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose
            
                            $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout
            
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
    
                            $Resource.state = $_resp.state
                            $Resource.duration = $Duration
                            $Resource.resultCode = $_resp.resultCode
                            $Resource.message = $_resp.message
                            $Resource.status = $_resp.Status
                            $Resource.details = $_resp
                            $Resource.jobUri = $_resp.resourceUri        
                            
                        }
                    }
                    
                    "[{0}] Resource content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Resource | Write-Verbose

                }
                catch {
        
                    if (-not $WhatIf) {
                        
                        if ($ScheduleTime) {
                            
                            $Resource.name = $Name
                            $Resource.schedule = $Schedule
                            $Resource.resultCode = "FAILURE"
                            $Resource.message = $_.Exception.Message -replace "`r`n", " " -replace "`n", " " -replace "`r", " "

                        }
                        else {
                            
                            $Resource.state = "ERROR"
                            $Resource.duration = '00:00:00'
                            $Resource.resultCode = "FAILURE"
                            $Resource.status = "Failed"
                            $Resource.message = $_.Exception.Message -replace "`r`n", " " -replace "`n", " " -replace "`r", " "
                        }      
                    }
                }  
            }
        }
        
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

function Invoke-HPECOMGroupInternalStorageConfiguration {
    <#
    .SYNOPSIS
    Initiate a server group internal storage configuration.
    
    .DESCRIPTION   
    This cmdlet initiates a server group internal storage configuration that will affect some or all of the server group members.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the group is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
        
    .PARAMETER GroupName
    Name of the group on which the internal storage configuration will be performed.     
    
    .PARAMETER ServerSerialNumber
    Specifies the serial number of an individual server to configure its internal storage within the group.

    .PARAMETER AllowStorageVolumeDeletion
    Specifies to delete any existing internal storage configuration prior to creating the new OS volume.

    .PARAMETER StorageVolumes
    Specifies the volume names to be configured for the group internal storage operation. If omitted, default volume names will be used.
    This parameter accepts an array of hashtable objects, each containing an `id` (the unique identifier of the volume) and a `name` (the desired name for the volume).

    Example for building the volumes array:

    $IDs = Get-HPECOMSetting -Region eu-central -Name 'AI_SERVER_RAID1_5' -ShowVolumes | Select-Object -ExpandProperty id

    $Volumes = @(
        @{ id = $IDs[0]; name = "OS_Volume" },
        @{ id = $IDs[1]; name = "Data_Volume" }
    )

    Pass the `$Volumes` array to the `-StorageVolumes` parameter to assign custom names to each volume during the configuration.

    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties). By default, the Cmdlet will wait for the job to complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Invoke-HPECOMGroupInternalStorageConfiguration -Region eu-central -GroupName ESXi_800

    This command initiates a server group internal storage configuration of all servers in a group named `ESXi_800` located in the `eu-central` region. 
   
    .EXAMPLE
    $IDs = Get-HPECOMSetting -Region eu-central -Name 'AI_SERVER_RAID1_5' -ShowVolumes | Select-Object -ExpandProperty id

    $Volumes = @(
        @{ id = $IDs[0]; name = "OS_Volume" },
        @{ id = $IDs[1]; name = "Data_Volume" }
    )

    Invoke-HPECOMGroupInternalStorageConfiguration -Region eu-central -GroupName ESXi_800 -AllowStorageVolumeDeletion -StorageVolumes $Volumes

    This command initiates a server group internal storage configuration for all servers in the group named `ESXi_800` in the `eu-central` region.
    The `-AllowStorageVolumeDeletion` switch ensures that any existing internal storage configuration is deleted before creating new OS volumes.
    The `-StorageVolumes $Volumes` parameter assigns custom names to the new volumes, such as 'OS_Volume' for the first and 'Data_Volume' for the second, as specified in the `$Volumes` array.

    .EXAMPLE
    Invoke-HPECOMGroupInternalStorageConfiguration -Region eu-central -GroupName ESXi_800 -ServerSerialNumber 'CZ12312312' 

    This command initiates a server group internal storage configuration of the server with the serial number 'CZ12312312' as part of the 'ESXi_800' group located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name "ESX-1" | Invoke-HPECOMGroupInternalStorageConfiguration -GroupName ESXi_800

    This command initiates a server group internal storage configuration of the server named 'ESX-1' as part of the 'ESXi_800' group located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central | Where-Object {$_.serialNumber -eq "CZ12312312" -or $_.serialNumber -eq "DZ12312312"}  | Invoke-HPECOMGroupInternalStorageConfiguration -GroupName ESXi_800 -Async
     
    The first command retrieves a list of all servers in the 'eu-central' region.
    The second command filters the list to include only the servers with serial numbers 'CZ12312312' or 'DZ12312312'.
    The last command initiates a server group internal storage configuration of the specified servers as part of the 'ESXi_800' group.
    The configuration runs asynchronously, allowing other tasks to continue without waiting for completion.
       
    .EXAMPLE
    "CZ12312312", "DZ12312312" | Invoke-HPECOMGroupInternalStorageConfiguration -Region eu-central -GroupName ESXi_800 
    
    This command initiates a server group internal storage configuration of the servers with serial numbers 'CZ12312312' and 'DZ12312312' as part of the 'ESXi_800' group located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central | ForEach-Object { $_ | Invoke-HPECOMGroupInternalStorageConfiguration }
    
    This command retrieves a list of all groups in the 'eu-central' region and initiates a server group internal storage configuration for each group.
    
    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.

    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer' or 'Get-HPECOMGroup -ShowMembers'.

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

    #>

    [CmdletBinding()]
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
                
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [String]$GroupName,

        [Parameter (ValueFromPipeline, ValueFromPipelineByPropertyName)] 
        [Alias('serial', 'serialnumber')]
        [String]$ServerSerialNumber,

        [switch]$AllowStorageVolumeDeletion,

        [Object]$StorageVolumes,

        [switch]$Async,

        [switch]$WhatIf

    )

    Begin {

        [int]$TimeoutinSecondsPerServer = 3600 # 1 hour per server

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $_JobTemplateName = 'GroupApplyInternalStorageSettings'

        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $Uri = Get-COMJobsUri

        $ServersList = [System.Collections.ArrayList]::new()
        $ServerIdsList = [System.Collections.ArrayList]::new()
        
        if ($AllowStorageVolumeDeletion) {
            $isStorageVolumeDeletionAllowed = $true
        }
        else {
            $isStorageVolumeDeletionAllowed = $false
        }     
        
    }
    
    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        if ($ServerSerialNumber -and $ServerSerialNumber -notmatch '^@\{.*\}$') {
            
            [void]$ServersList.add($ServerSerialNumber)
        }

    }

    End {

        try {

            if ($Region) {

                $_group = Get-HPECOMGroup -Region $Region -Name $GroupName
                $GroupMembers = $_group.devices
                # $GroupMembers = Get-HPECOMGroup -Region $Region -Name $GroupName -ShowMembers
                
                $_groupName = $_group.name
                $_groupResourceUri = $_group.resourceUri
                $_groupId = $_group.id
                $NbOfServers = $_group.devices.count
                
                "[{0}] GroupName '{1}' detected - URI: '{2}' - Nb of servers: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_groupName, $_groupResourceUri, $NbOfServers | Write-Verbose
            }
            else {
                Return
            }
            

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        if ( -not $_group) {

            $ErrorMessage = "Group '{0}' cannot be found in the '{1}' region!" -f $GroupName, $Region
            throw $ErrorMessage

        }

        
        try {
            
            $Servers = Get-HPECOMServer -Region $Region
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }
        

        
        
        if ($ServersList) {

            "[{0}] List of servers to configure: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServersList | out-string) | Write-Verbose

            foreach ($Object in $ServersList) {

                $Server = $Servers | Where-Object SerialNumber -eq $Object
    
                if ( -not $Server) {
    
                    $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Object
                    Write-warning $ErrorMessage
    
                } 
                elseif (-not ($GroupMembers | Where-Object serial -eq $Object)) {   
                   
                    $ErrorMessage = "Server '{0}': Resource is not a member of '{1}' group!" -f $Object, $GroupName
                    Write-warning $ErrorMessage
    
                }
                else {       
                   
                    # Building the list of devices object for payload
                    [void]$ServerIdsList.Add($server.id)       
                        
                }
            }
        }
        else {

            if ($GroupMembers) {

                foreach ($Object in $GroupMembers) {
                    [void]$ServerIdsList.Add($Object.id)
                }
            }
            else {

                # Must return a message if no server members are found in the group
                $ErrorMessage = "Group '{0}' has no members to be configured!" -f $GroupName
                Write-warning $ErrorMessage
                
            }
        }
            

        if ($ServerIdsList) {   
            
            "[{0}] List of server IDs to configure: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServerIdsList | out-string) | Write-Verbose
            

            # Build payload
            if ($StorageVolumes) {

                $data = @{
                    devices                        = $ServerIdsList
                    initialize                     = $isStorageVolumeDeletionAllowed
                    volumes                        = $StorageVolumes
                }
            }
            else {

                $data = @{
                    devices                        = $ServerIdsList
                    initialize                     = $isStorageVolumeDeletionAllowed
                    volumes                        = @()
                }
            
            }

            $payload = @{
                jobTemplate = $JobTemplateId
                resourceId   = $_groupId
                resourceType = "compute-ops-mgmt/group"
                jobParams = $data
            }

            $payload = ConvertTo-Json $payload -Depth 10 

            try {
                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                # Add region to object
                $_resp | Add-Member -type NoteProperty -name region -value $Region

                if (-not $WhatIf -and -not $Async) {    
                 
                    $Timeout = $NbOfServers * $TimeoutinSecondsPerServer
                
                    "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose

                    $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout 
                    "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

                }
                else {

                    $_resp = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs" 

                }
                 
            }
            catch {

                if (-not $WhatIf) {

                    $PSCmdlet.ThrowTerminatingError($_)

                }
            }  

            if (-not $WhatIf ) {
            
                Return $_resp
        
            }
        }
    }
}

function Invoke-HPECOMGroupOSInstallation {
    <#
    .SYNOPSIS
    Initiate a group OS installation.
    
    .DESCRIPTION   
    This cmdlet initiates a group operating system installation that will affect some or all of the server group members.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the group is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
        
    .PARAMETER GroupName
    Name of the group on which the operating system installation will be performed.     

    .PARAMETER ServerSerialNumber
    Specifies the serial number of an individual server to install the operating system within the group.

    .PARAMETER StopOnFailure
    Specifies if the operating system installation process will continue after the first failure. 
    When StopOnFailure is not used, the installation continues after a failure. When used, the installation stops after a failure and the remaining servers in the group will not be installed. 
    
    Note: This switch is applicable for serial operating system installation (i.e. when ParallelInstallations switch is not used). 

    .PARAMETER ParallelInstallations
    Specifies to perform the operating system installation to each server in the group in parallel instead of serial by default. 
    
    .PARAMETER OSCompletionTimeoutMin
    Specifies the amount of time (minutes) that Compute Ops Management waits before automatically marking an OS installation job complete. 
    The operating system image is then unmounted from the server. The specified timeout value applies to each server group member.
    Supported value:
    - Default: 240
    - Minimum: 60
    - Maximum: 720

    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties). By default, the Cmdlet will wait for the job to complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Invoke-HPECOMGroupOSInstallation -Region eu-central -GroupName ESXi_800

    This command initiates a group operating system installation of all servers in a group named `ESXi_800` located in the `eu-central` region.
    
    .EXAMPLE
    Invoke-HPECOMGroupOSInstallation -Region eu-central -GroupName ESXi_800 -ParallelInstallations

    This command initiates a group operating system installation of all servers in a group named `ESXi_800` located in the `eu-central` region.
    The installation is performed in parallel instead of serial by default.
   
    .EXAMPLE
    Invoke-HPECOMGroupOSInstallation -Region eu-central -GroupName ESXi_800 -StopOnFailure -OSCompletionTimeoutMin 100

    This command initiates a group operating system installation of all servers in a group named `ESXi_800` located in the `eu-central` region.
    The installation halts upon the first failure, and the operating system image is unmounted from the server after 100 minutes, reduced from the default 240 minutes.

    .EXAMPLE
    Invoke-HPECOMGroupOSInstallation -Region eu-central -GroupName ESXi_800 -ServerSerialNumber 'CZ12312312' 

    This command initiates a group operating system installation of the server with the serial number 'CZ12312312' as part of the 'ESXi_800' group located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name "ESX-1" | Invoke-HPECOMGroupOSInstallation -GroupName ESXi_800

    This command initiates a group operating system installation of the server named 'ESX-1' as part of the 'ESXi_800' group located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central | Where-Object {$_.serialNumber -eq "CZ12312312" -or $_.serialNumber -eq "DZ12312312"}  | Invoke-HPECOMGroupOSInstallation -GroupName ESXi_800 -Async
     
    The first command retrieves a list of all servers in the 'eu-central' region.
    The second command filters the list to include only the servers with serial numbers 'CZ12312312' or 'DZ12312312'.
    The last command initiates a group operating system installation of the specified servers as part of the 'ESXi_800' group. 
    The configuration runs asynchronously, allowing other tasks to continue without waiting for completion.
       
    .EXAMPLE
    "CZ12312312", "DZ12312312" | Invoke-HPECOMGroupOSInstallation -Region eu-central -GroupName ESXi_800 
    
    This command initiates a group operating system installation of the servers with serial numbers 'CZ12312312' and 'DZ12312312' as part of the 'ESXi_800' group located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central | ForEach-Object { $_ | Invoke-HPECOMGroupOSInstallation }

    This command retrieves a list of all groups in the 'eu-central' region and initiates a group operating system installation for each group.
      
    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.

    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer' or 'Get-HPECOMGroup -ShowMembers'.    

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
 
    #>

    [CmdletBinding(DefaultParameterSetName = 'GroupNameSerial')]
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
                
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "GroupNameSerial")]
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "GroupNameParallel")]
        [String]$GroupName,
        
        [Parameter (ValueFromPipeline, ValueFromPipelineByPropertyName)] 
        [Alias('serial', 'serialnumber')]
        [String]$ServerSerialNumber,

        [Parameter (ParameterSetName = 'GroupNameSerial')]
        [switch]$StopOnFailure,

        [Parameter (ParameterSetName = 'GroupNameParallel')]
        [switch]$ParallelInstallations,

        [ValidateRange(60, 720)]
        [int]$OSCompletionTimeoutMin,

        [switch]$Async,

        [switch]$WhatIf

    )

    Begin {

        [int]$TimeoutinSecondsPerServer = 3600 # 1 hour per server

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $_JobTemplateName = 'GroupOSInstallation'

        $JobTemplateUri = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object resourceuri
        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $Uri = Get-COMJobsUri

        $ServersList = [System.Collections.ArrayList]::new()
        $ServerIdsList = [System.Collections.ArrayList]::new()
        
      
        if ($StopOnFailure) {
            $StopOnFailureValue = $true
        }
        else {
            $StopOnFailureValue = $false
        }
                
        
    }
    
    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        if ($ServerSerialNumber -and $ServerSerialNumber -notmatch '^@\{.*\}$') {
            
            [void]$ServersList.add($ServerSerialNumber)
        }

           

    }

    End {

        try {
            if ($Region) {

                $_group = Get-HPECOMGroup -Region $Region -Name $GroupName
                $GroupMembers = $_group.devices

                $_groupName = $_group.name
                $_groupResourceUri = $_group.resourceUri
                $_groupId = $_group.id
                $NbOfServers = $_group.devices.count

                "[{0}] GroupName '{1}' detected - URI: '{2}' - Nb of servers: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_groupName, $_groupResourceUri, $NbOfServers | Write-Verbose
            }
            else {
                Return
            }            

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        if ( -not $_group) {

            $ErrorMessage = "Group '{0}' cannot be found in the '{1}' region!" -f $GroupName, $Region
            throw $ErrorMessage

        }


        try {
            
            $Servers = Get-HPECOMServer -Region $Region
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }
        

        if ($ServersList) {

            "[{0}] List of servers to configure: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServersList | out-string) | Write-Verbose

            foreach ($Object in $ServersList) {

                $Server = $Servers | Where-Object SerialNumber -eq $Object
    
                if ( -not $Server) {
    
                    $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Object
                    Write-warning $ErrorMessage
    
                } 
                elseif (-not ($GroupMembers | Where-Object serial -eq $Object)) {   
                   
                    $ErrorMessage = "Server '{0}': Resource is not a member of '{1}' group!" -f $Object, $GroupName
                    Write-warning $ErrorMessage
    
                }
                else {       
                   
                    # Building the list of devices object for payload
                    [void]$ServerIdsList.Add($server.id)       
                        
                }
            }
        }
        else {

            if ($GroupMembers) {
                foreach ($Object in $GroupMembers) {
                    [void]$ServerIdsList.Add($Object.id)
                }
            }
            else {

                # Must return a message if no server members are found in the group
                $ErrorMessage = "Group '{0}' has no members to be configured!" -f $GroupName
                Write-warning $ErrorMessage
                
            }
        }


        if ($ServerIdsList) {   
            
            "[{0}] List of server IDs to configure: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServerIdsList | out-string) | Write-Verbose
               
            # Parallel updates
            if ($ParallelInstallations -and -not $ServerIdsList -and -not $OSCompletionTimeoutMin) {

                $data = @{
                    parallel = $True
                }

            }
            elseif ($ParallelInstallations -and $ServerIdsList -and -not $OSCompletionTimeoutMin) {

                $data = @{
                    parallel = $True
                    devices  = $ServerIdsList
                }
            
            }
            elseif ($ParallelInstallations -and -not $ServerIdsList -and $OSCompletionTimeoutMin) {

                $data = @{
                    parallel               = $True
                    osCompletionTimeoutMin = $OSCompletionTimeoutMin
                }
            }
            elseif ($ParallelInstallations -and $ServerIdsList -and $OSCompletionTimeoutMin) {
                
                $data = @{
                    parallel               = $True
                    osCompletionTimeoutMin = $OSCompletionTimeoutMin
                    devices                = $ServerIdsList

                }
            }

            # Serial updates
            elseif (-not $ParallelInstallations -and -not $ServerIdsList -and -not $OSCompletionTimeoutMin) {
            
                $data = @{
                    parallel      = $False
                    stopOnFailure = $StopOnFailureValue
                   
                }
            
            }
            elseif (-not $ParallelInstallations -and $ServerIdsList -and -not $OSCompletionTimeoutMin) {
           
                $data = @{
                    parallel      = $False
                    stopOnFailure = $StopOnFailureValue
                    devices       = $ServerIdsList
                }

            }
            elseif (-not $ParallelInstallations -and $ServerIdsList -and $OSCompletionTimeoutMin) {
           
                $data = @{
                    parallel               = $False
                    stopOnFailure          = $StopOnFailureValue
                    devices                = $ServerIdsList
                    osCompletionTimeoutMin = $OSCompletionTimeoutMin

                }

            }
            elseif (-not $ParallelInstallations -and -not $ServerIdsList -and $OSCompletionTimeoutMin) {
           
                $data = @{
                    parallel               = $False
                    stopOnFailure          = $StopOnFailureValue
                    osCompletionTimeoutMin = $OSCompletionTimeoutMin

                }

            }


            $payload = @{
                jobTemplate = $JobTemplateId
                resourceId   = $_groupId
                resourceType = "compute-ops-mgmt/group"
                jobParams = $data
            }


            $payload = ConvertTo-Json $payload -Depth 10 

            try {
                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                # Add region to object
                $_resp | Add-Member -type NoteProperty -name region -value $Region

                if (-not $WhatIf -and -not $Async) {    
                
                    # Timeout for parallel group FW update 
                    if ($ParallelInstallations) {
                        $Timeout = $TimeoutinSecondsPerServer
                    
                    }
                    # Timeout for serial (default):  default timeout x nb of servers found in the group
                    else {
                        $Timeout = $NbOfServers * $TimeoutinSecondsPerServer
                    }
                
                    "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose

                    $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout 
                    "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

                }
                else {

                    $_resp = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs" 

                }
            }
            catch {

                if (-not $WhatIf) {

                    $PSCmdlet.ThrowTerminatingError($_)

                }
            }  

            if (-not $WhatIf ) {
            
                Return $_resp
        
            }

        }
    }
}

function Invoke-HPECOMGroupBiosConfiguration {
    <#
    .SYNOPSIS
    Initiate a server group bios configuration.
    
    .DESCRIPTION   
    This cmdlet initiates a server group bios configuration that will affect some or all of the server group members.

    Note: A server reboot is necessary for the new BIOS settings to take effect. COM will attempt to restart the server automatically. If the server cannot be restarted by COM, you must manually reboot the server (or use 'Restart-HPECOMserver') to complete the configuration process.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the group is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
        
    .PARAMETER GroupName
    Name of the group on which the bios configuration will be performed.     
    
    .PARAMETER ServerSerialNumber
    Specifies the serial number of an individual server to configure its BIOS settings within the group.     

    .PARAMETER ParallelConfigurations
    Specifies to perform the bios configuration to each server in the group in parallel (20 max) instead of serial by default. 

    .PARAMETER ResetBiosSettingsToDefaults
    Specifies to perform a reset server's BIOS settings to default values before applying the BIOS setting.
    
    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties). By default, the Cmdlet will wait for the job to complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Invoke-HPECOMGroupBiosConfiguration -Region eu-central -GroupName ESXi_800

    This command initiates a server group bios configuration of all servers in a group named `ESXi_800` located in the `eu-central` region.

    .EXAMPLE
    Invoke-HPECOMGroupBiosConfiguration -Region eu-central -GroupName ESXi_800 -ResetBiosSettingsToDefaults -ParallelConfigurations

    This command initiates a server group bios configuration of all servers in a group named `ESXi_800` located in the `eu-central` region.
    The configuration is performed in parallel instead of serial by default, and the server's BIOS settings are reset to default values before applying the new BIOS settings.

    .EXAMPLE
    Invoke-HPECOMGroupBiosConfiguration -Region eu-central -GroupName ESXi_800 -ServerSerialNumber 'CZ12312312' 

    This command initiates a server group bios configuration of the server with the serial number 'CZ12312312' as part of the 'ESXi_800' group located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name "ESX-1" | Invoke-HPECOMGroupBiosConfiguration -GroupName ESXi_800

    This command initiates a server group bios configuration of the server named 'ESX-1' as part of the 'ESXi_800' group located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central | Where-Object {$_.serialNumber -eq "CZ12312312" -or $_.serialNumber -eq "DZ12312312"}  | Invoke-HPECOMGroupBiosConfiguration -GroupName ESXi_800 -Async
     
    The first command retrieves a list of all servers in the 'eu-central' region.
    The second command filters the list to include only the servers with serial numbers 'CZ12312312' or 'DZ12312312'.
    The last command initiates a server group bios configuration of the specified servers as part of the 'ESXi_800' group.
    The configuration runs asynchronously, allowing other tasks to continue without waiting for completion.
       
    .EXAMPLE
    "CZ12312312", "DZ12312312" | Invoke-HPECOMGroupBiosConfiguration -Region eu-central -GroupName ESXi_800 
    
    This command initiates a server group bios configuration of the servers with serial numbers 'CZ12312312' and 'DZ12312312' as part of the 'ESXi_800' group located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central | ForEach-Object { $_ | Invoke-HPECOMGroupBiosConfiguration }
    
    This command retrieves a list of all groups in the 'eu-central' region and initiates a server group bios configuration for each group.
    
    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.

    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer' or 'Get-HPECOMGroup -ShowMembers'.

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

    #>

    [CmdletBinding()]
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
                
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [String]$GroupName,
        
        [Parameter (ValueFromPipeline, ValueFromPipelineByPropertyName)] 
        [Alias('serial', 'serialnumber')]
        [String]$ServerSerialNumber,

        [switch]$ParallelConfigurations,

        [switch]$ResetBiosSettingsToDefaults,

        [switch]$Async,

        [switch]$WhatIf

    )

    Begin {

        [int]$TimeoutinSecondsPerServer = 600 # 10 minutes

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $_JobTemplateName = 'GroupApplyServerSettings'

        $JobTemplateUri = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object resourceuri
        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $Uri = Get-COMJobsUri

        $ServersList = [System.Collections.ArrayList]::new()
        $ServerIdsList = [System.Collections.ArrayList]::new()
      
                
        
    }
    
    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        if ($ServerSerialNumber -and $ServerSerialNumber -notmatch '^@\{.*\}$') {

            [void]$ServersList.add($ServerSerialNumber)
        }

    }

    End {

        try {

            if ($Region) {
                $_group = Get-HPECOMGroup -Region $Region -Name $GroupName
                $GroupMembers = $_group.devices 

                $_groupName = $_group.name
                $_groupResourceUri = $_group.resourceUri
                $_groupId= $_group.id
                $NbOfServers = $_group.devices.count

                "[{0}] GroupName '{1}' detected - URI: '{2}' - Nb of servers: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_groupName, $_groupResourceUri, $NbOfServers | Write-Verbose
            }
            else {
                Return
            }            

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        if ( -not $_group) {

            $ErrorMessage = "Group '{0}' cannot be found in the '{1}' region!" -f $GroupName, $Region
            throw $ErrorMessage

        }

        
        try {
            
            $Servers = Get-HPECOMServer -Region $Region
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }
        

        
        
        if ($ServersList) {

            "[{0}] List of servers to configure: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServersList | out-string) | Write-Verbose

            foreach ($Object in $ServersList) {

                $Server = $Servers | Where-Object SerialNumber -eq $Object
    
                if ( -not $Server) {
    
                    $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Object
                    Write-warning $ErrorMessage
    
                } 
                elseif (-not ($GroupMembers | Where-Object serial -eq $Object)) {   
                   
                    $ErrorMessage = "Server '{0}': Resource is not a member of '{1}' group!" -f $Object, $GroupName
                    Write-warning $ErrorMessage
    
                }
                else {       
                   
                    # Building the list of devices object for payload
                    [void]$ServerIdsList.Add($server.id)       
                        
                }
            }
        }
        else {

            if ($GroupMembers) {
                foreach ($Object in $GroupMembers) {
                    [void]$ServerIdsList.Add($Object.id)
                }
            }
            else {

                # Must return a message if no server members are found in the group
                $ErrorMessage = "Group '{0}' has no members to be configured!" -f $GroupName
                Write-warning $ErrorMessage
                
            }
        }

      
        if ($ServerIdsList) {   
            
            "[{0}] List of server IDs to configure: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServerIdsList | out-string) | Write-Verbose

          
            # Parallel updates
            if ($ParallelConfigurations -and -not $ServerIdsList) {

                $data = @{
                    batch_size        = 20
                    redfish_subsystem = "BIOS"
                }

            }
            elseif ($ParallelConfigurations -and $ServerIdsList) {

                $data = @{
                    batch_size        = 20
                    devices           = $ServerIdsList
                    redfish_subsystem = "BIOS"

                }
            
            }

            # Serial updates
            elseif (-not $ParallelConfigurations -and -not $ServerIdsList) {
            
                $data = @{
                    batch_size        = 1
                    redfish_subsystem = "BIOS"
                   
                }
            
            }
            elseif (-not $ParallelConfigurations -and $ServerIdsList) {
           
                $data = @{
                    batch_size        = 1
                    devices           = $ServerIdsList
                    redfish_subsystem = "BIOS"

                }

            }

            if ($ResetBiosSettingsToDefaults) {

                $data.factory_reset	= $true
            }


            $payload = @{
                jobTemplate = $JobTemplateId
                resourceId   = $_groupId
                resourceType = "compute-ops-mgmt/group"
                jobParams = $data
            }            


            $payload = ConvertTo-Json $payload -Depth 10 

            try {
                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                # Add region to object
                $_resp | Add-Member -type NoteProperty -name region -value $Region

                if (-not $WhatIf -and -not $Async) {    
                
                    # Timeout for parallel group FW update 
                    if ($ParallelConfigurations) {
                        $Timeout = $TimeoutinSecondsPerServer
                    
                    }
                    # Timeout for serial (default):  default timeout x nb of servers found in the group
                    else {
                        $Timeout = $NbOfServers * $TimeoutinSecondsPerServer
                    }
                
                    "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose

                    $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout 
                    "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

                }
                else {

                    $_resp = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs" 

                }
            }
            catch {

                if (-not $WhatIf) {

                    $PSCmdlet.ThrowTerminatingError($_)

                }
            }  

            if (-not $WhatIf ) {
            
                Return $_resp
        
            }

        }
    }
}

function Invoke-HPECOMGroupiLOConfiguration {
    <#
    .SYNOPSIS
    Initiate a server group iLO configuration.

    .DESCRIPTION
    This cmdlet initiates a server group iLO configuration that will affect some or all of the server group members.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the group is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
        
    .PARAMETER GroupName
    Name of the group on which the iLO configuration will be performed.

    .PARAMETER ServerSerialNumber
    Specifies the serial number of an individual server to configure its iLO settings within the group.

    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties). By default, the Cmdlet will wait for the job to complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Invoke-HPECOMGroupiLOConfiguration -Region eu-central -GroupName ESXi_800

    This command initiates a server group iLO configuration of all servers in a group named `ESXi_800` located in the `eu-central` region.
    
    .EXAMPLE
    Invoke-HPECOMGroupiLOConfiguration -Region eu-central -GroupName ESXi_800 -ServerSerialNumber 'CZ12312312'
    
    This command initiates a server group iLO configuration of the server with the serial number 'CZ12312312' as part of the 'ESXi_800' group located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name "ESX-1" | Invoke-HPECOMGroupiLOConfiguration -GroupName ESXi_800

    This command initiates a server group iLO configuration of the server named 'ESX-1' as part of the 'ESXi_800' group located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -Name "AI_Group" -ShowMembers | Invoke-HPECOMGroupiLOConfiguration -GroupName AI_Group

    This command retrieves a list of all servers in the 'AI_Group' group located in the `eu-central` region and initiates a server group iLO configuration for each server.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.

    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer' or 'Get-HPECOMGroup -ShowMembers'.

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

    #>

    [CmdletBinding()]
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
                
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [String]$GroupName,
        
        [Parameter (ValueFromPipeline, ValueFromPipelineByPropertyName)] 
        [Alias('serial', 'serialnumber')]
        [String]$ServerSerialNumber,

        [switch]$Async,

        [switch]$WhatIf

    )

    Begin {

        [int]$TimeoutinSecondsPerServer = 600 # 10 minutes

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $_JobTemplateName = 'GroupApplyServerSettings'

        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $ServersList = [System.Collections.ArrayList]::new()
        $ServerIdsList = [System.Collections.ArrayList]::new()

        $Uri = Get-COMJobsUri

      
    }
    
    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        if ($ServerSerialNumber -and $ServerSerialNumber -notmatch '^@\{.*\}$') {
            [void]$ServersList.add($ServerSerialNumber)
        }

    }

    End {

        try {

            if ($Region) {
                $_group = Get-HPECOMGroup -Region $Region -Name $GroupName
                $GroupMembers = $_group.devices 

                $_groupName = $_group.name
                $_groupResourceUri = $_group.resourceUri
                $_groupId= $_group.id
                $NbOfServers = $_group.devices.count

                "[{0}] GroupName '{1}' detected - URI: '{2}' - Nb of servers: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_groupName, $_groupResourceUri, $NbOfServers | Write-Verbose
            }
            else {
                Return
            }            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if ( -not $_group) {
            $ErrorMessage = "Group '{0}' cannot be found in the '{1}' region!" -f $GroupName, $Region
            throw $ErrorMessage
        }
        
        try {
            $Servers = Get-HPECOMServer -Region $Region
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }
        
        if ($ServersList) {

            "[{0}] List of servers to configure: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServersList | out-string) | Write-Verbose

            foreach ($Object in $ServersList) {

                $Server = $Servers | Where-Object SerialNumber -eq $Object
    
                if ( -not $Server) {
    
                    $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Object
                    Write-warning $ErrorMessage
    
                } 
                elseif (-not ($GroupMembers | Where-Object serial -eq $Object)) {   
                   
                    $ErrorMessage = "Server '{0}': Resource is not a member of '{1}' group!" -f $Object, $GroupName
                    Write-warning $ErrorMessage
    
                }
                else {       
                   
                    # Building the list of devices object for payload
                    [void]$ServerIdsList.Add($server.id)       
                        
                }
            }
        }
        else {

            if ($GroupMembers) {
                foreach ($Object in $GroupMembers) {
                    [void]$ServerIdsList.Add($Object.id)
                }
            }
            else {

                # Must return a message if no server members are found in the group
                $ErrorMessage = "Group '{0}' has no members to be configured!" -f $GroupName
                Write-warning $ErrorMessage
                
            }
        }

      
        if ($ServerIdsList) {   
            
            "[{0}] List of server IDs to configure: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServerIdsList | out-string) | Write-Verbose

            if ($ServerIdsList) {
                $data = @{
                    devices           = $ServerIdsList
                    batch_size        = 20
                    redfish_subsystem = "ILO_SETTINGS"
                }
            }
            else {
                $data = @{
                    batch_size        = 20
                    redfish_subsystem = "ILO_SETTINGS"
                }
            }


            $payload = @{
                jobTemplate = $JobTemplateId
                resourceId   = $_groupId
                resourceType = "compute-ops-mgmt/group"
                jobParams = $data
            }            


            $payload = ConvertTo-Json $payload -Depth 10 

            try {
                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                # Add region to object
                $_resp | Add-Member -type NoteProperty -name region -value $Region

                if (-not $WhatIf -and -not $Async) {    
                    # Timeout for serial (default):  default timeout x nb of servers found in the group
                    $Timeout = $NbOfServers * $TimeoutinSecondsPerServer
                
                    "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose

                    $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout 
                    "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

                }
                else {

                    $_resp = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs" 

                }
            }
            catch {

                if (-not $WhatIf) {

                    $PSCmdlet.ThrowTerminatingError($_)

                }
            }  

            if (-not $WhatIf ) {
            
                Return $_resp
        
            }

        }
    }
}

function Invoke-HPECOMGroupiLOConfigurationCompliance {
    <#
    .SYNOPSIS
    Initiate the iLO configuration compliance details of a server within a specified group.

    .DESCRIPTION
    This cmdlet initiates a group iLO configuration compliance check to ensure a server's iLO settings are up-to-date with the group's iLO settings. 
    It also provides options for scheduling execution at a specific time and setting recurring schedules.

    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the server group is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER GroupName
    Specifies the name of the server group on which the iLO configuration compliance details will be retrieved.

    .PARAMETER ServerSerialNumber
    Specifies the serial number of an individual server to retrieve its specific compliance details within the group.

   .PARAMETER ScheduleTime
    Specifies the date and time when the compliance check should be executed. 
    This parameter accepts a DateTime object or a string representation of a date and time. 
    If not specified, the compliance check will be executed immediately.

    Examples for setting the date and time using `Get-Date`:
    - (Get-Date).AddMonths(6)
    - (Get-Date).AddDays(15)
    - (Get-Date).AddHours(3)
    Example for using a specific date string:
    - "2024-05-20 08:00:00"
    
    .PARAMETER Interval
    Specifies the interval at which the compliance check should be repeated. This parameter accepts a TimeSpan object or a string representation of a time interval. If not specified, the compliance check will not be repeated.
    
    This parameter supports common ISO 8601 period durations such as:
    - P1D (1 Day)
    - P1W (1 Week)
    - P1M (1 Month)
    - P1Y (1 Year)
    
    The accepted formats include periods (P) referencing days, weeks, months, years but not time (T) designations that reference hours, minutes, and seconds.

    A valid interval must be greater than 15 minutes (PT15M) and less than 1 year (P1Y).

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.
        
    .EXAMPLE
    Invoke-HPECOMGroupiLOConfigurationCompliance -Region eu-central -GroupName ESX-800 -ServerSerialNumber CZ12312312 

    This command initiates an immediate iLO configuration compliance check for the server with serial number 'CZ12312312' in the group 'ESX-800' in the 'eu-central' region.

    .EXAMPLE
    Invoke-HPECOMGroupiLOConfigurationCompliance -Region eu-central -GroupName ESX-800 -ServerSerialNumber CZ12312312 -ScheduleTime (Get-Date).AddDays(7) -Interval P1M  

    This command schedules a one-time iLO configuration compliance check for the server with serial number 'CZ12312312' in the group 'ESX-800' in the 'eu-central' region, to be executed 7 days from now and repeated every month.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -Name "AI_Group" -ShowMembers | Invoke-HPECOMGroupiLOConfigurationCompliance -GroupName AI_Group

    This command initiates an immediate iLO configuration compliance check for all servers in the group 'AI_Group' in the 'eu-central' region.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -Name "AI_Group" | Invoke-HPECOMGroupiLOConfigurationCompliance -ServerSerialNumber CZ12312312 

    This command initiates an immediate iLO configuration compliance check for the server with serial number 'CZ12312312' in the group 'AI_Group' in the 'eu-central' region.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the group's name or server's name.

    System.Collections.ArrayList
        List of groups from 'Get-HPECOMGroup'.
        List of servers from 'Get-HPECOMServer' or 'Get-HPECOMGroup -ShowMembers'.

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

    [CmdletBinding(DefaultParameterSetName = "Async")]
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
        
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [String]$GroupName,

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [alias('serial', 'serialnumber')]
        [String]$ServerSerialNumber,

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
            # Validate ISO 8601 duration format
            if ($_ -notmatch '^P(?!$)(\d+Y)?(\d+M)?(\d+W)?(\d+D)?(T(\d+H)?(\d+M)?(\d+S)?)?$') {
                throw "Invalid duration format. Please use an ISO 8601 period interval (e.g., P1D, P1W, P1M, P1Y, PT1H, PT15M)"
            }

            # Extract duration parts
            $years   = [int]($matches[1] -replace '\D', '')  # Y
            $months  = [int]($matches[2] -replace '\D', '')  # M (before T)
            $weeks   = [int]($matches[3] -replace '\D', '')  # W
            $days    = [int]($matches[4] -replace '\D', '')  # D
            $hours   = [int]($matches[6] -replace '\D', '')  # H
            $minutes = [int]($matches[7] -replace '\D', '')  # M (after T)
            $seconds = [int]($matches[8] -replace '\D', '')  # S

            # Calculate total duration in seconds (approximate months/years)
            $totalSeconds = 0
            if ($years)   { $totalSeconds += $years * 365 * 24 * 3600 }
            if ($months)  { $totalSeconds += $months * 30 * 24 * 3600 }
            if ($weeks)   { $totalSeconds += $weeks * 7 * 24 * 3600 }
            if ($days)    { $totalSeconds += $days * 24 * 3600 }
            if ($hours)   { $totalSeconds += $hours * 3600 }
            if ($minutes) { $totalSeconds += $minutes * 60 }
            if ($seconds) { $totalSeconds += $seconds }

            $minSeconds = 15 * 60
            $maxSeconds = 365 * 24 * 3600  # 1 year

            if ($totalSeconds -lt $minSeconds) {
                throw "The interval must be greater than 15 minutes (PT15M)."
            }
            if ($totalSeconds -gt $maxSeconds) {
                throw "The interval must be less than 1 year (P1Y)."
            }
            return $true
        })]
        [Parameter (ParameterSetName = 'Schedule')]
        [String]$Interval,    
        
        [Parameter (ParameterSetName = 'Async')]
        [switch]$Async,

        [switch]$WhatIf

    )

    Begin {

        [int]$TimeoutinSecondsPerServer = 1800  # 30 minutes

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $_JobTemplateName = 'CalculateiLOSettingsCompliance'
        
        $JobTemplateUri = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object resourceUri
        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $Uri = Get-COMJobsv1beta3Uri

        $GroupiLOSettingsComplianceStatus = [System.Collections.ArrayList]::new()
        
    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        try {

            $_group = Get-HPECOMGroup -Region $Region -Name $GroupName      
            $_groupMembers = Get-HPECOMGroup -Region $Region -Name $GroupName -ShowMembers
            $_server = $_groupMembers | Where-Object { $_.serialNumber -eq $ServerSerialNumber -or $_.serverName -eq $ServerSerialNumber}

            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
        
        if (-not $_group) {
        
            # Must return a message if resource not found
            $ErrorMessage = "Group '{0}' cannot be found in the '{1}' region!" -f $GroupName, $Region
            Write-warning $ErrorMessage
            return
        }
        elseif (-not $_server) {

            # Must return a message if resource not found
            $ErrorMessage = "Server '{0}' cannot be found in the '{1}' group!" -f $ServerSerialNumber, $GroupName
            Write-warning $ErrorMessage
            return

        }
        else {
            
            $_ResourceUri = $_server.deviceUri
            $_GroupId = $_group.id
            $NbOfServers = $_group.devices.count

            "[{0}] GroupName '{1}' and server '{2}' detected - URI: '{3}' - Nb of servers in group: '{4}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GroupName, $ServerSerialNumber, $_ResourceUri, $NbOfServers | Write-Verbose

           $data = @{
                group_id = $_GroupId
            }

            if ($ScheduleTime) {

                $Uri = Get-COMSchedulesUri

                $_Body = @{
                    jobTemplateUri = "/api/compute/v1/job-templates/" + $JobTemplateId
                    resourceUri    = $_ResourceUri
                    data           = $data
                }      

                $Operation = @{
                    type   = "REST"
                    method = "POST"
                    uri    = "/api/compute/v1/jobs"
                    body   = $_Body

                }

                $randomNumber = Get-Random -Minimum 000000 -Maximum 999999

                $Name = "$($GroupName)_GroupiLOSettingsComplianceCheck_Schedule_$($randomNumber)"
                $Description = "Scheduled task to run a group iLO settings compliance check on '$($GroupName)'"

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
                    purpose               = "GROUP_ILO_COMPLIANCE_CHECK"
                    schedule              = $Schedule
                    operation             = $Operation

                }

            }
            else {

                $payload = @{
                    jobTemplateUri = $JobTemplateUri
                    resourceUri   = $_ResourceUri
                    data = $data
                }
                
            }


            $payload = ConvertTo-Json $payload -Depth 10 

            try {
                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                # Add region to object
                $_resp | Add-Member -type NoteProperty -name region -value $Region
                
                if ($ScheduleTime) {

                    if (-not $WhatIf) {
    
                        $ReturnData = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Schedules"

                        "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

                    }

                }
                else {

                    if (-not $WhatIf -and -not $Async) {
    
                        # Timeout: default timeout x nb of servers found in the group
    
                        $Timeout = $NbOfServers * $TimeoutinSecondsPerServer 
        
                        "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose
        
                        $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout 
    
                        "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
    
                    }
                    else {

                        $ReturnData = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs" 

                    }
                }

            }
            catch {

                if (-not $WhatIf) {

                    $PSCmdlet.ThrowTerminatingError($_)

                }
            }  

            if ($ScheduleTime) {

                if (-not $WhatIf ) {
        
                    Return $ReturnData
                
                }
            }
        }

        if (-not $ScheduleTime) {

            [void] $GroupiLOSettingsComplianceStatus.add($_resp)
        }


    }

    End {

        if (-not $ScheduleTime -and -not $WhatIf ) {

            Return $GroupiLOSettingsComplianceStatus

        }

    }
}

function Get-HPECOMGroupiLOConfigurationCompliance {
    <#
    .SYNOPSIS
    Initiate the iLO configuration compliance details of a server within a specified group.

    .DESCRIPTION
    This cmdlet allows you to obtain detailed information about the iLO configuration compliance of all servers in a designated group.
    This cmdlet can be useful for identifying deviations from the group's iLO settings, ensuring that all devices are up to date and compliant with organizational standards.

    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the server group is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER GroupName
    Specifies the name of the server group on which the iLO configuration compliance details will be retrieved.

    .PARAMETER ServerSerialNumber
    Specifies the serial number of an individual server to retrieve its specific compliance details within the group.

    .PARAMETER ShowDeviations
    Switch parameter that retrieves only the iLO configuration components which have deviations from the group's iLO settings.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMGroupiLOConfigurationCompliance -Region eu-central -GroupName ESX-800 -ServerSerialNumber CZ12312312 

    This command returns the iLO configuration compliance of the server with serial number 'CZ12312312' in the group 'ESX-800' in the 'eu-central' region.

    .EXAMPLE
    Get-HPECOMGroupiLOConfigurationCompliance -Region eu-central -GroupName ESX-800 -ServerSerialNumber CZ12312312 -ShowDeviations

    This command returns the iLO configuration components which have a deviation with the group 'ESX-800' iLO configuration baseline in the 'eu-central' region.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the group's name or server's name.

    System.Collections.ArrayList
        List of groups from 'Get-HPECOMGroup'.
        List of servers from 'Get-HPECOMServer' or 'Get-HPECOMGroup -ShowMembers'.

    #>

    [CmdletBinding(DefaultParameterSetName = "ServerSerialNumber")]
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
        
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [String]$GroupName,

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [alias('serial', 'serialnumber')]
        [String]$ServerSerialNumber,

        [switch]$ShowDeviations,

        [switch]$WhatIf

    )

        Begin {
  
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
      
      
    }
            
    Process {
      
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose      

        $Uri = (Get-COMGroupsUri) + "?filter=name eq '$GroupName'"

        try {

            $_group = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region
            $GroupID = $_group.id

            "[{0}] ID found for group '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $GroupID | Write-Verbose

            if ($Null -eq $GroupID) { return }

            $Uri = (Get-COMGroupsUri) + "/" + $GroupID + "/ilo-settings-compliance"
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)

        }
        

        try {
            [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
    
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
                   
        }           
        
        $ReturnData = @()
      
        if ($Null -ne $CollectionList) {   
            
            # Add groupName, servername and serialNumber (only serial is provided)
            # groupName is used in Invoke-HPECOMGroupInternalStorageConfiguration, Update-HPECOMGroupFirmware, etc. 
            Foreach ($Item in $CollectionList) {

                try {
                    $_ServerName = Get-HPECOMServer -Region $Region -Name $Item.serial                        
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }

                $Item | Add-Member -type NoteProperty -name region -value $Region
                $Item | Add-Member -type NoteProperty -name groupName -value $GroupName
                $Item | Add-Member -type NoteProperty -name serialNumber -value $Item.serial
                $item | Add-Member -Type NoteProperty -Name serverName -Value $_ServerName.name
                
            }
                        
            if ($ServerSerialNumber) {

                if ($ShowDeviations) {
                    $CollectionList = $CollectionList | Where-Object serial -eq $ServerSerialNumber | ForEach-Object deviations | Sort-Object -Property category, settingName
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Groups.iLO.Compliance.Deviations"   
                }
                else {
                    $CollectionList = $CollectionList | Where-Object serial -eq $ServerSerialNumber
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Groups.iLO.Compliance"   
                }
            }
            else {
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Groups.iLO.Compliance"   
            }
            
            $ReturnData = $ReturnData | Sort-Object -Property serverName, serial
            return $ReturnData 
                
        }
        else {

            return
                
        }     
    }
}

function Invoke-HPECOMGroupExternalStorageConfiguration {
    <#
    .SYNOPSIS
    Initiate a server group external storage configuration.
    
    .DESCRIPTION   
    This cmdlet initiates a server group external storage configuration that will affect all server group members.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the group is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
        
    .PARAMETER GroupName
    Name of the group on which the external storage configuration will be performed.     
    
    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties). By default, the Cmdlet will wait for the job to complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.
    
    .EXAMPLE
    Invoke-HPECOMGroupExternalStorageConfiguration -Region eu-central -GroupName ESXi_800

    This command initiates a server group external storage configuration of all servers in a group named `ESXi_800` located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central | ForEach-Object { $_ | Invoke-HPECOMGroupExternalStorageConfiguration } 
    
    This command retrieves a list of all groups in the 'eu-central' region and initiates a server group external storage configuration for each group.
    
    .INPUTS
    No pipeline input is supported

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

    #>

    [CmdletBinding()]
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
                
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
        [String]$GroupName,

        [switch]$Async,

        [switch]$WhatIf

    )

    Begin {

        [int]$TimeoutinSecondsPerServer = 60

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $_JobTemplateName = 'GroupApplyExternalStorage'
        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $Uri = Get-COMJobsUri
                
    }
    
    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

    }

    End {
      
        try {
            if ($Region) {
                $_group = Get-HPECOMGroup -Region $Region -Name $GroupName
                $GroupMembers = $_group.devices
                
                $_groupName = $_group.name
                $_groupResourceUri = $_group.resourceUri
                $_groupId = $_group.id
                $NbOfServers = $_group.devices.count
                
                "[{0}] GroupName '{1}' detected - URI: '{2}' - Nb of servers: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_groupName, $_groupResourceUri, $NbOfServers | Write-Verbose
            }
            else {
                Return
            }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        if ( -not $_group) {

            $ErrorMessage = "Group '{0}' cannot be found in the '{1}' region!" -f $GroupName, $Region
            throw $ErrorMessage

        }
        elseif (-not $GroupMembers) {

            # Must return a message if no server members are found in the group
            $ErrorMessage = "Group '{0}' has no members to be configured!" -f $GroupName
            Write-warning $ErrorMessage
            
        }
        else {
        
            # Build payload         
            $payload = @{
                jobTemplate = $JobTemplateId
                resourceId   = $_groupId
                resourceType = "compute-ops-mgmt/group"
                jobParams = $data
            }

            $payload = ConvertTo-Json $payload -Depth 10 

            try {
                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                # Add region to object
                $_resp | Add-Member -type NoteProperty -name region -value $Region

                if (-not $WhatIf -and -not $Async) {    
                 
                    $Timeout = $NbOfServers * $TimeoutinSecondsPerServer
                
                    "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose

                    $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout 
                    "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

                }
                else {

                    $_resp = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs" 

                }
            }
            catch {

                if (-not $WhatIf) {

                    $PSCmdlet.ThrowTerminatingError($_)

                }
            }  

            if (-not $WhatIf ) {
            
                Return $_resp
        
            }

        }
    }
}

function Invoke-HPECOMGroupExternalStorageComplianceCheck {
    <#
    .SYNOPSIS
    Initiate an external storage compliance check on all servers in a group.
    
    .DESCRIPTION   
    This cmdlet initiates an external storage compliance check on all servers within a specified group.
    It also provides options for scheduling the execution at a specific time and setting recurring schedules.

    Note: An external storage server setting must be configured in the server group for the compliance feature to be available.
        
    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the group is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER GroupName
    Name of the group on which the external storage compliance check will be performed.    

    .PARAMETER ScheduleTime
    Specifies the date and time when the compliance check should be executed. 
    This parameter accepts a DateTime object or a string representation of a date and time. 
    If not specified, the compliance check will be executed immediately.

    Examples for setting the date and time using `Get-Date`:
    - (Get-Date).AddMonths(6)
    - (Get-Date).AddDays(15)
    - (Get-Date).AddHours(3)
    Example for using a specific date string:
    - "2024-05-20 08:00:00"

    .PARAMETER Interval
    Specifies the interval at which the compliance check should be repeated. This parameter accepts a TimeSpan object or a string representation of a time interval. 
    If not specified, the compliance check will not be repeated.
    
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
    Invoke-HPECOMGroupExternalStorageComplianceCheck -Region eu-central -GroupName ESX-800  

    This command checks the external storage compliance of all servers in the group 'ESX-800' in the 'eu-central' region.
       
    .EXAMPLE
    Get-HPECOMGroup -Region eu-central | Invoke-HPECOMGroupExternalStorageComplianceCheck 

    This command checks the external storage compliance of all servers in all groups within the 'eu-central' region.
    
    .EXAMPLE
    Invoke-HPECOMGroupExternalStorageComplianceCheck -Region eu-central -GroupName ESX-800 -ScheduleTime (Get-Date).AddHours(1) 

    Schedules the execution of a group external storage compliance check on the group named 'ESX-800' in the `eu-central` region starting 1 hour from now. 
    
    .EXAMPLE
    Get-HPECOMGroup -Region eu-central | Invoke-HPECOMGroupExternalStorageComplianceCheck -ScheduleTime (Get-Date).AddDays(1) -Interval P1M 

    Schedules a monthly execution of a group external storage compliance check on all groups within the `eu-central` region. The first execution will occur one day from now.

    .EXAMPLE
    "ESXi_group", "RHEL_group" | Invoke-HPECOMGroupExternalStorageComplianceCheck -Region  eu-central
    
    This command checks the external storage compliance of all servers in the groups 'ESXi_group' and 'RHEL_group' in the 'eu-central' region.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the group's names.

    System.Collections.ArrayList
        List of groups from 'Get-HPECOMGroup'.

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
        [alias('name')]
        [String]$GroupName,
                
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
            # Validate ISO 8601 duration format
            if ($_ -notmatch '^P(?!$)(\d+Y)?(\d+M)?(\d+W)?(\d+D)?(T(\d+H)?(\d+M)?(\d+S)?)?$') {
                throw "Invalid duration format. Please use an ISO 8601 period interval (e.g., P1D, P1W, P1M, P1Y, PT1H, PT15M)"
            }

            # Extract duration parts
            $years   = [int]($matches[1] -replace '\D', '')  # Y
            $months  = [int]($matches[2] -replace '\D', '')  # M (before T)
            $weeks   = [int]($matches[3] -replace '\D', '')  # W
            $days    = [int]($matches[4] -replace '\D', '')  # D
            $hours   = [int]($matches[6] -replace '\D', '')  # H
            $minutes = [int]($matches[7] -replace '\D', '')  # M (after T)
            $seconds = [int]($matches[8] -replace '\D', '')  # S

            # Calculate total duration in seconds (approximate months/years)
            $totalSeconds = 0
            if ($years)   { $totalSeconds += $years * 365 * 24 * 3600 }
            if ($months)  { $totalSeconds += $months * 30 * 24 * 3600 }
            if ($weeks)   { $totalSeconds += $weeks * 7 * 24 * 3600 }
            if ($days)    { $totalSeconds += $days * 24 * 3600 }
            if ($hours)   { $totalSeconds += $hours * 3600 }
            if ($minutes) { $totalSeconds += $minutes * 60 }
            if ($seconds) { $totalSeconds += $seconds }

            $minSeconds = 15 * 60
            $maxSeconds = 365 * 24 * 3600  # 1 year

            if ($totalSeconds -lt $minSeconds) {
                throw "The interval must be greater than 15 minutes (PT15M)."
            }
            if ($totalSeconds -gt $maxSeconds) {
                throw "The interval must be less than 1 year (P1Y)."
            }
            return $true
        })]
        [Parameter (ParameterSetName = 'Schedule')]
        [String]$Interval,    
        
        [Parameter (ParameterSetName = 'Async')]
        [switch]$Async,

        [switch]$WhatIf

    )

    Begin {

        [int]$TimeoutinSecondsPerServer = 900  # 15 minutes

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $_JobTemplateName = 'GroupExternalStorageCompliance'  
        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $Uri = Get-COMJobsUri
        
        $GroupFirmwareComplianceStatus = [System.Collections.ArrayList]::new()
        
    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        try {

            $_group = Get-HPECOMGroup -Region $Region -Name $GroupName
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
        
        if (-not $_group) {
            
            # Must return a message if resource not found
            $ErrorMessage = "Group '{0}' cannot be found in the '{1}' region!" -f $GroupName, $Region
            Write-warning $ErrorMessage
            return
            
        }
        else {
            
            $_ResourceUri = $_group.resourceUri
            $_GroupId = $_group.id
            $NbOfServers = $_group.devices.count
            
            "[{0}] GroupName '{1}' detected - URI: '{2}' - Nb of servers: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GroupName, $_ResourceUri, $NbOfServers | Write-Verbose         

            if ($NbOfServers -eq 0) {

                # Must return a message if no servers in group
                Write-Warning "Operation on group '$GroupName' cannot be executed because no server has been found in the group!"
                return
            }


            if ($ScheduleTime) {

                $Uri = Get-COMSchedulesUri

                $_Body = @{
                    jobTemplateUri = "/api/compute/v1/job-templates/" + $JobTemplateId
                    resourceUri    = $_ResourceUri
                }      

                $Operation = @{
                    type   = "REST"
                    method = "POST"
                    uri    = "/api/compute/v1/jobs"
                    body   = $_Body

                }

                $randomNumber = Get-Random -Minimum 000000 -Maximum 999999

                $Name = "$($GroupName)_GroupExternalStorageComplianceCheck_Schedule_$($randomNumber)"
                $Description = "Scheduled task to run a group external storage compliance check on '$($GroupName)'"

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
                    purpose               = "GROUP_EXTERNAL_STORAGE_COMPLIANCE_CHECK"
                    schedule              = $Schedule
                    operation             = $Operation

                }

            }
            else {

                $payload = @{
                    jobTemplate = $JobTemplateId
                    resourceId   = $_groupId
                    resourceType = "compute-ops-mgmt/group"
                    jobParams = @{}
                }
                
            }


            $payload = ConvertTo-Json $payload -Depth 10 

            try {
                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                # Add region to object
                $_resp | Add-Member -type NoteProperty -name region -value $Region
                # Apply Jobs format
                $_resp = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs" 

                if ($ScheduleTime) {

                    if (-not $WhatIf) {
    
                        $ReturnData = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Schedules"

                        "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

                    }

                }
                else {

                    if (-not $WhatIf -and -not $Async) {
    
                        # Timeout: default timeout x nb of servers found in the group
    
                        $Timeout = $NbOfServers * $TimeoutinSecondsPerServer 
        
                        "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose
        
                        $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout
    
                        "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
    
                    }
                    else {

                        $ReturnData = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs" 
    
                    }
                }

            }
            catch {

                if (-not $WhatIf) {

                    $PSCmdlet.ThrowTerminatingError($_)

                }
            }  
            
            if ($ScheduleTime) {

                if (-not $WhatIf ) {
        
                    Return $ReturnData
                
                }
            }
        }
        if (-not $ScheduleTime) {

            [void] $GroupFirmwareComplianceStatus.add($_resp)
        }


    }

    End {

        if (-not $ScheduleTime -and -not $WhatIf ) {
            
            Return $GroupFirmwareComplianceStatus
        
        }

    }
}

function Update-HPECOMApplianceFirmware {
    <#
    .SYNOPSIS
    UUpdates the firmware on a specified appliance.
    
    .DESCRIPTION   
    This cmdlet updates the firmware on an appliance using its IP address. It also provides an option to schedule the update at a specific time.
        
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the appliance is located.
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER IPAddress
    Specifies the IP address of the appliance for the firmware update.

    .PARAMETER ApplianceFirmwareBundleReleaseVersion
    Mandatory parameter specifying the appliance firmware bundle release version to use for the update. 
    The release version can be obtained using 'Get-HPECOMApplianceFirmwareBundle'.

    .PARAMETER ScheduleTime
    Specifies the date and time when the appliance firmware update should be executed. 
    This parameter accepts a DateTime object or a string representation of a date and time. 
    If not specified, the appliance firmware update will be executed immediately.

    Examples for setting the date and time using `Get-Date`:
    - (Get-Date).AddMonths(6)
    - (Get-Date).AddDays(15)
    - (Get-Date).AddHours(3)
    Example for using a specific date string:
    - "2024-05-20 08:00:00"

    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties). By default, the Cmdlet will wait for the job to complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Update-HPECOMApplianceFirmware -Region eu-central -IPAddress 192.168.7.59 -ApplianceFirmwareBundleReleaseVersion 9.00.00 

    This command updates the firmware on a OneView appliance with the IP address `192.168.7.59` located in the `eu-central` region using firmware bundle release version `9.00.00`. 
    
    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Name composer.lab | Update-HPECOMApplianceFirmware -ApplianceFirmwareBundleReleaseVersion 9.00.00

    This command retrieves OneView appliances with the hostname 'composer.lab' in the `eu-central` region.
    It then updates the firmware on these appliances using firmware bundle release version `9.00.00`.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central | Update-HPECOMApplianceFirmware -ApplianceFirmwareBundleReleaseVersion 9.00.00 
    
    This command updates all OneView appliances in the 'eu-central' region with the specified firmware bundle release version.
    First, it retrieves a list of all OneView appliances in the "eu-central" region.
    Then, the retrieved appliances are piped (|) to the Update-HPECOMApplianceFirmware cmdlet to update their firmware to the specified version.

    .EXAMPLE
    "192.168.1.2", "192.168.1.10" | Update-HPECOMApplianceFirmware -Region eu-central -ApplianceFirmwareBundleReleaseVersion 9.00.00

    This command updates the firmware on the appliances with the IP addresses `192.168.1.2'and '192.168.1.10'.
    The firmware update is performed in the `eu-central` region using firmware bundle release version `9.00.00`.

    .EXAMPLE
    Update-HPECOMApplianceFirmware -Region eu-central -IPAddress 192.168.7.59 -ApplianceFirmwareBundleReleaseVersion 9.00.00 -ScheduleTime ((Get-Date).AddMinutes(10))   

    This command schedules a firmware update for the appliance with the IP address `192.168.7.59` in the `eu-central` region using firmware bundle release version `9.00.00`, starting 10 minutes from now. 

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Name composer.domain.net | Update-HPECOMApplianceFirmware -ApplianceFirmwareBundleReleaseVersion 9.00.00 -ScheduleTime ((Get-Date).AddHours(2))  

    This command first retrieves OneView appliances with the hostname 'composer.domain.net' in the `eu-central` region.
    It then schedules a firmware update for this appliance using firmware bundle release version `9.00.00`, starting 2 hours from now.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central | Update-HPECOMApplianceFirmware -ApplianceFirmwareBundleReleaseVersion 9.00.00 -ScheduleTime ((Get-Date).AddDays(5))  

    This command first retrieves all OneView appliances in the `eu-central` region.
    It then schedules a firmware update for these appliances using firmware bundle release version `9.00.00`, starting 5 days from now.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the appliance's IP addresses.

    System.Collections.ArrayList
        List of appliances from 'Get-HPECOMAppliance'.

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

    [CmdletBinding(DefaultParameterSetName = 'Scheduled')]
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
        
        # [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'IP')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript({ [String]::IsNullOrEmpty($_) -or $_ -match [Net.IPAddress]$_ })]
        [string]$IPAddress,
        
        [Parameter (Mandatory)]
        [String]$ApplianceFirmwareBundleReleaseVersion,

        [Parameter (ParameterSetName = 'Scheduled')]
        [ValidateScript({
                if ($_ -ge (Get-Date) -and $_ -le (Get-Date).AddYears(1)) {
                    $true
                }
                else {
                    throw "The ScheduleTime must be within one year from the current date."
                }
            })]
        [DateTime]$ScheduleTime,

        [Parameter (ParameterSetName = 'Async')]
        [switch]$Async,

        [switch]$WhatIf

    )

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $_JobTemplateName = 'ApplianceUpdate'

        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $Uri = Get-COMJobsUri
        $ApplianceFWUpdateStatus = [System.Collections.ArrayList]::new()

        $Timeout = 3600 # 1 hour
        
    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        try {

            $_appliance = Get-HPECOMAppliance -Region $Region -IPAddress $IPAddress           

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
        
        if (-not $_appliance) {

            # Must return a message if not found
            $ErrorMessage = "Appliance '{0}' cannot be found in the '{1}' region!" -f $IPAddress, $Region
            Write-warning $ErrorMessage

        }
        elseif( $_appliance.applianceType -eq "GATEWAY") {

            $ErrorMessage = "Appliance '{0}' is not a OneView appliance and cannot be updated using this cmdlet!" -f $IPAddress
            Write-warning $ErrorMessage

        }
        else {

            $_applianceResourceUri = $_appliance.resourceUri
            $_applianceDeviceID = $_appliance.deviceId
            $_applianceType = $_appliance.applianceType
            $_applianceName = $_appliance.name
            $_applianceVersion = $_appliance.version.split("-")[0]  # Get only the version number, not the build number
            # $_applianceBaseVersion = "$($_applianceVersion.Major).$($_applianceVersion.Minor).$($_applianceVersion.Build)"  # Get only the Major.Minor.Build part of the version
            
            "[{0}] Appliance '{1}' detected - URI: '{2}' - DeviceID: '{3}' - Type: '{4}' - Version: '{5}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IPAddress, $_applianceResourceUri, $_applianceDeviceID, $_applianceType, $_applianceVersion | Write-Verbose
            
            try {
                $Bundle = Get-HPECOMApplianceFirmwareBundle -Region $Region -Version $ApplianceFirmwareBundleReleaseVersion -Type $_applianceType

                $BundleID = $Bundle.id
                
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
                
            }

            if (-not $BundleID) {
                # Must return a message if not found
                    
                $ErrorMessage = "The appliance firmware bundle release version '{0}' cannot be found in the '{1}' region!" -f $ApplianceFirmwareBundleReleaseVersion, $Region
                throw $ErrorMessage
    
            }
            else {

                # Check bundle is in the supported upgrade paths
                $SupportedUpgrades = Get-HPECOMApplianceFirmwareBundle -Region $Region -Version $ApplianceFirmwareBundleReleaseVersion -Type $_applianceType -SupportedUpgrades

                if ($SupportedUpgrades -notcontains $_applianceVersion) {

                    $ErrorMessage = "The appliance firmware bundle release version '{0}' is not in the supported upgrade paths for appliance '{1}' with current firmware version '{2}'!" -f $ApplianceFirmwareBundleReleaseVersion, $IPAddress, $_applianceVersion
                    throw $ErrorMessage

                }

                $data = @{
                    applianceFirmwareId = $BundleID

                }

                if ($ScheduleTime) {

                    $Uri = Get-COMSchedulesUri
    
                    $_Body = @{
                        jobTemplateUri = "/api/compute/v1/job-templates/" + $JobTemplateId
                        resourceUri    = $_applianceResourceUri
                        data           = $data
                    }      
    
                    $Operation = @{
                        type   = "REST"
                        method = "POST"
                        uri    = "/api/compute/v1/jobs"
                        body   = $_Body
    
                    }
    
                    $randomNumber = Get-Random -Minimum 000000 -Maximum 999999
    
                    $Name = "$($_applianceName)_ApplianceFirmwareUpdate_Schedule_$($randomNumber)"
                    $Description = "Scheduled task to update firmware for '$IPAddress' appliance"
    
    
                    $Schedule = @{
                        startAt = $ScheduleTime.ToString("o")  # Convert to ISO 8601 format as $ScheduleTime alone is convert by PS5.1 to '/Date(...)\/ notation'
                        # interval = $Null
                    }
    
    
                    $Payload = @{
                        name                  = $Name
                        description           = $Description
                        associatedResourceUri = $_applianceResourceUri
                        purpose               = "APPLIANCE_FW_UPDATE"
                        schedule              = $Schedule
                        operation             = $Operation
    
                    }
    
                }
                else {
    
                    # Build payload
                    $payload = @{
                        jobTemplate = $JobTemplateId
                        resourceId   = $_applianceDeviceID
                        resourceType = "compute-ops-mgmt/oneview-appliance"
                        jobParams = $data
                    }
                }


                $payload = ConvertTo-Json $payload -Depth 10 

                try {
                    $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                    # Add region to object
                    $_resp | Add-Member -type NoteProperty -name region -value $Region
                    # Apply Jobs format
                    $_resp = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs" 

                    if ($ScheduleTime) {

                        if (-not $WhatIf) {
        
                            $ReturnData = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Schedules"
    
                            "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
    
                        }
    
                    }
                    else {

                        if (-not $WhatIf -and -not $Async) {

                            "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $timeout | Write-Verbose

                            $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $timeout
                            "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
    
                        }
                        else {

                            $ReturnData = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs" 
        
                        }
                    }
                }
                catch {

                    if (-not $WhatIf) {

                        $PSCmdlet.ThrowTerminatingError($_)

                    }
                }  

                if ($ScheduleTime) {

                    if (-not $WhatIf ) {
            
                        Return $ReturnData
                    
                    }
                }
            }
        }

        if (-not $ScheduleTime) {

            [void] $ApplianceFWUpdateStatus.add($_resp)
        }

    }

    End {

        if (-not $ScheduleTime -and -not $WhatIf ) {
            
            Return $ApplianceFWUpdateStatus
        
        }

    }
}

function Get-HPECOMIloSecuritySatus {
    <#
    .SYNOPSIS
    Retrieve the list of iLO security status.
    
    .DESCRIPTION   
    This cmdlet can be used to retrieve the list of iLO security risk settings of a server.
        
    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the server is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
        
    .PARAMETER ServerName
    Name or serial number of the server for which the iLO security risk settings will be retrieved.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMIloSecuritySatus -Region eu-central -ServerName "CZ12312312" 

    This command returns the iLO security risk settings of the server with serial number 'CZ12312312' located in the `eu-central` region. 

    .EXAMPLE
    Get-HPECOMIloSecuritySatus -Region eu-central -ServerName ESX-1.domain.com

    This command returns the iLO security risk settings of the server with the name 'ESX-1.domain.com' located in the `eu-central` region.
   
    .INPUTS
    System.Collections.ArrayList
        List of servers retrieved using 'Get-HPECOMServer'.

    #>

    [CmdletBinding()]
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

        [Parameter (ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ByName')]
        # [Alias('name')]
        [String]$ServerName,

        [switch]$WhatIf

    )

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose


    }
    
    Process {
        
        # $Uri = (Get-COMServersUri) + "?filter=host/hostname eq '$ServerName' or name eq '$ServerName'"   # Filter that supports both serial numbers and server names


        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose


        try {

            $Server = Get-HPECOMServer -Region $Region -Name $ServerName

            "[{0}] ID found for server name '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServerName, $Server.ID | Write-Verbose
                    
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
       
        }

        if ($server.connectionType -eq "ONEVIEW" ) {
            Write-Warning "'$($ServerName)': The iLO security settings are not supported for OneView managed servers."
            return

        }
        elseif ($Server) {
            
            $Uri = (Get-COMServersUri) + "/" + $Server.id + "/security-parameters"
            
            try {
                [Array]$CollectionList = Invoke-HPECOMWebRequest -Method GET -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                            
            }
            catch {

                Write-Error "Unable to retrieve iLO security parameters details for '$ServerName'. Please check the iLO event logs for more details."
                $PSCmdlet.ThrowTerminatingError($_)
                    
            }

            if ($Null -ne $CollectionList) {     
            
                # Add region and serverName to object
                $CollectionList | Add-Member -type NoteProperty -name region -value $Region
                $CollectionList | ForEach-Object { $_ | Add-Member -type NoteProperty -name serverName -value $_.name }


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

            if (-not $WhatIf) {
                
                return $ReturnData 

            }
        }                       
        
        else {
            Return
        }

    }
}

function Enable-HPECOMIloIgnoreRiskSetting {
    <#
    .SYNOPSIS
    Enable ignore iLO security risk settings.
    
    .DESCRIPTION   
    This cmdlet can be used to enable ignore iLO security risk settings on a server.
        
    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the server is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
        
    .PARAMETER SerialNumber
    Serial number of the server on which the ignore iLO security risk will be enabled.
    
    .PARAMETER AccessPanelStatus 
    Parameter to enable the option to ignore the access panel status security risk warning.

    .PARAMETER AuthenticationFailureLogging 
    Parameter to enable the option to ignore the authentication failure logging security risk warning.

    .PARAMETER DefaultSSLCertificateInUse 
    Parameter to enable the option to ignore the default SSL Certificate In Use security risk warning.

    .PARAMETER GlobalComponentIntegrity
    Parameter to enable the option to ignore the global component integrity security risk warning.

    .PARAMETER IPMIDCMIOverLAN
    Parameter to enable the option to ignore the IPMI/DCMI Over LAN security risk warning.

    .PARAMETER LastFirmwareScanResult 
    Parameter to enable the option to ignore the last firmware scan result security risk warning.

    .PARAMETER MinimumPasswordLength 
    Parameter to enable the option to ignore the minimum password length security risk warning.

    .PARAMETER PasswordComplexity 
    Parameter to enable the option to ignore the password complexity security risk warning.

    .PARAMETER RequireHostAuthentication 
    Parameter to enable the option to ignore the require host authentication security risk warning.

    .PARAMETER RequireLoginforiLORBSU 
    Parameter to enable the option to ignore the require login for iLO RBSU security risk warning.

    .PARAMETER SecureBoot 
    Parameter to enable the option to ignore the secure boot security risk warning.

    .PARAMETER SecurityOverrideSwitch 
    Parameter to enable the option to ignore the security override switch security risk warning.

    .PARAMETER SNMPv1 
    Parameter to enable the option to ignore the SNMPv1 request: disabled security risk warning.

    .PARAMETER All
    Parameter to enable all ignore iLO security risk settings.

    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties). By default, the Cmdlet will wait for the job to complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Enable-HPECOMIloIgnoreRiskSetting -Region eu-central -SerialNumber "CZ12312312" -AccessPanelStatus -AuthenticationFailureLogging

    This command enables the ignore iLO security risk settings "Access Panel Status" and "Authentication Failure Logging" on the server with serial number 'CZ12312312' located in the `eu-central` region. 
   
    .EXAMPLE
    Enable-HPECOMIloIgnoreRiskSetting -Region eu-central -SerialNumber "CZ12312312" -AccessPanelStatus -AuthenticationFailureLogging -DefaultSSLCertificateInUse -IPMIDCMIOverLAN -LastFirmwareScanResult -MinimumPasswordLength -PasswordComplexity -RequireHostAuthentication -RequireLoginforiLORBSU -SecureBoot -SecurityOverrideSwitch -SNMPv1 

    This command enables all ignore iLO security risk settings on the server with serial number 'CZ12312312' located in the `eu-central` region. 

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-1 | Enable-HPECOMIloIgnoreRiskSetting -AccessPanelStatus -AuthenticationFailureLogging -DefaultSSLCertificateInUse 

    This command enables the ignore iLO security risk settings "Access Panel Status", "Authentication Failure Logging", and "Default SSL Certificate In Use" on the server named 'ESX-1' located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -ConnectionType Direct | Enable-HPECOMIloIgnoreRiskSetting -All 

    This command enables all ignore iLO security risk settings on the servers with a direct connection type located in the `eu-central` region.

    .EXAMPLE
    "CZ12312312", "DZ12312312" | Enable-HPECOMIloIgnoreRiskSetting -Region eu-central -MinimumPasswordLength 

    This command enables the ignore iLO security risk setting "Minimum Password Length" on the servers with serial numbers 'CZ12312312' and 'DZ12312312' located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central | Select-Object -First 3 | Enable-HPECOMIloIgnoreRiskSetting -MinimumPasswordLength -PasswordComplexity

    The first command retrieves all servers in the 'eu-central' region. The second command selects the first three servers.
    The third command enables the ignore iLO security risk settings "Minimum Password Length" and "Password Complexity" on the selected servers.
 
    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.

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

    #>

    [CmdletBinding()]
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

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [alias('serial')]
        [String]$SerialNumber,

        [Parameter (ParameterSetName = 'Custom')]
        [switch]$AccessPanelStatus,

        [Parameter (ParameterSetName = 'Custom')]
        [switch]$AuthenticationFailureLogging,
        
        [Parameter (ParameterSetName = 'Custom')]    
        [switch]$DefaultSSLCertificateInUse,

        [Parameter (ParameterSetName = 'Custom')]
        [switch]$GlobalComponentIntegrity,

        [Parameter (ParameterSetName = 'Custom')]            
        [switch]$IPMIDCMIOverLAN,

        [Parameter (ParameterSetName = 'Custom')]            
        [switch]$LastFirmwareScanResult,

        [Parameter (ParameterSetName = 'Custom')]            
        [switch]$MinimumPasswordLength,

        [Parameter (ParameterSetName = 'Custom')]            
        [switch]$PasswordComplexity,

        [Parameter (ParameterSetName = 'Custom')]            
        [switch]$RequireHostAuthentication,

        [Parameter (ParameterSetName = 'Custom')]    
        [switch]$RequireLoginforiLORBSU,

        [Parameter (ParameterSetName = 'Custom')]            
        [switch]$SecureBoot,

        [Parameter (ParameterSetName = 'Custom')]           
        [switch]$SecurityOverrideSwitch,
            
        [Parameter (ParameterSetName = 'Custom')]
        [switch]$SNMPv1,

        [Parameter (ParameterSetName = 'All')]
        [switch]$All,

        [switch]$Async,

        [switch]$WhatIf

    )

    Begin {

        [int]$TimeoutinSecondsPerServer = 60

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $_JobTemplateName = 'iLOSecurity'

        $JobTemplateUri = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object resourceuri
        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $Uri = Get-COMJobsUri      
        
        $ObjectStatusList = [System.Collections.ArrayList]::new()

        if (-not $All -and -not ($AccessPanelStatus -or $AuthenticationFailureLogging -or $DefaultSSLCertificateInUse -or $IPMIDCMIOverLAN -or $LastFirmwareScanResult -or $MinimumPasswordLength -or $PasswordComplexity -or $RequireHostAuthentication -or $RequireLoginforiLORBSU -or $SecureBoot -or $SecurityOverrideSwitch -or $SNMPv1)) {
            
            # Must return a message if no parameter is used    
            $ErrorMessage = "At least one ignore iLO security risk setting must be used with this cmdlet!" -f $ParamUsed
            $ErrorRecord = New-ErrorRecord IgnoreParameterNotFound InvalidArgument -TargetObject 'Server' -Message $ErrorMessage 
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }

    }
    
    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build tracking object for the output
        $objStatus = [pscustomobject]@{
  
            associatedResource     = $SerialNumber
            date                   = "$((Get-Date).ToString())"
            state                  = $Null
            name                   = $_JobTemplateName
            duration               = $Null
            resultCode             = $Null
            status                 = $Null
            message                = $Null    
            region                 = $Region  
            jobUri                 = $Null 
            details                = $Null        
            ignoreSecuritySettings = [System.Collections.ArrayList]::new()       
        
        }

        try {
            $ServerIloSecurityStatus = Get-HPECOMIloSecuritySatus -Region $Region -ServerName $SerialNumber -ErrorAction SilentlyContinue
        
        }
        catch {

            $objStatus.state = "ERROR"
            $objStatus.duration = '00:00:00'
            $objStatus.resultCode = "FAILURE"
            $objStatus.Status = "Failed"
            $objStatus.message = $_.Exception.Message -replace "`r`n", " " -replace "`n", " " -replace "`r", " "

            if ($WhatIf) {
                $ErrorMessage = "Unable to retrieve iLO security parameters details for '$SerialNumber'. Please check the iLO event logs for more details."
                Write-warning $ErrorMessage
                return
            }
        }

        if ($ServerIloSecurityStatus) {

            # Build $IgnoreSecuritySettings
            function New-Setting {
                param (
                    [string]$Name,
                    [string]$Id
                )
            
                return @{
                    name   = $Name
                    ignore = $true
                    id     = $Id
                }
            }

            if ($All) {

                $ServerIloSecurityStatus | ForEach-Object {
                    $Name = $_ | ForEach-Object name
                    $ID = $_ | ForEach-Object id

                    $PayloadSetting = New-Setting $Name $ID
                    [void]$objStatus.ignoreSecuritySettings.add($PayloadSetting)

                    "[{0}] Ignore iLO security risk setting '{1}' enabled for server '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $SerialNumber | Write-Verbose
                }

            }
            else {

                $settings = @(
                    @{ Name = "Access Panel Status"; Flag = $AccessPanelStatus },
                    @{ Name = "Authentication Failure Logging"; Flag = $AuthenticationFailureLogging },
                    @{ Name = "Default SSL Certificate In Use"; Flag = $DefaultSSLCertificateInUse },
                    @{ Name = "Global Component Integrity"; Flag = $GlobalComponentIntegrity },
                    @{ Name = "IPMI/DCMI Over LAN"; Flag = $IPMIDCMIOverLAN },
                    @{ Name = "Last Firmware Scan Result"; Flag = $LastFirmwareScanResult },
                    @{ Name = "Minimum Password Length"; Flag = $MinimumPasswordLength },
                    @{ Name = "Password Complexity"; Flag = $PasswordComplexity },
                    @{ Name = "Require Host Authentication"; Flag = $RequireHostAuthentication },
                    @{ Name = "Require Login for iLO RBSU"; Flag = $RequireLoginforiLORBSU },
                    @{ Name = "Secure Boot"; Flag = $SecureBoot },
                    @{ Name = "Security Override Switch"; Flag = $SecurityOverrideSwitch },
                    @{ Name = "SNMPv1"; Flag = $SNMPv1 }
                )
    
                foreach ($setting in $settings) {
    
                    if ($setting.Flag) {
                        $Name = $ServerIloSecurityStatus | Where-Object name -eq $setting.Name | ForEach-Object name
                        $ID = $ServerIloSecurityStatus | Where-Object name -eq $setting.Name | ForEach-Object id
    
                        if ($Name) {
                            $PayloadSetting = New-Setting $Name $ID
                            [void]$objStatus.ignoreSecuritySettings.add($PayloadSetting)
    
                            "[{0}] Ignore iLO security risk setting '{1}' enabled for server '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $setting.Name, $SerialNumber | Write-Verbose
                        } 
                        else {
    
                            Write-Warning "The iLO security risk setting '$($setting.Name)' is not available for server '$SerialNumber'. This setting will be ignored."
                        }
                    }
                }
            }            
        }
       
        # Add tracking object to the list of object status list
        [void]$ObjectStatusList.Add($objStatus)

    }

    end {       

        try {
            if ($Region) {

                $Servers = Get-HPECOMServer -Region $Region
            }
            else {
                Return
            }
        
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }
        
        
        foreach ($Resource in $ObjectStatusList) {

            if ($Resource.state -eq "ERROR") {
                continue
            }
            else {
                
                $Server = $Servers | Where-Object serialNumber -eq $Resource.associatedResource


                if (-not $Server) {
                    $Resource.state = "ERROR"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.Status = "Failed"
                    $Resource.message = "The server with serial number '$($Resource.associatedResource)' cannot be found in the Compute Ops Management instance."
                    
                    if ($WhatIf) {
                        $ErrorMessage = "The server with serial number '$($Resource.associatedResource)' cannot be found in the Compute Ops Management instance."
                        Write-warning $ErrorMessage
                        continue
                    }
                }
                elseif ($Server.connectionType -eq "ONEVIEW") {
                    $Resource.state = "ERROR"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.Status = "Failed"
                    $Resource.message = "The iLO security settings are not supported on this server."
                    
                    if ($WhatIf) {
                        $ErrorMessage = "'{0}': The iLO security settings are not supported for OneView managed servers." -f $Resource.associatedResource
                        Write-warning $ErrorMessage
                        continue
                    }
                }
    
                else {
    
                    # Build payload
                    $data = @{
                        ignoreSecuritySettings = $Resource.ignoreSecuritySettings
                    }
                       
                    $payload = @{
                        jobTemplate = $JobTemplateId
                        resourceId   = $Server.id
                        resourceType = "compute-ops-mgmt/server"
                        jobParams = $data 
                    }

                    $payload = ConvertTo-Json $payload -Depth 10           
        
                    try {
            
                        $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference      
            
                        if (-not $WhatIf -and -not $Async) {    
                                
                            $Timeout = $TimeoutinSecondsPerServer
                            
                            "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose
            
                            $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout 
            
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
        
                            $Resource.state = $_resp.state
                            $Resource.duration = $Duration
                            $Resource.resultCode = $_resp.resultCode
                            $Resource.status = $_resp.Status
                            $Resource.details = $_resp
                            $Resource.jobUri = $_resp.resourceUri
        
                            "[{0}] Resource content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Resource | Write-Verbose
                        
                        }
                    }
                    catch {
            
                        if (-not $WhatIf) {
        
                            $Resource.state = "ERROR"
                            $Resource.duration = '00:00:00'
                            $Resource.resultCode = "FAILURE"
                            $Resource.status = "Failed"
                            $Resource.message = $_.Exception.Message -replace "`r`n", " " -replace "`n", " " -replace "`r", " "
                            
                        }
                    }  
                }
            }
        }
        
        if (-not $WhatIf) {

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "COM.Jobs.Status" 
            Return $ObjectStatusList
        }
    }  
   
}

function Disable-HPECOMIloIgnoreRiskSetting {
    <#
    .SYNOPSIS
    Disable ignore iLO security risk settings.
    
    .DESCRIPTION   
    This cmdlet can be used to disable ignore iLO security risk settings on a server.
        
    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the server is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
        
    .PARAMETER SerialNumber
    Serial number of the server on which the ignore iLO security risk will be disabled.
        
    .PARAMETER AccessPanelStatus 
    Parameter to disable the option to ignore the access panel status security risk warning.

    .PARAMETER AuthenticationFailureLogging 
    Parameter to disable the option to ignore the authentication failure logging security risk warning.

    .PARAMETER DefaultSSLCertificateInUse 
    Parameter to disable the option to ignore the default SSL Certificate In Use security risk warning.

    .PARAMETER GlobalComponentIntegrity
    Parameter to disable the option to ignore the global component integrity security risk warning.

    .PARAMETER IPMIDCMIOverLAN
    Parameter to disable the option to ignore the IPMI/DCMI Over LAN security risk warning.

    .PARAMETER LastFirmwareScanResult 
    Parameter to disable the option to ignore the last firmware scan result security risk warning.

    .PARAMETER MinimumPasswordLength 
    Parameter to disable the option to ignore the minimum password length security risk warning.

    .PARAMETER PasswordComplexity 
    Parameter to disable the option to ignore the password complexity security risk warning.

    .PARAMETER RequireHostAuthentication 
    Parameter to disable the option to ignore the require host authentication security risk warning.

    .PARAMETER RequireLoginforiLORBSU 
    Parameter to disable the option to ignore the require login for iLO RBSU security risk warning.

    .PARAMETER SecureBoot 
    Parameter to disable the option to ignore the secure boot security risk warning.

    .PARAMETER SecurityOverrideSwitch 
    Parameter to disable the option to ignore the security override switch security risk warning.

    .PARAMETER SNMPv1 
    Parameter to disable the option to ignore the SNMPv1 request: disabled security risk warning.

    .PARAMETER All
    Parameter to disable all ignore iLO security risk settings.

    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties). By default, the Cmdlet will wait for the job to complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Disable-HPECOMIloIgnoreRiskSetting -Region eu-central -SerialNumber "CZ12312312" -AccessPanelStatus -AuthenticationFailureLogging

    This command disables the ignore iLO security risk settings "Access Panel Status" and "Authentication Failure Logging" on the server with serial number 'CZ12312312' located in the `eu-central` region. 
   
    .EXAMPLE
    Disable-HPECOMIloIgnoreRiskSetting -Region eu-central -SerialNumber "CZ12312312" -AccessPanelStatus -AuthenticationFailureLogging -DefaultSSLCertificateInUse -IPMIDCMIOverLAN -LastFirmwareScanResult -MinimumPasswordLength -PasswordComplexity -RequireHostAuthentication -RequireLoginforiLORBSU -SecureBoot -SecurityOverrideSwitch -SNMPv1 

    This command disables all ignore iLO security risk settings on the server with serial number 'CZ12312312' located in the `eu-central` region. 

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -ConnectionType Direct | Disable-HPECOMIloIgnoreRiskSetting -All 

    This command disables all ignore iLO security risk settings on the servers with a direct connection type located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-1 | Disable-HPECOMIloIgnoreRiskSetting -AccessPanelStatus -AuthenticationFailureLogging -DefaultSSLCertificateInUse

    This command disables the ignore iLO security risk settings "Access Panel Status", "Authentication Failure Logging", and "Default SSL Certificate In Use" on the server named 'ESX-1' located in the `eu-central` region.

    .EXAMPLE
    "CZ12312312", "DZ12312312" | Disable-HPECOMIloIgnoreRiskSetting -Region eu-central -MinimumPasswordLength

    This command disables the ignore iLO security risk setting "Minimum Password Length" on the servers with serial numbers 'CZ12312312' and 'DZ12312312' located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central | Select-Object -First 3 | Disable-HPECOMIloIgnoreRiskSetting -MinimumPasswordLength -PasswordComplexity

    The first command retrieves all servers in the 'eu-central' region. The second command selects the first three servers.
    The third command disables the ignore iLO security risk settings "Minimum Password Length" and "Password Complexity" on the selected servers.
 
    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.

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

    #>

    [CmdletBinding()]
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

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [alias('serial')]
        [String]$SerialNumber,   

        [Parameter (ParameterSetName = 'Custom')]
        [switch]$AccessPanelStatus,

        [Parameter (ParameterSetName = 'Custom')]
        [switch]$AuthenticationFailureLogging,
        
        [Parameter (ParameterSetName = 'Custom')]    
        [switch]$DefaultSSLCertificateInUse,

        [Parameter (ParameterSetName = 'Custom')]
        [switch]$GlobalComponentIntegrity,

        [Parameter (ParameterSetName = 'Custom')]            
        [switch]$IPMIDCMIOverLAN,

        [Parameter (ParameterSetName = 'Custom')]            
        [switch]$LastFirmwareScanResult,

        [Parameter (ParameterSetName = 'Custom')]            
        [switch]$MinimumPasswordLength,

        [Parameter (ParameterSetName = 'Custom')]            
        [switch]$PasswordComplexity,

        [Parameter (ParameterSetName = 'Custom')]            
        [switch]$RequireHostAuthentication,

        [Parameter (ParameterSetName = 'Custom')]    
        [switch]$RequireLoginforiLORBSU,

        [Parameter (ParameterSetName = 'Custom')]            
        [switch]$SecureBoot,

        [Parameter (ParameterSetName = 'Custom')]           
        [switch]$SecurityOverrideSwitch,
            
        [Parameter (ParameterSetName = 'Custom')]
        [switch]$SNMPv1,

        [Parameter (ParameterSetName = 'All')]
        [switch]$All,

        [switch]$Async,

        [switch]$WhatIf

    )

    Begin {

        [int]$TimeoutinSecondsPerServer = 60

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $_JobTemplateName = 'iLOSecurity'

        $JobTemplateUri = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object resourceuri
        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $Uri = Get-COMJobsUri      
        
        $ObjectStatusList = [System.Collections.ArrayList]::new()

        if (-not $All -and -not ($AccessPanelStatus -or $AuthenticationFailureLogging -or $DefaultSSLCertificateInUse -or $IPMIDCMIOverLAN -or $LastFirmwareScanResult -or $MinimumPasswordLength -or $PasswordComplexity -or $RequireHostAuthentication -or $RequireLoginforiLORBSU -or $SecureBoot -or $SecurityOverrideSwitch -or $SNMPv1)) {
            
            # Must return a message if no parameter is used    
            $ErrorMessage = "At least one ignore iLO security risk setting must be used with this cmdlet!" -f $ParamUsed
            $ErrorRecord = New-ErrorRecord IgnoreParameterNotFound InvalidArgument -TargetObject 'Server' -Message $ErrorMessage 
            $PSCmdlet.ThrowTerminatingError($ErrorRecord)
        }

    }
    
    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build tracking object for the output
        $objStatus = [pscustomobject]@{
  
            associatedResource     = $SerialNumber
            date                   = "$((Get-Date).ToString())"
            state                  = $Null
            name                   = $_JobTemplateName
            duration               = $Null
            resultCode             = $Null
            status                 = $Null
            message                = $Null    
            region                 = $Region  
            jobUri                 = $Null 
            details                = $Null        
            ignoreSecuritySettings = [System.Collections.ArrayList]::new()       
        
        }

        try {
            $ServerIloSecurityStatus = Get-HPECOMIloSecuritySatus -Region $Region -ServerName $SerialNumber -ErrorAction SilentlyContinue
        
        }
        catch {

            $objStatus.state = "ERROR"
            $objStatus.duration = '00:00:00'
            $objStatus.resultCode = "FAILURE"
            $objStatus.Status = "Failed"
            $objStatus.message = $_.Exception.Message -replace "`r`n", " " -replace "`n", " " -replace "`r", " "

            if ($WhatIf) {
                $ErrorMessage = "Unable to retrieve iLO security parameters details for '$SerialNumber'. Please check the iLO event logs for more details."
                Write-warning $ErrorMessage
                return
            }
            
        }

        if ($ServerIloSecurityStatus) {

            # Build $IgnoreSecuritySettings
            function New-Setting {
                param (
                    [string]$Name,
                    [string]$Id
                )
            
                return @{
                    name   = $Name
                    ignore = $false
                    id     = $Id
                }
            }

            if ($All) {

                $ServerIloSecurityStatus | ForEach-Object {
                    $Name = $_ | ForEach-Object name
                    $ID = $_ | ForEach-Object id

                    $PayloadSetting = New-Setting $Name $ID
                    [void]$objStatus.ignoreSecuritySettings.add($PayloadSetting)

                    "[{0}] Ignore iLO security risk setting '{1}' enabled for server '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $SerialNumber | Write-Verbose
                }

            }
            else {

                $settings = @(
                    @{ Name = "Access Panel Status"; Flag = $AccessPanelStatus },
                    @{ Name = "Authentication Failure Logging"; Flag = $AuthenticationFailureLogging },
                    @{ Name = "Default SSL Certificate In Use"; Flag = $DefaultSSLCertificateInUse },
                    @{ Name = "Global Component Integrity"; Flag = $GlobalComponentIntegrity },
                    @{ Name = "IPMI/DCMI Over LAN"; Flag = $IPMIDCMIOverLAN },
                    @{ Name = "Last Firmware Scan Result"; Flag = $LastFirmwareScanResult },
                    @{ Name = "Minimum Password Length"; Flag = $MinimumPasswordLength },
                    @{ Name = "Password Complexity"; Flag = $PasswordComplexity },
                    @{ Name = "Require Host Authentication"; Flag = $RequireHostAuthentication },
                    @{ Name = "Require Login for iLO RBSU"; Flag = $RequireLoginforiLORBSU },
                    @{ Name = "Secure Boot"; Flag = $SecureBoot },
                    @{ Name = "Security Override Switch"; Flag = $SecurityOverrideSwitch },
                    @{ Name = "SNMPv1"; Flag = $SNMPv1 }
                )

                foreach ($setting in $settings) {

                    if ($setting.Flag) {
                        $Name = $ServerIloSecurityStatus | Where-Object name -eq $setting.Name | ForEach-Object name
                        $ID = $ServerIloSecurityStatus | Where-Object name -eq $setting.Name | ForEach-Object id

                        if ($Name) {
                            $PayloadSetting = New-Setting $Name $ID
                            [void]$objStatus.ignoreSecuritySettings.add($PayloadSetting)

                            "[{0}] Ignore iLO security risk setting '{1}' enabled for server '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $setting.Name, $SerialNumber | Write-Verbose
                        } 
                        else {

                            Write-Warning "The iLO security risk setting '$($setting.Name)' is not available for server '$SerialNumber'. This setting will be ignored."
                        }
                    }
                }
            }            
        }
       
        # Add tracking object to the list of object status list
        [void]$ObjectStatusList.Add($objStatus)

    }

    end {       

        try {
            if ($Region) {
                $Servers = Get-HPECOMServer -Region $Region
            }
            else {
                Return
            }
        
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }
        
        
        foreach ($Resource in $ObjectStatusList) {

            if ($Resource.state -eq "ERROR") {
                continue
            }
            else {
                
                $Server = $Servers | Where-Object serialNumber -eq $Resource.associatedResource


                if (-not $Server) {
                    $Resource.state = "ERROR"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.Status = "Failed"
                    $Resource.message = "The server with serial number '$($Resource.associatedResource)' cannot be found in the Compute Ops Management instance."
                    
                    if ($WhatIf) {
                        $ErrorMessage = "The server with serial number '$($Resource.associatedResource)' cannot be found in the Compute Ops Management instance."
                        Write-warning $ErrorMessage
                        continue
                    }
                }
                elseif ($Server.connectionType -eq "ONEVIEW") {
                    $Resource.state = "ERROR"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.Status = "Failed"
                    $Resource.message = "The iLO security settings are not supported on this server."
                    
                    if ($WhatIf) {
                        $ErrorMessage = "'{0}': The iLO security settings are not supported for OneView managed servers." -f $Resource.associatedResource
                        Write-warning $ErrorMessage
                        continue
                    }
                }
    
                else {
    
                    # Build payload
                    $data = @{
                        ignoreSecuritySettings = $Resource.ignoreSecuritySettings
                    }
                        
                    # Build payload
                    $payload = @{
                        jobTemplate = $JobTemplateId
                        resourceId   = $Server.id
                        resourceType = "compute-ops-mgmt/server"
                        jobParams = $data
                    }
                    
                    $payload = ConvertTo-Json $payload -Depth 10            
            
        
                    try {
            
                        $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference      
            
                        if (-not $WhatIf -and -not $Async) {    
                                
                            $Timeout = $TimeoutinSecondsPerServer
                            
                            "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose
            
                            $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout 
            
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
        
                            $Resource.state = $_resp.state
                            $Resource.duration = $Duration
                            $Resource.resultCode = $_resp.resultCode
                            $Resource.status = $_resp.Status
                            $Resource.details = $_resp
                            $Resource.jobUri = $_resp.resourceUri
        
                            "[{0}] Resource content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Resource | Write-Verbose
                        
                        }
                    }
                    catch {
            
                        if (-not $WhatIf) {
        
                            $Resource.state = "ERROR"
                            $Resource.duration = '00:00:00'
                            $Resource.resultCode = "FAILURE"
                            $Resource.status = "Failed"
                            $Resource.message = $_.Exception.Message -replace "`r`n", " " -replace "`n", " " -replace "`r", " "
            
                            
                            
                        }
                    }  
                }
            }
        }
        
        if (-not $WhatIf) {

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "COM.Jobs.Status" 
            Return $ObjectStatusList
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
Export-ModuleMember -Function `
    'Wait-HPECOMJobComplete',
    'Get-HPECOMJob',
    'Start-HPECOMserver',
    'Restart-HPECOMserver',
    'Stop-HPECOMserver',
    'Update-HPECOMServerFirmware',
    'Update-HPECOMServeriLOFirmware',
    'Update-HPECOMGroupFirmware',
    'Stop-HPECOMGroupFirmware',
    'Invoke-HPECOMGroupFirmwareComplianceCheck',
    'Get-HPECOMGroupFirmwareCompliance',
    'Invoke-HPECOMServerExternalStorage',
    'Invoke-HPECOMGroupInternalStorageConfiguration',
    'Invoke-HPECOMGroupOSInstallation',
    'Invoke-HPECOMGroupBiosConfiguration',
    'Invoke-HPECOMGroupExternalStorageConfiguration',
    'Invoke-HPECOMGroupiLOConfiguration',
    'Invoke-HPECOMGroupiLOConfigurationCompliance',
    'Get-HPECOMGroupiLOConfigurationCompliance',
    'Invoke-HPECOMGroupExternalStorageComplianceCheck',
    'Update-HPECOMApplianceFirmware',
    'Get-HPECOMIloSecuritySatus',
    'Enable-HPECOMIloIgnoreRiskSetting',
    'Disable-HPECOMIloIgnoreRiskSetting' `
    -Alias *







# SIG # Begin signature block
# MIIungYJKoZIhvcNAQcCoIIujzCCLosCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCDDU+yc3Nd4rGZy
# t7unsaBwF5P22Bh+3r1IZgD6nXFKd6CCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQgXb+NGH+CJ/V+YUchGlG/blzwUzY6EQ9W6qJNpaSTz28wDQYJKoZIhvcNAQEB
# BQAEggIAe1Z9F6l+5FaLFmUF78tJ8j508C++0UplphXpZdrMFFYOkziWk2VwkNhb
# cSCOiivZpbQM8/btXrJLihmTsZwPc+/pJWI0XeFt+P8bEunG75/NSVu26m5wTOxN
# ehfB2XqPBzE+vdvk6S3wyAa4RrHgA28PrIs+8NPxe0gLbUS4w87THikfGNpupMm9
# +KutfjtfZmxfbRFVGsc0TZ4OO5S0RtNvWzMM4SodNq9VzExUWOSfMkn+eiS3okRJ
# 8b74zl0xvQ0TB9jPTU0y0orIjEQPj3o071JFI1lclEMZbGxqH1hrHVVhzSHX9yzp
# MywFm/25Fj30Znq2eTuCjZYHZZUzMK2+OFZtymQp+Z7BrjqRjQnAGwM88sQyd7J+
# U2hE3kJcND/F3SW6ja5pixmVzJ5Rd2O2U8781snH/b5jNgL3Cv1dmB+cKqmPZqWd
# qg2FaFxqKubP9QtLYkTuwrPLeVMQr1p1x6lHg3pkjC9pnDmAQ2UHQFj/sLxArx4e
# JPMkBOysrlPBFMxJfsQW/WGebUgm6x/mhKgftvbelcsweklok3eYjqL+VA590cCn
# TlAW5L7KRpYE7agUyDtDBG7Nf+7WP/8x1sSy5tXIOwiORCvrFTm95elf1fyzwzMV
# VeJ+mH+7tm/YXUjqhLG8Bs5sMs9T5MU8Sfcz5eWH9s6gaIaG1wOhghjoMIIY5AYK
# KwYBBAGCNwMDATGCGNQwghjQBgkqhkiG9w0BBwKgghjBMIIYvQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBBwYLKoZIhvcNAQkQAQSggfcEgfQwgfECAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQwhLqkKuQ46ZXv65nqbRZpTy/fE8Ul2GP0M/wj
# UTJvp6ru5hABzBpOziH00UGz2X6GAhRhqPl+fobWuBuC6BZ97xZcJzRG6hgPMjAy
# NjAxMTkxODE4NDZaoHakdDByMQswCQYDVQQGEwJHQjEXMBUGA1UECBMOV2VzdCBZ
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
# DxcNMjYwMTE5MTgxODQ2WjA/BgkqhkiG9w0BCQQxMgQwedHqOfUKwyggjzIsQ6KF
# tktW7ER8FuTTx8/q/AHzKIdgyGAlVsCNvO90rZv3QVS3MIIBegYLKoZIhvcNAQkQ
# AgwxggFpMIIBZTCCAWEwFgQUOMkUgRBEtNxmPpPUdEuBQYaptbEwgYcEFMauVOR4
# hvF8PVUSSIxpw0p6+cLdMG8wW6RZMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRpbWUgU3Rh
# bXBpbmcgUm9vdCBSNDYCEHojrtpTaZYPkcg+XPTH4z8wgbwEFIU9Yy2TgoJhfNCQ
# NcSR3pLBQtrHMIGjMIGOpIGLMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKTmV3
# IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBVU0VS
# VFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZpY2F0
# aW9uIEF1dGhvcml0eQIQNsKwvXwbOuejs902y8l1aDANBgkqhkiG9w0BAQEFAASC
# AgAQcM+vH6MjUAENSqd1fx1ecBnAgME1FpXwaVUlGJQf4331rn/fsErb763C0IvL
# kqOo+ZKJPlxRgiAWo+tgltdew0rawbUWmTq4ioi/9hIXjnY95IvVaDRLZ2NDkc4P
# rKaCMhg7KAzvJXLKvI8gRFfoqmdh+JO4hWeKrE7OXPRDApEXBI1usrwtEExqa8wa
# FIxcjE2duuEosiRye5vbIVqHNGGfj/TGUxH4tZndXT4aAkT41fhN3PpJiy25p6RA
# CKIuep7WI48l+wy3FXt/LT153TwmlB+dY11ZvJiF3VTVF9TgkRiNaooPemIQJlsn
# RP7ccj4VLLbiCE3zDzeXNtMHogzFEjNXpHso8bemekv2ICmmvT5Y5IB/aBLyEExh
# dPJQI74RbmrhE4L8xhkcDGto5wOIMLIAPOwwp0xxm8EgGtqhWGt4ZT4SfAvAAUXn
# 7/JsKtGiJbtjJbM2GLZzL72p6e2HjKJ/o5OioHrn6N7dHv2jw93kCat2qY3U6kfZ
# m3qeHu4FgxjOw+bUN+Gc0a+co3t5E7X0YNAnL7xChw+FNM5vVE7feJA7PTQKlN8W
# ssUPACR/KoTH5w5Ep8xdN7izTrDK0iWm+F+OEOcOGfU7+QlL8iYWvpPGI5rq+YTn
# fSN6v/DISXar7YV2MFfOx4ERZuErWKFuxGCmKhIY0NHtBQ==
# SIG # End signature block
