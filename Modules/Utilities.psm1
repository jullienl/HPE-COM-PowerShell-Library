#Region ------------------- GENERIC UTILITY FUNCTIONS -------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1

# Public functions
function Invoke-HPEGLWebRequest {  
    <#
    .SYNOPSIS
    Cmdlet to run web requests to the HPE Greenlake APIs. 

    .DESCRIPTION
    The `Invoke-HPEGLWebRequest` cmdlet sends HTTPS requests to the HPE Greenlake APIs. It adds the required headers, session, parses the response and returns the response.

    Upon execution, the cmdlet checks for an active HPE GreenLake session. If no session is found, it prompts the user to connect using 'Connect-HPEGL'.
    The cmdlet also supports automatic reconnection if the session has expired, ensuring seamless interaction with the API.
    The cmdlet supports pagination for GET requests, automatically retrieving all pages of results when applicable. It handles errors gracefully, providing informative messages for both critical and non-critical issues encountered during pagination.
    The cmdlet supports auto-completion for the 'Region' parameter, allowing users to easily select from available Compute Ops Management regions in their workspace.

    Upon successful execution, the cmdlet sets the `$Global:HPECOMInvokeReturnData` variable to the full response object, allowing users to access detailed information about the request and response. 
    If an error occurs, the variable is set to the error response object for further inspection.

    .PARAMETER Uri
    The absolute uri that identifies the required HPE GreenLake resource (eg. '/ui-doorway/ui/v1/license/devices').

    .PARAMETER Body
    Body for the request. Required if the method is POST or PUT.

    .PARAMETER Method
    The request HTTP Method.
     - "GET" (default) to get a resource from the appliance (read)
     - "POST" to create a new resource
     - "PUT" to modify a resource (write)
     - "PATCH" to modify a resource (write), with specific attributes set to values, other attributes should be set to $null.
     - "DELETE" to delete a resource

    .PARAMETER WebSession
    Web session object containing information about the HPE GreenLake session, including cookies and credentials.
    Default uses $Global:HPEGreenLakeSession.WorkspaceSession global variable.

    .PARAMETER SkipSessionCheck
    Switch parameter to skip the session check. This parameter is used internally by certain cmdlets (such as Get-HPEGLWorkspace, New-HPEGLWorkspace, 
    Get-HPEGLUserAccountDetails, Set-HPEGLUserAccountDetails, and Set-HPEGLUserAccountPassword) when Connect-HPEGLWorkspace has not yet been executed 
    (i.e., when no workspace session exists). It allows these cmdlets to run without requiring an active workspace session.
    
    .PARAMETER MaxRetries
    The maximum number of retries to attempt if the request fails. Default is 5.

    .PARAMETER InitialDelaySeconds
    The initial delay in seconds before the first retry attempt. Default is 1.

    .PARAMETER ContentType
    The content type of the request. Default is 'application/json'.

    .PARAMETER ReturnFullObject
    Switch parameter to return the full response object, including all properties, instead of only the items collection when an items property is present in the response.
    
    .PARAMETER WhatIfBoolean
    Switch parameter to show the user what would happen if the cmdlet was to run without actually running it.

    .EXAMPLE
    Invoke-HPEGLWebRequest -Uri 'https://aquila-user-api.common.cloud.hpe.com/ui-doorway/ui/v1/license/devices' 

    Run a GET web request on 'https://aquila-user-api.common.cloud.hpe.com/ui-doorway/ui/v1/license/devices' using the web session object
    $Global:HPEGreenLakeSession.WorkspaceSession containing information about the HPE GreenLake session. 

    .EXAMPLE
    Invoke-HPEGLWebRequest 'https://aquila-user-api.common.cloud.hpe.com/ui-doorway/ui/v1/um/users' -WhatIfBoolean $True

    Run a GET web request on 'https://aquila-user-api.common.cloud.hpe.com/ui-doorway/ui/v1/um/users' with the WhatIfBoolean parameter to see 
    the potential effects of the command before committing to it.

    .EXAMPLE
    $Uri = 'https://aquila-user-api.common.cloud.hpe.com' + '/ui-doorway/ui/v1/um/users'

    $Payload = @"
    {
    "usernames": [
        "email1@gmail.com", 
        "email@yahoo.com"
    ]
    }
    "@

    Invoke-HPEGLWebRequest -Method Delete -Uri $Uri -Body $Payload

    Run a DELETE web request on 'https://aquila-user-api.common.cloud.hpe.com/ui-doorway/ui/v1/um/users' with the provided payload. 

    .INPUTS
    None. You cannot pipe objects to this Cmdlet.

    .OUTPUTS
    The output of the cmdlet depends upon the format of the content that is retrieved.
    If the request returns JSON strings, Invoke-HPEGLWebRequest returns a PSObject that represents the strings.

    Upon successful execution, the cmdlet sets the `$Global:HPECOMInvokeReturnData` variable to the full response object, allowing users to access detailed information about the request and response. 
    If an error occurs, the variable is set to the error response object for further inspection.

    For error handling in try/catch blocks, use the `$Global:HPECOMInvokeReturnData` automatic variable to access the error response object, or the `$_.Exception.Details` variable's property for additional error context.
         
    #>
    [CmdletBinding()]
    Param (   

        [Parameter (Mandatory)]
        [String]$Uri,

        $Body, 

        [ValidateSet("GET", "POST", "PUT", "PATCH", "DELETE")]
        [String]$Method = "GET",

        $WebSession = $Global:HPEGreenLakeSession.WorkspaceSession, 

        [String]$ContentType = "application/json",
       
        [Switch]$SkipSessionCheck,
        
        [int]$MaxRetries = 5,
        [int]$InitialDelaySeconds = 1,
        
        [switch]$ReturnFullObject,

        $WhatIfBoolean = $false

    )
   
    Process {

        "[{0}] Starting Invoke-HPEGLWebRequest process..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        #Region Check if HPEGreenLakeSession variable is available
        
        if ($null -eq $Global:HPEGreenLakeSession.workspaceId) {
            
            # Throw error only if switch parameter to skip the session check 'SkipSessionCheck' is not used. 
            # Switch parameter to skip the session check is used internally by a few cmdlets:
            # - Get-HPEGLWorkspace
            # - New-HPEGLWorkspace
            # - Get-HPEGLUserPreference 
            # - Set-HPEGLUserPreference
            # - Get-HPEGLUserAccountDetails
            # - Set-HPEGLUserAccountDetails
            # - Set-HPEGLUserAccountPassword 
            # It allows these cmdlets to run without requiring an active workspace session, i.e. when Connect-HPEGLWorkspace has not yet been executed. 
            if (-not $PSBoundParameters.ContainsKey('SkipSessionCheck')) {
                Throw "No active HPE GreenLake workspace session found. Please run 'Connect-HPEGLWorkspace' to establish a session before using this cmdlet."

            }
        }   
        #EndRegion

        #Region Check if a reconnection is required
        try {

            "[{0}] Running Invoke-HPEGLAutoReconnect to check if refresh token is required..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

            Invoke-HPEGLAutoReconnect

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
        #EndRegion

        
        #Region Construction for WhatIf
        Clear-Variable -Name InvokeReturnData -ErrorAction SilentlyContinue

        if ( $WhatIfBoolean ) {

            if ($uri -match (Get-HPEGLUIbaseURL)) {

                "[{0}] Detected URI: UI Doorway ------" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                invoke-RestMethodWhatIf -Uri $Uri -Method $Method -Body $Body -WebSession $WebSession -ContentType $ContentType -Cmdlet "Invoke-HPEGLWebRequest"

            }
            elseif ($uri -match (Get-HPEOnepassbaseURL)) {

                "[{0}] Detected URI: HPE Onepass ------" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                      
                if ($null -ne $Body) {

                    try {
                        # "[{0}] Request body (payload) content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Body | Write-Verbose
                        $BodyObject = ConvertFrom-Json -InputObject $Body -ErrorAction Stop
                        # "[{0}] Payload content after convertion: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $BodyObject | Write-Verbose
                        # Add sessionId to the object
                        $BodyObject | Add-Member -MemberType NoteProperty -Name 'access_token' -Value  $Global:HPEGreenLakeSession.onepasstoken.access_token 
                        "[{0}] Request body (payload) content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), (($BodyObject | ConvertTo-Json) -Replace '"access_token"\s*:\s*"[^"]+"', '"access_token": "[REDACTED]"') | Write-Verbose

                    }
                    catch {
                        Write-Error "The provided JSON body is not valid."
                        return
                    }
                }
                else {
                    $BodyObject = @{ access_token = $Global:HPEGreenLakeSession.onepasstoken.access_token }
                }


                # Convert the body hashtable to a JSON string
                $Payload = $BodyObject | ConvertTo-Json
                        
                invoke-RestMethodWhatIf -Uri $Uri -Method $Method -Body $Payload -ContentType $ContentType -Cmdlet "Invoke-HPEGLWebRequest"

            }
            elseif ($uri -match (Get-HPEGLAPIbaseURL) -and $uri -match "/internal-identity/v2alpha1") {

                "[{0}] Detected URI: global.api.greenlake.hpe.com with /internal-identity/v2alpha1 ------" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                $headers = @{} 
                $headers["Accept"] = "application/json"
                $headers["Content-Type"] = $ContentType
                $headers["Authorization"] = "$($Global:HPEGreenLakeSession.glpApiAccessTokenv1_2.access_token)"

                invoke-RestMethodWhatIf -Uri $Uri -Method $Method -Body $Body -Headers $headers -ContentType $ContentType -Cmdlet "Invoke-HPEGLWebRequest"
                
            }
            else {

                "[{0}] Detected URI: $uri ------" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                
                # Use the v1_2 access token if available
                if ($Global:HPEGreenLakeSession.glpApiAccessTokenv1_2.access_token) {
                    "[{0}] API Access token found in `$Global:HPEGreenLakeSession.glpApiAccessTokenv1_2" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    $glpApiAccessToken = $Global:HPEGreenLakeSession.glpApiAccessTokenv1_2.access_token

                } 
                # Use the v1_1 access token if available
                elseif ($Global:HPEGreenLakeSession.glpApiAccessToken.access_token) {
                    "[{0}] API Access token found in `$Global:HPEGreenLakeSession.glpApiAccessToken" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    $glpApiAccessToken = $Global:HPEGreenLakeSession.glpApiAccessToken.access_token
                }
                else {

                    "[{0}] No API Access token found in `$Global:HPEGreenLakeSession" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    Throw "Error - No API Access Token found in `$Global:HPEGreenLakeSession! Connect-HPEGL must be executed !"
                        
                }

                $headers = @{} 
                $headers["Accept"] = "application/json"
                $headers["Content-Type"] = $ContentType
                # $headers["Authorization"] = "Bearer $($Global:HPEGreenLakeSession.glpApiAccessToken.access_token)"
                $headers["Authorization"] = "Bearer $($glpApiAccessToken)"

                invoke-RestMethodWhatIf -Uri $Uri -Method $Method -Body $Body -Headers $headers -ContentType $ContentType -Cmdlet "Invoke-HPEGLWebRequest"
                
            }
        }        
        #EndRegion


        # Construction for Invoke-Webrequest
        else {

            $lastException = $null
            $attempt = 0
            $complete = $false

            while (-not $complete -and $attempt -lt $MaxRetries) {          

                #Region When using a UI Doorway URI
                if ($uri -match (Get-HPEGLUIbaseURL)) {

                    "[{0}] ------------------------------------ Detected URI: UI Doorway ------------------------------------" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                    # Process pagination for GET 
                    if ($Method -eq "GET" -or $Method -eq "POST") {
                        # if ($Method -eq "GET" -or ($Method -eq "POST" -and -not $Body)) {

                        $AllCollection = [System.Collections.ArrayList]::new()

                        # Get 100 items pagination
                        $pagination = 100

                        # Detect if $uri contains a query parameter
                        $uriobj = [System.Uri]::new($uri)

                        # Parse the query parameters into a dictionary
                        $queryParameters = [System.Web.HttpUtility]::ParseQueryString($uriobj.Query)
                        
                        # URI modification to support pagination
                        if ($queryParameters["limit"]) {

                            $url = $uri
                        }
                        # If contains 'count_per_page' query parameter, set the pagination value to the value of count_per_page (condition for Get-HPEGLWorkspace)
                        elseif ($queryParameters["count_per_page"]) {

                            $url = $uri

                            # Capture the value of count_per_page
                            $countPerPageValue = $queryParameters["count_per_page"]
                            # Set the value of count_per_page to the pagination value
                            $pagination = $countPerPageValue

                        }
                        # If contains another query parameter
                        elseif ($uriobj.Query -ne "") {

                            $url = $uri + "&limit=$($pagination)&offset=0"

                        }
                        # If not contains any query parameter
                        else {
                            
                            $url = $uri + "?limit=$($pagination)&offset=0"
                        }

                        # "[{0}] URI that has been generated: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $url | Write-Verbose
                        
                    }
                    else {
                        $url = $uri
                    }
                    
                    if ($Global:HPEGreenLakeSession.WorkspaceSession.headers) {
                        "[{0}] Request headers: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ((($Global:HPEGreenLakeSession.WorkspaceSession.headers | ConvertTo-Json) -Replace 'Bearer \S+', 'Bearer [REDACTED]') | Out-String) | Write-Verbose
                    }
                      
                    if ($body) {
                        # If body is JSON
                        if ($body.Trim().StartsWith('{') -and $body.Trim().EndsWith('}')) {
                            $Payload = $Body 
                        }
                        else {
                            # Convert the body hashtable to a JSON string
                            $Payload = $Body | ConvertTo-Json -Depth 10
                        }
                    }            
                    else {
                        $Payload = $false
                    }
                    
                    
                    try {

                        "[{0}] About to make a '{1}' call to '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Method, $Url | Write-Verbose

                        if ($payload) {
                            "[{0}] Request body (payload) content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Payload | Write-Verbose
                        }
                        else {
                            "[{0}] No request body (payload) provided for this call." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                        }

                        $InvokeReturnData = Invoke-WebRequest -Uri $Url -Method $Method -Body $Body -WebSession $WebSession -ContentType $ContentType #-ErrorAction Stop

                        # Create a global variable to store the Invoke-WebRequest response
                        $Global:HPECOMInvokeReturnData = $InvokeReturnData
 
                        if ($InvokeReturnData -match "doctype html") {      
                            
                            "[{0}] HTML doctype response detected ! Throwing exception!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    
                            throw [HtmlContentDetectedException]::new("Error! HTML content detected! Throwing exception!")
                        }   
                        
                        "[{0}] Received status code response: '{1}' - Description: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $InvokeReturnData.StatusCode, $InvokeReturnData.StatusDescription | Write-verbose
                        # "[{0}] Raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $InvokeReturnData | Write-verbose  # Removed to avoid logging sensitive info. Content is returned after JSON parsing.  

                       
                        $complete = $true
                      
                    }
                    #Region Removed detailed exception handling to avoid logging sensitive info
                    # Handle exceptions related to network operations
                    # catch [System.Net.WebException] {

                    #     $attempt++    
                        
                    #     # Store the last exception
                    #     $lastException = $_                        
    
                    #     # Service Unavailable error
                    #     if ($_.Exception.Response.StatusCode -eq 503) {
                    #         $retries++
                    #         # $waitTime = [math]::Pow(2, $retries) * $InitialDelaySeconds
                    #         $waitTime = 2
                    #         "[{0}] Received 503. Retrying in $waitTime seconds..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    #         Start-Sleep -Seconds $waitTime
                    #     }
                    #     else {
                        
                    #         "[{0}] Exception thrown!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
    
                    #         # Get Exception type
                    #         $exception = $_.Exception

                    #         do {
                    #             "[{0}] Exception Type: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $exception.GetType().Name | Write-Verbose
                    #             $exception = $exception.InnerException
                    #         } while ($exception)
    
                    #         # Get exception stream
                    #         $result = $_.Exception.Response.GetResponseStream()
                    #         $reader = New-Object System.IO.StreamReader($result)
                    #         $reader.BaseStream.Position = 0
                    #         $reader.DiscardBufferedData()
                    #         $responseBody = $reader.ReadToEnd() 
    
                    #         # "[{0}] Raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $responseBody | Write-Verbose
                    
    
                    #         if ($Global:HPEGreenLakeSession.WorkspaceSession.headers) {
                    #             "[{0}] Request headers: " -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
    
                    #             foreach ($Param in $Global:HPEGreenLakeSession.WorkspaceSession.headers.Keys) { 
                        
                    #                 Write-Verbose "`t`t$Param : $($Global:HPEGreenLakeSession.WorkspaceSession.headers[$Param])" 
                         
                    #             }
                    #         }
    
                    #         $response = $responseBody | ConvertFrom-Json
                        
                    #         $ResponseCode = $response.code
                    #         $ResponseDetail = $response.detail
                    #         $ResponseStatus = $Response.Status
    
                    #         if ($ResponseCode) {
                    #             "[{0}] Request failed with the following Status: `n`tHTTPS Return Code = '{1}' `n`tHTTPS Return Code Description = '{2}' `n`tHTTPS Return Code Details = '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ResponseStatus, $ResponseCode, $ResponseDetail | write-verbose
                    #         }  
                    
                    #         $StatusCode = [int]$_.Exception.Response.StatusCode
                    #         $ExceptionCode = $_.Exception.Response.StatusCode.value__
                    
                    #         if ($StatusCode -and -not $ResponseCode) {
                    #             "[{0}] HTTPS Return Code = '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $StatusCode | Write-Verbose
                    #         }
                    #         elseif ($ExceptionCode -and -not $ResponseCode) {
                    #             "[{0}] HTTPS Return Code = '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ExceptionCode | Write-Verbose
                    #         }
    
    
                    #         if ($ResponseStatus -and $ResponseCode -and $ResponseDetail) {
                    #             Throw "Error '{0}' - '{1}' : '{2}'" -f $ResponseCode, $ResponseStatus, $ResponseDetail
                    #         }
                    #         elseif ($ResponseStatus -and $ResponseCode -and -not $ResponseDetail) {
                    #             Throw "Error '{0}' - '{1}'" -f $ResponseCode, $ResponseStatus
                    #         }
                    #         elseif ($ResponseStatus -and -not $ResponseCode -and -not $ResponseDetail) {
                    #             Throw "Error '{0}'" -f $ResponseStatus
                    #         }
                    #         elseif ($responseBody -match "Unauthorized" ) {
                    #             Throw "Error - Session has expired or been closed! Connect-HPEGL must be executed again!"
                    #         }
                    #         elseif ($response.message ) {
                    #             Throw "Error - $($response.message)"
                    #         }
                    #         elseif ($response.detail ) {
    
                    #             if ($response.detail.msg) {
    
                    #                 $Detailmsg = ($response.detail | ForEach-Object { $_.msg + ": " + $_.type }) -join " AND "
    
                    #                 Throw "Error - $Detailmsg"
                    #             }
                    #             else {
    
                    #                 Throw "Error - $($response.detail)"
                    #             }
    
                    #         }
                    #         else {
    
                    #             Throw "Error - $($response | Out-String)"
     
                    #         }
                    #     }                   
                    # }
                    # Handle general runtime exceptions
                    # catch [System.Management.Automation.RuntimeException] {

                    #     "[{0}] System.Management.Automation.RuntimeException catch triggered!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose    
                    #     "[{0}] Exception type: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.GetType().Name | Write-Verbose
                    #     "[{0}] Exception raw content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_ | Write-Verbose

                    #     # Store the last exception
                    #     $lastException = $_                        

                    #     # 'Request Timeout' error
                    #     if ($_.Exception.Response.StatusCode -eq 408) {
                    #         $retries++
                    #         # $waitTime = [math]::Pow(2, $retries) * $InitialDelaySeconds
                    #         $waitTime = 2
                    #         "[{0}] Received 408. Retrying in $waitTime seconds..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    #         Start-Sleep -Seconds $waitTime
                    #     }
                    #     # When 'Forbidden' error are not expected (issue with GLP?)
                    #     elseif ($_.Exception.Response.StatusCode -eq 403) {
                    #         $retries++
                    #         # $waitTime = [math]::Pow(2, $retries) * $InitialDelaySeconds
                    #         $waitTime = 2
                    #         "[{0}] Received 403. Retrying in $waitTime seconds..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    #         Start-Sleep -Seconds $waitTime
                    #     }
                    #     # When 'Internal Server Error' error 
                    #     elseif ($_.Exception.Response.StatusCode -eq 500) {
                    #         $retries++
                    #         # $waitTime = [math]::Pow(2, $retries) * $InitialDelaySeconds
                    #         $waitTime = 2
                    #         "[{0}] Received 500. Retrying in $waitTime seconds..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    #         Start-Sleep -Seconds $waitTime
                    #     }
                    #     else {

                    #         # Convert JSON string to object
                    #         try {
                                
                    #             $response = $_ | ConvertFrom-Json
        
                    #             $_ExceptionMessageDetails = [System.Collections.ArrayList]::new()
                    #             $_ExceptionMessage = [System.Collections.ArrayList]::new()
                    
                    #             if ($response.detail) {
        
                    #                 foreach ($detail in $response.detail) {
        
                    #                     # Capture the 'msg' property
                    #                     $message = $detail.msg
                    #                     $type = $detail.type
        
                    #                     $Info = [System.Collections.HashTable]@{
                    #                         message = $message
                    #                         type    = $type
                    #                     }
        
                    #                     [void]$_ExceptionMessageDetails.Add($Info)
        
                    #                 }
        
                    #                 if ($_ExceptionMessageDetails) {
                                        
                    #                     "[{0}] Exception Message Details: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($_ExceptionMessageDetails | out-String) | Write-Verbose
                    #                 }
        
                    #             }
        
                    #             if ($response.message) {
        
                    #                 [void]$_ExceptionMessage.add($response.message)
                    #             }

                    #             if ($response.errorDetails.length -ge 1 ) {

                    #                 foreach ($error in $response.errorDetails) {
                                    
                    #                     if ($error.metadata.error) {
                    #                         [void]$_ExceptionMessage.add($error.metadata.error)

                    #                     }
                    #                 }
                                    
                    #             }
                                
                    #         }
                    #         catch {}

                    #         $ExceptionCode = $_.Exception.Response.StatusCode.value__
                    #         $ExceptionText = $_.Exception.Response.StatusDescription + $_.Exception.Response.ReasonPhrase 


                    #         if ( $_ExceptionMessage) {
                    #             "[{0}] Request failed with the following Status:`r`n`tHTTPS Return Code = '{1}' `r`n`tHTTPS Return Code Description = '{2}' `r`n`tHTTPS Return Message = '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ExceptionCode, $ExceptionText, ($_ExceptionMessage -join " - ") | write-verbose
                    #         }
                    #         else {
                    #             "[{0}] Request failed with the following Status:`r`n`tHTTPS Return Code = '{1}' `r`n`tHTTPS Return Code Description = '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ExceptionCode, $ExceptionText | write-verbose
                    #         }
                        
                    #         if (-not $ExceptionCode ) {

                    #             $ExceptionCode = [int]$_.Exception.Response.StatusCode
                    #         }
        
        
                    #         if ( $ExceptionCode -eq 400 ) {
                    #             Throw "Error status Code: 400 (Bad Request)"
                            
                    #         } 
                
                    #         elseif ( $ExceptionCode -eq 401 ) {
                    #             Throw "Error status Code: 401 (Unauthorized) - Your session with HPE GreenLake doorway API has expired, please log in again using 'Connect-HPEGL'!"
                                
                    #         } 
                            
                    #         elseif ( $ExceptionCode -eq 403 ) {
                    #             Throw "Error status Code: 403 (Forbidden) - Your session with HPE GreenLake doorway API has expired or you do not have sufficient rights to perform this action!"
                                
                    #         } 
                            
                    #         elseif ( $ExceptionCode -eq 412 ) {
                    #             Throw "Error status Code: 412 (Precondition failed) - Please verify the content of the payload request!"
                                
                    #         } 
                            
                    #         elseif ( $ExceptionCode -eq 408 ) {
                    #             Throw "Error status Code: 408 (Request Timeout) - Please try again!"
                                
                    #         }
                            
                    #         else {
                    #             Throw "Error status Code: {0} ({1})" -f $ExceptionCode, $ExceptionText

                    #         }
                    #     }
                    # }  
                    #Endregion
                    catch [HtmlContentDetectedException] {

                        $attempt++

                        # Store the last exception
                        $lastException = $_ 

                        "[{0}] -------------------------------------------- HtmlContentDetectedException Catch triggered! ------------------------------------" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose                    
                        "[{0}] Exception type: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.GetType().Name | Write-Verbose

                        if ($_.Exception.Response) {
                            $statusCode = [int]$_.Exception.Response.StatusCode
                            "[{0}] Received HTTP status code: '{1}'." -f $MyInvocation.InvocationName.ToString().ToUpper(), $statusCode | Write-Verbose
                        }
                        else {
                            "[{0}] No HTTP status code received." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            $statusCode = "N/A"
                        }
                        
                        
                        "[{0}] Exception raw content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_ | Write-Verbose 
                        "[{0}] --------------------------------------------------------------------------------------------------" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose                    
                                             
                        
                        # When HTML is detected, it means the session has expired or been closed
                        Throw "Error - Session has expired or been closed! Connect-HPEGL must be executed again!"
                    }                   
                    catch {

                        $attempt++
                        # Store the last exception
                        $lastException = $_
                        $script:LastException = $_                
                        
                        # Extract error string for better diagnostics
                        $errorString = $_ | Out-String
                        $errorMsg = $_.Exception.Message
                        $parsedErrorMsg = $null
                        # Try to extract message from JSON if errorMsg is empty
                        if ([string]::IsNullOrWhiteSpace($errorMsg)) {
                            # Try to parse JSON from error string
                            try {
                                $parsedError = $errorString | ConvertFrom-Json -ErrorAction Stop
                                if ($parsedError -and $parsedError.message) {
                                    $parsedErrorMsg = $parsedError.message
                                }
                            }
                            catch {}
                            $errorMsg = if ($parsedErrorMsg) { $parsedErrorMsg } else { $errorString }
                        }

                        Write-Verbose "-------------------------------------------- Catch triggered! -----------------------------------------------------------------------" 
                        "[{0}] Exception type: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.GetType().Name | Write-Verbose
                        "[{0}] Exception message: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $errorMsg | Write-Verbose

                        $statusCode = $null
                        $errorData = $null

                        if ($_.Exception.Response) {
                            $statusCode = [int]$_.Exception.Response.StatusCode
                            "[{0}] Received HTTP status code: '{1}'." -f $MyInvocation.InvocationName.ToString().ToUpper(), $statusCode | Write-Verbose
                            $lastException | Add-Member -NotePropertyName 'StatusCode' -NotePropertyValue $statusCode -Force
                        }
                        else {
                            "[{0}] No HTTP status code or response content available." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                        }

                        # Extract JSON block from the exception string
                        $exceptionString = $_ | Out-String

                        if ($exceptionString -match '(\{[\s\S]*\})') {
                            $jsonBlock = $matches[1]
                            $decodedJson = [System.Text.RegularExpressions.Regex]::Unescape($jsonBlock) # Decode Unicode escape sequences
                            # Pretty-print the JSON content
                            try {
                                $prettyJson = $decodedJson | ConvertFrom-Json | ConvertTo-Json -Depth 30
                                "[{0}] Exception raw content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $prettyJson | Write-Verbose
                                $errorData = $prettyJson
                            }
                            catch {
                                # Fallback to raw decoded JSON if parsing fails
                                "[{0}] Exception raw content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $decodedJson | Write-Verbose
                                $errorData = $decodedJson
                            }
                        }
                        else {
                            "[{0}] Exception raw content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $exceptionString | Write-Verbose
                            $errorData = $exceptionString
                        }

                        Write-Verbose "--------------------------------------------------------------------------------------------------------------------------------------" 

                        if ($statusCode -in 408, 500, 502, 503, 504) {
                            "[{0}] HTTP error {1} encountered. Retrying in 1 second... (Attempt {2} of {3})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $statusCode, $attempt, $MaxRetries | Write-Verbose  
                            Start-Sleep -Seconds 1
                        }
                        else {
                            if ($errorMsg -eq "Unauthorized") {
                                $errorRecord = New-Object Management.Automation.ErrorRecord(
                                    $_.Exception,
                                    "HPECOMUnauthorizedError",
                                    [Management.Automation.ErrorCategory]::AuthenticationError,
                                    $null
                                )
                                $errorRecord | Add-Member -MemberType NoteProperty -Name "Message" -Value "Session has expired or been closed! Connect-HPEGL must be executed again!" -Force
                                $PSCmdlet.ThrowTerminatingError($errorRecord)
                            }
                            else {
                                "[{0}] Non-retriable error encountered. Exiting retry loop." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                break
                                # # Exit the loop and propagate the exception, but append API error message if present
                                # $complete = $true
                                # # Try to extract a 'message' property from the exception raw content
                                # $apiMessage = $null
                                # $exceptionString = $_ | Out-String
                                # if ($exceptionString -match '(\{[\s\S]*\})') {
                                #     $jsonBlock = $matches[1]
                                #     try {
                                #         $json = $jsonBlock | ConvertFrom-Json -ErrorAction Stop
                                #         if ($json.message) { $apiMessage = $json.message }
                                #     }
                                #     catch {}
                                # }
                                # if ($apiMessage) {
                                #     throw ("{0} | API Error: {1}" -f $_.Exception.Message, $apiMessage)
                                # }
                                # else {
                                #     throw $_
                                # }
                            }
                        }
                    }
                }
                #EndRegion

                #Region When using an HPEOnepass URI
                elseif ($uri -match (Get-HPEOnepassbaseURL)) {

                    "[{0}] ------------------------------------ Detected URI: HPE Onepass ------------------------------------" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                    if ($null -ne $Body) {

                        try {
                            $BodyObject = ConvertFrom-Json -InputObject $Body -ErrorAction Stop
                            # "Payload content after convertion: `n{0}" -f $BodyObject | Write-Verbose
                            # Add sessionId to the object
                            $BodyObject | Add-Member -MemberType NoteProperty -Name 'access_token' -Value $Global:HPEGreenLakeSession.onepasstoken.access_token 
                            # "Payload content after adding HPEOnePass sessionId: `n{0}" -f $BodyObject | Write-Verbose

                        }
                        catch {
                            Write-Error "The provided JSON body is not valid."
                            return
                        }
                    }
                    else {
                        $BodyObject = @{ access_token = $Global:HPEGreenLakeSession.onepasstoken.access_token }

                    }

                    "[{0}] About to make a '{1}' call to '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Method, $Uri | Write-Verbose
                    
                    # Convert the body hashtable to a JSON string
                    $Payload = $BodyObject | ConvertTo-Json
                    
                    if ($payload) {
                        "[{0}] Request body (payload) content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Payload -Replace '"access_token"\s*:\s*"[^"]+"', '"access_token": "[REDACTED]"') | Write-Verbose


                    }
                    else {
                        "[{0}] No request body (payload) provided for this call." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    }
                    
                    Try {

                        $InvokeReturnData = Invoke-WebRequest -Uri $Uri -Method $Method -Body $Payload -ContentType $ContentType #-ErrorAction Stop

                        # Create a global variable to store the Invoke-WebRequest response
                        $Global:HPECOMInvokeReturnData = $InvokeReturnData

                        "[{0}] Received status code response: '{1}' - Description: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $InvokeReturnData.StatusCode, $InvokeReturnData.StatusDescription | Write-verbose
                        # "[{0}] Raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $InvokeReturnData | Write-verbose  # Removed to avoid logging sensitive info. Content is returned after JSON parsing.  

                        $complete = $true

                    }
                    catch {

                        $attempt++
                        $lastException = $_

                        "[{0}] -------------------------------------------- Catch triggered! ------------------------------------" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose                    
                        "[{0}] Exception type: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.GetType().Name | Write-Verbose
    
                        if ($_.Exception.Response) {
                            $statusCode = [int]$_.Exception.Response.StatusCode
                            "[{0}] Received HTTP status code: '{1}'." -f $MyInvocation.InvocationName.ToString().ToUpper(), $statusCode | Write-Verbose
                        }
                        else {
                            "[{0}] No HTTP status code received." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            $statusCode = "N/A"
                        }
                        
                        
                        "[{0}] Exception raw content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_ | Write-Verbose 
                        "[{0}] --------------------------------------------------------------------------------------------------" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose                    
                        
                        if ($statusCode -in 408, 500, 502, 503, 504) {
                            "[{0}] HTTP error {1} encountered. Retrying in 1 second... (Attempt {2} of {3})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $statusCode, $attempt, $MaxRetries | Write-Verbose  
                            Start-Sleep -Seconds 1
                        }
                        else {
                            "[{0}] Non-retriable error encountered. Exiting retry loop." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            break
                        }
                    }
                    
                }
                #EndRegion
                
                #Region When using an HPE GLP API URI
                elseif ($uri -match (Get-HPEGLAPIbaseURL) -or $uri -match (Get-HPEGLAPIOrgbaseURL)) {

                    "[{0}] ------------------------------------ Detected URI: HPE GreenLake Platform API ------------------------------------" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                    # Process pagination for GET 
                    if ($Method -eq "GET") {

                        $AllCollection = [System.Collections.ArrayList]::new()

                        # Get 100 items pagination
                        $pagination = 100

                        # Detect if $uri contains a query parameter
                        $uriobj = [System.Uri]::new($uri)

                        # Parse the query parameters into a dictionary
                        $queryParameters = [System.Web.HttpUtility]::ParseQueryString($uriobj.Query)
                        
                        # URI modification to support pagination
                        if ($queryParameters["limit"]) {

                            $url = $uri
                        }
                        # If contains another query parameter
                        elseif ($uriobj.Query -ne "") {
                            $url = $uri + "&limit=$($pagination)&offset=0"

                        }
                        # If not contains any query parameter
                        else {                            
                            $url = $uri + "?limit=$($pagination)&offset=0"
                        }

                        "[{0}] URI that has been generated: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $url | Write-Verbose
                        
                    }
                    else {
                        $url = $uri
                    }
                    
                    # Always use v1_2 token if available, otherwise fallback to v1_1 token
                    # Use the v1_2 access token if available
                    if ($Global:HPEGreenLakeSession.glpApiAccessTokenv1_2.access_token) {
                        "[{0}] API Access token found in `$Global:HPEGreenLakeSession.glpApiAccessTokenv1_2" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                        $glpApiAccessToken = $Global:HPEGreenLakeSession.glpApiAccessTokenv1_2.access_token

                    } 
                    # Use the v1_1 access token if available
                    elseif ($Global:HPEGreenLakeSession.glpApiAccessToken.access_token) {
                        "[{0}] API Access token found in `$Global:HPEGreenLakeSession.glpApiAccessToken" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                        $glpApiAccessToken = $Global:HPEGreenLakeSession.glpApiAccessToken.access_token
                    }
                    else {
                        "[{0}] No API Access token found in `$Global:HPEGreenLakeSession" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                        Throw "Error - No API Access Token found in `$Global:HPEGreenLakeSession! 'Connect-HPEGL' must be executed first!"
                    }

                    $headers = @{} 
                    $headers["Accept"] = "application/json"
                    $headers["Content-Type"] = "application/json"
                    $headers["Authorization"] = "Bearer $($glpApiAccessToken)"                                    

                    "[{0}] Request headers: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ((($headers | ConvertTo-Json) -Replace 'Bearer \S+', 'Bearer [REDACTED]') | Out-String) | Write-Verbose

                    if ($body) {
                        # If body is JSON
                        if ($body.Trim().StartsWith('{') -and $body.Trim().EndsWith('}')) {
                            $Payload = $Body 
                        }
                        else {
                            # Convert the body hashtable to a JSON string
                            $Payload = $Body | ConvertTo-Json -Depth 10
                        }
                    }
                    else {
                        $Payload = $false
                    }

                    try {

                        "[{0}] About to make a '{1}' call to '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Method, $Url | Write-Verbose      

                        if ($payload) {
                            "[{0}] Request body (payload) content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Payload | Write-Verbose
                        }
                        else {
                            "[{0}] No request body (payload) provided for this call." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                        }
              
                        $InvokeReturnData = Invoke-WebRequest -Uri $Url -Method $Method -Headers $headers -Body $Body -ContentType $ContentType  #-ErrorAction Stop

                        # Create a global variable to store the Invoke-WebRequest response
                        $Global:HPECOMInvokeReturnData = $InvokeReturnData

                        "[{0}] Received status code response: '{1}' - Description: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $InvokeReturnData.StatusCode, $InvokeReturnData.StatusDescription | Write-verbose
                        # "[{0}] Raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $InvokeReturnData | Write-verbose  # Removed to avoid logging sensitive info. Content is returned after JSON parsing.  

                        $complete = $true
                    
                    }
                    catch {
                        $attempt++
                        $lastException = $_         
                        $script:LastException = $_             

                        # Extract error string for better diagnostics
                        $errorString = $_ | Out-String
                        $errorMsg = $_.Exception.Message
                        $parsedErrorMsg = $null
                        # Try to extract message from JSON if errorMsg is empty
                        if ([string]::IsNullOrWhiteSpace($errorMsg)) {
                            # Try to parse JSON from error string
                            try {
                                $parsedError = $errorString | ConvertFrom-Json -ErrorAction Stop
                                if ($parsedError -and $parsedError.message) {
                                    $parsedErrorMsg = $parsedError.message
                                }
                            }
                            catch {}
                            $errorMsg = if ($parsedErrorMsg) { $parsedErrorMsg } else { $errorString }
                        }

                        Write-Verbose "-------------------------------------------- Catch triggered! -----------------------------------------------------------------------" 
                        "[{0}] Exception type: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.GetType().Name | Write-Verbose
                        "[{0}] Exception message: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $errorMsg | Write-Verbose

                        $statusCode = $null
                        $errorData = $null

                        if ($_.Exception.Response) {
                            $statusCode = [int]$_.Exception.Response.StatusCode
                            "[{0}] Received HTTP status code: '{1}'." -f $MyInvocation.InvocationName.ToString().ToUpper(), $statusCode | Write-Verbose
                        }
                        else {
                            "[{0}] No HTTP status code or response content available." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                        }

                        # Extract JSON block from the exception string
                        $exceptionString = $_ | Out-String

                        if ($exceptionString -match '(\{[\s\S]*\})') {
                            $jsonBlock = $matches[1]
                            $decodedJson = [System.Text.RegularExpressions.Regex]::Unescape($jsonBlock) # Decode Unicode escape sequences
                            # Pretty-print the JSON content
                            try {
                                $prettyJson = $decodedJson | ConvertFrom-Json | ConvertTo-Json -Depth 30
                                "[{0}] Exception raw content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $prettyJson | Write-Verbose
                                $errorData = $prettyJson
                            }
                            catch {
                                # Fallback to raw decoded JSON if parsing fails
                                "[{0}] Exception raw content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $decodedJson | Write-Verbose
                                $errorData = $decodedJson
                            }
                        }
                        else {
                            "[{0}] Exception raw content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $exceptionString | Write-Verbose
                            $errorData = $exceptionString
                        }

                        Write-Verbose "--------------------------------------------------------------------------------------------------------------------------------------" 

                        if ($statusCode -in 408, 500, 502, 503, 504) {
                            "[{0}] HTTP error {1} encountered. Retrying in 1 second... (Attempt {2} of {3})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $statusCode, $attempt, $MaxRetries | Write-Verbose  
                            Start-Sleep -Seconds 1
                        }
                        else {
                            if ($errorMsg -eq "Unauthorized") {
                                $errorRecord = New-Object Management.Automation.ErrorRecord(
                                    $_.Exception,
                                    "HPECOMUnauthorizedError",
                                    [Management.Automation.ErrorCategory]::AuthenticationError,
                                    $null
                                )
                                $errorRecord | Add-Member -MemberType NoteProperty -Name "Message" -Value "Session has expired or been closed! Connect-HPEGL must be executed again!" -Force
                                $PSCmdlet.ThrowTerminatingError($errorRecord)
                            }
                            else {
                                "[{0}] Non-retriable error encountered. Exiting retry loop." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                break
                            }
                        }
                    }                  
                }
                #EndRegion

                else {
                    Throw "Error - Invalid URI! The URI must be a valid HPE GreenLake API URI!"
                }
            }       
            
            "[{0}] Exited retry loop. Complete: {1}, Attempts: {2}, MaxRetries: {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $complete, $attempt, $MaxRetries | Write-Verbose
            "[{0}] Before final exception check: lastException exists: {1}, complete: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($null -ne $lastException), $complete | Write-Verbose

              
            if ($lastException -and -not $complete) {
                Write-Verbose "-------------------------------------------- Final Exception Handling ------------------------------------------------------------------"
                "[{0}] Last exception occurred: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $lastException.Exception.Message | Write-Verbose
                "[{0}] Last exception type: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $lastException.GetType().Name | Write-Verbose

                if ($errorData) {
                    Write-Verbose "-------------------------------------------- Enhanced Exception Handling (`$ErrorMsg) ------------------------------------------------------------------"
                    # "[{0}] Raw error details: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMsg | Write-Verbose

                    try {
                        $errorData = $errorData | ConvertFrom-Json -ErrorAction Stop
                    }
                    catch {
                        $errorData = $null  # JSON parsing failed
                    }

                    # "[{0}] Parsed `$errorData: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $errorData | Write-Verbose

                    # Build your custom message as before
                    $exceptionMessage = [System.Collections.ArrayList]::new()

                    # Extract error details from issues
                    foreach ($detail in $errorData.errorDetails) {
                        if ($detail.issues -and $detail.issues.count -gt 0) {
                            # "[{0}] Found issues in errorDetail: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $detail.issues | Write-Verbose
                            $i = 1
                            foreach ($issue in $detail.issues) {
                                if ($issue.description) {
                                    $detailsMessage = "Issue $($i): " + [System.Text.RegularExpressions.Regex]::Unescape($issue.description)
                                    [void]$exceptionMessage.Add($detailsMessage)
                                }
                                $i++
                            }
                        } 
                        if ($detail.metadata.details) {
                            $detailsMessage = [System.Text.RegularExpressions.Regex]::Unescape($detail.metadata.details)
                            [void]$exceptionMessage.add($detailsMessage)
                        }
                        if ($detail.metadata.error) {
                            $detailsMessage = [System.Text.RegularExpressions.Regex]::Unescape($detail.metadata.error)
                            [void]$exceptionMessage.add($detailsMessage)
                        }
                    }


                    $exceptionMessage = if ($exceptionMessage.count -gt 0) { $exceptionMessage -join " - " } else { $null }
                    # "[{0}] Constructed exceptionMessage: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $exceptionMessage | Write-Verbose
                    $Message = if ($errorData.message) { [System.Text.RegularExpressions.Regex]::Unescape($errorData.message) } else { $lastException.Exception.Message }
                    # "[{0}] Base message: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Message | Write-Verbose
                    $msg = if ($exceptionMessage) { "{0} - {1}" -f $Message, $exceptionMessage } else { $Message }
                    # "[{0}] Final constructed message: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $msg | Write-Verbose                   

                    If ($msg) {
                        # Attach enhanced message to lastException
                        "[{0}] Attached Details to lastException: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $msg | Write-Verbose
    
                        $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                            $lastException.Exception,
                            "CustomErrorID",
                            [System.Management.Automation.ErrorCategory]::NotSpecified,
                            $null
                        )
                        $errorRecord.Exception | Add-Member -NotePropertyName 'Details' -NotePropertyValue $msg -Force
                    }
                    else {
                        "[{0}] No message constructed, using last exception message: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $lastException.Exception.Message | Write-Verbose
                        $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                            $lastException.Exception,
                            "CustomErrorID",
                            [System.Management.Automation.ErrorCategory]::NotSpecified,
                            $null
                        )
                        $errorRecord.Exception | Add-Member -NotePropertyName 'Details' -NotePropertyValue "" -Force
                    }
                    
                    # Store error data in global variable
                    $Global:HPECOMInvokeReturnData = $errorData
                    "[{0}] Set Global:HPECOMInvokeReturnData: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Global:HPECOMInvokeReturnData | ConvertTo-Json -Depth 5) | Write-Verbose

                }
                else {
                    "[{0}] No errorData and ErrorMsg available, using fallback message: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $lastException.Exception.Message | Write-Verbose
                    $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                        $lastException.Exception,
                        "CustomErrorID",
                        [System.Management.Automation.ErrorCategory]::NotSpecified,
                        $null
                    )
                    $errorRecord.Exception | Add-Member -NotePropertyName 'Details' -NotePropertyValue "" -Force
                }

                Throw $errorRecord
                    
            }  
        
            #Region Manage the response content
            if ($InvokeReturnData) {       
                
                # Simple format check first
                if (Test-JsonFormat -Content $InvokeReturnData -InvocationName $MyInvocation.InvocationName.ToString().ToUpper()) {
                
                    # Detect JSON depth and set optimal conversion depth
                    $detectedDepth = Get-JsonDepth -JsonString $InvokeReturnData

                    # Add cap: Calculate candidate, enforce min 15, then max 100
                    $candidateDepth = $detectedDepth + 3
                    $optimalDepth = [Math]::Max($candidateDepth, 15)  # Enforce minimum
                    $optimalDepth = [Math]::Min($optimalDepth, 100)   # Enforce maximum cap

                    if ($optimalDepth -eq 100) { "[{0}] JSON depth capped at 100 to prevent recursion issues" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose }
                    
                    "[{0}] Detected JSON depth: {1} - Using conversion depth: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $detectedDepth, $optimalDepth | Write-Verbose
                    
                    # Initialize $paginationOptimalDepth
                    $paginationOptimalDepth = $optimalDepth  # Safe default before pagination
                    
                    # Convert from JSON
                    try {

                        # Use case-sensitive JSON parsing
                        $InvokeReturnData = ConvertFrom-JsonCaseSensitive -JsonString $InvokeReturnData -MaxDepth $optimalDepth -InvocationName $MyInvocation.InvocationName.ToString().ToUpper()
                        "[{0}] JSON conversion successful with case-sensitive parsing at depth {1}!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $optimalDepth | Write-Verbose

                        if ($InvokeReturnData -eq "OK") {
                            "[{0}] Response Detected with an 'OK' response!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            return           
                        }   

                        # HPEOnepass URI expiration detection
                        if ($InvokeReturnData.message -match "expired") {
                            write-error "Session gets expired! You must run 'Connect-HPEGL' again!"
                        }

                        # Main logic for handling API responses
                        # UI Doorway API Pagination detection
                        if ($InvokeReturnData.PSObject.Properties['pagination']) {
                            
                            "[{0}] Response detected with a pagination content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnData.pagination | out-string) | Write-Verbose

                            if ($InvokeReturnData.pagination.total_count -gt 0) {

                                "[{0}] Total items is {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $InvokeReturnData.pagination.total_count | Write-Verbose

                                # Get all paginated pages (if any)
                                # When the query 'limit' is used, the number of items returned is equal to the limit set so only one page is available (no pagination is used).
                                # 'count' = 'limit'  - 'total' is always the total nb of items available without the limit.
                                if (($Method -eq "GET" -or $Method -eq "POST") -and -not $queryParameters["limit"]) {
                                    $Offset = 0
                                    $failedPages = [System.Collections.ArrayList]::new() 
                                    $AllCollection = $InvokeReturnData
    
                                    "[{0}] Total of items: '{1}' - Number of items per page: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $InvokeReturnData.pagination.total_count, $InvokeReturnData.pagination.count_per_page | Write-Verbose
                                
                                    $Numberofpages = [System.Math]::Ceiling(($InvokeReturnData.pagination.total_count / $InvokeReturnData.pagination.count_per_page))
                                
                                    "[{0}] Number of pages found: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Numberofpages | Write-Verbose
                                
                                    if ($Numberofpages -gt 1) {
                                        for ($i = 1; $i -lt $Numberofpages; $i++) {                                            
                                            $Offset += [int]$pagination

                                            "[{0}] Offset defined: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Offset | Write-Verbose
    
                                            # URI modification to support pagination with Get-HPEGLWorkspace
                                            if ($queryParameters["count_per_page"]) {        
                                                $url = $uri + "&offset=$Offset"
                                            }
                                            elseif ($uriobj.Query -ne "") {                                                    
                                                $url = $uri + "&limit=$($pagination)&offset=$($Offset)"
                                            }
                                            else {
                                                $url = $uri + "?limit=$($pagination)&offset=$($Offset)"
                                            }
    
                                            "[{0}] Request URI for page '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($i + 1), $url | Write-Verbose
                                        
                                            try {
                                        
                                                $paginationResponse = Invoke-WebRequest -Uri $Url -Method $Method -Body $Body -WebSession $WebSession -ContentType $ContentType #-ErrorAction Stop

                                                # Create a global variable to store the Invoke-WebRequest response
                                                $Global:HPECOMInvokeReturnData = $paginationResponse

                                                "[{0}] Received status code response: '{1}' - Description: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $paginationResponse.StatusCode, $paginationResponse.StatusDescription | Write-verbose
                                                # "[{0}] Raw response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $paginationResponse | Write-verbose

                                                # Detect JSON depth and set optimal conversion depth
                                                $paginationDepth = Get-JsonDepth -JsonString $paginationResponse.Content

                                                # Add cap: Calculate candidate, enforce min against current $paginationOptimalDepth, then max 100
                                                $candidateDepth = $paginationDepth + 3
                                                $paginationOptimalDepth = [Math]::Max($candidateDepth, $paginationOptimalDepth)  # Track max (with min buffer)
                                                $paginationOptimalDepth = [Math]::Min($paginationOptimalDepth, 100)              # Enforce maximum cap

                                                "[{0}] Detected JSON depth: {1} - Using conversion depth: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $paginationDepth, $paginationOptimalDepth | Write-Verbose

                                                # Convert from JSON using case-sensitive JSON parsing
                                                $InvokeReturnMoreData = ConvertFrom-JsonCaseSensitive -JsonString $paginationResponse.Content -MaxDepth $paginationOptimalDepth -InvocationName $MyInvocation.InvocationName.ToString().ToUpper()
                                                "[{0}] Pagination response converted with case-sensitive parsing at depth {1}!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $paginationOptimalDepth | Write-Verbose
                                                "[{0}] Raw converted response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnMoreData | ConvertTo-Json -Depth $paginationOptimalDepth) | Write-Verbose
                                                "[{0}] Adding page '{1}' to the result" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($i + 1) | Write-Verbose
                                                                                            
                                                # Initialize an empty hashtable
                                                $dictionary = @{}
                                                
                                                $InvokeReturnMoreData.PSObject.Properties | ForEach-Object {
                                                    $propertyName = $_.Name
                                                    $propertyValue = $_.Value        
                                                    if ($propertyValue -is [System.Collections.IEnumerable] -and $null -ne $propertyValue -and $propertyValue.GetType().Name -ne "String" -and -not ($propertyValue -is [hashtable])) {
                                                        # Already a collection/array
                                                        $dictionary[$propertyName] = $propertyValue
                                                    }
                                                    else {
                                                        # Single object, wrap in array
                                                        $dictionary[$propertyName] = @($propertyValue)
                                                    }
                                                }

                                                foreach ($entry in $dictionary.GetEnumerator()) {
                                                    $_Item = $entry.Key
                                                    $_Value = $entry.Value
                                                    if ($AllCollection.PSObject.Properties.Name -contains $_Item) {
                                                        "[{0}] Content of `$AllCollection matches with {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_Item | Write-Verbose
                                                        "[{0}] Adding page '{1}' to the result" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($i + 1) | Write-Verbose

                                                        # Ensure $AllCollection.$_Item is always an array before appending
                                                        if ($null -eq $AllCollection.$_Item) {
                                                            $AllCollection | Add-Member -MemberType NoteProperty -Name $_Item -Value @()
                                                        }
                                                        elseif ($AllCollection.$_Item -isnot [System.Collections.IEnumerable] -or $AllCollection.$_Item.GetType().Name -eq 'String') {
                                                            $AllCollection.$_Item = @($AllCollection.$_Item)
                                                        }
                                                        $AllCollection.$_Item += $_Value
                                                    }
                                                }
                                            }
                                            catch {
                                                $errorMsg = $_.Exception.Message
                                                $statusCode = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { $null }

                                                # Classify error
                                                $isCritical = $statusCode -in 401, 403, 404  # Add other critical codes as needed
                                                if ($isCritical) {
                                                    "[{0}] Critical error on page {1}: {2} (Status: {3})" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($i + 1), $errorMsg, $statusCode | Write-Verbose
                                                    Write-Error "[$($MyInvocation.InvocationName.ToString().ToUpper())] Critical error on page $($i + 1): $_"
                                                    $PSCmdlet.ThrowTerminatingError($_)  # Stop for critical errors
                                                }
                                                else {
                                                    "[{0}] Non-critical error on page {1}: {2} (Status: {3}). Skipping page." -f $MyInvocation.InvocationName.ToString().ToUpper(), ($i + 1), $errorMsg, $statusCode | Write-Verbose
                                                    Write-Warning "[$($MyInvocation.InvocationName.ToString().ToUpper())] Skipped page $($i + 1) due to error: $_"
                                                    $failedPages.Add($i + 1) | Out-Null  # Track for summary
                                                    continue  # Skip to next page
                                                }
                                            }
                                        }

                                        # Log summary of failed pages
                                        if ($failedPages.Count -gt 0) {
                                            "[{0}] Pagination completed with {1} failed page(s): {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $failedPages.Count, ($failedPages -join ", ") | Write-Verbose
                                            Write-Warning "[$($MyInvocation.InvocationName.ToString().ToUpper())] Fetched partial data; failed pages: $($failedPages -join ', ')"
                                        }
                                    }
    
                                    $InvokeReturnData = $AllCollection          
                                    $Depth = if ($paginationOptimalDepth -and $paginationOptimalDepth -is [int]) { $paginationOptimalDepth } else { $optimalDepth }
                                    if (-not $Depth -or $Depth -lt 1) {
                                        $Depth = 15  # Safe default
                                        "[{$($MyInvocation.InvocationName.ToString().ToUpper())}] Warning: Depth undefined or invalid, using default depth: $Depth" | Write-Verbose
                                    }
                                    
                                    if ($ReturnFullObject) {
                                        "[{0}] Leaving Invoke-HPECOMWebRequest and returning the full response content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnData | ConvertTo-Json -Depth $Depth) | Write-Verbose
                                        return $InvokeReturnData
                                    }
                                    elseif ($InvokeReturnData.content -and $InvokeReturnData.content -is [System.Collections.IEnumerable] -and $InvokeReturnData.content.GetType().Name -ne 'String') {
                                        "[{0}] Response detected with a content property!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                        "[{0}] Leaving Invoke-HPEGLMWebRequest and returning the content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnData.content | Convertto-json -Depth $Depth ) | Write-Verbose
                                        return $InvokeReturnData.content
                                    }
                                    else {
                                        "[{0}] Leaving Invoke-HPEGLWebRequest and returning the content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnData | Convertto-json -Depth $Depth ) | Write-Verbose
                                        return $InvokeReturnData                                                                      
                                    }
                                    
                                }
                                else {
                                    "[{0}] Pagination detected with a 'limit' query parameter; returning all items from the current page." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                    $Depth = if ($paginationOptimalDepth -and $paginationOptimalDepth -is [int]) { $paginationOptimalDepth } else { $optimalDepth }
                                    if (-not $Depth -or $Depth -lt 1) {
                                        $Depth = 15  # Safe default
                                        "[{$($MyInvocation.InvocationName.ToString().ToUpper())}] Warning: Depth undefined or invalid, using default depth: $Depth" | Write-Verbose
                                    }
                                    
                                    if ($ReturnFullObject) {
                                        "[{0}] Leaving Invoke-HPECOMWebRequest and returning the full response content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnData | ConvertTo-Json -Depth $Depth) | Write-Verbose
                                        return $InvokeReturnData
                                    }
                                    elseif ($InvokeReturnData.content -and $InvokeReturnData.content -is [System.Collections.IEnumerable] -and $InvokeReturnData.content.GetType().Name -ne 'String') {
                                        "[{0}] Response detected with a content property!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                        "[{0}] Leaving Invoke-HPEGLMWebRequest and returning the content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnData.content | Convertto-json -Depth $Depth ) | Write-Verbose
                                        return $InvokeReturnData.content
                                    }
                                    else {
                                        "[{0}] Leaving Invoke-HPEGLWebRequest and returning the content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnData | Convertto-json -Depth $Depth ) | Write-Verbose
                                        return $InvokeReturnData                                                                      
                                    }
                                }                               
                            }
                            else {
                                "[{0}] Response detected with no items (total is 0)" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                "[{0}] Leaving Invoke-HPEGLWebRequest and returning no content" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                return
                            }
                        }   
                        # GLP API Pagination detection
                        elseif ($InvokeReturnData.PSObject.Properties['total']) {    
                            
                            "[{0}] Response detected with a count/total content" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            
                            if ($InvokeReturnData.total -gt 0) {

                                "[{0}] Total items is {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $InvokeReturnData.total | Write-Verbose

                                # Check if content property exists (not sure this is still needed...)
                                if ($Null -ne $InvokeReturnData.content) {        
                                    "[{0}] Response detected with a content property!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                    "[{0}] $InvokeReturnData content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnData | out-String) | Write-Verbose
                                    $InvokeReturnData = $InvokeReturnData.content
                                }

                                # Validate items property
                                if (-not $InvokeReturnData.PSObject.Properties['items']) {
                                    Write-Error "[$($MyInvocation.InvocationName.ToString().ToUpper())] Items property missing in response"
                                    return
                                }

                                # Get all paginated pages (if any)
                                # When the query 'limit' is used, the number of items returned is equal to the limit set so only one page is available (no pagination is used).
                                # 'count' = 'limit'  - 'total' is always the total nb of items available without the limit.
                                if ($Method -eq "GET" -and -not $queryParameters["limit"]) {
                                    $Offset = 0
                                    $failedPages = [System.Collections.ArrayList]::new() 
                                    # Always wrap items in array to handle single-object/single-item responses
                                    $itemsArray = @()
                                    if ($InvokeReturnData.items -is [System.Collections.IEnumerable] -and $InvokeReturnData.items.GetType().Name -ne 'String') {
                                        $itemsArray = @($InvokeReturnData.items)
                                    }
                                    elseif ($null -ne $InvokeReturnData.items) {
                                        $itemsArray = @($InvokeReturnData.items)
                                    }
                                    $AllCollection = [PSCustomObject]@{ items = $itemsArray }

                                    $itemsCount = if ($AllCollection.items) { $AllCollection.items.Count } else { 0 }
                                    "[{0}] Total of items: '{1}' - Number of items per page: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $InvokeReturnData.total, $itemsCount | Write-Verbose

                                    if (-not $pagination -or $pagination -le 0) {
                                        Write-Error "[$($MyInvocation.InvocationName.ToString().ToUpper())] Invalid pagination value: '$pagination'"
                                        return
                                    }

                                    $Numberofpages = [System.Math]::Ceiling(($InvokeReturnData.total / $itemsCount))
                                    "[{0}] Number of pages found: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Numberofpages | Write-Verbose

                                    if ($Numberofpages -gt 1) {

                                        for ($i = 1; $i -lt $Numberofpages; $i++) {
                                            $Offset += [int]$pagination

                                            if ($uriobj.Query -ne "") {
                                                $url = "$($uri)&limit=$($pagination)&offset=$($Offset)"
                                            }
                                            else {
                                                $url = "$($uri)?limit=$($pagination)&offset=$($Offset)"
                                            }
                                            "[{0}] Request URI for page '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($i + 1), $Url | Write-Verbose

                                            try {
                                                $paginationResponse = Invoke-WebRequest -Uri $Url -Method $Method -Headers $headers -Body $Body -ContentType $ContentType
                                                # Create a global variable to store the response
                                                $Global:HPECOMInvokeReturnData = $paginationResponse
                                                "[{0}] Received status code response: '{1}' - Description: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $paginationResponse.StatusCode, $paginationResponse.StatusDescription | Write-Verbose
                                                $paginationDepth = Get-JsonDepth -JsonString $paginationResponse.Content

                                                # Add cap: Calculate candidate, enforce min against current $paginationOptimalDepth, then max 100
                                                $candidateDepth = $paginationDepth + 3
                                                $paginationOptimalDepth = [Math]::Max($candidateDepth, $paginationOptimalDepth)  # Track max (with min buffer)
                                                $paginationOptimalDepth = [Math]::Min($paginationOptimalDepth, 100)              # Enforce maximum cap
                                                                                                    
                                                "[{0}] Detected JSON depth: {1} - Using conversion depth: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $paginationDepth, $paginationOptimalDepth | Write-Verbose
                                                $InvokeReturnMoreData = ConvertFrom-JsonCaseSensitive -JsonString $paginationResponse.Content -MaxDepth $paginationOptimalDepth -InvocationName $MyInvocation.InvocationName.ToString().ToUpper()
                                                "[{0}] Pagination response converted with case-sensitive parsing at depth {1}!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $paginationOptimalDepth | Write-Verbose
                                                "[{0}] Raw converted response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnMoreData | ConvertTo-Json -Depth $paginationOptimalDepth) | Write-Verbose
                                                "[{0}] Adding page '{1}' to the result" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($i + 1) | Write-Verbose
                                                # Always wrap page items in array before appending
                                                $pageItems = @()
                                                if ($InvokeReturnMoreData.items -is [System.Collections.IEnumerable] -and $InvokeReturnMoreData.items.GetType().Name -ne 'String') {
                                                    $pageItems = @($InvokeReturnMoreData.items)
                                                }
                                                elseif ($null -ne $InvokeReturnMoreData.items) {
                                                    $pageItems = @($InvokeReturnMoreData.items)
                                                }
                                                $AllCollection.items += $pageItems
                                            }
                                            catch {
                                                $errorMsg = $_.Exception.Message
                                                $statusCode = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { $null }

                                                # Classify error
                                                $isCritical = $statusCode -in 401, 403, 404  # Add other critical codes as needed
                                                if ($isCritical) {
                                                    "[{0}] Critical error on page {1}: {2} (Status: {3})" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($i + 1), $errorMsg, $statusCode | Write-Verbose
                                                    Write-Error "[$($MyInvocation.InvocationName.ToString().ToUpper())] Critical error on page $($i + 1): $_"
                                                    $PSCmdlet.ThrowTerminatingError($_)  # Stop for critical errors
                                                }
                                                else {
                                                    "[{0}] Non-critical error on page {1}: {2} (Status: {3}). Skipping page." -f $MyInvocation.InvocationName.ToString().ToUpper(), ($i + 1), $errorMsg, $statusCode | Write-Verbose
                                                    Write-Warning "[$($MyInvocation.InvocationName.ToString().ToUpper())] Skipped page $($i + 1) due to error: $_"
                                                    $failedPages.Add($i + 1) | Out-Null  # Track for summary
                                                    continue  # Skip to next page
                                                }
                                            }
                                        }
                                        
                                        # Log summary of failed pages
                                        if ($failedPages.Count -gt 0) {
                                            "[{0}] Pagination completed with {1} failed page(s): {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $failedPages.Count, ($failedPages -join ", ") | Write-Verbose
                                            Write-Warning "[$($MyInvocation.InvocationName.ToString().ToUpper())] Fetched partial data; failed pages: $($failedPages -join ', ')"
                                        }                                            
                                    }

                                    $InvokeReturnData = $AllCollection
                                    $Depth = if ($paginationOptimalDepth -and $paginationOptimalDepth -is [int]) { $paginationOptimalDepth } else { $optimalDepth }
                                    if (-not $Depth -or $Depth -lt 1) {
                                        $Depth = 15  # Safe default
                                        "[{$($MyInvocation.InvocationName.ToString().ToUpper())}] Warning: Depth undefined or invalid, using default depth: $Depth" | Write-Verbose
                                    }
                                    
                                    if ($ReturnFullObject) {
                                        "[{0}] Leaving Invoke-HPECOMWebRequest and returning the full response content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnData | ConvertTo-Json -Depth $Depth) | Write-Verbose
                                        return $InvokeReturnData
                                    }
                                    elseif ($InvokeReturnData.items) {
                                        "[{0}] Leaving Invoke-HPECOMWebRequest and returning the items content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnData.items | ConvertTo-Json -Depth $Depth) | Write-Verbose
                                        return $InvokeReturnData.items
                                    }
                                    else {
                                        "[{0}] Leaving Invoke-HPECOMWebRequest and returning the full response content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnData | ConvertTo-Json -Depth $Depth) | Write-Verbose
                                        return $InvokeReturnData
                                    }
                                }   
                                else {
                                    "[{0}] Pagination detected with a 'limit' query parameter; returning all items from the current page." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                    $Depth = if ($paginationOptimalDepth -and $paginationOptimalDepth -is [int]) { $paginationOptimalDepth } else { $optimalDepth }
                                    if (-not $Depth -or $Depth -lt 1) {
                                        $Depth = 15  # Safe default
                                        "[{$($MyInvocation.InvocationName.ToString().ToUpper())}] Warning: Depth undefined or invalid, using default depth: $Depth" | Write-Verbose
                                    }
                                    
                                    if ($ReturnFullObject) {
                                        "[{0}] Leaving Invoke-HPECOMWebRequest and returning the full response content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnData | ConvertTo-Json -Depth $Depth) | Write-Verbose
                                        return $InvokeReturnData
                                    }
                                    elseif ($InvokeReturnData.items) {
                                        "[{0}] Leaving Invoke-HPECOMWebRequest and returning the items content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnData.items | ConvertTo-Json -Depth $Depth) | Write-Verbose
                                        return $InvokeReturnData.items
                                    }
                                    else {
                                        "[{0}] Leaving Invoke-HPECOMWebRequest and returning the full response content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnData | ConvertTo-Json -Depth $Depth) | Write-Verbose
                                        return $InvokeReturnData
                                    }
                                }
                            }
                            else {
                                "[{0}] Response detected with no items (total is 0)" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                "[{0}] Leaving Invoke-HPEGLWebRequest and returning no content" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                return
                            }
                        }
                        else {
                            "[{0}] Response detected with no total or pagination properties!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            $Depth = if ($paginationOptimalDepth -and $paginationOptimalDepth -is [int]) { $paginationOptimalDepth } else { $optimalDepth }
                            if (-not $Depth -or $Depth -lt 1) {
                                $Depth = 15  # Safe default
                                "[{$($MyInvocation.InvocationName.ToString().ToUpper())}] Warning: Depth undefined or invalid, using default depth: $Depth" | Write-Verbose
                            }
                            "[{0}] Leaving Invoke-HPEGLWebRequest and returning the response content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnData | Convertto-json -Depth $Depth ) | Write-Verbose
                            return $InvokeReturnData
                        }
                    }    
                    catch {    
                        # Handle other JSON parsing issues (malformed JSON, depth issues, etc.)
                        Write-Error "Failed to parse the returned JSON: $($_.Exception.Message). Attempting to reformat the data; output may not be formatted correctly."

                        "[{0}] JSON parsing failed: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                        
                        # Fallback: try with regular ConvertFrom-Json + AsHashtable
                        try {
                            "[{0}] Attempting fallback with standard ConvertFrom-Json..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            $_InvokeReturnData = $InvokeReturnData | ConvertFrom-Json -AsHashtable -Depth $optimalDepth -ErrorAction Stop
                            "[{0}] Fallback conversion successful" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            
                            $customObject = [PSCustomObject]$_InvokeReturnData

                            if ($customObject.items) {
                                "[{0}] Fallback response detected with an items property!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                return $customObject.items
                            }
                            else {
                                "[{0}] Fallback response detected with no items property!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                return $customObject
                            }
                        }
                        catch {
                            "[{0}] All JSON conversion attempts failed" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            $PSCmdlet.ThrowTerminatingError($_)
                        }
                    }                    
                }
                else {
                    # Content is not JSON format
                    "[{0}] Response is not JSON format, returning raw content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $InvokeReturnData | Write-Verbose
                    return $InvokeReturnData
                }          
            }  
            else {
                "[{0}] No content returned from the request" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                return $null
            }
            #EndRegion
        }     
    }         
}

function Invoke-HPECOMWebRequest {  
    <#
     .SYNOPSIS
    Cmdlet to run web requests to the Compute Ops Management API. 

    .DESCRIPTION
    The `Invoke-HPECOMWebRequest` cmdlet sends HTTPS requests to the Compute Ops Management API. It adds the required headers, parses the response and returns the response.

    Upon execution, the cmdlet checks for an active HPE GreenLake session. If no session is found, it prompts the user to connect using 'Connect-HPEGL'.
    The cmdlet also supports automatic reconnection if the session has expired, ensuring seamless interaction with the API.
    The cmdlet supports pagination for GET requests, automatically retrieving all pages of results when applicable. It handles errors gracefully, providing informative messages for both critical and non-critical issues encountered during pagination.
    The cmdlet supports auto-completion for the 'Region' parameter, allowing users to easily select from available Compute Ops Management regions in their workspace.

    Upon successful execution, the cmdlet sets the `$Global:HPECOMInvokeReturnData` variable to the full response object, allowing users to access detailed information about the request and response. 
    If an error occurs, the variable is set to the error response object for further inspection.


    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER Uri
    The uri that identifies the required Compute Ops Management resource (eg. /compute-ops/v1beta2/job-templates').

    .PARAMETER Body
    Body for the request. Required if the method is POST or PUT.

    .PARAMETER Method
    The request HTTP Method. Valid values are:
            * "GET" (default) to get a resource from the appliance (read)
            * "POST" to create a new resource
            * "PUT" to modify a resource (write)
            * "PATCH" to modify a resource (write), with specific attributes set to values, other attributes should be set to $null.
            * "DELETE" to delete a resource

    .PARAMETER ContentType
    Specifies the content type of the request body. Default is 'application/json'.

    .PARAMETER MaxRetries
    Specifies the maximum number of retry attempts for the request. Default is 5.

    .PARAMETER InitialDelaySeconds
    Specifies the initial delay (in seconds) before retrying the request. Default is 1.

    .PARAMETER UseLegacyEndpoints
    Switch parameter to use legacy API endpoints. This is useful for compatibility with older versions of the API.

    .PARAMETER ReturnFullObject
    Switch parameter to return the full response object, including all properties, instead of only the items collection when an items property is present in the response.

    .PARAMETER WhatIfBoolean
    Switch parameter to show the user what would happen if the cmdlet was to run without actually running it.

    .EXAMPLE
    Invoke-HPECOMWebRequest -Uri "/compute-ops/v1beta2/job-templates" -Region "us-west" -Method "GET"

    .INPUTS
    None. You cannot pipe objects to this Cmdlet.

    .OUTPUTS
    The output of the cmdlet depends upon the format of the content that is retrieved.
    If the request returns JSON strings, Invoke-HPEGLWebRequest returns a PSObject that represents the strings.

    Upon successful execution, the cmdlet sets the `$Global:HPECOMInvokeReturnData` variable to the full response object, allowing users to access detailed information about the request and response. 
    If an error occurs, the variable is set to the error response object for further inspection.

    For error handling in try/catch blocks, use the `$Global:HPECOMInvokeReturnData` automatic variable to access the error response object, or the `$_.Exception.Details` variable's property for additional error context.

    #>
    [CmdletBinding()]
    Param (   
        
        [Parameter (Mandatory)]
        [String]$Uri,

        $Body, 

        [ValidateSet("GET", "POST", "PUT", "PATCH", "DELETE")]
        [String]$Method = "GET",

        [Parameter(Mandatory)] 
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

        [String]$ContentType = 'application/json',

        $WhatIfBoolean = $false,

        [int]$MaxRetries = 5,
        [int]$InitialDelaySeconds = 1,

        [switch]$UseLegacyEndpoints,

        [switch]$ReturnFullObject

    )
   
    Process {

        "[{0}] Starting Invoke-HPECOMWebrequest process..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        #Region Check if HPEGreenLakeSession variable is available
        try {
            Get-Variable -Name HPEGreenLakeSession -Scope Global -ErrorAction Stop | Out-Null
        }
        catch {
            Throw "No active HPE GreenLake session found. Please run 'Connect-HPEGL' to establish a session before using this cmdlet."
    
        }
        #EndRegion


        #Region Check if a reconnection is required
        try {
            "[{0}] Starting Invoke-HPEGLAutoReconnect process..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            Invoke-HPEGLAutoReconnect 
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
        #EndRegion


        #Region Retrieve $Global:HPECOMjobtemplatesUris if not available
        if (-not $Global:HPECOMjobtemplatesUris ) {

            "[{0}] Starting the collection of job template URIs process..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

            if ($Global:HPECOMRegions.count -gt 0) {
                $FirstProvisionedCOMRegion = $Global:HPECOMRegions | Select-Object -first 1 | Select-Object -ExpandProperty region
                "[{0}] About to retrieve the URIs of each job templates in '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $FirstProvisionedCOMRegion | Write-Verbose
                Set-HPECOMJobTemplatesVariable -Region $FirstProvisionedCOMRegion
            }
            else {
                "[{0}] Unable to retrieve job templates because no provisioned COM region was found in the current workspace." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                Throw "Error - No provisioned COM region found in the current workspace. Please ensure that at least one COM region is provisioned. You can provisioned regions using 'New-HPEGLService'."            
            }
        }
       
        #EndRegion
      

        #Region Check if COM API variable for the region is available + construct $url and pagination
        Clear-Variable -Name InvokeReturnData -ErrorAction SilentlyContinue

        "[{0}] Region selected: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose
    
        $GLPTemporaryCredentials = $Global:HPEGreenLakeSession.apiCredentials | Where-Object { $_.name -match "GLP-$global:HPEGLAPIClientCredentialName" }

        "[{0}] Credential found in `$Global:HPEGreenLakeSession.apiCredentials: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GLPTemporaryCredentials.name | Write-Verbose

        if ($Null -eq $GLPTemporaryCredentials) {

            Throw "Error: No API credential found. 'Connect-HPEGL' must be executed first to establish a session and generate the required credentials."
             
        }
        else {

            # Determine the connectivity endpoint based on the URI and region
            if ($uri -match "^/ui-doorway") {

                "[{0}] Endpoint matching with UI_Doorway: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $uri | Write-Verbose

                # Connectivity endpoint is always https://<RegionX>-api.compute.cloud.hpe.com
                $LoginUrl = $Global:HPECOMRegions | Where-Object { $_.region -eq $Region } | Select-Object -ExpandProperty loginUrl
                # Get region name for UI Doorway
                $UIDoorwayregion = ([Uri]$LoginUrl).Host -split '\.' | Select-Object -First 1
                
                $ConnectivityEndPoint = "https://$($UIDoorwayregion)-api.compute.cloud.hpe.com"

                "[{0}] Connectivity endpoint found: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ConnectivityEndPoint | Write-Verbose
                 
            }
            elseif ($UseLegacyEndpoints) {
                # Legacy connectivity endpoints are always: https://<Region>-api.compute.cloud.hpe.com
                # With regions having a number at the end (e.g., ap-northeast1, eu-central1, us-west2):
                # AP NorthEast = ap-northeast1
                # EU Central = eu-central1
                # US West = us-west2
                switch ($Region) {
                    "ap-northeast" { $RegionName = "ap-northeast1" }
                    "eu-central" { $RegionName = "eu-central1" }
                    "us-west" { $RegionName = "us-west2" }
                    default { Throw "Error - The specified region '$Region' is not supported for legacy endpoints. Supported regions are: 'ap-northeast', 'eu-central', 'us-west'." }
                }
                
                $ConnectivityEndPoint = "https://$RegionName-api.compute.cloud.hpe.com"
            }
            else {
                # Connectivity endpoint is always https://<Region>.api.greenlake.hpe.com
                $ConnectivityEndPoint = "https://$Region.api.greenlake.hpe.com"
            }

            "[{0}] Using connectivity endpoint: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ConnectivityEndPoint | Write-Verbose

            # Determine which access token to use (v1_2 preferred over v1_1)
            $glpApiAccessToken = $null
            # Use the v1_2 access token if available
            if ($Global:HPEGreenLakeSession.glpApiAccessTokenv1_2.access_token) {
                "[{0}] API Access token found in `$Global:HPEGreenLakeSession.glpApiAccessTokenv1_2" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                $glpApiAccessToken = $Global:HPEGreenLakeSession.glpApiAccessTokenv1_2.access_token
            } 
            elseif ($Global:HPEGreenLakeSession.glpApiAccessToken.access_token) {
                "[{0}] API Access token found in `$Global:HPEGreenLakeSession.glpApiAccessToken" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                $glpApiAccessToken = $Global:HPEGreenLakeSession.glpApiAccessToken.access_token
            }
            else {
                "[{0}] No API Access token found in `$Global:HPEGreenLakeSession" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                Throw "Error - No API Access Token found in `$Global:HPEGreenLakeSession! Connect-HPEGL must be executed !"
            }


            # Process pagination for GET 
            if ($Method -eq "GET") {

                $AllCollection = [System.Collections.ArrayList]::new()

                # Get 100 items pagination
                $pagination = 100

                # Detect if $uri contains a query parameter
                $url = $ConnectivityEndPoint + $uri
                $uriobj = [System.Uri]::new($url)

                # Parse the query parameters into a dictionary
                $queryParameters = [System.Web.HttpUtility]::ParseQueryString($uriobj.Query)
                
                # If contains a query limit parameter
                if ($queryParameters["limit"]) {

                    $Url = $ConnectivityEndPoint + $uri
                }
                # If contains another query parameter
                elseif ($uriobj.Query -ne "") {
                    $Url = $ConnectivityEndPoint + $uri + "&limit=$($pagination)&offset=0"
                }
                # If not contains any query parameter
                else {                    
                    $Url = $ConnectivityEndPoint + $uri + "?limit=$($pagination)&offset=0"
                }                
            }
            else {

                $url = $ConnectivityEndPoint + $uri

            }
        }
        #EndRegion

       
        #Region Construction for WhatIf
        if ( $WhatIfBoolean ) {
               
            $headers = @{} 
            $headers["Accept"] = "application/json"
            $headers["Authorization"] = "Bearer $($glpApiAccessToken)"

            Invoke-RestMethodWhatIf -Uri $Url -Method $Method -Body $Body -Headers $headers -ContentType $ContentType -Cmdlet "Invoke-HPECOMWebRequest"
                
        }
        #EndRegion
        

        #Region Construction for Invoke-Webrequest
        else {

            # Ensure System.Net.Http is loaded for compatibility
            Add-Type -AssemblyName System.Net.Http

            $headers = @{} 
            $headers["Accept"] = "application/json"
            $headers["Authorization"] = "Bearer $($glpApiAccessToken)"

            "[{0}] Request headers: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), (($headers | ConvertTo-Json) -Replace 'Bearer \S+', 'Bearer [REDACTED]') | Write-Verbose

            if ($body) {
                # If body is JSON
                if ($body.Trim().StartsWith('{') -and $body.Trim().EndsWith('}')) {
                    $Payload = $Body 
                }
                else {
                    # Convert the body hashtable to a JSON string
                    $Payload = $Body | ConvertTo-Json -Depth 10                
                }            
            }
            else {
                $Payload = $null
            }

            $lastException = $null
            $attempt = 0
            $complete = $false

            while (-not $complete -and $attempt -lt $MaxRetries) {          
                try {
                    "[{0}] About to make a '{1}' call to '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Method, $Url | Write-Verbose      
                    if ($Payload) {
                        "[{0}] Request body (payload) content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Payload | Write-Verbose
                    }
                    else {
                        "[{0}] No request body (payload) provided for this call." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    }

                    $InvokeReturnData = Invoke-WebRequest -Uri $Url -Method $Method -Headers $headers -Body $Payload -ContentType $ContentType
                    $Global:HPECOMInvokeReturnData = $InvokeReturnData
                    "[{0}] Received status code response: '{1}' - Description: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $InvokeReturnData.StatusCode, $InvokeReturnData.StatusDescription | Write-Verbose
                    if ($InvokeReturnData.Content) {
                        "[{0}] Response content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $InvokeReturnData.Content | Write-Verbose
                    }
                    $complete = $true
                }
                catch {
                    $attempt++
                    $lastException = $_        

                    # Extract error string for better diagnostics
                    $errorString = $_ | Out-String
                    $errorMsg = $_.Exception.Message
                    $parsedErrorMsg = $null
                    if ([string]::IsNullOrWhiteSpace($errorMsg)) {
                        try {
                            $parsedError = $errorString | ConvertFrom-Json -ErrorAction Stop
                            if ($parsedError -and $parsedError.message) {
                                $parsedErrorMsg = $parsedError.message
                            }
                        }
                        catch {}
                        $errorMsg = if ($parsedErrorMsg) { $parsedErrorMsg } else { $errorString }
                    }

                    Write-Verbose "-------------------------------------------- Catch triggered! -----------------------------------------------------------------------" 
                    "[{0}] Exception type: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.GetType().Name | Write-Verbose
                    "[{0}] Exception message: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $errorMsg | Write-Verbose

                    $statusCode = $null
                    $errorData = $null

                    if ($_.Exception.Response) {
                        $statusCode = [int]$_.Exception.Response.StatusCode
                        "[{0}] Received HTTP status code: '{1}'." -f $MyInvocation.InvocationName.ToString().ToUpper(), $statusCode | Write-Verbose
                    }
                    else {
                        "[{0}] No HTTP status code or response content available." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    }

                    # Extract JSON block from the exception string
                    $exceptionString = $_ | Out-String
                    if ($exceptionString -match '(\{[\s\S]*\})') {
                        $jsonBlock = $matches[1]
                        $decodedJson = [System.Text.RegularExpressions.Regex]::Unescape($jsonBlock)
                        try {
                            $prettyJson = $decodedJson | ConvertFrom-Json | ConvertTo-Json -Depth 30
                            "[{0}] Exception raw content (parsing): `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $prettyJson | Write-Verbose
                            $errorData = $prettyJson
                        }
                        catch {
                            "[{0}] Exception raw content (fallback): `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $decodedJson | Write-Verbose
                            $errorData = $decodedJson
                        }
                    }
                    else {
                        "[{0}] Exception raw content (unparsed): `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $exceptionString | Write-Verbose
                        $errorData = $exceptionString
                    }

                    Write-Verbose "--------------------------------------------------------------------------------------------------------------------------------------" 

                    if ($statusCode -in 408, 500, 502, 503, 504) {
                        "[{0}] HTTP error {1} encountered. Retrying in 1 second... (Attempt {2} of {3})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $statusCode, $attempt, $MaxRetries | Write-Verbose  
                        Start-Sleep -Seconds 1
                    }
                    else {
                        if ($errorMsg -eq "Unauthorized") {
                            $errorRecord = New-Object Management.Automation.ErrorRecord(
                                $_.Exception,
                                "HPECOMUnauthorizedError",
                                [Management.Automation.ErrorCategory]::AuthenticationError,
                                $null
                            )
                            $errorRecord | Add-Member -NotePropertyName "Message" -NotePropertyValue "Session has expired or been closed! Connect-HPEGL must be executed again!" -Force
                            $PSCmdlet.ThrowTerminatingError($errorRecord)
                        }
                        else {
                            "[{0}] Non-retriable error encountered. Exiting retry loop." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            break
                        }
                    }
                }
            }

            "[{0}] Exited retry loop. Complete: {1}, Attempts: {2}, MaxRetries: {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $complete, $attempt, $MaxRetries | Write-Verbose
            "[{0}] Before final exception check: lastException exists: {1}, complete: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($null -ne $lastException), $complete | Write-Verbose

            if ($lastException -and -not $complete) {
                Write-Verbose "-------------------------------------------- Final Exception Handling ------------------------------------------------------------------"
                "[{0}] Last exception occurred: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $lastException.Exception.Message | Write-Verbose
                "[{0}] Last exception type: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $lastException.GetType().Name | Write-Verbose

                if ($errorData) {
                    Write-Verbose "-------------------------------------------- Enhanced Exception Handling (`$ErrorMsg) ------------------------------------------------------------------"
                    # "[{0}] Raw error details: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMsg | Write-Verbose

                    try {
                        $errorData = $errorData | ConvertFrom-Json -ErrorAction Stop
                    }
                    catch {
                        $errorData = $null  # JSON parsing failed
                    }

                    # "[{0}] Parsed `$errorData: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $errorData | Write-Verbose

                    # Build your custom message as before
                    $exceptionMessage = [System.Collections.ArrayList]::new()

                    # Extract error details from issues
                    foreach ($detail in $errorData.errorDetails) {
                        if ($detail.issues -and $detail.issues.count -gt 0) {
                            # "[{0}] Found issues in errorDetail: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $detail.issues | Write-Verbose
                            $i = 1
                            foreach ($issue in $detail.issues) {
                                if ($issue.description) {
                                    $detailsMessage = "Issue $($i): " + [System.Text.RegularExpressions.Regex]::Unescape($issue.description)
                                    [void]$exceptionMessage.Add($detailsMessage)
                                }
                                $i++
                            }
                        }
                        if ($detail.metadata.details) {
                            $detailsMessage = [System.Text.RegularExpressions.Regex]::Unescape($detail.metadata.details)
                            [void]$exceptionMessage.add($detailsMessage)
                        }
                        if ($detail.metadata.error) {
                            $detailsMessage = [System.Text.RegularExpressions.Regex]::Unescape($detail.metadata.error)
                            [void]$exceptionMessage.add($detailsMessage)
                        }
                    }


                    $exceptionMessage = if ($exceptionMessage.count -gt 0) { $exceptionMessage -join " - " } else { $null }
                    # "[{0}] Constructed exceptionMessage: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $exceptionMessage | Write-Verbose
                    $Message = if ($errorData.message) { [System.Text.RegularExpressions.Regex]::Unescape($errorData.message) } else { $lastException.Exception.Message }
                    # "[{0}] Base message: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Message | Write-Verbose
                    $msg = if ($exceptionMessage) { "{0} - {1}" -f $Message, $exceptionMessage } else { $Message }
                    # "[{0}] Final constructed message: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $msg | Write-Verbose                   

                    If ($msg) {
                        # Attach enhanced message to lastException
                        "[{0}] Attached Details to lastException: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $msg | Write-Verbose
    
                        $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                            $lastException.Exception,
                            "CustomErrorID",
                            [System.Management.Automation.ErrorCategory]::NotSpecified,
                            $null
                        )
                        $errorRecord.Exception | Add-Member -NotePropertyName 'Details' -NotePropertyValue $msg -Force
                    }
                    else {
                        "[{0}] No message constructed, using last exception message: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $lastException.Exception.Message | Write-Verbose
                        $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                            $lastException.Exception,
                            "CustomErrorID",
                            [System.Management.Automation.ErrorCategory]::NotSpecified,
                            $null
                        )
                        $errorRecord.Exception | Add-Member -NotePropertyName 'Details' -NotePropertyValue "" -Force
                    }
                    
                    # Store error data in global variable
                    $Global:HPECOMInvokeReturnData = $errorData
                    "[{0}] Set Global:HPECOMInvokeReturnData: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Global:HPECOMInvokeReturnData | ConvertTo-Json -Depth 5) | Write-Verbose

                }
                else {
                    "[{0}] No errorData and ErrorMsg available, using fallback message: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $lastException.Exception.Message | Write-Verbose
                    $errorRecord = New-Object System.Management.Automation.ErrorRecord(
                        $lastException.Exception,
                        "CustomErrorID",
                        [System.Management.Automation.ErrorCategory]::NotSpecified,
                        $null
                    )
                    $errorRecord.Exception | Add-Member -NotePropertyName 'Details' -NotePropertyValue "" -Force
                }

                Throw $errorRecord
                    
            }            

            if ($InvokeReturnData) {               
                try {
                    if (Test-JsonFormat -Content $InvokeReturnData -InvocationName $MyInvocation.InvocationName.ToString().ToUpper()) {
                        # Detect JSON depth and set optimal conversion depth
                        $detectedDepth = Get-JsonDepth -JsonString $InvokeReturnData

                        # Add cap: Calculate candidate, enforce min 15, then max 100
                        $candidateDepth = $detectedDepth + 3
                        $optimalDepth = [Math]::Max($candidateDepth, 15)  # Enforce minimum
                        $optimalDepth = [Math]::Min($optimalDepth, 100)   # Enforce maximum cap

                        if ($optimalDepth -eq 100) { "[{0}] JSON depth capped at 100 to prevent recursion issues" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose }

                        # Initialize $paginationOptimalDepth
                        $paginationOptimalDepth = $optimalDepth  # Safe default before pagination
            
                        "[{0}] Detected JSON depth: {1} - Using conversion depth: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $detectedDepth, $optimalDepth | Write-Verbose

                        # Convert from JSON
                        try {
                            $InvokeReturnData = ConvertFrom-JsonCaseSensitive -JsonString $InvokeReturnData -MaxDepth $optimalDepth -InvocationName $MyInvocation.InvocationName.ToString().ToUpper()
                            "[{0}] JSON conversion successful with case-sensitive parsing at depth {1}!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $optimalDepth | Write-Verbose   

                            if ($InvokeReturnData -eq "OK") {
                                "[{0}] Response detected with an 'OK' response!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                return           
                            }   

                            if ($InvokeReturnData.PSObject.Properties['total']) {

                                "[{0}] Response detected with a count/total content" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                                if ($InvokeReturnData.total -gt 0) {
                                    
                                    "[{0}] Total items is {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $InvokeReturnData.total | Write-Verbose

                                    if (-not $InvokeReturnData.PSObject.Properties['items']) {
                                        Write-Error "[$($MyInvocation.InvocationName.ToString().ToUpper())] Items property missing in response"
                                        return
                                    }

                                    if ($Method -eq "GET" -and -not $queryParameters["limit"]) {
                                        $Offset = 0
                                        $failedPages = [System.Collections.ArrayList]::new() 

                                        # Instead of wrapping only items, keep the full object for ReturnFullObject
                                        $AllCollection = $InvokeReturnData
                                        $itemsCount = if ($InvokeReturnData.items) { $InvokeReturnData.items.Count } else { 0 }
                                        "[{0}] Total of items: '{1}' - Number of items per page: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $InvokeReturnData.total, $itemsCount | Write-Verbose

                                        if (-not $pagination -or $pagination -le 0) {
                                            Write-Error "[$($MyInvocation.InvocationName.ToString().ToUpper())] Invalid pagination value: '$pagination'"
                                            return
                                        }

                                        $Numberofpages = [System.Math]::Ceiling(($InvokeReturnData.total / $InvokeReturnData.items.count))
                                        "[{0}] Number of pages found: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Numberofpages | Write-Verbose

                                        if ($Numberofpages -gt 1) {
                                            for ($i = 1; $i -lt $Numberofpages; $i++) {
                                                $Offset += [int]$pagination
                                                if ($uriobj.Query -ne "") {
                                                    $Url = "$($ConnectivityEndPoint)$($uri)&limit=$($pagination)&offset=$($Offset)"
                                                } else {
                                                    $Url = "$($ConnectivityEndPoint)$($uri)?limit=$($pagination)&offset=$($Offset)"
                                                }
                                                "[{0}] Request URI for page '{1}': '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($i + 1), $Url | Write-Verbose

                                                try {
                                                    $paginationResponse = Invoke-WebRequest -Uri $Url -Method $Method -Headers $headers -Body $Body -ContentType $ContentType
                                                    $Global:HPECOMInvokeReturnData = $paginationResponse

                                                    "[{0}] Received status code response: '{1}' - Description: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $paginationResponse.StatusCode, $paginationResponse.StatusDescription | Write-Verbose
                                                    if ($paginationResponse.Content) {
                                                        "[{0}] Response content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $paginationResponse.Content | Write-Verbose
                                                    }

                                                    $paginationDepth = Get-JsonDepth -JsonString $paginationResponse.Content
                                                    
                                                    # Add cap: Calculate candidate, enforce min against current $paginationOptimalDepth, then max 100
                                                    $candidateDepth = $paginationDepth + 3
                                                    $paginationOptimalDepth = [Math]::Max($candidateDepth, $paginationOptimalDepth)  # Track max (with min buffer)
                                                    $paginationOptimalDepth = [Math]::Min($paginationOptimalDepth, 100)              # Enforce maximum cap

                                                    "[{0}] Detected JSON depth: {1} - Using conversion depth: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $paginationDepth, $paginationOptimalDepth | Write-Verbose

                                                    $InvokeReturnMoreData = ConvertFrom-JsonCaseSensitive -JsonString $paginationResponse.Content -MaxDepth $paginationOptimalDepth -InvocationName $MyInvocation.InvocationName.ToString().ToUpper()
                                                    "[{0}] Pagination response converted with case-sensitive parsing at depth {1}!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $paginationOptimalDepth | Write-Verbose
                                                    "[{0}] Adding page '{1}' to the result" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($i + 1) | Write-Verbose
                                                    # Merge items into the original object
                                                    # $AllCollection.items += $InvokeReturnMoreData.items
                                                    $AllCollection.items = @($AllCollection.items) + @($InvokeReturnMoreData.items)  # Ensure arrays
                                                }
                                                catch {
                                                    $errorMsg = $_.Exception.Message
                                                    $statusCode = if ($_.Exception.Response) { [int]$_.Exception.Response.StatusCode } else { $null }

                                                    # Classify error
                                                    $isCritical = $statusCode -in 401, 403, 404  # Add other critical codes as needed
                                                    if ($isCritical) {
                                                        "[{0}] Critical error on page {1}: {2} (Status: {3})" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($i + 1), $errorMsg, $statusCode | Write-Verbose
                                                        Write-Error "[$($MyInvocation.InvocationName.ToString().ToUpper())] Critical error on page $($i + 1): $_"
                                                        $PSCmdlet.ThrowTerminatingError($_)  # Stop for critical errors
                                                    }
                                                    else {
                                                        "[{0}] Non-critical error on page {1}: {2} (Status: {3}). Skipping page." -f $MyInvocation.InvocationName.ToString().ToUpper(), ($i + 1), $errorMsg, $statusCode | Write-Verbose
                                                        Write-Warning "[$($MyInvocation.InvocationName.ToString().ToUpper())] Skipped page $($i + 1) due to error: $_"
                                                        $failedPages.Add($i + 1) | Out-Null  # Track for summary
                                                        continue  # Skip to next page
                                                    }
                                                }
                                            }

                                            # Log summary of failed pages
                                            if ($failedPages.Count -gt 0) {
                                                "[{0}] Pagination completed with {1} failed page(s): {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $failedPages.Count, ($failedPages -join ", ") | Write-Verbose
                                                Write-Warning "[$($MyInvocation.InvocationName.ToString().ToUpper())] Fetched partial data; failed pages: $($failedPages -join ', ')"
                                            }
                                        }

                                        $InvokeReturnData = $AllCollection
                                        $Depth = if ($paginationOptimalDepth -and $paginationOptimalDepth -is [int]) { $paginationOptimalDepth } else { $optimalDepth }
                                        if (-not $Depth -or $Depth -lt 1) {
                                            $Depth = 15  # Safe default
                                            "[{$($MyInvocation.InvocationName.ToString().ToUpper())}] Warning: Depth undefined or invalid, using default depth: $Depth" | Write-Verbose
                                        }

                                        if ($ReturnFullObject) {
                                            "[{0}] Leaving Invoke-HPECOMWebRequest and returning the full response content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnData | ConvertTo-Json -Depth $Depth) | Write-Verbose
                                            return $InvokeReturnData
                                        }
                                        elseif ($InvokeReturnData.items) {
                                            "[{0}] Leaving Invoke-HPECOMWebRequest and returning the items content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnData.items | ConvertTo-Json -Depth $Depth) | Write-Verbose
                                            return $InvokeReturnData.items
                                        }
                                        else {
                                            "[{0}] Leaving Invoke-HPECOMWebRequest and returning the full response content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnData | ConvertTo-Json -Depth $Depth) | Write-Verbose
                                            return $InvokeReturnData
                                        }
                                    }
                                    else {
                                        "[{0}] Pagination detected with a 'limit' query parameter; returning all items from the current page." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                        $Depth = if ($paginationOptimalDepth -and $paginationOptimalDepth -is [int]) { $paginationOptimalDepth } else { $optimalDepth }
                                        if (-not $Depth -or $Depth -lt 1) {
                                            $Depth = 15  # Safe default
                                            "[{$($MyInvocation.InvocationName.ToString().ToUpper())}] Warning: Depth undefined or invalid, using default depth: $Depth" | Write-Verbose
                                        }
                                        
                                        if ($ReturnFullObject) {
                                            "[{0}] Leaving Invoke-HPECOMWebRequest and returning the full response content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnData | ConvertTo-Json -Depth $Depth) | Write-Verbose
                                            return $InvokeReturnData
                                        }
                                        elseif ($InvokeReturnData.items) {
                                            "[{0}] Leaving Invoke-HPECOMWebRequest and returning the items content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnData.items | ConvertTo-Json -Depth $Depth) | Write-Verbose
                                            return $InvokeReturnData.items
                                        }
                                        else {
                                            "[{0}] Leaving Invoke-HPECOMWebRequest and returning the full response content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnData | ConvertTo-Json -Depth $Depth) | Write-Verbose
                                            return $InvokeReturnData
                                        }
                                    }
                                }
                                else {
                                    "[{0}] Response detected with no items (total is 0)" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                    "[{0}] Leaving Invoke-HPECOMWebRequest and returning no content" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                    return
                                }
                            }
                            else {
                                "[{0}] Response detected with no total property!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                $Depth = if ($paginationOptimalDepth -and $paginationOptimalDepth -is [int]) { $paginationOptimalDepth } else { $optimalDepth }
                                if (-not $Depth -or $Depth -lt 1) {
                                    $Depth = 15  # Safe default
                                    "[{$($MyInvocation.InvocationName.ToString().ToUpper())}] Warning: Depth undefined or invalid, using default depth: $Depth" | Write-Verbose
                                }
                                "[{0}] Leaving Invoke-HPECOMWebRequest and returning the response content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InvokeReturnData | ConvertTo-Json -Depth $Depth) | Write-Verbose
                                return $InvokeReturnData
                            }
                        }
                        catch {
                            Write-Error "Failed to parse the returned JSON: $($_.Exception.Message). Attempting to reformat the data; output may not be formatted correctly."
                            "[{0}] JSON parsing failed: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                
                            try {
                                "[{0}] Attempting fallback with standard ConvertFrom-Json..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                $_InvokeReturnData = $InvokeReturnData | ConvertFrom-Json -AsHashtable -Depth $optimalDepth -ErrorAction Stop
                                "[{0}] Fallback conversion successful" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    
                                $customObject = [PSCustomObject]$_InvokeReturnData

                                if ($customObject.items -and -not $ReturnFullObject) {
                                    "[{0}] Fallback response detected with an items property!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                    return $customObject.items
                                }
                                else {
                                    "[{0}] Fallback response detected with no items property!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                    return $customObject
                                }
                            }
                            catch {
                                "[{0}] All JSON conversion attempts failed" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                                $PSCmdlet.ThrowTerminatingError($_)
                            }
                        }
                    }
                    else {
                        "[{0}] Response is not JSON format, returning raw content: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $InvokeReturnData | Write-Verbose
                        return $InvokeReturnData
                    }
                }
                catch {
                    "[{0}] Error processing response content: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_.Exception.Message | Write-Verbose
                    return $null
                }
            }
            else {
                if (-not $lastException) {
                    "[{0}] No response content received." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                    return $null
                }
            }                          
        }
    }         
}

function Connect-HPEOnepass {
    <#
    .SYNOPSIS
    Connects to HPE Onepass using OAuth2 Authorization Code Flow with PKCE.

    .DESCRIPTION
    This function initiates an OAuth2 authentication flow against HPE Onepass, retrieves an access token, and stores it in the global session object. 
    It requires a previously initialized HPEGreenLakeSession (via Connect-HPEGL).

    .PARAMETER OnepassClientId
    The OAuth2 client ID for HPE Onepass. Defaults to '0oanq2cp67rSBpQVU357'.

    .PARAMETER RedirectUri
    The redirect URI registered for the OAuth2 client. Defaults to 'https://auth.hpe.com/profile/login/callback'.

    .EXAMPLE
    PS> Connect-HPEOnepass

    Initiates the Onepass authentication flow and returns the access token object.

    .NOTES
    Requires a valid global HPEGreenLakeSession and HPEGLOauth2IssuerId. Run Connect-HPEGL first.

    #>
    
    [CmdletBinding()]
    param (
        [String]$OnepassClientId = "0oanq2cp67rSBpQVU357",
        [String]$RedirectUri = "https://auth.hpe.com/profile/login/callback"
        
    )

    Write-Verbose ("[{0}] Starting Connect-HPEOnepass" -f $MyInvocation.InvocationName.ToString().ToUpper())
    $functionName = 'Connect-HPEOnepass'

    # Ensure global session object exists
    if (-not $Global:HPEGreenLakeSession -or -not $Global:HPEGLOauth2IssuerId) { 
        throw "Global HPEGreenLakeSession is not initialized. Please run Connect-HPEGL first to initialize the session."
    }
    
    
    # Check if existing token is still valid, refresh only if expired        
    if ($Global:HPEGreenLakeSession.onepassToken.creation_time -and $Global:HPEGreenLakeSession.onepassToken.expires_in) {
        $creationTime = [datetime]::Parse($Global:HPEGreenLakeSession.onepassToken.creation_time)
        $expiresIn = [int]$Global:HPEGreenLakeSession.onepassToken.expires_in
        $expiryTime = $creationTime.AddSeconds($expiresIn)
        if ((Get-Date) -ge $expiryTime) {            
            Write-Verbose ("[{0}] Existing Onepass token has expired, proceeding to refresh." -f $MyInvocation.InvocationName.ToString().ToUpper())
        }
        else {
            Write-Verbose ("[{0}] Existing Onepass token is still valid, skipping re-authentication." -f $MyInvocation.InvocationName.ToString().ToUpper())
            return $Global:HPEGreenLakeSession.onepassToken
        }
    }

    ##### Login to OnePass to get access token #####
    # Step 1: Generate code verifier and challenge
    Write-Verbose ("[{0}] [OAUTH2 - Onepass] Step 7.1: Generating code verifier and challenge" -f $functionName)
    $code_verifier = [System.Convert]::ToBase64String((1..64 | ForEach-Object { Get-Random -Maximum 256 }) -as [byte[]]) -replace '[+/=]', { switch ($_) { '+' { '-' } '/' { '_' } '=' { '' } } }
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $code_challenge = [System.Convert]::ToBase64String($sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($code_verifier))) -replace '[+/=]', { switch ($_) { '+' { '-' } '/' { '_' } '=' { '' } } }

    # Step 2: Prepare OAuth2/OIDC parameters
    Write-Verbose ("[{0}] [OAUTH2 - Onepass] Step 2: Preparing OAuth2/OIDC parameters" -f $functionName)
    $Scope = "openid email profile"
    $State = ([System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((New-Guid).Guid))).Replace('=', '').Replace('+', '').Replace('/', '')
    $Nonce = ([System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes((New-Guid).Guid))).Replace('=', '').Replace('+', '').Replace('/', '')

    # Step 3: Build authorize URL
    Write-Verbose ("[{0}] [OAUTH2 - Onepass] Step 7.3: Building authorize URL" -f $functionName)
    $authorizeUrl = "https://auth.hpe.com/oauth2/$($Global:HPEGLOauth2IssuerId)/v1/authorize" +
    "?client_id=$OnepassClientId" +
    "&code_challenge=$code_challenge" +
    "&code_challenge_method=S256" +
    "&nonce=$Nonce" +
    "&redirect_uri=$([uri]::EscapeDataString($RedirectUri))" +
    "&response_type=code" +
    "&state=$State" +
    "&scope=$([uri]::EscapeDataString($Scope))"

    # Step 4: Start session and GET login page   
    Write-Verbose ("[{0}] [OAUTH2 - Onepass] Step 7.4: Starting session and GET login page" -f $functionName)         
    $maxRedirects = 5
    $currentUrl = $authorizeUrl
    $loginPageUrl = $null
    Write-Verbose ("[{0}] [OAUTH2 - Onepass] About to execute GET request to: '{1}'" -f $functionName, $currentUrl)

    # Force skip=true cookie to bypass /hpe/cf/ challenge 
    try {
        $cookie = New-Object System.Net.Cookie('skip', 'true', '/', 'auth.hpe.com')
        $Global:HPEGreenLakeSession.AuthSession.Cookies.Add($cookie)
        Write-Verbose '[OAUTH2 - Onepass] Forced skip=true cookie in AuthSession.'
    }
    catch { Write-Verbose '[OAUTH2 - Onepass] Failed to set skip=true cookie: ' + $_ }

    for ($i = 1; $i -le $maxRedirects; $i++) {
        Write-Verbose ("[{0}] ------------------------------------- Redirection {1} -------------------------------------" -f $functionName, $i)
        Write-Verbose ("[{0}] [OAUTH2 - Onepass] Redirect $($i): $currentUrl" -f $functionName)

        try {
            $response = Invoke-WebRequest -Uri $currentUrl -WebSession $Global:HPEGreenLakeSession.AuthSession -Method Get -MaximumRedirection 0 -ErrorAction Stop
            $loginPageUrl = $currentUrl
            break
        }
        catch {
            $location = $null
            if ($_.Exception.Response -and $_.Exception.Response.Headers["Location"]) {
                $location = $_.Exception.Response.Headers["Location"]
            }
            elseif ($_.Exception.Response -and $_.Exception.Response.Headers.GetValues) {
                try { $location = $_.Exception.Response.Headers.GetValues("Location")[0] } catch {}
            }
            if ($location) {
                $currentUrl = $location
                $loginPageUrl = $location
                continue
            }
            else {
                throw "[OAUTH2 - Onepass] Failed to retrieve login page URL."
            }
        }
    }
    if ($loginPageUrl -match "error=") {
        throw "[OAUTH2 - Onepass] Error encountered while attempting to access login page: $loginPageUrl"
    }

    # Only handle callback URL and error cases, never a login form
    if ($loginPageUrl -match "/profile/login/callback" -and $loginPageUrl -match "code=") {
        Write-Verbose ("[{0}] [OAUTH2 - Onepass] Already at callback URL with code." -f $functionName)
        $callbackUrl = $loginPageUrl
    }
    else {
        $callbackUrl = $loginPageUrl
    }

    # Extract code from callback URL
    Write-Verbose ("[{0}] [OAUTH2 - Onepass] Extracting authorization code from callback URL" -f $functionName)
    $code = $null
    if ($callbackUrl -match "[?&]code=([^&]+)") {
        $code = $matches[1]
        Write-Verbose ("[{0}] [OAUTH2 - Onepass] Extracted code: $code" -f $functionName)
    }
    else {
        throw "[OAUTH2 - Onepass] Could not extract authorization code from callback URL: $callbackUrl"
    }

    # Step 5: Exchange code for tokens
    Write-Verbose ("[{0}] [OAUTH2 - Onepass] Exchanging code for tokens" -f $functionName)
    $tokenEndpoint = "https://auth.hpe.com/oauth2/$($Global:HPEGLOauth2IssuerId)/v1/token"
    $tokenPayloadObj = @{
        grant_type    = "authorization_code"
        code          = $code
        redirect_uri  = $RedirectUri
        client_id     = $OnepassClientId
        code_verifier = $code_verifier
    }
    $body = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
    $tokenPayloadObj.GetEnumerator() | ForEach-Object { $body.Add($_.Key, $_.Value) }
    $bodyString = $body.ToString()
    $tokenHeaders = @{ 'Content-Type' = 'application/x-www-form-urlencoded' }
    $tokenResponse = Invoke-RestMethod -Uri $tokenEndpoint -Method Post -Body $bodyString -Headers $tokenHeaders
    $OnepassOauth2AccessToken = $tokenResponse.access_token
    if ($OnepassOauth2AccessToken) {
        Write-Verbose ("[{0}] [OAUTH2 - Onepass] Access token successfully retrieved. Token preview: {1}..." -f $functionName, $OnepassOauth2AccessToken.Substring(0, [Math]::Min(50, $OnepassOauth2AccessToken.Length)))
    }
    else {
        throw "[OAUTH2 - Onepass] Failed to retrieve access token from token endpoint. This may occur if you attempt to run the connection multiple times in a short period. Please wait a moment and try again."
    }

    # Store Onepass credentials
    $OnepassCredential = [PSCustomObject]@{
        access_token  = $OnepassOauth2AccessToken
        id_token      = $tokenResponse.id_token
        expires_in    = $tokenResponse.expires_in
        token_type    = $tokenResponse.token_type
        creation_time = Get-Date
    }
    # Save tokens in global session
    $Global:HPEGreenLakeSession.onepassToken = $OnepassCredential
    "[{0}] Connection to HPE Onepass successful!" -f $functionName | Write-Verbose

    return (($Global:HPEGreenLakeSession.onepassToken | ConvertTo-Json -Depth 5) -replace '("access_token":\s*)"[^"]+"', '$1[REDACTED]' -replace '("id_token":\s*)"[^"]+"', '$1[REDACTED]')
}

Function Connect-HPEGL { 
    <#
    .SYNOPSIS
    Initiates a connection to the HPE GreenLake platform and to all available Compute Ops Management instances within the specified workspace.
    
    .DESCRIPTION
    This cmdlet initiates and manages your connection to the HPE GreenLake platform. Upon successful connection, it creates a persistent session for all subsequent module cmdlet requests through the ${Global:HPEGreenLakeSession}` connection tracker variable. 
    Additionally, the cmdlet generates a temporary unified API client credential for HPE GreenLake and any Compute Ops Management service instances provisioned in the workspace.
    
    The global variable `$Global:HPEGreenLakeSession` stores session information, API client credentials, API access tokens, and other relevant details for both HPE GreenLake and Compute Ops Management APIs.
    
    To use this cmdlet, you need an HPE Account. If you do not have an HPE Account, you can create one at https://common.cloud.hpe.com.
    
    Note: To learn how to create an HPE account, see https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us&page=GUID-497192AA-FDC2-49C5-B572-0D2F58A23745.html
    
    Note: To interact with an HPE GreenLake workspace and a Compute Ops Management instance using this library, you must have at least the 'Observer' role for both 'HPE GreenLake Platform' and 'Compute Ops Management' service managers. 
          This role grants view-only privileges. For modification capabilities, you need either the 'Operator' (view and edit privileges) or the 'Administrator' (view, edit, and delete privileges) role. 
          Alternatively, you can create a custom role that meets your specific access requirements.
    
    Note: This library supports both single-factor authentication and multi-factor authentication (MFA) using Google Authenticator or Okta Verify. 
          To use MFA, ensure that the Okta Verify or Google Authenticator app is installed on your mobile device and properly linked to your account before initiating the connection process. 
          MFA with security keys or biometric authenticators is not supported. 
          - If your HPE GreenLake account is configured to use only security keys or biometric authenticators for MFA, you must enable either Google Authenticator or Okta Verify in your account settings to use this library.
          - For accounts with Google Authenticator enabled, you will be prompted to enter the verification code. 
          - For accounts with Okta Verify enabled, you will need to approve the push notification on your phone.
          - If both Google Authenticator and Okta Verify are enabled, the library defaults to using Okta Verify push notifications.
    
    Note: This library supports SAML Single Sign-On (SSO) but exclusively for HPE.com email addresses. Other domains or identity providers are not supported for direct SSO authentication. 
          To use SSO, ensure that the Okta Verify app is installed on your mobile device and properly linked to your account before initiating the connection process. 
          Users leveraging SAML SSO through other identity providers cannot authenticate directly using their corporate credentials with the `Connect-HPEGL` cmdlet. 
          As a workaround, invite a user with an email address that is not associated with any SAML SSO domains configured in the workspace. 
          This can be done via the HPE GreenLake GUI under `User Management` by selecting `Invite Users`. Assign the HPE GreenLake Account Administrator role to the invited user. 
          Once the invitation is accepted, the user can set a password and use these credentials to log in with `Connect-HPEGL`.
    
    Note: You do not need an existing HPE GreenLake workspace to connect. You can create a new workspace after your first connection using the 'New-HPEGLWorkspace' cmdlet.
    
    .PARAMETER Credential 
    Set of security credentials such as a username and password to establish a connection to HPE GreenLake.
    
    .PARAMETER SSOEmail
    Specifies the email address to use for Single Sign-On (SSO) authentication. SSO is supported only for HPE.com email addresses. Other domains or identity providers are not supported for direct SSO authentication.
    
    .PARAMETER Workspace 
    Specifies the name of a workspace available in HPE GreenLake that you want to connect to.
    
    - You can omit this parameter if no workspaces have been created in HPE GreenLake yet.
    - If you have only one workspace in HPE GreenLake, you can omit this parameter, and the cmdlet will automatically connect to the available workspace.
    - If you have multiple workspaces and are unsure of the workspace name you want to connect to, you can omit this parameter. After connecting to HPE GreenLake, use the 'Get-HPEGLWorkspace' cmdlet to list and identify the available workspaces.
    
    .PARAMETER RemoveExistingCredentials
    Specifies whether to remove all existing API credentials generated by previous runs of Connect-HPEGL or Connect-HPEGLWorkspace that were not properly cleaned up by a Disconnect-HPEGL operation.
    When enabled, this option will delete all previously created API credentials attached to your user account that may be lingering from earlier sessions.
    Use this option if you encounter the error: 'You have reached the maximum of 7 personal API clients' when connecting. Removing these credentials can resolve the issue by clearing out unused credentials created by this library.

    Caution: Removing existing credentials may affect other active PowerShell sessions related to your user using those credentials, potentially causing authentication failures until those sessions reconnect.

    .PARAMETER NoProgress
    Suppresses the progress bar display for automation or silent operation.

    .INPUTS
    None. You cannot pipe objects to this cmdlet.
    
    .OUTPUTS
    HPEGreenLakeSession
    
    When a valid connection is established with the HPE GreenLake platform, several properties are added to the 
    `${Global:HPEGreenLakeSession}` connection tracker variable. The object returned will contain the following public properties:
            
         ====================================================================================================================
         | Name                      | Type               | Value                                                           |
         --------------------------------------------------------------------------------------------------------------------
         | AuthSession               | WebRequestSession  | Web session object used for Okta/HPE GreenLake authentication   |
         --------------------------------------------------------------------------------------------------------------------
         | WorkspaceSession          | WebRequestSession  | Web session object for the selected workspace (API operations)  |
         --------------------------------------------------------------------------------------------------------------------
         | oauth2AccessToken         | String             | OAuth2 access token                                             | 
         --------------------------------------------------------------------------------------------------------------------
         | oauth2IdToken             | String             | OAuth2 ID Token                                                 |
         --------------------------------------------------------------------------------------------------------------------
         | oauth2RefreshToken        | String             | OAuth2 refresh token                                            |
         --------------------------------------------------------------------------------------------------------------------
         | userName                  | String             | Username used for authentication                                |
         --------------------------------------------------------------------------------------------------------------------
         | name                      | String             | Name of the user used for authentication                        |
         --------------------------------------------------------------------------------------------------------------------
         | workspaceId               | String             | Workspace ID                                                    |
         --------------------------------------------------------------------------------------------------------------------
         | workspace                 | String             | Workspace name                                                  |
         --------------------------------------------------------------------------------------------------------------------
         | workspacesCount           | Integer            | Number of available workspaces                                  |
         --------------------------------------------------------------------------------------------------------------------
         | organization              | String             | Name of the organization governance                             |
         --------------------------------------------------------------------------------------------------------------------
         | organizationId            | String             | ID of the organization governance                               |
         --------------------------------------------------------------------------------------------------------------------
         | oauth2TokenCreation       | Datetime           | OAuth2 token creation time                                      |
         --------------------------------------------------------------------------------------------------------------------
         | oauth2TokenCreationEpoch  | String             | Unix timestamp of OAuth2 token creation                         |     
         --------------------------------------------------------------------------------------------------------------------
         | apiCredentials            | ArrayList          | List of API client credentials created during the session       |
         --------------------------------------------------------------------------------------------------------------------
         | glpApiAccessToken         | String             | HPE GreenLake API access token for workspace v1                 |       
         --------------------------------------------------------------------------------------------------------------------
         | glpApiAccessTokenv1_2     | String             | HPE GreenLake API access token for workspace v2                 |       
         --------------------------------------------------------------------------------------------------------------------
         | ccsSid                    | String             | HPE CCS session ID                                              |    
         --------------------------------------------------------------------------------------------------------------------
         | onepassToken              | Object             |  OAuth2 token details for the HPE Onepass authentication        |    
         ====================================================================================================================
    
    API client credentials are stored in `${Global:HPEGreenLakeSession.apiCredentials}` and contains the following properties:
         
         ====================================================================================================================
         | Name                    | Type         | Value                                                                   |
         --------------------------------------------------------------------------------------------------------------------
         | name                    | String       | Name of the API client credential                                       |
         --------------------------------------------------------------------------------------------------------------------
         | workspace_name          | String       | Name of the associated workspace                                        |
         --------------------------------------------------------------------------------------------------------------------
         | workspace_id            | String       | ID of the associated workspace                                          |
         --------------------------------------------------------------------------------------------------------------------
         | application_name        | String       | Name of the provisioned service (e.g., Compute Ops Mgmt)                |
         --------------------------------------------------------------------------------------------------------------------
         | region                  | String       | Region code where the service is provisioned                            |
         --------------------------------------------------------------------------------------------------------------------
         | application_instance_id | String       | Unique ID of the service instance                                       |
         --------------------------------------------------------------------------------------------------------------------
         | secure_client_secret    | SecureString | Encrypted client secret for the API client credential                   |
         --------------------------------------------------------------------------------------------------------------------
         | client_id               | String       | Client ID for the API client credential                                 |
         --------------------------------------------------------------------------------------------------------------------
         | connectivity_endpoint   | String       | API endpoint URL for the service                                        |
         ====================================================================================================================

    OAuth2 token details for the HPE Onepass authenticatio are stored in `${Global:HPEGreenLakeSession.OnepassToken}` and contains the following properties:
         
         ====================================================================================================================
         | Name           | Type     | Value                                                                                |
         --------------------------------------------------------------------------------------------------------------------
         | access_token   | String   | Access token for the HPE Onepass application                                         |
         --------------------------------------------------------------------------------------------------------------------
         | id_token       | String   | ID token for the HPE Onepass application                                             |
         --------------------------------------------------------------------------------------------------------------------
         | refresh_token  | String   | Refresh token for the HPE Onepass application                                        |
         --------------------------------------------------------------------------------------------------------------------
         | token_type     | String   | Type of the token (e.g., Bearer)                                                     |
         --------------------------------------------------------------------------------------------------------------------
         | expires_in     | Int      | Number of seconds until the token expires                                            |
         --------------------------------------------------------------------------------------------------------------------
         | creation_time  | Datetime | Date and time when the token was created                                             |
         ====================================================================================================================

    The HPE GreenLake API token details are stored in ${Global:HPEGreenLakeSession.glpApiAccessToken} and ${Global:HPEGreenLakeSession.glpApiAccessTokenv1_2} for v2 workspace and contains the following properties:

         ====================================================================================================================
         | Name                       | Type               | Value                                                           |
         --------------------------------------------------------------------------------------------------------------------
         | name                       | String             | Name of the API Client credential                               | 
         --------------------------------------------------------------------------------------------------------------------
         | access_token               | String             | Access token of the API client credential                       |
         --------------------------------------------------------------------------------------------------------------------
         | expires_in                 | String             | Time in seconds until the token expires                         |
         --------------------------------------------------------------------------------------------------------------------
         | creation_time              | Datetime           | Date and time of when the token was created                     |
         ====================================================================================================================
   
    .EXAMPLE
    Connect-HPEGL  
    
    Connect to HPE GreenLake when you have not yet created any workspace. The user will be prompted for their username and password.
    
    In this example, no parameters are passed to the `Connect-HPEGL` cmdlet, which will prompt the user for their HPE GreenLake username and password. 
    This is useful when connecting to HPE GreenLake for the first time or when no workspace exists yet.
    
    If there is only one workspace available, the cmdlet will automatically connect to that workspace. 
    
    If multiple workspaces exist, the user can use the `Get-HPEGLWorkspace` cmdlet once connected to retrieve the workspace names and then specify the desired workspace to connect to using 'Connect-HPEGLWorkspace -Name <WorkspaceName>'.
    
    .EXAMPLE
    $Username = "Sean@gmail.com"
    $Secpasswd = read-host "Please enter your HPE GreenLake password" -AsSecureString
    $Credentials = New-Object System.Management.Automation.PSCredential ($Username, $Secpasswd)
    Connect-HPEGL -Credential $Credentials 
    
    Connect the user Sean@gmail.com to HPE GreenLake using a PSCredential object. 
    
    In this example, the username and password are collected first, and then a PSCredential object is created. The credential object is subsequently passed to the `Connect-HPEGL` cmdlet to establish the connection.
    
    .EXAMPLE
    Connect-HPEGL -Credential $Credentials -Workspace "My_workspace_name" 
    
    Connect the user Sean@gmail.com to an existing workspace named "My_workspace_name" in HPE GreenLake using a PSCredential object. 
    Temporary HPE GreenLake and COM API client credentials are generated in the newly connected 'My_workspace_name' workspace.
    '$Global:HPEGreenLakeSession' is updated with the new API credentials and workspace details.
    
    Here, the previously created PSCredential object is used again, but this time with an additional `-Workspace` parameter to specify which workspace in HPE GreenLake to connect to.
    
    .EXAMPLE
    $GLP_Username = "lio@domain.com"
    $GLP_EncryptedPassword = "...01000000d08c9ddf0115d1118c7a00c04fc297eb01000000ea1f94d2f2dc2b40af7a0adaeeae84b1f349432b32a730af3b80567e2378c570b3a111d627d70ac9eb6f281..."
    $GLP_SecurePassword = ConvertTo-SecureString $GLP_EncryptedPassword
    $credentials = New-Object System.Management.Automation.PSCredential ($GLP_Username, $GLP_SecurePassword)
    
    Connect-HPEGL -Credential $credentials -Workspace "HPE Workspace" 
    
    Connect the user lio@domain.com to an existing workspace named "HPE Workspace" using an encrypted password.
    
    In this example, the secure password string is first converted to a SecureString, and then a PSCredential object is created using an encrypted password and username. This credential object is then used to connect to a specific workspace named "HPE Workspace".
    
    Using an encrypted password like $GLP_EncryptedPassword in a script enhances security by preventing unauthorized access to plaintext credentials, and follows best practices for secure coding. It also reduces the risk of human error and accidental exposure during code sharing or review processes.
    
    To generate an encrypted password, you can use:
    ConvertTo-SecureString -String "<Your_HPE_GreenLake_Password>" -AsPlainText -Force |  ConvertFrom-SecureString 
    
    .EXAMPLE
    Connect-HPEGL -Credential $credentials
    
    # Get the list of available workspaces
    Get-HPEGLWorkspace 
    
    # Connect to a specific workspace from the list of workspaces
    Connect-HPEGLWorkspace -Name "<WorkspaceName>"
    
    This example demonstrates how to connect to the HPE GreenLake platform using provided credentials, retrieve the list of available workspaces, and then connect to a specific workspace when the workspace name is unknown.
    
    .EXAMPLE
    Connect-HPEGL -SSOEmail "firstname.lastname@hpe.com" -Workspace "My_workspace_name" 
    
    This example demonstrates how to connect to HPE GreenLake using Single Sign-On (SSO) with an email address.
    The user will be prompted to approve the push notification on their phone for authentication.
    If the workspace name is specified, the cmdlet will connect to the specified workspace.
    If no workspace name is provided, the cmdlet will connect to the default workspace associated with the user's account.
    
    .LINK
    If you do not have an HPE Account, you can create one at https://common.cloud.hpe.com.
    
    To learn how to create an HPE account, see https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us&page=GUID-497192AA-FDC2-49C5-B572-0D2F58A23745.html
    
    #>
    [CmdletBinding(DefaultParameterSetName = 'Credential')]
    param (
        [Parameter(Mandatory, ParameterSetName = 'Credential')]
        [Alias('PSCredential')]
        [PSCredential]$Credential,
    
        [Parameter(Mandatory = $true, ParameterSetName = 'SSO')]
        [string]$SSOEmail,
    
        [Parameter(Mandatory = $False)]        
        [ValidateNotNullOrEmpty()]
        [String]$Workspace,

        [Switch]$RemoveExistingCredentials,

        [Switch]$NoProgress

            
    )
    
    Begin {
            
        $Caller = (Get-PSCallStack)[1].Command
        $functionName = $MyInvocation.InvocationName.ToString().ToUpper()      
        "[{0}] Called from: {1}" -f $functionName, $Caller | Write-Verbose
    
        # Display the currently loaded version of the HPECOMCmdlets module
        "[{0}] Currently loaded HPECOMCmdlets module version: {1}" -f $functionName, $Global:HPECOMCmdletsModuleVersion | Write-Verbose
    
        # Get the PowerShell version
        $PSversion = $PSVersionTable.PSVersion.ToString().Split('.')[0]
    
        if ($PSVersionTable.PSVersion.Major -lt 7) {
            # If the PowerShell version is 5, display an error message and exit
            if ($PSVersion -eq 5) {
                Write-Error "This module requires PowerShell version 7 or higher. PowerShell version 5 is no longer supported. Please upgrade your PowerShell version to continue using this module."
                Break
            }
            else {
                # If the PowerShell version is less than 7, display an error message and exit
                Write-Error "This module requires PowerShell version 7 or higher. Please upgrade your PowerShell version to continue using this module."
                Break
            }
        }

        # Changing default TLS to 1.2 from 1.0
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
                       
        # Cleaning up some HPECOMCmdlets variables in the session   
            
        # Remove HPEGLworkspaces global variable if it exists
        if (Get-Variable -Scope global -Name HPEGLworkspaces -ErrorAction SilentlyContinue) {
            Remove-Variable -Name HPEGLworkspaces -Scope Global -Force
            "[{0}] Global variable `$Global:HPEGLworkspaces has been removed" -f $functionName | Write-Verbose
        }
        # Remove HPEGreenLakeSession global variable if it exists
        if (Get-Variable -Scope global -Name HPEGreenLakeSession -ErrorAction SilentlyContinue) {
            Remove-Variable -Name HPEGreenLakeSession -Scope Global -Force
            "[{0}] Global variable `$Global:HPEGreenLakeSession has been removed" -f $functionName | Write-Verbose
        }
                        
        "[{0}] About to test DNS resolution and TCP connection with all HPE GreenLake endpoints" -f $functionName, $Caller | Write-Verbose
    
        # 1 - Test DNS resolution
    
        $ccsSettingsUrl = Get-ccsSettingsUrl
        $CCServer = $ccsSettingsUrl.Authority
        
        Test-EndpointDNSResolution $CCServer
    
        # 2 - Test TCP connection: https://common.cloud.hpe.com
        
        Test-EndpointTCPConnection https://common.cloud.hpe.com
            
        # 3 - Test TCP connection: https://auth.hpe.com
    
        Test-EndpointTCPConnection https://auth.hpe.com

        # 4 - Retrieve HPE GreenLake Common Cloud Services Settings and set global variables
            
        $response = Invoke-RestMethod $ccsSettingsUrl -Method 'GET' 
        "[{0}] Response content of GET '{1}' request: `n{2}" -f $functionName, $ccsSettingsUrl, ($response | ConvertTo-Json -Depth 10) | Write-Verbose
            
        [uri]$Global:HPEGLauthorityURL = $response.authorityURL
        "[{0}] HPEGLauthorityURL variable set: '{1}'" -f $functionName, $Global:HPEGLauthorityURL | Write-Verbose
            
        New-Variable -Name HPEGLoktaURL -Scope Global -Value $response.oktaURL -Option ReadOnly -ErrorAction SilentlyContinue -Force
        "[{0}] HPEGLoktaURL variable set: '{1}'" -f $functionName, $Global:HPEGLoktaURL | Write-Verbose
    
        New-Variable -Name HPEGLclient_id -Scope Global -Value $response.client_id -Option ReadOnly -ErrorAction SilentlyContinue -Force
        "[{0}] HPEGLclient_id variable set: '{1}'" -f $functionName, $Global:HPEGLclient_id | Write-Verbose
            
        # 5 - Decrypt credential password
    
        if ($psCmdlet.ParameterSetName -eq 'Credential') {
            $Username = $Credential.UserName
            $decryptPassword = [Runtime.InteropServices.Marshal]::PtrToStringBSTR([Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password))
        }
        else {
            $Username = $SSOEmail 
            $decryptPassword = $null  # For SSO, no password; IDX will handle federation
        }
                
        # 6 - Get Compute GMT time difference in hours
    
        $GMTTimeDifferenceInHour = Get-GMTTimeDifferenceInHours
        $Global:HPEGLGMTTimeDifferenceInHour = $GMTTimeDifferenceInHour 
    
        "[{0}] Global varibale `$HPEGLGMTTimeDifferenceInHour set to store compute time difference in hours with the GMT timezone" -f $functionName | Write-Verbose
            
        # Initialize progress bar variables
        $completedSteps = 0
        $totalSteps = if ($Workspace -and -not $SSOEmail) { 9 } elseif ($SSOEmail) { 14 } else { 9 }
    
        function Update-ProgressBar {
            param (
                [int]$CompletedSteps,
                [int]$TotalSteps,
                [string]$CurrentActivity,
                [int]$Id
            )
    
            if (-not $NoProgress) {
                $percentComplete = [math]::Min(($CompletedSteps / $TotalSteps) * 100, 100)
                Write-Progress -Id $Id -Activity "Connecting to HPE GreenLake, please wait..." -Status $CurrentActivity -PercentComplete $percentComplete
            }            
        }     
        
        function Log-Cookies {
            param(
                [Parameter(Mandatory)]
                [string]$Domain,
                [Parameter(Mandatory)]
                [Microsoft.PowerShell.Commands.WebRequestSession]$Session,
                [string]$Step = ''
            )
            $functionName = $MyInvocation.InvocationName.ToString().ToUpper()
            $cookies = $Session.Cookies.GetCookies($Domain)
            if ($Step) {
                "[{0}] Cookies {1} ({2}):" -f $functionName, $Step, $Domain | Write-Verbose
            }
            else {
                "[{0}] Cookies {1}:" -f $functionName, $Domain | Write-Verbose
            }
            if ($cookies.Count -eq 0) {
                "[{0}]   (none)" -f $functionName | Write-Verbose
            }
            else {
                foreach ($cookie in $cookies) {
                    "[{0}]   {1} = {2} (Domain: {3}, Path: {4}, Secure: {5}, HttpOnly: {6})" -f $functionName, $cookie.Name, $cookie.Value, $cookie.Domain, $cookie.Path, $cookie.Secure, $cookie.HttpOnly | Write-Verbose
                }
            }
        }

        function Redact-StateHandle {
            <#
    .SYNOPSIS
        Redacts 'stateHandle' values (direct or nested) and 'stateToken' in URLs within a JSON-derived object.

    .DESCRIPTION
        Finds the first 'stateHandle' (as direct string prop or nested {name: 'stateHandle', value: 'token'}), 
        redacts all exact matches, plus any stateToken query params in href URLs.

    .PARAMETER InputObject
        The input object (e.g., from ConvertFrom-Json).

    .EXAMPLE
        $json = Get-Content 'auth-response.json' | ConvertFrom-Json
        $redacted = Redact-StateHandle -InputObject $json
        $redacted | ConvertTo-Json -Depth 10
    #>
            [CmdletBinding()]
            param(
                [Parameter(Mandatory = $true, ValueFromPipeline = $true)]
                [object]$InputObject
            )

            process {
                $functionName = $MyInvocation.MyCommand.Name.ToUpper()

                # Recursive function to find the first stateHandle value (direct or nested)
                function Find-StateHandleValue {
                    param([object]$Obj)
                    if ($Obj -is [PSCustomObject]) {
                        # Check for direct 'stateHandle' string property
                        if ($Obj.PSObject.Properties.Name -contains 'stateHandle' -and $Obj.stateHandle -is [string]) {
                            return $Obj.stateHandle
                        }
                        # Check for nested {name: 'stateHandle', value: 'token'}
                        if ($Obj.name -eq 'stateHandle' -and $Obj.value -and $Obj.value -is [string]) {
                            return $Obj.value
                        }
                        # Recurse into properties
                        foreach ($prop in $Obj.PSObject.Properties) {
                            $result = Find-StateHandleValue -Obj $prop.Value
                            if ($result) { return $result }
                        }
                    }
                    elseif ($Obj -is [array]) {
                        foreach ($item in $Obj) {
                            $result = Find-StateHandleValue -Obj $item
                            if ($result) { return $result }
                        }
                    }
                    return $null
                }

                $stateHandleValue = Find-StateHandleValue -Obj $InputObject
                $hasStateHandle = -not [string]::IsNullOrWhiteSpace($stateHandleValue)

                if (-not $hasStateHandle) {
                    "[{0}] No 'stateHandle' property (direct or nested with 'value') found in InputObject." -f $functionName | Write-Verbose
                }

                # Convert to JSON string
                $jsonString = $InputObject | ConvertTo-Json -Depth 50 -Compress

                # Redact stateHandle if found
                if ($hasStateHandle) {
                    $escapedValue = [regex]::Escape($stateHandleValue)
                    $jsonString = $jsonString -replace "`"($escapedValue)`"", '"[REDACTED]"'
                }

                # Redact stateToken in href URLs using script block for safe replacement
                $jsonString = $jsonString -replace '(?s)"href"\s*:\s*"([^"]*)"', {
                    $fullMatch = $_.Value
                    $url = $_.Groups[1].Value  # Captured URL inside quotes
                    $newUrl = $url -replace 'stateToken=([^&"]*)', 'stateToken=[REDACTED]'  # Redact param inside URL
                    $fullMatch -replace [regex]::Escape($url), $newUrl  # Rebuild with new URL
                }

                # Convert back to object
                $redactedObject = $jsonString | ConvertFrom-Json

                return $redactedObject
            }
        }
  
    }
    
    Process { 
    
        "[{0}] Bound PS Parameters: {1}" -f $functionName, ($PSBoundParameters | out-string) | Write-Verbose
    
        $global:session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

        $step = 1

        ##############################################################################################################################################################################################
        
        # Handle non-hpe.com SSO Email cases (not supported)
        if ($PSBoundParameters.ContainsKey('SSOEmail') -and $SSOEmail -notmatch 'hpe.com$') {

            # Return message that SSO is not supported with non HPE email Account
            $ErrorMessage = "Single Sign-On (SSO) is currently only supported for HPE corporate email accounts (ending with '@hpe.com'). Please use an HPE email address or connect with standard credentials."
            throw $ErrorMessage

            #-----------------------------------------------------------Authentication to HPE GreenLake Common Cloud Services----------------------------------------------------------------------------- 
            
            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            #Region [STEP 1] Generate PKCE code verifier, state and code challenge
            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
    
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName, $href | Write-Verbose
            "[{0}] [STEP 1] Generating PKCE code verifier and code challenge" -f $functionName | Write-Verbose
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName, $href | Write-Verbose
    
            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Generating PKCE codes" -Id 0
            $step++
            
            $pkceTemplate = [pscustomobject][ordered]@{  
                code_verifier  = $null  
                code_challenge = $null   
            }  
        
            $codeVerifier = -join (((48..57) * 4) + ((65..90) * 4) + ((97..122) * 4) | Get-Random -Count 128 | ForEach-Object { [char]$_ })
        
            $hashAlgo = [System.Security.Cryptography.HashAlgorithm]::Create('sha256')
            $hash = $hashAlgo.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($codeVerifier))
            $b64Hash = [System.Convert]::ToBase64String($hash)
            $code_challenge = $b64Hash.Substring(0, 43)
            
            $code_challenge = $code_challenge.Replace("/", "_")
            $code_challenge = $code_challenge.Replace("+", "-")
            $code_challenge = $code_challenge.Replace("=", "")
        
            $pkceChallenges = $pkceTemplate.PsObject.Copy()
            $pkceChallenges.code_challenge = $code_challenge
            $pkceChallenges.code_verifier = $codeVerifier 
        
            $codeChallenge = $pkceChallenges.code_challenge
            $codeVerifier = $pkceChallenges.code_verifier
        
            "[{0}] Generated code verifier: '{1}'" -f $functionName, $codeVerifier | Write-Verbose
            "[{0}] Generated code challenge: '{1}'" -f $functionName, $codeChallenge | write-Verbose
        
            # 	state=3515d3c342a74b3f99dcb9de9926c660
            # Generate a random state value (32 hex characters)
            $state = -join ((48..57) + (97..102) | Get-Random -Count 32 | ForEach-Object { [char]$_ })
            "[{0}] Generated state: '{1}'" -f $functionName, $state | Write-Verbose

            $completedSteps++
        
            #EndRegion

            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            #Region [STEP 2] Initial OAuth request and save first redirection to https://aquila-org-api.common.cloud.hpe.com/authorization/v2/oauth2/default/authorize?
            #
            # client_id=aquila-user-auth
            # &
            # redirect_uri=https://common.cloud.hpe.com/authentication/callback
            # &
            # response_type=code
            # &
            # scope=openid profile email
            # &
            # state=3515d3c342a74b3f99dcb9de9926c660
            # &
            # code_challenge=GkW43wqEGGAm7BhqGu0na3aK7eDg4duj4maqr8PsM2Q
            # &
            # code_challenge_method=S256
            # &
            # response_mode=query
            # &
            # new_login=true
            # &
            # origin=common.cloud.hpe.com  
            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName, $href | Write-Verbose
            "[{0}] [STEP 2] Initial OAuth request and save first redirection." -f $functionName | Write-Verbose
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName, $href | Write-Verbose

            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Initiating OAuth authorization request" -Id 0
            $step++

            $headers = @{}
            $headers["Content-Type"] = "application/json"
        
            $ccsRedirecturi = 'https://common.cloud.hpe.com/authentication/callback'

            # $url = "{0}?client_id={1}&redirect_uri={2}&response_type=code&scope=openid%20profile%20email&code_challenge={3}&code_challenge_method=S256" -f $authEndpoint, $Global:HPEGLclient_id, $encodedRedirectUri, $codeChallenge
                
            $queryParams = @{
                client_id             = $Global:HPEGLclient_id
                redirect_uri          = $ccsRedirecturi
                response_type         = "code"
                response_mode         = "query"
                scope                 = "openid profile email"
                code_challenge        = $codeChallenge
                state                 = $state
                code_challenge_method = "S256"
                new_login             = $true
                origin                = "common.cloud.hpe.com"
            }
                
            # Build the query string
            $queryString = ($queryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "&"
        
            # Combine the base URL with the query string
            $url = "$(Get-HPEGLAPIOrgbaseURL)/authorization/v2/oauth2/default/authorize?$($queryString)"
            "[{0}] About to execute GET request to: {1}" -f $functionName, $url | Write-Verbose
            "[{0}] Using the query parameters: {1}" -f $functionName, ($queryParams | Out-String) | Write-Verbose
            
            try {

                $responseStep2 = Invoke-WebRequest $url -Method Get -MaximumRedirection 0 -ErrorAction SilentlyContinue -ErrorVariable redirected1 -WebSession $Session

                "[{0}] Received status code response: '{1}' - Description: '{2}'" -f $functionName, $responseStep2.StatusCode, $responseStep2.StatusDescription | Write-verbose
                "[{0}] Raw response for `$responseStep2: `n{1}" -f $functionName, $responseStep2 | Write-verbose

                if ($responseStep2.StatusCode -ne 302) {                
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    Throw "An error occurred during the connection to HPE GreenLake. Please check your network connection and try again."
                }
                else {
                    "[{0}] Redirection detected. Proceeding with the next step..." -f $functionName | Write-Verbose
                }
            }
            # Not using catch as entering the catch block when encountering a 302 (false error as we have a redirection)
            catch {
                #     Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                #     $PSCmdlet.ThrowTerminatingError($_)
            }
        
            if ($redirected1.ErrorRecord.Exception.Response.StatusCode.value__ -eq 302) {
                $redirecturl1 = $redirected1.ErrorRecord.Exception.Response.Headers.Location.AbsoluteUri
            }

            "[{0}] First redirection URL captured: '{1}'" -f $functionName, $redirecturl1 | Write-Verbose
            $completedSteps++

            
            #EndRegion

            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            #Region [STEP 3] Follow first redirection and save second one: GET request to 'https://sso.common.cloud.hpe.com/as/authorization.oauth2?code_challenge=XXXXXXX&origin=common.cloud.hpe.com&response_type=code&client_id=aquila-user-auth&new_login=True&scope=openid%20profile%20email&code_challenge_method=S256&redirect_uri=https://common.cloud.hpe.com/authentication/callback&response_mode=query'
            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
    
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName, $href | Write-Verbose
            "[{0}] [STEP 3] Follow first redirection and save second one" -f $functionName | Write-Verbose
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName, $href | Write-Verbose

            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Follow first redirection" -Id 0
            $step++

            "[{0}] Step 3 - Follow redirection: '{1}'" -f $functionName, $redirecturl1 | Write-Verbose

            try {

                $responseStep3 = Invoke-WebRequest $redirecturl1 -Method Get -MaximumRedirection 0 -ErrorAction SilentlyContinue -ErrorVariable redirected2 -WebSession $Session

                "[{0}] Received status code response: '{1}' - Description: '{2}'" -f $functionName, $responseStep3.StatusCode, $responseStep3.StatusDescription | Write-verbose
                "[{0}] Raw response for `$responseStep3: `n{1}" -f $functionName, $responseStep3 | Write-verbose

                if ($responseStep3.StatusCode -ne 302) {
                                                
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }

                    Throw "An error occurred during the connection to HPE GreenLake. Please check your network connection and try again."
                }
                else {
                    "[{0}] Redirection detected. Proceeding with the next step..." -f $functionName | Write-Verbose
                }
            }
            # Not using catch as entering the catch block when encountering a 302 (false error as we have a redirection)
            catch {
                #     Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                #     $PSCmdlet.ThrowTerminatingError($_)
            }
        
            if ($redirected2.ErrorRecord.Exception.Response.StatusCode.value__ -eq 302) {
                $redirecturl2 = $redirected2.ErrorRecord.Exception.Response.Headers.Location.AbsoluteUri
            }
        
            "[{0}] Second redirection URL captured: '{1}'" -f $functionName, $redirecturl2 | Write-Verbose
        
            # redirected url: 'https://aquila-org-api.common.cloud.hpe.com/internal-identity/v1alpha1/sso-authorize?scope=openid+profile+email+ccsidp&origin=common.cloud.hpe.com&response_type=code&redirect_uri=https%3A%2F%2Fsso.common.cloud.hpe.com%2Fsp%2FeyJpc3MiOiJodHRwczpcL1wvYXV0aC5ocGUuY29tXC9vYXV0aDJcL2FxdWlsYSJ9%2Fcb.openid&state=X0Du3haximeFPCiAyAdFPQSjKxmMR1&nonce=ECiFAjqbUWPsPmxhFOhGz5&client_id=0oae329tm8xw7nwZE357'
            
            # Extract the redirect_uri parameter value from $redirecturl2
            $redirectUriEncoded = ($redirecturl2 -split '[?&]') | Where-Object { $_ -like 'redirect_uri=*' } | ForEach-Object { $_ -replace '^redirect_uri=', '' }
            $redirectUri = [System.Web.HttpUtility]::UrlDecode($redirectUriEncoded)
            "[{0}] Extracted redirect_uri: '{1}'" -f $functionName, $redirectUri | Write-Verbose
            
            $completedSteps++
            
            #EndRegion

            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            #Region [STEP 4] Follow second redirection and save third one: GET request to 'https://sso.common.cloud.hpe.com/as/authorization.oauth2?code_challenge=XXXXXXX&origin=common.cloud.hpe.com&response_type=code&client_id=aquila-user-auth&new_login=True&scope=openid%20profile%20email&code_challenge_method=S256&redirect_uri=https://common.cloud.hpe.com/authentication/callback&response_mode=query'
            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
    
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName, $href | Write-Verbose
            "[{0}] [STEP 4] Follow second redirection and save third one" -f $functionName | Write-Verbose
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName, $href | Write-Verbose

            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Follow second redirection" -Id 0
            $step++

            "[{0}] Step 4 - Follow redirection: '{1}'" -f $functionName, $redirecturl2 | Write-Verbose

            try {

                $responseStep4 = Invoke-WebRequest $redirecturl2 -Method Get -MaximumRedirection 0 -ErrorAction SilentlyContinue -ErrorVariable redirected3 -WebSession $Session

                "[{0}] Received status code response: '{1}' - Description: '{2}'" -f $functionName, $responseStep4.StatusCode, $responseStep4.StatusDescription | Write-verbose
                "[{0}] Raw response for `$responseStep4: `n{1}" -f $functionName, $responseStep4 | Write-verbose

                if ($responseStep4.StatusCode -ne 302) {
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    Throw "An error occurred during the connection to HPE GreenLake. Please check your network connection and try again."
                }
                else {
                    "[{0}] Redirection detected. Proceeding with the next step..." -f $functionName | Write-Verbose
                }
            }
            # Not using catch as entering the catch block when encountering a 302 (false error as we have a redirection)
            catch {
                #     Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                #     $PSCmdlet.ThrowTerminatingError($_)
            }
        
            if ($redirected3.ErrorRecord.Exception.Response.StatusCode.value__ -eq 302) {
                $redirecturl3 = $redirected3.ErrorRecord.Exception.Response.Headers.Location.AbsoluteUri
            }

            "[{0}] Third redirection URL captured: '{1}'" -f $functionName, $redirecturl3 | Write-Verbose

            # redirected url: https://auth.hpe.com/oauth2/aus43pf0g8mvh4ntv357/v1/authorize?client_id=XXXXXXX&code_challenge=XXXXXX&code_challenge_method=S256&prompt=none&redirect_uri=https%3A%2F%2Faquila-org-api.common.cloud.hpe.com%2Finternal-identity%2Fv1alpha1%2Fsso-callback&response_mode=query&response_type=code&scope=openid+email&state=XXXXXXXX

            # Extract the ID (e.g., aus43pf0g8mvh4ntv357) from the redirected URL
            # $idMatch = [regex]::Match($redirecturl3, '/oauth2/([^/]+)/v1/authorize')
            # if ($idMatch.Success) {
            #     $authId = $idMatch.Groups[1].Value
            #     "[{0}] Extracted auth ID: '{1}'" -f $functionName, $authId | Write-Verbose
            # } else {
            #     "[{0}] Could not extract auth ID from URL: '{1}'" -f $functionName, $redirecturl3 | Write-Verbose
            #     Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
            #     Throw "An error occurred during the connection to HPE GreenLake. Please check your network connection and try again."
            # }

            # Extract https://auth.hpe.com/oauth2/aus43pf0g8mvh4ntv357/v1/authorize from the redirected URL
            # Extract the base authorize URL (without query parameters) from $redirecturl3
            $authorizeBaseUrl = $redirecturl3 -replace '(\?.*)$', ''
            "[{0}] Extracted authorize base URL: '{1}'" -f $functionName, $authorizeBaseUrl | Write-Verbose

            $completedSteps++
            
            #EndRegion

            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            #Region [STEP 5] Follow third redirection and save the fourth one: GET request to 'https://auth.hpe.com/oauth2/aus43pf0g8mvh4ntv357/v1/authorize?client_id=XXXXXXX&code_challenge=XXXXXX&code_challenge_method=S256&prompt=none&redirect_uri=https%3A%2F%2Faquila-org-api.common.cloud.hpe.com%2Finternal-identity%2Fv1alpha1%2Fsso-callback&response_mode=query&response_type=code&scope=openid+email&state=XXXXXXXX'
            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
    
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName, $href | Write-Verbose
            "[{0}] [STEP 5] Follow third redirection and save the fourth one" -f $functionName | Write-Verbose
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName, $href | Write-Verbose

            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Follow third redirection" -Id 0
            $step++

            "[{0}] Step 5 - Follow redirection: '{1}'" -f $functionName, $redirecturl3 | Write-Verbose

            try {

                $responseStep5 = Invoke-WebRequest $redirecturl3 -Method Get -MaximumRedirection 0 -ErrorAction SilentlyContinue -ErrorVariable redirected4 -WebSession $Session

                "[{0}] Received status code response: '{1}' - Description: '{2}'" -f $functionName, $responseStep5.StatusCode, $responseStep5.StatusDescription | Write-verbose
                "[{0}] Raw response for `$responseStep5: `n{1}" -f $functionName, $responseStep5 | Write-verbose

                if ($responseStep5.StatusCode -ne 302) {
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    Throw "An error occurred during the connection to HPE GreenLake. Please check your network connection and try again."
                }
                else {
                    "[{0}] Redirection detected. Proceeding with the next step..." -f $functionName | Write-Verbose
                }
            }
            # Not using catch as entering the catch block when encountering a 302 (false error as we have a redirection)
            catch {
                #     Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                #     $PSCmdlet.ThrowTerminatingError($_)
            }
        
            if ($redirected4.ErrorRecord.Exception.Response.StatusCode.value__ -eq 302) {
                $redirecturl4 = $redirected4.ErrorRecord.Exception.Response.Headers.Location.AbsoluteUri
            }

            "[{0}] Fourth redirection URL captured: '{1}'" -f $functionName, $redirecturl4 | Write-Verbose

            #redirected url: https://aquila-org-api.common.cloud.hpe.com/internal-identity/v1alpha1/sso-callback?state=XXXXXX&error=login_required&error_description=The+client+specified+not+to+prompt%2C+but+the+user+is+not+logged+in.'                                 

            $completedSteps++

            #EndRegion

            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            #Region [STEP 6] Follow 4th redirection and save the fifth one: GET request to 'https://aquila-org-api.common.cloud.hpe.com/internal-identity/v1alpha1/sso-callback?state=XXXXXX&error=login_required&error_description=The+client+specified+not+to+prompt%2C+but+the+user+is+not+logged+in.'
            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
    
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName, $href | Write-Verbose
            "[{0}] [STEP 6] Follow fourth redirection and save the fifth one" -f $functionName | Write-Verbose
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName, $href | Write-Verbose

            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Follow fourth redirection" -Id 0
            $step++

            "[{0}] Step 6 - Follow redirection: '{1}'" -f $functionName, $redirecturl4 | Write-Verbose

            try {

                $responseStep6 = Invoke-WebRequest $redirecturl4 -Method Get -MaximumRedirection 0 -ErrorAction SilentlyContinue -ErrorVariable redirected5 -WebSession $Session

                "[{0}] Received status code response: '{1}' - Description: '{2}'" -f $functionName, $responseStep6.StatusCode, $responseStep6.StatusDescription | Write-verbose
                "[{0}] Raw response for `$responseStep6: `n{1}" -f $functionName, $responseStep6 | Write-verbose

                if ($responseStep6.StatusCode -ne 302) {
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    Throw "An error occurred during the connection to HPE GreenLake. Please check your network connection and try again."
                }
                else {
                    "[{0}] Redirection detected. Proceeding with the next step..." -f $functionName | Write-Verbose
                }
            }
            # Not using catch as entering the catch block when encountering a 302 (false error as we have a redirection)
            catch {
                #     Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                #     $PSCmdlet.ThrowTerminatingError($_)
            }
        
            if ($redirected5.ErrorRecord.Exception.Response.StatusCode.value__ -eq 302) {
                $redirecturl5 = $redirected5.ErrorRecord.Exception.Response.Headers.Location.AbsoluteUri
            }

            "[{0}] Fifth redirection URL captured: '{1}'" -f $functionName, $redirecturl5 | Write-Verbose

            # redirected url: https://common.cloud.hpe.com/sso/continue?state=XXXXX

            # Extract the state parameter value from $redirecturl5
            $Answeredstate = ($redirecturl5 -split '[?&]') | Where-Object { $_ -like 'state=*' } | ForEach-Object { $_ -replace '^state=', '' } 
            "[{0}] Extracted state from fifth redirection: '{1}'" -f $functionName, $Answeredstate | Write-Verbose

            $completedSteps++

            #EndRegion                    

            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            #Region [STEP 7] Resolve SSO with login_hint: GET request to 'https://aquila-org-api.common.cloud.hpe.com/internal-identity/v1alpha1/sso-resolve?login_hint=XXXXXXXXXXXXXXXXX&state=XXXXXXXXXXXX'
            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
    
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName, $href | Write-Verbose
            "[{0}] [STEP 7] Resolve SSO" -f $functionName | Write-Verbose
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName, $href | Write-Verbose

            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Resolve SSO with login_hint" -Id 0
            $step++

            # Build URL
            $ssoResolveUrl = "$(Get-HPEGLAPIOrgbaseURL)/internal-identity/v1alpha1/sso-resolve?login_hint=$($Username)&state=$($Answeredstate)"

            "[{0}] Step 7 - Resolve SSO: '{1}'" -f $functionName, $ssoResolveUrl | Write-Verbose

            try {

                $responseStep7 = Invoke-WebRequest $ssoResolveUrl -Method Get -MaximumRedirection 0 -ErrorAction SilentlyContinue -ErrorVariable redirected6 -WebSession $Session

                "[{0}] Received status code response: '{1}' - Description: '{2}'" -f $functionName, $responseStep7.StatusCode, $responseStep7.StatusDescription | Write-verbose
                "[{0}] Raw response for `$responseStep7: `n{1}" -f $functionName, $responseStep7 | Write-verbose

                if ($responseStep7.StatusCode -ne 302) {
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    Throw "An error occurred during the connection to HPE GreenLake. Please check your network connection and try again."
                }
                else {
                    "[{0}] Redirection detected. Proceeding with the next step..." -f $functionName | Write-Verbose
                }
            }
            # Not using catch as entering the catch block when encountering a 302 (false error as we have a redirection)
            catch {
                #     Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                #     $PSCmdlet.ThrowTerminatingError($_)
            }
        
            if ($redirected6.ErrorRecord.Exception.Response.StatusCode.value__ -eq 302) {
                $redirecturl6 = $redirected6.ErrorRecord.Exception.Response.Headers.Location.AbsoluteUri
            }

            "[{0}] Sixth redirection URL captured: '{1}'" -f $functionName, $redirecturl6 | Write-Verbose

            # redirected url: https://common.cloud.hpe.com/sso/selector?auth_source=hpe_myaccount&login_hint=XXXXXXXXXX&myaccount_session=true&redirect=XXXXXXXXXXXX

            # Extract the redirect parameter value from $redirecturl6
            $Redirect = ($redirecturl6 -split '[?&]') | Where-Object { $_ -like 'redirect=*' } | ForEach-Object { $_ -replace '^redirect=', '' } 
            "[{0}] Extracted redirect from sixth redirection: '{1}'" -f $functionName, $Redirect | Write-Verbose

            # The redirect parameter is base64-encoded. Decoding it:
            $decodedRedirect = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String([System.Web.HttpUtility]::UrlDecode($Redirect)))
            "[{0}] Decoded redirect parameter: '{1}'" -f $functionName, $decodedRedirect | Write-Verbose

            # Extract the display from the decoded redirect
            $display = ($decodedRedirect -split '[?&]') | Where-Object { $_ -like 'display=*' } | ForEach-Object { $_ -replace '^display=', '' }
            "[{0}] Extracted display from decoded redirect: '{1}'" -f $functionName, [System.Web.HttpUtility]::UrlDecode($display) | Write-Verbose

            # Extract the idp from the decoded redirect
            $idp = ($decodedRedirect -split '[?&]') | Where-Object { $_ -like 'idp=*' } | ForEach-Object { $_ -replace '^idp=', '' }
            "[{0}] Extracted idp from decoded redirect: '{1}'" -f $functionName, $idp | Write-Verbose

            # Extract the client_id from the decoded redirect
            $clientId = ($decodedRedirect -split '[?&]') | Where-Object { $_ -like 'client_id=*' } | ForEach-Object { $_ -replace '^client_id=', '' }
            "[{0}] Extracted client_id from decoded redirect: '{1}'" -f $functionName, $clientId | Write-Verbose

            # Extract the nonce from the decoded redirect
            $nonce = ($decodedRedirect -split '[?&]') | Where-Object { $_ -like 'nonce=*' } | ForEach-Object { $_ -replace '^nonce=', '' }
            "[{0}] Extracted nonce from decoded redirect: '{1}'" -f $functionName, $nonce | Write-Verbose

            # Extract the redirect_uri from the decoded redirect
            $ccsRedirecturi = ($decodedRedirect -split '[?&]') | Where-Object { $_ -like 'redirect_uri=*' } | ForEach-Object { $_ -replace '^redirect_uri=', '' }
            $ccsRedirecturi = [System.Web.HttpUtility]::UrlDecode($ccsRedirecturi)
            "[{0}] Extracted redirect_uri from decoded redirect: '{1}'" -f $functionName, $ccsRedirecturi | Write-Verbose

            $completedSteps++

            #EndRegion

            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            #Region [STEP 8] OAuth Authorize with idp to 'https://auth.hpe.com/oauth2/xxxxxxxxxxxxxxxxxxx/v1/authorize?
            # client_id=xxxxxxxxxxxxxx&
            # display=https://sts.windows.net/037db3fc-7e83-48ba-8f4e-04d42b37bc28/&
            # idp=xxxxxxxxxxxxxxxxx&
            # login_hint=jullienl@4lldxf.onmicrosoft.com&
            # nonce=xxxxxxxxxxxxxxxxxxx&
            # prompt=login&
            # redirect_uri=https://sso.common.cloud.hpe.com/sp/xxxxxxxxxxxxxxxxxx/cb.openid&
            # response_type=code&
            # scope=openid profile email ccsidp&
            # sso_options=false&
            # state=xxxxxxxxxxxxxxxxx'
            # ---------------------------------------------------------------------------------------------------------------------------------------------------------

            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName, $href | Write-Verbose
            "[{0}] [STEP 8] OAuth Authorize with idp" -f $functionName | Write-Verbose
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName, $href | Write-Verbose

            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - OAuth Authorize with idp" -Id 0
            $step++

            $queryParams = @{
                client_id     = $clientId
                # display               = "https://sts.windows.net/037db3fc-7e83-48ba-8f4e-04d42b37bc28/"
                idp           = $idp
                login_hint    = $Username
                nonce         = $nonce
                # prompt                = "login" 
                redirect_uri  = $ccsRedirecturi
                response_type = "code"
                scope         = "openid profile email ccsidp"
                sso_options   = "true"
                state         = $Answeredstate

            }
                
            # Build the query string
            $queryString = ($queryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) -join "&"
        
            # Combine the base URL with the query string
            $url = "$($authorizeBaseUrl)?$($queryString)"

            "[{0}] About to execute GET request to: {1}" -f $functionName, $url | Write-Verbose
            "[{0}] Using the query parameters: {1}" -f $functionName, ($queryParams | Out-String) | Write-Verbose
            
            try {

                $responseStep8 = Invoke-WebRequest $url -Method Get -MaximumRedirection 0 -ErrorAction SilentlyContinue -ErrorVariable redirected7 -WebSession $Session

                "[{0}] Received status code response: '{1}' - Description: '{2}'" -f $functionName, $responseStep8.StatusCode, $responseStep8.StatusDescription | Write-verbose
                "[{0}] Raw response for `$responseStep8: `n{1}" -f $functionName, $responseStep8 | Write-verbose

                if ($responseStep8.StatusCode -ne 302) {
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    Throw "An error occurred during the connection to HPE GreenLake. Please check your network connection and try again."
                }
                else {
                    "[{0}] Redirection detected. Proceeding with the next step..." -f $functionName | Write-Verbose
                }
            }
            # Not using catch as entering the catch block when encountering a 302 (false error as we have a redirection)
            catch {
                #     Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                #     $PSCmdlet.ThrowTerminatingError($_)
            }

            if ($redirected7.ErrorRecord.Exception.Response.StatusCode.value__ -eq 302) {
                $redirecturl7 = $redirected7.ErrorRecord.Exception.Response.Headers.Location.AbsoluteUri
            }

            "[{0}] Seventh redirection URL captured: '{1}'" -f $functionName, $redirecturl7 | Write-Verbose

            $completedSteps++

            #EndRegion

            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            #Region [STEP 9] Follow redirection to capture OktaData to 'https://sso.common.cloud.hpe.com/as/authorization.oauth2?
            # state=MmtyQzAyb0drdmVJMVdrMlgwT2lPK0R1SE5QWWU1R2hwd05pV1NNcXJubXhEemxyb3RaMCtGdXdteVE4emtOVg&
            # nonce=eU8Bf9Ff2CikdlfJtNMG1tlzwsb78dMh&
            # code_challenge=9wE8d45To4gRLSPJhPchT0RnAx_vbaC9hXox59Jwh4I&
            # code_challenge_method=S256&
            # client_id=prod-auth-glp-federation&
            # redirect_uri=https://auth.hpe.com/oauth2/v1/authorize/callback&
            # response_type=code&
            # display=https://sts.windows.net/037db3fc-7e83-48ba-8f4e-04d42b37bc28/&
            # login_hint=jullienl@4lldxf.onmicrosoft.com&
            # scope=email openid profile
            # ---------------------------------------------------------------------------------------------------------------------------------------------------------

            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName, $href | Write-Verbose
            "[{0}] [STEP 9] Follow redirection: '{1}'" -f $functionName, $redirecturl7 | Write-Verbose
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName, $href | Write-Verbose

            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Follow redirection" -Id 0
            $step++

            try {

                $responseStep9 = Invoke-WebRequest $redirecturl7 -Method Get -ErrorAction SilentlyContinue -WebSession $Session

                "[{0}] Received status code response: '{1}' - Description: '{2}'" -f $functionName, $responseStep9.StatusCode, $responseStep9.StatusDescription | Write-verbose
                # Display only the last 30 lines of the response content for debugging
                $lastLines = ($responseStep9.Content -split "`r?`n") | Select-Object -Last 30
                "[{0}] Raw response for `$responseStep9 (last 30 lines):`n{1}" -f $functionName, ($lastLines -join "`n") | Write-Verbose
                
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                $PSCmdlet.ThrowTerminatingError($_)
            }
        

            # Capture OKTAData from the response and retrieve the fromUri value
            $oktaData = ($responseStep9.Content -join "`n" | Select-String -Pattern 'var OKTAData = ({.*?});' -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value }
            "[{0}] Extracted OKTAData: '{1}'" -f $functionName, $oktaData | Write-Verbose
            if (-not $oktaData) {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                Throw "An error occurred during the connection to HPE GreenLake. Unable to retrieve the required OKTAData value from the response. Please check your network connection and try again, or contact your administrator if the issue persists."
            }

            # Use regex to extract the fromUri value from OKTAData
            $fromUri = ($oktaData -join "`n" | Select-String -Pattern '"fromUri":"([^"]+)"' -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value }
            # Replace hex escape sequences with their actual characters
            $decodedFromUri = $fromUri -replace '\\x2F', '/' -replace '\\x3F', '?' -replace '\\x3D', '='
            "[{0}] Extracted fromUri: '{1}'" -f $functionName, $decodedFromUri | Write-Verbose
            if (-not $decodedFromUri) {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                Throw "An error occurred during the connection to HPE GreenLake. Unable to retrieve the required fromUri value from the response. Please check your network connection and try again, or contact your administrator if the issue persists."
            }

            # Use regex to extract the id value from glcpIDPprod 
            $glcpIDPprodId = ($responseStep9.Content -join "`n" | Select-String -Pattern "var glcpIDPprod = \{[^}]*id: '([^']+)'" -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value }
            "[{0}] Extracted glcpIDPprod id: '{1}'" -f $functionName, $glcpIDPprodId | Write-Verbose
            if (-not $glcpIDPprodId) {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                Throw "An error occurred during the connection to HPE GreenLake. Unable to retrieve the required glcpIDPprod id value from the response. Please check your network connection and try again, or contact your administrator if the issue persists."
            }

            $completedSteps++

            #EndRegion  
            
            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            #Region [STEP 10] Initiate Authentication via HPE Okta SSO Endpoint
            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName | Write-Verbose
            "[{0}] [STEP 10] Initiate Authentication via HPE Okta SSO Endpoint" -f $functionName | Write-Verbose
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName | Write-Verbose

            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Initiate Authentication via HPE Okta SSO Endpoint" -Id 0
            $step++

            # Load System.Web for decoding
            Add-Type -AssemblyName System.Web

            # # Validate inputs
            # if (-not $glcpIDPprodId) { Throw "[{0}] glcpIDPprodId is null or empty." -f $functionName }
            # if (-not $decodedFromUri) { Throw "[{0}] decodedFromUri is null or empty." -f $functionName }

            # URL-encode the decoded string
            $encodedFromUri = [System.Net.WebUtility]::UrlEncode($decodedFromUri)

            # Construct the full URL
            $baseUrl = "https://auth.hpe.com/sso/idps/" + $glcpIDPprodId
            $fullUrl = $baseUrl + "?fromURI=" + $encodedFromUri

            $method = "GET"

            "[{0}] About to execute {1} request to: '{2}'" -f $functionName, $method, $fullUrl | Write-Verbose

            # Initialize session if null
            if (-not $session) {
                "[{0}] WebSession is null. Initializing new session." -f $functionName | Write-Verbose
                $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
            }

            # Log initial cookies
            "[{0}] Initial session cookies for {1}: {2}" -f $functionName, $fullUrl, ($session.Cookies.GetCookies($fullUrl) | Out-String) | Write-Verbose

            try {
                $responseStep10 = Invoke-WebRequest -Uri $fullUrl -Method $method -ErrorAction Stop -WebSession $session
                # $responseStep10.Content | Out-File -FilePath "step10_response.html" -Encoding UTF8
                "[{0}] SAML2 IDP response received successfully." -f $functionName | Write-Verbose
                "[{0}] Received status code: '{1}' - Description: '{2}'" -f $functionName, $responseStep10.StatusCode, $responseStep10.StatusDescription | Write-Verbose
                $lastLines = ($responseStep10.Content -split "`r?`n") | Select-Object -Last 30
                "[{0}] Raw response for `$responseStep10 (last 30 lines):`n{1}" -f $functionName, ($lastLines -join "`n") | Write-Verbose
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                "[{0}] SAML2 IDP response failed to process: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                "[{0}] Exception details: {1}" -f $functionName, ($_.Exception | Out-String) | Write-Verbose
                Throw "Failed to fetch initial SAML response from $fullUrl."
            }

            # Add cookies to session
            if ($responseStep10.Headers['Set-Cookie']) {
                $cookies = $responseStep10.Headers['Set-Cookie'] -split '(?<!\w);(?!\w)'
                foreach ($cookie in $cookies) {
                    if ($cookie -match '(\w+)=([^;]*)(?:;|$)' -and $matches[2].Trim() -and $matches[2].Trim().Length -gt 0 -and $matches[2] -notmatch '^(Thu, 01 Jan 1970|deleted)$') {
                        try {
                            $cookieObj = New-Object System.Net.Cookie
                            $cookieObj.Name = $matches[1]
                            $cookieObj.Value = $matches[2].Trim()
                            $cookieObj.Domain = (New-Object System.Uri $fullUrl).Host
                            $session.Cookies.Add($cookieObj)
                            "[{0}] Added cookie: {1}={2}" -f $functionName, $cookieObj.Name, $cookieObj.Value | Write-Verbose
                        }
                        catch {
                            "[{0}] Skipped invalid cookie: {1} ({2})" -f $functionName, $cookie, $_.Exception.Message | Write-Verbose
                        }
                    }
                }
            }
            else {
                "[{0}] No cookies found in initial response" -f $functionName | Write-Verbose
            }

            # Log cookies after Step 10
            "[{0}] Session cookies after Step 10 for {1}: {2}" -f $functionName, $fullUrl, ($session.Cookies.GetCookies($fullUrl) | Out-String) | Write-Verbose

            # Extract SAMLAction, SAMLRequest, Method, and RelayState
            $SAMLActionMatch = ($responseStep10.Content -join "`n" | Select-String -Pattern '<form[^>]*id="appForm"[^>]*action="([^"]+)"').Matches | Select-Object -First 1
            $SAMLActionValue = if ($SAMLActionMatch) { [System.Web.HttpUtility]::HtmlDecode($SAMLActionMatch.Groups[1].Value) } else { $null }

            $SAMLRequestMatch = ($responseStep10.Content -join "`n" | Select-String -Pattern '<input[^>]*name="SAMLRequest"[^>]*value="([^"]+)"').Matches | Select-Object -First 1
            $SAMLRequestValue = if ($SAMLRequestMatch) { [System.Web.HttpUtility]::HtmlDecode($SAMLRequestMatch.Groups[1].Value) } else { $null }

            $RelayStateMatch = ($responseStep10.Content -join "`n" | Select-String -Pattern '<input[^>]*name="RelayState"[^>]*value="([^"]+)"').Matches | Select-Object -First 1
            $RelayStateValue = if ($RelayStateMatch) { [System.Web.HttpUtility]::HtmlDecode($RelayStateMatch.Groups[1].Value) } else { $null }

            $SAMLMethodMatch = ($responseStep10.Content -join "`n" | Select-String -Pattern 'method="([^"]+)"').Matches | Select-Object -First 1
            $SAMLMethodValue = if ($SAMLMethodMatch) { $SAMLMethodMatch.Groups[1].Value } else { "POST" }

            # Display extracted values
            "[{0}] Extracted SAMLAction: {1}" -f $functionName, $SAMLActionValue | Write-Verbose
            "[{0}] Extracted SAMLMethod: '{1}'" -f $functionName, $SAMLMethodValue | Write-Verbose
            "[{0}] Extracted SAMLRequest: {1}..." -f $functionName, ($SAMLRequestValue ? $SAMLRequestValue.Substring(0, [Math]::Min(100, $SAMLRequestValue.Length)) : "None") | Write-Verbose
            "[{0}] Extracted RelayState: {1}..." -f $functionName, ($RelayStateValue ? $RelayStateValue.Substring(0, [Math]::Min(100, $RelayStateValue.Length)) : "None") | Write-Verbose
            "[{0}] RelayState length: {1}" -f $functionName, ($RelayStateValue ? $RelayStateValue.Length : 0) | Write-Verbose
            
            if (-not $SAMLActionValue -or -not $SAMLMethodValue -or -not $SAMLRequestValue -or -not $RelayStateValue) {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                "[{0}] Missing required SAML parameters (Action, Method, SAMLRequest, or RelayState)." -f $functionName | Write-Verbose
                throw "[{0}] Missing required SAML parameters (Action, Method, SAMLRequest, or RelayState)." -f $functionName
            }
           
            # Decode base64 SAMLRequest
            try {
                $byteArray = [System.Convert]::FromBase64String($SAMLRequestValue)
                if ($byteArray.Length -gt 1 -and $byteArray[0] -eq 0x78 -and $byteArray[1] -eq 0x9C) {
                    $memoryStream = New-Object System.IO.MemoryStream(, $byteArray)
                    $deflateStream = New-Object System.IO.Compression.DeflateStream($memoryStream, [System.IO.Compression.CompressionMode]::Decompress)
                    $decompressedStream = New-Object System.IO.MemoryStream
                    $deflateStream.CopyTo($decompressedStream)
                    $decompressedBytes = $decompressedStream.ToArray()
                    $xmlString = [System.Text.Encoding]::UTF8.GetString($decompressedBytes)
                }
                else {
                    $xmlString = [System.Text.Encoding]::UTF8.GetString($byteArray)
                }
                "[{0}] Decoded SAMLRequest: {1}..." -f $functionName, ($xmlString.Substring(0, [Math]::Min(100, $xmlString.Length))) | Write-Verbose
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                Throw "Error decoding base64 SAMLRequest: $_`nRaw SAMLRequest: $SAMLRequestValue"
            }

            $completedSteps++
            #EndRegion

            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            #Region [STEP 11] Submit SAML Authentication Request
            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName | Write-Verbose
            "[{0}] [STEP 11] Submit SAML Authentication Request: '{1}'" -f $functionName, $SAMLActionValue | Write-Verbose
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName | Write-Verbose

            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Submit SAML Authentication Request" -Id 0
            $step++

            try {

                $body = @{
                    SAMLRequest = $SAMLRequestValue
                    RelayState  = $RelayStateValue
                }

                "[{0}] About to execute {1} request to: '{2}'" -f $functionName, $SAMLMethodValue, $SAMLActionValue | Write-Verbose
                "[{0}] Using the query parameters: {1}" -f $functionName, ($body | Out-String) | Write-Verbose

                $responseStep11 = Invoke-WebRequest -Method $SAMLMethodValue -Uri $SAMLActionValue -Body $body -WebSession $session -ContentType "application/x-www-form-urlencoded" -MaximumRedirection 1 -ErrorAction Stop
                # $responseStep11.Content | Out-File -FilePath "step11_response.html" -Encoding UTF8                
                "[{0}] Received status code: '{1}' - Description: '{2}'" -f $functionName, $responseStep11.StatusCode, $responseStep11.StatusDescription | Write-Verbose
                "[{0}] Content for `$responseStep11 starts with: {1}..." -f $functionName, ($responseStep11.Content.Substring(0, [Math]::Min(100, $responseStep11.Content.Length))) | Write-Verbose
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                "[{0}] Failed to submit SAML request to {1}: {2}" -f $functionName, $SAMLActionValue, $_.Exception.Message | Write-Verbose
                throw "Failed to submit SAML request to $SAMLActionValue : $_."
            }

            $completedSteps++

            #EndRegion 

            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            #Region [STEP 12] Submit Email Form
            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName | Write-Verbose
            "[{0}] [STEP 12] Submit email form" -f $functionName | Write-Verbose
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName | Write-Verbose

            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Submit email form" -Id 0
            $step++

            try {
                $newActionMatch = ($responseStep11.Content -join "`n" | Select-String -Pattern '<form[^>]*action=["'']([^"'']*)["''][^>]*id="ssoForm"').Matches | Select-Object -First 1
                $newActionValue = if ($newActionMatch -and $newActionMatch.Groups.Count -gt 1) { [System.Web.HttpUtility]::HtmlDecode($newActionMatch.Groups[1].Value) } else { $null }
                "[{0}] Extracted form action: {1}" -f $MyInvocation.InvocationName.ToString().ToString().ToUpper(), ($newActionValue ? $newActionValue : "None") | Write-Verbose

                if (-not $newActionValue) { 
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "[{0}] No action URL found in login form." -f $functionName 
                }

                $newActionUri = if ($newActionValue -match '^/') {
                    $baseUri = New-Object System.Uri $SAMLActionValue
                    [System.Uri]::new($baseUri, $newActionValue).ToString()
                }
                else {
                    $newActionValue
                }
                "[{0}] Resolved form action: {1}" -f $functionName, $newActionUri | Write-Verbose

                $newBody = @{
                    subject                           = $Username
                    'clear.previous.selected.subject' = ''
                    'cancel.identifier.selection'     = 'false'
                }
                "[{0}] Email form body: {1}" -f $functionName, ($newBody | Out-String) | Write-Verbose

                $responseStep12 = Invoke-WebRequest -Method POST -Uri $newActionUri -Body $newBody -WebSession $session -ContentType "application/x-www-form-urlencoded" -MaximumRedirection 1 -ErrorAction Stop
                # $responseStep12.Content | Out-File -FilePath "step12_response.html" -Encoding UTF8                
                "[{0}] Received status code: '{1}' - Description: '{2}'" -f $functionName, $responseStep12.StatusCode, $responseStep12.StatusDescription | Write-Verbose
                "[{0}] Content for `$responseStep12 starts with: {1}..." -f $functionName, ($responseStep12.Content.Substring(0, [Math]::Min(100, $responseStep12.Content.Length))) | Write-Verbose
                
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                "[{0}] Failed to submit email form to {1}: {2}" -f $functionName, $newActionUri, $_.Exception.Message | Write-Verbose
                throw "Failed to submit email form to $newActionUri : $_."
            }

            $autoPostFormMatch = ($responseStep12.Content -join "`n" | Select-String -Pattern '<form[^>]*action=["'']([^"'']*)["''][^>]*>').Matches | Select-Object -First 1
            $autoPostAction = if ($autoPostFormMatch) { [System.Web.HttpUtility]::HtmlDecode($autoPostFormMatch.Groups[1].Value) } else { $null }
            $autoPostSAMLRequestMatch = ($responseStep12.Content -join "`n" | Select-String -Pattern '<input[^>]*name=["'']SAMLRequest["''][^>]*value=["'']([^"'']*)["'']').Matches | Select-Object -First 1
            $autoPostSAMLRequest = if ($autoPostSAMLRequestMatch) { [System.Web.HttpUtility]::HtmlDecode($autoPostSAMLRequestMatch.Groups[1].Value) } else { $null }
            $autoPostRelayStateMatch = ($responseStep12.Content -join "`n" | Select-String -Pattern '<input[^>]*name=["'']RelayState["''][^>]*value=["'']([^"'']*)["'']').Matches | Select-Object -First 1
            $autoPostRelayState = if ($autoPostRelayStateMatch) { [System.Web.HttpUtility]::HtmlDecode($autoPostRelayStateMatch.Groups[1].Value) } else { $null }

            "[{0}] Auto-post form action: {1}" -f $functionName, ($autoPostAction ? $autoPostAction : "None") | Write-Verbose
            "[{0}] Auto-post SAMLRequest: {1}..." -f $functionName, ($autoPostSAMLRequest ? $autoPostSAMLRequest.Substring(0, [Math]::Min(100, $autoPostSAMLRequest.Length)) : "None") | Write-Verbose
            "[{0}] Auto-post RelayState: {1}..." -f $functionName, ($autoPostRelayState ? $autoPostRelayState.Substring(0, [Math]::Min(100, $autoPostRelayState.Length)) : "None") | Write-Verbose

            if (-not $autoPostAction) { 
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                throw "[{0}] Auto-post form action is null or empty." -f $functionName
            }

            if (-not $autoPostSAMLRequest) { 
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                throw "[{0}] Auto-post SAMLRequest is null or empty." -f $functionName
            }

            if (-not $autoPostRelayState) { 
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                throw "[{0}] Auto-post RelayState is null or empty." -f $functionName
            }

            $completedSteps++

            #EndRegion 

            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            #Region [STEP 13] Submit Auto-post Form to Azure AD (refined)
            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName | Write-Verbose
            "[{0}] [STEP 13] Submit auto-post form to Azure AD: '{1}'" -f $functionName, $autoPostAction | Write-Verbose
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName | Write-Verbose

            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Submit auto-post form to Azure AD" -Id 0
            $step++

            try {
                $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
                $ctx = $null
                $flowToken = $null
                $configObj = $null

                $autoPostBody = @{
                    SAMLRequest = $autoPostSAMLRequest
                    RelayState  = $autoPostRelayState
                }

                "[{0}] Executing SAML auto-post to: '{1}'" -f $functionName, $autoPostAction | Write-Verbose
                "[{0}] Auto-post body content: {1}" -f $functionName, ($autoPostBody | Out-String) | Write-Verbose

                $responseStep13 = Invoke-WebRequest -Uri $autoPostAction -Method POST -Form $autoPostBody -WebSession $session -MaximumRedirection 1 -ErrorAction Stop

                "[{0}] Received status code: '{1}' - {2}" -f $functionName, $responseStep13.StatusCode, $responseStep13.StatusDescription | Write-Verbose

                # $session.Cookies.GetCookies("https://login.microsoftonline.com") | Format-Table Name, Value, Domain, Path


                $configPattern = '\$Config\s*=\s*({.*?});'
                if ($responseStep13.Content -match $configPattern) {
                    $configJson = $matches[1]
                    $configJson | Out-File -FilePath "step13_config.json" -Encoding UTF8
                    "[{0}] Extracted and saved $Config JSON to step13_config.json" -f $functionName | Write-Verbose

                    $configObj = $configJson | ConvertFrom-Json
                    if ($configObj.sTenantId) {
                        $tenantId = $configObj.sTenantId
                        "[{0}] Extracted tenant ID from Config: {1}" -f $functionName, $tenantId | Write-Verbose
                    }

                    if ($configObj.sFT) {
                        $flowToken = $configObj.sFT
                        "[{0}] Extracted FlowToken from Config..." -f $functionName | Write-Verbose
                    }

                    if ($configObj.sCtx) {
                        $ctx = $configObj.sCtx
                        "[{0}] Extracted sCtx from Config..." -f $functionName | Write-Verbose
                    }

                    if ($configObj.apiCanary) {
                        $canaryValue = $configObj.apiCanary
                        "[{0}] Extracted apiCanary from Config..." -f $functionName | Write-Verbose
                    }

                    if ($configObj.urlGetCredentialType) {
                        $getCredTypeUrl = $configObj.urlGetCredentialType
                        "[{0}] Extracted GetCredentialType URL: {1}" -f $functionName, $getCredTypeUrl | Write-Verbose
                    }
                }
                else {
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "[{0}] Failed to extract `$Config variable from Azure AD response content!" -f $functionName
                }
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                "[{0}] Error during Step 13: {1}" -f $functionName, $_.Exception.Message | Write-Error
                throw $_.Exception
            }

            if ($debugSessionTracing) {
                "[{0}] --- SESSION DEBUG ---" -f $functionName | Write-Verbose

                # 🍪 Print cookies
                if ($session -and $session.Cookies) {
                    $cookieUri = "https://login.microsoftonline.com"
                    try {
                        $cookies = $session.Cookies.GetCookies($cookieUri)
                        "[{0}] WebSession has {1} cookies for {2}:" -f $functionName, $cookies.Count, $cookieUri | Write-Verbose
                        foreach ($cookie in $cookies) {
                            "[COOKIE] {0} = {1}; Domain={2}; Path={3}; Secure={4}" -f $cookie.Name, $cookie.Value, $cookie.Domain, $cookie.Path, $cookie.Secure | Write-Verbose
                        }
                    }
                    catch {
                        "[{0}] Failed to inspect cookies: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                    }
                }
                else {
                    "[{0}] WebSession is null or empty." -f $functionName | Write-Verbose
                }

                # 🔑 Log flow identifiers
                if ($flowToken) {
                    "[{0}] FlowToken present; length={1}" -f $functionName, $flowToken.Length | Write-Verbose
                }
                if ($ctx) {
                    "[{0}] sCtx present; starts with: {1}..." -f $functionName, $ctx.Substring(0, 30) | Write-Verbose
                }
                if ($canaryValue) {
                    "[{0}] Canary token present; starts with: {1}..." -f $functionName, $canaryValue.Substring(0, 30) | Write-Verbose
                }

                # 🧬 Device code metadata
                if ($deviceCodeResponse) {
                    "[{0}] DeviceCode: {1}..." -f $functionName, $deviceCodeResponse.device_code.Substring(0, 15) | Write-Verbose
                    "[{0}] Expires in: {1}s | Poll interval: {2}s" -f $functionName, $deviceCodeResponse.expires_in, $deviceCodeResponse.interval | Write-Verbose
                    "[{0}] UserCode: {1}" -f $functionName, $deviceCodeResponse.user_code | Write-Verbose
                }

                # 🧾 Polling error (inside Step 15 loop)
                if ($lastErrorObj) {
                    "[{0}] Last Token Poll Error: {1} - {2}" -f $functionName, $lastErrorObj.error, $lastErrorObj.error_description | Write-Verbose
                }

                "[{0}] --- END SESSION DEBUG ---" -f $functionName | Write-Verbose
            }

            $CompletedSteps++

            #EndRegion

            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            #Region [STEP 14] Submit DeviceCode Request
            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName | Write-Verbose
            "[{0}] [STEP 14] Submit DeviceCode request" -f $functionName | Write-Verbose
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName | Write-Verbose

            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Submit DeviceCode request" -Id 0
            $step++

            try {
                # Optional: GetCredentialType for Entropy
                $getCredTypeUrl = "https://login.microsoftonline.com/$tenantId/GetCredentialType?mkt=en-US"

                $credTypeBody = @{
                    username                       = $Username
                    isOtherIdpSupported            = $true
                    checkPhones                    = $false
                    isRemoteNGCSupported           = $true
                    isCookieBannerShown            = $false
                    isFidoSupported                = $true
                    originalRequest                = $ctx
                    country                        = "FR"
                    forceotclogin                  = $false
                    isExternalFederationDisallowed = $false
                    isSignup                       = $false
                    flowToken                      = $flowToken
                    isRemoteConnectSupported       = $false
                    federationFlags                = 0
                    isAccessPassSupported          = $true
                    isQrCodePinSupported           = $true
                } | ConvertTo-Json


                # For GetCredentialType
                $headersCredentialType = @{
                    "Canary" = $canaryValue
                }

                try {
                    "[{0}] Submitting GetCredentialType request to: '{1}'" -f $functionName, $getCredTypeUrl | Write-Verbose
                    "[{0}] Request body: {1}" -f $functionName, $credTypeBody | Write-Verbose
                    "[{0}] Request headers: {1}" -f $functionName, $headersCredentialType | Write-Verbose

                    $responseStep14 = Invoke-RestMethod -Method POST -Uri $getCredTypeUrl -Body $credTypeBody -Headers $headersCredentialType -WebSession $session -ContentType "application/json" -ErrorAction Stop
                    "[{0}] GetCredentialType response: {1}" -f $functionName, ($responseStep14 | ConvertTo-Json -Depth 3) | Write-Verbose

                    if ($responseStep14.Credentials.HasRemoteNGC -and $responseStep14.Credentials.RemoteNgcParams.Entropy) {
                        $correctAnswer = $responseStep14.Credentials.RemoteNgcParams.Entropy
                        $sessionIdentifier = $responseStep14.Credentials.RemoteNgcParams.SessionIdentifier
                        "[{0}] Confirming MSAL session identity = {1}" -f $functionName, $sessionIdentifier | Write-Verbose
                        "[{0}] Extracted Entropy: {1}" -f $functionName, $correctAnswer | Write-Verbose
                    }
                    else {
                        "[{0}] Warning: No Entropy found in GetCredentialType response. Push notification may not be supported." -f $functionName | Write-Warning
                    }
                }
                catch {
                    "[{0}] Warning: GetCredentialType failed, proceeding without Entropy: {1}" -f $functionName, $_.Exception.Message | Write-Warning
                }

                # DeviceCode Request - FORM ENCODED
                $deviceCodeUrl = "https://login.microsoftonline.com/$($configObj.sTenantId)/oauth2/v2.0/devicecode"
                # $clientId = $configObj.urlMsaSignUp.Split('client_id=')[1].Split('&')[0]
                # Azure CLI public client ID (proven to support Device Code Flow)
                $clientId = "f9688b63-3cb1-4843-896a-39a826d96b08"
                # $clientId = "04b07795-8ddb-461a-bbee-02f9e1bf7b46"


                $deviceCodeBody = [System.Collections.Generic.Dictionary[string, string]]::new()
                $deviceCodeBody.Add("client_id", $clientId)
                $deviceCodeBody.Add("scope", "openid profile email offline_access")

                $encodedBody = [System.Net.Http.FormUrlEncodedContent]::new($deviceCodeBody).ReadAsStringAsync().Result

                
                $headersDeviceCode = @{
                    "Content-Type"               = "application/x-www-form-urlencoded"
                    "x-client-SKU"               = "MSAL.PS"
                    "x-client-Ver"               = "1.0.0"
                    "x-client-OS"                = "Windows"
                    "x-client-CPU"               = "x64"
                    "x-client-Current-Telemetry" = "1|0.1.0|"
                    "x-ms-PKeyAuth"              = "1.0"
                    "x-ms-Request-Id"            = [guid]::NewGuid().ToString()
                    "x-AnchorMailbox"            = $Username
                    "User-Agent"                 = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) PowerShell/7.4"
                }


                "[{0}] Submitting DeviceCode request to: '{1}'" -f $functionName, $deviceCodeUrl | Write-Verbose
                "[{0}] Request body: {1}" -f $functionName, $encodedBody | Write-Verbose
                "[{0}] Request headers: {1}" -f $functionName, ($headersDeviceCode | out-String) | Write-Verbose

                $deviceCodeResponse = Invoke-RestMethod -Method POST -Uri $deviceCodeUrl -Body $encodedBody -WebSession $session -Headers $headersDeviceCode -ErrorAction Stop
                "[{0}] DeviceCode response: {1}" -f $functionName, ($deviceCodeResponse | ConvertTo-Json -Depth 3) | Write-Verbose

                # $session.Cookies.GetCookies("https://login.microsoftonline.com") | Format-Table Name, Value, Domain, Path


                # Save device_code and user_code
                if ($deviceCodeResponse.device_code) {
                    $deviceCode = $deviceCodeResponse.device_code
                    "[{0}] Extracted device_code: {1}..." -f $functionName, ($deviceCode.Substring(0, [Math]::Min(100, $deviceCode.Length))) | Write-Verbose
                }

                "[{0}] Session Identifier: {1}" -f $functionName, $sessionIdentifier | Write-Verbose
                "[{0}] Device Code: {1}" -f $functionName, $deviceCode.Substring(0, 20) | Write-Verbose


                if ($deviceCodeResponse.user_code) {
                    $userCode = $deviceCodeResponse.user_code
                    Write-Host "User Code:  $deviceCodeResponse.message"
                    "[{0}] Extracted user_code: {1}..." -f $functionName, ($userCode.Substring(0, [Math]::Min(100, $userCode.Length))) | Write-Verbose
                    "[{0}] Verification URI: {1}" -f $functionName, $deviceCodeResponse.verification_uri | Write-Verbose
                    "[{0}] Polling interval: {1} seconds" -f $functionName, $deviceCodeResponse.interval | Write-Verbose
                }

                $deviceCodeResponse | ConvertTo-Json -Depth 3 | Out-File -FilePath "devicecode_response.json" -Encoding UTF8
                "[{0}] Saved DeviceCode response to devicecode_response.json" -f $functionName | Write-Verbose

                # Push Notification Guidance
                if ($correctAnswer) {
                    Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Check your phone for a MS Authenticator push notification..." -Id 0
                    Start-Sleep -Seconds 2
                    $completedSteps++
                    Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Respond '$correctAnswer' to the MS Authenticator notification." -Id 0
                }
                else {
                    Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Visit $($deviceCodeResponse.verification_uri) and enter code: $userCode" -Id 0
                    $completedSteps++
                }
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                $errorMsg = "[{0}] Error in Step 14: {1}" -f $functionName, $_.Exception.Message
                "[{0}] {1}" -f $functionName, $errorMsg | Write-Error
                throw $errorMsg
            }

            $CompletedSteps++

            #EndRegion

            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            #Region [STEP 15] Poll /token Endpoint for Access Token
            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName | Write-Verbose
            "[{0}] [STEP 15] Poll /token endpoint for access token" -f $functionName | Write-Verbose
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName | Write-Verbose

            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Poll /token endpoint for access token" -Id 0
            $step++

            try {
                $pollUrl = "https://login.microsoftonline.com/$($configObj.sTenantId)/oauth2/v2.0/token"

                $pollBody = @{
                    client_id   = $clientId
                    device_code = $deviceCode
                    grant_type  = "urn:ietf:params:oauth:grant-type:device_code"
                }

                $headersTokenPoll = @{
                    "Content-Type"               = "application/x-www-form-urlencoded"
                    "x-client-SKU"               = "MSAL.PS"
                    "x-client-Ver"               = "1.0.0"
                    "x-client-OS"                = "Windows"
                    "x-client-CPU"               = "x64"
                    "x-client-Current-Telemetry" = "1|0.1.0|"
                    "x-ms-PKeyAuth"              = "1.0"
                    "x-ms-Request-Id"            = [guid]::NewGuid().ToString()
                    "User-Agent"                 = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) PowerShell/7.4"
                }



                "[{0}] Polling endpoint for Access Token: '{1}'" -f $functionName, $pollUrl | Write-Verbose
                "[{0}] Request body: {1}" -f $functionName, ($pollBody | Out-String) | Write-Verbose
                "[{0}] Request headers: {1}" -f $functionName, ($headersTokenPoll | Out-String) | Write-Verbose

                $pollCount = 0

                $timeoutSeconds = $deviceCodeResponse.expires_in
                $elapsed = [System.Diagnostics.Stopwatch]::StartNew()
                
                while ($elapsed.Elapsed.TotalSeconds -lt $timeoutSeconds) { 

                    $pollCount++
                    "[{0}] Poll attempt #{1}..." -f $functionName, $pollCount | Write-Verbose

                    try {

                        $tokenResponse = Invoke-RestMethod -Method POST -Uri $pollUrl -Body $pollBody -WebSession $session -Headers $headersTokenPoll
                        "[{0}] Token response received!" -f $functionName | Write-Verbose
                        $tokenResponse | ConvertTo-Json -Depth 3 | Out-File -FilePath "access_token_response.json" -Encoding UTF8
                        "[{0}] Saved token response to access_token_response.json" -f $functionName | Write-Verbose
                        break
                    }
                    catch {
                        $httpStatus = $_.Exception.Response.StatusCode.value__
                        "[CONNECT-HPEGL] HTTP Status Code: $httpStatus" | Write-Verbose
                        
                        if ($_.ErrorDetails -and $_.ErrorDetails.Message) {
                            try {
                                $errorObj = $_.ErrorDetails.Message | ConvertFrom-Json
                                $errorCode = $errorObj.error
                                $errorDescription = $errorObj.error_description

                                "[{0}] Token polling error: {1} - {2}" -f $functionName, $errorCode, $errorDescription | Write-Verbose

                                switch ($errorCode) {
                                    "authorization_pending" {
                                        "[{0}] Authorization still pending, sleeping for $($deviceCodeResponse.interval) seconds..." -f $functionName | Write-Verbose
                                        Start-Sleep -Seconds $deviceCodeResponse.interval
                                    }
                                    "authorization_declined" {
                                        if (-not $NoProgress) {
                                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                        }
                                        throw "[{0}] Authorization declined by user." -f $functionName
                                    }
                                    "expired_token" {
                                        if (-not $NoProgress) {
                                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                        }
                                        throw "[{0}] Device code expired before user completed authentication." -f $functionName
                                    }
                                    default {
                                        if (-not $NoProgress) {
                                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                        }
                                        throw "[{0}] Unexpected error during token polling: {1}" -f $functionName, $errorCode
                                    }
                                }
                            }
                            catch {
                                if (-not $NoProgress) {
                                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                }
                                "[{0}] Failed to parse error response JSON: {1}" -f $functionName, $_.ErrorDetails.Message | Write-Verbose
                                throw "[{0}] Raw error: {1}" -f $functionName, $_.ErrorDetails.Message
                            }
                        }
                        else {
                            if (-not $NoProgress) {
                                Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                            }
                            throw "[{0}] No error details available during token polling." -f $functionName
                        }
                    }
                }
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                "[{0}] Error during token polling: {1}" -f $functionName, $_.Exception.Message | Write-Error
                throw $_.Exception.Message
            }

            $CompletedSteps++

            #EndRegion

            exit       

        }
        # Handle non SSO and hpe.com SSO Email cases
        else {


            #region [STEP 1] Generate PKCE code verifier and challenge
            Write-Verbose " ----------------------------------STEP 1--------------------------------------------------------------------------------"
            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Generate PKCE code verifier and challenge" -Id 0
            $step++
            Write-Verbose "[${functionName}] Generating PKCE code verifier and challenge"
            # Generate a browser-compliant PKCE code_verifier: 86 chars of [A-Za-z0-9-._~]
            $pkceChars = ([char]45, [char]46, [char]95, [char]126) + (48..57 | ForEach-Object { [char]$_ }) + (65..90 | ForEach-Object { [char]$_ }) + (97..122 | ForEach-Object { [char]$_ })
            $codeVerifier = -join (1..86 | ForEach-Object { $pkceChars | Get-Random })
            $sha256 = [System.Security.Cryptography.SHA256]::Create()
            $codeChallenge = [Convert]::ToBase64String($sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($codeVerifier))).TrimEnd('=')
            $codeChallenge = $codeChallenge.Replace('+', '-').Replace('/', '_')
            "[{0}] Code verifier (for PKCE): {1}...{2}" -f $functionName, $codeVerifier.Substring(0, 1), $codeVerifier.Substring($codeVerifier.Length - 1, 1) | Write-Verbose
            "[{0}] Code challenge (for PKCE): {1}...{2}" -f $functionName, $codeChallenge.Substring(0, 1), $codeChallenge.Substring($codeChallenge.Length - 1, 1) | Write-Verbose

            $completedSteps++
            #endregion STEP 1: End PKCE code_verifier and code_challenge generation

            #region [STEP 2] Retrieve client_id and oauthIssuer from HPE settings.json (https://common.cloud.hpe.com/settings.json)
            Write-Verbose " ----------------------------------STEP 2--------------------------------------------------------------------------------"
            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Retrieve client_id and oauthIssuer from HPE settings.json" -Id 0
            $step++
            $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
            $headers = @{
                "Accept" = "application/json"
            }
            "[{0}] Step 2: GET https://common.cloud.hpe.com/settings.json" -f $functionName | Write-Verbose
            $settingsResp = Invoke-RestMethod -Uri "https://common.cloud.hpe.com/settings.json" -Method Get -Headers $headers
            $dynamicClientId = "aquila-user-auth"
            $dynamicIssuer = $settingsResp.oauthIssuer
            if (-not $dynamicIssuer) {
                "[{0}] Could not retrieve oauthIssuer from settings.json." -f $functionName | Write-Verbose
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                throw "Authentication failed: Could not retrieve oauthIssuer from settings.json."
            }
            "[{0}] client_id: {1}" -f $functionName, $dynamicClientId | Write-Verbose
            "[{0}] oauthIssuer from settings.json: {1}" -f $functionName, $dynamicIssuer | Write-Verbose
            $completedSteps++
            #endregion STEP 2: End retrieval of client_id and oauthIssuer 

            #region [STEP 3] Initiate authorization to obtain stateToken from /as/authorization.oauth2
            Write-Verbose " ----------------------------------STEP 3--------------------------------------------------------------------------------"
            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Initiate authorization to obtain stateToken" -Id 0
            $step++
            $RedirectUri = 'https://common.cloud.hpe.com/authentication/callback'
            $authzUrl = "https://sso.common.cloud.hpe.com/as/authorization.oauth2?client_id=$dynamicClientId"
            $authzUrl += "&redirect_uri=$([uri]::EscapeDataString($RedirectUri))"
            $authzUrl += "&response_type=code"
            $authzUrl += "&scope=openid%20profile%20email"
            $authzUrl += "&code_challenge=$codeChallenge"
            $authzUrl += "&code_challenge_method=S256"

            # Hide sensitive information in logs
            $authzUrlLog = $authzUrl
            if ($authzUrlLog -match 'client_id=[^&]+') {
                $authzUrlLog = $authzUrlLog -replace '(client_id=)[^&]+', '$1[REDACTED]'
            }
            if ($authzUrlLog -match 'code_challenge=[^&]+') {
                $authzUrlLog = $authzUrlLog -replace '(code_challenge=)[^&]+', '$1[REDACTED]'
            }
            "[{0}] Step 3: GET {1}" -f $functionName, $authzUrlLog | Write-Verbose
            "[{0}] About to execute GET request to: '{1}'" -f $functionName, $authzUrlLog | Write-Verbose
        
            $response = Invoke-WebRequest $authzUrl -Method 'GET' -Headers $headers -WebSession $session

            # Log-Cookies -Domain $authzUrl -Session $session -Step "Step 3 (GET $authzUrl)"
            $stateToken = ($response.Content -split "[`r`n]" | Select-String -Pattern '(?:"stateToken":")(.*?)(?:")').Matches | ForEach-Object { $_.Groups[1].Value }
        
            if (-not $stateToken) {
                "[{0}] Could not extract stateToken from /as/authorization.oauth2 response." -f $functionName | Write-Verbose
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                throw "Authentication failed: Could not extract stateToken from /as/authorization.oauth2 response."
            }
            $stateToken = [System.Text.RegularExpressions.Regex]::Replace($stateToken, "\\x([0-9A-Fa-f]{2})", { param($m) [char][Convert]::ToInt32($m.Groups[1].Value, 16) })
            $stateToken = [System.Text.RegularExpressions.Regex]::Replace($stateToken, "\\u([0-9A-Fa-f]{4})", { param($m) [char][Convert]::ToInt32($m.Groups[1].Value, 16) })
            "[{0}] stateToken (unescaped): {1}...{2}" -f $functionName, $stateToken.Substring(0, 1), $stateToken.Substring($stateToken.Length - 1, 1) | Write-Verbose
            $completedSteps++
            #endregion STEP 3: End stateToken extraction from authorization endpoint

            #region [STEP 4] Exchange stateToken for stateHandle via Okta IDX introspect (/idp/idx/introspect) 
            Write-Verbose " ----------------------------------STEP 4--------------------------------------------------------------------------------"
            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Exchange stateToken for stateHandle" -Id 0
            $step++
            "[{0}] Step 4: POST https://auth.hpe.com/idp/idx/introspect" -f $functionName | Write-Verbose
            $introspectPayloadObj = @{ stateToken = $stateToken }
            $introspectPayload = $introspectPayloadObj | ConvertTo-Json
            $introspectResp = $null

            $retry = $false
            for ($i = 0; $i -lt 2; $i++) {
                try {
                    "[{0}] About to execute POST request to: '{1}'" -f $functionName, "https://auth.hpe.com/idp/idx/introspect" | Write-Verbose
                    $introspectPayloadLog = $introspectPayloadObj | ConvertTo-Json
                    "[{0}] Payload content: `n{1}" -f $functionName, ($introspectPayloadLog -replace '("stateToken"\s*:\s*")([^"]+)(")', '$1[REDACTED]$3') | Write-Verbose
                    $introspectResp = Invoke-RestMethod -Uri "https://auth.hpe.com/idp/idx/introspect" -Method Post -Body $introspectPayload -ContentType "application/json" -WebSession $session -Headers $headers

                    # Log-Cookies -Domain "https://auth.hpe.com" -Session $session -Step "Step 4 (POST /idp/idx/introspect)"
                    if ($introspectResp.stateHandle) {
                        break
                    }
                    elseif ($introspectResp.messages -and $introspectResp.messages.value -and $introspectResp.messages.value[0].message -eq "The session has expired.") {
                        "[{0}] Session expired at introspect. Retrying flow from STEP 5.3..." -f $functionName | Write-Verbose
                        $retry = $true
                    }
                    else {
                        break
                    }
                }
                catch {
                    "[{0}] Error during introspect: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                    if ($_.Exception.Response -and ($_.Exception.Response.Content | ConvertFrom-Json).messages.value[0].message -eq "The session has expired.") {
                        "[{0}] Session expired at introspect (exception). Retrying flow from STEP 5.3..." -f $functionName | Write-Verbose
                        $retry = $true
                    }
                    else {
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        throw "Authentication failed: Error during introspect: $_"
                    }
                }
                if ($retry -and $i -eq 0) {
                    Start-Sleep -Seconds 1
                    # Re-run STEP 5.3: GET /as/authorization.oauth2 to get new stateToken
                    "[{0}] Retrying STEP 5.3: GET /as/authorization.oauth2 for new stateToken" -f $functionName | Write-Verbose
                    "[{0}] About to execute GET request to: '{1}'" -f $functionName, $authzUrl | Write-Verbose
                    try {
                        $response = Invoke-WebRequest $authzUrl -Method 'GET' -Headers $headers -WebSession $session
                        $stateToken = ($response.Content -split "[`r`n]" | Select-String -Pattern '(?:"stateToken":")(.*?)(?:")').Matches | ForEach-Object { $_.Groups[1].Value }
                        if (-not $stateToken) {
                            "[{0}] Could not extract stateToken from /as/authorization.oauth2 response (retry)." -f $functionName | Write-Verbose
                            if (-not $NoProgress) {
                                Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                            }
                            throw "Authentication failed: Could not extract stateToken from /as/authorization.oauth2 response (retry)."
                        }
                        $stateToken = [System.Text.RegularExpressions.Regex]::Replace($stateToken, "\\x([0-9A-Fa-f]{2})", { param($m) [char][Convert]::ToInt32($m.Groups[1].Value, 16) })
                        $stateToken = [System.Text.RegularExpressions.Regex]::Replace($stateToken, "\\u([0-9A-Fa-f]{4})", { param($m) [char][Convert]::ToInt32($m.Groups[1].Value, 16) })
                        "[{0}] stateToken (retry): {1}" -f $functionName, $stateToken | Write-Verbose
                        $introspectPayload = @{ stateToken = $stateToken } | ConvertTo-Json
                        $retry = $false
                    }
                    catch {
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        throw "Authentication failed: Failed to obtain new stateToken in retry: $_"
                    }
                }
            }

            $stateHandle = $introspectResp.stateHandle

            if (-not $stateHandle) {
                "[{0}] Failed to get stateHandle from introspect response" -f $functionName | Write-Verbose
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                throw "Authentication failed: Could not extract stateHandle from introspect response."
            }
            # Validate stateHandle format (allow ~ in addition to alphanumeric, ., _, and -)
            if ($stateHandle -notmatch "^[a-zA-Z0-9._~-]+$") {
                "[{0}] Invalid stateHandle format: {1}" -f $functionName, $stateHandle | Write-Verbose
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                throw "Authentication failed: Invalid stateHandle format."
            }

            "[{0}] stateHandle: {1}*********" -f $functionName, ($stateHandle.Substring(0, [Math]::Min(10, $stateHandle.Length))) | Write-Verbose


            $completedSteps++
            #endregion STEP 4: End IDX introspect (stateHandle retrieval)

            #Region [STEP 5]: Identify user with Okta IDX (POST /idp/idx/identify)
            Write-Verbose " ----------------------------------STEP 5--------------------------------------------------------------------------------"
            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Identify user with Okta IDX" -Id 0
            $step++
            "[{0}] Step 5: POST https://auth.hpe.com/idp/idx/identify" -f $functionName | Write-Verbose
            $identifyPayloadObj = @{ identifier = $Username; stateHandle = $stateHandle }
            $identifyPayload = $identifyPayloadObj | ConvertTo-Json
            "[{0}] About to execute POST request to: '{1}'" -f $functionName, "https://auth.hpe.com/idp/idx/identify" | Write-Verbose
            $identifyPayloadLog = $identifyPayloadObj | ConvertTo-Json
            # Hide stateHandle value in logs for security
            $identifyPayloadLogRedacted = $identifyPayloadLog -replace '("stateHandle"\s*:\s*")([^"]+)(")', '$1[REDACTED]$3'
            "[{0}] Payload content: `n{1}" -f $functionName, $identifyPayloadLogRedacted | Write-Verbose
            try {
                # Use Invoke-WebRequest to capture raw response
                $response = Invoke-WebRequest -Uri "https://auth.hpe.com/idp/idx/identify" -Method Post -Body $identifyPayload -ContentType "application/json" -WebSession $session -Headers $headers
                $identifyResp = $response.Content | ConvertFrom-Json
                # Hide stateHandle value in logs for security
 
                $identifyRespRedacted = Redact-StateHandle $identifyResp
                $identifyRespJson = $identifyRespRedacted | ConvertTo-Json -Depth 20
                "[{0}] Identify response received: `n{1}" -f $functionName, $identifyRespJson | Write-Verbose
                # Check for errors in the response messages                     
                if ($identifyResp.messages -and $identifyResp.messages.value) {
                    "[{0}] Authentication failed: Unexpected error in response messages: {1}" -f $functionName, ($identifyResp.messages | ConvertTo-Json -Depth 20) | Write-Verbose
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "Authentication failed: Unexpected error in response messages: $($identifyResp.messages | ConvertTo-Json -Depth 20)"
                } 
                # Log-Cookies -Domain "https://auth.hpe.com" -Session $session -Step "Step 5 (POST /idp/idx/identify)"                 
            }
            catch {
                $StatusCode = $_.Exception.Response.StatusCode
                $StatusError = $_.Exception.Response.StatusDescription
                "[{0}] Error status code: {1} ({2})" -f $functionName, $StatusCode, $StatusError | Write-Verbose
                $errorContent = $_.ErrorDetails.Message
                "[{0}] Raw error content: {1}" -f $functionName, $errorContent | Write-Verbose

                $errorBody = $null
                try {
                    if ($errorContent -and $errorContent -is [string] -and $errorContent.Trim()) {
                        $errorBody = $errorContent | ConvertFrom-Json
                        "[{0}] Parsed error response body" -f $functionName | Write-Verbose
                    }
                }
                catch {
                    "[{0}] Failed to parse error response: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                }

                if ($StatusCode -eq 401) {
                    if ($errorBody -and $errorBody.messages -and $errorBody.messages.value) {
                        foreach ($message in $errorBody.messages.value) {
                            switch ($message.i18n.key) {
                                "errors.E0000004" {
                                    "[{0}] Detected incorrect password error (errors.E0000004)" -f $functionName | Write-Verbose
                                    if (-not $NoProgress) {
                                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                    }
                                    throw "Authentication failed: Incorrect password. Please verify your credentials and try again."
                                }
                                "errors.E0000015" {
                                    "[{0}] Detected insufficient permissions error (errors.E0000015)" -f $functionName | Write-Verbose
                                    if (-not $NoProgress) {
                                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                    }                                        
                                    throw "Authentication failed: Insufficient permissions. Please ensure your account has the necessary access rights."
                                }
                                "errors.E0000011" {
                                    "[{0}] Detected invalid token error (errors.E0000011)" -f $functionName | Write-Verbose
                                    if (-not $NoProgress) {
                                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                    }
                                    throw "Authentication failed: Invalid token provided. Please try again or contact your administrator."
                                }
                                "errors.E0000064" {
                                    "[{0}] Detected password expired error (errors.E0000064)" -f $functionName | Write-Verbose
                                    if (-not $NoProgress) {
                                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                    }                                        
                                    throw "Authentication failed: Your password has expired. Please reset your password and try again."
                                }
                                "errors.E0000207" {
                                    "[{0}] Detected incorrect username or password error (errors.E0000207)" -f $functionName | Write-Verbose
                                    if (-not $NoProgress) {
                                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                    }                                        
                                    throw "Authentication failed: Incorrect username or password. Please verify your credentials and try again."
                                }
                                default {
                                    "[{0}] Detected other error: {1} (key={2})" -f $functionName, $message.message, $message.i18n.key | Write-Verbose
                                    if (-not $NoProgress) {
                                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                    }
                                    throw "Authentication failed: $($message.message) (key=$($message.i18n.key))"
                                }
                            }
                        }
                    }
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }                        
                    throw "Authentication failed: $StatusCode $StatusError (no error details)"
                }
                elseif ($StatusCode -eq 403) {
                    if ($errorBody -and $errorBody.messages -and $errorBody.messages.value) {
                        foreach ($message in $errorBody.messages.value) {
                            switch ($message.i18n.key) {
                                "errors.E0000005" {
                                    "[{0}] Detected invalid session error (errors.E0000005)" -f $functionName | Write-Verbose
                                    if (-not $NoProgress) {
                                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                    }
                                    throw "Authentication failed: Invalid session. Please try logging in again."
                                }
                                default {
                                    "[{0}] Detected other error: {1} (key={2})" -f $functionName, $message.message, $message.i18n.key | Write-Verbose
                                    if (-not $NoProgress) {
                                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                    }
                                    throw "Authentication failed: $($message.message) (key=$($message.i18n.key))"
                                }
                            }
                        }
                    }
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "Authentication failed: $StatusCode $StatusError (no error details)"
                }
                elseif ($StatusCode -eq 404) {
                    if ($errorBody -and $errorBody.messages -and $errorBody.messages.value) {
                        foreach ($message in $errorBody.messages.value) {
                            switch ($message.i18n.key) {
                                "errors.E0000007" {
                                    "[{0}] Detected resource not found error (errors.E0000007)" -f $functionName | Write-Verbose
                                    if (-not $NoProgress) {
                                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                    }
                                    throw "Authentication failed: Resource not found. Please contact your administrator."
                                }
                                default {
                                    "[{0}] Detected other error: {1} (key={2})" -f $functionName, $message.message, $message.i18n.key | Write-Verbose
                                    if (-not $NoProgress) {
                                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                    }
                                    throw "Authentication failed: $($message.message) (key=$($message.i18n.key))"
                                }
                            }
                        }
                    }
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "Authentication failed: $StatusCode $StatusError (no error details)"
                }

                # Handle other unexpected errors
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                throw "Authentication failed: Unexpected error: {0} {1} - {2}" -f $StatusCode, $StatusError, $_.Exception.Message
            }


            if ($identifyResp.messages -and $identifyResp.messages.value -and $identifyResp.messages.value.Count -gt 0) {
                "[{0}] Authentication failed: Unexpected error in response messages: {1}" -f $functionName, ($identifyResp.messages | ConvertTo-Json -Depth 20) | Write-Verbose
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                throw "Authentication failed: Unexpected error in response messages: $($identifyResp.messages | ConvertTo-Json -Depth 20)"
            }          
            
            if (-not $identifyResp.stateHandle) {
                "[{0}] Authentication failed: Could not extract stateHandle from identify response." -f $functionName | Write-Verbose
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                throw "Authentication failed: Could not extract stateHandle from identify response."
            }
            else {
                "[{0}] Identification successful, stateHandle obtained." -f $functionName | Write-Verbose
                $stateHandle = $identifyResp.stateHandle
            }
            
            # Extract user identifier (for potential use later)
            if ( $identifyResp.user -or $identifyResp.user.value -or $identifyResp.user.value.identifier) {
                $userIdentifier = $identifyResp.user.value.identifier
                "[{0}] Extracted user identifier: {1}" -f $functionName, $userIdentifier | Write-Verbose
            }
            elseif (-not $SSOEmail) {
                "[{0}] No user identifier found in identify response. The username has not been recognized by HPE GreenLake" -f $functionName | Write-Verbose
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                throw "Authentication failed: The username '$Username' was not recognized by HPE GreenLake. Please check the username and try again."
            }

            # Extract the id of the authentication issuer (for potential use later)
            if ($identifyResp.authentication -and $identifyResp.authentication.value -and $identifyResp.authentication.value.issuer) {
                $Oauth2IssuerId = $identifyResp.authentication.value.issuer.id
                # Store Issuer Id in a global variable for use in other functions
                $Global:HPEGLOauth2IssuerId = $Oauth2IssuerId
                "[{0}] Extracted OAuth2 Issuer Id: {1}" -f $functionName, $Oauth2IssuerId | Write-Verbose
            }
            else {
                "[{0}] No OAuth2 Issuer Id found in identify response." -f $functionName | Write-Verbose
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                throw "Authentication failed: Could not extract OAuth2 Issuer Id from identify response."
            }

            # Extract the appid of the "HPE GreenLake edge-to-cloud Platform" application  (for potential use later)
            if ($identifyResp.app -and $identifyResp.app.value -and $identifyResp.app.value.id) {
                $HPEGLAppId = $identifyResp.app.value.id
                "[{0}] Extracted HPE GreenLake App Id: {1}" -f $functionName, $HPEGLAppId | Write-Verbose
                # Store App Id in a global variable for use in other functions
                $Global:HPEGLEdgeToCloudAppId = $HPEGLAppId
            }
            else {
                "[{0}] No HPE GreenLake App Id found in identify response." -f $functionName | Write-Verbose
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                throw "Authentication failed: Could not extract HPE GreenLake App Id from identify response."
            }

            # Determine available authenticators and select preferred one
            # Prioritize Okta Verify (push or TOTP), then Google Authenticator, then password as fallback
            if ($identifyResp.authenticators -and $identifyResp.authenticators.value) {
                $authenticators = $identifyResp.authenticators.value
                $preferredAuthenticator = $null

                foreach ($auth in $authenticators) {
                    $methods = if ($auth.methods) { $auth.methods | ForEach-Object { $_.type } } else { @() }

                    # Prefer Okta Verify PUSH if available
                    if ($auth.type -eq 'app' -and $auth.key -eq 'okta_verify' -and $methods -contains 'push') {
                        $preferredAuthenticator = @{ auth = $auth; methodType = 'push'; name = $auth.displayName }
                        "[{0}] Okta Verify PUSH authenticator selected." -f $functionName | Write-Verbose
                        break
                    }
                }

                # If no Okta Verify PUSH, look for Okta Verify TOTP
                if (-not $preferredAuthenticator) {
                    foreach ($auth in $authenticators) {
                        $methods = if ($auth.methods) { $auth.methods | ForEach-Object { $_.type } } else { @() }
                        if ($auth.type -eq 'app' -and $auth.key -eq 'okta_verify' -and $methods -contains 'totp') {
                            $preferredAuthenticator = @{ auth = $auth; methodType = 'totp'; name = $auth.displayName }
                            "[{0}] Okta Verify TOTP selected." -f $functionName | Write-Verbose
                            break
                        }
                    }
                }

                # If no Okta Verify, look for Google Authenticator
                if (-not $preferredAuthenticator) {
                    foreach ($auth in $authenticators) {
                        $methods = if ($auth.methods) { $auth.methods | ForEach-Object { $_.type } } else { @() }
                        if ($auth.type -eq 'app' -and $auth.key -eq 'google_otp' -and $methods -contains 'otp') {
                            $preferredAuthenticator = @{ auth = $auth; methodType = 'otp'; name = $auth.displayName }
                            "[{0}] Google Authenticator selected." -f $functionName | Write-Verbose
                            break
                        }
                    }
                }

                # If neither Okta nor Google, fallback to password
                if (-not $preferredAuthenticator) {
                    foreach ($auth in $authenticators) {
                        $methods = if ($auth.methods) { $auth.methods | ForEach-Object { $_.type } } else { @() }
                        if ($auth.type -eq 'password' -and $methods -contains 'password') {
                            $preferredAuthenticator = @{ auth = $auth; methodType = 'password'; name = $auth.displayName }
                            "[{0}] Password authenticator selected as fallback." -f $functionName | Write-Verbose
                            break
                        }
                    }
                }

                # If still not found, throw for unsupported MFA
                if (-not $preferredAuthenticator) {
                    $unsupported = $authenticators | ForEach-Object {
                        "{0} (type={1}, id={2})" -f $_.displayName, $_.type, $_.id
                    } | Out-String
                    $errMsg = "[{0}] Unsupported MFA method detected. Only Okta Verify push or TOTP (Okta/Google) are supported. Found: {1}" -f $functionName, $unsupported
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    "[{0}] {1}" -f $functionName, $errMsg | Write-Verbose
                    throw "Authentication failed: $errMsg"
                }
            }
            # If redirect IDP with SSO with hpe.com email addresses
            elseif ($identifyResp.remediation -and $identifyResp.remediation.value -and ($identifyResp.remediation.value | Where-Object { $_.name -eq 'redirect-idp' })) {
                $redirectIdp = $identifyResp.remediation.value | Where-Object { $_.name -eq 'redirect-idp' }
                $preferredAuthenticator = @{ methodType = $redirectIdp.name; name = $redirectIdp.idp.name; id = $redirectIdp.idp.id; href = $redirectIdp.href }

                "[{0}] Redirect to external IDP detected." -f $functionName | Write-Verbose

                if ($PSBoundParameters.ContainsKey('SSOEmail') -and $SSOEmail -match 'hpe.com$') {
                    "[{0}] SSO authentication with HPE email {1}." -f $functionName, $SSOEmail | Write-Verbose
                    # Set SSO flag to trigger SSO flow later
                    $SSOwithHPEEmail = $true
                }
                else {
                    $errMsg = "[{0}] SSO authentication detected with non-HPE email domain. Only hpe.com emails are supported for SSO." -f $functionName
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }                    
                    "[{0}] {1}" -f $functionName, $errMsg | Write-Verbose
                    throw "Authentication failed: $errMsg"
                }
            }
            else {
                $errMsg = "[{0}] No authenticators found in identify response." -f $functionName
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }                    
                "[{0}] {1}" -f $functionName, $errMsg | Write-Verbose
                throw "Authentication failed: $errMsg"
            }

            # verbose the preferred authenticator details
            # Hide stateTokenExternalId value in logs for security
            $preferredAuthenticatorLog = $preferredAuthenticator | Select-Object *
            if ($preferredAuthenticatorLog.PSObject.Properties['href'] -and $preferredAuthenticatorLog.href -match 'stateTokenExternalId=([^&]+)') {
                $preferredAuthenticatorLog.href = $preferredAuthenticatorLog.href -replace '(stateTokenExternalId=)[^&]+', '$1[REDACTED]'
            }
            "[{0}] Preferred authenticator details: {1}" -f $functionName, ($preferredAuthenticatorLog | Out-String) | Write-Verbose

            # Capture href in remediation where name is challenge-authenticator
            $authenticatorHref = $identifyResp.remediation.value | Where-Object { $_.name -eq 'challenge-authenticator' } | Select-Object -ExpandProperty href
            if ($authenticatorHref) {
                "[{0}] Extracted authenticator href for challenge-authenticator: {1}" -f $functionName, ($authenticatorHref -replace 'stateTokenExternalId=[^&]+', 'stateTokenExternalId=[REDACTED]') | Write-Verbose
            }
            else {
                "[{0}] No authenticator href found for challenge-authenticator." -f $functionName | Write-Verbose
            }

            $completedSteps++
            #Endregion STEP 5: End user identification            

            if ($SSOwithHPEEmail) {

                "[{0}] SSO authentication detected with HPE email {1}." -f $functionName, $SSOEmail | Write-Verbose

                #region [STEP 5.1]: Redirect to stateToken URL (GET https://auth.hpe.com/sso/idps/xxxxxxxxxxxxxxxx?stateTokenExternalId=xxxxxxxxxxxxxxxxxxxxxx)
                Write-Verbose " ----------------------------------STEP 5.1--------------------------------------------------------------------------------"
                Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Redirect to stateToken URL" -Id 0
                $step++
                "[{0}] Step 5.1: GET https://auth.hpe.com/sso/idps/xxxxxxxxxxxxxxxx?stateTokenExternalId=xxxxxxxxxxxxxxxxxxxxxx" -f $functionName | Write-Verbose
                # Hide stateTokenExternalId value in logs for security
                $hrefLog = $preferredAuthenticator.href
                if ($hrefLog -match 'stateTokenExternalId=[^&]+') {
                    $hrefLog = $hrefLog -replace '(stateTokenExternalId=)[^&]+', '$1[REDACTED]'
                }
                "[{0}] About to execute GET request to: '{1}'" -f $functionName, $hrefLog | Write-Verbose
                try {
                    $responseStep51 = Invoke-webrequest $preferredAuthenticator.href -Method 'GET' -ErrorAction Stop -WebSession $session
                    "[{0}] SAML2 IDP response received successfully." -f $functionName | Write-Verbose
                    # "[{0}] Raw response for `$responseStep51: `n{1}" -f $functionName, ($responseStep51.content | Out-String) | Write-verbose
                    # Log-Cookies -Domain "https://auth.hpe.com" -Session $session -Step "Step 5.1 (GET redirect-idp)"
                }
                catch {
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "Authentication failed: Error during redirect to external IDP: $_"
                }
       
                # Get action, method, relayState, LoginHint and SAMLRequest values from the html response
                $encodedaction = ($responseStep51.content | Select-String -Pattern '(?<=action=")(.*?)(?=")' -AllMatches).Matches | ForEach-Object { $_.groups[1].Value }
                $action = [System.Web.HttpUtility]::HtmlDecode($encodedaction)
                "[{0}] Extracted Action: '{1}'" -f $functionName, $action | Write-Verbose
                    
                $method = ($responseStep51.content | Select-String -Pattern '(?<=method=")(.*?)(?=")' -AllMatches).Matches | ForEach-Object { $_.groups[1].Value }
                "[{0}] Extracted Method: '{1}'" -f $functionName, $method | Write-Verbose
                    
                $LoginHint = ($responseStep51.content | Select-String -Pattern '(?<=name="LoginHint" type="hidden" value=")(.*?)(?=")' -AllMatches).Matches | ForEach-Object { $_.groups[1].Value }
                $LoginHint = [System.Web.HttpUtility]::HtmlDecode($LoginHint)
                "[{0}] Extracted LoginHint: '{1}'" -f $functionName, $LoginHint | Write-Verbose
                    
                $encodedRelayState = ($responseStep51.content | Select-String -Pattern '(?<=name="RelayState" type="hidden" value=")(.*?)(?=")' -AllMatches).Matches | ForEach-Object { $_.groups[1].Value }
                $RelayState = [System.Web.HttpUtility]::HtmlDecode($encodedRelayState)
                # "[{0}] Extracted RelayState: '{1}'" -f $functionName, $RelayState | Write-Verbose
                $decodeRelayState = [System.Web.HttpUtility]::UrlDecode($RelayState)
                # "[{0}] Decoded RelayState: '{1}'" -f $functionName, $decodeRelayState | Write-Verbose
        
                # Extract the SAMLRequest value from the HTML response
                $encodedSAMLRequest = ($responseStep51.Content -join "`n" | Select-String -Pattern 'name="SAMLRequest" type="hidden" value="([^"]+)"' -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value }
                # "[{0}] Extracted Encoded SAMLRequest: '{1}'" -f $functionName, $encodedSAMLRequest | Write-Verbose
        
                $SAMLRequest = [System.Web.HttpUtility]::HtmlDecode($encodedSAMLRequest)
                # "[{0}] Extracted Decoded SAMLRequest: '{1}'" -f $functionName, $SAMLRequest | Write-Verbose
        
                $CompletedSteps++

                #EndRegion STEP 5.1: End user identification redirect to IDP    
                
                #Region [STEP 5.2]: SAML Authentication Request Submission (POST https://mylogin.hpe.com/app/hpe_211366workforceuserauthentication_1/exk95g22w0a0gbCGg697/sso/saml2?RelayState=...&SAMLRequest=...&LoginHint=...)
                Write-Verbose " ----------------------------------STEP 5.2--------------------------------------------------------------------------------"
                Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - SAML Authentication Request Submission" -Id 0
                $step++
                "[{0}] Step 5.2: POST https://mylogin.hpe.com/app/hpe_211366workforceuserauthentication_1/exk95g22w0a0gbCGg697/sso/saml" -f $functionName | Write-Verbose

                "[{0}] About to execute {1} request to: '{2}'" -f $functionName, $method, $action | Write-Verbose
                            
                # Define the payload
                $payload = @{
                    'SAMLRequest' = $SAMLRequest
                    'LoginHint'   = $LoginHint
                    'RelayState'  = $decodeRelayState
                } 
                            
                # Hide SAMLRequest and okta_key values in logs for security
                $redactedPayload = $payload.Clone()  # Create a shallow copy (sufficient for simple hashtables)
                $redactedPayload['SAMLRequest'] = '[REDACTED]'
                $redactedPayload['RelayState'] = $redactedPayload['RelayState'] -replace 'okta_key=([^&]+)', 'okta_key=[REDACTED]'

                "[{0}] Payload for POST request: {1}" -f $functionName, ($redactedPayload | Out-String) | Write-Verbose

                $payload = ($payload.GetEnumerator() | ForEach-Object { "$($_.Key)=$([System.Web.HttpUtility]::UrlEncode($_.Value))" }) -join "&"
                
                # Define the headers
                $headers = @{
                    "Content-Type" = "application/x-www-form-urlencoded"
                }
                # Decode SAMLRequest for ID extraction
                $decodedSAMLRequest = $null
                if ($SAMLRequest -match '^[A-Za-z0-9+/=]+$') {
                    try {
                        $decodedSAMLRequest = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String($SAMLRequest))
                        # "[{0}] Decoded SAMLRequest: `n'{1}'" -f $functionName, $decodedSAMLRequest | Write-Verbose
                    }
                    catch {
                        "[{0}] ERROR: Failed to decode SAMLRequest: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        throw "Authentication failed: Could not decode SAMLRequest."
                    }
                }
                else {
                    "[{0}] WARNING: SAMLRequest is not base64-encoded: '{1}'" -f $functionName, $SAMLRequest | Write-Verbose
                    $decodedSAMLRequest = $SAMLRequest  # Assume it's already decoded
                }
                try {
                    $responseStep52 = Invoke-WebRequest -Uri $action -Method $method -ErrorAction Stop -Headers $headers -Body $payload -WebSession $Session 
                    "[{0}] SAML2 IDP response received successfully." -f $functionName | Write-Verbose 

                    # Log-Cookies -Domain "https://mylogin.hpe.com" -Session $session -Step "Step 5.2 (POST SAMLRequest)"

                    # Extract AuthnRequest ID from decoded SAMLRequest
                    $authnRequestId = ($decodedSAMLRequest | Select-String -Pattern 'ID="([^"]+)"' | ForEach-Object { $_.Matches.Groups[1].Value })
                    if ($authnRequestId) {
                        "[{0}] Step 5.2 AuthnRequest ID: {1}...{2}" -f $functionName, $authnRequestId.Substring(0, 1), $authnRequestId.Substring($authnRequestId.Length - 1, 1) | Write-Verbose
                    }
                    else {
                        "[{0}] WARNING: No AuthnRequest ID found in SAMLRequest!" -f $functionName | Write-Verbose
                    }
                    
                }
                catch {
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    "[{0}] SAML2 IDP response failed to process: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                    "[{0}] Exception details: {1}" -f $functionName, ($_.Exception | Out-String) | Write-Verbose
                    throw "Authentication failed: Could not complete SAML authentication request. {1}" -f $_.Exception.Message
                }
                # Extract stateToken from HTML and decode
                $stateToken = ($responseStep52.Content | Select-String -Pattern '"stateToken":"(.*?)"' | ForEach-Object { $_.Matches.Groups[1].Value })
                $stateToken = $stateToken -replace '\\x2D', '-'
                "[{0}] Decoded stateToken: '{1}...{2}'" -f $functionName, $stateToken.Substring(0, 1), $stateToken.Substring($stateToken.Length - 1, 1) | Write-Verbose
                if (-not $stateToken) {
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    "[{0}] Failed to extract stateToken from the response." -f $functionName | Write-Verbose
                    throw "Authentication failed: Could not extract stateToken from the SAML response."

                }
                # Extract oktaData using regex
                $oktaDataMatch = [regex]::Match($responseStep52, 'var oktaData = ({[\s\S]*?});')
                
                # "[{0}] SAML2 okta DataMatch: '{1}'" -f $functionName, $oktaDataMatch | Write-Verbose
                
                if ($oktaDataMatch.Success) {
                    $oktaDataString = $oktaDataMatch.Groups[1].Value
                
                    try {
                        # Clean up the matched oktaData string using .NET Regex to decode \xNN sequences
                        $oktaDataString = [System.Text.RegularExpressions.Regex]::Replace(
                            $oktaDataString,
                            '\\x([0-9A-Fa-f]{2})',
                            { param($match) [char][Convert]::ToInt32($match.Groups[1].Value, 16) }
                        )
                
                        # Remove invalid JavaScript function definitions
                        $oktaDataString = $oktaDataString -replace '"consent":{"cancel":function\s*\(\)\s*{[^}]*}}', '"consent":{"cancel":""}'
                
                        # Parse JSON into a PowerShell object
                        $oktaData = $oktaDataString | ConvertFrom-Json
                
                        "[{0}] Extracted oktaData: `n{1}" -f $functionName, $oktaData | Write-Verbose
                                                                        
                        $baseUrl = [System.Web.HttpUtility]::HtmlDecode($oktaData.signIn.baseUrl)
                        "[{0}] Extracted baseUrl: '{1}'" -f $functionName, $baseUrl | Write-Verbose
                
                    }
                    catch {
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        "[{0}] Failed to extract oktaData from the response." -f $functionName | Write-Verbose
                        throw "Authentication failed: Could not parse oktaData from the SAML response. {1}" -f $_.Exception.Message
                    }
                }
                else {
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    "[{0}] No oktaData found in the response." -f $functionName | Write-Verbose
                    throw "Authentication failed: Could not find oktaData in the SAML response."
                }
                            
                $CompletedSteps++

                #EndRegion [STEP 5.2] SAML Authentication Request Submission

                #Region [STEP 5.3]: Authentication State Introspection (POST https://mylogin.hpe.com/idp/idx/introspect)
                Write-Verbose " ----------------------------------STEP 5.3--------------------------------------------------------------------------------"        
                Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Authentication State Introspection" -Id 0
                $step++
                "[{0}] Step 5.3: POST https://mylogin.hpe.com/idp/idx/introspect" -f $functionName | Write-Verbose
                
                $url = $baseUrl + "/idp/idx/introspect"
                $method = "POST"
                            
                "[{0}] About to execute {1} request to: '{2}'" -f $functionName, $method, $url | Write-Verbose
                
                
                # Define the payload
                $payload = @{
                    stateToken = $stateToken
                } | ConvertTo-Json -Depth 10
                
                # Define the headers
                $headers = @{
                    "Content-Type" = "application/json"
                }
                                    
                # Hide stateToken value in logs for security
                $payloadLog = $payload
                if ($payloadLog -match '"stateToken"\s*:\s*"[^"]+"') {
                    $payloadLog = $payloadLog -replace '("stateToken"\s*:\s*")([^"]+)(")', '$1[REDACTED]$3'
                }
                "[{0}] Payload content: `n{1}" -f $functionName, ($payloadLog | out-string) | Write-Verbose
                
                try {
                    $responseStep53 = Invoke-RestMethod -Uri $url -Method $Method -ErrorAction Stop -Headers $headers -Body $payload -WebSession $Session
                                
                    "[{0}] SAML2 IDP response received successfully." -f $functionName | Write-Verbose
                    # "[{0}] Raw response for `$responseStep53: `n{1}" -f $functionName, ($responseStep53 | ConvertTo-Json -d 10) | Write-verbose
                    "[{0}] Response: remediation = {1}" -f $functionName, ($responseStep53.remediation.value[0].name) | Write-verbose
                    # Log-Cookies -Domain "https://mylogin.hpe.com" -Session $session -Step "Step 5.3 (POST /idp/idx/introspect)"
                }
                catch {
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    "[{0}] SAML2 IDP response failed to validate the authentication state. Please verify the state token and try again." -f $functionName | Write-Verbose
                    throw "Authentication failed: Could not validate the authentication state. {1}" -f $_.Exception.Message
                }               
                        
                $RemediationValues = $responseStep53.remediation.value | Redact-StateHandle
                "[{0}] Remediation values: `n{1}" -f $functionName, ($RemediationValues | ConvertTo-Json -Depth 10) | Write-Verbose

                # Capturing challengeHref, authenticatorId, methodType, and stateHandle from $responseStep53
                $stateHandle = $responseStep53.stateHandle
                "[{0}] Extracted stateHandle: {1}...{2}" -f $functionName, $stateHandle.Substring(0, 1), $stateHandle.Substring($stateHandle.Length - 1, 1) | Write-Verbose
            
                $challengeHref = $responseStep53.remediation.value | Where-Object { $_.name -eq 'select-authenticator-authenticate' } | Select-Object -ExpandProperty href
                "[{0}] Extracted challengeHref: '{1}'" -f $functionName, $challengeHref | Write-Verbose

                $OktaVerify = ($responseStep53.remediation.value | Where-Object { $_.name -eq 'select-authenticator-authenticate' }).value | Where-Object { $_.name -eq 'authenticator' } | Select-Object -ExpandProperty options | Where-Object { $_.label -eq 'Okta Verify' }
                                    
                if (-not $OktaVerify) {
                    "[{0}] ERROR: Okta Verify authenticator not found" -f $functionName | Write-Verbose
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "Authentication failed: Okta Verify authenticator not found in response"
                }
                "[{0}] Found Okta Verify authenticator" -f $functionName | Write-Verbose

                # Get authenticatorId for Okta Verify 
                $authenticatorId = ($OktaVerify.value.form.value | Where-Object { $_.name -eq "id" }).value
                if (-not $authenticatorId) {
                    "[{0}] ERROR: authenticatorId not found for Okta Verify" -f $functionName | Write-Verbose
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "Authentication failed: AuthenticatorId not found"
                }
                "[{0}] Extracted authenticatorId: {1}" -f $functionName, $authenticatorId | Write-Verbose

                # Get available methodType options
                $methodOptions = ($OktaVerify.value.form.value | Where-Object { $_.name -eq "methodType" }).options
                if (-not $methodOptions) {
                    "[{0}] ERROR: No methodType options found for Okta Verify" -f $functionName | Write-Verbose
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "Authentication failed: No methodType options found for Okta Verify"
                }
                "[{0}] Available methodTypes: {1}" -f $functionName, ($methodOptions.value -join ", ") | Write-Verbose

                # Select method: prefer push, fallback to totp
                $methodType = $null
                $pushOption = $methodOptions | Where-Object { $_.value -eq "push" }
                $totpOption = $methodOptions | Where-Object { $_.value -eq "totp" }

                if ($pushOption) {
                    $methodType = "push"
                    "[{0}] Selected methodType: push" -f $functionName | Write-Verbose
                }
                elseif ($totpOption) {
                    $methodType = "totp"
                    "[{0}] Push not available, selected methodType: totp" -f $functionName | Write-Verbose
                }
                else {
                    "[{0}] ERROR: Neither push nor totp available for Okta Verify" -f $functionName | Write-Verbose
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "Authentication failed: Neither push nor totp available for Okta Verify"
                }
            
                $CompletedSteps++

                #EndRegion [STEP 5.3] Authentication State Introspection

                #Region [STEP 5.4]: Send Okta Verify Authenticator Request: POST request to 'https://mylogin.hpe.com/idp/idx/challenge'
                Write-Verbose " ----------------------------------STEP 5.4--------------------------------------------------------------------------------"       
                Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Send Okta Verify Authenticator Request" -Id 0
                $step++
                "[{0}] Step 5.4: POST 'https://mylogin.hpe.com/idp/idx/challenge' to initiate Okta Verify {2}" -f $functionName, $challengeHref, $methodType | Write-Verbose

                $method = "POST"
                            
                "[{0}] About to execute {1} request to: '{2}'" -f $functionName, $method, $challengeHref | Write-Verbose
                
                # Define the payload
                $payload = @{
                    stateHandle   = $stateHandle
                    authenticator = @{
                        id         = $authenticatorId
                        methodType = $methodType
                    }
                } | ConvertTo-Json -Depth 10
                
                # Define the headers
                $headers = @{
                    "Content-Type" = "application/json"
                }
                                    
                # Hide stateHandle value in logs for security
                $payloadLog = $payload
                if ($payloadLog -match '"stateHandle"\s*:\s*"[^"]+"') {
                    $payloadLog = $payloadLog -replace '("stateHandle"\s*:\s*")([^"]+)(")', '$1[REDACTED]$3'
                }
                "[{0}] Payload content: `n{1}" -f $functionName, ($payloadLog | out-string) | Write-Verbose
                
                try {
                    $responseStep54 = Invoke-RestMethod -Uri $challengeHref -Method $Method -ErrorAction Stop -Headers $headers -Body $payload -WebSession $Session                
                    "[{0}] Okta Verify push notification sent successfully." -f $functionName | Write-Verbose
                    # Redact stateHandle before verbose output
                    $responseStep54Redacted = Redact-StateHandle $responseStep54
                    "[{0}] Raw response for `$responseStep54: `n{1}" -f $functionName, ($responseStep54Redacted | ConvertTo-Json -Depth 50) | Write-Verbose
                    # Log-Cookies -Domain "https://mylogin.hpe.com" -Session $session -Step "Step 5.4 (POST /idp/idx/challenge)"
                }
                catch {
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    "[{0}] Failed to send Okta Verify push notification. Please verify your email and try again." -f $functionName | Write-Verbose
                    throw "Authentication failed: Could not send Okta Verify push notification. {1}" -f $_.Exception.Message
                }
                
                # Capturing stateHandle, pollHref (for push), verifyHref (for totp), and correctAnswer (for push number challenge)
                $stateHandle = $responseStep54.stateHandle
                # "[{0}] Extracted stateHandle: {1}" -f $functionName, $stateHandle | Write-Verbose

                if (-not $stateHandle) {
                    Write-Verbose "[${functionName}] Failed to get stateHandle from introspect response"
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "Authentication failed: Could not extract stateHandle from introspect response."
                }

                # Validate stateHandle format (allow ~ in addition to alphanumeric, ., _, and -)
                if ($stateHandle -notmatch "^[a-zA-Z0-9._~-]+$") {
                    Write-Verbose "[${functionName}] Invalid stateHandle format: $stateHandle"
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "Authentication failed: Invalid stateHandle format."
                }

                if ($methodType -eq "push") {
                    $pollHref = $responseStep54.remediation.value | Where-Object { $_.name -eq 'challenge-poll' } | Select-Object -ExpandProperty href
                    if (-not $pollHref) {
                        "[{0}] ERROR: No pollHref found for push authentication" -f $functionName | Write-Verbose
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        throw "Authentication failed: No pollHref found in response for push authentication"
                    }
                    "[{0}] Extracted pollHref: '{1}'" -f $functionName, $pollHref | Write-Verbose

                    $correctAnswer = $responseStep54.currentAuthenticator.value.contextualData.correctAnswer
                    if ($correctAnswer) {
                        "[{0}] Extracted correctAnswer: {1}" -f $functionName, $correctAnswer | Write-Verbose
                    }
                    else {
                        "[{0}] No correctAnswer found (number challenge not required)" -f $functionName | Write-Verbose
                    }
                }
                elseif ($methodType -eq "totp") {
                    # Try to get verifyHref from remediation (e.g., challenge-authenticator)
                    $verifyHref = $responseStep54.remediation.value | Where-Object { $_.name -eq 'challenge-authenticator' } | Select-Object -ExpandProperty href
                    if (-not $verifyHref) {
                        # Fallback to challengeHref
                        $verifyHref = $challengeHref
                        "[{0}] No verifyHref found in response, falling back to challengeHref: '{1}'" -f $functionName, $verifyHref | Write-Verbose
                    }
                    else {
                        "[{0}] Extracted verifyHref: '{1}'" -f $functionName, $verifyHref | Write-Verbose
                    }
                }
                        
                $CompletedSteps++

                #EndRegion [STEP 5.4] Send Okta Verify Authenticator Request

                #Region [STEP 5.5]: Verify Okta Verify Status: Handle Push or TOTP
                Write-Verbose " ----------------------------------STEP 5.5--------------------------------------------------------------------------------"       
                Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Verify Okta Verify Status" -Id 0
                $step++
                Write-Verbose ("[{0}] Step 5.5: GET 'https://mylogin.hpe.com/idp/idx/authenticators/poll' to verify Okta Verify {1} status" -f $functionName, $methodType)

                # $methodType ("push" or "totp") comes from Step 5.3
                # $pollHref (push) or $verifyHref (totp) comes from Step 5.4
                # $challengeHref (from Step 5.3) is fallback for TOTP

                if ($methodType -eq "push") {
                    # Handle Push Notification
                    Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Check your phone for an Okta Verify push notification from HPE GreenLake" -Id 0
                            
                    Start-Sleep -Milliseconds 500
                    # Start-Sleep -Seconds 1
                    $completedSteps++
                    if ($correctAnswer) {
                        Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Respond '$correctAnswer' to the Okta Verify notification." -Id 0
                    }
                    else {
                        Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Approve the Okta Verify push notification." -Id 0
                    }

                    if (-not $pollHref) {
                        "[{0}] ERROR: No poll URL found for push authentication" -f $functionName | Write-Verbose
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        throw "Authentication failed: No poll URL provided for push authentication."
                    }

                    $timeout = [datetime]::Now.AddMinutes(2)
                            
                    "[{0}] About to execute POST request to: '{1}'" -f $functionName, $pollHref | Write-Verbose

                    $payload = @{
                        stateHandle = $stateHandle
                    } | ConvertTo-Json
                            
                    # Hide stateHandle value in logs for security
                    $payloadLog = $payload
                    if ($payloadLog -match '"stateHandle"\s*:\s*"[^"]+"') {
                        $payloadLog = $payloadLog -replace '("stateHandle"\s*:\s*")([^"]+)(")', '$1[REDACTED]$3'
                    }
                    "[{0}] Payload content: `n{1}" -f $functionName, $payloadLog | Write-Verbose

                    do {
                        try {
                            $responseStep55 = Invoke-RestMethod -Uri $pollHref -Method POST -Body $payload -ContentType 'application/json' -ErrorAction Stop -WebSession $session
                            # "[{0}] Okta Verify push notification poll response received." -f $functionName | Write-Verbose
                        }
                        catch {
                            if (-not $NoProgress) {
                                Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                            }
                            "[{0}] Failed to poll Okta Verify push status: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                            throw "Authentication failed: Unable to poll Okta Verify push status. {1}" -f $_.Exception.Message
                        }

                        if ([datetime]::Now -ge $timeout) {
                            if (-not $NoProgress) {
                                Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                            }
                            throw "Authentication failed: Timeout error! Okta Verify push verification did not succeed within 2 minutes."
                        }

                        Start-Sleep -Seconds 3

                    } until ( $responseStep55.success.name -eq "success-redirect" -or ($responseStep55.messages -and $responseStep55.messages.value -and $responseStep55.messages.value[0] -and $responseStep55.messages.value[0].class -eq "ERROR") )

                    if ($responseStep55.success.name -eq "success-redirect") {
                        "[{0}] Verification via Okta Verify push notification completed successfully." -f $functionName | Write-Verbose                       
                    }
                    elseif ($responseStep55.messages.value[0].class -eq "ERROR") {
                        "[{0}] Verification via Okta Verify push notification failed." -f $functionName | Write-Verbose
                        "[{0}] Error message: {1}" -f $functionName, $responseStep55.messages.value[0].message | Write-Verbose
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        throw "Authentication failed: Unable to verify the status of the Okta Verify push notification. The notification was either rejected or an incorrect verification number was selected."
                    }
                }
                elseif ($methodType -eq "totp") {
                    # Handle TOTP
                    Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Open Okta Verify and enter the 6-digit code" -Id 0
                    Start-Sleep -Seconds 2
                    $completedSteps++
                    Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Waiting for Okta Verify code input" -Id 0

                    # Use $verifyHref from Step 4.4, fallback to $challengeHref
                    $verifyHref = if ($verifyHref) { $verifyHref } else { $challengeHref }
                    if (-not $verifyHref) {
                        "[{0}] ERROR: No verify URL available for TOTP (neither verifyHref nor challengeHref provided)" -f $functionName | Write-Verbose
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        throw "Authentication failed: No verify URL available for TOTP authentication. Check Step 4.4 and 4.3 responses."
                    }

                    "[{0}] Prompting user for Okta Verify TOTP code" -f $functionName | Write-Verbose
                    $baseurlofVerifyHref = ($verifyHref -split '/')[2]
                    Write-Host "Please open Okta Verify and enter the 6-digit code of '$baseurlofVerifyHref' for '$UserName'"
                    $totpCode = Read-Host "Enter Okta Verify code"
                    
                    if ($totpCode -notmatch '^\d{6}$') {
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        "[{0}] ERROR: Invalid TOTP code. Must be a 6-digit number." -f $functionName | Write-Verbose
                        throw "Authentication failed: Invalid TOTP code. Must be a 6-digit number."
                    }
                    
                    $payload = @{
                        stateHandle = $stateHandle
                        credentials = @{
                            totp = $totpCode
                        }
                    } | ConvertTo-Json
                    
                    "[{0}] About to execute POST request to: '{1}'" -f $functionName, $verifyHref | Write-Verbose
                    # Hide stateHandle value in logs for security
                    $payloadLog = $payload
                    if ($payloadLog -match '"stateHandle"\s*:\s*"[^"]+"') {
                        $payloadLog = $payloadLog -replace '("stateHandle"\s*:\s*")([^"]+)(")', '$1[REDACTED]$3'
                    }
                    "[{0}] Payload content: `n{1}" -f $functionName, $payloadLog | Write-Verbose

                    try {
                        $responseStep55 = Invoke-RestMethod -Uri $verifyHref -Method POST -Body $payload -ContentType 'application/json' -ErrorAction Stop -WebSession $session
                        "[{0}] Okta Verify TOTP code submitted successfully. Response: `n{1}" -f $functionName, ($responseStep55 | ConvertTo-Json -Depth 50) | Write-Verbose
                        "[{0}] Okta Verify TOTP verification response received." -f $functionName | Write-Verbose
                    }
                    catch {
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        "[{0}] Failed to verify Okta Verify TOTP code: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                        throw "Authentication failed: Unable to verify the Okta Verify TOTP code. {1}" -f $_.Exception.Message
                    }

                    if ($responseStep55.success.name -eq "success-redirect") {
                        "[{0}] Verification via Okta Verify TOTP completed successfully." -f $functionName | Write-Verbose
                    }
                    elseif ($responseStep55.messages -and $responseStep55.messages.value -and $responseStep55.messages.value[0].class -eq "ERROR") {
                        "[{0}] Verification via Okta Verify TOTP failed." -f $functionName | Write-Verbose
                        "[{0}] Error message: {1}" -f $functionName, $responseStep55.messages.value[0].message | Write-Verbose
                        
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        throw "Authentication failed: Unable to verify the Okta Verify TOTP code. The code was incorrect or expired."
                    }
                }

                # "[{0}] Raw response for `$responseStep55`: `n{1}" -f $functionName, ($responseStep55 | ConvertTo-Json -Depth 50) | Write-Verbose
                        
                # After success (push or TOTP), perform a final introspect to confirm overall state
                "[{0}] Performing final introspect to confirm overall authentication state and capture cookies (POST https://mylogin.hpe.com/idp/idx/introspect)" -f $functionName | Write-Verbose
                $body = @{ stateToken = $stateToken } | ConvertTo-Json

                try {
                    
                    $response = Invoke-WebRequest -Uri "https://mylogin.hpe.com/idp/idx/introspect" -Method POST -Body $body -Headers $introspectHeaders -WebSession $session -ErrorAction Stop
                    $finalIntrospectData = $response.Content | ConvertFrom-Json
                    "[{0}] Final introspect response: `n{1}" -f $functionName, ( $response.Content | ConvertFrom-Json | Redact-StateHandle | ConvertTo-Json -Depth 50 ) | Write-Verbose
                        
                    # Store the response in $global:introspectResponse
                    $global:introspectResponse = $response.Content | ConvertFrom-Json
                    $global:stateToken = $global:introspectResponse.stateHandle
                    $global:redirectUrl = $global:introspectResponse.success.href
            
                    # Log-Cookies -Domain "https://mylogin.hpe.com" -Session $session -Step "Step 5.5 (Final POST /idp/idx/introspect)"
            
                    "[{0}] SSO complete. Final status: SUCCESS" -f $functionName | Write-Verbose
                    "[{0}] Retrieving user details for the current session" -f $functionName | Write-Verbose
                            
                    # Capture user details
                    $Name = $($global:introspectResponse.user.value.profile.firstName) + " " + ($global:introspectResponse.user.value.profile.lastName)
                    "[{0}] User name to save to the current session object: {1}" -f $functionName, ($Name) | Write-Verbose
                }
                catch {
                    "[{0}] Introspect POST failed: {1}" -f $functionName, $_.ErrorDetails.Message | Write-Verbose
                    $errorResponse = $_.ErrorDetails.Message | ConvertFrom-Json -ErrorAction SilentlyContinue
                    if ($errorResponse.messages.value.Count -gt 0 -and $errorResponse.messages.value[0].i18n.key -eq "idx.session.expired") {
                        "[{0}] Session expired. Attempting to retry the introspect request with the new stateToken." -f $functionName | Write-Verbose
                        # Retry the introspect request with the new stateToken
                        $introspectBody = @{ stateHandle = $global:stateToken } | ConvertTo-Json
                        $response = Invoke-WebRequest -Uri "https://mylogin.hpe.com/idp/idx/introspect" -Method POST -Body $introspectBody -Headers $introspectHeaders -WebSession $webSession -UseBasicParsing
                        $global:introspectResponse = $response.Content | ConvertFrom-Json
                    }
                    else {
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        throw "Authentication failed: Introspect POST failed with unexpected error: $($_.Exception.Message)"
                    }
                }

                if ($finalIntrospectData.success.name -ne "success-redirect") {
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "Authentication failed: Final introspect failed: $($finalIntrospectData.status)"
                }
                        
                $redirectUrl = $finalIntrospectData.success.href
                # Hide stateToken value in logs for security
                $redirectUrlLog = $redirectUrl
                if ($redirectUrlLog -match 'stateToken=[^&]+') {
                    $redirectUrlLog = $redirectUrlLog -replace '(stateToken=)[^&]+', '$1[REDACTED]'
                }
                "[{0}] Redirect URL: {1}" -f $functionName, $redirectUrlLog | Write-Verbose
                # Update stateHandle if new one is returned
                if ($finalIntrospectData.stateHandle) {
                    $stateHandle = $finalIntrospectData.stateHandle
                }

                $completedSteps++


                #EndRegion [STEP 5.5] Verify Okta Verify Status

                #Region [STEP 5.6]: Acquire SAML response: GET request to 'https://mylogin.hpe.com/login/token/redirect?stateToken=...'
                Write-Verbose " ----------------------------------STEP 5.6--------------------------------------------------------------------------------"        
                Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Acquire SAML response" -Id 0
                $step++
                # Hide stateToken value in logs for security
                $redirectUrlLog = $global:redirectUrl
                if ($redirectUrlLog -match 'stateToken=[^&]+') {
                    $redirectUrlLog = $redirectUrlLog -replace '(stateToken=)[^&]+', '$1[REDACTED]'
                }
                Write-Verbose ("[{0}] Step 5.6: GET '{1}' to acquire SAMLResponse" -f $functionName, $redirectUrlLog)

                "[{0}] About to GET SAMLResponse from: '{1}'" -f $functionName, $redirectUrlLog | Write-Verbose

                # Log-Cookies -Domain "https://mylogin.hpe.com" -Session $session -Step "Before Step 5.6 (GET SAMLResponse)"

                $responseStep56 = Invoke-WebRequest -Uri $redirectUrl -Method GET -ErrorAction Stop -WebSession $session   
                "[{0}] SAML response acquired successfully." -f $functionName | Write-Verbose
                # Extract and display only the </script><form id="appForm" ... section from the HTML content
                $formSection = ($responseStep56.Content -join "`n") -match '(<form id="appForm"[\s\S]+?</form>)' | Out-Null
                $formSection = $matches[1]
                # Hide sensitive values in logs (RelayState, SAMLResponse)
                $formSectionRedacted = $formSection
                $formSectionRedacted = $formSectionRedacted -replace '(name="RelayState" type="hidden" value=")[^"]+(")', '$1[REDACTED]$2'
                $formSectionRedacted = $formSectionRedacted -replace '(name="SAMLResponse" type="hidden" value=")[^"]+(")', '$1[REDACTED]$2'
                "[{0}] Extracted script from SAML section:`n{1}" -f $functionName, $formSectionRedacted | Write-Verbose
                
                # Log cookies set by the response
                # Log-Cookies -Domain "https://mylogin.hpe.com" -Session $session -Step "After Step 5.6 (GET SAMLResponse)"
                
                # Extract actionUrl
                $encodedString = ($responseStep56.Content | Select-String -Pattern 'action="(.*?)"' | ForEach-Object { $_.Matches.Groups[1].Value } | Select-Object -First 1)
                if (-not $encodedString) {
                    "[{0}] ERROR: No action URL found in response!" -f $functionName | Write-Verbose
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "Authentication failed: Action URL not found"
                }
                $actionUrl = [System.Web.HttpUtility]::HtmlDecode($encodedString)
                "[{0}] Decoded actionUrl: '{1}'" -f $functionName, $actionUrl | Write-Verbose

                # Extract method for actionUrl (POST or GET)
                $method = ($responseStep56.Content | Select-String -Pattern 'method="(POST|GET)"' | ForEach-Object { $_.Matches.Groups[1].Value } | Select-Object -First 1)
                if (-not $method) {
                    "[{0}] ERROR: No form method found in response! Defaulting to POST." -f $functionName | Write-Verbose
                    $method = "POST"
                }
                "[{0}] Extracted form method: '{1}'" -f $functionName, $method | Write-Verbose

                # Extract RelayState
                $encodedRelayState = ($responseStep56.Content -join "`n" | Select-String -Pattern 'name="RelayState" type="hidden" value="([^"]+)"' -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value } | Select-Object -First 1
                if (-not $encodedRelayState) {
                    "[{0}] ERROR: No RelayState found in response!" -f $functionName | Write-Verbose
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }                            
                    throw "Authentication failed: RelayState not found"
                }
                $RelayState = [System.Web.HttpUtility]::HtmlDecode($encodedRelayState)
                $encodedRelayState = [System.Web.HttpUtility]::UrlEncode($RelayState)
                # Hide okta_key value in logs for security
                $RelayStateLog = $RelayState
                if ($RelayStateLog -match 'okta_key=[^&]+') {
                    $RelayStateLog = $RelayStateLog -replace '(okta_key=)[^&]+', '$1[REDACTED]'
                }
                "[{0}] Extracted RelayState: '{1}'" -f $functionName, $RelayStateLog | Write-Verbose
                # "[{0}] Encoded RelayState: '{1}'" -f $functionName, $encodedRelayState | Write-Verbose
            
                # Extract the SAMLResponse value
                $encodedSAMLResponse = ($responseStep56.Content -join "`n" | Select-String -Pattern 'name="SAMLResponse" type="hidden" value="([^"]+)"' -AllMatches).Matches | ForEach-Object { $_.Groups[1].Value }
                # "[{0}] Extracted Encoded SAMLResponse: `n{1}" -f $functionName, $encodedSAMLResponse | Write-Verbose

                $SAMLResponse = [System.Web.HttpUtility]::HtmlDecode($encodedSAMLResponse)
                # "[{0}] Extracted Decoded SAMLResponse: `n{1}" -f $functionName, $SAMLResponse | Write-Verbose
                $completedSteps++
                

                #EndRegion [STEP 5.6] Acquire SAML response

                #Region [STEP 5.7]: POST SAMLResponse to 'https://auth.hpe.com/sso/saml2/0oaxkzvt641W1SCSY357'
                Write-Verbose " ----------------------------------STEP 5.7--------------------------------------------------------------------------------"
                Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Acquire SAML response" -Id 0
                $step++
                "[{0}] Step 5.7 - About to POST SAMLResponse to: 'https://auth.hpe.com/sso/saml2/0oaxkzvt641W1SCSY357'" -f $functionName | Write-Verbose
                "[{0}] Skipping session refresh GET as it returns an HTML page requiring JavaScript" -f $functionName | Write-Verbose

                # Proceed with SAML POST
                "[{0}] Posting SAMLResponse to: {1}" -f $functionName, $actionUrl | Write-Verbose
                $encodedRelayState = [System.Web.HttpUtility]::UrlEncode($RelayState)        
                $samlBody = "SAMLResponse=$([System.Web.HttpUtility]::UrlEncode($samlResponse))&RelayState=$encodedRelayState"        
                # Redact SAMLResponse and RelayState before verbose output
                $samlBodyRedacted = $samlBody -replace '(SAMLResponse=)[^&]+', '$1[REDACTED]' -replace '(RelayState=)[^&]+', '$1[REDACTED]'
                "[{0}] SAML POST body: `n{1}" -f $functionName, $samlBodyRedacted | Write-Verbose
                
                # Log cookies before SAML POST
                # Log-Cookies -Domain "https://mylogin.hpe.com" -Session $session -Step "Before Step 5.7 (POST SAMLResponse)"

                try {
                    $finalResponse = Invoke-WebRequest -Uri $actionUrl -Method Post -Body $samlBody -ContentType "application/x-www-form-urlencoded" -WebSession $session -ErrorAction Stop
                    "[{0}] SAML POST response status: {1}" -f $functionName, $finalResponse.StatusCode | Write-Verbose
                    
                    # # Expose the full response content for debugging
                    # $finalResponse.Content | Out-File -FilePath ".\hpe_saml_post_success_response.html" -Encoding utf8
                    # "[{0}] SAML POST success response saved to .\hpe_saml_post_success_response.html" -f $functionName | Write-Verbose
                }
                catch {
                    "[{0}] SAML POST failed: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                    if ($_.Exception.Response) {
                        $errorResponse = $_.Exception.Response.GetResponseStream()
                        $reader = New-Object System.IO.StreamReader($errorResponse)
                        $responseBody = $reader.ReadToEnd()
                        "[{0}] SAML POST error response body: `n{1}" -f $functionName, $responseBody | Write-Verbose
                        # Save the error response to a file for further analysis
                        # $responseBody | Out-File -FilePath ".\hpe_saml_post_error_response.html" -Encoding utf8
                        # "[{0}] SAML POST error response saved to .\hpe_saml_post_error_response.html" -f $functionName | Write-Verbose
                    }
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "Authentication failed: SAML POST failed with error: $($_.Exception.Message)"
                }

                # Extract stateToken from HTML (example regex)
                $stateToken = [regex]::Match($finalResponse.Content, '"stateToken"\s*:\s*"([^"]+)"').Groups[1].Value
                "[{0}] Extracted stateToken: {1}...{2}" -f $functionName, $stateToken.Substring(0, 1), $stateToken.Substring($stateToken.Length - 1, 1) | Write-Verbose

                #EndRegion [STEP 5.7] POST SAMLResponse

                #Region [STEP 5.8]: Post to introspect to exchange stateToken for authorization code (POST https://auth.hpe.com/idp/idx/introspect)
                Write-Verbose " ----------------------------------STEP 5.8--------------------------------------------------------------------------------"
                "[{0}] Step 5.8 - Exchanging stateToken for authorization code" -f $functionName | Write-Verbose
                $introspectUrl = "https://auth.hpe.com/idp/idx/introspect"

                "[{0}] Raw stateToken value (before JSON): '{1}...{2}'" -f $functionName, $stateToken.Substring(0, 1), $stateToken.Substring($stateToken.Length - 1, 1) | Write-Verbose

                # Manually construct JSON to avoid serialization issues with backslash
                $processedStateToken = $stateToken -replace '\\x2D', '-'
                $body = "{`"stateToken`":`"$processedStateToken`"}"

                "[{0}] About to make a POST {1}" -f $functionName, $introspectUrl | Write-Verbose
                # Hide stateToken value in logs for security
                $bodyLog = $body
                if ($bodyLog -match '"stateToken"\s*:\s*"[^"]+"') {
                    $bodyLog = $bodyLog -replace '("stateToken"\s*:\s*")([^"]+)(")', '$1[REDACTED]$3'
                }
                "[{0}] Introspect POST Body: `n{1}" -f $functionName, $bodyLog | Write-Verbose

                $response = Invoke-WebRequest -Uri $introspectUrl -Method POST -Body $body -ContentType "application/json" -WebSession $session
                "[{0}] Introspect response status: {1}" -f $functionName, $response.StatusCode | Write-Verbose
                $introspectResult = $response.Content | ConvertFrom-Json
                "[{0}] Introspect response content: `n{1}" -f $functionName, (Redact-StateHandle ($introspectResult) | ConvertTo-Json -Depth 20) | Write-Verbose

                if ($introspectResult.success) {
                    $redirectUrl1 = $introspectResult.success.href
                    # Remove stateToken from the redirect URL for logging
                    $redirectUrlLog = $redirectUrl1
                    if ($redirectUrlLog -match 'stateToken=[^&]+') {
                        $redirectUrlLog = $redirectUrlLog -replace '(stateToken=)[^&]+', '$1[REDACTED]'
                    }
                    "[{0}] Redirect URL from introspect: {1}" -f $functionName, $redirectUrlLog | Write-Verbose
                }
                else {
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "Authentication failed: Introspect did not return a success href. Response: $($response.Content)"
                }

                #endregion [STEP 5.8] Post to introspect to exchange stateToken for authorization code

                #Region [STEP 5.9]: Follow redirect to get authorization code (GET $redirectUrl1)
                Write-Verbose " ----------------------------------STEP 5.9--------------------------------------------------------------------------------"
                "[{0}] Step 5.9 - Following redirects to get authorization code" -f $functionName | Write-Verbose
                # Remove stateToken from the redirect URL for logging
                $redirectUrlLog = $redirectUrl1
                if ($redirectUrlLog -match 'stateToken=[^&]+') {
                    $redirectUrlLog = $redirectUrlLog -replace '(stateToken=)[^&]+', '$1[REDACTED]'
                }
                "[{0}] About to make a GET {1}" -f $functionName, $redirectUrlLog | Write-Verbose
                
                # Generalized redirect chain: follow up to 5 redirects, capturing the final URL
                $maxRedirects = 5
                $authCode = $null
                $finalUrl = $redirectUrl1

                for ($i = 1; $i -le $maxRedirects; $i++) {
                    "[{0}] ------------------------------------- Redirection {1} -------------------------------------" -f $functionName, $i | Write-Verbose
                    # Hide stateToken and code values in logs for security
                    $finalUrlLog = $finalUrl
                    if ($finalUrlLog -match 'stateToken=[^&]+') {
                        $finalUrlLog = $finalUrlLog -replace '(stateToken=)[^&]+', '$1[REDACTED]'
                    }
                    if ($finalUrlLog -match 'state=[^&]+') {
                        $finalUrlLog = $finalUrlLog -replace '(state=)[^&]+', '$1[REDACTED]'
                    }
                    if ($finalUrlLog -match 'code=[^&]+') {
                        $finalUrlLog = $finalUrlLog -replace '(code=)[^&]+', '$1[REDACTED]'
                    }
                    "[{0}] About to execute GET request to: '{1}'" -f $functionName, $finalUrlLog | Write-Verbose

                    try {
                        $resp = Invoke-WebRequest -Uri $finalUrl -WebSession $session -MaximumRedirection 0 -ErrorAction Stop
                        "[{0}] Response StatusCode: {1}" -f $functionName, $resp.StatusCode | Write-Verbose
                        "[{0}] Response Headers: {1}" -f $functionName, ($resp.Headers | Out-String) | Write-Verbose
                        # Log-Cookies -Domain $finalUrl -Session $session -Step "After redirect $i"
                        break
                    }
                    catch {
                        $location = $null
                        if ($_.Exception.Response -and $_.Exception.Response.Headers["Location"]) {
                            $location = $_.Exception.Response.Headers["Location"]
                        }
                        elseif ($_.Exception.Response -and $_.Exception.Response.Headers.GetValues) {
                            try {
                                $location = $_.Exception.Response.Headers.GetValues("Location")[0]
                            }
                            catch {}
                        }
            
                        if ($location) {
                            # Hide stateToken and code values in logs for security
                            $locationLog = $location
                            if ($locationLog -match 'stateToken=[^&]+') {
                                $locationLog = $locationLog -replace '(stateToken=)[^&]+', '$1[REDACTED]'
                            }
                            if ($locationLog -match 'code=[^&]+') {
                                $locationLog = $locationLog -replace '(code=)[^&]+', '$1[REDACTED]'
                            }
                            if ($locationLog -match 'state=[^&]+') {
                                $locationLog = $locationLog -replace '(state=)[^&]+', '$1[REDACTED]'
                            }
                            "[{0}] Redirected to: {1}" -f $functionName, $locationLog | Write-Verbose
                            $finalUrl = $location
                            if ($finalUrl -like "$RedirectUri*") {
                                $finalUrlLog = $finalUrl
                                if ($finalUrlLog -match 'code=[^&]+') {
                                    $finalUrlLog = $finalUrlLog -replace '(code=)[^&]+', '$1[REDACTED]'
                                }
                                "[{0}] Arrived at callback URL: {1}" -f $functionName, $finalUrlLog | Write-Verbose
                                if ($finalUrl -match "code=([^&]+)") {
                                    $authCode = $matches[1]
                                }
                                break
                            }
                        }
                        else {
                            "[{0}] No Location header in redirect response. Stopping redirect chain." -f $functionName | Write-Verbose
                            break
                        }
                    }
                }

                if (-not $authCode) {
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "Authentication failed: Unable to obtain authorization code after submitting credentials."
                } 
                else {
                    "[{0}] Authorization code obtained successfully." -f $functionName | Write-Verbose
                    "[{0}] Authorization code: {1}...{2}" -f $functionName, $authCode.Substring(0, 1), $authCode.Substring($authCode.Length - 1, 1) | Write-Verbose
                }

                $completedSteps++
                #endregion STEP 5.9: End redirect chain to get authorization code

            }
            else {
                
                #region [STEP 5.1]: Register device nonce with Okta (POST /api/v1/internal/device/nonce)

                Write-Verbose " ----------------------------------STEP 5.1--------------------------------------------------------------------------------"
                Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Register device nonce with Okta" -Id 0
                $step++
                "[{0}] POST https://auth.hpe.com/api/v1/internal/device/nonce" -f $functionName | Write-Verbose
                "[{0}] About to execute POST request to: '{1}'" -f $functionName, "https://auth.hpe.com/api/v1/internal/device/nonce" | Write-Verbose
                "[{0}] Payload content: <none>" -f $functionName | Write-Verbose
                Invoke-RestMethod -Uri "https://auth.hpe.com/api/v1/internal/device/nonce" -Method Post -WebSession $session -Headers $headers | Out-Null
                "[{0}] Device nonce response received." -f $functionName | Write-Verbose

                #endregion STEP 5.1: End device nonce registration

                #region [STEP 5.2]: Submit user credentials and follow redirects (POST /idp/idx/challenge/answer) - Authentication method selection (PUSH, TOTP, password...)
                Write-Verbose " ----------------------------------STEP 5.2--------------------------------------------------------------------------------"
                "[{0}] Step 5.2: POST https://auth.hpe.com/idp/idx/challenge/answer" -f $functionName | Write-Verbose
                # Always perform the initial challenge/answer POST
                $challengePayloadObj = @{ credentials = @{ passcode = $decryptPassword }; stateHandle = $stateHandle }
                $challengePayload = $challengePayloadObj | ConvertTo-Json
                "[{0}] About to execute POST request to: '{1}'" -f $functionName, $authenticatorHref | Write-Verbose
                $challengePayloadLog = $challengePayloadObj | ConvertTo-Json -Depth 10
                if ($challengePayloadLog -match '"passcode"\s*:\s*"[^"]+"') {
                    $challengePayloadLog = $challengePayloadLog -replace '("passcode"\s*:\s*")([^"]+)(")', '$1[REDACTED]$3'
                    $challengePayloadLog = $challengePayloadLog -replace '("stateHandle"\s*:\s*")([^"]+)(")', '$1[REDACTED]$3'
                }
                "[{0}] Payload content: `n{1}" -f $functionName, $challengePayloadLog | Write-Verbose

                try {
                    # Use Invoke-WebRequest to capture raw response
                    $response = Invoke-WebRequest -Uri $authenticatorHref -Method Post -Body $challengePayload -ContentType "application/json" -WebSession $session -Headers $headers -ErrorAction Stop
                    $challengeResp = $response.Content | ConvertFrom-Json
                    # Redact stateHandle before verbose output
                    $challengeRespRedacted = Redact-StateHandle $challengeResp
                    # Redact stateToken in success.href if present
                    $challengeRespJson = $challengeRespRedacted | ConvertTo-Json -Depth 20
                    $challengeRespJson = $challengeRespJson -replace '(stateToken=)[^"]+', '${1}[REDACTED]'
                    "[{0}] Challenge response received: `n{1}" -f $functionName, $challengeRespJson | Write-Verbose
                    # Check for errors in the response messages                     
                    if ($challengeResp.messages -and $challengeResp.messages.value) {
                        "[{0}] Authentication failed: Unexpected error in response messages: {1}" -f $functionName, ($challengeResp.messages | ConvertTo-Json -Depth 20) | Write-Verbose
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        throw "Authentication failed: Unexpected error in response messages: $($challengeResp.messages | ConvertTo-Json -Depth 20)"
                    }  

                    # If no errors in messages, assume authentication is successful
                    "[{0}] Authentication successful" -f $functionName | Write-Verbose
                }
                catch {
                    $StatusCode = $_.Exception.Response.StatusCode
                    $StatusError = $_.Exception.Response.StatusDescription
                    "[{0}] Error status code: {1} ({2})" -f $functionName, $StatusCode, $StatusError | Write-Verbose
                    $errorContent = $_.ErrorDetails.Message
                    "[{0}] Raw error content: {1}" -f $functionName, $errorContent | Write-Verbose

                    $errorBody = $null
                    try {
                        if ($errorContent -and $errorContent -is [string] -and $errorContent.Trim()) {
                            $errorBody = $errorContent | ConvertFrom-Json
                            "[{0}] Parsed error response body" -f $functionName | Write-Verbose
                        }
                    }
                    catch {
                        "[{0}] Failed to parse error response: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                    }

                    if ($StatusCode -eq 401) {
                        if ($errorBody -and $errorBody.messages -and $errorBody.messages.value) {
                            foreach ($message in $errorBody.messages.value) {
                                switch ($message.i18n.key) {
                                    "errors.E0000004" {
                                        "[{0}] Detected incorrect password error (errors.E0000004)" -f $functionName | Write-Verbose
                                        if (-not $NoProgress) {
                                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                        }
                                        throw "Authentication failed: Incorrect password. Please verify your credentials and try again."
                                    }
                                    "errors.E0000015" {
                                        "[{0}] Detected insufficient permissions error (errors.E0000015)" -f $functionName | Write-Verbose
                                        if (-not $NoProgress) {
                                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                        }                                        
                                        throw "Authentication failed: Insufficient permissions. Please ensure your account has the necessary access rights."
                                    }
                                    "errors.E0000011" {
                                        "[{0}] Detected invalid token error (errors.E0000011)" -f $functionName | Write-Verbose
                                        if (-not $NoProgress) {
                                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                        }
                                        throw "Authentication failed: Invalid token provided. Please try again or contact your administrator."
                                    }
                                    "errors.E0000064" {
                                        "[{0}] Detected password expired error (errors.E0000064)" -f $functionName | Write-Verbose
                                        if (-not $NoProgress) {
                                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                        }                                        
                                        throw "Authentication failed: Your password has expired. Please reset your password and try again."
                                    }
                                    "errors.E0000207" {
                                        "[{0}] Detected incorrect username or password error (errors.E0000207)" -f $functionName | Write-Verbose
                                        if (-not $NoProgress) {
                                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                        }                                        
                                        throw "Authentication failed: Incorrect username or password. Please verify your credentials and try again."
                                    }
                                    default {
                                        "[{0}] Detected other error: {1} (key={2})" -f $functionName, $message.message, $message.i18n.key | Write-Verbose
                                        if (-not $NoProgress) {
                                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                        }
                                        throw "Authentication failed: $($message.message) (key=$($message.i18n.key))"
                                    }
                                }
                            }
                        }
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }                        
                        throw "Authentication failed: $StatusCode $StatusError (no error details)"
                    }
                    elseif ($StatusCode -eq 403) {
                        if ($errorBody -and $errorBody.messages -and $errorBody.messages.value) {
                            foreach ($message in $errorBody.messages.value) {
                                switch ($message.i18n.key) {
                                    "errors.E0000005" {
                                        "[{0}] Detected invalid session error (errors.E0000005)" -f $functionName | Write-Verbose
                                        if (-not $NoProgress) {
                                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                        }
                                        throw "Authentication failed: Invalid session. Please try logging in again."
                                    }
                                    default {
                                        "[{0}] Detected other error: {1} (key={2})" -f $functionName, $message.message, $message.i18n.key | Write-Verbose
                                        if (-not $NoProgress) {
                                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                        }
                                        throw "Authentication failed: $($message.message) (key=$($message.i18n.key))"
                                    }
                                }
                            }
                        }
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        throw "Authentication failed: $StatusCode $StatusError (no error details)"
                    }
                    elseif ($StatusCode -eq 404) {
                        if ($errorBody -and $errorBody.messages -and $errorBody.messages.value) {
                            foreach ($message in $errorBody.messages.value) {
                                switch ($message.i18n.key) {
                                    "errors.E0000007" {
                                        "[{0}] Detected resource not found error (errors.E0000007)" -f $functionName | Write-Verbose
                                        if (-not $NoProgress) {
                                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                        }
                                        throw "Authentication failed: Resource not found. Please contact your administrator."
                                    }
                                    default {
                                        "[{0}] Detected other error: {1} (key={2})" -f $functionName, $message.message, $message.i18n.key | Write-Verbose
                                        if (-not $NoProgress) {
                                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                        }
                                        throw "Authentication failed: $($message.message) (key=$($message.i18n.key))"
                                    }
                                }
                            }
                        }
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        throw "Authentication failed: $StatusCode $StatusError (no error details)"
                    }

                    # Handle other unexpected errors
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "[{0}] Unexpected error: {1} {2} - {3}" -f $functionName, $StatusCode, $StatusError, $_.Exception.Message
                }

                # Extract user details
                $Name = $($challengeResp.user.value.profile.firstName) + " " + ($challengeResp.user.value.profile.lastName)
                "[{0}] User name to save to the current session object: {1}" -f $functionName, ($Name) | Write-Verbose

                # Authentication without MFA (password only)
                if ($challengeResp.success -and $challengeResp.success.href) {
                    Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Submit user credentials and follow redirects" -Id 0
                    $step++
                    "[{0}] User authenticated without MFA (password only)." -f $functionName | Write-Verbose
                    $href = $challengeResp.success.href
                    # Hide stateToken value in logs for security
                    $hrefLog = $href
                    if ($hrefLog -match 'stateToken=[^&]+') {
                        $hrefLog = $hrefLog -replace '(stateToken=)[^&]+', '$1[REDACTED]'
                    }
                    "[{0}] About to execute GET request to: '{1}'" -f $functionName, $hrefLog | Write-Verbose
                }
                # Enrollment required (user has not finalized MFA enrollment)
                elseif ($challengeResp.remediation.value | Where-Object { $_.name -like '*enroll*' }) {
                    "[{0}] MFA enrollment has been detected. User must log in to the HPE GreenLake GUI and complete the MFA setup using one of the available methods before proceeding with this library" -f $functionName | Write-Verbose
            
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "Connection error! Multi-factor authentication (MFA) enrollment is required. Please log in to the HPE GreenLake GUI and complete the MFA setup using one of the available methods before proceeding with this library."
                }
                # PUSH (Okta Verify) with push notification
                elseif ($preferredAuthenticator -and $preferredAuthenticator.methodType -eq 'push') {
                    "[{0}] Selecting '{1} PUSH' for authentication." -f $functionName, $preferredAuthenticator.name | Write-Verbose
             
                    $challengePayloadObj = @{ 
                        authenticator = @{ 
                            id         = $preferredAuthenticator.auth.id
                            methodType = $preferredAuthenticator.methodType
                        }
                        stateHandle   = $stateHandle
                    }

                    $challengePayload = $challengePayloadObj | ConvertTo-Json

                    # Capture href in remediation where name is select-authenticator-authenticate
                    $href = $challengeResp.remediation.value | Where-Object { $_.name -eq 'select-authenticator-authenticate' } | Select-Object -ExpandProperty href
        
                    "[{0}] About to execute POST request to: '{1}'" -f $functionName, $href | Write-Verbose

                    # Redact stateHandle before verbose output
                    $challengePayloadLogRedacted = ($challengePayload | ConvertFrom-Json | Redact-StateHandle) | ConvertTo-Json -Depth 20
                    "[{0}] Payload content: `n{1}" -f $functionName, $challengePayloadLogRedacted | Write-Verbose
               
                    $challengeResp = Invoke-RestMethod -Uri $href -Method Post -Body $challengePayload -ContentType "application/json" -WebSession $session -Headers $headers -MaximumRedirection 0 -ErrorAction Stop
                    
                    # Redact stateHandle before verbose output
                    $challengeRespRedacted = Redact-StateHandle $challengeResp
                    "[{0}] Challenge response received: `n{1}" -f $functionName, ($challengeRespRedacted | ConvertTo-Json -Depth 20) | Write-Verbose
                    
                    $href = $challengeResp.remediation.value | Where-Object { $_.name -eq 'challenge-poll' } | Select-Object -ExpandProperty href
                    # Poll for status
                    $maxPolls = 30
                    $pollInterval = 2
                    for ($i = 1; $i -le $maxPolls; $i++) {                        
                        if ($correctAnswer) {
                            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Approve the $($preferredAuthenticator.name) push notification on your device by selecting the number '$correctAnswer'." -Id 0
                        }
                        else {
                            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Approve the $($preferredAuthenticator.name) push notification on your device..." -Id 0
                        }
                        Start-Sleep -Seconds $pollInterval
                        "[{0}] Polling for Okta Verify push status, attempt {1}/{2}..." -f $functionName, $i, $maxPolls | Write-Verbose
                        $challengeResp = Invoke-RestMethod -Uri $href -Method Post -Body $challengePayload -ContentType "application/json" -WebSession $session -Headers $headers -MaximumRedirection 0 -ErrorAction Stop
                        if ($challengeResp.remediation) {
                            "[{0}] Challenge response remediation: `n{1}" -f $functionName, (Redact-StateHandle $challengeResp.remediation | ConvertTo-Json -Depth 20) | Write-Verbose
                        }
                        if ($challengeResp.success -and $challengeResp.success.href) {
                            "[{0}] Okta Verify push approved." -f $functionName | Write-Verbose
                            $href = $challengeResp.success.href
                            # Hide stateToken value in logs for security
                            $hrefLog = $href
                            if ($hrefLog -match 'stateToken=[^&]+') {
                                $hrefLog = $hrefLog -replace '(stateToken=)[^&]+', '$1[REDACTED]'
                            }
                            "[{0}] About to execute final GET request to: '{1}'" -f $functionName, $hrefLog | Write-Verbose
                            break
                        }
                        if ($i -eq $maxPolls) {
                            "[{0}] Maximum number of Okta Verify push polling attempts ({1}) reached. MFA approval not received." -f $functionName, $maxPolls | Write-Verbose
                            if (-not $NoProgress) {
                                Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                            }
                            throw "Maximum number of Okta Verify push polling attempts ($maxPolls) reached. MFA approval not received."
                        }
                        if ($challengeResp.messages -and $challengeResp.messages.value -and $challengeResp.messages.value[0].message) {
                            "[{0}] Okta Verify push polling error: {1}" -f $functionName, $challengeResp.messages.value[0].message | Write-Verbose
                            if (-not $NoProgress) {
                                Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                            }
                            throw "Okta Verify push polling error: $($challengeResp.messages.value[0].message)"
                        }
                    }   
                    $Step++

                }
                # TOTP (Okta/Google Authenticator) with passcode prompt
                elseif ($preferredAuthenticator -and $preferredAuthenticator.methodType -eq 'otp') {   
                    "[{0}] Selecting '{1}' for authentication with passcode prompt." -f $functionName, $preferredAuthenticator.name | Write-Verbose
                    # Prompt user for TOTP code
                    Write-Host "Please enter the 6-digit code from your '$($preferredAuthenticator.name)' app for user '$userIdentifier':" -ForegroundColor Yellow
                    $totpCode = Read-Host -Prompt "MFA Code"
                    $Step++
                    # Capture href in remediation where name is challenge-authenticator
                    if ( $challengeResp.remediation.value | Where-Object { $_.name -eq 'challenge-authenticator' } ) {
                        $href = $challengeResp.remediation.value | Where-Object { $_.name -eq 'challenge-authenticator' } | Select-Object -ExpandProperty href
                    }
                    else {
                        # If not present, fallback to select-authenticator-authenticate (may happen if password was not required)
                        $href = $challengeResp.remediation.value | Where-Object { $_.name -eq 'select-authenticator-authenticate' } | Select-Object -ExpandProperty href
                        $challengePayloadObj = @{ 
                            authenticator = @{ 
                                id         = $preferredAuthenticator.auth.id
                                methodType = $preferredAuthenticator.methodType
                            }
                            stateHandle   = $stateHandle
                        }

                        $challengePayload = $challengePayloadObj | ConvertTo-Json
                        "[{0}] About to execute POST request to: '{1}'" -f $functionName, $href | Write-Verbose
                                            
                        # Redact stateHandle before verbose output
                        $challengePayloadLogRedacted = ($challengePayload | ConvertFrom-Json | Redact-StateHandle) | ConvertTo-Json -Depth 20
                        "[{0}] Payload content: `n{1}" -f $functionName, $challengePayloadLogRedacted | Write-Verbose
                        
                        $challengeResp = Invoke-RestMethod -Uri $href -Method Post -Body $challengePayload -ContentType "application/json" -WebSession $session -Headers $headers -MaximumRedirection 0 -ErrorAction Stop
                               
                        # Redact stateHandle before verbose output
                        $challengeRespRedacted = Redact-StateHandle $challengeResp
                        "[{0}] Challenge response received: `n{1}" -f $functionName, ($challengeRespRedacted | ConvertTo-Json -Depth 20) | Write-Verbose

                        $href = $challengeResp.remediation.value | Where-Object { $_.name -eq 'challenge-authenticator' } | Select-Object -ExpandProperty href
                        "[{0}] Href for TOTP challenge: '{1}'" -f $functionName, $href | Write-Verbose

                    }
         
                    if ($preferredAuthenticator.name -eq 'Google Authenticator') {
                        $challengePayloadObj = @{
                            credentials = @{ passcode = $totpCode }
                            stateHandle = $stateHandle
                        }
                    }
                    else {
                        $challengePayloadObj = @{
                            credentials = @{ totp = $totpCode }
                            stateHandle = $stateHandle
                        }
                    }
 
                    $challengePayload = $challengePayloadObj | ConvertTo-Json
                    "[{0}] About to execute POST request to: '{1}'" -f $functionName, $href | Write-Verbose
                   
                    # Redact stateHandle before verbose output
                    $challengePayloadLogRedacted = ($challengePayload | ConvertFrom-Json | Redact-StateHandle) | ConvertTo-Json -Depth 20
                    "[{0}] Payload content: `n{1}" -f $functionName, $challengePayloadLogRedacted | Write-Verbose
        
                    try {
                        $challengeResp = Invoke-RestMethod -Uri $href -Method Post -Body $challengePayload -ContentType "application/json" -WebSession $session -Headers $headers -MaximumRedirection 0 -ErrorAction Stop
                    }
                    catch {
                        "[{0}] Error during TOTP challenge response: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                        $remediation = ($_ | ConvertFrom-Json).remediation
                        $challengeAuth = $remediation.value | Where-Object { $_.name -eq 'challenge-authenticator' }
                        $credentials = $challengeAuth | Select-Object -ExpandProperty value -ErrorAction SilentlyContinue | Where-Object { $_.name -eq 'credentials' }
                        $formValue = $credentials.form.value
                        $passcodeObj = $formValue | Where-Object { $_.name -eq 'passcode' }
                        $messages = $passcodeObj.messages.value
                        if ($messages -and $messages.Count -gt 0) {
                            $errMsg = $messages[0].message
                        }
                        else {
                            $errMsg = "Unknown error during TOTP challenge response."
                        }
            
                        if ($errMsg -match 'expired') {
                            "[{0}] {1} code expired. Error: {2}" -f $functionName, $preferredAuthenticator.name, $errMsg | Write-Verbose
                            if (-not $NoProgress) {
                                Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                            }
                            throw "Authentication failed: '$($preferredAuthenticator.name)' code expired."
                        }
                        elseif ($_.Exception.Response -and $_.Exception.Response.StatusCode.value__ -eq 400) {
                            "[{0}] {1} code rejected. HTTP 400 Bad Request received." -f $functionName, $preferredAuthenticator.name | Write-Verbose
                            if (-not $NoProgress) {
                                Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                            }
                            throw "Authentication failed: The code entered for '$($preferredAuthenticator.name)' was incorrect (HTTP 400). Please verify your authenticator app and try again."
                        }
                        else {
                            "[{0}] {1} code rejected. Error: {2}" -f $functionName, $preferredAuthenticator.name, $errMsg | Write-Verbose
                            if (-not $NoProgress) {
                                Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                            }
                            throw "Authentication failed: The code entered for '$($preferredAuthenticator.name)' was rejected. Error: $errMsg"
                        }
                    }

                    # Redact stateHandle before verbose output
                    $challengeRespRedacted = Redact-StateHandle $challengeResp
                    "[{0}] Challenge response received: `n{1}" -f $functionName, ($challengeRespRedacted | ConvertTo-Json -Depth 20) | Write-Verbose

                    if ($challengeResp.success -and $challengeResp.success.href) {
                        "[{0}] {1} code accepted." -f $functionName, $preferredAuthenticator.name | Write-Verbose
                        $href = $challengeResp.success.href
                        # Hide stateToken value in logs for security
                        $hrefLog = $href
                        if ($hrefLog -match 'stateToken=[^&]+') {
                            $hrefLog = $hrefLog -replace '(stateToken=)[^&]+', '$1[REDACTED]'
                        }
                        "[{0}] About to execute final GET request to: '{1}'" -f $functionName, $hrefLog | Write-Verbose
                    }
                    else {
                        "[{0}] {1} code rejected." -f $functionName, $preferredAuthenticator.name | Write-Verbose
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        throw "Authentication failed: '$($preferredAuthenticator.name)' code rejected."
                    }
                }

                # The challengeResp may contain a remediation with a redirect to the callback URL with code
                $authCode = $null
            
                # Generalized redirect chain: follow up to 5 redirects, but do not capture or log cookies
                $maxRedirects = 5
                if ($href) {
                    $currentUrl = $href
                }
                
                $redirectUrl = $null
                if ($challengeResp.remediation -and $challengeResp.remediation.redirect) {
                    $redirectUrl = $challengeResp.remediation.redirect.href
                }
                elseif ($challengeResp.success -and $challengeResp.success.href) {
                    $redirectUrl = $challengeResp.success.href
                }

                if ($redirectUrl) {
                    # Hide stateToken value in logs for security
                    $redirectUrlLog = $redirectUrl
                    if ($redirectUrlLog -match 'stateToken=[^&]+') {
                        $redirectUrlLog = $redirectUrlLog -replace '(stateToken=)[^&]+', '$1[REDACTED]'
                    }
                    "[{0}] Following success.href: {1}" -f $functionName, $redirectUrlLog | Write-Verbose
                    $finalUrl = $redirectUrl
                    $maxRedirects = 5
                    for ($i = 1; $i -le $maxRedirects; $i++) {
                        "[{0}] ------------------------------------- Redirection {1} -------------------------------------" -f $functionName, $i | Write-Verbose
                        # Hide stateToken and code values in logs for security
                        $finalUrlLog = $finalUrl
                        if ($finalUrlLog -match 'stateToken=[^&]+') {
                            $finalUrlLog = $finalUrlLog -replace '(stateToken=)[^&]+', '$1[REDACTED]'
                        }
                        if ($finalUrlLog -match 'state=[^&]+') {
                            $finalUrlLog = $finalUrlLog -replace '(state=)[^&]+', '$1[REDACTED]'
                        }
                        if ($finalUrlLog -match 'code=[^&]+') {
                            $finalUrlLog = $finalUrlLog -replace '(code=)[^&]+', '$1[REDACTED]'
                        }
                        "[{0}] About to execute GET request to: '{1}'" -f $functionName, $finalUrlLog | Write-Verbose

                        try {
                            $resp = Invoke-WebRequest -Uri $finalUrl -WebSession $session -Headers $headers -MaximumRedirection 0 -ErrorAction Stop
                            break
                        }
                        catch {
                            $location = $null
                            if ($_.Exception.Response -and $_.Exception.Response.Headers["Location"]) {
                                $location = $_.Exception.Response.Headers["Location"]
                            }
                            elseif ($_.Exception.Response -and $_.Exception.Response.Headers.GetValues) {
                                try {
                                    $location = $_.Exception.Response.Headers.GetValues("Location")[0]
                                }
                                catch {}
                            }

                            if ($location) {
                                # Hide stateToken and code values in logs for security
                                $locationLog = $location
                                if ($locationLog -match 'stateToken=[^&]+') {
                                    $locationLog = $locationLog -replace '(stateToken=)[^&]+', '$1[REDACTED]'
                                }
                                if ($locationLog -match 'state=[^&]+') {
                                    $locationLog = $locationLog -replace '(state=)[^&]+', '$1[REDACTED]'
                                }
                                if ($locationLog -match 'code=[^&]+') {
                                    $locationLog = $locationLog -replace '(code=)[^&]+', '$1[REDACTED]'
                                }
                                "[{0}] Redirected to: {1}" -f $functionName, $locationLog | Write-Verbose
                                $finalUrl = $location
                                if ($finalUrl -like "$RedirectUri*") {
                                    $finalUrlLog = $finalUrl
                                    if ($finalUrlLog -match 'code=[^&]+') {
                                        $finalUrlLog = $finalUrlLog -replace '(code=)[^&]+', '$1[REDACTED]'
                                    }
                                    if ($finalUrlLog -match 'state=[^&]+') {
                                        $finalUrlLog = $finalUrlLog -replace '(state=)[^&]+', '$1[REDACTED]'
                                    }
                                    "[{0}] Arrived at callback URL: {1}" -f $functionName, $finalUrlLog | Write-Verbose
                                    if ($finalUrl -match "code=([^&]+)") {
                                        $authCode = $matches[1]
                                    }
                                    break
                                }
                            }
                            else {
                                "[{0}] No Location header in redirect response. All headers: {1} Exception: {2}" -f $functionName, (ConvertTo-Json $_.Exception.Response.Headers -Depth 5), $_ | Write-Verbose
                                break
                            }
                        }
                    }
                }
                # Block handles the case where Okta responds with a successWithInteractionCode object. This is a newer pattern where Okta provides an interaction code that the client can exchange for tokens.
                elseif ($challengeResp.successWithInteractionCode) {
                    if ($challengeResp.successWithInteractionCode.redirectUri -and ($challengeResp.successWithInteractionCode.redirectUri -match "code=([^&]+)")) {
                        $authCode = $matches[1]
                    }
                }

                if (-not $authCode) {
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "Connection error! Unable to obtain authorization code after submitting credentials."
                } 
                else {
                    "[{0}] Authorization code obtained successfully." -f $functionName | Write-Verbose
                    "[{0}] Authorization code: {1}...{2}" -f $functionName, $authCode.Substring(0, 1), $authCode.Substring($authCode.Length - 1, 1) | Write-Verbose
                }

                $completedSteps++
                #endregion STEP 5.2: End credential submission and redirect handling                       
            }
        }
    
        ##############################################################################################################################################################################################
                
                        
        #region [STEP 6]: Exchange authorization code for tokens (POST /as/token.oauth2) and save details to global session variable
        Write-Verbose " ----------------------------------STEP 6--------------------------------------------------------------------------------"
        Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Exchange authorization code for tokens" -Id 0
        $step++
        "[{0}] Step 6: POST https://sso.common.cloud.hpe.com/as/token.oauth2" -f $functionName | Write-Verbose
        "[{0}] Code verifier (for token): {1}...{2}" -f $functionName, $codeVerifier.Substring(0, 1), $codeVerifier.Substring($codeVerifier.Length - 1, 1) | Write-Verbose
        "[{0}] Code challenge (for token): {1}...{2}" -f $functionName, $codeChallenge.Substring(0, 1), $codeChallenge.Substring($codeChallenge.Length - 1, 1) | Write-Verbose
        $tokenPayloadObj = @{
            client_id     = $dynamicClientId
            code          = $authCode
            redirect_uri  = $RedirectUri
            code_verifier = $codeVerifier
            grant_type    = "authorization_code"
        }
        "[{0}] About to execute POST request to: '{1}'" -f $functionName, "https://sso.common.cloud.hpe.com/as/token.oauth2" | Write-Verbose
        $tokenPayloadLog = $tokenPayloadObj.Clone()
        # Hide sensitive code and code_verifier values in logs
        $tokenPayloadLog.code = '[REDACTED]'
        $tokenPayloadLog.code_verifier = '[REDACTED]'        
        "[{0}] Payload content: `n{1}" -f $functionName, ($tokenPayloadLog | Out-String) | Write-Verbose

        # Convert token payload to URL-encoded string for application/x-www-form-urlencoded
        $body = [System.Web.HttpUtility]::ParseQueryString([String]::Empty)
        $tokenPayloadObj.GetEnumerator() | ForEach-Object { $body.Add($_.Key, $_.Value) }
        $bodyString = $body.ToString()
        # Hide sensitive code and code_verifier values in logs
        $bodyStringLog = $bodyString -replace '(code=)[^&]+', '$1[REDACTED]' -replace '(code_verifier=)[^&]+', '$1[REDACTED]'
        "[{0}] Token request body (urlencoded): {1}" -f $functionName, $bodyStringLog | Write-Verbose
        
        $tokenResponse = Invoke-RestMethod -Uri "https://sso.common.cloud.hpe.com/as/token.oauth2" -Method Post -Body $bodyString -ContentType "application/x-www-form-urlencoded" 
        "[{0}] Tokens retrieved successfully" -f $functionName | Write-Verbose
        
        $Oauth2AccessToken = $tokenResponse.access_token
        "[{0}] OAuth2 Access Token: '{1}...'" -f $functionName, ($oauth2AccessToken.Substring(0, [Math]::Min(50, $oauth2AccessToken.Length))) | Write-Verbose
        $Oauth2IdToken = $tokenResponse.id_token
        "[{0}] OAuth2 ID Token: '{1}...'" -f $functionName, ($oauth2IdToken.Substring(0, [Math]::Min(50, $oauth2IdToken.Length))) | Write-Verbose
        $Oauth2RefreshToken = $tokenResponse.refresh_token
        "[{0}] OAuth2 Refresh Token: '{1}...'" -f $functionName, ($oauth2RefreshToken.Substring(0, [Math]::Min(10, $oauth2RefreshToken.Length))) | Write-Verbose

        Write-Verbose ("[{0}] Setting up global session variable" -f $functionName)

        $Global:HPEGreenLakeSession = [System.Collections.ArrayList]::new()
            
        $SessionInformation = [PSCustomObject]@{
            AuthSession              = $session
            WorkspaceSession         = $Null
            oauth2AccessToken        = $Oauth2AccessToken
            oauth2IdToken            = $Oauth2IdToken
            oauth2RefreshToken       = $Oauth2RefreshToken
            username                 = $UserName
            name                     = $Name
            workspaceId              = $Null
            workspace                = $Null
            workspacesCount          = $Null
            organization             = $Null
            organizationId           = $Null
            oauth2TokenCreation      = [datetime]$(Get-Date)
            oauth2TokenCreationEpoch = $((New-TimeSpan -Start (Get-Date "01/01/1970") -End (Get-Date)).TotalSeconds) 
            apiCredentials           = [System.Collections.ArrayList]::new()
            glpApiAccessToken        = [System.Collections.ArrayList]::new()
            glpApiAccessTokenv1_2    = [System.Collections.ArrayList]::new()      
            ccsSid                   = $Null
            onepassToken             = $Null
        }
            
        [void]$Global:HPEGreenLakeSession.add($SessionInformation)
            
        $Global:HPEGreenLakeSession = Invoke-RepackageObjectWithType -RawObject $Global:HPEGreenLakeSession -ObjectName 'Connection'

        "[{0}] `$Global:HPEGreenLakeSession global variable set!" -f $functionName | Write-Verbose

        $completedSteps++

        #endregion STEP 6: End token exchange
          
        #region [STEP 7]: Create session with workspace (acquire CCS SID/IDX) to https://aquila-user-api.common.cloud.hpe.com/authn/v1/session
        Write-Verbose " ----------------------------------STEP 7--------------------------------------------------------------------------------"
        Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Create session with workspace" -Id 0
        $step++
        Write-Verbose ("[{0}] Step 7: Create session with workspace using Connect-HPEGLWorkspace" -f $functionName)
        try {
            # Create session with workspace using Connect-HPEGLWorkspace
            if ($Workspace) {
                "[{0}] Create session using: Connect-HPEGLWorkspace -Name '{1}'" -f $functionName, $Workspace | Write-Verbose
                $CCSSession = Connect-HPEGLWorkspace -Name $Workspace -NoProgress:$NoProgress -RemoveExistingCredentials:$RemoveExistingCredentials
            }
            else {
                "[{0}] Create session using: Connect-HPEGLWorkspace" -f $functionName | Write-Verbose
                $CCSSession = Connect-HPEGLWorkspace -NoProgress:$NoProgress -RemoveExistingCredentials:$RemoveExistingCredentials
            }
        }
        catch {
            if (-not $NoProgress) {
                Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed # progress bar from 'Connect-HPEGLWorkspace' 
            }
            $PSCmdlet.ThrowTerminatingError($_)
        }
                    
    
        $completedSteps++
    
        #endregion STEP 7: End workspace session creation
            
        "[{0}] Connection to HPE GreenLake successful!" -f $functionName | Write-Verbose
        
        # Clear the progress bar upon completion
        if (-not $NoProgress) {
            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Completed" -Completed
            Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake" -Status "Completed" -Completed
        }
        "[{0}] HPE GreenLake session established for user '{1}'" -f $functionName, $Global:HPEGreenLakeSession.username | Write-Verbose
        "[{0}] HPE GreenLake session details: `n{1}" -f $functionName, ($Global:HPEGreenLakeSession | Out-String) | Write-Verbose
        "[{0}] HPE GreenLake session created at: {1}" -f $functionName, $Global:HPEGreenLakeSession.oauth2TokenCreation | Write-Verbose
        "[{0}] HPE GreenLake session expires at: {1}" -f $functionName, $Global:HPEGreenLakeSession.oauth2TokenCreation.AddMinutes(120) | Write-Verbose
        
        return $Global:HPEGreenLakeSession

    }
}

Function Disconnect-HPEGL { 
    <#
.SYNOPSIS
Log off from the HPE GreenLake platform.

.DESCRIPTION
This cmdlet terminates the current HPE GreenLake session by logging out the user and purging all variables and temporary API credentials established through 'Connect-HPEGL'.

.EXAMPLE
Disconnect-HPEGL

Terminates the current HPE GreenLake session. 

.INPUTS
None. You cannot pipe objects to this cmdlet.

.OUTPUTS
System.String
    Returns "<email address> session disconnected from <workspace name> workspace!"

#>

    [CmdletBinding()]
    Param(
        [Switch]$NoProgress
    ) 


    Begin {

        $Caller = (Get-PSCallStack)[1].Command
        $functionName = $MyInvocation.InvocationName.ToString().ToUpper()
        "[{0}] Called from: {1}" -f $functionName, $Caller | Write-Verbose    
    
        # Initialize progress bar variables
        $completedSteps = 0
        $totalSteps = 3

        function Update-ProgressBar {
            param (
                [int]$CompletedSteps,
                [int]$TotalSteps,
                [string]$CurrentActivity,
                [int]$Id
            )
            if (-not $NoProgress) {
                $percentComplete = [math]::Min(($CompletedSteps / $TotalSteps) * 100, 100)
                Write-Progress -Id $Id -Activity "Disconnecting from HPE GreenLake" -Status $CurrentActivity -PercentComplete $percentComplete
            }
        }
    }
    
    
    Process {
    
        "[{0}] Bound PS Parameters: {1}" -f $functionName, ($PSBoundParameters | out-string) | Write-Verbose
    
        if (-not $Global:HPEGreenLakeSession) {
            Write-Warning "Operation not required: No HPE GreenLake session found."
    
        }
        else {

            $_WorkspaceName = $Global:HPEGreenLakeSession.workspace

            $step = 1

            # Access_token expiration date
            $AccessTokenExpirationDate = $Global:HPEGreenLakeSession.oauth2TokenCreation.AddMinutes(120)

            # Number of minutes before expiration of the Access_token expiration date
            $BeforeExpirationinMinutes = [math]::Round(((New-TimeSpan -Start (Get-Date) -End ($AccessTokenExpirationDate)).TotalHours ) * 60)
        
            if ( $BeforeExpirationinMinutes -gt 0) { 

                $Expiration = $BeforeExpirationinMinutes 

                "[{0}] Session expiration in '{1}' minutes" -f $functionName, $Expiration | Write-Verbose


                #Region 1 - Remove library API client credential  
            
                "[{0}] ------------------------------------- STEP 1 -------------------------------------" -f $functionName | Write-Verbose
                
                Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Removing the library personal API client" -Id 3
                $step++
            
                "[{0}] About to remove the GLP temporary API Client credential using the template '{1}'" -f $functionName, $global:HPEGLAPIClientCredentialName | Write-Verbose
                
                if ($Global:HPEGreenLakeSession.apiCredentials) {

                    try {

                        $APIcredential = Get-HPEGLAPICredential | Where-Object { $_.name -match $global:HPEGLAPIClientCredentialName } 
                
                        if ($APIcredential) {
            
                            $APIcredential | Remove-HPEGLAPICredential -Force | Out-Null
            
                        }
                        else {
                            "[{0}] No library API Client credential found using the template '{1}'!" -f $functionName, $global:HPEGLAPIClientCredentialName | Write-Verbose
                        }

                    }
                    catch {                        
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 3
                            Write-Progress -Id 3 -Activity "Disconnecting from HPE GreenLake" -Status "Failed" -Completed 
                        }
                        Write-Warning "The session has already been disconnected due to expiration!"
                        return
                        # $PSCmdlet.ThrowTerminatingError($_)
                    }    
                
                }

                $completedSteps++

                #endregion


                #Region 2 - Remove HPE GreenLake workspace session   
                "[{0}] ------------------------------------- STEP 2 -------------------------------------" -f $functionName | Write-Verbose

                Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Removing HPE GreenLake workspace session" -Id 3
                $step++

                "[{0}] About to remove HPE GreenLake workspace session" -f $functionName | Write-Verbose

                $url = Get-AuthnEndSessionURI

                "[{0}] About to execute GET request to: '{1}'" -f $functionName, $url | Write-Verbose
        
                try {

                    $InvokeReturnData = Invoke-WebRequest -Method GET -Uri $url -WebSession $Global:HPEGreenLakeSession.WorkspaceSession -ContentType 'application/json' 
                    "[{0}] Received status code response: '{1}' - Description: '{2}'" -f $functionName, $InvokeReturnData.StatusCode, $InvokeReturnData.StatusDescription | Write-verbose
                   
                    "[{0}] Raw response: `n{1}" -f $functionName, $InvokeReturnData | Write-verbose

                    "[{0}] Workspace '{1}' session removed successfully!" -f $functionName, $Global:HPEGreenLakeSession.workspace | Write-Verbose

                }
                catch {

                    $Response = $null
                    if ($_.Exception.Response) {
                        try {
                            $Response = $_.Exception.Response | ConvertTo-Json -Depth 10
                        } catch {
                            $Response = $_.Exception.Response.ToString()
                        }
                    }

                    $ExceptionCode = $null
                    $ExceptionText = $null
                    if ($_.Exception.Response -and $_.Exception.Response.StatusCode) {
                        $ExceptionCode = $_.Exception.Response.StatusCode
                    }
                    if ($_.Exception.Response -and $_.Exception.Response.StatusDescription) {
                        $ExceptionText = $_.Exception.Response.StatusDescription
                    }
                    if ($_.Exception.Response -and $_.Exception.Response.ReasonPhrase) {
                        $ExceptionText += $_.Exception.Response.ReasonPhrase
                    }
                
                    "[{0}] Request failed with the following Status:`r`n`tHTTPS Return Code = '{1}' `r`n`tHTTPS Return Code Description = '{2}' `n" -f $functionName, $ExceptionCode, $ExceptionText | Write-Verbose

                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 3
                        Write-Progress -Id 3 -Activity "Disconnecting from HPE GreenLake" -Status "Failed" -Completed 
                    }

                    $PSCmdlet.ThrowTerminatingError($_)
            
                }

                $completedSteps++

                #endregion


                #Region 3 - Revoke CCS OAuth2 token
                "[{0}] ------------------------------------- STEP 3 -------------------------------------" -f $functionName | Write-Verbose

                Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Revoking OAuth2 tokens" -Id 3
                $step++

                "[{0}] About to revoke CCS OAuth2 token" -f $functionName | Write-Verbose

                $OpenidConfiguration = Get-OpenidConfiguration
                $url = $Global:HPEGLauthorityURL.OriginalString + $OpenidConfiguration
                "[{0}] About to execute GET request to: '{1}'" -f $functionName, $url | Write-Verbose
            
                
                try {
                    $response = Invoke-RestMethod $url -Method 'GET' 
            
                }
                catch {                
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 3
                        Write-Progress -Id 3 -Activity "Disconnecting from HPE GreenLake" -Status "Failed" -Completed 
                    }
                    $PSCmdlet.ThrowTerminatingError($_)
                }

                $formattedResponse = $response | ConvertTo-Json -Depth 10
                "[{0}] Raw response: `n{1}" -f $functionName, $formattedResponse | Write-verbose

                $payload = @{
                    'client_id'       = 'aquila-user-auth'
                    'token'           = $Global:HPEGreenLakeSession.oauth2AccessToken
                    'token_type_hint' = 'access_token'
                    
                } 
                    
                $RevocationEndpoint = $response.revocation_endpoint

                "[{0}] About to execute POST request to revoke CCS OAuth2 token to: '{1}'" -f $functionName, $RevocationEndpoint | Write-Verbose
                
                try {

                    $redactedPayload = $payload.Clone()  # Shallow copy for simple hashtables
                    $redactedPayload['token'] = '[REDACTED]'
                    "[{0}] Request payload: `n{1}" -f $functionName, ($redactedPayload | Out-String) | Write-Verbose

                    $InvokeReturnData = Invoke-webrequest -Uri $RevocationEndpoint -Method 'POST' -Body $payload -ContentType "application/x-www-form-urlencoded" -ErrorAction stop -WebSession $Global:HPEGreenLakeSession.WorkspaceSession
                    
                    "[{0}] Received status code response: '{1}' - Description: '{2}'" -f $functionName, $InvokeReturnData.StatusCode, $InvokeReturnData.StatusDescription | Write-verbose
                    # "[{0}] Raw response: `n{1}" -f $functionName, $InvokeReturnData | Write-verbose
                
                    "[{0}] CCS OAuth2 token '{1}' revoked!" -f $functionName, $Global:HPEGreenLakeSession.username | Write-Verbose

                    $_username = $Global:HPEGreenLakeSession.username
                    
                    # Remove HPEGLworkspaces global variable if it exists
                    if (Get-Variable -Scope global -Name HPEGLworkspaces -ErrorAction SilentlyContinue) {
                        Remove-Variable -Name HPEGLworkspaces -Scope Global -Force
                        "[{0}] Global variable `$Global:HPEGLworkspaces has been removed" -f $functionName | Write-Verbose
                    }
                    # Remove HPEGreenLakeSession global variable if it exists
                    if (Get-Variable -Scope global -Name HPEGreenLakeSession -ErrorAction SilentlyContinue) {
                        Remove-Variable -Name HPEGreenLakeSession -Scope Global -Force
                        "[{0}] Global variable `$Global:HPEGreenLakeSession has been removed" -f $functionName | Write-Verbose
                    }
                }
                
                catch {

                    "[{0}] Exception thrown!" -f $functionName | Write-Verbose

                    # Get Exception type
                    $exception = $_.Exception

                    do {
                        "[{0}] Exception Type: '{1}'" -f $functionName, $exception.GetType().Name | Write-Verbose
                        $exception = $exception.InnerException
                    } while ($exception)

                    # Get exception stream
                    $result = $_.Exception.Response.GetResponseStream()
                    $reader = New-Object System.IO.StreamReader($result)
                    $reader.BaseStream.Position = 0
                    $reader.DiscardBufferedData()
                    $responseBody = $reader.ReadToEnd() 


                    "[{0}] Raw response `n{1}" -f $functionName, $responseBody | Write-Verbose
                
                    $response = $responseBody | ConvertFrom-Json
                        
                    if ($Body) {
                        "[{0}] Request payload: '{1}'" -f $functionName, ($Body | Out-String) | Write-Verbose
                    }
                    if ($Headers) {
                        "[{0}] Request headers: '{1}'" -f $functionName, ($headers | Out-String) | Write-Verbose
                    }

                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 3
                        Write-Progress -Id 3 -Activity "Disconnecting from HPE GreenLake" -Status "Failed" -Completed 
                    }

                    Throw "Error -  $responseBody"          
                }
                
                $completedSteps++
                
                #endregion
                
                # Clear the progress bar upon completion
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Completed" -Id 3
                    Write-Progress -Id 3 -Activity "Disconnecting from HPE GreenLake" -Status "Completed" -Completed 
                }
                
                if ($_WorkspaceName) {
                    return ("'{0}' session disconnected from '{1}' workspace!" -f $_username, $_WorkspaceName)

                }
                else {
                    return ("'{0}' session disconnected!" -f $_username)

                }

            }
            # Expiration = 0
            else { 

                "[{0}] The session has expired! Disconnection is not needed!" -f $functionName | Write-Verbose   
                
                # Remove HPEGLworkspaces global variable if it exists
                if (Get-Variable -Scope global -Name HPEGLworkspaces -ErrorAction SilentlyContinue) {
                    Remove-Variable -Name HPEGLworkspaces -Scope Global -Force
                    "[{0}] Global variable `$Global:HPEGLworkspaces has been removed" -f $functionName | Write-Verbose
                }
                # Remove HPEGreenLakeSession global variable if it exists
                if (Get-Variable -Scope global -Name HPEGreenLakeSession -ErrorAction SilentlyContinue) {
                    Remove-Variable -Name HPEGreenLakeSession -Scope Global -Force
                    "[{0}] Global variable `$Global:HPEGreenLakeSession has been removed" -f $functionName | Write-Verbose
                }
                    
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Completed" -Id 3
                    Write-Progress -Id 3 -Activity "Disconnecting from HPE GreenLake" -Status "Completed" -Completed 
                }

                Write-Warning "The session has already been disconnected due to expiration!"
                return
            }
        }
    }
}

Function Connect-HPEGLWorkspace {
    <#
    .SYNOPSIS
    Connect to a workspace or switch between HPE GreenLake workspaces.

    .DESCRIPTION
    This cmdlet establishes a connection to an HPE GreenLake workspace or switches between workspaces.
    It manages the creation and removal of temporary API client credentials, updating the $Global:HPEGreenLakeSession global variable.
    Used by Connect-HPEGL to initiate a session or by Invoke-HPEGLAutoReconnect for token refresh.

    .PARAMETER Name
    Specifies the name of a workspace available in HPE GreenLake. Use Get-HPEGLWorkspace to retrieve available workspace names.
    Optional; defaults to the first available workspace associated with the user's email.

    .PARAMETER Force
    Forces reconnection to the current workspace, re-establishing connections to HPE GreenLake workspace, HPE Onepass and COM APIs.

    .PARAMETER RemoveExistingCredentials
    Specifies whether to remove all existing API credentials generated by previous runs of Connect-HPEGL or Connect-HPEGLWorkspace that were not properly cleaned up by a Disconnect-HPEGL operation.
    When enabled, this option will delete all previously created API credentials attached to your user account that may be lingering from earlier sessions.
    Use this option if you encounter the error: 'You have reached the maximum of 7 personal API clients' when connecting. Removing these credentials can resolve the issue by clearing out unused credentials created by this library.

    Caution: Removing existing credentials may affect other active PowerShell sessions related to your user using those credentials, potentially causing authentication failures until those sessions reconnect.

    .PARAMETER NoProgress
    Suppresses the progress bar display for automation or silent operation.

    .EXAMPLE
    Connect-HPEGLWorkspace
    Connects to the default HPE GreenLake workspace and generates temporary API credentials.

    .EXAMPLE
    Connect-HPEGLWorkspace -Name 'DreamCompany'
    Connects to or switches to the 'DreamCompany' workspace, updating API credentials.

    .EXAMPLE
    Connect-HPEGLWorkspace -Force
    Forces reconnection to the current workspace, refreshing tokens.

    .EXAMPLE
    Get-HPEGLWorkspace -Name Workspace_2134168251 | Connect-HPEGLWorkspace
    Connects to the specified workspace via pipeline input.

    .INPUTS
    System.Object
        A workspace object from Get-HPEGLWorkspace.

    .OUTPUTS
    System.Collections.ArrayList
        The updated $Global:HPEGreenLakeSession global variable.

    .NOTES
    - GLP API access token validity: 15 minutes (v1.2) or 120 minutes (v1.1)
    - Requires $Global:HPEGreenLakeSession global variable to be set
    #>

    [CmdletBinding(DefaultParameterSetName = "Name")]
    Param(
        [Parameter(ValueFromPipelineByPropertyName, ParameterSetName = "Name")]
        [Alias("company_name")]
        [String]$Name,

        [Parameter(ParameterSetName = "Force")]
        [Switch]$Force,

        [Parameter(ParameterSetName = "Name")]
        [Switch]$RemoveExistingCredentials,

        [Switch]$NoProgress
    )

    Begin {
        $Caller = (Get-PSCallStack)[1].Command
        $functionName = $MyInvocation.InvocationName.ToString().ToUpper()
        "[{0}] Called from: {1}" -f $functionName, $Caller | Write-Verbose

        # Initialize progress bar variables
        $completedSteps = 0
        $totalSteps = if ($Force) { 3 } elseif ($Name) { 7 } else { 7 } # switching to a different workspace 
        function Update-ProgressBar {
            param (
                [int]$CompletedSteps,
                [int]$TotalSteps,
                [string]$CurrentActivity,
                [int]$Id
            )
            if (-not $NoProgress) {
                $percentComplete = [math]::Min(($CompletedSteps / $TotalSteps) * 100, 100)
                Write-Progress -Id $Id -Activity "Connecting to workspace" -Status $CurrentActivity -PercentComplete $percentComplete
            }
        }

        if (-not $Global:HPEGreenLakeSession) {
            "[{0}] No session found! 'Connect-HPEGL' must be executed first!" -f $functionName | Write-Verbose
            Write-Warning "No session found! Please run Connect-HPEGL first."
            if (-not $NoProgress) {
                Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
            }
            return
        }

        $Oauth2AccessToken = $Global:HPEGreenLakeSession.oauth2AccessToken
        $Oauth2IdToken = $Global:HPEGreenLakeSession.oauth2IdToken

        $HPEGLtokenEndpoint = "https://sso.common.cloud.hpe.com/as/token.oauth2"
    }

    Process {

        #Region : Validate and prepare parameters
        "[{0}] Bound PS Parameters: {1}" -f $functionName, ($PSBoundParameters | Out-String) | Write-Verbose

        # Check access token expiration
        $AccessTokenExpirationDate = $Global:HPEGreenLakeSession.oauth2TokenCreation.AddMinutes(120)
        $BeforeExpirationinMinutes = [math]::Round(($AccessTokenExpirationDate - (Get-Date)).TotalMinutes, 2)
        if ($BeforeExpirationinMinutes -le 0) {
            "[{0}] Session expired! 'Connect-HPEGL' must be executed again!" -f $functionName | Write-Verbose
            Write-Warning "The session has expired! Please run Connect-HPEGL again."
            if (-not $NoProgress) {
                Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
            }
            return
        }

        # Check for existing connection to the same workspace
        if ($Global:HPEGreenLakeSession.workspace -eq $Name -and -not $Force) {
            "[{0}] Already connected to workspace {1}!" -f $functionName, $Name | Write-Verbose
            Write-Warning "You are already connected to workspace $Name!"
            if (-not $NoProgress) {
                Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Completed" -Id 1
                Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Completed" -Completed
                Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Completed" -Completed
            }
            return
        }

        $step = 1
        #EndRegion

        # Create new session if none exists and if force is not specified
        if (-not $Global:HPEGreenLakeSession.workspace -and -not $Force) {

            #Region: [STEP 1]: Create new session (POST https://aquila-user-api.common.cloud.hpe.com/authn/v1/session)
            Write-Verbose " ----------------------------------STEP 1--------------------------------------------------------------------------------"
            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Creating session" -Id 1
            $step++
            Write-Verbose ("[{0}] Step 1: Create new session using POST https://aquila-user-api.common.cloud.hpe.com/authn/v1/session" -f $functionName)
            $ID_Token_Details = Get-HPEGLJWTDetails -Token $Oauth2IdToken
            if ($ID_Token_Details.expiryDateTime -lt (Get-Date)) {
                "[{0}] ID token expired! Expiration: {1}" -f $functionName, $ID_Token_Details.expiryDateTime | Write-Verbose
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                    Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                throw "ID token expired (valid for 5 minutes). Please reconnect using Connect-HPEGL."
            }

            $url = Get-AuthnSessionURI
            $headers = @{
                "Accept"        = "application/json"
                "Content-Type"  = "application/json"
                "Authorization" = "Bearer $Oauth2AccessToken"
            }
            $tokenParams = @{ 'id_token' = $Oauth2IdToken } | ConvertTo-Json

            try {
                "[{0}] POST request to: {1}" -f $functionName, $url | Write-Verbose
                $response = Invoke-RestMethod -Method Post -Uri $url -Headers $headers -Body $tokenParams -SessionVariable CCSSession -Verbose:$VerbosePreference
                if ($response.accounts) {
                    $Global:HPEGLworkspaces = $response.accounts
                }
                $cookies = $CCSSession.Cookies.GetCookies($url)
                # Display all cookies in verbose output
                # "[{0}] All cookies for {1}:" -f $functionName, $url | Write-Verbose
                # foreach ($cookie in $cookies) {
                #     "[COOKIE] {0} = {1}; Domain={2}; Path={3}; Expires={4}; Secure={5}; HttpOnly={6}" -f $cookie.Name, $cookie.Value, $cookie.Domain, $cookie.Path, $cookie.Expires, $cookie.Secure, $cookie.HttpOnly | Write-Verbose
                # }
                $ccsSessionValue = ($cookies | Where-Object { $_.Name -eq 'ccs-session' }).Value
                "[{0}] CCS session cookie: {1}...{2}" -f $functionName, $ccsSessionValue.Substring(0, 1), $ccsSessionValue.Substring($ccsSessionValue.Length - 1, 1) | Write-Verbose
                $Global:HPEGreenLakeSession.WorkspaceSession = $CCSSession
                $Global:HPEGreenLakeSession.ccsSid = $ccsSessionValue
                $Global:HPEGreenLakeSession.workspacesCount = $Global:HPEGLworkspaces.Count
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                    Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                $PSCmdlet.ThrowTerminatingError($_)
            }

            $completedSteps++
            #EndRegion Create new session

            #Region: [STEP 2]: Load workspace (GET https://aquila-user-api.common.cloud.hpe.com/authn/v1/session/load-account/xxxxxxxxxxxxxxxxxxxx)
            Write-Verbose " ----------------------------------STEP 2--------------------------------------------------------------------------------"
            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Loading workspace" -Id 1
            $step++
            if ($Global:HPEGLworkspaces.Count -eq 0) {
                Write-Warning "No workspaces found. Please use New-HPEGLWorkspace to create one."
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                    Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                return
            }
            elseif (-not $Name -and $Global:HPEGLworkspaces.Count -gt 1) {
                Write-Warning "Multiple workspaces ($($Global:HPEGLworkspaces.Count)) found. Use Connect-HPEGLWorkspace -Name <workspace name>."
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                    Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                return
            }
            elseif ($Name) {
                $MyWorkspaceName = $Global:HPEGLworkspaces | Where-Object { $_.company_name -eq $Name }
                if (-not $MyWorkspaceName) {
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                        Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "Workspace '$Name' not found. Use Get-HPEGLWorkspace to list available workspaces."
                }
            }
            else {
                $MyWorkspaceName = $Global:HPEGLworkspaces
            }
            
            $Global:HPEGreenLakeSession.workspaceId = $MyWorkspaceName.platform_customer_id
            $Global:HPEGreenLakeSession.workspace = $MyWorkspaceName.company_name
            
            $SessionLoadAccountUri = Get-SessionLoadAccountUri
            $url = $SessionLoadAccountUri + $Global:HPEGreenLakeSession.workspaceId
            Write-Verbose ("[{0}] Step 2: Load workspace using GET {1}" -f $functionName, $url)
            try {
                $Timeout = 1
                do {
                    $useraccount = Invoke-WebRequest -Method Get -Uri $url -Headers $headers -WebSession $CCSSession -Verbose:$VerbosePreference
                    $success = $useraccount.StatusCode -eq 200
                    if (-not $success) { Start-Sleep -Seconds 1; $Timeout++ }
                } until ($success -or $Timeout -ge 60)
                if ($Timeout -ge 60) {
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                        Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "Cannot load workspace at this time."
                }
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                    Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                $PSCmdlet.ThrowTerminatingError($_)
            }
            $completedSteps++
            #EndRegion
        }

        # Force reconnection (used by Invoke-HPEGLAutoReconnect to refresh tokens)
        elseif ($Force) {
            
            #Region Ensure the user’s session with the workspace is valid and active
            if ($Global:HPEGreenLakeSession.workspacesCount -eq 0) {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Completed" -Id 1
                    Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Completed" -Completed
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Completed" -Completed
                }
                throw "No workspaces found in the current session. Please use New-HPEGLWorkspace to create one."
            }
            elseif (-not $Global:HPEGreenLakeSession.workspace) {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Completed" -Id 1
                    Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Completed" -Completed
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Completed" -Completed
                }
                throw "No workspace session found in the current session. Please use Connect-HPEGLWorkspace -Name <workspace name> to select one."
            }
            #EndRegion

            #Region Reload workspace session
            $MyWorkspaceName = $Global:HPEGreenLakeSession.workspace
            "[{0}] STEP {1} - Forcing workspace load: {2}" -f $functionName, $step, $MyWorkspaceName | Write-Verbose
            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Loading workspace" -Id 1
            $step++

            $SessionLoadAccountUri = Get-SessionLoadAccountUri

            $url = $SessionLoadAccountUri + $Global:HPEGreenLakeSession.workspaceId
            $headers = @{
                "Accept"        = "application/json"
                "Content-Type"  = "application/json"
                "Authorization" = "Bearer $Oauth2AccessToken"
            }
            $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
            $session.Cookies.Add((New-Object System.Net.Cookie("ccs-session", $Global:HPEGreenLakeSession.ccsSid, "/", "aquila-user-api.common.cloud.hpe.com")))
            try {
                $Timeout = 1
                do {
                    $useraccount = Invoke-WebRequest -Method Get -Uri $url -Headers $headers -WebSession $session 
                    $success = $useraccount.StatusCode -eq 200
                    if (-not $success) { Start-Sleep -Seconds 1; $Timeout++ }
                } until ($success -or $Timeout -ge 60)
                if ($Timeout -ge 60) {
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                        Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "Unable to load to the workspace at this time. Please try again later."
                }
                $cookies = $session.Cookies.GetCookies($url)
                $uniqueCookies = @{}
                foreach ($cookie in $cookies) {
                    if ($cookie.Name -eq 'ccs-session' -and -not $uniqueCookies.ContainsKey($cookie.Name)) {
                        $uniqueCookies[$cookie.Name] = $cookie
                    }
                    else {
                        $uniqueCookies[$cookie.Name] = $cookie
                    }
                }
                $newCookieContainer = New-Object System.Net.CookieContainer
                foreach ($cookieName in $uniqueCookies.Keys) {
                    $newCookie = $uniqueCookies[$cookieName]
                    $newCookieContainer.Add($newCookie)
                }
                $session.Cookies = $newCookieContainer
                $ccsSessionValue = ($uniqueCookies['ccs-session']).Value
                $Global:HPEGreenLakeSession.WorkspaceSession = $session
                $Global:HPEGreenLakeSession.ccsSid = $ccsSessionValue
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                    Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                $statusCode = $null
                try {
                    $statusCode = $_.Exception.Response.StatusCode
                }
                catch {}
                if ($statusCode -eq 401 -or $statusCode -eq "Unauthorized") {
                    throw "GLP session refresh failed due to prolonged inactivity or expired credentials. Please reconnect using Connect-HPEGL."
                }
                $PSCmdlet.ThrowTerminatingError($_)
            }
            $completedSteps++
            #EndRegion            

            #Region Refresh UI Doorway access token
            "[{0}] STEP {1} - Renewing GLP OAuth2 token." -f $functionName, $step | Write-Verbose
            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Renewing GLP OAuth2 token" -Id 1
            $step++

            $Body = @{
                'grant_type'    = 'refresh_token'
                'client_id'     = 'aquila-user-auth'
                'refresh_token' = $Global:HPEGreenLakeSession.oauth2RefreshToken
            }
            try {
                $InvokeReturnData = Invoke-WebRequest -Uri $HPEGLtokenEndpoint -Method Post -ContentType "application/x-www-form-urlencoded" -Body $Body -WebSession $Global:HPEGreenLakeSession.WorkspaceSession -Verbose:$VerbosePreference
                $InvokeReturnData = $InvokeReturnData | ConvertFrom-Json
                $Global:HPEGreenLakeSession.oauth2AccessToken = $InvokeReturnData.access_token
                $Global:HPEGreenLakeSession.oauth2RefreshToken = $InvokeReturnData.refresh_token
                $Global:HPEGreenLakeSession.oauth2IdToken = $InvokeReturnData.id_token
                $Global:HPEGreenLakeSession.oauth2TokenCreation = Get-Date
                $Global:HPEGreenLakeSession.oauth2TokenCreationEpoch = (New-TimeSpan -Start (Get-Date "01/01/1970") -End (Get-Date)).TotalSeconds
                "[{0}] Tokens refreshed successfully" -f $functionName | Write-Verbose
                
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                    Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                $PSCmdlet.ThrowTerminatingError($_)
            }
            $completedSteps++
            #EndRegion

            #Region: Refresh public API access token
            "[{0}] STEP {1} - Renewing GLP API token." -f $functionName, $step | Write-Verbose
            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Renewing GLP API token" -Id 1
            $step++

            $GLPTemporaryCredentials = $Global:HPEGreenLakeSession.apiCredentials | Where-Object { $_.name -match "GLP-$global:HPEGLAPIClientCredentialName" }
            
            if ($GLPTemporaryCredentials) {
                try {
                    $SecureClientSecret = $GLPTemporaryCredentials.secure_client_secret | ConvertTo-SecureString
                    $Bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureClientSecret)
                    $ClientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($Bstr)
                    $Payload = @{
                        'client_id'     = $GLPTemporaryCredentials.client_id
                        'client_secret' = $ClientSecret
                        'grant_type'    = 'client_credentials'
                    }
                    $response = Invoke-RestMethod -Method Post -Uri $HPEGLtokenEndpoint -Body $Payload -ContentType 'application/x-www-form-urlencoded'
                    $Global:HPEGreenLakeSession.glpApiAccessToken = [PSCustomObject]@{
                        name          = $GLPTemporaryCredentials.name
                        access_token  = $response.access_token
                        expires_in    = $response.expires_in
                        creation_time = Get-Date
                    }

                    $tokenIssuerv2uri = (Get-HPEGLAPIbaseURL) + "/authorization/v2/oauth2/" + $Global:HPEGreenLakeSession.workspaceId + "/token"
                    $response2 = Invoke-RestMethod -Method Post -Uri $tokenIssuerv2uri -Body $Payload -ContentType 'application/x-www-form-urlencoded'
                    $token = Get-HPEGLJWTDetails $response2.access_token
                    $tokenVersion = if ($token.PSObject.Properties.Match("hpe_token_type")) { $token.hpe_token_type } else { "api-v1.1" }
                    if ($tokenVersion -eq "api-v1.2") {
                        $Global:HPEGreenLakeSession.glpApiAccessTokenv1_2 = [PSCustomObject]@{
                            name          = $GLPTemporaryCredentials.name
                            access_token  = $response2.access_token
                            expires_in    = $response2.expires_in
                            creation_time = Get-Date
                        }
                    }
                    else {
                        $Global:HPEGreenLakeSession.glpApiAccessTokenv1_2 = $null
                    }
                }
                catch {
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                        Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }
            $completedSteps++
            #EndRegion           

        }

        # Switch workspace
        else {

            if (-not $Name) {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                    Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                throw "Parameter 'Name' is required when switching workspaces. Use Get-HPEGLWorkspace to list available workspaces."
            }

            #Region Step 1: Remove existing GLP API credential
            try {
                $Workspace = Get-HPEGLWorkspace -Name $Name -Verbose:$VerbosePreference
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                    Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                $PSCmdlet.ThrowTerminatingError($_)
            }
            if (-not $Workspace) {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                    Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                throw "Workspace '$Name' not found for user '$($Global:HPEGreenLakeSession.username)'. Use Get-HPEGLWorkspace to list available workspaces."
            }
            $WorkspaceId = $Workspace.platform_customer_id
            $MyWorkspaceName = $Workspace.company_name

            try {
                $APIcredential = Get-HPEGLAPICredential | Where-Object { $_.name -match $global:HPEGLAPIClientCredentialName }
                if ($APIcredential) {
                    "[{0}] STEP {1} - Removing API credentials from current workspace" -f $functionName, $step | Write-Verbose
                    Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Removing API credentials" -Id 1
                    $step++
                    $APIcredential | Remove-HPEGLAPICredential -Force | Out-Null
                }
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                    Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                $PSCmdlet.ThrowTerminatingError($_)
            }
            $completedSteps++
            #EndRegion

            #Region Step 2: Load new workspace
            "[{0}] STEP {1} - Loading workspace: {2}" -f $functionName, $step, $MyWorkspaceName | Write-Verbose
            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Loading workspace" -Id 1
            $step++

            try {
                $LoadAccountUri = Get-LoadAccountUri
                $url = $LoadAccountUri + $WorkspaceId
                $useraccount = Invoke-WebRequest -Method Get -Uri $url -Headers $headers -WebSession $Global:HPEGreenLakeSession.WorkspaceSession
                $cookies = $Global:HPEGreenLakeSession.WorkspaceSession.Cookies.GetCookies($url)
                $ccsSessionValue = ($cookies | Where-Object { $_.Name -eq 'ccs-session' }).Value
                $Global:HPEGreenLakeSession.ccsSid = $ccsSessionValue
                $Global:HPEGreenLakeSession.workspaceId = $WorkspaceId
                $Global:HPEGreenLakeSession.workspace = $Name
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                    Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                $PSCmdlet.ThrowTerminatingError($_)
            }
            $completedSteps++
            #EndRegion
        }

        #Region: Generate GLP API credential
        if ($MyWorkspaceName -and -not $Force) {

            #Region: [STEP 3]: Create GLP API credential
            Write-Verbose " ----------------------------------STEP 3--------------------------------------------------------------------------------"
            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Creating API credential" -Id 1
            $step++
            Write-Verbose ("[{0}] Step 3: Create new API credential" -f $functionName)

            $APIClientCredentialTemplateName = Get-APIClientCredentialTemplateName
            "[{0}] Using API client credential template: {1}" -f $functionName, $APIClientCredentialTemplateName | Write-Verbose

            try {
                if ($RemoveExistingCredentials) {
                    "[{0}] Removing existing API credentials created by this library using template name: {1}" -f $functionName, $APIClientCredentialTemplateName | Write-Verbose
                    $APIcredentials = Get-HPEGLAPICredential | Where-Object { $_.name -match $APIClientCredentialTemplateName -or $_.name -eq "GLP-PowerShell_Library_Temporary_Credential" -or $_.name -match "COM_PowerShell_Library_Temp_Credential" }
                                   
                    "[{0}] Found {1} existing API credentials to remove." -f $functionName, $APIcredentials.Count | Write-Verbose

                    if ($APIcredentials) {
                        '[{0}] Found existing API credentials: {1}' -f $functionName, ($APIcredentials | Select-Object -ExpandProperty name -Unique) | Write-Verbose
                        $APIcredentials | Remove-HPEGLAPICredential -Force | Out-Null
                        "[{0}] Existing API credentials removed." -f $functionName | Write-Verbose
                    }
                }
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                    Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                $PSCmdlet.ThrowTerminatingError($_)
            }

            try {
                
                $global:HPEGLAPIClientCredentialName = "$APIClientCredentialTemplateName`_$((Get-Date).ToString('yyMMdd_HHmm_ss'))"
                $GLPAPICreationTask = New-HPEGLAPIcredential -HPEGreenLake -TemplateName $global:HPEGLAPIClientCredentialName -ErrorAction Stop

                if ($GLPAPICreationTask.status -ne "Complete") {
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                        Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "API Credential creation failed: $($GLPAPICreationTask.Exception)"
                }
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                    Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                $ErrorMessage = $_.Exception.Message
                if ($ErrorMessage -match "You have reached the maximum of 7 personal API clients") {
                    Throw "You have reached the maximum limit of 7 personal API clients. A possible fix is to use the -RemoveExistingCredentials parameter when connecting to automatically remove previously generated credentials created by this library.`nCaution: Removing existing credentials may impact other active library sessions related to your user that are currently using those credentials. This could cause authentication failures in other running PowerShell sessions until they reconnect."
                }
                else {
                    Throw "Failed to create HPE GreenLake API credential: $ErrorMessage"
                }

            }
            $completedSteps++
            #EndRegion Create GLP API credential

            #Region: [STEP 4]: Create session with new GLP API credential
            Write-Verbose " ----------------------------------STEP 4--------------------------------------------------------------------------------"
            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Creating session" -Id 1
            $step++
            Write-Verbose ("[{0}] Step 4: Create new API session" -f $functionName)
            $GLPTemporaryCredentials = $Global:HPEGreenLakeSession.apiCredentials | Where-Object { $_.name -match "GLP-$Global:HPEGLAPIClientCredentialName" }
            if ($GLPTemporaryCredentials) {
                "[{0}] Found temporary GLP credentials '{1}'" -f $functionName, $GLPTemporaryCredentials.name | Write-Verbose
                try {
                    $SecureClientSecret = $GLPTemporaryCredentials.secure_client_secret | ConvertTo-SecureString
                    $Bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureClientSecret)
                    $ClientSecret = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($Bstr)
                    $Payload = @{
                        'client_id'     = $GLPTemporaryCredentials.client_id
                        'client_secret' = $ClientSecret
                        'grant_type'    = 'client_credentials'
                    }
                    "[{0}] Getting token from URI: {1}" -f $functionName, $HPEGLtokenEndpoint | Write-Verbose
                    $response = Invoke-RestMethod -Method Post -Uri $HPEGLtokenEndpoint -Body $Payload -ContentType 'application/x-www-form-urlencoded'
                    $Global:HPEGreenLakeSession.glpApiAccessToken = [PSCustomObject]@{
                        name          = $GLPTemporaryCredentials.name
                        access_token  = $response.access_token
                        expires_in    = $response.expires_in
                        creation_time = Get-Date
                    }

                    $tokenIssuerv2uri = (Get-HPEGLAPIbaseURL) + "/authorization/v2/oauth2/" + $Global:HPEGreenLakeSession.workspaceId + "/token"
                    "[{0}] Getting v2 token from URI: {1}" -f $functionName, $tokenIssuerv2uri | Write-Verbose
                    $response2 = Invoke-RestMethod -Method Post -Uri $tokenIssuerv2uri -Body $Payload -ContentType 'application/x-www-form-urlencoded'
                    $token = Get-HPEGLJWTDetails $response2.access_token
                    $tokenVersion = if ($token.PSObject.Properties.Match("hpe_token_type")) { $token.hpe_token_type } else { "api-v1.1" }
                    if ($tokenVersion -eq "api-v1.2") {
                        $Global:HPEGreenLakeSession.glpApiAccessTokenv1_2 = [PSCustomObject]@{
                            name          = $GLPTemporaryCredentials.name
                            access_token  = $response2.access_token
                            expires_in    = $response2.expires_in
                            creation_time = Get-Date
                        }
                    }
                    else {
                        $Global:HPEGreenLakeSession.glpApiAccessTokenv1_2 = $null
                    }
                }
                catch {
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                        Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    $PSCmdlet.ThrowTerminatingError($_)
                }
            }
            $completedSteps++
            #EndRegion Create GLP session

            #Region: [STEP 5]: Set COM regions
            Write-Verbose " ----------------------------------STEP 5--------------------------------------------------------------------------------"
            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Setting COM regions" -Id 1
            $step++
            Write-Verbose ("[{0}] Step 5: Setting COM regions" -f $functionName)
            $Global:HPECOMRegions = [System.Collections.ArrayList]::new()
            try {
                $AvailableCOMInstances = Get-HPEGLService -ShowProvisioned -Name 'Compute Ops Management'
                foreach ($COMInstance in $AvailableCOMInstances) {
                    $url = "https://aquila-user-api.common.cloud.hpe.com/authn/v1/onboarding/login-url/" + $COMInstance.application_instance_id
                    "[{0}] About to run a GET {1} " -f $functionName, $url | Write-Verbose
                    $LoginURLResponse = Invoke-RestMethod -Method Get -Uri $url -Headers $headers -WebSession $Global:HPEGreenLakeSession.WorkspaceSession #-AllowInsecureRedirect
                    "[{0}] Login URL response: {1}" -f $functionName, $LoginURLResponse | Write-Verbose
                    $LoginURL = $LoginURLResponse.login_url
                    if (-not $LoginURL) {
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                            Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        throw "Failed to retrieve login URL for COM instance: $($COMInstance.application_instance_id)"
                    }
                    $Global:HPECOMRegions += [PSCustomObject]@{
                        region   = $COMInstance.region
                        loginUrl = $LoginURL
                    }
                    # [void]$Global:HPECOMRegions.Add($COMInstance.region)
                }
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                    Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                $PSCmdlet.ThrowTerminatingError($_)
            }
            $completedSteps++
            #EndRegion Set COM regions

            #Region: [STEP 6] Generate $Global:HPECOMjobtemplatesUris variable to store all COM job templates
            Write-Verbose " ----------------------------------STEP 6--------------------------------------------------------------------------------"
            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Generating global variable to store all COM job templates" -Id 1
            $step++
            if (-not $Global:HPECOMjobtemplatesUris) {
                if ($Global:HPECOMRegions.count -gt 0) {
                    "[{0}] Step 6: `$Global:HPECOMjobtemplatesUris is not defined, generating it..." -f $functionName | Write-Verbose
                    $FirstProvisionedCOMRegion = $Global:HPECOMRegions | Select-Object -first 1 | Select-Object -ExpandProperty region
                    try {
                        Set-HPECOMJobTemplatesVariable -region $FirstProvisionedCOMRegion
                    }
                    catch {
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                            Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        $PSCmdlet.ThrowTerminatingError($_)
                    }
                }
                elseif ($Global:HPECOMRegions.count -eq 0) {
                    "[{0}] Step 6: Skipping the initialization of `$Global:HPECOMjobtemplatesUris as no COM regions are available." -f $functionName, $step | Write-Verbose
                }
            }
            else {
                "[{0}] Step 6: `$Global:HPECOMjobtemplatesUris is already defined, skipping generation." -f $functionName | Write-Verbose
            }
            
            $completedSteps++
            #EndRegion Generate COM job template variables

        }

        #EndRegion Generate GLP API credential

        #Region: Get organization governance
        if (-not $Force) {
            Write-Verbose " ----------------------------------STEP 7--------------------------------------------------------------------------------"
            "[{0}] STEP 7 - Getting organization governance" -f $functionName | Write-Verbose
            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Getting organization governance" -Id 1
            $step++

            try {
                $OrganizationGovernance = Get-HPEGLOrganization -ShowCurrent
                if ($OrganizationGovernance -and $OrganizationGovernance.name -and $OrganizationGovernance.id) {
                    $Global:HPEGreenLakeSession.organization = $OrganizationGovernance.name
                    $Global:HPEGreenLakeSession.organizationId = $OrganizationGovernance.id
                }
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                    Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                $PSCmdlet.ThrowTerminatingError($_)
            }
            $completedSteps++
        }
        #EndRegion Get organization governance

    }

    End {
        "[{0}] Connection process completed" -f $functionName | Write-Verbose
        if (-not $NoProgress) {
            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Completed" -Id 1
            Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Completed" -Completed
            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Completed" -Completed
        }
        return $Global:HPEGreenLakeSession
    }
}

Function Invoke-HPEGLAutoReconnect {
    <#
    .SYNOPSIS
        Manages HPE GreenLake session token refresh for HPE GreenLake API access tokens.

    .DESCRIPTION
        Checks the expiration status of HPE GreenLake API access tokens and refreshes them if they're close to expiring or if the Force parameter is specified.
        Throws an error if the session is already expired, requiring a new connection via Connect-HPEGL.

    .PARAMETER Force
        Forces a refresh of HPE GreenLake API access tokens regardless of their expiration status.

    .EXAMPLE
        Invoke-HPEGLAutoReconnect 
        Checks and refreshes the access tokens if they're about to expire.

    .EXAMPLE
        Invoke-HPEGLAutoReconnect -Force
        Forces a refresh of the access tokens immediately.

    .NOTES
        - HPE GreenLake public API access token validity: 15 minutes (v1.2) or 120 minutes (v1.1)
        - Requires $Global:HPEGreenLakeSession global variable to be set
    #>

    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    Begin {
        # Validate session existence
        if (-not $Global:HPEGreenLakeSession) {
            Throw "No HPE GreenLake session found! Connect-HPEGL must be executed first!"
        }

        # Initialize variables
        $currentTime = Get-Date
        $functionName = $MyInvocation.InvocationName.ToString().ToUpper()
    }

    Process {

        try {
            # Check if the session is still valid
            if ($Global:HPEGreenLakeSession.glpApiAccessTokenv1_2) {
                $glpToken = $Global:HPEGreenLakeSession.glpApiAccessTokenv1_2[0]
                $Timeout = 2 # v1.2 token validity is 15 minutes
                $glpExpiration = $glpToken.creation_Time.AddSeconds($glpToken.expires_in)
            }
            elseif ($Global:HPEGreenLakeSession.glpApiAccessToken) {
                $glpToken = $Global:HPEGreenLakeSession.glpApiAccessToken[0]
                $Timeout = 110 # v1.1 token validity is 120 minutes
                $glpExpiration = $glpToken.creation_Time.AddSeconds($glpToken.expires_in)
            }
            else {
                $Timeout = 110 # token validity is 120 minutes
                $glpExpiration = $Global:HPEGreenLakeSession.oauth2TokenCreation.AddMinutes(120)
            }
            
            $minutesToGlpExpiration = [math]::Round(($glpExpiration - $currentTime).TotalMinutes, 2)       

            if ($minutesToGlpExpiration -le 0) {
                Throw "HPE GreenLake session has expired! Please reconnect using Connect-HPEGL."
            }
            elseif ($Force -or $minutesToGlpExpiration -le $Timeout) {
                "[{0}] GLP API Access Token is expiring in {1} minute(s) or Force refresh requested. Refreshing token..." -f $functionName, $minutesToGlpExpiration | Write-Verbose
                try {
                    Connect-HPEGLWorkspace -Force -ErrorAction Stop | Out-Null
                    "[{0}] GLP API Access Token refreshed successfully." -f $functionName | Write-Verbose
                }
                catch {
                    "[{0}] Failed to refresh GLP API Access Token: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                    throw $_
                }
            }
            else {
                "[{0}] GLP API Access Token is valid for {1} more minute(s). No refresh needed." -f $functionName, $minutesToGlpExpiration | Write-Verbose
            }
        }
        catch {
            Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
            $PSCmdlet.ThrowTerminatingError($_)
        }
    }
}

function Get-HPEGLJWTDetails {
    [cmdletbinding()]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [string]$token
    )
  
    <#
  
  .SYNOPSIS
  Decode a JWT Access Token and convert to a PowerShell Object.
  JWT Access Token updated to include the JWT Signature (sig), JWT Token Expiry (expiryDateTime) and JWT Token time to expiry (timeToExpiry).
  
  .DESCRIPTION
  Decode a JWT Access Token and convert to a PowerShell Object.
  JWT Access Token updated to include the JWT Signature (sig), JWT Token Expiry (expiryDateTime) and JWT Token time to expiry (timeToExpiry).
  
  Thanks to Darren Robinson for this function!
  https://github.com/darrenjrobinson/JWTDetails
  https://blog.darrenjrobinson.com

  .PARAMETER token
  The JWT Access Token to decode and update with expiry time and time to expiry
  
  .INPUTS
  Token from Pipeline 
  
  .OUTPUTS
  PowerShell Object
  
  .EXAMPLE
  Get-HPEGLJWTDetails
  
  .EXAMPLE
  PS> Get-HPEGLJWTDetails($myAccessToken)
  or 
  PS> $myAccessToken | Get-JWTDetails
  tenant_id             : cd988f3c-710c-43eb-9e25-123456789
  internal              : False
  pod                   : uswest2
  org                   : myOrd
  identity_id           : 1c818084624f8babcdefgh9a4
  user_name             : adminDude
  strong_auth_supported : True
  user_id               : 100666
  scope                 : {read, write}
  exp                   : 1564474732
  jti                   : 1282411c-ffff-1111-a9d0-f9314a123c7a
  sig                   : SWPhCswizzleQWdM4K8A8HotX5fP/PT8kBWnaaAf2g6k=
  expiryDateTime        : 30/07/2019 6:18:52 PM
  timeToExpiry          : -00:57:37.4457299
  
  #>
  
    if (!$token.Contains(".") -or !$token.StartsWith("eyJ")) { Write-Error "Invalid token" -ErrorAction Stop }
  
    # Token
    foreach ($i in 0..1) {
        $data = $token.Split('.')[$i].Replace('-', '+').Replace('_', '/')
        switch ($data.Length % 4) {
            0 { break }
            2 { $data += '==' }
            3 { $data += '=' }
        }
    }
  
    $decodedToken = [System.Text.Encoding]::UTF8.GetString([convert]::FromBase64String($data)) | ConvertFrom-Json 
    # "[{0}] JWT Token: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $decodedToken | Write-Verbose

  
    # Signature
    foreach ($i in 0..2) {
        $sig = $token.Split('.')[$i].Replace('-', '+').Replace('_', '/')
        switch ($sig.Length % 4) {
            0 { break }
            2 { $sig += '==' }
            3 { $sig += '=' }
        }
    }
    # "[{0}] JWT Signature: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $sig | Write-Verbose

    $decodedToken | Add-Member -Type NoteProperty -Name "sig" -Value $sig
  
    # Convert Expiry time to PowerShell DateTime
    $orig = (Get-Date -Year 1970 -Month 1 -Day 1 -hour 0 -Minute 0 -Second 0 -Millisecond 0)
    $timeZone = Get-TimeZone
    $utcTime = $orig.AddSeconds($decodedToken.exp)
    $offset = $timeZone.GetUtcOffset($(Get-Date)).TotalMinutes #Daylight saving needs to be calculated
    $localTime = $utcTime.AddMinutes($offset)     # Return local time,
      
    $decodedToken | Add-Member -Type NoteProperty -Name "expiryDateTime" -Value $localTime
      
    # Time to Expiry
    $timeToExpiry = ($localTime - (get-date))
    $decodedToken | Add-Member -Type NoteProperty -Name "timeToExpiry" -Value $timeToExpiry
  
    return $decodedToken
}


#Region Private functions

function Test-EndpointTCPConnection {
    [CmdletBinding()] 
    param (
        [uri]$URL,
        [int]$Port = 443,
        [int]$Timeout = 5000, # 5000 milliseconds (5 seconds)
        [int]$RetryCount = 3  # Number of retry attempts
    )

    # Get progress bar actual settings 
    $OriginalProgressPreference = $Global:ProgressPreference
    # Disable progress bar
    $Global:ProgressPreference = 'SilentlyContinue'

    try {
        # Construct the target URL with port
        $targetUrl = if ($Port -eq 443 -and $URL.Scheme -eq "https") { $URL.ToString() } else { "$($URL.Scheme)://$($URL.Host):$Port" }
        "[{0}] Testing connectivity to: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $targetUrl | Write-Verbose

        for ($i = 0; $i -lt $RetryCount; $i++) {
            try {
                # Send a GET request to test connectivity
                $response = Invoke-WebRequest -Uri $targetUrl -Method Get -UseBasicParsing -TimeoutSec ($Timeout / 1000) -ErrorAction Stop

                if ($response.StatusCode -eq 200) {
                    "[{0}] '{1}' is reachable on port {2}. Status code: 200 OK" -f $MyInvocation.InvocationName.ToString().ToUpper(), $URL, $Port | Write-Verbose
                    return 
                }
                else {
                    $Global:ProgressPreference = $OriginalProgressPreference
                    "[{0}] '{1}' is reachable on port {2}, but returned status code: {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $URL, $Port, $response.StatusCode | Write-Verbose
                    throw "Failed to connect to $($URL) on port $($Port). Status code: $($response.StatusCode)"
                }
            } 
            catch {
                $errorMessage = $_.Exception.Message
                if ($i -eq $RetryCount - 1) {
                    "[{0}] {1} is unreachable after {2} attempts. Error: {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $URL, $RetryCount, $errorMessage | Write-Verbose
                    throw "$($URL) is unreachable after $RetryCount attempts. Error: $errorMessage"
                }
                else {
                    "[{0}] Attempt {1} failed to reach {2}. Error: {3}. Retrying..." -f $MyInvocation.InvocationName.ToString().ToUpper(), ($i + 1), $URL, $errorMessage | Write-Verbose
                    Start-Sleep -Seconds 2  # Wait for 2 seconds before retrying
                }
            }
        }
    } 
    finally {
        # Return to original progress bar global settings
        $Global:ProgressPreference = $OriginalProgressPreference
    }
}


function Test-EndpointDNSResolution {
    [CmdletBinding()] 
    param (

        [uri]$URL,
        [int]$RetryCount = 3   # Number of retry attempts

    )

    # Get progress bar actual settings 
    $OriginalProgressPreference = $Global:ProgressPreference
    # Disable progress bar
    $Global:ProgressPreference = 'SilentlyContinue'

    for ($i = 0; $i -lt $RetryCount; $i++) {

        try {
            
            ([System.Net.Dns]::GetHostAddresses($URL)) | Out-Null
            
            "[{0}] '{1}' is DNS resolvable." -f $MyInvocation.InvocationName.ToString().ToUpper(), $URL | Write-Verbose
            return
    
        } 
        catch {

            if ($i -eq $RetryCount - 1) {
                
                # Return to original progress bar global settings
                $Global:ProgressPreference = $OriginalProgressPreference
                "[{0}] {1} is not DNS resolvable after {2} attempts. Fix your network environment and try again." -f $MyInvocation.InvocationName.ToString().ToUpper(), $url, $RetryCount | Write-Verbose

                throw "$($URL) is not DNS resolvable after $RetryCount attempts. Fix your network environment and try again."
            } 
            else {
    
                "[{0}] Attempt {1} failed to resolve {2}. Retrying..." -f $MyInvocation.InvocationName.ToString().ToUpper(), ($i + 1), $URL | Write-Verbose
                Start-Sleep -Seconds 2  # Wait for 2 seconds before retrying
            }
        }
        finally {
    
            # Return to original progress bar global settings
            $Global:ProgressPreference = $OriginalProgressPreference
    
        }
    }
} 


function Invoke-RestMethodWhatIf {   
    Param   (   
        $Uri,
        $Method,
        $Headers,
        $Websession,
        $ContentType,
        $Body,
        [ValidateSet ('Invoke-HPEGLWebRequest', 'Invoke-HPECOMWebRequest', 'Invoke-RestMethod', 'Invoke-WebRequest')]
        $Cmdlet
    )
    process {
        if ( -not $Body ) {
            $Body = 'No Body provided'
        }
        write-warning "You have selected the 'What-If' option; therefore, the call will not be made. Instead, you will see a preview of the REST API call."
        Write-host "The cmdlet executed for this call will be:" 
        write-host  "$Cmdlet" -ForegroundColor green
        Write-host "The URI for this call will be:" 
        write-host  "$Uri" -ForegroundColor green
        Write-host "The Method of this call will be:"
        write-host -ForegroundColor green $Method

        if ($headers) {
            Write-host "The Header for this call will be:"
            $headerString = ($Headers | ConvertTo-Json) -Replace 'Bearer \S+', 'Bearer [REDACTED]' | Out-String
            $headerString = $headerString.TrimEnd("`r", "`n")
            Write-host -ForegroundColor green $headerString
        }
        if ($websession) {
            Write-host "The Websession for this call will be:"
            $websessionString = ($websession.headers | ConvertTo-Json) -Replace 'Bearer \S+', 'Bearer [REDACTED]' | Out-String
            $websessionString = $websessionString.TrimEnd("`r", "`n")
            write-host -ForegroundColor green $websessionString
        }
        if ( $ContentType ) {
            write-host "The Content-Type is set to:"
            write-host -ForegroundColor green $ContentType
        }  
        if ( $Body ) {
            write-host "The Body of this call will be:"
            write-host -foregroundcolor green ($Body -Replace '"access_token"\s*:\s*"[^"]+"', '"access_token": "[REDACTED]"' | Out-String)
        }
    }
}


function Set-HPECOMJobTemplatesVariable {
    <#
    .DESCRIPTION
    The cmdlet retrieves and stores the details for each COM job template in the $Global:HPECOMjobtemplatesUris global variable.
    The Cmdlet is automatically executed the first time Connect-HPEWorkspace and Invoke-HPECOMWebRequest is run.

    To get the URI of a job template, you can use:
    $Global:HPECOMjobtemplatesUris | Where-Object name -eq PowerOn.New | Select-Object -Expand resourceUri

    .EXAMPLE
    Set-HPECOMJobTemplatesVariable 
    
    Retreive the details for each COM job template and save them in the $Global:HPECOMjobtemplatesUris global variable
    #>
    [CmdletBinding()]

    $HPECOMjobtemplatesUrisList = [System.Collections.ArrayList]::new()
    
    if ($Global:HPECOMRegions) {
        
        $_Region = $Global:HPECOMRegions | Select-Object -First 1 -ExpandProperty region
        "[{0}] Region selected: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_Region | Write-Verbose

        $ConnectivityEndPoint = "https://$_Region.api.greenlake.hpe.com"
        
        # Use the v1_2 access token if available
        if ($Global:HPEGreenLakeSession.glpApiAccessTokenv1_2.access_token) {
            $glpApiAccessToken = $Global:HPEGreenLakeSession.glpApiAccessTokenv1_2.access_token

        } 
        # Use the v1_1 access token if available
        elseif ($Global:HPEGreenLakeSession.glpApiAccessToken.access_token) {
            $glpApiAccessToken = $Global:HPEGreenLakeSession.glpApiAccessToken.access_token
        }

        $COMJobTemplatesUri = Get-COMJobTemplatesUri
        $url = $ConnectivityEndPoint + $COMJobTemplatesUri
         
        $headers = @{} 
        $headers["Accept"] = "application/json"
        $headers["Content-Type"] = "application/json"
        $headers["Authorization"] = "Bearer $($glpApiAccessToken)"

        "[{0}] About to run a GET request to '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $url | Write-Verbose
        "[{0}] Headers used: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), (($headers | ConvertTo-Json) -Replace 'Bearer \S+', 'Bearer [REDACTED]') | Write-Verbose

        try {
            [array]$JobTemplates = (Invoke-RestMethod -Uri $url -Method 'GET' -Headers $Headers ).items
            # "[{0}] Response: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($JobTemplates | Out-String ) | Write-Verbose

        }   
        catch {    
            $PSCmdlet.ThrowTerminatingError($_)

        }

        foreach ($JobTemplate in $JobTemplates) {

            $object = @{
                name        = $JobTemplate.name
                resourceUri = $JobTemplate.resourceUri
                id          = $JobTemplate.id
            }
            
        
            [void]$HPECOMjobtemplatesUrisList.add($object)

        }

        # $HPECOMjobtemplatesUrisList = @(
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/5a657c6f-777d-4c7e-874a-1650b95b37f2"
        #         Id          = "5a657c6f-777d-4c7e-874a-1650b95b37f2"
        #         name        = "AnalyzeFirmwareUpdate"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/87f47eff-7245-4788-bf58-5b6af361d1ba"
        #         Id          = "87f47eff-7245-4788-bf58-5b6af361d1ba"
        #         name        = "AnalyzeFirmwareUpdateOrchestrator"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/1c4ac4be-8eeb-49f2-a86a-fd8c9182616c"
        #         Id          = "1c4ac4be-8eeb-49f2-a86a-fd8c9182616c"
        #         name        = "ApplianceUpdate"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/2d0f40f7-2a07-4c74-92e1-d1afaf49e632"
        #         Id          = "2d0f40f7-2a07-4c74-92e1-d1afaf49e632"
        #         name        = "ApplySettingsTemplate"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/497a5418-cbc2-4870-a1e7-1fc30c885f2f"
        #         Id          = "497a5418-cbc2-4870-a1e7-1fc30c885f2f"
        #         name        = "CalculateiLOSettingsCompliance"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/aacfb3e0-6575-4d4f-a711-1ee1ae768407"
        #         Id          = "aacfb3e0-6575-4d4f-a711-1ee1ae768407"
        #         name        = "ColdBoot"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/aae145a1-79a2-4516-b191-c98039c96542"
        #         Id          = "aae145a1-79a2-4516-b191-c98039c96542"
        #         name        = "CreateOneviewComplianceReport"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/b0001d36-6490-48ac-93af-a87adfb997ed"
        #         Id          = "b0001d36-6490-48ac-93af-a87adfb997ed"
        #         name        = "DataRoundupReportOrchestrator"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/fd54a96c-cabc-42e3-aee3-374a2d009dba"
        #         Id          = "fd54a96c-cabc-42e3-aee3-374a2d009dba"
        #         name        = "FirmwareUpdate.New"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/d6595f1b-84e6-4587-ade5-656e2a5ea20d"
        #         Id          = "d6595f1b-84e6-4587-ade5-656e2a5ea20d"
        #         name        = "GetFullServerInventory"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/fc16aa48-c73c-4463-9112-e061383ebfa9"
        #         Id          = "fc16aa48-c73c-4463-9112-e061383ebfa9"
        #         name        = "GetOneViewSettings"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/a0124cb1-00f1-46b7-818f-a9eb5f60591f"
        #         Id          = "a0124cb1-00f1-46b7-818f-a9eb5f60591f"
        #         name        = "GetOneviewServerInventory"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/50fa7d05-5941-4e8e-90c3-5995f1d600a8"
        #         Id          = "50fa7d05-5941-4e8e-90c3-5995f1d600a8"
        #         name        = "GetPowerMeterData"
        #     },
        #     @{
        #         resourceUri = "/api/compute/v1/job-templates/2c7de503-77af-4340-b68d-7a26e5359b8e"
        #         Id          = "2c7de503-77af-4340-b68d-7a26e5359b8e"
        #         name        = "GetSSOUrl"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/6cd671db-ce6b-45ce-894e-7b5ae23e0399"
        #         Id          = "6cd671db-ce6b-45ce-894e-7b5ae23e0399"
        #         name        = "GetSettingsForTemplate"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/c708eb57-235d-4ea8-9e21-8ceea2438773"
        #         # resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/54095626-3911-4fea-9741-816e2531994e"
        #         Id          = "c708eb57-235d-4ea8-9e21-8ceea2438773"
        #         # Id = "54095626-3911-4fea-9741-816e2531994e"
        #         name        = "GroupApplyInternalStorageSettings"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/a229a162-b43f-45b0-b7bb-692df77b9746"
        #         Id          = "a229a162-b43f-45b0-b7bb-692df77b9746"
        #         name        = "GroupApplyOneviewSettings"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/fcb79270-5954-42e9-9374-6a065b6d494a"
        #         Id          = "fcb79270-5954-42e9-9374-6a065b6d494a"
        #         name        = "GroupApplyExternalStorage"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/beff07ce-f36d-4699-9ac3-f872dcd63133"
        #         Id          = "beff07ce-f36d-4699-9ac3-f872dcd63133"
        #         name        = "GroupApplyServerSettings"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/db3620d4-19a4-4b54-9804-83f8f59d48a4"
        #         Id          = "db3620d4-19a4-4b54-9804-83f8f59d48a4"
        #         name        = "GroupCopyServerProfileTemplates"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/7177aa6a-e8f8-4e9b-ae31-e01dafcc81df"
        #         Id          = "7177aa6a-e8f8-4e9b-ae31-e01dafcc81df"
        #         name        = "GroupExternalStorageCompliance"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/23b8ba2a-6c46-4223-b028-919382c7dcac"
        #         Id          = "23b8ba2a-6c46-4223-b028-919382c7dcac"
        #         name        = "GroupFirmwareCompliance"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/91159b5e-9eeb-11ec-a9da-00155dc0a0c0"
        #         Id          = "91159b5e-9eeb-11ec-a9da-00155dc0a0c0"
        #         name        = "GroupFirmwareUpdate"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/08be2b1b-a9b3-4abb-82a2-8048f35dbccb"
        #         Id          = "08be2b1b-a9b3-4abb-82a2-8048f35dbccb"
        #         name        = "GroupGetIloSecurityParams"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/e2952628-2629-4088-93db-91742304ef0c"
        #         Id          = "e2952628-2629-4088-93db-91742304ef0c"
        #         name        = "GroupOSInstallation"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/2dfe138a-21b7-4797-8c6b-4d8e7e5f847c"
        #         Id          = "2dfe138a-21b7-4797-8c6b-4d8e7e5f847c"
        #         name        = "GroupServerInventoryReport"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/a55c8b26-3c57-4044-a4ee-1d0e3c108286"
        #         Id          = "a55c8b26-3c57-4044-a4ee-1d0e3c108286"
        #         name        = "GroupiLOSettingsCompliance"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/94caa4ef-9ff8-4805-9e97-18a09e673b66"
        #         Id          = "94caa4ef-9ff8-4805-9e97-18a09e673b66"
        #         name        = "IloOnlyFirmwareUpdate"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/abfda355-6e58-4c00-be0a-af35dbd70398"
        #         Id          = "abfda355-6e58-4c00-be0a-af35dbd70398"
        #         name        = "OrchestratorAddUpdateServerTemplates"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/d0c13b58-748c-461f-9a61-c0c5c71f1bb4"
        #         Id          = "d0c13b58-748c-461f-9a61-c0c5c71f1bb4"
        #         name        = "PowerOff.New"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/0cbb2377-1834-488d-840c-d5bf788c34fb"
        #         Id          = "0cbb2377-1834-488d-840c-d5bf788c34fb"
        #         name        = "PowerOn.New"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/30110551-cad6-4069-95b8-dbce9bbd8525"
        #         Id          = "30110551-cad6-4069-95b8-dbce9bbd8525"
        #         name        = "Restart.New"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/b21ca9e2-8a1b-11ee-b9d1-0242ac120002"
        #         Id          = "b21ca9e2-8a1b-11ee-b9d1-0242ac120002"
        #         name        = "ServerNetworkConnectivity"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/9310319e-7b7f-41ba-8b24-8b34eed1ca62"
        #         Id          = "9310319e-7b7f-41ba-8b24-8b34eed1ca62"
        #         name        = "GetServerExternalStorage"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/cf4f929b-d44a-4a90-93a9-820955458fd4"
        #         Id          = "cf4f929b-d44a-4a90-93a9-820955458fd4"
        #         name        = "SetIloSettings"
        #     },
        #     @{
        #         resourceUri = "/compute-ops-mgmt/v1beta2/job-templates/e1d69e76-38cc-4079-9192-a380baea2973"
        #         Id          = "e1d69e76-38cc-4079-9192-a380baea2973"
        #         name        = "iLOSecurity"
        #     }
        # ) | Sort-Object -Property name

        $Global:HPECOMjobtemplatesUris = $HPECOMjobtemplatesUrisList

        "[{0}] Each COM job template has been stored in the `$Global:HPECOMjobtemplatesUris global variable." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

    }
    else {
        "[{0}] Global variable `$global:HPECOMjobtemplatesUris cannot be set as no COM API client credential can be found for '{1}' region" -f $MyInvocation.InvocationName.ToString().ToUpper(), $region | Write-Verbose
    }

}


function Get-GMTTimeDifferenceInHours {
    # Function to get the current time difference between GMT and the local computer time zone

    [CmdletBinding()]
    Param(

        [switch]$InMinutes

    )

    # Get current date and time in UTC (GMT)
    $utcNow = [DateTime]::UtcNow

    # Define TimeZoneInfo objects for GMT and Local Time Zone
    $localTimeZone = [System.TimeZoneInfo]::Local                        # Local Computer Time Zone

    # Convert UTC to Local Time
    $localTime = [System.TimeZoneInfo]::ConvertTimeFromUtc($utcNow, $localTimeZone)

    # Calculate the time difference
    $timeDifferenceinHours = ($localTime - $utcNow).TotalHours
    $timeDifferenceinMinutes = ($localTime - $utcNow).TotalMinutes

    # Check if the current date/time falls within Daylight Saving Time
    $isDaylightSaving = $localTimeZone.IsDaylightSavingTime($localTime)

    # Display the detected local time zone, DST status, and the time difference
    "[{0}] Detected local time zone: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $localTimeZone.Id | Write-Verbose
    "[{0}] Is the current time in Daylight Saving Time? '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $isDaylightSaving | Write-Verbose
    "[{0}] Current time difference between GMT and local time: '{1}' hour(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), [Math]::Round($timeDifferenceinHours, 0) | Write-Verbose
    "[{0}] Current time difference between GMT and local time: '{1}' minutes(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), [Math]::Round($timeDifferenceinMinutes, 0) | Write-Verbose
       
    if ($InMinutes) {
        Return $timeDifferenceinMinutes
    }
    else {
        Return $timeDifferenceinHours
    }

}

# Helper function to get the JSON depth
# This function calculates the maximum depth of nested JSON objects or arrays
function Get-JsonDepth {
    [CmdletBinding()]
    param([string]$JsonString)
    
    $maxDepth = 0
    $currentDepth = 0
    $inString = $false
    $escaped = $false

    if ([string]::IsNullOrEmpty($JsonString)) {
        Write-Verbose "[$($MyInvocation.InvocationName)] JSON string is null or empty"
        return 0
    }
    
    foreach ($char in $JsonString.ToCharArray()) {
        if ($escaped) {
            $escaped = $false
            continue
        }
        
        switch ($char) {
            '\' { if ($inString) { $escaped = $true } }
            '"' { $inString = -not $inString }
            '{' { if (-not $inString) { $currentDepth++; $maxDepth = [Math]::Max($maxDepth, $currentDepth) } }
            '}' { if (-not $inString) { $currentDepth-- } }
            '[' { if (-not $inString) { $currentDepth++; $maxDepth = [Math]::Max($maxDepth, $currentDepth) } }
            ']' { if (-not $inString) { $currentDepth-- } }
        }
    }
    
    return $maxDepth
}

# Helper function to test if the content is in JSON format
# This function performs a basic check to see if the content looks like JSON
function Test-JsonFormat {
    [CmdletBinding()]
    param(
        [string]$Content,
        [string]$InvocationName
    )
    
    # Basic format check only
    if ([string]::IsNullOrWhiteSpace($Content)) {
        "[{0}] Content is null or empty" -f $InvocationName | Write-Verbose
        return $false
    }
    
    $trimmed = $Content.Trim()
      
    # Check if it looks like JSON
    $looksLikeJson = ($trimmed.StartsWith('{') -and $trimmed.EndsWith('}')) -or 
    ($trimmed.StartsWith('[') -and $trimmed.EndsWith(']'))
    
    if ($looksLikeJson) {
        "[{0}] Content appears to be JSON format" -f $InvocationName | Write-Verbose
        return $true
    }
    else {
        "[{0}] Content does not appear to be JSON format" -f $InvocationName | Write-Verbose
        return $false
    }
}

# Helper function to implement case-sensitive JSON parsing in PowerShell 7+
# This function uses System.Text.Json to parse JSON with case sensitivity
function ConvertFrom-JsonCaseSensitive {
    param(
        [string]$JsonString,
        [int]$MaxDepth = 64,
        [string]$InvocationName = "UNKNOWN"
    )
    
    try {
        # Configure JsonDocumentOptions (not JsonSerializerOptions for JsonDocument.Parse)
        $documentOptions = [System.Text.Json.JsonDocumentOptions]::new()
        $documentOptions.MaxDepth = $MaxDepth
        $documentOptions.AllowTrailingCommas = $true
        $documentOptions.CommentHandling = [System.Text.Json.JsonCommentHandling]::Skip
        
        # "[{0}] Using System.Text.Json with case-sensitive parsing at depth {1}" -f $InvocationName, $MaxDepth | Write-Verbose
        
        # Parse JSON to JsonDocument with correct options type
        $jsonDocument = [System.Text.Json.JsonDocument]::Parse($JsonString, $documentOptions)
        
        # Convert to PowerShell object
        $result = ConvertJsonElementToPSObject -JsonElement $jsonDocument.RootElement
        
        $jsonDocument.Dispose()
        return $result
    }
    catch {
        throw "Failed to parse JSON with case-sensitive options: $($_.Exception.Message)"
    }
}

# Helper function to convert JsonElement to PowerShell objects
# This function recursively converts JsonElement to PSCustomObject or array
function ConvertJsonElementToPSObject {
    param([System.Text.Json.JsonElement]$JsonElement)
    
    switch ($JsonElement.ValueKind) {
        'Object' {
            # Use a hashtable first to preserve case sensitivity, then convert
            $hashtable = @{}
            foreach ($property in $JsonElement.EnumerateObject()) {
                $propertyValue = ConvertJsonElementToPSObject -JsonElement $property.Value
                $hashtable[$property.Name] = $propertyValue
            }
            # Convert hashtable to PSCustomObject (preserves case-sensitive keys)
            return [PSCustomObject]$hashtable
        }
        'Array' {
            $array = @()
            foreach ($element in $JsonElement.EnumerateArray()) {
                $array += ConvertJsonElementToPSObject -JsonElement $element
            }
            return $array
        }
        'String' {
            return $JsonElement.GetString()
        }
        'Number' {
            if ($JsonElement.TryGetInt64([ref]$null)) {
                return $JsonElement.GetInt64()
            }
            else {
                return $JsonElement.GetDouble()
            }
        }
        'True' {
            return $true
        }
        'False' {
            return $false
        }
        'Null' {
            return $null
        }
        default {
            return $JsonElement.ToString()
        }
    }
}

function Invoke-RepackageObjectWithType {
    Param (
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

#EndRegion



# Export only public functions and aliases
Export-ModuleMember -Function 'Invoke-HPEGLWebRequest', 'Invoke-HPECOMWebRequest', 'Connect-HPEOnepass', 'Connect-HPEGL', 'Disconnect-HPEGL', 'Connect-HPEGLWorkspace', 'Invoke-HPEGLAutoReconnect', 'Get-HPEGLJWTDetails' -Alias *

# SIG # Begin signature block
# MIIungYJKoZIhvcNAQcCoIIujzCCLosCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBlR1QvZZqls4GC
# 553FnPd9nAP7J9hUzCfKZ5eF7Tt2JqCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQgk5Wl8pjlkb3yZXhkFp+nWZbvmDnWlIjbtc3A/ThUDPwwDQYJKoZIhvcNAQEB
# BQAEggIAg41kiKcZMQcnhLO6w3DLtnMv77BJ+JZ0IkBzbiALBo8dX6f5cuW1vlu4
# uwyKOyw1B33zPyo6u9lbztJJCJk4IBLk5Ur64e4TFCOuaG5Cc+rYe2ymsxETxs1Y
# 8M0HbrOvRUuLtoSmiNt4qwi6gYJYPUoLb7c8zdb5PuobtKxFBY0jBe6PlPGATbwx
# Jslsp2L0BYAA4zS31XyOg40sozrd6TmZTqnI2/KvOlJmEWvp0TmGgPqCee8nO8Yn
# fUvUyYWsRi1WGo+zmI8g2WNPIavAL40pT4CUDxLps7Y9bP/h2eKu769aPIgG0HsF
# r5omxwGBZN6UDR7u4Y6XODuQ+8oh2+jKu2UH2fcI3qUJTT8u5DzdsBCcIOfg5xCH
# dlS7ka58MOomAwcUE9b4cppi14r6FfNNC/RGK+Y4k48Uuu6sO8S19aQIEU0YwjTv
# jy1uKS+dFH3BNJ1w3AP4EKNU4ZBIvsb288a6WlGpYkCgDR3lbmV13pUeV087WZ69
# pFCwXvuFLlzW5J7PzozZBepL4L0VRD/R0h9rr0Nj+F5LCWgRbDQXAui/W7Ckk1WN
# ybnFGm5xwJXxuY9RgbSofYwWXpzeySvyef+XvaeI8XmbGiXz5Pc1sUqRx8ufgE2m
# bN9VdYG4e0KmZy6oGtzoJQFnhhunEZUmy713h3S0h+npHs1x8ZWhghjoMIIY5AYK
# KwYBBAGCNwMDATGCGNQwghjQBgkqhkiG9w0BBwKgghjBMIIYvQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBBwYLKoZIhvcNAQkQAQSggfcEgfQwgfECAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQwxhNVhMYVUz1r3Z4EMDIA43DkRO66s4PDSOU1
# X175ttwQdS2kUAbKTaP74kL8r9n/AhQzaNQGB19969GiCkVQeir3ztnmJBgPMjAy
# NTEwMTMxMjAyNTNaoHakdDByMQswCQYDVQQGEwJHQjEXMBUGA1UECBMOV2VzdCBZ
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
# DxcNMjUxMDEzMTIwMjUzWjA/BgkqhkiG9w0BCQQxMgQwz3Z0VdYdlUpraBy2rYW4
# Gv5xGJ33eTmFEy22lTM71oT6lD7h/MmJj+ljuGOc54pBMIIBegYLKoZIhvcNAQkQ
# AgwxggFpMIIBZTCCAWEwFgQUOMkUgRBEtNxmPpPUdEuBQYaptbEwgYcEFMauVOR4
# hvF8PVUSSIxpw0p6+cLdMG8wW6RZMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRpbWUgU3Rh
# bXBpbmcgUm9vdCBSNDYCEHojrtpTaZYPkcg+XPTH4z8wgbwEFIU9Yy2TgoJhfNCQ
# NcSR3pLBQtrHMIGjMIGOpIGLMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKTmV3
# IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBVU0VS
# VFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZpY2F0
# aW9uIEF1dGhvcml0eQIQNsKwvXwbOuejs902y8l1aDANBgkqhkiG9w0BAQEFAASC
# AgA6RLFcEG4dJjU8t34CxgARD8ZQywDypwyTiqQko8nlmlB+Hu1yeQfEwIHFf0/B
# bT29raltmuv0yzY9xkRW+nfQPc6NXbB4CMMuolmdQORWx6HZ8uZfmCinzXmvoj8d
# oDbC1Oh7ur/GPCu7NZeIauvQGnUWkGkLSNWNbnF+BFmxvBnxiT4JzDAH/mdnSz68
# tfOaWftA2oLm2DnJrmXu8yJVsRdOCKaRQ+GZNgkv8Zd/2xILQNYCFxb/0h4c1Y5Q
# 0pYmGmVqxlRmyymKjIQIoLXynTFCzxNBT1a4o9Shvu1t91ssEBEmb+xv3bbFMwz5
# qfCo8svYng6Z/KAYYjwwZl7hkYHVpYSyi3v/Vik1U0/5QVaRs63u3JItC5rVna+O
# NgO1ZsslXjZsYqG26khv7WQ3NqWpeN/7klZygGlBfbPJvmYhSH3bpKXFd2VYJNyY
# bhtETt1fAiCIvDvVclVwLSEKtsJib532Zcd37sQeaszUHPEVYRTk0h0PRc26woXy
# JyuaXzWv5j14HTkhqLCZ/4EtA8kpG5vGlQdzFj9z/9HqMLJjhDb9biLATjPO+5Oj
# kfMcsvacVDg6ZIISKN/J11xIqABZkY7bGiRP//mCjf9wyXw8aqVbkBh1tzR6y5u/
# MJL1SiJdfGsf35xnDVZJBFV50oK09oYeXllkP/kEbh2bgQ==
# SIG # End signature block
