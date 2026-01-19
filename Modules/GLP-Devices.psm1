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

    #>

    [CmdletBinding(DefaultParameterSetName = 'NotArchived')]
    Param( 

        [Parameter (ParameterSetName = 'Archived', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Parameter (ParameterSetName = 'NotArchived', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [ValidateNotNullOrEmpty()]
        [Alias ('SerialNumber')]
        [String]$Name, 
        
        # [Parameter (ParameterSetName = 'Archived', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        # [Parameter (ParameterSetName = 'NotArchived', ValueFromPipeline, ValueFromPipelineByPropertyName)]
        # [ValidateNotNullOrEmpty()]
        # [String]$SerialNumber,  

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
    
        # $SerialNumbersList = [System.Collections.ArrayList]::new()

    }

    Process {

        "[{0}] Bound PS Parameters: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($PSBoundParameters | out-string) | Write-Verbose


        # Set URI
        if ($Name) {       

            # $Uri = (Get-COMServersUri) + "?filter=name eq '$Name'"   # Filter that supports only serial numbers
            # $DevicesUri = Get-DevicesUri
            $Uri = (Get-DevicesUri) + "?filter=(secondaryName eq '$Name' or deviceName eq '$Name' or serialNumber eq '$Name')"   # Filter that supports both serial numbers and server names
            # Added the parentheses to fix issue when other filters are added with and
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
           
        $ReturnData = @()       

        if ($Null -ne $AllCollection) {     

            $CollectionList = $AllCollection 

            write-Verbose ("[{0}] Enriching device data with additional properties..." -f $MyInvocation.InvocationName.ToString().ToUpper())

            # Add serverName to object
            $CollectionList | ForEach-Object { 
                if ($_.secondaryName) {
                    $_ | Add-Member -Type NoteProperty -Name serverName -Value $_.secondaryName -Force
                }
                else {
                    $_ | Add-Member -Type NoteProperty -Name serverName -Value $_.serialNumber -Force
                }
            }

            # Add iLOName to object
            $CollectionList | ForEach-Object { 
                if ($_.deviceName) {
                    $_ | Add-Member -Type NoteProperty -Name iLOName -Value $_.deviceName -Force
                }
            }

            
            # Add location details to object
            $CollectionList | ForEach-Object {
                $ServerID = $_.id
                if ($ServerID) {
                    $MatchedServerID = $AllCollectionUIDoorWay | Where-Object { $_.resource_id -eq $ServerID }
                    if ($MatchedServerID -and $MatchedServerID.location_name) {
                        if (-not $_.PSObject.Properties.Match('location') -or $null -eq $_.location) {
                            $_ | Add-Member -Type NoteProperty -Name location -Value ([PSCustomObject]@{}) -Force
                        }
                        if ($null -ne $_.location) {
                            $_.location | Add-Member -Type NoteProperty -Name name -Value $MatchedServerID.location_name -Force
                            $_.location | Add-Member -Type NoteProperty -Name streetAddress -Value $MatchedServerID.streetAddress -Force
                            $_.location | Add-Member -Type NoteProperty -Name country -Value $MatchedServerID.country -Force
                            $_.location | Add-Member -Type NoteProperty -Name city -Value $MatchedServerID.city -Force
                            $_.location | Add-Member -Type NoteProperty -Name postalCode -Value $MatchedServerID.postalCode -Force
                            $_.location | Add-Member -Type NoteProperty -Name state -Value $MatchedServerID.state -Force
                        }
                    }
                }
            }

            # Add application details to object
            $CollectionList | ForEach-Object {
                $ServerID = $_.id
                if ($ServerID) {
                    $MatchedServerID = $AllCollectionUIDoorWay | Where-Object { $_.resource_id -eq $ServerID }
                    if ($MatchedServerID -and $MatchedServerID.application_name) {
                        if (-not $_.PSObject.Properties.Match('application') -or $null -eq $_.application) {
                            $_ | Add-Member -Type NoteProperty -Name application -Value ([PSCustomObject]@{}) -Force
                        }
                        if ($null -ne $_.application) {
                            $_.application | Add-Member -Type NoteProperty -Name name -Value $MatchedServerID.application_name -Force
                            $_.application | Add-Member -Type NoteProperty -Name region -Value $_.region -Force
                        }
                    }
                }
            }


            # Add warranty details to object
            $CollectionList | ForEach-Object {
                $ServerID = $_.id
                if ($ServerID) {
                    $MatchedServerID = $AllCollectionUIDoorWay | Where-Object { $_.resource_id -eq $ServerID }
                    if ($MatchedServerID -and $MatchedServerID.support_state) {
                        if (-not $_.PSObject.Properties.Match('warranty') -or $null -eq $_.warranty) {
                            $_ | Add-Member -Type NoteProperty -Name warranty -Value ([PSCustomObject]@{}) -Force
                        }
                        if ($null -ne $_.warranty) {
                            if ($MatchedServerID.support_level) {
                                $_.warranty | Add-Member -Type NoteProperty -Name supportLevel -Value $MatchedServerID.support_level -Force
                            }
                            if ($MatchedServerID.support_state) {
                                $_.warranty | Add-Member -Type NoteProperty -Name supportState -Value $MatchedServerID.support_state -Force
                            }
                            if ($MatchedServerID.support_end_date) {
                                # Convert milliseconds since epoch to DateTime
                                $endTime = [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$MatchedServerID.support_end_date).DateTime
                                $_.warranty | Add-Member -Type NoteProperty -Name endTime -Value $endTime -Force
                            }
                            else {
                                $_.warranty | Add-Member -Type NoteProperty -Name endTime -Value $MatchedServerID.support_end_date -Force
                            }
                        }
                    }
                }
            }
                    
            # Add subscription details to object
            $CollectionList | ForEach-Object {
                $ServerID = $_.id
                if ($ServerID) {
                    $MatchedServerID = $AllCollectionUIDoorWay | Where-Object { $_.resource_id -eq $ServerID }
                    if ($MatchedServerID -and $MatchedServerID.subscriptions -and $MatchedServerID.subscriptions.Count -gt 0) {
                        if (-not $_.PSObject.Properties.Match('subscription') -or $null -eq $_.subscription) {
                            $_ | Add-Member -Type NoteProperty -Name subscription -Value ([PSCustomObject]@{}) -Force
                        }
                        if ($null -ne $_.subscription) {
                            $_.subscription | Add-Member -Type NoteProperty -Name key -Value $MatchedServerID.subscriptions[0].key -Force
                            $_.subscription | Add-Member -Type NoteProperty -Name tier -Value $MatchedServerID.subscriptions[0].tier -Force
                            if ($MatchedServerID.subscriptions[0].end_date) {
                                # Convert milliseconds since epoch to DateTime
                                $endTime = [DateTimeOffset]::FromUnixTimeMilliseconds([int64]$MatchedServerID.subscriptions[0].end_date).DateTime
                                $_.subscription | Add-Member -Type NoteProperty -Name endTime -Value $endTime -Force
                            }
                            else {
                                $_.subscription | Add-Member -Type NoteProperty -Name endTime -Value $MatchedServerID.subscriptions[0].end_date -Force
                            }
                            $_.subscription | Add-Member -Type NoteProperty -Name quantity -Value $MatchedServerID.subscriptions[0].quantity -Force
                            $_.subscription | Add-Member -Type NoteProperty -Name available_quantity -Value $MatchedServerID.subscriptions[0].available_quantity -Force
                        }
                    }
                }
            }


            # Add service delivery contact details to object 
            $CollectionList | ForEach-Object { 
                $_ | Add-Member -Type NoteProperty -Name serviceDelivery -Value $null -Force
            }
            $CollectionList | ForEach-Object {
                $ServerID = $_.id
                if ($ServerID) {
                    $MatchedServerID = $AllCollectionUIDoorWay | Where-Object { $_.resource_id -eq $ServerID }
                    if ($MatchedServerID) {
                        $_.serviceDelivery = [PSCustomObject]@{
                            name  = $MatchedServerID.contact_name
                            email = $MatchedServerID.contact_id
                        }
                    }
                }
            }


            # iLOIPAddress cannot be added to object as not present


            if ($ShowRequireAssignment) {

                # test that application.id is available

                $CollectionList = $CollectionList | Where-Object { $_.assignedState -eq "UNASSIGNED" }

            }   

            if ($ShowRequireSubscription) {

                $CollectionList = $CollectionList | Where-Object { $_.subscription.Count -eq 0 }

            }   

            if ($ShowComputeReadyForCOMIloConnection) {

                $CollectionList = $CollectionList | Where-Object { $_.application.name -eq "Compute Ops Management" -and $_.subscription.id }

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

       
        # Add tracking object to the list of object status list
        [void]$ObjectStatusList.Add($objStatus)

    }

    end {        

        try {
            $Devices = Get-HPEGLdevice 
        
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        
        foreach ($DeviceToAdd in $ObjectStatusList) {
            
            
            $ErrorFoundInTags = $False

            $Device = $Devices | Where-Object serialNumber -eq $DeviceToAdd.SerialNumber
            
            
            if ( $Device) {

                $DeviceToAdd.Status = "Warning"
                $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Device already present in the workspace!" }
                $DeviceToAdd.TagsAdded = $Null
                
                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource already present in the workspace!" -f $DeviceToAdd.SerialNumber
                    Write-warning $ErrorMessage
                    continue
                }
            } 
            else {
                
                if ($DeviceToAdd.TagsAdded) {
                    
                    "[{0}] {1}: Object TagsAdded content: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DeviceToAdd.serialnumber, $DeviceToAdd.TagsAdded | Write-Verbose

                    $splittedtags = $DeviceToAdd.TagsAdded.split(",")

                    if ($splittedtags.Length -gt 25) {
                        
                        $DeviceToAdd.Status = "Failed"
                        $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Too many tags defined ! A maximum of 25 tags per resource is supported!" }
                        $DeviceToAdd.TagsAdded = $Null
                        $ErrorFoundInTags = $True


                        if ($WhatIf) {
                            $ErrorMessage = "Device '{0}': Resource is defined with too many tags! A maximum of 25 tags per resource is supported!" -f $DeviceToAdd.SerialNumber
                            Write-warning $ErrorMessage
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
                            if ($tag -notmatch '^[\p{L}\p{Nd}_ .:+\-@]+\=[\p{L}\p{Nd}_ .:+\-@]+$') {
                                
                                $splittedtagName = $tag.TrimEnd().TrimStart()
    
                                $DeviceToAdd.Status = "Failed"
                                $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Tag format '$splittedtagName' not supported! Expected format is <tagname>=<value>, <tagname>=<value>!" }
                                $DeviceToAdd.TagsAdded = $Null
                                $ErrorFoundInTags = $True
    
                                if ($WhatIf) {
                                    $ErrorMessage = "Device '{0}': Tag '{1}' format not supported! Expected format is <tagname>=<value>, <tagname>=<value>!" -f $DeviceToAdd.SerialNumber, $splittedtagName
                                    Write-warning $ErrorMessage
                                    break
                                }
                            }
                            else {
    
                                $tagname = $tag.split('=')[0]
        
                                # Remove space at the begining and at the end of the string if any
                                $tagname = $tagname.TrimEnd().TrimStart()
        
                                if ($tagname.Length -gt 128) {
        
                                    $DeviceToAdd.Status = "Failed"
                                    $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Tag name '$tagname' is over 128 characters! Tag names can have a maximum of 128 characters!" }
                                    $DeviceToAdd.TagsAdded = $Null
                                    $ErrorFoundInTags = $True
        
                                    if ($WhatIf) {
                                        $ErrorMessage = "Device '{0}': Tag name '{1}' is over 128 characters! Tag names can have a maximum of 128 characters!" -f $DeviceToAdd.SerialNumber, $tagname
                                        Write-warning $ErrorMessage
                                        break
                                    }
                                }
                                else {
                                    
                                    $tagvalue = $tag.split('=')[1]
                                    
                                    # Remove space at the begining and at the end of the string if any
                                    $tagvalue = $tagvalue.TrimEnd().TrimStart()
            
                                    if ($tagvalue.Length -gt 256) {
            
                                        $DeviceToAdd.Status = "Failed"
                                        $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Tag value '$tagvalue' is over 256 characters! Tag values can have a maximum of 256 characters!" }
                                        $DeviceToAdd.TagsAdded = $Null
                                        $ErrorFoundInTags = $True
            
                                        if ($WhatIf) {
                                            $ErrorMessage = "Device '{0}': Tag value '{1}' is over 256 characters! Tag values can have a maximum of 256 characters!" -f $DeviceToAdd.SerialNumber, $tagvalue
                                            Write-warning $ErrorMessage
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
                            $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Device cannot be added to the HPE GreenLake workspace!" }
                            $DeviceToAdd.Exception = $_.Exception.message 

                        }
                    }
                }
            }      
        }
    
        

        if (-not $WhatIf) {

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "Device.Add.SPTSDE"    
            Return $ObjectStatusList
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
    (Optional) Enables iLO web proxy. Specifies the hostname or IP address of the web proxy server.
    
    .PARAMETER IloProxyPort
    (Optional) Specifies the iLO web proxy port number. The range of valid port values in iLO is from 1 to 65535.
    
    .PARAMETER IloProxyUserName
    (Optional) Specifies the iLO web proxy username, if applicable.
    
    .PARAMETER IloProxyPassword
    (Optional) Specifies the iLO web proxy password, if applicable, as a SecureString.

    .PARAMETER DisconnectiLOfromOneView
    If present, this switch parameter disconnects a system managed by HPE OneView in order to connect it to Compute Ops Management. If absent, the connection to Compute Ops Management will fail if the system is already managed by HPE OneView.
    
    .EXAMPLE
    $iLO_credential = Get-Credential 
    Connect-HPEGLDeviceComputeiLOtoCOM -IloIP "192.168.0.21" -IloCredential $iLO_credential -SkipCertificateValidation
    
    Connect the iLO at 192.168.0.21 of compute device "123456789012" to the currently assigned Compute Ops Management instance. Certificate validation checks are skipped.
    
    .EXAMPLE
    Connect-HPEGLDeviceComputeiLOtoCOM -IloIP "192.168.1.151" -IloCredential $iLO_credential -IloProxyServer "web-proxy.domain.com" -IloProxyPort 8080

    Connect the iLO at 192.168.1.151 of compute device "123456789012" to the currently assigned Compute Ops Management instance through a web proxy.

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
    $iLOs =  .\iLOs-List-To-Connect-To-COM.csv -Delimiter ","

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
    $iLOs =  .\iLOs-List-To-Connect-To-COM.csv -Delimiter ","

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
    $iLOs =  .\iLOs-List-To-Connect-To-COM.csv -Delimiter ","

    # Retrieve the name of the first available Compute Ops Management Secure Gateway in the central european region
    $SecureGatewayName = Get-HPECOMAppliance -Region eu-central -Type SecureGateway | select -first 1 -ExpandProperty name
    
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
        [Alias ('IP')]
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

        [Switch]$DisconnectiLOfromOneView
  
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
            $objStatus.Status = "Failed"
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

            "[{0}] {1}: Received status code response: '{2}' - Description: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $response.StatusCode, $InvokeReturnData.StatusDescription | Write-verbose
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
                
                $objStatus.iLOConnectionStatus = "Failed"
                $objStatus.iLOConnectionDetails = "Server cannot be connected to COM using a COM activation key because the iLO firmware version is lower than v3.09. Please run the cmdlet without the 'ActivationKeyfromCOM' parameter."
                
                "[{0}] {1} [{2}] The iLO {3} firmware version {4} is NOT compatible with the COM activation key ! iLO cannot be connected to COM using a COM activation key because the iLO firmware version is lower than v3.09" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $iLOGeneration, $iLOFWVersion | Write-Verbose
                
                $objStatus.Status = "Failed"
                [void]$iLOConnectionStatus.add($objStatus) 
                return

            }
            elseif ($iLOGeneration -eq "iLO 6" -and [decimal]$iLOFWVersion -lt [decimal]1.64) {

                
                $objStatus.iLOConnectionStatus = "Failed"
                $objStatus.iLOConnectionDetails = "Server cannot be connected to COM using a COM activation key because the iLO firmware version is lower than v1.64. Please run the cmdlet without the 'ActivationKeyfromCOM' parameter."

                "[{0}] {1} [{2}] The iLO {3} firmware version {4} is NOT compatible with the COM activation key ! iLO cannot be connected to COM using a COM activation key because the iLO firmware version is lower than v1.64" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $iLOGeneration, $iLOFWVersion | Write-Verbose

                $objStatus.Status = "Failed"
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
                $objStatus.Status = "Failed"
                $objStatus.Details = "Device cannot be found in the HPE GreenLake workspace"
                [void] $iLOConnectionStatus.add($objStatus)
                return
                
            }
            elseif (-not $device.region) {
                # Must return a message if device is not assigned to COM
                $objStatus.Status = "Failed"
                $objStatus.Details = "Device is not assigned to any service instance!"
                [void] $iLOConnectionStatus.add($objStatus)
                return
                
            }
            elseif (-not $device.subscription.key) {
                # Must return a message if device has no subscription
                $objStatus.Status = "Failed"
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
                        "[{0}] {1} [{2}] iLO proxy server settings removed successfully!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber | Write-Verbose
                        $objStatus.ProxySettingsStatus = "Complete"
                        $objStatus.ProxySettingsDetails = "iLO proxy server settings removed successfully!"
                    }
                    else {
                        "[{0}] {1} [{2}] iLO proxy server settings removal error! Message: {3}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $msg | Write-Verbose
                        $objStatus.ProxySettingsStatus = "Failed"
                        $objStatus.ProxySettingsDetails = $msg                        
                    }  
                    
                    # Wait for 5 seconds to allow iLO to apply the changes
                    Start-Sleep -Seconds 5
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

                if ($CloudConnectStatus -ne "Connected") {

                    $iLOConnectiontoCOMResponse = $null
                
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
                                $CloudConnectStatus = (Invoke-RestMethod @CloudConnectStatusParams).Oem.Hpe.CloudConnect.CloudConnectStatus
                                "[{0}] {1} [{2}] Connection to COM status: '{3}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $CloudConnectStatus | Write-Verbose
                            
                                # Calculate the current spinner character
                                $spinnerChar = $spinner[$subcounter % $spinner.Length]
                            
                                # Display the spinner character
                                $message = "[{0}] -- iLO '{1}' - Connection to COM status: '{2}'" -f $IloIP, $SerialNumber, $CloudConnectStatus
                                Write-SpinnerOutput -Message $message -SpinnerChar $spinnerChar
                            
                                $subcounter++
                                "[{0}] {1} [{2}] Waiting for iLO to connect to COM... (check {3})" -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $subcounter | Write-Verbose
                                Start-Sleep -Seconds 4
                            
                            } while ($CloudConnectStatus -eq "ConnectionInProgress" -and $subcounter -le 30) # Wait up to 2 minutes for connection to complete 

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
                        
                            # Check if the error message indicates "Connection in progress"
                            if ($_ -match "Connection in progress" -and $counter -le 10 -and $_ -notmatch "COMActivationDenied") {
                                "[{0}] {1} [{2}] Connection in progress, retrying (attempt {3})..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $IloIP, $SerialNumber, $counter | Write-Verbose
                                Start-Sleep -Seconds 5
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
                        
                    } until ($CloudConnectStatus -eq "Connected" -or $counter -gt 10)      
                
                    if ($counter -gt 10) {
                        Clear-SpinnerOutput
                    
                        $objStatus.iLOConnectionStatus = "Failed"
                        $objStatus.iLOConnectionDetails = "iLO cannot be connected to Compute Ops Management! Connection timeout - Check the iLO event log for more information."
                        $objStatus.Status = "Failed"
                        [void] $iLOConnectionStatus.add($objStatus)
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
                    $objStatus.iLOConnectionStatus = "Complete"
                    $objStatus.iLOConnectionDetails = "iLO is already connected to the Compute Ops Management instance!"
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
            }
            #EndRegion
        }
        else {
            "[{0}] {1} [{2}] iLO is not supported by HPE GreenLake! Skipping server..." -f $MyInvocation.InvocationName.ToString().ToUpper(), $iLOIP, $SerialNumber | Write-Verbose
            
            $objStatus.OnboardingStatus = "Error" 
            $objStatus.OnboardingDetails = "Only iLO5, iLO6 and iLO7 are supported by HPE GreenLake"
        }   

        # Final status determination
        if ($objStatus.PSobject.Properties.value -contains "Failed") {
            $objStatus.Status = "Failed"
        }
        else {
            $objStatus.Status = "Complete"
        }

        # Ensure status is added to collection
        [void] $iLOConnectionStatus.add($objStatus)

    }

    end {

        $iLOConnectionStatus = Invoke-RepackageObjectWithType -RawObject $iLOConnectionStatus -ObjectName "Device.Connect.iLO"    
        Return $iLOConnectionStatus
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

       
        # Add tracking object to the list of object status list
        [void]$ObjectStatusList.Add($objStatus)

    }

    end {        

        try {
            $Devices = Get-HPEGLdevice 
        
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        
        foreach ($DeviceToAdd in $ObjectStatusList) {
            
            
            $ErrorFoundInTags = $False

            $Device = $Devices | Where-Object serialNumber -eq $DeviceToAdd.SerialNumber
            
            
            if ( $Device) {

                $DeviceToAdd.Status = "Warning"
                $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Device already present in the workspace!" }
                $DeviceToAdd.TagsAdded = $Null
                
                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource already present in the workspace!" -f $DeviceToAdd.SerialNumber
                    Write-warning $ErrorMessage
                    continue
                }
            } 
            else {
                
                if ($DeviceToAdd.TagsAdded) {
                    
                    "[{0}] {1}: Object TagsAdded content: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DeviceToAdd.serialnumber, $DeviceToAdd.TagsAdded | Write-Verbose

                    $splittedtags = $DeviceToAdd.TagsAdded.split(",")

                    if ($splittedtags.Length -gt 25) {
                        
                        $DeviceToAdd.Status = "Failed"
                        $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Too many tags defined ! A maximum of 25 tags per resource is supported!" }
                        $DeviceToAdd.TagsAdded = $Null
                        $ErrorFoundInTags = $True


                        if ($WhatIf) {
                            $ErrorMessage = "Device '{0}': Resource is defined with too many tags! A maximum of 25 tags per resource is supported!" -f $DeviceToAdd.SerialNumber
                            Write-warning $ErrorMessage
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
                            if ($tag -notmatch '^[\p{L}\p{Nd}_ .:+\-@]+\=[\p{L}\p{Nd}_ .:+\-@]+$') {
                                
                                $splittedtagName = $tag.TrimEnd().TrimStart()
    
                                $DeviceToAdd.Status = "Failed"
                                $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Tag format '$splittedtagName' not supported! Expected format is <tagname>=<value>, <tagname>=<value>!" }
                                $DeviceToAdd.TagsAdded = $Null
                                $ErrorFoundInTags = $True
    
                                if ($WhatIf) {
                                    $ErrorMessage = "Device '{0}': Tag '{1}' format not supported! Expected format is <tagname>=<value>, <tagname>=<value>!" -f $DeviceToAdd.SerialNumber, $splittedtagName                                   
                                    Write-warning $ErrorMessage
                                    break
                                }
                            }
                            else {
    
                                $tagname = $tag.split('=')[0]
        
                                # Remove space at the begining and at the end of the string if any
                                $tagname = $tagname.TrimEnd().TrimStart()
        
                                if ($tagname.Length -gt 128) {
        
                                    $DeviceToAdd.Status = "Failed"
                                    $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Tag name '$tagname' is over 128 characters! Tag names can have a maximum of 128 characters!" }
                                    $DeviceToAdd.TagsAdded = $Null
                                    $ErrorFoundInTags = $True
                                    
                                    if ($WhatIf) {
                                        $ErrorMessage = "Device '{0}': Tag name '{1}' is over 128 characters! Tag names can have a maximum of 128 characters!" -f $DeviceToAdd.SerialNumber, $tagname
                                        Write-warning $ErrorMessage
                                        break
                                    }
                                }
                                else {
                                    
                                    $tagvalue = $tag.split('=')[1]
                                    
                                    # Remove space at the begining and at the end of the string if any
                                    $tagvalue = $tagvalue.TrimEnd().TrimStart()
            
                                    if ($tagvalue.Length -gt 256) {
            
                                        $DeviceToAdd.Status = "Failed"
                                        $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Tag value '$tagvalue' is over 256 characters! Tag values can have a maximum of 256 characters!" }
                                        $DeviceToAdd.TagsAdded = $Null
                                        $ErrorFoundInTags = $True
            
                                        if ($WhatIf) {
                                            $ErrorMessage = "Device '{0}': Tag value '{1}' is over 256 characters! Tag values can have a maximum of 256 characters!" -f $DeviceToAdd.SerialNumber, $tagvalue
                                            Write-warning $ErrorMessage
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
                            $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Device cannot be added to the HPE GreenLake workspace!" }
                            $DeviceToAdd.Exception = $_.Exception.message 

                        }
                    }
                }
            }      
        }
    
        

        if (-not $WhatIf) {

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "Device.Add.SPTSDE"    
            Return $ObjectStatusList
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

            
        # Add tracking object to the list of object status list
        [void]$ObjectStatusList.Add($objStatus)



    }

    end {        

        try {
            $Devices = Get-HPEGLdevice 
        
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }

        
        foreach ($DeviceToAdd in $ObjectStatusList) {
            
            
            $ErrorFoundInTags = $False

            $Device = $Devices | Where-Object serialNumber -eq $DeviceToAdd.SerialNumber
            
            
            if ( $Device) {

                $DeviceToAdd.Status = "Warning"
                $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Device already present in the workspace!" }
                $DeviceToAdd.TagsAdded = $Null
                
                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource already present in the workspace!" -f $DeviceToAdd.SerialNumber
                    Write-warning $ErrorMessage
                    continue
                }
            } 
            else {
                
                if ($DeviceToAdd.TagsAdded) {
                    
                    "[{0}] {1}: Object TagsAdded content: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DeviceToAdd.serialnumber, $DeviceToAdd.TagsAdded | Write-Verbose

                    $splittedtags = $DeviceToAdd.TagsAdded.split(",")

                    if ($splittedtags.Length -gt 25) {
                        
                        $DeviceToAdd.Status = "Failed"
                        $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Too many tags defined ! A maximum of 25 tags per resource is supported!" }
                        $DeviceToAdd.TagsAdded = $Null
                        $ErrorFoundInTags = $True


                        if ($WhatIf) {
                            $ErrorMessage = "Device '{0}': Resource is defined with too many tags! A maximum of 25 tags per resource is supported!" -f $DeviceToAdd.SerialNumber
                            Write-warning $ErrorMessage
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
                            if ($tag -notmatch '^[\p{L}\p{Nd}_ .:+\-@]+\=[\p{L}\p{Nd}_ .:+\-@]+$') {
                                
                                $splittedtagName = $tag.TrimEnd().TrimStart()
    
                                $DeviceToAdd.Status = "Failed"
                                $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Tag format '$splittedtagName' not supported! Expected format is <tagname>=<value>, <tagname>=<value>!" }
                                $DeviceToAdd.TagsAdded = $Null
                                $ErrorFoundInTags = $True
    
                                if ($WhatIf) {
                                    $ErrorMessage = "Device '{0}': Tag '{1}' format not supported! Expected format is <tagname>=<value>, <tagname>=<value>!" -f $DeviceToAdd.SerialNumber, $splittedtagName
                                    Write-warning $ErrorMessage
                                    break
                                }
                            }
                            else {
    
                                $tagname = $tag.split('=')[0]
        
                                # Remove space at the begining and at the end of the string if any
                                $tagname = $tagname.TrimEnd().TrimStart()
        
                                if ($tagname.Length -gt 128) {
        
                                    $DeviceToAdd.Status = "Failed"
                                    $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Tag name '$tagname' is over 128 characters! Tag names can have a maximum of 128 characters!" }
                                    $DeviceToAdd.TagsAdded = $Null
                                    $ErrorFoundInTags = $True
        
                                    if ($WhatIf) {
                                        $ErrorMessage = "Device '{0}': Tag name '{1}' is over 128 characters! Tag names can have a maximum of 128 characters!" -f $DeviceToAdd.SerialNumber, $tagname
                                        Write-warning $ErrorMessage
                                        break
                                    }
                                }
                                else {
                                    
                                    $tagvalue = $tag.split('=')[1]
                                    
                                    # Remove space at the begining and at the end of the string if any
                                    $tagvalue = $tagvalue.TrimEnd().TrimStart()
            
                                    if ($tagvalue.Length -gt 256) {
            
                                        $DeviceToAdd.Status = "Failed"
                                        $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Tag value '$tagvalue' is over 256 characters! Tag values can have a maximum of 256 characters!" }
                                        $DeviceToAdd.TagsAdded = $Null
                                        $ErrorFoundInTags = $True
            
                                        if ($WhatIf) {
                                            $ErrorMessage = "Device '{0}': Tag value '{1}' is over 256 characters! Tag values can have a maximum of 256 characters!" -f $DeviceToAdd.SerialNumber, $tagvalue
                                            Write-warning $ErrorMessage
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
                            $DeviceToAdd.Details = [PSCustomObject]@{TagsAdded = 0; Error = "Device cannot be added to the HPE GreenLake workspace!" }
                            $DeviceToAdd.Exception = $_.Exception.message 

                        }
                    }
                }
            }      
        }
    
        

        if (-not $WhatIf) {

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "Device.Add.SMTSDE"    
            Return $ObjectStatusList
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

      
        # Add tracking object to the list of object status list
        [void]$ArchivedDevicesStatus.Add($objStatus)     

   
    }

    end {        

        try {
            $Devices = Get-HPEGLdevice 
        
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }


        "[{0}] Devices to archive: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ArchivedDevicesStatus.SerialNumber | Write-Verbose

        foreach ($DeviceToArchive in $ArchivedDevicesStatus) {

            $Device = $Devices | Where-Object serialnumber -eq $DeviceToArchive.SerialNumber

            if ( -not $Device) {
                
                $DeviceToArchive.Status = "Failed"
                $DeviceToArchive.Details = "Device cannot be found in the workspace!"
                
                # Must return a message if device not found
                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource cannot be found in the workspace!" -f $DeviceToArchive.SerialNumber
                    Write-warning $ErrorMessage
                    continue
                }

            }
            elseif ( $Device.archived ) {
                # Must return a message if device already archived
                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource is already disabled (archived)!" -f $DeviceToArchive.SerialNumber
                    Write-warning $ErrorMessage
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
                    
                        $DeviceToArchive.Status = "Complete"
                        $DeviceToArchive.Details = "Device successfully disabled (archived)"
                    }
                }
            }
            catch {

                if (-not $WhatIf) {
                    
                    foreach ($DeviceToArchive in $ArchivedDevicesStatus) {

                        $DeviceToArchive.Status = "Failed"
                        $DeviceToArchive.Details = "Device could not be disabled (archived)!"
                        $DeviceToArchive.Exception = $_.Exception.message

                    }
                }
            }
        }


        if (-not $WhatIf) {

            $ArchivedDevicesStatus = Invoke-RepackageObjectWithType -RawObject $ArchivedDevicesStatus -ObjectName "ObjStatus.SSDE"  
            Return $ArchivedDevicesStatus
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

      

        # Add tracking object to the list of object status list
        [void]$UnarchivedDevicesStatus.Add($objStatus)     



    }

    end {

        try {
            $Devices = Get-HPEGLdevice 
        
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }


        "[{0}] Devices to unarchive: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($UnarchivedDevicesStatus.SerialNumber | out-string) | Write-Verbose

        foreach ($DeviceToUnarchive in $UnarchivedDevicesStatus) {

            $Device = $Devices | Where-Object serialnumber -eq $DeviceToUnarchive.SerialNumber

            if ( -not $Device) {
                
                $DeviceToUnarchive.Status = "Failed"
                $DeviceToUnarchive.Details = "Device cannot be found in the workspace!"
                
                # Must return a message if device not found
                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource cannot be found in the workspace!" -f $DeviceToUnarchive.SerialNumber
                    Write-warning $ErrorMessage
                    continue
                }
                 
            }
            elseif (-not $device.archived ) {
                # Must return a message if device is not archived
            
                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource is already enabled (unarchived)!" -f $DeviceToUnarchive.SerialNumber
                    Write-warning $ErrorMessage
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
                    
                        $DeviceToUnarchive.Status = "Complete"
                        $DeviceToUnarchive.Details = "Device successfully enabled (unarchived)"
                    }
                }
            }
            catch {

                if (-not $WhatIf) {
                    
                    foreach ($DeviceToUnarchive in $UnarchivedDevicesStatus) {

                        $DeviceToUnarchive.Status = "Failed"
                        $DeviceToUnarchive.Details = "Device could not be enabled (unarchived)!"
                        $DeviceToUnarchive.Exception = $_.Exception.message

                    }
                }
            }
        }


        if (-not $WhatIf) {

            $UnarchivedDevicesStatus = Invoke-RepackageObjectWithType -RawObject $UnarchivedDevicesStatus -ObjectName "ObjStatus.SSDE"  
            Return $UnarchivedDevicesStatus
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
        [void]$ObjectStatusList.Add($objStatus)

    }

    end {

        try {
            $Devices = Get-HPEGLdevice 
        
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }


        "[{0}] List of devices where to add tags: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ObjectStatusList.serialnumber | Write-Verbose

        foreach ($DeviceToAddTags in $ObjectStatusList) {

            $Device = $Devices | Where-Object serialNumber -eq $DeviceToAddTags.SerialNumber

            if ( -not $Device) {
                # Must return a message if device not found
                $DeviceToAddTags.Status = "Failed"
                $DeviceToAddTags.Details = [PSCustomObject]@{
                    TagsAdded      = 0; 
                    TagsDeleted    = 0; 
                    TagsUnmodified = 0; 
                    Error          = "Device cannot be found in the HPE GreenLake workspace!" 
                }               

                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource cannot be found in the workspace!" -f $DeviceToAddTags.SerialNumber
                    Write-warning $ErrorMessage
                    continue
                }
            } 
            else {

                "[{0}] {1}: Object TagsAdded content: {2}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $DeviceToAddTags.serialnumber, $DeviceToAddTags.TagsAdded | Write-Verbose

                $splittedtags = $DeviceToAddTags.TagsAdded.split(",")

                if ($splittedtags.Length -gt 25) {
                    
                    $DeviceToAddTags.Status = "Failed"
                    $DeviceToAddTags.Details = [PSCustomObject]@{
                        TagsAdded      = 0; 
                        TagsDeleted    = 0; 
                        TagsUnmodified = 0; 
                        Error          = "Too many tags defined ! A maximum of 25 tags per resource is supported!" 
                    }               

                    if ($WhatIf) {
                        $ErrorMessage = "Device '{0}': Resource is defined with too many tags! A maximum of 25 tags per resource is supported!" -f $DeviceToAddTags.SerialNumber
                        Write-warning $ErrorMessage
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
                        if ($tag -notmatch '^[\p{L}\p{Nd}_ .:+\-@]+\=[\p{L}\p{Nd}_ .:+\-@]+$') {
                            
                            $splittedtagName = $tag.TrimEnd().TrimStart()

                            $DeviceToAddTags.Status = "Failed"
                            $DeviceToAddTags.Details = [PSCustomObject]@{
                                TagsAdded      = 0; 
                                TagsDeleted    = 0; 
                                TagsUnmodified = 0; 
                                Error          = "Tag format '$splittedtagName' not supported! Expected format is <tagname>=<value>, <tagname>=<value>!" 
                            }               

                            if ($WhatIf) {
                                $ErrorMessage = "Device '{0}': Tag '{1}' format not supported! Expected format is <tagname>=<value>, <tagname>=<value>!" -f $DeviceToAddTags.SerialNumber, $splittedtagName
                                Write-warning $ErrorMessage
                                break
                            }
                        }
                        else {

                            $tagname = $tag.split('=')[0]
    
                            # Remove space at the begining and at the end of the string if any
                            $tagname = $tagname.TrimEnd().TrimStart()
    
                            if ($tagname.Length -gt 128) {
    
                                $DeviceToAddTags.Status = "Failed"
                                $DeviceToAddTags.Details = [PSCustomObject]@{TagsAdded = 0; TagsDeleted = 0; TagsUnmodified = 0; Error = "Tag name '$tagname' is over 128 characters! Tag names can have a maximum of 128 characters!" }               
    
                                if ($WhatIf) {
                                    $ErrorMessage = "Device '{0}': Tag name '{1}' is over 128 characters! Tag names can have a maximum of 128 characters!" -f $DeviceToAddTags.SerialNumber, $tagname
                                    Write-warning $ErrorMessage
                                    break
                                }
                            }
                            else {
                                
                                $tagvalue = $tag.split('=')[1]
                                
                                # Remove space at the begining and at the end of the string if any
                                $tagvalue = $tagvalue.TrimEnd().TrimStart()
        
                                if ($tagvalue.Length -gt 256) {
        
                                    $DeviceToAddTags.Status = "Failed"
                                    $DeviceToAddTags.Details = [PSCustomObject]@{TagsAdded = 0; TagsDeleted = 0; TagsUnmodified = 0; Error = "Tag value '$tagvalue' is over 256 characters! Tag values can have a maximum of 256 characters!" }     

        
                                    if ($WhatIf) {
                                        $ErrorMessage = "Device '{0}': Tag value '{1}' is over 256 characters! Tag values can have a maximum of 256 characters!" -f $DeviceToAddTags.SerialNumber, $tagvalue
                                        Write-warning $ErrorMessage
                                        break
                                    }
                                }
                                else {

                                    $TagsList += [PSCustomObject]@{
                                        name  = $tagname
                                        value = $tagvalue 
                                    }
                                }
                            }
                        }
                    } 
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
       
        
        # Removing objects where status is failed (condition when device is not found or tags are not supported)
        $ObjectStatusListForFoundDevices = $ObjectStatusList | Where-Object { $_.Status -ne "Failed" }
        
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
                            $object.Details = [PSCustomObject]@{TagsAdded = $TagsToBeCreated.count; TagsDeleted = $TagsToBeDeleted.count; TagsUnmodified = $object.TagsUnmodified -ne $null ? ($object.TagsUnmodified -split ",").Count : 0; Error = $null }
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
                                TagsUnmodified = $object.TagsUnmodified -ne $null ? ($object.TagsUnmodified -split ",").Count : 0; 
                                Error          = "No action required, the same tag configuration already exists!" 
                            }
                            [void] $AddTagsDevicesStatus.add($object)
                        }
                    }
                    else {
                        foreach ($object in $Group.Group) {
                            Write-Warning "Device '$($object.SerialNumber)' has no action required, the tag configuration already exists."
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
                        $object.Details = [PSCustomObject]@{TagsAdded = 0; TagsDeleted = 0; TagsUnmodified = 0; Error = "Device tagging error!" }
                        $object.Exception = $_.Exception.message 
                        [void] $AddTagsDevicesStatus.add($object)
                    }
                }
            }
        }
    
        # Getting objects where status is failed (condition when device is not found or tags are not supported )
        $ObjectStatusListOfDevicesNotFound = $ObjectStatusList | Where-Object { $_.Status -eq "Failed" } 


        "[{0}] List of objects with failed status: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusListOfDevicesNotFound | Out-String) | Write-Verbose

        foreach ($Object in $ObjectStatusListOfDevicesNotFound) {
            if (-not $WhatIf) {
                $Object.TagsAdded = $null
                $Object.TagsDeleted = $null
                $Object.TagsUnmodified = $null
                [void] $AddTagsDevicesStatus.add($Object)
            }
        }


        if (-not $WhatIf) {

            $AddTagsDevicesStatus = Invoke-RepackageObjectWithType -RawObject $AddTagsDevicesStatus -ObjectName "Device.Tag.STTTSDE"  
            Return $AddTagsDevicesStatus
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
        [void]$ObjectStatusList.Add($objStatus)

    }

    end {


        try {
            $Devices = Get-HPEGLdevice 
        
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)
            
        }


        "[{0}] List of devices where to remove tags: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $ObjectStatusList.serialnumber | Write-Verbose

        foreach ($DeviceToRemoveTags in $ObjectStatusList) {

            $Device = $Devices | Where-Object serialNumber -eq $DeviceToRemoveTags.SerialNumber

            if ( -not $Device) {
                # Must return a message if device not found
                $DeviceToRemoveTags.Status = "Failed"
                $DeviceToRemoveTags.TagsDeleted = $null
                $DeviceToRemoveTags.TagsNotFound = $null
                $DeviceToRemoveTags.Exception = $null
                $DeviceToRemoveTags.Details = [PSCustomObject]@{TagsDeleted = 0; TagsNotFound = 0; Error = "Device cannot be found in the workspace!" }

                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource cannot be found in the workspace!" -f $DeviceToRemoveTags.SerialNumber
                    Write-warning $ErrorMessage
                    continue
                }
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

                        foreach ($tag in $splittedtags) {

                            # Validate tag format, if format is not <tagname>, return error
                            if ($tag -notmatch '^[\p{L}\p{Nd}_ .:+\-@]+$') {

                                $splittedtagName = $tag.TrimEnd().TrimStart()

                                $DeviceToRemoveTags.Status = "Failed"
                                $DeviceToRemoveTags.TagsDeleted = $null
                                $DeviceToRemoveTags.TagsNotFound = $null
                                $DeviceToRemoveTags.Exception = $null
                                $DeviceToRemoveTags.Details = [PSCustomObject]@{
                                    TagsDeleted  = 0; 
                                    TagsNotFound = 0; 
                                    Error        = "Tag format '$splittedtagName' not supported! Expected format is <tagname>, <tagname>!" 
                                }

                                if ($WhatIf) {
                                    $ErrorMessage = "Device '{0}' tag '{1}' format not supported! Expected format is <tagname>, <tagname>!" -f $DeviceToRemoveTags.SerialNumber, $splittedtagName
                                    Write-warning $ErrorMessage
                                    break
                                }                                
                            }
                            else {
                            
                                # Remove space at the begining and at the end of the string if any
                                $tagname = $tag.TrimEnd().TrimStart()                                
                                $TagsList += $tagname

                            }
                                
                        } 

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
            }
        }


        "[{0}] List of objects in `$ObjectStatusList: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList | Out-String) | Write-Verbose

        # Removing objects where status is failed (condition when device is not found or tags not supported)
        $ObjectStatusListForFoundDevices = $ObjectStatusList | Where-Object { $_.Status -ne "Failed" }
        
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
    
                        # Find tags that need to be deleted but that do not exist
                        $TagsNotfoundNumber = $TagsList.count - $TagsToBeDeleted.count
    
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
                            $object.Details = [PSCustomObject]@{TagsDeleted = $TagsToBeDeleted.count; TagsNotFound = $object.TagsNotFound -ne $null ? ($object.TagsNotFound -split ",").Count : 0; Error = $Null }
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
                            Write-Warning "Device '$($object.SerialNumber)' has no action required, tags to remove cannot be found!"

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
                        $object.Exception = $_.Exception.Message
                        $object.Details = [PSCustomObject]@{TagsDeleted = 0; TagsNotFound = 0; Error = "Device untagging error!" }
                        [void] $RemoveTagsDevicesStatus.add($object)

                    }
                }
            }
        }   
        
        # Getting objects where status is failed (condition when device is not found and tags are not supported)
        $ObjectStatusListOfDevicesNotFound = $ObjectStatusList | Where-Object { $_.Status -eq "Failed" } 


        "[{0}] List of objects with devices not found: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusListOfDevicesNotFound | Out-String) | Write-Verbose

        foreach ($Object in $ObjectStatusListOfDevicesNotFound) {

            if (-not $WhatIf) {
                $Object.TagsDeleted = $null
                $Object.TagsNotFound = $null
                $Object.Exception = $null
                [void] $RemoveTagsDevicesStatus.add($Object)
            }
        }

        if (-not $WhatIf) {

            $RemoveTagsDevicesStatus = Invoke-RepackageObjectWithType -RawObject $RemoveTagsDevicesStatus -ObjectName "Device.Tag.STTTSDE"  
            Return $RemoveTagsDevicesStatus
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
                Write-warning $ErrorMessage
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
                Write-Warning "$PrimaryContactEmail contact email is not found in the HPE GreenLake workspace! Please ensure the email address is valid and trustworthy!"
                $PrimaryContactName = "NONGLP"
            }

            if ($ShippingReceivingContactEmail) {

                $ShippingReceivingContactInfo = Get-HPEGLUser -Email $ShippingReceivingContactEmail

                if ( $ShippingReceivingContactInfo) {
                    $ShippingReceivingContactName = $ShippingReceivingContactInfo.firstname + " " + $ShippingReceivingContactInfo.lastname

                }
                else {
                    Write-Warning "$ShippingReceivingContactEmail contact email is not found in the HPE GreenLake workspace! Please ensure the email address is valid and trustworthy!"
                    $ShippingReceivingContactName = "NONGLP"

                }
            }
            
            if ($SecurityContactEmail) {

                $SecurityContactInfo = Get-HPEGLUser -Email $SecurityContactEmail

                if ( $SecurityContactInfo) {
                    $SecurityContactName = $SecurityContactInfo.firstname + " " + $SecurityContactInfo.lastname

                }
                else {
                    Write-Warning "$SecurityContactEmail contact email is not found in the HPE GreenLake workspace! Please ensure the email address is valid and trustworthy!"
                    $SecurityContactName = "NONGLP"
                }
            }
            
            if ($OperationsContactEmail) {

                $OperationsContactInfo = Get-HPEGLUser -Email $OperationsContactEmail

                if ( $OperationsContactInfo) {
                    $OperationsContactName = $OperationsContactInfo.firstname + " " + $OperationsContactInfo.lastname

                }
                else {
                    Write-Warning "$OperationsContactEmail contact email is not found in the HPE GreenLake workspace! Please ensure the email address is valid and trustworthy!"
                    $OperationsContactName = "NONGLP"
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

            $LocationAddressList += $StreetAddress 

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
                    
                $LocationAddressList += $ShippingReceivingAddress

            }
           
           
            # Defining contacts

            $ContactsList = [System.Collections.ArrayList]::new()


            $PrimaryContact = [PSCustomObject]@{ 
                type        = "primary"
                name        = $PrimaryContactName
                phoneNumber = $PrimaryContactPhone
                email       = $PrimaryContactEmail
            }              
            
            $ContactsList += $PrimaryContact 


            if ($ShippingReceivingContactEmail) {
    
                $ShippingReceivingContact = [PSCustomObject]@{ 
                    type        = "shipping_receiving"
                    name        = $ShippingReceivingContactName
                    phoneNumber = $ShippingReceivingContactPhone
                    email       = $ShippingReceivingContactEmail
                }

                $ContactsList += $ShippingReceivingContact

            }
            
            if ($SecurityContactEmail) {

                $SecurityContact = [PSCustomObject]@{ 
                    type        = "security"
                    name        = $SecurityContactName
                    phoneNumber = $SecurityContactPhone
                    email       = $SecurityContactEmail
                }

                $ContactsList += $SecurityContact
            }
            
            if ($OperationsContactEmail) {

                $OperationsContact = [PSCustomObject]@{ 
                    type        = "operations"
                    name        = $OperationsContactName
                    phoneNumber = $OperationsContactPhone
                    email       = $OperationsContactEmail
                }

                $ContactsList += $OperationsContact
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
        
                }

            }
            catch {
                "[{0}] Failed to create location '{1}'" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                if (-not $WhatIf) {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Location cannot be created!"
                    $objStatus.Exception = $Global:HPECOMInvokeReturnData
                }

            }

        }
        

        [void] $NewLocationStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

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

        [Parameter (ParameterSetName = "ShippingReceivingContact")]
        [String]$ShippingReceivingContactEmail,   

        [Parameter (ParameterSetName = "ShippingReceivingContact")]
        [String]$ShippingReceivingContactPhone, 
        
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

        [Switch]$WhatIf
    ) 

    Begin {

        $Caller = (Get-PSCallStack)[1].Command

        "[{0}] Called from: {1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Caller | Write-Verbose

        $ObjectStatusList = [System.Collections.ArrayList]::new()

               
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
        

        [void] $ObjectStatusList.add($objStatus)

    }

    end {

        try {
            
            $Locations = Get-HPEGLLocation -ShowDetails
            $Users = Get-HPEGLUser 
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }
        
        
        foreach ($Object in $ObjectStatusList) {
            
            $Locationfound = $Locations | Where-Object name -eq $Object.Name

            $Uri = (Get-DevicesLocationUri) + "/" + $Locationfound.id

            if (-not $Locationfound) {

                # Must return a message if device not found
                $Object.Status = "Failed"
                $Object.Details = "Location cannot be found in the workspace!"

                if ($WhatIf) {
                    $ErrorMessage = "Location '{0}': Resource cannot be found in the workspace!" -f $Object.Name
                    Write-warning $ErrorMessage
                    continue
                }

            }
            else {
                                
                $LocationAddressList = [System.Collections.ArrayList]::new()
                $ContactsList = [System.Collections.ArrayList]::new()
                
                #Region Validate emails
                if ($PrimaryContactEmail) {

                    $PrimaryContactInfo = $Users | Where-Object email -eq $PrimaryContactEmail
                    
                    # Get contact names from emails 
                    if ( $PrimaryContactInfo) {
                        $PrimaryContactName = $PrimaryContactInfo.contact.first_name + " " + $PrimaryContactInfo.contact.last_name
                    }
                    else {
                        Throw "$PrimaryContactEmail contact email cannot be found in the HPE GreenLake workspace!"
                    }
                }          

                if ($ShippingReceivingContactEmail) {
                   
                    $ShippingReceivingContactInfo = $Users | Where-Object email -eq $ShippingReceivingContactEmail

                    if ( $ShippingReceivingContactInfo) {
                        $ShippingReceivingContactName = $ShippingReceivingContactInfo.contact.first_name + " " + $ShippingReceivingContactInfo.contact.last_name

                    }
                    else {
                        Throw "$ShippingReceivingContactEmail contact email cannot be found in the HPE GreenLake workspace!"
                    }
                }
                
                if ($SecurityContactEmail) {
                  
                    $SecurityContactInfo = $Users | Where-Object email -eq $SecurityContactEmail

                    if ( $SecurityContactInfo) {
                        $SecurityContactName = $SecurityContactInfo.contact.first_name + " " + $SecurityContactInfo.contact.last_name

                    }
                    else {
                        Throw "$SecurityContactEmail contact email cannot be found in the HPE GreenLake workspace!"
                    }
                }
                
                if ($OperationsContactEmail) {
                   
                    $OperationsContactInfo = $Users | Where-Object email -eq $OperationsContactEmail

                    if ( $OperationsContactInfo) {
                        $OperationsContactName = $OperationsContactInfo.contact.first_name + " " + $OperationsContactInfo.contact.last_name

                    }
                    else {
                        Throw "$OperationsContactEmail contact email cannot be found in the HPE GreenLake workspace!"
                    }
                }


                #EndRegion

                #Region Modifying details (Name or Description)

                if ($NewName) {

                    # newname cannot be used when more than one location is found in $ObjectStatusList
                    if ($ObjectStatusList.Count -gt 1) {
                        Throw "NewName cannot be used when more than one location is found in the pipeline!"
                    }
                    else {
                        $Name = $NewName
                    }

                }
                else {
                    $Name = $Locationfound.name
                }

                if (-not $PSBoundParameters.ContainsKey('Description')) {
                
                    if ($Locationfound.description) {
                                
                        $Description = $Locationfound.description
                    }
                    else {
                        $Description = $Null
                    }
                }

                if ($PSBoundParameters.ContainsKey('NewName') -or $PSBoundParameters.ContainsKey('Description')) {

                    # Building payload
            
                    $Payload = [PSCustomObject]@{
                        name         = $Name
                        description  = $Description
                        locationType = "building"
            
                    } | ConvertTo-Json -Depth 5
                }

                #EndRegion
            
                #Region Modifying street address
                if (-not $PSBoundParameters.ContainsKey('Country')) {
                
                    if (($Locationfound.addresses | Where-Object type -eq Street ).country) {
                                
                        $Country = ($Locationfound.addresses | Where-Object type -eq Street ).country
                    }
                    else {
                        $Country = $Null
                    }
                }
                if (-not $PSBoundParameters.ContainsKey('Street')) {
            
                    if (($Locationfound.addresses | Where-Object type -eq Street ).streetAddress) {
                                
                        $Street = ($Locationfound.addresses | Where-Object type -eq Street ).streetAddress
                    }
                    else {
                        $Street = $Null
                    }
                }
                if (-not $PSBoundParameters.ContainsKey('Street2')) {
            
                    if (($Locationfound.addresses | Where-Object type -eq Street ).streetAddress2) {
                                
                        $Street2 = ($Locationfound.addresses | Where-Object type -eq Street ).streetAddress2
                    }
                    else {
                        $Street2 = $Null
                    }
                }
                if (-not $PSBoundParameters.ContainsKey('City')) {
            
                    if (($Locationfound.addresses | Where-Object type -eq Street ).city) {
                                
                        $City = ($Locationfound.addresses | Where-Object type -eq Street ).city
                    }
                    else {
                        $City = $Null
                    }
                }
                # State is mandatory !
                if (-not $State) {
            
                    if (($Locationfound.addresses | Where-Object type -eq Street ).state) {
                                
                        $State = ($Locationfound.addresses | Where-Object type -eq Street ).state
                    }

                }
                if (-not $PSBoundParameters.ContainsKey('PostalCode')) {
            
                    if (($Locationfound.addresses | Where-Object type -eq Street ).postalCode) {
                                
                        $PostalCode = ($Locationfound.addresses | Where-Object type -eq Street ).postalCode
                    }
                    else {
                        $PostalCode = $Null
                    }
                }

                if ($PSBoundParameters.ContainsKey('Country') -or $PSBoundParameters.ContainsKey('Street') -or $PSBoundParameters.ContainsKey('Street2') -or $PSBoundParameters.ContainsKey('City') -or $PSBoundParameters.ContainsKey('State') -or $PSBoundParameters.ContainsKey('PostalCode')) {
                
                    $PrimaryAddressId = ($Locationfound.addresses | Where-Object type -eq Street).id

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

                    $LocationAddressList += $StreetAddress 
                }
                #Endregion

                #Region Modifying shipping/receiving address

                if (-not $PSBoundParameters.ContainsKey('ShippingReceivingCountry')) {
                
                    if (($Locationfound.addresses | Where-Object type -eq shipping_receiving ).country) {
                                
                        $ShippingReceivingCountry = ($Locationfound.addresses | Where-Object type -eq shipping_receiving ).country
                    }
                    else {
                        $ShippingReceivingCountry = $Null
                    }
                }
                if (-not $PSBoundParameters.ContainsKey('ShippingReceivingStreet')) {
            
                    if (($Locationfound.addresses | Where-Object type -eq shipping_receiving ).streetAddress) {
                                
                        $ShippingReceivingStreet = ($Locationfound.addresses | Where-Object type -eq shipping_receiving ).streetAddress
                    }
                    else {
                        $ShippingReceivingStreet = $Null
                    }
                }
                if (-not $PSBoundParameters.ContainsKey('ShippingReceivingStreet2')) {
            
                    if (($Locationfound.addresses | Where-Object type -eq shipping_receiving ).streetAddress2) {
                                
                        $ShippingReceivingStreet2 = ($Locationfound.addresses | Where-Object type -eq shipping_receiving ).streetAddress2
                    }
                    else {
                        $ShippingReceivingStreet2 = $Null
                    }
                }
                if (-not $PSBoundParameters.ContainsKey('ShippingReceivingCity')) {
            
                    if (($Locationfound.addresses | Where-Object type -eq shipping_receiving ).city) {
                                
                        $ShippingReceivingCity = ($Locationfound.addresses | Where-Object type -eq shipping_receiving ).city
                    }
                    else {
                        $ShippingReceivingCity = $Null
                    }
                }
                # Mandatory
                if (-not $PSBoundParameters.ContainsKey('ShippingReceivingState')) {
            
                    if (($Locationfound.addresses | Where-Object type -eq shipping_receiving ).state) {
                                
                        $ShippingReceivingState = ($Locationfound.addresses | Where-Object type -eq shipping_receiving ).state
                    }
                    else {
                        $ShippingReceivingState = "N/A"
                    }
                    
                }
                if (-not $PSBoundParameters.ContainsKey('ShippingReceivingPostalCode')) {
            
                    if (($Locationfound.addresses | Where-Object type -eq shipping_receiving ).postalCode) {
                                
                        $ShippingReceivingPostalCode = ($Locationfound.addresses | Where-Object type -eq shipping_receiving ).postalCode
                    }
                    else {
                        $ShippingReceivingPostalCode = $Null
                    }
                }


                if ($PSBoundParameters.ContainsKey('ShippingReceivingCountry') -or $PSBoundParameters.ContainsKey('ShippingReceivingStreet') -or $PSBoundParameters.ContainsKey('ShippingReceivingStreet2') `
                        -or $PSBoundParameters.ContainsKey('ShippingReceivingCity') -or $PSBoundParameters.ContainsKey('ShippingReceivingState') -or $PSBoundParameters.ContainsKey('ShippingReceivingPostalCode')) {

                    # if already exists
                    if (($Locationfound.addresses | Where-Object type -eq shipping_receiving).id) {

                        $ShippingAddressId = ($Locationfound.addresses | Where-Object type -eq shipping_receiving).id
                        
                        $ShippingReceivingAddress = [PSCustomObject]@{
                            country        = $ShippingReceivingCountry
                            streetaddress  = $ShippingReceivingStreet
                            streetaddress2 = $ShippingReceivingStreet2
                            city           = $ShippingReceivingCity
                            state          = $ShippingReceivingState
                            postalcode     = $ShippingReceivingPostalCode
                            type           = "shipping_receiving"
                            id             = $ShippingAddressId 
                        }
                    }
                    else {
                        $ShippingReceivingAddress = [PSCustomObject]@{
                            country        = $ShippingReceivingCountry
                            streetaddress  = $ShippingReceivingStreet
                            streetaddress2 = $ShippingReceivingStreet2
                            city           = $ShippingReceivingCity
                            state          = $ShippingReceivingState
                            postalcode     = $ShippingReceivingPostalCode
                            type           = "shipping_receiving"
                        }

                    }
                        
                    $LocationAddressList += $ShippingReceivingAddress
                }

                #Endregion
                
                #Region Removing Shipping/receiving contact
                if ($RemoveShippingReceivingAddress) {
        
                    $ShippingAddressId = ($Locationfound.addresses | Where-Object type -eq shipping_receiving).id
        
                    if (! $ShippingAddressId) {
    
                        "[{0}] There is no Shipping and Receiving address for the '{1}' location!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

                        $Object.Status = "Failed"
                        $Object.Details = "There is no Shipping and Receiving address in this location to be removed!"
                        # [void] $UpdateLocationStatus.add($Object)
                        continue

                        if ($Whatif) {
                            $ErrorMessage = "There is no Shipping and Receiving address in location '{0}' to be removed!" -f $Object.Name
                            Write-warning $ErrorMessage
                            continue
                        }

                    }
                    else {

                        $StreetAddressId = ($Locationfound.addresses | Where-Object type -eq street).id

                        $Country = ($Locationfound.addresses | Where-Object type -eq Street ).country
                    
                        $Street = ($Locationfound.addresses | Where-Object type -eq Street ).streetAddress
        
                        $Street2 = ($Locationfound.addresses | Where-Object type -eq Street ).streetAddress2
        
                        $City = ($Locationfound.addresses | Where-Object type -eq Street ).city
        
                        $State = ($Locationfound.addresses | Where-Object type -eq Street ).state
        
                        $PostalCode = ($Locationfound.addresses | Where-Object type -eq Street ).postalCode
        
                        $StreetAddress = [PSCustomObject]@{
                            country        = $Country
                            streetaddress  = $Street
                            streetaddress2 = $Street2
                            city           = $City
                            state          = $State
                            postalcode     = $PostalCode
                            type           = "street"
                            id             = $StreetAddressId 
        
                        }

                        $LocationAddressList += $StreetAddress      
                        
                        $ShippingAddressInfo = [PSCustomObject]@{ 
                            type = "shipping_receiving"
                            id   = $ShippingAddressId
                        }         
                        
                        $LocationAddressList += $ShippingAddressInfo      

                    }
                }
                #Endregion

                #Region Modifying primary contact

                if (-not $PSBoundParameters.ContainsKey('PrimaryContactName')) {
                
                    if (($Locationfound.contacts | Where-Object type -eq primary).name) {
                                
                        $PrimaryContactName = ($Locationfound.contacts | Where-Object type -eq primary).name
                    }
                    else {
                        $PrimaryContactName = $Null
                    }
                }
                if (-not $PSBoundParameters.ContainsKey('PrimaryContactPhone')) {
            
                    if (($Locationfound.contacts | Where-Object type -eq primary).phone_number) {
                                
                        $PrimaryContactPhone = ($Locationfound.contacts | Where-Object type -eq primary).phone_number
                    }
                    else {
                        $PrimaryContactPhone = $Null
                    }
                }
                if (-not $PSBoundParameters.ContainsKey('PrimaryContactEmail')) {
            
                    if (($Locationfound.contacts | Where-Object type -eq primary).email) {
                                
                        $PrimaryContactEmail = ($Locationfound.contacts | Where-Object type -eq primary).email
                    }
                    else {
                        $PrimaryContactEmail = $Null
                    }
                }

                if ($PSBoundParameters.ContainsKey('PrimaryContactEmail') -or $PSBoundParameters.ContainsKey('PrimaryContactPhone')) {
            
                    $PrimaryContactId = ($Locationfound.contacts | Where-Object type -eq primary).id
                
                    $ContactInfo = [PSCustomObject]@{ 
                        type = "primary"
                        id   = $PrimaryContactId
                    }         
                    
                    $ContactsList += $ContactInfo             
                    
                    $PrimaryContact = [PSCustomObject]@{ 
                        type        = "primary"
                        name        = $PrimaryContactName
                        phoneNumber = $PrimaryContactPhone
                        email       = $PrimaryContactEmail
                        locationId  = $Locationfound.id
                    }              
                
                    $ContactsList += $PrimaryContact 

                }

                #EndRegion

                #Region Modifying shipping/receiving contact

                if (-not $PSBoundParameters.ContainsKey('ShippingReceivingContactPhone')) {
            
                    if (($Locationfound.contacts | Where-Object type -eq shipping_receiving).phone_number) {
                                
                        $ShippingReceivingContactPhone = ($Locationfound.contacts | Where-Object type -eq shipping_receiving).phone_number
                    }
                    else {
                        $ShippingReceivingContactPhone = $Null
                    }
                }
                if (-not $PSBoundParameters.ContainsKey('ShippingReceivingContactEmail')) {
            
                    if (($Locationfound.contacts | Where-Object type -eq shipping_receiving).email) {
                                
                        $ShippingReceivingContactEmail = ($Locationfound.contacts | Where-Object type -eq shipping_receiving).email
                    }
                    else {
                        $ShippingReceivingContactEmail = $Null
                    }
                }

                if ( $PSBoundParameters.ContainsKey('ShippingReceivingContactEmail') -or $PSBoundParameters.ContainsKey('ShippingReceivingContactPhone')) {
                    
                    # If contact not existing
                    if (! ($Locationfound.contacts | Where-Object type -eq shipping_receiving)) {

                        $ShippingReceivingContact = [PSCustomObject]@{ 
                            type        = "shipping_receiving"
                            name        = $ShippingReceivingContactName
                            phoneNumber = $ShippingReceivingContactPhone
                            email       = $ShippingReceivingContactEmail
                            locationId  = $Locationfound.id
                        }

                        $ContactsList += $ShippingReceivingContact

                    }
                    # If contact already created
                    else {

                        $ShippingReceivingContactId = ($Locationfound.contacts | Where-Object type -eq shipping_receiving).id
        
                        $ContactInfo = [PSCustomObject]@{ 
                            type = "shipping_receiving"
                            id   = $ShippingReceivingContactId
                        }         
                        
                        $ContactsList += $ContactInfo  

                        $ShippingReceivingContact = [PSCustomObject]@{ 
                            type        = "shipping_receiving"
                            name        = $ShippingReceivingContactName
                            phoneNumber = $ShippingReceivingContactPhone
                            email       = $ShippingReceivingContactEmail
                            locationId  = $Locationfound.id
                        }

                        $ContactsList += $ShippingReceivingContact
                    }
                }

                #EndRegion

                #Region Remove Shipping/Receiving Contact
                if ($RemoveShippingReceivingContact) {
                    
                    $ShippingReceivingContactId = ($Locationfound.contacts | Where-Object type -eq shipping_receiving).id

                    if ( ! $ShippingReceivingContactId) {
                        
                        "[{0}] There is no Shipping and Receiving contact for the '{1}' location!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                        
                        $Object.Status = "Failed"
                        $Object.Details = "There is no Shipping and Receiving contact in this location to be removed!"
                        # [void] $UpdateLocationStatus.add($objStatus)
                        continue

                        if ($Whatif) {
                            $ErrorMessage = "There is no Shipping and Receiving contact in location '{0}' to be removed!" -f $Object.Name
                            Write-warning $ErrorMessage
                            continue
                        }
                 

                    }
                    else {
        
                        $ContactInfo = [PSCustomObject]@{ 
                            type = "shipping_receiving"
                            id   = $ShippingReceivingContactId
                        }         
                    
                        $ContactsList += $ContactInfo  
                    }
                }
                #Endregion

                #Region Modifying security contact

                if (-not $PSBoundParameters.ContainsKey('SecurityContactPhone')) {
        
                    if (($Locationfound.contacts | Where-Object type -eq security).phone_number) {
                                
                        $SecurityContactPhone = ($Locationfound.contacts | Where-Object type -eq security).phone_number
        
                    }
                    else {
                        $SecurityContactPhone = $Null
                    }
        
                }
                if (-not $PSBoundParameters.ContainsKey('SecurityContactEmail')) {
        
                    if (($Locationfound.contacts | Where-Object type -eq security).email) {
                                
                        $SecurityContactEmail = ($Locationfound.contacts | Where-Object type -eq security).email
        
                    }
                    else {
                        $SecurityContactEmail = $Null
                    }
        
                }

                if ( $PSBoundParameters.ContainsKey('SecurityContactEmail') -or $PSBoundParameters.ContainsKey('SecurityContactPhone')) {

                    # If contact not existing

                    if (! ($Locationfound.contacts | Where-Object type -eq security)) {

                        $SecurityContact = [PSCustomObject]@{ 
                            type        = "security"
                            name        = $SecurityContactName
                            phoneNumber = $SecurityContactPhone
                            email       = $SecurityContactEmail
                            locationId  = $Locationfound.id

                        }

                        $ContactsList += $SecurityContact

                    }
                    # If contact already created
                    else {

                        $SecurityContactId = ($Locationfound.contacts | Where-Object type -eq security).id

                        $ContactInfo = [PSCustomObject]@{ 
                            type = "security"
                            id   = $SecurityContactId
                        }         
                    
                        $ContactsList += $ContactInfo  

                        $SecurityContact = [PSCustomObject]@{ 
                            type        = "security"
                            name        = $SecurityContactName
                            phoneNumber = $SecurityContactPhone
                            email       = $SecurityContactEmail
                            locationId  = $Locationfound.id
                        }

                        $ContactsList += $SecurityContact
                    }
                }
                #Endregion

                #Region Remove Security Contact
                if ($RemoveSecurityContact) {
                    
                    $SecurityContactId = ($Locationfound.contacts | Where-Object type -eq security).id

                    if ( ! $SecurityContactId) {
                        
                        "[{0}] There is no security contact for the '{1}' location!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose

                        $Object.Status = "Failed"
                        $Object.Details = "There is no security contact in this location to be removed!"
                        # [void] $UpdateLocationStatus.add($Object)
                        continue

                        if ($Whatif) {
                            $ErrorMessage = "There is no security contact in location '{0}' to be removed!" -f $Object.Name
                            Write-warning $ErrorMessage
                            continue
                        }

                    }
                    else {

                        $ContactInfo = [PSCustomObject]@{ 
                            type = "security"
                            id   = $SecurityContactId
                        }         
                
                        $ContactsList += $ContactInfo  
                    }
                }
                #Endregion

                #Region Modifying operations contact

                if (-not $PSBoundParameters.ContainsKey('OperationsContactPhone')) {
            
                    if (($Locationfound.contacts | Where-Object type -eq operations).phone_number) {
                                
                        $OperationsContactPhone = ($Locationfound.contacts | Where-Object type -eq operations).phone_number
        
                    }
                    else {
                        $OperationsContactPhone = $Null
                    }
        
                }  
                if (-not $PSBoundParameters.ContainsKey('OperationsContactEmail')) {
        
                    if (($Locationfound.contacts | Where-Object type -eq operations).email) {
                                
                        $OperationsContactEmail = ($Locationfound.contacts | Where-Object type -eq operations).email
        
                    }
                    else {
                        $OperationsContactEmail = $Null
                    }
        
                }  

                if ($PSBoundParameters.ContainsKey('OperationsContactEmail') -or $PSBoundParameters.ContainsKey('OperationsContactPhone')) {

                    # If contact not existing

                    if (! ($Locationfound.contacts | Where-Object type -eq operations)) {

                        $OperationsContact = [PSCustomObject]@{ 
                            type        = "operations"
                            name        = $OperationsContactName
                            phoneNumber = $OperationsContactPhone
                            email       = $OperationsContactEmail
                            locationId  = $Locationfound.id
                        }

                        $ContactsList += $OperationsContact

                    }                  
                    # If contact already created
                    else {

                        $OperationsContactId = ($Locationfound.contacts | Where-Object type -eq operations).id

                        $ContactInfo = [PSCustomObject]@{ 
                            type = "operations"
                            id   = $OperationsContactId
                        }         
                
                        $ContactsList += $ContactInfo  

                        $OperationsContact = [PSCustomObject]@{ 
                            type        = "operations"
                            name        = $OperationsContactName
                            phoneNumber = $OperationsContactPhone
                            email       = $OperationsContactEmail
                            locationId  = $Locationfound.id
                        }

                        $ContactsList += $OperationsContact
                    }
                }
                #Endregion

                #Region Remove Operations Contact
                if ($RemoveOperationsContact) {

                    $OperationsContactId = ($Locationfound.contacts | Where-Object type -eq operations).id

                    if ( ! $OperationsContactId) {
                        
                        "[{0}] There is no operations contact for the '{1}' location!" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                        
                        $Object.Status = "Failed"
                        $Object.Details = "There is no operations contact in this location to be removed!"
                        # [void] $UpdateLocationStatus.add($Object)
                        continue

                        if ($Whatif) {
                            $ErrorMessage = "There is no operations contact in location '{0}' to be removed!" -f $Object.Name
                            Write-warning $ErrorMessage
                            continue
                        }
                       
                    }
                    else {

                        $ContactInfo = [PSCustomObject]@{ 
                            type = "operations"
                            id   = $OperationsContactId
                        }         
            
                        $ContactsList += $ContactInfo  
                    }
                }
                #Endregion


                # Building payload

                if ( $LocationAddressList) {
                    $Payload = [PSCustomObject]@{
                        name         = $Name
                        description  = $Description
                        locationType = "building"
                        addresses    = $LocationAddressList
        
                    } | ConvertTo-Json -Depth 5
                }

                if ( $ContactsList) {

                    $Payload = [PSCustomObject]@{
                        name         = $Name
                        description  = $Description
                        locationType = "building"
                        contacts     = $ContactsList

                    } | ConvertTo-Json -Depth 5
                }
                
                
                if ( $LocationAddressList -and $ContactsList) {
                    $Payload = [PSCustomObject]@{
                        name         = $Name
                        description  = $Description
                        locationType = "building"
                        addresses    = $LocationAddressList
                        contacts     = $ContactsList

        
                    } | ConvertTo-Json -Depth 5
                }


                    
                # Modify Location
                try {

                    $Response = Invoke-HPEGLWebRequest -Uri $Uri -method 'PATCH' -body $Payload -ContentType "application/merge-patch+json" -WhatIfBoolean $WhatIf -Verbose:$VerbosePreference    

                    if (-not $WhatIf) {

                        "[{0}] Location '{1}' successfully updated" -f $MyInvocation.InvocationName.ToString().ToUpper(), $Name | Write-Verbose
                        $Object.Status = "Complete"
                        $Object.Details = "Location successfully modified"
            
                    }

                }
                catch {

                    if (-not $WhatIf) {
                        $Object.Status = "Failed"
                        $Object.Details = "Location cannot be modified!"
                        $Object.Exception = $_.Exception.message 
                    }
                }
            }
        }


        if (-not $WhatIf) {

            $ObjectStatusList = Invoke-RepackageObjectWithType -RawObject $ObjectStatusList -ObjectName "ObjStatus.NSDE" 
            Return $ObjectStatusList
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

                $Uri = (Get-DevicesLocationUri) + "/" + $Locationfound.id
                
            }
            catch {
                $PSCmdlet.ThrowTerminatingError($_)                
            }


            if ( -not $Locationfound) {
    
                # Must return a message if resource not found
                
                if ($WhatIf) {
                    $ErrorMessage = "Location '{0}': Resource cannot be found in the workspace!" -f $Name
                    Write-warning $ErrorMessage
                    return
                }
                else {
                    $objStatus.Status = "Failed"
                    $objStatus.Details = "Location cannot be found in the workspace!"
                }
            
            }
            else {           
                   
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
                        $objStatus.Details = "Location cannot be deleted!"
                        $objStatus.Exception = $Global:HPECOMInvokeReturnData 
                    }

                }

            }
        
        }

        else {
                
            'Operation cancelled by user!' | Write-Verbose

            if ($WhatIf) {
                $ErrorMessage = "Operation cancelled by the user!"
                Write-warning $ErrorMessage
                return
            }
            else {    
                $objStatus.Status = "Failed"
                $objStatus.Details = "Operation cancelled by the user!"
            }
        }

        [void] $RemoveLocationStatus.add($objStatus)

    }

    end {

        if (-not $WhatIf) {

            $RemoveLocationStatus = Invoke-RepackageObjectWithType -RawObject $RemoveLocationStatus -ObjectName "ObjStatus.NSDE" 
            Return $RemoveLocationStatus
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
    

        [void]$ObjectStatusList.Add($objStatus)


    }

    end {

        try {
            
            $devices = Get-HPEGLdevice 
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }
        
        
        "[{0}] List of devices where to set a location: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList.serialnumber | out-string) | Write-Verbose

        foreach ($Object in $ObjectStatusList) {

            $Device = $Devices | Where-Object serialNumber -eq $Object.SerialNumber

            if ( -not $Device) {

                # Must return a message if device not found
                $Object.Status = "Failed"
                $Object.Details = "Device cannot be found in the HPE GreenLake workspace!" 

                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}' cannot be found in the HPE GreenLake workspace!" -f $Object.SerialNumber
                    Write-warning $ErrorMessage
                    continue
                }

            } 
            elseif ($device.location.name -and -not $Force) {

                # Must return a message if device is already assigned to location and removed from the list of devices to be set
                $Object.Status = "Warning"
                $Object.Details = "Device is already assigned to the '$($device.location.name)' location!"

                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}' is already assigned to the '{1}' location!" -f $Object.SerialNumber, $device.location.name
                    Write-warning $ErrorMessage
                    continue
                }
                
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
                            $Object.Details = "Location cannot be assigned to device!"

                            $Object.Exception = $_.Exception.message 

                        }
                    }
                }
            }
        }

        if (-not $WhatIf) {

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
    
        [void]$ObjectStatusList.Add($objStatus)


    }

    end {

        try {
            
            $devices = Get-HPEGLdevice 
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }
        
        
        "[{0}] List of devices where to remove the location: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList.serialnumber | out-string) | Write-Verbose

        foreach ($Object in $ObjectStatusList) {

            $Device = $Devices | Where-Object serialNumber -eq $Object.SerialNumber

            if ( -not $Device) {

                # Must return a message if device not found
                $Object.Status = "Failed"
                $Object.Details = "Device cannot be found in the workspace!" 

                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource cannot be found in the workspace!" -f $Object.SerialNumber
                    Write-warning $ErrorMessage
                    continue
                }

            } 
            elseif (-not $device.location.name) {

                # Must return a message if device is not assigned to a location
                $Object.Status = "Warning"
                $Object.Details = "Device is not assigned to a location!"

                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource is not assigned to a location!" -f $Object.SerialNumber
                    Write-warning $ErrorMessage
                    continue
                }

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
                            $Object.Details = "Location cannot be unassigned from device!"
                            $Object.Exception = $_.Exception.message 

                        }
                    }
                }
            }
        }

        if (-not $WhatIf) {

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
    

        [void]$ObjectStatusList.Add($objStatus)


    }

    end {

        try {
            
            $devices = Get-HPEGLdevice 
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }
        
        
        "[{0}] List of devices where to set the service delivery contact: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList.serialnumber | out-string) | Write-Verbose

        foreach ($Object in $ObjectStatusList) {

            $Device = $Devices | Where-Object serialNumber -eq $Object.SerialNumber

            if ( -not $Device) {

                # Must return a message if device not found
                $Object.Status = "Failed"
                $Object.Details = "Device cannot be found in the HPE GreenLake workspace!" 

                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}' cannot be found in the HPE GreenLake workspace!" -f $Object.SerialNumber
                    Write-warning $ErrorMessage
                    continue
                }

            } 
            elseif ($device.serviceDelivery.email -eq $Email) {

                # Must return a message if device already set with the same contact
                $Object.Status = "Warning"
                $Object.Details = "Device is already assigned to the service delivery contact '{0}'! No changes made." -f $device.serviceDelivery.email

                if ($WhatIf) {
                    $WarningMessage = "Device is already assigned to the service delivery contact '{0}'! No changes will be made." -f $device.serviceDelivery.email
                    Write-warning $WarningMessage
                    continue
                }

            }
            else {         

                if ($device.serviceDelivery.email) {
                    # Must return a message if device is already assigned to contact and will be updated
                    "Device is currently assigned to the service delivery contact '{0}' and will be updated to the new contact '{1}'." -f $device.serviceDelivery.email, $Email | Write-Verbose
                    $WarningMessage = "Device is currently assigned to the service delivery contact '{0}' and will be updated to the new contact '{1}'." -f $device.serviceDelivery.email, $Email
                    Write-warning $WarningMessage
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
                            $Object.Details = "Service delivery contact cannot be assigned to device!"

                            $Object.Exception = $_.Exception.message 

                        }
                    }
                }
            }
        }

        if (-not $WhatIf) {

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
    
        [void]$ObjectStatusList.Add($objStatus)


    }

    end {

        try {
            
            $devices = Get-HPEGLdevice 
            
        }
        catch {
            $PSCmdlet.ThrowTerminatingError($_)                
        }
        
        
        "[{0}] List of devices where to remove the service delivery contact: `n{1}" -f $MyInvocation.InvocationName.ToString().ToUpper(), ($ObjectStatusList.serialnumber | out-string) | Write-Verbose

        foreach ($Object in $ObjectStatusList) {

            $Device = $Devices | Where-Object serialNumber -eq $Object.SerialNumber

            if ( -not $Device) {

                # Must return a message if device not found
                $Object.Status = "Failed"
                $Object.Details = "Device cannot be found in the workspace!" 

                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource cannot be found in the workspace!" -f $Object.SerialNumber
                    Write-warning $ErrorMessage
                    continue
                }

            } 
            elseif (-not $device.serviceDelivery.email -and -not $device.serviceDelivery.name) {

                # Must return a message if device is not assigned to a service delivery contact
                $Object.Status = "Warning"
                $Object.Details = "Device is not assigned to a service delivery contact!"

                if ($WhatIf) {
                    $ErrorMessage = "Device '{0}': Resource is not assigned to a service delivery contact!" -f $Object.SerialNumber
                    Write-warning $ErrorMessage
                    continue
                }

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
                            $Object.Details = "Service delivery contact cannot be unassigned from device!"
                            $Object.Exception = $_.Exception.message 

                        }
                    }
                }
            }
        }

        if (-not $WhatIf) {

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
    'Get-HPEGLLocation', 'New-HPEGLLocation', 'Set-HPEGLLocation', 'Remove-HPEGLLocation', `
    'Set-HPEGLDeviceLocation', 'Remove-HPEGLDeviceLocation', `
    'Set-HPEGLDeviceServiceDeliveryContact', 'Remove-HPEGLDeviceServiceDeliveryContact' `
    -Alias *


# SIG # Begin signature block
# MIItTgYJKoZIhvcNAQcCoIItPzCCLTsCAQExDzANBglghkgBZQMEAgEFADB5Bgor
# BgEEAYI3AgEEoGswaTA0BgorBgEEAYI3AgEeMCYCAwEAAAQQH8w7YFlLCE63JNLG
# KX7zUQIBAAIBAAIBAAIBAAIBADAxMA0GCWCGSAFlAwQCAQUABCB8BGf5Ye5uQETx
# zW/LIWo1Gigu3/FsmHf0HGyAT3Pw26CCEfYwggVvMIIEV6ADAgECAhBI/JO0YFWU
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
# IgQgFyOm+18bWUz4QEY47iIw9ixoJaHKcGliaUaCV/3UE40wDQYJKoZIhvcNAQEB
# BQAEggIAUN8TkhKOXtAMC4uZhNymBdgE0zFoh7yHEz0/QRwF14CG46nuxwunQGgd
# /ZH2BksHHiBfhLV4Pl6yqtxZcnEt2G6//psRphaqnufG1nbtq+pM3tbO2baL8YTi
# oNhqYN5yFThkuG8TSvzkdz4yAQHPyGZ4eYlMa3EheXp5eHuIFEK3rXbQItzkHnQd
# LqA0z9bTVmbj3ntgAeYxg5EWzSodUxXHNlpkKclGYm3TvjBFFXyLmZPG1SCrS0UQ
# Jj4/Hz+24wApfA+ZssEAKgfUPgrw+q0katEnqbYxbPtiZmQ+MQaAmc5BIyQ0xjHi
# cgO0dbnHCPOqKeBrsKKYxhebp7+Texo4NSWtNHv24QLKEwrVsSwD+LJ4b1DOhixo
# GI+cXNBA4226JVkQ4EpsP9VsQq6lInLt/QKCa80tOEi2gfEbagvbbwWgvTCmlPJL
# 5PDIMjgA8uHK+2C6DEmnlxiGjDst38M23MPBUIDMkIekRRvgAix3mUYmf9bgAImU
# voC8lCgwTuiVIJOTTpuQFKCxaFr+Qm+R5f0PXdwPRbWOYj2RX/+ec++Y9LPkoc4Y
# 3ssJMDX2hvjC6jZ6+U62frIZzXMU4YnaBBlgVVe5yP0QVXNN51OuzsxvijARtxUU
# 4C8tr+5tWeq1X7op5AYvGWXRaZ9xIP8OqRJh7EfPVZKt/XuOFLqhgheYMIIXlAYK
# KwYBBAGCNwMDATGCF4QwgheABgkqhkiG9w0BBwKgghdxMIIXbQIBAzEPMA0GCWCG
# SAFlAwQCAgUAMIGIBgsqhkiG9w0BCRABBKB5BHcwdQIBAQYJYIZIAYb9bAcBMEEw
# DQYJYIZIAWUDBAICBQAEMN3bmfmppWEjxg/Io/wJqqWCieyWsMUbZRrUUVW+CUFa
# GGyEVxYJqUFRSPWcj12iRgIRAKHjy1RqjtE49u5lXYojHUEYDzIwMjYwMTE5MTgy
# MzA5WqCCEzowggbtMIIE1aADAgECAhAMIENJ+dD3WfuYLeQIG4h7MA0GCSqGSIb3
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
# BgkqhkiG9w0BCQMxDQYLKoZIhvcNAQkQAQQwHAYJKoZIhvcNAQkFMQ8XDTI2MDEx
# OTE4MjMwOVowKwYLKoZIhvcNAQkQAgwxHDAaMBgwFgQUcrz9oBB/STSwBxxhD+bX
# llAAmHcwNwYLKoZIhvcNAQkQAi8xKDAmMCQwIgQgMvPjsb2i17JtTx0bjN29j4uE
# dqF4ntYSzTyqep7/NcIwPwYJKoZIhvcNAQkEMTIEMPFeqQB+fb4S4U0eDelbAqGA
# xyzM7HbLFJWBpomftgpAE/uaoIZyVJQbu4rJuW9HNzANBgkqhkiG9w0BAQEFAASC
# AgBMcnkg8PEYY93AiqEq1wZiJYD+eDwjApp+p1F7CwDqHhtcN445yDmLm335R2rh
# mamstVpzSj/nEJQJP7ebOeb+egUXVi1udD+7GqSgXFioEZ+gWXUxykgKpdebLpuR
# F2EnRnQOEyXCS9sXuX50EeGGkA+qLc7mesERbPTj1hPFSw2hVEvix983PByAiy1s
# FXVw8Fl4pleXGnOriVCMdoXBxUmjEv1fiXNeSZQenCPXET4OfynI4TUmWwjK/4BE
# vA2cJUBXUTxUbc38JHK0oD38eH+ri2nmNLB2kFTEgBB3z93s9De6/JWB0/VA0r0r
# 20GFSsh4avBKlHchuuasHIhN86GKjadijjPP1DH7RgdfSOlqIQiYn2TM0IxY0zS9
# 1Dzn8c3nwh0w4h5dyyrwvQK2DnOgWc8I9qQMI2NJ5xooY2MBACQCbxY5L9Rn7NJc
# gkNW4fAPVnmd6UvtHwynyxi7NDQZpM269j8XUTWc1G64emvocxhy+R9fmpr7A5vv
# B+dCeVjkYPHl/7Rj92U2svUWjrw5qyHM2ULyRss2XDJKo8uMTZm/IO7e5jIeN6CH
# QekkMjFPOpo7u9GaRzmS4h2U5WBopjo0cVuQmo0PCpoPTTKkH97VOJkAvjttYopi
# ctetEfnfrUJeXvLSsGE14nrDwax7/Uf8Zunn43mAooxNTw==
# SIG # End signature block
