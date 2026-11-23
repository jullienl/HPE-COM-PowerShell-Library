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

        The completed job resource object with the following key properties:
        - state: Final state of the job (e.g., "COMPLETE" for success, "ERROR" for failure, "STALLED" for a stalled job)
        - resultCode: Result code of the job (e.g., "SUCCESS", "FAILURE")
        - resourceUri: The resource URI of the job
        - type: The type of job (e.g., "server-power-ops", "firmware-update", etc.)
                
    #>

    [CmdletBinding ()]
    Param(

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
                
                $jobResource = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method GET -WhatIfBoolean $false -Verbose:$VerbosePreference    
                
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

                Write-Progress -Activity "Job has reached terminal state" -Status $jobState -Completed
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
        $_Message = Get-HPECOMActivity -Region $Region -JobResourceUri $jobResource.resourceuri -WarningAction SilentlyContinue | Select-Object -ExpandProperty formattedmessage

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
    Optional parameter that can be used to specify the name of a job to display (e.g., 'IloOnlyFirmwareUpdate', 'ServerPowerOn').

    .PARAMETER SourceName
    Optional parameter that can be used to display jobs associated with a specific resource name.
    Source name can be a server name, server serial number, group name, or appliance name.

    .PARAMETER Category 
    Optional parameter that can be used to display the jobs of a specific category. Auto-completion (Tab key) is supported for this parameter, providing a list of categories.
    
    .PARAMETER ShowRunning
    Optional switch parameter that can be used to display only running jobs.
    
    .PARAMETER ShowPending
    Optional switch parameter that can be used to display only pending jobs.

    .PARAMETER ShowComplete
    Optional switch parameter that can be used to display only completed jobs.

    .PARAMETER ShowApprovalPending
    Optional switch parameter that can be used to display only jobs waiting for approval from one or more configured approvers.

    .PARAMETER ShowError
    Optional switch parameter that can be used to display only jobs that ended with an error.

    .PARAMETER ShowHalted
    Optional switch parameter that can be used to display only jobs that are halted.

    .PARAMETER ShowStalled
    Optional switch parameter that can be used to display only jobs that are stalled.
    
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
    Get-HPECOMJob -Region eu-central -SourceName CZJ11105MV

    Retrieve the last seven days jobs associated with a server specified by its serial number.

    .EXAMPLE
    Get-HPECOMJob -Region eu-central -SourceName "Production-Servers" -ShowLastMonth

    Retrieve the last month jobs associated with a group named 'Production-Servers'.

    .EXAMPLE
    Get-HPECOMJob -Region us-west -ShowComplete

    Return only completed jobs from the last seven days in the western US region.

    .EXAMPLE
    Get-HPECOMJob -Region us-west -ShowApprovalPending

    Return only jobs that are waiting for approval in the western US region.

    .EXAMPLE
    Get-HPECOMJob -Region us-west -ShowError

    Return only jobs that ended with an error in the western US region.

    .EXAMPLE
    Get-HPECOMJob -Region us-west -ShowHalted

    Return only halted jobs in the western US region.

    .EXAMPLE
    Get-HPECOMJob -Region us-west -ShowStalled

    Return only stalled jobs in the western US region.

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

    .OUTPUTS
    HPEGreenLake.COM.Jobs [System.Management.Automation.PSCustomObject]

        Job objects with the following key properties:
        - name: The name of the job (e.g., 'IloOnlyFirmwareUpdate', 'ServerPowerOn')
        - state: The current state of the job - "PENDING" (waiting to start), "RUNNING" (in progress), "STALLED" (stuck), "ERROR" (failed), "COMPLETE" (finished successfully), or "APPROVAL_PENDING" (waiting for approver approval)
        - resultCode: The result code indicating success or failure
        - createdAt: Timestamp when the job was created
        - resourceUri: The URI of the job resource
        - category: The category of the job (e.g., 'Server', 'Group', 'Firmware')
        - associatedResourceId: The ID of the resource associated with the job
        - region: The region code where the job is running

    
   #>
    [CmdletBinding(DefaultParameterSetName = "JobResourceUri")]
    Param( 
    
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

        [Parameter (ParameterSetName = 'ShowPending')]
        [Parameter (ParameterSetName = 'ShowRunning')]
        [Parameter (ParameterSetName = 'ShowComplete')]
        [Parameter (ParameterSetName = 'ShowApprovalPending')]
        [Parameter (ParameterSetName = 'ShowError')]
        [Parameter (ParameterSetName = 'ShowHalted')]
        [Parameter (ParameterSetName = 'ShowStalled')]
        [Parameter (ParameterSetName = 'ShowLastMonth')]
        [Parameter (ParameterSetName = 'ShowLastThreeMonths')]
        [Parameter (ParameterSetName = 'ShowAll')]
        [Parameter (ParameterSetName = 'JobResourceUri')]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Parameter (Mandatory, ParameterSetName = 'SourceName')]
        [ValidateNotNullOrEmpty()]
        [String]$SourceName,
        
        # Pipeline is supported but it requires to change the default parameter set to JobResourceUri but then 
        # it generates an error when -Name and -Category parameters are used alone as the parameter set name cannot then be identified. 
        # So I had to add the parameter set name JobResourceUri to the -Name and -Category parameters to avoid this issue + clear the $Name PS bound parameter if pipeline input
        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = 'JobResourceUri')]
        [Alias('jobUri', 'resourceUri')]
        [ValidateNotNullOrEmpty()]
        [string]$JobResourceUri,

        [Parameter (ParameterSetName = 'ShowPending')]
        [Parameter (ParameterSetName = 'ShowRunning')]
        [Parameter (ParameterSetName = 'ShowComplete')]
        [Parameter (ParameterSetName = 'ShowApprovalPending')]
        [Parameter (ParameterSetName = 'ShowError')]
        [Parameter (ParameterSetName = 'ShowHalted')]
        [Parameter (ParameterSetName = 'ShowStalled')]
        [Parameter (ParameterSetName = 'ShowLastMonth')]
        [Parameter (ParameterSetName = 'ShowLastThreeMonths')]
        [Parameter (ParameterSetName = 'ShowAll')]
        [Parameter (ParameterSetName = 'JobResourceUri')]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $Items = @('Analyze', 'Filter', 'Group', 'Appliance', 'Report', 'Server', 'Server-hardware', 'Setting')
                $filteredItems = $Items | Where-Object { $_ -like "$wordToComplete*" }
                return $filteredItems | ForEach-Object {
                    [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
                }
            })]
        [ValidateSet ('Analyze', 'Filter', 'Group', 'Appliance', 'Report', 'Server', 'Server-hardware', 'Setting')]
        [string]$Category,
        
        [Parameter (ParameterSetName = 'ShowRunning')]
        [Switch]$ShowRunning,
        
        [Parameter (ParameterSetName = 'ShowPending')]
        [Switch]$ShowPending,

        [Parameter (ParameterSetName = 'ShowComplete')]
        [Switch]$ShowComplete,

        [Parameter (ParameterSetName = 'ShowApprovalPending')]
        [Switch]$ShowApprovalPending,

        [Parameter (ParameterSetName = 'ShowError')]
        [Switch]$ShowError,

        [Parameter (ParameterSetName = 'ShowHalted')]
        [Switch]$ShowHalted,

        [Parameter (ParameterSetName = 'ShowStalled')]
        [Switch]$ShowStalled,
        
        [Parameter (ParameterSetName = 'ShowLastMonth')]
        [Parameter (ParameterSetName = 'SourceName')]
        [Switch]$ShowLastMonth,

        [Parameter (ParameterSetName = 'ShowLastThreeMonths')]
        [Parameter (ParameterSetName = 'SourceName')]
        [Switch]$ShowLastThreeMonths,

        [Parameter (ParameterSetName = 'ShowAll')]
        [Parameter (ParameterSetName = 'SourceName')]
        [Switch]$ShowAll,

        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command
  
        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

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

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # If pipeline input with JobResourceUri, then don't take name PS bound parameter into account 
        # as it stores the name of the job and not the displayName of a resource.
        # A separate variable is used: assigning $null to $Name would fail its [ValidateNotNullOrEmpty()] check.
        $_NameFilter = if ($JobResourceUri) { $null } else { $Name }

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
        if ($_NameFilter) {
            # Name parameter is for job name filtering only
            "[{0}] Filtering by job name: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_NameFilter | Write-Verbose
            $Uri = Add-FilterToUri -Uri $Uri -Filter "name eq '$_NameFilter'"
        }
        elseif ($SourceName) {
            # SourceName parameter is for resource name filtering (server, group, appliance)
            # Retrieve associated source name ID by trying different resource types
            try {
                $SourceResource = $null
                $cmdletsToTry = @(
                    'Get-HPECOMServer',
                    'Get-HPECOMGroup', 
                    'Get-HPECOMAppliance'
                )
                
                foreach ($cmdlet in $cmdletsToTry) {
                    $SourceResource = & $cmdlet -Region $Region -Name $SourceName -Verbose:$VerbosePreference -ErrorAction SilentlyContinue | 
                        Select-Object -First 1
                    
                    if ($SourceResource) {
                        $SourceNameID = $SourceResource.id
                        "[{0}] Found {1} resource '{2}' with ID: {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $cmdlet.Replace('Get-HPECOM',''), $SourceName, $SourceNameID | Write-Verbose
                        break
                    }
                }
                
                if (-not $SourceNameID) {
                    "[{0}] No resource found with name '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SourceName | Write-Verbose
                    Return
                }

                # For appliances, prepend the appliance type prefix to match job resource ID format
                if ($SourceResource.applianceType) {
                    switch ($SourceResource.applianceType) {
                        "GATEWAY" { $SourceNameID = "gateway+$SourceNameID" }
                        "SYNERGY" { $SourceNameID = "oneview+$SourceNameID" }
                        "VM" { $SourceNameID = "oneview+$SourceNameID" }
                    }
                }
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }

            # Encode the $SourceNameID as it may contain special characters like + signs
            $EncodedSourceNameID = [System.Web.HttpUtility]::UrlEncode($SourceNameID)

            # For servers, use associatedResourceId
            if ($SourceResource.PSObject.TypeNames -contains 'HPEGreenLake.COM.Servers') {
                $Uri = Add-FilterToUri -Uri $Uri -Filter "resource/id eq '$EncodedSourceNameID'"
            }
            # For other resources (group, appliance), use resource/id
            else {
                $Uri = Add-FilterToUri -Uri $Uri -Filter "contains(resource/id, '$EncodedSourceNameID')"
            }
        }

        if ($ShowRunning) {
            $Uri = Add-FilterToUri -Uri $Uri -Filter "state eq 'running'"
        }
        elseif ($ShowPending) {
            $Uri = Add-FilterToUri -Uri $Uri -Filter "state eq 'pending'"
        }
        elseif ($ShowComplete) {
            $Uri = Add-FilterToUri -Uri $Uri -Filter "state eq 'complete'"
        }
        elseif ($ShowApprovalPending) {
            $Uri = Add-FilterToUri -Uri $Uri -Filter "state eq 'approvalpending'"
        }
        elseif ($ShowError) {
            $Uri = Add-FilterToUri -Uri $Uri -Filter "state eq 'error'"
        }
        elseif ($ShowHalted) {
            $Uri = Add-FilterToUri -Uri $Uri -Filter "state eq 'halted'"
        }
        elseif ($ShowStalled) {
            $Uri = Add-FilterToUri -Uri $Uri -Filter "state eq 'stalled'"
        }

        # Filter 7 days except for the other cases
        if (-not $ShowAll -and -not $JobResourceUri -and -not $ShowRunning -and -not $ShowPending -and -not $ShowComplete -and -not $ShowApprovalPending -and -not $ShowError -and -not $ShowHalted -and -not $ShowStalled -and -not $ShowLastMonth -and -not $ShowLastThreeMonths) {
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
            # No jobs found - provide helpful message (but not during WhatIf and only for default 7-day window)
            if (-not $WhatIf -and -not $ShowAll -and -not $ShowLastMonth -and -not $ShowLastThreeMonths -and -not $ShowRunning -and -not $ShowPending -and -not $ShowComplete -and -not $ShowApprovalPending -and -not $SourceName -and -not $JobResourceUri) {
                Write-Warning "No jobs found in the last 7 days. Try using -ShowLastMonth, -ShowLastThreeMonths, or -ShowAll to see historical jobs."
            }
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

    Note: If an approval policy is active for this server's group, this operation may require approval before the job executes.
          Use 'Get-HPECOMApprovalRequest -State PENDING' to check for pending requests and 'Resolve-HPECOMApprovalRequest' to approve or decline.

    .PARAMETER Region 
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the server is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name 
    Specifies the name or serial number of the server to power on. Accepts server names (hostname/DNS name) or serial numbers.

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
    Start-HPECOMserver -Region us-west -Name CZ12312312
    
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
    Start-HPECOMserver -Region eu-central -Name CZ12312312 -ScheduleTime (Get-Date).AddHours(6)  

    This command schedules a power on operation for the server with the serial number 'CZ12312312' in the `eu-central` region to occur six hours from the current time. 

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name CZ12312312 | Start-HPECOMserver -ScheduleTime (Get-Date).AddDays(2)
  
    This command retrieves the server with the serial number 'CZ12312312' in the `eu-central` region and schedules a power on to occur two days from the current date.
    
    .EXAMPLE
    Start-HPECOMserver -Region eu-central -Name CZ12312312 -ScheduleTime (Get-Date).AddHours(6) -Interval P1W
 
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

    HPEGreenLake.COM.Schedules.Status [System.Management.Automation.PSCustomObject]

        - The schedule job object that includes the schedule details when `-ScheduleTime` is used.

    
   #>

    [CmdletBinding(DefaultParameterSetName = 'SerialNumber')]
    Param( 

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

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SerialNumber')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ScheduleSerialNumber')]
        [Alias('ServerSerialNumber', 'serial', 'serialnumber')]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

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
                description        = "Scheduled task to power on server '$Name'"
                associatedResource = $Name
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
                associatedResource = $Name
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
            $Servers = Get-HPECOMServer -Region $Region
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

         
        foreach ($Resource in $ObjectStatusList) {
            
            $Server = $Servers | Where-Object { $_.name -eq $Resource.associatedResource -or $_.host.hostname -eq $Resource.associatedResource -or $_.hardware.serialNumber -eq $Resource.associatedResource }
              
            if (-not $Server) {

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Server cannot be found in the Compute Ops Management instance!"

                }
                else {

                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Warning"
                    $Resource.message = "Server cannot be found in the Compute Ops Management instance!"
                }
                
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Resource.associatedResource
                    Write-Warning  "$ErrorMessage. Cannot display API request."
                    continue
                }
            } 
            elseif ($Server.hardware.powerState -eq "ON") {

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Server requested power state is already on!"

                }
                else {
                    
                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Warning"
                    $Resource.message = "Server requested power state is already on!"
                }
                
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Requested power state is already on!" -f $Resource.associatedResource
                    Write-Warning  "$ErrorMessage. Cannot display API request."
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
    
                    $ScheduleName = "$($Name)_ServerPowerOn_Schedule_$($randomNumber)"
                    $Resource.name = $ScheduleName 

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
    
                    $payload = @{
                        name                  = $ScheduleName
                        description           = $Description
                        associatedResourceUri = $_serverResourceUri
                        purpose               = "SERVER_POWER_ON"
                        schedule              = $Schedule
                        operation             = $Operation
    
                    }
    
                }
                else {
                    
                    $payload = @{
                        jobTemplate  = $JobTemplateId
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

                        if (-not $WhatIf -and $_resp.state -eq 'APPROVAL_PENDING') {
                            Write-Warning "Server '$($Resource.associatedResource)': Job is pending approval. Use 'Get-HPECOMApprovalRequest -State PENDING' to view pending requests and 'Resolve-HPECOMApprovalRequest' to approve or decline."
                        }
                        elseif (-not $WhatIf -and -not $Async) {    
                             
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
                            
                            $Resource.name = $ScheduleName
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

    Note: If an approval policy is active for this server's group, this operation may require approval before the job executes.
          Use 'Get-HPECOMApprovalRequest -State PENDING' to check for pending requests and 'Resolve-HPECOMApprovalRequest' to approve or decline.
            
    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the server is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name 
    Specifies the name or serial number of the server to restart. Accepts server names (hostname/DNS name) or serial numbers.

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
    Restart-HPECOMserver -Region us-west -Name CZ12312312
    
    This command restarts the server with the serial number 'CZ12312312' and waits for the job to complete then return the job resource object. 

    .EXAMPLE
    Restart-HPECOMserver -Region us-west -Name ESX-2.domain.com

    This command restarts the server with the DNS name 'ESX-2.domain.com' and waits for the job to complete.

    .EXAMPLE
    Restart-HPECOMserver -Region us-west -Name CZ12312312 -Async 

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
    Restart-HPECOMserver -Region eu-central -Name CZ12312312 -ScheduleTime (Get-Date).AddHours(6)  

    This command schedules a restart operation for the server with the serial number 'CZ12312312' in the `eu-central` region to occur six hours from the current time. 

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name CZ12312312 | Restart-HPECOMserver -ScheduleTime (Get-Date).AddDays(2)
  
    This command retrieves the server with the serial number 'CZ12312312' in the `eu-central` region and schedules a restart to occur two days from the current date.

    .EXAMPLE
    Restart-HPECOMserver -Region eu-central -Name CZ12312312 -ScheduleTime (Get-Date).AddHours(6) -Interval P1W
 
    Schedules a weekly restart operation for the server with serial number 'CZ12312312' in the `eu-central` region. The first execution will occur six hours from the current time.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers or DNS names.

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

    [CmdletBinding(DefaultParameterSetName = 'SerialNumber')]
    Param( 

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

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SerialNumber')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ScheduleSerialNumber')]
        [Alias('ServerSerialNumber', 'serial', 'serialnumber')]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

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
                description        = "Scheduled task to restart server '$Name'"
                associatedResource = $Name
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
                associatedResource = $Name
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
            $Servers = Get-HPECOMServer -Region $Region
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

         
        foreach ($Resource in $ObjectStatusList) {
            
            $Server = $Servers | Where-Object { $_.name -eq $Resource.associatedResource -or $_.host.hostname -eq $Resource.associatedResource -or $_.hardware.serialNumber -eq $Resource.associatedResource }
              
            if (-not $Server) {

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Server cannot be found in the Compute Ops Management instance!"

                }
                else {

                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Warning"
                    $Resource.message = "Server cannot be found in the Compute Ops Management instance!"
                }
                
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Resource.associatedResource
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }
            } 
            elseif ($Server.hardware.powerState -eq "OFF") {

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Server power state must be ON to be restarted."

                }
                else {
                    
                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Warning"
                    $Resource.message = "Server power state must be ON to be restarted."
                }
                
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Power state must be ON to be restarted." -f $Resource.associatedResource
                    Write-Warning "$ErrorMessage Cannot display API request."
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
    
                    $ScheduleName = "$($Resource.associatedResource)_ServerRestart_Schedule_$($randomNumber)"
                    $Resource.name = $ScheduleName 

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
    
                    $payload = @{
                        name                  = $ScheduleName
                        description           = $Description
                        associatedResourceUri = $_serverResourceUri
                        purpose               = "SERVER_RESTART"
                        schedule              = $Schedule
                        operation             = $Operation
    
                    }
    
                }
                else {
                    
                    $payload = @{
                        jobTemplate  = $JobTemplateId
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

                        if (-not $WhatIf -and $_resp.state -eq 'APPROVAL_PENDING') {
                            Write-Warning "Server '$($Resource.associatedResource)': Job is pending approval. Use 'Get-HPECOMApprovalRequest -State PENDING' to view pending requests and 'Resolve-HPECOMApprovalRequest' to approve or decline."
                        }
                        elseif (-not $WhatIf -and -not $Async) {    
                             
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

                            $Resource.name = $ScheduleName
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

    Note: If an approval policy is active for this server's group, this operation may require approval before the job executes.
          Use 'Get-HPECOMApprovalRequest -State PENDING' to check for pending requests and 'Resolve-HPECOMApprovalRequest' to approve or decline.
            
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

    HPEGreenLake.COM.Schedules.Status [System.Management.Automation.PSCustomObject]

        - The schedule job object that includes the schedule details when `-ScheduleTime` is used.

    
   #>

    [CmdletBinding(DefaultParameterSetName = 'SerialNumber')]
    Param( 

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

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SerialNumber')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ScheduleSerialNumber')]
        [Alias('ServerSerialNumber', 'serial', 'serialnumber')]
        [ValidateNotNullOrEmpty()]
        [String]$Name,
        
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
                description        = "Scheduled task to power off server '$Name'"
                associatedResource = $Name
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
                associatedResource = $Name
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
            $Servers = Get-HPECOMServer -Region $Region
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

         
        foreach ($Resource in $ObjectStatusList) {
            
            $Server = $Servers | Where-Object { $_.name -eq $Resource.associatedResource -or $_.host.hostname -eq $Resource.associatedResource -or $_.hardware.serialNumber -eq $Resource.associatedResource }
              
            if (-not $Server) {

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Server cannot be found in the Compute Ops Management instance!"

                }
                else {

                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Warning"
                    $Resource.message = "Server cannot be found in the Compute Ops Management instance!"
                }
                
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Resource.associatedResource
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }
            } 
            elseif ($Server.hardware.powerState -eq "OFF") {

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Server requested power state is already off!"

                }
                else {
                    
                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Warning"
                    $Resource.message = "Server requested power state is already off!"
                }
                
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Requested power state is already off." -f $Resource.associatedResource
                    Write-Warning "$ErrorMessage Cannot display API request."
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
    
                    $ScheduleName = "$($Resource.associatedResource)_ServerPowerOff_Schedule_$($randomNumber)"
                    $Resource.name = $ScheduleName 

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
    
                    $payload = @{
                        name                  = $ScheduleName
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

                        if (-not $WhatIf -and $_resp.state -eq 'APPROVAL_PENDING') {
                            Write-Warning "Server '$($Resource.associatedResource)': Job is pending approval. Use 'Get-HPECOMApprovalRequest -State PENDING' to view pending requests and 'Resolve-HPECOMApprovalRequest' to approve or decline."
                        }
                        elseif (-not $WhatIf -and -not $Async) {    
                             
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

                            $Resource.name = $ScheduleName
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

    Note: If an approval policy is active for this server's group, this operation may require approval before the job executes.
          Use 'Get-HPECOMApprovalRequest -State PENDING' to check for pending requests and 'Resolve-HPECOMApprovalRequest' to approve or decline.

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

    HPEGreenLake.COM.Schedules.Status [System.Management.Automation.PSCustomObject]

        - The schedule job object that includes the schedule details when `-ScheduleTime` is used.

    #>

    [CmdletBinding(DefaultParameterSetName = 'SerialNumber')]
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
        
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SerialNumber')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ScheduleSerialNumber')]
        [Alias('ServerSerialNumber', 'serial', 'serialnumber')]
        [ValidateNotNullOrEmpty()]
        [String]$Name,
        
        [Parameter (Mandatory)]
        [Alias('FirmwareBundleReleaseVersion')]
        [ValidateNotNullOrEmpty()]
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
                associatedResource = $Name
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

                associatedResource = $Name
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

            $ErrorMessage = "Firmware baseline release version '{0}' cannot be found in the Compute Ops Management instance!" -f $FirmwareBaselineReleaseVersion
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
            
            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            
            foreach ($Resource in $ObjectStatusList) {
                $Resource.resultCode = "FAILURE"
                $Resource.message = $ErrorMessage
                if (-not $ScheduleTime) {
                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.status = "Warning"
                }
            }
            
            if ($ScheduleTime) {
                $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "COM.Schedules.Status"
            }
            else {
                $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "COM.Jobs.Status"
            }
            Return $ObjectStatusList
            
        }


        try {
            $Servers = Get-HPECOMServer -Region $Region
        
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        # Fetch all running jobs once to detect in-progress firmware updates
        $_AllRunningJobs = @()
        try {
            $_AllRunningJobs = @(Get-HPECOMJob -Region $Region -ShowRunning -Verbose:$false -ErrorAction SilentlyContinue)
        }
        catch {
            "[{0}] Warning: Unable to query running jobs — in-progress check will be skipped. Error: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
        }

           
        foreach ($Resource in $ObjectStatusList) {
            
            $Server = $Servers | Where-Object { $_.name -eq $Resource.associatedResource -or $_.host.hostname -eq $Resource.associatedResource -or $_.hardware.serialNumber -eq $Resource.associatedResource }

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
                    
                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.Status = "Warning"
                    $Resource.message = "Server cannot be found in the Compute Ops Management instance!"
                    
                }
                 
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Resource.associatedResource
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }
            } 
            elseif ($Server.serverGeneration -eq "UNKNOWN") {

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Unable to retrieve server hardware information. Please check the iLO event logs for further details."

                }
                else {
                    
                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.Status = "Warning"
                    $Resource.message = "Unable to retrieve server hardware information. Please check the iLO event logs for further details."
                    
                }
                 
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Unable to retrieve hardware information. Please check the iLO event logs for further details." -f $Resource.associatedResource
                    Write-Warning "$ErrorMessage Cannot display API request."
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

                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.Status = "Warning"
                    $Resource.message = "Operation not supported on OneView managed servers!"
                }
                
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Operation not supported on OneView managed servers!" -f $Resource.associatedResource
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }
            }
            else {       
        
                $_serverResourceUri = $Server.resourceUri

                # Skip if a firmware update job is already running for this server
                if ($_AllRunningJobs) {
                    $_existingRunningJob = $_AllRunningJobs | Where-Object {
                        $_.name -eq $_JobTemplateName -and $_.resource.id -eq $Server.id
                    } | Select-Object -First 1
                    if ($_existingRunningJob) {
                        $_msg = "Server '{0}' already has a running firmware update job ('{1}'). Skipping to avoid conflict." -f $Resource.associatedResource, $_existingRunningJob.resourceUri
                        "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_msg | Write-Verbose
                        if ($WhatIf) {
                            Write-Warning "$_msg Cannot display API request."
                        }
                        else {
                            $Resource.state = "WARNING"
                            $Resource.duration = '00:00:00'
                            $Resource.resultCode = "SKIPPED"
                            $Resource.Status = "Warning"
                            $Resource.message = $_msg
                        }
                        continue
                    }
                }

                try {
                    $Bundle = $Bundles | Where-Object { $_.bundleGeneration -match $_serverGeneration }
                    $BundleID = $Bundle.id
                    
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                    
                }
    
                if (-not $BundleID) {

                    if ($ScheduleTime) {

                        $Resource.resultCode = "FAILURE"
                        $Resource.message = "Firmware baseline release version '{0}' cannot be found in the Compute Ops Management instance!" -f $FirmwareBaselineReleaseVersion

                    }
                    else {

                        $Resource.state = "WARNING"
                        $Resource.duration = '00:00:00'
                        $Resource.resultCode = "FAILURE"
                        $Resource.Status = "Warning"
                        $Resource.message = "Firmware baseline release version '{0}' cannot be found in the Compute Ops Management instance!" -f $FirmwareBaselineReleaseVersion
                    }

                    if ($WhatIf) {
                        $ErrorMessage = "Firmware baseline release version '{0}' cannot be found in the Compute Ops Management instance!" -f $FirmwareBaselineReleaseVersion
                        Write-Warning "$ErrorMessage Cannot display API request."
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
    
                        $ScheduleName = "$($Resource.associatedResource)_ServerFirmwareUpdate_Schedule_$($randomNumber)"
                        $Description = "Scheduled task to update firmware for '$($Resource.associatedResource)' server"
        
    
                        $Schedule = @{
                            startAt = $ScheduleTime.ToString("o")  # Convert to ISO 8601 format as $ScheduleTime alone is convert by PS5.1 to '/Date(...)\/ notation'
                            # interval = $Null
                        }
        
    
                        $payload = @{
                            name                  = $ScheduleName
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
    
                            if (-not $WhatIf -and $_resp.state -eq 'APPROVAL_PENDING') {
                                Write-Warning "Server '$($Resource.associatedResource)': Job is pending approval. Use 'Get-HPECOMApprovalRequest -State PENDING' to view pending requests and 'Resolve-HPECOMApprovalRequest' to approve or decline."
                            }
                            elseif (-not $WhatIf -and -not $Async) {    
                                 
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

                                $Resource.name = $ScheduleName
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

    Note: If an approval policy is active for this server's group, this operation may require approval before the job executes.
          Use 'Get-HPECOMApprovalRequest -State PENDING' to check for pending requests and 'Resolve-HPECOMApprovalRequest' to approve or decline.
    
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

    HPEGreenLake.COM.Schedules.Status [System.Management.Automation.PSCustomObject]

        - The schedule job object that includes the schedule details when `-ScheduleTime` is used.

    #>

    [CmdletBinding(DefaultParameterSetName = 'Scheduled')]
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
        
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)] 
        [Alias('ServerSerialNumber', 'serial', 'serialnumber')]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

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
                associatedResource = $Name
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

                associatedResource = $Name
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
            $Servers = Get-HPECOMServer -Region $Region
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        # Fetch all running jobs once to detect in-progress iLO firmware updates
        $_AllRunningJobs = @()
        try {
            $_AllRunningJobs = @(Get-HPECOMJob -Region $Region -ShowRunning -Verbose:$false -ErrorAction SilentlyContinue)
        }
        catch {
            "[{0}] Warning: Unable to query running jobs — in-progress check will be skipped. Error: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
        }



        foreach ($Resource in $ObjectStatusList) {
            
            $Server = $Servers | Where-Object { $_.name -eq $Resource.associatedResource -or $_.host.hostname -eq $Resource.associatedResource -or $_.hardware.serialNumber -eq $Resource.associatedResource }

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
                    
                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Warning"
                    $Resource.message = "Server cannot be found in the Compute Ops Management instance!"
                    
                }
                 
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Resource.associatedResource
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }
            } 
            elseif ($Server.serverGeneration -eq "UNKNOWN") {

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Unable to retrieve server hardware information. Please check the iLO event logs for further details."

                }
                else {
                    
                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Warning"
                    $Resource.message = "Unable to retrieve server hardware information. Please check the iLO event logs for further details."
                    
                }
                 
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Unable to retrieve hardware information. Please check the iLO event logs for further details." -f $Resource.associatedResource
                    Write-Warning "$ErrorMessage Cannot display API request."
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

                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Warning"
                    $Resource.message = "Operation not supported on OneView managed servers!"
                }
                
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Operation not supported on OneView managed servers!" -f $Resource.associatedResource
                    Write-Warning "$ErrorMessage Cannot display API request."
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

                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Warning"
                    $Resource.message = "Operation not supported because auto iLO firmware update is enabled. To proceed, disable auto iLO firmware update using 'Disable-HPECOMServerAutoiLOFirmwareUpdate'."
                }
                
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Operation not supported because auto iLO firmware update is enabled. To proceed, disable auto iLO firmware update using 'Disable-HPECOMServerAutoiLOFirmwareUpdate'." -f $Resource.associatedResource
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }
            }
            else {    

                $_serverResourceUri = $Server.resourceUri

                # Skip if an iLO firmware update job is already running for this server
                if ($_AllRunningJobs) {
                    $_existingRunningJob = $_AllRunningJobs | Where-Object {
                        $_.name -eq $_JobTemplateName -and $_.resource.id -eq $Server.id
                    } | Select-Object -First 1
                    if ($_existingRunningJob) {
                        $_msg = "Server '{0}' already has a running iLO firmware update job ('{1}'). Skipping to avoid conflict." -f $Resource.associatedResource, $_existingRunningJob.resourceUri
                        "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_msg | Write-Verbose
                        if ($WhatIf) {
                            Write-Warning "$_msg Cannot display API request."
                        }
                        else {
                            $Resource.state = "WARNING"
                            $Resource.duration = '00:00:00'
                            $Resource.resultCode = "SKIPPED"
                            $Resource.status = "Warning"
                            $Resource.message = $_msg
                        }
                        continue
                    }
                }

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
    
                    $ScheduleName = "$($Resource.associatedResource)_ServeriLOFirmwareUpdate_Schedule_$($randomNumber)"
                    $Description = "Scheduled task to update iLO firmware for '$($Resource.associatedResource)' server"
    
    
                    $Schedule = @{
                        startAt = $ScheduleTime.ToString("o")  # Convert to ISO 8601 format as $ScheduleTime alone is convert by PS5.1 to '/Date(...)\/ notation'
                        # interval = $Null
                    }
    
    
                    $payload = @{
                        name                  = $ScheduleName
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

                        if (-not $WhatIf -and $_resp.state -eq 'APPROVAL_PENDING') {
                            Write-Warning "Server '$($Resource.associatedResource)': Job is pending approval. Use 'Get-HPECOMApprovalRequest -State PENDING' to view pending requests and 'Resolve-HPECOMApprovalRequest' to approve or decline."
                        }
                        elseif (-not $WhatIf -and -not $Async) {    
                             
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

                            $Resource.name = $ScheduleName
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

function Invoke-HPECOMServerFirmwareDownload {
    <#
    .SYNOPSIS
    Initiates a firmware download on one or more servers.

    .DESCRIPTION
    This cmdlet initiates a server firmware download. The firmware is downloaded and stored in the iLO repository on
    the selected server. Firmware downloads can be performed in the background without interrupting server operations.
    On networks with slow connections, this feature decreases firmware update job duration by pre-staging firmware
    components in the iLO Repository before a firmware update job is started.

    During the download process, the server inventory is analyzed and the required components are downloaded.
    When you later initiate a firmware update on an individual server, you can select the already-downloaded baseline.

    Note: When HPE drivers and software are included, the affected servers must be powered on and must meet the AMS
          and iSUT prerequisites. Servers that do not meet those requirements are automatically dropped by COM.

    Note: If an approval policy is active for this server's group, this operation may require approval before the job executes.
          Use 'Get-HPECOMApprovalRequest -State PENDING' to check for pending requests and 'Resolve-HPECOMApprovalRequest' to approve or decline.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the server is located.
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name
    Specifies the name, serial number, or hostname of the server on which the firmware download will be performed.

    .PARAMETER FirmwareBaselineReleaseVersion
    Specifies the firmware baseline release version to download. This release version can be found using 'Get-HPECOMFirmwareBaseline'.
    If not specified, the configured server group baseline is used (if applicable).

    .PARAMETER InstallHPEDriversAndSoftware
    When specified, includes HPE driver and software components in the download.
    The server must be powered on and meet the AMS and iSUT prerequisites.

    .PARAMETER AllowFirmwareDowngrade
    When enabled, components that are older than the installed version are also downloaded to match the baseline exactly.
    When disabled (default), only components newer than the installed version are downloaded.

    .PARAMETER TestConnectionRequirements
    When specified, verifies that the server meets the connectivity requirements before initiating the download.
    Servers that do not meet the requirements are automatically dropped.

    .PARAMETER ScheduleTime
    Specifies the date and time when the firmware download should be executed.
    This parameter accepts a DateTime object or a string representation of a date and time.
    If not specified, the firmware download is executed immediately.

    Examples for setting the date and time using `Get-Date`:
    - (Get-Date).AddMonths(6)
    - (Get-Date).AddDays(15)
    - (Get-Date).AddHours(3)
    Example for using a specific date string:
    - "2024-05-20 08:00:00"

    .PARAMETER Interval
    Specifies the interval for a recurring scheduled download using ISO 8601 duration format.
    Must be at least 15 minutes and no more than 1 year.

    Examples:
    - 'P1D'  for daily
    - 'P1W'  for weekly
    - 'P1M'  for monthly
    - 'P1Y'  for yearly
    - 'PT1H' for hourly

    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties).
    By default, the cmdlet waits for the job to complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Invoke-HPECOMServerFirmwareDownload -Region eu-central -Name CZ2311004G -FirmwareBaselineReleaseVersion "2024.11.00.01"

    This command downloads firmware baseline '2024.11.00.01' to the iLO repository of server 'CZ2311004G' in the 'eu-central' region.

    .EXAMPLE
    Invoke-HPECOMServerFirmwareDownload -Region eu-central -Name CZ2311004G -FirmwareBaselineReleaseVersion "2024.11.00.01" -InstallHPEDriversAndSoftware -AllowFirmwareDowngrade

    This command downloads firmware baseline '2024.11.00.01' to server 'CZ2311004G', including HPE driver and
    software components and allowing components older than the installed version to be downloaded.

    .EXAMPLE
    Invoke-HPECOMServerFirmwareDownload -Region eu-central -Name CZ2311004G -FirmwareBaselineReleaseVersion "2024.11.00.01" -TestConnectionRequirements

    This command downloads firmware baseline '2024.11.00.01' to server 'CZ2311004G', first verifying that the server
    meets connectivity requirements.

    .EXAMPLE
    "CZ2311004G", "DZ12312312" | Invoke-HPECOMServerFirmwareDownload -Region eu-central -FirmwareBaselineReleaseVersion "2024.11.00.01" -Async

    This command initiates firmware downloads on two servers and returns the job resources immediately for monitoring.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Model "ProLiant DL360 Gen10 Plus" | Invoke-HPECOMServerFirmwareDownload -FirmwareBaselineReleaseVersion "2024.11.00.01"

    This command retrieves all DL360 Gen10 Plus servers in the 'eu-central' region and downloads the specified
    firmware baseline to each one.

    .EXAMPLE
    Invoke-HPECOMServerFirmwareDownload -Region eu-central -Name CZ2311004G -ScheduleTime (Get-Date).AddHours(6)

    This command schedules a firmware download for server 'CZ2311004G' to occur six hours from now, using the
    server group's configured baseline.

    .EXAMPLE
    Invoke-HPECOMServerFirmwareDownload -Region eu-central -Name CZ2311004G -FirmwareBaselineReleaseVersion "2024.11.00.01" -ScheduleTime (Get-Date).AddDays(1) -Interval P1W

    This command creates a recurring weekly firmware download schedule for server 'CZ2311004G', starting one day
    from now.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's names or serial numbers.

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

        - If the `-Async` switch is used, the cmdlet returns the job resource immediately, allowing you to monitor
          its progress using the `state` and `resultCode` properties, or by passing the job object to
          `Wait-HPECOMJobComplete` for blocking/waiting behavior.

    HPEGreenLake.COM.Schedules.Status [System.Management.Automation.PSCustomObject]

        - The schedule job object that includes the schedule details when `-ScheduleTime` is used.

    #>

    [CmdletBinding(DefaultParameterSetName = 'SerialNumber')]
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

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SerialNumber')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ScheduleSerialNumber')]
        [Alias('ServerSerialNumber', 'serial', 'serialnumber')]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [ValidateNotNullOrEmpty()]
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

        [switch]$InstallHPEDriversAndSoftware,

        [switch]$AllowFirmwareDowngrade,

        [switch]$TestConnectionRequirements,

        [Parameter (ParameterSetName = 'SerialNumber')]
        [switch]$Async,

        [switch]$WhatIf
    )

    Begin {

        [int]$TimeoutinSecondsPerServer = 3600 # Timeout 1 hour per server

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $_JobTemplateName = 'FirmwareDownload'

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
                associatedResource = $Name
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

                associatedResource = $Name
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

        # Resolve firmware baseline if a release version was specified
        $Bundles = $null
        if ($FirmwareBaselineReleaseVersion) {

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

                $ErrorMessage = "Firmware baseline release version '{0}' cannot be found in the Compute Ops Management instance!" -f $FirmwareBaselineReleaseVersion
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
                    return
                }

                foreach ($Resource in $ObjectStatusList) {
                    $Resource.resultCode = "FAILURE"
                    $Resource.message = $ErrorMessage
                    if (-not $ScheduleTime) {
                        $Resource.state = "WARNING"
                        $Resource.duration = '00:00:00'
                        $Resource.status = "Warning"
                    }
                }

                if ($ScheduleTime) {
                    $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "COM.Schedules.Status"
                }
                else {
                    $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "COM.Jobs.Status"
                }
                Return $ObjectStatusList

            }
        }

        try {
            $Servers = Get-HPECOMServer -Region $Region
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        # Fetch all running jobs once to detect in-progress firmware downloads
        $_AllRunningJobs = @()
        try {
            $_AllRunningJobs = @(Get-HPECOMJob -Region $Region -ShowRunning -Verbose:$false -ErrorAction SilentlyContinue)
        }
        catch {
            "[{0}] Warning: Unable to query running jobs — in-progress check will be skipped. Error: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
        }

        foreach ($Resource in $ObjectStatusList) {

            $Server = $Servers | Where-Object { $_.name -eq $Resource.associatedResource -or $_.host.hostname -eq $Resource.associatedResource -or $_.hardware.serialNumber -eq $Resource.associatedResource }

            "[{0}] Server {1} - Found: `n{2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Resource.associatedResource, $Server | Write-Verbose

            if (-not $Server) {

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Server cannot be found in the Compute Ops Management instance!"

                }
                else {

                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.Status = "Warning"
                    $Resource.message = "Server cannot be found in the Compute Ops Management instance!"

                }

                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Resource.associatedResource
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }

            }
            elseif ($Server.connectionType -eq "ONEVIEW") {

                # Not supported on OneView managed servers!

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = "Operation not supported on OneView managed servers!"

                }
                else {

                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.Status = "Warning"
                    $Resource.message = "Operation not supported on OneView managed servers!"
                }

                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Operation not supported on OneView managed servers!" -f $Resource.associatedResource
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }
            }
            else {

                $_serverResourceUri = $Server.resourceUri

                # Skip if a firmware download job is already running for this server
                if ($_AllRunningJobs) {
                    $_existingRunningJob = $_AllRunningJobs | Where-Object {
                        $_.name -eq $_JobTemplateName -and $_.resource.id -eq $Server.id
                    } | Select-Object -First 1
                    if ($_existingRunningJob) {
                        $_msg = "Server '{0}' already has a running firmware download job ('{1}'). Skipping to avoid conflict." -f $Resource.associatedResource, $_existingRunningJob.resourceUri
                        "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_msg | Write-Verbose
                        if ($WhatIf) {
                            Write-Warning "$_msg Cannot display API request."
                        }
                        else {
                            $Resource.state = "WARNING"
                            $Resource.duration = '00:00:00'
                            $Resource.resultCode = "SKIPPED"
                            $Resource.Status = "Warning"
                            $Resource.message = $_msg
                        }
                        continue
                    }
                }

                # Resolve bundle ID for this server's generation (only when a baseline was specified)
                $BundleID = $null
                $BundleResolutionFailed = $false

                if ($Bundles) {

                    if ($Server.serverGeneration -eq "UNKNOWN") {

                        "[{0}] Server {1} - Unable to retrieve server hardware information. Please check the iLO event logs for further details." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Resource.associatedResource | Write-Verbose

                        if ($ScheduleTime) {
                            $Resource.resultCode = "FAILURE"
                            $Resource.message = "Unable to retrieve server hardware information. Please check the iLO event logs for further details."
                        }
                        else {
                            $Resource.state = "WARNING"
                            $Resource.duration = '00:00:00'
                            $Resource.resultCode = "FAILURE"
                            $Resource.Status = "Warning"
                            $Resource.message = "Unable to retrieve server hardware information. Please check the iLO event logs for further details."
                        }

                        if ($WhatIf) {
                            $ErrorMessage = "Server '{0}': Unable to retrieve hardware information. Please check the iLO event logs for further details." -f $Resource.associatedResource
                            Write-Warning "$ErrorMessage Cannot display API request."
                            continue
                        }

                        $BundleResolutionFailed = $true

                    }
                    else {

                        [int]$_serverGeneration = $Server.serverGeneration -replace "GEN_", ""
                        "[{0}] Server {1} - Generation: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Resource.associatedResource, $_serverGeneration | Write-Verbose

                        try {
                            $Bundle = $Bundles | Where-Object { $_.bundleGeneration -match $_serverGeneration }
                            $BundleID = $Bundle.id
                        }
                        catch {
                            $PSCmdlet.ThrowTerminatingError($_)
                        }

                        if (-not $BundleID) {

                            if ($ScheduleTime) {
                                $Resource.resultCode = "FAILURE"
                                $Resource.message = "Firmware baseline release version '{0}' cannot be found in the Compute Ops Management instance!" -f $FirmwareBaselineReleaseVersion
                            }
                            else {
                                $Resource.state = "WARNING"
                                $Resource.duration = '00:00:00'
                                $Resource.resultCode = "FAILURE"
                                $Resource.Status = "Warning"
                                $Resource.message = "Firmware baseline release version '{0}' cannot be found in the Compute Ops Management instance!" -f $FirmwareBaselineReleaseVersion
                            }

                            if ($WhatIf) {
                                $ErrorMessage = "Firmware baseline release version '{0}' cannot be found in the Compute Ops Management instance!" -f $FirmwareBaselineReleaseVersion
                                Write-Warning "$ErrorMessage Cannot display API request."
                                continue
                            }

                            $BundleResolutionFailed = $true

                        }
                    }
                }

                if (-not $BundleResolutionFailed) {

                    $data = @{
                        install_sw_drivers = [bool]$InstallHPEDriversAndSoftware
                        downgrade          = [bool]$AllowFirmwareDowngrade
                        test_connection    = [bool]$TestConnectionRequirements
                    }

                    if ($BundleID) {
                        $data['bundle_id'] = $BundleID
                    }

                    if ($ScheduleTime) {

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

                        $ScheduleName = "$($Resource.associatedResource)_ServerFirmwareDownload_Schedule_$($randomNumber)"
                        $Description = "Scheduled task to download firmware for '$($Resource.associatedResource)' server"

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

                        $payload = @{
                            name                  = $ScheduleName
                            description           = $Description
                            associatedResourceUri = $_serverResourceUri
                            purpose               = "SERVER_FW_DOWNLOAD"
                            schedule              = $Schedule
                            operation             = $Operation
                        }

                    }
                    else {

                        $payload = @{
                            jobTemplate  = $JobTemplateId
                            resourceId   = $Server.id
                            resourceType = "compute-ops-mgmt/server"
                            jobParams    = $data
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
                                $Resource.message = "The schedule to download server firmware has been successfully created."

                            }

                        }
                        else {

                            if (-not $WhatIf -and $_resp.state -eq 'APPROVAL_PENDING') {
                                Write-Warning "Server '$($Resource.associatedResource)': Job is pending approval. Use 'Get-HPECOMApprovalRequest -State PENDING' to view pending requests and 'Resolve-HPECOMApprovalRequest' to approve or decline."
                            }
                            elseif (-not $WhatIf -and -not $Async) {

                                "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $TimeoutinSecondsPerServer | Write-Verbose

                                $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $TimeoutinSecondsPerServer

                                "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

                            }

                            if (-not $WhatIf) {

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

                                $Resource.name = $ScheduleName
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

function Invoke-HPECOMGroupServerFirmwareDownload {
    <#
    .SYNOPSIS
    Initiates a firmware download on all or selected servers in a group.

    .DESCRIPTION
    This cmdlet initiates a firmware download job on one or more servers belonging to a server group. 
    The firmware is downloaded and stored in the iLO repository on each selected server. Firmware downloads 
    can be performed in the background without interrupting server operations.

    On networks with slow connections, this feature decreases firmware update job duration by pre-staging firmware
    components in the iLO Repository before a firmware update job is started. When you later initiate a firmware
    update on individual servers, they can use the already-downloaded baseline.

    The configured firmware baseline for the server group is used. To specify a baseline per individual server,
    use 'Invoke-HPECOMServerFirmwareDownload'.

    Note: When HPE drivers and software are included, the affected servers must be powered on and must meet the AMS
          and iSUT prerequisites. Servers that do not meet those requirements are automatically dropped by COM.

    Note: If an approval policy is active for this group, this operation may require approval before the job executes.
          Use 'Get-HPECOMApprovalRequest -State PENDING' to check for pending requests and 'Resolve-HPECOMApprovalRequest' to approve or decline.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the group is located.
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER GroupName
    Name of the group on which the firmware download will be performed.

    .PARAMETER ServerName
    (Optional) Specifies the name, serial number, or hostname of a server in the group on which the firmware download will be performed.

    If not specified, the firmware download will be performed on all servers in the group.

    .PARAMETER InstallHPEDriversAndSoftware
    When specified, includes HPE driver and software components in the download.
    The server must be powered on and meet the AMS and iSUT prerequisites.

    .PARAMETER AllowFirmwareDowngrade
    When enabled, components that are older than the installed version are also downloaded to match the baseline exactly.
    When disabled (default), only components newer than the installed version are downloaded.

    .PARAMETER TestConnectionRequirements
    When specified, verifies that each server meets the connectivity requirements before initiating the download.
    Servers that do not meet the requirements are automatically dropped.

    .PARAMETER ScheduleTime
    Specifies the date and time when the firmware download should be executed.
    This parameter accepts a DateTime object or a string representation of a date and time.
    If not specified, the firmware download is executed immediately.

    Examples for setting the date and time using `Get-Date`:
    - (Get-Date).AddMonths(6)
    - (Get-Date).AddDays(15)
    - (Get-Date).AddHours(3)
    Example for using a specific date string:
    - "2024-05-20 08:00:00"

    .PARAMETER Interval
    Specifies the interval for a recurring scheduled download using ISO 8601 duration format.
    Must be at least 15 minutes and no more than 1 year.

    Examples:
    - 'P1D'  for daily
    - 'P1W'  for weekly
    - 'P1M'  for monthly
    - 'P1Y'  for yearly
    - 'PT1H' for hourly

    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties).
    By default, the cmdlet waits for the job to complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Invoke-HPECOMGroupServerFirmwareDownload -Region eu-central -GroupName ESXi_group

    This command downloads firmware to the iLO repository of all servers in the group 'ESXi_group' in the 'eu-central' region,
    using the group's configured firmware baseline.

    .EXAMPLE
    Invoke-HPECOMGroupServerFirmwareDownload -Region eu-central -GroupName ESXi_group -InstallHPEDriversAndSoftware -AllowFirmwareDowngrade

    This command downloads firmware for all servers in the group 'ESXi_group', including HPE driver and software components,
    and allows components older than the installed version to be downloaded.

    .EXAMPLE
    Invoke-HPECOMGroupServerFirmwareDownload -Region eu-central -GroupName ESXi_group -ServerName CZ2311004H -TestConnectionRequirements

    This command downloads firmware for server 'CZ2311004H' in group 'ESXi_group', first verifying that the server
    meets connectivity requirements.

    .EXAMPLE
    Invoke-HPECOMGroupServerFirmwareDownload -Region eu-central -GroupName ESXi_group -Async

    This command initiates a firmware download for all servers in group 'ESXi_group' and returns the job resource immediately for monitoring.

    .EXAMPLE
    $task = Invoke-HPECOMGroupServerFirmwareDownload -Region eu-central -GroupName ESXi_group -Async
    $task | Wait-HPECOMJobComplete

    This command initiates a firmware download for all servers in group 'ESXi_group' and waits for the job to complete.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -Name ESXi_group | Invoke-HPECOMGroupServerFirmwareDownload

    This command retrieves the group 'ESXi_group' in the 'eu-central' region and downloads firmware for all its servers.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central | Invoke-HPECOMGroupServerFirmwareDownload -Async

    This command downloads firmware for all servers in every group in the 'eu-central' region and returns each job immediately.

    .EXAMPLE
    "CZ2311004H", "DZ12312312" | Invoke-HPECOMGroupServerFirmwareDownload -Region eu-central -GroupName ESXi_group

    This command downloads firmware for the two specified servers in group 'ESXi_group'.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -Name ESXi_group -ShowMembers | Select-Object -First 2 | Invoke-HPECOMGroupServerFirmwareDownload -GroupName ESXi_group

    This command retrieves the first two server members of group 'ESXi_group' and downloads firmware for them.

    .EXAMPLE
    Invoke-HPECOMGroupServerFirmwareDownload -Region eu-central -GroupName ESXi_group -ScheduleTime (Get-Date).AddHours(6)

    This command schedules a firmware download for all servers in group 'ESXi_group' to occur six hours from now.

    .EXAMPLE
    Invoke-HPECOMGroupServerFirmwareDownload -Region eu-central -GroupName ESXi_group -ScheduleTime (Get-Date).AddDays(1) -Interval P1W

    This command creates a recurring weekly firmware download schedule for all servers in group 'ESXi_group', starting one day from now.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's names or serial numbers.

    System.Collections.ArrayList
        List of groups from 'Get-HPECOMGroup' or list of servers from 'Get-HPECOMServer' or 'Get-HPECOMGroup -ShowMembers'.

    .OUTPUTS
    HPEGreenLake.COM.Jobs [System.Management.Automation.PSCustomObject]

        - If the -Async switch is used, the cmdlet returns the job resource immediately, allowing you to monitor
          its progress using the `state` and `resultCode` properties, or by passing the job object to
          `Wait-HPECOMJobComplete` for blocking/waiting behavior.

    HPEGreenLake.COM.Jobs.Status [System.Management.Automation.PSCustomObject]

        - When the job completes (sync mode), the returned object contains detailed job status information, including:
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

    HPEGreenLake.COM.Schedules [System.Management.Automation.PSCustomObject]

        - The schedule object that includes the schedule details when `-ScheduleTime` is used.

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

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String]$GroupName,

        [Parameter (ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('ServerSerialNumber', 'serial', 'serialnumber')]
        [ValidateNotNullOrEmpty()]
        [String]$ServerName,

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

        [switch]$InstallHPEDriversAndSoftware,

        [switch]$AllowFirmwareDowngrade,

        [switch]$TestConnectionRequirements,

        [Parameter (ParameterSetName = 'Async')]
        [switch]$Async,

        [switch]$WhatIf
    )

    Begin {

        [int]$TimeoutinSecondsPerServer = 3600  # Timeout 1 hour

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $_JobTemplateName = 'FirmwareDownload'

        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $Uri = Get-COMJobsUri

        $ServersList = [System.Collections.ArrayList]::new()
        $ServerIdsList = [System.Collections.ArrayList]::new()
        $ValidationStatusList = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Not match strings that start with @{, contain any characters in between, and end with }
        if ($ServerName -and $ServerName -notmatch '^@\{.*\}$') {

            [void]$ServersList.add($ServerName)
        }

    }

    End {

        try {
            $_group = Get-HPECOMGroup -Region $Region -Name $GroupName
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if (-not $_group) {

            $ErrorMessage = "Group '{0}' cannot be found in the '{1}' region!" -f $GroupName, $Region
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {
                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $ErrorMessage
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                [void]$ValidationStatusList.Add($objStatus)
                $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
                Return $ValidationStatusList
            }

        }

        $GroupMembers = $_group.devices
        $_groupName = $_group.name
        $_groupResourceUri = $_group.resourceUri
        $_groupId = $_group.id
        $NbOfServers = $_group.devices.count
        "[{0}] GroupName '{1}' detected - URI: '{2}' - Nb of servers: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_groupName, $_groupResourceUri, $NbOfServers | Write-Verbose

        try {
            $Servers = Get-HPECOMServer -Region $Region
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if ($ServersList) {

            "[{0}] List of servers to download firmware: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServersList | out-string) | Write-Verbose

            foreach ($Object in $ServersList) {

                $Server = $Servers | Where-Object { $_.name -eq $Object -or $_.host.hostname -eq $Object -or $_.hardware.serialNumber -eq $Object }

                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $null
                    duration           = '00:00:00'
                    associatedResource = $Object
                    region             = $Region
                }

                if (-not $Server) {

                    $objStatus.message = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Object
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                    if ($WhatIf) { Write-Warning "$($objStatus.message) Cannot display API request." }
                    else { [void]$ValidationStatusList.Add($objStatus) }

                }
                elseif (-not ($GroupMembers | Where-Object serial -eq $Server.hardware.serialNumber)) {

                    $objStatus.message = "Server '{0}': Resource is not a member of '{1}' group!" -f $Object, $GroupName
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                    if ($WhatIf) { Write-Warning "$($objStatus.message) Cannot display API request." }
                    else { [void]$ValidationStatusList.Add($objStatus) }

                }
                else {

                    # Building the list of device IDs for payload
                    [void]$ServerIdsList.Add($Server.id)

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
                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = "Group '{0}' has no members to download firmware to!" -f $GroupName
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                if ($WhatIf) { Write-Warning "$($objStatus.message) Cannot display API request." }
                else { [void]$ValidationStatusList.Add($objStatus) }

            }
        }

        if (-not $ServerIdsList -and -not $WhatIf -and $ValidationStatusList.Count -gt 0) {
            $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
            Return $ValidationStatusList
        }

        if ($ServerIdsList) {

            # Skip if a group firmware download job is already running for this group
            $_AllRunningJobs = @()
            try {
                $_AllRunningJobs = @(Get-HPECOMJob -Region $Region -ShowRunning -Verbose:$false -ErrorAction SilentlyContinue)
            }
            catch {
                "[{0}] Warning: Unable to query running jobs — in-progress check will be skipped. Error: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
            }
            $_existingRunningJob = $_AllRunningJobs | Where-Object {
                $_.name -eq $_JobTemplateName -and $_.resource.id -like "*$_groupId*"
            } | Select-Object -First 1
            if ($_existingRunningJob) {
                $_msg = "Group '{0}' already has a running firmware download job ('{1}'). Skipping to avoid conflict." -f $GroupName, $_existingRunningJob.resourceUri
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_msg | Write-Verbose
                if ($WhatIf) {
                    Write-Warning "$_msg Cannot display API request."
                }
                else {
                    $objStatus = [PSCustomObject]@{
                        state              = "WARNING"
                        resultCode         = "SKIPPED"
                        status             = "Warning"
                        message            = $_msg
                        duration           = '00:00:00'
                        associatedResource = $GroupName
                        region             = $Region
                    }
                    [void]$ValidationStatusList.Add($objStatus)
                    $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
                    Return $ValidationStatusList
                }
                return
            }

            "[{0}] List of server IDs to download firmware: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServerIdsList | out-string) | Write-Verbose

            $data = @{
                install_sw_drivers = [bool]$InstallHPEDriversAndSoftware
                downgrade          = [bool]$AllowFirmwareDowngrade
                test_connection    = [bool]$TestConnectionRequirements
                devices            = $ServerIdsList
            }

            if ($ScheduleTime) {

                $Uri = Get-COMSchedulesUri

                $_Body = @{
                    jobTemplateUri = "/api/compute/v1/job-templates/" + $JobTemplateId
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

                $Name = "$($GroupName)_GroupFirmwareDownload_Schedule_$($randomNumber)"
                $Description = "Scheduled task to download firmware for '$_groupName' group"

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

                $payload = @{
                    name                  = $Name
                    description           = $Description
                    associatedResourceUri = $_groupResourceUri
                    purpose               = "GROUP_FW_DOWNLOAD"
                    schedule              = $Schedule
                    operation             = $Operation
                }

            }
            else {

                $payload = @{
                    jobTemplate  = $JobTemplateId
                    resourceId   = $_groupId
                    resourceType = "compute-ops-mgmt/group"
                    jobParams    = $data
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

                    if (-not $WhatIf -and $_resp.state -eq 'APPROVAL_PENDING') {
                        Write-Warning "Group '$GroupName': Job is pending approval. Use 'Get-HPECOMApprovalRequest -State PENDING' to view pending requests and 'Resolve-HPECOMApprovalRequest' to approve or decline."
                    }
                    elseif (-not $WhatIf -and -not $Async) {

                        "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $TimeoutinSecondsPerServer | Write-Verbose

                        $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $TimeoutinSecondsPerServer

                        "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

                    }
                    else {

                        if (-not $WhatIf) {
                            $ReturnData = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs"
                        }

                    }
                }

            }
            catch {

                if (-not $WhatIf) {

                    $PSCmdlet.ThrowTerminatingError($_)

                }
            }

            if (-not $WhatIf) {
                Return $(if ($ScheduleTime -or $Async) { $ReturnData } else { $_resp })
            }
        }
    }
}

function Update-HPECOMGroupServerFirmware {
    <#
    .SYNOPSIS
    Updates the firmware of a group of servers.
    
    .DESCRIPTION   
    This cmdlet initiates a parallel server group firmware update that will affect some or all of the server group members. It also provides an option to schedule the update at a specific time.

    Note: If an approval policy is active for this group, this operation may require approval before the job executes.
          Use 'Get-HPECOMApprovalRequest -State PENDING' to check for pending requests and 'Resolve-HPECOMApprovalRequest' to approve or decline.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the group is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
        
    .PARAMETER GroupName
    Name of the group on which the firmware update will be performed.     
    
    .PARAMETER ServerSerialNumber
    (Optional) Specifies the serial number of the server on which the firmware update will be performed.
    
    If not specified, the firmware update will be performed on all servers in the group.

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
    Update-HPECOMGroupServerFirmware -Region eu-central -GroupName ESXi_800 -PowerOffAfterUpdate 

    This command updates in parallel the firmware for all servers in a group named `ESXi_800` located in the `eu-central` region. It also powers off the servers after the update.
   
    .EXAMPLE
    $task = Update-HPECOMGroupServerFirmware -Region eu-central -GroupName ESXi_800 -Async
    $task | Wait-HPECOMJobComplete

    This command updates in parallel the firmware for all servers in a group named `ESXi_800` located in the `eu-central` region. 
    The update runs asynchronously, and the task is monitored using the `Wait-HPECOMJobComplete` cmdlet.

    .EXAMPLE
    Update-HPECOMGroupServerFirmware -Region eu-central -GroupName ESXi_800 -SerialUpdates -StopOnFailure -AllowFirmwareDowngrade -InstallHPEDriversAndSoftware -DisablePrerequisiteCheck 
    
    This command updates in serial the firmware for all servers in a group named `ESXi_800` located in the `eu-central` region. It specifies that after a failure, the firmware update process will stop,
    and the remaining devices in the group will not be updated. It also installs HPE drivers and software, disables the prerequisites check, and allows firmware downgrade. 

    .EXAMPLE
    Update-HPECOMGroupServerFirmware -Region eu-central -GroupName ESXi_800 -ServerSerialNumber 'CZ2311004H' -AllowFirmwareDowngrade 

    This command updates the firmware for a specific server with the serial number `CZ2311004H` in a group named `ESXi_800` located in the `eu-central` region. It allows firmware downgrade.

    .EXAMPLE
    Update-HPECOMGroupServerFirmware -Region eu-central -GroupName ESXi_800 -WaitForPowerOfforReboot -WaitForPowerOfforRebootTimeout 8 

    This command updates in parallel the firmware for all servers in a group named `ESXi_800` located in the `eu-central` region. 
    It waits for the user to power off or reboot the server before performing the installation. The timeout for waiting is set to 8 hours.
    After 8 hours, if the server is not powered off or rebooted, the firmware update will be canceled.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central | Where-Object {$_.serialNumber -eq "CZ12312312" -or $_.serialNumber -eq "DZ12312312"}  | Update-HPECOMGroupServerFirmware -GroupName  ESXi_800 -AllowFirmwareDowngrade -Async
     
    The first command retrieves a list of all servers in the 'eu-central' region.
    The second command filters the list to include only the servers with serial numbers 'CZ12312312' or 'DZ12312312'.
    The last command updates the firmware of the selected servers as part of the 'ESXi_800' group.
    The update runs in parallel across the selected servers. Firmware downgrades are allowed if necessary. The update runs asynchronously, allowing other tasks to continue without waiting for completion.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -Name ESXi_800 -ShowMembers | Update-HPECOMGroupServerFirmware 
    
    This command retrieves the list of servers in a group named 'ESXi_800' located in the 'eu-central' region and updates the firmware for all servers in the group.

    .EXAMPLE
    "CZ12312312", "DZ12312312" | Update-HPECOMGroupServerFirmware -Region eu-central -GroupName ESXi_800
    
    This command updates the firmware for servers with serial numbers 'CZ12312312' and 'DZ12312312' in a group named 'ESXi_800' located in the 'eu-central' region.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central | ForEach-Object { $_ | Update-HPECOMGroupServerFirmware } 

    This command retrieves all groups in the 'eu-central' region and updates the firmware for each group.

    .EXAMPLE
    Update-HPECOMGroupServerFirmware -Region eu-central -GroupName ESXi_800 -ScheduleTime (Get-Date).AddDays(4)

    This command creates a schedule to update the firmware of all servers in a group named 'ESXi_800' located in the 'eu-central' region. The schedule is set to run four days from now.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central | Where-Object { $_.SerialNumber -eq "CZ12312312" -or $_.SerialNumber -eq "DZ12312312" } | Update-HPECOMGroupServerFirmware -GroupName ESXi_800 -ScheduleTime (Get-Date).AddHours(12)

    This command retrieves servers with specific serial numbers from the 'eu-central' region and schedules a firmware update for them in the 'ESXi_800' group in twelve hours.
   
    .EXAMPLE    
    Get-HPECOMGroup -Region eu-central -name ESXi_800 -ShowMembers | Select-Object -Last 2 | Update-HPECOMGroupServerFirmware -GroupName ESXi_800 -ScheduleTime (Get-Date).AddMonths(6)

    This example retrieves the last two servers from the 'ESXi_800' in the 'eu-central' region and schedules a firmware update for them six months from the current date.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.

    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer' or 'Get-HPECOMGroup -ShowMembers'.

    .OUTPUTS
    HPEGreenLake.COM.Jobs [System.Management.Automation.PSCustomObject]

        - If the -Async switch is used, the cmdlet returns the job resource immediately, allowing you to monitor
          its progress using the `state` and `resultCode` properties, or by passing the job object to
          `Wait-HPECOMJobComplete` for blocking/waiting behavior.

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

    HPEGreenLake.COM.Schedules [System.Management.Automation.PSCustomObject]

        - The schedule job object that includes the schedule details when `-ScheduleTime` is used.

    #>

    [CmdletBinding(DefaultParameterSetName = 'Scheduled')]
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
                
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String]$GroupName,

        [Parameter (ValueFromPipeline, ValueFromPipelineByPropertyName)] 
        [Alias('ServerSerialNumber', 'serial', 'serialnumber')]
        [ValidateNotNullOrEmpty()]
        [String]$ServerName,

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

        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $Uri = Get-COMJobsUri

        $ServersList = [System.Collections.ArrayList]::new()
        $ServerIdsList = [System.Collections.ArrayList]::new()
        $ValidationStatusList = [System.Collections.ArrayList]::new()

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
        if ($ServerName -and $ServerName -notmatch '^@\{.*\}$') {
            
            [void]$ServersList.add($ServerName)
        }

    }

    End {

        try {
            $_group = Get-HPECOMGroup -Region $Region -Name $GroupName
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if ( -not $_group) {

            $ErrorMessage = "Group '{0}' cannot be found in the '{1}' region!" -f $GroupName, $Region
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {
                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $ErrorMessage
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                [void]$ValidationStatusList.Add($objStatus)
                $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
                Return $ValidationStatusList
            }

        }

        $GroupMembers = $_group.devices
        $_groupName = $_group.name
        $_groupResourceUri = $_group.resourceUri
        $_groupId = $_group.id
        $NbOfServers = $_group.devices.count
        "[{0}] GroupName '{1}' detected - URI: '{2}' - Nb of servers: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_groupName, $_groupResourceUri, $NbOfServers | Write-Verbose

        
        try {
            
            $Servers = Get-HPECOMServer -Region $Region
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }
        
        
        if ($ServersList) {

            "[{0}] List of servers to update: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServersList | out-string) | Write-Verbose

            foreach ($Object in $ServersList) {

                $Server = $Servers | Where-Object { $_.name -eq $Object -or $_.host.hostname -eq $Object -or $_.hardware.serialNumber -eq $Object }

                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $null
                    duration           = '00:00:00'
                    associatedResource = $Object
                    region             = $Region
                }

                if ( -not $Server) {
    
                    $objStatus.message = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Object
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                    if ($WhatIf) { Write-Warning "$($objStatus.message). Cannot display API request." }
                    else { [void]$ValidationStatusList.Add($objStatus) }
    
                } 
                elseif (-not ($GroupMembers | Where-Object serial -eq $Server.hardware.serialNumber)) {   
                   
                    $objStatus.message = "Server '{0}': Resource is not a member of '{1}' group!" -f $Object, $GroupName
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                    if ($WhatIf) { Write-Warning "$($objStatus.message). Cannot display API request." }
                    else { [void]$ValidationStatusList.Add($objStatus) }
    
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
                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = "Group '{0}' has no members to be updated!" -f $GroupName
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                if ($WhatIf) { Write-Warning "$($objStatus.message). Cannot display API request." }
                else { [void]$ValidationStatusList.Add($objStatus) }

            }
        }

        if (-not $ServerIdsList -and -not $WhatIf -and $ValidationStatusList.Count -gt 0) {
            $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
            Return $ValidationStatusList
        }

        if ($ServerIdsList) {   

            # Skip if a group firmware update job is already running for this group
            $_AllRunningJobs = @()
            try {
                $_AllRunningJobs = @(Get-HPECOMJob -Region $Region -ShowRunning -Verbose:$false -ErrorAction SilentlyContinue)
            }
            catch {
                "[{0}] Warning: Unable to query running jobs — in-progress check will be skipped. Error: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
            }
            $_existingRunningJob = $_AllRunningJobs | Where-Object {
                $_.name -eq $_JobTemplateName -and $_.resource.id -like "*$_groupId*"
            } | Select-Object -First 1
            if ($_existingRunningJob) {
                $_msg = "Group '{0}' already has a running firmware update job ('{1}'). Skipping to avoid conflict." -f $GroupName, $_existingRunningJob.resourceUri
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_msg | Write-Verbose
                if ($WhatIf) {
                    Write-Warning "$_msg Cannot display API request."
                }
                else {
                    $objStatus = [PSCustomObject]@{
                        state              = "WARNING"
                        resultCode         = "SKIPPED"
                        status             = "Warning"
                        message            = $_msg
                        duration           = '00:00:00'
                        associatedResource = $GroupName
                        region             = $Region
                    }
                    [void]$ValidationStatusList.Add($objStatus)
                    $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
                    Return $ValidationStatusList
                }
                return
            }

            "[{0}] List of server IDs to update: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServerIdsList | out-string) | Write-Verbose
            
            # Build job data — devices always present (we are inside 'if ($ServerIdsList)')
            # stopOnFailure only applies to serial updates
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
            if (-not $Parallel) {
                $data.stopOnFailure = $StopOnFailureValue
            }
            
            if ($ScheduleTime) {

                $Uri = Get-COMSchedulesUri

                $_Body = @{
                    jobTemplateUri = "/api/compute/v1/job-templates/" + $JobTemplateId
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
                $payload = @{
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
                        if ($Parallel) {
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

                        if (-not $WhatIf) {
                            $ReturnData = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs"
                        }

                    }
                }

            }
            catch {

                if (-not $WhatIf) {

                    $PSCmdlet.ThrowTerminatingError($_)

                }
            }  

            if (-not $WhatIf) {
                Return $(if ($ScheduleTime -or $Async) { $ReturnData } else { $_resp })
            }
        }
    }
}

function Stop-HPECOMGroupServerFirmware {
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
    $Job = Update-HPECOMGroupServerFirmware -Region eu-central -GroupName ESXi_group -Async 
    Stop-HPECOMGroupServerFirmware -Region eu-central -InputJobObject $Job

    The first command initiates an asynchronous firmware update for the server group named ESXi_group in the eu-central region. The second command cancels this ongoing firmware update job.

    .EXAMPLE
    $Job = Update-HPECOMGroupServerFirmware -Region  eu-central -GroupName ESXi_group -Async 
    $Job | Stop-HPECOMGroupServerFirmware 

    This command starts an asynchronous firmware update for all servers in a group named `ESXi_group` located in the `eu-central` region, and then it stops the update process.

    .EXAMPLE
    Get-HPECOMJob -Region eu-central -Type groups | Select-Object -last 1 | Stop-HPECOMGroupServerFirmware 

    This command retrieves the last group firmware update job in the `eu-central` region and stops the update process.

    .INPUTS
    System.Collections.ArrayList
        List of jobs from 'Get-HPECOMJob'.

    .OUTPUTS
    HPEGreenLake.COM.Jobs [System.Management.Automation.PSCustomObject]

        - If the -Async switch is used, the cmdlet returns the job resource immediately, allowing you to monitor
          its progress using the `state` and `resultCode` properties, or by passing the job object to
          `Wait-HPECOMJobComplete` for blocking/waiting behavior.

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

    #>

    [CmdletBinding(DefaultParameterSetName = 'GroupNameSerial')]
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
    
                    "[{0}] ID = '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $InputJobObject.id | Write-Verbose
                    $Uri = (Get-COMJobsUri) + '/' + $InputJobObject.id

                    $_job = Get-HPECOMJob -Region $Region -JobResourceUri $uri -WarningAction SilentlyContinue
    
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

        # Init $_resp once per pipeline item — mutate .message and .resultCode per branch below
        $_resp = [PSCustomObject]@{
            id         = $InputJobObject.id
            state      = "WARNING"
            resultCode = "FAILURE"
            status     = "Warning"
            message    = $null
            duration   = '00:00:00'
            region     = $Region
        }
        
        if (-not $_job) {
            
            $_resp.message = "Job ID '{0}' cannot be found in the Compute Ops Management instance!" -f $InputJobObject.id
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp.message | Write-Verbose
            if ($WhatIf) { Write-Warning $_resp.message; return }
            [void]$StopGroupFirmwareStatus.add($_resp)
            return   # exit this Process iteration; End block returns the typed list
            
        }
        elseif ($_job.state -eq "COMPLETE") {

            $_resp.resultCode = $null
            $_resp.message = "Job ID '{0}' is already in 'COMPLETE' state and cannot be stopped!" -f $InputJobObject.id
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp.message | Write-Verbose
            if ($WhatIf) { Write-Warning $_resp.message; return }
            [void]$StopGroupFirmwareStatus.add($_resp)

        }
        elseif ($_job.jobParams.parallel -eq $True) {

            $_resp.message = "Job ID '{0}' cannot be stopped because the server group firmware update is not set with the Serial update option enabled!" -f $InputJobObject.id
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp.message | Write-Verbose
            if ($WhatIf) { Write-Warning $_resp.message; return }
            [void]$StopGroupFirmwareStatus.add($_resp)

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
                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method PATCH -body $payload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
    
                # Add region to object
                $_resp | Add-Member -type NoteProperty -name region -value $Region

                # Guard Invoke-RepackageObjectWithType — $_resp is null when WhatIf active
                if (-not $WhatIf) {
                    $_resp = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs"
                }
    
                if (-not $WhatIf -and -not $Async) {
        
                    $Timeout = 3600 # 1 hour
                                    
                    "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose
    
                    $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout 
    
                    "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
    
                }
            }
            catch {
    
                if (-not $WhatIf) {
    
                    $PSCmdlet.ThrowTerminatingError($_)
    
                }
            }  
            
            if (-not $WhatIf) {
                [void]$StopGroupFirmwareStatus.add($_resp)
            }
        }
    }
    
    End {
        
        if ($StopGroupFirmwareStatus.Count -gt 0) {
            
            $StopGroupFirmwareStatus = Invoke-RepackageObjectWithType -RawObject $StopGroupFirmwareStatus -ObjectName "COM.Jobs.Status"

            Return $StopGroupFirmwareStatus
        
        }
    }
}

function Invoke-HPECOMGroupServerFirmwareComplianceCheck {
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
    Invoke-HPECOMGroupServerFirmwareComplianceCheck -Region eu-central -GroupName ESX-800  

    This command checks firmware compliance of all servers in the group 'ESX-800' in the 'eu-central' region.
   
    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -Name ESXi_group | Invoke-HPECOMGroupServerFirmwareComplianceCheck

    This command checks firmware compliance of all servers in the group named 'ESXi_group' in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central | Invoke-HPECOMGroupServerFirmwareComplianceCheck 

    This command checks firmware compliance of all servers in all groups of the 'eu-central' region.

    .EXAMPLE
    Invoke-HPECOMGroupServerFirmwareComplianceCheck -Region eu-central -GroupName ESX-800 -ScheduleTime (get-Date).addminutes(10) 

    Schedules the execution of a group firmware compliance check on the group named 'ESX-800' in the `eu-central` region starting 10 minutes from now. 

    .EXAMPLE
    Invoke-HPECOMGroupServerFirmwareComplianceCheck -Region eu-central -GroupName ESX-800 -ScheduleTime (get-Date).addhours(6) -Interval P1M

    Schedules a monthly execution of a group firmware compliance check on the group named 'ESX-800' in the `eu-central` region. The first execution will start in 6 hours. 

    .EXAMPLE
    "ESXi_group", "RHEL_group" | Invoke-HPECOMGroupServerFirmwareComplianceCheck -Region  eu-central

    This command checks firmware compliance of all servers in the groups 'ESXi_group' and 'RHEL_group' in the `eu-central` region.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the group's names.
    
    System.Collections.ArrayList
        List of groups from 'Get-HPECOMGroup'.

    .OUTPUTS
    HPEGreenLake.COM.Jobs [System.Management.Automation.PSCustomObject]

        - If the -Async switch is used, the cmdlet returns the job resource immediately, allowing you to monitor
          its progress using the `state` and `resultCode` properties, or by passing the job object to
          `Wait-HPECOMJobComplete` for blocking/waiting behavior.

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

    HPEGreenLake.COM.Schedules [System.Management.Automation.PSCustomObject]

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
        [alias('name')]
        [ValidateNotNullOrEmpty()]
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
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }

            $_resp = [PSCustomObject]@{
                state              = "WARNING"
                resultCode         = "FAILURE"
                status             = "Warning"
                message            = $ErrorMessage
                duration           = '00:00:00'
                associatedResource = $GroupName
                region             = $Region
            }
            [void]$GroupFirmwareComplianceStatus.add($_resp)
            return
            
        }
        # elseif ($_groupCompliance.complianceState -like "Not Applicable") {
            
        #     # Must return an error if one of the server is not in good condition to run a compliance report (I had a 'Power stalled' condition which causes exception)
        #     $ErrorMessage = "Group '{0}' is not applicable for a compliance check. Please verify the state of each server in the group using 'Get-HPECOMGroup -ShowCompliance'." -f $GroupName
        #     Write-Warning "$ErrorMessage Cannot display API request."
        # }
        else {
            
            $_ResourceUri = $_group.resourceUri
            $_ResourceId = $_group.id
            $NbOfServers = $_group.devices.count

            "[{0}] GroupName '{1}' detected - URI: '{2}' - Nb of servers: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GroupName, $_ResourceUri, $NbOfServers | Write-Verbose         

            if ($NbOfServers -eq 0) {

                # Must return a message if no servers in group
                $ErrorMessage = "Group '{0}': Operation cannot be executed because no server has been found in the group!" -f $GroupName
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
                    return
                }

                $_resp = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $ErrorMessage
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                [void]$GroupFirmwareComplianceStatus.add($_resp)
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

                        # Guard — $_resp is null when WhatIf active
                        if (-not $WhatIf) {
                            $ReturnData = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs"
                        }
                    }
                }
            }
            catch {

                if (-not $WhatIf) {

                    $PSCmdlet.ThrowTerminatingError($_)

                }
            }  

            # ScheduleTime → $ReturnData (COM.Schedules), Async → $ReturnData (COM.Jobs)
            # Sync         → $_resp (Wait-HPECOMJobComplete result); accumulate for End block
            if (-not $WhatIf) {
                if ($ScheduleTime -or $Async) {
                    Return $ReturnData
                }
                else {
                    [void] $GroupFirmwareComplianceStatus.add($_resp)
                }
            }
        }
    }

    End {

        if ($GroupFirmwareComplianceStatus.Count -gt 0) {
            
            $GroupFirmwareComplianceStatus = Invoke-RepackageObjectWithType -RawObject $GroupFirmwareComplianceStatus -ObjectName "COM.Jobs.Status"

            Return $GroupFirmwareComplianceStatus
        
        }
    }
}

function Get-HPECOMGroupServerFirmwareCompliance {
    <#
    .SYNOPSIS
    Retrieves the firmware compliance details of servers within a specified group.
    
    .DESCRIPTION   
    The `Get-HPECOMGroupServerFirmwareCompliance` cmdlet allows you to obtain detailed information about the firmware compliance of all servers in a designated group. 
    This cmdlet can be useful for identifying deviations from the group's firmware baseline, ensuring that all devices are up to date and compliant with organizational standards.
    
    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the server group is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER GroupName
    Specifies the name of the server group on which the firmware compliance details will be retrieved.

    .PARAMETER ServerSerialNumber
    (Optional) Specifies the serial number of an individual server to retrieve its specific compliance details within the group. If not specified, the compliance check will be performed on all servers in the group.

    .PARAMETER ShowDeviations
    Switch parameter that retrieves only the firmware components which have deviations from the group's firmware baseline.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMGroupServerFirmwareCompliance -Region eu-central -GroupName ESX-800  

    This command returns the firmware compliance of all servers in the group 'ESX-800' in the 'eu-central' region.
   
    .EXAMPLE
    Get-HPECOMGroupServerFirmwareCompliance -Region eu-central -GroupName ESX-800 -ServerSerialNumber CZ12312312 

    This command returns the firmware compliance of the server with serial number 'CZ12312312' in the group 'ESX-800' in the 'eu-central' region.

    .EXAMPLE
    Get-HPECOMGroupServerFirmwareCompliance -Region eu-central -GroupName ESX-800 -ServerSerialNumber CZ12312312 -ShowDeviations

    This command returns the firmware components which have a deviation with the group 'ESX-800' firmware baseline in the 'eu-central' region.
    
    .EXAMPLE
    Get-HPECOMGroup -Region eu-central | Get-HPECOMGroupServerFirmwareCompliance 

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
        
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String]$GroupName,

        [Parameter (ValueFromPipelineByPropertyName, ParameterSetName = 'ServerSerialNumber')]
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'DeviationsServerSerialNumber')]
        [Alias('ServerSerialNumber', 'serial', 'serialnumber')]
        [ValidateNotNullOrEmpty()]
        [String]$ServerName,

        [Parameter (ParameterSetName = 'DeviationsServerSerialNumber')]
        [Parameter (ParameterSetName = 'DeviationsServerName')]
        [switch]$ShowDeviations,

        [switch]$WhatIf

    )

    Begin {
  
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
      
      
    }
            
    Process {
      
        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose      

        try {

            $_allGroups = Invoke-HPECOMWebRequest -Method Get -Uri (Get-COMGroupsUri) -Region $Region
            $_group = @($_allGroups) | Where-Object { $_.name -ieq $GroupName } | Select-Object -First 1
            $GroupID = $_group.id

            "[{0}] ID found for group '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GroupName, $GroupID | Write-Verbose

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
            # groupName is used in Invoke-HPECOMGroupServerInternalStorageConfiguration, Update-HPECOMGroupServerFirmware, etc. 
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
                        
            if ($ServerName) {

                
                if ($ShowDeviations) {
                    
                    $CollectionList = $CollectionList | Where-Object { $_.serial -eq $ServerName -or $_.serverName -eq $ServerName } | ForEach-Object deviations | Sort-Object -Property ComponentName


                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Groups.Firmware.Compliance.Deviations"   
                    
                }
                else {
                    
                    $CollectionList = $CollectionList | Where-Object { $_.serial -eq $ServerName -or $_.serverName -eq $ServerName }

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

    HPEGreenLake.COM.Schedules.Status [System.Management.Automation.PSCustomObject]

        - The schedule job object that includes the schedule details when `-ScheduleTime` is used.

    #>

    [CmdletBinding()]
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
        
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SerialNumber')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ScheduleSerialNumber')]
        [Alias('ServerSerialNumber', 'serial', 'serialnumber')]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

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
                description        = "Scheduled task to get external storage details on server '$Name'"
                associatedResource = $Name
                region             = $Region
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
                associatedResource = $Name
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
            $Servers = Get-HPECOMServer -Region $Region
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

         
        foreach ($Resource in $ObjectStatusList) {
            
            $Server = $Servers | Where-Object { $_.name -eq $Resource.associatedResource -or $_.host.hostname -eq $Resource.associatedResource -or $_.hardware.serialNumber -eq $Resource.associatedResource }
              
            if (-not $Server) {

                $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Resource.associatedResource
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = $ErrorMessage

                }
                else {

                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Warning"
                    $Resource.message = $ErrorMessage
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
    
                    $ScheduleName = "$($Resource.associatedResource)_GetServerExternalStorage_Schedule_$($randomNumber)"
                    $Resource.name = $ScheduleName 

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
                        name                  = $ScheduleName
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

                        if (-not $WhatIf) {    
                             
                            "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose
            
                            $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout
            
                            "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

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
                            
                            $Resource.name = $ScheduleName
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

function Invoke-HPECOMGroupServerInternalStorageConfiguration {
    <#
    .SYNOPSIS
    Initiate a server group internal storage configuration.
    
    .DESCRIPTION   
    This cmdlet initiates a server group internal storage configuration that will affect some or all of the server group members.

    Note: If an approval policy is active for this group, this operation may require approval before the job executes.
          Use 'Get-HPECOMApprovalRequest -State PENDING' to check for pending requests and 'Resolve-HPECOMApprovalRequest' to approve or decline.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the group is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
        
    .PARAMETER GroupName
    Name of the group on which the internal storage configuration will be performed.     
    
    .PARAMETER ServerSerialNumber
    (Optional) Specifies the serial number of an individual server to configure its internal storage within the group. If not specified, the internal storage configuration will be performed on all servers in the group.

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
    Invoke-HPECOMGroupServerInternalStorageConfiguration -Region eu-central -GroupName ESXi_800

    This command initiates a server group internal storage configuration of all servers in a group named `ESXi_800` located in the `eu-central` region. 
   
    .EXAMPLE
    $IDs = Get-HPECOMSetting -Region eu-central -Name 'AI_SERVER_RAID1_5' -ShowVolumes | Select-Object -ExpandProperty id

    $Volumes = @(
        @{ id = $IDs[0]; name = "OS_Volume" },
        @{ id = $IDs[1]; name = "Data_Volume" }
    )

    Invoke-HPECOMGroupServerInternalStorageConfiguration -Region eu-central -GroupName ESXi_800 -AllowStorageVolumeDeletion -StorageVolumes $Volumes

    This command initiates a server group internal storage configuration for all servers in the group named `ESXi_800` in the `eu-central` region.
    The `-AllowStorageVolumeDeletion` switch ensures that any existing internal storage configuration is deleted before creating new OS volumes.
    The `-StorageVolumes $Volumes` parameter assigns custom names to the new volumes, such as 'OS_Volume' for the first and 'Data_Volume' for the second, as specified in the `$Volumes` array.

    .EXAMPLE
    Invoke-HPECOMGroupServerInternalStorageConfiguration -Region eu-central -GroupName ESXi_800 -ServerSerialNumber 'CZ12312312' 

    This command initiates a server group internal storage configuration of the server with the serial number 'CZ12312312' as part of the 'ESXi_800' group located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name "ESX-1" | Invoke-HPECOMGroupServerInternalStorageConfiguration -GroupName ESXi_800

    This command initiates a server group internal storage configuration of the server named 'ESX-1' as part of the 'ESXi_800' group located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central | Where-Object {$_.serialNumber -eq "CZ12312312" -or $_.serialNumber -eq "DZ12312312"}  | Invoke-HPECOMGroupServerInternalStorageConfiguration -GroupName ESXi_800 -Async
     
    The first command retrieves a list of all servers in the 'eu-central' region.
    The second command filters the list to include only the servers with serial numbers 'CZ12312312' or 'DZ12312312'.
    The last command initiates a server group internal storage configuration of the specified servers as part of the 'ESXi_800' group.
    The configuration runs asynchronously, allowing other tasks to continue without waiting for completion.
       
    .EXAMPLE
    "CZ12312312", "DZ12312312" | Invoke-HPECOMGroupServerInternalStorageConfiguration -Region eu-central -GroupName ESXi_800 
    
    This command initiates a server group internal storage configuration of the servers with serial numbers 'CZ12312312' and 'DZ12312312' as part of the 'ESXi_800' group located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central | ForEach-Object { $_ | Invoke-HPECOMGroupServerInternalStorageConfiguration }
    
    This command retrieves a list of all groups in the 'eu-central' region and initiates a server group internal storage configuration for each group.
    
    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.

    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer' or 'Get-HPECOMGroup -ShowMembers'.

    .OUTPUTS
    HPEGreenLake.COM.Jobs [System.Management.Automation.PSCustomObject]

        - If the -Async switch is used, the cmdlet returns the job resource immediately, allowing you to monitor
          its progress using the `state` and `resultCode` properties, or by passing the job object to
          `Wait-HPECOMJobComplete` for blocking/waiting behavior.

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

    #>

    [CmdletBinding()]
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
                
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String]$GroupName,

        [Parameter (ValueFromPipeline, ValueFromPipelineByPropertyName)] 
        [Alias('ServerSerialNumber', 'serial', 'serialnumber')]
        [ValidateNotNullOrEmpty()]
        [String]$ServerName,

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
        $ValidationStatusList = [System.Collections.ArrayList]::new()
        
        if ($AllowStorageVolumeDeletion) {
            $isStorageVolumeDeletionAllowed = $true
        }
        else {
            $isStorageVolumeDeletionAllowed = $false
        }     
        
    }
    
    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        if ($ServerName -and $ServerName -notmatch '^@\{.*\}$') {
            
            [void]$ServersList.add($ServerName)
        }

    }

    End {

        try {
            $_group = Get-HPECOMGroup -Region $Region -Name $GroupName
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if (-not $_group) {

            $ErrorMessage = "Group '{0}' cannot be found in the '{1}' region!" -f $GroupName, $Region
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }

            $_resp = [PSCustomObject]@{
                state              = "WARNING"
                resultCode         = "FAILURE"
                status             = "Warning"
                message            = $ErrorMessage
                duration           = '00:00:00'
                associatedResource = $GroupName
                region             = $Region
            }
            [void]$ValidationStatusList.Add($_resp)
            $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
            Return $ValidationStatusList
        }

        # Extract properties AFTER null guard — never inside try block (NPE risk)
        $GroupMembers      = $_group.devices
        $_groupName        = $_group.name
        $_groupResourceUri = $_group.resourceUri
        $_groupId          = $_group.id
        $NbOfServers       = $_group.devices.count

        "[{0}] GroupName '{1}' detected - URI: '{2}' - Nb of servers: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_groupName, $_groupResourceUri, $NbOfServers | Write-Verbose

        try {
            $Servers = Get-HPECOMServer -Region $Region
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
        

        
        
        if ($ServersList) {

            "[{0}] List of servers to configure: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServersList | out-string) | Write-Verbose

            foreach ($Object in $ServersList) {

                $Server = $Servers | Where-Object { $_.name -eq $Object -or $_.host.hostname -eq $Object -or $_.hardware.serialNumber -eq $Object }

                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $null
                    duration           = '00:00:00'
                    associatedResource = $Object
                    region             = $Region
                }

                if (-not $Server) {

                    $objStatus.message = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Object
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                    if ($WhatIf) { Write-Warning "$($objStatus.message). Cannot display API request." }
                    else { [void]$ValidationStatusList.Add($objStatus) }

                }
                elseif (-not ($GroupMembers | Where-Object serial -eq $Server.hardware.serialNumber)) {

                    $objStatus.message = "Server '{0}': Resource is not a member of '{1}' group!" -f $Object, $GroupName
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                    if ($WhatIf) { Write-Warning "$($objStatus.message). Cannot display API request." }
                    else { [void]$ValidationStatusList.Add($objStatus) }

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
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request." }
                else {
                    $_resp = [PSCustomObject]@{
                        state              = "WARNING"
                        resultCode         = "FAILURE"
                        status             = "Warning"
                        message            = $ErrorMessage
                        duration           = '00:00:00'
                        associatedResource = $GroupName
                        region             = $Region
                    }
                    [void]$ValidationStatusList.Add($_resp)
                }
            }
        }

        # Early return if all servers failed validation
        if (-not $ServerIdsList -and -not $WhatIf -and $ValidationStatusList.Count -gt 0) {
            $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
            Return $ValidationStatusList
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

                    # Guard — $_resp is null when WhatIf active
                    if (-not $WhatIf) {
                        $_resp = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs"
                    }
                }
                 
            }
            catch {

                if (-not $WhatIf) {

                    $PSCmdlet.ThrowTerminatingError($_)

                }
            }  

            if (-not $WhatIf) {
                if ($ValidationStatusList.Count -gt 0) {
                    $AllResults = [System.Collections.ArrayList]::new()
                    $ValidationStatusList | ForEach-Object { [void]$AllResults.Add($_) }
                    [void]$AllResults.Add($_resp)
                    Return (Invoke-RepackageObjectWithType -RawObject $AllResults -ObjectName "COM.Jobs.Status")
                }
                Return (Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs.Status")
            }
        }
    }
}

function Invoke-HPECOMGroupServerOSInstallation {
    <#
    .SYNOPSIS
    Initiate a group OS installation.
    
    .DESCRIPTION   
    This cmdlet initiates a group operating system installation that will affect some or all of the server group members.

    Note: If an approval policy is active for this group, this operation may require approval before the job executes.
          Use 'Get-HPECOMApprovalRequest -State PENDING' to check for pending requests and 'Resolve-HPECOMApprovalRequest' to approve or decline.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the group is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
        
    .PARAMETER GroupName
    Name of the group on which the operating system installation will be performed.     

    .PARAMETER ServerSerialNumber
    (Optional) Specifies the serial number of an individual server to install the operating system within the group.

    If not specified, the operating system installation will be performed on all servers in the group.

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
    Invoke-HPECOMGroupServerOSInstallation -Region eu-central -GroupName ESXi_800

    This command initiates a group operating system installation of all servers in a group named `ESXi_800` located in the `eu-central` region.
    
    .EXAMPLE
    Invoke-HPECOMGroupServerOSInstallation -Region eu-central -GroupName ESXi_800 -ParallelInstallations

    This command initiates a group operating system installation of all servers in a group named `ESXi_800` located in the `eu-central` region.
    The installation is performed in parallel instead of serial by default.
   
    .EXAMPLE
    Invoke-HPECOMGroupServerOSInstallation -Region eu-central -GroupName ESXi_800 -StopOnFailure -OSCompletionTimeoutMin 100

    This command initiates a group operating system installation of all servers in a group named `ESXi_800` located in the `eu-central` region.
    The installation halts upon the first failure, and the operating system image is unmounted from the server after 100 minutes, reduced from the default 240 minutes.

    .EXAMPLE
    Invoke-HPECOMGroupServerOSInstallation -Region eu-central -GroupName ESXi_800 -ServerSerialNumber 'CZ12312312' 

    This command initiates a group operating system installation of the server with the serial number 'CZ12312312' as part of the 'ESXi_800' group located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name "ESX-1" | Invoke-HPECOMGroupServerOSInstallation -GroupName ESXi_800

    This command initiates a group operating system installation of the server named 'ESX-1' as part of the 'ESXi_800' group located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central | Where-Object {$_.serialNumber -eq "CZ12312312" -or $_.serialNumber -eq "DZ12312312"}  | Invoke-HPECOMGroupServerOSInstallation -GroupName ESXi_800 -Async
     
    The first command retrieves a list of all servers in the 'eu-central' region.
    The second command filters the list to include only the servers with serial numbers 'CZ12312312' or 'DZ12312312'.
    The last command initiates a group operating system installation of the specified servers as part of the 'ESXi_800' group. 
    The configuration runs asynchronously, allowing other tasks to continue without waiting for completion.
       
    .EXAMPLE
    "CZ12312312", "DZ12312312" | Invoke-HPECOMGroupServerOSInstallation -Region eu-central -GroupName ESXi_800 
    
    This command initiates a group operating system installation of the servers with serial numbers 'CZ12312312' and 'DZ12312312' as part of the 'ESXi_800' group located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central | ForEach-Object { $_ | Invoke-HPECOMGroupServerOSInstallation }

    This command retrieves a list of all groups in the 'eu-central' region and initiates a group operating system installation for each group.
      
    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.

    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer' or 'Get-HPECOMGroup -ShowMembers'.    

    .OUTPUTS
    HPEGreenLake.COM.Jobs [System.Management.Automation.PSCustomObject]

        - If the -Async switch is used, the cmdlet returns the job resource immediately, allowing you to monitor
          its progress using the `state` and `resultCode` properties, or by passing the job object to
          `Wait-HPECOMJobComplete` for blocking/waiting behavior.

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
 
    #>

    [CmdletBinding(DefaultParameterSetName = 'GroupNameSerial')]
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
                
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "GroupNameSerial")]
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "GroupNameParallel")]
        [ValidateNotNullOrEmpty()]
        [String]$GroupName,
        
        [Parameter (ValueFromPipeline, ValueFromPipelineByPropertyName)] 
        [Alias('ServerSerialNumber', 'serial', 'serialnumber')]
        [ValidateNotNullOrEmpty()]
        [String]$ServerName,

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

        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $Uri = Get-COMJobsUri

        $ServersList = [System.Collections.ArrayList]::new()
        $ServerIdsList = [System.Collections.ArrayList]::new()
        $ValidationStatusList = [System.Collections.ArrayList]::new()


        if ($StopOnFailure) {
            $StopOnFailureValue = $true
        }
        else {
            $StopOnFailureValue = $false
        }
                
        
    }
    
    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        if ($ServerName -and $ServerName -notmatch '^@\{.*\}$') {
            
            [void]$ServersList.add($ServerName)
        }

           

    }

    End {

        try {
            $_group = Get-HPECOMGroup -Region $Region -Name $GroupName
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if (-not $_group) {

            $ErrorMessage = "Group '{0}' cannot be found in the '{1}' region!" -f $GroupName, $Region

            if ($WhatIf) {
                Write-Warning  "$ErrorMessage. Cannot display API request."
                Return
            }
            else {
                $_resp = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $ErrorMessage
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                [void]$ValidationStatusList.Add($_resp)
                Return Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
            }
        }

        $GroupMembers = $_group.devices
        $_groupName = $_group.name
        $_groupResourceUri = $_group.resourceUri
        $_groupId = $_group.id
        $NbOfServers = $_group.devices.count

        "[{0}] GroupName '{1}' detected - URI: '{2}' - Nb of servers: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_groupName, $_groupResourceUri, $NbOfServers | Write-Verbose


        try {
            
            $Servers = Get-HPECOMServer -Region $Region
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }
        

        if ($ServersList) {

            "[{0}] List of servers to configure: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServersList | out-string) | Write-Verbose

            foreach ($Object in $ServersList) {

                $Server = $Servers | Where-Object { $_.name -eq $Object -or $_.host.hostname -eq $Object -or $_.hardware.serialNumber -eq $Object }
    
                if (-not $Server) {

                    $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Object

                    $objStatus = [PSCustomObject]@{
                        state              = "WARNING"
                        resultCode         = "FAILURE"
                        status             = "Warning"
                        message            = $null
                        duration           = '00:00:00'
                        associatedResource = $Object
                        region             = $Region
                    }
                    $objStatus.message = $ErrorMessage

                    if ($WhatIf) {
                        Write-Warning "$($objStatus.message). Cannot display API request."
                    }
                    else {
                        [void]$ValidationStatusList.Add($objStatus)
                    }

                }
                elseif (-not ($GroupMembers | Where-Object serial -eq $Server.hardware.serialNumber)) {

                    $ErrorMessage = "Server '{0}': Resource is not a member of '{1}' group!" -f $Object, $GroupName

                    $objStatus = [PSCustomObject]@{
                        state              = "WARNING"
                        resultCode         = "FAILURE"
                        status             = "Warning"
                        message            = $null
                        duration           = '00:00:00'
                        associatedResource = $Object
                        region             = $Region
                    }
                    $objStatus.message = $ErrorMessage

                    if ($WhatIf) {
                        Write-Warning "$($objStatus.message). Cannot display API request."
                    }
                    else {
                        [void]$ValidationStatusList.Add($objStatus)
                    }

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

                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $null
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                $objStatus.message = $ErrorMessage

                if ($WhatIf) {
                    Write-Warning "$($objStatus.message). Cannot display API request."
                }
                else {
                    [void]$ValidationStatusList.Add($objStatus)
                }

            }
        }

        if (-not $ServerIdsList -and -not $WhatIf -and $ValidationStatusList.Count -gt 0) {
            Return Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
        }

        if ($ServerIdsList) {   
            
            "[{0}] List of server IDs to configure: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServerIdsList | out-string) | Write-Verbose
               
            # Parallel updates
            if ($ParallelInstallations -and -not $ServersList -and -not $OSCompletionTimeoutMin) {

                $data = @{
                    parallel = $True
                }

            }
            elseif ($ParallelInstallations -and $ServersList -and -not $OSCompletionTimeoutMin) {

                $data = @{
                    parallel = $True
                    devices  = $ServerIdsList
                }
            
            }
            elseif ($ParallelInstallations -and -not $ServersList -and $OSCompletionTimeoutMin) {

                $data = @{
                    parallel               = $True
                    osCompletionTimeoutMin = $OSCompletionTimeoutMin
                }
            }
            elseif ($ParallelInstallations -and $ServersList -and $OSCompletionTimeoutMin) {
                
                $data = @{
                    parallel               = $True
                    osCompletionTimeoutMin = $OSCompletionTimeoutMin
                    devices                = $ServerIdsList

                }
            }

            # Serial updates
            elseif (-not $ParallelInstallations -and -not $ServersList -and -not $OSCompletionTimeoutMin) {
            
                $data = @{
                    parallel      = $False
                    stopOnFailure = $StopOnFailureValue
                   
                }
            
            }
            elseif (-not $ParallelInstallations -and $ServersList -and -not $OSCompletionTimeoutMin) {
           
                $data = @{
                    parallel      = $False
                    stopOnFailure = $StopOnFailureValue
                    devices       = $ServerIdsList
                }

            }
            elseif (-not $ParallelInstallations -and $ServersList -and $OSCompletionTimeoutMin) {
           
                $data = @{
                    parallel               = $False
                    stopOnFailure          = $StopOnFailureValue
                    devices                = $ServerIdsList
                    osCompletionTimeoutMin = $OSCompletionTimeoutMin

                }

            }
            elseif (-not $ParallelInstallations -and -not $ServersList -and $OSCompletionTimeoutMin) {
           
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

                    if (-not $WhatIf) {
                        $_resp = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs"
                    }

                }
            }
            catch {

                if (-not $WhatIf) {

                    $PSCmdlet.ThrowTerminatingError($_)

                }
            }  

            if (-not $WhatIf ) {
                if ($ValidationStatusList.Count -gt 0) {
                    $AllResults = [System.Collections.ArrayList]::new()
                    $ValidationStatusList | ForEach-Object { [void]$AllResults.Add($_) }
                    [void]$AllResults.Add($_resp)
                    Return (Invoke-RepackageObjectWithType -RawObject $AllResults -ObjectName "COM.Jobs.Status")
                }
                Return (Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs.Status")
            }

        }
    }
}

function Invoke-HPECOMGroupServerBiosConfiguration {
    <#
    .SYNOPSIS
    Initiate a server group bios configuration.
    
    .DESCRIPTION   
    This cmdlet initiates a server group bios configuration that will affect some or all of the server group members.

    Note: A server reboot is necessary for the new BIOS settings to take effect. COM will attempt to restart the server automatically. If the server cannot be restarted by COM, you must manually reboot the server (or use 'Restart-HPECOMserver') to complete the configuration process.

    Note: If an approval policy is active for this group, this operation may require approval before the job executes.
          Use 'Get-HPECOMApprovalRequest -State PENDING' to check for pending requests and 'Resolve-HPECOMApprovalRequest' to approve or decline.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the group is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
        
    .PARAMETER GroupName
    Name of the group on which the bios configuration will be performed.     
    
    .PARAMETER ServerSerialNumber
    (Optional) Specifies the serial number of an individual server to configure its BIOS settings within the group. If not specified, the BIOS configuration will be performed on all servers in the group.

    .PARAMETER ParallelConfigurations
    Specifies to perform the bios configuration to each server in the group in parallel (20 max) instead of serial by default. 

    .PARAMETER ResetBiosSettingsToDefaults
    Specifies to perform a reset server's BIOS settings to default values before applying the BIOS setting.
    
    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties). By default, the Cmdlet will wait for the job to complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Invoke-HPECOMGroupServerBiosConfiguration -Region eu-central -GroupName ESXi_800

    This command initiates a server group bios configuration of all servers in a group named `ESXi_800` located in the `eu-central` region.

    .EXAMPLE
    Invoke-HPECOMGroupServerBiosConfiguration -Region eu-central -GroupName ESXi_800 -ResetBiosSettingsToDefaults -ParallelConfigurations

    This command initiates a server group bios configuration of all servers in a group named `ESXi_800` located in the `eu-central` region.
    The configuration is performed in parallel instead of serial by default, and the server's BIOS settings are reset to default values before applying the new BIOS settings.

    .EXAMPLE
    Invoke-HPECOMGroupServerBiosConfiguration -Region eu-central -GroupName ESXi_800 -ServerSerialNumber 'CZ12312312' 

    This command initiates a server group bios configuration of the server with the serial number 'CZ12312312' as part of the 'ESXi_800' group located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name "ESX-1" | Invoke-HPECOMGroupServerBiosConfiguration -GroupName ESXi_800

    This command initiates a server group bios configuration of the server named 'ESX-1' as part of the 'ESXi_800' group located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central | Where-Object {$_.serialNumber -eq "CZ12312312" -or $_.serialNumber -eq "DZ12312312"}  | Invoke-HPECOMGroupServerBiosConfiguration -GroupName ESXi_800 -Async
     
    The first command retrieves a list of all servers in the 'eu-central' region.
    The second command filters the list to include only the servers with serial numbers 'CZ12312312' or 'DZ12312312'.
    The last command initiates a server group bios configuration of the specified servers as part of the 'ESXi_800' group.
    The configuration runs asynchronously, allowing other tasks to continue without waiting for completion.
       
    .EXAMPLE
    "CZ12312312", "DZ12312312" | Invoke-HPECOMGroupServerBiosConfiguration -Region eu-central -GroupName ESXi_800 
    
    This command initiates a server group bios configuration of the servers with serial numbers 'CZ12312312' and 'DZ12312312' as part of the 'ESXi_800' group located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central | ForEach-Object { $_ | Invoke-HPECOMGroupServerBiosConfiguration }
    
    This command retrieves a list of all groups in the 'eu-central' region and initiates a server group bios configuration for each group.
    
    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.

    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer' or 'Get-HPECOMGroup -ShowMembers'.

    .OUTPUTS
    HPEGreenLake.COM.Jobs [System.Management.Automation.PSCustomObject]

        - If the -Async switch is used, the cmdlet returns the job resource immediately, allowing you to monitor
          its progress using the `state` and `resultCode` properties, or by passing the job object to
          `Wait-HPECOMJobComplete` for blocking/waiting behavior.

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

    #>

    [CmdletBinding()]
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
                
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String]$GroupName,
        
        [Parameter (ValueFromPipeline, ValueFromPipelineByPropertyName)] 
        [Alias('ServerSerialNumber', 'serial', 'serialnumber')]
        [ValidateNotNullOrEmpty()]
        [String]$ServerName,

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

        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $Uri = Get-COMJobsUri

        $ServersList = [System.Collections.ArrayList]::new()
        $ServerIdsList = [System.Collections.ArrayList]::new()
        $ValidationStatusList = [System.Collections.ArrayList]::new()


    }
    
    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        if ($ServerName -and $ServerName -notmatch '^@\{.*\}$') {

            [void]$ServersList.add($ServerName)
        }

    }

    End {

        try {
            $_group = Get-HPECOMGroup -Region $Region -Name $GroupName
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if (-not $_group) {

            $ErrorMessage = "Group '{0}' cannot be found in the '{1}' region!" -f $GroupName, $Region

            if ($WhatIf) {
                Write-Warning  "$ErrorMessage. Cannot display API request."
                Return
            }
            else {
                $_resp = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $ErrorMessage
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                [void]$ValidationStatusList.Add($_resp)
                Return Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
            }
        }

        $GroupMembers = $_group.devices
        $_groupName = $_group.name
        $_groupResourceUri = $_group.resourceUri
        $_groupId = $_group.id
        $NbOfServers = $_group.devices.count

        "[{0}] GroupName '{1}' detected - URI: '{2}' - Nb of servers: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_groupName, $_groupResourceUri, $NbOfServers | Write-Verbose

        
        try {
            
            $Servers = Get-HPECOMServer -Region $Region
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }
        

        
        
        if ($ServersList) {

            "[{0}] List of servers to configure: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServersList | out-string) | Write-Verbose

            foreach ($Object in $ServersList) {

                $Server = $Servers | Where-Object { $_.name -eq $Object -or $_.host.hostname -eq $Object -or $_.hardware.serialNumber -eq $Object }

                if (-not $Server) {

                    $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Object

                    $objStatus = [PSCustomObject]@{
                        state              = "WARNING"
                        resultCode         = "FAILURE"
                        status             = "Warning"
                        message            = $null
                        duration           = '00:00:00'
                        associatedResource = $Object
                        region             = $Region
                    }
                    $objStatus.message = $ErrorMessage

                    if ($WhatIf) {
                        Write-Warning "$($objStatus.message). Cannot display API request."
                    }
                    else {
                        [void]$ValidationStatusList.Add($objStatus)
                    }

                }
                elseif (-not ($GroupMembers | Where-Object serial -eq $Server.hardware.serialNumber)) {

                    $ErrorMessage = "Server '{0}': Resource is not a member of '{1}' group!" -f $Object, $GroupName

                    $objStatus = [PSCustomObject]@{
                        state              = "WARNING"
                        resultCode         = "FAILURE"
                        status             = "Warning"
                        message            = $null
                        duration           = '00:00:00'
                        associatedResource = $Object
                        region             = $Region
                    }
                    $objStatus.message = $ErrorMessage

                    if ($WhatIf) {
                        Write-Warning "$($objStatus.message). Cannot display API request."
                    }
                    else {
                        [void]$ValidationStatusList.Add($objStatus)
                    }

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

                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $null
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                $objStatus.message = $ErrorMessage

                if ($WhatIf) {
                    Write-Warning "$($objStatus.message). Cannot display API request."
                }
                else {
                    [void]$ValidationStatusList.Add($objStatus)
                }

            }
        }

        if (-not $ServerIdsList -and -not $WhatIf -and $ValidationStatusList.Count -gt 0) {
            Return Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
        }

        if ($ServerIdsList) {

            "[{0}] List of server IDs to configure: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServerIdsList | out-string) | Write-Verbose


            # Parallel updates
            if ($ParallelConfigurations -and -not $ServersList) {

                $data = @{
                    batch_size        = 20
                    redfish_subsystem = "BIOS"
                }

            }
            elseif ($ParallelConfigurations -and $ServersList) {

                $data = @{
                    batch_size        = 20
                    devices           = $ServerIdsList
                    redfish_subsystem = "BIOS"
                }
            
            }

            # Serial updates
            elseif (-not $ParallelConfigurations -and -not $ServersList) {
            
                $data = @{
                    batch_size        = 1
                    redfish_subsystem = "BIOS"
                   
                }
            
            }
            elseif (-not $ParallelConfigurations -and $ServersList) {
           
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

                    if (-not $WhatIf) {
                        $_resp = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs"
                    }

                }
            }
            catch {

                if (-not $WhatIf) {

                    $PSCmdlet.ThrowTerminatingError($_)

                }
            }  

            if (-not $WhatIf ) {
                if ($ValidationStatusList.Count -gt 0) {
                    $AllResults = [System.Collections.ArrayList]::new()
                    $ValidationStatusList | ForEach-Object { [void]$AllResults.Add($_) }
                    [void]$AllResults.Add($_resp)
                    Return (Invoke-RepackageObjectWithType -RawObject $AllResults -ObjectName "COM.Jobs.Status")
                }
                Return (Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs.Status")
            }

        }
    }
}

function Invoke-HPECOMGroupServeriLOConfiguration {
    <#
    .SYNOPSIS
    Initiate a server group iLO configuration.

    .DESCRIPTION
    This cmdlet initiates a server group iLO configuration that will affect some or all of the server group members.

    Note: If an approval policy is active for this group, this operation may require approval before the job executes.
          Use 'Get-HPECOMApprovalRequest -State PENDING' to check for pending requests and 'Resolve-HPECOMApprovalRequest' to approve or decline.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the group is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
        
    .PARAMETER GroupName
    Name of the group on which the iLO configuration will be performed.

    .PARAMETER ServerSerialNumber
    (Optional) Specifies the serial number of an individual server to configure its iLO settings within the group. If not specified, the iLO configuration will be performed on all servers in the group.

    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties). By default, the Cmdlet will wait for the job to complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Invoke-HPECOMGroupServeriLOConfiguration -Region eu-central -GroupName ESXi_800

    This command initiates a server group iLO configuration of all servers in a group named `ESXi_800` located in the `eu-central` region.
    
    .EXAMPLE
    Invoke-HPECOMGroupServeriLOConfiguration -Region eu-central -GroupName ESXi_800 -ServerSerialNumber 'CZ12312312'
    
    This command initiates a server group iLO configuration of the server with the serial number 'CZ12312312' as part of the 'ESXi_800' group located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name "ESX-1" | Invoke-HPECOMGroupServeriLOConfiguration -GroupName ESXi_800

    This command initiates a server group iLO configuration of the server named 'ESX-1' as part of the 'ESXi_800' group located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -Name "AI_Group" -ShowMembers | Invoke-HPECOMGroupServeriLOConfiguration -GroupName AI_Group

    This command retrieves a list of all servers in the 'AI_Group' group located in the `eu-central` region and initiates a server group iLO configuration for each server.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.

    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer' or 'Get-HPECOMGroup -ShowMembers'.

    .OUTPUTS
    HPEGreenLake.COM.Jobs [System.Management.Automation.PSCustomObject]

        - If the -Async switch is used, the cmdlet returns the job resource immediately, allowing you to monitor
          its progress using the `state` and `resultCode` properties, or by passing the job object to
          `Wait-HPECOMJobComplete` for blocking/waiting behavior.

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

    #>

    [CmdletBinding()]
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
                
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String]$GroupName,
        
        [Parameter (ValueFromPipeline, ValueFromPipelineByPropertyName)] 
        [Alias('ServerSerialNumber', 'serial', 'serialnumber')]
        [ValidateNotNullOrEmpty()]
        [String]$ServerName,

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
        $ValidationStatusList = [System.Collections.ArrayList]::new()

        $Uri = Get-COMJobsUri

    }
    
    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        if ($ServerName -and $ServerName -notmatch '^@\{.*\}$') {
            [void]$ServersList.add($ServerName)
        }

    }

    End {

        try {
            $_group = Get-HPECOMGroup -Region $Region -Name $GroupName
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if (-not $_group) {

            $ErrorMessage = "Group '{0}' cannot be found in the '{1}' region!" -f $GroupName, $Region

            if ($WhatIf) {
                Write-Warning  "$ErrorMessage. Cannot display API request."
                Return
            }
            else {
                $_resp = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $ErrorMessage
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                [void]$ValidationStatusList.Add($_resp)
                Return Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
            }
        }

        $GroupMembers = $_group.devices
        $_groupName = $_group.name
        $_groupResourceUri = $_group.resourceUri
        $_groupId = $_group.id
        $NbOfServers = $_group.devices.count

        "[{0}] GroupName '{1}' detected - URI: '{2}' - Nb of servers: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_groupName, $_groupResourceUri, $NbOfServers | Write-Verbose
        
        try {
            $Servers = Get-HPECOMServer -Region $Region
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }
        
        if ($ServersList) {

            "[{0}] List of servers to configure: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServersList | out-string) | Write-Verbose

            foreach ($Object in $ServersList) {

                $Server = $Servers | Where-Object { $_.name -eq $Object -or $_.host.hostname -eq $Object -or $_.hardware.serialNumber -eq $Object }
    
                if (-not $Server) {

                    $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Object

                    $objStatus = [PSCustomObject]@{
                        state              = "WARNING"
                        resultCode         = "FAILURE"
                        status             = "Warning"
                        message            = $null
                        duration           = '00:00:00'
                        associatedResource = $Object
                        region             = $Region
                    }
                    $objStatus.message = $ErrorMessage

                    if ($WhatIf) {
                        Write-Warning "$($objStatus.message). Cannot display API request."
                    }
                    else {
                        [void]$ValidationStatusList.Add($objStatus)
                    }

                }
                elseif (-not ($GroupMembers | Where-Object serial -eq $Server.hardware.serialNumber)) {

                    $ErrorMessage = "Server '{0}': Resource is not a member of '{1}' group!" -f $Object, $GroupName

                    $objStatus = [PSCustomObject]@{
                        state              = "WARNING"
                        resultCode         = "FAILURE"
                        status             = "Warning"
                        message            = $null
                        duration           = '00:00:00'
                        associatedResource = $Object
                        region             = $Region
                    }
                    $objStatus.message = $ErrorMessage

                    if ($WhatIf) {
                        Write-Warning "$($objStatus.message). Cannot display API request."
                    }
                    else {
                        [void]$ValidationStatusList.Add($objStatus)
                    }

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

                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $null
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                $objStatus.message = $ErrorMessage

                if ($WhatIf) {
                    Write-Warning "$($objStatus.message). Cannot display API request."
                }
                else {
                    [void]$ValidationStatusList.Add($objStatus)
                }

            }
        }

        if (-not $ServerIdsList -and -not $WhatIf -and $ValidationStatusList.Count -gt 0) {
            Return Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
        }

        if ($ServerIdsList) {

            "[{0}] List of server IDs to configure: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ServerIdsList | out-string) | Write-Verbose

            if ($ServersList) {
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

                    if (-not $WhatIf) {
                        $_resp = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs"
                    }

                }

                # Set associatedResource to group name
                if ($_resp.PSObject.Properties.Name -notcontains 'associatedResource') {
                    $_resp | Add-Member -Type NoteProperty -Name associatedResource -Value $GroupName -Force
                }
                else {
                    $_resp.associatedResource = $GroupName
                }
            }
            catch {

                if (-not $WhatIf) {

                    $PSCmdlet.ThrowTerminatingError($_)

                }
            }  

            if (-not $WhatIf ) {
                if ($ValidationStatusList.Count -gt 0) {
                    $AllResults = [System.Collections.ArrayList]::new()
                    $ValidationStatusList | ForEach-Object { [void]$AllResults.Add($_) }
                    [void]$AllResults.Add($_resp)
                    Return (Invoke-RepackageObjectWithType -RawObject $AllResults -ObjectName "COM.Jobs.Status")
                }
                Return (Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs.Status")
            }

        }
    }
}

function Invoke-HPECOMGroupServeriLOConfigurationCompliance {
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
    (Optional) Specifies the serial number of an individual server to retrieve its specific compliance details within the group. If not specified, the compliance check will be performed on all servers in the group.

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
    Invoke-HPECOMGroupServeriLOConfigurationCompliance -Region eu-central -GroupName ESX-800 -ServerSerialNumber CZ12312312 

    This command initiates an immediate iLO configuration compliance check for the server with serial number 'CZ12312312' in the group 'ESX-800' in the 'eu-central' region.

    .EXAMPLE
    Invoke-HPECOMGroupServeriLOConfigurationCompliance -Region eu-central -GroupName ESX-800 -ServerSerialNumber CZ12312312 -ScheduleTime (Get-Date).AddDays(7) -Interval P1M  

    This command schedules a one-time iLO configuration compliance check for the server with serial number 'CZ12312312' in the group 'ESX-800' in the 'eu-central' region, to be executed 7 days from now and repeated every month.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -Name "AI_Group" -ShowMembers | Invoke-HPECOMGroupServeriLOConfigurationCompliance -GroupName AI_Group

    This command initiates an immediate iLO configuration compliance check for all servers in the group 'AI_Group' in the 'eu-central' region.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -Name "AI_Group" | Invoke-HPECOMGroupServeriLOConfigurationCompliance -ServerSerialNumber CZ12312312 

    This command initiates an immediate iLO configuration compliance check for the server with serial number 'CZ12312312' in the group 'AI_Group' in the 'eu-central' region.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the group's name or server's name.

    System.Collections.ArrayList
        List of groups from 'Get-HPECOMGroup'.
        List of servers from 'Get-HPECOMServer' or 'Get-HPECOMGroup -ShowMembers'.

    .OUTPUTS
    HPEGreenLake.COM.Jobs [System.Management.Automation.PSCustomObject]

        - If the -Async switch is used, the cmdlet returns the job resource immediately, allowing you to monitor
          its progress using the `state` and `resultCode` properties, or by passing the job object to
          `Wait-HPECOMJobComplete` for blocking/waiting behavior.

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

    HPEGreenLake.COM.Schedules [System.Management.Automation.PSCustomObject]

        - The schedule job object that includes the schedule details when `-ScheduleTime` is used.


    #>

    [CmdletBinding(DefaultParameterSetName = "Async")]
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
        
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String]$GroupName,

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('ServerSerialNumber', 'serial', 'serialnumber')]
        [ValidateNotNullOrEmpty()]
        [String]$ServerName,

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

            $_group = Get-HPECOMGroup -Region $Region -Name $GroupName -WarningAction SilentlyContinue
            if ($_group) {
                $_groupMembers = Get-HPECOMGroup -Region $Region -Name $GroupName -ShowMembers -WarningAction SilentlyContinue
                $_server = $_groupMembers | Where-Object { $_.serialNumber -eq $ServerName -or $_.serverName -eq $ServerName}
            }

            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
        
        if (-not $_group) {
        
            # Must return a message if resource not found
            $ErrorMessage = "Group '{0}' cannot be found in the '{1}' region!" -f $GroupName, $Region
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

            if ($WhatIf) {
                Write-Warning  "$ErrorMessage. Cannot display API request."
                return
            }

            $_resp = [PSCustomObject]@{
                state              = "WARNING"
                resultCode         = "FAILURE"
                status             = "Warning"
                message            = $ErrorMessage
                duration           = '00:00:00'
                associatedResource = $GroupName
                region             = $Region
            }
            [void]$GroupiLOSettingsComplianceStatus.add($_resp)
            return
        }
        elseif (-not $_server) {

            # Must return a message if resource not found
            $ErrorMessage = "Server '{0}' cannot be found in the '{1}' group!" -f $ServerName, $GroupName
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

            if ($WhatIf) {
                Write-Warning  "$ErrorMessage. Cannot display API request."
                return
            }

            $_resp = [PSCustomObject]@{
                state              = "WARNING"
                resultCode         = "FAILURE"
                status             = "Warning"
                message            = $ErrorMessage
                duration           = '00:00:00'
                associatedResource = $ServerName
                region             = $Region
            }
            [void]$GroupiLOSettingsComplianceStatus.add($_resp)
            return

        }
        else {
            
            $_ResourceUri = $_server.deviceUri
            $_GroupId = $_group.id
            $NbOfServers = $_group.devices.count

            "[{0}] GroupName '{1}' and server '{2}' detected - URI: '{3}' - Nb of servers in group: '{4}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GroupName, $ServerName, $_ResourceUri, $NbOfServers | Write-Verbose

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

                        if (-not $WhatIf) {
                            $ReturnData = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs"
                        }

                    }
                }

            }
            catch {

                if (-not $WhatIf) {

                    $PSCmdlet.ThrowTerminatingError($_)

                }
            }  

            if ($ScheduleTime -or $Async) {

                if (-not $WhatIf ) {
        
                    Return $ReturnData
                
                }
            }
        }

        if (-not $ScheduleTime -and -not $Async -and -not $WhatIf) {

            [void] $GroupiLOSettingsComplianceStatus.add($_resp)
        }


    }

    End {

        if (-not $ScheduleTime -and -not $Async -and -not $WhatIf ) {

            $GroupiLOSettingsComplianceStatus = Invoke-RepackageObjectWithType -RawObject $GroupiLOSettingsComplianceStatus -ObjectName "COM.Jobs.Status"

            Return $GroupiLOSettingsComplianceStatus

        }

    }
}

function Get-HPECOMGroupServeriLOConfigurationCompliance {
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
    (Optional) Specifies the serial number of an individual server to retrieve its specific compliance details within the group. If not specified, the compliance check will be performed on all servers in the group.

    .PARAMETER ShowDeviations
    Switch parameter that retrieves only the iLO configuration components which have deviations from the group's iLO settings.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMGroupServeriLOConfigurationCompliance -Region eu-central -GroupName ESX-800 -ServerSerialNumber CZ12312312 

    This command returns the iLO configuration compliance of the server with serial number 'CZ12312312' in the group 'ESX-800' in the 'eu-central' region.

    .EXAMPLE
    Get-HPECOMGroupServeriLOConfigurationCompliance -Region eu-central -GroupName ESX-800 -ServerSerialNumber CZ12312312 -ShowDeviations

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
        
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String]$GroupName,

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('ServerSerialNumber', 'serial', 'serialnumber')]
        [ValidateNotNullOrEmpty()]
        [String]$ServerName,

        [switch]$ShowDeviations,

        [switch]$WhatIf

    )

        Begin {
  
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
      
      
    }
            
    Process {
      
        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose      

        try {

            $_allGroups = Invoke-HPECOMWebRequest -Method Get -Uri (Get-COMGroupsUri) -Region $Region
            $_group = @($_allGroups) | Where-Object { $_.name -ieq $GroupName } | Select-Object -First 1
            $GroupID = $_group.id

            "[{0}] ID found for group '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GroupName, $GroupID | Write-Verbose

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
            # groupName is used in Invoke-HPECOMGroupServerInternalStorageConfiguration, Update-HPECOMGroupServerFirmware, etc. 
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
                        
            if ($ServerName) {

                if ($ShowDeviations) {
                    $CollectionList = $CollectionList | Where-Object { $_.serial -eq $ServerName -or $_.serverName -eq $ServerName } | ForEach-Object deviations | Sort-Object -Property category, settingName
                    $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "COM.Groups.iLO.Compliance.Deviations"   
                }
                else {
                    $CollectionList = $CollectionList | Where-Object { $_.serial -eq $ServerName -or $_.serverName -eq $ServerName }
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

function Invoke-HPECOMGroupServerExternalStorageConfiguration {
    <#
    .SYNOPSIS
    Initiate a server group external storage configuration.
    
    .DESCRIPTION   
    This cmdlet initiates a server group external storage configuration that will affect all server group members.

    Note: If an approval policy is active for this group, this operation may require approval before the job executes.
          Use 'Get-HPECOMApprovalRequest -State PENDING' to check for pending requests and 'Resolve-HPECOMApprovalRequest' to approve or decline.
    
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
    Invoke-HPECOMGroupServerExternalStorageConfiguration -Region eu-central -GroupName ESXi_800

    This command initiates a server group external storage configuration of all servers in a group named `ESXi_800` located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central | ForEach-Object { $_ | Invoke-HPECOMGroupServerExternalStorageConfiguration } 
    
    This command retrieves a list of all groups in the 'eu-central' region and initiates a server group external storage configuration for each group.
    
    .INPUTS
    No pipeline input is supported

    .OUTPUTS
    HPEGreenLake.COM.Jobs [System.Management.Automation.PSCustomObject]

        - If the -Async switch is used, the cmdlet returns the job resource immediately, allowing you to monitor
          its progress using the `state` and `resultCode` properties, or by passing the job object to
          `Wait-HPECOMJobComplete` for blocking/waiting behavior.

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

    #>

    [CmdletBinding()]
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
                
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
        [ValidateNotNullOrEmpty()]
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
        $ValidationStatusList = [System.Collections.ArrayList]::new()
                
    }
    
    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

    }

    End {
      
        try {
            $_group = Get-HPECOMGroup -Region $Region -Name $GroupName
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if (-not $_group) {

            $ErrorMessage = "Group '{0}' cannot be found in the '{1}' region!" -f $GroupName, $Region

            if ($WhatIf) {
                Write-Warning  "$ErrorMessage. Cannot display API request."
                Return
            }
            else {
                $_resp = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $ErrorMessage
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                [void]$ValidationStatusList.Add($_resp)
                Return Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
            }
        }

        $GroupMembers = $_group.devices
        $_groupName = $_group.name
        $_groupResourceUri = $_group.resourceUri
        $_groupId = $_group.id
        $NbOfServers = $_group.devices.count

        "[{0}] GroupName '{1}' detected - URI: '{2}' - Nb of servers: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_groupName, $_groupResourceUri, $NbOfServers | Write-Verbose

        if (-not $GroupMembers) {

            # Must return a message if no server members are found in the group
            $ErrorMessage = "Group '{0}' has no members to be configured!" -f $GroupName

            $objStatus = [PSCustomObject]@{
                state              = "WARNING"
                resultCode         = "FAILURE"
                status             = "Warning"
                message            = $null
                duration           = '00:00:00'
                associatedResource = $GroupName
                region             = $Region
            }
            $objStatus.message = $ErrorMessage

            if ($WhatIf) {
                Write-Warning "$($objStatus.message). Cannot display API request."
            }
            else {
                [void]$ValidationStatusList.Add($objStatus)
                Return Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
            }
        }
        else {

            # Build payload
            $payload = @{
                jobTemplate  = $JobTemplateId
                resourceId   = $_groupId
                resourceType = "compute-ops-mgmt/group"
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

                    if (-not $WhatIf) {
                        $_resp = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs"
                    }

                }
            }
            catch {

                if (-not $WhatIf) {

                    $PSCmdlet.ThrowTerminatingError($_)

                }
            }

            if (-not $WhatIf) {

                Return $_resp

            }

        }
    }
}

function Invoke-HPECOMGroupServerExternalStorageComplianceCheck {
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
    Invoke-HPECOMGroupServerExternalStorageComplianceCheck -Region eu-central -GroupName ESX-800  

    This command checks the external storage compliance of all servers in the group 'ESX-800' in the 'eu-central' region.
       
    .EXAMPLE
    Get-HPECOMGroup -Region eu-central | Invoke-HPECOMGroupServerExternalStorageComplianceCheck 

    This command checks the external storage compliance of all servers in all groups within the 'eu-central' region.
    
    .EXAMPLE
    Invoke-HPECOMGroupServerExternalStorageComplianceCheck -Region eu-central -GroupName ESX-800 -ScheduleTime (Get-Date).AddHours(1) 

    Schedules the execution of a group external storage compliance check on the group named 'ESX-800' in the `eu-central` region starting 1 hour from now. 
    
    .EXAMPLE
    Get-HPECOMGroup -Region eu-central | Invoke-HPECOMGroupServerExternalStorageComplianceCheck -ScheduleTime (Get-Date).AddDays(1) -Interval P1M 

    Schedules a monthly execution of a group external storage compliance check on all groups within the `eu-central` region. The first execution will occur one day from now.

    .EXAMPLE
    "ESXi_group", "RHEL_group" | Invoke-HPECOMGroupServerExternalStorageComplianceCheck -Region  eu-central
    
    This command checks the external storage compliance of all servers in the groups 'ESXi_group' and 'RHEL_group' in the 'eu-central' region.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the group's names.

    System.Collections.ArrayList
        List of groups from 'Get-HPECOMGroup'.

    .OUTPUTS
    HPEGreenLake.COM.Jobs [System.Management.Automation.PSCustomObject]

        - If the -Async switch is used, the cmdlet returns the job resource immediately, allowing you to monitor
          its progress using the `state` and `resultCode` properties, or by passing the job object to
          `Wait-HPECOMJobComplete` for blocking/waiting behavior.

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

    HPEGreenLake.COM.Schedules [System.Management.Automation.PSCustomObject]

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
        [alias('name')]
        [ValidateNotNullOrEmpty()]
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
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

            if ($WhatIf) {
                Write-Warning  "$ErrorMessage. Cannot display API request."
                Return
            }
            else {
                $_resp = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $ErrorMessage
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                [void]$GroupFirmwareComplianceStatus.Add($_resp)
                Return Invoke-RepackageObjectWithType -RawObject $GroupFirmwareComplianceStatus -ObjectName "COM.Jobs.Status"
            }
            
        }
        else {
            
            $_ResourceUri = $_group.resourceUri
            $_GroupId = $_group.id
            $NbOfServers = $_group.devices.count
            
            "[{0}] GroupName '{1}' detected - URI: '{2}' - Nb of servers: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GroupName, $_ResourceUri, $NbOfServers | Write-Verbose         

            if ($NbOfServers -eq 0) {

                # Must return a message if no servers in group
                $ErrorMessage = "Operation on group '$GroupName' cannot be executed because no server has been found in the group!"
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

                if ($WhatIf) {
                    Write-Warning  "$ErrorMessage. Cannot display API request."
                    Return
                }
                else {
                    $_resp = [PSCustomObject]@{
                        state              = "WARNING"
                        resultCode         = "FAILURE"
                        status             = "Warning"
                        message            = $ErrorMessage
                        duration           = '00:00:00'
                        associatedResource = $GroupName
                        region             = $Region
                    }
                    [void]$GroupFirmwareComplianceStatus.Add($_resp)
                    Return Invoke-RepackageObjectWithType -RawObject $GroupFirmwareComplianceStatus -ObjectName "COM.Jobs.Status"
                }
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

                $payload = @{
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
                    jobTemplate  = $JobTemplateId
                    resourceId   = $_GroupId
                    resourceType = "compute-ops-mgmt/group"
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

                        "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ReturnData | Write-Verbose

                        Return $ReturnData

                    }

                }
                elseif ($Async) {

                    if (-not $WhatIf) {

                        $_resp = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs"

                        Return $_resp

                    }

                }
                else {

                    if (-not $WhatIf) {

                        # Timeout: default timeout x nb of servers found in the group

                        $Timeout = $NbOfServers * $TimeoutinSecondsPerServer 
        
                        "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose
        
                        $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout
    
                        "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose
    
                    }
                }

            }
            catch {

                if (-not $WhatIf) {

                    $PSCmdlet.ThrowTerminatingError($_)

                }
            }  
            
        }

        if (-not $ScheduleTime -and -not $Async -and -not $WhatIf) {

            [void] $GroupFirmwareComplianceStatus.Add($_resp)
        }


    }

    End {

        if (-not $ScheduleTime -and -not $Async -and -not $WhatIf ) {
            
            $GroupFirmwareComplianceStatus = Invoke-RepackageObjectWithType -RawObject $GroupFirmwareComplianceStatus -ObjectName "COM.Jobs.Status"

            Return $GroupFirmwareComplianceStatus
        
        }

    }
}

function Update-HPECOMApplianceFirmware {
    <#
    .SYNOPSIS
    Updates the firmware on a specified appliance.
    
    .DESCRIPTION   
    This cmdlet initiates a firmware update on a specified OneView appliance identified by its IP address or hostname. 
    It also provides options for scheduling the update at a specific time and for waiting until the update job completes.
    
    By default, jobs are submitted and returned immediately without waiting for completion (appliance updates typically take 60-90 minutes). 
    Use -Wait to block until all jobs complete.
    Use -ScheduleTime to schedule the updates for a future date and time.

    Note: Only OneView appliances are supported. 
    Note: GATEWAY appliances cannot be updated using this cmdlet as they are automatically updated by HPE.
          Only OneView appliances (OVE_APPLIANCE_VM and OVE_APPLIANCE_SYNERGY) can be manually updated.
    
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

    .PARAMETER Wait
    By default, this cmdlet returns the job resource immediately without waiting for it to complete (async by default).
    Use this switch to block execution and wait until the firmware update job reaches a terminal state (COMPLETE, ERROR, or STALLED).
    The cmdlet polls the job status and returns the final result only when the job finishes.
    You can also pass the returned job object to 'Wait-HPECOMJobComplete' to perform the wait manually.

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

    .EXAMPLE
    Update-HPECOMApplianceFirmware -Region eu-central -IPAddress 192.168.7.59 -ApplianceFirmwareBundleReleaseVersion 9.00.00 -Wait

    This command updates the firmware on the appliance with IP address `192.168.7.59` and blocks until the update job completes.
    The final job status (COMPLETE, ERROR, or STALLED) is returned once the job reaches a terminal state.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the appliance's IP addresses.

    System.Collections.ArrayList
        List of appliances from 'Get-HPECOMAppliance'.

    .OUTPUTS
    HPEGreenLake.COM.Jobs [System.Management.Automation.PSCustomObject]

        The appliance firmware update job resource, returned both in the default mode and after -Wait completes.
        Key properties include:
        - state: Current job state (RUNNING, PENDING, COMPLETE, ERROR, STALLED)
        - resultCode: Result of the job (SUCCESS, FAILURE)
        - status: Simplified status indicator (e.g., "Complete", "Warning", "Failed")
        - name: Name of the job template used (e.g., "ApplianceFwUpdate")
        - associatedResource: The appliance resource associated with the job
        - date: Date and time when the job was created
        - jobUri: URI of the job resource
        - duration: Time taken for the job to complete
        - message: Any informational or error messages returned by the job
        - region: The COM region code where the job was submitted

    HPEGreenLake.COM.Schedules [System.Management.Automation.PSCustomObject]

        The schedule job object returned when `-ScheduleTime` is used.


    #>

    [CmdletBinding(DefaultParameterSetName = 'Scheduled')]
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
        
        # [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'IP')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateScript({ [String]::IsNullOrEmpty($_) -or $_ -match [Net.IPAddress]$_ })]
        [string]$IPAddress,
        
        [Parameter (Mandatory)]
        [ValidateNotNullOrEmpty()]
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

        [Parameter (ParameterSetName = 'Wait')]
        [switch]$Wait,

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

        # Fetch all running jobs once to detect in-progress appliance firmware updates
        $_AllRunningJobs = @()
        try {
            $_AllRunningJobs = @(Get-HPECOMJob -Region $Region -ShowRunning -Verbose:$false -ErrorAction SilentlyContinue)
        }
        catch {
            "[{0}] Warning: Unable to query running jobs — in-progress check will be skipped. Error: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
        }
        
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
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
            if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request." }

        }
        elseif( $_appliance.applianceType -eq "GATEWAY") {

            $ErrorMessage = "Appliance '{0}' is not a OneView appliance and cannot be updated using this cmdlet!" -f $IPAddress
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
            if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request." }

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

                $ErrorMessage = "The appliance firmware bundle release version '{0}' cannot be found in the '{1}' region!" -f $ApplianceFirmwareBundleReleaseVersion, $Region
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request." }
    
            }
            else {

                # Check bundle is in the supported upgrade paths
                $SupportedUpgrades = Get-HPECOMApplianceFirmwareBundle -Region $Region -Version $ApplianceFirmwareBundleReleaseVersion -Type $_applianceType -SupportedUpgrades

                if ($SupportedUpgrades -notcontains $_applianceVersion) {

                    $ErrorMessage = "The appliance firmware bundle release version '{0}' is not in the supported upgrade paths for appliance '{1}' with current firmware version '{2}'!" -f $ApplianceFirmwareBundleReleaseVersion, $IPAddress, $_applianceVersion
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                    if ($WhatIf) { Write-Warning "$ErrorMessage Cannot display API request." }

                }
                else {

                # Skip if a firmware update job is already running for this appliance
                if ($_AllRunningJobs) {
                    $_existingRunningJob = $_AllRunningJobs | Where-Object {
                        $_.name -eq $_JobTemplateName -and $_.resource.id -like "*$_applianceDeviceID*"
                    } | Select-Object -First 1
                    if ($_existingRunningJob) {
                        $_msg = "Appliance '{0}' already has a running firmware update job ('{1}'). Skipping to avoid conflict." -f $_applianceName, $_existingRunningJob.resourceUri
                        "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_msg | Write-Verbose
                        if ($WhatIf) { Write-Warning "$_msg Cannot display API request." }
                        else {
                            $objStatus = [PSCustomObject]@{
                                state              = "WARNING"
                                resultCode         = "SKIPPED"
                                status             = "Warning"
                                message            = $_msg
                                duration           = '00:00:00'
                                associatedResource = $_applianceName
                                name               = $_JobTemplateName
                                date               = "$((Get-Date).ToString())"
                                jobUri             = $_existingRunningJob.resourceUri
                                region             = $Region
                            }
                            [void] $ApplianceFWUpdateStatus.add($objStatus)
                        }
                        return
                    }
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
    
    
                    $payload = @{
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

                        if (-not $WhatIf -and $Wait) {

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
                } # closes supported upgrade path else block
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

function Update-HPECOMGroupApplianceFirmware {
    <#
    .SYNOPSIS
    Updates the appliance software of OneView appliances in an OVE appliance group.
    
    .DESCRIPTION   
    This cmdlet updates the appliance software for some or all OneView appliances that are members of an OVE appliance group within a specified region.

    The target firmware version is determined by the OneView appliance software setting configured in the group. The group must have a OneView appliance software setting assigned before updates can be submitted.
    
    A separate update job is submitted for each targeted appliance. The cmdlet performs the following steps before submitting any job:
    - Displays an upfront summary of all targeted appliances with their current and target versions, flagging any that will be skipped.
    - Automatically skips appliances that are already running the target version (no update needed).
    - Automatically skips appliances that already have a firmware update job in RUNNING or PENDING state, to avoid submitting a conflicting duplicate job. A warning is issued for each skipped appliance.
    - Reminds you to create a backup of the appliance and to run the HPE OneView Update Readiness Checker (https://www.hpe.com/support/ov-urc) to verify that the environment is ready for the update.
    - Prompts for confirmation per appliance: [Y] Yes, [N] No (abort all), or [S] Skip this appliance.
    
    By default, jobs are submitted and returned immediately without waiting for completion (appliance updates typically take 60-90 minutes). Use -Wait to block until all jobs complete.
    Use -Force to suppress the interactive prompt and update all targeted appliances automatically.
    Use -ScheduleTime to schedule the updates for a future date and time.
    
    Note: Only groups with deviceType 'OVE_APPLIANCE_VM' or 'OVE_APPLIANCE_SYNERGY' are supported.
    Note: GATEWAY appliances cannot be updated using this cmdlet.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the group is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER GroupName
    Name of the OVE appliance group whose member appliances will be updated.
    Only groups with deviceType 'OVE_APPLIANCE_VM' or 'OVE_APPLIANCE_SYNERGY' are supported.

    .PARAMETER ApplianceName
    (Optional) Specifies the name (hostname or IP address) of a specific appliance to update within the group.

    If not specified, the update is applied to all member appliances in the group.

    .PARAMETER ScheduleTime
    Specifies the date and time when the appliance firmware updates should be executed. 
    This parameter accepts a DateTime object or a string representation of a date and time. 
    If not specified, the updates will be executed immediately.

    Examples for setting the date and time using `Get-Date`:
    - (Get-Date).AddMonths(6)
    - (Get-Date).AddDays(15)
    - (Get-Date).AddHours(3)
    Example for using a specific date string:
    - "2024-05-20 08:00:00"

    .PARAMETER Force
    When specified, suppresses the per-appliance interactive confirmation prompt (Yes/No/Skip) and proceeds with all updates automatically.

    .PARAMETER Wait
    When specified, the cmdlet blocks until each submitted job completes and returns detailed job status objects.
    By default (without -Wait), jobs are submitted and the job resource objects are returned immediately so you can monitor progress independently using 'Wait-HPECOMJobComplete', 'Get-HPECOMJob' or 'Get-HPECOMAppliance -Region eu-central -Name "<applianceName>" -ShowJobs'.
    Note: Appliance firmware updates typically take 60-90 minutes. Using -Wait will block your session for the duration.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Update-HPECOMGroupApplianceFirmware -Region eu-central -GroupName OVE_Synergy_Group

    This command updates the appliance software for all appliances in the 'OVE_Synergy_Group' group located in the 'eu-central' region using the firmware bundle version defined in the group's OneView appliance software setting.
    Before each update, you will be prompted to confirm with [Y] Yes, [N] No (abort all), or [S] Skip.

    .EXAMPLE
    Update-HPECOMGroupApplianceFirmware -Region eu-central -GroupName OVE_Synergy_Group -Force

    This command updates the appliance software for all appliances in the 'OVE_Synergy_Group' group without prompting for confirmation.

    .EXAMPLE
    Update-HPECOMGroupApplianceFirmware -Region eu-central -GroupName OVE_Synergy_Group -ApplianceName "composer.domain.lab"
    Get-HPECOMAppliance -Region eu-central -Name "composer.domain.lab" -ShowJobs

    These commands update only the appliance 'composer.domain.lab' in the 'OVE_Synergy_Group' group located in the 'eu-central' region and monitors the job progress.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Name "composer.domain.lab" | Update-HPECOMGroupApplianceFirmware -GroupName OVE_Synergy_Group

    This command retrieves the appliance 'composer.domain.lab' and pipes it to update its firmware within the 'OVE_Synergy_Group' group.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -Name OVE_Synergy_Group -ShowMembers | Update-HPECOMGroupApplianceFirmware -GroupName OVE_Synergy_Group -Force

    This command retrieves all appliance members in the 'OVE_Synergy_Group' group and updates their firmware without prompting.

    .EXAMPLE
    Update-HPECOMGroupApplianceFirmware -Region eu-central -GroupName OVE_Synergy_Group -ScheduleTime ((Get-Date).AddDays(5))

    This command schedules appliance software updates for all appliances in the 'OVE_Synergy_Group' group, starting 5 days from now.

    .EXAMPLE
    Update-HPECOMGroupApplianceFirmware -Region eu-central -GroupName OVE_VM_Group

    This command submits appliance software update jobs for all appliances in the 'OVE_VM_Group' group and returns the job objects immediately for monitoring (default behavior).

    .EXAMPLE
    Update-HPECOMGroupApplianceFirmware -Region eu-central -GroupName OVE_VM_Group -Wait -Force

    This command updates all appliances in the 'OVE_VM_Group' group without prompting and blocks until every job completes, returning detailed status objects.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing appliance names (hostnames or IP addresses).

    System.Collections.ArrayList
        List of appliances from 'Get-HPECOMAppliance' or 'Get-HPECOMGroup -ShowMembers'.

    .OUTPUTS
    HPEGreenLake.COM.Jobs [System.Management.Automation.PSCustomObject]

        - By default, the cmdlet returns job resource objects immediately after submission (one per appliance), including:
            - `state` / `resultCode`: current job state (PENDING/RUNNING initially)
            - `resourceUri`: URI you can pass to 'Wait-HPECOMJobComplete' or 'Get-HPECOMJob'
            - `region`: region where the job was submitted

    HPEGreenLake.COM.Jobs.Status [System.Management.Automation.PSCustomObject]

        - When `-Wait` is specified, the cmdlet blocks until each job finishes and returns detailed status objects:
            - `state`: COMPLETE, ERROR, or STALLED
            - `resultCode`: SUCCESS or FAILURE
            - `associatedResource`, `date`, `jobUri`, `duration`, `message`, `details`

    HPEGreenLake.COM.Schedules [System.Management.Automation.PSCustomObject]

        - The schedule job object(s) that include schedule details when `-ScheduleTime` is used.

    #>

    [CmdletBinding(DefaultParameterSetName = 'Scheduled')]
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
                
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String]$GroupName,

        [Parameter (ValueFromPipeline, ValueFromPipelineByPropertyName)] 
        [Alias('name', 'IPAddress')]
        [ValidateNotNullOrEmpty()]
        [String]$ApplianceName,

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

        [switch]$Force,

        [Parameter (ParameterSetName = 'Wait')]
        [switch]$Wait,

        [switch]$WhatIf

    )

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $_JobTemplateName = 'ApplianceUpdate'

        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $JobsUri = Get-COMJobsUri
        $SchedulesUri = Get-COMSchedulesUri

        $ApplianceNamesList = [System.Collections.ArrayList]::new()
        $StatusList = [System.Collections.ArrayList]::new()
        $ScheduleResultsList = [System.Collections.ArrayList]::new()
        $JobResultsList = [System.Collections.ArrayList]::new()
        $ValidationStatusList = [System.Collections.ArrayList]::new()

        $Timeout = 7200  # 2 hours per appliance (updates typically take 60-90 min)

    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Collect ApplianceName input; ignore hashtable-like strings injected by the pipeline framework
        if ($ApplianceName -and $ApplianceName -notmatch '^@\{.*\}$') {
            [void]$ApplianceNamesList.Add($ApplianceName)
        }

    }

    End {

        # 1. Validate group exists
        try {
            $_group = Get-HPECOMGroup -Region $Region -Name $GroupName
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if (-not $_group) {

            $ErrorMessage = "Group '{0}' cannot be found in the '{1}' region!" -f $GroupName, $Region
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {
                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $ErrorMessage
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                [void]$ValidationStatusList.Add($objStatus)
                $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
                Return $ValidationStatusList
            }

        }

        # 2. Guard: group must be an OVE appliance group
        if ($_group.deviceType -notmatch '^OVE_APPLIANCE') {

            $ErrorMessage = "Group '{0}' is not a OneView appliance group (deviceType: '{1}'). Only groups with deviceType 'OVE_APPLIANCE_VM' or 'OVE_APPLIANCE_SYNERGY' are supported." -f $GroupName, $_group.deviceType
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {
                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $ErrorMessage
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                [void]$ValidationStatusList.Add($objStatus)
                $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
                Return $ValidationStatusList
            }

        }

        $GroupMembers = $_group.devices
        $_groupName = $_group.name

        "[{0}] Group '{1}' validated - deviceType: '{2}' - Member count: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_groupName, $_group.deviceType, $GroupMembers.Count | Write-Verbose

        # 3. Validate the group has a OneView appliance software setting configured
        try {
            $_AllSettings = Get-HPECOMSetting -Region $Region
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        $_settingIds = $_group.settingsUris | ForEach-Object { $_.split('/')[-1] }
        $_SoftwareSetting = $_AllSettings | Where-Object { $_.id -in $_settingIds -and $_.category -match '^OVE_SOFTWARE_' } | Select-Object -First 1

        if (-not $_SoftwareSetting) {

            $ErrorMessage = "Group '{0}' does not have a OneView appliance software setting configured. OneView appliance software setting must be set for this group to update OneView appliances. Edit the group and assign a OneView appliance software setting to the group." -f $GroupName
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {
                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $ErrorMessage
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                [void]$ValidationStatusList.Add($objStatus)
                $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
                Return $ValidationStatusList
            }

        }

        $BundleID = $_SoftwareSetting.applianceFirmwareId

        # Fetch all bundles once to get the target version string for display
        try {
            $_AllBundles = Get-HPECOMApplianceFirmwareBundle -Region $Region
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        $_TargetBundle = $_AllBundles | Where-Object id -eq $BundleID | Select-Object -First 1
        $TargetVersion = if ($_TargetBundle) { $_TargetBundle.applianceVersion } else { $BundleID }

        "[{0}] Software setting '{1}' - Bundle ID: '{2}' - Target version: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_SoftwareSetting.name, $BundleID, $TargetVersion | Write-Verbose

        # 4. Get all appliances in the region
        try {
            $AllAppliances = Get-HPECOMAppliance -Region $Region
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        # 5. Build the list of appliances to update
        $AppliancesToUpdate = [System.Collections.ArrayList]::new()

        if ($ApplianceNamesList) {

            "[{0}] Processing specific appliances: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ApplianceNamesList -join ', ') | Write-Verbose

            foreach ($Name in $ApplianceNamesList) {

                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $null
                    duration           = '00:00:00'
                    associatedResource = $Name
                    region             = $Region
                }

                # Match appliance by IP address or hostname
                if ($Name -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
                    $Appliance = $AllAppliances | Where-Object ipaddress -eq $Name
                }
                else {
                    $Appliance = $AllAppliances | Where-Object name -eq $Name
                }

                if (-not $Appliance) {

                    $objStatus.message = "Appliance '{0}' cannot be found in the '{1}' region!" -f $Name, $Region
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                    if ($WhatIf) { Write-Warning "$($objStatus.message) Cannot display API request." }
                    else { [void]$ValidationStatusList.Add($objStatus) }

                }
                elseif (-not ($GroupMembers | Where-Object serial -eq $Appliance.id)) {

                    $objStatus.message = "Appliance '{0}' is not a member of group '{1}'!" -f $Name, $GroupName
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                    if ($WhatIf) { Write-Warning "$($objStatus.message) Cannot display API request." }
                    else { [void]$ValidationStatusList.Add($objStatus) }

                }
                else {
                    [void]$AppliancesToUpdate.Add($Appliance)
                }
            }

        }
        else {

            # No specific appliance named — target all group members
            if ($GroupMembers) {

                foreach ($Member in $GroupMembers) {
                    $Appliance = $AllAppliances | Where-Object id -eq $Member.serial
                    if ($Appliance) {
                        [void]$AppliancesToUpdate.Add($Appliance)
                    }
                }

            }
            else {

                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = "Group '{0}' has no appliance members to be updated!" -f $GroupName
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                if ($WhatIf) { Write-Warning "$($objStatus.message) Cannot display API request." }
                else {
                    [void]$ValidationStatusList.Add($objStatus)
                    $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
                    Return $ValidationStatusList
                }

            }
        }

        if (-not $AppliancesToUpdate -and -not $WhatIf -and $ValidationStatusList.Count -gt 0) {
            $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
            Return $ValidationStatusList
        }

        # 6. Fetch all currently running jobs once (used to detect in-progress appliance updates)
        #    Always fetch — this is a read-only GET and must also run under -WhatIf to warn correctly.
        $_AllRunningJobs = @()
        try {
            $_AllRunningJobs = @(Get-HPECOMJob -Region $Region -ShowRunning -Verbose:$false -ErrorAction SilentlyContinue)
        }
        catch {
            "[{0}] Warning: Unable to query running jobs — in-progress check will be skipped. Error: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
        }

        # 6a. Pre-filter (non-WhatIf only): remove appliances with a running firmware update job from the
        #     processing list before the summary is printed, so the summary only shows what will actually run.
        #     Status objects are added to ValidationStatusList for each skipped appliance.
        if ($_AllRunningJobs -and -not $WhatIf) {
            $_AppliancesToProcess = [System.Collections.ArrayList]::new()
            foreach ($_a in $AppliancesToUpdate) {
                $_aDeviceID = $_a.deviceId
                $_runningJob = $_AllRunningJobs | Where-Object {
                    $_.name -eq $_JobTemplateName -and (
                        $_.resource.id -like "*$($_a.id)*" -or
                        $_.resource.id -like "*$_aDeviceID*"
                    )
                } | Select-Object -First 1
                if ($_runningJob) {
                    $_msg = "Appliance '{0}' already has a running firmware update job ('{1}'). Skipping to avoid conflict." -f $_a.name, $_runningJob.resourceUri
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_msg | Write-Verbose
                    [void]$ValidationStatusList.Add([PSCustomObject]@{
                        state              = "WARNING"
                        resultCode         = "SKIPPED"
                        status             = "Warning"
                        message            = $_msg
                        duration           = '00:00:00'
                        associatedResource = $_a.name
                        name               = $_JobTemplateName
                        date               = "$((Get-Date).ToString())"
                        jobUri             = $_runningJob.resourceUri
                        region             = $Region
                    })
                }
                else {
                    [void]$_AppliancesToProcess.Add($_a)
                }
            }
            $AppliancesToUpdate = $_AppliancesToProcess
        }

        # If all appliances were pre-filtered out, return status objects without printing the summary
        if (-not $AppliancesToUpdate -and -not $WhatIf -and $ValidationStatusList.Count -gt 0) {
            $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
            Return $ValidationStatusList
        }

        # 7. Pre-loop summary — only reached when at least one appliance will be processed
        if (-not $WhatIf) {
            Write-Host ""
            Write-Host ("  Appliance update summary for group '{0}' — target version: {1}" -f $_groupName, $TargetVersion) -ForegroundColor Cyan
            Write-Host ("  " + ("-" * 80))
            foreach ($_a in $AppliancesToUpdate) {
                $_av = $_a.version.split("-")[0]
                if ($_av -eq $TargetVersion) {
                    Write-Host ("    {0,-35} {1,-12}  →  {2,-12}  (already up-to-date, will be skipped)" -f $_a.name, $_av, $TargetVersion) -ForegroundColor DarkGray
                }
                else {
                    Write-Host ("    {0,-35} {1,-12}  →  {2,-12}" -f $_a.name, $_av, $TargetVersion)
                }
            }
            Write-Host ""
        }

        # 8. Per-appliance: prompt and submit job
        foreach ($Appliance in $AppliancesToUpdate) {

            $_applianceResourceUri = $Appliance.resourceUri
            $_applianceDeviceID = $Appliance.deviceId
            $_applianceType = $Appliance.applianceType
            $_applianceName = $Appliance.name
            $_applianceVersion = $Appliance.version.split("-")[0]  # Version number only, strip build suffix

            "[{0}] Processing appliance '{1}' - applianceType: '{2}' - currentVersion: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_applianceName, $_applianceType, $_applianceVersion | Write-Verbose

            # Skip appliances that already have a running firmware update job
            if ($_AllRunningJobs) {
                $_existingRunningJob = $_AllRunningJobs | Where-Object {
                    $_.name -eq $_JobTemplateName -and (
                        $_.resource.id -like "*$($Appliance.id)*" -or
                        $_.resource.id -like "*$_applianceDeviceID*"
                    )
                } | Select-Object -First 1

                if ($_existingRunningJob) {
                    $_msg = "Appliance '{0}' already has a running firmware update job ('{1}'). Skipping to avoid conflict." -f $_applianceName, $_existingRunningJob.resourceUri
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_msg | Write-Verbose
                    if ($WhatIf) {
                        Write-Warning "$_msg Cannot display API request."
                    }
                    continue
                }
            }

            # Skip appliances already running the target version
            if ($_applianceVersion -eq $TargetVersion) {

                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "SKIPPED"
                    status             = "Warning"
                    message            = "Appliance '{0}' is already running the target version '{1}'. No update required." -f $_applianceName, $TargetVersion
                    duration           = '00:00:00'
                    associatedResource = $_applianceName
                    name               = $_JobTemplateName
                    date               = "$((Get-Date).ToString())"
                    jobUri             = $null
                    region             = $Region
                }
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                if ($WhatIf) { Write-Warning $objStatus.message }
                else { [void]$ValidationStatusList.Add($objStatus) }
                continue

            }

            # Interactive confirmation prompt (skipped when -WhatIf or -Force)
            if (-not $WhatIf -and -not $Force) {

                Write-Host ""
                Write-Host "  Appliance       : $_applianceName" -ForegroundColor Cyan
                Write-Host "  Current version : $_applianceVersion"
                Write-Host "  Target version  : $TargetVersion"
                Write-Host ""
                Write-Host "  IMPORTANT: Before updating, ensure you have a current backup of the appliance." -ForegroundColor Yellow
                Write-Host "  Run the HPE OneView Update Readiness Checker to verify your environment is ready:" -ForegroundColor Yellow
                Write-Host "  https://www.hpe.com/support/ov-urc" -ForegroundColor Yellow
                Write-Host ""

                $choice = $null

                while ($choice -notin @('Y', 'N', 'S')) {
                    $choice = (Read-Host "  Proceed with update? [Y] Yes  [N] No (abort all)  [S] Skip this appliance").Trim().ToUpper()
                    if ($choice -notin @('Y', 'N', 'S')) {
                        Write-Host "  Please enter Y, N, or S." -ForegroundColor Red
                    }
                }

                if ($choice -eq 'N') {
                    Write-Host "  Firmware update aborted by user." -ForegroundColor Red
                    return
                }
                elseif ($choice -eq 'S') {
                    "[{0}] Appliance '{1}' skipped by user." -f $MyInvocation.InvocationName.ToString().ToUpper(), $_applianceName | Write-Verbose
                    continue
                }
            }

            # Build job payload data
            $data = @{
                applianceFirmwareId = $BundleID
            }

            if ($ScheduleTime) {

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
                $ScheduleName = "$($_applianceName)_ApplianceFirmwareUpdate_Schedule_$($randomNumber)"
                $ScheduleDescription = "Scheduled appliance software update for '$_applianceName' in group '$GroupName'"

                $Schedule = @{
                    startAt = $ScheduleTime.ToString("o")  # ISO 8601 format
                }

                $payload = @{
                    name                  = $ScheduleName
                    description           = $ScheduleDescription
                    associatedResourceUri = $_applianceResourceUri
                    purpose               = "APPLIANCE_FW_UPDATE"
                    schedule              = $Schedule
                    operation             = $Operation
                }

                $payload = ConvertTo-Json $payload -Depth 10

                try {
                    $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $SchedulesUri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

                    if (-not $WhatIf) {
                        $_resp | Add-Member -type NoteProperty -name region -value $Region
                        $_schedResp = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Schedules"
                        [void]$ScheduleResultsList.Add($_schedResp)
                        "[{0}] Schedule created for appliance '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_applianceName, $_resp.resourceUri | Write-Verbose
                    }

                }
                catch {
                    if (-not $WhatIf) {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }
                }

            }
            else {

                # Build immediate job payload
                $payload = @{
                    jobTemplate  = $JobTemplateId
                    resourceId   = $_applianceDeviceID
                    resourceType = "compute-ops-mgmt/oneview-appliance"
                    jobParams    = $data
                }

                $payload = ConvertTo-Json $payload -Depth 10

                $objStatus = [PSCustomObject]@{
                    state              = $null
                    resultCode         = $null
                    status             = $null
                    message            = $null
                    duration           = '00:00:00'
                    associatedResource = $_applianceName
                    region             = $Region
                    jobUri             = $null
                    details            = $null
                    name               = $_JobTemplateName
                    date               = "$((Get-Date).ToString())"
                }

                try {
                    $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $JobsUri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

                    $_resp | Add-Member -type NoteProperty -name region -value $Region
                    $_resp = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs"

                    if (-not $WhatIf -and $Wait) {

                        "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose

                        $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout
                        "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

                        if ($_resp -and $_resp.PSObject.Properties.Name -contains 'createdAt' -and $_resp.PSObject.Properties.Name -contains 'updatedAt') {
                            $Duration = ((Get-Date $_resp.updatedAt) - (Get-Date $_resp.createdAt)).ToString('hh\:mm\:ss')
                        }
                        else {
                            $Duration = '00:00:00'
                        }

                        $objStatus.state = $_resp.state
                        $objStatus.duration = $Duration
                        $objStatus.resultCode = $_resp.resultCode
                        $objStatus.status = $_resp.Status
                        $objStatus.message = "To monitor job progress, run: Get-HPECOMAppliance -Region $Region -Name '$_applianceName' -ShowJobs"
                        $objStatus.details = $_resp
                        $objStatus.jobUri = $_resp.resourceUri

                        [void]$StatusList.Add($objStatus)

                    }
                    elseif (-not $WhatIf) {

                        $_resp | Add-Member -Type NoteProperty -Name message -Value "To monitor job progress, run: Get-HPECOMAppliance -Region $Region -Name '$_applianceName' -ShowJobs" -Force
                        [void]$JobResultsList.Add($_resp)
                        "[{0}] Job submitted for appliance '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_applianceName, $_resp.resourceUri | Write-Verbose

                    }

                }
                catch {

                    if (-not $WhatIf) {

                        $objStatus.state = "ERROR"
                        $objStatus.duration = '00:00:00'
                        $objStatus.resultCode = "FAILURE"
                        $objStatus.status = "Failed"
                        $objStatus.message = if ($_.Exception.Message) { $_.Exception.Message } else { "An error occurred while submitting the firmware update job for appliance '$_applianceName'." }

                        [void]$StatusList.Add($objStatus)

                    }
                }

            }

        }

        # Return results
        if ($ScheduleTime -and -not $WhatIf) {

            if ($ScheduleResultsList.Count -gt 0) {
                Return $ScheduleResultsList
            }
            return

        }

        if (-not $Wait -and -not $WhatIf) {

            # Merge any validation warnings with submitted jobs and return immediately
            $AllResults = [System.Collections.ArrayList]::new()
            if ($ValidationStatusList.Count -gt 0) {
                $ValidationStatusList | ForEach-Object { [void]$AllResults.Add($_) }
            }
            if ($JobResultsList.Count -gt 0) {
                $JobResultsList = Invoke-RepackageObjectWithType -RawObject $JobResultsList -ObjectName "COM.Jobs"
                Return $JobResultsList
            }
            if ($ValidationStatusList.Count -gt 0) {
                $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
                Return $ValidationStatusList
            }
            return

        }

        if (-not $WhatIf) {

            # Merge validation failures and job statuses
            $AllResults = [System.Collections.ArrayList]::new()

            if ($ValidationStatusList.Count -gt 0) {
                $ValidationStatusList | ForEach-Object { [void]$AllResults.Add($_) }
            }

            if ($StatusList.Count -gt 0) {
                $StatusList | ForEach-Object { [void]$AllResults.Add($_) }
            }

            if ($AllResults.Count -gt 0) {
                $AllResults = Invoke-RepackageObjectWithType -RawObject $AllResults -ObjectName "COM.Jobs.Status"
                Return $AllResults
            }

        }

    }
}

function Invoke-HPECOMGroupApplianceSettings {
    <#
    .SYNOPSIS
    Initiates the appliance settings of OneView appliances in an OVE appliance group.
    
    .DESCRIPTION   
    This cmdlet initiates an appliance group configuration that applies the group's OneView appliance settings to some or all OneView appliance members of an OVE appliance group.

    Before submitting the configuration job, ensure the following prerequisites are met:
    - The group must be configured with one or more OneView appliance group settings (OVE appliance settings).
    - The target appliances must be in the Connected state in Compute Ops Management.
    - No other jobs must be in progress on the target appliances.
    - The source HPE OneView appliance (from which settings were captured) must have a security mode equal to or higher than the destination appliance. Applying settings from a lower security mode to a higher security mode is not supported.

    Note: Only groups with deviceType 'OVE_APPLIANCE_VM' or 'OVE_APPLIANCE_SYNERGY' are supported.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the group is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
        
    .PARAMETER GroupName
    Name of the OVE appliance group on which the configuration will be performed.
    Only groups with deviceType 'OVE_APPLIANCE_VM' or 'OVE_APPLIANCE_SYNERGY' are supported.
    
    .PARAMETER ApplianceName
    (Optional) Specifies the name (hostname or IP address) of one or more specific appliances to configure within the group. 
    If not specified, the configuration is applied to all member appliances in the group.

    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties). By default, the Cmdlet will wait for the job to complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Invoke-HPECOMGroupApplianceSettings -Region eu-central -GroupName OneView_VM_Grp

    This command initiates an appliance group configuration for all appliances in the group named 'OneView_VM_Grp' located in the 'eu-central' region.

    .EXAMPLE
    Invoke-HPECOMGroupApplianceSettings -Region eu-central -GroupName OneView_VM_Grp -ApplianceName "oneview.domain.lab"

    This command initiates an appliance group configuration for the appliance 'oneview.domain.lab' within the 'OneView_VM_Grp' group in the 'eu-central' region.

    .EXAMPLE
    Invoke-HPECOMGroupApplianceSettings -Region eu-central -GroupName OneView_VM_Grp -Async

    This command initiates an appliance group configuration for all appliances in 'OneView_VM_Grp' and returns the job resource immediately for monitoring.

    .EXAMPLE
    Get-HPECOMAppliance -Region eu-central -Name "oneview.domain.lab" | Invoke-HPECOMGroupApplianceSettings -GroupName OneView_VM_Grp

    This command retrieves the appliance 'oneview.domain.lab' and pipes it to configure it within the 'OneView_VM_Grp' group in the 'eu-central' region.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central -Name OneView_VM_Grp -ShowMembers | Invoke-HPECOMGroupApplianceSettings -GroupName OneView_VM_Grp

    This command retrieves all appliance members of the 'OneView_VM_Grp' group and initiates a configuration for all of them.

    .EXAMPLE
    "oneview1.domain.lab", "oneview2.domain.lab" | Invoke-HPECOMGroupApplianceSettings -Region eu-central -GroupName OneView_VM_Grp

    This command initiates a group configuration for the two specified appliances within the 'OneView_VM_Grp' group in the 'eu-central' region.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central | ForEach-Object { $_ | Invoke-HPECOMGroupApplianceSettings }

    This command retrieves all groups in the 'eu-central' region and initiates an appliance configuration for each OVE appliance group.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing appliance names (hostnames or IP addresses).

    System.Collections.ArrayList
        List of appliances from 'Get-HPECOMAppliance' or 'Get-HPECOMGroup -ShowMembers'.

    .OUTPUTS
    HPEGreenLake.COM.Jobs [System.Management.Automation.PSCustomObject]

        - If the -Async switch is used, the cmdlet returns the job resource immediately, allowing you to monitor
          its progress using the `state` and `resultCode` properties, or by passing the job object to
          `Wait-HPECOMJobComplete` for blocking/waiting behavior.

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

    #>

    [CmdletBinding()]
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
                
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
        [ValidateNotNullOrEmpty()]
        [String]$GroupName,

        [Parameter (ValueFromPipeline, ValueFromPipelineByPropertyName)] 
        [Alias('name', 'IPAddress')]
        [ValidateNotNullOrEmpty()]
        [String]$ApplianceName,

        [switch]$Async,

        [switch]$WhatIf

    )

    Begin {

        [int]$TimeoutinSecondsPerAppliance = 300  # 5 minutes per appliance

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $_JobTemplateName = 'GroupApplyOneviewSettings'

        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $Uri = Get-COMJobsUri

        $ApplianceNamesList   = [System.Collections.ArrayList]::new()
        $ApplianceIdsList     = [System.Collections.ArrayList]::new()
        $ValidationStatusList = [System.Collections.ArrayList]::new()
                
    }
    
    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        if ($ApplianceName -and $ApplianceName -notmatch '^@\{.*\}$') {

            [void]$ApplianceNamesList.add($ApplianceName)
        }

    }

    End {

        # 1. Fetch and validate the group
        try {
            $_group = Get-HPECOMGroup -Region $Region -Name $GroupName
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if (-not $_group) {

            $ErrorMessage = "Group '{0}' cannot be found in the '{1}' region!" -f $GroupName, $Region
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                Return
            }
            else {
                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $ErrorMessage
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                [void]$ValidationStatusList.Add($objStatus)
                $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
                Return $ValidationStatusList
            }
        }

        # 2. Guard: group must be an OVE appliance group
        if ($_group.deviceType -notmatch '^OVE_APPLIANCE') {

            $ErrorMessage = "Group '{0}' is not a OneView appliance group (deviceType: '{1}'). Only groups with deviceType 'OVE_APPLIANCE_VM' or 'OVE_APPLIANCE_SYNERGY' are supported." -f $GroupName, $_group.deviceType
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                Return
            }
            else {
                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $ErrorMessage
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                [void]$ValidationStatusList.Add($objStatus)
                $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
                Return $ValidationStatusList
            }
        }

        $GroupMembers   = $_group.devices
        $_groupName     = $_group.name
        $_groupId       = $_group.id
        $NbOfAppliances = $GroupMembers.count

        "[{0}] Group '{1}' validated - deviceType: '{2}' - Member count: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_groupName, $_group.deviceType, $NbOfAppliances | Write-Verbose

        # 3. Validate the group has at least one OneView appliance setting configured
        try {
            $_AllSettings = Get-HPECOMSetting -Region $Region
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        $_settingIds      = $_group.settingsUris | ForEach-Object { $_.split('/')[-1] }
        $_ApplianceSetting = $_AllSettings | Where-Object { $_.id -in $_settingIds -and $_.category -match '^OVE_APPLIANCE_SETTINGS' } | Select-Object -First 1

        if (-not $_ApplianceSetting) {

            $ErrorMessage = "Group '{0}' does not have a OneView appliance setting configured. Assign an appliance setting to the group before initiating a configuration. Use 'Get-HPECOMSetting -Region {1} -Category OneViewApplianceSettings' to list available settings." -f $GroupName, $Region
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                Return
            }
            else {
                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $ErrorMessage
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                [void]$ValidationStatusList.Add($objStatus)
                $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
                Return $ValidationStatusList
            }
        }

        "[{0}] Appliance setting '{1}' (category: '{2}') found for group '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_ApplianceSetting.name, $_ApplianceSetting.category, $_groupName | Write-Verbose

        # 4. Get all appliances in the region
        try {
            $AllAppliances = Get-HPECOMAppliance -Region $Region
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        # 5. Fetch all currently running jobs once (used to detect in-progress configuration jobs)
        $_AllRunningJobs = @()
        try {
            $_AllRunningJobs = @(Get-HPECOMJob -Region $Region -ShowRunning -Verbose:$false -ErrorAction SilentlyContinue)
        }
        catch {
            "[{0}] Warning: Unable to query running jobs — in-progress check will be skipped. Error: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
        }

        # 6. Build the list of appliances to configure
        if ($ApplianceNamesList) {

            "[{0}] Processing specific appliances: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ApplianceNamesList -join ', ') | Write-Verbose

            foreach ($Name in $ApplianceNamesList) {

                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $null
                    duration           = '00:00:00'
                    associatedResource = $Name
                    region             = $Region
                }

                # Match appliance by IP address or hostname
                if ($Name -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
                    $Appliance = $AllAppliances | Where-Object ipaddress -eq $Name
                }
                else {
                    $Appliance = $AllAppliances | Where-Object name -eq $Name
                }

                if (-not $Appliance) {

                    $objStatus.message = "Appliance '{0}' cannot be found in the '{1}' region!" -f $Name, $Region
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                    if ($WhatIf) { Write-Warning "$($objStatus.message) Cannot display API request." }
                    else { [void]$ValidationStatusList.Add($objStatus) }

                }
                elseif (-not ($GroupMembers | Where-Object serial -eq $Appliance.id)) {

                    $objStatus.message = "Appliance '{0}' is not a member of group '{1}'!" -f $Name, $GroupName
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                    if ($WhatIf) { Write-Warning "$($objStatus.message) Cannot display API request." }
                    else { [void]$ValidationStatusList.Add($objStatus) }

                }
                elseif ($Appliance.state -ne 'CONNECTED') {

                    $objStatus.message = "Appliance '{0}' is not in the Connected state (current state: '{1}'). Only Connected appliances can be configured." -f $Name, $Appliance.state
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                    if ($WhatIf) { Write-Warning "$($objStatus.message) Cannot display API request." }
                    else { [void]$ValidationStatusList.Add($objStatus) }

                }
                elseif ($_AllRunningJobs) {

                    # Use the group member composite id (oneview+UUID) for the running job check
                    $_memberCompositeId = ($GroupMembers | Where-Object serial -eq $Appliance.id).id

                    $_existingRunningJob = $_AllRunningJobs | Where-Object {
                        $_.name -eq $_JobTemplateName -and $_.resource.id -like "*$_memberCompositeId*"
                    } | Select-Object -First 1

                    if ($_existingRunningJob) {
                        $objStatus.message = "Appliance '{0}' already has a running configuration job ('{1}'). Skipping to avoid conflict." -f $Name, $_existingRunningJob.resourceUri
                        "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                        if ($WhatIf) { Write-Warning "$($objStatus.message) Cannot display API request." }
                        else { [void]$ValidationStatusList.Add($objStatus) }
                    }
                    else {
                        # Add the group member composite id (oneview+UUID) — required by the API targetApplianceIds field
                        [void]$ApplianceIdsList.Add($_memberCompositeId)
                    }

                }
                else {
                    # Add the group member composite id (oneview+UUID) — required by the API targetApplianceIds field
                    $_memberCompositeId = ($GroupMembers | Where-Object serial -eq $Appliance.id).id
                    [void]$ApplianceIdsList.Add($_memberCompositeId)
                }
            }

        }
        else {

            if ($GroupMembers) {

                "[{0}] No specific appliances named — validating all {1} group members" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GroupMembers.Count | Write-Verbose

                foreach ($Object in $GroupMembers) {

                    # Group member 'serial' matches the appliance plain UUID id from Get-HPECOMAppliance
                    # Group member 'id' is the composite oneview+UUID format required by the API
                    $Appliance = $AllAppliances | Where-Object id -eq $Object.serial

                    if (-not $Appliance) {

                        $objStatus = [PSCustomObject]@{
                            state              = "WARNING"
                            resultCode         = "FAILURE"
                            status             = "Warning"
                            message            = "Appliance with ID '{0}' (group member of '{1}') cannot be found in the '{2}' region!" -f $Object.serial, $GroupName, $Region
                            duration           = '00:00:00'
                            associatedResource = $Object.serial
                            region             = $Region
                        }
                        "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                        if ($WhatIf) { Write-Warning "$($objStatus.message) Cannot display API request." }
                        else { [void]$ValidationStatusList.Add($objStatus) }

                    }
                    elseif ($Appliance.state -ne 'CONNECTED') {

                        $objStatus = [PSCustomObject]@{
                            state              = "WARNING"
                            resultCode         = "FAILURE"
                            status             = "Warning"
                            message            = "Appliance '{0}' is not in the Connected state (current state: '{1}'). Only Connected appliances can be configured." -f $Appliance.name, $Appliance.state
                            duration           = '00:00:00'
                            associatedResource = $Appliance.name
                            region             = $Region
                        }
                        "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                        if ($WhatIf) { Write-Warning "$($objStatus.message) Cannot display API request." }
                        else { [void]$ValidationStatusList.Add($objStatus) }

                    }
                    elseif ($_AllRunningJobs) {

                        $_existingRunningJob = $_AllRunningJobs | Where-Object {
                            $_.name -eq $_JobTemplateName -and $_.resource.id -like "*$($Appliance.id)*"
                        } | Select-Object -First 1

                        if ($_existingRunningJob) {
                            $objStatus = [PSCustomObject]@{
                                state              = "WARNING"
                                resultCode         = "FAILURE"
                                status             = "Warning"
                                message            = "Appliance '{0}' already has a running configuration job ('{1}'). Skipping to avoid conflict." -f $Appliance.name, $_existingRunningJob.resourceUri
                                duration           = '00:00:00'
                                associatedResource = $Appliance.name
                                region             = $Region
                            }
                            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                            if ($WhatIf) { Write-Warning "$($objStatus.message) Cannot display API request." }
                            else { [void]$ValidationStatusList.Add($objStatus) }
                        }
                        else {
                            # Add the group member composite id (oneview+UUID) — required by the API targetApplianceIds field
                            [void]$ApplianceIdsList.Add($Object.id)
                        }

                    }
                    else {
                        # Add the group member composite id (oneview+UUID) — required by the API targetApplianceIds field
                        [void]$ApplianceIdsList.Add($Object.id)
                    }
                }
            }
            else {

                # Must return a message if no appliance members are found in the group
                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $null
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                $objStatus.message = "Group '{0}' has no appliance members to be configured!" -f $GroupName

                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                if ($WhatIf) {
                    Write-Warning "$($objStatus.message) Cannot display API request."
                }
                else {
                    [void]$ValidationStatusList.Add($objStatus)
                    $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
                    Return $ValidationStatusList
                }
            }
        }

        # Early return if all appliances failed validation (named or all-members path)
        if (-not $ApplianceIdsList -and -not $WhatIf -and $ValidationStatusList.Count -gt 0) {
            $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
            Return $ValidationStatusList
        }

        if ($ApplianceIdsList) {

            "[{0}] List of appliance IDs to configure: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ApplianceIdsList | out-string) | Write-Verbose

            # Build payload — targetApplianceIds is always required by the API
            $data = @{
                targetApplianceIds = @($ApplianceIdsList)
            }

            $payload = @{
                jobTemplate  = $JobTemplateId
                resourceId   = $_groupId
                resourceType = "compute-ops-mgmt/group"
                jobParams    = $data
            }

            $payload = ConvertTo-Json $payload -Depth 10

            try {
                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

                # Add region to object
                $_resp | Add-Member -type NoteProperty -name region -value $Region

                if (-not $WhatIf -and -not $Async) {

                    $Timeout = $ApplianceIdsList.Count * $TimeoutinSecondsPerAppliance

                    "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose

                    $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout
                    "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

                }
                else {

                    if (-not $WhatIf) {
                        $_resp = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs"
                    }

                }
            }
            catch {

                if (-not $WhatIf) {

                    $PSCmdlet.ThrowTerminatingError($_)

                }
            }

            if (-not $WhatIf) {

                # Build a friendly message listing the appliances actually configured
                if ($ApplianceNamesList) {
                    # Named appliances — resolve configured names from the IDs that passed validation
                    $_configuredNames = $ApplianceNamesList | Where-Object {
                        $_applianceName = $_
                        $ap = $AllAppliances | Where-Object { $_.name -eq $_applianceName -or $_.ipaddress -eq $_applianceName }
                        $ap -and ($ApplianceIdsList -contains ($GroupMembers | Where-Object serial -eq $ap.id).id)
                    }
                }
                else {
                    # All-members path — resolve names from configured IDs
                    $_configuredNames = $ApplianceIdsList | ForEach-Object {
                        $compositeId = $_
                        $member = $GroupMembers | Where-Object id -eq $compositeId
                        $ap = $AllAppliances | Where-Object id -eq $member.serial
                        if ($ap) { $ap.name } else { $compositeId }
                    }
                }
                # Only set a custom success message when the job actually succeeded — preserve the API error message on failure
                if ($_resp.resultCode -eq 'SUCCESS') {
                    $_configuredMsg = "Applied OneView appliance settings to: {0}" -f ($_configuredNames -join ', ')
                    $_resp.message = $_configuredMsg
                }
                # else: keep $_resp.message as-is (the detailed error from Get-HPECOMActivity via Wait-HPECOMJobComplete)

                # Set associatedResource to group name
                if ($_resp.PSObject.Properties.Name -notcontains 'associatedResource') {
                    $_resp | Add-Member -Type NoteProperty -Name associatedResource -Value $GroupName -Force
                }
                else {
                    $_resp.associatedResource = $GroupName
                }

                # Merge any validation warnings with the job result
                if ($ValidationStatusList.Count -gt 0) {
                    $AllResults = [System.Collections.ArrayList]::new()
                    $ValidationStatusList | ForEach-Object { [void]$AllResults.Add($_) }
                    [void]$AllResults.Add($_resp)
                    Return (Invoke-RepackageObjectWithType -RawObject $AllResults -ObjectName "COM.Jobs.Status")
                }

                Return (Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs.Status")

            }

        }
    }
}

function Copy-HPECOMGroupApplianceServerProfileTemplate {
    <#
    .SYNOPSIS
    Copies the OneView server profile templates defined in a group's VM server template setting to all or specific appliances in an OVE appliance group.
    
    .DESCRIPTION   
    This cmdlet submits a group job that copies the server profile templates defined in the group's OneView VM server template setting 
    to some or all OneView appliance members of an OVE appliance group. The templates are copied using the same names as defined 
    in the setting — no renaming is performed.

    Before submitting the copy job, ensure the following prerequisites are met:
    - The group must be configured with a OneView server profile template setting (OVE_SERVER_TEMPLATES_VM or OVE_SERVER_TEMPLATES_SYNERGY).
    - The target appliances must be in the Connected state in Compute Ops Management.
    - No other jobs must be in progress on the target appliances.

    Note: Only groups with deviceType 'OVE_APPLIANCE_VM' or 'OVE_APPLIANCE_SYNERGY' are supported.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the group is located. 
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
        
    .PARAMETER GroupName
    Name of the OVE appliance group on which the copy operation will be performed.
    Only groups with deviceType 'OVE_APPLIANCE_VM' or 'OVE_APPLIANCE_SYNERGY' are supported.

    .PARAMETER ApplianceName
    (Optional) Specifies the name (hostname or IP address) of one or more specific appliances to target within the group. 
    If not specified, the copy operation is applied to all member appliances in the group.

    .PARAMETER Async
    Use this parameter to immediately return the asynchronous job resource to monitor (using 'state' and 'resultCode' properties). By default, the Cmdlet will wait for the job to complete.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Copy-HPECOMGroupApplianceServerProfileTemplate -Region eu-central -GroupName OneView_VM_Grp

    This command copies all server profile templates defined in the group's VM server template setting to all appliances in the group 'OneView_VM_Grp' in the 'eu-central' region.

    .EXAMPLE
    Copy-HPECOMGroupApplianceServerProfileTemplate -Region eu-central -GroupName OneView_VM_Grp -ApplianceName "oneview.domain.lab"

    This command copies all server profile templates defined in the group's VM server template setting to the appliance 'oneview.domain.lab' within the 'OneView_VM_Grp' group.

    .EXAMPLE
    Copy-HPECOMGroupApplianceServerProfileTemplate -Region eu-central -GroupName OneView_VM_Grp -Async

    This command starts the copy operation and immediately returns the job resource for monitoring.

    .EXAMPLE
    "oneview1.domain.lab", "oneview2.domain.lab" | Copy-HPECOMGroupApplianceServerProfileTemplate -Region eu-central -GroupName OneView_VM_Grp

    This command copies all server profile templates from the group's setting to the two specified appliances within the 'OneView_VM_Grp' group.

    .EXAMPLE
    Get-HPECOMGroup -Region eu-central | ForEach-Object { $_ | Copy-HPECOMGroupApplianceServerProfileTemplate }

    This command retrieves all groups in the 'eu-central' region and copies server profile templates for each OVE appliance group.

    .EXAMPLE
    $result = Copy-HPECOMGroupApplianceServerProfileTemplate -Region eu-central -GroupName OneView_VM_Grp
    $result.message
    3 of 4 server profile template copy operation(s) succeeded, 1 failed.
    Failed:
    * Server profile Template_2 Template failed to be copied to the OneView appliance oneview2.domain.lab
    Succeeded:
    * Server template Template_1 was copied successfully to the OneView appliance oneview1.domain.lab
    * Server template Template_2 was copied successfully to the OneView appliance oneview1.domain.lab
    * Server template Template_1 was copied successfully to the OneView appliance oneview2.domain.lab
    
    In this example, the result of the copy operation is stored in the `$result` variable. The `message` property of the result object contains a summary of the operation, including how many template copies succeeded or failed, along with details for each appliance.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing appliance names (hostnames or IP addresses).

    System.Collections.ArrayList
        List of appliances from 'Get-HPECOMAppliance' or 'Get-HPECOMGroup -ShowMembers'.

    .OUTPUTS
    HPEGreenLake.COM.Jobs [System.Management.Automation.PSCustomObject]

        - If the -Async switch is used, the cmdlet returns the job resource immediately, allowing you to monitor
          its progress using the `state` and `resultCode` properties, or by passing the job object to
          `Wait-HPECOMJobComplete` for blocking/waiting behavior.

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

    #>

    [CmdletBinding()]
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
                
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)] 
        [ValidateNotNullOrEmpty()]
        [String]$GroupName,

        [Parameter (ValueFromPipeline, ValueFromPipelineByPropertyName)] 
        [Alias('name', 'IPAddress')]
        [ValidateNotNullOrEmpty()]
        [String]$ApplianceName,

        [switch]$Async,

        [switch]$WhatIf

    )

    Begin {

        [int]$TimeoutinSecondsPerAppliance = 300  # 5 minutes per appliance

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $_JobTemplateName = 'GroupCopyServerProfileTemplates'

        $JobTemplateId = $Global:HPECOMjobtemplatesUris | Where-Object name -eq $_JobTemplateName | ForEach-Object id

        $Uri = Get-COMJobsUri

        $ApplianceNamesList   = [System.Collections.ArrayList]::new()
        $ApplianceIdsList     = [System.Collections.ArrayList]::new()
        $ValidationStatusList = [System.Collections.ArrayList]::new()
                
    }
    
    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        if ($ApplianceName -and $ApplianceName -notmatch '^@\{.*\}$') {

            [void]$ApplianceNamesList.add($ApplianceName)
        }

    }

    End {

        # 1. Fetch and validate the group
        try {
            $_group = Get-HPECOMGroup -Region $Region -Name $GroupName
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if (-not $_group) {

            $ErrorMessage = "Group '{0}' cannot be found in the '{1}' region!" -f $GroupName, $Region
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                Return
            }
            else {
                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $ErrorMessage
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                [void]$ValidationStatusList.Add($objStatus)
                $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
                Return $ValidationStatusList
            }
        }

        # 2. Guard: group must be an OVE appliance group
        if ($_group.deviceType -notmatch '^OVE_APPLIANCE') {

            $ErrorMessage = "Group '{0}' is not a OneView appliance group (deviceType: '{1}'). Only groups with deviceType 'OVE_APPLIANCE_VM' or 'OVE_APPLIANCE_SYNERGY' are supported." -f $GroupName, $_group.deviceType
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                Return
            }
            else {
                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $ErrorMessage
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                [void]$ValidationStatusList.Add($objStatus)
                $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
                Return $ValidationStatusList
            }
        }

        $GroupMembers   = $_group.devices
        $_groupName     = $_group.name
        $_groupId       = $_group.id
        $NbOfAppliances = $GroupMembers.count

        "[{0}] Group '{1}' validated - deviceType: '{2}' - Member count: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_groupName, $_group.deviceType, $NbOfAppliances | Write-Verbose

        # 3. Validate the group has at least one OneView server profile template setting configured
        try {
            $_AllSettings = Get-HPECOMSetting -Region $Region
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        $_settingIds        = $_group.settingsUris | ForEach-Object { $_.split('/')[-1] }
        $_TemplateSetting   = $_AllSettings | Where-Object { $_.id -in $_settingIds -and $_.category -match '^OVE_SERVER_TEMPLATES' } | Select-Object -First 1

        if (-not $_TemplateSetting) {

            $ErrorMessage = "Group '{0}' does not have a OneView server profile template setting configured. Assign a server profile template setting to the group before initiating a copy operation. Use 'Get-HPECOMSetting -Region {1} -Category OneViewServerProfileTemplatesVM' or 'Get-HPECOMSetting -Region {1} -Category OneViewServerProfileTemplatesSynergy' to list available settings." -f $GroupName, $Region
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                Return
            }
            else {
                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $ErrorMessage
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                [void]$ValidationStatusList.Add($objStatus)
                $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
                Return $ValidationStatusList
            }
        }

        "[{0}] Server profile template setting '{1}' (category: '{2}') found for group '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_TemplateSetting.name, $_TemplateSetting.category, $_groupName | Write-Verbose

        # 4. Get all appliances in the region
        try {
            $AllAppliances = Get-HPECOMAppliance -Region $Region
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        # 5. Fetch all currently running jobs once (used to detect in-progress copy jobs)
        $_AllRunningJobs = @()
        try {
            $_AllRunningJobs = @(Get-HPECOMJob -Region $Region -ShowRunning -Verbose:$false -ErrorAction SilentlyContinue)
        }
        catch {
            "[{0}] Warning: Unable to query running jobs — in-progress check will be skipped. Error: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
        }

        # 6. Build the list of appliances to target
        if ($ApplianceNamesList) {

            "[{0}] Processing specific appliances: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ApplianceNamesList -join ', ') | Write-Verbose

            foreach ($Name in $ApplianceNamesList) {

                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $null
                    duration           = '00:00:00'
                    associatedResource = $Name
                    region             = $Region
                }

                # Match appliance by IP address or hostname
                if ($Name -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
                    $Appliance = $AllAppliances | Where-Object ipaddress -eq $Name
                }
                else {
                    $Appliance = $AllAppliances | Where-Object name -eq $Name
                }

                if (-not $Appliance) {

                    $objStatus.message = "Appliance '{0}' cannot be found in the '{1}' region!" -f $Name, $Region
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                    if ($WhatIf) { Write-Warning "$($objStatus.message) Cannot display API request." }
                    else { [void]$ValidationStatusList.Add($objStatus) }

                }
                elseif (-not ($GroupMembers | Where-Object serial -eq $Appliance.id)) {

                    $objStatus.message = "Appliance '{0}' is not a member of group '{1}'!" -f $Name, $GroupName
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                    if ($WhatIf) { Write-Warning "$($objStatus.message) Cannot display API request." }
                    else { [void]$ValidationStatusList.Add($objStatus) }

                }
                elseif ($Appliance.state -ne 'CONNECTED') {

                    $objStatus.message = "Appliance '{0}' is not in the Connected state (current state: '{1}'). Only Connected appliances can have server profile templates copied." -f $Name, $Appliance.state
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                    if ($WhatIf) { Write-Warning "$($objStatus.message) Cannot display API request." }
                    else { [void]$ValidationStatusList.Add($objStatus) }

                }
                elseif ($_AllRunningJobs) {

                    # Use the group member composite id (oneview+UUID) for the running job check
                    $_memberCompositeId = ($GroupMembers | Where-Object serial -eq $Appliance.id).id

                    $_existingRunningJob = $_AllRunningJobs | Where-Object {
                        $_.name -eq $_JobTemplateName -and $_.resource.id -like "*$_memberCompositeId*"
                    } | Select-Object -First 1

                    if ($_existingRunningJob) {
                        $objStatus.message = "Appliance '{0}' already has a running copy job ('{1}'). Skipping to avoid conflict." -f $Name, $_existingRunningJob.resourceUri
                        "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                        if ($WhatIf) { Write-Warning "$($objStatus.message) Cannot display API request." }
                        else { [void]$ValidationStatusList.Add($objStatus) }
                    }
                    else {
                        # Add the group member composite id (oneview+UUID) — required by the API targetApplianceIds field
                        [void]$ApplianceIdsList.Add($_memberCompositeId)
                    }

                }
                else {
                    # Add the group member composite id (oneview+UUID) — required by the API targetApplianceIds field
                    $_memberCompositeId = ($GroupMembers | Where-Object serial -eq $Appliance.id).id
                    [void]$ApplianceIdsList.Add($_memberCompositeId)
                }
            }

        }
        else {

            if ($GroupMembers) {

                "[{0}] No specific appliances named — validating all {1} group members" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GroupMembers.Count | Write-Verbose

                foreach ($Object in $GroupMembers) {

                    # Group member 'serial' matches the appliance plain UUID id from Get-HPECOMAppliance
                    # Group member 'id' is the composite oneview+UUID format required by the API
                    $Appliance = $AllAppliances | Where-Object id -eq $Object.serial

                    # Initialize $objStatus ONCE per iteration with all common fields; only .message is set per branch
                    $objStatus = [PSCustomObject]@{
                        state              = "WARNING"
                        resultCode         = "FAILURE"
                        status             = "Warning"
                        message            = $null
                        duration           = '00:00:00'
                        associatedResource = if ($Appliance) { $Appliance.name } else { $Object.serial }
                        region             = $Region
                    }

                    if (-not $Appliance) {

                        $objStatus.message = "Appliance with ID '{0}' (group member of '{1}') cannot be found in the '{2}' region!" -f $Object.serial, $GroupName, $Region
                        "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                        if ($WhatIf) { Write-Warning "$($objStatus.message) Cannot display API request." }
                        else { [void]$ValidationStatusList.Add($objStatus) }

                    }
                    elseif ($Appliance.state -ne 'CONNECTED') {

                        $objStatus.message = "Appliance '{0}' is not in the Connected state (current state: '{1}'). Only Connected appliances can have server profile templates copied." -f $Appliance.name, $Appliance.state
                        "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                        if ($WhatIf) { Write-Warning "$($objStatus.message) Cannot display API request." }
                        else { [void]$ValidationStatusList.Add($objStatus) }

                    }
                    elseif ($_AllRunningJobs) {

                        $_existingRunningJob = $_AllRunningJobs | Where-Object {
                            $_.name -eq $_JobTemplateName -and $_.resource.id -like "*$($Appliance.id)*"
                        } | Select-Object -First 1

                        if ($_existingRunningJob) {
                            $objStatus.message = "Appliance '{0}' already has a running copy job ('{1}'). Skipping to avoid conflict." -f $Appliance.name, $_existingRunningJob.resourceUri
                            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                            if ($WhatIf) { Write-Warning "$($objStatus.message) Cannot display API request." }
                            else { [void]$ValidationStatusList.Add($objStatus) }
                        }
                        else {
                            # Add the group member composite id (oneview+UUID) — required by the API targetApplianceIds field
                            [void]$ApplianceIdsList.Add($Object.id)
                        }

                    }
                    else {
                        # Add the group member composite id (oneview+UUID) — required by the API targetApplianceIds field
                        [void]$ApplianceIdsList.Add($Object.id)
                    }
                }
            }
            else {

                # Must return a message if no appliance members are found in the group
                $objStatus = [PSCustomObject]@{
                    state              = "WARNING"
                    resultCode         = "FAILURE"
                    status             = "Warning"
                    message            = $null
                    duration           = '00:00:00'
                    associatedResource = $GroupName
                    region             = $Region
                }
                $objStatus.message = "Group '{0}' has no appliance members to copy server profile templates to!" -f $GroupName

                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $objStatus.message | Write-Verbose
                if ($WhatIf) {
                    Write-Warning "$($objStatus.message) Cannot display API request."
                }
                else {
                    [void]$ValidationStatusList.Add($objStatus)
                    $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
                    Return $ValidationStatusList
                }
            }
        }

        # Early return if all appliances failed validation (named or all-members path)
        if (-not $ApplianceIdsList -and -not $WhatIf -and $ValidationStatusList.Count -gt 0) {
            $ValidationStatusList = Invoke-RepackageObjectWithType -RawObject $ValidationStatusList -ObjectName "COM.Jobs.Status"
            Return $ValidationStatusList
        }

        if ($ApplianceIdsList) {

            "[{0}] List of appliance IDs to target: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ApplianceIdsList | out-string) | Write-Verbose

            # Build payload — targetApplianceIds is always required by the API
            $data = @{
                targetApplianceIds = @($ApplianceIdsList)
            }

            $payload = @{
                jobTemplate  = $JobTemplateId
                resourceId   = $_groupId
                resourceType = "compute-ops-mgmt/group"
                jobParams    = $data
            }

            $payload = ConvertTo-Json $payload -Depth 10

            try {
                $_resp = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference

                # Add region to object
                $_resp | Add-Member -type NoteProperty -name region -value $Region

                if (-not $WhatIf -and -not $Async) {

                    $Timeout = $ApplianceIdsList.Count * $TimeoutinSecondsPerAppliance

                    "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose

                    $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout
                    "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

                }
                else {

                    if (-not $WhatIf) {
                        $_resp = Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs"
                    }

                }
            }
            catch {

                if (-not $WhatIf) {

                    $PSCmdlet.ThrowTerminatingError($_)

                }
            }

            if (-not $WhatIf) {

                # Build a friendly message listing the appliances actually targeted
                if ($ApplianceNamesList) {
                    # Named appliances — resolve targeted names from the IDs that passed validation
                    $_configuredNames = $ApplianceNamesList | Where-Object {
                        $_applianceName = $_
                        $ap = $AllAppliances | Where-Object { $_.name -eq $_applianceName -or $_.ipaddress -eq $_applianceName }
                        $ap -and ($ApplianceIdsList -contains ($GroupMembers | Where-Object serial -eq $ap.id).id)
                    }
                }
                else {
                    # All-members path — resolve names from targeted IDs
                    $_configuredNames = $ApplianceIdsList | ForEach-Object {
                        $compositeId = $_
                        $member = $GroupMembers | Where-Object id -eq $compositeId
                        $ap = $AllAppliances | Where-Object id -eq $member.serial
                        if ($ap) { $ap.name } else { $compositeId }
                    }
                }

                # Build the final message based on job outcome
                if ($_resp.resultCode -eq 'SUCCESS') {
                    $_resp.message = "Copied server profile templates to: {0}" -f ($_configuredNames -join ', ')
                }
                elseif ($_resp.data.state_reason_message.message_args.Count -ge 5) {

                    # Extract structured details from data.state_reason_message.message_args:
                    #   [0] = total operations, [1] = successful count, [2] = failed count,
                    #   [3] = multi-line success detail, [4] = multi-line failure detail
                    $_args     = $_resp.data.state_reason_message.message_args
                    $_total    = $_args[0]
                    $_success  = $_args[1]
                    $_failed   = $_args[2]
                    $_successLines = $_args[3] -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { "  " + $_.Trim() }
                    $_failLines    = $_args[4] -split "`n" | Where-Object { $_.Trim() } | ForEach-Object { "  " + $_.Trim() }

                    $_parts = @("$_success of $_total server profile template copy operation(s) succeeded, $_failed failed.")
                    if ($_failLines)    { $_parts += "Failed:`n" + ($_failLines -join "`n") }
                    if ($_successLines) { $_parts += "Succeeded:`n" + ($_successLines -join "`n") }
                    $_resp.message = $_parts -join "`n"
                }
                else {
                    # Fallback: ensure the activity message (which can be an array) is joined to a single string
                    if ($_resp.message -is [Array]) {
                        $_resp.message = $_resp.message -join " - "
                    }
                }

                # Set associatedResource to group name
                if ($_resp.PSObject.Properties.Name -notcontains 'associatedResource') {
                    $_resp | Add-Member -Type NoteProperty -Name associatedResource -Value $GroupName -Force
                }
                else {
                    $_resp.associatedResource = $GroupName
                }

                # Merge any validation warnings with the job result
                if ($ValidationStatusList.Count -gt 0) {
                    $AllResults = [System.Collections.ArrayList]::new()
                    $ValidationStatusList | ForEach-Object { [void]$AllResults.Add($_) }
                    [void]$AllResults.Add($_resp)
                    Return (Invoke-RepackageObjectWithType -RawObject $AllResults -ObjectName "COM.Jobs.Status")
                }

                Return (Invoke-RepackageObjectWithType -RawObject $_resp -ObjectName "COM.Jobs.Status")

            }

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

        [Parameter (ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ByName')]
        # [Alias('name')]
        [ValidateNotNullOrEmpty()]
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
        
    .PARAMETER Name
    Name, hostname, or serial number of the server on which the ignore iLO security risk will be enabled.
    
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
    Enable-HPECOMIloIgnoreRiskSetting -Region eu-central -Name "CZ12312312" -AccessPanelStatus -AuthenticationFailureLogging

    This command enables the ignore iLO security risk settings "Access Panel Status" and "Authentication Failure Logging" on the server with name or serial number 'CZ12312312' located in the `eu-central` region. 
   
    .EXAMPLE
    Enable-HPECOMIloIgnoreRiskSetting -Region eu-central -Name "CZ12312312" -AccessPanelStatus -AuthenticationFailureLogging -DefaultSSLCertificateInUse -IPMIDCMIOverLAN -LastFirmwareScanResult -MinimumPasswordLength -PasswordComplexity -RequireHostAuthentication -RequireLoginforiLORBSU -SecureBoot -SecurityOverrideSwitch -SNMPv1 

    This command enables all ignore iLO security risk settings on the server with name or serial number 'CZ12312312' located in the `eu-central` region. 

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-1 | Enable-HPECOMIloIgnoreRiskSetting -AccessPanelStatus -AuthenticationFailureLogging -DefaultSSLCertificateInUse 

    This command enables the ignore iLO security risk settings "Access Panel Status", "Authentication Failure Logging", and "Default SSL Certificate In Use" on the server named 'ESX-1' located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -ConnectionType Direct | Enable-HPECOMIloIgnoreRiskSetting -All 

    This command enables all ignore iLO security risk settings on the servers with a direct connection type located in the `eu-central` region.

    .EXAMPLE
    "CZ12312312", "DZ12312312" | Enable-HPECOMIloIgnoreRiskSetting -Region eu-central -MinimumPasswordLength 

    This command enables the ignore iLO security risk setting "Minimum Password Length" on the servers with names or serial numbers 'CZ12312312' and 'DZ12312312' located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central | Select-Object -First 3 | Enable-HPECOMIloIgnoreRiskSetting -MinimumPasswordLength -PasswordComplexity

    The first command retrieves all servers in the 'eu-central' region. The second command selects the first three servers.
    The third command enables the ignore iLO security risk settings "Minimum Password Length" and "Password Complexity" on the selected servers.
 
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

    #>

    [CmdletBinding()]
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

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('ServerSerialNumber', 'serial', 'serialnumber')]
        [ValidateNotNullOrEmpty()]
        [String]$ServerName,

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
  
            associatedResource     = $ServerName
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

        $ServerIloSecurityStatus = $null

        try {
            $ServerIloSecurityStatus = Get-HPECOMIloSecuritySatus -Region $Region -ServerName $ServerName -ErrorAction SilentlyContinue
        
        }
        catch {

            $objStatus.state = "ERROR"
            $objStatus.duration = '00:00:00'
            $objStatus.resultCode = "FAILURE"
            $objStatus.Status = "Failed"
            $objStatus.message = $_.Exception.Message -replace "`r`n", " " -replace "`n", " " -replace "`r", " "

            if ($WhatIf) {
                $ErrorMessage = "Unable to retrieve iLO security parameters details for '$ServerName'. Please check the iLO event logs for more details."
                Write-Warning "$ErrorMessage Cannot display API request."
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
                    $SettingName = $_ | ForEach-Object name
                    $ID = $_ | ForEach-Object id

                    $PayloadSetting = New-Setting $SettingName $ID
                    [void]$objStatus.ignoreSecuritySettings.add($PayloadSetting)

                    "[{0}] Ignore iLO security risk setting '{1}' enabled for server '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SettingName, $ServerName | Write-Verbose
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
                        $SettingName = $ServerIloSecurityStatus | Where-Object name -eq $setting.Name | ForEach-Object name
                        $ID = $ServerIloSecurityStatus | Where-Object name -eq $setting.Name | ForEach-Object id
    
                        if ($SettingName) {
                            $PayloadSetting = New-Setting $SettingName $ID
                            [void]$objStatus.ignoreSecuritySettings.add($PayloadSetting)
    
                            "[{0}] Ignore iLO security risk setting '{1}' enabled for server '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $setting.Name, $ServerName | Write-Verbose
                        } 
                        else {
    
                            Write-Warning "The iLO security risk setting '$($setting.Name)' is not available for server '$ServerName'. This setting will be ignored."
                        }
                    }
                }
            }            
        }
       
        # Add tracking object to the list of object status list
        [void]$ObjectStatusList.Add($objStatus)

    }

    end {       

        if (-not $Region) { Return }
        
        
        foreach ($Resource in $ObjectStatusList) {

            if ($Resource.state -eq "ERROR") {
                continue
            }
            else {
                
                try {
                    $Server = Get-HPECOMServer -Region $Region -Name $Resource.associatedResource
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }

                if (-not $Server) {
                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.Status = "Warning"
                    $Resource.message = "Server '$($Resource.associatedResource)' cannot be found in the Compute Ops Management instance."
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Resource.message | Write-Verbose
                    if ($WhatIf) {
                        $ErrorMessage = "Server '$($Resource.associatedResource)' cannot be found in the Compute Ops Management instance."
                        Write-Warning "$ErrorMessage Cannot display API request."
                        continue
                    }
                }
                elseif ($Server.connectionType -eq "ONEVIEW") {
                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.Status = "Warning"
                    $Resource.message = "The iLO security settings are not supported on this server."
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Resource.message | Write-Verbose
                    if ($WhatIf) {
                        $ErrorMessage = "'{0}': The iLO security settings are not supported for OneView managed servers." -f $Resource.associatedResource
                        Write-Warning "$ErrorMessage Cannot display API request."
                        continue
                    }
                }
    
                else {
    
                    # Skip if no valid settings were resolved
                    if ($Resource.ignoreSecuritySettings.Count -eq 0) {
                        $Resource.state = "WARNING"
                        $Resource.duration = '00:00:00'
                        $Resource.resultCode = "FAILURE"
                        $Resource.Status = "Warning"
                        $Resource.message = "None of the requested iLO security risk settings are available for server '$($Resource.associatedResource)'. No changes were made."
                        "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Resource.message | Write-Verbose
                        if ($WhatIf) {
                            Write-Warning "$($Resource.message) Cannot display API request."
                        }
                        continue
                    }

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
        
    .PARAMETER Name
    Name, hostname, or serial number of the server on which the ignore iLO security risk will be disabled.
        
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
    Disable-HPECOMIloIgnoreRiskSetting -Region eu-central -Name "CZ12312312" -AccessPanelStatus -AuthenticationFailureLogging

    This command disables the ignore iLO security risk settings "Access Panel Status" and "Authentication Failure Logging" on the server with name or serial number 'CZ12312312' located in the `eu-central` region. 
   
    .EXAMPLE
    Disable-HPECOMIloIgnoreRiskSetting -Region eu-central -Name "CZ12312312" -AccessPanelStatus -AuthenticationFailureLogging -DefaultSSLCertificateInUse -IPMIDCMIOverLAN -LastFirmwareScanResult -MinimumPasswordLength -PasswordComplexity -RequireHostAuthentication -RequireLoginforiLORBSU -SecureBoot -SecurityOverrideSwitch -SNMPv1 

    This command disables all ignore iLO security risk settings on the server with name or serial number 'CZ12312312' located in the `eu-central` region. 

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -ConnectionType Direct | Disable-HPECOMIloIgnoreRiskSetting -All 

    This command disables all ignore iLO security risk settings on the servers with a direct connection type located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-1 | Disable-HPECOMIloIgnoreRiskSetting -AccessPanelStatus -AuthenticationFailureLogging -DefaultSSLCertificateInUse

    This command disables the ignore iLO security risk settings "Access Panel Status", "Authentication Failure Logging", and "Default SSL Certificate In Use" on the server named 'ESX-1' located in the `eu-central` region.

    .EXAMPLE
    "CZ12312312", "DZ12312312" | Disable-HPECOMIloIgnoreRiskSetting -Region eu-central -MinimumPasswordLength

    This command disables the ignore iLO security risk setting "Minimum Password Length" on the servers with names or serial numbers 'CZ12312312' and 'DZ12312312' located in the `eu-central` region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central | Select-Object -First 3 | Disable-HPECOMIloIgnoreRiskSetting -MinimumPasswordLength -PasswordComplexity

    The first command retrieves all servers in the 'eu-central' region. The second command selects the first three servers.
    The third command disables the ignore iLO security risk settings "Minimum Password Length" and "Password Complexity" on the selected servers.
 
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

    #>

    [CmdletBinding()]
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

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('ServerSerialNumber', 'serial', 'serialnumber')]
        [ValidateNotNullOrEmpty()]
        [String]$ServerName,

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
  
            associatedResource     = $ServerName
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

        $ServerIloSecurityStatus = $null

        try {
            $ServerIloSecurityStatus = Get-HPECOMIloSecuritySatus -Region $Region -ServerName $ServerName -ErrorAction SilentlyContinue
        
        }
        catch {

            $objStatus.state = "ERROR"
            $objStatus.duration = '00:00:00'
            $objStatus.resultCode = "FAILURE"
            $objStatus.Status = "Failed"
            $objStatus.message = $_.Exception.Message -replace "`r`n", " " -replace "`n", " " -replace "`r", " "

            if ($WhatIf) {
                $ErrorMessage = "Unable to retrieve iLO security parameters details for '$ServerName'. Please check the iLO event logs for more details."
                Write-Warning "$ErrorMessage Cannot display API request."
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
                    $SettingName = $_ | ForEach-Object name
                    $ID = $_ | ForEach-Object id

                    $PayloadSetting = New-Setting $SettingName $ID
                    [void]$objStatus.ignoreSecuritySettings.add($PayloadSetting)

                    "[{0}] Ignore iLO security risk setting '{1}' disabled for server '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SettingName, $ServerName | Write-Verbose
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
                        $SettingName = $ServerIloSecurityStatus | Where-Object name -eq $setting.Name | ForEach-Object name
                        $ID = $ServerIloSecurityStatus | Where-Object name -eq $setting.Name | ForEach-Object id

                        if ($SettingName) {
                            $PayloadSetting = New-Setting $SettingName $ID
                            [void]$objStatus.ignoreSecuritySettings.add($PayloadSetting)

                            "[{0}] Ignore iLO security risk setting '{1}' disabled for server '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $setting.Name, $ServerName | Write-Verbose
                        } 
                        else {

                            Write-Warning "The iLO security risk setting '$($setting.Name)' is not available for server '$ServerName'. This setting will be ignored."
                        }
                    }
                }
            }            
        }
       
        # Add tracking object to the list of object status list
        [void]$ObjectStatusList.Add($objStatus)

    }

    end {       

        if (-not $Region) { Return }
        
        
        foreach ($Resource in $ObjectStatusList) {

            if ($Resource.state -eq "ERROR") {
                continue
            }
            else {
                
                try {
                    $Server = Get-HPECOMServer -Region $Region -Name $Resource.associatedResource
                }
                catch {
                    $PSCmdlet.ThrowTerminatingError($_)
                }

                if (-not $Server) {
                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.Status = "Warning"
                    $Resource.message = "Server '$($Resource.associatedResource)' cannot be found in the Compute Ops Management instance."
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Resource.message | Write-Verbose
                    if ($WhatIf) {
                        $ErrorMessage = "Server '$($Resource.associatedResource)' cannot be found in the Compute Ops Management instance."
                        Write-Warning "$ErrorMessage Cannot display API request."
                        continue
                    }
                }
                elseif ($Server.connectionType -eq "ONEVIEW") {
                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.Status = "Warning"
                    $Resource.message = "The iLO security settings are not supported on this server."
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Resource.message | Write-Verbose
                    if ($WhatIf) {
                        $ErrorMessage = "'{0}': The iLO security settings are not supported for OneView managed servers." -f $Resource.associatedResource
                        Write-Warning "$ErrorMessage Cannot display API request."
                        continue
                    }
                }
    
                else {
    
                    # Skip if no valid settings were resolved
                    if ($Resource.ignoreSecuritySettings.Count -eq 0) {
                        $Resource.state = "WARNING"
                        $Resource.duration = '00:00:00'
                        $Resource.resultCode = "FAILURE"
                        $Resource.Status = "Warning"
                        $Resource.message = "None of the requested iLO security risk settings are available for server '$($Resource.associatedResource)'. No changes were made."
                        "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Resource.message | Write-Verbose
                        if ($WhatIf) {
                            Write-Warning "$($Resource.message) Cannot display API request."
                        }
                        continue
                    }

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

Function Set-HPECOMServerUIDIndicator {
    <#
    .SYNOPSIS
    Set the UID indicator LED state for a server.

    .DESCRIPTION
    This cmdlet turns the Unit Identification (UID) indicator LED on or off for a server.
    The UID LED helps physically locate a server in a data center.
    It provides options for scheduling the execution at a specific time and setting recurring schedules.

    Note: If an approval policy is active for this server's group, this operation may require approval before the job executes.
          Use 'Get-HPECOMApprovalRequest -State PENDING' to check for pending requests and 'Resolve-HPECOMApprovalRequest' to approve or decline.

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the server is located.
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name
    Specifies the name or serial number of the server for which to set the UID indicator LED state. Accepts server names (hostname/DNS name) or serial numbers.

    .PARAMETER State
    Specifies the desired state of the UID indicator LED. Accepted values are 'ON' and 'OFF'.

    .PARAMETER ScheduleTime
    Specifies the date and time when the UID indicator operation should be executed.
    This parameter accepts a DateTime object or a string representation of a date and time.
    If not specified, the operation will be executed immediately.

    Examples for setting the date and time using `Get-Date`:
    - (Get-Date).AddMonths(6)
    - (Get-Date).AddDays(15)
    - (Get-Date).AddHours(3)
    Example for using a specific date string:
    - "2024-05-20 08:00:00"

    .PARAMETER Interval
    Specifies the interval at which the UID indicator operation should be repeated.

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
    Set-HPECOMServerUIDIndicator -Region us-west -Name CZ12312312 -State ON

    This command turns on the UID indicator LED for the server with serial number 'CZ12312312' in the 'us-west' region and waits for the job to complete before returning the job resource object.

    .EXAMPLE
    Set-HPECOMServerUIDIndicator -Region eu-central -Name ESX-1 -State OFF

    This command turns off the UID indicator LED for the server named 'ESX-1' in the 'eu-central' region and waits for the job to complete.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-1 | Set-HPECOMServerUIDIndicator -State ON -Async

    This command turns on the UID indicator LED for the server named 'ESX-1' and immediately returns the asynchronous job resource to monitor.

    .EXAMPLE
    Get-HPECOMServer -Region us-west -ConnectionType Direct | Set-HPECOMServerUIDIndicator -State ON

    This command turns on the UID indicator LED for all directly managed servers in the 'us-west' region.

    .EXAMPLE
    "CZ12312312", "DZ12312312" | Set-HPECOMServerUIDIndicator -Region eu-central -State ON

    This command turns on the UID indicator LED for the servers with serial numbers 'CZ12312312' and 'DZ12312312' in the 'eu-central' region.

    .EXAMPLE
    Set-HPECOMServerUIDIndicator -Region eu-central -Name CZ12312312 -State ON -ScheduleTime (Get-Date).AddHours(6)

    This command schedules the UID indicator LED to be turned on for the server with serial number 'CZ12312312' in the 'eu-central' region, six hours from the current time.

    .EXAMPLE
    Set-HPECOMServerUIDIndicator -Region eu-central -Name CZ12312312 -State ON -ScheduleTime (Get-Date).AddHours(6) -Interval P1W

    Schedules a weekly UID-on operation for the server with serial number 'CZ12312312' in the 'eu-central' region. The first execution will occur six hours from the current time.

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

    HPEGreenLake.COM.Schedules.Status [System.Management.Automation.PSCustomObject]

        - The schedule job object that includes the schedule details when `-ScheduleTime` is used.


   #>

    [CmdletBinding(DefaultParameterSetName = 'SerialNumber')]
    Param(

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
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

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SerialNumber')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ScheduleSerialNumber')]
        [Alias('ServerSerialNumber', 'serial', 'serialnumber')]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

        [Parameter (Mandatory)]
        [ValidateSet('ON', 'OFF')]
        [String]$State,

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
            if ($_ -notmatch '^P(?!$)(\d+Y)?(\d+M)?(\d+W)?(\d+D)?(T(\d+H)?(\d+M)?(\d+S)?)?$') {
                throw "Invalid duration format. Please use an ISO 8601 period interval (e.g., P1D, P1W, P1M, P1Y, PT1H, PT15M)"
            }

            $years   = [int]($matches[1] -replace '\D', '')
            $months  = [int]($matches[2] -replace '\D', '')
            $weeks   = [int]($matches[3] -replace '\D', '')
            $days    = [int]($matches[4] -replace '\D', '')
            $hours   = [int]($matches[6] -replace '\D', '')
            $minutes = [int]($matches[7] -replace '\D', '')
            $seconds = [int]($matches[8] -replace '\D', '')

            $totalSeconds = 0
            if ($years)   { $totalSeconds += $years * 365 * 24 * 3600 }
            if ($months)  { $totalSeconds += $months * 30 * 24 * 3600 }
            if ($weeks)   { $totalSeconds += $weeks * 7 * 24 * 3600 }
            if ($days)    { $totalSeconds += $days * 24 * 3600 }
            if ($hours)   { $totalSeconds += $hours * 3600 }
            if ($minutes) { $totalSeconds += $minutes * 60 }
            if ($seconds) { $totalSeconds += $seconds }

            $minSeconds = 15 * 60
            $maxSeconds = 365 * 24 * 3600

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

        if ($State -eq 'ON') {
            $_JobTemplateName = 'UidIndicatorOn'
        }
        else {
            $_JobTemplateName = 'UidIndicatorOff'
        }

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
                description        = "Scheduled task to turn $($State.ToLower()) the UID indicator LED for server '$Name'"
                associatedResource = $Name
                purpose            = "SERVER_UID_INDICATOR_$State"
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
                associatedResource = $Name
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
            $Servers = Get-HPECOMServer -Region $Region
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }


        foreach ($Resource in $ObjectStatusList) {

            $Server = $Servers | Where-Object { $_.name -eq $Resource.associatedResource -or $_.host.hostname -eq $Resource.associatedResource -or $_.hardware.serialNumber -eq $Resource.associatedResource }

            if (-not $Server) {

                $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Resource.associatedResource
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = $ErrorMessage

                }
                else {

                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Warning"
                    $Resource.message = $ErrorMessage
                }

                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }
            }
            elseif ($State -eq 'ON' -and $Server.hardware.indicatorLed -eq 'LIT') {

                $ErrorMessage = "Server '{0}': UID indicator LED is already on!" -f $Resource.associatedResource
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = $ErrorMessage

                }
                else {

                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Warning"
                    $Resource.message = $ErrorMessage
                }

                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }
            }
            elseif ($State -eq 'OFF' -and $Server.hardware.indicatorLed -eq 'OFF') {

                $ErrorMessage = "Server '{0}': UID indicator LED is already off!" -f $Resource.associatedResource
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = $ErrorMessage

                }
                else {

                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Warning"
                    $Resource.message = $ErrorMessage
                }

                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
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
                    }

                    $Operation = @{
                        type   = "REST"
                        method = "POST"
                        uri    = "/api/compute/v1/jobs"
                        body   = $_Body
                    }

                    $randomNumber = Get-Random -Minimum 000000 -Maximum 999999

                    $ScheduleName = "$($Name)_ServerUIDIndicator${State}_Schedule_$($randomNumber)"
                    $Resource.name = $ScheduleName

                    $Description = $Resource.description

                    if ($Interval) {

                        $Schedule = @{
                            startAt  = $ScheduleTime.ToString("o")
                            interval = $Interval
                        }
                    }
                    else {

                        $Schedule = @{
                            startAt  = $ScheduleTime.ToString("o")
                            interval = $Null
                        }
                    }

                    $Resource.schedule = $Schedule

                    $payload = @{
                        name                  = $ScheduleName
                        description           = $Description
                        associatedResourceUri = $_serverResourceUri
                        purpose               = "SERVER_UID_INDICATOR_$State"
                        schedule              = $Schedule
                        operation             = $Operation
                    }

                }
                else {

                    $payload = @{
                        jobTemplate  = $JobTemplateId
                        resourceId   = $_serverId
                        resourceType = "compute-ops-mgmt/server"
                        jobParams    = @{}
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
                            $Resource.message = "The schedule to turn $($State.ToLower()) the UID indicator LED has been successfully created."

                        }

                    }
                    else {

                        if (-not $WhatIf -and $_resp.state -eq 'APPROVAL_PENDING') {
                            Write-Warning "Server '$($Resource.associatedResource)': Job is pending approval. Use 'Get-HPECOMApprovalRequest -State PENDING' to view pending requests and 'Resolve-HPECOMApprovalRequest' to approve or decline."
                        }
                        elseif (-not $WhatIf -and -not $Async) {

                            "[{0}] Running Wait-HPECOMJobComplete -Region '{1}' -Job '{2}' -Timeout '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region, ($_resp.resourceuri), $Timeout | Write-Verbose

                            $_resp = Wait-HPECOMJobComplete -Region $Region -Job $_resp.resourceuri -Timeout $Timeout

                            "[{0}] Response returned: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_resp | Write-Verbose

                        }

                        if (-not $WhatIf ) {

                            if ($_resp -and $_resp.PSObject.Properties.Name -contains 'createdAt' -and $_resp.PSObject.Properties.Name -contains 'updatedAt') {
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

                            $Resource.name = $ScheduleName
                            $Resource.schedule = $Schedule
                            $Resource.resultCode = "FAILURE"
                            $Resource.message = if ($_.Exception.Message) { $_.Exception.Message } else { "Schedule creation failed for server '$($Resource.associatedResource)'!" }

                        }
                        else {

                            $Resource.state = "ERROR"
                            $Resource.duration = '00:00:00'
                            $Resource.resultCode = "FAILURE"
                            $Resource.status = "Failed"
                            $Resource.message = if ($_.Exception.Message) { $_.Exception.Message } else { "Operation failed for server '$($Resource.associatedResource)'!" }
                            $Resource.details = $Global:HPECOMInvokeReturnData
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

Function Enable-HPECOMServerMaintenanceMode {
    <#
    .SYNOPSIS
    Enable maintenance mode for a server.

    .DESCRIPTION
    This cmdlet enables maintenance mode for a server. While maintenance mode is enabled, Compute Ops Management suspends
    automatic support case creation, ServiceNow incident creation, and email notifications for the server. This is useful
    during planned maintenance windows to avoid generating support cases and notifications for expected events.

    Use 'Disable-HPECOMServerMaintenanceMode' to turn maintenance mode off when the maintenance is complete.

    Note: The current maintenance mode state of a server is exposed by the 'maintenanceMode' property returned by
          'Get-HPECOMServer' (visible with Format-List or Select-Object).

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the server is located.
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name
    Specifies the name or serial number of the server for which to enable maintenance mode. Accepts server names (hostname/DNS name) or serial numbers.

    .PARAMETER ScheduleTime
    Specifies the date and time when the enable maintenance mode operation should be executed.
    This parameter accepts a DateTime object or a string representation of a date and time.
    If not specified, the operation will be executed immediately.

    Examples for setting the date and time using `Get-Date`:
    - (Get-Date).AddMonths(6)
    - (Get-Date).AddDays(15)
    - (Get-Date).AddHours(3)
    Example for using a specific date string:
    - "2024-05-20 08:00:00"

    .PARAMETER Interval
    Specifies the interval at which the enable maintenance mode operation should be repeated.

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
    Enable-HPECOMServerMaintenanceMode -Region eu-central -Name CZ12312312

    # Verify that maintenance mode is now enabled on the server
    Get-HPECOMServer -Region eu-central -Name CZ12312312 | Select-Object name, serialNumber, maintenanceMode

    The first command enables maintenance mode for the server with serial number 'CZ12312312' in the 'eu-central' region and waits for the job to complete before returning the job resource object.
    The second command confirms the result by displaying the 'maintenanceMode' property of the server, which should now report 'True'.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-1 | Enable-HPECOMServerMaintenanceMode -Async

    This command enables maintenance mode for the server named 'ESX-1' and immediately returns the asynchronous job resource to monitor.

    .EXAMPLE
    "CZ12312312", "DZ12312312" | Enable-HPECOMServerMaintenanceMode -Region eu-central

    This command enables maintenance mode for the servers with serial numbers 'CZ12312312' and 'DZ12312312' in the 'eu-central' region.

    .EXAMPLE
    Get-HPECOMServer -Region us-west -ConnectionType Direct | Enable-HPECOMServerMaintenanceMode

    This command enables maintenance mode for all directly managed servers in the 'us-west' region.

    .EXAMPLE
    Enable-HPECOMServerMaintenanceMode -Region eu-central -Name CZ12312312 -ScheduleTime (Get-Date).AddHours(6)

    This command schedules maintenance mode to be enabled for the server with serial number 'CZ12312312' in the 'eu-central' region, six hours from the current time.

    .EXAMPLE
    Enable-HPECOMServerMaintenanceMode -Region eu-central -Name CZ12312312 -ScheduleTime (Get-Date).AddHours(6) -Interval P1W

    Schedules a weekly enable-maintenance-mode operation for the server with serial number 'CZ12312312' in the 'eu-central' region. The first execution will occur six hours from the current time.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -InMaintenanceMode

    This command lists all servers in the 'eu-central' region that are currently in maintenance mode, using the '-InMaintenanceMode' filter of 'Get-HPECOMServer'.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.

    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer'.

    .OUTPUTS
    HPEGreenLake.COM.Jobs.Status [System.Management.Automation.PSCustomObject]

        - When the job completes, the returned object contains detailed job status information, including 'state', 'resultCode', 'message', and the full job resource in 'details'.
        - If the '-Async' switch is used, the cmdlet returns the job resource immediately, allowing you to monitor its progress using the 'state' and 'resultCode' properties, or by passing the job object to 'Wait-HPECOMJobComplete'.

    HPEGreenLake.COM.Schedules.Status [System.Management.Automation.PSCustomObject]

        - The schedule job object that includes the schedule details when '-ScheduleTime' is used.
   #>

    [CmdletBinding(DefaultParameterSetName = 'SerialNumber')]
    Param(

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
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

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SerialNumber')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ScheduleSerialNumber')]
        [Alias('ServerSerialNumber', 'serial', 'serialnumber')]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

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
            if ($_ -notmatch '^P(?!$)(\d+Y)?(\d+M)?(\d+W)?(\d+D)?(T(\d+H)?(\d+M)?(\d+S)?)?$') {
                throw "Invalid duration format. Please use an ISO 8601 period interval (e.g., P1D, P1W, P1M, P1Y, PT1H, PT15M)"
            }

            $years   = [int]($matches[1] -replace '\D', '')
            $months  = [int]($matches[2] -replace '\D', '')
            $weeks   = [int]($matches[3] -replace '\D', '')
            $days    = [int]($matches[4] -replace '\D', '')
            $hours   = [int]($matches[6] -replace '\D', '')
            $minutes = [int]($matches[7] -replace '\D', '')
            $seconds = [int]($matches[8] -replace '\D', '')

            $totalSeconds = 0
            if ($years)   { $totalSeconds += $years * 365 * 24 * 3600 }
            if ($months)  { $totalSeconds += $months * 30 * 24 * 3600 }
            if ($weeks)   { $totalSeconds += $weeks * 7 * 24 * 3600 }
            if ($days)    { $totalSeconds += $days * 24 * 3600 }
            if ($hours)   { $totalSeconds += $hours * 3600 }
            if ($minutes) { $totalSeconds += $minutes * 60 }
            if ($seconds) { $totalSeconds += $seconds }

            $minSeconds = 15 * 60
            $maxSeconds = 365 * 24 * 3600

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

        $_JobTemplateName = 'ServerMaintenanceModeEnable'

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
                description        = "Scheduled task to enable maintenance mode for server '$Name'"
                associatedResource = $Name
                purpose            = "SERVER_MAINTENANCE_MODE_ENABLE"
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
                associatedResource = $Name
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

        [void]$ObjectStatusList.Add($objStatus)

    }

    end {

        try {
            $Servers = Get-HPECOMServer -Region $Region
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }


        foreach ($Resource in $ObjectStatusList) {

            $Server = $Servers | Where-Object { $_.name -eq $Resource.associatedResource -or $_.host.hostname -eq $Resource.associatedResource -or $_.hardware.serialNumber -eq $Resource.associatedResource }

            if (-not $Server) {

                $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Resource.associatedResource
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = $ErrorMessage

                }
                else {

                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Warning"
                    $Resource.message = $ErrorMessage
                }

                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }
            }
            elseif (-not $ScheduleTime -and $Server.maintenanceMode -eq $true) {

                $ErrorMessage = "Server '{0}': Maintenance mode is already enabled!" -f $Resource.associatedResource
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

                $Resource.state = "WARNING"
                $Resource.duration = '00:00:00'
                $Resource.resultCode = "FAILURE"
                $Resource.status = "Warning"
                $Resource.message = $ErrorMessage

                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
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
                    }

                    $Operation = @{
                        type   = "REST"
                        method = "POST"
                        uri    = "/api/compute/v1/jobs"
                        body   = $_Body
                    }

                    $randomNumber = Get-Random -Minimum 000000 -Maximum 999999

                    $ScheduleName = "$($Name)_ServerMaintenanceModeEnable_Schedule_$($randomNumber)"
                    $Resource.name = $ScheduleName

                    $Description = $Resource.description

                    if ($Interval) {

                        $Schedule = @{
                            startAt  = $ScheduleTime.ToString("o")
                            interval = $Interval
                        }
                    }
                    else {

                        $Schedule = @{
                            startAt  = $ScheduleTime.ToString("o")
                            interval = $Null
                        }
                    }

                    $Resource.schedule = $Schedule

                    $payload = @{
                        name                  = $ScheduleName
                        description           = $Description
                        associatedResourceUri = $_serverResourceUri
                        purpose               = "SERVER_MAINTENANCE_MODE_ENABLE"
                        schedule              = $Schedule
                        operation             = $Operation
                    }

                }
                else {

                    $payload = @{
                        jobTemplate  = $JobTemplateId
                        resourceId   = $_serverId
                        resourceType = "compute-ops-mgmt/server"
                        jobParams    = @{}
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
                            $Resource.resultCode = "SUCCESS"
                            $Resource.details = $_resp
                            $Resource.message = "The schedule to enable maintenance mode has been successfully created."

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

                            $Resource.name = $ScheduleName
                            $Resource.schedule = $Schedule
                            $Resource.resultCode = "FAILURE"
                            $Resource.message = if ($_.Exception.Message) { $_.Exception.Message } else { "Schedule creation failed for server '$($Resource.associatedResource)'!" }

                        }
                        else {

                            $Resource.state = "ERROR"
                            $Resource.duration = '00:00:00'
                            $Resource.resultCode = "FAILURE"
                            $Resource.status = "Failed"
                            $Resource.message = if ($_.Exception.Message) { $_.Exception.Message } else { "Operation failed for server '$($Resource.associatedResource)'!" }
                            $Resource.details = $Global:HPECOMInvokeReturnData
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

Function Disable-HPECOMServerMaintenanceMode {
    <#
    .SYNOPSIS
    Disable maintenance mode for a server.

    .DESCRIPTION
    This cmdlet disables maintenance mode for a server. Once maintenance mode is disabled, Compute Ops Management resumes
    automatic support case creation, ServiceNow incident creation, and email notifications for the server. Use this cmdlet
    when a planned maintenance window is complete.

    Use 'Enable-HPECOMServerMaintenanceMode' to turn maintenance mode on before starting maintenance.

    Note: The current maintenance mode state of a server is exposed by the 'maintenanceMode' property returned by
          'Get-HPECOMServer' (visible with Format-List or Select-Object).

    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.) where the server is located.
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Name
    Specifies the name or serial number of the server for which to disable maintenance mode. Accepts server names (hostname/DNS name) or serial numbers.

    .PARAMETER ScheduleTime
    Specifies the date and time when the disable maintenance mode operation should be executed.
    This parameter accepts a DateTime object or a string representation of a date and time.
    If not specified, the operation will be executed immediately.

    Examples for setting the date and time using `Get-Date`:
    - (Get-Date).AddMonths(6)
    - (Get-Date).AddDays(15)
    - (Get-Date).AddHours(3)
    Example for using a specific date string:
    - "2024-05-20 08:00:00"

    .PARAMETER Interval
    Specifies the interval at which the disable maintenance mode operation should be repeated.

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
    Disable-HPECOMServerMaintenanceMode -Region eu-central -Name CZ12312312

    # Verify that maintenance mode is now disabled on the server
    Get-HPECOMServer -Region eu-central -Name CZ12312312 | Select-Object name, serialNumber, maintenanceMode

    The first command disables maintenance mode for the server with serial number 'CZ12312312' in the 'eu-central' region and waits for the job to complete before returning the job resource object.
    The second command confirms the result by displaying the 'maintenanceMode' property of the server, which should now report 'False'.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-1 | Disable-HPECOMServerMaintenanceMode -Async

    This command disables maintenance mode for the server named 'ESX-1' and immediately returns the asynchronous job resource to monitor.

    .EXAMPLE
    "CZ12312312", "DZ12312312" | Disable-HPECOMServerMaintenanceMode -Region eu-central

    This command disables maintenance mode for the servers with serial numbers 'CZ12312312' and 'DZ12312312' in the 'eu-central' region.

    .EXAMPLE
    Disable-HPECOMServerMaintenanceMode -Region eu-central -Name CZ12312312 -ScheduleTime (Get-Date).AddHours(6)

    This command schedules maintenance mode to be disabled for the server with serial number 'CZ12312312' in the 'eu-central' region, six hours from the current time.

    .EXAMPLE
    Disable-HPECOMServerMaintenanceMode -Region eu-central -Name CZ12312312 -ScheduleTime (Get-Date).AddHours(6) -Interval P1W

    Schedules a weekly disable-maintenance-mode operation for the server with serial number 'CZ12312312' in the 'eu-central' region. The first execution will occur six hours from the current time.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -InMaintenanceMode | Disable-HPECOMServerMaintenanceMode

    This command retrieves all servers in the 'eu-central' region that are currently in maintenance mode (using the '-InMaintenanceMode' filter of 'Get-HPECOMServer') and disables maintenance mode on each of them.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.

    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer'.

    .OUTPUTS
    HPEGreenLake.COM.Jobs.Status [System.Management.Automation.PSCustomObject]

        - When the job completes, the returned object contains detailed job status information, including 'state', 'resultCode', 'message', and the full job resource in 'details'.
        - If the '-Async' switch is used, the cmdlet returns the job resource immediately, allowing you to monitor its progress using the 'state' and 'resultCode' properties, or by passing the job object to 'Wait-HPECOMJobComplete'.

    HPEGreenLake.COM.Schedules.Status [System.Management.Automation.PSCustomObject]

        - The schedule job object that includes the schedule details when '-ScheduleTime' is used.
   #>

    [CmdletBinding(DefaultParameterSetName = 'SerialNumber')]
    Param(

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
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

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SerialNumber')]
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'ScheduleSerialNumber')]
        [Alias('ServerSerialNumber', 'serial', 'serialnumber')]
        [ValidateNotNullOrEmpty()]
        [String]$Name,

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
            if ($_ -notmatch '^P(?!$)(\d+Y)?(\d+M)?(\d+W)?(\d+D)?(T(\d+H)?(\d+M)?(\d+S)?)?$') {
                throw "Invalid duration format. Please use an ISO 8601 period interval (e.g., P1D, P1W, P1M, P1Y, PT1H, PT15M)"
            }

            $years   = [int]($matches[1] -replace '\D', '')
            $months  = [int]($matches[2] -replace '\D', '')
            $weeks   = [int]($matches[3] -replace '\D', '')
            $days    = [int]($matches[4] -replace '\D', '')
            $hours   = [int]($matches[6] -replace '\D', '')
            $minutes = [int]($matches[7] -replace '\D', '')
            $seconds = [int]($matches[8] -replace '\D', '')

            $totalSeconds = 0
            if ($years)   { $totalSeconds += $years * 365 * 24 * 3600 }
            if ($months)  { $totalSeconds += $months * 30 * 24 * 3600 }
            if ($weeks)   { $totalSeconds += $weeks * 7 * 24 * 3600 }
            if ($days)    { $totalSeconds += $days * 24 * 3600 }
            if ($hours)   { $totalSeconds += $hours * 3600 }
            if ($minutes) { $totalSeconds += $minutes * 60 }
            if ($seconds) { $totalSeconds += $seconds }

            $minSeconds = 15 * 60
            $maxSeconds = 365 * 24 * 3600

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

        $_JobTemplateName = 'ServerMaintenanceModeDisable'

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
                description        = "Scheduled task to disable maintenance mode for server '$Name'"
                associatedResource = $Name
                purpose            = "SERVER_MAINTENANCE_MODE_DISABLE"
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
                associatedResource = $Name
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

        [void]$ObjectStatusList.Add($objStatus)

    }

    end {

        try {
            $Servers = Get-HPECOMServer -Region $Region
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }


        foreach ($Resource in $ObjectStatusList) {

            $Server = $Servers | Where-Object { $_.name -eq $Resource.associatedResource -or $_.host.hostname -eq $Resource.associatedResource -or $_.hardware.serialNumber -eq $Resource.associatedResource }

            if (-not $Server) {

                $ErrorMessage = "Server '{0}': Resource cannot be found in the Compute Ops Management instance!" -f $Resource.associatedResource
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

                if ($ScheduleTime) {

                    $Resource.resultCode = "FAILURE"
                    $Resource.message = $ErrorMessage

                }
                else {

                    $Resource.state = "WARNING"
                    $Resource.duration = '00:00:00'
                    $Resource.resultCode = "FAILURE"
                    $Resource.status = "Warning"
                    $Resource.message = $ErrorMessage
                }

                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }
            }
            elseif (-not $ScheduleTime -and $Server.maintenanceMode -ne $true) {

                $ErrorMessage = "Server '{0}': Maintenance mode is already disabled!" -f $Resource.associatedResource
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

                $Resource.state = "WARNING"
                $Resource.duration = '00:00:00'
                $Resource.resultCode = "FAILURE"
                $Resource.status = "Warning"
                $Resource.message = $ErrorMessage

                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
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
                    }

                    $Operation = @{
                        type   = "REST"
                        method = "POST"
                        uri    = "/api/compute/v1/jobs"
                        body   = $_Body
                    }

                    $randomNumber = Get-Random -Minimum 000000 -Maximum 999999

                    $ScheduleName = "$($Name)_ServerMaintenanceModeDisable_Schedule_$($randomNumber)"
                    $Resource.name = $ScheduleName

                    $Description = $Resource.description

                    if ($Interval) {

                        $Schedule = @{
                            startAt  = $ScheduleTime.ToString("o")
                            interval = $Interval
                        }
                    }
                    else {

                        $Schedule = @{
                            startAt  = $ScheduleTime.ToString("o")
                            interval = $Null
                        }
                    }

                    $Resource.schedule = $Schedule

                    $payload = @{
                        name                  = $ScheduleName
                        description           = $Description
                        associatedResourceUri = $_serverResourceUri
                        purpose               = "SERVER_MAINTENANCE_MODE_DISABLE"
                        schedule              = $Schedule
                        operation             = $Operation
                    }

                }
                else {

                    $payload = @{
                        jobTemplate  = $JobTemplateId
                        resourceId   = $_serverId
                        resourceType = "compute-ops-mgmt/server"
                        jobParams    = @{}
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
                            $Resource.resultCode = "SUCCESS"
                            $Resource.details = $_resp
                            $Resource.message = "The schedule to disable maintenance mode has been successfully created."

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

                            $Resource.name = $ScheduleName
                            $Resource.schedule = $Schedule
                            $Resource.resultCode = "FAILURE"
                            $Resource.message = if ($_.Exception.Message) { $_.Exception.Message } else { "Schedule creation failed for server '$($Resource.associatedResource)'!" }

                        }
                        else {

                            $Resource.state = "ERROR"
                            $Resource.duration = '00:00:00'
                            $Resource.resultCode = "FAILURE"
                            $Resource.status = "Failed"
                            $Resource.message = if ($_.Exception.Message) { $_.Exception.Message } else { "Operation failed for server '$($Resource.associatedResource)'!" }
                            $Resource.details = $Global:HPECOMInvokeReturnData
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

Set-Alias -Name 'Update-HPECOMGroupFirmware'                       -Value 'Update-HPECOMGroupServerFirmware'
Set-Alias -Name 'Stop-HPECOMGroupFirmware'                         -Value 'Stop-HPECOMGroupServerFirmware'
Set-Alias -Name 'Invoke-HPECOMGroupFirmwareComplianceCheck'        -Value 'Invoke-HPECOMGroupServerFirmwareComplianceCheck'
Set-Alias -Name 'Get-HPECOMGroupFirmwareCompliance'                -Value 'Get-HPECOMGroupServerFirmwareCompliance'
Set-Alias -Name 'Invoke-HPECOMGroupInternalStorageConfiguration'  -Value 'Invoke-HPECOMGroupServerInternalStorageConfiguration'
Set-Alias -Name 'Invoke-HPECOMGroupOSInstallation'                -Value 'Invoke-HPECOMGroupServerOSInstallation'
Set-Alias -Name 'Invoke-HPECOMGroupBiosConfiguration'             -Value 'Invoke-HPECOMGroupServerBiosConfiguration'
Set-Alias -Name 'Invoke-HPECOMGroupiLOConfiguration'              -Value 'Invoke-HPECOMGroupServeriLOConfiguration'
Set-Alias -Name 'Invoke-HPECOMGroupiLOConfigurationCompliance'    -Value 'Invoke-HPECOMGroupServeriLOConfigurationCompliance'
Set-Alias -Name 'Get-HPECOMGroupiLOConfigurationCompliance'       -Value 'Get-HPECOMGroupServeriLOConfigurationCompliance'
Set-Alias -Name 'Invoke-HPECOMGroupExternalStorageConfiguration'  -Value 'Invoke-HPECOMGroupServerExternalStorageConfiguration'
Set-Alias -Name 'Invoke-HPECOMGroupExternalStorageComplianceCheck' -Value 'Invoke-HPECOMGroupServerExternalStorageComplianceCheck'


# Export only public functions and aliases
Export-ModuleMember -Function `
    'Wait-HPECOMJobComplete',
    'Get-HPECOMJob',
    'Start-HPECOMserver',
    'Restart-HPECOMserver',
    'Stop-HPECOMserver',
    'Update-HPECOMServerFirmware',
    'Update-HPECOMServeriLOFirmware',
    'Invoke-HPECOMServerFirmwareDownload',
    'Invoke-HPECOMGroupServerFirmwareDownload',
    'Update-HPECOMGroupServerFirmware',
    'Stop-HPECOMGroupServerFirmware',
    'Invoke-HPECOMGroupServerFirmwareComplianceCheck',
    'Get-HPECOMGroupServerFirmwareCompliance',
    'Invoke-HPECOMServerExternalStorage',
    'Invoke-HPECOMGroupServerInternalStorageConfiguration',
    'Invoke-HPECOMGroupServerOSInstallation',
    'Invoke-HPECOMGroupServerBiosConfiguration',
    'Invoke-HPECOMGroupServerExternalStorageConfiguration',
    'Invoke-HPECOMGroupServeriLOConfiguration',
    'Invoke-HPECOMGroupServeriLOConfigurationCompliance',
    'Get-HPECOMGroupServeriLOConfigurationCompliance',
    'Invoke-HPECOMGroupServerExternalStorageComplianceCheck',
    'Update-HPECOMApplianceFirmware',
    'Update-HPECOMGroupApplianceFirmware',
    'Invoke-HPECOMGroupApplianceSettings',
    'Copy-HPECOMGroupApplianceServerProfileTemplate',
    'Get-HPECOMIloSecuritySatus',
    'Enable-HPECOMIloIgnoreRiskSetting',
    'Disable-HPECOMIloIgnoreRiskSetting',
    'Set-HPECOMServerUIDIndicator',
    'Enable-HPECOMServerMaintenanceMode',
    'Disable-HPECOMServerMaintenanceMode' `
    -Alias *







# SIG # Begin signature block
# MIIn2gYJKoZIhvcNAQcCoIInyzCCJ8cCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCCUaAO8wsQ4nZna
# CcmWjLNKdXRqgMKSxPTdqgDG7LDD26CCDIMwggYaMIIEAqADAgECAhBiHW0MUgGe
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
# 7uKis13LpRUBToRPB/02zord9Le1LZjs+rDR+5zVX+EwDQYJKoZIhvcNAQEBBQAE
# ggIARQJXhFH1z04phDSoyl7aV637jrgl3OX2jWx4Bmcvtv0ANOFUV2FxihZfy1of
# 7hCr/lqpN9IGVHc2YUmdFxqdJA0cExr7weXnqst6xYxGo50js/KUt824naXmLvt7
# 1HR7VHibtwuTNy5WB9w4kj4MmOyWMFRaVRtixAAHF7lFMvmWlZtkHi4e4VcO4VGI
# L/ENnHmLeskmEZj3//TWf1bM4arXGwcRFgxrV59VQpIm9puWWAWB9EMuy773GFJE
# tHCJHPAEcH2OXZJ/HQOypeQQFb4ofdzjJ5d+a/sSs6pAmv/+6r1CaxKlUCU4HJ/3
# nOKyectFuLixY5cuxRQxwbBU9TtqMaE/u6EEL5EcmSJ12TSasIaKLaF4mo6u5GoP
# F4vPrPLtZGtFQ0ZNa3tUDLMmn4w39PS5+NU0X3/EvmSGGqtewFrwidAsyjYAz4jS
# zim3SkPFkOMlYVSaTnrTj9C9v2tmF0SYGB2rHVmOcY3ZmugjhgCAM2tBc1C7nYNf
# v94sp7bAfLJs4M/vxue5Nt/ZZf05spplxwWReSt345qu4LIJabBGuFvNPkQifUte
# 9cxcQY1a0GfmJBdAzmsG+QDNNWP7YQAvuQWNMPzFZFay1muYX9iQR6FpbBVzEJyd
# /OAWbp02ipDWz1upnlDzCCCXWn4NKSxxBHbHOMeTK62XQHyhgheXMIIXkwYKKwYB
# BAGCNwMDATGCF4Mwghd/BgkqhkiG9w0BBwKgghdwMIIXbAIBAzEPMA0GCWCGSAFl
# AwQCAgUAMIGHBgsqhkiG9w0BCRABBKB4BHYwdAIBAQYJYIZIAYb9bAcBMEEwDQYJ
# YIZIAWUDBAICBQAEMPb/PV0CBl5inXg+OW/RIzXga3mWHFQoLboUuKS/jKJAB3LS
# tE0FZpXlG5A2+el7oAIQXoaB4iCQa3Dv6muhSv5S0hgPMjAyNjExMjMwODQwNTha
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
# SIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjYxMTIzMDg0
# MDU4WjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBTpqKcjtIUE9eDhQ4tnPs6HzyxQ
# mzA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCBxHdd7HC5xsmHXVY1pnAB3yX0SAzCa
# YI7cEFY0wVBQezA/BgkqhkiG9w0BCQQxMgQwp4fxE9T9KyV+eOp61vQkKKGV++I+
# 3EhVqjh5c4XPYFMKtSAUD0l1Sqz0KJc9NaBlMA0GCSqGSIb3DQEBAQUABIICAGtX
# 8FPFBSoAB2gb2tA5V51ZoChKdHoU1kb2XEeas6yoe0rWPAeJXN3kbkeHoA2/Gae7
# JhxZ/0QUz6GjDpv09Sj6N46m62KYVsz2P4MQBcYS+iVdmWvNWBIHADLw1ja0xVBj
# MKQeRCMRwdG437OuSLaBV+ExU3VpPI/i1fCmIlDNB6MQ0r9FLIcD4dKNMzArwuYg
# R77M6VTjh4ERb0RqJ8sqe6pDwKY1V9116sk7TfcK5Ri/6cIJA0VKy8bC8aT9usyc
# LL1HHg4AITrqjYDJetTX9drpH8/0y+M1GD/5/O2HtQbJW4Anj9x3RMv+NeaG6Hxr
# EvxfhkwycZyzGmB+cM7hqbk6GI0crm5IBWGtMTM6MeIxA1MWO2kSncw22D+eVdJQ
# rShe+ngBT5DaqxNPj8W1qa5TPDpiRWocoonuVFHnhu5B3/+77OINQEK2Vplk2SZU
# x8iZaqKr/2rJolD6gzakHXBXrkZVxZ0lIZbhY6gxCttsqHT6Nfi5JZDquZwQMvbA
# X+YqmVbZZP+YY0u/UaflurxP4RJXDALfwVjC05BafZhWoFguUxl0q9/fUh6+KCOA
# w6VC7hpbZ/ntiO/d3R1ZhNAMPFVHZDHr6V5ziJwQuuzsRn3GrSDeXjPzLjv50b4a
# Ag1bED1UZYIQKz8bmLECDyGYGBFVsHSWBOBISBEg
# SIG # End signature block
