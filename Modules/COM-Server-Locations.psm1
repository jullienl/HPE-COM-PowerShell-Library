#------------------- FUNCTIONS FOR COMPUTE OPS MANAGEMENT SERVER LOCATIONS -----------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1

# Get-HPECOMServerLocation is an alias of Get-HPEGLLocation
Set-Alias -Name Get-HPECOMServerLocation -Value Get-HPEGLLocation


# Public functions
Function Set-HPECOMOneViewServerLocation {
    <#
    .SYNOPSIS
    Configure the server location for HPE OneView managed servers.

    .DESCRIPTION
    This Cmdlet assigns an a location that exists in HPE GreenLake to HPE OneView managed servers. 
    
    Assigning a location enhances the data visible in Compute Ops Management sustainability reports and the HPE Sustainability Insight Center.

    For non-HPE OneView servers, use 'Set-HPEGLDeviceLocation'.
    
    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.)
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.

    .PARAMETER LocationName
    Specifies the name of the location to assign to the server.
    
    .PARAMETER ServerName
    Specifies the name of the server.
    
    .PARAMETER ServerSerialNumber
    Specifies the serial number of the server.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.

    .EXAMPLE
    Set-HPECOMOneViewServerLocation -Region eu-central -LocationName "Mougins" -ServerSerialNumber CN12312312

    Assign the location named 'Mougins' to the server with the serial number 'CN12312312' in the central EU region.

    .EXAMPLE
    Set-HPECOMOneViewServerLocation -Region eu-central -LocationName "Mougins" -ServerName RHEL-1
    
    Assign the location named 'Mougins' to the server named 'RHEL-1' in the central EU region.

    .EXAMPLE
    'CN12312312', 'CN12312313', 'CN12312314' |  Set-HPECOMOneViewServerLocation -Region eu-central  -LocationName "Mougins" 

    Assign the location named 'Mougins' to the servers with the serial numbers 'CN12312312', 'CN12312313', and 'CN12312314' in the central EU region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -ConnectionType 'OneView managed' | Set-HPECOMOneViewServerLocation -LocationName "Mougins" 
    
    Assign the location named 'Mougins' to all HPE OneView managed servers in the central EU region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Model 'Synergy 480 Gen11' | Set-HPECOMOneViewServerLocation -LocationName "Mougins"

    Assign the location named 'Mougins' to all HPE OneView managed servers with the model 'Synergy 480 Gen11' in the central EU region.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.    
    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Server - Serial number or name of the server
        * Region - Name of the region where the server is located
        * Location - Name of the location assigned to the server
        * Status - Status of the assignment attempt (Failed for http error return; Complete if assignment is successful; Warning if no action is needed) 
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.
    
   #>

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 
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

        [Parameter (Mandatory)]
        [String]$LocationName,

        [Parameter (Mandatory, ParameterSetName = 'Name')]
        [String]$ServerName,
    
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SerialNumber')]
        [Alias('serialNumber')]
        [String]$ServerSerialNumber,

        [Switch]$WhatIf
       
    ) 
    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $ObjectStatusList = [System.Collections.ArrayList]::new()
        $DevicesList = [System.Collections.ArrayList]::new()
        $DevicesTrackingList = [System.Collections.ArrayList]::new()

        try {
            $Location = Get-HPEGLLocation -Name $LocationName
            $Uri = (Get-COMServerLocationsUri) + "/" + $Location.ID + "/servers"
           
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        if ( -not $Location) {

            $ErrorMessage = "Location '{0}': Resource cannot be found in the '{1}' region!" -f $LocationName, $Region
            throw $ErrorMessage

        }
        
    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        # Build object for the output
        $objStatus = [pscustomobject]@{

            Server    = if ($ServerSerialNumber) { $ServerSerialNumber } else { $ServerName }
            Region    = $Region     
            Location  = $LocationName                       
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

        [void] $ObjectStatusList.add($objStatus)
    
    }
    
    End {


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
        
        
        "[{0}] List of servers to add to location: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList.SerialNumber | out-string) | Write-Verbose


        foreach ($Object in $ObjectStatusList) {

            $Server = $Servers | Where-Object serialNumber -eq $Object.server
            
            if (-not $Server) {
                $Server = $Servers | Where-Object serverName -eq $Object.server
            }
            
            #  Condition when serverName is used and when multiple servers use the same serverName 
            if ( $server -and $Server.id.count -gt 1) {

                # Must return a message if device not found
                $Object.Status = "Failed"
                $Object.Details = "Server was found multiple times in the Compute Ops Management instance! Please refine your query to return a single server resource."

                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}' was found multiple times in the Compute Ops Management instance! Please refine your query to return a single server resource." -f $Object.server
                    Write-warning $ErrorMessage
                    continue
                }
            }
            elseif ( $server -and $Server.connectionType -ne "OneView") {

                # Must return a message if device not OneView server
                $Object.Status = "Failed"
                $Object.Details = "Server is not an HPE OneView managed server! For non-HPE OneView servers, use 'Set-HPEGLDeviceLocation'"

                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}' is not an HPE OneView managed server! For non-HPE OneView servers, use 'Set-HPEGLDeviceLocation'" -f $Object.server
                    Write-warning $ErrorMessage
                    continue
                }

            } 
            elseif ( -not $Server) {

                # Must return a message if device not found
                $Object.Status = "Failed"
                $Object.Details = "Server cannot be found in the region!"

                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}': Resource cannot be found in the '{1}' region!" -f $Object.server, $Region
                    Write-warning $ErrorMessage
                    continue
                }

            } 
            else {       
            
                $ServerLocation = Get-HPECOMServer -Region $Region -Name $server.serialnumber -ShowLocation

                if ($ServerLocation.LocationName) {   
                    # Must return a message if server already member of a location
                    $Object.Status = "Warning"
                    $Object.Details = "Server is already assigned to the '$($ServerLocation.LocationName)' location!"

                    if ($WhatIf) {
                        $ErrorMessage = "Server '{0}': Resource is already assigned to the '{1}' location!" -f $Object.server, $ServerLocation.LocationName
                        Write-warning $ErrorMessage
                        continue
                    }

                }
                else {

                    # Build DeviceInfo object for tracking
                    $DeviceInfo = [PSCustomObject]@{
                        serialnumber = $server.serialNumber
                        servername   = $server.serverName
                        
                    }
                    
                    Write-Verbose "Server serialNumber: $($server.serialNumber)"
                    Write-Verbose "Server ID: $($server.id)"
                    
                    # Building the list of devices object for payload
                    [void]$DevicesList.Add($($Server.id))
    
                    # Building the list of devices object for tracking
                    [void]$DevicesTrackingList.Add($DeviceInfo)

                }
            }
        }


        if ($DevicesList) {

            # Build payload
            $payload = ConvertTo-Json -Depth 10 @{
                servers = $DevicesList
            } 

        
            # Add Devices to location  
            try {

                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method POST -Body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                
                if (-not $WhatIf) {
                   
                    foreach ($Object in $ObjectStatusList) {

                        $DeviceSet = $DevicesTrackingList | Where-Object { $_.serialnumber -eq $Object.Server -or $_.servername -eq $Object.Server }

                        If ($DeviceSet) {
                            
                            $Object.Status = "Complete"
                            $Object.Details = "Location successfully assigned to server"

                        }
                    }
                }
            }
            catch {
                
                if (-not $WhatIf) {

                    foreach ($Object in $ObjectStatusList) {

                        $DeviceSet = $DevicesTrackingList | Where-Object { $_.serialnumber -eq $Object.Server -or $_.servername -eq $Object.Server }

                        If ($DeviceSet) {
                            
                            $Object.Status = "Failed"
                            $Object.Details = "Location cannot be assigned to server!"
                            $Object.Exception = $_.Exception.message 

                        }
                    }
                }
            }
        }
        

        if (-not $WhatIf ) {
            
            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "Location.SeLSDE"
            Return $ObjectStatusList
        
        }

    }
}

Function Remove-HPECOMOneViewServerLocation {
    <#
    .SYNOPSIS
    Remove location of one or more servers managed by HPE OneView.

    .DESCRIPTION
    This Cmdlet unassigns an HPE GreenLake location from HPE OneView managed server(s). 

    For non-HPE OneView servers, use `Remove-HPEGLDeviceLocation`.
    
    .PARAMETER Region     
    Specifies the region code of a Compute Ops Management instance provisioned in the workspace (e.g., 'us-west', 'eu-central', etc.)
    This mandatory parameter can be retrieved using 'Get-HPEGLService -Name "Compute Ops Management" -ShowProvisioned' or 'Get-HPEGLRegion -ShowProvisioned'.

    Auto-completion (Tab key) is supported for this parameter, providing a list of region codes provisioned in your workspace.
    
    .PARAMETER ServerName
    Specifies the name of the server.
    
    .PARAMETER ServerSerialNumber
    Specifies the serial number of the server.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to COM instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by COM.
   
    .EXAMPLE
    Remove-HPECOMOneViewServerLocation -Region eu-central -ServerSerialNumber CN12312312
    
    Remove the location of the server with the serial number 'CN12312312' in the central EU region.

    .EXAMPLE
    Remove-HPECOMOneViewServerLocation -Region eu-central -ServerName RHEL-1

    Remove the location of the server named 'RHEL-1' in the central EU region.

    .EXAMPLE
    'CN12312312', 'CN12312313', 'CN12312314' |  Remove-HPECOMOneViewServerLocation -Region eu-central

    Remove the location of the servers with the serial numbers 'CN12312312', 'CN12312313', and 'CN12312314' in the central EU region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -ConnectionType 'OneView managed' | Remove-HPECOMOneViewServerLocation

    Remove the location of all HPE OneView managed servers in the central EU region.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -Model 'Synergy 480 Gen11' | Remove-HPECOMOneViewServerLocation

    Remove the location of all HPE OneView managed servers with the model 'Synergy 480 Gen11' in the central EU region.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the server's serial numbers.
    System.Collections.ArrayList
        List of servers from 'Get-HPECOMServer'.
    
    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Server - Serial number or name of the server
        * Region - Name of the region where the server is located
        * Location - Name of the location assigned to the server
        * Status - Status of the assignment attempt (Failed for http error return; Complete if assignment is successful; Warning if no action is needed) 
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.

   #>

   
    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 
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

        [Parameter (Mandatory, ParameterSetName = 'Name')]
        [String]$ServerName,
    
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName, ParameterSetName = 'SerialNumber')]
        [Alias('serialNumber')]
        [String]$ServerSerialNumber,

        [Switch]$WhatIf
       
    ) 
    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $ObjectStatusList = [System.Collections.ArrayList]::new()
        $DevicesList = [System.Collections.ArrayList]::new()
        $DevicesTrackingList = [System.Collections.ArrayList]::new()

                
    }

    Process {

        "[{0}] Bound PS Parameters: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
        
        # Build object for the output
        $objStatus = [pscustomobject]@{

            Server    = if ($ServerSerialNumber) { $ServerSerialNumber } else { $ServerName }
            Region    = $Region     
            Location  = $Null                       
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }

        [void] $ObjectStatusList.add($objStatus)
    
    }
    
    End {

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
        
        
        "[{0}] List of servers where to remove the location: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList.SerialNumber | out-string) | Write-Verbose


        foreach ($Object in $ObjectStatusList) {

            $Server = $Servers | Where-Object serialNumber -eq $Object.server
            
            if (-not $Server) {
                $Server = $Servers | Where-Object serverName -eq $Object.server
            }
            

            #  Condition when serverName is used and when multiple servers use the same serverName 
            if ( $server -and $Server.id.count -gt 1) {

                # Must return a message if device not found
                $Object.Status = "Failed"
                $Object.Details = "Server was found multiple times in the Compute Ops Management instance! Please refine your query to return a single server resource."

                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}' was found multiple times in the Compute Ops Management instance! Please refine your query to return a single server resource." -f $Object.server
                    Write-warning $ErrorMessage
                    continue
                }
            }
            elseif ( $server -and $Server.connectionType -ne "OneView") {

                # Must return a message if device not OneView server
                $Object.Status = "Failed"
                $Object.Details = "Server is not an HPE OneView managed server! For non-HPE OneView servers, use 'Set-HPEGLDeviceLocation'"

                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}' is not an HPE OneView managed server! For non-HPE OneView servers, use 'Set-HPEGLDeviceLocation'" -f $Object.server
                    Write-warning $ErrorMessage
                    continue
                }

            } 
            elseif ( -not $Server) {

                # Must return a message if device not found
                $Object.Status = "Failed"
                $Object.Details = "Server cannot be found in the Compute Ops Management instance!"

                if ($WhatIf) {
                    $ErrorMessage = "Server '{0}' cannot be found in the Compute Ops Management instance!" -f $Object.server
                    Write-warning $ErrorMessage
                    continue
                }

            } 
            else {       
            
                $ServerLocation = Get-HPECOMServer -Region $Region -Name $server.serialnumber -ShowLocation

                if (-not $ServerLocation.LocationName) {   
                    # Must return a message if server is not member of the location
                    $Object.Status = "Warning"
                    $Object.Details = "Server is not assigned to a location!"

                    if ($WhatIf) {
                        $ErrorMessage = "Server '{0}': Resource not assigned to a location" -f $Object.server
                        Write-warning $ErrorMessage
                        continue
                    }

                }
                else {

                    $Object.Location = $ServerLocation.name 

                    # Build DeviceInfo object for tracking
                    $DeviceInfo = [PSCustomObject]@{
                        serialnumber = $server.serialNumber
                        servername   = $server.serverName
                        
                    }
                    
                    Write-Verbose "Server serialNumber: $($server.serialNumber)"
                    Write-Verbose "Server ID: $($server.id)"
                    
                    # Building the list of devices object for payload
                    [void]$DevicesList.Add($($Server.id))
    
                    # Building the list of devices object for tracking
                    [void]$DevicesTrackingList.Add($DeviceInfo)

                }
            }
        }


        if ($DevicesList) {

            "[{0}] List of IDs to add to query: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($DevicesList | out-string) | Write-Verbose


            # Build the query string
            $queryString = ($DevicesList | ForEach-Object { "id=$_" }) -join "&"
            $queryString = "?$queryString"

            # ID uses a '+' sign, it needs to be replaced with '%2B' to avoid 404 resource not found error 
            # (URL encoding not working: $encodedQueryString = [System.Web.HttpUtility]::UrlEncode($queryString) )
            $encodedQueryString = $queryString.replace('+', '%2B')

            $Uri = (Get-COMServerLocationsUri) + "/" + $ServerLocation.locationId + "/servers" + $encodedQueryString
       
            # Remove Devices to location  
            try {

                $Response = Invoke-HPECOMWebRequest -Region $Region -Uri $Uri -method DELETE -Body $payload -ContentType "application/json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                
                if (-not $WhatIf) {
                   
                    foreach ($Object in $ObjectStatusList) {

                        $DeviceSet = $DevicesTrackingList | Where-Object { $_.serialnumber -eq $Object.Server -or $_.servername -eq $Object.Server }

                        If ($DeviceSet) {
                            
                            $Object.Status = "Complete"
                            $Object.Details = "Location successfully unassigned from server"

                        }
                    }
                }
            }
            catch {
                
                if (-not $WhatIf) {

                    foreach ($Object in $ObjectStatusList) {

                        $DeviceSet = $DevicesTrackingList | Where-Object { $_.serialnumber -eq $Object.Server -or $_.servername -eq $Object.Server }

                        If ($DeviceSet) {
                            
                            $Object.Status = "Failed"
                            $Object.Details = "Location cannot be unassigned from server!"
                            $Object.Exception = $_.Exception.message 

                        }
                    }
                }
            }
        }
        

        if (-not $WhatIf ) {

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "Location.SeLSDE"
            Return $ObjectStatusList
        
        }

    }
}


# Private functions (not exported)
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


# Export only public functions and aliases
Export-ModuleMember -Function 'Set-HPECOMOneViewServerLocation', 'Remove-HPECOMOneViewServerLocation' -Alias *


# SIG # Begin signature block
# MIIunwYJKoZIhvcNAQcCoIIukDCCLowCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCBmyt7mHWRz53ne
# dSW+ibcCNuuIqUZGgJitB0f2xZIVwKCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQgZguhJficmYXJwwzxOZTRZRWdi6yId7VVDwX66TaPNFIwDQYJKoZIhvcNAQEB
# BQAEggIAefqXPTKX8LeHrKIz7o2+xWZqo3OlLB5Q3JEpgCc8zWaOdGIjn5hBGsn0
# xwV8UmAqN7fHt1EPBA2Nglo7YHfpaO/B1+hs6aHGRY5ru78i02RfG7niEg+K2zIf
# L9Iuh0OS+5Rq53o1Isqk9gAopnFTF2cPCfP/bPsFagGN0Be0IrOV97uf6viOReRB
# vOb1n+kPCbVFWVi3PnD0bn3mxo1cfUA9p2NK3areInEiX+Uj5wcTMBh9cFqNtNoo
# aswDn7DPjAtjnhLndJvo2fTT9nRBMKiEtfGUzBxWbTlhgSoqIFM30tv36m/cbfxZ
# ZYjIYZ51i6+HyF5sJJOVDUbjXiZewW6WA9PJ8/YJkbgQUPulwE2NoT2xSUQZqBBt
# Fwr/Hn/uoPtElx+xoZZbEoAQ4HKdz21QJ3nW3BcbBFii0tI3MOzzWqESi16oEoLe
# YEoujp1bVjtyBhbVvASC566qbPgiCdkjn1iqwYI1TAQTw7leuFJNU9LL/uCdhSGA
# btm3w9Y/8fire7IqaIZNSwGLcCCgrRpc1cqtPy+fltI4/ZRE+5vB0WhhUdGMW/pT
# iCiVkg5Lq8DrtJl9D3b6Dvs5LjWATZnw1jlw+xgzGVoCHmu795ktKk1aDuev9pZK
# Un0Q1QDQti3X8+XLDCd5FydOv9zXoNB/40kXCMkLbYQIxW9F8PuhghjpMIIY5QYK
# KwYBBAGCNwMDATGCGNUwghjRBgkqhkiG9w0BBwKgghjCMIIYvgIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBCAYLKoZIhvcNAQkQAQSggfgEgfUwgfICAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQwGNgl0xSCRdRdIGbtUKsWk0Wxvsp0KHifTkdz
# Bo99f0r7cQFjtM0n2BlqtX7ZtXOaAhUAiQDhkEPcoZa4SsVSigEiWpMoOVYYDzIw
# MjUxMDAyMTU0ODI1WqB2pHQwcjELMAkGA1UEBhMCR0IxFzAVBgNVBAgTDldlc3Qg
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
# MQ8XDTI1MTAwMjE1NDgyNVowPwYJKoZIhvcNAQkEMTIEMJTqcm6cRS8KWw19t59b
# QtcltAkoND5T4Qfl7TiUQf75I4aMicx47nFxbsVW6oxtTDCCAXoGCyqGSIb3DQEJ
# EAIMMYIBaTCCAWUwggFhMBYEFDjJFIEQRLTcZj6T1HRLgUGGqbWxMIGHBBTGrlTk
# eIbxfD1VEkiMacNKevnC3TBvMFukWTBXMQswCQYDVQQGEwJHQjEYMBYGA1UEChMP
# U2VjdGlnbyBMaW1pdGVkMS4wLAYDVQQDEyVTZWN0aWdvIFB1YmxpYyBUaW1lIFN0
# YW1waW5nIFJvb3QgUjQ2AhB6I67aU2mWD5HIPlz0x+M/MIG8BBSFPWMtk4KCYXzQ
# kDXEkd6SwULaxzCBozCBjqSBizCBiDELMAkGA1UEBhMCVVMxEzARBgNVBAgTCk5l
# dyBKZXJzZXkxFDASBgNVBAcTC0plcnNleSBDaXR5MR4wHAYDVQQKExVUaGUgVVNF
# UlRSVVNUIE5ldHdvcmsxLjAsBgNVBAMTJVVTRVJUcnVzdCBSU0EgQ2VydGlmaWNh
# dGlvbiBBdXRob3JpdHkCEDbCsL18Gzrno7PdNsvJdWgwDQYJKoZIhvcNAQEBBQAE
# ggIAlRe5iXmKTqFQ9rntUZqc5Ydtvfz5AtLdfQMhnkxHY/j8t91OUyYTdbsg321R
# z1myuWgzGLyP5s0CsGexqgN/tw/oplJjd+xzCeBIp6Wykrz1PeZ/QL4NlgFgiujg
# pkbzIS7LWPZGSlq9iOTPrWIDcUcZkoKVI6pFXwOWS9Lj4YhXFQSNEK+CQvg/13CL
# z0dAra+MwVoXk8fmG/rQAV37dRBCdB08llqAmBGr0H3ORH2jfzQjkcJoFV8SYa23
# EZeFY5txGfYPJiwgIZWw8QNb2o0pplTYBVjUOFWbNnFsc5bXqXT15sH4nq4K99CS
# pOu+KCqGf9wLvnaPUFdfHE9Y8gTIz929JDvdbdR5HpXk5yuxVY0FIycXFnpqCPoz
# GgAwjyXiR18E1MbrseIvWj1NV1ZVQD59gn4DKoBmovp/hqYzPk3sM3VmgBcG1aib
# gsi/tv7FnP7YScCHfQMC+LdleD3n+c5utzEStfXt+ke9xsq9PpTxEqWPSkCJuYu7
# 3CpuRhPOQLcHLEaZxZPwazT1TGtGnS5l1RQi6MbN4vELBG8z0yjzWltWKVur+vLt
# 2X+dYPREn78k22w/Oj4aYutf1da8B8FkppGNUtwRYofmI7TcgX1CmJbi6uIlffUc
# mM0tJrtOSyxeE7SdxZAu7UOK3BifgKicJ3UT0HyYxS+FhwU=
# SIG # End signature block
