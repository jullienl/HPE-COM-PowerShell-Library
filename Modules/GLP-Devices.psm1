#------------------- FUNCTIONS FOR HPE GreenLake DEVICES-----------------------------------------------------------------------------------------------------------------------------------------------

using module .\Constants.psm1

# Public functions
Function Get-HPEGLDevice {
    <#
    .SYNOPSIS
    Retrieve device resource(s).

    .DESCRIPTION
    This Cmdlet returns a collection of device resources, or specific devices with specified parameters such as serial numbers, names, part numbers, etc. 

    .PARAMETER Name
    Specifies the device name, serial number, or iLO name of the devices to display. You can provide any of these identifiers to retrieve matching device resources.

    .PARAMETER PartNumber
    Specifies the part number of the devices to display.

    .PARAMETER ShowRequireAssignment
    Optional parameter to display devices that lack a service assignment.

    .PARAMETER ShowRequireSubscription
    Optional parameter to display devices that do not have a subscription tier.

    .PARAMETER ShowComputeReadyForCOMIloConnection
    Optional parameter to display devices that are ready for an iLO connection to a Compute Ops Management instance.

    .PARAMETER ShowArchived
    Optional parameter to display only archived devices.

    .PARAMETER ShowNotArchived 
    Optional parameter to hide archived devices.

    .PARAMETER FilterByDeviceType
    Specifies the device type, such as STORAGE, COMPUTE, or SWITCH.

    .PARAMETER Location
    Specifies the name of the physical location to filter devices assigned to that location.

    .PARAMETER ServiceDeliveryName
    Specifies the service delivery contact's name or email address to filter devices assigned to that contact.

    .PARAMETER ShowTags
    Optional parameter to display device tags along with key device information in a simplified view.

    .PARAMETER Limit
    Defines the number of devices to be displayed.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. Useful for understanding the inner workings of the native REST API calls.

    .EXAMPLE
    Get-HPEGLdevice

    Return all device resources.

    .EXAMPLE
    Get-HPEGLdevice -SerialNumber CN70490RXP

    Return the device resource with the serial number "CN70490RXP".

    .EXAMPLE
    Get-HPEGLdevice -Name CN70490RXP

    Return the device resource with the serial number "CN70490RXP".

    .EXAMPLE
    Get-HPEGLdevice -Name ESX-002.lab

    Return the device resource with the name "ESX-002.lab".

    .EXAMPLE
    Get-HPEGLdevice -PartNumber "P38471-B21"

    Return all device resources with the part number "P38471-B21".

    .EXAMPLE
    Get-HPEGLdevice -FilterByDeviceType STORAGE

    Return all device resources with the device type "STORAGE".

    .EXAMPLE
    Get-HPEGLdevice -Location "Houston-Datacenter"

    Return all device resources assigned to the "Houston-Datacenter" location.

    .EXAMPLE
    Get-HPEGLdevice -ShowRequireAssignment 

    Return all device resources that require a service assignment.

    .EXAMPLE
    Get-HPEGLDevice -ShowComputeReadyForCOMIloConnection

    Return all compute device resources that are ready to connect to a Compute Ops Management instance using 'Connect-HPEGLDeviceComputeiLOtoCOM'.

    .EXAMPLE
    Get-HPEGLdevice -ShowRequireSubscription -ShowRequireAssignment

    Return all device resources that require both a subscription and a service assignment.

    .EXAMPLE
    Get-HPEGLDevice -ShowArchived

    Return all archived devices.

    .EXAMPLE
    Get-HPEGLdevice -Limit 200

    Return the first 200 device resources.

    .EXAMPLE
    "J12345605X", "J13134413T", "J21233335W", "J2123333S" | Get-HPEGLdevice

    Return all devices matching the given serial numbers from the pipeline.

    .EXAMPLE
    Get-HPECOMServer -Region us-west -ConnectionType Direct | Get-HPEGLdevice 

    Retrieve a list of HPE COM servers from the 'us-west' region with a direct connection type (not OneView) and then get the corresponding devices.
    This example demonstrates how to chain the output of 'Get-HPECOMServer' to 'Get-HPEGLdevice'.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects representing the device's serial numbers.
    System.Collections.ArrayList
        List of device(s) from 'Get-HPECOMServer'.

    .OUTPUTS
    HPE.GreenLake.Device[]
        A typed array of device objects, or HPE.GreenLake.Device.Tags[] when -ShowTags is used.

    #>

    [CmdletBinding(DefaultParameterSetName = 'NotArchived')]
    Param( 

        [Parameter (ParameterSetName = 'Archived', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter (ParameterSetName = 'NotArchived', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias ('SerialNumber')]
        [String]$Name, 
        
        [Parameter (ParameterSetName = 'Archived')]
        [Parameter (ParameterSetName = 'NotArchived')]
        [ValidateNotNullOrEmpty()]
        [String]$PartNumber, 

        [Parameter (ParameterSetName = 'Archived')]
        [Parameter (ParameterSetName = 'NotArchived')]
        [Switch]$ShowRequireAssignment,

        [Parameter (ParameterSetName = 'Archived')]
        [Parameter (ParameterSetName = 'NotArchived')]
        [Switch]$ShowRequireSubscription,

        [Parameter (ParameterSetName = 'Archived')]
        [Parameter (ParameterSetName = 'NotArchived')]
        [Switch]$ShowComputeReadyForCOMIloConnection,


        [Parameter (ParameterSetName = 'Archived')]
        [Switch]$ShowArchived,

        [Parameter (ParameterSetName = 'NotArchived')]
        [Switch]$ShowNotArchived,

        [Parameter (ParameterSetName = 'Archived')]
        [Parameter (ParameterSetName = 'NotArchived')]
        [ValidateNotNullOrEmpty()]
        [ValidateSet('ACCESS POINT', 'GATEWAY', 'SERVER', 'STORAGE', 'SWITCH')]
        [String]$FilterByDeviceType,

        [Parameter (ParameterSetName = 'Archived')]
        [Parameter (ParameterSetName = 'NotArchived')]
        [ValidateNotNullOrEmpty()]
        [String]$Location,
        
        [Parameter (ParameterSetName = 'Archived')]
        [Parameter (ParameterSetName = 'NotArchived')]
        [ValidateNotNullOrEmpty()]
        [Alias ('ServiceDeliveryEmail')]
        [String]$ServiceDeliveryName,
        
        [Parameter (ParameterSetName = 'Archived')]
        [Parameter (ParameterSetName = 'NotArchived')]
        [Switch]$ShowTags,

        [Parameter (ParameterSetName = 'Archived')]
        [Parameter (ParameterSetName = 'NotArchived')]
        [int]$Limit,
        
        [Switch]$WhatIf
       
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose


        # Set URI
        if ($Name) {
            # Filter supports serial numbers, iLO names and server names; parentheses required when additional filters are appended with 'and'
            $Uri = (Get-DevicesUri) + "?filter=(secondaryName eq '$Name' or deviceName eq '$Name' or serialNumber eq '$Name')"
        }
        else {

            $Uri = Get-DevicesUri

        }   
        Write-Verbose ("[{0}] Initial URI: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri)
                
        if ($PSBoundParameters.ContainsKey('FilterByDeviceType')) {

            # "ALS","AP","BLE","COMPUTE","CONTROLLER","DHCI_COMPUTE","DHCI_STORAGE","EINAR","EINR","GATEWAY","IAP","LTE_MODEM","MC","STORAGE","SWITCH","NW_THIRD_PARTY","PCE","SD_WAN_GW","OPSRAMP_SAAS","SD_SAAS","SENSOR","BRIDGES","UNKNOWN"

            switch ($FilterByDeviceType) {
                "ACCESS POINT" { $_DeviceType = "AP" }
                "GATEWAY" { $_DeviceType = "GATEWAY" }
                "SERVER" { $_DeviceType = "COMPUTE" }
                "STORAGE" { $_DeviceType = "STORAGE" }
                "SWITCH" { $_DeviceType = "SWITCH" }
            }


            if ($Uri -match "\?filter=" ) {
                $Uri = $Uri + " and deviceType eq '$_DeviceType'"
            }
            else {
                $Uri = $Uri + "?filter=deviceType eq '$_DeviceType'"
            }
        }

        if ($PSBoundParameters.ContainsKey('PartNumber')) {
            if ($Uri -match "\?filter=" ) {
                $Uri = $Uri + " and partNumber eq '$PartNumber'"
            }
            else {
                $Uri = $Uri + "?filter=partNumber eq '$PartNumber'"
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
           
        try {

            "[{0}] Collecting device data using public API..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

            [Array]$AllCollection = Invoke-HPEGLWebRequest -Method GET -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

            # Adding UI Doorway device API to get missing data (e.g. location, service name, subscription, etc.)
            "[{0}] Collecting device data using UI-Doorway API to collect missing content..." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

            $UriUIDoorway = (Get-DevicesUIDoorwayUri) + "/filter"
            
            if ($Name) {

                $body = @{
                    unassigned_only    = $false
                    archive_visibility = "ALL"
                    include_quantity   = $true
                    include_config     = $true
                    include_warranty   = $true
                    serial_number      = $Name
                } | ConvertTo-Json 
                
            }
            else {
       
                $body = @{
                    unassigned_only    = $false
                    archive_visibility = "ALL"
                    include_quantity   = $true
                    include_config     = $true
                    include_warranty   = $true
                } | ConvertTo-Json 
            }                

            [Array]$AllCollectionUIDoorWay = Invoke-HPEGLWebRequest -Method POST -Uri $UriUIDoorway -Body $Body -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
            $AllCollectionUIDoorWay = $AllCollectionUIDoorWay.devices

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }
           
        if ($Null -ne $AllCollection) {     

            $CollectionList = $AllCollection 

            Write-Verbose ("[{0}] Enriching device data with additional properties..." -f $MyInvocation.InvocationName.ToString().ToUpper())

            # Build a hashtable for O(1) UI-Doorway lookups by resource_id
            $UIDoorwayIndex = @{}
            foreach ($d in $AllCollectionUIDoorWay) {
                if ($d.resource_id) { $UIDoorwayIndex[$d.resource_id] = $d }
            }

            # Single enrichment pass — all properties set from one hashtable lookup per device
            foreach ($device in $CollectionList) {

                # serverName
                $device | Add-Member -Type NoteProperty -Name serverName -Value $(if ($device.secondaryName) { $device.secondaryName } else { $device.serialNumber }) -Force

                # iLOName
                if ($device.deviceName) {
                    $device | Add-Member -Type NoteProperty -Name iLOName -Value $device.deviceName -Force
                }

                $ui = if ($device.id) { $UIDoorwayIndex[$device.id] } else { $null }

                # location
                if ($ui -and $ui.location_name) {
                    if (-not $device.PSObject.Properties.Match('location') -or $null -eq $device.location) {
                        $device | Add-Member -Type NoteProperty -Name location -Value ([PSCustomObject]@{}) -Force
                    }
                    $device.location | Add-Member -Type NoteProperty -Name name          -Value $ui.location_name  -Force
                    $device.location | Add-Member -Type NoteProperty -Name streetAddress -Value $ui.streetAddress   -Force
                    $device.location | Add-Member -Type NoteProperty -Name country       -Value $ui.country        -Force
                    $device.location | Add-Member -Type NoteProperty -Name city          -Value $ui.city           -Force
                    $device.location | Add-Member -Type NoteProperty -Name postalCode    -Value $ui.postalCode     -Force
                    $device.location | Add-Member -Type NoteProperty -Name state         -Value $ui.state          -Force
                }

                # application
                if ($ui -and $ui.application_name) {
                    if (-not $device.PSObject.Properties.Match('application') -or $null -eq $device.application) {
                        $device | Add-Member -Type NoteProperty -Name application -Value ([PSCustomObject]@{}) -Force
                    }
                    $device.application | Add-Member -Type NoteProperty -Name name   -Value $ui.application_name -Force
                    $device.application | Add-Member -Type NoteProperty -Name region -Value $device.region        -Force
                }

                # warranty
                if ($ui -and $ui.support_state) {
                    if (-not $device.PSObject.Properties.Match('warranty') -or $null -eq $device.warranty) {
                        $device | Add-Member -Type NoteProperty -Name warranty -Value ([PSCustomObject]@{}) -Force
                    }
                    if ($ui.support_level) {
                        $device.warranty | Add-Member -Type NoteProperty -Name supportLevel -Value $ui.support_level -Force
                    }
                    $device.warranty | Add-Member -Type NoteProperty -Name supportState -Value $ui.support_state -Force
                    if ($ui.support_end_date) {
                        $endTime = [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$ui.support_end_date).DateTime
                        $device.warranty | Add-Member -Type NoteProperty -Name endTime -Value $endTime -Force
                    }
                    else {
                        $device.warranty | Add-Member -Type NoteProperty -Name endTime -Value $ui.support_end_date -Force
                    }
                }

                # subscription
                if ($ui -and $ui.subscriptions -and $ui.subscriptions.Count -gt 0) {
                    if (-not $device.PSObject.Properties.Match('subscription') -or $null -eq $device.subscription) {
                        $device | Add-Member -Type NoteProperty -Name subscription -Value ([PSCustomObject]@{}) -Force
                    }
                    $device.subscription | Add-Member -Type NoteProperty -Name key   -Value $ui.subscriptions[0].key  -Force
                    $device.subscription | Add-Member -Type NoteProperty -Name tier  -Value $ui.subscriptions[0].tier -Force
                    if ($ui.subscriptions[0].end_date) {
                        $endTime = [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$ui.subscriptions[0].end_date).DateTime
                        $device.subscription | Add-Member -Type NoteProperty -Name endTime -Value $endTime -Force
                    }
                    else {
                        $device.subscription | Add-Member -Type NoteProperty -Name endTime -Value $ui.subscriptions[0].end_date -Force
                    }
                    $device.subscription | Add-Member -Type NoteProperty -Name quantity           -Value $ui.subscriptions[0].quantity           -Force
                    $device.subscription | Add-Member -Type NoteProperty -Name available_quantity -Value $ui.subscriptions[0].available_quantity -Force
                }

                # serviceDelivery
                $device | Add-Member -Type NoteProperty -Name serviceDelivery -Value ([PSCustomObject]@{
                        name  = $(if ($ui) { $ui.contact_name } else { $null })
                        email = $(if ($ui) { $ui.contact_id }   else { $null })
                    }) -Force
            }

            # iLOIPAddress cannot be added to object as not present


            if ($ShowRequireAssignment) {

                $CollectionList = $CollectionList | Where-Object { $_.assignedState -eq "UNASSIGNED" }

            }   

            if ($ShowRequireSubscription) {

                $CollectionList = $CollectionList | Where-Object { -not $_.subscription.key }

            }   

            if ($ShowComputeReadyForCOMIloConnection) {

                $CollectionList = $CollectionList | Where-Object { $_.application.name -eq "Compute Ops Management" -and $_.subscription.key }

            }                   

            if ($ShowArchived) {

                $CollectionList = $CollectionList | Where-Object { $_.archived }

            }   

            if ($ShowNotArchived) {

                $CollectionList = $CollectionList | Where-Object { -not $_.archived }

            }   
        
            if ($Location) {

                $CollectionList = $CollectionList | Where-Object { $_.location.name -eq $Location }

            }   

            if ($ServiceDeliveryName) {
                $CollectionList = $CollectionList | Where-Object { $_.serviceDelivery.name -eq $ServiceDeliveryName -or $_.serviceDelivery.email -eq $ServiceDeliveryName }
            }   

            if ($ShowTags) {
                
                # Create simplified objects with tags information
                $TagsCollection = $CollectionList | ForEach-Object {
                    
                    # Format tags as comma-separated string
                    $tagsString = ""
                    if ($_.tags -and $_.tags.PSObject.Properties) {
                        $tagsList = @()
                        foreach ($tag in $_.tags.PSObject.Properties) {
                            $tagsList += "$($tag.Name)=$($tag.Value)"
                        }
                        $tagsString = $tagsList -join ", "
                    }
                    
                    [PSCustomObject]@{
                        Name         = $_.serverName
                        SerialNumber = $_.serialNumber
                        Model        = $_.model
                        PartNumber   = $_.partNumber
                        Service      = $_.application.name
                        Region       = $_.application.region
                        Tags         = $tagsString
                        Location     = $_.location.name
                    }
                }
                
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $TagsCollection -ObjectName "Device.Tags"
                $ReturnData = $ReturnData | Sort-Object Name, SerialNumber
                return $ReturnData
            }
            else {
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $CollectionList -ObjectName "Device"    
                $ReturnData = $ReturnData | Sort-Object { $_.serverName, $_.serialNumber }
                return $ReturnData
            } 
            
        }
        else {

            return
            
        }   
    }
}

Function Add-HPEGLDeviceCompute {
    <#
    .SYNOPSIS
    Add compute device(s) to HPE GreenLake.

    .DESCRIPTION
    This Cmdlet adds compute device(s) to the currently connected HPE GreenLake workspace. It can optionally add tags during the onboarding process. 
    
    Note: Devices to be added must be on the Compute Ops Management supported servers list. For more details, refer to the [supported servers list](https://support.hpe.com/hpesc/public/docDisplay?docId=sd00001293en_us&page=GUID-BC7D1D1B-AE36-4F00-A1FB-C1B9E01DF101).

    .PARAMETER SerialNumber
    Specifies the serial number of the device to be added. This value can be retrieved from the HPE iLO RedFish API.

    .PARAMETER PartNumber
    Specifies the part number of the device to be added. This value can be retrieved from the HPE iLO RedFish API.

    .PARAMETER Tags
    Optional parameter to add tags to the device. Tags must meet the following string format: <Name>=<Value>, <Name>=<Value>.

    Supported tags example:
        - "Country=US"
        - "Country=US,State=TX,App=Grafana" 
        - "Country=US, State =TX ,App= Grafana "
            -> Produces the same result as the previous example.
        - "Private note=this is my tag note value,Email=Chris@email.com,City=New York" 
        - "Private note = this is my tag note value , Email = Chris@email.com , City=New York "
            -> Produces the same result as the previous example.   

    Refer to HPE GreenLake tagging specifications:
    https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us&docLocale=en_US&page=GUID-1E4DDAEA-E799-418F-90C8-30CE6A2873AB.html
        - Resources that support tagging can have up to 25 tags per resource.
        - Tag keys and values are case-insensitive.
        - There can be only one value for a particular tag key for a given resource.
        - Null is not allowed as a possible value for a tag key; instead, an empty string ("") will be supported to enable customers to use tag key-value pairs for labeling.
        - System-defined tags are allowed and start with the prefix "hpe:". User-defined tags cannot start with this prefix.
        - Tag keys must have 1-128 characters.
        - Tag values can have a maximum of 256 characters.
        - Allowed characters include letters, numbers, spaces representable in UTF-8, and the following characters: _ . : + - @.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Add-HPEGLDeviceCompute -SerialNumber "123456789012" -PartNumber "879991-B21" -Tags "Country=US, Hypersior App=ESXi, City=New York"
    
    Adds a compute device to the currently connected HPE GreenLake workspace using a serial number and part number and assigns three tags.

    .EXAMPLE
    Import-Csv Compute_Devices.csv | Add-HPEGLDeviceCompute -Tags "Location=Houston"
    
    Adds all compute devices listed in a `Compute_Devices.csv` file to the currently connected HPE GreenLake workspace and assigns the same location tag to all devices.

    The content of the CSV file must use the following format:
        SerialNumber, PartNumber
        WGX2380BLC, P55181-B21
        DZ12312312, P55182-B21
        CZ12312312, P54277-B21
      
    .EXAMPLE
    Import-Csv .\Compute_Devices_Tags.csv -Delimiter ";"  | Add-HPEGLDeviceCompute  
    
    Adds all compute devices listed in a `Compute_Devices_Tags.csv` file to the currently connected HPE GreenLake workspace and assigns tags as defined in the 'Tags' column of the CSV file.

    The content of the CSV file must use the following format:
        SerialNumber; PartNumber; Tags
        WGX2380BLC; P55181-B21; Country=US, State=CA, App=RH
        EZ12312312; P55182-B21; State=TX, Role=Production
        CZ12312312; P54277-B21
        7LKY2323233LM; P54277-B21; City=New York

        Note that for `CZ12312312`, no tags are assigned in this example.

    .EXAMPLE
    # Example when you don't have the serial numbers and part numbers but only the iLO IP addresses and credentials.

    $iLO_collection = import-csv Private\iLOs.csv -Delimiter ";"  
    Import-Module HPEiLOCmdlets 

    $ComputeDevicesToAdd = @()

    ForEach ($iLO in $iLO_Collection) {
        try {
            $session = Connect-HPEiLO -Address $iLO.IP -username $iLO.Username -password $iLO.Password -DisableCertificateAuthentication -ErrorAction Stop
            $HPEiLOSystemInfo = Get-HPEiLOSystemInfo -Connection $session 

            $SerialNumber = $HPEiLOSystemInfo.SerialNumber
            $PartNumber = $HPEiLOSystemInfo.sku
            $Tags = $iLO.Tags
            
            $ComputeDevicesToAdd += [PSCustomObject]@{SerialNumber = $SerialNumber; PartNumber = $PartNumber; Tags = $Tags }

            Disconnect-HPEiLO -Connection $session
        }
        catch {
            "iLO {0} cannot be added ! Check your IP or credentials !" -f $iLO.IP
            continue
        }
    }

    $ComputeDevicesToAdd  | Add-HPEGLDeviceCompute 

    Sample script to add all compute devices listed in an `iLOs.csv` file to the currently connected HPE GreenLake workspace. Device information (part number and serial number) is retrieved using the HPEiLOCmdlets module with the IP and credentials provided in the CSV file. Optionally, tags can also be provided.

    The content of the iLOs.csv file must use the following format:
        IP; Username; Password; Tags
        192.168.1.44; demo; password; Country=FR, State=PACA, App=RH
        192.168.0.40; Administrator; P@ssw0rd; State=Texas, Role=production
        192.168.3.194; Admin; Password!    
        
        Note that for `192.168.3.194`, no tags are assigned in this example.

    .EXAMPLE
    $devices = @(
        [PSCustomObject]@{SerialNumber = '123456789012'; PartNumber = 'P55181-B21'},
        [PSCustomObject]@{SerialNumber = '123432356789'; PartNumber = 'P54277-B21'}
    )

    $devices | Add-HPEGLDeviceCompute -Tags "Country=US, Department=Marketing"
    
    Adds all compute devices (2) listed in `$devices` with the specified serial numbers and part numbers and assigns them two identical tags.

    .EXAMPLE
    $devices = @(
        [PSCustomObject]@{SerialNumber = '123456789012'; PartNumber = 'P55181-B21'; Tags = 'Country=US, State=PACA, App=RH' },
        [PSCustomObject]@{SerialNumber = '123432356789'; PartNumber = 'P54277-B21'; Tags = 'State=Texas, Role=production' }
    )

    $devices | Add-HPEGLDeviceCompute 
    
    Adds all compute devices (2) listed in `$devices` with the specified serial numbers and part numbers and assigns them different tags.

    .INPUTS
    System.Collections.ArrayList
        List of Device(s) with serialnumber, partnumber and tags properties. 

    .OUTPUTS
    System.Collections.ArrayList
        Returns a custom status object containing the following PsCustomObject keys:  
        * SerialNumber - Serial number of the device attempted to be added
        * PartNumber - Part number of the device attempted to be added
        * TagsAdded - List of tags to assign to the device (if any)
        * Status - Status of the device onboarding attempt (Failed for HTTP error return; Complete if onboarding is successful; Warning if no action is needed) 
        * Details - More information about the onboarding status of the device, which includes a PSCustomObject with:
          - TagsAdded - The number of tags added to the device.
          - Error - More information on a warning or failed status error.
        * Exception - Information about any exceptions generated during the operation.

    #>

    [CmdletBinding()]
    Param( 
        
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String]$SerialNumber,

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String]$PartNumber,

        [Parameter (ValueFromPipelineByPropertyName)]
        [String]$Tags,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-DevicesAddUri

        $InputList = [System.Collections.ArrayList]::new()
        $ObjectStatusList = [System.Collections.ArrayList]::new()
        $DevicesToAddList = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build tracking object for the output
        $objStatus = [pscustomobject]@{
  
            SerialNumber = $SerialNumber
            PartNumber   = $PartNumber
            TagsAdded    = $Tags
            Status       = $Null
            Details      = $Null
            Exception    = $Null
                  
        }

       
        # Add tracking object to the input list (always) and output list (only when not WhatIf)
        [void]$InputList.Add($objStatus)
        if (-not $WhatIf) { [void]$ObjectStatusList.Add($objStatus) }

    }

    end {        

        try {
            $Devices = Get-HPEGLdevice 
        
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        
        foreach ($DeviceToAdd in $InputList) {
            
            
            $ErrorFoundInTags = $False

            $Device = $Devices | Where-Object serialNumber -eq $DeviceToAdd.SerialNumber
            
            
            if ( $Device) {

                $DeviceToAdd.Status = "Warning"
                $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Device already present in the workspace!" }
                $DeviceToAdd.TagsAdded = $Null
                
                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource already present in the workspace!" -f $DeviceToAdd.SerialNumber
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }
            } 
            else {
                
                if ($DeviceToAdd.TagsAdded) {
                    
                    "[{0}] {1}: Object TagsAdded content: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DeviceToAdd.serialnumber, $DeviceToAdd.TagsAdded | Write-Verbose

                    $splittedtags = $DeviceToAdd.TagsAdded.split(",")

                    if ($splittedtags.Length -gt 25) {
                        
                        $DeviceToAdd.Status = "Warning"
                        $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Too many tags defined ! A maximum of 25 tags per resource is supported!" }
                        $DeviceToAdd.TagsAdded = $Null
                        $ErrorFoundInTags = $True


                        if ($WhatIf) {
                            $ErrorMessage = "Device '{0}': Resource is defined with too many tags! A maximum of 25 tags per resource is supported!" -f $DeviceToAdd.SerialNumber
                            Write-Warning "$ErrorMessage Cannot display API request."
                            continue
                        }
                    }
                    else {

                        # Object for the tracking object
                        $TagsList = [System.Collections.ArrayList]::new()
                        # Object for the payload
                        $TagsArray = @{}
                                
                        foreach ($tag in $splittedtags) {
    
                            # Check tag format, if format is not <tagname>=<value>, return error
                            if ($tag -notmatch '^[\p{L}\p{Nd}_ .:+\-@]+\=[\p{L}\p{Nd}_ .:+\-@]*$') {
                                
                                $splittedtagName = $tag.TrimEnd().TrimStart()
    
                                $DeviceToAdd.Status = "Warning"
                                $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Tag format '$splittedtagName' not supported! Expected format is <tagname>=<value>, <tagname>=<value>!" }
                                $DeviceToAdd.TagsAdded = $Null
                                $ErrorFoundInTags = $True
    
                                if ($WhatIf) {
                                    $ErrorMessage = "Device '{0}': Tag '{1}' format not supported! Expected format is <tagname>=<value>, <tagname>=<value>!" -f $DeviceToAdd.SerialNumber, $splittedtagName
                                    Write-Warning "$ErrorMessage Cannot display API request."
                                    break
                                }
                            }
                            else {
    
                                # Split only at the first '=' to preserve values containing '='
                                $eqIndex = $tag.IndexOf('=')
                                $tagname = $tag.Substring(0, $eqIndex).Trim()

        
                                if ($tagname.Length -gt 128) {
        
                                    $DeviceToAdd.Status = "Warning"
                                    $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Tag name '$tagname' is over 128 characters! Tag names can have a maximum of 128 characters!" }
                                    $DeviceToAdd.TagsAdded = $Null
                                    $ErrorFoundInTags = $True
        
                                    if ($WhatIf) {
                                        $ErrorMessage = "Device '{0}': Tag name '{1}' is over 128 characters! Tag names can have a maximum of 128 characters!" -f $DeviceToAdd.SerialNumber, $tagname
                                        Write-Warning "$ErrorMessage Cannot display API request."
                                        break
                                    }
                                }
                                else {
                                    
                                    $tagvalue = $tag.Substring($eqIndex + 1).Trim()

            
                                    if ($tagvalue.Length -gt 256) {
            
                                        $DeviceToAdd.Status = "Warning"
                                        $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Tag value '$tagvalue' is over 256 characters! Tag values can have a maximum of 256 characters!" }
                                        $DeviceToAdd.TagsAdded = $Null
                                        $ErrorFoundInTags = $True
            
                                        if ($WhatIf) {
                                            $ErrorMessage = "Device '{0}': Tag value '{1}' is over 256 characters! Tag values can have a maximum of 256 characters!" -f $DeviceToAdd.SerialNumber, $tagvalue
                                            Write-Warning "$ErrorMessage Cannot display API request."
                                            break
                                        }
                                    }
                                    else {
    
                                        $TagsArray.$tagname = $tagvalue 
                
                                        $TagsList += [PSCustomObject]@{
                                            name  = $tagname
                                            value = $tagvalue 
                                        }
                                    }
                                }
                            }
                        } 
                    }


                    if ($TagsList -and -not $ErrorFoundInTags) {
                        
                        $DeviceToAdd.TagsAdded = $TagsList
                    }
    
                }
                else {
    
                    "[{0}] {1}: No tags to add" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DeviceToAdd.serialnumber | Write-Verbose
    
                }
                
                

                # Build DeviceList object

                if (-not $ErrorFoundInTags) {

                    # If tags
                    if ($DeviceToAdd.TagsAdded) {
                    
                        $DeviceList = [PSCustomObject]@{
                            serialNumber = $DeviceToAdd.SerialNumber
                            partNumber   = $DeviceToAdd.PartNumber 
                            tags         = $TagsArray 
                        }
                    }
                    # If no tags
                    else {
                        
                        $DeviceList = [PSCustomObject]@{
                            serialNumber = $DeviceToAdd.SerialNumber
                            partNumber   = $DeviceToAdd.PartNumber 
                            
                        }
                    }
    
                    [void]$DevicesToAddList.Add($DeviceList)
                }

            }
        }


        "[{0}] List of objects in `$ObjectStatusList: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList | Out-String) | Write-Verbose

        if ($DevicesToAddList) {

            # Build payload
            $payload = [PSCustomObject]@{
                compute = $DevicesToAddList 
                network = @()
                storage = @()
            } | ConvertTo-Json -Depth 5
            

            # Add device
            try {
                Invoke-HPEGLWebRequest -Uri $Uri -method 'POST' -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | out-Null

                if (-not $WhatIf) {

                    foreach ($DeviceToAdd in $ObjectStatusList) {

                        $AddedDevice = $DevicesToAddList | Where-Object serialNumber -eq $DeviceToAdd.SerialNumber

                        If ($AddedDevice) {

                            $DeviceToAdd.Status = "Complete"

                            if ($DeviceToAdd.TagsAdded) {
                                
                                $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = $DeviceToAdd.TagsAdded.count; Error = $Null }
                            }
                            else {
                                $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = $Null }

                            }

                        }
                    }
                }
            }
            catch {

                if (-not $WhatIf) {

                    foreach ($DeviceToAdd in $ObjectStatusList) {

                        $AddedDevice = $DevicesToAddList | Where-Object serialNumber -eq $DeviceToAdd.SerialNumber

                        If ($AddedDevice) {

                            $DeviceToAdd.Status = "Failed"
                            $DeviceToAdd.TagsAdded = $Null
                            $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = if ($_.Exception.Message) { $_.Exception.Message } else { "Device cannot be added to the HPE GreenLake workspace!" } }
                            $DeviceToAdd.Exception = $Global:HPECOMInvokeReturnData

                        }
                    }
                }
            }      
        }
    
        

        if ($ObjectStatusList.Count -gt 0) {

            Return Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "Device.Add.SPTSDE"
        }

    }
}

Function Connect-HPEGLDeviceComputeiLOtoCOM {
    <#
    .SYNOPSIS
    Connect an iLO of a compute device to a Compute Ops Management instance.

    .DESCRIPTION
    This Cmdlet connects the iLO of a compute device to a Compute Ops Management (COM) instance. You can connect the iLO to the currently assigned COM instance or specify a particular COM instance using an activation key.
    The Cmdlet also supports disconnecting a system managed by HPE OneView to enable connection to COM, and allows configuration of a web proxy, including support for proxy authentication with username and password.
    To connect an iLO through a secure gateway, use the -IloProxyServer <SecureGateway_name> and -IloProxyPort 8080 parameters.

    When using the proxy parameters, the cmdlet automatically configures the iLO to use the specified proxy server, port and authentication.

    By default (i.e., when the 'ActivationKeyFromCOM' parameter is not used), this Cmdlet connects the iLO of a compute device to the assigned Compute Ops Management instance.

      - Requirement: The compute device must first be added to the workspace using 'Add-HPEGLDeviceCompute', then assigned to a Compute Ops Management instance using 'Add-HPEGLDeviceToService', and finally attached to a valid subscription key using Add-HPEGLSubscriptionToDevice.

      - You can use 'Get-HPEGLDevice -ShowComputeReadyForCOMIloConnection' to retrieve all compute devices ready to be connected to a Compute Ops Management instance.
        

    When the 'ActivationKeyFromCOM' parameter is used, the following steps take place:

       1- The compute device is added to the HPE GreenLake workspace.

       2- The compute device is attached to the Compute Ops Management instance from which the provided activation key was generated.

       3- The compute device is assigned to the Compute Ops Management subscription key set by 'New-HPECOMServerActivationKey' or by the auto subscription policy using 'Set-HPEGLDeviceAutoSubscription'.

       4- The iLO of the compute device is connected to the Compute Ops Management instance from which the provided activation key was generated.
       
    Requirement: An activation key is required and can be generated using 'New-HPECOMServerActivationKey'. The COM activation key is not supported for iLO5 versions lower than v3.09 and iLO6 versions lower than v1.64.
       
       - You can use 'Get-HPECOMServerActivationKey' to retrieve all generated and valid activation keys for the different Compute Ops Management instances where you want the compute device to be connected.

    .PARAMETER IloIP
    Specifies the IP address or hostname of the iLO device to connect to Compute Ops Management. Accepts either an IPv4/IPv6 address or a DNS hostname.
    
    .PARAMETER IloCredential
    A PSCredential object comprising the username and password associated with the iLO of the device that is being added.
    
    .PARAMETER ActivationKeyFromCOM
    (Optional) Specifies the Compute Ops Management activation key to be used for the connection. This activation key is retrieved using 'Get-HPECOMServerActivationKey'. 
    If not provided, the workspace account ID is used, and in this case, ensure the server is attached to a valid subscription key.

    .PARAMETER SkipCertificateValidation
    Skips certificate validation checks that include all validations such as expiration, revocation, trusted root authority, etc.

    [WARNING]:  Using this parameter is not secure and is not recommended. This switch is only intended to be used against known hosts using a self-signed certificate for testing purposes. Use at your own risk.

    .PARAMETER IloProxyServer
    (Optional) Enables iLO web proxy or Secure Gateway connectivity. Specifies the hostname or IP address of the web proxy server or Compute Ops Management Secure Gateway appliance.
    To connect an iLO through a Secure Gateway, provide the Secure Gateway appliance name and use port 8080 with -IloProxyPort.
    
    .PARAMETER IloProxyPort
    (Optional) Specifies the iLO web proxy or Secure Gateway port number. The range of valid port values in iLO is from 1 to 65535. Use port 8080 when connecting through a Compute Ops Management Secure Gateway.
    
    .PARAMETER IloProxyUserName
    (Optional) Specifies the iLO web proxy username, if applicable.
    
    .PARAMETER IloProxyPassword
    (Optional) Specifies the iLO web proxy password, if applicable, as a SecureString.

    .PARAMETER RemoveExistingiLOProxySettings
    If present, this switch parameter removes any existing iLO proxy configuration before connecting to Compute Ops Management. 
    This is useful when an incorrectly configured proxy is preventing the iLO from connecting to the cloud.
    
    Note: Due to an iLO firmware limitation, the proxy error may persist in the iLO's cached network state even after removal. 
    In such cases, use the -ResetiLOIfProxyErrorPersists parameter to automatically reset the iLO and clear the cached state.
    
    .PARAMETER ResetiLOIfProxyErrorPersists
    (Optional) When used with -RemoveExistingiLOProxySettings, automatically resets the iLO if cached proxy errors persist after proxy removal.
    This addresses a known iLO firmware limitation where the network stack does not properly clear cached connectivity test results.
    
    The cmdlet will:
    - Detect if proxy errors remain cached after removal
    - Perform an iLO reset (ForceRestart) to clear the network stack
    - Wait up to 120 seconds for iLO to restart (with 6 retry attempts)
    - Reconnect to iLO and complete the COM connection
    
    This provides a fully automated solution for the cached proxy issue without manual intervention.

    .PARAMETER MaxConnectionAttempts
    (Optional) Specifies the maximum number of connection attempts before giving up. Valid range is 1-30. Default is 10.
    Increase this value for networks with intermittent connectivity issues, or decrease for faster failure detection.
    
    .PARAMETER ConnectionRetryDelaySeconds
    (Optional) Specifies the delay in seconds between connection retry attempts. Valid range is 1-60. Default is 5 seconds.
    Increase this value to allow more time between retries on slower networks, or decrease for faster retry cycles.
    
    .PARAMETER ConnectionMonitoringTimeoutSeconds
    (Optional) Specifies the maximum time in seconds to monitor a connection in 'ConnectionInProgress' state. Valid range is 30-600. Default is 120 seconds (2 minutes).
    Increase this value for slower network environments or when connecting through complex network paths.
    
    .PARAMETER DisconnectiLOfromOneView
    If present, this switch parameter disconnects a system managed by HPE OneView in order to connect it to Compute Ops Management. If absent, the connection to Compute Ops Management will fail if the system is already managed by HPE OneView.
    
    .PARAMETER Force
    If present, this switch parameter forces reconnection of the iLO to Compute Ops Management even when the iLO is already connected. 
    The cmdlet will first disconnect the iLO from the current COM connection (via the iLO Redfish DisableCloudConnect action), then reconnect it using the specified parameters.
    This is useful when migrating an iLO connection in either direction:
    - Direct -> Secure Gateway: combine with -IloProxyServer and -IloProxyPort to route the reconnection through the Secure Gateway.
    - Secure Gateway -> Direct: combine with -RemoveExistingiLOProxySettings to clear the proxy before reconnecting directly.
    
    .EXAMPLE
    $iLO_credential = Get-Credential 
    Connect-HPEGLDeviceComputeiLOtoCOM -IloIP "192.168.0.21" -IloCredential $iLO_credential -SkipCertificateValidation
    
    Connect the iLO at 192.168.0.21 of compute device "123456789012" to the currently assigned Compute Ops Management instance. Certificate validation checks are skipped.
    
    .EXAMPLE
    Connect-HPEGLDeviceComputeiLOtoCOM -IloIP "192.168.1.151" -IloCredential $iLO_credential -IloProxyServer "web-proxy.domain.com" -IloProxyPort 8080

    Connect the iLO at 192.168.1.151 of compute device "123456789012" to the currently assigned Compute Ops Management instance through a web proxy.

    .EXAMPLE
    $iLO_credential = Get-Credential 
    $SecureGatewayName = Get-HPECOMAppliance -Region eu-central -Type SecureGateway | Select-Object -First 1 -ExpandProperty name
    $COM_Activation_Key = New-HPECOMServerActivationKey -Region eu-central -SecureGateway $SecureGatewayName
    Connect-HPEGLDeviceComputeiLOtoCOM -IloIP "192.168.0.21" -IloCredential $iLO_credential -ActivationKeyFromCOM $COM_Activation_Key -IloProxyServer $SecureGatewayName -IloProxyPort 8080 -SkipCertificateValidation

    Connect the iLO at 192.168.0.21 to the Compute Ops Management instance in the eu-central region through a Compute Ops Management Secure Gateway.
    The activation key is generated for the Secure Gateway, and the iLO is configured to route its connection through that Secure Gateway on port 8080.

    .EXAMPLE
    $iLO_secureString_Proxy_Password = Read-Host -Prompt "Enter the proxy password" -AsSecureString
    Connect-HPEGLDeviceComputeiLOtoCOM -IloIP "192.168.0.21" -IloCredential $iLO_credential -IloProxyServer "web-proxy.domain.com" -IloProxyPort 8080 -IloProxyUserName "admin" -IloProxyPassword $iLO_secureString_Proxy_Password

    Connect the iLO at 192.168.0.21 of compute device "123456789012" to the currently assigned Compute Ops Management instance through a web proxy using a username and password.

    .EXAMPLE
    $iLO_credential = Get-Credential 
    Import-Csv .\iLOs-List-To-Connect-To-COM.csv | Connect-HPEGLDeviceComputeiLOtoCOM -IloCredential $iLO_credential

    Connect all compute device iLOs listed in the `iLOs-List-To-Connect-To-COM.csv` file to the Compute Ops Management instance assigned to them.

    The content of the CSV file must use the following format:
        IP
        192.188.2.151
        192.188.2.152

    .EXAMPLE
    $iLOs = Import-Csv .\iLOs-List-To-Connect-To-COM.csv -Delimiter ","

    # Retrieve the first available Compute Ops Management subscription key that is valid and with available quantitiy 
    $Subscription_Key = Get-HPEGLSubscription -ShowWithAvailableQuantity -ShowValid -FilterBySubscriptionType Server | Select-Object -First 1 -ExpandProperty key

    # Generate an activation key for the Compute Ops Management in the central european region 
    $COM_Activation_Key = New-HPECOMServerActivationKey -Region eu-central -SubscriptionKey $Subscription_Key 
    
    ForEach ($iLO in $iLOs) {
      try {
        $iLO_SecurePassword = ConvertTo-SecureString $ILO.Password -AsPlainText -Force
        $iLO_credential = New-Object System.Management.Automation.PSCredential ($iLO.Username, $iLO_SecurePassword)
        Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLO_credential -IloIP $iLO.IP -ActivationKeyfromCOM $COM_Activation_Key
      }
      catch {
        "iLO {0} cannot be connected to COM ! Check your network access, iLO IP or credentials !" -f $iLO.IP
        continue
      }          
    }

    The compute devices listed in the `iLOs-List-To-Connect-To-COM.csv` file are added to the HPE GreenLake workspace, 
    attached to the Compute Ops Management 'eu-central' instance from which the activation key was generated, 
    assigned to the Compute Ops Management subscription key retrieved by 'Get-HPEGLSubscription' 
    and connected directly to the Compute Ops Management instance without using a web proxy.

    The content of the CSV file must use the following format:
       IP, Username, Password
       192.168.0.1, admin, password
       192.168.0.2, Administrator, password
       192.168.0.3, demo, password

    .EXAMPLE
    $iLOs = Import-Csv .\iLOs-List-To-Connect-To-COM.csv -Delimiter ","

    # Retrieve the first available Compute Ops Management subscription key that is valid and with available quantitiy 
    $Subscription_Key = Get-HPEGLSubscription -ShowWithAvailableQuantity -ShowValid -FilterBySubscriptionType Server | Select-Object -First 1 -ExpandProperty key

    # Generate an activation key for the Compute Ops Management in the central european region 
    $COM_Activation_Key = New-HPECOMServerActivationKey -Region eu-central -SubscriptionKey $Subscription_Key 
    
    ForEach ($iLO in $iLOs) {
      try {
        $iLO_SecurePassword = ConvertTo-SecureString $ILO.Password -AsPlainText -Force
        $iLO_credential = New-Object System.Management.Automation.PSCredential ($iLO.Username, $iLO_SecurePassword)
        Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLO_credential -IloIP $iLO.IP -ActivationKeyfromCOM $COM_Activation_Key -IloProxyServer "web-proxy.domain.com" -IloProxyPort 8080
      }
      catch {
        "iLO {0} cannot be connected to COM ! Check your network access, iLO IP or credentials !" -f $iLO.IP
        continue
      }          
    }

    The compute devices listed in the `iLOs-List-To-Connect-To-COM.csv` file are added to the HPE GreenLake workspace, 
    attached to the Compute Ops Management 'eu-central' instance from which the activation key was generated, 
    assigned to the Compute Ops Management subscription key retrieved by 'Get-HPEGLSubscription' 
    and connected to the Compute Ops Management instance through a web proxy.

    The content of the CSV file must use the following format:
       IP, Username, Password
       192.168.0.1, admin, password
       192.168.0.2, Administrator, password
       192.168.0.3, demo, password

    .EXAMPLE
    $iLOs = Import-Csv .\iLOs-List-To-Connect-To-COM.csv -Delimiter ","

    # Retrieve the name of the first available Compute Ops Management Secure Gateway in the central european region
    $SecureGatewayName = Get-HPECOMAppliance -Region eu-central -Type SecureGateway | Select-Object -First 1 -ExpandProperty name
    
    # Generate an activation key for the Compute Ops Management Secure Gateway in the central european region 
    $COM_Activation_Key = New-HPECOMServerActivationKey -Region eu-central -SecureGateway $SecureGatewayName  
    
    ForEach ($iLO in $iLOs) {
      try {
        $iLO_SecurePassword = ConvertTo-SecureString $ILO.Password -AsPlainText -Force
        $iLO_credential = New-Object System.Management.Automation.PSCredential ($iLO.Username, $iLO_SecurePassword)
        Connect-HPEGLDeviceComputeiLOtoCOM -iLOCredential $iLO_credential -IloIP $iLO.IP -ActivationKeyfromCOM $COM_Activation_Key -IloProxyServer $SecureGatewayName -IloProxyPort 8080 
      }
      catch {
        "iLO {0} cannot be connected to COM ! Check your network access, iLO IP or credentials !" -f $iLO.IP
        continue
      }          
    }

    The compute devices listed in the `iLOs-List-To-Connect-To-COM.csv` file are added to the HPE GreenLake workspace, 
    attached to the Compute Ops Management 'eu-central' instance from which the activation key was generated, 
    assigned to the Compute Ops Management subscription key retrieved by 'Get-HPEGLSubscription' 
    and connected to the Compute Ops Management instance through a Compute Ops Management Secure Gateway.

    The content of the CSV file must use the following format:
       IP, Username, Password
       192.168.0.1, admin, password
       192.168.0.2, Administrator, password
       192.168.0.3, demo, password

    .EXAMPLE
    $iLO_credential = Get-Credential 
    $COM_Activation_Key = New-HPECOMServerActivationKey -Region eu-central
    Connect-HPEGLDeviceComputeiLOtoCOM -IloIP "192.168.0.21" -IloCredential $iLO_credential -ActivationKeyfromCOM $COM_Activation_Key -RemoveExistingiLOProxySettings -ResetiLOIfProxyErrorPersists -SkipCertificateValidation

    Connect the iLO at 192.168.0.21 to the Compute Ops Management instance in the eu-central region. 
    If the iLO has an existing proxy configuration causing connection issues, it will be removed. 
    If cached proxy errors persist after removal (due to iLO firmware limitation), the iLO will be automatically reset to clear the network stack, 
    then reconnected and the COM connection completed. This provides a fully automated solution for proxy-related connection issues.
   

    .EXAMPLE
    # Migration: Direct connection -> Secure Gateway connection 
    
    # Get iLO credentials interactively
    $iLO_credential = Get-Credential 

    # Retrieve the name of the first available Compute Ops Management Secure Gateway in the central european region
    $SecureGatewayName = Get-HPECOMAppliance -Region eu-central -Type SecureGateway | Select-Object -First 1 -ExpandProperty name

    # Generate a COM activation key tied to the Secure Gateway
    $COM_Activation_Key = New-HPECOMServerActivationKey -Region eu-central -SecureGateway $SecureGatewayName

    # Reconnect all servers using a Direct connection to a Secure Gateway connection in a single operation
    Get-HPECOMServer -Region eu-central -ConnectionType Direct | Connect-HPEGLDeviceComputeiLOtoCOM -IloCredential $iLO_credential -ActivationKeyFromCOM $COM_Activation_Key -IloProxyServer $SecureGatewayName -IloProxyPort 8080 -Force -SkipCertificateValidation

    Migrates all servers in the eu-central region from a Direct connection to a Secure Gateway connection in a single command.
    -Force disconnects each iLO from its current Direct connection and reconnects it through the Secure Gateway. 
    -IloProxyServer and -IloProxyPort configure the Secure Gateway as the iLO proxy.
    Because the device service assignment is never removed, group memberships, server settings and policies in COM are fully preserved throughout the migration.

    .EXAMPLE
    # Migration: Secure Gateway connection -> Direct connection 

    # Get iLO credentials interactively
    $iLO_credential = Get-Credential

    # Generate a COM activation key (not tied to any Secure Gateway) 
    $COM_Activation_Key = New-HPECOMServerActivationKey -Region eu-central

    # Reconnect all servers using a Secure Gateway connection to a Direct connection in a single operation
    Get-HPECOMServer -Region eu-central -ConnectionType 'Secure Gateway' | Connect-HPEGLDeviceComputeiLOtoCOM -IloCredential $iLO_credential -ActivationKeyFromCOM $COM_Activation_Key -IloProxyServer web_proxy.domain.com -IloProxyPort 8088 -Force -SkipCertificateValidation
    
    Migrates all servers in the eu-central region from a Secure Gateway connection to a Direct connection in a single command.
    -Force disconnects each iLO from the Secure Gateway and reconnects it directly to COM. 
    -IloProxyServer / -IloProxyPort replace the Secure Gateway proxy with a standard corporate web proxy — use this when iLO still needs a proxy to reach COM over the internet. If iLO has unrestricted internet access, use -RemoveExistingiLOProxySettings instead to clear the proxy entirely.
    Because the device service assignment is never removed, group memberships, server settings and policies in COM are fully preserved throughout the migration.

    .INPUTS
    System.Collections.ArrayList
        List of Device(s) with an IP property (iLO IP address).

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * iLO - iLO IP address of the device to connect to Compute Ops Management.
        * SerialNumber - Serial number of the device.
        * Status - Status of the iLO connection and configuration attempt (Failed for error; Complete if successful; Warning if no action is needed or another condition was encountered).
        * Details - More information about the status.
        * iLOConnectionStatus - Status of the iLO connection attempt to Compute Ops Management (Failed for HTTP error return; Complete if successful, Warning if another condition was encountered).
        * iLOConnectionDetails - More information about the iLO connection attempt status.
        * ProxySettingsStatus - Status of the iLO Proxy configuration attempt (Failed for HTTP error return; Complete if successful).
        * ProxySettingsDetails - More information about the iLO Proxy configuration status.
        * Exception - Information about any exceptions generated during the operation.
#>

    [CmdletBinding(DefaultParameterSetName = 'EnableProxySettings')]
    Param( 
 
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateScript({
                if ([string]::IsNullOrEmpty($_)) { return $true }
                $ip = $null
                if ([Net.IPAddress]::TryParse($_, [ref]$ip)) { return $true }
                try { [Net.Dns]::GetHostEntry($_) | Out-Null; return $true } catch { throw "Invalid IP or hostname: $_" }
            })]
        [Alias ('IP', 'iLOIPAddress')]
        [string]$IloIP,

        [Parameter (Mandatory)]
        [ValidateNotNullOrEmpty()]
        [PSCredential]$iLOCredential,

        [string]$ActivationKeyfromCOM,
        
        [Switch]$SkipCertificateValidation,

        [Parameter (ParameterSetName = 'EnableProxySettings')]
        [String]$IloProxyServer,
  
        [Parameter (ParameterSetName = 'EnableProxySettings')]
        [ValidateNotNullOrEmpty()]
        [ValidateRange(1, 65535)]
        [Int]$IloProxyPort,
  
        [Parameter (ParameterSetName = 'EnableProxySettings')]
        [String]$IloProxyUserName,
  
        [Parameter (ParameterSetName = 'EnableProxySettings')]
        [ValidateNotNull()]
        [System.Security.SecureString]$IloProxyPassword,

        [Parameter (ParameterSetName = 'DisableProxySettings')]
        [Switch]$RemoveExistingiLOProxySettings,
        
        [Parameter (ParameterSetName = 'DisableProxySettings')]
        [Switch]$ResetiLOIfProxyErrorPersists,

        [Switch]$DisconnectiLOfromOneView,

        [Switch]$Force,

        [Parameter (Mandatory = $false)]
        [ValidateRange(1, 30)]
        [int]$MaxConnectionAttempts = 10,

        [Parameter (Mandatory = $false)]
        [ValidateRange(1, 60)]
        [int]$ConnectionRetryDelaySeconds = 5,

        [Parameter (Mandatory = $false)]
        [ValidateRange(30, 600)]
        [int]$ConnectionMonitoringTimeoutSeconds = 120
  
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $iLOConnectionStatus = [System.Collections.ArrayList]::new()

        try {
            $devices = Get-HPEGLdevice 
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        # Make sure IloProxyUserName is provided if IloProxyPassword is provided
        if ($PSBoundParameters.ContainsKey('IloProxyPassword') -and -not $PSBoundParameters.ContainsKey('IloProxyUserName')) {
            $ErrorMessage = "Parameter 'IloProxyUserName' is required when 'IloProxyPassword' is provided."
            Throw $ErrorMessage
        }
        # Make sure IloProxyPassword is provided if IloProxyUserName is provided
        if ($PSBoundParameters.ContainsKey('IloProxyUserName') -and -not $PSBoundParameters.ContainsKey('IloProxyPassword')) {
            $ErrorMessage = "Parameter 'IloProxyPassword' is required when 'IloProxyUserName' is provided."
            Throw $ErrorMessage
        }
        # Make sure IloProxyPort is provided if IloProxyServer is provided
        if ($PSBoundParameters.ContainsKey('IloProxyServer') -and -not $PSBoundParameters.ContainsKey('IloProxyPort')) {
            $ErrorMessage = "Parameter 'IloProxyPort' is required when 'IloProxyServer' is provided."
            Throw $ErrorMessage
        }
        # Make sure IloProxyServer is provided if IloProxyPort is provided
        if ($PSBoundParameters.ContainsKey('IloProxyPort') -and -not $PSBoundParameters.ContainsKey('IloProxyServer')) {
            $ErrorMessage = "Parameter 'IloProxyServer' is required when 'IloProxyPort' is provided."
            Throw $ErrorMessage
        }
        
            
         
    }

    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Create object for the output
        $objStatus = [pscustomobject]@{
  
            iLO                  = $IloIP
            SerialNumber         = $Null
            Status               = $Null
            Details              = $Null
            iLOConnectionStatus  = $Null
            iLOConnectionDetails = $Null
            ProxySettingsStatus  = $Null
            ProxySettingsDetails = $Null
            Exception            = $Null
        }
        

        #Region----------------------------------------------------------- Create iLO session -----------------------------------------------------------    
      
        # Test network connectivity with iLO
        $IsILOAccessible = (New-Object System.Net.NetworkInformation.Ping).Send($IloIP, 4000) 

        "[{0}] PING iLO '{1}' test result: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $IsILOAccessible.status | Write-Verbose

        if ($IsILOAccessible.Status -ne "Success") {
            $objStatus.Status = "Warning"
            $objStatus.Details = "iLO is not reachable. Please ensure your are connected to the iLO network."
            [void] $iLOConnectionStatus.add($objStatus)
            return       
        }


        $iLOBaseURL = "https://$IloIP"
            
        $AddURI = "/redfish/v1/SessionService/Sessions/"
            
        $url = $iLOBaseURL + $AddURI

        $IloUsername = $iLOCredential.UserName
        $IlodecryptPassword = $iLOCredential.GetNetworkCredential().Password  
            
        $Body = [System.Collections.Hashtable]@{
            UserName = $IloUserName
            Password = $IlodecryptPassword
        } | ConvertTo-Json 
            
        "[{0}] {1}: Attempting an iLO session creation..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP | Write-Verbose
        "[{0}] {1}: About to run a POST {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $url | Write-Verbose
        "[{0}] {1}: Body content: `n{2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, ($Body -replace '"Password":\s*"(.*?)"', '"Password": "[REDACTED]"') | Write-Verbose

        try {

            if ($SkipCertificateValidation) {
                $response = Invoke-WebRequest -Method POST -Uri $url -Body $Body -ContentType "Application/json" -SkipCertificateCheck -ErrorAction Stop
            }
            else {
                $response = Invoke-WebRequest -Method POST -Uri $url -Body $Body -ContentType "Application/json" -ErrorAction Stop
            }
            
            $XAuthToken = (($response.RawContent -split "[`r`n]" | select-string -Pattern 'X-Auth-Token' ) -split " ")[1]

            "[{0}] {1}: Received status code response: '{2}' - Description: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $response.StatusCode, $response.StatusDescription | Write-verbose
            "[{0}] {1}: Raw response: `n{2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, ($response | ConvertFrom-Json | ConvertTo-Json -Depth 10) | Write-Verbose

            if (-not $XAuthToken) {
                $objStatus.iLOConnectionStatus = "Failed"
                $objStatus.iLOConnectionDetails = "iLO connection error! No X-Auth-Token received from iLO."
                $objStatus.Exception = "No X-Auth-Token received from iLO."

                "[{0}] {1}: iLO connection error! No X-Auth-Token received from iLO." -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP | Write-Verbose
                $objStatus.Status = "Failed"
                [void] $iLOConnectionStatus.add($objStatus)
                return
            }
            else {
                "[{0}] {1}: iLO session created successfully! XAuthToken: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP, ($XAuthToken.Substring(0, 5) + "***********" ) | Write-Verbose
            }

            # Clear the variable and force garbage collection
            $IlodecryptPassword = $null
            [GC]::Collect()
            [GC]::WaitForPendingFinalizers()

        }
        catch {

            # Check if the exception message contains invalid certificate error
            if ($_.Exception.InnerException.Message -match "remote certificate is invalid") {
                    
                $objStatus.iLOConnectionStatus = "Failed"
                $objStatus.iLOConnectionDetails = "Failed to create iLO session due to certificate validation error. To bypass certificate validation checks, including expiration, revocation, and trusted root authority, use the -SkipCertificateValidation switch. Warning: This is not recommended as it is insecure because it exposes the connection to potential man-in-the-middle attacks and other security risks."
                $objStatus.Exception = $_.Exception.InnerException.Message 

                "[{0}] {1}: Attempt to create iLO session failed due to certificate validation error!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP | Write-Verbose

            }
            else {               
                
                $objStatus.iLOConnectionStatus = "Failed"
                $objStatus.iLOConnectionDetails = "iLO connection error! Verify the iLO IP address, credentials, and ensure you have an active connection to the iLO network, then try again."
                $objStatus.Exception = $_.Exception.message 

                "[{0}] {1}: iLO session cannot be created!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP | Write-Verbose
            }

            $objStatus.Status = "Failed"
            [void] $iLOConnectionStatus.add($objStatus)
            return
        }
        
        #endregion

        #Region----------------------------------------------------------- Get System information -----------------------------------------------------------
                
        $Headers = [System.Collections.Hashtable]@{
            'X-Auth-Token'  = $XAuthToken
            'Content-Type'  = 'application/json'
            'OData-Version' = '4.0'    
        }

        "[{0}] {1}: Getting iLO information..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP | Write-Verbose

        $AddURI = "/redfish/v1/Managers/1/"

        "[{0}] {1}: About to run a GET {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP, ($iLObaseURL + $AddURI) | Write-Verbose
        "[{0}] {1}: Headers content: `n{2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP, (($Headers | ConvertTo-Json -Depth 5) -replace '("X-Auth-Token"\s*:\s*")([^"]+)"', '${1}[REDACTED]"') | Write-Verbose

        try {
            if ($SkipCertificateValidation) {
                $Manager = Invoke-RestMethod -Method GET -Uri ($iLObaseURL + $AddURI) -Headers $Headers -SkipCertificateCheck
            }
            else {
                $Manager = Invoke-RestMethod -Method GET -Uri ($iLObaseURL + $AddURI) -Headers $Headers
            }            
        }
        catch {
            $objStatus.iLOConnectionStatus = "Failed"
            $objStatus.iLOConnectionDetails = "iLO communication error!"
            $objStatus.Exception = $_.Exception.message 

            "[{0}] {1}: iLO communication error!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP | Write-Verbose
            $objStatus.Status = "Failed"
            [void] $iLOConnectionStatus.add($objStatus)
            return
        }
            
        $iLOGeneration = $Manager.model
        $iLOFWVersion = ($Manager.firmwareVersion.split(" "))[2].TrimStart('v')  # "FirmwareVersion": "iLO 5 v3.06" or "iLO 6 v1.62"

        # Get device serial number from iLO
        "[{0}] {1}: Getting system information..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP | Write-Verbose

        $AddURI = "/redfish/v1/Systems/1/"

        "[{0}] {1}: About to run a GET {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP, ($iLObaseURL + $AddURI) | Write-Verbose
        "[{0}] {1}: Headers content: `n{2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP, (($Headers | ConvertTo-Json -Depth 5) -replace '("X-Auth-Token"\s*:\s*")([^"]+)"', '${1}[REDACTED]"') | Write-Verbose

        try {
            if ($SkipCertificateValidation) {
                $System = Invoke-RestMethod -Method GET -Uri ($iLObaseURL + $AddURI) -Headers $Headers -SkipCertificateCheck
            }
            else {
                $System = Invoke-RestMethod -Method GET -Uri ($iLObaseURL + $AddURI) -Headers $Headers
            }             
        }
        catch {
            $objStatus.iLOConnectionStatus = "Failed"
            $objStatus.iLOConnectionDetails = "iLO communication error!"
            $objStatus.Exception = $_.Exception.message 

            "[{0}] {1}: iLO communication error!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP | Write-Verbose
            $objStatus.Status = "Failed"
            [void] $iLOConnectionStatus.add($objStatus)
            return
        }

        $SerialNumber = $objStatus.SerialNumber = $System.SerialNumber 
        
        # Get proxy settings from iLO
        "[{0}] {1}: Getting proxy settings..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP | Write-Verbose

        $AddURI = "/redfish/v1/Managers/1/NetworkProtocol/"

        "[{0}] {1}: About to run a GET {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP, ($iLObaseURL + $AddURI) | Write-Verbose
        "[{0}] {1}: Headers content: `n{2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP, (($Headers | ConvertTo-Json -Depth 5) -replace '("X-Auth-Token"\s*:\s*")([^"]+)"', '${1}[REDACTED]"') | Write-Verbose

        try {
            if ($SkipCertificateValidation) {
                $NetworkProtocol = Invoke-RestMethod -Method GET -Uri ($iLObaseURL + $AddURI) -Headers $Headers -SkipCertificateCheck
            }
            else {
                $NetworkProtocol = Invoke-RestMethod -Method GET -Uri ($iLObaseURL + $AddURI) -Headers $Headers
            }             
            if ($NetworkProtocol.Oem.Hpe.WebProxyConfiguration.ProxyServer -ne "") {
                $ProxySettings = "Enabled"
                $ExistingProxyServer = $NetworkProtocol.Oem.Hpe.WebProxyConfiguration.ProxyServer
                $ExistingProxyPort   = $NetworkProtocol.Oem.Hpe.WebProxyConfiguration.ProxyPort
                "[{0}] {1}: Existing iLO proxy settings detected - ProxyServer: '{2}', ProxyPort: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP, $ExistingProxyServer, $ExistingProxyPort | Write-Verbose
            }
            else {
                $ProxySettings = "Disabled"
            }
        }
        catch {
            $objStatus.iLOConnectionStatus = "Failed"
            $objStatus.iLOConnectionDetails = "iLO communication error!"
            $objStatus.Exception = $_.Exception.message 

            "[{0}] {1}: iLO communication error!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP | Write-Verbose
            $objStatus.Status = "Failed"
            [void] $iLOConnectionStatus.add($objStatus)
            return
        }

        # Display iLO information
        "[{0}] {1} [{2} v{3} - SN: {4} - Proxy: {5}]" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $iLOGeneration, $iLOFWVersion, $SerialNumber, $ProxySettings | Write-Verbose
         
        #EndRegion

        
        if ($ActivationKeyfromCOM) {           
            
            #Region----------------------------------------------------------- iLO Firmware validation with COM activation key -----------------------------------------------------------
            # Check if the iLO firmware version is compatible with the COM activation key
            # Servers running earlier versions of iLO 5 and iLO 6 can be activated by using the HPE GreenLake workspace ID.
            # COM activation key is not supported if iLO5 lower than v3.09 and if iLO6 lower than v1.64.
            if ($iLOGeneration -eq "iLO 5" -and [decimal]$iLOFWVersion -lt [decimal]3.09) {
                
                $objStatus.iLOConnectionStatus = "Warning"
                $objStatus.iLOConnectionDetails = "Server cannot be connected to COM using a COM activation key because the iLO firmware version is lower than v3.09. Please run the cmdlet without the 'ActivationKeyfromCOM' parameter."
                
                "[{0}] {1} [{2}] The iLO {3} firmware version {4} is NOT compatible with the COM activation key ! iLO cannot be connected to COM using a COM activation key because the iLO firmware version is lower than v3.09" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $iLOGeneration, $iLOFWVersion | Write-Verbose
                
                $objStatus.Status = "Warning"
                [void]$iLOConnectionStatus.add($objStatus) 
                return

            }
            elseif ($iLOGeneration -eq "iLO 6" -and [decimal]$iLOFWVersion -lt [decimal]1.64) {

                
                $objStatus.iLOConnectionStatus = "Warning"
                $objStatus.iLOConnectionDetails = "Server cannot be connected to COM using a COM activation key because the iLO firmware version is lower than v1.64. Please run the cmdlet without the 'ActivationKeyfromCOM' parameter."

                "[{0}] {1} [{2}] The iLO {3} firmware version {4} is NOT compatible with the COM activation key ! iLO cannot be connected to COM using a COM activation key because the iLO firmware version is lower than v1.64" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $iLOGeneration, $iLOFWVersion | Write-Verbose

                $objStatus.Status = "Warning"
                [void]$iLOConnectionStatus.add($objStatus)
                return
            }
            else {
                "[{0}] {1} [{2}] The iLO {3} firmware version {4} is compatible with the COM activation key" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $iLOGeneration, $iLOFWVersion | Write-Verbose
            }
            #EndRegion
        }

        else {

            #Region----------------------------------------------------------- Validate device in the workspace without COM activation key ------------------------------------------------
            # Validate if the device is present in the workspace and if it is assigned to COM and attached to a valid subscription key when no COM activation key is provided

            "[{0}] {1} [{2}] No COM activation key provided. The iLO will be connected to the currently assigned COM instance." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose                        
            
            # Test if device present in the workspace
            $device = $devices | Where-Object serialNumber -eq $SerialNumber
            
            if ( -not $device) {
                # Must return a message if device is not found
                $objStatus.Status = "Warning"
                $objStatus.Details = "Device cannot be found in the HPE GreenLake workspace"
                [void] $iLOConnectionStatus.add($objStatus)
                return
                
            }
            elseif (-not $device.region) {
                # Must return a message if device is not assigned to COM
                $objStatus.Status = "Warning"
                $objStatus.Details = "Device is not assigned to any service instance!"
                [void] $iLOConnectionStatus.add($objStatus)
                return
                
            }
            elseif (-not $device.subscription.key) {
                # Must return a message if device has no subscription
                $objStatus.Status = "Warning"
                $objStatus.Details = "Device has not been attached to any subscription!"
                [void] $iLOConnectionStatus.add($objStatus)
                return
                
            }
            #EndRegion
        }       
                
        
        if ($iLOGeneration -eq "iLO 5" -or $iLOGeneration -eq "iLO 6" -or $iLOGeneration -eq "iLO 7") {       
            
            #Region----------------------------------------------------------- Remove iLO proxy settings -----------------------------------------------------------------------------
            if ($RemoveExistingiLOProxySettings -and $ProxySettings -eq "Enabled") {

                "[{0}] {1} [{2}] Attempting to remove existing iLO proxy server settings" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose

                $AddURI = "/redfish/v1/Managers/1/NetworkProtocol/"

                $url = ( $iLObaseURL + $AddURI)
                                    
                $Body = [System.Collections.Hashtable]@{
                    Oem = @{
                        Hpe = @{
                            WebProxyConfiguration = @{
                                ProxyServer   = ""
                                ProxyPort     = $Null
                                ProxyUserName = ""
                                ProxyPassword = ""
                            }
                        }
                    }
                } | ConvertTo-Json -d 9

                "[{0}] {1} [{2}] About to run a POST {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $url | Write-Verbose
                "[{0}] {1} [{2}] Headers content: `n{3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP, $SerialNumber, (($Headers | ConvertTo-Json -Depth 5) -replace '("X-Auth-Token"\s*:\s*")([^"]+)"', '${1}[REDACTED]"') | Write-Verbose
                "[{0}] {1} [{2}] Body content: `n{3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $Body | Write-Verbose

                try {
                    
                    if ($SkipCertificateValidation) {
                        $Response = Invoke-RestMethod -Method PATCH -Uri $url -Headers $Headers -Body $Body -ErrorAction Stop -SkipCertificateCheck
                    }                        
                    else {
                        $Response = Invoke-RestMethod -Method PATCH -Uri $url -Headers $Headers -Body $Body -ErrorAction Stop
                    }

    
                    "[{0}] {1} [{2}] Raw response: `n{3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, ($Response | Out-String) | Write-Verbose

                    $msg = $response.error.'@Message.ExtendedInfo'.MessageId
                
                    "[{0}] {1} [{2}] Response: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $msg | Write-Verbose
    
                    if ($msg -match "Success") {
                        "[{0}] {1} [{2}] iLO proxy server settings removed successfully! (was: ProxyServer='{3}', ProxyPort='{4}')" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $ExistingProxyServer, $ExistingProxyPort | Write-Verbose
                        $objStatus.ProxySettingsStatus = "Complete"
                        $objStatus.ProxySettingsDetails = "iLO proxy server settings removed successfully!"
                        
                        # Verify proxy settings were actually removed by reading them back
                        try {
                            $NetworkProtocolURI = "/redfish/v1/Managers/1/NetworkProtocol/"
                            $NetworkProtocolUrl = $iLObaseURL + $NetworkProtocolURI
                            
                            Start-Sleep -Seconds 3
                            
                            if ($SkipCertificateValidation) {
                                $NetworkProtocolCheck = Invoke-RestMethod -Method GET -Uri $NetworkProtocolUrl -Headers $Headers -ErrorAction Stop -SkipCertificateCheck
                            }
                            else {
                                $NetworkProtocolCheck = Invoke-RestMethod -Method GET -Uri $NetworkProtocolUrl -Headers $Headers -ErrorAction Stop
                            }
                            
                            $CurrentProxyServer = $NetworkProtocolCheck.Oem.Hpe.WebProxyConfiguration.ProxyServer
                            
                            if ($CurrentProxyServer) {
                                "[{0}] {1} [{2}] Warning: Proxy server still configured as '{3}' - proxy removal may not have fully applied!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $CurrentProxyServer | Write-Verbose
                            }
                            else {
                                "[{0}] {1} [{2}] Proxy removal verified - proxy server is no longer configured" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                            }
                        }
                        catch {
                            "[{0}] {1} [{2}] Warning: Could not verify proxy removal: {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $_.Exception.Message | Write-Verbose
                        }
                        
                        # Wait additional time for proxy removal to propagate
                        "[{0}] {1} [{2}] Waiting 10 seconds for proxy removal to fully propagate..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                        Start-Sleep -Seconds 10
                        
                        # Check if CloudConnect is still showing proxy error - if so, disable it to clear cached state
                        try {
                            $CheckURI = "/redfish/v1/Managers/1/"
                            $CheckUrl = $iLObaseURL + $CheckURI
                            
                            if ($SkipCertificateValidation) {
                                $CheckResponse = Invoke-RestMethod -Method GET -Uri $CheckUrl -Headers $Headers -ErrorAction Stop -SkipCertificateCheck
                            }
                            else {
                                $CheckResponse = Invoke-RestMethod -Method GET -Uri $CheckUrl -Headers $Headers -ErrorAction Stop
                            }
                            
                            $CurrentFailReason = $CheckResponse.Oem.Hpe.CloudConnect.FailReason
                            $CurrentStatus = $CheckResponse.Oem.Hpe.CloudConnect.CloudConnectStatus
                            
                            "[{0}] {1} [{2}] Current CloudConnect state: Status='{3}', FailReason='{4}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $CurrentStatus, $CurrentFailReason | Write-Verbose
                            
                            # If still showing proxy error, disable CloudConnect to force fresh test
                            if ($CurrentFailReason -match "ProxyOrFirewall") {
                                
                                if ($ResetiLOIfProxyErrorPersists) {
                                    # Known iLO firmware limitation: cached proxy error persists even after proxy removal
                                    # Only solution is iLO reset - faster and more reliable than disable/wait/enable cycle
                                    "[{0}] {1} [{2}] iLO has cached proxy error that persists after removal. Performing iLO reset to clear network stack..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                                    
                                    try {
                                        $ResetURI = "/redfish/v1/Managers/1/Actions/Manager.Reset/"
                                        $ResetUrl = $iLObaseURL + $ResetURI
                                        $ResetBody = @{ ResetType = "ForceRestart" } | ConvertTo-Json
                                        
                                        if ($SkipCertificateValidation) {
                                            $null = Invoke-RestMethod -Method POST -Uri $ResetUrl -Headers $Headers -Body $ResetBody -ErrorAction Stop -SkipCertificateCheck
                                        }
                                        else {
                                            $null = Invoke-RestMethod -Method POST -Uri $ResetUrl -Headers $Headers -Body $ResetBody -ErrorAction Stop
                                        }
                                        
                                        "[{0}] {1} [{2}] iLO reset initiated. Waiting 60 seconds for iLO to restart and clear cached network state..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                                        Start-Sleep -Seconds 60
                                        
                                        # Retry reconnection with multiple attempts (iLO resets can take 90-120 seconds)
                                        "[{0}] {1} [{2}] Attempting to reconnect to iLO after reset..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                                        
                                        $MaxReconnectAttempts = 6
                                        $ReconnectInterval = 10
                                        $ReconnectSuccess = $false
                                        
                                        for ($attempt = 1; $attempt -le $MaxReconnectAttempts; $attempt++) {
                                            try {
                                                # Create new session after reset
                                                $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($iLOCredential.Password)
                                                $iLOPasswordPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($Ptr)
                                                
                                                $ReconnectBody = [System.Collections.Hashtable]@{
                                                    UserName = $iLOCredential.UserName
                                                    Password = $iLOPasswordPlainText
                                                } | ConvertTo-Json
                                                
                                                $SessionURI = "/redfish/v1/SessionService/Sessions/"
                                                $SessionUrl = $iLObaseURL + $SessionURI
                                                
                                                if ($SkipCertificateValidation) {
                                                    $SessionResponse = Invoke-WebRequest -Method POST -Uri $SessionUrl -Body $ReconnectBody -ContentType "application/json" -ErrorAction Stop -SkipCertificateCheck
                                                }
                                                else {
                                                    $SessionResponse = Invoke-WebRequest -Method POST -Uri $SessionUrl -Body $ReconnectBody -ContentType "application/json" -ErrorAction Stop
                                                }
                                                
                                                # Extract X-Auth-Token from response headers
                                                $NewXAuthToken = (($SessionResponse.RawContent -split "[`r`n]" | select-string -Pattern 'X-Auth-Token' ) -split " ")[1]
                                                
                                                # Update the Headers hashtable with new token
                                                $Headers['X-Auth-Token'] = $NewXAuthToken
                                                
                                                "[{0}] {1} [{2}] iLO session re-established after reset (attempt {3}/{4})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $attempt, $MaxReconnectAttempts | Write-Verbose
                                                $ReconnectSuccess = $true
                                                
                                                # Clean up sensitive data
                                                $iLOPasswordPlainText = $null
                                                [GC]::Collect()
                                                break
                                            }
                                            catch {
                                                if ($attempt -lt $MaxReconnectAttempts) {
                                                    "[{0}] {1} [{2}] iLO not ready yet (attempt {3}/{4}). Waiting {5} seconds before retry..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $attempt, $MaxReconnectAttempts, $ReconnectInterval | Write-Verbose
                                                    Start-Sleep -Seconds $ReconnectInterval
                                                }
                                                else {
                                                    "[{0}] {1} [{2}] Warning: Failed to reconnect to iLO after {3} attempts: {4}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $MaxReconnectAttempts, $_.Exception.Message | Write-Verbose
                                                    "[{0}] {1} [{2}] iLO may be taking longer than expected to restart. Please verify iLO is accessible and retry the connection." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Warning
                                                }
                                            }
                                        }
                                        
                                        if (-not $ReconnectSuccess) {
                                            # Could not reconnect after reset - return error
                                            $ErrorMessage = "iLO reset completed but could not re-establish connection after {0} seconds. Please verify iLO is accessible and retry." -f (60 + ($MaxReconnectAttempts * $ReconnectInterval))
                                            $objStatus.Status = "Failed"
                                            $objStatus.Details = $ErrorMessage
                                            [void] $iLOConnectionStatus.add($objStatus)
                                            return
                                        }
                                        
                                    }
                                    catch {
                                        "[{0}] {1} [{2}] Warning: iLO reset failed: {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $_.Exception.Message | Write-Verbose
                                        "[{0}] {1} [{2}] Attempting to continue with disable/enable CloudConnect approach..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                                    }
                                }
                                
                                if (-not $ResetiLOIfProxyErrorPersists) {
                                    "[{0}] {1} [{2}] iLO still has cached proxy error. Disabling CloudConnect to clear state..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                                    "[{0}] {1} [{2}] NOTE: Due to iLO firmware limitation, proxy error may persist. Consider using -ResetiLOIfProxyErrorPersists parameter for reliable clearing." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Warning
                                    
                                    $DisableURI = "/redfish/v1/Managers/1/Actions/Oem/Hpe/HpeiLO.DisableCloudConnect/"
                                    $DisableUrl = $iLObaseURL + $DisableURI
                                    $DisableBody = @{} | ConvertTo-Json
                                    
                                    if ($SkipCertificateValidation) {
                                        $null = Invoke-RestMethod -Method POST -Uri $DisableUrl -Headers $Headers -Body $DisableBody -ErrorAction Stop -SkipCertificateCheck
                                    }
                                    else {
                                        $null = Invoke-RestMethod -Method POST -Uri $DisableUrl -Headers $Headers -Body $DisableBody -ErrorAction Stop
                                    }
                                    
                                    "[{0}] {1} [{2}] CloudConnect disabled successfully. Waiting for network stack to clear cached state..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                                    
                                    # Wait even longer for iLO network stack to fully reset
                                    Start-Sleep -Seconds 30
                                    
                                    # Verify CloudConnect is now in NotEnabled state
                                    if ($SkipCertificateValidation) {
                                        $VerifyResponse = Invoke-RestMethod -Method GET -Uri $CheckUrl -Headers $Headers -ErrorAction Stop -SkipCertificateCheck
                                    }
                                    else {
                                        $VerifyResponse = Invoke-RestMethod -Method GET -Uri $CheckUrl -Headers $Headers -ErrorAction Stop
                                    }
                                    
                                    $VerifyStatus = $VerifyResponse.Oem.Hpe.CloudConnect.CloudConnectStatus
                                    $VerifyFailReason = $VerifyResponse.Oem.Hpe.CloudConnect.FailReason
                                    "[{0}] {1} [{2}] CloudConnect state after disable: Status='{3}', FailReason='{4}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $VerifyStatus, $VerifyFailReason | Write-Verbose
                                }
                            }
                            else {
                                "[{0}] {1} [{2}] iLO has cleared the proxy error state" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                            }
                        }
                        catch {
                            "[{0}] {1} [{2}] Warning: Error checking/clearing CloudConnect state: {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $_.Exception.Message | Write-Verbose
                        }
                    }
                    else {
                        "[{0}] {1} [{2}] iLO proxy server settings removal error! Message: {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $msg | Write-Verbose
                        $objStatus.ProxySettingsStatus = "Failed"
                        $objStatus.ProxySettingsDetails = $msg                        
                    }
                }
                catch {

                    "[{0}] {1} [{2}] iLO proxy server settings cannot be removed! Error: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $_ | Write-Verbose
                    $ErrorMessage = "Failed to remove iLO proxy server settings: $($_.Exception.Message)"

                    $objStatus.ProxySettingsStatus = "Failed"
                    $objStatus.ProxySettingsDetails = $ErrorMessage
                    [void] $iLOConnectionStatus.add($objStatus)
                    return

                }
            }
            elseif ($RemoveExistingiLOProxySettings -and $ProxySettings -eq "Disabled") {
                "[{0}] {1} [{2}] No existing iLO proxy server settings to remove" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                $objStatus.ProxySettingsStatus = "Complete"
                $objStatus.ProxySettingsDetails = "No existing iLO proxy server settings to remove"
                
                # Even though proxy is disabled, check if there's a cached proxy error from previous configuration
                if ($ResetiLOIfProxyErrorPersists) {
                    try {
                        $CheckURI = "/redfish/v1/Managers/1/"
                        $CheckUrl = $iLObaseURL + $CheckURI
                        
                        if ($SkipCertificateValidation) {
                            $CheckResponse = Invoke-RestMethod -Method GET -Uri $CheckUrl -Headers $Headers -ErrorAction Stop -SkipCertificateCheck
                        }
                        else {
                            $CheckResponse = Invoke-RestMethod -Method GET -Uri $CheckUrl -Headers $Headers -ErrorAction Stop
                        }
                        
                        $CurrentFailReason = $CheckResponse.Oem.Hpe.CloudConnect.FailReason
                        $CurrentStatus = $CheckResponse.Oem.Hpe.CloudConnect.CloudConnectStatus
                        
                        "[{0}] {1} [{2}] Current CloudConnect state: Status='{3}', FailReason='{4}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $CurrentStatus, $CurrentFailReason | Write-Verbose
                        
                        # If still showing proxy error even though proxy is disabled, reset iLO to clear cached state
                        if ($CurrentFailReason -match "ProxyOrFirewall") {
                            "[{0}] {1} [{2}] Proxy is disabled but iLO has cached proxy error from previous configuration. Performing iLO reset to clear network stack..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                            
                            try {
                                $ResetURI = "/redfish/v1/Managers/1/Actions/Manager.Reset/"
                                $ResetUrl = $iLObaseURL + $ResetURI
                                $ResetBody = @{ ResetType = "ForceRestart" } | ConvertTo-Json
                                
                                if ($SkipCertificateValidation) {
                                    $null = Invoke-RestMethod -Method POST -Uri $ResetUrl -Headers $Headers -Body $ResetBody -ErrorAction Stop -SkipCertificateCheck
                                }
                                else {
                                    $null = Invoke-RestMethod -Method POST -Uri $ResetUrl -Headers $Headers -Body $ResetBody -ErrorAction Stop
                                }
                                
                                "[{0}] {1} [{2}] iLO reset initiated. Waiting 60 seconds for iLO to restart and clear cached network state..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                                Start-Sleep -Seconds 60
                                
                                # Retry reconnection with multiple attempts
                                "[{0}] {1} [{2}] Attempting to reconnect to iLO after reset..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                                
                                $MaxReconnectAttempts = 6
                                $ReconnectInterval = 10
                                $ReconnectSuccess = $false
                                
                                for ($attempt = 1; $attempt -le $MaxReconnectAttempts; $attempt++) {
                                    try {
                                        # Create new session after reset
                                        $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($iLOCredential.Password)
                                        $iLOPasswordPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($Ptr)
                                        
                                        $ReconnectBody = [System.Collections.Hashtable]@{
                                            UserName = $iLOCredential.UserName
                                            Password = $iLOPasswordPlainText
                                        } | ConvertTo-Json
                                        
                                        $SessionURI = "/redfish/v1/SessionService/Sessions/"
                                        $SessionUrl = $iLObaseURL + $SessionURI
                                        
                                        if ($SkipCertificateValidation) {
                                            $SessionResponse = Invoke-WebRequest -Method POST -Uri $SessionUrl -Body $ReconnectBody -ContentType "application/json" -ErrorAction Stop -SkipCertificateCheck
                                        }
                                        else {
                                            $SessionResponse = Invoke-WebRequest -Method POST -Uri $SessionUrl -Body $ReconnectBody -ContentType "application/json" -ErrorAction Stop
                                        }
                                        
                                        # Extract X-Auth-Token from response headers
                                        $NewXAuthToken = (($SessionResponse.RawContent -split "[`r`n]" | select-string -Pattern 'X-Auth-Token' ) -split " ")[1]
                                        
                                        # Update the Headers hashtable with new token
                                        $Headers['X-Auth-Token'] = $NewXAuthToken
                                        
                                        "[{0}] {1} [{2}] iLO session re-established after reset (attempt {3}/{4})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $attempt, $MaxReconnectAttempts | Write-Verbose
                                        $ReconnectSuccess = $true
                                        
                                        # Clean up sensitive data
                                        $iLOPasswordPlainText = $null
                                        [GC]::Collect()
                                        break
                                    }
                                    catch {
                                        if ($attempt -lt $MaxReconnectAttempts) {
                                            "[{0}] {1} [{2}] iLO not ready yet (attempt {3}/{4}). Waiting {5} seconds before retry..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $attempt, $MaxReconnectAttempts, $ReconnectInterval | Write-Verbose
                                            Start-Sleep -Seconds $ReconnectInterval
                                        }
                                        else {
                                            "[{0}] {1} [{2}] Warning: Failed to reconnect to iLO after {3} attempts: {4}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $MaxReconnectAttempts, $_.Exception.Message | Write-Verbose
                                            "[{0}] {1} [{2}] iLO may be taking longer than expected to restart. Please verify iLO is accessible and retry the connection." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Warning
                                        }
                                    }
                                }
                                
                                if (-not $ReconnectSuccess) {
                                    # Could not reconnect after reset - return error
                                    $ErrorMessage = "iLO reset completed but could not re-establish connection after {0} seconds. Please verify iLO is accessible and retry." -f (60 + ($MaxReconnectAttempts * $ReconnectInterval))
                                    $objStatus.Status = "Failed"
                                    $objStatus.Details = $ErrorMessage
                                    [void] $iLOConnectionStatus.add($objStatus)
                                    return
                                }
                                
                            }
                            catch {
                                "[{0}] {1} [{2}] Warning: iLO reset failed: {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $_.Exception.Message | Write-Verbose
                            }
                        }
                    }
                    catch {
                        "[{0}] {1} [{2}] Warning: Error checking CloudConnect state: {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $_.Exception.Message | Write-Verbose
                    }
                }
            }
            #EndRegion

            #Region----------------------------------------------------------- Enable iLO proxy settings or secure gateway if needed -----------------------------------------------------------------------------
            if ($IloProxyServer) {

                "[{0}] {1} [{2}] iLO attempting iLO proxy server settings" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose

                $AddURI = "/redfish/v1/Managers/1/NetworkProtocol/"

                $url = ( $iLObaseURL + $AddURI)

                if ($IloProxyUserName -and $IloProxyPassword) {
                    
                    $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($IloProxyPassword)
                    $IloProxyPasswordPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($Ptr)

                    $Body = [System.Collections.Hashtable]@{
                        Oem = @{
                            Hpe = @{
                                WebProxyConfiguration = @{
                                    ProxyServer   = $IloProxyServer
                                    ProxyPort     = $IloProxyPort
                                    ProxyUserName = $IloProxyUserName
                                    ProxyPassword = $IloProxyPasswordPlainText
                                }
                            }
                        }
                    } | ConvertTo-Json -d 9

                }
                else {

                    $Body = [System.Collections.Hashtable]@{
                        Oem = @{
                            Hpe = @{
                                WebProxyConfiguration = @{
                                    ProxyServer = $IloProxyServer
                                    ProxyPort   = $IloProxyPort
                                }
                            }
                        }
                    } | ConvertTo-Json -d 9
                }

                "[{0}] {1} [{2}] About to run a POST {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $url | Write-Verbose 
                "[{0}] {1} [{2}] Headers content: `n{3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP, $SerialNumber, (($Headers | ConvertTo-Json -Depth 5) -replace '("X-Auth-Token"\s*:\s*")([^"]+)"', '${1}[REDACTED]"') | Write-Verbose
                "[{0}] {1} [{2}] Body content: `n{3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $Body | Write-Verbose

                try {
                    
                    if ($SkipCertificateValidation) {
                        $Response = Invoke-RestMethod -Method PATCH -Uri $url -Headers $Headers -Body $Body -ErrorAction Stop -SkipCertificateCheck
                    }                        
                    else {
                        $Response = Invoke-RestMethod -Method PATCH -Uri $url -Headers $Headers -Body $Body -ErrorAction Stop
                    }


                    "[{0}] {1} [{2}] - Raw response: `n{3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, ($Response | Out-String) | Write-Verbose

                    $msg = $response.error.'@Message.ExtendedInfo'.MessageId

                    "[{0}] {1} [{2}] - Response: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $msg | Write-Verbose

                    if ($msg -match "Success") {
                        "[{0}] {1} [{2}] - iLO proxy server settings modified successfully!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                        $objStatus.ProxySettingsStatus = "Complete"
                        $objStatus.ProxySettingsDetails = "iLO proxy server settings modified successfully!"
                    }
                    else {
                        "[{0}] {1} [{2}] - iLO proxy server settings modification error!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                        $objStatus.ProxySettingsStatus = "Failed"
                        $objStatus.ProxySettingsDetails = $msg                        
                    }  
                    
                    # Wait for 5 seconds to allow iLO to apply the changes
                    Start-Sleep -Seconds 5

                }
                catch {

                    "[{0}] {1} [{2}] iLO proxy server settings cannot be configured! Error: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $_ | Write-Verbose

                    $objStatus.ProxySettingsStatus = "Failed"
                    $objStatus.ProxySettingsDetails = $_.Exception.message 
                    [void] $iLOConnectionStatus.add($objStatus)
                    return

                }
            }
            else {
                "[{0}] {1} [{2}] No iLO proxy server settings to configure" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
            }
            #EndRegion

            #Region----------------------------------------------------------- Connect iLO to Compute Ops Management -----------------------------------------------------------------------------

            "[{0}] {1} [{2}] Attempting to connect iLO to the Compute Ops Management instance..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose

            # If -DisconnectiLOfromOneView switch used: disconnect iLO from Oneview
            if ($DisconnectiLOfromOneView) { 
                $OverrideManager = $True 
            } 
            else {
                $OverrideManager = $False
            }

            if ($ActivationKeyfromCOM) {
                $ActivationKey = $ActivationKeyfromCOM
            }
            else {
                $ActivationKey = $Global:HPEGreenLakeSession.workspaceId
            }

            $Body = [System.Collections.Hashtable]@{
                ActivationKey   = $ActivationKey
                OverrideManager = $OverrideManager
            } | ConvertTo-Json 

            $AddURI = "/redfish/v1/Managers/1/Actions/Oem/Hpe/HpeiLO.EnableCloudConnect/"
            $url = ($iLObaseURL + $AddURI)    

            "[{0}] {1} [{2}] About to run a POST {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $url | Write-Verbose
            "[{0}] {1} [{2}] Headers content: `n{3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP, $SerialNumber, (($Headers | ConvertTo-Json -Depth 5) -replace '("X-Auth-Token"\s*:\s*")([^"]+)"', '${1}[REDACTED]"') | Write-Verbose
            "[{0}] {1} [{2}] Body content: `n{3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $Body | Write-Verbose

            $currentDate = Get-Date 
            $counter = 1

            # Define the spinning cursor characters
            $spinner = @('|', '/', '-', '\')

            # Get the current width of the terminal window                
            $terminalWidth = (Get-Host).UI.RawUI.WindowSize.Width                    

            # Create a clear line string based on the terminal width to ensure the entire line is overwritten
            $clearLine = " " * ($terminalWidth - 1)

            # Function to display spinner output consistently
            function Write-SpinnerOutput {
                param(
                    [string]$Message,
                    [string]$SpinnerChar
                )
                $output = "{0}  {1}" -f $Message, $SpinnerChar
                Write-Host "`r$clearLine`r$output" -NoNewline -ForegroundColor Yellow
            }

            # Function to clear spinner output
            function Clear-SpinnerOutput {
                Write-Host "`r$clearLine`r" -NoNewline
            }

            try {
                # Get initial cloud connect status
                $CloudConnectStatusParams = @{
                    Method  = 'GET'
                    Uri     = ($iLObaseURL + "/redfish/v1/Managers/1/")
                    Headers = $Headers
                }
                if ($SkipCertificateValidation) {
                    $CloudConnectStatusParams.SkipCertificateCheck = $true
                }

                "[{0}] {1} [{2}] About to run a GET {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, ($iLObaseURL + "/redfish/v1/Managers/1/") | Write-Verbose
                "[{0}] {1} [{2}] Headers content: `n{3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP, $SerialNumber, (($Headers | ConvertTo-Json -Depth 5) -replace '("X-Auth-Token"\s*:\s*")([^"]+)"', '${1}[REDACTED]"') | Write-Verbose

                $CloudConnectStatus = (Invoke-RestMethod @CloudConnectStatusParams).Oem.Hpe.CloudConnect.CloudConnectStatus
                "[{0}] {1} [{2}] Status of the iLO connection to COM: {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $CloudConnectStatus | Write-Verbose

                # If -Force specified and iLO is already connected, disconnect first to allow reconnection
                if ($Force -and $CloudConnectStatus -eq "Connected") {

                    "[{0}] {1} [{2}] -Force specified: disconnecting iLO from COM to force reconnection..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose

                    try {
                        $DisableCloudConnectURI = "/redfish/v1/Managers/1/Actions/Oem/Hpe/HpeiLO.DisableCloudConnect/"
                        $DisableCloudConnectUrl = $iLObaseURL + $DisableCloudConnectURI
                        $DisableCloudConnectBody = @{} | ConvertTo-Json

                        $DisableParams = @{
                            Method      = 'POST'
                            Uri         = $DisableCloudConnectUrl
                            Headers     = $Headers
                            Body        = $DisableCloudConnectBody
                            ErrorAction = 'Stop'
                        }
                        if ($SkipCertificateValidation) {
                            $DisableParams.SkipCertificateCheck = $true
                        }

                        $null = Invoke-RestMethod @DisableParams
                        "[{0}] {1} [{2}] DisableCloudConnect sent. Polling until iLO disconnects from COM..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose

                        # Poll until disconnected (up to ~30 seconds)
                        $disconnectCounter = 0
                        do {
                            Start-Sleep -Seconds 3
                            $disconnectCounter++
                            $CloudConnectStatus = (Invoke-RestMethod @CloudConnectStatusParams).Oem.Hpe.CloudConnect.CloudConnectStatus
                            "[{0}] {1} [{2}] CloudConnect status after force-disconnect: '{3}' (check {4}/10)" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $CloudConnectStatus, $disconnectCounter | Write-Verbose
                        } while ($CloudConnectStatus -eq "Connected" -and $disconnectCounter -le 10)

                        if ($CloudConnectStatus -ne "Connected") {
                            "[{0}] {1} [{2}] iLO successfully disconnected from COM. Waiting 10 seconds for iLO network stack to stabilize before reconnecting..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                            Start-Sleep -Seconds 10
                        }
                        else {
                            "[{0}] {1} [{2}] iLO could not be disconnected from COM within the polling window. Proceeding with reconnection attempt anyway..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                        }
                    }
                    catch {
                        "[{0}] {1} [{2}] Error during Force disconnect: {3}. Re-checking CloudConnect status..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $_.Exception.Message | Write-Verbose
                        try {
                            $CloudConnectStatus = (Invoke-RestMethod @CloudConnectStatusParams).Oem.Hpe.CloudConnect.CloudConnectStatus
                        }
                        catch {
                            $CloudConnectStatus = "NotConnected"
                        }
                    }
                }

                if ($CloudConnectStatus -ne "Connected") {

                    $iLOConnectiontoCOMResponse = $null
                    $PollingLoopResetDone = $false  # Guard to prevent infinite reset loops inside the polling loop
                
                    do {
                        try {
                            "[{0}] {1} [{2}] About to run POST {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $url | Write-Verbose

                            # Prepare POST request parameters
                            $PostParams = @{
                                Method      = 'POST'
                                Uri         = $url
                                Body        = $Body
                                Headers     = $Headers
                                ErrorAction = 'SilentlyContinue'
                            }
                            if ($SkipCertificateValidation) {
                                $PostParams.SkipCertificateCheck = $true
                            }

                            $iLOConnectiontoCOMResponse = Invoke-RestMethod @PostParams 
                            $subcounter = 0
                        
                            "[{0}] {1} [{2}] About to run GET {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, ($iLObaseURL + "/redfish/v1/Managers/1/") | Write-Verbose

                            do {                           
                                $ManagerInfo = Invoke-RestMethod @CloudConnectStatusParams
                                $CloudConnectStatus = $ManagerInfo.Oem.Hpe.CloudConnect.CloudConnectStatus
                                $FailReason = $ManagerInfo.Oem.Hpe.CloudConnect.FailReason
                                $WebConnectivity = $ManagerInfo.Oem.Hpe.CloudConnect.ExtendedStatusInfo.WebConnectivity
                                
                                "[{0}] {1} [{2}] Connection to COM status: '{3}' - FailReason: '{4}' - WebConnectivity: '{5}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $CloudConnectStatus, $FailReason, $WebConnectivity | Write-Verbose
                            
                                # Check for actual errors (not "NotTested", not "Initializing" which is transient after a reset, not success indicators like "Already_Connected", and not "DisabledByCOM")
                                # DisabledByCOM means the device IS connected but disabled by COM (administrative state, not a connection failure)
                                # Initializing means the iLO is still starting up its network stack — treat as transient, not a failure
                                if ($FailReason -and $FailReason -ne "NotTested" -and $FailReason -ne "Initializing" -and $FailReason -notmatch "Already|Connected|DisabledByCOM") {
                                    Clear-SpinnerOutput
                                    "[{0}] {1} [{2}] Error detected - FailReason: '{3}', WebConnectivity: '{4}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $FailReason, $WebConnectivity | Write-Verbose
                                    
                                    # When -ResetiLOIfProxyErrorPersists is set and a ProxyOrFirewall error surfaces during connection monitoring,
                                    # perform an iLO reset to clear the cached network state. The one-shot guard prevents infinite reset loops.
                                    if ($FailReason -match "ProxyOrFirewall" -and $ResetiLOIfProxyErrorPersists -and -not $PollingLoopResetDone) {
                                        $PollingLoopResetDone = $true
                                        "[{0}] {1} [{2}] ProxyOrFirewall error detected during connection monitoring. Performing iLO reset to clear cached network state..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                                        
                                        try {
                                            $ResetURI = "/redfish/v1/Managers/1/Actions/Manager.Reset/"
                                            $ResetUrl = $iLObaseURL + $ResetURI
                                            $ResetBody = @{ ResetType = "ForceRestart" } | ConvertTo-Json
                                            
                                            if ($SkipCertificateValidation) {
                                                $null = Invoke-RestMethod -Method POST -Uri $ResetUrl -Headers $Headers -Body $ResetBody -ErrorAction Stop -SkipCertificateCheck
                                            }
                                            else {
                                                $null = Invoke-RestMethod -Method POST -Uri $ResetUrl -Headers $Headers -Body $ResetBody -ErrorAction Stop
                                            }
                                            
                                            "[{0}] {1} [{2}] iLO reset initiated. Waiting 60 seconds for iLO to restart and clear cached network state..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                                            Start-Sleep -Seconds 60
                                            
                                            "[{0}] {1} [{2}] Attempting to reconnect to iLO after reset..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                                            
                                            $MaxReconnectAttempts = 6
                                            $ReconnectInterval = 10
                                            $ReconnectSuccess = $false
                                            
                                            for ($attempt = 1; $attempt -le $MaxReconnectAttempts; $attempt++) {
                                                try {
                                                    $Ptr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($iLOCredential.Password)
                                                    $iLOPasswordPlainText = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($Ptr)
                                                    
                                                    $ReconnectBody = [System.Collections.Hashtable]@{
                                                        UserName = $iLOCredential.UserName
                                                        Password = $iLOPasswordPlainText
                                                    } | ConvertTo-Json
                                                    
                                                    $SessionURI = "/redfish/v1/SessionService/Sessions/"
                                                    $SessionUrl = $iLObaseURL + $SessionURI
                                                    
                                                    if ($SkipCertificateValidation) {
                                                        $SessionResponse = Invoke-WebRequest -Method POST -Uri $SessionUrl -Body $ReconnectBody -ContentType "application/json" -ErrorAction Stop -SkipCertificateCheck
                                                    }
                                                    else {
                                                        $SessionResponse = Invoke-WebRequest -Method POST -Uri $SessionUrl -Body $ReconnectBody -ContentType "application/json" -ErrorAction Stop
                                                    }
                                                    
                                                    $NewXAuthToken = (($SessionResponse.RawContent -split "`r`n" | select-string -Pattern 'X-Auth-Token') -split " ")[1]
                                                    $Headers['X-Auth-Token'] = $NewXAuthToken
                                                    
                                                    "[{0}] {1} [{2}] iLO session re-established after reset (attempt {3}/{4})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $attempt, $MaxReconnectAttempts | Write-Verbose
                                                    $ReconnectSuccess = $true
                                                    
                                                    $iLOPasswordPlainText = $null
                                                    [GC]::Collect()
                                                    break
                                                }
                                                catch {
                                                    if ($attempt -lt $MaxReconnectAttempts) {
                                                        "[{0}] {1} [{2}] iLO not ready yet (attempt {3}/{4}). Waiting {5} seconds before retry..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $attempt, $MaxReconnectAttempts, $ReconnectInterval | Write-Verbose
                                                        Start-Sleep -Seconds $ReconnectInterval
                                                    }
                                                    else {
                                                        "[{0}] {1} [{2}] Warning: Failed to reconnect to iLO after {3} attempts: {4}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $MaxReconnectAttempts, $_.Exception.Message | Write-Verbose
                                                        "[{0}] {1} [{2}] iLO may be taking longer than expected to restart. Please verify iLO is accessible and retry the connection." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Warning
                                                    }
                                                }
                                            }
                                            
                                            if (-not $ReconnectSuccess) {
                                                $objStatus.iLOConnectionStatus = "Failed"
                                                $objStatus.iLOConnectionDetails = "iLO reset completed to clear proxy error, but could not re-establish iLO session. Please verify iLO is accessible and retry."
                                                $objStatus.Status = "Failed"
                                                [void] $iLOConnectionStatus.add($objStatus)
                                                return
                                            }
                                            
                                            # Re-issue EnableCloudConnect to retry the connection with the now-cleared iLO network state
                                            "[{0}] {1} [{2}] Re-issuing EnableCloudConnect POST after iLO reset to retry connection..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                                            $iLOConnectiontoCOMResponse = Invoke-RestMethod @PostParams
                                            Start-Sleep -Seconds 2
                                            
                                            # Refresh CloudConnect status so the do-while condition evaluates correctly when we continue
                                            $RefreshInfo = Invoke-RestMethod @CloudConnectStatusParams
                                            $CloudConnectStatus = $RefreshInfo.Oem.Hpe.CloudConnect.CloudConnectStatus
                                            $FailReason = $RefreshInfo.Oem.Hpe.CloudConnect.FailReason
                                            $WebConnectivity = $RefreshInfo.Oem.Hpe.CloudConnect.ExtendedStatusInfo.WebConnectivity
                                            "[{0}] {1} [{2}] Post-reset CloudConnect state before resuming monitoring: Status='{3}', FailReason='{4}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $CloudConnectStatus, $FailReason | Write-Verbose
                                            
                                            $subcounter = 0
                                            continue  # Resume the inner polling loop to monitor the new connection attempt
                                        }
                                        catch {
                                            "[{0}] {1} [{2}] Warning: iLO reset failed: {3}. Falling through to standard error handler..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $_.Exception.Message | Write-Verbose
                                            # Fall through to standard error path below
                                        }
                                    }
                                    
                                    # Format user-friendly error message
                                    $errorDetail = switch -Regex ($FailReason) {
                                        "ProxyOrFirewall" { "Proxy or Firewall Issue - Check network connectivity and proxy settings" }
                                        default { $FailReason -replace "_", " " }
                                    }
                                    
                                    # If this is a proxy error and we just removed proxy settings, suggest using reset parameter
                                    if ($RemoveExistingiLOProxySettings -and $FailReason -match "ProxyOrFirewall" -and -not $ResetiLOIfProxyErrorPersists) {
                                        "[{0}] {1} [{2}] WARNING: Proxy error persists after proxy removal due to iLO firmware limitation (cached network state)." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Warning
                                        "[{0}] {1} [{2}] RECOMMENDATION: Use -ResetiLOIfProxyErrorPersists parameter to automatically reset iLO and clear cached state." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Warning
                                    }
                                    
                                    $objStatus.iLOConnectionStatus = "Failed"
                                    $objStatus.iLOConnectionDetails = "iLO cannot be connected to Compute Ops Management! $errorDetail"
                                    $objStatus.Status = "Failed"
                                    [void]$iLOConnectionStatus.add($objStatus)
                                    return
                                }

                                # Calculate the current spinner character
                                $spinnerChar = $spinner[$subcounter % $spinner.Length]
                            
                                # Display the spinner character
                                $message = "[{0}] -- iLO '{1}' - Connection to COM status: '{2}'" -f $IloIP, $SerialNumber, $CloudConnectStatus
                                Write-SpinnerOutput -Message $message -SpinnerChar $spinnerChar
                            
                                $subcounter++
                                "[{0}] {1} [{2}] Waiting for iLO to connect to COM... (check {3})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $subcounter | Write-Verbose
                                Start-Sleep -Seconds 4
                            
                            } while (($CloudConnectStatus -eq "ConnectionInProgress" -or $FailReason -eq "Initializing") -and $subcounter -le ([Math]::Ceiling($ConnectionMonitoringTimeoutSeconds / 4))) # Dynamic timeout based on parameter 

                            # After monitoring loop completes, check FailReason one more time
                            if ($CloudConnectStatus -eq "NotConnected") {
                                $FinalManagerInfo = Invoke-RestMethod @CloudConnectStatusParams
                                $FinalFailReason = $FinalManagerInfo.Oem.Hpe.FailReason
                                
                                if ($FinalFailReason) {
                                    Clear-SpinnerOutput
                                    "[{0}] {1} [{2}] FailReason detected after monitoring: {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $FinalFailReason | Write-Verbose
                                    $objStatus.iLOConnectionStatus = "Failed"
                                    $objStatus.iLOConnectionDetails = "iLO cannot be connected to Compute Ops Management! $FinalFailReason"
                                    $objStatus.Status = "Failed"
                                    [void]$iLOConnectionStatus.add($objStatus)
                                    return
                                }
                            }

                            # Process response inside try to catch errors
                            if ($iLOConnectiontoCOMResponse -and $iLOConnectiontoCOMResponse.PSObject.Properties['error'] -and $iLOConnectiontoCOMResponse.error.'@Message.ExtendedInfo') {
                                $msg = $iLOConnectiontoCOMResponse.error.'@Message.ExtendedInfo'.MessageId
                                "[{0}] {1} [{2}] Response: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $msg | Write-Verbose

                                if ($msg -notmatch "Success") {
                                    Clear-SpinnerOutput
                                    "[{0}] {1} [{2}] Error to the attempt to connect to COM!: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $msg | Write-Verbose
                                    $objStatus.iLOConnectionStatus = "Failed"
                                    $objStatus.iLOConnectionDetails = "iLO cannot be connected to Compute Ops Management!"
                                    $objStatus.Exception = "Error: {0}" -f $msg
                                    $objStatus.Status = "Failed"
                                    [void]$iLOConnectionStatus.add($objStatus)
                                    return
                                }
                            }
                            else {
                                $msg = "AlreadyConnected"
                                "[{0}] {1} [{2}] iLO is already connected to a COM instance!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                            }

                            $counter++
                            "[{0}] {1} [{2}] Completed connection attempt {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $counter | Write-Verbose

                        } 
                        catch {
                            "[{0}] Catch triggered! {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_ | Write-Verbose
                        
                            # Check if the error message indicates "Connection in progress" (including COMActivationDenied when a connection attempt is already in-flight)
                            if ($_ -match "Connection in progress" -and $counter -le $MaxConnectionAttempts) {
                                "[{0}] {1} [{2}] Connection in progress, retrying (attempt {3})..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $counter | Write-Verbose
                                Start-Sleep -Seconds $ConnectionRetryDelaySeconds
                            } 
                            else {
                                Clear-SpinnerOutput
                                $MessageId = if ($_.Exception.Response) { $_.Exception.Response.StatusCode.value__ } else { "Unknown" }
                                $errorMessage = $_.Exception.Message
                                "[{0}] {1} [{2}] iLO connection to COM error! Message ID: {3} - Message: {4}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $MessageId, $errorMessage | Write-Verbose
                                $objStatus.iLOConnectionStatus = "Failed"
                                $objStatus.iLOConnectionDetails = "iLO cannot be connected to Compute Ops Management! Check the iLO logs."
                                $objStatus.Exception = "Error: '$errorMessage'"
                                $objStatus.Status = "Failed"
                                [void]$iLOConnectionStatus.add($objStatus)
                                return
                            }
                        }
                        
                    } until ($CloudConnectStatus -eq "Connected" -or ($FailReason -eq "DisabledByCOM" -and $WebConnectivity -eq "Connected") -or $counter -gt $MaxConnectionAttempts)      
                
                    if ($counter -gt $MaxConnectionAttempts) {
                        Clear-SpinnerOutput
                    
                        # Check Oem.Hpe.FailReason using Views endpoint (same as iLO UI)
                        try {
                            "[{0}] {1} [{2}] Connection timeout - Checking iLO FailReason via Views endpoint..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose

                            $ViewsBody = @{
                                Select = @(
                                    @{
                                        From       = "/Managers/1/"
                                        Properties = @(
                                            "Oem.Hpe.CloudConnect as CloudConnect",
                                            "Oem.Hpe.FailReason as FailReason"
                                        )
                                    }
                                )
                            } | ConvertTo-Json -Depth 5

                            $ViewsParams = @{
                                Method      = 'POST'
                                Uri         = ($iLObaseURL + "/redfish/v1/Views/")
                                Headers     = $Headers
                                Body        = $ViewsBody
                                ContentType = 'application/json'
                            }
                            if ($SkipCertificateValidation) {
                                $ViewsParams.SkipCertificateCheck = $true
                            }

                            "[{0}] {1} [{2}] About to POST {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, ($iLObaseURL + "/redfish/v1/Views/") | Write-Verbose
                            "[{0}] {1} [{2}] Views Body: `n{3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $ViewsBody | Write-Verbose

                            $ViewsData = Invoke-RestMethod @ViewsParams
                            $FailReason = $ViewsData.FailReason
                            $CloudConnectStatus = $ViewsData.CloudConnect.CloudConnectStatus
                        
                            if ($FailReason) {
                                "[{0}] {1} [{2}] FailReason found: {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $FailReason | Write-Verbose
                                $objStatus.iLOConnectionDetails = "iLO cannot be connected to Compute Ops Management! $FailReason"
                            }
                            else {
                                "[{0}] {1} [{2}] No FailReason found. CloudConnect status: {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $CloudConnectStatus | Write-Verbose
                                $objStatus.iLOConnectionDetails = "iLO cannot be connected to Compute Ops Management! Connection timeout - Check network connectivity, proxy settings, and firewall rules."
                            }
                        }
                        catch {
                            "[{0}] {1} [{2}] Error retrieving FailReason via Views: {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $_ | Write-Verbose
                            $objStatus.iLOConnectionDetails = "iLO cannot be connected to Compute Ops Management! Connection timeout - Unable to retrieve error details."
                        }

                        $objStatus.iLOConnectionStatus = "Failed"
                        $objStatus.Status = "Failed"
                        [void] $iLOConnectionStatus.add($objStatus)
                        return
                    }
                    else {
                        Clear-SpinnerOutput
                        $counter2 = 1

                        do {
                            # Calculate the current spinner character
                            $spinnerChar = $spinner[$counter2 % $spinner.Length]
                        
                            # Display the spinner character
                            $message = "[{0}] -- iLO '{1}' - Checking the availability of the device in the workspace..." -f $IloIP, $SerialNumber
                            Write-SpinnerOutput -Message $message -SpinnerChar $spinnerChar

                            $DeviceFoundinGLP = Get-HPEGLDevice -Name $SerialNumber
                            Start-Sleep -Milliseconds 1000
                            $counter2++
                            "[{0}] {1} [{2}] Device not found in the workspace. Checking again (attempt {3})..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $counter2 | Write-Verbose

                        } until ($null -ne $DeviceFoundinGLP -or $counter2 -gt 7)

                        Clear-SpinnerOutput

                        if ($DeviceFoundinGLP) {
                            "[{0}] {1} [{2}] Device found in the HPE GreenLake workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                        }
                        else {
                            "[{0}] {1} [{2}] Device not found in the HPE GreenLake workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                        }

                        # Determine final status based on message and device presence
                        if ($msg -match "Success" -and $DeviceFoundinGLP) {
                            "[{0}] {1} [{2}] iLO successfully connected to Compute Ops Management!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                            $objStatus.iLOConnectionStatus = "Complete"
                            $objStatus.iLOConnectionDetails = "iLO successfully connected to the Compute Ops Management instance!"
                        }
                        elseif ($msg -eq "AlreadyConnected" -and $DeviceFoundinGLP) {
                            "[{0}] {1} [{2}] iLO already connected to Compute Ops Management!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                            $objStatus.iLOConnectionStatus = "Complete"
                            $objStatus.iLOConnectionDetails = "iLO is already connected to the Compute Ops Management instance!"
                        }
                        elseif ($msg -eq "AlreadyConnected" -and $null -eq $DeviceFoundinGLP) {
                            "[{0}] {1} [{2}] iLO already connected to a Compute Ops Management instance - The device cannot be found in the workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                            $objStatus.iLOConnectionStatus = "Warning"
                            $objStatus.iLOConnectionDetails = "iLO is already connected, but to a different Compute Ops Management instance!"
                        }
                        elseif ($msg -match "Success" -and $null -eq $DeviceFoundinGLP) {
                            # Check the iLO event log to detect any error message 
                            try {
                                $EventLogParams = @{
                                    Method  = 'GET'
                                    Uri     = ($iLObaseURL + "/redfish/v1/Managers/1/LogServices/IEL/Entries/")
                                    Headers = $Headers
                                }
                                if ($SkipCertificateValidation) {
                                    $EventLogParams.SkipCertificateCheck = $true
                                }

                                $iLOEventLogs = (Invoke-RestMethod @EventLogParams).Members
                                $iLOEventLogErrorMessages = $iLOEventLogs | 
                                Sort-Object -Property Created -Descending | 
                                Where-Object { 
                                    [DateTime]::Parse($_.Created).ToLocalTime() -gt $currentDate -and 
                                    $_.Message -match "(?i)Compute Ops Management.*failed|failed.*Compute Ops Management" 
                                }
                            
                                $FormattediLOEventLogErrorMessages = ($iLOEventLogErrorMessages | Select-Object -ExpandProperty Message) -join "`n"
                            
                                if ($FormattediLOEventLogErrorMessages) {
                                    $objStatus.iLOConnectionDetails = $FormattediLOEventLogErrorMessages
                                }
                                else {
                                    $objStatus.iLOConnectionDetails = "Connection reported success but device not found in workspace. Check COM service status."
                                }
                            }
                            catch {
                                "[{0}] {1} [{2}] Error retrieving event logs: {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $_ | Write-Verbose
                                $objStatus.iLOConnectionDetails = "Connection reported success but device not found in workspace and unable to retrieve event logs."
                            }
                        
                            $objStatus.iLOConnectionStatus = "Failed"
                            $objStatus.Status = "Failed"
                            [void] $iLOConnectionStatus.add($objStatus)
                            return
                        }
                        else {
                            $objStatus.iLOConnectionStatus = "Complete"
                            $objStatus.iLOConnectionDetails = "iLO successfully connected to Compute Ops Management!"
                        }
                    }   
                }
                else {
                    "[{0}] {1} [{2}] iLO already connected to Compute Ops Management!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                    if ($Force) {
                        $objStatus.iLOConnectionStatus = "Warning"
                        $objStatus.iLOConnectionDetails = "iLO is already connected to the Compute Ops Management instance and could not be force-disconnected. Use -Verbose for details."
                    }
                    else {
                        $objStatus.iLOConnectionStatus = "Complete"
                        $objStatus.iLOConnectionDetails = "iLO is already connected to the Compute Ops Management instance!"
                    }
                }
            }
            catch {
                Clear-SpinnerOutput
                $errorMessage = "Unexpected error during iLO connection process: $_"
                Write-Error $errorMessage
            
                $objStatus.iLOConnectionStatus = "Failed"
                $objStatus.iLOConnectionDetails = "Unexpected error during connection process."
                $objStatus.Exception = "Error: '{0}'" -f $_
                $objStatus.Status = "Failed"
                [void] $iLOConnectionStatus.add($objStatus)
                return
            }
            #EndRegion
        }
        else {
            "[{0}] {1} [{2}] iLO is not supported by HPE GreenLake! Skipping server..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP, $SerialNumber | Write-Verbose
            
            $objStatus.Status = "Warning" 
            $objStatus.Details = "Only iLO5, iLO6 and iLO7 are supported by HPE GreenLake."
        }   

        # Final status determination
        if ($objStatus.PSobject.Properties.value -contains "Failed") {
            $objStatus.Status = "Failed"
        }
        elseif ($objStatus.PSobject.Properties.value -contains "Warning") {
            $objStatus.Status = "Warning"
        }
        else {
            $objStatus.Status = "Complete"
        }

        # Ensure status is added to collection
        [void] $iLOConnectionStatus.add($objStatus)

    }

    end {

        if ($iLOConnectionStatus.Count -gt 0) {
            Return Invoke-RepackageObjectWithType -RawObject $iLOConnectionStatus -ObjectName "Device.Connect.iLO"
        }
    }
        
}


Function Add-HPEGLDeviceStorage {
    <#
    .SYNOPSIS
    Add storage device(s) to HPE GreenLake. 

    .DESCRIPTION
    This Cmdlet adds storage device(s) to the currently connected HPE GreenLake workspace. It can optionally add tags during the onboarding process.  
    Devices must meet the requirements of the Data Services and be on the list of supported systems.    
   
    .PARAMETER SerialNumber
    Serial number of the storage device to be added. 
    The serial number can be found in the order confirmation email or in the email received after you activate the storage device software. 
    For Nimble devices, it can be retrieved from the Storage System UI or the pull-out tab.

    .PARAMETER PartNumber 
    Part number of the device to be added. 

   .PARAMETER Tags
    Optional parameter to add tags to the device. Tags must meet the following string format: <Name>=<Value>, <Name>=<Value>.

    Supported tags example:
        - "Country=US"
        - "Country=US,State=TX,App=Grafana" 
        - "Country=US, State =TX ,App= Grafana "
            -> Produces the same result as the previous example.
        - "Private note=this is my tag note value,Email=Chris@email.com,City=New York" 
        - "Private note = this is my tag note value , Email = Chris@email.com , City=New York "
            -> Produces the same result as the previous example.  

    Refer to HPE GreenLake tagging specifications:
    https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us&docLocale=en_US&page=GUID-1E4DDAEA-E799-418F-90C8-30CE6A2873AB.html
        - Resources that support tagging can have up to 25 tags per resource.
        - Tag keys and values are case-insensitive.
        - There can be only one value for a particular tag key for a given resource.
        - Null is not allowed as a possible value for a tag key; instead, an empty string ("") will be supported to enable customers to use tag key-value pairs for labeling.
        - System-defined tags are allowed and start with the prefix "hpe:". User-defined tags cannot start with this prefix.
        - Tag keys must have 1-128 characters.
        - Tag values can have a maximum of 256 characters.
        - Allowed characters include letters, numbers, spaces representable in UTF-8, and the following characters: _ . : + - @.

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Add-HPEGLDeviceStorage -SerialNumber "123456789012" -PartNumber "879991-B21" -Tags "Country=US, Hypersior App=ESXi, City=New York"
    
    Adds a storage device to the currently connected HPE GreenLake workspace using a serial number and part number and assigns three tags.

    .EXAMPLE
    Import-Csv Storage_Devices.csv  | Add-HPEGLDeviceStorage -Tags "Location=Houston"

    Adds all storage devices listed in a `Storage_Devices.csv` file to the currently connected HPE GreenLake workspace and assigns the same location tag to all devices.

    The content of the CSV file must use the following format:
        SerialNumber, PartNumber
        AF-23454852, Pxxxxx-B21
        AF-32331565, Pxxxxx-B21
        AF-32331597, Pxxxxx-B21
 
    .EXAMPLE
    Import-Csv Storage_Devices.csv -Delimiter ";"  | Add-HPEGLDeviceStorage 
    
    Adds all storage devices listed in a `Storage_Devices.csv` file to the currently connected HPE GreenLake workspace and assigns tags as defined in the 'Tags' column of the CSV file.

    The content of the CSV file must use the following format:
        SerialNumber; PartNumber; Tags
        AF-23454852; Pxxxxx-B21; Country=US, State=PACA, App=RH
        AF-32331565; Pxxxxx-B21; State=Texas, Role=production
        AF-32331597; Pxxxxx-B21

        Note that for `AF-32331597`, no tags are assigned in this example.              

    .EXAMPLE
    $devices = @(
        [PSCustomObject]@{SerialNumber = 'AF-23454852'; PartNumber = 'Pxxxxx-B21' },
        [PSCustomObject]@{SerialNumber = 'AF-32331565'; PartNumber = 'Pxxxxx-B21' }
    )

    $devices | Add-HPEGLDeviceStorage
    
    Add all storage devices (2) listed in $devices with the specified serial number and part number keys.
    
    .EXAMPLE
    $devices = @(
        [PSCustomObject]@{SerialNumber = '123456789012'; PartNumber = 'Pxxxxx-B21'; Tags = 'Country=US, State=PACA, App=RH' },
        [PSCustomObject]@{SerialNumber = '123432356789'; PartNumber = 'Pxxxxx-B21'; Tags = 'State=Texas, Role=production' }
    )

    $devices | Add-HPEGLDeviceStorage 
    
    Adds all storage devices (2) listed in `$devices` with the specified serial numbers and part numbers and assigns them different tags.

    .INPUTS
    System.Collections.ArrayList
        List of Device(s) with serialnumber, partnumber and tags properties. 

    .OUTPUTS
    System.Collections.ArrayList
        Returns a custom status object containing the following PsCustomObject keys:  
        * SerialNumber - Serial number of the device attempted to be added
        * PartNumber - Part number of the device attempted to be added
        * TagsAdded - List of tags to assign to the device (if any)
        * Status - Status of the device onboarding attempt (Failed for HTTP error return; Complete if onboarding is successful; Warning if no action is needed) 
        * Details - More information about the onboarding status of the device, which includes a PSCustomObject with:
          - TagsAdded - The number of tags added to the device.
          - Error - More information on a warning or failed status error.
        * Exception - Information about any exceptions generated during the operation.

    
   #>

    [CmdletBinding()]
    Param( 
        
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String]$SerialNumber,

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String]$PartNumber,

        [Parameter (ValueFromPipelineByPropertyName)]
        [String]$Tags,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-DevicesAddUri

        $InputList = [System.Collections.ArrayList]::new()
        $ObjectStatusList = [System.Collections.ArrayList]::new()
        $DevicesToAddList = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build tracking object for the output
        $objStatus = [pscustomobject]@{
  
            SerialNumber = $SerialNumber
            PartNumber   = $PartNumber
            TagsAdded    = $Tags
            Status       = $Null
            Details      = $Null
            Exception    = $Null
                  
        }

       
        # Add tracking object to the input list (always) and output list (only when not WhatIf)
        [void]$InputList.Add($objStatus)
        if (-not $WhatIf) { [void]$ObjectStatusList.Add($objStatus) }

    }

    end {        

        try {
            $Devices = Get-HPEGLdevice 
        
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        
        foreach ($DeviceToAdd in $InputList) {
            
            
            $ErrorFoundInTags = $False

            $Device = $Devices | Where-Object serialNumber -eq $DeviceToAdd.SerialNumber
            
            
            if ( $Device) {

                $DeviceToAdd.Status = "Warning"
                $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Device already present in the workspace!" }
                $DeviceToAdd.TagsAdded = $Null
                
                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource already present in the workspace!" -f $DeviceToAdd.SerialNumber
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }
            } 
            else {
                
                if ($DeviceToAdd.TagsAdded) {
                    
                    "[{0}] {1}: Object TagsAdded content: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DeviceToAdd.serialnumber, $DeviceToAdd.TagsAdded | Write-Verbose

                    $splittedtags = $DeviceToAdd.TagsAdded.split(",")

                    if ($splittedtags.Length -gt 25) {
                        
                        $DeviceToAdd.Status = "Warning"
                        $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Too many tags defined ! A maximum of 25 tags per resource is supported!" }
                        $DeviceToAdd.TagsAdded = $Null
                        $ErrorFoundInTags = $True


                        if ($WhatIf) {
                            $ErrorMessage = "Device '{0}': Resource is defined with too many tags! A maximum of 25 tags per resource is supported!" -f $DeviceToAdd.SerialNumber
                            Write-Warning "$ErrorMessage Cannot display API request."
                            continue
                        }
                    }
                    else {

                        # Object for the tracking object
                        $TagsList = [System.Collections.ArrayList]::new()
                        # Object for the payload
                        $TagsArray = @{}
                                
                        foreach ($tag in $splittedtags) {
    
                            # Check tag format, if format is not <tagname>=<value>, return error
                            if ($tag -notmatch '^[\p{L}\p{Nd}_ .:+\-@]+\=[\p{L}\p{Nd}_ .:+\-@]*$') {
                                
                                $splittedtagName = $tag.TrimEnd().TrimStart()
    
                                $DeviceToAdd.Status = "Warning"
                                $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Tag format '$splittedtagName' not supported! Expected format is <tagname>=<value>, <tagname>=<value>!" }
                                $DeviceToAdd.TagsAdded = $Null
                                $ErrorFoundInTags = $True
    
                                if ($WhatIf) {
                                    $ErrorMessage = "Device '{0}': Tag '{1}' format not supported! Expected format is <tagname>=<value>, <tagname>=<value>!" -f $DeviceToAdd.SerialNumber, $splittedtagName
                                    Write-Warning "$ErrorMessage Cannot display API request."
                                    break
                                }
                            }
                            else {
    
                                # Split only at the first '=' to preserve values containing '='
                                $eqIndex = $tag.IndexOf('=')
                                $tagname = $tag.Substring(0, $eqIndex).Trim()

        
                                if ($tagname.Length -gt 128) {
        
                                    $DeviceToAdd.Status = "Warning"
                                    $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Tag name '$tagname' is over 128 characters! Tag names can have a maximum of 128 characters!" }
                                    $DeviceToAdd.TagsAdded = $Null
                                    $ErrorFoundInTags = $True
                                    
                                    if ($WhatIf) {
                                        $ErrorMessage = "Device '{0}': Tag name '{1}' is over 128 characters! Tag names can have a maximum of 128 characters!" -f $DeviceToAdd.SerialNumber, $tagname
                                        Write-Warning "$ErrorMessage Cannot display API request."
                                        break
                                    }
                                }
                                else {
                                    
                                    $tagvalue = $tag.Substring($eqIndex + 1).Trim()
                                    


            
                                    if ($tagvalue.Length -gt 256) {
            
                                        $DeviceToAdd.Status = "Warning"
                                        $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Tag value '$tagvalue' is over 256 characters! Tag values can have a maximum of 256 characters!" }
                                        $DeviceToAdd.TagsAdded = $Null
                                        $ErrorFoundInTags = $True
            
                                        if ($WhatIf) {
                                            $ErrorMessage = "Device '{0}': Tag value '{1}' is over 256 characters! Tag values can have a maximum of 256 characters!" -f $DeviceToAdd.SerialNumber, $tagvalue
                                            Write-Warning "$ErrorMessage Cannot display API request."
                                            break
                                        }
                                    }
                                    else {
    
                                        $TagsArray.$tagname = $tagvalue 
                
                                        $TagsList += [PSCustomObject]@{
                                            name  = $tagname
                                            value = $tagvalue 
                                        }
                                    }
                                }
                            }
                        } 
                    }


                    if ($TagsList -and -not $ErrorFoundInTags) {
                        
                        $DeviceToAdd.TagsAdded = $TagsList
                    }
    
                }
                else {
    
                    "[{0}] {1}: No tags to add" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DeviceToAdd.serialnumber | Write-Verbose
    
                }
                
                

                # Build DeviceList object

                if (-not $ErrorFoundInTags) {

                    # If tags
                    if ($DeviceToAdd.TagsAdded) {
                    
                        $DeviceList = [PSCustomObject]@{
                            serialNumber = $DeviceToAdd.SerialNumber
                            partNumber   = $DeviceToAdd.PartNumber 
                            tags         = $TagsArray 
                        }
                    }
                    # If no tags
                    else {
                        
                        $DeviceList = [PSCustomObject]@{
                            serialNumber = $DeviceToAdd.SerialNumber
                            partNumber   = $DeviceToAdd.PartNumber 
                            
                        }
                    }
    
                    [void]$DevicesToAddList.Add($DeviceList)
                }

            }
        }


        "[{0}] List of objects in `$ObjectStatusList: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList | Out-String) | Write-Verbose

        if ($DevicesToAddList) {

            # Build payload
            $payload = [PSCustomObject]@{
                compute = @()
                network = @()
                storage = $DevicesToAddList 

            } | ConvertTo-Json -Depth 5
            

            # Add device
            try {
                Invoke-HPEGLWebRequest -Uri $Uri -method 'POST' -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | out-Null

                if (-not $WhatIf) {

                    foreach ($DeviceToAdd in $ObjectStatusList) {

                        $AddedDevice = $DevicesToAddList | Where-Object serialNumber -eq $DeviceToAdd.SerialNumber

                        If ($AddedDevice) {

                            $DeviceToAdd.Status = "Complete"

                            if ($DeviceToAdd.TagsAdded) {
                                
                                $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = $DeviceToAdd.TagsAdded.count; Error = $Null }
                            }
                            else {
                                $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = $Null }

                            }

                        }
                    }
                }
            }
            catch {

                if (-not $WhatIf) {

                    foreach ($DeviceToAdd in $ObjectStatusList) {

                        $AddedDevice = $DevicesToAddList | Where-Object serialNumber -eq $DeviceToAdd.SerialNumber

                        If ($AddedDevice) {

                            $DeviceToAdd.Status = "Failed"
                            $DeviceToAdd.TagsAdded = $Null
                            $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = if ($_.Exception.Message) { $_.Exception.Message } else { "Device cannot be added to the HPE GreenLake workspace!" } }
                            $DeviceToAdd.Exception = $Global:HPECOMInvokeReturnData

                        }
                    }
                }
            }      
        }
    
        

        if ($ObjectStatusList.Count -gt 0) {

            Return Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "Device.Add.SPTSDE"
        }


    }
}


Function Add-HPEGLDeviceNetwork {
    <#
    .SYNOPSIS
    Add network device(s) to HPE GreenLake. 

    .DESCRIPTION
    This Cmdlet adds network device(s) to the currently connected HPE GreenLake workspace. It can optionally add tags during the onboarding process.  
    Devices must meet the requirements of the Data Services and be on the list of supported systems.    
   
    .PARAMETER SerialNumber
    Serial number of the network device to be added. 
    The serial number can be found in the order confirmation email or in the email received after you activate the network device software. 
    For Nimble devices, it can be retrieved from the network System UI or the pull-out tab.

    .PARAMETER MacAddress 
    Media access control (MAC) address of the device to be added. Most network devices have MAC address on the front or back of the hardware.

    .PARAMETER Tags
    Optional parameter to add tags to the device. Tags must meet the following string format: <Name>=<Value>, <Name>=<Value>.

    Supported tags example:
        - "Country=US"
        - "Country=US,State=TX,App=Grafana" 
        - "Country=US, State =TX ,App= Grafana "
            -> Produces the same result as the previous example.
        - "Private note=this is my tag note value,Email=Chris@email.com,City=New York" 
        - "Private note = this is my tag note value , Email = Chris@email.com , City=New York "
            -> Produces the same result as the previous example.  

    Refer to HPE GreenLake tagging specifications:
    https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us&docLocale=en_US&page=GUID-1E4DDAEA-E799-418F-90C8-30CE6A2873AB.html
        - Resources that support tagging can have up to 25 tags per resource.
        - Tag keys and values are case-insensitive.
        - There can be only one value for a particular tag key for a given resource.
        - Null is not allowed as a possible value for a tag key; instead, an empty string ("") will be supported to enable customers to use tag key-value pairs for labeling.
        - System-defined tags are allowed and start with the prefix "hpe:". User-defined tags cannot start with this prefix.
        - Tag keys must have 1-128 characters.
        - Tag values can have a maximum of 256 characters.
        - Allowed characters include letters, numbers, spaces representable in UTF-8, and the following characters: _ . : + - @.
    
    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Add-HPEGLDeviceNetwork -SerialNumber "123456789012" -MACAddress "aa:bb:cc:dd:ee:ff"  -Tags "Country=US, Hypersior App=ESXi, City=New York"
    
    Adds a network device to the currently connected HPE GreenLake workspace using a serial number and part number and assigns three tags.

    .EXAMPLE
    Import-Csv Network_Devices.csv  | Add-HPEGLDeviceNetwork -Tags "Location=Houston"

    Adds all network devices listed in a `Network_Devices.csv` file to the currently connected HPE GreenLake workspace and assigns the same location tag to all devices.

    The content of the CSV file must use the following format:
        SerialNumber, MACAddress
        A-23434324,	aa:bb:cc:dd:ee:ff
        A-53234730,	11:bb:22:dd:33:78
        A-58976464,	ff:bb:e3:d2:34:23
 
    .EXAMPLE
    Import-Csv Network_Devices.csv -Delimiter ";"  | Add-HPEGLDeviceNetwork 
    
    Adds all network devices listed in a `Network_Devices.csv` file to the currently connected HPE GreenLake workspace and assigns tags as defined in the 'Tags' column of the CSV file.

    The content of the CSV file must use the following format:
        SerialNumber; MACAddress; Tags
        A-23434324;	aa:bb:cc:dd:ee:ff; Country=US, State=PACA, App=RH
        A-53234730;	11:bb:22:dd:33:78; State=Texas, Role=production
        A-58976464;	ff:bb:e3:d2:34:23

        Note that for `A-58976464`, no tags are assigned in this example.              

    .EXAMPLE
    $devices = @(
        [PSCustomObject]@{SerialNumber = 'A-53234730'; MACAddress = 'aa:bb:cc:dd:ee:ff' },
        [PSCustomObject]@{SerialNumber = 'A-58976464'; MACAddress = '11:bb:22:dd:33:78' }
    )

    $devices | Add-HPEGLDeviceNetwork
    
    Add all network devices (2) listed in $devices with the specified serial number and part number keys.
    
    .EXAMPLE
    $devices = @(
        [PSCustomObject]@{SerialNumber = 'A-53234730'; MACAddress = 'aa:bb:cc:dd:ee:ff'; Tags = 'Country=US, State=PACA, App=RH' },
        [PSCustomObject]@{SerialNumber = 'A-58976464'; MACAddress = '11:bb:22:dd:33:78'; Tags = 'State=Texas, Role=production' }
    )

    $devices | Add-HPEGLDeviceNetwork 
    
    Adds all network devices (2) listed in `$devices` with the specified serial numbers and part numbers and assigns them different tags.

    .INPUTS
    System.Collections.ArrayList
        List of Device(s) with serialnumber, MACAddress and tags properties. 

    .OUTPUTS
    System.Collections.ArrayList
        Returns a custom status object containing the following PsCustomObject keys:  
        * SerialNumber - Serial number of the device attempted to be added
        * PartNumber - Part number of the device attempted to be added
        * TagsAdded - List of tags to assign to the device (if any)
        * Status - Status of the device onboarding attempt (Failed for HTTP error return; Complete if onboarding is successful; Warning if no action is needed) 
        * Details - More information about the onboarding status of the device, which includes a PSCustomObject with:
          - TagsAdded - The number of tags added to the device.
          - Error - More information on a warning or failed status error.
        * Exception - Information about any exceptions generated during the operation.

   #>

    [CmdletBinding()]
    Param( 
 
        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [String]$SerialNumber,

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [ValidateScript({
                if ( $_ -match "^([0-9A-Fa-f]{2}[:-]){5}([0-9A-Fa-f]{2})$") {
                    $True
                } 
                else {
                    throw "Input '$_' is not in a valid MAC address format. Expected format is 'aa:bb:cc:dd:ee:ff'"
                }
            })]  
        [Alias ('mac_address')]
        [String]$MacAddress,

        [Parameter (ValueFromPipelineByPropertyName)]
        [String]$Tags,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-DevicesAddUri

        $ObjectStatusList = [System.Collections.ArrayList]::new()
        $InputList = [System.Collections.ArrayList]::new()
        $DevicesToAddList = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            SerialNumber = $SerialNumber
            MACAddress   = $MacAddress
            TagsAdded    = $Tags
            Status       = $Null
            Details      = $Null
            Exception    = $Null
                  
        }

            
        # Add tracking object to the input list (always) and output list (only when not WhatIf)
        [void]$InputList.Add($objStatus)
        if (-not $WhatIf) { [void]$ObjectStatusList.Add($objStatus) }



    }

    end {        

        try {
            $Devices = Get-HPEGLdevice 
        
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        
        foreach ($DeviceToAdd in $InputList) {
            
            
            $ErrorFoundInTags = $False

            $Device = $Devices | Where-Object serialNumber -eq $DeviceToAdd.SerialNumber
            
            
            if ( $Device) {

                $DeviceToAdd.Status = "Warning"
                $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Device already present in the workspace!" }
                $DeviceToAdd.TagsAdded = $Null
                
                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource already present in the workspace!" -f $DeviceToAdd.SerialNumber
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }
            } 
            else {
                
                if ($DeviceToAdd.TagsAdded) {
                    
                    "[{0}] {1}: Object TagsAdded content: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DeviceToAdd.serialnumber, $DeviceToAdd.TagsAdded | Write-Verbose

                    $splittedtags = $DeviceToAdd.TagsAdded.split(",")

                    if ($splittedtags.Length -gt 25) {
                        
                        $DeviceToAdd.Status = "Warning"
                        $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Too many tags defined ! A maximum of 25 tags per resource is supported!" }
                        $DeviceToAdd.TagsAdded = $Null
                        $ErrorFoundInTags = $True


                        if ($WhatIf) {
                            $ErrorMessage = "Device '{0}': Resource is defined with too many tags! A maximum of 25 tags per resource is supported!" -f $DeviceToAdd.SerialNumber
                            Write-Warning "$ErrorMessage Cannot display API request."
                            continue
                        }
                    }
                    else {

                        # Object for the tracking object
                        $TagsList = [System.Collections.ArrayList]::new()
                        # Object for the payload
                        $TagsArray = @{}
                                
                        foreach ($tag in $splittedtags) {
    
                            # Check tag format, if format is not <tagname>=<value>, return error
                            if ($tag -notmatch '^[\p{L}\p{Nd}_ .:+\-@]+\=[\p{L}\p{Nd}_ .:+\-@]*$') {
                                
                                $splittedtagName = $tag.TrimEnd().TrimStart()
    
                                $DeviceToAdd.Status = "Warning"
                                $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Tag format '$splittedtagName' not supported! Expected format is <tagname>=<value>, <tagname>=<value>!" }
                                $DeviceToAdd.TagsAdded = $Null
                                $ErrorFoundInTags = $True
    
                                if ($WhatIf) {
                                    $ErrorMessage = "Device '{0}': Tag '{1}' format not supported! Expected format is <tagname>=<value>, <tagname>=<value>!" -f $DeviceToAdd.SerialNumber, $splittedtagName
                                    Write-Warning "$ErrorMessage Cannot display API request."
                                    break
                                }
                            }
                            else {
    
                                # Split only at the first '=' to preserve values containing '='
                                $eqIndex = $tag.IndexOf('=')
                                $tagname = $tag.Substring(0, $eqIndex).Trim()

        
                                if ($tagname.Length -gt 128) {
        
                                    $DeviceToAdd.Status = "Warning"
                                    $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Tag name '$tagname' is over 128 characters! Tag names can have a maximum of 128 characters!" }
                                    $DeviceToAdd.TagsAdded = $Null
                                    $ErrorFoundInTags = $True
        
                                    if ($WhatIf) {
                                        $ErrorMessage = "Device '{0}': Tag name '{1}' is over 128 characters! Tag names can have a maximum of 128 characters!" -f $DeviceToAdd.SerialNumber, $tagname
                                        Write-Warning "$ErrorMessage Cannot display API request."
                                        break
                                    }
                                }
                                else {
                                    
                                    $tagvalue = $tag.Substring($eqIndex + 1).Trim()
                                    


            
                                    if ($tagvalue.Length -gt 256) {
            
                                        $DeviceToAdd.Status = "Warning"
                                        $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Tag value '$tagvalue' is over 256 characters! Tag values can have a maximum of 256 characters!" }
                                        $DeviceToAdd.TagsAdded = $Null
                                        $ErrorFoundInTags = $True
            
                                        if ($WhatIf) {
                                            $ErrorMessage = "Device '{0}': Tag value '{1}' is over 256 characters! Tag values can have a maximum of 256 characters!" -f $DeviceToAdd.SerialNumber, $tagvalue
                                            Write-Warning "$ErrorMessage Cannot display API request."
                                            break
                                        }
                                    }
                                    else {
    
                                        $TagsArray.$tagname = $tagvalue 
                
                                        $TagsList += [PSCustomObject]@{
                                            name  = $tagname
                                            value = $tagvalue 
                                        }
                                    }
                                }
                            }
                        } 
                    }


                    if ($TagsList -and -not $ErrorFoundInTags) {
                        
                        $DeviceToAdd.TagsAdded = $TagsList
                    }
    
                }
                else {
    
                    "[{0}] {1}: No tags to add" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DeviceToAdd.serialnumber | Write-Verbose
    
                }
                
                

                # Build DeviceList object

                if (-not $ErrorFoundInTags) {

                    # If tags
                    if ($DeviceToAdd.TagsAdded) {
                    
                        $DeviceList = [PSCustomObject]@{
                            serialNumber = $DeviceToAdd.SerialNumber
                            macAddress   = $DeviceToAdd.macAddress 
                            tags         = $TagsArray 
                        }
                    }
                    # If no tags
                    else {
                        
                        $DeviceList = [PSCustomObject]@{
                            serialNumber = $DeviceToAdd.SerialNumber
                            macAddress   = $DeviceToAdd.macAddress 
                            
                        }
                    }
    
                    [void]$DevicesToAddList.Add($DeviceList)
                }

            }
        }


        "[{0}] List of objects in `$ObjectStatusList: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList | Out-String) | Write-Verbose

        if ($DevicesToAddList) {

            # Build payload
            $payload = [PSCustomObject]@{
                compute = @()
                network = $DevicesToAddList 
                storage = @()

            } | ConvertTo-Json -Depth 5
            

            # Add device
            try {
                Invoke-HPEGLWebRequest -Uri $Uri -method 'POST' -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | out-Null

                if (-not $WhatIf) {

                    foreach ($DeviceToAdd in $ObjectStatusList) {

                        $AddedDevice = $DevicesToAddList | Where-Object serialNumber -eq $DeviceToAdd.SerialNumber

                        If ($AddedDevice) {

                            $DeviceToAdd.Status = "Complete"

                            if ($DeviceToAdd.TagsAdded) {
                                
                                $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = $DeviceToAdd.TagsAdded.count; Error = $Null }
                            }
                            else {
                                $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = $Null }

                            }

                        }
                    }
                }
            }
            catch {

                if (-not $WhatIf) {

                    foreach ($DeviceToAdd in $ObjectStatusList) {

                        $AddedDevice = $DevicesToAddList | Where-Object serialNumber -eq $DeviceToAdd.SerialNumber

                        If ($AddedDevice) {

                            $DeviceToAdd.Status = "Failed"
                            $DeviceToAdd.TagsAdded = $Null
                            $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = if ($_.Exception.Message) { $_.Exception.Message } else { "Device cannot be added to the HPE GreenLake workspace!" } }
                            $DeviceToAdd.Exception = $Global:HPECOMInvokeReturnData

                        }
                    }
                }
            }      
        }
    
        

        if ($ObjectStatusList.Count -gt 0) {

            Return Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "Device.Add.SMTSDE"
        }


    }
} 

Function Disable-HPEGLDevice {
    <#
    .SYNOPSIS
    Archive device(s) in HPE GreenLake.

    .DESCRIPTION
    This Cmdlet archives device(s) in HPE GreenLake. Archiving devices will remove all service assignments and will remove them from your inventory list.

    .PARAMETER SerialNumber 
    Serial number of the device to be archived. 

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Disable-HPEGLDevice -SerialNumber CNX2380BLC

    Archive the device with the serial number 'CNX2380BLC'.

    .EXAMPLE
    Get-HPEGLDevice -FilterByDeviceType SERVER -SearchString DL360 | Disable-HPEGLDevice -WhatIf

    Archive all DL360 server devices found in the HPE GreenLake workspace.

    .EXAMPLE
    'CNX2380BLC', '7CE244P9LM' | Disable-HPEGLDevice

    Archive the list of devices with serial numbers 'CNX2380BLC' and '7CE244P9LM' provided in the pipeline.

    .INPUTS
    System.Collections.ArrayList
        List of devices(s) from 'Get-HPEGLDevice'.
    System.String, System.String[]
        A single string object or a list of string objects that represent the device's serial numbers. 

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * SerialNumber - Serial number of the device attempted to be archived 
        * Status - Status of the archiving attempt (Failed for http error return; Complete if archiving is successful; Warning if no action is needed) 
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.

    
   #>
    [CmdletBinding()]
    Param( 
 
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [String]$SerialNumber,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-DevicesUIDoorwayUri  

        $ArchivedDevicesStatus = [System.Collections.ArrayList]::new()
        $InputList = [System.Collections.ArrayList]::new()
        $DevicesToArchivedList = [System.Collections.ArrayList]::new()



    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

                  
        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            SerialNumber = $SerialNumber
            Status       = $Null
            Details      = $Null
            Exception    = $Null
          
        }

      
        # Add tracking object to the input list (always) and output list (only when not WhatIf)
        [void]$InputList.Add($objStatus)
        if (-not $WhatIf) { [void]$ArchivedDevicesStatus.Add($objStatus) }

   
    }

    end {        

        try {
            $Devices = Get-HPEGLdevice 
        
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }


        "[{0}] Devices to archive: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $InputList.SerialNumber | Write-Verbose

        foreach ($DeviceToArchive in $InputList) {

            $Device = $Devices | Where-Object serialnumber -eq $DeviceToArchive.SerialNumber

            if ( -not $Device) {
                
                # Must return a message if device not found
                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource cannot be found in the workspace!" -f $DeviceToArchive.SerialNumber
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }

                $DeviceToArchive.Status = "Warning"
                $DeviceToArchive.Details = "Device cannot be found in the workspace!"

            }
            elseif ( $Device.archived ) {
                # Must return a message if device already archived
                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource is already disabled (archived)!" -f $DeviceToArchive.SerialNumber
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }
                else {
                    
                    $DeviceToArchive.Status = "Warning"
                    $DeviceToArchive.Details = "Device already disabled (archived)!"
                

                }


            }
            else {

                # Create the device list object 
                if ($device.macAddress) {

                    $DeviceList = [PSCustomObject]@{
                        archive       = $true
                        serial_number = $device.serialNumber
                        part_number   = $device.partNumber
                        device_type   = $device.deviceType
                        mac_address   = $device.macAddress
                    }
                    [void]$DevicesToArchivedList.Add($DeviceList)

                }
                else {

                    $DeviceList = [PSCustomObject]@{
                        archive       = $true
                        serial_number = $device.serialNumber
                        part_number   = $device.partNumber
                        device_type   = $device.deviceType
                    }
                    [void]$DevicesToArchivedList.Add($DeviceList)
                }
            }

        }

        if ($DevicesToArchivedList) {

            $payload = [PSCustomObject]@{
                devices = $DevicesToArchivedList
            } | ConvertTo-Json -Depth 5


            try {

                Invoke-HPEGLWebRequest -Uri $Uri -Method 'PATCH' -Body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | Out-Null

                if (-not $WhatIf) {

                    foreach ($DeviceToArchive in $ArchivedDevicesStatus) {
                    
                        $ArchivedDevice = $DevicesToArchivedList | Where-Object serial_number -eq $DeviceToArchive.SerialNumber
                        if ($ArchivedDevice) {
                            $DeviceToArchive.Status = "Complete"
                            $DeviceToArchive.Details = "Device successfully disabled (archived)"
                        }
                    }
                }
            }
            catch {

                if (-not $WhatIf) {
                    
                    foreach ($DeviceToArchive in $ArchivedDevicesStatus) {

                        $ArchivedDevice = $DevicesToArchivedList | Where-Object serial_number -eq $DeviceToArchive.SerialNumber

                        if ($ArchivedDevice) {
                            $DeviceToArchive.Status = "Failed"
                            $DeviceToArchive.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Device could not be disabled (archived)!" }
                            $DeviceToArchive.Exception = $Global:HPECOMInvokeReturnData
                        }
                    }
                }
            }
        }


        if ($ArchivedDevicesStatus.Count -gt 0) {

            Return Invoke-RepackageObjectWithType -RawObject $ArchivedDevicesStatus -ObjectName "ObjStatus.SSDE"
        }
    }
}

Function Enable-HPEGLDevice {
    <#
    .SYNOPSIS
    Unarchive device(s) in HPE GreenLake.

    .DESCRIPTION
    This Cmdlet unarchives device(s) in HPE GreenLake console. Unarchiving devices will make devices available for assignment and subscription.      

    .PARAMETER SerialNumber 
    Serial number of the device to be unarchived. 

    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Enable-HPEGLDevice -SerialNumber "CNX2380BLC"

    Unarchive the device with the serial number CNX2380BLC.
    
    .EXAMPLE
    Get-HPEGLdevice -ShowArchived | Enable-HPEGLDevice

    Unarchive all archived devices found in the HPE GreenLake workspace.

    .EXAMPLE
    'CNX2380BLC', '7CE244P9LM' | Enable-HPEGLDevice

    Unarchive the list of devices with serial numbers 'CNX2380BLC' and '7CE244P9LM' provided in the pipeline.

    .INPUTS
    System.Collections.ArrayList
        List of archived devices from 'Get-HPEGLdevice -ShowArchived'. 
    System.String, System.String[]
        A single string object or a list of string objects that represent the device's serial numbers.        

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * SerialNumber - Serial number of the device attempted to be unarchived 
        * Status - Status of the unarchiving attempt (Failed for http error return; Complete if unarchiving is successful; Warning if no action is needed) 
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.

    
   #>
    [CmdletBinding()]
    Param( 
 
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [ValidateNotNullOrEmpty()]
        [String]$SerialNumber,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-DevicesUIDoorwayUri

        $UnarchivedDevicesStatus = [System.Collections.ArrayList]::new()
        $InputList = [System.Collections.ArrayList]::new()
        $DevicesToUnarchivedList = [System.Collections.ArrayList]::new()

        
    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose


        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            SerialNumber = $SerialNumber
            Status       = $Null
            Details      = $Null
            Exception    = $Null
          
        }

      

        # Add tracking object to the input list (always) and output list (only when not WhatIf)
        [void]$InputList.Add($objStatus)
        if (-not $WhatIf) { [void]$UnarchivedDevicesStatus.Add($objStatus) }



    }

    end {

        try {
            $Devices = Get-HPEGLdevice 
        
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }


        "[{0}] Devices to unarchive: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InputList.SerialNumber | out-string) | Write-Verbose

        foreach ($DeviceToUnarchive in $InputList) {

            $Device = $Devices | Where-Object serialnumber -eq $DeviceToUnarchive.SerialNumber

            if ( -not $Device) {
                
                # Must return a message if device not found
                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource cannot be found in the workspace!" -f $DeviceToUnarchive.SerialNumber
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }

                $DeviceToUnarchive.Status = "Warning"
                $DeviceToUnarchive.Details = "Device cannot be found in the workspace!"
                 
            }
            elseif (-not $device.archived ) {
                # Must return a message if device is not archived
            
                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource is already enabled (unarchived)!" -f $DeviceToUnarchive.SerialNumber
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }
                else {
                    $DeviceToUnarchive.Status = "Warning"
                    $DeviceToUnarchive.Details = "Device is already enabled (unarchived)!"
                        
                }

            }
            else {
            
                # Create the device list object 
                if ($device.macAddress) {

                    $DeviceList = [PSCustomObject]@{
                        archive       = $false
                        serial_number = $device.serialNumber
                        part_number   = $device.partNumber
                        device_type   = $device.deviceType
                        mac_address   = $device.macAddress
                    }
                    [void]$DevicesToUnarchivedList.Add($DeviceList)

                }
                else {

                    $DeviceList = [PSCustomObject]@{
                        archive       = $false
                        serial_number = $device.serialNumber
                        part_number   = $device.partNumber
                        device_type   = $device.deviceType
                    }
                    [void]$DevicesToUnarchivedList.Add($DeviceList)
                }
            }
        }

            
        if ($DevicesToUnarchivedList) {

            $payload = [PSCustomObject]@{
                devices = $DevicesToUnarchivedList
            } | ConvertTo-Json -Depth 5


            try {

                Invoke-HPEGLWebRequest -Uri $Uri -Method 'PATCH' -Body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | Out-Null

                if (-not $WhatIf) {

                    foreach ($DeviceToUnarchive in $UnarchivedDevicesStatus) {
                    
                        $UnarchivedDevice = $DevicesToUnarchivedList | Where-Object serial_number -eq $DeviceToUnarchive.SerialNumber
                        if ($UnarchivedDevice) {
                            $DeviceToUnarchive.Status = "Complete"
                            $DeviceToUnarchive.Details = "Device successfully enabled (unarchived)"
                        }
                    }
                }
            }
            catch {

                if (-not $WhatIf) {
                    
                    foreach ($DeviceToUnarchive in $UnarchivedDevicesStatus) {

                        $UnarchivedDevice = $DevicesToUnarchivedList | Where-Object serial_number -eq $DeviceToUnarchive.SerialNumber

                        if ($UnarchivedDevice) {
                            $DeviceToUnarchive.Status = "Failed"
                            $DeviceToUnarchive.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Device could not be enabled (unarchived)!" }
                            $DeviceToUnarchive.Exception = $Global:HPECOMInvokeReturnData
                        }
                    }
                }
            }
        }


        if ($UnarchivedDevicesStatus.Count -gt 0) {

            Return Invoke-RepackageObjectWithType -RawObject $UnarchivedDevicesStatus -ObjectName "ObjStatus.SSDE"
        }


    }
   
}

Function Add-HPEGLDeviceTagToDevice {
    <#
.SYNOPSIS
Add tag(s) to a device.

.DESCRIPTION
This cmdlet adds one or more tags to a specified device available in the workspace. If a tag with the same name already exists on the device, the cmdlet deletes the existing tag and recreates it with the new value.

.PARAMETER SerialNumber
The serial number of the device to which tags must be added. This value can be retrieved using 'Get-HPEGLDevice'.

.PARAMETER Tags
Tags to be added to the device. Tags must meet the following string format: <Name>=<Value>, <Name>=<Value>.

Supported tags example:
    - "Country=US"
    - "Country=US,State=TX,App=Grafana" 
    - "Country=US, State =TX ,App= Grafana "
        -> Produces the same result as the previous example.
    - "Note=this is my tag note value,Email=Chris@email.com,City=New York" 
    - "Note = this is my tag note value , Email = Chris@email.com , City=New York "
        -> Produces the same result as the previous example.  

Refer to HPE GreenLake tagging specifications:
https://support.hpe.com/hpesc/public/docDisplay?docId=a00120892en_us&docLocale=en_US&page=GUID-1E4DDAEA-E799-418F-90C8-30CE6A2873AB.html
    - Resources that support tagging can have up to 25 tags per resource.
    - Tag keys and values are case-insensitive.
    - There can be only one value for a particular tag key for a given resource.
    - Null is not allowed as a possible value for a tag key; instead, an empty string ("") will be supported to enable customers to use tag key-value pairs for labeling.
    - System-defined tags are allowed and start with the prefix "hpe:". User-defined tags cannot start with this prefix.
    - Tag keys must have 1-128 characters.
    - Tag values can have a maximum of 256 characters.
    - Allowed characters include letters, numbers, spaces representable in UTF-8, and the following characters: _ . : + - @.

.PARAMETER WhatIf
Shows the raw REST API call that would be made to GLP instead of sending the request. Useful for understanding the inner workings of the native REST API calls used by GLP.

.EXAMPLE
Add-HPEGLDeviceTagToDevice -SerialNumber CWERX2380BLC -Tags "Department=HR"

Adds the tag 'Department=HR' to the device with serial number 'CWERX2380BLC'. 

.EXAMPLE
Add-HPEGLDeviceTagToDevice -SerialNumber CWERX2380BLC -Tags "Country=US, App=VMware"

Adds the tags 'Country=US' and 'App=VMware' to the device with serial number 'CWERX2380BLC'.

.EXAMPLE
'CNX2380BLC', 'MXQ73200W1', 'EZ12312312' | Add-HPEGLDeviceTagToDevice -Tags "Department=HR, Apps=RHEL"

Adds the tags 'Department=HR' and 'Apps=RHEL' to the list of devices with the specified serial numbers defined in the pipeline.

.EXAMPLE
Get-HPEGLDevice -FilterByDeviceType SERVER -SearchString DL360 | Add-HPEGLDeviceTagToDevice -Tags "Country=US, Apps=VMware ESX"

Adds the tags 'Country=US' and 'Apps=VMware ESX' to all DL360 server devices found in the workspace.

.EXAMPLE
Import-Csv Tests/Network_Devices.csv | Add-HPEGLDeviceTagToDevice -Tags "Country=US, City=New York"

Adds two tags to all devices listed in a "Network_Devices.csv" file containing at least a SerialNumber column.

.EXAMPLE
Import-Csv .\Compute_Devices_Tags.csv -Delimiter ";"  | Add-HPEGLDeviceTagToDevice 

Adds tags to all devices listed in a `Compute_Devices_Tags.csv` file containing at least two columns, SerialNumber and Tags.

The content of the CSV file must use the following format:
    SerialNumber; Tags
    7LKY2323233LM; Country=US, State=CA, App=RH
    CZ123QWE456; State=TX, Role=Production
    CZ122QWE533; City=New York

.INPUTS
System.Collections.ArrayList
    List of devices(s) from 'Get-HPEGLDevice'.
System.String, System.String[]
    A single string object or a list of string objects representing the device's serial numbers.

.OUTPUTS
System.Collections.ArrayList
    A custom status object or array of objects containing the following PsCustomObject keys:
    * SerialNumber - The serial number of the device to which tags were attempted to be added.
    * PartNumber - The part number of the device.
    * DeviceType - The type of the device.
    * TagsAdded - List of tags that have been added.
    * TagsDeleted - List of tags that have been deleted.
    * TagsUnmodified - List of tags that have not been modified.
    * Status - The status of the tagging attempt (Failed for HTTP error return; Warning if tagging is incomplete; Complete if tagging is successful).
    * Details - More information about the status which includes a PSCustomObject with:
          - TagsAdded - The number of tags added to the device.
          - TagsDeleted - The number of tags deleted.
          - TagsUnmodified - The number of tags that have not been modified.
          - Error - More information on a warning or failed status error.
    * Exception - Information about any exceptions generated during the operation.
#>


    [CmdletBinding()]
    Param( 
 
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [String]$SerialNumber,

        [Parameter (Mandatory, ValueFromPipelineByPropertyName)]
        [String]$Tags,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = (Get-DevicesATagsUri) + "?only_validate=false"
        
        $AddTagsDevicesStatus = [System.Collections.ArrayList]::new()
        
        $DevicesWithTagsToAddList = [System.Collections.ArrayList]::new()
        $InputList = [System.Collections.ArrayList]::new()
        $ObjectStatusList = [System.Collections.ArrayList]::new()


    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose
    
        # Build object for the output
        $objStatus = [pscustomobject]@{
          
            SerialNumber   = $SerialNumber
            PartNumber     = $null
            DeviceType     = $null
            TagsAdded      = $Tags
            TagsDeleted    = $null
            TagsUnmodified = $null
            Status         = $null
            Details        = $null
            Exception      = $null
                  
        }
        
      
        # Add tracking object to the list of object status list
        [void]$InputList.Add($objStatus)
        if (-not $WhatIf) {
            [void]$ObjectStatusList.Add($objStatus)
        }

    }

    end {

        try {
            $Devices = Get-HPEGLdevice 
        
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }


        "[{0}] List of devices where to add tags: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $InputList.serialnumber | Write-Verbose

        foreach ($DeviceToAddTags in $InputList) {

            $Device = $Devices | Where-Object serialNumber -eq $DeviceToAddTags.SerialNumber

            if ( -not $Device) {
                # Must return a message if device not found
                $ErrorMessage = "Device '{0}': Resource cannot be found in the workspace!" -f $DeviceToAddTags.SerialNumber
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }

                $DeviceToAddTags.Status = "Warning"
                $DeviceToAddTags.Details = [PSCustomObject]@{
                    TagsAdded      = 0; 
                    TagsDeleted    = 0; 
                    TagsUnmodified = 0; 
                    Error          = "Device cannot be found in the HPE GreenLake workspace!" 
                }
                Add-Member -InputObject $DeviceToAddTags -MemberType NoteProperty -Name _PreValidationFailed -Value $True -Force
            } 
            else {

                "[{0}] {1}: Object TagsAdded content: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DeviceToAddTags.serialnumber, $DeviceToAddTags.TagsAdded | Write-Verbose

                $splittedtags = $DeviceToAddTags.TagsAdded.split(",")

                if ($splittedtags.Length -gt 25) {
                    $ErrorMessage = "Device '{0}': Resource is defined with too many tags! A maximum of 25 tags per resource is supported!" -f $DeviceToAddTags.SerialNumber
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                    if ($WhatIf) {
                        Write-Warning "$ErrorMessage Cannot display API request."
                        continue
                    }

                    $DeviceToAddTags.Status = "Warning"
                    $DeviceToAddTags.Details = [PSCustomObject]@{
                        TagsAdded      = 0; 
                        TagsDeleted    = 0; 
                        TagsUnmodified = 0; 
                        Error          = "Too many tags defined ! A maximum of 25 tags per resource is supported!" 
                    }
                    Add-Member -InputObject $DeviceToAddTags -MemberType NoteProperty -Name _PreValidationFailed -Value $True -Force
                }
                else {

                    # Object for the tracking object
                    $TagsList = [System.Collections.ArrayList]::new()
                    # Object for the payload
                    $TagsArray = @{}
                    $tagValidationFailed = $false
                            
                    foreach ($tag in $splittedtags) {

                        # Check tag format, if format is not <tagname>=<value>, return error
                        if ($tag -notmatch '^[\p{L}\p{Nd}_ .:+\-@]+\=[\p{L}\p{Nd}_ .:+\-@]+$') {
                            
                            $splittedtagName = $tag.TrimEnd().TrimStart()
                            $ErrorMessage = "Device '{0}': Tag '{1}' format not supported! Expected format is <tagname>=<value>, <tagname>=<value>!" -f $DeviceToAddTags.SerialNumber, $splittedtagName
                            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                            if ($WhatIf) {
                                Write-Warning "$ErrorMessage Cannot display API request."
                                $tagValidationFailed = $true
                                break
                            }

                            $DeviceToAddTags.Status = "Warning"
                            $DeviceToAddTags.Details = [PSCustomObject]@{
                                TagsAdded      = 0; 
                                TagsDeleted    = 0; 
                                TagsUnmodified = 0; 
                                Error          = "Tag format '$splittedtagName' not supported! Expected format is <tagname>=<value>, <tagname>=<value>!" 
                            }
                            Add-Member -InputObject $DeviceToAddTags -MemberType NoteProperty -Name _PreValidationFailed -Value $True -Force
                        }
                        else {

                            $tagname = $tag.split('=')[0]
    
                            # Remove space at the begining and at the end of the string if any
                            $tagname = $tagname.TrimEnd().TrimStart()
    
                            if ($tagname.Length -gt 128) {
                                $ErrorMessage = "Device '{0}': Tag name '{1}' is over 128 characters! Tag names can have a maximum of 128 characters!" -f $DeviceToAddTags.SerialNumber, $tagname
                                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                                if ($WhatIf) {
                                    Write-Warning "$ErrorMessage Cannot display API request."
                                    $tagValidationFailed = $true
                                    break
                                }

                                $DeviceToAddTags.Status = "Warning"
                                $DeviceToAddTags.Details = [PSCustomObject]@{TagsAdded = 0; TagsDeleted = 0; TagsUnmodified = 0; Error = "Tag name '$tagname' is over 128 characters! Tag names can have a maximum of 128 characters!" }
                                Add-Member -InputObject $DeviceToAddTags -MemberType NoteProperty -Name _PreValidationFailed -Value $True -Force
                            }
                            else {
                                
                                $tagvalue = $tag.split('=')[1]
                                
                                # Remove space at the begining and at the end of the string if any
                                $tagvalue = $tagvalue.TrimEnd().TrimStart()
        
                                if ($tagvalue.Length -gt 256) {
                                    $ErrorMessage = "Device '{0}': Tag value '{1}' is over 256 characters! Tag values can have a maximum of 256 characters!" -f $DeviceToAddTags.SerialNumber, $tagvalue
                                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                                    if ($WhatIf) {
                                        Write-Warning "$ErrorMessage Cannot display API request."
                                        $tagValidationFailed = $true
                                        break
                                    }

                                    $DeviceToAddTags.Status = "Warning"
                                    $DeviceToAddTags.Details = [PSCustomObject]@{TagsAdded = 0; TagsDeleted = 0; TagsUnmodified = 0; Error = "Tag value '$tagvalue' is over 256 characters! Tag values can have a maximum of 256 characters!" }
                                    Add-Member -InputObject $DeviceToAddTags -MemberType NoteProperty -Name _PreValidationFailed -Value $True -Force
                                }
                                else {

                                    [void]$TagsList.Add([PSCustomObject]@{
                                            name  = $tagname
                                            value = $tagvalue 
                                        })
                                }
                            }
                        }
                    } 

                    if ($WhatIf -and $tagValidationFailed) { continue }
                }

                # Remove all tags from the tracking object as we will create a new tag status based on device state
                $DeviceToAddTags.TagsAdded = $null


                $DeviceToAddTags.PartNumber = $Device.partNumber
                $DeviceToAddTags.DeviceType = $Device.deviceType

                # Build DeviceList object
                $DeviceList = [PSCustomObject]@{
                    serial_number = $Device.serialNumber
                    part_number   = $Device.partNumber 
                    device_type   = $Device.deviceType
            
                }

                # Building the list of devices object where to add tags
                [void]$DevicesWithTagsToAddList.Add($DeviceList)

                # Capturing Tags that already exist
                $ExistingTags = $Device.tags

                if ($ExistingTags) {
                    "[{0}] {1}: Existing tags: `n{2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, ($ExistingTags | convertto-json ) | write-verbose
                }
                else {
                    "[{0}] {1}: No existing tag!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber | write-verbose

                }

                
                # Payload objects
                $TagsUnmodified = [System.Collections.ArrayList]::new()
                $TagsToBeCreated = [System.Collections.ArrayList]::new()
                $TagsToBeDeleted = [System.Collections.ArrayList]::new()
              

                # Process each tag in TagsList
                foreach ($_Tag in $TagsList) {
                    "[{0}] [PROCESS_TAGS] Processing tag '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_Tag.name | Write-Verbose

                    # Check if ExistingTags is not null and has the tag as a property
                    if ($ExistingTags -and ($ExistingTags.PSObject.Properties.Name -contains $_Tag.name)) {
                        "[{0}] [PROCESS_TAGS] '{1}' tag is present" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_Tag.name | Write-Verbose

                        # Compare tag values
                        if ($_Tag.value -eq $ExistingTags.$($_Tag.name)) {
                            "[{0}] [PROCESS_TAGS] Tag '{1}' value is equal to the one already set: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_Tag.name, $_Tag.value | Write-Verbose
                            [void]$TagsUnmodified.Add($_Tag)
                            $DeviceToAddTags.TagsUnmodified = $TagsUnmodified
                            $DeviceToAddTags.Status = "Warning"
                        }
                        else {
                            "[{0}] [PROCESS_TAGS] Tag '{1}' value is not equal to the one already set: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_Tag.name, $_Tag.value | Write-Verbose

                            # Step 1: Add existing tag to delete list
                            $_TagToDelete = @{
                                name  = $_Tag.name
                                value = $ExistingTags.$($_Tag.name)
                            }
                            [void]$TagsToBeDeleted.Add($_TagToDelete)

                            # Step 2: Add new tag to create list
                            [void]$TagsToBeCreated.Add($_Tag)

                            # Update tracking object
                            $DeviceToAddTags.TagsAdded = $TagsToBeCreated
                            $DeviceToAddTags.TagsDeleted = $TagsToBeDeleted
                        }
                    }
                    else {
                        "[{0}] [PROCESS_TAGS] '{1}' tag cannot be found or ExistingTags is empty" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_Tag.name | Write-Verbose
                        [void]$TagsToBeCreated.Add($_Tag)
                        $DeviceToAddTags.TagsAdded = $TagsToBeCreated
                    }
                }    
            }
        }

        "[{0}] List of objects in `$ObjectStatusList: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList | Out-String) | Write-Verbose
       
        
        # Removing objects where pre-validation failed (condition when device is not found or tags are not supported)
        $ObjectStatusListForFoundDevices = $ObjectStatusList | Where-Object { -not $_._PreValidationFailed }
        
        "[{0}] List of objects where status is not failed in `$ObjectStatusList: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusListforFoundDevices | Out-String) | Write-Verbose
        
        "[{0}] Grouping objects based on identical TagsAdded / TagsDeleted property values" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
        
        # Create a unique key for each object based on TagsDeleted
        $ObjectStatusListForFoundDevices | ForEach-Object {
            $TagsDeleteduniqueKey = ($_.TagsDeleted | Sort-Object name, value | ForEach-Object { "$($_.name)=$($_.value)" }) -join ";"
            $TagsAddeduniqueKey = ($_.TagsAdded | Sort-Object name, value | ForEach-Object { "$($_.name)=$($_.value)" }) -join ";"
            $uniqueKey = "$TagsDeleteduniqueKey;$TagsAddeduniqueKey"
            Add-Member -InputObject $_ -MemberType NoteProperty -Name UniqueKey -Value $uniqueKey
        }

        # Group objects based on the unique key
        $groupedObjects = $ObjectStatusListForFoundDevices | Group-Object -Property UniqueKey

        # Remove the UniqueKey property from each object in $groupedObjects
        $groupedObjects | ForEach-Object {
            $_.Group | ForEach-Object {
                $_ | ForEach-Object { $_.PSObject.Properties.Remove('UniqueKey') }

            }
        }
        
        "[{0}] List of object groups with devices found: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($groupedObjects | Out-String) | Write-Verbose

        foreach ($Group in $groupedObjects ) {
            
            "[{0}] Group being processed: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Group | Out-String) | Write-Verbose

            $ListOfDevicesWithMatchingTagsAddedAndModified = $DevicesWithTagsToAddList | Where-Object serial_Number -in $Group.group.SerialNumber 

            if ($Group.Count -eq 1 ) {
                $ListOfDevicesWithMatchingTagsAddedAndModified = @($ListOfDevicesWithMatchingTagsAddedAndModified)
            }

            $TagsToBeCreated = $Group.group[0].TagsAdded
            
            if ($Group.group[0].TagsDeleted ) {
                $TagsToBeDeleted = $Group.group[0].TagsDeleted 
            }
            else {
                $TagsToBeDeleted = @()
            }
                
            # Add tags
            try {
                # DELETE request (only delete_tags)
                if ($TagsToBeDeleted -and $TagsToBeDeleted.Count -gt 0) {
                    $deletePayload = [PSCustomObject]@{
                        devices     = $ListOfDevicesWithMatchingTagsAddedAndModified
                        delete_tags = $TagsToBeDeleted
                    }
                    $jsonDeletePayload = $deletePayload | ConvertTo-Json -Depth 5
                    $Response = Invoke-HPEGLWebRequest -Uri $Uri -method 'PUT' -body $jsonDeletePayload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                }

                # CREATE request (only create_tags)
                if ($TagsToBeCreated -and $TagsToBeCreated.Count -gt 0) {
                    $createPayload = [PSCustomObject]@{
                        devices     = $ListOfDevicesWithMatchingTagsAddedAndModified
                        create_tags = $TagsToBeCreated
                    }
                    $jsonCreatePayload = $createPayload | ConvertTo-Json -Depth 5
                    $Response = Invoke-HPEGLWebRequest -Uri $Uri -method 'PUT' -body $jsonCreatePayload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                    if (-not $WhatIf) {
                        foreach ($object in $Group.Group) {
                            $object.Status = "Complete"
                            # Format tags as 'key=value' strings
                            $object.TagsAdded = if ($TagsToBeCreated) { ($TagsToBeCreated | ForEach-Object { "{0}={1}" -f $_.name, $_.value }) -join ", " } else { $null }
                            $object.TagsDeleted = if ($TagsToBeDeleted) { ($TagsToBeDeleted | ForEach-Object { "{0}={1}" -f $_.name, $_.value }) -join ", " } else { $null }
                            $object.TagsUnmodified = if ($object.TagsUnmodified) { ($object.TagsUnmodified | ForEach-Object { "{0}={1}" -f $_.name, $_.value }) -join ", " } else { $null }
                            $object.Details = [PSCustomObject]@{TagsAdded = $TagsToBeCreated.count; TagsDeleted = $TagsToBeDeleted.count; TagsUnmodified = $null -ne $object.TagsUnmodified ? ($object.TagsUnmodified -split ",").Count : 0; Error = $null }
                            [void] $AddTagsDevicesStatus.add($object)
                        }
                    }
                }
                elseif ((-not $TagsToBeCreated) -and (-not $TagsToBeDeleted -or $TagsToBeDeleted.Count -eq 0)) {
                    # No action required
                    if (-not $WhatIf) {
                        foreach ($object in $Group.Group) {
                            $object.Status = "Warning"
                            $object.TagsAdded = $null
                            $object.TagsDeleted = $null
                            $object.TagsUnmodified = if ($object.TagsUnmodified) { ($object.TagsUnmodified | ForEach-Object { "{0}={1}" -f $_.name, $_.value }) -join ", " } else { $null }
                            $object.Details = [PSCustomObject]@{
                                TagsAdded      = 0; 
                                TagsDeleted    = 0; 
                                TagsUnmodified = $null -ne $object.TagsUnmodified ? ($object.TagsUnmodified -split ",").Count : 0; 
                                Error          = "No action required, the same tag configuration already exists!" 
                            }
                            [void] $AddTagsDevicesStatus.add($object)
                        }
                    }
                    else {
                        foreach ($object in $Group.Group) {
                            Write-Warning "Device '$($object.SerialNumber)' has no action required, the tag configuration already exists. Cannot display API request."
                        }
                    }
                }

            }
            catch {

                if (-not $WhatIf) {

                    foreach ($object in $Group.Group) {
                        $object.Status = "Failed"
                        $object.TagsAdded = $null
                        $object.TagsDeleted = $null
                        $object.TagsUnmodified = $null
                        $object.Details = [PSCustomObject]@{TagsAdded = 0; TagsDeleted = 0; TagsUnmodified = 0; Error = if ($_.Exception.Message) { $_.Exception.Message } else { "Device tagging error!" } }
                        $object.Exception = $Global:HPECOMInvokeReturnData
                        [void] $AddTagsDevicesStatus.add($object)
                    }
                }
            }
        }
    
        # Getting objects where pre-validation failed (condition when device is not found or tags are not supported)
        $ObjectStatusListOfDevicesNotFound = $ObjectStatusList | Where-Object { $_._PreValidationFailed }


        "[{0}] List of objects with failed status: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusListOfDevicesNotFound | Out-String) | Write-Verbose

        foreach ($Object in $ObjectStatusListOfDevicesNotFound) {
            if (-not $WhatIf) {
                $Object.TagsAdded = $null
                $Object.TagsDeleted = $null
                $Object.TagsUnmodified = $null
                # Remove the internal tracking property before adding to output
                if ($Object.PSObject.Properties['_PreValidationFailed']) {
                    $Object.PSObject.Properties.Remove('_PreValidationFailed')
                }
                [void] $AddTagsDevicesStatus.add($Object)
            }
        }


        if ($AddTagsDevicesStatus.Count -gt 0) {

            Return Invoke-RepackageObjectWithType -RawObject $AddTagsDevicesStatus -ObjectName "Device.Tag.STTTSDE"
        }
    }
}

Function Remove-HPEGLDeviceTagFromDevice {
    <#
.SYNOPSIS
Delete tag(s) from a device.

.DESCRIPTION
This Cmdlet deletes one or more tags from a specified device available in the workspace.

.PARAMETER SerialNumber
The serial number of the device from which tags must be deleted. This value can be retrieved using 'Get-HPEGLDevice'.

.PARAMETER Tags
Tags to be removed from the device. Tags must meet the following string format: <Name1>, <Name2>. For example, "Country" or "European location, timezone" or "Country, State, Grafana".

.PARAMETER WhatIf
Shows the raw REST API call that would be made to GLP instead of sending the request. Useful for understanding the inner workings of the native REST API calls used by GLP.

.EXAMPLE
Remove-HPEGLDeviceTagFromDevice -SerialNumber CWERX2380BLC -Tags "European location"

Removes the tag 'European location' from the device with serial number 'CWERX2380BLC'. 

.EXAMPLE
Remove-HPEGLDeviceTagFromDevice -SerialNumber CWERX2380BLC -Tags "Country, App"

Removes the tags 'Country' and 'App' from the device with serial number 'CWERX2380BLC'.

.EXAMPLE
'CNX2380BLC', 'MXQ73200W1', 'EZ12312312' | Remove-HPEGLDeviceTagFromDevice -Tags "Department, Apps"

Removes the tags 'Department' and 'Apps' from the list of devices with the specified serial numbers defined in the pipeline.

.EXAMPLE
Get-HPEGLDevice -FilterByDeviceType SERVER -SearchString DL360 | Remove-HPEGLDeviceTagFromDevice -Tags "Country, State"

Removes the tags 'Country' and 'State' from all DL360 server devices found in the workspace.

.EXAMPLE
Import-Csv Tests/Network_Devices.csv | Remove-HPEGLDeviceTagFromDevice -Tags "Country, City, State"

Removes three tags from all devices listed in a CSV file containing at least a SerialNumber column.

.EXAMPLE
Get-HPEGLDevice -FilterByDeviceType SWITCH | Remove-HPEGLDeviceTagFromDevice -All

Removes all tags from all switch devices found in the workspace.

.EXAMPLE
Import-Csv .\Compute_Devices_Tags.csv -Delimiter ";"  | Remove-HPEGLDeviceTagFromDevice 

Removes tags from all devices listed in a `Compute_Devices_Tags.csv` file containing at least two columns, SerialNumber and Tags.

The content of the CSV file must use the following format:
    SerialNumber; Tags
    7LKY2323233LM; Country, State, App
    CZ123QWE456; State, Role
    CZ122QWE533; City

.INPUTS
System.Collections.ArrayList
    List of devices(s) from 'Get-HPEGLDevice'.
System.String, System.String[]
    A single string object or a list of string objects representing the device's serial numbers.

.OUTPUTS
System.Collections.ArrayList
    A custom status object or array of objects containing the following PsCustomObject keys:
    * SerialNumber - The serial number of the device from which tags were attempted to be removed.
    * PartNumber - The part number of the device.
    * TagsDeleted - List of tags that have been deleted.
    * TagsNotFound - List of tags that were not found on the device.
    * Status - The status of the untagging attempt (Failed for HTTP error return; Warning if untagging is incomplete; Complete if tagging is successful).
    * Details - More information about the status which includes a PSCustomObject with:
          - TagsDeleted - The number of tags deleted.
          - TagsNotFound - The number of tags that could not be found on the device.
          - Error - More information on a warning or failed status error.
    * Exception - Information about any exceptions generated during the operation.
#>

    [CmdletBinding(DefaultParameterSetName = 'SerialNumberAndTags')]
    Param( 
 
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = "SerialNumberAndTags")]
        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline, ParameterSetName = "SerialNumberAndAll")]
        [String]$SerialNumber,

        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ParameterSetName = "SerialNumberAndTags")]
        [String]$Tags,

        [Parameter (ParameterSetName = "SerialNumberAndAll")]
        [Switch]$All,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = (Get-DevicesATagsUri) + "?only_validate=false"
        
        $RemoveTagsDevicesStatus = [System.Collections.ArrayList]::new()
        
        $DevicesWithTagsToRemoveList = [System.Collections.ArrayList]::new()
        $InputList = [System.Collections.ArrayList]::new()
        $ObjectStatusList = [System.Collections.ArrayList]::new()


    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose               
        
        # Build object for the output
        $objStatus = [pscustomobject]@{
          
            SerialNumber = $SerialNumber
            PartNumber   = $Null
            DeviceType   = $Null
            TagsDeleted  = $Tags
            TagsNotFound = $Null
            Status       = $Null
            Details      = $Null
            Exception    = $Null
                  
        }

        # Add tracking object to the list of object status list
        [void]$InputList.Add($objStatus)
        if (-not $WhatIf) {
            [void]$ObjectStatusList.Add($objStatus)
        }

    }

    end {


        try {
            $Devices = Get-HPEGLdevice 
        
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }


        "[{0}] List of devices where to remove tags: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $InputList.serialnumber | Write-Verbose

        foreach ($DeviceToRemoveTags in $InputList) {

            $Device = $Devices | Where-Object serialNumber -eq $DeviceToRemoveTags.SerialNumber

            if ( -not $Device) {
                # Must return a message if device not found
                $ErrorMessage = "Device '{0}': Resource cannot be found in the workspace!" -f $DeviceToRemoveTags.SerialNumber
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }

                $DeviceToRemoveTags.Status = "Warning"
                $DeviceToRemoveTags.TagsDeleted = $null
                $DeviceToRemoveTags.TagsNotFound = $null
                $DeviceToRemoveTags.Exception = $null
                $DeviceToRemoveTags.Details = [PSCustomObject]@{TagsDeleted = 0; TagsNotFound = 0; Error = "Device cannot be found in the workspace!" }
                Add-Member -InputObject $DeviceToRemoveTags -MemberType NoteProperty -Name _PreValidationFailed -Value $True -Force
            } 
            else {

                $DeviceToRemoveTags.PartNumber = $Device.partNumber
                $DeviceToRemoveTags.DeviceType = $Device.deviceType

                # Build DeviceList object
                $DeviceList = [PSCustomObject]@{
                    serial_number = $Device.serialNumber
                    part_number   = $Device.partNumber 
                    device_type   = $Device.deviceType
                        
                }      
                "[{0}] `$DeviceList: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($DeviceList | out-String) | write-verbose
                    
                # Building the list of devices object where to remove tags
                [void]$DevicesWithTagsToRemoveList.Add($DeviceList)
                    
                # Capturing existing tags 
                $ExistingTags = $device.tags

                if ($ExistingTags) {
                    "[{0}] {1}: Existing tags: `n{2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber, ($ExistingTags | Out-String) | write-verbose
                }
                else {
                    "[{0}] {1}: No existing tag!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SerialNumber | write-verbose
        
                }
    
                # Process tags if they exist
                if ($ExistingTags) {
    
                    # Initialize payload objects
                    $TagsToBeDeleted = [System.Collections.ArrayList]::new()
                    $TagsNotFoundList = [System.Collections.ArrayList]::new()
    
                    if ($All) {
                        # Add all existing tags to delete list
                        foreach ($property in $ExistingTags.PSObject.Properties) {
                            $tag = [PSCustomObject]@{
                                name  = $property.Name
                                value = $property.Value
                            }
                            [void]$TagsToBeDeleted.Add($tag)
                        }
                        $TagsNotfoundNumber = 0

                    }
                    else {
                        # Parse comma-separated tag names
                        $splittedtags = $DeviceToRemoveTags.TagsDeleted -split "," | ForEach-Object { $_.Trim() }
                        $TagsList = [System.Collections.ArrayList]::new()
                        $tagValidationFailed = $false

                        foreach ($tag in $splittedtags) {

                            # Validate tag format, if format is not <tagname>, return error
                            if ($tag -notmatch '^[\p{L}\p{Nd}_ .:+\-@]+$') {

                                $splittedtagName = $tag.TrimEnd().TrimStart()
                                $ErrorMessage = "Device '{0}': Tag '{1}' format not supported! Expected format is <tagname>, <tagname>!" -f $DeviceToRemoveTags.SerialNumber, $splittedtagName
                                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                                if ($WhatIf) {
                                    Write-Warning "$ErrorMessage Cannot display API request."
                                    $tagValidationFailed = $true
                                    break
                                }

                                $DeviceToRemoveTags.Status = "Warning"
                                $DeviceToRemoveTags.TagsDeleted = $null
                                $DeviceToRemoveTags.TagsNotFound = $null
                                $DeviceToRemoveTags.Exception = $null
                                $DeviceToRemoveTags.Details = [PSCustomObject]@{
                                    TagsDeleted  = 0; 
                                    TagsNotFound = 0; 
                                    Error        = "Tag format '$splittedtagName' not supported! Expected format is <tagname>, <tagname>!" 
                                }
                                Add-Member -InputObject $DeviceToRemoveTags -MemberType NoteProperty -Name _PreValidationFailed -Value $True -Force
                            }
                            else {
                            
                                # Remove space at the begining and at the end of the string if any
                                $tagname = $tag.TrimEnd().TrimStart()                                
                                [void]$TagsList.Add($tagname)

                            }
                                
                        } 

                        if ($WhatIf -and $tagValidationFailed) { continue }

                        if ($TagsList) {                                
                                
                            "[{0}] Tags requested for deletion: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($TagsList -join ", ") | Write-Verbose
                                
                            foreach ($_Tag in $TagsList) {  
                                
                                # Check if tag exists in ExistingTags
                                if ($ExistingTags.PSObject.Properties.Name -contains $_Tag) {
                                    "[{0}] Tag '{1}' is present" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_Tag | write-verbose

                                    $tagItem = [PSCustomObject]@{
                                        name  = $_Tag
                                        value = $ExistingTags.$_Tag
                                    }
                                    [void]$TagsToBeDeleted.Add($tagItem)
                                }
                                else {
                                    "[{0}] Tag '{1}' cannot be found" -f $MyInvocation.InvocationName.ToString().ToUpper(), $_Tag | write-verbose
                                    [void]$TagsNotFoundList.Add($_Tag)
                                }
                            }
                
                            $TagsNotfoundNumber = $TagsNotFoundList.count
                                
                            # Add TagsNotFound to tracking object
                            if ($TagsNotFoundList) {
                                $DeviceToRemoveTags.TagsNotFound = $TagsNotFoundList
                            }
                            else {
                                $DeviceToRemoveTags.TagsNotFound = $null
                            }
                        }
                    }
                        
                    # Update tracking object with tags to delete
                    if ($TagsToBeDeleted -and $TagsToBeDeleted.Count -gt 0) {
                        # Keep TagsToBeDeleted as array of objects for API payload
                        $DeviceToRemoveTags.TagsDeleted = $TagsToBeDeleted
                        "[{0}] Tag list to delete: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($TagsToBeDeleted | Out-String) | write-verbose
                    }
                    else {
                        $DeviceToRemoveTags.TagsDeleted = $null                    
                        "[{0}] No tag to delete!" -f $MyInvocation.InvocationName.ToString().ToUpper() | write-verbose
                    }

                    # Update Details in tracking object
                    $DeviceToRemoveTags.Details = [PSCustomObject]@{
                        TagsDeleted  = $TagsToBeDeleted.Count
                        TagsNotFound = $TagsNotfoundNumber
                        Error        = $null
                    }
                }
                else {
                    # Device has no existing tags - nothing to remove
                    $ErrorMessage = "Device '{0}': No tags found on this device, nothing to remove!" -f $DeviceToRemoveTags.SerialNumber
                    "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose
                    if ($WhatIf) {
                        Write-Warning "$ErrorMessage Cannot display API request."
                        continue
                    }
                    $DeviceToRemoveTags.Status = "Warning"
                    $DeviceToRemoveTags.TagsDeleted = $null
                    $DeviceToRemoveTags.TagsNotFound = $null
                    $DeviceToRemoveTags.Details = [PSCustomObject]@{ TagsDeleted = 0; TagsNotFound = 0; Error = "No tags found on this device, nothing to remove!" }
                    Add-Member -InputObject $DeviceToRemoveTags -MemberType NoteProperty -Name _PreValidationFailed -Value $True -Force
                }
            }
        }


        "[{0}] List of objects in `$ObjectStatusList: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList | Out-String) | Write-Verbose

        # Removing objects where pre-validation failed (condition when device is not found or tags not supported)
        $ObjectStatusListForFoundDevices = $ObjectStatusList | Where-Object { -not $_._PreValidationFailed }
        
        "[{0}] List of objects where status is not failed in `$ObjectStatusList: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusListforFoundDevices | Out-String) | Write-Verbose
        
        "[{0}] Grouping objects based on identical TagsDeleted property values" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
        
        # Create a unique key for each object based on TagsDeleted
        $ObjectStatusListForFoundDevices | ForEach-Object {
            $uniqueKey = ($_.TagsDeleted | Sort-Object name, value | ForEach-Object { "$($_.name)=$($_.value)" }) -join ";"
            Add-Member -InputObject $_ -MemberType NoteProperty -Name UniqueKey -Value $uniqueKey
        }

        # Group objects based on the unique key
        $groupedObjects = $ObjectStatusListForFoundDevices | Group-Object -Property UniqueKey

        # Remove the UniqueKey property from each object in $groupedObjects
        $groupedObjects | ForEach-Object {
            $_.Group | ForEach-Object {
                $_ | ForEach-Object { $_.PSObject.Properties.Remove('UniqueKey') }

            }
        }
        
        "[{0}] List of object groups: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($groupedObjects | Out-String) | Write-Verbose

        
        foreach ($Group in $groupedObjects) {
            
            "[{0}] Group being processed: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Group | Out-String) | Write-Verbose

            $ListOfDevicesWithMatchingTagsDeleteded = $DevicesWithTagsToRemoveList | Where-Object serial_Number -in $Group.group.SerialNumber 

            if ($Group.Count -eq 1 ) {
                $ListOfDevicesWithMatchingTagsDeleteded = @($ListOfDevicesWithMatchingTagsDeleteded)
            }

            $TagsToBeDeleted = $Group.group[0].TagsDeleted 

            # Build payload
            $payload = [PSCustomObject]@{
                devices     = $ListOfDevicesWithMatchingTagsDeleteded 
                delete_tags = $TagsToBeDeleted
                create_tags = @()
            }
                
                
            try {

                $jsonPayload = $payload | ConvertTo-Json -Depth 5

                if ($TagsToBeDeleted) {
                    
                    $Response = Invoke-HPEGLWebRequest -Uri $Uri -method 'PUT' -body $jsonPayload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference        

                    if (-not $WhatIf) {
    
                        foreach ($object in $Group.Group) {
                            $object.Status = "Complete"
                            # Format TagsDeleted as 'key=value' strings for output only
                            if ($TagsToBeDeleted) {
                                $object.TagsDeleted = ($TagsToBeDeleted | ForEach-Object { "{0}={1}" -f $_.name, $_.value }) -join ", "
                            }
                            else {
                                $object.TagsDeleted = $null
                            }
                            $object.Exception = $null
                            $object.Details = [PSCustomObject]@{TagsDeleted = $TagsToBeDeleted.count; TagsNotFound = $null -ne $object.TagsNotFound ? ($object.TagsNotFound -split ",").Count : 0; Error = $Null }
                            [void] $RemoveTagsDevicesStatus.add($object)
                        }
                    }
                }
                else {

                    "[{0}] No deletion is required, as there are no such tags to delete." -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                    if (-not $WhatIf) {

                        foreach ($object in $Group.Group) {
                            $object.Status = "Warning"
                            $object.TagsDeleted = $null
                            $object.TagsNotFound = $null
                            $object.Exception = $null
                            $object.Details = [PSCustomObject]@{TagsDeleted = 0; TagsNotFound = 0; Error = "No action required, tags to remove cannot be found!" }
                            [void] $RemoveTagsDevicesStatus.add($object)

                        }
                    }
                    else {

                        foreach ($object in $Group.Group) {
                            Write-Warning "Device '$($object.SerialNumber)' has no action required, tags to remove cannot be found! Cannot display API request."

                        }
                    }
                }
            }
            catch {

                if (-not $WhatIf) {

                    foreach ($object in $Group.Group) {
                        $object.Status = "Failed"
                        $object.TagsDeleted = $null
                        $object.TagsNotFound = $null
                        $object.Exception = $Global:HPECOMInvokeReturnData
                        $object.Details = [PSCustomObject]@{TagsDeleted = 0; TagsNotFound = 0; Error = if ($_.Exception.Message) { $_.Exception.Message } else { "Device untagging error!" } }
                        [void] $RemoveTagsDevicesStatus.add($object)

                    }
                }
            }
        }   
        
        # Getting objects where pre-validation failed (condition when device is not found and tags are not supported)
        $ObjectStatusListOfDevicesNotFound = $ObjectStatusList | Where-Object { $_._PreValidationFailed }


        "[{0}] List of objects with devices not found: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusListOfDevicesNotFound | Out-String) | Write-Verbose

        foreach ($Object in $ObjectStatusListOfDevicesNotFound) {

            if (-not $WhatIf) {
                $Object.TagsDeleted = $null
                $Object.TagsNotFound = $null
                $Object.Exception = $null
                # Remove the internal tracking property before adding to output
                if ($Object.PSObject.Properties['_PreValidationFailed']) {
                    $Object.PSObject.Properties.Remove('_PreValidationFailed')
                }
                [void] $RemoveTagsDevicesStatus.add($Object)
            }
        }

        if ($RemoveTagsDevicesStatus.Count -gt 0) {

            Return Invoke-RepackageObjectWithType -RawObject $RemoveTagsDevicesStatus -ObjectName "Device.Tag.STTTSDE"
        }
    }
}

Function Get-HPEGLLocation {
    <#
    .SYNOPSIS
    Retrieve device locations.

    .DESCRIPTION
    This Cmdlet returns a collection of physical locations and service shipping addresses for all devices.

    .PARAMETER Name 
    (Optional) Specifies the name of a location to display its details.

    .PARAMETER ShowDetails
    (Optional) If specified, retrieves detailed information about the location(s), including complete address information and primary contact phone number.

    .PARAMETER ShowServers
    If specified, the Cmdlet will return a list of servers located in the specified location. 
    This parameter requires that a Compute Ops Management instance is available in the workspace.
    
    .PARAMETER WhatIf 
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Get-HPEGLLocation

    Returns all physical locations.

    .EXAMPLE
    Get-HPEGLLocation -ShowDetails

    Returns all physical locations with detailed information including complete addresses and primary contact phone number.

    .EXAMPLE
    Get-HPEGLLocation -Name "Geneva"

    Returns the Geneva location information.

    .EXAMPLE
    Get-HPEGLLocation -Name "Geneva" -ShowDetails

    Returns detailed information for the Geneva location including complete address and primary contact phone number.

    .EXAMPLE
    Get-HPEGLLocation -Name "Geneva" -ShowServers

    Returns the list of servers assigned to the Geneva location.

    #>

    [CmdletBinding(DefaultParameterSetName = 'Name')]
    Param( 
        [Parameter(Mandatory, ParameterSetName = "ShowServers")]
        [Parameter(ParameterSetName = "ShowDetails")]
        [Parameter(ParameterSetName = "Name")]
        [String]$Name,  
        
        [Parameter(ParameterSetName = "ShowDetails")]
        [switch]$ShowDetails,

        [Parameter(ParameterSetName = "ShowServers")]
        [switch]$ShowServers,
 
        [Switch]$WhatIf

    ) 
    
    Begin {
    
        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
        
        $Uri = Get-DevicesLocationUri
  
    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        try {
            [array]$Collection = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
        
        }
        catch {
   
            $PSCmdlet.ThrowTerminatingError($_)
       
        }
       

        if ($Null -ne $Collection) {

            if ($ShowDetails) {

                "[{0}] Retrieving detailed location information" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

                $ListOfDetailedLocations = @()
    
                foreach ($Location in $Collection) {
    
                    "[{0}] Selected collection data '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Location.name | Write-Verbose
    
                    $Uri = (Get-DevicesLocationUri) + "/" + $Location.id
    
                    "[{0}] URI for the '{1}' location: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Location.name, $Uri | Write-Verbose
    
                    try {
                        [array]$_Resp = Invoke-HPEGLWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
    
                        # Fetch tags for this location and attach to the object
                        $TagsUri = (Get-LocationsTagsUri) + "/" + $Location.id
                        "[{0}] Fetching tags for location '{1}' from '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Location.name, $TagsUri | Write-Verbose
                        try {
                            $tagsResp = Invoke-HPEGLWebRequest -Method Get -Uri $TagsUri -WhatIfBoolean $false -Verbose:$VerbosePreference
                            # API may return an array directly or an object with an items/tags property
                            $tagItems = if ($tagsResp -is [System.Collections.IEnumerable] -and $tagsResp -isnot [string]) {
                                $tagsResp
                            }
                            elseif ($tagsResp.items) {
                                $tagsResp.items
                            }
                            elseif ($tagsResp.tags) {
                                $tagsResp.tags
                            }
                            else {
                                $null
                            }
                            $_Resp | Add-Member -MemberType NoteProperty -Name "tags" -Value $tagItems -Force
                            "[{0}] Retrieved {1} tag(s) for location '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($tagItems | Measure-Object).Count, $Location.name | Write-Verbose
                        }
                        catch {
                            "[{0}] Could not retrieve tags for location '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Location.name, $_.Exception.Message | Write-Verbose
                            $_Resp | Add-Member -MemberType NoteProperty -Name "tags" -Value $null -Force
                        }

                        # [void]$ListOfDetailedLocations.Add($_Resp)
                        $ListOfDetailedLocations += $_Resp
                
                    }
                    catch {
            
                        $PSCmdlet.ThrowTerminatingError($_)
                
                    }
                }              
            }
            else {
                $ListOfDetailedLocations = $Collection
            }
                       
            if ($Name) {
                
                $ListOfDetailedLocations = $ListOfDetailedLocations | Where-Object { $_.name -eq $Name } 
                
            }

            if ($ShowServers) {

                if ($HPECOMRegions.Count -eq 0) {
                    Write-Warning "No Compute Ops Management instance is available. Cannot display servers for this location."
                    return
                }

                $ListofServers = @()

                if ($Null -ne $ListOfDetailedLocations -and $ListOfDetailedLocations.Count -gt 0) {

                    $Location = $ListOfDetailedLocations

                    "[{0}] Selected location '{1}' to display its servers" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Location.name | Write-Verbose

                    $Uri = (Get-COMServerLocationsUri) + "/" + $Location.id 

                    "[{0}] URI for the '{1}' location devices: '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Location.name, $Uri | Write-Verbose

                    try {
                        $servers = Get-HPEGLDevice -FilterByDeviceType SERVER -ErrorAction Stop
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }

                    if ($Null -ne $servers) {

                        Foreach ($Region in $Global:HPECOMRegions.region) {
                            
                            "[{0}] Using Compute Ops Management region: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Region | Write-Verbose
        
                            try {
                                [array]$_Resp = Invoke-HPECOMWebRequest -Method Get -Uri $Uri -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference -Region $Region

                                if ($Null -ne $_Resp.servers) {

                                    "[{0}] Number of servers found in location '{1}' in region '{2}': {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Location.name, $Region, $_Resp.servers.count | Write-Verbose
                                    foreach ($device in $_Resp.servers) {
                                        # Extract serial number from device string :  "P53933-B21+CZJ3100GDB"
                                        $deviceSN = $device -split "\+" | Select-Object -last 1
                                        "[{0}] Processing device with serial number '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $deviceSN | Write-Verbose
                                        $server = $servers | Where-Object serialnumber -eq $deviceSN
                                        
                                        if ($server) {
                                            "[{0}] Found server '{1}' in location '{2}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $deviceSN, $Location.name | Write-Verbose
                                            $ListofServers += $server
                                        }
                                    }
                                }
                            }
                            catch {
                                $PSCmdlet.ThrowTerminatingError($_)
                            }
                        }
                        return $ListofServers | Sort-Object name, serial_Number
                    }
                    return
                }
                return
            }
                
            if ($ShowDetails) {
                "[{0}] Returning detailed location information" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $ListOfDetailedLocations -ObjectName "Location.Details" 

            }
            else {
                "[{0}] Returning basic location information" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                $ReturnData = Invoke-RepackageObjectWithType -RawObject $ListOfDetailedLocations -ObjectName "Location" 
            }

            $ReturnData = $ReturnData | Sort-Object name, country

            return $ReturnData
  
        }
        else {

            return 
            
        }
    }
}

Function New-HPEGLLocation {
    <#
    .SYNOPSIS
    Creates a new physical location and service shipping address for devices.

    .DESCRIPTION
    This Cmdlet creates a new physical location with its street address, and optionally, a separate shipping/receiving address if it differs from the street address. It also includes contact details, with the primary contact being mandatory and optional contacts for shipping/receiving, security, and operations.

    Later, this location can be assigned to devices using `Set-HPEGLDeviceLocation`.

    The street address represents the physical location of devices assigned to it and will be used as the default shipping and receiving address. A different shipping and receiving address can be set if needed. If specified, this alternate address will be used when support cases are generated for devices assigned to the location.

    Note: A location can be assigned to devices for automated HPE support case creation and services using `Set-HPEGLDeviceLocation` or removed with `Remove-HPEGLDeviceLocation`.

    .PARAMETER Name 
    Specifies the name of the physical location.

    .PARAMETER Description 
    (Optional) Provides a description of the location.

    .PARAMETER Country 
    Specifies the country of the street address of the location.

    .PARAMETER Street 
    Specifies the postal street address of the location.

    .PARAMETER Street2 
    (Optional) Specifies the second line of the postal street address of the location.

    .PARAMETER City 
    Specifies the city of the street address of the location.

    .PARAMETER State 
    Specifies the state of the street address of the location.

    .PARAMETER PostalCode 
    Specifies the postal code of the street address of the location.

    .PARAMETER ShippingReceivingCountry
    (Optional) Specifies the country for the shipping and receiving address if it differs from the street address.

    .PARAMETER ShippingReceivingStreet
    (Optional) Specifies the street for the shipping and receiving address if it differs from the street address.

    .PARAMETER ShippingReceivingStreet2
    (Optional) Specifies the second line of the street for the shipping and receiving address if it differs from the street address.

    .PARAMETER ShippingReceivingCity
    (Optional) Specifies the city for the shipping and receiving address if it differs from the street address.

    .PARAMETER ShippingReceivingState
    (Optional) Specifies the state for the shipping and receiving address if it differs from the street address.

    .PARAMETER ShippingReceivingPostalCode
    (Optional) Specifies the postal code for the shipping and receiving address if it differs from the street address.

    .PARAMETER PrimaryContactEmail
    (Optional) Sets the primary contact email address for the location.

    .PARAMETER PrimaryContactPhone
    (Optional) Sets the primary contact phone number for the location.

    .PARAMETER ShippingReceivingContactEmail
    (Optional) Sets the shipping and receiving contact email address for the location.

    .PARAMETER ShippingReceivingContactPhone
    (Optional) Sets the shipping and receiving contact phone number for the location.

    .PARAMETER SecurityContactEmail
    (Optional) Sets the security contact email address for the location.

    .PARAMETER SecurityContactPhone
    (Optional) Sets the security contact phone number for the location.

    .PARAMETER OperationsContactEmail
    (Optional) Sets the operations contact email address for the location.

    .PARAMETER OperationsContactPhone
    (Optional) Sets the operations contact phone number for the location.

    .PARAMETER Tags
    (Optional) Tags to assign to the location on creation. Tags must be in the format: <Name>=<Value>, <Name>=<Value>.
    Example: "Country=US, Site=Datacenter1"

    .PARAMETER ValidationCycle
    Specifies how often you would like to validate this location. Valid validation cycle is 6, 12 or 18 months. Default is 12 months.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE  
    New-HPEGLLocation -Name "Boston" -Description "My Boston location" `
    -Country 'United States' -Street "321 Summer Street" -Street2 "5th floor" `
    -City "Boston" -State "MA" -PostalCode "02210" `
    -PrimaryContactEmail "Edmond@email.com" -PrimaryContactPhone "+1234567890" `
    -ShippingReceivingContactEmail "Lisa@email.com" -ShippingReceivingContactPhone "+1234567890"

    Creates a new location with shipping and receiving contact information the same as the primary contact, and with the service shipping address set to the same as the location address.

    .EXAMPLE   
    New-HPEGLLocation -Name "Boston" -Description "My Boston location" `
    -Country 'United States' -Street "321 Summer Street" -Street2 "5th floor" -City "Boston" -State "MA" -PostalCode "02210" `
    -PrimaryContactEmail "Edmond@email.com" -PrimaryContactPhone "+1234567890" `
    -ShippingReceivingContactEmail "Lisa@email.com" -ShippingReceivingContactPhone "+1234567890" `
    -ShippingReceivingCountry "France" -ShippingReceivingStreet "5th Avenue" -ShippingReceivingCity "Mougins" -ShippingReceivingState "NA" -ShippingReceivingPostalCode "06250"

    Creates a new location with a different service shipping and receiving address, with a primary contact information and with a service shipping address set with a different address than the location address.

    .EXAMPLE
    New-HPEGLLocation -Name "Boston" -Description "My Boston location" `
    -Country 'United States' -Street "321 Summer Street" -Street2 "5th floor" -City "Boston" -State "MA" -PostalCode "02210" `
    -PrimaryContactEmail "Edmond@email.com" -PrimaryContactPhone "+1234567890" `
    -ShippingReceivingContactEmail "Lisa@email.com" -ShippingReceivingContactPhone "+1234567890" `
    -ShippingReceivingCountry "France" -ShippingReceivingStreet "5th Avenue" -ShippingReceivingCity "Mougins" -ShippingReceivingState "NA" -ShippingReceivingPostalCode "06250" `
    -SecurityContactEmail Justine@ik.mail -OperationsContactEmail Walter@ik.mail

    Creates a new location with a different service shipping and receiving address, with primary, security, and operations contact information and with a service shipping address set with a different address than the location address.

    .INPUTS
    None. You cannot pipe objects to this Cmdlet.

    .OUTPUTS
    System.Collections.ArrayList    
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * Name - Name of the location object attempted to be created.
        * Status - Status of the creation attempt (Failed for HTTP error return; Complete if successful; Warning if no action is needed).
        * Details - More information about the status.
        * Exception - Information about any exceptions generated during the operation.

    #>    

    [CmdletBinding(DefaultParameterSetName = 'Default')]
    Param( 

        [Parameter (Mandatory, ParameterSetName = "Default")]
        [Parameter (Mandatory, ParameterSetName = "ShippingReceiving")]
        [String]$Name,

        [Parameter (ParameterSetName = "Default")]
        [Parameter (ParameterSetName = "ShippingReceiving")]
        [String]$Description,

        [Parameter (Mandatory, ParameterSetName = "Default")]
        [Parameter (Mandatory, ParameterSetName = "ShippingReceiving")]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $countryNames = $Global:HPEGLSchemaMetadata.hpeCountryCodes.Name
                $countryNames | Where-Object { $_ -like "$wordToComplete*" } | Sort-Object
            })]
        [ValidateScript({
                $countryNames = $Global:HPEGLSchemaMetadata.hpeCountryCodes.Name
                if ($countryNames -contains $_) { 
                    $true 
                }
                else { 
                    Throw "Country '$_' is not valid. Supported countries are: $($countryNames -join ', ')."
                }
            })]
        [ValidateNotNullOrEmpty()]
        [String]$Country,

        [Parameter (Mandatory, ParameterSetName = "Default")]
        [Parameter (Mandatory, ParameterSetName = "ShippingReceiving")]
        [ValidateNotNullOrEmpty()]
        [String]$Street,

        [Parameter (ParameterSetName = "Default")]
        [Parameter (ParameterSetName = "ShippingReceiving")]
        [ValidateNotNullOrEmpty()]
        [String]$Street2,        

        [Parameter (Mandatory, ParameterSetName = "Default")]
        [Parameter (Mandatory, ParameterSetName = "ShippingReceiving")]
        [ValidateNotNullOrEmpty()]
        [String]$City,

        [Parameter (Mandatory, ParameterSetName = "Default")]
        [Parameter (Mandatory, ParameterSetName = "ShippingReceiving")]
        [ValidateNotNullOrEmpty()]
        [String]$State,

        [Parameter (Mandatory, ParameterSetName = "Default")]
        [Parameter (Mandatory, ParameterSetName = "ShippingReceiving")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                if ($_ -match '^[a-zA-Z0-9\s\-]{3,10}$') {
                    $true
                }
                else {
                    Throw "Invalid Postal Code: must be 3-10 characters long and contain only alphanumeric characters, spaces, or hyphens."
                }
            })]
        [String]$PostalCode,
        
        [Parameter (Mandatory, ParameterSetName = "ShippingReceiving")]
        [ValidateNotNullOrEmpty()]
        [String]$ShippingReceivingCountry, 

        [Parameter (Mandatory, ParameterSetName = "ShippingReceiving")]
        [ValidateNotNullOrEmpty()]
        [String]$ShippingReceivingStreet, 
        
        [Parameter (ParameterSetName = "ShippingReceiving")]
        [ValidateNotNullOrEmpty()]
        [String]$ShippingReceivingStreet2, 
        
        [Parameter (Mandatory, ParameterSetName = "ShippingReceiving")]
        [ValidateNotNullOrEmpty()]
        [String]$ShippingReceivingCity, 
        
        [Parameter (Mandatory, ParameterSetName = "ShippingReceiving")]
        [ValidateNotNullOrEmpty()]
        [String]$ShippingReceivingState,    

        [Parameter (Mandatory, ParameterSetName = "ShippingReceiving")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
                if ($_ -match '^[a-zA-Z0-9\s\-]{3,10}$') {
                    $true
                }
                else {
                    Throw "Invalid Postal Code: must be 3-10 characters long and contain only alphanumeric characters, spaces, or hyphens."
                }
            })]
        [String]$ShippingReceivingPostalCode,    

        [Parameter (Mandatory, ParameterSetName = "Default")]
        [Parameter (Mandatory, ParameterSetName = "ShippingReceiving")]
        [validatescript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$PrimaryContactEmail,   

        [Parameter (ParameterSetName = "Default")]
        [Parameter (ParameterSetName = "ShippingReceiving")]
        [ValidateScript({
                if ($_ -match '^\+\d+(\s?\d+)*$') {
                    $true
                }
                else {
                    Throw "Invalid phone number format. The number must start with a '+' followed by digits, with or without spaces."
                }
            })]
        [String]$PrimaryContactPhone,  

        [Parameter (ParameterSetName = "Default")]
        [Parameter (ParameterSetName = "ShippingReceiving")]
        [validatescript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$ShippingReceivingContactEmail,   

        [Parameter (ParameterSetName = "Default")]
        [Parameter (ParameterSetName = "ShippingReceiving")]
        [ValidateScript({
                if ($_ -match '^\+\d+(\s?\d+)*$') {
                    $true
                }
                else {
                    Throw "Invalid phone number format. The number must start with a '+' followed by digits, with or without spaces."
                }
            })]
        [String]$ShippingReceivingContactPhone,  

        [Parameter (ParameterSetName = "Default")]
        [Parameter (ParameterSetName = "ShippingReceiving")]
        [validatescript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$SecurityContactEmail,   

        [Parameter (ParameterSetName = "Default")]
        [Parameter (ParameterSetName = "ShippingReceiving")]
        [ValidateScript({
                if ($_ -match '^\+\d+(\s?\d+)*$') {
                    $true
                }
                else {
                    Throw "Invalid phone number format. The number must start with a '+' followed by digits, with or without spaces."
                }
            })]
        [String]$SecurityContactPhone,      
        
        [Parameter (ParameterSetName = "Default")]
        [Parameter (ParameterSetName = "ShippingReceiving")]
        [validatescript({ if ($_ -as [Net.Mail.MailAddress]) { $true } else { Throw "The Parameter value is not an email address. Please correct the value and try again." } })]
        [String]$OperationsContactEmail,   

        [Parameter (ParameterSetName = "Default")]
        [Parameter (ParameterSetName = "ShippingReceiving")]
        [ValidateScript({
                if ($_ -match '^\+\d+(\s?\d+)*$') {
                    $true
                }
                else {
                    Throw "Invalid phone number format. The number must start with a '+' followed by digits, with or without spaces."
                }
            })]
        [String]$OperationsContactPhone,    

        [Parameter (ParameterSetName = "Default")]
        [Parameter (ParameterSetName = "ShippingReceiving")]
        [ValidateSet('6', '12', '18')]
        [String]$ValidationCycle = "12",

        [Parameter (ParameterSetName = "Default")]
        [Parameter (ParameterSetName = "ShippingReceiving")]
        [String]$Tags,

        [Switch]$WhatIf
    ) 

    Begin {

    
        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-DevicesLocationUri  
        $NewLocationStatus = [System.Collections.ArrayList]::new()

               
    }

    Process {         

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name      = $Name
            Status    = $Null
            Details   = $Null
            Exception = $Null
                          
        }

        # Check if location already exists
        try {
            $Locationfound = Get-HPEGLLocation -Name $Name
                
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }


        if ( $Locationfound) {

            # Must return a message if Location is already created 
            "[{0}] Location '{1}' already exists in the workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "Location '{0}': Resource already exists in the workspace! No action needed." -f $Name
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "Location already exists in the workspace! No action needed."
            }
            
        }
        else {

            # Get contact names from emails 
            $PrimaryContactInfo = Get-HPEGLUser -Email $PrimaryContactEmail

            if ( $PrimaryContactInfo) {
                $PrimaryContactName = $PrimaryContactInfo.firstname + " " + $PrimaryContactInfo.lastname
            }
            else {
                "[{0}] {1} contact email is not found in the HPE GreenLake workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $PrimaryContactEmail | Write-Verbose
                if ($WhatIf) {
                    Write-Warning "$PrimaryContactEmail contact email is not found in the HPE GreenLake workspace! Cannot display API request."
                    return
                }
                $objStatus.Status = "Warning"
                $objStatus.Details = "'$PrimaryContactEmail' primary contact email is not found in the HPE GreenLake workspace! Please ensure the email address is valid and try again."
                [void] $NewLocationStatus.add($objStatus)
                return
            }

            if ($ShippingReceivingContactEmail) {

                $ShippingReceivingContactInfo = Get-HPEGLUser -Email $ShippingReceivingContactEmail

                if ( $ShippingReceivingContactInfo) {
                    $ShippingReceivingContactName = $ShippingReceivingContactInfo.firstname + " " + $ShippingReceivingContactInfo.lastname

                }
                else {
                    "[{0}] {1} contact email is not found in the HPE GreenLake workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ShippingReceivingContactEmail | Write-Verbose
                    if ($WhatIf) {
                        Write-Warning "$ShippingReceivingContactEmail contact email is not found in the HPE GreenLake workspace! Cannot display API request."
                        return
                    }
                    $objStatus.Status = "Warning"
                    $objStatus.Details = "'$ShippingReceivingContactEmail' shipping/receiving contact email is not found in the HPE GreenLake workspace! Please ensure the email address is valid and try again."
                    [void] $NewLocationStatus.add($objStatus)
                    return
                }
            }
            
            if ($SecurityContactEmail) {

                $SecurityContactInfo = Get-HPEGLUser -Email $SecurityContactEmail

                if ( $SecurityContactInfo) {
                    $SecurityContactName = $SecurityContactInfo.firstname + " " + $SecurityContactInfo.lastname

                }
                else {
                    "[{0}] {1} contact email is not found in the HPE GreenLake workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SecurityContactEmail | Write-Verbose
                    if ($WhatIf) {
                        Write-Warning "$SecurityContactEmail contact email is not found in the HPE GreenLake workspace! Cannot display API request."
                        return
                    }
                    $objStatus.Status = "Warning"
                    $objStatus.Details = "'$SecurityContactEmail' security contact email is not found in the HPE GreenLake workspace! Please ensure the email address is valid and try again."
                    [void] $NewLocationStatus.add($objStatus)
                    return
                }
            }
            
            if ($OperationsContactEmail) {

                $OperationsContactInfo = Get-HPEGLUser -Email $OperationsContactEmail

                if ( $OperationsContactInfo) {
                    $OperationsContactName = $OperationsContactInfo.firstname + " " + $OperationsContactInfo.lastname

                }
                else {
                    "[{0}] {1} contact email is not found in the HPE GreenLake workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $OperationsContactEmail | Write-Verbose
                    if ($WhatIf) {
                        Write-Warning "$OperationsContactEmail contact email is not found in the HPE GreenLake workspace! Cannot display API request."
                        return
                    }
                    $objStatus.Status = "Warning"
                    $objStatus.Details = "'$OperationsContactEmail' operations contact email is not found in the HPE GreenLake workspace! Please ensure the email address is valid and try again."
                    [void] $NewLocationStatus.add($objStatus)
                    return
                }
            }


            # Defining location street address or location street address with shipping and receiving address

            
            $LocationAddressList = [System.Collections.ArrayList]::new()

            $StreetAddress = [PSCustomObject]@{
                country        = $Country
                streetAddress  = $Street
                streetAddress2 = $Street2
                city           = $City
                state          = $State
                postalCode     = $PostalCode
                type           = "street"

            }

            [void]$LocationAddressList.Add($StreetAddress)

            if ($ShippingReceivingCountry) {

                $ShippingReceivingAddress = [PSCustomObject]@{
                    type           = "shipping_receiving"
                    country        = $ShippingReceivingCountry
                    streetAddress  = $ShippingReceivingStreet
                    streetAddress2 = $ShippingReceivingStreet2
                    city           = $ShippingReceivingCity
                    state          = $ShippingReceivingState
                    postalCode     = $ShippingReceivingPostalCode
                }
                    
                [void]$LocationAddressList.Add($ShippingReceivingAddress)

            }
           
           
            # Defining contacts

            $ContactsList = [System.Collections.ArrayList]::new()


            $PrimaryContact = [PSCustomObject]@{ 
                type        = "primary"
                name        = $PrimaryContactName
                phoneNumber = $PrimaryContactPhone
                email       = $PrimaryContactEmail
            }              
            
            [void]$ContactsList.Add($PrimaryContact)


            if ($ShippingReceivingContactEmail) {
    
                $ShippingReceivingContact = [PSCustomObject]@{ 
                    type        = "shipping_receiving"
                    name        = $ShippingReceivingContactName
                    phoneNumber = $ShippingReceivingContactPhone
                    email       = $ShippingReceivingContactEmail
                }

                [void]$ContactsList.Add($ShippingReceivingContact)

            }
            
            if ($SecurityContactEmail) {

                $SecurityContact = [PSCustomObject]@{ 
                    type        = "security"
                    name        = $SecurityContactName
                    phoneNumber = $SecurityContactPhone
                    email       = $SecurityContactEmail
                }

                [void]$ContactsList.Add($SecurityContact)
            }
            
            if ($OperationsContactEmail) {

                $OperationsContact = [PSCustomObject]@{ 
                    type        = "operations"
                    name        = $OperationsContactName
                    phoneNumber = $OperationsContactPhone
                    email       = $OperationsContactEmail
                }

                [void]$ContactsList.Add($OperationsContact)
            }

            # Building payload

            $Payload = [PSCustomObject]@{
                name             = $Name
                description      = $Description
                locationType     = "building"
                addresses        = $LocationAddressList
                contacts         = $ContactsList
                validated        = $true
                validationCycle  = $ValidationCycle
                validatedByEmail = $Global:HPEGreenLakeSession.username
                validatedByName  = $Global:HPEGreenLakeSession.name

            } | ConvertTo-Json -Depth 5
   
                   
            # Create Location
            try {

                $Response = Invoke-HPEGLWebRequest -Uri $Uri -method 'POST' -body $Payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                
                if (-not $WhatIf) {

                    "[{0}] Location '{1}' successfully created" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                    $objStatus.Status = "Complete"
                    $objStatus.Details = "Location successfully created"

                    # Apply tags if specified
                    if ($PSBoundParameters.ContainsKey('Tags') -and $Tags) {
                        $LocationId = if ($Response.id) { $Response.id } else { (Get-HPEGLLocation -Name $Name).id }
                        if ($LocationId) {
                            $CreateTagsList = [System.Collections.ArrayList]::new()
                            $Tags -split ',' | ForEach-Object {
                                $pair = $_.Trim()
                                if ($pair -match '^([^=]+)\s*=\s*(.*)$') {
                                    [void]$CreateTagsList.Add([PSCustomObject]@{ name = $Matches[1].Trim(); value = $Matches[2].Trim() })
                                }
                            }
                            if ($CreateTagsList.Count -gt 0) {
                                try {
                                    $TagsPayload = [PSCustomObject]@{
                                        locationId = $LocationId
                                        createTags = $CreateTagsList
                                    } | ConvertTo-Json -Depth 5
                                    Invoke-HPEGLWebRequest -Uri (Get-LocationsTagsUri) -method 'PATCH' -body $TagsPayload -ContentType "application/merge-patch+json" -WhatIfBoolean $false -Verbose:$VerbosePreference | Out-Null
                                    "[{0}] Tags applied to location '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                                    $objStatus.Details = "Location successfully created with $($CreateTagsList.Count) tag(s)"
                                }
                                catch {
                                    "[{0}] Failed to apply tags to location '{1}': {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $_.Exception.Message | Write-Verbose
                                }
                            }
                        }
                    }
        
                }

            }
            catch {
                "[{0}] Failed to create location '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Location cannot be created!" }
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData
                }

            }

        }
        

        if (-not $WhatIf) {
            [void] $NewLocationStatus.add($objStatus)
        }

    }

    end {

        if ($NewLocationStatus.Count -gt 0) {

            $NewLocationStatus = Invoke-RepackageObjectWithType -RawObject $NewLocationStatus -ObjectName "ObjStatus.NSDE" 
            Return $NewLocationStatus
        }


    }
}

Function Set-HPEGLLocation {
    <#
    .SYNOPSIS
    Modify an existing physical location.

    .DESCRIPTION
    This Cmdlet modifies physical location information such as addresses (street and shipping/receiving), contacts (primary, shipping/receiving, security, and operations), and other details. 
    
    If you omit any parameter, the cmdlet retains the current settings for those fields and only updates the provided parameters.

    The street address represents the physical location of the devices assigned to the location. It will be used as the default shipping and receiving address for these devices. A different shipping and receiving address can be set if needed. If specified, this alternate address will be used when support cases are generated for devices assigned to the location.

    Note: A location can be assigned to devices for automated HPE support case creation and services using `Set-HPEGLDeviceLocation` or removed with `Remove-HPEGLDeviceLocation`.
    
    .PARAMETER Name 
    Specifies the name of the physical location.

    .PARAMETER NewName 
    (Optional) Sets a new name for the location.

    .PARAMETER Description 
    (Optional) Sets a description of the location.

    .PARAMETER Country 
    (Optional) Sets the country of the street address of the location.

    .PARAMETER Street 
    (Optional) Sets the street address of the street address of the location.

    .PARAMETER Street2 
    (Optional) Sets the secondary street address of the street address of the location.

    .PARAMETER City 
    (Optional) Sets the city of the street address of the location.
        
    .PARAMETER State 
    (Optional) Sets the state of the street address of the location.

    .PARAMETER PostalCode 
    (Optional) Sets the postal code of the street address of the location.

    .PARAMETER ShippingReceivingCountry
    (Optional) Sets the country for the shipping and receiving address if it differs from the street address.        

    .PARAMETER ShippingReceivingStreet
    (Optional) Sets the street for the shipping and receiving address if it differs from the street address.     

    .PARAMETER ShippingReceivingStreet2
    (Optional) Sets the secondary street for the shipping and receiving address if it differs from the street address.  

    .PARAMETER ShippingReceivingCity
    (Optional) Sets the city for the shipping and receiving address if it differs from the street address.  

    .PARAMETER ShippingReceivingState
    (Optional) Sets the state for the shipping and receiving address if it differs from the street address.  

    .PARAMETER ShippingReceivingPostalCode
    (Optional) Sets the postal code for the shipping and receiving address if it differs from the street address. 

    .PARAMETER RemoveShippingReceivingAddress
    (Optional) Deletes the shipping and receiving address of the location.

    .PARAMETER PrimaryContactEmail
    (Optional) Sets the primary contact email address of the location.    

    .PARAMETER PrimaryContactPhone
    (Optional) Sets the primary contact phone number of the location.

    .PARAMETER ShippingReceivingContactEmail
    (Optional) Sets the shipping and receiving contact email address of the location.

    .PARAMETER ShippingReceivingContactPhone
    (Optional) Sets the shipping and receiving contact phone number of the location.

    .PARAMETER RemoveShippingReceivingContact
    (Optional) Deletes the shipping and receiving contact of the location.

    .PARAMETER SecurityContactEmail
    (Optional) Sets the security contact email address of the location.

    .PARAMETER SecurityContactPhone
    (Optional) Sets the security contact phone number of the location.

    .PARAMETER RemoveSecurityContact
    (Optional) Deletes the security contact of the location.

    .PARAMETER OperationsContactEmail
    (Optional) Sets the operations contact email address of the location.

    .PARAMETER OperationsContactPhone
    (Optional) Sets the operations contact phone number of the location.

    .PARAMETER RemoveOperationsContact
    (Optional) Deletes the operations contact of the location.

    .PARAMETER Tags
    (Optional) Tags to add or update on the location. Tags must be in the format: <Name>=<Value>, <Name>=<Value>.
    Example: "Country=US, Site=Datacenter1"

    .PARAMETER RemoveTags
    (Optional) Tag names to remove from the location. Accepts a comma-separated list of tag names.
    Example: "Country, Site"

    .PARAMETER RemoveAllTags
    (Optional) Removes all tags from the location.

    .PARAMETER ValidationCycle
    (Optional) Sets how often you would like to validate this location. Valid values are 6, 12 or 18 months.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.
        
   .EXAMPLE
    Set-HPEGLLocation -Name "Mougins" -NewName "HPE Mougins" -Description "Location in Central Europe"
    Renames the "Mougins" location to "HPE Mougins" and changes its description.

    .EXAMPLE
    Set-HPEGLLocation -Name "Mougins" -Description ""

    Removes the description set for the "Mougins" location.

    .EXAMPLE
    Set-HPEGLLocation -Name "Boston" -Country 'United States' -Street "321 Summer Street" -Street2 "5th floor" -City "Boston" -State "MA" -PostalCode "02210"

    Modifies the street address of the "Boston" location.

    .EXAMPLE
    Set-HPEGLLocation -Name "Boston" -Street2 ""

    Removes the secondary street address from the "Boston" location's street address.

    .EXAMPLE
    Set-HPEGLLocation -Name "Houston" -PrimaryContactEmail TheBoss@email.com -PrimaryContactPhone "+123456789"

    Modifies the "Houston" location with a primary contact email and phone number.

    .EXAMPLE
    Set-HPEGLLocation -Name "Mougins" -ShippingReceivingCountry "France" -ShippingReceivingStreet "790 Avenue du Docteur Donat" -ShippingReceivingStreet2 "Marco Polo - Batiment B" -ShippingReceivingCity "Mougins" -ShippingReceivingPostalCode 06254

    Adds or modifies the shipping and receiving address for the "Mougins" location.

    .EXAMPLE
    Set-HPEGLLocation -Name "Boston" -RemoveShippingReceivingAddress

    Removes the existing shipping and receiving address from the "Boston" location.

    .EXAMPLE
    Set-HPEGLLocation -Name "Mougins" -ShippingReceivingContactEmail TheTech@email.com -ShippingReceivingContactPhone "+123456789"

    Modifies or adds the shipping and receiving contact information for the "Mougins" location.

    .EXAMPLE
    Set-HPEGLLocation -Name Barcelona -RemoveShippingReceivingContact

    Removes the existing shipping and receiving contact information from the "Barcelona" location.

    .EXAMPLE
    Set-HPEGLLocation -Name Barcelona -SecurityContactEmail Thesecurity@email.com -SecurityContactPhone "+3360000001"

    Modifies or adds the security contact information for the "Barcelona" location.

    .EXAMPLE
    Set-HPEGLLocation -Name Barcelona -RemoveSecurityContact

    Removes the existing security contact from the "Barcelona" location.

    .EXAMPLE
    Set-HPEGLLocation -Name Barcelona -OperationsContactEmail TheOperations@email.com -OperationsContactPhone "+1123456789"

    Modifies or adds the operations contact information for the "Barcelona" location.

    .EXAMPLE
    Set-HPEGLLocation -Name Barcelona -RemoveOperationsContact

    Removes the existing operations contact from the "Barcelona" location.

    .EXAMPLE
    Get-HPEGLLocation | Set-HPEGLLocation -SecurityContactEmail security@domain.com -SecurityContactPhone +123456789123

    Modifies or adds security contact information for all locations found in the currently connected HPE GreenLake workspace.

    .EXAMPLE
    Set-HPEGLLocation -Name "Mougins" -Tags "Country=FR, Site=HQ"

    Adds or updates tags on the "Mougins" location.

    .EXAMPLE
    Set-HPEGLLocation -Name "Mougins" -RemoveTags "Country, Site"

    Removes the "Country" and "Site" tags from the "Mougins" location.

    .EXAMPLE
    Set-HPEGLLocation -Name "Mougins" -RemoveAllTags

    Removes all tags from the "Mougins" location.

    .INPUTS
    System.Collections.ArrayList
        List of location(s) from 'Get-HPEGLLocation'.

    .OUTPUTS
    System.Collections.ArrayList    
    A custom status object or array of objects containing the following PsCustomObject keys:  
    * Name - name of the location object attempted to be modified 
    * Status - status of the modification attempt (Failed for HTTP error return; Complete if successful; Warning if no action is needed) 
    * Details - more information about the status 
    * Exception - information about any exceptions generated during the operation.
    #>

    [CmdletBinding(DefaultParameterSetName = 'Details')]
    Param( 

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [String]$Name,

        [Parameter (ParameterSetName = "Details")]
        [String]$NewName,

        [Parameter (ParameterSetName = "Details")]
        [String]$Description,

        [Parameter (ParameterSetName = "PrimaryAddress")]
        [ArgumentCompleter({
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $countryNames = $Global:HPEGLSchemaMetadata.hpeCountryCodes.Name
                $countryNames | Where-Object { $_ -like "$wordToComplete*" } | Sort-Object
            })]
        [ValidateScript({
                $countryNames = $Global:HPEGLSchemaMetadata.hpeCountryCodes.Name
                if ($countryNames -contains $_) { 
                    $true 
                }
                else { 
                    Throw "Country '$_' is not valid. Supported countries are: $($countryNames -join ', ')."
                }
            })]
        [ValidateNotNullOrEmpty()]
        [String]$Country,

        [Parameter (ParameterSetName = "PrimaryAddress")]
        [String]$Street,

        [Parameter (ParameterSetName = "PrimaryAddress")]
        [String]$Street2,        

        [Parameter (ParameterSetName = "PrimaryAddress")]
        [String]$City,

        [Parameter (ParameterSetName = "PrimaryAddress")]
        [String]$State,

        [Parameter (ParameterSetName = "PrimaryAddress")]
        [ValidateScript({
                if ($_ -match '^[a-zA-Z0-9\s\-]{3,10}$') {
                    $true
                }
                else {
                    Throw "Invalid Postal Code: must be 3-10 characters long and contain only alphanumeric characters, spaces, or hyphens."
                }
            })]
        [String]$PostalCode,
        
        [Parameter (ParameterSetName = "ShippingReceivingAddress")]
        [String]$ShippingReceivingCountry, 

        [Parameter (ParameterSetName = "ShippingReceivingAddress")]
        [String]$ShippingReceivingStreet, 
        
        [Parameter (ParameterSetName = "ShippingReceivingAddress")]
        [String]$ShippingReceivingStreet2, 
        
        [Parameter (ParameterSetName = "ShippingReceivingAddress")]
        [String]$ShippingReceivingCity, 
        
        [Parameter (ParameterSetName = "ShippingReceivingAddress")]
        [String]$ShippingReceivingState,    

        [Parameter (ParameterSetName = "ShippingReceivingAddress")]
        [ValidateScript({
                if ($_ -match '^[a-zA-Z0-9\s\-]{3,10}$') {
                    $true
                }
                else {
                    Throw "Invalid Postal Code: must be 3-10 characters long and contain only alphanumeric characters, spaces, or hyphens."
                }
            })]
        [String]$ShippingReceivingPostalCode,    

        [Parameter (ParameterSetName = "RemoveShippingReceivingAddress")]
        [Switch]$RemoveShippingReceivingAddress,    

        [Parameter (ParameterSetName = "PrimaryContact")]
        [String]$PrimaryContactEmail,   

        [Parameter (ParameterSetName = "PrimaryContact")]
        [String]$PrimaryContactPhone,
        
        [Parameter (ParameterSetName = "PrimaryContact")]
        [String]$PrimaryContactName,

        [Parameter (ParameterSetName = "ShippingReceivingContact")]
        [String]$ShippingReceivingContactEmail,   

        [Parameter (ParameterSetName = "ShippingReceivingContact")]
        [String]$ShippingReceivingContactPhone,
        
        [Parameter (ParameterSetName = "ShippingReceivingContact")]
        [String]$ShippingReceivingContactName,
        
        [Parameter (ParameterSetName = "RemoveShippingReceivingContact")]
        [Switch]$RemoveShippingReceivingContact,    

        [Parameter (ParameterSetName = "SecurityContact")]
        [String]$SecurityContactEmail,   

        [Parameter (ParameterSetName = "SecurityContact")]
        [String]$SecurityContactPhone,  
        
        [Parameter (ParameterSetName = "RemoveSecurityContact")]
        [Switch]$RemoveSecurityContact,    
        
        [Parameter (ParameterSetName = "OperationsContact")]
        [String]$OperationsContactEmail,   

        [Parameter (ParameterSetName = "OperationsContact")]
        [String]$OperationsContactPhone,  
        
        [Parameter (ParameterSetName = "RemoveOperationsContact")]
        [Switch]$RemoveOperationsContact,  

        [Parameter (ParameterSetName = "Tags")]
        [String]$Tags,

        [Parameter (ParameterSetName = "RemoveTags")]
        [String]$RemoveTags,

        [Parameter (ParameterSetName = "RemoveAllTags")]
        [Switch]$RemoveAllTags,

        [ValidateSet('6', '12', '18')]
        [String]$ValidationCycle,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose
        "[{0}] Parameter Set Name: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $PSCmdlet.ParameterSetName | Write-Verbose
        "[{0}] All Parameters bound: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters.Keys -join ', ') | Write-Verbose
        
        # Check specific postal code parameters
        if ($PSBoundParameters.ContainsKey('PostalCode')) {
            "[{0}] PostalCode parameter IS bound with value: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $PostalCode | Write-Verbose
        }
        if ($PSBoundParameters.ContainsKey('ShippingReceivingPostalCode')) {
            "[{0}] ShippingReceivingPostalCode parameter IS bound with value: '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ShippingReceivingPostalCode | Write-Verbose
        }

        $ObjectStatusList = [System.Collections.ArrayList]::new()
        $InputList = [System.Collections.ArrayList]::new()

               
    }

    Process {         

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name      = $Name
            Status    = $Null
            Details   = $Null
            Exception = $Null
                          
        }
        

        [void] $InputList.Add($objStatus)
        if (-not $WhatIf) { [void] $ObjectStatusList.Add($objStatus) }

    }

    end {

        "[{0}] Entering END block" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose

        try {
            
            "[{0}] About to call Get-HPEGLLocation" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            $Locations = Get-HPEGLLocation -ShowDetails
            "[{0}] Get-HPEGLLocation returned {1} locations" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Locations.Count | Write-Verbose
            
            "[{0}] About to call Get-HPEGLUser" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
            $Users = Get-HPEGLUser 
            "[{0}] Get-HPEGLUser returned {1} users" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Users.Count | Write-Verbose
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }
        
        "[{0}] About to start foreach loop, ObjectStatusList has {1} items" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ObjectStatusList.Count | Write-Verbose
        "[{0}] Locations variable type: {1}, Count: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Locations.GetType().Name, $Locations.Count | Write-Verbose
        "[{0}] Locations[0] properties: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), (($Locations[0].PSObject.Properties.Name) -join ', ') | Write-Verbose
        
        foreach ($Object in $InputList) {
            
            "[{0}] Inside foreach, processing object: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Object.Name | Write-Verbose
            $Locationfound = $Locations | Where-Object name -eq $Object.Name
            "[{0}] Found location: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Locationfound -ne $null) | Write-Verbose

            if (-not $Locationfound) {

                # Must return a message if location is not found
                if ($WhatIf) {
                    $ErrorMessage = "Location '{0}': Resource cannot be found in the workspace!" -f $Object.Name
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }
                else {
                    $Object.Status = "Warning"
                    $Object.Details = "Location cannot be found in the workspace! No action needed."
                }

            }
            else {
                
                "[{0}] Entered ELSE block - location found, starting processing" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                $Uri = (Get-DevicesLocationUri) + "/update/" + $Locationfound.id
                "[{0}] Uri built: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Uri | Write-Verbose
                                
                $LocationAddressList = [System.Collections.ArrayList]::new()
                $AddressesToDelete = [System.Collections.ArrayList]::new()
                $ContactsToDelete = [System.Collections.ArrayList]::new()
                $ContactsToAdd = [System.Collections.ArrayList]::new()
                
                "[{0}] Created array lists, about to validate emails" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                
                #Region Validate emails
                if ($PrimaryContactEmail) {

                    # Use provided name if specified
                    if ($PSBoundParameters.ContainsKey('PrimaryContactName')) {
                        $PrimaryContactName = $PrimaryContactName
                    }
                    else {
                        # Try to get name from workspace users
                        $PrimaryContactInfo = $Users | Where-Object email -eq $PrimaryContactEmail
                        
                        if ( $PrimaryContactInfo) {
                            $PrimaryContactName = $PrimaryContactInfo.displayName
                        }
                        else {
                            "[{0}] Contact email '{1}' cannot be found in the HPE GreenLake workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $PrimaryContactEmail | Write-Verbose
                            if ($WhatIf) {
                                $ErrorMessage = "Contact email '{0}' cannot be found in the HPE GreenLake workspace! Use Get-HPEGLUser to see available users." -f $PrimaryContactEmail
                                Write-Warning "$ErrorMessage Cannot display API request."
                                continue
                            }
                            else {
                                $Object.Status = "Warning"
                                $Object.Details = "Contact email '$PrimaryContactEmail' cannot be found in the HPE GreenLake workspace! Use Get-HPEGLUser to see available users."
                            }
                        }
                    }
                }          

                if ($ShippingReceivingContactEmail) {
                   
                    $ShippingReceivingContactInfo = $Users | Where-Object email -eq $ShippingReceivingContactEmail

                    if ( $ShippingReceivingContactInfo) {
                        $ShippingReceivingContactName = $ShippingReceivingContactInfo.displayName

                    }
                    else {
                        "[{0}] Contact email '{1}' cannot be found in the HPE GreenLake workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ShippingReceivingContactEmail | Write-Verbose
                        if ($WhatIf) {
                            $ErrorMessage = "Contact email '{0}' cannot be found in the HPE GreenLake workspace! Use Get-HPEGLUser to see available users." -f $ShippingReceivingContactEmail
                            Write-Warning "$ErrorMessage Cannot display API request."
                            continue
                        }
                        else {
                            $Object.Status = "Warning"
                            $Object.Details = "Contact email '$ShippingReceivingContactEmail' cannot be found in the HPE GreenLake workspace! Use Get-HPEGLUser to see available users."
                        }
                    }
                }
                
                if ($SecurityContactEmail) {
                  
                    $SecurityContactInfo = $Users | Where-Object email -eq $SecurityContactEmail

                    if ( $SecurityContactInfo) {
                        $SecurityContactName = $SecurityContactInfo.displayName

                    }
                    else {
                        "[{0}] Contact email '{1}' cannot be found in the HPE GreenLake workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $SecurityContactEmail | Write-Verbose
                        if ($WhatIf) {
                            $ErrorMessage = "Contact email '{0}' cannot be found in the HPE GreenLake workspace! Use Get-HPEGLUser to see available users." -f $SecurityContactEmail
                            Write-Warning "$ErrorMessage Cannot display API request."
                            continue
                        }
                        else {
                            $Object.Status = "Warning"
                            $Object.Details = "Contact email '$SecurityContactEmail' cannot be found in the HPE GreenLake workspace! Use Get-HPEGLUser to see available users."
                        }
                    }
                }
                
                if ($OperationsContactEmail) {
                   
                    $OperationsContactInfo = $Users | Where-Object email -eq $OperationsContactEmail

                    if ( $OperationsContactInfo) {
                        $OperationsContactName = $OperationsContactInfo.displayName

                    }
                    else {
                        "[{0}] Contact email '{1}' cannot be found in the HPE GreenLake workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $OperationsContactEmail | Write-Verbose
                        if ($WhatIf) {
                            $ErrorMessage = "Contact email '{0}' cannot be found in the HPE GreenLake workspace! Use Get-HPEGLUser to see available users." -f $OperationsContactEmail
                            Write-Warning "$ErrorMessage Cannot display API request."
                            continue
                        }
                        else {
                            $Object.Status = "Warning"
                            $Object.Details = "Contact email '$OperationsContactEmail' cannot be found in the HPE GreenLake workspace! Use Get-HPEGLUser to see available users."
                        }
                    }
                }


                #EndRegion

                #Region Modifying details (Name or Description)

                if ($NewName) {

                    # newname cannot be used when more than one location is found in $ObjectStatusList
                    if ($ObjectStatusList.Count -gt 1) {
                        "[{0}] NewName cannot be used when more than one location is found in the pipeline!" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                        if ($WhatIf) {
                            Write-Warning "NewName cannot be used when more than one location is found in the pipeline! Cannot display API request."
                            continue
                        }
                        else {
                            $Object.Status = "Warning"
                            $Object.Details = "NewName cannot be used when more than one location is found in the pipeline!"
                        }
                    }
                    else {
                        $Name = $NewName
                    }

                }

                #EndRegion
            
                #Region Modifying street address
                if ($PSBoundParameters.ContainsKey('Country') -or $PSBoundParameters.ContainsKey('Street') -or $PSBoundParameters.ContainsKey('Street2') -or $PSBoundParameters.ContainsKey('City') -or $PSBoundParameters.ContainsKey('State') -or $PSBoundParameters.ContainsKey('PostalCode')) {
                
                    # Get existing street address to fill in missing values
                    $existingStreet = $Locationfound.addresses | Where-Object type -eq street
                    $PrimaryAddressId = $existingStreet.id

                    # Use provided values or fall back to existing ones
                    if (-not $PSBoundParameters.ContainsKey('Country')) {
                        $tempCountry = $existingStreet.country
                        if ($tempCountry -and $Global:HPEGLSchemaMetadata.hpeCountryCodes.Name -contains $tempCountry) {
                            $Country = $tempCountry
                        }
                    }
                    if (-not $PSBoundParameters.ContainsKey('Street')) { $Street = $existingStreet.streetAddress }
                    if (-not $PSBoundParameters.ContainsKey('Street2')) { $Street2 = $existingStreet.streetAddress2 }
                    if (-not $PSBoundParameters.ContainsKey('City')) { $City = $existingStreet.city }
                    if (-not $PSBoundParameters.ContainsKey('State')) { $State = $existingStreet.state }
                    if (-not $PSBoundParameters.ContainsKey('PostalCode')) {
                        $tempPostalCode = $existingStreet.postalCode
                        if ($tempPostalCode -and $tempPostalCode -match '^[a-zA-Z0-9\s\-]{3,10}$') {
                            $PostalCode = $tempPostalCode
                        }
                    }

                    $StreetAddress = [PSCustomObject]@{
                        country        = $Country
                        streetAddress  = $Street
                        streetAddress2 = $Street2
                        city           = $City
                        state          = $State
                        postalCode     = $PostalCode
                        type           = "street"
                        id             = $PrimaryAddressId
                    }

                    [void]$LocationAddressList.Add($StreetAddress)
                }
                #Endregion

                #Region Modifying shipping/receiving address

                if ($PSBoundParameters.ContainsKey('ShippingReceivingCountry') -or $PSBoundParameters.ContainsKey('ShippingReceivingStreet') -or $PSBoundParameters.ContainsKey('ShippingReceivingStreet2') `
                        -or $PSBoundParameters.ContainsKey('ShippingReceivingCity') -or $PSBoundParameters.ContainsKey('ShippingReceivingState') -or $PSBoundParameters.ContainsKey('ShippingReceivingPostalCode')) {

                    # Get existing shipping/receiving address to fill in missing values
                    $existingShipping = $Locationfound.addresses | Where-Object type -eq shipping_receiving

                    # Use provided values or fall back to existing ones
                    if (-not $PSBoundParameters.ContainsKey('ShippingReceivingCountry')) { $ShippingReceivingCountry = $existingShipping.country }
                    if (-not $PSBoundParameters.ContainsKey('ShippingReceivingStreet')) { $ShippingReceivingStreet = $existingShipping.streetAddress }
                    if (-not $PSBoundParameters.ContainsKey('ShippingReceivingStreet2')) { $ShippingReceivingStreet2 = $existingShipping.streetAddress2 }
                    if (-not $PSBoundParameters.ContainsKey('ShippingReceivingCity')) { $ShippingReceivingCity = $existingShipping.city }
                    if (-not $PSBoundParameters.ContainsKey('ShippingReceivingState')) { 
                        $ShippingReceivingState = if ($existingShipping.state) { $existingShipping.state } else { "N/A" }
                    }
                    if (-not $PSBoundParameters.ContainsKey('ShippingReceivingPostalCode')) {
                        $tempShippingPostalCode = $existingShipping.postalCode
                        if ($tempShippingPostalCode -and $tempShippingPostalCode -match '^[a-zA-Z0-9\s\-]{3,10}$') {
                            $ShippingReceivingPostalCode = $tempShippingPostalCode
                        }
                    }

                    # If already exists, include ID for deletion
                    if ($existingShipping.id) {
                        $ShippingAddressId = $existingShipping.id
                        
                        $ShippingReceivingAddress = [PSCustomObject]@{
                            country        = $ShippingReceivingCountry
                            streetAddress  = $ShippingReceivingStreet
                            streetAddress2 = $ShippingReceivingStreet2
                            city           = $ShippingReceivingCity
                            state          = $ShippingReceivingState
                            postalCode     = $ShippingReceivingPostalCode
                            type           = "shipping_receiving"
                            id             = $ShippingAddressId 
                        }
                    }
                    else {
                        $ShippingReceivingAddress = [PSCustomObject]@{
                            country        = $ShippingReceivingCountry
                            streetAddress  = $ShippingReceivingStreet
                            streetAddress2 = $ShippingReceivingStreet2
                            city           = $ShippingReceivingCity
                            state          = $ShippingReceivingState
                            postalCode     = $ShippingReceivingPostalCode
                            type           = "shipping_receiving"
                        }

                    }
                        
                    [void]$LocationAddressList.Add($ShippingReceivingAddress)
                }

                #Endregion
                
                #Region Removing Shipping/receiving address
                if ($RemoveShippingReceivingAddress) {
        
                    $ShippingAddressId = ($Locationfound.addresses | Where-Object type -eq shipping_receiving).id
        
                    if (! $ShippingAddressId) {
    
                        "[{0}] There is no Shipping and Receiving address for the '{1}' location!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

                        if ($WhatIf) {
                            $ErrorMessage = "There is no Shipping and Receiving address in location '{0}' to be removed!" -f $Object.Name
                            Write-Warning "$ErrorMessage Cannot display API request."
                            continue
                        }
                        else {
                            $Object.Status = "Warning"
                            $Object.Details = "There is no Shipping and Receiving address in this location to be removed!"
                        }

                    }
                    else {
                        # For removal, add ID to delete array
                        [void]$AddressesToDelete.Add($ShippingAddressId)
                    }
                }
                #Endregion

                #Region Modifying primary contact

                if ($PSBoundParameters.ContainsKey('PrimaryContactEmail') -or $PSBoundParameters.ContainsKey('PrimaryContactPhone')) {
            
                    $PrimaryContactId = ($Locationfound.contacts | Where-Object type -eq primary).id
                    
                    # If contact exists, delete it first
                    if ($PrimaryContactId) {
                        [void]$ContactsToDelete.Add($PrimaryContactId)
                    }
                    
                    # Add the new/updated contact (always required: email, name, type)
                    $PrimaryContact = [PSCustomObject]@{ 
                        email       = $PrimaryContactEmail
                        name        = $PrimaryContactName
                        type        = "primary"
                        phoneNumber = $PrimaryContactPhone
                    }
                
                    [void]$ContactsToAdd.Add($PrimaryContact)

                }

                #EndRegion

                #Region Modifying shipping/receiving contact

                if ($PSBoundParameters.ContainsKey('ShippingReceivingContactEmail') -or $PSBoundParameters.ContainsKey('ShippingReceivingContactPhone')) {
            
                    $ShippingReceivingContactId = ($Locationfound.contacts | Where-Object type -eq shipping_receiving).id
                    
                    # If contact exists, mark for deletion
                    if ($ShippingReceivingContactId) {
                        [void]$ContactsToDelete.Add($ShippingReceivingContactId)
                    }
                    
                    # Add the new/updated contact
                    $ShippingReceivingContact = [PSCustomObject]@{ 
                        email       = $ShippingReceivingContactEmail
                        name        = $ShippingReceivingContactName
                        type        = "shipping_receiving"
                        phoneNumber = $ShippingReceivingContactPhone
                    }
                
                    [void]$ContactsToAdd.Add($ShippingReceivingContact)

                }

                #EndRegion

                #Region Remove Shipping/Receiving Contact
                if ($RemoveShippingReceivingContact) {
                    
                    $ShippingReceivingContactId = ($Locationfound.contacts | Where-Object type -eq shipping_receiving).id

                    if ( ! $ShippingReceivingContactId) {
                        
                        "[{0}] There is no Shipping and Receiving contact for the '{1}' location!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                        
                        if ($WhatIf) {
                            $ErrorMessage = "There is no Shipping and Receiving contact in location '{0}' to be removed!" -f $Object.Name
                            Write-Warning "$ErrorMessage Cannot display API request."
                            continue
                        }
                        else {
                            $Object.Status = "Warning"
                            $Object.Details = "There is no Shipping and Receiving contact in this location to be removed!"
                        }

                    }
                    else {
                        [void]$ContactsToDelete.Add($ShippingReceivingContactId)
                    }
                }
                #Endregion

                #Region Modifying security contact

                if ($PSBoundParameters.ContainsKey('SecurityContactEmail') -or $PSBoundParameters.ContainsKey('SecurityContactPhone')) {
            
                    $SecurityContactId = ($Locationfound.contacts | Where-Object type -eq security).id
                    
                    # If contact exists, mark for deletion
                    if ($SecurityContactId) {
                        [void]$ContactsToDelete.Add($SecurityContactId)
                    }
                    
                    # Add the new/updated contact
                    $SecurityContact = [PSCustomObject]@{ 
                        email       = $SecurityContactEmail
                        name        = $SecurityContactName
                        type        = "security"
                        phoneNumber = $SecurityContactPhone
                    }
                
                    [void]$ContactsToAdd.Add($SecurityContact)

                }
                #Endregion

                #Region Remove Security Contact
                if ($RemoveSecurityContact) {
                    
                    $SecurityContactId = ($Locationfound.contacts | Where-Object type -eq security).id

                    if ( ! $SecurityContactId) {
                        
                        "[{0}] There is no security contact for the '{1}' location!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

                        if ($WhatIf) {
                            $ErrorMessage = "There is no security contact in location '{0}' to be removed!" -f $Object.Name
                            Write-Warning "$ErrorMessage Cannot display API request."
                            continue
                        }
                        else {
                            $Object.Status = "Warning"
                            $Object.Details = "There is no security contact in this location to be removed!"
                        }

                    }
                    else {
                        [void]$ContactsToDelete.Add($SecurityContactId)
                    }
                }
                #Endregion

                #Region Modifying operations contact

                if ($PSBoundParameters.ContainsKey('OperationsContactEmail') -or $PSBoundParameters.ContainsKey('OperationsContactPhone')) {
            
                    $OperationsContactId = ($Locationfound.contacts | Where-Object type -eq operations).id
                    
                    # If contact exists, mark for deletion
                    if ($OperationsContactId) {
                        [void]$ContactsToDelete.Add($OperationsContactId)
                    }
                    
                    # Add the new/updated contact
                    $OperationsContact = [PSCustomObject]@{ 
                        email       = $OperationsContactEmail
                        name        = $OperationsContactName
                        type        = "operations"
                        phoneNumber = $OperationsContactPhone
                    }
                
                    [void]$ContactsToAdd.Add($OperationsContact)

                }
                #Endregion

                #Region Remove Operations Contact
                if ($RemoveOperationsContact) {

                    $OperationsContactId = ($Locationfound.contacts | Where-Object type -eq operations).id

                    if ( ! $OperationsContactId) {
                        
                        "[{0}] There is no operations contact for the '{1}' location!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                        
                        if ($WhatIf) {
                            $ErrorMessage = "There is no operations contact in location '{0}' to be removed!" -f $Object.Name
                            Write-Warning "$ErrorMessage Cannot display API request."
                            continue
                        }
                        else {
                            $Object.Status = "Warning"
                            $Object.Details = "There is no operations contact in this location to be removed!"
                        }

                    }
                    else {
                        [void]$ContactsToDelete.Add($OperationsContactId)
                    }
                }
                #Endregion


                # Building payloads - only include properties being changed
                $NameDescriptionPayload = $null
                $AddressPayload = $null

                # Build name/description payload if being changed
                if ($PSBoundParameters.ContainsKey('NewName') -or $PSBoundParameters.ContainsKey('Description') -or $PSBoundParameters.ContainsKey('ValidationCycle')) {
                    $NameDescObj = [PSCustomObject]@{}
                    
                    if ($PSBoundParameters.ContainsKey('NewName')) {
                        $NameDescObj | Add-Member -MemberType NoteProperty -Name "name" -Value $Name
                    }
                    
                    if ($PSBoundParameters.ContainsKey('Description')) {
                        $NameDescObj | Add-Member -MemberType NoteProperty -Name "description" -Value $Description
                    }

                    if ($PSBoundParameters.ContainsKey('ValidationCycle')) {
                        $NameDescObj | Add-Member -MemberType NoteProperty -Name "validationCycle" -Value $ValidationCycle
                    }
                    
                    $NameDescriptionPayload = $NameDescObj | ConvertTo-Json -Depth 5
                }

                # Build address payload if being changed
                if ($LocationAddressList.Count -gt 0 -or $AddressesToDelete.Count -gt 0) {
                    # Addresses: include ID in "add" to update in place, or omit ID to create new
                    $AddressPayloadObj = [PSCustomObject]@{}
                    
                    $AddressesToAdd = @()
                    
                    foreach ($addr in $LocationAddressList) {
                        if ($addr.id) {
                            # Has ID - include it in the add section to update in place
                            $AddressesToAdd += $addr
                        }
                        else {
                            # No ID - add as new address
                            $AddressesToAdd += $addr
                        }
                    }
                    
                    if ($AddressesToDelete.Count -gt 0) {
                        $AddressPayloadObj | Add-Member -MemberType NoteProperty -Name "delete" -Value $AddressesToDelete
                    }
                    
                    if ($AddressesToAdd.Count -gt 0) {
                        $AddressPayloadObj | Add-Member -MemberType NoteProperty -Name "add" -Value $AddressesToAdd
                    }
                    
                    $AddressPayload = [PSCustomObject]@{
                        addresses = $AddressPayloadObj
                    } | ConvertTo-Json -Depth 5
                }

                    
                # Modify Location
                if (-not $Object.Status) {
                    try {

                        # Handle contacts - single atomic operation with both delete and add
                        if ($ContactsToDelete.Count -gt 0 -or $ContactsToAdd.Count -gt 0) {
                            "[{0}] Updating contacts (delete: {1}, add: {2})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ContactsToDelete.Count, $ContactsToAdd.Count | Write-Verbose
                        
                            $ContactsPayload = [PSCustomObject]@{}
                        
                            if ($ContactsToDelete.Count -gt 0) {
                                $ContactsPayload | Add-Member -MemberType NoteProperty -Name "delete" -Value $ContactsToDelete
                            }
                        
                            if ($ContactsToAdd.Count -gt 0) {
                                $ContactsPayload | Add-Member -MemberType NoteProperty -Name "add" -Value $ContactsToAdd
                            }
                        
                            $ContactUpdatePayload = [PSCustomObject]@{
                                contacts = $ContactsPayload
                            } | ConvertTo-Json -Depth 5
                        
                            $Response = Invoke-HPEGLWebRequest -Uri $Uri -method 'PATCH' -body $ContactUpdatePayload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                            "[{0}] Contact update successful" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                        }
                    
                        # Update name/description if needed
                        if ($NameDescriptionPayload) {
                            "[{0}] Updating name/description" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            $Response = Invoke-HPEGLWebRequest -Uri $Uri -method 'PATCH' -body $NameDescriptionPayload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                        }
                    
                        # Update addresses if needed
                        if ($AddressPayload) {
                            "[{0}] Updating addresses" -f $MyInvocation.InvocationName.ToString().ToUpper() | Write-Verbose
                            $Response = Invoke-HPEGLWebRequest -Uri $Uri -method 'PATCH' -body $AddressPayload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                        }

                        # Update tags if needed
                        if ($PSCmdlet.ParameterSetName -in @('Tags', 'RemoveTags', 'RemoveAllTags')) {
                            $TagsUri = Get-LocationsTagsUri
                            $TagsPayloadObj = [PSCustomObject]@{ locationId = $Locationfound.id }

                            if ($PSCmdlet.ParameterSetName -eq 'Tags') {
                                # Parse the requested tags
                                $RequestedTags = [System.Collections.ArrayList]::new()
                                $Tags -split ',' | ForEach-Object {
                                    $pair = $_.Trim()
                                    if ($pair -match '^([^=]+)\s*=\s*(.*)$') {
                                        [void]$RequestedTags.Add([PSCustomObject]@{ name = $Matches[1].Trim(); value = $Matches[2].Trim() })
                                    }
                                }
                                if ($RequestedTags.Count -eq 0) {
                                    "[{0}] No valid tags found in '{1}'." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Tags | Write-Verbose
                                    if ($WhatIf) {
                                        Write-Warning "No valid tags found in '$Tags'. Tags must be in 'Key=Value' format. Cannot display API request."
                                        continue
                                    }
                                    else {
                                        $Object.Status = "Warning"
                                        $Object.Details = "No valid tags found in '$Tags'. Tags must be in 'Key=Value' format."
                                    }
                                }

                                # Compare against existing tags:
                                #  - same name + same value  → skip (already set)
                                #  - same name + diff value  → delete old + create new
                                #  - new name                → create only
                                $CreateTagsList = [System.Collections.ArrayList]::new()
                                $DeleteTagsList = [System.Collections.ArrayList]::new()

                                foreach ($requested in $RequestedTags) {
                                    $existing = $Locationfound.tags | Where-Object { $_.name -ieq $requested.name }
                                    if ($existing) {
                                        if ($existing.value -eq $requested.value) {
                                            "[{0}] Tag '{1}={2}' already set on location '{3}', skipping" -f $MyInvocation.InvocationName.ToString().ToUpper(), $requested.name, $requested.value, $Locationfound.name | Write-Verbose
                                        }
                                        else {
                                            # Delete old value, add new value
                                            [void]$DeleteTagsList.Add([PSCustomObject]@{ name = $existing.name; value = $existing.value })
                                            [void]$CreateTagsList.Add([PSCustomObject]@{ name = $requested.name; value = $requested.value })
                                        }
                                    }
                                    else {
                                        [void]$CreateTagsList.Add([PSCustomObject]@{ name = $requested.name; value = $requested.value })
                                    }
                                }

                                if ($CreateTagsList.Count -eq 0 -and $DeleteTagsList.Count -eq 0) {
                                    "[{0}] All specified tags already have the same values on location '{1}'." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Object.Name | Write-Verbose
                                    if ($WhatIf) {
                                        Write-Warning "All specified tags already have the same values on location '$($Object.Name)'. No changes needed. Cannot display API request."
                                        continue
                                    }
                                    else {
                                        $Object.Status = "Warning"
                                        $Object.Details = "All specified tags already have the same values on this location. No changes needed."
                                    }
                                }

                                if ($DeleteTagsList.Count -gt 0) {
                                    $TagsPayloadObj | Add-Member -MemberType NoteProperty -Name "deleteTags" -Value $DeleteTagsList
                                }
                                if ($CreateTagsList.Count -gt 0) {
                                    $TagsPayloadObj | Add-Member -MemberType NoteProperty -Name "createTags" -Value $CreateTagsList
                                }
                            }
                            elseif ($PSCmdlet.ParameterSetName -eq 'RemoveTags') {
                                $DeleteTagsList = [System.Collections.ArrayList]::new()
                                $RemoveTags -split ',' | ForEach-Object {
                                    $tagName = ($_ -split '=')[0].Trim()
                                    $existingTag = $Locationfound.tags | Where-Object { $_.name -eq $tagName }
                                    if ($existingTag) {
                                        [void]$DeleteTagsList.Add([PSCustomObject]@{ name = $existingTag.name; value = $existingTag.value })
                                    }
                                    else {
                                        "[{0}] Tag '{1}' not found on location '{2}', skipping" -f $MyInvocation.InvocationName.ToString().ToUpper(), $tagName, $Locationfound.name | Write-Verbose
                                    }
                                }
                                if ($DeleteTagsList.Count -eq 0) {
                                    "[{0}] None of the specified tags were found on location '{1}'." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Object.Name | Write-Verbose
                                    if ($WhatIf) {
                                        Write-Warning "None of the specified tags were found on location '$($Object.Name)'. Cannot display API request."
                                        continue
                                    }
                                    else {
                                        $Object.Status = "Warning"
                                        $Object.Details = "None of the specified tags were found on this location."
                                    }
                                }
                                if (-not $Object.Status) {
                                $TagsPayloadObj | Add-Member -MemberType NoteProperty -Name "deleteTags" -Value $DeleteTagsList
                                }
                            }
                            else {
                                # RemoveAllTags
                                $ExistingTagsList = $Locationfound.tags
                                if (-not $ExistingTagsList -or ($ExistingTagsList | Measure-Object).Count -eq 0) {
                                    "[{0}] Location '{1}' has no tags to remove." -f $MyInvocation.InvocationName.ToString().ToUpper(), $Object.Name | Write-Verbose
                                    if ($WhatIf) {
                                        Write-Warning "Location '$($Object.Name)' has no tags to remove. Cannot display API request."
                                        continue
                                    }
                                    else {
                                        $Object.Status = "Warning"
                                        $Object.Details = "This location has no tags to remove."
                                    }
                                }
                                if (-not $Object.Status) {
                                $TagsPayloadObj | Add-Member -MemberType NoteProperty -Name "deleteTags" -Value $ExistingTagsList
                                }
                            }

                            if (-not $Object.Status) {
                            # For the -Tags set, split into two calls when there are deletions:
                            # the API rejects a payload that both deletes and creates the same tag name.
                            # Call 1 (if needed): delete old tag values
                            # Call 2: create new tag values
                            if ($PSCmdlet.ParameterSetName -eq 'Tags' -and $TagsPayloadObj.PSObject.Properties['deleteTags']) {
                                $DeleteOnlyPayload = [PSCustomObject]@{
                                    locationId = $Locationfound.id
                                    deleteTags = $TagsPayloadObj.deleteTags
                                } | ConvertTo-Json -Depth 5
                                "[{0}] Step 1: Deleting existing tag values before update for location '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Locationfound.name | Write-Verbose
                                Invoke-HPEGLWebRequest -Uri $TagsUri -method 'PATCH' -body $DeleteOnlyPayload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | Out-Null

                                if ($TagsPayloadObj.PSObject.Properties['createTags']) {
                                    $CreateOnlyPayload = [PSCustomObject]@{
                                        locationId = $Locationfound.id
                                        createTags = $TagsPayloadObj.createTags
                                    } | ConvertTo-Json -Depth 5
                                    "[{0}] Step 2: Creating updated tag values for location '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Locationfound.name | Write-Verbose
                                    $Response = Invoke-HPEGLWebRequest -Uri $TagsUri -method 'PATCH' -body $CreateOnlyPayload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                                }
                            }
                            else {
                                $TagsPayload = $TagsPayloadObj | ConvertTo-Json -Depth 5
                                "[{0}] Updating tags for location '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Locationfound.name | Write-Verbose
                                $Response = Invoke-HPEGLWebRequest -Uri $TagsUri -method 'PATCH' -body $TagsPayload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference
                            }
                            } # end if (-not $Object.Status)
                        }

                        if (-not $WhatIf) {

                            if (-not $Object.Status) {
                                "[{0}] Location '{1}' successfully updated" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($Name ?? $Locationfound.name) | Write-Verbose
                                $Object.Status = "Complete"
                                $Object.Details = "Location successfully modified"
                            }
            
                        }

                    }
                    catch {

                        if (-not $WhatIf) {
                            $Object.Status = "Failed"
                            $Object.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Location cannot be modified!" }
                            $Object.Exception = $Global:HPECOMInvokeReturnData
                        }
                    }
                } 
            }
        }


        if ($ObjectStatusList.Count -gt 0) {

            Return Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "ObjStatus.NSDE"
        }
    }
}

Function Remove-HPEGLLocation {
    <#
    .SYNOPSIS
    Delete a physical location and service shipping address.

    .DESCRIPTION
    This Cmdlet can be used to delete a physical location and its addresses and contacts.

    The cmdlet issues a message at runtime to warn the user of the irreversible impact of this action and asks for a confirmation for the removal of the location.
        
    Any assigned devices will be released. Any associated addresses will no longer be accessible for automated support case creation. All associated contacts will no longer be assigned to any devices assigned to this location.

    .PARAMETER Name 
    Specifies the name of the physical location to be deleted.

    .PARAMETER Force
    Switch parameter that performs the deletion without prompting for confirmation.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Remove-HPEGLLocation -Name "Boston"

    Deletes the Boston physical location and any associated service shipping addresses and contacts after the user has confirmed the removal. Any devices assigned to the Boston location are released.

    .EXAMPLE
    Get-HPEGLLocation -Name "Mougins" | Remove-HPEGLLocation -Force

    Deletes the Mougins physical location and any associated service shipping addresses and contacts without prompting for confirmation.

    .EXAMPLE
    Get-HPEGLLocation | Remove-HPEGLLocation

    Deletes all physical locations and any associated service shipping addresses and contacts with prompting for confirmation.

    .INPUTS
    System.Collections.ArrayList
        List of location(s) from 'Get-HPEGLLocation'.
    System.String, System.String[]
        A single string object or a list of string objects that represent the location's names.

    .OUTPUTS
    System.Collections.ArrayList    
    A custom status object or array of objects containing the following PsCustomObject keys:  
    * Name - name of the location object attempted to be deleted 
    * Status - status of the deletion attempt (Failed for HTTP error return; Complete if the deletion is successful; Warning if no action is needed) 
    * Details - more information about the status 
    * Exception - Information about any exceptions generated during the operation.
    #>

    [CmdletBinding()]
    Param( 

        [Parameter (Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [String]$Name, 

        [Switch]$Force,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose


        $RemoveLocationStatus = [System.Collections.ArrayList]::new()
               
    }

    Process {         

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name      = $Name
            Status    = $Null
            Details   = $Null
            Exception = $Null
                      
        }

        if ($Force) {
            $decision = 0
        }
        else {
            $title = "Remove Location: $Name" 
            $question = @"
Any assigned devices will be released.
Any associated addresses will no longer be accessible for automated support case creation.
All associated contacts will no longer be assigned to any devices assigned to this location.

Are you sure you want to proceed?
"@
            
            # Create choice descriptions with help messages
            $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Confirm deletion of the location '$Name' and release all associated devices, addresses, and contacts."
            $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Cancel the deletion operation. The location '$Name' will remain unchanged."
            
            $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
            $decision = $Host.UI.PromptForChoice($title, $question, $choices, 1)
        }
           

        if ($decision -eq 0) {


            # Check if location exists
            try {
                $Locationfound = Get-HPEGLLocation -Name $Name
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)                
            }


            if ( -not $Locationfound) {
    
                # Must return a message if resource not found
                "[{0}] Location '{1}' cannot be found in the workspace!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                if ($WhatIf) {
                    $ErrorMessage = "Location '{0}': Resource cannot be found in the workspace!" -f $Name
                    Write-Warning "$ErrorMessage Cannot display API request."
                    return
                }
                else {
                    $objStatus.Status = "Warning"
                    $objStatus.Details = "Location cannot be found in the workspace!"
                }
            
            }
            else {           
                
                $Uri = (Get-DevicesLocationUri) + "/" + $Locationfound.id
                   
                # Delete Location
                try {

                    $Response = Invoke-HPEGLWebRequest -Uri $Uri -method 'DELETE' -body $Payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
                
                    if (-not $WhatIf) {

                        "[{0}] Location '{1}' successfully deleted" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                        $objStatus.Status = "Complete"
                        $objStatus.Details = "Location successfully deleted"
        
                    }

                }
                catch {

                    if (-not $WhatIf) {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Location cannot be deleted!" }
                        $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                    }

                }

            }
        
        }

        else {
                
            'Operation cancelled by user!' | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "Operation cancelled by the user!"
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {    
                $objStatus.Status = "Warning"
                $objStatus.Details = "Operation cancelled by the user!"
            }
        }

        if (-not $WhatIf) {
            [void] $RemoveLocationStatus.add($objStatus)
        }

    }

    end {

        if ($RemoveLocationStatus.Count -gt 0) {

            $RemoveLocationStatus = Invoke-RepackageObjectWithType -RawObject $RemoveLocationStatus -ObjectName "ObjStatus.NSDE" 
            Return $RemoveLocationStatus
        }


    }
}

Function Confirm-HPEGLLocation {
    <#
    .SYNOPSIS
    Validate and reactivate an expired location.

    .DESCRIPTION
    This Cmdlet validates a location that has reached its expiration date (validationExpired = True) and resets the validation cycle. 
    Locations must be periodically validated to ensure accurate information for HPE support case creation and services.
    
    When a location's expiredAt date is reached, the location needs to be revalidated using this cmdlet.

    .PARAMETER Name 
    Specifies the name of the location to validate. Use 'Get-HPEGLLocation' to retrieve available location names.

    .PARAMETER ValidationCycle
    Specifies the validation cycle in months (6, 12, or 18). Default is 12 months.
    This determines when the location will need to be validated again after this confirmation.

    .PARAMETER Force
    Switch parameter that performs the validation without prompting for confirmation. By default, the cmdlet displays the current location details (address and contacts) and asks for confirmation before proceeding.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Confirm-HPEGLLocation -Name "Mougins"
    
    Displays the current address and contact details for the "Mougins" location, prompts for confirmation, then validates the location and resets its validation cycle.

    .EXAMPLE
    Confirm-HPEGLLocation -Name "Mougins" -Force

    Validates the "Mougins" location without prompting for confirmation.

    .EXAMPLE
    Get-HPEGLLocation | Where-Object validationExpired -eq $True | Confirm-HPEGLLocation -Force
    
    Validates all expired locations in the workspace without prompting for confirmation.

    .EXAMPLE
    Get-HPEGLLocation | Confirm-HPEGLLocation -ValidationCycle 18

    Displays location details and prompts for confirmation for each location in the workspace, then validates the confirmed ones and sets their validation cycle to 18 months.

    .INPUTS
    System.String
        Location name from 'Get-HPEGLLocation'.

    .OUTPUTS
    System.Collections.ArrayList    
    A custom status object or array of objects containing the following PsCustomObject keys:  
    * Name - name of the location object attempted to be validated 
    * Status - status of the validation attempt (Failed for HTTP error return; Complete if successful; Warning if location not found) 
    * Details - more information about the status 
    * Exception - information about any exceptions generated during the operation.
    #>

    [CmdletBinding()]
    Param( 
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [String]$Name,

        [ValidateSet('6', '12', '18')]
        [String]$ValidationCycle = "12",

        [Switch]$Force,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $ConfirmLocationStatus = [System.Collections.ArrayList]::new()
               
    }

    Process {         

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
            Name      = $Name
            Status    = $Null
            Details   = $Null
            Exception = $Null
        }
        
        # Pre-validation - Get location with details (use Trim() on name match to handle any trailing space from prior partial runs)
        try {
            "[{0}] Retrieving location '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
            $AllLocations = Get-HPEGLLocation -ShowDetails -ErrorAction Stop
            $Location = $AllLocations | Where-Object { $_.name.Trim() -eq $Name.Trim() }
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        # Validation check
        if (-not $Location) {
            "[{0}] Location '{1}' not found in workspace" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
            
            if ($WhatIf) {
                $ErrorMessage = "Location '{0}' not found in workspace." -f $Name
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }
            else {
                $objStatus.Status = "Warning"
                $objStatus.Details = "Location not found in workspace!"
            }
        }
        else {
            
            "[{0}] Location '{1}' found with ID: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $Location.id | Write-Verbose

            # Build and display location details, then prompt for confirmation (unless -Force or -WhatIf)
            if (-not $Force -and -not $WhatIf) {

                $streetAddr = $Location.addresses | Where-Object type -eq "street"
                $shippingAddr = $Location.addresses | Where-Object type -eq "shipping_receiving"

                # Format street address block
                $streetLines = @()
                if ($streetAddr) {
                    if ($streetAddr.streetAddress) { $streetLines += "  Street  : $($streetAddr.streetAddress)" }
                    if ($streetAddr.streetAddress2) { $streetLines += "          : $($streetAddr.streetAddress2)" }
                    if ($streetAddr.city) { $streetLines += "  City    : $($streetAddr.city)" }
                    if ($streetAddr.state) { $streetLines += "  State   : $($streetAddr.state)" }
                    if ($streetAddr.postalCode) { $streetLines += "  ZIP     : $($streetAddr.postalCode)" }
                    if ($streetAddr.country) { $streetLines += "  Country : $($streetAddr.country)" }
                }

                # Format shipping/receiving address block
                $shippingLines = @()
                if ($shippingAddr) {
                    if ($shippingAddr.streetAddress) { $shippingLines += "  Street  : $($shippingAddr.streetAddress)" }
                    if ($shippingAddr.streetAddress2) { $shippingLines += "          : $($shippingAddr.streetAddress2)" }
                    if ($shippingAddr.city) { $shippingLines += "  City    : $($shippingAddr.city)" }
                    if ($shippingAddr.state) { $shippingLines += "  State   : $($shippingAddr.state)" }
                    if ($shippingAddr.postalCode) { $shippingLines += "  ZIP     : $($shippingAddr.postalCode)" }
                    if ($shippingAddr.country) { $shippingLines += "  Country : $($shippingAddr.country)" }
                }

                # Format contacts block
                $contactLines = @()
                foreach ($contactType in @('primary', 'shipping_receiving', 'security', 'operations')) {
                    $c = $Location.contacts | Where-Object type -eq $contactType
                    if ($c) {
                        $label = switch ($contactType) {
                            'primary' { 'Primary' }
                            'shipping_receiving' { 'Shipping/Receiving' }
                            'security' { 'Security' }
                            'operations' { 'Operations' }
                        }
                        $contactLines += "  $label"
                        if ($c.name) { $contactLines += "    Name  : $($c.name)" }
                        if ($c.email) { $contactLines += "    Email : $($c.email)" }
                        if ($c.phoneNumber) { $contactLines += "    Phone : $($c.phoneNumber)" }
                    }
                }

                # Format tags block
                $tagLines = @()
                if ($Location.tags -and $Location.tags.Count -gt 0) {
                    foreach ($tag in $Location.tags) {
                        $tagLines += "  $($tag.name) = $($tag.value)"
                    }
                }

                # Compose the display message
                $displayParts = [System.Collections.Generic.List[string]]::new()
                $displayParts.Add("")
                if ($Location.description) { $displayParts.Add("Description: $($Location.description)") }
                if ($Location.validationExpired) { $displayParts.Add("STATUS: VALIDATION EXPIRED") }
                if ($Location.expiredAt) { $displayParts.Add("Expired at : $($Location.expiredAt)") }

                if ($streetLines.Count -gt 0) {
                    $displayParts.Add("")
                    $displayParts.Add("Street Address:")
                    $streetLines | ForEach-Object { $displayParts.Add($_) }
                }

                if ($shippingLines.Count -gt 0) {
                    $displayParts.Add("")
                    $displayParts.Add("Shipping/Receiving Address:")
                    $shippingLines | ForEach-Object { $displayParts.Add($_) }
                }

                if ($contactLines.Count -gt 0) {
                    $displayParts.Add("")
                    $displayParts.Add("Contacts:")
                    $contactLines | ForEach-Object { $displayParts.Add($_) }
                }

                if ($tagLines.Count -gt 0) {
                    $displayParts.Add("")
                    $displayParts.Add("Tags:")
                    $tagLines | ForEach-Object { $displayParts.Add($_) }
                }

                $displayParts.Add("")

                $question = ($displayParts -join "`n") + "`nAre the location details above correct? Do you want to confirm the validation?"

                $yes = New-Object System.Management.Automation.Host.ChoiceDescription "&Yes", "Confirm validation of the location '$Name'."
                $no = New-Object System.Management.Automation.Host.ChoiceDescription "&No", "Cancel the validation. The location '$Name' will remain unchanged."

                $choices = [System.Management.Automation.Host.ChoiceDescription[]]($yes, $no)
                $decision = $Host.UI.PromptForChoice("Confirm Location: $Name", $question, $choices, 1)
            }
            else {
                $decision = 0
            }

            if ($decision -eq 1) {

                'Validation cancelled by user!' | Write-Verbose
                $objStatus.Status = "Warning"
                $objStatus.Details = "Operation cancelled by the user!"

            }
            else {
            
                # Use the /update/ endpoint with application/merge-patch+json and locationDetails wrapper
                # (same pattern as Set-HPEGLLocation)
                $Uri = (Get-DevicesLocationUri) + "/update/" + $Location.id
                $LocationType = if ($Location.locationType) { $Location.locationType } elseif ($Location.type) { $Location.type } else { "building" }

                # 2-step approach: the API requires at least one property to change per call, and the name
                # must be part of the change (description-only changes cause a 409 duplicate name conflict).
                #   Step 1: Temp name + set validated=false (name change makes the call accepted)
                #   Step 2: Restore original name + set validated=true + validationCycle (name change back makes this call accepted)
                $OriginalName = $Location.name.Trim()
                $OriginalDescription = $Location.description
                $TempName = $OriginalName + " "
                # Ensure TempName truly differs from the currently stored name (in case it already has a trailing space)
                if ($Location.name -eq $TempName) { $TempName = $OriginalName + "  " }

                try {
                    # Step 1: Set temp name + validated=false
                    $ResetPayload = @{
                        locationDetails = @{
                            name         = $TempName
                            locationType = $LocationType
                            description  = $OriginalDescription
                            validated    = $false
                        }
                    } | ConvertTo-Json -Depth 5

                    "[{0}] Step 1: Resetting validation state for location '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                    Invoke-HPEGLWebRequest -Uri $Uri -method 'PATCH' -body $ResetPayload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | Out-Null

                    # Step 2: Restore original name + set validated=true with new cycle
                    $ValidationPayload = @{
                        locationDetails = @{
                            name            = $OriginalName
                            locationType    = $LocationType
                            description     = $OriginalDescription
                            validated       = $true
                            validationCycle = $ValidationCycle
                        }
                    } | ConvertTo-Json -Depth 5

                    "[{0}] Step 2: Setting validated=true and restoring name for location '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                    $Response = Invoke-HPEGLWebRequest -Uri $Uri -method 'PATCH' -body $ValidationPayload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    
            
                    if (-not $WhatIf) {
                        "[{0}] Location '{1}' successfully validated with {2} month validation cycle" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name, $ValidationCycle | Write-Verbose
                        $objStatus.Status = "Complete"
                        $objStatus.Details = "Location successfully validated with {0} month validation cycle" -f $ValidationCycle
                    }
                }
                catch {
                    if (-not $WhatIf) {
                        $objStatus.Status = "Failed"
                        $objStatus.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Location validation failed!" }
                        $objStatus.Exception = $Global:HPECOMInvokeReturnData
                    }
                }
            } # end inner else (user confirmed)
        } # end else (location found)

        if (-not $WhatIf) {
            [void] $ConfirmLocationStatus.add($objStatus)
        }
    }

    end {
        if ($ConfirmLocationStatus.Count -gt 0) {
            $ConfirmLocationStatus = Invoke-RepackageObjectWithType -RawObject $ConfirmLocationStatus -ObjectName "ObjStatus.NSDE" 
            Return $ConfirmLocationStatus
        }
    }
}

Function Set-HPEGLDeviceLocation {
    <#
    .SYNOPSIS
    Assign device(s) to a physical location.

    .DESCRIPTION
    This Cmdlet assigns device(s) to an HPE GreenLake physical location. This action enables automated HPE support case creation and services.    

    For HPE OneView servers, use 'Set-HPECOMOneViewServerLocation'.

    .PARAMETER DeviceSerialNumber 
    Serial number of the device to be assigned to the location. This value can be retrieved from 'Get-HPEGLDevice'.

    .PARAMETER LocationName 
    Name of the available physical location to assign. This value can be retrieved from 'Get-HPEGLLocation'.

    .PARAMETER Force
    Forces the assignment to the specified location even if the device is already assigned to a different location.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Set-HPEGLDeviceLocation -LocationName London -DeviceSerialNumber CW12312332
        
    Assigns the device with the serial number 'CW12312332' to the 'London' location.

    .EXAMPLE
    Get-HPEGLDevice -Name CW12312332 | Set-HPEGLDeviceLocation -LocationName 'Houston' 
       
    Assigns the device with the serial number 'CW12312332' to the 'Houston' location.

    .EXAMPLE
    Get-HPEGLdevice | Set-HPEGLDeviceLocation -LocationName Houston

    Assigns all devices returned by 'Get-HPEGLdevice' to the 'Houston' location.
    
    .EXAMPLE
    'CW12312332', 'CW12312333', 'CW12312334' | Set-HPEGLDeviceLocation -LocationName "London"

    Assigns the devices with the provided list of serial numbers to the 'London' location using pipeline input.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -name CW12312334 | Set-HPEGLDeviceLocation -LocationName Boston 

    Assigns the Compute Ops Management server in the central european region with the serial number 'CW12312334' to the 'Boston' location.
        
    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects that represent the device's serial numbers. 
    System.Collections.ArrayList
        List of devices(s) from 'Get-HPEGLDevice' or from 'Get-HPECOMServer'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * SerialNumber - Serial number of the device being assigned to a physical location.
        * Location - Name of the location where the device is being assigned.
        * Status - Status of the assignment attempt (Failed for HTTP error return; Complete if assignment is successful; Warning if no action is needed).
        * Details - More information about the status.
        * Exception - Information about any exceptions generated during the operation.
    #>


    [CmdletBinding()]
    Param( 
 
        [Parameter (Mandatory)]
        [String]$LocationName,

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('serialnumber')]
        [String]$DeviceSerialNumber,

        [Switch]$Force,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-DevicesUIDoorwayUri

        $InputList = [System.Collections.ArrayList]::new()
        $ObjectStatusList = [System.Collections.ArrayList]::new()
        $DevicesList = [System.Collections.ArrayList]::new()

        try {
            
            $Locationfound = Get-HPEGLLocation -Name $LocationName

            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }

        if ( -not $Locationfound) {
                    
            $ErrorMessage = "Location '{0}' cannot be found in the workspace!" -f $LocationName

            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }

            throw $ErrorMessage
        }

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

      
        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            SerialNumber = $DeviceSerialNumber
            Location     = $LocationName                       
            Status       = $Null
            Details      = $Null
            Exception    = $Null
                  
        }
    

        [void]$InputList.Add($objStatus)
        if (-not $WhatIf) {
            [void]$ObjectStatusList.Add($objStatus)
        }


    }

    end {

        try {
            
            $devices = Get-HPEGLdevice 
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }
        
        
        "[{0}] List of devices where to set a location: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InputList.serialnumber | out-string) | Write-Verbose

        foreach ($Object in $InputList) {

            $Device = $Devices | Where-Object serialNumber -eq $Object.SerialNumber

            if ( -not $Device) {

                # Must return a message if device not found
                $ErrorMessage = "Device '{0}' cannot be found in the HPE GreenLake workspace!" -f $Object.SerialNumber
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }

                $Object.Status = "Warning"
                $Object.Details = "Device cannot be found in the HPE GreenLake workspace!" 

            } 
            elseif ($device.location.name -and -not $Force) {

                # Must return a message if device is already assigned to location and removed from the list of devices to be set
                $ErrorMessage = "Device '{0}' is already assigned to the '{1}' location!" -f $Object.SerialNumber, $device.location.name
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }

                $Object.Status = "Warning"
                $Object.Details = "Device is already assigned to the '$($device.location.name)' location!"
                
            }
            else {

                if ($device.location.name -and $Force) {
                    # Removing first the location assignement
                    try {
                        Remove-HPEGLDeviceLocation -DeviceSerialNumber $Object.SerialNumber -WhatIf:$WhatIf | Out-Null
                    }
                    catch {
                        $PSCmdlet.ThrowTerminatingError($_)
                    }   
                }

                # Build DeviceList object
                
                $DeviceList = [PSCustomObject]@{
                    serial_number = $Device.serialNumber
                    part_number   = $Device.partNumber 
                    device_type   = $Device.deviceType
                    location_id   = $Locationfound.id
                }

                
                # Building the list of devices object where to add tags
                [void]$DevicesList.Add($DeviceList)
                    
            }
        }

        if ($DevicesList) {

            # Build payload
            $payload = [PSCustomObject]@{
                devices = $DevicesList

            } | ConvertTo-Json -Depth 5

                                
            # Assign Devices to location  
            try {

                Invoke-HPEGLWebRequest -Uri $Uri -method 'PATCH' -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | out-Null
                
                if (-not $WhatIf) {
                    
                    foreach ($Object in $ObjectStatusList) {

                        $DeviceSet = $DevicesList | Where-Object serial_Number -eq $Object.SerialNumber

                        If ($DeviceSet) {
                              
                            $Object.Status = "Complete"
                            $Object.Details = "Location successfully assigned to device"

                        }
                    }

                }
            }
            catch {
                
                if (-not $WhatIf) {

                    foreach ($Object in $ObjectStatusList) {

                        $DeviceSet = $DevicesList | Where-Object serial_Number -eq $Object.SerialNumber

                        If ($DeviceSet) {
                              
                            $Object.Status = "Failed"
                            $Object.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Location cannot be assigned to device!" }
                            $Object.Exception = $Global:HPECOMInvokeReturnData

                        }
                    }
                }
            }
        }

        if ($ObjectStatusList.Count -gt 0) {

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "Location.SLSDE" 
            Return $ObjectStatusList
        }


    }
}

Function Remove-HPEGLDeviceLocation {
    <#
    .SYNOPSIS
    Remove device(s) from a physical location. 

    .DESCRIPTION
    This Cmdlet unassigns device(s) from an HPE GreenLake physical location.  

    For HPE OneView servers, use 'Remove-HPECOMOneViewServerLocation'.
        
    .PARAMETER DeviceSerialNumber 
    Serial number of the device to be unassigned from a physical location. 

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.
   
    .EXAMPLE
    Remove-HPEGLDeviceLocation -DeviceSerialNumber CZ12312311
    
    Unassign the device with the serial number 'CZ12312311' from its physical location.

    .EXAMPLE
    Get-HPEGLDevice -Name CZ12312311 | Remove-HPEGLDeviceLocation 

    Unassign the device with the serial number 'CZ12312311' from its physical location.

    .EXAMPLE
    'CW12312332', 'CW12312333' | Remove-HPEGLDeviceLocation 

    Unassign the devices with the serial numbers listed as a pipeline input from their physical location.

    .EXAMPLE
    Get-HPEGLDevice -FilterByDeviceType SERVER -SearchString "Gen11" | Remove-HPEGLDeviceLocation

    Unassign all 'Gen11' server devices from their physical location.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -name CW12312334 | Remove-HPEGLDeviceLocation

    Unassign the Compute Ops Management server in the central european region with the serial number 'CW12312334' from its physical location.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects that represent the device's serial numbers. 
    System.Collections.ArrayList
        List of devices(s) from 'Get-HPEGLDevice' or 'Get-HPECOMServer'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * SerialNumber - Serial number of the device to be unassigned from a physical location. 
        * Status - Status of the unassignment attempt (Failed for http error return; Complete if unassignment is successful; Warning if no action is needed) 
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.
    
   #>

    [CmdletBinding()]
    Param( 
 
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('serialnumber')]
        [String]$DeviceSerialNumber,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-DevicesUIDoorwayUri

        $InputList = [System.Collections.ArrayList]::new()
        $ObjectStatusList = [System.Collections.ArrayList]::new()
        $DevicesList = [System.Collections.ArrayList]::new()


    }

    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            SerialNumber = $DeviceSerialNumber
            Status       = $Null
            Details      = $Null
            Exception    = $Null
                  
        }
        [void]$InputList.Add($objStatus)
        if (-not $WhatIf) {
            [void]$ObjectStatusList.Add($objStatus)
        }


    }

    end {

        try {
            
            $devices = Get-HPEGLdevice 
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }
        
        
        "[{0}] List of devices where to remove the location: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InputList.serialnumber | out-string) | Write-Verbose

        foreach ($Object in $InputList) {

            $Device = $Devices | Where-Object serialNumber -eq $Object.SerialNumber

            if ( -not $Device) {

                # Must return a message if device not found
                $ErrorMessage = "Device '{0}': Resource cannot be found in the workspace!" -f $Object.SerialNumber
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }

                $Object.Status = "Warning"
                $Object.Details = "Device cannot be found in the workspace!" 

            } 
            elseif (-not $device.location.name) {

                # Must return a message if device is not assigned to a location
                $ErrorMessage = "Device '{0}': Resource is not assigned to a location!" -f $Object.SerialNumber
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }

                $Object.Status = "Warning"
                $Object.Details = "Device is not assigned to a location!"

            }
            else {         

                # Build DeviceList object
                
                $DeviceList = [PSCustomObject]@{
                    serial_number = $Device.serialNumber
                    part_number   = $Device.partNumber 
                    device_type   = $Device.deviceType
                    location_id   = ""
                }


                # Building the list of devices object where to remove location
                [void]$DevicesList.Add($DeviceList)
                    
            }
        }

        if ($DevicesList) {

            # Build payload
            $payload = [PSCustomObject]@{
                devices = $DevicesList

            } | ConvertTo-Json -Depth 5

                                
            # Unassign devices from location  
            try {

                Invoke-HPEGLWebRequest -Uri $Uri -method 'PATCH' -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | out-Null
                
                if (-not $WhatIf) {
                    
                    foreach ($Object in $ObjectStatusList) {

                        $DeviceSet = $DevicesList | Where-Object serial_Number -eq $Object.SerialNumber

                        If ($DeviceSet) {
                              
                            $Object.Status = "Complete"
                            $Object.Details = "Location successfully unassigned from device"

                        }
                    }
                }
            }
            catch {
                
                if (-not $WhatIf) {

                    foreach ($Object in $ObjectStatusList) {

                        $DeviceSet = $DevicesList | Where-Object serial_Number -eq $Object.SerialNumber

                        If ($DeviceSet) {
                              
                            $Object.Status = "Failed"
                            $Object.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Location cannot be unassigned from device!" }
                            $Object.Exception = $Global:HPECOMInvokeReturnData

                        }
                    }
                }
            }
        }

        if ($ObjectStatusList.Count -gt 0) {

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "ObjStatus.SSDE"   
            Return $ObjectStatusList
        }


    }
}

Function Set-HPEGLDeviceServiceDeliveryContact {
    <#
    .SYNOPSIS
    Assign device(s) to a service delivery contact.

    .DESCRIPTION
    This cmdlet allows users to set or update a service delivery contact for an HPE GreenLake device. The Service Delivery Contact will receive all support and service communications for the selected devices.
    
    .PARAMETER DeviceSerialNumber
    Serial number of the device to be assigned to the service delivery contact. This value can be retrieved from 'Get-HPEGLDevice'.

    .PARAMETER Email
    The email address of the service delivery contact. This value is required and must correspond to a valid user email in the workspace.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.

    .EXAMPLE
    Set-HPEGLDeviceServiceDeliveryContact -DeviceSerialNumber CW12312332 -Email email@domain.com

    Assigns the device with the serial number 'CW12312332' to the service delivery contact with the email address 'email@domain.com'.

    .EXAMPLE
    Get-HPEGLDevice -Name CW12312332 | Set-HPEGLDeviceServiceDeliveryContact -Email email@domain.com

    Assigns the device with the serial number 'CW12312332' to the service delivery contact with the email address 'email@domain.com'.

    .EXAMPLE
    Get-HPEGLdevice | Set-HPEGLDeviceServiceDeliveryContact -Email email@domain.com

    Assigns all devices returned by 'Get-HPEGLdevice' to the service delivery contact with the email address 'email@domain.com'.

    .EXAMPLE
    'CW12312332', 'CW12312333', 'CW12312334' | Set-HPEGLDeviceServiceDeliveryContact -Email email@domain.com

    Assigns the devices with the provided list of serial numbers to the service delivery contact with the email address 'email@domain.com' using pipeline input.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -name CW12312334 | Set-HPEGLDeviceServiceDeliveryContact -Email email@domain.com

    Assigns the Compute Ops Management server in the central european region with the serial number 'CW12312334' to the service delivery contact with the email address 'email@domain.com'.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects that represent the device's serial numbers. 
    System.Collections.ArrayList
        List of devices(s) from 'Get-HPEGLDevice' or from 'Get-HPECOMServer'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * SerialNumber - Serial number of the device being assigned to the service delivery contact.
        * Email - Email address of the service delivery contact.
        * Status - Status of the assignment attempt (Failed for HTTP error return; Complete if assignment is successful; Warning if no action is needed).
        * Details - More information about the status.
        * Exception - Information about any exceptions generated during the operation.
    #>


    [CmdletBinding()]
    Param( 
 
        [Parameter (Mandatory)]
        [String]$Email,

        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('serialnumber')]
        [String]$DeviceSerialNumber,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-DevicesUIDoorwayUri

        $InputList = [System.Collections.ArrayList]::new()
        $ObjectStatusList = [System.Collections.ArrayList]::new()
        $DevicesList = [System.Collections.ArrayList]::new()

        try {
            
            $Emailfound = Get-HPEGLUser -Email $Email

        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
        }

        if ( -not $Emailfound) {

            $ErrorMessage = "Email '{0}' cannot be found in the workspace!" -f $Email
            "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

            if ($WhatIf) {
                Write-Warning "$ErrorMessage Cannot display API request."
                return
            }

            throw $ErrorMessage
        }

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

      
        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            SerialNumber = $DeviceSerialNumber
            Email        = $Email                       
            Status       = $Null
            Details      = $Null
            Exception    = $Null
                  
        }
    

        [void]$InputList.Add($objStatus)
        if (-not $WhatIf) {
            [void]$ObjectStatusList.Add($objStatus)
        }


    }

    end {

        try {
            
            $devices = Get-HPEGLdevice 
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }
        
        
        "[{0}] List of devices where to set the service delivery contact: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InputList.serialnumber | out-string) | Write-Verbose

        foreach ($Object in $InputList) {

            $Device = $Devices | Where-Object serialNumber -eq $Object.SerialNumber

            if ( -not $Device) {

                # Must return a message if device not found
                $ErrorMessage = "Device '{0}' cannot be found in the HPE GreenLake workspace!" -f $Object.SerialNumber
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }

                $Object.Status = "Warning"
                $Object.Details = "Device cannot be found in the HPE GreenLake workspace!" 

            } 
            elseif ($device.serviceDelivery.email -eq $Email) {

                # Must return a message if device already set with the same contact
                $ErrorMessage = "Device '{0}' is already assigned to the service delivery contact '{1}'!" -f $Object.SerialNumber, $device.serviceDelivery.email
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }

                $Object.Status = "Warning"
                $Object.Details = "Device is already assigned to the service delivery contact '{0}'! No changes made." -f $device.serviceDelivery.email

            }
            else {         

                if ($device.serviceDelivery.email) {
                    # Must return a message if device is already assigned to contact and will be updated
                    "Device is currently assigned to the service delivery contact '{0}' and will be updated to the new contact '{1}'." -f $device.serviceDelivery.email, $Email | Write-Verbose
                }

                # Build DeviceList object
                
                $DeviceList = [PSCustomObject]@{
                    serial_number = $Device.serialNumber
                    part_number   = $Device.partNumber 
                    device_type   = $Device.deviceType
                    contact_id    = $email
                    contact_name  = $Emailfound.firstname + " " + $Emailfound.lastname
                    contact_type  = "GLP"
                }

                
                # Building the list of devices object 
                [void]$DevicesList.Add($DeviceList)
                    
            }
        }

        if ($DevicesList) {

            # Build payload
            $payload = [PSCustomObject]@{
                devices = $DevicesList

            } | ConvertTo-Json -Depth 5

                                
            # Assign Devices to contact  
            try {

                Invoke-HPEGLWebRequest -Uri $Uri -method 'PATCH' -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | out-Null
                
                if (-not $WhatIf) {
                    
                    foreach ($Object in $ObjectStatusList) {

                        $DeviceSet = $DevicesList | Where-Object serial_Number -eq $Object.SerialNumber

                        If ($DeviceSet) {
                              
                            $Object.Status = "Complete"
                            $Object.Details = "Service delivery contact successfully assigned to device"

                        }
                    }

                }
            }
            catch {
                
                if (-not $WhatIf) {

                    foreach ($Object in $ObjectStatusList) {

                        $DeviceSet = $DevicesList | Where-Object serial_Number -eq $Object.SerialNumber

                        If ($DeviceSet) {
                              
                            $Object.Status = "Failed"
                            $Object.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Service delivery contact cannot be assigned to device!" }
                            $Object.Exception = $Global:HPECOMInvokeReturnData

                        }
                    }
                }
            }
        }

        if ($ObjectStatusList.Count -gt 0) {

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "ObjStatus.SESDE" 
            Return $ObjectStatusList
        }


    }
}

Function Remove-HPEGLDeviceServiceDeliveryContact {
    <#
    .SYNOPSIS
    Unassign device(s) from a service delivery contact. 

    .DESCRIPTION
    This Cmdlet unassigns device(s) from an HPE GreenLake service delivery contact.  

    .PARAMETER DeviceSerialNumber
    Serial number of the device to be unassigned from a service delivery contact.

    .PARAMETER WhatIf
    Shows the raw REST API call that would be made to GLP instead of sending the request. This option is useful for understanding the inner workings of the native REST API calls used by GLP.
   
    .EXAMPLE
    Remove-HPEGLDeviceServiceDeliveryContact -DeviceSerialNumber CZ12312311

    Unassign the device with the serial number 'CZ12312311' from its service delivery contact.

    .EXAMPLE
    Get-HPEGLDevice -Name CZ12312311 | Remove-HPEGLDeviceServiceDeliveryContact

    Unassign the device with the serial number 'CZ12312311' from its service delivery contact.

    .EXAMPLE
    'CW12312332', 'CW12312333' | Remove-HPEGLDeviceServiceDeliveryContact

    Unassign the devices with the serial numbers listed as a pipeline input from their service delivery contact.

    .EXAMPLE
    Get-HPEGLDevice -FilterByDeviceType SERVER -SearchString "Gen11" | Remove-HPEGLDeviceServiceDeliveryContact

    Unassign all 'Gen11' server devices from their service delivery contact.

    .EXAMPLE
    Get-HPECOMServer -Region eu-central -name CW12312334 | Remove-HPEGLDeviceServiceDeliveryContact

    Unassign the Compute Ops Management server in the central european region with the serial number 'CW12312334' from its service delivery contact.

    .INPUTS
    System.String, System.String[]
        A single string object or a list of string objects that represent the device's serial numbers. 
    System.Collections.ArrayList
        List of devices(s) from 'Get-HPEGLDevice' or 'Get-HPECOMServer'.

    .OUTPUTS
    System.Collections.ArrayList
        A custom status object or array of objects containing the following PsCustomObject keys:  
        * SerialNumber - Serial number of the device being unassigned from its service delivery contact.
        * Status - Status of the unassignment attempt (Failed for http error return; Complete if unassignment is successful; Warning if no action is needed) 
        * Details - More information about the status 
        * Exception: Information about any exceptions generated during the operation.
    
   #>

    [CmdletBinding()]
    Param( 
 
        [Parameter (Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('serialnumber')]
        [String]$DeviceSerialNumber,

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $Uri = Get-DevicesUIDoorwayUri

        $InputList = [System.Collections.ArrayList]::new()
        $ObjectStatusList = [System.Collections.ArrayList]::new()
        $DevicesList = [System.Collections.ArrayList]::new()


    }

    Process {
        
        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose

        # Build object for the output
        $objStatus = [pscustomobject]@{
  
            SerialNumber = $DeviceSerialNumber
            Status       = $Null
            Details      = $Null
            Exception    = $Null
                  
        }
    
        [void]$InputList.Add($objStatus)
        if (-not $WhatIf) {
            [void]$ObjectStatusList.Add($objStatus)
        }


    }

    end {

        try {
            
            $devices = Get-HPEGLdevice 
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }
        
        
        "[{0}] List of devices where to remove the service delivery contact: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($InputList.serialnumber | out-string) | Write-Verbose

        foreach ($Object in $InputList) {

            $Device = $Devices | Where-Object serialNumber -eq $Object.SerialNumber

            if ( -not $Device) {

                # Must return a message if device not found
                $ErrorMessage = "Device '{0}': Resource cannot be found in the workspace!" -f $Object.SerialNumber
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }

                $Object.Status = "Warning"
                $Object.Details = "Device cannot be found in the workspace!" 

            } 
            elseif (-not $device.serviceDelivery.email -and -not $device.serviceDelivery.name) {

                # Must return a message if device is not assigned to a service delivery contact
                $ErrorMessage = "Device '{0}': Resource is not assigned to a service delivery contact!" -f $Object.SerialNumber
                "[{0}] {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ErrorMessage | Write-Verbose

                if ($WhatIf) {
                    Write-Warning "$ErrorMessage Cannot display API request."
                    continue
                }

                $Object.Status = "Warning"
                $Object.Details = "Device is not assigned to a service delivery contact!"

            }
            else {         

                # Build DeviceList object
                
                $DeviceList = [PSCustomObject]@{
                    serial_number = $Device.serialNumber
                    part_number   = $Device.partNumber 
                    device_type   = $Device.deviceType
                    contact_id    = ""
                    contact_name  = ""
                }
                
                # Building the list of devices object 
                [void]$DevicesList.Add($DeviceList)
                    
            }
        }

        if ($DevicesList) {

            # Build payload
            $payload = [PSCustomObject]@{
                devices = $DevicesList

            } | ConvertTo-Json -Depth 5

                                
            # Unassign devices from service delivery contact
            try {

                Invoke-HPEGLWebRequest -Uri $Uri -method 'PATCH' -body $payload -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference | out-Null
                
                if (-not $WhatIf) {
                    
                    foreach ($Object in $ObjectStatusList) {

                        $DeviceSet = $DevicesList | Where-Object serial_Number -eq $Object.SerialNumber

                        If ($DeviceSet) {
                              
                            $Object.Status = "Complete"
                            $Object.Details = "Service delivery contact successfully unassigned from device"

                        }
                    }
                }
            }
            catch {
                
                if (-not $WhatIf) {

                    foreach ($Object in $ObjectStatusList) {

                        $DeviceSet = $DevicesList | Where-Object serial_Number -eq $Object.SerialNumber

                        If ($DeviceSet) {
                              
                            $Object.Status = "Failed"
                            $Object.Details = if ($_.Exception.Message) { $_.Exception.Message } else { "Service delivery contact cannot be unassigned from device!" }
                            $Object.Exception = $Global:HPECOMInvokeReturnData

                        }
                    }
                }
            }
        }

        if ($ObjectStatusList.Count -gt 0) {

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "ObjStatus.SSDE"   
            Return $ObjectStatusList
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
    'Get-HPEGLDevice', 'Add-HPEGLDeviceCompute', 'Connect-HPEGLDeviceComputeiLOtoCOM', 'Add-HPEGLDeviceStorage', 'Add-HPEGLDeviceNetwork', `
    'Disable-HPEGLDevice', 'Enable-HPEGLDevice', 'Add-HPEGLDeviceTagToDevice', 'Remove-HPEGLDeviceTagFromDevice', `
    'Get-HPEGLLocation', 'New-HPEGLLocation', 'Set-HPEGLLocation', 'Remove-HPEGLLocation', 'Confirm-HPEGLLocation', `
    'Set-HPEGLDeviceLocation', 'Remove-HPEGLDeviceLocation', `
    'Set-HPEGLDeviceServiceDeliveryContact', 'Remove-HPEGLDeviceServiceDeliveryContact' `
    -Alias *


# SIG # Begin signature block
# MIIungYJKoZIhvcNAQcCoIIujzCCLosCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCA6R39tPUlDTBdK
# 0e3TSXctOO80d7E6cxDnqzQOyCK9CaCCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQg3E+lqrrgGj3A3qdLiR+VOOiKULdVp8I86wWP9PgMmf0wDQYJKoZIhvcNAQEB
# BQAEggIAcGsN6fOQ8R+CMQfT3lED+CS0lQBK7GT4sKQylVdCrr/lnqs9ZayGt9HJ
# yPh4VLcDBXWQx7n5wKKX5/xQedSeqpn8Dawpxq9Mk9Cm1hK2hWknYFM10ZZrDMPz
# RXhQsP4Yw59+qwGCFG0yfa0AVvqGsih19AKDb+ARiLC7Skg5nTDNUx2M33VzX2WI
# KX8YJOL8llY/trAtD1uhkF0z7NiSvePvLplAmARSxHveed+PQFLi1FZtEjSxVUuR
# J3dFVmaSLUPppaXyAuxsKY3fT79DlHoBIsLserVSPBI9JkDy0zbaPAzteFGzlrZC
# 8pBp3XkFMKRadVF93ytE+S9DT5oVLoMK4SsDqgrK673JbZmDEnywwUVjPrVBhw8H
# 2NLV+4Blsjt6fP7vuweIc0WVzC0w59AFDRYOV+6SiTE61e6KMgLOn1746o0sOnCu
# M/+tEmFs6Oi3ChmzBfGQC62DKTgBrl7vOhe2YcPFJ2Ii5hcqT5nwp762yj/Sn18N
# US/rFVqPfm4C65DWkhHmv3Fd4VGhJ1sPegOUqE8HBZpPSJzaapm9sVIJJU+OILFU
# QMKEAmGCvTIR9IAqXG9LJ2jLG6JEzWT4dYDg2KoDOlMdsy5ICj11rSnzgbhcXdzt
# Ra01rGECI3qQBh3tOqSTVPoYxWyZyQMIMmMGKNfdyshdRnzGW1ShghjoMIIY5AYK
# KwYBBAGCNwMDATGCGNQwghjQBgkqhkiG9w0BBwKgghjBMIIYvQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIIBBwYLKoZIhvcNAQkQAQSggfcEgfQwgfECAQEGCisGAQQBsjEC
# AQEwQTANBglghkgBZQMEAgIFAAQw0zMPjpl322pM82d5YUd1k1JuFXKNeHKcLK3a
# ++BtJCVePhMqZ+SPylAnM4sHc+h6AhRSo5q1LI8NmXFVRLCC+OXgnNwbMxgPMjAy
# NjAzMTcxNDMzNTJaoHakdDByMQswCQYDVQQGEwJHQjEXMBUGA1UECBMOV2VzdCBZ
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
# DxcNMjYwMzE3MTQzMzUyWjA/BgkqhkiG9w0BCQQxMgQwgU4zD81Vhplm4hsXElkR
# n1aC6hI806mDyr0IazlqLqAg6yPYIJgO53Cdc4ToW3IqMIIBegYLKoZIhvcNAQkQ
# AgwxggFpMIIBZTCCAWEwFgQUOMkUgRBEtNxmPpPUdEuBQYaptbEwgYcEFMauVOR4
# hvF8PVUSSIxpw0p6+cLdMG8wW6RZMFcxCzAJBgNVBAYTAkdCMRgwFgYDVQQKEw9T
# ZWN0aWdvIExpbWl0ZWQxLjAsBgNVBAMTJVNlY3RpZ28gUHVibGljIFRpbWUgU3Rh
# bXBpbmcgUm9vdCBSNDYCEHojrtpTaZYPkcg+XPTH4z8wgbwEFIU9Yy2TgoJhfNCQ
# NcSR3pLBQtrHMIGjMIGOpIGLMIGIMQswCQYDVQQGEwJVUzETMBEGA1UECBMKTmV3
# IEplcnNleTEUMBIGA1UEBxMLSmVyc2V5IENpdHkxHjAcBgNVBAoTFVRoZSBVU0VS
# VFJVU1QgTmV0d29yazEuMCwGA1UEAxMlVVNFUlRydXN0IFJTQSBDZXJ0aWZpY2F0
# aW9uIEF1dGhvcml0eQIQNsKwvXwbOuejs902y8l1aDANBgkqhkiG9w0BAQEFAASC
# AgDP1WzSe3BckX+6008DMzxRwWlC6meKqbvFBzC+ACBpDewAZ/GmzXGj75FTJXvN
# aTQ1KnnWYw8urowj0hwEjaL368koVuHuSyzv5oPC6PuzCmdRQIUGJ5EGyGjMNNwI
# sMVkJPd/ZKuk+t9Y1ZQYunnqZ7LLgBkPWioPPI88Ilvm+3xKGyazziY7SRd85VBP
# 7tteqHKYsux+95xOre+RXGWKUNcplJk4litINcdW3so8L37K9qqYRSpXLwjRDeNj
# dYK02aPpXijaaKHBTF34kKVsr2kCNUqGnK+aCced9n+tzht1zOaBYUpWRX7QN0nf
# yLuwah+XlCkU82XgzyiX9iPeDB7ge8qDKduKiGyWJ3hM8dvtVY9zbWq0U6D9duxe
# 2zkji+4UrrPLiJaMnDn8OlfOhVChEXVmzAfLO06fqIkWn1WAFukCqX7YN8tJCE9M
# 4BP1G+eDVHxvPmjHXM882LcWcoy1zugBwwRtvZQk6MbZr+J65BxrpdpPQdZ452kd
# dCPmQE39hIg2DeD7ymF6qC359AvLHOxyipNlySKV7AJuTKHVwgJvaWUZHTOmO9S8
# 3tqMytnMG4FyzfvK+RqlVgBqA+ZyfU7x4xZPBe2MRcVMFIQl1eWSa2DyoE+GTPTd
# 3zTKgqP1C4+B65WFXzOknr+70VPf4bBkGN6jROvyGJr2oA==
# SIG # End signature block
