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
                Write-Error @"
No active HPE GreenLake workspace session found.

Please run 'Connect-HPEGLWorkspace' to establish a session before using this cmdlet.
"@ -ErrorAction Stop

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
                    Write-Error @"
The COM region '$_' is not provisioned in this workspace! 

Please specify a valid region code (e.g., 'us-west', 'eu-central'). 

You can retrieve the region code using: Get-HPEGLService -Name 'Compute Ops Management' -ShowProvisioned
You can also use the Tab key for auto-completion to see the list of provisioned region codes.
"@ -ErrorAction Stop
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
                Write-Error @"
No provisioned COM region found in the current workspace.

Please ensure that at least one COM region is provisioned.

You can provisioned regions using 'New-HPEGLService'.
"@ -ErrorAction Stop
            }
        }
       
        #EndRegion
      

        #Region Check if COM API variable for the region is available + construct $url and pagination
        Clear-Variable -Name InvokeReturnData -ErrorAction SilentlyContinue

        "[{0}] Region selected: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose
    
        $GLPTemporaryCredentials = $Global:HPEGreenLakeSession.apiCredentials | Where-Object { $_.name -match "GLP-$global:HPEGLAPIClientCredentialName" }

        "[{0}] Credential found in `$Global:HPEGreenLakeSession.apiCredentials: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $GLPTemporaryCredentials.name | Write-Verbose

        if ($Null -eq $GLPTemporaryCredentials) {

            Write-Error @"
Error: No API credential found. 'Connect-HPEGL' must be executed first to establish a session and generate the required credentials.
"@ -ErrorAction Stop
             
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
                                                }
                                                else {
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
        throw "[{0}] Global HPEGreenLakeSession is not initialized. Please run Connect-HPEGL first to initialize the session." -f $functionName
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
                throw "[{0}] [OAUTH2 - Onepass] Failed to retrieve login page URL." -f $functionName
            }
        }
    }
    if ($loginPageUrl -match "error=") {
        throw "[{0}] [OAUTH2 - Onepass] Error encountered while attempting to access login page: {1}" -f $functionName, $loginPageUrl
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
        throw "[{0}] [OAUTH2 - Onepass] Could not extract authorization code from callback URL: {1}" -f $functionName, $callbackUrl
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
        Write-Error @"
[OAUTH2 - Onepass] Failed to retrieve access token from token endpoint. 

This may occur if you attempt to run the connection multiple times in a short period. 
Please wait a moment and try again.
"@ -ErrorAction Stop
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
This cmdlet establishes and manages your connection to the HPE GreenLake platform. Upon successful authentication, it creates a persistent session stored in the global variable `$Global:HPEGreenLakeSession`, which tracks all connection details, API credentials, and access tokens for subsequent cmdlet operations.

The cmdlet automatically generates temporary unified API client credentials for HPE GreenLake and any Compute Ops Management service instances provisioned in the connected workspace, enabling seamless interaction with both platforms through a single authentication.

AUTHENTICATION METHODS

This library supports three authentication methods:

1. Single-Factor Authentication (Username and Password)
   - Direct authentication using HPE Account credentials
   - Suitable for non-SSO environments or testing scenarios

2. Multi-Factor Authentication (MFA) with HPE Account
   - Google Authenticator: 6-digit time-based verification codes
   - Okta Verify: Push notifications for approval
   
   MFA Requirements:
   • Authenticator app must be installed and linked to your HPE Account
   • Security keys and biometric authenticators are not supported
   • If your account uses only security keys/biometrics, enable Google Authenticator or Okta Verify in account settings
   • When both methods are available, Okta Verify push notifications take precedence

3. SAML Single Sign-On (SSO) - Passwordless Authentication
   
   Supported Identity Providers:
   
   • Okta
     - Push notifications (with or without number challenge) and TOTP codes
     - Push notifications prioritized; automatic fallback to TOTP
     - 2-minute approval timeout
     - Requires Okta Verify installed and enrolled
   
   • Microsoft Entra ID
     - Passwordless push notifications with mandatory number matching
     - Passwordless phone sign-in required (standard MFA enrollment insufficient)
     - Commercial cloud only (login.microsoftonline.com)
     - TOTP codes not supported in passwordless flows
     - Allow 15-30 minutes for enrollment changes to propagate
   
   • PingIdentity
     - Push notifications and TOTP codes
     - Push prioritized; automatic fallback to TOTP
     - All PingOne regions supported (NA, EU, APAC, CA)
     - 2-minute approval timeout
     - Requires PingID enrolled and active
   
   SSO Prerequisites:
   • SAML SSO configured in your HPE GreenLake workspace
   • Identity Provider configured with HPE GreenLake as SAML 2.0 application
   • Passwordless authentication methods only (push notifications and/or TOTP)
   • User has appropriate application access permissions
   
   Security Note: Password-based MFA flows are not supported. This follows NIST and industry best practices, 
                  as passwordless authentication eliminates vulnerabilities such as phishing, credential stuffing, and password reuse.
   
   Configuration Guide: https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us
   Technical blog: https://jullienl.github.io/Configuring-SAML-SSO-with-HPE-GreenLake-and-Passwordless-Authentication-for-HPECOMCmdlets/

ACCOUNT REQUIREMENTS

• HPE Account: Required for authentication methods 1 and 2 (single-factor and MFA)
  - Not required when using SSO with external Identity Providers (Okta, Entra ID, PingIdentity)
  - Create an account at https://common.cloud.hpe.com
  - Account creation guide: https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us&page=GUID-497192AA-FDC2-49C5-B572-0D2F58A23745.html

ROLE-BASED ACCESS

Minimum required role: Observer (view-only access)
- Observer: View resources and configurations
- Operator: View and edit resources
- Administrator: View, edit, and delete resources
- Custom roles: Create tailored access permissions

Required roles for both:
• HPE GreenLake Platform service manager
• Compute Ops Management service manager (access required for each COM instance you plan to manage)

WORKSPACE MANAGEMENT

You do not need an existing HPE GreenLake workspace to connect. After initial authentication, create a new workspace using the 'New-HPEGLWorkspace' cmdlet.

SESSION MANAGEMENT

The global variable `$Global:HPEGreenLakeSession` stores:
• Session information and web request sessions
• API client credentials (HPE GreenLake and Compute Ops Management)
• OAuth2 access tokens, ID tokens, and refresh tokens
• Workspace details (ID, name, organization)
• Token creation timestamps and expiration details

For detailed session properties, see the OUTPUTS section below.

.PARAMETER Credential 
Set of security credentials such as a username and password to establish a connection to HPE GreenLake.

.PARAMETER SSOEmail
Specifies the email address to use for Single Sign-On (SSO) authentication. 

Supported Identity Providers:
- Okta: Okta Verify push notifications or TOTP codes
- Microsoft Entra ID: Microsoft Authenticator passwordless push with mandatory number matching
- PingIdentity: PingID push notifications or TOTP codes

Authentication Flow:
1. Monitor PowerShell for authentication prompts based on your Identity Provider:
   - Number to verify (e.g., "35" for Entra ID number matching)
   - Push notification to approve on your mobile device
   - TOTP code prompt from your authenticator app

2. Complete authentication on your mobile device:
   - Approve the push notification, or
   - Enter the displayed number in your authenticator app, or
   - Provide the TOTP code when prompted

3. Connection proceeds automatically once authentication is verified

Note: SSO must be properly configured in your HPE GreenLake workspace. If you receive an "SSO configuration issue" error, contact your Workspace Administrator 
      to ensure your email domain is pre-claimed and SAML SSO is configured.

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
Note: Critical information such as number matching challenges will still be displayed regardless of this setting.

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

.NOTES
    ENVIRONMENT VARIABLES (Optional - For Development/Testing Only):
    
    By default, Connect-HPEGL connects to HPE GreenLake production endpoints.
    For development, testing, staging, or private cloud deployments, you can override
    these endpoints using environment variables:
    
    HPE_COMMON_CLOUD_URL - Override for https://common.cloud.hpe.com
        Default: https://common.cloud.hpe.com
        Description: HPE Common Cloud Services settings endpoint
        
    HPE_AUTH_URL - Override for https://auth.hpe.com
        Default: https://auth.hpe.com
        Description: HPE authentication and OAuth2 endpoint
        
    HPE_SSO_URL - Override for https://sso.common.cloud.hpe.com
        Default: https://sso.common.cloud.hpe.com
        Description: HPE SSO endpoint for federated authentication
    
    Example - Using Development Environment:
        PS> $env:HPE_COMMON_CLOUD_URL = "https://dev-common.cloud.hpe.com"
        PS> $env:HPE_AUTH_URL = "https://dev-auth.hpe.com"
        PS> $env:HPE_SSO_URL = "https://dev-sso.common.cloud.hpe.com"
        PS> Connect-HPEGL -SSOEmail user@company.com -Workspace TestWorkspace
    
    Example - Using Mock Server for Testing:
        PS> $env:HPE_COMMON_CLOUD_URL = "https://localhost:8443"
        PS> $env:HPE_AUTH_URL = "https://localhost:8444"
        PS> Connect-HPEGL -Credential $cred -Workspace MockWorkspace
    
    Example - Clear Environment Variables (Return to Production):
        PS> Remove-Item Env:\HPE_COMMON_CLOUD_URL
        PS> Remove-Item Env:\HPE_AUTH_URL
        PS> Remove-Item Env:\HPE_SSO_URL
        PS> Connect-HPEGL -Credential $cred -Workspace ProductionWorkspace
    
    Production Users: Do not set these environment variables. The function uses
    production URLs by default. Environment variables are only needed for non-production
    scenarios such as development, testing, or private cloud deployments.

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
Connect-HPEGL -SSOEmail "user@company.com" -Workspace "Production"

This example demonstrates SSO authentication with Okta using push notification.
The cmdlet will send a push notification to the user's Okta Verify app.
If number matching is enabled, the user must enter the displayed number in the app.
Otherwise, simply approve the push notification within 2 minutes.

.EXAMPLE
Connect-HPEGL -SSOEmail "user@company.com" -Workspace "Production"

This example demonstrates SSO authentication with Microsoft Entra ID using passwordless push with mandatory number matching.
The cmdlet will display a number in PowerShell (e.g., "35").
Open Microsoft Authenticator on your mobile device and enter the exact number shown to approve the authentication.
Authentication must be completed within 2 minutes.

Note: Ensure passwordless phone sign-in is enabled in Microsoft Authenticator (standard MFA enrollment is insufficient).

.EXAMPLE
Connect-HPEGL -SSOEmail "user@company.com" -Workspace "Production"

This example demonstrates SSO authentication with PingIdentity using push notification.
The cmdlet will send a push notification to the user's PingID app.
Approve the notification on your mobile device within 2 minutes.
If push is unavailable, you may be prompted to enter a TOTP code from the PingID app.

.EXAMPLE
Connect-HPEGL -SSOEmail "user@company.com"

Connect to HPE GreenLake using SSO without specifying a workspace.
After authentication, use Get-HPEGLWorkspace to list available workspaces, then connect to a specific workspace using Connect-HPEGLWorkspace -Name "<WorkspaceName>".

.EXAMPLE
Connect-HPEGL -SSOEmail "user@company.com" -Workspace "Production" -RemoveExistingCredentials

Connect using SSO and remove all existing API credentials from previous sessions.
Use this if you encounter the "maximum of 7 personal API clients" error.

.EXAMPLE
Connect-HPEGL -SSOEmail "user@company.com" -Workspace "Production" -Verbose

Connect using SSO with verbose output for troubleshooting.
This displays detailed information about each step of the authentication process.

.LINK
If you do not have an HPE Account, you can create one at https://common.cloud.hpe.com.

To learn how to create an HPE account, see https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us&page=GUID-497192AA-FDC2-49C5-B572-0D2F58A23745.html

For SAML SSO configuration instructions, see https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us

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
    
        # Support environment variable override for dev/test/private cloud environments
        # Production users don't set these - function uses defaults
        $hpeCommonUrl = if ($env:HPE_COMMON_CLOUD_URL) { 
            "[{0}] Using HPE Common Cloud URL from environment variable: {1}" -f $functionName, $env:HPE_COMMON_CLOUD_URL | Write-Verbose
            $env:HPE_COMMON_CLOUD_URL 
        }
        else { 
            "https://common.cloud.hpe.com" 
        }

        $hpeAuthUrl = if ($env:HPE_AUTH_URL) { 
            "[{0}] Using HPE Auth URL from environment variable: {1}" -f $functionName, $env:HPE_AUTH_URL | Write-Verbose
            $env:HPE_AUTH_URL 
        }
        else { 
            "https://auth.hpe.com" 
        }

        $hpeSsoUrl = if ($env:HPE_SSO_URL) { 
            "[{0}] Using HPE SSO URL from environment variable: {1}" -f $functionName, $env:HPE_SSO_URL | Write-Verbose
            $env:HPE_SSO_URL 
        }
        else { 
            "https://sso.common.cloud.hpe.com" 
        }

        # 1 - Test DNS resolution
    
        $ccsSettingsUrl = Get-ccsSettingsUrl
        $CCServer = $ccsSettingsUrl.Authority
        
        Test-EndpointDNSResolution $CCServer
    
        # 2 - Test TCP connection: HPE Common Cloud URL
        
        Test-EndpointTCPConnection $hpeCommonUrl
            
        # 3 - Test TCP connection: HPE Auth URL
    
        Test-EndpointTCPConnection $hpeAuthUrl

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
        $totalSteps = if ($Workspace -and -not $SSOEmail) { 9 } elseif ($SSOEmail -and $SSOEmail -match 'hpe.com$') { 14 } else { 18 }
    
        function Update-ProgressBar {
            param (
                [int]$CompletedSteps,
                [int]$TotalSteps,
                [string]$CurrentActivity,
                [int]$Id
            )
    
            if (-not $NoProgress) {
                # Ensure percentage is between 0 and 100 (prevent negative values)
                $percentComplete = [math]::Max(0, [math]::Min(($CompletedSteps / $TotalSteps) * 100, 100))
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
    
        # === INITIALIZATION ===
        $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession

        $step = 1

        ##############################################################################################################################################################################################
        
        # Handle non-hpe.com SSO Email cases
        if ($PSBoundParameters.ContainsKey('SSOEmail') -and $SSOEmail -notmatch 'hpe.com$') {

            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            #Region Helper functions for Entra ID/Okta/PingID passwordless MFA authentication flow

            function Get-302RedirectUrl {
                param(
                    [string]$Url,
                    [Microsoft.PowerShell.Commands.WebRequestSession]$Session,
                    [hashtable]$Headers = $null,
                    [string]$StepName
                )
                
                $params = @{
                    Uri                = $Url
                    Method             = 'Get'
                    MaximumRedirection = 0
                    WebSession         = $Session
                }
                
                if ($Headers) {
                    $params['Headers'] = $Headers
                }
                
                try {
                    $response = Invoke-WebRequest @params
                    return $null  # No redirect occurred
                }
                catch {
                    if ($_.Exception.Message -match "302") {
                        if ($_.Exception.Response) {
                            $redirectUrl = $_.Exception.Response.Headers.Location.AbsoluteUri
                            
                            # Hide any sensitive information in logs
                            $redirectUrlLog = $redirectUrl -replace "stateToken=[^&]+", "stateToken=[REDACTED]"
                            $redirectUrlLog = $redirectUrlLog -replace "client_id=[^&]+", "client_id=[REDACTED]"
                            $redirectUrlLog = $redirectUrlLog -replace "code_challenge=[^&]+", "code_challenge=[REDACTED]"
                            $redirectUrlLog = $redirectUrlLog -replace "state=[^&]+", "state=[REDACTED]"

                            "[{0}] {1} - 302 redirect to: {2}" -f $functionName, $StepName, $redirectUrlLog | Write-Verbose
                            return $redirectUrl
                        }
                    }
                    else {
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        throw "[{0}] Authentication failed at {1}: {2}" -f $functionName, $StepName, $_.Exception.Message
                    }
                }
            }

            function Get-QueryParameter {
                param(
                    [string]$Url,
                    [string]$ParamName
                )
                
                $value = ($Url -split '[?&]') | Where-Object { $_ -like "$ParamName=*" } | ForEach-Object { $_ -replace "^$ParamName=", '' }
                return [System.Web.HttpUtility]::UrlDecode($value)
            }           

            function Invoke-EntraIDMFAAuthentication {
                <#
            .SYNOPSIS
                Performs Entra ID (Azure AD) passwordless authentication using Microsoft Authenticator push notifications.

            .DESCRIPTION
                This function implements the correct Entra ID passwordless authentication flow:
                1. Calls GetCredentialType API to check available authentication methods
                2. Initiates push notification to Microsoft Authenticator app with number matching
                3. Polls DeviceCodeStatus API until user approves or denies the notification
                4. Returns the SAML response for completing HPE GreenLake authentication
                
                This flow does NOT require passwords and works with pure passwordless authentication policies.
                Only Microsoft Authenticator push notifications are supported in this passwordless flow.

            .PARAMETER StateToken
                The context token (ctx) from the SAML flow, used as originalRequest parameter

            .PARAMETER FlowToken
                The flow token from the Entra ID login page

            .PARAMETER CanaryToken
                The canary token for CSRF protection

            .PARAMETER Username
                The user's UPN (e.g., user@domain.onmicrosoft.com)

            .PARAMETER Session
                The WebRequestSession to maintain cookies and session state

            .PARAMETER TenantDomain
                The Entra ID tenant domain (e.g., login.microsoftonline.com)

            .PARAMETER BaseUrl
                The Entra ID base URL. Defaults to https://login.microsoftonline.com for commercial cloud.
                For sovereign clouds, specify: https://login.microsoftonline.us (Government), etc.    

            .PARAMETER NoProgress
                Suppresses progress bar updates (number matching entropy will still be shown)

            .PARAMETER CompletedSteps
                Reference to completed steps counter for progress tracking

            .PARAMETER TotalSteps
                Total number of steps for progress calculation

            .PARAMETER CurrentStep
                Reference to current step counter

            .EXAMPLE
                $result = Invoke-EntraIDMFAAuthentication -StateToken $ctx -FlowToken $flowToken `
                    -CanaryToken $canary -Username "user@domain.com" -Session $session -TenantDomain "login.microsoftonline.com"

                This example performs Entra ID passwordless authentication in the commercial cloud.

            .EXAMPLE
                $result = Invoke-EntraIDMFAAuthentication -StateToken $ctx -FlowToken $flowToken `
                    -CanaryToken $canary -Username "user@domain.com" -Session $session `
                    -TenantDomain "login.microsoftonline.us" -BaseUrl "https://login.microsoftonline.us"      
                    
                This example performs Entra ID passwordless authentication in the Azure Government cloud.

            .NOTES
                Only Microsoft Authenticator push notifications are supported. TOTP codes and other MFA methods
                are not available in the passwordless authentication flow.
            #>

                param(
                    [Parameter(Mandatory = $false)]
                    [string]$StateToken,

                    [Parameter(Mandatory = $false)]
                    [string]$FlowToken,

                    [Parameter(Mandatory = $false)]
                    [string]$CanaryToken,

                    [Parameter(Mandatory = $true)]
                    [string]$Username,

                    [Parameter(Mandatory = $true)]
                    [Microsoft.PowerShell.Commands.WebRequestSession]$Session,

                    [Parameter(Mandatory = $true)]
                    [string]$TenantDomain,

                    [Parameter(Mandatory = $false)]
                    [switch]$NoProgress,

                    [Parameter(Mandatory = $false)]
                    [ref]$CompletedSteps,

                    [Parameter(Mandatory = $false)]
                    [int]$TotalSteps,

                    [Parameter(Mandatory = $false)]
                    [ref]$CurrentStep,

                    [Parameter(Mandatory = $false)]
                    [string]$BaseUrl = "https://login.microsoftonline.com",

                    [Parameter(Mandatory = $false)]
                    [int]$TimeoutMinutes = 2,

                    [Parameter(Mandatory = $false)]
                    [int]$PollIntervalSeconds = 3
                )

                $functionName = "Invoke-EntraIDMFAAuthentication".ToUpper()
                $script:HelpUrl = "https://github.com/jullienl/HPE-COM-PowerShell-Library/blob/main/README.md"


                # Validate we have at least one required token
                if (-not $StateToken -and -not $FlowToken) {
                    throw "[{0}] Either StateToken (ctx) or FlowToken must be provided for Entra ID authentication" -f $functionName
                }

                "[{0}] Starting Entra ID passwordless authentication" -f $functionName | Write-Verbose
                "[{0}] Username: {1}" -f $functionName, $Username | Write-Verbose

                # Single progress bar update for the entire MFA process
                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                    $currentStepValue = $CurrentStep.Value
                    Update-ProgressBar -CompletedSteps $CompletedSteps.Value -TotalSteps $TotalSteps -CurrentActivity "Step $currentStepValue/$TotalSteps - Entra ID Passwordless Authentication" -Id 0
                    $CurrentStep.Value++
                }

                #Region STEP 1: Get Available Authentication Methods
                
                $getCredentialTypeUrl = "$baseUrl/common/GetCredentialType"

                "[{0}] Step 1: Checking available authentication methods using POST {1}" -f $functionName, $getCredentialTypeUrl | Write-Verbose
                
                # Detect country code with fallback
                $countryCode = try { 
                    [System.Globalization.RegionInfo]::CurrentRegion.TwoLetterISORegionName 
                }
                catch { 
                    "US" 
                }

                $payload = @{
                    username                       = $Username
                    isOtherIdpSupported            = $true
                    checkPhones                    = $false
                    isRemoteNGCSupported           = $true
                    isCookieBannerShown            = $false
                    isFidoSupported                = $true
                    originalRequest                = $StateToken
                    country                        = $countryCode
                    forceotclogin                  = $false
                    isExternalFederationDisallowed = $false
                    isRemoteConnectSupported       = $false
                    federationFlags                = 0
                    isSignup                       = $false
                    flowToken                      = $FlowToken
                    isAccessPassSupported          = $true
                    isQrCodePinSupported           = $true
                } | ConvertTo-Json -Depth 10

                $headers = @{
                    "Content-Type"      = "application/json"
                    "canary"            = $CanaryToken
                    "client-request-id" = [guid]::NewGuid().ToString()             
                }

                "[{0}] Payload: `n{1}" -f $functionName, ($payload ) | Write-Verbose
                "[{0}] Headers: `n{1}" -f $functionName, ($headers | ConvertTo-Json -Depth 10) | Write-Verbose

                try {
                    $credentialTypeResponse = Invoke-RestMethod -Uri $getCredentialTypeUrl -Method POST -ErrorAction Stop `
                        -Headers $headers -Body $payload -WebSession $Session


                    "[{0}] GetCredentialType response received: `n{1}" -f $functionName, ($credentialTypeResponse | ConvertTo-Json -Depth 10) | Write-Verbose
                }
                catch {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                    }
                    "[{0}] Failed to get credential type: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                    throw "[{0}] Could not retrieve Entra ID authentication methods. {1}" -f $functionName, $_.Exception.Message
                }

                # Update tokens if new ones were returned
                if ($credentialTypeResponse.FlowToken) {
                    $FlowToken = $credentialTypeResponse.FlowToken
                }
                if ($credentialTypeResponse.apiCanary) {
                    $CanaryToken = $credentialTypeResponse.apiCanary
                }
                #EndRegion STEP 1

                #Region STEP 2: Validate User and Check Authentication Methods
                "[{0}] Step 2: Validating user and authentication methods" -f $functionName | Write-Verbose

                # Check if user exists
                if ($credentialTypeResponse.IfExistsResult -ne 0) {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                    }
                    Write-Error @"
User authentication failed.

This error can occur for multiple reasons:

1. User account does not exist in Entra ID
2. User account is disabled or locked
3. User is not assigned to the HPE GreenLake application in Entra ID
   - Contact your Entra ID administrator to verify application access
   - Ensure you have the required app role assignments

For complete Entra ID setup prerequisites, see: $script:HelpUrl
"@ -ErrorAction Stop
                }

                # Check throttle status
                if ($credentialTypeResponse.ThrottleStatus -eq 1) {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                    }
                    throw "[{0}] Authentication requests are being throttled. Please wait a few minutes and try again." -f $functionName
                }

                # Extract authentication method details
                $sessionIdentifier = $null
                $entropy = $null

                if ($credentialTypeResponse.Credentials) {
                    # Check for RemoteNGC (push notification) support
                    if ($credentialTypeResponse.Credentials.HasRemoteNGC) {
                        
                        if ($credentialTypeResponse.Credentials.RemoteNgcParams) {
                            $sessionIdentifier = $credentialTypeResponse.Credentials.RemoteNgcParams.SessionIdentifier
                            $entropy = $credentialTypeResponse.Credentials.RemoteNgcParams.Entropy
                            
                            "[{0}] Push notification available - Entropy: {1}" -f $functionName, $entropy | Write-Verbose
                        }
                        else {
                            # RemoteNGC exists but params are null - passwordless is available but not set as default
                            # This happens when user has passwordless configured but must click "Use an app instead" in browser
                            # We need to make an additional API call to explicitly request RemoteNGC credentials
                            
                            "[{0}] RemoteNGC available but not default - requesting explicit RemoteNGC credentials" -f $functionName | Write-Verbose
                            
                            $beginAuthUrl = "$baseUrl/common/SAS/BeginAuth"
                            $beginAuthPayload = @{
                                AuthMethodId = "PhoneAppNotification"
                                Method       = "BeginAuth"
                                ctx          = $FlowToken
                                flowToken    = $FlowToken
                            } | ConvertTo-Json -Depth 10
                            
                            $beginAuthHeaders = @{
                                "Content-Type"      = "application/json"
                                "canary"            = $CanaryToken
                                "client-request-id" = [guid]::NewGuid().ToString()
                            }
                            
                            try {
                                "[{0}] Calling BeginAuth to request RemoteNGC credentials" -f $functionName | Write-Verbose
                                $beginAuthResponse = Invoke-RestMethod -Uri $beginAuthUrl -Method POST -ErrorAction Stop `
                                    -Headers $beginAuthHeaders -Body $beginAuthPayload -WebSession $Session
                                
                                "[{0}] BeginAuth response: `n{1}" -f $functionName, ($beginAuthResponse | ConvertTo-Json -Depth 10) | Write-Verbose
                                
                                # Extract RemoteNGC parameters from BeginAuth response
                                if ($beginAuthResponse.SessionIdentifier -and $beginAuthResponse.Entropy) {
                                    $sessionIdentifier = $beginAuthResponse.SessionIdentifier
                                    $entropy = $beginAuthResponse.Entropy
                                    "[{0}] Successfully obtained RemoteNGC credentials - Entropy: {1}" -f $functionName, $entropy | Write-Verbose
                                }
                                else {
                                    throw "[{0}] BeginAuth response missing SessionIdentifier or Entropy" -f $functionName
                                }
                            }
                            catch {
                                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                                    Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                                }
                                "[{0}] Failed to request RemoteNGC credentials: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                                $errorMessage = @"
Microsoft Authenticator passwordless sign-in is not properly configured for this account.

This error can occur for multiple reasons:

1. Microsoft Authenticator is not enrolled with passwordless phone sign-in enabled
   - Go to https://aka.ms/mysecurityinfo
   - Add or reconfigure Microsoft Authenticator with phone sign-in (passwordless) enabled
   - Wait 15-30 minutes for changes to propagate

2. User is not assigned to the HPE GreenLake application in Entra ID
   - Contact your Entra ID administrator to verify application access
   - Ensure you have the required app role assignments

For complete Entra ID setup prerequisites, see: $script:HelpUrl
"@
                                Write-Error $errorMessage -ErrorAction Stop
                            }
                        }
                    }
                    else {
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                        }
                        $errorMessage = @"
Microsoft Authenticator passwordless authentication is not enabled for this account.

This error can occur for multiple reasons:

1. Microsoft Authenticator is not enrolled with passwordless phone sign-in enabled
   - Install Microsoft Authenticator on your mobile device
   - Go to https://aka.ms/mysecurityinfo
   - Add Microsoft Authenticator with phone sign-in (passwordless) enabled
   - Wait 15-30 minutes for changes to propagate

2. User is not assigned to the HPE GreenLake application in Entra ID
   - Contact your Entra ID administrator to verify application access
   - Ensure you have the required app role assignments

For complete Entra ID setup prerequisites, see: $script:HelpUrl
"@
                        Write-Error $errorMessage -ErrorAction Stop
                    }
                }
                else {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                    }
                    throw "[{0}] Invalid response from Entra ID. Credentials information missing." -f $functionName
                }
                #EndRegion STEP 2

                #Region STEP 3: Handle Push Notification
                "[{0}] Step 3: Handling push notification challenge" -f $functionName | Write-Verbose

                Start-Sleep -Milliseconds 500

                # Display entropy number in progress bar if number matching is enabled (ALWAYS shown, bypasses NoProgress)
                if ($entropy -and $entropy -gt 0) {
                    Update-ProgressBar -CompletedSteps $CompletedSteps.Value -TotalSteps $TotalSteps `
                        -CurrentActivity "Respond '$entropy' to the Microsoft Authenticator notification" -Id 0
                    "[{0}] Number matching active - user must enter: {1}" -f $functionName, $entropy | Write-Verbose
                }
                else {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $CompletedSteps.Value -TotalSteps $TotalSteps `
                            -CurrentActivity "Approve the Microsoft Authenticator push notification" -Id 0
                    }
                }

                # Poll for user approval
                "[{0}] Polling for push notification approval" -f $functionName | Write-Verbose

                $deviceCodeStatusUrl = "$baseUrl/common/DeviceCodeStatus"

                $pollPayload = @{
                    DeviceCode = $sessionIdentifier
                } | ConvertTo-Json -Depth 10

                $pollHeaders = @{
                    "Content-Type"      = "application/json"
                    "Accept"            = "application/json"
                    "canary"            = $CanaryToken
                    "client-request-id" = [guid]::NewGuid().ToString()
                }

                $timeout = [datetime]::Now.AddMinutes($TimeoutMinutes)
                $pollCount = 0
                $maxPolls = 120

                do {
                    $pollCount++
                    
                    try {
                        $pollResponse = Invoke-RestMethod -Uri $deviceCodeStatusUrl -Method POST -Body $pollPayload `
                            -Headers $pollHeaders -ErrorAction Stop -WebSession $Session

                        "[{0}] Poll #{1}: AuthorizationState = {2}" -f $functionName, $pollCount, $pollResponse.AuthorizationState | Write-Verbose
                        
                        # Check for approval
                        if ($pollResponse.AuthorizationState -eq 2) {
                            "[{0}] Push notification approved by user!" -f $functionName | Write-Verbose
                            break
                        }
                        
                        # Check for denial/rejection
                        if ($pollResponse.AuthorizationState -eq 1) {
                            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                            }
                            "[{0}] Push notification was denied by user (AuthorizationState = 1)" -f $functionName | Write-Verbose
                            throw "[{0}] Microsoft Authenticator push notification was denied. The user either clicked 'It's not me' or entered an invalid number." -f $functionName
                        }
                        
                        # Check for other unexpected states
                        if ($pollResponse.AuthorizationState -gt 2) {
                            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                            }
                            "[{0}] Unexpected AuthorizationState: {1}" -f $functionName, $pollResponse.AuthorizationState | Write-Verbose
                            throw "[{0}] Push notification failed with unexpected state: {1}" -f $functionName, $pollResponse.AuthorizationState
                        }
                    }
                    catch {
                        # Don't throw on timeouts, but re-throw other errors
                        if ($_.Exception.Message -notmatch "timeout|timed out") {
                            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                            }
                            throw
                        }
                    }

                    # Check overall timeout
                    if ([datetime]::Now -ge $timeout) {
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                        }
                        Write-Error @"
Timeout! Microsoft Authenticator push notification was not approved within $TimeoutMinutes minutes.

Please try again and approve the request promptly.
"@ -ErrorAction Stop
                    }

                    Start-Sleep -Seconds $PollIntervalSeconds                
                } until ($pollResponse.AuthorizationState -eq 2 -or $pollCount -ge $maxPolls)

                # Final check
                if ($pollResponse.AuthorizationState -ne 2) {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                    }
                    throw "[{0}] Push notification approval failed or timed out. Please try again." -f $functionName
                }
                #EndRegion STEP 3

                #Region STEP 4: Complete Authentication and Get SAML Response
                "[{0}] Step 4: Completing authentication flow" -f $functionName | Write-Verbose

                # Extract tenant ID
                $tenantId = $null

                # Priority 1: Check if TenantDomain contains a GUID
                if ($TenantDomain -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') {
                    $tenantId = $matches[1]
                }
                # Priority 2: Check StateToken (ctx)
                elseif ($StateToken -and $StateToken -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') {
                    $tenantId = $matches[1]
                }
                # Priority 3: Check if we can extract from session URLs
                elseif ($Session.Cookies.Count -gt 0) {
                    # Try to find tenant from cookie domain or previous requests
                    foreach ($cookie in $Session.Cookies.GetCookies($baseUrl)) {
                        if ($cookie.Path -match '/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/') {
                            $tenantId = $matches[1]
                            break
                        }
                    }
                }

                # Fallback to 'common'
                if (-not $tenantId) {
                    $tenantId = "common"
                }

                $loginUrl = "$baseUrl/$tenantId/login"

                # Build form data
                $formData = @(
                    "code=$([uri]::EscapeDataString($sessionIdentifier))"
                    "login=$([uri]::EscapeDataString($Username))"
                    "loginfmt=$([uri]::EscapeDataString($Username))"
                    "psRNGCEntropy=$entropy"
                    "psRNGCSLK=$([uri]::EscapeDataString($sessionIdentifier))"
                    "ctx=$([uri]::EscapeDataString($StateToken))"
                    "flowToken=$([uri]::EscapeDataString($FlowToken))"
                    "canary=$([uri]::EscapeDataString($CanaryToken))"
                ) -join '&'

                $loginHeaders = @{
                    "Content-Type" = "application/x-www-form-urlencoded"
                }

                try {
                    $loginResponse = Invoke-WebRequest -Uri $loginUrl -Method POST -Body $formData `
                        -Headers $loginHeaders -ErrorAction Stop -WebSession $Session -MaximumRedirection 10

                    "[{0}] Login POST completed" -f $functionName | Write-Verbose

                    # Check if we got SAML response directly
                    if ($loginResponse.Content -match 'name="SAMLResponse"') {
                        "[{0}] SAML response found in login response" -f $functionName | Write-Verbose
                        
                        if ($CompletedSteps) { $CompletedSteps.Value++ }
                        return $loginResponse
                    }
                    
                    # Check for KMSI (Keep Me Signed In) page
                    $isKmsiPage = $loginResponse.Content -match '"PageID"\s*content="KmsiInterrupt"' -or
                    $loginResponse.Content -match '"urlPost"\s*:\s*"/kmsi"'

                    if ($isKmsiPage) {
                        "[{0}] KMSI (Keep Me Signed In) page detected" -f $functionName | Write-Verbose
                        
                        # Extract tokens from JavaScript config or form fields
                        $kmsiCtx = ""
                        $kmsiFlowToken = ""
                        $kmsiCanary = ""
                        
                        if ($loginResponse.Content -match '"sFT"\s*:\s*"([^"]+)"') {
                            $kmsiFlowToken = $matches[1]
                        }
                        if ($loginResponse.Content -match '"sCtx"\s*:\s*"([^"]+)"') {
                            $kmsiCtx = $matches[1]
                        }
                        elseif ($StateToken) {
                            $kmsiCtx = $StateToken
                        }
                        if ($loginResponse.Content -match '"canary"\s*:\s*"([^"]+)"') {
                            $kmsiCanary = $matches[1]
                        }
                        
                        $kmsiUrl = "$baseUrl/kmsi"
                        $kmsiFormData = @(
                            "LoginOptions=1"
                            "type=28"
                            "ctx=$([uri]::EscapeDataString($kmsiCtx))"
                            "flowToken=$([uri]::EscapeDataString($kmsiFlowToken))"
                            "canary=$([uri]::EscapeDataString($kmsiCanary))"
                        ) -join '&'
                        
                        $kmsiResponse = Invoke-WebRequest -Uri $kmsiUrl -Method POST -Body $kmsiFormData `
                            -Headers $loginHeaders -ErrorAction Stop -WebSession $Session -MaximumRedirection 10
                        
                        "[{0}] KMSI POST completed" -f $functionName | Write-Verbose
                        
                        if ($CompletedSteps) { $CompletedSteps.Value++ }
                        return $kmsiResponse
                    }
                    
                    # Return login response if no KMSI
                    if ($CompletedSteps) { $CompletedSteps.Value++ }
                    return $loginResponse
                }
                catch {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Entra ID Authentication" -Status "Failed" -Completed
                    }
                    "[{0}] Failed to complete authentication flow: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                    throw "[{0}] Could not complete Entra ID authentication. {1}" -f $functionName, $_.Exception.Message
                }
                #EndRegion STEP 4
            }

            function Invoke-OktaMFAAuthentication {
                <#
            .SYNOPSIS
                Performs Okta passwordless authentication using Okta Verify push notifications or TOTP codes.

            .DESCRIPTION
                This function implements the Okta Identity Engine (IDX) authentication flow:
                1. Introspects authentication state
                2. Identifies user if needed
                3. Selects Okta Verify authenticator and method (push or TOTP)
                4. Handles MFA challenge (push polling or TOTP code entry)
                5. Returns SAML response for completing authentication
                
                Supports both push notifications (with or without number matching) and TOTP codes.
                Automatically prefers push but falls back to TOTP if push is unavailable.

            .PARAMETER StateToken
                The Okta state token from the SAML flow

            .PARAMETER Username
                The user's email address or username

            .PARAMETER Session
                The WebRequestSession to maintain cookies and session state

            .PARAMETER OktaDomain
                The Okta domain (e.g., mycompany.okta.com)

            .PARAMETER NoProgress
                Suppresses progress bar updates (number matching will still be shown)

            .PARAMETER CompletedSteps
                Reference to completed steps counter for progress tracking

            .PARAMETER TotalSteps
                Total number of steps for progress calculation

            .PARAMETER CurrentStep
                Reference to current step counter

            .EXAMPLE
                $result = Invoke-OktaMFAAuthentication -StateToken $token -Username "user@example.com" `
                    -Session $session -OktaDomain "mycompany.okta.com"
            #>

                param(
                    [Parameter(Mandatory = $true)]
                    [string]$StateToken,

                    [Parameter(Mandatory = $true)]
                    [string]$Username,

                    [Parameter(Mandatory = $true)]
                    [Microsoft.PowerShell.Commands.WebRequestSession]$Session,

                    [Parameter(Mandatory = $true)]
                    [string]$OktaDomain,

                    [Parameter(Mandatory = $false)]
                    [switch]$NoProgress,

                    [Parameter(Mandatory = $false)]
                    [ref]$CompletedSteps,

                    [Parameter(Mandatory = $false)]
                    [int]$TotalSteps,

                    [Parameter(Mandatory = $false)]
                    [ref]$CurrentStep,

                    [Parameter(Mandatory = $false)]
                    [int]$TimeoutMinutes = 2,

                    [Parameter(Mandatory = $false)]
                    [int]$PollIntervalSeconds = 3
                )

                $functionName = "Invoke-OktaMFAAuthentication".ToUpper()
                $baseUrl = "https://$OktaDomain"
                $script:HelpUrl = "https://github.com/jullienl/HPE-COM-PowerShell-Library/blob/main/README.md"

                # Single progress bar update for the entire MFA process
                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                    Update-ProgressBar -CompletedSteps $CompletedSteps.Value -TotalSteps $TotalSteps -CurrentActivity "Step $CurrentStep.Value/$TotalSteps - Steps Okta MFA Authentication" -Id 0
                    $CurrentStep.Value++
                }

                "[{0}] Starting Okta authentication for: {1}" -f $functionName, $baseUrl | Write-Verbose

                #Region STEP 1: Introspect
                "[{0}] Step 1: Introspecting authentication state" -f $functionName | Write-Verbose

                $introspectUrl = "$baseUrl/idp/idx/introspect"
                $payload = @{ stateToken = $StateToken } | ConvertTo-Json -Depth 10
                $headers = @{
                    "Content-Type" = "application/json"
                    "Accept"       = "application/ion+json; okta-version=1.0.0"
                }

                try {
                    $introspectResponse = Invoke-RestMethod -Uri $introspectUrl -Method POST -ErrorAction Stop `
                        -Headers $headers -Body $payload -WebSession $Session

                    "[{0}] Introspect response received" -f $functionName | Write-Verbose
                }
                catch {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                    }
                    "[{0}] Introspect failed: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                    throw "[{0}] Could not introspect authentication state. {1}" -f $functionName, $_.Exception.Message
                }

                # Check for MFA step-up scenario (outdated Okta Verify app)
                $remediationActions = $introspectResponse.remediation.value.name
                if ($remediationActions -contains 'select-authenticator-authenticate') {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                    }
                    
                    Write-Error @"
Authentication failed: Outdated Okta Verify app detected.

ROOT CAUSE: Your Okta Verify mobile app is too old to meet current security requirements.

IMMEDIATE SOLUTIONS:
1. UPDATE Okta Verify on your mobile device to the latest version 
2. RE-ENROLL your device if updating doesn't work  

Contact IT support if updating the app doesn't resolve this issue.
"@ -ErrorAction Stop                   

                }
                #EndRegion STEP 1

                #Region STEP 2: Identify (submit username if needed)
                $identifyRemediation = $introspectResponse.remediation.value | Where-Object { $_.name -eq 'identify' }

                if ($identifyRemediation) {
                    "[{0}] Step 2: Submitting username" -f $functionName | Write-Verbose
                    
                    $identifyUrl = $identifyRemediation.href
                    $payload = @{
                        identifier  = $Username
                        stateHandle = $introspectResponse.stateHandle
                    } | ConvertTo-Json -Depth 10

                    $headers = @{
                        "Content-Type" = "application/json; okta-version=1.0.0"
                        "Accept"       = "application/ion+json; okta-version=1.0.0"
                    }

                    try {
                        $currentResponse = Invoke-RestMethod -Uri $identifyUrl -Method POST -ErrorAction Stop `
                            -Headers $headers -Body $payload -WebSession $Session
                        
                        "[{0}] Identity submitted successfully" -f $functionName | Write-Verbose
                    }
                    catch {
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                        }
                        "[{0}] Failed to submit username: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                        $errorMessage = @"
User authentication failed.

This error can occur for multiple reasons:

1. User account does not exist in Okta
2. User account is disabled or locked
3. User is not assigned to the HPE GreenLake application in Okta
   - Contact your Okta administrator to verify application access
   - Ensure you have the required app role assignments

For complete Okta setup prerequisites, see: $script:HelpUrl
"@
                        Write-Error $errorMessage -ErrorAction Stop
                    }
                }
                else {
                    $currentResponse = $introspectResponse
                }
                #EndRegion STEP 2

                #Region STEP 3: Select Okta Verify Authenticator and Method
                "[{0}] Step 3: Selecting Okta Verify authenticator" -f $functionName | Write-Verbose

                $stateHandle = $currentResponse.stateHandle
                $selectAuthRemediation = $currentResponse.remediation.value | Where-Object { $_.name -eq 'select-authenticator-authenticate' }

                if (-not $selectAuthRemediation) {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                    }
                    throw "[{0}] Authenticator selection not available. For Okta setup prerequisites, see: {1}" -f $functionName, $script:HelpUrl
                }

                $challengeHref = $selectAuthRemediation.href
                $OktaVerify = ($selectAuthRemediation.value | Where-Object { $_.name -eq 'authenticator' }).options | Where-Object { $_.label -like '*Okta*Verify*' }

                if (-not $OktaVerify) {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                    }
                    $errorMessage = @"
Okta Verify passwordless authentication is not enabled for this account.

This error can occur for multiple reasons:

1. Okta Verify is not enrolled with push notifications or TOTP codes
   - Install Okta Verify on your mobile device
   - Enroll Okta Verify in your Okta account settings
   - Ensure either push notifications or TOTP (Time-based One-Time Password) is enabled
   - Test the enrollment by signing in through a web browser first

2. User is not assigned to the HPE GreenLake application in Okta
   - Contact your Okta administrator to verify application access
   - Ensure you have the required app role assignments

For complete Okta setup prerequisites, see: $script:HelpUrl
"@
                    Write-Error $errorMessage -ErrorAction Stop
                }

                $authenticatorId = ($OktaVerify.value.form.value | Where-Object { $_.name -eq "id" }).value
                $methodOptions = ($OktaVerify.value.form.value | Where-Object { $_.name -eq "methodType" }).options

                if (-not $authenticatorId -or -not $methodOptions) {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                    }
                    throw "[{0}] Invalid Okta Verify configuration. For Okta setup prerequisites, see: {1}" -f $functionName, $script:HelpUrl
                }

                # Select method: prefer push, fallback to TOTP
                $methodType = if ($methodOptions.value -contains "push") {
                    "[{0}] Selected method: push" -f $functionName | Write-Verbose
                    "push"
                }
                elseif ($methodOptions.value -contains "totp") {
                    "[{0}] Selected method: totp (push not available)" -f $functionName | Write-Verbose
                    "totp"
                }
                else {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                    }
                    throw "[{0}] Neither push nor TOTP authentication available. For Okta setup prerequisites, see: {1}" -f $functionName, $script:HelpUrl
                }
                #EndRegion STEP 3

                #Region STEP 4: Trigger Challenge
                "[{0}] Step 4: Initiating {1} challenge" -f $functionName, $methodType | Write-Verbose

                $payload = @{
                    stateHandle   = $stateHandle
                    authenticator = @{
                        id         = $authenticatorId
                        methodType = $methodType
                    }
                } | ConvertTo-Json -Depth 10

                $headers = @{
                    "Content-Type" = "application/json; okta-version=1.0.0"
                    "Accept"       = "application/ion+json; okta-version=1.0.0"
                }

                try {
                    $challengeResponse = Invoke-RestMethod -Uri $challengeHref -Method POST -ErrorAction Stop -Headers $headers -Body $payload -WebSession $Session

                    "[{0}] {1} challenge initiated successfully" -f $functionName, $methodType.ToUpper() | Write-Verbose
                }
                catch {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                    }
                    "[{0}] Failed to initiate {1} challenge: {2}" -f $functionName, $methodType, $_.Exception.Message | Write-Verbose
                    throw "[{0}] Could not initiate Okta Verify {1} challenge. {2}" -f $functionName, $methodType, $_.Exception.Message
                }

                $stateHandle = $challengeResponse.stateHandle
                #EndRegion STEP 4

                #Region STEP 5: Handle TOTP Input
                if ($methodType -eq "totp") {
                    "[{0}] Step 5: Handling TOTP authentication" -f $functionName | Write-Verbose

                    $totpCode = Read-Host -Prompt "Enter your Okta Verify TOTP code for $($Username)"

                    if ([string]::IsNullOrWhiteSpace($totpCode)) {
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                        }
                        throw "[{0}] TOTP code is required" -f $functionName
                    }

                    $answerHref = ($challengeResponse.remediation.value | Where-Object { $_.name -eq 'challenge-authenticator' }).href

                    if (-not $answerHref) {
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                        }
                        throw "[{0}] No answerHref found in TOTP challenge response" -f $functionName
                    }

                    $payload = @{
                        stateHandle = $stateHandle
                        credentials = @{ totp = $totpCode }
                    } | ConvertTo-Json -Depth 10

                    $headers = @{
                        "Content-Type" = "application/json; okta-version=1.0.0"
                        "Accept"       = "application/ion+json; okta-version=1.0.0"
                    }

                    try {
                        $totpResponse = Invoke-RestMethod -Uri $answerHref -Method POST -ErrorAction Stop `
                            -Headers $headers -Body $payload -WebSession $Session

                        "[{0}] TOTP code submitted successfully" -f $functionName | Write-Verbose
                    }
                    catch {
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                        }

                        $errorMessage = "Invalid TOTP code. Please verify the code and try again"
                        
                        if ($_.Exception.Response) {
                            try {
                                $errorStream = $_.Exception.Response.GetResponseStream()
                                $reader = New-Object System.IO.StreamReader($errorStream)
                                $errorBody = $reader.ReadToEnd()
                                $reader.Close()
                                $errorJson = $errorBody | ConvertFrom-Json
                                
                                if ($errorJson.errorSummary) {
                                    $errorMessage = $errorJson.errorSummary
                                }
                            }
                            catch { }
                        }

                        "[{0}] Failed to submit TOTP code: {1}" -f $functionName, $errorMessage | Write-Verbose
                        throw $errorMessage
                    }

                    # Check for multi-factor authentication (TOTP + Password)
                    $additionalAuthRequired = $totpResponse.remediation.value | Where-Object { 
                        $_.name -eq 'challenge-authenticator' -and $_.relatesTo -contains '$.currentAuthenticatorEnrollment'
                    }

                    if ($additionalAuthRequired) {
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                        }
                        Write-Error @"
Multi-factor authentication (TOTP + additional factor) is not supported.

Please configure Okta to use TOTP alone.

For setup prerequisites, see: $script:HelpUrl
"@ -ErrorAction Stop
                    }

                    # Extract success redirect URL
                    $successRedirectUrl = $totpResponse.success.href
                    if (-not $successRedirectUrl) {
                        $successRedirectUrl = $totpResponse.successWithInteractionCode.href
                    }

                    if (-not $successRedirectUrl) {
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                        }
                        throw "[{0}] No success redirect URL found after TOTP verification" -f $functionName
                    }

                    "[{0}] TOTP verification completed successfully" -f $functionName | Write-Verbose
                    "[{0}] Following success redirect to retrieve SAML response" -f $functionName | Write-Verbose

                    try {
                        $samlResponse = Invoke-WebRequest -Uri $successRedirectUrl -Method GET -WebSession $Session -UseBasicParsing -ErrorAction Stop

                        "[{0}] SAML response retrieved successfully" -f $functionName | Write-Verbose

                        if ($CompletedSteps) { $CompletedSteps.Value++ }
                        return $samlResponse
                    }
                    catch {
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                        }
                        throw "[{0}] Could not retrieve SAML response. {1}" -f $functionName, $_.Exception.Message
                    }
                }
                #EndRegion STEP 5

                #Region STEP 6: Poll for Push Approval
                if ($methodType -eq "push") {
                    "[{0}] Step 6: Polling for push approval" -f $functionName | Write-Verbose

                    $pollHref = ($challengeResponse.remediation.value | Where-Object { $_.name -eq 'challenge-poll' }).href

                    if (-not $pollHref) {
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                        }
                        throw "[{0}] No pollHref found for push authentication" -f $functionName
                    }

                    $correctAnswer = $challengeResponse.currentAuthenticator.value.contextualData.correctAnswer

                    Start-Sleep -Milliseconds 500

                    # Always show number challenge (bypasses NoProgress for critical info)
                    if ($correctAnswer) {
                        Update-ProgressBar -CompletedSteps $CompletedSteps.Value -TotalSteps $TotalSteps `
                            -CurrentActivity "Respond '$correctAnswer' to the Okta Verify notification" -Id 0
                        "[{0}] Number challenge active - user must select: {1}" -f $functionName, $correctAnswer | Write-Verbose
                    }
                    else {
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $CompletedSteps.Value -TotalSteps $TotalSteps `
                                -CurrentActivity "Approve the Okta Verify push notification" -Id 0
                        }
                    }

                    $timeout = [datetime]::Now.AddMinutes($TimeoutMinutes)
                    $payload = @{ stateHandle = $stateHandle } | ConvertTo-Json
                    $headers = @{
                        "Content-Type" = "application/json; okta-version=1.0.0"
                        "Accept"       = "application/ion+json; okta-version=1.0.0"
                    }

                    do {
                        try {
                            $pollResponse = Invoke-RestMethod -Uri $pollHref -Method POST -Body $payload `
                                -Headers $headers -ErrorAction Stop -WebSession $Session
                        }
                        catch {
                            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                            }
                            throw "[{0}] Unable to poll Okta Verify push status. {1}" -f $functionName, $_.Exception.Message
                        }

                        # Check for timeout
                        if ([datetime]::Now -ge $timeout) {
                            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                            }
                            throw "[{0}] Timeout! Okta Verify push notification was not approved within {1} minutes" -f $functionName, $TimeoutMinutes
                        }

                        # Check for success
                        if ($pollResponse.success.name -eq "success-redirect" -or $pollResponse.successWithInteractionCode) {
                            break
                        }

                        # Check for multi-factor authentication requirement
                        if ($pollResponse.remediation.value | Where-Object { $_.name -eq 'challenge-authenticator' -and $_.relatesTo -contains '$.currentAuthenticatorEnrollment' }) {
                            break
                        }

                        # Check for error
                        if ($pollResponse.messages -and $pollResponse.messages.value -and $pollResponse.messages.value.Count -gt 0) {
                            if ($pollResponse.messages.value[0].class -eq "ERROR") {
                                break
                            }
                        }

                        Start-Sleep -Seconds $PollIntervalSeconds

                    } while ($true)

                    # Check for Push + Password scenario
                    if ($pollResponse.remediation.value | Where-Object { $_.name -eq 'challenge-authenticator' -and $_.relatesTo -contains '$.currentAuthenticatorEnrollment' }) {
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                        }
                        Write-Error @"
Multi-factor authentication (Push + additional factor) is not supported.

Please configure Okta to use Push alone.

For setup prerequisites, see: $script:HelpUrl
"@ -ErrorAction Stop
                    }

                    # Check for push denial - with proper null checking
                    if ($pollResponse.messages -and $pollResponse.messages.value -and $pollResponse.messages.value.Count -gt 0 -and $pollResponse.messages.value[0].class -eq "ERROR") {
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                        }
                        $errorMsg = if ($pollResponse.messages.value[0].message) { $pollResponse.messages.value[0].message } else { "Unknown error" }
                        "[{0}] Push notification denied: {1}" -f $functionName, $errorMsg | Write-Verbose
                        throw "[{0}] Push notification was rejected or incorrect number was selected" -f $functionName
                    }

                    # Check for success and extract redirect URL
                    if ($pollResponse.success.name -eq "success-redirect" -or $pollResponse.successWithInteractionCode) {
                        # Extract success redirect URL
                        $successRedirectUrl = $pollResponse.success.href
                        if (-not $successRedirectUrl) {
                            $successRedirectUrl = $pollResponse.successWithInteractionCode.href
                        }

                        if (-not $successRedirectUrl) {
                            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                            }
                            throw "[{0}] No success redirect URL found after push approval" -f $functionName
                        }

                        "[{0}] Push notification approved successfully" -f $functionName | Write-Verbose
                        "[{0}] Following success redirect to retrieve SAML response" -f $functionName | Write-Verbose

                        try {
                            $samlResponse = Invoke-WebRequest -Uri $successRedirectUrl -Method GET `
                                -WebSession $Session -UseBasicParsing -ErrorAction Stop

                            "[{0}] SAML response retrieved successfully" -f $functionName | Write-Verbose

                            if ($CompletedSteps) { $CompletedSteps.Value++ }
                            return $samlResponse
                        }
                        catch {
                            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                            }
                            throw "[{0}] Could not retrieve SAML response. {1}" -f $functionName, $_.Exception.Message
                        }
                    }
                    else {
                        # If we get here, something unexpected happened
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Okta Authentication" -Status "Failed" -Completed
                        }
                        throw "[{0}] Unexpected response from push polling. Please try again." -f $functionName
                    }
                }
                #EndRegion STEP 6
            }
            function Invoke-PingIDMFAAuthentication {
                <#
            .SYNOPSIS
                Performs PingOne/PingID SAML authentication using PingID mobile app push notifications or OTP codes.

            .DESCRIPTION
                This function implements the PingOne SAML + PingID authentication flow:
                1. Follows SAML redirect to extract flowId from PingOne
                2. Submits username to PingOne flows API
                3. Initiates PingID authentication via authenticator.pingone.com
                4. Waits for user to approve push notification on mobile device
                5. Handles JWT callback with ppm_request and ppm_response tokens
                6. Resumes SAML flow to retrieve final SAML response
                
                Authentication Methods:
                - Push Notification (Primary): Sends push to mobile device with optional number matching
                - OTP Fallback (Automatic): Only available if push is unavailable or fails
                
                IMPORTANT: PingID architecture ALWAYS sends a push notification after WebAuthn submission.
                The push notification MUST be approved - denying or ignoring it breaks the authentication session.
                There is no way to skip or cancel the push notification.

            .PARAMETER SAMLRedirectUrl
                The full SAML redirect URL from the IdP initiation (contains flowId parameter)

            .PARAMETER Username
                The user's email address or username

            .PARAMETER Session
                The WebRequestSession to maintain cookies and session state

            .PARAMETER EnvironmentId
                The PingOne environment ID (e.g., a4ff1a35-682b-469f-9acf-373ee0508d31)

            .PARAMETER NoProgress
                Suppresses progress bar updates (number matching will still be shown)

            .PARAMETER CompletedSteps
                Reference to completed steps counter for progress tracking

            .PARAMETER TotalSteps
                Total number of steps for progress calculation

            .PARAMETER CurrentStep
                Reference to current step counter

            .PARAMETER TimeoutMinutes
                Maximum time to wait for push approval (default: 2 minutes)

            .PARAMETER PollIntervalSeconds
                Interval between status polls (default: 3 seconds)

            .EXAMPLE
                $result = Invoke-PingIDMFAAuthentication -SAMLRedirectUrl $redirectUrl -Username "user@example.com" `
                    -Session $session -EnvironmentId "a4ff1a35-682b-469f-9acf-373ee0508d31"
                
                Authenticates using push notification. User must approve the push on their mobile device.

            .EXAMPLE
                $result = Invoke-PingIDMFAAuthentication -SAMLRedirectUrl $redirectUrl -Username "user@example.com" `
                    -Session $session -EnvironmentId "a4ff1a35-682b-469f-9acf-373ee0508d31" -TimeoutMinutes 5
                
                Authenticates using push notification with extended timeout of 5 minutes.
            #>

                param(
                    [Parameter(Mandatory = $true)]
                    [string]$SAMLRedirectUrl,

                    [Parameter(Mandatory = $true)]
                    [string]$Username,

                    [Parameter(Mandatory = $true)]
                    [Microsoft.PowerShell.Commands.WebRequestSession]$Session,

                    [Parameter(Mandatory = $true)]
                    [string]$EnvironmentId,

                    [Parameter(Mandatory = $false)]
                    [switch]$NoProgress,

                    [Parameter(Mandatory = $false)]
                    [ref]$CompletedSteps,

                    [Parameter(Mandatory = $false)]
                    [int]$TotalSteps,

                    [Parameter(Mandatory = $false)]
                    [ref]$CurrentStep,

                    [Parameter(Mandatory = $false)]
                    [int]$TimeoutMinutes = 2,

                    [Parameter(Mandatory = $false)]
                    [int]$PollIntervalSeconds = 3
                )

                $functionName = "Invoke-PingIDMFAAuthentication".ToUpper()
                
                # Extract PingOne base URLs directly from SAMLRedirectUrl instead of reconstructing
                # This automatically supports ALL regions including .com, .eu, .asia, .ca, .com.au, .sg, and future regions
                $authBaseUrl = $null
                $authenticatorBaseUrl = $null
                $detectedRegion = "unknown"
                
                # Extract base URL from SAMLRedirectUrl (works with any subdomain: auth., apps., authenticator.)
                # Match pattern: https://(any).pingone.(any TLD)/
                if ($SAMLRedirectUrl -match 'https://([^/]+\.)?pingone\.([^/]+)') {
                    # Extract the full domain (e.g., "eu", "com.au", "sg")
                    $detectedRegion = $Matches[2]
                    $authBaseUrl = "https://auth.pingone.$detectedRegion"
                    "[{0}] Extracted region '{1}' from URL: {2}" -f $functionName, $detectedRegion, $SAMLRedirectUrl | Write-Verbose
                    "[{0}] Constructed auth base URL: {1}" -f $functionName, $authBaseUrl | Write-Verbose
                }
                
                # Construct authenticator URL
                if ($authBaseUrl) {
                    $authenticatorBaseUrl = $authBaseUrl -replace '^https://auth\.', 'https://authenticator.'
                    "[{0}] Constructed authenticator base URL: {1}" -f $functionName, $authenticatorBaseUrl | Write-Verbose
                }
                
                # Fallback to default if extraction failed
                if (-not $authBaseUrl) {
                    "[{0}] WARNING: Could not extract base URLs from SAML redirect, falling back to .com default" -f $functionName | Write-Verbose
                    $authBaseUrl = "https://auth.pingone.com"
                    $authenticatorBaseUrl = "https://authenticator.pingone.com"
                    $detectedRegion = "com (fallback)"
                }
                
                "[{0}] Using PingOne region: {1}" -f $functionName, $detectedRegion | Write-Verbose
                $script:HelpUrl = "https://github.com/jullienl/HPE-COM-PowerShell-Library/blob/main/README.md"

                # Single progress bar update for the entire MFA process
                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                    $currentStepValue = $CurrentStep.Value
                    Update-ProgressBar -CompletedSteps $CompletedSteps.Value -TotalSteps $TotalSteps -CurrentActivity "Step $currentStepValue/$TotalSteps - PingID Passwordless Authentication" -Id 0
                    $CurrentStep.Value++
                }

                "[{0}] Starting PingOne/PingID authentication for environment: {1}" -f $functionName, $EnvironmentId | Write-Verbose

                #Region STEP 1: Follow SAML redirect and extract flowId
                "[{0}] Step 1: Following SAML redirect to extract flowId" -f $functionName | Write-Verbose

                try {
                    # Extract flowId from URL first (URL already contains it)
                    $flowId = $null
                    if ($SAMLRedirectUrl -match 'flowId=([^&]+)') {
                        $flowId = $matches[1]
                        "[{0}] Extracted flowId from URL: {1}" -f $functionName, $flowId | Write-Verbose
                    }

                    if (-not $flowId) {
                        throw "[{0}] Could not extract flowId from SAML redirect URL" -f $functionName
                    }

                    # Now follow the redirect to establish session and capture cookies
                    # Use -MaximumRedirection 5 to follow redirects automatically
                    $redirectResponse = Invoke-WebRequest -Uri $SAMLRedirectUrl -Method GET -WebSession $Session -MaximumRedirection 5 -ErrorAction Stop

                    $finalUrl = if ($redirectResponse.BaseResponse.ResponseUri) { 
                        $redirectResponse.BaseResponse.ResponseUri.AbsoluteUri 
                    }
                    else { 
                        $SAMLRedirectUrl 
                    }
                    
                    "[{0}] Followed redirect to: {1}" -f $functionName, $finalUrl | Write-Verbose
                    
                    # Verify we reached the signon page
                    if ($finalUrl -notmatch "apps\.pingone\.$pingRegion.*signon") {
                        "[{0}] Warning: Did not reach expected signon page. Got: {1}" -f $functionName, $finalUrl | Write-Verbose
                    }

                    # Check and log cookies after redirect
                    $cookieCount = ($Session.Cookies.GetCookies($authBaseUrl) | Measure-Object).Count
                    "[{0}] After redirect, session has {1} cookies for auth.pingone.{2}" -f $functionName, $cookieCount, $pingRegion | Write-Verbose
                    
                    # If no cookies, this might be a WebSession recreation issue - warn but continue
                    if ($cookieCount -eq 0) {
                        "[{0}] WARNING: No ST cookies found in session. This may cause authentication to fail." -f $functionName | Write-Verbose
                        "[{0}] This often happens when PowerShell recreates the WebSession between requests." -f $functionName | Write-Verbose
                    }
                }
                catch {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                    }
                    "[{0}] Failed to extract flowId: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                    throw "[{0}] Could not extract flowId from SAML redirect. {1}" -f $functionName, $_.Exception.Message
                }
                #EndRegion STEP 1
                
                #Region STEP 2: Submit username to PingOne flows API
                "[{0}] Step 2: Submitting username to PingOne" -f $functionName | Write-Verbose

                # Log current cookies in session for debugging
                $cookieCount = ($Session.Cookies.GetCookies($authBaseUrl) | Measure-Object).Count
                "[{0}] Session has {1} cookies for auth.pingone.{2}" -f $functionName, $cookieCount, $pingRegion | Write-Verbose
                if ($cookieCount -gt 0) {
                    $Session.Cookies.GetCookies($authBaseUrl) | ForEach-Object {
                        "[{0}]   Cookie: {1}" -f $functionName, $_.Name | Write-Verbose
                    }
                }

                # Extract username from email if needed (PingOne expects "username", not "username@company.com")
                $usernameOnly = $Username
                if ($Username -match '^([^@]+)@') {
                    $usernameOnly = $matches[1]
                    "[{0}] Extracted username '{1}' from email '{2}'" -f $functionName, $usernameOnly, $Username | Write-Verbose
                }

                $userLookupUrl = "$authBaseUrl/$EnvironmentId/flows/$flowId"
                $payload = @{ username = $usernameOnly } | ConvertTo-Json -Depth 10 -Compress
                
                # Construct apps origin/referer by replacing auth. with apps.
                $appsBaseUrl = $authBaseUrl -replace '^https://auth\.', 'https://apps.'
                $headers = @{
                    "Content-Type" = "application/vnd.pingidentity.user.lookup+json"
                    "Accept"       = "*/*"
                    "Origin"       = $appsBaseUrl
                    "Referer"      = "$appsBaseUrl/"
                }

                try {
                    $userLookupResponse = Invoke-RestMethod -Uri $userLookupUrl -Method POST -ErrorAction Stop `
                        -Headers $headers -Body $payload -WebSession $Session

                    "[{0}] Username submitted successfully" -f $functionName | Write-Verbose
                    
                    # Check if PingOne is requesting password instead of passwordless MFA
                    # This indicates misconfiguration - passwordless policy not properly set up
                    $responseJson = $userLookupResponse | ConvertTo-Json -Depth 10 -Compress
                    "[{0}] Response structure: {1}" -f $functionName, $responseJson | Write-Verbose
                    
                    # Check for password authentication request patterns
                    $passwordRequested = $false
                    $passwordIndicators = @()
                    
                    # Pattern 1: Check for password.verify link in HAL format
                    if ($userLookupResponse._links -and $userLookupResponse._links.'password.verify') {
                        $passwordRequested = $true
                        $passwordIndicators += "password.verify link found"
                        "[{0}] Detected password.verify link in response - password authentication required" -f $functionName | Write-Verbose
                    }
                    
                    # Pattern 2: Check for password.check or usernamePassword links
                    if ($userLookupResponse._links -and ($userLookupResponse._links.'password.check' -or $userLookupResponse._links.'usernamePassword')) {
                        $passwordRequested = $true
                        $passwordIndicators += "password authentication link found"
                        "[{0}] Detected password authentication link in response" -f $functionName | Write-Verbose
                    }
                    
                    # Pattern 3: Check for explicit authType=PASSWORD or similar
                    if ($userLookupResponse.authType -match 'password|PASSWORD') {
                        $passwordRequested = $true
                        $passwordIndicators += "authType=$($userLookupResponse.authType)"
                        "[{0}] Detected password authType in response" -f $functionName | Write-Verbose
                    }
                    
                    # Pattern 4: Check if response lacks PingID authentication link (critical)
                    $hasPingIDLink = $false
                    if ($userLookupResponse._links -and $userLookupResponse._links.'pingid.authentication') {
                        $hasPingIDLink = $true
                        "[{0}] Confirmed PingID passwordless authentication link present" -f $functionName | Write-Verbose
                    }
                    
                    # If password is requested instead of PingID, fail with clear error
                    if ($passwordRequested) {
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                        }
                        
                        $indicators = $passwordIndicators -join ", "
                        "[{0}] ERROR: PingOne is requesting password authentication instead of passwordless MFA" -f $functionName | Write-Verbose
                        "[{0}] Indicators: {1}" -f $functionName, $indicators | Write-Verbose
                        Write-Error @"
Password authentication is not supported.

Please configure PingOne to use passwordless authentication only.

For setup prerequisites, see: $script:HelpUrl
"@ -ErrorAction Stop
                    }                    # Warn if no PingID link found (might be a different MFA method or misconfiguration)
                    if (-not $hasPingIDLink) {
                        "[{0}] WARNING: No PingID authentication link found in response" -f $functionName | Write-Verbose
                        "[{0}] This may indicate PingID is not configured for this user or environment" -f $functionName | Write-Verbose
                    }
                }
                catch {
                    # Enhanced error diagnostics - check for passwordless policy misconfiguration
                    $errorDetails = $_.Exception.Message
                    $serverErrorBody = $null
                    
                    if ($_.Exception.Response) {
                        try {
                            $errorStream = $_.Exception.Response.GetResponseStream()
                            $reader = New-Object System.IO.StreamReader($errorStream)
                            $serverErrorBody = $reader.ReadToEnd()
                            $reader.Close()
                            "[{0}] Server response body: {1}" -f $functionName, $serverErrorBody | Write-Verbose
                        }
                        catch { }
                    }
                    
                    # Check if error indicates passwordless is disabled (400 Bad Request with CONSTRAINT_VIOLATION or Invalid flow status)
                    $passwordlessDisabled = $false
                    if ($serverErrorBody) {
                        # Parse error response if it's JSON
                        try {
                            $errorObj = $serverErrorBody | ConvertFrom-Json
                            if ($errorObj.code -eq "REQUEST_FAILED" -or $errorObj.code -eq "CONSTRAINT_VIOLATION") {
                                $passwordlessDisabled = $true
                                "[{0}] Detected REQUEST_FAILED/CONSTRAINT_VIOLATION - likely passwordless disabled" -f $functionName | Write-Verbose
                            }
                            if ($serverErrorBody -match "Invalid request for flow status|flow status") {
                                $passwordlessDisabled = $true
                                "[{0}] Detected 'Invalid flow status' error - passwordless disabled" -f $functionName | Write-Verbose
                            }
                        }
                        catch {
                            # Not JSON, check raw text
                            if ($serverErrorBody -match "CONSTRAINT_VIOLATION|Invalid request for flow|REQUEST_FAILED") {
                                $passwordlessDisabled = $true
                                "[{0}] Detected constraint violation in error text - passwordless disabled" -f $functionName | Write-Verbose
                            }
                        }
                    }
                    
                    # Check HTTP status code - 400 Bad Request often indicates policy issue
                    if ($_.Exception.Response.StatusCode -eq 400) {
                        $passwordlessDisabled = $true
                        "[{0}] Detected HTTP 400 Bad Request - likely passwordless policy issue" -f $functionName | Write-Verbose
                    }
                    
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                    }
                    
                    # Provide clear error message if passwordless is disabled
                    if ($passwordlessDisabled) {
                        "[{0}] ERROR: PingOne rejected the passwordless authentication request" -f $functionName | Write-Verbose
                        "[{0}] This indicates passwordless policy is DISABLED in PingOne" -f $functionName | Write-Verbose
                        Write-Error @"
Password authentication is not supported.

Please configure PingOne to use passwordless authentication only.

For setup prerequisites, see: $script:HelpUrl
"@ -ErrorAction Stop
                    }

                    # Generic error handling if not a passwordless issue
                    "[{0}] Failed to submit username: {1}" -f $functionName, $errorDetails | Write-Verbose
                    "[{0}] Request URL: {1}" -f $functionName, $userLookupUrl | Write-Verbose
                    "[{0}] Request body: {1}" -f $functionName, $payload | Write-Verbose
                    "[{0}] Cookies available: {1}" -f $functionName, $cookieCount | Write-Verbose
                    
                    if ($serverErrorBody) {
                        $errorMessage = @"
User authentication failed.

This error can occur for multiple reasons:

1. User account does not exist in PingOne environment $EnvironmentId
2. User account is disabled or locked
3. User is not assigned to the HPE GreenLake application in PingOne
   - Contact your PingOne administrator to verify application access
   - Ensure you have the required app role assignments

Additional error details: $errorDetails

Server response: 
$serverErrorBody

For complete PingIdentity setup prerequisites, see: $script:HelpUrl
"@
                        Write-Error $errorMessage -ErrorAction Stop
                    }
                    else {
                        throw
                    }
                }
                #EndRegion STEP 2                
                
                #Region STEP 3: Initiate PingID authentication
                "[{0}] Step 3: Initiating PingID authentication" -f $functionName | Write-Verbose

                # Extract necessary parameters from HAL response
                # PingOne uses HAL (Hypertext Application Language) format with _links
                $idpAccountId = $null
                $ppmRequest = $null

                # Check if response has _links.pingid.authentication.href (HAL format)
                if ($userLookupResponse._links -and $userLookupResponse._links.'pingid.authentication' -and $userLookupResponse._links.'pingid.authentication'.href) {
                    $authUrl = $userLookupResponse._links.'pingid.authentication'.href
                    "[{0}] Found PingID authentication URL in HAL _links: {1}" -f $functionName, $authUrl | Write-Verbose
                                
                    # Extract idp_account_id and ppm_request from query parameters
                    if ($authUrl -match '[?&]idp_account_id=([^&]+)') {
                        $idpAccountId = $matches[1]
                        "[{0}] Extracted idpAccountId from URL: {1}" -f $functionName, $idpAccountId | Write-Verbose
                    }
                                
                    if ($authUrl -match '[?&]ppm_request=([^&]+)') {
                        $ppmRequest = $matches[1]
                        "[{0}] Extracted ppmRequest from URL (length: {1})" -f $functionName, $ppmRequest.Length | Write-Verbose
                    }
                }
                else {
                    # Fallback: try direct properties (older format)
                    $idpAccountId = $userLookupResponse.idpAccountId
                    $ppmRequest = $userLookupResponse.ppmRequest
                                
                    if ($idpAccountId -and $ppmRequest) {
                        "[{0}] Extracted parameters from direct properties (legacy format)" -f $functionName | Write-Verbose
                    }
                }

                if (-not $idpAccountId -or -not $ppmRequest) {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                    }
                                
                    # Enhanced diagnostics
                    "[{0}] ERROR: Could not extract required parameters from response" -f $functionName | Write-Verbose
                    "[{0}]   Response format: {1}" -f $functionName, ($userLookupResponse | ConvertTo-Json -Depth 2 -Compress) | Write-Verbose
                    "[{0}]   idpAccountId found: {1}" -f $functionName, ($null -ne $idpAccountId) | Write-Verbose
                    "[{0}]   ppmRequest found: {1}" -f $functionName, ($null -ne $ppmRequest) | Write-Verbose

                    $errorMessage = @"
PingID passwordless authentication is not enabled for this account.

This error can occur for multiple reasons:

1. PingID MFA is not configured for this user in environment $EnvironmentId
   - Install PingID on your mobile device
   - Enroll PingID through your organization's PingOne portal
   - Ensure push notifications are enabled for PingID
   - Verify PingOne authentication policy requires PingID (not password)
   - Test the enrollment by signing in through a web browser first

2. User is not assigned to the HPE GreenLake application in PingOne
   - Contact your PingOne administrator to verify application access
   - Ensure you have the required app role assignments

For complete PingIdentity setup prerequisites, see: $script:HelpUrl
"@
                    Write-Error $errorMessage -ErrorAction Stop
                }

                # POST to authenticator.pingone.com to initiate PingID auth
                $pingIdAuthUrl = "$authenticatorBaseUrl/pingid/ppm/auth"
                $authBody = "iss=PingOneV2&idp_account_id=$idpAccountId&ppm_request=$ppmRequest"
                $headers = @{
                    "Content-Type" = "application/x-www-form-urlencoded"
                    "Accept"       = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
                }

                try {
                    $pingIdAuthResponse = Invoke-WebRequest -Uri $pingIdAuthUrl -Method POST -ErrorAction Stop `
                        -Headers $headers -Body $authBody -WebSession $Session

                    "[{0}] PingID authentication initiated" -f $functionName | Write-Verbose
                }
                catch {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                    }
                    "[{0}] Failed to initiate PingID authentication: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                    throw "[{0}] Could not initiate PingID authentication. {1}" -f $functionName, $_.Exception.Message
                }
                #EndRegion STEP 3

                #Region STEP 4: Submit WebAuthn capabilities
                "[{0}] Step 4: Submitting WebAuthn capabilities" -f $functionName | Write-Verbose

                $webAuthnBody = "isWebAuthnSupportedByBrowser=true&isWebAuthnPlatformAuthenticatorAvailable=false&isWebAuthnTimeout=false"
                $headers = @{
                    "Content-Type" = "application/x-www-form-urlencoded"
                    "Accept"       = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
                }

                $webAuthnResponse = $null
                try {
                    $webAuthnResponse = Invoke-WebRequest -Uri $pingIdAuthUrl -Method POST -ErrorAction Stop `
                        -Headers $headers -Body $webAuthnBody -WebSession $Session

                    "[{0}] WebAuthn capabilities submitted" -f $functionName | Write-Verbose
                }
                catch {
                    # Non-critical error, continue with initial response
                    "[{0}] Warning: Failed to submit WebAuthn capabilities: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                }
                #EndRegion STEP 4

                #Region STEP 5: Determine authentication method and handle accordingly
                "[{0}] Step 5: Determining authentication method" -f $functionName | Write-Verbose

                # Extract CSRF token - try WebAuthn response first (Step 4), then initial response (Step 3)
                # The CSRF token location varies by PingOne environment configuration
                $csrfToken = $null
                $responseToSearch = if ($webAuthnResponse) { $webAuthnResponse.Content } else { $pingIdAuthResponse.Content }
                $responseSource = if ($webAuthnResponse) { "WebAuthn response" } else { "initial auth response" }
                
                # Try multiple regex patterns to extract CSRF token
                if ($responseToSearch -match 'csrfToken["\s]*[:=]["\s]*["'']([^"'']+)["'']') {
                    $csrfToken = $matches[1]
                    "[{0}] Extracted CSRF token from {1} (pattern 1): {2}" -f $functionName, $responseSource, $csrfToken | Write-Verbose
                }
                elseif ($responseToSearch -match 'name="csrfToken"[^>]*value="([^"]+)"') {
                    $csrfToken = $matches[1]
                    "[{0}] Extracted CSRF token from {1} (pattern 2 - hidden input): {2}" -f $functionName, $responseSource, $csrfToken | Write-Verbose
                }
                elseif ($responseToSearch -match 'data-csrf-token="([^"]+)"') {
                    $csrfToken = $matches[1]
                    "[{0}] Extracted CSRF token from {1} (pattern 3 - data attribute): {2}" -f $functionName, $responseSource, $csrfToken | Write-Verbose
                }
                elseif ($responseToSearch -match 'csrf[_-]?token["\s]*[:=]["\s]*["'']([^"'']+)["'']') {
                    $csrfToken = $matches[1]
                    "[{0}] Extracted CSRF token from {1} (pattern 4 - flexible): {2}" -f $functionName, $responseSource, $csrfToken | Write-Verbose
                }
                else {
                    # CSRF token not found - this might be OK if PingOne doesn't require it for the response page
                    "[{0}] WARNING: Could not extract CSRF token from {1}" -f $functionName, $responseSource | Write-Verbose
                    "[{0}] Will attempt to retrieve tokens without CSRF token" -f $functionName | Write-Verbose
                }
                
                # Extract number challenge from WebAuthn response (Step 4) if available
                # Number challenge appears AFTER WebAuthn submission, not in initial response
                $numberChallenge = $null
                $numberResponseContent = if ($webAuthnResponse) { $webAuthnResponse.Content } else { $pingIdAuthResponse.Content }
                
                if ($numberResponseContent -match '<div\s+class="numbermatching">(\d+)</div>') {
                    $numberChallenge = $matches[1]
                    "[{0}] Detected number matching challenge: {1}" -f $functionName, $numberChallenge | Write-Verbose
                }
                elseif ($numberResponseContent -match 'data-challenge-number["\s]*[:=]["\s]*["''](\d+)["'']') {
                    $numberChallenge = $matches[1]
                    "[{0}] Detected number matching challenge: {1}" -f $functionName, $numberChallenge | Write-Verbose
                }
                elseif ($numberResponseContent -match 'challenge["\s]*[:=]["\s]*["''](\d+)["'']') {
                    $numberChallenge = $matches[1]
                    "[{0}] Detected number matching challenge: {1}" -f $functionName, $numberChallenge | Write-Verbose
                }
                
                # Check OTP availability and policy enforcement
                # Use WebAuthn response (Step 4) to check for OTP option and policy restrictions
                $responseContent = if ($webAuthnResponse) { $webAuthnResponse.Content } else { $pingIdAuthResponse.Content }
                $hasOtpOption = $responseContent -match 'use.*code|enter.*code|otp|passcode|data-use-code'
                
                # Check if OTP-only is enforced by policy (push disabled)
                # Policy OTP can be detected by specific HTML elements or data attributes in the response
                $otpOnlyByPolicy = $responseContent -match 'data-policy["\s]*[:=]["\s]*["'']otp["'']|policy["\s]*[:=]["\s]*["'']OTP["'']|otpOnly["\s]*[:=]["\s]*true'
                
                # If HTML detection didn't find policy enforcement, do a quick status check
                # This catches POLICY_OTP that's only visible via status endpoint
                if (-not $otpOnlyByPolicy -and $hasOtpOption) {
                    "[{0}] Performing quick status check to detect OTP-only policy..." -f $functionName | Write-Verbose
                    try {
                        $statusUrl = "$authenticatorBaseUrl/pingid/ppm/auth/status"
                        $timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
                        $quickStatusCheck = Invoke-RestMethod -Uri "$statusUrl`?_=$timestamp" -Method GET -ErrorAction Stop `
                            -Headers @{"Accept" = "*/*" } -WebSession $Session
                        
                        "[{0}] Quick status response: {1}" -f $functionName, ($quickStatusCheck | ConvertTo-Json -Compress) | Write-Verbose
                        
                        if ($quickStatusCheck.status -eq "POLICY_OTP") {
                            $otpOnlyByPolicy = $true
                            "[{0}] Detected POLICY_OTP via status check - OTP enforced by policy" -f $functionName | Write-Verbose
                        }
                    }
                    catch {
                        "[{0}] Quick status check failed: {1} - will proceed with default detection" -f $functionName, $_.Exception.Message | Write-Verbose
                    }
                }
                
                # Determine authentication method to use
                # Push notification is the default and primary method
                # OTP is used if: 1) enforced by policy, 2) push unavailable, or 3) user preference (not implemented)
                $useOtp = $false
                $pushAvailable = -not ($responseContent -match 'push.*not.*available|push.*unavailable|no.*device')
                
                if ($otpOnlyByPolicy) {
                    # OTP enforced by administrator policy
                    $useOtp = $true
                    "[{0}] Selected method: OTP code (enforced by policy - push disabled by administrator)" -f $functionName | Write-Verbose
                }
                elseif ($pushAvailable) {
                    # Push is available and will be used (default)
                    "[{0}] Selected method: Push notification (default)" -f $functionName | Write-Verbose
                }
                elseif ($hasOtpOption) {
                    # Push not available, automatic fallback to OTP
                    $useOtp = $true
                    "[{0}] Selected method: OTP code (push not available, automatic fallback)" -f $functionName | Write-Verbose
                }
                else {
                    # Neither method available
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                    }
                    throw "[{0}] Neither push nor OTP authentication available. For PingOne setup prerequisites, see: {1}" -f $functionName, $script:HelpUrl
                }
                #EndRegion STEP 5

                #Region STEP 6: Handle OTP Code Input (if selected)
                if ($useOtp) {
                    "[{0}] Step 6: Handling OTP code authentication" -f $functionName | Write-Verbose

                    $otpCode = Read-Host -Prompt "Enter your PingID OTP code for $($Username)"

                    if ([string]::IsNullOrWhiteSpace($otpCode)) {
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                        }
                        throw "[{0}] OTP code is required" -f $functionName
                    }

                    # Submit OTP code
                    $otpSubmitUrl = "$authenticatorBaseUrl/pingid/ppm/auth/otp"
                    $otpBody = "otp=$otpCode&csrfToken=$csrfToken"
                    
                    $headers = @{
                        "Content-Type" = "application/x-www-form-urlencoded"
                        "Accept"       = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
                    }

                    try {
                        $otpResponse = Invoke-WebRequest -Uri $otpSubmitUrl -Method POST -ErrorAction Stop `
                            -Headers $headers -Body $otpBody -WebSession $Session

                        "[{0}] OTP code submitted successfully" -f $functionName | Write-Verbose

                        # Extract JWT tokens from OTP response
                        $ppmRequest = $null
                        $ppmResponse = $null

                        if ($otpResponse.Content -match 'name="ppm_request"[^>]*value="([^"]+)"') {
                            $ppmRequest = $matches[1]
                            "[{0}] Extracted ppm_request token from OTP response" -f $functionName | Write-Verbose
                        }

                        if ($otpResponse.Content -match 'name="ppm_response"[^>]*value="([^"]+)"') {
                            $ppmResponse = $matches[1]
                            "[{0}] Extracted ppm_response token from OTP response" -f $functionName | Write-Verbose
                        }

                        if (-not $ppmRequest -or -not $ppmResponse) {
                            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                            }
                            throw "[{0}] Could not extract JWT tokens from OTP response" -f $functionName
                        }

                        # Skip to callback step
                        "[{0}] OTP authentication completed, proceeding to callback" -f $functionName | Write-Verbose
                    }
                    catch {
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                        }

                        $errorMessage = "Invalid OTP code. Please verify the code and try again"
                        
                        if ($_.Exception.Response) {
                            try {
                                $errorStream = $_.Exception.Response.GetResponseStream()
                                $reader = New-Object System.IO.StreamReader($errorStream)
                                $errorBody = $reader.ReadToEnd()
                                $reader.Close()
                                
                                if ($errorBody -match 'error|invalid|incorrect') {
                                    $errorMessage = $errorBody
                                }
                            }
                            catch { }
                        }

                        "[{0}] Failed to submit OTP code: {1}" -f $functionName, $errorMessage | Write-Verbose
                        throw $errorMessage
                    }
                }
                else {
                    # Continue with push notification flow
                    "[{0}] Step 6: Polling for push approval" -f $functionName | Write-Verbose

                    Start-Sleep -Milliseconds 500

                    # Show appropriate progress message based on number challenge
                    # Always show number challenge (bypasses NoProgress for critical info)
                    if ($numberChallenge) {
                        Update-ProgressBar -CompletedSteps $CompletedSteps.Value -TotalSteps $TotalSteps `
                            -CurrentActivity "Respond '$numberChallenge' to the PingID notification" -Id 0
                        "[{0}] Number challenge active - user must select: {1}" -f $functionName, $numberChallenge | Write-Verbose
                    }
                    else {
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $CompletedSteps.Value -TotalSteps $TotalSteps `
                                -CurrentActivity "Waiting for PingID authentication..." -Id 0
                        }
                    }

                    "[{0}] Initiating authentication request..." -f $functionName | Write-Verbose
                    "[{0}] Waiting for authentication approval (timeout: {1} minutes)..." -f $functionName, $TimeoutMinutes | Write-Verbose

                    # Poll the status endpoint until approved
                    $statusUrl = "$authenticatorBaseUrl/pingid/ppm/auth/status"
                    $timeout = [datetime]::Now.AddMinutes($TimeoutMinutes)
                    $approved = $false
                    $timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
                    $firstPoll = $true

                    $headers = @{
                        "Accept" = "*/*"
                    }

                    do {
                        Start-Sleep -Seconds $PollIntervalSeconds

                        try {
                            # Poll status with timestamp to prevent caching
                            $statusCheckUrl = "$statusUrl`?_=$timestamp"
                            $statusResponse = Invoke-RestMethod -Uri $statusCheckUrl -Method GET -ErrorAction Stop `
                                -Headers $headers -WebSession $Session

                            "[{0}] Status poll response: {1}" -f $functionName, ($statusResponse | ConvertTo-Json -Compress) | Write-Verbose

                            # Check if authentication is complete
                            if ($statusResponse.status -eq "OK" -or $statusResponse.status -eq "SUCCESS") {
                                $approved = $true
                                "[{0}] Push notification approved!" -f $functionName | Write-Verbose
                                break
                            }
                            elseif ($statusResponse.status -eq "ASYNC_AUTH_WAIT" -or $statusResponse.status -eq "WAITING") {
                                # Still waiting for user approval - update message on first wait to confirm push was sent
                                if ($firstPoll) {
                                    "[{0}] Push notification confirmed - sent to mobile device" -f $functionName | Write-Verbose
                                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps -and -not $numberChallenge) {
                                        Update-ProgressBar -CompletedSteps $CompletedSteps.Value -TotalSteps $TotalSteps `
                                            -CurrentActivity "Approve the PingID push notification" -Id 0
                                    }
                                    $firstPoll = $false
                                }
                                else {
                                    "[{0}] Still waiting for approval..." -f $functionName | Write-Verbose
                                }
                            }
                            elseif ($statusResponse.status -eq "POLICY_OTP") {
                                # Policy requires OTP only - push is disabled by administrator
                                "[{0}] Server reported POLICY_OTP status - push disabled by policy, switching to OTP" -f $functionName | Write-Verbose
                                
                                # Prompt for OTP code
                                $otpCode = Read-Host -Prompt "Enter your PingID OTP code for $($Username)"
                                
                                if ([string]::IsNullOrWhiteSpace($otpCode)) {
                                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                                        Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                                    }
                                    throw "[{0}] OTP code is required" -f $functionName
                                }
                                
                                # Submit OTP code
                                $otpSubmitUrl = "$authenticatorBaseUrl/pingid/ppm/auth/otp"
                                $otpBody = "otp=$otpCode&csrfToken=$csrfToken"
                                
                                $otpHeaders = @{
                                    "Content-Type" = "application/x-www-form-urlencoded"
                                    "Accept"       = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
                                }
                                
                                try {
                                    $otpResponse = Invoke-WebRequest -Uri $otpSubmitUrl -Method POST -ErrorAction Stop `
                                        -Headers $otpHeaders -Body $otpBody -WebSession $Session
                                    
                                    "[{0}] OTP code submitted successfully" -f $functionName | Write-Verbose
                                    
                                    # Extract JWT tokens from OTP response
                                    if ($otpResponse.Content -match 'name="ppm_request"[^>]*value="([^"]+)"') {
                                        $ppmRequest = $matches[1]
                                        "[{0}] Extracted ppm_request token from OTP response" -f $functionName | Write-Verbose
                                    }
                                    
                                    if ($otpResponse.Content -match 'name="ppm_response"[^>]*value="([^"]+)"') {
                                        $ppmResponse = $matches[1]
                                        "[{0}] Extracted ppm_response token from OTP response" -f $functionName | Write-Verbose
                                    }
                                    
                                    if (-not $ppmRequest -or -not $ppmResponse) {
                                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                                            Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                                        }
                                        throw "[{0}] Could not extract JWT tokens from OTP response" -f $functionName
                                    }
                                    
                                    # Mark as approved to exit polling loop
                                    $approved = $true
                                    "[{0}] OTP authentication completed" -f $functionName | Write-Verbose
                                    break
                                }
                                catch {
                                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                                        Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                                    }
                                    
                                    $errorMessage = "Invalid OTP code. Please verify the code and try again"
                                    if ($_.Exception.Response) {
                                        try {
                                            $errorStream = $_.Exception.Response.GetResponseStream()
                                            $reader = New-Object System.IO.StreamReader($errorStream)
                                            $errorBody = $reader.ReadToEnd()
                                            $reader.Close()
                                            if ($errorBody -match 'error|invalid|incorrect') {
                                                $errorMessage = $errorBody
                                            }
                                        }
                                        catch { }
                                    }
                                    
                                    "[{0}] Failed to submit OTP code: {1}" -f $functionName, $errorMessage | Write-Verbose
                                    throw $errorMessage
                                }
                            }
                            elseif ($statusResponse.status -eq "TIMEOUT" -or $statusResponse.status -eq "AUTH_OTP") {
                                "[{0}] Server reported {1} status - push notification timed out" -f $functionName, $statusResponse.status | Write-Verbose
                                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                                    Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                                }
                                throw "[{0}] PingID push notification timed out. The authentication request expired before approval." -f $functionName
                            }
                            elseif ($statusResponse.status -eq "DENY" -or $statusResponse.status -eq "DENIED" -or $statusResponse.status -eq "NUMBER_MATCHING_DENY" -or $statusResponse.status -eq "FAILED") {
                                "[{0}] Push notification was denied or failed (status: {1})" -f $functionName, $statusResponse.status | Write-Verbose
                                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                                    Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                                }
                                throw "[{0}] Push notification was rejected or incorrect number was selected" -f $functionName
                            }
                            elseif ($statusResponse.status -eq "INVALID_INPUT") {
                                "[{0}] Server returned INVALID_INPUT status - policy restriction detected" -f $functionName | Write-Verbose
                                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                                    Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                                }
                                throw "[{0}] A company policy is preventing you from authenticating with PingID at this time. Contact your administrator." -f $functionName
                            }
                        }
                        catch {
                            # Check if this is a status-related throw (TIMEOUT, AUTH_OTP, DENIED, REJECTED, FAILED, POLICY) - rethrow it
                            if ($_.Exception.Message -match "timed out|denied|rejected|failed|policy|OTP code") {
                                throw
                            }
                            # Otherwise it's a network/connectivity error - log and continue polling
                            "[{0}] Status poll error: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                        }

                        # Check for timeout
                        if ([datetime]::Now -ge $timeout) {
                            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                            }
                            throw "[{0}] Timeout! PingID push notification was not approved within {1} minutes" -f $functionName, $TimeoutMinutes
                        }

                        $timestamp = [DateTimeOffset]::Now.ToUnixTimeMilliseconds()
                        
                    } while (-not $approved)

                    # Retrieve JWT tokens from response page (for push)
                    # Skip if tokens were already retrieved (e.g., from POLICY_OTP handling)
                    if (-not $ppmRequest -or -not $ppmResponse) {
                        "[{0}] Retrieving authentication tokens from response page" -f $functionName | Write-Verbose

                        # Build the response page URL - CSRF token may or may not be required
                        if ($csrfToken) {
                            "[{0}] Using CSRF token: {1}" -f $functionName, $csrfToken | Write-Verbose
                            $responsePageUrl = "$authenticatorBaseUrl/pingid/ppm/auth/response?csrfToken=$csrfToken&status=OK&getStatusResponse=%7B%22status%22%3A%22OK%22%7D"
                        }
                        else {
                            "[{0}] No CSRF token available - attempting without it" -f $functionName | Write-Verbose
                            $responsePageUrl = "$authenticatorBaseUrl/pingid/ppm/auth/response?status=OK&getStatusResponse=%7B%22status%22%3A%22OK%22%7D"
                        }
                        
                        try {
                            $tokenResponse = Invoke-WebRequest -Uri $responsePageUrl -Method GET -ErrorAction Stop `
                                -WebSession $Session -UseBasicParsing

                            "[{0}] Retrieved authentication response page" -f $functionName | Write-Verbose

                            # Extract ppm_request and ppm_response from hidden form fields
                            if ($tokenResponse.Content -match 'name="ppm_request"[^>]*value="([^"]+)"') {
                                $ppmRequest = $matches[1]
                                "[{0}] Extracted ppm_request token" -f $functionName | Write-Verbose
                            }

                            if ($tokenResponse.Content -match 'name="ppm_response"[^>]*value="([^"]+)"') {
                                $ppmResponse = $matches[1]
                                "[{0}] Extracted ppm_response token" -f $functionName | Write-Verbose
                            }

                            if (-not $ppmRequest -or -not $ppmResponse) {
                                if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                                    Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                                    Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                                }
                                throw "[{0}] Could not extract JWT tokens from authentication response" -f $functionName
                            }
                        }
                        catch {
                            if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                                Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                            }
                            "[{0}] Failed to retrieve tokens: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                            throw "[{0}] Could not retrieve authentication tokens. {1}" -f $functionName, $_.Exception.Message
                        }
                    }
                    else {
                        "[{0}] Tokens already retrieved (from POLICY_OTP handling), skipping response page" -f $functionName | Write-Verbose
                    }
                }
                #EndRegion STEP 6

                #Region STEP 7: Post callback with JWT tokens
                "[{0}] Step 7: Posting authentication callback" -f $functionName | Write-Verbose

                $callbackUrl = "$authBaseUrl/$EnvironmentId/flows/$flowId/pingIDAuthenticationCallback"
                $callbackBody = "ppm_request=$ppmRequest&ppm_response=$ppmResponse"
                
                $headers = @{
                    "Content-Type" = "application/x-www-form-urlencoded"
                    "Accept"       = "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8"
                }

                try {
                    # This should return a 302 redirect to the SAML resume URL
                    $callbackResponse = Invoke-WebRequest -Uri $callbackUrl -Method POST -ErrorAction Stop `
                        -Headers $headers -Body $callbackBody -WebSession $Session -MaximumRedirection 0

                    "[{0}] Callback posted (Status: {1})" -f $functionName, $callbackResponse.StatusCode | Write-Verbose
                }
                catch {
                    # 302 redirect is expected, catch it to get the Location header
                    if ($_.Exception.Response.StatusCode -eq 302) {
                        "[{0}] Received expected 302 redirect" -f $functionName | Write-Verbose
                    }
                    else {
                        if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                            Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                        }
                        throw "[{0}] Callback post failed. {1}" -f $functionName, $_.Exception.Message
                    }
                }
                #EndRegion STEP 7                #Region STEP 8: Resume SAML and retrieve response
                "[{0}] Step 8: Resuming SAML flow" -f $functionName | Write-Verbose

                $resumeUrl = "$authBaseUrl/$EnvironmentId/saml20/resume?flowId=$flowId"

                try {
                    $samlResumeResponse = Invoke-WebRequest -Uri $resumeUrl -Method GET -WebSession $Session -UseBasicParsing -ErrorAction Stop

                    "[{0}] SAML flow resumed successfully" -f $functionName | Write-Verbose
                    "[{0}] Authentication completed" -f $functionName | Write-Verbose

                    if ($CompletedSteps) { $CompletedSteps.Value++ }
                    return $samlResumeResponse
                }
                catch {
                    if (-not $NoProgress -and $CompletedSteps -and $TotalSteps) {
                        Update-ProgressBar -CompletedSteps $TotalSteps -TotalSteps $TotalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "PingID Authentication" -Status "Failed" -Completed
                    }
                    throw "[{0}] Could not resume SAML flow. {1}" -f $functionName, $_.Exception.Message
                }
                #EndRegion STEP 8
            }

            #Endregion Helper functions            
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
        
            # $url = "{0}?client_id={1}&redirect_uri={2}&response_type=code&scope=openid%20profile%20email&code_challenge={3}&code_challenge_method=S256" -f $authEndpoint, $dynamicClientId, $encodedRedirectUri, $codeChallenge
                
            $dynamicClientId = "aquila-user-auth"
            
            $queryParams = @{
                client_id             = $dynamicClientId
                redirect_uri          = 'https://common.cloud.hpe.com/authentication/callback'
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
            $queryParamsLog = $queryParams.PsObject.Copy()
            # Hide sensitive information in logs
            $queryParamsLog.code_challenge = "[REDACTED]"

            # Combine the base URL with the query string
            $url = "$(Get-HPEGLAPIOrgbaseURL)/authorization/v2/oauth2/default/authorize?$($queryString)"
            
            # Hide sensitive information
            $authzUrlLog = $url -replace "code_challenge=[^&]+", "code_challenge=[REDACTED]"
            "[{0}] About to execute GET request to: {1}" -f $functionName, $authzUrlLog | Write-Verbose
            "[{0}] Using the query parameters: {1}" -f $functionName, ($queryParamsLog | Out-String) | Write-Verbose
           
            $redirecturl1 = Get-302RedirectUrl -Url $url -Session $Session -StepName "Step 2"

            # Validate that we got a redirect URL
            if ([string]::IsNullOrEmpty($redirecturl1)) {
                throw "[{0}] Failed to capture redirect URL in Step 2" -f $functionName
            }

            # Log cookies
            Log-Cookies -Domain "https://aquila-org-api.common.cloud.hpe.com" -Session $session -Step "in session AFTER STEP 2"

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
           
            $redirecturl2 = Get-302RedirectUrl -Url $redirecturl1 -Session $Session -Headers $commonHeaders -StepName "Step 3"

            # Validate that we got a redirect URL
            if ([string]::IsNullOrEmpty($redirecturl2)) {
                throw "[{0}] Failed to capture redirect URL in Step 3" -f $functionName
            }

            # Log cookies
            Log-Cookies -Domain "https://sso.common.cloud.hpe.com" -Session $session -Step "in session AFTER STEP 3"

            # redirected url: 'https://aquila-org-api.common.cloud.hpe.com/internal-identity/v1alpha1/sso-authorize?scope=openid+profile+email+ccsidp&origin=common.cloud.hpe.com&response_type=code&redirect_uri=https%3A%2F%2Fsso.common.cloud.hpe.com%2Fsp%2FeyJpc3MiOiJodHRwczpcL1wvYXV0aC5ocGUuY29tXC9vYXV0aDJcL2FxdWlsYSJ9%2Fcb.openid&state=X0Du3haximeFPCiAyAdFPQSjKxmMR1&nonce=ECiFAjqbUWPsPmxhFOhGz5&client_id=0oae329tm8xw7nwZE357'
            
            # Extract the redirect_uri parameter value from $redirecturl2
            $redirectUriEncoded = ($redirecturl2 -split '[?&]') | Where-Object { $_ -like 'redirect_uri=*' } | ForEach-Object { $_ -replace '^redirect_uri=', '' }
            $redirectUri = [System.Web.HttpUtility]::UrlDecode($redirectUriEncoded)
            "[{0}] Extracted redirect_uri from Step 3 URL: '{1}'" -f $functionName, $redirectUri | Write-Verbose           

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

            $redirecturl3 = Get-302RedirectUrl -Url $redirecturl2 -Session $Session -Headers $commonHeaders -StepName "Step 4"           
            
            # Validate that we got a redirect URL
            if ([string]::IsNullOrEmpty($redirecturl3)) {
                throw "[{0}] Failed to capture redirect URL in Step 4" -f $functionName
            }

            # Log cookies
            Log-Cookies -Domain "https://sso.common.cloud.hpe.com" -Session $session -Step "in session AFTER STEP 4"

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

            $redirecturl4 = Get-302RedirectUrl -Url $redirecturl3 -Session $Session -StepName "Step 5"  

            # Validate that we got a redirect URL
            if ([string]::IsNullOrEmpty($redirecturl4)) {
                throw "[{0}] Failed to capture redirect URL in Step 5" -f $functionName
            }

            # Log cookies
            Log-Cookies -Domain "https://auth.hpe.com" -Session $session -Step "in session AFTER STEP 5"

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

            $redirecturl5 = Get-302RedirectUrl -Url $redirecturl4 -Session $Session -StepName "Step 6"

            # Validate that we got a redirect URL
            if ([string]::IsNullOrEmpty($redirecturl5)) {
                throw "[{0}] Failed to capture redirect URL in Step 6" -f $functionName
            }

            # Log cookies
            Log-Cookies -Domain "https://aquila-org-api.common.cloud.hpe.com" -Session $session -Step "in session AFTER STEP 6"
            
            # redirected url: https://common.cloud.hpe.com/sso/continue?state=XXXXX

            # Extract the state parameter value from $redirecturl5
            $Answeredstate = ($redirecturl5 -split '[?&]') | Where-Object { $_ -like 'state=*' } | ForEach-Object { $_ -replace '^state=', '' } 
            "[{0}] Extracted state from redirection: '{1}'" -f $functionName, $Answeredstate | Write-Verbose


            $completedSteps++

            #EndRegion                  

            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            #Region [STEP 7] Resolve SSO and extract parameters
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName | Write-Verbose
            "[{0}] [STEP 7] Resolve SSO and extract parameters" -f $functionName | Write-Verbose
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName | Write-Verbose

            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Resolve SSO" -Id 0
            $step++

            $ssoResolveUrl = "$(Get-HPEGLAPIOrgbaseURL)/internal-identity/v1alpha1/sso-resolve?login_hint=$($Username)&state=$($Answeredstate)"
            "[{0}] Step 7 - Resolve SSO: '{1}'" -f $functionName, $ssoResolveUrl | Write-Verbose

            $selectorUrl = Get-302RedirectUrl -Url $ssoResolveUrl -Session $Session -StepName "Step 7"       

            # Extract and decode the redirect parameter from selector URL
            $Redirect = ($selectorUrl -split '[?&]') | Where-Object { $_ -like 'redirect=*' } | ForEach-Object { $_ -replace '^redirect=', '' }
            $decodedRedirect = [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String([System.Web.HttpUtility]::UrlDecode($Redirect)))
            "[{0}] Decoded redirect parameter: '{1}'" -f $functionName, $decodedRedirect | Write-Verbose

            $display = Get-QueryParameter -Url $decodedRedirect -ParamName 'display'
            $idp = Get-QueryParameter -Url $decodedRedirect -ParamName 'idp'
            $clientId = Get-QueryParameter -Url $decodedRedirect -ParamName 'client_id'
            $nonce = Get-QueryParameter -Url $decodedRedirect -ParamName 'nonce'
            $ccsRedirecturi = Get-QueryParameter -Url $decodedRedirect -ParamName 'redirect_uri'

            "[{0}] Extracted display: '{1}'" -f $functionName, [System.Web.HttpUtility]::UrlDecode($display) | Write-Verbose
            "[{0}] Extracted idp: '{1}'" -f $functionName, $idp | Write-Verbose
            "[{0}] Extracted client_id: '{1}'" -f $functionName, $clientId | Write-Verbose

            # Must add a check to ensure the domain is "pre-claimed" for auto-SSO, if not, the process must stop with an error message
            if ([string]::IsNullOrEmpty($idp) -or [string]::IsNullOrEmpty($clientId) -or [string]::IsNullOrEmpty($nonce) -or [string]::IsNullOrEmpty($ccsRedirecturi)) {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }

                Write-Error @"
Authentication failed: SSO configuration issue detected.

The domain for '$Username' is not configured for SSO or the SSO setup is incomplete. 

Please verify the email domain is pre-claimed in HPE GreenLake and SSO is properly configured for this domain. 

Contact your administrator if you need assistance.
"@ -ErrorAction Stop
            }

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
                idp           = $idp
                login_hint    = $Username
                nonce         = $nonce
                prompt        = "login" 
                redirect_uri  = $ccsRedirecturi
                response_type = "code"
                scope         = "openid profile email ccsidp"
                sso_options   = "false"
                state         = $Answeredstate
                display       = [System.Web.HttpUtility]::UrlDecode($display)
            }

            # Build the query string
            $queryString = ($queryParams.GetEnumerator() | ForEach-Object { "$($_.Key)=$([System.Web.HttpUtility]::UrlEncode($_.Value.ToString()))" }) -join "&"

            # Combine the base URL with the query string
            $url = "$($authorizeBaseUrl)?$($queryString)"

            "[{0}] About to execute GET request to: {1}" -f $functionName, $url | Write-Verbose
            "[{0}] Using the query parameters: {1}" -f $functionName, ($queryParams | Out-String) | Write-Verbose

            $redirecturl7 = Get-302RedirectUrl -Url $url -Session $Session -StepName "Step 8"
                    
            # Validate that we got a redirect URL
            if ([string]::IsNullOrEmpty($redirecturl7)) {
                throw "[{0}] Failed to capture redirect URL in Step 8" -f $functionName
            }

            # Log cookies
            Log-Cookies -Domain "https://auth.hpe.com/" -Session $session -Step "in session AFTER STEP 8"

            $completedSteps++

            #EndRegion

            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            #Region [STEP 9] Follow nextredirection to 'https://auth.hpe.com/sso/idps/0oa1j3ahd46U2O1n4358?stateTokenExternalId=XXXXXXXXXXXXXXXXXXXX'
            # ---------------------------------------------------------------------------------------------------------------------------------------------------------

            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName, $href | Write-Verbose
            "[{0}] [STEP 9] Follow redirection: '{1}'" -f $functionName, $redirecturl7 | Write-Verbose
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName, $href | Write-Verbose

            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Follow redirection" -Id 0
            $step++

            $redirecturl8 = Get-302RedirectUrl -Url $redirecturl7 -Session $Session -StepName "Step 9"

            # Validate that we got a redirect URL
            if ([string]::IsNullOrEmpty($redirecturl8)) {
                throw "[{0}] Failed to capture redirect URL in Step 9" -f $functionName
            }

            # Log cookies
            Log-Cookies -Domain "https://sso.common.cloud.hpe.com/" -Session $session -Step "in session AFTER STEP 9"


            $completedSteps++

            #EndRegion  

            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            #Region [STEP 10] Follow redirection to capture OktaData to 'https://sso.common.cloud.hpe.com/as/authorization.oauth2?
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
            "[{0}] [STEP 10] Follow redirection: '{1}'" -f $functionName, $redirecturl8 | Write-Verbose
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName, $href | Write-Verbose

            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Follow redirection" -Id 0
            $step++

            try {
                # Initial GET request - may return SAML form directly (Legacy IAM) or identity selection page (Enhanced IAM)
                $responseStep10 = Invoke-WebRequest $redirecturl8 -Method Get -WebSession $Session -MaximumRedirection 5 -ErrorAction Stop
    
                "[{0}] Received status code response: '{1}' - Description: '{2}'" -f $functionName, $responseStep10.StatusCode, $responseStep10.StatusDescription | Write-Verbose

                # Check what type of response we received
                $hasSAMLForm = $responseStep10.Content -match 'name="SAMLRequest"'
                $hasIdentitySelection = $responseStep10.Content -match 'name="subject"' -or 
                $responseStep10.Content -match 'resumeSAML20' -and $responseStep10.Content -match '<form'

                if ($hasSAMLForm) {
                    "[{0}] Direct SAML form received (Legacy IAM or already authenticated)" -f $functionName | Write-Verbose
                }
                elseif ($hasIdentitySelection) {
                    "[{0}] Identity selection page detected (Enhanced IAM) - submitting user identity" -f $functionName | Write-Verbose
                    
                    # Extract form action URL
                    $formActionMatch = ($responseStep10.Content | Select-String -Pattern '<form[^>]*action="([^"]+)"').Matches | Select-Object -First 1
                    $formAction = if ($formActionMatch) { 
                        [System.Web.HttpUtility]::HtmlDecode($formActionMatch.Groups[1].Value)
                    }
                    else {
                        # Use current URL if no action specified
                        $responseStep10.BaseResponse.RequestMessage.RequestUri.AbsoluteUri
                    }
                    
                    "[{0}] Submitting identity to: {1}" -f $functionName, $formAction | Write-Verbose
                    
                    # POST with subject parameter to select user identity
                    $identityBody = @{
                        subject                           = $Username
                        "clear.previous.selected.subject" = ""
                        "cancel.identifier.selection"     = "false"
                    }
                    
                    $responseStep10 = Invoke-WebRequest -Uri $formAction -Method POST -Body $identityBody `
                        -WebSession $Session -ContentType "application/x-www-form-urlencoded" `
                        -MaximumRedirection 5 -ErrorAction Stop

                    "[{0}] Identity submitted successfully - status: {1}" -f $functionName, $responseStep10.StatusCode | Write-Verbose
                    
                    # Verify we now have SAML form
                    if (-not ($responseStep10.Content -match 'name="SAMLRequest"')) {
                        throw "[{0}] Expected SAML form after identity selection but did not receive it" -f $functionName
                    }
                    
                    "[{0}] SAML form received after identity selection" -f $functionName | Write-Verbose
                }
                else {
                    "[{0}] WARNING: Unexpected response type - no SAML form or identity selection detected" -f $functionName | Write-Verbose
                }

                # Display response for debugging
                $lastLines = ($responseStep10.Content -split "`r?`n") | Select-Object -Last 30
                "[{0}] Raw response for Step 10 (last 30 lines):`n{1}" -f $functionName, ($lastLines -join "`n") | Write-Verbose

            }
            catch {
                "[{0}] Error in Step 10: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                throw "[{0}] Authentication failed: {1}" -f $functionName, $_.Exception.Message                    
            }

            # Extract SAMLAction, SAMLRequest, Method, and RelayState with error handling
            try {
                $SAMLActionMatch = ($responseStep10.Content -join "`n" | Select-String -Pattern 'action="([^"]+)"').Matches | Select-Object -First 1
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
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                "[{0}] SAML form parsing error: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                Write-Error @"
[$functionName] Failed to parse SAML authentication form. 

The HPE GreenLake SSO page structure may have changed. 

Error: $($_.Exception.Message)
"@ -ErrorAction Stop
            }
            
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
                Write-Error @"
Error decoding base64 SAMLRequest: $_

Raw SAMLRequest: $SAMLRequestValue
"@ -ErrorAction Stop
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

                # Use standard Invoke-WebRequest for all providers
                # PingOne authentication flow doesn't require special cookie handling at this step
                # Cookies will be managed naturally by the WebRequestSession throughout the flow
                $responseStep11 = Invoke-WebRequest -Method $SAMLMethodValue -Uri $SAMLActionValue -Body $body `
                    -WebSession $session -ContentType "application/x-www-form-urlencoded" `
                    -MaximumRedirection 1 -ErrorAction Stop
    
                "[{0}] Received status code: '{1}' - Description: '{2}'" -f $functionName, $responseStep11.StatusCode, $responseStep11.StatusDescription | Write-Verbose
    
                "[{0}] Content for `$responseStep11 starts with: {1}..." -f $functionName, ($responseStep11.Content.Substring(0, [Math]::Min(100, $responseStep11.Content.Length))) | Write-Verbose

            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                "[{0}] Failed to submit SAML request to {1}: {2}" -f $functionName, $SAMLActionValue, $_.Exception.Message | Write-Verbose
                throw "[{0}] Failed to submit SAML request to {1}: {2}" -f $functionName, $SAMLActionValue, $_
            }

            $completedSteps++

            #EndRegion


            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            #Region [STEP 12] Handle IdP Authentication Flow

            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName | Write-Verbose
            "[{0}] [STEP 12] Handle IdP Authentication Flow" -f $functionName | Write-Verbose
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName | Write-Verbose

            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - IdP Authentication" -Id 0
            $step++

            try {
                $currentResponse = $responseStep11
                
                # Get current URL to help with IdP detection
                $currentUrl = $currentResponse.BaseResponse.RequestMessage.RequestUri.AbsoluteUri
                "[{0}] Current response URL: {1}" -f $functionName, $currentUrl | Write-Verbose               

                $isEntraIDLoginPage = $currentUrl -match 'login\.microsoftonline\.com|login\.windows\.net|sts\.windows\.net' -and
                $currentResponse.Content -match '(Microsoft|Sign in to your account|Enter password|Stay signed in)'
                
                if ($isEntraIDLoginPage) {
                    "[{0}] Detected Entra ID login page directly (no redirect needed)" -f $functionName | Write-Verbose
                    "[{0}] Using Microsoft Authenticator MFA (push or TOTP)" -f $functionName | Write-Verbose
                    
                    # Extract Entra ID context from the login page
                    $entraContext = @{}
                    
                    # Extract from $Config JavaScript variable using more specific regex patterns
                    # Extract individual values instead of parsing entire JSON (more reliable)

                    # Extract sFT (FlowToken)
                    if ($currentResponse.Content -match '"sFT"\s*:\s*"([^"]+)"') {
                        $entraContext.FlowToken = $Matches[1]
                        "[{0}] Extracted FlowToken from \$Config" -f $functionName | Write-Verbose
                    }

                    # Extract canary token
                    if ($currentResponse.Content -match '"canary"\s*:\s*"([^"]+)"') {
                        $entraContext.CanaryToken = $Matches[1]
                        "[{0}] Extracted CanaryToken from \$Config" -f $functionName | Write-Verbose
                    }

                    # Extract sCtx (context)
                    if ($currentResponse.Content -match '"sCtx"\s*:\s*"([^"]+)"') {
                        $entraContext.Ctx = $Matches[1]
                        "[{0}] Extracted Ctx from \$Config" -f $functionName | Write-Verbose
                    }

                    # Extract correlationId (may be useful)
                    if ($currentResponse.Content -match '"correlationId"\s*:\s*"([^"]+)"') {
                        $entraContext.CorrelationId = $Matches[1]
                        "[{0}] Extracted CorrelationId from \$Config" -f $functionName | Write-Verbose
                    }

                    # Extract sessionId
                    if ($currentResponse.Content -match '"sessionId"\s*:\s*"([^"]+)"') {
                        $entraContext.SessionId = $Matches[1]
                        "[{0}] Extracted SessionId from \$Config" -f $functionName | Write-Verbose
                    }
                    
                    # Fallback: Extract from hidden form fields
                    if (-not $entraContext.FlowToken -and $currentResponse.Content -match '<input[^>]+name="flowToken"[^>]+value="([^"]+)"') {
                        $entraContext.FlowToken = $Matches[1]
                    }
                    if (-not $entraContext.CanaryToken -and $currentResponse.Content -match '<input[^>]+name="canary"[^>]+value="([^"]+)"') {
                        $entraContext.CanaryToken = $Matches[1]
                    }
                    if (-not $entraContext.Ctx -and $currentResponse.Content -match '<input[^>]+name="ctx"[^>]+value="([^"]+)"') {
                        $entraContext.Ctx = $Matches[1]
                    }
                    
                    $tenantDomain = ([System.Uri]$currentUrl).Host
                    
                    if (-not $entraContext.FlowToken -and -not $entraContext.Ctx) {
                        throw "[{0}] Could not extract Entra ID authentication context from login page" -f $functionName
                    }
                    
                    $completedStepsRef = [ref]$completedSteps
                    $currentStepRef = [ref]$step
                    
                    $responseStep12 = Invoke-EntraIDMFAAuthentication `
                        -StateToken $entraContext.Ctx `
                        -FlowToken $entraContext.FlowToken `
                        -CanaryToken $entraContext.CanaryToken `
                        -Username $Username `
                        -Session $session `
                        -TenantDomain $tenantDomain `
                        -NoProgress:$NoProgress `
                        -CompletedSteps $completedStepsRef `
                        -TotalSteps $totalSteps `
                        -CurrentStep $currentStepRef
                    
                    "[{0}] Entra ID MFA authentication completed" -f $functionName | Write-Verbose
                    $currentResponse = $responseStep12
                }
                elseif ($currentResponse.Content -match 'id="ssoForm"|name="subject"') {
        
                    "[{0}] Detected Okta identifier selection form - submitting username" -f $functionName | Write-Verbose
        
                    try {
                        $formActionMatch = ($currentResponse.Content | Select-String -Pattern '<form[^>]*action=["'']([^"'']*)["''][^>]*id="ssoForm"').Matches | Select-Object -First 1
                        $formAction = if ($formActionMatch) { [System.Web.HttpUtility]::HtmlDecode($formActionMatch.Groups[1].Value) } else { $null }
            
                        if (-not $formAction) {
                            throw "[{0}] Okta identifier form action not found" -f $functionName
                        }

                        if ($formAction -match '^/') {
                            $baseUri = [uri]$SAMLActionValue
                            $formAction = "{0}://{1}{2}" -f $baseUri.Scheme, $baseUri.Host, $formAction
                        }
            
                        $formBody = @{
                            subject                           = $Username
                            'clear.previous.selected.subject' = ''
                            'cancel.identifier.selection'     = 'false'
                        }
            
                        "[{0}] Submitting Okta identifier form to: {1}" -f $functionName, $formAction | Write-Verbose
                        $currentResponse = Invoke-WebRequest -Method POST -Uri $formAction -Body $formBody -WebSession $session -ContentType "application/x-www-form-urlencoded" -MaximumRedirection 5
                    }
                    catch {
                        "[{0}] Okta identifier form parsing error: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                        Write-Error @"
[$functionName] Failed to parse Okta identifier selection form. 

The Okta page structure may have changed. 

Error: $($_.Exception.Message)
"@ -ErrorAction Stop
                    }
                }
    
                # Extract state token from current response (before any redirects)
                # Note: PingOne uses flowId instead of stateToken
                $stateToken = $null
                $flowId = $null
                $rawToken = $null

                # Try to extract flowId from URL (PingOne)
                if ($currentUrl -match '[?&]flowId=([^&]+)') {
                    $flowId = $Matches[1]
                    "[{0}] Found flowId from URL: {1}" -f $functionName, $flowId | Write-Verbose
                }

                # Try to extract stateToken (Okta)
                if ($currentResponse.Content -match "var\s+stateToken\s*=\s*'([^']+)'") {
                    $rawToken = $Matches[1]
                    "[{0}] Found raw state token (pattern 1)" -f $functionName | Write-Verbose
                }
                elseif ($currentResponse.Content -match '"stateToken"\s*:\s*"([^"]+)"') {
                    $rawToken = $Matches[1]
                    "[{0}] Found raw state token (pattern 2 - JSON)" -f $functionName | Write-Verbose
                }

                if ($rawToken) {
                    # Decode HTML escape sequences manually
                    $stateToken = $rawToken
                    # Replace common escape sequences
                    $stateToken = $stateToken -replace '\\x2D', '-'
                    $stateToken = $stateToken -replace '\\x2B', '+'
                    $stateToken = $stateToken -replace '\\x2F', '/'
                    $stateToken = $stateToken -replace '\\x3D', '='
                    $stateToken = $stateToken -replace '\\x5F', '_'
    
                    "[{0}] Extracted and decoded state token: {1}..." -f $functionName, $stateToken.Substring(0, [Math]::Min(50, $stateToken.Length)) | Write-Verbose
                }
                elseif (-not $flowId) {
                    "[{0}] Neither state token nor flowId found in response" -f $functionName | Write-Verbose
                }
                # Check if we already have a SAML Response (authentication complete)
                if ($currentResponse.Content -match '<input[^>]*name=["'']SAMLResponse["'']') {
                    "[{0}] SAML Response already present - authentication complete" -f $functionName | Write-Verbose
                    $responseStep12 = $currentResponse
                }
                # Check if we have a PingOne flow (detected by flowId in URL + ping in URL)
                elseif ($flowId -and $currentUrl -match 'ping') {
                    "[{0}] Detected PingOne sign-on page with flowId" -f $functionName | Write-Verbose
                    
                    # Extract Ping environment ID from URL with error handling
                    try {
                        $pingEnvironmentId = $null
                        if ($currentUrl -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') {
                            $pingEnvironmentId = $Matches[1]
                            "[{0}] Extracted Ping environment ID from URL: {1}" -f $functionName, $pingEnvironmentId | Write-Verbose
                        }
                        
                        if (-not $pingEnvironmentId) {
                            throw "[{0}] Could not extract PingOne environment ID from URL: {1}" -f $functionName, $currentUrl
                        }
                    }
                    catch {
                        "[{0}] PingOne environment ID extraction error: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                        Write-Error @"
[$functionName] Failed to extract PingOne environment ID from URL. 

The PingOne URL format may have changed. 

Current URL: $currentUrl
"@ -ErrorAction Stop
                    }
                    
                    "[{0}] Using PingID MFA (push or TOTP)" -f $functionName | Write-Verbose
                    "[{0}] Environment ID: {1}, FlowId: {2}" -f $functionName, $pingEnvironmentId, $flowId | Write-Verbose
                    
                    # Create refs for progress tracking
                    $completedStepsRef = [ref]$completedSteps
                    $currentStepRef = [ref]$step
                    
                    $responseStep12 = Invoke-PingIDMFAAuthentication `
                        -SAMLRedirectUrl $currentUrl `
                        -Username $Username `
                        -Session $session `
                        -EnvironmentId $pingEnvironmentId `
                        -NoProgress:$NoProgress `
                        -CompletedSteps $completedStepsRef `
                        -TotalSteps $totalSteps `
                        -CurrentStep $currentStepRef 

                }
                # Check if we need to redirect to another IdP or handle push authentication
                elseif ($currentResponse.Content -match '<form[^>]*action=["'']([^"'']*)["'']') {
                    # Extract SAML redirect form with error handling
                    try {
                        $autoPostFormMatch = ($currentResponse.Content | Select-String -Pattern '<form[^>]*action=["'']([^"'']*)["''][^>]*>').Matches | Select-Object -First 1
                        $autoPostAction = if ($autoPostFormMatch) { [System.Web.HttpUtility]::HtmlDecode($autoPostFormMatch.Groups[1].Value) } else { $null }
        
                        $autoPostSAMLRequestMatch = ($currentResponse.Content | Select-String -Pattern '<input[^>]*name=["'']SAMLRequest["''][^>]*value=["'']([^"'']*)["'']').Matches | Select-Object -First 1
                        $autoPostSAMLRequest = if ($autoPostSAMLRequestMatch) { [System.Web.HttpUtility]::HtmlDecode($autoPostSAMLRequestMatch.Groups[1].Value) } else { $null }
        
                        $autoPostRelayStateMatch = ($currentResponse.Content | Select-String -Pattern '<input[^>]*name=["'']RelayState["''][^>]*value=["'']([^"'']*)["'']').Matches | Select-Object -First 1
                        $autoPostRelayState = if ($autoPostRelayStateMatch) { [System.Web.HttpUtility]::HtmlDecode($autoPostRelayStateMatch.Groups[1].Value) } else { $null }

                        # Validate that we extracted required elements
                        if (-not $autoPostAction) {
                            throw "[{0}] SAML form action not found in response" -f $functionName
                        }
        
                        "[{0}] Extracted form action (raw): {1}" -f $functionName, $autoPostAction | Write-Verbose
                        "[{0}] Extracted SAMLRequest (raw): {1}..." -f $functionName, ($autoPostSAMLRequest ? $autoPostSAMLRequest.Substring(0, [Math]::Min(100, $autoPostSAMLRequest.Length)) : "None") | Write-Verbose
                        "[{0}] Extracted RelayState (raw): {1}..." -f $functionName, ($autoPostRelayState ? $autoPostRelayState.Substring(0, [Math]::Min(100, $autoPostRelayState.Length)) : "None") | Write-Verbose
                    }
                    catch {
                        "[{0}] HTML parsing error: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                        Write-Error @"
[$functionName] Failed to parse authentication response. 

The Identity Provider may have changed their page structure. 

Error: $($_.Exception.Message)
"@ -ErrorAction Stop
                    }
        
                    # Resolve relative URL to absolute URL
                    $resolvedAction = $autoPostAction
                    if ($autoPostAction -match '^/') {
                        $oktaUri = [uri]$SAMLActionValue
                        $resolvedAction = "{0}://{1}{2}" -f $oktaUri.Scheme, $oktaUri.Host, $autoPostAction
                        "[{0}] Resolved relative URL using SAMLActionValue base ({1}://{2}) to: {3}" -f $functionName, $oktaUri.Scheme, $oktaUri.Host, $resolvedAction | Write-Verbose
                    }
        
                    "[{0}] Detected SAML redirect to: {1}" -f $functionName, $resolvedAction | Write-Verbose
        
                    # Detect IdP type - check CURRENT response first, then resolved URL, then original URL
                    $idpType = $null

                    # Priority 1: Check current response URL 
                    $currentUrl = $currentResponse.BaseResponse.RequestMessage.RequestUri.AbsoluteUri
                    "[{0}] Current response URL: {1}" -f $functionName, $currentUrl | Write-Verbose

                    # Use flexible pattern matching - match on IdP name in URL, not specific domains
                    if ($currentUrl -match 'okta') {
                        $idpType = 'Okta'
                        "[{0}] Detected Okta from current response URL" -f $functionName | Write-Verbose
                    }
                    elseif ($currentUrl -match 'microsoft|azure|entra|login\.windows\.net|sts\.windows\.net') {
                        $idpType = 'EntraID'
                        "[{0}] Detected Microsoft Entra ID from current response URL" -f $functionName | Write-Verbose
                    }
                    elseif ($currentUrl -match 'ping') {
                        $idpType = 'PingIdentity'
                        "[{0}] Detected Ping Identity from current response URL" -f $functionName | Write-Verbose
                    }

                    # Priority 2: Check redirect form action URL
                    if (-not $idpType -and $resolvedAction) {
                        if ($resolvedAction -match 'okta') {
                            $idpType = 'Okta'
                            "[{0}] Detected Okta from redirect action URL" -f $functionName | Write-Verbose
                        }
                        elseif ($resolvedAction -match 'microsoft|azure|entra|login\.windows\.net|sts\.windows\.net') {
                            $idpType = 'EntraID'
                            "[{0}] Detected Microsoft Entra ID from redirect action URL" -f $functionName | Write-Verbose
                        }
                        elseif ($resolvedAction -match 'ping') {
                            $idpType = 'PingIdentity'
                            "[{0}] Detected Ping Identity from redirect action URL" -f $functionName | Write-Verbose
                        }
                    }

                    # Priority 3: Check response content patterns
                    if (-not $idpType) {
                        if ($currentResponse.Content -match 'okta') {
                            $idpType = 'Okta'
                            "[{0}] Detected Okta from content patterns" -f $functionName | Write-Verbose
                        }
                        elseif ($currentResponse.Content -match 'microsoft|azure|entra|msal') {
                            $idpType = 'EntraID'
                            "[{0}] Detected Microsoft Entra ID from content patterns" -f $functionName | Write-Verbose
                        }
                        elseif ($currentResponse.Content -match 'ping') {
                            $idpType = 'PingIdentity'
                            "[{0}] Detected Ping Identity from content patterns" -f $functionName | Write-Verbose
                        }
                    }

                    # Priority 4: Check original SAML action URL from Step 10
                    if (-not $idpType -and $SAMLActionValue) {
                        if ($SAMLActionValue -match 'okta') {
                            $idpType = 'Okta'
                            "[{0}] Detected Okta from original SAML action URL" -f $functionName | Write-Verbose
                        }
                        elseif ($SAMLActionValue -match 'microsoft|azure|entra|login\.windows\.net|sts\.windows\.net') {
                            $idpType = 'EntraID'
                            "[{0}] Detected Microsoft Entra ID from original SAML action URL" -f $functionName | Write-Verbose
                        }
                        elseif ($SAMLActionValue -match 'ping') {
                            $idpType = 'PingIdentity'
                            "[{0}] Detected Ping Identity from original SAML action URL" -f $functionName | Write-Verbose
                        }
                    }

                    # Final check
                    if (-not $idpType) {
                        "[{0}] ERROR: Could not detect IdP type" -f $functionName | Write-Verbose
                        "[{0}] Current URL: {1}" -f $functionName, $currentUrl | Write-Verbose
                        "[{0}] Resolved Action: {1}" -f $functionName, $resolvedAction | Write-Verbose
                        "[{0}] Original SAML Action: {1}" -f $functionName, $SAMLActionValue | Write-Verbose
                        Write-Error @"
[{0}] Unsupported IdP detected.

SUPPORTED IDENTITY PROVIDERS:
- Okta (with Okta Verify push or TOTP)
- Microsoft Entra ID (with Authenticator push)
- Ping Identity (with PingID push or OTP)

For setup prerequisites, see: https://github.com/jullienl/HPE-COM-PowerShell-Library/blob/main/README.md
"@ -f $functionName -ErrorAction Stop
                    }

                    "[{0}] Detected final IdP type: {1}" -f $functionName, $idpType | Write-Verbose
        
                    # Route to appropriate MFA handler based on detected IdP
                    switch ($idpType) {
                        'Okta' {
                            "[{0}] Using Okta Verify MFA (push or TOTP)" -f $functionName | Write-Verbose
                            
                            # Extract Okta domain from current URL, resolved action, or original SAML action
                            # Use flexible pattern - extract any okta-related domain
                            $oktaDomain = $null
                            
                            if ($currentUrl -match 'https?://([^/]+okta[^/]*)') {
                                $oktaDomain = $Matches[1]
                                "[{0}] Extracted Okta domain from current URL: {1}" -f $functionName, $oktaDomain | Write-Verbose
                            }
                            elseif ($resolvedAction -and $resolvedAction -match 'https?://([^/]+okta[^/]*)') {
                                $oktaDomain = ([System.Uri]$resolvedAction).Host
                                "[{0}] Extracted Okta domain from resolved action: {1}" -f $functionName, $oktaDomain | Write-Verbose
                            }
                            elseif ($SAMLActionValue -match 'https?://([^/]+okta[^/]*)') {
                                $oktaDomain = ([System.Uri]$SAMLActionValue).Host
                                "[{0}] Extracted Okta domain from original SAML action: {1}" -f $functionName, $oktaDomain | Write-Verbose
                            }
                            
                            if (-not $oktaDomain) {
                                throw "[{0}] Could not extract Okta domain from authentication flow" -f $functionName
                            }
                            
                            # Create refs for progress tracking
                            $completedStepsRef = [ref]$completedSteps
                            $currentStepRef = [ref]$step
                            
                            $responseStep12 = Invoke-OktaMFAAuthentication `
                                -StateToken $stateToken `
                                -Username $Username `
                                -Session $session `
                                -OktaDomain $oktaDomain `
                                -NoProgress:$NoProgress `
                                -CompletedSteps $completedStepsRef `
                                -TotalSteps $totalSteps `
                                -CurrentStep $currentStepRef
                        }
                        
                        'EntraID' {
                            "[{0}] Using Microsoft Authenticator MFA (push or TOTP)" -f $functionName | Write-Verbose
                            
                            # Extract tenant domain from current URL, resolved action, or original SAML action
                            $tenantDomain = $null
                            
                            if ($currentUrl -match 'https?://(login\.microsoftonline\.com|login\.windows\.net|sts\.windows\.net)') {
                                $tenantDomain = $Matches[1]
                                "[{0}] Extracted Entra ID domain from current URL: {1}" -f $functionName, $tenantDomain | Write-Verbose
                            }
                            elseif ($resolvedAction -and $resolvedAction -match 'https?://(login\.microsoftonline\.com|login\.windows\.net|sts\.windows\.net)') {
                                $tenantDomain = ([System.Uri]$resolvedAction).Host
                                "[{0}] Extracted Entra ID domain from resolved action: {1}" -f $functionName, $tenantDomain | Write-Verbose
                            }
                            elseif ($SAMLActionValue -match 'https?://(login\.microsoftonline\.com|login\.windows\.net|sts\.windows\.net)') {
                                $tenantDomain = ([System.Uri]$SAMLActionValue).Host
                                "[{0}] Extracted Entra ID domain from original SAML action: {1}" -f $functionName, $tenantDomain | Write-Verbose
                            }
                            
                            if (-not $tenantDomain) {
                                # Default to standard Entra ID login endpoint
                                $tenantDomain = "login.microsoftonline.com"
                                "[{0}] Using default Entra ID domain: {1}" -f $functionName, $tenantDomain | Write-Verbose
                            }
                            
                            # For redirect-based flow, we need to follow the redirect first to extract tokens
                            # POST the SAML request to get the login page
                            "[{0}] Following Entra ID redirect to extract authentication context" -f $functionName | Write-Verbose
                            
                            $entraLoginPage = $null
                            if ($autoPostSAMLRequest -and $autoPostRelayState) {
                                try {
                                    $formBody = @{
                                        SAMLRequest = $autoPostSAMLRequest
                                        RelayState  = $autoPostRelayState
                                    }
                                    
                                    $entraLoginPage = Invoke-WebRequest -Uri $resolvedAction -Method POST -Body $formBody `
                                        -WebSession $session -ContentType "application/x-www-form-urlencoded" -ErrorAction Stop
                                    
                                    "[{0}] Entra ID login page retrieved" -f $functionName | Write-Verbose
                                }
                                catch {
                                    "[{0}] Failed to retrieve Entra ID login page: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                                    throw "[{0}] Could not retrieve Entra ID login page: {1}" -f $functionName, $_.Exception.Message
                                }
                            }
                            
                            # Extract Entra ID context from login page
                            $entraContext = @{}
                            
                            if ($entraLoginPage) {
                                # Extract individual values using regex
                                if ($entraLoginPage.Content -match '"sFT"\s*:\s*"([^"]+)"') {
                                    $entraContext.FlowToken = $Matches[1]
                                    "[{0}] Extracted FlowToken from Entra ID page" -f $functionName | Write-Verbose
                                }
                                if ($entraLoginPage.Content -match '"canary"\s*:\s*"([^"]+)"') {
                                    $entraContext.CanaryToken = $Matches[1]
                                    "[{0}] Extracted CanaryToken from Entra ID page" -f $functionName | Write-Verbose
                                }
                                if ($entraLoginPage.Content -match '"sCtx"\s*:\s*"([^"]+)"') {
                                    $entraContext.Ctx = $Matches[1]
                                    "[{0}] Extracted Ctx from Entra ID page" -f $functionName | Write-Verbose
                                }
                                
                                # Fallback to form fields
                                if (-not $entraContext.FlowToken -and $entraLoginPage.Content -match '<input[^>]+name="flowToken"[^>]+value="([^"]+)"') {
                                    $entraContext.FlowToken = $Matches[1]
                                }
                                if (-not $entraContext.CanaryToken -and $entraLoginPage.Content -match '<input[^>]+name="canary"[^>]+value="([^"]+)"') {
                                    $entraContext.CanaryToken = $Matches[1]
                                }
                                if (-not $entraContext.Ctx -and $entraLoginPage.Content -match '<input[^>]+name="ctx"[^>]+value="([^"]+)"') {
                                    $entraContext.Ctx = $Matches[1]
                                }
                            }
                            
                            # Validate we have required tokens
                            if (-not $entraContext.FlowToken -and -not $entraContext.Ctx) {
                                "[{0}] ERROR: Could not extract Entra ID authentication context" -f $functionName | Write-Verbose
                                throw "[{0}] Could not extract Entra ID authentication context from login page" -f $functionName
                            }
                            
                            # Create refs for progress tracking
                            $completedStepsRef = [ref]$completedSteps
                            $currentStepRef = [ref]$step
                            
                            $responseStep12 = Invoke-EntraIDMFAAuthentication `
                                -StateToken $entraContext.Ctx `
                                -FlowToken $entraContext.FlowToken `
                                -CanaryToken $entraContext.CanaryToken `
                                -Username $Username `
                                -Session $session `
                                -TenantDomain $tenantDomain `
                                -NoProgress:$NoProgress `
                                -CompletedSteps $completedStepsRef `
                                -TotalSteps $totalSteps `
                                -CurrentStep $currentStepRef
                        }
                        
                        'PingIdentity' {
                            "[{0}] Using PingID MFA (push or TOTP)" -f $functionName | Write-Verbose
                            
                            # Extract Ping environment ID from URL (e.g., a4ff1a35-682b-469f-9acf-373ee0508d31)
                            $pingEnvironmentId = $null
                            
                            # Try from current URL
                            if ($currentUrl -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') {
                                $pingEnvironmentId = $Matches[1]
                                "[{0}] Extracted Ping environment ID from current URL: {1}" -f $functionName, $pingEnvironmentId | Write-Verbose
                            }
                            
                            # Try from resolved action if not found
                            if (-not $pingEnvironmentId -and $resolvedAction -and $resolvedAction -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') {
                                $pingEnvironmentId = $Matches[1]
                                "[{0}] Extracted Ping environment ID from resolved action: {1}" -f $functionName, $pingEnvironmentId | Write-Verbose
                            }
                            
                            # Try from original SAML action
                            if (-not $pingEnvironmentId -and $SAMLActionValue -and $SAMLActionValue -match '([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})') {
                                $pingEnvironmentId = $Matches[1]
                                "[{0}] Extracted Ping environment ID from SAML action: {1}" -f $functionName, $pingEnvironmentId | Write-Verbose
                            }
                            
                            if (-not $pingEnvironmentId) {
                                throw "[{0}] Could not extract PingOne environment ID from authentication flow" -f $functionName
                            }
                            
                            # Validate we have flowId (from URL, not stateToken)
                            if (-not $flowId) {
                                throw "[{0}] Could not extract flowId from PingOne response. URL: {1}" -f $functionName, $currentUrl
                            }
                            
                            "[{0}] Using flowId: {1}" -f $functionName, $flowId | Write-Verbose
                            
                            # Create refs for progress tracking
                            $completedStepsRef = [ref]$completedSteps
                            $currentStepRef = [ref]$step
                            
                            # Build the SAML redirect URL with flowId
                            $samlRedirectUrl = $currentUrl
                            
                            $responseStep12 = Invoke-PingIDMFAAuthentication `
                                -SAMLRedirectUrl $samlRedirectUrl `
                                -Username $Username `
                                -Session $session `
                                -EnvironmentId $pingEnvironmentId `
                                -NoProgress:$NoProgress `
                                -CompletedSteps $completedStepsRef `
                                -TotalSteps $totalSteps `
                                -CurrentStep $currentStepRef  
                        }
                        
                        default {
                            throw "[{0}] Unsupported IdP type: {1}" -f $functionName, $idpType
                        }
                    }
        
                }
                else {
                    throw "[{0}] Unexpected response format - no SAML form or response found" -f $functionName
                }
    
                "[{0}] IdP authentication flow completed" -f $functionName | Write-Verbose
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                "[{0}] Failed at IdP authentication: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                throw "[{0}] IdP authentication failed: {1}" -f $functionName, $_
            }

            $completedSteps++

            #EndRegion

            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            #Region [STEP 13] POST SAML Response Back to HPE
            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName | Write-Verbose
            "[{0}] [STEP 13] POST SAML Response Back to HPE" -f $functionName | Write-Verbose
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName | Write-Verbose

            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Complete SAML authentication" -Id 0
            $step++

            try {
                # Extract SAML Response with error handling
                try {
                    $samlResponseMatch = ($responseStep12.Content | Select-String -Pattern '<input[^>]*name=["'']SAMLResponse["''][^>]*value=["'']([^"'']*)["'']').Matches | Select-Object -First 1
                    $samlResponse = if ($samlResponseMatch) { [System.Web.HttpUtility]::HtmlDecode($samlResponseMatch.Groups[1].Value) } else { $null }
        
                    $samlRelayStateMatch = ($responseStep12.Content | Select-String -Pattern '<input[^>]*name=["'']RelayState["''][^>]*value=["'']([^"'']*)["'']').Matches | Select-Object -First 1
                    $samlRelayState = if ($samlRelayStateMatch) { [System.Web.HttpUtility]::HtmlDecode($samlRelayStateMatch.Groups[1].Value) } else { $null }
        
                    $samlActionMatch = ($responseStep12.Content | Select-String -Pattern '<form[^>]*action=["'']([^"'']*)["'']').Matches | Select-Object -First 1
                    $samlAction = if ($samlActionMatch) { [System.Web.HttpUtility]::HtmlDecode($samlActionMatch.Groups[1].Value) } else { $null }
        
                    if (-not $samlResponse) {
                        throw "[{0}] SAMLResponse not found in IdP response" -f $functionName
                    }
        
                    if (-not $samlAction) {
                        throw "[{0}] SAML form action URL not found" -f $functionName
                    }
                }
                catch {
                    "[{0}] SAML Response parsing error: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                    Write-Error @"
[$functionName] Failed to parse SAML authentication response from Identity Provider. 

The IdP response format may have changed. 

Error: $($_.Exception.Message)
"@ -ErrorAction Stop
                }
    
                "[{0}] SAML Response received (length: {1})" -f $functionName, $samlResponse.Length | Write-Verbose
                "[{0}] Posting back to HPE: {1}" -f $functionName, $samlAction | Write-Verbose
    
                # POST SAML Response back to HPE SSO
                $samlBody = @{
                    SAMLResponse = $samlResponse
                }
                if ($samlRelayState) {
                    $samlBody['RelayState'] = $samlRelayState
                }
    
                $responseStep13 = Invoke-WebRequest -Uri $samlAction -Method POST -Body $samlBody -WebSession $session -ContentType "application/x-www-form-urlencoded" -MaximumRedirection 5
    
                "[{0}] SAML Response posted successfully - Status: {1}" -f $functionName, $responseStep13.StatusCode | Write-Verbose
                "[{0}] Response content starts with: {1}..." -f $functionName, ($responseStep13.Content.Substring(0, [Math]::Min(100, $responseStep13.Content.Length))) | Write-Verbose
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                "[{0}] Failed to POST SAML Response: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                throw "[{0}] Failed to POST SAML Response to HPE: {1}" -f $functionName, $_
            }

            "[{0}] Checking for OAuth redirect in SAML response..." -f $functionName | Write-Verbose

            # Check for JavaScript window.location redirect (most common pattern)
            $jsRedirectUrl = $null

            if ($responseStep13.Content -match 'window\.location(?:\s*=\s*|\s*\.\s*href\s*=\s*)[''"]([^''"]+)[''"]') {
                $jsRedirectUrl = $matches[1]
                 
                # Decode JavaScript escape sequences (\x3A -> :, \x2F -> /, etc.)   
                $jsRedirectUrl = $jsRedirectUrl -replace '\\x([0-9A-Fa-f]{2})', { [char][convert]::ToInt32($_.Groups[1].Value, 16) }
    
                "[{0}] Found JavaScript redirect: {1}" -f $functionName, ($jsRedirectUrl -replace 'code=[^&]+', 'code=[REDACTED]') | Write-Verbose
            }

            # Log full HTML for debugging (first 2000 chars)
            $htmlPreview = $responseStep13.Content.Substring(0, [Math]::Min(2000, $responseStep13.Content.Length))
            "[{0}] Full HTML preview (first 2000 chars):`n{1}" -f $functionName, $htmlPreview | Write-Verbose

            # Log the response URL
            "[{0}] Response URL: {1}" -f $functionName, $responseStep13.BaseResponse.ResponseUri.AbsoluteUri | Write-Verbose
            $completedSteps++

            #EndRegion

            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            #Region [STEP 14] Complete Token Redirect Flow
            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName | Write-Verbose
            "[{0}] [STEP 14] Complete Token Redirect Flow" -f $functionName | Write-Verbose
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName | Write-Verbose

            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Completing token redirect" -Id 0
            $step++

            try {
                # Extract the full redirect URL first, then parse stateToken from it
                $stateToken = $null
                $tokenRedirectUrl = $null
                
                # Look for the JavaScript redirect URL in the response
                if ($responseStep13.Content -match 'https[^"''<>\s]*login[^"''<>\s]*token[^"''<>\s]*redirect[^"''<>\s]*stateToken[^"''<>\s]*') {
                    $tokenRedirectUrl = $matches[0]
                    # Decode HTML entities
                    $tokenRedirectUrl = $tokenRedirectUrl -replace '\\x3A', ':' -replace '\\x2F', '/' -replace '\\x3D', '=' -replace '\\x26', '&' -replace '\\x3F', '?' -replace '\\x2D', '-'
                    
                    "[{0}] Found token redirect URL: {1}" -f $functionName, ($tokenRedirectUrl -replace 'stateToken=[^&]+', 'stateToken=[REDACTED]') | Write-Verbose
                    
                    # Extract stateToken from the URL
                    if ($tokenRedirectUrl -match '[?&]stateToken=([^&]+)') {
                        $stateToken = $matches[1]
                        "[{0}] Extracted stateToken: {1}..." -f $functionName, $stateToken.Substring(0, [Math]::Min(15, $stateToken.Length)) | Write-Verbose
                    }
                }
                
                if (-not $tokenRedirectUrl -or -not $stateToken) {
                    throw "[{0}] Token redirect URL or stateToken not found in Step 13 response" -f $functionName
                }
                
                # POST to /idp/idx/introspect with stateToken
                "[{0}] Introspecting stateToken at auth.hpe.com..." -f $functionName | Write-Verbose
                
                $introspectUrl = "https://auth.hpe.com/idp/idx/introspect"
                $introspectBody = @{
                    stateToken = $stateToken
                } | ConvertTo-Json -Compress
                
                $introspectResponse = Invoke-WebRequest -Uri $introspectUrl -Method POST -Body $introspectBody -ContentType "application/ion+json; okta-version=1.0.0" -WebSession $session -ErrorAction Stop
                
                "[{0}] Introspect response status: {1}" -f $functionName, $introspectResponse.StatusCode | Write-Verbose
                
                # Properly decode the content - check if it's bytes or string
                $introspectContent = $null
                if ($introspectResponse.Content -is [byte[]]) {
                    $introspectContent = [System.Text.Encoding]::UTF8.GetString($introspectResponse.Content)
                }
                else {
                    $introspectContent = $introspectResponse.Content
                }
                
                "[{0}] Introspect response content (first 500 chars): {1}" -f $functionName, $introspectContent.Substring(0, [Math]::Min(500, $introspectContent.Length)) | Write-Verbose
                
                $introspectData = $introspectContent | ConvertFrom-Json
                
                # Check what properties the introspect response has
                $properties = ($introspectData.PSObject.Properties | ForEach-Object { $_.Name }) -join ', '
                "[{0}] Introspect response properties: {1}" -f $functionName, $properties | Write-Verbose
                
                # Look for success redirect
                $successUrl = $null
           
                # Look for success redirect 
                if ($introspectData.successWithInteractionCode -and $introspectData.successWithInteractionCode.href) {
                    $successUrl = $introspectData.successWithInteractionCode.href
                    "[{0}] Found successWithInteractionCode.href" -f $functionName | Write-Verbose
                }
                elseif ($introspectData.success -and $introspectData.success.href) {
                    $successUrl = $introspectData.success.href
                    "[{0}] Found success.href" -f $functionName | Write-Verbose
                }
                
                if (-not $successUrl) {
                    "[{0}] Full introspect response JSON:" -f $functionName | Write-Verbose
                    ($introspectData | ConvertTo-Json -Depth 10).Split("`n") | ForEach-Object { "[{0}] {1}" -f $functionName, $_ | Write-Verbose }
                    
                    # Build detailed error message
                    Write-Error @"
Authentication failed: External Identity Provider authentication did not complete successfully.

This error can occur for multiple reasons:

1. MFA Challenge Not Completed
   - Push notification was denied, ignored, or timed out
   - TOTP code was not entered or was incorrect
   - Authentication request expired before completion

2. User Not Assigned to HPE GreenLake Application
   - Contact your Identity Provider administrator to verify you have access to the HPE GreenLake application
   - Ensure you have the required application role assignments

3. Missing Required Licenses (Microsoft Entra ID)
   - User account lacks Azure AD Premium P1/P2 license
   - Passwordless authentication requires proper licensing
   - Contact your Entra ID administrator to assign required licenses
   - Verify license includes Microsoft Authenticator and MFA features

4. Identity Provider Configuration Issues
   - SAML assertion generation failed
   - Application integration settings are incorrect
   - Required claims or attributes are missing

5. Session or State Token Issues
   - Authentication session expired
   - State token became invalid during the authentication flow

Please check the verbose logs for the full introspect response details.
For complete SSO setup prerequisites, see: $script:HelpUrl
"@ -ErrorAction Stop
                }
                
                "[{0}] Following success URL: {1}" -f $functionName, ($successUrl -replace 'stateToken=[^&]+', 'stateToken=[REDACTED]') | Write-Verbose
                
                # Follow the success URL - use manual redirect following to handle all cases
                $currentUrl = $successUrl
                $redirectCount = 0
                $maxRedirects = 15
                $responseStep14 = $null
                
                while ($redirectCount -lt $maxRedirects) {
                    try {
                        $responseStep14 = Invoke-WebRequest -Uri $currentUrl -Method GET -WebSession $session -MaximumRedirection 0 -ErrorAction Stop
                        
                        # Got a 200 response - check for OAuth code or JavaScript redirects
                        $finalUrl = if ($responseStep14.BaseResponse.ResponseUri) { $responseStep14.BaseResponse.ResponseUri.AbsoluteUri } else { $currentUrl }
                        "[{0}] Request {1}: 200 OK at {2}" -f $functionName, $redirectCount, ($finalUrl -replace 'code=[^&]+', 'code=[REDACTED]') | Write-Verbose
                        
                        # Check if we have the OAuth code
                        if ($finalUrl -match 'common\.cloud\.hpe\.com.*[?&]code=') {
                            "[{0}] Found common.cloud.hpe.com callback in final URL!" -f $functionName | Write-Verbose
                            break
                        }
                        
                        # Look for JavaScript or meta redirects in the HTML
                        $nextUrl = $null
                        
                        # Check for OAuth callback in response content
                        if ($responseStep14.Content -match '(https://[^"''<>\s]*common\.cloud\.hpe\.com[^"''<>\s]*[?&]code=[A-Za-z0-9_-]{20,}[^"''<>\s]*)') {
                            $nextUrl = $matches[1]
                            $nextUrl = $nextUrl -replace '\\x3A', ':' -replace '\\x2F', '/' -replace '\\x3D', '=' -replace '\\x26', '&' -replace '\\x3F', '?' -replace '\\x2D', '-' -replace '&amp;', '&'
                            "[{0}] Found common.cloud.hpe.com callback in HTML content!" -f $functionName | Write-Verbose
                        }
                        # Meta refresh
                        elseif ($responseStep14.Content -match '<meta[^>]+http-equiv\s*=\s*["\x27]refresh["\x27][^>]+url\s*=\s*([^"\x27>]+)') {
                            $nextUrl = $matches[1]
                            $nextUrl = $nextUrl -replace '\\x3A', ':' -replace '\\x2F', '/' -replace '\\x3D', '=' -replace '\\x26', '&' -replace '\\x3F', '?' -replace '\\x2D', '-'
                            "[{0}] Found meta refresh to: {1}" -f $functionName, ($nextUrl -replace 'code=[^&]+', 'code=[REDACTED]') | Write-Verbose
                        }
                        # JavaScript window.location
                        elseif ($responseStep14.Content -match 'window\.location(?:\.href)?\s*=\s*["\x27]([^"\x27]+)["\x27]') {
                            $nextUrl = $matches[1]
                            $nextUrl = $nextUrl -replace '\\x3A', ':' -replace '\\x2F', '/' -replace '\\x3D', '=' -replace '\\x26', '&' -replace '\\x3F', '?' -replace '\\x2D', '-'
                            "[{0}] Found JavaScript redirect to: {1}" -f $functionName, ($nextUrl -replace 'code=[^&]+', 'code=[REDACTED]') | Write-Verbose
                        }
                        
                        if ($nextUrl) {
                            # Make absolute if relative
                            if ($nextUrl -notmatch '^https?://') {
                                $uri = [System.Uri]::new($currentUrl)
                                $nextUrl = [System.Uri]::new($uri, $nextUrl).AbsoluteUri
                            }
                            $currentUrl = $nextUrl
                            $redirectCount++
                            continue
                        }
                        
                        # No more redirects
                        "[{0}] No more redirects found - stopping" -f $functionName | Write-Verbose
                        "[{0}] Response preview (first 1000 chars): {1}" -f $functionName, $responseStep14.Content.Substring(0, [Math]::Min(1000, $responseStep14.Content.Length)) | Write-Verbose
                        break
                    }
                    catch {
                        # Handle HTTP redirects (3xx)
                        if ($_.Exception.Response) {
                            $statusCode = [int]$_.Exception.Response.StatusCode
                            if ($statusCode -ge 300 -and $statusCode -lt 400) {
                                $location = $_.Exception.Response.Headers.Location
                                if ($location) {
                                    if ($location.IsAbsoluteUri) {
                                        $location = $location.AbsoluteUri
                                    }
                                    else {
                                        $uri = [System.Uri]::new($currentUrl)
                                        $location = [System.Uri]::new($uri, $location.OriginalString).AbsoluteUri
                                    }
                                    
                                    "[{0}] Request {1}: {2} redirect to {3}" -f $functionName, $redirectCount, $statusCode, ($location -replace 'code=[^&]+', 'code=[REDACTED]') | Write-Verbose
                                    $currentUrl = $location
                                    $redirectCount++
                                    continue
                                }
                            }
                        }
                        throw
                    }
                }
                
                if (-not $responseStep14) {
                    throw "[{0}] Failed to complete redirect chain" -f $functionName
                }
                
                # Save the final callback URL for Step 15
                $finalCallbackUrl = $currentUrl
                "[{0}] Token redirect completed after {1} request(s)" -f $functionName, $redirectCount | Write-Verbose
                "[{0}] Final callback URL: {1}" -f $functionName, ($finalCallbackUrl -replace 'code=[^&]+', 'code=[REDACTED]') | Write-Verbose

                if ($finalCallbackUrl -notmatch 'common\.cloud\.hpe\.com.*[?&]code=' -and $responseStep14.Content -notmatch 'common\.cloud\.hpe\.com[^"''<>\s]*[?&]code=') {
                    "[{0}] Warning: No common.cloud.hpe.com callback found" -f $functionName | Write-Warning
                }
                
                "[{0}] Token redirect flow completed" -f $functionName | Write-Verbose
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                "[{0}] Failed to complete token redirect: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                throw "[{0}] Failed to complete token redirect flow: {1}" -f $functionName, $_
            }

            $completedSteps++

            #EndRegion

            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            #Region [STEP 15] Extract OAuth Authorization Code from Response
            # --------------------------------------------------------------------------------------------------------------------------------------------------------------
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName | Write-Verbose
            "[{0}] [STEP 15] Extract OAuth Authorization Code from Response" -f $functionName | Write-Verbose
            "[{0}] ------------------------------------------------------------------------------------------------------------------" -f $functionName | Write-Verbose

            Update-ProgressBar -CompletedSteps $completedSteps -TotalSteps $totalSteps -CurrentActivity "Step $step/$totalSteps - Extracting OAuth code" -Id 0
            $step++

            try {
                "[{0}] Extracting OAuth code from final URL: {1}" -f $functionName, ($finalCallbackUrl -replace 'code=[^&]+', 'code=[REDACTED]') | Write-Verbose
                
                if ($finalCallbackUrl -match '[?&]code=([^&]+)') {
                    $authCode = $matches[1]
                    "[{0}] OAuth code extracted from final callback URL" -f $functionName | Write-Verbose
                    "[{0}] Code preview: {1}..." -f $functionName, $authCode.Substring(0, [Math]::Min(20, $authCode.Length)) | Write-Verbose
                }
                else {
                    throw "[{0}] OAuth code not found in final callback URL: {1}" -f $functionName, $finalCallbackUrl
                }
                
                # Set token endpoint and redirect_uri for Aquila
                $tokenUrl = "https://aquila-org-api.common.cloud.hpe.com/authorization/v2/oauth2/default/token"
                $RedirectUri = "https://common.cloud.hpe.com/authentication/callback"
                
                "[{0}] Using Aquila API token endpoint" -f $functionName | Write-Verbose
                "[{0}] Token exchange redirect_uri: {1}" -f $functionName, $RedirectUri | Write-Verbose
                "[{0}] OAuth authorization code successfully extracted" -f $functionName | Write-Verbose
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                "[{0}] Failed to extract OAuth code: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                throw "[{0}] Failed to extract OAuth authorization code: {1}" -f $functionName, $_
            }

            $completedSteps++

            #EndRegion           

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
                throw "[{0}] Authentication failed: Could not retrieve oauthIssuer from settings.json." -f $functionName
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
                throw "[{0}] Authentication failed: Could not extract stateToken from /as/authorization.oauth2 response." -f $functionName
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
                        "[{0}] Session expired at introspect. Retrying flow from STEP 4..." -f $functionName | Write-Verbose
                        $retry = $true
                    }
                    else {
                        break
                    }
                }
                catch {
                    "[{0}] Error during introspect: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                    if ($_.Exception.Response -and ($_.Exception.Response.Content | ConvertFrom-Json).messages.value[0].message -eq "The session has expired.") {
                        "[{0}] Session expired at introspect (exception). Retrying flow from STEP 4..." -f $functionName | Write-Verbose
                        $retry = $true
                    }
                    else {
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        throw "[{0}] Authentication failed: Error during introspect: {1}" -f $functionName, $_
                    }
                }
                if ($retry -and $i -eq 0) {
                    Start-Sleep -Seconds 1
                    # Re-run STEP 4: GET /as/authorization.oauth2 to get new stateToken
                    "[{0}] Retrying STEP 4: GET /as/authorization.oauth2 for new stateToken" -f $functionName | Write-Verbose
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
                            throw "[{0}] Authentication failed: Could not extract stateToken from /as/authorization.oauth2 response (retry)." -f $functionName
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
                        throw "[{0}] Authentication failed: Failed to obtain new stateToken in retry: {1}" -f $functionName, $_
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
                throw "[{0}] Authentication failed: Could not extract stateHandle from introspect response." -f $functionName
            }
            # Validate stateHandle format (allow ~ in addition to alphanumeric, ., _, and -)
            if ($stateHandle -notmatch "^[a-zA-Z0-9._~-]+$") {
                "[{0}] Invalid stateHandle format: {1}" -f $functionName, $stateHandle | Write-Verbose
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                throw "[{0}] Authentication failed: Invalid stateHandle format." -f $functionName
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
                    throw "[{0}] Authentication failed: Unexpected error in response messages: {1}" -f $functionName, ($identifyResp.messages | ConvertTo-Json -Depth 20)
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
                                    throw "[{0}] Authentication failed: Incorrect password. Please verify your credentials and try again." -f $functionName
                                }
                                "errors.E0000015" {
                                    "[{0}] Detected insufficient permissions error (errors.E0000015)" -f $functionName | Write-Verbose
                                    if (-not $NoProgress) {
                                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                    }                                        
                                    throw "[{0}] Authentication failed: Insufficient permissions. Please ensure your account has the necessary access rights." -f $functionName
                                }
                                "errors.E0000011" {
                                    "[{0}] Detected invalid token error (errors.E0000011)" -f $functionName | Write-Verbose
                                    if (-not $NoProgress) {
                                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                    }
                                    throw "[{0}] Authentication failed: Invalid token provided. Please try again or contact your administrator." -f $functionName
                                }
                                "errors.E0000064" {
                                    "[{0}] Detected password expired error (errors.E0000064)" -f $functionName | Write-Verbose
                                    if (-not $NoProgress) {
                                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                    }                                        
                                    throw "[{0}] Authentication failed: Your password has expired. Please reset your password and try again." -f $functionName
                                }
                                "errors.E0000207" {
                                    "[{0}] Detected incorrect username or password error (errors.E0000207)" -f $functionName | Write-Verbose
                                    if (-not $NoProgress) {
                                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                    }                                        
                                    throw "[{0}] Authentication failed: Incorrect username or password. Please verify your credentials and try again." -f $functionName
                                }
                                default {
                                    "[{0}] Detected other error: {1} (key={2})" -f $functionName, $message.message, $message.i18n.key | Write-Verbose
                                    if (-not $NoProgress) {
                                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                    }
                                    throw "[{0}] Authentication failed: {1} (key={2})" -f $functionName, $message.message, $message.i18n.key
                                }
                            }
                        }
                    }
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }                        
                    throw "[{0}] Authentication failed: {1} {2} (no error details)" -f $functionName, $StatusCode, $StatusError
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
                                    throw "[{0}] Authentication failed: Invalid session. Please try logging in again." -f $functionName
                                }
                                default {
                                    "[{0}] Detected other error: {1} (key={2})" -f $functionName, $message.message, $message.i18n.key | Write-Verbose
                                    if (-not $NoProgress) {
                                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                    }
                                    throw "[{0}] Authentication failed: {1} (key={2})" -f $functionName, $message.message, $message.i18n.key
                                }
                            }
                        }
                    }
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "[{0}] Authentication failed: {1} {2} (no error details)" -f $functionName, $StatusCode, $StatusError
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
                                    throw "[{0}] Authentication failed: Resource not found. Please contact your administrator." -f $functionName
                                }
                                default {
                                    "[{0}] Detected other error: {1} (key={2})" -f $functionName, $message.message, $message.i18n.key | Write-Verbose
                                    if (-not $NoProgress) {
                                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                    }
                                    throw "[{0}] Authentication failed: {1} (key={2})" -f $functionName, $message.message, $message.i18n.key
                                }
                            }
                        }
                    }
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    throw "[{0}] Authentication failed: {1} {2} (no error details)" -f $functionName, $StatusCode, $StatusError
                }

                # Handle other unexpected errors
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                throw "[{0}] Authentication failed: Unexpected error: {1} {2} - {3}" -f $functionName, $StatusCode, $StatusError, $_.Exception.Message
            }


            if ($identifyResp.messages -and $identifyResp.messages.value -and $identifyResp.messages.value.Count -gt 0) {
                "[{0}] Authentication failed: Unexpected error in response messages: {1}" -f $functionName, ($identifyResp.messages | ConvertTo-Json -Depth 20) | Write-Verbose
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                throw "[{0}] Authentication failed: Unexpected error in response messages: {1}" -f $functionName, ($identifyResp.messages | ConvertTo-Json -Depth 20)
            }          
            
            if (-not $identifyResp.stateHandle) {
                "[{0}] Authentication failed: Could not extract stateHandle from identify response." -f $functionName | Write-Verbose
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                throw "[{0}] Authentication failed: Could not extract stateHandle from identify response." -f $functionName
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
                throw "[{0}] Authentication failed: The username '{1}' was not recognized by HPE GreenLake. Please check the username and try again." -f $functionName, $Username
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
                throw "[{0}] Authentication failed: Could not extract OAuth2 Issuer Id from identify response." -f $functionName
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
                throw "[{0}] Authentication failed: Could not extract HPE GreenLake App Id from identify response." -f $functionName
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
                    throw "[{0}] Authentication failed: {1}" -f $functionName, $errMsg
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
                    throw "[{0}] Authentication failed: {1}" -f $functionName, $errMsg
                }
            }
            else {
                $errMsg = "[{0}] No authenticators found in identify response." -f $functionName
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }                    
                "[{0}] {1}" -f $functionName, $errMsg | Write-Verbose
                throw "[{0}] Authentication failed: {1}" -f $functionName, $errMsg
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
                    throw "[{0}] Authentication failed: Error during redirect to external IDP: {1}" -f $functionName, $_
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
                        throw "[{0}] Authentication failed: Could not decode SAMLRequest." -f $functionName
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
                    throw "[{0}] Authentication failed: Could not complete SAML authentication request. {1}" -f $functionName, $_.Exception.Message
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
                    throw "[{0}] Authentication failed: Could not extract stateToken from the SAML response." -f $functionName

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
                        throw "[{0}] Authentication failed: Could not parse oktaData from the SAML response. {1}" -f $functionName, $_.Exception.Message
                    }
                }
                else {
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    "[{0}] No oktaData found in the response." -f $functionName | Write-Verbose
                    throw "[{0}] Authentication failed: Could not find oktaData in the SAML response." -f $functionName
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
                    throw "[{0}] Authentication failed: Could not validate the authentication state. {1}" -f $functionName, $_.Exception.Message
                }               
                        
                $RemediationValues = $responseStep53.remediation.value | Redact-StateHandle
                "[{0}] Remediation values: `n{1}" -f $functionName, ($RemediationValues | ConvertTo-Json -Depth 10) | Write-Verbose

                # Capturing challengeHref, authenticatorId, methodType, and stateHandle from $responseStep53
                $stateHandle = $responseStep53.stateHandle
                "[{0}] Extracted stateHandle: {1}...{2}" -f $functionName, $stateHandle.Substring(0, 1), $stateHandle.Substring($stateHandle.Length - 1, 1) | Write-Verbose
            
                # Check for device-challenge-poll (Okta FastPass/device-bound authentication)
                $skipTraditionalOktaVerify = $false
                $deviceChallengePoll = $responseStep53.remediation.value | Where-Object { $_.name -eq 'device-challenge-poll' }
                
                if ($deviceChallengePoll) {
                    "[{0}] Detected device-challenge-poll remediation (Okta FastPass/device-bound authentication)" -f $functionName | Write-Verbose
                    "[{0}] Attempting to cancel device-challenge-poll to fall back to traditional authentication..." -f $functionName | Write-Verbose
                    
                    # Extract the poll cancel URL
                    $pollCancelUrl = $deviceChallengePoll.href -replace '/poll$', '/poll/cancel'
                    "[{0}] Poll cancel URL: {1}" -f $functionName, $pollCancelUrl | Write-Verbose
                    
                    try {
                        # Attempt to cancel the device-challenge-poll
                        $cancelPayload = @{
                            reason      = "OV_UNREACHABLE_BY_LOOPBACK"
                            statusCode  = $null
                            stateHandle = $stateHandle
                        } | ConvertTo-Json -Depth 10
                        
                        $cancelHeaders = @{
                            "Content-Type" = "application/json"
                        }
                        
                        "[{0}] Sending cancel request to: {1}" -f $functionName, $pollCancelUrl | Write-Verbose
                        $cancelResponse = Invoke-RestMethod -Uri $pollCancelUrl -Method POST -Headers $cancelHeaders -Body $cancelPayload -WebSession $Session -ErrorAction Stop
                        
                        "[{0}] Device-challenge-poll cancelled successfully" -f $functionName | Write-Verbose
                        
                        # Check if we got select-authenticator-authenticate after cancel
                        $newRemediation = $cancelResponse.remediation.value | Where-Object { $_.name -eq 'select-authenticator-authenticate' }
                        if ($newRemediation) {
                            "[{0}] New remediation type after cancel: select-authenticator-authenticate" -f $functionName | Write-Verbose
                            # Update response to use the cancel response which should have select-authenticator-authenticate
                            $responseStep53 = $cancelResponse
                            $stateHandle = $cancelResponse.stateHandle
                            "[{0}] Successfully fell back to traditional authentication flow (select-authenticator-authenticate)" -f $functionName | Write-Verbose
                        }
                        else {
                            "[{0}] Cancel succeeded but did not return select-authenticator-authenticate" -f $functionName | Write-Verbose
                            "[{0}] New remediation type: {1}" -f $functionName, ($cancelResponse.remediation.value[0].name) | Write-Verbose
                        }
                    }
                    catch {
                        "[{0}] Failed to cancel device-challenge-poll: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
                        "[{0}] Falling back to device-challenge-poll polling (Mac compatibility mode)" -f $functionName | Write-Verbose
                        
                        # If cancel fails, proceed with device-challenge-poll polling (Mac/desktop app scenario)
                        $pollUrl = $deviceChallengePoll.href
                        $pollInterval = if ($deviceChallengePoll.refresh) { $deviceChallengePoll.refresh / 1000 } else { 5 }
                        $maxAttempts = 60  # 5 minutes timeout
                        
                        "[{0}] Starting device-challenge-poll polling (interval: {1}s, max attempts: {2})" -f $functionName, $pollInterval, $maxAttempts | Write-Verbose
                        
                        $pollPayload = @{
                            stateHandle = $stateHandle
                        } | ConvertTo-Json -Depth 10
                        
                        $pollHeaders = @{
                            "Content-Type" = "application/json"
                        }
                        
                        $attempt = 0
                        $authSuccess = $false
                        
                        while ($attempt -lt $maxAttempts -and -not $authSuccess) {
                            $attempt++
                            Start-Sleep -Seconds $pollInterval
                            
                            try {
                                $pollResponse = Invoke-RestMethod -Uri $pollUrl -Method POST -Headers $pollHeaders -Body $pollPayload -WebSession $Session -ErrorAction Stop
                                
                                # Check if authentication succeeded (successWithInteractionCode)
                                if ($pollResponse.successWithInteractionCode) {
                                    "[{0}] Device authentication succeeded via polling!" -f $functionName | Write-Verbose
                                    $authSuccess = $true
                                    
                                    # Extract SAML response from successWithInteractionCode.href
                                    $interactionCodeUrl = $pollResponse.successWithInteractionCode.href
                                    "[{0}] Interaction code URL: {1}" -f $functionName, $interactionCodeUrl | Write-Verbose
                                    
                                    # Follow the interaction code redirect to get SAML
                                    $samlResponse = Invoke-WebRequest -Uri $interactionCodeUrl -Method GET -WebSession $Session -MaximumRedirection 0 -ErrorAction SilentlyContinue
                                    
                                    # Extract the final redirect location which should contain the authorization code
                                    if ($samlResponse.Headers.Location) {
                                        $finalRedirect = $samlResponse.Headers.Location
                                        "[{0}] Final redirect: {1}" -f $functionName, $finalRedirect | Write-Verbose
                                        
                                        # Parse authorization code from redirect
                                        if ($finalRedirect -match '[?&]code=([^&]+)') {
                                            $authCode = $matches[1]
                                            "[{0}] Authorization code obtained from device authentication" -f $functionName | Write-Verbose
                                            $skipTraditionalOktaVerify = $true
                                            break
                                        }
                                    }
                                }
                                
                                # Update stateHandle for next poll
                                if ($pollResponse.stateHandle) {
                                    $stateHandle = $pollResponse.stateHandle
                                }
                            }
                            catch {
                                "[{0}] Poll attempt {1}/{2} failed: {3}" -f $functionName, $attempt, $maxAttempts, $_.Exception.Message | Write-Verbose
                            }
                        }
                        
                        if (-not $authSuccess) {
                            "[{0}] Device-challenge-poll polling timed out after {1} attempts" -f $functionName, $maxAttempts | Write-Verbose
                            if (-not $NoProgress) {
                                Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                            }
                            throw "[{0}] Authentication failed: Device authentication timed out. Please approve the authentication on your Okta Verify desktop app." -f $functionName
                        }
                    }
                }

                # Only proceed with traditional Okta Verify if we didn't use device authentication
                if (-not $skipTraditionalOktaVerify) {
                    $challengeHref = $responseStep53.remediation.value | Where-Object { $_.name -eq 'select-authenticator-authenticate' } | Select-Object -ExpandProperty href
                    "[{0}] Extracted challengeHref: '{1}'" -f $functionName, $challengeHref | Write-Verbose

                    $OktaVerify = ($responseStep53.remediation.value | Where-Object { $_.name -eq 'select-authenticator-authenticate' }).value | Where-Object { $_.name -eq 'authenticator' } | Select-Object -ExpandProperty options | Where-Object { $_.label -eq 'Okta Verify' }
                                    
                    if (-not $OktaVerify) {
                        "[{0}] ERROR: Okta Verify authenticator not found" -f $functionName | Write-Verbose
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        throw "[{0}] Authentication failed: Okta Verify authenticator not found in response" -f $functionName
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
                        throw "[{0}] Authentication failed: AuthenticatorId not found" -f $functionName
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
                        throw "[{0}] Authentication failed: No methodType options found for Okta Verify" -f $functionName
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
                        throw "[{0}] Authentication failed: Neither push nor totp available for Okta Verify" -f $functionName
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
                        throw "[{0}] Authentication failed: Could not send Okta Verify push notification. {1}" -f $functionName, $_.Exception.Message
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
                        throw "[{0}] Authentication failed: Could not extract stateHandle from introspect response." -f $functionName
                    }

                    # Validate stateHandle format (allow ~ in addition to alphanumeric, ., _, and -)
                    if ($stateHandle -notmatch "^[a-zA-Z0-9._~-]+$") {
                        Write-Verbose "[${functionName}] Invalid stateHandle format: $stateHandle"
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        throw "[{0}] Authentication failed: Invalid stateHandle format." -f $functionName
                    }

                    if ($methodType -eq "push") {
                        $pollHref = $responseStep54.remediation.value | Where-Object { $_.name -eq 'challenge-poll' } | Select-Object -ExpandProperty href
                        if (-not $pollHref) {
                            "[{0}] ERROR: No pollHref found for push authentication" -f $functionName | Write-Verbose
                            if (-not $NoProgress) {
                                Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                            }
                            throw "[{0}] Authentication failed: No pollHref found in response for push authentication" -f $functionName
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
                            throw "[{0}] Authentication failed: No poll URL provided for push authentication." -f $functionName
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
                                throw "[{0}] Authentication failed: Unable to poll Okta Verify push status. {1}" -f $functionName, $_.Exception.Message
                            }

                            if ([datetime]::Now -ge $timeout) {
                                if (-not $NoProgress) {
                                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                }
                                throw "[{0}] Authentication failed: Timeout error! Okta Verify push verification did not succeed within 2 minutes." -f $functionName
                            }

                            Start-Sleep -Seconds 3

                        } until ( $responseStep55.success.name -eq "success-redirect" -or ($responseStep55.messages -and $responseStep55.messages.value -and $responseStep55.messages.value[0] -and $responseStep55.messages.value[0].class -eq "ERROR") )

                        if ($responseStep55.success.name -eq "success-redirect") {
                            "[{0}] Verification via Okta Verify push notification completed successfully." -f $functionName | Write-Verbose
                        
                            # Update stateHandle from the successful response
                            if ($responseStep55.stateHandle) {
                                $stateHandle = $responseStep55.stateHandle
                                "[{0}] Updated stateHandle from successful push response" -f $functionName | Write-Verbose
                            }
                        }
                        elseif ($responseStep55.messages.value[0].class -eq "ERROR") {
                            "[{0}] Verification via Okta Verify push notification failed." -f $functionName | Write-Verbose
                            "[{0}] Error message: {1}" -f $functionName, $responseStep55.messages.value[0].message | Write-Verbose
                            if (-not $NoProgress) {
                                Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                            }
                            Write-Error @"
Authentication failed: Unable to verify the status of the Okta Verify push notification.

The notification was either rejected or an incorrect verification number was selected.
"@ -ErrorAction Stop
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
                            throw "[{0}] Authentication failed: No verify URL available for TOTP authentication. Check Step 4.4 and 4.3 responses." -f $functionName
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
                            throw "[{0}] Authentication failed: Invalid TOTP code. Must be a 6-digit number." -f $functionName
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
                            throw "[{0}] Authentication failed: Unable to verify the Okta Verify TOTP code. {1}" -f $functionName, $_.Exception.Message
                        }

                        if ($responseStep55.success.name -eq "success-redirect") {
                            "[{0}] Verification via Okta Verify TOTP completed successfully." -f $functionName | Write-Verbose
                        
                            # Update stateHandle from the successful response
                            if ($responseStep55.stateHandle) {
                                $stateHandle = $responseStep55.stateHandle
                                "[{0}] Updated stateHandle from successful TOTP response" -f $functionName | Write-Verbose
                            }
                        }
                        elseif ($responseStep55.messages -and $responseStep55.messages.value -and $responseStep55.messages.value[0].class -eq "ERROR") {
                            "[{0}] Verification via Okta Verify TOTP failed." -f $functionName | Write-Verbose
                            "[{0}] Error message: {1}" -f $functionName, $responseStep55.messages.value[0].message | Write-Verbose
                        
                            if (-not $NoProgress) {
                                Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                            }
                            throw "[{0}] Authentication failed: Unable to verify the Okta Verify TOTP code. The code was incorrect or expired." -f $functionName
                        }
                    }

                    # "[{0}] Raw response for `$responseStep55`: `n{1}" -f $functionName, ($responseStep55 | ConvertTo-Json -Depth 50) | Write-Verbose
                        
                    # After success (push or TOTP), perform a final introspect to confirm overall state
                    "[{0}] Performing final introspect to confirm overall authentication state and capture cookies (POST https://mylogin.hpe.com/idp/idx/introspect)" -f $functionName | Write-Verbose
                    $body = @{ stateHandle = $stateHandle } | ConvertTo-Json

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
                            throw "[{0}] Authentication failed: Introspect POST failed with unexpected error: {1}" -f $functionName, $_.Exception.Message
                        }
                    }

                    if ($finalIntrospectData.success.name -ne "success-redirect") {
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                    
                        # Build detailed error message
                        Write-Error @"
Authentication failed: Okta authentication did not complete successfully.

This error can occur for multiple reasons:

1. MFA Challenge Not Completed
   - Okta Verify push notification was denied, ignored, or timed out
   - TOTP code was not entered or was incorrect
   - Authentication request expired before completion

2. User Not Assigned to HPE GreenLake Application
   - Contact your Okta administrator to verify you have access to the HPE GreenLake application
   - Ensure you have the required application role assignments

3. Missing Required Licenses (Okta)
   - User account may lack required Okta licenses or features
   - Contact your Okta administrator to verify licensing

4. Okta Configuration Issues
   - SAML assertion generation failed
   - Application integration settings are incorrect
   - Required claims or attributes are missing

5. Session or State Issues
   - Authentication session expired
   - State handle became invalid during the authentication flow

Introspect status: $($finalIntrospectData.status)
For complete Okta setup prerequisites, see: $script:HelpUrl
"@ -ErrorAction Stop
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
                        throw "[{0}] Authentication failed: Action URL not found" -f $functionName
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
                        throw "[{0}] Authentication failed: RelayState not found" -f $functionName
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

                } # End if (-not $skipTraditionalOktaVerify)

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
                    throw "[{0}] Authentication failed: SAML POST failed with error: {1}" -f $functionName, $_.Exception.Message
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
                # Check if we're being asked to re-authenticate (MFA step-up scenario)
                elseif ($introspectResult.remediation -and $introspectResult.remediation.value) {
                    $remediationActions = $introspectResult.remediation.value | ForEach-Object { $_.name }
                    "[{0}] Remediation actions required: {1}" -f $functionName, ($remediationActions -join ', ') | Write-Verbose
                    
                    # Check for select-authenticator-authenticate which indicates MFA step-up is required
                    if ($remediationActions -contains 'select-authenticator-authenticate') {
                        $availableAuthenticators = @()
                        foreach ($remediation in $introspectResult.remediation.value) {
                            if ($remediation.name -eq 'select-authenticator-authenticate' -and $remediation.value) {
                                foreach ($value in $remediation.value) {
                                    if ($value.name -eq 'authenticator' -and $value.options) {
                                        foreach ($option in $value.options) {
                                            $availableAuthenticators += $option.label
                                        }
                                    }
                                }
                            }
                        }
                        
                        $authenticatorList = if ($availableAuthenticators.Count -gt 0) { 
                            "`n`nAvailable authenticators: $($availableAuthenticators -join ', ')" 
                        }

                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }

                        Write-Error @"
Authentication failed: Outdated Okta Verify app detected.

ROOT CAUSE: Your Okta Verify mobile app is too old to meet current security requirements.

IMMEDIATE SOLUTIONS:
1. UPDATE Okta Verify on your mobile device to the latest version 
2. RE-ENROLL your device if updating doesn't work  

WHY THIS HAPPENS:
- Initial MFA succeeded with basic authentication context
- Token exchange requires enhanced device attestation  
- Your outdated Okta Verify app cannot provide the required security proof${authenticatorList}

Contact IT support if updating the app doesn't resolve this issue.

Technical details: MFA step-up triggered due to insufficient device attestation during SAML-to-OIDC token exchange.
"@ -ErrorAction Stop

                    }
                    else {
                        # Other remediation actions that we don't handle
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        $remediationList = $remediationActions -join ', '
                        Write-Error @" 
Authentication failed: Unexpected remediation actions required: $remediationList

Please contact your IT administrator.
"@ -ErrorAction Stop 
                    }
                }
                else {
                    # Neither success nor known remediation patterns
                    if (-not $NoProgress) {
                        Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                        Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                    }
                    Write-Error @"
Authentication failed: Introspect did not return a success href or recognized remediation pattern.

Response: $($response.Content)
"@ -ErrorAction Stop
                }

                #endregion [STEP 5.8] Post to introspect to exchange stateToken for authorization code

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
                    throw "[{0}] Authentication failed: Unable to obtain authorization code after submitting credentials." -f $functionName
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
                        throw "[{0}] Authentication failed: Unexpected error in response messages: {1}" -f $functionName, ($challengeResp.messages | ConvertTo-Json -Depth 20)
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
                                        throw "[{0}] Authentication failed: Incorrect password. Please verify your credentials and try again." -f $functionName
                                    }
                                    "errors.E0000015" {
                                        "[{0}] Detected insufficient permissions error (errors.E0000015)" -f $functionName | Write-Verbose
                                        if (-not $NoProgress) {
                                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                        }                                        
                                        throw "[{0}] Authentication failed: Insufficient permissions. Please ensure your account has the necessary access rights." -f $functionName
                                    }
                                    "errors.E0000011" {
                                        "[{0}] Detected invalid token error (errors.E0000011)" -f $functionName | Write-Verbose
                                        if (-not $NoProgress) {
                                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                        }
                                        throw "[{0}] Authentication failed: Invalid token provided. Please try again or contact your administrator." -f $functionName
                                    }
                                    "errors.E0000064" {
                                        "[{0}] Detected password expired error (errors.E0000064)" -f $functionName | Write-Verbose
                                        if (-not $NoProgress) {
                                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                        }                                        
                                        throw "[{0}] Authentication failed: Your password has expired. Please reset your password and try again." -f $functionName
                                    }
                                    "errors.E0000207" {
                                        "[{0}] Detected incorrect username or password error (errors.E0000207)" -f $functionName | Write-Verbose
                                        if (-not $NoProgress) {
                                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                        }                                        
                                        throw "[{0}] Authentication failed: Incorrect username or password. Please verify your credentials and try again." -f $functionName
                                    }
                                    default {
                                        "[{0}] Detected other error: {1} (key={2})" -f $functionName, $message.message, $message.i18n.key | Write-Verbose
                                        if (-not $NoProgress) {
                                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                        }
                                        throw "[{0}] Authentication failed: {1} (key={2})" -f $functionName, $message.message, $message.i18n.key
                                    }
                                }
                            }
                        }
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }                        
                        throw "[{0}] Authentication failed: {1} {2} (no error details)" -f $functionName, $StatusCode, $StatusError
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
                                        throw "[{0}] Authentication failed: Invalid session. Please try logging in again." -f $functionName
                                    }
                                    default {
                                        "[{0}] Detected other error: {1} (key={2})" -f $functionName, $message.message, $message.i18n.key | Write-Verbose
                                        if (-not $NoProgress) {
                                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                        }
                                        throw "[{0}] Authentication failed: {1} (key={2})" -f $functionName, $message.message, $message.i18n.key
                                    }
                                }
                            }
                        }
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        throw "[{0}] Authentication failed: {1} {2} (no error details)" -f $functionName, $StatusCode, $StatusError
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
                                        throw "[{0}] Authentication failed: Resource not found. Please contact your administrator." -f $functionName
                                    }
                                    default {
                                        "[{0}] Detected other error: {1} (key={2})" -f $functionName, $message.message, $message.i18n.key | Write-Verbose
                                        if (-not $NoProgress) {
                                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                                        }
                                        throw "[{0}] Authentication failed: {1} (key={2})" -f $functionName, $message.message, $message.i18n.key
                                    }
                                }
                            }
                        }
                        if (-not $NoProgress) {
                            Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                            Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                        }
                        throw "[{0}] Authentication failed: {1} {2} (no error details)" -f $functionName, $StatusCode, $StatusError
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
                    Write-Error @"
Connection error! Multi-factor authentication (MFA) enrollment is required.

Please log in to the HPE GreenLake GUI and complete the MFA setup using one of the available methods before proceeding with this library.
"@ -ErrorAction Stop
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
                            throw "[{0}] Maximum number of Okta Verify push polling attempts ({1}) reached. MFA approval not received." -f $functionName, $maxPolls
                        }
                        if ($challengeResp.messages -and $challengeResp.messages.value -and $challengeResp.messages.value[0].message) {
                            "[{0}] Okta Verify push polling error: {1}" -f $functionName, $challengeResp.messages.value[0].message | Write-Verbose
                            if (-not $NoProgress) {
                                Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                            }
                            throw "[{0}] Okta Verify push polling error: {1}" -f $functionName, $challengeResp.messages.value[0].message
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
                            throw "[{0}] Authentication failed: '{1}' code expired." -f $functionName, $preferredAuthenticator.name
                        }
                        elseif ($_.Exception.Response -and $_.Exception.Response.StatusCode.value__ -eq 400) {
                            "[{0}] {1} code rejected. HTTP 400 Bad Request received." -f $functionName, $preferredAuthenticator.name | Write-Verbose
                            if (-not $NoProgress) {
                                Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                            }
                            Write-Error @"
Authentication failed: The code entered for '$($preferredAuthenticator.name)' was incorrect (HTTP 400).

Please verify your authenticator app and try again.
"@ -ErrorAction Stop
                        }
                        else {
                            "[{0}] {1} code rejected. Error: {2}" -f $functionName, $preferredAuthenticator.name, $errMsg | Write-Verbose
                            if (-not $NoProgress) {
                                Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                                Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                            }
                            throw "[{0}] Authentication failed: The code entered for '{1}' was rejected. Error: {2}" -f $functionName, $preferredAuthenticator.name, $errMsg
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
                        throw "[{0}] Authentication failed: '{1}' code rejected." -f $functionName, $preferredAuthenticator.name
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
                    throw "[{0}] Connection error! Unable to obtain authorization code after submitting credentials." -f $functionName
                } 
                else {
                    "[{0}] Authorization code obtained successfully." -f $functionName | Write-Verbose
                    "[{0}] Authorization code: {1}...{2}" -f $functionName, $authCode.Substring(0, 1), $authCode.Substring($authCode.Length - 1, 1) | Write-Verbose
                }

                $completedSteps++
                #endregion STEP 5.2: End credential submission and redirect handling                       
            }

            $tokenUrl = "https://sso.common.cloud.hpe.com/as/token.oauth2"
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
            grant_type    = "authorization_code"
            code          = $authCode
            redirect_uri  = $RedirectUri
            code_verifier = $codeVerifier
            client_id     = $dynamicClientId
        }
        "[{0}] About to execute POST request to: '{1}'" -f $functionName, $tokenUrl | Write-Verbose
        
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
        
        try {
            $tokenResponse = Invoke-RestMethod -Uri $tokenUrl -Method Post -Body $bodyString -ContentType "application/x-www-form-urlencoded"
            "[{0}] Token exchange successful - Status: {1}" -f $functionName, $tokenResponse.StatusCode | Write-Verbose
        }   
        catch {
            if (-not $NoProgress) {
                Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 0
                Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
            }
            "[{0}] Failed to exchange OAuth code for tokens: {1}" -f $functionName, $_.Exception.Message | Write-Verbose
            
            # Try to get error response body
            $errorBody = $null
            if ($_.Exception.Response) {
                try {
                    $errorBody = $_.ErrorDetails.Message
                }
                catch {
                    $errorBody = "Could not read error details"
                }
            }
            elseif ($_.ErrorDetails) {
                $errorBody = $_.ErrorDetails.Message
            }
            
            if ($errorBody) {
                "[{0}] Error details: {1}" -f $functionName, $errorBody | Write-Verbose
            }
            
            throw "[{0}] Authentication failed: Could not exchange OAuth code for access token. {1}" -f $functionName, $_.Exception.Message
        }
        
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
                        }
                        catch {
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
                    Write-Error @"
Workspace '$Name' not found or not accessible.

This error can occur for multiple reasons:

1. Workspace does not exist in HPE GreenLake
2. Workspace name is misspelled
3. User does not have access permissions to this workspace
   - Contact your HPE GreenLake workspace administrator
   - Verify you have been assigned the appropriate role (Observer, Operator, or Administrator)

To view available workspaces: Get-HPEGLWorkspace
"@ -ErrorAction Stop
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
                $errorMessage = @"
Workspace '$Name' not found or not accessible for user '$($Global:HPEGreenLakeSession.username)'.

This error can occur for multiple reasons:

1. Workspace does not exist in HPE GreenLake
2. Workspace name is misspelled
3. User does not have access permissions to this workspace
   - Contact your HPE GreenLake workspace administrator
   - Verify you have been assigned the appropriate role (Observer, Operator, or Administrator)

To view available workspaces: Get-HPEGLWorkspace
"@
                throw $errorMessage
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
                        '[{0}] Found existing API credentials: {1}' -f $functionName, (($APIcredentials | Select-Object -ExpandProperty name -Unique) -join ', ') | Write-Verbose
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
                
                # Check for 403 Forbidden error (insufficient permissions)
                $ErrorMessage = $_.Exception.Message
                if ($ErrorMessage -match "403" -or $ErrorMessage -match "Forbidden") {
                    Write-Error @"
Insufficient permissions to remove API credentials (403 Forbidden).

Your user account does not have the required permissions to remove existing API credentials in this workspace.

ROLES THAT CANNOT MANAGE API CREDENTIALS:
The following roles will result in a 403 Forbidden error when attempting to create or remove API credentials:
- Workspace Member
- Identity domain and SCIM integration (Administrator, Viewer)
- Identity domain and SSO (Administrator, Viewer)
- Identity user administrator
- Identity user group administrator
- Identity user group membership administrator
- Orders (Administrator, Operator, Observer)
- Organization administrator
- Organization workspace (Administrator, Viewer)

REQUIRED PERMISSIONS:
You need a role with workspace-level API credential management permissions, such as:
- Workspace Observer (minimum required role)
- Workspace Operator
- Workspace Administrator

SOLUTIONS:
1. Contact your Workspace Administrator to:
   - Grant you a role with API credential management permissions
   - Or manually remove old API credentials from your account
2. Connect without the -RemoveExistingCredentials parameter (old credentials will remain but may cause "maximum of 7 API clients" error later)
3. Use a different user account with at least 'Workspace Observer' role privileges

For more information about roles and permissions, visit:
https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us
"@ -ErrorAction Stop
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

                "[{0}] Created new GLP API credential: {1}" -f $functionName, $global:HPEGLAPIClientCredentialName | Write-Verbose
            }
            catch {
                if (-not $NoProgress) {
                    Update-ProgressBar -CompletedSteps $totalSteps -TotalSteps $totalSteps -CurrentActivity "Failed" -Id 1
                    Write-Progress -Id 1 -Activity "Connecting to HPE GreenLake workspace" -Status "Failed" -Completed
                    Write-Progress -Id 0 -Activity "Connecting to HPE GreenLake" -Status "Failed" -Completed
                }
                $ErrorMessage = $_.Exception.Message
                
                # Check for 403 Forbidden error (insufficient permissions)
                if ($ErrorMessage -match "403" -or $ErrorMessage -match "Forbidden") {
                    Write-Error @"
Insufficient permissions to create API credentials (403 Forbidden).

IMPORTANT: This PowerShell library requires the ability to create temporary API credentials to function properly. 
API credential creation is a mandatory requirement for Connect-HPEGL to establish a connection and interact with HPE GreenLake services.

Your user account does not have the required permissions to create API credentials in this workspace.

ROLES THAT CANNOT MANAGE API CREDENTIALS:
The following roles will result in a 403 Forbidden error when attempting to create or remove API credentials:
- Workspace Member
- Identity domain and SCIM integration (Administrator, Viewer)
- Identity domain and SSO (Administrator, Viewer)
- Identity user administrator
- Identity user group administrator
- Identity user group membership administrator
- Orders (Administrator, Operator, Observer)
- Organization administrator
- Organization workspace (Administrator, Viewer)

REQUIRED PERMISSIONS:
You need a role with workspace-level API credential management permissions, such as:
- Workspace Observer (minimum required role)
- Workspace Operator
- Workspace Administrator

SOLUTIONS:
1. Contact your Workspace Administrator or Identity user administrator to grant you a role with API credential management permissions (at minimum 'Workspace Observer')
2. Use a different user account that has the required permissions

For more information about roles and permissions, visit:
https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us
"@ -ErrorAction Stop
                }
                elseif ($ErrorMessage -match "You have reached the maximum of 7 personal API clients") {
                    Write-Error @"
You have reached the maximum limit of 7 personal API clients.

CAUSE:
HPE GreenLake enforces a maximum of 7 personal API client credentials per user account. This limit has been reached, preventing new credential creation.

SOLUTION:
Use the -RemoveExistingCredentials parameter when connecting to automatically remove old credentials created by this library:

    Connect-HPEGL -Credential `$credentials -Workspace "MyWorkspace" -RemoveExistingCredentials

This will clean up unused credentials from previous sessions that were not properly removed by Disconnect-HPEGL.

CAUTION:
Removing existing credentials may affect other active PowerShell sessions using those credentials. Those sessions will need to reconnect after cleanup.

ALTERNATIVE:
Manually remove old credentials via the HPE GreenLake web portal (Manage Workspace > Personal API clients) before reconnecting.
"@ -ErrorAction Stop                
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
                "[{0}] Create session using temporary GLP credentials '{1}'" -f $functionName, $GLPTemporaryCredentials.name | Write-Verbose
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
# MIItTQYJKoZIhvcNAQcCoIItPjCCLToCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCAgz3IcSK1/RxzO
# Zs1eorBYVyy0TpF092mzJIW13Bi696CCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# nZ+oA+rbZZyGZkz3xbUYKTGCGq0wghqpAgEBMGkwVDELMAkGA1UEBhMCR0IxGDAW
# BgNVBAoTD1NlY3RpZ28gTGltaXRlZDErMCkGA1UEAxMiU2VjdGlnbyBQdWJsaWMg
# Q29kZSBTaWduaW5nIENBIFIzNgIRAMgx4fswkMFDciVfUuoKqr0wDQYJYIZIAWUD
# BAIBBQCgfDAQBgorBgEEAYI3AgEMMQIwADAZBgkqhkiG9w0BCQMxDAYKKwYBBAGC
# NwIBBDAcBgorBgEEAYI3AgELMQ4wDAYKKwYBBAGCNwIBFTAvBgkqhkiG9w0BCQQx
# IgQg4K9xm8Uv9Mu9nRz+CaUt46UuQfdTzbDlUaWPOVPt9o0wDQYJKoZIhvcNAQEB
# BQAEggIAeeYuwopqXHQdinAbCv7wxXRtdzs1gffQje7uj4oOpYoTtc4nMvMMNRFq
# qaGrsUWcllnFyi5ZRqyOAynZNG4JKG5GM21/SlpL4biNXrkTDTLexWrAWRWjJ458
# fS8iXuwqKwPV6g+JIV3G9QpeVH25oScgkRAWT7M4FC4+wjg4ckUVCGG7ZGo5le5s
# 9UQxRSazr+PmRltMpsckVhPrLkC4MRujUHeyDPUdF3P734rh9NE1fgvuiNPIy0Uk
# 5h6DTSGn/P4avkQVjdsx8h5RsTiJO6YH3zJMD6NWebc/XFqKNcTGFkg4AaE2f9ZN
# JRZl3c0G6FjdmICiBF79kIQc2HtrYp/e5lzWDzTiPQO/IcY0y3f4Yv9s1C1OUWjk
# mhhSZQ2Wix6Y097dnZ+tG4apCP+jls0HcxdjpTu5bweAo23SgZiRBL8rwMW3QM+i
# 30EAtEnVd687HWulO7oRizwxMKG0FuWqXnJ6o/tFG3DIPrVbYHQC/HGAV+ZX1HRG
# 6XQHGkyT5dspFo18BKFbYzvldiVy/hQnw67e6gzMQPIEyFuhywWCBz8V3bUQXMHE
# McLx+0TDqiEApjeaeLnHo/TpG5Wn2gng6fDTs0JqUiIR+BnKYgVp4enSy7fEgr5b
# gkh9IcYUW0KUVtKiqGYyppyUpBdxF54S58Xi9sO72phQQqlIQ1mhgheXMIIXkwYK
# KwYBBAGCNwMDATGCF4Mwghd/BgkqhkiG9w0BBwKgghdwMIIXbAIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIGHBgsqhkiG9w0BCRABBKB4BHYwdAIBAQYJYIZIAYb9bAcBMEEw
# DQYJYIZIAWUDBAICBQAEMLjCqQsEzMxCmn3PRCkV2PPd+bX9aAZO8dIouUSDeNEa
# 6Mkt1JPHnH2xbXm3LUOXfAIQNqVYKr8vkm4o1h3aF/g5aBgPMjAyNTExMjUxNTM0
# NTNaoIITOjCCBu0wggTVoAMCAQICEAwgQ0n50PdZ+5gt5AgbiHswDQYJKoZIhvcN
# AQEMBQAwaTELMAkGA1UEBhMCVVMxFzAVBgNVBAoTDkRpZ2lDZXJ0LCBJbmMuMUEw
# PwYDVQQDEzhEaWdpQ2VydCBUcnVzdGVkIEc0IFRpbWVTdGFtcGluZyBSU0E0MDk2
# IFNIQTI1NiAyMDI1IENBMTAeFw0yNTA2MDQwMDAwMDBaFw0zNjA5MDMyMzU5NTla
# MGMxCzAJBgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjE7MDkGA1UE
# AxMyRGlnaUNlcnQgU0hBMzg0IFJTQTQwOTYgVGltZXN0YW1wIFJlc3BvbmRlciAy
# MDI1IDEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQDbOVL7i3S35ckN
# Udj680nGm/v3iwzc7hRDJyYpFeZguz5hF/O3KXxAnuf9SrE1MpaaN0UNYa/jf5ra
# iInjXLE57SwugXHwXVrPYlFNlzt2EDFud75vJ3lt/ZIRmUKu4bHFZKpulRjp0AZE
# ILIE5qIVqheGSf4vXl59yiYNKtOcDlWB32m8w77tsz61JbgnMCIhs7aYg/IIR0pi
# xyY+X5gG56dI/s0nD2JwvW1amfrW4zpbJQ2/hFzIEDP428ls1/mRMzsXjpy8HCnS
# VliKxlH3znLmxiPh7jJQFs8HHKtPlo0xn77m2KzwYOYcKmrJUtDh4sfCmKbmLBHj
# 1NER8RO2UQU5FZOQnaE47XPNUBazqO116nXZW0VmhA6EjB1R88dKwDDf3EVV68UQ
# V/a74NWvWw5XskAJj7FwbyFYh6o8ZVTCSLIFFROADsd4DElvSJCXgYMELpkEDjAY
# 39qEzEXh+4mw6zXPCQ8FKdeYeSbXwfAeAg8qTbzt0whyFnKObvMZwJhnhuKyhRhY
# v2hOBr0kJ8UxNz3KXbpcMHTOX2t1LC+I6ZphKVpFqcXzijEBieqAHLpnz3KQ+Bad
# vtJGLfU3I/fn1aGiT7fp+TLFM+NKsJa8wrunNtGDy18hGVSfGXsblsiuQ+oxsP3M
# mgHv0wcWAuvmWNTuutwvDL5wR+nMUwIDAQABo4IBlTCCAZEwDAYDVR0TAQH/BAIw
# ADAdBgNVHQ4EFgQUVZ6552fIkRBJtDZSjXm3JMU/LfgwHwYDVR0jBBgwFoAU729T
# SunkBnx6yuKQVvYv1Ensy04wDgYDVR0PAQH/BAQDAgeAMBYGA1UdJQEB/wQMMAoG
# CCsGAQUFBwMIMIGVBggrBgEFBQcBAQSBiDCBhTAkBggrBgEFBQcwAYYYaHR0cDov
# L29jc3AuZGlnaWNlcnQuY29tMF0GCCsGAQUFBzAChlFodHRwOi8vY2FjZXJ0cy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkRzRUaW1lU3RhbXBpbmdSU0E0MDk2
# U0hBMjU2MjAyNUNBMS5jcnQwXwYDVR0fBFgwVjBUoFKgUIZOaHR0cDovL2NybDMu
# ZGlnaWNlcnQuY29tL0RpZ2lDZXJ0VHJ1c3RlZEc0VGltZVN0YW1waW5nUlNBNDA5
# NlNIQTI1NjIwMjVDQTEuY3JsMCAGA1UdIAQZMBcwCAYGZ4EMAQQCMAsGCWCGSAGG
# /WwHATANBgkqhkiG9w0BAQwFAAOCAgEAG34LJIfYCWrFQedRadkkjuul0CqjQ9yK
# TJXjwu2TlBYWDGkc/1a2NHeWyQQA6TdOzOa43IyJ3tW7EeVAmXgpx1OvlxDZgvL6
# XnrSl4GAzuQDgcImoap1B3ONfKuWDdgJ1+eOz3D/sE7zFSaUBqr8P49Nlk74yfFr
# f8ijJiwX4v2BZfhUnFkuWNWzkkqalKiefKwxi/sJqqRCkEOYlZTYXryYstld9TTB
# dsPL1BBOySBwe+LJAN4HWXqOX9bA5CJI1M1p9hBRHZmwnms8m7U0/M7WG0rB2JSN
# Z6cfCrkFErUFHv4P5PAb3tQdfhXRb4m8VmnzPd3cbmwDs+32o7n/oBZn7TJ/yc3n
# wP4cABKEeafLbm3pbuoXpVJFkIikavyFsCN9sGE7gxjwbZT3PBUqnpKWO4qSfF3Z
# u6KE7fd2KgIawHq2tf77FAp/hCVhKCAW8P1lZIbjKwk9g7H6FuwFMQ40W2v33Ho6
# AmefJWQOi50if6CZX4Gr5rYb74EtTkBc5VyUTGm6hRBdRkXmnexSt3bVCMX1FrTH
# hEPTaBLhfCDM362+5j62OE8gLBeYfcREv588ijFlPReDBU/7XtSpRuLlml7hh1p0
# blaMJMG+2aUzglWi8ZhG/IDJ+ZgknHT/RP6orTnBEmmDirzW84q4JA9oT0f30kJW
# 98IMGbgqOsQwgga0MIIEnKADAgECAhANx6xXBf8hmS5AQyIMOkmGMA0GCSqGSIb3
# DQEBCwUAMGIxCzAJBgNVBAYTAlVTMRUwEwYDVQQKEwxEaWdpQ2VydCBJbmMxGTAX
# BgNVBAsTEHd3dy5kaWdpY2VydC5jb20xITAfBgNVBAMTGERpZ2lDZXJ0IFRydXN0
# ZWQgUm9vdCBHNDAeFw0yNTA1MDcwMDAwMDBaFw0zODAxMTQyMzU5NTlaMGkxCzAJ
# BgNVBAYTAlVTMRcwFQYDVQQKEw5EaWdpQ2VydCwgSW5jLjFBMD8GA1UEAxM4RGln
# aUNlcnQgVHJ1c3RlZCBHNCBUaW1lU3RhbXBpbmcgUlNBNDA5NiBTSEEyNTYgMjAy
# NSBDQTEwggIiMA0GCSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC0eDHTCphBcr48
# RsAcrHXbo0ZodLRRF51NrY0NlLWZloMsVO1DahGPNRcybEKq+RuwOnPhof6pvF4u
# GjwjqNjfEvUi6wuim5bap+0lgloM2zX4kftn5B1IpYzTqpyFQ/4Bt0mAxAHeHYNn
# QxqXmRinvuNgxVBdJkf77S2uPoCj7GH8BLuxBG5AvftBdsOECS1UkxBvMgEdgkFi
# DNYiOTx4OtiFcMSkqTtF2hfQz3zQSku2Ws3IfDReb6e3mmdglTcaarps0wjUjsZv
# kgFkriK9tUKJm/s80FiocSk1VYLZlDwFt+cVFBURJg6zMUjZa/zbCclF83bRVFLe
# GkuAhHiGPMvSGmhgaTzVyhYn4p0+8y9oHRaQT/aofEnS5xLrfxnGpTXiUOeSLsJy
# goLPp66bkDX1ZlAeSpQl92QOMeRxykvq6gbylsXQskBBBnGy3tW/AMOMCZIVNSaz
# 7BX8VtYGqLt9MmeOreGPRdtBx3yGOP+rx3rKWDEJlIqLXvJWnY0v5ydPpOjL6s36
# czwzsucuoKs7Yk/ehb//Wx+5kMqIMRvUBDx6z1ev+7psNOdgJMoiwOrUG2ZdSoQb
# U2rMkpLiQ6bGRinZbI4OLu9BMIFm1UUl9VnePs6BaaeEWvjJSjNm2qA+sdFUeEY0
# qVjPKOWug/G6X5uAiynM7Bu2ayBjUwIDAQABo4IBXTCCAVkwEgYDVR0TAQH/BAgw
# BgEB/wIBADAdBgNVHQ4EFgQU729TSunkBnx6yuKQVvYv1Ensy04wHwYDVR0jBBgw
# FoAU7NfjgtJxXWRM3y5nP+e6mK4cD08wDgYDVR0PAQH/BAQDAgGGMBMGA1UdJQQM
# MAoGCCsGAQUFBwMIMHcGCCsGAQUFBwEBBGswaTAkBggrBgEFBQcwAYYYaHR0cDov
# L29jc3AuZGlnaWNlcnQuY29tMEEGCCsGAQUFBzAChjVodHRwOi8vY2FjZXJ0cy5k
# aWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVkUm9vdEc0LmNydDBDBgNVHR8EPDA6
# MDigNqA0hjJodHRwOi8vY3JsMy5kaWdpY2VydC5jb20vRGlnaUNlcnRUcnVzdGVk
# Um9vdEc0LmNybDAgBgNVHSAEGTAXMAgGBmeBDAEEAjALBglghkgBhv1sBwEwDQYJ
# KoZIhvcNAQELBQADggIBABfO+xaAHP4HPRF2cTC9vgvItTSmf83Qh8WIGjB/T8Ob
# XAZz8OjuhUxjaaFdleMM0lBryPTQM2qEJPe36zwbSI/mS83afsl3YTj+IQhQE7jU
# /kXjjytJgnn0hvrV6hqWGd3rLAUt6vJy9lMDPjTLxLgXf9r5nWMQwr8Myb9rEVKC
# hHyfpzee5kH0F8HABBgr0UdqirZ7bowe9Vj2AIMD8liyrukZ2iA/wdG2th9y1IsA
# 0QF8dTXqvcnTmpfeQh35k5zOCPmSNq1UH410ANVko43+Cdmu4y81hjajV/gxdEkM
# x1NKU4uHQcKfZxAvBAKqMVuqte69M9J6A47OvgRaPs+2ykgcGV00TYr2Lr3ty9qI
# ijanrUR3anzEwlvzZiiyfTPjLbnFRsjsYg39OlV8cipDoq7+qNNjqFzeGxcytL5T
# TLL4ZaoBdqbhOhZ3ZRDUphPvSRmMThi0vw9vODRzW6AxnJll38F0cuJG7uEBYTpt
# MSbhdhGQDpOXgpIUsWTjd6xpR6oaQf/DJbg3s6KCLPAlZ66RzIg9sC+NJpud/v4+
# 7RWsWCiKi9EOLLHfMR2ZyJ/+xhCx9yHbxtl5TPau1j/1MIDpMPx0LckTetiSuEtQ
# vLsNz3Qbp7wGWqbIiOWCnb5WqxL3/BAPvIXKUjPSxyZsq8WhbaM2tszWkPZPubdc
# MIIFjTCCBHWgAwIBAgIQDpsYjvnQLefv21DiCEAYWjANBgkqhkiG9w0BAQwFADBl
# MQswCQYDVQQGEwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3
# d3cuZGlnaWNlcnQuY29tMSQwIgYDVQQDExtEaWdpQ2VydCBBc3N1cmVkIElEIFJv
# b3QgQ0EwHhcNMjIwODAxMDAwMDAwWhcNMzExMTA5MjM1OTU5WjBiMQswCQYDVQQG
# EwJVUzEVMBMGA1UEChMMRGlnaUNlcnQgSW5jMRkwFwYDVQQLExB3d3cuZGlnaWNl
# cnQuY29tMSEwHwYDVQQDExhEaWdpQ2VydCBUcnVzdGVkIFJvb3QgRzQwggIiMA0G
# CSqGSIb3DQEBAQUAA4ICDwAwggIKAoICAQC/5pBzaN675F1KPDAiMGkz7MKnJS7J
# IT3yithZwuEppz1Yq3aaza57G4QNxDAf8xukOBbrVsaXbR2rsnnyyhHS5F/WBTxS
# D1Ifxp4VpX6+n6lXFllVcq9ok3DCsrp1mWpzMpTREEQQLt+C8weE5nQ7bXHiLQwb
# 7iDVySAdYyktzuxeTsiT+CFhmzTrBcZe7FsavOvJz82sNEBfsXpm7nfISKhmV1ef
# VFiODCu3T6cw2Vbuyntd463JT17lNecxy9qTXtyOj4DatpGYQJB5w3jHtrHEtWoY
# OAMQjdjUN6QuBX2I9YI+EJFwq1WCQTLX2wRzKm6RAXwhTNS8rhsDdV14Ztk6MUSa
# M0C/CNdaSaTC5qmgZ92kJ7yhTzm1EVgX9yRcRo9k98FpiHaYdj1ZXUJ2h4mXaXpI
# 8OCiEhtmmnTK3kse5w5jrubU75KSOp493ADkRSWJtppEGSt+wJS00mFt6zPZxd9L
# BADMfRyVw4/3IbKyEbe7f/LVjHAsQWCqsWMYRJUadmJ+9oCw++hkpjPRiQfhvbfm
# Q6QYuKZ3AeEPlAwhHbJUKSWJbOUOUlFHdL4mrLZBdd56rF+NP8m800ERElvlEFDr
# McXKchYiCd98THU/Y+whX8QgUWtvsauGi0/C1kVfnSD8oR7FwI+isX4KJpn15Gkv
# mB0t9dmpsh3lGwIDAQABo4IBOjCCATYwDwYDVR0TAQH/BAUwAwEB/zAdBgNVHQ4E
# FgQU7NfjgtJxXWRM3y5nP+e6mK4cD08wHwYDVR0jBBgwFoAUReuir/SSy4IxLVGL
# p6chnfNtyA8wDgYDVR0PAQH/BAQDAgGGMHkGCCsGAQUFBwEBBG0wazAkBggrBgEF
# BQcwAYYYaHR0cDovL29jc3AuZGlnaWNlcnQuY29tMEMGCCsGAQUFBzAChjdodHRw
# Oi8vY2FjZXJ0cy5kaWdpY2VydC5jb20vRGlnaUNlcnRBc3N1cmVkSURSb290Q0Eu
# Y3J0MEUGA1UdHwQ+MDwwOqA4oDaGNGh0dHA6Ly9jcmwzLmRpZ2ljZXJ0LmNvbS9E
# aWdpQ2VydEFzc3VyZWRJRFJvb3RDQS5jcmwwEQYDVR0gBAowCDAGBgRVHSAAMA0G
# CSqGSIb3DQEBDAUAA4IBAQBwoL9DXFXnOF+go3QbPbYW1/e/Vwe9mqyhhyzshV6p
# Grsi+IcaaVQi7aSId229GhT0E0p6Ly23OO/0/4C5+KH38nLeJLxSA8hO0Cre+i1W
# z/n096wwepqLsl7Uz9FDRJtDIeuWcqFItJnLnU+nBgMTdydE1Od/6Fmo8L8vC6bp
# 8jQ87PcDx4eo0kxAGTVGamlUsLihVo7spNU96LHc/RzY9HdaXFSMb++hUD38dglo
# hJ9vytsgjTVgHAIDyyCwrFigDkBjxZgiwbJZ9VVrzyerbHbObyMt9H5xaiNrIv8S
# uFQtJ37YOtnwtoeW/VvRXKwYw02fc7cBqZ9Xql4o4rmUMYIDjDCCA4gCAQEwfTBp
# MQswCQYDVQQGEwJVUzEXMBUGA1UEChMORGlnaUNlcnQsIEluYy4xQTA/BgNVBAMT
# OERpZ2lDZXJ0IFRydXN0ZWQgRzQgVGltZVN0YW1waW5nIFJTQTQwOTYgU0hBMjU2
# IDIwMjUgQ0ExAhAMIENJ+dD3WfuYLeQIG4h7MA0GCWCGSAFlAwQCAgUAoIHhMBoG
# CSqGSIb3DQEJAzENBgsqhkiG9w0BCRABBDAcBgkqhkiG9w0BCQUxDxcNMjUxMTI1
# MTUzNDUzWjArBgsqhkiG9w0BCRACDDEcMBowGDAWBBRyvP2gEH9JNLAHHGEP5teW
# UACYdzA3BgsqhkiG9w0BCRACLzEoMCYwJDAiBCAy8+OxvaLXsm1PHRuM3b2Pi4R2
# oXie1hLNPKp6nv81wjA/BgkqhkiG9w0BCQQxMgQwKl7/O66xI4szCoNbXlHFBJqg
# ItkGpir6O50YhaBUWVqpGpgJZl/WnaT1ZkD+HexHMA0GCSqGSIb3DQEBAQUABIIC
# AGk2d0eGA+Ds0tmz2xaLsWO/KzaycRoRiF7w1BfQNVzMt1peAEXg5n01E842ioD1
# LZXwjpXEGcbH3mjQQ1cNo8FMgVGdI55xLAmcDgV5xocLvWKNvDXGnA7k0IhUOD4D
# ck2dYX0Q1EPfDRBeCrRh5o5OBGFMr0fgccugjqHTlvNfLjOKiJGDcFPIR85oo4Um
# 39w1L165lCgb8mkBY0GmNOwDIVhwlc7clxwZY942KB5z2rQMTskA6PVGl2fahKrk
# O+ZIfUcMcBCocipMd6fYPTo/QjK+liNqdZVWT4tYaNQ8UfD59vcxcI4IrPZ1v7w4
# lrixUHQsA0f3vmMq87g7SFI0cNItoVzMxwGNxFlkUW4GpQvfHvbztiXDx4nxzMLT
# UJyJxaeTYfFMb7OWntXIKcDH28LoyMT9ImtR4aLYZ72JLB9Yn7WaYf/1ZqMW5Lgt
# 0p4tvsEde22YzACQeCpHuOW5amxfiDnJaVQjBkMhBgJanPn0dZAurrGWrOcazLlD
# Qb/w9zG/87O/Z+zjdoRk+e+T4wxSy60SvMNlDm8FyX9YeViXfNAnrB9dFU+RDAks
# pACRZyzUD8j0T8i7OYHMgiD3f8k2Wv0GLMH7Rt/iOJBvLyfP+Ng9Vj/aMIHk2kFb
# wmL3AsBOUr2WDcDvaVxnrcjCuXKphD8q0fVcBshj4xNt
# SIG # End signature block
