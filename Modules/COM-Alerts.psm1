#------------------- FUNCTIONS FOR COMPUTE OPS MANAGEMENT ALERTS -----------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1

# Public functions
Function Get-HPECOMAlert {
    <#
    .SYNOPSIS
    Retrieve the list of server alerts.

    .DESCRIPTION
    This Cmdlet returns a collection of server alert resources that are available in the specified region.
    Alerts provide security information and issues related to servers.
    By default, all alerts are returned since they persist until cleared.
    
    .PARAMETER Region
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.).
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER SourceName
    Optional parameter that can be used to display alerts for a specific server by name or serial number.
    
    .PARAMETER ShowLastWeek
    This switch parameter can be used to display alerts from the last week (7 days).

    .PARAMETER ShowLastMonth
    This switch parameter can be used to display the alerts from the last month.

    .PARAMETER ShowLastThreeMonths
    This switch parameter can be used to display the alerts from the last three months.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Get-HPECOMAlert -Region eu-central

    Return all server alerts in the central European region.

    .EXAMPLE
    Get-HPECOMAlert -Region eu-central -ShowLastWeek

    Return server alerts from the last week (7 days) in the central European region.

    .EXAMPLE
    Get-HPECOMAlert -Region eu-central -ShowLastMonth

    Return server alerts from the last month in the central European region.

    .EXAMPLE
    Get-HPECOMAlert -Region eu-central -ShowLastThreeMonths

    Return server alerts from the last three months in the central European region.

    .EXAMPLE
    Get-HPECOMAlert -Region eu-central -SourceName CZJ11105MV 

    Retrieve alerts for a server specified by its serial number.

    .EXAMPLE
    Get-HPECOMAlert -Region eu-central -SourceName "ESX-1"

    Retrieve alerts for a server specified by its name.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Name ESX-1 | Get-HPECOMAlert 

    Retrieve alerts for a server named 'ESX-1' in the "eu-central" region using pipeline input.

    .EXAMPLE
    Get-HPECOMServer -Region us-west -PowerState ON | Get-HPECOMAlert

    Retrieve alerts for all powered on servers in the "us-west" region.
       
    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server names or serial numbers.
    System.Collections.ArrayList
        List of server resources retrieved using 'Get-HPECOMServer'.

    .OUTPUTS
    HPEGreenLake.COM.Servers.Alert [System.Management.Automation.PSCustomObject]

        Alert objects with the following key properties:
        - serverName: The name of the server
        - serialNumber: The serial number of the server
        - serverId: The internal server ID
        - createdAt: The date/time when the alert was created (DateTime object)
        - description: The alert description/message
        - severity: The severity level of the alert (possible values: OK, WARNING, CRITICAL, UNKNOWN, NOT_PRESENT, REDUNDANT, NON_REDUNDANT)
        - category: The category of the alert
        - region: The region code where the alert was generated
    
   #>
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 
    
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'Default')] 
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = 'SourceName')]
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

        [Parameter (ParameterSetName = 'SourceName')]
        [Alias('Name', 'SerialNumber')]
        [String]$SourceName,

        [Parameter (ValueFromPipelineByPropertyName, ParameterSetName = 'Default')]
        [Parameter (ValueFromPipelineByPropertyName, ParameterSetName = 'SourceName')]
        [string]$ResourceUri,

        [Parameter (ParameterSetName = 'Default')]
        [Parameter (ParameterSetName = 'SourceName')]
        [Switch]$ShowLastWeek,

        [Parameter (ParameterSetName = 'Default')]
        [Parameter (ParameterSetName = 'SourceName')]
        [Switch]$ShowLastMonth,

        [Parameter (ParameterSetName = 'Default')]
        [Parameter (ParameterSetName = 'SourceName')]
        [Switch]$ShowLastThreeMonths,

        [Switch]$WhatIf
       
    ) 


    Begin {
  
        $Caller = (Get-PSCallStack)[1].Command
        
        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $AlertCollection = [System.Collections.ArrayList]::new()

        # Calculate time filters
        $todayMinusSevenDays = (Get-Date).AddDays(-7).ToUniversalTime()
        $todayMinusOneMonth = (Get-Date).AddMonths(-1).ToUniversalTime()
        $todayMinusThreeMonths = (Get-Date).AddMonths(-3).ToUniversalTime()
      
    }
      
      
    Process {
      
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
       
        if ($ResourceUri) {
            # Extract server ID from resourceUri and use it directly
            $ServerID = $ResourceUri.Split("/")[-1]
            "[{0}] Extracted server ID '{1}' from resourceUri" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServerID | Write-Verbose
            
            # Build URI directly with the extracted server ID
            $Uri = (Get-COMServersUri) + "/" + $ServerID + "/alerts"
            
            # Make API call
            try {
                "[{0}] Retrieving alerts for server ID '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ServerID | Write-Verbose
                [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }

            if ($Null -ne $CollectionList -and $CollectionList.Count -gt 0 -and -not $WhatIf) {
                
                "[{0}] Received {1} alert(s) from server ID '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CollectionList.Count, $ServerID | Write-Verbose
                
                # Add serial number and region to object (serverName not available without lookup)
                $CollectionList | ForEach-Object { 
                    if ($_.serverId) {
                        $_ | Add-Member -type NoteProperty -name serialNumber -value ($_.serverId -split '\+')[1] -Force 
                    }
                }
                $CollectionList | Add-Member -type NoteProperty -name region -value $Region -Force
                
                # Convert createdAt string to DateTime object in-place
                $CollectionList | ForEach-Object { 
                    if ($_.createdAt) {
                        $_.createdAt = [DateTime]$_.createdAt
                    }
                }
                
                "[{0}] Before filtering: {1} alert(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CollectionList.Count | Write-Verbose
                
                # Apply time filters if specified
                if ($ShowLastWeek) {
                    $CollectionList = @($CollectionList | Where-Object { $_.createdAt -and ($_.createdAt -gt $todayMinusSevenDays) })
                    "[{0}] After ShowLastWeek filter: {1} alert(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CollectionList.Count | Write-Verbose
                }
                elseif ($ShowLastMonth) {
                    $CollectionList = @($CollectionList | Where-Object { $_.createdAt -and ($_.createdAt -gt $todayMinusOneMonth) })
                    "[{0}] After ShowLastMonth filter: {1} alert(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CollectionList.Count | Write-Verbose
                }
                elseif ($ShowLastThreeMonths) {
                    $CollectionList = @($CollectionList | Where-Object { $_.createdAt -and ($_.createdAt -gt $todayMinusThreeMonths) })
                    "[{0}] After ShowLastThreeMonths filter: {1} alert(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CollectionList.Count | Write-Verbose
                }
                
                if ($CollectionList.Count -gt 0) {
                    "[{0}] Adding {1} alert(s) to collection" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CollectionList.Count | Write-Verbose
                    [void]$AlertCollection.AddRange($CollectionList)
                }
                else {
                    "[{0}] No alerts remaining after filtering" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                }
            }
        }
        elseif ($SourceName) {
            # Get alerts for a specific server
            
            # Step 1: Pre-validation - Get server resource
            try {
                "[{0}] Retrieving server resource for '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SourceName | Write-Verbose
                $Server = Get-HPECOMServer -Region $Region -Name $SourceName -Verbose:$false | Select-Object -First 1
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }

            # Step 2: Validation check BEFORE API call
            if (-not $Server) {
                "[{0}] Server '{1}' not found in region '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SourceName, $Region | Write-Verbose
                
                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}' not found in region '{1}'. Cannot display API request." -f $SourceName, $Region
                    Write-Warning $ErrorMessage
                    return
                }
                else {
                    # Get-* cmdlet: return nothing silently for "not found"
                    return
                }
            }

            # Step 3: Build URI AFTER validation passes
            $ServerID = $Server.id
            $Uri = (Get-COMServersUri) + "/" + $ServerID + "/alerts"
            
            # Step 4: Make API call
            try {
                "[{0}] Retrieving alerts for server '{1}' (ID: {2})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SourceName, $ServerID | Write-Verbose
                [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }

            if ($Null -ne $CollectionList -and $CollectionList.Count -gt 0 -and -not $WhatIf) {
                
                "[{0}] Received {1} alert(s) from server '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CollectionList.Count, $Server.name | Write-Verbose
                
                # Add serial number, servername, and region to object
                $CollectionList | Add-Member -type NoteProperty -name serverName -value $Server.name -Force
                $CollectionList | ForEach-Object { 
                    if ($_.serverId) {
                        $_ | Add-Member -type NoteProperty -name serialNumber -value ($_.serverId -split '\+')[1] -Force 
                    }
                }
                $CollectionList | Add-Member -type NoteProperty -name region -value $Region -Force
                
                # Convert createdAt string to DateTime object in-place
                $CollectionList | ForEach-Object { 
                    if ($_.createdAt) {
                        $_.createdAt = [DateTime]$_.createdAt
                    }
                }
                
                "[{0}] Before filtering: {1} alert(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CollectionList.Count | Write-Verbose
                
                # Apply time filters if specified
                if ($ShowLastWeek) {
                    $CollectionList = @($CollectionList | Where-Object { $_.createdAt -and ($_.createdAt -gt $todayMinusSevenDays) })
                    "[{0}] After ShowLastWeek filter: {1} alert(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CollectionList.Count | Write-Verbose
                }
                elseif ($ShowLastMonth) {
                    $CollectionList = @($CollectionList | Where-Object { $_.createdAt -and ($_.createdAt -gt $todayMinusOneMonth) })
                    "[{0}] After ShowLastMonth filter: {1} alert(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CollectionList.Count | Write-Verbose
                }
                elseif ($ShowLastThreeMonths) {
                    $CollectionList = @($CollectionList | Where-Object { $_.createdAt -and ($_.createdAt -gt $todayMinusThreeMonths) })
                    "[{0}] After ShowLastThreeMonths filter: {1} alert(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CollectionList.Count | Write-Verbose
                }
                # Default: no filtering - show all alerts (they persist until cleared)
                
                if ($CollectionList.Count -gt 0) {
                    "[{0}] Adding {1} alert(s) to collection" -f $MyInvocation.InvocationName.ToString().ToUpper(), $CollectionList.Count | Write-Verbose
                    [void]$AlertCollection.AddRange($CollectionList)
                }
                else {
                    "[{0}] No alerts remaining after filtering" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                }
            }
        }
        else {
            # Get alerts for all servers in the region
            
            "[{0}] Retrieving all servers in region '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose
            
            # Step 1: Get all servers
            try {
                $Servers = Get-HPECOMServer -Region $Region -Verbose:$false
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)
            }

            if (-not $Servers) {
                "[{0}] No servers found in region '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose
                return
            }

            # Step 2: Get alerts for each server
            foreach ($Server in $Servers) {
                
                $ServerID = $Server.id
                $Uri = (Get-COMServersUri) + "/" + $ServerID + "/alerts"
                
                try {
                    "[{0}] Retrieving alerts for server '{1}' (ID: {2})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Server.name, $ServerID | Write-Verbose
                    [Array]$CollectionList = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -Region $Region -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                }
                catch {
                    # Continue to next server if one fails
                    "[{0}] Failed to retrieve alerts for server '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Server.name, $_.Exception.Message | Write-Verbose
                    continue
                }

                if ($Null -ne $CollectionList -and $CollectionList.Count -gt 0 -and -not $WhatIf) {
                    
                    # Add serial number, servername, and region to object
                    $CollectionList | Add-Member -type NoteProperty -name serverName -value $Server.name -Force
                    $CollectionList | ForEach-Object { 
                        if ($_.serverId) {
                            $_ | Add-Member -type NoteProperty -name serialNumber -value ($_.serverId -split '\+')[1] -Force 
                        }
                    }
                    $CollectionList | Add-Member -type NoteProperty -name region -value $Region -Force
                    
                    # Convert createdAt string to DateTime object in-place
                    $CollectionList | ForEach-Object { 
                        if ($_.createdAt) {
                            $_.createdAt = [DateTime]$_.createdAt
                        }
                    }
                    
                    # Apply time filters if specified
                    if ($ShowLastWeek) {
                        $CollectionList = @($CollectionList | Where-Object { $_.createdAt -and ($_.createdAt -gt $todayMinusSevenDays) })
                    }
                    elseif ($ShowLastMonth) {
                        $CollectionList = @($CollectionList | Where-Object { $_.createdAt -and ($_.createdAt -gt $todayMinusOneMonth) })
                    }
                    elseif ($ShowLastThreeMonths) {
                        $CollectionList = @($CollectionList | Where-Object { $_.createdAt -and ($_.createdAt -gt $todayMinusThreeMonths) })
                    }
                    # Default: no filtering - show all alerts (they persist until cleared)
                    
                    if ($CollectionList.Count -gt 0) {
                        [void]$AlertCollection.AddRange($CollectionList)
                    }
                }
            }
        }

    }

    End {

        "[{0}] Total alerts collected: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $AlertCollection.Count | Write-Verbose

        if ($AlertCollection.Count -gt 0) {
            "[{0}] Repackaging {1} alert(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $AlertCollection.Count | Write-Verbose
            $ReturnData = Invoke-RepackageObjectWithType -RawObject $AlertCollection -ObjectName "COM.Servers.Alert"    
            "[{0}] Returning {1} alert(s)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ReturnData.Count | Write-Verbose
            return $ReturnData | Sort-Object -Property createdAt -Descending
        }
        else {
            "[{0}] No alerts found" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            return
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

                $DataSetType = "HPEGreenLake.$ObjectName"
                $RawElementObject.PSTypeNames.Insert(0, $DataSetType)
                
                $RawElementObject.PSObject.TypeNames.Insert(0, $DataSetType)

                $OutputObject += $RawElementObject
            }

            if ($OutputObject.PSObject.TypeNames -notcontains $DataSetType) {

                foreach ($item in $OutputObject) {
                    [void]($item | Add-Member -MemberType NoteProperty -Name PSObject.TypeNames -Value @( $DataSetType) -Force)
                }
            }

            return $OutputObject
        }
        else {
            return
        }
    }   
}


# Export only public functions and aliases
Export-ModuleMember -Function 'Get-HPECOMAlert' -Alias *

# SIG # Begin signature block
# MIItTgYJKoZIhvcNAQcCoIItPzCCLTsCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCC4WQCMUY+twoAy
# R/8UoP0LvH8mfxqmw/DzaEzWD2sVgaCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQgV4H8BeJSOrsjTD94u08/VsdEb7JvSXy6QRMwJExRwk4wDQYJKoZIhvcNAQEB
# BQAEggIACCm+r4se0io7BpoC6TEIDFLIbqK1BrbyqSEhHGBY/Zzz6aOj0oVjLvxf
# sP9ZmFcyJIGogo/+IuMNaIeHogYHqLUORgR4SKq+BNG1O+ouFZjYT0ZlYcuDzVO6
# Yf9VZ3Vbhj4arWZVoGRnnVTFsVMw9OFrvQc9Lch9PM3n/VAmAbZGKLFYaKHTAbMc
# IHRUY7QMD+XNzWp8ucsonzss4nSM6LG+xPeh78fEjbcu9CIila+v3hfvIR2I4/yH
# 7ztcieTq97BiSQxHDMf8DXABRP5vRjW5bqyQ935ruPzurYPxIELbjx9+5o+j8moV
# dLlW376SrvgbWJELstTLew+foLFdgzM+at46dCEOYGFnzAAbhLWl5QaGYI+h6QgX
# 1K642EVUSGEdxeq3eTvp+GtafQaJSNlvXi8YyhMeJboz7KlLkOb+P3WZ7FYLvjfZ
# OtU2O3SQrlSNBO1DnqAorYoaaT6pTZvPXbOjBoq1jBUKDR2kHkE+VYDIE8QqxDEk
# TdX2AHYFIZrfPRP3V8CDGu+i5+z5u2A6gOvsuQWJh+FNBBYIqJZGkJnnnkoOBcqq
# 0cn4t4rAQW7HlDjBcLg3QM38IgHrqgyFPz9JZVhzaU8XFO2QsgVW1u9HsqSWByDf
# z7fDdcNsZfyf+uYL2iereoiurV9g7nPY2DYxGs/g97vP9Irg89ahgheYMIIXlAYK
# KwYBBAGCNwMDATGCF4QwgheABgkqhkiG9w0BBwKgghdxMIIXbQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIGIBgsqhkiG9w0BCRABBKB5BHcwdQIBAQYJYIZIAYb9bAcBMEEw
# DQYJYIZIAWUDBAICBQAEMEe3uH3m4Jr1RQ8KzOrdYH0eUSOZNFcxFhFPy5hf17rd
# GfPj3IbZZuOdOd1KIjIgCgIRAM0yr5U5daM5GobrYECRjK8YDzIwMjYwMTMwMTA0
# NDQzWqCCEzowggbtMIIE1aADAgECAhAMIENJ+dD3WfuYLeQIG4h7MA0GCSqGSIb3
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
# BgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI2MDEz
# MDEwNDQ0M1owKwYLKoZIhvcNAQkQAgwxHDAaMBgwFgQUcrz9oBB/STSwBxxhD+bX
# llAAmHcwNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgMvPjsb2i17JtTx0bjN29j4uE
# dqF4ntYSzTyqep7/NcIwPwYJKoZIhvcNAQkEMTIEMDZEV8OIIJcfom2P+pHFuH4J
# q/haBajvFasTiMhN7fzr6PtnIILEfHwWXPPcjp/02TANBgkqhkiG9w0BAQEFAASC
# AgBRFs+zixLs3jP6urd9jZtXIIKiT9XzwIW6ZtRiWFoux9R8cZ78EfOW+2oEnuWH
# ijLfUbtki1i9Tyrsd8V4N8FhmuMhlAy/U49aATjBRVwIFhnVC+u4RsVRbzr+u2u8
# WAArApdpNP8HnG3/f4PyPWzQHeuF8N7GoJt0/HSnitPzLDnC+ukEBs53lb/fhXVs
# TCO83z0LwRCN2ChMSDIy+1RzZE0tBSkKV21EA6PJ4MB5szdlyGr9KgQtaEvhWDT4
# s6xhsipSfYRQ98yToQHZ16hvCIicojqao7wf4fDweJZRwocvr91/aT+mNusW9Jeo
# NNfdYx8eLjtsxIis+hGfrXvFY/Cyhc+wSeqhfJ4wZzb52KJkAI+eI6WY9RQSG+wT
# TgdrynOA1vWeOX0G7Df6kKAcOcyMr0jNJLPPzyLtcM6bPQIxXMZ4j765FCiK+z1e
# wf/TuWPW/6I/F1+nPXUlnRJEYAUCkWizEQXs6gv6dYBu+DdCEoEQURaSegS3vmc1
# 1Se/GXdbn+85bg9YzsxEP2t4p/3EjVdpLMdlewNWLtwIPqwICJ5dO3AMr68YtSw0
# +VbAwtqwgbfuZrLMMoDMfFGtdNpuFnC2Dkh1gZokTd0MeZO5h9tVpqQsX3z1E1YD
# 6ZwKueTyf5rGfukNitxNlH8rVwN0kZ/Nlypixl2Ax7jU/w==
# SIG # End signature block
